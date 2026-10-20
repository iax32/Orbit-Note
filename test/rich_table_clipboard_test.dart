import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';
import 'package:orbit_note/features/notes/rich/rich_table_editor.dart';

void main() {
  late String body;
  String clipboard = '';
  Completer<String?>? pending;
  bool clipboardFails = false;
  String? htmlClipboard;
  String? richHtmlClipboard;
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('pasteboard'),
          (_) async => null,
        );
    pending = null;
    clipboardFails = false;
    htmlClipboard = null;
    richHtmlClipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            if (call.arguments == 'text/html') {
              return htmlClipboard == null ? null : {'text': htmlClipboard};
            }
            if (clipboardFails) {
              throw PlatformException(code: 'clipboard-unavailable');
            }
            final text = pending == null ? clipboard : await pending!.future;
            return text == null ? null : {'text': text};
          }
          if (call.method == 'Clipboard.setData') {
            if (clipboardFails) {
              throw PlatformException(code: 'clipboard-unavailable');
            }
            clipboard = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.hasStrings') {
            return {'value': clipboard.isNotEmpty};
          }
          return null;
        });
    const richClipboard = MethodChannel('orbit_note/clipboard');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(richClipboard, (call) async {
          if (call.method == 'setRichText') {
            richHtmlClipboard = (call.arguments as Map)['html'] as String;
            clipboard = (call.arguments as Map)['plainText'] as String;
            return true;
          }
          return null;
        });
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('orbit_note/clipboard'),
      null,
    );
  });
  Finder cell(int row, int col) => find.byKey(ValueKey('rich-cell-$row-$col'));
  Finder field(String text) => find.byWidgetPredicate(
    (w) => w is TextField && w.controller?.text == text,
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
              noteId: 'clipboard-note',
              title: 'Clipboard',
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
  }) async {
    if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  Future<void> operation(WidgetTester tester, String action) async {
    await tester.tap(find.byTooltip('Table operations'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  const table = '| A | B |\n| --- | --- |\n| One | Two |\n';
  testWidgets(
    'browser paragraph lists paste without phantom empty bullets and undo',
    (tester) async {
      await open(tester, 'Before');
      await tester.tap(field('Before'));
      await tester.pumpAndSettle();
      tester.widget<TextField>(field('Before')).controller!.selection =
          const TextSelection(baseOffset: 0, extentOffset: 6);
      clipboard =
          'Final Reminders\nBe on time: Exam at 13:15.\nSubmit manually: Save your answers.';
      htmlClipboard =
          '<h2>Final Reminders</h2><ul>'
          '<li><p><strong>Be on time:</strong> Exam at 13:15.</p></li>'
          '<li><p><strong>Submit manually:</strong> Save your answers.</p></li></ul>';
      await key(tester, LogicalKeyboardKey.keyV, control: true);
      expect(
        body,
        '## Final Reminders\n\n- **Be on time:** Exam at 13:15.\n- **Submit manually:** Save your answers.',
      );
      final lists = MarkdownDocument.parse(
        body,
      ).blocks.where((block) => block.kind == MarkdownBlockKind.list).toList();
      expect(lists, hasLength(2));
      expect(lists.every((block) => block.content.trim().isNotEmpty), isTrue);
      expect(field('Be on time: Exam at 13:15.'), findsOneWidget);
      expect(field('Submit manually: Save your answers.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await key(tester, LogicalKeyboardKey.keyZ, control: true);
      expect(body, 'Before');
    },
  );

  testWidgets(
    'blank rows retain their destination positions during grid paste',
    (tester) async {
      await open(tester, '| A |\n| --- |\n| One |\n');
      await tester.tap(cell(1, 0));
      clipboard = 'First\n\nThird\n';
      await tester
          .state<RichTableEditorState>(find.byType(RichTableEditor))
          .pasteGrid();
      await tester.pumpAndSettle();
      expect(MarkdownTable.tryParse(body)!.rows, [
        ['A'],
        ['First'],
        [''],
        ['Third'],
      ]);
    },
  );

  testWidgets(
    'an all-empty one-column selection retains its row count on copy and paste',
    (tester) async {
      await open(tester, '| A |\n| --- |\n| |\n| |\n| |\n');
      await tester.tap(cell(1, 0));
      final editor = tester.state<RichTableEditorState>(
        find.byType(RichTableEditor),
      );
      editor.selectRectangle(
        startRow: 1,
        startColumn: 0,
        endRow: 3,
        endColumn: 0,
      );
      await tester.pump();
      await editor.copySelection();
      expect(clipboard, '""\n""\n""');
      editor.clearRectangleSelection();
      await tester.pump();
      await tester.tap(cell(3, 0));
      await editor.pasteGrid();
      await tester.pumpAndSettle();
      expect(MarkdownTable.tryParse(body)!.rows, [
        ['A'],
        [''],
        [''],
        [''],
        [''],
        [''],
      ]);
    },
  );
  testWidgets('cell paste preserves active composition and native selection', (
    tester,
  ) async {
    await open(tester, table);
    await tester.tap(cell(1, 0));
    final controller = tester.widget<TextField>(cell(1, 0)).controller!;
    const value = TextEditingValue(
      text: 'One',
      selection: TextSelection.collapsed(offset: 3),
      composing: TextRange(start: 0, end: 3),
    );
    controller.value = value;
    clipboard = 'Replacement';
    await tester
        .state<RichTableEditorState>(find.byType(RichTableEditor))
        .pasteGrid(atCaret: true);
    await key(tester, LogicalKeyboardKey.keyV, control: true);
    expect(body, table);
    expect(controller.value, value);
  });
  for (final fail in [false, true]) {
    testWidgets(
      'rectangle cut ${fail ? 'failure preserves cells' : 'clears the range with one undo'}',
      (tester) async {
        final source = '$table| Three | Four |\n';
        await open(tester, source);
        await tester.tap(cell(1, 0));
        tester
            .state<RichTableEditorState>(find.byType(RichTableEditor))
            .selectRectangle(
              startRow: 1,
              startColumn: 0,
              endRow: 2,
              endColumn: 1,
            );
        await tester.pump();
        clipboardFails = fail;
        await key(tester, LogicalKeyboardKey.keyX, control: true);
        if (fail) {
          expect(body, source);
        } else {
          expect(clipboard, 'One\tTwo\nThree\tFour');
          expect(MarkdownTable.tryParse(body)!.rows.skip(1), [
            ['', ''],
            ['', ''],
          ]);
          await key(tester, LogicalKeyboardKey.keyZ, control: true);
          expect(body, source);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('native text cut retains exact selected substring and undo', (
    tester,
  ) async {
    await open(tester, table);
    await tester.tap(cell(1, 0));
    tester.widget<TextField>(cell(1, 0)).controller!.selection =
        const TextSelection(baseOffset: 1, extentOffset: 3);
    await key(tester, LogicalKeyboardKey.keyX, control: true);
    expect(clipboard, 'ne');
    expect(MarkdownTable.tryParse(body)!.rows[1], ['O', 'Two']);
    await key(tester, LogicalKeyboardKey.keyZ, control: true);
    expect(body, table);
  });

  testWidgets('native menu paste preserves the rectangular destination', (
    tester,
  ) async {
    await open(tester, '$table| Three | Four |\n');
    await tester.tap(cell(2, 1));
    tester
        .state<RichTableEditorState>(find.byType(RichTableEditor))
        .selectRectangle(startRow: 1, startColumn: 0, endRow: 2, endColumn: 1);
    await tester.pump();
    clipboard = 'X\tY\nZ\tW';
    final native = tester.state<EditableTextState>(
      find.descendant(of: cell(2, 1), matching: find.byType(EditableText)),
    );
    final toolbar =
        tester.widget<TextField>(cell(2, 1)).contextMenuBuilder!(
              tester.element(cell(2, 1)),
              native,
            )
            as AdaptiveTextSelectionToolbar;
    toolbar.buttonItems!
        .firstWhere((item) => item.type == ContextMenuButtonType.paste)
        .onPressed!();
    await tester.pumpAndSettle();
    expect(body, '| A | B |\n| --- | --- |\n| X | Y |\n| Z | W |\n');
  });

  testWidgets(
    'delayed grid paste refuses changed range with the same focus corner',
    (tester) async {
      await open(tester, '$table| Three | Four |\n');
      await tester.tap(cell(2, 1));
      final editor = tester.state<RichTableEditorState>(
        find.byType(RichTableEditor),
      );
      editor.selectRectangle(
        startRow: 0,
        startColumn: 0,
        endRow: 2,
        endColumn: 1,
      );
      await tester.pump();
      pending = Completer<String?>();
      final paste = editor.pasteGrid();
      await tester.pump();
      editor.selectRectangle(
        startRow: 1,
        startColumn: 0,
        endRow: 2,
        endColumn: 1,
      );
      pending!.complete('Changed\tCells');
      await paste;
      await tester.pumpAndSettle();
      expect(body, '$table| Three | Four |\n');
    },
  );
  testWidgets('failed native cell cut preserves the selected text', (
    tester,
  ) async {
    await open(tester, table);
    await tester.tap(cell(1, 0));
    tester.widget<TextField>(cell(1, 0)).controller!.selection =
        const TextSelection(baseOffset: 0, extentOffset: 3);
    clipboardFails = true;
    await key(tester, LogicalKeyboardKey.keyX, control: true);
    expect(body, table);
    expect(tester.widget<TextField>(cell(1, 0)).controller!.text, 'One');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keyboard rectangle paste replaces from upper left even with focus at the far corner',
    (tester) async {
      await open(tester, '$table| Three | Four |\n');
      await tester.tap(cell(2, 1));
      final editor = tester.state<RichTableEditorState>(
        find.byType(RichTableEditor),
      );
      editor.selectRectangle(
        startRow: 1,
        startColumn: 0,
        endRow: 2,
        endColumn: 1,
      );
      await tester.pump();
      clipboard = 'X\tY\nZ\tW';
      await key(tester, LogicalKeyboardKey.keyV, control: true);
      expect(body, '| A | B |\n| --- | --- |\n| X | Y |\n| Z | W |\n');
      await key(tester, LogicalKeyboardKey.keyZ, control: true);
      expect(body, '$table| Three | Four |\n');
    },
  );

  testWidgets('table paste uses one plain clipboard snapshot', (tester) async {
    await open(tester, table);
    await tester.tap(cell(1, 0));
    var reads = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            if (call.arguments == 'text/html') return null;
            return {'text': ++reads == 1 ? 'Captured' : 'Later clipboard'};
          }
          return null;
        });
    await tester
        .state<RichTableEditorState>(find.byType(RichTableEditor))
        .pasteGrid();
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(body, '| A | B |\n| --- | --- |\n| Captured | Two |\n');
  });

  testWidgets(
    'ordinary single-line paste retains commas and quotes in the cell',
    (tester) async {
      await open(tester, table);
      await tester.tap(cell(1, 0));
      tester.widget<TextField>(cell(1, 0)).controller!.selection =
          const TextSelection(baseOffset: 0, extentOffset: 3);
      clipboard = 'Hello, "friend"';
      await key(tester, LogicalKeyboardKey.keyV, control: true);
      expect(MarkdownTable.tryParse(body)!.rows[1], ['Hello, "friend"', 'Two']);
    },
  );
  for (final reverse in [false, true]) {
    testWidgets(
      'rectangle paste uses its upper left corner (${reverse ? 'reverse' : 'forward'}) and supports undo',
      (tester) async {
        await open(tester, '$table| Three | Four |\n');
        await tester.tap(cell(1, 0));
        final editor = tester.state<RichTableEditorState>(
          find.byType(RichTableEditor),
        );
        editor.selectRectangle(
          startRow: reverse ? 2 : 1,
          startColumn: reverse ? 1 : 0,
          endRow: reverse ? 1 : 2,
          endColumn: reverse ? 0 : 1,
        );
        await tester.pump();
        clipboard = 'X\tY\nZ\tW';
        await editor.pasteGrid();
        await tester.pumpAndSettle();
        expect(body, '| A | B |\n| --- | --- |\n| X | Y |\n| Z | W |\n');
        await key(tester, LogicalKeyboardKey.keyZ, control: true);
        expect(body, '$table| Three | Four |\n');
      },
    );
  }

  testWidgets(
    'TSV copy paste retains literal tabs, commas and quoted cell values',
    (tester) async {
      const source =
          '| A | B |\n| --- | --- |\n| one, two, three | "quoted"\tvalue |\n';
      await open(tester, source);
      final editor = tester.state<RichTableEditorState>(
        find.byType(RichTableEditor),
      );
      await tester.tap(cell(1, 0));
      editor.selectRectangle(
        startRow: 1,
        startColumn: 0,
        endRow: 1,
        endColumn: 1,
      );
      await tester.pump();
      await editor.copySelection();
      editor.clearRectangleSelection();
      await tester.pump();
      await tester.tap(cell(0, 0));
      await editor.pasteGrid();
      await tester.pumpAndSettle();
      final parsed = MarkdownTable.tryParse(body)!;
      expect(parsed.columns, 2);
      expect(parsed.rows[0], ['one, two, three', '"quoted"\tvalue']);
      expect(parsed.rows[1], ['one, two, three', '"quoted"\tvalue']);
    },
  );

  testWidgets(
    'single cell copy preserves quotes and commas when pasted as a grid',
    (tester) async {
      const source = '| A | B |\n| --- | --- |\n| "one, two" | Kept |\n';
      await open(tester, source);
      final editor = tester.state<RichTableEditorState>(
        find.byType(RichTableEditor),
      );
      await tester.tap(cell(1, 0));
      await editor.copyCell();
      await tester.tap(cell(0, 0));
      await editor.pasteGrid();
      await tester.pumpAndSettle();
      expect(MarkdownTable.tryParse(body)!.rows[0], ['"one, two"', 'B']);
    },
  );

  testWidgets(
    'TSV separator takes priority over commas inside unquoted cells',
    (tester) async {
      await open(tester, table);
      await tester.tap(cell(1, 0));
      clipboard = 'one, two, three\tvalue';
      await tester
          .state<RichTableEditorState>(find.byType(RichTableEditor))
          .pasteGrid();
      await tester.pumpAndSettle();
      expect(MarkdownTable.tryParse(body)!.rows[1], [
        'one, two, three',
        'value',
      ]);
    },
  );
  test(
    'table cell edits preserve mixed line endings and authored trailing whitespace',
    () {
      const source = ' A | B \r\n:-----| ---: \n One | Two\r\n\n  ';
      final table = MarkdownTable.tryParse(source)!;
      expect(table.encode(), source);
      table.rows[1][1] = 'Changed';
      expect(table.encode(), source.replaceFirst('Two', 'Changed'));
      table.rows.insert(1, ['', '']);
      expect(
        table.encode(),
        source
            .replaceFirst(' One', '|  |  |\r\n One')
            .replaceFirst('Two', 'Changed'),
      );
    },
  );
  test(
    'table cell boundaries respect backtick runs and pipe escape parity',
    () {
      expect(MarkdownTable.cells(r'| ``a`b|c`` | tail |'), [
        r'``a`b|c``',
        'tail',
      ]);
      expect(MarkdownTable.cells(r'| `open | tail |'), ['`open', 'tail']);
      for (var n = 0; n < 6; n++) {
        final visible = '${List.filled(n, '\\').join()}|literal';
        final encoded = MarkdownTable.cellText(visible);
        expect(MarkdownTable.cells('| $encoded | tail |'), [encoded, 'tail']);
        expect(MarkdownTable.visibleCell(encoded), visible);
      }
    },
  );
  testWidgets('cell editing preserves untouched table spelling and CRLF', (
    tester,
  ) async {
    const source =
        'Before **kept**\r\n\r\n  | A  | B |\r\n|:-----| ---: |\r\n| One  | Two |\r\n\r\n{{unknown}}\r\n';
    await open(tester, source);
    await tester.enterText(cell(1, 1), 'Changed');
    await tester.pumpAndSettle();
    expect(body, source.replaceFirst('Two', 'Changed'));
    await key(tester, LogicalKeyboardKey.keyZ, control: true);
    expect(body, source);
  });
  testWidgets(
    'literal backslashes and pipes survive cell edits and mode changes',
    (tester) async {
      await open(tester, table);
      const value = r'one\|two\\|three';
      await tester.enterText(cell(1, 0), value);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Source'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rich'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(cell(1, 0)).controller!.text, value);
      expect(cell(1, 1), findsOneWidget);
    },
  );
  testWidgets(
    'deleted cell controllers cannot resurrect text when Tab adds a row',
    (tester) async {
      await open(tester, '$table| Old | Ghost |\n');
      await tester.tap(cell(2, 1));
      await operation(tester, 'Delete row');
      await tester.tap(cell(1, 1));
      await key(tester, LogicalKeyboardKey.tab);
      expect(tester.widget<TextField>(cell(2, 0)).controller!.text, '');
      expect(tester.widget<TextField>(cell(2, 1)).controller!.text, '');
      expect(body.contains('Ghost'), isFalse);
    },
  );
  testWidgets('delayed TSV paste cannot overwrite a moved cell selection', (
    tester,
  ) async {
    await open(tester, table);
    await tester.tap(cell(1, 0));
    pending = Completer<String?>();
    await key(tester, LogicalKeyboardKey.keyV, control: true);
    tester.widget<TextField>(cell(1, 0)).controller!.selection =
        const TextSelection.collapsed(offset: 1);
    pending!.complete('X\tY\nZ\tW');
    await tester.pumpAndSettle();
    expect(body, table);
  });
  testWidgets('table clipboard failure leaves source and focus usable', (
    tester,
  ) async {
    await open(tester, table);
    await tester.tap(cell(1, 0));
    clipboardFails = true;
    await key(tester, LogicalKeyboardKey.keyV, control: true);
    expect(body, table);
    expect(tester.takeException(), isNull);
    await tester.enterText(cell(1, 0), 'Still editable');
    await tester.pumpAndSettle();
    expect(body, contains('Still editable'));
  });
  testWidgets(
    'table copy failure is recoverable and alignment accepts longer separators',
    (tester) async {
      const source = '| A | B |\n| :-----: | --- |\n| One | Two |\n';
      await open(tester, source);
      expect(tester.widget<TextField>(cell(1, 0)).textAlign, TextAlign.center);
      await tester.tap(cell(1, 0));
      clipboardFails = true;
      await tester.tap(find.byTooltip('Copy cell'));
      await tester.pumpAndSettle();
      expect(body, source);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'TSV menu paste uses grid semantics and an oversized paste changes nothing',
    (tester) async {
      clipboard = 'X\tY\rZ\tW\r';
      await open(tester, table);
      await tester.tap(cell(1, 0));
      await tester.pumpAndSettle();
      final editable = tester.state<EditableTextState>(
        find.descendant(of: cell(1, 0), matching: find.byType(EditableText)),
      );
      final toolbar =
          tester.widget<TextField>(cell(1, 0)).contextMenuBuilder!(
                tester.element(cell(1, 0)),
                editable,
              )
              as AdaptiveTextSelectionToolbar;
      toolbar.buttonItems!
          .firstWhere((item) => item.type == ContextMenuButtonType.paste)
          .onPressed!();
      await tester.pumpAndSettle();
      expect(body, '| A | B |\n| --- | --- |\n| X | Y |\n| Z | W |\n');
      await key(tester, LogicalKeyboardKey.keyZ, control: true);
      expect(body, table);
      expect(tester.widget<TextField>(cell(1, 0)).controller!.text, 'One');
      await key(tester, LogicalKeyboardKey.keyY, control: true);
      expect(tester.widget<TextField>(cell(1, 0)).controller!.text, 'X');
      expect(tester.widget<TextField>(cell(2, 1)).controller!.text, 'W');
      await key(tester, LogicalKeyboardKey.keyZ, control: true);
      expect(body, table);
      await tester.tap(cell(1, 0));
      clipboard = List.filled(51, 'excess').join('\t');
      await key(tester, LogicalKeyboardKey.keyV, control: true);
      expect(body, table);
      expect(
        find.textContaining('exceeds the editable table limit'),
        findsOneWidget,
      );
    },
  );
  testWidgets('rectangular selection copies a TSV range', (tester) async {
    await open(tester, table);
    final editor = tester.state<RichTableEditorState>(
      find.byType(RichTableEditor),
    );
    editor.selectRectangle(
      startRow: 0,
      startColumn: 0,
      endRow: 1,
      endColumn: 1,
    );
    await tester.pump();
    expect(find.text('2 × 2 selected'), findsOneWidget);
    await editor.copySelection();
    expect(clipboard, 'A\tB\nOne\tTwo');
    await editor.copySelectionAsCsv();
    expect(clipboard, '"A","B"\n"One","Two"');
  });

  testWidgets('dragging across cells selects a rectangle', (tester) async {
    await open(tester, table);
    final start = tester.getCenter(cell(0, 0));
    final end = tester.getCenter(cell(1, 1));
    await tester.dragFrom(start, end - start);
    await tester.pumpAndSettle();
    expect(find.text('2 × 2 selected'), findsOneWidget);
    final editor = tester.state<RichTableEditorState>(
      find.byType(RichTableEditor),
    );
    expect(editor.selectedRectangle, (0, 1, 0, 1));
  });

  testWidgets('selected cells copy a native rich HTML table', (tester) async {
    await open(tester, table);
    final editor = tester.state<RichTableEditorState>(
      find.byType(RichTableEditor),
    );
    editor.selectRectangle(
      startRow: 0,
      startColumn: 0,
      endRow: 1,
      endColumn: 1,
    );
    await tester.pump();
    await editor.copySelectionAsHtml();
    expect(clipboard, 'A\tB\nOne\tTwo');
    expect(
      richHtmlClipboard,
      '<table><tbody><tr><th>A</th><th>B</th></tr>'
      '<tr><td>One</td><td>Two</td></tr></tbody></table>',
    );
  });

  testWidgets('HTML table clipboard paste preserves cells as a grid', (
    tester,
  ) async {
    htmlClipboard =
        '<table><tr><th>Head</th><th>Value</th></tr>'
        '<tr><td>Alpha</td><td>Beta</td></tr></table>';
    await open(tester, table);
    final editor = tester.state<RichTableEditorState>(
      find.byType(RichTableEditor),
    );
    await tester.tap(cell(1, 0));
    await editor.pasteGrid();
    await tester.pumpAndSettle();
    expect(
      body,
      '| A | B |\n| --- | --- |\n| Head | Value |\n| Alpha | Beta |\n',
    );
  });

  testWidgets('quoted CSV clipboard paste handles commas and new rows', (
    tester,
  ) async {
    clipboard = '"Alpha, one","Beta"\n"Gamma","Delta"';
    await open(tester, table);
    final editor = tester.state<RichTableEditorState>(
      find.byType(RichTableEditor),
    );
    await tester.tap(cell(1, 0));
    await editor.pasteGrid();
    await tester.pumpAndSettle();
    expect(
      body,
      '| A | B |\n| --- | --- |\n| Alpha, one | Beta |\n| Gamma | Delta |\n',
    );
  });
  testWidgets('CSV paste respects quoted newlines and tabs inside comma fields', (
    tester,
  ) async {
    clipboard = '"Alpha\tone, line 1\nline 2","Beta"\n"Gamma","Delta"';
    await open(tester, table);
    final editor = tester.state<RichTableEditorState>(
      find.byType(RichTableEditor),
    );
    await tester.tap(cell(1, 0));
    await editor.pasteGrid();
    await tester.pumpAndSettle();
    expect(
      body,
      '| A | B |\n| --- | --- |\n| Alpha\tone, line 1<br>line 2 | Beta |\n| Gamma | Delta |\n',
    );
    expect(
      tester.widget<TextField>(cell(1, 0)).controller!.text,
      'Alpha\tone, line 1<br>line 2',
    );
  });
  testWidgets(
    'pending paste cannot follow focus to another cell or survive a later edit',
    (tester) async {
      await open(tester, table);
      await tester.tap(cell(1, 0));
      pending = Completer<String?>();
      await key(tester, LogicalKeyboardKey.keyV, control: true);
      await tester.tap(cell(1, 1));
      pending!.complete('X\tY');
      await tester.pumpAndSettle();
      expect(body, table);
      pending = Completer<String?>();
      await key(tester, LogicalKeyboardKey.keyV, control: true);
      await tester.enterText(cell(1, 1), 'New');
      await tester.pumpAndSettle();
      pending!.complete('Old\tPaste');
      await tester.pumpAndSettle();
      expect(body, table.replaceFirst('Two', 'New'));
    },
  );
  testWidgets(
    'multiline CRLF paste beside an equation preserves math and exact undo',
    (tester) async {
      const source = 'Before\r\n\r\nValue \$x\$ tail\r\n\r\nAfter ^stable';
      await open(tester, source);
      await tester.tap(field(' tail'));
      tester.widget<TextField>(field(' tail')).controller!.selection =
          const TextSelection.collapsed(offset: 5);
      clipboard = '\n\nNew paragraph';
      await key(tester, LogicalKeyboardKey.keyV, control: true);
      expect(body, source.replaceFirst(' tail', ' tail\r\n\r\nNew paragraph'));
      expect(field('New paragraph'), findsOneWidget);
      expect(
        tester.widget<TextField>(field('New paragraph')).focusNode!.hasFocus,
        isTrue,
      );
      await key(tester, LogicalKeyboardKey.keyZ, control: true);
      expect(body, source);
    },
  );
  testWidgets(
    'replacing equal newline counts still separates pasted paragraphs',
    (tester) async {
      const source = 'Alpha\nBeta\nGamma';
      await open(tester, source);
      await tester.tap(field(source));
      tester.widget<TextField>(field(source)).controller!.selection =
          const TextSelection(baseOffset: 0, extentOffset: source.length);
      clipboard = 'One\n\nTwo';
      await key(tester, LogicalKeyboardKey.keyV, control: true);
      expect(body, clipboard);
      expect(field('One'), findsOneWidget);
      expect(field('Two'), findsOneWidget);
    },
  );
  testWidgets(
    'replacing a soft line with whitespace creates a real paragraph boundary',
    (tester) async {
      const source = 'Alpha\nBeta\nGamma';
      await open(tester, source);
      await tester.tap(field(source));
      tester.widget<TextField>(field(source)).controller!.selection =
          const TextSelection(baseOffset: 6, extentOffset: 10);
      clipboard = ' ';
      await key(tester, LogicalKeyboardKey.keyV, control: true);
      expect(body, 'Alpha\n \nGamma');
      expect(field('Alpha'), findsOneWidget);
      expect(field('Gamma'), findsOneWidget);
      await key(tester, LogicalKeyboardKey.keyZ, control: true);
      expect(body, source);
    },
  );
  testWidgets(
    'prose menu paste uses multiline projection and failures preserve the note',
    (tester) async {
      clipboard = 'One\n\nTwo';
      await open(tester, 'Original');
      await tester.tap(field('Original'));
      tester.widget<TextField>(field('Original')).controller!.selection =
          const TextSelection(baseOffset: 0, extentOffset: 8);
      await tester.pumpAndSettle();
      final editable = tester.state<EditableTextState>(
        find.descendant(
          of: field('Original'),
          matching: find.byType(EditableText),
        ),
      );
      final toolbar =
          tester.widget<TextField>(field('Original')).contextMenuBuilder!(
                tester.element(field('Original')),
                editable,
              )
              as AdaptiveTextSelectionToolbar;
      toolbar.buttonItems!
          .firstWhere((item) => item.type == ContextMenuButtonType.paste)
          .onPressed!();
      await tester.pumpAndSettle();
      expect(body, clipboard);
      expect(field('Two'), findsOneWidget);
      clipboardFails = true;
      await key(tester, LogicalKeyboardKey.keyV, control: true);
      expect(body, clipboard);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('delayed prose paste preserves newer typing and changed focus', (
    tester,
  ) async {
    await open(tester, 'Original\n\nAfter');
    await tester.tap(field('Original'));
    pending = Completer<String?>();
    await key(tester, LogicalKeyboardKey.keyV, control: true);
    await tester.enterText(field('Original'), 'Edited');
    await tester.pumpAndSettle();
    pending!.complete('old\n\npaste');
    await tester.pumpAndSettle();
    expect(body, 'Edited\n\nAfter');
    pending = Completer<String?>();
    await key(tester, LogicalKeyboardKey.keyV, control: true);
    await tester.tap(field('After'));
    pending!.complete('stale');
    await tester.pumpAndSettle();
    expect(body, 'Edited\n\nAfter');
  });
  testWidgets('collapsed prose paste respects the selected typing style', (
    tester,
  ) async {
    await open(tester, 'First');
    await tester.tap(field('First'));
    tester.widget<TextField>(field('First')).controller!.selection =
        const TextSelection.collapsed(offset: 5);
    await key(tester, LogicalKeyboardKey.keyB, control: true);
    clipboard = 'added';
    await key(tester, LogicalKeyboardKey.keyV, control: true);
    expect(body, 'First**added**');
    await key(tester, LogicalKeyboardKey.keyZ, control: true);
    expect(body, 'First');
  });
  testWidgets(
    'prose paste inherits formatting and respects an explicit formatting exit',
    (tester) async {
      const source = '**First**';
      await open(tester, source);
      await tester.tap(field('First'));
      tester.widget<TextField>(field('First')).controller!.selection =
          const TextSelection.collapsed(offset: 5);
      clipboard = 'added';
      await key(tester, LogicalKeyboardKey.keyV, control: true);
      expect(body, '**Firstadded**');
      await key(tester, LogicalKeyboardKey.keyZ, control: true);
      expect(body, source);
      await key(tester, LogicalKeyboardKey.arrowRight);
      await key(tester, LogicalKeyboardKey.keyV, control: true);
      expect(body, '**First**added');
      await key(tester, LogicalKeyboardKey.keyZ, control: true);
      expect(body, source);
    },
  );
  for (final selected in [false, true]) {
    testWidgets(
      'multiline prose paste reprojects blocks and undoes (selected=$selected)',
      (tester) async {
        const source = 'Before **kept**\n\nAlpha Omega\n\nAfter ^stable';
        await open(tester, source);
        await tester.tap(field('Alpha Omega'));
        tester.widget<TextField>(field('Alpha Omega')).controller!.selection =
            TextSelection(baseOffset: 6, extentOffset: selected ? 11 : 6);
        clipboard = 'first\n\nsecond\n\n';
        await key(tester, LogicalKeyboardKey.keyV, control: true);
        final expected =
            'Before **kept**\n\nAlpha first\n\nsecond\n\n${selected ? '' : 'Omega'}\n\nAfter ^stable';
        expect(body, expected);
        expect(field('Alpha first'), findsOneWidget);
        expect(field('second'), findsOneWidget);
        await key(tester, LogicalKeyboardKey.keyZ, control: true);
        expect(body, source);
      },
    );
  }
}
