part of 'native_workspace_store.dart';

Future<String?> _hashFile(File file) async => await file.exists()
    ? (await sha256.bind(file.openRead()).first).toString()
    : null;

Future<WorkspaceStage> _stageSync(
  NativeWorkspaceStore store,
  Stream<List<int>> bytes,
  String expectedHash,
  int maxBytes,
  void Function(int bytesRead)? onProgress,
  bool Function()? isCancelled,
) async {
  store._requireOwnership();
  final ownership = store._ownership;
  final file = await store._file(
    '.orbit/device/sync/incoming/${const Uuid().v4()}.part',
  );
  await file.parent.create(recursive: true);
  final output = await file.open(mode: FileMode.write);
  var length = 0;
  try {
    await for (final chunk in bytes) {
      if (isCancelled?.call() == true) {
        throw const WorkspaceFailure('Attachment recovery was cancelled.');
      }
      if (store._ownership != ownership) {
        throw const WorkspaceConflict('Vault changed during transfer.');
      }
      length += chunk.length;
      if (length > maxBytes) {
        throw const WorkspaceFailure('Sync entry exceeds the transfer limit.');
      }
      await output.writeFrom(chunk);
      onProgress?.call(length);
    }
    await output.flush();
  } on Object {
    await output.close();
    if (await file.exists()) await file.delete();
    rethrow;
  }
  await output.close();
  if (await _hashFile(file) != expectedHash || store._ownership != ownership) {
    await file.delete();
    throw const WorkspaceConflict('Transferred bytes or Vault changed.');
  }
  return _NativeSyncStage(store, ownership!, file, expectedHash, length);
}

class _NativeSyncStage implements WorkspaceStage {
  _NativeSyncStage(
    this.store,
    this.ownership,
    this.file,
    this.hash,
    this.length, [
    this.cleanupManifest,
  ]);
  final NativeWorkspaceStore store;
  final NativeVaultLock ownership;
  final File file;
  final File? cleanupManifest;
  @override
  final String hash;
  @override
  final int length;
  bool _closed = false;

  void _check() {
    if (_closed || store._ownership != ownership) {
      throw const WorkspaceConflict('This transfer belongs to a closed Vault.');
    }
    store._requireOwnership();
  }

  @override
  Stream<List<int>> openRead() async* {
    _check();
    yield* file.openRead();
  }

  @override
  Future<Uint8List> read({required int maxBytes}) async {
    _check();
    if (length > maxBytes) {
      throw const WorkspaceFailure('Structured sync content is too large.');
    }
    return file.readAsBytes();
  }

  @override
  Future<void> commit(
    String path, {
    required String? expectedHash,
    required void Function() checkCurrent,
  }) async {
    void check() {
      _check();
      checkCurrent();
    }

    check();
    final destination = await store._file(path);
    await store._checkExpected(path, expectedHash);
    if (await _hashFile(file) != hash) {
      throw const WorkspaceConflict('Staged sync bytes changed.');
    }
    await destination.parent.create(recursive: true);
    final id = const Uuid().v4();
    final area = path.startsWith('.orbit/device/') ? '.orbit/device' : '.orbit';
    final tempPath = '$path.orbit-$id.tmp';
    final temp = await store._file(tempPath);
    final journal = await store._file('$area/recovery/$id.json');
    final beforePath = expectedHash == null ? null : '$area/history/$id.before';
    if (beforePath != null) {
      final backup = await store._file(beforePath);
      await backup.parent.create(recursive: true);
      await destination.copy(backup.path);
      final handle = await backup.open(mode: FileMode.append);
      try {
        await handle.flush();
      } finally {
        await handle.close();
      }
      if (await _hashFile(backup) != expectedHash) {
        throw const WorkspaceConflict(
          'Local bytes changed before sync backup.',
        );
      }
    }
    await file.copy(temp.path);
    final handle = await temp.open(mode: FileMode.append);
    try {
      await handle.flush();
    } finally {
      await handle.close();
    }
    // No journal exists before both checks succeed. A failed preparation cannot
    // cause a rejected transfer to publish automatically on the next launch.
    try {
      if (await _hashFile(temp) != hash) {
        throw const WorkspaceConflict('Sync staging copy is corrupt.');
      }
      await store._checkExpected(path, expectedHash);
      check();
    } on Object {
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
    final record = <String, dynamic>{
      'format': 'orbit-note-file-save',
      'version': 1,
      'target': path,
      'temp': tempPath,
      'beforeHash': expectedHash,
      'afterHash': hash,
      'beforePath': beforePath,
    };
    await journal.parent.create(recursive: true);
    await journal.writeAsString(jsonEncode(record), flush: true);
    try {
      await store._checkExpected(path, expectedHash);
      check();
    } on Object {
      // The application rejected this commit. Keep the before-image but remove
      // this operation's uncommitted intent so startup cannot bypass the guard.
      await journal.delete();
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
    await temp.rename(destination.path);
    try {
      await store._completeJournal(journal, record);
      await store._pruneHistory(area);
    } on Object {
      /* A published write remains successful; startup cleans up. */
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (await file.exists()) await file.delete();
    if (cleanupManifest != null && await cleanupManifest!.exists()) {
      await cleanupManifest!.delete();
    }
  }
}

String _attachmentStageId(String id) {
  if (!RegExp(r'^[a-zA-Z0-9-]{8,80}$').hasMatch(id)) {
    throw const WorkspaceFailure('Invalid attachment recovery stage.');
  }
  return id;
}

Future<File> _attachmentStageFile(
  NativeWorkspaceStore store,
  String id,
  String suffix,
) => store._file('.orbit/device/recovery/attachments/attachment-$id$suffix');

Map<String, dynamic> _attachmentStageJson(WorkspaceAttachmentStageInfo info) =>
    {
      'format': 'orbit-note-attachment-stage',
      'version': 1,
      'id': info.id,
      'operation': info.operation,
      'target': info.target,
      'expectedHash': info.expectedHash,
      'maxBytes': info.maxBytes,
      'length': info.length,
      'sourceName': info.sourceName,
      'updatedAt': (info.updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
    };

WorkspaceAttachmentStageInfo _attachmentStageInfo(Map raw) {
  final id = raw['id'];
  final operation = raw['operation'];
  final target = raw['target'];
  final expectedHash = raw['expectedHash'];
  final maxBytes = raw['maxBytes'];
  final length = raw['length'];
  if (raw['format'] != 'orbit-note-attachment-stage' ||
      raw['version'] != 1 ||
      id is! String ||
      operation is! String ||
      target is! String ||
      expectedHash is! String ||
      maxBytes is! int ||
      length is! int ||
      maxBytes < 0 ||
      length < 0) {
    throw const FormatException('Unsupported attachment recovery stage.');
  }
  DateTime? updatedAt;
  if (raw['updatedAt'] is String) {
    updatedAt = DateTime.tryParse(raw['updatedAt'] as String)?.toUtc();
  }
  return WorkspaceAttachmentStageInfo(
    id: _attachmentStageId(id),
    operation: operation,
    target: target,
    expectedHash: expectedHash,
    maxBytes: maxBytes,
    length: length,
    sourceName: raw['sourceName'] is String
        ? raw['sourceName'] as String
        : null,
    updatedAt: updatedAt,
  );
}

Future<void> _writeAttachmentStageManifest(
  File manifest,
  WorkspaceAttachmentStageInfo info,
) async {
  final temporary = File('${manifest.path}.tmp');
  await temporary.writeAsString(
    jsonEncode(_attachmentStageJson(info)),
    flush: true,
  );
  await temporary.rename(manifest.path);
}

Future<WorkspaceStage> _stageAttachment(
  NativeWorkspaceStore store,
  Stream<List<int>> bytes,
  WorkspaceAttachmentStageInfo info,
  void Function(int bytesRead)? onProgress,
  bool Function()? isCancelled,
) async {
  store._requireOwnership();
  final ownership = store._ownership;
  final id = _attachmentStageId(info.id);
  final manifest = await _attachmentStageFile(store, id, '.json');
  final file = await _attachmentStageFile(store, id, '.part');
  if (await manifest.exists() || await file.exists()) {
    throw const WorkspaceConflict(
      'An attachment recovery stage already exists.',
    );
  }
  await file.parent.create(recursive: true);
  await _writeAttachmentStageManifest(
    manifest,
    WorkspaceAttachmentStageInfo(
      id: id,
      operation: info.operation,
      target: info.target,
      expectedHash: info.expectedHash,
      maxBytes: info.maxBytes,
      length: 0,
      sourceName: info.sourceName,
      updatedAt: DateTime.now().toUtc(),
    ),
  );
  final output = await file.open(mode: FileMode.write);
  var length = 0;
  try {
    await for (final chunk in bytes) {
      if (isCancelled?.call() == true) {
        throw const WorkspaceFailure('Attachment recovery was cancelled.');
      }
      if (store._ownership != ownership) {
        throw const WorkspaceConflict('Vault changed during transfer.');
      }
      length += chunk.length;
      if (length > info.maxBytes) {
        throw const WorkspaceFailure('Attachment exceeds the transfer limit.');
      }
      await output.writeFrom(chunk);
      await output.flush();
      await _writeAttachmentStageManifest(
        manifest,
        WorkspaceAttachmentStageInfo(
          id: id,
          operation: info.operation,
          target: info.target,
          expectedHash: info.expectedHash,
          maxBytes: info.maxBytes,
          length: length,
          sourceName: info.sourceName,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      onProgress?.call(length);
    }
    await output.flush();
  } finally {
    await output.close();
  }
  if (await _hashFile(file) != info.expectedHash ||
      store._ownership != ownership) {
    if (await file.exists()) await file.delete();
    if (await manifest.exists()) await manifest.delete();
    throw const WorkspaceConflict('Transferred bytes or Vault changed.');
  }
  return _NativeSyncStage(
    store,
    ownership!,
    file,
    info.expectedHash,
    length,
    manifest,
  );
}

Future<List<WorkspaceAttachmentStageInfo>> _listAttachmentStages(
  NativeWorkspaceStore store,
) async {
  store._requireOwnership();
  final directory = Directory(
    (await store._file('.orbit/device/recovery/attachments')).path,
  );
  if (!await directory.exists()) return [];
  final result = <WorkspaceAttachmentStageInfo>[];
  await for (final entity in directory.list(followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
    try {
      final info = _attachmentStageInfo(
        jsonDecode(await entity.readAsString()) as Map,
      );
      final part = await _attachmentStageFile(store, info.id, '.part');
      if (!await part.exists()) continue;
      result.add(info);
    } on Object {
      // Keep malformed recovery files for inspection without making startup
      // unusable. A subsequent discard can remove the known stage by id.
    }
  }
  result.sort(
    (a, b) =>
        (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)),
  );
  return result;
}

/// Removes only well-formed, device-local stages whose last durable progress
/// update is outside the recovery retention window. Unknown or malformed
/// manifests remain untouched so cleanup can never destroy data it cannot
/// positively identify as an abandoned attachment stage.
Future<void> _pruneAttachmentStages(NativeWorkspaceStore store) async {
  store._requireOwnership();
  final directory = Directory(
    (await store._file('.orbit/device/recovery/attachments')).path,
  );
  if (!await directory.exists()) return;
  final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 30));
  await for (final entity in directory.list(followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
    try {
      final info = _attachmentStageInfo(
        jsonDecode(await entity.readAsString()) as Map,
      );
      final updatedAt = info.updatedAt;
      if (updatedAt == null || !updatedAt.isBefore(cutoff)) continue;
      final part = await _attachmentStageFile(store, info.id, '.part');
      if (await part.exists()) await part.delete();
      if (await entity.exists()) await entity.delete();
      final temporary = File('${entity.path}.tmp');
      if (await temporary.exists()) await temporary.delete();
    } on Object {
      // Leave malformed or unknown recovery data for explicit inspection.
    }
  }
}

Future<WorkspaceStage> _resumeAttachmentStage(
  NativeWorkspaceStore store,
  String id,
  Stream<List<int>> bytes,
  void Function(int bytesRead)? onProgress,
  bool Function()? isCancelled,
) async {
  store._requireOwnership();
  final ownership = store._ownership;
  final safeId = _attachmentStageId(id);
  final manifest = await _attachmentStageFile(store, safeId, '.json');
  final file = await _attachmentStageFile(store, safeId, '.part');
  if (!await manifest.exists() || !await file.exists()) {
    throw const WorkspaceFailure(
      'The interrupted attachment transfer is unavailable.',
    );
  }
  final info = _attachmentStageInfo(
    jsonDecode(await manifest.readAsString()) as Map,
  );
  final currentLength = await file.length();
  if (currentLength > info.maxBytes) {
    throw const WorkspaceFailure(
      'The interrupted attachment exceeds the transfer limit.',
    );
  }
  final output = await file.open(mode: FileMode.append);
  var length = currentLength;
  try {
    onProgress?.call(length);
    await for (final chunk in bytes) {
      if (isCancelled?.call() == true) {
        throw const WorkspaceFailure('Attachment recovery was cancelled.');
      }
      if (store._ownership != ownership) {
        throw const WorkspaceConflict('Vault changed during transfer.');
      }
      length += chunk.length;
      if (length > info.maxBytes) {
        throw const WorkspaceFailure('Attachment exceeds the transfer limit.');
      }
      await output.writeFrom(chunk);
      await output.flush();
      await _writeAttachmentStageManifest(
        manifest,
        WorkspaceAttachmentStageInfo(
          id: info.id,
          operation: info.operation,
          target: info.target,
          expectedHash: info.expectedHash,
          maxBytes: info.maxBytes,
          length: length,
          sourceName: info.sourceName,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      onProgress?.call(length);
    }
    await output.flush();
  } finally {
    await output.close();
  }
  if (await _hashFile(file) != info.expectedHash ||
      store._ownership != ownership) {
    throw const WorkspaceConflict(
      'Resumed bytes do not match the recorded checksum.',
    );
  }
  return _NativeSyncStage(
    store,
    ownership!,
    file,
    info.expectedHash,
    length,
    manifest,
  );
}

Future<void> _discardAttachmentStage(
  NativeWorkspaceStore store,
  String id,
) async {
  store._requireOwnership();
  final safeId = _attachmentStageId(id);
  final manifest = await _attachmentStageFile(store, safeId, '.json');
  final file = await _attachmentStageFile(store, safeId, '.part');
  if (await file.exists()) await file.delete();
  if (await manifest.exists()) await manifest.delete();
}
