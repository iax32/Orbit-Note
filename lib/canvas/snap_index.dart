import 'dart:math' as math;
import 'equal_spacing.dart';
import 'geometry.dart';

class CanvasSnapTarget {
  const CanvasSnapTarget(
    this.id,
    this.bounds, {
    this.spacing = true,
    this.dynamic = false,
  });
  final String id;
  final CanvasBounds bounds;
  final bool spacing, dynamic;
}

typedef CanvasAxisSnap = ({double delta, double position});
typedef _Coordinate = ({double position, int order, int coordinate});
typedef _Target = ({CanvasSnapTarget target, int order});

/// One immutable gesture index. Alignment remains global (not just a 500-pixel
/// neighborhood), and spacing queries keep the original row/column semantics.
/// Attached moving connectors can supply live bounds without rebuilding it.
class CanvasSnapIndex {
  CanvasSnapIndex(Iterable<CanvasSnapTarget> targets) {
    var order = 0;
    final spacing = <_Target>[];
    for (final target in targets) {
      final item = (target: target, order: order++);
      if (target.dynamic) {
        _dynamic.add(item);
        continue;
      }
      _x.addAll(
        _coordinates(target.bounds, false).indexed.map(
          (c) => (position: c.$2, order: item.order, coordinate: c.$1),
        ),
      );
      _y.addAll(
        _coordinates(target.bounds, true).indexed.map(
          (c) => (position: c.$2, order: item.order, coordinate: c.$1),
        ),
      );
      if (target.spacing) spacing.add(item);
    }
    int compare(_Coordinate a, _Coordinate b) {
      final position = a.position.compareTo(b.position);
      if (position != 0) return position;
      final order = a.order.compareTo(b.order);
      return order != 0 ? order : a.coordinate.compareTo(b.coordinate);
    }

    _x.sort(compare);
    _y.sort(compare);
    _rows = _IntervalNode.build(
      [...spacing]
        ..sort((a, b) => a.target.bounds.top.compareTo(b.target.bounds.top)),
      false,
    );
    _columns = _IntervalNode.build(
      [...spacing]
        ..sort((a, b) => a.target.bounds.left.compareTo(b.target.bounds.left)),
      true,
    );
  }
  final _x = <_Coordinate>[], _y = <_Coordinate>[];
  final _dynamic = <_Target>[];
  _IntervalNode? _rows, _columns;
  Iterable<String> get dynamicIds => _dynamic.map((t) => t.target.id);

  CanvasAxisSnap? alignment(
    CanvasBounds moving, {
    required bool vertical,
    required double tolerance,
    Map<String, CanvasBounds> live = const {},
  }) {
    final axis = vertical ? _y : _x;
    final positions = _coordinates(moving, vertical);
    ({double delta, double position, int order, int moving, int coordinate})?
    best;
    void consider(_Coordinate target, int movingIndex) {
      final delta = target.position - positions[movingIndex];
      if (delta.abs() > tolerance) return;
      final previous = best;
      if (previous == null ||
          delta.abs() < previous.delta.abs() ||
          delta.abs() == previous.delta.abs() &&
              (target.order < previous.order ||
                  target.order == previous.order &&
                      (movingIndex < previous.moving ||
                          movingIndex == previous.moving &&
                              target.coordinate < previous.coordinate))) {
        best = (
          delta: delta,
          position: target.position,
          order: target.order,
          moving: movingIndex,
          coordinate: target.coordinate,
        );
      }
    }

    for (var i = 0; i < positions.length; i++) {
      final found = _lowerBound(axis, positions[i]);
      if (found < axis.length) consider(axis[found], i);
      if (found > 0) {
        // Earliest original target wins ties even for duplicate coordinates.
        final prior = _lowerBound(axis, axis[found - 1].position);
        consider(axis[prior], i);
      }
    }
    for (final item in _dynamic) {
      final coordinates = _coordinates(
        live[item.target.id] ?? item.target.bounds,
        vertical,
      );
      for (var i = 0; i < positions.length; i++) {
        for (var j = 0; j < coordinates.length; j++) {
          consider((
            position: coordinates[j],
            order: item.order,
            coordinate: j,
          ), i);
        }
      }
    }
    return best == null ? null : (delta: best!.delta, position: best!.position);
  }

  CanvasEqualSpacing? spacing(
    CanvasBounds moving, {
    required bool vertical,
    required double tolerance,
    Map<String, CanvasBounds> live = const {},
  }) {
    final items = <_Target>[];
    (vertical ? _columns : _rows)?.query(
      vertical ? moving.left : moving.top,
      vertical ? moving.right : moving.bottom,
      items,
    );
    for (final item in _dynamic) {
      if (!item.target.spacing) continue;
      items.add((
        target: CanvasSnapTarget(
          item.target.id,
          live[item.target.id] ?? item.target.bounds,
        ),
        order: item.order,
      ));
    }
    _Target? before, after;
    double start(CanvasBounds b) => vertical ? b.top : b.left;
    double end(CanvasBounds b) => vertical ? b.bottom : b.right;
    for (final item in items) {
      final b = item.target.bounds;
      if (!(vertical
          ? b.left < moving.right && b.right > moving.left
          : b.top < moving.bottom && b.bottom > moving.top)) {
        continue;
      }
      if (end(b) <= start(moving) &&
          (before == null ||
              end(b) > end(before.target.bounds) ||
              end(b) == end(before.target.bounds) &&
                  item.order < before.order)) {
        before = item;
      }
      if (start(b) >= end(moving) &&
          (after == null ||
              start(b) < start(after.target.bounds) ||
              start(b) == start(after.target.bounds) &&
                  item.order < after.order)) {
        after = item;
      }
    }
    if (before == null || after == null) return null;
    return equalCanvasSpacing(
      moving,
      [before.target.bounds, after.target.bounds],
      vertical: vertical,
      tolerance: tolerance,
    );
  }

  static List<double> _coordinates(CanvasBounds b, bool vertical) =>
      vertical ? [b.top, b.center.y, b.bottom] : [b.left, b.center.x, b.right];
  static int _lowerBound(List<_Coordinate> axis, double value) {
    var low = 0, high = axis.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (axis[mid].position < value) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }
}

class _IntervalNode {
  _IntervalNode(this.value, this.start, this.end, this.left, this.right)
    : maximumEnd = math.max(
        end,
        math.max(
          left?.maximumEnd ?? double.negativeInfinity,
          right?.maximumEnd ?? double.negativeInfinity,
        ),
      );
  final _Target value;
  final double start, end, maximumEnd;
  final _IntervalNode? left, right;
  static _IntervalNode? build(
    List<_Target> values,
    bool horizontal, [
    int start = 0,
    int? end,
  ]) {
    end ??= values.length;
    if (start >= end) return null;
    final mid = (start + end) ~/ 2, value = values[mid];
    final bounds = value.target.bounds;
    return _IntervalNode(
      value,
      horizontal ? bounds.left : bounds.top,
      horizontal ? bounds.right : bounds.bottom,
      build(values, horizontal, start, mid),
      build(values, horizontal, mid + 1, end),
    );
  }

  void query(double from, double to, List<_Target> result) {
    if (maximumEnd <= from) return;
    left?.query(from, to, result);
    if (start < to && end > from) result.add(value);
    if (start < to) right?.query(from, to, result);
  }
}
