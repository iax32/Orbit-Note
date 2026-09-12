import 'dart:typed_data';

abstract interface class WorkspaceSelectionStore {
  Future<void> rememberSelection();
  Future<List<String>> recentLocations();
  Future<void> clearSelection();
}

abstract interface class WorkspaceChangeSource {
  /// Relative paths; '*' means a directory changed and reconciliation is needed.
  Stream<String> get changes;
}

class FileReplacement {
  const FileReplacement(this.bytes, this.expectedHash);
  final Uint8List bytes;
  final String expectedHash;
}

abstract interface class WorkspaceFolderStore {
  Future<List<String>> listFolders();
  Future<void> createFolder(String path);
  Future<void> deleteFolder(String path);
  Future<void> movePath(
    String source,
    String target,
    Map<String, FileReplacement> replacements,
  );
}

abstract interface class WorkspaceStore {
  String get location;
  bool get isBrowser;
  Future<void> initialize({String? path});
  Future<List<String>> listFiles();
  Future<Uint8List?> read(String relativePath);

  /// Compare and replace. A non-null expected value must match the existing bytes.
  /// Null expects the target to be absent. Never overwrites an unexpected file.
  Future<void> write(
    String relativePath,
    Uint8List bytes, {
    required String? expectedHash,
  });

  /// Deletes only the version inspected by the caller. Null expects absence.
  Future<void> deleteFile(String relativePath, {required String? expectedHash});
  Future<void> close();
}
