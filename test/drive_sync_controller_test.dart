import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_note/app/drive_sync_controller.dart';
import 'package:orbit_note/app/google_cloud_controller.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/workspace_failure.dart';
import 'package:orbit_note/application/sync/google_account.dart';
import 'package:orbit_note/application/sync/sync_inventory.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/sync/google_drive_api.dart';
import 'package:orbit_note/features/workspace/drive_sync_settings.dart';
import 'package:orbit_note/features/workspace/google_drive_settings.dart';
import 'google_account_test.dart' show TestGoogleCredentials;
import 'google_drive_account_test.dart' show FakeGoogleAuth;
import 'support/drive_sync_service.dart';

class _ReadyWorkspace extends WorkspaceController {
  _ReadyWorkspace(this.source);
  final WorkspaceRepository source;
  @override
  int build() {
    repository = source;
    hasWorkspace = true;
    loading = false;
    mergeRepositoryObjects();
    return 0;
  }
}

class _MetadataRepository extends WorkspaceRepository {
  _MetadataRepository()
    : super(store: NativeWorkspaceStore(), index: MemoryObjectIndex());
  // Widget layout checks use deterministic size metadata. Native transfer tests
  // above/below still exercise real durable files and staging.
  @override
  Future<SyncFootprint> syncFootprint() async => const SyncFootprint(0, 0, 0);
}

void main() {
  late Directory root;
  late WorkspaceRepository repo;
  late WorkspaceController workspace;
  late FakeGoogleAuth auth;
  late DriveSyncService server;
  late GoogleCloudController cloud;
  late DriveSyncController sync;
  var shared = false;
  Widget settings({double textScale = 1}) => ProviderScope(
    overrides: [
      googleCloudProvider.overrideWithValue(cloud),
      driveSyncProvider.overrideWithValue(sync),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DriveSyncSettings(workspace: workspace),
          ),
        ),
      ),
    ),
  );
  DriveSyncController controller() => DriveSyncController(
    workspace,
    cloud,
    sharedActive: () => shared,
    automatic: false,
  );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('orbit-drive-controller-');
    repo = _MetadataRepository();
    await repo.initialize(path: root.path);
    workspace = WorkspaceController()
      ..repository = repo
      ..hasWorkspace = true;
    workspace.loading = false;
    workspace.mergeRepositoryObjects();
    auth = FakeGoogleAuth();
    server = DriveSyncService(repo.workspaceId);
    final api = GoogleDriveApi(
      auth: auth,
      client: server.client,
      localMetadata: TestGoogleCredentials()
        ..value = '{"subject-1":{"id":"root","pending":false}}',
    );
    cloud = GoogleCloudController(auth, api);
    shared = false;
    sync = controller();
    await sync.restore();
  });
  tearDown(() async {
    sync.dispose();
    cloud.dispose();
    workspace.cancelAllTimers();
    await workspace.flushAll();
    await repo.close();
    server.client.close();
    await root.delete(recursive: true);
  });
  test(
    'startup constructs account services only for a locally enabled binding',
    () async {
      var starts = 0, accounts = 0;
      ProviderContainer container() => ProviderContainer(
        overrides: [
          workspaceProvider.overrideWith(() => _ReadyWorkspace(repo)),
          googleCloudProvider.overrideWith((ref) {
            accounts++;
            return cloud;
          }),
          driveSyncProvider.overrideWith((ref) {
            ref.read(googleCloudProvider);
            starts++;
            return sync;
          }),
        ],
      );
      final first = container();
      first.read(driveSyncStartupProvider);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(starts, 0);
      expect(accounts, 0);
      first.dispose();
      await sync.enable();
      final second = container();
      second.read(driveSyncStartupProvider);
      for (var i = 0; i < 100 && starts == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(starts, 1);
      expect(accounts, 1);
      second.dispose();
    },
  );
  test(
    'device-local Archive metadata blocks setup before any upload',
    () async {
      workspace.session.archivedFolders = ['Notes/Archive'];
      await sync.enable();
      expect(sync.enabled, isFalse);
      expect(sync.error, contains('Archive'));
      expect(server.requests, 0);
    },
  );
  test(
    'interrupted first setup reuses its durable generated folder ID after restart',
    () async {
      server.files.remove('sync-vault');
      server.failFolderCreateOnce = true;
      await sync.enable();
      expect(sync.enabled, isFalse);
      final settings = await workspace
          .createSyncReplica()
          .createDriveSettingsStore()
          .load();
      final pending = settings!['pendingFolder'] as String;
      sync.dispose();
      sync = controller();
      await sync.restore();
      await sync.enable();
      expect(sync.enabled, isTrue);
      expect(sync.error, isEmpty);
      final folders = server.files.values
          .where(
            (f) =>
                (f.metadata['appProperties'] as Map?)?['orbitRole'] ==
                'sync-vault',
          )
          .toList();
      expect(folders.single.metadata['id'], pending);
      expect(sync.result?.upToDate, isTrue);
    },
  );
  testWidgets(
    'personal sync pause remains reachable during Google reconnection',
    (tester) async {
      sync.enabled = true;
      cloud.reconnectRequired = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            googleCloudProvider.overrideWithValue(cloud),
            driveSyncProvider.overrideWithValue(sync),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: GoogleDriveSettings(workspace: workspace),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final pause = find.widgetWithText(TextButton, 'Pause sync');
      expect(pause, findsOneWidget);
      await tester.ensureVisible(pause);
      expect(tester.widget<TextButton>(pause).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('automatic sync consent is cancellable and account-bound', (
    tester,
  ) async {
    await tester.pumpWidget(settings());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enable automatic sync'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(server.requests, 0);
    await tester.tap(find.text('Enable automatic sync'));
    await tester.pumpAndSettle();
    auth.current = const GoogleAccount(
      subject: 'changed',
      name: 'Other',
      email: 'changed@example.test',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(server.requests, 0);
    expect(find.textContaining('Start sync setup again'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'sync settings and consent wrap at narrow widths with enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      sync.status = 'Saved locally · Drive sync needs attention';
      sync.error =
          'The connected Google account needs permission before synchronization can continue. Local work is preserved.';
      await tester.pumpWidget(settings(textScale: 1.8));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Enable automatic sync'));
      await tester.tap(find.text('Enable automatic sync'));
      await tester.pumpAndSettle();
      expect(find.text('Enable automatic Drive sync?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'nothing uploads before explicit opt-in, and pause survives restart',
    () async {
      final note = await repo.create(
        typeId: 'orbit.note',
        title: 'Private',
        body: 'offline',
      );
      workspace.mergeRepositoryObjects();
      sync.changed();
      await sync.syncNow();
      expect(server.requests, 0);
      await sync.enable();
      expect(sync.enabled, isTrue);
      expect(sync.error, isEmpty);
      expect(sync.result?.upToDate, isTrue);
      expect(server.revisions, isNotEmpty);
      workspace.edit(note.id, body: 'new local edit');
      await sync.syncNow(force: true);
      expect(sync.status, contains('Up to date'));
      final creates = server.recordCreates;
      await sync.pause();
      sync.dispose();
      sync = controller();
      await sync.restore();
      expect(sync.enabled, isFalse);
      await sync.syncNow(force: true);
      expect(server.recordCreates, creates);
      expect(repo.objects.single.body, 'new local edit');
    },
  );
  test(
    'enabled binding resumes after controller restart without duplicating files',
    () async {
      await sync.enable();
      final creates = server.recordCreates;
      sync.dispose();
      sync = controller();
      await sync.restore();
      expect(sync.enabled, isTrue);
      await sync.syncNow();
      expect(server.recordCreates, creates);
      expect(sync.result?.upToDate, isTrue);
    },
  );
  test(
    'auth failure pauses automatic requests and exposes reconnect',
    () async {
      await sync.enable();
      server.rejectStatus = 401;
      await sync.syncNow(force: true);
      expect(cloud.reconnectRequired, isTrue);
      final requests = server.requests;
      await sync.syncNow();
      await sync.syncNow();
      expect(server.requests, requests);
      expect(sync.error, isNotEmpty);
      server.rejectStatus = null;
      await sync.syncNow(force: true);
      expect(sync.result?.upToDate, isTrue);
    },
  );
  test('changing accounts cannot upload to the previous binding', () async {
    await sync.enable();
    final creates = server.recordCreates;
    auth.current = const GoogleAccount(
      subject: 'other',
      name: 'Other',
      email: 'other@example.test',
    );
    sync.changed();
    await sync.syncNow(force: true);
    expect(server.recordCreates, creates);
    expect(sync.status, contains('Reconnect'));
    await sync.enable();
    expect(sync.error, contains('another account'));
    expect(server.recordCreates, creates);
  });
  test(
    'shared collaboration suspends personal sync without erasing its binding',
    () async {
      await sync.enable();
      final requests = server.requests;
      shared = true;
      sync.changed();
      await sync.syncNow(force: true);
      expect(server.requests, requests);
      expect(sync.status, contains('Shared Vault'));
      shared = false;
      sync.changed();
      await sync.syncNow(force: true);
      expect(sync.enabled, isTrue);
      expect(sync.result?.upToDate, isTrue);
    },
  );
  test(
    'pausing during publication retains local work and invalidates late checkpoint',
    () async {
      final note = await repo.create(
        typeId: 'orbit.note',
        title: 'Draft',
        body: 'before',
      );
      workspace.mergeRepositoryObjects();
      await sync.enable();
      workspace.edit(note.id, body: 'paused during upload');
      final entered = Completer<void>(), release = Completer<void>();
      server.beforeRecord = () async {
        entered.complete();
        await release.future;
      };
      final pass = sync.syncNow(force: true);
      await entered.future;
      await sync.pause();
      release.complete();
      await pass;
      expect(sync.enabled, isFalse);
      expect(repo.objects.single.body, 'paused during upload');
      expect(sync.status, contains('paused'));
      final settings = await workspace
          .createSyncReplica()
          .createDriveSettingsStore()
          .load();
      expect(settings!['enabled'], isFalse);
    },
  );
  test(
    'opening a cloud Vault prepares only a checked manifest and never uploads',
    () async {
      await sync.enable();
      final creates = server.recordCreates;
      await sync.refreshVaults();
      final bundle = await sync.prepareOpenVault(sync.availableVaults.single);
      expect(bundle.files.keys, ['workspace.json']);
      expect(
        jsonDecode(utf8.decode(bundle.files['workspace.json']!))['id'],
        repo.workspaceId,
      );
      expect(server.recordCreates, creates);
    },
  );
  test(
    'newer settings remain untouched and block setup before cloud writes',
    () async {
      final state = workspace.createSyncReplica().createDriveSettingsStore();
      await state.load();
      await state.save({
        'format': 'orbit-drive-settings',
        'version': 99,
        'unknown': 'keep',
      });
      await sync.restore();
      await sync.enable();
      expect(sync.enabled, isFalse);
      expect(sync.error, contains('preserved'));
      expect(server.requests, 0);
      expect(
        (await workspace
            .createSyncReplica()
            .createDriveSettingsStore()
            .load())!['unknown'],
        'keep',
      );
    },
  );
  test(
    'batch lease excludes foreground sync and restores the active binding',
    () async {
      await sync.enable();
      final requests = server.requests;
      await sync.runVaultBatch((current) async {
        expect(current(), true);
        expect(sync.busy, true);
        await sync.syncNow(force: true);
        expect(server.requests, requests);
        await expectLater(
          sync.runVaultBatch((_) async {}),
          throwsA(isA<WorkspaceConflict>()),
        );
      });
      expect(sync.busy, false);
      expect(sync.enabled, true);
      expect(workspace.repository.workspaceId, repo.workspaceId);
      await sync.syncNow(force: true);
      expect(sync.result!.upToDate, true);
    },
  );
  test(
    'changing accounts invalidates a batch lease before another operation',
    () async {
      await sync.runVaultBatch((current) async {
        expect(current(), true);
        auth.current = const GoogleAccount(subject: 'different-account');
        sync.changed();
        expect(current(), false);
      });
      expect(sync.busy, false);
      expect(server.recordCreates, 0);
    },
  );
}
