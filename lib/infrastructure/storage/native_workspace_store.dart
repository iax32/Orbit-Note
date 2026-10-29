import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:watcher/watcher.dart';

import '../../domain/workspace_failure.dart';
import 'path_safety.dart';
import 'native_path_moves.dart';
import 'native_folder_commands.dart';
import 'native_vault_lock.dart';
import 'native_history_retention.dart';
import 'native_file_digests.dart';
import 'workspace_store.dart';
import 'object_encoding_execution.dart';

part 'native_sync_staging.dart';

WorkspaceStore createWorkspaceStore() =>
    NativeWorkspaceStore(rememberWorkspace: true);

class NativeWorkspaceStore
    implements
        WorkspaceStore,
        WorkspaceSelectionStore,
        WorkspaceChangeSource,
        WorkspaceAttachmentChangeSource,
        WorkspaceStreamingStore,
        WorkspaceFileSizeStore,
        WorkspaceChecksumStagingStore,
        WorkspaceAttachmentStagingStore,
        WorkspaceGuardedMoveStore,
        WorkspaceFolderCommandStore,
        WorkspaceFolderStore {
  @override
  Future<int> fileSize(String path) async => (await _file(path)).length();
  NativeFolderCommands get _folderCommands => NativeFolderCommands(
    _file,
    (path, bytes, hash) => write(path, bytes, expectedHash: hash),
  );

  @override
  Future<void> applyFolderCommand(
    List<FolderFileChange> files, {
    required String workspaceId,
    List<String> createFolders = const [],
    List<String> removeFolders = const [],
  }) {
    _requireOwnership();
    return _folderCommands.apply(
      files,
      workspaceId,
      createFolders,
      removeFolders,
    );
  }

  NativeWorkspaceStore({
    this.rememberWorkspace = false,
    this.existingWorkspaceId,
    this.selectionFilePath,
    this.historyMaxEntries = 200,
    this.historyMaxBytes = 64 * 1024 * 1024,
    this.historyMaxAge = const Duration(days: 30),
  });
  final bool rememberWorkspace;

  /// Batch transfer must never create a replacement for a deleted selection.
  final String? existingWorkspaceId;
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
        'recent': {_root.path, ...await recentLocations()}.take(50).toList(),
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

  /// Add a downloaded Vault without switching the user's active selection.
  Future<void> rememberRecentLocation(String path) async {
    if (!rememberWorkspace) return;
    final previous = await _readSelection();
    final file = await _selectionFile();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.${const Uuid().v4()}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        ...previous,
        'version': 1,
        'recent': {path, ...await recentLocations()}.take(50).toList(),
      }),
      flush: true,
    );
    await temporary.rename(file.path);
  }

  @override
  Future<List<String>> recentLocations() async {
    if (!rememberWorkspace) return [];
    final saved = await _readSelection();
    final candidates = {
      if (saved['path'] is String) saved['path'] as String,
      if (saved['recent'] is List)
        ...(saved['recent'] as List).whereType<String>(),
    }.toList();
    final available = <String>[];
    for (final path in candidates) {
      try {
        final type = await FileSystemEntity.type(path);
        final root = p.rootPrefix(p.absolute(path));
        if (type == FileSystemEntityType.directory ||
            (root.isNotEmpty && !await Directory(root).exists())) {
          available.add(path);
        }
      } on FileSystemException {
        // An inaccessible drive is not evidence that the Vault was deleted.
        available.add(path);
      }
    }
    final recent = available.take(50).toList();
    if (candidates.length != recent.length) {
      final file = await _selectionFile();
      final temp = File('${file.path}.${const Uuid().v4()}.tmp');
      await temp.writeAsString(
        jsonEncode({
          ...saved,
          if (!recent.contains(saved['path'])) 'path': null,
          if (!recent.contains(saved['path'])) 'closed': true,
          'recent': recent,
        }),
        flush: true,
      );
      await temp.rename(file.path);
    }
    return recent;
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
  StreamController<WatchEvent>? _linuxEvents;
  StreamSubscription<WatchEvent>? _linuxWatchSubscription;

  String _relativeWatchPath(String path) =>
      p.relative(path, from: _root.path).replaceAll('\\', '/');

  bool _isObjectWatchPath(String path) =>
      !path.startsWith('.orbit/') &&
      !path.contains('.orbit-') &&
      !path.startsWith('Attachments/');

  Future<void> _startLinuxWatcher() async {
    if (!Platform.isLinux) return;
    // Directory.watch(recursive: true) does not recurse on Linux. The watcher
    // installs watches for existing/new subdirectories and reconciles races
    // between creating a directory and writing its first file.
    final watcher = DirectoryWatcher(_root.path);
    final events = StreamController<WatchEvent>.broadcast();
    final failure = Completer<void>();
    _linuxEvents = events;
    _linuxWatchSubscription = watcher.events.listen(
      events.add,
      onError: (Object error, StackTrace stack) {
        if (!watcher.isReady && !failure.isCompleted) {
          failure.completeError(error, stack);
        } else {
          events.addError(error, stack);
        }
      },
    );
    await Future.any([watcher.ready, failure.future]);
  }

  NativeVaultLock? _ownership;
  void _requireOwnership() {
    if (_ownership == null) {
      throw const WorkspaceFailure(
        'Open and lock the Vault before changing its files.',
      );
    }
  }

  @override
  String get location => _root.path;
  @override
  bool get isBrowser => false;
  @override
  Stream<String> get changes {
    if (Platform.isLinux) {
      return _linuxEvents!.stream
          .map((event) => _relativeWatchPath(event.path))
          .where(_isObjectWatchPath);
    }
    return _root.watch(recursive: true).expand((event) {
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
  }

  @override
  Stream<String> get attachmentChanges {
    if (Platform.isLinux) {
      return _linuxEvents!.stream
          .map((event) => _relativeWatchPath(event.path))
          .where((path) => path.startsWith('Attachments/'));
    }
    return _root.watch(recursive: true).expand((event) {
      String relative(String path) =>
          p.relative(path, from: _root.path).replaceAll('\\', '/');
      final paths = [
        relative(event.path),
        if (event is FileSystemMoveEvent && event.destination != null)
          relative(event.destination!),
      ];
      return paths
          .where((path) => path.startsWith('Attachments/'))
          .where((path) => !event.isDirectory);
    });
  }

  @override
  Future<void> initialize({String? path}) async {
    await close();
    try {
      await _initialize(path: path);
    } on Object {
      await close();
      rethrow;
    }
  }

  Future<void> _initialize({String? path}) async {
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
    if (existingWorkspaceId == null) {
      await _root.create(recursive: true);
    } else if (!await _root.exists()) {
      throw const WorkspaceFailure('Selected Vault is no longer available.');
    }
    try {
      _root = Directory(await _root.resolveSymbolicLinks());
    } catch (_) {
      // Retain normalized directory if resolveSymbolicLinks is unsupported (e.g. network shares, subst drives).
    }
    Future<void> verifyExisting() async {
      if (existingWorkspaceId == null) return;
      final file = await _file('workspace.json');
      if (!await file.exists() || await file.length() > 1024 * 1024) {
        throw const WorkspaceFailure('Selected Vault manifest is unavailable.');
      }
      final v = jsonDecode(await file.readAsString()) as Map;
      if (v['format'] != 'orbit-note-workspace' ||
          v['version'] != 1 ||
          v['id'] != existingWorkspaceId) {
        throw const WorkspaceFailure(
          'Selected Vault identity changed. Select it again.',
        );
      }
    }

    await verifyExisting();
    _ownership = await NativeVaultLock.acquire(
      await _file('.orbit/device/vault.lock'),
    );
    await verifyExisting();
    await _file('.orbit/workspace.sqlite');
    final manifest = await read('workspace.json');
    var supportsRecovery = manifest == null;
    // Recovery must not mutate an unsupported newer workspace.
    if (manifest == null) {
      await _recoverPendingWrites();
    } else {
      try {
        final record = jsonDecode(utf8.decode(manifest)) as Map;
        if (record['format'] == 'orbit-note-workspace' &&
            record['version'] == 1) {
          supportsRecovery = true;
          await _recoverPendingWrites();
          await _moves.recover();
          await _folderCommands.recover();
        }
      } on FormatException {
        /* Repository reports an invalid manifest. */
      }
    }
    if (supportsRecovery) await _pruneAttachmentStages(this);
    await _startLinuxWatcher();
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
    final result = <String>{'Notes'};
    if (await directory.exists()) {
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is Directory) {
          final rel = p
              .relative(entity.path, from: _root.path)
              .replaceAll('\\', '/');
          result.add(rel);
        }
      }
    }
    return result.toList()..sort();
  }

  @override
  Future<void> createFolder(String path) async {
    _requireOwnership();
    final effectivePath = path == 'Notes' || path.startsWith('Notes/')
        ? path
        : 'Notes/$path';
    validateNotesPath(effectivePath);
    final directory = Directory((await _file(effectivePath)).path);
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      return;
    }
    await directory.create(recursive: true);
  }

  @override
  Future<void> deleteFolder(String path) async {
    _requireOwnership();
    final effectivePath = path == 'Notes' || path.startsWith('Notes/')
        ? path
        : 'Notes/$path';
    validateNotesPath(effectivePath);
    final directory = Directory((await _file(effectivePath)).path);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  @override
  Future<void> deleteFile(
    String relativePath, {
    required String? expectedHash,
  }) async {
    _requireOwnership();
    validateRelativePath(relativePath);
    final file = await _file(relativePath);
    await _checkExpected(relativePath, expectedHash);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> movePath(
    String source,
    String target,
    Map<String, FileReplacement> replacements,
  ) {
    _requireOwnership();
    return _moves.move(source, target, replacements);
  }

  @override
  Future<void> moveSyncPath(
    String source,
    String target,
    Map<String, FileReplacement> replacements, {
    required void Function() checkCurrent,
  }) {
    _requireOwnership();
    return _moves.move(
      source,
      target,
      replacements,
      checkCurrent: checkCurrent,
    );
  }

  @override
  Future<Uint8List?> read(String relativePath) async {
    final file = await _file(relativePath);
    return await file.exists() ? file.readAsBytes() : null;
  }

  @override
  Stream<List<int>> openRead(String relativePath) async* {
    final file = await _file(relativePath);
    yield* file.openRead();
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
    final existing = await _file(relativePath);
    final actual = await _hashFile(existing);
    if (actual != expected) {
      throw const WorkspaceConflict(
        'This file changed outside Orbit Note. Your pending edit has not replaced it.',
      );
    }
  }

  @override
  Future<WorkspaceStage> stage(
    Stream<List<int>> bytes, {
    required String expectedHash,
    required int maxBytes,
    void Function(int bytesRead)? onProgress,
    bool Function()? isCancelled,
  }) =>
      _stageSync(this, bytes, expectedHash, maxBytes, onProgress, isCancelled);

  @override
  Future<WorkspaceStage> stageWithChecksums(
    Stream<List<int>> bytes, {
    required String expectedHash,
    required int maxBytes,
  }) => _stageSync(
    this,
    bytes,
    expectedHash,
    maxBytes,
    null,
    null,
    includeMd5: true,
  );

  @override
  Future<WorkspaceStage> stageAttachment(
    Stream<List<int>> bytes, {
    required WorkspaceAttachmentStageInfo info,
    void Function(int bytesRead)? onProgress,
    bool Function()? isCancelled,
  }) => _stageAttachment(this, bytes, info, onProgress, isCancelled);

  @override
  Future<List<WorkspaceAttachmentStageInfo>> listAttachmentStages() =>
      _listAttachmentStages(this);

  @override
  Future<WorkspaceStage> resumeAttachmentStage(
    String id,
    Stream<List<int>> bytes, {
    void Function(int bytesRead)? onProgress,
    bool Function()? isCancelled,
  }) => _resumeAttachmentStage(this, id, bytes, onProgress, isCancelled);

  @override
  Future<void> discardAttachmentStage(String id) =>
      _discardAttachmentStage(this, id);

  @override
  Future<void> write(
    String relativePath,
    Uint8List bytes, {
    required String? expectedHash,
  }) async {
    _requireOwnership();
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
      'afterHash': await runObjectEncoding(
        () => sha256.convert(bytes).toString(),
        size: bytes.length,
      ),
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

  Future<void> _historyMaintenance = Future.value();
  NativeHistoryMaintenance? _historyWorker;
  Future<void> _pruneHistory(String area) {
    final root = _root.path;
    final work = _historyMaintenance.then(
      (_) => (_historyWorker ??= NativeHistoryMaintenance()).prune(
        root: root,
        area: area,
        maxEntries: historyMaxEntries,
        maxBytes: historyMaxBytes,
        maxAge: historyMaxAge,
      ),
    );
    _historyMaintenance = work.catchError((Object _) {});
    return work;
  }

  Future<void> _recoverPendingWrites() async {
    for (final area in ['.orbit', '.orbit/device']) {
      await _recoverWriteArea(area);
    }
    await _retireLegacyJournals();
    await _pruneHistory('.orbit');
    await _pruneHistory('.orbit/device');
  }

  Future<void> _recoverWriteArea(String area) async {
    final directory = Directory((await _file('$area/recovery')).path);
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
        // A device journal must not mutate authored content.
        if (area == '.orbit/device' && !target.startsWith('.orbit/device/')) {
          continue;
        }
        final temporary = record['temp'] as String;
        final temp = await _file(temporary);
        if (!await temp.exists()) {
          if (await _hashFile(await _file(target)) == record['afterHash']) {
            await _completeJournal(entity, record);
          }
          continue;
        }
        if (await _hashFile(temp) != record['afterHash']) continue;
        final currentHash = await _hashFile(await _file(target));
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
  Future<void> close() async {
    // Keep the old Vault's OS lease until its queued maintenance has finished.
    await _historyMaintenance;
    final historyWorker = _historyWorker;
    _historyWorker = null;
    await historyWorker?.close();
    final subscription = _linuxWatchSubscription;
    final events = _linuxEvents;
    _linuxWatchSubscription = null;
    _linuxEvents = null;
    await subscription?.cancel();
    await events?.close();
    final ownership = _ownership;
    _ownership = null;
    await ownership?.close();
  }
}
