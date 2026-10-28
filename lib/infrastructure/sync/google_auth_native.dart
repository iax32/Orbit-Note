import 'dart:async';
import '../../application/sync/google_mobile_auth.dart';
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../application/sync/google_account.dart';
import 'google_desktop_auth.dart';
import 'google_credential_store.dart';
import 'google_auth_stub.dart' as stub;

GoogleAccountAuth createGoogleAuth() {
  if (Platform.isAndroid || Platform.isIOS) {
    const androidId = String.fromEnvironment(
      'ORBIT_GOOGLE_ANDROID_SERVER_CLIENT_ID',
    );
    const iosId = String.fromEnvironment('ORBIT_GOOGLE_IOS_CLIENT_ID');
    final ios = Platform.isIOS;
    return GoogleMobileAuth(
      configured: (ios ? iosId : androidId).isNotEmpty,
      bridge: NativeMobileGoogleBridge(
        clientId: ios ? iosId : null,
        serverClientId: ios ? null : androidId,
      ),
      credentials: SecureGoogleCredentials(
        ios ? 'orbit.google.ios.v1' : 'orbit.google.android.v1',
      ),
    );
  }
  if (!Platform.isWindows) return stub.createGoogleAuth();
  return GoogleDesktopAuth(
    clientId: const String.fromEnvironment('ORBIT_GOOGLE_DESKTOP_CLIENT_ID'),
    clientSecret: const String.fromEnvironment(
      'ORBIT_GOOGLE_DESKTOP_CLIENT_SECRET',
    ),
    credentials: const SecureGoogleCredentials('orbit.google.desktop.v1'),
    configurationStore: const SecureGoogleCredentials(
      'orbit.google.desktop-client.v1',
    ),
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

/// Google SDK handles the native activity/URL callback and token refresh.
class NativeMobileGoogleBridge implements MobileGoogleBridge {
  NativeMobileGoogleBridge({this.clientId, this.serverClientId});
  final String? clientId, serverClientId;
  final GoogleSignIn sdk = GoogleSignIn.instance;
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on GoogleSignInException catch (error) {
      throw switch (error.code) {
        GoogleSignInExceptionCode.canceled => const GoogleCloudError(
          'cancelled',
          'Sign-in was cancelled.',
        ),
        GoogleSignInExceptionCode.clientConfigurationError =>
          const GoogleCloudError(
            'configuration',
            'Google app registration does not match this build. The distributor must check the OAuth client, package name, signing certificate and iOS callback scheme.',
          ),
        _ => const GoogleCloudError(
          'reauth',
          'Google could not finish sign-in. Check your connection and try again.',
        ),
      };
    }
  }

  @override
  Future<void> initialize() => _guard(
    () => sdk.initialize(clientId: clientId, serverClientId: serverClientId),
  );
  @override
  Future<MobileGoogleUser?> authenticate({required bool interactive}) =>
      _guard(() async {
        final user = interactive
            ? await sdk.authenticate()
            : await sdk.attemptLightweightAuthentication();
        return user == null ? null : _NativeGoogleUser(user, this);
      });
  @override
  Future<void> signOut() => _guard(sdk.signOut);
}

class _NativeGoogleUser implements MobileGoogleUser {
  _NativeGoogleUser(this.user, this.bridge);
  final GoogleSignInAccount user;
  final NativeMobileGoogleBridge bridge;
  String? _token;
  @override
  GoogleAccount get account => GoogleAccount(
    subject: user.id,
    name: user.displayName ?? '',
    email: user.email,
    avatar: user.photoUrl,
  );
  @override
  Future<String> authorize({required bool interactive, bool refresh = false}) =>
      bridge._guard(() async {
        if (refresh && _token != null) {
          await user.authorizationClient.clearAuthorizationToken(
            accessToken: _token!,
          );
        }
        final grant = interactive
            ? await user.authorizationClient.authorizeScopes(googleScopes)
            : await user.authorizationClient.authorizationForScopes(
                googleScopes,
              );
        if (grant == null) {
          throw const GoogleCloudError(
            'reauth',
            'Reconnect Google Drive to allow access to Orbit files.',
          );
        }
        return _token = grant.accessToken;
      });
}
