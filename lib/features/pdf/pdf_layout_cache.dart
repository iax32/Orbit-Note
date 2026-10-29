import 'dart:ui';
import 'package:pdfrx/pdfrx.dart';

/// Memoize exact geometry, not estimated page sizes. Every dimension is checked
/// so equal page counts, in-place metadata updates and mixed sizes remain safe.
class PdfPageLayoutCache {
  List<Size> _sizes = const [];
  Object? _mode;
  double? _margin;
  PdfPageLayout? _layout;
  PdfPageLayout resolve(
    List<PdfPage> pages, {
    required Object mode,
    required double margin,
    required PdfPageLayout Function() build,
  }) {
    if (_layout != null &&
        _mode == mode &&
        _margin == margin &&
        pages.length == _sizes.length) {
      var same = true;
      for (var i = 0; i < pages.length; i++) {
        if (_sizes[i].width != pages[i].width ||
            _sizes[i].height != pages[i].height) {
          same = false;
          break;
        }
      }
      if (same) return _layout!;
    }
    final layout = build();
    _sizes = [for (final page in pages) Size(page.width, page.height)];
    _mode = mode;
    _margin = margin;
    _layout = layout;
    return layout;
  }

  void clear() {
    _sizes = const [];
    _layout = null;
    _mode = null;
    _margin = null;
  }
}
