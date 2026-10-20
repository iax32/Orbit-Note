import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/features/notes/note_find_index.dart';
import 'package:orbit_note/features/notes/rich/document_history.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';

class TransactionNativeStore extends NativeWorkspaceStore {
  TransactionNativeStore(this.root);
  final String root;
  @override
  Future<void> initialize({String? path}) =>
      super.initialize(path: path ?? root);
}

void main() {
  test(
    'native long-note replace and history replay keep exact source and metadata across reopen',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'orbit-editor-transactions-',
      );
      final repo = WorkspaceRepository(
        store: TransactionNativeStore(root.path),
        index: MemoryObjectIndex(),
      );
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      container.read(workspaceProvider);
      final c = container.read(workspaceProvider.notifier);
      try {
        while (c.loading) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
        c.pausePdfIndex(true);
        c.cancelAllTimers();
        final source = List.generate(
          750,
          (i) =>
              '## Section $i\r\n\r\n**alpha** [alpha](https://example.test/alpha) 😀\r\n\r\n',
        ).join();
        final note = (await c.create(
          'orbit.note',
          body: source,
          properties: {
            'future': {
              'keep': [1, 2],
            },
            'tags': ['research'],
          },
        ))!;
        final index = NoteFindIndex(source, rich: true),
            history = DocumentHistory();
        final next = index.replace(index.matches('alpha'), 'beta');
        history.record(source, next);
        expect(c.publishEditorBody('primary', note.id, source, next), isTrue);
        await c.flush(note.id);
        await c.initialize();
        expect(c.find(note.id)!.body, next);
        expect(next, contains('(https://example.test/alpha)'));
        var current = next;
        for (var i = 0; i < 6; i++) {
          final restored = i.isEven
              ? history.undo(current)
              : history.redo(current);
          expect(
            c.publishEditorBody('primary', note.id, current, restored),
            isTrue,
          );
          await c.flush(note.id);
          await c.initialize();
          expect(c.find(note.id)!.body, restored);
          current = restored;
        }
        expect(current, next);
        expect(c.find(note.id)!.properties['future'], {
          'keep': [1, 2],
        });
        expect(c.find(note.id)!.properties['tags'], ['research']);
        expect(c.activeObjects, hasLength(1));
        expect(c.dirty, isEmpty);
      } finally {
        c.cancelAllTimers();
        container.dispose();
        await repo.close();
        expect(
          root.absolute.path,
          startsWith(Directory.systemTemp.absolute.path),
        );
        await root.delete(recursive: true);
      }
    },
  );
}
