import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import '../workspace/object_bridges.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../app/workspace_controller.dart';
import '../../domain/note_composition.dart';
import '../../domain/universal_object.dart';
import '../../canvas/scene.dart';
import '../../canvas/geometry.dart';
import '../../canvas/diagram_reference.dart';
import '../canvas/canvas_diagram_preview.dart';
import '../canvas/canvas_painter.dart';
import '../canvas/canvas_editor.dart';
import '../canvas/canvas_images.dart';

class NoteObjectSurface extends StatefulWidget {
  const NoteObjectSurface({
    super.key,
    required this.block,
    required this.objects,
    required this.onOpen,
    this.controller,
    this.editable = false,
  });
  final NoteObjectBlock block;
  final List<UniversalObject> objects;
  final ValueChanged<String> onOpen;
  final WorkspaceController? controller;
  final bool editable;
  @override
  State<NoteObjectSurface> createState() => _NoteObjectSurfaceState();
}

class _NoteObjectSurfaceState extends State<NoteObjectSurface> {
  final _textCache = CanvasTextCache();
  CanvasImageCache? _images;
  String? _imageWorkspace;
  int _imageRevision = -1;
  Map<String, dynamic>? _sceneData;
  CanvasScene? _scene;
  Map<String, dynamic>? _diagramData;
  String? _diagramFragment;
  ResolvedCanvasDiagram? _diagram;
  bool _diagramUnsupported = false;
  void _previewChanged() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _images?.dispose();
    _textCache.dispose();
    super.dispose();
  }

  UniversalObject? get object =>
      (widget.controller?.activeObjects ?? widget.objects)
          .where((o) => o.id == widget.block.id && !o.isDeleted)
          .firstOrNull;
  bool get writable =>
      widget.editable &&
      widget.controller != null &&
      !widget.controller!.repository.readOnly &&
      object?.isReadOnly == false;
  List<CanvasObjectReference> get references => [
    for (final o in widget.controller?.activeObjects ?? widget.objects)
      if (!o.isDeleted)
        CanvasObjectReference(
          id: o.id,
          title: o.title,
          typeId: o.typeId,
          body: o.body,
          properties: o.properties,
        ),
  ];
  Future<void> _draw() async {
    final original = object;
    if (!writable || original == null) return;
    if (CanvasScene.fromJson(original.data).readOnly) return;
    final controller = widget.controller!;
    final workspace = controller.repository.workspaceId;
    var expected = original.data;
    await showOrbitDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 1200,
          height: MediaQuery.sizeOf(context).height * .86,
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(child: Text(original.title)),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ],
              ),
              Expanded(
                child: CanvasEditor(
                  comfort: controller.session.canvasComfort,
                  onComfortChanged: (value) =>
                      controller.updateSession((s) => s.canvasComfort = value),
                  canvasId: original.id,
                  data: original.data,
                  focusElementIds:
                      diagramElementIds(widget.block.reference) ?? const [],
                  objects: references,
                  onOpenObject: widget.onOpen,
                  imageLoader: controller.repository.readAttachment,
                  imageRevision: controller.attachmentRevision,
                  onChanged: (data) {
                    final current = controller.find(original.id);
                    if (controller.repository.workspaceId != workspace ||
                        current == null ||
                        current.isDeleted ||
                        current.isReadOnly ||
                        controller.repository.readOnly ||
                        !identical(current.data, expected)) {
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'The drawing changed elsewhere. Reopen it before editing.',
                          ),
                        ),
                      );
                      return;
                    }
                    controller.edit(original.id, data: data);
                    expected = controller.find(original.id)!.data;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (controller != null) {
      final repository = controller.repository;
      if (_imageWorkspace != repository.workspaceId) {
        _images?.dispose();
        _imageWorkspace = repository.workspaceId;
        _images = CanvasImageCache(
          loader: repository.readAttachment,
          onChanged: _previewChanged,
        );
        _imageRevision = controller.attachmentRevision;
      } else if (_imageRevision != controller.attachmentRevision) {
        _imageRevision = controller.attachmentRevision;
        _images?.invalidateAll();
      }
    }
    final target = object;
    if (widget.block.reference.anchorType == 'elements') {
      final ids = diagramElementIds(widget.block.reference);
      if (target == null || target.typeId != 'orbit.canvas' || ids == null) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.block.label),
              const Text(
                'The linked diagram source or selection is unavailable. Its original reference is retained.',
              ),
              SelectableText('orbit-object:${widget.block.reference.target}'),
            ],
          ),
        );
      }
      if (!identical(_diagramData, target.data) ||
          _diagramFragment != widget.block.fragment) {
        _diagramData = target.data;
        _diagramFragment = widget.block.fragment;
        final source = CanvasScene.fromJson(target.data);
        _diagramUnsupported = source.readOnly;
        _diagram = ResolvedCanvasDiagram(source, ids);
      }
      if (_diagramUnsupported) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Unsupported Canvas format. The diagram reference and source data are retained.',
          ),
        );
      }
      return CanvasDiagramPreview(
        scene: _diagram!.scene,
        title: widget.block.label,
        unavailable: _diagram!.unavailable,
        onOpen: () => widget.onOpen(widget.block.reference.target),
        onEdit: writable ? _draw : null,
      );
    }
    if (controller != null && target?.typeId != 'orbit.canvas') {
      return ObjectReferenceCard(
        controller: controller,
        reference: widget.block.reference,
        fallback: widget.block.label,
        interactive: widget.editable,
      );
    }
    if (target == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.block.label),
              const Text(
                'Source unavailable. The original reference is retained.',
              ),
              SelectableText('orbit-object:${widget.block.id}'),
            ],
          ),
        ),
      );
    }
    final task = target.typeId == 'orbit.task';
    List<UniversalObject> members = const [];
    String? issue;
    if (target.typeId == 'orbit.view' && widget.controller != null) {
      try {
        members = widget.controller!.queryViewObjects(target);
        issue = widget.controller!.queryViewIssue(target);
      } catch (_) {
        issue =
            'The collection cannot be resolved. Open its source to review the definition.';
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controller != null)
              ObjectReferenceCard(
                controller: controller,
                reference: widget.block.reference,
                preview: false,
              ),
            if (controller == null)
              Row(
                children: [
                  if (task)
                    Checkbox(
                      value: target.isCompleted,
                      onChanged: writable
                          ? (value) {
                              final current = object;
                              if (current == null || !writable) return;
                              widget.controller!.edit(
                                current.id,
                                properties: {
                                  ...current.properties,
                                  'completed': value == true,
                                },
                              );
                              setState(() {});
                            }
                          : null,
                    ),
                  Expanded(
                    child: Text(
                      target.title.isEmpty ? widget.block.label : target.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            if (target.properties['dueDate'] != null)
              Text('Due ${target.properties['dueDate']}'),
            if (target.properties['status'] != null)
              Text('Status: ${target.properties['status']}'),
            if (target.typeId == 'orbit.canvas')
              SizedBox(
                height: 220,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (!identical(_sceneData, target.data)) {
                      _sceneData = target.data;
                      _scene = CanvasScene.fromJson(target.data);
                    }
                    final scene = _scene!;
                    if (scene.readOnly) {
                      return const Center(
                        child: Text(
                          'Unsupported drawing format. The original data is preserved.',
                        ),
                      );
                    }
                    final refs = {for (final r in references) r.id: r};
                    _images?.updateVisible([
                      for (final e in scene.elements)
                        if (!e.hidden &&
                            e.type == 'image' &&
                            e.data['contentRef'] is String)
                          e.data['contentRef'] as String
                        else if (!e.hidden &&
                            e.type == 'card' &&
                            refs[e.objectId]?.isImage == true &&
                            refs[e.objectId]?.contentRef != null)
                          refs[e.objectId]!.contentRef!,
                    ]);
                    final bounds = scene.contentBounds;
                    if (bounds == null) {
                      return const Center(
                        child: Text(
                          'Empty drawing — choose Edit drawing to sketch.',
                        ),
                      );
                    }
                    final zoom = math
                        .min(
                          (constraints.maxWidth - 24) /
                              math.max(bounds.width, 1),
                          196 / math.max(bounds.height, 1),
                        )
                        .clamp(.01, 4.0);
                    final camera = CanvasCamera(
                      x: bounds.left - 12 / zoom,
                      y: bounds.top - 12 / zoom,
                      zoom: zoom,
                    );
                    return RepaintBoundary(
                      child: CustomPaint(
                        painter: OrbitCanvasPainter(
                          semanticColors: OrbitColors.of(context),
                          scene: scene,
                          camera: camera,
                          selection: const {},
                          objects: {for (final r in references) r.id: r},
                          colors: Theme.of(context).colorScheme,
                          textCache: _textCache,
                          images: _images?.images ?? const {},
                          backgroundStyle:
                              target.data['backgroundStyle'] is String
                              ? target.data['backgroundStyle'] as String
                              : 'dots',
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (issue != null) Text(issue),
            if (target.typeId == 'orbit.view') ...[
              Text('${members.length} items'),
              for (final member in members.take(8))
                TextButton(
                  onPressed: () => widget.onOpen(member.id),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(member.title),
                  ),
                ),
              if (members.length > 8)
                const Text('Open collection to see all items.'),
            ],
            Wrap(
              spacing: 8,
              children: [
                if (controller == null)
                  TextButton(
                    onPressed: () =>
                        widget.onOpen(widget.block.reference.target),
                    child: const Text('Open source'),
                  ),
                if (target.typeId == 'orbit.canvas' &&
                    writable &&
                    !CanvasScene.fromJson(target.data).readOnly)
                  TextButton(
                    onPressed: _draw,
                    child: const Text('Edit drawing'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
