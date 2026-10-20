import 'object_connection_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/workspace_controller.dart';
import '../../domain/object_reference.dart';
import '../../domain/object_connections.dart';
import '../../domain/note_composition.dart';
import '../../canvas/diagram_reference.dart';
import '../../domain/document_anchors.dart';
import '../../domain/model_asset.dart';
import '../../domain/code_preview.dart';
import '../../domain/project_context.dart';
import '../../domain/research_workspace.dart';
import '../../domain/universal_object.dart';

String objectKind(UniversalObject o) {
  if (o.properties['isCourseOverview'] == true) return 'Course';
  if (o.properties['isCreativeBrief'] == true) return 'Project brief';
  if (o.properties['studyCard'] != null) return 'Study card';
  if (o.properties['pdfSource'] != null) return 'PDF passage';
  if (o.typeId == 'orbit.file') {
    final name = '${o.properties['originalName'] ?? o.title}';
    if (isModelAsset(name)) return '3D model';
    if (o.properties['mimeType'] == 'application/pdf') return 'PDF';
    if ('${o.properties['mimeType']}'.startsWith('image/')) return 'Image';
    if (previewLanguage(name) != null) return 'Source file';
    return 'Attachment';
  }
  return switch (o.typeId) {
    'orbit.canvas' => 'Canvas',
    'orbit.task' => 'Task',
    'orbit.event' => 'Event',
    'orbit.view' => 'Saved view',
    _ => 'Note',
  };
}

Future<void> copyLiveReference(
  BuildContext context,
  UniversalObject object, {
  ObjectReference? reference,
  bool card = true,
}) async {
  final ref = reference ?? ObjectReference(object.id);
  try {
    await Clipboard.setData(
      ClipboardData(
        text: card
            ? NoteObjectBlock(
                object.id,
                object.title,
                fragment: ref.isPrecise ? ref.fragment : null,
              ).encode()
            : ref.markdown(object.title),
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            card
                ? 'Live reference copied. Paste into a note or Canvas.'
                : 'Stable reference copied.',
          ),
        ),
      );
    }
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('The clipboard is unavailable. Nothing was changed.'),
        ),
      );
    }
  }
}

class ObjectReferenceCard extends StatefulWidget {
  const ObjectReferenceCard({
    super.key,
    required this.controller,
    required this.reference,
    this.fallback = 'Linked object',
    this.interactive = false,
    this.actions = true,
    this.preview = true,
  });
  final WorkspaceController controller;
  final ObjectReference reference;
  final String fallback;
  final bool interactive, actions, preview;
  @override
  State<ObjectReferenceCard> createState() => _ReferenceCardState();
}

class _ReferenceCardState extends State<ObjectReferenceCard> {
  VoidCallback? _removeListener;
  bool _refreshPending = false;
  void _listen() {
    _removeListener = widget.controller.observeChanges(() {
      if (!mounted) return;
      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        if (_refreshPending) return;
        _refreshPending = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _refreshPending = false;
          if (mounted) setState(() {});
        });
      } else {
        setState(() {});
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(ObjectReferenceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _removeListener?.call();
      _listen();
    }
  }

  @override
  void dispose() {
    _removeListener?.call();
    super.dispose();
  }

  String? _imageKey;
  Future<Uint8List?>? _image;
  @override
  Widget build(BuildContext context) {
    final c = widget.controller,
        target = widget.controller.find(widget.reference.id);
    final colors = Theme.of(context).colorScheme;
    final missing = target == null || target.isDeleted;
    var body = target?.body ?? '',
        warning = missing
            ? 'Source unavailable. This reference is retained.'
            : '';
    final ref = widget.reference;
    if (!missing && ref.anchorType != null) {
      if (target.typeId == 'orbit.note' &&
          {'block', 'heading', 'label'}.contains(ref.anchorType)) {
        final fragment = resolveDocumentFragment(
          body,
          ref,
          latex: target.properties['documentFormat'] == 'latex',
        );
        if (fragment == null) {
          warning =
              'This precise location is missing or ambiguous. Open the source to review it.';
          body = '';
        } else {
          body = fragment.text;
        }
      } else if (ref.anchorType == 'element' &&
          target.typeId == 'orbit.canvas') {
        final raw = target.data['elements'];
        final matches = raw is List
            ? raw
                  .whereType<Map>()
                  .where((e) => e['id'] == ref.anchorId)
                  .toList()
            : <Map>[];
        if (matches.length != 1) {
          warning =
              'The Canvas element is unavailable. The board reference remains intact.';
        } else {
          body = '${matches.single['text'] ?? 'Canvas element'}';
        }
      } else if (ref.anchorType == 'elements' &&
          target.typeId == 'orbit.canvas') {
        final ids = diagramElementIds(ref);
        final raw = target.data['elements'];
        final present = raw is List
            ? raw
                  .whereType<Map>()
                  .where((e) => e['hidden'] != true)
                  .map((e) => e['id'])
                  .toSet()
            : const <Object?>{};
        body = 'Linked diagram selection';
        if (ids == null || ids.any((id) => !present.contains(id))) {
          warning =
              'Some diagram items are unavailable. The original selection is retained.';
        }
      } else if (ref.anchorType == 'unknown') {
        warning =
            'Unsupported precise location. The original target is retained.';
      }
    }
    final image =
        !missing &&
        target.typeId == 'orbit.file' &&
        ('${target.properties['mimeType']}'.startsWith('image/') ||
            RegExp(
              r'\.(png|jpe?g|webp|gif)$',
              caseSensitive: false,
            ).hasMatch(target.title));
    final imageRef = target?.properties['contentRef'];
    final size = target?.properties['byteLength'];
    final canPreviewImage =
        widget.preview &&
        image &&
        imageRef is String &&
        (size is! num || size <= 16 * 1024 * 1024);
    if (canPreviewImage) {
      final key =
          '${c.repository.workspaceId}:$imageRef:${target.properties['checksum']}:${c.attachmentRevision}';
      if (key != _imageKey) {
        _imageKey = key;
        _image = c.repository.readAttachment(imageRef);
      }
    }
    final members =
        !missing &&
            target.typeId == 'orbit.view' &&
            target.properties['viewType'] != 'research'
        ? c.queryViewIssue(target) == null
              ? c.queryViewObjects(target)
              : <UniversalObject>[]
        : <UniversalObject>[];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (target?.typeId == 'orbit.task')
                Checkbox(
                  value: target!.isCompleted,
                  onChanged:
                      widget.interactive &&
                          !missing &&
                          !target.isReadOnly &&
                          !c.repository.readOnly
                      ? (v) {
                          final current = c.find(target.id);
                          if (current == null || current.isDeleted) return;
                          c.edit(
                            current.id,
                            properties: {
                              ...current.properties,
                              'completed': v == true,
                            },
                          );
                        }
                      : null,
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 10, top: 2),
                  child: Icon(
                    missing
                        ? Icons.link_off
                        : image
                        ? Icons.image_outlined
                        : target.typeId == 'orbit.canvas'
                        ? Icons.dashboard_outlined
                        : Icons.link,
                    size: 20,
                    color: colors.primary,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target?.title.isNotEmpty == true
                          ? target!.title
                          : widget.fallback,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      missing
                          ? 'Unavailable source'
                          : '${objectKind(target)}${ref.page == null ? '' : ' · Page ${ref.page}'}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!missing)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                [
                  if (target.properties['course'] is String &&
                      target.properties['course'] != '')
                    'Course: ${target.properties['course']}',
                  if (target.properties['projectName'] is String &&
                      target.properties['projectName'] != '')
                    'Project: ${target.properties['projectName']}',
                  if (target.properties['folder'] is String)
                    '${target.properties['folder']}',
                  if (target.properties['dueDate'] != null)
                    'Due ${target.properties['dueDate']}',
                  if (target.properties['status'] != null)
                    '${target.properties['status']}',
                ].join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (warning.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(warning, style: TextStyle(color: colors.error)),
            ),
          if (canPreviewImage)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FutureBuilder<Uint8List?>(
                future: _image,
                builder: (context, result) {
                  if (result.connectionState != ConnectionState.done) {
                    return const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (result.hasError || result.data == null) {
                    return TextButton(
                      onPressed: () => setState(() => _imageKey = null),
                      child: const Text('Image unavailable · Retry'),
                    );
                  }
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      result.data!,
                      height: 170,
                      fit: BoxFit.contain,
                      cacheWidth: 700,
                      errorBuilder: (_, _, _) => const Text(
                        'Image cannot be decoded. Open its source to recover it.',
                      ),
                    ),
                  );
                },
              ),
            ),
          if (widget.preview && body.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                body.length > 1200 ? '${body.substring(0, 1200)}…' : body,
                maxLines: 7,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
          if (widget.preview && target?.typeId == 'orbit.view') ...[
            const SizedBox(height: 8),
            Text(
              target!.properties['viewType'] == 'research'
                  ? 'Live research collection'
                  : '${members.length} matching items',
            ),
            for (final member in members.take(4))
              TextButton(
                onPressed: () => c.openReference(
                  ObjectReference(member.id),
                  secondary: true,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(member.title),
                ),
              ),
          ],
          if (widget.actions)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: missing ? null : () => c.openReference(ref),
                  child: const Text('Open source'),
                ),
                TextButton(
                  onPressed: missing
                      ? null
                      : () => c.openReference(ref, secondary: true),
                  child: const Text('Open beside'),
                ),
                TextButton(
                  onPressed: missing
                      ? null
                      : () =>
                            copyLiveReference(context, target, reference: ref),
                  child: const Text('Copy live card'),
                ),
                TextButton(
                  onPressed: () => showObjectConnections(context, c, ref.id),
                  child: const Text('Connections'),
                ),
                if (missing &&
                    target?.isDeleted == true &&
                    !c.repository.readOnly)
                  TextButton(
                    onPressed: () => c.restore(target!.id),
                    child: const Text('Restore source'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

Future<UniversalObject?> showObjectReferencePicker(
  BuildContext context,
  WorkspaceController c, {
  String title = 'Choose a live reference',
  String? exclude,
  Set<String>? types,
  String? project,
}) {
  final generation = c.workspaceGeneration;
  return showDialog<UniversalObject>(
    context: context,
    builder: (_) => _ObjectPicker(
      controller: c,
      generation: generation,
      title: title,
      exclude: exclude,
      types: types,
      project: project,
    ),
  );
}

class _ObjectPicker extends ConsumerStatefulWidget {
  const _ObjectPicker({
    required this.controller,
    required this.title,
    required this.generation,
    this.exclude,
    this.types,
    this.project,
  });
  final WorkspaceController controller;
  final String title;
  final int generation;
  final String? exclude;
  final Set<String>? types;
  final String? project;
  @override
  ConsumerState<_ObjectPicker> createState() => _ObjectPickerState();
}

class _ObjectPickerState extends ConsumerState<_ObjectPicker> {
  String query = '', type = 'all';
  String? selected;
  bool completed = false;
  int limit = 40, keyboardIndex = 0;
  final scroll = ScrollController();
  final focus = FocusNode();
  late final String workspace;
  late final int generation;
  @override
  void initState() {
    super.initState();
    workspace = widget.controller.repository.workspaceId;
    generation = widget.generation;
  }

  final rowKeys = <String, GlobalKey>{};
  @override
  void dispose() {
    scroll.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(workspaceProvider);
    final c = widget.controller;
    final items =
        (workspace == c.repository.workspaceId &&
                    generation == c.workspaceGeneration
                ? c.activeObjects
                : <UniversalObject>[])
            .where(
              (o) =>
                  o.id != widget.exclude &&
                  (widget.project == null ||
                      o.id == widget.project ||
                      objectProject(o) == widget.project) &&
                  (widget.types == null || widget.types!.contains(o.typeId)) &&
                  (type == 'all' || type == o.typeId) &&
                  '${o.title} ${o.properties['aliases'] ?? ''} ${o.properties['folder'] ?? ''} ${o.properties['course'] ?? ''}'
                      .toLowerCase()
                      .contains(query),
            )
            .toList()
          ..sort((a, b) {
            final name = a.title.compareTo(b.title);
            return name == 0 ? a.id.compareTo(b.id) : name;
          });
    keyboardIndex = keyboardIndex.clamp(
      0,
      items.isEmpty ? 0 : items.length - 1,
    );
    final choice = items.where((o) => o.id == selected).firstOrNull;
    void choose(UniversalObject? object) {
      if (!mounted || completed) return;
      final current = object == null ? null : c.find(object.id);
      if (object != null &&
          workspace == c.repository.workspaceId &&
          generation == c.workspaceGeneration &&
          current != null &&
          !current.isDeleted &&
          current.id != widget.exclude &&
          (widget.project == null ||
              current.id == widget.project ||
              objectProject(current) == widget.project) &&
          (widget.types == null || widget.types!.contains(current.typeId)) &&
          (type == 'all' || current.typeId == type)) {
        completed = true;
        Navigator.pop(context, current);
      }
    }

    focus.onKeyEvent = (_, event) {
      if (event is! KeyDownEvent ||
          HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isAltPressed) {
        return KeyEventResult.ignored;
      }
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.enter && items.isNotEmpty) {
        // A deleted/filtered selection must not silently become another object.
        if (selected == null || choice != null) {
          choose(choice ?? items[keyboardIndex]);
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.arrowUp) {
        if (items.isNotEmpty) {
          setState(() {
            keyboardIndex =
                (keyboardIndex + (key == LogicalKeyboardKey.arrowDown ? 1 : -1))
                    .clamp(0, items.length - 1);
            selected = items[keyboardIndex].id;
            limit = limit < keyboardIndex + 1 ? keyboardIndex + 1 : limit;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final row = rowKeys[selected]?.currentContext;
            if (mounted && row != null) Scrollable.ensureVisible(row);
          });
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    final visibleIds = items.take(limit).map((o) => o.id).toSet();
    rowKeys.removeWhere((id, _) => !visibleIds.contains(id));
    final list = ListView(
      controller: scroll,
      children: [
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'No matching objects. Try another title, course or folder.',
            ),
          ),
        for (final object in items.take(limit))
          ListTile(
            key: rowKeys.putIfAbsent(object.id, GlobalKey.new),
            selected: object.id == selected,
            title: Text(object.title.isEmpty ? 'Untitled' : object.title),
            subtitle: Text(
              '${objectKind(object)} · ${object.properties['folder'] ?? object.id}',
            ),
            onTap: () => setState(() => selected = object.id),
            onLongPress: () => choose(object),
          ),
        if (items.length > limit)
          TextButton(
            onPressed: () => setState(() => limit += 40),
            child: const Text('Show more objects'),
          ),
      ],
    );
    return Dialog(
      child: SizedBox(
        width: 960,
        height: 690,
        child: LayoutBuilder(
          builder: (context, viewport) => Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: viewport.maxHeight * .42,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Cancel reference picker',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          autofocus: true,
                          focusNode: focus,
                          decoration: const InputDecoration(
                            labelText: 'Find an object',
                            hintText: 'Title, alias, course or folder',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) => setState(() {
                            query = v.toLowerCase();
                            selected = null;
                            limit = 40;
                            keyboardIndex = 0;
                            if (scroll.hasClients) scroll.jumpTo(0);
                          }),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final entry in {
                                'all': 'All',
                                'orbit.note': 'Notes',
                                'orbit.canvas': 'Canvas',
                                'orbit.task': 'Tasks',
                                'orbit.event': 'Events',
                                'orbit.file': 'Files',
                                'orbit.view': 'Views',
                              }.entries)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(entry.value),
                                    selected: type == entry.key,
                                    onSelected: (_) => setState(() {
                                      type = entry.key;
                                      selected = null;
                                      limit = 40;
                                      keyboardIndex = 0;
                                    }),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, bounds) =>
                      bounds.maxWidth /
                              MediaQuery.textScalerOf(context).scale(1) <
                          700
                      ? list
                      : Row(
                          children: [
                            Expanded(child: list),
                            const VerticalDivider(width: 1),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: choice == null
                                    ? const Text(
                                        'Select an object to preview its current content. References keep the original identity and update with their source.',
                                      )
                                    : ObjectReferenceCard(
                                        controller: c,
                                        reference: ObjectReference(choice.id),
                                        actions: false,
                                      ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: viewport.maxHeight * .26,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${items.length} objects · Original content stays shared',
                        ),
                        if (choice != null)
                          TextButton(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (previewContext) => AlertDialog(
                                content: SingleChildScrollView(
                                  child: ObjectReferenceCard(
                                    controller: c,
                                    reference: ObjectReference(choice.id),
                                    actions: false,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(previewContext),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            ),
                            child: const Text('Preview'),
                          ),
                        FilledButton(
                          onPressed:
                              choice == null ||
                                  workspace != c.repository.workspaceId
                              ? null
                              : () => choose(choice),
                          child: const Text('Use reference'),
                        ),
                      ],
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

Future<void> useReferenceElsewhere(
  BuildContext context,
  WorkspaceController c,
  ObjectReference ref, {
  required bool canvas,
}) async {
  final workspace = c.repository.workspaceId,
      generation = c.workspaceGeneration;
  final destination = await showObjectReferencePicker(
    context,
    c,
    exclude: ref.id,
    title: canvas ? 'Place reference on Canvas' : 'Embed reference in note',
    types: {canvas ? 'orbit.canvas' : 'orbit.note'},
  );
  if (destination == null ||
      !context.mounted ||
      workspace != c.repository.workspaceId ||
      generation != c.workspaceGeneration) {
    return;
  }
  final placement = canvas
      ? await c.placeReferenceOnCanvas(destination, ref)
      : null;
  final ok = canvas
      ? placement != null
      : await c.embedReferenceInNote(destination, ref);
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(
        ok
            ? 'Added a live reference. The original remains shared.'
            : 'The destination changed or could not be saved. Review its save status.',
      ),
      action: ok
          ? SnackBarAction(
              label: 'Open',
              onPressed: () => c.openReference(
                ObjectReference(
                  destination.id,
                  anchorType: placement == null ? null : 'element',
                  anchorId: placement,
                ),
              ),
            )
          : null,
    ),
  );
}

Future<void> showObjectConnections(
  BuildContext context,
  WorkspaceController c,
  String id,
) => showDialog<void>(
  context: context,
  builder: (_) => _Connections(controller: c, id: id),
);

class _Connections extends ConsumerStatefulWidget {
  const _Connections({required this.controller, required this.id});
  final WorkspaceController controller;
  final String id;
  @override
  ConsumerState<_Connections> createState() => _ConnectionsState();
}

class _ConnectionsState extends ConsumerState<_Connections> {
  String filter = '', mode = 'Used in';
  int limit = 30;
  bool busy = false;
  String? feedback;
  late final int generation;
  @override
  void initState() {
    super.initState();
    generation = widget.controller.workspaceGeneration;
  }

  Future<void> add() async {
    final c = widget.controller, source = widget.controller.find(widget.id);
    if (source == null || generation != c.workspaceGeneration) return;
    final workspace = c.repository.workspaceId,
        version = researchVersion(source);
    final target = await showObjectReferencePicker(
      context,
      c,
      exclude: source.id,
    );
    if (target == null ||
        !mounted ||
        workspace != c.repository.workspaceId ||
        generation != c.workspaceGeneration) {
      return;
    }
    final saved = await showObjectConnectionEditor(
      context,
      c,
      source,
      target,
      generation: generation,
      expectedSourceVersion: version,
    );
    if (mounted && generation == c.workspaceGeneration && saved == true) {
      setState(() => feedback = 'Connection saved.');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(workspaceProvider);
    final c = widget.controller, source = widget.controller.find(widget.id);
    if (generation != c.workspaceGeneration) {
      return AlertDialog(
        title: const Text('Vault changed'),
        content: const Text('Reopen Connections in the current Vault.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }
    final authored = ProjectConnection.read(
      source?.properties['orbitConnections'],
    );
    final inbound = c.connectionsTo(widget.id),
        outbound = c.connectionsFrom(widget.id);
    final memberships = <ObjectConnection>[];
    if (mode == 'Saved views') {
      for (final view in c.activeObjects.where(
        (o) =>
            o.typeId == 'orbit.view' && o.properties['viewType'] != 'research',
      )) {
        if (c.queryViewIssue(view) == null &&
            c.queryViewObjects(view).any((o) => o.id == widget.id)) {
          memberships.add(
            ObjectConnection(
              source: view,
              target: ObjectReference(widget.id),
              location: ObjectReference(view.id),
              label: 'Included by saved view',
            ),
          );
        }
      }
    }
    final edges =
        (mode == 'Used in'
                ? inbound
                : mode == 'Saved views'
                ? memberships
                : outbound)
            .where(
              (e) =>
                  '${mode != 'References' ? e.source.title : c.find(e.target.id)?.title ?? ''} ${e.label}'
                      .toLowerCase()
                      .contains(filter),
            )
            .toList();
    return Dialog(
      child: SizedBox(
        width: 900,
        height: 760,
        child: LayoutBuilder(
          builder: (context, viewport) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: viewport.maxHeight * .42,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Connections · ${source?.title ?? 'Unavailable object'}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close connections',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final name in [
                                'Used in',
                                'References',
                                'Saved views',
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(
                                      name == 'Saved views'
                                          ? name
                                          : '$name (${name == 'Used in' ? inbound.length : outbound.length})',
                                    ),
                                    selected: mode == name,
                                    onSelected: (_) => setState(() {
                                      mode = name;
                                      limit = 30;
                                    }),
                                  ),
                                ),
                              TextButton.icon(
                                onPressed:
                                    busy ||
                                        c.repository.readOnly ||
                                        source == null ||
                                        source.isDeleted ||
                                        source.isReadOnly
                                    ? null
                                    : add,
                                icon: const Icon(Icons.add_link),
                                label: const Text('Connect objects'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Filter connections',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) => setState(() {
                            filter = v.toLowerCase();
                            limit = 30;
                          }),
                        ),
                      ),
                      if (feedback != null)
                        Text(feedback!, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (edges.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No connections match this view. Place a live card, embed a source, or connect objects explicitly.',
                        ),
                      ),
                    for (final edge in edges.take(limit))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                edge.label,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                            for (final relation in authored.where(
                              (r) =>
                                  mode == 'References' &&
                                  r.id == edge.authoredId,
                            )) ...[
                              if (relation.note.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(relation.note),
                                ),
                              if (relation.warning(
                                    c.find(relation.target.id),
                                  ) !=
                                  null) ...[
                                Text(
                                  relation.warning(c.find(relation.target.id))!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                                if (c.find(relation.target.id)?.isDeleted ==
                                    false)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      onPressed:
                                          busy ||
                                              c.repository.readOnly ||
                                              source?.isReadOnly == true
                                          ? null
                                          : () async {
                                              final ok = await c
                                                  .reviewProjectConnection(
                                                    widget.id,
                                                    relation.id,
                                                  );
                                              if (mounted) {
                                                setState(
                                                  () => feedback = ok
                                                      ? 'Source version reviewed.'
                                                      : 'Could not review this connection.',
                                                );
                                              }
                                            },
                                      child: const Text('Mark source reviewed'),
                                    ),
                                  ),
                              ],
                            ],
                            ObjectReferenceCard(
                              controller: c,
                              reference: mode != 'References'
                                  ? edge.location
                                  : edge.target,
                              interactive: true,
                            ),
                            if (mode == 'Used in')
                              TextButton(
                                onPressed: () {
                                  c.openReference(
                                    edge.location,
                                    secondary: true,
                                    offset: edge.offset,
                                  );
                                  Navigator.pop(context);
                                },
                                child: const Text('Go to exact use'),
                              ),
                            if (mode == 'References' && edge.authoredId != null)
                              Wrap(
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: busy || c.repository.readOnly
                                        ? null
                                        : () async {
                                            final ok = await c
                                                .removeProjectConnection(
                                                  edge.source.id,
                                                  edge.authoredId!,
                                                );
                                            if (mounted) {
                                              setState(
                                                () => feedback = ok
                                                    ? 'Connection removed. Original objects remain intact.'
                                                    : 'Could not remove this connection.',
                                              );
                                            }
                                          },
                                    child: const Text('Remove connection'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    if (edges.length > limit)
                      TextButton(
                        onPressed: () => setState(() => limit += 30),
                        child: Text(
                          'Show more (${edges.length - limit} remaining)',
                        ),
                      ),
                    if (c.canUndoProjectMutation(widget.id))
                      TextButton(
                        onPressed: () => c.undoProjectMutation(widget.id),
                        child: const Text('Undo last connection change'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ObjectBridgeBar extends StatelessWidget {
  const ObjectBridgeBar({
    super.key,
    required this.controller,
    required this.object,
  });
  final WorkspaceController controller;
  final UniversalObject object;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            TextButton.icon(
              onPressed: () => showObjectConnections(context, c, object.id),
              icon: const Icon(Icons.hub_outlined, size: 17),
              label: const Text('Connections'),
            ),
            PopupMenuButton<String>(
              tooltip: 'Use this object elsewhere',
              onSelected: (value) {
                final ref = ObjectReference(object.id);
                switch (value) {
                  case 'card':
                    copyLiveReference(context, object);
                  case 'mention':
                    copyLiveReference(context, object, card: false);
                  case 'note':
                    useReferenceElsewhere(context, c, ref, canvas: false);
                  case 'canvas':
                    useReferenceElsewhere(context, c, ref, canvas: true);
                  case 'side':
                    c.openReference(ref, secondary: true);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'card', child: Text('Copy live card')),
                PopupMenuItem(
                  value: 'mention',
                  child: Text('Copy stable mention'),
                ),
                PopupMenuItem(value: 'note', child: Text('Embed in note…')),
                PopupMenuItem(value: 'canvas', child: Text('Place on Canvas…')),
                PopupMenuItem(value: 'side', child: Text('Open beside')),
              ],
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Text('Use elsewhere'),
                    SizedBox(width: 4),
                    Icon(Icons.expand_more, size: 16),
                  ],
                ),
              ),
            ),
            for (final key in ['courseId', 'project'])
              if (object.properties[key] is String &&
                  c.find(object.properties[key] as String)?.isDeleted == false)
                TextButton(
                  onPressed: () => c.openReference(
                    ObjectReference(object.properties[key] as String),
                    secondary: true,
                  ),
                  child: Text(
                    '${key == 'courseId' ? 'Course' : 'Project'}: ${c.find(object.properties[key] as String)!.title}',
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
