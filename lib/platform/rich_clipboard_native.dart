import 'package:flutter/services.dart';

const _channel = MethodChannel('orbit_note/clipboard');

Future<bool> writeRichClipboard(String plainText, String html) async =>
    await _channel.invokeMethod<bool>('setRichText', {
      'plainText': plainText,
      'html': html,
    }) ==
    true;
