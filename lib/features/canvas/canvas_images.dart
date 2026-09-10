import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

class CanvasImageReference {
  const CanvasImageReference({
    required this.contentRef,
    this.title = 'Image',
    this.width = 320,
    this.height = 240,
  });
  final String contentRef;
  final String title;
  final double width;
  final double height;
}

/// Only visible images are requested; decoded memory is bounded independently of
/// full attachment size. Source bytes and filesystem ownership stay in storage.
class CanvasImageCache {
  CanvasImageCache({required this.loader, required this.onChanged});
  final Future<Uint8List?> Function(String contentRef) loader;
  final VoidCallback onChanged;
  final LinkedHashMap<String, ui.Image> _images = LinkedHashMap();
  final Set<String> _pending = {};
  final Set<String> _failed = {};
  bool _disposed = false;
  Set<String> _wanted = {};

  /// Admit a stable bounded working set. Excess visible images retain their
  /// placeholders rather than repeatedly evicting and decoding each other.
  void updateVisible(Iterable<String> references) {
    _wanted = references.toSet().take(24).toSet();
    _failed.removeWhere((ref) => !_wanted.contains(ref));
    for (final ref in _wanted) {
      ensure(ref);
    }
  }

  Map<String, ui.Image> get images => Map.unmodifiable(_images);

  Future<void> ensure(String reference) async {
    if (_disposed ||
        !_wanted.contains(reference) ||
        _pending.contains(reference) ||
        _failed.contains(reference)) {
      return;
    }
    final existing = _images.remove(reference);
    if (existing != null) {
      _images[reference] = existing;
      return;
    }
    if (_pending.length >= 4) return;
    _pending.add(reference);
    try {
      final bytes = await loader(reference);
      if (_disposed) return;
      if (bytes == null) {
        _failed.add(reference);
        return;
      }
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final factor =
          1024 /
          (descriptor.width > descriptor.height
              ? descriptor.width
              : descriptor.height);
      final codec = await descriptor.instantiateCodec(
        targetWidth: factor < 1
            ? (descriptor.width * factor).round().clamp(1, 1024)
            : descriptor.width,
        targetHeight: factor < 1
            ? (descriptor.height * factor).round().clamp(1, 1024)
            : descriptor.height,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
      if (_disposed || !_wanted.contains(reference)) {
        frame.image.dispose();
        return;
      }
      _images[reference] = frame.image;
      while (_images.length > 24) {
        _images.remove(_images.keys.first)?.dispose();
      }
    } catch (_) {
      // Missing/unsupported images retain their ordinary attachment reference.
      if (!_disposed) _failed.add(reference);
    } finally {
      _pending.remove(reference);
      if (!_disposed) onChanged();
    }
  }

  void dispose() {
    _disposed = true;
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
  }
}
