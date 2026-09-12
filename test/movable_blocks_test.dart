import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';

void main() {
  String clipboard = '';
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
            return null;
          }
          if (call.method == 'Clipboard.getData') return {'text': clipboard};
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('Movable blocks model and serialization logic', () {
    test('movableBlocks excludes blank spacers and pinned frontmatter', () {
      const source = '''---
title: My Doc
tags: [test]
---

First paragraph.

Second paragraph.

- Item 1
- Item 2
''';
      final doc = MarkdownDocument.parse(source);
      final nonBlank = <MarkdownBlock>[];
      for (var i = 0; i < doc.blocks.length; i++) {
        final b = doc.blocks[i];
        if (b.kind == MarkdownBlockKind.blank) continue;
        if (i == 0 &&
            b.kind == MarkdownBlockKind.raw &&
            b.source.startsWith('---')) {
          continue;
        }
        nonBlank.add(b);
      }

      expect(nonBlank.length, 4);
      expect(nonBlank[0].kind, MarkdownBlockKind.text);
      expect(nonBlank[0].content.trim(), 'First paragraph.');
      expect(nonBlank[1].kind, MarkdownBlockKind.text);
      expect(nonBlank[1].content.trim(), 'Second paragraph.');
      expect(nonBlank[2].kind, MarkdownBlockKind.list);
      expect(nonBlank[3].kind, MarkdownBlockKind.list);
    });
  });

  group('RichMarkdownEditor block handles and context actions', () {
    late String currentBody;
    String? createdTaskTitle;

    Future<void> openEditor(WidgetTester tester, String body) async {
      currentBody = body;
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, set) => RichMarkdownEditor(
                body: currentBody,
                onChanged: (next) => set(() => currentBody = next),
                onUndo: () {},
                onRedo: () {},
                linkTargets: const [],
                linkBindings: const {},
                onOpenLink: (_) {},
                onCreateTask: (title) async => createdTaskTitle = title,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'renders Notion-style [ + ] and [ ⋮⋮ ] handles on content blocks',
      (tester) async {
        const doc = 'First paragraph.\n\nSecond paragraph.\n';
        await openEditor(tester, doc);

        // Verify drag handles and add buttons exist
        expect(find.byIcon(Icons.drag_indicator), findsNWidgets(2));
        expect(find.byTooltip('Add block below'), findsNWidgets(2));
      },
    );

    testWidgets(
      'tapping drag handle opens context menu with move/duplicate/copy/delete options',
      (tester) async {
        const doc = 'First paragraph.\n\nSecond paragraph.\n';
        await openEditor(tester, doc);

        // Tap drag handle on the first block
        await tester.tap(find.byIcon(Icons.drag_indicator).first);
        await tester.pumpAndSettle();

        expect(find.text('Move up'), findsOneWidget);
        expect(find.text('Move down'), findsOneWidget);
        expect(find.text('Duplicate'), findsOneWidget);
        expect(find.text('Copy Markdown'), findsOneWidget);
        expect(find.text('Turn into...'), findsOneWidget);
        expect(find.text('Create Task from block'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);
      },
    );

    testWidgets(
      'Move down reorders paragraphs safely and preserves markdown spacing',
      (tester) async {
        const doc = 'First paragraph.\n\nSecond paragraph.\n';
        await openEditor(tester, doc);

        // Tap drag handle on first paragraph and choose 'Move down'
        await tester.tap(find.byIcon(Icons.drag_indicator).first);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Move down'));
        await tester.pumpAndSettle();

        // First paragraph moved after second paragraph!
        expect(
          currentBody.indexOf('Second paragraph.'),
          lessThan(currentBody.indexOf('First paragraph.')),
        );
        expect(currentBody, contains('\n\n'));
      },
    );

    testWidgets('Duplicate block duplicates content with proper separation', (
      tester,
    ) async {
      const doc = 'Unique block content\n';
      await openEditor(tester, doc);

      await tester.tap(find.byIcon(Icons.drag_indicator).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();

      expect('Unique block content'.allMatches(currentBody).length, 2);
    });

    testWidgets('Create Task from block triggers task creation callback', (
      tester,
    ) async {
      const doc = 'Implement OAuth authentication\n';
      await openEditor(tester, doc);

      await tester.tap(find.byIcon(Icons.drag_indicator).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Task from block'));
      await tester.pumpAndSettle();

      expect(createdTaskTitle, 'Implement OAuth authentication');
    });
  });

  group('NoteEditor integration with undo/redo for block moves', () {
    testWidgets('undo restores original block order after move', (
      tester,
    ) async {
      String editorBody = 'Alpha\n\nBeta\n';

      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, set) => NoteEditor(
                noteId: 'test-note',
                title: 'Test',
                body: editorBody,
                onTitleChanged: (_) {},
                onBodyChanged: (v) => set(() => editorBody = v),
                linkTargets: const [],
                onOpenObject: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open context menu on first block and move down
      await tester.tap(find.byIcon(Icons.drag_indicator).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Move down'));
      await tester.pumpAndSettle();

      // Now Beta is before Alpha
      expect(editorBody.indexOf('Beta'), lessThan(editorBody.indexOf('Alpha')));

      // Press Ctrl+Z to undo
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      // Alpha is restored before Beta!
      expect(editorBody.indexOf('Alpha'), lessThan(editorBody.indexOf('Beta')));
    });
  });
}
