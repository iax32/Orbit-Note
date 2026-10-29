import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../../canvas/geometry.dart';
import '../../canvas/scene.dart';
import 'canvas_painter.dart';
import '../../app/canvas_performance.dart';

/// Repaint only the active vector stroke. Samples never rebuild the editor,
/// re-query the saved scene or invalidate its display lists.
class CanvasLiveInkPainter extends CustomPainter {
  CanvasLiveInkPainter({
    required Listenable changes,
    required this.stroke,
    required this.camera,
    this.cache,
    this.performanceSurface = 0,
  }) : super(repaint: changes);
  final CanvasElement? Function() stroke;
  final CanvasCamera Function() camera;
  final CanvasLiveInkCache? cache;
  final int performanceSurface;
  @override
  void paint(Canvas canvas, Size size) {
    final perf = CanvasPerformance.instance;
    final started = performanceSurface == 0 ? null : perf.begin();
    try {
      _paintInk(canvas, size);
    } finally {
      perf.duration(CanvasPerfEvent.liveInkPaint, performanceSurface, started, {
        'samples': cache?.parsedSamples ?? 0,
        'recorded': cache?.recordedSegments ?? 0,
      });
      if (performanceSurface != 0) {
        perf.gauge(performanceSurface, {
          'activeSamples': cache?.parsedSamples ?? 0,
          'activeRecordedSegments': cache?.recordedSegments ?? 0,
          'activePressure': cache?.pressureMode == true ? 1 : 0,
        });
      }
    }
  }

  void _paintInk(Canvas canvas, Size size) {
    final element = stroke();
    if (element == null) return;
    final view = camera();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(view.zoom);
    canvas.translate(-view.x, -view.y);
    if (cache == null) {
      OrbitCanvasPainter.paintInk(canvas, element, Color(element.color));
    } else {
      cache!.paint(canvas, element);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CanvasLiveInkPainter oldDelegate) => true;
}

/// Only newly appended pressure segments are parsed/recorded. Keep the last
/// segment live: brush exit taper changes when the next sample arrives.
/// Source samples and the shared nib renderer remain unchanged.
class CanvasLiveInkCache {
  final _points = <CanvasPoint>[];
  final _samples = <Map>[];
  final _pictures = <_InkChunk>[];
  Object? _style;
  bool _pressure = false;
  Path? _smoothPrefix;
  int _smoothCurves = 0;
  int _recorded = 0;
  int _generation = 0;
  bool _segmented = false;
  int get recordedSegments => _recorded;
  int get parsedSamples => _samples.length;
  bool get pressureMode => _pressure;

  void paint(Canvas canvas, CanvasElement element) {
    if (!prepare(element)) {
      OrbitCanvasPainter.paintInk(canvas, element, Color(element.color));
      return;
    }
    for (final picture in _pictures) {
      canvas.drawPicture(picture.picture);
    }
    paintTail(canvas, element);
  }

  bool prepare(CanvasElement element) {
    final raw = element.data['points'];
    if (raw is! List || raw.isEmpty) return false;
    final style = (
      element.x,
      element.y,
      element.color,
      element.strokeWidth,
      element.data['penStyle'],
      element.data['isHighlighter'],
    );
    if (_style != style ||
        raw.length < _samples.length ||
        _samples.isNotEmpty &&
            (!identical(raw.first, _samples.first) ||
                !identical(raw[_samples.length - 1], _samples.last))) {
      clear();
      _style = style;
    }
    final oldPressure = _pressure;
    for (var i = _samples.length; i < raw.length; i++) {
      final sample = raw[i];
      if (sample is! Map ||
          sample['x'] is! num ||
          sample['y'] is! num ||
          !(sample['x'] as num).isFinite ||
          !(sample['y'] as num).isFinite) {
        clear();
        return false;
      }
      _samples.add(sample);
      _points.add(
        CanvasPoint(
          (sample['x'] as num).toDouble(),
          (sample['y'] as num).toDouble(),
        ),
      );
      final pressure = sample['pressure'];
      _pressure |= pressure is num && pressure.isFinite && pressure < .95;
    }
    final nib = element.data['penStyle'];
    _segmented =
        _pressure ||
        const {'fountain', 'brush', 'pencil', 'calligraphy'}.contains(nib);
    if (!_segmented) return true;
    if (oldPressure != _pressure && _pictures.isNotEmpty) {
      _generation++;
      for (final picture in _pictures) {
        picture.picture.dispose();
      }
      _pictures.clear();
      _recorded = 0;
    }
    while (_recorded + 128 < _points.length - 1) {
      final recorder = ui.PictureRecorder();
      _drawSegments(Canvas(recorder), element, _recorded, _recorded + 128);
      var left = double.infinity, top = double.infinity;
      var right = double.negativeInfinity, bottom = double.negativeInfinity;
      for (var i = _recorded; i <= _recorded + 128; i++) {
        final p = _points[i];
        left = math.min(left, p.x + element.x);
        top = math.min(top, p.y + element.y);
        right = math.max(right, p.x + element.x);
        bottom = math.max(bottom, p.y + element.y);
      }
      final padding =
          (element.data['isHighlighter'] == true
                  ? math.max(16.0, element.strokeWidth)
                  : element.strokeWidth) *
              2 +
          2;
      _pictures.add(
        _InkChunk(
          recorder.endRecording(),
          Rect.fromLTRB(left, top, right, bottom).inflate(padding),
        ),
      );
      _recorded += 128;
    }
    return true;
  }

  void paintTail(Canvas canvas, CanvasElement element) {
    if (_points.isEmpty) return;
    if (!_segmented) {
      _smoothPrefix ??= Path()
        ..moveTo(element.x + _points.first.x, element.y + _points.first.y);
      for (var i = _smoothCurves + 1; i < _points.length - 1; i++) {
        final point = _points[i], next = _points[i + 1];
        _smoothPrefix!.quadraticBezierTo(
          element.x + point.x,
          element.y + point.y,
          element.x + (point.x + next.x) / 2,
          element.y + (point.y + next.y) / 2,
        );
        _smoothCurves = i;
      }
      final path = Path.from(_smoothPrefix!)
        ..lineTo(element.x + _points.last.x, element.y + _points.last.y);
      OrbitCanvasPainter.paintInk(
        canvas,
        element,
        Color(element.color),
        inkPoints: _points,
        inkSamples: _samples,
        inkHasPressure: false,
        inkPath: path,
      );
      return;
    }
    _drawSegments(canvas, element, _recorded, null);
  }

  void _drawSegments(
    Canvas canvas,
    CanvasElement element,
    int start,
    int? end,
  ) {
    final nib = element.data['penStyle'];
    final hasPressure =
        _pressure || const {'fountain', 'brush', 'pencil'}.contains(nib);
    OrbitCanvasPainter.paintInk(
      canvas,
      element,
      Color(element.color),
      inkPoints: _points,
      inkSamples: _samples,
      inkHasPressure: hasPressure,
      startSegment: start,
      endSegment: end,
    );
  }

  void clear() {
    _generation++;
    for (final picture in _pictures) {
      picture.picture.dispose();
    }
    _pictures.clear();
    _points.clear();
    _samples.clear();
    _style = null;
    _pressure = false;
    _segmented = false;
    _recorded = 0;
    _smoothPrefix = null;
    _smoothCurves = 0;
  }

  void dispose() => clear();
}

class _InkChunk {
  _InkChunk(this.picture, this.bounds);
  final ui.Picture picture;
  final Rect bounds;
}

/// Keep the completed pressure sections in separate engine-retained layers.
/// Re-recording a single growing picture still replays all its old segments on
/// the GPU. Only the unfinished tail changes here. No source samples are lost.
class CanvasLiveInkLayer extends StatefulWidget {
  const CanvasLiveInkLayer({
    super.key,
    required this.changes,
    required this.stroke,
    required this.camera,
    required this.cache,
    this.performanceSurface = 0,
  });
  final Listenable changes;
  final CanvasElement? Function() stroke;
  final CanvasCamera Function() camera;
  final CanvasLiveInkCache cache;
  final int performanceSurface;
  @override
  State<CanvasLiveInkLayer> createState() => _CanvasLiveInkLayerState();
}

class _CanvasLiveInkLayerState extends State<CanvasLiveInkLayer> {
  Object? _layoutKey;
  final _chunks = <_InkChunk, Widget>{};
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.changes,
    builder: (context, _) {
      final perf = CanvasPerformance.instance;
      final started = widget.performanceSurface == 0 ? null : perf.begin();
      final element = widget.stroke();
      final view = widget.camera();
      final cache = widget.cache;
      final valid = element != null && cache.prepare(element);
      perf.duration(
        CanvasPerfEvent.liveInkPrepare,
        widget.performanceSurface,
        started,
      );
      if (widget.performanceSurface != 0) {
        perf.gauge(widget.performanceSurface, {
          'activeSamples': valid ? cache.parsedSamples : 0,
          'activeRecordedSegments': valid ? cache.recordedSegments : 0,
          'activePressure': valid && cache.pressureMode ? 1 : 0,
          'activeLayers': valid ? cache._pictures.length : 0,
        });
      }
      final density = MediaQuery.devicePixelRatioOf(context);
      return LayoutBuilder(
        builder: (context, constraints) {
          final layoutKey = (
            cache,
            cache._generation,
            view.x,
            view.y,
            view.zoom,
            density,
            constraints.maxWidth,
            constraints.maxHeight,
          );
          if (!valid || _layoutKey != layoutKey) {
            _chunks.clear();
            _layoutKey = valid ? layoutKey : null;
          }
          final viewport = Rect.fromLTWH(
            view.x,
            view.y,
            constraints.maxWidth / view.zoom,
            constraints.maxHeight / view.zoom,
          );
          final scale = view.zoom * density;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              if (valid)
                for (final chunk in cache._pictures)
                  if (chunk.bounds.overlaps(viewport))
                    _chunks.putIfAbsent(
                      chunk,
                      () => _chunkLayer(chunk, view, viewport, scale),
                    ),
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    willChange: true,
                    painter: _InkTailPainter(
                      element: element,
                      cache: cache,
                      camera: view,
                      valid: valid,
                      performanceSurface: widget.performanceSurface,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );

  Widget _chunkLayer(
    _InkChunk chunk,
    CanvasCamera view,
    Rect viewport,
    double scale,
  ) {
    // Limit imported/out-of-view geometry; floor/ceil on the device grid avoids
    // a second fractional translation at layer boundaries.
    final bounds = chunk.bounds.intersect(viewport.inflate(32 / view.zoom));
    final left = view.x + ((bounds.left - view.x) * scale).floor() / scale;
    final top = view.y + ((bounds.top - view.y) * scale).floor() / scale;
    final right = view.x + ((bounds.right - view.x) * scale).ceil() / scale;
    final bottom = view.y + ((bounds.bottom - view.y) * scale).ceil() / scale;
    return Positioned(
      key: ObjectKey(chunk),
      left: (left - view.x) * view.zoom,
      top: (top - view.y) * view.zoom,
      width: (right - left) * view.zoom,
      height: (bottom - top) * view.zoom,
      child: RepaintBoundary(
        child: CustomPaint(
          isComplex: true,
          painter: _InkChunkPainter(
            chunk.picture,
            CanvasCamera(x: left, y: top, zoom: view.zoom),
          ),
        ),
      ),
    );
  }
}

class _InkChunkPainter extends CustomPainter {
  _InkChunkPainter(this.picture, this.camera);
  final ui.Picture picture;
  final CanvasCamera camera;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.scale(camera.zoom);
    canvas.translate(-camera.x, -camera.y);
    canvas.drawPicture(picture);
  }

  @override
  bool shouldRepaint(_InkChunkPainter old) =>
      !identical(picture, old.picture) ||
      camera.x != old.camera.x ||
      camera.y != old.camera.y ||
      camera.zoom != old.camera.zoom;
}

class _InkTailPainter extends CustomPainter {
  _InkTailPainter({
    required this.element,
    required this.cache,
    required this.camera,
    required this.valid,
    required this.performanceSurface,
  });
  final CanvasElement? element;
  final CanvasLiveInkCache cache;
  final CanvasCamera camera;
  final bool valid;
  final int performanceSurface;
  @override
  void paint(Canvas canvas, Size size) {
    final ink = element;
    if (ink == null) return;
    final perf = CanvasPerformance.instance;
    final started = performanceSurface == 0 ? null : perf.begin();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(camera.zoom);
    canvas.translate(-camera.x, -camera.y);
    if (valid) {
      cache.paintTail(canvas, ink);
    } else {
      OrbitCanvasPainter.paintInk(canvas, ink, Color(ink.color));
    }
    perf.duration(CanvasPerfEvent.liveInkPaint, performanceSurface, started);
  }

  @override
  bool shouldRepaint(_InkTailPainter old) => true;
}
