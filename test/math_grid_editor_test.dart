import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/rich/math_grid_editor.dart';
import 'package:orbit_note/features/notes/rich/note_math.dart';

void main() {
  test(
    'standard grids round trip; unsupported structure stays source-only',
    () {
      for (final environment in ['matrix', 'pmatrix', 'bmatrix', 'aligned']) {
        final model = MathGrid(environment, [
          [r'\frac{1}{2}', 'x'],
          ['y', '4'],
        ]);
        expect(MathGrid.parse(model.encode())!.rows, model.rows);
        expect(MathGrid.parse(model.encode())!.environment, environment);
      }
      expect(MathGrid.parse(r'\begin{matrix}a & b \\ c\end{matrix}'), isNull);
      expect(
        MathGrid.parse(r'\begin{matrix}\frac{a & b}{c}\end{matrix}'),
        isNull,
      );
      expect(MathGrid.parse(r'prefix \begin{matrix}x\end{matrix}'), isNull);
    },
  );
  testWidgets(
    'visual matrix cells, structural buttons and rendered result work',
    (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showMathGrid(context);
                },
                child: const Text('Open grid'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open grid'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('math-cell-0-0-0')),
        '42',
      );
      await tester.tap(find.text('Add row'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(6));
      await tester.tap(find.text('Add column'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(9));
      await tester.tap(find.text('Apply grid'));
      await tester.pumpAndSettle();
      expect(MathGrid.parse(result!)!.rows.first.first, '42');
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: NoteMath(result!, display: true))),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Invalid'), findsNothing);
    },
  );
}
