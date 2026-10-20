import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/features/notes/go_to_line_dialog.dart';
import 'package:orbit_note/features/notes/markdown_editing.dart';
import 'package:orbit_note/features/notes/note_editor.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('pasteboard'),
          (_) async => null,
        );
  });
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createTestApp(Widget child) {
    return MaterialApp(
      theme: orbitDarkTheme(),
      home: Scaffold(body: child),
    );
  }

  group('MarkdownEditing Line and Column Calculations', () {
    test('lineAndColumnOf calculates 1-indexed line and column accurately', () {
      const text = 'First line\nSecond line\nThird line';

      // Start of text
      final p0 = MarkdownEditing.lineAndColumnOf(text, 0);
      expect(p0.line, 1);
      expect(p0.column, 1);

      // Middle of first line ('First ') -> offset 6
      final p6 = MarkdownEditing.lineAndColumnOf(text, 6);
      expect(p6.line, 1);
      expect(p6.column, 7);

      // Start of second line (after '\n' at 10) -> offset 11
      final p11 = MarkdownEditing.lineAndColumnOf(text, 11);
      expect(p11.line, 2);
      expect(p11.column, 1);

      // Third line
      final pThird = MarkdownEditing.lineAndColumnOf(text, 23);
      expect(pThird.line, 3);
      expect(pThird.column, 1);

      // Out of bounds clamped
      final pClamped = MarkdownEditing.lineAndColumnOf(text, 999);
      expect(pClamped.line, 3);
      expect(pClamped.column, 11);

      // Empty text
      final pEmpty = MarkdownEditing.lineAndColumnOf('', 0);
      expect(pEmpty.line, 1);
      expect(pEmpty.column, 1);
    });

    test('totalLinesOf counts lines accurately', () {
      expect(MarkdownEditing.totalLinesOf(''), 1);
      expect(MarkdownEditing.totalLinesOf('single line'), 1);
      expect(MarkdownEditing.totalLinesOf('line 1\nline 2'), 2);
      expect(MarkdownEditing.totalLinesOf('line 1\nline 2\nline 3\n'), 4);
    });

    test('offsetOfLine maps line and column to offset correctly', () {
      const text = 'First line\nSecond line\nThird line';

      // Line 1, Col 1 -> 0
      expect(MarkdownEditing.offsetOfLine(text, 1, 1), 0);

      // Line 1, Col 6 -> 5
      expect(MarkdownEditing.offsetOfLine(text, 1, 6), 5);

      // Line 2, Col 1 -> 11
      expect(MarkdownEditing.offsetOfLine(text, 2, 1), 11);

      // Line 3, Col 1 -> 23
      expect(MarkdownEditing.offsetOfLine(text, 3, 1), 23);

      // Clamping line > totalLines
      expect(MarkdownEditing.offsetOfLine(text, 10, 1), 23);

      // Clamping column > line length
      expect(MarkdownEditing.offsetOfLine(text, 1, 99), 10);
    });
  });

  group('MarkdownEditing Auto-Pairing and Delimiter Wrapping', () {
    test('wrapSelection wraps active selection with delimiters', () {
      const text = 'Hello world today';
      final val = const TextEditingValue(
        text: text,
        selection: TextSelection(baseOffset: 6, extentOffset: 11), // 'world'
      );

      // Brackets
      final wrappedParen = MarkdownEditing.wrapSelection(val, '(', ')');
      expect(wrappedParen.text, 'Hello (world) today');
      expect(wrappedParen.selection.textInside(wrappedParen.text), 'world');

      // Quotes
      final wrappedQuotes = MarkdownEditing.wrapSelection(val, '"', '"');
      expect(wrappedQuotes.text, 'Hello "world" today');

      // Markdown formatting: bold/italic asterisks
      final wrappedStars = MarkdownEditing.wrapSelection(val, '**', '**');
      expect(wrappedStars.text, 'Hello **world** today');

      // Math inline
      final wrappedMath = MarkdownEditing.wrapSelection(val, r'$', r'$');
      expect(wrappedMath.text, r'Hello $world$ today');
    });

    test(
      'handleAutoWrapOrPair handles selection wrapping for brackets and quotes',
      () {
        const text = 'Hello universe';
        final val = const TextEditingValue(
          text: text,
          selection: TextSelection(
            baseOffset: 6,
            extentOffset: 14,
          ), // 'universe'
        );

        final wrappedBracket = MarkdownEditing.handleAutoWrapOrPair(val, '[');
        expect(wrappedBracket?.text, 'Hello [universe]');

        final wrappedBrace = MarkdownEditing.handleAutoWrapOrPair(val, '{');
        expect(wrappedBrace?.text, 'Hello {universe}');

        final wrappedBacktick = MarkdownEditing.handleAutoWrapOrPair(val, '`');
        expect(wrappedBacktick?.text, 'Hello `universe`');

        final wrappedTilde = MarkdownEditing.handleAutoWrapOrPair(val, '~');
        expect(wrappedTilde?.text, 'Hello ~universe~');
      },
    );

    test(
      'handleAutoWrapOrPair auto-pairs at collapsed caret and steps over closing',
      () {
        // 1. Auto-pair open paren
        final v1 = const TextEditingValue(
          text: 'hello ',
          selection: TextSelection.collapsed(offset: 6),
        );
        final paired = MarkdownEditing.handleAutoWrapOrPair(v1, '(');
        expect(paired?.text, 'hello ()');
        expect(paired?.selection.baseOffset, 7); // caret inside: hello (|)

        // 2. Step-over closing paren
        final stepOver = MarkdownEditing.handleAutoWrapOrPair(paired!, ')');
        expect(stepOver?.text, 'hello ()');
        expect(stepOver?.selection.baseOffset, 8); // stepped over: hello ()|

        // 3. Auto-pair double quotes
        final quotePaired = MarkdownEditing.handleAutoWrapOrPair(v1, '"');
        expect(quotePaired?.text, 'hello ""');
        expect(quotePaired?.selection.baseOffset, 7);

        // 4. Apostrophe in word: don't auto-pair single quote if preceded by letter
        final vWord = const TextEditingValue(
          text: 'don',
          selection: TextSelection.collapsed(offset: 3),
        );
        final apostrophe = MarkdownEditing.handleAutoWrapOrPair(vWord, "'");
        expect(apostrophe, isNull);
      },
    );

    test(
      'handleBackspacePair deletes both matching brackets when caret is in between',
      () {
        // Inside ()
        final vParen = const TextEditingValue(
          text: 'test () end',
          selection: TextSelection.collapsed(offset: 6), // between ( and )
        );
        final bsParen = MarkdownEditing.handleBackspacePair(vParen);
        expect(bsParen?.text, 'test  end');
        expect(bsParen?.selection.baseOffset, 5);

        // Inside []
        final vSquare = const TextEditingValue(
          text: 'test [] end',
          selection: TextSelection.collapsed(offset: 6),
        );
        final bsSquare = MarkdownEditing.handleBackspacePair(vSquare);
        expect(bsSquare?.text, 'test  end');

        // Inside ""
        final vQuote = const TextEditingValue(
          text: 'test "" end',
          selection: TextSelection.collapsed(offset: 6),
        );
        final bsQuote = MarkdownEditing.handleBackspacePair(vQuote);
        expect(bsQuote?.text, 'test  end');

        // Inside $$
        final vMath = const TextEditingValue(
          text: 'test \$\$ end',
          selection: TextSelection.collapsed(offset: 6),
        );
        final bsMath = MarkdownEditing.handleBackspacePair(vMath);
        expect(bsMath?.text, 'test  end');

        // Not an empty pair
        final vNormal = const TextEditingValue(
          text: 'test (a) end',
          selection: TextSelection.collapsed(offset: 7), // after 'a'
        );
        expect(MarkdownEditing.handleBackspacePair(vNormal), isNull);
      },
    );
  });

  group('MarkdownEditing Line Movements and Duplication', () {
    test(
      'moveLine moves current line up and down preserving relative cursor',
      () {
        const text = 'Line Alpha\nLine Beta\nLine Gamma';

        // Caret on Line Beta at offset 16 (after 'Line B')
        final vBeta = const TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: 17),
        );

        // Move Up -> Beta becomes line 1, Alpha becomes line 2
        final up = MarkdownEditing.moveLine(vBeta, up: true);
        expect(up, isNotNull);
        expect(up!.text, 'Line Beta\nLine Alpha\nLine Gamma');
        expect(up.selection.baseOffset, 6); // same column on Line Beta

        // Move Up again when already at top -> returns null
        final upTop = MarkdownEditing.moveLine(up, up: true);
        expect(upTop, isNull);

        // Move Down -> Beta moves back to line 2
        final down = MarkdownEditing.moveLine(up, up: false);
        expect(down, isNotNull);
        expect(down!.text, 'Line Alpha\nLine Beta\nLine Gamma');
        expect(down.selection.baseOffset, 17);

        // Move Down again -> Beta becomes line 3, Gamma becomes line 2
        final down2 = MarkdownEditing.moveLine(down, up: false);
        expect(down2, isNotNull);
        expect(down2!.text, 'Line Alpha\nLine Gamma\nLine Beta');

        // Move Down when already at bottom -> returns null
        final downBottom = MarkdownEditing.moveLine(down2, up: false);
        expect(downBottom, isNull);
      },
    );

    test(
      'duplicateLine duplicates active line immediately below with cursor at same column',
      () {
        const text = 'Header\nTask item\nFooter';

        // Caret in 'Task item' at offset 11 ('Task ')
        final vTask = const TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: 12),
        );

        final dup = MarkdownEditing.duplicateLine(vTask);
        expect(dup, isNotNull);
        expect(dup!.text, 'Header\nTask item\nTask item\nFooter');
        expect(dup.selection.baseOffset, 12 + 'Task item\n'.length);
      },
    );
  });

  group('GoToLineDialog Widget Tests', () {
    testWidgets(
      'renders GoToLineDialog and returns parsed line:column on submit',
      (tester) async {
        ({int line, int column})? result;

        await tester.pumpWidget(
          createTestApp(
            Builder(
              builder: (context) {
                return ElevatedButton(
                  key: const ValueKey('open-dialog-btn'),
                  onPressed: () async {
                    result = await showGoToLineDialog(
                      context,
                      totalLines: 100,
                      currentLine: 15,
                      currentColumn: 3,
                    );
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        );

        // Open dialog
        await tester.tap(find.byKey(const ValueKey('open-dialog-btn')));
        await tester.pumpAndSettle();

        expect(find.text('Go to Line'), findsOneWidget);
        expect(find.text('Lines 1 to 100'), findsOneWidget);

        // Enter '42:8'
        final input = find.byKey(const ValueKey('go-to-line-input'));
        expect(input, findsOneWidget);

        await tester.enterText(input, '42:8');
        await tester.pump();

        expect(find.text('Jump to Ln 42, Col 8'), findsOneWidget);

        // Submit
        await tester.tap(find.byKey(const ValueKey('go-to-line-submit')));
        await tester.pumpAndSettle();

        expect(result, isNotNull);
        expect(result!.line, 42);
        expect(result!.column, 8);
      },
    );

    testWidgets('cancelling GoToLineDialog returns null', (tester) async {
      ({int line, int column})? result = (line: 99, column: 99);

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                key: const ValueKey('open-dialog-btn'),
                onPressed: () async {
                  result = await showGoToLineDialog(
                    context,
                    totalLines: 50,
                    currentLine: 1,
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('open-dialog-btn')));
      await tester.pumpAndSettle();

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });

  group('NoteEditor Line Indicator Tests', () {
    testWidgets(
      'renders note-line-col-indicator and updates live with cursor position',
      (tester) async {
        String currentBody = 'Alpha line\nBeta line\nGamma line';

        await tester.pumpWidget(
          createTestApp(
            NoteEditor(
              noteId: 'test-note-1',
              title: 'Test Document',
              body: currentBody,
              onTitleChanged: (_) {},
              onBodyChanged: (v) => currentBody = v,
              linkTargets: const [],
              onOpenObject: (_) {},
              initialViewState: const {'mode': 'write'},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find line/col indicator in footer
        final indicatorFinder = find.byKey(
          const ValueKey('note-line-col-indicator'),
        );
        expect(indicatorFinder, findsOneWidget);
        expect(find.textContaining('Ln 1, Col 1'), findsOneWidget);

        // Find body TextField and tap it to move cursor
        final bodyField = find.byKey(const ValueKey('note-body'));
        expect(bodyField, findsOneWidget);

        // Move cursor to Beta line (offset 15)
        await tester.enterText(
          bodyField,
          'Alpha line\nBeta modified\nGamma line',
        );
        await tester.pumpAndSettle();

        // Scrolling uses the normal editor viewport, without a progress stripe.
        expect(
          find.byKey(const ValueKey('note-reading-progress-bar')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'renders note-line-col-indicator and updates live in rich mode',
      (tester) async {
        String currentBody =
            'First line in block one\n\nSecond block line here';

        await tester.pumpWidget(
          createTestApp(
            NoteEditor(
              noteId: 'test-note-rich',
              title: 'Rich Test Note',
              body: currentBody,
              onTitleChanged: (_) {},
              onBodyChanged: (v) => currentBody = v,
              linkTargets: const [],
              onOpenObject: (_) {},
              initialViewState: const {'mode': 'rich'},
            ),
          ),
        );
        await tester.pump();

        // Footer indicator exists
        expect(
          find.byKey(const ValueKey('note-line-col-indicator')),
          findsOneWidget,
        );

        // textFields: 0 is title, 1 is block 1, 2 is block 2
        final textFields = find.byType(TextField);
        expect(textFields, findsAtLeastNWidgets(3));

        // Tap the second block text field (which is on line 3)
        await tester.tap(textFields.at(2));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // The footer indicator should show Ln 3
        expect(find.textContaining('Ln 3'), findsOneWidget);
      },
    );

    testWidgets('Go to Line navigates to target line in rich mode', (
      tester,
    ) async {
      String currentBody =
          'Block one heading\n\nBlock two content\n\nBlock three footer';

      await tester.pumpWidget(
        createTestApp(
          NoteEditor(
            noteId: 'test-note-rich-goto',
            title: 'Rich Go To Note',
            body: currentBody,
            onTitleChanged: (_) {},
            onBodyChanged: (v) => currentBody = v,
            linkTargets: const [],
            onOpenObject: (_) {},
            initialViewState: const {'mode': 'rich'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap footer indicator to open Go to Line dialog
      await tester.tap(find.byKey(const ValueKey('note-line-col-indicator')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('go-to-line-input')), findsOneWidget);

      // Enter line 5 (in block 3)
      await tester.enterText(
        find.byKey(const ValueKey('go-to-line-input')),
        '5:1',
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('go-to-line-submit')));
      await tester.pumpAndSettle();

      // Dialog is dismissed and Ln 5 is reflected
      expect(find.byKey(const ValueKey('go-to-line-input')), findsNothing);
      expect(find.textContaining('Ln 5'), findsOneWidget);
    });

    testWidgets('smart URL paste wraps selected text in source mode', (
      tester,
    ) async {
      String currentBody = 'Visit the website for details.';

      var clipboardText = 'https://flutter.dev';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': clipboardText};
          }
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String? ?? '';
            return null;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      await tester.pumpWidget(
        createTestApp(
          NoteEditor(
            noteId: 'test-smart-paste',
            title: 'Smart Paste Note',
            body: currentBody,
            onTitleChanged: (_) {},
            onBodyChanged: (v) => currentBody = v,
            linkTargets: const [],
            onOpenObject: (_) {},
            initialViewState: const {
              'mode': 'write',
              'base': 10,
              'extent': 17, // 'website' selected
            },
          ),
        ),
      );
      await tester.pump();

      // Focus body field
      final bodyField = find.byKey(const ValueKey('note-body'));
      await tester.tap(bodyField);
      await tester.pump(const Duration(milliseconds: 50));

      // Ensure selection is 'website' (10 to 17)
      final editable = tester.state<EditableTextState>(
        find.descendant(of: bodyField, matching: find.byType(EditableText)),
      );
      editable.updateEditingValue(
        const TextEditingValue(
          text: 'Visit the website for details.',
          selection: TextSelection(baseOffset: 10, extentOffset: 17),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Send Ctrl+V
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        currentBody,
        'Visit the [website](https://flutter.dev) for details.',
      );
    });

    testWidgets(
      'smart URL paste in rich mode wraps text and preserves markdown structure',
      (tester) async {
        String currentBody = '## Useful website reference';

        var clipboardText = 'https://dart.dev';
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall call) async {
            if (call.method == 'Clipboard.getData') {
              return <String, dynamic>{'text': clipboardText};
            }
            if (call.method == 'Clipboard.setData') {
              clipboardText = (call.arguments as Map)['text'] as String? ?? '';
              return null;
            }
            return null;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });

        await tester.pumpWidget(
          createTestApp(
            NoteEditor(
              noteId: 'test-rich-paste',
              title: 'Rich Paste Note',
              body: currentBody,
              onTitleChanged: (_) {},
              onBodyChanged: (v) => currentBody = v,
              linkTargets: const [],
              onOpenObject: (_) {},
              initialViewState: const {'mode': 'rich'},
            ),
          ),
        );
        await tester.pump();

        // Focus block TextField (index 1, as index 0 is note title)
        final field = find.byType(TextField).at(1);
        await tester.tap(field);
        await tester.pump(const Duration(milliseconds: 50));

        final editable = tester.state<EditableTextState>(
          find.descendant(of: field, matching: find.byType(EditableText)),
        );
        // Select 'website' (index 7 to 14 of visible 'Useful website reference')
        editable.updateEditingValue(
          TextEditingValue(
            text: editable.textEditingValue.text,
            selection: const TextSelection(baseOffset: 7, extentOffset: 14),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        // Send Ctrl+V
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));

        expect(currentBody, '## Useful [website](https://dart.dev) reference');
      },
    );
    testWidgets(
      'mode switch from source to rich preserves caret offset and position',
      (tester) async {
        String currentBody =
            'Paragraph one here.\n\nParagraph two with specific target text.\n\nParagraph three.';
        Map<String, dynamic> viewState = {'mode': 'write'};

        await tester.pumpWidget(
          createTestApp(
            NoteEditor(
              noteId: 'test-mode-switch',
              title: 'Mode Switch Note',
              body: currentBody,
              onTitleChanged: (_) {},
              onBodyChanged: (v) => currentBody = v,
              onViewStateChanged: (v) => viewState = v,
              linkTargets: const [],
              onOpenObject: (_) {},
              initialViewState: viewState,
            ),
          ),
        );
        await tester.pump();

        // Find the source TextField and set cursor in second paragraph
        final targetOffset = currentBody.indexOf('specific target');
        final bodyField = find.byKey(const ValueKey('note-body'));
        final controller = tester.widget<TextField>(bodyField).controller!;
        controller.selection = TextSelection.collapsed(offset: targetOffset);
        await tester.pump();

        // Switch to rich mode via mode selector
        await tester.tap(find.text('Rich').first);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // View state is updated to rich mode and docOffset is preserved
        expect(viewState['mode'], 'rich');
        expect(viewState['extent'], targetOffset);
      },
    );
  });
}
