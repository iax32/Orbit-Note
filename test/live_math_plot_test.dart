import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/math_plot_definition.dart';
import 'package:orbit_note/domain/math_plot_svg.dart';
import 'package:orbit_note/domain/math_result.dart';
import 'package:orbit_note/domain/math_lab.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';
import 'package:orbit_note/canvas/math_plot_elements.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/features/canvas/canvas_rich_text.dart';

void main() {
  test('common Unicode mathematical input keeps authored expressions', () {
    const source = '2×π÷2−π';
    final expression = MathExpression.parse(source);
    expect(expression.source, source);
    expect(expression.evaluate(), closeTo(0, 1e-12));
    expect(
      MathExpression.parse('xπ').evaluate({'x': 2}),
      closeTo(6.283185307179586, 1e-12),
    );
    final recipe = MathPlotDefinition.create(functions: ['sin(π×x)']);
    expect(recipe.valuesAt(.5).first, closeTo(1, 1e-12));
    expect(recipe.functions.first, 'sin(π×x)');
  });
  test(
    'plot recipes are portable, preserve unfamiliar metadata and freeze nested data',
    () {
      final original = {
        'title': 'My study graph',
        'plugin': {
          'owner': 'stable-id',
          'settings': [1, 2],
        },
        'window': {'customTickSpacing': .5},
      };
      final first = MathPlotDefinition.create(
        functions: ['a*x', 'x^2'],
        variables: {'a': 2},
        original: original,
      );
      final saved = MathPlotDefinition.tryParse(first.json)!;
      expect(saved.functions, ['a*x', 'x^2']);
      expect(saved.variables, {'a': 2});
      expect(saved.data['plugin'], original['plugin']);
      final changed = MathPlotDefinition.create(
        functions: ['a*x', 'x^3'],
        variables: {'a': 3},
        original: saved.data,
      );
      expect(changed.data['plugin'], original['plugin']);
      expect((changed.data['window'] as Map)['customTickSpacing'], .5);
      expect(
        () => (saved.data['window'] as Map)['xMin'] = 99,
        throwsUnsupportedError,
      );
      expect(
        () => (saved.data['plugin'] as Map)['settings'][0] = 99,
        throwsUnsupportedError,
      );
    },
  );
  test(
    'fenced plots round-trip as recoverable code through the Markdown projection',
    () {
      final recipe = MathPlotDefinition.create(functions: ['sin(x)', 'cos(x)']);
      final source =
          'Before\r\n\r\n${recipe.markdown.replaceAll('\n', '\r\n')}\r\n\r\nAfter\r\n';
      final document = MarkdownDocument.parse(source);
      final block = document.blocks.singleWhere(
        (b) => b.kind == MarkdownBlockKind.code,
      );
      expect(block.language, 'orbit-plot');
      expect(
        MathPlotDefinition.tryParse(block.content)!.functions,
        hasLength(2),
      );
      expect(document.source, source);
      expect(
        MathLabResult('f(x)=x', 'Function', plotDefinition: recipe).markdown,
        recipe.markdown,
      );
    },
  );
  test(
    'malformed, unknown-version and unsafe recipes are refused without evaluation',
    () {
      final valid =
          jsonDecode(MathPlotDefinition.create(functions: ['x']).json)
              as Map<String, dynamic>;
      final cases = [
        {...valid, 'version': 2},
        {
          ...valid,
          'functions': [''],
        },
        {...valid, 'functions': List.filled(5, 'x')},
        {
          ...valid,
          'functions': ['a*x'],
        },
        {
          ...valid,
          'functions': [42],
        },
        {
          ...valid,
          'functions': ['1;exit()'],
        },
        {
          ...valid,
          'variables': {'x': 1},
        },
        {
          ...valid,
          'variables': {'pi': 3},
        },
        {
          ...valid,
          'variables': {'a': 'oops'},
        },
        {
          ...valid,
          'window': {'xMin': 1, 'xMax': 1, 'yMin': -1, 'yMax': 1},
        },
        {...valid, 'title': 42},
        {...valid, 'title': 'a' * 121},
      ];
      for (final data in cases) {
        expect(
          MathPlotDefinition.tryParse(jsonEncode(data)),
          isNull,
          reason: data.toString(),
        );
      }
      expect(MathPlotDefinition.tryParse('{'), isNull);
      expect(MathPlotDefinition.tryParse('${'[' * 40}0${']' * 40}'), isNull);
      expect(MathPlotDefinition.tryParse(' ' * 65537), isNull);
      final raw = jsonEncode(valid);
      for (final literal in [
        '1e999',
        '1e-999',
        '9007199254740993',
        '0.123456789123456789',
      ]) {
        expect(
          MathPlotDefinition.tryParse(
            raw.replaceFirst('"version":1', '"metadata":$literal,"version":1'),
          ),
          isNull,
        );
      }
      expect(
        MathPlotDefinition.tryParse(
          jsonEncode({
            ...valid,
            'window': {
              'xMin': 1,
              'xMax': 1.0000000000000002,
              'yMin': -1,
              'yMax': 1,
            },
          }),
        ),
        isNull,
      );
    },
  );
  test(
    'comparison plots retain domain gaps; tables include finite values outside the visible y window',
    () {
      final recipe = MathPlotDefinition.create(
        functions: ['1/x', 'sqrt(x)', 'x^2'],
        xMin: -2,
        xMax: 2,
        yMin: -1,
        yMax: 1,
      );
      expect(recipe.sample(), hasLength(3));
      expect(recipe.sample().first.segments, hasLength(2));
      final rows = recipe.table(rows: 5);
      expect(rows[0], [-2.0, -.5, null, 4.0]);
      expect(rows[2], [0.0, null, 0.0, 0.0]);
      expect(recipe.valuesAt(2)[2], 4);
      expect(recipe.tableText(rows: 5), contains('undefined'));
      expect(
        recipe.tableText(separator: ',', rows: 5),
        startsWith('x,f1(x),f2(x),f3(x)'),
      );
      expect(recipe.tableTex(rows: 5), contains(r'\text{undefined}'));
      expect(() => recipe.table(rows: 102), throwsFormatException);
      expect(() => recipe.valuesAt(double.nan), throwsFormatException);
      expect(() => recipe.valuesAt(3), throwsFormatException);
    },
  );
  test(
    'value exports use machine-readable precision and Canvas arrays show readable rows',
    () {
      final recipe = MathPlotDefinition.create(functions: ['1e-9*x']);
      final text = recipe.tableText(rows: 3);
      expect(text, isNot(contains(' e')));
      expect(
        double.parse(text.split('\n').last.split('\t').last),
        closeTo(5e-9, 1e-20),
      );
      final preview = CanvasRichText.formatMathToUnicode(recipe.tableTex());
      expect(preview, contains('⎡'));
      expect(preview, isNot(contains('begin')));
      expect(preview.split('\n'), hasLength(12));
    },
  );
  test(
    'SVG export is standalone vector data with escaped labels and full source',
    () {
      final recipe = MathPlotDefinition.create(
        functions: ['x', 'x^2'],
        original: {
          'title': '<script> & "Plot"',
          'metadata': '<image href="https://example.invalid" />',
        },
      );
      final svg = mathPlotSvg(recipe);
      expect(svg, isNot(contains('<script')));
      expect(svg, isNot(contains('<image')));
      expect(RegExp('<polyline ').allMatches(svg), hasLength(2));
      expect(
        svg,
        contains(
          '<desc>${const HtmlEscape(HtmlEscapeMode.element).convert(recipe.json)}</desc>',
        ),
      );
      expect(
        svg,
        contains(
          '<title>${const HtmlEscape(HtmlEscapeMode.element).convert(recipe.title)}</title>',
        ),
      );
      expect(svg, contains('&lt;script&gt;'));
      final controls = MathPlotDefinition.create(
        functions: ['x'],
        original: {'title': 'Name\u0001', 'metadata': 'saved\u0001'},
      );
      expect(mathPlotSvg(controls), isNot(contains('\u0001')));
      expect(mathPlotSvg(controls), contains(r'saved\u0001'));
    },
  );
  test(
    'Canvas comparison snapshots use distinct ordinary ink and undo as one operation',
    () {
      final recipe = MathPlotDefinition.create(functions: ['sin(x)', 'cos(x)']);
      var id = 0;
      final result = MathLabResult(
        'f_1=sin(x), f_2=cos(x)',
        'Compare',
        plot: recipe.sample().first,
        plotDefinition: recipe,
      );
      final elements = mathResultElements(
        result,
        const CanvasPoint(0, 0),
        0xffffffff,
        () => 'm${id++}',
      );
      final ink = elements.where((e) => e.type == 'ink').toList();
      expect(ink, hasLength(2));
      expect(ink.map((e) => e.color).toSet(), hasLength(2));
      expect(elements.first.text, contains(r'$$'));
      expect(elements.first.text, isNot(contains('```orbit-plot')));
      final history = CanvasHistory(
        CanvasScene.fromJson({'schemaVersion': 1, 'elements': []}),
      );
      for (final e in elements) {
        history.put(e);
      }
      history.commit();
      expect(
        CanvasScene.fromJson(
          jsonDecode(jsonEncode(history.scene.toJson()))
              as Map<String, dynamic>,
        ).elements,
        hasLength(elements.length),
      );
      history.undo();
      expect(history.scene.elements, isEmpty);
    },
  );
}
