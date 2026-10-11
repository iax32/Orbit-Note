import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:pdfrx/pdfrx.dart';
import 'local_ocr.dart';

typedef OcrPageExtractor =
    Stream<Map<String, dynamic>> Function(Uint8List bytes, bool pdf);

/// Serial, bounded page rendering; buffers are released before the next page.
Stream<Map<String, dynamic>> recognizeAttachment(
  Uint8List bytes,
  bool pdf,
) async* {
  if (!pdf) {
    yield await recognizeLocalImage(bytes);
    return;
  }
  await pdfrxFlutterInitialize();
  final document = await PdfDocument.openData(bytes);
  try {
    if (document.permissions?.allowsCopying == false) {
      throw UnsupportedError('This PDF does not permit text copying.');
    }
    if (document.pages.length > 500) {
      throw StateError('Recognition supports up to 500 pages per file.');
    }
    for (final page in document.pages) {
      final scale = math.min(3.0, 2600 / math.max(page.width, page.height));
      final rendered = await page.render(
        fullWidth: page.width * scale,
        fullHeight: page.height * scale,
        backgroundColor: 0xffffffff,
      );
      if (rendered == null) {
        throw StateError('Page ${page.pageNumber} could not be rendered.');
      }
      try {
        final image = await rendered.createImage();
        try {
          final encoded = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (encoded == null) throw StateError('Page encoding failed.');
          yield {
            ...await recognizeLocalImage(encoded.buffer.asUint8List()),
            'total': document.pages.length,
          };
        } finally {
          image.dispose();
        }
      } finally {
        rendered.dispose();
      }
    }
  } finally {
    await document.dispose();
  }
}
