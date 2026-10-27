import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<bool> exportFile(
  String name,
  String content, {
  String mimeType = 'application/json',
  bool Function()? isCancelled,
  void Function(int completed, int total)? onProgress,
}) async {
  if (isCancelled?.call() == true) return false;
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body?.append(anchor);
  anchor.click();
  onProgress?.call(content.length, content.length);
  anchor.remove();
  Future<void>.delayed(
    const Duration(seconds: 5),
    () => web.URL.revokeObjectURL(url),
  );
  return true;
}

Future<bool> exportBinaryFile(
  String name,
  Uint8List bytes, {
  String mimeType = 'application/octet-stream',
  bool Function()? isCancelled,
  void Function(int completed, int total)? onProgress,
}) async {
  if (isCancelled?.call() == true) return false;
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body?.append(anchor);
  anchor.click();
  onProgress?.call(bytes.length, bytes.length);
  anchor.remove();
  Future<void>.delayed(
    const Duration(seconds: 5),
    () => web.URL.revokeObjectURL(url),
  );
  return true;
}
