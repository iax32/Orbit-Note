import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:orbit_note/domain/workspace_failure.dart';
import 'package:orbit_note/infrastructure/storage/workspace_store.dart';

class MemoryStore implements WorkspaceStore {
  final files = <String, Uint8List>{};
  bool failWrites = false;
  Future<void>? writeGate;
  String? failInitializePath;
  bool failAllInitializations = false;
  @override
  String get location => 'Test workspace';
  @override
  bool get isBrowser => false;
  @override
  Future<void> initialize({String? path}) async {
    if (failAllInitializations ||
        (path != null && path == failInitializePath)) {
      throw const WorkspaceFailure('Cannot open selected folder');
    }
  }

  @override
  Future<void> close() async {}
  @override
  Future<List<String>> listFiles() async => files.keys.toList();
  @override
  Future<Uint8List?> read(String relativePath) async => files[relativePath];
  @override
  Future<void> write(
    String relativePath,
    Uint8List bytes, {
    required String? expectedHash,
  }) async {
    await writeGate;
    if (failWrites) {
      throw const WorkspaceFailure('Simulated write failure');
    }
    final old = files[relativePath];
    if ((old == null ? null : sha256.convert(old).toString()) != expectedHash) {
      throw const WorkspaceConflict('External edit');
    }
    files[relativePath] = Uint8List.fromList(bytes);
  }

  @override
  Future<void> deleteFile(String relativePath) async {
    files.remove(relativePath);
  }
}
