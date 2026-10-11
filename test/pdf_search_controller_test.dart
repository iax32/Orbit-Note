import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/domain/object_reference.dart';
import 'package:orbit_note/domain/pdf_search.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/workspace_store.dart';
import 'support/memory_store.dart';
import 'pdf_search_indexer_test.dart' show until;

class GatedRepository extends WorkspaceRepository {
  GatedRepository(MemoryStore store)
    : super(store: store, index: MemoryObjectIndex());
  Completer<void>? gate;
  @override
  Future<String?> pdfSourceChecksum(String path) async {
    await gate?.future;
    return super.pdfSourceChecksum(path);
  }
}

class WatchingPdfStore extends MemoryStore
    implements WorkspaceAttachmentChangeSource {
  final events = StreamController<String>.broadcast();
  @override
  Stream<String> get attachmentChanges => events.stream;
}

void main() {
  late MemoryStore store;
  late GatedRepository repo;
  late ProviderContainer container;
  late WorkspaceController c;
  setUp(() async {
    store = WatchingPdfStore();
    repo = GatedRepository(store);
    container = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        workspaceProvider.overrideWith(
          () => WorkspaceController(
            pdfTextExtractor: (bytes) async* {
              yield PdfTextPage(
                1,
                bytes.first == 1 ? 'old needle' : 'new phrase',
                2,
              );
              yield const PdfTextPage(2, 'needle on page two', 2);
            },
          ),
        ),
      ],
    );
    container.read(workspaceProvider);
    c = container.read(workspaceProvider.notifier);
    await until(() => !c.loading);
  });
  tearDown(() async {
    if (repo.gate != null && !repo.gate!.isCompleted) repo.gate!.complete();
    await c.closeWorkspace();
    container.dispose();
    await (store as WatchingPdfStore).events.close();
  });

  test(
    'global PDF results open exact page with ephemeral offsets and checksum',
    () async {
      final file = await repo.importAttachment(
        name: 'Research.pdf',
        bytes: Uint8List.fromList([1]),
      );
      // Older file records can identify PDFs by filename without MIME metadata.
      await repo.save(
        file.copyWith(properties: {...file.properties}..remove('mimeType')),
      );
      await c.refresh();
      await until(() => c.pdfIndexEntries[file.id]?.phase == 'Indexed');
      final match = (await c.searchLocations(
        'needle',
      )).where((r) => r.location.page == 2).single;
      c.openSearchResult(match);
      await until(() => c.session.activeId == file.id);
      expect(c.locationRequests[file.id]!.reference.page, 2);
      expect(c.locationRequests[file.id]!.offset, 0);
      expect(
        c.pdfSearchRequests[file.id]!.sourceChecksum,
        match.sourceChecksum,
      );
      final view = c.session.noteViews['pdf:primary:${file.id}']!;
      expect(view['page'], 2);
      expect(view.containsKey('offset'), isFalse);
      expect(view.containsKey('sourceChecksum'), isFalse);
      c.requestLocation(ObjectReference(file.id, page: 1));
      expect(c.pdfSearchRequests, isEmpty);
    },
  );

  test(
    'opening a stale result verifies actual bytes even when no watcher event arrived',
    () async {
      final file = await repo.importAttachment(
        name: 'Research.pdf',
        bytes: Uint8List.fromList([1]),
      );
      await c.refresh();
      await until(() => c.pdfIndexEntries[file.id]?.phase == 'Indexed');
      final match = (await c.searchLocations('old')).single;
      store.files[file.properties['contentRef']] = Uint8List.fromList([9]);
      c.openSearchResult(match);
      await until(() => c.error != null);
      expect(c.error, contains('changed'));
      expect(c.session.activeId, isNull);
      expect(c.pdfSearchRequests, isEmpty);
      expect(c.isCurrentSearchResult(match), isFalse);
      await until(() => c.pdfIndexEntries[file.id]?.phase == 'Indexed');
      expect(
        (await c.searchLocations(
          'old',
        )).where((r) => r.matchKind == 'PDF text'),
        isEmpty,
      );
      expect(
        (await c.searchLocations(
          'new',
        )).where((r) => r.matchKind == 'PDF text'),
        hasLength(1),
      );
    },
  );

  test(
    'navigation during async source verification cannot steal focus later',
    () async {
      final file = await repo.importAttachment(
        name: 'Research.pdf',
        bytes: Uint8List.fromList([1]),
      );
      final note = await repo.create(
        typeId: 'orbit.note',
        title: 'Current note',
      );
      await c.refresh();
      await until(() => c.pdfIndexEntries[file.id]?.phase == 'Indexed');
      final match = (await c.searchLocations('old')).single;
      repo.gate = Completer<void>();
      c.openSearchResult(match);
      c.openObject(note.id);
      repo.gate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(c.session.activeId, note.id);
      expect(c.pdfSearchRequests, isEmpty);
      expect(c.error, isNull);
    },
  );

  test(
    'focus recheck reindexes changed attachment bytes without modifying metadata',
    () async {
      final file = await repo.importAttachment(
        name: 'Research.pdf',
        bytes: Uint8List.fromList([1]),
      );
      await c.refresh();
      await until(() => c.pdfIndexEntries[file.id]?.phase == 'Indexed');
      final match = (await c.searchLocations('old')).single;
      store.files[file.properties['contentRef']] = Uint8List.fromList([9]);
      await c.checkExternalChanges();
      expect(c.isCurrentSearchResult(match), isFalse);
      await until(() => c.pdfIndexEntries[file.id]?.phase == 'Indexed');
      expect(
        c.find(file.id)!.properties['checksum'],
        file.properties['checksum'],
      );
      expect(
        (await c.searchLocations(
          'new',
        )).where((r) => r.matchKind == 'PDF text'),
        hasLength(1),
      );
    },
  );

  test(
    'attachment watcher invalidates a result before the UI debounce and resumes indexing',
    () async {
      final file = await repo.importAttachment(
        name: 'Research.pdf',
        bytes: Uint8List.fromList([1]),
      );
      await c.refresh();
      await until(() => c.pdfIndexEntries[file.id]?.phase == 'Indexed');
      final match = (await c.searchLocations('old')).single;
      c.pausePdfIndex(true);
      store.files[file.properties['contentRef']] = Uint8List.fromList([9]);
      (store as WatchingPdfStore).events.add(
        file.properties['contentRef'] as String,
      );
      await until(() => !c.isCurrentSearchResult(match));
      expect(c.pdfIndexEntries[file.id]!.phase, 'Pending');
      c.pausePdfIndex(false);
      await until(() => c.pdfIndexEntries[file.id]?.phase == 'Indexed');
      expect(
        (await c.searchLocations(
          'new',
        )).where((r) => r.matchKind == 'PDF text'),
        hasLength(1),
      );
    },
  );

  test(
    'closing the Vault cancels a pending navigation without late errors',
    () async {
      final file = await repo.importAttachment(
        name: 'Research.pdf',
        bytes: Uint8List.fromList([1]),
      );
      await c.refresh();
      await until(() => c.pdfIndexEntries[file.id]?.phase == 'Indexed');
      final match = (await c.searchLocations('old')).single;
      repo.gate = Completer<void>();
      c.openSearchResult(match);
      await c.closeWorkspace();
      store.files.remove(file.properties['contentRef']);
      repo.gate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(c.hasWorkspace, isFalse);
      expect(c.error, isNull);
      expect(c.pdfSearchRequests, isEmpty);
    },
  );
}
