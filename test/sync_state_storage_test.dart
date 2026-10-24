import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/sync/sync_policy.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/sync_entry.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/storage/workspace_sync_state_store.dart';
import 'package:orbit_note/domain/workspace_failure.dart';
import 'package:orbit_note/infrastructure/sync/native_device_identity.dart';

void main() {
  test(
    'installation identity persists across versions and is separate from Vault identity',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-device-');
      try {
        final first = await loadSyncDevice(
          appVersion: '1',
          supportDirectory: '${root.path}/installation-a',
        );
        final reopened = await loadSyncDevice(
          appVersion: '2',
          supportDirectory: '${root.path}/installation-a',
        );
        final other = await loadSyncDevice(
          appVersion: '2',
          supportDirectory: '${root.path}/installation-b',
        );
        expect(first.id, reopened.id);
        expect(first.id, isNot(other.id));
        expect(reopened.appVersion, '2');
        expect(reopened.platform, Platform.operatingSystem);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'durable sync state survives reopen and is excluded from backup',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-sync-state-');
      final store = NativeWorkspaceStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      try {
        await repo.initialize(path: root.path);
        final state = WorkspaceSyncStateStore(store);
        expect(await state.load(), isNull);
        await state.save({
          'version': 1,
          'pending': {'note': 'pending-hash'},
          'cursor': '42',
        });
        await repo.close();
        await repo.initialize(path: root.path);
        expect((await WorkspaceSyncStateStore(store).load())!['cursor'], '42');
        final backup = jsonDecode(await repo.exportBundle()) as Map;
        expect(
          (backup['files'] as Map).keys.any(
            (p) => (p as String).startsWith('.orbit/device/'),
          ),
          isFalse,
        );
      } finally {
        await repo.close();
        await root.delete(recursive: true);
      }
    },
  );

  test('stale sync state writer cannot overwrite a newer checkpoint', () async {
    final root = await Directory.systemTemp.createTemp('orbit-sync-cas-');
    final store = NativeWorkspaceStore();
    try {
      await store.initialize(path: root.path);
      final first = WorkspaceSyncStateStore(store),
          second = WorkspaceSyncStateStore(store);
      await first.load();
      await second.load();
      await first.save({'cursor': 'new'});
      await expectLater(
        second.save({'cursor': 'old'}),
        throwsA(isA<WorkspaceConflict>()),
      );
      expect((await first.load())!['cursor'], 'new');
    } finally {
      await store.close();
      await root.delete(recursive: true);
    }
  });

  test('device journal recovers staged sync state on restart', () async {
    final root = await Directory.systemTemp.createTemp('orbit-sync-recovery-');
    final store = NativeWorkspaceStore();
    try {
      await store.initialize(path: root.path);
      const target = WorkspaceSyncStateStore.path;
      final after = Uint8List.fromList(utf8.encode('{"cursor":"durable"}'));
      final temp = '$target.orbit-test.tmp';
      await File('${root.path}/$temp').parent.create(recursive: true);
      await File('${root.path}/$temp').writeAsBytes(after, flush: true);
      final journal = File('${root.path}/.orbit/device/recovery/test.json');
      await journal.parent.create(recursive: true);
      await journal.writeAsString(
        jsonEncode({
          'format': 'orbit-note-file-save',
          'version': 1,
          'target': target,
          'temp': temp,
          'beforeHash': null,
          'afterHash': sha256.convert(after).toString(),
          'beforePath': null,
        }),
        flush: true,
      );
      await store.close();
      await store.initialize(path: root.path);
      expect(
        (await WorkspaceSyncStateStore(store).load())!['cursor'],
        'durable',
      );
      expect(await journal.exists(), isFalse);
    } finally {
      await store.close();
      await root.delete(recursive: true);
    }
  });

  test(
    'sync policy excludes device, cache, index and recovery, retains tombstones',
    () {
      for (final path in [
        '.orbit/device/settings.json',
        '.orbit/workspace.sqlite-wal',
        '.orbit/cache/image.png',
        '.orbit/recovery/op.json',
        '.orbit/history/old.before',
        'Notes/a.md.orbit-test.tmp',
      ]) {
        expect(syncPathRole(path), SyncPathRole.excluded);
      }
      expect(syncPathRole('.orbit/tombstones/id.json'), SyncPathRole.tombstone);
      expect(syncPathRole('Notes/Archived/a.md'), SyncPathRole.object);
      expect(syncPathRole('Objects/future.object.json'), SyncPathRole.object);
      expect(
        syncPathRole('Attachments/hash/file.pdf'),
        SyncPathRole.attachment,
      );
      for (final path in [
        'seWS26_ue1_angabe.pdf',
        'Courses/Week 1/SLIDES.PDF',
        'Notes/Lecture/image.PNG',
        'References/report.docx',
        'References/data.csv',
        'Models/chair.glb',
        'readme.md',
      ]) {
        expect(syncPathRole(path), SyncPathRole.attachment, reason: path);
      }
      for (final path in [
        'Future/unknown.json',
        '.git/notes.pdf',
        '.Orbit/device/secret.pdf',
        '.env',
        'config/client_secret.json',
        'Future/future.object.json',
      ]) {
        expect(syncPathRole(path), SyncPathRole.unsupported, reason: path);
      }
    },
  );

  test('unsafe and colliding remote paths are rejected before apply', () {
    SyncEntry entry(String key, String path) =>
        SyncEntry(key: key, path: path, hash: 'a' * 64);
    for (final path in [
      '../Notes/a.md',
      'Notes/CON.md',
      'Notes/a.md ',
      '.orbit/device/token.json',
    ]) {
      expect(
        () => validateSyncEntries({'a': entry('a', path)}),
        throwsA(isA<WorkspaceFailure>()),
      );
    }
    expect(
      () => validateSyncEntries({
        'a': entry('a', 'Notes/A.md'),
        'b': entry('b', 'Notes/a.md'),
      }),
      throwsA(isA<WorkspaceConflict>()),
    );
  });
}
