import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/math_plot_definition.dart';
import 'package:orbit_note/features/math/math_plot_view.dart';
import 'package:orbit_note/features/math/math_plot_block.dart';
import 'package:orbit_note/features/math/math_plot_source_block.dart';
import 'package:orbit_note/features/math/math_lab_dialog.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/rich/code_block.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';

Future<void> calculatePlot(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('math-calculate')));
  await tester.tap(find.byKey(const ValueKey('math-calculate')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('read-only rich plots expose inspection without edit controls', (
    tester,
  ) async {
    final definition = MathPlotDefinition.create(functions: ['x']);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RichMarkdownEditor(
            body: definition.markdown,
            onChanged: (_) {},
            onUndo: () {},
            onRedo: () {},
            linkTargets: const [],
            linkBindings: const {},
            onOpenLink: (_) {},
            mathPlotsReadOnly: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MathPlotView), findsOneWidget);
    expect(find.text('Edit plot'), findsNothing);
    expect(find.text('Edit plot source'), findsNothing);
    expect(find.text('Copy values'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'rich find reveals plot source and selects the exact metadata passage',
    (tester) async {
      final source = MathPlotDefinition.create(
        functions: ['x'],
        original: {'metadata': '🌙 keep-me'},
      ).markdown;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditor(
              noteId: 'find',
              title: 'Graph',
              body: source,
              onTitleChanged: (_) {},
              onBodyChanged: (_) {},
              linkTargets: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Find in note · Ctrl+F'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Find in this note'),
        'keep-me',
      );
      await tester.pumpAndSettle();
      expect(find.byType(NoteCodeBlock), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('rich-code')),
      );
      expect(
        field.controller!.selection.textInside(field.controller!.text),
        'keep-me',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'read search exposes plot JSON transiently and restores the graph',
    (tester) async {
      final source = MathPlotDefinition.create(
        functions: ['x'],
        original: {'metadata': 'keep-me'},
      ).markdown;
      var writes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditor(
              noteId: 'read',
              title: 'Graph',
              body: source,
              initialViewState: const {'mode': 'read'},
              onTitleChanged: (_) {},
              onBodyChanged: (_) => writes++,
              linkTargets: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Find in note · Ctrl+F'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Find in this note'),
        'keep-me',
      );
      await tester.pumpAndSettle();
      expect(find.byType(NoteCodeBlock), findsOneWidget);
      await tester.tap(find.byTooltip('Close find'));
      await tester.pumpAndSettle();
      expect(find.byType(MathPlotView), findsOneWidget);
      expect(writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'value tables ignore hidden y bounds and single-expression tools refuse comparisons',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MathLabDialog())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Functions'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('math-Expression')),
        'x\nx^2',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('math-Lower y bound')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('math-Lower y bound')),
        'invalid',
      );
      await tester.ensureVisible(find.text('Table'));
      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();
      await calculatePlot(tester);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('math-insert')))
            .onPressed,
        isNotNull,
      );
      await tester.ensureVisible(find.text('Derivative'));
      await tester.tap(find.text('Derivative'));
      await tester.pumpAndSettle();
      await calculatePlot(tester);
      expect(find.textContaining('Use one expression'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('math-insert')))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  final recipe = MathPlotDefinition.create(
    functions: ['a*x', 'x^2'],
    variables: {'a': 2},
    original: {
      'plugin': {'objectId': 'keep-me'},
    },
  );
  testWidgets(
    'Read and Rich modes reopen live plots without mutating Markdown',
    (tester) async {
      for (final mode in ['rich', 'read', 'write']) {
        var writes = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NoteEditor(
                noteId: 'n',
                title: 'Graph',
                body: recipe.markdown,
                initialViewState: {'mode': mode},
                onTitleChanged: (_) {},
                onBodyChanged: (_) => writes++,
                linkTargets: const [],
                onOpenObject: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (mode != 'write') {
          expect(find.byType(MathPlotView), findsOneWidget);
          expect(
            find.text('Edit plot'),
            mode == 'rich' ? findsOneWidget : findsNothing,
          );
          final inspector = find.byKey(const ValueKey('math-plot-inspector'));
          await tester.ensureVisible(inspector);
          await tester.tap(inspector);
          await tester.pump();
          expect(find.textContaining('x = '), findsWidgets);
        }
        expect(writes, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );
  testWidgets(
    'graph parameter edits preserve unknown data, CRLF fences and exact undo',
    (tester) async {
      final original =
          'Before\r\n\r\n${recipe.markdown.replaceAll('\n', '\r\n')}\r\n\r\nAfter\r\n';
      var body = original;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, update) => NoteEditor(
                noteId: 'n',
                title: 'Graph',
                body: body,
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
      await tester.ensureVisible(find.text('Edit plot'));
      await tester.tap(find.text('Edit plot'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('math-Variables')));
      await tester.enterText(
        find.byKey(const ValueKey('math-Variables')),
        'a=3',
      );
      await calculatePlot(tester);
      await tester.tap(find.byKey(const ValueKey('math-insert')));
      await tester.pumpAndSettle();
      final block = MarkdownDocument.parse(
        body,
      ).blocks.singleWhere((b) => b.kind == MarkdownBlockKind.code);
      final changed = MathPlotDefinition.tryParse(block.content)!;
      expect(changed.variables['a'], 3);
      expect(changed.data['plugin'], recipe.data['plugin']);
      expect(body, startsWith('Before\r\n\r\n'));
      expect(body, endsWith('After\r\n'));
      expect(body, isNot(contains('\r\r\n')));
      await tester.ensureVisible(find.byTooltip('Undo · Ctrl+Z'));
      await tester.tap(find.byTooltip('Undo · Ctrl+Z'));
      await tester.pumpAndSettle();
      expect(body, original);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'plot dialogs refuse stale edits after switching to another note',
    (tester) async {
      var owner = 'first', body = recipe.markdown;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                return NoteEditor(
                  noteId: owner,
                  title: 'Graph',
                  body: body,
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
      await tester.ensureVisible(find.text('Edit plot'));
      await tester.tap(find.text('Edit plot'));
      await tester.pumpAndSettle();
      await calculatePlot(tester);
      update(() => owner = 'second');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('math-insert')));
      await tester.pumpAndSettle();
      expect(body, recipe.markdown);
      expect(find.textContaining('Reopen the plot'), findsOneWidget);
    },
  );
  testWidgets(
    'unknown recipes remain editable code and do not steal focus when repaired',
    (tester) async {
      var source = jsonEncode({...recipe.data, 'version': 2});
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (_, update) => MathPlotSourceBlock(
                  source: source,
                  onSourceChanged: (s) => update(() => source = s),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NoteCodeBlock), findsOneWidget);
      expect(find.byType(MathPlotView), findsNothing);
      final field = find.byKey(const ValueKey('rich-code'));
      await tester.enterText(field, recipe.json);
      await tester.pumpAndSettle();
      expect(find.byType(NoteCodeBlock), findsOneWidget);
      expect(find.text('Show plot'), findsOneWidget);
      await tester.tap(find.text('Show plot'));
      await tester.pumpAndSettle();
      expect(find.byType(MathPlotView), findsOneWidget);
    },
  );
  testWidgets(
    'graphs expose values and source at narrow widths and 200% text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: MathPlotBlock(definition: recipe),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Value table'));
      await tester.tap(find.text('Value table'));
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'comparison and value-table outputs render with the shared TeX renderer',
    (tester) async {
      final errors = <String>[];
      for (final tex in [
        recipe.tableTex(),
        r'\begin{aligned}f_1(x)&=\sin(x)\\f_2(x)&=\cos(x)\end{aligned}',
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Math.tex(
                  tex,
                  onErrorFallback: (error) {
                    errors.add(error.toString());
                    return const Text('Invalid');
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      expect(errors, isEmpty);
    },
  );
  testWidgets('clipboard failures are reported without changing graph source', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'denied');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: MathPlotBlock(definition: recipe)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy values'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not copy values'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
