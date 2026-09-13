import 'dart:math' as math;

import 'connectors.dart';
import 'geometry.dart';
import 'scene.dart';

/// Exports a [CanvasScene] to a standard vector SVG document string.
///
/// Pure Dart implementation independent of Flutter/UI SDKs.
String canvasToSvg(
  CanvasScene scene, {
  CanvasBounds? bounds,
  bool transparent = false,
  int? backgroundColor,
  Iterable<String>? elementIds,
}) {
  final targetIds = elementIds?.toSet();

  CanvasBounds exportBounds;
  if (targetIds != null && targetIds.isNotEmpty) {
    CanvasBounds? unionBounds;
    for (final id in targetIds) {
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

  final width = math.max(10.0, exportBounds.width);
  final height = math.max(10.0, exportBounds.height);
  final minX = exportBounds.left;
  final minY = exportBounds.top;

  final bgHex = backgroundColor != null
      ? _toHexColor(backgroundColor)
      : '#121218';

  final buffer = StringBuffer();
  buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="no"?>');
  buffer.writeln(
    '<svg xmlns="http://www.w3.org/2000/svg" '
    'xmlns:xlink="http://www.w3.org/1999/xlink" '
    'viewBox="${_formatNum(minX)} ${_formatNum(minY)} ${_formatNum(width)} ${_formatNum(height)}" '
    'width="${_formatNum(width)}" height="${_formatNum(height)}">',
  );

  // Embedded styles and defs
  buffer.writeln('  <defs>');
  buffer.writeln('    <style type="text/css">');
  buffer.writeln(
    '      text { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }',
  );
  buffer.writeln('    </style>');
  buffer.writeln(
    '    <filter id="sticky-shadow" x="-8%" y="-8%" width="120%" height="120%">',
  );
  buffer.writeln(
    '      <feDropShadow dx="0" dy="2" stdDeviation="3" flood-opacity="0.18"/>',
  );
  buffer.writeln('    </filter>');
  buffer.writeln('  </defs>');

  // Background rect
  if (!transparent) {
    buffer.writeln(
      '  <rect x="${_formatNum(minX)}" y="${_formatNum(minY)}" '
      'width="${_formatNum(width)}" height="${_formatNum(height)}" fill="$bgHex" />',
    );
  }

  // Render elements in z-stacking order
  for (final element in scene.elementsInOrder) {
    if (element.hidden || !element.renderable) continue;
    if (targetIds != null && !targetIds.contains(element.id)) continue;

    _renderElementSvg(buffer, element, scene, bgHex);
  }

  buffer.writeln('</svg>');
  return buffer.toString();
}

void _renderElementSvg(
  StringBuffer buf,
  CanvasElement element,
  CanvasScene scene,
  String canvasBgHex,
) {
  final accent = _toHexColor(element.color);
  final strokeW = element.strokeWidth;

  switch (element.type) {
    case 'rectangle':
    case 'frame':
      final isFrame = element.type == 'frame';
      final fillOpacity = isFrame ? '0.04' : '0.10';
      buf.writeln(
        '  <rect x="${_formatNum(element.x)}" y="${_formatNum(element.y)}" '
        'width="${_formatNum(element.width)}" height="${_formatNum(element.height)}" '
        'rx="10" ry="10" fill="$accent" fill-opacity="$fillOpacity" '
        'stroke="$accent" stroke-width="${_formatNum(strokeW)}" />',
      );
      if (element.text.isNotEmpty) {
        _renderCenteredText(
          buf,
          element.text,
          element.bounds.deflate(12),
          accent,
          14,
        );
      }

    case 'ellipse':
      final cx = element.x + element.width / 2;
      final cy = element.y + element.height / 2;
      final rx = math.max(1.0, element.width / 2);
      final ry = math.max(1.0, element.height / 2);
      buf.writeln(
        '  <ellipse cx="${_formatNum(cx)}" cy="${_formatNum(cy)}" '
        'rx="${_formatNum(rx)}" ry="${_formatNum(ry)}" '
        'fill="$accent" fill-opacity="0.10" stroke="$accent" stroke-width="${_formatNum(strokeW)}" />',
      );
      if (element.text.isNotEmpty) {
        _renderCenteredText(
          buf,
          element.text,
          element.bounds.deflate(12),
          accent,
          14,
        );
      }

    case 'diamond':
      final cx = element.x + element.width / 2;
      final cy = element.y + element.height / 2;
      final pTop = '$cx,${element.y}';
      final pRight = '${element.x + element.width},$cy';
      final pBottom = '$cx,${element.y + element.height}';
      final pLeft = '${element.x},$cy';
      buf.writeln(
        '  <polygon points="$pTop $pRight $pBottom $pLeft" '
        'fill="$accent" fill-opacity="0.10" stroke="$accent" stroke-width="${_formatNum(strokeW)}" />',
      );
      if (element.text.isNotEmpty) {
        _renderCenteredText(
          buf,
          element.text,
          element.bounds.deflate(16),
          accent,
          13,
        );
      }

    case 'text':
      _renderTextLines(
        buf,
        element.text,
        element.x,
        element.y + 16,
        accent,
        15,
      );

    case 'sticky':
      final stickyBg = element.color != 0xff8b7cf6
          ? _toHexColor(element.color)
          : '#fef08a';
      buf.writeln(
        '  <rect x="${_formatNum(element.x)}" y="${_formatNum(element.y)}" '
        'width="${_formatNum(element.width)}" height="${_formatNum(element.height)}" '
        'rx="8" ry="8" fill="$stickyBg" stroke="$stickyBg" stroke-width="1" filter="url(#sticky-shadow)" />',
      );
      _renderTextLines(
        buf,
        element.text,
        element.x + 14,
        element.y + 24,
        '#1c1917',
        14,
      );

    case 'card':
      final nested = element.data['data'] is Map
          ? element.data['data'] as Map
          : null;
      final title =
          element.data['title'] is String &&
              (element.data['title'] as String).isNotEmpty
          ? element.data['title'] as String
          : (nested?['title'] is String &&
                    (nested!['title'] as String).isNotEmpty
                ? nested['title'] as String
                : element.text);
      final subtitle = element.data['subtitle'] is String
          ? element.data['subtitle'] as String
          : (nested?['subtitle'] is String
                ? nested!['subtitle'] as String
                : '');
      final badge =
          element.data['badge'] is String &&
              (element.data['badge'] as String).isNotEmpty
          ? element.data['badge'] as String
          : (nested?['badge'] is String &&
                    (nested!['badge'] as String).isNotEmpty
                ? nested['badge'] as String
                : 'CARD');

      buf.writeln(
        '  <rect x="${_formatNum(element.x)}" y="${_formatNum(element.y)}" '
        'width="${_formatNum(element.width)}" height="${_formatNum(element.height)}" '
        'rx="12" ry="12" fill="#1e1e24" stroke="$accent" stroke-width="1.5" />',
      );
      // Badge pill
      buf.writeln(
        '  <text x="${_formatNum(element.x + 14)}" y="${_formatNum(element.y + 22)}" '
        'font-size="10" font-weight="700" fill="$accent" letter-spacing="0.8">${_escapeXml(badge.toUpperCase())}</text>',
      );
      // Title
      buf.writeln(
        '  <text x="${_formatNum(element.x + 14)}" y="${_formatNum(element.y + 44)}" '
        'font-size="14" font-weight="600" fill="#f3f4f6">${_escapeXml(title)}</text>',
      );
      // Subtitle
      if (subtitle.isNotEmpty) {
        buf.writeln(
          '  <text x="${_formatNum(element.x + 14)}" y="${_formatNum(element.y + 64)}" '
          'font-size="11" fill="#9ca3af">${_escapeXml(subtitle)}</text>',
        );
      }

    case 'section':
      buf.writeln(
        '  <text x="${_formatNum(element.x)}" y="${_formatNum(element.y + 14)}" '
        'font-size="13" font-weight="700" letter-spacing="1.2" fill="$accent">${_escapeXml(element.text.toUpperCase())}</text>',
      );
      buf.writeln(
        '  <line x1="${_formatNum(element.x)}" y1="${_formatNum(element.y + 22)}" '
        'x2="${_formatNum(element.x + element.width)}" y2="${_formatNum(element.y + 22)}" '
        'stroke="$accent" stroke-width="1.5" stroke-opacity="0.5" />',
      );

    case 'swatch':
      final swatchH = math.max(20.0, element.height - 36);
      buf.writeln(
        '  <rect x="${_formatNum(element.x)}" y="${_formatNum(element.y)}" '
        'width="${_formatNum(element.width)}" height="${_formatNum(swatchH)}" '
        'rx="8" ry="8" fill="$accent" />',
      );
      buf.writeln(
        '  <rect x="${_formatNum(element.x)}" y="${_formatNum(element.y + swatchH)}" '
        'width="${_formatNum(element.width)}" height="36" '
        'fill="#26262a" rx="4" ry="4" />',
      );
      buf.writeln(
        '  <text x="${_formatNum(element.x + element.width / 2)}" y="${_formatNum(element.y + swatchH + 22)}" '
        'text-anchor="middle" font-family="monospace" font-size="12" font-weight="600" fill="#f3f4f6">$accent</text>',
      );

    case 'column':
      buf.writeln(
        '  <rect x="${_formatNum(element.x)}" y="${_formatNum(element.y)}" '
        'width="${_formatNum(element.width)}" height="${_formatNum(element.height)}" '
        'rx="12" ry="12" fill="#18181f" stroke="#374151" stroke-width="1" />',
      );
      buf.writeln(
        '  <line x1="${_formatNum(element.x + 16)}" y1="${_formatNum(element.y + 42)}" '
        'x2="${_formatNum(element.x + element.width - 16)}" y2="${_formatNum(element.y + 42)}" '
        'stroke="$accent" stroke-width="2" stroke-opacity="0.45" />',
      );
      if (element.text.isNotEmpty) {
        buf.writeln(
          '  <text x="${_formatNum(element.x + 16)}" y="${_formatNum(element.y + 28)}" '
          'font-size="15" font-weight="600" fill="#f3f4f6">${_escapeXml(element.text)}</text>',
        );
      }

    case 'link':
      buf.writeln(
        '  <rect x="${_formatNum(element.x)}" y="${_formatNum(element.y)}" '
        'width="${_formatNum(element.width)}" height="${_formatNum(element.height)}" '
        'rx="12" ry="12" fill="#1e1e24" stroke="#374151" stroke-width="1" />',
      );
      buf.writeln(
        '  <text x="${_formatNum(element.x + 16)}" y="${_formatNum(element.y + 24)}" '
        'font-size="10" font-weight="700" fill="$accent">WEBSITE &#x2197;</text>',
      );
      buf.writeln(
        '  <text x="${_formatNum(element.x + 16)}" y="${_formatNum(element.y + 50)}" '
        'font-size="15" font-weight="600" fill="#f3f4f6">${_escapeXml(element.text)}</text>',
      );
      if (element.url.isNotEmpty) {
        buf.writeln(
          '  <text x="${_formatNum(element.x + 16)}" y="${_formatNum(element.y + 72)}" '
          'font-size="11" fill="#9ca3af">${_escapeXml(element.url)}</text>',
        );
      }

    case 'image':
      final ref = element.data['contentRef'] as String? ?? '';
      if (ref.startsWith('data:image') ||
          ref.startsWith('http://') ||
          ref.startsWith('https://')) {
        buf.writeln(
          '  <image href="${_escapeXml(ref)}" x="${_formatNum(element.x)}" y="${_formatNum(element.y)}" '
          'width="${_formatNum(element.width)}" height="${_formatNum(element.height)}" '
          'preserveAspectRatio="xMidYMid meet" />',
        );
      } else {
        buf.writeln(
          '  <rect x="${_formatNum(element.x)}" y="${_formatNum(element.y)}" '
          'width="${_formatNum(element.width)}" height="${_formatNum(element.height)}" '
          'rx="10" ry="10" fill="#2d3748" stroke="#4a5568" stroke-width="1" />',
        );
        buf.writeln(
          '  <text x="${_formatNum(element.x + element.width / 2)}" y="${_formatNum(element.y + element.height / 2 + 5)}" '
          'text-anchor="middle" font-size="14" fill="#a0aec0">Image</text>',
        );
      }

    case 'ink':
      final points = element.points;
      if (points.isEmpty) return;
      final isHighlighter = element.data['isHighlighter'] == true;
      final inkWidth = isHighlighter ? math.max(18.0, strokeW) : strokeW;
      final inkOpacity = isHighlighter ? '0.38' : '1.0';

      if (points.length == 1) {
        final p = points.first;
        buf.writeln(
          '  <circle cx="${_formatNum(element.x + p.x)}" cy="${_formatNum(element.y + p.y)}" '
          'r="${_formatNum(inkWidth / 2)}" fill="$accent" opacity="$inkOpacity" />',
        );
        return;
      }

      final d = StringBuffer();
      d.write(
        'M ${_formatNum(element.x + points.first.x)} ${_formatNum(element.y + points.first.y)}',
      );
      for (final p in points.skip(1)) {
        d.write(
          ' L ${_formatNum(element.x + p.x)} ${_formatNum(element.y + p.y)}',
        );
      }
      buf.writeln(
        '  <path d="$d" fill="none" stroke="$accent" stroke-width="${_formatNum(inkWidth)}" '
        'stroke-linecap="round" stroke-linejoin="round" opacity="$inkOpacity" />',
      );

    case 'connector':
    case 'arrow':
    case 'line':
      final endpoints = resolveConnectorEndpoints(element, scene);
      final start = endpoints.start;
      final end = endpoints.end;
      final routing = ConnectorRouting.parse(element.routing);
      final style = ConnectorStyle.parse(element.strokeStyle);
      final startMarker = ConnectorMarker.parse(element.startMarker);
      final endMarker = ConnectorMarker.parse(
        element.endMarker,
        defaultMarker: (element.type == 'arrow' || element.type == 'connector'
            ? ConnectorMarker.arrow
            : ConnectorMarker.none),
      );

      // Dash pattern
      var dashAttr = '';
      if (style == ConnectorStyle.dashed) {
        dashAttr = ' stroke-dasharray="8,5"';
      } else if (style == ConnectorStyle.dotted) {
        dashAttr = ' stroke-dasharray="2,6"';
      }

      // Path data
      final d = StringBuffer();
      d.write('M ${_formatNum(start.x)} ${_formatNum(start.y)}');
      if (routing == ConnectorRouting.curved &&
          endpoints.controlPoints.length >= 2) {
        final cp1 = endpoints.controlPoints[0];
        final cp2 = endpoints.controlPoints[1];
        d.write(
          ' C ${_formatNum(cp1.x)} ${_formatNum(cp1.y)}, ${_formatNum(cp2.x)} ${_formatNum(cp2.y)}, ${_formatNum(end.x)} ${_formatNum(end.y)}',
        );
      } else if (routing == ConnectorRouting.orthogonal &&
          endpoints.controlPoints.isNotEmpty) {
        for (final cp in endpoints.controlPoints) {
          d.write(' L ${_formatNum(cp.x)} ${_formatNum(cp.y)}');
        }
        d.write(' L ${_formatNum(end.x)} ${_formatNum(end.y)}');
      } else {
        d.write(' L ${_formatNum(end.x)} ${_formatNum(end.y)}');
      }

      buf.writeln(
        '  <path d="$d" fill="none" stroke="$accent" stroke-width="${_formatNum(strokeW)}" '
        'stroke-linecap="round" stroke-linejoin="round"$dashAttr />',
      );

      // Markers
      if (startMarker != ConnectorMarker.none) {
        final firstTarget = endpoints.controlPoints.isNotEmpty
            ? endpoints.controlPoints.first
            : end;
        final angle = math.atan2(
          start.y - firstTarget.y,
          start.x - firstTarget.x,
        );
        _renderMarkerSvg(buf, start, angle, startMarker, accent, strokeW);
      }
      if (endMarker != ConnectorMarker.none) {
        final lastTarget = endpoints.controlPoints.isNotEmpty
            ? endpoints.controlPoints.last
            : start;
        final angle = math.atan2(end.y - lastTarget.y, end.x - lastTarget.x);
        _renderMarkerSvg(buf, end, angle, endMarker, accent, strokeW);
      }

      // Midpoint label pill
      if (element.text.trim().isNotEmpty) {
        final mid = endpoints.midpoint;
        final text = element.text.trim();
        final textWidth = math.max(40.0, text.length * 8.0 + 16.0);
        final pillH = 22.0;
        buf.writeln(
          '  <rect x="${_formatNum(mid.x - textWidth / 2)}" y="${_formatNum(mid.y - pillH / 2)}" '
          'width="${_formatNum(textWidth)}" height="${_formatNum(pillH)}" '
          'rx="5" ry="5" fill="$canvasBgHex" stroke="$accent" stroke-width="1" stroke-opacity="0.4" />',
        );
        buf.writeln(
          '  <text x="${_formatNum(mid.x)}" y="${_formatNum(mid.y + 4.5)}" '
          'text-anchor="middle" font-size="11" font-weight="600" fill="$accent">${_escapeXml(text)}</text>',
        );
      }
  }
}

void _renderMarkerSvg(
  StringBuffer buf,
  CanvasPoint pt,
  double angle,
  ConnectorMarker marker,
  String color,
  double strokeWidth,
) {
  if (marker == ConnectorMarker.arrow) {
    final head = math.max(12.0, strokeWidth * 3.5);
    final p1x = pt.x - math.cos(angle - 0.48) * head;
    final p1y = pt.y - math.sin(angle - 0.48) * head;
    final p2x = pt.x - math.cos(angle + 0.48) * head;
    final p2y = pt.y - math.sin(angle + 0.48) * head;
    buf.writeln(
      '  <polyline points="${_formatNum(p1x)},${_formatNum(p1y)} ${_formatNum(pt.x)},${_formatNum(pt.y)} ${_formatNum(p2x)},${_formatNum(p2y)}" '
      'fill="none" stroke="$color" stroke-width="${_formatNum(strokeWidth)}" stroke-linecap="round" stroke-linejoin="round" />',
    );
  } else if (marker == ConnectorMarker.dot) {
    final r = math.max(3.5, strokeWidth * 1.5 + 1.5);
    buf.writeln(
      '  <circle cx="${_formatNum(pt.x)}" cy="${_formatNum(pt.y)}" r="${_formatNum(r)}" fill="$color" />',
    );
  } else if (marker == ConnectorMarker.diamond) {
    final dSize = math.max(6.0, strokeWidth * 2.5 + 4);
    final pBackX = pt.x - math.cos(angle) * dSize;
    final pBackY = pt.y - math.sin(angle) * dSize;
    final pSide1X = pt.x - math.cos(angle + math.pi / 2) * (dSize * 0.55);
    final pSide1Y = pt.y - math.sin(angle + math.pi / 2) * (dSize * 0.55);
    final pSide2X = pt.x - math.cos(angle - math.pi / 2) * (dSize * 0.55);
    final pSide2Y = pt.y - math.sin(angle - math.pi / 2) * (dSize * 0.55);
    buf.writeln(
      '  <polygon points="${_formatNum(pt.x)},${_formatNum(pt.y)} ${_formatNum(pSide1X)},${_formatNum(pSide1Y)} ${_formatNum(pBackX)},${_formatNum(pBackY)} ${_formatNum(pSide2X)},${_formatNum(pSide2Y)}" '
      'fill="$color" />',
    );
  }
}

void _renderCenteredText(
  StringBuffer buf,
  String text,
  CanvasBounds bounds,
  String color,
  double fontSize,
) {
  final lines = text.split('\n');
  final lineHeight = fontSize * 1.35;
  final totalH = lines.length * lineHeight;
  final startY = bounds.top + (bounds.height - totalH) / 2 + fontSize * 0.85;
  final cx = bounds.left + bounds.width / 2;

  buf.writeln(
    '  <text text-anchor="middle" font-size="${_formatNum(fontSize)}" fill="$color">',
  );
  for (var i = 0; i < lines.length; i++) {
    final y = startY + i * lineHeight;
    buf.writeln(
      '    <tspan x="${_formatNum(cx)}" y="${_formatNum(y)}">${_escapeXml(lines[i])}</tspan>',
    );
  }
  buf.writeln('  </text>');
}

void _renderTextLines(
  StringBuffer buf,
  String text,
  double startX,
  double startY,
  String color,
  double fontSize,
) {
  final lines = text.split('\n');
  final lineHeight = fontSize * 1.35;
  buf.writeln('  <text font-size="${_formatNum(fontSize)}" fill="$color">');
  for (var i = 0; i < lines.length; i++) {
    final y = startY + i * lineHeight;
    buf.writeln(
      '    <tspan x="${_formatNum(startX)}" y="${_formatNum(y)}">${_escapeXml(lines[i])}</tspan>',
    );
  }
  buf.writeln('  </text>');
}

String _toHexColor(int color) {
  final r = ((color >> 16) & 0xff).toRadixString(16).padLeft(2, '0');
  final g = ((color >> 8) & 0xff).toRadixString(16).padLeft(2, '0');
  final b = (color & 0xff).toRadixString(16).padLeft(2, '0');
  return '#$r$g$b';
}

String _formatNum(double num) {
  return num.toStringAsFixed(1);
}

String _escapeXml(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
