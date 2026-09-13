part of 'native_workspace_store.dart';

Future<String?> _hashFile(File file) async => await file.exists()
    ? (await sha256.bind(file.openRead()).first).toString()
    : null;

Future<WorkspaceStage> _stageSync(
  NativeWorkspaceStore store,
  Stream<List<int>> bytes,
  String expectedHash,
  int maxBytes,
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
      if (store._ownership != ownership) {
        throw const WorkspaceConflict('Vault changed during transfer.');
      }
      length += chunk.length;
      if (length > maxBytes) {
        throw const WorkspaceFailure('Sync entry exceeds the transfer limit.');
      }
      await output.writeFrom(chunk);
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
    this.length,
  );
  final NativeWorkspaceStore store;
  final NativeVaultLock ownership;
  final File file;
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
  }
}
