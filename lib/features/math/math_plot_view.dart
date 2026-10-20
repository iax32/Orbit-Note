import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/math_lab.dart';
import '../../domain/math_plot_definition.dart';
import '../../domain/math_plot_svg.dart';

/// Caches samples/parsed expressions; cursor movement never reparses the graph.
class MathPlotView extends StatefulWidget {
  const MathPlotView({super.key, required this.definition});
  final MathPlotDefinition definition;
  @override
  State<MathPlotView> createState() => _MathPlotViewState();
}

class _MathPlotViewState extends State<MathPlotView> {
  late List<MathPlot> _plots;
  late List<MathExpression> _expressions;
  double? _x;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _plots = widget.definition.sample();
    _expressions = widget.definition.functions
        .map(MathExpression.parse)
        .toList();
    _x = null;
  }

  @override
  void didUpdateWidget(MathPlotView old) {
    super.didUpdateWidget(old);
    if (!identical(old.definition, widget.definition) &&
        old.definition.json != widget.definition.json) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.definition, theme = Theme.of(context);
    final colors = [
      theme.colorScheme.primary,
      for (final c in mathSeriesColors.skip(1))
        theme.brightness == Brightness.dark
            ? Color.lerp(Color(c), Colors.white, .3)!
            : Color(c),
    ];
    final values = _x == null
        ? null
        : _expressions.map((e) {
            try {
              return e.evaluate({...d.variables, 'x': _x!});
            } on FormatException {
              return null;
            }
          }).toList();
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < d.functions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'f${i + 1}(x) = ${d.functions[i]}',
              style: TextStyle(color: colors[i]),
            ),
          ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, bounds) {
            final chartHeight = 260 + 32 * scale;
            void inspect(Offset position) {
              final area = _plotArea(Size(bounds.maxWidth, chartHeight), scale);
              final ratio = ((position.dx - area.left) / area.width).clamp(
                0.0,
                1.0,
              );
              setState(() => _x = d.xMin + (d.xMax - d.xMin) * ratio);
            }

            return Semantics(
              label:
                  '${d.title}. x ${d.xMin} to ${d.xMax}; y ${d.yMin} to ${d.yMax}. ${d.functions.join('; ')}. Sampled curves; gaps may be missed.',
              child: MouseRegion(
                onHover: (e) => inspect(e.localPosition),
                child: GestureDetector(
                  onTapDown: (e) => inspect(e.localPosition),
                  child: SizedBox(
                    key: const ValueKey('math-live-plot'),
                    height: chartHeight,
                    child: CustomPaint(
                      painter: _GraphPainter(
                        _plots,
                        colors,
                        theme.colorScheme.onSurface,
                        scale,
                        _x,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (_plots.every((p) => p.segments.isEmpty))
          const Text(
            'No visible curves in this window. Edit the ranges or formulas.',
          ),
        if (_x != null)
          Semantics(
            liveRegion: true,
            child: Text(
              'x = ${mathNumber(_x!)} • ${List.generate(values!.length, (i) => 'f${i + 1} = ${values[i] == null ? 'undefined' : mathNumber(values[i]!)}').join(' • ')}',
            ),
          )
        else
          const Text('Move the pointer or tap the graph to inspect values.'),
        Slider(
          key: const ValueKey('math-plot-inspector'),
          min: d.xMin,
          max: d.xMax,
          divisions: 256,
          value: _x ?? (d.xMin + (d.xMax - d.xMin) / 2),
          semanticFormatterCallback: (value) =>
              'Inspect x = ${mathNumber(value)}',
          onChanged: (value) => setState(() => _x = value),
          onChangeStart: (value) => setState(() => _x = value),
        ),
        const Text(
          'Real numbers • radians • 257 samples per curve; gaps may be missed.',
        ),
      ],
    );
  }
}

Rect _plotArea(Size size, double scale) => Rect.fromLTWH(
  math.min(76 * scale, size.width * .3),
  16,
  math.max(1, size.width - math.min(76 * scale, size.width * .3) - 16),
  math.max(1, size.height - 16 - 40 * scale),
);

class _GraphPainter extends CustomPainter {
  const _GraphPainter(this.plots, this.colors, this.ink, this.scale, this.x);
  final List<MathPlot> plots;
  final List<Color> colors;
  final Color ink;
  final double scale;
  final double? x;
  @override
  void paint(Canvas canvas, Size size) {
    final d = plots.first, area = _plotArea(size, scale);
    Offset point(double x, double y) => Offset(
      area.left + (x - d.xMin) / (d.xMax - d.xMin) * area.width,
      area.top + (d.yMax - y) / (d.yMax - d.yMin) * area.height,
    );
    void label(
      String text,
      Offset at, {
      bool right = false,
      bool center = false,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: 11 * scale, color: ink),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: math.max(1, right ? area.left - 8 : area.width * .3));
      painter.paint(
        canvas,
        Offset(
          center
              ? at.dx - painter.width / 2
              : right
              ? at.dx - painter.width
              : at.dx,
          at.dy,
        ),
      );
    }

    final grid = Paint()
      ..color = ink.withValues(alpha: .16)
      ..strokeWidth = 1;
    for (var i = 0; i <= 5; i++) {
      final p = Offset(
        area.left + area.width * i / 5,
        area.top + area.height * i / 5,
      );
      canvas.drawLine(Offset(p.dx, area.top), Offset(p.dx, area.bottom), grid);
      canvas.drawLine(Offset(area.left, p.dy), Offset(area.right, p.dy), grid);
      // Narrow charts use only endpoint/midpoint x labels to avoid collisions.
      if (area.width > 420 * scale || i == 0 || i == 5) {
        label(
          mathNumber(d.xMin + (d.xMax - d.xMin) * i / 5),
          Offset(p.dx, area.bottom + 6),
          center: true,
        );
      }
      label(
        mathNumber(d.yMax - (d.yMax - d.yMin) * i / 5),
        Offset(area.left - 8, p.dy - 6 * scale),
        right: true,
      );
    }
    canvas.save();
    canvas.clipRect(area);
    grid.color = ink.withValues(alpha: .55);
    if (d.xMin <= 0 && d.xMax >= 0) {
      canvas.drawLine(point(0, d.yMin), point(0, d.yMax), grid);
    }
    if (d.yMin <= 0 && d.yMax >= 0) {
      canvas.drawLine(point(d.xMin, 0), point(d.xMax, 0), grid);
    }
    for (var i = 0; i < plots.length; i++) {
      final pen = Paint()
        ..color = colors[i]
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      for (final segment in plots[i].segments) {
        final first = point(segment.first.$1, segment.first.$2),
            path = Path()..moveTo(first.dx, first.dy);
        for (final p in segment.skip(1)) {
          final at = point(p.$1, p.$2);
          path.lineTo(at.dx, at.dy);
        }
        canvas.drawPath(path, pen);
      }
    }
    if (x != null) {
      final at = point(x!, d.yMin);
      canvas.drawLine(
        Offset(at.dx, area.top),
        Offset(at.dx, area.bottom),
        Paint()
          ..color = ink.withValues(alpha: .7)
          ..strokeWidth = 1,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GraphPainter old) =>
      old.plots != plots ||
      old.ink != ink ||
      old.scale != scale ||
      old.x != x ||
      old.colors.first != colors.first;
}
