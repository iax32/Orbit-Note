import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';
import 'package:orbit_note/domain/document_anchors.dart';
import 'package:orbit_note/domain/object_reference.dart';
import 'package:orbit_note/features/notes/rich/markdown_block_editing.dart';

void main() {
  test('duplicating a paragraph keeps its original anchor unique', () {
    final source = 'First ^stable\n\nSecond';
    final edit = MarkdownBlockEditing.duplicate(
      MarkdownDocument.parse(source),
      0,
      0,
    );
    expect(edit.source, 'First ^stable\n\nFirst\n\nSecond');
    expect(RegExp(r'\^stable').allMatches(edit.source).length, 1);
    expect(
      MarkdownDocument.parse(
        edit.source,
      ).blocks.where((b) => b.kind == MarkdownBlockKind.text).length,
      3,
    );
    expect(edit.source.substring(edit.offset, edit.endOffset), 'First\n');
  });
  test(
    'duplicating the last paragraph preserves the lack of final newline',
    () {
      final edit = MarkdownBlockEditing.duplicate(
        MarkdownDocument.parse('First\n\nLast ^last'),
        2,
        2,
      );
      expect(edit.source, 'First\n\nLast ^last\n\nLast');
    },
  );
  test(
    'multi-block duplicate preserves CRLF and unknown literal anchor text',
    () {
      final source = 'First ^first\r\n\r\nSecond ^second\r\n\r\nThird';
      final edit = MarkdownBlockEditing.duplicate(
        MarkdownDocument.parse(source),
        0,
        2,
      );
      expect(
        edit.source,
        'First ^first\r\n\r\nSecond ^second\r\n\r\nFirst\r\n\r\nSecond\r\n\r\nThird',
      );
      final code = '```\nvalue ^literal\n```';
      expect(
        MarkdownBlockEditing.duplicate(
          MarkdownDocument.parse(code),
          0,
          0,
        ).source,
        '$code\n\n$code',
      );
    },
  );
  test('duplicating list items does not add a paragraph gap', () {
    expect(
      MarkdownBlockEditing.duplicate(
        MarkdownDocument.parse('- item\n- next'),
        0,
        0,
      ).source,
      '- item\n- item\n- next',
    );
  });
  test(
    'conversion retains alignment and rejects dropping a linked identity',
    () {
      final source = '<!-- orbit:align=center -->\r\n## Heading ##\r\n';
      final edit = MarkdownBlockEditing.convert(
        MarkdownDocument.parse(source),
        0,
        'Text',
      )!;
      expect(edit.source, '<!-- orbit:align=center -->\r\nHeading\r\n');
      expect(
        MarkdownDocument.parse(edit.source).blocks.first.alignment,
        'center',
      );
      final linked = 'Text ^stable\n';
      final refusal = MarkdownBlockEditing.convert(
        MarkdownDocument.parse(linked),
        0,
        'Heading 2',
      )!;
      expect(refusal.source, linked);
      expect(refusal.notice, isNotNull);
      expect(
        MarkdownBlockEditing.convert(
          MarkdownDocument.parse(linked),
          0,
          'Text',
        )!.source,
        linked,
      );
    },
  );
  test('code conversion chooses a fence longer than its payload backticks', () {
    final source = '~~~dart\n```\nliteral ````\n~~~\r\n';
    final original = MarkdownDocument.parse(source);
    final edit = MarkdownBlockEditing.convert(original, 0, 'Code block')!;
    final converted = MarkdownDocument.parse(edit.source);
    expect(converted.blocks.length, 1);
    expect(converted.blocks.first.kind, MarkdownBlockKind.code);
    expect(converted.blocks.first.content, original.blocks.first.content);
    expect(converted.blocks.first.prefix, '`````text\r\n');
    expect(edit.source.endsWith('`````\r\n'), true);
  });
  test('unknown source blocks cannot be flattened by a structure command', () {
    final source = '{{ extension ^literal }}\n';
    final edit = MarkdownBlockEditing.convert(
      MarkdownDocument.parse(source),
      0,
      'Heading 1',
    )!;
    expect(edit.source, source);
    expect(edit.notice, isNotNull);
  });
  test(
    'alignment uses document CRLF even when the final block has no newline',
    () {
      final doc = MarkdownDocument.parse('First\r\n\r\nLast');
      final aligned = doc.blocks.last.withAlignment(
        'right',
        lineEnding: MarkdownBlockEditing.eol(doc),
      );
      expect(aligned, '<!-- orbit:align=right -->\r\nLast');
      expect(MarkdownDocument.parse(aligned).blocks.first.alignment, 'right');
    },
  );
  test('an aligned paragraph receives a resolvable precise reference', () {
    const source = '<!-- orbit:align=center -->\r\nProse.\r\n\r\nNext';
    final anchored = anchorDocumentBlock(source, 'note-id', 30, 'stable');
    expect(
      anchored.source,
      '<!-- orbit:align=center -->\r\nProse. ^stable\r\n\r\nNext',
    );
    expect(anchored.reference.target, 'note-id#^stable');
    expect(
      resolveDocumentFragment(
        anchored.source,
        ObjectReference.parse('note-id#^stable'),
      )?.blockId,
      'stable',
    );
    final repeated = anchorDocumentBlock(
      anchored.source,
      'note-id',
      30,
      'different',
    );
    expect(repeated.source, anchored.source);
    expect(repeated.reference.target, anchored.reference.target);
  });
  test(
    'formatting preserves text and unrelated styles across mixed ranges',
    () {
      for (final source in [
        'plain text',
        '**bold** and *italic*',
        '***nested***',
        '[a link](https://example.com)',
        '[[target|alias]]',
        '<u>underlined</u>',
        '==highlight==',
        'one \x60code\x60 two',
        '**one *two* three**',
      ]) {
        final original = InlineProjection(source);
        for (var start = 0; start < original.text.length; start++) {
          for (var end = start + 1; end <= original.text.length; end++) {
            for (final entry in {
              '**': 'bold',
              '*': 'italic',
              '~~': 'strike',
              '==': 'highlight',
              '<u>': 'underline',
            }.entries) {
              final result = InlineProjection(
                original.formatRange(
                  start,
                  end,
                  entry.key,
                  entry.key == '<u>' ? '</u>' : entry.key,
                ),
              );
              expect(result.text, original.text);
              for (var i = 0; i < original.text.length; i++) {
                final before = {...original.styles[i]},
                    after = {...result.styles[i]};
                if (i >= start && i < end) {
                  before.remove(entry.value);
                  after.remove(entry.value);
                }
                expect(after.length, before.length);
                expect(after.containsAll(before), true);
              }
            }
          }
        }
      }
    },
  );
}
