import '../../app/orbit_components.dart';
import 'object_connection_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';
import '../../app/session_state.dart';
import '../../domain/project_context.dart';
import '../../domain/research_workspace.dart';
import '../../domain/universal_object.dart';
import 'workspace_views.dart';
import 'object_bridges.dart';

Future<void> showProjectWorkspace(
  BuildContext context,
  WorkspaceController c,
) => showOrbitDialog<void>(
  context: context,
  builder: (_) => Dialog(
    child: SizedBox(
      width: 720,
      height: 720,
      child: ProjectContextPanel(controller: c, dialog: true),
    ),
  ),
);

class ProjectContextBar extends StatelessWidget {
  const ProjectContextBar({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller, id = c.selectedProjectId;
    final generation = c.workspaceGeneration;
    if (id == null && c.projectChoices.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: OrbitColors.of(context).divider),
        ),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.workspaces_outline, size: 16),
            label: Text(
              id == null
                  ? 'Choose project'
                  : c.projectChoices[id] ?? 'Unavailable project',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onPressed: c.projectContextAvailable
                ? () async {
                    final selected = await _pickProject(context, c);
                    if (selected != null &&
                        context.mounted &&
                        generation == c.workspaceGeneration) {
                      await c.selectProject(selected);
                    }
                  }
                : null,
          ),
          if (id != null) ...[
            TextButton.icon(
              icon: const Icon(Icons.dashboard_outlined, size: 16),
              label: const Text('Project workspace'),
              onPressed: () => showProjectWorkspace(context, c),
            ),
            IconButton(
              tooltip: 'Search this project',
              icon: const Icon(Icons.search, size: 18),
              onPressed: () => c.navigate(OrbitDestination.search),
            ),
            IconButton(
              tooltip: 'Clear project scope',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => c.selectProject(null),
            ),
          ],
        ],
      ),
    );
  }
}

Future<String?> _pickProject(
  BuildContext context,
  WorkspaceController c,
) async {
  var query = '';
  final generation = c.workspaceGeneration;
  return showOrbitDialog<String>(
    context: context,
    builder: (_) => Consumer(
      builder: (_, ref, _) {
        ref.watch(workspaceProvider);
        final choices = generation == c.workspaceGeneration
            ? c.projectChoices.entries.toList()
            : <MapEntry<String, String>>[];
        choices.sort((a, b) => a.value.compareTo(b.value));
        return StatefulBuilder(
          builder: (context, setState) {
            final matches = choices
                .where(
                  (e) => '${e.value} ${e.key}'.toLowerCase().contains(
                    query.toLowerCase(),
                  ),
                )
                .toList();
            return AlertDialog(
              title: const Text('Choose project'),
              content: SizedBox(
                width: 480,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Find a project',
                      ),
                      onChanged: (v) => setState(() => query = v),
                    ),
                    Expanded(
                      child: matches.isEmpty
                          ? const Center(
                              child: Text(
                                'No projects found. Create a project from the explorer.',
                              ),
                            )
                          : ListView.builder(
                              itemCount: matches.length,
                              itemBuilder: (_, i) => ListTile(
                                title: Text(matches[i].value),
                                subtitle: Text(matches[i].key),
                                onTap: () {
                                  if (context.mounted &&
                                      generation == c.workspaceGeneration &&
                                      c.projectChoices.containsKey(
                                        matches[i].key,
                                      )) {
                                    Navigator.pop(context, matches[i].key);
                                  }
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    ),
  );
}

class ProjectContextPanel extends ConsumerStatefulWidget {
  const ProjectContextPanel({
    super.key,
    required this.controller,
    this.dialog = false,
  });
  final WorkspaceController controller;
  final bool dialog;
  @override
  ConsumerState<ProjectContextPanel> createState() =>
      _ProjectContextPanelState();
}

class _ProjectContextPanelState extends ConsumerState<ProjectContextPanel> {
  final nextStep = TextEditingController();
  String? loadedProject;
  int? loadedGeneration;
  String query = '', tab = 'Work', type = 'All', feedback = '';
  int page = 0;
  bool busy = false;
  @override
  void dispose() {
    nextStep.dispose();
    super.dispose();
  }

  Future<void> run(Future<bool?> Function() operation) async {
    if (!mounted || busy) return;
    final c = widget.controller,
        generation = widget.controller.workspaceGeneration;
    final project = c.selectedProjectId;
    bool owns() =>
        mounted &&
        generation == c.workspaceGeneration &&
        project == c.selectedProjectId;
    setState(() {
      busy = true;
      feedback = '';
    });
    try {
      final ok = await operation();
      if (owns()) {
        setState(
          () => feedback = ok == null
              ? ''
              : ok
              ? 'Saved locally.'
              : 'Could not complete. Check save status or reopen the current source.',
        );
      }
    } finally {
      if (owns()) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(workspaceProvider);
    final c = widget.controller, id = c.selectedProjectId;
    final generation = c.workspaceGeneration;
    if (loadedProject != id || loadedGeneration != generation) {
      loadedProject = id;
      loadedGeneration = generation;
      busy = false;
      feedback = '';
      nextStep.text = id == null
          ? ''
          : (c.projectRecord(id)['draft'] is String
                ? c.projectRecord(id)['draft'] as String
                : c.projectRecord(id)['nextStep'] is String
                ? c.projectRecord(id)['nextStep'] as String
                : '');
      page = 0;
    }
    final records = id == null ? <UniversalObject>[] : c.projectObjects(id);
    final filtered = records
        .where(
          (o) =>
              (type == 'All' || o.typeId == 'orbit.${type.toLowerCase()}') &&
              '${o.title} ${o.properties['tags'] ?? ''}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    if (tab == 'Work') {
      page = page.clamp(0, filtered.isEmpty ? 0 : (filtered.length - 1) ~/ 30);
    }
    final pending = records
        .where((o) => o.typeId == 'orbit.task' && !o.isCompleted)
        .length;
    final colors = OrbitColors.of(context);
    return Material(
      color: colors.panel,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    id == null
                        ? 'Project workspace'
                        : c.projectChoices[id] ?? 'Unavailable project',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: c.projectPanelPinned
                      ? 'Unpin project panel'
                      : 'Keep project beside documents',
                  onPressed: id == null
                      ? null
                      : () => c.pinProjectPanel(!c.projectPanelPinned),
                  icon: Icon(
                    c.projectPanelPinned
                        ? Icons.push_pin
                        : Icons.push_pin_outlined,
                  ),
                ),
                IconButton(
                  tooltip: 'Close project panel',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    if (widget.dialog) {
                      Navigator.pop(context);
                    } else {
                      c.pinProjectPanel(false);
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: id == null
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Choose a project in the workspace bar. Your documents stay open.',
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    children: [
                      Text(
                        '$pending unfinished tasks · ${records.length} linked objects',
                        style: TextStyle(color: colors.subtle),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final name in [
                            'Work',
                            'Connections',
                            'Activity',
                            'Continue',
                          ])
                            ChoiceChip(
                              label: Text(name),
                              selected: tab == name,
                              onSelected: (_) => setState(() {
                                tab = name;
                                page = 0;
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (feedback.isNotEmpty)
                        Semantics(
                          liveRegion: true,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(feedback),
                          ),
                        ),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final o
                              in records
                                  .where((o) => c.canUndoProjectMutation(o.id))
                                  .take(10))
                            TextButton.icon(
                              onPressed: busy
                                  ? null
                                  : () =>
                                        run(() => c.undoProjectMutation(o.id)),
                              icon: const Icon(Icons.undo),
                              label: Text(
                                'Undo ${o.title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                      if (tab == 'Work') ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final kind in ['note', 'task', 'canvas'])
                              OutlinedButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => c.create('orbit.$kind'),
                                icon: const Icon(Icons.add, size: 16),
                                label: Text('New $kind'),
                              ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => run(() async {
                                      final chosen =
                                          await showObjectReferencePicker(
                                            context,
                                            c,
                                            title:
                                                'Assign existing object to this project',
                                          );
                                      if (chosen == null) return null;
                                      if (!mounted ||
                                          generation != c.workspaceGeneration ||
                                          id != c.selectedProjectId) {
                                        return false;
                                      }
                                      return c.assignObjectProject(
                                        chosen.id,
                                        id,
                                        expected: chosen,
                                        expectedGeneration: generation,
                                      );
                                    }),
                              child: const Text('Assign existing'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Filter project objects',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) => setState(() {
                            query = v;
                            page = 0;
                          }),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final name in [
                              'All',
                              'Note',
                              'Task',
                              'Canvas',
                              'File',
                              'Event',
                              'View',
                            ])
                              ChoiceChip(
                                label: Text(name),
                                selected: type == name,
                                onSelected: (_) => setState(() {
                                  type = name;
                                  page = 0;
                                }),
                              ),
                          ],
                        ),
                        if (filtered.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No matching project objects.'),
                          ),
                        for (final o in filtered.skip(page * 30).take(30))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(objectIcon(o.typeId), size: 18),
                            title: Text(o.title),
                            subtitle: Text(
                              o.properties['isCreativeBrief'] == true
                                  ? 'Project brief'
                                  : o.typeId.replaceFirst('orbit.', ''),
                            ),
                            onTap: () => c.openObject(o.id),
                            trailing: IconButton(
                              tooltip: 'Open beside current document',
                              icon: const Icon(Icons.vertical_split_outlined),
                              onPressed: () =>
                                  c.openObject(o.id, secondary: true),
                            ),
                          ),
                        _pages(filtered.length),
                      ],
                      if (tab == 'Connections') ..._connections(c, records),
                      if (tab == 'Activity') ...[
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Record project activity'),
                          subtitle: const Text(
                            'Only deliberate in-app actions. Paused actions are not recorded. Up to 300 entries; clear at any time.',
                          ),
                          value: c.projectRecording,
                          onChanged: c.setProjectRecording,
                        ),
                        TextButton(
                          onPressed: c.clearProjectActivity,
                          child: const Text('Clear activity history'),
                        ),
                        ..._activity(c, id),
                      ],
                      if (tab == 'Continue') ...[
                        TextField(
                          controller: nextStep,
                          onChanged: c.setProjectContinuationDraft,
                          minLines: 3,
                          maxLines: 8,
                          maxLength: 4000,
                          decoration: const InputDecoration(
                            labelText: 'Where to continue',
                            hintText:
                                'Next action, unanswered question, or what to check…',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton(
                              onPressed: busy
                                  ? null
                                  : () => run(
                                      () => c.saveProjectContinuation(
                                        nextStep.text,
                                      ),
                                    ),
                              child: const Text('Save working position'),
                            ),
                            OutlinedButton(
                              onPressed:
                                  busy || c.projectRecord(id)['context'] is! Map
                                  ? null
                                  : () => run(c.resumeProject),
                              child: const Text('Resume workspace'),
                            ),
                            TextButton(
                              onPressed: () => run(() async {
                                final ok = await c.clearProjectSavedContext();
                                if (ok) nextStep.clear();
                                return ok;
                              }),
                              child: const Text('Reset project context'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Restores current documents, tabs, split, reading positions and Canvas cameras. Missing documents remain missing. This position is private to this device.',
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _pages(int count) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    children: [
      Text(
        '${count == 0 ? 0 : page * 30 + 1}–${((page + 1) * 30).clamp(0, count)} of $count',
      ),
      IconButton(
        tooltip: 'Previous page',
        onPressed: page == 0 ? null : () => setState(() => page--),
        icon: const Icon(Icons.chevron_left),
      ),
      IconButton(
        tooltip: 'Next page',
        onPressed: (page + 1) * 30 >= count
            ? null
            : () => setState(() => page++),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
  List<Widget> _activity(WorkspaceController c, String id) {
    final raw = c.projectRecord(id)['events'];
    final events = raw is List
        ? raw
              .whereType<Map>()
              .where((e) => e['object'] is String && e['action'] is String)
              .toList()
        : <Map>[];
    page = page.clamp(0, events.isEmpty ? 0 : (events.length - 1) ~/ 30);
    return [
      if (events.isEmpty) const Text('No recorded activity yet.'),
      for (final e in events.skip(page * 30).take(30))
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            '${e['action']} · ${c.find(e['object'] as String?)?.title ?? 'Unavailable object'}',
          ),
          subtitle: Text(e['at']?.toString() ?? ''),
          onTap: c.find(e['object'] as String?)?.isDeleted == false
              ? () => c.openObject(e['object'] as String)
              : null,
        ),
      _pages(events.length),
    ];
  }

  List<Widget> _connections(
    WorkspaceController c,
    List<UniversalObject> records,
  ) {
    final generation = c.workspaceGeneration, project = c.selectedProjectId;
    final entries = [
      for (final o in records)
        for (final r in ProjectConnection.read(
          o.properties['orbitConnections'],
        ))
          (source: o, link: r),
    ];
    page = page.clamp(0, entries.isEmpty ? 0 : (entries.length - 1) ~/ 30);
    return [
      TextButton.icon(
        icon: const Icon(Icons.add_link),
        label: const Text('Add meaningful connection'),
        onPressed: () async {
          final source = await showObjectReferencePicker(
            context,
            c,
            project: project,
            title: 'Choose source object',
          );
          if (source != null &&
              mounted &&
              generation == c.workspaceGeneration &&
              project == c.selectedProjectId) {
            await _connectionDialog(context, c, source.id);
          }
        },
      ),
      const Text(
        'Read connections left to right: source implements / supports / blocks / is verified by target. Source versions are checked locally.',
      ),
      if (entries.isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No authored connections yet. Existing backlinks remain in the object inspector.',
          ),
        ),
      for (final entry in entries.skip(page * 30).take(30)) ...[
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            '${entry.source.title} → ${entry.link.kind} → ${c.find(entry.link.target.id)?.title ?? 'Unavailable source'}',
          ),
          subtitle: Text(
            [
              if (entry.link.target.isPrecise) entry.link.target.fragment,
              if (entry.link.note.isNotEmpty) entry.link.note,
              if (entry.link.warning(c.find(entry.link.target.id)) != null)
                entry.link.warning(c.find(entry.link.target.id))!,
            ].join('\n'),
          ),
          onTap: c.find(entry.link.target.id)?.isDeleted == false
              ? () {
                  c.openProjectReference(
                    entry.link.target,
                    sourceVersion: entry.link.raw['versionToken'] is String
                        ? entry.link.raw['versionToken'] as String
                        : null,
                  );
                }
              : null,
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: busy
                  ? null
                  : () => run(
                      () => c.reviewProjectConnection(
                        entry.source.id,
                        entry.link.id,
                      ),
                    ),
              child: const Text('Mark reviewed'),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => run(
                      () => c.removeProjectConnection(
                        entry.source.id,
                        entry.link.id,
                      ),
                    ),
              child: const Text('Remove connection'),
            ),
          ],
        ),
      ],
      _pages(entries.length),
    ];
  }
}

Future<void> _connectionDialog(
  BuildContext context,
  WorkspaceController c,
  String sourceId,
) async {
  final source = c.find(sourceId);
  if (source == null) return;
  final expectedSourceVersion = researchVersion(source);
  final generation = c.workspaceGeneration;
  final chosen = await showObjectReferencePicker(
    context,
    c,
    exclude: sourceId,
    title: 'Choose target',
  );
  if (chosen == null ||
      !context.mounted ||
      generation != c.workspaceGeneration) {
    return;
  }
  await showObjectConnectionEditor(
    context,
    c,
    source,
    chosen,
    generation: generation,
    expectedSourceVersion: expectedSourceVersion,
  );
}
