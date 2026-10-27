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
  final Map<String, int> _generations = {};
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
  Set<String> get failedReferences => Set.unmodifiable(_failed);

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
    final generation = _generations[reference] ?? 0;
    var stale = false;
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      final bytes = await loader(reference);
      stale = generation != (_generations[reference] ?? 0);
      if (stale) return;
      if (_disposed) return;
      if (bytes == null) {
        _failed.add(reference);
        return;
      }
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final factor =
          1024 /
          (descriptor.width > descriptor.height
              ? descriptor.width
              : descriptor.height);
      codec = await descriptor.instantiateCodec(
        targetWidth: factor < 1
            ? (descriptor.width * factor).round().clamp(1, 1024)
            : descriptor.width,
        targetHeight: factor < 1
            ? (descriptor.height * factor).round().clamp(1, 1024)
            : descriptor.height,
      );
      final frame = await codec.getNextFrame();
      stale = generation != (_generations[reference] ?? 0);
      if (_disposed || !_wanted.contains(reference) || stale) {
        frame.image.dispose();
        return;
      }
      _images[reference] = frame.image;
      while (_images.length > 24) {
        _images.remove(_images.keys.first)?.dispose();
      }
    } catch (_) {
      // Missing/unsupported images retain their ordinary attachment reference.
      stale = generation != (_generations[reference] ?? 0);
      if (!_disposed && !stale) _failed.add(reference);
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
      _pending.remove(reference);
      if (stale && !_disposed && _wanted.contains(reference)) {
        // A replacement landed while the old decode was in flight. Schedule
        // one fresh read after releasing the pending slot.
        Future<void>.microtask(() => ensure(reference));
      }
      if (!_disposed) onChanged();
    }
  }

  /// Drop decoded and failed entries so a replaced attachment cannot leave a
  /// stale preview visible. In-flight decodes are fenced by a generation token.
  void invalidate(String reference) {
    _generations[reference] = (_generations[reference] ?? 0) + 1;
    _images.remove(reference)?.dispose();
    _failed.remove(reference);
    if (!_disposed && _wanted.contains(reference)) {
      ensure(reference);
      onChanged();
    }
  }

  /// Invalidate every currently visible/decoded attachment. The workspace
  /// controller batches native watcher events, so this remains cheap while
  /// guaranteeing replacement for references that changed during a batch.
  void invalidateAll() {
    final references = {..._wanted, ..._images.keys, ..._failed};
    for (final reference in references) {
      _generations[reference] = (_generations[reference] ?? 0) + 1;
      _images.remove(reference)?.dispose();
      _failed.remove(reference);
    }
    if (_disposed) return;
    for (final reference in _wanted) {
      ensure(reference);
    }
    onChanged();
  }

  void dispose() {
    _disposed = true;
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    _generations.clear();
  }
}
