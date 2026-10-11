import 'dart:math' as math;

import 'character_recognizer.dart';
import 'geometry.dart';
import 'scene.dart';

/// Result of geometric shape recognition on a raw freehand stroke.
class RecognizedShape {
  const RecognizedShape({
    required this.type,
    required this.confidence,
    required this.bounds,
    this.startPoint,
    this.endPoint,
  });

  /// The detected shape type: 'rectangle', 'ellipse', 'diamond', 'line', 'arrow'.
  final String type;

  /// Confidence score between 0.0 and 1.0.
  final double confidence;

  /// Bounding box of the recognized shape.
  final CanvasBounds bounds;

  /// Start endpoint for line/arrow shapes.
  final CanvasPoint? startPoint;

  /// End endpoint for line/arrow shapes.
  final CanvasPoint? endPoint;
}

/// Analyzes an ink [CanvasElement] and detects if it represents a clean geometric shape.
RecognizedShape? recognizeShape(CanvasElement inkElement) {
  final points = inkElement.points;
  if (points.length < 4) return null;

  // Transform points to world coordinates
  final worldPoints = points
      .map((p) => CanvasPoint(inkElement.x + p.x, inkElement.y + p.y))
      .toList();

  final bounds = inkElement.bounds;
  final width = bounds.width;
  final height = bounds.height;
  if (width < 8 && height < 8) return null;

  // Calculate total path length
  var totalLength = 0.0;
  for (var i = 0; i < worldPoints.length - 1; i++) {
    totalLength += (worldPoints[i + 1] - worldPoints[i]).length;
  }
  if (totalLength < 16) return null;

  final first = worldPoints.first;
  final last = worldPoints.last;
  final gap = (first - last).length;
  final isClosed = gap < 48 || (gap / totalLength) < 0.26;

  if (isClosed) {
    // 1. Calculate centroid
    var sumX = 0.0;
    var sumY = 0.0;
    for (final p in worldPoints) {
      sumX += p.x;
      sumY += p.y;
    }
    final centroid = CanvasPoint(
      sumX / worldPoints.length,
      sumY / worldPoints.length,
    );

    // 2. Check Circle / Ellipse (theoretical circle dev = 0.0, rectangle dev ~ 0.197)
    final rx = math.max(10.0, width / 2);
    final ry = math.max(10.0, height / 2);

    var radialDevSum = 0.0;
    for (final p in worldPoints) {
      final dx = (p.x - centroid.x) / rx;
      final dy = (p.y - centroid.y) / ry;
      final normDist = math.sqrt(dx * dx + dy * dy);
      radialDevSum += (normDist - 1.0).abs();
    }
    final avgRadialDev = radialDevSum / worldPoints.length;

    if (avgRadialDev < 0.14) {
      final conf = (1.0 - avgRadialDev * 3.0).clamp(0.6, 0.98);
      return RecognizedShape(type: 'ellipse', confidence: conf, bounds: bounds);
    }

    // 3. Check 4 corners (Rectangle check: distance to bounding corners < 0.14 * minDim)
    final cornerTolerance = math.min(width, height) * 0.14;
    final tl = CanvasPoint(bounds.left, bounds.top);
    final tr = CanvasPoint(bounds.right, bounds.top);
    final bl = CanvasPoint(bounds.left, bounds.bottom);
    final br = CanvasPoint(bounds.right, bounds.bottom);

    var hasTL = false, hasTR = false, hasBL = false, hasBR = false;
    for (final p in worldPoints) {
      if ((p - tl).length < cornerTolerance) hasTL = true;
      if ((p - tr).length < cornerTolerance) hasTR = true;
      if ((p - bl).length < cornerTolerance) hasBL = true;
      if ((p - br).length < cornerTolerance) hasBR = true;
    }

    final cornerCount =
        (hasTL ? 1 : 0) + (hasTR ? 1 : 0) + (hasBL ? 1 : 0) + (hasBR ? 1 : 0);
    if (cornerCount >= 3) {
      return RecognizedShape(
        type: 'rectangle',
        confidence: 0.88,
        bounds: bounds,
      );
    }

    // 4. Check diamond edge midpoints
    final midTop = CanvasPoint(bounds.left + width / 2, bounds.top);
    final midRight = CanvasPoint(bounds.right, bounds.top + height / 2);
    final midBottom = CanvasPoint(bounds.left + width / 2, bounds.bottom);
    final midLeft = CanvasPoint(bounds.left, bounds.top + height / 2);

    var hasMidT = false, hasMidR = false, hasMidB = false, hasMidL = false;
    for (final p in worldPoints) {
      if ((p - midTop).length < cornerTolerance * 1.5) hasMidT = true;
      if ((p - midRight).length < cornerTolerance * 1.5) hasMidR = true;
      if ((p - midBottom).length < cornerTolerance * 1.5) hasMidB = true;
      if ((p - midLeft).length < cornerTolerance * 1.5) hasMidL = true;
    }

    if (hasMidT && hasMidR && hasMidB && hasMidL && cornerCount <= 1) {
      return RecognizedShape(type: 'diamond', confidence: 0.82, bounds: bounds);
    }

    // Default closed fallback: rectangle if box-like, else ellipse
    final isSquareish = (width / height).clamp(0.3, 3.0) == (width / height);
    return RecognizedShape(
      type: isSquareish && cornerCount >= 2 ? 'rectangle' : 'ellipse',
      confidence: 0.65,
      bounds: bounds,
    );
  }

  // Open Stroke: Straight line or Arrow
  final chordLength = (last - first).length;
  if (chordLength > 20) {
    // Check line deviation
    var maxPerpDist = 0.0;
    final lineDx = last.x - first.x;
    final lineDy = last.y - first.y;

    for (final p in worldPoints) {
      // Distance from point p to line segment (first -> last)
      final num =
          (lineDy * p.x - lineDx * p.y + last.x * first.y - last.y * first.x)
              .abs();
      final dist = num / chordLength;
      if (dist > maxPerpDist) maxPerpDist = dist;
    }

    // Check if the stroke has an arrowhead at the end (sharp reversal/fork)
    var isArrow = false;
    if (worldPoints.length >= 4) {
      final tailIdx = math.max(1, (worldPoints.length * 0.70).floor());
      final bodyVec = CanvasPoint(
        worldPoints[tailIdx].x - first.x,
        worldPoints[tailIdx].y - first.y,
      );
      final headVec = CanvasPoint(
        last.x - worldPoints[tailIdx].x,
        last.y - worldPoints[tailIdx].y,
      );
      final dot = (bodyVec.x * headVec.x + bodyVec.y * headVec.y);
      if (dot < 0) {
        isArrow = true;
      }
    }

    if (maxPerpDist / chordLength < 0.20) {
      return RecognizedShape(
        type: isArrow ? 'arrow' : 'line',
        confidence: 0.88,
        bounds: bounds,
        startPoint: first,
        endPoint: last,
      );
    }
  }

  return null;
}

/// Converts a raw ink stroke [CanvasElement] into a clean geometric shape.
///
/// If [forceShape] is provided ('rectangle', 'ellipse', 'diamond', 'arrow', 'line'),
/// that shape is generated directly. Otherwise, [recognizeShape] is used.
CanvasElement? convertInkToShape(
  CanvasElement inkElement, {
  String? forceShape,
}) {
  final recognized = recognizeShape(inkElement);
  final shapeType = forceShape ?? recognized?.type ?? 'rectangle';
  final bounds = inkElement.bounds;

  if (shapeType == 'arrow' || shapeType == 'line') {
    final start =
        recognized?.startPoint ??
        (inkElement.points.isNotEmpty
            ? CanvasPoint(
                inkElement.x + inkElement.points.first.x,
                inkElement.y + inkElement.points.first.y,
              )
            : CanvasPoint(bounds.left, bounds.top));
    final end =
        recognized?.endPoint ??
        (inkElement.points.isNotEmpty
            ? CanvasPoint(
                inkElement.x + inkElement.points.last.x,
                inkElement.y + inkElement.points.last.y,
              )
            : CanvasPoint(bounds.right, bounds.bottom));

    return CanvasElement({
      'id': inkElement.id,
      'type': shapeType == 'arrow' ? 'arrow' : 'line',
      'startX': start.x,
      'startY': start.y,
      'endX': end.x,
      'endY': end.y,
      'color': inkElement.color,
      'strokeWidth': math.max(2.0, inkElement.strokeWidth),
      'endMarker': shapeType == 'arrow' ? 'arrow' : 'none',
      if (inkElement.groupId != null) 'groupId': inkElement.groupId,
    });
  }

  // Geometric 2D shapes
  final finalW = math.max(48.0, bounds.width);
  final finalH = math.max(48.0, bounds.height);

  return CanvasElement({
    'id': inkElement.id,
    'type': shapeType,
    'x': bounds.left,
    'y': bounds.top,
    'width': finalW,
    'height': finalH,
    'color': inkElement.color,
    'strokeWidth': math.max(2.0, inkElement.strokeWidth),
    'text': '',
    if (inkElement.groupId != null) 'groupId': inkElement.groupId,
  });
}

/// Unified recognition result representing either a clean geometric shape or a character.
class RecognizedInkGesture {
  const RecognizedInkGesture.shape(this.shape)
    : character = null,
      isShape = true;

  const RecognizedInkGesture.character(this.character)
    : shape = null,
      isShape = false;

  final RecognizedShape? shape;
  final RecognizedCharacter? character;
  final bool isShape;
  bool get isCharacter => !isShape;
  double get confidence =>
      isShape ? (shape?.confidence ?? 0.0) : (character?.confidence ?? 0.0);
}

/// Unified classifier: evaluates an ink stroke against geometric shapes and handwriting characters.
RecognizedInkGesture? recognizeInkGesture(
  CanvasElement inkElement, {
  double minConfidence = 0.65,
}) {
  final shape = recognizeShape(inkElement);
  final char = recognizeCharacterFromInk(
    inkElement,
    minConfidence: minConfidence,
  );

  if (shape == null && char == null) return null;

  // If only one matched, return that match
  if (shape != null && char == null) {
    return RecognizedInkGesture.shape(shape);
  }
  if (shape == null && char != null) {
    return RecognizedInkGesture.character(char);
  }

  // Both matched: arbitrate based on size and glyph characteristics
  final bounds = inkElement.bounds;
  final maxDim = math.max(bounds.width, bounds.height);

  // Arrows are always shapes
  if (shape!.type == 'arrow') {
    return RecognizedInkGesture.shape(shape);
  }

  // Large strokes (> 75px) with shape match are shapes
  if (maxDim > 75.0) {
    return RecognizedInkGesture.shape(shape);
  }

  // If character is a distinct non-circle/box letter/digit with high confidence, prefer character
  final distinctChars = {
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    'A',
    'B',
    'C',
    'E',
    'F',
    'G',
    'H',
    'J',
    'K',
    'L',
    'M',
    'N',
    'P',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
    'a',
    'b',
    'd',
    'e',
    'h',
    'r',
    't',
    '+',
    '=',
    '?',
    '!',
  };
  if (char != null &&
      distinctChars.contains(char.char) &&
      char.confidence >= 0.70) {
    return RecognizedInkGesture.character(char);
  }

  // Compare confidences
  if (shape.confidence >= (char?.confidence ?? 0.0)) {
    return RecognizedInkGesture.shape(shape);
  } else {
    return RecognizedInkGesture.character(char!);
  }
}

/// Converts an ink [CanvasElement] using a recognized ink gesture.
CanvasElement? convertInkGesture(
  CanvasElement inkElement,
  RecognizedInkGesture gesture,
) {
  if (gesture.isShape) {
    return convertInkToShape(inkElement, forceShape: gesture.shape?.type);
  } else if (gesture.isCharacter) {
    return convertInkToText(inkElement, text: gesture.character?.char);
  }
  return null;
}
