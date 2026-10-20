import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orbit_note/app/collaboration_controller.dart';
import 'package:orbit_note/app/drive_sync_controller.dart';
import 'package:orbit_note/app/drive_vault_scheduler.dart';
import 'package:orbit_note/app/google_cloud_controller.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/device_secret_store.dart';
import 'package:orbit_note/application/sync/drive_vault_batch.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/vault_candidate.dart';
import 'package:orbit_note/features/workspace/drive_schedule_settings.dart';
import 'package:orbit_note/features/workspace/collaboration_settings.dart';
import 'package:orbit_note/infrastructure/collaboration/server.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/sync/google_drive_api.dart';
import 'package:orbit_note/platform/vault_discovery_native.dart';
import 'google_account_test.dart' show TestGoogleCredentials;
import 'google_drive_account_test.dart' show FakeGoogleAuth;
import 'support/drive_sync_service.dart';
import 'support/memory_store.dart';

class PrivateMemory implements DeviceSecretStore {
  String? value;
  bool failWrite = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    if (failWrite) throw StateError('Device storage unavailable');
    this.value = value;
  }

  @override
  Future<void> delete() async => value = null;
}

void main() {
  test(
    'local-only startup does not construct a scheduler or contact an account',
    () async {
      for (final raw in <String?>[
        null,
        '{"format":"orbit-drive-schedule","version":1,"enabled":false}',
        '{"format":"orbit-drive-schedule","version":99,"enabled":true}',
        'invalid',
      ]) {
        var created = 0;
        final container = ProviderContainer(
          overrides: [
            driveScheduleStoreProvider.overrideWithValue(
              PrivateMemory()..value = raw,
            ),
            driveVaultSchedulerProvider.overrideWith((_) {
              created++;
              throw StateError('Unexpected account startup');
            }),
          ],
        );
        container.read(driveScheduleStartupProvider);
        await Future<void>.delayed(Duration.zero);
        expect(created, 0);
        container.dispose();
      }
    },
  );
  test(
    'server data inside a Vault is rejected before creating private files',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'orbit-server-directory-',
      );
      try {
        final vault = await Directory('${root.path}/vault').create();
        await File(
          '${vault.path}/workspace.json',
        ).writeAsString('{"version":1}');
        final target = Directory('${vault.path}/nested/private');
        await expectLater(
          validateCollaborationDirectory(target),
          throwsStateError,
        );
        await expectLater(
          CollaborationServer(target, 'private').start(port: 0),
          throwsStateError,
        );
        expect(await target.exists(), false);
        await validateCollaborationDirectory(Directory('${root.path}/private'));
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
  group('scheduled Drive Vault checks', () {
    late Directory root;
    late WorkspaceRepository active;
    late WorkspaceController workspace;
    late DriveSyncService server;
    late GoogleCloudController cloud;
    late DriveSyncController sync;
    late DriveVaultScheduler scheduler;
    late PrivateMemory settings;
    var shared = false;
    var clock = DateTime.utc(2026, 10, 15);
    Future<VaultRepositoryLease> open(VaultCandidate v) async {
      final repo = await openExistingVault(v);
      return VaultRepositoryLease(repo, repo.close);
    }

    Future<VaultCandidate> seed(String name, {bool bound = true}) async {
      final repo = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: MemoryObjectIndex(),
      );
      await repo.initialize(path: '${root.path}/$name');
      await repo.create(typeId: 'orbit.note', title: name, body: 'local $name');
      final v = VaultCandidate(
        path: repo.location,
        id: repo.workspaceId,
        name: name,
      );
      await repo.close();
      if (bound) {
        final batch = DriveVaultBatch(
          api: cloud.drive,
          open: open,
          isCurrent: () => true,
          onChanged: () {},
        );
        await batch.run([VaultTransferJob.local(v)]);
      }
      return v;
    }

    DriveVaultScheduler make() => DriveVaultScheduler(
      workspace: workspace,
      sync: sync,
      cloud: cloud,
      store: settings,
      sharedActive: () => shared,
      automatic: false,
      now: () => clock,
    );
    testWidgets(
      'scheduled controls remain usable at narrow width and enlarged text',
      (tester) async {
        await tester.runAsync(() async {
          await scheduler.addVaults([
            await seed('A deliberately long Vault name for narrow layouts'),
          ]);
        });
        tester.view.physicalSize = const Size(390, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              driveVaultSchedulerProvider.overrideWithValue(scheduler),
            ],
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: const Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: DriveScheduleSettings(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Manage scheduled Vault checks'));
        await tester.pumpAndSettle();
        expect(find.text('Pause scheduled checks'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
    setUp(() async {
      shared = false;
      clock = DateTime.utc(2026, 10, 15);
      root = await Directory.systemTemp.createTemp('orbit-scheduled-sync-');
      active = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: MemoryObjectIndex(),
      );
      await active.initialize(path: '${root.path}/active');
      workspace = WorkspaceController()
        ..repository = active
        ..hasWorkspace = true
        ..loading = false;
      server = DriveSyncService('fixture');
      final auth = FakeGoogleAuth();
      cloud = GoogleCloudController(
        auth,
        GoogleDriveApi(
          auth: auth,
          client: server.client,
          localMetadata: TestGoogleCredentials()
            ..value = '{"subject-1":{"id":"root","pending":false}}',
        ),
      );
      sync = DriveSyncController(
        workspace,
        cloud,
        sharedActive: () => shared,
        automatic: false,
      );
      await sync.restore();
      settings = PrivateMemory();
      scheduler = make();
    });
    tearDown(() async {
      scheduler.dispose();
      sync.dispose();
      cloud.dispose();
      workspace.cancelAllTimers();
      await active.close();
      server.client.close();
      await root.delete(recursive: true);
    });
    test(
      'selected closed Vault checks persist across restart without changing the active Vault',
      () async {
        final v = await seed('Course');
        await scheduler.addVaults([v]);
        final replica = await openExistingVault(v);
        await replica.save(
          replica.objects.single.copyWith(body: 'new offline work'),
        );
        await replica.close();
        final creates = server.recordCreates;
        scheduler.dispose();
        scheduler = make();
        await scheduler.restore();
        expect(scheduler.enabled, true);
        await scheduler.checkNow(force: true);
        expect(scheduler.jobs.single.state, VaultTransferState.complete);
        expect(server.recordCreates, greaterThan(creates));
        expect(workspace.repository, same(active));
        expect(workspace.repository.location, contains('active'));
      },
    );
    test(
      'scheduled checks never create bindings or resume individually paused Vaults',
      () async {
        final v = await seed('Unbound', bound: false);
        await scheduler.addVaults([v]);
        final requests = server.requests;
        await scheduler.checkNow(force: true);
        expect(scheduler.jobs.single.state, VaultTransferState.paused);
        expect(server.requests, requests);
        expect(
          await File(
            '${v.path}/.orbit/device/sync/drive-settings-v1.json',
          ).exists(),
          false,
        );
      },
    );
    test(
      'active Vault, account mismatch and shared-session activity do not trigger inactive transfers',
      () async {
        final v = await seed('Inactive');
        await scheduler.addVaults([
          v,
          VaultCandidate(
            path: active.location,
            id: active.workspaceId,
            name: 'Active',
          ),
        ]);
        final requests = server.requests;
        shared = true;
        await scheduler.checkNow(force: true);
        expect(server.requests, requests);
        expect(scheduler.status, contains('Shared Vault'));
        shared = false;
        await scheduler.checkNow(force: true);
        expect(scheduler.jobs.length, 1);
        expect(scheduler.jobs.single.id, v.id);
        await scheduler.setEnabled(false);
        (cloud.auth as FakeGoogleAuth).current = null;
        await scheduler.setEnabled(true);
        expect(scheduler.enabled, false);
      },
    );
    test(
      'interval and offline backoff prevent repeated requests until due',
      () async {
        final v = await seed('Backoff');
        await scheduler.addVaults([v]);
        final before = server.requests;
        await scheduler.checkNow();
        expect(server.requests, before);
        clock = clock.add(const Duration(minutes: 5));
        server.offline = true;
        await scheduler.checkNow();
        expect(scheduler.jobs.single.state, VaultTransferState.failed);
        final failedRequests = server.requests;
        await scheduler.checkNow();
        expect(server.requests, failedRequests);
        expect(scheduler.nextCheck!.isAfter(clock), true);
      },
    );
    test(
      'pause during publication cancels later work and persists the paused schedule',
      () async {
        final v = await seed('Pause');
        await scheduler.addVaults([v]);
        final repo = await openExistingVault(v);
        await repo.save(repo.objects.single.copyWith(body: 'changed'));
        await repo.close();
        final entered = Completer<void>(), release = Completer<void>();
        server.beforeRecord = () async {
          entered.complete();
          await release.future;
        };
        final pass = scheduler.checkNow(force: true);
        await entered.future;
        await scheduler.setEnabled(false);
        release.complete();
        await pass;
        expect(scheduler.enabled, false);
        expect(jsonDecode(settings.value!)['enabled'], false);
        expect(scheduler.jobs.single.state, VaultTransferState.cancelled);
      },
    );
    test(
      'future configuration is preserved until an explicit Forget',
      () async {
        settings.value =
            '{"format":"orbit-drive-schedule","version":99,"future":true}';
        await scheduler.restore();
        final before = settings.value;
        await scheduler.setEnabled(false);
        await scheduler.setMinutes(1);
        expect(settings.value, before);
        expect(scheduler.configurationBlocked, true);
        await scheduler.forget();
        expect(settings.value, null);
      },
    );
    test(
      'supported unknown schedule fields survive pause and interval edits',
      () async {
        final vault = await seed('Metadata');
        settings.value = jsonEncode({
          'format': 'orbit-drive-schedule',
          'version': 1,
          'enabled': true,
          'subject': cloud.account!.subject,
          'minutes': 5,
          'futureRoot': {'keep': true},
          'vaults': [
            {
              'id': vault.id,
              'path': vault.path,
              'name': vault.name,
              'futureEntry': 42,
            },
          ],
        });
        await scheduler.restore();
        await scheduler.setEnabled(false);
        await scheduler.setMinutes(15);
        final saved = jsonDecode(settings.value!);
        expect(saved['futureRoot'], {'keep': true});
        expect(saved['vaults'][0]['futureEntry'], 42);
      },
    );
    test(
      'locked selected Vault does not prevent the next scheduled Vault check',
      () async {
        final a = await seed('Locked'), b = await seed('Available');
        await scheduler.addVaults([a, b]);
        final held = await openExistingVault(a);
        try {
          await scheduler.checkNow(force: true);
          expect(scheduler.jobs.first.state, VaultTransferState.failed);
          expect(scheduler.jobs.last.state, VaultTransferState.complete);
        } finally {
          await held.close();
        }
      },
    );
  });

  group('remembered self-hosted connections', () {
    late WorkspaceRepository repo;
    late WorkspaceController workspace;
    late PrivateMemory secret;
    late CollaborationController controller;
    final room = List.filled(43, 'r').join(),
        token = List.filled(43, 't').join();
    var deny = false, access = 'editor';
    final endpoint = Uri.parse('http://127.0.0.1:47831');
    CollaborationController make() => CollaborationController(
      workspace,
      MockClient(
        (r) async => deny
            ? http.Response('{}', 403)
            : http.Response(
                jsonEncode({
                  'protocol': 1,
                  'workspaceId': repo.workspaceId,
                  'role': access,
                  'sequence': 0,
                  'documents': {},
                  'peers': [],
                }),
                200,
              ),
      ),
      automaticPolling: false,
      secrets: (_) => secret,
    );
    setUp(() async {
      deny = false;
      access = 'editor';
      secret = PrivateMemory();
      repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      workspace = WorkspaceController()
        ..repository = repo
        ..hasWorkspace = true
        ..loading = false;
      controller = make();
    });
    tearDown(() async {
      controller.dispose();
      workspace.cancelAllTimers();
      await repo.close();
    });
    testWidgets(
      'saved connection controls wrap and unsupported profiles can be forgotten',
      (tester) async {
        tester.view.physicalSize = const Size(390, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          await controller.connect(endpoint, room, token);
          await controller.rememberConnection();
        });
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      showCollaborationSettings(context, controller),
                  child: const Text('Open shared settings'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open shared settings'));
        await tester.pumpAndSettle();
        expect(find.text('Reconnect saved server'), findsOneWidget);
        expect(find.text('Remember connection on this device'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        controller = make();
        secret.value = '{"format":"orbit-shared-connection","version":99}';
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => showCollaborationSettings(context, controller),
                child: const Text('Open shared settings'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open shared settings'));
        await tester.pumpAndSettle();
        expect(find.text('Forget saved connection'), findsOneWidget);
        await tester.ensureVisible(find.text('Forget saved connection'));
        await tester.tap(find.text('Forget saved connection'));
        await tester.pumpAndSettle();
        expect(secret.value, null);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
    test(
      'explicit save and restart reconnect use server permissions, not cached roles',
      () async {
        await controller.connect(endpoint, room, token);
        await controller.rememberConnection();
        expect(secret.value, contains('orbit-shared-connection'));
        expect(secret.value, isNot(contains('owner-key')));
        controller.dispose();
        controller = make();
        access = 'viewer';
        await controller.loadSavedConnection();
        expect(controller.hasSavedConnection, true);
        expect(controller.connected, false);
        await controller.reconnectSaved();
        expect(controller.viewer, true);
        controller.disconnect();
        expect(controller.hasSavedConnection, true);
        await controller.forgetSavedConnection();
        expect(secret.value, null);
      },
    );
    test(
      'revoked saved capability cannot reconnect or erase local files',
      () async {
        await repo.create(
          typeId: 'orbit.note',
          title: 'Local',
          body: 'preserve',
        );
        workspace.mergeRepositoryObjects();
        await controller.connect(endpoint, room, token);
        await controller.rememberConnection();
        controller.disconnect();
        deny = true;
        await expectLater(
          controller.reconnectSaved(),
          throwsA(isA<CollaborationAccessDenied>()),
        );
        expect(controller.connected, false);
        expect(controller.connecting, false);
        expect(repo.objects.single.body, 'preserve');
      },
    );
    test(
      'unknown saved formats cannot be overwritten and save failures release UI busy state',
      () async {
        await controller.connect(endpoint, room, token);
        secret.value =
            '{"format":"orbit-shared-connection","version":99,"opaque":true}';
        final before = secret.value;
        await expectLater(controller.rememberConnection(), throwsA(anything));
        expect(secret.value, before);
        await controller.forgetSavedConnection();
        secret.failWrite = true;
        await expectLater(controller.rememberConnection(), throwsA(anything));
        expect(controller.profileBusy, false);
        expect(secret.value, null);
      },
    );
    test(
      'connecting authority is visible before waiting for the server and clears on cancellation',
      () async {
        controller.dispose();
        final gate = Completer<http.Response>();
        controller = CollaborationController(
          workspace,
          MockClient((_) => gate.future),
          automaticPolling: false,
        );
        final pending = controller.connect(endpoint, room, token);
        expect(controller.connecting, true);
        controller.disconnect();
        gate.complete(
          http.Response(
            jsonEncode({
              'protocol': 1,
              'workspaceId': repo.workspaceId,
              'role': 'editor',
              'sequence': 0,
              'documents': {},
              'peers': [],
            }),
            200,
          ),
        );
        await expectLater(pending, throwsA(anything));
        expect(controller.connecting, false);
        expect(controller.connected, false);
      },
    );
  });

  test(
    'self-hosted readiness is non-disclosing, owner info is authenticated and storage failure becomes unready',
    () async {
      final overrides = HttpOverrides.current;
      HttpOverrides.global = null;
      final temp = await Directory.systemTemp.createTemp(
        'orbit-server-health-',
      );
      final server = CollaborationServer(temp, 'owner-key');
      final client = http.Client();
      final repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      final workspace = WorkspaceController()
        ..repository = repo
        ..hasWorkspace = true
        ..loading = false;
      final controller = CollaborationController(
        workspace,
        client,
        automaticPolling: false,
      );
      try {
        final port = await server.start(port: 0),
            endpoint = Uri.parse('http://127.0.0.1:$port');
        final health = await client.get(endpoint.resolve('/healthz'));
        expect(health.statusCode, 200);
        expect(health.body, isNot(contains('owner-key')));
        expect(
          (await client.get(endpoint.resolve('/v1/server'))).statusCode,
          403,
        );
        expect(
          (await controller.testServer(endpoint, 'owner-key'))['protocol'],
          1,
        );
        await Directory('${temp.path}/events.jsonl').create();
        await expectLater(
          controller.createRoom(endpoint, 'owner-key', 'Owner'),
          throwsA(anything),
        );
        expect(
          (await client.get(endpoint.resolve('/healthz'))).statusCode,
          503,
        );
        await expectLater(
          controller.testServer(endpoint, 'owner-key'),
          throwsA(anything),
        );
      } finally {
        controller.dispose();
        workspace.cancelAllTimers();
        await repo.close();
        await server.close();
        await temp.delete(recursive: true);
        HttpOverrides.global = overrides;
      }
    },
  );
}
