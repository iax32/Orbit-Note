import 'dart:typed_data';

/// Retained files are inspected and exported, never silently applied or removed.
class WorkspaceRecoveryFile {
  const WorkspaceRecoveryFile({required this.path, required this.length});
  final String path;
  final int length;

  static bool acceptsPath(String path) =>
      path.startsWith('.orbit/recovery/') ||
      path.startsWith('.orbit/imported-recovery/') ||
      path.startsWith('.orbit/device/recovery/') ||
      (path.contains('.orbit-') && path.endsWith('.tmp'));
}

class WorkspaceRecoverySnapshot {
  WorkspaceRecoverySnapshot({required this.path, required Uint8List bytes})
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView();
  final String path;
  final Uint8List bytes;
}
