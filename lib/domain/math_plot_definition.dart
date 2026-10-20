import 'dart:convert';
import 'math_lab.dart';

/// A portable, bounded graph recipe. It owns expressions, never image bytes.
class MathPlotDefinition {
  MathPlotDefinition._(
    this.data,
    this.functions,
    this.variables,
    this.xMin,
    this.xMax,
    this.yMin,
    this.yMax,
  );
  final Map<String, dynamic> data;
  final List<String> functions;
  final Map<String, double> variables;
  final double xMin, xMax, yMin, yMax;
  String get title => data['title'] as String? ?? 'Function plot';
  String get json => const JsonEncoder.withIndent('  ').convert(data);
  String get markdown => '```orbit-plot\n$json\n```';

  factory MathPlotDefinition.create({
    required List<String> functions,
    Map<String, double> variables = const {},
    double xMin = -5,
    double xMax = 5,
    double yMin = -5,
    double yMax = 5,
    Map<String, dynamic> original = const {},
  }) => MathPlotDefinition._fromJson({
    ...original,
    'version': 1,
    'functions': functions,
    'variables': variables,
    'window': {
      ...(original['window'] is Map
          ? Map<String, dynamic>.from(original['window'] as Map)
          : <String, dynamic>{}),
      'xMin': xMin,
      'xMax': xMax,
      'yMin': yMin,
      'yMax': yMax,
    },
  });

  factory MathPlotDefinition._fromJson(Map<String, dynamic> data) {
    if (data['version'] != 1 ||
        data['functions'] is! List ||
        data['variables'] is! Map ||
        data['window'] is! Map) {
      throw const FormatException('Unsupported plot recipe.');
    }
    final rawFunctions = data['functions'] as List;
    if (rawFunctions.isEmpty ||
        rawFunctions.length > 4 ||
        rawFunctions.any(
          (f) =>
              f is! String || f.trim().isEmpty || f.contains(RegExp(r'[\r\n]')),
        )) {
      throw const FormatException('Use one to four function expressions.');
    }
    final functions = rawFunctions.cast<String>();
    final rawVariables = data['variables'] as Map;
    if (rawVariables.length > 12 ||
        rawVariables.keys.any((k) => k is! String || k == 'x') ||
        rawVariables.values.any((v) => v is! num || !v.isFinite)) {
      throw const FormatException(
        'Use at most 12 finite parameters; x is the horizontal axis.',
      );
    }
    final variables = mathVariables(
      rawVariables.entries.map((e) => '${e.key}=${e.value}').join(';'),
    );
    for (final f in functions) {
      final expression = MathExpression.parse(f);
      if (expression.variables.any(
        (name) => name != 'x' && !variables.containsKey(name),
      )) {
        throw const FormatException(
          'Define every named parameter before plotting.',
        );
      }
    }
    double bound(String key) {
      final value = (data['window'] as Map)[key];
      if (value is! num || !value.isFinite) {
        throw const FormatException(
          'Plot windows need four finite numeric bounds.',
        );
      }
      return value.toDouble();
    }

    final xMin = bound('xMin'),
        xMax = bound('xMax'),
        yMin = bound('yMin'),
        yMax = bound('yMax');
    MathPlot.validateWindow(xMin, xMax, yMin, yMax);
    if (data['title'] != null &&
        (data['title'] is! String || (data['title'] as String).length > 120)) {
      throw const FormatException(
        'Plot titles may contain at most 120 characters.',
      );
    }
    final encoded = jsonEncode(data);
    if (!_boundedJson(encoded)) {
      throw const FormatException('Plot recipe is too large or deeply nested.');
    }
    // Deep copy unknown metadata so later callers cannot mutate a saved recipe.
    return MathPlotDefinition._(
      _freeze(jsonDecode(encoded)) as Map<String, dynamic>,
      List.unmodifiable(functions),
      Map.unmodifiable(variables),
      xMin,
      xMax,
      yMin,
      yMax,
    );
  }
  static Object? _freeze(Object? value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.unmodifiable(
        value.map((k, v) => MapEntry(k, _freeze(v))),
      );
    }
    if (value is List) return List.unmodifiable(value.map(_freeze));
    return value;
  }

  static MathPlotDefinition? tryParse(String source) {
    if (!_boundedJson(source)) return null;
    try {
      final decoded = jsonDecode(source);
      return decoded is Map<String, dynamic>
          ? MathPlotDefinition._fromJson(decoded)
          : null;
    } on FormatException {
      return null;
    }
  }

  static bool _boundedJson(String source) {
    if (source.length > 65536) return false;
    var depth = 0, quoted = false, escaped = false;
    final number = RegExp(r'-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?');
    for (var index = 0; index < source.length; index++) {
      final code = source.codeUnitAt(index);
      if (quoted) {
        if (escaped) {
          escaped = false;
        } else if (code == 92) {
          escaped = true;
        } else if (code == 34) {
          quoted = false;
        }
      } else if (code == 34) {
        quoted = true;
      } else if (code == 123 || code == 91) {
        if (++depth > 32) return false;
      } else if (code == 125 || code == 93) {
        if (--depth < 0) return false;
      } else if (code == 45 || code >= 48 && code <= 57) {
        final token = number.matchAsPrefix(source, index);
        if (token == null) return false;
        final literal = token[0]!;
        try {
          final value = parseMathNumber(literal);
          if (_decimalIdentity(value.toString()) != _decimalIdentity(literal)) {
            return false;
          }
        } on FormatException {
          return false;
        }
        // Unknown integers must also round-trip exactly in a JavaScript reader.
        if (!literal.contains(RegExp(r'[.eE]')) &&
            BigInt.parse(literal).abs() > BigInt.from(9007199254740991)) {
          return false;
        }
        index = token.end - 1;
      }
    }
    return !quoted && depth == 0;
  }

  /// Refuse metadata decimals that would be rounded during JSON re-encoding.
  static String _decimalIdentity(String literal) {
    final parts = literal.toLowerCase().split('e');
    final mantissa = parts.first, negative = mantissa.startsWith('-');
    var digits = mantissa
        .replaceAll(RegExp(r'[-.]'), '')
        .replaceFirst(RegExp(r'^0+'), '');
    if (digits.isEmpty) return '0';
    final point = mantissa.indexOf('.');
    var power =
        (parts.length == 1 ? 0 : int.parse(parts[1])) -
        (point < 0 ? 0 : mantissa.length - point - 1);
    while (digits.endsWith('0')) {
      digits = digits.substring(0, digits.length - 1);
      power++;
    }
    return '${negative ? '-' : ''}$digits:$power';
  }

  List<MathPlot> sample() => functions
      .map(
        (source) => MathPlot.sample(
          MathExpression.parse(source),
          variables,
          xMin: xMin,
          xMax: xMax,
          yMin: yMin,
          yMax: yMax,
        ),
      )
      .toList();
  List<double?> valuesAt(double x) {
    if (!x.isFinite || x < xMin || x > xMax) {
      throw const FormatException('Choose x within the plot window.');
    }
    return functions.map((source) {
      try {
        return MathExpression.parse(source).evaluate({...variables, 'x': x});
      } on FormatException {
        return null;
      }
    }).toList();
  }

  List<List<double?>> table({int rows = 21}) {
    if (rows < 2 || rows > 101) {
      throw const FormatException('Value tables support 2–101 rows.');
    }
    final expressions = functions.map(MathExpression.parse).toList();
    return List.generate(rows, (i) {
      final x = i == rows - 1 ? xMax : xMin + (xMax - xMin) * i / (rows - 1);
      return [x, for (final expression in expressions) _value(expression, x)];
    });
  }

  double? _value(MathExpression expression, double x) {
    try {
      return expression.evaluate({...variables, 'x': x});
    } on FormatException {
      return null;
    }
  }

  String tableText({String separator = '\t', int rows = 21}) => ([
    [
      'x',
      for (var i = 0; i < functions.length; i++) 'f${i + 1}(x)',
    ].join(separator),
    for (final row in table(rows: rows))
      row.map((n) => n == null ? 'undefined' : n.toString()).join(separator),
  ]).join('\n');
  String tableTex({int rows = 11}) {
    final columns = 'r' * (functions.length + 1);
    final header = List.generate(
      functions.length,
      (i) => 'f_{${i + 1}}(x)',
    ).join(' & ');
    final cells = table(rows: rows)
        .map(
          (row) => row
              .map((n) => n == null ? r'\text{undefined}' : mathNumberTex(n))
              .join(' & '),
        )
        .join(r' \\ ');
    return '${r'\begin{array}'}{$columns}x & $header ${r'\\'} $cells${r'\end{array}'}';
  }
}
