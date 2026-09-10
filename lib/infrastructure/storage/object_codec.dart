import 'dart:convert';

import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../../domain/universal_object.dart';
import '../../domain/workspace_failure.dart';

class ObjectCodec {
  static final _frontmatter = RegExp(r'^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)');

  UniversalObject decode(
    String text,
    String workspaceId, {
    required bool markdown,
  }) {
    if (markdown) {
      final match = _frontmatter.firstMatch(text);
      if (match == null) {
        throw const FormatException(
          'Markdown has no Orbit identity. Import/adoption is required before editing.',
        );
      }
      final header = _plain(loadYaml(match.group(1)!)) as Map<String, dynamic>;
      final envelope = Map<String, dynamic>.from(header['orbit'] as Map);
      envelope['properties'] = header['properties'] ?? <String, dynamic>{};
      return UniversalObject.fromJson(
        envelope,
        workspaceId: workspaceId,
        body: text.substring(match.end),
        documentExtra: {...header}
          ..remove('orbit')
          ..remove('properties'),
      );
    }
    final record = jsonDecode(text) as Map<String, dynamic>;
    if (!{
      'orbit-note-object',
      'orbit-note-board',
      'orbit-note-drawing',
    }.contains(record['format'])) {
      throw const FormatException(
        'This object format is unsupported. Its file is unchanged.',
      );
    }
    return UniversalObject.fromJson(
      Map<String, dynamic>.from(record['object'] as Map),
      workspaceId: workspaceId,
      body: record['body'] as String? ?? '',
      data: Map<String, dynamic>.from(record['data'] as Map? ?? {}),
      formatVersion: record['version'] as int,
      documentExtra: {...record}
        ..removeWhere(
          (key, _) =>
              {'format', 'version', 'object', 'body', 'data'}.contains(key),
        ),
    );
  }

  String encode(UniversalObject object, {String? previousSource}) {
    if (object.isReadOnly) {
      throw const WorkspaceReadOnly(
        'A newer object format cannot be overwritten by this version of Orbit Note.',
      );
    }
    final envelope = object.toJson()..remove('workspaceId');
    if (object.typeId == 'orbit.note') {
      envelope.remove('properties');
      final previous = previousSource == null
          ? null
          : _frontmatter.firstMatch(previousSource);
      final editor = YamlEditor(previous?.group(1) ?? '{}');
      final old = previous == null
          ? <String, dynamic>{}
          : _plain(loadYaml(previous.group(1)!)) as Map<String, dynamic>;
      if (old['orbit'] is! Map) editor.update(['orbit'], <String, dynamic>{});
      for (final entry in envelope.entries) {
        if (jsonEncode((old['orbit'] as Map?)?[entry.key]) !=
            jsonEncode(entry.value)) {
          editor.update(['orbit', entry.key], entry.value);
        }
      }
      if (jsonEncode(old['properties']) != jsonEncode(object.properties)) {
        editor.update(['properties'], object.properties);
      }
      if (previous == null) {
        for (final entry in object.documentExtra.entries) {
          editor.update([entry.key], entry.value);
        }
      }
      return '---\n${editor.toString().trimRight()}\n---\n${object.body}';
    }
    return '${const JsonEncoder.withIndent('  ').convert({...object.documentExtra, 'format': object.typeId == 'orbit.canvas'
        ? 'orbit-note-board'
        : object.typeId == 'orbit.drawing'
        ? 'orbit-note-drawing'
        : 'orbit-note-object', 'version': object.formatVersion, 'object': envelope, 'body': object.body, 'data': object.data})}\n';
  }

  dynamic _plain(dynamic value, [int depth = 0]) {
    if (depth > 40) {
      throw const FormatException('YAML nesting exceeds the safe limit.');
    }
    if (value is Map) {
      return value.map((key, child) {
        if (key is! String) {
          throw const FormatException('Metadata keys must be strings.');
        }
        return MapEntry(key, _plain(child, depth + 1));
      });
    }
    if (value is List) {
      return value.map((child) => _plain(child, depth + 1)).toList();
    }
    return value;
  }
}
