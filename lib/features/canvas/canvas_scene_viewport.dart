import 'package:flutter/material.dart';
import '../../canvas/geometry.dart';
import '../../canvas/scene.dart';
import 'canvas_painter.dart';
import '../../app/canvas_performance.dart';

/// Retain complete strokes in small, ordered world layers. Never cut a pen
/// segment at an internal tile edge: that changes pressure/antialias coverage.
/// Camera movement translates saved ink; zoom rebuilds at full density.
class CanvasSceneViewport extends StatefulWidget {
  const CanvasSceneViewport({
    super.key,
    required this.scene,
    required this.camera,
    required this.builder,
    this.inkCache,
    this.performanceSurface = 0,
  });
  final CanvasScene scene;
  final CanvasCamera camera;
  final CanvasInkCache? inkCache;
  final int performanceSurface;
  final OrbitCanvasPainter Function(CanvasCamera, List<CanvasElement>) builder;

  @override
  State<CanvasSceneViewport> createState() => _CanvasSceneViewportState();
}

class _RetainedGroup {
  _RetainedGroup(this.order, this.elements);
  final int order;
  final List<CanvasElement> elements;
}

class _CanvasSceneViewportState extends State<CanvasSceneViewport> {
  CanvasScene get scene => widget.scene;
  CanvasCamera get camera => widget.camera;
  CanvasInkCache? get inkCache => widget.inkCache;
  OrbitCanvasPainter Function(CanvasCamera, List<CanvasElement>) get builder =>
      widget.builder;
  CanvasScene? _plannedScene;
  int? _plannedRevision;
  final _membership = <String, _RetainedGroup>{};
  double _layerPixels = 0, _maxLayerPixels = 0;

  void _preparePlan() {
    if (identical(scene, _plannedScene) && scene.revision == _plannedRevision) {
      return;
    }
    _plannedScene = scene;
    _plannedRevision = scene.revision;
    _membership.clear();
    final drawable = scene.elementsInOrder
        .where((e) => e.renderable && !e.hidden)
        .toList();
    final ordered = [
      ...drawable.where((e) => e.type == 'column'),
      ...drawable.where((e) => e.type != 'column'),
    ];
    var samples = 0, serial = 0;
    _RetainedGroup? group;
    for (final element in ordered) {
      final first = group?.elements.first;
      if (first == null ||
          (first.type == 'ink') != (element.type == 'ink') ||
          (scene.orderOf(first.id) ?? 0) ~/ 32 !=
              (scene.orderOf(element.id) ?? 0) ~/ 32 ||
          (first.type == 'column') != (element.type == 'column') ||
          element.type == 'ink' && samples >= 4096) {
        group = _RetainedGroup(serial++, []);
        samples = 0;
      }
      group!.elements.add(element);
      _membership[element.id] = group;
      if (element.data['points'] is List) {
        samples += (element.data['points'] as List).length;
      }
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final perf = CanvasPerformance.instance;
      final started = perf.begin();
      _preparePlan();
      _layerPixels = 0;
      _maxLayerPixels = 0;
      final size = constraints.biggest;
      final visible = scene.query(
        camera.viewport(size.width, size.height).inflate(80 / camera.zoom),
      );
      // Visibility chooses groups, never their membership or world origin.
      // Otherwise each entering/leaving stroke invalidates its entire bitmap
      // during a pan even when no authored content changed.
      final active = <_RetainedGroup>{
        for (final e in visible)
          if (_membership[e.id] != null) _membership[e.id]!,
      }.toList()..sort((a, b) => a.order.compareTo(b.order));
      final groups = active.map((g) => g.elements).toList();
      inkCache?.retainVisible(groups.expand((g) => g));
      final result = ClipRect(
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
      perf.duration(
        CanvasPerfEvent.viewportBuild,
        widget.performanceSurface,
        started,
        {
          'groups': groups.length,
          'visible': visible.length,
          'layerPixels': _layerPixels,
          'largestLayerPixels': _maxLayerPixels,
        },
      );
      perf.gauge(widget.performanceSurface, {
        'groups': groups.length,
        'visible': visible.length,
        'layerPixels': _layerPixels,
        'largestLayerPixels': _maxLayerPixels,
        'zoom': camera.zoom,
        'density': MediaQuery.devicePixelRatioOf(context),
        'hz': View.of(context).display.refreshRate,
      });
      return result;
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
    final pixels = bounds.width * bounds.height * scale * scale;
    _layerPixels += pixels;
    if (pixels > _maxLayerPixels) _maxLayerPixels = pixels;
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
