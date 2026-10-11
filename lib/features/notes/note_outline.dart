class NoteHeading {
  const NoteHeading(this.title, this.level, this.offset);
  final String title;
  final int level, offset;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteHeading &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          level == other.level &&
          offset == other.offset;

  @override
  int get hashCode => Object.hash(title, level, offset);

  @override
  String toString() => 'NoteHeading("$title", level: $level, offset: $offset)';
}

List<NoteHeading> noteOutline(String source, {bool isLatex = false}) {
  if (isLatex) {
    return _latexOutline(source);
  }
  final result = <NoteHeading>[];
  var offset = 0;
  String? fence;
  var fenceLength = 0;
  String? previous;
  var previousOffset = 0;
  for (final line in source.split('\n')) {
    final visibleLine = line.replaceFirst(
      RegExp(r'[ \t]+\^[A-Za-z0-9][A-Za-z0-9_-]*(?=\r?$)'),
      '',
    );
    final marker = RegExp(r'^ {0,3}(`{3,}|~{3,})(.*)$').firstMatch(line);
    if (fence != null) {
      if (marker != null &&
          marker[1]![0] == fence &&
          marker[1]!.length >= fenceLength &&
          marker[2]!.trim().isEmpty) {
        fence = null;
      }
      previous = null;
    } else if (marker != null) {
      fence = marker[1]![0];
      fenceLength = marker[1]!.length;
      previous = null;
    } else {
      final atx = RegExp(
        r'^ {0,3}(#{1,6})\s+(.+?)\s*#*\s*$',
      ).firstMatch(visibleLine);
      final setext = RegExp(r'^ {0,3}(=+|-+)\s*$').firstMatch(line);
      if (atx != null) {
        result.add(NoteHeading(atx[2]!, atx[1]!.length, offset));
      } else if (setext != null &&
          previous != null &&
          previous.trim().isNotEmpty) {
        result.add(
          NoteHeading(
            previous.trim(),
            setext[1]![0] == '=' ? 1 : 2,
            previousOffset,
          ),
        );
      }
      previous = atx == null && setext == null && !line.startsWith('    ')
          ? visibleLine
          : null;
      previousOffset = offset;
    }
    offset += line.length + 1;
  }
  return result;
}

List<NoteHeading> _latexOutline(String source) {
  final result = <NoteHeading>[];
  var offset = 0;
  final sectionRegex = RegExp(
    r'^\s*\\(chapter|section|subsection|subsubsection|paragraph)\*?\{([^}]+)\}',
  );
  for (final line in source.split('\n')) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('%')) {
      final match = sectionRegex.firstMatch(line);
      if (match != null) {
        final cmd = match.group(1);
        final title = match.group(2)!.trim();
        final int level;
        switch (cmd) {
          case 'chapter':
            level = 1;
            break;
          case 'section':
            level = 1;
            break;
          case 'subsection':
            level = 2;
            break;
          case 'subsubsection':
            level = 3;
            break;
          case 'paragraph':
            level = 4;
            break;
          default:
            level = 1;
        }
        result.add(NoteHeading(title, level, offset));
      }
    }
    offset += line.length + 1;
  }
  return result;
}
