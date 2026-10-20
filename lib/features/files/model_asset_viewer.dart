import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/model_asset.dart';

ModelAsset _decodeAsset((Uint8List, String) input) =>
    parseModelAsset(input.$1, input.$2);

class ModelAssetViewer extends StatefulWidget {
  const ModelAssetViewer({
    super.key,
    required this.name,
    required this.loadBytes,
    required this.onOpenOriginal,
    this.onPlace,
    this.byteLength,
    this.sourceVersion,
  });
  final String name;
  final int? byteLength;

  /// Immutable attachment/cache version; callback rebuilds alone do not reload it.
  final Object? sourceVersion;
  final Future<Uint8List?> Function() loadBytes;
  final VoidCallback onOpenOriginal;
  final VoidCallback? onPlace;
  @override
  State<ModelAssetViewer> createState() => _ViewerState();
}

class _ViewerState extends State<ModelAssetViewer> {
  late Future<ModelAsset> asset = load();
  double yaw = -.5, pitch = .3, zoom = 1;
  bool wireframe = false;
  int request = 0;
  @override
  void didUpdateWidget(covariant ModelAssetViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceVersion != widget.sourceVersion ||
        oldWidget.byteLength != widget.byteLength ||
        oldWidget.name != widget.name ||
        (widget.sourceVersion == null &&
            oldWidget.loadBytes != widget.loadBytes)) {
      yaw = -.5;
      pitch = .3;
      zoom = 1;
      wireframe = false;
      asset = load();
    }
  }

  Future<ModelAsset> load() async {
    final token = ++request;
    final name = widget.name, loadBytes = widget.loadBytes;
    if ((widget.byteLength ?? 0) > ModelAsset.maxBytes) {
      throw const FormatException(
        'Preview limit is 32 MB. Open the original instead.',
      );
    }
    final bytes = await loadBytes();
    if (!mounted || token != request) {
      throw const FormatException(
        'A newer model preview replaced this request.',
      );
    }
    if (bytes == null) {
      throw const FormatException(
        'Asset is missing. Recover the attachment or open its original.',
      );
    }
    return compute(_decodeAsset, (bytes, name));
  }

  void reset() => setState(() {
    yaw = -.5;
    pitch = .3;
    zoom = 1;
  });
  void magnify(double delta) =>
      setState(() => zoom = (zoom + delta).clamp(.2, 4));
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limits) => Column(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: limits.maxHeight * .35),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    widget.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    tooltip: 'Fit model',
                    onPressed: reset,
                    icon: const Icon(Icons.center_focus_strong),
                  ),
                  IconButton(
                    tooltip: 'Zoom out',
                    onPressed: () => magnify(-.2),
                    icon: const Icon(Icons.remove),
                  ),
                  Text('${(zoom * 100).round()}%'),
                  IconButton(
                    tooltip: 'Zoom in',
                    onPressed: () => magnify(.2),
                    icon: const Icon(Icons.add),
                  ),
                  FilterChip(
                    label: const Text('Wireframe'),
                    selected: wireframe,
                    onSelected: (v) => setState(() => wireframe = v),
                  ),
                  for (final view in ['Front', 'Side', 'Top'])
                    TextButton(
                      onPressed: () => setState(() {
                        yaw = view == 'Side' ? math.pi / 2 : 0;
                        pitch = view == 'Top' ? math.pi / 2 : 0;
                      }),
                      child: Text(view),
                    ),
                  if (widget.onPlace != null)
                    OutlinedButton.icon(
                      onPressed: widget.onPlace,
                      icon: const Icon(Icons.dashboard_outlined),
                      label: const Text('Add to Canvas'),
                    ),
                  TextButton(
                    onPressed: widget.onOpenOriginal,
                    child: const Text('Open original'),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<ModelAsset>(
            future: asset,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.view_in_ar_outlined, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            'Preview unavailable\n${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              asset = load();
                            }),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final model = snapshot.data!;
              return Column(
                children: [
                  Expanded(
                    child: Focus(
                      autofocus: true,
                      onKeyEvent: (_, event) {
                        if (event is! KeyDownEvent) {
                          return KeyEventResult.ignored;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.home) {
                          reset();
                        } else if (event.logicalKey ==
                            LogicalKeyboardKey.arrowLeft) {
                          setState(() => yaw -= .15);
                        } else if (event.logicalKey ==
                            LogicalKeyboardKey.arrowRight) {
                          setState(() => yaw += .15);
                        } else if (event.logicalKey ==
                            LogicalKeyboardKey.arrowUp) {
                          setState(() => pitch -= .15);
                        } else if (event.logicalKey ==
                            LogicalKeyboardKey.arrowDown) {
                          setState(() => pitch += .15);
                        } else {
                          return KeyEventResult.ignored;
                        }
                        return KeyEventResult.handled;
                      },
                      child: Semantics(
                        label:
                            '3D model preview. Drag to rotate; arrow keys rotate; Home fits the model.',
                        child: GestureDetector(
                          onPanUpdate: (d) => setState(() {
                            yaw += d.delta.dx * .01;
                            pitch = (pitch + d.delta.dy * .01).clamp(
                              -math.pi / 2,
                              math.pi / 2,
                            );
                          }),
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: ModelMeshPainter(
                                model,
                                yaw,
                                pitch,
                                zoom,
                                wireframe,
                                Theme.of(context).colorScheme,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: limits.maxHeight * .22,
                    ),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          '${model.points.length} vertices · ${model.faces.length} triangles\n${model.notes.join('\n')}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

class ModelMeshPainter extends CustomPainter {
  ModelMeshPainter(
    this.model,
    this.yaw,
    this.pitch,
    this.zoom,
    this.wireframe,
    this.colors,
  );
  final ModelAsset model;
  final double yaw, pitch, zoom;
  final bool wireframe;
  final ColorScheme colors;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.surface);
    final scale = math.min(size.width, size.height) * .8 * zoom;
    final center = Offset(size.width / 2, size.height / 2);
    final grid = Paint()
      ..color = colors.outlineVariant.withValues(alpha: .3)
      ..strokeWidth = .5;
    for (var x = 0.0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final transformed = [for (final p in model.points) rotate(p)];
    final ordered = model.faces.toList()
      ..sort(
        (a, b) => (transformed[a.a].z + transformed[a.b].z + transformed[a.c].z)
            .compareTo(
              transformed[b.a].z + transformed[b.b].z + transformed[b.c].z,
            ),
      );
    Offset screen(MeshPoint p) => center + Offset(p.x * scale, -p.y * scale);
    for (final face in ordered) {
      final a = transformed[face.a],
          b = transformed[face.b],
          c = transformed[face.c];
      final abx = b.x - a.x,
          aby = b.y - a.y,
          abz = b.z - a.z,
          acx = c.x - a.x,
          acy = c.y - a.y,
          acz = c.z - a.z;
      final nx = aby * acz - abz * acy,
          ny = abz * acx - abx * acz,
          nz = abx * acy - aby * acx;
      final length = math.sqrt(nx * nx + ny * ny + nz * nz);
      final light = length == 0
          ? .5
          : (.35 + .65 * ((nx * .3 + ny * .5 + nz * .8) / length).abs()).clamp(
              .25,
              1.0,
            );
      final path = Path()
        ..moveTo(screen(a).dx, screen(a).dy)
        ..lineTo(screen(b).dx, screen(b).dy)
        ..lineTo(screen(c).dx, screen(c).dy)
        ..close();
      final color = Color(face.color);
      canvas.drawPath(
        path,
        Paint()
          ..style = wireframe ? PaintingStyle.stroke : PaintingStyle.fill
          ..strokeWidth = .7
          ..color = wireframe
              ? colors.primary
              : Color.fromARGB(
                  255,
                  (color.r * 255 * light).round(),
                  (color.g * 255 * light).round(),
                  (color.b * 255 * light).round(),
                ),
      );
    }
  }

  MeshPoint rotate(MeshPoint p) {
    final x = p.x * math.cos(yaw) + p.z * math.sin(yaw),
        z = -p.x * math.sin(yaw) + p.z * math.cos(yaw);
    return MeshPoint(
      x,
      p.y * math.cos(pitch) - z * math.sin(pitch),
      p.y * math.sin(pitch) + z * math.cos(pitch),
    );
  }

  @override
  bool shouldRepaint(covariant ModelMeshPainter old) =>
      old.model != model ||
      old.yaw != yaw ||
      old.pitch != pitch ||
      old.zoom != zoom ||
      old.wireframe != wireframe ||
      old.colors != colors;
}
