import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';

void main() {
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
              title: 'Multi-Block Reorder Test',
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
    bool alt = false,
  }) async {
    if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    if (alt) await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(key);
    if (alt) await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  testWidgets('Alt+Up and Alt+Down moves active paragraph up and down', (
    tester,
  ) async {
    await open(
      tester,
      'First paragraph.\n\nSecond paragraph.\n\nThird paragraph.\n\n',
    );

    final secondPara = field('Second paragraph.');
    expect(secondPara, findsOneWidget);
    await tester.tap(secondPara);
    await tester.pumpAndSettle();

    // Alt+Up: moves "Second paragraph." above "First paragraph."
    await key(tester, LogicalKeyboardKey.arrowUp, alt: true);
    await tester.pumpAndSettle();

    expect(
      body,
      'Second paragraph.\n\nFirst paragraph.\n\nThird paragraph.\n\n',
    );

    // Alt+Down: moves "Second paragraph." back down
    await key(tester, LogicalKeyboardKey.arrowDown, alt: true);
    await tester.pumpAndSettle();

    expect(
      body,
      'First paragraph.\n\nSecond paragraph.\n\nThird paragraph.\n\n',
    );
  });

  testWidgets('Alt+Up and Alt+Down moves multi-block selection up and down', (
    tester,
  ) async {
    await open(tester, 'Alpha\n\nBeta\n\nGamma\n\nDelta\n\n');

    final editor = tester.state<RichMarkdownEditorState>(
      find.byType(RichMarkdownEditor),
    );

    // Select Beta (block 2) and Gamma (block 4)
    editor.selectBlockRange(2, 4);
    await tester.pumpAndSettle();
    expect(editor.hasMultiBlockSelection, isTrue);

    // Alt+Up: moves Beta and Gamma above Alpha
    await key(tester, LogicalKeyboardKey.arrowUp, alt: true);
    await tester.pumpAndSettle();

    expect(body, 'Beta\n\nGamma\n\nAlpha\n\nDelta\n\n');
    // Selection is preserved at the new location
    expect(editor.hasMultiBlockSelection, isTrue);

    // Alt+Down: moves Beta and Gamma back after Alpha
    await key(tester, LogicalKeyboardKey.arrowDown, alt: true);
    await tester.pumpAndSettle();

    expect(body, 'Alpha\n\nBeta\n\nGamma\n\nDelta\n\n');
  });

  testWidgets('Duplicate selected blocks clones entire selection below', (
    tester,
  ) async {
    await open(tester, 'First block.\n\nSecond block.\n\nThird block.\n\n');

    final editor = tester.state<RichMarkdownEditorState>(
      find.byType(RichMarkdownEditor),
    );

    // Select first and second blocks
    editor.selectBlockRange(0, 2);
    await tester.pumpAndSettle();

    editor.duplicateSelectedBlocks();
    await tester.pumpAndSettle();

    expect(
      body,
      'First block.\n\nSecond block.\n\nFirst block.\n\nSecond block.\n\nThird block.\n\n',
    );
  });

  testWidgets('Undo restores original block order after movement', (
    tester,
  ) async {
    await open(tester, 'Line A\n\nLine B\n\nLine C\n\n');

    final lineB = field('Line B');
    await tester.tap(lineB);
    await tester.pumpAndSettle();

    // Move Line B up
    await key(tester, LogicalKeyboardKey.arrowUp, alt: true);
    await tester.pumpAndSettle();

    expect(body, 'Line B\n\nLine A\n\nLine C\n\n');

    // Undo with Ctrl+Z
    await key(tester, LogicalKeyboardKey.keyZ, control: true);
    await tester.pumpAndSettle();

    expect(body, 'Line A\n\nLine B\n\nLine C\n\n');
  });

  testWidgets(
    'Draggable and DragTarget accept multi-block payload without error',
    (tester) async {
      await open(tester, 'Source block\n\nTarget block\n\nEnd block\n\n');

      final editor = tester.state<RichMarkdownEditorState>(
        find.byType(RichMarkdownEditor),
      );

      // Select Source block
      editor.selectBlockRange(0, 0);
      await tester.pumpAndSettle();

      // Verify Draggable with block-drag-0 key exists and targets block-drop
      expect(find.byKey(const ValueKey('block-drag-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('block-drop-2')), findsOneWidget);

      // Drag block 0 onto block 2
      await tester.drag(
        find.byKey(const ValueKey('block-drag-0')),
        const Offset(0, 100),
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Ctrl+D duplicates active block when focused in paragraph', (
    tester,
  ) async {
    await open(tester, 'First block\n\nSecond block\n\n');

    final first = field('First block');
    await tester.tap(first);
    await tester.pumpAndSettle();

    await key(tester, LogicalKeyboardKey.keyD, control: true);
    await tester.pumpAndSettle();

    expect(body, 'First block\n\nFirst block\n\nSecond block\n\n');
  });

  testWidgets('Ctrl+D duplicates multi-block selection', (tester) async {
    await open(tester, 'First block\n\nSecond block\n\nThird block\n\n');

    final editor = tester.state<RichMarkdownEditorState>(
      find.byType(RichMarkdownEditor),
    );

    editor.selectBlockRange(0, 2);
    await tester.pumpAndSettle();

    await key(tester, LogicalKeyboardKey.keyD, control: true);
    await tester.pumpAndSettle();

    expect(
      body,
      'First block\n\nSecond block\n\nFirst block\n\nSecond block\n\nThird block\n\n',
    );
  });
}
