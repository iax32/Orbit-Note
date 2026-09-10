import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/backup_bundle.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/domain/attachment_safety.dart';
import 'package:orbit_note/domain/wiki_links.dart';
import 'package:orbit_note/platform/import_backup_native.dart';
import 'package:orbit_note/platform/vault_folder_native.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('orbit-audit-');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  test(
    'Vault create, rename, close and recent selection preserve identity',
    () async {
      final folder = await createVaultFolder(root.path, 'Research');
      final store = NativeWorkspaceStore(
        rememberWorkspace: true,
        selectionFilePath: '${root.path}/selection.json',
      );
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      try {
        await repo.initialize(path: folder);
        final id = repo.workspaceId;
        await repo.renameWorkspace('Research Library');
        expect(repo.workspaceId, id);
        expect(repo.name, 'Research Library');
        expect(await repo.recentLocations(), contains(folder));
        await repo.clearSelection();
        await expectLater(store.initialize(), throwsA(anything));
        await repo.initialize(path: folder);
        expect(repo.workspaceId, id);
        expect(repo.name, 'Research Library');
        await expectLater(
          createVaultFolder(root.path, 'Research'),
          throwsA(anything),
        );
      } finally {
        await repo.close();
      }
    },
  );
  test(
    'native change stream reports content events and ignores save machinery',
    () async {
      final store = NativeWorkspaceStore();
      await store.initialize(path: root.path);
      final events = <String>[];
      final subscription = store.changes.listen(events.add);
      try {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await File('${root.path}/external.md').writeAsString('External');
        await Directory('${root.path}/.orbit/cache').create(recursive: true);
        await File('${root.path}/.orbit/cache/preview').writeAsString('cache');
        for (var i = 0; i < 50 && !events.contains('external.md'); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(events, contains('external.md'));
        expect(events.any((e) => e.startsWith('.orbit/')), isFalse);
      } finally {
        await subscription.cancel();
      }
    },
  );
  test(
    'authored links remain byte-exact while metadata binds stable identity',
    () async {
      final repo = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: MemoryObjectIndex(),
      );
      try {
        await repo.initialize(path: root.path);
        final target = await repo.create(
          typeId: 'orbit.note',
          title: 'Architecture',
        );
        const source =
            '  [[Architecture]]\n`[[Architecture]]`\n[[Architecture|Read this]]  \n';
        var note = await repo.create(
          typeId: 'orbit.note',
          title: 'Source',
          body: source,
        );
        expect(note.body, source);
        expect(note.linkBindings['Architecture'], target.id);
        await repo.save(target.copyWith(title: 'Renamed'));
        await repo.create(typeId: 'orbit.note', title: 'Architecture');
        note = await repo.save(note);
        expect(note.body, source);
        final targets = repo.objects.map(
          (o) => NoteLinkTarget(id: o.id, title: o.title),
        );
        expect(
          resolveWikiLink(
            parseWikiLinks(source).first,
            targets,
            bindings: note.linkBindings,
          ).target!.id,
          target.id,
        );
      } finally {
        await repo.close();
      }
    },
  );
  test(
    'successful writes bound history and retire completed journals',
    () async {
      final store = NativeWorkspaceStore(
        historyMaxEntries: 3,
        historyMaxBytes: 1000,
      );
      await store.initialize(path: root.path);
      String? hash;
      for (var i = 0; i < 20; i++) {
        final bytes = Uint8List.fromList(utf8.encode('version $i'));
        await store.write('Notes/example.md', bytes, expectedHash: hash);
        hash = sha256.convert(bytes).toString();
      }
      final files = await store.listFiles();
      expect(files.where((p) => p.startsWith('.orbit/recovery/')), isEmpty);
      expect(files.where((p) => p.endsWith('.before')).length, 3);
      expect(
        utf8.decode((await store.read('Notes/example.md'))!),
        'version 19',
      );
      expect(
        await store.read(files.firstWhere((p) => p.endsWith('.before'))),
        isNotNull,
      );
    },
  );
  test(
    'mixed backup preserves ordinary Markdown and malformed/unknown content',
    () async {
      final repo = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: MemoryObjectIndex(),
      );
      try {
        await repo.initialize(path: '${root.path}/original');
        await repo.create(
          typeId: 'orbit.note',
          title: 'Good',
          body: 'Good content',
        );
        final payload = jsonDecode(await repo.exportBundle()) as Map;
        final files = payload['files'] as Map;
        files['Notes/plain.md'] = base64Encode(
          utf8.encode('# Plain Markdown\n'),
        );
        files['Objects/bad.object.json'] = base64Encode(
          utf8.encode('{unfinished'),
        );
        files['Future/opaque.bin'] = base64Encode([0, 255, 1]);
        final bundle = BackupBundle.parse(jsonEncode(payload));
        expect(bundle.warnings.length, 2);
        final imported = await importBackup(bundle, root.path);
        expect(
          await File('$imported/Notes/plain.md').readAsString(),
          '# Plain Markdown\n',
        );
        expect(
          await File('$imported/Objects/bad.object.json').readAsString(),
          '{unfinished',
        );
        expect(await File('$imported/Future/opaque.bin').readAsBytes(), [
          0,
          255,
          1,
        ]);
      } finally {
        await repo.close();
      }
    },
  );
  test(
    'scripts and unknown file types need confirmation, documents do not',
    () {
      for (final path in [
        'setup.EXE',
        'run.ps1',
        'link.lnk',
        'report.pdf.exe',
        'thing.unknown',
      ]) {
        expect(attachmentNeedsConfirmation(path), isTrue);
      }
      for (final path in ['report.pdf', 'photo.png', 'notes.md']) {
        expect(attachmentNeedsConfirmation(path), isFalse);
      }
    },
  );
}
