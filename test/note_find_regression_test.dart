import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/note_find_index.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';

void main() {
  test('cached Unicode queries retain exact ranges after cache eviction', () {
    final source = List.generate(
      9000,
      (i) => '**Straße $i 😀**\r\n\r\n',
    ).join();
    final index = NoteFindIndex(source, rich: true);
    for (var pass = 0; pass < 2; pass++) {
      final matches = index.matches('strasse');
      expect(matches, hasLength(9000));
      expect(
        matches.every((m) => source.substring(m.start, m.end) == 'Straße'),
        isTrue,
      );
      expect(index.matches('s'), hasLength(9000)); // never half of ß
      expect(index.matches('😀'), hasLength(9000));
    }
    final replaced = index.replace(
      index.matches('strasse').take(1).toList(),
      'Road',
    );
    expect(replaced.startsWith('**Road 0 😀**'), isTrue);
    final updated = NoteFindIndex(replaced, rich: true);
    expect(updated.matches('strasse'), hasLength(8999));
    expect(updated.matches('road'), hasLength(1));
  });
  test(
    'reference label replacement preserves multiline destination and title',
    () {
      const source =
          '[Guide][api]\r\n\r\n[api]:\r\n/docs\r\n"Manual\r\ncontinued"\r\n';
      final index = NoteFindIndex(source, rich: true);
      expect(index.referenceDefinitions, {'api': '/docs'});
      expect(
        index.replace(index.matches('Guide'), 'Handbook'),
        '[Handbook][api]\r\n\r\n[api]:\r\n/docs\r\n"Manual\r\ncontinued"\r\n',
      );
      final matches = index.matches('Manual\r\ncontinued');
      expect(matches, hasLength(1));
      expect(
        index.replace(matches, 'Updated'),
        '[Guide][api]\r\n\r\n[api]:\r\n/docs\r\n"Updated"\r\n',
      );
    },
  );

  test('visible phrases cross marks without touching unrelated source', () {
    const source = '# Heading\r\n\r\nA **red** fox and tail.\r\n';
    final index = NoteFindIndex(source, rich: true);
    final matches = index.matches('red fox');
    expect(matches, hasLength(1));
    final next = index.replace(matches, 'blue bird');
    expect(next.startsWith('# Heading\r\n\r\nA '), isTrue);
    expect(next.endsWith(' and tail.\r\n'), isTrue);
    expect(InlineProjection(next).text, contains('A blue bird and tail.'));
  });
  test('repeated label replacement preserves link and wiki targets', () {
    const source = '[cat](https://cat.test) and [[cat]] and **cat cat**';
    final index = NoteFindIndex(source, rich: true);
    expect(index.matches('cat'), hasLength(4));
    expect(
      index.replace(index.matches('cat'), 'dog'),
      '[dog](https://cat.test) and [[cat|dog]] and **dog dog**',
    );
    expect(NoteFindIndex(source, rich: false).matches('cat'), hasLength(5));
  });
  test(
    'whole words respect Unicode letters, marks, numbers and scope edges',
    () {
      const source = 'cat catch écat caté cat_ cat2 猫cat cat\u0301 cat';
      final index = NoteFindIndex(source, rich: false);
      expect(index.matches('cat', wholeWord: true), hasLength(2));
      expect(index.matches('cat', wholeWord: true, start: 4, end: 7), isEmpty);
      final unicode = NoteFindIndex('été étéx xété été', rich: false);
      expect(unicode.matches('été', wholeWord: true), hasLength(2));
    },
  );
  test('case-insensitive Find uses full Unicode folds and exact ranges', () {
    const source = 'Straße STRASSE ΟΣΥΣΣΕΥΣ οσυσσευσ Kelvin K';
    final index = NoteFindIndex(source, rich: false);
    final latin = index.matches('strasse');
    expect(latin, hasLength(2));
    expect(latin.map((match) => source.substring(match.start, match.end)), [
      'Straße',
      'STRASSE',
    ]);
    final greek = index.matches('οσυσσευσ');
    expect(greek, hasLength(2));
    expect(greek.map((match) => source.substring(match.start, match.end)), [
      'ΟΣΥΣΣΕΥΣ',
      'οσυσσευσ',
    ]);
    final kelvin = index.matches('k', wholeWord: true);
    expect(kelvin, hasLength(1));
    expect(source.substring(kelvin.single.start, kelvin.single.end), 'K');
    expect(NoteFindIndex('ß', rich: false).matches('s'), isEmpty);
  });
  test('folded Rich replacement preserves formatting and source spelling', () {
    const source = '**Straße** and [STRASSE](https://example.test)';
    final index = NoteFindIndex(source, rich: true);
    expect(
      index.replace(index.matches('strasse'), 'route'),
      '**route** and [route](https://example.test)',
    );
    expect(
      index.replace(index.matches('STRASSE'), 'ß'),
      '**ß** and [ß](https://example.test)',
    );
  });
  test('literal replacement handles dollars, slashes, empty text and CRLF', () {
    const source = 'cat\r\ncat\r\n';
    final index = NoteFindIndex(source, rich: false);
    expect(
      index.replace(index.matches('cat'), r'$1\path'),
      '\$1\\path\r\n\$1\\path\r\n',
    );
    expect(index.replace(index.matches('cat'), ''), '\r\n\r\n');
  });
  test('source-only syntax remains available and rich labels omit targets', () {
    const source =
        '---\r\nx: secret\r\n---\r\n# **Visible** [label](hidden)\r\n';
    final rich = NoteFindIndex(source, rich: true);
    expect(rich.matches('hidden'), isEmpty);
    expect(rich.matches('secret'), hasLength(1));
    expect(rich.matches('Visible label'), hasLength(1));
    expect(
      rich.selectedText(source.indexOf('Visible'), source.indexOf('(hidden)')),
      'Visible label',
    );
  });
  test(
    'rich punctuation stays literal and cannot reinterpret earlier markers',
    () {
      const source = '**prefix cat cat';
      final index = NoteFindIndex(source, rich: true);
      final next = index.replace(index.matches('cat'), '**');
      expect(InlineProjection(next).text, '**prefix ** **');
      final styled = NoteFindIndex('**cat cat** and [cat](target)', rich: true);
      final replaced = styled.replace(styled.matches('cat'), r'$1*\path');
      expect(
        InlineProjection(replaced).text,
        r'$1*\path $1*\path and $1*\path',
      );
      expect(replaced, contains('(target)'));
    },
  );
  test('escaped closing marks remain literal inside existing formatting', () {
    final projection = InlineProjection(r'**a\** b** and _c\_ d_');
    expect(projection.text, 'a** b and c_ d');
    expect(projection.styles.first, contains('bold'));
    expect(projection.styles.last, contains('italic'));
    expect(InlineProjection(r'**a\\** tail').text, 'a\\ tail');
  });
  test('unsupported literal code replacement refuses the entire batch', () {
    final index = NoteFindIndex('cat and `cat`', rich: true);
    expect(
      () => index.replace(index.matches('cat'), '`'),
      throwsFormatException,
    );
    expect(index.source, 'cat and `cat`');
  });
  test(
    'large Source replace-all preserves every untouched line and empty batches',
    () {
      final source = List.filled(10000, 'cat untouched\r\n').join();
      final index = NoteFindIndex(source, rich: false);
      expect(
        index.replace(index.matches('cat'), 'kitten'),
        List.filled(10000, 'kitten untouched\r\n').join(),
      );
      expect(index.replace(index.matches('missing'), 'kitten'), source);
    },
  );
  test(
    'many Rich blocks retain formatting and gaps during one replacement',
    () {
      final source = List.filled(
        1000,
        '# Title\r\n\r\n**cat** tail\r\n\r\n',
      ).join();
      final index = NoteFindIndex(source, rich: true);
      expect(
        index.replace(index.matches('cat'), 'kitten'),
        List.filled(1000, '# Title\r\n\r\n**kitten** tail\r\n\r\n').join(),
      );
    },
  );

  late String body;
  Future<void> open(
    WidgetTester tester,
    String text, {
    String mode = 'write',
    String noteId = 'find-regression',
  }) async {
    body = text;
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => NoteEditor(
              noteId: noteId,
              title: 'Find',
              body: body,
              initialViewState: {'mode': mode},
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

  Finder getQuery() => find.widgetWithText(TextField, 'Find in this note');
  TextEditingController sourceController(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(const ValueKey('note-body')))
      .controller!;
  Future<void> search(WidgetTester tester, String query) async {
    await tester.tap(find.byTooltip('Find in note · Ctrl+F'));
    await tester.pumpAndSettle();
    await tester.enterText(getQuery(), query);
    await tester.pumpAndSettle();
  }

  Future<void> replaceWith(WidgetTester tester, String text) async {
    await tester.enterText(
      find.byKey(const ValueKey('note-replacement')),
      text,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Rich find keeps mode, selection and keyboard navigation', (
    tester,
  ) async {
    await open(tester, '**red** fox and red fox', mode: 'rich');
    await search(tester, 'red fox');
    expect(find.byKey(const ValueKey('note-body')), findsNothing);
    expect(find.text('2 matches'), findsOneWidget);
    expect(tester.widget<TextField>(getQuery()).focusNode!.hasFocus, isTrue);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('(2 of 2)'), findsOneWidget);
    expect(tester.widget<TextField>(getQuery()).focusNode!.hasFocus, isTrue);
    await tester.tap(find.byTooltip('Previous match'));
    await tester.pumpAndSettle();
    expect(find.text('(1 of 2)'), findsOneWidget);
    await replaceWith(tester, 'blue bird');
    await tester.tap(find.text('Replace all'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Apply '));
    await tester.pumpAndSettle();
    expect(InlineProjection(body).text, 'blue bird and blue bird');
    await tester.tap(find.byTooltip('Undo · Ctrl+Z'));
    await tester.pumpAndSettle();
    expect(body, '**red** fox and red fox');
    expect(find.text('2 matches'), findsOneWidget);
    await tester.tap(find.byTooltip('Redo · Ctrl+Shift+Z'));
    await tester.pumpAndSettle();
    expect(find.text('0 matches'), findsOneWidget);
  });
  testWidgets('single Replace validates whole-word and scope membership', (
    tester,
  ) async {
    await open(tester, 'cat catch [cat and cat] cat');
    final controller = sourceController(tester);
    controller.selection = const TextSelection(
      baseOffset: 10,
      extentOffset: 23,
    );
    await search(tester, 'cat');
    await tester.tap(find.byTooltip('Find in selection · Alt+S'));
    await tester.tap(find.byTooltip('Match whole word · Alt+W'));
    await tester.pumpAndSettle();
    expect(find.text('2 matches'), findsOneWidget);
    // A stale/arbitrary selection outside the captured scope must not be edited.
    controller.selection = const TextSelection(baseOffset: 4, extentOffset: 7);
    await replaceWith(tester, 'dog');
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(body, 'cat catch [dog and cat] cat');
  });
  testWidgets('scope translates through edits before it and undo', (
    tester,
  ) async {
    await open(tester, 'outer [cat and cat] outer cat');
    final controller = sourceController(tester);
    controller.selection = const TextSelection(baseOffset: 6, extentOffset: 19);
    await search(tester, 'cat');
    await tester.tap(find.byTooltip('Find in selection · Alt+S'));
    await tester.pumpAndSettle();
    controller.value = TextEditingValue(
      text: 'PREFIX ${controller.text}',
      selection: const TextSelection.collapsed(offset: 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 matches'), findsOneWidget);
    await replaceWith(tester, 'kitten');
    await tester.tap(find.text('Replace all in selection'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Apply '));
    await tester.pumpAndSettle();
    expect(body, 'PREFIX outer [kitten and kitten] outer cat');
    await tester.tap(find.byTooltip('Undo · Ctrl+Z'));
    await tester.pumpAndSettle();
    expect(body, 'PREFIX outer [cat and cat] outer cat');
    expect(find.text('2 matches'), findsOneWidget);
  });
  testWidgets('counts refresh after source edits and previous on no matches', (
    tester,
  ) async {
    await open(tester, 'cat cat');
    await search(tester, 'cat');
    await tester.enterText(find.byKey(const ValueKey('note-body')), 'dog');
    await tester.pumpAndSettle();
    expect(find.text('0 matches'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous match'));
    await tester.pumpAndSettle();
    expect(find.text('0 matches'), findsOneWidget);
    await tester.tap(find.byTooltip('Undo · Ctrl+Z'));
    await tester.pumpAndSettle();
    expect(body, 'cat cat');
    expect(find.text('2 matches'), findsOneWidget);
  });
  testWidgets('switching Rich to Source refreshes markup matches', (
    tester,
  ) async {
    await open(tester, '[label](hidden)', mode: 'rich');
    await search(tester, 'hidden');
    expect(find.text('0 matches'), findsOneWidget);
    await tester.tap(find.text('Source'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note-body')), findsOneWidget);
    expect(find.text('1 match'), findsOneWidget);
    await tester.tap(find.text('Rich'));
    await tester.pumpAndSettle();
    expect(find.text('0 matches'), findsOneWidget);
  });
  testWidgets('Read find stays in Read and preserves source on undo', (
    tester,
  ) async {
    await open(tester, '**cat** [cat](target)', mode: 'read');
    await search(tester, 'cat');
    expect(find.byKey(const ValueKey('note-preview')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-body')), findsNothing);
    await replaceWith(tester, 'dog');
    await tester.tap(find.text('Replace all'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Apply '));
    await tester.pumpAndSettle();
    expect(body, '**dog** [dog](target)');
    await tester.tap(getQuery());
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    // Undo in Find belongs to that input; document Undo is an explicit action.
    expect(body, '**dog** [dog](target)');
    await tester.tap(find.byKey(const ValueKey('note-document-undo')));
    await tester.pumpAndSettle();
    expect(body, '**cat** [cat](target)');
  });
  testWidgets('reopening Find retains captured scope and query', (
    tester,
  ) async {
    await open(tester, 'cat [cat and cat] cat');
    sourceController(tester).selection = const TextSelection(
      baseOffset: 4,
      extentOffset: 17,
    );
    await search(tester, 'cat');
    await tester.tap(find.byTooltip('Find in selection · Alt+S'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Find in note · Ctrl+F'));
    await tester.pumpAndSettle();
    expect(find.text('In Selection'), findsOneWidget);
    expect(find.text('2 matches'), findsOneWidget);
    expect(tester.widget<TextField>(getQuery()).controller!.text, 'cat');
  });
  testWidgets(
    'unsafe Rich replacement reports failure without a partial edit',
    (tester) async {
      await open(tester, 'cat and `cat`', mode: 'rich');
      await search(tester, 'cat');
      await replaceWith(tester, '`');
      await tester.tap(find.text('Replace all'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Apply '));
      await tester.pumpAndSettle();
      expect(body, 'cat and `cat`');
      expect(
        find.text(
          'Could not safely replace this markup. Try editing it in Source.',
        ),
        findsOneWidget,
      );
      expect(find.text('2 matches'), findsOneWidget);
    },
  );
  testWidgets(
    'replacement containing the query advances past a rewritten wiki label',
    (tester) async {
      await open(tester, '[[cat]] and cat', mode: 'rich');
      await search(tester, 'cat');
      await replaceWith(tester, 'catcat');
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      expect(body, '[[cat|catcat]] and cat');
      expect(find.text('(3 of 3)'), findsOneWidget);
    },
  );
  testWidgets('Split uses source matching and preserves mode', (tester) async {
    await open(tester, '[cat](cat)', mode: 'split');
    await search(tester, 'cat');
    expect(find.text('2 matches'), findsOneWidget);
    expect(find.byKey(const ValueKey('note-preview')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-body')), findsOneWidget);
  });
  testWidgets(
    'Source navigation scrolls to distant matches while Find keeps focus',
    (tester) async {
      await open(
        tester,
        '${List.filled(250, 'An ordinary line.').join('\n')}\nTARGET',
      );
      await search(tester, 'TARGET');
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('note-body')),
      );
      expect(field.scrollController!.offset, greaterThan(0));
      expect(field.controller!.selection.textInside(body), 'TARGET');
      expect(tester.widget<TextField>(getQuery()).focusNode!.hasFocus, isTrue);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(getQuery()).focusNode!.hasFocus, isTrue);
    },
  );
  testWidgets('switching notes clears old counts before an empty new query', (
    tester,
  ) async {
    await open(tester, 'cat cat');
    await search(tester, 'cat');
    expect(find.text('2 matches'), findsOneWidget);
    await open(tester, 'dog', noteId: 'second-note');
    await tester.tap(find.byTooltip('Find in note · Ctrl+F'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(getQuery()).controller!.text, isEmpty);
    expect(find.text('0 matches'), findsOneWidget);
    expect(find.text('2 matches'), findsNothing);
    expect(body, 'dog');
  });
}
