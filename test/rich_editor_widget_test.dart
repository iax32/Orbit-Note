import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/rich/note_math.dart';
import 'package:orbit_note/features/notes/rich/code_block.dart';

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
      expect(find.byType(NoteMath), findsNWidgets(3));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(NoteMath).at(1));
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
      await tester.enterText(field(''), 'Done');
      await tester.pumpAndSettle();
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
      expect(find.byType(NoteMath), findsNWidgets(2));
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
    expect(find.byType(NoteMath), findsNWidgets(formulas.length));
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
      await tester.tap(field(''));
      await tester.enterText(field(''), ' after');
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
