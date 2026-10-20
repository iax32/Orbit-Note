import 'dart:convert';
import 'math_lab.dart';
import 'math_plot_definition.dart';

const mathSeriesColors = [0xff6750a4, 0xff087d69, 0xffac5700, 0xffbd385e];

/// Standalone vector output; no external URLs, scripts or user-provided markup.
String mathPlotSvg(MathPlotDefinition definition) {
  String escape(String text) =>
      const HtmlEscape(HtmlEscapeMode.element).convert(
        String.fromCharCodes(
          text.runes.map(
            (c) =>
                c == 9 ||
                    c == 10 ||
                    c == 13 ||
                    c >= 32 && c <= 0xd7ff ||
                    c >= 0xe000 && c <= 0xfffd ||
                    c >= 0x10000 && c <= 0x10ffff
                ? c
                : 0xfffd,
          ),
        ),
      );
  const left = 85.0, top = 55.0, width = 650.0, height = 300.0;
  double px(double x) =>
      left +
      (x - definition.xMin) / (definition.xMax - definition.xMin) * width;
  double py(double y) =>
      top +
      (definition.yMax - y) / (definition.yMax - definition.yMin) * height;
  final output = StringBuffer(
    '<svg xmlns="http://www.w3.org/2000/svg" width="760" height="490" viewBox="0 0 760 490"><title>${escape(definition.title)}</title><desc>${escape(definition.json)}</desc><rect width="760" height="490" fill="white"/><g font-family="sans-serif" font-size="12" fill="#222">',
  );
  output.write(
    '<text x="85" y="28" font-size="18">${escape(definition.title)}</text>',
  );
  for (var i = 0; i <= 5; i++) {
    final x = left + width * i / 5, y = top + height * i / 5;
    output.write(
      '<path d="M$x $top V${top + height} M$left $y H${left + width}" stroke="#ddd" fill="none"/>',
    );
    output.write(
      '<text x="$x" y="${top + height + 22}" text-anchor="${i == 0
          ? 'start'
          : i == 5
          ? 'end'
          : 'middle'}">${mathNumber(definition.xMin + (definition.xMax - definition.xMin) * i / 5)}</text>',
    );
    output.write(
      '<text x="${left - 10}" y="${y + 4}" text-anchor="end">${mathNumber(definition.yMax - (definition.yMax - definition.yMin) * i / 5)}</text>',
    );
  }
  if (definition.xMin <= 0 && definition.xMax >= 0) {
    output.write('<path d="M${px(0)} $top V${top + height}" stroke="#888"/>');
  }
  if (definition.yMin <= 0 && definition.yMax >= 0) {
    output.write('<path d="M$left ${py(0)} H${left + width}" stroke="#888"/>');
  }
  final plots = definition.sample();
  for (var i = 0; i < plots.length; i++) {
    final color =
        '#${(mathSeriesColors[i] & 0xffffff).toRadixString(16).padLeft(6, '0')}';
    for (final segment in plots[i].segments) {
      output.write(
        '<polyline points="${segment.map((p) => '${px(p.$1).toStringAsFixed(3)},${py(p.$2).toStringAsFixed(3)}').join(' ')}" stroke="$color" stroke-width="2" fill="none"/>',
      );
    }
    final raw = definition.functions[i],
        label = raw.length > 95 ? '${raw.substring(0, 95)}…' : raw;
    output.write(
      '<text x="85" y="${397 + i * 18}" fill="$color">f${i + 1}(x) = ${escape(label)}</text>',
    );
  }
  output.write(
    '<text x="85" y="479">Real numbers • radians • 257 samples per curve; discontinuities may be missed.</text></g></svg>',
  );
  return output.toString();
}
