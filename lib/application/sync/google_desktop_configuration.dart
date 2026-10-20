import 'dart:convert';
import 'google_account.dart';

/// Desktop app registration, never a user's password or refresh token.
class GoogleDesktopConfiguration {
  const GoogleDesktopConfiguration(this.clientId, this.clientSecret);
  final String clientId, clientSecret;
  static GoogleDesktopConfiguration fromDownload(String source) {
    if (source.length > 65536) throw _invalid();
    try {
      final value = jsonDecode(
        source.startsWith('\uFEFF') ? source.substring(1) : source,
      );
      if (value is! Map ||
          value['installed'] is! Map ||
          value.containsKey('web')) {
        throw _invalid();
      }
      final installed = value['installed'] as Map;
      if (installed['auth_uri'] != null &&
          installed['auth_uri'] !=
              'https://accounts.google.com/o/oauth2/auth') {
        throw _invalid();
      }
      if (installed['token_uri'] != null &&
          installed['token_uri'] != 'https://oauth2.googleapis.com/token') {
        throw _invalid();
      }
      return _parse(installed['client_id'], installed['client_secret'] ?? '');
    } on Object {
      throw _invalid();
    }
  }

  static GoogleDesktopConfiguration fromStored(String source) {
    try {
      final value = jsonDecode(source);
      if (value is! Map || value['version'] != 1) throw _invalid();
      return _parse(value['clientId'], value['clientSecret']);
    } on Object {
      throw _invalid();
    }
  }

  static GoogleDesktopConfiguration _parse(dynamic id, dynamic secret) {
    if (id is! String ||
        !RegExp(
          r'^\d+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$',
        ).hasMatch(id) ||
        secret is! String ||
        secret.length > 8192 ||
        secret.contains(RegExp(r'[\r\n]'))) {
      throw _invalid();
    }
    return GoogleDesktopConfiguration(id, secret);
  }

  String encode() => jsonEncode({
    'version': 1,
    'clientId': clientId,
    'clientSecret': clientSecret,
  });
  static GoogleCloudError _invalid() => const GoogleCloudError(
    'configuration',
    'Choose the JSON downloaded for a Google OAuth Desktop app client. Web clients, passwords and access tokens cannot activate desktop sign-in.',
  );
}
