import 'dart:math' as math;

import 'geometry.dart';
import 'scene.dart';

/// Represents a recognized character (letter, digit, or symbol) from handwriting.
class RecognizedCharacter {
  const RecognizedCharacter({
    required this.char,
    required this.confidence,
    required this.bounds,
    required this.isDigit,
    required this.isLetter,
    required this.isSymbol,
  });

  /// The recognized character string, e.g. "A", "7", "+".
  final String char;

  /// Confidence score between 0.0 and 1.0.
  final double confidence;

  /// Bounding box of the original ink strokes.
  final CanvasBounds bounds;

  /// True if the character is a digit '0'-'9'.
  final bool isDigit;

  /// True if the character is an alphabetic letter.
  final bool isLetter;

  /// True if the character is a symbol or punctuation.
  final bool isSymbol;

  @override
  String toString() =>
      'RecognizedCharacter(char: "$char", conf: ${confidence.toStringAsFixed(2)}, bounds: $bounds)';
}

/// A canonical gesture template for point-cloud matching.
class _CharacterTemplate {
  const _CharacterTemplate({
    required this.char,
    required this.strokes,
    this.isDigit = false,
    this.isLetter = false,
    this.isSymbol = false,
  });

  final String char;
  final List<List<CanvasPoint>> strokes;
  final bool isDigit;
  final bool isLetter;
  final bool isSymbol;
}

/// Pure Dart online handwriting character recognizer.
class CharacterRecognizer {
  CharacterRecognizer() {
    _initTemplates();
  }

  static const int _targetPointCount = 32;
  static const double _canonicalSize = 100.0;

  final List<
    ({
      String char,
      List<CanvasPoint> cloud,
      bool isDigit,
      bool isLetter,
      bool isSymbol,
    })
  >
  _normalizedTemplates = [];

  void _initTemplates() {
    for (final t in _templates) {
      final cloud = _resampleAndNormalizeStrokes(t.strokes);
      if (cloud.isNotEmpty) {
        _normalizedTemplates.add((
          char: t.char,
          cloud: cloud,
          isDigit: t.isDigit,
          isLetter: t.isLetter,
          isSymbol: t.isSymbol,
        ));
      }
    }
  }

  /// Recognizes a handwritten character from a list of strokes.
  ///
  /// Each stroke is a list of [CanvasPoint]s in world/element coordinates.
  RecognizedCharacter? recognize(
    List<List<CanvasPoint>> strokes, {
    CanvasBounds? bounds,
    double minConfidence = 0.65,
  }) {
    if (strokes.isEmpty) return null;

    final candidateCloud = _resampleAndNormalizeStrokes(strokes);
    if (candidateCloud.isEmpty) return null;

    // Compute bounding box if not provided
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = -double.infinity;
    var maxY = -double.infinity;

    for (final stroke in strokes) {
      for (final p in stroke) {
        if (p.x < minX) minX = p.x;
        if (p.x > maxX) maxX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.y > maxY) maxY = p.y;
      }
    }
    final calcBounds =
        bounds ??
        CanvasBounds(
          minX,
          minY,
          math.max(1.0, maxX - minX),
          math.max(1.0, maxY - minY),
        );

    final width = calcBounds.width;
    final height = calcBounds.height;
    final aspectRatio = width / math.max(1.0, height);

    // Evaluate against all normalized templates using symmetric Chamfer distance
    String? bestChar;
    var bestDistance = double.infinity;
    var bestIsDigit = false;
    var bestIsLetter = false;
    var bestIsSymbol = false;

    // Distinguish narrow vertical strokes ('1', 'I', 'l') vs wide ('-', '=')
    final isVeryNarrow = aspectRatio < 0.32;
    final isVeryWide = aspectRatio > 2.8;

    for (final template in _normalizedTemplates) {
      if (isVeryNarrow &&
          template.char != '1' &&
          template.char != 'I' &&
          template.char != 'l' &&
          template.char != '|' &&
          template.char != '!') {
        continue;
      }
      if (isVeryWide &&
          template.char != '-' &&
          template.char != '=' &&
          template.char != '_') {
        continue;
      }

      final dist = _cloudDistance(candidateCloud, template.cloud);
      if (dist < bestDistance) {
        bestDistance = dist;
        bestChar = template.char;
        bestIsDigit = template.isDigit;
        bestIsLetter = template.isLetter;
        bestIsSymbol = template.isSymbol;
      }
    }

    if (bestChar == null) return null;

    // Calculate normalized confidence score (0.0 to 1.0)
    final confidence = (1.0 - (bestDistance / 55.0)).clamp(0.0, 0.99);
    if (confidence < minConfidence) return null;

    return RecognizedCharacter(
      char: bestChar,
      confidence: confidence,
      bounds: calcBounds,
      isDigit: bestIsDigit,
      isLetter: bestIsLetter,
      isSymbol: bestIsSymbol,
    );
  }

  /// Resamples and normalizes one or more strokes into a fixed-size point cloud.
  static List<CanvasPoint> _resampleAndNormalizeStrokes(
    List<List<CanvasPoint>> rawStrokes,
  ) {
    final validStrokes = rawStrokes.where((s) => s.isNotEmpty).toList();
    if (validStrokes.isEmpty) return const [];

    // Calculate arc lengths of all strokes
    final strokeLengths = <double>[];
    var totalLength = 0.0;
    for (final stroke in validStrokes) {
      var len = 0.0;
      for (var i = 0; i < stroke.length - 1; i++) {
        len += (stroke[i + 1] - stroke[i]).length;
      }
      strokeLengths.add(len);
      totalLength += len;
    }

    // Collect resampled points proportionally across strokes
    final resampledPoints = <CanvasPoint>[];
    if (totalLength < 1e-4) {
      // Degenerate tap
      for (var i = 0; i < _targetPointCount; i++) {
        resampledPoints.add(validStrokes.first.first);
      }
    } else {
      var pointsRemaining = _targetPointCount;
      for (var s = 0; s < validStrokes.length; s++) {
        final stroke = validStrokes[s];
        final strokeLen = strokeLengths[s];
        final count = (s == validStrokes.length - 1)
            ? pointsRemaining
            : math.max(
                2,
                ((strokeLen / totalLength) * _targetPointCount).round(),
              );
        pointsRemaining -= count;

        resampledPoints.addAll(_resampleStroke(stroke, count));
      }
    }

    // Scale to canonical box [0, 100] while preserving aspect ratio
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = -double.infinity;
    var maxY = -double.infinity;

    for (final p in resampledPoints) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    final w = math.max(1e-4, maxX - minX);
    final h = math.max(1e-4, maxY - minY);
    final scale = _canonicalSize / math.max(w, h);

    final scaledPoints = resampledPoints
        .map((p) => CanvasPoint((p.x - minX) * scale, (p.y - minY) * scale))
        .toList();

    // Center at origin (0, 0)
    var sumX = 0.0;
    var sumY = 0.0;
    for (final p in scaledPoints) {
      sumX += p.x;
      sumY += p.y;
    }
    final centroid = CanvasPoint(
      sumX / scaledPoints.length,
      sumY / scaledPoints.length,
    );

    return scaledPoints.map((p) => p - centroid).toList();
  }

  /// Resamples a single polyline into [count] equidistant points.
  static List<CanvasPoint> _resampleStroke(
    List<CanvasPoint> stroke,
    int count,
  ) {
    if (stroke.length <= 1 || count <= 1) {
      return List.filled(count, stroke.first);
    }

    var totalLen = 0.0;
    for (var i = 0; i < stroke.length - 1; i++) {
      totalLen += (stroke[i + 1] - stroke[i]).length;
    }

    final interval = totalLen / (count - 1);
    final result = <CanvasPoint>[stroke.first];
    var currentDist = 0.0;
    var segIdx = 0;
    var prev = stroke[0];

    while (result.length < count && segIdx < stroke.length - 1) {
      final next = stroke[segIdx + 1];
      final segLen = (next - prev).length;

      if (currentDist + segLen >= interval) {
        final t = (interval - currentDist) / math.max(1e-6, segLen);
        final interp = CanvasPoint(
          prev.x + t * (next.x - prev.x),
          prev.y + t * (next.y - prev.y),
        );
        result.add(interp);
        prev = interp;
        currentDist = 0.0;
      } else {
        currentDist += segLen;
        segIdx++;
        if (segIdx < stroke.length - 1) {
          prev = stroke[segIdx];
        }
      }
    }

    while (result.length < count) {
      result.add(stroke.last);
    }

    return result;
  }

  /// Calculates symmetric Chamfer point-cloud distance between two normalized clouds.
  static double _cloudDistance(List<CanvasPoint> a, List<CanvasPoint> b) {
    var sumA = 0.0;
    for (final p in a) {
      var minDist = double.infinity;
      for (final q in b) {
        final d = (p - q).length;
        if (d < minDist) minDist = d;
      }
      sumA += minDist;
    }

    var sumB = 0.0;
    for (final q in b) {
      var minDist = double.infinity;
      for (final p in a) {
        final d = (q - p).length;
        if (d < minDist) minDist = d;
      }
      sumB += minDist;
    }

    return (sumA / a.length + sumB / b.length) / 2.0;
  }
}

/// Global recognizer singleton for quick access.
final CharacterRecognizer globalCharacterRecognizer = CharacterRecognizer();

/// Convenience function to recognize a character from an ink [CanvasElement].
RecognizedCharacter? recognizeCharacterFromInk(
  CanvasElement inkElement, {
  double minConfidence = 0.65,
}) {
  if (inkElement.points.isEmpty) return null;
  final stroke = inkElement.points
      .map((p) => CanvasPoint(inkElement.x + p.x, inkElement.y + p.y))
      .toList();

  return globalCharacterRecognizer.recognize(
    [stroke],
    bounds: inkElement.bounds,
    minConfidence: minConfidence,
  );
}

/// Converts an ink [CanvasElement] into a clean text character [CanvasElement].
CanvasElement convertInkToText(CanvasElement inkElement, {String? text}) {
  final recognized = text != null
      ? null
      : recognizeCharacterFromInk(inkElement);
  final char = text ?? recognized?.char ?? 'A';
  final bounds = inkElement.bounds;

  final finalW = math.max(40.0, bounds.width);
  final finalH = math.max(40.0, bounds.height);

  return CanvasElement({
    'id': inkElement.id,
    'type': 'text',
    'x': bounds.left,
    'y': bounds.top,
    'width': finalW,
    'height': finalH,
    'color': inkElement.color,
    'text': char,
    if (inkElement.groupId != null) 'groupId': inkElement.groupId,
  });
}

// =============================================================================
// Canonical Handwriting Character Templates
// Coordinates defined on standard [0, 100] coordinate space.
// =============================================================================

CanvasPoint _p(double x, double y) => CanvasPoint(x, y);

final List<_CharacterTemplate> _templates = [
  // --- DIGITS (0 - 9) ---
  _CharacterTemplate(
    char: '0',
    isDigit: true,
    strokes: [
      [
        _p(50, 0),
        _p(15, 30),
        _p(15, 70),
        _p(50, 100),
        _p(85, 70),
        _p(85, 30),
        _p(50, 0),
      ],
    ],
  ),
  _CharacterTemplate(
    char: '1',
    isDigit: true,
    strokes: [
      [_p(50, 0), _p(50, 100)],
    ],
  ),
  _CharacterTemplate(
    char: '1',
    isDigit: true,
    strokes: [
      [_p(25, 25), _p(50, 0), _p(50, 100)],
    ],
  ),
  _CharacterTemplate(
    char: '2',
    isDigit: true,
    strokes: [
      [_p(20, 25), _p(50, 0), _p(85, 25), _p(50, 65), _p(15, 100), _p(85, 100)],
    ],
  ),
  _CharacterTemplate(
    char: '3',
    isDigit: true,
    strokes: [
      [
        _p(20, 10),
        _p(75, 10),
        _p(85, 35),
        _p(50, 50),
        _p(85, 65),
        _p(75, 90),
        _p(20, 90),
      ],
    ],
  ),
  _CharacterTemplate(
    char: '4',
    isDigit: true,
    strokes: [
      [_p(75, 15), _p(20, 65), _p(90, 65)],
      [_p(75, 10), _p(75, 100)],
    ],
  ),
  _CharacterTemplate(
    char: '4',
    isDigit: true,
    strokes: [
      [_p(75, 0), _p(20, 65), _p(85, 65), _p(75, 20), _p(75, 100)],
    ],
  ),
  _CharacterTemplate(
    char: '5',
    isDigit: true,
    strokes: [
      [
        _p(80, 0),
        _p(25, 0),
        _p(20, 45),
        _p(75, 55),
        _p(80, 80),
        _p(50, 100),
        _p(20, 90),
      ],
    ],
  ),
  _CharacterTemplate(
    char: '6',
    isDigit: true,
    strokes: [
      [
        _p(75, 15),
        _p(30, 45),
        _p(20, 75),
        _p(50, 100),
        _p(80, 75),
        _p(50, 50),
        _p(25, 70),
      ],
    ],
  ),
  _CharacterTemplate(
    char: '7',
    isDigit: true,
    strokes: [
      [_p(15, 0), _p(85, 0), _p(35, 100)],
    ],
  ),
  _CharacterTemplate(
    char: '8',
    isDigit: true,
    strokes: [
      [
        _p(50, 50),
        _p(25, 25),
        _p(50, 0),
        _p(75, 25),
        _p(50, 50),
        _p(25, 75),
        _p(50, 100),
        _p(75, 75),
        _p(50, 50),
      ],
    ],
  ),
  _CharacterTemplate(
    char: '9',
    isDigit: true,
    strokes: [
      [
        _p(80, 50),
        _p(50, 50),
        _p(20, 25),
        _p(50, 0),
        _p(80, 25),
        _p(80, 85),
        _p(50, 100),
      ],
    ],
  ),

  // --- CAPITAL LETTERS (A - Z) ---
  _CharacterTemplate(
    char: 'A',
    isLetter: true,
    strokes: [
      [_p(15, 100), _p(50, 0), _p(85, 100)],
      [_p(30, 60), _p(70, 60)],
    ],
  ),
  _CharacterTemplate(
    char: 'A',
    isLetter: true,
    strokes: [
      [_p(15, 100), _p(50, 0), _p(85, 100), _p(30, 60), _p(70, 60)],
    ],
  ),
  _CharacterTemplate(
    char: 'B',
    isLetter: true,
    strokes: [
      [_p(20, 100), _p(20, 0)],
      [_p(20, 0), _p(75, 25), _p(20, 50), _p(80, 75), _p(20, 100)],
    ],
  ),
  _CharacterTemplate(
    char: 'B',
    isLetter: true,
    strokes: [
      [_p(20, 100), _p(20, 0), _p(75, 25), _p(20, 50), _p(80, 75), _p(20, 100)],
    ],
  ),
  _CharacterTemplate(
    char: 'C',
    isLetter: true,
    strokes: [
      [_p(85, 20), _p(50, 0), _p(15, 50), _p(50, 100), _p(85, 80)],
    ],
  ),
  _CharacterTemplate(
    char: 'D',
    isLetter: true,
    strokes: [
      [_p(20, 100), _p(20, 0)],
      [_p(20, 0), _p(85, 50), _p(20, 100)],
    ],
  ),
  _CharacterTemplate(
    char: 'D',
    isLetter: true,
    strokes: [
      [_p(20, 100), _p(20, 0), _p(85, 50), _p(20, 100)],
    ],
  ),
  _CharacterTemplate(
    char: 'E',
    isLetter: true,
    strokes: [
      [_p(85, 0), _p(20, 0), _p(20, 100), _p(85, 100)],
      [_p(20, 50), _p(70, 50)],
    ],
  ),
  _CharacterTemplate(
    char: 'F',
    isLetter: true,
    strokes: [
      [_p(85, 0), _p(20, 0), _p(20, 100)],
      [_p(20, 50), _p(70, 50)],
    ],
  ),
  _CharacterTemplate(
    char: 'G',
    isLetter: true,
    strokes: [
      [
        _p(85, 20),
        _p(50, 0),
        _p(15, 50),
        _p(50, 100),
        _p(85, 80),
        _p(85, 55),
        _p(55, 55),
      ],
    ],
  ),
  _CharacterTemplate(
    char: 'H',
    isLetter: true,
    strokes: [
      [_p(20, 0), _p(20, 100)],
      [_p(80, 0), _p(80, 100)],
      [_p(20, 50), _p(80, 50)],
    ],
  ),
  _CharacterTemplate(
    char: 'I',
    isLetter: true,
    strokes: [
      [_p(50, 0), _p(50, 100)],
    ],
  ),
  _CharacterTemplate(
    char: 'J',
    isLetter: true,
    strokes: [
      [_p(75, 0), _p(75, 80), _p(50, 100), _p(25, 80)],
    ],
  ),
  _CharacterTemplate(
    char: 'K',
    isLetter: true,
    strokes: [
      [_p(25, 0), _p(25, 100)],
      [_p(85, 10), _p(25, 55), _p(85, 100)],
    ],
  ),
  _CharacterTemplate(
    char: 'L',
    isLetter: true,
    strokes: [
      [_p(25, 0), _p(25, 100), _p(85, 100)],
    ],
  ),
  _CharacterTemplate(
    char: 'M',
    isLetter: true,
    strokes: [
      [_p(15, 100), _p(25, 0), _p(50, 60), _p(75, 0), _p(85, 100)],
    ],
  ),
  _CharacterTemplate(
    char: 'N',
    isLetter: true,
    strokes: [
      [_p(20, 100), _p(20, 0), _p(80, 100), _p(80, 0)],
    ],
  ),
  _CharacterTemplate(
    char: 'O',
    isLetter: true,
    strokes: [
      [_p(50, 0), _p(15, 50), _p(50, 100), _p(85, 50), _p(50, 0)],
    ],
  ),
  _CharacterTemplate(
    char: 'P',
    isLetter: true,
    strokes: [
      [_p(20, 100), _p(20, 0), _p(80, 25), _p(20, 50)],
    ],
  ),
  _CharacterTemplate(
    char: 'Q',
    isLetter: true,
    strokes: [
      [_p(50, 0), _p(15, 50), _p(50, 100), _p(85, 50), _p(50, 0)],
      [_p(65, 75), _p(90, 100)],
    ],
  ),
  _CharacterTemplate(
    char: 'R',
    isLetter: true,
    strokes: [
      [_p(20, 100), _p(20, 0), _p(80, 25), _p(20, 50), _p(85, 100)],
    ],
  ),
  _CharacterTemplate(
    char: 'S',
    isLetter: true,
    strokes: [
      [
        _p(85, 20),
        _p(50, 0),
        _p(20, 25),
        _p(50, 50),
        _p(80, 75),
        _p(50, 100),
        _p(15, 80),
      ],
    ],
  ),
  _CharacterTemplate(
    char: 'T',
    isLetter: true,
    strokes: [
      [_p(15, 0), _p(85, 0)],
      [_p(50, 0), _p(50, 100)],
    ],
  ),
  _CharacterTemplate(
    char: 'T',
    isLetter: true,
    strokes: [
      [_p(15, 0), _p(85, 0), _p(50, 0), _p(50, 100)],
    ],
  ),
  _CharacterTemplate(
    char: 'U',
    isLetter: true,
    strokes: [
      [_p(20, 0), _p(20, 80), _p(50, 100), _p(80, 80), _p(80, 0)],
    ],
  ),
  _CharacterTemplate(
    char: 'V',
    isLetter: true,
    strokes: [
      [_p(20, 0), _p(50, 100), _p(80, 0)],
    ],
  ),
  _CharacterTemplate(
    char: 'W',
    isLetter: true,
    strokes: [
      [_p(15, 0), _p(30, 100), _p(50, 40), _p(70, 100), _p(85, 0)],
    ],
  ),
  _CharacterTemplate(
    char: 'X',
    isLetter: true,
    strokes: [
      [_p(15, 10), _p(85, 90)],
      [_p(85, 10), _p(15, 90)],
    ],
  ),
  _CharacterTemplate(
    char: 'Y',
    isLetter: true,
    strokes: [
      [_p(20, 0), _p(50, 50)],
      [_p(80, 0), _p(50, 50), _p(50, 100)],
    ],
  ),
  _CharacterTemplate(
    char: 'Z',
    isLetter: true,
    strokes: [
      [_p(15, 10), _p(85, 10), _p(15, 90), _p(85, 90)],
    ],
  ),

  // --- LOWERCASE COMMON LETTERS ---
  _CharacterTemplate(
    char: 'a',
    isLetter: true,
    strokes: [
      [
        _p(75, 40),
        _p(40, 40),
        _p(20, 70),
        _p(50, 100),
        _p(80, 70),
        _p(80, 100),
      ],
    ],
  ),
  _CharacterTemplate(
    char: 'b',
    isLetter: true,
    strokes: [
      [_p(25, 0), _p(25, 100), _p(75, 75), _p(75, 45), _p(25, 45)],
    ],
  ),
  _CharacterTemplate(
    char: 'd',
    isLetter: true,
    strokes: [
      [_p(75, 55), _p(25, 55), _p(25, 85), _p(75, 100), _p(75, 0)],
    ],
  ),
  _CharacterTemplate(
    char: 'e',
    isLetter: true,
    strokes: [
      [_p(25, 60), _p(80, 60), _p(55, 30), _p(25, 60), _p(50, 95), _p(85, 85)],
    ],
  ),
  _CharacterTemplate(
    char: 'h',
    isLetter: true,
    strokes: [
      [_p(25, 0), _p(25, 100), _p(25, 50), _p(75, 50), _p(75, 100)],
    ],
  ),
  _CharacterTemplate(
    char: 'r',
    isLetter: true,
    strokes: [
      [_p(25, 100), _p(25, 35), _p(25, 45), _p(75, 35)],
    ],
  ),
  _CharacterTemplate(
    char: 't',
    isLetter: true,
    strokes: [
      [_p(50, 0), _p(50, 90), _p(75, 90)],
      [_p(25, 35), _p(75, 35)],
    ],
  ),

  // --- SYMBOLS ---
  _CharacterTemplate(
    char: '+',
    isSymbol: true,
    strokes: [
      [_p(50, 15), _p(50, 85)],
      [_p(15, 50), _p(85, 50)],
    ],
  ),
  _CharacterTemplate(
    char: '-',
    isSymbol: true,
    strokes: [
      [_p(15, 50), _p(85, 50)],
    ],
  ),
  _CharacterTemplate(
    char: '=',
    isSymbol: true,
    strokes: [
      [_p(15, 35), _p(85, 35)],
      [_p(15, 65), _p(85, 65)],
    ],
  ),
  _CharacterTemplate(
    char: '?',
    isSymbol: true,
    strokes: [
      [_p(20, 30), _p(50, 10), _p(80, 30), _p(50, 60), _p(50, 75)],
      [_p(50, 95), _p(50, 98)],
    ],
  ),
  _CharacterTemplate(
    char: '!',
    isSymbol: true,
    strokes: [
      [_p(50, 10), _p(50, 75)],
      [_p(50, 95), _p(50, 98)],
    ],
  ),
];
