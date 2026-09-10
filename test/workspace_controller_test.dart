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
