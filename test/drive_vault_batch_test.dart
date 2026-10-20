import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/sync/drive_vault_batch.dart';
import 'package:orbit_note/application/sync/google_account.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/app/drive_sync_controller.dart';
import 'package:orbit_note/app/google_cloud_controller.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/domain/vault_candidate.dart';
import 'package:orbit_note/domain/workspace_failure.dart';
import 'package:orbit_note/features/workspace/drive_vault_batch_dialog.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/sync/google_drive_api.dart';
import 'package:orbit_note/platform/import_backup_native.dart';
import 'package:orbit_note/platform/vault_discovery_native.dart';
import 'google_account_test.dart' show TestGoogleCredentials;
import 'google_drive_account_test.dart' show FakeGoogleAuth;
import 'support/drive_sync_service.dart';
import 'support/memory_store.dart';

void main() {
  late Directory root;
  late DriveSyncService server;
  late FakeGoogleAuth auth;
  late GoogleDriveApi api;
  var current = true;
  Future<VaultCandidate> seed(String name) async {
    final repo = WorkspaceRepository(
      store: NativeWorkspaceStore(),
      index: MemoryObjectIndex(),
    );
    final path = '${root.path}/$name';
    await repo.initialize(path: path);
    await repo.renameWorkspace(name);
    await repo.create(
      typeId: 'orbit.note',
      title: '$name note',
      body: 'Exact 😀\r\n$name',
    );
    await repo.create(
      typeId: 'orbit.canvas',
      title: '$name board',
      data: {'elements': [], 'unknown': true},
    );
    await repo.importAttachment(
      name: '$name.bin',
      bytes: Uint8List.fromList(List.generate(300000, (i) => i % 251)),
    );
    final v = VaultCandidate(path: path, id: repo.workspaceId, name: name);
    await repo.close();
    return v;
  }

  Future<VaultRepositoryLease> open(VaultCandidate v) async {
    final repo = await openExistingVault(v);
    return VaultRepositoryLease(repo, repo.close);
  }

  DriveVaultBatch batch({void Function()? changed}) => DriveVaultBatch(
    api: api,
    open: open,
    isCurrent: () => current,
    onChanged: changed ?? () {},
    createDownload: (v, bundle) async => VaultCandidate(
      path: await importBackup(bundle, root.path),
      id: v.workspaceId,
      name: v.name,
    ),
  );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('orbit-bulk-drive-');
    current = true;
    auth = FakeGoogleAuth();
    server = DriveSyncService('unused-fixture-vault');
    api = GoogleDriveApi(
      auth: auth,
      client: server.client,
      localMetadata: TestGoogleCredentials()
        ..value = '{"subject-1":{"id":"root","pending":false}}',
    );
  });
  tearDown(() async {
    server.client.close();
    await root.delete(recursive: true);
  });
  test(
    'folder discovery is shallow, deduplicated, read-only and format checked',
    () async {
      final a = await seed('Course A'), b = await seed('Course B');
      await Directory('${root.path}/other').create();
      await File(
        '${root.path}/other/workspace.json',
      ).writeAsString('{bad json');
      await Directory('${root.path}/nested').create();
      await Directory(a.path).rename('${root.path}/nested/deep');
      final found = await discoverVaults([root.path, b.path], children: true);
      expect(found.vaults.map((e) => e.id), [b.id]);
      expect(found.warnings, isNotEmpty);
      expect(
        await File('${root.path}/other/workspace.json').readAsString(),
        '{bad json',
      );
      expect((await discoverVaults([b.path, b.path])).vaults.length, 1);
    },
  );
  test(
    'deleted and changed selections never create replacement Vaults',
    () async {
      final v = await seed('Deleted');
      await Directory(v.path).delete(recursive: true);
      await expectLater(openExistingVault(v), throwsA(isA<WorkspaceFailure>()));
      expect(await Directory(v.path).exists(), isFalse);
      final other = await seed('Changed');
      final file = File('${other.path}/workspace.json');
      final value = jsonDecode(await file.readAsString()) as Map;
      await file.writeAsString(jsonEncode({...value, 'id': 'replacement-id'}));
      final before = await file.readAsString();
      await expectLater(
        openExistingVault(other),
        throwsA(isA<WorkspaceFailure>()),
      );
      expect(await file.readAsString(), before);
    },
  );
  test(
    'only selected Vaults upload, bindings survive restart and retry creates no duplicates',
    () async {
      final a = await seed('Alpha'),
          b = await seed('Beta'),
          omitted = await seed('Private');
      final jobs = [VaultTransferJob.local(a), VaultTransferJob.local(b)];
      await batch().run(jobs);
      expect(
        jobs.map((j) => j.state),
        everyElement(VaultTransferState.complete),
      );
      final remote = await api.listSyncVaults();
      expect(remote.map((v) => v.workspaceId), containsAll([a.id, b.id]));
      expect(remote.map((v) => v.workspaceId), isNot(contains(omitted.id)));
      final creates = server.recordCreates;
      await batch().run([VaultTransferJob.local(a), VaultTransferJob.local(b)]);
      expect(server.recordCreates, creates);
      final repo = await openExistingVault(a);
      final settings = await WorkspaceSyncReplica(
        repo,
        canApply: () => true,
      ).createDriveSettingsStore().load();
      expect(settings!['enabled'], isTrue);
      expect(settings['subject'], 'subject-1');
      await repo.close();
      expect(
        await File(
          '${omitted.path}/.orbit/device/sync/drive-settings-v1.json',
        ).exists(),
        isFalse,
      );
    },
  );
  test(
    'twelve Vaults with the same display name retain twelve separate cloud identities',
    () async {
      final jobs = <VaultTransferJob>[];
      for (var i = 0; i < 12; i++) {
        final repo = WorkspaceRepository(
          store: NativeWorkspaceStore(),
          index: MemoryObjectIndex(),
        );
        final path = '${root.path}/course-$i';
        await repo.initialize(path: path);
        await repo.renameWorkspace('University');
        jobs.add(
          VaultTransferJob.local(
            VaultCandidate(path: path, id: repo.workspaceId, name: repo.name),
          ),
        );
        await repo.close();
      }
      await batch().run(jobs);
      expect(
        jobs.map((j) => j.state),
        everyElement(VaultTransferState.complete),
      );
      final ids = jobs.map((j) => j.id).toSet();
      expect(
        (await api.listSyncVaults())
            .where((v) => ids.contains(v.workspaceId))
            .length,
        12,
      );
    },
  );
  test(
    'a locked Vault fails independently while the next Vault completes',
    () async {
      final a = await seed('Locked'), b = await seed('Available');
      final held = await openExistingVault(a);
      final jobs = [VaultTransferJob.local(a), VaultTransferJob.local(b)];
      try {
        await batch().run(jobs);
        expect(jobs[0].state, VaultTransferState.failed);
        expect(jobs[1].state, VaultTransferState.complete);
        expect(
          (await api.listSyncVaults()).map((v) => v.workspaceId),
          isNot(contains(a.id)),
        );
      } finally {
        await held.close();
      }
    },
  );
  test('same-identity copies are rejected before cloud requests', () async {
    final a = await seed('Same');
    final before = server.requests;
    await expectLater(
      batch().run([VaultTransferJob.local(a), VaultTransferJob.local(a)]),
      throwsA(isA<WorkspaceConflict>()),
    );
    expect(server.requests, before);
  });
  test(
    'cancellation stops later Vaults and resumes durable setup without duplicate folders',
    () async {
      final a = await seed('Cancel A'), b = await seed('Cancel B');
      late DriveVaultBatch transfer;
      var cancel = true;
      transfer = batch(
        changed: () {
          if (cancel && server.recordCreates > 0) {
            cancel = false;
            transfer.cancel();
          }
        },
      );
      final jobs = [VaultTransferJob.local(a), VaultTransferJob.local(b)];
      await transfer.run(jobs);
      expect(
        jobs.every((j) => j.state == VaultTransferState.cancelled),
        isTrue,
      );
      expect(
        (await api.listSyncVaults()).where((v) => v.workspaceId == b.id),
        isEmpty,
      );
      final repo = await openExistingVault(a);
      final settings = await WorkspaceSyncReplica(
        repo,
        canApply: () => true,
      ).createDriveSettingsStore().load();
      expect(settings!['enabled'], isFalse);
      await repo.close();
      await batch().run(jobs);
      expect(
        jobs.map((j) => j.state),
        everyElement(VaultTransferState.complete),
      );
      expect(
        (await api.listSyncVaults()).where((v) => v.workspaceId == a.id).length,
        1,
      );
    },
  );
  test(
    'account switch cancels all remaining Vaults without cross-account publication',
    () async {
      final a = await seed('Account A'), b = await seed('Account B');
      var switched = false;
      final transfer = batch(
        changed: () {
          if (!switched && server.recordCreates > 0) {
            switched = true;
            auth.current = const GoogleAccount(subject: 'another-account');
          }
        },
      );
      final jobs = [VaultTransferJob.local(a), VaultTransferJob.local(b)];
      await transfer.run(jobs);
      expect(
        jobs.every((j) => j.state == VaultTransferState.cancelled),
        isTrue,
      );
      expect(
        server.revisions.every(
          (r) => (r.metadata['appProperties'] as Map)['orbitVaultId'] != b.id,
        ),
        isTrue,
      );
    },
  );
  test(
    'bulk downloads create distinct exact Vaults and retain durable automatic bindings',
    () async {
      final a = await seed('Download A'), b = await seed('Download B');
      await batch().run([VaultTransferJob.local(a), VaultTransferJob.local(b)]);
      final vaults = (await api.listSyncVaults()).where(
        (v) => [a.id, b.id].contains(v.workspaceId),
      );
      final jobs = vaults.map(VaultTransferJob.cloud).toList();
      await batch().run(jobs);
      expect(
        jobs.map((j) => j.state),
        everyElement(VaultTransferState.complete),
      );
      expect(jobs.map((j) => j.local!.path).toSet().length, 2);
      for (final job in jobs) {
        final repo = await openExistingVault(job.local!);
        expect(repo.workspaceId, job.id);
        expect(
          repo.objects.where((o) => o.typeId == 'orbit.note').single.body,
          'Exact 😀\r\n${job.name}',
        );
        expect(
          repo.objects
              .where((o) => o.typeId == 'orbit.canvas')
              .single
              .data['unknown'],
          true,
        );
        final file = repo.objects.singleWhere((o) => o.typeId == 'orbit.file');
        expect(
          (await repo.readAttachment(
            file.properties['contentRef'] as String,
          ))!.length,
          300000,
        );
        await repo.close();
      }
    },
  );
  test(
    'newer binding remains untouched and does not prevent unrelated uploads',
    () async {
      final a = await seed('Future'), b = await seed('Normal');
      final repo = await openExistingVault(a);
      final store = WorkspaceSyncReplica(
        repo,
        canApply: () => true,
      ).createDriveSettingsStore();
      await store.load();
      await store.save({
        'format': 'orbit-drive-settings',
        'version': 99,
        'future': true,
      });
      await repo.close();
      final jobs = [VaultTransferJob.local(a), VaultTransferJob.local(b)];
      await batch().run(jobs);
      expect(jobs[0].state, VaultTransferState.failed);
      expect(jobs[1].state, VaultTransferState.complete);
      final after = await openExistingVault(a);
      expect(
        (await WorkspaceSyncReplica(
          after,
          canApply: () => true,
        ).createDriveSettingsStore().load())!['version'],
        99,
      );
      await after.close();
    },
  );
  test(
    'download retry reuses its published local folder after cancellation',
    () async {
      final a = await seed('Retry download');
      await batch().run([VaultTransferJob.local(a)]);
      final remote = (await api.listSyncVaults()).singleWhere(
        (v) => v.workspaceId == a.id,
      );
      final job = VaultTransferJob.cloud(remote);
      var creates = 0, cancel = true;
      late DriveVaultBatch transfer;
      transfer = DriveVaultBatch(
        api: api,
        open: open,
        isCurrent: () => current,
        createDownload: (v, bundle) async {
          creates++;
          return VaultCandidate(
            path: await importBackup(bundle, root.path),
            id: v.workspaceId,
            name: v.name,
          );
        },
        onChanged: () {
          if (cancel && job.local != null) {
            cancel = false;
            transfer.cancel();
          }
        },
      );
      await transfer.run([job]);
      expect(job.state, VaultTransferState.cancelled);
      final path = job.local!.path;
      await transfer.run([job]);
      expect(job.state, VaultTransferState.complete);
      expect(job.local!.path, path);
      expect(creates, 1);
    },
  );
  test(
    'offline conflicts remain reviewable and do not overwrite either draft',
    () async {
      final a = await seed('Conflict');
      await batch().run([VaultTransferJob.local(a)]);
      final remote = (await api.listSyncVaults()).singleWhere(
        (v) => v.workspaceId == a.id,
      );
      final copy = VaultTransferJob.cloud(remote);
      await batch().run([copy]);
      final repoA = await openExistingVault(a),
          repoB = await openExistingVault(copy.local!);
      final noteA = repoA.objects.singleWhere((o) => o.typeId == 'orbit.note');
      final noteB = repoB.objects.singleWhere((o) => o.id == noteA.id);
      await repoA.save(noteA.copyWith(body: 'cloud draft'));
      await repoB.save(noteB.copyWith(body: 'offline draft'));
      await repoA.close();
      await repoB.close();
      await batch().run([VaultTransferJob.local(a)]);
      final job = VaultTransferJob.local(copy.local!);
      await batch().run([job]);
      expect(job.state, VaultTransferState.review);
      final after = await openExistingVault(copy.local!);
      expect(
        after.objects.singleWhere((o) => o.id == noteA.id).body,
        'offline draft',
      );
      final state = await WorkspaceSyncReplica(
        after,
        canApply: () => true,
      ).createStateStore().load();
      expect((state!['conflicts'] as Map).containsKey(noteA.id), true);
      await after.close();
    },
  );
  test(
    'an active-Vault lease retains draft guards during incoming downloads',
    () async {
      final a = await seed('Draft guard');
      await batch().run([VaultTransferJob.local(a)]);
      final remote = (await api.listSyncVaults()).singleWhere(
        (v) => v.workspaceId == a.id,
      );
      final copy = VaultTransferJob.cloud(remote);
      await batch().run([copy]);
      final source = await openExistingVault(a);
      final note = source.objects.singleWhere((o) => o.typeId == 'orbit.note');
      await source.save(note.copyWith(body: 'incoming cloud edit'));
      await source.close();
      await batch().run([VaultTransferJob.local(a)]);
      final active = await openExistingVault(copy.local!);
      try {
        final transfer = DriveVaultBatch(
          api: api,
          isCurrent: () => current,
          onChanged: () {},
          open: (_) async => VaultRepositoryLease(
            active,
            () async {},
            createReplica: (guard) => WorkspaceSyncReplica(
              active,
              canApply: () => false,
              isCurrent: guard,
            ),
          ),
        );
        final job = VaultTransferJob.local(copy.local!);
        await transfer.run([job]);
        expect(job.state, VaultTransferState.failed);
        expect(
          active.objects.singleWhere((o) => o.id == note.id).body,
          'Exact 😀\r\nDraft guard',
        );
      } finally {
        await active.close();
      }
    },
  );
  test(
    'adding many downloaded recents preserves active selection and unknown preferences',
    () async {
      final active = await seed('Active');
      final prefs = File('${root.path}/selection.json');
      await prefs.writeAsString(
        jsonEncode({
          'version': 1,
          'path': active.path,
          'closed': false,
          'future': 42,
          'recent': [active.path],
        }),
      );
      final store = NativeWorkspaceStore(
        rememberWorkspace: true,
        selectionFilePath: prefs.path,
      );
      for (var i = 0; i < 13; i++) {
        final dir = await Directory('${root.path}/download-$i').create();
        await store.rememberRecentLocation(dir.path);
      }
      final value = jsonDecode(await prefs.readAsString()) as Map;
      expect(value['path'], active.path);
      expect(value['closed'], false);
      expect(value['future'], 42);
      expect((await store.recentLocations()).length, 14);
    },
  );
  testWidgets(
    'account change while discovery waits invalidates the picker consent',
    (tester) async {
      final repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      final workspace = WorkspaceController()
        ..repository = repo
        ..hasWorkspace = true
        ..loading = false;
      final cloud = GoogleCloudController(auth, api);
      final sync = DriveSyncController(
        workspace,
        cloud,
        sharedActive: () => false,
        automatic: false,
      );
      final pending = Completer<VaultDiscovery>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriveVaultBatchDialog(
              workspace: workspace,
              sync: sync,
              cloud: cloud,
              findVaults: (paths, {bool children = false}) => pending.future,
            ),
          ),
        ),
      );
      await tester.pump();
      auth.current = const GoogleAccount(subject: 'different-account');
      pending.complete(
        const VaultDiscovery([
          VaultCandidate(
            path: 'memory',
            id: 'selected',
            name: 'Selected Vault',
          ),
        ], []),
      );
      await tester.pump();
      expect(
        find.textContaining('The account or active Vault changed'),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Upload and sync selected Vaults'),
      );
      expect(button.onPressed, isNull);
      expect(server.requests, 0);
      await tester.pumpWidget(const SizedBox());
      sync.dispose();
      cloud.dispose();
      workspace.cancelAllTimers();
      await repo.close();
    },
  );
  testWidgets(
    'Vault picker works at narrow widths and enlarged text without selecting by default',
    (tester) async {
      late VaultCandidate candidate;
      late WorkspaceRepository repo;
      await tester.runAsync(() async {
        candidate = await seed('UI course');
        repo = await openExistingVault(candidate);
      });
      final workspace = WorkspaceController()
        ..repository = repo
        ..hasWorkspace = true
        ..loading = false;
      final cloud = GoogleCloudController(auth, api);
      final sync = DriveSyncController(
        workspace,
        cloud,
        sharedActive: () => false,
        automatic: false,
      );
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 780),
                textScaler: TextScaler.linear(2),
              ),
              child: DriveVaultBatchDialog(
                workspace: workspace,
                sync: sync,
                cloud: cloud,
                findVaults: (paths, {bool children = false}) async =>
                    VaultDiscovery([candidate], []),
                scheduleVaults: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('0 Vaults selected'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Select all'));
      await tester.tap(find.text('Select all'));
      await tester.pump();
      expect(find.text('1 Vault selected'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      sync.dispose();
      cloud.dispose();
      workspace.cancelAllTimers();
      await tester.runAsync(repo.close);
    },
  );
}
