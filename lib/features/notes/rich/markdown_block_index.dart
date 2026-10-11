import 'markdown_document.dart';

/// Transient positions for one version of the editing projection. Recreate after
/// source or block order changes; retaining it never changes the source document.
class MarkdownBlockIndex {
  MarkdownBlockIndex(List<MarkdownBlock> blocks) {
    var offset = 0;
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      _indices.putIfAbsent(block, () => i);
      _starts.add(offset);
      _sources.add(block.source);
      offset += block.source.length;
      _ends.add(offset);
    }
    length = offset;
  }

  final Map<MarkdownBlock, int> _indices = Map.identity();
  final _starts = <int>[];
  final _ends = <int>[];
  final _sources = <String>[];
  late final int length;
  late final String source = _sources.join();

  int indexOf(MarkdownBlock block) => _indices[block] ?? -1;

  int offsetOf(int index) {
    if (index < 0) throw RangeError.value(index, 'index');
    return index < _starts.length ? _starts[index] : length;
  }

  int blockAt(int offset) {
    var low = 0, high = _ends.length;
    while (low < high) {
      final middle = (low + high) >> 1;
      if (offset < _ends[middle]) {
        high = middle;
      } else {
        low = middle + 1;
      }
    }
    return low < _ends.length ? low : _ends.length - 1;
  }
}
