import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/block_formatting.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/block_format_dialog.dart';

void main() {
  testWidgets(
    'block style chooser remains searchable and cancellable at 200% text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? choice;
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
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  choice = await showDialog<String>(
                    context: context,
                    builder: (_) => const BlockFormatDialog(),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'missing style');
      await tester.pumpAndSettle();
      expect(find.text('No matching block styles.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(choice, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  test('block formats retain links, inline marks, checked state and CRLF', () {
    expect(
      formatNoteBlocks('- [x] **Keep** [[id|Source]] ^anchor\r\n', 'Checklist'),
      '- [x] **Keep** [[id|Source]] ^anchor\r\n',
    );
    expect(
      formatNoteBlocks('# Name ^anchor\r\n', 'Paragraph'),
      'Name ^anchor\r\n',
    );
    expect(
      formatNoteBlocks('Name ^anchor\r\n---\r\n', 'Heading 3'),
      '### Name ^anchor\r\n',
    );
    expect(
      formatNoteBlocks('First\n\nSecond\n', 'Numbered list'),
      '1. First\n\n2. Second\n',
    );
    expect(
      formatNoteBlocks('First\n\nSecond\n', 'BTW block'),
      '> [!BTW]\n> First\n>\n> Second\n',
    );
  });
  test(
    'blank blocks become usable styles and final newlines remain deliberate',
    () {
      expect(formatNoteBlocks('', 'Heading 2'), '## ');
      expect(formatNoteBlocks('\r\n', 'Checklist'), '- [ ] \r\n');
      expect(formatNoteBlocks('End', 'Quote'), '> End');
      expect(formatNoteBlocks('## End ##', 'Paragraph'), 'End');
    },
  );
  test(
    'structured/unknown blocks and nested lists refuse instead of flattening',
    () {
      for (final source in [
        '```dart\nx\n```\n',
        '| A |\n|---|\n|B|\n',
        '<!-- custom -->\n',
        '> [!MYSTERY]\n> Keep\n',
        '  - nested\n',
        '> > deep\n',
        '<!-- orbit:align=center -->\nText\n',
        '[key]: https://example.com\n',
      ]) {
        expect(
          () => formatNoteBlocks(source, 'Paragraph'),
          throwsFormatException,
          reason: source,
        );
      }
      expect(
        () => formatNoteBlocks('First\nsecond\n', 'Heading 1'),
        throwsFormatException,
      );
    },
  );
  testWidgets('block chooser converts the current block and undoes exactly', (
    tester,
  ) async {
    var body = 'A **small** idea [[Source]].\n\nKeep the rest.\n';
    final original = body;
    await tester.pumpWidget(
      MaterialApp(
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
    await tester.tap(find.byTooltip('Format block'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'BTW');
    await tester.pumpAndSettle();
    await tester.tap(find.text('BTW block'));
    await tester.pumpAndSettle();
    expect(
      body,
      '> [!BTW]\n> A **small** idea [[Source]].\n\nKeep the rest.\n',
    );
    await tester.tap(find.byTooltip('Undo · Ctrl+Z'));
    await tester.pumpAndSettle();
    expect(body, original);
  });
  testWidgets(
    'Source formatting rejects a changed source while chooser is open',
    (tester) async {
      var body = '# Before\n';
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                return NoteEditor(
                  noteId: 'n',
                  title: 'Note',
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
      await tester.tap(find.byTooltip('Format block'));
      await tester.pumpAndSettle();
      update(() => body = '# New source\n');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paragraph'));
      await tester.pumpAndSettle();
      expect(body, '# New source\n');
      expect(
        find.textContaining('The document changed. Open Format block again.'),
        findsOneWidget,
      );
    },
  );
}
