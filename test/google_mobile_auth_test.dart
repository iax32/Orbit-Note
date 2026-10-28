import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/sync/google_account.dart';
import 'package:orbit_note/application/sync/google_mobile_auth.dart';

class _Store implements GoogleCredentialStore {
  String? value;
  Completer<void>? writing;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String text) async {
    await writing?.future;
    value = text;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

class _User implements MobileGoogleUser {
  _User(this.subject);
  final String subject;
  bool deny = false;
  final requests = <bool>[];
  @override
  GoogleAccount get account =>
      GoogleAccount(subject: subject, email: '$subject@example.test');
  @override
  Future<String> authorize({
    required bool interactive,
    bool refresh = false,
  }) async {
    requests.add(interactive);
    if (deny) throw const GoogleCloudError('reauth', 'Consent required');
    return refresh ? 'refreshed-token' : 'access-token';
  }
}

class _Bridge implements MobileGoogleBridge {
  _User? user = _User('alice');
  bool failInitialization = false;
  int attempts = 0, signOuts = 0;
  Completer<void>? signingIn;
  @override
  Future<void> initialize() async {
    attempts++;
    if (failInitialization) {
      throw const GoogleCloudError('configuration', 'Missing registration');
    }
  }

  @override
  Future<MobileGoogleUser?> authenticate({required bool interactive}) async {
    await signingIn?.future;
    return user;
  }

  @override
  Future<void> signOut() async {
    signOuts++;
  }
}

void main() {
  late _Store store;
  late _Bridge bridge;
  late GoogleMobileAuth auth;
  setUp(() {
    store = _Store();
    bridge = _Bridge();
    auth = GoogleMobileAuth(
      configured: true,
      bridge: bridge,
      credentials: store,
    );
  });
  test(
    'identity is connected only after Drive authorization and persists no token',
    () async {
      bridge.user!.deny = true;
      await expectLater(auth.signIn(), throwsA(isA<GoogleCloudError>()));
      expect(auth.account, isNull);
      expect(store.value, isNull);
      bridge.user!.deny = false;
      expect((await auth.signIn()).subject, 'alice');
      expect(store.value, isNot(contains('token')));
      expect(await auth.accessToken(refresh: true), 'refreshed-token');
    },
  );
  test(
    'initialization failure is retryable instead of poisoning all later sign-ins',
    () async {
      bridge.failInitialization = true;
      await expectLater(auth.signIn(), throwsA(isA<GoogleCloudError>()));
      bridge.failInitialization = false;
      await auth.signIn();
      expect(bridge.attempts, 2);
    },
  );
  test(
    'restoration cannot silently switch to another native Google account',
    () async {
      store.value = jsonEncode(const GoogleAccount(subject: 'bob').toJson());
      await expectLater(
        auth.restore(),
        throwsA(
          isA<GoogleCloudError>().having((e) => e.code, 'code', 'reauth'),
        ),
      );
      expect(auth.account!.subject, 'bob');
      await expectLater(
        auth.signIn(expectedSubject: 'bob'),
        throwsA(
          isA<GoogleCloudError>().having(
            (e) => e.code,
            'code',
            'accountMismatch',
          ),
        ),
      );
      expect(bridge.signOuts, 1);
    },
  );
  test('cancelled native callback cannot reconnect an account', () async {
    bridge.signingIn = Completer<void>();
    final pending = auth.signIn();
    await Future<void>.delayed(Duration.zero);
    auth.cancel();
    bridge.signingIn!.complete();
    await expectLater(pending, throwsA(isA<GoogleCloudError>()));
    expect(auth.account, isNull);
    expect(store.value, isNull);
  });
  test(
    'disconnect during secure write cannot leave a stale restored identity',
    () async {
      store.writing = Completer<void>();
      final pending = auth.signIn();
      await Future<void>.delayed(Duration.zero);
      final disconnected = auth.signOut();
      final rejected = expectLater(pending, throwsA(isA<GoogleCloudError>()));
      store.writing!.complete();
      await rejected;
      await disconnected;
      expect(auth.account, isNull);
      expect(store.value, isNull);
    },
  );
  test(
    'restore is silent and unconfigured builds never open native authentication',
    () async {
      await auth.signIn();
      final restored = GoogleMobileAuth(
        configured: true,
        bridge: bridge,
        credentials: store,
      );
      await restored.restore();
      expect(bridge.user!.requests.last, isFalse);
      final unavailable = GoogleMobileAuth(
        configured: false,
        bridge: bridge,
        credentials: store,
      );
      await expectLater(
        unavailable.signIn(),
        throwsA(
          isA<GoogleCloudError>().having(
            (e) => e.code,
            'code',
            'configuration',
          ),
        ),
      );
      expect(await unavailable.restore(), isNull);
    },
  );
}
