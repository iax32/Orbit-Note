import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/read_search_overlay.dart';

void main() {
  late String body;
  Future<void> open(WidgetTester tester, String source) async {
    body = source;
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => NoteEditor(
              noteId: 'read-search',
              title: 'Read',
              body: body,
              initialViewState: const {'mode': 'read'},
              onTitleChanged: (_) {},
              onBodyChanged: (v) => update(() => body = v),
              linkTargets: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder query() => find.widgetWithText(TextField, 'Find in this note');
  Future<void> search(WidgetTester tester, String term) async {
    await tester.tap(find.byTooltip('Find in note · Ctrl+F'));
    await tester.pumpAndSettle();
    await tester.enterText(query(), term);
    await tester.pumpAndSettle();
  }

  ReadSearchOverlayState overlay(WidgetTester tester) =>
      tester.state(find.byType(ReadSearchOverlay));
  bool highlights(WidgetTester tester) => tester
      .widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(ReadSearchOverlay),
          matching: find.byType(CustomPaint),
        ),
      )
      .any((w) => w.foregroundPainter != null);
  testWidgets(
    'many matches in one paragraph retain exact navigation and source',
    (tester) async {
      final source = List.filled(1000, 'target').join(' ');
      await open(tester, source);
      await search(tester, 'target');
      expect(find.text('1000 matches'), findsOneWidget);
      expect(highlights(tester), isTrue);
      await tester.tap(find.byTooltip('Previous match'));
      await tester.pumpAndSettle();
      expect(find.text('(1000 of 1000)'), findsOneWidget);
      expect(overlay(tester).revealSelected(), isTrue);
      expect(body, source);
    },
  );
  testWidgets(
    'Read highlights formatted prose and preserves Find focus/source',
    (tester) async {
      const source =
          '# Heading target\n\n**target** and [target](https://example.com)\n';
      await open(tester, source);
      await search(tester, 'target');
      expect(highlights(tester), isTrue);
      expect(overlay(tester).revealSelected(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('3 matches'), findsOneWidget);
      expect(tester.widget<TextField>(query()).focusNode!.hasFocus, isTrue);
      expect(body, source);
    },
  );
  testWidgets(
    'next match reveals distant prose by layout rather than source ratio',
    (tester) async {
      final paragraphs = List.generate(
        70,
        (i) => 'Paragraph $i with several ordinary words.',
      ).join('\n\n');
      await open(tester, 'target start\n\n$paragraphs\n\nlast target');
      await search(tester, 'target');
      await tester.tap(find.byTooltip('Next match'));
      await tester.pumpAndSettle();
      final editable = tester.state<EditableTextState>(
        find
            .byType(EditableText)
            .evaluate()
            .where(
              (e) =>
                  (e.widget as EditableText).controller.text == 'last target',
            )
            .map((e) => find.byWidget(e.widget))
            .first,
      );
      final render = editable.renderEditable;
      final point = render.localToGlobal(
        render.getLocalRectForCaret(const TextPosition(offset: 5)).center,
      );
      expect(point.dy, inInclusiveRange(100, 900));
      expect(find.text('(2 of 2)'), findsOneWidget);
      expect(tester.widget<TextField>(query()).focusNode!.hasFocus, isTrue);
    },
  );
  testWidgets(
    'Read code match reveals both distant line and horizontal column',
    (tester) async {
      final lines = List.generate(75, (i) => 'line $i').join('\n');
      final code = '$lines\n${'x' * 220} target';
      await open(tester, '```text\n$code\n```\n');
      await search(tester, 'target');
      expect(overlay(tester).revealSelected(), isTrue);
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('rich-code'));
      final editable = tester.state<EditableTextState>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      final render = editable.renderEditable;
      final point = render.localToGlobal(
        render
            .getLocalRectForCaret(TextPosition(offset: code.length - 6))
            .center,
      );
      expect(point.dx, inInclusiveRange(0, 1280));
      expect(point.dy, inInclusiveRange(100, 900));
      expect(body, '```text\n$code\n```\n');
    },
  );
  testWidgets('whole-word and match-case options control rendered highlights', (
    tester,
  ) async {
    await open(tester, 'cat catch Cat été étéx');
    await search(tester, 'cat');
    expect(highlights(tester), isTrue);
    await tester.tap(find.byTooltip('Match whole word · Alt+W'));
    await tester.tap(find.byTooltip('Match case · Alt+C'));
    await tester.pumpAndSettle();
    expect(find.text('1 match'), findsOneWidget);
    expect(overlay(tester).revealSelected(), isTrue);
    await tester.enterText(query(), 'été');
    await tester.pumpAndSettle();
    expect(find.text('1 match'), findsOneWidget);
    expect(highlights(tester), isTrue);
  });
  for (final eol in ['\n', '\r\n']) {
    testWidgets(
      "multiline code Find maps ${eol == '\r\n' ? 'CRLF' : 'LF'} without changing source",
      (tester) async {
        final code = eol == '\r\n' ? 'first\r\nsecond' : 'first\nsecond';
        final source = eol == '\r\n'
            ? '```text\r\n$code\r\n```\r\n'
            : '```text\n$code\n```\n';
        await open(tester, source);
        await search(tester, code);
        expect(tester.widget<TextField>(query()).controller!.text, code);
        expect(find.text('1 match'), findsOneWidget);
        expect(highlights(tester), isTrue);
        expect(overlay(tester).revealSelected(), isTrue);
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(query()).focusNode!.hasFocus, isTrue);
        expect(body, source);
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('rich-code')))
              .controller!
              .text,
          'first\nsecond',
        );
      },
    );
  }
  testWidgets('Read navigates folded Unicode hits across code and prose', (
    tester,
  ) async {
    const source =
        'Straße prose\r\n\r\n```text metadata=STRASSE\r\n'
        '😀 Straße\r\n```\r\n\r\n~~~text\r\nSTRASSE\r\n~~~\r\n';
    await open(tester, source);
    await search(tester, 'strasse');
    expect(find.text('3 matches'), findsOneWidget);
    expect(highlights(tester), isTrue);
    for (var i = 1; i <= 3; i++) {
      expect(find.text('($i of 3)'), findsOneWidget);
      expect(overlay(tester).revealSelected(), isTrue);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next match'));
      await tester.pumpAndSettle();
    }
    expect(find.text('(1 of 3)'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous match'));
    await tester.pumpAndSettle();
    expect(find.text('(3 of 3)'), findsOneWidget);
    expect(overlay(tester).revealSelected(), isTrue);
    expect(tester.widget<TextField>(query()).focusNode!.hasFocus, isTrue);
    expect(body, source);
  });
  testWidgets('Read code rejects query matches in language metadata', (
    tester,
  ) async {
    const source = '```target\r\nordinary body\r\n```\r\n';
    await open(tester, source);
    await search(tester, 'target');
    expect(find.text('0 matches'), findsOneWidget);
    expect(overlay(tester).revealSelected(), isFalse);
    expect(body, source);
  });
  testWidgets('closing Find clears decorations without changing the note', (
    tester,
  ) async {
    await open(tester, 'target');
    await search(tester, 'target');
    expect(highlights(tester), isTrue);
    await tester.tap(find.byTooltip('Close find'));
    await tester.pumpAndSettle();
    expect(highlights(tester), isFalse);
    expect(body, 'target');
  });
  testWidgets(
    'formatted custom body mismatch safely refuses ordinal navigation',
    (tester) async {
      await open(tester, '> [!NOTE] Title\n> **target**\n');
      await search(tester, 'target');
      expect(overlay(tester).revealSelected(), isFalse);
      expect(highlights(tester), isFalse);
      expect(body, '> [!NOTE] Title\n> **target**\n');
    },
  );
  testWidgets(
    'equal match counts with different rendered ownership are refused',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReadSearchOverlay(
              request: ReadSearchRequest(
                query: 'target',
                expectedCount: 1,
                expectedSegments: ['source target'],
                visibleIndices: {0},
                selectedIndex: 0,
                matchCase: false,
                wholeWord: false,
              ),
              child: SelectableText('different target'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(overlay(tester).revealSelected(), isFalse);
      expect(highlights(tester), isFalse);
    },
  );
  testWidgets('Read table matches map to visible cells without metadata', (
    tester,
  ) async {
    await open(tester, '| Name | Detail |\n| --- | --- |\n| item | target |\n');
    await search(tester, 'target');
    expect(highlights(tester), isTrue);
    expect(overlay(tester).revealSelected(), isTrue);
    await tester.pumpAndSettle();
    expect(body, '| Name | Detail |\n| --- | --- |\n| item | target |\n');
  });
  testWidgets('zero matches and a mode switch remove stale highlights', (
    tester,
  ) async {
    await open(tester, '**target**');
    await search(tester, 'target');
    await tester.enterText(query(), 'missing');
    await tester.pumpAndSettle();
    expect(highlights(tester), isFalse);
    expect(overlay(tester).revealSelected(), isFalse);
    await tester.tap(find.text('Source'));
    await tester.pumpAndSettle();
    expect(find.byType(ReadSearchOverlay), findsNothing);
    expect(body, '**target**');
  });
}
