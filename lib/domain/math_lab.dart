import 'dart:math' as math;

double parseMathNumber(String source) {
  if (source.length > 128) {
    throw const FormatException(
      'Numeric values may contain at most 128 characters.',
    );
  }
  final value = double.tryParse(source.trim());
  if (value == null ||
      !value.isFinite ||
      value == 0 &&
          RegExp(r'[1-9]').hasMatch(source.split(RegExp('[eE]')).first)) {
    throw const FormatException(
      'Use finite numbers within the floating-point range, with dot decimals.',
    );
  }
  return value;
}

double _finite(num value) {
  if (!value.isFinite) {
    throw const FormatException(
      'The result is outside the finite real-number domain.',
    );
  }
  return value.toDouble();
}

String mathNumber(double value) {
  _finite(value);
  if (value == 0) return '0';
  if (value.abs() < 1e12 && value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  final pieces = value.toStringAsPrecision(10).split('e');
  var mantissa = pieces.first;
  if (mantissa.contains('.')) {
    mantissa = mantissa
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  return pieces.length == 1 ? mantissa : '$mantissa e${int.parse(pieces.last)}';
}

String mathNumberTex(double value) {
  final text = mathNumber(value), pieces = text.split(' e');
  return pieces.length == 1
      ? text
      : '${pieces.first}\\times 10^{${pieces.last}}';
}

sealed class _MathNode {
  double evaluate(Map<String, double> variables);
  String get tex;
}

class _Number extends _MathNode {
  _Number(this.value);
  final double value;
  @override
  double evaluate(Map<String, double> variables) => value;
  @override
  String get tex => mathNumberTex(value);
}

class _Variable extends _MathNode {
  _Variable(this.name);
  final String name;
  @override
  double evaluate(Map<String, double> variables) => switch (name) {
    'pi' => math.pi,
    'e' => math.e,
    _ =>
      variables[name] ??
          (throw FormatException('Give "$name" a numeric value.')),
  };
  @override
  String get tex => name == 'pi'
      ? r'\pi'
      : name.length == 1 && name != '_'
      ? name
      : '\\mathrm{${name.replaceAll('_', r'\_')}}';
}

class _Unary extends _MathNode {
  _Unary(this.node);
  final _MathNode node;
  @override
  double evaluate(Map<String, double> variables) => -node.evaluate(variables);
  @override
  String get tex => '-\\left(${node.tex}\\right)';
}

class _Binary extends _MathNode {
  _Binary(this.op, this.a, this.b);
  final String op;
  final _MathNode a, b;
  @override
  double evaluate(Map<String, double> variables) {
    final left = a.evaluate(variables), right = b.evaluate(variables);
    return _finite(switch (op) {
      '+' => left + right,
      '-' => left - right,
      '*' => left * right,
      '/' =>
        right == 0
            ? throw const FormatException('Division by zero.')
            : left / right,
      '^' => math.pow(left, right),
      _ => throw const FormatException('Unknown operator.'),
    });
  }

  @override
  String get tex => switch (op) {
    '/' => '\\frac{${a.tex}}{${b.tex}}',
    '^' => '{${a.tex}}^{${b.tex}}',
    _ => '\\left(${a.tex} ${op == '*' ? r'\cdot' : op} ${b.tex}\\right)',
  };
}

class _Function extends _MathNode {
  _Function(this.name, this.argument);
  final String name;
  final _MathNode argument;
  @override
  double evaluate(Map<String, double> variables) {
    final n = argument.evaluate(variables);
    return _finite(switch (name) {
      'sin' => math.sin(n),
      'cos' => math.cos(n),
      'tan' => math.tan(n),
      'asin' => math.asin(n),
      'acos' => math.acos(n),
      'atan' => math.atan(n),
      'sqrt' => math.sqrt(n),
      'abs' => n.abs(),
      'exp' => math.exp(n),
      'ln' => math.log(n),
      'log' => math.log(n) / math.ln10,
      'floor' => n.floorToDouble(),
      'ceil' => n.ceilToDouble(),
      _ => throw const FormatException('Unsupported function.'),
    });
  }

  @override
  String get tex => switch (name) {
    'sqrt' => '\\sqrt{${argument.tex}}',
    'abs' => '\\left|${argument.tex}\\right|',
    'floor' => '\\left\\lfloor ${argument.tex}\\right\\rfloor',
    'ceil' => '\\left\\lceil ${argument.tex}\\right\\rceil',
    'asin' => '\\arcsin\\left(${argument.tex}\\right)',
    'acos' => '\\arccos\\left(${argument.tex}\\right)',
    'atan' => '\\arctan\\left(${argument.tex}\\right)',
    _ => '\\$name\\left(${argument.tex}\\right)',
  };
}

/// Bounded numeric arithmetic, not code evaluation or a symbolic TeX interpreter.
class MathExpression {
  MathExpression._(this.source, this._root, this.variables);
  factory MathExpression.parse(String source) {
    if (source.length > 4096) {
      throw const FormatException('Use at most 4,096 expression characters.');
    }
    final normalized = source
        .replaceAll('π', '(pi)')
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('−', '-');
    final parser = _MathParser(normalized);
    final root = parser.expression();
    parser.space();
    if (parser.at != normalized.length) {
      throw FormatException('Unexpected input at character ${parser.at + 1}.');
    }
    return MathExpression._(source, root, Set.unmodifiable(parser.variables));
  }
  final String source;
  final _MathNode _root;
  final Set<String> variables;
  String get tex => _root.tex;
  double evaluate([Map<String, double> values = const {}]) {
    if (values.values.any((v) => !v.isFinite)) {
      throw const FormatException('Variables must be finite numbers.');
    }
    return _finite(_root.evaluate(values));
  }
}

class _MathParser {
  _MathParser(this.source);
  final String source;
  int at = 0, depth = 0, nodes = 0;
  final variables = <String>{};
  void space() {
    while (at < source.length && RegExp(r'\s').hasMatch(source[at])) {
      at++;
    }
  }

  bool take(String token) {
    space();
    if (source.startsWith(token, at)) {
      at += token.length;
      return true;
    }
    return false;
  }

  T count<T extends _MathNode>(T node) {
    if (++nodes > 512) {
      throw const FormatException('Use at most 512 expression terms.');
    }
    return node;
  }

  _MathNode expression() {
    if (++depth > 64) {
      throw const FormatException('Expression nesting exceeds 64 levels.');
    }
    var value = term();
    while (true) {
      if (take('+')) {
        value = count(_Binary('+', value, term()));
      } else if (take('-')) {
        value = count(_Binary('-', value, term()));
      } else {
        break;
      }
    }
    depth--;
    return value;
  }

  _MathNode term() {
    var value = unary();
    while (true) {
      if (take('*')) {
        value = count(_Binary('*', value, unary()));
      } else if (take('/')) {
        value = count(_Binary('/', value, unary()));
      } else {
        space();
        if (at < source.length && RegExp(r'[A-Za-z_(]').hasMatch(source[at])) {
          value = count(_Binary('*', value, unary()));
        } else {
          break;
        }
      }
    }
    return value;
  }

  _MathNode unary() {
    if (++depth > 64) {
      throw const FormatException('Expression nesting exceeds 64 levels.');
    }
    final _MathNode value;
    if (take('+')) {
      value = unary();
    } else if (take('-')) {
      value = count(_Unary(unary()));
    } else {
      value = power();
    }
    depth--;
    return value;
  }

  _MathNode power() {
    final value = primary();
    return take('^') ? count(_Binary('^', value, unary())) : value;
  }

  _MathNode primary() {
    if (take('(')) {
      final value = expression();
      if (!take(')')) throw const FormatException('Close the parenthesis.');
      return value;
    }
    space();
    final number = RegExp(
      r'(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?',
    ).matchAsPrefix(source, at);
    if (number != null) {
      at = number.end;
      final text = number[0]!, value = double.parse(text);
      if (!value.isFinite ||
          value == 0 &&
              RegExp(r'[1-9]').hasMatch(text.split(RegExp('[eE]')).first)) {
        throw const FormatException(
          'This number is outside the supported floating-point range.',
        );
      }
      return count(_Number(value));
    }
    final name = RegExp(r'[A-Za-z_][A-Za-z0-9_]*').matchAsPrefix(source, at);
    if (name == null) {
      throw FormatException(
        'Expected a number, variable or parenthesis at character ${at + 1}.',
      );
    }
    at = name.end;
    final id = name[0]!;
    if (const [
      'sin',
      'cos',
      'tan',
      'asin',
      'acos',
      'atan',
      'sqrt',
      'abs',
      'exp',
      'ln',
      'log',
      'floor',
      'ceil',
    ].contains(id)) {
      if (!take('(')) throw FormatException('Write $id(...) with parentheses.');
      final argument = expression();
      if (!take(')')) {
        throw const FormatException('Close the function parenthesis.');
      }
      return count(_Function(id, argument));
    }
    if (id.length > 40) {
      throw const FormatException(
        'Variable names may contain up to 40 characters.',
      );
    }
    if (!['pi', 'e'].contains(id)) variables.add(id);
    if (variables.length > 12) {
      throw const FormatException('Use at most 12 variables.');
    }
    return count(_Variable(id));
  }
}

Map<String, double> mathVariables(String source) {
  if (source.length > 2048) {
    throw const FormatException('Variable definitions are too long.');
  }
  final values = <String, double>{};
  for (final line
      in source.split(RegExp(r'[;\r\n]')).where((l) => l.trim().isNotEmpty)) {
    final match = RegExp(
      r'^\s*([A-Za-z_][A-Za-z0-9_]{0,39})\s*=\s*(.+?)\s*$',
    ).firstMatch(line);
    if (match == null ||
        ['pi', 'e'].contains(match[1]) ||
        values.containsKey(match[1])) {
      throw const FormatException(
        'Use unique name=value definitions; pi and e are constants.',
      );
    }
    final value = parseMathNumber(match[2]!);
    values[match[1]!] = value;
    if (values.length > 12) {
      throw const FormatException('Use at most 12 variable definitions.');
    }
  }
  return values;
}

class NumericEstimate {
  const NumericEstimate(this.value, this.error, this.samples);
  final double value, error;
  final int samples;
}

NumericEstimate numericDerivative(
  MathExpression expression,
  double x,
  Map<String, double> variables,
) {
  _finite(x);
  final h = 1e-4 * math.max(1, x.abs());
  double f(double at) => expression.evaluate({...variables, 'x': at});
  final center = f(x), left = f(x - h), right = f(x + h);
  final nearLeft = f(x - h / 2), nearRight = f(x + h / 2);
  final coarse = _finite((right - left) / (2 * h));
  final fine = _finite((nearRight - nearLeft) / h);
  final coarseGap = ((right - center) / h - (center - left) / h).abs();
  final fineGap =
      ((nearRight - center) / (h / 2) - (center - nearLeft) / (h / 2)).abs();
  // Refuse clear corners/steps whose one-sided disagreement does not shrink.
  // This is a sampled diagnostic, not a differentiability proof.
  if (!coarseGap.isFinite ||
      !fineGap.isFinite ||
      fineGap > 1e-6 * math.max(1, fine.abs()) && fineGap >= coarseGap * .9) {
    throw const FormatException(
      'One-sided slopes do not agree. Check for a corner, jump or rapid oscillation.',
    );
  }
  return NumericEstimate(
    _finite((4 * fine - coarse) / 3),
    _finite((fine - coarse).abs() / 3),
    5,
  );
}

NumericEstimate numericIntegral(
  MathExpression expression,
  double a,
  double b,
  Map<String, double> variables,
) {
  if (!a.isFinite || !b.isFinite || a.abs() > 1e6 || b.abs() > 1e6 || a >= b) {
    throw const FormatException(
      'Choose increasing finite bounds within ±1,000,000.',
    );
  }
  double simpson(int n) {
    final h = (b - a) / n;
    var sum = 0.0;
    for (var i = 0; i <= n; i++) {
      final value = expression.evaluate({...variables, 'x': a + i * h});
      sum = _finite(
        sum +
            (i == 0 || i == n
                    ? 1
                    : i.isOdd
                    ? 4
                    : 2) *
                value,
      );
    }
    return _finite(sum * h / 3);
  }

  final coarse = simpson(128), fine = simpson(256);
  return NumericEstimate(fine, _finite((fine - coarse).abs() / 15), 386);
}

NumericEstimate numericRoot(
  MathExpression expression,
  double a,
  double b,
  Map<String, double> variables,
) {
  if (!a.isFinite || !b.isFinite || a >= b || a.abs() > 1e6 || b.abs() > 1e6) {
    throw const FormatException(
      'Choose increasing finite bounds within ±1,000,000.',
    );
  }
  double f(double x) => expression.evaluate({...variables, 'x': x});
  var left = f(a), right = f(b);
  if (left == 0) return NumericEstimate(a, 0, 2);
  if (right == 0) return NumericEstimate(b, 0, 2);
  if ((left < 0) == (right < 0)) {
    throw const FormatException(
      'Root finding needs opposite signs at the two bounds.',
    );
  }
  final tolerance = 1e-10 * math.max(left.abs(), right.abs());
  for (var i = 0; i < 100; i++) {
    final mid = a + (b - a) / 2, value = f(mid);
    if (value == 0 ||
        value.abs() <= tolerance &&
            (b - a).abs() <= 1e-9 * math.max(1, mid.abs())) {
      return NumericEstimate(mid, value.abs(), i + 3);
    }
    if (mid == a || mid == b) break;
    if ((left < 0) == (value < 0)) {
      a = mid;
      left = value;
    } else {
      b = mid;
      right = value;
    }
  }
  throw const FormatException(
    'Root residual did not converge. Check continuity and the bracket.',
  );
}

class MathPlot {
  const MathPlot(this.points, this.xMin, this.xMax, this.yMin, this.yMax);
  final List<(double, double?)> points;
  final double xMin, xMax, yMin, yMax;
  static void validateWindow(
    double xMin,
    double xMax,
    double yMin,
    double yMax,
  ) {
    if (![xMin, xMax, yMin, yMax].every((n) => n.isFinite && n.abs() <= 1e6) ||
        xMin >= xMax ||
        yMin >= yMax) {
      throw const FormatException(
        'Plot windows need increasing finite bounds within ±1,000,000.',
      );
    }
    if (xMin + (xMax - xMin) / 256 == xMin ||
        yMin + (yMax - yMin) / 256 == yMin) {
      throw const FormatException(
        'Plot window is too small for distinct floating-point samples.',
      );
    }
  }

  static MathPlot sample(
    MathExpression expression,
    Map<String, double> variables, {
    double xMin = -5,
    double xMax = 5,
    double yMin = -5,
    double yMax = 5,
  }) {
    validateWindow(xMin, xMax, yMin, yMax);
    // Validate missing names before domain failures are represented as gaps.
    if (expression.variables.any(
      (v) => v != 'x' && !variables.containsKey(v),
    )) {
      throw const FormatException(
        'Define all named parameters before plotting.',
      );
    }
    final points = <(double, double?)>[];
    for (var i = 0; i <= 256; i++) {
      final x = xMin + (xMax - xMin) * i / 256;
      double? y;
      try {
        final value = expression.evaluate({...variables, 'x': x});
        if (value >= yMin && value <= yMax) y = value;
      } on FormatException {
        y = null;
      }
      points.add((x, y));
    }
    return MathPlot(List.unmodifiable(points), xMin, xMax, yMin, yMax);
  }

  List<List<(double, double)>> get segments {
    final result = <List<(double, double)>>[];
    var current = <(double, double)>[];
    for (final (x, y) in points) {
      if (y == null ||
          current.isNotEmpty &&
              (current.last.$2 - y).abs() > (yMax - yMin) * .8) {
        if (current.length > 1) result.add(current);
        current = [];
      }
      if (y != null) current.add((x, y));
    }
    if (current.length > 1) result.add(current);
    return result;
  }
}
