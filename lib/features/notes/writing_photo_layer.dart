import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../app/orbit_theme.dart';
import '../../domain/writing_photo.dart';

typedef WritingPhotoLoader = Future<Uint8List?> Function(String id);

/// Conservative bound for ink against either a completely white or black photo.
double readablePhotoOpacity(ThemeData theme) {
  final scheme = theme.colorScheme;
  final colors = [scheme.onSurface, scheme.onSurfaceVariant, scheme.primary];
  final targets = [
    for (final color in colors)
      OrbitContrast.ratio(color, scheme.surface).clamp(1.0, 4.5),
  ];
  bool safe(double opacity) {
    for (final extreme in [Colors.white, Colors.black]) {
      final backdrop = Color.alphaBlend(
        extreme.withValues(alpha: opacity),
        scheme.surface,
      );
      for (var i = 0; i < colors.length; i++) {
        if (OrbitContrast.ratio(colors[i], backdrop) + .00001 < targets[i]) {
          return false;
        }
      }
    }
    return true;
  }

  var low = 0.0, high = 1.0;
  for (var i = 0; i < 18; i++) {
    final middle = (low + high) / 2;
    if (safe(middle)) {
      low = middle;
    } else {
      high = middle;
    }
  }
  return (low - .002).clamp(0.0, 1.0);
}

class WritingPhotoLayer extends StatefulWidget {
  const WritingPhotoLayer({
    super.key,
    required this.photo,
    required this.opacity,
    this.bytes,
    this.loader,
    this.owner,
    this.retry = 0,
    this.onFailure,
  });
  final WritingPhoto photo;
  final double opacity;
  final Uint8List? bytes;
  final WritingPhotoLoader? loader;
  final Object? owner;
  final int retry;
  final ValueChanged<bool>? onFailure;
  @override
  State<WritingPhotoLayer> createState() => _WritingPhotoLayerState();
}

class _WritingPhotoLayerState extends State<WritingPhotoLayer> {
  Uint8List? _bytes;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(WritingPhotoLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.id != widget.photo.id ||
        oldWidget.owner != widget.owner ||
        oldWidget.retry != widget.retry ||
        !identical(oldWidget.bytes, widget.bytes)) {
      _load();
    }
  }

  void _notify(bool failed, int generation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _generation) widget.onFailure?.call(failed);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _bytes = null;
    _notify(false, generation);
    try {
      final data = widget.bytes ?? await widget.loader?.call(widget.photo.id);
      if (!mounted || generation != _generation) return;
      if (data == null) {
        _notify(true, generation);
        return;
      }
      validateWritingPhotoBytes(data);
      setState(() => _bytes = data);
    } on Object {
      if (mounted && generation == _generation) _notify(true, generation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) return const SizedBox.expand();
    final generation = _generation;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Opacity(
          opacity: widget.opacity,
          child: Image.memory(
            bytes,
            key: ValueKey((widget.photo.id, widget.owner, generation)),
            fit: widget.photo.contain ? BoxFit.contain : BoxFit.cover,
            alignment: Alignment(widget.photo.x, widget.photo.y),
            filterQuality: FilterQuality.medium,
            gaplessPlayback: false,
            errorBuilder: (context, error, stack) {
              _notify(true, generation);
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
  }
}
