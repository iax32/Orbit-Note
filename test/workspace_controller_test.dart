import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';
import 'support/pdf_fixture.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/domain/pdf_annotation.dart';
import 'package:orbit_note/domain/research_document.dart';

void main() {
  late MemoryStore store;
  late WorkspaceRepository repo;
  late ProviderContainer container;
  late WorkspaceController controller;
  setUp(() async {
    store = MemoryStore();
    repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    container.read(workspaceProvider);
    controller = container.read(workspaceProvider.notifier);
    for (var i = 0; i < 100 && controller.loading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    expect(controller.loading, isFalse);
  });
  tearDown(() async {
    store.writeGate = null;
    store.failWrites = false;
    await controller.flushAll();
    container.dispose();
  });
  test(
    'PDF documentation starters persist with provenance and safe failures',
    () async {
      final bytes = researchPdf();
      final file = await repo.importAttachment(
        name: 'Game systems.pdf',
        bytes: bytes,
      );
      await controller.refresh();
      final created = <String, String>{};
      for (final document in ResearchDocument.values) {
        final note = await controller.createPdfQuote(
          file.id,
          2,
          '',
          document: document,
        );
        expect(note, isNotNull);
        expect(note!.body, contains('[[${file.id}#page=2|'));
        expect(note.body, startsWith('# ${document.label}\n'));
        expect(
          (note.properties['pdfSource'] as Map)['checksum'],
          file.properties['checksum'],
        );
        created[note.id] = note.body;
      }
      final selected = await controller.createPdfQuote(
        file.id,
        1,
        'Exact *source*\nsecond line',
        document: ResearchDocument.design,
      );
      expect(selected!.body, contains('> Exact *source*\n> second line'));
      final count = controller.objects.length;
      expect(
        await controller.createPdfQuote(
          file.id,
          0,
          '',
          document: ResearchDocument.playtest,
        ),
        isNull,
      );
      store.failWrites = true;
      expect(
        await controller.createPdfQuote(
          file.id,
          1,
          '',
          document: ResearchDocument.playtest,
        ),
        isNull,
      );
      expect(controller.objects.length, count);
      store.failWrites = false;
      await controller.initialize();
      for (final entry in created.entries) {
        expect(controller.find(entry.key)!.body, entry.value);
      }
      expect(
        await repo.readAttachment(file.properties['contentRef'] as String),
        bytes,
      );
    },
  );
  test(
    'PDF quotes create durable linked notes without changing original bytes',
    () async {
      final bytes = researchPdf();
      final file = await repo.importAttachment(
        name: 'lecture.pdf',
        bytes: bytes,
      );
      await controller.refresh();
      final quote = await controller.createPdfQuote(
        file.id,
        2,
        'A research finding',
      );
      expect(quote, isNotNull);
      expect(quote!.body, contains('[[${file.id}#page=2|lecture.pdf · p. 2]]'));
      expect(
        (quote.properties['pdfSource'] as Map)['checksum'],
        file.properties['checksum'],
      );
      await repo.refresh();
      expect(repo.objects.firstWhere((o) => o.id == quote.id).body, quote.body);
      expect(
        await repo.readAttachment(file.properties['contentRef'] as String),
        bytes,
      );
      final count = controller.objects.length;
      store.failWrites = true;
      expect(
        await controller.createPdfQuote(file.id, 1, 'Cannot save'),
        isNull,
      );
      expect(controller.objects.length, count);
      expect(controller.error, isNotNull);
      store.failWrites = false;
      expect(
        await repo.readAttachment(file.properties['contentRef'] as String),
        bytes,
      );
    },
  );
  test(
    'PDF form drafts persist and reject stale sources without changing bytes',
    () async {
      final bytes = formPdf();
      final file = await repo.importAttachment(name: 'form.pdf', bytes: bytes);
      await controller.refresh();
      final checksum = file.properties['checksum'] as String;
      expect(
        await controller.savePdfFormField(
          file.id,
          checksum,
          '1:0',
          'Player one',
        ),
        isTrue,
      );
      expect(
        await controller.savePdfFormField(file.id, checksum, '1:1', true),
        isTrue,
      );
      await controller.initialize();
      final draft = controller.find(file.id)!.properties['pdfFormDraft'] as Map;
      expect(draft['values'], {'1:0': 'Player one', '1:1': true});
      expect(
        await controller.savePdfFormField(file.id, 'stale', '1:1', false),
        isFalse,
      );
      expect(
        await controller.savePdfFormField(file.id, checksum, 'bad', true),
        isFalse,
      );
      store.failWrites = true;
      expect(
        await controller.savePdfFormField(
          file.id,
          checksum,
          '1:0',
          'Retained draft',
        ),
        isFalse,
      );
      expect(controller.dirty, contains(file.id));
      store.failWrites = false;
      expect(await controller.flushAll(), isTrue);
      await controller.initialize();
      expect(
        ((controller.find(file.id)!.properties['pdfFormDraft'] as Map)['values']
            as Map)['1:0'],
        'Retained draft',
      );
      expect(
        await repo.readAttachment(file.properties['contentRef'] as String),
        bytes,
      );
    },
  );
  test(
    'PDF highlights persist as linkable notes with source-version safety',
    () async {
      final bytes = researchPdf();
      final file = await repo.importAttachment(name: 'paper.pdf', bytes: bytes);
      await controller.refresh();
      final checksum = file.properties['checksum'] as String;
      final regions = [
        CanvasElement({
          'id': 'r1',
          'type': 'rectangle',
          'page': 1,
          'x': .1,
          'y': .2,
          'width': .3,
          'height': .02,
        }),
      ];
      final note = await controller.createPdfHighlight(
        file.id,
        checksum,
        'A finding',
        regions,
        comment: 'Compare with chapter two.',
      );
      expect(note, isNotNull);
      expect(note!.body, contains('Compare with chapter two.'));
      expect(note.body, contains('[[${file.id}#page=1|'));
      await controller.initialize();
      final restored = PdfAnnotation(controller.find(note.id)!);
      expect(restored.regions.single.data, regions.single.data);
      expect(restored.matches(checksum), isTrue);
      expect(restored.matches('replacement'), isFalse);
      expect(
        await repo.readAttachment(file.properties['contentRef'] as String),
        bytes,
      );
      final count = controller.objects.length;
      expect(
        await controller.createPdfHighlight(file.id, 'stale', 'Quote', regions),
        isNull,
      );
      expect(
        await controller.createPdfHighlight(file.id, checksum, 'Quote', [
          regions.single.copy({'x': -1}),
        ]),
        isNull,
      );
      store.failWrites = true;
      expect(
        await controller.createPdfHighlight(
          file.id,
          checksum,
          'Quote',
          regions,
        ),
        isNull,
      );
      expect(controller.objects.length, count);
      store.failWrites = false;
      await controller.trash(note.id);
      expect(PdfAnnotation.isAnnotation(controller.find(note.id)!), isFalse);
      await controller.restore(note.id);
      expect(PdfAnnotation.isAnnotation(controller.find(note.id)!), isTrue);
    },
  );
  test('editing while a save is pending commits the newest draft', () async {
    final object = (await controller.create('orbit.note'))!;
    final gate = Completer<void>();
    store.writeGate = gate.future;
    controller.edit(object.id, body: 'First draft');
    final pending = controller.flush(object.id);
    await Future<void>.delayed(Duration.zero);
    controller.edit(object.id, body: 'Newer draft');
    store.writeGate = null;
    gate.complete();
    await pending;
    expect(repo.objects.single.body, 'Newer draft');
    expect(controller.dirty, isEmpty);
  });
  test('tab cycling wraps and preserves the other split pane', () async {
    final a = (await controller.create('orbit.note', title: 'A'))!;
    final b = (await controller.create('orbit.note', title: 'B'))!;
    controller.openObject(a.id);
    controller.openObject(b.id, secondary: true);
    controller.cycleTab(secondary: true);
    expect(controller.session.secondaryId, a.id);
    expect(controller.session.activeId, a.id);
    controller.cycleTab(reverse: true);
    expect(controller.session.activeId, b.id);
    expect(controller.session.secondaryId, a.id);
  });
  test('search retains index relevance and overlays unsaved drafts', () async {
    final z = (await controller.create('orbit.note', title: 'Z topic'))!;
    final a = (await controller.create('orbit.note', title: 'A topic'))!;
    controller.edit(z.id, body: 'needle');
    controller.edit(a.id, body: 'needle');
    await controller.flushAll();
    expect((await controller.search('needle')).map((o) => o.id), [z.id, a.id]);
    controller.edit(a.id, body: 'needle updated draft');
    expect(
      (await controller.search('needle')).first.body,
      'needle updated draft',
    );
    controller.edit(a.id, body: 'no match');
    expect((await controller.search('needle')).map((o) => o.id), [z.id]);
  });
  test(
    'startup failure still allows selecting a replacement workspace',
    () async {
      final failedStore = MemoryStore()..failAllInitializations = true;
      final failedRepo = WorkspaceRepository(
        store: failedStore,
        index: MemoryObjectIndex(),
      );
      final other = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(failedRepo)],
      );
      try {
        other.read(workspaceProvider);
        final recovering = other.read(workspaceProvider.notifier);
        for (var i = 0; i < 100 && recovering.loading; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
        expect(recovering.error, isNotNull);
        expect(await recovering.flushAll(), isTrue);
        failedStore.failAllInitializations = false;
        await recovering.initialize(path: 'replacement');
        expect(recovering.error, isNull);
        expect(failedRepo.workspaceId, isNotEmpty);
      } finally {
        other.dispose();
      }
    },
  );
  test('saved references and legacy aliases survive target rename', () async {
    final target = (await controller.create('orbit.note', title: 'Original'))!;
    final source = (await controller.create('orbit.note'))!;
    controller.edit(source.id, body: 'See [[Original|Readable name]].');
    await controller.flush(source.id);
    expect(controller.find(source.id)!.body, 'See [[Original|Readable name]].');
    expect(controller.find(source.id)!.linkBindings['Original'], target.id);
    controller.edit(target.id, title: 'Renamed');
    await controller.flush(target.id);
    expect(
      controller.find(target.id)!.properties['aliases'],
      contains('Original'),
    );
    expect(
      controller.backlinks(target.id).map((o) => o.id),
      contains(source.id),
    );
  });
  test(
    'external changes reload clean notes but preserve dirty conflicts',
    () async {
      final note = (await controller.create('orbit.note'))!;
      final path = store.files.keys.firstWhere((p) => p.startsWith('Notes/'));
      final original = utf8.decode(store.files[path]!);
      store.files[path] = Uint8List.fromList(
        utf8.encode('$original\nExternal content'),
      );
      await controller.checkExternalChanges();
      expect(controller.find(note.id)!.body, contains('External content'));
      controller.edit(note.id, body: 'Local draft');
      store.files[path] = Uint8List.fromList(
        utf8.encode('$original\nAnother edit'),
      );
      await controller.checkExternalChanges();
      expect(controller.externalChangesPending, isTrue);
      expect(controller.find(note.id)!.body, 'Local draft');
      await controller.flush(note.id);
      expect(controller.failures[note.id], isNotNull);
      expect(utf8.decode(store.files[path]!), contains('Another edit'));
      await controller.saveConflictCopy(note.id);
    },
  );
  test(
    'failed workspace switch recovers the previous saved workspace',
    () async {
      final note = (await controller.create('orbit.note'))!;
      controller.edit(note.id, body: 'Keep this draft');
      store.failInitializePath = 'unavailable';
      await controller.initialize(path: 'unavailable');
      expect(controller.find(note.id)!.body, 'Keep this draft');
      expect(controller.error, contains('previous workspace is still open'));
      controller.edit(note.id, body: 'Editing still works');
      expect(await controller.flushAll(), isTrue);
      expect(repo.objects.single.body, 'Editing still works');
    },
  );
  test(
    'exit flush waits for the latest layout during an active save',
    () async {
      final gate = Completer<void>();
      store.writeGate = gate.future;
      controller.updateSession((s) => s.splitRatio = .4);
      final first = controller.saveSession();
      await Future<void>.delayed(Duration.zero);
      controller.updateSession((s) => s.splitRatio = .65);
      var finished = false;
      final flush = controller.flushAll().then((ok) {
        finished = true;
        return ok;
      });
      await Future<void>.delayed(Duration.zero);
      expect(finished, isFalse);
      store.writeGate = null;
      gate.complete();
      await first;
      expect(await flush, isTrue);
      expect((await repo.readDeviceSettings())['splitRatio'], .65);
    },
  );
  test(
    'trashing a different object does not discard an unsaved note',
    () async {
      final note = (await controller.create('orbit.note'))!,
          task = (await controller.create('orbit.task'))!;
      controller.edit(note.id, body: 'Keep my draft');
      await controller.trash(task.id);
      expect(controller.find(note.id)!.body, 'Keep my draft');
      await controller.flushAll();
      expect(
        repo.objects.firstWhere((o) => o.id == note.id).body,
        'Keep my draft',
      );
      await controller.restore(task.id);
      expect(controller.find(task.id)!.isDeleted, isFalse);
    },
  );
  test('failed saves stay dirty and retry uses the retained draft', () async {
    final note = (await controller.create('orbit.note'))!;
    store.failWrites = true;
    controller.edit(note.id, body: 'Keep through failure');
    await controller.flush(note.id);
    expect(controller.dirty, contains(note.id));
    expect(controller.failures, contains(note.id));
    store.failWrites = false;
    await controller.retry(note.id);
    expect(controller.dirty, isEmpty);
    expect(repo.objects.single.body, 'Keep through failure');
  });
  test(
    'pane configuration and independent positions survive restart',
    () async {
      final note = (await controller.create('orbit.note'))!;
      controller.updateSession((s) {
        s.secondaryId = note.id;
        s.splitAxis = 'vertical';
        s.splitRatio = .35;
        s.positions = {'primary:${note.id}': 100, 'secondary:${note.id}': 900};
      });
      await controller.flushAll();
      await controller.initialize();
      expect(controller.session.secondaryId, note.id);
      expect(controller.session.splitAxis, 'vertical');
      expect(controller.session.splitRatio, .35);
      expect(controller.session.positions['secondary:${note.id}'], 900);
      expect(controller.session.destination, OrbitDestination.home);
    },
  );
}
