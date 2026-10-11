import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/markdown_clipboard.dart';

void main() {
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
  });
}
