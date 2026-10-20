import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/rich/callout_block.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';
import 'package:orbit_note/features/notes/rich/structured_text_projection.dart';
import 'package:orbit_note/features/notes/note_find_index.dart';

void main() {
  testWidgets(
    'callout defaults are undoable and title controls fit enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var body =
          '> [!BTW] A long helpful title for the narrow editor\n> Keep this content.\n';
      final original = body;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, setState) => NoteEditor(
                noteId: 'n',
                title: 'Note',
                body: body,
                onTitleChanged: (_) {},
                onBodyChanged: (s) => setState(() => body = s),
                linkTargets: const [],
                onOpenObject: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byTooltip('Callout options').hitTestable(),
        100,
        scrollable: find
            .descendant(
              of: find.byType(RichMarkdownEditor),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Callout options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Make collapsible'));
      await tester.pumpAndSettle();
      expect(body, contains('[!BTW]+'));
      await tester.tap(find.byTooltip('Callout options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start collapsed'));
      await tester.pumpAndSettle();
      expect(body, contains('[!BTW]-'));
      expect(find.byKey(const ValueKey('callout-body')), findsNothing);
      final before = body;
      await tester.tap(find.byTooltip('Expand callout'));
      await tester.pumpAndSettle();
      expect(body, before);
      await tester.tap(find.byTooltip('Undo · Ctrl+Z'));
      await tester.pumpAndSettle();
      expect(body, contains('[!BTW]+'));
      await tester.tap(find.byTooltip('Undo · Ctrl+Z'));
      await tester.pumpAndSettle();
      expect(body, original);
      expect(tester.takeException(), isNull);
    },
  );
  test('BTW and folded unknown types retain title/body offsets and source', () {
    for (final type in ['BTW', 'MYSTERY']) {
      final source = '> [!$type]-   Title  \r\n> Body\r\n';
      final parts = CalloutSourceParts(source),
          parsed = ParsedCallout.parse(source);
      expect(parsed.title, 'Title');
      expect(parsed.fold, '-');
      expect(parsed.rawType, type);
      expect(source.substring(parts.titleStart, parts.titleEnd), 'Title');
      expect(
        parts.editTitle('Renamed'),
        source.replaceFirst('Title', 'Renamed'),
      );
      expect(parts.editBody('Changed'), contains('> [!$type]-   Title  \r\n'));
      final match = NoteFindIndex(source, rich: true).matches('Title').single;
      expect(source.substring(match.start, match.end), 'Title');
    }
    expect(
      CalloutSourceParts('> [!BTW]-\n> Body\n').editTitle('Extra'),
      '> [!BTW]- Extra\n> Body\n',
    );
    expect(
      ParsedCallout.parse('> [!MYSTERY]- Title\n> Body\n').toMarkdown(),
      '> [!MYSTERY]- Title\n> Body\n',
    );
  });
  testWidgets(
    'callout title/type edits preserve collapse markers and exact body',
    (tester) async {
      var source = '> [!MYSTERY]+   Old  \r\n>body\r\n';
      final key = GlobalKey<CalloutBlockState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, setState) => CalloutBlock(
                key: key,
                source: source,
                onChanged: (s) => setState(() => source = s),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      key.currentState!.selectSource(
        CalloutSourceParts(source).titleStart,
        length: 3,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Callout options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit title'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'X');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(source, '> [!MYSTERY]+   X  \r\n>body\r\n');
      await tester.tap(find.byTooltip('Change callout type'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('By the way'));
      await tester.pumpAndSettle();
      expect(source, '> [!BTW]+   X  \r\n>body\r\n');
      final before = source;
      await tester.tap(find.byTooltip('Collapse callout'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('callout-body')), findsNothing);
      expect(source, before);
      await tester.tap(find.byTooltip('Expand callout'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('callout-body')), findsOneWidget);
    },
  );
  testWidgets(
    'Read-mode folded callouts expand for document search without edits',
    (tester) async {
      const body = '> [!BTW]- Extra context\n> Hidden pearl\n';
      var changes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditor(
              noteId: 'n',
              title: 'Note',
              body: body,
              initialViewState: const {'mode': 'read'},
              onTitleChanged: (_) {},
              onBodyChanged: (_) => changes++,
              linkTargets: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hidden pearl', findRichText: true), findsNothing);
      await tester.tap(find.byTooltip('Expand callout'));
      await tester.pumpAndSettle();
      expect(find.text('Hidden pearl', findRichText: true), findsWidgets);
      await tester.tap(find.byTooltip('Collapse callout'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Find in note · Ctrl+F'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Find in this note'),
        'pearl',
      );
      await tester.pumpAndSettle();
      expect(find.text('Hidden pearl', findRichText: true), findsWidgets);
      expect(changes, 0);
    },
  );
}
