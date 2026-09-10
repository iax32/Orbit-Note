class WorkspaceFailure implements Exception {
  const WorkspaceFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class WorkspaceConflict extends WorkspaceFailure {
  const WorkspaceConflict(super.message, {this.recoveryPath});
  final String? recoveryPath;
}

class WorkspaceReadOnly extends WorkspaceFailure {
  const WorkspaceReadOnly(super.message);
}
