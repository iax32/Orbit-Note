import 'package:flutter/services.dart';

const _channel = MethodChannel('orbit_note/ocr');

/// Native engines receive only image bytes, with no network or Vault path access.
Future<Map<String, dynamic>> recognizeLocalImage(Uint8List bytes) async {
  try {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'recognize',
      bytes,
    );
    if (result == null) throw StateError('Recognition returned no result.');
    return result;
  } on MissingPluginException {
    throw UnsupportedError(
      'Local recognition is available on Windows. Saved recognition and corrections remain readable on this platform.',
    );
  }
}
