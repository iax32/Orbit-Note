import 'dart:math' as math;
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../canvas/geometry.dart';
import '../../canvas/scene.dart';
import '../../canvas/connectors.dart';
import '../../canvas/groups.dart';
import 'canvas_rich_text.dart';

class CanvasObjectReference {
  const CanvasObjectReference({
    required this.id,
    required this.title,
    required this.typeId,
    this.body = '',
    this.properties = const {},
  });
  final String id;
  final String title;
  final String typeId;
  final String body;
  final Map<String, dynamic> properties;
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
    this.guides = const [],
    this.images = const {},
    this.backgroundStyle = 'dots',
    this.hoveredAnchorElementId,
    this.connectingStartElementId,
    required this.textCache,
    this.exportElementIds,
    this.transparentBackground = false,
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
  final List<CanvasGuideLine> guides;
  final Map<String, ui.Image> images;
  final String backgroundStyle;
  final String? hoveredAnchorElementId;
  final String? connectingStartElementId;
  final Set<String>? exportElementIds;
  final bool transparentBackground;

  @override
  void paint(Canvas canvas, Size size) {
    if (!transparentBackground) {
      canvas.drawColor(colors.surface, BlendMode.src);
      _grid(canvas, size);
    }
    canvas.save();
    canvas.scale(camera.zoom);
    canvas.translate(-camera.x, -camera.y);
    final visible = exportElementIds != null
        ? scene.elements.where((e) => exportElementIds!.contains(e.id))
        : scene.query(
            camera.viewport(size.width, size.height).inflate(80 / camera.zoom),
          );
    for (final element in visible.where((e) => e.type == 'column')) {
      _element(canvas, element);
    }
    for (final element in visible.where((e) => e.type != 'column')) {
      _element(canvas, element);
    }
    if (preview != null) _element(canvas, preview!);
    if (exportElementIds == null) {
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
        if (element.locked) {
          _text(
            canvas,
            '🔒',
            Rect.fromLTWH(
              bounds.right - 18 / camera.zoom,
              bounds.top - 18 / camera.zoom,
              18 / camera.zoom,
              18 / camera.zoom,
            ),
            color: colors.primary,
            size: 12 / camera.zoom,
          );
        }
        if (selection.length == 1 &&
            isConnectorElement(element) &&
            !element.locked) {
          final endpoints = resolveConnectorEndpoints(element, scene);
          for (final point in [endpoints.start, endpoints.end]) {
            canvas.drawCircle(
              Offset(point.x, point.y),
              5 / camera.zoom,
              Paint()..color = colors.primary,
            );
            canvas.drawCircle(
              Offset(point.x, point.y),
              5 / camera.zoom,
              Paint()
                ..color = colors.onSurface
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1 / camera.zoom,
            );
          }
        } else if (selection.length == 1 && element.type != 'ink') {
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
      final selectedGroupIds = selection
          .map((id) => scene[id]?.groupId)
          .whereType<String>()
          .toSet();
      for (final gid in selectedGroupIds) {
        final gBounds = calculateGroupBounds(scene, gid);
        if (gBounds != null) {
          final groupRect = _rect(gBounds.inflate(8 / camera.zoom));
          final groupPaint = Paint()
            ..color = colors.primary.withValues(alpha: 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2 / camera.zoom;
          _drawDashedRect(canvas, groupRect, groupPaint, camera.zoom);

          final badgeWidth = 46.0 / camera.zoom;
          final badgeHeight = 15.0 / camera.zoom;
          final badgeRect = Rect.fromLTWH(
            groupRect.left,
            groupRect.top - badgeHeight - 2 / camera.zoom,
            badgeWidth,
            badgeHeight,
          );
          final badgeBg = Paint()
            ..color = colors.primary.withValues(alpha: 0.16)
            ..style = PaintingStyle.fill;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              badgeRect,
              Radius.circular(3 / camera.zoom),
            ),
            badgeBg,
          );
          _text(
            canvas,
            'GROUP',
            badgeRect,
            color: colors.primary,
            size: 9 / camera.zoom,
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
      if (guides.isNotEmpty) {
        final guidePaint = Paint()
          ..color = colors.primary.withValues(alpha: .75)
          ..strokeWidth = 1.0 / camera.zoom
          ..style = PaintingStyle.stroke;
        final vp = camera.viewport(size.width, size.height);
        for (final guide in guides) {
          if (guide.isVertical) {
            _drawDashedLine(
              canvas,
              Offset(guide.position, vp.top),
              Offset(guide.position, vp.bottom),
              guidePaint,
              dashLength: 5.0 / camera.zoom,
              gapLength: 4.0 / camera.zoom,
            );
          } else {
            _drawDashedLine(
              canvas,
              Offset(vp.left, guide.position),
              Offset(vp.right, guide.position),
              guidePaint,
              dashLength: 5.0 / camera.zoom,
              gapLength: 4.0 / camera.zoom,
            );
          }
        }
      }
      final anchorTargetIds = {
        hoveredAnchorElementId,
        connectingStartElementId,
      }.whereType<String>();
      if (anchorTargetIds.isNotEmpty) {
        final dotPaint = Paint()
          ..color = colors.primary
          ..style = PaintingStyle.fill;
        final ringPaint = Paint()
          ..color = colors.surface
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / camera.zoom;
        for (final elemId in anchorTargetIds) {
          final elem = scene[elemId];
          if (elem != null) {
            final anchors = getElementAnchors(elem.bounds);
            for (final anchor in anchors.values) {
              canvas.drawCircle(
                Offset(anchor.x, anchor.y),
                5.0 / camera.zoom,
                ringPaint,
              );
              canvas.drawCircle(
                Offset(anchor.x, anchor.y),
                3.5 / camera.zoom,
                dotPaint,
              );
            }
          }
        }
      }
    }
    canvas.restore();
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Paint paint, {
    required double dashLength,
    required double gapLength,
  }) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance == 0) return;
    final nx = dx / distance;
    final ny = dy / distance;
    var current = 0.0;
    while (current < distance) {
      final next = math.min(current + dashLength, distance);
      canvas.drawLine(
        Offset(p1.dx + nx * current, p1.dy + ny * current),
        Offset(p1.dx + nx * next, p1.dy + ny * next),
        paint,
      );
      current = next + gapLength;
    }
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint, double zoom) {
    final dash = 6.0 / zoom;
    final gap = 4.0 / zoom;
    _drawDashedLine(
      canvas,
      rect.topLeft,
      rect.topRight,
      paint,
      dashLength: dash,
      gapLength: gap,
    );
    _drawDashedLine(
      canvas,
      rect.topRight,
      rect.bottomRight,
      paint,
      dashLength: dash,
      gapLength: gap,
    );
    _drawDashedLine(
      canvas,
      rect.bottomRight,
      rect.bottomLeft,
      paint,
      dashLength: dash,
      gapLength: gap,
    );
    _drawDashedLine(
      canvas,
      rect.bottomLeft,
      rect.topLeft,
      paint,
      dashLength: dash,
      gapLength: gap,
    );
  }

  void _grid(Canvas canvas, Size size) {
    if (backgroundStyle == 'blank') return;

    var step = 24 * camera.zoom;
    while (step < 15) {
      step *= 4;
    }
    final origin = camera.toScreen(const CanvasPoint(0, 0));

    if (backgroundStyle == 'grid') {
      final linePaint = Paint()
        ..color = colors.onSurface.withValues(alpha: .08)
        ..strokeWidth = 1.0;
      for (var x = origin.x % step; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
      }
      for (var y = origin.y % step; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
    } else if (backgroundStyle == 'graph') {
      // Engineering / Math graph paper: minor grid + prominent major grid
      var minorStep = 8.0 * camera.zoom;
      while (minorStep < 6.0) {
        minorStep *= 4.0;
      }
      final majorStep = minorStep * 4.0;
      final minorPaint = Paint()
        ..color = colors.onSurface.withValues(alpha: .045)
        ..strokeWidth = 0.75;
      final majorPaint = Paint()
        ..color = colors.onSurface.withValues(alpha: .15)
        ..strokeWidth = 1.25;

      for (var x = origin.x % minorStep; x < size.width; x += minorStep) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), minorPaint);
      }
      for (var y = origin.y % minorStep; y < size.height; y += minorStep) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), minorPaint);
      }
      for (var x = origin.x % majorStep; x < size.width; x += majorStep) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), majorPaint);
      }
      for (var y = origin.y % majorStep; y < size.height; y += majorStep) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), majorPaint);
      }
    } else if (backgroundStyle == 'cornell') {
      // Cornell Notes layout: Ruled lines + Left Cue divider + Bottom Summary divider
      final rulePaint = Paint()
        ..color = colors.onSurface.withValues(alpha: .09)
        ..strokeWidth = 1.0;
      for (var y = origin.y % step; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), rulePaint);
      }

      final cueScreenX = camera.toScreen(const CanvasPoint(200, 0)).x;
      final dividerPaint = Paint()
        ..color = colors.primary.withValues(alpha: .38)
        ..strokeWidth = 1.75;
      if (cueScreenX >= 0 && cueScreenX <= size.width) {
        canvas.drawLine(
          Offset(cueScreenX, 0),
          Offset(cueScreenX, size.height),
          dividerPaint,
        );
      }

      final summaryScreenY = camera.toScreen(const CanvasPoint(0, 700)).y;
      if (summaryScreenY >= 0 && summaryScreenY <= size.height) {
        canvas.drawLine(
          Offset(0, summaryScreenY),
          Offset(size.width, summaryScreenY),
          dividerPaint,
        );
      }

      if (camera.zoom > 0.35) {
        final labelColor = colors.primary.withValues(alpha: .60);
        if (cueScreenX > 60 && cueScreenX <= size.width + 100) {
          _text(
            canvas,
            'CUES / QUESTIONS',
            Rect.fromLTWH(
              math.max(12, cueScreenX - 160),
              math.max(12, origin.y + 12),
              150,
              20,
            ),
            color: labelColor,
            size: 10,
            weight: FontWeight.w700,
          );
        }
        if (cueScreenX + 16 < size.width) {
          _text(
            canvas,
            'NOTES',
            Rect.fromLTWH(
              math.max(12, cueScreenX + 16),
              math.max(12, origin.y + 12),
              100,
              20,
            ),
            color: labelColor,
            size: 10,
            weight: FontWeight.w700,
          );
        }
        if (summaryScreenY >= 0 && summaryScreenY + 8 < size.height) {
          _text(
            canvas,
            'SUMMARY',
            Rect.fromLTWH(
              math.max(12, origin.x + 12),
              summaryScreenY + 8,
              120,
              20,
            ),
            color: labelColor,
            size: 10,
            weight: FontWeight.w700,
          );
        }
      }
    } else if (backgroundStyle == 'lines') {
      final linePaint = Paint()
        ..color = colors.onSurface.withValues(alpha: .09)
        ..strokeWidth = 1.0;
      for (var y = origin.y % step; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
    } else {
      // 'dots' (default)
      final paint = Paint()..color = colors.onSurface.withValues(alpha: .11);
      for (var x = origin.x % step; x < size.width; x += step) {
        for (var y = origin.y % step; y < size.height; y += step) {
          canvas.drawCircle(Offset(x, y), .75, paint);
        }
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
      case 'column':
        canvas.drawRRect(
          RRect.fromRectAndRadius(bounds, const Radius.circular(12)),
          Paint()..color = colors.surfaceContainerLow,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(bounds, const Radius.circular(12)),
          Paint()
            ..color = colors.outline
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        canvas.drawLine(
          Offset(bounds.left + 16, bounds.top + 42),
          Offset(bounds.right - 16, bounds.top + 42),
          Paint()
            ..color = accent.withValues(alpha: .45)
            ..strokeWidth = 2,
        );
        if (camera.zoom > .25) {
          _text(
            canvas,
            element.text,
            Rect.fromLTWH(
              bounds.left + 16,
              bounds.top + 12,
              math.max(1, bounds.width - 32),
              26,
            ),
            color: colors.onSurface,
            size: 15,
            weight: FontWeight.w600,
            maxLines: 1,
          );
        }
      case 'link':
        canvas.drawRRect(
          RRect.fromRectAndRadius(bounds, const Radius.circular(12)),
          Paint()..color = colors.surfaceContainerHigh,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(bounds, const Radius.circular(12)),
          Paint()
            ..color = colors.outline
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        if (camera.zoom > .25) {
          _text(
            canvas,
            'WEBSITE ↗',
            Rect.fromLTWH(
              bounds.left + 16,
              bounds.top + 14,
              math.max(1, bounds.width - 32),
              20,
            ),
            color: accent,
            size: 10,
          );
          _text(
            canvas,
            element.text,
            Rect.fromLTWH(
              bounds.left + 16,
              bounds.top + 40,
              math.max(1, bounds.width - 32),
              44,
            ),
            color: colors.onSurface,
            size: 16,
            weight: FontWeight.w600,
            maxLines: 2,
          );
          _text(
            canvas,
            element.url,
            Rect.fromLTWH(
              bounds.left + 16,
              bounds.top + 92,
              math.max(1, bounds.width - 32),
              22,
            ),
            color: colors.onSurfaceVariant,
            size: 11,
            maxLines: 1,
          );
        }
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
        final isHighlighter = element.data['isHighlighter'] == true;
        final inkWidth = isHighlighter
            ? math.max(16.0, element.strokeWidth)
            : element.strokeWidth;
        final inkColor = isHighlighter
            ? accent.withValues(alpha: 0.38)
            : accent;
        final inkStroke = Paint()
          ..color = inkColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = inkWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        final points = element.points;
        if (points.isEmpty) return;
        if (points.length == 1) {
          canvas.drawCircle(
            Offset(element.x + points.first.x, element.y + points.first.y),
            inkWidth / 2,
            Paint()..color = inkColor,
          );
          return;
        }
        final path = Path()
          ..moveTo(element.x + points.first.x, element.y + points.first.y);
        for (final point in points.skip(1)) {
          path.lineTo(element.x + point.x, element.y + point.y);
        }
        canvas.drawPath(path, inkStroke);
      case 'connector':
      case 'arrow':
      case 'line':
        final endpoints = resolveConnectorEndpoints(element, scene);
        final start = Offset(endpoints.start.x, endpoints.start.y);
        final end = Offset(endpoints.end.x, endpoints.end.y);
        final routing = ConnectorRouting.parse(element.routing);
        final style = ConnectorStyle.parse(element.strokeStyle);
        final startMarker = ConnectorMarker.parse(element.startMarker);
        final endMarker = ConnectorMarker.parse(
          element.endMarker,
          defaultMarker: (element.type == 'arrow' || element.type == 'connector'
              ? ConnectorMarker.arrow
              : ConnectorMarker.none),
        );

        final path = Path();
        path.moveTo(start.dx, start.dy);
        if (routing == ConnectorRouting.curved &&
            endpoints.controlPoints.length >= 2) {
          final cp1 = Offset(
            endpoints.controlPoints[0].x,
            endpoints.controlPoints[0].y,
          );
          final cp2 = Offset(
            endpoints.controlPoints[1].x,
            endpoints.controlPoints[1].y,
          );
          path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);
        } else if (routing == ConnectorRouting.orthogonal &&
            endpoints.controlPoints.isNotEmpty) {
          for (final cp in endpoints.controlPoints) {
            path.lineTo(cp.x, cp.y);
          }
          path.lineTo(end.dx, end.dy);
        } else {
          path.lineTo(end.dx, end.dy);
        }

        if (style == ConnectorStyle.solid) {
          canvas.drawPath(path, stroke);
        } else {
          final isDashed = style == ConnectorStyle.dashed;
          final dashLen = isDashed ? 8.0 : 1.0;
          final gapLen = isDashed
              ? 5.0
              : math.max(6.0, stroke.strokeWidth * 2.5);
          for (final metric in path.computeMetrics()) {
            var distance = 0.0;
            while (distance < metric.length) {
              final next = math.min(distance + dashLen, metric.length);
              final extract = metric.extractPath(distance, next);
              canvas.drawPath(extract, stroke);
              distance = next + gapLen;
            }
          }
        }

        // Start marker
        if (startMarker != ConnectorMarker.none) {
          final firstTarget = endpoints.controlPoints.isNotEmpty
              ? Offset(
                  endpoints.controlPoints.first.x,
                  endpoints.controlPoints.first.y,
                )
              : end;
          final startAngle = math.atan2(
            start.dy - firstTarget.dy,
            start.dx - firstTarget.dx,
          );
          if (startMarker == ConnectorMarker.arrow) {
            final head = math.min(16.0, (firstTarget - start).distance / 3);
            canvas.drawPath(
              Path()
                ..moveTo(
                  start.dx - math.cos(startAngle - 0.48) * head,
                  start.dy - math.sin(startAngle - 0.48) * head,
                )
                ..lineTo(start.dx, start.dy)
                ..lineTo(
                  start.dx - math.cos(startAngle + 0.48) * head,
                  start.dy - math.sin(startAngle + 0.48) * head,
                ),
              stroke,
            );
          } else if (startMarker == ConnectorMarker.dot) {
            canvas.drawCircle(
              start,
              math.max(3.0, stroke.strokeWidth * 1.5 + 2),
              Paint()..color = stroke.color,
            );
          } else if (startMarker == ConnectorMarker.diamond) {
            final dSize = math.max(6.0, stroke.strokeWidth * 2.5 + 4);
            final dPath = Path()
              ..moveTo(
                start.dx - math.cos(startAngle) * dSize,
                start.dy - math.sin(startAngle) * dSize,
              )
              ..lineTo(
                start.dx - math.cos(startAngle + math.pi / 2) * (dSize * 0.55),
                start.dy - math.sin(startAngle + math.pi / 2) * (dSize * 0.55),
              )
              ..lineTo(start.dx, start.dy)
              ..lineTo(
                start.dx - math.cos(startAngle - math.pi / 2) * (dSize * 0.55),
                start.dy - math.sin(startAngle - math.pi / 2) * (dSize * 0.55),
              )
              ..close();
            canvas.drawPath(dPath, Paint()..color = stroke.color);
          }
        }

        // End marker
        if (endMarker != ConnectorMarker.none) {
          final lastTarget = endpoints.controlPoints.isNotEmpty
              ? Offset(
                  endpoints.controlPoints.last.x,
                  endpoints.controlPoints.last.y,
                )
              : start;
          final endAngle = math.atan2(
            end.dy - lastTarget.dy,
            end.dx - lastTarget.dx,
          );
          if (endMarker == ConnectorMarker.arrow) {
            final head = math.min(16.0, (end - lastTarget).distance / 3);
            canvas.drawPath(
              Path()
                ..moveTo(
                  end.dx - math.cos(endAngle - 0.48) * head,
                  end.dy - math.sin(endAngle - 0.48) * head,
                )
                ..lineTo(end.dx, end.dy)
                ..lineTo(
                  end.dx - math.cos(endAngle + 0.48) * head,
                  end.dy - math.sin(endAngle + 0.48) * head,
                ),
              stroke,
            );
          } else if (endMarker == ConnectorMarker.dot) {
            canvas.drawCircle(
              end,
              math.max(3.0, stroke.strokeWidth * 1.5 + 2),
              Paint()..color = stroke.color,
            );
          } else if (endMarker == ConnectorMarker.diamond) {
            final dSize = math.max(6.0, stroke.strokeWidth * 2.5 + 4);
            final dPath = Path()
              ..moveTo(
                end.dx - math.cos(endAngle) * dSize,
                end.dy - math.sin(endAngle) * dSize,
              )
              ..lineTo(
                end.dx - math.cos(endAngle + math.pi / 2) * (dSize * 0.55),
                end.dy - math.sin(endAngle + math.pi / 2) * (dSize * 0.55),
              )
              ..lineTo(end.dx, end.dy)
              ..lineTo(
                end.dx - math.cos(endAngle - math.pi / 2) * (dSize * 0.55),
                end.dy - math.sin(endAngle - math.pi / 2) * (dSize * 0.55),
              )
              ..close();
            canvas.drawPath(dPath, Paint()..color = stroke.color);
          }
        }

        // Label pill
        if (element.text.trim().isNotEmpty && element.id != editingId) {
          final mid = Offset(endpoints.midpoint.x, endpoints.midpoint.y);
          final tp = textCache.layout(
            element.text.trim(),
            TextStyle(
              color: stroke.color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            200,
            2,
          );
          const padH = 6.0;
          const padV = 3.0;
          final pillRect = Rect.fromCenter(
            center: mid,
            width: tp.width + padH * 2,
            height: tp.height + padV * 2,
          );
          final rrect = RRect.fromRectAndRadius(
            pillRect,
            const Radius.circular(5),
          );
          canvas.drawRRect(rrect, Paint()..color = colors.surface);
          canvas.drawRRect(
            rrect,
            Paint()
              ..color = accent.withValues(alpha: 0.35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0,
          );
          tp.paint(
            canvas,
            Offset(mid.dx - tp.width / 2, mid.dy - tp.height / 2),
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
        if (CanvasRichText.hasRichFormatting(element.text)) {
          CanvasRichText.draw(
            canvas: canvas,
            text: element.text,
            bounds: bounds.deflate(6),
            accent: accent,
            colors: colors,
            textCache: textCache,
            defaultFontSize: 17.0,
          );
        } else {
          _text(
            canvas,
            element.text,
            bounds.deflate(6),
            color: colors.onSurface,
            size: 18,
          );
        }
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
          CanvasRichText.draw(
            canvas: canvas,
            text: element.text,
            bounds: bounds.deflate(16),
            accent: accent,
            colors: colors,
            textCache: textCache,
            defaultFontSize: 16.0,
          );
        }
      case 'card':
        final hasObjectId =
            element.objectId != null && element.objectId!.isNotEmpty;
        final object = hasObjectId ? objects[element.objectId] : null;
        final hasText = element.text.trim().isNotEmpty;
        final isStandalone = !hasObjectId;
        final isUnresolved = hasObjectId && object == null && !hasText;

        final isCanvas = object?.typeId == 'orbit.canvas';
        final pdfSource = object?.properties['pdfSource'] is Map
            ? object!.properties['pdfSource'] as Map
            : null;
        Color stripColor = isUnresolved ? colors.error : accent;

        String typeLabel;
        String titleText;
        String bodyText;

        if (object != null) {
          if (pdfSource != null) {
            final page = pdfSource['page'] is int
                ? pdfSource['page'] as int
                : 1;
            final quote = pdfSource['quote'] is String
                ? (pdfSource['quote'] as String).trim()
                : '';
            final highlightColor = pdfSource['color'] is int
                ? Color(pdfSource['color'] as int)
                : accent;
            typeLabel = 'PDF HIGHLIGHT · P. $page';
            stripColor = highlightColor;
            titleText = object.title.isNotEmpty
                ? object.title
                : (quote.isNotEmpty ? quote : 'PDF Highlight');
            final comment = object.body
                .replaceAll(RegExp(r'[#*`\[\]]'), '')
                .trim();
            if (quote.isNotEmpty) {
              bodyText = comment.isNotEmpty && comment != quote
                  ? '“$quote”\n\n$comment'
                  : '“$quote”';
            } else {
              bodyText = comment;
            }
          } else if (object.typeId == 'orbit.file') {
            final isPdf = object.title.toLowerCase().endsWith('.pdf');
            typeLabel = isPdf ? 'PDF DOCUMENT' : 'ATTACHMENT';
            titleText = object.title.isEmpty ? 'Untitled File' : object.title;
            bodyText = object.body.replaceAll(RegExp(r'[#*`\[\]]'), '').trim();
          } else if (object.typeId == 'orbit.task') {
            final isDone = object.properties['status'] == 'done';
            typeLabel = isDone ? 'TASK (DONE)' : 'TASK';
            titleText = object.title.isEmpty ? 'Untitled Task' : object.title;
            bodyText = object.body.replaceAll(RegExp(r'[#*`\[\]]'), '').trim();
          } else {
            typeLabel = isCanvas
                ? 'CANVAS BOARD'
                : object.typeId.replaceFirst('orbit.', '').toUpperCase();
            titleText = object.title.isEmpty ? 'Untitled' : object.title;
            bodyText = object.body.replaceAll(RegExp(r'[#*`\[\]]'), '').trim();
          }
        } else if (hasText) {
          typeLabel = 'CARD';
          final lines = element.text.trim().split('\n');
          titleText = lines.first.trim();
          bodyText = lines.length > 1 ? lines.skip(1).join('\n').trim() : '';
        } else if (isStandalone) {
          typeLabel = 'CARD';
          titleText = 'Card';
          bodyText = '';
        } else {
          typeLabel = 'UNRESOLVED REFERENCE';
          titleText = 'Missing object';
          bodyText = element.objectId ?? '';
        }

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
          Paint()..color = stripColor,
        );
        _text(
          canvas,
          typeLabel,
          Rect.fromLTWH(
            bounds.left + 30,
            bounds.top + 18,
            math.max(1, bounds.width - 46),
            18,
          ),
          color: (isCanvas || pdfSource != null)
              ? stripColor
              : (isUnresolved ? colors.error : colors.onSurfaceVariant),
          size: 10,
          weight: FontWeight.w600,
          maxLines: 1,
        );

        final isCompact = bounds.height <= 95;
        if (isCompact) {
          _text(
            canvas,
            titleText,
            Rect.fromLTWH(
              bounds.left + 16,
              bounds.top + 38,
              math.max(1, bounds.width - 32),
              20,
            ),
            color: colors.onSurface,
            size: 14,
            weight: FontWeight.w600,
            maxLines: 1,
          );
          if (bodyText.isNotEmpty && bounds.height >= 60) {
            _text(
              canvas,
              bodyText,
              Rect.fromLTWH(
                bounds.left + 16,
                bounds.top + 58,
                math.max(1, bounds.width - 32),
                math.max(1, bounds.height - 62),
              ),
              color: colors.onSurfaceVariant,
              size: 11,
              maxLines: 1,
            );
          }
        } else {
          _text(
            canvas,
            titleText,
            Rect.fromLTWH(
              bounds.left + 16,
              bounds.top + 46,
              math.max(1, bounds.width - 32),
              48,
            ),
            color: colors.onSurface,
            size: 16,
            weight: FontWeight.w600,
            maxLines: 2,
          );
          if (camera.zoom > .5 && bounds.height > 105 && bodyText.isNotEmpty) {
            final cardBodyRect = Rect.fromLTWH(
              bounds.left + 16,
              bounds.top + 98,
              math.max(1, bounds.width - 32),
              math.max(1, bounds.height - 110),
            );
            if (CanvasRichText.hasRichFormatting(bodyText)) {
              CanvasRichText.draw(
                canvas: canvas,
                text: bodyText,
                bounds: cardBodyRect,
                accent: accent,
                colors: colors,
                textCache: textCache,
                defaultFontSize: 12.0,
                maxLines: 4,
              );
            } else {
              _text(
                canvas,
                bodyText,
                cardBodyRect,
                color: colors.onSurfaceVariant,
                size: 12,
                maxLines: 4,
              );
            }
          }
        }
      case 'section':
        if (camera.zoom > .2) {
          final title = element.text.isEmpty
              ? 'SECTION'
              : element.text.toUpperCase();
          _text(
            canvas,
            title,
            Rect.fromLTWH(bounds.left, bounds.top, bounds.width, 22),
            color: accent,
            size: 13,
            weight: FontWeight.w700,
            maxLines: 1,
          );
          final lineY = bounds.top + 25;
          canvas.drawLine(
            Offset(bounds.left, lineY),
            Offset(bounds.right, lineY),
            Paint()
              ..color = accent.withValues(alpha: 0.45)
              ..strokeWidth = 1.5,
          );
        }
      case 'swatch':
        final swatchCard = RRect.fromRectAndRadius(
          bounds,
          const Radius.circular(10),
        );
        canvas.drawRRect(
          swatchCard,
          Paint()..color = colors.surfaceContainerHigh,
        );
        canvas.drawRRect(
          swatchCard,
          Paint()
            ..color = colors.outlineVariant.withValues(alpha: .4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        final colorHeight = bounds.height * 0.62;
        final colorFill = RRect.fromRectAndCorners(
          Rect.fromLTWH(bounds.left, bounds.top, bounds.width, colorHeight),
          topLeft: const Radius.circular(10),
          topRight: const Radius.circular(10),
        );
        canvas.drawRRect(colorFill, Paint()..color = Color(element.color));
        if (camera.zoom > .25) {
          final hex =
              '#${(element.color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
          _text(
            canvas,
            hex,
            Rect.fromLTWH(
              bounds.left + 10,
              bounds.top + colorHeight + 8,
              math.max(1, bounds.width - 20),
              16,
            ),
            color: colors.onSurface,
            size: 11,
            weight: FontWeight.w600,
            maxLines: 1,
          );
          if (element.text.isNotEmpty) {
            _text(
              canvas,
              element.text,
              Rect.fromLTWH(
                bounds.left + 10,
                bounds.top + colorHeight + 26,
                math.max(1, bounds.width - 20),
                16,
              ),
              color: colors.onSurfaceVariant,
              size: 10,
              maxLines: 1,
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
      editingId != oldDelegate.editingId ||
      backgroundStyle != oldDelegate.backgroundStyle ||
      hoveredAnchorElementId != oldDelegate.hoveredAnchorElementId ||
      connectingStartElementId != oldDelegate.connectingStartElementId ||
      transparentBackground != oldDelegate.transparentBackground ||
      !setEquals(exportElementIds, oldDelegate.exportElementIds) ||
      !listEquals(guides, oldDelegate.guides);
}

/// High-fidelity raster PNG export for a [CanvasScene].
Future<Uint8List?> renderCanvasToPng({
  required CanvasScene scene,
  required ColorScheme colors,
  required String backgroundStyle,
  CanvasBounds? bounds,
  Set<String>? elementIds,
  double scale = 2.0,
  bool transparent = false,
  Map<String, ui.Image> images = const {},
  Map<String, CanvasObjectReference> objects = const {},
}) async {
  CanvasBounds exportBounds;
  if (elementIds != null && elementIds.isNotEmpty) {
    CanvasBounds? unionBounds;
    for (final id in elementIds) {
      final elem = scene[id];
      if (elem != null) {
        unionBounds = unionBounds?.union(elem.bounds) ?? elem.bounds;
      }
    }
    exportBounds = (unionBounds ?? const CanvasBounds(0, 0, 800, 600)).inflate(
      40,
    );
  } else if (bounds != null) {
    exportBounds = bounds;
  } else {
    exportBounds = (scene.contentBounds ?? const CanvasBounds(0, 0, 800, 600))
        .inflate(40);
  }

  final width = (exportBounds.width * scale).ceilToDouble().clamp(
    10.0,
    16384.0,
  );
  final height = (exportBounds.height * scale).ceilToDouble().clamp(
    10.0,
    16384.0,
  );

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

  final exportCamera = CanvasCamera(
    x: exportBounds.left,
    y: exportBounds.top,
    zoom: scale,
  );

  final textCache = CanvasTextCache();
  final painter = OrbitCanvasPainter(
    scene: scene,
    camera: exportCamera,
    selection: const {},
    objects: objects,
    colors: colors,
    backgroundStyle: backgroundStyle,
    images: images,
    textCache: textCache,
    exportElementIds: elementIds,
    transparentBackground: transparent,
  );

  painter.paint(canvas, Size(width, height));
  final picture = recorder.endRecording();
  final img = await picture.toImage(width.toInt(), height.toInt());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  textCache.dispose();
  return byteData?.buffer.asUint8List();
}
