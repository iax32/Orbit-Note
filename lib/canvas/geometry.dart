import 'dart:math' as math;

/// Geometry shared by board, freeform and annotation consumers, without Flutter.
class CanvasPoint {
  const CanvasPoint(this.x, this.y);
  final double x;
  final double y;

  CanvasPoint operator +(CanvasPoint other) =>
      CanvasPoint(x + other.x, y + other.y);
  CanvasPoint operator -(CanvasPoint other) =>
      CanvasPoint(x - other.x, y - other.y);
  CanvasPoint operator *(double factor) => CanvasPoint(x * factor, y * factor);
  double get length => math.sqrt(x * x + y * y);
}

class CanvasBounds {
  const CanvasBounds(this.left, this.top, this.width, this.height);
  factory CanvasBounds.between(CanvasPoint a, CanvasPoint b) => CanvasBounds(
    math.min(a.x, b.x),
    math.min(a.y, b.y),
    (a.x - b.x).abs(),
    (a.y - b.y).abs(),
  );

  final double left;
  final double top;
  final double width;
  final double height;
  double get right => left + width;
  double get bottom => top + height;
  CanvasPoint get center => CanvasPoint(left + width / 2, top + height / 2);

  bool contains(CanvasPoint point) =>
      point.x >= left &&
      point.x <= right &&
      point.y >= top &&
      point.y <= bottom;
  bool intersects(CanvasBounds other) =>
      left <= other.right &&
      right >= other.left &&
      top <= other.bottom &&
      bottom >= other.top;
  CanvasBounds inflate(double delta) => CanvasBounds(
    left - delta,
    top - delta,
    width + delta * 2,
    height + delta * 2,
  );
  CanvasBounds union(CanvasBounds other) => CanvasBounds(
    math.min(left, other.left),
    math.min(top, other.top),
    math.max(right, other.right) - math.min(left, other.left),
    math.max(bottom, other.bottom) - math.min(top, other.top),
  );
}

class CanvasGuideLine {
  const CanvasGuideLine({required this.isVertical, required this.position});
  final bool isVertical;
  final double position;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasGuideLine &&
          runtimeType == other.runtimeType &&
          isVertical == other.isVertical &&
          position == other.position;

  @override
  int get hashCode => Object.hash(isVertical, position);
}

class CanvasCamera {
  const CanvasCamera({this.x = 0, this.y = 0, this.zoom = 1});
  factory CanvasCamera.fromJson(Map<String, dynamic>? data) => CanvasCamera(
    x: finiteNumber(data?['x'], 0),
    y: finiteNumber(data?['y'], 0),
    zoom: finiteNumber(data?['zoom'], 1).clamp(.1, 4),
  );

  final double x;
  final double y;
  final double zoom;
  CanvasPoint toScreen(CanvasPoint world) =>
      CanvasPoint((world.x - x) * zoom, (world.y - y) * zoom);
  CanvasPoint toWorld(CanvasPoint screen) =>
      CanvasPoint(screen.x / zoom + x, screen.y / zoom + y);
  CanvasCamera pan(CanvasPoint screenDelta) => CanvasCamera(
    x: x - screenDelta.x / zoom,
    y: y - screenDelta.y / zoom,
    zoom: zoom,
  );
  CanvasCamera zoomAt(CanvasPoint screenAnchor, double factor) {
    final world = toWorld(screenAnchor);
    final nextZoom = (zoom * factor).clamp(.1, 4.0);
    return CanvasCamera(
      x: world.x - screenAnchor.x / nextZoom,
      y: world.y - screenAnchor.y / nextZoom,
      zoom: nextZoom,
    );
  }

  CanvasBounds viewport(double width, double height) =>
      CanvasBounds(x, y, width / zoom, height / zoom);
  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'zoom': zoom};
}

double finiteNumber(Object? value, double fallback) =>
    value is num && value.isFinite ? value.toDouble() : fallback;

/// Bounded grid membership prevents a giant element allocating millions of cells.
class CanvasSpatialIndex {
  CanvasSpatialIndex({this.cellSize = 512});
  final double cellSize;
  final Map<String, CanvasBounds> _bounds = {};
  final Map<(int, int), Set<String>> _cells = {};
  final Set<String> _large = {};

  Iterable<(int, int)> _keys(CanvasBounds bounds) sync* {
    for (
      var x = (bounds.left / cellSize).floor();
      x <= (bounds.right / cellSize).floor();
      x++
    ) {
      for (
        var y = (bounds.top / cellSize).floor();
        y <= (bounds.bottom / cellSize).floor();
        y++
      ) {
        yield (x, y);
      }
    }
  }

  bool _isLarge(CanvasBounds bounds) =>
      ((bounds.right / cellSize).floor() -
              (bounds.left / cellSize).floor() +
              1) *
          ((bounds.bottom / cellSize).floor() -
              (bounds.top / cellSize).floor() +
              1) >
      256;

  void put(String id, CanvasBounds bounds) {
    remove(id);
    _bounds[id] = bounds;
    if (_isLarge(bounds)) {
      _large.add(id);
    } else {
      for (final key in _keys(bounds)) {
        (_cells[key] ??= {}).add(id);
      }
    }
  }

  void remove(String id) {
    final previous = _bounds.remove(id);
    if (previous == null || _large.remove(id)) return;
    for (final key in _keys(previous)) {
      final cell = _cells[key];
      cell?.remove(id);
      if (cell?.isEmpty ?? false) _cells.remove(key);
    }
  }

  Set<String> query(CanvasBounds bounds) {
    final candidates = <String>{..._large};
    if (_isLarge(bounds)) {
      candidates.addAll(_bounds.keys);
    } else {
      for (final key in _keys(bounds)) {
        candidates.addAll(_cells[key] ?? const <String>{});
      }
    }
    return candidates.where((id) => _bounds[id]!.intersects(bounds)).toSet();
  }
}
