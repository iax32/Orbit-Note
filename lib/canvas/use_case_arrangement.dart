import 'dart:math' as math;

import 'connectors.dart';
import 'geometry.dart';
import 'scene.dart';
import 'uml_interaction.dart';

bool _node(CanvasElement e) =>
    e.renderable &&
    !e.hidden &&
    const {UmlNodeKind.actor, UmlNodeKind.useCase}.contains(umlNodeKind(e));

/// Repositions only the selected connected use-case components (all if empty).
/// Pure placement edits: callers apply these together as one history command.
/// Two actors flank the cases, avoiding the tangled K2,n fan-out on one side.
/// No identities, notation, manual control points or source references change.
List<CanvasElement> organizeUseCases(
  CanvasScene scene, {
  Set<String> selection = const {},
}) {
  if (scene.readOnly) return [];
  final nodes = {for (final e in scene.elements.where(_node)) e.id: e};
  final links = scene.elements
      .where(
        (e) =>
            !e.hidden &&
            e.renderable &&
            umlLinkKind(e) != null &&
            nodes.containsKey(e.startId) &&
            nodes.containsKey(e.endId),
      )
      .toList();
  final adjacency = {for (final id in nodes.keys) id: <String>[]};
  for (final e in links) {
    adjacency[e.startId]!.add(e.endId!);
    adjacency[e.endId]!.add(e.startId!);
  }
  final seeds = selection.isEmpty
      ? nodes.keys.toSet()
      : <String>{
          ...selection.where(nodes.containsKey),
          for (final e in links.where((e) => selection.contains(e.id))) ...[
            e.startId!,
            e.endId!,
          ],
        };
  final remaining = nodes.keys.toSet();
  final result = <String, CanvasElement>{};
  int order(CanvasElement a, CanvasElement b) {
    final y = a.y.compareTo(b.y);
    return y != 0 ? y : a.id.compareTo(b.id);
  }

  while (remaining.isNotEmpty) {
    final ids = <String>{};
    final queue = [remaining.first];
    for (var i = 0; i < queue.length; i++) {
      final id = queue[i];
      if (!remaining.remove(id)) continue;
      ids.add(id);
      queue.addAll(adjacency[id]!);
    }
    if (!ids.any(seeds.contains)) continue;
    final members = ids.map((id) => nodes[id]!).toList();
    final actors =
        members.where((e) => umlNodeKind(e) == UmlNodeKind.actor).toList()
          ..sort((a, b) {
            final x = a.x.compareTo(b.x);
            return x != 0 ? x : order(a, b);
          });
    final cases =
        members.where((e) => umlNodeKind(e) == UmlNodeKind.useCase).toList()
          ..sort(order);
    if (cases.isEmpty || members.length < 2) continue;
    final bounds = members.map((e) => e.bounds).reduce((a, b) => a.union(b));
    final related = links
        .where((e) => ids.contains(e.startId) && ids.contains(e.endId))
        .toList();
    // Place directly related cases consecutively, so include/extend can use the
    // short vertical gap instead of wrapping behind unrelated cases.
    final caseIds = cases.map((e) => e.id).toSet();
    final ordered = <CanvasElement>[];
    void visit(CanvasElement first) {
      final pending = [first.id];
      for (var i = 0; i < pending.length; i++) {
        final id = pending[i];
        if (!caseIds.remove(id)) continue;
        ordered.add(nodes[id]!);
        final neighbors =
            adjacency[id]!
                .where(caseIds.contains)
                .map((id) => nodes[id]!)
                .toList()
              ..sort(order);
        pending.addAll(neighbors.map((e) => e.id));
      }
    }

    for (final e in cases) {
      if (caseIds.contains(e.id)) visit(e);
    }
    final actorWidth = actors.fold(0.0, (n, e) => math.max(n, e.width));
    final caseWidth = cases.fold(0.0, (n, e) => math.max(n, e.width));
    final gap = math.max(220.0, 120 + related.length * 10.0);
    final caseX = bounds.left + (actors.isEmpty ? 0 : actorWidth + gap);
    final proposed = <String, CanvasElement>{};
    var y = bounds.top;
    for (final e in ordered) {
      proposed[e.id] = e.locked
          ? e
          : e.copy({'x': caseX + (caseWidth - e.width) / 2, 'y': y});
      y += e.height + 100;
    }
    final actorBottom = <int, double>{};
    for (var i = 0; i < actors.length; i++) {
      final e = actors[i];
      final targets = adjacency[e.id]!
          .where(proposed.containsKey)
          .map((id) => proposed[id]!.bounds.center.y)
          .toList();
      final center = targets.isEmpty
          ? bounds.top + (y - bounds.top) / 2
          : targets.reduce((a, b) => a + b) / targets.length;
      final actorY = math.max(
        math.max(bounds.top, center - e.height / 2),
        actorBottom[i % 2] ?? bounds.top,
      );
      proposed[e.id] = e.locked
          ? e
          : e.copy({
              'x': i.isEven ? bounds.left : caseX + caseWidth + gap,
              'y': actorY,
            });
      actorBottom[i % 2] = proposed[e.id]!.bounds.bottom + 100;
    }
    // Preserve unrelated content and locked placements. Find a free band rather
    // than dropping the newly expanded layout over a neighboring board/diagram.
    final obstacles = scene.elements
        .where(
          (e) =>
              !ids.contains(e.id) &&
              !e.hidden &&
              e.renderable &&
              !isConnectorElement(e) &&
              e.type != 'frame' &&
              umlNodeKind(e) != UmlNodeKind.system,
        )
        .toList();
    obstacles.addAll(members.where((e) => e.locked));
    var shift = 0.0;
    for (var attempt = 0; attempt <= obstacles.length; attempt++) {
      double? next;
      for (final e in proposed.values.where((e) => !e.locked)) {
        final box = CanvasBounds(e.x, e.y + shift, e.width, e.height);
        for (final obstacle in obstacles) {
          final occupied = (result[obstacle.id] ?? obstacle).bounds.inflate(36);
          if (box.intersects(occupied)) {
            next = math.max(next ?? shift, occupied.bottom - e.y + 1);
          }
        }
      }
      if (next == null) break;
      shift = next;
    }
    for (final e in proposed.values) {
      if (e.locked) continue;
      final placed = e.translated(CanvasPoint(0, shift));
      final old = nodes[e.id]!;
      if (placed.x != old.x || placed.y != old.y) result[e.id] = placed;
    }
  }
  // Expand owned system boundaries with their contents. Never shrink a frame,
  // move unrelated contents or resize a locked boundary.
  for (final frame in scene.elements.where(
    (e) =>
        !e.locked &&
        !e.hidden &&
        e.renderable &&
        umlNodeKind(e) == UmlNodeKind.system,
  )) {
    var bounds = frame.bounds;
    for (final original in nodes.values) {
      final moved = result[original.id];
      if (moved != null && frame.bounds.contains(original.bounds.center)) {
        bounds = bounds.union(moved.bounds.inflate(48));
      }
    }
    if (bounds.left != frame.x ||
        bounds.top != frame.y ||
        bounds.width != frame.width ||
        bounds.height != frame.height) {
      result[frame.id] = frame.copy({
        'x': bounds.left,
        'y': bounds.top,
        'width': bounds.width,
        'height': bounds.height,
      });
    }
  }
  // Stored endpoint fallbacks travel with their node for older/offline readers;
  // manual curves, fixed anchors and all unknown connector data remain intact.
  for (final e in scene.elements.where(isConnectorElement)) {
    if (e.locked) continue;
    final a = result[e.startId], b = result[e.endId];
    if (a == null && b == null) continue;
    final deltaA = a == null
        ? const CanvasPoint(0, 0)
        : CanvasPoint(a.x - scene[a.id]!.x, a.y - scene[a.id]!.y);
    final deltaB = b == null
        ? const CanvasPoint(0, 0)
        : CanvasPoint(b.x - scene[b.id]!.x, b.y - scene[b.id]!.y);
    final start = storedConnectorStart(e) + deltaA;
    final end = storedConnectorEnd(e) + deltaB;
    result[e.id] = e.copy({
      'startX': start.x,
      'startY': start.y,
      'endX': end.x,
      'endY': end.y,
    });
  }
  return result.values.toList();
}
