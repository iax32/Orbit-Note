import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  late MemoryStore store;
  late ProviderContainer container;
  late WorkspaceController c;
  setUp(() async {
    store = MemoryStore();
    container = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(
          WorkspaceRepository(store: store, index: MemoryObjectIndex()),
        ),
      ],
    );
    container.read(workspaceProvider);
    c = container.read(workspaceProvider.notifier);
    while (c.loading) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    c.pausePdfIndex(true);
    c.cancelAllTimers();
  });
  tearDown(() {
    c.cancelAllTimers();
    container.dispose();
  });

  test(
    'simultaneous recovery requests create one copy of the same retained draft',
    () async {
      final note = (await c.create('orbit.note', body: 'base'))!;
      c.publishEditorBody('left', note.id, 'base', 'left');
      await c.flush(note.id);
      c.publishEditorBody('right', note.id, 'base', 'retained');
      final gate = Completer<void>();
      store.writeGate = gate.future;
      final first = c.recoverEditorDraft('right'),
          second = c.recoverEditorDraft('right');
      await Future<void>.delayed(Duration.zero);
      store.writeGate = null;
      gate.complete();
      final results = await Future.wait([first, second]);
      expect(results[0]!.id, results[1]!.id);
      expect(
        c.activeObjects.where((o) => o.properties['recoveredFrom'] == note.id),
        hasLength(1),
      );
      expect(c.find(note.id)!.body, 'left');
      expect(c.editorDraftConflicts, isEmpty);
    },
  );

  test(
    'a failed shared recovery releases its pending entry and retries once',
    () async {
      final note = (await c.create('orbit.note', body: 'base'))!;
      c.publishEditorBody('left', note.id, 'base', 'left');
      await c.flush(note.id);
      c.publishEditorBody('right', note.id, 'base', 'retained');
      store.failWrites = true;
      final failed = await Future.wait([
        c.recoverEditorDraft('right'),
        c.recoverEditorDraft('right'),
      ]);
      expect(failed, [null, null]);
      expect(c.editorDraftConflicts['right']!.body, 'retained');
      store.failWrites = false;
      final success = await Future.wait([
        c.recoverEditorDraft('right'),
        c.recoverEditorDraft('right'),
      ]);
      expect(success[0]!.id, success[1]!.id);
      expect(
        c.activeObjects.where((o) => o.properties['recoveredFrom'] == note.id),
        hasLength(1),
      );
    },
  );

  test(
    'a newer conflicting draft can recover separately without being cleared by the older copy',
    () async {
      final note = (await c.create('orbit.note', body: 'base'))!;
      c.publishEditorBody('left', note.id, 'base', 'left');
      await c.flush(note.id);
      c.publishEditorBody('right', note.id, 'base', 'v1');
      final gate = Completer<void>();
      store.writeGate = gate.future;
      final first = c.recoverEditorDraft('right');
      await Future<void>.delayed(Duration.zero);
      c.publishEditorBody('right', note.id, 'base', 'v2');
      final second = c.recoverEditorDraft('right'),
          repeated = c.recoverEditorDraft('right');
      store.writeGate = null;
      gate.complete();
      final results = await Future.wait([first, second, repeated]);
      expect(results[0]!.body, 'v1');
      expect(results[1]!.body, 'v2');
      expect(results[1]!.id, results[2]!.id);
      expect(results[0]!.id, isNot(results[1]!.id));
      expect(c.editorDraftConflicts, isEmpty);
    },
  );

  test(
    'recovering two different pane drafts does not merge their identities',
    () async {
      final note = (await c.create('orbit.note', body: 'base'))!;
      c.publishEditorBody('left', note.id, 'base', 'left');
      await c.flush(note.id);
      c.publishEditorBody('first', note.id, 'base', 'draft 1');
      c.publishEditorBody('second', note.id, 'base', 'draft 2');
      final copies = await Future.wait([
        c.recoverEditorDraft('first'),
        c.recoverEditorDraft('second'),
      ]);
      expect(copies[0]!.body, 'draft 1');
      expect(copies[1]!.body, 'draft 2');
      expect(copies[0]!.id, isNot(copies[1]!.id));
      expect(c.find(note.id)!.body, 'left');
    },
  );

  test(
    'Canvas recovery coalesces writes and preserves opaque data and placement references',
    () async {
      final note = (await c.create(
        'orbit.canvas',
        data: {'schemaVersion': 1, 'elements': []},
      ))!;
      c.publishCanvasDraft('left', note.id, note.data, {
        'schemaVersion': 1,
        'elements': [],
        'latest': true,
      });
      await c.flush(note.id);
      c.publishCanvasDraft('right', note.id, note.data, {
        'schemaVersion': 1,
        'opaque': {
          'keep': [1, 2],
        },
        'elements': [
          {'id': 'placement', 'type': 'card', 'objectId': note.id},
        ],
      });
      final copies = await Future.wait([
        c.recoverEditorDraft('right'),
        c.recoverEditorDraft('right'),
      ]);
      expect(copies[0]!.id, copies[1]!.id);
      expect(copies[0]!.data['opaque'], {
        'keep': [1, 2],
      });
      expect((copies[0]!.data['elements'] as List).single['objectId'], note.id);
    },
  );

  test(
    'interleaved latest saves retain all edits and failed saves remain retryable',
    () async {
      final note = (await c.create(
        'orbit.note',
        body: 'base',
        properties: {
          'future': {'keep': 7},
        },
      ))!;
      final gate = Completer<void>();
      store.writeGate = gate.future;
      c.publishEditorBody('left', note.id, 'base', 'draft 0');
      final saves = [c.flush(note.id)];
      for (var i = 1; i <= 80; i++) {
        expect(
          c.publishEditorBody('left', note.id, 'draft ${i - 1}', 'draft $i'),
          isTrue,
        );
        if (i % 10 == 0) saves.add(c.flush(note.id));
      }
      store.writeGate = null;
      gate.complete();
      await Future.wait(saves);
      store.failWrites = true;
      c.publishEditorBody('left', note.id, 'draft 80', 'final pending');
      await c.flush(note.id);
      expect(c.dirty, contains(note.id));
      expect(c.find(note.id)!.properties['future'], {'keep': 7});
      store.failWrites = false;
      await c.retry(note.id);
      await c.initialize();
      expect(c.find(note.id)!.body, 'final pending');
      expect(c.dirty, isEmpty);
    },
  );
}
