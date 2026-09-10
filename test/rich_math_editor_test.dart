import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/rich/equation_editor.dart';
import 'package:orbit_note/features/notes/rich/rich_math_block.dart';
import 'package:orbit_note/features/notes/rich/visual_math_model.dart';

void main() {
  group('VisualMathModel', () {
    test(
      'slot edits preserve spacing, fraction variants and unsupported commands',
      () {
        final model = VisualMathModel(
          r'A + \dfrac  {x}{y} + \fraction{keep}{exact}',
        );
        expect(model.fractions, hasLength(1));
        expect(
          model.updateFractionDenominator(0, '2'),
          r'A + \dfrac  {x}{2} + \fraction{keep}{exact}',
        );
        expect(VisualMathModel(r'\frac{a}{broken').fractions, isEmpty);
        expect(VisualMathModel(r'\\frac{a}{b}').fractions, isEmpty);
        expect(VisualMathModel('% \\frac{a}{b}\nplain').fractions, isEmpty);
      },
    );
    test('parses simple and multiple fractions', () {
      final model = VisualMathModel(r'\frac{1}{2} + \frac{a}{b}');
      expect(model.fractions.length, 2);
      expect(model.fractions[0].numerator, '1');
      expect(model.fractions[0].denominator, '2');
      expect(model.fractions[1].numerator, 'a');
      expect(model.fractions[1].denominator, 'b');
    });

    test(
      'updates fraction denominator directly (writing the number below it)',
      () {
        final model = VisualMathModel(r'\frac{a}{b}');
        final updated = model.updateFractionDenominator(0, '42');
        expect(updated, r'\frac{a}{42}');
        expect(model.fractions[0].denominator, '42');
      },
    );

    test('updates fraction numerator directly', () {
      final model = VisualMathModel(r'\frac{a}{b}');
      final updated = model.updateFractionNumerator(0, 'x + 1');
      expect(updated, r'\frac{x + 1}{b}');
      expect(model.fractions[0].numerator, 'x + 1');
    });

    test('handles nested fractions without syntax corruption', () {
      final model = VisualMathModel(r'\frac{1 + \frac{x}{y}}{2}');
      expect(model.fractions.length, 2);
      expect(model.fractions[0].numerator, r'1 + \frac{x}{y}');
      expect(model.fractions[0].denominator, '2');
      final updated = model.updateFractionDenominator(0, '10');
      expect(updated, r'\frac{1 + \frac{x}{y}}{10}');
    });

    test('adds spacing between equations without opening code', () {
      final model = VisualMathModel(r'E = mc^2');
      final spaced = model.addSpacing();
      expect(spaced, contains(r'\quad'));
      expect(spaced, r'E = mc^2 \quad ');
    });

    test('adds line break between equations', () {
      final model = VisualMathModel(r'E = mc^2');
      final multiline = model.addLineBreak();
      expect(multiline, contains(r'\\'));
      expect(model.equationLines.length, 2);
    });

    test('parses big operators with lower bound (below) and upper bound', () {
      final model = VisualMathModel(r'\sum_{i=1}^{n} i^2');
      expect(model.bigOps.length, 1);
      expect(model.bigOps[0].operator, r'\sum');
      expect(model.bigOps[0].lowerBound, 'i=1');
      expect(model.bigOps[0].upperBound, 'n');
      final updated = model.updateBigOpLowerBound(0, 'k=0');
      expect(updated, contains(r'\sum_{k=0}^{n}'));
    });

    test('parses and updates subscripts (writing number below it)', () {
      final model = VisualMathModel(r'x_1 + y_2');
      expect(model.scripts.length, 2);
      expect(model.scripts[0].base, 'x');
      expect(model.scripts[0].subscript, '1');
      final updated = model.updateScriptSubscript(0, 'i+1');
      expect(updated, r'x_{i+1} + y_2');
    });
  });

  group('Rich Math UI & In-Place Editing', () {
    late String body;

    Future<void> openEditor(WidgetTester tester, String initial) async {
      body = initial;
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => NoteEditor(
                noteId: 'math-test',
                title: 'Math Note',
                body: body,
                onTitleChanged: (_) {},
                onBodyChanged: (v) => setState(() => body = v),
                linkTargets: const [],
                onOpenObject: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'rich editing view allows clicking fraction denominator to write number below it directly',
      (tester) async {
        await openEditor(tester, '\$\$\n\\frac{a}{b}\n\$\$\n');
        expect(find.byType(RichMathBlock), findsOneWidget);

        // In-place denominator input slot ("Bottom")
        final denomInput = find.byKey(const ValueKey('frac-den-0'));
        expect(denomInput, findsOneWidget);

        await tester.tap(denomInput);
        await tester.enterText(denomInput, '100');
        await tester.pumpAndSettle();

        expect(body, contains(r'\frac{a}{100}'));
        await tester.enterText(denomInput, '200');
        await tester.pumpAndSettle();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(denomInput).controller!.text, '100');
        expect(
          tester.widget<TextField>(denomInput).focusNode!.hasFocus,
          isTrue,
        );
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(body, contains(r'\frac{a}{b}'));
        expect(tester.widget<TextField>(denomInput).controller!.text, 'b');
      },
    );

    testWidgets(
      'rich editing view adds space and line break between equations with one click',
      (tester) async {
        await openEditor(tester, '\$\$\nE = mc^2\n\$\$\n');
        expect(find.byType(RichMathBlock), findsOneWidget);

        // Tap "+ Space" toolbar button directly on the block
        final spaceBtn = find.text('+ Space');
        expect(spaceBtn, findsOneWidget);
        await tester.tap(spaceBtn);
        await tester.pumpAndSettle();

        expect(body, contains(r'\quad'));

        // Tap "+ Line Break" toolbar button directly on the block
        final lineBreakBtn = find.text('+ Line Break');
        expect(lineBreakBtn, findsOneWidget);
        await tester.tap(lineBreakBtn);
        await tester.pumpAndSettle();

        expect(body, contains(r'\\'));
        expect(
          find.byTooltip(
            'Invalid or unsupported LaTeX. The source is preserved.',
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'equation studio dialog allows visual denominator editing and arrow key navigation',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        String? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    result = await showDialog<String>(
                      context: context,
                      builder: (_) => const EquationEditor(
                        source: r'\frac{numerator}{denominator}',
                        display: true,
                      ),
                    );
                  },
                  child: const Text('Open Studio'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Studio'));
        await tester.pumpAndSettle();

        // Verify visual fraction card exists
        expect(find.byKey(const ValueKey('visual-fraction-0')), findsOneWidget);
        final numField = find.byKey(const ValueKey('visual-numerator-0'));
        final denField = find.byKey(const ValueKey('visual-denominator-0'));
        expect(numField, findsOneWidget);
        expect(denField, findsOneWidget);

        // Test arrow down navigation from numerator to denominator
        await tester.tap(numField);
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(numField).focusNode!.hasFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(denField).focusNode!.hasFocus, isTrue);

        // Edit denominator directly in visual studio
        await tester.enterText(denField, '42');
        await tester.pumpAndSettle();

        // Tap apply
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();

        expect(result, r'\frac{numerator}{42}');
      },
    );
  });
}
