import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:orbit_note/features/pdf/pdf_layout_cache.dart';

class _Page extends Fake implements PdfPage {
  _Page(this.width, this.height);
  @override
  final double width;
  @override
  final double height;
}

void main() {
  test(
    'exact layout reuse checks all page dimensions, mode, margin and reset',
    () {
      final cache = PdfPageLayoutCache();
      final pages = <PdfPage>[
        for (var i = 0; i < 1000; i++) _Page(500, i.isEven ? 700 : 900),
      ];
      var builds = 0;
      PdfPageLayout layout() {
        builds++;
        return PdfPageLayout(
          pageLayouts: [
            for (final page in pages)
              Rect.fromLTWH(0, 0, page.width, page.height),
          ],
          documentSize: const Size(500, 900000),
        );
      }

      final first = cache.resolve(
        pages,
        mode: 'continuous',
        margin: 8,
        build: layout,
      );
      for (var i = 0; i < 100; i++) {
        expect(
          identical(
            cache.resolve(pages, mode: 'continuous', margin: 8, build: layout),
            first,
          ),
          isTrue,
        );
      }
      expect(builds, 1);
      pages[999] = _Page(600, 1000);
      final changed = cache.resolve(
        pages,
        mode: 'continuous',
        margin: 8,
        build: layout,
      );
      expect(identical(changed, first), isFalse);
      expect(changed.pageLayouts.last.size, const Size(600, 1000));
      cache.resolve(pages, mode: 'single', margin: 8, build: layout);
      cache.resolve(pages, mode: 'single', margin: 16, build: layout);
      expect(builds, 4);
      cache.clear();
      cache.resolve(pages, mode: 'single', margin: 16, build: layout);
      expect(builds, 5);
    },
  );
}
