import 'dart:convert';
import 'dart:typed_data';

Future<Uint8List> encodeSharedCheckpoint(Map<String, dynamic> state) async =>
    Uint8List.fromList(utf8.encode(jsonEncode(state)));
Future<Map<String, dynamic>> decodeSharedCheckpoint(Uint8List bytes) async =>
    jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
