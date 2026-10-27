import 'package:flutter/material.dart';
import '../../canvas/geometry.dart';
import '../../canvas/scene.dart';
import '../canvas/canvas_painter.dart';

/// Uses the production vector renderer, including SVG-compatible UML glyphs.
class UniversityPreview extends StatefulWidget {
  const UniversityPreview({
    super.key,
    required this.scene,
    this.active = const {},
  });
  final CanvasScene scene;
  final Set<String> active;
  @override
  State<UniversityPreview> createState() => _UniversityPreviewState();
}

class _UniversityPreviewState extends State<UniversityPreview> {
  final cache = CanvasTextCache();
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 300,
    child: LayoutBuilder(
      builder: (context, size) {
        final frame = widget.scene.elements.first.bounds;
        final x = (size.maxWidth - 20) / frame.width,
            y = 280 / frame.height,
            zoom = x < y ? x : y;
        return Semantics(
          label:
              'University diagram preview. Pinch or scroll to zoom; highlighted nodes are active.',
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 8,
            child: CustomPaint(
              size: Size(size.maxWidth, 300),
              painter: OrbitCanvasPainter(
                scene: widget.scene,
                camera: CanvasCamera(
                  x: frame.left - 10 / zoom,
                  y: frame.top - 10 / zoom,
                  zoom: zoom,
                ),
                selection: const {},
                objects: const {},
                colors: Theme.of(context).colorScheme,
                textCache: cache,
                forceUmlDetails: true,
                searchMatchIds: widget.active,
              ),
            ),
          ),
        );
      },
    ),
  );
}
