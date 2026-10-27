import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:orbit_note/features/notes/markdown_clipboard.dart';
import 'package:orbit_note/features/notes/media_clipboard.dart';
import 'package:orbit_note/domain/pdf_quote_transfer.dart';

Iterable<md.Element> elements(Iterable<md.Node> nodes) sync* {
  for (final node in nodes) {
    if (node is md.Element) {
      yield node;
      yield* elements(node.children ?? []);
    }
  }
}

void main() {
  test(
    'browser links and image paths retain spaces parentheses and exact entities',
    () {
      final text = htmlToMarkdown(
        '<p><a href="https://example.org/a (draft).pdf?q=a&amp;amp;b=2">Source</a></p><p><img src="file:///C:/My Notes/a (1).png" alt="Diagram [1]"></p>',
      );
      final parsed = elements(
        md.Document().parseLines(text.split('\n')),
      ).toList();
      expect(
        parsed.singleWhere((e) => e.tag == 'a').attributes['href'],
        'https://example.org/a%20(draft).pdf?q=a&amp;b=2',
      );
      expect(
        parsed.singleWhere((e) => e.tag == 'img').attributes['src'],
        'file:///C:/My%20Notes/a%20(1).png',
      );
    },
  );
  test('multiline HTML table cells keep one table and literal text', () {
    final text = htmlToMarkdown(
      '<table><tr><th>Field</th><th>Details</th></tr><tr><td>A</td><td><p>First &lt;literal&gt;</p><p>Second <code>a|b</code></p></td></tr></table>',
    );
    final parsed = elements(
      md.Document(
        extensionSet: md.ExtensionSet.gitHubFlavored,
      ).parseLines(text.split('\n')),
    ).toList();
    expect(parsed.where((e) => e.tag == 'table'), hasLength(1));
    expect(parsed.where((e) => e.tag == 'tr'), hasLength(2));
    expect(text, contains('&lt;literal&gt;'));
    expect(text, contains('<br>'));
    expect(text, contains(r'a\|b'));
    expect(text, isNot(contains('\u0000orbit-code-')));
  });
  test('HTML quoted paragraphs and fenced code stay inside their quote', () {
    final text = htmlToMarkdown(
      '<blockquote><p>First paragraph</p><p>Second paragraph</p><pre><code>x\n\ny</code></pre></blockquote>',
    );
    final nodes = md.Document().parseLines(text.split('\n'));
    expect(nodes, hasLength(1));
    expect((nodes.single as md.Element).tag, 'blockquote');
    expect(
      elements(nodes).singleWhere((e) => e.tag == 'pre').textContent,
      'x\n\ny\n',
    );
  });
  test('PDF cited text normalizes all source line endings into quoted lines', () {
    const quote = PdfQuoteDragData(
      objectId: 'pdf',
      title: 'Source',
      page: 9,
      text: 'First\rSecond\r\nThird\n\nLast',
    );
    expect(
      quote.markdownQuote,
      '> First\n> Second\n> Third\n> \n> Last\n\n[[pdf#page=9|Source · p. 9]]\n',
    );
  });
  test(
    'thousands of rich code runs and large note-to-Canvas text retain end sentinels',
    () {
      final html = List.generate(
        4000,
        (i) => '<p>Line $i <code>a  b $i</code></p>',
      ).join();
      final clock = Stopwatch()..start();
      final text = htmlToMarkdown(html);
      clock.stop();
      expect(text, contains('`a  b 3999`'));
      expect(text, isNot(contains('\u0000orbit-code-')));
      final items = markdownCanvasItems(text);
      expect(items, hasLength(1));
      expect(items.single['text'], text);
      // Report rather than hard-fail on different CI machine speeds.
      // ignore: avoid_print
      print('4000 rich runs: ${clock.elapsedMilliseconds} ms');
    },
  );
}
