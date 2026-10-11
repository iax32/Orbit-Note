import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/document_stats_dialog.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/shortcuts_dialog.dart';

void main() {
  group('DocumentStats unit tests', () {
    test('computes accurately for empty text', () {
      final stats = DocumentStats.compute('');
      expect(stats.words, 0);
      expect(stats.characters, 0);
      expect(stats.charactersNoSpaces, 0);
      expect(stats.paragraphs, 0);
      expect(stats.sentences, 0);
      expect(stats.headings, 0);
      expect(stats.readingMinutes, 0);
      expect(stats.readingSeconds, 0);
      expect(stats.readingTimeFormatted, '< 1 min');
      expect(stats.speakingTimeFormatted, '< 1 min');
    });

    test(
      'computes accurately for Markdown text with headings and paragraphs',
      () {
        const text = '''
# Heading 1

This is the first paragraph. It has two sentences!

## Heading 2

Here is another paragraph with some words for testing.
''';
        final stats = DocumentStats.compute(text, isLatex: false);
        expect(stats.headings, 2);
        expect(stats.paragraphs, 4); // 2 headings + 2 paragraphs
        expect(stats.words, greaterThan(15));
        expect(stats.characters, text.runes.length);
        expect(
          stats.charactersNoSpaces,
          text.replaceAll(RegExp(r'\s'), '').runes.length,
        );
        expect(stats.sentences, greaterThanOrEqualTo(3));
      },
    );

    test('computes accurately for LaTeX text with section commands', () {
      const latex = r'''
\section{Introduction}
This is an introductory paragraph with math $x^2 + y^2 = z^2$.

\subsection{Details}
A second paragraph with further exposition and details.
''';
      final stats = DocumentStats.compute(latex, isLatex: true);
      expect(stats.headings, 2);
      expect(stats.words, greaterThan(10));
    });

    test('formatSummary formats comprehensive statistics', () {
      final stats = DocumentStats.compute('Hello world! How are you today?');
      final summary = stats.formatSummary(title: 'Greeting Note');
      expect(summary, contains('Greeting Note'));
      expect(summary, contains('Words: 6'));
      expect(summary, contains('Estimated reading time:'));
    });
  });

  group('DocumentStatsDialog widget tests', () {
    testWidgets('renders metric cards and responds to interactions', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDocumentStatsDialog(
                  context,
                  title: 'Test Note',
                  text:
                      'First paragraph with some words.\n\nSecond paragraph here.',
                  selectedText: 'First paragraph',
                  isLatex: false,
                ),
                child: const Text('Open Stats'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Stats'));
      await tester.pumpAndSettle();

      expect(find.text('Document Analytics'), findsOneWidget);
      expect(find.text('Test Note'), findsOneWidget);
      expect(find.text('Words'), findsOneWidget);
      expect(find.text('Characters'), findsOneWidget);
      expect(find.text('Paragraphs'), findsOneWidget);
      expect(find.text('Reading Time'), findsOneWidget);
      expect(find.text('Speaking Time'), findsOneWidget);

      // Verify tabs for selection exist
      expect(find.text('Full Document'), findsOneWidget);
      expect(find.text('Selected Text'), findsOneWidget);

      // Switch tab to Selected Text
      await tester.tap(find.text('Selected Text'));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsWidgets); // 2 words in "First paragraph"

      // Click Copy Stats
      await tester.tap(find.text('Copy Stats'));
      await tester.pump();
      expect(find.text('Copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));

      // Close dialog
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Document Analytics'), findsNothing);
    });
  });

  group('ShortcutsDialog widget tests', () {
    testWidgets('renders shortcuts and filters accurately', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showShortcutsCheatsheet(context),
                child: const Text('Open Shortcuts'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Shortcuts'));
      await tester.pumpAndSettle();

      expect(find.text('Keyboard Shortcuts'), findsOneWidget);
      expect(find.text('TEXT FORMATTING'), findsOneWidget);
      expect(find.text('Bold'), findsOneWidget);
      expect(find.text('Ctrl'), findsWidgets);

      // Search for "date"
      await tester.enterText(find.byType(TextField), 'date');
      await tester.pumpAndSettle();

      expect(find.textContaining('Insert current date'), findsOneWidget);
      expect(find.text('Bold'), findsNothing);

      // Clear search
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      expect(find.text('Bold'), findsOneWidget);

      // Close dialog
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Keyboard Shortcuts'), findsNothing);
    });
  });

  group('NoteEditor ergonomics and shortcuts integration', () {
    testWidgets('shortcuts help button in header opens cheatsheet', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1100, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditor(
              noteId: 'ergonomics-test-note',
              title: 'Ergonomics Note',
              body: 'A quick test note with content.',
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

      // Help button should be present in header
      final helpBtn = find.byKey(const ValueKey('note-shortcuts-button'));
      expect(helpBtn, findsOneWidget);

      await tester.tap(helpBtn);
      await tester.pumpAndSettle();

      expect(find.text('Keyboard Shortcuts'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Keyboard Shortcuts'), findsNothing);
    });

    testWidgets(
      'clicking document metrics in footer opens Document Analytics dialog',
      (tester) async {
        tester.view.physicalSize = const Size(1100, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NoteEditor(
                noteId: 'stats-test-note',
                title: 'Stats Note',
                body: 'Line one words.\n\nLine two words.',
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

        final statsFooter = find.byKey(const ValueKey('document-stats'));
        expect(statsFooter, findsOneWidget);

        await tester.tap(statsFooter);
        await tester.pumpAndSettle();

        expect(find.text('Document Analytics'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.text('Stats Note'),
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(find.text('Document Analytics'), findsNothing);
      },
    );

    testWidgets('Alt+1, Alt+2, Alt+4 switch editor modes smoothly', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1100, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditor(
              noteId: 'mode-switch-note',
              title: 'Mode Switch Note',
              body: '# Heading\nParagraph body.',
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

      // Focus editor so CallbackShortcuts receives key events
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();

      // Switch to Source mode via Alt+2
      await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('note-body')), findsOneWidget);

      // Switch to Read mode via Alt+4
      await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('note-preview')), findsOneWidget);
    });
  });
}
