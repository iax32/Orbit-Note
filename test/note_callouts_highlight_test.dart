import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:orbit_note/domain/wiki_links.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/note_format_toolbar.dart';
import 'package:orbit_note/features/notes/rich/callout_block.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';
import 'package:orbit_note/features/notes/rich/note_highlight.dart';

void main() {
  group('Callout & Highlight Models', () {
    test(
      'CalloutType colors match vivid Blue for NOTE and Purple for IMPORTANT',
      () {
        expect(CalloutType.note.color, const Color(0xFF0284C7));
        expect(CalloutType.important.color, const Color(0xFFA855F7));
        expect(CalloutType.tip.color, const Color(0xFF10B981));
        expect(CalloutType.warning.color, const Color(0xFFF59E0B));
        expect(CalloutType.caution.color, const Color(0xFFE57582));

        expect(CalloutType.fromString('note'), CalloutType.note);
        expect(CalloutType.fromString('NOTE'), CalloutType.note);
        expect(CalloutType.fromString('important'), CalloutType.important);
        expect(CalloutType.fromString('IMPORTANT'), CalloutType.important);
      },
    );

    test('ParsedCallout header displays formatted label by default', () {
      final noteCallout = ParsedCallout(
        type: CalloutType.note,
        title: '',
        body: 'Observation.',
      );
      expect(noteCallout.headerDisplay, 'Note');

      final impCallout = ParsedCallout(
        type: CalloutType.important,
        title: '',
        body: 'Vital item.',
      );
      expect(impCallout.headerDisplay, 'Important');

      final customCallout = ParsedCallout(
        type: CalloutType.important,
        title: 'Security Warning',
        body: 'Details here.',
      );
      expect(customCallout.headerDisplay, 'Important: Security Warning');
    });

    test(
      'InlineProjection parses ==highlight== and sets highlight style mark',
      () {
        final projection = InlineProjection('This is ==highlighted== text');
        expect(projection.text, 'This is highlighted text');
        // "highlighted" starts at index 8 and ends at index 19
        for (var i = 8; i < 19; i++) {
          expect(
            projection.styles[i].contains('highlight'),
            isTrue,
            reason: 'char at index $i should have highlight style',
          );
        }
        expect(projection.styles[0].contains('highlight'), isFalse);
      },
    );

    test(
      'HighlightInlineSyntax and MarkTagInlineSyntax match highlight tokens',
      () {
        final doc1 = md.Document(inlineSyntaxes: [HighlightInlineSyntax()]);
        final nodes1 = doc1.parseInline('A ==test== text');
        expect(
          nodes1.any(
            (n) =>
                n is md.Element && n.tag == 'mark' && n.textContent == 'test',
          ),
          isTrue,
        );

        final doc2 = md.Document(inlineSyntaxes: [MarkTagInlineSyntax()]);
        final nodes2 = doc2.parseInline('A <mark>test</mark> text');
        expect(
          nodes2.any(
            (n) =>
                n is md.Element && n.tag == 'mark' && n.textContent == 'test',
          ),
          isTrue,
        );
      },
    );

    test('CalloutBlockSyntax parses GitHub/Obsidian callout syntax', () {
      final doc = md.Document(blockSyntaxes: const [CalloutBlockSyntax()]);
      final lines = ['> [!NOTE]', '> A useful observation.', '> Second line.'];
      final nodes = doc.parseLines(lines);
      expect(nodes.length, 1);
      expect(nodes.first, isA<md.Element>());
      final calloutEl = nodes.first as md.Element;
      expect(calloutEl.tag, 'callout');
      expect(calloutEl.attributes['type'], 'NOTE');
      expect(
        calloutEl.children?.first.textContent,
        'A useful observation.\nSecond line.',
      );
    });

    test('CalloutBlockSyntax parses IMPORTANT callout with custom title', () {
      final doc = md.Document(blockSyntaxes: const [CalloutBlockSyntax()]);
      final lines = [
        '> [!IMPORTANT] Critical Safety',
        '> Do not delete vault.',
      ];
      final nodes = doc.parseLines(lines);
      expect(nodes.length, 1);
      final calloutEl = nodes.first as md.Element;
      expect(calloutEl.tag, 'callout');
      expect(calloutEl.attributes['type'], 'IMPORTANT');
      expect(calloutEl.attributes['title'], 'Critical Safety');
      expect(calloutEl.children?.first.textContent, 'Do not delete vault.');
    });
  });

  group('Note Format Toolbar & Editor Widgets', () {
    testWidgets('NoteFormatToolbar triggers NoteFormatAction.highlight', (
      tester,
    ) async {
      NoteFormatAction? selectedAction;
      final undoController = UndoHistoryController();
      addTearDown(undoController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteFormatToolbar(
              onFormat: (a) => selectedAction = a,
              undoController: undoController,
            ),
          ),
        ),
      );

      final highlightBtn = find.byTooltip('Highlight · Ctrl+Shift+H');
      expect(highlightBtn, findsOneWidget);
      await tester.tap(highlightBtn);
      await tester.pump();

      expect(selectedAction, NoteFormatAction.highlight);
    });

    testWidgets(
      'NoteEditor formats text selection with ==highlight== on highlight action',
      (tester) async {
        var body = 'Welcome to Orbit Note';
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NoteEditor(
                initialViewState: const {'mode': 'write'},
                noteId: 'note-hl-1',
                title: 'Highlight Note',
                body: body,
                onTitleChanged: (_) {},
                onBodyChanged: (v) => body = v,
                linkTargets: const [NoteLinkTarget(id: 't-1', title: 'Target')],
                onOpenObject: (_) {},
              ),
            ),
          ),
        );

        final field = find.byKey(const ValueKey('note-body'));
        final textField = tester.widget<TextField>(field);
        textField.controller!.selection = const TextSelection(
          baseOffset: 11,
          extentOffset: 16, // "Orbit"
        );

        await tester.tap(find.byTooltip('Highlight · Ctrl+Shift+H'));
        await tester.pump();

        expect(body, 'Welcome to ==Orbit== Note');
      },
    );

    testWidgets(
      'NoteEditor handles Ctrl+Shift+H shortcut for highlight formatting',
      (tester) async {
        var body = 'Highlight this idea';
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NoteEditor(
                initialViewState: const {'mode': 'write'},
                noteId: 'note-hl-2',
                title: 'Shortcut Note',
                body: body,
                onTitleChanged: (_) {},
                onBodyChanged: (v) => body = v,
                linkTargets: const [],
                onOpenObject: (_) {},
              ),
            ),
          ),
        );

        final field = find.byKey(const ValueKey('note-body'));
        await tester.tap(field);
        await tester.pump();
        final textField = tester.widget<TextField>(field);
        textField.controller!.selection = const TextSelection(
          baseOffset: 15,
          extentOffset: 19, // "idea"
        );

        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        await tester.pump();

        expect(body, 'Highlight this ==idea==');
      },
    );

    testWidgets(
      'MarkdownBody in NoteEditor renders callouts with side color and nested highlights',
      (tester) async {
        const markdownContent =
            '> [!IMPORTANT]\n> Keep in mind that ==yellow highlight== is prominent.\n\n> [!NOTE]\n> A blue accent note.';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NoteEditor(
                initialViewState: const {'mode': 'read'},
                noteId: 'note-hl-3',
                title: 'Preview Note',
                body: markdownContent,
                onTitleChanged: (_) {},
                onBodyChanged: (_) {},
                linkTargets: const [],
                onOpenObject: (_) {},
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('note-preview')), findsOneWidget);

        // Verify the headers are rendered
        expect(find.text('IMPORTANT'), findsOneWidget);
        expect(find.text('NOTE'), findsOneWidget);

        // Verify the nested highlight text is rendered
        expect(find.text('yellow highlight'), findsOneWidget);

        // Verify containers for the colored side-bars exist
        final containers = tester.widgetList<Container>(find.byType(Container));
        final hasPurpleBar = containers.any(
          (c) =>
              c.constraints?.maxWidth == 4 &&
              (c.color == const Color(0xFFA855F7)),
        );
        final hasBlueBar = containers.any(
          (c) =>
              c.constraints?.maxWidth == 4 &&
              (c.color == const Color(0xFF0284C7)),
        );
        expect(
          hasPurpleBar,
          isTrue,
          reason: 'IMPORTANT callout should have purple 4px side bar',
        );
        expect(
          hasBlueBar,
          isTrue,
          reason: 'NOTE callout should have vivid blue 4px side bar',
        );
      },
    );
  });
}
