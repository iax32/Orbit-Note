import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../domain/writing_photo.dart';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

import '../domain/calendar_event.dart';
import '../domain/calendar_planning.dart';
import '../domain/event_recurrence.dart';
import '../domain/smart_view_query.dart';
import '../domain/task_planning.dart';
import '../domain/object_tombstone.dart';
import '../domain/universal_object.dart';
import '../domain/wiki_links.dart';
import '../domain/note_path_links.dart';
import '../domain/search_text.dart';
import '../domain/pdf_search.dart';
import '../domain/ocr_document.dart';
import '../domain/study_card.dart';
import 'search_execution.dart';
import '../domain/workspace_failure.dart';
import '../infrastructure/storage/index_factory.dart';
import '../infrastructure/storage/object_codec.dart';
import '../infrastructure/storage/object_index.dart';
import '../infrastructure/storage/path_safety.dart';
import '../infrastructure/storage/store_factory.dart';
import '../infrastructure/storage/workspace_store.dart';
import '../infrastructure/storage/workspace_sync_state_store.dart';
import 'workspace_deletions.dart';
import 'workspace_recovery.dart';
import 'sync/sync_inventory.dart';
import 'sync/sync_policy.dart';
import 'sync/sync_provider.dart';
import '../domain/sync_entry.dart';

part 'sync/workspace_sync_replica.dart';
part 'workspace_folders.dart';

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
  int _syncGeneration = 0;
  bool _indexReady = false;
  bool _readOnly = false;
  String _workspaceId = '';
  String _name = '';
  String? _manifestHash;
  List<String> _folders = const ['Notes'];
  static const maxAttachmentRecoveryBytes = 100 * 1024 * 1024;
  List<String> get folders => List.unmodifiable(_folders);
  bool get supportsFolders => _store is WorkspaceFolderStore;
  String? objectPath(String id) => _paths[id];

  Future<PdfTextDocument?> readPdfTextCache(String id) async {
    if (_index is! PdfTextCache || !_indexReady) return null;
    try {
      return PdfTextDocument.parse(
        await (_index as PdfTextCache).readPdfText(id),
      );
    } on Object {
      return null;
    }
  }

  Future<void> writePdfTextCache(String id, PdfTextDocument document) async {
    if (_index is PdfTextCache && _indexReady) {
      await (_index as PdfTextCache).writePdfText(id, document.toJson());
    } else {
      throw const WorkspaceFailure('PDF cache is unavailable.');
    }
  }

  Future<void> removePdfTextCache(String id) async {
    if (_index is PdfTextCache && _indexReady) {
      await (_index as PdfTextCache).removePdfText(id);
    }
  }

  Future<String?> pdfSourceChecksum(String path) async {
    validateRelativePath(path);
    if (!path.startsWith('Attachments/')) {
      throw const WorkspaceFailure('Invalid PDF attachment path.');
    }
    final store = _store;
    if (store is WorkspaceFileSizeStore) {
      final int size;
      try {
        size = await (store as WorkspaceFileSizeStore).fileSize(path);
      } on Object {
        return null;
      }
      if (size > maxAttachmentRecoveryBytes) {
        throw const WorkspaceFailure(
          'PDF exceeds the 100 MB attachment limit.',
        );
      }
    }
    var read = 0;
    return (await _inspectStoredAttachment(
      path,
      onProgress: (n, _, _) => read = n,
      isCancelled: () => read > maxAttachmentRecoveryBytes,
    ))?.checksum;
  }

  Future<Uint8List> readPdfSearchSource(String path) async {
    validateRelativePath(path);
    if (!path.startsWith('Attachments/')) {
      throw const WorkspaceFailure('Invalid PDF attachment path.');
    }
    final store = _store;
    if (store is WorkspaceFileSizeStore &&
        await (store as WorkspaceFileSizeStore).fileSize(path) >
            maxAttachmentRecoveryBytes) {
      throw const WorkspaceFailure('PDF exceeds the 100 MB attachment limit.');
    }
    final bytes = await readAttachment(path);
    if (bytes == null) {
      throw const WorkspaceFailure('PDF attachment is missing.');
    }
    if (bytes.length > maxAttachmentRecoveryBytes) {
      throw const WorkspaceFailure('PDF exceeds the 100 MB attachment limit.');
    }
    return bytes;
  }

  /// Verifies an attachment without materializing large retained sources.
  /// Native stores stream from disk; small/portable stores use their existing
  /// bounded read implementation.
  Future<({int length, String checksum})?> _inspectStoredAttachment(
    String path, {
    void Function(int bytesRead, int totalBytes, String phase)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final store = _store;
    if (store is WorkspaceStreamingStore && store is WorkspaceFileSizeStore) {
      late final int total;
      try {
        total = await (store as WorkspaceFileSizeStore).fileSize(path);
      } on Object {
        return null;
      }
      var length = 0;
      try {
        final digest = await sha256
            .bind(
              (store as WorkspaceStreamingStore).openRead(path).map((chunk) {
                if (isCancelled?.call() == true) {
                  throw const WorkspaceFailure(
                    'Attachment recovery was cancelled.',
                  );
                }
                length += chunk.length;
                onProgress?.call(length, total, 'Verifying retained source…');
                return chunk;
              }),
            )
            .first;
        if (length != total) return null;
        onProgress?.call(length, total, 'Verification complete');
        return (length: length, checksum: digest.toString());
      } on Object {
        return null;
      }
    }
    final bytes = await store.read(path);
    if (bytes == null) return null;
    if (isCancelled?.call() == true) {
      throw const WorkspaceFailure('Attachment recovery was cancelled.');
    }
    onProgress?.call(bytes.length, bytes.length, 'Verification complete');
    return (length: bytes.length, checksum: sha256.convert(bytes).toString());
  }

  Future<void> createFolder(String path) {
    final generation = _syncGeneration, owner = workspaceId;
    return _serial(() async {
      _requireWritable();
      if (generation != _syncGeneration || owner != workspaceId) {
        throw const WorkspaceFailure(
          'The Vault changed before folder creation.',
        );
      }
      await _verifyManifest();
      await (_store as WorkspaceFolderStore).createFolder(path);
      _folders = await (_store as WorkspaceFolderStore).listFolders();
    });
  }

  Future<void> deleteFolder(String folder) =>
      _ownedOrganization(() => _changeFolder(folder, null));

  Future<void> moveNote(String id, String folder) {
    if (_objects[id]?.typeId != 'orbit.note') {
      return Future.error(
        const WorkspaceFailure(
          'Only text-backed notes can be moved through moveNote.',
        ),
      );
    }
    return moveObjectsToFolder([id], folder);
  }

  Future<void> moveFolder(String source, String target) =>
      _ownedOrganization(() => _changeFolder(source, target));
  List<UniversalObject> get objects => List.unmodifiable(_objects.values);
  Future<SyncInventory> syncInventory() => _serial(() async {
    _requireWritable();
    await _verifyManifest();
    return captureSyncInventory(_store, workspaceId);
  });

  bool get supportsFileSync =>
      _store is WorkspaceStreamingStore &&
      _store is WorkspaceStagingStore &&
      !_store.isBrowser;

  /// File-size metadata only: opening Settings never rehashes large attachments.
  Future<SyncFootprint> syncFootprint() => _serial(() async {
    final store = _store;
    var count = 0, bytes = 0, largest = 0;
    for (final path in await store.listFiles()) {
      final role = syncPathRole(path);
      if (role == SyncPathRole.excluded || role == SyncPathRole.unsupported) {
        continue;
      }
      final size = store is WorkspaceFileSizeStore
          ? await (store as WorkspaceFileSizeStore).fileSize(path)
          : (await store.read(path))?.length ?? 0;
      count++;
      bytes += size;
      if (size > largest) largest = size;
    }
    return SyncFootprint(count, bytes, largest);
  });
  List<String> get issues => List.unmodifiable(_issues);

  /// Metadata only on native stores. Safe to use while a Vault is read-only.
  Future<List<WorkspaceRecoveryFile>> recoveryFiles() => _serial(() async {
    _requireOpen();
    final paths =
        (await _store.listFiles())
            .where(WorkspaceRecoveryFile.acceptsPath)
            .toList()
          ..sort();
    final files = <WorkspaceRecoveryFile>[];
    for (final path in paths) {
      validateRelativePath(path);
      final store = _store;
      final length = store is WorkspaceFileSizeStore
          ? await (store as WorkspaceFileSizeStore).fileSize(path)
          : (await store.read(path))?.length ?? 0;
      files.add(WorkspaceRecoveryFile(path: path, length: length));
    }
    return List.unmodifiable(files);
  });

  /// Read a bounded immutable copy. Recovery never executes imported journals.
  Future<WorkspaceRecoverySnapshot> readRecoveryFile(
    String path,
  ) => _serial(() async {
    _requireOpen();
    validateRelativePath(path);
    if (!WorkspaceRecoveryFile.acceptsPath(path)) {
      throw const WorkspaceFailure('Choose a retained recovery file.');
    }
    const maxBytes = 16 * 1024 * 1024;
    final store = _store;
    if (store is WorkspaceFileSizeStore &&
        await (store as WorkspaceFileSizeStore).fileSize(path) > maxBytes) {
      throw const WorkspaceFailure(
        'Recovery file exceeds the 16 MiB review limit. Copy it from the Vault folder or export a full backup.',
      );
    }
    Uint8List? bytes;
    if (store is WorkspaceStreamingStore) {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in (store as WorkspaceStreamingStore).openRead(
        path,
      )) {
        if (builder.length + chunk.length > maxBytes) {
          throw const WorkspaceFailure(
            'Recovery file exceeds the 16 MiB review limit.',
          );
        }
        builder.add(chunk);
      }
      bytes = builder.takeBytes();
    } else {
      bytes = await store.read(path);
    }
    if (bytes == null) {
      throw const WorkspaceFailure(
        'This recovery file is no longer available. Refresh the list.',
      );
    }
    if (bytes.length > maxBytes) {
      throw const WorkspaceFailure(
        'Recovery file exceeds the 16 MiB review limit.',
      );
    }
    return WorkspaceRecoverySnapshot(path: path, bytes: bytes);
  });

  String get workspaceId => _workspaceId;
  String get name => _name;
  String get location => _store.location;
  bool get readOnly => _readOnly;
  bool get isBrowser => _store.isBrowser;
  Stream<String> get externalFileChanges => _store is WorkspaceChangeSource
      ? (_store as WorkspaceChangeSource).changes
      : const Stream.empty();
  Stream<String> get externalAttachmentChanges =>
      _store is WorkspaceAttachmentChangeSource
      ? (_store as WorkspaceAttachmentChangeSource).attachmentChanges
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
    _syncGeneration++;
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
    if (!_readOnly) {
      try {
        await WorkspaceDeletions(_store, workspaceId).recover();
      } on Object catch (error) {
        _readOnly = true;
        _addIssue(
          'An interrupted deletion needs review. All remaining files are preserved. $error',
        );
      }
    }
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
    final tombstones = <String>{};
    for (final path in await _store.listFiles()) {
      if (WorkspaceDeletions.isJournal(path)) {
        _readOnly = true;
        _addIssue(
          'An interrupted deletion is retained at $path. Reopen the Vault to retry recovery.',
        );
      }
      if (path.startsWith('.orbit/tombstones/')) {
        try {
          final bytes = await _store.read(path);
          final record = ObjectTombstone.fromJson(
            jsonDecode(utf8.decode(bytes!)) as Map<String, dynamic>,
          );
          if (record.workspaceId != workspaceId || record.storagePath != path) {
            throw const FormatException('Tombstone identity mismatch.');
          }
          tombstones.add(record.objectId);
        } on Object catch (error) {
          _readOnly = true;
          _addIssue(
            'An unsupported deletion record is preserved at $path. $error',
          );
        }
        continue;
      }
      if (path.startsWith('.orbit/recovery/') && path.endsWith('.move.json')) {
        _readOnly = true;
        _addIssue(
          'An interrupted folder move needs recovery review at $path. Vault opened read-only to preserve all versions.',
        );
      }
      if (path.startsWith('.orbit/recovery/') &&
          path.endsWith('.folder.json')) {
        _readOnly = true;
        _addIssue(
          'An interrupted folder command needs recovery at $path. Reopen the Vault; changed files are preserved.',
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
    if (objects.keys.any(tombstones.contains)) {
      _readOnly = true;
      _addIssue(
        'An object and its permanent deletion record both exist. Both are preserved for review.',
      );
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
  }) {
    final generation = _syncGeneration, owner = workspaceId;
    final now = DateTime.now().toUtc();
    // Freeze caller-owned containers before waiting behind another command.
    final candidate = UniversalObject(
      id: const Uuid().v4(),
      workspaceId: owner,
      typeId: typeId,
      title: title,
      body: body,
      properties: properties,
      data: data,
      createdAt: now,
      updatedAt: now,
      revision: 0,
    );
    return _serial(() async {
      _requireWritable();
      if (generation != _syncGeneration || owner != workspaceId) {
        throw const WorkspaceFailure(
          'The Vault changed before object creation.',
        );
      }
      return _save(candidate);
    });
  }

  Future<UniversalObject> save(UniversalObject object) =>
      _serial(() => _save(object));
  Future<UniversalObject> _save(UniversalObject object) async {
    _requireWritable();
    await _verifyManifest();
    _validate(object);
    final existing = _objects[object.id];
    validateEventRecurrence(object, previous: existing);
    if (object.properties['calendarPlan'] != null &&
        jsonEncode(object.properties['calendarPlan']) !=
            jsonEncode(existing?.properties['calendarPlan'])) {
      validateCalendarPlan(object.properties['calendarPlan'], object.typeId);
    }
    if (object.properties['studyCard'] != null &&
        jsonEncode(object.properties['studyCard']) !=
            jsonEncode(existing?.properties['studyCard'])) {
      if (object.typeId != 'orbit.note') {
        throw const FormatException('Study cards must be Markdown notes.');
      }
      StudyCard.validate(object.properties['studyCard']);
    }
    if (object.properties['studyUnderstanding'] !=
            existing?.properties['studyUnderstanding'] &&
        object.properties['studyUnderstanding'] != null &&
        !studyUnderstandingStates.contains(
          object.properties['studyUnderstanding'],
        )) {
      throw const FormatException('Invalid understanding state.');
    }
    if (object.properties['ocr'] != null &&
        jsonEncode(object.properties['ocr']) !=
            jsonEncode(existing?.properties['ocr'])) {
      OcrDocument.validate(object.properties['ocr']);
      final recognition = OcrDocument.parse(object.properties['ocr'])!;
      if (object.typeId != 'orbit.file' ||
          recognition.path != object.properties['contentRef'] ||
          await pdfSourceChecksum(recognition.path) != recognition.checksum) {
        throw const WorkspaceConflict(
          'The attachment changed. Recognition was not saved.',
        );
      }
    }
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

  // Organization/lifecycle commands may wait behind a Vault reopen in the queue.
  // Even reopening the same identity retires the old intent.
  Future<T> _ownedOrganization<T>(Future<T> Function() command) {
    final generation = _syncGeneration, owner = workspaceId;
    return _serial(() {
      if (generation != _syncGeneration || owner != workspaceId) {
        throw const WorkspaceFailure(
          'The Vault changed before this operation.',
        );
      }
      return command();
    });
  }

  Future<UniversalObject> trash(String id) => _ownedOrganization(
    () => _save(_requireObject(id).copyWith(deletedAt: DateTime.now().toUtc())),
  );
  Future<UniversalObject> restore(String id) => _ownedOrganization(
    () => _save(_requireObject(id).copyWith(clearDeletedAt: true)),
  );

  Future<void> deletePermanently(String id) => _ownedOrganization(() async {
    _requireWritable();
    await _verifyManifest();
    final object = _objects[id];
    if (object == null) return;
    _validate(object);
    try {
      await WorkspaceDeletions(
        _store,
        workspaceId,
      ).delete(id, _paths[id]!, _hashes[id]!);
    } finally {
      await _refresh();
    }
  });

  Future<void> emptyTrash({Iterable<String>? ids}) {
    final selected =
        (ids ?? _objects.values.where((o) => o.isDeleted).map((o) => o.id))
            .toSet();
    return _ownedOrganization(() async {
      _requireWritable();
      await _verifyManifest();
      final trashed = _objects.values
          .where((o) => selected.contains(o.id) && o.isDeleted)
          .toList();
      try {
        for (final object in trashed) {
          _validate(object);
          await WorkspaceDeletions(
            _store,
            workspaceId,
          ).delete(object.id, _paths[object.id]!, _hashes[object.id]!);
        }
      } finally {
        await _refresh();
      }
    });
  }

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
    final lower = query.trim().toLowerCase();
    final snapshot = objects;
    return runSearchWork(
      () => snapshot
          .where(
            (o) =>
                !o.isDeleted && searchableText(o).toLowerCase().contains(lower),
          )
          .toList(),
      size: snapshot.fold<int>(0, (size, o) => size + o.body.length + 256),
    );
  }

  Future<String> saveDeviceWritingPhoto(
    Uint8List bytes, {
    required String expectedWorkspace,
  }) {
    validateWritingPhotoBytes(bytes);
    final copy = Uint8List.fromList(bytes);
    final id = sha256.convert(copy).toString();
    return _serial(() async {
      _requireWritable();
      if (workspaceId != expectedWorkspace) {
        throw const WorkspaceFailure(
          'The Vault changed before saving the background.',
        );
      }
      final path = '.orbit/device/writing-backgrounds/$id.png';
      final old = (await _store.listFiles()).contains(path)
          ? await _readStoredWritingPhoto(id)
          : null;
      if (old != null) {
        if (sha256.convert(old).toString() != id) {
          throw const WorkspaceFailure(
            'The saved background is damaged; choose another photo.',
          );
        }
        return id;
      }
      await _store.write(path, copy, expectedHash: null);
      return id;
    });
  }

  Future<Uint8List?> readDeviceWritingPhoto(
    String id, {
    required String expectedWorkspace,
  }) => _serial(() async {
    _requireOpen();
    if (!WritingPhoto.validId(id) || workspaceId != expectedWorkspace) {
      throw const WorkspaceFailure(
        'The background reference is unavailable in this Vault.',
      );
    }
    return _readStoredWritingPhoto(id);
  });

  Future<Uint8List?> _readStoredWritingPhoto(String id) async {
    final path = '.orbit/device/writing-backgrounds/$id.png';
    final store = _store;
    if (store is WorkspaceFileSizeStore &&
        await (store as WorkspaceFileSizeStore).fileSize(path) >
            WritingPhoto.maxBytes) {
      throw const WorkspaceFailure('The saved background exceeds its limit.');
    }
    Uint8List? bytes;
    if (store is WorkspaceStreamingStore) {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in (store as WorkspaceStreamingStore).openRead(
        path,
      )) {
        if (builder.length + chunk.length > WritingPhoto.maxBytes) {
          throw const WorkspaceFailure(
            'The saved background exceeds its limit.',
          );
        }
        builder.add(chunk);
      }
      bytes = builder.takeBytes();
    } else {
      bytes = await store.read(path);
    }
    if (bytes == null) return null;
    validateWritingPhotoBytes(bytes);
    if (sha256.convert(bytes).toString() != id) {
      throw const WorkspaceFailure('The saved background is damaged.');
    }
    return Uint8List.fromList(bytes);
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
  }) {
    if (bytes.length > 100 * 1024 * 1024) {
      return Future.error(
        const WorkspaceFailure(
          'This first attachment importer accepts files up to 100 MB.',
        ),
      );
    }
    final generation = _syncGeneration, owner = workspaceId;
    // Hashing and writes must observe the same bytes even while queued.
    final snapshot = Uint8List.fromList(bytes);
    return _serial(() async {
      if (generation != _syncGeneration || workspaceId != owner) {
        throw const WorkspaceFailure(
          'The Vault changed before attachment import. Try importing again.',
        );
      }
      _requireWritable();
      final checksum = sha256.convert(snapshot).toString();
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
        await _store.write(path, snapshot, expectedHash: null);
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
            'byteLength': snapshot.length,
            'checksum': checksum,
          },
        ),
      );
    });
  }

  Future<Uint8List?> readAttachment(String relativePath) async {
    validateRelativePath(relativePath);
    if (!relativePath.startsWith('Attachments/')) {
      throw const WorkspaceFailure(
        'Attachment paths must be within Attachments/.',
      );
    }
    return _store.read(relativePath);
  }

  Future<Uint8List> _bufferAttachmentStream(
    Stream<List<int>> bytes, {
    required String expectedChecksum,
    required void Function(int bytesRead)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final builder = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in bytes) {
      if (isCancelled?.call() == true) {
        throw const WorkspaceFailure('Attachment recovery was cancelled.');
      }
      length += chunk.length;
      if (length > maxAttachmentRecoveryBytes) {
        throw const WorkspaceFailure('Choose a file no larger than 100 MB.');
      }
      builder.add(chunk);
      onProgress?.call(length);
    }
    final value = builder.takeBytes();
    if (sha256.convert(value).toString() != expectedChecksum) {
      throw const WorkspaceFailure(
        'The selected bytes do not match the expected checksum.',
      );
    }
    return value;
  }

  /// Restore missing original bytes only after checking their recorded hash.
  /// Never replaces an existing file or rewrites authored references.
  Future<void> recoverMissingAttachment(
    String reference,
    Uint8List bytes, {
    required String expectedChecksum,
  }) => _serial(() async {
    _requireWritable();
    await _verifyManifest();
    validateRelativePath(reference);
    if (!reference.startsWith('Attachments/') ||
        bytes.length > 100 * 1024 * 1024 ||
        sha256.convert(bytes).toString() != expectedChecksum) {
      throw const WorkspaceFailure(
        'Choose the original file matching the recorded checksum. Different bytes must be attached as a new source.',
      );
    }
    await _store.write(reference, bytes, expectedHash: null);
  });

  /// Streams a verified source into the missing original path. Native stores
  /// stage directly to disk; browser stores use a bounded compatibility buffer.
  Future<void> recoverMissingAttachmentStream(
    String reference,
    Stream<List<int>> bytes, {
    required String expectedChecksum,
    void Function(int bytesRead)? onProgress,
    String? resumableStageId,
    bool Function()? isCancelled,
  }) => _serial(() async {
    _requireWritable();
    await _verifyManifest();
    validateRelativePath(reference);
    if (!reference.startsWith('Attachments/')) {
      throw const WorkspaceFailure(
        'Attachment paths must stay in Attachments/.',
      );
    }
    final store = _store;
    if (store is WorkspaceAttachmentStagingStore ||
        store is WorkspaceStagingStore) {
      final stage = store is WorkspaceAttachmentStagingStore
          ? resumableStageId == null
                ? await (store as WorkspaceAttachmentStagingStore)
                      .stageAttachment(
                        bytes,
                        info: WorkspaceAttachmentStageInfo(
                          id: const Uuid().v4(),
                          operation: 'restore',
                          target: reference,
                          expectedHash: expectedChecksum,
                          maxBytes: maxAttachmentRecoveryBytes,
                          length: 0,
                        ),
                        onProgress: onProgress,
                        isCancelled: isCancelled,
                      )
                : await (store as WorkspaceAttachmentStagingStore)
                      .resumeAttachmentStage(
                        resumableStageId,
                        bytes,
                        onProgress: onProgress,
                        isCancelled: isCancelled,
                      )
          : await (store as WorkspaceStagingStore).stage(
              bytes,
              expectedHash: expectedChecksum,
              maxBytes: maxAttachmentRecoveryBytes,
              onProgress: onProgress,
              isCancelled: isCancelled,
            );
      try {
        if (isCancelled?.call() == true) {
          throw const WorkspaceFailure('Attachment recovery was cancelled.');
        }
        await _verifyManifest();
        if (stage.hash != expectedChecksum) {
          throw const WorkspaceConflict(
            'The interrupted transfer checksum no longer matches this source.',
          );
        }
        await stage.commit(reference, expectedHash: null, checkCurrent: () {});
      } finally {
        await stage.close();
      }
      return;
    }
    final value = await _bufferAttachmentStream(
      bytes,
      expectedChecksum: expectedChecksum,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
    await _store.write(reference, value, expectedHash: null);
  });

  /// Commits a new immutable source before changing the existing file identity.
  /// Older bytes remain ordinary files and raw Markdown paths remain literal.
  Future<UniversalObject> relinkAttachment(
    UniversalObject expected, {
    required String name,
    required Uint8List bytes,
  }) => _serial(() async {
    _requireAttachmentSnapshot(expected);
    await _verifyManifest();
    if (bytes.length > 100 * 1024 * 1024) {
      throw const WorkspaceFailure('Choose a file no larger than 100 MB.');
    }
    final checksum = sha256.convert(bytes).toString();
    final path = 'Attachments/$checksum/${_safeName(name)}';
    final old = await _store.read(path);
    if (old == null) {
      await _store.write(path, bytes, expectedHash: null);
    } else if (sha256.convert(old).toString() != checksum) {
      throw const WorkspaceConflict(
        'The new source path contains different bytes.',
      );
    }
    return _changeAttachmentSource(expected, {
      'contentRef': path,
      'originalName': name,
      'mimeType': _mime(_safeName(name)),
      'byteLength': bytes.length,
      'checksum': checksum,
    });
  });

  /// Streams a verified new source before updating the stable file object.
  Future<UniversalObject> relinkAttachmentStream(
    UniversalObject expected, {
    required String name,
    required String expectedChecksum,
    required Stream<List<int>> bytes,
    void Function(int bytesRead)? onProgress,
    String? resumableStageId,
    bool Function()? isCancelled,
  }) => _serial(() async {
    _requireAttachmentSnapshot(expected);
    await _verifyManifest();
    final checksum = expectedChecksum;
    final path = 'Attachments/$checksum/${_safeName(name)}';
    final store = _store;
    var byteLength = 0;
    if (store is WorkspaceAttachmentStagingStore ||
        store is WorkspaceStagingStore) {
      final stage = store is WorkspaceAttachmentStagingStore
          ? resumableStageId == null
                ? await (store as WorkspaceAttachmentStagingStore)
                      .stageAttachment(
                        bytes,
                        info: WorkspaceAttachmentStageInfo(
                          id: const Uuid().v4(),
                          operation: 'relink',
                          target: path,
                          expectedHash: checksum,
                          maxBytes: maxAttachmentRecoveryBytes,
                          length: 0,
                          sourceName: name,
                        ),
                        onProgress: onProgress,
                        isCancelled: isCancelled,
                      )
                : await (store as WorkspaceAttachmentStagingStore)
                      .resumeAttachmentStage(
                        resumableStageId,
                        bytes,
                        onProgress: onProgress,
                        isCancelled: isCancelled,
                      )
          : await (store as WorkspaceStagingStore).stage(
              bytes,
              expectedHash: checksum,
              maxBytes: maxAttachmentRecoveryBytes,
              onProgress: onProgress,
              isCancelled: isCancelled,
            );
      byteLength = stage.length;
      try {
        if (stage.hash != checksum) {
          throw const WorkspaceConflict(
            'The interrupted transfer checksum no longer matches this source.',
          );
        }
        final old = await _store.read(path);
        if (old == null) {
          await stage.commit(path, expectedHash: null, checkCurrent: () {});
        } else if (sha256.convert(old).toString() != checksum) {
          throw const WorkspaceConflict(
            'The new source path contains different bytes.',
          );
        }
      } finally {
        await stage.close();
      }
    } else {
      final value = await _bufferAttachmentStream(
        bytes,
        expectedChecksum: checksum,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
      byteLength = value.length;
      final old = await _store.read(path);
      if (old == null) {
        await _store.write(path, value, expectedHash: null);
      } else if (sha256.convert(old).toString() != checksum) {
        throw const WorkspaceConflict(
          'The new source path contains different bytes.',
        );
      }
    }
    return _changeAttachmentSource(expected, {
      'contentRef': path,
      'originalName': name,
      'mimeType': _mime(_safeName(name)),
      'byteLength': byteLength,
      'checksum': checksum,
    });
  });

  /// Lists native attachment stages left by an interrupted transfer. Browser
  /// stores use the bounded compatibility path and therefore return none.
  Future<List<WorkspaceAttachmentStageInfo>> attachmentRecoveryStages({
    String? target,
  }) => _serial(() async {
    final store = _store;
    if (store is! WorkspaceAttachmentStagingStore) return const [];
    await _verifyManifest();
    final stages = await (store as WorkspaceAttachmentStagingStore)
        .listAttachmentStages();
    return target == null
        ? stages
        : stages.where((stage) => stage.target == target).toList();
  });

  Future<void> discardAttachmentRecoveryStage(String id) => _serial(() async {
    final store = _store;
    if (store is! WorkspaceAttachmentStagingStore) return;
    await _verifyManifest();
    await (store as WorkspaceAttachmentStagingStore).discardAttachmentStage(id);
  });

  Future<UniversalObject> restoreAttachmentSource(
    UniversalObject expected,
    String reference, {
    void Function(int bytesRead, int totalBytes, String phase)? onProgress,
    bool Function()? isCancelled,
  }) => _serial(() async {
    _requireAttachmentSnapshot(expected);
    await _verifyManifest();
    final raw = expected.properties['attachmentSourceHistory'];
    final entries = raw is List
        ? raw
              .whereType<Map>()
              .where((e) => e['contentRef'] == reference)
              .toList()
        : <Map>[];
    if (entries.length != 1) {
      throw const WorkspaceFailure('Choose one retained source version.');
    }
    final source = entries.single;
    validateRelativePath(reference);
    if (!reference.startsWith('Attachments/')) {
      throw const WorkspaceFailure(
        'Source versions must stay inside Attachments/.',
      );
    }
    final inspected = await _inspectStoredAttachment(
      reference,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
    if (inspected == null || inspected.checksum != source['checksum']) {
      throw const WorkspaceConflict(
        'The retained source is missing or changed. Restore its original bytes first.',
      );
    }
    return _changeAttachmentSource(expected, {
      for (final key in _attachmentSourceKeys) key: source[key],
    });
  });

  /// Removes one retained source record and deletes its bytes only when no
  /// other file object still references that immutable path.
  Future<UniversalObject> forgetAttachmentSourceVersion(
    UniversalObject expected,
    String reference, {
    void Function(int bytesRead, int totalBytes, String phase)? onProgress,
    bool Function()? isCancelled,
  }) => _serial(() async {
    _requireAttachmentSnapshot(expected);
    await _verifyManifest();
    if (expected.properties['contentRef'] == reference) {
      throw const WorkspaceFailure(
        'The active source cannot be removed from history.',
      );
    }
    final raw = expected.properties['attachmentSourceHistory'];
    final history = raw is List ? raw.whereType<Map>().toList() : <Map>[];
    final removed = history
        .where((entry) => entry['contentRef'] == reference)
        .toList();
    if (removed.length != 1) {
      throw const WorkspaceFailure('Choose one retained source version.');
    }
    final referencedElsewhere = _objects.values.any(
      (object) =>
          object.id != expected.id &&
          object.typeId == 'orbit.file' &&
          object.properties['contentRef'] == reference &&
          !object.isDeleted,
    );
    if (referencedElsewhere) {
      throw const WorkspaceConflict(
        'This source is still used by another file object and cannot be cleaned up.',
      );
    }
    final inspected = await _inspectStoredAttachment(
      reference,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
    if (inspected == null || inspected.checksum != removed.single['checksum']) {
      throw const WorkspaceConflict(
        'The retained source is missing or changed; its history was preserved.',
      );
    }
    final nextHistory = history
        .where((entry) => entry['contentRef'] != reference)
        .toList();
    final saved = await _save(
      expected.copyWith(
        properties: {
          ...expected.properties,
          'attachmentSourceHistory': nextHistory,
        },
      ),
    );
    await _store.deleteFile(reference, expectedHash: inspected.checksum);
    return saved;
  });

  static const _attachmentSourceKeys = {
    'contentRef',
    'originalName',
    'mimeType',
    'byteLength',
    'checksum',
  };

  void _requireAttachmentSnapshot(UniversalObject expected) {
    _requireWritable();
    final current = _requireObject(expected.id);
    if (current.typeId != 'orbit.file' ||
        current.isDeleted ||
        current.revision != expected.revision ||
        jsonEncode(current.toJson()) != jsonEncode(expected.toJson())) {
      throw const WorkspaceConflict(
        'The attachment changed while recovery was open. Reopen it before continuing.',
      );
    }
    final history = current.properties['attachmentSourceHistory'];
    if (history != null &&
        (history is! List || history.any((e) => e is! Map))) {
      throw const WorkspaceReadOnly(
        'Unrecognized source history is preserved.',
      );
    }
  }

  Future<UniversalObject> _changeAttachmentSource(
    UniversalObject expected,
    Map<String, dynamic> source,
  ) {
    final history = [
      ...?(expected.properties['attachmentSourceHistory'] as List?),
    ];
    final previous = {
      for (final key in _attachmentSourceKeys) key: expected.properties[key],
      'recordedAt': DateTime.now().toUtc().toIso8601String(),
    };
    // One entry per immutable path; no retained or unknown history is discarded.
    if (!history.whereType<Map>().any(
      (e) => e['contentRef'] == previous['contentRef'],
    )) {
      history.add(previous);
    }
    return _save(
      expected.copyWith(
        properties: {
          ...expected.properties,
          ...source,
          'attachmentSourceHistory': history,
        },
      ),
    );
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
    _syncGeneration++;
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
      validateTaskPlanning(
        object,
        _objects.values,
        previous: _objects[object.id],
      );
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
    if (object.typeId == 'orbit.view' &&
        object.properties['smartQuery'] != null) {
      final raw = object.properties['smartQuery'];
      if (raw is! Map) {
        throw const FormatException('Unreadable Smart View query.');
      }
      SmartViewQuery(Map<String, dynamic>.from(raw));
    }
    // JSON rejects non-finite geometry and unsupported runtime objects.
    jsonEncode({'object': object.toJson(), 'data': object.data});
  }

  String _newPath(UniversalObject object) {
    final folder = object.properties['folder'] as String?;
    final safeTitle = _safeName(object.title);
    if (object.typeId == 'orbit.note') {
      if (folder != null && folder.isNotEmpty && folder != 'Notes') {
        final effectiveFolder = folder.startsWith('Notes/')
            ? folder
            : 'Notes/$folder';
        return '$effectiveFolder/$safeTitle-${object.id}.md';
      }
      return 'Notes/$safeTitle-${object.id}.md';
    }
    return switch (object.typeId) {
      'orbit.canvas' => 'Boards/${object.id}.board.json',
      'orbit.drawing' => 'Drawings/${object.id}.drawing.json',
      _ => 'Objects/${object.id}.object.json',
    };
  }

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
