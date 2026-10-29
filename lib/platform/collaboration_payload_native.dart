import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const supportsCollaborationCompression = true;

Uint8List encodeCollaborationPayload((Object, bool) request) {
  final bytes = utf8.encode(jsonEncode(request.$1));
  return request.$2 ? Uint8List.fromList(gzip.encode(bytes)) : bytes;
}
