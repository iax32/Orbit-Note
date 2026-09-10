import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../domain/workspace_failure.dart';
import 'path_safety.dart';
import 'native_path_moves.dart';
import 'workspace_store.dart';

WorkspaceStore createWorkspaceStore() =>
    NativeWorkspaceStore(rememberWorkspace: true);

class NativeWorkspaceStore
    implements
        WorkspaceStore,
        WorkspaceSelectionStore,
        WorkspaceChangeSource,
        WorkspaceFolderStore {
  NativeWorkspaceStore({
    this.rememberWorkspace = false,
    this.selectionFilePath,
    this.historyMaxEntries = 200,
    this.historyMaxBytes = 64 * 1024 * 1024,
    this.historyMaxAge = const Duration(days: 30),
  });
  final bool rememberWorkspace;
  final String? selectionFilePath;
  final int historyMaxEntries, historyMaxBytes;
  final Duration historyMaxAge;
  Future<File> _selectionFile() async => File(
    selectionFilePath ??
        p.join(
          (await getApplicationSupportDirectory()).path,
          'selected-workspace.json',
        ),
  );

  @override
  Future<void> rememberSelection() async {
    if (!rememberWorkspace) return;
    final file = await _selectionFile();
    final previous = await _readSelection();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.${const Uuid().v4()}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        ...previous,
        'version': 1,
        'path': _root.path,
        'closed': false,
        'recent': {_root.path, ...await recentLocations()}.take(12).toList(),
      }),
      flush: true,
    );
    await temporary.rename(file.path);
  }

  Future<Map<String, dynamic>> _readSelection() async {
    final file = await _selectionFile();
    if (!await file.exists()) return {};
    final value = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (value['version'] != 1) {
      throw const WorkspaceFailure('Newer Vault preferences are preserved.');
    }
    return value;
  }

  @override
  Future<List<String>> recentLocations() async {
    if (!rememberWorkspace) return [];
    final saved = await _readSelection();
    return {
      if (saved['path'] is String) saved['path'] as String,
      if (saved['recent'] is List)
        ...(saved['recent'] as List).whereType<String>(),
    }.take(12).toList();
  }

  @override
  Future<void> clearSelection() async {
    if (!rememberWorkspace) return;
    final saved = await _readSelection();
    final file = await _selectionFile();
    final temp = File('${file.path}.${const Uuid().v4()}.tmp');
    await temp.writeAsString(
      jsonEncode({
        ...saved,
        'version': 1,
        'path': null,
        'closed': true,
        'recent': await recentLocations(),
      }),
      flush: true,
    );
    await temp.rename(file.path);
  }

  late Directory _root;
  @override
  String get location => _root.path;
  @override
  bool get isBrowser => false;
  @override
  Stream<String> get changes => _root.watch(recursive: true).expand((event) {
    String relative(String path) =>
        p.relative(path, from: _root.path).replaceAll('\\', '/');
    final paths = [
      relative(event.path),
      if (event is FileSystemMoveEvent && event.destination != null)
        relative(event.destination!),
    ];
    return paths
        .where(
          (path) =>
              !path.startsWith('.orbit/') &&
              !path.contains('.orbit-') &&
              !path.startsWith('Attachments/'),
        )
        .map((path) => event.isDirectory ? '*' : path);
  });

  @override
  Future<void> initialize({String? path}) async {
    if (path == null && rememberWorkspace) {
      final file = await _selectionFile();
      if (await file.exists()) {
        final saved = jsonDecode(await file.readAsString()) as Map;
        if (saved['version'] == 1 && saved['closed'] == true) {
          throw const WorkspaceFailure('Choose a Vault to continue.');
        }
        if (saved['version'] != 1 || saved['path'] is! String) {
          throw const WorkspaceFailure(
            'Saved workspace selection is unsupported. Choose a workspace explicitly.',
          );
        }
        path = saved['path'] as String;
        if (!await File(p.join(path, 'workspace.json')).exists()) {
          throw const WorkspaceFailure(
            'Your selected workspace is unavailable. Reconnect it or choose another folder.',
          );
        }
      }
      if (path == null) {
        final legacy = p.join(
          (await getApplicationDocumentsDirectory()).path,
          'Orbit Note',
          'My Knowledge',
        );
        if (await File(p.join(legacy, 'workspace.json')).exists()) {
          path = legacy;
        } else {
          throw const WorkspaceFailure(
            'Create a Vault or open an existing Orbit folder.',
          );
        }
      }
    }
    final selected =
        path ??
        p.join(
          (await getApplicationDocumentsDirectory()).path,
          'Orbit Note',
          'My Knowledge',
        );
    _root = Directory(p.normalize(p.absolute(selected)));
    await _root.create(recursive: true);
    _root = Directory(await _root.resolveSymbolicLinks());
    await _file('.orbit/workspace.sqlite');
    final manifest = await read('workspace.json');
    // Recovery must not mutate an unsupported newer workspace.
    if (manifest == null) {
      await _recoverPendingWrites();
    } else {
      try {
        final record = jsonDecode(utf8.decode(manifest)) as Map;
        if (record['format'] == 'orbit-note-workspace' &&
            record['version'] == 1) {
          await _recoverPendingWrites();
          await _moves.recover();
        }
      } on FormatException {
        /* Repository reports an invalid manifest. */
      }
    }
  }

  Future<File> _file(String relativePath) async {
    validateRelativePath(relativePath);
    var current = _root.path;
    for (final component in relativePath.split('/')) {
      current = p.join(current, component);
      if (await FileSystemEntity.type(current, followLinks: false) ==
          FileSystemEntityType.link) {
        throw const WorkspaceFailure(
          'Symbolic links inside a workspace cannot be written or read.',
        );
      }
    }
    if (!p.isWithin(_root.path, current)) {
      throw const WorkspaceFailure('Path escapes the workspace.');
    }
    return File(current);
  }

  NativePathMoves get _moves => NativePathMoves(
    _root.path,
    (path, bytes, hash) => write(path, bytes, expectedHash: hash),
  );

  @override
  Future<List<String>> listFolders() async {
    final directory = Directory((await _file('Notes')).path);
    final result = <String>['Notes'];
    if (await directory.exists()) {
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is Directory) {
          result.add(
            p.relative(entity.path, from: _root.path).replaceAll('\\', '/'),
          );
        }
      }
    }
    return result..sort();
  }

  @override
  Future<void> createFolder(String path) async {
    validateNotesPath(path);
    if (!path.startsWith('Notes/')) {
      throw const WorkspaceFailure('Folders belong inside Notes.');
    }
    final directory = Directory((await _file(path)).path);
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw const WorkspaceFailure('A file or folder already has that name.');
    }
    await directory.create(recursive: true);
  }

  @override
  Future<void> movePath(
    String source,
    String target,
    Map<String, FileReplacement> replacements,
  ) => _moves.move(source, target, replacements);

  @override
  Future<Uint8List?> read(String relativePath) async {
    final file = await _file(relativePath);
    return await file.exists() ? file.readAsBytes() : null;
  }

  @override
  Future<List<String>> listFiles() async {
    final result = <String>[];
    await for (final entity in _root.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        result.add(
          p.relative(entity.path, from: _root.path).replaceAll('\\', '/'),
        );
      }
    }
    result.sort();
    return result;
  }

  Future<void> _checkExpected(String relativePath, String? expected) async {
    final existing = await read(relativePath);
    final actual = existing == null
        ? null
        : sha256.convert(existing).toString();
    if (actual != expected) {
      throw const WorkspaceConflict(
        'This file changed outside Orbit Note. Your pending edit has not replaced it.',
      );
    }
  }

  @override
  Future<void> write(
    String relativePath,
    Uint8List bytes, {
    required String? expectedHash,
  }) async {
    final destination = await _file(relativePath);
    await _checkExpected(relativePath, expectedHash);
    await destination.parent.create(recursive: true);
    final commandId = const Uuid().v4();
    final tempPath = '$relativePath.orbit-$commandId.tmp';
    final area = relativePath.startsWith('.orbit/device/')
        ? '.orbit/device'
        : '.orbit';
    final journalPath = '$area/recovery/$commandId.json';
    final temp = await _file(tempPath);
    final journal = await _file(journalPath);
    await journal.parent.create(recursive: true);
    final before = await read(relativePath);
    if (before != null) {
      final backup = await _file('$area/history/$commandId.before');
      await backup.parent.create(recursive: true);
      await backup.writeAsBytes(before, flush: true);
    }
    await temp.writeAsBytes(bytes, flush: true);
    final record = <String, dynamic>{
      'format': 'orbit-note-file-save',
      'version': 1,
      'target': relativePath,
      'temp': tempPath,
      'beforeHash': expectedHash,
      'afterHash': sha256.convert(bytes).toString(),
      'beforePath': before == null ? null : '$area/history/$commandId.before',
    };
    await journal.writeAsString(jsonEncode(record), flush: true);
    // Recheck after staging: a file watcher is not a concurrency precondition.
    await _checkExpected(relativePath, expectedHash);
    try {
      // Dart's same-directory rename replaces an existing file. A failed rename
      // leaves both the source and the staged version available for recovery.
      await temp.rename(destination.path);
    } on FileSystemException catch (error) {
      throw WorkspaceFailure(
        'The file could not be replaced. Your edit is retained at $tempPath. ${error.message}',
      );
    }
    // Cleanup cannot turn a committed save into an apparent failure.
    try {
      await _completeJournal(journal, record);
      await _pruneHistory(area);
    } on Object {
      /* Retry maintenance on the next open/save. */
    }
  }

  Future<void> _completeJournal(File journal, Map record) async {
    final beforePath = record['beforePath'];
    if (beforePath is String) {
      if (!beforePath.endsWith('.before') ||
          !(beforePath.startsWith('.orbit/history/') ||
              beforePath.startsWith('.orbit/device/history/'))) {
        throw const WorkspaceFailure(
          'Unsupported history path retained for inspection.',
        );
      }
      final metadata = await _file(
        '${beforePath.substring(0, beforePath.length - '.before'.length)}.json',
      );
      await metadata.writeAsString(
        jsonEncode({
          ...record,
          'completedAt': (await journal.stat()).modified
              .toUtc()
              .toIso8601String(),
        }),
        flush: true,
      );
    }
    if (await journal.exists()) await journal.delete();
  }

  Future<void> _pruneHistory(String area) async {
    final folder = Directory(p.join(_root.path, area, 'history'));
    if (!await folder.exists()) return;
    final entries =
        <
          ({File metadata, File before, String target, DateTime time, int size})
        >[];
    await for (final entity in folder.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final record = jsonDecode(await entity.readAsString()) as Map;
        if (record['format'] != 'orbit-note-file-save' ||
            record['version'] != 1 ||
            record['completedAt'] is! String ||
            record['beforePath'] is! String) {
          continue;
        }
        final before = await _file(record['beforePath'] as String);
        if (!p.isWithin(folder.path, before.path) || !await before.exists()) {
          continue;
        }
        entries.add((
          metadata: entity,
          before: before,
          target: record['target'] as String,
          time: DateTime.parse(record['completedAt'] as String),
          size: await before.length(),
        ));
      } on Object {
        /* Unknown recovery/history remains untouched. */
      }
    }
    entries.sort((a, b) => b.time.compareTo(a.time));
    final keptTargets = <String>{};
    var count = 0, bytes = 0;
    final cutoff = DateTime.now().toUtc().subtract(historyMaxAge);
    for (final entry in entries) {
      final preserveLast = keptTargets.add(entry.target);
      if (!preserveLast &&
          (count >= historyMaxEntries ||
              bytes + entry.size > historyMaxBytes ||
              entry.time.isBefore(cutoff))) {
        // Never prune a version still referenced by an unresolved save journal.
        final journal = File(
          p.join(_root.path, area, 'recovery', p.basename(entry.metadata.path)),
        );
        if (await journal.exists()) continue;
        await entry.before.delete();
        await entry.metadata.delete();
      } else {
        count++;
        bytes += entry.size;
      }
    }
  }

  Future<void> _recoverPendingWrites() async {
    final directory = Directory((await _file('.orbit/recovery')).path);
    if (!await directory.exists()) return;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final record = jsonDecode(await entity.readAsString()) as Map;
        if (record['format'] != 'orbit-note-file-save' ||
            record['version'] != 1) {
          continue;
        }
        final target = record['target'] as String;
        final temporary = record['temp'] as String;
        final temp = await _file(temporary);
        if (!await temp.exists()) {
          final current = await read(target);
          if (current != null &&
              sha256.convert(current).toString() == record['afterHash']) {
            await _completeJournal(entity, record);
          }
          continue;
        }
        final after = await temp.readAsBytes();
        if (sha256.convert(after).toString() != record['afterHash']) continue;
        final current = await read(target);
        final currentHash = current == null
            ? null
            : sha256.convert(current).toString();
        if (currentHash == record['beforeHash']) {
          final destination = await _file(target);
          await temp.rename(destination.path);
          await _completeJournal(entity, record);
        }
        // Different external content is never overwritten during recovery.
      } on Object {
        // A corrupt/unsupported recovery record is retained verbatim for export.
      }
    }
    await _retireLegacyJournals();
    await _pruneHistory('.orbit');
    await _pruneHistory('.orbit/device');
  }

  /// Older versions retained every successful journal. Retire only entries whose
  /// after-hash is proven by current content or the before-hash of a known commit.
  Future<void> _retireLegacyJournals() async {
    final pending = <String, List<(File, Map)>>{};
    final queue = <String>[];
    final seenTargets = <String>{};
    for (final area in ['.orbit', '.orbit/device']) {
      for (final sub in ['history', 'recovery']) {
        final directory = Directory(p.join(_root.path, area, sub));
        if (!await directory.exists()) continue;
        await for (final file in directory.list(followLinks: false)) {
          if (file is! File || !file.path.endsWith('.json')) continue;
          try {
            final record = jsonDecode(await file.readAsString()) as Map;
            if (record['format'] != 'orbit-note-file-save' ||
                record['version'] != 1 ||
                record['target'] is! String) {
              continue;
            }
            final target = record['target'] as String;
            if (sub == 'history' && record['completedAt'] is String) {
              queue.add('$target\u0000${record['beforeHash']}');
            } else if (sub == 'recovery' &&
                record['temp'] is String &&
                !await (await _file(record['temp'] as String)).exists()) {
              (pending['$target\u0000${record['afterHash']}'] ??= []).add((
                file,
                record,
              ));
            }
            if (seenTargets.add(target)) {
              final current = await read(target);
              if (current != null) {
                queue.add('$target\u0000${sha256.convert(current)}');
              }
            }
          } on Object {
            /* Unverifiable records remain recoverable. */
          }
        }
      }
    }
    for (var i = 0; i < queue.length; i++) {
      final entries = pending.remove(queue[i]) ?? [];
      for (final (file, record) in entries) {
        try {
          await _completeJournal(file, record);
          queue.add('${record['target']}\u0000${record['beforeHash']}');
        } on Object {
          /* Never prune an unresolved chain. */
        }
      }
    }
  }

  @override
  Future<void> close() async {}
}
