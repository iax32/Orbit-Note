import 'dart:async';
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

Future<Rect> measurePdfContentWidth(
  PdfPage page, {
  PdfPageRenderCancellationToken? cancellationToken,
}) async {
  final scale = 640 / (page.width > page.height ? page.width : page.height);
  final image = await page.render(
    fullWidth: (page.width * scale).clamp(1, 640),
    fullHeight: (page.height * scale).clamp(1, 640),
    backgroundColor: 0xffffffff,
    cancellationToken: cancellationToken,
  );
  if (image == null) return const Rect.fromLTWH(0, 0, 1, 1);
  try {
    return pdfContentWidth(image.pixels, image.width, image.height);
  } finally {
    image.dispose();
  }
}

typedef PdfWidthMeasure =
    Future<Rect> Function(PdfPage page, PdfPageRenderCancellationToken token);

class _WidthRequest {
  _WidthRequest(this.page);
  final PdfPage page;
  final result = Completer<Rect?>();
  PdfPageRenderCancellationToken? token;
  bool retired = false;
  Object get key =>
      (page.document, page.pageNumber, page.width, page.height, page.rotation);
}

/// Comfort fitting must not enqueue a native raster job for every page crossed
/// while scrolling. One running job and one latest destination are retained;
/// completed measurements use a bounded LRU, scoped to document identity.
class PdfContentWidthCache {
  PdfContentWidthCache({this.capacity = 32, PdfWidthMeasure? measure})
    : assert(capacity > 0),
      _measure =
          measure ??
          ((page, token) =>
              measurePdfContentWidth(page, cancellationToken: token));
  final int capacity;
  final PdfWidthMeasure _measure;
  final _completed = <Object, Rect>{};
  _WidthRequest? _active, _pending;
  bool _disposed = false;
  int get cachedPages => _completed.length;

  Future<Rect?> measure(PdfPage page) {
    if (_disposed) return Future.value(null);
    final request = _WidthRequest(page);
    final cached = _completed.remove(request.key);
    if (cached != null) {
      cancel();
      _completed[request.key] = cached;
      return Future.value(cached);
    }
    if (_active?.key == request.key && !_active!.retired) {
      return _active!.result.future;
    }
    if (_pending?.key == request.key) return _pending!.result.future;
    cancel();
    _pending = request;
    _drain();
    return request.result.future;
  }

  void cancel() {
    final active = _active;
    if (active != null) {
      active.retired = true;
      active.token?.cancel();
    }
    _pending?.result.complete(null);
    _pending = null;
  }

  void clear() {
    cancel();
    _completed.clear();
  }

  void dispose() {
    _disposed = true;
    clear();
  }

  Future<void> _drain() async {
    if (_active != null || _pending == null || _disposed) return;
    final request = _pending!;
    _pending = null;
    _active = request;
    try {
      final token = request.token = request.page.createCancellationToken();
      final result = await _measure(request.page, token);
      if (request.retired || _disposed) {
        request.result.complete(null);
      } else {
        _completed[request.key] = result;
        while (_completed.length > capacity) {
          _completed.remove(_completed.keys.first);
        }
        request.result.complete(result);
      }
    } catch (error, stack) {
      if (request.retired || _disposed) {
        request.result.complete(null);
      } else {
        // Failures are not cached: retrying the same page can recover.
        request.result.completeError(error, stack);
      }
    } finally {
      _active = null;
      unawaited(_drain());
    }
  }
}
