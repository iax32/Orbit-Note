import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

import '../domain/calendar_event.dart';
import '../domain/universal_object.dart';
import '../domain/wiki_links.dart';
import '../domain/note_path_links.dart';
import '../domain/search_text.dart';
import '../domain/workspace_failure.dart';
import '../infrastructure/storage/index_factory.dart';
import '../infrastructure/storage/object_codec.dart';
import '../infrastructure/storage/object_index.dart';
import '../infrastructure/storage/path_safety.dart';
import '../infrastructure/storage/store_factory.dart';
import '../infrastructure/storage/workspace_store.dart';

/// Coordinates durable content before updating the disposable query index.
/// UI/controllers use this boundary, never the platform store or SQLite directly.
class WorkspaceRepository {
  WorkspaceRepository({WorkspaceStore? store, ObjectIndex? index})
    : _store = store ?? createWorkspaceStore(),
      _index = index ?? createObjectIndex();

  final WorkspaceStore _store;
  final ObjectIndex _index;
  final _codec = ObjectCodec();
  final _objects = <String, UniversalObject>{};
  final _paths = <String, String>{};
  final _sources = <String, String>{};
  final _hashes = <String, String>{};
  final _issues = <String>[];
  Future<void> _queue = Future.value();
  bool _initialized = false;
  bool _indexReady = false;
  bool _readOnly = false;
  String _workspaceId = '';
  String _name = '';
  String? _manifestHash;
  List<String> _folders = const ['Notes'];
  List<String> get folders => List.unmodifiable(_folders);
  bool get supportsFolders => _store is WorkspaceFolderStore;
  String? objectPath(String id) => _paths[id];

  Future<void> createFolder(String path) => _serial(() async {
    _requireWritable();
    await _verifyManifest();
    await (_store as WorkspaceFolderStore).createFolder(path);
    _folders = await (_store as WorkspaceFolderStore).listFolders();
  });

  Future<void> deleteFolder(String folder) => _serial(() async {
    _requireWritable();
    await _verifyManifest();
    if (folder == 'Notes' || !folder.startsWith('Notes/')) {
      throw const WorkspaceFailure('Cannot remove the root Notes folder.');
    }
    final notesInFolder = _paths.entries
        .where((e) => e.value == folder || e.value.startsWith('$folder/'))
        .map((e) => e.key)
        .toList();
    final owned = _paths.values.toSet();
    if ((await _store.listFiles()).any(
      (path) => path.startsWith('$folder/') && !owned.contains(path),
    )) {
      throw const WorkspaceFailure(
        'Move unrecognized files out before deleting this folder.',
      );
    }
    for (final id in notesInFolder) {
      final source = _paths[id]!;
      await _moveNotes(source, 'Notes/${p.posix.basename(source)}');
      final obj = _objects[id];
      if (obj != null && !obj.isDeleted) {
        await _save(obj.copyWith(deletedAt: DateTime.now().toUtc()));
      }
    }
    if (_store is WorkspaceFolderStore) {
      await (_store as WorkspaceFolderStore).deleteFolder(folder);
      _folders = await (_store as WorkspaceFolderStore).listFolders();
    }
    await _refresh();
  });

  Future<void> moveNote(String id, String folder) => _serial(() async {
    final source = _paths[id];
    if (source == null || !source.startsWith('Notes/')) {
      throw const WorkspaceFailure('Only text-backed notes can be moved.');
    }
    if (!_folders.contains(folder)) {
      throw const WorkspaceFailure('Choose an existing folder.');
    }
    await _moveNotes(source, '$folder/${p.posix.basename(source)}');
  });

  Future<void> moveFolder(String source, String target) =>
      _serial(() => _moveNotes(source, target));

  Future<void> _moveNotes(String source, String target) async {
    _requireWritable();
    await _verifyManifest();
    final replacements = <String, FileReplacement>{};
    final owned = _paths.values.toSet();
    for (final path in await _store.listFiles()) {
      if ((path == source || path.startsWith('$source/')) &&
          path.endsWith('.md') &&
          !owned.contains(path)) {
        throw const WorkspaceFailure(
          'This folder contains unrecognized Markdown. Adopt or move those files separately before moving the folder.',
        );
      }
    }
    for (final entry in _paths.entries) {
      if (entry.value != source && !entry.value.startsWith('$source/')) {
        continue;
      }
      final object = _objects[entry.key]!;
      _validate(object);
      final nextPath = '$target${entry.value.substring(source.length)}';
      final body = rebaseNoteLinks(
        object.body,
        entry.value,
        nextPath,
        movedSource: source,
        movedTarget: target,
      );
      final next = body == object.body
          ? object
          : object.copyWith(
              body: body,
              revision: object.revision + 1,
              updatedAt: DateTime.now().toUtc(),
            );
      replacements[entry.value] = FileReplacement(
        _bytes(
          body == object.body
              ? _sources[entry.key]!
              : _codec.encode(next, previousSource: _sources[entry.key]),
        ),
        _hashes[entry.key]!,
      );
    }
    try {
      await (_store as WorkspaceFolderStore).movePath(
        source,
        target,
        replacements,
      );
    } finally {
      await _refresh();
    }
  }

  List<UniversalObject> get objects => List.unmodifiable(_objects.values);
  List<String> get issues => List.unmodifiable(_issues);
  String get workspaceId => _workspaceId;
  String get name => _name;
  String get location => _store.location;
  bool get readOnly => _readOnly;
  bool get isBrowser => _store.isBrowser;
  Stream<String> get externalFileChanges => _store is WorkspaceChangeSource
      ? (_store as WorkspaceChangeSource).changes
      : const Stream.empty();
  Future<List<String>> recentLocations() => _store is WorkspaceSelectionStore
      ? (_store as WorkspaceSelectionStore).recentLocations()
      : Future.value([]);
  Future<void> clearSelection() => _store is WorkspaceSelectionStore
      ? (_store as WorkspaceSelectionStore).clearSelection()
      : Future.value();
  Future<void> renameWorkspace(String name) => _serial(() async {
    _requireWritable();
    await _verifyManifest();
    if (name.trim().isEmpty) {
      throw const WorkspaceFailure('Vault name cannot be empty.');
    }
    final old =
        jsonDecode(utf8.decode((await _store.read('workspace.json'))!)) as Map;
    final bytes = _bytes(
      '${const JsonEncoder.withIndent('  ').convert({...old, 'name': name.trim()})}\n',
    );
    await _store.write('workspace.json', bytes, expectedHash: _manifestHash);
    _manifestHash = sha256.convert(bytes).toString();
    _name = name.trim();
  });

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> initialize({String? path}) => _serial(() async {
    await _index.close();
    _indexReady = false;
    _initialized = false;
    _objects.clear();
    _paths.clear();
    _sources.clear();
    _hashes.clear();
    _issues.clear();
    _readOnly = false;
    await _store.initialize(path: path);
    var manifestBytes = await _store.read('workspace.json');
    if (manifestBytes == null) {
      final files = await _store.listFiles();
      if (files.any(
        (f) => !f.startsWith('.orbit/') && !f.contains('.orbit-'),
      )) {
        throw const WorkspaceFailure(
          'This folder has files but no Orbit workspace manifest. Choose an empty folder or an existing Orbit workspace.',
        );
      }
      final manifest = {
        'format': 'orbit-note-workspace',
        'version': 1,
        'id': const Uuid().v4(),
        'name': 'My Knowledge',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      };
      manifestBytes = _bytes(
        '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
      );
      await _store.write('workspace.json', manifestBytes, expectedHash: null);
    }
    final manifest =
        jsonDecode(utf8.decode(manifestBytes)) as Map<String, dynamic>;
    if (manifest['format'] != 'orbit-note-workspace' ||
        manifest['id'] is! String ||
        manifest['version'] is! int) {
      throw const WorkspaceFailure(
        'The workspace manifest is invalid. No content was replaced.',
      );
    }
    _workspaceId = manifest['id'] as String;
    _manifestHash = sha256.convert(manifestBytes).toString();
    _name = manifest['name'] as String? ?? 'My Knowledge';
    _readOnly = manifest['version'] != 1;
    if (_readOnly) {
      _issues.add(
        'Workspace format ${manifest['version']} is unsupported; opened read-only.',
      );
    }
    if (isBrowser) {
      _issues.add(
        'Browser content is stored on this device. Clearing site data removes it; export a backup regularly.',
      );
    }
    _initialized = true;
    await _refresh();
    final selectionStore = _store;
    if (selectionStore is WorkspaceSelectionStore) {
      try {
        await (selectionStore as WorkspaceSelectionStore).rememberSelection();
      } catch (e) {
        _addIssue(
          'Workspace opened, but its selection could not be remembered: $e',
        );
      }
    }
    if (!_readOnly) {
      try {
        await _index.initialize(location);
        await _index.replaceAll(objects);
        _indexReady = true;
      } on Object catch (error) {
        _issues.add(
          'Search index unavailable; content remains in open files. $error',
        );
      }
    }
  });

  Future<void> refresh() => _serial(_refresh);
  Future<void> _verifyManifest() async {
    final bytes = await _store.read('workspace.json');
    if (bytes == null || sha256.convert(bytes).toString() != _manifestHash) {
      _readOnly = true;
      throw const WorkspaceReadOnly(
        'The workspace manifest changed outside Orbit. Reopen this workspace before editing; pending drafts are retained.',
      );
    }
  }

  Future<bool> hasExternalChanges({
    Set<String>? changedPaths,
  }) => _serial(() async {
    _requireOpen();
    await _verifyManifest();
    if (changedPaths != null && !changedPaths.contains('*')) {
      final byPath = {
        for (final entry in _paths.entries) entry.value: entry.key,
      };
      for (final path in changedPaths) {
        if (path == 'workspace.json') continue;
        final canonical =
            (path.startsWith('Notes/') && path.endsWith('.md')) ||
            (path.startsWith('Objects/') && path.endsWith('.object.json')) ||
            (path.startsWith('Boards/') && path.endsWith('.board.json')) ||
            (path.startsWith('Drawings/') && path.endsWith('.drawing.json'));
        if (!canonical) continue;
        final id = byPath[path];
        if (id == null) return true;
        final bytes = await _store.read(path);
        if (bytes == null || sha256.convert(bytes).toString() != _hashes[id]) {
          return true;
        }
      }
      return false;
    }
    final files = (await _store.listFiles())
        .where(
          (p) =>
              (p.startsWith('Notes/') && p.endsWith('.md')) ||
              (p.startsWith('Objects/') && p.endsWith('.object.json')) ||
              (p.startsWith('Boards/') && p.endsWith('.board.json')) ||
              (p.startsWith('Drawings/') && p.endsWith('.drawing.json')),
        )
        .toSet();
    if (files.length != _paths.length || !files.containsAll(_paths.values)) {
      return true;
    }
    for (final entry in _paths.entries) {
      final bytes = await _store.read(entry.value);
      if (bytes == null ||
          sha256.convert(bytes).toString() != _hashes[entry.key]) {
        return true;
      }
    }
    return false;
  });
  Future<void> _refresh() async {
    _requireOpen();
    if (_store is WorkspaceFolderStore) {
      _folders = await (_store as WorkspaceFolderStore).listFolders();
    }
    final objects = <String, UniversalObject>{};
    final paths = <String, String>{};
    final sources = <String, String>{};
    final hashes = <String, String>{};
    for (final path in await _store.listFiles()) {
      if (path.startsWith('.orbit/recovery/') && path.endsWith('.move.json')) {
        _readOnly = true;
        _addIssue(
          'An interrupted folder move needs recovery review at $path. Vault opened read-only to preserve all versions.',
        );
      }
      if (path.contains('.orbit-') && path.endsWith('.tmp') ||
          path.endsWith('.pending')) {
        _addIssue(
          'A pending recovery copy is retained at $path. Review it before discarding any work.',
        );
      }
      final markdown = path.startsWith('Notes/') && path.endsWith('.md');
      final structured =
          (path.startsWith('Objects/') && path.endsWith('.object.json')) ||
          (path.startsWith('Boards/') && path.endsWith('.board.json')) ||
          (path.startsWith('Drawings/') && path.endsWith('.drawing.json'));
      if (!markdown && !structured) continue;
      try {
        final bytes = await _store.read(path);
        if (bytes == null) continue;
        final source = utf8.decode(bytes);
        final object = _codec.decode(source, workspaceId, markdown: markdown);
        if (objects.containsKey(object.id)) {
          _readOnly = true;
          _addIssue(
            'Duplicate object identity in ${paths[object.id]} and $path; workspace opened read-only.',
          );
          continue;
        }
        objects[object.id] = object;
        paths[object.id] = path;
        sources[object.id] = source;
        hashes[object.id] = sha256.convert(bytes).toString();
      } on Object catch (error) {
        _addIssue(
          'Could not open $path; its original file is preserved. $error',
        );
      }
    }
    _objects
      ..clear()
      ..addAll(objects);
    _paths
      ..clear()
      ..addAll(paths);
    _sources
      ..clear()
      ..addAll(sources);
    _hashes
      ..clear()
      ..addAll(hashes);
    if (_indexReady) {
      try {
        await _index.replaceAll(this.objects);
      } on Object catch (error) {
        _indexReady = false;
        _addIssue('The index needs rebuilding; local content is safe. $error');
      }
    }
  }

  Future<UniversalObject> create({
    required String typeId,
    required String title,
    String body = '',
    Map<String, dynamic> properties = const {},
    Map<String, dynamic> data = const {},
  }) => _serial(() async {
    _requireWritable();
    final now = DateTime.now().toUtc();
    return _save(
      UniversalObject(
        id: const Uuid().v4(),
        workspaceId: workspaceId,
        typeId: typeId,
        title: title,
        body: body,
        properties: properties,
        data: data,
        createdAt: now,
        updatedAt: now,
        revision: 0,
      ),
    );
  });

  Future<UniversalObject> save(UniversalObject object) =>
      _serial(() => _save(object));
  Future<UniversalObject> _save(UniversalObject object) async {
    _requireWritable();
    await _verifyManifest();
    _validate(object);
    final existing = _objects[object.id];
    if (existing != null &&
        (existing.revision != object.revision ||
            existing.typeId != object.typeId ||
            existing.createdAt != object.createdAt)) {
      throw const WorkspaceConflict(
        'This object changed since editing began. Refresh it before applying this version.',
      );
    }
    if (existing == null && object.revision != 0) {
      throw const WorkspaceConflict(
        'This object no longer exists in the loaded workspace.',
      );
    }
    final properties = Map<String, dynamic>.of(object.properties);
    final targets = _objects.values
        .where((o) => !o.isDeleted)
        .map(
          (o) => NoteLinkTarget(
            id: o.id,
            title: o.title,
            aliases: o.properties['aliases'] is List
                ? (o.properties['aliases'] as List).whereType<String>().toList()
                : const [],
          ),
        )
        .toList();
    if (properties['orbitLinkBindings'] == null ||
        properties['orbitLinkBindings'] is Map) {
      final bindings = <String, dynamic>{
        ...?existing?.linkBindings,
        ...Map<String, dynamic>.from(
          properties['orbitLinkBindings'] as Map? ?? {},
        ),
      };
      for (final link in parseWikiLinks(object.body)) {
        if (bindings.containsKey(link.target)) continue;
        final target = resolveWikiLink(link, targets).target;
        if (target != null && target.id != link.target) {
          bindings[link.target] = target.id;
        }
      }
      if (bindings.isNotEmpty) properties['orbitLinkBindings'] = bindings;
    }
    if (existing != null &&
        existing.title != object.title &&
        (properties['aliases'] == null || properties['aliases'] is List)) {
      properties['aliases'] = {
        ...?(properties['aliases'] as List?),
        existing.title,
      }.toList();
    }
    // Authored Markdown is never normalized by autosave. Identity bindings are
    // metadata, so saving cannot shift source selections or break editor undo.
    final saved = object.copyWith(
      properties: properties,
      revision: object.revision + 1,
      updatedAt: DateTime.now().toUtc(),
    );
    final path = _paths[object.id] ?? _newPath(object);
    final source = _codec.encode(saved, previousSource: _sources[object.id]);
    final bytes = _bytes(source);
    try {
      await _store.write(path, bytes, expectedHash: _hashes[object.id]);
    } on WorkspaceConflict {
      final recoveryPath =
          '.orbit/recovery/conflict-${const Uuid().v4()}.pending';
      try {
        await _store.write(recoveryPath, bytes, expectedHash: null);
      } on Object catch (error) {
        throw WorkspaceConflict(
          'The original file changed. The pending edit is still in the editor, but a recovery copy could not be written: $error',
        );
      }
      throw WorkspaceConflict(
        'The original file changed outside Orbit Note. Your pending version is preserved at $recoveryPath. Refresh to load the external version.',
        recoveryPath: recoveryPath,
      );
    }
    _objects[object.id] = saved;
    _paths[object.id] = path;
    _sources[object.id] = source;
    _hashes[object.id] = sha256.convert(bytes).toString();
    if (_indexReady) {
      try {
        await _index.upsert(saved);
      } on Object catch (error) {
        _indexReady = false;
        _addIssue('Saved locally; the search index needs rebuilding. $error');
      }
    }
    return saved;
  }

  Future<UniversalObject> trash(String id) => _serial(
    () => _save(_requireObject(id).copyWith(deletedAt: DateTime.now().toUtc())),
  );
  Future<UniversalObject> restore(String id) =>
      _serial(() => _save(_requireObject(id).copyWith(clearDeletedAt: true)));

  Future<void> deletePermanently(String id) => _serial(() async {
    _requireWritable();
    await _verifyManifest();
    final object = _objects[id];
    if (object == null) return;
    final path = _paths[id];
    if (path != null) {
      await _store.deleteFile(path);
    }
    _objects.remove(id);
    _paths.remove(id);
    _sources.remove(id);
    _hashes.remove(id);
    if (_indexReady) {
      try {
        await _index.replaceAll(objects);
      } on Object {
        _indexReady = false;
      }
    }
  });

  Future<void> emptyTrash() => _serial(() async {
    _requireWritable();
    await _verifyManifest();
    final trashed = _objects.values.where((o) => o.isDeleted).toList();
    for (final object in trashed) {
      final path = _paths[object.id];
      if (path != null) {
        await _store.deleteFile(path);
      }
      _objects.remove(object.id);
      _paths.remove(object.id);
      _sources.remove(object.id);
      _hashes.remove(object.id);
    }
    if (_indexReady) {
      try {
        await _index.replaceAll(objects);
      } on Object {
        _indexReady = false;
      }
    }
  });

  Future<List<UniversalObject>> search(String query) async {
    await _queue;
    _requireOpen();
    if (_indexReady) {
      try {
        final ids = await _index.search(query);
        return ids
            .map((id) => _objects[id])
            .whereType<UniversalObject>()
            .toList();
      } on Object {
        _indexReady = false;
      }
    }
    final lower = query.toLowerCase();
    return objects
        .where(
          (o) =>
              !o.isDeleted && searchableText(o).toLowerCase().contains(lower),
        )
        .toList();
  }

  Future<Map<String, dynamic>> readDeviceSettings() async {
    await _queue;
    _requireOpen();
    final bytes = await _store.read('.orbit/device/settings.json');
    if (bytes == null) return {};
    try {
      final doc = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (doc['version'] != 1) {
        _addIssue(
          'Device settings use an unsupported version; defaults are used.',
        );
        return {};
      }
      return Map<String, dynamic>.from(doc['data'] as Map);
    } on Object {
      _addIssue('Device settings could not be read; content is unaffected.');
      return {};
    }
  }

  Future<void> writeDeviceSettings(
    Map<String, dynamic> settings,
  ) => _serial(() async {
    _requireWritable();
    const path = '.orbit/device/settings.json';
    final before = await _store.read(path);
    if (before != null) {
      try {
        final old = jsonDecode(utf8.decode(before)) as Map;
        if (old['version'] != 1) {
          throw const WorkspaceReadOnly('Newer device settings are preserved.');
        }
      } on FormatException {
        throw const WorkspaceFailure(
          'Corrupt device settings are preserved; restore them before changing settings.',
        );
      }
    }
    await _store.write(
      path,
      _bytes(
        jsonEncode({
          'format': 'orbit-note-device-settings',
          'version': 1,
          'data': settings,
        }),
      ),
      expectedHash: before == null ? null : sha256.convert(before).toString(),
    );
  });

  Future<UniversalObject> importAttachment({
    required String name,
    required Uint8List bytes,
  }) => _serial(() async {
    _requireWritable();
    if (bytes.length > 100 * 1024 * 1024) {
      throw const WorkspaceFailure(
        'This first attachment importer accepts files up to 100 MB.',
      );
    }
    final checksum = sha256.convert(bytes).toString();
    final matches = objects.where(
      (o) =>
          o.typeId == 'orbit.file' &&
          o.properties['checksum'] == checksum &&
          !o.isDeleted,
    );
    if (matches.isNotEmpty) return matches.first;
    final safeName = _safeName(name);
    final path = 'Attachments/$checksum/$safeName';
    final old = await _store.read(path);
    if (old == null) {
      await _store.write(path, bytes, expectedHash: null);
    } else if (sha256.convert(old).toString() != checksum) {
      throw const WorkspaceConflict(
        'An attachment at this location has different bytes; it was not replaced.',
      );
    }
    // An interruption before metadata is written leaves recoverable ordinary
    // bytes, never a metadata record referencing a not-yet-written attachment.
    final now = DateTime.now().toUtc();
    return _save(
      UniversalObject(
        id: const Uuid().v4(),
        workspaceId: workspaceId,
        typeId: 'orbit.file',
        title: name,
        createdAt: now,
        updatedAt: now,
        revision: 0,
        properties: {
          'contentRef': path,
          'originalName': name,
          'mimeType': _mime(safeName),
          'byteLength': bytes.length,
          'checksum': checksum,
        },
      ),
    );
  });

  Future<Uint8List?> readAttachment(String relativePath) async {
    validateRelativePath(relativePath);
    if (!relativePath.startsWith('Attachments/')) {
      throw const WorkspaceFailure(
        'Attachment paths must be within Attachments/.',
      );
    }
    return _store.read(relativePath);
  }

  /// Portable documented JSON envelope containing original authoritative bytes.
  /// Device state, credentials and rebuildable SQLite/cache files are excluded.
  Future<String> exportBundle() => _serial(() async {
    _requireOpen();
    final directories = supportsFolders
        ? await (_store as WorkspaceFolderStore).listFolders()
        : <String>[];
    final files = <String, String>{};
    bool included(String path) =>
        !path.startsWith('.orbit/device/') &&
        !path.startsWith('.orbit/cache/') &&
        !path.startsWith('.orbit/workspace.sqlite');
    final paths = (await _store.listFiles()).where(included).toList();
    for (final path in paths) {
      validateRelativePath(path);
      final bytes = await _store.read(path);
      if (bytes == null) {
        throw const WorkspaceConflict(
          'A file disappeared during export. Retry after external changes finish.',
        );
      }
      files[path] = base64Encode(bytes);
    }
    for (final path in paths) {
      final bytes = await _store.read(path);
      if (bytes == null || base64Encode(bytes) != files[path]) {
        throw const WorkspaceConflict(
          'Files changed during export. Retry when the workspace is stable.',
        );
      }
    }
    final after = (await _store.listFiles()).where(included).toList();
    if (supportsFolders &&
        jsonEncode(await (_store as WorkspaceFolderStore).listFolders()) !=
            jsonEncode(directories)) {
      throw const WorkspaceConflict(
        'Folders changed during export. Retry when the Vault is stable.',
      );
    }
    if (jsonEncode(after) != jsonEncode(paths)) {
      throw const WorkspaceConflict(
        'Files were added during export. Retry when the workspace is stable.',
      );
    }
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'orbit-note-backup',
      'version': 1,
      'workspaceId': workspaceId,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'encoding': 'base64',
      'files': files,
      'directories': directories,
    });
  });

  Future<void> close() => _serial(() async {
    await _index.close();
    await _store.close();
    _initialized = false;
  });

  UniversalObject _requireObject(String id) =>
      _objects[id] ??
      (throw const WorkspaceFailure('This object is no longer available.'));
  void _requireOpen() {
    if (!_initialized) throw const WorkspaceFailure('Open a workspace first.');
  }

  void _requireWritable() {
    _requireOpen();
    if (_readOnly) {
      throw const WorkspaceReadOnly(
        'This workspace is read-only. Its files are preserved.',
      );
    }
  }

  void _validate(UniversalObject object) {
    if (object.workspaceId != workspaceId) {
      throw const WorkspaceFailure('Object belongs to another workspace.');
    }
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(object.id)) {
      throw const WorkspaceFailure('Object identity must be a UUID.');
    }
    if (object.isReadOnly) {
      throw const WorkspaceReadOnly(
        'This object uses a newer unsupported format.',
      );
    }
    if (object.title.trim().isEmpty) {
      throw const WorkspaceFailure('Give this object a title.');
    }
    if (object.typeId == 'orbit.task') {
      final completed = object.properties['completed'];
      final priority = object.properties['priority'];
      if (completed != null && completed is! bool) {
        throw const WorkspaceFailure('Task completed must be a boolean.');
      }
      if (priority != null &&
          !{
            'none',
            'low',
            'medium',
            'high',
            'urgent',
            0,
            1,
            2,
            3,
          }.contains(priority)) {
        throw const WorkspaceFailure('Unsupported task priority.');
      }
      final due = object.properties['dueDate'];
      if (due != null && (due is! String || DateTime.tryParse(due) == null)) {
        throw const WorkspaceFailure('Task due date must be an ISO date.');
      }
    }
    if (object.typeId == 'orbit.event') {
      EventSchedule.fromProperties(object.properties);
    }
    // JSON rejects non-finite geometry and unsupported runtime objects.
    jsonEncode({'object': object.toJson(), 'data': object.data});
  }

  String _newPath(UniversalObject object) => switch (object.typeId) {
    'orbit.note' => 'Notes/${_safeName(object.title)}-${object.id}.md',
    'orbit.canvas' => 'Boards/${object.id}.board.json',
    'orbit.drawing' => 'Drawings/${object.id}.drawing.json',
    _ => 'Objects/${object.id}.object.json',
  };
  String _safeName(String name) {
    var clean = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_').trim();
    clean = clean.replaceAll(RegExp(r'[. ]+$'), '');
    if (clean.length > 80) clean = clean.substring(0, 80);
    if (clean.isEmpty ||
        RegExp(
          r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)',
          caseSensitive: false,
        ).hasMatch(clean)) {
      clean = 'file_$clean';
    }
    return clean;
  }

  String _mime(String path) => switch (path.split('.').last.toLowerCase()) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'svg' => 'image/svg+xml',
    'pdf' => 'application/pdf',
    'txt' || 'md' => 'text/plain',
    _ => 'application/octet-stream',
  };
  void _addIssue(String issue) {
    if (!_issues.contains(issue)) _issues.add(issue);
  }

  Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));
}
