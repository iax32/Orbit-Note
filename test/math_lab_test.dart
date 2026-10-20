import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/math_lab.dart';
import 'package:orbit_note/domain/math_matrix.dart';
import 'package:orbit_note/domain/math_result.dart';
import 'package:orbit_note/canvas/math_plot_elements.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/canvas/canvas_svg.dart';

void main() {
  test('TeX-only results retain named inputs and reject invalid metadata', () {
    final result = const MathLabResult(
      'a+b=5',
      'Sum',
    ).withVariables({'a': 2, 'b': 3});
    expect(result.tex, contains(r'\mathrm{a}=2'));
    expect(result.tex, contains(r'\mathrm{b}=3'));
    expect(() => result.withVariables({'bad}name': 2}), throwsFormatException);
    expect(
      () => result.withVariables({'a': double.infinity}),
      throwsFormatException,
    );
  });
  test(
    'arithmetic preserves precedence, implicit multiplication and signed powers',
    () {
      final cases = {
        '2+3*4': 14.0,
        '-2^2': -4.0,
        '(-2)^2': 4.0,
        '2^3^2': 512.0,
        '2^-2': .25,
        '2(3+4)': 14.0,
        '1e-3 + .5': .501,
        '8/2/2': 2.0,
      };
      for (final entry in cases.entries) {
        expect(
          MathExpression.parse(entry.key).evaluate(),
          closeTo(entry.value, 1e-12),
          reason: entry.key,
        );
      }
      expect(
        MathExpression.parse('2pi').evaluate(),
        closeTo(2 * math.pi, 1e-12),
      );
      expect(
        MathExpression.parse(
          'a*x^2+b',
        ).evaluate(mathVariables('a=2; x=3\nb=1')),
        19,
      );
    },
  );
  test('real functions and constants use radians', () {
    expect(
      MathExpression.parse(
        'sin(pi/2)+cos(0)+sqrt(9)+ln(e)+log(100)',
      ).evaluate(),
      closeTo(8, 1e-12),
    );
    expect(
      MathExpression.parse('asin(1)+acos(0)+atan(1)').evaluate(),
      closeTo(1.25 * math.pi, 1e-12),
    );
    expect(MathExpression.parse('abs(-2)+floor(1.9)+ceil(1.1)').evaluate(), 5);
  });
  test('bad domains, nonfinite results and missing parameters refuse', () {
    for (final source in [
      '1/0',
      'sqrt(-1)',
      'ln(0)',
      'asin(2)',
      '(-1)^0.5',
      'exp(1000)',
      'x+1',
      '1e308*2',
    ]) {
      expect(
        () => MathExpression.parse(source).evaluate(),
        throwsFormatException,
        reason: source,
      );
    }
    expect(
      () => MathExpression.parse('x').evaluate({'x': double.nan}),
      throwsFormatException,
    );
  });
  test('untrusted expressions are bounded and never executed', () {
    for (final source in [
      '',
      '1; exit()',
      r'\frac{1}{2}',
      'import("os")',
      '2**3',
      'sin()',
      '1e999',
      '1e-999',
      '1+${'(' * 80}2${')' * 80}',
      List.filled(300, '1').join('+'),
      'x' * 4097,
    ]) {
      expect(
        () => MathExpression.parse(source),
        throwsFormatException,
        reason: source.length > 80 ? 'large input' : source,
      );
    }
  });
  test('variable definitions reject duplicates, reserved names and code', () {
    expect(mathVariables('a=2\r\nb=-3.5'), {'a': 2.0, 'b': -3.5});
    for (final source in [
      'a=2;a=3',
      'pi=3',
      'a=sin(2)',
      'a=NaN',
      'a=Infinity',
      'a=1e-999',
      'bad name=3',
      List.generate(13, (i) => 'v$i=$i').join(';'),
    ]) {
      expect(() => mathVariables(source), throwsFormatException);
    }
  });
  test('derivatives and integrals agree with known smooth functions', () {
    final derivative = numericDerivative(MathExpression.parse('x^3'), 2, {});
    expect(derivative.value, closeTo(12, 1e-7));
    expect(derivative.error.isFinite, isTrue);
    expect(numericDerivative(MathExpression.parse('x^2'), 0, {}).value, 0);
    expect(
      () => numericDerivative(MathExpression.parse('abs(x)'), 0, {}),
      throwsFormatException,
    );
    expect(
      () => numericDerivative(MathExpression.parse('floor(x)'), 0, {}),
      throwsFormatException,
    );
    final integral = numericIntegral(MathExpression.parse('x^2'), 0, 3, {});
    expect(integral.value, closeTo(9, 1e-10));
    expect(
      numericIntegral(MathExpression.parse('sin(x)'), 0, math.pi, {}).value,
      closeTo(2, 1e-8),
    );
    expect(
      () => numericIntegral(MathExpression.parse('1/x'), -1, 1, {}),
      throwsFormatException,
    );
    expect(
      () => numericIntegral(MathExpression.parse('x'), 1, 1, {}),
      throwsFormatException,
    );
  });
  test(
    'root convergence rejects same-sign brackets and discontinuous poles',
    () {
      final root = numericRoot(MathExpression.parse('x^2-2'), 0, 2, {});
      expect(root.value, closeTo(math.sqrt(2), 1e-9));
      expect(root.error, lessThan(1e-8));
      expect(numericRoot(MathExpression.parse('x'), 0, 1, {}).value, 0);
      expect(
        () => numericRoot(MathExpression.parse('x^2+1'), -2, 2, {}),
        throwsFormatException,
      );
      expect(
        () => numericRoot(MathExpression.parse('1/(x-.12345)'), -1, 1, {}),
        throwsFormatException,
      );
    },
  );
  test('function plots keep domain gaps and explicit windows', () {
    final plot = MathPlot.sample(MathExpression.parse('1/x'), {});
    expect(plot.points, hasLength(257));
    expect(plot.segments, hasLength(2));
    expect(plot.segments.first.last.$1, lessThan(0));
    expect(plot.segments.last.first.$1, greaterThan(0));
    expect(
      MathPlot.sample(MathExpression.parse('sqrt(x)'), {}).points.first.$2,
      isNull,
    );
    expect(
      () => MathPlot.sample(MathExpression.parse('a*x'), {}),
      throwsFormatException,
    );
    expect(
      () => MathPlot.sample(MathExpression.parse('x'), {}, xMin: 5, xMax: 1),
      throwsFormatException,
    );
  });
  test(
    'matrix operations support pivot swaps, products and real system solutions',
    () {
      final a = MathMatrix.parse('2,1\r\n1,3');
      final solution = a.solve(MathMatrix.parse('5;7'));
      expect(solution.values[0][0], closeTo(1.6, 1e-12));
      expect(solution.values[1][0], closeTo(1.8, 1e-12));
      expect(a.determinant, 5);
      expect(MathMatrix.parse('0 1;1 0').determinant, -1);
      final identity = a.multiply(a.inverse);
      for (var r = 0; r < 2; r++) {
        for (var c = 0; c < 2; c++) {
          expect(identity.values[r][c], closeTo(r == c ? 1 : 0, 1e-12));
        }
      }
      expect(MathMatrix.parse('1 2 3;4 5 6').transpose.values, [
        [1, 4],
        [2, 5],
        [3, 6],
      ]);
    },
  );
  test(
    'matrix errors refuse ragged, nonfinite, singular and incompatible data',
    () {
      for (final source in [
        '',
        '1 2;3',
        'NaN',
        '1e999',
        '1e-999',
        '1,,2',
        '1,2,',
        List.filled(7, '1').join(' '),
      ]) {
        expect(() => MathMatrix.parse(source), throwsFormatException);
      }
      expect(() => MathMatrix.parse('1 2;2 4').inverse, throwsFormatException);
      expect(
        () => MathMatrix.parse('1 0;0 1e-15').inverse,
        throwsFormatException,
      );
      expect(
        () => MathMatrix.parse('1 2 3').determinant,
        throwsFormatException,
      );
      expect(
        () => MathMatrix.parse('1 2').multiply(MathMatrix.parse('1 2')),
        throwsFormatException,
      );
      expect(
        () => MathMatrix.parse('1 0;0 1').solve(MathMatrix.parse('1 2')),
        throwsFormatException,
      );
    },
  );
  test(
    'Canvas plots round-trip with editable primitives, SVG and atomic undo',
    () {
      final plot = MathPlot.sample(MathExpression.parse('1/x'), {});
      final result = MathLabResult(
        r'f(x)=\frac{1}{x}',
        'Function 1/x • x:[-5,5] y:[-5,5]',
        plot: plot,
      );
      var nextId = 0;
      final elements = mathResultElements(
        result,
        const CanvasPoint(30, 60),
        0xffffffff,
        () => 'math-${nextId++}',
      );
      final history = CanvasHistory(
        CanvasScene.fromJson({'schemaVersion': 1, 'elements': []}),
      );
      for (final e in elements) {
        history.put(e);
      }
      history.commit();
      expect(elements.where((e) => e.type == 'ink'), hasLength(2));
      expect(elements.map((e) => e.groupId).toSet(), hasLength(1));
      final scene = CanvasScene.fromJson(
        jsonDecode(jsonEncode(history.scene.toJson())) as Map<String, dynamic>,
      );
      expect(scene.elements, hasLength(elements.length));
      expect(scene.elements.every((e) => e.renderable), isTrue);
      expect(canvasToSvg(scene), contains('<svg'));
      expect(scene.elements.first.text, contains(r'$$'));
      expect(history.undo(), isTrue);
      expect(history.scene.elements, isEmpty);
      expect(history.redo(), isTrue);
      expect(history.scene.elements, hasLength(elements.length));
    },
  );
}
