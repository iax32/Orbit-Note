import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';
import 'graph_view.dart';

/// Compact, interactive 2D local context graph embedded in the inspector or note view.
///
/// Visualizes the local web of knowledge around a focal object (1-2 hops),
/// with node type colors, interactive force physics, zoom/pan, and 1-click navigation.
class LocalContextGraph extends StatefulWidget {
  const LocalContextGraph({
    super.key,
    required this.controller,
    required this.focusId,
    this.height = 240,
    this.onOpenObject,
  });

  final WorkspaceController controller;
  final String focusId;
  final double height;
  final ValueChanged<String>? onOpenObject;

  @override
  State<LocalContextGraph> createState() => _LocalContextGraphState();
}

class _LocalContextGraphState extends State<LocalContextGraph> {
  final TransformationController _transformCtrl = TransformationController();
  int _hops = 1;
  GraphData? _graphData;
  GraphNode? _hoveredNode;
  String _lastConfig = '';

  @override
  void initState() {
    super.initState();
    _rebuildGraph();
  }

  @override
  void didUpdateWidget(covariant LocalContextGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusId != widget.focusId ||
        oldWidget.controller.objects.length !=
            widget.controller.objects.length) {
      _rebuildGraph();
    }
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  void _rebuildGraph() {
    final c = widget.controller;
    final config = '${widget.focusId}|$_hops|${c.objects.length}';
    if (config == _lastConfig && _graphData != null) return;
    _lastConfig = config;

    final data = GraphData.build(
      objects: c.objects,
      focusId: widget.focusId,
      maxHops: _hops,
    );

    setState(() {
      _graphData = data;
      _hoveredNode = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitToView();
    });
  }

  void _fitToView() {
    final nodes = _graphData?.nodes;
    if (nodes == null || nodes.isEmpty) {
      _transformCtrl.value = Matrix4.identity();
      return;
    }

    var minX = nodes.first.x;
    var maxX = nodes.first.x;
    var minY = nodes.first.y;
    var maxY = nodes.first.y;

    for (final n in nodes) {
      if (n.x < minX) minX = n.x;
      if (n.x > maxX) maxX = n.x;
      if (n.y < minY) minY = n.y;
      if (n.y > maxY) maxY = n.y;
    }

    final boxW = math.max(60.0, maxX - minX + 80.0);
    final boxH = math.max(60.0, maxY - minY + 80.0);
    final centerX = (minX + maxX) / 2.0;
    final centerY = (minY + maxY) / 2.0;

    final renderBox = context.findRenderObject() as RenderBox?;
    final viewW = renderBox?.hasSize == true ? renderBox!.size.width : 300.0;
    final viewH = widget.height;

    final scale = math.min(viewW / boxW, viewH / boxH).clamp(0.45, 1.4);

    final tx = (viewW / 2.0) - (centerX * scale);
    final ty = (viewH / 2.0) - (centerY * scale);

    _transformCtrl.value = Matrix4.identity()
      ..translateByDouble(tx, ty, 0.0, 1.0)
      ..scaleByDouble(scale, scale, 1.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final graph = _graphData;
    final nodesCount = graph?.nodes.length ?? 0;
    final edgesCount = graph?.edges.length ?? 0;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: colors.raised.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 1. Interactive Canvas
          if (graph != null && nodesCount > 0)
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transformCtrl,
                boundaryMargin: const EdgeInsets.all(500),
                minScale: 0.25,
                maxScale: 3.0,
                child: MouseRegion(
                  onExit: (_) => setState(() => _hoveredNode = null),
                  onHover: (event) {
                    final local = event.localPosition;
                    GraphNode? closest;
                    var minDist = double.infinity;
                    for (final n in graph.nodes) {
                      final dx = n.x - local.dx;
                      final dy = n.y - local.dy;
                      final dist = math.sqrt((dx * dx) + (dy * dy));
                      if (dist < n.radius + 8 && dist < minDist) {
                        minDist = dist;
                        closest = n;
                      }
                    }
                    if (closest != _hoveredNode) {
                      setState(() => _hoveredNode = closest);
                    }
                  },
                  child: GestureDetector(
                    onTapUp: (details) {
                      final local = details.localPosition;
                      for (final n in graph.nodes) {
                        final dx = n.x - local.dx;
                        final dy = n.y - local.dy;
                        final dist = math.sqrt((dx * dx) + (dy * dy));
                        if (dist <= n.radius + 6) {
                          if (widget.onOpenObject != null) {
                            widget.onOpenObject!(n.id);
                          } else {
                            widget.controller.openObject(n.id);
                          }
                          return;
                        }
                      }
                    },
                    child: CustomPaint(
                      size: const Size(1200, 1000),
                      painter: _LocalContextPainter(
                        data: graph,
                        focusId: widget.focusId,
                        hoveredNode: _hoveredNode,
                        colors: colors,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hub_outlined,
                      size: 28,
                      color: colors.subtle.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'No local connections yet',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.subtle,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Type [[note title]] to link documents',
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.subtle.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 2. Overlay Controls (Top Bar)
          Positioned(
            top: 6,
            left: 8,
            right: 8,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.panel.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hub, size: 11, color: colors.accent),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '$nodesCount ${nodesCount == 1 ? "node" : "nodes"} · $edgesCount ${edgesCount == 1 ? "link" : "links"}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: colors.subtle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Hop count toggle
                Container(
                  decoration: BoxDecoration(
                    color: colors.panel.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Wrap(
                    children: [
                      _buildHopButton('1 Hop', 1, colors),
                      _buildHopButton('2 Hops', 2, colors),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Re-center button
                Tooltip(
                  message: 'Reset graph view',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: _fitToView,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colors.panel.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: colors.border.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Icon(
                        Icons.filter_center_focus,
                        size: 13,
                        color: colors.subtle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Hover tooltip chip
          if (_hoveredNode != null)
            Positioned(
              bottom: 6,
              left: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.panel.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _hoveredNode!.colorFor(colors)),
                  boxShadow: [
                    BoxShadow(
                      color: _hoveredNode!
                          .colorFor(colors)
                          .withValues(alpha: 0.25),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _hoveredNode!.colorFor(colors),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(
                        _hoveredNode!.title,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: colors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '· Click to open',
                      style: TextStyle(fontSize: 9, color: colors.subtle),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHopButton(String label, int hops, OrbitColors colors) {
    final selected = _hops == hops;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () {
        if (_hops != hops) {
          setState(() => _hops = hops);
          _rebuildGraph();
        }
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? colors.accent.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? colors.accent : colors.subtle,
          ),
        ),
      ),
    );
  }
}

class _LocalContextPainter extends CustomPainter {
  const _LocalContextPainter({
    required this.data,
    required this.focusId,
    required this.hoveredNode,
    required this.colors,
  });

  final GraphData data;
  final String focusId;
  final GraphNode? hoveredNode;
  final OrbitColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Subtle background dots
    final dotPaint = Paint()..color = colors.border.withValues(alpha: 0.18);
    const spacing = 32.0;
    for (var x = 0.0; x < size.width; x += spacing) {
      for (var y = 0.0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.7, dotPaint);
      }
    }

    final nodeMap = data.nodeMap;
    final hovered = hoveredNode ?? nodeMap[focusId];
    final activeConnectedIds = <String>{};
    if (hovered != null) {
      activeConnectedIds.add(hovered.id);
      for (final edge in data.edges) {
        if (edge.sourceId == hovered.id) activeConnectedIds.add(edge.targetId);
        if (edge.targetId == hovered.id) activeConnectedIds.add(edge.sourceId);
      }
    }

    // 2. Draw Edges
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final edge in data.edges) {
      final n1 = nodeMap[edge.sourceId];
      final n2 = nodeMap[edge.targetId];
      if (n1 == null || n2 == null) continue;

      final isHoverEdge =
          hovered != null &&
          (edge.sourceId == hovered.id || edge.targetId == hovered.id);

      if (isHoverEdge) {
        edgePaint.color = colors.accent;
        edgePaint.strokeWidth = 1.8;
      } else {
        edgePaint.color = colors.subtle.withValues(alpha: 0.28);
        edgePaint.strokeWidth = 1.0;
      }

      canvas.drawLine(Offset(n1.x, n1.y), Offset(n2.x, n2.y), edgePaint);
    }

    // 3. Draw Nodes
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()..style = PaintingStyle.stroke;
    final glowPaint = Paint()..style = PaintingStyle.fill;

    for (final node in data.nodes) {
      final isFocal = node.id == focusId;
      final isHovered = hovered != null && hovered.id == node.id;
      final isConnected =
          hovered != null && activeConnectedIds.contains(node.id);
      final isDimmed = hovered != null && !isConnected;

      final baseColor = node.colorFor(colors);
      final alpha = isDimmed ? 0.35 : 1.0;
      final radius = isFocal ? node.radius + 3.0 : node.radius;

      // Outer pulsing glow for focal node
      if (isFocal) {
        glowPaint.color = colors.accent.withValues(alpha: 0.22);
        canvas.drawCircle(Offset(node.x, node.y), radius + 7.0, glowPaint);
        glowPaint.color = colors.accent.withValues(alpha: 0.12);
        canvas.drawCircle(Offset(node.x, node.y), radius + 12.0, glowPaint);
      } else if (isHovered) {
        glowPaint.color = baseColor.withValues(alpha: 0.2);
        canvas.drawCircle(Offset(node.x, node.y), radius + 5.0, glowPaint);
      }

      // Node Body Fill
      fillPaint.color = colors.panel.withValues(alpha: alpha);
      canvas.drawCircle(Offset(node.x, node.y), radius, fillPaint);

      // Node Border Stroke
      strokePaint.color = isFocal
          ? colors.accent
          : isHovered
          ? colors.accentHover
          : baseColor.withValues(alpha: 0.85 * alpha);
      strokePaint.strokeWidth = isFocal ? 2.5 : (isHovered ? 2.0 : 1.4);
      canvas.drawCircle(Offset(node.x, node.y), radius, strokePaint);

      // Center type-colored dot
      canvas.drawCircle(
        Offset(node.x, node.y),
        isFocal ? 4.0 : 2.5,
        Paint()
          ..color = (isFocal ? colors.accent : baseColor).withValues(
            alpha: alpha,
          ),
      );

      // Label below node
      final textSpan = TextSpan(
        text: node.title,
        style: TextStyle(
          fontFamily: 'Segoe UI',
          fontSize: isFocal ? 11 : 10,
          fontWeight: isFocal || isHovered
              ? FontWeight.bold
              : FontWeight.normal,
          color: isFocal
              ? colors.accent
              : (isHovered
                    ? colors.text
                    : colors.subtle.withValues(alpha: alpha)),
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 100);

      textPainter.paint(
        canvas,
        Offset(node.x - (textPainter.width / 2), node.y + radius + 3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LocalContextPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.focusId != focusId ||
        oldDelegate.hoveredNode != hoveredNode ||
        oldDelegate.colors != colors;
  }
}
