import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import '../../domain/universal_object.dart';
import '../../domain/search_text.dart';
import 'object_index.dart';

ObjectIndex createObjectIndex() => DriftObjectIndex();

class DriftObjectIndex implements ObjectIndex {
  _IndexDatabase? _database;
  @override
  Future<void> initialize(String location) async {
    final file = File(p.join(location, '.orbit', 'workspace.sqlite'));
    await file.parent.create(recursive: true);
    var database = _IndexDatabase(NativeDatabase.createInBackground(file));
    try {
      await database
          .customSelect('SELECT count(*) AS count FROM objects')
          .get();
    } on Object {
      await database.close();
      // Content is never recovered from SQL. Retain a bad index for diagnosis,
      // then construct a clean index from authoritative workspace files.
      final suffix = '.invalid-${DateTime.now().microsecondsSinceEpoch}';
      for (final ending in ['', '-wal', '-shm']) {
        final item = File('${file.path}$ending');
        if (await item.exists()) await item.rename('${item.path}$suffix');
      }
      database = _IndexDatabase(NativeDatabase.createInBackground(file));
      await database
          .customSelect('SELECT count(*) AS count FROM objects')
          .get();
    }
    _database = database;
  }

  @override
  Future<void> replaceAll(List<UniversalObject> objects) async {
    final db = _database!;
    await db.transaction(() async {
      await db.customStatement('DELETE FROM objects');
      for (final object in objects) {
        await upsert(object);
      }
    });
  }

  @override
  Future<void> upsert(UniversalObject object) async {
    await _database!.customStatement(
      '''
      INSERT INTO objects(id, workspace_id, type_id, title, body, revision, deleted, search_text)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET workspace_id=excluded.workspace_id,
        type_id=excluded.type_id, title=excluded.title, body=excluded.body,
        revision=excluded.revision, deleted=excluded.deleted, search_text=excluded.search_text
    ''',
      [
        object.id,
        object.workspaceId,
        object.typeId,
        object.title,
        object.body,
        object.revision,
        object.isDeleted ? 1 : 0,
        searchableText(object),
      ],
    );
  }

  @override
  Future<List<String>> search(String query) async {
    final literal = query
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
    final rows = await _database!
        .customSelect(
          "SELECT id FROM objects WHERE deleted=0 AND search_text LIKE ? ESCAPE '\\' ORDER BY CASE WHEN lower(title)=lower(?) THEN 0 WHEN title LIKE ? ESCAPE '\\' THEN 1 WHEN title LIKE ? ESCAPE '\\' THEN 2 ELSE 3 END, lower(title), id LIMIT 100",
          variables: [
            Variable.withString('%$literal%'),
            Variable.withString(query),
            Variable.withString('$literal%'),
            Variable.withString('%$literal%'),
          ],
        )
        .get();
    return rows.map((row) => row.read<String>('id')).toList();
  }

  @override
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}

/// Small explicit SQL schema: code generation adds no value for this derived
/// index. Drift owns connection lifecycle, transactions and schema versioning.
class _IndexDatabase extends GeneratedDatabase {
  _IndexDatabase(super.executor);
  @override
  int get schemaVersion => 2;
  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement('''CREATE TABLE objects (
      id TEXT PRIMARY KEY NOT NULL, workspace_id TEXT NOT NULL,
      type_id TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL,
      revision INTEGER NOT NULL, deleted INTEGER NOT NULL DEFAULT 0,
      search_text TEXT NOT NULL DEFAULT ''
    )''');
      await customStatement(
        'CREATE INDEX objects_type ON objects(type_id, deleted)',
      );
    },
    onUpgrade: (_, from, to) async {
      if (from < 2) {
        await customStatement(
          "ALTER TABLE objects ADD COLUMN search_text TEXT NOT NULL DEFAULT ''",
        );
      }
    },
  );
}
