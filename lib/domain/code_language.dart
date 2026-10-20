import 'dart:convert';

class CodePosition {
  const CodePosition(this.line, this.character);
  final int line, character;
  Map<String, int> get json => {'line': line, 'character': character};
  static CodePosition parse(dynamic value) {
    if (value is! Map ||
        value['line'] is! int ||
        value['character'] is! int ||
        value['line'] < 0 ||
        value['character'] < 0) {
      throw const FormatException('Invalid language-tool position.');
    }
    return CodePosition(value['line'] as int, value['character'] as int);
  }
}

List<({int start, int end})> languageLines(String text) {
  final result = <({int start, int end})>[];
  var start = 0;
  for (final match in RegExp(r'\r\n|\r|\n').allMatches(text)) {
    result.add((start: start, end: match.start));
    start = match.end;
  }
  result.add((start: start, end: text.length));
  return result;
}

CodePosition codePosition(String text, int offset) {
  if (offset < 0 || offset > text.length) {
    throw const FormatException('Caret outside source.');
  }
  final lines = languageLines(text);
  for (var i = 0; i < lines.length; i++) {
    if (offset <= lines[i].end ||
        i == lines.length - 1 ||
        offset < lines[i + 1].start) {
      return CodePosition(
        i,
        (offset - lines[i].start).clamp(0, lines[i].end - lines[i].start),
      );
    }
  }
  throw const FormatException('Invalid caret.');
}

int codeOffset(String text, CodePosition position) {
  final lines = languageLines(text);
  if (position.line >= lines.length ||
      position.character >
          lines[position.line].end - lines[position.line].start) {
    throw const FormatException(
      'Language tool returned a range outside this source.',
    );
  }
  final offset = lines[position.line].start + position.character;
  if (offset > 0 &&
      offset < text.length &&
      text.codeUnitAt(offset) >= 0xdc00 &&
      text.codeUnitAt(offset) <= 0xdfff &&
      text.codeUnitAt(offset - 1) >= 0xd800 &&
      text.codeUnitAt(offset - 1) <= 0xdbff) {
    throw const FormatException('Language range splits a Unicode character.');
  }
  return offset;
}

class CodeTextEdit {
  const CodeTextEdit(this.start, this.end, this.text);
  final int start, end;
  final String text;
  static CodeTextEdit parse(String source, dynamic value) {
    if (value is! Map ||
        value['range'] is! Map ||
        value['newText'] is! String) {
      throw const FormatException('Invalid language edit.');
    }
    final range = value['range'] as Map;
    return CodeTextEdit(
      codeOffset(source, CodePosition.parse(range['start'])),
      codeOffset(source, CodePosition.parse(range['end'])),
      value['newText'] as String,
    );
  }
}

String applyCodeEdits(String source, List<CodeTextEdit> edits) {
  if (edits.length > 2000) {
    throw const FormatException('Too many language edits.');
  }
  final sorted = List<CodeTextEdit>.of(edits)
    ..sort((a, b) => a.start.compareTo(b.start));
  var previous = -1;
  for (final edit in sorted) {
    if (edit.start < 0 ||
        edit.end < edit.start ||
        edit.end > source.length ||
        edit.start < previous ||
        (edit.start == previous && edit.start == edit.end)) {
      throw const FormatException('Overlapping or invalid language edits.');
    }
    previous = edit.end;
  }
  var result = source;
  for (final edit in sorted.reversed) {
    result = result.replaceRange(edit.start, edit.end, edit.text);
  }
  if (utf8.encode(result).length > 1024 * 1024) {
    throw const FormatException('Language edit exceeds the source size limit.');
  }
  return result;
}

class CodeSuggestion {
  const CodeSuggestion(this.label, this.detail, this.edits);
  final String label, detail;
  final List<CodeTextEdit> edits;
}

String codeLanguageId(String path) =>
    switch (path.split('.').last.toLowerCase()) {
      'html' || 'htm' => 'html',
      'py' => 'python',
      'cpp' || 'cc' || 'cxx' || 'h' || 'hpp' || 'hxx' || 'c' => 'cpp',
      _ => '',
    };

List<CodeSuggestion> offlineCodeSuggestions(
  String source,
  int offset,
  String language,
) {
  if (offset < 0 || offset > source.length) return [];
  final prefix = RegExp(
    r'[A-Za-z_][A-Za-z_0-9]*$',
  ).firstMatch(source.substring(0, offset));
  final start = prefix?.start ?? offset, word = prefix?.group(0) ?? '';
  final templates = switch (language) {
    'python' => {
      'def': 'def function_name():\n    pass',
      'class': 'class ClassName:\n    def __init__(self):\n        pass',
      'for': 'for item in items:\n    pass',
      'if': 'if condition:\n    pass',
      'try': 'try:\n    pass\nexcept Exception as error:\n    print(error)',
      'main': 'if __name__ == "__main__":\n    main()',
      'print': 'print()',
      'import': 'import ',
    },
    'cpp' => {
      'main': '#include <iostream>\n\nint main() {\n    return 0;\n}',
      'class': 'class ClassName {\npublic:\n    ClassName() = default;\n};',
      'for': 'for (const auto& item : items) {\n    \n}',
      'if': 'if (condition) {\n    \n}',
      'struct': 'struct Data {\n    \n};',
      'std': 'std::',
      'include': '#include <>',
    },
    'html' => {
      'html':
          '<!DOCTYPE html>\n<html lang="en">\n<head>\n  <meta charset="UTF-8">\n  <meta name="viewport" content="width=device-width, initial-scale=1">\n  <title>Project</title>\n</head>\n<body>\n  \n</body>\n</html>',
      'div': '<div>\n  \n</div>',
      'a': '<a href="">Link</a>',
      'img': '<img src="" alt="">',
      'script': '<script src="script.js"></script>',
      'link': '<link rel="stylesheet" href="style.css">',
      'button': '<button type="button">Button</button>',
      'section': '<section>\n  \n</section>',
    },
    _ => <String, String>{},
  };
  final lineStart = start == 0
      ? 0
      : source.substring(0, start).lastIndexOf(RegExp(r'[\r\n]')) + 1;
  final indentation =
      RegExp(
        r'^[ \t]*',
      ).firstMatch(source.substring(lineStart, start))?.group(0) ??
      '';
  final ending = RegExp(r'\r\n|\n|\r').firstMatch(source)?.group(0) ?? '\n';
  final suggestions = <CodeSuggestion>[
    for (final e in templates.entries)
      if (word.isEmpty || e.key.startsWith(word))
        CodeSuggestion(e.key, 'Offline snippet', [
          CodeTextEdit(
            start > 0 &&
                    ((language == 'html' &&
                            source[start - 1] == '<' &&
                            e.value.startsWith('<')) ||
                        (language == 'cpp' &&
                            source[start - 1] == '#' &&
                            e.value.startsWith('#')))
                ? start - 1
                : start,
            offset,
            e.value.replaceAll('\n', '$ending$indentation'),
          ),
        ]),
  ];
  final identifiers = RegExp(r'\b[A-Za-z_][A-Za-z_0-9]{1,60}\b')
      .allMatches(source)
      .take(10000)
      .map((m) => m.group(0)!)
      .toSet()
      .where((s) => s != word && s.startsWith(word))
      .take(60);
  for (final id in identifiers) {
    if (!templates.containsKey(id)) {
      suggestions.add(
        CodeSuggestion(id, 'Word in current file', [
          CodeTextEdit(start, offset, id),
        ]),
      );
    }
  }
  return suggestions;
}

class CodeProblem {
  const CodeProblem(
    this.uri,
    this.position,
    this.message,
    this.severity,
    this.version,
  );
  final Uri uri;
  final CodePosition position;
  final String message;
  final int severity;
  final int? version;
}
