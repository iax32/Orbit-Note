import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';

void main() {
  test('reference titles and next-line destinations stay in one raw block', () {
    for (final title in ['"API manual"', "'API manual'", '(API manual)']) {
      for (final eol in ['\n', '\r\n']) {
        final definition =
            '  [api]:$eol\t<https://example.com/a b>$eol  $title$eol';
        final source = '[Guide][api]$eol$eol${definition}After';
        final document = MarkdownDocument.parse(source);
        expect(document.source, source);
        expect(document.referenceDefinitions, {
          'api': 'https://example.com/a b',
        });
        expect(
          MarkdownDocument.referenceDefinitionsFor(source),
          document.referenceDefinitions,
        );
        expect(
          document.blocks
              .where((b) => b.kind == MarkdownBlockKind.raw)
              .single
              .source,
          definition,
        );
        expect(document.blocks.last.content, 'After');
      }
    }
  });

  test('reference definition blocks preserve mixed line endings exactly', () {
    for (final destinationEol in ['\n', '\r\n']) {
      for (final titleEol in ['\n', '\r\n']) {
        final source =
            '[Guide][docs]\r\n\r\n[docs]: /guide$destinationEol'
            '  "A title"$titleEol\n\nAfter\r\n';
        final document = MarkdownDocument.parse(source);
        final raw = document.blocks.where(
          (block) => block.kind == MarkdownBlockKind.raw,
        );

        expect(document.source, source);
        expect(document.referenceDefinitions, {'docs': '/guide'});
        expect(MarkdownDocument.referenceDefinitionsFor(source), {
          'docs': '/guide',
        });
        expect(
          raw.single.source,
          '[docs]: /guide$destinationEol  "A title"$titleEol',
        );

        final reparsed = MarkdownDocument.parse(document.source);
        expect(reparsed.source, source);
        expect(reparsed.referenceDefinitions, document.referenceDefinitions);
        expect(
          reparsed.blocks
              .where((block) => block.kind == MarkdownBlockKind.raw)
              .single
              .source,
          raw.single.source,
        );
      }
    }
  });

  test('mixed definition endings keep resolved link edits source-local', () {
    const source =
        '[Guide][docs]\n\n[docs]: <https://example.test/guide>\n  "Guide"\r\nNext';
    final document = MarkdownDocument.parse(source);
    final projection = InlineProjection(
      '[Guide][docs]',
      referenceDefinitions: document.referenceDefinitions,
    );

    expect(projection.text, 'Guide');
    expect(projection.links.single.target, 'https://example.test/guide');
    expect(projection.edit('Manual'), '[Manual][docs]');
    expect(document.source, source);
    expect(MarkdownDocument.parse(document.source).source, source);
    expect(MarkdownDocument.parse(document.source).referenceDefinitions, {
      'docs': 'https://example.test/guide',
    });
  });

  test('escaped reference labels round-trip with mixed definition endings', () {
    for (final label in [r'ref\[', r'ref\]']) {
      final target = label.endsWith(r'\[') ? '/left' : '/right';
      for (final destinationEol in ['\n', '\r\n']) {
        for (final titleEol in ['\n', '\r\n']) {
          final source =
              '[Value][$label]\r\n\r\n[$label]: $target$destinationEol'
              '  "Title"${titleEol}After';
          final document = MarkdownDocument.parse(source);
          final raw = document.blocks.singleWhere(
            (block) => block.kind == MarkdownBlockKind.raw,
          );
          final projection = InlineProjection(
            '[Value][$label]',
            referenceDefinitions: document.referenceDefinitions,
          );

          expect(document.source, source);
          expect(document.referenceDefinitions, {label: target});
          expect(MarkdownDocument.referenceDefinitionsFor(source), {
            label: target,
          });
          expect(
            raw.source,
            '[$label]: $target$destinationEol  "Title"$titleEol',
          );
          expect(projection.text, 'Value');
          expect(projection.links.single.target, target);
          expect(projection.links.single.isResolved, isTrue);
          for (var visible = 0; visible <= projection.text.length; visible++) {
            final start = projection.sourceOffset(visible);
            final end = projection.sourceOffset(visible, end: true);
            expect(projection.visibleOffset(start), visible);
            expect(projection.visibleOffset(end), visible);
          }
          expect(projection.edit('Manual'), '[Manual][$label]');
          expect(MarkdownDocument.parse(document.source).source, source);
        }
      }
    }
  });

  test(
    'Unicode case folding preserves escaped labels through mixed endings',
    () {
      final cases = [
        (
          definition: r'Straße\[',
          reference: r'STRASSE\[',
          key: r'strasse\[',
          visible: 'STRASSE[',
          target: '/german',
        ),
        (
          definition: r'ſignal\]',
          reference: r'SIGNAL\]',
          key: r'signal\]',
          visible: 'SIGNAL]',
          target: '/long-s',
        ),
        (
          definition: r'Kelvin\[',
          reference: r'KELVIN\[',
          key: r'kelvin\[',
          visible: 'KELVIN[',
          target: '/kelvin',
        ),
        (
          definition: r'Ος\]',
          reference: r'οσ\]',
          key: r'οσ\]',
          visible: 'οσ]',
          target: '/greek',
        ),
      ];

      for (final item in cases) {
        for (final destinationEol in ['\n', '\r\n']) {
          for (final titleEol in ['\n', '\r\n']) {
            final definition =
                '[${item.definition}]: ${item.target}$destinationEol'
                '  "Unicode"$titleEol';
            final source =
                '[Value][${item.reference}]\r\n'
                '[${item.reference}]\n\n${definition}After';
            final document = MarkdownDocument.parse(source);
            final expected = {item.key: item.target};
            final raw = document.blocks.singleWhere(
              (block) => block.kind == MarkdownBlockKind.raw,
            );

            expect(document.referenceDefinitions, expected);
            expect(MarkdownDocument.referenceDefinitionsFor(source), expected);
            expect(raw.source, definition);

            for (final linkSource in [
              '[Value][${item.reference}]',
              '[${item.reference}]',
            ]) {
              final projection = InlineProjection(
                linkSource,
                referenceDefinitions: document.referenceDefinitions,
              );
              expect(
                projection.text,
                linkSource.startsWith('[Value]') ? 'Value' : item.visible,
              );
              expect(projection.links.single.target, item.target);
              expect(projection.links.single.isResolved, isTrue);
              for (
                var visible = 0;
                visible <= projection.text.length;
                visible++
              ) {
                final start = projection.sourceOffset(visible);
                final end = projection.sourceOffset(visible, end: true);
                expect(projection.visibleOffset(start), visible);
                expect(projection.visibleOffset(end), visible);
              }
              expect(
                projection.edit('Manual'),
                linkSource.startsWith('[Value]')
                    ? '[Manual][${item.reference}]'
                    : '[Manual]',
              );
            }
            expect(MarkdownDocument.parse(document.source).source, source);
          }
        }
      }
    },
  );

  test(
    'duplicate and unresolved references preserve mixed-source selections',
    () {
      const source =
          '[Guide][DOC]\r\n'
          '[Missing][Unknown]\n'
          '[Unknown]\r\n\r\n'
          '[doc]: /first\r\n'
          '  "First"\n'
          '[DOC]: /second\r\n'
          'After';
      final document = MarkdownDocument.parse(source);
      final rawBlocks = document.blocks.where(
        (block) => block.kind == MarkdownBlockKind.raw,
      );

      expect(document.referenceDefinitions, {'doc': '/first'});
      expect(MarkdownDocument.referenceDefinitionsFor(source), {
        'doc': '/first',
      });
      expect(rawBlocks.map((block) => block.source), [
        '[doc]: /first\r\n  "First"\n',
        '[DOC]: /second\r\n',
      ]);
      expect(document.source, source);

      final links = [
        (
          source: '[Guide][DOC]',
          text: 'Guide',
          target: '/first',
          resolved: true,
          replacement: '[Manual][DOC]',
        ),
        (
          source: '[Missing][Unknown]',
          text: 'Missing',
          target: 'Unknown',
          resolved: false,
          replacement: '[Manual][Unknown]',
        ),
      ];
      for (final item in links) {
        final projection = InlineProjection(
          item.source,
          referenceDefinitions: document.referenceDefinitions,
        );
        expect(projection.text, item.text);
        expect(projection.links.single.target, item.target);
        expect(projection.links.single.isResolved, item.resolved);
        for (var visible = 0; visible <= projection.text.length; visible++) {
          final start = projection.sourceOffset(visible);
          final end = projection.sourceOffset(visible, end: true);
          expect(projection.visibleOffset(start), visible);
          expect(projection.visibleOffset(end), visible);
        }
        expect(projection.edit('Manual'), item.replacement);
      }

      final ordinary = InlineProjection(
        '[Unknown]',
        referenceDefinitions: document.referenceDefinitions,
      );
      expect(ordinary.links, isEmpty);
      expect(ordinary.text, '[Unknown]');
      expect(
        ordinary.edit(
          '[Manual]',
          selectionStart: 1,
          selectionEnd: ordinary.text.length - 1,
        ),
        '[Manual]',
      );
      expect(MarkdownDocument.parse(document.source).source, source);
    },
  );

  test('reference titles span nonblank lines and allow escaped delimiters', () {
    const definition = '[api]: /docs "First\nsecond \\"quoted\\" line"\n';
    final document = MarkdownDocument.parse('${definition}After');
    expect(document.referenceDefinitions, {'api': '/docs'});
    expect(document.blocks.first.source, definition);
    expect(document.blocks.last.content, 'After');
    expect(MarkdownDocument.parse('[api]: /docs ""').referenceDefinitions, {
      'api': '/docs',
    });
  });

  test(
    'invalid same-line titles and destinations do not resolve references',
    () {
      for (final definition in [
        '[api]: /docs trailing garbage',
        '[api]: /docs "title" garbage',
        '[api]: /docs "unclosed',
        '[api]: /docs (nested (title))',
        '[api]: <docs>(title)',
        '[api]: <unclosed',
        '[api]: <nested<url>>',
        '[api]: /unbalanced(foo',
        '[api]: /unbalanced)foo',
        '[api]:\n\n/docs',
        '[api]: /docs "one\n\ntwo"',
        '    [api]: /docs',
        '\t[api]: /docs',
      ]) {
        final source = '[api]\n\n$definition';
        final document = MarkdownDocument.parse(source);
        expect(document.referenceDefinitions, isEmpty, reason: definition);
        expect(document.source, source);
        expect(
          InlineProjection(
            '[api]',
            referenceDefinitions: document.referenceDefinitions,
          ).text,
          '[api]',
        );
      }
    },
  );

  test(
    'invalid next-line title rolls back without swallowing ordinary prose',
    () {
      for (final title in [
        '"title" garbage',
        '"unclosed\ntext',
        '(nested (title))',
        'ordinary prose',
      ]) {
        final source = '[api]: /docs\n$title';
        final document = MarkdownDocument.parse(source);
        expect(document.referenceDefinitions, {'api': '/docs'}, reason: title);
        expect(document.blocks.first.source, '[api]: /docs\n');
        expect(document.source, source);
      }
    },
  );

  test(
    'empty and balanced destinations resolve and first valid definition wins',
    () {
      const source =
          '[empty]: <>\n[api]: /bad "title" junk\n[api]: /docs(a(b(c))) (title)\n[api]: /later\n';
      final document = MarkdownDocument.parse(source);
      expect(document.referenceDefinitions, {
        'empty': '',
        'api': '/docs(a(b(c)))',
      });
      expect(
        InlineProjection(
          '[empty]',
          referenceDefinitions: document.referenceDefinitions,
        ).links.single.isResolved,
        isTrue,
      );
      expect(document.source, source);
    },
  );

  test('frontmatter and nonclosing fences cannot leak reference definitions', () {
    const source =
        '---\n[meta]: /ignored\n---\n```\n[code]: /ignored\n``` trailing text\n[still-code]: /ignored\n```\n[api]:\n/docs\n';
    final document = MarkdownDocument.parse(source);
    expect(document.referenceDefinitions, {'api': '/docs'});
    expect(
      MarkdownDocument.referenceDefinitionsFor(source),
      document.referenceDefinitions,
    );
    expect(document.source, source);
  });

  test(
    'reference destinations decode Markdown escapes and HTML entities only for actions',
    () {
      const source =
          '[Guide][api]\n\n[api]: /docs\\(v1\\)?mode=full&amp;view=print\\#intro\n';
      final document = MarkdownDocument.parse(source);
      expect(document.referenceDefinitions, {
        'api': '/docs(v1)?mode=full&view=print#intro',
      });
      expect(
        InlineProjection(
          '[Guide][api]',
          referenceDefinitions: document.referenceDefinitions,
        ).links.single.target,
        '/docs(v1)?mode=full&view=print#intro',
      );
      expect(document.source, source);
      expect(
        InlineProjection(
          '[Guide][api]',
          referenceDefinitions: document.referenceDefinitions,
        ).edit('Manual'),
        '[Manual][api]',
      );
    },
  );

  test('reference destinations decode named and numeric entities', () {
    const source = '[a]: /search?q=one&#38;two=&#x22;ok&#x22;\n';
    expect(MarkdownDocument.parse(source).referenceDefinitions, {
      'a': '/search?q=one&two="ok"',
    });
  });

  test('empty ATX headings remain editable heading blocks', () {
    final document = MarkdownDocument.parse('#\n## \n###\t\n');
    expect(
      document.blocks
          .where((block) => block.kind == MarkdownBlockKind.heading)
          .map((block) => block.level),
      [1, 2, 3],
    );
    expect(document.source, '#\n## \n###\t\n');
  });

  test('tab-spaced list markers and no-space quotes are structural', () {
    final document = MarkdownDocument.parse('-\tfirst\n1.\tsecond\n>quote\n');
    expect(document.blocks.map((block) => block.kind), [
      MarkdownBlockKind.list,
      MarkdownBlockKind.list,
      MarkdownBlockKind.quote,
    ]);
    expect(document.blocks[0].content, 'first');
    expect(document.blocks[1].content, 'second');
    expect(document.blocks[2].content, 'quote');
  });

  test('contiguous indented code is preserved as one raw block', () {
    const source = '    first\n\tsecond\n\nAfter';
    final document = MarkdownDocument.parse(source);
    expect(document.blocks.first.kind, MarkdownBlockKind.raw);
    expect(document.blocks.first.source, '    first\n\tsecond\n\n');
    expect(document.blocks.last.content, 'After');
    expect(document.source, source);
  });

  test('inline code spans support matching backtick runs', () {
    final projection = InlineProjection('``code `tick``');
    expect(projection.text, 'code `tick');
    expect(
      projection.styles.every((styles) => styles.contains('code')),
      isTrue,
    );
    expect(projection.sourceOffset(5), 7);
  });

  test('inline code spans normalize line endings and edge spaces', () {
    final projection = InlineProjection('`  one\r\ntwo  `');
    expect(projection.text, ' one two ');
    expect(projection.styles.length, projection.text.length);
    expect(
      projection.styles.every((styles) => styles.contains('code')),
      isTrue,
    );
  });

  test('editing a normalized code span preserves its authored delimiters', () {
    final projection = InlineProjection('``a\r\nb``');
    expect(
      projection.edit('a c', selectionStart: 2, selectionEnd: 3),
      '``a\r\nc``',
    );
  });

  test(
    'code spans inside links hide bracket content and keep escapes literal',
    () {
      final bracketed = InlineProjection('[a `]` b](/guide)');
      expect(bracketed.text, 'a ] b');
      expect(bracketed.links, hasLength(1));
      expect(bracketed.styles[2], containsAll(<String>['link', 'code']));

      final mixed = InlineProjection(r'[*a `b\*c` d*](/guide)');
      expect(mixed.text, 'a b\\*c d');
      expect(mixed.links, hasLength(1));
      expect(
        mixed.styles.every(
          (styles) => styles.containsAll(<String>['link', 'italic']),
        ),
        isTrue,
      );
      expect(
        mixed.styles.skip(2).take(4).every((styles) => styles.contains('code')),
        isTrue,
      );

      final edited = InlineProjection('[a `b\r\nc` d](/guide)');
      expect(edited.text, 'a b c d');
      expect(edited.sourceOffset(4), 7);
      expect(edited.sourceOffset(5, end: true), 8);
      expect(
        edited.edit('a b X d', selectionStart: 4, selectionEnd: 5),
        '[a `b\r\nX` d](/guide)',
      );
    },
  );

  test('unmatched backtick runs remain literal source text', () {
    final projection = InlineProjection('literal ` text');
    expect(projection.text, 'literal ` text');
    expect(projection.styles.any((styles) => styles.contains('code')), isFalse);
  });

  test('unmatched runs inside links stay literal and preserve the link', () {
    final projection = InlineProjection('[a ``literal ` b](/guide)');
    expect(projection.text, 'a ``literal ` b');
    expect(projection.links, hasLength(1));
    expect(projection.styles.any((styles) => styles.contains('code')), isFalse);
    expect(
      projection.edit('a ``literal X b', selectionStart: 12, selectionEnd: 13),
      '[a ``literal X b](/guide)',
    );
  });

  test('escaped backtick parity stays literal in nested link labels', () {
    final escaped = InlineProjection(
      r'[outer [inner \`](/inner) tail](/outer)',
    );
    expect(escaped.links, hasLength(1));
    expect(escaped.links.single.target, '/inner');
    expect(escaped.text, '[outer inner ` tail](/outer)');
    expect(escaped.styles.any((styles) => styles.contains('code')), isFalse);

    final even = InlineProjection(r'[a \\` b](/guide)');
    expect(even.links, hasLength(1));
    expect(even.text, r'a \` b');
    expect(even.styles.any((styles) => styles.contains('code')), isFalse);

    final odd = InlineProjection(r'[a \\\` b](/guide)');
    expect(odd.links, hasLength(1));
    expect(odd.text, r'a \` b');
    expect(odd.styles.any((styles) => styles.contains('code')), isFalse);
  });

  test('unmatched runs cannot hide a link boundary using their tail', () {
    final inline = InlineProjection('[a ``x](/guide) ` tail');
    expect(inline.text, 'a ``x ` tail');
    expect(inline.links.single.target, '/guide');
    expect(inline.styles.any((styles) => styles.contains('code')), isFalse);

    final reference = InlineProjection(
      '[a ``x][id] ` tail',
      referenceDefinitions: {'id': '/guide'},
    );
    expect(reference.text, 'a ``x ` tail');
    expect(reference.links.single.target, '/guide');
    expect(reference.styles.any((styles) => styles.contains('code')), isFalse);
  });

  test('code content cannot masquerade as a nested link', () {
    final projection = InlineProjection('[a `[inner](/inner)` b](/outer)');
    expect(projection.text, 'a [inner](/inner) b');
    expect(projection.links, hasLength(1));
    expect(projection.links.single.target, '/outer');
    expect(projection.styles[2], containsAll(['link', 'code']));
    expect(
      projection.edit(
        'a [other](/inner) b',
        selectionStart: 3,
        selectionEnd: 8,
      ),
      '[a `[other](/inner)` b](/outer)',
    );
  });

  test('even backslashes open code while odd backslashes escape backticks', () {
    final even = InlineProjection(r'[a \\`x]y` b](/guide)');
    expect(even.text, r'a \x]y b');
    expect(even.links.single.target, '/guide');
    expect(
      even.styles.skip(3).take(3).every((s) => s.contains('code')),
      isTrue,
    );
    expect(even.sourceOffset(3), 6);
    expect(even.sourceOffset(6, end: true), 9);
    expect(
      even.edit(r'a \z b', selectionStart: 3, selectionEnd: 6),
      r'[a \\`z` b](/guide)',
    );

    final odd = InlineProjection(r'[a \\\`x` b](/guide)');
    expect(odd.text, r'a \`x` b');
    expect(odd.links.single.target, '/guide');
    expect(odd.styles.any((s) => s.contains('code')), isFalse);
    expect(odd.sourceOffset(3), 5);
    expect(odd.sourceOffset(4, end: true), 7);
    expect(
      odd.edit(r'a \Xx` b', selectionStart: 3, selectionEnd: 4),
      r'[a \\Xx` b](/guide)',
    );
  });

  test('editing code punctuation retains its literal preceding backslash', () {
    final projection = InlineProjection(r'[a `b\*c` d](/guide)');
    expect(projection.text, r'a b\*c d');
    expect(projection.sourceOffset(4), 6);
    expect(projection.sourceOffset(5, end: true), 7);
    expect(
      projection.edit(r'a b\Xc d', selectionStart: 4, selectionEnd: 5),
      r'[a `b\Xc` d](/guide)',
    );

    final closing = InlineProjection(r'`a\`');
    expect(closing.text, r'a\');
    expect(closing.styles.every((s) => s.contains('code')), isTrue);
  });

  test(
    'nested edge-space code edits preserve link wrappers and UTF-16 offsets',
    () {
      final projection = InlineProjection('[*`  A\r\nB  `*](/guide)');
      expect(projection.text, ' A B ');
      expect(
        projection.styles.every(
          (styles) => styles.containsAll(<String>['link', 'italic', 'code']),
        ),
        isTrue,
      );
      expect(projection.sourceOffset(0), 4);
      expect(projection.sourceOffset(2), 6);
      expect(projection.sourceOffset(3), 8);
      expect(projection.sourceOffset(5, end: true), 10);
      expect(
        projection.edit(' A X ', selectionStart: 3, selectionEnd: 4),
        '[*`  A\r\nX  `*](/guide)',
      );
      expect(
        projection.edit('X A B ', selectionStart: 0, selectionEnd: 0),
        '[*` X A\r\nB  `*](/guide)',
      );
    },
  );

  test('nested code edge spaces use ASCII-space rules and UTF-16 offsets', () {
    final projection = InlineProjection('[*` \u00a0 `*](/guide)');
    expect(projection.text, '\u00a0');
    expect(
      projection.styles.single,
      containsAll(<String>['link', 'italic', 'code']),
    );
    expect(projection.sourceOffset(0), 4);
    expect(projection.sourceOffset(1, end: true), 5);
    expect(
      projection.edit('X', selectionStart: 0, selectionEnd: 1),
      '[*` X `*](/guide)',
    );
  });

  test('line-ending boundaries map as one visible selection unit', () {
    final projection = InlineProjection('[*`a\r\nb`*](/guide)');
    expect(projection.text, 'a b');
    expect(projection.sourceOffset(1), 4);
    expect(projection.sourceOffset(2, end: true), 6);
    expect(projection.visibleOffset(4), 1);
    expect(projection.visibleOffset(5), 1);
    expect(
      projection.edit('aXb', selectionStart: 1, selectionEnd: 2),
      '[*`aXb`*](/guide)',
    );
    expect(
      projection.edit('a X', selectionStart: 2, selectionEnd: 3),
      '[*`a\r\nX`*](/guide)',
    );

    final emoji = InlineProjection('[*`😀\r\nB`*](/guide)');
    expect(emoji.text, '😀 B');
    expect(emoji.sourceOffset(2), 5);
    expect(emoji.sourceOffset(3), 7);
    expect(emoji.sourceOffset(4, end: true), 8);
    expect(
      emoji.edit('😀XB', selectionStart: 2, selectionEnd: 3),
      '[*`😀XB`*](/guide)',
    );
  });

  test('mixed line endings round-trip with reference-link edits', () {
    final projection = InlineProjection(
      '`a\r\nb` and [Guide][docs]',
      referenceDefinitions: {'docs': '/guide'},
    );
    expect(projection.text, 'a b and Guide');
    expect(projection.links.single.target, '/guide');

    for (var visible = 0; visible <= projection.text.length; visible++) {
      final start = projection.sourceOffset(visible);
      final end = projection.sourceOffset(visible, end: true);
      expect(
        projection.visibleOffset(start),
        visible,
        reason: 'start $visible',
      );
      expect(projection.visibleOffset(end), visible, reason: 'end $visible');
    }

    expect(
      projection.edit('a Xb and Guide', selectionStart: 1, selectionEnd: 2),
      '`a Xb` and [Guide][docs]',
    );
    expect(
      projection.edit('a b and Manual', selectionStart: 8, selectionEnd: 13),
      '`a\r\nb` and [Manual][docs]',
    );
  });

  test('autolinks project visible labels and mail targets', () {
    final projection = InlineProjection(
      'Visit <https://example.com/a> or <me@example.com>.',
    );
    expect(projection.text, 'Visit https://example.com/a or me@example.com.');
    expect(projection.links, hasLength(2));
    expect(projection.links[0].target, 'https://example.com/a');
    expect(projection.links[1].target, 'mailto:me@example.com');
    expect(projection.links.every((link) => !link.isReference), isTrue);
  });

  test(
    'inline link destinations decode escapes and entities without rewriting source',
    () {
      const source =
          r'[Guide](https://example.test/a\(b\)?q=one&amp;x=1\#intro)';
      final projection = InlineProjection(source);
      expect(projection.text, 'Guide');
      expect(
        projection.links.single.target,
        'https://example.test/a(b)?q=one&x=1#intro',
      );
      expect(
        projection.edit('Manual'),
        r'[Manual](https://example.test/a\(b\)?q=one&amp;x=1\#intro)',
      );
    },
  );

  test(
    'inline links keep balanced destination parentheses inside the target',
    () {
      const source = '[Docs](https://example.test/a(b(c)))';
      final projection = InlineProjection(source);
      expect(projection.links.single.target, 'https://example.test/a(b(c))');
      expect(projection.links.single.sourceEnd, source.length);
    },
  );

  test('inline link titles are excluded from targets and preserve source', () {
    for (final title in ['"Reference"', "'Reference'", '(Reference)']) {
      final source = '[Docs](  /guide&amp;part=1  $title  )';
      final projection = InlineProjection(source);
      expect(projection.text, 'Docs', reason: title);
      expect(projection.links.single.target, '/guide&part=1', reason: title);
      expect(projection.links.single.sourceEnd, source.length, reason: title);
      expect(projection.edit('Manual'), '[Manual]${source.substring(6)}');
    }
  });

  test('inline links accept one line ending around destination and title', () {
    const source = '[Docs](\n/guide\n"Reference"\n)';
    final projection = InlineProjection(source);
    expect(projection.links.single.target, '/guide');
    expect(projection.links.single.sourceEnd, source.length);
    expect(projection.edit('Manual'), '[Manual](\n/guide\n"Reference"\n)');
  });

  test('inline title line endings preserve CRLF and reject blank lines', () {
    const valid = '[Docs](\r\n/guide\r\n"First\r\nsecond"\r\n)';
    final projection = InlineProjection(valid);
    expect(projection.links.single.target, '/guide');
    expect(projection.links.single.sourceEnd, valid.length);
    expect(
      projection.edit('Manual'),
      '[Manual](\r\n/guide\r\n"First\r\nsecond"\r\n)',
    );
    for (final invalid in [
      '[Docs](/guide\r\n\r\n"title")',
      '[Docs](/guide\r\n  \r\n"title")',
      '[Docs](/guide\n \n"title")',
    ]) {
      expect(InlineProjection(invalid).links, isEmpty, reason: invalid);
    }
  });

  test('parenthesized titles require escaped nested delimiters', () {
    final valid = InlineProjection(r'[Docs](/guide (a \(b\)))');
    expect(valid.links.single.target, '/guide');
    expect(valid.links.single.sourceEnd, valid.source.length);
    for (final invalid in [
      '[Docs](/guide (a (b)))',
      '[Docs](/guide (a)',
      '[Docs](/guide "title\')',
    ]) {
      expect(InlineProjection(invalid).links, isEmpty, reason: invalid);
    }
  });

  test('inline link labels allow escaped and matched nested brackets', () {
    for (final source in [
      r'[a [b] c](/guide)',
      r'[\[bracket\]](/guide)',
      r'[a [b [c] d] e](/guide)',
    ]) {
      final projection = InlineProjection(source);
      expect(projection.links, hasLength(1), reason: source);
      expect(projection.links.single.target, '/guide');
      expect(projection.links.single.sourceEnd, source.length);
      expect(projection.edit('Manual'), '[Manual](/guide)');
    }
  });

  test('inline link labels only treat punctuation backslashes as escapes', () {
    final literalBackslash = InlineProjection(r'[\x](/guide)');
    expect(literalBackslash.links, hasLength(1));
    expect(literalBackslash.text, r'\x');
    expect(
      literalBackslash.links.single.sourceEnd,
      literalBackslash.source.length,
    );

    final escapedBrackets = InlineProjection(r'[\[x\]](/guide)');
    expect(escapedBrackets.links, hasLength(1));
    expect(escapedBrackets.text, '[x]');

    final nestedAfterLiteralBackslash = InlineProjection(r'[\x [b] c](/guide)');
    expect(nestedAfterLiteralBackslash.links, hasLength(1));
    expect(nestedAfterLiteralBackslash.text, r'\x [b] c');
  });

  test('escaped punctuation maps carets around its source escape marker', () {
    final projection = InlineProjection(r'\*x');
    expect(projection.text, '*x');
    expect(projection.sourceOffset(0), 0);
    expect(projection.sourceOffset(1), 2);
    expect(projection.visibleOffset(0), 0);
    expect(projection.visibleOffset(1), 0);
    expect(projection.visibleOffset(2), 1);
    expect(projection.edit('x*x', selectionStart: 0, selectionEnd: 0), r'x\*x');
    expect(projection.edit('x', selectionStart: 0, selectionEnd: 1), 'x');
  });

  test('escaped delimiters stay literal inside linked emphasis', () {
    final escapedClosing = InlineProjection(r'[*word\*](/guide)');
    expect(escapedClosing.text, '*word*');
    expect(escapedClosing.links, hasLength(1));
    expect(
      escapedClosing.styles.every((styles) => styles.contains('link')),
      isTrue,
    );
    expect(
      escapedClosing.styles.any((styles) => styles.contains('italic')),
      isFalse,
    );

    final nested = InlineProjection(r'[*a \* b*](/guide)');
    expect(nested.text, 'a * b');
    expect(nested.links, hasLength(1));
    expect(
      nested.styles.every(
        (styles) => styles.containsAll(<String>['link', 'italic']),
      ),
      isTrue,
    );
    expect(nested.sourceOffset(2), 4);
    expect(nested.sourceOffset(3, end: true), 6);
    expect(
      nested.edit('a X b', selectionStart: 2, selectionEnd: 3),
      '[*a X b*](/guide)',
    );
  });

  test('unmatched or nested inline links remain literal', () {
    for (final source in [
      '[a [b] c](/guide',
      '[a [b] c](/guide "title" trailing)',
    ]) {
      final projection = InlineProjection(source);
      expect(projection.links, isEmpty, reason: source);
      expect(projection.text, source);
    }
  });

  test('nested link syntax does not project the outer link', () {
    final projection = InlineProjection('[a [b](nested) c](/guide)');
    expect(projection.links, hasLength(1));
    expect(projection.links.single.target, 'nested');
    expect(projection.text, '[a b c](/guide)');
  });

  test('malformed inline titles and trailing characters remain literal', () {
    for (final source in [
      '[Docs](/guide "unclosed)',
      '[Docs](/guide "title" trailing)',
      '[Docs](/guide unknown)',
      '[Docs](/guide "one\n\ntwo")',
    ]) {
      final projection = InlineProjection(source);
      expect(projection.links, isEmpty, reason: source);
      expect(projection.text, source);
    }
  });

  test('reference links hide only their authored labels', () {
    final projection = InlineProjection('See [guide][docs] and [next][].');
    expect(projection.text, 'See guide and next.');
    expect(projection.links, hasLength(2));
    expect(projection.links[0].target, 'docs');
    expect(projection.links[1].target, 'next');
    expect(projection.links.every((link) => link.isReference), isTrue);
    expect(InlineProjection('[guide][docs]').edit('manual'), '[manual][docs]');
    final nested = InlineProjection('[*guide*][docs]');
    expect(nested.text, 'guide');
    expect(nested.styles.first, containsAll(<String>['link', 'italic']));
  });

  test('reference labels allow escaped brackets and reject unescaped ones', () {
    const definitionsSource = r'''[ref\[]: /left
[ref\]]: /right
''';
    final definitions = MarkdownDocument.parse(
      definitionsSource,
    ).referenceDefinitions;
    expect(definitions, {r'ref\[': '/left', r'ref\]': '/right'});

    final full = InlineProjection(
      r'[left][ref\[] and [right][ref\]]',
      referenceDefinitions: definitions,
    );
    expect(full.text, 'left and right');
    expect(full.links.map((link) => link.target), ['/left', '/right']);

    final shortcuts = InlineProjection(
      r'[ref\[] and [ref\]]',
      referenceDefinitions: definitions,
    );
    expect(shortcuts.text, 'ref[ and ref]');
    expect(shortcuts.links, hasLength(2));

    final unsupported = InlineProjection(
      r'[left][ref[inner]]',
      referenceDefinitions: definitions,
    );
    expect(unsupported.links, isEmpty);
    expect(unsupported.text, r'[left][ref[inner]]');
  });

  test(
    'reference definitions resolve across the document and skip fenced code',
    () {
      const source =
          '[Docs][api]\n\n[api]: <https://example.com/docs>\n\n```\n[code]: https://ignored.example\n```';
      final document = MarkdownDocument.parse(source);
      expect(document.referenceDefinitions, {
        'api': 'https://example.com/docs',
      });
      final resolved = InlineProjection(
        '[Docs][API]',
        referenceDefinitions: document.referenceDefinitions,
      );
      expect(resolved.links.single.target, 'https://example.com/docs');
      expect(resolved.links.single.isResolved, isTrue);
      final unresolved = InlineProjection(
        '[Missing][unknown]',
        referenceDefinitions: document.referenceDefinitions,
      );
      expect(unresolved.text, 'Missing');
      expect(unresolved.links.single.target, 'unknown');
      expect(unresolved.links.single.isResolved, isFalse);
    },
  );

  test(
    'reference labels use Unicode case folding and CommonMark whitespace',
    () {
      const source = '[SS]: /sharp\n[foo\u00a0bar]: /nbsp\n';
      final definitions = MarkdownDocument.parse(source).referenceDefinitions;
      final projection = InlineProjection(
        '[ẞ] [foo bar] [foo\u00a0bar]',
        referenceDefinitions: definitions,
      );

      expect(projection.text, 'ẞ [foo bar] foo\u00a0bar');
      expect(projection.links, hasLength(2));
      expect(projection.links[0].target, '/sharp');
      expect(projection.links[0].isResolved, isTrue);
      expect(projection.links[1].target, '/nbsp');
      expect(projection.links[1].isResolved, isTrue);
      expect(
        InlineProjection(
          '[ẞ]',
          referenceDefinitions: definitions,
        ).edit('Manual'),
        '[Manual]',
      );
    },
  );

  test('shortcut references require a matching definition', () {
    final definitions = {'guide': 'https://example.com/guide'};
    final resolved = InlineProjection(
      'Read [Guide] and [ordinary] and ![Guide](cover.png).',
      referenceDefinitions: definitions,
    );
    expect(resolved.text, 'Read Guide and [ordinary] and ![Guide](cover.png).');
    expect(resolved.links, hasLength(1));
    expect(resolved.links.single.label, 'Guide');
    expect(resolved.links.single.target, 'https://example.com/guide');
    expect(resolved.links.single.isReference, isTrue);
    expect(resolved.links.single.isResolved, isTrue);
    expect(
      InlineProjection(
        '[Guide]',
        referenceDefinitions: definitions,
      ).edit('Manual'),
      '[Manual]',
    );
  });

  test('reparsing a changed definition refreshes shortcut destinations', () {
    const original = '[Guide]\n\n[guide]: https://old.example';
    const updated = '[Guide]\n\n[guide]: https://new.example';
    final before = MarkdownDocument.parse(original);
    final after = MarkdownDocument.parse(updated);
    expect(
      InlineProjection(
        '[Guide]',
        referenceDefinitions: before.referenceDefinitions,
      ).links.single.target,
      'https://old.example',
    );
    expect(
      InlineProjection(
        '[Guide]',
        referenceDefinitions: after.referenceDefinitions,
      ).links.single.target,
      'https://new.example',
    );
  });
}
