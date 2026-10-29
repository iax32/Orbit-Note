import 'dart:convert';
import 'dart:typed_data';

const supportsCollaborationCompression = false;

Uint8List encodeCollaborationPayload((Object, bool) request) =>
    utf8.encode(jsonEncode(request.$1));
