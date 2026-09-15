import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/features/notes/rich/equation_editor.dart';
import 'package:orbit_note/features/notes/rich/structured_math_editor.dart';
import 'package:orbit_note/features/notes/rich/latex_catalog.dart';

void main() {
  late String source;
  Future<void> open(
    WidgetTester tester,
    String initial, {
    bool display = true,
  }) async {
    source = initial;
    await tester.pumpWidget(
      MaterialApp(
        theme: orbitDarkTheme(),
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, update) => EditableMathExpression(
                source: source,
                display: display,
                onChanged: (s) => update(() => source = s),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String text) => find.byWidgetPredicate(
    (w) => w is TextField && w.controller?.text == text,
  );
  Finder slot(String label) => find.descendant(
    of: find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == label,
    ),
    matching: find.byType(TextField),
  );
  Future<void> type(WidgetTester tester, String text) async {
    final target = find.byWidgetPredicate(
      (w) => w is TextField && w.focusNode?.hasFocus == true,
    );
    final controller = tester.widget<TextField>(target).controller!;
    final selection = controller.selection;
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: controller.text.replaceRange(
          selection.start,
          selection.end,
          text,
        ),
        selection: TextSelection.collapsed(
          offset: selection.start + text.length,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> key(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool shift = false,
  }) async {
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'roots, powers, indices and limits edit directly without a dialog',
    (tester) async {
      await open(tester, r'\sqrt[3]{a}+x_1^2+\sum_{i=0}^{n}i');
      await tester.enterText(slot('Inside root'), 'b+1');
      await tester.pumpAndSettle();
      await tester.enterText(slot('Root degree'), '4');
      await tester.pumpAndSettle();
      await tester.enterText(slot('Exponent'), '5');
      await tester.pumpAndSettle();
      await tester.enterText(slot('Subscript'), 'k');
      await tester.pumpAndSettle();
      await tester.enterText(slot('Lower limit'), 'j=1');
      await tester.pumpAndSettle();
      expect(source, r'\sqrt[4]{b+1}+x_{k}^{5}+\sum_{j=1}^{n}i');
      expect(find.byType(EquationEditor), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fraction arrows and Tab move between real numerator and denominator',
    (tester) async {
      await open(tester, r'\frac{a}{b}');
      await tester.tap(field('a'));
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(tester.widget<TextField>(field('b')).focusNode!.hasFocus, isTrue);
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(tester.widget<TextField>(field('a')).focusNode!.hasFocus, isTrue);
      await key(tester, LogicalKeyboardKey.tab);
      expect(tester.widget<TextField>(field('b')).focusNode!.hasFocus, isTrue);
      await key(tester, LogicalKeyboardKey.tab, shift: true);
      expect(tester.widget<TextField>(field('a')).focusNode!.hasFocus, isTrue);
      expect(source, r'\frac{a}{b}');
    },
  );

  testWidgets('typing slash makes a fraction and selects the denominator', (
    tester,
  ) async {
    await open(tester, 'x');
    await tester.tap(field('x'));
    tester.widget<TextField>(field('x')).controller!.selection =
        const TextSelection.collapsed(offset: 1);
    await type(tester, '/');
    expect(source, r'\frac{x}{\square}');
    expect(tester.widget<TextField>(field('□')).focusNode!.hasFocus, isTrue);
    await type(tester, '2');
    expect(source, r'\frac{x}{2}');
    await key(tester, LogicalKeyboardKey.arrowRight);
    await type(tester, '+y');
    expect(source, r'\frac{x}{2}+y');
  });

  testWidgets(
    'power shortcut and root toolbar wrap the selected operand only',
    (tester) async {
      await open(tester, 'a+x');
      await tester.tap(field('a+x'));
      tester.widget<TextField>(field('a+x')).controller!.selection =
          const TextSelection.collapsed(offset: 3);
      await type(tester, '^');
      expect(source, r'a+{x}^{\square}');
      await type(tester, '2');
      expect(source, r'a+{x}^{2}');
      await tester.tap(field('x'));
      tester.widget<TextField>(field('x')).controller!.selection =
          const TextSelection(baseOffset: 0, extentOffset: 1);
      await tester.tap(find.text('Symbols & templates'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('latex-search')),
        'Square root',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey(r'latex-entry-\sqrt{\square}')),
      );
      await tester.pumpAndSettle();
      expect(source, r'a+{\sqrt{x}}^{2}');
      expect(find.byType(EquationEditor), findsNothing);
    },
  );

  testWidgets(
    'nested fractions edit one leaf without rewriting surrounding TeX',
    (tester) async {
      await open(tester, r'\dfrac  {a+\frac{b}{c}}{\sqrt{d}}+\unknown{keep}');
      await tester.enterText(field('c'), '42');
      await tester.pumpAndSettle();
      expect(source, r'\dfrac  {a+\frac{b}{42}}{\sqrt{d}}+\unknown{keep}');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Greek symbols insert at the selected caret and keep typing focus',
    (tester) async {
      await open(tester, 'x+y');
      await tester.tap(field('x+y'));
      tester.widget<TextField>(field('x+y')).controller!.selection =
          const TextSelection(baseOffset: 2, extentOffset: 3);
      await tester.tap(find.text('Symbols & templates'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('latex-search')),
        'alpha',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey(r'latex-entry-\alpha')));
      await tester.pumpAndSettle();
      expect(source, r'x+\alpha ');
      expect(field('x+α'), findsOneWidget);
      await type(tester, 'z');
      expect(source, r'x+\alpha z');
    },
  );

  testWidgets('composition changes keep the IME range until committed', (
    tester,
  ) async {
    await open(tester, 'x');
    await tester.tap(field('x'));
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'xあ',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 1, end: 2),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<TextField>(field('xあ')).controller!.value.composing,
      const TextRange(start: 1, end: 2),
    );
    expect(source, 'xあ');
  });

  testWidgets(
    'successive input events before a frame splice against the latest equation',
    (tester) async {
      await open(tester, r'\frac{a}{b}+\sqrt{x}');
      await tester.tap(field('b'));
      for (final text in ['20', '200', '2000']) {
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          ),
        );
      }
      await tester.pumpAndSettle();
      expect(source, r'\frac{a}{2000}+\sqrt{x}');
      expect(field('2000'), findsOneWidget);
    },
  );

  testWidgets(
    'full symbol table stays open without moving or covering the equation',
    (tester) async {
      await open(tester, r'\frac{a}{b}');
      final before = tester.getRect(field('a'));
      await tester.tap(find.text('Symbols & templates'));
      await tester.pumpAndSettle();
      expect(
        find.text('${latexCatalog.length} entries · click to insert'),
        findsOneWidget,
      );
      expect(tester.getRect(field('a')), before);
      expect(
        tester
            .getRect(find.byKey(const ValueKey('latex-catalog-panel')))
            .overlaps(before),
        isFalse,
      );
      await tester.tap(field('b'));
      await tester.pumpAndSettle();
      await tester.enterText(field('b'), '42');
      await tester.pumpAndSettle();
      expect(source, r'\frac{a}{42}');
      expect(find.byKey(const ValueKey('latex-search')), findsOneWidget);
      await key(tester, LogicalKeyboardKey.escape);
      expect(find.byKey(const ValueKey('latex-search')), findsNothing);
    },
  );

  testWidgets(
    'symbol insertion keeps a middle caret instead of jumping to the end',
    (tester) async {
      await open(tester, 'x+y');
      await tester.tap(field('x+y'));
      tester.widget<TextField>(field('x+y')).controller!.selection =
          const TextSelection.collapsed(offset: 1);
      await tester.tap(find.text('Symbols & templates'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('latex-search')),
        'alpha',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey(r'latex-entry-\alpha')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(field('xα+y'))
            .controller!
            .selection
            .extentOffset,
        2,
      );
      await type(tester, 'z');
      expect(source, r'x\alpha z+y');
    },
  );

  testWidgets(
    'Backspace on an empty denominator keeps the numerator and trailing equation',
    (tester) async {
      await open(tester, r'\frac{x+1}{}+y');
      await tester.tap(find.byKey(const ValueKey('frac-den-0')));
      await key(tester, LogicalKeyboardKey.backspace);
      expect(source, 'x+1+y');
      await type(tester, 'z');
      expect(source, 'x+1z+y');
    },
  );

  testWidgets(
    'Ctrl+A Delete selects and clears the whole equation into an editable slot',
    (tester) async {
      await open(tester, r'\frac{a}{b}+x^2');
      await tester.tap(field('b'));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await key(tester, LogicalKeyboardKey.delete);
      expect(source, r'\square');
      await type(tester, 'x+2');
      expect(source, 'x+2');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ordinary arrow symbols stay editable when typing after them', (
    tester,
  ) async {
    await open(tester, r'x\leftarrow y');
    expect(field('x←y'), findsOneWidget);
    await tester.tap(field('x←y'));
    tester.widget<TextField>(field('x←y')).controller!.selection =
        const TextSelection.collapsed(offset: 3);
    await type(tester, '+z');
    expect(source, r'x\leftarrow y+z');
    expect(field('x←y+z'), findsOneWidget);
  });

  testWidgets('copy and paste a selected whole fraction keeps standard LaTeX', (
    tester,
  ) async {
    var clipboard = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.getData') return {'text': clipboard};
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    Future<void> control(LogicalKeyboardKey value) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(value);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    const original = r'\frac{a}{b}+x^2';
    await open(tester, original);
    await tester.tap(field('b'));
    await control(LogicalKeyboardKey.keyA);
    await control(LogicalKeyboardKey.keyC);
    expect(clipboard, original);
    await control(LogicalKeyboardKey.keyX);
    expect(clipboard, original);
    expect(source, r'\square');
    await control(LogicalKeyboardKey.keyA);
    await control(LogicalKeyboardKey.keyV);
    expect(source, original);
    expect(field('b'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed clipboard cut preserves the selected whole equation', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'clipboard-unavailable');
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    const original = r'\frac{a}{b}+x^2';
    await open(tester, original);
    await tester.tap(field('b'));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(source, original);
    expect(field('b'), findsOneWidget);
    expect(
      find.text('Could not copy the equation. It has been kept.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'narrow inline and block math remain editable at larger text size',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final display in [true, false]) {
        await open(
          tester,
          r'\frac{a+\sqrt{x}}{b}+\int_0^1 x^2dx',
          display: display,
        );
        await tester.tap(field('b'));
        await tester.pumpAndSettle();
        await tester.enterText(field('b'), '20');
        await tester.pumpAndSettle();
        expect(source, contains('{20}'));
        expect(tester.takeException(), isNull);
      }
    },
  );
}
