import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../../application/search_execution.dart';
import '../../domain/orbit_search.dart';

/// Image matches are drawn only after checking the displayed byte snapshot.
class OcrImageHighlight extends StatelessWidget {
  const OcrImageHighlight({
    super.key,
    required this.bytes,
    required this.match,
    required this.image,
  });
  final Uint8List bytes;
  final OrbitSearchResult? match;
  final Widget image;
  @override
  Widget build(BuildContext context) {
    if (match == null || match!.sourceRegions.isEmpty) return image;
    return FutureBuilder<bool>(
      future: runSearchWork(
        () => sha256.convert(bytes).toString() == match!.sourceChecksum,
        size: bytes.length,
      ),
      builder: (context, snapshot) => Stack(
        children: [
          image,
          if (snapshot.data == true)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _Regions(
                    match!.sourceRegions,
                    Theme.of(context).colorScheme.primary.withValues(alpha: .3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Regions extends CustomPainter {
  _Regions(this.regions, this.color);
  final List<Map<String, double>> regions;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    for (final r in regions) {
      canvas.drawRect(
        Rect.fromLTWH(
          r['x']! * size.width,
          r['y']! * size.height,
          r['width']! * size.width,
          r['height']! * size.height,
        ),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Regions old) =>
      old.regions != regions || old.color != color;
}
