import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/storage/workspace_store.dart';
import 'support/memory_store.dart';

class MetadataNativeStore extends NativeWorkspaceStore {
  MetadataNativeStore(this.temporaryRoot);
  final String temporaryRoot;
  @override
  Future<void> initialize({String? path}) =>
      super.initialize(path: path ?? temporaryRoot);
}

Future<(ProviderContainer, WorkspaceController)> setup(
  WorkspaceStore store, {
  String? path,
}) async {
  final repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
  final container = ProviderContainer(
    overrides: [repositoryProvider.overrideWithValue(repo)],
  );
  container.read(workspaceProvider);
  final c = container.read(workspaceProvider.notifier);
  while (c.loading) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  if (path != null) await c.initialize(path: path);
  c.pausePdfIndex(true);
  c.cancelAllTimers();
  return (container, c);
}

void main() {
  test(
    'field patches preserve newer body, title, data and unrelated nested values',
    () async {
      final (container, c) = await setup(MemoryStore());
      try {
        final note = (await c.create(
          'orbit.note',
          title: 'Before',
          properties: {
            'score': 1,
            'future': {'keep': true},
          },
        ))!;
        final generation = c.workspaceGeneration;
        c.edit(
          note.id,
          title: 'New title',
          body: 'New body\r\n',
          properties: {
            ...note.properties,
            'future': {
              'keep': [2, 3],
            },
          },
          data: {'opaque': 7},
        );
        expect(
          c.editObjectMetadata(
            note,
            generation: generation,
            changes: {'score': 2},
          ),
          isTrue,
        );
        expect(c.find(note.id)!.title, 'New title');
        expect(c.find(note.id)!.body, 'New body\r\n');
        expect(c.find(note.id)!.properties['future'], {
          'keep': [2, 3],
        });
        expect(c.find(note.id)!.data, {'opaque': 7});
        expect(
          c.editObjectMetadata(
            note,
            generation: generation,
            changes: {'score': 3},
          ),
          isFalse,
        );
        expect(c.find(note.id)!.properties['score'], 2);
        await c.flushAll();
      } finally {
        container.dispose();
      }
    },
  );

  test(
    'missing versus null properties and legacy accent changes are conflicts',
    () async {
      final (container, c) = await setup(MemoryStore());
      try {
        final note = (await c.create('orbit.note', title: 'Before'))!;
        c.updateProperty(note.id, 'optional', null);
        expect(
          c.editObjectMetadata(
            note,
            generation: c.workspaceGeneration,
            changes: {'optional': 'value'},
          ),
          isFalse,
        );
        c.updateProperty(note.id, 'accent', '#ff0000');
        expect(
          c.editObjectMetadata(
            note,
            generation: c.workspaceGeneration,
            changes: {'color': 0xff0000ff},
            unchanged: {'accent'},
          ),
          isFalse,
        );
        expect(c.find(note.id)!.properties.containsKey('color'), isFalse);
        await c.flushAll();
      } finally {
        container.dispose();
      }
    },
  );

  test(
    'same-Vault reopen and deletion retire captured metadata edits',
    () async {
      final (container, c) = await setup(MemoryStore());
      try {
        final note = (await c.create('orbit.note', title: 'Before'))!;
        final generation = c.workspaceGeneration;
        await c.initialize();
        expect(
          c.editObjectMetadata(note, generation: generation, title: 'Stale'),
          isFalse,
        );
        final current = c.find(note.id)!;
        await c.trash(note.id);
        expect(
          c.editObjectMetadata(
            current,
            generation: c.workspaceGeneration,
            title: 'Deleted',
          ),
          isFalse,
        );
        expect(c.find(note.id)!.title, 'Before');
      } finally {
        container.dispose();
      }
    },
  );

  test('failed metadata save retains the draft for retry', () async {
    final store = MemoryStore();
    final (container, c) = await setup(store);
    try {
      final note = (await c.create('orbit.note', title: 'Before'))!;
      expect(
        c.editObjectMetadata(
          note,
          generation: c.workspaceGeneration,
          title: 'Pending',
        ),
        isTrue,
      );
      store.failWrites = true;
      await c.flush(note.id);
      expect(c.dirty, contains(note.id));
      expect(c.find(note.id)!.title, 'Pending');
      store.failWrites = false;
      await c.flush(note.id);
      expect(c.dirty, isNot(contains(note.id)));
      await c.initialize();
      expect(c.find(note.id)!.title, 'Pending');
    } finally {
      store.failWrites = false;
      container.dispose();
    }
  });

  test(
    'native rename/color/reset survive reopen without losing source or identity',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'orbit-metadata-quality-',
      );
      final (container, c) = await setup(
        MetadataNativeStore(root.path),
        path: root.path,
      );
      try {
        final note = (await c.create(
          'orbit.note',
          title: 'Before',
          body: '## Source\r\n\r\nText with [links](asset.png).\r\n',
          properties: {
            'future': {'keep': 9},
            'accent': '#123456',
          },
        ))!;
        final path = c.repository.objectPath(note.id);
        expect(
          c.editObjectMetadata(
            note,
            generation: c.workspaceGeneration,
            title: 'Renamed',
            changes: {'color': 0xffabcdef},
          ),
          isTrue,
        );
        await c.flush(note.id);
        final current = c.find(note.id)!;
        expect(
          c.editObjectMetadata(
            current,
            generation: c.workspaceGeneration,
            remove: {'color', 'accent'},
          ),
          isTrue,
        );
        await c.flush(note.id);
        await c.initialize(path: root.path);
        final saved = c.find(note.id)!;
        expect(saved.title, 'Renamed');
        expect(saved.body, note.body);
        expect(saved.properties['future'], {'keep': 9});
        expect(saved.properties.containsKey('color'), isFalse);
        expect(saved.properties.containsKey('accent'), isFalse);
        expect(saved.properties['aliases'], contains('Before'));
        expect(c.repository.objectPath(note.id), path);
      } finally {
        container.dispose();
        await c.repository.close();
        await root.delete(recursive: true);
      }
    },
  );
}
