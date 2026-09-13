import 'dart:typed_data';

abstract interface class WorkspaceFileSizeStore {
  Future<int> fileSize(String path);
}

abstract interface class WorkspaceStreamingStore {
  Stream<List<int>> openRead(String relativePath);
}

/// Device-local staging, outside authored paths. Network streams never hold the
/// repository command queue. A stage remains bound to the store opening it.
abstract interface class WorkspaceStagingStore {
  Future<WorkspaceStage> stage(
    Stream<List<int>> bytes, {
    required String expectedHash,
    required int maxBytes,
  });
}

abstract interface class WorkspaceStage {
  String get hash;
  int get length;
  Stream<List<int>> openRead();
  Future<Uint8List> read({required int maxBytes});
  Future<void> commit(
    String path, {
    required String? expectedHash,
    required void Function() checkCurrent,
  });
  Future<void> close();
}

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

class FolderFileChange {
  const FolderFileChange(
    this.source,
    this.target,
    this.bytes,
    this.expectedHash,
  );
  final String source, target, expectedHash;
  final Uint8List bytes;
}

abstract interface class WorkspaceFolderCommandStore {
  Future<void> applyFolderCommand(
    List<FolderFileChange> files, {
    required String workspaceId,
    List<String> createFolders = const [],
    List<String> removeFolders = const [],
  });
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

abstract interface class WorkspaceGuardedMoveStore {
  Future<void> moveSyncPath(
    String source,
    String target,
    Map<String, FileReplacement> replacements, {
    required void Function() checkCurrent,
  });
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
