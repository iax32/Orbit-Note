import 'dart:math' as math;
import '../canvas/geometry.dart';

/// Presentation-only page regions; no board placements are changed.
class CanvasPdfLayout {
  CanvasPdfLayout(
    CanvasBounds bounds, {
    String orientation = 'auto',
    bool a3 = false,
    bool tiles = true,
  }) {
    if (![
          bounds.left,
          bounds.top,
          bounds.width,
          bounds.height,
        ].every((v) => v.isFinite) ||
        bounds.width <= 0 ||
        bounds.height <= 0 ||
        bounds.width > 10000000 ||
        bounds.height > 10000000) {
      throw const FormatException(
        'Canvas has invalid or excessive export bounds.',
      );
    }
    if (!['auto', 'portrait', 'landscape'].contains(orientation)) {
      throw const FormatException('Unknown page orientation.');
    }
    final landscape =
        orientation == 'landscape' ||
        orientation == 'auto' && bounds.width > bounds.height;
    final short = a3 ? 841.89 : 595.28, long = a3 ? 1190.55 : 841.89;
    width = landscape ? long : short;
    height = landscape ? short : long;
    final usableWidth = width - 64, usableHeight = height - 136;
    final fit = math.min(
      usableWidth / bounds.width,
      usableHeight / bounds.height,
    );
    scale = tiles ? math.min(1.0, math.max(fit, .75)) : fit;
    final regionWidth = usableWidth / scale,
        regionHeight = usableHeight / scale;
    // A little overlap keeps strokes/labels at paper boundaries recoverable.
    final stepX = math.max(1.0, regionWidth - 24),
        stepY = math.max(1.0, regionHeight - 24);
    columns = tiles
        ? math.max(1, ((bounds.width - regionWidth) / stepX).ceil() + 1)
        : 1;
    rows = tiles
        ? math.max(1, ((bounds.height - regionHeight) / stepY).ceil() + 1)
        : 1;
    if (rows * columns > 100) {
      throw const FormatException(
        'Canvas needs over 100 pages. Use A3, fit on one page, or export a smaller selection.',
      );
    }
    pages = [
      for (var r = 0; r < rows; r++)
        for (var c = 0; c < columns; c++)
          CanvasBounds(
            bounds.left + c * stepX,
            bounds.top + r * stepY,
            math.min(regionWidth, bounds.width - c * stepX),
            math.min(regionHeight, bounds.height - r * stepY),
          ),
    ];
  }
  late final double width, height, scale;
  late final int rows, columns;
  late final List<CanvasBounds> pages;
}
