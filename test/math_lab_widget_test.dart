import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/math_templates.dart';
import 'package:orbit_note/domain/math_result.dart';
import 'package:orbit_note/features/math/math_lab_dialog.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/latex/rich_latex_editor.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_rich_text.dart';
import 'package:orbit_note/app/orbit_theme.dart';

Future<void> calculate(WidgetTester tester, String expression) async {
  await tester.enterText(
    find.byKey(const ValueKey('math-Expression')),
    expression,
  );
  await tester.ensureVisible(find.byKey(const ValueKey('math-calculate')));
  await tester.tap(find.byKey(const ValueKey('math-calculate')));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'Canvas matrix previews preserve readable rows without TeX environment noise',
    () {
      expect(
        CanvasRichText.formatMathToUnicode(
          r'\begin{pmatrix}2 & 10 \\ -1 & 3\end{pmatrix}',
        ),
        '⎛  2  10 ⎞\n⎝ -1   3 ⎠',
      );
      expect(
        CanvasRichText.formatMathToUnicode(
          r'\begin{bmatrix}1 & 2\end{bmatrix}',
        ),
        '[ 1  2 ]',
      );
      expect(
        CanvasRichText.formatMathToUnicode(r'\operatorname{Var}(X)'),
        'Var(X)',
      );
    },
  );
  testWidgets(
    'math dialog remains usable with large text and an on-screen keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(2),
              viewInsets: EdgeInsets.only(bottom: 260),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showMathLab(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(MathLabDialog), findsNothing);
    },
  );
  testWidgets(
    'calculator insertion is explicit; editing invalidates previous result',
    (tester) async {
      MathLabResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showMathLab(context);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await calculate(tester, 'sqrt(9)+2^3');
      expect(
        find.textContaining(r'\approx 11'),
        findsNothing,
      ); // Source is collapsed.
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('math-insert')))
            .onPressed,
        isNotNull,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('math-Expression')));
      await tester.enterText(
        find.byKey(const ValueKey('math-Expression')),
        '1/0',
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('math-insert')))
            .onPressed,
        isNull,
      );
      await calculate(tester, '1/0');
      expect(find.text('Division by zero.'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('math-Expression')));
      await calculate(tester, 'sqrt(9)+2^3');
      await tester.tap(find.byKey(const ValueKey('math-insert')));
      await tester.pumpAndSettle();
      expect(result!.tex, contains(r'\approx 11'));
    },
  );
  testWidgets(
    'all mathematical templates render rather than fall back to source',
    (tester) async {
      final errors = <String>[];
      for (final template in mathLabTemplates) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Math.tex(
                  template.tex,
                  onErrorFallback: (e) {
                    errors.add('${template.name}: $e');
                    return const Text('Invalid');
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: template.name);
      }
      expect(errors, isEmpty);
    },
  );
  testWidgets(
    'templates and dialog actions remain reachable at narrow 200% text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: const Scaffold(body: MathLabDialog()),
        ),
      );
      await tester.ensureVisible(find.text('Templates'));
      await tester.tap(find.text('Templates'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('math-Search templates')),
        'Bezier',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('math-insert')))
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Cubic Bezier curve'));
      await tester.tap(find.text('Cubic Bezier curve'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('math-insert')))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final mode in ['rich', 'write']) {
    testWidgets(
      '$mode Markdown math insertion survives projection and one undo',
      (tester) async {
        var body = 'Keep my words.\n';
        const original = 'Keep my words.\n';
        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (_, update) => NoteEditor(
                  noteId: 'n',
                  title: 'Math',
                  body: body,
                  initialViewState: {'mode': mode},
                  onTitleChanged: (_) {},
                  onBodyChanged: (s) => update(() => body = s),
                  linkTargets: const [],
                  onOpenObject: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Math Lab'));
        await tester.pumpAndSettle();
        await calculate(tester, '2+3');
        await tester.tap(find.byKey(const ValueKey('math-insert')));
        await tester.pumpAndSettle();
        expect(body, contains(r'\approx 5'));
        expect(body, contains('Keep my words.'));
        final undo = find.byTooltip('Undo · Ctrl+Z');
        await tester.ensureVisible(undo);
        await tester.tap(undo);
        await tester.pumpAndSettle();
        expect(body, original);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'changing a note while Math Lab is open prevents stale insertion',
    (tester) async {
      var body = 'Before\n';
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                return NoteEditor(
                  noteId: 'n',
                  title: 'Math',
                  body: body,
                  initialViewState: const {'mode': 'write'},
                  onTitleChanged: (_) {},
                  onBodyChanged: (s) => setState(() => body = s),
                  linkTargets: const [],
                  onOpenObject: (_) {},
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Math Lab'));
      await tester.pumpAndSettle();
      await calculate(tester, '2+3');
      update(() => body = 'A newer draft\n');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('math-insert')));
      await tester.pumpAndSettle();
      expect(body, 'A newer draft\n');
      expect(find.textContaining('Reopen Math Lab'), findsOneWidget);
    },
  );
  testWidgets(
    'LaTeX Math Lab inserts inside the document, before its closing marker',
    (tester) async {
      var body =
          '\\documentclass{article}\n\\begin{document}\nOriginal prose\n\\end{document}\n';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichLatexEditor(
              body: body,
              onChanged: (s) => body = s,
              contentWidth: 700,
              fontSize: 16,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Math Lab'));
      await tester.tap(find.text('Math Lab'));
      await tester.pumpAndSettle();
      await calculate(tester, '2+3');
      await tester.tap(find.byKey(const ValueKey('math-insert')));
      await tester.pumpAndSettle();
      expect(
        body.indexOf(r'\approx 5'),
        lessThan(body.indexOf(r'\end{document}')),
      );
      expect(body, contains('Original prose'));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Canvas functions insert normal ink with a single undo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, dynamic> data = {'schemaVersion': 1, 'elements': []};
    await tester.pumpWidget(
      MaterialApp(
        theme: orbitDarkTheme(),
        home: Scaffold(
          body: CanvasEditor(
            canvasId: 'c',
            data: data,
            onChanged: (s) => data = s,
            objects: const [],
            onOpenObject: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add / organize board content'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Math Lab · calculate & plot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Functions'));
    await tester.pumpAndSettle();
    await calculate(tester, 'x^2');
    await tester.tap(find.byKey(const ValueKey('math-insert')));
    await tester.pumpAndSettle();
    expect(
      (data['elements'] as List).where((e) => e['type'] == 'ink'),
      isNotEmpty,
    );
    await tester.tap(find.byTooltip('Undo (Ctrl+Z)'));
    await tester.pumpAndSettle();
    expect(data['elements'], isEmpty);
    expect(tester.takeException(), isNull);
  });
}
