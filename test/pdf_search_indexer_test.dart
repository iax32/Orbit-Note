import 'dart:async';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/pdf_search_indexer.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/application/workspace_search.dart';
import 'package:orbit_note/domain/pdf_search.dart';
import 'package:orbit_note/domain/search_workspace.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/workspace_store.dart';
import 'support/memory_store.dart';

Future<void> until(bool Function() done) async {
  for (var i = 0; i < 500 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  expect(
    done(),
    isTrue,
    reason: 'Background indexing did not reach expected state',
  );
}

class FailingCache extends MemoryObjectIndex {
  @override
  Future<void> writePdfText(String id, Map<String, dynamic> document) async {
    throw StateError('Disk unavailable');
  }
}

class SizedPdfStore extends MemoryStore implements WorkspaceFileSizeStore {
  int attachmentReads = 0;
  @override
  Future<int> fileSize(String path) async => 101 * 1024 * 1024;
  @override
  Future<Uint8List?> read(String path) async {
    if (path.startsWith('Attachments/')) attachmentReads++;
    return super.read(path);
  }
}

void main() {
  late MemoryStore store;
  late MemoryObjectIndex cache;
  late WorkspaceRepository repo;
  late UniversalObject pdf;
  late PdfSearchIndexer indexer;
  final original = Uint8List.fromList([1, 2, 3]);
  Future<void> setup({MemoryObjectIndex? index}) async {
    store = MemoryStore();
    cache = index ?? MemoryObjectIndex();
    repo = WorkspaceRepository(store: store, index: cache);
    await repo.initialize();
    pdf = await repo.importAttachment(name: 'Research.pdf', bytes: original);
  }

  PdfSearchIndexer start(PdfTextExtractor extractor) {
    indexer = PdfSearchIndexer(repo, extract: extractor, onChanged: () {});
    indexer.synchronize(repo.objects);
    return indexer;
  }

  tearDown(() async {
    await indexer.close();
    await repo.close();
  });

  test(
    'complete pages publish exact UTF-16 matches without changing originals',
    () async {
      await setup();
      final before = {
        for (final entry in store.files.entries)
          entry.key: List<int>.of(entry.value),
      };
      start((_) async* {
        yield const PdfTextPage(1, '😀 Needle and another needle.', 2);
        yield const PdfTextPage(2, 'A NEEDLE on the next page.', 2);
      });
      await until(() => !indexer.running);
      final doc = indexer.documents[pdf.id]!;
      final matches = doc.search(pdf, 'needle');
      expect(matches.map((m) => m.location.page), [1, 1, 2]);
      expect(matches.first.sourceOffset, 3);
      expect(matches.first.matchLength, 6);
      expect(matches.first.sourceChecksum, sha256.convert(original).toString());
      expect(matches.first.sourcePath, pdf.properties['contentRef']);
      for (final match in matches) {
        expect(
          match.matchedText
              .substring(
                match.excerptOffset!,
                match.excerptOffset! + match.excerptLength!,
              )
              .toLowerCase(),
          'needle',
        );
      }
      expect(
        matches[1].excerptOffset,
        greaterThan(matches.first.excerptOffset!),
      );
      expect(indexer.entries[pdf.id]!.phase, 'Indexed');
      expect(await repo.readPdfTextCache(pdf.id), isNotNull);
      expect(store.files, before);
      expect(repo.objects.single.properties, pdf.properties);
    },
  );

  test(
    'partial progress is visible but unsearchable; pause and resume rebuild safely',
    () async {
      await setup();
      final gate = Completer<void>();
      var attempts = 0, disposed = 0;
      start((_) async* {
        attempts++;
        try {
          yield const PdfTextPage(1, 'first needle', 2);
          if (attempts == 1) await gate.future;
          yield const PdfTextPage(2, 'second needle', 2);
        } finally {
          disposed++;
        }
      });
      await until(() => indexer.entries[pdf.id]?.pages == 1);
      expect(indexer.documents, isEmpty);
      expect(await repo.readPdfTextCache(pdf.id), isNull);
      indexer.setPaused(true);
      gate.complete();
      await until(() => !indexer.running);
      expect(indexer.entries[pdf.id]!.phase, 'Pending');
      expect(disposed, 1);
      indexer.setPaused(false);
      await until(() => indexer.entries[pdf.id]?.phase == 'Indexed');
      expect(attempts, 2);
      expect(disposed, 2);
      expect(indexer.documents[pdf.id]!.pages.length, 2);
    },
  );

  test(
    'external replacement during extraction cannot publish stale text',
    () async {
      await setup();
      final gate = Completer<void>();
      start((bytes) async* {
        yield PdfTextPage(
          1,
          bytes.first == 1 ? 'old needle' : 'current source',
          2,
        );
        await gate.future;
        yield const PdfTextPage(2, 'last page', 2);
      });
      await until(() => indexer.entries[pdf.id]?.pages == 1);
      final path = pdf.properties['contentRef'] as String;
      store.files[path] = Uint8List.fromList([9, 8, 7]);
      gate.complete();
      await until(() => !indexer.running);
      expect(indexer.entries[pdf.id]!.phase, 'Failed');
      expect(indexer.documents, isEmpty);
      expect(await repo.readPdfTextCache(pdf.id), isNull);
      indexer.retry();
      await until(() => indexer.entries[pdf.id]?.phase == 'Indexed');
      expect(indexer.documents[pdf.id]!.search(pdf, 'old'), isEmpty);
      expect(indexer.documents[pdf.id]!.search(pdf, 'current'), hasLength(1));
    },
  );

  test(
    'invalidation hides matches immediately and binds cache to actual new bytes',
    () async {
      await setup();
      var calls = 0;
      start((bytes) async* {
        calls++;
        yield PdfTextPage(1, bytes.first == 1 ? 'old needle' : 'new needle', 1);
      });
      await until(() => !indexer.running);
      final old = indexer.documents[pdf.id]!.search(pdf, 'needle').single;
      final path = pdf.properties['contentRef'] as String;
      store.files[path] = Uint8List.fromList([4]);
      indexer.invalidatePath(path);
      expect(indexer.isCurrent(old), isFalse);
      expect(indexer.documents, isEmpty);
      await until(() => !indexer.running);
      expect(calls, 2);
      expect(
        indexer.documents[pdf.id]!.checksum,
        sha256.convert([4]).toString(),
      );
      expect(pdf.properties['checksum'], old.sourceChecksum);
    },
  );

  test(
    'restart reuses verified cache and discards it when actual bytes change',
    () async {
      await setup();
      var calls = 0;
      Stream<PdfTextPage> extractor(Uint8List bytes) async* {
        calls++;
        yield PdfTextPage(1, 'version ${bytes.first}', 1);
      }

      start(extractor);
      await until(() => !indexer.running);
      await indexer.close();
      start(extractor);
      await until(() => !indexer.running);
      expect(calls, 1);
      store.files[pdf.properties['contentRef']] = Uint8List.fromList([8]);
      await indexer.close();
      start(extractor);
      await until(() => !indexer.running);
      expect(calls, 2);
      expect(indexer.documents[pdf.id]!.pages, ['version 8']);
    },
  );

  test(
    'missing, corrupt and incomplete PDFs expose failures and can be retried',
    () async {
      await setup();
      var fail = true;
      final path = pdf.properties['contentRef'] as String;
      store.files.remove(path);
      start((_) async* {
        if (fail) throw FormatException('Invalid PDF');
        yield const PdfTextPage(1, 'recovered needle', 1);
      });
      await until(() => !indexer.running);
      expect(indexer.entries[pdf.id]!.detail, contains('missing'));
      store.files[path] = original;
      indexer.retry();
      await until(() => !indexer.running);
      expect(indexer.entries[pdf.id]!.detail, contains('Invalid PDF'));
      fail = false;
      indexer.retry();
      await until(() => !indexer.running);
      expect(indexer.documents, hasLength(1));
      await indexer.close();
      await cache.removePdfText(pdf.id);
      start((_) async* {
        yield const PdfTextPage(1, 'partial needle', 2);
      });
      await until(() => !indexer.running);
      expect(indexer.documents, isEmpty);
      expect(indexer.entries[pdf.id]!.detail, contains('Incomplete'));
    },
  );

  test(
    'scanned and partially scanned PDFs report incomplete text coverage',
    () async {
      await setup();
      start((_) async* {
        yield const PdfTextPage(1, ' ', 1);
      });
      await until(() => !indexer.running);
      expect(indexer.entries[pdf.id]!.phase, 'No text');
      expect(indexer.entries[pdf.id]!.detail, contains('OCR'));
      expect(indexer.documents[pdf.id]!.search(pdf, 'needle'), isEmpty);
      await indexer.close();
      await cache.removePdfText(pdf.id);
      start((_) async* {
        yield const PdfTextPage(1, 'needle', 2);
        yield const PdfTextPage(2, '', 2);
      });
      await until(() => !indexer.running);
      expect(indexer.entries[pdf.id]!.phase, 'Indexed');
      expect(indexer.entries[pdf.id]!.detail, contains('1/2 pages'));
    },
  );

  test(
    'cache write failure preserves session search and reports the limitation',
    () async {
      await setup(index: FailingCache());
      start((_) async* {
        yield const PdfTextPage(1, 'needle', 1);
      });
      await until(() => !indexer.running);
      expect(indexer.documents[pdf.id]!.search(pdf, 'needle'), hasLength(1));
      expect(indexer.entries[pdf.id]!.detail, contains('could not be saved'));
    },
  );

  test(
    'closing cancels extraction and prevents late cache publication',
    () async {
      await setup();
      final gate = Completer<void>();
      var disposed = false;
      start((_) async* {
        try {
          yield const PdfTextPage(1, 'needle', 2);
          await gate.future;
          yield const PdfTextPage(2, 'needle', 2);
        } finally {
          disposed = true;
        }
      });
      await until(() => indexer.entries[pdf.id]?.pages == 1);
      final closing = indexer.close();
      gate.complete();
      await closing;
      expect(disposed, isTrue);
      expect(indexer.documents, isEmpty);
      expect(await repo.readPdfTextCache(pdf.id), isNull);
    },
  );

  test(
    'object deletion during extraction cannot resurrect old results',
    () async {
      await setup();
      final gate = Completer<void>();
      start((_) async* {
        yield const PdfTextPage(1, 'obsolete needle', 2);
        await gate.future;
        yield const PdfTextPage(2, 'obsolete needle', 2);
      });
      await until(() => indexer.entries[pdf.id]?.pages == 1);
      indexer.synchronize([]);
      gate.complete();
      await until(() => !indexer.running);
      expect(indexer.documents, isEmpty);
      expect(indexer.entries, isEmpty);
    },
  );

  test(
    'PDF pages join full candidates before project, folder and kind filtering',
    () async {
      await setup();
      final target = pdf.copyWith(
        properties: {...pdf.properties, 'project': 'Study', 'folder': 'Papers'},
      );
      final notes = [
        for (var i = 0; i < 130; i++)
          UniversalObject(
            id: 'note-$i',
            workspaceId: pdf.workspaceId,
            typeId: 'orbit.note',
            createdAt: pdf.createdAt,
            updatedAt: pdf.updatedAt,
            title: 'needle $i',
            body: 'needle',
            properties: {'project': 'Other'},
          ),
      ];
      final documents = {
        target.id: PdfTextDocument(
          pdf.properties['contentRef'] as String,
          'actual-hash',
          ['needle one', 'needle two'],
        ),
      };
      final results = await projectWorkspaceSearch(
        indexed: notes,
        snapshot: [...notes, target],
        drafts: {},
        query: 'needle',
        pdfDocuments: documents,
        limit: null,
      );
      expect(results.length, greaterThan(130));
      final filtered = const SearchOptions(
        project: 'Study',
        folder: 'Papers',
        kind: 'PDF',
      ).apply(results);
      expect(filtered, hasLength(2));
      expect(filtered.map((r) => r.location.page), [1, 2]);
      final moved = target.copyWith(
        properties: {...target.properties, 'contentRef': 'Attachments/new.pdf'},
      );
      expect(
        await projectWorkspaceSearch(
          indexed: [],
          snapshot: [moved],
          drafts: {},
          query: 'needle',
          pdfDocuments: documents,
          limit: null,
        ),
        isEmpty,
      );
    },
  );

  test(
    'relink invalidates cached matches and indexes the new source under the same UUID',
    () async {
      await setup();
      start((bytes) async* {
        yield PdfTextPage(1, bytes.first == 1 ? 'old needle' : 'new phrase', 1);
      });
      await until(() => !indexer.running);
      final old = indexer.documents[pdf.id]!.search(pdf, 'old').single;
      indexer.setPaused(true);
      final replacement = await repo.importAttachment(
        name: 'Replacement.pdf',
        bytes: Uint8List.fromList([9]),
      );
      final relinked = await repo.save(
        pdf.copyWith(properties: replacement.properties),
      );
      indexer.synchronize(repo.objects);
      expect(relinked.id, pdf.id);
      expect(indexer.isCurrent(old), isFalse);
      indexer.setPaused(false);
      await until(() => !indexer.running);
      expect(
        indexer.documents[pdf.id]!.path,
        replacement.properties['contentRef'],
      );
      expect(
        indexer.documents[pdf.id]!.search(relinked, 'new').single.object.id,
        pdf.id,
      );
      expect(store.files[pdf.properties['contentRef']], original);
    },
  );

  test('invalid derived cache data is rejected and can be rebuilt', () async {
    await setup();
    await cache.writePdfText(pdf.id, {
      'version': 1,
      'path': pdf.properties['contentRef'],
      'checksum': pdf.properties['checksum'],
      'pages': [],
    });
    start((_) async* {
      yield const PdfTextPage(1, 'fresh needle', 1);
    });
    await until(() => !indexer.running);
    expect(indexer.documents[pdf.id]!.pages, ['fresh needle']);
    expect(PdfTextDocument.parse({'version': 99}), isNull);
  });

  test(
    'oversized native sources fail before reads or hashing and unsafe paths are rejected',
    () async {
      store = SizedPdfStore();
      cache = MemoryObjectIndex();
      repo = WorkspaceRepository(store: store, index: cache);
      await repo.initialize();
      pdf = await repo.importAttachment(name: 'Large.pdf', bytes: original);
      (store as SizedPdfStore).attachmentReads = 0;
      var extracted = false;
      start((_) async* {
        extracted = true;
        yield const PdfTextPage(1, 'needle', 1);
      });
      await until(() => !indexer.running);
      expect(indexer.entries[pdf.id]!.detail, contains('100 MB'));
      expect((store as SizedPdfStore).attachmentReads, 0);
      expect(extracted, isFalse);
      await expectLater(
        repo.pdfSourceChecksum('../outside.pdf'),
        throwsA(isA<Object>()),
      );
      await expectLater(
        repo.readPdfSearchSource('Notes/source.pdf'),
        throwsA(isA<Object>()),
      );
    },
  );

  test(
    'oversized extracted text fails without publishing truncated search results',
    () async {
      await setup();
      start((_) async* {
        yield PdfTextPage(1, 'x' * (PdfTextDocument.maxTextCharacters + 1), 1);
      });
      await until(() => !indexer.running);
      expect(indexer.entries[pdf.id]!.detail, contains('32 Mi-character'));
      expect(indexer.documents, isEmpty);
      expect(await repo.readPdfTextCache(pdf.id), isNull);
    },
  );
}
