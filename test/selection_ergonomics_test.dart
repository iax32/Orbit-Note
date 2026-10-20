import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/markdown_clipboard.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';

void main() {
  String plain = '', html = '', body = '';
  Completer<void>? gate;
  setUp(() {
    plain = html = '';
    gate = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        await gate?.future;
        return {
          'text': call.arguments.toString().contains('text/html')
              ? html
              : plain,
        };
      }
      if (call.method == 'Clipboard.setData') {
        plain = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(const MethodChannel('pasteboard'), (
      call,
    ) async {
      if (call.method == 'html') return html.isEmpty ? null : html;
      return null;
    });
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(const MethodChannel('pasteboard'), null);
  });
  Finder field(String value) => find.byWidgetPredicate(
    (w) => w is TextField && w.controller?.text == value,
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
              noteId: 'selection-note',
              title: 'Selection',
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

  Future<void> command(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool shift = false,
  }) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  RichMarkdownEditorState editor(WidgetTester tester) =>
      tester.state<RichMarkdownEditorState>(find.byType(RichMarkdownEditor));

  for (final count in [60, 360]) {
    testWidgets(
      'scrolling a selected passage in the complete editor keeps copy, paste and undo accurate in $count paragraphs',
      (tester) async {
        final original = List.generate(
          count,
          (i) => 'Line $i: Notes with emoji 🎮 and useful details.',
        ).join('\n\n');
        await open(tester, original);
        final first = field('Line 0: Notes with emoji 🎮 and useful details.');
        final viewport = tester.getRect(find.byType(RichMarkdownEditor));
        final start = tester.getTopLeft(first) + const Offset(24, 12);
        final drag = await tester.startGesture(
          start,
          kind: PointerDeviceKind.mouse,
        );
        await drag.moveTo(start + const Offset(100, 0));
        await tester.pumpAndSettle();
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: start + const Offset(100, 0),
            scrollDelta: const Offset(0, 600),
            kind: PointerDeviceKind.mouse,
          ),
        );
        await tester.pumpAndSettle();
        final rich = editor(tester);
        final range = rich.currentDocumentSelection;
        expect(rich.scroll.offset, 600);
        expect(range.end, greaterThan(original.indexOf('Line 5:')));
        // Native drag events continue arriving at the paragraph we started in.
        await drag.moveTo(viewport.center);
        await tester.pumpAndSettle();
        await drag.up();
        await tester.pumpAndSettle();
        final selected = rich.currentDocumentSelection;
        expect(rich.scroll.offset, 600);
        await command(tester, LogicalKeyboardKey.keyC);
        expect(plain, original.substring(selected.start, selected.end));
        expect(body, original);
        expect(rich.scroll.offset, 600);
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: viewport.center,
            scrollDelta: const Offset(0, 500),
            kind: PointerDeviceKind.mouse,
          ),
        );
        await tester.pumpAndSettle();
        expect(rich.scroll.offset, 1100);
        expect(rich.currentDocumentSelection, selected);
        plain = 'Replacement';
        await command(tester, LogicalKeyboardKey.keyV);
        expect(
          body,
          original.replaceRange(selected.start, selected.end, 'Replacement'),
        );
        expect(rich.hasCrossDocumentSelection, isFalse);
        // Editing still reveals the actual insertion caret.
        final selectedField = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              (w.controller?.text.contains('Replacement') ?? false),
        );
        expect(tester.getRect(selectedField).overlaps(viewport), isTrue);
        await command(tester, LogicalKeyboardKey.keyZ);
        expect(body, original);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('HTML code preserves indentation, blank lines and literal entities', () {
    final value = htmlToMarkdown(
      '<pre><code>if (x &lt; 2) {\n    call();\n\n\n    again();\n}</code></pre>',
    );
    expect(value, '```\nif (x < 2) {\n    call();\n\n\n    again();\n}\n```');
    expect(htmlToMarkdown('<p><code>a  b `c`</code></p>'), '`` a  b `c` ``');
    expect(
      htmlToMarkdown('<pre><code>```\nx\n```</code></pre>'),
      '````\n```\nx\n```\n````',
    );
  });
  test('Windows HTML payload extracts UTF-8 fragment without transport headers', () {
    const fragment = '<p>😀 <strong>Café</strong></p>';
    const prefix = '<html><body>outside<!--StartFragment-->';
    const suffix = '<!--EndFragment-->outside</body></html>';
    var header =
        'Version:1.0\r\nStartHTML:0000000000\r\nEndHTML:0000000000\r\nStartFragment:0000000000\r\nEndFragment:0000000000\r\n';
    final start = utf8.encode(header).length;
    final fragmentStart = start + utf8.encode(prefix).length;
    final fragmentEnd = fragmentStart + utf8.encode(fragment).length;
    header = header
        .replaceFirst(
          'StartHTML:0000000000',
          'StartHTML:${start.toString().padLeft(10, '0')}',
        )
        .replaceFirst(
          'EndHTML:0000000000',
          'EndHTML:${(fragmentEnd + utf8.encode(suffix).length).toString().padLeft(10, '0')}',
        )
        .replaceFirst(
          'StartFragment:0000000000',
          'StartFragment:${fragmentStart.toString().padLeft(10, '0')}',
        )
        .replaceFirst(
          'EndFragment:0000000000',
          'EndFragment:${fragmentEnd.toString().padLeft(10, '0')}',
        );
    expect(
      clipboardHtmlFragment('$header$prefix$fragment$suffix\x00'),
      fragment,
    );
    expect(
      clipboardHtmlFragment(
        'Version:1.0\r\nStartFragment:99999\r\n<html><!--StartFragment-->$fragment<!--EndFragment--></html>',
      ),
      fragment,
    );
  });
  testWidgets(
    'literal HTML plain text is not mistaken for rich clipboard data',
    (tester) async {
      await tester.pumpWidget(const SizedBox());
      plain = html = '<div>Authored source</div>';
      expect(await readMarkdownClipboard(), plain);
    },
  );
  testWidgets('cross-paragraph paste replaces the actual range with one undo', (
    tester,
  ) async {
    const source = 'Alpha text\n\nMiddle text\n\nOmega text';
    await open(tester, source);
    editor(tester).selectDocumentRange(5, source.indexOf('Omega') + 5);
    await tester.pumpAndSettle();
    plain = 'NEW';
    await command(tester, LogicalKeyboardKey.keyV);
    expect(body, 'AlphaNEW text');
    await command(tester, LogicalKeyboardKey.keyZ);
    expect(body, source);
  });
  testWidgets('cross-paragraph paste balances remaining inline formatting', (
    tester,
  ) async {
    const source = '**Alpha**\n\nMiddle\n\n**Omega**';
    await open(tester, source);
    editor(tester).selectDocumentRange(4, source.indexOf('Omega') + 3);
    await tester.pumpAndSettle();
    plain = 'X';
    await command(tester, LogicalKeyboardKey.keyV);
    expect(InlineProjection(body).text, 'AlXga');
    expect(body, '**Al**X**ga**');
  });
  testWidgets('range paste refuses delayed data after the range changes', (
    tester,
  ) async {
    const source = 'One\n\nTwo\n\nThree';
    await open(tester, source);
    editor(tester).selectDocumentRange(1, source.indexOf('Three'));
    await tester.pumpAndSettle();
    gate = Completer<void>();
    plain = 'stale';
    final pending = editor(tester).pasteDocumentSelection();
    editor(tester).clearCrossDocumentSelection();
    gate!.complete();
    await pending;
    await tester.pumpAndSettle();
    expect(body, source);
  });
  testWidgets(
    'range highlight retains the exact native editor state and geometry',
    (tester) async {
      const source = 'One paragraph\n\nTwo paragraph';
      await open(tester, source);
      await tester.tap(field('One paragraph'));
      await tester.pumpAndSettle();
      final before = tester.state<EditableTextState>(
        find.descendant(
          of: field('One paragraph'),
          matching: find.byType(EditableText),
        ),
      );
      final rect = tester.getRect(field('One paragraph'));
      editor(tester).selectDocumentRange(2, source.indexOf('Two') + 3);
      await tester.pumpAndSettle();
      final after = tester.state<EditableTextState>(
        find.descendant(
          of: field('One paragraph'),
          matching: find.byType(EditableText),
        ),
      );
      expect(identical(before, after), isTrue);
      expect(tester.getRect(field('One paragraph')), rect);
      await tester.tap(field('Two paragraph'));
      await tester.pumpAndSettle();
      expect(editor(tester).hasCrossDocumentSelection, isFalse);
    },
  );
  testWidgets(
    'plain paste ignores rich formatting while formatted paste lands at the inserted word',
    (tester) async {
      await open(tester, 'Hello world');
      await tester.tap(field('Hello world'));
      await tester.pumpAndSettle();
      final c = tester.widget<TextField>(field('Hello world')).controller!;
      c.selection = const TextSelection.collapsed(offset: 6);
      plain = 'bold';
      html = '<p><strong>bold</strong></p>';
      await command(tester, LogicalKeyboardKey.keyV);
      expect(body, 'Hello **bold**world');
      expect(
        tester
            .widget<TextField>(field('Hello boldworld'))
            .controller!
            .selection
            .extentOffset,
        10,
      );
      await command(tester, LogicalKeyboardKey.keyZ);
      await tester.tap(field('Hello world'));
      tester.widget<TextField>(field('Hello world')).controller!.selection =
          const TextSelection.collapsed(offset: 6);
      await command(tester, LogicalKeyboardKey.keyV, shift: true);
      expect(body, 'Hello boldworld');
    },
  );
  testWidgets('left/right collapse a cross-document range to its boundary', (
    tester,
  ) async {
    const source = 'One\n\nTwo\n\nThree';
    await open(tester, source);
    editor(tester).selectDocumentRange(1, source.indexOf('Three') + 2);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(editor(tester).hasCrossDocumentSelection, isFalse);
    expect(editor(tester).currentDocumentSelection.extentOffset, 1);
  });
  testWidgets('raw code paste keeps literal HTML and whitespace', (
    tester,
  ) async {
    await open(tester, '```cpp\nold\n```\n');
    await tester.tap(field('old'));
    await tester.pumpAndSettle();
    final c = tester.widget<TextField>(field('old')).controller!;
    c.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
    plain = '  <vector>\n    x;';
    html = '<p><strong>formatted</strong></p>';
    await command(tester, LogicalKeyboardKey.keyV);
    expect(body, contains('  <vector>\n    x;'));
  });

  testWidgets(
    'copy from partial formatted endpoints produces balanced Markdown',
    (tester) async {
      const source = '**Alpha**\n\nMiddle\n\n**Omega**';
      await open(tester, source);
      editor(tester).selectDocumentRange(4, source.indexOf('Omega') + 3);
      await tester.pumpAndSettle();
      await command(tester, LogicalKeyboardKey.keyC);
      expect(plain, '**pha**\n\nMiddle\n\n**Ome**');
      expect(body, source);
    },
  );
  testWidgets(
    'Source paste preserves authored HTML and plain paste does not create links',
    (tester) async {
      await open(tester, 'Original text');
      await tester.tap(find.text('Source'));
      await tester.pumpAndSettle();
      await tester.tap(field('Original text'));
      tester.widget<TextField>(field('Original text')).controller!.selection =
          const TextSelection(baseOffset: 0, extentOffset: 13);
      plain = '<div>  keep me</div>\n';
      html = '<p><strong>Rich content</strong></p>';
      await command(tester, LogicalKeyboardKey.keyV);
      expect(body, plain);
    },
  );
  testWidgets(
    'Windows provider can read rich data when Flutter only returns plain text',
    (tester) async {
      await tester.pumpWidget(const SizedBox());
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.getData') return {'text': 'plain'};
            return null;
          });
      html =
          'Version:1.0\r\nStartFragment:999999\r\n<html><!--StartFragment--><p><b>Native</b></p><!--EndFragment--></html>\x00';
      expect(await readMarkdownClipboard(), '**Native**');
    },
    skip: !Platform.isWindows,
  );
  test('HTML entities decode once inside copied code', () {
    expect(
      htmlToMarkdown('<pre><code>&amp;lt;  &amp;amp;</code></pre>'),
      '```\n&lt;  &amp;\n```',
    );
  });
}
