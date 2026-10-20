import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orbit_note/app/google_cloud_controller.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/sync/google_account.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/features/workspace/google_drive_settings.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/sync/google_drive_api.dart';
import 'google_account_test.dart' show TestGoogleCredentials;
import 'support/memory_store.dart';

class FakeGoogleAuth implements GoogleAccountAuth {
  GoogleAccount? current = const GoogleAccount(
    subject: 'subject-1',
    name: 'Student',
    email: 'student@example.test',
  );
  int refreshes = 0;
  String token = 'test-access';
  @override
  bool get configured => true;
  @override
  GoogleAccount? get account => current;
  @override
  Future<GoogleAccount?> restore() async => current;
  @override
  Future<GoogleAccount> signIn({String? expectedSubject}) async =>
      current = const GoogleAccount(
        subject: 'subject-1',
        name: 'Student',
        email: 'student@example.test',
      );
  @override
  Future<String> accessToken({bool refresh = false}) async {
    if (refresh) refreshes++;
    return token;
  }

  @override
  Future<void> signOut() async => current = null;
  @override
  void cancel() {}
}

void main() {
  late FakeGoogleAuth auth;
  late TestGoogleCredentials storage;
  setUp(() {
    auth = FakeGoogleAuth();
    storage = TestGoogleCredentials();
  });
  GoogleDriveApi api(Future<http.Response> Function(http.Request) handler) =>
      GoogleDriveApi(
        auth: auth,
        client: MockClient(handler),
        localMetadata: storage,
      );
  test(
    'About fields are narrow, 401 refreshes once, quota values remain real',
    () async {
      var requests = 0;
      final drive = api((r) async {
        expect(r.url.path, '/drive/v3/about');
        expect(r.url.queryParameters['fields'], contains('storageQuota'));
        expect(r.url.queryParameters['fields'], isNot(contains('*')));
        if (requests++ == 0) return http.Response('{}', 401);
        return http.Response(
          '{"storageQuota":{"limit":"100","usage":"60","usageInDrive":"10"}}',
          200,
        );
      });
      expect((await drive.quota()).remaining, BigInt.from(40));
      expect(auth.refreshes, 1);
    },
  );
  test('root uses stored Drive ID even after rename', () async {
    storage.value = '{"subject-1":{"id":"root-id","pending":false}}';
    final drive = api((r) async {
      expect(r.method, 'GET');
      expect(r.url.path, '/drive/v3/files/root-id');
      return http.Response(
        '{"id":"root-id","name":"My Notes","ownedByMe":true,"mimeType":"application/vnd.google-apps.folder","appProperties":{"orbitRole":"root"}}',
        200,
      );
    });
    expect(await drive.ensureRoot(), 'root-id');
  });
  test(
    'each account creates its own root with its own authorization',
    () async {
      final roots = <String, String>{};
      final drive = api((r) async {
        final subject = auth.current!.subject;
        expect(r.headers['Authorization'], 'Bearer token-$subject');
        if (r.url.path.endsWith('/generateIds')) {
          return http.Response(
            jsonEncode({
              'ids': ['root-$subject'],
            }),
            200,
          );
        }
        if (r.method == 'POST') {
          final body = jsonDecode(r.body) as Map;
          expect(body['id'], 'root-$subject');
          // No shared parent or developer Drive is supplied: Google creates the
          // folder in the authorized user's My Drive.
          expect(body.containsKey('parents'), isFalse);
          expect(body.containsKey('owners'), isFalse);
          roots[subject] = body['id'] as String;
          return http.Response(jsonEncode({'id': body['id']}), 200);
        }
        if (r.url.path == '/drive/v3/files') {
          expect(r.url.queryParameters['q'], contains("'me' in owners"));
          return http.Response('{"files":[]}', 200);
        }
        expect(r.url.path, '/drive/v3/files/root-$subject');
        return http.Response(
          jsonEncode({
            'id': roots[subject],
            'ownedByMe': true,
            'mimeType': GoogleDriveApi.folderMime,
            'appProperties': {'orbitRole': 'root'},
          }),
          200,
        );
      });
      for (final subject in ['alice', 'bob', 'alice']) {
        auth.current = GoogleAccount(subject: subject);
        auth.token = 'token-$subject';
        expect(await drive.ensureRoot(), 'root-$subject');
      }
      expect(roots, {'alice': 'root-alice', 'bob': 'root-bob'});
      final saved = jsonDecode(storage.value!) as Map;
      expect(saved['alice']['id'], 'root-alice');
      expect(saved['bob']['id'], 'root-bob');
    },
  );
  test(
    'a root transferred to another owner is rejected without writes',
    () async {
      storage.value = '{"subject-1":{"id":"shared-root","pending":false}}';
      final original = storage.value;
      final drive = api((r) async {
        expect(r.method, 'GET');
        expect(r.url.path, '/drive/v3/files/shared-root');
        return http.Response(
          jsonEncode({
            'id': 'shared-root',
            'ownedByMe': false,
            'mimeType': GoogleDriveApi.folderMime,
            'appProperties': {'orbitRole': 'root'},
          }),
          200,
        );
      });
      await expectLater(
        drive.ensureRoot(),
        throwsA(isA<GoogleCloudError>().having((e) => e.code, 'code', 'root')),
      );
      expect(storage.value, original);
    },
  );
  test(
    'root create records generated ID first and resumes lost acknowledgement',
    () async {
      var created = false, creates = 0;
      final drive = api((r) async {
        if (r.url.path.endsWith('/generateIds')) {
          return http.Response('{"ids":["generated"]}', 200);
        }
        if (r.method == 'POST') {
          creates++;
          expect(storage.value, contains('generated'));
          created = true;
          throw Exception('response lost');
        }
        if (r.url.path.endsWith('/generated') && created) {
          return http.Response(
            '{"id":"generated","ownedByMe":true,"mimeType":"application/vnd.google-apps.folder","appProperties":{"orbitRole":"root"}}',
            200,
          );
        }
        return http.Response('{"files":[]}', 200);
      });
      await expectLater(drive.ensureRoot(), throwsA(isA<GoogleCloudError>()));
      expect(await drive.ensureRoot(), 'generated');
      expect(creates, 1);
    },
  );
  test(
    'same name different UUIDs remain separate and discovery paginates',
    () async {
      final drive = api((r) async {
        expect(r.url.queryParameters['q'], contains('orbitRole'));
        expect(r.url.queryParameters['q'], contains("'me' in owners"));
        final second = r.url.queryParameters.containsKey('pageToken');
        return http.Response(
          jsonEncode({
            if (!second) 'nextPageToken': 'next',
            'files': [
              {
                'id': second ? 'drive-b' : 'drive-a',
                'name': 'Study',
                'appProperties': {
                  'orbitRole': 'vault',
                  'orbitProtocol': '1',
                  'orbitVaultId': second ? 'uuid-b' : 'uuid-a',
                },
              },
            ],
          }),
          200,
        );
      });
      final vaults = await drive.listVaults();
      expect(vaults.map((v) => v.workspaceId), ['uuid-a', 'uuid-b']);
    },
  );
  test(
    'account changes discard response instead of displaying another account quota',
    () async {
      final drive = api((r) async {
        auth.current = const GoogleAccount(subject: 'other');
        return http.Response('{"storageQuota":{"limit":"100"}}', 200);
      });
      await expectLater(
        drive.quota(),
        throwsA(
          isA<GoogleCloudError>().having((e) => e.code, 'code', 'account'),
        ),
      );
    },
  );
  test('Google unavailable cannot prevent a durable local Note save', () async {
    final drive = api((r) async => http.Response('{}', 503));
    final cloud = GoogleCloudController(auth, drive);
    await cloud.restore();
    final store = MemoryStore();
    final repository = WorkspaceRepository(
      store: store,
      index: MemoryObjectIndex(),
    );
    await repository.initialize();
    final note = await repository.create(
      typeId: 'orbit.note',
      title: 'Offline study',
      body: 'Saved without Google.',
    );
    await repository.close();
    final reopened = WorkspaceRepository(
      store: store,
      index: MemoryObjectIndex(),
    );
    await reopened.initialize();
    expect(
      reopened.objects.singleWhere((o) => o.id == note.id).body,
      'Saved without Google.',
    );
    await reopened.close();
    cloud.dispose();
  });
  test('profile remains connected when quota service is unavailable', () async {
    final drive = api(
      (r) async => r.url.path.endsWith('/about')
          ? http.Response('{}', 503)
          : http.Response('{"files":[]}', 200),
    );
    final c = GoogleCloudController(auth, drive);
    await c.restore();
    expect(c.account?.subject, 'subject-1');
    expect(c.quota, isNull);
    expect(c.message, contains('unavailable'));
    c.dispose();
  });
  testWidgets(
    'Google account card, unknown limit, avatar fallback and sign out',
    (tester) async {
      final drive = api(
        (r) async => http.Response(
          r.url.path.endsWith('/about')
              ? '{"storageQuota":{"usage":"6000"}}'
              : '{"files":[]}',
          200,
        ),
      );
      final cloud = GoogleCloudController(auth, drive);
      await cloud.restore();
      final repository = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      await repository.initialize();
      final workspace = WorkspaceController()..repository = repository;
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
      expect(find.text('student@example.test'), findsOneWidget);
      expect(find.textContaining('No storage limit reported'), findsOneWidget);
      expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
      expect(find.text('Local-first'), findsOneWidget);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(cloud.account, isNotNull);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(cloud.account, isNull);
      expect(find.text('Continue with Google'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      cloud.dispose();
    },
  );
}
