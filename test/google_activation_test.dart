import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orbit_note/application/sync/google_account.dart';
import 'package:orbit_note/application/sync/google_desktop_configuration.dart';
import 'package:orbit_note/app/google_cloud_controller.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/features/workspace/google_drive_settings.dart';
import 'package:orbit_note/infrastructure/sync/google_desktop_auth.dart';
import 'package:orbit_note/infrastructure/sync/google_drive_api.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'google_account_test.dart'
    show TestGoogleCredentials, TestGoogleReceiver;
import 'google_drive_account_test.dart' show FakeGoogleAuth;
import 'support/memory_store.dart';

const testClientId = '123456-desktop.apps.googleusercontent.com';
String download({String id = testClientId}) => jsonEncode({
  'installed': {
    'client_id': id,
    'client_secret': 'test-desktop-value',
    'auth_uri': 'https://accounts.google.com/o/oauth2/auth',
    'token_uri': 'https://oauth2.googleapis.com/token',
  },
});

class _ConfigurationStore extends TestGoogleCredentials {
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<void> write(String value) async {
    await gate?.future;
    if (fail) throw StateError('secret-internal-error');
    await super.write(value);
  }
}

void main() {
  for (final failRoot in [false, true]) {
    test(
      'first sign-in prepares only an empty Drive folder; root failure retains account ($failRoot)',
      () async {
        final account = FakeGoogleAuth()..current = null;
        final metadata = TestGoogleCredentials();
        var created = 0;
        final client = MockClient((request) async {
          expect(request.url.path, isNot(contains('/upload/')));
          if (request.url.path.endsWith('/generateIds')) {
            return http.Response('{"ids":["root-test"]}', 200);
          }
          if (request.method == 'POST') {
            expect(request.url.path, '/drive/v3/files');
            final body = jsonDecode(request.body) as Map;
            expect(body['mimeType'], GoogleDriveApi.folderMime);
            expect(body['appProperties']['orbitRole'], 'root');
            created++;
            return failRoot
                ? http.Response('{}', 503)
                : http.Response('{"id":"root-test"}', 200);
          }
          if (request.url.path.endsWith('/about')) {
            return http.Response('{"storageQuota":{"usage":"0"}}', 200);
          }
          if (request.url.path.endsWith('/root-test')) {
            return http.Response(
              '{"id":"root-test","ownedByMe":true,"mimeType":"application/vnd.google-apps.folder","appProperties":{"orbitRole":"root"}}',
              200,
            );
          }
          return http.Response('{"files":[]}', 200);
        });
        final cloud = GoogleCloudController(
          account,
          GoogleDriveApi(
            auth: account,
            client: client,
            localMetadata: metadata,
          ),
        );
        await cloud.connect();
        expect(cloud.account, isNotNull);
        expect(created, 1);
        if (failRoot) {
          expect(cloud.rootId, isNull);
          expect(cloud.message, isNot(contains('Drive is ready')));
        } else {
          expect(cloud.rootId, 'root-test');
          expect(cloud.message, contains('Drive is ready'));
          await cloud.connect();
          expect(created, 1);
        }
        cloud.dispose();
      },
    );
  }
  test('downloaded desktop JSON and stored configuration round-trip', () {
    final config = GoogleDesktopConfiguration.fromDownload(
      '\uFEFF${download()}',
    );
    expect(config.clientId, testClientId);
    expect(
      GoogleDesktopConfiguration.fromStored(config.encode()).clientId,
      testClientId,
    );
  });
  for (final bad in [
    '{"web":{"client_id":"$testClientId"}}',
    '{"installed":{"client_id":"password","client_secret":"secret"}}',
    '{"installed":{"client_id":"$testClientId","token_uri":"https://other.example/token"}}',
    '{"version":2}',
    'broken JSON',
    'x' * 65537,
  ]) {
    test(
      'invalid client download is rejected without echoing its contents ${bad.length}',
      () {
        expect(
          () => GoogleDesktopConfiguration.fromDownload(bad),
          throwsA(
            isA<GoogleCloudError>().having(
              (e) => e.toString().contains('secret'),
              'leaks secret',
              isFalse,
            ),
          ),
        );
      },
    );
  }
  test('future stored configuration is rejected', () {
    expect(
      () => GoogleDesktopConfiguration.fromStored(
        '{"version":2,"clientId":"$testClientId","clientSecret":"secret"}',
      ),
      throwsA(isA<GoogleCloudError>()),
    );
  });
  late _ConfigurationStore config;
  late TestGoogleCredentials credentials;
  GoogleDesktopAuth auth({
    String id = '',
    http.Client? client,
    TestGoogleReceiver? receiver,
  }) => GoogleDesktopAuth(
    clientId: id,
    configurationStore: config,
    credentials: credentials,
    client: client ?? MockClient((_) async => http.Response('{}', 500)),
    receive: () async => receiver ?? TestGoogleReceiver(),
    openBrowser: (uri) async {
      receiver?.result.complete(
        receiver.redirect.replace(
          queryParameters: {
            'state': uri.queryParameters['state']!,
            'code': 'test-code',
          },
        ),
      );
      return true;
    },
  );
  setUp(() {
    config = _ConfigurationStore();
    credentials = TestGoogleCredentials();
  });
  test(
    'activate once and restore the app registration after restart without opening a browser',
    () async {
      final first = auth();
      expect(first.configured, isFalse);
      await first.configureDesktop(download());
      expect(first.configured, isTrue);
      expect(first.canConfigureDesktop, isFalse);
      final reopened = auth();
      expect(await reopened.restore(), isNull);
      expect(reopened.configured, isTrue);
      expect(reopened.clientId, testClientId);
      expect(credentials.value, isNull);
    },
  );
  test(
    'configured releases cannot be overridden by imported registration',
    () async {
      final first = auth(id: testClientId);
      await expectLater(
        first.configureDesktop(
          download(id: '123-other.apps.googleusercontent.com'),
        ),
        throwsA(isA<GoogleCloudError>()),
      );
      expect(first.clientId, testClientId);
      expect(config.value, isNull);
    },
  );
  test(
    'failed secure storage never activates an unsaved registration',
    () async {
      config.fail = true;
      final first = auth();
      await expectLater(first.configureDesktop(download()), throwsStateError);
      expect(first.configured, isFalse);
      expect(first.canConfigureDesktop, isTrue);
    },
  );
  test(
    'parallel activation cannot replace a client while its write is pending',
    () async {
      config.gate = Completer<void>();
      final first = auth();
      final pending = first.configureDesktop(download());
      await expectLater(
        first.configureDesktop(
          download(id: '123-other.apps.googleusercontent.com'),
        ),
        throwsA(isA<GoogleCloudError>()),
      );
      config.gate!.complete();
      await pending;
      expect(first.clientId, testClientId);
    },
  );
  test(
    'Google rejects a client with a setup error rather than a reconnect loop',
    () async {
      final receiver = TestGoogleReceiver();
      final first = auth(
        id: testClientId,
        receiver: receiver,
        client: MockClient(
          (_) async => http.Response(
            '{"error":"invalid_client","error_description":"secret response"}',
            401,
          ),
        ),
      );
      await expectLater(
        first.signIn(),
        throwsA(
          isA<GoogleCloudError>()
              .having((e) => e.code, 'code', 'configuration')
              .having((e) => e.message.contains('secret'), 'leak', isFalse),
        ),
      );
      expect(receiver.closed, isTrue);
    },
  );
  test(
    'disabled Drive API leaves the account connected and explains the real cause',
    () async {
      final account = FakeGoogleAuth();
      final client = MockClient(
        (_) async => http.Response(
          '{"error":{"errors":[{"reason":"accessNotConfigured"}],"message":"secret response"}}',
          403,
        ),
      );
      final cloud = GoogleCloudController(
        account,
        GoogleDriveApi(
          auth: account,
          client: client,
          localMetadata: credentials,
        ),
      );
      await cloud.restore();
      expect(cloud.account, isNotNull);
      expect(cloud.reconnectRequired, isFalse);
      expect(cloud.message, contains('Drive API is disabled'));
      expect(cloud.message, isNot(contains('secret')));
      cloud.dispose();
    },
  );
  testWidgets(
    'unconfigured sign-in button opens actionable setup rather than staying disabled',
    (tester) async {
      final desktop = auth();
      final cloud = GoogleCloudController(
        desktop,
        GoogleDriveApi(
          auth: desktop,
          client: MockClient((_) async => http.Response('{}', 500)),
          localMetadata: credentials,
        ),
      );
      final repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      final workspace = WorkspaceController()..repository = repo;
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
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.text('Activate Google sign-in'), findsOneWidget);
      expect(find.text('Import desktop client…'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      cloud.dispose();
      await repo.close();
    },
  );
}
