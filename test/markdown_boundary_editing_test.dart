import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';
import 'package:orbit_note/features/notes/rich/markdown_block_editing.dart';

void main() {
  MarkdownDocument doc(String source) => MarkdownDocument.parse(source);
  test(
    'insert and Backspace restore original paragraph and CRLF boundaries',
    () {
      for (final source in ['First', 'First\n', 'First\r\n']) {
        final inserted = MarkdownBlockEditing.insertAfter(doc(source), 0, '');
        final parsed = doc(inserted.source);
        final index = parsed.blockAt(inserted.offset);
        // Mirror the focused blank projection in the rich editor.
        final blank = parsed.blocks[index];
        parsed.blocks[index] = MarkdownBlock(
          blank.source,
          MarkdownBlockKind.text,
          suffix: blank.source,
        );
        final result = MarkdownBlockEditing.backspace(parsed, index)!;
        expect(result.source, source.endsWith('\n') ? source : '$source\n');
        expect(result.offset, 5);
      }
    },
  );
  test('empty paragraph after fenced code removes only its boundary', () {
    final source = '```\ncode\n```\n\n';
    final parsed = doc(source);
    expect(
      MarkdownBlockEditing.backspace(parsed, parsed.blocks.length - 1)!.source,
      '```\ncode\n```',
    );
  });
  test(
    'formatted split and join preserve source, anchor and final newline',
    () {
      final source = '**bold** ^paragraph\n';
      final split = MarkdownBlockEditing.split(doc(source), 0, 2, 2);
      final parsed = doc(split.source);
      expect(MarkdownBlockEditing.backspace(parsed, 2)!.source, source);
      expect(
        MarkdownBlockEditing.deleteForward(
          doc('First\n\nSecond ^second\n'),
          0,
        )!.source,
        'FirstSecond ^second\n',
      );
    },
  );
  test('separately referenced paragraphs cannot silently lose identities', () {
    final parsed = doc('First ^first\n\nSecond ^second');
    final edit = MarkdownBlockEditing.backspace(parsed, 2)!;
    expect(edit.source, parsed.source);
    expect(edit.notice, isNotNull);
  });
  test('Backspace removes heading or list formatting before merging', () {
    expect(MarkdownBlockEditing.backspace(doc('- item'), 0)!.source, 'item');
    expect(
      MarkdownBlockEditing.backspace(doc('## Heading ##\n'), 0)!.source,
      'Heading\n',
    );
    expect(
      MarkdownBlockEditing.split(doc('> quote'), 0, 5, 5).source,
      '> quote\n> ',
    );
    expect(
      MarkdownBlockEditing.split(doc('# Heading'), 0, 0, 0).source,
      '\n\n# Heading',
    );
  });
  test(
    'exiting empty lists and quotes focuses after the paragraph separator',
    () {
      for (final line in ['\n', '\r\n']) {
        for (final (first, empty) in [
          ('- bullet', '- '),
          ('9. item', '10. '),
          ('- [x] done', '- [ ] '),
          ('> quote', '> '),
        ]) {
          for (final after in ['', '${line}After **kept**$line']) {
            final source = '$first$line$empty$after';
            final edit = MarkdownBlockEditing.split(doc(source), 1, 0, 0);
            expect(edit.source, '$first$line$line$after');
            expect(edit.offset, first.length + line.length * 2);
            // Typing at that caret preserves the separator and following prose.
            expect(
              edit.source.replaceRange(edit.offset, edit.offset, 'Done'),
              '$first$line${line}Done$after',
            );
          }
        }
      }
    },
  );
  test('partial formatting toggles preserve nested marks and link targets', () {
    expect(
      InlineProjection('**bold**').formatRange(0, 2, '**', '**'),
      'bo**ld**',
    );
    expect(
      InlineProjection('***bold***').formatRange(0, 4, '**', '**'),
      '*bold*',
    );
    expect(
      InlineProjection(
        '[word](https://example.com)',
      ).formatRange(0, 4, '**', '**'),
      '**[word](https://example.com)**',
    );
    expect(InlineProjection('**bold**').formatRange(0, 4, '**', '**'), 'bold');
  });
  test('mixed formatting keeps text readable and applies requested style', () {
    final original = InlineProjection('**bold** and *italic*');
    for (final tag in ['**', '*']) {
      final result = InlineProjection(original.formatRange(0, 5, tag, tag));
      expect(result.text, original.text);
      final mark = tag == '**' ? 'bold' : 'italic';
      expect(result.styles.take(5).every((s) => s.contains(mark)), isTrue);
    }
  });
}
