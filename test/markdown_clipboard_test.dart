import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/markdown_clipboard.dart';

void main() {
  for (final wrapper in ['p', 'div', 'div><p']) {
    test(
      'paragraph-wrapped browser list items keep text on the bullet ($wrapper)',
      () {
        final closing = wrapper == 'div><p' ? '</p></div>' : '</$wrapper>';
        final opening = '<$wrapper>';
        expect(
          htmlToMarkdown(
            '<h2>Final Reminders</h2><ul>'
            '<li>\n $opening<strong>Be on time:</strong> Exam at 13:15.$closing</li>'
            '<li>$opening<strong>Submit manually:</strong> Save your answers.$closing</li>'
            '</ul>',
          ),
          '## Final Reminders\n\n- **Be on time:** Exam at 13:15.\n- **Submit manually:** Save your answers.',
        );
      },
    );
  }

  test(
    'browser list wrappers retain attributes, Unicode, links and literal code spacing',
    () {
      expect(
        htmlToMarkdown(
          '<UL><LI data-start="10">\r\n<P class="paragraph">'
          '<strong>Café 😀:</strong> <code>a  b &amp; c</code> '
          '<a href="https://example.com">Source</a></P></LI></UL>',
        ),
        '- **Café 😀:** `a  b & c` [Source](https://example.com)',
      );
    },
  );

  test(
    'intentional empty list items and separate prose paragraphs survive conversion',
    () {
      expect(
        htmlToMarkdown('<ul><li><p></p></li><li><p>Filled</p></li></ul>'),
        '- \n- Filled',
      );
      expect(
        htmlToMarkdown('<p>First paragraph</p><p>Second paragraph</p>'),
        'First paragraph\n\nSecond paragraph',
      );
    },
  );

  test('converts common browser formatting to readable Markdown', () {
    expect(
      htmlToMarkdown(
        '<h2>Release notes</h2><p><strong>Fast</strong> and '
        '<em>focused</em>. <a href="https://example.com">Read more</a>.</p>'
        '<ul><li>Offline</li><li>Local-first</li></ul>',
      ),
      '## Release notes\n\n**Fast** and *focused*. '
      '[Read more](https://example.com).\n\n- Offline\n- Local-first',
    );
  });

  test('keeps code, quotes, entities, images, and simple tables lossless', () {
    final result = htmlToMarkdown('''
<blockquote>Use &amp; keep it simple.</blockquote>
<pre><code>final x = 1;</code></pre>
<p><img src="cover.png" alt="Cover"></p>
<table><tr><th>Name</th><th>Done</th></tr><tr><td>Ship</td><td>Yes</td></tr></table>
''');
    expect(result, contains('> Use & keep it simple.'));
    expect(result, contains('```\nfinal x = 1;\n```'));
    expect(result, contains('![Cover](cover.png)'));
    expect(result, contains('| Name | Done |\n| --- | --- |\n| Ship | Yes |'));
  });

  testWidgets('rich clipboard is preferred and plain text remains fallback', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            final format = call.arguments.toString();
            if (format.contains('text/html')) {
              return {'text': '<p><strong>From web</strong></p>'};
            }
            return {'text': 'plain fallback'};
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(const SizedBox());
    expect(await readMarkdownClipboard(), '**From web**');
    expect(await readMarkdownClipboard(preferHtml: false), 'plain fallback');
  });
}
