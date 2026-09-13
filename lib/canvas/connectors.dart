import 'dart:math' as math;

import 'geometry.dart';
import 'scene.dart';

bool isConnectorElement(CanvasElement e) =>
    const {'arrow', 'line', 'connector'}.contains(e.type);

CanvasPoint storedConnectorStart(CanvasElement e) =>
    e.data['startX'] is num &&
        e.data['startY'] is num &&
        (e.data['startX'] as num).isFinite &&
        (e.data['startY'] as num).isFinite
    ? CanvasPoint(
        (e.data['startX'] as num).toDouble(),
        (e.data['startY'] as num).toDouble(),
      )
    : CanvasPoint(
        e.data['reverseX'] == true ? e.bounds.right : e.bounds.left,
        e.data['reverseY'] == true ? e.bounds.bottom : e.bounds.top,
      );

CanvasPoint storedConnectorEnd(CanvasElement e) =>
    e.data['endX'] is num &&
        e.data['endY'] is num &&
        (e.data['endX'] as num).isFinite &&
        (e.data['endY'] as num).isFinite
    ? CanvasPoint(
        (e.data['endX'] as num).toDouble(),
        (e.data['endY'] as num).toDouble(),
      )
    : CanvasPoint(
        e.data['reverseX'] == true ? e.bounds.left : e.bounds.right,
        e.data['reverseY'] == true ? e.bounds.top : e.bounds.bottom,
      );

/// Explicit world endpoints, with legacy bounds/direction retained for older readers.
Map<String, dynamic> connectorEndpointData(
  CanvasPoint start,
  CanvasPoint end,
) => {
  'startX': start.x,
  'startY': start.y,
  'endX': end.x,
  'endY': end.y,
  'x': math.min(start.x, end.x),
  'y': math.min(start.y, end.y),
  'width': (end.x - start.x).abs(),
  'height': (end.y - start.y).abs(),
  'reverseX': end.x < start.x,
  'reverseY': end.y < start.y,
};

enum ConnectorAnchor {
  auto,
  top,
  bottom,
  left,
  right;

  static ConnectorAnchor parse(String? value) {
    switch (value?.toLowerCase()) {
      case 'top':
        return ConnectorAnchor.top;
      case 'bottom':
        return ConnectorAnchor.bottom;
      case 'left':
        return ConnectorAnchor.left;
      case 'right':
        return ConnectorAnchor.right;
      default:
        return ConnectorAnchor.auto;
    }
  }

  String get label {
    switch (this) {
      case ConnectorAnchor.top:
        return 'top';
      case ConnectorAnchor.bottom:
        return 'bottom';
      case ConnectorAnchor.left:
        return 'left';
      case ConnectorAnchor.right:
        return 'right';
      case ConnectorAnchor.auto:
        return 'auto';
    }
  }
}

enum ConnectorStyle {
  solid,
  dashed,
  dotted;

  static ConnectorStyle parse(String? value) {
    switch (value?.toLowerCase()) {
      case 'dashed':
        return ConnectorStyle.dashed;
      case 'dotted':
        return ConnectorStyle.dotted;
      default:
        return ConnectorStyle.solid;
    }
  }

  String get label {
    switch (this) {
      case ConnectorStyle.solid:
        return 'Solid';
      case ConnectorStyle.dashed:
        return 'Dashed';
      case ConnectorStyle.dotted:
        return 'Dotted';
    }
  }
}

enum ConnectorMarker {
  none,
  arrow,
  dot,
  diamond;

  static ConnectorMarker parse(
    String? value, {
    ConnectorMarker defaultMarker = ConnectorMarker.none,
  }) {
    switch (value?.toLowerCase()) {
      case 'arrow':
        return ConnectorMarker.arrow;
      case 'dot':
        return ConnectorMarker.dot;
      case 'diamond':
        return ConnectorMarker.diamond;
      case 'none':
        return ConnectorMarker.none;
      default:
        return defaultMarker;
    }
  }

  String get label {
    switch (this) {
      case ConnectorMarker.none:
        return 'None';
      case ConnectorMarker.arrow:
        return 'Arrow';
      case ConnectorMarker.dot:
        return 'Dot';
      case ConnectorMarker.diamond:
        return 'Diamond';
    }
  }
}

enum ConnectorRouting {
  straight,
  curved,
  orthogonal;

  static ConnectorRouting parse(String? value) {
    switch (value?.toLowerCase()) {
      case 'curved':
        return ConnectorRouting.curved;
      case 'orthogonal':
        return ConnectorRouting.orthogonal;
      default:
        return ConnectorRouting.straight;
    }
  }

  String get label {
    switch (this) {
      case ConnectorRouting.straight:
        return 'Straight';
      case ConnectorRouting.curved:
        return 'Curved';
      case ConnectorRouting.orthogonal:
        return 'Orthogonal';
    }
  }
}

class ConnectorEndpoints {
  const ConnectorEndpoints({
    required this.start,
    required this.end,
    this.resolvedStartAnchor = ConnectorAnchor.auto,
    this.resolvedEndAnchor = ConnectorAnchor.auto,
    this.controlPoints = const [],
  });

  final CanvasPoint start;
  final CanvasPoint end;
  final ConnectorAnchor resolvedStartAnchor;
  final ConnectorAnchor resolvedEndAnchor;
  final List<CanvasPoint> controlPoints;

  CanvasPoint get midpoint {
    if (controlPoints.isNotEmpty) {
      final midIdx = controlPoints.length ~/ 2;
      return controlPoints[midIdx];
    }
    return CanvasPoint((start.x + end.x) / 2, (start.y + end.y) / 2);
  }

  CanvasBounds get bounds {
    final allPoints = [start, end, ...controlPoints];
    var minX = allPoints.first.x;
    var maxX = allPoints.first.x;
    var minY = allPoints.first.y;
    var maxY = allPoints.first.y;
    for (final p in allPoints.skip(1)) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    return CanvasBounds(
      minX,
      minY,
      math.max(1, maxX - minX),
      math.max(1, maxY - minY),
    );
  }
}

/// Returns the 4 perimeter anchors and center for a given bounding box.
Map<ConnectorAnchor, CanvasPoint> getElementAnchors(CanvasBounds bounds) {
  return {
    ConnectorAnchor.top: CanvasPoint(bounds.center.x, bounds.top),
    ConnectorAnchor.bottom: CanvasPoint(bounds.center.x, bounds.bottom),
    ConnectorAnchor.left: CanvasPoint(bounds.left, bounds.center.y),
    ConnectorAnchor.right: CanvasPoint(bounds.right, bounds.center.y),
  };
}

/// Finds the closest anchor on [bounds] to [targetPoint].
ConnectorAnchor findClosestAnchor(
  CanvasBounds bounds,
  CanvasPoint targetPoint,
) {
  final anchors = getElementAnchors(bounds);
  ConnectorAnchor bestAnchor = ConnectorAnchor.top;
  double bestDistance = double.infinity;
  for (final entry in anchors.entries) {
    final d = (entry.value - targetPoint).length;
    if (d < bestDistance) {
      bestDistance = d;
      bestAnchor = entry.key;
    }
  }
  return bestAnchor;
}

/// Resolves the absolute start and end world points and any routing control points
/// for a connector or arrow, considering attached scene elements and anchors.
ConnectorEndpoints resolveConnectorEndpoints(
  CanvasElement connector,
  CanvasScene scene,
) {
  final startId = connector.data['startId'] as String?;
  final endId = connector.data['endId'] as String?;
  final startElem = startId != null ? scene[startId] : null;
  final endElem = endId != null ? scene[endId] : null;

  final startAnchorSetting = ConnectorAnchor.parse(
    connector.data['startAnchor'] as String?,
  );
  final endAnchorSetting = ConnectorAnchor.parse(
    connector.data['endAnchor'] as String?,
  );
  final routing = ConnectorRouting.parse(connector.data['routing'] as String?);

  CanvasPoint startPoint;
  CanvasPoint endPoint;
  ConnectorAnchor resolvedStartAnchor = startAnchorSetting;
  ConnectorAnchor resolvedEndAnchor = endAnchorSetting;

  if (startElem != null && endElem != null) {
    final startAnchors = getElementAnchors(startElem.bounds);
    final endAnchors = getElementAnchors(endElem.bounds);

    if (startAnchorSetting == ConnectorAnchor.auto &&
        endAnchorSetting == ConnectorAnchor.auto) {
      final dx = endElem.bounds.center.x - startElem.bounds.center.x;
      final dy = endElem.bounds.center.y - startElem.bounds.center.y;
      if (dx.abs() >= dy.abs()) {
        if (dx > 0) {
          resolvedStartAnchor = ConnectorAnchor.right;
          resolvedEndAnchor = ConnectorAnchor.left;
        } else {
          resolvedStartAnchor = ConnectorAnchor.left;
          resolvedEndAnchor = ConnectorAnchor.right;
        }
      } else {
        if (dy > 0) {
          resolvedStartAnchor = ConnectorAnchor.bottom;
          resolvedEndAnchor = ConnectorAnchor.top;
        } else {
          resolvedStartAnchor = ConnectorAnchor.top;
          resolvedEndAnchor = ConnectorAnchor.bottom;
        }
      }
    } else if (startAnchorSetting == ConnectorAnchor.auto) {
      resolvedStartAnchor = findClosestAnchor(
        startElem.bounds,
        endAnchors[resolvedEndAnchor] ?? endElem.bounds.center,
      );
    } else if (endAnchorSetting == ConnectorAnchor.auto) {
      resolvedEndAnchor = findClosestAnchor(
        endElem.bounds,
        startAnchors[resolvedStartAnchor] ?? startElem.bounds.center,
      );
    }

    startPoint = startAnchors[resolvedStartAnchor] ?? startElem.bounds.center;
    endPoint = endAnchors[resolvedEndAnchor] ?? endElem.bounds.center;
  } else if (startElem != null) {
    endPoint = storedConnectorEnd(connector);
    resolvedStartAnchor = startAnchorSetting == ConnectorAnchor.auto
        ? findClosestAnchor(startElem.bounds, endPoint)
        : startAnchorSetting;
    startPoint =
        getElementAnchors(startElem.bounds)[resolvedStartAnchor] ??
        startElem.bounds.center;
  } else if (endElem != null) {
    startPoint = storedConnectorStart(connector);
    resolvedEndAnchor = endAnchorSetting == ConnectorAnchor.auto
        ? findClosestAnchor(endElem.bounds, startPoint)
        : endAnchorSetting;
    endPoint =
        getElementAnchors(endElem.bounds)[resolvedEndAnchor] ??
        endElem.bounds.center;
  } else {
    startPoint = storedConnectorStart(connector);
    endPoint = storedConnectorEnd(connector);
  }
  final controlPoints = <CanvasPoint>[];
  if (routing == ConnectorRouting.curved) {
    final dist = (endPoint - startPoint).length;
    final curveDistance = math.min(100.0, math.max(30.0, dist * 0.35));

    CanvasPoint cp1;
    switch (resolvedStartAnchor) {
      case ConnectorAnchor.right:
        cp1 = CanvasPoint(startPoint.x + curveDistance, startPoint.y);
      case ConnectorAnchor.left:
        cp1 = CanvasPoint(startPoint.x - curveDistance, startPoint.y);
      case ConnectorAnchor.bottom:
        cp1 = CanvasPoint(startPoint.x, startPoint.y + curveDistance);
      case ConnectorAnchor.top:
        cp1 = CanvasPoint(startPoint.x, startPoint.y - curveDistance);
      case ConnectorAnchor.auto:
        cp1 = CanvasPoint(
          startPoint.x + (endPoint.x - startPoint.x) * 0.3,
          startPoint.y + (endPoint.y - startPoint.y) * 0.1,
        );
    }

    CanvasPoint cp2;
    switch (resolvedEndAnchor) {
      case ConnectorAnchor.left:
        cp2 = CanvasPoint(endPoint.x - curveDistance, endPoint.y);
      case ConnectorAnchor.right:
        cp2 = CanvasPoint(endPoint.x + curveDistance, endPoint.y);
      case ConnectorAnchor.top:
        cp2 = CanvasPoint(endPoint.x, endPoint.y - curveDistance);
      case ConnectorAnchor.bottom:
        cp2 = CanvasPoint(endPoint.x, endPoint.y + curveDistance);
      case ConnectorAnchor.auto:
        cp2 = CanvasPoint(
          endPoint.x - (endPoint.x - startPoint.x) * 0.3,
          endPoint.y - (endPoint.y - startPoint.y) * 0.1,
        );
    }

    controlPoints.addAll([cp1, cp2]);
  } else if (routing == ConnectorRouting.orthogonal) {
    if (resolvedStartAnchor == ConnectorAnchor.left ||
        resolvedStartAnchor == ConnectorAnchor.right) {
      if (resolvedEndAnchor == ConnectorAnchor.left ||
          resolvedEndAnchor == ConnectorAnchor.right) {
        final midX = (startPoint.x + endPoint.x) / 2;
        controlPoints.add(CanvasPoint(midX, startPoint.y));
        controlPoints.add(CanvasPoint(midX, endPoint.y));
      } else {
        controlPoints.add(CanvasPoint(endPoint.x, startPoint.y));
      }
    } else {
      if (resolvedEndAnchor == ConnectorAnchor.top ||
          resolvedEndAnchor == ConnectorAnchor.bottom) {
        final midY = (startPoint.y + endPoint.y) / 2;
        controlPoints.add(CanvasPoint(startPoint.x, midY));
        controlPoints.add(CanvasPoint(endPoint.x, midY));
      } else {
        controlPoints.add(CanvasPoint(startPoint.x, endPoint.y));
      }
    }
  }

  return ConnectorEndpoints(
    start: startPoint,
    end: endPoint,
    resolvedStartAnchor: resolvedStartAnchor,
    resolvedEndAnchor: resolvedEndAnchor,
    controlPoints: controlPoints,
  );
}

/// Tests if [point] hits a connector, arrow, or line, including its curved or
/// orthogonal path and its label pill, within [tolerance].
bool hitTestConnector(
  CanvasElement connector,
  CanvasScene scene,
  CanvasPoint point, {
  double tolerance = 5,
}) {
  final endpoints = resolveConnectorEndpoints(connector, scene);
  final effTol = tolerance + connector.strokeWidth / 2;

  // 1. Test text label pill bounds if text is present
  if (connector.text.trim().isNotEmpty) {
    final mid = endpoints.midpoint;
    final labelWidth = math.max(
      60.0,
      connector.text.trim().length * 8.5 + 16.0,
    );
    final labelBounds = CanvasBounds(
      mid.x - labelWidth / 2,
      mid.y - 14,
      labelWidth,
      28,
    ).inflate(tolerance);
    if (labelBounds.contains(point)) return true;
  }

  // 2. Test routing geometry
  final routing = ConnectorRouting.parse(connector.data['routing'] as String?);
  if (routing == ConnectorRouting.curved &&
      endpoints.controlPoints.length >= 2) {
    // Subdivide cubic bezier curve
    final p0 = endpoints.start;
    final p1 = endpoints.controlPoints[0];
    final p2 = endpoints.controlPoints[1];
    final p3 = endpoints.end;
    const steps = 16;
    CanvasPoint prev = p0;
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final mt = 1.0 - t;
      final x =
          mt * mt * mt * p0.x +
          3 * mt * mt * t * p1.x +
          3 * mt * t * t * p2.x +
          t * t * t * p3.x;
      final y =
          mt * mt * mt * p0.y +
          3 * mt * mt * t * p1.y +
          3 * mt * t * t * p2.y +
          t * t * t * p3.y;
      final curr = CanvasPoint(x, y);
      if (distanceToSegment(point, prev, curr) <= effTol) {
        return true;
      }
      prev = curr;
    }
    return false;
  } else if (routing == ConnectorRouting.orthogonal &&
      endpoints.controlPoints.isNotEmpty) {
    final pts = [endpoints.start, ...endpoints.controlPoints, endpoints.end];
    for (var i = 1; i < pts.length; i++) {
      if (distanceToSegment(point, pts[i - 1], pts[i]) <= effTol) {
        return true;
      }
    }
    return false;
  } else {
    // Straight segment
    return distanceToSegment(point, endpoints.start, endpoints.end) <= effTol;
  }
}
