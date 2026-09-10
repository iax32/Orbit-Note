import '../../domain/workspace_failure.dart';

void validateRelativePath(String value) {
  if (value.isEmpty ||
      value.contains('\\') ||
      value.startsWith('/') ||
      value.contains(':') ||
      value.contains('\u0000') ||
      value
          .split('/')
          .any((part) => part.isEmpty || part == '.' || part == '..')) {
    throw const WorkspaceFailure('Unsafe workspace-relative path.');
  }
}

void validateNotesPath(String value) {
  validateRelativePath(value);
  if (!(value == 'Notes' || value.startsWith('Notes/')) ||
      value.length > 220 ||
      value
          .split('/')
          .any(
            (part) =>
                part.endsWith('.') ||
                part.endsWith(' ') ||
                RegExp(r'[<>"|?*\x00-\x1f]').hasMatch(part) ||
                RegExp(
                  r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)',
                  caseSensitive: false,
                ).hasMatch(part),
          )) {
    throw const WorkspaceFailure('Choose a portable Notes folder/file name.');
  }
}
