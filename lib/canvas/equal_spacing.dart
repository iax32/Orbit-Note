import 'geometry.dart';

class CanvasEqualSpacing {
  const CanvasEqualSpacing(
    this.delta,
    this.position,
    this.before,
    this.after,
    this.gap,
  );
  final double delta, position, before, after, gap;
}

/// Nearest non-overlapping neighbors on one row/column. Linear in scene size.
CanvasEqualSpacing? equalCanvasSpacing(
  CanvasBounds moving,
  Iterable<CanvasBounds> others, {
  required bool vertical,
  required double tolerance,
}) {
  CanvasBounds? before, after;
  double start(CanvasBounds b) => vertical ? b.top : b.left;
  double end(CanvasBounds b) => vertical ? b.bottom : b.right;
  bool overlaps(CanvasBounds b) => vertical
      ? b.left < moving.right && b.right > moving.left
      : b.top < moving.bottom && b.bottom > moving.top;
  for (final b in others) {
    if (!overlaps(b)) continue;
    if (end(b) <= start(moving) && (before == null || end(b) > end(before))) {
      before = b;
    }
    if (start(b) >= end(moving) && (after == null || start(b) < start(after))) {
      after = b;
    }
  }
  if (before == null || after == null) return null;
  final leftGap = start(moving) - end(before),
      rightGap = start(after) - end(moving);
  if ((leftGap - rightGap).abs() > tolerance * 2) return null;
  return CanvasEqualSpacing(
    (rightGap - leftGap) / 2,
    vertical ? moving.center.x : moving.center.y,
    end(before),
    start(after),
    (leftGap + rightGap) / 2,
  );
}
