import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../canvas/geometry.dart';
import '../../canvas/scene.dart';
import '../../canvas/starter_templates.dart';
import 'canvas_painter.dart';

class CanvasStarterDialog extends StatefulWidget {
  const CanvasStarterDialog({super.key});
  @override
  State<CanvasStarterDialog> createState() => _CanvasStarterDialogState();
}

class _CanvasStarterDialogState extends State<CanvasStarterDialog> {
  final search = TextEditingController();
  final cache = CanvasTextCache();
  CanvasStarter selected = CanvasStarters.all.first;
  late CanvasScene scene = _scene(selected);
  CanvasScene _scene(CanvasStarter starter) {
    var i = 0;
    return CanvasScene.fromJson({
      'schemaVersion': 1,
      'elements': starter
          .createElements(() => 'preview-${i++}')
          .map((e) => e.data)
          .toList(),
    });
  }

  @override
  void dispose() {
    search.dispose();
    cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = CanvasStarters.search(search.text);
    return OrbitDialog(
      maxWidth: 800,
      title: const Text('Canvas template library'),
      contentSlivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add an editable starter beside your existing content. Every item uses the normal Canvas tools; one Undo removes the insertion.',
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('canvas-starter-search'),
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Search Canvas templates',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear Canvas template search',
                          onPressed: () => setState(search.clear),
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Preview: ${selected.name}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Semantics(
                label: '${selected.name}. ${selected.description}',
                image: true,
                child: ExcludeSemantics(
                  child: AspectRatio(
                    aspectRatio: 1.8,
                    child: ClipRect(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final bounds = scene.contentBounds!.inflate(30);
                          final zoom = math.min(
                            constraints.maxWidth / bounds.width,
                            constraints.maxHeight / bounds.height,
                          );
                          return CustomPaint(
                            painter: OrbitCanvasPainter(
                              scene: scene,
                              camera: CanvasCamera(
                                x:
                                    bounds.center.x -
                                    constraints.maxWidth / zoom / 2,
                                y:
                                    bounds.center.y -
                                    constraints.maxHeight / zoom / 2,
                                zoom: zoom,
                              ),
                              selection: const {},
                              objects: const {},
                              colors: Theme.of(context).colorScheme,
                              textCache: cache,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (options.isEmpty)
                const Text('No matching Canvas templates. Try another search.'),
            ],
          ),
        ),
        SliverList.builder(
          itemCount: options.length,
          itemBuilder: (context, index) {
            final starter = options[index];
            return ListTile(
              key: ValueKey('canvas-starter-${starter.id}'),
              selected: starter == selected,
              leading: Icon(
                starter.mindMap ? Icons.hub_outlined : Icons.dashboard_outlined,
              ),
              title: Text(starter.name),
              subtitle: Text(starter.description),
              onTap: () => setState(() {
                selected = starter;
                scene = _scene(starter);
              }),
            );
          },
        ),
      ],
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: options.contains(selected)
              ? () => Navigator.pop(context, selected)
              : null,
          child: const Text('Add to Canvas'),
        ),
      ],
    );
  }
}
