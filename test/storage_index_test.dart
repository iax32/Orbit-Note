import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/native_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'indexed search includes metadata and Canvas text with title ranking',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'orbit-search-test-',
      );
      final repo = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: DriftObjectIndex(),
      );
      try {
        await repo.initialize(path: folder.path);
        final exact = await repo.create(typeId: 'orbit.note', title: 'Needle');
        final tagged = await repo.create(
          typeId: 'orbit.note',
          title: 'Research',
          properties: {
            'tags': ['Needle'],
            'filename': 'notes-special.pdf',
          },
        );
        final board = await repo.create(
          typeId: 'orbit.canvas',
          title: 'Board',
          data: {
            'schemaVersion': 1,
            'elements': [
              {'id': 'a', 'type': 'sticky', 'text': 'Needle in a board'},
            ],
          },
        );
        final result = await repo.search('Needle');
        expect(result.first.id, exact.id);
        expect(result.map((o) => o.id), containsAll([tagged.id, board.id]));
        expect((await repo.search('notes-special.pdf')).single.id, tagged.id);
      } finally {
        await repo.close();
        await folder.delete(recursive: true);
      }
    },
  );
  test(
    'Drift index rebuilds after missing or corrupt SQLite without losing notes',
    () async {
      final folder = await Directory.systemTemp.createTemp('orbit-index-test-');
      WorkspaceRepository repository() => WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: DriftObjectIndex(),
      );
      var repo = repository();
      try {
        await repo.initialize(path: folder.path);
        final note = await repo.create(
          typeId: 'orbit.note',
          title: '100% local',
          body: 'Needle in Markdown',
        );
        expect((await repo.search('100%')).single.id, note.id);
        expect(repo.issues, isEmpty);
        await repo.close();
        final index = File(p.join(folder.path, '.orbit', 'workspace.sqlite'));
        await index.delete();
        repo = repository();
        await repo.initialize(path: folder.path);
        expect((await repo.search('Needle')).single.id, note.id);
        expect(repo.issues, isEmpty);
        await repo.close();
        await index.writeAsString('not a SQLite database');
        repo = repository();
        await repo.initialize(path: folder.path);
        expect((await repo.search('Needle')).single.id, note.id);
        expect(repo.issues, isEmpty);
        expect(repo.objects.single.body, 'Needle in Markdown');
      } finally {
        await repo.close();
        await folder.delete(recursive: true);
      }
    },
  );
}
