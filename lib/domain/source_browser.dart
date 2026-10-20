class SourceFileEntry {
  const SourceFileEntry(this.path, this.language);
  final String path, language;
}

/// Exact captured lines, including their authored line endings.
class SourceExcerpt {
  const SourceExcerpt(
    this.repository,
    this.path,
    this.start,
    this.end,
    this.text,
    this.language, {
    this.sourceSha256 = '',
  });
  final String repository, path, text, language;

  /// Hash of the complete UTF-8 source snapshot, never a Git revision claim.
  final String sourceSha256;
  final int start, end;

  String get markdown {
    var fence = '```';
    while (text.contains(fence)) {
      fence += '`';
    }
    return '$fence$language\n$text${text.endsWith('\n') || text.endsWith('\r') ? '' : '\n'}$fence';
  }
}

String sourceLineExcerpt(String text, int first, int last) {
  final endings = RegExp(r'\r\n|\r|\n').allMatches(text).toList();
  final starts = [0, for (final m in endings) m.end];
  if (first < 1 || last < first || last > starts.length) {
    throw const FormatException('Select a valid source line range.');
  }
  return text.substring(
    starts[first - 1],
    last < starts.length ? starts[last] : text.length,
  );
}

class SourceFileListing {
  const SourceFileListing(this.files, {this.incomplete = false});
  final List<SourceFileEntry> files;
  final bool incomplete;
}

String? sourceLanguage(String path) {
  final extension = path.split('.').last.toLowerCase();
  return const {
    'dart': 'dart',
    'c': 'c',
    'h': 'cpp',
    'cc': 'cpp',
    'cpp': 'cpp',
    'cxx': 'cpp',
    'hpp': 'cpp',
    'cs': 'cs',
    'js': 'javascript',
    'jsx': 'javascript',
    'mjs': 'javascript',
    'ts': 'typescript',
    'tsx': 'typescript',
    'html': 'html',
    'htm': 'html',
    'css': 'css',
    'scss': 'scss',
    'json': 'json',
    'yaml': 'yaml',
    'yml': 'yaml',
    'py': 'python',
    'lua': 'lua',
    'gd': 'python',
    'rs': 'rust',
    'go': 'go',
    'java': 'java',
    'kt': 'kotlin',
    'swift': 'swift',
    'sh': 'bash',
    'sql': 'sql',
    'xml': 'xml',
    'toml': 'ini',
    'md': 'markdown',
    'txt': '',
    'glsl': 'glsl',
    'hlsl': 'cpp',
    'shader': 'cpp',
    'usf': 'cpp',
    'ush': 'cpp',
    'cginc': 'cpp',
    'gdshader': 'glsl',
    'luau': 'lua',
    'ini': 'ini',
    'asm': 'x86asm',
    's': 'x86asm',
    'log': '',
  }[extension];
}

List<int> sourceMatchingLines(
  String text,
  String query, {
  bool caseSensitive = false,
}) {
  if (query.isEmpty) return const [];
  final needle = caseSensitive ? query : query.toLowerCase();
  final lines = text.split(RegExp(r'\r\n|\r|\n'));
  return [
    for (var i = 0; i < lines.length; i++)
      if ((caseSensitive ? lines[i] : lines[i].toLowerCase()).contains(needle))
        i,
  ];
}
