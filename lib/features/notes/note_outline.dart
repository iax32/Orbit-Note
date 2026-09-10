class NoteHeading {
  const NoteHeading(this.title, this.level, this.offset);
  final String title;
  final int level, offset;
}

List<NoteHeading> noteOutline(String source) {
  final result = <NoteHeading>[];
  var offset = 0;
  String? fence;
  var fenceLength = 0;
  String? previous;
  var previousOffset = 0;
  for (final line in source.split('\n')) {
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
      final atx = RegExp(r'^ {0,3}(#{1,6})\s+(.+?)\s*#*\s*$').firstMatch(line);
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
          ? line
          : null;
      previousOffset = offset;
    }
    offset += line.length + 1;
  }
  return result;
}
