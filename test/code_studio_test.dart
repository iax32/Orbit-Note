import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/rich/code_editing.dart';
import 'package:orbit_note/features/notes/rich/code_workspace.dart';
import 'package:orbit_note/features/notes/rich/code_surface.dart';

TextEditingValue value(String text, int base, int extent) => TextEditingValue(
  text: text,
  selection: TextSelection(baseOffset: base, extentOffset: extent),
);
final draft = find.byKey(const ValueKey('code-workspace-editor'));
void main() {
  test('HTML and CSS block comments round-trip whole lines with CRLF', () {
    for (final language in ['html', 'css']) {
      final original = value('before\r\n  item\r\n  next\r\nafter', 24, 8);
      final commented = toggleCodeComments(original, language);
      expect(commented.text.startsWith('before\r\n  '), isTrue);
      expect(commented.text.endsWith('\r\nafter'), isTrue);
      final restored = toggleCodeComments(commented, language);
      expect(restored.text, original.text);
      expect(
        restored.selection.baseOffset > restored.selection.extentOffset,
        isTrue,
      );
    }
    expect(
      () => toggleCodeComments(value('a /* nested */ b', 0, 15), 'css'),
      throwsFormatException,
    );
    expect(
      () => toggleCodeComments(value('x--y', 0, 4), 'html'),
      throwsFormatException,
    );
    expect(supportsCodeComments('json'), isFalse);
  });
  test('selection wrappers keep literal UTF16 text and reversed range', () {
    final wrapped = wrapCodeSelection(value('a😀bc', 4, 1), '[', ']');
    expect(wrapped.text, 'a[😀b]c');
    expect(
      wrapped.selection,
      const TextSelection(baseOffset: 5, extentOffset: 2),
    );
    final empty = wrapCodeSelection(value('', 0, 0), '{', '}');
    expect(empty.text, '{}');
    expect(empty.selection.extentOffset, 1);
  });
  test(
    'delete line groups and whitespace cleanup preserve unaffected endings',
    () {
      expect(deleteCodeLines(value('a\r\nb\r\nc', 3, 6)).text, 'a\r\nc');
      expect(deleteCodeLines(value('a\r\nb', 3, 3)).text, 'a');
      expect(deleteCodeLines(value('a\r\n', 3, 3)).text, 'a');
      expect(deleteCodeLines(value('one', 0, 3)).text, '');
      final cleaned = trimCodeWhitespace(value(' a \r\n\tb\t\n c ', 12, 0));
      expect(cleaned.text, ' a\r\n\tb\n c');
      expect(cleaned.selection.baseOffset, cleaned.text.length);
      final composing = value(
        'x ',
        0,
        0,
      ).copyWith(composing: const TextRange(start: 0, end: 1));
      expect(trimCodeWhitespace(composing), composing);
      expect(deleteCodeLines(composing), composing);
      expect(wrapCodeSelection(composing, '(', ')'), composing);
    },
  );
  Future<void> open(
    WidgetTester tester, {
    String language = 'css',
    String text = 'one\ntwo\nthree',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CodeWorkspace(
          code: text,
          language: language,
          canApply: () => true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> menu(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip('Code actions'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'original comparison preserves draft, selection and undo across layouts',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester);
      await tester.enterText(draft, 'changed\nsecond');
      final controller = tester.widget<TextField>(draft).controller!;
      controller.selection = const TextSelection(
        baseOffset: 10,
        extentOffset: 2,
      );
      await tester.tap(find.byTooltip('Compare original and draft'));
      await tester.pumpAndSettle();
      final original = tester.widget<TextField>(
        find.byKey(const ValueKey('code-workspace-original')),
      );
      expect(original.readOnly, isTrue);
      expect(original.controller!.text, 'one\ntwo\nthree');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 10, extentOffset: 2),
      );
      tester.view.physicalSize = const Size(390, 650);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(draft).controller, same(controller));
      expect(controller.text, 'changed\nsecond');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 10, extentOffset: 2),
      );
      await tester.ensureVisible(find.byTooltip('Undo draft'));
      await tester.tap(find.byTooltip('Undo draft'));
      await tester.pumpAndSettle();
      expect(controller.text, 'one\ntwo\nthree');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'gutter selects correct logical lines after scrolling and wrapping',
    (tester) async {
      await open(
        tester,
        text: List.generate(100, (i) => 'line $i').join('\r\n'),
      );
      final controller = tester.widget<TextField>(draft).controller!;
      final editable = find.descendant(
        of: draft,
        matching: find.byType(EditableText),
      );
      final render = tester.state<EditableTextState>(editable).renderEditable;
      final line = codeLines(controller.text)[2];
      final rect = render.getLocalRectForCaret(
        TextPosition(offset: line.start),
      );
      final surface = find.byType(CodeSurface);
      await tester.tapAt(
        Offset(
          tester.getTopLeft(surface).dx + 12,
          render.localToGlobal(rect.center).dy,
        ),
      );
      await tester.pump();
      expect(
        controller.selection,
        TextSelection(baseOffset: line.start, extentOffset: line.end),
      );
      controller.selection = TextSelection.collapsed(
        offset: codeLines(controller.text)[80].start,
      );
      await tester.pumpAndSettle();
      expect(
        render
            .getLocalRectForCaret(
              TextPosition(offset: controller.selection.start),
            )
            .top,
        lessThan(render.size.height),
      );
      await tester.tap(find.text('Wrap lines'));
      await tester.pumpAndSettle();
      await tester.enterText(draft, '${'long wrapped content ' * 20}\nnext');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('cleanup, wrapping and reset participate in draft history', (
    tester,
  ) async {
    await open(tester, text: 'one  \r\ntwo\t');
    final controller = tester.widget<TextField>(draft).controller!;
    await menu(tester, 'Trim trailing whitespace');
    expect(controller.text, 'one\r\ntwo');
    controller.selection = const TextSelection(baseOffset: 3, extentOffset: 0);
    await menu(tester, 'Wrap selection in ( )');
    expect(controller.text, '(one)\r\ntwo');
    await menu(tester, 'Reset draft to original');
    expect(controller.text, 'one  \r\ntwo\t');
    await tester.tap(find.byTooltip('Undo draft'));
    await tester.pumpAndSettle();
    expect(controller.text, '(one)\r\ntwo');
    expect(tester.takeException(), isNull);
  });
  testWidgets('nested comments reject without losing source or comparison', (
    tester,
  ) async {
    await open(tester, text: 'a /* existing */ b');
    await menu(tester, 'Toggle comments · Ctrl+/');
    expect(
      tester.widget<TextField>(draft).controller!.text,
      'a /* existing */ b',
    );
    expect(find.textContaining('manual editing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
