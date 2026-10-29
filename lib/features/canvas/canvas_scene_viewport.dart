import 'package:flutter/material.dart';
import '../../canvas/geometry.dart';
import '../../canvas/scene.dart';
import 'canvas_painter.dart';

/// Retain complete strokes in small, ordered world layers. Never cut a pen
/// segment at an internal tile edge: that changes pressure/antialias coverage.
/// Camera movement translates saved ink; zoom rebuilds at full density.
class CanvasSceneViewport extends StatelessWidget {
  const CanvasSceneViewport({
    super.key,
    required this.scene,
    required this.camera,
    required this.builder,
    this.inkCache,
  });
  final CanvasScene scene;
  final CanvasCamera camera;
  final CanvasInkCache? inkCache;
  final OrbitCanvasPainter Function(CanvasCamera, List<CanvasElement>) builder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final visible = scene.query(
        camera.viewport(size.width, size.height).inflate(80 / camera.zoom),
      );
      inkCache?.retainVisible(visible);
      final drawable = visible.where((e) => e.renderable && !e.hidden);
      final ordered = [
        ...drawable.where((e) => e.type == 'column'),
        ...drawable.where((e) => e.type != 'column'),
      ];
      final groups = <List<CanvasElement>>[];
      var groupSamples = 0;
      for (final element in ordered) {
        final bucket = (scene.orderOf(element.id) ?? 0) ~/ 32;
        if (groups.isEmpty ||
            (groups.last.first.type == 'ink') != (element.type == 'ink') ||
            ((scene.orderOf(groups.last.first.id) ?? 0) ~/ 32) != bucket ||
            (groups.last.first.type == 'column') !=
                (element.type == 'column') ||
            element.type == 'ink' && groupSamples >= 4096) {
          groups.add([]);
          groupSamples = 0;
        }
        groups.last.add(element);
        if (element.data['points'] is List) {
          groupSamples += (element.data['points'] as List).length;
        }
      }
      return ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _PaperPainter(builder(camera, const [])),
                ),
              ),
            ),
            for (final group in groups)
              if (group.first.type == 'ink')
                _inkLayer(group, MediaQuery.devicePixelRatioOf(context), size)
              else
                Positioned.fill(
                  key: ValueKey(('objects', group.first.id)),
                  child: RepaintBoundary(
                    child: CustomPaint(painter: builder(camera, group)),
                  ),
                ),
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(painter: builder(camera, const [])),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _inkLayer(List<CanvasElement> group, double density, Size viewport) {
    var bounds = group.first.bounds;
    var padding = 2.0;
    for (final element in group) {
      bounds = bounds.union(element.bounds);
      final width = element.data['isHighlighter'] == true
          ? 22.0
          : element.strokeWidth;
      if (width * 2 + 2 > padding) padding = width * 2 + 2;
    }
    bounds = bounds.inflate(padding);
    // Align layer origins to the device-pixel grid, so a fractional world
    // bound does not add a second subpixel transform to pressure geometry.
    final scale = camera.zoom * density;
    final left = (bounds.left * scale).floor() / scale;
    final top = (bounds.top * scale).floor() / scale;
    bounds = CanvasBounds(
      left,
      top,
      (bounds.right * scale).ceil() / scale - left,
      (bounds.bottom * scale).ceil() / scale - top,
    );
    // A million-unit imported stroke must not request a giant bitmap. Crop
    // derived layers well outside the viewport, on a stable world grid.
    final stride = 512 / camera.zoom;
    final cropLeft = (camera.x / stride).floor() * stride - stride;
    final cropTop = (camera.y / stride).floor() * stride - stride;
    final crop = Rect.fromLTWH(
      cropLeft,
      cropTop,
      viewport.width / camera.zoom + stride * 3,
      viewport.height / camera.zoom + stride * 3,
    );
    final clipped = Rect.fromLTWH(
      bounds.left,
      bounds.top,
      bounds.width,
      bounds.height,
    ).intersect(crop);
    bounds = CanvasBounds(
      clipped.left,
      clipped.top,
      clipped.width,
      clipped.height,
    );
    return Positioned(
      key: ValueKey(('ink', group.first.id, camera.zoom)),
      left: (bounds.left - camera.x) * camera.zoom,
      top: (bounds.top - camera.y) * camera.zoom,
      width: bounds.width * camera.zoom,
      height: bounds.height * camera.zoom,
      child: RepaintBoundary(
        child: CustomPaint(
          isComplex: true,
          painter: builder(
            CanvasCamera(x: bounds.left, y: bounds.top, zoom: camera.zoom),
            group,
          ),
        ),
      ),
    );
  }
}

// Paper remains viewport-sized, including gradients, sheet edges and labels.
class _PaperPainter extends CustomPainter {
  _PaperPainter(this.delegate);
  final OrbitCanvasPainter delegate;
  @override
  void paint(Canvas canvas, Size size) =>
      delegate.paintBackground(canvas, size);
  @override
  bool shouldRepaint(_PaperPainter old) =>
      delegate.camera.x != old.delegate.camera.x ||
      delegate.camera.y != old.delegate.camera.y ||
      delegate.camera.zoom != old.delegate.camera.zoom ||
      delegate.colors != old.delegate.colors ||
      delegate.semanticColors != old.delegate.semanticColors ||
      delegate.backgroundStyle != old.delegate.backgroundStyle;
}
