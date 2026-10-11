import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/note_editor.dart';

void main() {
  Widget buildEditor({
    required String body,
    ValueChanged<String>? onBodyChanged,
    Map<String, dynamic> initialViewState = const {'mode': 'write'},
  }) {
    return MaterialApp(
      home: Scaffold(
        body: NoteEditor(
          noteId: 'test-note',
          title: 'Test Note',
          body: body,
          onTitleChanged: (_) {},
          onBodyChanged: onBodyChanged ?? (_) {},
          linkTargets: const [],
          onOpenObject: (_) {},
          initialViewState: initialViewState,
        ),
      ),
    );
  }

  group('Document metrics and reading time', () {
    testWidgets(
      'unselected metrics show total words, characters, and reading time',
      (tester) async {
        const text = 'One two three four five six seven eight nine ten.';
        await tester.pumpWidget(buildEditor(body: text));
        await tester.pumpAndSettle();

        final stats = find.byKey(const ValueKey('document-stats'));
        expect(stats, findsOneWidget);
        final widget = tester.widget<Text>(stats);
        expect(widget.data, contains('10 words'));
        expect(widget.data, contains('characters'));
        expect(widget.data, contains('~1 min read'));
        expect(widget.data, isNot(contains('Selection:')));
      },
    );

    testWidgets(
      'selected metrics show explicit Selection and Document scopes with read times',
      (tester) async {
        const text =
            'Alpha beta gamma delta epsilon zeta eta theta iota kappa.';
        await tester.pumpWidget(buildEditor(body: text));
        await tester.pumpAndSettle();

        final field = find.byKey(const ValueKey('note-body'));
        final controller = tester.widget<TextField>(field).controller!;
        controller.selection = const TextSelection(
          baseOffset: 0,
          extentOffset: 16,
        ); // "Alpha beta gamma"
        await tester.pump();

        final stats = find.byKey(const ValueKey('document-stats'));
        final widget = tester.widget<Text>(stats);
        expect(
          widget.data,
          contains('Selection: 3 of 10 words (16 chars, < 1 min read)'),
        );
        expect(
          widget.data,
          contains('Document: 10 words (57 characters, ~1 min read)'),
        );
      },
    );
  });

  group('Find & Replace with match index and navigation', () {
    testWidgets('seeds search term from short single-line selection', (
      tester,
    ) async {
      const text = 'First sample and second sample in text.';
      await tester.pumpWidget(buildEditor(body: text));
      await tester.pumpAndSettle();

      final field = find.byKey(const ValueKey('note-body'));
      final controller = tester.widget<TextField>(field).controller!;
      controller.selection = const TextSelection(
        baseOffset: 6,
        extentOffset: 12,
      ); // "sample"
      await tester.pump();

      await tester.tap(find.byTooltip('Find in note · Ctrl+F'));
      await tester.pump();

      final findField = find.widgetWithText(TextField, 'Find in this note');
      expect(findField, findsOneWidget);
      expect(tester.widget<TextField>(findField).controller!.text, 'sample');
      expect(find.text('2 matches'), findsOneWidget);
      expect(find.text('(1 of 2)'), findsOneWidget);
    });

    testWidgets('seeds selection scope from multi-line selection', (
      tester,
    ) async {
      const text =
          'Line one\nLine two with target\nLine three with target\nLine four';
      await tester.pumpWidget(buildEditor(body: text));
      await tester.pumpAndSettle();

      final field = find.byKey(const ValueKey('note-body'));
      final controller = tester.widget<TextField>(field).controller!;
      // Select lines 2 and 3
      final start = text.indexOf('Line two');
      final end = text.indexOf('\nLine four');
      controller.selection = TextSelection(
        baseOffset: start,
        extentOffset: end,
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Find in note · Ctrl+F'));
      await tester.pump();

      // Should be in selection mode
      expect(
        find.byTooltip('Find in selection (active) · Alt+S'),
        findsOneWidget,
      );
      expect(find.text('In Selection'), findsOneWidget);

      final findField = find.widgetWithText(TextField, 'Find in this note');
      await tester.enterText(findField, 'target');
      await tester.pump();

      expect(find.text('2 matches'), findsOneWidget);
      expect(find.text('(1 of 2)'), findsOneWidget);
    });

    testWidgets('bidirectional navigation updates match index and selection', (
      tester,
    ) async {
      const text = 'word one, word two, word three, word four';
      await tester.pumpWidget(buildEditor(body: text));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Find in note · Ctrl+F'));
      await tester.pump();

      final findField = find.widgetWithText(TextField, 'Find in this note');
      await tester.enterText(findField, 'word');
      await tester.pump();

      expect(find.text('4 matches'), findsOneWidget);
      expect(find.text('(1 of 4)'), findsOneWidget);

      final controller = tester
          .widget<TextField>(find.byKey(const ValueKey('note-body')))
          .controller!;
      expect(controller.selection.start, 0);
      expect(controller.selection.end, 4);

      // Next match -> (2 of 4)
      await tester.tap(find.byTooltip('Next match'));
      await tester.pump();
      expect(find.text('(2 of 4)'), findsOneWidget);
      expect(controller.selection.start, text.indexOf('word two'));

      // Next match -> (3 of 4)
      await tester.tap(find.byTooltip('Next match'));
      await tester.pump();
      expect(find.text('(3 of 4)'), findsOneWidget);
      expect(controller.selection.start, text.indexOf('word three'));

      // Previous match -> back to (2 of 4)
      await tester.tap(find.byTooltip('Previous match'));
      await tester.pump();
      expect(find.text('(2 of 4)'), findsOneWidget);
      expect(controller.selection.start, text.indexOf('word two'));
    });

    testWidgets('case sensitivity toggle Aa distinguishes case', (
      tester,
    ) async {
      const text = 'Hello world, hello orbit, HELLO everyone';
      await tester.pumpWidget(buildEditor(body: text));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Find in note · Ctrl+F'));
      await tester.pump();

      final findField = find.widgetWithText(TextField, 'Find in this note');
      await tester.enterText(findField, 'Hello');
      await tester.pump();

      // Case-insensitive by default -> 3 matches
      expect(find.text('3 matches'), findsOneWidget);

      // Toggle match case
      await tester.tap(find.byTooltip('Match case · Alt+C'));
      await tester.pump();

      // Exact case -> only 1 match ("Hello")
      expect(find.text('1 match'), findsOneWidget);
      expect(find.text('(1 of 1)'), findsOneWidget);
    });

    testWidgets('whole word toggle matches exact word tokens only', (
      tester,
    ) async {
      const text = 'cat catch category catalog cat concatenate';
      await tester.pumpWidget(buildEditor(body: text));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Find in note · Ctrl+F'));
      await tester.pump();

      final findField = find.widgetWithText(TextField, 'Find in this note');
      await tester.enterText(findField, 'cat');
      await tester.pump();

      // Without whole word: 6 matches
      expect(find.text('6 matches'), findsOneWidget);

      // Toggle whole word
      await tester.tap(find.byTooltip('Match whole word · Alt+W'));
      await tester.pump();

      // Only standalone "cat" matches (2 times)
      expect(find.text('2 matches'), findsOneWidget);
    });
  });

  group('Selection-scoped replacement', () {
    testWidgets(
      'Replace all in selection restricts replacements strictly inside scope',
      (tester) async {
        var currentBody =
            'outer apple [apple inside apple and apple] outer apple';
        await tester.pumpWidget(
          buildEditor(body: currentBody, onBodyChanged: (v) => currentBody = v),
        );
        await tester.pumpAndSettle();

        final field = find.byKey(const ValueKey('note-body'));
        final controller = tester.widget<TextField>(field).controller!;
        final scopeStart = currentBody.indexOf('[apple');
        final scopeEnd = currentBody.indexOf('] outer') + 1;
        controller.selection = TextSelection(
          baseOffset: scopeStart,
          extentOffset: scopeEnd,
        );
        await tester.pump();

        // Open find
        await tester.tap(find.byTooltip('Find in note · Ctrl+F'));
        await tester.pump();

        // Set find query
        final findField = find.widgetWithText(TextField, 'Find in this note');
        await tester.enterText(findField, 'apple');
        await tester.pump();

        // Toggle to in-selection scope
        await tester.tap(find.byTooltip('Find in selection · Alt+S'));
        await tester.pump();

        // Set replacement query
        final replaceField = find.byKey(const ValueKey('note-replacement'));
        await tester.enterText(replaceField, 'orange');
        await tester.pump();

        // Verify scope is in selection
        expect(find.text('3 matches'), findsOneWidget);
        expect(find.text('Replace all in selection'), findsOneWidget);

        // Click Replace all in selection
        await tester.tap(find.text('Replace all in selection'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Apply '));
        await tester.pump();

        // The 3 apples inside [ ... ] are replaced with orange; outer apples remain untouched!
        expect(
          currentBody,
          'outer apple [orange inside orange and orange] outer apple',
        );
      },
    );

    testWidgets('single Replace replaces current match and advances', (
      tester,
    ) async {
      var currentBody = 'cat and cat and cat';
      await tester.pumpWidget(
        buildEditor(body: currentBody, onBodyChanged: (v) => currentBody = v),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Find in note · Ctrl+F'));
      await tester.pump();

      final findField = find.widgetWithText(TextField, 'Find in this note');
      await tester.enterText(findField, 'cat');
      await tester.pump();

      final replaceField = find.byKey(const ValueKey('note-replacement'));
      await tester.enterText(replaceField, 'dog');
      await tester.pump();

      expect(find.text('3 matches'), findsOneWidget);
      expect(find.text('(1 of 3)'), findsOneWidget);

      // Single replace first occurrence
      await tester.tap(find.text('Replace'));
      await tester.pump();

      expect(currentBody, 'dog and cat and cat');
      expect(find.text('2 matches'), findsOneWidget);
      expect(find.text('(1 of 2)'), findsOneWidget);
    });
  });
}
