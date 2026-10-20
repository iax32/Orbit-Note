import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orbit_note/app/collaboration_controller.dart';
import 'package:orbit_note/app/google_cloud_controller.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/application/sync/google_account.dart';
import 'package:orbit_note/domain/collaboration.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/sync/google_drive_api.dart';
import 'package:orbit_note/features/workspace/google_drive_settings.dart';
import 'google_drive_account_test.dart' show FakeGoogleAuth;
import 'google_account_test.dart' show TestGoogleCredentials;
import 'support/memory_store.dart';

class FailingSignOut extends FakeGoogleAuth {
  @override
  Future<void> signOut() async => throw const GoogleCloudError(
    'offline',
    'Could not clear device credentials. Try signing out again.',
  );
}

class BackupFixture {
  BackupFixture(FakeGoogleAuth auth, this.source) {
    final bytes = utf8.encode(source);
    final workspaceId = jsonDecode(source)['workspaceId'] as String;
    final properties = {
      'orbitRole': 'backup',
      'orbitProtocol': '1',
      'orbitVaultId': workspaceId,
      'orbitSha256': sha256.convert(bytes).toString(),
    };
    backup = GoogleDriveBackup(
      'backup',
      'Verified backup',
      workspaceId,
      'subject-1',
      bytes.length,
      sha256.convert(bytes).toString(),
    );
    api = GoogleDriveApi(
      auth: auth,
      localMetadata: TestGoogleCredentials()
        ..value = '{"subject-1":{"id":"root","pending":false}}',
      wait: (duration) async {
        waits.add(duration);
        onWait?.call();
      },
      client: MockClient((r) async {
        if (r.url.path.endsWith('/root')) {
          return http.Response(
            '{"id":"root","ownedByMe":true,"mimeType":"application/vnd.google-apps.folder","appProperties":{"orbitRole":"root"}}',
            200,
          );
        }
        if (r.url.path.endsWith('/generateIds')) {
          return http.Response('{"ids":["backup"]}', 200);
        }
        if (r.method == 'POST') {
          uploads++;
          return http.Response(
            '{}',
            200,
            headers: {
              'location':
                  'https://www.googleapis.com/upload/drive/v3/files?upload_id=test',
            },
          );
        }
        if (r.method == 'PUT') {
          if (rejectedStatus != null && r.bodyBytes.isNotEmpty) {
            final status = rejectedStatus!;
            rejectedStatus = null;
            return http.Response(
              jsonEncode({
                'error': {
                  'errors': [
                    {'reason': reason},
                  ],
                },
              }),
              status,
            );
          }
          if (r.bodyBytes.isEmpty) {
            probes++;
            if (probeFailures-- > 0) return http.Response('{}', 503);
            return http.Response('', 308);
          }
          return http.Response('{"id":"backup"}', 200);
        }
        if (r.url.queryParameters['alt'] == 'media') {
          return http.Response(
            await (download?.future ?? Future.value(source)),
            200,
          );
        }
        if (r.url.path.endsWith('/backup')) {
          return http.Response(
            jsonEncode({
              'id': 'backup',
              'ownedByMe': true,
              'size': '${bytes.length}',
              'md5Checksum': md5.convert(bytes).toString(),
              'appProperties': properties,
            }),
            200,
          );
        }
        if (failList) throw http.ClientException('Listing unavailable');
        return http.Response('{"files":[]}', 200);
      }),
    );
  }
  final String source;
  late GoogleDriveApi api;
  late GoogleDriveBackup backup;
  int uploads = 0;
  int probes = 0;
  int probeFailures = 0;
  void Function()? onWait;
  int? rejectedStatus;
  String reason = '';
  final waits = <Duration>[];
  bool failList = false;
  Completer<String>? download;
}

void main() {
  late String source;
  setUpAll(() async {
    final repository = WorkspaceRepository(
      store: MemoryStore(),
      index: MemoryObjectIndex(),
    );
    await repository.initialize();
    await repository.create(
      typeId: 'orbit.note',
      title: 'Backup',
      body: 'Exact portable bytes 😀',
    );
    source = await repository.exportBundle();
    await repository.close();
  });
  for (final dispose in [false, true]) {
    test(
      'cancel${dispose ? '/dispose' : ''} during backup preparation sends no upload',
      () async {
        final auth = FakeGoogleAuth(),
            drive = BackupFixture(FakeGoogleAuth(), source);
        final c = GoogleCloudController(auth, drive.api);
        final prepared = Completer<String>();
        final operation = c.uploadBackup(() => prepared.future);
        if (dispose) {
          c.dispose();
        } else {
          c.cancelTransfer();
        }
        prepared.complete('prepared bytes');
        await operation;
        expect(drive.uploads, 0);
        expect(c.transferProgress, isNull);
        if (!dispose) c.dispose();
      },
    );
  }
  test(
    'verified upload remains successful when refreshing the list fails',
    () async {
      final auth = FakeGoogleAuth(),
          drive = BackupFixture(FakeGoogleAuth(), source)..failList = true;
      final c = GoogleCloudController(auth, drive.api);
      addTearDown(c.dispose);
      await c.uploadBackup(() async => source);
      expect(drive.uploads, 1);
      expect(c.backups.single.id, 'backup');
      expect(c.message, contains('uploaded and verified'));
      expect(c.message, contains('Refresh backups'));
      expect(c.reconnectRequired, isFalse);
    },
  );
  test('cancelled late download never returns a restore candidate', () async {
    final drive = BackupFixture(FakeGoogleAuth(), source)
      ..download = Completer<String>();
    final c = GoogleCloudController(FakeGoogleAuth(), drive.api);
    addTearDown(c.dispose);
    final operation = c.downloadBackup(drive.backup);
    expect(c.transferProgress, 0);
    c.cancelTransfer();
    drive.download!.complete(source);
    expect(await operation, isNull);
    expect(c.transferProgress, isNull);
  });
  test(
    'failed sign out retains the account and explains the failure',
    () async {
      final auth = FailingSignOut();
      final fixture = BackupFixture(auth, source);
      final c = GoogleCloudController(auth, fixture.api);
      addTearDown(c.dispose);
      c.backups = [fixture.backup];
      await c.signOut();
      expect(c.account?.subject, 'subject-1');
      expect(c.backups.single.id, 'backup');
      expect(c.message, contains('Try signing out again'));
      expect(c.busy, isFalse);
    },
  );

  for (final status in [429, 503]) {
    test(
      'Drive $status resumes the same upload after a bounded status probe',
      () async {
        final fixture = BackupFixture(FakeGoogleAuth(), source)
          ..rejectedStatus = status;
        final backup = await fixture.api.uploadBackup(source);
        expect(backup.checksum, sha256.convert(utf8.encode(source)).toString());
        expect(fixture.uploads, 1);
        expect(fixture.probes, 1);
        expect(fixture.waits, [const Duration(seconds: 1)]);
      },
    );
  }
  test(
    'Drive stops after three failed recovery probes in the same session',
    () async {
      final fixture = BackupFixture(FakeGoogleAuth(), source)
        ..rejectedStatus = 503
        ..probeFailures = 10;
      await expectLater(
        fixture.api.uploadBackup(source),
        throwsA(
          isA<GoogleCloudError>().having((e) => e.code, 'code', 'offline'),
        ),
      );
      expect(fixture.uploads, 1);
      expect(fixture.probes, 3);
      expect(fixture.waits, [
        const Duration(seconds: 1),
        const Duration(seconds: 2),
        const Duration(seconds: 4),
      ]);
    },
  );
  test('cancelling during recovery wait prevents any status probe', () async {
    var cancelled = false;
    final fixture = BackupFixture(FakeGoogleAuth(), source)
      ..rejectedStatus = 503
      ..onWait = () => cancelled = true;
    await expectLater(
      fixture.api.uploadBackup(source, isCancelled: () => cancelled),
      throwsA(
        isA<GoogleCloudError>().having((e) => e.code, 'code', 'cancelled'),
      ),
    );
    expect(fixture.uploads, 1);
    expect(fixture.probes, 0);
  });
  test(
    'Drive transfer refreshes expired access once without another upload session',
    () async {
      final auth = FakeGoogleAuth();
      final fixture = BackupFixture(auth, source)..rejectedStatus = 401;
      await fixture.api.uploadBackup(source);
      expect(auth.refreshes, 1);
      expect(fixture.uploads, 1);
      expect(fixture.probes, 0);
    },
  );
  for (final reason in [
    'storageQuotaExceeded',
    'userRateLimitExceeded',
    'accessNotConfigured',
  ]) {
    test('Drive transfer distinguishes $reason from revoked access', () async {
      final fixture = BackupFixture(FakeGoogleAuth(), source)
        ..rejectedStatus = 403
        ..reason = reason;
      final c = GoogleCloudController(FakeGoogleAuth(), fixture.api);
      addTearDown(c.dispose);
      if (reason == 'userRateLimitExceeded') {
        await c.uploadBackup(() async => source);
        expect(c.backups, isNotEmpty);
        expect(fixture.probes, 1);
      } else {
        await c.uploadBackup(() async => source);
        expect(
          c.message,
          contains(
            reason == 'storageQuotaExceeded'
                ? 'storage is full'
                : 'API is disabled',
          ),
        );
      }
      expect(c.reconnectRequired, isFalse);
    });
  }

  testWidgets(
    'backup browser filters current Vault, names and account ownership',
    (tester) async {
      final auth = FakeGoogleAuth();
      final fixture = BackupFixture(auth, source);
      final cloud = GoogleCloudController(auth, fixture.api);
      final repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      final workspace = WorkspaceController()..repository = repo;
      cloud.backups = [
        GoogleDriveBackup(
          'a',
          'Course backup',
          repo.workspaceId,
          'subject-1',
          100,
          'hash',
        ),
        const GoogleDriveBackup(
          'b',
          'Game backup',
          'another-vault',
          'subject-1',
          200,
          'hash',
        ),
        GoogleDriveBackup(
          'c',
          'Private other account',
          repo.workspaceId,
          'other-subject',
          100,
          'hash',
        ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [googleCloudProvider.overrideWithValue(cloud)],
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
      expect(find.text('Course backup'), findsOneWidget);
      expect(find.text('Game backup'), findsNothing);
      expect(find.text('Private other account'), findsNothing);
      await tester.ensureVisible(find.text('All Vaults'));
      await tester.tap(find.text('All Vaults'));
      await tester.pumpAndSettle();
      expect(find.text('Game backup'), findsOneWidget);
      final search = find.byKey(const ValueKey('drive-backup-search'));
      await tester.ensureVisible(search);
      await tester.enterText(search, ' GAME ');
      await tester.pumpAndSettle();
      expect(find.text('Game backup'), findsOneWidget);
      expect(find.text('Course backup'), findsNothing);
      expect(find.text('Private other account'), findsNothing);
      await tester.enterText(search, 'absent');
      await tester.pumpAndSettle();
      expect(find.textContaining('No matching backups'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      cloud.dispose();
      await repo.close();
    },
  );
  for (final changedAccount in [false, true]) {
    testWidgets(
      'backup consent expires when ${changedAccount ? 'account' : 'Vault'} changes',
      (tester) async {
        final auth = FakeGoogleAuth();
        final fixture = BackupFixture(auth, source);
        final cloud = GoogleCloudController(auth, fixture.api);
        final repo = WorkspaceRepository(
          store: MemoryStore(),
          index: MemoryObjectIndex(),
        );
        await repo.initialize();
        final workspace = WorkspaceController()..repository = repo;
        Widget settings(WorkspaceController current) => ProviderScope(
          overrides: [googleCloudProvider.overrideWithValue(cloud)],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: GoogleDriveSettings(workspace: current),
              ),
            ),
          ),
        );
        await tester.pumpWidget(settings(workspace));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Back up this Vault'));
        await tester.tap(find.text('Back up this Vault'));
        await tester.pumpAndSettle();
        if (changedAccount) {
          auth.current = const GoogleAccount(
            subject: 'other-subject',
            name: 'Other',
            email: 'other@example.test',
          );
        } else {
          // A settings route can survive replacement of its owning workspace.
          await tester.pumpWidget(
            settings(WorkspaceController()..repository = repo),
          );
        }
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(fixture.uploads, 0);
        expect(find.textContaining('Start the backup again'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        cloud.dispose();
        await repo.close();
      },
    );
  }

  group('shared session recovery', () {
    late MemoryStore store;
    late WorkspaceRepository repo;
    late ProviderContainer container;
    late WorkspaceController workspace;
    late Map<String, dynamic> state;
    late String noteId;
    late DateTime now;
    final endpoint = Uri.parse('https://shared.example.test');
    final room = 'a' * 43, token = 'b' * 43;
    setUp(() async {
      store = MemoryStore();
      repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
      container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      workspace = container.read(workspaceProvider.notifier);
      await workspace.initialize();
      final note = (await workspace.create(
        'orbit.note',
        title: 'Shared',
        body: 'hello',
      ))!;
      noteId = note.id;
      state = {
        'protocol': 1,
        'workspaceId': repo.workspaceId,
        'role': 'editor',
        'sequence': 1,
        'documents': {
          note.id: {'version': 1, 'snapshot': collaborationSnapshot(note)},
        },
        'peers': [],
      };
      now = DateTime.utc(2026, 10, 15);
    });
    tearDown(() async {
      store.failWrites = false;
      await workspace.flushAll();
      container.dispose();
      await repo.close();
    });
    CollaborationController client(
      Future<http.Response> Function(http.Request) handler,
    ) {
      final c = CollaborationController(
        workspace,
        MockClient(handler),
        now: () => now,
        automaticPolling: false,
      );
      addTearDown(c.dispose);
      return c;
    }

    http.Response jsonState() => http.Response(jsonEncode(state), 200);

    test(
      'transient failure backs off, retries, and clears the interrupted state',
      () async {
        var calls = 0, offline = false;
        final c = client((_) async {
          calls++;
          if (offline) throw http.ClientException('offline');
          return jsonState();
        });
        await c.connect(endpoint, room, token);
        offline = true;
        await c.pump();
        expect(c.retryAt, now.add(const Duration(seconds: 1)));
        final prior = calls;
        await c.pump();
        expect(calls, prior);
        now = now.add(const Duration(seconds: 1));
        await c.pump();
        expect(c.retryAt, now.add(const Duration(seconds: 2)));
        offline = false;
        await c.retryNow();
        expect(c.retryAt, isNull);
        expect(c.status, contains('acknowledged'));
      },
    );
    test(
      'revoked access pauses automatic requests and explicit retry can recover',
      () async {
        var denied = false, calls = 0;
        final c = client((_) async {
          calls++;
          return denied
              ? http.Response('<html>Denied</html>', 403)
              : jsonState();
        });
        await c.connect(endpoint, room, token);
        denied = true;
        await c.pump();
        expect(c.accessBlocked, isTrue);
        final before = calls;
        now = now.add(const Duration(minutes: 10));
        await c.pump();
        expect(calls, before);
        denied = false;
        await c.retryNow();
        expect(c.accessBlocked, isFalse);
        expect(c.connected, isTrue);
      },
    );
    test(
      'disconnect invalidates a connection response still in flight',
      () async {
        final response = Completer<http.Response>(),
            entered = Completer<void>();
        final c = client((_) {
          entered.complete();
          return response.future;
        });
        final operation = c.connect(endpoint, room, token);
        final checked = expectLater(operation, throwsStateError);
        await entered.future;
        c.disconnect();
        response.complete(jsonState());
        await checked;
        expect(c.connected, isFalse);
      },
    );
    test('a later connection wins over an earlier delayed reply', () async {
      final old = Completer<http.Response>(), entered = Completer<void>();
      var calls = 0;
      final c = client((_) {
        calls++;
        if (calls == 1) {
          entered.complete();
          return old.future;
        }
        return Future.value(jsonState());
      });
      final early = c.connect(endpoint, room, token);
      final checked = expectLater(early, throwsStateError);
      await entered.future;
      await c.connect(endpoint, 'c' * 43, 'd' * 43);
      old.complete(jsonState());
      await checked;
      expect(c.room, 'c' * 43);
    });
    test('unsupported permissions never replace a valid session', () async {
      final c = client((_) async => jsonState());
      await c.connect(endpoint, room, token);
      state['role'] = 'future-owner';
      await expectLater(
        c.connect(endpoint, 'c' * 43, 'd' * 43),
        throwsStateError,
      );
      expect(c.room, room);
      expect(c.role, 'editor');
    });
    test(
      'failed local save stays pending and is never reported acknowledged',
      () async {
        final c = client((r) async {
          expect(r.method, 'GET');
          return jsonState();
        });
        await c.connect(endpoint, room, token);
        workspace.edit(noteId, body: 'hello changed');
        store.failWrites = true;
        await c.pump();
        expect(c.pendingChanges, 1);
        expect(c.status, contains('pending'));
        expect(workspace.find(noteId)!.body, 'hello changed');
      },
    );
    test(
      'lost upload acknowledgement retries the same proposal and retains later local edits',
      () async {
        String? operationId;
        var lost = true, posts = 0;
        final c = client((r) async {
          if (r.method == 'POST') {
            posts++;
            final operation = jsonDecode(r.body) as Map;
            operationId ??= operation['operation'] as String;
            if (posts <= 2) {
              expect(operation['operation'], operationId);
            } else {
              expect(operation['operation'], isNot(operationId));
            }
            state['documents'] = {
              noteId: {
                'version': posts > 2 ? 3 : 2,
                'snapshot': operation['snapshot'],
              },
            };
            state['sequence'] = 2;
            if (lost) {
              lost = false;
              throw http.ClientException('ack lost');
            }
            return http.Response(
              jsonEncode((state['documents'] as Map)[noteId]),
              200,
            );
          }
          return jsonState();
        });
        await c.connect(endpoint, room, token);
        workspace.edit(noteId, body: 'hello!');
        await c.pump();
        expect(c.pendingChanges, 1);
        workspace.edit(noteId, body: 'hello! More');
        await c.retryNow();
        expect(workspace.find(noteId)!.body, 'hello! More');
        expect(c.pendingChanges, 1);
        await c.pump();
        expect(c.pendingChanges, 0);
      },
    );
  });
}
