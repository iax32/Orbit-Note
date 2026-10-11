import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<bool> writeRichClipboard(String plainText, String html) async {
  // Invoke write before the first await to retain the user's copy gesture.
  // Unsupported or permission-denied writes are handled by the caller's
  // plain-text fallback; never request clipboard reads to perform a copy.
  final item = web.ClipboardItem(
    {
          'text/plain': web.Blob(
            [plainText.toJS].toJS,
            web.BlobPropertyBag(type: 'text/plain'),
          ),
          'text/html': web.Blob(
            [html.toJS].toJS,
            web.BlobPropertyBag(type: 'text/html'),
          ),
        }.jsify()!
        as JSObject,
  );
  await web.window.navigator.clipboard.write([item].toJS).toDart;
  return true;
}
