/// Lazily computed footer data for one exact source version. Selection/caret
/// changes reuse it; document edits create a new index without delaying metrics.
class NoteTextIndex {
  NoteTextIndex(this.source);
  final String source;
  late final int words = RegExp(r'\S+').allMatches(source).length;
  late final int characters = source.runes.length;
  late final int charactersNoSpaces =
      source.length -
      RegExp(r'\s+')
          .allMatches(source)
          .fold(0, (count, match) => count + match.end - match.start);
  late final List<int> _lineStarts = [
    0,
    for (var i = 0; i < source.length; i++)
      if (source.codeUnitAt(i) == 10) i + 1,
  ];
  int get lines => _lineStarts.length;

  ({int line, int column}) lineAndColumn(int offset) {
    final clamped = offset.clamp(0, source.length);
    var low = 0, high = _lineStarts.length;
    while (low < high) {
      final middle = (low + high) >> 1;
      if (_lineStarts[middle] <= clamped) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return (line: low, column: clamped - _lineStarts[low - 1] + 1);
  }
}
