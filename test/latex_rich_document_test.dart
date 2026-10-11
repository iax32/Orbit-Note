import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/features/notes/latex/latex_document.dart';
import 'package:orbit_note/features/notes/latex/latex_prose_controller.dart';
import 'package:orbit_note/features/notes/latex/rich_latex_editor.dart';
import 'package:orbit_note/features/notes/rich/structured_math_editor.dart';

const document = r'''\documentclass{article}
\newcommand{\custom}[1]{#1}
\begin{document}
\section*{Introduction}
Hello \textbf{world} and \custom{kept}.

\[
\frac{a}{b}
\]

\end{document}
''';

void main() {
  testWidgets('adding missing metadata keeps the paragraph controller mapped', (
    tester,
  ) async {
    var body = document;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => RichLatexEditor(
              body: body,
              contentWidth: 800,
              fontSize: 16,
              onChanged: (value) => setState(() => body = value),
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(
      find.byTooltip('Document title, author and date'),
    );
    await tester.tap(find.byTooltip('Document title, author and date'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Author(s)',
      ),
      'Ada',
    );
    await tester.pumpAndSettle();
    final prose = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.controller is LatexProseController &&
          w.controller!.text.startsWith('Hello'),
    );
    await tester.ensureVisible(prose);
    await tester.enterText(prose, 'Updated paragraph.');
    await tester.pumpAndSettle();
    expect(body, contains(r'\author{Ada}'));
    expect(body, contains('Updated paragraph.'));
    expect(body, contains(r'\section*{Introduction}'));
    expect(body, contains(r'\frac{a}{b}'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Enter creates a paragraph and moves the caret to it', (
    tester,
  ) async {
    var body = 'Hello world\n\n';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => RichLatexEditor(
              body: body,
              contentWidth: 800,
              fontSize: 16,
              onChanged: (v) => setState(() => body = v),
            ),
          ),
        ),
      ),
    );
    final field = find.byWidgetPredicate(
      (w) => w is TextField && w.controller is LatexProseController,
    );
    await tester.tap(field);
    await tester.pump();
    tester.widget<TextField>(field).controller!.selection =
        const TextSelection.collapsed(offset: 5);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) => w is TextField && w.controller is LatexProseController,
      ),
      findsNWidgets(2),
    );
    expect(body, contains('Hello\n\n'));
    final focused = tester
        .widgetList<TextField>(find.byType(TextField))
        .where((w) => w.focusNode?.hasFocus == true)
        .single;
    expect(focused.controller!.text.trim(), 'world');
    expect(focused.controller!.selection.baseOffset, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'inline equation opens visual editing and cancellation preserves source',
    (tester) async {
      const source = r'Energy is $E=mc^2$.';
      var body = source;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => RichLatexEditor(
                body: body,
                contentWidth: 800,
                fontSize: 16,
                onChanged: (v) => setState(() => body = v),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('latex-inline-0-10')));
      await tester.pumpAndSettle();
      expect(find.text('Edit equation'), findsOneWidget);
      expect(find.byType(EditableMathExpression), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(body, source);
      await tester.tap(find.byKey(const ValueKey('latex-inline-0-10')));
      await tester.pumpAndSettle();
      tester
          .state<EditableMathExpressionState>(
            find.byType(EditableMathExpression),
          )
          .insertLatex(r'\alpha');
      await tester.pumpAndSettle();
      expect(body, source);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(body, startsWith('Energy is \$'));
      expect(body, contains(r'\alpha'));
      expect(body.trim(), endsWith(r'$.'));
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'prose projects nested formatting and splices edits without losing macros',
    () {
      final c = LatexProseController(
        r'A \textbf{bold \textit{word}} \custom{x}.',
      );
      addTearDown(c.dispose);
      expect(c.text, r'A bold word \custom{x}.');
      c.value = c.value.copyWith(text: c.text.replaceFirst('word', 'term'));
      expect(c.source, r'A \textbf{bold \textit{term}} \custom{x}.');
      c.value = c.value.copyWith(text: c.text.replaceFirst('bold term', 'new'));
      expect(c.source, r'A \textbf{new\textit{}} \custom{x}.');
    },
  );

  test(
    'format selection, styled typing and literal TeX characters round trip',
    () {
      final c = LatexProseController('Hello world');
      addTearDown(c.dispose);
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      c.format('textbf');
      expect(c.text, 'Hello world');
      expect(c.source, r'\textbf{Hello} world');
      c.format('textbf');
      expect(c.source, 'Hello world');
      c.format('textbf');
      c.selection = TextSelection.collapsed(offset: c.text.length);
      c.format('textit');
      c.value = TextEditingValue(text: '${c.text} & 50%');
      expect(c.source, r'\textbf{Hello} world\textit{ \& 50\%}');
      expect(LatexProseController(c.source).text, 'Hello world & 50%');
    },
  );

  test('alignment environments and end marker preserve source', () {
    for (final source in [
      '',
      '\n\n',
      'Text without a final newline',
      document,
    ]) {
      expect(LatexDocument.parse(source).toLatex(), source);
    }
    const source =
        '\\begin{document}\n\\begin{center}\nHello\n\\end{center}\n\\end{document}\n';
    final doc = LatexDocument.parse(source);
    expect(doc.toLatex(), source);
    expect(
      doc.blocks.where((b) => b.environment == 'center').single.type,
      LatexBlockType.paragraph,
    );
    final adjacent = LatexDocument.parse('Hello\n\\end{document}\n');
    expect(adjacent.blocks.first.rawContent, 'Hello\n');
    expect(adjacent.blocks.last.source, '\\end{document}\n');
  });

  testWidgets(
    'document formatting edits visual text and preserves custom source',
    (tester) async {
      var body = document;
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => RichLatexEditor(
                body: body,
                contentWidth: 800,
                fontSize: 16,
                onChanged: (value) => setState(() => body = value),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add Block'), findsNothing);
      expect(find.byType(EditableMathExpression), findsOneWidget);
      final paragraph = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.controller is LatexProseController &&
            w.controller!.text.startsWith('Hello'),
      );
      await tester.tap(paragraph);
      await tester.pump();
      final controller = tester.widget<TextField>(paragraph).controller!;
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      await tester.tap(find.byTooltip('Bold (Ctrl+B)'));
      await tester.pumpAndSettle();
      expect(body, contains(r'\textbf{Hello} \textbf{world}'));
      expect(body, contains(r'\newcommand{\custom}[1]{#1}'));
      expect(body, contains(r'\custom{kept}'));
      expect(body, contains('\\[\n\\frac{a}{b}\n\\]'));
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 5),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'symbol insertion uses rich document position before end marker',
    (tester) async {
      var body = document;
      final key = GlobalKey<RichLatexEditorState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => RichLatexEditor(
                key: key,
                body: body,
                contentWidth: 800,
                fontSize: 16,
                onChanged: (v) => setState(() => body = v),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      key.currentState!.insertMath(r'\alpha + \beta');
      await tester.pumpAndSettle();
      expect(
        body.indexOf(r'\alpha'),
        lessThan(body.indexOf(r'\end{document}')),
      );
      expect(find.byType(EditableMathExpression), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rich document toolbar fits a narrow pane at large text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: RichLatexEditor(
              body: document,
              onChanged: (_) {},
              contentWidth: 800,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
