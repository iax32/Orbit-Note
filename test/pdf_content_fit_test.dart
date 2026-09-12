import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/pdf/pdf_content_fit.dart';

void main() {
  test(
    'content fitting retains image colors and edge marks with conservative padding',
    () {
      final pixels = Uint8List(100 * 100 * 4)..fillRange(0, 40000, 255);
      void mark(int x, int y) {
        pixels[(y * 100 + x) * 4] = 0;
      }

      mark(40, 50);
      mark(60, 50);
      expect(
        pdfContentWidth(pixels, 100, 100),
        const Rect.fromLTRB(.2, 0, .8, 1),
      );
      mark(99, 80);
      expect(pdfContentWidth(pixels, 100, 100).right, 1);
      mark(0, 10);
      expect(
        pdfContentWidth(pixels, 100, 100),
        const Rect.fromLTWH(0, 0, 1, 1),
      );
    },
  );
  test('blank and invalid previews safely use the full page', () {
    final white = Uint8List(400)..fillRange(0, 400, 255);
    expect(pdfContentWidth(white, 10, 10), const Rect.fromLTWH(0, 0, 1, 1));
    expect(
      pdfContentWidth(Uint8List(0), 10, 10),
      const Rect.fromLTWH(0, 0, 1, 1),
    );
  });
}
