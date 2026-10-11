import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/application/pdf_search_indexer.dart';
import 'package:orbit_note/domain/ocr_document.dart';
import 'package:orbit_note/domain/pdf_search.dart';
import 'package:orbit_note/features/notes/ocr_review_dialog.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/platform/ocr_pages.dart';
import 'package:orbit_note/platform/local_ocr.dart';
import 'support/memory_store.dart';
import 'pdf_search_indexer_test.dart' show until;

Map<String, dynamic> recognized([String text = 'ORBIT scanned evidence']) => {
  'text': text,
  'language': 'en-US',
  'total': 1,
  'lines': [
    {
      'start': 0,
      'end': text.length,
      'x': .1,
      'y': .2,
      'width': .7,
      'height': .08,
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryStore store;
  late WorkspaceRepository repo;
  late ProviderContainer container;
  late WorkspaceController c;
  Future<void> setup({
    OcrPageExtractor? extract,
    PdfTextExtractor? textExtract,
  }) async {
    store = MemoryStore();
    repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
    container = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        workspaceProvider.overrideWith(
          () => WorkspaceController(
            pdfTextExtractor:
                textExtract ??
                (_) async* {
                  yield const PdfTextPage(1, '', 1);
                },
            ocrExtractor:
                extract ??
                (_, _) async* {
                  yield recognized();
                },
          ),
        ),
      ],
    );
    container.read(workspaceProvider);
    c = container.read(workspaceProvider.notifier);
    await c.initialize();
    addTearDown(() async {
      await c.closeWorkspace();
      container.dispose();
    });
  }

  Future<String> attach([String name = 'scan.pdf', int variant = 1]) async {
    final file = await repo.importAttachment(
      name: name,
      bytes: Uint8List.fromList([variant, 2, 3]),
    );
    c.mergeRepositoryObjects();
    c.notify();
    return file.id;
  }

  test(
    'recognition geometry, UTF-16 offsets and correction fallback round trip',
    () {
      final page = recognized('😀 ORBIT');
      final doc = OcrDocument('Attachments/a.png', 'a' * 64, 'en', [page]);
      expect(doc.regions(0, 3, 8), hasLength(1));
      expect(OcrDocument.parse(doc.toJson())!.text(0), '😀 ORBIT');
      final corrected = OcrDocument(doc.path, doc.checksum, 'en', [
        {...page, 'corrected': 'fixed'},
      ]);
      expect(corrected.text(0), 'fixed');
      expect(corrected.regions(0, 0, 5), isEmpty);
      expect(corrected.pages[0]['text'], '😀 ORBIT');
    },
  );
  test('invalid bounds, excessive text and future versions fail closed', () {
    final good = OcrDocument('Attachments/a.png', 'a' * 64, 'en', [
      recognized(),
    ]).toJson();
    expect(OcrDocument.parse({...good, 'version': 2}), isNull);
    expect(
      OcrDocument.parse({
        ...good,
        'pages': [
          {
            'text': 'a',
            'lines': [
              {
                'start': 0,
                'end': 1,
                'x': double.nan,
                'y': 0,
                'width': 1,
                'height': 1,
              },
            ],
          },
        ],
      }),
      isNull,
    );
    expect(
      OcrDocument.parse({
        ...good,
        'pages': [
          {'text': 'a' * (OcrDocument.maxCharacters + 1), 'lines': []},
        ],
      }),
      isNull,
    );
  });
  test(
    'recognition becomes page-level search with source regions and linked passages',
    () async {
      await setup();
      final id = await attach();
      await c.recognizeFiles([id]);
      await until(() => c.pdfIndexEntries[id]?.phase == 'Indexed');
      final results = await c.searchLocations('scanned');
      final match = results.singleWhere(
        (r) => r.matchKind == 'Recognized text',
      );
      expect(match.location.page, 1);
      expect(match.sourceRegions, hasLength(1));
      expect(match.sourceChecksum, sha256.convert([1, 2, 3]).toString());
      final note = await c.createRecognitionNote(
        c.find(id)!,
        0,
        'scanned evidence',
      );
      expect(note!.body, contains('$id#page=1'));
      expect(note.properties['sourceChecksum'], match.sourceChecksum);
      expect(store.files[c.find(id)!.properties['contentRef']], [1, 2, 3]);
    },
  );
  test('image recognition participates in universal search', () async {
    await setup();
    final id = await attach('scan.png');
    await c.recognizeFiles([id]);
    await until(() => c.pdfIndexEntries[id]?.phase == 'Indexed');
    final matches = await c.searchLocations('evidence');
    expect(
      matches.where(
        (r) => r.object.id == id && r.matchKind == 'Recognized text',
      ),
      hasLength(1),
    );
  });
  test(
    'correction is durable, removes misleading geometry, and reset restores original',
    () async {
      await setup();
      final id = await attach();
      await c.recognizeFiles([id]);
      expect(
        await c.correctRecognition(c.find(id)!, 0, 'corrected phrase'),
        isTrue,
      );
      await until(() => c.pdfIndexEntries[id]?.phase == 'Indexed');
      expect(
        (await c.searchLocations('corrected')).single.sourceRegions,
        isEmpty,
      );
      await c.closeWorkspace();
      await c.initialize();
      await until(() => c.pdfIndexEntries[id]?.phase == 'Indexed');
      expect(
        OcrDocument.parse(c.find(id)!.properties['ocr'])!.text(0),
        'corrected phrase',
      );
      expect(await c.correctRecognition(c.find(id)!, 0, null), isTrue);
      expect(
        OcrDocument.parse(c.find(id)!.properties['ocr'])!.text(0),
        contains('scanned'),
      );
    },
  );
  test(
    're-recognition preserves corrections and unknown supported metadata',
    () async {
      await setup();
      final id = await attach();
      await c.recognizeFiles([id]);
      final before = c.find(id)!;
      await repo.save(
        before.copyWith(
          properties: {
            ...before.properties,
            'ocr': {
              ...before.properties['ocr'] as Map,
              'futureHint': {'keep': true},
            },
          },
        ),
      );
      c.mergeRepositoryObjects();
      c.notify();
      await c.correctRecognition(c.find(id)!, 0, 'authored correction');
      await c.recognizeFiles([id]);
      expect(c.find(id)!.properties['ocr']['futureHint'], {'keep': true});
      expect(
        OcrDocument.parse(c.find(id)!.properties['ocr'])!.text(0),
        'authored correction',
      );
    },
  );
  test('cancelled recognition publishes no partial durable result', () async {
    final gate = Completer<void>();
    await setup(
      extract: (_, _) async* {
        yield {...recognized(), 'total': 2};
        await gate.future;
        yield {...recognized(), 'total': 2};
      },
    );
    final id = await attach();
    final work = c.recognizeFiles([id]);
    await until(() => c.ocrStatus.contains('1/2'));
    c.cancelOcr();
    gate.complete();
    await work;
    expect(c.find(id)!.properties['ocr'], isNull);
    expect(c.ocrRunning, isFalse);
  });
  test(
    'paused recognition can cancel without deadlocking and preserves prior record',
    () async {
      final gate = Completer<void>();
      await setup(
        extract: (_, _) async* {
          await gate.future;
          yield recognized();
        },
      );
      final id = await attach();
      final work = c.recognizeFiles([id]);
      c.pauseOcr(true);
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(c.find(id)!.properties['ocr'], isNull);
      c.cancelOcr();
      await work;
      expect(c.ocrRunning, isFalse);
    },
  );
  test(
    'partial and failing engines report retryable errors and continue batch',
    () async {
      var count = 0;
      await setup(
        extract: (_, _) async* {
          if (count++ == 0) {
            yield {...recognized(), 'total': 2};
          } else {
            yield recognized();
          }
        },
      );
      final a = await attach('a.pdf'), b = await attach('b.png', 2);
      // Import deduplication intentionally shares bytes but keeps each source usable.
      await c.recognizeFiles([a, b]);
      expect(c.ocrFailures[a], contains('Incomplete'));
      expect(c.find(a)!.properties['ocr'], isNull);
      expect(c.find(b)!.properties['ocr'], isNotNull);
    },
  );
  test(
    'changed attachment and edited object reject staged recognition',
    () async {
      final gate = Completer<void>();
      await setup(
        extract: (_, _) async* {
          await gate.future;
          yield recognized();
        },
      );
      final id = await attach();
      final work = c.recognizeFiles([id]);
      await until(() => c.ocrStatus.contains('Verifying'));
      store.files[c.find(id)!.properties['contentRef']] = Uint8List.fromList([
        4,
      ]);
      gate.complete();
      await work;
      expect(c.find(id)!.properties['ocr'], isNull);
      expect(c.ocrFailures[id], contains('changed'));
    },
  );
  test(
    'changed source invalidates existing OCR matches without destroying corrections',
    () async {
      await setup();
      final id = await attach();
      await c.recognizeFiles([id]);
      await until(() => c.pdfIndexEntries[id]?.phase == 'Indexed');
      final match = (await c.searchLocations('scanned')).single;
      store.files[c.find(id)!.properties['contentRef']] = Uint8List.fromList([
        9,
      ]);
      c.openSearchResult(match);
      await until(() => c.error?.contains('changed') == true);
      await until(() => c.pdfIndexEntries[id]?.phase == 'No text');
      expect(await c.searchLocations('scanned'), isEmpty);
      expect(c.find(id)!.properties['ocr'], isNotNull);
      expect(await c.createRecognitionNote(c.find(id)!, 0, 'scanned'), isNull);
    },
  );
  test(
    'failed correction save retains original and rejects stale dialogs',
    () async {
      await setup();
      final id = await attach();
      await c.recognizeFiles([id]);
      final expected = c.find(id)!;
      store.failWrites = true;
      expect(await c.correctRecognition(expected, 0, 'new'), isFalse);
      expect(
        OcrDocument.parse(c.find(id)!.properties['ocr'])!.text(0),
        contains('scanned'),
      );
      store.failWrites = false;
      await c.correctRecognition(c.find(id)!, 0, 'one');
      expect(await c.correctRecognition(expected, 0, 'stale'), isFalse);
      expect(OcrDocument.parse(c.find(id)!.properties['ocr'])!.text(0), 'one');
    },
  );
  test(
    'platform adapter supplies bytes and missing engine has an honest fallback',
    () async {
      const channel = MethodChannel('orbit_note/ocr');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'recognize');
            expect(call.arguments, [1]);
            return recognized();
          });
      expect(
        (await recognizeLocalImage(Uint8List.fromList([1])))['text'],
        contains('ORBIT'),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await expectLater(
        recognizeLocalImage(Uint8List.fromList([1])),
        throwsA(isA<UnsupportedError>()),
      );
    },
  );
  test(
    'explicit corrections override embedded PDF text, including an empty correction',
    () async {
      await setup(
        textExtract: (_) async* {
          yield const PdfTextPage(1, 'embedded typo', 1);
        },
      );
      final id = await attach();
      await c.recognizeFiles([id]);
      await until(() => c.pdfIndexEntries[id]?.phase == 'Indexed');
      expect(
        (await c.searchLocations('embedded')).single.matchKind,
        'PDF text',
      );
      await c.correctRecognition(c.find(id)!, 0, 'corrected content');
      await until(() => c.pdfIndexEntries[id]?.phase == 'Indexed');
      expect(await c.searchLocations('embedded'), isEmpty);
      expect(
        (await c.searchLocations('corrected')).single.matchKind,
        'Recognized text',
      );
      await c.correctRecognition(c.find(id)!, 0, '');
      await until(() => c.pdfIndexEntries[id]?.phase == 'No text');
      expect(await c.searchLocations('corrected'), isEmpty);
      expect(c.pdfIndexEntries[id]!.detail, contains('no readable text'));
    },
  );
  test(
    'future recognition survives restart and unrelated edits without engine overwrite',
    () async {
      await setup();
      final id = await attach();
      await c.closeWorkspace();
      final path = repo.objectPath(id)!;
      final raw = jsonDecode(utf8.decode(store.files[path]!)) as Map;
      raw['object']['properties']['ocr'] = {
        'version': 99,
        'unknown': ['keep'],
      };
      store.files[path] = Uint8List.fromList(utf8.encode(jsonEncode(raw)));
      await c.initialize();
      await c.recognizeFiles([id]);
      expect(c.ocrFailures[id], contains('Unsupported'));
      final source = c.find(id)!;
      await repo.save(source.copyWith(title: 'Renamed source'));
      c.mergeRepositoryObjects();
      expect(c.find(id)!.properties['ocr'], {
        'version': 99,
        'unknown': ['keep'],
      });
    },
  );
  test(
    'recognition search rebuilds from portable metadata with an entirely new index',
    () async {
      await setup();
      final id = await attach('scan.png');
      await c.recognizeFiles([id]);
      await c.closeWorkspace();
      final rebuilt = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await rebuilt.initialize();
      final indexer = PdfSearchIndexer(
        rebuilt,
        extract: (_) async* {
          throw StateError('Image OCR must not use PDF extraction');
        },
        onChanged: () {},
      );
      indexer.synchronize(rebuilt.objects);
      await until(() => indexer.entries[id]?.phase == 'Indexed');
      expect(
        indexer.documents[id]!.search(
          rebuilt.objects.singleWhere((o) => o.id == id),
          'scanned',
        ),
        hasLength(1),
      );
      await indexer.close();
      await rebuilt.close();
    },
  );
  test(
    'editing a file while recognition is staged refuses the stale command',
    () async {
      final started = Completer<void>(), gate = Completer<void>();
      await setup(
        extract: (_, _) async* {
          started.complete();
          await gate.future;
          yield recognized();
        },
      );
      final id = await attach();
      final work = c.recognizeFiles([id]);
      await started.future;
      c.edit(id, title: 'New title');
      gate.complete();
      await work;
      expect(c.find(id)!.title, 'New title');
      expect(c.find(id)!.properties['ocr'], isNull);
      expect(c.ocrFailures[id], contains('changed'));
    },
  );
  testWidgets('recognition review is usable at narrow widths and 250% text', (
    tester,
  ) async {
    await tester.runAsync(() => setup());
    final id = await tester.runAsync(() => attach('scan.png'));
    await tester.runAsync(() => c.recognizeFiles([id!]));
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2.5)),
          child: child!,
        ),
        home: Scaffold(
          body: OcrReviewDialog(controller: c, objectId: id),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Recognized text'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
