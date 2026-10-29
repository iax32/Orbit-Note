import '../../app/orbit_theme.dart';
import 'package:flutter/material.dart';
import '../../canvas/geometry.dart';
import '../../canvas/scene.dart';
import '../../domain/collaboration.dart';
import 'canvas_painter.dart';

/// View-only awareness in world coordinates. It never mutates or locks a scene.
class CanvasPresenceOverlay extends StatelessWidget {
  const CanvasPresenceOverlay({
    super.key,
    required this.scene,
    required this.camera,
    required this.peers,
  });
  final CanvasScene scene;
  final CanvasCamera camera;
  final List<Map<String, dynamic>> peers;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final colors = Theme.of(context).colorScheme;
          final palette = [colors.primary, colors.secondary, colors.tertiary];
          final viewport = camera.viewport(
            constraints.maxWidth,
            constraints.maxHeight,
          );
          final children = <Widget>[];
          for (final peer in peers.take(128)) {
            final x = peer['x'], y = peer['y'], name = peer['name'];
            if (x is! num ||
                y is! num ||
                !x.isFinite ||
                !y.isFinite ||
                x.abs() > 100000000 ||
                y.abs() > 100000000 ||
                name is! String ||
                name.trim().isEmpty ||
                peer['active'] == false) {
              continue;
            }
            final label = String.fromCharCodes(
              name.runes
                  .take(80)
                  .map(
                    (rune) => rune >= 0xd800 && rune <= 0xdfff ? 0xfffd : rune,
                  ),
            );
            final session = peer['session'];
            final identity = session is String && session.length <= 80
                ? session
                : label;
            final color =
                palette[identity.codeUnits.fold(
                      0,
                      (n, c) => (n * 31 + c) & 0xffff,
                    ) %
                    palette.length];
            final ink = collaborationInkPreview(peer['ink']);
            if (ink != null && peer['role'] != 'viewer') {
              children.add(
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      key: ValueKey('peer-ink-$identity'),
                      painter: _PeerInkPainter(CanvasElement(ink), camera),
                    ),
                  ),
                ),
              );
            }
            for (final id in collaborationSelectionIds(peer['selection'])) {
              final element = scene[id];
              if (element == null ||
                  element.hidden ||
                  !element.renderable ||
                  !element.bounds.intersects(viewport)) {
                continue;
              }
              final bounds = element.bounds;
              final point = camera.toScreen(
                CanvasPoint(bounds.left, bounds.top),
              );
              children.add(
                Positioned(
                  left: point.x - 3,
                  top: point.y - 3,
                  width: bounds.width * camera.zoom + 6,
                  height: bounds.height * camera.zoom + 6,
                  child: Semantics(
                    label: '$label selected ${element.type}',
                    child: DecoratedBox(
                      key: ValueKey('peer-selection-$identity-$id'),
                      decoration: BoxDecoration(
                        border: Border.all(color: color, width: 2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              );
            }
            final point = camera.toScreen(
              CanvasPoint(x.toDouble(), y.toDouble()),
            );
            children.add(
              Positioned(
                left: point.x,
                top: point.y,
                child: Semantics(
                  label: '$label cursor',
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        '↖ $label',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11,
                          color: OrbitContrast.inkOn(color),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
          return Stack(children: children);
        },
      ),
    ),
  );
}

class _PeerInkPainter extends CustomPainter {
  _PeerInkPainter(this.stroke, CanvasCamera camera)
    : x = camera.x,
      y = camera.y,
      zoom = camera.zoom;
  final CanvasElement stroke;
  final double x, y, zoom;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(zoom);
    canvas.translate(-x, -y);
    OrbitCanvasPainter.paintInk(
      canvas,
      stroke,
      Color(stroke.data['color'] as int),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PeerInkPainter oldDelegate) =>
      x != oldDelegate.x ||
      y != oldDelegate.y ||
      zoom != oldDelegate.zoom ||
      !collaborationEqual(stroke.data, oldDelegate.stroke.data);
}
