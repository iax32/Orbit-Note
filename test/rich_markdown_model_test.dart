import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';
import 'package:orbit_note/features/notes/rich/document_history.dart';
import 'package:orbit_note/features/notes/markdown_editing.dart';
import 'package:orbit_note/infrastructure/storage/object_codec.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  final fixtures = <String>[
    '# Heading\n\nA **bold** and _italic_ paragraph.\n',
    '- first\n  - nested\n  2. numbered\n- [x] Done\n- [ ] Task\n',
    '| Name | Status |\n| :--- | ---: |\n| A \\| B | **Done** |\n',
    '~~~cpp\nint main() {\n  return 0;\n}\n~~~\n',
    '[[Object|Readable]] [ordinary](https://example.com)\n\n![caption](<../Attachments/a.png>)\n',
    r'Inline $O(n \log n)$ and malformed $\badthing{x$.'
        '\n\n\$\$\n\\frac{a}{b}\n\$\$\n',
    '---\nunknown: [one, two]\n---\n\n:::orbit-extension\n{{view:unknown}}\n[^f]: Footnote\n<div>Untouched</div>\n',
    '# CRLF\r\n\r\nText **bold**\r\n\r\n```dart\r\ncode\r\n```\r\n',
    '# Heading without final newline',
    '```unfinished\n  preserve\n',
  ];
  for (var i = 0; i < fixtures.length; i++) {
    test('lossless projection preserves fixture $i exactly', () {
      expect(MarkdownDocument.parse(fixtures[i]).source, fixtures[i]);
    });
  }
  test(
    'editing one paragraph preserves all unrelated source bytes and reopens',
    () async {
      final repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      final body = fixtures.join('\n');
      final note = await repo.create(
        typeId: 'orbit.note',
        title: 'Lecture',
        body: body,
        properties: {
          'unknown': {'retain': true},
        },
      );
      final document = MarkdownDocument.parse(note.body);
      final block = document.blocks.firstWhere(
        (b) => b.kind == MarkdownBlockKind.heading,
      );
      block.source = block.replaceContent('Edited heading');
      final saved = await repo.save(note.copyWith(body: document.source));
      await repo.refresh();
      expect(repo.objects.single.body, saved.body);
      expect(repo.objects.single.properties['unknown'], {'retain': true});
      final encoded = ObjectCodec().encode(saved);
      final decoded = ObjectCodec().decode(
        encoded,
        repo.workspaceId,
        markdown: true,
      );
      expect(decoded.body, saved.body);
      expect(saved.body.replaceFirst('Edited heading', 'Heading'), body);
      await repo.close();
    },
  );
  test(
    'inline editing retains original markers, link identity and unaffected syntax',
    () {
      expect(
        InlineProjection('**important** and _quiet_').text,
        'important and quiet',
      );
      expect(
        InlineProjection('**important** and _quiet_').edit(
          'important concept and quiet',
          selectionStart: 9,
          selectionEnd: 9,
        ),
        '**important concept** and _quiet_',
      );
      expect(
        InlineProjection('[Label](target.md)').edit('New label'),
        '[New label](target.md)',
      );
      expect(
        InlineProjection('[[stable-id|Readable]]').edit('Renamed label'),
        '[[stable-id|Renamed label]]',
      );
      expect(InlineProjection('a **bold** z').edit('a  z'), 'a  z');
    },
  );
  test(
    'shared splice history spans rich and source edits with bounded retention',
    () {
      final history = DocumentHistory();
      history.record('a', '**a**');
      history.record('**a**', '**ab**');
      expect(history.undo('**ab**'), '**a**');
      expect(history.undo('**a**'), 'a');
      expect(history.redo('a'), '**a**');
      var text = '';
      for (var i = 0; i < 1000; i++) {
        history.record(text, '${text}x');
        text += 'x';
      }
      expect(history.retainedCharacters, lessThan(1000));
    },
  );
  test('typing at every inline boundary preserves style and link targets', () {
    for (final (source, visible, offset, expected) in [
      ('**bold** plain', 'boldX plain', 4, '**boldX** plain'),
      ('plain **bold**', 'plain Xbold', 6, 'plain X**bold**'),
      ('_italic_ end', 'italicX end', 6, '_italicX_ end'),
      ('~~old~~ end', 'oldX end', 3, '~~oldX~~ end'),
      ('`code` end', 'codeX end', 4, '`codeX` end'),
      ('***both***', 'bothX', 4, '***bothX***'),
      ('[[Identity|Label]] end', 'LabelX end', 5, '[[Identity|LabelX]] end'),
      ('[[Title]] end', 'TitleX end', 5, '[[Title|TitleX]] end'),
    ]) {
      expect(
        InlineProjection(
          source,
        ).edit(visible, selectionStart: offset, selectionEnd: offset),
        expected,
        reason: source,
      );
      expect(InlineProjection(expected).text, visible);
    }
    expect(
      InlineProjection('***both***').styles.first,
      containsAll(['bold', 'italic']),
    );
    final projection = InlineProjection('a **bold** z');
    expect(
      projection.edit('a bXz', selectionStart: 3, selectionEnd: 7),
      'a **bX**z',
    );
    expect(projection.visibleOffset(projection.sourceOffset(4)), 4);
  });
  test('smart lists continue, exit, indent and preserve code/composition', () {
    TextEditingValue atEnd(String s) => TextEditingValue(
      text: s,
      selection: TextSelection.collapsed(offset: s.length),
    );
    expect(MarkdownEditing.continueList(atEnd('- item'))!.text, '- item\n- ');
    expect(
      MarkdownEditing.continueList(atEnd('  2. second'))!.text,
      '  2. second\n  3. ',
    );
    expect(
      MarkdownEditing.continueList(atEnd('- [x] done'))!.text,
      '- [x] done\n- [ ] ',
    );
    expect(MarkdownEditing.continueList(atEnd('- [ ] '))!.text, '');
    expect(MarkdownEditing.continueList(atEnd('```md\n- example')), isNull);
    expect(
      MarkdownEditing.continueList(
        atEnd(
          '- composing',
        ).copyWith(composing: const TextRange(start: 2, end: 5)),
      ),
      isNull,
    );
    final indent = MarkdownEditing.indentList(atEnd('- item'))!;
    expect(indent.text, '  - item');
    expect(MarkdownEditing.indentList(indent, outdent: true)!.text, '- item');
  });
  test(
    'table parser preserves escaped cells and alignment; explicit edits serialize',
    () {
      final table = MarkdownTable.tryParse(fixtures[2])!;
      expect(table.rows[1][0], r'A \| B');
      expect(table.alignments, [':---', '---:']);
      table.rows[1][1] = 'Changed';
      expect(MarkdownTable.tryParse(table.encode())!.rows[1][1], 'Changed');
      expect(
        MarkdownTable.tryParse('| A | B |\n| --- | --- |\n| Only one |'),
        isNull,
      );
    },
  );
}
