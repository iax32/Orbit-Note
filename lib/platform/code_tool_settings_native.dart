import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../domain/code_project.dart';

Future<File> _settingsFile([String? location]) async => File(
  location ??
      p.join(
        (await getApplicationSupportDirectory()).path,
        'code-tools.local.json',
      ),
);
Future<Map<String, dynamic>> loadCodeToolSettings([String? location]) async {
  final file = await _settingsFile(location);
  if (!await file.exists()) return {};
  if (await file.length() > 65536) {
    throw const FormatException('Code tool settings exceed their limit.');
  }
  final value = jsonDecode(await file.readAsString());
  if (value is! Map || value['version'] != 1) {
    throw const FormatException(
      'Unsupported code tool settings; original data retained.',
    );
  }
  return Map<String, dynamic>.from(value);
}

Future<void> saveCodeToolSettings(
  Map<String, dynamic> settings, {
  String? location,
}) async {
  for (final key in ['python', 'compiler', 'debugger']) {
    if (settings[key] is String) ToolCommand(settings[key] as String, []);
  }
  final servers = settings['servers'];
  if (settings['debuggerArguments'] is String) {
    final args = jsonDecode(settings['debuggerArguments'] as String);
    if (args is! List || args.any((a) => a is! String)) {
      throw const FormatException(
        'Debugger arguments must be a JSON string array.',
      );
    }
  }
  if (servers is! Map) {
    throw const FormatException('Invalid language server settings.');
  }
  for (final item in servers.values) {
    if (item is! Map ||
        item['executable'] is! String ||
        item['arguments'] is! List ||
        (item['arguments'] as List).any((a) => a is! String)) {
      throw const FormatException('Invalid language command.');
    }
    ToolCommand(
      item['executable'] as String,
      (item['arguments'] as List).cast<String>(),
    );
  }
  final old = await loadCodeToolSettings(location);
  final file = await _settingsFile(location);
  await file.parent.create(recursive: true);
  final oldServers = old['servers'] is Map ? old['servers'] as Map : {};
  final bytes = utf8.encode(
    jsonEncode({
      ...old,
      ...settings,
      'version': 1,
      'servers': {
        ...oldServers,
        for (final entry in servers.entries)
          entry.key: {
            if (oldServers[entry.key] is Map) ...(oldServers[entry.key] as Map),
            ...(entry.value as Map),
          },
      },
    }),
  );
  if (bytes.length > 65536) {
    throw const FormatException('Code tool settings exceed their limit.');
  }
  final temporary = File('${file.path}.${const Uuid().v4()}.tmp');
  try {
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(file.path);
  } finally {
    if (await temporary.exists()) await temporary.delete();
  }
}
