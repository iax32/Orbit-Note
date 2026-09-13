import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';

void main() {
  late Directory root;
  late WorkspaceRepository repo;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('orbit-sync-inventory-');
    repo = WorkspaceRepository(
      store: NativeWorkspaceStore(),
      index: MemoryObjectIndex(),
    );
    await repo.initialize(path: root.path);
  });
  tearDown(() async {
    await repo.close();
    await root.delete(recursive: true);
  });

  test(
    'device-only folder Archive metadata is reported, never silently omitted',
    () async {
      await repo.createFolder('Notes/Archived');
      await repo.writeDeviceSettings({
        'archivedFolders': ['Notes/Archived'],
      });
      final inventory = await repo.syncInventory();
      expect(inventory.ready, isFalse);
      expect(
        inventory.issues.any(
          (s) => s.contains('Archive is currently device-local'),
        ),
        isTrue,
      );
      expect((await repo.readDeviceSettings())['archivedFolders'], [
        'Notes/Archived',
      ]);
    },
  );

  test(
    'inventory retains authored data, archive, Trash and empty folders',
    () async {
      final archived = await repo.create(
        typeId: 'orbit.note',
        title: 'Archive',
        body: 'raw **text**',
        properties: {'archived': true},
      );
      final trash = await repo.create(typeId: 'orbit.note', title: 'Trash');
      await repo.trash(trash.id);
      final view = await repo.create(
        typeId: 'orbit.view',
        title: 'Saved Board',
        properties: {'viewType': 'board', 'folder': 'Notes'},
      );
      final canvas = await repo.create(
        typeId: 'orbit.canvas',
        title: 'Board',
        data: {'schemaVersion': 1, 'elements': []},
      );
      final payload = Uint8List.fromList(
        List.generate(256 * 1024, (i) => i % 256),
      );
      final file = await repo.importAttachment(
        name: 'sample.pdf',
        bytes: payload,
      );
      await repo.createFolder('Notes/Empty');
      final inventory = await repo.syncInventory();
      expect(inventory.issues, isEmpty);
      expect(
        inventory.entries.keys,
        containsAll([archived.id, trash.id, canvas.id, file.id, view.id]),
      );
      expect(inventory.folders, contains('Notes/Empty'));
      final ref = file.properties['contentRef'] as String;
      expect(
        inventory.entries['blob:$ref']!.hash,
        sha256.convert(payload).toString(),
      );
      expect(
        inventory.entries.values.any(
          (e) => e.path.startsWith('.orbit/device/'),
        ),
        isFalse,
      );
      final before = await File(
        '${root.path}/${repo.objectPath(archived.id)}',
      ).readAsBytes();
      await repo.syncInventory();
      expect(
        await File(
          '${root.path}/${repo.objectPath(archived.id)}',
        ).readAsBytes(),
        before,
      );
    },
  );

  test(
    'permanent deletion is inventoried as explicit identity, not absence',
    () async {
      final note = await repo.create(typeId: 'orbit.note', title: 'Delete');
      final path = repo.objectPath(note.id)!;
      await repo.deletePermanently(note.id);
      final inventory = await repo.syncInventory();
      expect(inventory.ready, isTrue);
      expect(inventory.entries[note.id]!.deleted, isTrue);
      expect(inventory.entries[note.id]!.path, path);
      expect(
        inventory.sourcePaths[note.id],
        '.orbit/tombstones/${note.id}.json',
      );
    },
  );

  test(
    'unknown authored data blocks a complete-sync claim without rewriting it',
    () async {
      final unknown = File('${root.path}/Future/custom.json');
      await unknown.parent.create();
      await unknown.writeAsString('{"future":true}');
      final inventory = await repo.syncInventory();
      expect(inventory.ready, isFalse);
      expect(
        inventory.issues.any((s) => s.contains('Future/custom.json')),
        isTrue,
      );
      expect(await unknown.readAsString(), '{"future":true}');
    },
  );

  test(
    'changed attachment bytes block sync while originals stay available',
    () async {
      final file = await repo.importAttachment(
        name: 'scan.pdf',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      final path = file.properties['contentRef'] as String;
      await File('${root.path}/$path').writeAsBytes([4, 5, 6]);
      final inventory = await repo.syncInventory();
      expect(inventory.ready, isFalse);
      expect(inventory.issues.any((s) => s.contains(file.id)), isTrue);
      expect(await repo.readAttachment(path), [4, 5, 6]);
    },
  );
}
