import 'dart:io';

import '../../domain/workspace_failure.dart';

/// Held by the operating system, not by the existence/age of a lock file.
/// The file stays in place so another process cannot lock a different inode.
class NativeVaultLock {
  NativeVaultLock._(this._file, this._key);
  static final _held = <String>{};
  final RandomAccessFile _file;
  final String _key;
  bool _closed = false;

  static Future<NativeVaultLock> acquire(File file) async {
    final key = Platform.isWindows ? file.path.toLowerCase() : file.path;
    if (!_held.add(key)) {
      throw const WorkspaceFailure(
        'This Vault is already open in Orbit. Close it there first.',
      );
    }
    RandomAccessFile? handle;
    try {
      await file.parent.create(recursive: true);
      handle = await file.open(mode: FileMode.append);
      await handle.lock(FileLock.exclusive, 0, 1);
      return NativeVaultLock._(handle, key);
    } on Object {
      await handle?.close();
      _held.remove(key);
      throw const WorkspaceFailure(
        'This Vault is in use or cannot be locked. Close the other Orbit instance and retry.',
      );
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _file
          .close(); // Closing releases the OS lock, including after errors.
    } finally {
      _held.remove(_key);
    }
  }
}
