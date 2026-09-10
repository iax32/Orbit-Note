import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/backup_bundle.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/platform/import_backup_native.dart';

void main() {
  late Directory root;
  late WorkspaceRepository repository;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('orbit-import-test-');
    repository = WorkspaceRepository(
      store: NativeWorkspaceStore(),
      index: MemoryObjectIndex(),
    );
    await repository.initialize(path: '${root.path}/original');
  });
  tearDown(() async {
    await repository.close();
    await root.delete(recursive: true);
  });
  test(
    'export/import preserves objects, attachment bytes and unknown fields',
    () async {
      final note = await repository.create(
        typeId: 'orbit.note',
        title: 'Research',
        body: '# Hello',
        properties: {
          'future': {'x': 7},
        },
      );
      await repository.create(
        typeId: 'orbit.task',
        title: 'Read it',
        properties: {'completed': false},
      );
      await repository.create(
        typeId: 'orbit.canvas',
        title: 'Board',
        data: {
          'schemaVersion': 1,
          'elements': [],
          'unknown': [1, 2],
        },
      );
      await repository.importAttachment(
        name: 'sample.bin',
        bytes: Uint8List.fromList([0, 1, 255]),
      );
      final before = BackupBundle.parse(await repository.exportBundle());
      final path = await importBackup(before, root.path);
      final imported = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: MemoryObjectIndex(),
      );
      try {
        await imported.initialize(path: path);
        expect(imported.objects.length, 4);
        expect(
          imported.objects
              .firstWhere((o) => o.id == note.id)
              .properties['future'],
          {'x': 7},
        );
        final after = BackupBundle.parse(await imported.exportBundle());
        for (final entry in before.files.entries) {
          final key = entry.key.startsWith('.orbit/recovery/')
              ? entry.key.replaceFirst(
                  '.orbit/recovery/',
                  '.orbit/imported-recovery/',
                )
              : entry.key;
          expect(after.files[key], entry.value, reason: key);
        }
      } finally {
        await imported.close();
      }
    },
  );
  test('unsafe and colliding paths are rejected before disk writes', () async {
    final source =
        jsonDecode(await repository.exportBundle()) as Map<String, dynamic>;
    for (final path in [
      '../escape',
      'Notes/CON.md',
      'Notes/x.',
      'WORKSPACE.JSON',
      'a/b',
    ]) {
      final files = Map<String, dynamic>.from(source['files'] as Map)
        ..[path] = base64Encode([1]);
      if (path == 'a/b') files['a'] = base64Encode([1]);
      expect(
        () => BackupBundle.parse(jsonEncode({...source, 'files': files})),
        throwsA(anything),
      );
    }
  });
  test(
    'selected workspace survives a new store and unavailable paths are not recreated',
    () async {
      final pointer = '${root.path}/device/selection.json';
      final selectedPath = '${root.path}/selected';
      final first = WorkspaceRepository(
        store: NativeWorkspaceStore(
          rememberWorkspace: true,
          selectionFilePath: pointer,
        ),
        index: MemoryObjectIndex(),
      );
      await first.initialize(path: selectedPath);
      final id = first.workspaceId;
      await first.close();
      final second = WorkspaceRepository(
        store: NativeWorkspaceStore(
          rememberWorkspace: true,
          selectionFilePath: pointer,
        ),
        index: MemoryObjectIndex(),
      );
      await second.initialize();
      expect(second.workspaceId, id);
      await second.close();
      await Directory(selectedPath).rename('${root.path}/disconnected');
      final third = NativeWorkspaceStore(
        rememberWorkspace: true,
        selectionFilePath: pointer,
      );
      await expectLater(third.initialize(), throwsA(anything));
      expect(await Directory(selectedPath).exists(), isFalse);
    },
  );
  test(
    'write failure never publishes or modifies the original workspace',
    () async {
      await repository.create(
        typeId: 'orbit.note',
        title: 'Keep me',
        body: 'Original',
      );
      final source = await repository.exportBundle();
      final bundle = BackupBundle.parse(source);
      var writes = 0;
      await expectLater(
        importBackup(
          bundle,
          root.path,
          writeFile: (file, bytes) async {
            if (writes++ > 0) throw const FileSystemException('disk full');
            await file.writeAsBytes(bytes, flush: true);
          },
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await repository.exportBundle(), contains('orbit-note-backup'));
      expect(
        (await root.list().toList()).where(
          (e) => e.path.contains('Imported Orbit'),
        ),
        isEmpty,
      );
      expect(
        await File('${root.path}/original/workspace.json').readAsBytes(),
        bundle.files['workspace.json'],
      );
    },
  );
}
