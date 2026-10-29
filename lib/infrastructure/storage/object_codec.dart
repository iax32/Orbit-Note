import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../../domain/universal_object.dart';
import '../../domain/workspace_failure.dart';
import 'object_encoding_execution.dart';
import 'object_encoding_types.dart';
export 'object_encoding_types.dart' show ObjectEncoding;

typedef ObjectDecoding = ({String source, UniversalObject object});
typedef SyncObjectHeader = ({
  String id,
  String typeId,
  bool readOnly,
  String? attachmentPath,
  String? attachmentHash,
});

SyncObjectHeader objectSyncHeader(UniversalObject object) => (
  id: object.id,
  typeId: object.typeId,
  readOnly: object.isReadOnly,
  attachmentPath: object.properties['contentRef'] is String
      ? object.properties['contentRef'] as String
      : null,
  attachmentHash: object.properties['checksum'] is String
      ? object.properties['checksum'] as String
      : null,
);

UniversalObject _decodeSeed(String source, String workspace) =>
    ObjectCodec().decode(source, workspace, markdown: false);

ObjectEncoding _encodeForSave(UniversalObject object, String? previousSource) {
  // Markdown omits data in its owning file, but unsupported runtime values in
  // that field must still be rejected just as in structured object saves.
  if (object.typeId == 'orbit.note') jsonEncode(object.data);
  final source = ObjectCodec().encode(object, previousSource: previousSource);
  final bytes = Uint8List.fromList(utf8.encode(source));
  return (source: source, bytes: bytes, hash: sha256.convert(bytes).toString());
}

class ObjectCodec {
  late final _saveExecutor = createObjectSaveExecutor(
    _encodeForSave,
    _decodeSeed,
  );
  Future<void> close() => _saveExecutor.close();
  static final _frontmatter = RegExp(r'^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)');

  Future<String> hashBytes(Uint8List bytes) => runObjectEncoding(
    () => sha256.convert(bytes).toString(),
    size: bytes.length,
  );

  /// Sync needs identity/attachment metadata, not a second full scene graph on
  /// the UI heap every polling cycle. Decode/validate on the worker and return
  /// only the header; normal object loading still retains the complete data.
  Future<SyncObjectHeader> inspectForSync(
    Uint8List bytes,
    String workspaceId, {
    required bool markdown,
  }) => runObjectEncoding(
    () => objectSyncHeader(
      ObjectCodec().decode(utf8.decode(bytes), workspaceId, markdown: markdown),
    ),
    size: bytes.length,
  );

  Future<ObjectDecoding> decodeForLoad(
    Uint8List bytes,
    String workspaceId, {
    required bool markdown,
  }) => runObjectEncoding(() {
    final source = utf8.decode(bytes);
    return (
      source: source,
      object: ObjectCodec().decode(source, workspaceId, markdown: markdown),
    );
  }, size: bytes.length);

  Future<ObjectEncoding> encodeForSave(
    UniversalObject object, {
    UniversalObject? previousObject,
    String? previousSource,
  }) {
    // Estimate using array lengths only, without traversing every point just to
    // decide whether to move encoding off the UI thread. Small saves stay cheap.
    var size = previousSource?.length ?? object.body.length;
    final elements = object.data['elements'];
    if (elements is List) {
      size += elements.length * 256;
      for (final element in elements) {
        if (size >= 65536) break;
        final points = element is Map ? element['points'] : null;
        if (points is List) size += points.length * 64;
      }
    }
    return _saveExecutor.encode(
      object,
      previousObject: previousObject,
      previousSource: previousSource,
      size: size,
    );
  }

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
