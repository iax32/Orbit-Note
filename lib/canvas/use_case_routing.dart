import 'dart:math' as math;
import 'dart:typed_data';

import 'connectors.dart';
import 'geometry.dart';
import 'scene.dart';

/// Independent use-case endpoints and labels; never bundle separate relationships.
bool isAutomaticUseCaseConnector(CanvasElement e) {
  final link = e.data['umlLink'];
  return isConnectorElement(e) &&
      link is Map &&
      const {
        'association',
        'include',
        'extend',
        'generalization',
        'constraint',
      }.contains(link['kind']) &&
      ConnectorRouting.parse(e.routing) == ConnectorRouting.straight &&
      ConnectorAnchor.parse(e.startAnchor) == ConnectorAnchor.auto &&
      ConnectorAnchor.parse(e.endAnchor) == ConnectorAnchor.auto;
}

typedef _Labels = List<({String text, CanvasBounds bounds})>;
typedef _Resolver = ConnectorEndpoints Function(CanvasElement, CanvasScene);
final _layouts = Expando<_Layout>();

/// Derived, sendable geometry only; no providers, timers or native resources.
/// The worker uses the same solver as exports and normal synchronous scenes.
class PreparedUseCaseRouting {
  PreparedUseCaseRouting._(this._layout);
  final _Layout? _layout;
}

PreparedUseCaseRouting prepareUseCaseRouting(Map<String, dynamic> data) {
  final scene = CanvasScene.fromJson(data);
  return PreparedUseCaseRouting._(_layouts[scene]);
}

bool hasCurrentUseCaseLayout(CanvasScene scene, {required bool canonical}) {
  final layout = _layouts[scene];
  return layout != null &&
      layout.revision == scene.revision &&
      layout.routingEpoch == scene.routingEpoch &&
      (canonical ? layout.previewBase == null : layout.previewBase != null);
}

bool installPreparedUseCaseRouting(
  CanvasScene scene,
  PreparedUseCaseRouting prepared,
) {
  final layout = prepared._layout;
  if (layout == null ||
      !_sameSignature(layout.signature, _routingSignature(scene))) {
    return false;
  }
  layout.revision = scene.revision + 1;
  layout.routingEpoch = scene.routingEpoch + 1;
  _layouts[scene] = layout;
  return true;
}

ConnectorEndpoints useCaseConnectorLayout(
  CanvasElement edge,
  CanvasScene scene,
  ConnectorEndpoints Function(CanvasElement, CanvasScene) resolveBase,
) {
  final stored = scene[edge.id];
  if (stored == null ||
      const [
        'startId',
        'endId',
        'startAnchorOffset',
        'endAnchorOffset',
        'startX',
        'startY',
        'endX',
        'endY',
        'startMultiplicity',
        'endMultiplicity',
        'startRole',
        'endRole',
      ].any((key) => stored.data[key] != edge.data[key])) {
    // Transient endpoint drags are not yet part of the committed scene layout.
    return resolveBase(edge, scene);
  }
  var layout = _layouts[scene];
  if (layout == null ||
      layout.revision != scene.revision ||
      layout.routingEpoch != scene.routingEpoch) {
    final signature = _routingSignature(scene);
    if (layout != null &&
        layout.routingEpoch == scene.routingEpoch &&
        _sameSignature(layout.signature, signature)) {
      layout.revision = scene.revision;
    } else {
      layout = _Layout(
        scene,
        resolveBase,
        signature,
        previous: scene.interactiveRouting ? layout : null,
      );
      _layouts[scene] = layout;
    }
  }
  return layout.edges[edge.id] ?? resolveBase(edge, scene);
}

// Compare exact geometry inputs, not hash-only keys: recoloring, locking,
// stacking and stored fallback endpoints on attached edges do not change paths.
List<Object?> _routingSignature(CanvasScene scene) {
  final items = scene.elements.toList()..sort((a, b) => a.id.compareTo(b.id));
  final key = <Object?>[];
  for (final e in items) {
    key.addAll([e.id, e.type, e.hidden, e.renderable]);
    if (isConnectorElement(e)) {
      final link = e.data['umlLink'];
      key.addAll([
        e.startId,
        e.endId,
        e.routing,
        e.startAnchor,
        e.endAnchor,
        _routingNumber(e.data['startAnchorOffset']),
        _routingNumber(e.data['endAnchorOffset']),
        _routingNumber(e.data['routingOffset']),
        link is Map && link['kind'] is String ? link['kind'] : null,
        link is Map ? _routingNumber(link['position']) : null,
      ]);
      if (e.startId == null || scene[e.startId!] == null) {
        final p = storedConnectorStart(e);
        key.addAll([p.x, p.y]);
      }
      if (e.endId == null || scene[e.endId!] == null) {
        final p = storedConnectorEnd(e);
        key.addAll([p.x, p.y]);
      }
      for (final field in [
        'startMultiplicity',
        'endMultiplicity',
        'startRole',
        'endRole',
      ]) {
        key.add(e.data[field] is String ? e.data[field] : null);
      }
    } else {
      key.addAll([e.x, e.y, e.width, e.height, _kind(e)]);
    }
  }
  return key;
}

bool _sameSignature(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// These renderer fields accept finite numbers only. Ignored future JSON maps
// must not make equal geometry compare by map identity across worker isolates.
num? _routingNumber(Object? value) =>
    value is num && value.isFinite ? value : null;

String? _kind(CanvasElement e) {
  final data = e.data['umlNode'];
  final kind = data is Map ? data['kind'] : null;
  return kind is String ? kind : null;
}

bool _obstacle(CanvasElement e) =>
    e.renderable &&
    !e.hidden &&
    !isConnectorElement(e) &&
    e.type != 'frame' &&
    !const {'system', 'fragment', 'lifeline', 'activation'}.contains(_kind(e));

List<CanvasPoint> _points(ConnectorEndpoints e) => [
  e.start,
  ...e.controlPoints,
  e.end,
];

ConnectorEndpoints _polyline(
  List<CanvasPoint> points,
  ConnectorEndpoints base, {
  _Labels? labels,
}) => ConnectorEndpoints(
  start: points.first,
  end: points.last,
  controlPoints: points.sublist(1, points.length - 1),
  resolvedStartAnchor: base.resolvedStartAnchor,
  resolvedEndAnchor: base.resolvedEndAnchor,
  isPolyline: true,
  endLabels: labels,
);

class _Layout {
  _Layout(
    CanvasScene scene,
    _Resolver resolveBase,
    this.signature, {
    _Layout? previous,
  }) : revision = scene.revision,
       routingEpoch = scene.routingEpoch,
       source = {for (final e in scene.elements) e.id: e} {
    final degrees = <String, int>{};
    for (final e in scene.elements.where(
      (e) => !e.hidden && e.renderable && isAutomaticUseCaseConnector(e),
    )) {
      for (final id in [e.startId, e.endId]) {
        if (id != null) degrees[id] = (degrees[id] ?? 0) + 1;
      }
    }
    final links =
        scene.elements
            .where(
              (e) =>
                  !e.hidden && e.renderable && isAutomaticUseCaseConnector(e),
            )
            .toList()
          ..sort((a, b) {
            final a1 = scene[a.startId ?? ''], a2 = scene[a.endId ?? ''];
            final b1 = scene[b.startId ?? ''], b2 = scene[b.endId ?? ''];
            bool actorLink(
              CanvasElement e,
              CanvasElement? x,
              CanvasElement? y,
            ) =>
                (e.data['umlLink'] as Map?)?['kind'] == 'association' &&
                (x != null &&
                        _kind(x) == 'actor' &&
                        (degrees[x.id] ?? 0) >= 7 ||
                    y != null &&
                        _kind(y) == 'actor' &&
                        (degrees[y.id] ?? 0) >= 7);
            final aa = actorLink(a, a1, a2), bb = actorLink(b, b1, b2);
            if (aa != bb) return aa ? -1 : 1;
            final da = (a1 != null && a2 != null)
                ? (a2.bounds.center - a1.bounds.center).length
                : 0.0;
            final db = (b1 != null && b2 != null)
                ? (b2.bounds.center - b1.bounds.center).length
                : 0.0;
            final cmp = da.compareTo(db);
            return cmp != 0 ? cmp : a.id.compareTo(b.id);
          });
    final nodes = scene.elements.where(_obstacle).toList();
    final routes = <({String id, List<CanvasPoint> points})>[];
    // Respect explicit/manual lines as existing traffic, without rerouting them.
    for (final e in scene.elements.where(
      (e) =>
          e.renderable &&
          !e.hidden &&
          isConnectorElement(e) &&
          !isAutomaticUseCaseConnector(e),
    )) {
      routes.add((id: e.id, points: _points(resolveBase(e, scene))));
    }
    final manualRoutes = List<({String id, List<CanvasPoint> points})>.of(
      routes,
    );
    if (previous != null && manualRoutes.isEmpty) {
      final base = previous.previewBase ?? previous;
      final reused = _previewPaths(scene, links, nodes, base);
      if (reused != null) {
        edges.addAll(reused);
        previewBase = base;
        _placeLabels(links, nodes, manualRoutes, previous: previous);
        return;
      }
    }
    var pending = List<CanvasElement>.of(links);
    final reserved = <({String id, List<CanvasPoint> points})>[];
    final nodeMargins = _margins(nodes);
    for (final edge in links) {
      for (final (id, otherId) in [
        (edge.startId, edge.endId),
        (edge.endId, edge.startId),
      ]) {
        final actor = scene[id ?? ''], other = scene[otherId ?? ''];
        if (actor == null || other == null || _kind(actor) != 'actor') continue;
        if (links
                .where((e) => e.startId == actor.id || e.endId == actor.id)
                .length <
            7) {
          continue;
        }
        final port = _port(
          actor,
          other,
          edge,
          links,
          scene,
          _sides(actor, other).first,
        );
        if (!nodes.any(
          (n) =>
              n.id != actor.id &&
              _blocked(
                port.tip,
                port.exit,
                n.bounds.inflate(math.min(4, nodeMargins[n.id]!)),
              ),
        )) {
          reserved.add((id: edge.id, points: [port.tip, port.exit]));
        }
      }
    }
    var best = <String, ConnectorEndpoints>{};
    var bestCount = -1;
    // Hard separation, not a crossing penalty: previously routed lines reserve
    // their own corridor. Retry blocked links first instead of merging lanes.
    for (var pass = 0; pass < 6; pass++) {
      final attempt = <String, ConnectorEndpoints>{};
      routes
        ..clear()
        ..addAll(manualRoutes)
        ..addAll(reserved);
      final failed = <CanvasElement>[];
      for (final edge in pending) {
        final a = scene[edge.startId ?? ''], b = scene[edge.endId ?? ''];
        final base = resolveBase(edge, scene);
        if (a == null || b == null || a.hidden || b.hidden) {
          attempt[edge.id] = base;
          continue;
        }
        final chosen = _readableRoute(edge, a, b, links, nodes, scene, routes);
        if (chosen == null) {
          failed.add(edge);
          attempt[edge.id] = ConnectorEndpoints(
            start: base.start,
            end: base.end,
            isPolyline: true,
            routeBlocked: true,
          );
        } else {
          attempt[edge.id] = _polyline(chosen, base);
          routes.add((id: edge.id, points: chosen));
        }
      }
      final count = pending.length - failed.length;
      if (count > bestCount) {
        best = attempt;
        bestCount = count;
      }
      if (failed.isEmpty) break;
      final failedIds = failed.map((e) => e.id).toSet();
      pending = [
        ...failed,
        ...pending.where((e) => !failedIds.contains(e.id)).toList().reversed,
      ];
    }
    edges.addAll(best);
    // Never bypass separation on failure. An explicit unresolved indicator is
    // safer than inventing a shared trunk or crossing a node/another relation.
    _placeLabels(links, nodes, manualRoutes);
  }

  void _placeLabels(
    List<CanvasElement> links,
    List<CanvasElement> nodes,
    List<({String id, List<CanvasPoint> points})> manualRoutes, {
    _Layout? previous,
  }) {
    final routes = <({String id, List<CanvasPoint> points})>[];
    routes
      ..clear()
      ..addAll(manualRoutes);
    for (final edge in links) {
      final endpoint = edges[edge.id]!;
      if (endpoint.routeBlocked) continue;
      routes.add((id: edge.id, points: _points(endpoint)));
    }
    final usedLabels = <CanvasBounds>[];
    final labelTraffic = _LineObstacles(routes);
    for (final edge in links) {
      final endpoint = edges[edge.id]!;
      if (!endpoint.isPolyline || endpoint.routeBlocked) continue;
      final labels = connectorEndLabels(edge, endpoint);
      final placed = <({String text, CanvasBounds bounds})>[];
      for (var i = 0; i < labels.length; i++) {
        final atStart =
            i == 0 &&
            [
              edge.data['startMultiplicity'],
              edge.data['startRole'],
            ].whereType<String>().any((s) => s.trim().isNotEmpty);
        final path = atStart
            ? _points(endpoint)
            : _points(endpoint).reversed.toList();
        final label = labels[i];
        final old = previous?.edges[edge.id];
        final oldLabels = old?.endLabels;
        final preferred =
            old?.routeBlocked == false &&
                oldLabels != null &&
                i < oldLabels.length &&
                oldLabels[i].text == label.text
            ? oldLabels[i].bounds
            : null;
        final bounds = _labelBounds(
          path,
          label.bounds,
          nodes,
          usedLabels,
          routes.where((r) => r.id != edge.id).map((r) => r.points),
          collision: labelTraffic,
          excluding: edge.id,
          preferred: preferred,
        );
        placed.add((text: label.text, bounds: bounds));
        usedLabels.add(bounds.inflate(5));
      }
      edges[edge.id] = _polyline(_points(endpoint), endpoint, labels: placed);
    }
    for (final edge in links.where((e) => edges[e.id]!.routeBlocked)) {
      final endpoint = edges[edge.id]!;
      final size = connectorRouteWarningBounds(endpoint);
      var bounds = _labelBounds(
        [endpoint.start, endpoint.end],
        size,
        nodes,
        usedLabels,
        routes.map((r) => r.points),
        collision: labelTraffic,
        excluding: edge.id,
      );
      if (nodes.any((n) => n.bounds.inflate(7).intersects(bounds)) ||
          usedLabels.any((r) => r.intersects(bounds))) {
        final right = nodes.fold(
          endpoint.start.x,
          (double x, n) => math.max(x, n.bounds.right),
        );
        bounds = CanvasBounds(
          right + 48,
          endpoint.start.y,
          size.width,
          size.height,
        );
        while (usedLabels.any((r) => r.intersects(bounds))) {
          bounds = CanvasBounds(
            bounds.left,
            bounds.top + 48,
            bounds.width,
            bounds.height,
          );
        }
      }
      usedLabels.add(bounds.inflate(5));
      edges[edge.id] = ConnectorEndpoints(
        start: endpoint.start,
        end: endpoint.end,
        isPolyline: true,
        routeBlocked: true,
        endLabels: [(text: connectorRouteWarningText, bounds: bounds)],
      );
    }
  }

  int revision;
  int routingEpoch;
  final Map<String, CanvasElement> source;
  _Layout? previewBase;
  final List<Object?> signature;
  final edges = <String, ConnectorEndpoints>{};
}

typedef _Port = ({CanvasPoint tip, CanvasPoint exit});

final _obstacleMargins = Expando<Map<String, double>>();
Map<String, double> _margins(List<CanvasElement> nodes) {
  final cached = _obstacleMargins[nodes];
  if (cached != null) return cached;
  final margins = {for (final n in nodes) n.id: 12.0};
  void inspect(CanvasElement n, CanvasElement other) {
    if (n.id == other.id) return;
    final a = n.bounds, b = other.bounds;
    double? gap;
    if (a.left <= b.right && b.left <= a.right) {
      if (a.bottom <= b.top) gap = b.top - a.bottom;
      if (b.bottom <= a.top) gap = a.top - b.bottom;
    }
    if (a.top <= b.bottom && b.top <= a.bottom) {
      if (a.right <= b.left) gap = b.left - a.right;
      if (b.right <= a.left) gap = a.left - b.right;
    }
    if (gap != null && gap > 0) {
      final padding = math.max(1.0, gap / 3);
      margins[n.id] = math.min(margins[n.id]!, padding);
      margins[other.id] = math.min(margins[other.id]!, padding);
    }
  }

  if (nodes.length <= 256) {
    for (var i = 0; i < nodes.length; i++) {
      for (var j = i + 1; j < nodes.length; j++) {
        inspect(nodes[i], nodes[j]);
      }
    }
  } else {
    final index = CanvasSpatialIndex(cellSize: 128);
    final byId = {for (final n in nodes) n.id: n};
    for (final n in nodes) {
      index.put(n.id, n.bounds);
    }
    var budget = nodes.length * 64;
    // Inspect local UML neighborhoods first. Distant decorations must neither
    // disable narrow-gutter routing nor introduce an unbounded all-pairs pass.
    for (final n in [
      ...nodes.where((n) => _kind(n) != null),
      ...nodes.where((n) => _kind(n) == null),
    ]) {
      if (budget <= 0) break;
      final near = index.query(n.bounds.inflate(36));
      budget -= index.lastCandidateCount;
      if (near.length > 256) continue;
      for (final id in near) {
        inspect(n, byId[id]!);
      }
    }
  }
  return _obstacleMargins[nodes] = margins;
}

List<CanvasPoint>? _readableRoute(
  CanvasElement edge,
  CanvasElement a,
  CanvasElement b,
  List<CanvasElement> links,
  List<CanvasElement> nodes,
  CanvasScene scene,
  List<({String id, List<CanvasPoint> points})> routes, {
  bool allowGrid = true,
}) {
  final traffic = routes.where((r) => r.id != edge.id).toList();
  final collision = _LineObstacles(traffic);
  final actors = {if (_kind(a) == 'actor') a.id, if (_kind(b) == 'actor') b.id};
  final unrelatedTraffic = _LineObstacles(
    traffic.where((r) {
      final link = scene[r.id];
      return link == null ||
          !actors.contains(link.startId) && !actors.contains(link.endId);
    }).toList(),
  );
  final margins = _margins(nodes);
  final boxes = nodes.map((n) => n.bounds.inflate(margins[n.id]!)).toList();
  bool clearPort(_Port port, String owner) =>
      !nodes.any(
        (n) =>
            n.id != owner &&
            _blocked(
              port.tip,
              port.exit,
              n.bounds.inflate(math.min(4, margins[n.id]!)),
            ),
      ) &&
      // Stems in one actor fan may be close, but never share/cross a segment.
      // Unrelated traffic keeps its own clearance, including at the attachment.
      !collision.near(port.tip, port.exit, .01) &&
      !unrelatedTraffic.near(port.tip, port.exit, 2);
  final pairs = <({_Port from, _Port to, double lower, double penalty})>[];
  List<CanvasPoint>? best;
  var bestScore = double.infinity;
  bool faces(
    CanvasElement node,
    ConnectorAnchor side,
    CanvasPoint tip,
    CanvasPoint direction,
  ) {
    if (node.type == 'ellipse') {
      final normal = CanvasPoint(
        (tip.x - node.bounds.center.x) / math.max(1, node.width * node.width),
        (tip.y - node.bounds.center.y) / math.max(1, node.height * node.height),
      );
      return normal.x * direction.x + normal.y * direction.y > .00001;
    }
    return switch (side) {
      ConnectorAnchor.left => direction.x < 0,
      ConnectorAnchor.right => direction.x > 0,
      ConnectorAnchor.top => direction.y < 0,
      _ => direction.y > 0,
    };
  }

  final directAssociation =
      (_highFan(a, links) || _highFan(b, links)) &&
      (edge.data['umlLink'] as Map?)?['kind'] == 'association';
  final laneClearance = directAssociation && links.length > 6 ? 2.0 : 7.0;
  final starts = _sides(a, b), ends = _sides(b, a);
  for (var i = 0; i < starts.length; i++) {
    final from = _port(a, b, edge, links, scene, starts[i]);
    final fromClear = clearPort(from, a.id);
    for (var j = 0; j < ends.length; j++) {
      final to = _port(b, a, edge, links, scene, ends[j]);
      final penalty = (i + j) * 18.0;
      // A clear association does not need two inflated escape boxes between
      // closely spaced endpoints. Convex perimeter normals prevent re-entering
      // either case; every other node and existing line remains an exclusion.
      final delta = to.tip - from.tip;
      if (directAssociation &&
          faces(a, starts[i], from.tip, delta) &&
          faces(b, ends[j], to.tip, delta * -1) &&
          !nodes.any(
            (n) =>
                n.id != a.id &&
                n.id != b.id &&
                _blocked(from.tip, to.tip, n.bounds.inflate(4)),
          ) &&
          !collision.near(from.tip, to.tip, .01) &&
          !unrelatedTraffic.near(from.tip, to.tip, 2)) {
        final score = delta.length + penalty;
        if (score < bestScore) {
          best = [from.tip, to.tip];
          bestScore = score;
        }
      }
      if (!fromClear || !clearPort(to, b.id)) continue;
      pairs.add((
        from: from,
        to: to,
        penalty: penalty,
        lower:
            (from.exit.x - to.exit.x).abs() +
            (from.exit.y - to.exit.y).abs() +
            (from.tip - from.exit).length +
            (to.tip - to.exit).length +
            penalty,
      ));
    }
  }
  pairs.sort((a, b) => a.lower.compareTo(b.lower));
  void consider(
    _Port from,
    _Port to,
    List<CanvasPoint> middle,
    double penalty,
  ) {
    for (var i = 1; i < middle.length; i++) {
      if (boxes.any((r) => _blocked(middle[i - 1], middle[i], r)) ||
          collision.near(middle[i - 1], middle[i], laneClearance)) {
        return;
      }
    }
    final path = _simplify([from.tip, ...middle, to.tip]);
    if (_selfCrosses(path)) return;
    var score = penalty + math.max(0, path.length - 2) * 32;
    for (var i = 1; i < path.length; i++) {
      score += (path[i] - path[i - 1]).length;
      if (i > 1) {
        final u = path[i - 1] - path[i - 2], v = path[i] - path[i - 1];
        if ((u.x * v.y - u.y * v.x).abs() < .001 && u.x * v.x + u.y * v.y < 0) {
          return;
        }
      }
    }
    if (score < bestScore - .001) {
      best = path;
      bestScore = score;
    }
  }

  // Score inexpensive, legible candidates on all sides before any grid search.
  // A reachable back-side port must not win over a short front-side connection.
  for (final p in pairs) {
    final s = p.from.exit, t = p.to.exit;
    if ((s.x - t.x).abs() < .001 || (s.y - t.y).abs() < .001) {
      consider(p.from, p.to, [s, t], p.penalty);
    }
    for (final bend in [CanvasPoint(s.x, t.y), CanvasPoint(t.x, s.y)]) {
      consider(p.from, p.to, [s, bend, t], p.penalty);
    }
    final x = (s.x + t.x) / 2, y = (s.y + t.y) / 2;
    consider(p.from, p.to, [
      s,
      CanvasPoint(x, s.y),
      CanvasPoint(x, t.y),
      t,
    ], p.penalty);
    consider(p.from, p.to, [
      s,
      CanvasPoint(s.x, y),
      CanvasPoint(t.x, y),
      t,
    ], p.penalty);
  }
  // Keep work bounded: stop at a near-direct simple route; otherwise compare
  // grid alternatives only while their length lower bound can improve it.
  if (!allowGrid ||
      pairs.isEmpty ||
      best != null && bestScore <= pairs.first.lower + 96) {
    return best;
  }
  var searched = 0;
  for (final p in pairs) {
    if (p.lower >= bestScore) continue;
    if (best != null && searched >= 4) break;
    searched++;
    final middle = _separateRoute(
      p.from.exit,
      p.to.exit,
      boxes,
      traffic,
      collision: collision,
      clearance: laneClearance,
    );
    if (middle != null) consider(p.from, p.to, middle, p.penalty);
  }
  return best;
}

Map<String, ConnectorEndpoints>? _previewPaths(
  CanvasScene scene,
  List<CanvasElement> links,
  List<CanvasElement> nodes,
  _Layout before,
) {
  if (scene.length != before.source.length) return null;
  final changed = <String>{};
  for (final node in nodes) {
    final old = before.source[node.id];
    if (old == null ||
        old.type != node.type ||
        old.hidden != node.hidden ||
        _kind(old) != _kind(node)) {
      return null;
    }
    if (old.x != node.x ||
        old.y != node.y ||
        old.width != node.width ||
        old.height != node.height) {
      changed.add(node.id);
    }
  }
  final result = <String, ConnectorEndpoints>{};
  List<CanvasPoint> patchStart(
    List<CanvasPoint> points,
    CanvasElement node,
    CanvasElement old,
    CanvasElement other,
    CanvasElement edge,
  ) {
    if (points.length < 2) return points;
    final delta = points[1] - points[0];
    final relative = points.first - old.bounds.center;
    final horizontal =
        relative.x.abs() / math.max(1, old.width) >=
        relative.y.abs() / math.max(1, old.height);
    final side = _kind(node) == 'actor'
        ? (delta.x >= 0 ? ConnectorAnchor.right : ConnectorAnchor.left)
        : horizontal
        ? (relative.x >= 0 ? ConnectorAnchor.right : ConnectorAnchor.left)
        : (relative.y >= 0 ? ConnectorAnchor.bottom : ConnectorAnchor.top);
    final port = _port(node, other, edge, links, scene, side);
    if (points.length == 2) return [port.tip, points.last];
    var tail = points.skip(1).toList();
    final oldBox = old.bounds.inflate(24), first = tail.first;
    final isOldPort = switch (side) {
      ConnectorAnchor.left => (first.x - oldBox.left).abs() < .01,
      ConnectorAnchor.right => (first.x - oldBox.right).abs() < .01,
      ConnectorAnchor.top => (first.y - oldBox.top).abs() < .01,
      _ => (first.y - oldBox.bottom).abs() < .01,
    };
    if (isOldPort && tail.length > 1) {
      final oldPort = tail[0], next = tail[1];
      tail = tail.skip(1).toList();
      if ((next.y - oldPort.y).abs() < .001) {
        tail[0] = CanvasPoint(next.x, port.exit.y);
      } else if ((next.x - oldPort.x).abs() < .001) {
        tail[0] = CanvasPoint(port.exit.x, next.y);
      }
    }
    final target = tail.first;
    final bridge = side == ConnectorAnchor.left || side == ConnectorAnchor.right
        ? CanvasPoint(target.x, port.exit.y)
        : CanvasPoint(port.exit.x, target.y);
    if (tail.length > 1) {
      final next = tail[1];
      final first = tail[0];
      if ((bridge.x - first.x).abs() < .001 &&
              (first.x - next.x).abs() < .001 &&
              bridge.y >= math.min(first.y, next.y) &&
              bridge.y <= math.max(first.y, next.y) ||
          (bridge.y - first.y).abs() < .001 &&
              (first.y - next.y).abs() < .001 &&
              bridge.x >= math.min(first.x, next.x) &&
              bridge.x <= math.max(first.x, next.x)) {
        tail = tail.skip(1).toList();
      }
    }
    return _simplify([port.tip, port.exit, bridge, ...tail]);
  }

  for (final edge in links) {
    final old = before.source[edge.id], cached = before.edges[edge.id];
    if (old == null || cached == null) return null;
    for (final field in [
      'startId',
      'endId',
      'routing',
      'startAnchor',
      'endAnchor',
      'startAnchorOffset',
      'endAnchorOffset',
    ]) {
      if (field == 'startAnchorOffset' || field == 'endAnchorOffset') {
        if (_routingNumber(old.data[field]) !=
            _routingNumber(edge.data[field])) {
          return null;
        }
      } else if (old.data[field] != edge.data[field]) {
        return null;
      }
    }
    var points = _points(cached);
    final a = scene[edge.startId ?? ''], b = scene[edge.endId ?? ''];
    if (a == null || b == null) return null;
    if (cached.routeBlocked) {
      final oldA = before.source[a.id]!, oldB = before.source[b.id]!;
      result[edge.id] = ConnectorEndpoints(
        start: cached.start + CanvasPoint(a.x - oldA.x, a.y - oldA.y),
        end: cached.end + CanvasPoint(b.x - oldB.x, b.y - oldB.y),
        isPolyline: true,
        routeBlocked: true,
      );
      continue;
    }
    if (changed.contains(a.id)) {
      points = patchStart(points, a, before.source[a.id]!, b, edge);
    }
    if (changed.contains(b.id)) {
      points = patchStart(
        points.reversed.toList(),
        b,
        before.source[b.id]!,
        a,
        edge,
      ).reversed.toList();
    }
    result[edge.id] = _polyline(points, cached);
  }
  bool invalid(CanvasElement edge, List<CanvasPoint> points) {
    if (_selfCrosses(points, clearance: .001)) return true;
    for (final (id, tip, toward) in [
      (edge.startId, points.first, points[1]),
      (edge.endId, points.last, points[points.length - 2]),
    ]) {
      final node = scene[id ?? ''];
      if (node == null || node.type != 'ellipse') continue;
      final d = toward - tip, relative = tip - node.bounds.center;
      if (relative.x * d.x / math.max(1, node.width * node.width) +
              relative.y * d.y / math.max(1, node.height * node.height) <
          -.00001) {
        return true;
      }
    }
    for (var i = 1; i < points.length; i++) {
      for (final node in nodes) {
        if (i == 1 && node.id == edge.startId ||
            i == points.length - 1 && node.id == edge.endId) {
          continue;
        }
        if (_blocked(points[i - 1], points[i], node.bounds.inflate(2))) {
          return true;
        }
      }
    }
    return false;
  }

  final visible = links.where((e) => !result[e.id]!.routeBlocked).toList();
  final paths = {
    for (final edge in visible) edge.id: _points(result[edge.id]!),
  };
  final repair = <String>{};
  for (final edge in visible) {
    if (invalid(edge, paths[edge.id]!)) repair.add(edge.id);
  }
  bool meets(List<CanvasPoint> a, List<CanvasPoint> b, double gap) {
    for (var i = 1; i < a.length; i++) {
      for (var j = 1; j < b.length; j++) {
        if (_segmentsNear(a[i - 1], a[i], b[j - 1], b[j], gap)) return true;
      }
    }
    return false;
  }

  for (var i = 0; i < visible.length; i++) {
    for (var j = i + 1; j < visible.length; j++) {
      final a = visible[i].id, b = visible[j].id;
      final first = visible[i], second = visible[j];
      final sharedActor = [first.startId, first.endId].any(
        (id) =>
            id != null &&
            (id == second.startId || id == second.endId) &&
            scene[id] != null &&
            _kind(scene[id]!) == 'actor',
      );
      if (!repair.contains(a) &&
          !repair.contains(b) &&
          meets(paths[a]!, paths[b]!, sharedActor ? .01 : .8)) {
        repair.add(b);
      }
    }
  }
  final traffic = <({String id, List<CanvasPoint> points})>[
    for (final edge in visible.where((e) => !repair.contains(e.id)))
      (id: edge.id, points: paths[edge.id]!),
  ];
  for (final edge in visible.where((e) => repair.contains(e.id))) {
    final a = scene[edge.startId!]!, b = scene[edge.endId!]!;
    // Repair only invalid continuations during input, without another complete
    // graph search on every pointer sample. If no safe simple path exists, keep
    // the explicit pending indicator until canonical worker routing on release.
    final points = _readableRoute(
      edge,
      a,
      b,
      links,
      nodes,
      scene,
      traffic,
      allowGrid: false,
    );
    final cached = result[edge.id]!;
    if (points == null) {
      result[edge.id] = ConnectorEndpoints(
        start: cached.start,
        end: cached.end,
        isPolyline: true,
        routeBlocked: true,
      );
    } else {
      result[edge.id] = _polyline(points, cached);
      traffic.add((id: edge.id, points: points));
    }
  }
  return result;
}

final _portTables = Expando<Map<(String, String, ConnectorAnchor), _Port>>();
bool _highFan(CanvasElement node, List<CanvasElement> links) =>
    _kind(node) == 'actor' &&
    links
            .where((e) => e.startId == node.id || e.endId == node.id)
            .take(7)
            .length >=
        7;
final _peerTables =
    Expando<Map<(String, ConnectorAnchor, String), List<CanvasElement>>>();
final _actorTipTables = Expando<Map<String, Map<String, double>>>();
Map<String, double> _actorTips(
  CanvasElement node,
  List<CanvasElement> links,
  CanvasScene scene,
) {
  final actors = _actorTipTables[links] ??= {};
  return actors.putIfAbsent(node.id, () {
    final all =
        links
            .where(
              (e) =>
                  (e.startId == node.id || e.endId == node.id) &&
                  scene[(e.startId == node.id ? e.endId : e.startId) ?? ''] !=
                      null,
            )
            .toList()
          ..sort((a, b) {
            CanvasPoint target(CanvasElement e) =>
                scene[(e.startId == node.id ? e.endId : e.startId)!]!
                    .bounds
                    .center;
            final cmp = target(a).y.compareTo(target(b).y);
            return cmp != 0 ? cmp : a.id.compareTo(b.id);
          });
    final figure = math.min(94.0, node.height * .62);
    return {
      for (var i = 0; i < all.length; i++)
        all[i].id:
            node.y +
            figure * (.2 + (all.length < 2 ? .5 : i / (all.length - 1)) * .6),
    };
  });
}

_Port _port(
  CanvasElement node,
  CanvasElement other,
  CanvasElement edge,
  List<CanvasElement> links,
  CanvasScene scene,
  ConnectorAnchor anchor,
) {
  // Each layout owns a fresh immutable link list. Reuse its exact allocation
  // across side candidates, ordering retries and reserved fan stems.
  final table = _portTables[links] ??= {};
  return table.putIfAbsent((
    node.id,
    edge.id,
    anchor,
  ), () => _allocatePort(node, other, edge, links, scene, anchor));
}

_Port _allocatePort(
  CanvasElement node,
  CanvasElement other,
  CanvasElement edge,
  List<CanvasElement> links,
  CanvasScene scene,
  ConnectorAnchor anchor,
) {
  final horizontal =
      anchor == ConnectorAnchor.left || anchor == ConnectorAnchor.right;
  final fan = _highFan(node, links);
  final alternate =
      fan &&
      horizontal &&
      (other.bounds.center.x >= node.bounds.center.x) !=
          (anchor == ConnectorAnchor.right);
  final peers = (_peerTables[links] ??= {}).putIfAbsent(
    (node.id, anchor, alternate ? edge.id : ''),
    () =>
        links.where((e) {
          final target = e.startId == node.id
              ? scene[e.endId ?? '']
              : e.endId == node.id
              ? scene[e.startId ?? '']
              : null;
          if (target == null) return false;
          if (fan && horizontal && e.id != edge.id) {
            final right = target.bounds.center.x >= node.bounds.center.x;
            if (right != (anchor == ConnectorAnchor.right)) return false;
          }
          return true;
        }).toList()..sort((a, b) {
          CanvasElement opposite(CanvasElement e) =>
              scene[(e.startId == node.id ? e.endId : e.startId)!]!;
          final pa = opposite(a).bounds.center, pb = opposite(b).bounds.center;
          final order = horizontal
              ? pa.y.compareTo(pb.y)
              : pa.x.compareTo(pb.x);
          return order != 0 ? order : a.id.compareTo(b.id);
        }),
  );
  final rank = math.max(0, peers.indexWhere((e) => e.id == edge.id));
  final fraction = peers.length < 2 ? .5 : .25 + .5 * rank / (peers.length - 1);
  var tip = getElementAnchors(node.bounds)[anchor]!;
  if (_kind(node) == 'actor') {
    tip = CanvasPoint(
      node.bounds.center.x,
      fan
          ? _actorTips(node, links, scene)[edge.id] ?? node.bounds.center.y
          : node.y + math.min(94.0, node.height * .62) * (.30 + fraction * .36),
    );
  } else if (horizontal) {
    final dy = node.height * (fraction - .5);
    final dx = node.type == 'ellipse'
        ? node.width /
              2 *
              math.sqrt(
                math.max(0, 1 - math.pow(dy / math.max(1, node.height / 2), 2)),
              )
        : node.width / 2;
    tip = CanvasPoint(
      node.bounds.center.x + (anchor == ConnectorAnchor.left ? -dx : dx),
      node.bounds.center.y + dy,
    );
  } else {
    final dx = node.width * (fraction - .5);
    final dy = node.type == 'ellipse'
        ? node.height /
              2 *
              math.sqrt(
                math.max(0, 1 - math.pow(dx / math.max(1, node.width / 2), 2)),
              )
        : node.height / 2;
    tip = CanvasPoint(
      node.bounds.center.x + dx,
      node.bounds.center.y + (anchor == ConnectorAnchor.top ? -dy : dy),
    );
  }
  final box = node.bounds.inflate(24);
  var exit = switch (anchor) {
    ConnectorAnchor.left => CanvasPoint(box.left, tip.y),
    ConnectorAnchor.right => CanvasPoint(box.right, tip.y),
    ConnectorAnchor.top => CanvasPoint(tip.x, box.top),
    _ => CanvasPoint(tip.x, box.bottom),
  };
  if (_kind(node) == 'actor') {
    double? last;
    var projected = tip.y;
    for (var i = 0; i <= rank; i++) {
      final peer = peers[i];
      final target =
          scene[(peer.startId == node.id ? peer.endId : peer.startId)!]!;
      final nearX = anchor == ConnectorAnchor.right
          ? target.bounds.left
          : target.bounds.right;
      final dx = nearX - tip.x;
      final peerY = _actorTips(node, links, scene)[peer.id] ?? tip.y;
      var ideal = dx.abs() < 24
          ? node.y + (i - (peers.length - 1) / 2) * 16
          : peerY + (target.bounds.center.y - peerY) * (exit.x - tip.x) / dx;
      ideal = ideal.clamp(
        tip.y - math.max(160, peers.length * 32),
        tip.y + math.max(160, peers.length * 32),
      );
      projected = last == null ? ideal : math.max(ideal, last + 12);
      last = projected;
    }
    exit = CanvasPoint(
      exit.x,
      fan
          ? projected
          : node.y +
                math.min(94.0, node.height * .62) * .48 +
                (rank - (peers.length - 1) / 2) * 32,
    );
  } else if (peers.length > 4) {
    final offset = (rank - (peers.length - 1) / 2) * 12;
    exit = horizontal
        ? CanvasPoint(exit.x, node.bounds.center.y + offset)
        : CanvasPoint(node.bounds.center.x + offset, exit.y);
  }
  return (tip: tip, exit: exit);
}

bool _blocked(CanvasPoint a, CanvasPoint b, CanvasBounds r) {
  // Rectilinear edges may run on a clearance boundary, never through its interior.
  const epsilon = .001;
  if ((a.y - b.y).abs() < epsilon) {
    return a.y > r.top + epsilon &&
        a.y < r.bottom - epsilon &&
        math.max(a.x, b.x) > r.left + epsilon &&
        math.min(a.x, b.x) < r.right - epsilon;
  }
  if ((a.x - b.x).abs() < epsilon) {
    return a.x > r.left + epsilon &&
        a.x < r.right - epsilon &&
        math.max(a.y, b.y) > r.top + epsilon &&
        math.min(a.y, b.y) < r.bottom - epsilon;
  }
  // Label collision with manual diagonal lines.
  if (r.contains(a) || r.contains(b)) return true;
  return _cross(
        a,
        b,
        CanvasPoint(r.left, r.top),
        CanvasPoint(r.right, r.top),
      ) ||
      _cross(
        a,
        b,
        CanvasPoint(r.right, r.top),
        CanvasPoint(r.right, r.bottom),
      ) ||
      _cross(
        a,
        b,
        CanvasPoint(r.right, r.bottom),
        CanvasPoint(r.left, r.bottom),
      ) ||
      _cross(a, b, CanvasPoint(r.left, r.bottom), CanvasPoint(r.left, r.top));
}

bool _cross(CanvasPoint a, CanvasPoint b, CanvasPoint c, CanvasPoint d) {
  double orient(CanvasPoint p, CanvasPoint q, CanvasPoint r) =>
      (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x);
  return orient(a, b, c) * orient(a, b, d) < -.001 &&
      orient(c, d, a) * orient(c, d, b) < -.001;
}

CanvasBounds _labelBounds(
  List<CanvasPoint> path,
  CanvasBounds size,
  List<CanvasElement> nodes,
  List<CanvasBounds> used,
  Iterable<List<CanvasPoint>> otherRoutes, {
  _LineObstacles? collision,
  String? excluding,
  CanvasBounds? preferred,
}) {
  var travelled = 0.0;
  final traffic = otherRoutes.toList();
  const searchLimit = 8192.0;
  if (preferred != null) {
    CanvasPoint? closest;
    var distance = double.infinity;
    for (var i = 1; i < path.length; i++) {
      final a = path[i - 1], delta = path[i] - a, offset = preferred.center - a;
      final squared = delta.x * delta.x + delta.y * delta.y;
      final t = squared < .00001
          ? 0.0
          : ((offset.x * delta.x + offset.y * delta.y) / squared).clamp(
              0.0,
              1.0,
            );
      final p = a + delta * t, score = (p - preferred.center).length;
      if (score < distance) {
        distance = score;
        closest = p;
      }
    }
    if (closest != null) {
      final box = CanvasBounds(
        closest.x - size.width / 2,
        closest.y - size.height / 2,
        size.width,
        size.height,
      );
      if (!nodes.any((n) => n.bounds.inflate(7).intersects(box)) &&
          !used.any((r) => r.intersects(box)) &&
          collision != null &&
          !collision.intersectsBox(box.inflate(1.5), excluding: excluding)) {
        return box;
      }
    }
  }
  final length = List.generate(
    path.length - 1,
    (i) => (path[i + 1] - path[i]).length,
  ).fold(0.0, (a, b) => a + b);
  for (var i = 1; i < path.length; i++) {
    final a = path[i - 1], delta = path[i] - a;
    final segment = delta.length;
    if (segment < .001) continue;
    for (
      var step = 18.0;
      step <= math.min(segment, searchLimit);
      step += step < 420 ? 12 : 36
    ) {
      final distance = travelled + step;
      if (distance > length + .001) break;
      final p = a + delta * (step / segment);
      final box = CanvasBounds(
        p.x - size.width / 2,
        p.y - size.height / 2,
        size.width,
        size.height,
      );
      if (nodes.any((n) => n.bounds.inflate(7).intersects(box)) ||
          used.any((r) => r.intersects(box))) {
        continue;
      }
      bool intersectsTraffic() {
        final clearance = box.inflate(1.5);
        if (collision != null) {
          return collision.intersectsBox(clearance, excluding: excluding);
        }
        for (final route in traffic) {
          for (var i = 1; i < route.length; i++) {
            if (_blocked(route[i - 1], route[i], clearance)) return true;
          }
        }
        return false;
      }

      if (intersectsTraffic()) {
        continue;
      }
      // Candidates are visited in increasing path distance: the first valid
      // box is already optimal. Do not scan the rest of every long fan branch.
      return box;
    }
    travelled += segment;
  }
  return size;
}

List<ConnectorAnchor> _sides(CanvasElement node, CanvasElement other) {
  final d = other.bounds.center - node.bounds.center;
  final horizontal = d.x >= 0 ? ConnectorAnchor.right : ConnectorAnchor.left;
  final vertical = d.y >= 0 ? ConnectorAnchor.bottom : ConnectorAnchor.top;
  if (_kind(node) == 'actor') {
    return [
      horizontal,
      horizontal == ConnectorAnchor.left
          ? ConnectorAnchor.right
          : ConnectorAnchor.left,
    ];
  }
  final first = d.x.abs() >= d.y.abs() ? horizontal : vertical;
  return [
    first,
    ...[
      ConnectorAnchor.left,
      ConnectorAnchor.right,
      ConnectorAnchor.top,
      ConnectorAnchor.bottom,
    ].where((v) => v != first),
  ];
}

class _LineObstacles {
  _LineObstacles(List<({String id, List<CanvasPoint> points})> routes) {
    for (final route in routes) {
      for (var i = 1; i < route.points.length; i++) {
        final a = route.points[i - 1], b = route.points[i];
        final index = _segments.length;
        _segments.add((a: a, b: b, id: route.id));
        final minX = (math.min(a.x, b.x) / 96).floor(),
            maxX = (math.max(a.x, b.x) / 96).floor();
        final minY = (math.min(a.y, b.y) / 96).floor(),
            maxY = (math.max(a.y, b.y) / 96).floor();
        final span = maxX - minX + maxY - minY + 3;
        if (span > 512) {
          _large.add(index);
          continue;
        }
        // Supercover traversal: index cells touched by the segment, not every
        // cell in a large diagonal bounding rectangle. Include both corner
        // neighbors so exact touch/crossing checks cannot fall through a gap.
        void add(int x, int y) => ((_cells[x] ??= {})[y] ??= []).add(index);
        var x = (a.x / 96).floor(), y = (a.y / 96).floor();
        final endX = (b.x / 96).floor(), endY = (b.y / 96).floor();
        final dx = b.x - a.x,
            dy = b.y - a.y,
            sx = dx >= 0 ? 1 : -1,
            sy = dy >= 0 ? 1 : -1;
        final stepX = dx == 0 ? double.infinity : 96 / dx.abs();
        final stepY = dy == 0 ? double.infinity : 96 / dy.abs();
        var tx = dx == 0
            ? double.infinity
            : ((sx > 0 ? x + 1 : x) * 96 - a.x) / dx;
        var ty = dy == 0
            ? double.infinity
            : ((sy > 0 ? y + 1 : y) * 96 - a.y) / dy;
        for (var cell = 0; cell < span; cell++) {
          add(x, y);
          if (x == endX && y == endY) break;
          if ((tx - ty).abs() < 1e-12) {
            add(x + sx, y);
            add(x, y + sy);
            x += sx;
            y += sy;
            tx += stepX;
            ty += stepY;
          } else if (tx < ty) {
            x += sx;
            tx += stepX;
          } else {
            y += sy;
            ty += stepY;
          }
        }
      }
    }
    _seen = List<int>.filled(_segments.length, 0);
  }
  final _segments = <({CanvasPoint a, CanvasPoint b, String id})>[];
  final _cells = <int, Map<int, List<int>>>{};
  final _large = <int>[];
  late final List<int> _seen;
  var _generation = 0;
  bool intersectsBox(CanvasBounds box, {String? excluding}) {
    final stamp = ++_generation;
    bool check(int index) {
      if (_seen[index] == stamp) return false;
      _seen[index] = stamp;
      final segment = _segments[index];
      return segment.id != excluding && _blocked(segment.a, segment.b, box);
    }

    for (final i in _large) {
      if (check(i)) return true;
    }
    final x0 = (box.left / 96).floor(), x1 = (box.right / 96).floor();
    final y0 = (box.top / 96).floor(), y1 = (box.bottom / 96).floor();
    if ((x1 - x0 + 1) * (y1 - y0 + 1) > 512) {
      for (var i = 0; i < _segments.length; i++) {
        if (check(i)) return true;
      }
      return false;
    }
    for (var x = x0; x <= x1; x++) {
      final column = _cells[x];
      if (column == null) continue;
      for (var y = y0; y <= y1; y++) {
        for (final i in column[y] ?? const <int>[]) {
          if (check(i)) return true;
        }
      }
    }
    return false;
  }

  bool near(CanvasPoint a, CanvasPoint b, double gap) {
    if (_segments.isEmpty) return false;
    final stamp = ++_generation;
    bool check(int index) {
      if (_seen[index] == stamp) return false;
      _seen[index] = stamp;
      final s = _segments[index];
      return _segmentsNear(a, b, s.a, s.b, gap);
    }

    for (final index in _large) {
      if (check(index)) return true;
    }
    final minX = ((math.min(a.x, b.x) - gap) / 96).floor(),
        maxX = ((math.max(a.x, b.x) + gap) / 96).floor();
    final minY = ((math.min(a.y, b.y) - gap) / 96).floor(),
        maxY = ((math.max(a.y, b.y) + gap) / 96).floor();
    if ((maxX - minX + 1) * (maxY - minY + 1) > 512) {
      for (var i = 0; i < _segments.length; i++) {
        if (check(i)) return true;
      }
      return false;
    }
    for (var x = minX; x <= maxX; x++) {
      final column = _cells[x];
      if (column == null) continue;
      for (var y = minY; y <= maxY; y++) {
        for (final index in column[y] ?? const <int>[]) {
          if (check(index)) return true;
        }
      }
    }
    return false;
  }
}

bool _segmentsNear(
  CanvasPoint a,
  CanvasPoint b,
  CanvasPoint c,
  CanvasPoint d,
  double gap,
) {
  if (math.max(a.x, b.x) + gap < math.min(c.x, d.x) ||
      math.max(c.x, d.x) + gap < math.min(a.x, b.x) ||
      math.max(a.y, b.y) + gap < math.min(c.y, d.y) ||
      math.max(c.y, d.y) + gap < math.min(a.y, b.y)) {
    return false;
  }
  if (_cross(a, b, c, d)) return true;
  return distanceToSegment(a, c, d) < gap ||
      distanceToSegment(b, c, d) < gap ||
      distanceToSegment(c, a, b) < gap ||
      distanceToSegment(d, a, b) < gap;
}

bool _selfCrosses(List<CanvasPoint> points, {double clearance = .5}) {
  for (var i = 1; i < points.length; i++) {
    for (var j = i + 2; j < points.length; j++) {
      if (_segmentsNear(
        points[i - 1],
        points[i],
        points[j - 1],
        points[j],
        clearance,
      )) {
        return true;
      }
    }
  }
  return false;
}

List<CanvasPoint>? _separateRoute(
  CanvasPoint start,
  CanvasPoint end,
  List<CanvasBounds> obstacles,
  List<({String id, List<CanvasPoint> points})> routes, {
  _LineObstacles? collision,
  double clearance = 7,
}) {
  collision ??= _LineObstacles(routes);
  // Every legal grid edge includes its endpoints. If either endpoint is
  // already inside a forbidden corridor, exploring the grid cannot reach it.
  // In crowded diagrams these impossible side candidates dominated full layout.
  if (obstacles.any(
        (r) => _blocked(start, start, r) || _blocked(end, end, r),
      ) ||
      collision.near(start, start, clearance) ||
      collision.near(end, end, clearance)) {
    return null;
  }
  var envelope = CanvasBounds.between(start, end);
  for (final box in obstacles) {
    envelope = envelope.union(box);
  }
  for (final route in routes) {
    for (final p in route.points) {
      envelope = envelope.union(CanvasBounds(p.x, p.y, 0, 0));
    }
  }
  envelope = envelope.inflate(48);
  final fine = clearance * 2;
  final xs = <double>{
    start.x,
    end.x,
    if (clearance < 7) ...[
      start.x - fine,
      start.x + fine,
      end.x - fine,
      end.x + fine,
    ],
    envelope.left,
    envelope.right,
  };
  final ys = <double>{
    start.y,
    end.y,
    if (clearance < 7) ...[
      start.y - fine,
      start.y + fine,
      end.y - fine,
      end.y + fine,
    ],
    envelope.top,
    envelope.bottom,
  };
  for (final r in obstacles) {
    xs.addAll([r.left, r.right]);
    ys.addAll([r.top, r.bottom]);
  }
  for (final route in routes) {
    for (final p in route.points) {
      xs.addAll([
        p.x - 24,
        p.x - 12,
        if (clearance < 7) ...[p.x - fine, p.x + fine],
        p.x + 12,
        p.x + 24,
      ]);
      ys.addAll([
        p.y - 24,
        p.y - 12,
        if (clearance < 7) ...[p.y - fine, p.y + fine],
        p.y + 12,
        p.y + 24,
      ]);
    }
  }
  final x = xs.toList()..sort(), y = ys.toList()..sort();
  final nx = x.length;
  final cacheLength = nx * y.length * 2;
  final validity = cacheLength <= 4000000 ? Uint8List(cacheLength) : null;
  final sparseValidity = <int, int>{};
  final first = (y.indexOf(start.y) * nx + x.indexOf(start.x)) * 3;
  final target = y.indexOf(end.y) * nx + x.indexOf(end.x);
  final stateCount = nx * y.length * 3;
  // The bounded grid already gives states stable integer addresses. Avoid
  // boxed hash entries in the common case; keep a sparse fallback for huge grids.
  final denseScores = stateCount <= 131072
      ? (Float64List(stateCount)..fillRange(0, stateCount, double.infinity))
      : null;
  final denseParents = denseScores == null ? null : Int32List(stateCount);
  final scores = <int, double>{}, parent = <int, int>{};
  double scoreAt(int id) => denseScores?[id] ?? scores[id] ?? double.infinity;
  int? parentOf(int id) {
    if (denseParents == null) return parent[id];
    final value = denseParents[id];
    return value == 0 ? null : value - 1;
  }

  if (denseScores != null) {
    denseScores[first] = 0;
  } else {
    scores[first] = 0;
  }
  final heap = _RouteHeap()..add(first, 0);
  final nodeCollision = _GridObstacles(obstacles);
  var expanded = 0;
  while (heap.isNotEmpty && expanded++ < 18000) {
    final entry = heap.pop(),
        state = entry.id,
        cell = state ~/ 3,
        dir = state % 3;
    final ix = cell % nx, iy = cell ~/ nx;
    final at = CanvasPoint(x[ix], y[iy]), score = scoreAt(state);
    if (entry.cost >
        score + (end.x - at.x).abs() + (end.y - at.y).abs() + .001) {
      continue;
    }
    if (cell == target) {
      final points = <CanvasPoint>[at];
      var cursor = state;
      while (parentOf(cursor) != null) {
        cursor = parentOf(cursor)!;
        final c = cursor ~/ 3;
        points.add(CanvasPoint(x[c % nx], y[c ~/ nx]));
      }
      return _simplify(points.reversed.toList());
    }
    for (final delta in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final xx = ix + delta.$1, yy = iy + delta.$2;
      if (xx < 0 || xx >= nx || yy < 0 || yy >= y.length) continue;
      final next = CanvasPoint(x[xx], y[yy]);
      // The same undirected grid edge is visited from multiple heading states.
      // Its collision result is independent of direction and can be reused.
      final gridEdge = delta.$1 != 0
          ? (iy * nx + (ix < xx ? ix : xx)) * 2
          : ((iy < yy ? iy : yy) * nx + ix) * 2 + 1;
      var collisionState = validity?[gridEdge] ?? sparseValidity[gridEdge] ?? 0;
      if (collisionState == 0) {
        collisionState =
            nodeCollision.blocked(at, next) ||
                collision.near(at, next, clearance)
            ? 1
            : 2;
        if (validity != null) {
          validity[gridEdge] = collisionState;
        } else {
          sparseValidity[gridEdge] = collisionState;
        }
      }
      if (collisionState == 1) continue;
      final direction = delta.$1 == 0 ? 2 : 1,
          id = (yy * nx + xx) * 3 + direction;
      final cost =
          score + (next - at).length + (dir != 0 && dir != direction ? 24 : 0);
      if (cost >= scoreAt(id) - .001) continue;
      if (denseScores != null) {
        denseScores[id] = cost;
        denseParents![id] = state + 1;
      } else {
        scores[id] = cost;
        parent[id] = state;
      }
      heap.add(id, cost + (end.x - next.x).abs() + (end.y - next.y).abs());
    }
  }
  return null;
}

List<CanvasPoint> _simplify(List<CanvasPoint> points) {
  final result = <CanvasPoint>[];
  for (final p in points) {
    if (result.isNotEmpty && (p - result.last).length < .001) continue;
    while (result.length >= 2) {
      final a = result[result.length - 2],
          b = result.last,
          ab = b - a,
          bc = p - b;
      if ((ab.x * bc.y - ab.y * bc.x).abs() > .001 ||
          ab.x * bc.x + ab.y * bc.y < 0) {
        break;
      }
      result.removeLast();
    }
    result.add(p);
  }
  return result.length < 2 ? [points.first, points.last] : result;
}

class _RouteHeap {
  var _ids = List<int>.filled(64, 0);
  var _costs = Float64List(64);
  int _length = 0;
  bool get isNotEmpty => _length != 0;
  void add(int id, double cost) {
    if (_length == _ids.length) {
      _ids = List<int>.filled(_length * 2, 0)..setRange(0, _length, _ids);
      _costs = Float64List(_length * 2)..setRange(0, _length, _costs);
    }
    var i = _length++;
    while (i > 0) {
      final p = (i - 1) ~/ 2;
      if (_costs[p] <= cost) break;
      _ids[i] = _ids[p];
      _costs[i] = _costs[p];
      i = p;
    }
    _ids[i] = id;
    _costs[i] = cost;
  }

  ({int id, double cost}) pop() {
    final first = (id: _ids[0], cost: _costs[0]);
    _length--;
    if (_length == 0) return first;
    final lastId = _ids[_length], lastCost = _costs[_length];
    var i = 0;
    while (i * 2 + 1 < _length) {
      var c = i * 2 + 1;
      if (c + 1 < _length && _costs[c + 1] < _costs[c]) c++;
      if (_costs[c] >= lastCost) break;
      _ids[i] = _ids[c];
      _costs[i] = _costs[c];
      i = c;
    }
    _ids[i] = lastId;
    _costs[i] = lastCost;
    return first;
  }
}

/// Each grid edge lies on one axis band. Retain only the obstacles that can
/// intersect that band; exact clearance comparisons still decide collisions.
class _GridObstacles {
  _GridObstacles(this.bounds);
  final List<CanvasBounds> bounds;
  final _rows = <double, List<CanvasBounds>>{},
      _columns = <double, List<CanvasBounds>>{};
  bool blocked(CanvasPoint a, CanvasPoint b) {
    final horizontal = (a.y - b.y).abs() < .001;
    final cache = horizontal ? _rows : _columns;
    final coordinate = horizontal ? a.y : a.x;
    var candidates = cache[coordinate];
    if (candidates == null) {
      candidates = bounds
          .where(
            (r) => horizontal
                ? coordinate > r.top + .001 && coordinate < r.bottom - .001
                : coordinate > r.left + .001 && coordinate < r.right - .001,
          )
          .toList();
      if (cache.length >= 128) cache.remove(cache.keys.first);
      cache[coordinate] = candidates;
    }
    return candidates.any((r) => _blocked(a, b, r));
  }
}
