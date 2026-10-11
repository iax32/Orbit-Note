import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/bibtex.dart';
import 'package:orbit_note/domain/citation_library.dart';
import 'package:orbit_note/domain/document_citations.dart';
import 'package:orbit_note/features/notes/citation_import_dialog.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  const bib = r'''
% ordinary comments
@article{Ada2026,
 title = {A {Game} with commas, "quotes" and {nested {braces}}},
 author = "Lovelace, Ada and Roe, Jane",
 year = 2026,
 journal = {Research Journal},
 doi = {10.1234/example},
 url = {https://example.org/paper},
 pages = {12--42},
 custom_field = {preserve {this}},
}
@book(Other, title="Second book", publisher={Press}, year=2025)
''';
  test('braces, quotes, commas, comments and parenthesized entries parse', () {
    final parsed = BibtexImport(bib);
    expect(parsed.records.length, 2);
    final source = CitationSource.fromJson(parsed.records.first);
    expect(source.title, contains('nested braces'));
    expect(source.author, 'Lovelace, Ada and Roe, Jane');
    expect(source.publisher, 'Research Journal');
    expect(source.doi, '10.1234/example');
    expect(BibtexImport('\ufeff$bib').records.length, 2);
    expect(
      BibtexImport(
        r'@misc{literal,title={A \{literal\} label}}',
      ).records.single['title'],
      'A {literal} label',
    );
  });
  test(
    'unknown fields and original TeX survive import, editing and export',
    () {
      final plan = CitationImportPlan(
        'A note.',
        BibtexImport(bib).records,
        CitationImportPolicy.keepExisting,
      );
      final model = DocumentCitations(plan.result);
      var output = exportBibtex(model);
      expect(output, contains('custom_field = {preserve {this}}'));
      expect(output, contains('pages = {12--42}'));
      expect(output, contains(r'{nested {braces}}'));
      expect(BibtexImport(output).records.length, 2);
      final saved = model.save(
        const CitationSource(
          id: 'Ada2026',
          title: 'Updated title',
          author: 'New author',
          publisher: 'New journal',
        ),
      );
      output = exportBibtex(DocumentCitations(saved));
      expect(output, contains('journal = {New journal}'));
      expect(output, contains('custom_field = {preserve {this}}'));
      final imported = BibtexImport(output);
      expect(
        CitationSource.fromJson(imported.records.first).title,
        'Updated title',
      );
      expect(CitationSource.fromJson(imported.records.first).doi, isEmpty);
    },
  );
  test(
    'macros and preambles are not evaluated, malformed data fails explicitly',
    () {
      final parsed = BibtexImport(
        r'@string{j="A {nested} journal"} @preamble{"text"} @article{macro,title=j} @misc{good,title={A} # { title},year=2026}',
      );
      expect(parsed.records.single['title'], 'A title');
      expect(parsed.warnings.join(), contains('unresolved macros'));
      for (final text in [
        '@book{x,title={unclosed}',
        '@book{x,title="unclosed}',
        '@book{x,title={A},title={B}}',
        '@book{x,title={${'{' * 65}A${'}' * 65}}}',
      ]) {
        expect(() => BibtexImport(text), throwsFormatException, reason: text);
      }
      expect(
        () => BibtexImport('x' * (1024 * 1024 + 1)),
        throwsFormatException,
      );
      expect(
        BibtexImport('@misc{bad,url={javascript:evil},title={Unsafe}}').records,
        isEmpty,
      );
    },
  );
  test('key and DOI policies are explicit and preserve citation identity', () {
    const original = CitationSource(
      id: 'Ada2026',
      title: 'Old',
      doi: 'https://doi.org/10.1234/EXAMPLE',
    );
    final source =
        '${original.marker}\nClaim ${DocumentCitations.citation(original, 'p. 1')}';
    final incoming = BibtexImport(
      '@misc{Different,title={New},doi={doi:10.1234/example}}',
    ).records;
    final kept = CitationImportPlan(
      source,
      incoming,
      CitationImportPolicy.keepExisting,
    );
    expect(kept.skipped, 1);
    expect(kept.result, source);
    final renamed = CitationImportPlan(
      source,
      incoming,
      CitationImportPolicy.renameIncoming,
    );
    expect(
      DocumentCitations(renamed.result).sources.keys,
      containsAll(['Ada2026', 'Different-2']),
    );
    final replaced = CitationImportPlan(
      source,
      incoming,
      CitationImportPolicy.replaceExisting,
    );
    final model = DocumentCitations(replaced.result);
    expect(model.sources.keys, ['Ada2026']);
    expect(model.sources['Ada2026']!.title, 'New');
    expect(model.occurrences.single.id, 'Ada2026');
  });
  test(
    'ambiguous duplicates and contradictory DOI/key matches cannot overwrite',
    () {
      const a = CitationSource(id: 'a', title: 'A', doi: '10/a');
      const b = CitationSource(id: 'b', title: 'B', doi: '10/b');
      final records = [
        const CitationSource(id: 'a', title: 'Incoming', doi: '10/b').toJson(),
      ];
      expect(
        () => CitationImportPlan(
          '${a.marker}\n${b.marker}',
          records,
          CitationImportPolicy.replaceExisting,
        ),
        throwsFormatException,
      );
      expect(
        () => CitationImportPlan('', [
          a.toJson(),
          a.toJson(),
        ], CitationImportPolicy.renameIncoming),
        throwsFormatException,
      );
    },
  );
  test(
    'library snapshots preserve extra records without creating citations',
    () {
      final saved = CitationImportPlan(
        '',
        BibtexImport(bib).records,
        CitationImportPolicy.keepExisting,
      ).result;
      final library = sourceLibraryBody(DocumentCitations(saved));
      final reopened = DocumentCitations(library);
      expect(reopened.sources.length, 2);
      expect(reopened.occurrences, isEmpty);
      expect(exportBibtex(reopened), contains('custom_field'));
      final reused = CitationImportPlan('Other note.', [
        ...reopened.sources.keys.map(reopened.record),
      ], CitationImportPolicy.keepExisting);
      expect(DocumentCitations(reused.result).sources.length, 2);
    },
  );
  test('batch imports 1,000 sources and rejects a larger import', () {
    final input = List.generate(
      1000,
      (i) => '@misc{k$i,title={Source $i}}',
    ).join('\n');
    final result = CitationImportPlan(
      'Keep this prose.',
      BibtexImport(input).records,
      CitationImportPolicy.keepExisting,
    );
    expect(result.added, 1000);
    expect(DocumentCitations(result.result).sources.length, 1000);
    expect(result.result, startsWith('Keep this prose.'));
    expect(
      () => BibtexImport('$input\n@misc{last,title={Too many}}'),
      throwsFormatException,
    );
  });
  test(
    'export rejects crafted field injection and metadata in code stays literal',
    () {
      const item = CitationSource(id: 'a', title: 'A');
      final record = {
        ...item.toJson(),
        'bibtex': {
          'fields': {'custom': '} @misc{evil,title={Injected}'},
        },
      };
      final model = DocumentCitations(DocumentCitations('').saveRecord(record));
      expect(() => exportBibtex(model), throwsFormatException);
      expect(
        exportBibtex(DocumentCitations('```\n${item.marker}\n```')),
        isNot(contains('@misc{a')),
      );
    },
  );
  testWidgets('reviewed import selects records before returning a plan', (
    tester,
  ) async {
    CitationImportPlan? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showCitationImport(context, 'Original.');
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      '@misc{one,title={First}}\n@misc{two,title={Second}}',
    );
    await tester.tap(find.text('Preview import'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Second'),
      150,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import selected sources'));
    await tester.pumpAndSettle();
    expect(result!.added, 1);
    expect(DocumentCitations(result!.result).sources.keys, ['one']);
    expect(tester.takeException(), isNull);
  });
  testWidgets('narrow enlarged-text library import remains usable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const source = CitationSource(
      id: 'a',
      title: 'A long source title that wraps across multiple lines',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: CitationImportDialog(
              source: '',
              libraries: [
                CitationLibrary(
                  'canonical-id',
                  'Research library',
                  source.marker,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.byType(DropdownButtonFormField<String>),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Research library').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(source.title), 100);
    await tester.pumpAndSettle();
    expect(find.text(source.title), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test(
    'library is a canonical note and survives repository reopen and failed saving',
    () async {
      final store = MemoryStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      final metadata = CitationImportPlan(
        '',
        BibtexImport(bib).records,
        CitationImportPolicy.keepExisting,
      ).result;
      final library = await repo.create(
        typeId: 'orbit.note',
        title: 'Research library',
        body: sourceLibraryBody(DocumentCitations(metadata)),
        properties: {
          'citationLibrary': 1,
          'unknown': {'keep': true},
        },
      );
      await repo.close();
      final reopened = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await reopened.initialize();
      final object = reopened.objects.singleWhere((o) => o.id == library.id);
      expect(object.properties['citationLibrary'], 1);
      expect(object.properties['unknown'], {'keep': true});
      expect(
        exportBibtex(DocumentCitations(object.body)),
        contains('custom_field'),
      );
      store.failWrites = true;
      await expectLater(
        reopened.save(object.copyWith(body: 'Damaged replacement')),
        throwsA(anything),
      );
      store.failWrites = false;
      await reopened.close();
      final recovered = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await recovered.initialize();
      expect(
        recovered.objects.singleWhere((o) => o.id == library.id).body,
        object.body,
      );
      await recovered.close();
    },
  );
}
