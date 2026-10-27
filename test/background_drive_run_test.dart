import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/device_secret_store.dart';
import 'package:orbit_note/application/sync/background_drive_run.dart';
import 'package:orbit_note/application/sync/drive_vault_batch.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/sync/google_drive_api.dart';
import 'package:orbit_note/platform/vault_discovery_native.dart';
import 'google_account_test.dart' show TestGoogleCredentials;
import 'google_drive_account_test.dart' show FakeGoogleAuth;
import 'support/drive_sync_service.dart';

class _Secrets implements DeviceSecretStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async {
    value = v;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

void main() {
  late Directory root;
  late DriveSyncService server;
  late GoogleDriveApi api;
  late FakeGoogleAuth auth;
  late _Secrets settings, report;
  late String path, id;
  Map<String, dynamic> enrollment({bool enabled = true}) => {
    'format': 'orbit-drive-schedule',
    'version': 1,
    'enabled': true,
    'backgroundEnabled': enabled,
    'subject': 'subject-1',
    'vaults': [
      {'path': path, 'id': id, 'name': 'Course'},
    ],
  };
  Future<WorkspaceRepository> open() async {
    final repo = WorkspaceRepository(
      store: NativeWorkspaceStore(existingWorkspaceId: id),
      index: MemoryObjectIndex(),
    );
    await repo.initialize(path: path);
    return repo;
  }

  BackgroundDriveRun runner() => BackgroundDriveRun(
    settings: settings,
    report: report,
    auth: auth,
    createBatch: (current) => DriveVaultBatch(
      api: api,
      requireEnabledBinding: true,
      isCurrent: current,
      onChanged: () {},
      open: (v) async {
        final repo = await openExistingVault(v);
        return VaultRepositoryLease(repo, repo.close);
      },
    ),
  );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('orbit-background-');
    path = '${root.path}/Course';
    final repo = WorkspaceRepository(
      store: NativeWorkspaceStore(),
      index: MemoryObjectIndex(),
    );
    await repo.initialize(path: path);
    id = repo.workspaceId;
    await repo.create(
      typeId: 'orbit.note',
      title: 'Offline work',
      body: 'Exact 😀\r\n',
    );
    await repo.close();
    server = DriveSyncService(id);
    auth = FakeGoogleAuth();
    api = GoogleDriveApi(
      auth: auth,
      client: server.client,
      localMetadata: TestGoogleCredentials(),
    );
    settings = _Secrets()..value = jsonEncode(enrollment());
    report = _Secrets();
  });
  tearDown(() async {
    server.client.close();
    await root.delete(recursive: true);
  });
  Future<void> bind({bool enabled = true}) async {
    final repo = await open();
    final store = WorkspaceSyncReplica(
      repo,
      canApply: () => true,
    ).createDriveSettingsStore();
    await store.load();
    await store.save({
      'format': 'orbit-drive-settings',
      'version': 1,
      'workspaceId': id,
      'subject': 'subject-1',
      'email': 'student@example.test',
      'folder': 'sync-vault',
      'enabled': enabled,
    });
    await repo.close();
  }

  test(
    'opt-in is required and missing bindings never create folders or upload',
    () async {
      settings.value = jsonEncode(enrollment(enabled: false));
      expect(await runner().run(), true);
      expect(server.requests, 0);
      settings.value = jsonEncode(enrollment());
      expect(await runner().run(), true);
      expect(server.requests, 0);
      expect(
        (jsonDecode(report.value!) as Map)['vaults'][0]['state'],
        'paused',
      );
    },
  );
  test(
    'paused per-Vault binding remains paused after worker restart',
    () async {
      await bind(enabled: false);
      expect(await runner().run(), true);
      expect(await runner().run(), true);
      expect(server.requests, 0);
      final repo = await open();
      expect(
        (await WorkspaceSyncReplica(
          repo,
          canApply: () => true,
        ).createDriveSettingsStore().load())!['enabled'],
        false,
      );
      await repo.close();
    },
  );
  test(
    'existing binding syncs and repeated jobs do not duplicate publications',
    () async {
      await bind();
      expect(await runner().run(), true);
      final creates = server.recordCreates;
      expect(creates, greaterThan(0));
      expect(await runner().run(), true);
      expect(server.recordCreates, creates);
      expect((jsonDecode(report.value!) as Map)['status'], 'complete');
    },
  );
  test(
    'locked Vault is skipped and can sync after editor releases ownership',
    () async {
      await bind();
      final repo = await open();
      expect(await runner().run(), false);
      expect(server.recordCreates, 0);
      await repo.close();
      expect(await runner().run(), true);
    },
  );
  test(
    'offline worker resumes through durable engine on next invocation',
    () async {
      await bind();
      server.offline = true;
      expect(await runner().run(), false);
      server.offline = false;
      expect(await runner().run(), true);
    },
  );
  test('sign-out never opens consent or makes network requests', () async {
    await bind();
    auth.current = null;
    expect(await runner().run(), false);
    expect(server.requests, 0);
    expect((jsonDecode(report.value!) as Map)['status'], 'reconnect');
  });
  test('malformed, duplicate and future enrollment fails closed', () async {
    for (final value in [
      {...enrollment(), 'version': 2},
      {
        ...enrollment(),
        'vaults': [
          ...(enrollment()['vaults'] as List),
          ...(enrollment()['vaults'] as List),
        ],
      },
      {...enrollment(), 'backgroundEnabled': 'true'},
    ]) {
      settings.value = jsonEncode(value);
      expect(await runner().run(), false);
      expect(server.requests, 0);
    }
  });
}
