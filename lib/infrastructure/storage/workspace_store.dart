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
    void Function(int bytesRead)? onProgress,
    bool Function()? isCancelled,
  });
}

/// Metadata retained for an attachment transfer that was interrupted while
/// its bytes were being staged. The staged bytes are device-local and are
/// never treated as authored workspace content until the guarded commit.
class WorkspaceAttachmentStageInfo {
  const WorkspaceAttachmentStageInfo({
    required this.id,
    required this.operation,
    required this.target,
    required this.expectedHash,
    required this.maxBytes,
    required this.length,
    this.sourceName,
    this.updatedAt,
  });

  final String id;
  final String operation;
  final String target;
  final String expectedHash;
  final int maxBytes;
  final int length;
  final String? sourceName;
  final DateTime? updatedAt;
}

/// Native stores retain attachment stages across a process interruption.
/// Browser stores can continue to use the bounded in-memory compatibility
/// path without pretending that a staged byte range is durable.
abstract interface class WorkspaceAttachmentStagingStore {
  Future<WorkspaceStage> stageAttachment(
    Stream<List<int>> bytes, {
    required WorkspaceAttachmentStageInfo info,
    void Function(int bytesRead)? onProgress,
    bool Function()? isCancelled,
  });

  Future<List<WorkspaceAttachmentStageInfo>> listAttachmentStages();

  Future<WorkspaceStage> resumeAttachmentStage(
    String id,
    Stream<List<int>> bytes, {
    void Function(int bytesRead)? onProgress,
    bool Function()? isCancelled,
  });

  Future<void> discardAttachmentStage(String id);
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

/// Native stores can report attachment changes without forcing a full object
/// reconciliation. Attachment bytes are durable files, but they are not part
/// of the Markdown/JSON object index.
abstract interface class WorkspaceAttachmentChangeSource {
  /// Relative `Attachments/` paths whose bytes were created, replaced, or
  /// removed outside the repository boundary.
  Stream<String> get attachmentChanges;
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
