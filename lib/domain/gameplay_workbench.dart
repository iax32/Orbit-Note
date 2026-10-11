/// A source citation is knowledge, not permission to open or execute a repository.
class GameplayCodeReference {
  GameplayCodeReference({
    required this.repository,
    required this.path,
    required this.revision,
    required this.startLine,
    required this.endLine,
    required this.excerpt,
    this.branch = '',
  });
  final String repository, path, revision, excerpt, branch;
  final int startLine, endLine;

  void validate() {
    if (repository.trim().isEmpty ||
        repository.length > 2000 ||
        repository.contains(RegExp(r'[\r\n\x00]'))) {
      throw const FormatException('Enter a repository name or location.');
    }
    if (path.isEmpty ||
        path.length > 2000 ||
        path.startsWith('/') ||
        path.contains('\\') ||
        path.contains(':') ||
        path.split('/').any((p) => p.isEmpty || p == '.' || p == '..') ||
        path.contains(RegExp(r'[\r\n\x00]'))) {
      throw const FormatException(
        'Use a repository-relative path, such as src/player.cpp.',
      );
    }
    if (!RegExp(r'^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$').hasMatch(revision)) {
      throw const FormatException(
        'Paste the full 40- or 64-character Git commit hash. A branch is not a revision.',
      );
    }
    if (startLine < 1 ||
        endLine < startLine ||
        endLine > 10000000 ||
        excerpt.trim().isEmpty ||
        excerpt.length > 100000 ||
        branch.length > 500 ||
        branch.contains(RegExp(r'[\r\n\x00]'))) {
      throw const FormatException(
        'Enter a valid line range and a source excerpt (up to 100,000 characters).',
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'repository': repository.trim(),
    'path': path,
    'commit': revision.toLowerCase(),
    'startLine': startLine,
    'endLine': endLine,
    'branch': branch,
    'excerpt': excerpt,
  };

  String get markdown {
    validate();
    var fence = '```';
    while (excerpt.contains(fence)) {
      fence += '`';
    }
    return 'Repository: $repository\n\nFile: `$path` · lines $startLine–$endLine\n\n'
        'Commit: `$revision`\n\n${branch.isEmpty ? '' : 'Branch when captured: $branch (may move)\n\n'}'
        '$fence\n$excerpt\n$fence\n';
  }
}

List<String> gameplayIds(Object? value) =>
    value is List ? value.whereType<String>().toSet().toList() : const [];
