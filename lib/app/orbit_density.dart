import 'package:flutter/material.dart';

/// Geometry is independent of typography: compact mode saves space, not letters.
class OrbitDensity extends ThemeExtension<OrbitDensity> {
  const OrbitDensity({this.compact = false, this.scale = 1});
  final bool compact;
  final double scale;
  double get rowHeight => (compact ? 30 : 36) * scale;
  double get controlHeight => (compact ? 30 : 36) * scale;
  double get smallControl => (compact ? 28 : 32) * scale;
  double get cardPadding => (compact ? 10 : 14) * scale;
  double get sectionGap => (compact ? 18 : 24) * scale;
  double get icon => 18 * scale;
  double get tabWidth => (compact ? 188 : 220) * scale;
  double get boardColumn => (compact ? 272 : 304) * scale;
  static OrbitDensity of(BuildContext context) =>
      Theme.of(context).extension<OrbitDensity>() ?? const OrbitDensity();
  @override
  OrbitDensity copyWith({bool? compact, double? scale}) => OrbitDensity(
    compact: compact ?? this.compact,
    scale: scale ?? this.scale,
  );
  @override
  OrbitDensity lerp(covariant OrbitDensity? other, double t) => other == null
      ? this
      : OrbitDensity(
          compact: t < .5 ? compact : other.compact,
          scale: scale + (other.scale - scale) * t,
        );
}
