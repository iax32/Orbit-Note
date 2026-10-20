import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';

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
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  late String body;
  Finder field(String value) => find.byWidgetPredicate(
    (w) => w is TextField && w.controller?.text == value,
  );

  Future<void> open(WidgetTester tester, String source) async {
    body = source;
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => NoteEditor(
              noteId: 'test-note',
              title: 'Multi-Block Selection Test',
              body: body,
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

  Future<void> key(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool control = false,
    bool shift = false,
  }) async {
    if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'sequential Ctrl+A: first press selects block, second press selects all blocks',
    (tester) async {
      await open(
        tester,
        '# Title\n\nFirst paragraph.\n\nSecond paragraph.\n\nThird paragraph.\n\n',
      );

      final firstPara = field('First paragraph.');
      expect(firstPara, findsOneWidget);
      await tester.tap(firstPara);
      await tester.pumpAndSettle();

      // First Ctrl+A: selects text within the paragraph
      await key(tester, LogicalKeyboardKey.keyA, control: true);
      await tester.pumpAndSettle();

      final controller = tester.widget<TextField>(firstPara).controller!;
      expect(controller.selection.start, 0);
      expect(controller.selection.end, 'First paragraph.'.length);
      // Not yet multi-block selected
      expect(find.byKey(const ValueKey('selected-block-0')), findsNothing);

      // Second Ctrl+A: selects all blocks across the document
      await key(tester, LogicalKeyboardKey.keyA, control: true);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('selected-block-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('selected-block-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('selected-block-4')), findsOneWidget);
      expect(find.byKey(const ValueKey('selected-block-6')), findsOneWidget);
    },
  );

  testWidgets('Ctrl+A in empty paragraph immediately selects all blocks', (
    tester,
  ) async {
    await open(tester, '# Header\n\n\n\nBottom text.\n\n');

    final emptyPara = field('');
    expect(emptyPara, findsOneWidget);
    await tester.tap(emptyPara);
    await tester.pumpAndSettle();

    // Ctrl+A in empty paragraph selects all document blocks
    await key(tester, LogicalKeyboardKey.keyA, control: true);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('selected-block-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('selected-block-2')), findsOneWidget);
  });

  testWidgets(
    'Shift + Click selects a text range without moving the paragraph layout',
    (tester) async {
      await open(
        tester,
        '# Title\n\nBlock one.\n\nBlock two.\n\nBlock three.\n\n',
      );

      // Tap block 2 (Block one.)
      await tester.tap(field('Block one.'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('cross-selected-block-2')),
        findsNothing,
      );

      // Shift + Click on block 6 (Block three.)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(field('Block three.'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      // Content blocks 2, 4, 6 should be selected
      expect(find.byKey(const ValueKey('selected-block-0')), findsNothing);
      expect(
        find.byKey(const ValueKey('cross-selected-block-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('cross-selected-block-4')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('cross-selected-block-6')),
        findsOneWidget,
      );

      // Click without Shift clears multi-block selection
      await tester.tap(field('Block two.'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('cross-selected-block-2')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('cross-selected-block-4')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('cross-selected-block-6')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Shift + Down and Shift + Up extend and contract block selection',
    (tester) async {
      await open(
        tester,
        '# Title\n\nBlock one.\n\nBlock two.\n\nBlock three.\n\n',
      );

      final block1 = field('Block one.');
      await tester.tap(block1);
      await tester.pumpAndSettle();

      // Put caret at end of Block one
      final controller = tester.widget<TextField>(block1).controller!;
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      await tester.pumpAndSettle();

      // Shift + Down at end of block extends selection to Block two (block 4)
      await key(tester, LogicalKeyboardKey.arrowDown, shift: true);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('selected-block-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('selected-block-4')), findsOneWidget);
      expect(find.byKey(const ValueKey('selected-block-6')), findsNothing);

      // Shift + Down again extends to Block three (block 6)
      await key(tester, LogicalKeyboardKey.arrowDown, shift: true);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('selected-block-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('selected-block-4')), findsOneWidget);
      expect(find.byKey(const ValueKey('selected-block-6')), findsOneWidget);

      // Shift + Up contracts selection back
      await key(tester, LogicalKeyboardKey.arrowUp, shift: true);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('selected-block-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('selected-block-4')), findsOneWidget);
      expect(find.byKey(const ValueKey('selected-block-6')), findsNothing);
    },
  );

  testWidgets('Ctrl+C copies exact Markdown of all selected blocks', (
    tester,
  ) async {
    await open(
      tester,
      '# Title\n\nBlock one.\n\nBlock two.\n\nBlock three.\n\n',
    );

    // Tap block 2 and Shift+Click block 4
    await tester.tap(field('Block one.'));
    await tester.pumpAndSettle();
    tester
        .state<RichMarkdownEditorState>(find.byType(RichMarkdownEditor))
        .selectBlockRange(2, 4);
    await tester.pumpAndSettle();

    clipboard = '';
    await key(tester, LogicalKeyboardKey.keyC, control: true);
    await tester.pumpAndSettle();

    expect(clipboard, 'Block one.\n\nBlock two.\n\n');
  });

  testWidgets(
    'Ctrl+X cuts selected blocks and Backspace/Delete deletes them with undo/redo',
    (tester) async {
      await open(
        tester,
        '# Title\n\nBlock one.\n\nBlock two.\n\nBlock three.\n\n',
      );

      // Select Block one (block 2) and Block two (block 4)
      await tester.tap(field('Block one.'));
      await tester.pumpAndSettle();
      tester
          .state<RichMarkdownEditorState>(find.byType(RichMarkdownEditor))
          .selectBlockRange(2, 4);
      await tester.pumpAndSettle();

      // Cut (Ctrl+X)
      clipboard = '';
      await key(tester, LogicalKeyboardKey.keyX, control: true);
      await tester.pumpAndSettle();

      expect(clipboard, 'Block one.\n\nBlock two.\n\n');
      expect(body, '# Title\n\nBlock three.\n\n');

      // Undo (Ctrl+Z) restores the blocks
      await key(tester, LogicalKeyboardKey.keyZ, control: true);
      await tester.pumpAndSettle();

      expect(body, '# Title\n\nBlock one.\n\nBlock two.\n\nBlock three.\n\n');

      // Select Block two and Block three, then Backspace
      await tester.tap(field('Block two.'));
      await tester.pumpAndSettle();
      tester
          .state<RichMarkdownEditorState>(find.byType(RichMarkdownEditor))
          .selectBlockRange(4, 6);
      await tester.pumpAndSettle();

      await key(tester, LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(body, '# Title\n\nBlock one.\n\n');

      // Undo again
      await key(tester, LogicalKeyboardKey.keyZ, control: true);
      await tester.pumpAndSettle();

      expect(body, '# Title\n\nBlock one.\n\nBlock two.\n\nBlock three.\n\n');
    },
  );

  testWidgets('Escape key clears multi-block selection', (tester) async {
    await open(tester, '# Title\n\nBlock one.\n\nBlock two.\n\n');

    // Select all with Ctrl+A twice
    await tester.tap(field('Block one.'));
    await tester.pumpAndSettle();
    await key(tester, LogicalKeyboardKey.keyA, control: true);
    await key(tester, LogicalKeyboardKey.keyA, control: true);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('selected-block-0')), findsOneWidget);

    // Press Escape
    await key(tester, LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('selected-block-0')), findsNothing);
    expect(find.byKey(const ValueKey('selected-block-2')), findsNothing);
  });

  testWidgets(
    'cross-block text selection copies and deletes exact source range',
    (tester) async {
      const source = 'First **one**\n\nSecond paragraph\n\nThird paragraph';
      await open(tester, source);
      final editor = tester.state<RichMarkdownEditorState>(
        find.byType(RichMarkdownEditor),
      );
      final end = source.indexOf('Third paragraph');
      editor.selectDocumentRange(2, end);
      await tester.pumpAndSettle();
      expect(editor.hasCrossDocumentSelection, isTrue);
      expect(editor.currentDocumentSelection.baseOffset, 2);
      expect(editor.currentDocumentSelection.extentOffset, end);

      await editor.copyCrossDocumentSelection();
      expect(clipboard, 'rst **one**\n\nSecond paragraph\n\n');
      expect(editor.deleteCrossDocumentSelection(), isTrue);
      await tester.pumpAndSettle();
      expect(body, 'FiThird paragraph');
    },
  );

  testWidgets(
    'Typing a character replaces selected blocks with a new paragraph',
    (tester) async {
      await open(
        tester,
        '# Title\n\nBlock one.\n\nBlock two.\n\nBlock three.\n\n',
      );

      // Select Block one and Block two
      await tester.tap(field('Block one.'));
      await tester.pumpAndSettle();
      tester
          .state<RichMarkdownEditorState>(find.byType(RichMarkdownEditor))
          .selectBlockRange(2, 4);
      await tester.pumpAndSettle();

      // Type character 'x'
      await key(tester, LogicalKeyboardKey.keyX);
      await tester.pumpAndSettle();

      expect(body, '# Title\n\nx\n\nBlock three.\n\n');
    },
  );
}
