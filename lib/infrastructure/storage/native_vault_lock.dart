import 'dart:io';

import 'package:path/path.dart' as p;

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
    final normalized = p.normalize(file.path);
    final key = Platform.isWindows ? normalized.toLowerCase() : normalized;
    if (!_held.add(key)) {
      throw const WorkspaceFailure(
        'This Vault is already open in Orbit. Close it there first.',
      );
    }
    RandomAccessFile? handle;
    const maxAttempts = 6;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        await file.parent.create(recursive: true);
        handle = await file.open(mode: FileMode.append);
        await handle.lock(FileLock.exclusive, 0, 1);
        return NativeVaultLock._(handle, key);
      } on Object {
        await handle?.close();
        handle = null;
        if (attempt == maxAttempts - 1) {
          _held.remove(key);
          throw const WorkspaceFailure(
            'This Vault is in use or cannot be locked. Close the other Orbit instance and retry.',
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
    _held.remove(key);
    throw const WorkspaceFailure(
      'This Vault is in use or cannot be locked. Close the other Orbit instance and retry.',
    );
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
