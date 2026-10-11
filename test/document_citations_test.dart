import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/document_citations.dart';
import 'package:orbit_note/domain/document_publication.dart';
import 'package:orbit_note/features/notes/citation_workspace.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';
import 'package:orbit_note/features/notes/export/publication_export.dart';

void main() {
  const a = CitationSource(
    id: 'a',
    title: 'Game Design',
    author: 'Zoe',
    year: '2026',
    doi: '10.123/test',
  );
  const b = CitationSource(
    id: 'b',
    title: 'Research',
    author: 'Ada',
    year: '2025',
    isbn: '123',
    url: 'https://example.org',
  );
  String sample() =>
      '${a.marker}\r\n${b.marker}\r\n\r\nFirst ${DocumentCitations.citation(a, 'p. 42')}. Then ${DocumentCitations.citation(b, '')}. Again ${DocumentCitations.citation(a, '')}.';

  test(
    'sources and citations survive reopening, style changes and repeated refresh',
    () {
      final input = sample();
      final numbered = DocumentCitations(input).refresh(numberedStyle: true);
      final reopened = DocumentCitations(numbered);
      expect(reopened.sources['a']!.doi, '10.123/test');
      expect(reopened.occurrences.length, 3);
      expect(numbered, contains('[1, p. 42]'));
      expect(numbered, contains('1. Zoe. (2026). Game Design'));
      expect(numbered, contains('2. Ada. (2025). Research'));
      expect(reopened.refresh(), numbered);
      final alphabetical = reopened.refresh(numberedStyle: false);
      expect(
        alphabetical.indexOf('- Ada.'),
        lessThan(alphabetical.indexOf('- Zoe.')),
      );
      expect(alphabetical, contains('(Zoe, 2026, p. 42)'));
      expect(input, contains('\r\n'));
    },
  );
  test('only used sources appear, and cited metadata cannot be deleted', () {
    final source =
        '${a.marker}\n${b.marker}\nText ${DocumentCitations.citation(a, '')}';
    final model = DocumentCitations(source);
    expect(model.refresh(), isNot(contains('- Ada.')));
    expect(() => model.remove('a'), throwsFormatException);
    expect(DocumentCitations(model.remove('b')).sources.keys, ['a']);
  });
  test('insertion rejects code, metadata and generated content', () {
    final text = DocumentCitations(sample()).refresh();
    final model = DocumentCitations(text);
    expect(model.canInsert(text.indexOf('First'), text.indexOf('First')), true);
    expect(model.canInsert(10, 10), false);
    final at = text.indexOf('## References') + 4;
    expect(model.canInsert(at, at), false);
    final label = text.indexOf('(Zoe, 2026');
    expect(model.canInsert(label + 1, label + 1), false);
    expect(DocumentCitations('`code`').canInsert(2, 2), false);
    expect(DocumentCitations('    code').canInsert(5, 5), false);
    expect(() => DocumentCitations('```unclosed').save(a), throwsStateError);
    expect(
      DocumentCitations(
        '```\n<!-- orbit:bibliography v=1 style=numbered -->\n<!-- /orbit:bibliography -->\n```',
      ).numbered,
      false,
    );
  });
  test('metadata edits keep unknown keys and refresh labels', () {
    final marker =
        '<!-- orbit:source ${jsonEncode({
          ...a.toJson(),
          'future': {'retained': true},
        })} -->';
    final model = DocumentCitations(
      '$marker\nText ${DocumentCitations.citation(a, '')}',
    );
    final saved = model.save(
      const CitationSource(
        id: 'a',
        title: 'Updated',
        author: 'New',
        year: '2027',
      ),
    );
    expect(saved, contains('"future":{"retained":true}'));
    expect(DocumentCitations(saved).refresh(), contains('(New, 2027)'));
  });
  test(
    'fenced, inline, indented code, comments and frontmatter remain literal',
    () {
      final example = '${a.marker}\n${DocumentCitations.citation(a, '')}';
      for (final input in [
        '```md\n$example\n```',
        '`$example`',
        '    ${a.marker}\n    ${DocumentCitations.citation(a, '')}',
        '<pre>$example</pre>',
        '---\nexample: ${a.marker}\n---',
      ]) {
        final model = DocumentCitations(input);
        expect(model.sources, isEmpty, reason: input);
        expect(model.occurrences, isEmpty, reason: input);
        expect(model.publication(), input, reason: input);
      }
    },
  );
  test('duplicates, unknown versions and missing references preserve source', () {
    final duplicate = DocumentCitations(
      '${a.marker}\n${a.marker}\n${DocumentCitations.citation(a, '')}',
    );
    expect(duplicate.warnings, isNotEmpty);
    expect(() => duplicate.save(a), throwsFormatException);
    final missing = DocumentCitations(DocumentCitations.citation(a, 'p. 2'));
    expect(missing.warnings.single, contains('Missing'));
    expect(missing.refresh(), missing.source);
    const future =
        '<!-- orbit:source {"v":2,"id":"a","title":"Future"} -->\n<!-- orbit:cite {"v":2} -->future<!-- /orbit:cite -->';
    expect(DocumentCitations(future).publication(), future);
    const unknown =
        '<!-- orbit:bibliography v=2 style=unknown -->keep<!-- /orbit:bibliography -->';
    expect(DocumentCitations(unknown).publication(), unknown);
    final multiple =
        '${DocumentCitations(sample()).refresh()}\n${DocumentCitations(sample()).refresh()}';
    expect(() => DocumentCitations(multiple).refresh(), throwsFormatException);
  });
  test('metadata cannot inject comments, markup or unsafe URLs', () {
    const injected = CitationSource(
      id: 'safe',
      title: '</script><!-- evil --> *text*',
    );
    expect(injected.marker, isNot(contains('</script>')));
    final output = DocumentCitations(
      '${injected.marker}\n${DocumentCitations.citation(injected, '')}',
    ).publication();
    expect(output, contains(r'\<'));
    expect(
      () => const CitationSource(
        id: 'a',
        title: 'Unsafe',
        url: 'javascript:alert(1)',
      ).validate(),
      throwsFormatException,
    );
    expect(
      () => const CitationSource(id: 'a', title: 'Two\nlines').validate(),
      throwsFormatException,
    );
  });
  test('Rich inline projection hides metadata with exact source ranges', () {
    final cite = DocumentCitations.citation(a, 'p. 42');
    final source = 'Before $cite after 😀';
    final projection = InlineProjection(source);
    expect(projection.text, 'Before (Zoe, 2026, p. 42) after 😀');
    final parsed = MarkdownDocument.parse('$cite\n');
    expect(parsed.blocks.first.kind, MarkdownBlockKind.text);
    expect(parsed.source, '$cite\n');
    expect(InlineProjection('`$cite`').text, cite);
    final erased = projection.edit(
      'Before  after 😀',
      selectionStart: 7,
      selectionEnd: projection.text.indexOf(' after'),
    );
    expect(erased, 'Before  after 😀');
    expect(DocumentCitations.metadataLine(a.marker), true);
    expect(
      DocumentCitations.metadataLine('<!-- orbit:source {"v":2} -->'),
      false,
    );
  });
  test(
    'publishing refreshes bibliography in HTML and Word without touching note',
    () {
      final input = sample();
      final document = PublicationDocument.parse(
        'Report',
        input,
        const PublicationStyle(),
      );
      final output = PublicationExport(document);
      expect(document.source, contains('## References'));
      expect(document.source, isNot(contains('orbit:cite')));
      expect(output.html(), contains('Game Design'));
      expect(output.html(), contains('References'));
      expect(output.docx(), isNotEmpty);
      expect(input, isNot(contains('## References')));
      expect(DocumentCitations(input).occurrences.length, 3);
    },
  );
  testWidgets('manager keeps actions accessible on narrow enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: CitationWorkspace(
              source: sample(),
              onApply: (before, next) {
                changed = next;
                return true;
              },
              onInsert: (_) {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Numbered bibliography'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Numbered bibliography'));
    await tester.pump();
    expect(changed, contains('style=numbered'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('editor inserts a located citation and hides metadata in Read', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var body = 'A claim.\n\n${a.marker}\n';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => NoteEditor(
              noteId: 'citations',
              title: 'Research',
              body: body,
              onTitleChanged: (_) {},
              onBodyChanged: (next) => update(() => body = next),
              linkTargets: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Source'));
    await tester.pumpAndSettle();
    final sourceField = find.byKey(const ValueKey('note-body'));
    await tester.tap(sourceField);
    tester.widget<TextField>(sourceField).controller!.selection =
        const TextSelection.collapsed(offset: 7);
    await tester.tap(find.byTooltip('Writing tools'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Citations & bibliography'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Cite'),
      150,
      scrollable: find
          .descendant(
            of: find.byType(CitationWorkspace),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cite'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'p. 42');
    await tester.tap(find.text('Insert citation'));
    await tester.pumpAndSettle();
    expect(DocumentCitations(body).occurrences.single.locator, 'p. 42');
    expect(body, contains('A claim<!-- orbit:cite'));
    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();
    expect(find.textContaining('orbit:source'), findsNothing);
    expect(
      find.textContaining('Zoe, 2026, p. 42', findRichText: true),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });
}
