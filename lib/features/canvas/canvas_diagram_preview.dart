import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../app/orbit_theme.dart';
import '../../canvas/geometry.dart';
import '../../canvas/scene.dart';
import '../../canvas/uml.dart';
import 'canvas_painter.dart';

/// Native vector view of the shared scene; no screenshot or image attachment.
class CanvasDiagramPreview extends StatefulWidget {
  const CanvasDiagramPreview({
    super.key,
    required this.scene,
    required this.title,
    this.onOpen,
    this.onEdit,
    this.unavailable = 0,
  });
  final CanvasScene scene;
  final String title;
  final VoidCallback? onOpen;
  final VoidCallback? onEdit;
  final int unavailable;
  @override
  State<CanvasDiagramPreview> createState() => _CanvasDiagramPreviewState();
}

class _CanvasDiagramPreviewState extends State<CanvasDiagramPreview> {
  final cache = CanvasTextCache();
  @override
  void dispose() {
    cache.dispose();
    super.dispose();
  }

  Widget paint(double width, double height) {
    final bounds = widget.scene.contentBounds!;
    final zoom = math
        .min(
          (width - 40) / math.max(1, bounds.width),
          (height - 40) / math.max(1, bounds.height),
        )
        .clamp(.01, 2.0);
    return RepaintBoundary(
      child: CustomPaint(
        key: const ValueKey('note-diagram-vector'),
        painter: OrbitCanvasPainter(
          scene: widget.scene,
          camera: CanvasCamera(
            x: bounds.center.x - width / zoom / 2,
            y: bounds.center.y - height / zoom / 2,
            zoom: zoom,
          ),
          selection: const {},
          objects: const {},
          colors: Theme.of(context).colorScheme,
          textCache: cache,
          backgroundStyle: 'none',
          forceUmlDetails: true,
        ),
        size: Size(width, height),
      ),
    );
  }

  void expand() {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 1200,
          height: MediaQuery.sizeOf(context).height * .85,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close diagram preview',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (_, bounds) => ClipRect(
                    child: InteractiveViewer(
                      minScale: .5,
                      maxScale: 5,
                      child: SizedBox(
                        width: bounds.maxWidth,
                        height: bounds.maxHeight,
                        child: paint(bounds.maxWidth, bounds.maxHeight),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final nodes = widget.scene.elementsInOrder.where(isUmlClass).toList();
    final otherNodes = widget.scene.elementsInOrder
        .where(
          (e) =>
              !isUmlClass(e) &&
              !['arrow', 'line', 'connector'].contains(e.type) &&
              e.text.isNotEmpty,
        )
        .toList();
    final edges = widget.scene.elementsInOrder
        .where(
          (e) => e.type == 'connector' || e.type == 'arrow' || e.type == 'line',
        )
        .length;
    final bounds = widget.scene.contentBounds;
    return Material(
      key: const ValueKey('note-diagram-surface'),
      color: colors.panel,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.border),
        borderRadius: BorderRadius.circular(OrbitRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  otherNodes.isEmpty
                      ? 'Live diagram · ${nodes.length} classes · $edges relationships'
                      : 'Research diagram · ${otherNodes.length + nodes.length} items · $edges relationships',
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (widget.unavailable > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  '${widget.unavailable} referenced diagram items are missing or hidden. Open Canvas to review the source.',
                  style: TextStyle(color: colors.warning),
                ),
              ),
            ),
          if (bounds == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'The referenced diagram items are unavailable. The original reference is retained.',
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = math.max(640.0, constraints.maxWidth);
                final height =
                    ((bounds.height + 40) /
                            math.max(1, bounds.width + 40) *
                            width)
                        .clamp(240.0, 620.0);
                return Semantics(
                  label: 'Diagram. Expand to zoom, or read the details below.',
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: paint(width, height),
                    ),
                  ),
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                if (widget.onOpen != null)
                  TextButton.icon(
                    onPressed: widget.onOpen,
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open Canvas'),
                  ),
                if (bounds != null)
                  TextButton.icon(
                    onPressed: expand,
                    icon: const Icon(Icons.open_in_full, size: 16),
                    label: const Text('Expand'),
                  ),
                if (widget.onEdit != null)
                  TextButton.icon(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit diagram'),
                  ),
              ],
            ),
          ),
          if (nodes.isNotEmpty)
            ExpansionTile(
              title: const Text('Class details'),
              children: [
                for (final e in nodes)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SelectableText(
                        UmlClass(e).searchableText,
                        style: TextStyle(color: colors.text, height: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          if (otherNodes.isNotEmpty)
            ExpansionTile(
              title: const Text('Diagram details'),
              children: [
                for (final e in otherNodes)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(e.text),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
