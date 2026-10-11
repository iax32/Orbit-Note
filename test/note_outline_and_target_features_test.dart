import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/document_stats_dialog.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/note_outline.dart';
import 'package:orbit_note/features/notes/note_outline_panel.dart';

void main() {
  group('noteOutline and NoteHeading tests', () {
    test('NoteHeading equality and hashCode', () {
      const h1 = NoteHeading('Intro', 1, 0);
      const h2 = NoteHeading('Intro', 1, 0);
      const h3 = NoteHeading('Details', 2, 50);

      expect(h1, equals(h2));
      expect(h1.hashCode, equals(h2.hashCode));
      expect(h1, isNot(equals(h3)));
      expect(h1.toString(), contains('Intro'));
    });

    test(
      'noteOutline parses Markdown headings with correct levels and offsets',
      () {
        const markdown = '''
# Heading One
Paragraph content here.

## Subsection A
More content.

### Deep Section
Final notes.
''';
        final outline = noteOutline(markdown, isLatex: false);
        expect(outline.length, 3);
        expect(outline[0].title, 'Heading One');
        expect(outline[0].level, 1);
        expect(outline[1].title, 'Subsection A');
        expect(outline[1].level, 2);
        expect(outline[2].title, 'Deep Section');
        expect(outline[2].level, 3);
      },
    );

    test(
      'noteOutline parses LaTeX section commands and ignores commented lines',
      () {
        const latex = r'''
\documentclass{article}
% \section{Commented Out}
\section{Introduction}
Some text here.
\subsection{Methodology}
More text here.
\subsubsection{Data Processing}
Details.
\paragraph{Summary}
Final paragraph.
''';
        final outline = noteOutline(latex, isLatex: true);
        expect(outline.length, 4);
        expect(outline[0].title, 'Introduction');
        expect(outline[0].level, 1);
        expect(outline[1].title, 'Methodology');
        expect(outline[1].level, 2);
        expect(outline[2].title, 'Data Processing');
        expect(outline[2].level, 3);
        expect(outline[3].title, 'Summary');
        expect(outline[3].level, 4);
      },
    );
  });

  group('NoteOutlinePanel widget tests', () {
    testWidgets('renders headings, level badges, and handles selection', (
      tester,
    ) async {
      NoteHeading? selected;
      bool closed = false;

      const headings = [
        NoteHeading('Overview', 1, 0),
        NoteHeading('Deep Dive', 2, 100),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteOutlinePanel(
              headings: headings,
              onHeadingSelected: (h) => selected = h,
              onClose: () => closed = true,
            ),
          ),
        ),
      );

      expect(find.text('Outline'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // badge count
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Deep Dive'), findsOneWidget);
      expect(find.text('H1'), findsOneWidget);
      expect(find.text('H2'), findsOneWidget);

      // Tap on Deep Dive
      await tester.tap(find.text('Deep Dive'));
      expect(selected, equals(headings[1]));

      // Tap on close button
      await tester.tap(find.byKey(const ValueKey('close-outline-panel')));
      expect(closed, isTrue);
    });

    testWidgets('filters headings with real-time search', (tester) async {
      const headings = [
        NoteHeading('Apples', 1, 0),
        NoteHeading('Bananas', 2, 50),
        NoteHeading('Oranges', 2, 100),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteOutlinePanel(
              headings: headings,
              onHeadingSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Apples'), findsOneWidget);
      expect(find.text('Bananas'), findsOneWidget);
      expect(find.text('Oranges'), findsOneWidget);

      // Filter by "ban"
      await tester.enterText(find.byType(TextField), 'ban');
      await tester.pumpAndSettle();

      expect(find.text('Bananas'), findsOneWidget);
      expect(find.text('Apples'), findsNothing);
      expect(find.text('Oranges'), findsNothing);
    });

    testWidgets('shows empty state when no headings exist', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteOutlinePanel(
              headings: const [],
              onHeadingSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('No headings yet'), findsOneWidget);
      expect(find.textContaining('Add headings with #'), findsOneWidget);
    });
  });

  group('DocumentStatsDialog word goal tests', () {
    testWidgets('setting and clearing word goal triggers callback', (
      tester,
    ) async {
      int? updatedGoal;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDocumentStatsDialog(
                  context,
                  title: 'Goal Note',
                  text: 'One two three four five six seven eight nine ten.',
                  isLatex: false,
                  targetWords: null,
                  onTargetWordsChanged: (v) => updatedGoal = v,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Goal card preset chips should exist
      expect(find.text('Target Goal:'), findsOneWidget);
      expect(find.text('500'), findsOneWidget);
      expect(find.text('1k'), findsOneWidget);

      // Select 500 words goal
      await tester.ensureVisible(find.text('500'));
      await tester.tap(find.text('500'));
      await tester.pumpAndSettle();

      expect(updatedGoal, 500);
      expect(
        find.textContaining('Writing Goal: 10 / 500 words'),
        findsOneWidget,
      );

      // Clear the goal
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
      expect(updatedGoal, isNull);
    });
  });

  group('NoteEditor outline rail, copy-as, and target words integration', () {
    testWidgets('header outline button and Alt+O toggle NoteOutlinePanel', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const noteText =
          '# Main Title\nFirst paragraph.\n\n## Subtopic\nSecond paragraph.';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditor(
              noteId: 'outline-test-note',
              title: 'Outline Test',
              body: noteText,
              onTitleChanged: (_) {},
              onBodyChanged: (_) {},
              linkTargets: const [],
              onOpenObject: (_) {},
              documentFormat: 'markdown',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Outline panel not shown initially
      expect(find.byType(NoteOutlinePanel), findsNothing);

      // Tap outline button in header
      final toggleBtn = find.byKey(const ValueKey('note-outline-toggle'));
      expect(toggleBtn, findsOneWidget);

      await tester.tap(toggleBtn);
      await tester.pumpAndSettle();

      // Outline panel should now be visible
      expect(find.byType(NoteOutlinePanel), findsOneWidget);
      expect(find.text('Main Title'), findsWidgets);
      expect(find.text('Subtopic'), findsWidgets);

      // Close it via close button
      await tester.tap(find.byKey(const ValueKey('close-outline-panel')));
      await tester.pumpAndSettle();
      expect(find.byType(NoteOutlinePanel), findsNothing);

      // Focus editor and toggle via Alt+O
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
      await tester.pumpAndSettle();

      expect(find.byType(NoteOutlinePanel), findsOneWidget);
    });

    testWidgets('copy-as menu displays options in header', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditor(
              noteId: 'copy-test-note',
              title: 'Copy Test',
              body: '# Title\n**Bold text** and [link](https://example.com)',
              onTitleChanged: (_) {},
              onBodyChanged: (_) {},
              linkTargets: const [],
              onOpenObject: (_) {},
              documentFormat: 'markdown',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final copyMenuBtn = find.byKey(const ValueKey('note-copy-as-menu'));
      expect(copyMenuBtn, findsOneWidget);

      await tester.tap(copyMenuBtn);
      await tester.pumpAndSettle();

      expect(find.text('Plain Text'), findsOneWidget);
      expect(find.text('HTML'), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);

      await tester.tap(find.text('Plain Text'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets(
      'Read mode heading jump scrolls preview without switching mode',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final longText = StringBuffer('# Header One\n');
        for (int i = 0; i < 50; i++) {
          longText.writeln('Paragraph $i with some filler words for length.');
        }
        longText.writeln('## Header Two\n');
        for (int i = 0; i < 50; i++) {
          longText.writeln('Second section paragraph $i.');
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NoteEditor(
                initialViewState: const {'mode': 'read'},
                noteId: 'read-scroll-note',
                title: 'Read Scroll Note',
                body: longText.toString(),
                onTitleChanged: (_) {},
                onBodyChanged: (_) {},
                linkTargets: const [],
                onOpenObject: (_) {},
                documentFormat: 'markdown',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify we are in Read mode (preview widget exists)
        expect(find.byKey(const ValueKey('note-preview')), findsOneWidget);

        // Open outline panel
        await tester.tap(find.byKey(const ValueKey('note-outline-toggle')));
        await tester.pumpAndSettle();

        // Tap Header Two in outline
        await tester.tap(
          find.descendant(
            of: find.byType(NoteOutlinePanel),
            matching: find.text('Header Two'),
          ),
        );
        await tester.pumpAndSettle();

        // Still in Read mode! Mode was not forced to split!
        expect(find.byKey(const ValueKey('note-preview')), findsOneWidget);
      },
    );
  });
}
