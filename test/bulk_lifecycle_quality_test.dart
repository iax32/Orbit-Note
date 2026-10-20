import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/workspace_failure.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'support/memory_store.dart';

class CleanupStore extends MemoryStore {
  int? remainingDeletes;
  @override
  Future<void> deleteFile(String path, {required String? expectedHash}) async {
    if (!path.startsWith('.orbit/') && remainingDeletes != null) {
      if (remainingDeletes == 0) {
        throw const WorkspaceFailure('Simulated locked owner');
      }
      remainingDeletes = remainingDeletes! - 1;
    }
    await super.deleteFile(path, expectedHash: expectedHash);
  }
}

void main() {
  group('controller lifecycle', () {
    late CleanupStore store;
    late WorkspaceRepository repo;
    late ProviderContainer container;
    late WorkspaceController c;
    setUp(() async {
      store = CleanupStore();
      repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
      container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      container.read(workspaceProvider);
      c = container.read(workspaceProvider.notifier);
      while (c.loading) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      c.pausePdfIndex(true);
      c.cancelAllTimers();
    });
    tearDown(() async {
      store.writeGate = null;
      store.failWrites = false;
      store.remainingDeletes = null;
      await c.flushAll();
      container.dispose();
    });

    test(
      'duplicate batch freezes and deduplicates a mutable selection',
      () async {
        final a = (await c.create('orbit.note', title: 'A'))!;
        final b = (await c.create('orbit.canvas', title: 'B'))!;
        final ids = [a.id, b.id, a.id];
        final gate = Completer<void>();
        store.writeGate = gate.future;
        final copying = c.duplicateObjects(ids);
        await Future<void>.delayed(Duration.zero);
        ids.clear();
        gate.complete();
        final result = await copying;
        expect(result.map((o) => o.title), ['A (Copy)', 'B (Copy)']);
        expect(result.map((o) => o.id).toSet().length, 2);
      },
    );

    test('deleted objects are never duplicated by a stale selection', () async {
      final a = (await c.create('orbit.note', title: 'Deleted'))!;
      expect(await c.trash(a.id), isTrue);
      expect(await c.duplicateObjects([a.id]), isEmpty);
    });

    test(
      'partial Empty Trash reconciles only durably removed identities',
      () async {
        final a = (await c.create('orbit.note', title: 'A'))!;
        final b = (await c.create('orbit.canvas', title: 'B'))!;
        await c.trash(a.id);
        await c.trash(b.id);
        c.session.bookmarkedTabs = [a.id, b.id];
        store.remainingDeletes = 1;
        await c.emptyTrash();
        expect(repo.objects.any((o) => o.id == a.id), isFalse);
        expect(c.find(a.id), isNull);
        expect(c.find(b.id)?.isDeleted, isTrue);
        expect(c.session.bookmarkedTabs, [b.id]);
        expect(c.error, contains('Simulated locked owner'));
        store.remainingDeletes = null;
        await c.initialize();
        expect(c.find(a.id), isNull);
        expect(c.find(b.id), isNull);
      },
    );

    test(
      'failed flush blocks permanent deletion and retains latest draft',
      () async {
        final a = (await c.create('orbit.note', title: 'A'))!;
        c.edit(a.id, body: 'Recovered new work');
        store.failWrites = true;
        await c.deletePermanently(a.id);
        expect(c.find(a.id)?.body, 'Recovered new work');
        expect(repo.objects.any((o) => o.id == a.id), isTrue);
        expect(c.dirty, contains(a.id));
        store.failWrites = false;
      },
    );

    test(
      'planning Undo retries storage failure but never erases later work',
      () async {
        final a = (await c.create(
          'orbit.task',
          title: 'Task',
          properties: {
            'custom': {'keep': 7},
          },
        ))!;
        expect(await c.configureTask(a, {'priority': 'high'}), isTrue);
        store.failWrites = true;
        expect(await c.undoPlanning(), isFalse);
        expect(c.canUndoPlanning, isTrue);
        expect(c.find(a.id)!.properties['priority'], 'high');
        store.failWrites = false;
        expect(await c.undoPlanning(), isTrue);
        final restored = c.find(a.id)!;
        expect(restored.properties['custom'], {'keep': 7});
        expect(await c.configureTask(restored, {'priority': 'low'}), isTrue);
        c.edit(a.id, title: 'Later title');
        await c.flush(a.id);
        expect(await c.undoPlanning(), isFalse);
        expect(c.find(a.id)!.title, 'Later title');
        expect(c.find(a.id)!.properties['priority'], 'low');
      },
    );
  });

  group('queued repository ownership', () {
    for (final action in ['trash', 'restore', 'delete', 'empty']) {
      test('$action rejects a command queued behind Vault reopening', () async {
        final repo = WorkspaceRepository(
          store: MemoryStore(),
          index: MemoryObjectIndex(),
        );
        await repo.initialize();
        try {
          final a = await repo.create(typeId: 'orbit.note', title: 'A');
          if (action != 'trash') await repo.trash(a.id);
          final before = repo.objects.single;
          final reopening = repo.initialize();
          final operation = switch (action) {
            'trash' => repo.trash(a.id),
            'restore' => repo.restore(a.id),
            'delete' => repo.deletePermanently(a.id),
            _ => repo.emptyTrash(),
          };
          final rejected = expectLater(
            operation,
            throwsA(isA<WorkspaceFailure>()),
          );
          await reopening;
          await rejected;
          expect(repo.objects.single.revision, before.revision);
          expect(repo.objects.single.isDeleted, before.isDeleted);
        } finally {
          await repo.close();
        }
      });
    }
  });

  test('Empty Trash excludes objects trashed after its invocation', () async {
    final repo = WorkspaceRepository(
      store: MemoryStore(),
      index: MemoryObjectIndex(),
    );
    await repo.initialize();
    try {
      final a = await repo.create(typeId: 'orbit.note', title: 'Old trash');
      final b = await repo.create(typeId: 'orbit.task', title: 'Later trash');
      await repo.trash(a.id);
      final later = repo.trash(b.id);
      final clearing = repo.emptyTrash();
      await later;
      await clearing;
      expect(repo.objects.single.id, b.id);
      expect(repo.objects.single.isDeleted, isTrue);
    } finally {
      await repo.close();
    }
  });

  for (final action in ['move', 'folder-move', 'folder-delete']) {
    test('native $action rejects retired queued intent', () async {
      final root = await Directory.systemTemp.createTemp('orbit-bulk-retired-');
      final repo = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: MemoryObjectIndex(),
      );
      try {
        await repo.initialize(path: root.path);
        await repo.createFolder('Notes/From');
        await repo.createFolder('Notes/Target');
        final a = await repo.create(
          typeId: 'orbit.note',
          title: 'A',
          properties: {'folder': 'Notes/From'},
        );
        final reopening = repo.initialize(path: root.path);
        final operation = switch (action) {
          'move' => repo.moveObjectsToFolder([a.id], 'Notes/Target'),
          'folder-move' => repo.moveFolder('Notes/From', 'Notes/New'),
          _ => repo.deleteFolder('Notes/From'),
        };
        final rejected = expectLater(
          operation,
          throwsA(isA<WorkspaceFailure>()),
        );
        await reopening;
        await rejected;
        expect(repo.objectFolder(a.id), 'Notes/From');
        expect(repo.objects.single.isDeleted, isFalse);
      } finally {
        await repo.close();
        await root.delete(recursive: true);
      }
    });
  }

  test(
    '120 mixed owners retain identity, opaque data and restore across repeated moves/restarts',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-bulk-stress-');
      final repo = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: MemoryObjectIndex(),
      );
      try {
        await repo.initialize(path: root.path);
        await repo.createFolder('Notes/A');
        await repo.createFolder('Notes/B');
        final ids = <String>[];
        for (var i = 0; i < 120; i++) {
          ids.add(
            (await repo.create(
              typeId: [
                'orbit.note',
                'orbit.task',
                'orbit.canvas',
                'orbit.view',
              ][i % 4],
              title: 'Same title',
              properties: {
                'opaque': {'index': i},
                'folder': 'Notes/A',
              },
            )).id,
          );
        }
        for (var round = 0; round < 4; round++) {
          final target = round.isEven ? 'Notes/B' : 'Notes/A';
          await repo.moveObjectsToFolder([...ids, ...ids.take(10)], target);
          for (final id in ids.skip(round).take(8)) {
            await repo.trash(id);
            await repo.restore(id);
          }
          await repo.initialize(path: root.path);
          expect(repo.objects.map((o) => o.id), unorderedEquals(ids));
          expect(ids.map(repo.objectFolder).toSet(), {target});
          for (var i = 0; i < ids.length; i++) {
            final o = repo.objects.singleWhere((o) => o.id == ids[i]);
            expect(o.properties['opaque'], {'index': i});
            expect(o.isDeleted, isFalse);
          }
        }
      } finally {
        await repo.close();
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'native mixed move freezes selection before waiting for the queue',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-bulk-quality-');
      final repo = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: MemoryObjectIndex(),
      );
      try {
        await repo.initialize(path: root.path);
        await repo.createFolder('Notes/Target');
        final ids = <String>[];
        for (final type in [
          'orbit.note',
          'orbit.task',
          'orbit.canvas',
          'orbit.view',
        ]) {
          ids.add(
            (await repo.create(
              typeId: type,
              title: type,
              properties: {
                'future': [1, 2],
              },
            )).id,
          );
        }
        final expected = List.of(ids);
        final moving = repo.moveObjectsToFolder(ids, 'Notes/Target');
        ids.clear();
        await moving;
        expect(expected.map(repo.objectFolder).toSet(), {'Notes/Target'});
        await repo.initialize(path: root.path);
        expect(expected.map(repo.objectFolder).toSet(), {'Notes/Target'});
        expect(
          repo.objects.every(
            (o) => o.properties['future'].toString() == '[1, 2]',
          ),
          isTrue,
        );
      } finally {
        await repo.close();
        await root.delete(recursive: true);
      }
    },
  );
}
