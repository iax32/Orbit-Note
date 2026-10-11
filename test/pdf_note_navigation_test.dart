import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/domain/research_document.dart';
import 'support/memory_store.dart';
import 'support/pdf_fixture.dart';

void main() {
  late WorkspaceRepository repo;
  late ProviderContainer container;
  late WorkspaceController c;
  setUp(() async {
    repo = WorkspaceRepository(
      store: MemoryStore(),
      index: MemoryObjectIndex(),
    );
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    container.read(workspaceProvider);
    c = container.read(workspaceProvider.notifier);
    while (c.loading) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  });
  tearDown(() async {
    await c.flushAll();
    container.dispose();
  });

  test(
    'opening an annotation opens its actual note and precise source beside it',
    () async {
      final file = await repo.importAttachment(
        name: 'Paper.pdf',
        bytes: researchPdf(),
      );
      await c.refresh();
      final note = await c.createPdfPageComment(
        file.id,
        file.properties['checksum'] as String,
        2,
        'Observation',
      );
      final count = c.activeObjects.length;
      c.session.noteViews = {
        'pdf:primary:${file.id}': {'page': 1, 'zoom': 1.7},
      };
      c.openPdfNote(note!.id);
      expect(c.session.activeId, note.id);
      expect(c.session.secondaryId, file.id);
      final view = c.session.noteViews['pdf:secondary:${file.id}']!;
      expect(view['page'], 2);
      expect(view['annotationId'], note.id);
      // A new narrower pane fits its width; an existing secondary zoom survives.
      expect(view['zoom'], isNull);
      c.session.noteViews['pdf:secondary:${file.id}']!['zoom'] = 1.2;
      final request = view['request'] as int;
      expect(c.openPdfSource(note.id), isTrue);
      expect(c.session.noteViews['pdf:secondary:${file.id}']!['zoom'], 1.2);
      expect(
        c.session.noteViews['pdf:secondary:${file.id}']!['request'],
        request + 1,
      );
      expect(c.activeObjects.length, count);
      c.edit(file.id, properties: {...file.properties, 'checksum': 'replaced'});
      c.openPdfNote(note.id);
      expect(c.session.activeId, note.id);
      expect(
        c.session.noteViews['pdf:secondary:${file.id}']!['annotationId'],
        isNull,
      );
    },
  );

  test(
    'connected notes include backlinks and provenance once, excluding unrelated notes',
    () async {
      final file = await repo.importAttachment(
        name: 'Paper.pdf',
        bytes: researchPdf(),
      );
      final linked = await repo.create(
        typeId: 'orbit.note',
        title: 'Existing note',
        body: 'Evidence [[${file.id}#page=2|Paper]]',
      );
      await repo.create(
        typeId: 'orbit.note',
        title: 'Unrelated',
        body: 'Other',
      );
      await c.refresh();
      final research = await c.createPdfQuote(
        file.id,
        1,
        '',
        document: ResearchDocument.research,
        expectedChecksum: file.properties['checksum'] as String,
      );
      final ids = c.pdfLinkedNotes(file.id).map((o) => o.id).toList();
      expect(ids.toSet(), {linked.id, research!.id});
      expect(ids, hasLength(2));
      c.session.noteViews = {
        'pdf:primary:${file.id}': {'page': 2, 'zoom': 1.8},
      };
      c.openPdfNote(linked.id, besidePdfId: file.id);
      expect(c.session.activeId, linked.id);
      expect(c.session.secondaryId, file.id);
      expect(c.session.noteViews['pdf:secondary:${file.id}']!['page'], 2);
      expect(
        await c.createPdfQuote(file.id, 1, 'Stale', expectedChecksum: 'old'),
        isNull,
      );
    },
  );

  test(
    'missing or malformed PDF source never prevents opening the note',
    () async {
      final note = await repo.create(
        typeId: 'orbit.note',
        title: 'Recovered research',
        properties: {
          'pdfSource': {'objectId': 45, 'page': 'bad'},
        },
      );
      await c.refresh();
      expect(c.openPdfSource(note.id), isFalse);
      c.openPdfNote(note.id);
      expect(c.session.activeId, note.id);
    },
  );
}
