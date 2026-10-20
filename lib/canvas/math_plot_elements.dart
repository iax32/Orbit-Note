import 'dart:math' as math;
import '../domain/math_result.dart';
import '../domain/math_plot_svg.dart';
import 'scene.dart';
import 'geometry.dart';

/// A plot is a normal editable Canvas snapshot, using the existing ink engine.
List<CanvasElement> mathResultElements(
  MathLabResult result,
  CanvasPoint origin,
  int color,
  String Function() id,
) {
  final group = id();
  final elements = <CanvasElement>[];
  void add(Map<String, dynamic> data) => elements.add(
    CanvasElement({'id': id(), 'groupId': group, 'color': color, ...data}),
  );
  add({
    'type': 'sticky',
    'x': origin.x,
    'y': origin.y,
    'width': result.tableDefinition == null
        ? 360.0
        : math.max(
            360.0,
            (result.tableDefinition!.functions.length + 1) * 180.0 + 64,
          ),
    'height':
        (200 +
                result.description.split('\n').length * 20 +
                RegExp(r'\\\\').allMatches(result.tex).length * 24)
            .clamp(300, 800)
            .toDouble(),
    'text': result.equationMarkdown,
  });
  final plots =
      result.plotDefinition?.sample() ??
      [if (result.plot != null) result.plot!];
  if (plots.isEmpty) return elements;
  final plot = plots.first;
  const width = 520.0, height = 320.0;
  final left = origin.x + 390, top = origin.y;
  CanvasPoint project(double x, double y) => CanvasPoint(
    left + (x - plot.xMin) / (plot.xMax - plot.xMin) * width,
    top + (plot.yMax - y) / (plot.yMax - plot.yMin) * height,
  );
  void line(CanvasPoint a, CanvasPoint b, double stroke) => add({
    'type': 'line',
    'startX': a.x,
    'startY': a.y,
    'endX': b.x,
    'endY': b.y,
    'strokeWidth': stroke,
    'endMarker': 'none',
  });
  // Faint grid uses exactly the same editable line primitives as hand drawing.
  for (var i = 0; i <= 10; i++) {
    line(
      CanvasPoint(left + i * width / 10, top),
      CanvasPoint(left + i * width / 10, top + height),
      .35,
    );
    line(
      CanvasPoint(left, top + i * height / 10),
      CanvasPoint(left + width, top + i * height / 10),
      .35,
    );
  }
  if (plot.xMin <= 0 && plot.xMax >= 0) {
    line(project(0, plot.yMin), project(0, plot.yMax), 1.5);
  }
  if (plot.yMin <= 0 && plot.yMax >= 0) {
    line(project(plot.xMin, 0), project(plot.xMax, 0), 1.5);
  }
  for (var series = 0; series < plots.length; series++) {
    for (final segment in plots[series].segments) {
      final points = segment.map((p) => project(p.$1, p.$2)).toList();
      final x = points.map((p) => p.x).reduce(math.min),
          y = points.map((p) => p.y).reduce(math.min);
      add({
        'type': 'ink',
        'color': series == 0 ? color : mathSeriesColors[series],
        'x': x,
        'y': y,
        'width': math.max(1.0, points.map((p) => p.x).reduce(math.max) - x),
        'height': math.max(1.0, points.map((p) => p.y).reduce(math.max) - y),
        'strokeWidth': 2.0,
        'penStyle': 'pen',
        'points': [
          for (final p in points) {'x': p.x - x, 'y': p.y - y},
        ],
      });
    }
  }
  add({
    'type': 'text',
    'x': left,
    'y': top + height + 12,
    'width': width,
    'height': 80.0 + plots.length * 20,
    'fontSize': 14.0,
    'text':
        'Sampled graph • x: ${plot.xMin} to ${plot.xMax} • y: ${plot.yMin} to ${plot.yMax}\nEditable snapshot; gaps may be missed. Ungroup to edit individual strokes.\n${result.plotDefinition?.functions.indexed.map((e) => 'f${e.$1 + 1}(x)=${e.$2}').join('\n') ?? ''}',
  });
  return elements;
}
