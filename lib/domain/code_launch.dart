import 'dart:convert';
import 'package:path/path.dart' as p;
import 'code_project.dart';

bool validCodeWorkingDirectory(String value) =>
    value == '.' ||
    (value.isNotEmpty &&
        value.length <= 4096 &&
        !value.startsWith('/') &&
        !value.contains(RegExp(r'[\\:\x00\r\n]')) &&
        !value
            .split('/')
            .any(
              (s) => s.isEmpty || s == '.' || s == '..' || s.startsWith('.'),
            ));

class CodeLaunchSnapshot {
  CodeLaunchSnapshot(Map<String, dynamic> data, this.hash)
    : data = Map<String, dynamic>.from(jsonDecode(jsonEncode(data)) as Map);
  factory CodeLaunchSnapshot.empty() =>
      CodeLaunchSnapshot({'version': 1, 'profiles': []}, null);
  final Map<String, dynamic> data;
  final String? hash;
  List<CodeRunProfile> get profiles {
    if (data['version'] != 1 ||
        data['profiles'] is! List ||
        (data['profiles'] as List).length > 30) {
      throw const FormatException(
        'Unsupported launch settings. Original data was retained.',
      );
    }
    final result = (data['profiles'] as List)
        .map(CodeRunProfile.parse)
        .toList();
    if (result.map((p) => p.id).toSet().length != result.length) {
      throw const FormatException('Duplicate launch profile identities.');
    }
    return result;
  }

  Map<String, dynamic> replacing(CodeRunProfile profile) => {
    ...data,
    'profiles': [
      for (final p in profiles)
        if (p.id == profile.id) profile.data else p.data,
      if (!profiles.any((p) => p.id == profile.id)) profile.data,
    ],
  };
  Map<String, dynamic> removing(String id) => {
    ...data,
    'profiles': [
      for (final p in profiles)
        if (p.id != id) p.data,
    ],
  };
}

class CodeRunProfile {
  CodeRunProfile.parse(dynamic value) {
    if (value is! Map) throw const FormatException('Invalid run profile.');
    data = Map<String, dynamic>.from(value);
    if (data['id'] is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(data['id']) ||
        data['name'] is! String ||
        name.trim().isEmpty ||
        name.length > 100 ||
        data['cwd'] is! String ||
        !validCodeWorkingDirectory(cwd) ||
        data['steps'] is! List ||
        steps.isEmpty ||
        steps.length > 8) {
      throw const FormatException(
        'Choose a name, scoped folder and 1–8 valid steps.',
      );
    }
  }
  late final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get name => data['name'] as String;
  String get cwd => data['cwd'] as String;
  List<CodeRunStep> get steps =>
      (data['steps'] as List).map(CodeRunStep.parse).toList();
}

class CodeRunStep {
  CodeRunStep.parse(dynamic value) {
    if (value is! Map ||
        !['python', 'compiler', 'custom', 'program'].contains(value['tool']) ||
        value['arguments'] is! List ||
        (value['arguments'] as List).any((a) => a is! String) ||
        (value['tool'] == 'custom' && value['executable'] is! String)) {
      throw const FormatException(
        'Choose a tool and JSON argument array for each step.',
      );
    }
    data = Map<String, dynamic>.from(value);
    ToolCommand(
      tool == 'custom' ? data['executable'] as String? ?? '' : tool,
      arguments,
    );
  }
  late final Map<String, dynamic> data;
  String get tool => data['tool'] as String;
  List<String> get arguments => (data['arguments'] as List).cast<String>();
  ToolCommand command(Map<String, String> tools, String output, String cwd) =>
      ToolCommand(
        tool == 'program'
            ? output
            : tool == 'custom'
            ? data['executable'] as String
            : tools[tool] ?? '',
        arguments
            .map(
              (a) => a
                  .replaceAll('{output}', output)
                  .replaceAll('{buildDir}', p.dirname(output)),
            )
            .toList(),
        workingDirectory: cwd,
      );
}

abstract interface class CodeLaunchStore {
  Future<CodeLaunchSnapshot> load();
  Future<CodeLaunchSnapshot> save(
    CodeLaunchSnapshot expected,
    Map<String, dynamic> data,
  );
  Future<List<CodeLaunchSnapshot>> history();
}

abstract interface class CodeWebPreview {
  Uri get url;
  Stream<String> get events;
  void refresh();
  Future<void> stop();
}
