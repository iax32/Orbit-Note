import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/pdf_annotation.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';
import 'support/pdf_fixture.dart';

void main() {
  test(
    'annotated copy persists separately; stale edits and failed saves retain originals',
    () async {
      final store = MemoryStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      container.read(workspaceProvider);
      final c = container.read(workspaceProvider.notifier);
      while (c.loading) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      try {
        final original = researchPdf();
        final source = await repo.importAttachment(
          name: 'Source.pdf',
          bytes: original,
        );
        await c.refresh();
        final note = await c.createPdfPageComment(
          source.id,
          source.properties['checksum'] as String,
          1,
          'Keep this comment',
        );
        expect(note, isNotNull);
        final snapshot = PdfAnnotation(c.find(note!.id)!);
        // Persistence is byte-agnostic: the native export tests verify real PDF content.
        final copyBytes = Uint8List.fromList([...original, 10]);
        store.failWrites = true;
        expect(
          await c.saveAnnotatedPdfCopy(c.find(source.id)!, [
            snapshot,
          ], copyBytes),
          isFalse,
        );
        store.failWrites = false;
        expect(c.find(note.id)!.body, contains('Keep this comment'));
        expect(
          await c.saveAnnotatedPdfCopy(c.find(source.id)!, [
            snapshot,
          ], copyBytes),
          isTrue,
        );
        final copies = c.activeObjects
            .where((o) => o.typeId == 'orbit.file' && o.id != source.id)
            .toList();
        expect(copies, hasLength(1));
        expect(copies.single.title, 'Source · annotated.pdf');
        expect(
          await repo.readAttachment(source.properties['contentRef'] as String),
          original,
        );
        c.edit(note.id, body: 'Newer comment');
        expect(
          await c.saveAnnotatedPdfCopy(c.find(source.id)!, [
            snapshot,
          ], copyBytes),
          isFalse,
        );
        await c.flushAll();
        final oldSource = c.find(source.id)!;
        c.edit(
          source.id,
          properties: {...oldSource.properties, 'checksum': 'replaced'},
        );
        expect(
          await c.saveAnnotatedPdfCopy(oldSource, [
            PdfAnnotation(c.find(note.id)!),
          ], copyBytes),
          isFalse,
        );
        await c.flushAll();
        final reopened = WorkspaceRepository(
          store: store,
          index: MemoryObjectIndex(),
        );
        await reopened.initialize();
        expect(
          await reopened.readAttachment(
            copies.single.properties['contentRef'] as String,
          ),
          copyBytes,
        );
        expect(
          await reopened.readAttachment(
            source.properties['contentRef'] as String,
          ),
          original,
        );
        expect(
          reopened.objects.singleWhere((o) => o.id == note.id).body,
          'Newer comment',
        );
        await reopened.close();
      } finally {
        store.failWrites = false;
        await c.flushAll();
        container.dispose();
      }
    },
  );
}
