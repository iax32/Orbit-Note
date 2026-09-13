import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../../application/sync/google_account.dart';

abstract interface class GoogleAuthorizationReceiver {
  Uri get redirect;
  Future<Uri> get callback;
  Future<void> close();
}

class GoogleDesktopAuth implements GoogleAccountAuth {
  GoogleDesktopAuth({
    required this.clientId,
    this.clientSecret = '',
    required this.credentials,
    required this.client,
    required this.openBrowser,
    required this.receive,
    this.timeout = const Duration(minutes: 3),
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final String clientId, clientSecret;
  final GoogleCredentialStore credentials;
  final http.Client client;
  final Future<bool> Function(Uri) openBrowser;
  final Future<GoogleAuthorizationReceiver> Function() receive;
  final Duration timeout;
  final DateTime Function() now;
  GoogleAccount? _account;
  String? _access, _refresh;
  DateTime? _expires;
  Future<String>? _refreshing;
  Completer<void>? _cancel;
  int _generation = 0;
  Future<void> _credentialWrites = Future.value();
  Future<void> _store(Future<void> Function() operation) {
    final next = _credentialWrites.then((_) => operation());
    _credentialWrites = next.catchError((Object _) {});
    return next;
  }

  @override
  bool get configured => clientId.isNotEmpty;
  @override
  GoogleAccount? get account => _account;
  String _random() => base64UrlEncode(
    List.generate(32, (_) => Random.secure().nextInt(256)),
  ).replaceAll('=', '');
  void _check(int generation) {
    if (generation != _generation) {
      throw const GoogleCloudError('cancelled', 'Sign-in was cancelled.');
    }
  }

  @override
  Future<GoogleAccount> signIn({String? expectedSubject}) async {
    if (!configured) {
      throw const GoogleCloudError(
        'configuration',
        'Google sign-in is not configured in this build. You can keep using Orbit locally.',
      );
    }
    if (_cancel != null) {
      throw const GoogleCloudError('busy', 'A Google sign-in is already open.');
    }
    final generation = ++_generation;
    final cancel = _cancel = Completer<void>();
    GoogleAuthorizationReceiver? receiver;
    try {
      receiver = await receive();
      _check(generation);
      final verifier = _random(), state = _random();
      final uri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': clientId,
        'redirect_uri': receiver.redirect.toString(),
        'response_type': 'code',
        'scope': googleScopes.join(' '),
        'state': state,
        'code_challenge_method': 'S256',
        'code_challenge': base64UrlEncode(
          sha256.convert(ascii.encode(verifier)).bytes,
        ).replaceAll('=', ''),
        'access_type': 'offline',
        'prompt': 'consent select_account',
      });
      if (!await openBrowser(uri)) {
        throw const GoogleCloudError(
          'browser',
          'The browser could not open. Try again.',
        );
      }
      final response = await Future.any<Uri>([
        receiver.callback,
        cancel.future.then<Uri>(
          (_) => throw const GoogleCloudError(
            'cancelled',
            'Sign-in was cancelled.',
          ),
        ),
      ]).timeout(timeout);
      _check(generation);
      if (response.scheme != receiver.redirect.scheme ||
          response.host != receiver.redirect.host ||
          response.port != receiver.redirect.port ||
          response.path != receiver.redirect.path ||
          response.queryParametersAll['state']?.length != 1 ||
          response.queryParameters['state'] != state) {
        throw const GoogleCloudError(
          'state',
          'Google sign-in could not be verified. Please try again.',
        );
      }
      if (response.queryParameters.containsKey('error')) {
        throw const GoogleCloudError(
          'cancelled',
          'Sign-in was cancelled or permission was declined.',
        );
      }
      final code = response.queryParameters['code'];
      if (code == null ||
          code.isEmpty ||
          response.queryParametersAll['code']?.length != 1) {
        throw const GoogleCloudError(
          'callback',
          'Google did not return a valid sign-in response.',
        );
      }
      final tokens = await _token({
        'grant_type': 'authorization_code',
        'code': code,
        'code_verifier': verifier,
        'redirect_uri': receiver.redirect.toString(),
      });
      final profileResponse = await client
          .get(
            Uri.https('openidconnect.googleapis.com', '/v1/userinfo'),
            headers: {'Authorization': 'Bearer ${tokens['access_token']}'},
          )
          .timeout(const Duration(seconds: 30));
      if (profileResponse.statusCode != 200) {
        throw const GoogleCloudError(
          'identity',
          'Google could not confirm the account. Please try again.',
        );
      }
      final profile = GoogleAccount.fromJson(
        jsonDecode(profileResponse.body) as Map<String, dynamic>,
      );
      if (expectedSubject != null && profile.subject != expectedSubject) {
        throw const GoogleCloudError(
          'accountMismatch',
          'Choose the previously connected Google account, or use Change account first.',
        );
      }
      _check(generation);
      final refresh = tokens['refresh_token'];
      if (refresh is! String || refresh.isEmpty) {
        throw const GoogleCloudError(
          'authorization',
          'Google did not allow session restoration. Reconnect and approve access.',
        );
      }
      await _commit(profile, tokens, refresh, generation);
      return profile;
    } on TimeoutException {
      throw const GoogleCloudError(
        'timeout',
        'Google sign-in timed out. Please try again.',
      );
    } on GoogleCloudError {
      rethrow;
    } on Object {
      throw const GoogleCloudError(
        'network',
        'Google is unavailable. Your local Vault is unaffected.',
      );
    } finally {
      await receiver?.close();
      _cancel = null;
    }
  }

  Future<Map<String, dynamic>> _token(Map<String, String> values) async {
    final response = await client
        .post(
          Uri.https('oauth2.googleapis.com', '/token'),
          body: {
            ...values,
            'client_id': clientId,
            if (clientSecret.isNotEmpty) 'client_secret': clientSecret,
          },
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      if (response.statusCode == 400 || response.statusCode == 401) {
        throw const GoogleCloudError(
          'reauth',
          'Google Drive needs to be connected again.',
        );
      }
      throw const GoogleCloudError(
        'network',
        'Google is temporarily unavailable.',
      );
    }
    final value = jsonDecode(response.body) as Map<String, dynamic>;
    if (value['access_token'] is! String ||
        (value['access_token'] as String).isEmpty ||
        value['token_type']?.toString().toLowerCase() != 'bearer' ||
        value['expires_in'] is! num ||
        (value['expires_in'] as num) <= 0) {
      throw const GoogleCloudError(
        'token',
        'Google returned an invalid authorization response.',
      );
    }
    if (value['scope'] is String &&
        !(value['scope'] as String).split(' ').contains(googleDriveScope)) {
      throw const GoogleCloudError(
        'permission',
        'Allow access to Orbit files in Google Drive to continue.',
      );
    }
    return value;
  }

  Future<void> _commit(
    GoogleAccount profile,
    Map<String, dynamic> tokens,
    String refresh,
    int generation,
  ) async {
    _check(generation);
    final expires = now().add(
      Duration(seconds: (tokens['expires_in'] as num).toInt()),
    );
    await _store(() async {
      _check(generation);
      await credentials.write(
        jsonEncode({
          'version': 1,
          'clientId': clientId,
          'account': profile.toJson(),
          'access': tokens['access_token'],
          'refresh': refresh,
          'expires': expires.toUtc().toIso8601String(),
        }),
      );
    });
    _check(generation);
    _account = profile;
    _access = tokens['access_token'] as String;
    _refresh = refresh;
    _expires = expires;
  }

  @override
  Future<GoogleAccount?> restore() async {
    if (!configured) return null;
    final generation = _generation;
    final raw = await credentials.read();
    _check(generation);
    if (raw == null) return null;
    try {
      final v = jsonDecode(raw) as Map;
      if (v['version'] != 1 || v['clientId'] != clientId) {
        throw const FormatException();
      }
      _account = GoogleAccount.fromJson(
        Map<String, dynamic>.from(v['account'] as Map),
      );
      _access = v['access'] as String;
      _refresh = v['refresh'] as String;
      _expires = DateTime.parse(v['expires'] as String);
    } on Object {
      throw const GoogleCloudError(
        'reauth',
        'Google Drive needs to be connected again.',
      );
    }
    await accessToken();
    return _account;
  }

  @override
  Future<String> accessToken({bool refresh = false}) async {
    if (_account == null || _refresh == null) {
      throw const GoogleCloudError(
        'reauth',
        'Connect Google Drive to continue.',
      );
    }
    if (!refresh &&
        _access != null &&
        _expires!.isAfter(now().add(const Duration(minutes: 1)))) {
      return _access!;
    }
    return _refreshing ??= _renew().whenComplete(() => _refreshing = null);
  }

  Future<String> _renew() async {
    final generation = _generation, profile = _account!;
    final value = await _token({
      'grant_type': 'refresh_token',
      'refresh_token': _refresh!,
    });
    await _commit(
      profile,
      value,
      value['refresh_token'] as String? ?? _refresh!,
      generation,
    );
    return _access!;
  }

  @override
  void cancel() {
    _generation++;
    if (_cancel?.isCompleted == false) _cancel!.complete();
  }

  @override
  Future<void> signOut() async {
    cancel();
    // Removing this installation's credentials does not revoke other devices.
    await _store(credentials.delete);
    _account = null;
    _access = null;
    _refresh = null;
    _expires = null;
  }
}
