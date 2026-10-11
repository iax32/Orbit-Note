import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/note_find_index.dart';
import 'package:orbit_note/features/notes/rich/callout_block.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';
import 'package:orbit_note/features/notes/rich/structured_text_projection.dart';

void main() {
  const table =
      '| Name | Detail |\r\n| :--- | ---: |\r\n'
      '| first | a\\|b target |\r\n| second | tail target |\r\n';
  const callout =
      '> [!MYSTERY]   Title target  \r\n'
      '>   first line \r\n>second target\r\n> tail   \r\n';
  test('cell search excludes delimiters and alignment, maps escaped pipes', () {
    final index = NoteFindIndex(table, rich: true);
    expect(index.matches('---'), isEmpty);
    expect(index.matches('|'), hasLength(1));
    final match = index.matches('a|b').single;
    expect(table.substring(match.start, match.end), r'a\|b');
    expect(index.replace([match], 'x|y'), table.replaceFirst(r'a\|b', r'x\|y'));
    expect(index.matches('Detail first'), isEmpty);
  });
  test('cell selection scope cannot create word boundaries', () {
    final index = NoteFindIndex(table, rich: true);
    final target = table.indexOf('target');
    expect(
      index.matches('target', start: target, end: target + 6),
      hasLength(1),
    );
    expect(
      index.matches('tar', wholeWord: true, start: target, end: target + 3),
      isEmpty,
    );
  });
  test(
    'cell projection mirrors editor text for escaping and literal Markdown',
    () {
      for (final source in [
        r'a\|b',
        r'a\\|b',
        r'a\\\|b',
        r'a\\\\|b',
        r'`x|y`',
        '**bold**',
        r'\\',
      ]) {
        final projection = StructuredTextProjection.cell(source);
        expect(projection.text, MarkdownTable.visibleCell(source));
        expect(projection.edit(projection.text), source);
        expect(
          StructuredTextProjection.cell(
            projection.edit('${projection.text}|tail'),
          ).text,
          '${projection.text}|tail',
        );
      }
    },
  );
  test('callout search indexes title/body and excludes type/quote syntax', () {
    final index = NoteFindIndex(callout, rich: true);
    expect(index.matches('target'), hasLength(2));
    expect(index.matches('MYSTERY'), isEmpty);
    expect(index.matches('>'), isEmpty);
    expect(
      index.replace(index.matches('target'), 'kitten'),
      callout.replaceAll('target', 'kitten'),
    );
    expect(
      NoteFindIndex(callout, rich: false).matches('MYSTERY'),
      hasLength(1),
    );
  });
  test(
    'callout body maps multiline text and preserves unrelated whitespace',
    () {
      final parts = CalloutSourceParts(callout);
      expect(parts.body.text, '  first line \nsecond target\ntail   ');
      expect(parts.editBody(parts.body.text), callout);
      expect(
        parts.editBody(parts.body.text.replaceFirst('target', 'value')),
        callout.replaceFirst('second target', 'second value'),
      );
      final index = NoteFindIndex(callout, rich: true);
      final match = index.matches('line \nsecond').single;
      expect(callout.substring(match.start, match.end), 'line \r\n>second');
    },
  );
  test(
    'callout line insertion and deletion retain quoted structure and CRLF',
    () {
      const source = '> [!NOTE] Title\r\n> one\r\n>two\r\n';
      final parts = CalloutSourceParts(source);
      expect(parts.editBody('one two'), '> [!NOTE] Title\r\n> one two\r\n');
      expect(
        parts.editBody('one\nmiddle\ntwo'),
        '> [!NOTE] Title\r\n> one\r\n> middle\r\n>two\r\n',
      );
      expect(parts.editBody(''), '> [!NOTE] Title\r\n> \r\n');
      final empty = CalloutSourceParts('> [!TIP] Title');
      expect(empty.editBody('new\nline'), '> [!TIP] Title\n> new\n> line\n');
    },
  );
  test(
    'multiline callout replacement keeps owning block and following prose',
    () {
      const source =
          '> [!TIP] Title\r\n> first\r\n>second\r\n\r\nFollowing\r\n';
      final index = NoteFindIndex(source, rich: true);
      expect(
        index.replace(index.matches('first\nsecond'), 'new\nbody'),
        '> [!TIP] Title\r\n> new\r\n> body\r\n\r\nFollowing\r\n',
      );
    },
  );

  test(
    'newlines in table cells or callout titles refuse the complete batch',
    () {
      for (final source in [table, callout]) {
        final index = NoteFindIndex(source, rich: true);
        expect(
          () => index.replace(index.matches('target'), 'new\nline'),
          throwsFormatException,
        );
        expect(index.source, source);
      }
    },
  );

  test(
    'editing authored unquoted blank lines keeps the body owned by the callout',
    () {
      const source = '> [!NOTE] Title\r\n\r\n> body\r\n';
      final parts = CalloutSourceParts(source);
      expect(parts.body.text, '\nbody');
      expect(parts.editBody('body'), '> [!NOTE] Title\r\n> body\r\n');
      expect(
        parts.editBody('new\nbody'),
        '> [!NOTE] Title\r\n> new\r\n> body\r\n',
      );
      expect(
        parts.editBody('new\n\nbody'),
        '> [!NOTE] Title\r\n> new\r\n\r\n> body\r\n',
      );
      expect(
        MarkdownDocument.parse(parts.editBody('body')).blocks.single.kind,
        MarkdownBlockKind.callout,
      );
    },
  );

  late String body;
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
              noteId: 'structured-search',
              title: 'Search',
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
  TextField cell(WidgetTester tester, int row, int col) =>
      tester.widget<TextField>(find.byKey(ValueKey('rich-cell-$row-$col')));
  TextField bodyField(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(const ValueKey('callout-body')));
  Future<void> search(WidgetTester tester, String term) async {
    await tester.tap(find.byTooltip('Find in note · Ctrl+F'));
    await tester.pumpAndSettle();
    await tester.enterText(query(), term);
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

  testWidgets(
    'find selects exact cells in both directions and retains query focus',
    (tester) async {
      await open(tester, table);
      await search(tester, 'target');
      expect(
        cell(
          tester,
          1,
          1,
        ).controller!.selection.textInside(cell(tester, 1, 1).controller!.text),
        'target',
      );
      expect(tester.widget<TextField>(query()).focusNode!.hasFocus, isTrue);
      await tester.tap(find.byTooltip('Next match'));
      await tester.pumpAndSettle();
      expect(
        cell(
          tester,
          2,
          1,
        ).controller!.selection.textInside(cell(tester, 2, 1).controller!.text),
        'target',
      );
      expect(find.text('(2 of 2)'), findsOneWidget);
      await tester.tap(find.byTooltip('Previous match'));
      await tester.pumpAndSettle();
      expect(find.text('(1 of 2)'), findsOneWidget);
      expect(body, table);
    },
  );
  testWidgets(
    'escaped-pipe search selects visible text and replacement undoes exactly',
    (tester) async {
      await open(tester, table);
      await search(tester, 'a|b');
      final controller = cell(tester, 1, 1).controller!;
      expect(controller.selection.textInside(controller.text), 'a|b');
      await tester.enterText(
        find.byKey(const ValueKey('note-replacement')),
        'x|y',
      );
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      expect(body, table.replaceFirst(r'a\|b', r'x\|y'));
      expect(cell(tester, 1, 1).controller!.text, 'x|y target');
      await undo(tester);
      expect(body, table);
      expect(cell(tester, 1, 1).controller!.text, 'a|b target');
      await undo(tester, redo: true);
      expect(cell(tester, 1, 1).controller!.text, 'x|y target');
    },
  );
  testWidgets('callout title is highlighted and next selects exact body text', (
    tester,
  ) async {
    await open(tester, callout);
    await search(tester, 'target');
    final header = tester.widget<Text>(
      find.byKey(const ValueKey('callout-header')),
    );
    final children = (header.textSpan as TextSpan).children!;
    expect(
      children.whereType<TextSpan>().where(
        (s) => s.text == 'target' && s.style?.backgroundColor != null,
      ),
      hasLength(1),
    );
    await tester.tap(find.byTooltip('Next match'));
    await tester.pumpAndSettle();
    final field = bodyField(tester);
    expect(
      field.controller!.selection.textInside(field.controller!.text),
      'target',
    );
    expect(find.text('(2 of 2)'), findsOneWidget);
    expect(tester.widget<TextField>(query()).focusNode!.hasFocus, isTrue);
    expect(body, callout);
  });
  testWidgets('callout replace-all preserves custom type and exact undo', (
    tester,
  ) async {
    await open(tester, callout);
    await search(tester, 'target');
    await tester.enterText(
      find.byKey(const ValueKey('note-replacement')),
      'kitten',
    );
    await tester.tap(find.text('Replace all'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Apply '));
    await tester.pumpAndSettle();
    expect(body, callout.replaceAll('target', 'kitten'));
    expect(bodyField(tester).controller!.text, contains('second kitten'));
    await undo(tester);
    expect(body, callout);
    expect(bodyField(tester).controller!.text, contains('second target'));
  });
  testWidgets(
    'typing in a focused callout preserves source and undo synchronizes it',
    (tester) async {
      await open(tester, callout);
      final field = find.byKey(const ValueKey('callout-body'));
      await tester.enterText(
        field,
        bodyField(tester).controller!.text.replaceFirst('target', 'edited'),
      );
      await tester.pumpAndSettle();
      expect(body, callout.replaceFirst('second target', 'second edited'));
      expect(bodyField(tester).focusNode!.hasFocus, isTrue);
      await undo(tester);
      expect(body, callout);
      expect(
        bodyField(tester).controller!.text,
        '  first line \nsecond target\ntail   ',
      );
      await undo(tester, redo: true);
      expect(body, callout.replaceFirst('second target', 'second edited'));
      expect(bodyField(tester).controller!.text, contains('second edited'));
    },
  );
  testWidgets(
    'changing callout type retains authored title, body and line endings',
    (tester) async {
      await open(tester, callout);
      await tester.tap(find.byTooltip('Change callout type'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tip').last);
      await tester.pumpAndSettle();
      expect(body, callout.replaceFirst('MYSTERY', 'TIP'));
      await tester.tap(find.byTooltip('Undo · Ctrl+Z'));
      await tester.pumpAndSettle();
      expect(body, callout);
    },
  );
  testWidgets(
    'callout keeps a local type change when body edits arrive before rebuild',
    (tester) async {
      await open(tester, callout);
      final menu = tester.widget<PopupMenuButton<CalloutType>>(
        find.ancestor(
          of: find.byTooltip('Change callout type'),
          matching: find.byType(PopupMenuButton<CalloutType>),
        ),
      );
      menu.onSelected!(CalloutType.tip);

      final field = bodyField(tester);
      field.controller!.text = 'edited body';
      field.onChanged!('edited body');

      expect(body, '> [!TIP]   Title target  \r\n> edited body\r\n');
      await tester.pumpAndSettle();
      expect(body, '> [!TIP]   Title target  \r\n> edited body\r\n');
    },
  );
  testWidgets('search scrolls to a distant table row without editing source', (
    tester,
  ) async {
    final source =
        '| Name | Value |\n| --- | --- |\n'
        '${List.generate(100, (i) => '| Row $i | value $i |\n').join()}';
    await open(tester, source);
    await search(tester, 'value 99');
    final field = cell(tester, 100, 1);
    expect(
      field.controller!.selection.textInside(field.controller!.text),
      'value 99',
    );
    final rect = tester.getRect(find.byKey(const ValueKey('rich-cell-100-1')));
    expect(rect.top, greaterThan(0));
    expect(rect.bottom, lessThan(1000));
    expect(tester.widget<TextField>(query()).focusNode!.hasFocus, isTrue);
    expect(body, source);
  });
  testWidgets(
    'focused callout undo retains its field beside other paragraphs',
    (tester) async {
      final source = 'Before\r\n\r\n$callout\r\nAfter\r\n';
      await open(tester, source);
      await tester.enterText(
        find.byKey(const ValueKey('callout-body')),
        bodyField(tester).controller!.text.replaceFirst('target', 'edited'),
      );
      await tester.pumpAndSettle();
      await undo(tester);
      expect(body, source);
      expect(bodyField(tester).focusNode!.hasFocus, isTrue);
      await undo(tester, redo: true);
      expect(body, source.replaceFirst('second target', 'second edited'));
      expect(bodyField(tester).focusNode!.hasFocus, isTrue);
    },
  );
  testWidgets(
    'focused table undo retains the edited cell instead of the first cell',
    (tester) async {
      await open(tester, 'Before\r\n\r\n$table\r\nAfter\r\n');
      final source = body;
      await tester.enterText(
        find.byKey(const ValueKey('rich-cell-2-1')),
        'edited',
      );
      await tester.pumpAndSettle();
      await undo(tester);
      expect(body, source);
      expect(cell(tester, 2, 1).focusNode!.hasFocus, isTrue);
      expect(cell(tester, 2, 1).controller!.text, 'tail target');
      await undo(tester, redo: true);
      expect(cell(tester, 2, 1).focusNode!.hasFocus, isTrue);
      expect(cell(tester, 2, 1).controller!.text, 'edited');
    },
  );
  testWidgets(
    'long callout titles wrap with the type control accessible in narrow notes',
    (tester) async {
      await open(
        tester,
        '> [!NOTE] ${List.filled(25, 'Long title').join(' ')}\n> Body\n',
      );
      tester.view.physicalSize = const Size(520, 1000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(find.byTooltip('Change callout type'));
      expect(rect.right, lessThanOrEqualTo(520));
      expect(rect.left, greaterThanOrEqualTo(0));
      await tester.tap(find.byTooltip('Change callout type'));
      await tester.pumpAndSettle();
      expect(find.text('Tip'), findsOneWidget);
    },
  );
  testWidgets(
    'Backspace removes a leading callout blank line with exact undo',
    (tester) async {
      const source = '> [!NOTE] Title\r\n\r\n> body\r\n';
      await open(tester, source);
      await tester.tap(find.byKey(const ValueKey('callout-body')));
      bodyField(tester).controller!.selection = const TextSelection.collapsed(
        offset: 1,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(body, '> [!NOTE] Title\r\n> body\r\n');
      expect(bodyField(tester).controller!.text, 'body');
      await undo(tester);
      expect(body, source);
      expect(bodyField(tester).controller!.text, '\nbody');
    },
  );
  testWidgets(
    'Find seeds visible text from the selected cell after other paragraphs',
    (tester) async {
      await open(tester, 'Before\r\n\r\n$table');
      await tester.tap(find.byKey(const ValueKey('rich-cell-1-1')));
      cell(tester, 1, 1).controller!.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 3,
      );
      await tester.tap(find.byTooltip('Find in note · Ctrl+F'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(query()).controller!.text, 'a|b');
      expect(find.text('1 match'), findsOneWidget);
    },
  );
  testWidgets(
    'Find captures callout body selection and excludes its title and following text',
    (tester) async {
      final source = 'Before\r\n\r\n$callout\r\nFollowing target\r\n';
      await open(tester, source);
      await tester.tap(find.byKey(const ValueKey('callout-body')));
      final controller = bodyField(tester).controller!;
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
      await search(tester, 'target');
      expect(find.text('In Selection'), findsOneWidget);
      expect(find.text('1 match'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('note-replacement')),
        'edited',
      );
      await tester.tap(find.text('Replace all in selection'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Apply '));
      await tester.pumpAndSettle();
      expect(body, source.replaceFirst('second target', 'second edited'));
      await undo(tester);
      expect(body, source);
    },
  );
}
