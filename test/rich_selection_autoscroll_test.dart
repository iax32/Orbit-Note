import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';

void main() {
  Future<void> advance(WidgetTester tester, [int frames = 30]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<(RichMarkdownEditorState, ValueNotifier<String>)> open(
    WidgetTester tester, {
    int paragraphs = 60,
    double scale = 1,
    bool formatted = true,
    ValueChanged<Map<String, dynamic>>? onState,
  }) async {
    final source = ValueNotifier(
      List.generate(
        paragraphs,
        (i) =>
            'Paragraph $i contains ${formatted ? '**formatted**' : 'formatted'} text and emoji 🎮.',
      ).join('\n\n'),
    );
    addTearDown(source.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 640,
              height: 400,
              child: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: ValueListenableBuilder<String>(
                  valueListenable: source,
                  builder: (context, body, _) => RichMarkdownEditor(
                    noteId: 'drag-note',
                    body: body,
                    onChanged: (v) => source.value = v,
                    onState: onState,
                    onUndo: () {},
                    onRedo: () {},
                    linkTargets: const [],
                    linkBindings: const {},
                    onOpenLink: (_) {},
                    spellCheckEnabled: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (
      tester.state<RichMarkdownEditorState>(find.byType(RichMarkdownEditor)),
      source,
    );
  }

  Finder field(int i) => find.byWidgetPredicate(
    (w) =>
        w is TextField &&
        (w.controller?.text.startsWith('Paragraph $i contains') ?? false),
  );

  for (final count in [60, 360]) {
    testWidgets(
      'wheel during selection does not return to its starting block in $count blocks',
      (tester) async {
        final (editor, _) = await open(tester, paragraphs: count);
        final viewport = tester.getRect(find.byType(RichMarkdownEditor));
        final start = tester.getTopLeft(field(0)) + const Offset(12, 12);
        final gesture = await tester.startGesture(
          start,
          kind: PointerDeviceKind.mouse,
        );
        await gesture.moveTo(start + const Offset(180, 0));
        await tester.pumpAndSettle();
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: viewport.center,
            scrollDelta: const Offset(0, 600),
            kind: PointerDeviceKind.mouse,
          ),
        );
        await tester.pump();
        expect(
          editor.scroll.offset,
          greaterThanOrEqualTo(590),
          reason: 'wheel before moving',
        );
        await gesture.moveTo(viewport.center);
        await advance(tester);
        expect(editor.scroll.offset, greaterThanOrEqualTo(590));
        expect(editor.currentDocumentSelection.extentOffset, greaterThan(300));
        await gesture.up();
        await advance(tester);
        expect(editor.scroll.offset, greaterThanOrEqualTo(590));
      },
    );

    testWidgets(
      'manual wheel after native selection stays put in $count blocks',
      (tester) async {
        final (editor, source) = await open(tester, paragraphs: count);
        final before = source.value;
        final viewport = tester.getRect(find.byType(RichMarkdownEditor));
        final start = tester.getTopLeft(field(0)) + const Offset(12, 12);
        final gesture = await tester.startGesture(
          start,
          kind: PointerDeviceKind.mouse,
        );
        await gesture.moveTo(start + const Offset(180, 0));
        await gesture.up();
        await tester.pumpAndSettle();
        final selection = editor.currentDocumentSelection;
        expect(selection.isCollapsed, isFalse);
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: viewport.center,
            scrollDelta: const Offset(0, 600),
            kind: PointerDeviceKind.mouse,
          ),
        );
        await advance(tester);
        expect(editor.scroll.offset, greaterThanOrEqualTo(590));
        expect(editor.currentDocumentSelection, selection);
        expect(source.value, before);
      },
    );
  }

  for (final count in [60, 360]) {
    testWidgets(
      'stationary wheel selection updates, copies, reverses and releases in $count blocks',
      (tester) async {
        String clipboard = '';
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.getData') return {'text': clipboard};
          return null;
        });
        addTearDown(
          () =>
              messenger.setMockMethodCallHandler(SystemChannels.platform, null),
        );
        Map<String, dynamic> lastView = {};
        final (editor, source) = await open(
          tester,
          paragraphs: count,
          formatted: false,
          onState: (value) => lastView = value,
        );
        final original = source.value;
        final start = tester.getTopLeft(field(0)) + const Offset(12, 12);
        final gesture = await tester.startGesture(
          start,
          kind: PointerDeviceKind.mouse,
        );
        await gesture.moveTo(start + const Offset(180, 0));
        await tester.pumpAndSettle();
        final base = editor.currentDocumentSelection.baseOffset;
        Future<void> wheel(double delta) async {
          await tester.sendEventToBinding(
            PointerScrollEvent(
              position: start + const Offset(180, 0),
              scrollDelta: Offset(0, delta),
              kind: PointerDeviceKind.mouse,
            ),
          );
          await advance(tester);
        }

        await wheel(600);
        final range = editor.currentDocumentSelection;
        expect(editor.scroll.offset, 600);
        expect(range.baseOffset, base);
        expect(lastView['selection'], {
          'base': range.baseOffset,
          'extent': range.extentOffset,
        });
        expect(
          range.extentOffset,
          greaterThan(original.indexOf('Paragraph 5')),
        );
        await wheel(600);
        expect(editor.scroll.offset, 1200);
        expect(editor.currentDocumentSelection.baseOffset, base);
        expect(
          editor.currentDocumentSelection.extentOffset,
          greaterThan(range.extentOffset),
        );
        await wheel(-600);
        expect(editor.scroll.offset, 600);
        expect(editor.currentDocumentSelection, range);
        await gesture.up();
        await advance(tester);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(clipboard, contains('Paragraph 5'));
        expect(clipboard, isNot(contains('Paragraph 30')));
        expect(clipboard, original.substring(range.start, range.end));
        expect(source.value, original);
        expect(editor.scroll.offset, 600);
        expect(editor.currentDocumentSelection, range);
        await wheel(600);
        expect(editor.scroll.offset, 1200);
        expect(editor.currentDocumentSelection, range);
        // The old paragraph remains normally editable after the handoff ends.
        editor.scroll.jumpTo(0);
        await tester.pumpAndSettle();
        await tester.tap(field(0));
        await tester.pumpAndSettle();
        final native = tester.widget<TextField>(field(0));
        expect(native.focusNode!.hasFocus, isTrue);
        expect(native.focusNode!.canRequestFocus, isTrue);
        expect(editor.hasCrossDocumentSelection, isFalse);
        await tester.enterText(field(0), 'Edited after selection');
        await tester.pumpAndSettle();
        expect(source.value, startsWith('Edited after selection'));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final count in [60, 360]) {
    testWidgets(
      'upward wheel selection keeps the anchor and cancellation stops updates in $count blocks',
      (tester) async {
        final (editor, source) = await open(
          tester,
          paragraphs: count,
          formatted: false,
        );
        final original = source.value;
        editor.scroll.jumpTo(1000);
        await tester.pumpAndSettle();
        final viewport = tester.getRect(find.byType(RichMarkdownEditor));
        final visible = find
            .byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  (w.controller?.text.startsWith('Paragraph ') ?? false),
            )
            .hitTestable();
        final target = visible.at(visible.evaluate().length ~/ 2);
        final start = tester.getTopLeft(target) + const Offset(24, 12);
        final gesture = await tester.startGesture(
          start,
          kind: PointerDeviceKind.mouse,
        );
        await gesture.moveTo(start + const Offset(100, 0));
        await tester.pumpAndSettle();
        final base = editor.currentDocumentSelection.baseOffset;
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: start + const Offset(100, 0),
            scrollDelta: const Offset(0, -600),
            kind: PointerDeviceKind.mouse,
          ),
        );
        await advance(tester);
        expect(editor.scroll.offset, 400);
        expect(editor.currentDocumentSelection.baseOffset, base);
        expect(editor.currentDocumentSelection.extentOffset, lessThan(base));
        await gesture.moveTo(viewport.center);
        await advance(tester);
        expect(editor.scroll.offset, 400);
        await gesture.cancel();
        await tester.pumpAndSettle();
        final range = editor.currentDocumentSelection;
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: viewport.center,
            scrollDelta: const Offset(0, 300),
            kind: PointerDeviceKind.mouse,
          ),
        );
        await advance(tester);
        expect(editor.scroll.offset, 700);
        expect(editor.currentDocumentSelection, range);
        expect(source.value, original);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'edge hold selects newly revealed text in $count paragraph note',
      (tester) async {
        final (editor, source) = await open(tester, paragraphs: count);
        final before = source.value;
        final viewport = tester.getRect(find.byType(RichMarkdownEditor));
        final gesture = await tester.startGesture(
          tester.getTopLeft(field(0)) + const Offset(12, 12),
          kind: PointerDeviceKind.mouse,
        );
        await gesture.moveTo(Offset(viewport.center.dx, viewport.bottom + 20));
        await advance(tester);
        expect(editor.scroll.offset, greaterThan(200));
        final selection = editor.currentDocumentSelection;
        expect(
          selection.extentOffset,
          greaterThan(before.indexOf('Paragraph 5')),
        );
        final base = selection.baseOffset;
        await advance(tester);
        expect(editor.currentDocumentSelection.baseOffset, base);
        expect(
          editor.currentDocumentSelection.extentOffset,
          greaterThan(selection.extentOffset),
        );
        expect(source.value, before);
        await gesture.up();
        await tester.pump();
        final stopped = editor.scroll.offset;
        final range = editor.currentDocumentSelection;
        await advance(tester);
        expect(editor.scroll.offset, stopped);
        expect(editor.currentDocumentSelection, range);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'leaving edge pauses and reversing direction keeps original anchor',
    (tester) async {
      final (editor, _) = await open(tester, paragraphs: 360);
      final rect = tester.getRect(find.byType(RichMarkdownEditor));
      final gesture = await tester.startGesture(
        tester.getTopLeft(field(0)) + const Offset(15, 12),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(Offset(rect.center.dx, rect.bottom - 2));
      await advance(tester, 50);
      final base = editor.currentDocumentSelection.baseOffset;
      await gesture.moveTo(rect.center);
      await tester.pump();
      final paused = editor.scroll.offset;
      await advance(tester);
      expect(editor.scroll.offset, paused);
      await gesture.moveTo(Offset(rect.center.dx, rect.top - 12));
      await advance(tester, 20);
      expect(editor.scroll.offset, lessThan(paused));
      expect(editor.currentDocumentSelection.baseOffset, base);
      await gesture.cancel();
      await tester.pump();
      final stopped = editor.scroll.offset;
      await advance(tester);
      expect(editor.scroll.offset, stopped);
    },
  );

  testWidgets('external text change and disposal stop pending drag frames', (
    tester,
  ) async {
    final (editor, source) = await open(tester);
    final rect = tester.getRect(find.byType(RichMarkdownEditor));
    final gesture = await tester.startGesture(
      tester.getTopLeft(field(0)) + const Offset(15, 12),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(Offset(rect.center.dx, rect.bottom));
    await advance(tester, 10);
    source.value = 'Replacement document';
    await tester.pumpAndSettle();
    expect(find.text('Replacement document'), findsOneWidget);
    expect(
      editor.currentDocumentSelection.extentOffset,
      lessThanOrEqualTo(source.value.length),
    );
    await gesture.up();
    await tester.pumpWidget(const SizedBox());
    await advance(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('right button and ordinary idle clicks do not auto-scroll', (
    tester,
  ) async {
    final (editor, _) = await open(tester);
    final rect = tester.getRect(find.byType(RichMarkdownEditor));
    final gesture = await tester.startGesture(
      tester.getCenter(field(0)),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.moveTo(Offset(rect.center.dx, rect.bottom + 10));
    await advance(tester);
    expect(editor.scroll.offset, 0);
    await gesture.up();
    await tester.tap(field(0));
    await advance(tester);
    expect(editor.scroll.offset, 0);
  });

  testWidgets('large text scroll clamps at document boundary', (tester) async {
    final (editor, _) = await open(tester, paragraphs: 8, scale: 2);
    final rect = tester.getRect(find.byType(RichMarkdownEditor));
    final gesture = await tester.startGesture(
      tester.getTopLeft(field(0)) + const Offset(15, 12),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(Offset(rect.center.dx, rect.bottom + 80));
    await advance(tester, 150);
    expect(editor.scroll.offset, editor.scroll.position.maxScrollExtent);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('focus loss stops edge hold and active disposal cancels frames', (
    tester,
  ) async {
    final (editor, _) = await open(tester);
    final rect = tester.getRect(find.byType(RichMarkdownEditor));
    final gesture = await tester.startGesture(
      tester.getTopLeft(field(0)) + const Offset(15, 12),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(Offset(rect.center.dx, rect.bottom));
    await advance(tester, 15);
    expect(editor.scroll.offset, greaterThan(0));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    final stopped = editor.scroll.offset;
    await advance(tester);
    expect(editor.scroll.offset, stopped);
    await gesture.up();
    editor.scroll.jumpTo(0);
    await tester.pumpAndSettle();
    final active = await tester.startGesture(
      tester.getTopLeft(field(0)) + const Offset(15, 12),
      kind: PointerDeviceKind.mouse,
    );
    await active.moveTo(Offset(rect.center.dx, rect.bottom));
    await advance(tester, 10);
    await tester.pumpWidget(const SizedBox());
    await active.up();
    await advance(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('window deactivation stops selection scrolling', (tester) async {
    final (editor, _) = await open(tester);
    final rect = tester.getRect(find.byType(RichMarkdownEditor));
    final gesture = await tester.startGesture(
      tester.getTopLeft(field(0)) + const Offset(15, 12),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(Offset(rect.center.dx, rect.bottom));
    await advance(tester, 10);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    final stopped = editor.scroll.offset;
    await advance(tester);
    expect(editor.scroll.offset, stopped);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await gesture.up();
  });
}
