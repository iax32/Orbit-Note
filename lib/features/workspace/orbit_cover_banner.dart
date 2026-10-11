import 'package:flutter/material.dart';
import '../../app/orbit_theme.dart';

/// Reusable banner/cover component for Notes, Projects, Collections, and Home.
class OrbitCoverBanner extends StatelessWidget {
  const OrbitCoverBanner({
    super.key,
    required this.cover,
    this.heightPreset = 'standard',
    this.editable = false,
    this.onChangeCover,
    this.onRemoveCover,
    this.child,
  });

  final String? cover;
  final String heightPreset;
  final bool editable;
  final VoidCallback? onChangeCover;
  final VoidCallback? onRemoveCover;
  final Widget? child;

  static const coverPresets = [
    (
      'gradient:violet',
      'Violet Aurora',
      [Color(0xFF8B7CF6), Color(0xFF6366F1), Color(0xFF4C1D95)],
    ),
    (
      'gradient:sunset',
      'Sunset Glow',
      [Color(0xFFF97316), Color(0xFFEC4899), Color(0xFF8B5CF6)],
    ),
    (
      'gradient:ocean',
      'Ocean Deep',
      [Color(0xFF06B6D4), Color(0xFF3B82F6), Color(0xFF1E3A8A)],
    ),
    (
      'gradient:forest',
      'Forest Emerald',
      [Color(0xFF10B981), Color(0xFF059669), Color(0xFF064E3B)],
    ),
    (
      'gradient:amber',
      'Amber Horizon',
      [Color(0xFFF59E0B), Color(0xFFD97706), Color(0xFF78350F)],
    ),
    (
      'gradient:graphite',
      'Graphite Sleek',
      [Color(0xFF374151), Color(0xFF1F2937), Color(0xFF111827)],
    ),
  ];

  double get _height => switch (heightPreset) {
    'compact' => 80.0,
    'hero' => 190.0,
    _ => 130.0,
  };

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final hasCover = cover != null && cover!.trim().isNotEmpty;

    if (!hasCover && !editable) {
      return const SizedBox.shrink();
    }

    Widget content;
    if (hasCover) {
      final cov = cover!.trim();
      if (cov.startsWith('color:')) {
        final hexStr = cov.substring('color:'.length);
        final colorVal = int.tryParse(hexStr) ?? colors.panel.toARGB32();
        content = Container(
          height: _height,
          width: double.infinity,
          color: Color(colorVal),
        );
      } else {
        final match = coverPresets.where((p) => p.$1 == cov);
        final gradientColors = match.isNotEmpty
            ? match.first.$3
            : [
                colors.accent.withValues(alpha: 0.8),
                colors.panel,
                colors.background,
              ];
        content = Container(
          height: _height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
          ),
        );
      }
    } else {
      content = Container(
        height: 48,
        width: double.infinity,
        color: Colors.transparent,
      );
    }

    return Stack(
      children: [
        content,
        // Darken overlay for text contrast
        if (hasCover)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.45),
                  ],
                ),
              ),
            ),
          ),
        if (child != null)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: child!,
            ),
          ),
        if (editable)
          Positioned(
            top: 12,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasCover && onChangeCover != null)
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.55),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 28),
                    ),
                    onPressed: onChangeCover,
                    icon: const Icon(Icons.image_outlined, size: 14),
                    label: const Text(
                      'Change cover',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                if (!hasCover && onChangeCover != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: colors.subtle,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 28),
                    ),
                    onPressed: onChangeCover,
                    icon: const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 14,
                    ),
                    label: const Text(
                      'Add cover',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                if (hasCover && onRemoveCover != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.55),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(28, 28),
                    ),
                    tooltip: 'Remove cover',
                    onPressed: onRemoveCover,
                    icon: const Icon(Icons.close, size: 14),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
