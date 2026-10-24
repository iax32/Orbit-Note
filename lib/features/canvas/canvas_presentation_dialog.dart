import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import '../../canvas/geometry.dart';
import '../../canvas/presentation.dart';
import '../../canvas/scene.dart';
import 'canvas_painter.dart';

Future<void> showCanvasPresentation(
  BuildContext context, {
  required CanvasScene scene,
  required Map<String, CanvasObjectReference> objects,
  Map<String, ui.Image> images = const {},
  Set<String> selection = const {},
  String fontFamily = 'Segoe UI',
  String background = 'dots',
}) async {
  final frozen = CanvasScene.fromJson(scene.toJson());
  final copies = {for (final e in images.entries) e.key: e.value.clone()};
  var adopted = false;
  final surface = _Presentation(
    scene: frozen,
    objects: Map.of(objects),
    images: copies,
    selection: Set.of(selection),
    fontFamily: fontFamily,
    background: background,
  );
  try {
    await showDialog<void>(
      context: context,
      builder: (_) {
        adopted = true;
        return surface;
      },
    );
  } finally {
    if (!adopted) {
      for (final image in copies.values) {
        image.dispose();
      }
    }
  }
}

class _Presentation extends StatefulWidget {
  const _Presentation({
    required this.scene,
    required this.objects,
    required this.images,
    required this.selection,
    required this.fontFamily,
    required this.background,
  });
  final CanvasScene scene;
  final Map<String, CanvasObjectReference> objects;
  final Map<String, ui.Image> images;
  final Set<String> selection;
  final String fontFamily, background;
  @override
  State<_Presentation> createState() => _PresentationState();
}

class _PresentationState extends State<_Presentation>
    with SingleTickerProviderStateMixin {
  late final player = AnimationController(vsync: this, value: 1);
  final cache = CanvasTextCache();
  bool selectedOnly = false;
  double speed = 1;
  Iterable<CanvasElement> get elements => widget.scene.elements.where(
    (e) =>
        !e.hidden &&
        e.renderable &&
        (!selectedOnly || widget.selection.contains(e.id)),
  );
  void play() {
    final base = (elements.take(1000).length * 650).clamp(650, 30000);
    player.duration = OrbitMotionScope.duration(
      context,
      Duration(milliseconds: (base / speed).round()),
      spatial: true,
    );
    if (player.duration == Duration.zero ||
        !OrbitMotionScope.settings(context).drawing) {
      player.value = 1;
      return;
    }
    player.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    player.stop();
    player.value = 1;
  }

  @override
  void dispose() {
    player.dispose();
    cache.dispose();
    for (final image in widget.images.values) {
      image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = elements.take(1000).toList(),
        timeline = CanvasPresentation(items);
    final bounded = elements.skip(1000).isNotEmpty;
    final bounds = items.isEmpty
        ? const CanvasBounds(0, 0, 600, 400)
        : items
              .skip(1)
              .fold(items.first.bounds, (a, b) => a.union(b.bounds))
              .inflate(24);
    return OrbitDialog(
      maxWidth: 1000,
      title: const Text('Canvas presentation'),
      content: SizedBox(
        width: 900,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Read-only replay in stored placement order. Your board, history and exports stay unchanged.',
              ),
              if (bounded)
                const Text(
                  'Preview limited to the first 1,000 visible placements. Select a smaller group to replay other content.',
                ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (widget.selection.isNotEmpty)
                    FilterChip(
                      label: const Text('Selection only'),
                      selected: selectedOnly,
                      onSelected: (v) {
                        player.stop();
                        player.value = 1;
                        setState(() => selectedOnly = v);
                      },
                    ),
                  DropdownButton<double>(
                    value: speed,
                    items: [
                      for (final n in [.5, 1.0, 1.5, 2.0])
                        DropdownMenuItem(value: n, child: Text('$n×')),
                    ],
                    onChanged: (v) {
                      player.stop();
                      setState(() => speed = v!);
                    },
                  ),
                  Text('${items.length} placements'),
                ],
              ),
              SizedBox(
                height: 340,
                child: LayoutBuilder(
                  builder: (context, c) {
                    final zoom = math
                        .min(
                          c.maxWidth / math.max(1, bounds.width),
                          340 / math.max(1, bounds.height),
                        )
                        .clamp(.001, 4.0);
                    final camera = CanvasCamera(
                      x: bounds.center.x - c.maxWidth / (2 * zoom),
                      y: bounds.center.y - 340 / (2 * zoom),
                      zoom: zoom,
                    );
                    return RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: player,
                        builder: (context, _) => CustomPaint(
                          key: const ValueKey('canvas-presentation-surface'),
                          painter: OrbitCanvasPainter(
                            scene: widget.scene,
                            camera: camera,
                            selection: const {},
                            objects: widget.objects,
                            images: widget.images,
                            colors: Theme.of(context).colorScheme,
                            semanticColors: OrbitColors.of(context),
                            textCache: cache,
                            exportElementIds: items.map((e) => e.id).toSet(),
                            backgroundStyle: widget.background,
                            fontFamily: widget.fontFamily,
                            revealProgress: timeline.at(player.value),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    );
                  },
                ),
              ),
              AnimatedBuilder(
                animation: player,
                builder: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Slider(
                      key: const ValueKey('canvas-replay-position'),
                      value: player.value,
                      label: '${(player.value * 100).round()}%',
                      onChanged: (v) {
                        player.stop();
                        player.value = v;
                      },
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: items.isEmpty ? null : play,
                          icon: const Icon(Icons.replay),
                          label: const Text('Replay'),
                        ),
                        TextButton.icon(
                          onPressed: items.isEmpty
                              ? null
                              : () {
                                  if (player.isAnimating) {
                                    player.stop();
                                  } else if (player.value < 1) {
                                    player.forward();
                                  } else {
                                    play();
                                  }
                                  setState(() {});
                                },
                          icon: Icon(
                            player.isAnimating ? Icons.pause : Icons.play_arrow,
                          ),
                          label: Text(player.isAnimating ? 'Pause' : 'Resume'),
                        ),
                        TextButton(
                          onPressed: () {
                            player.stop();
                            player.value = 1;
                          },
                          child: const Text('Show complete board'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (items.isEmpty)
                const Text('Add or select visible content to replay.'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
