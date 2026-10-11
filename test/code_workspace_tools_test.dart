import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/rich/code_editing.dart';
import 'package:orbit_note/features/notes/rich/code_workspace.dart';

TextEditingValue selected(String text, int base, int extent) =>
    TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: base, extentOffset: extent),
    );
Finder get source => find.byKey(const ValueKey('code-workspace-editor'));
void main() {
  test(
    'moving CRLF line groups preserves reversed selection and untouched content',
    () {
      final value = selected('first\r\nsecond\r\nthird', 15, 7);
      final next = moveCodeLines(value, down: false);
      expect(next.text, 'second\r\nfirst\r\nthird');
      expect(
        next.selection,
        const TextSelection(baseOffset: 8, extentOffset: 0),
      );
      expect(moveCodeLines(next, down: true), value);
      expect(moveCodeLines(selected('one', 0, 0), down: true).text, 'one');
    },
  );
  test('line move preserves UTF16 columns and final unterminated line', () {
    final next = moveCodeLines(selected('a\nété😀', 7, 7), down: false);
    expect(next.text, 'été😀\na');
    expect(next.selection.extentOffset, 5);
    expect(
      moveCodeLines(selected('one\ntwo\nthree', 3, 0), down: true).text,
      'two\none\nthree',
    );
  });
  test('duplicate final and selected CRLF lines preserves direction', () {
    final next = duplicateCodeLines(selected('a\r\nb', 4, 4));
    expect(next.text, 'a\r\nb\r\nb');
    expect(next.selection.extentOffset, 7);
    final group = duplicateCodeLines(selected('a\r\nb\r\nc', 6, 0));
    expect(group.text, 'a\r\nb\r\na\r\nb\r\nc');
    expect(
      group.selection,
      const TextSelection(baseOffset: 12, extentOffset: 6),
    );
  });
  test(
    'comments preserve indentation, blank lines and unsupported languages',
    () {
      final value = selected('  one();\r\n\r\n\ttwo();', 22, 0);
      // Use valid original source offsets, including a reverse selection.
      final valid = value.copyWith(
        selection: TextSelection(
          baseOffset: value.text.length,
          extentOffset: 0,
        ),
      );
      final next = toggleCodeComments(valid, 'cpp');
      expect(next.text, '  // one();\r\n\r\n\t// two();');
      expect(toggleCodeComments(next, 'cpp'), valid);
      expect(toggleCodeComments(valid, 'json'), valid);
      expect(
        toggleCodeComments(selected('x\ny', 0, 3), 'python').text,
        '# x\n# y',
      );
    },
  );
  test(
    'configured indentation and smart Enter retain CRLF and composition',
    () {
      final value = selected('  {}\r\nnext', 3, 3);
      final next = newlineCode(value, unit: '    ');
      expect(next.text, '  {\r\n      \r\n  }\r\nnext');
      expect(next.selection.extentOffset, 11);
      expect(indentCode(selected('x\ny', 0, 3), unit: '\t').text, '\tx\n\ty');
      final composing = value.copyWith(
        composing: const TextRange(start: 0, end: 2),
      );
      expect(newlineCode(composing), composing);
      expect(duplicateCodeLines(composing), composing);
      expect(moveCodeLines(composing, down: true), composing);
      expect(toggleCodeComments(composing, 'js'), composing);
      expect(indentCode(selected('x', 0, 0), unit: 'invalid').text, 'x');
    },
  );

  Future<void> open(
    WidgetTester tester, {
    String text = 'foo Foo food\r\nfoo',
    bool readOnly = false,
    bool Function()? canApply,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CodeWorkspace(
          code: text,
          language: 'javascript',
          readOnly: readOnly,
          canApply: canApply ?? () => true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'find/replace uses whole words, case and Unicode source offsets with undo',
    (tester) async {
      await open(tester, text: 'İ Straße straße food foo');
      await tester.enterText(
        find.widgetWithText(TextField, 'Find in code'),
        'STRASSE',
      );
      await tester.tap(find.text('Next match'));
      await tester.pump();
      final editor = tester.widget<TextField>(source).controller!;
      expect(
        editor.selection,
        const TextSelection(baseOffset: 2, extentOffset: 8),
      );
      await tester.tap(find.text('Replace'));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextField, 'Replace with'),
        'street',
      );
      await tester.tap(find.text('Replace all'));
      await tester.pump(const Duration(seconds: 1));
      expect(editor.text, 'İ street street food foo');
      await tester.tap(find.byTooltip('Undo draft'));
      await tester.pump();
      expect(editor.text, 'İ Straße straße food foo');
      await tester.enterText(
        find.widgetWithText(TextField, 'Find in code'),
        'foo',
      );
      await tester.tap(find.text('Whole word'));
      await tester.tap(find.text('Next match'));
      await tester.pump();
      expect(
        editor.text.substring(editor.selection.start, editor.selection.end),
        'foo',
      );
      expect(editor.selection.start, 21);
      await tester.tap(find.text('Previous match'));
      await tester.pump();
      expect(editor.selection.start, 21);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('code shortcuts move, duplicate, comment and go to line', (
    tester,
  ) async {
    await open(tester, text: 'first\nsecond');
    final editor = tester.widget<TextField>(source).controller!;
    await tester.tap(source);
    editor.selection = const TextSelection.collapsed(offset: 6);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(editor.text, 'second\nfirst');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(editor.text, '// second\n// second\nfirst');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(editor.text, '// second\nfirst');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyY);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(editor.text, '// second\n// second\nfirst');
    await tester.tap(find.byTooltip('Code actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go to line · Ctrl+G'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '3');
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(editor.selection.extentOffset, 20);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'read-only code keeps navigation and forbids mutation shortcuts',
    (tester) async {
      await open(tester, text: 'a\nb', readOnly: true);
      await tester.tap(source);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(tester.widget<TextField>(source).controller!.text, 'a\nb');
      expect(find.text('Apply to note'), findsNothing);
      expect(find.text('Replace'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'narrow enlarged code workspace remains scrollable and error-free',
    (tester) async {
      tester.view.physicalSize = const Size(390, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: CodeWorkspace(
            code: 'x',
            language: 'javascript',
            canApply: () => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Apply to note'));
      await tester.tap(find.text('Apply to note'));
      await tester.pumpAndSettle();
      expect(find.textContaining('The source changed.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
