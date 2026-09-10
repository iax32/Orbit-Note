import 'geometry.dart';
import 'scene.dart';

enum CanvasArrangement {
  left,
  center,
  right,
  top,
  middle,
  bottom,
  horizontal,
  vertical;

  String get label => switch (this) {
    left => 'Align left',
    center => 'Align horizontal centers',
    right => 'Align right',
    top => 'Align top',
    middle => 'Align vertical centers',
    bottom => 'Align bottom',
    horizontal => 'Distribute horizontally',
    vertical => 'Distribute vertically',
  };
}

/// Pure geometry; callers apply the returned placements as one undo command.
List<CanvasElement> arrangeCanvas(
  Iterable<CanvasElement> selection,
  CanvasArrangement action,
) {
  final elements = selection.where((e) => !e.locked).toList();
  if (elements.length < 2) return [];
  final bounds = elements.map((e) => e.bounds).reduce((a, b) => a.union(b));
  if (action == CanvasArrangement.horizontal ||
      action == CanvasArrangement.vertical) {
    if (elements.length < 3) return [];
    final horizontal = action == CanvasArrangement.horizontal;
    elements.sort(
      (a, b) => (horizontal ? a.x.compareTo(b.x) : a.y.compareTo(b.y)),
    );
    final first = elements.first, last = elements.last;
    final start = horizontal ? first.x : first.y;
    final end = horizontal ? last.x + last.width : last.y + last.height;
    final total = elements.fold<double>(
      0,
      (sum, e) => sum + (horizontal ? e.width : e.height),
    );
    final gap = (end - start - total) / (elements.length - 1);
    var cursor = start;
    return elements.map((e) {
      final result = e.translated(
        horizontal
            ? CanvasPoint(cursor - e.x, 0)
            : CanvasPoint(0, cursor - e.y),
      );
      cursor += (horizontal ? e.width : e.height) + gap;
      return result;
    }).toList();
  }
  return elements
      .map(
        (e) => e.translated(switch (action) {
          CanvasArrangement.left => CanvasPoint(bounds.left - e.x, 0),
          CanvasArrangement.center => CanvasPoint(
            bounds.center.x - e.bounds.center.x,
            0,
          ),
          CanvasArrangement.right => CanvasPoint(
            bounds.right - e.bounds.right,
            0,
          ),
          CanvasArrangement.top => CanvasPoint(0, bounds.top - e.y),
          CanvasArrangement.middle => CanvasPoint(
            0,
            bounds.center.y - e.bounds.center.y,
          ),
          CanvasArrangement.bottom => CanvasPoint(
            0,
            bounds.bottom - e.bounds.bottom,
          ),
          _ => const CanvasPoint(0, 0),
        }),
      )
      .toList();
}
