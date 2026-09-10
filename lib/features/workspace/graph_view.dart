import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';
import '../../domain/universal_object.dart';
import '../../domain/wiki_links.dart';

class GraphNode {
  GraphNode({
    required this.id,
    required this.title,
    required this.type,
    required this.x,
    required this.y,
  });

  final String id;
  final String title;
  final String type;
  double x;
  double y;
  double vx = 0;
  double vy = 0;
  int connectionCount = 0;
  bool matchesQuery = true;

  Color get color {
    switch (type) {
      case 'orbit.note':
        return const Color(0xFF8B7CF6); // Orbit Accent
      case 'orbit.task':
        return const Color(0xFFD8B56A); // Orbit Warning
      case 'orbit.canvas':
        return const Color(0xFF6F7FEA); // Orbit Secondary
      case 'orbit.event':
        return const Color(0xFF65C6A3); // Orbit Success
      default:
        return const Color(0xFFB6B2C2); // Orbit Subtle
    }
  }

  double get radius => (9.0 + (connectionCount * 1.5)).clamp(9.0, 24.0);
}

class GraphEdge {
  const GraphEdge({required this.sourceId, required this.targetId, this.label});

  final String sourceId;
  final String targetId;
  final String? label;
}

class GraphData {
  GraphData({required this.nodes, required this.edges});

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  Map<String, GraphNode> get nodeMap => {for (final n in nodes) n.id: n};

  static GraphData build({
    required List<UniversalObject> objects,
    String? focusId,
    int maxHops = 2,
    Set<String>? typeFilters,
    String query = '',
  }) {
    final activeObjects = objects.where((o) => !o.isDeleted).toList();
    final allowedTypes =
        typeFilters ??
        {'orbit.note', 'orbit.task', 'orbit.canvas', 'orbit.event'};

    // Map titles & IDs for link resolution
    final titleToId = <String, String>{};
    for (final o in activeObjects) {
      if (o.title.isNotEmpty) {
        titleToId[o.title.toLowerCase()] = o.id;
      }
    }

    final rawEdges = <GraphEdge>[];
    final edgeKeys = <String>{};

    void addEdge(String src, String tgt) {
      if (src == tgt) return;
      final key = src.compareTo(tgt) < 0 ? '$src:$tgt' : '$tgt:$src';
      if (edgeKeys.add(key)) {
        rawEdges.add(GraphEdge(sourceId: src, targetId: tgt));
      }
    }

    for (final o in activeObjects) {
      // 1. WikiLinks in notes
      if (o.typeId == 'orbit.note' && o.body.isNotEmpty) {
        final links = parseWikiLinks(o.body);
        for (final link in links) {
          final targetText = link.target.trim();
          final boundId = o.linkBindings[targetText];
          if (boundId != null) {
            addEdge(o.id, boundId);
          } else {
            final matchedId = titleToId[targetText.toLowerCase()];
            if (matchedId != null) {
              addEdge(o.id, matchedId);
            }
          }
        }
      }

      // 2. Task context link
      if (o.typeId == 'orbit.task') {
        final ctx = o.properties['context'];
        if (ctx is String && ctx.isNotEmpty) {
          addEdge(o.id, ctx);
        }
      }

      // 3. Event linked context
      if (o.typeId == 'orbit.event') {
        final ctx = o.properties['context'] ?? o.properties['linkedId'];
        if (ctx is String && ctx.isNotEmpty) {
          addEdge(o.id, ctx);
        }
      }

      // 4. Canvas transcluded elements
      if (o.typeId == 'orbit.canvas') {
        final elements = o.data['elements'];
        if (elements is List) {
          for (final el in elements) {
            if (el is Map) {
              final target = el['targetId'] ?? el['objectId'];
              if (target is String && target.isNotEmpty) {
                addEdge(o.id, target);
              }
            }
          }
        }
      }
    }

    // Filter nodes if in local focus mode
    Set<String> visibleIds;
    if (focusId != null && focusId.isNotEmpty) {
      visibleIds = {focusId};
      var currentHop = {focusId};
      for (var hop = 0; hop < maxHops; hop++) {
        final nextHop = <String>{};
        for (final edge in rawEdges) {
          if (currentHop.contains(edge.sourceId)) nextHop.add(edge.targetId);
          if (currentHop.contains(edge.targetId)) nextHop.add(edge.sourceId);
        }
        visibleIds.addAll(nextHop);
        currentHop = nextHop;
      }
    } else {
      visibleIds = activeObjects.map((o) => o.id).toSet();
    }

    // Build node list
    final nodes = <GraphNode>[];
    final random = math.Random(42);
    final count = activeObjects.length;

    for (var i = 0; i < count; i++) {
      final o = activeObjects[i];
      if (!visibleIds.contains(o.id)) continue;
      if (!allowedTypes.contains(o.typeId)) continue;

      // Arrange initially in an open spiral / circle
      final angle = (i / math.max(1, count)) * 2 * math.pi;
      final dist = 120.0 + (random.nextDouble() * 260.0);
      final x = 400.0 + (math.cos(angle) * dist);
      final y = 350.0 + (math.sin(angle) * dist);

      final node = GraphNode(
        id: o.id,
        title: o.title.isNotEmpty ? o.title : 'Untitled',
        type: o.typeId,
        x: x,
        y: y,
      );

      if (query.isNotEmpty) {
        node.matchesQuery = node.title.toLowerCase().contains(
          query.toLowerCase(),
        );
      }

      nodes.add(node);
    }

    final validNodeIds = nodes.map((n) => n.id).toSet();
    final filteredEdges = rawEdges
        .where(
          (e) =>
              validNodeIds.contains(e.sourceId) &&
              validNodeIds.contains(e.targetId),
        )
        .toList();

    // Compute connection counts
    for (final edge in filteredEdges) {
      for (final n in nodes) {
        if (n.id == edge.sourceId || n.id == edge.targetId) {
          n.connectionCount++;
        }
      }
    }

    // Run force-directed simulation steps
    simulatePhysics(nodes, filteredEdges, iterations: 35);

    return GraphData(nodes: nodes, edges: filteredEdges);
  }

  static void simulatePhysics(
    List<GraphNode> nodes,
    List<GraphEdge> edges, {
    int iterations = 35,
  }) {
    if (nodes.length <= 1) return;
    const kRepel = 4200.0;
    const kSpring = 0.045;
    const restLength = 110.0;
    final nodeMap = {for (final n in nodes) n.id: n};

    for (var iter = 0; iter < iterations; iter++) {
      // Repulsion between all nodes (Coulomb)
      for (var i = 0; i < nodes.length; i++) {
        final n1 = nodes[i];
        for (var j = i + 1; j < nodes.length; j++) {
          final n2 = nodes[j];
          final dx = n1.x - n2.x;
          final dy = n1.y - n2.y;
          final distSq = (dx * dx) + (dy * dy) + 1.0;
          final dist = math.sqrt(distSq);
          if (dist > 500) continue;
          final force = kRepel / distSq;
          final fx = (dx / dist) * force;
          final fy = (dy / dist) * force;
          n1.vx += fx;
          n1.vy += fy;
          n2.vx -= fx;
          n2.vy -= fy;
        }
      }

      // Attraction along edges (Hooke's spring)
      for (final edge in edges) {
        final n1 = nodeMap[edge.sourceId];
        final n2 = nodeMap[edge.targetId];
        if (n1 == null || n2 == null) continue;
        final dx = n2.x - n1.x;
        final dy = n2.y - n1.y;
        final dist = math.sqrt((dx * dx) + (dy * dy)) + 0.001;
        final delta = dist - restLength;
        final force = kSpring * delta;
        final fx = (dx / dist) * force;
        final fy = (dy / dist) * force;
        n1.vx += fx;
        n1.vy += fy;
        n2.vx -= fx;
        n2.vy -= fy;
      }

      // Centering force & damping
      for (final n in nodes) {
        n.vx += (400.0 - n.x) * 0.005;
        n.vy += (350.0 - n.y) * 0.005;
        n.vx *= 0.78;
        n.vy *= 0.78;
        n.x += n.vx;
        n.y += n.vy;
      }
    }
  }
}

/// An interactive, modern Knowledge Graph View (LNK-06) for Orbit Note.
class GraphView extends StatefulWidget {
  const GraphView({super.key, required this.controller});

  final WorkspaceController controller;

  @override
  State<GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends State<GraphView> {
  final TransformationController _transformCtrl = TransformationController();
  String _query = '';
  bool _localMode = false;
  final Set<String> _typeFilters = {
    'orbit.note',
    'orbit.task',
    'orbit.canvas',
    'orbit.event',
  };
  GraphNode? _hoveredNode;

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  void _resetView() {
    _transformCtrl.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final c = widget.controller;
    final activeId = c.session.activeId;

    final graphData = GraphData.build(
      objects: c.objects,
      focusId: _localMode ? activeId : null,
      typeFilters: _typeFilters,
      query: _query,
    );

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Interactive Graph Canvas
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _transformCtrl,
              boundaryMargin: const EdgeInsets.all(1200),
              minScale: 0.15,
              maxScale: 3.5,
              child: MouseRegion(
                onHover: (event) {
                  final localPos = event.localPosition;
                  GraphNode? closest;
                  var minDist = double.infinity;
                  for (final node in graphData.nodes) {
                    final dx = node.x - localPos.dx;
                    final dy = node.y - localPos.dy;
                    final dist = math.sqrt((dx * dx) + (dy * dy));
                    if (dist < node.radius + 8 && dist < minDist) {
                      minDist = dist;
                      closest = node;
                    }
                  }
                  if (closest != _hoveredNode) {
                    setState(() => _hoveredNode = closest);
                  }
                },
                child: GestureDetector(
                  onTapUp: (details) {
                    final localPos = details.localPosition;
                    for (final node in graphData.nodes) {
                      final dx = node.x - localPos.dx;
                      final dy = node.y - localPos.dy;
                      final dist = math.sqrt((dx * dx) + (dy * dy));
                      if (dist <= node.radius + 6) {
                        c.openObject(node.id);
                        return;
                      }
                    }
                  },
                  child: CustomPaint(
                    size: const Size(1800, 1400),
                    painter: _GraphCanvasPainter(
                      data: graphData,
                      hoveredNode: _hoveredNode,
                      colors: colors,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Floating Top Controls Bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colors.panel.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(OrbitRadius.card),
                border: Border.all(color: colors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  // Title & Mode Toggle
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hub_rounded, color: colors.accent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Knowledge Graph',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: const Text(
                          'Global',
                          style: TextStyle(fontSize: 11),
                        ),
                        selected: !_localMode,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setState(() => _localMode = false),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text(
                          'Local',
                          style: TextStyle(fontSize: 11),
                        ),
                        selected: _localMode,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setState(() => _localMode = true),
                      ),
                    ],
                  ),

                  // Search Filter
                  SizedBox(
                    width: 180,
                    height: 32,
                    child: TextField(
                      style: TextStyle(fontSize: 12, color: colors.text),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Filter nodes…',
                        prefixIcon: Icon(
                          Icons.search,
                          size: 16,
                          color: colors.subtle,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),

                  // Type Filter Chips & Reset
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TypeFilterChip(
                        label: 'Notes',
                        color: const Color(0xFF8B7CF6),
                        selected: _typeFilters.contains('orbit.note'),
                        onTap: () => setState(() {
                          _typeFilters.contains('orbit.note')
                              ? _typeFilters.remove('orbit.note')
                              : _typeFilters.add('orbit.note');
                        }),
                      ),
                      const SizedBox(width: 4),
                      _TypeFilterChip(
                        label: 'Tasks',
                        color: const Color(0xFFD8B56A),
                        selected: _typeFilters.contains('orbit.task'),
                        onTap: () => setState(() {
                          _typeFilters.contains('orbit.task')
                              ? _typeFilters.remove('orbit.task')
                              : _typeFilters.add('orbit.task');
                        }),
                      ),
                      const SizedBox(width: 4),
                      _TypeFilterChip(
                        label: 'Canvases',
                        color: const Color(0xFF6F7FEA),
                        selected: _typeFilters.contains('orbit.canvas'),
                        onTap: () => setState(() {
                          _typeFilters.contains('orbit.canvas')
                              ? _typeFilters.remove('orbit.canvas')
                              : _typeFilters.add('orbit.canvas');
                        }),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Reset view to center',
                        child: IconButton(
                          icon: const Icon(Icons.center_focus_strong, size: 18),
                          onPressed: _resetView,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.raised,
                          borderRadius: BorderRadius.circular(
                            OrbitRadius.control,
                          ),
                        ),
                        child: Text(
                          '${graphData.nodes.length} nodes · ${graphData.edges.length} links',
                          style: TextStyle(fontSize: 11, color: colors.subtle),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Hovered Node Details Pill
          if (_hoveredNode != null)
            Positioned(
              bottom: 24,
              left: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colors.raised.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(OrbitRadius.control),
                  border: Border.all(color: _hoveredNode!.color),
                  boxShadow: [
                    BoxShadow(
                      color: _hoveredNode!.color.withValues(alpha: 0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _hoveredNode!.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_hoveredNode!.type.replaceFirst('orbit.', '').toUpperCase()} · ${_hoveredNode!.connectionCount} connections · Click to open',
                      style: TextStyle(fontSize: 11, color: colors.subtle),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TypeFilterChip extends StatelessWidget {
  const _TypeFilterChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(OrbitRadius.control),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(OrbitRadius.control),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GraphCanvasPainter extends CustomPainter {
  _GraphCanvasPainter({
    required this.data,
    required this.hoveredNode,
    required this.colors,
  });

  final GraphData data;
  final GraphNode? hoveredNode;
  final OrbitColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw subtle background dot grid
    final gridPaint = Paint()..color = colors.border.withValues(alpha: 0.25);
    const spacing = 40.0;
    for (var x = 0.0; x < size.width; x += spacing) {
      for (var y = 0.0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.8, gridPaint);
      }
    }

    final nodeMap = data.nodeMap;
    final hovered = hoveredNode;
    final activeConnectedIds = <String>{};
    if (hovered != null) {
      activeConnectedIds.add(hovered.id);
      for (final edge in data.edges) {
        if (edge.sourceId == hovered.id) activeConnectedIds.add(edge.targetId);
        if (edge.targetId == hovered.id) activeConnectedIds.add(edge.sourceId);
      }
    }

    // 2. Draw edges
    final edgePaint = Paint()
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (final edge in data.edges) {
      final n1 = nodeMap[edge.sourceId];
      final n2 = nodeMap[edge.targetId];
      if (n1 == null || n2 == null) continue;

      final isHoverConnected =
          hovered != null &&
          (edge.sourceId == hovered.id || edge.targetId == hovered.id);

      if (isHoverConnected) {
        edgePaint.color = colors.accent;
        edgePaint.strokeWidth = 2.0;
      } else if (hovered != null) {
        edgePaint.color = colors.border.withValues(alpha: 0.2);
        edgePaint.strokeWidth = 0.8;
      } else {
        edgePaint.color = colors.border.withValues(alpha: 0.7);
        edgePaint.strokeWidth = 1.2;
      }

      canvas.drawLine(Offset(n1.x, n1.y), Offset(n2.x, n2.y), edgePaint);
    }

    // 3. Draw nodes
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final glowPaint = Paint()..style = PaintingStyle.fill;

    for (final node in data.nodes) {
      final isHovered = hovered != null && hovered.id == node.id;
      final isConnected =
          hovered != null && activeConnectedIds.contains(node.id);
      final isDimmed = hovered != null && !isConnected;

      final baseColor = node.color;
      final alphaFactor = (!node.matchesQuery || isDimmed) ? 0.25 : 1.0;
      final nodeRadius = isHovered ? node.radius * 1.25 : node.radius;

      // Outer glow
      glowPaint.color = baseColor.withValues(
        alpha: isHovered ? 0.45 : 0.15 * alphaFactor,
      );
      canvas.drawCircle(
        Offset(node.x, node.y),
        nodeRadius + (isHovered ? 8.0 : 4.0),
        glowPaint,
      );

      // Node body
      fillPaint.color = baseColor.withValues(alpha: 0.85 * alphaFactor);
      canvas.drawCircle(Offset(node.x, node.y), nodeRadius, fillPaint);

      // Node border
      strokePaint.color = isHovered
          ? Colors.white
          : baseColor.withValues(alpha: alphaFactor);
      canvas.drawCircle(Offset(node.x, node.y), nodeRadius, strokePaint);

      // Node Label
      final textSpan = TextSpan(
        text: node.title,
        style: TextStyle(
          fontSize: isHovered ? 12 : 10,
          fontWeight: isHovered ? FontWeight.bold : FontWeight.normal,
          color: isHovered
              ? Colors.white
              : colors.text.withValues(alpha: alphaFactor),
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 120);

      final labelOffset = Offset(
        node.x - (textPainter.width / 2),
        node.y + nodeRadius + 4,
      );

      // Label background pill for readability
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          labelOffset.dx - 4,
          labelOffset.dy - 2,
          textPainter.width + 8,
          textPainter.height + 4,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        bgRect,
        Paint()..color = colors.background.withValues(alpha: 0.8 * alphaFactor),
      );

      textPainter.paint(canvas, labelOffset);
    }
  }

  @override
  bool shouldRepaint(covariant _GraphCanvasPainter oldDelegate) => true;
}
