import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Tiny5 has a 128-unit pixel cell in a 1024-unit em. Render its cells at
/// whole display pixels, after composing app zoom and OS text scaling.
/// This changes text layout, never bitmap-scales text or changes the viewport.
class PixelFontTextScaler extends TextScaler {
  const PixelFontTextScaler(this.base, this.devicePixelRatio);
  final TextScaler base;
  final double devicePixelRatio;

  @override
  double scale(double fontSize) {
    final scaled = base.scale(fontSize);
    if (scaled <= 0 || !scaled.isFinite) return scaled;
    final ratio = devicePixelRatio.isFinite && devicePixelRatio > 0
        ? devicePixelRatio
        : 1.0;
    return math.max(8.0, (scaled * ratio / 8).round() * 8.0) / ratio;
  }

  @override
  double get textScaleFactor => scale(14) / 14;
  @override
  bool operator ==(Object other) =>
      other is PixelFontTextScaler &&
      other.base == base &&
      other.devicePixelRatio == devicePixelRatio;
  @override
  int get hashCode => Object.hash(base, devicePixelRatio);
}

/// Keep the same subtree while switching designs or the continuous-size option.
class PixelFontScope extends StatelessWidget {
  const PixelFontScope({super.key, required this.enabled, required this.child});
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final current = media.textScaler;
    final base = current is PixelFontTextScaler ? current.base : current;
    return MediaQuery(
      data: media.copyWith(
        textScaler: enabled
            ? PixelFontTextScaler(base, media.devicePixelRatio)
            : base,
      ),
      child: child,
    );
  }
}
