import 'dart:typed_data';
import 'dart:ui';
import 'package:pdfrx/pdfrx.dart';

/// Fits visible page content, not just text. Never modifies or clips the PDF.
/// Conservative limits retain faint edge details missed by the small preview.
Rect pdfContentWidth(Uint8List bgra, int width, int height) {
  const full = Rect.fromLTWH(0, 0, 1, 1);
  if (width < 1 || height < 1 || bgra.length != width * height * 4) return full;
  var left = width, right = -1;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      if (bgra[i + 3] > 16 &&
          (bgra[i] < 250 || bgra[i + 1] < 250 || bgra[i + 2] < 250)) {
        if (x < left) left = x;
        if (x > right) right = x;
      }
    }
  }
  if (right < left) return full;
  final start = (left / width - .03).clamp(0.0, .20);
  final end = ((right + 1) / width + .03).clamp(.80, 1.0);
  return Rect.fromLTRB(start, 0, end, 1);
}

Future<Rect> measurePdfContentWidth(PdfPage page) async {
  final scale = 640 / (page.width > page.height ? page.width : page.height);
  final image = await page.render(
    fullWidth: (page.width * scale).clamp(1, 640),
    fullHeight: (page.height * scale).clamp(1, 640),
    backgroundColor: 0xffffffff,
  );
  if (image == null) return const Rect.fromLTWH(0, 0, 1, 1);
  try {
    return pdfContentWidth(image.pixels, image.width, image.height);
  } finally {
    image.dispose();
  }
}
