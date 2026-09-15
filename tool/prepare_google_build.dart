import 'dart:convert';
import 'dart:io';

/// Only public application identifiers/native-client values enter a build.
/// User account credentials must never come from the distributor or CI.
Map<String, String> googleBuildConfiguration(
  String platform,
  Map<String, String> environment,
) {
  if (platform != 'windows' && platform != 'android') {
    throw const FormatException('Choose windows or android.');
  }
  final mode = environment['ORBIT_GOOGLE_BUILD_MODE'] ?? 'local-only';
  if (mode == 'local-only') return const {};
  if (mode != 'google-account-preview') {
    throw const FormatException(
      'Choose local-only or google-account-preview. Full Google sync is not released yet.',
    );
  }
  final key = platform == 'windows'
      ? 'ORBIT_GOOGLE_DESKTOP_CLIENT_ID'
      : 'ORBIT_GOOGLE_ANDROID_SERVER_CLIENT_ID';
  final clientId = environment[key]?.trim() ?? '';
  if (!RegExp(
    r'^\d+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$',
  ).hasMatch(clientId)) {
    // Report the required setting, never its value or the surrounding environment.
    throw FormatException(
      'Configure $key before building the Google account preview.',
    );
  }
  return {
    key: clientId,
    if (platform == 'windows')
      'ORBIT_GOOGLE_DESKTOP_CLIENT_SECRET':
          environment['ORBIT_GOOGLE_DESKTOP_CLIENT_SECRET'] ?? '',
  };
}

Future<void> main(List<String> arguments) async {
  try {
    final options = <String, String>{};
    for (final argument in arguments) {
      final split = argument.indexOf('=');
      if (split < 0 || !argument.startsWith('--')) {
        throw const FormatException(
          'Use --platform=windows|android and --output=PATH.',
        );
      }
      final key = argument.substring(2, split);
      if (!{'platform', 'output', 'config'}.contains(key) ||
          options.containsKey(key)) {
        throw const FormatException('Unknown or repeated build option.');
      }
      options[key] = argument.substring(split + 1);
    }
    final output = options['output'];
    if (output == null || output.isEmpty) {
      throw const FormatException(
        'A generated build configuration output path is required.',
      );
    }
    final environment = Map<String, String>.from(Platform.environment);
    final config = options['config'];
    if (config != null) {
      if (File(config).absolute.path == File(output).absolute.path) {
        throw const FormatException(
          'Keep the input configuration separate from generated output.',
        );
      }
      final decoded = jsonDecode(await File(config).readAsString());
      if (decoded is! Map<String, dynamic> ||
          decoded.values.any((v) => v is! String)) {
        throw const FormatException(
          'Google build configuration must contain string values.',
        );
      }
      // File values cannot change the chosen build mode, or add arbitrary defines.
      for (final key in const [
        'ORBIT_GOOGLE_DESKTOP_CLIENT_ID',
        'ORBIT_GOOGLE_DESKTOP_CLIENT_SECRET',
        'ORBIT_GOOGLE_ANDROID_SERVER_CLIENT_ID',
      ]) {
        if (decoded.containsKey(key)) environment[key] = decoded[key] as String;
      }
    }
    final configuration = googleBuildConfiguration(
      options['platform'] ?? '',
      environment,
    );
    final file = File(output);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(configuration)}\n',
    );
    stdout.writeln(
      configuration.isEmpty
          ? 'Local-only build: Google sign-in is disabled.'
          : 'Google account preview configured. Vault transfers and automatic sync remain unfinished.',
    );
  } on FormatException catch (error) {
    // JSON parse exceptions may contain input excerpts; use a generic message.
    stderr.writeln(
      error.source == null
          ? error.message
          : 'Invalid Google build configuration JSON.',
    );
    exitCode = 1;
  } on FileSystemException {
    stderr.writeln(
      'Could not read or write Google build configuration. Check the supplied paths.',
    );
    exitCode = 1;
  }
}
