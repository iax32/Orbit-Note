import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../canvas/geometry.dart';
import '../../canvas/scene.dart';
import 'canvas_painter.dart';

/// Repaint only the active vector stroke. Samples never rebuild the editor,
/// re-query the saved scene or invalidate its display lists.
class CanvasLiveInkPainter extends CustomPainter {
  CanvasLiveInkPainter({
    required Listenable changes,
    required this.stroke,
    required this.camera,
    this.cache,
  }) : super(repaint: changes);
  final CanvasElement? Function() stroke;
  final CanvasCamera Function() camera;
  final CanvasLiveInkCache? cache;
  @override
  void paint(Canvas canvas, Size size) {
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
  final _pictures = <ui.Picture>[];
  Object? _style;
  bool _pressure = false;
  int _recorded = 0;
  int get recordedSegments => _recorded;
  int get parsedSamples => _samples.length;

  void paint(Canvas canvas, CanvasElement element) {
    final raw = element.data['points'];
    if (raw is! List || raw.isEmpty) return;
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
        OrbitCanvasPainter.paintInk(canvas, element, Color(element.color));
        return;
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
    final segmented =
        _pressure ||
        const {'fountain', 'brush', 'pencil', 'calligraphy'}.contains(nib);
    if (!segmented) {
      OrbitCanvasPainter.paintInk(
        canvas,
        element,
        Color(element.color),
        inkPoints: _points,
        inkSamples: _samples,
      );
      return;
    }
    if (oldPressure != _pressure && _pictures.isNotEmpty) {
      for (final picture in _pictures) {
        picture.dispose();
      }
      _pictures.clear();
      _recorded = 0;
    }
    final hasPressure =
        _pressure || const {'fountain', 'brush', 'pencil'}.contains(nib);
    void draw(Canvas target, int start, int? end) =>
        OrbitCanvasPainter.paintInk(
          target,
          element,
          Color(element.color),
          inkPoints: _points,
          inkSamples: _samples,
          inkHasPressure: hasPressure,
          startSegment: start,
          endSegment: end,
        );
    while (_recorded + 128 < _points.length - 1) {
      final recorder = ui.PictureRecorder();
      draw(Canvas(recorder), _recorded, _recorded + 128);
      _pictures.add(recorder.endRecording());
      _recorded += 128;
    }
    for (final picture in _pictures) {
      canvas.drawPicture(picture);
    }
    draw(canvas, _recorded, null);
  }

  void clear() {
    for (final picture in _pictures) {
      picture.dispose();
    }
    _pictures.clear();
    _points.clear();
    _samples.clear();
    _style = null;
    _pressure = false;
    _recorded = 0;
  }

  void dispose() => clear();
}
