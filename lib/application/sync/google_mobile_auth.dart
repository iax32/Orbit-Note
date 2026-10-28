import 'dart:convert';
import 'google_account.dart';

/// Native SDK owns refresh credentials. Only the public account identity is
/// stored by Orbit, outside the Vault. The bridge is replaceable for testing.
abstract interface class MobileGoogleBridge {
  Future<void> initialize();
  Future<MobileGoogleUser?> authenticate({required bool interactive});
  Future<void> signOut();
}

abstract interface class MobileGoogleUser {
  GoogleAccount get account;
  Future<String> authorize({required bool interactive, bool refresh = false});
}

class GoogleMobileAuth implements GoogleAccountAuth {
  GoogleMobileAuth({
    required this.configured,
    required this.bridge,
    required this.credentials,
  });
  @override
  final bool configured;
  final MobileGoogleBridge bridge;
  final GoogleCredentialStore credentials;
  Future<void>? _initializing;
  Future<void> _storage = Future<void>.value();
  MobileGoogleUser? _user;
  GoogleAccount? _account;
  int _generation = 0;
  @override
  GoogleAccount? get account => _account;

  Future<void> _init() async {
    final pending = _initializing ??= bridge.initialize();
    try {
      await pending;
    } catch (_) {
      if (identical(pending, _initializing)) _initializing = null;
      rethrow;
    }
  }

  void _check(int generation) {
    if (generation != _generation) {
      throw const GoogleCloudError('cancelled', 'Sign-in was cancelled.');
    }
  }

  Future<void> _serializeStorage(Future<void> Function() action) {
    final next = _storage.then((_) => action());
    _storage = next.catchError((Object _) {});
    return next;
  }

  @override
  Future<GoogleAccount> signIn({String? expectedSubject}) async {
    if (!configured) {
      throw const GoogleCloudError(
        'configuration',
        'This mobile build has no Google app registration. Install a configured release; signing into Google Cloud in a browser does not connect Orbit.',
      );
    }
    final generation = ++_generation;
    await _init();
    _check(generation);
    final user = await bridge.authenticate(interactive: true);
    _check(generation);
    if (user == null) {
      throw const GoogleCloudError('cancelled', 'Sign-in was cancelled.');
    }
    if (expectedSubject != null && user.account.subject != expectedSubject) {
      await bridge.signOut();
      throw const GoogleCloudError(
        'accountMismatch',
        'Choose the previously connected Google account, or use Change account first.',
      );
    }
    await user.authorize(interactive: true);
    _check(generation);
    await _serializeStorage(() async {
      _check(generation);
      await credentials.write(jsonEncode(user.account.toJson()));
      if (generation != _generation) await credentials.delete();
    });
    _check(generation);
    _user = user;
    return _account = user.account;
  }

  @override
  Future<GoogleAccount?> restore() async {
    if (!configured) return null;
    final generation = _generation;
    final raw = await credentials.read();
    _check(generation);
    if (raw == null) return null;
    GoogleAccount saved;
    try {
      saved = GoogleAccount.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      throw const GoogleCloudError('reauth', 'Reconnect Google Drive.');
    }
    _account = saved; // Keep the expected identity for reconnect validation.
    await _init();
    _check(generation);
    final user = await bridge.authenticate(interactive: false);
    _check(generation);
    if (user == null || user.account.subject != saved.subject) {
      throw const GoogleCloudError(
        'reauth',
        'Reconnect the same Google account to continue.',
      );
    }
    await user.authorize(interactive: false);
    _check(generation);
    _user = user;
    return _account = user.account;
  }

  @override
  Future<String> accessToken({bool refresh = false}) async {
    final user = _user;
    if (user == null) {
      throw const GoogleCloudError(
        'reauth',
        'Connect Google Drive to continue.',
      );
    }
    final generation = _generation;
    final token = await user.authorize(interactive: false, refresh: refresh);
    _check(generation);
    return token;
  }

  @override
  void cancel() => _generation++;

  @override
  Future<void> signOut() async {
    cancel();
    _user = null;
    _account = null;
    // Local disconnect remains possible if the SDK is unavailable/offline.
    await _serializeStorage(credentials.delete);
    if (!configured) return;
    await _init();
    await bridge.signOut();
  }
}
