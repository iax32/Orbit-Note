import 'math_lab.dart';

/// Small, bounded real matrices. No symbolic evaluation or external execution.
class MathMatrix {
  MathMatrix(List<List<double>> values)
    : values = List.unmodifiable(
        values.map((row) => List<double>.unmodifiable(row)),
      ) {
    if (values.isEmpty ||
        values.length > 6 ||
        values.first.isEmpty ||
        values.first.length > 6 ||
        values.any((r) => r.length != columns || r.any((v) => !v.isFinite))) {
      throw const FormatException(
        'Use a rectangular finite matrix, from 1×1 to 6×6.',
      );
    }
  }
  final List<List<double>> values;
  int get rows => values.length;
  int get columns => values.first.length;
  factory MathMatrix.parse(String source) {
    if (source.length > 4096) {
      throw const FormatException('Matrix input is too large.');
    }
    final rows = source.trim().split(RegExp(r'[;\r\n]+'));
    if (rows.any((row) => RegExp(r'^\s*,|,\s*$|,\s*,').hasMatch(row))) {
      throw const FormatException(
        'Fill every matrix cell; empty comma-separated cells are not zero.',
      );
    }
    return MathMatrix(
      rows
          .map(
            (row) => row.trim().split(RegExp(r'[ ,\t]+')).map((s) {
              return parseMathNumber(s);
            }).toList(),
          )
          .toList(),
    );
  }
  String get tex =>
      r'\begin{pmatrix}' +
      values.map((r) => r.map(mathNumberTex).join(' & ')).join(r' \\ ') +
      r'\end{pmatrix}';
  MathMatrix get transpose => MathMatrix(
    List.generate(columns, (c) => List.generate(rows, (r) => values[r][c])),
  );
  MathMatrix multiply(MathMatrix other) {
    if (columns != other.rows) {
      throw const FormatException('A’s columns must equal B’s rows.');
    }
    return MathMatrix(
      List.generate(
        rows,
        (r) => List.generate(other.columns, (c) {
          var sum = 0.0;
          for (var k = 0; k < columns; k++) {
            sum += values[r][k] * other.values[k][c];
          }
          return sum;
        }),
      ),
    );
  }

  void _square() {
    if (rows != columns) {
      throw const FormatException('This operation needs a square matrix.');
    }
  }

  List<List<double>> _copy() => values.map((r) => r.toList()).toList();
  double get _scale =>
      values.expand((r) => r).fold(0, (s, n) => n.abs() > s ? n.abs() : s);
  int _pivot(List<List<double>> a, int c) {
    var p = c;
    for (var r = c + 1; r < rows; r++) {
      if (a[r][c].abs() > a[p][c].abs()) p = r;
    }
    return p;
  }

  double get determinant {
    _square();
    final a = _copy();
    var result = 1.0;
    for (var c = 0; c < rows; c++) {
      final p = _pivot(a, c);
      if (a[p][c] == 0) return 0;
      if (p != c) {
        final temp = a[p];
        a[p] = a[c];
        a[c] = temp;
        result = -result;
      }
      final pivot = a[c][c];
      result *= pivot;
      for (var r = c + 1; r < rows; r++) {
        final factor = a[r][c] / pivot;
        for (var k = c + 1; k < rows; k++) {
          a[r][k] -= factor * a[c][k];
        }
      }
    }
    if (!result.isFinite) {
      throw const FormatException(
        'The determinant overflowed. Rescale the matrix.',
      );
    }
    return result;
  }

  MathMatrix get inverse {
    _square();
    final a = _copy();
    final b = List.generate(
      rows,
      (r) => List.generate(rows, (c) => r == c ? 1.0 : 0.0),
    );
    for (var c = 0; c < rows; c++) {
      final p = _pivot(a, c);
      if (a[p][c].abs() <= _scale * 1e-12) {
        throw const FormatException(
          'Matrix is singular or too poorly conditioned for a reliable inverse.',
        );
      }
      for (final matrix in [a, b]) {
        final temp = matrix[c];
        matrix[c] = matrix[p];
        matrix[p] = temp;
      }
      final pivot = a[c][c];
      for (var k = 0; k < rows; k++) {
        a[c][k] /= pivot;
        b[c][k] /= pivot;
      }
      for (var r = 0; r < rows; r++) {
        if (r == c) continue;
        final factor = a[r][c];
        for (var k = 0; k < rows; k++) {
          a[r][k] -= factor * a[c][k];
          b[r][k] -= factor * b[c][k];
        }
      }
    }
    return MathMatrix(b);
  }

  MathMatrix solve(MathMatrix right) {
    _square();
    if (right.rows != rows || right.columns != 1) {
      throw const FormatException(
        'B must be a column vector with one entry per row of A.',
      );
    }
    return inverse.multiply(right);
  }
}
