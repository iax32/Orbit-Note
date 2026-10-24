import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'orbit_components.dart';
import 'orbit_theme.dart';

bool orbitEffectEnabled(BuildContext context, String family) {
  if (OrbitMotionScope.isOff(context)) return false;
  final p = OrbitMotionScope.settings(context);
  return switch (family) {
    'editing' => p.editing,
    'drawing' => p.drawing,
    'reading' => p.reading,
    'smart' => p.smart,
    _ => p.navigation,
  };
}

/// One finite presentation over the current child. No outgoing editor or second
/// focus tree is retained. Any direct interaction settles it immediately.
class OrbitEffect extends StatefulWidget {
  const OrbitEffect({
    super.key,
    required this.child,
    required this.trigger,
    this.family = 'navigation',
    this.style = 'arrival',
    this.interactive = false,
    this.duration = const Duration(milliseconds: 240),
    this.onMount = false,
    this.paused = false,
  });
  final Widget child;
  final Object? trigger;
  final String family, style;
  final bool interactive, onMount, paused;
  final Duration duration;
  @override
  State<OrbitEffect> createState() => _OrbitEffectState();
}

class _OrbitEffectState extends State<OrbitEffect>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(vsync: this, value: 1);
  bool initialized = false;
  void replay() {
    final duration = orbitEffectEnabled(context, widget.family)
        ? OrbitMotionScope.duration(context, widget.duration)
        : Duration.zero;
    controller.duration = duration;
    if (duration == Duration.zero) {
      controller.value = 1;
    } else {
      controller.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller.stop();
    controller.value = 1;
    if (!initialized && widget.onMount) replay();
    initialized = true;
  }

  @override
  void didUpdateWidget(OrbitEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) replay();
    if (widget.paused) {
      controller.stop();
    } else if (oldWidget.paused && controller.value < 1) {
      controller.forward();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) {
      controller.stop();
      controller.value = 1;
    },
    child: AnimatedBuilder(
      animation: controller,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(controller.value);
        final reduced = OrbitMotionScope.isReduced(context);
        final color = OrbitColors.of(context).accent;
        final overlay =
            widget.interactive ||
            const {
              'underline',
              'wave',
              'highlight',
              'shimmer',
              'spotlight',
              'caret',
            }.contains(widget.style);
        final style = widget.style;
        final profile = OrbitMotionScope.settings(context).profile;
        final travel = !overlay && !reduced;
        final zoom =
            travel && const {'zoom', 'lift', 'paper', 'morph'}.contains(style);
        final x = travel && (style == 'slide' || style == 'paper') ? 10.0 : 0.0;
        final transform = Matrix4.identity()
          ..translateByDouble(
            x * (1 - t),
            travel && x == 0 ? (profile == 'paper' ? 6.0 : 4.0) * (1 - t) : 0,
            0,
            1,
          )
          ..scaleByDouble(
            zoom ? 1 - .018 * (1 - t) : 1,
            zoom ? 1 - .018 * (1 - t) : 1,
            1,
            1,
          );
        if (travel && style == 'curl') {
          transform
            ..setEntry(3, 2, .0007)
            ..rotateY(-.12 * (1 - t));
        }
        // A constant wrapper tree matters: settling must never recreate an
        // EditableText, its composing range, native selection or focus node.
        return Stack(
          children: [
            Opacity(
              opacity: overlay ? 1 : (reduced ? .90 + .10 * t : .88 + .12 * t),
              child: Transform(
                transform: transform,
                alignment: Alignment.centerLeft,
                transformHitTests: false,
                child: ImageFiltered(
                  enabled: travel && style == 'blur' && t < 1,
                  imageFilter: ui.ImageFilter.blur(
                    sigmaX: 2 * (1 - t),
                    sigmaY: 2 * (1 - t),
                  ),
                  child: child,
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _FeedbackPainter(
                    overlay ? t : 1,
                    color,
                    reduced ? 'spotlight' : style,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _FeedbackPainter extends CustomPainter {
  _FeedbackPainter(this.progress, this.color, this.style);
  final double progress;
  final Color color;
  final String style;
  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1 || size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final alpha = math.sin(progress * math.pi) * .22;
    final paint = Paint()..color = color.withValues(alpha: alpha);
    if (style == 'underline' || style == 'caret') {
      canvas.drawLine(
        Offset.zero.translate(0, size.height - 1),
        Offset(size.width * progress, size.height - 1),
        paint..strokeWidth = 2,
      );
    } else if (style == 'shimmer' || style == 'wave' || style == 'highlight') {
      final width = math.max(24.0, size.width * .3);
      final rect = Rect.fromLTWH(
        (size.width + width) * progress - width,
        0,
        width,
        size.height,
      );
      paint.shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ],
      ).createShader(rect);
      canvas.drawRect(rect, paint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(1),
          const Radius.circular(6),
        ),
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FeedbackPainter old) =>
      progress != old.progress || color != old.color || style != old.style;
}

/// Read-only presentation of real authored text. Full text remains available to
/// assistive technology; touching it completes the reveal before text selection.
class OrbitTextReplay extends StatefulWidget {
  const OrbitTextReplay({
    super.key,
    required this.text,
    required this.style,
    required this.replay,
    this.textStyle,
    this.paused = false,
  });
  final String text, style;
  final Object replay;
  final TextStyle? textStyle;
  final bool paused;
  @override
  State<OrbitTextReplay> createState() => _OrbitTextReplayState();
}

class _OrbitTextReplayState extends State<OrbitTextReplay>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(vsync: this, value: 1);
  late List<String> glyphs = widget.text.characters.toList();
  bool first = true;
  void play() {
    final enabled =
        !OrbitMotionScope.isOff(context) &&
        !OrbitMotionScope.isReduced(context) &&
        widget.style != 'none';
    controller.duration = OrbitMotionScope.duration(
      context,
      Duration(milliseconds: (glyphs.length * 20).clamp(500, 12000)),
    );
    if (!enabled) {
      controller.value = 1;
      return;
    }
    controller.forward(from: 0);
    if (widget.paused) controller.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller.stop();
    controller.value = 1;
    if (first) {
      play();
    }
    first = false;
  }

  @override
  void didUpdateWidget(OrbitTextReplay old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      glyphs = widget.text.characters.toList();
    }
    if (old.replay != widget.replay ||
        old.style != widget.style ||
        old.text != widget.text) {
      play();
    }
    if (widget.paused) {
      controller.stop();
    } else if (old.paused && controller.value < 1) {
      controller.forward();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.text,
    child: ExcludeSemantics(
      child: Listener(
        onPointerDown: (_) {
          controller.stop();
          controller.value = 1;
        },
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, _) {
            final p = controller.value;
            var cadence = widget.style == 'typewriter' && p < 1
                ? (p + math.sin(p * 35) * .009).clamp(0.0, 1.0)
                : p;
            var count = (glyphs.length * cadence).floor().clamp(
              0,
              glyphs.length,
            );
            if (widget.style == 'word' && count < glyphs.length) {
              while (count > 0 && glyphs[count - 1].trim().isNotEmpty) {
                count--;
              }
            }
            String text;
            if (widget.style == 'scramble' && p < 1) {
              const symbols = '░▒<>/*+-';
              text = [
                for (var i = 0; i < glyphs.length; i++)
                  i < count || glyphs[i].trim().isEmpty
                      ? glyphs[i]
                      : symbols[(i + (p * 40).floor()) % symbols.length],
              ].join();
            } else if (const {
              'typewriter',
              'word',
              'character',
            }.contains(widget.style)) {
              text = glyphs.take(count).join();
            } else {
              text = widget.text;
            }
            Widget child = SelectableText(
              text,
              style: (widget.textStyle ?? Theme.of(context).textTheme.bodyLarge)
                  ?.copyWith(
                    fontWeight: widget.style == 'typography'
                        ? FontWeight.lerp(FontWeight.w400, FontWeight.w600, p)
                        : widget.textStyle?.fontWeight,
                  ),
            );
            if (widget.style == 'blur' && p < 1) {
              child = ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: 3 * (1 - p),
                  sigmaY: 3 * (1 - p),
                ),
                child: child,
              );
            }
            if (widget.style == 'ink' && p < 1) {
              child = ClipRect(clipper: _InkClip(p), child: child);
            }
            return child;
          },
        ),
      ),
    ),
  );
}

class _InkClip extends CustomClipper<Rect> {
  _InkClip(this.p);
  final double p;
  @override
  Rect getClip(Size s) => Rect.fromLTWH(0, 0, s.width, s.height * p);
  @override
  bool shouldReclip(_InkClip old) => p != old.p;
}

/// Short, deterministic vector sketches for motion previews. Actual Canvas
/// replay supplies its own authored paths through the spatial painter.
class OrbitMotionSketch extends StatelessWidget {
  const OrbitMotionSketch({
    super.key,
    required this.progress,
    required this.style,
  });
  final double progress;
  final String style;
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(420, 180),
    painter: _Sketch(progress, style, OrbitColors.of(context).accent),
  );
}

class _Sketch extends CustomPainter {
  _Sketch(this.p, this.style, this.color);
  final double p;
  final String style;
  final Color color;
  @override
  void paint(Canvas c, Size s) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    final graph = const {'diagram', 'constellation', 'path'}.contains(style);
    if (graph) {
      for (var i = 0; i < 5; i++) {
        final a = i * math.pi * 2 / 5;
        final center = Offset(s.width / 2, s.height / 2);
        final end =
            center +
            Offset(math.cos(a) * s.width * .32, math.sin(a) * s.height * .34);
        path.moveTo(center.dx, center.dy);
        path.lineTo(end.dx, end.dy);
        if (p > i / 6) {
          c.drawCircle(end, 9 * math.min(1, (p - i / 6) * 6), paint);
        }
      }
    } else {
      path.moveTo(16, s.height * .65);
      for (var i = 0; i < 80; i++) {
        path.lineTo(
          16 + (s.width - 32) * i / 79,
          s.height * .5 + math.sin(i * .2) * s.height * .24,
        );
      }
      if (style == 'highlight') {
        paint
          ..strokeWidth = 18
          ..color = color.withValues(alpha: .35);
      }
      if (style == 'erase') {
        paint.color = color.withValues(alpha: 1 - p);
      }
    }
    final metrics = path.computeMetrics().toList();
    final length = metrics.fold<double>(0, (n, m) => n + m.length);
    var left = length * p;
    for (final metric in metrics) {
      if (left <= 0) break;
      c.drawPath(metric.extractPath(0, math.min(left, metric.length)), paint);
      left -= metric.length;
    }
  }

  @override
  bool shouldRepaint(_Sketch o) =>
      p != o.p || style != o.style || color != o.color;
}
