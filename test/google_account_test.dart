import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orbit_note/application/sync/google_account.dart';
import 'package:orbit_note/infrastructure/sync/google_desktop_auth.dart';

class TestGoogleCredentials implements GoogleCredentialStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
  @override
  Future<void> delete() async => value = null;
}

class TestGoogleReceiver implements GoogleAuthorizationReceiver {
  final result = Completer<Uri>();
  bool closed = false;
  @override
  Uri get redirect => Uri.parse('http://127.0.0.1:32109/oauth/callback');
  @override
  Future<Uri> get callback => result.future;
  @override
  Future<void> close() async {
    closed = true;
  }
}

class _GatedCredentials extends TestGoogleCredentials {
  final started = Completer<void>(), release = Completer<void>();
  @override
  Future<void> write(String value) async {
    started.complete();
    await release.future;
    await super.write(value);
  }
}

void main() {
  late TestGoogleCredentials store;
  late TestGoogleReceiver receiver;
  late GoogleDesktopAuth auth;
  late Uri authorization;
  late DateTime now;
  var tokenCalls = 0;
  Map<String, String>? lastExchange;
  String? badState, oauthError;
  var noCallback = false, revoked = false, badToken = false;
  setUp(() {
    store = TestGoogleCredentials();
    receiver = TestGoogleReceiver();
    now = DateTime.utc(2026, 9, 13);
    tokenCalls = 0;
    badState = oauthError = null;
    noCallback = revoked = badToken = false;
    final client = MockClient((request) async {
      if (request.url.host == 'openidconnect.googleapis.com') {
        return http.Response(
          jsonEncode({
            'sub': 'stable-sub',
            'email': 'student@example.test',
            'name': 'Student',
          }),
          200,
        );
      }
      tokenCalls++;
      lastExchange = request.bodyFields;
      if (revoked) return http.Response('{"error":"invalid_grant"}', 400);
      return http.Response(
        jsonEncode({
          'access_token': 'test-access',
          'token_type': 'Bearer',
          'expires_in': badToken ? -1 : 3600,
          'scope': googleScopes.join(' '),
          if (request.bodyFields['grant_type'] == 'authorization_code')
            'refresh_token': 'test-refresh',
        }),
        200,
      );
    });
    auth = GoogleDesktopAuth(
      clientId: 'desktop-id',
      credentials: store,
      client: client,
      now: () => now,
      receive: () async => receiver,
      timeout: const Duration(milliseconds: 50),
      openBrowser: (uri) async {
        authorization = uri;
        if (!noCallback) {
          receiver.result.complete(
            receiver.redirect.replace(
              queryParameters: {
                'state': badState ?? uri.queryParameters['state']!,
                if (oauthError == null)
                  'code': 'test-code'
                else
                  'error': oauthError!,
              },
            ),
          );
        }
        return true;
      },
    );
  });
  test(
    'desktop PKCE, scopes and verified subject; secure restore without browser',
    () async {
      expect((await auth.signIn()).subject, 'stable-sub');
      expect(authorization.queryParameters['scope']!.split(' '), googleScopes);
      expect(
        authorization.queryParameters['scope'],
        isNot(contains('auth/drive ')),
      );
      expect(
        authorization.queryParameters['redirect_uri'],
        receiver.redirect.toString(),
      );
      final verifier = lastExchange!['code_verifier']!;
      expect(verifier.length, greaterThanOrEqualTo(43));
      expect(
        authorization.queryParameters['code_challenge'],
        base64UrlEncode(
          sha256.convert(ascii.encode(verifier)).bytes,
        ).replaceAll('=', ''),
      );
      expect(receiver.closed, isTrue);
      expect(store.value, contains('test-refresh'));
      final restored = GoogleDesktopAuth(
        clientId: 'desktop-id',
        credentials: store,
        client: auth.client,
        now: () => now,
        receive: () async => throw StateError('No browser on restore'),
        openBrowser: (_) async => false,
      );
      expect((await restored.restore())!.subject, 'stable-sub');
      expect(tokenCalls, 1);
      expect(await restored.accessToken(), 'test-access');
    },
  );
  test(
    'state mismatch rejects before token exchange and closes listener',
    () async {
      badState = 'wrong';
      await expectLater(
        auth.signIn(),
        throwsA(isA<GoogleCloudError>().having((e) => e.code, 'code', 'state')),
      );
      expect(tokenCalls, 0);
      expect(store.value, isNull);
      expect(receiver.closed, isTrue);
    },
  );
  test('wrong account reconnect never replaces secure credentials', () async {
    await expectLater(
      auth.signIn(expectedSubject: 'different-sub'),
      throwsA(
        isA<GoogleCloudError>().having(
          (e) => e.code,
          'code',
          'accountMismatch',
        ),
      ),
    );
    expect(store.value, isNull);
    expect(auth.account, isNull);
  });
  test(
    'sign out cannot be undone by an in-flight secure credential write',
    () async {
      final gated = _GatedCredentials();
      final racing = GoogleDesktopAuth(
        clientId: auth.clientId,
        credentials: gated,
        client: auth.client,
        now: () => now,
        receive: () async => receiver,
        openBrowser: auth.openBrowser,
      );
      final signIn = racing.signIn();
      final assertion = expectLater(signIn, throwsA(isA<GoogleCloudError>()));
      await gated.started.future;
      final signOut = racing.signOut();
      gated.release.complete();
      await assertion;
      await signOut;
      expect(gated.value, isNull);
      expect(racing.account, isNull);
    },
  );
  test('user denial preserves local credentials', () async {
    oauthError = 'access_denied';
    await expectLater(auth.signIn(), throwsA(isA<GoogleCloudError>()));
    expect(tokenCalls, 0);
    expect(receiver.closed, isTrue);
  });
  test('callback timeout cleans listener', () async {
    noCallback = true;
    await expectLater(
      auth.signIn(),
      throwsA(isA<GoogleCloudError>().having((e) => e.code, 'code', 'timeout')),
    );
    expect(receiver.closed, isTrue);
    expect(store.value, isNull);
  });
  test('explicit cancellation cleans listener', () async {
    noCallback = true;
    final future = auth.signIn();
    await Future<void>.delayed(const Duration(milliseconds: 1));
    auth.cancel();
    await expectLater(future, throwsA(isA<GoogleCloudError>()));
    expect(receiver.closed, isTrue);
    expect(store.value, isNull);
  });
  test('expired access refreshes once and retains refresh token', () async {
    await auth.signIn();
    now = now.add(const Duration(hours: 2));
    await Future.wait([auth.accessToken(), auth.accessToken()]);
    expect(tokenCalls, 2);
    expect(lastExchange!['grant_type'], 'refresh_token');
    expect(store.value, contains('test-refresh'));
  });
  test(
    'revoked refresh retains account and marks reconnect without leaking response',
    () async {
      await auth.signIn();
      revoked = true;
      await expectLater(
        auth.accessToken(refresh: true),
        throwsA(
          isA<GoogleCloudError>().having((e) => e.code, 'code', 'reauth'),
        ),
      );
      expect(auth.account!.subject, 'stable-sub');
      expect(store.value, isNotNull);
    },
  );
  test('invalid token response never persists a session', () async {
    badToken = true;
    await expectLater(auth.signIn(), throwsA(isA<GoogleCloudError>()));
    expect(store.value, isNull);
  });
  test('sign out removes only installation credentials', () async {
    await auth.signIn();
    await auth.signOut();
    expect(store.value, isNull);
    expect(auth.account, isNull);
    expect(await auth.restore(), isNull);
  });
  test('quota uses total Google usage rather than Drive-only usage', () {
    final q = GoogleStorageQuota.fromJson({
      'storageQuota': {
        'limit': '100000',
        'usage': '60000',
        'usageInDrive': '20000',
        'usageInDriveTrash': '123',
      },
      'maxUploadSize': '200000',
    });
    expect(q.remaining, BigInt.from(40000));
    expect(q.fraction, .6);
    expect(q.trashUsage, BigInt.from(123));
    expect(
      () => q.checkUpload(BigInt.from(41000), BigInt.one),
      throwsA(isA<GoogleCloudError>()),
    );
  });
  test('unreported limit is unknown, malformed fields never become zero', () {
    final q = GoogleStorageQuota.fromJson({
      'storageQuota': {'usage': '9007199254740993', 'limit': 'NaN'},
    });
    expect(q.limit, isNull);
    expect(q.remaining, isNull);
    expect(q.fraction, isNull);
    expect(q.usage, BigInt.parse('9007199254740993'));
    expect(
      () => q.checkUpload(BigInt.from(999999), BigInt.one),
      returnsNormally,
    );
  });
  test('quota saturation and maxUploadSize fail preflight safely', () {
    final full = GoogleStorageQuota.fromJson({
      'storageQuota': {'limit': '100', 'usage': '101'},
    });
    expect(full.remaining, BigInt.zero);
    expect(full.nearlyFull, isTrue);
    final max = GoogleStorageQuota.fromJson({'maxUploadSize': '100'});
    expect(
      () => max.checkUpload(BigInt.from(200), BigInt.from(101)),
      throwsA(isA<GoogleCloudError>()),
    );
  });
}
