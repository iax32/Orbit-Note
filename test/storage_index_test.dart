import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/native_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'v2 migrates to FTS with quoted literal queries and synchronized updates',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'orbit-fts-migration-',
      );
      final index = DriftObjectIndex();
      try {
        await Directory(p.join(folder.path, '.orbit')).create();
        final db = sqlite3.open(
          p.join(folder.path, '.orbit', 'workspace.sqlite'),
        );
        db.execute(
          'CREATE TABLE objects(id TEXT PRIMARY KEY, workspace_id TEXT, type_id TEXT, title TEXT, body TEXT, revision INTEGER, deleted INTEGER, search_text TEXT)',
        );
        db.execute(
          "INSERT INTO objects VALUES('legacy','w','orbit.note','Legacy needle','',1,0,'Legacy needle 100% a_b \"quoted\"')",
        );
        db.execute('PRAGMA user_version=2');
        db.close();
        await index.initialize(folder.path);
        expect(await index.search('needle'), ['legacy']);
        expect(await index.search('100%'), ['legacy']);
        expect(await index.search('a_b'), ['legacy']);
        expect(await index.search('"quoted"'), ['legacy']);
        expect(await index.search('OR'), isEmpty);
        await index.replaceAll([]);
        expect(await index.search('needle'), isEmpty);
        await index.close();
        await index.initialize(folder.path);
        expect(await index.search('needle'), isEmpty);
      } finally {
        await index.close();
        await folder.delete(recursive: true);
      }
    },
  );
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
