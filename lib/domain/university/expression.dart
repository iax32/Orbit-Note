typedef LabValues = Map<String, Object>;
typedef _Expr = Object Function(LabValues);

/// Small deterministic teaching language; never evaluates Dart or user code.
class LabExpression {
  LabExpression(String source) {
    if (source.length > 2000) {
      throw const FormatException('Expression too long.');
    }
    final pattern = RegExp(
      r'\s+|\d+(?:\.\d+)?|[A-Za-z_]\w*|==|!=|<=|>=|&&|\|\||[()+*/%<>!\-]',
    );
    var offset = 0;
    for (final m in pattern.allMatches(source)) {
      if (m.start != offset) {
        throw const FormatException('Unsupported expression syntax.');
      }
      offset = m.end;
      if (m[0]!.trim().isNotEmpty) tokens.add(m[0]!);
    }
    if (offset != source.length || tokens.length > 500) {
      throw const FormatException('Unsupported expression syntax.');
    }
    _root = _binary(0);
    if (index != tokens.length) {
      throw const FormatException('Unexpected expression token.');
    }
  }
  final tokens = <String>[];
  int index = 0;
  late final _Expr _root;
  static const _levels = [
    ['||'],
    ['&&'],
    ['==', '!='],
    ['<', '<=', '>', '>='],
    ['+', '-'],
    ['*', '/', '%'],
  ];
  bool _take(String token) {
    if (index < tokens.length && tokens[index] == token) {
      index++;
      return true;
    }
    return false;
  }

  _Expr _binary(int level) {
    if (level == _levels.length) return _atom();
    var left = _binary(level + 1);
    while (index < tokens.length && _levels[level].contains(tokens[index])) {
      final op = tokens[index++], a = left, b = _binary(level + 1);
      left = (v) {
        final x = a(v);
        if (op == '&&') return truth(x) && truth(b(v));
        if (op == '||') return truth(x) || truth(b(v));
        final y = b(v);
        if (op == '==') return x == y;
        if (op == '!=') return x != y;
        final n = number(x), m = number(y);
        return switch (op) {
          '<' => n < m,
          '<=' => n <= m,
          '>' => n > m,
          '>=' => n >= m,
          '+' => finite(n + m),
          '-' => finite(n - m),
          '*' => finite(n * m),
          '/' =>
            m == 0
                ? throw const FormatException('Division by zero.')
                : finite(n / m),
          '%' =>
            m == 0
                ? throw const FormatException('Division by zero.')
                : finite(n % m),
          _ => throw const FormatException('Unsupported operator.'),
        };
      };
    }
    return left;
  }

  _Expr _atom() {
    if (_take('!')) {
      final a = _atom();
      return (v) => !truth(a(v));
    }
    if (_take('-')) {
      final a = _atom();
      return (v) => finite(-number(a(v)));
    }
    if (_take('(')) {
      final a = _binary(0);
      if (!_take(')')) {
        throw const FormatException('Missing closing parenthesis.');
      }
      return a;
    }
    if (index >= tokens.length) {
      throw const FormatException('Missing expression.');
    }
    final t = tokens[index++], n = num.tryParse(t);
    if (n != null) return (_) => finite(n);
    if (t == 'true' || t == 'false') return (_) => t == 'true';
    if (!RegExp(r'^[A-Za-z_]\w*$').hasMatch(t)) {
      throw const FormatException('Invalid variable.');
    }
    return (v) => v[t] ?? (throw FormatException('Unknown variable: $t'));
  }

  Object evaluate(LabValues values) => _root(values);
  static bool truth(Object value) => value is bool
      ? value
      : throw const FormatException('A guard must be boolean.');
  static num number(Object value) =>
      value is num ? value : throw const FormatException('Expected a number.');
  static num finite(num n) => n.isFinite && n.abs() <= 1e12
      ? n
      : throw const FormatException('Numeric teaching limit exceeded.');
}

bool labGuard(String source, LabValues values) =>
    source.trim().isEmpty ||
    LabExpression.truth(LabExpression(source).evaluate(values));

void labActions(String source, LabValues values, List<String> log) {
  if (source.length > 4000) {
    throw const FormatException('Action list too long.');
  }
  final statements = source.split(';');
  if (statements.length > 100 || log.length + statements.length > 1000) {
    throw const FormatException(
      'Action budget exceeded; split this teaching run.',
    );
  }
  for (final raw in statements) {
    final text = raw.trim();
    if (text.isEmpty) continue;
    final increment = RegExp(r'^([A-Za-z_]\w*)(\+\+|--)$').firstMatch(text);
    if (increment != null) {
      final key = increment[1]!;
      values[key] = LabExpression.finite(
        LabExpression.number(
              values[key] ?? (throw FormatException('Unknown variable: $key')),
            ) +
            (increment[2] == '++' ? 1 : -1),
      );
    } else {
      final assignment = RegExp(
        r'^([A-Za-z_]\w*)\s*=\s*(?!=)(.+)$',
      ).firstMatch(text);
      if (assignment == null) {
        throw FormatException('Use assignments/increments only: $text');
      }
      values[assignment[1]!] = LabExpression(assignment[2]!).evaluate(values);
    }
    log.add(text);
  }
}
