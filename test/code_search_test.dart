import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/note_find_index.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';
import 'package:orbit_note/features/notes/rich/fenced_code_source.dart';

void main() {
  const source =
      'Before\r\n\r\n  ````dart custom=target  \r\n'
      'print("target");\r\n**target** and été 😀\r\n  `````  \r\n\r\nAfter';
  test('Rich indexes literal code body, excluding info and delimiters', () {
    final index = NoteFindIndex(source, rich: true);
    expect(index.matches('target'), hasLength(2));
    expect(index.matches('custom='), isEmpty);
    expect(index.matches('````'), isEmpty);
    expect(index.matches('**target**'), hasLength(1));
    for (final match in index.matches('target')) {
      expect(source.substring(match.start, match.end), 'target');
    }
    expect(NoteFindIndex(source, rich: false).matches('target'), hasLength(3));
    expect(NoteFindIndex(source, rich: false).matches('custom='), hasLength(1));
  });
  test('code whole words and selection use complete UTF-16 source bounds', () {
    final index = NoteFindIndex(source, rich: true);
    final selected = source.indexOf('été');
    expect(index.selectedText(selected, selected + 'été 😀'.length), 'été 😀');
    expect(index.matches('été', wholeWord: true), hasLength(1));
    expect(index.matches('té', wholeWord: true, start: selected + 1), isEmpty);
    final start = source.indexOf('print');
    final end = source.indexOf(' and');
    expect(index.matches('target', start: start, end: end), hasLength(2));
    expect(index.selectedText(start, end), 'print("target");\r\n**target**');
  });
  test(
    'replacement keeps original fences, info, spaces, CRLF and siblings',
    () {
      final index = NoteFindIndex(source, rich: true);
      final result = index.replace(index.matches('target'), 'changed');
      expect(
        result,
        source
            .replaceFirst('print("target")', 'print("changed")')
            .replaceFirst('**target**', '**changed**'),
      );
    },
  );
  test('closing-like code replacement grows only needed fence runs', () {
    final index = NoteFindIndex(source, rich: true);
    final result = index.replace(index.matches('**target**'), '``````');
    final code = MarkdownDocument.parse(
      result,
    ).blocks.firstWhere((b) => b.kind == MarkdownBlockKind.code);
    // This is inline in the body and cannot close a block.
    expect(code.prefix, '  ````dart custom=target  \r\n');
    final block = MarkdownDocument.parse(
      source,
    ).blocks.firstWhere((b) => b.kind == MarkdownBlockKind.code);
    final edited = replaceFencedCodeContent(block, '  ``````  \r\ntail');
    expect(edited.prefix, '  ```````dart custom=target  \r\n');
    expect(edited.suffix, '\r\n  ```````  \r\n');
    expect(
      MarkdownDocument.parse(edited.source).blocks.first.content,
      '  ``````  \r\ntail',
    );
  });
  test(
    'search replacement fences complete inserted lines and multiple blocks',
    () {
      const input =
          '```text\nTARGET\n```\n\nprose untouched\n\n~~~unknown\nTARGET\n~~~~~\n';
      final index = NoteFindIndex(input, rich: true);
      final result = index.replace(index.matches('TARGET'), '```\n~~~');
      final codes = MarkdownDocument.parse(
        result,
      ).blocks.where((b) => b.kind == MarkdownBlockKind.code).toList();
      expect(codes, hasLength(2));
      expect(codes[0].prefix, '````text\n');
      expect(codes[0].content, '```\n~~~');
      expect(codes[1].prefix, '~~~~unknown\n');
      expect(codes[1].suffix, '\n~~~~~\n');
      expect(codes[1].content, '```\n~~~');
    },
  );
  test('empty code, longer closers and no-op preserve authored source', () {
    final empty = MarkdownDocument.parse(
      '~~~ mystery\r\n  ~~~~~ \r\n',
    ).blocks.first;
    expect(replaceFencedCodeContent(empty, '').source, empty.source);
    final edited = replaceFencedCodeContent(empty, '~~~');
    expect(edited.source, '~~~~ mystery\r\n~~~\r\n  ~~~~~ \r\n');
    expect(MarkdownDocument.parse(edited.source).blocks.first.content, '~~~');
  });
  test('unfinished fences remain literal, recoverable source', () {
    const input = '```unfinished\nbody TARGET';
    final index = NoteFindIndex(input, rich: true);
    expect(index.matches('unfinished'), hasLength(1));
    expect(
      index.replace(index.matches('TARGET'), 'changed'),
      '```unfinished\nbody changed',
    );
  });

  late String body;
  Future<void> open(WidgetTester tester, String input) async {
    body = input;
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => NoteEditor(
              noteId: 'code-search',
              title: 'Code search',
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

  Finder query() => find.widgetWithText(TextField, 'Find in this note');
  Finder codes() => find.byKey(const ValueKey('rich-code'));
  TextField code(WidgetTester tester, [int index = 0]) =>
      tester.widget<TextField>(codes().at(index));
  Future<void> search(WidgetTester tester, String text) async {
    await tester.tap(find.byTooltip('Find in note · Ctrl+F'));
    await tester.pumpAndSettle();
    await tester.enterText(query(), text);
    await tester.pumpAndSettle();
  }

  Future<void> undo(WidgetTester tester, {bool redo = false}) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (redo) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    if (redo) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  testWidgets('Find selects exact code ranges both ways and keeps query focus', (
    tester,
  ) async {
    await open(
      tester,
      'intro\n\n```dart\nfirst target tail\nsecond target\n```\n\n~~~\nthird target\n~~~\n',
    );
    await search(tester, 'target');
    expect(
      code(tester).controller!.selection,
      const TextSelection(baseOffset: 6, extentOffset: 12),
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(
      code(
        tester,
      ).controller!.selection.textInside(code(tester).controller!.text),
      'target',
    );
    expect(code(tester).controller!.selection.start, 25);
    await tester.tap(find.byTooltip('Next match'));
    await tester.pumpAndSettle();
    expect(
      code(tester, 1).controller!.selection,
      const TextSelection(baseOffset: 6, extentOffset: 12),
    );
    expect(find.text('(3 of 3)'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous match'));
    await tester.pumpAndSettle();
    expect(find.text('(2 of 3)'), findsOneWidget);
    expect(tester.widget<TextField>(query()).focusNode!.hasFocus, isTrue);
    expect(body, contains('```dart'));
  });
  testWidgets('Find captures live code selection after other paragraphs', (
    tester,
  ) async {
    await open(tester, source);
    await tester.tap(codes());
    final controller = code(tester).controller!;
    controller.selection = TextSelection(
      baseOffset: controller.text.indexOf('**'),
      extentOffset: controller.text.indexOf(' and'),
    );
    await tester.tap(find.byTooltip('Find in note · Ctrl+F'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(query()).controller!.text, '**target**');
    await tester.enterText(query(), 'target');
    await tester.tap(find.byTooltip('Find in selection · Alt+S'));
    await tester.pumpAndSettle();
    expect(find.text('1 match'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('note-replacement')),
      'changed',
    );
    await tester.tap(find.text('Replace all in selection'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Apply '));
    await tester.pumpAndSettle();
    expect(body, source.replaceFirst('**target**', '**changed**'));
    // Find/Replace inputs own their text history. Use the explicit document
    // control while focus remains in the replacement field.
    await tester.tap(find.byKey(const ValueKey('note-document-undo')));
    await tester.pumpAndSettle();
    expect(body, source);
  });
  testWidgets('code replacement keeps fences and exact shared undo/redo', (
    tester,
  ) async {
    const input = 'before\n\n```dart info\nTARGET\n```\n\nafter';
    await open(tester, input);
    await search(tester, 'TARGET');
    await tester.enterText(
      find.byKey(const ValueKey('note-replacement')),
      '```\nnew',
    );
    await tester.tap(find.text('Replace all'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Apply '));
    await tester.pumpAndSettle();
    expect(body, 'before\n\n````dart info\n```\nnew\n````\n\nafter');
    expect(code(tester).controller!.text, '```\nnew');
    await tester.tap(find.byKey(const ValueKey('note-document-undo')));
    await tester.pumpAndSettle();
    expect(body, input);
    expect(code(tester).controller!.text, 'TARGET');
    await tester.tap(find.byKey(const ValueKey('note-document-redo')));
    await tester.pumpAndSettle();
    expect(code(tester).controller!.text, '```\nnew');
  });
  testWidgets(
    'back-to-back fence growth edits keep the current block before rebuild',
    (tester) async {
      const input = 'before\n\n```text\nold\n```\n\nafter';
      await open(tester, input);
      final field = tester.widget<TextField>(codes());
      field.controller!.text = '```\ntail';
      field.onChanged!('```\ntail');
      // The first edit grows the fence and schedules a parent rebuild. Deliver
      // another edit through the old field callback before that frame runs.
      field.controller!.text = '```\ntail\nmore';
      field.onChanged!('```\ntail\nmore');
      await tester.pumpAndSettle();
      expect(body, 'before\n\n````text\n```\ntail\nmore\n````\n\nafter');
      expect(code(tester).controller!.text, '```\ntail\nmore');
    },
  );
  testWidgets('focused code history retains field and selection beside prose', (
    tester,
  ) async {
    const input =
        'first paragraph\n\n```dart\nvalue TARGET tail\n```\n\nlast paragraph';
    await open(tester, input);
    await tester.enterText(codes(), 'value changed tail');
    await tester.pumpAndSettle();
    expect(code(tester).focusNode!.hasFocus, isTrue);
    await undo(tester);
    expect(body, input);
    expect(code(tester).controller!.text, 'value TARGET tail');
    expect(code(tester).focusNode!.hasFocus, isTrue);
    await undo(tester, redo: true);
    expect(code(tester).controller!.text, 'value changed tail');
    expect(code(tester).focusNode!.hasFocus, isTrue);
  });
  testWidgets('single Replace advances to the next match when fences grow', (
    tester,
  ) async {
    await open(tester, '```text\nTARGET\nTARGET\nTARGET\n```\n');
    await search(tester, 'TARGET');
    await tester.enterText(
      find.byKey(const ValueKey('note-replacement')),
      '``````',
    );
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(code(tester).controller!.text, '``````\nTARGET\nTARGET');
    expect(
      code(tester).controller!.selection,
      const TextSelection(baseOffset: 7, extentOffset: 13),
    );
    expect(find.text('(1 of 2)'), findsOneWidget);
  });
  testWidgets(
    'distant line and horizontal match scroll to the selected caret',
    (tester) async {
      final lines = List.generate(85, (i) => 'line $i').join('\n');
      final text = '$lines\n${'x' * 240}TARGET';
      await open(tester, '```text\n$text\n```\n');
      await search(tester, 'TARGET');
      final editable = tester.state<EditableTextState>(
        find.descendant(of: codes(), matching: find.byType(EditableText)),
      );
      final render = editable.renderEditable;
      final caret = render.getLocalRectForCaret(
        TextPosition(offset: text.length),
      );
      final point = render.localToGlobal(caret.center);
      expect(point.dx, inInclusiveRange(0, 1280));
      expect(point.dy, inInclusiveRange(100, 900));
      expect(code(tester).controller!.selection.textInside(text), 'TARGET');
      expect(tester.widget<TextField>(query()).focusNode!.hasFocus, isTrue);
    },
  );
  testWidgets(
    'focused code undo retains a backwards range instead of collapsing it',
    (tester) async {
      await open(tester, 'before\n\n```text\nfirst target tail\n```\n\nafter');
      await tester.enterText(codes(), 'first edited tail');
      await tester.pumpAndSettle();
      code(tester).controller!.selection = const TextSelection(
        baseOffset: 12,
        extentOffset: 6,
      );
      await undo(tester);
      expect(code(tester).controller!.text, 'first target tail');
      expect(
        code(tester).controller!.selection,
        const TextSelection(baseOffset: 12, extentOffset: 6),
      );
      expect(code(tester).focusNode!.hasFocus, isTrue);
    },
  );
  testWidgets('code search counts body in Rich/Read and info in Source/Split', (
    tester,
  ) async {
    await open(tester, source);
    await search(tester, 'custom=target');
    expect(find.text('0 matches'), findsOneWidget);
    for (final mode in ['Source', 'Split', 'Read', 'Rich']) {
      await tester.tap(find.text(mode));
      await tester.pumpAndSettle();
      expect(
        find.text(
          mode == 'Source' || mode == 'Split' ? '1 match' : '0 matches',
        ),
        findsOneWidget,
      );
    }
    expect(body, source);
  });
  testWidgets(
    'typing a delimiter line retains code focus and source-exact undo',
    (tester) async {
      const input = 'before\n\n~~~custom\nold\n~~~\n\nafter';
      await open(tester, input);
      await tester.enterText(codes(), '~~~\ntail');
      await tester.pumpAndSettle();
      expect(body, 'before\n\n~~~~custom\n~~~\ntail\n~~~~\n\nafter');
      expect(code(tester).focusNode!.hasFocus, isTrue);
      await undo(tester);
      expect(body, input);
      await undo(tester, redo: true);
      expect(code(tester).controller!.text, '~~~\ntail');
    },
  );
}
