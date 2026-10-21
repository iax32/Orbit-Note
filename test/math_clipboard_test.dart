import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:orbit_note/domain/document_publication.dart';
import 'package:orbit_note/features/notes/math_clipboard.dart';
import 'package:orbit_note/features/notes/markdown_clipboard.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';
import 'package:orbit_note/features/notes/rich/note_math.dart';
import 'package:orbit_note/features/notes/rich/rich_math_block.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';

String katex(String tex, {bool display = false}) =>
    '${display ? '<span class="katex-display">' : ''}'
    '<span class="katex"><span class="katex-mathml"><math><semantics>'
    '<mrow><mi>duplicate accessibility text</mi></mrow>'
    '<annotation encoding="application/x-tex">$tex</annotation>'
    '</semantics></math></span>'
    '<span class="katex-html" aria-hidden="true">duplicate visual text</span>'
    '</span>${display ? '</span>' : ''}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'plain explanation imports inline and display equations as editable Markdown',
    () {
      const source = r'''## Derivation

For \(x > 0\), use **the identity**:
\[
\begin{aligned}
f(x) &= \frac{1}{2}x^2 \\
f'(x) &= x
\end{aligned}
\]
- Thus \(f'(2)=2\).
''';
      final result = normalizePastedMath(source);
      expect(result, contains(r'For $x > 0$, use **the identity**:'));
      expect(result, contains(r"- Thus $f'(2)=2$."));
      final document = MarkdownDocument.parse(result);
      expect(document.source, result);
      expect(
        document.blocks.where((b) => b.kind == MarkdownBlockKind.math),
        hasLength(1),
      );
      expect(result, contains(r'\begin{aligned}'));
      expect(result, contains(r"f'(x) &= x"));
      expect(normalizePastedMath(result), result);
    },
  );

  for (final source in [
    r'`\(literal\)` and ``\[literal\]``',
    '```latex\n\\[x\\]\n```',
    '~~~~tex\r\n\\(x\\)\r\n~~~~',
    '````markdown\n```\n\\[x\\]\n```\n````',
    '```tex\n\\[unclosed code\\]',
    'Intro\n\n```latex\n\\[x\\]\n```\nEnd',
    'Intro\n\n~~~\n\\(x\\)\n~~~',
    r'\\(escaped\\) and \\[escaped\\]',
    r'No closing \(x and \[y',
    r'Empty \( \) and \[ \]',
    r'Existing $\text{\(literal\)}$ and $$\text{\[literal\]}$$',
    r'Existing $\text{\(literal\)} \\$',
    r'`\(literal\)\`',
    '    \\(indented\\)\n\t\\[code\\]',
    r'[source]: path/\(literal\)',
    r'Price $5.00, another $10.00, ordinary [text] and (text).',
    r'[Source](images/\(literal\).png "title")',
    r'![Cover](images/\(literal\).png)',
    r'https://example.test/\(literal\) and <https://example.test/\[literal\]>',
  ]) {
    test('preserves literal or unsupported source: $source', () {
      expect(normalizePastedMath(source), source);
    });
  }

  test('escaped closing delimiter and Unicode survive without truncation', () {
    expect(
      normalizePastedMath(r'😀 \( \text{\\)} + α \) fin'),
      r'😀 $\text{\\)} + α$ fin',
    );
    expect(normalizePastedMath('\\(a\nb\\)'), '\\(a\nb\\)');
    expect(
      normalizePastedMath('Before \\[x\\] after'),
      'Before \n\n\$\$\nx\n\$\$\n\n after',
    );
  });

  test('currency never prevents importing an equation between prices', () {
    expect(
      normalizePastedMath(r'Pay $5 for \(x\), total $10.'),
      r'Pay $5 for $x$, total $10.',
    );
  });

  for (final display in [false, true]) {
    test(
      'KaTeX ${display ? 'display' : 'inline'} imports TeX exactly once',
      () {
        final result = htmlToMarkdown(
          '<p>Use ${katex(r'\frac{a}{b}', display: display)} now.</p>',
        );
        expect(
          result,
          contains(display ? '\$\$\n\\frac{a}{b}\n\$\$' : r'$\frac{a}{b}$'),
        );
        expect(RegExp(r'\\frac').allMatches(result), hasLength(1));
        expect(result, isNot(contains('duplicate')));
        expect(result, contains('Use'));
        expect(result, contains('now.'));
      },
    );
  }

  test(
    'display imports do not add blank paragraphs at existing boundaries',
    () {
      expect(
        normalizePastedMath('Before\n\n\\[x\\]\n\nAfter'),
        'Before\n\n\$\$\nx\n\$\$\n\nAfter',
      );
      expect(normalizePastedMath(r'\[x\]'), '\$\$\nx\n\$\$');
      expect(
        normalizePastedMath('Before\r\n\r\n\\[x\\]\r\n\r\nAfter'),
        'Before\r\n\r\n\$\$\nx\n\$\$\r\n\r\nAfter',
      );
    },
  );

  test(
    'table formula pipes and display math stay inside their original cell',
    () {
      final result = htmlToMarkdown(
        '<table><tr><th>Norm</th><th>Value</th></tr><tr><td>${katex('|x|', display: true)}</td><td>2</td></tr></table>',
      );
      expect(result, '| Norm | Value |\n| --- | --- |\n| \$\\|x\\|\$ | 2 |');
      final document = MarkdownDocument.parse(result);
      expect(
        document.blocks.where((block) => block.kind == MarkdownBlockKind.table),
        hasLength(1),
      );
    },
  );

  test('display wrappers, entities and meaningful TeX whitespace survive', () {
    expect(
      htmlToMarkdown(
        '<p>Start</p>${katex(r'\begin{aligned}a &amp;= b \\ c &lt; d\end{aligned}', display: true)}<p>End</p>',
      ),
      'Start\n\n\$\$\n\\begin{aligned}a &= b \\\\ c < d\\end{aligned}\n\$\$\n\nEnd',
    );
    expect(htmlToMarkdown(katex(r'\text{a  b}')), r'$\text{a  b}$');
    expect(
      htmlToMarkdown(r'<p>Use \(\text{a  b}\).</p>'),
      r'Use $\text{a  b}$.',
    );
  });

  test('MathJax MathML annotations and legacy TeX script imports are inert', () {
    expect(
      htmlToMarkdown(
        '<mjx-container display="true"><math><semantics><mi>x</mi><annotation encoding="application/x-latex">x^2</annotation></semantics></math></mjx-container>',
      ),
      '\$\$\nx^2\n\$\$',
    );
    expect(
      htmlToMarkdown(
        '<p>A <script type="math/tex">x+1</script>.</p><script>alert(1)</script><style>.bad{}</style>',
      ),
      r'A $x+1$.',
    );
    expect(
      htmlToMarkdown('<script type="math/tex; mode=display">x=1</script>'),
      '\$\$\nx=1\n\$\$',
    );
  });

  test(
    'data-latex attributes decode entities and tolerate quoted > characters',
    () {
      expect(
        htmlToMarkdown(
          '<span data-latex="x &gt; 2" title="a > b"><svg><text>noise</text></svg></span>',
        ),
        r'$x > 2$',
      );
      expect(
        htmlToMarkdown("<span data-latex='x &quot;y&quot;'>noise</span>"),
        r'$x "y"$',
      );
    },
  );

  test('quoted attribute contents do not masquerade as math attributes', () {
    expect(
      htmlToMarkdown('<span title="data-latex=\'fake\'">Keep this</span>'),
      'Keep this',
    );
    expect(htmlToMarkdown('<span data-latex=x^2>fallback</span>'), r'$x^2$');
    expect(
      htmlToMarkdown(
        '<annotation encoding="application/x-tex">x^2</annotation>',
      ),
      r'$x^2$',
    );
  });

  test('missing/empty source leaves recoverable visible fallback', () {
    expect(
      htmlToMarkdown('<span class="katex"><span>x + y</span></span>'),
      'x + y',
    );
    expect(
      htmlToMarkdown(
        '<math><mi>x</mi><annotation encoding="application/x-tex"> </annotation></math>',
      ),
      'x',
    );
    expect(htmlToMarkdown('<span class="katex">partial x'), 'partial x');
  });

  test(
    'HTML code remains literal, prose math imports and tables retain equations',
    () {
      final result = htmlToMarkdown(
        '<p>Use \\(x\\).</p><pre><code>\\[literal\\]</code></pre><p><code>\\(literal\\)</code></p><table><tr><th>Value</th></tr><tr><td>${katex('x^2')}</td></tr></table>',
      );
      expect(result, contains(r'Use $x$.'));
      expect(result, contains('```\n\\[literal\\]\n```'));
      expect(result, contains(r'`\(literal\)`'));
      expect(result, contains(r'| $x^2$ |'));
    },
  );

  test(
    'large explanations do not duplicate formulas or leak protection tokens',
    () {
      final source = List.generate(
        1000,
        (i) => '<p>Step $i: ${katex('x_{$i}')}.</p>',
      ).join();
      final result = htmlToMarkdown(source);
      expect(RegExp(r'\$x_\{\d+\}\$').allMatches(result), hasLength(1000));
      expect(result, isNot(contains('duplicate')));
      expect(result, isNot(contains('\u0000')));
    },
  );

  test('multiple equations in a shared wrapper are all retained', () {
    final result = htmlToMarkdown(
      '<span class="katex-display">${katex('x')}${katex('y')}</span>',
    );
    expect(result, contains(r'$x$'));
    expect(result, contains(r'$y$'));
    expect(result, isNot(contains('duplicate')));
  });

  test(
    'table quoting preserves TeX norm bars and their authored backslashes',
    () {
      for (final tex in [
        r'|x|',
        r'\|x\|',
        r'\left\|x\right\|',
        r'\text{a|b}',
      ]) {
        final result = htmlToMarkdown(
          '<table><tr><th>Formula</th></tr><tr><td>${katex(tex)}</td></tr></table>',
        );
        final table = MarkdownTable.tryParse(result)!;
        expect(table.columns, 1);
        expect(MarkdownTable.visibleCell(table.rows[1][0]), '\$$tex\$');
      }
    },
  );

  test('browser list equations do not introduce empty bullet placeholders', () {
    expect(
      htmlToMarkdown(
        '<ul><li><p>Use ${katex('x^2', display: true)} here.</p></li><li><p>Continue</p></li></ul>',
      ),
      '- Use \$x^2\$ here.\n- Continue',
    );
  });

  test('annotation-xml fallback cannot consume the next TeX annotation', () {
    expect(
      htmlToMarkdown(
        '<math><semantics><annotation-xml encoding="application/xhtml+xml"><span>visual</span></annotation-xml><annotation encoding="application/x-tex">x^2</annotation></semantics></math>',
      ),
      r'$x^2$',
    );
  });

  test(
    'large malformed delimiters preserve source and subsequent valid math',
    () {
      for (final opening in [r'\[', r'\(']) {
        final source = List.filled(25000, '$opening unfinished\n').join();
        expect(normalizePastedMath(source), source);
      }
      final source =
          List.filled(25000, '\\( unfinished\n').join() + r'\) then \(x\)';
      expect(
        normalizePastedMath(source),
        '${source.substring(0, source.length - 5)}\$x\$',
      );
    },
  );

  test(
    'publication tables retain math, enclosing formatting and forward references',
    () {
      final formula = MarkdownTable.cellText(r'$\|x\|$');
      final body =
          '| Formula | Code |\n| --- | --- |\n| **[$formula][ref]** | `${MarkdownTable.cellText(r'$\|code\|$')}` |\n\n[ref]: https://example.com\n\nOutside: '
          r'$\|outside\|$';
      final document = PublicationDocument.parse(
        'Math',
        body,
        const PublicationStyle(),
      );
      final elements = <md.Element>[];
      void visit(md.Node node) {
        if (node is md.Element) {
          elements.add(node);
          node.children?.forEach(visit);
        }
      }

      document.nodes.forEach(visit);
      expect(
        elements
            .where((node) => node.tag == 'math-inline')
            .map((node) => node.textContent),
        [r'\|x\|', r'\|outside\|'],
      );
      expect(
        elements.where((node) => node.tag == 'a').single.attributes['href'],
        'https://example.com',
      );
      expect(elements.where((node) => node.tag == 'strong'), hasLength(1));
      expect(elements.where((node) => node.tag == 'code'), hasLength(1));
    },
  );

  testWidgets('pasted table norms render identically in Read and publication', (
    tester,
  ) async {
    final body = htmlToMarkdown(
      '<table><tr><th>Norm</th></tr><tr><td>${katex(r'\|x\|')}</td></tr></table>',
    );
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteEditor(
            noteId: 'table-read',
            title: 'Math',
            body: body,
            onBodyChanged: (_) {},
            onTitleChanged: (_) {},
            onOpenObject: (_) {},
            linkTargets: const [],
            spellCheckEnabled: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();
    expect(tester.widget<NoteMath>(find.byType(NoteMath)).source, r'\|x\|');
    expect(tester.takeException(), isNull);
  });

  String plain = '';
  String? html;
  setUp(() {
    plain = '';
    html = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        final text = call.arguments == 'text/html' ? html : plain;
        return text == null ? null : {'text': text};
      }
      return null;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('pasteboard'),
      (_) async => null,
    );
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(const MethodChannel('pasteboard'), null);
  });

  test(
    'clipboard normal paste imports math while literal paste retains source',
    () async {
      plain = r'For \(x\), use \[y=x^2\].';
      expect(await readMarkdownClipboard(), contains(r'For $x$'));
      expect(await readMarkdownClipboard(preferHtml: false), plain);
      html = '<p>For ${katex('x')}, proceed.</p>';
      expect(await readMarkdownClipboard(), r'For $x$, proceed.');
      expect(await readMarkdownClipboard(preferHtml: false), plain);
    },
  );

  testWidgets(
    'normal Rich keyboard paste creates editable equations with undo and redo',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var body = 'Replace this';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, setState) => NoteEditor(
                noteId: 'math-paste',
                title: 'Math',
                body: body,
                onBodyChanged: (value) => setState(() => body = value),
                onTitleChanged: (_) {},
                onOpenObject: (_) {},
                linkTargets: const [],
                spellCheckEnabled: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final editor = tester.state<RichMarkdownEditorState>(
        find.byType(RichMarkdownEditor),
      );
      editor.selectDocumentRange(0, body.length);
      await tester.pump();
      plain = r'Use \(x^2\).';
      html =
          '<p>Use ${katex('x^2')}.</p>${katex(r'\frac{1}{2}', display: true)}';
      Future<void> key(LogicalKeyboardKey value, {bool shift = false}) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(value);
        if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
      }

      await key(LogicalKeyboardKey.keyV);
      final pasted = body;
      expect(body, contains(r'Use $x^2$.'));
      expect(find.byType(RichMathBlock), findsOneWidget);
      expect(inlineMathMatches(body).first[1], 'x^2');
      await key(LogicalKeyboardKey.keyZ);
      expect(body, 'Replace this');
      await key(LogicalKeyboardKey.keyZ, shift: true);
      expect(body, pasted);
      await tester.tap(find.text('Read'));
      await tester.pumpAndSettle();
      expect(find.byType(NoteMath), findsNWidgets(2));
      expect(body, pasted);
      expect(tester.takeException(), isNull);
    },
  );

  for (final mode in ['rich', 'plain', 'source', 'code']) {
    testWidgets(
      '$mode caret paste respects the intended math/literal boundary',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var body = mode == 'code' ? '```tex\noriginal\n```' : 'original';
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (_, setState) => NoteEditor(
                  noteId: 'caret-$mode',
                  title: 'Math',
                  body: body,
                  initialViewState: mode == 'source'
                      ? const {'mode': 'write'}
                      : const {},
                  onBodyChanged: (value) => setState(() => body = value),
                  onTitleChanged: (_) {},
                  onOpenObject: (_) {},
                  linkTargets: const [],
                  spellCheckEnabled: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final field = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.controller?.text == 'original',
        );
        expect(field, findsOneWidget);
        await tester.tap(field);
        tester.widget<TextField>(field).controller!.selection =
            const TextSelection(baseOffset: 0, extentOffset: 8);
        plain = r'Use \(x^2\).';
        html = '<p>Use ${katex('x^2')}.</p>';
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        if (mode == 'plain') {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
        if (mode == 'plain') {
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        }
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(
          body,
          mode == 'code'
              ? '```tex\n$plain\n```'
              : mode == 'rich'
              ? r'Use $x^2$.'
              : plain,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
