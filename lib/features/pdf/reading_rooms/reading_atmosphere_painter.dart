import 'package:flutter/material.dart';
import 'reading_room_model.dart';

/// Quiet, ambient lighting backdrop for virtual reading rooms.
///
/// Provides a subtle, stationary ambient light wash around the margins
/// of the reading viewport that reflects the selected reading environment
/// without distracting motion or competing with document content.
class ReadingAtmosphere extends StatelessWidget {
  const ReadingAtmosphere({super.key, required this.room, this.child});

  final ReadingRoom room;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AtmospherePainter(room: room),
      child: child,
    );
  }
}

class _AtmospherePainter extends CustomPainter {
  const _AtmospherePainter({required this.room});

  final ReadingRoom room;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // 1. Base graphite backdrop
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.2),
        radius: 1.25,
        colors: [
          room.primaryTone,
          room.primaryTone.withValues(alpha: 0.95),
          const Color(0xFF0F1014),
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 2. Quiet, restrained lighting washes per environment
    switch (room.atmosphereType) {
      case RoomAtmosphereType.rain:
        _paintRainAtmosphere(canvas, size);
      case RoomAtmosphereType.fireplace:
        _paintFireplaceAtmosphere(canvas, size);
      case RoomAtmosphereType.midnight:
        _paintMidnightAtmosphere(canvas, size);
      case RoomAtmosphereType.train:
        _paintTrainAtmosphere(canvas, size);
      case RoomAtmosphereType.forest:
        _paintForestAtmosphere(canvas, size);
      case RoomAtmosphereType.cafe:
        _paintCafeAtmosphere(canvas, size);
    }
  }

  void _paintRainAtmosphere(Canvas canvas, Size size) {
    // Subtle cool rain-slate wash across the left perimeter
    final coolWash = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.85, -0.6),
        radius: 1.0,
        colors: [room.accentTone.withValues(alpha: 0.08), Colors.transparent],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, coolWash);

    // Warm quiet reading lamp glow in the top-right
    final lampGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.8, -0.85),
        radius: 0.75,
        colors: [
          const Color(0xFFFDE68A).withValues(alpha: 0.07),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, lampGlow);
  }

  void _paintFireplaceAtmosphere(Canvas canvas, Size size) {
    // Soft, warm hearth ambient wash resting at the bottom margin
    final hearthGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, 1.0),
        radius: 0.85,
        colors: [
          room.accentTone.withValues(alpha: 0.10),
          room.accentTone.withValues(alpha: 0.03),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, hearthGlow);
  }

  void _paintMidnightAtmosphere(Canvas canvas, Size size) {
    // Quiet observatory violet wash along the top horizon
    final horizonWash = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.9),
        radius: 0.95,
        colors: [room.accentTone.withValues(alpha: 0.08), Colors.transparent],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, horizonWash);
  }

  void _paintTrainAtmosphere(Canvas canvas, Size size) {
    // Subtle dusk twilight wash across the lower third
    final duskWash = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          room.accentTone.withValues(alpha: 0.05),
          room.accentTone.withValues(alpha: 0.08),
        ],
        stops: const [0.55, 0.85, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, duskWash);
  }

  void _paintForestAtmosphere(Canvas canvas, Size size) {
    // Quiet woodland sage-green peripheral wash
    final forestWash = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.7, 0.7),
        radius: 0.9,
        colors: [room.accentTone.withValues(alpha: 0.07), Colors.transparent],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, forestWash);
  }

  void _paintCafeAtmosphere(Canvas canvas, Size size) {
    // Warm caramel bistro lamp glow
    final cafeGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.7, -0.7),
        radius: 0.8,
        colors: [room.accentTone.withValues(alpha: 0.08), Colors.transparent],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, cafeGlow);
  }

  @override
  bool shouldRepaint(covariant _AtmospherePainter oldDelegate) {
    return oldDelegate.room.id != room.id;
  }
}
