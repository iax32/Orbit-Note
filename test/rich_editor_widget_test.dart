import 'dart:async';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';
import 'package:orbit_note/features/notes/rich/note_math.dart';
import 'package:orbit_note/features/notes/rich/code_block.dart';
import 'package:orbit_note/features/notes/rich/rich_math_block.dart';

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
  Future<void> open(
    WidgetTester tester,
    String source, {
    Map<String, dynamic> state = const {},
    ValueChanged<Map<String, dynamic>>? onState,
    Future<String?> Function()? onInsertAttachment,
  }) async {
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
              noteId: 'lecture',
              title: 'Lecture',
              body: body,
              onTitleChanged: (_) {},
              onBodyChanged: (v) => update(() => body = v),
              linkTargets: const [],
              onOpenObject: (_) {},
              initialViewState: state,
              onViewStateChanged: onState,
              onInsertAttachment: onInsertAttachment,
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
    'editing a multiline definition refreshes retained shortcut fields',
    (tester) async {
      const definition = '[guide]:\r\n/docs\r\n"Manual"';
      await open(tester, '[Guide]\r\n\r\n$definition');
      expect(field('Guide'), findsOneWidget);
      expect(field(definition), findsOneWidget);
      const invalid = '[guide]:\r\n/docs "Manual" garbage';
      await tester.enterText(field(definition), invalid);
      await tester.pumpAndSettle();
      expect(body, '[Guide]\r\n\r\n$invalid');
      expect(field('[Guide]'), findsOneWidget);
      expect(field('Guide'), findsNothing);
      await key(tester, LogicalKeyboardKey.keyZ, control: true);
      expect(body, '[Guide]\r\n\r\n$definition');
      expect(field('Guide'), findsOneWidget);
      expect(field(definition), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'invalid next-line title returns to prose without changing the link target',
    (tester) async {
      const definition = '[guide]: /docs\n"Manual"';
      await open(tester, '[Guide]\n\n$definition');
      await tester.enterText(field(definition), '$definition garbage');
      await tester.pumpAndSettle();
      expect(body, '[Guide]\n\n$definition garbage');
      expect(field('Guide'), findsOneWidget);
      expect(field('[guide]: /docs\n'), findsOneWidget);
      expect(field('"Manual" garbage'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'moving repeated paragraphs retains the complete selected range',
    (tester) async {
      await open(tester, 'Same\n\nMiddle\n\nSame\n\nDestination');
      final rich = tester.state<RichMarkdownEditorState>(
        find.byType(RichMarkdownEditor),
      );
      rich.selectBlockRange(0, 4);
      await tester.pumpAndSettle();
      rich.moveSelectedBlocksDown();
      await tester.pumpAndSettle();
      rich.deleteSelectedBlocks();
      await tester.pumpAndSettle();
      expect(body.contains('Destination'), true);
      expect(body.contains('Same'), false);
      expect(body.contains('Middle'), false);
    },
  );

  testWidgets('a block menu cannot operate on a changed selected range', (
    tester,
  ) async {
    const original = 'First\n\nSecond\n\nThird';
    await open(tester, original);
    final rich = tester.state<RichMarkdownEditorState>(
      find.byType(RichMarkdownEditor),
    );
    rich.selectBlockRange(0, 2);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Drag 3 blocks · Click for options').first);
    await tester.pumpAndSettle();
    expect(find.text('Duplicate selected blocks'), findsOneWidget);
    expect(rich.hasMultiBlockSelection, isTrue);
    rich.selectBlockRange(2, 4);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate selected blocks'));
    await tester.pumpAndSettle();
    expect(body, original);
  });

  testWidgets(
    'desktop selected handle duplicates the range and prose exits selection',
    (tester) async {
      const original = 'First\n\nSecond\n\nThird';
      await open(tester, original);
      final rich = tester.state<RichMarkdownEditorState>(
        find.byType(RichMarkdownEditor),
      );
      rich.selectBlockRange(0, 2);
      await tester.pumpAndSettle();
      final handle = find.byTooltip('Drag 3 blocks · Click for options').first;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(handle));
      await tester.pumpAndSettle();
      await tester.tap(handle);
      await tester.pumpAndSettle();
      expect(rich.hasMultiBlockSelection, isTrue);
      await tester.tap(find.text('Duplicate selected blocks'));
      await tester.pumpAndSettle();
      expect(body, 'First\n\nSecond\n\nFirst\n\nSecond\n\nThird');
      await key(tester, LogicalKeyboardKey.keyZ, control: true);
      expect(body, original);
      rich.selectBlockRange(0, 2);
      await tester.pumpAndSettle();
      await tester.tap(field('Third'));
      await tester.pumpAndSettle();
      expect(rich.hasMultiBlockSelection, isFalse);
      expect(
        tester.widget<TextField>(field('Third')).focusNode!.hasFocus,
        isTrue,
      );
      expect(body, original);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('block reference menu delegates the exact block offset', (
    tester,
  ) async {
    int? copiedAt;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RichMarkdownEditor(
            body: 'First\n\nSecond',
            noteId: 'note-id',
            onChanged: (_) {},
            onUndo: () {},
            onRedo: () {},
            linkTargets: const [],
            linkBindings: const {},
            onOpenLink: (_) {},
            onCopyBlockReference: (offset) async {
              copiedAt = offset;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Drag to move · Click for options').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy link to block'));
    await tester.pumpAndSettle();
    expect(copiedAt, 7);
  });

  testWidgets('a stale block menu cannot duplicate a replacement paragraph', (
    tester,
  ) async {
    await open(tester, 'First\n\nSecond');
    final rich = tester.state<RichMarkdownEditorState>(
      find.byType(RichMarkdownEditor),
    );
    await tester.tap(find.byTooltip('Drag to move · Click for options').first);
    await tester.pumpAndSettle();
    rich.widget.onChanged('Replacement');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();
    expect(body, 'Replacement');
    expect(tester.takeException(), null);
  });

  testWidgets('Source alignment preserves the selected text offsets', (
    tester,
  ) async {
    await open(tester, 'First paragraph');
    await tester.tap(find.text('Source'));
    await tester.pumpAndSettle();
    final editor = tester.widget<TextField>(field('First paragraph'));
    editor.focusNode!.requestFocus();
    editor.controller!.selection = const TextSelection(
      baseOffset: 8,
      extentOffset: 2,
    );
    await tester.tap(find.byTooltip('Align right'));
    await tester.pumpAndSettle();
    const marker = '<!-- orbit:align=right -->\n';
    expect(body, '${marker}First paragraph');
    expect(
      tester.widget<TextField>(field(body)).controller!.selection,
      TextSelection(
        baseOffset: marker.length + 8,
        extentOffset: marker.length + 2,
      ),
    );
  });

  testWidgets('alignment retains a reversed text selection', (tester) async {
    await open(tester, '**First** paragraph');
    final editor = tester.widget<TextField>(field('First paragraph'));
    editor.focusNode!.requestFocus();
    editor.controller!.selection = const TextSelection(
      baseOffset: 8,
      extentOffset: 2,
    );
    await tester.tap(find.byTooltip('Align center'));
    await tester.pumpAndSettle();
    expect(body, '<!-- orbit:align=center -->\n**First** paragraph');
    expect(
      tester.widget<TextField>(field('First paragraph')).controller!.selection,
      const TextSelection(baseOffset: 8, extentOffset: 2),
    );
  });

  testWidgets('delayed rich attachment waits for an explicit new position', (
    tester,
  ) async {
    await open(tester, 'First');
    final pending = Completer<String?>();
    final rich = tester.state<RichMarkdownEditorState>(
      find.byType(RichMarkdownEditor),
    );
    final insertion = rich.insertFrom(() => pending.future);
    await tester.enterText(field('First'), 'Changed');
    pending.complete('[File](files/example.pdf)');
    await insertion;
    await tester.pumpAndSettle();
    expect(body, 'Changed');
    await tester.tap(find.text('Insert here'));
    await tester.pumpAndSettle();
    expect(body, 'Changed[File](files/example.pdf)');
  });

  testWidgets('rich attachment errors preserve text and permit retry', (
    tester,
  ) async {
    await open(tester, 'First');
    final rich = tester.state<RichMarkdownEditorState>(
      find.byType(RichMarkdownEditor),
    );
    await rich.insertFrom(
      () => Future<String?>.error(StateError('unreadable')),
    );
    await tester.pumpAndSettle();
    expect(body, 'First');
    expect(find.textContaining('Could not insert attachment:'), findsOneWidget);
    final pending = Completer<String?>();
    var calls = 0;
    final insertion = rich.insertFrom(() {
      calls++;
      return pending.future;
    });
    await rich.insertFrom(() async {
      calls++;
      return 'wrong';
    });
    expect(calls, 1);
    pending.complete(null);
    await insertion;
    expect(body, 'First');
  });

  testWidgets('Source attachment does not replace an intervening edit', (
    tester,
  ) async {
    final pending = Completer<String?>();
    await open(tester, 'First', onInsertAttachment: () => pending.future);
    await tester.tap(find.text('Source'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Insert attachment'));
    await tester.pump();
    await tester.enterText(field('First'), 'Changed');
    pending.complete('[File](files/example.pdf)');
    await tester.pumpAndSettle();
    expect(body, 'Changed');
    expect(find.text('Insert here'), findsOneWidget);
  });

  testWidgets('formatting selected text toggles and retains selection', (
    tester,
  ) async {
    await open(tester, '**bold**');
    final editor = tester.widget<TextField>(field('bold'));
    editor.focusNode!.requestFocus();
    editor.controller!.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 2,
    );
    await key(tester, LogicalKeyboardKey.keyB, control: true);
    expect(body, 'bo**ld**');
    expect(
      tester.widget<TextField>(field('bold')).controller!.selection,
      const TextSelection(baseOffset: 0, extentOffset: 2),
    );
    await key(tester, LogicalKeyboardKey.keyZ, control: true);
    expect(body, '**bold**');
  });

  testWidgets('collapsed bold waits for typing without empty markers', (
    tester,
  ) async {
    await open(tester, 'First');
    final editor = tester.widget<TextField>(field('First'));
    editor.focusNode!.requestFocus();
    editor.controller!.selection = const TextSelection.collapsed(offset: 5);
    await key(tester, LogicalKeyboardKey.keyB, control: true);
    expect(body, 'First');
    await tester.enterText(field('First'), 'FirstX');
    await tester.pumpAndSettle();
    expect(body, 'First**X**');
  });

  testWidgets('Delete at paragraph end joins the next paragraph', (
    tester,
  ) async {
    await open(tester, 'First\n\nSecond\n');
    final editor = tester.widget<TextField>(field('First'));
    editor.focusNode!.requestFocus();
    editor.controller!.selection = const TextSelection.collapsed(offset: 5);
    await tester.pump();
    await key(tester, LogicalKeyboardKey.delete);
    expect(body, 'FirstSecond\n');
    await key(tester, LogicalKeyboardKey.keyZ, control: true);
    expect(body, 'First\n\nSecond\n');
  });

  testWidgets(
    'inline fraction values edit directly without the equation studio',
    (tester) async {
      await open(tester, r'Value $\frac{1}{2}$ stays here.');
      await tester.enterText(find.byKey(const ValueKey('frac-den-0')), '25');
      await tester.pumpAndSettle();
      expect(body, r'Value $\frac{1}{25}$ stays here.');
      expect(find.text('Inline Equation Studio'), findsNothing);
      await key(tester, LogicalKeyboardKey.keyZ, control: true);
      await tester.pumpAndSettle();
      expect(body, r'Value $\frac{1}{2}$ stays here.');
    },
  );

  testWidgets('Right arrow exits hidden formatting without adding a space', (
    tester,
  ) async {
    for (final marker in ['**', '*', '~~', '`']) {
      await open(tester, '${marker}word$marker');
      final finder = field('word');
      await tester.tap(finder);
      tester.widget<TextField>(finder).controller!.selection =
          const TextSelection.collapsed(offset: 4);
      await key(tester, LogicalKeyboardKey.arrowRight);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'wordX',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      await tester.pumpAndSettle();
      expect(body, '${marker}word${marker}X');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('block duplication and deletion participate in document undo', (
    tester,
  ) async {
    await open(tester, 'First\n\nSecond');
    await tester.tap(find.byTooltip('Drag to move · Click for options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();
    expect(body.split('First'), hasLength(3));
    expect(body.endsWith('Second'), isTrue);
    await key(tester, LogicalKeyboardKey.keyZ, control: true);
    expect(body, 'First\n\nSecond');
  });

  testWidgets(
    'insert between paragraphs focuses a separate durable paragraph',
    (tester) async {
      await open(tester, 'First\n\nSecond');
      await tester.tap(find.byTooltip('Insert paragraph here').first);
      await tester.pumpAndSettle();
      final focused = find.byWidgetPredicate(
        (w) => w is TextField && w.focusNode?.hasFocus == true,
      );
      expect(focused, findsOneWidget);
      await tester.enterText(focused, 'Middle');
      await tester.pumpAndSettle();
      expect(body, 'First\n\nMiddle\n\nSecond');
    },
  );

  testWidgets(
    'Rich is real editable formatted text and mode switches preserve exact source/undo',
    (tester) async {
      const initial =
          '# Algorithms\n\nAn **important** concept.\n\n{{orbit:unknown}}\n';
      await open(tester, initial);
      expect(find.byKey(const ValueKey('note-body')), findsNothing);
      expect(field('Algorithms'), findsOneWidget);
      expect(field('An important concept.'), findsOneWidget);
      await tester.enterText(field('Algorithms'), 'Algorithms and graphs');
      await tester.pumpAndSettle();
      expect(body, initial.replaceFirst('Algorithms', 'Algorithms and graphs'));
      await tester.tap(find.text('Source'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('note-body')))
            .controller!
            .text,
        body,
      );
      await tester.tap(find.byKey(const ValueKey('note-body')));
      await key(tester, LogicalKeyboardKey.keyZ, control: true);
      expect(body, initial);
      await tester.tap(find.text('Rich'));
      await tester.pumpAndSettle();
      await tester.tap(field('Algorithms'));
      await key(tester, LogicalKeyboardKey.keyY, control: true);
      expect(body, initial.replaceFirst('Algorithms', 'Algorithms and graphs'));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'long-note edit and navigation retain unaffected rich block controllers',
    (tester) async {
      final initial =
          '---\nunknown: retained\n---\n\n# Start\n\n'
          '${List.generate(120, (i) => 'Paragraph $i stays editable.\n\n').join()}'
          '| A | B |\n| --- | --- |\n| 1 | 2 |\n\n'
          '\$\$\nx^2\n\$\$\n\n```text\nkeep code\n```\n';
      await open(tester, initial);
      final rich = tester.state<RichMarkdownEditorState>(
        find.byType(RichMarkdownEditor),
      );
      final untouched = tester
          .widget<TextField>(field('Paragraph 90 stays editable.'))
          .controller;
      final tableCell = tester
          .widget<TextField>(find.byKey(const ValueKey('rich-cell-1-0')))
          .controller;
      final code = tester
          .widget<TextField>(find.byKey(const ValueKey('rich-code')))
          .controller;
      final math = tester.widget<RichMathBlock>(find.byType(RichMathBlock));
      rich.jumpTo(body.indexOf('Paragraph 60'));
      await tester.pumpAndSettle();
      await tester.enterText(
        field('Paragraph 60 stays editable.'),
        'Paragraph 60 now has a longer sentence.',
      );
      await tester.pumpAndSettle();
      expect(
        body,
        initial.replaceFirst(
          'Paragraph 60 stays editable.',
          'Paragraph 60 now has a longer sentence.',
        ),
      );
      rich.jumpTo(body.indexOf('Paragraph 90'));
      await tester.pumpAndSettle();
      expect(
        rich.currentDocumentSelection.extentOffset,
        body.indexOf('Paragraph 90'),
      );
      expect(
        tester
            .widget<TextField>(field('Paragraph 90 stays editable.'))
            .controller,
        same(untouched),
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('rich-cell-1-0')))
            .controller,
        same(tableCell),
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('rich-code')))
            .controller,
        same(code),
      );
      expect(
        tester.widget<RichMathBlock>(find.byType(RichMathBlock)),
        same(math),
      );
      await key(tester, LogicalKeyboardKey.keyZ, control: true);
      expect(body, initial);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'footer caches refresh for Unicode edits and changed source selection',
    (tester) async {
      await open(tester, 'First\n\nSecond');
      expect(find.textContaining('13 characters'), findsOneWidget);
      await tester.enterText(field('Second'), 'Second🙂');
      await tester.pumpAndSettle();
      expect(find.textContaining('14 characters'), findsOneWidget);
      await tester.tap(find.text('Source'));
      await tester.pumpAndSettle();
      final source = find.byKey(const ValueKey('note-body'));
      await tester.tap(source);
      final controller = tester.widget<TextField>(source).controller!;
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Selection: 1 of 2 words (5 chars'),
        findsOneWidget,
      );
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: body.length,
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Selection: 2 of 2 words (14 chars'),
        findsOneWidget,
      );
      expect(body, 'First\n\nSecond🙂');
    },
  );
  testWidgets(
    'composition commit is one shared history entry and cancellation adds none',
    (tester) async {
      for (final sourceMode in [false, true]) {
        await open(tester, '**Alpha**\n\nSecond');
        if (sourceMode) {
          await tester.tap(find.text('Source'));
          await tester.pumpAndSettle();
        }
        final target = sourceMode
            ? find.byKey(const ValueKey('note-body'))
            : field('Alpha');
        await tester.tap(target);
        final controller = tester.widget<TextField>(target).controller!;
        final original = controller.text;
        for (final suffix in ['か', 'かな']) {
          tester.testTextInput.updateEditingValue(
            TextEditingValue(
              text: '$original$suffix',
              selection: TextSelection.collapsed(
                offset: original.length + suffix.length,
              ),
              composing: TextRange(
                start: original.length,
                end: original.length + suffix.length,
              ),
            ),
          );
          await tester.pump();
        }
        final composingBody = body;
        await key(tester, LogicalKeyboardKey.keyZ, control: true);
        expect(body, composingBody);
        tester.testTextInput.updateEditingValue(
          controller.value.copyWith(composing: TextRange.empty),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Undo · Ctrl+Z'));
        await tester.pumpAndSettle();
        expect(body, '**Alpha**\n\nSecond');
        await tester.tap(find.byTooltip('Redo · Ctrl+Shift+Z'));
        await tester.pumpAndSettle();
        expect(body, composingBody);

        // A canceled composition must not erase the existing undo/redo entry.
        final next = sourceMode
            ? find.byKey(const ValueKey('note-body'))
            : field('Alphaかな');
        await tester.tap(next);
        final beforeCancel = tester.widget<TextField>(next).controller!.value;
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: '${beforeCancel.text}文',
            selection: TextSelection.collapsed(
              offset: beforeCancel.text.length + 1,
            ),
            composing: TextRange(
              start: beforeCancel.text.length,
              end: beforeCancel.text.length + 1,
            ),
          ),
        );
        await tester.pump();
        tester.testTextInput.updateEditingValue(
          beforeCancel.copyWith(composing: TextRange.empty),
        );
        await tester.pumpAndSettle();
        expect(body, composingBody);
        await tester.tap(find.byTooltip('Undo · Ctrl+Z'));
        await tester.pumpAndSettle();
        expect(body, '**Alpha**\n\nSecond');
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'bold content edits directly and IME composing range survives save acknowledgement',
    (tester) async {
      await open(tester, '**important**');
      final editor = field('important');
      await tester.tap(editor);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'important文',
          selection: TextSelection.collapsed(offset: 10),
          composing: TextRange(start: 9, end: 10),
        ),
      );
      await tester.pump();
      final controller = tester
          .widget<TextField>(field('important文'))
          .controller!;
      expect(controller.value.composing, const TextRange(start: 9, end: 10));
      expect(body, '**important文**');
      tester.testTextInput.updateEditingValue(
        controller.value.copyWith(composing: TextRange.empty),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Rich list Enter continues unchecked items and empty Enter exits to editable paragraph',
    (tester) async {
      await open(tester, '- [x] Read chapter');
      await tester.tap(field('Read chapter'));
      final controller = tester
          .widget<TextField>(field('Read chapter'))
          .controller!;
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      await key(tester, LogicalKeyboardKey.enter);
      expect(body, '- [x] Read chapter\n- [ ] ');
      await key(tester, LogicalKeyboardKey.enter);
      expect(body, '- [x] Read chapter\n\n');
      final empty = field('');
      expect(empty, findsOneWidget);
      await tester.enterText(empty, 'Next paragraph');
      await tester.pumpAndSettle();
      expect(body, contains('Next paragraph'));
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(body, startsWith('- [ ]'));
      await tester.tap(find.byTooltip('Undo · Ctrl+Z'));
      await tester.pumpAndSettle();
      expect(body, startsWith('- [x]'));
    },
  );
  testWidgets(
    'visual tables edit cells, add row with Tab, paste TSV and undo',
    (tester) async {
      await open(
        tester,
        '| Name | Status |\n| --- | --- |\n| Alice | Ready |\n',
      );
      await tester.enterText(
        find.byKey(const ValueKey('rich-cell-1-0')),
        'Bob',
      );
      await tester.pumpAndSettle();
      expect(body, contains('| Bob | Ready |'));
      await tester.tap(find.byKey(const ValueKey('rich-cell-1-1')));
      await key(tester, LogicalKeyboardKey.tab);
      expect(find.byKey(const ValueKey('rich-cell-2-0')), findsOneWidget);
      await Clipboard.setData(const ClipboardData(text: 'X\tY\nZ\tW'));
      await key(tester, LogicalKeyboardKey.keyV, control: true);
      expect(body, contains('| X | Y |\n| Z | W |'));
      await key(tester, LogicalKeyboardKey.keyZ, control: true);
      expect(body, contains('| Bob | Ready |'));
      expect(body, isNot(contains('| X | Y |')));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('code editing highlights and Copy code copies only contents', (
    tester,
  ) async {
    await open(tester, '```cpp\nint main() {\n  return 0;\n}\n```\n');
    expect(find.byType(NoteCodeBlock), findsOneWidget);
    await tester.tap(find.text('Copy code'));
    await tester.pump();
    expect(
      (await Clipboard.getData(Clipboard.kTextPlain))!.text,
      'int main() {\n  return 0;\n}',
    );
    expect(find.text('Copied ✓'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('rich-code')),
      'int answer = 42;',
    );
    await tester.pumpAndSettle();
    expect(body, '```cpp\nint answer = 42;\n```\n');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'inline/block equations render and edit locally; malformed math remains visible',
    (tester) async {
      await open(
        tester,
        'Complexity: \$O(n \\log n)\$.\n\n\$\$\n\\frac{a}{b}\n\$\$\n\n\$\$\n\\badcommand{x}\n\$\$\n',
      );
      expect(find.byType(EditableMathExpression), findsNWidgets(3));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Advanced equation editor').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('equation-source')),
        r'\sqrt{x}',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(body, contains(r'\sqrt{x}'));
      expect(body, contains(r'\badcommand{x}'));
    },
  );
  testWidgets(
    'slash commands create a heading without retaining slash syntax',
    (tester) async {
      await open(tester, '');
      await tester.enterText(field(''), '/');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Heading 1'));
      await tester.pumpAndSettle();
      await tester.enterText(field(''), 'Lecture one');
      await tester.pumpAndSettle();
      expect(body, '# Lecture one');
    },
  );
  testWidgets('Split divider persists and outline keeps Split mode', (
    tester,
  ) async {
    Map<String, dynamic>? state;
    await open(
      tester,
      '# First\n\nText\n\n## Second\n\nMore text',
      state: const {'mode': 'split'},
      onState: (v) => state = v,
    );
    await tester.drag(
      find.byKey(const ValueKey('note-split-divider')),
      const Offset(100, 0),
    );
    await tester.pumpAndSettle();
    expect(state!['splitRatio'], greaterThan(.5));
    await tester.tap(find.byTooltip('Note outline'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note-split-divider')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Enter splits bold safely and Backspace rejoins editable paragraphs',
    (tester) async {
      const original = '**bold**\n\n{{untouched}}\n';
      await open(tester, original);
      await tester.tap(field('bold'));
      tester.widget<TextField>(field('bold')).controller!.selection =
          const TextSelection.collapsed(offset: 2);
      await key(tester, LogicalKeyboardKey.enter);
      expect(body, '**bo**\n\n**ld**\n\n{{untouched}}\n');
      expect(tester.widget<TextField>(field('ld')).focusNode!.hasFocus, isTrue);
      await key(tester, LogicalKeyboardKey.backspace);
      expect(body, original);
      expect(field('bold'), findsOneWidget);
      await key(tester, LogicalKeyboardKey.keyZ, control: true);
      expect(body, '**bo**\n\n**ld**\n\n{{untouched}}\n');
      await key(tester, LogicalKeyboardKey.keyZ, control: true);
      expect(body, original);
    },
  );

  testWidgets(
    'Enter in the middle of a note leaves an immediately editable empty paragraph',
    (tester) async {
      await open(tester, '# Heading ##\n\nExisting paragraph\n');
      await tester.tap(field('Heading'));
      tester.widget<TextField>(field('Heading')).controller!.selection =
          const TextSelection.collapsed(offset: 7);
      await key(tester, LogicalKeyboardKey.enter);
      expect(field(''), findsOneWidget);
      expect(tester.widget<TextField>(field('')).focusNode!.hasFocus, isTrue);
      await tester.enterText(field(''), 'New paragraph');
      await tester.pumpAndSettle();
      expect(body, '# Heading ##\n\nNew paragraph\n\nExisting paragraph\n');
    },
  );

  for (final (source, next) in [
    ('- bullet', '- bullet\n- '),
    ('9. item', '9. item\n10. '),
  ]) {
    testWidgets('Rich continuation and nesting for $source', (tester) async {
      await open(tester, source);
      final input = field(source.substring(source.indexOf(' ') + 1));
      await tester.tap(input);
      final controller = tester.widget<TextField>(input).controller!;
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      await key(tester, LogicalKeyboardKey.enter);
      expect(body, next);
      await key(tester, LogicalKeyboardKey.tab);
      expect(body, next.replaceFirst('\n', '\n  '));
      await key(tester, LogicalKeyboardKey.tab, shift: true);
      expect(body, next);
      await key(tester, LogicalKeyboardKey.enter);
      expect(tester.widget<TextField>(field('')).focusNode!.hasFocus, isTrue);
      await tester.enterText(field(''), 'Done');
      await tester.pumpAndSettle();
      expect(body, '$source\n\nDone');
      await tester.tap(find.text('Source'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rich'));
      await tester.pumpAndSettle();
      expect(field('Done'), findsOneWidget);
      expect(body, '$source\n\nDone');
    });
  }

  testWidgets(
    'table row/column commands, backward navigation and plain paste preserve surrounding Markdown',
    (tester) async {
      const table = '| A | B |\n| --- | --- |\n| One | Two |\n';
      const original = 'Before **kept**\n\n$table\n{{after}}\n';
      await open(tester, original);
      Future<void> operation(String name) async {
        await tester.tap(find.byTooltip('Table operations'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
      }

      await tester.tap(field('Two'));
      await key(tester, LogicalKeyboardKey.tab, shift: true);
      final one = tester.widget<TextField>(field('One'));
      expect(one.focusNode!.hasFocus, isTrue);
      one.controller!.selection = const TextSelection.collapsed(offset: 1);
      await Clipboard.setData(const ClipboardData(text: 'X'));
      await key(tester, LogicalKeyboardKey.keyV, control: true);
      expect(body, contains('| OXne | Two |'));
      await operation('Add column right');
      expect(body, contains('| OXne |  | Two |'));
      await operation('Delete column');
      expect(body, contains('|  | Two |'));
      await operation('Add row above');
      expect(find.byKey(const ValueKey('rich-cell-2-0')), findsOneWidget);
      await operation('Delete row');
      expect(find.byKey(const ValueKey('rich-cell-2-0')), findsNothing);
      expect(body, startsWith('Before **kept**\n\n'));
      expect(body, endsWith('\n{{after}}\n'));
      await tester.tap(find.text('Source'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rich'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Read equations and Copy code preserve source and ignore math inside code',
    (tester) async {
      const original =
          r'Escaped \$x\$ and `$y$`, but $\alpha_i^2$ renders.'
          '\n\n\$\$\\frac{a}{b}\$\$\n\n~~~python\nprint(42)\n~~~\n';
      await open(tester, original);
      expect(find.byType(EditableMathExpression), findsNWidgets(2));
      await tester.tap(find.text('Read'));
      await tester.pumpAndSettle();
      expect(find.byType(NoteMath), findsNWidgets(2));
      await tester.tap(find.text('Copy code'));
      await tester.pump();
      expect(clipboard, 'print(42)');
      expect(body, original);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('university equations render without an error fallback', (
    tester,
  ) async {
    const formulas = [
      r'\frac{a}{b}+\sqrt{x}',
      r'\sum_{i=1}^{n} i^2',
      r'\int_0^\infty e^{-x}\,dx',
      r'\begin{pmatrix}a&b\\c&d\end{pmatrix}',
      r'\forall x\in\mathbb{R},\;\exists y:\;x\leq y',
      r'\alpha\land\beta\implies\gamma\in A\cup B',
      r'x_i^{n+1}',
    ];
    await open(tester, formulas.map((f) => '\$\$\n$f\n\$\$').join('\n\n'));
    expect(find.byType(EditableMathExpression), findsNWidgets(formulas.length));
    expect(
      find.byTooltip('Invalid or unsupported LaTeX. The source is preserved.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rich selection survives mode switches without content edits', (
    tester,
  ) async {
    Map<String, dynamic>? saved;
    await open(tester, '**Select** these words', onState: (v) => saved = v);
    await tester.tap(field('Select these words'));
    tester
        .widget<TextField>(field('Select these words'))
        .controller!
        .selection = const TextSelection(
      baseOffset: 2,
      extentOffset: 9,
    );
    await tester.tap(find.text('Source'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rich'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(field('Select these words'))
          .controller!
          .selection,
      const TextSelection(baseOffset: 2, extentOffset: 9),
    );
    expect((saved!['rich'] as Map)['base'], 2);
    expect(body, '**Select** these words');
  });

  testWidgets('empty code blocks remain fenced after editing and undo', (
    tester,
  ) async {
    await open(tester, '```dart\n```\n\nUntouched');
    await tester.enterText(
      find.byKey(const ValueKey('rich-code')),
      'final x = 1;',
    );
    await tester.pumpAndSettle();
    expect(body, '```dart\nfinal x = 1;\n```\n\nUntouched');
    await tester.tap(find.byTooltip('Undo · Ctrl+Z'));
    await tester.pumpAndSettle();
    expect(body, '```dart\n```\n\nUntouched');
    expect(find.byType(NoteCodeBlock), findsOneWidget);
  });

  testWidgets(
    'text after a terminal inline equation can create a new paragraph',
    (tester) async {
      await open(tester, r'An equation $x^2$');
      final afterMath = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == '' && w.maxLines == null,
      );
      await tester.tap(afterMath);
      await tester.enterText(afterMath, ' after');
      await tester.pumpAndSettle();
      final tail = tester.widget<TextField>(field(' after'));
      tail.controller!.selection = const TextSelection.collapsed(offset: 6);
      await key(tester, LogicalKeyboardKey.enter);
      expect(body, 'An equation \$x^2\$ after\n\n');
      final inputs = find.byWidgetPredicate(
        (w) => w is TextField && w.focusNode?.hasFocus == true,
      );
      expect(inputs, findsOneWidget);
      await tester.enterText(inputs, 'Next paragraph');
      await tester.pumpAndSettle();
      expect(body, 'An equation \$x^2\$ after\n\nNext paragraph');
    },
  );
}
