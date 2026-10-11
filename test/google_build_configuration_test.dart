import 'package:flutter_test/flutter_test.dart';
import '../tool/prepare_google_build.dart' show googleBuildConfiguration;

void main() {
  const desktop = '123456-desktop.apps.googleusercontent.com';
  const android = '123456-android.apps.googleusercontent.com';
  const configured = {
    'ORBIT_GOOGLE_BUILD_MODE': 'google-account-preview',
    'ORBIT_GOOGLE_DESKTOP_CLIENT_ID': desktop,
    'ORBIT_GOOGLE_DESKTOP_CLIENT_SECRET': 'native-client-value',
    'ORBIT_GOOGLE_ANDROID_SERVER_CLIENT_ID': android,
    'GOOGLE_REFRESH_TOKEN': 'must-not-be-embedded',
    'GOOGLE_ACCESS_TOKEN': 'must-not-be-embedded',
    'UNRELATED_CI_SECRET': 'must-not-be-embedded',
  };
  test('preview embeds only the selected platform app configuration', () {
    expect(googleBuildConfiguration('windows', configured), {
      'ORBIT_GOOGLE_DESKTOP_CLIENT_ID': desktop,
      'ORBIT_GOOGLE_DESKTOP_CLIENT_SECRET': 'native-client-value',
    });
    expect(googleBuildConfiguration('android', configured), {
      'ORBIT_GOOGLE_ANDROID_SERVER_CLIENT_ID': android,
    });
  });
  test('local-only mode never embeds available credentials', () {
    expect(googleBuildConfiguration('windows', {}), isEmpty);
    expect(
      googleBuildConfiguration('android', {
        ...configured,
        'ORBIT_GOOGLE_BUILD_MODE': 'local-only',
      }),
      isEmpty,
    );
  });
  test('missing and example identifiers fail before preview builds', () {
    for (final platform in ['windows', 'android']) {
      for (final invalid in [
        '',
        'YOUR_CLIENT_ID.apps.googleusercontent.com',
        'not-a-client',
      ]) {
        expect(
          () => googleBuildConfiguration(platform, {
            'ORBIT_GOOGLE_BUILD_MODE': 'google-account-preview',
            'ORBIT_GOOGLE_DESKTOP_CLIENT_ID': invalid,
            'ORBIT_GOOGLE_ANDROID_SERVER_CLIENT_ID': invalid,
          }),
          throwsFormatException,
        );
      }
    }
  });
  test('unknown mode or platform cannot silently produce a release', () {
    expect(
      () => googleBuildConfiguration('ios', configured),
      throwsFormatException,
    );
    expect(
      () => googleBuildConfiguration('windows', {
        ...configured,
        'ORBIT_GOOGLE_BUILD_MODE': 'google-sync-ready',
      }),
      throwsFormatException,
    );
  });
  test('invalid identifiers never leak their values through errors', () {
    try {
      googleBuildConfiguration('windows', {
        'ORBIT_GOOGLE_BUILD_MODE': 'google-account-preview',
        'ORBIT_GOOGLE_DESKTOP_CLIENT_ID': 'private-value',
      });
      fail('Invalid configuration accepted');
    } on FormatException catch (error) {
      expect(error.toString(), isNot(contains('private-value')));
    }
  });
}
