import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:orbit_note/domain/wiki_links.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/note_format_toolbar.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';
import 'package:orbit_note/features/notes/rich/note_underline.dart';

void main() {
  group('Footnotes & Underline Models and Syntaxes', () {
    test('InlineProjection parses <u> and <ins> and sets underline mark', () {
      final p1 = InlineProjection('This is <u>underlined</u> text');
      expect(p1.text, 'This is underlined text');
      // "underlined" starts at index 8 and ends at index 18
      for (var i = 8; i < 18; i++) {
        expect(
          p1.styles[i].contains('underline'),
          isTrue,
          reason: 'char at $i should have underline mark',
        );
      }
      expect(p1.styles[0].contains('underline'), isFalse);

      final p2 = InlineProjection('This is <ins>inserted</ins> text');
      expect(p2.text, 'This is inserted text');
      for (var i = 8; i < 16; i++) {
        expect(
          p2.styles[i].contains('underline'),
          isTrue,
          reason: 'char at $i should have underline mark',
        );
      }
    });

    test('InlineProjection parses [^1] and sets footnote mark', () {
      final p = InlineProjection('Reference[^1] and footnote[^note2].');
      expect(p.text, 'Reference[^1] and footnote[^note2].');
      // "[^1]" is at index 9..13
      for (var i = 9; i < 13; i++) {
        expect(
          p.styles[i].contains('footnote'),
          isTrue,
          reason: 'char at $i should have footnote mark',
        );
      }
      expect(p.styles[0].contains('footnote'), isFalse);
    });

    test(
      'UnderlineInlineSyntax and InsInlineSyntax match tags to u element',
      () {
        final doc1 = md.Document(inlineSyntaxes: [UnderlineInlineSyntax()]);
        final nodes1 = doc1.parseInline('Test <u>underline</u> text');
        expect(
          nodes1.any(
            (n) =>
                n is md.Element && n.tag == 'u' && n.textContent == 'underline',
          ),
          isTrue,
        );

        final doc2 = md.Document(inlineSyntaxes: [InsInlineSyntax()]);
        final nodes2 = doc2.parseInline('Test <ins>inserted</ins> text');
        expect(
          nodes2.any(
            (n) =>
                n is md.Element && n.tag == 'u' && n.textContent == 'inserted',
          ),
          isTrue,
        );
      },
    );

    testWidgets(
      'UnderlineElementBuilder renders Text with underline decoration',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MarkdownBody(
                data: 'Plain and <u>underlined</u> text',
                inlineSyntaxes: [UnderlineInlineSyntax()],
                builders: {'u': UnderlineElementBuilder()},
              ),
            ),
          ),
        );

        final textWidgets = tester.widgetList<Text>(find.byType(Text));
        final underlined = textWidgets.firstWhere(
          (t) => t.data == 'underlined',
        );
        expect(underlined.style?.decoration, TextDecoration.underline);
      },
    );
  });

  group('NoteFormatToolbar Underline & Footnote Controls', () {
    testWidgets(
      'NoteFormatToolbar contains Underline button and invokes callback',
      (tester) async {
        NoteFormatAction? selectedAction;
        final undoController = UndoHistoryController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NoteFormatToolbar(
                onFormat: (action) => selectedAction = action,
                undoController: undoController,
              ),
            ),
          ),
        );

        final underlineBtn = find.byTooltip('Underline · Ctrl+U');
        expect(underlineBtn, findsOneWidget);

        await tester.tap(underlineBtn);
        await tester.pump();
        expect(selectedAction, NoteFormatAction.underline);
      },
    );

    testWidgets(
      'NoteFormatToolbar popup menu contains Footnote and Underline',
      (tester) async {
        String? chosenCommand;
        final undoController = UndoHistoryController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NoteFormatToolbar(
                onFormat: (_) {},
                undoController: undoController,
                onCommand: (cmd) => chosenCommand = cmd,
              ),
            ),
          ),
        );

        final addBtn = find.byIcon(Icons.add_circle_outline);
        expect(addBtn, findsOneWidget);

        await tester.tap(addBtn);
        await tester.pumpAndSettle();

        expect(find.text('Underline'), findsOneWidget);
        expect(find.text('Footnote'), findsOneWidget);

        await tester.tap(find.text('Footnote'));
        await tester.pumpAndSettle();

        expect(chosenCommand, 'Footnote');
      },
    );
  });

  group('NoteEditor Underline & Footnote Behavior', () {
    Widget buildEditor({
      required String body,
      ValueChanged<String>? onBodyChanged,
      String mode = 'write',
    }) {
      return MaterialApp(
        home: Scaffold(
          body: NoteEditor(
            initialViewState: {'mode': mode},
            noteId: 'test-note',
            title: 'Test Note',
            body: body,
            onTitleChanged: (_) {},
            onBodyChanged: onBodyChanged ?? (_) {},
            linkTargets: const <NoteLinkTarget>[],
            onOpenObject: (_) {},
          ),
        ),
      );
    }

    testWidgets(
      'NoteEditor formats text selection with <u>...</u> on underline',
      (tester) async {
        String currentBody = 'Select my word here';
        await tester.pumpWidget(
          buildEditor(
            body: currentBody,
            onBodyChanged: (val) => currentBody = val,
            mode: 'write',
          ),
        );
        await tester.pumpAndSettle();

        final field = find.byKey(const ValueKey('note-body'));
        await tester.tap(field);
        await tester.pump();
        final textField = tester.widget<TextField>(field);
        textField.controller!.selection = const TextSelection(
          baseOffset: 10,
          extentOffset: 14, // "word"
        );

        // Tap Underline toolbar button
        final underlineBtn = find.byTooltip('Underline · Ctrl+U');
        expect(underlineBtn, findsOneWidget);

        await tester.tap(underlineBtn);
        await tester.pumpAndSettle();

        expect(currentBody, 'Select my <u>word</u> here');
      },
    );

    testWidgets('NoteEditor handles Ctrl+U shortcut to underline selection', (
      tester,
    ) async {
      String currentBody = 'Shortcut sample text';
      await tester.pumpWidget(
        buildEditor(
          body: currentBody,
          onBodyChanged: (val) => currentBody = val,
          mode: 'write',
        ),
      );
      await tester.pumpAndSettle();

      final field = find.byKey(const ValueKey('note-body'));
      await tester.tap(field);
      await tester.pump();
      final textField = tester.widget<TextField>(field);
      textField.controller!.selection = const TextSelection(
        baseOffset: 9,
        extentOffset: 15, // "sample"
      );

      // Simulate Ctrl+U
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();

      expect(currentBody, 'Shortcut <u>sample</u> text');
    });

    testWidgets('NoteEditor inserts auto-incremented footnote and definition', (
      tester,
    ) async {
      String currentBody =
          'Existing footnote[^1] in text.\n\n[^1]: First note.';
      await tester.pumpWidget(
        buildEditor(
          body: currentBody,
          onBodyChanged: (val) => currentBody = val,
          mode: 'write',
        ),
      );
      await tester.pumpAndSettle();

      // Open insert block menu
      final addBtn = find.byIcon(Icons.add_circle_outline);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Tap 'Footnote'
      await tester.tap(find.text('Footnote'));
      await tester.pumpAndSettle();

      // Should automatically detect [^1] and generate [^2] and [^2]:
      expect(currentBody, contains('[^2]'));
      expect(currentBody, contains('[^2]: '));
    });

    testWidgets(
      'MarkdownBody in NoteEditor renders footnote reference and definition',
      (tester) async {
        const markdown =
            'Claim about something[^1].\n\n[^1]: Reference citation.';
        await tester.pumpWidget(buildEditor(body: markdown, mode: 'read'));
        await tester.pumpAndSettle();

        final preview = find.byKey(const ValueKey('note-preview'));
        expect(preview, findsOneWidget);

        // MarkdownBody parses footnote references into superscript '1' and definition with return '↩'
        expect(find.textContaining('Claim about something'), findsOneWidget);
        expect(find.textContaining('Reference citation'), findsOneWidget);
        expect(find.textContaining('↩'), findsOneWidget);
      },
    );

    testWidgets(
      'MarkdownBody in NoteEditor renders <u> underline and callouts with underline',
      (tester) async {
        const markdown =
            '> [!NOTE]\n> A note with <u>underlined</u> text.\n\nOutside <u>underline</u>.';
        await tester.pumpWidget(buildEditor(body: markdown, mode: 'read'));
        await tester.pumpAndSettle();

        expect(find.byType(MarkdownBody), findsWidgets);
        final textWidgets = tester.widgetList<Text>(find.byType(Text));
        final underlinedTexts = textWidgets.where(
          (t) => t.data == 'underlined' || t.data == 'underline',
        );
        expect(underlinedTexts, isNotEmpty);
        for (final text in underlinedTexts) {
          expect(text.style?.decoration, TextDecoration.underline);
        }
      },
    );
  });
}
