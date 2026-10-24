import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_motion_effects.dart';
import '../../app/orbit_theme.dart';

/// Keeps exactly one live PDF viewer. The lens samples its rendered page rather
/// than opening a second document or re-running text extraction.
class PdfMotionSurface extends StatefulWidget {
  const PdfMotionSurface({
    super.key,
    required this.child,
    required this.navigation,
    required this.annotation,
    required this.page,
    required this.pageCount,
    this.lens = false,
    this.onDirectInteraction,
  });
  final Widget child;
  final Object navigation, annotation;
  final int page, pageCount;
  final bool lens;
  final VoidCallback? onDirectInteraction;
  @override
  State<PdfMotionSurface> createState() => _PdfMotionSurfaceState();
}

class _PdfMotionSurfaceState extends State<PdfMotionSurface> {
  final position = ValueNotifier<Offset?>(null);
  @override
  void dispose() {
    position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = OrbitMotionScope.settings(context);
    return ClipRect(
      child: MouseRegion(
        onHover: widget.lens ? (e) => position.value = e.localPosition : null,
        onExit: (_) => position.value = null,
        child: Listener(
          onPointerDown: (_) {
            position.value = null;
            widget.onDirectInteraction?.call();
          },
          onPointerSignal: (_) => widget.onDirectInteraction?.call(),
          onPointerMove: widget.lens
              ? (e) => position.value = e.localPosition
              : null,
          onPointerUp: (_) => position.value = null,
          onPointerCancel: (_) => position.value = null,
          child: Stack(
            children: [
              Positioned.fill(
                child: OrbitEffect(
                  trigger: widget.navigation,
                  family: 'reading',
                  style: prefs.pageStyle,
                  child: OrbitEffect(
                    trigger: widget.annotation,
                    family: 'reading',
                    style: 'highlight',
                    interactive: true,
                    child: widget.child,
                  ),
                ),
              ),
              if (prefs.readingProgress && widget.pageCount > 0)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: LinearProgressIndicator(
                      semanticsLabel: 'PDF page position',
                      value: (widget.page / widget.pageCount).clamp(0.0, 1.0),
                      minHeight: 2,
                    ),
                  ),
                ),
              if (widget.lens)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ValueListenableBuilder<Offset?>(
                      valueListenable: position,
                      builder: (context, p, _) => LayoutBuilder(
                        builder: (context, c) {
                          if (p == null ||
                              c.maxWidth < 140 ||
                              c.maxHeight < 140) {
                            return const SizedBox.shrink();
                          }
                          final left = (p.dx - 60).clamp(0.0, c.maxWidth - 120),
                              top = (p.dy - 150).clamp(0.0, c.maxHeight - 120);
                          return Stack(
                            children: [
                              Positioned(
                                left: left,
                                top: top,
                                child: RawMagnifier(
                                  size: const Size(120, 120),
                                  magnificationScale: 1.8,
                                  focalPointOffset:
                                      p - Offset(left + 60, top + 60),
                                  decoration: MagnifierDecoration(
                                    shape: CircleBorder(
                                      side: BorderSide(
                                        color: OrbitColors.of(context).accent,
                                        width: 2,
                                      ),
                                    ),
                                    shadows: const [
                                      BoxShadow(
                                        blurRadius: 10,
                                        color: Color(0x33000000),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
