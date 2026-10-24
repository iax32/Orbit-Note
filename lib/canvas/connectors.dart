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
  diamond,
  filledTriangle,
  hollowTriangle,
  hollowDiamond,
  filledDiamond;

  static ConnectorMarker parse(
    String? value, {
    ConnectorMarker defaultMarker = ConnectorMarker.none,
  }) {
    switch (value?.toLowerCase()) {
      case 'filledtriangle':
        return ConnectorMarker.filledTriangle;
      case 'hollowtriangle':
        return ConnectorMarker.hollowTriangle;
      case 'hollowdiamond':
        return ConnectorMarker.hollowDiamond;
      case 'filleddiamond':
        return ConnectorMarker.filledDiamond;
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
      case ConnectorMarker.hollowTriangle:
        return 'Hollow triangle';
      case ConnectorMarker.filledTriangle:
        return 'Filled triangle';
      case ConnectorMarker.hollowDiamond:
        return 'Hollow diamond';
      case ConnectorMarker.filledDiamond:
        return 'Filled diamond';
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

  CanvasPoint tangentTarget({required bool atStart}) {
    final tip = atStart ? start : end;
    final candidates = atStart
        ? [...controlPoints, end]
        : [...controlPoints.reversed, start];
    return candidates.firstWhere(
      (p) => (p - tip).length > .001,
      orElse: () => tip + const CanvasPoint(1, 0),
    );
  }

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
  final startId = connector.startId;
  final endId = connector.endId;
  final startElem = startId != null ? scene[startId] : null;
  final endElem = endId != null ? scene[endId] : null;

  final startAnchorSetting = ConnectorAnchor.parse(connector.startAnchor);
  final endAnchorSetting = ConnectorAnchor.parse(connector.endAnchor);
  final routing = ConnectorRouting.parse(connector.routing);

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
  CanvasPoint offsetAnchor(
    CanvasElement node,
    CanvasPoint point,
    ConnectorAnchor anchor,
    Object? raw,
  ) {
    if (raw is! num || !raw.isFinite) return point;
    final fraction = raw.toDouble().clamp(0.0, 1.0);
    return switch (anchor) {
      ConnectorAnchor.left || ConnectorAnchor.right => CanvasPoint(
        point.x,
        node.y + node.height * fraction,
      ),
      ConnectorAnchor.top || ConnectorAnchor.bottom => CanvasPoint(
        node.x + node.width * fraction,
        point.y,
      ),
      ConnectorAnchor.auto => point,
    };
  }

  if (startElem != null) {
    startPoint = offsetAnchor(
      startElem,
      startPoint,
      resolvedStartAnchor,
      connector.data['startAnchorOffset'],
    );
  }
  if (endElem != null) {
    endPoint = offsetAnchor(
      endElem,
      endPoint,
      resolvedEndAnchor,
      connector.data['endAnchorOffset'],
    );
  }
  // Sequence messages attach to the lifeline centre, below its participant
  // header. Existing connector data still supplies an old-reader fallback.
  final link = connector.data['umlLink'];
  final sequence =
      link is Map &&
      const {
        'synchronous',
        'asynchronous',
        'reply',
        'create',
        'destroy',
      }.contains(link['kind']);
  if (sequence && startElem != null && endElem != null) {
    final position = finiteNumber(link['position'], .3).clamp(.12, .9);
    startPoint = CanvasPoint(
      startElem.bounds.center.x,
      startElem.y + math.max(68, startElem.height * position),
    );
    endPoint = CanvasPoint(
      endElem.bounds.center.x,
      endElem.y + math.max(68, endElem.height * position),
    );
    if (link['kind'] == 'create') {
      endPoint = CanvasPoint(
        startPoint.x < endElem.bounds.center.x
            ? endElem.bounds.left
            : endElem.bounds.right,
        endElem.y + 32,
      );
    } else if (link['kind'] == 'destroy') {
      endPoint = CanvasPoint(
        endElem.bounds.center.x,
        endElem.bounds.bottom - 5,
      );
    }
    if (startElem.id == endElem.id) {
      endPoint = CanvasPoint(
        startPoint.x,
        math.min(startElem.bounds.bottom, startPoint.y + 40),
      );
      return ConnectorEndpoints(
        start: startPoint,
        end: endPoint,
        controlPoints: [
          CanvasPoint(startPoint.x + 72, startPoint.y),
          CanvasPoint(startPoint.x + 72, endPoint.y),
        ],
      );
    }
  }
  // Ellipse connectors touch the oval, rather than its bounding rectangle.
  CanvasPoint ovalEdge(CanvasElement node, CanvasPoint toward) {
    final center = node.bounds.center, delta = toward - center;
    final rx = math.max(1.0, node.width / 2),
        ry = math.max(1.0, node.height / 2);
    final scale = math.sqrt(
      delta.x * delta.x / (rx * rx) + delta.y * delta.y / (ry * ry),
    );
    return scale < .001
        ? CanvasPoint(center.x + rx, center.y)
        : center + delta * (1 / scale);
  }

  if (!sequence && routing == ConnectorRouting.straight) {
    CanvasPoint actorAnchor(CanvasElement node) => CanvasPoint(
      node.bounds.center.x,
      node.y + math.min(94.0, node.height * .62) * .48,
    );
    if (startElem?.data['umlNode'] is Map &&
        (startElem!.data['umlNode'] as Map)['kind'] == 'actor') {
      startPoint = actorAnchor(startElem);
    }
    if (endElem?.data['umlNode'] is Map &&
        (endElem!.data['umlNode'] as Map)['kind'] == 'actor') {
      endPoint = actorAnchor(endElem);
    }
    if (startElem?.type == 'ellipse' &&
        startAnchorSetting == ConnectorAnchor.auto) {
      startPoint = ovalEdge(startElem!, endElem?.bounds.center ?? endPoint);
    }
    if (endElem?.type == 'ellipse' &&
        endAnchorSetting == ConnectorAnchor.auto) {
      endPoint = ovalEdge(endElem!, startElem?.bounds.center ?? startPoint);
    }
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
    final lane = finiteNumber(
      connector.data['routingOffset'],
      0,
    ).clamp(-10000.0, 10000.0);
    if (resolvedStartAnchor == ConnectorAnchor.left ||
        resolvedStartAnchor == ConnectorAnchor.right) {
      if (resolvedEndAnchor == ConnectorAnchor.left ||
          resolvedEndAnchor == ConnectorAnchor.right) {
        final midX = (startPoint.x + endPoint.x) / 2 + lane;
        controlPoints.add(CanvasPoint(midX, startPoint.y));
        controlPoints.add(CanvasPoint(midX, endPoint.y));
      } else {
        controlPoints.add(CanvasPoint(endPoint.x, startPoint.y));
      }
    } else {
      if (resolvedEndAnchor == ConnectorAnchor.top ||
          resolvedEndAnchor == ConnectorAnchor.bottom) {
        final midY = (startPoint.y + endPoint.y) / 2 + lane;
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

  for (final label in connectorEndLabels(connector, endpoints)) {
    if (label.bounds.inflate(tolerance).contains(point)) return true;
  }

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
  final routing = ConnectorRouting.parse(connector.routing);
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

/// Shared geometry for Canvas paint and portable SVG. The tip touches the class;
/// closed UML markers extend back along the edge, away from the class interior.
List<CanvasPoint> umlMarkerPolygon(
  ConnectorMarker marker,
  CanvasPoint tip,
  CanvasPoint toward,
) {
  if (!{
    ConnectorMarker.filledTriangle,
    ConnectorMarker.hollowTriangle,
    ConnectorMarker.hollowDiamond,
    ConnectorMarker.filledDiamond,
  }.contains(marker)) {
    return const [];
  }
  final delta = toward - tip;
  final length = math.max(.001, delta.length);
  final axis = CanvasPoint(delta.x / length, delta.y / length);
  final normal = CanvasPoint(-axis.y, axis.x);
  if (marker == ConnectorMarker.hollowTriangle ||
      marker == ConnectorMarker.filledTriangle) {
    return [tip, tip + axis * 20 + normal * 10, tip + axis * 20 - normal * 10];
  }
  return [
    tip,
    tip + axis * 12 + normal * 7,
    tip + axis * 24,
    tip + axis * 12 - normal * 7,
  ];
}

List<({String text, CanvasBounds bounds})> connectorEndLabels(
  CanvasElement e,
  ConnectorEndpoints endpoints,
) {
  final result = <({String text, CanvasBounds bounds})>[];
  for (final atStart in [true, false]) {
    final prefix = atStart ? 'start' : 'end';
    final lines = [e.data['${prefix}Multiplicity'], e.data['${prefix}Role']]
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim())
        .toList();
    if (lines.isEmpty) continue;
    final tip = atStart ? endpoints.start : endpoints.end;
    final toward = endpoints.tangentTarget(atStart: atStart);
    final delta = toward - tip;
    final width =
        (lines.fold<int>(0, (n, s) => math.max(n, s.length)) * 8.0 + 12).clamp(
          36.0,
          240.0,
        );
    final height = lines.length * 18.0 + 4;
    final horizontal = delta.x.abs() >= delta.y.abs();
    final x = horizontal
        ? (delta.x >= 0 ? tip.x + 28 : tip.x - width - 28)
        : tip.x + 12;
    final y = horizontal
        ? tip.y - height - 6
        : (delta.y >= 0 ? tip.y + 28 : tip.y - height - 28);
    result.add((
      text: lines.join('\n'),
      bounds: CanvasBounds(x, y, width, height),
    ));
  }
  // Short relationships can place both multiplicities on the same patch of
  // paper. Keep the second label on the opposite side of the edge instead.
  if (result.length == 2 &&
      result.first.bounds.inflate(4).intersects(result.last.bounds)) {
    final last = result.last;
    final direction = endpoints.tangentTarget(atStart: false) - endpoints.end;
    final horizontal = direction.x.abs() >= direction.y.abs();
    result[result.length - 1] = (
      text: last.text,
      bounds: CanvasBounds(
        horizontal
            ? last.bounds.left
            : endpoints.end.x - last.bounds.width - 12,
        horizontal ? endpoints.end.y + 6 : last.bounds.top,
        last.bounds.width,
        last.bounds.height,
      ),
    );
  }
  return result;
}
