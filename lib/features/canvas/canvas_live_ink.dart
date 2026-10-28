import 'package:flutter/material.dart';
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
  }) : super(repaint: changes);
  final CanvasElement? Function() stroke;
  final CanvasCamera Function() camera;
  @override
  void paint(Canvas canvas, Size size) {
    final element = stroke();
    if (element == null) return;
    final view = camera();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(view.zoom);
    canvas.translate(-view.x, -view.y);
    OrbitCanvasPainter.paintInk(canvas, element, Color(element.color));
    canvas.restore();
  }

  @override
  bool shouldRepaint(CanvasLiveInkPainter oldDelegate) => true;
}
