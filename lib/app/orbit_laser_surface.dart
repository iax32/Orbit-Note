import 'package:flutter/material.dart';
import 'orbit_components.dart';
import 'orbit_theme.dart';

/// Ephemeral, bounded screen-space presentation pointer. Never creates ink,
/// objects, history entries, clipboard content or collaboration mutations.
class OrbitLaserSurface extends StatefulWidget {
  const OrbitLaserSurface({super.key});
  @override
  State<OrbitLaserSurface> createState() => _OrbitLaserSurfaceState();
}

class _OrbitLaserSurfaceState extends State<OrbitLaserSurface>
    with SingleTickerProviderStateMixin {
  late final fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    value: 1,
  );
  final points = <Offset>[];
  int? pointer;
  void add(Offset p) {
    points.add(p);
    if (points.length > 160) points.removeAt(0);
    if (OrbitMotionScope.isOff(context) ||
        OrbitMotionScope.isReduced(context)) {
      fade.stop();
      fade.value = 0;
      setState(() {});
    } else {
      fade.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (OrbitMotionScope.isOff(context) ||
        OrbitMotionScope.isReduced(context)) {
      fade.stop();
      fade.value = 1;
      points.clear();
      pointer = null;
    }
  }

  @override
  void dispose() {
    fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Temporary laser pointer. Exit using the Canvas motion menu.',
    child: MouseRegion(
      cursor: SystemMouseCursors.precise,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          if (pointer != null) return;
          pointer = e.pointer;
          points.clear();
          add(e.localPosition);
        },
        onPointerMove: (e) {
          if (pointer == e.pointer) add(e.localPosition);
        },
        onPointerUp: (e) {
          if (pointer == e.pointer) {
            pointer = null;
            if (OrbitMotionScope.isOff(context) ||
                OrbitMotionScope.isReduced(context)) {
              points.clear();
              fade.value = 1;
            } else {
              fade.forward(from: 0);
            }
          }
        },
        onPointerCancel: (e) {
          if (pointer == e.pointer) {
            pointer = null;
            points.clear();
            fade.value = 1;
          }
        },
        child: AnimatedBuilder(
          animation: fade,
          builder: (context, _) => CustomPaint(
            painter: _Laser(
              List.of(points),
              1 - fade.value,
              OrbitColors.of(context).accent,
              !OrbitMotionScope.isReduced(context) &&
                  !OrbitMotionScope.isOff(context),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
}

class _Laser extends CustomPainter {
  _Laser(this.points, this.opacity, this.color, this.trail);
  final List<Offset> points;
  final double opacity;
  final Color color;
  final bool trail;
  @override
  void paint(Canvas c, Size s) {
    if (points.isEmpty || opacity <= 0) return;
    c.save();
    c.clipRect(Offset.zero & s);
    if (trail) {
      for (var i = 1; i < points.length; i++) {
        c.drawLine(
          points[i - 1],
          points[i],
          Paint()
            ..color = color.withValues(alpha: opacity * i / points.length)
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    c.drawCircle(
      points.last,
      4,
      Paint()..color = color.withValues(alpha: opacity),
    );
    c.restore();
  }

  @override
  bool shouldRepaint(_Laser o) => true;
}
