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
  Future<void> deleteFile(
    String relativePath, {
    required String? expectedHash,
  }) async {
    final old = files[relativePath];
    if ((old == null ? null : sha256.convert(old).toString()) != expectedHash) {
      throw const WorkspaceConflict('External edit before deletion');
    }
    files.remove(relativePath);
  }
}

class FolderMemoryStore extends MemoryStore implements WorkspaceFolderStore {
  final Set<String> folderList = {'Notes'};

  @override
  Future<List<String>> listFolders() async => folderList.toList()..sort();

  @override
  Future<void> createFolder(String path) async {
    folderList.add(path);
  }

  @override
  Future<void> deleteFolder(String path) async {
    folderList.remove(path);
  }

  @override
  Future<void> movePath(
    String source,
    String target,
    Map<String, FileReplacement> replacements,
  ) async {
    folderList.remove(source);
    folderList.add(target);
  }
}
