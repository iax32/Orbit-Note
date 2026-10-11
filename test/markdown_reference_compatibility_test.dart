import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/note_find_index.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';

void expectCaretRoundTrips(InlineProjection projection) {
  for (var caret = 0; caret <= projection.text.length; caret++) {
    expect(projection.visibleOffset(projection.sourceOffset(caret)), caret);
    expect(
      projection.visibleOffset(projection.sourceOffset(caret, end: true)),
      caret,
    );
  }
}

void main() {
  test('nested literal labels keep links and every selected range editable', () {
    const labels = [
      'a [b] c',
      r'a \[b\] c',
      'a *b* c',
      'a **b** c',
      '😀 [b] c',
    ];
    for (final label in labels) {
      final visible = InlineProjection(label).text;
      for (final suffix in ['[docs]', '(/guide)']) {
        final source = '[$label]$suffix';
        final projection = InlineProjection(
          source,
          referenceDefinitions: const {'docs': '/guide'},
        );
        expect(projection.text, visible, reason: source);
        expect(projection.links.single.target, '/guide', reason: source);
        expectCaretRoundTrips(projection);
        // UTF-16 coordinates, restricted to Unicode scalar boundaries for edits.
        final boundaries = [0];
        for (final rune in visible.runes) {
          boundaries.add(boundaries.last + (rune > 0xffff ? 2 : 1));
        }
        for (final start in boundaries) {
          for (final end in boundaries.where((end) => end >= start)) {
            final next = visible.replaceRange(start, end, 'X');
            final edited = InlineProjection(
              projection.edit(next, selectionStart: start, selectionEnd: end),
              referenceDefinitions: const {'docs': '/guide'},
            );
            expect(edited.text, next, reason: '$source $start..$end');
            expect(edited.links.single.target, '/guide');
            expectCaretRoundTrips(edited);
          }
        }
      }
    }
  });

  test('nested child links coexist with an outer reference link', () {
    const children = [
      ('[child](/inner)', 'child', '/inner'),
      ('[child][inner]', 'child', '/inner'),
      ('[inner][]', 'inner', '/inner'),
      ('[inner]', 'inner', '/inner'),
      (
        '<https://example.test>',
        'https://example.test',
        'https://example.test',
      ),
    ];
    for (final (child, text, target) in children) {
      for (final outer in ['[outer]', '(/outer)']) {
        final source = '[a $child b]$outer';
        final projection = InlineProjection(
          source,
          referenceDefinitions: const {'inner': '/inner', 'outer': '/outer'},
        );
        expect(
          projection.links.map((link) => link.target),
          outer == '[outer]' ? [target, '/outer'] : [target],
          reason: source,
        );
        final expectedText = outer == '[outer]'
            ? 'a $text b'
            : '[a $text b](/outer)';
        expect(projection.text, expectedText, reason: source);
        expectCaretRoundTrips(projection);
        final start = projection.text.indexOf(text);
        final edited = projection.edit(
          projection.text.replaceRange(start, start + text.length, 'changed'),
          selectionStart: start,
          selectionEnd: start + text.length,
        );
        expect(
          InlineProjection(
            edited,
            referenceDefinitions: const {'inner': '/inner', 'outer': '/outer'},
          ).text,
          contains('changed'),
          reason: source,
        );
      }
    }
  });

  test('escaped and code-contained links cannot disable an outer link', () {
    for (final label in [
      r'a \[child\] b',
      'a `[child][inner]` b',
      'a `<https://example.test>` b',
      'a [ordinary] b',
    ]) {
      for (final suffix in ['[outer]', '(/outer)']) {
        final projection = InlineProjection(
          '[$label]$suffix',
          referenceDefinitions: const {'inner': '/inner', 'outer': '/outer'},
        );
        expect(projection.links.map((link) => link.target), ['/outer']);
        expect(projection.text, InlineProjection(label).text);
        expectCaretRoundTrips(projection);
      }
    }
  });

  test(
    'nonbreaking identifier whitespace is retained for full reference lookup',
    () {
      const definitions = {'\u00a0docs\u00a0': '/nbsp', 'docs': '/ordinary'};
      for (final suffix in ['[\u00a0docs\u00a0]', '[\u00a0missing\u00a0]']) {
        final projection = InlineProjection(
          '[Guide]$suffix',
          referenceDefinitions: definitions,
        );
        expect(
          projection.links.single.target,
          suffix.contains('missing') ? '\u00a0missing\u00a0' : '/nbsp',
        );
        expect(projection.edit('Manual'), '[Manual]$suffix');
        expectCaretRoundTrips(projection);
      }
    },
  );

  test(
    'malformed definitions cannot mask later valid targets or swallow prose',
    () {
      const malformed = [
        '[docs]: /bad "title" junk',
        '[docs]: /bad "unclosed',
        '[docs]: /bad (nested (title))',
        '[docs]: <bad<url>>',
        '[docs]: /bad(unbalanced',
        '[docs]:\n\n/bad',
        '[docs[inner]]: /bad',
      ];
      for (final invalid in malformed) {
        for (final eol in ['\n', '\r\n']) {
          final bad = invalid.replaceAll('\n', eol);
          final source = '[Guide][docs]$eol$eol$bad$eol$eol[DOCS]: /good$eol';
          final document = MarkdownDocument.parse(source);
          expect(document.source, source);
          expect(document.referenceDefinitions, {'docs': '/good'}, reason: bad);
          expect(MarkdownDocument.referenceDefinitionsFor(source), {
            'docs': '/good',
          });
          final index = NoteFindIndex(source, rich: true);
          expect(
            index.replace(index.matches('Guide'), 'Manual'),
            source.replaceFirst('Guide', 'Manual'),
          );
        }
      }
    },
  );

  test(
    'mixed-ending malformed titles roll back without claiming later definitions',
    () {
      const title = '  "unclosed\r\n\nLater prose\r\n';
      const source = '[Guide][docs]\n\n[docs]: /good\r\n$title[next]: /next\n';
      final document = MarkdownDocument.parse(source);
      expect(document.referenceDefinitions, {'docs': '/good', 'next': '/next'});
      expect(document.source, source);
      expect(
        document.blocks
            .where((block) => block.kind == MarkdownBlockKind.raw)
            .map((block) => block.source),
        ['[docs]: /good\r\n', '[next]: /next\n'],
      );
      final index = NoteFindIndex(source, rich: true);
      expect(
        index.replace(index.matches('Guide'), 'Manual'),
        source.replaceFirst('Guide', 'Manual'),
      );
    },
  );
}
