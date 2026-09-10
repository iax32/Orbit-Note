import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/application/backup_bundle.dart';
import 'package:orbit_note/domain/note_path_links.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/storage/native_path_moves.dart';
import 'package:orbit_note/infrastructure/storage/workspace_store.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/platform/import_backup_native.dart';
import 'package:orbit_note/app/session_state.dart';

void main() {
  late Directory root;
  late NativeWorkspaceStore store;
  late WorkspaceRepository repo;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('orbit-folders-');
    store = NativeWorkspaceStore();
    repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
    await repo.initialize(path: '${root.path}/vault');
  });
  tearDown(() async {
    await repo.close();
    await root.delete(recursive: true);
  });

  test('explicit moves rebase prose links and keep code/source labels exact', () {
    const source =
        '![Image](<../Attachments/a/image.png>)\n[Doc](../Attachments/a/doc.pdf "Title")\n[[Readable]]\n`[Example](../Attachments/a/doc.pdf)`\n```md\n![Code](../Attachments/a/image.png)\n```\n[ref]: ../Attachments/a/doc.pdf\n[Web](https://example.com)';
    final moved = rebaseNoteLinks(source, 'Notes/a.md', 'Notes/Research/a.md');
    expect(moved, contains('![Image](<../../Attachments/a/image.png>)'));
    expect(moved, contains('[Doc](../../Attachments/a/doc.pdf "Title")'));
    expect(moved, contains('`[Example](../Attachments/a/doc.pdf)`'));
    expect(moved, contains('```md\n![Code](../Attachments/a/image.png)\n```'));
    expect(rebaseNoteLinks(moved, 'Notes/Research/a.md', 'Notes/a.md'), source);
  });

  test(
    'nested note/folder moves preserve IDs, attachment bytes and backups including empty folders',
    () async {
      final image = await repo.importAttachment(
        name: 'image.png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      final ref = image.properties['contentRef'] as String;
      final note = await repo.create(
        typeId: 'orbit.note',
        title: 'Research',
        body: '![](<../$ref>)\n[[Readable]]',
      );
      await repo.createFolder('Notes/Projects/Empty');
      await repo.moveNote(note.id, 'Notes/Projects');
      expect(repo.objectPath(note.id), startsWith('Notes/Projects/'));
      expect(
        repo.objects.singleWhere((o) => o.id == note.id).body,
        contains('../../$ref'),
      );
      await repo.moveFolder('Notes/Projects', 'Notes/Library');
      expect(repo.objectPath(note.id), startsWith('Notes/Library/'));
      expect(repo.folders, contains('Notes/Library/Empty'));
      expect(await repo.readAttachment(ref), [1, 2, 3]);
      final bundle = BackupBundle.parse(await repo.exportBundle());
      final imported = await importBackup(bundle, root.path);
      expect(await Directory('$imported/Notes/Library/Empty').exists(), isTrue);
      final restored = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: MemoryObjectIndex(),
      );
      try {
        await restored.initialize(path: imported);
        expect(
          restored.objects.singleWhere((o) => o.id == note.id).body,
          repo.objects.singleWhere((o) => o.id == note.id).body,
        );
      } finally {
        await restored.close();
      }
    },
  );

  test(
    'collisions, traversal, reserved names and unknown Markdown fail without moving originals',
    () async {
      final note = await repo.create(typeId: 'orbit.note', title: 'Original');
      await repo.createFolder('Notes/Existing');
      await expectLater(
        repo.moveFolder('Notes/Existing', 'Notes/Existing/Sub'),
        throwsA(anything),
      );
      await expectLater(
        repo.createFolder('Notes/../escape'),
        throwsA(anything),
      );
      await expectLater(repo.createFolder('Notes/CON'), throwsA(anything));
      await repo.createFolder('Notes/Unowned');
      await File(
        '${store.location}/Notes/Unowned/plain.md',
      ).writeAsString('Ordinary Markdown');
      await expectLater(
        repo.moveFolder('Notes/Unowned', 'Notes/Renamed'),
        throwsA(anything),
      );
      expect(
        await File('${store.location}/Notes/Unowned/plain.md').readAsString(),
        'Ordinary Markdown',
      );
      final before = await store.read(repo.objectPath(note.id)!);
      await File(
        '${store.location}/Notes/Existing/${repo.objectPath(note.id)!.split('/').last}',
      ).writeAsString('Existing destination');
      await expectLater(
        repo.moveNote(note.id, 'Notes/Existing'),
        throwsA(anything),
      );
      expect(await store.read(repo.objectPath(note.id)!), before);
    },
  );

  test('interrupted multi-file preparation rolls forward on reopen', () async {
    await repo.createFolder('Notes/Source');
    for (final name in ['a', 'b']) {
      await File(
        '${store.location}/Notes/Source/$name.txt',
      ).writeAsString('before-$name');
    }
    final replacements = <String, FileReplacement>{};
    for (final name in ['a', 'b']) {
      final bytes = await File(
        '${store.location}/Notes/Source/$name.txt',
      ).readAsBytes();
      replacements['Notes/Source/$name.txt'] = FileReplacement(
        Uint8List.fromList(utf8.encode('after-$name')),
        sha256.convert(bytes).toString(),
      );
    }
    var writes = 0;
    final moves = NativePathMoves(store.location, (path, bytes, hash) async {
      if (++writes == 2) {
        throw const FileSystemException('Injected interrupted write');
      }
      await store.write(path, bytes, expectedHash: hash);
    });
    await expectLater(
      moves.move('Notes/Source', 'Notes/Target', replacements),
      throwsA(anything),
    );
    await repo.initialize(path: store.location);
    expect(repo.readOnly, isFalse);
    expect(await Directory('${store.location}/Notes/Source').exists(), isFalse);
    for (final name in ['a', 'b']) {
      expect(
        await File('${store.location}/Notes/Target/$name.txt').readAsString(),
        'after-$name',
      );
    }
    expect(
      (await store.listFiles()).where((path) => path.endsWith('.move.json')),
      isEmpty,
    );
  });

  test(
    'external conflict during move recovery retains all bytes and opens read-only',
    () async {
      await repo.createFolder('Notes/Source');
      final file = File('${store.location}/Notes/Source/a.txt');
      await file.writeAsString('before');
      final moves = NativePathMoves(store.location, (_, _, _) async {
        throw const FileSystemException('Injected interruption');
      });
      await expectLater(
        moves.move('Notes/Source', 'Notes/Target', {
          'Notes/Source/a.txt': FileReplacement(
            Uint8List.fromList(utf8.encode('after')),
            sha256.convert(utf8.encode('before')).toString(),
          ),
        }),
        throwsA(anything),
      );
      await file.writeAsString('external');
      await repo.initialize(path: store.location);
      expect(repo.readOnly, isTrue);
      expect(await file.readAsString(), 'external');
      expect(
        (await store.listFiles()).where((path) => path.endsWith('.move-data')),
        isNotEmpty,
      );
    },
  );

  test('folder collapse preference survives device session round trip', () {
    final session = SessionState(
      collapsedFolders: ['Notes/Research'],
      noteSort: 'name-asc',
    );
    final restored = SessionState.fromJson(session.toJson());
    expect(restored.collapsedFolders, ['Notes/Research']);
    expect(restored.noteSort, 'name-asc');
  });

  test(
    'Windows recovery junction is rejected before reading external journals',
    () async {
      final recovery = Directory('${store.location}/.orbit/recovery');
      if (await recovery.exists()) {
        await recovery.rename('${store.location}/.orbit/previous-recovery');
      }
      final outside = await Directory('${root.path}/outside').create();
      final sentinel = File('${outside.path}/keep.json');
      await sentinel.writeAsString('{"external":"preserve"}');
      final junction = await Process.run('cmd', [
        '/c',
        'mklink',
        '/J',
        recovery.path.replaceAll('/', '\\'),
        outside.path.replaceAll('/', '\\'),
      ]);
      expect(junction.exitCode, 0, reason: '${junction.stderr}');
      try {
        await expectLater(
          repo.initialize(path: store.location),
          throwsA(anything),
        );
        expect(await sentinel.readAsString(), '{"external":"preserve"}');
      } finally {
        await Link(recovery.path).delete();
      }
    },
    skip: !Platform.isWindows,
  );

  test('folder move preserves destinations inside the moved tree', () {
    expect(
      rebaseNoteLinks(
        '[Sibling](b.md) ![Asset](../Attachments/a.png)',
        'Notes/Source/a.md',
        'Notes/Target/a.md',
        movedSource: 'Notes/Source',
        movedTarget: 'Notes/Target',
      ),
      '[Sibling](b.md) ![Asset](../Attachments/a.png)',
    );
  });
}
