import 'dart:math' as math;
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../canvas/geometry.dart';
import '../../canvas/scene.dart';

class CanvasObjectReference {
  const CanvasObjectReference({
    required this.id,
    required this.title,
    required this.typeId,
    this.body = '',
  });
  final String id;
  final String title;
  final String typeId;
  final String body;
  @override
  bool operator ==(Object other) =>
      other is CanvasObjectReference &&
      other.id == id &&
      other.title == title &&
      other.typeId == typeId &&
      other.body == body;
  @override
  int get hashCode => Object.hash(id, title, typeId, body);
}

class CanvasTextCache {
  final LinkedHashMap<Object, TextPainter> _entries = LinkedHashMap();
  TextPainter layout(
    String text,
    TextStyle style,
    double width,
    int? maxLines,
  ) {
    final key = (text, style, width, maxLines);
    final cached = _entries.remove(key);
    if (cached != null) {
      _entries[key] = cached;
      return cached;
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '…',
    )..layout(maxWidth: width);
    _entries[key] = painter;
    while (_entries.length > 256) {
      _entries.remove(_entries.keys.first)?.dispose();
    }
    return painter;
  }

  void dispose() {
    for (final painter in _entries.values) {
      painter.dispose();
    }
    _entries.clear();
  }
}

class OrbitCanvasPainter extends CustomPainter {
  OrbitCanvasPainter({
    required this.scene,
    required this.camera,
    required this.selection,
    required this.objects,
    required this.colors,
    this.region,
    this.preview,
    this.editingId,
    this.images = const {},
    required this.textCache,
  }) : sceneRevision = scene.revision;
  final CanvasTextCache textCache;
  final int sceneRevision;
  final CanvasScene scene;
  final CanvasCamera camera;
  final Set<String> selection;
  final Map<String, CanvasObjectReference> objects;
  final ColorScheme colors;
  final CanvasBounds? region;
  final CanvasElement? preview;
  final String? editingId;
  final Map<String, ui.Image> images;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(colors.surface, BlendMode.src);
    _grid(canvas, size);
    canvas.save();
    canvas.scale(camera.zoom);
    canvas.translate(-camera.x, -camera.y);
    final visible = scene.query(
      camera.viewport(size.width, size.height).inflate(80 / camera.zoom),
    );
    for (final element in visible) {
      _element(canvas, element);
    }
    if (preview != null) _element(canvas, preview!);
    final selectionPaint = Paint()
      ..color = colors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / camera.zoom;
    for (final id in selection) {
      final element = scene[id];
      if (element == null || element.hidden) continue;
      final bounds = _rect(element.bounds.inflate(4 / camera.zoom));
      canvas.drawRRect(
        RRect.fromRectAndRadius(bounds, Radius.circular(8 / camera.zoom)),
        selectionPaint,
      );
      if (selection.length == 1 && element.type != 'ink') {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: bounds.bottomRight,
              width: 9 / camera.zoom,
              height: 9 / camera.zoom,
            ),
            Radius.circular(2 / camera.zoom),
          ),
          Paint()..color = colors.primary,
        );
      }
    }
    if (region != null) {
      canvas.drawRect(
        _rect(region!),
        Paint()..color = colors.primary.withValues(alpha: .08),
      );
      canvas.drawRect(_rect(region!), selectionPaint);
    }
    canvas.restore();
  }

  void _grid(Canvas canvas, Size size) {
    var step = 24 * camera.zoom;
    while (step < 15) {
      step *= 4;
    }
    final origin = camera.toScreen(const CanvasPoint(0, 0));
    final paint = Paint()..color = colors.onSurface.withValues(alpha: .11);
    for (var x = origin.x % step; x < size.width; x += step) {
      for (var y = origin.y % step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), .75, paint);
      }
    }
  }

  void _element(Canvas canvas, CanvasElement element) {
    if (!element.renderable || element.id == editingId) return;
    final bounds = _rect(element.bounds);
    final accent = Color(element.color);
    final stroke = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = element.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (element.type) {
      case 'image':
        final image = images[element.data['contentRef']];
        final destination = Rect.fromLTWH(
          element.x,
          element.y,
          element.width,
          element.height,
        );
        if (image != null) {
          paintImage(
            canvas: canvas,
            rect: destination,
            image: image,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          );
        } else {
          canvas.drawRRect(
            RRect.fromRectAndRadius(destination, const Radius.circular(10)),
            Paint()..color = colors.surfaceContainerHigh,
          );
        }
      case 'ink':
        final points = element.points;
        if (points.isEmpty) return;
        if (points.length == 1) {
          canvas.drawCircle(
            Offset(element.x + points.first.x, element.y + points.first.y),
            element.strokeWidth / 2,
            Paint()..color = accent,
          );
          return;
        }
        final path = Path()
          ..moveTo(element.x + points.first.x, element.y + points.first.y);
        for (final point in points.skip(1)) {
          path.lineTo(element.x + point.x, element.y + point.y);
        }
        canvas.drawPath(path, stroke);
      case 'arrow':
      case 'line':
        final start = Offset(
          element.data['reverseX'] == true ? bounds.right : bounds.left,
          element.data['reverseY'] == true ? bounds.bottom : bounds.top,
        );
        final end = Offset(
          element.data['reverseX'] == true ? bounds.left : bounds.right,
          element.data['reverseY'] == true ? bounds.top : bounds.bottom,
        );
        canvas.drawLine(start, end, stroke);
        if (element.type == 'arrow') {
          final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
          final head = math.min(16.0, (end - start).distance / 3);
          canvas.drawPath(
            Path()
              ..moveTo(
                end.dx - math.cos(angle - .48) * head,
                end.dy - math.sin(angle - .48) * head,
              )
              ..lineTo(end.dx, end.dy)
              ..lineTo(
                end.dx - math.cos(angle + .48) * head,
                end.dy - math.sin(angle + .48) * head,
              ),
            stroke,
          );
        }
      case 'rectangle':
      case 'ellipse':
      case 'diamond':
      case 'frame':
        final fill = Paint()
          ..color = accent.withValues(
            alpha: element.type == 'frame' ? .035 : .08,
          );
        if (element.type == 'ellipse') {
          canvas.drawOval(bounds, fill);
          canvas.drawOval(bounds, stroke);
        } else if (element.type == 'diamond') {
          final path = Path()
            ..moveTo(bounds.center.dx, bounds.top)
            ..lineTo(bounds.right, bounds.center.dy)
            ..lineTo(bounds.center.dx, bounds.bottom)
            ..lineTo(bounds.left, bounds.center.dy)
            ..close();
          canvas.drawPath(path, fill);
          canvas.drawPath(path, stroke);
        } else {
          final rect = RRect.fromRectAndRadius(
            bounds,
            const Radius.circular(10),
          );
          canvas.drawRRect(rect, fill);
          canvas.drawRRect(rect, stroke);
        }
        if (element.text.isNotEmpty && camera.zoom > .3) {
          _text(
            canvas,
            element.text,
            bounds.deflate(14),
            color: colors.onSurface,
            size: 15,
          );
        }
      case 'text':
        if (camera.zoom < .2) return;
        _text(
          canvas,
          element.text,
          bounds.deflate(6),
          color: colors.onSurface,
          size: 18,
        );
      case 'sticky':
        canvas.drawRRect(
          RRect.fromRectAndRadius(bounds, const Radius.circular(5)),
          Paint()
            ..color = Color.alphaBlend(
              accent.withValues(alpha: .23),
              colors.surfaceContainerHigh,
            ),
        );
        canvas.drawRect(
          Rect.fromLTWH(bounds.left, bounds.top, bounds.width, 5),
          Paint()..color = accent.withValues(alpha: .5),
        );
        if (camera.zoom > .25) {
          _text(
            canvas,
            element.text,
            bounds.deflate(16),
            color: colors.onSurface,
            size: 17,
          );
        }
      case 'card':
        final object = objects[element.objectId];
        final card = RRect.fromRectAndRadius(bounds, const Radius.circular(12));
        canvas.drawRRect(card, Paint()..color = colors.surfaceContainerHigh);
        canvas.drawRRect(
          card,
          Paint()
            ..color = colors.outlineVariant.withValues(alpha: .55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(bounds.left + 16, bounds.top + 16, 5, 18),
            const Radius.circular(2),
          ),
          Paint()..color = object == null ? colors.error : accent,
        );
        if (camera.zoom > .25) {
          _text(
            canvas,
            (object?.typeId ?? 'Unresolved reference').toUpperCase(),
            Rect.fromLTWH(
              bounds.left + 30,
              bounds.top + 18,
              math.max(1, bounds.width - 46),
              18,
            ),
            color: colors.onSurfaceVariant,
            size: 10,
            maxLines: 1,
          );
          _text(
            canvas,
            object?.title ?? 'Missing object',
            Rect.fromLTWH(
              bounds.left + 16,
              bounds.top + 48,
              math.max(1, bounds.width - 32),
              48,
            ),
            color: colors.onSurface,
            size: 17,
            weight: FontWeight.w600,
            maxLines: 2,
          );
          if (camera.zoom > .6 && bounds.height > 115) {
            _text(
              canvas,
              object?.body.replaceAll(RegExp(r'[#*`\[\]]'), '') ??
                  element.objectId ??
                  '',
              Rect.fromLTWH(
                bounds.left + 16,
                bounds.top + 103,
                math.max(1, bounds.width - 32),
                math.max(1, bounds.height - 119),
              ),
              color: colors.onSurfaceVariant,
              size: 12,
              maxLines: 4,
            );
          }
        }
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Rect bounds, {
    required Color color,
    required double size,
    int? maxLines,
    FontWeight? weight,
  }) {
    if (bounds.width <= 0 || bounds.height <= 0) return;
    final painter = textCache.layout(
      text,
      TextStyle(
        fontFamily: 'Segoe UI',
        color: color,
        fontSize: size,
        height: 1.4,
        fontWeight: weight,
      ),
      bounds.width,
      maxLines,
    );
    canvas.save();
    canvas.clipRect(bounds);
    painter.paint(canvas, bounds.topLeft);
    canvas.restore();
  }

  Rect _rect(CanvasBounds bounds) =>
      Rect.fromLTWH(bounds.left, bounds.top, bounds.width, bounds.height);
  @override
  bool shouldRepaint(covariant OrbitCanvasPainter oldDelegate) =>
      !identical(scene, oldDelegate.scene) ||
      sceneRevision != oldDelegate.sceneRevision ||
      camera.x != oldDelegate.camera.x ||
      camera.y != oldDelegate.camera.y ||
      camera.zoom != oldDelegate.camera.zoom ||
      !setEquals(selection, oldDelegate.selection) ||
      !mapEquals(objects, oldDelegate.objects) ||
      !mapEquals(images, oldDelegate.images) ||
      colors != oldDelegate.colors ||
      region != oldDelegate.region ||
      preview != oldDelegate.preview ||
      editingId != oldDelegate.editingId;
}
