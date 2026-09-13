import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../application/sync/google_account.dart';
import 'google_desktop_auth.dart';
import 'google_credential_store.dart';
import 'google_auth_stub.dart' as stub;

GoogleAccountAuth createGoogleAuth() {
  if (Platform.isAndroid) return GoogleAndroidAuth();
  if (!Platform.isWindows) return stub.createGoogleAuth();
  return GoogleDesktopAuth(
    clientId: const String.fromEnvironment('ORBIT_GOOGLE_DESKTOP_CLIENT_ID'),
    clientSecret: const String.fromEnvironment(
      'ORBIT_GOOGLE_DESKTOP_CLIENT_SECRET',
    ),
    credentials: const SecureGoogleCredentials('orbit.google.desktop.v1'),
    client: http.Client(),
    openBrowser: (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
    receive: LoopbackGoogleReceiver.bind,
  );
}

class LoopbackGoogleReceiver implements GoogleAuthorizationReceiver {
  LoopbackGoogleReceiver._(this.server) {
    server.listen(
      (request) async {
        if (request.method != 'GET' || request.uri.path != '/oauth/callback') {
          request.response.statusCode = 404;
        } else {
          if (!_response.isCompleted) {
            _response.complete(redirect.replace(query: request.uri.query));
          }
          request.response.headers.contentType = ContentType.html;
          request.response.headers.set('Cache-Control', 'no-store');
          request.response.headers.set(
            'Content-Security-Policy',
            "default-src 'none'",
          );
          request.response.write(
            '<!doctype html><title>Orbit Note</title><p>You can return to Orbit Note. Check the app for your sign-in result.</p>',
          );
        }
        await request.response.close();
      },
      onError: (Object _) {
        if (!_response.isCompleted) {
          _response.completeError(
            const GoogleCloudError(
              'callback',
              'Google sign-in could not return to Orbit.',
            ),
          );
        }
      },
    );
  }
  final HttpServer server;
  final _response = Completer<Uri>();
  static Future<LoopbackGoogleReceiver> bind() async =>
      LoopbackGoogleReceiver._(
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
      );
  @override
  Uri get redirect =>
      Uri.parse('http://127.0.0.1:${server.port}/oauth/callback');
  @override
  Future<Uri> get callback => _response.future;
  @override
  Future<void> close() async {
    await server.close(force: true);
  }
}

/// Credential Manager identity and Google authorization are separate SDK calls.
/// Android's Google services own refresh credentials; Orbit never exports them.
class GoogleAndroidAuth implements GoogleAccountAuth {
  static const serverClientId = String.fromEnvironment(
    'ORBIT_GOOGLE_ANDROID_SERVER_CLIENT_ID',
  );
  static Future<void>? _initialized;
  final GoogleSignIn sdk = GoogleSignIn.instance;
  final GoogleCredentialStore credentials = const SecureGoogleCredentials(
    'orbit.google.android.v1',
  );
  GoogleSignInAccount? _user;
  GoogleAccount? _account;
  String? _token;
  int _generation = 0;
  @override
  bool get configured => serverClientId.isNotEmpty;
  @override
  GoogleAccount? get account => _account;
  Future<void> _init() =>
      _initialized ??= sdk.initialize(serverClientId: serverClientId);
  GoogleCloudError _error(Object error) =>
      error is GoogleSignInException &&
          error.code == GoogleSignInExceptionCode.canceled
      ? const GoogleCloudError('cancelled', 'Sign-in was cancelled.')
      : const GoogleCloudError(
          'reauth',
          'Google Drive needs to be connected again.',
        );
  @override
  Future<GoogleAccount> signIn({String? expectedSubject}) async {
    if (!configured) {
      throw const GoogleCloudError(
        'configuration',
        'Google sign-in is not configured in this build.',
      );
    }
    final generation = ++_generation;
    try {
      await _init();
      final user = await sdk.authenticate();
      if (expectedSubject != null && user.id != expectedSubject) {
        await sdk.signOut();
        throw const GoogleCloudError(
          'accountMismatch',
          'Choose the previously connected Google account, or use Change account first.',
        );
      }
      final grant = await user.authorizationClient.authorizeScopes(
        googleScopes,
      );
      if (generation != _generation) {
        throw const GoogleCloudError('cancelled', 'Sign-in was cancelled.');
      }
      _user = user;
      _token = grant.accessToken;
      _account = GoogleAccount(
        subject: user.id,
        name: user.displayName ?? '',
        email: user.email,
        avatar: user.photoUrl,
      );
      await credentials.write(jsonEncode(_account!.toJson()));
      return _account!;
    } on GoogleCloudError {
      rethrow;
    } on Object catch (e) {
      throw _error(e);
    }
  }

  @override
  Future<GoogleAccount?> restore() async {
    if (!configured) return null;
    final raw = await credentials.read();
    if (raw == null) return null;
    try {
      _account = GoogleAccount.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      await _init();
      _user = await sdk.attemptLightweightAuthentication();
      if (_user == null || _user!.id != _account!.subject) {
        throw const GoogleCloudError(
          'reauth',
          'Reconnect the same Google account to continue.',
        );
      }
      await accessToken();
      return _account;
    } on GoogleCloudError {
      rethrow;
    } on Object catch (e) {
      throw _error(e);
    }
  }

  @override
  Future<String> accessToken({bool refresh = false}) async {
    if (_user == null) {
      throw const GoogleCloudError(
        'reauth',
        'Connect Google Drive to continue.',
      );
    }
    try {
      if (refresh && _token != null) {
        await _user!.authorizationClient.clearAuthorizationToken(
          accessToken: _token!,
        );
      }
      final grant = await _user!.authorizationClient.authorizationForScopes(
        googleScopes,
      );
      if (grant == null) {
        throw const GoogleCloudError(
          'reauth',
          'Reconnect Google Drive to allow access to Orbit files.',
        );
      }
      return _token = grant.accessToken;
    } on GoogleCloudError {
      rethrow;
    } on Object catch (e) {
      throw _error(e);
    }
  }

  @override
  void cancel() {
    _generation++;
  }

  @override
  Future<void> signOut() async {
    cancel();
    await _init();
    await sdk.signOut();
    await credentials.delete();
    _account = null;
    _user = null;
    _token = null;
  }
}
