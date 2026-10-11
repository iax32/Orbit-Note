import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../app/workspace_controller.dart';
import '../../domain/gameplay_workbench.dart';
import '../../domain/universal_object.dart';
import '../../domain/wiki_links.dart';
import '../notes/note_link_dialog.dart';
import '../../domain/source_browser.dart';
import 'source_browser_dialog.dart';
import 'gameplay_release_workspace.dart';

Future<void> showGameplayWorkbench(
  BuildContext context,
  WorkspaceController c, {
  required String project,
  required String folder,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      GameplayWorkbench(controller: c, project: project, folder: folder),
);

class GameplayWorkbench extends ConsumerStatefulWidget {
  const GameplayWorkbench({
    super.key,
    required this.controller,
    required this.project,
    required this.folder,
  });
  final WorkspaceController controller;
  final String project, folder;
  @override
  ConsumerState<GameplayWorkbench> createState() => _GameplayWorkbenchState();
}

class _GameplayWorkbenchState extends ConsumerState<GameplayWorkbench> {
  String? selected;
  String? previewId;
  String filter = '';
  String buildFilter = '';
  String? message;
  bool busy = false;
  int page = 0;
  final next = TextEditingController();
  late final workspace = widget.controller.repository.workspaceId;
  WorkspaceController get c => widget.controller;
  @override
  void dispose() {
    next.dispose();
    super.dispose();
  }

  void choose(String id) {
    setState(() {
      selected = id;
      previewId = null;
      page = 0;
      next.text = c.gameplayResume(id)?['gameplayNextStep'] as String? ?? '';
    });
  }

  Future<void> run(Future<bool> Function() action, String success) async {
    if (c.repository.workspaceId != workspace) {
      setState(() => message = 'The workspace changed. Reopen the workbench.');
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final ok = await action();
      if (mounted) {
        setState(
          () => message = ok
              ? success
              : c.error ?? 'Could not save. Your sources are retained.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> record(
    UniversalObject mechanic,
    String kind, {
    UniversalObject? task,
  }) async {
    final result = await showDialog<UniversalObject>(
      context: context,
      builder: (_) => _GameplayRecordDialog(
        c: c,
        mechanic: mechanic,
        kind: kind,
        task: task,
      ),
    );
    if (mounted && result != null) {
      setState(() {
        previewId = result.id;
        message = 'Saved locally.';
      });
    }
  }

  Future<void> finding(UniversalObject source) async {
    final title = await _textPrompt(
      context,
      'Create fix task',
      'Finding / task title',
    );
    if (title == null || !mounted) return;
    await run(
      () async =>
          await c.createTaskFromFinding(
            finding: title,
            sourceNoteId: source.id,
            discipline: 'Gameplay',
            mechanicId: selected,
          ) !=
          null,
      'Fix task linked to this playtest.',
    );
  }

  void openBeside(UniversalObject mechanic, UniversalObject object) {
    c.openObject(mechanic.id);
    if (object.id != mechanic.id) c.openObject(object.id, secondary: true);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(workspaceProvider);
    final mechanics =
        c.activeObjects
            .where(
              (o) =>
                  o.typeId == 'orbit.note' &&
                  o.properties['category'] == 'Mechanic Spec' &&
                  (o.properties['project'] == widget.project ||
                      o.properties['folder'] == widget.folder ||
                      (o.properties['folder'] is String &&
                          (o.properties['folder'] as String).startsWith(
                            '${widget.folder}/',
                          ))),
            )
            .toList()
          ..sort((a, b) => a.title.compareTo(b.title));
    final mechanic = selected == null ? null : c.find(selected!);
    final usable = mechanic != null && !mechanic.isDeleted;
    final locked =
        busy ||
        c.repository.readOnly ||
        mechanic?.isReadOnly == true ||
        c.repository.workspaceId != workspace;
    final related = usable
        ? c.gameplayRelated(mechanic.id)
        : <UniversalObject>[];
    final builds =
        related
            .map((o) => o.properties['build'])
            .whereType<String>()
            .where((b) => b.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final filtered = related
        .where(
          (o) =>
              (buildFilter.isEmpty || o.properties['build'] == buildFilter) &&
              '${o.title} ${o.body} ${o.properties['category']}'
                  .toLowerCase()
                  .contains(filter.toLowerCase()),
        )
        .toList();
    final currentPage = page.clamp(
      0,
      (filtered.length - 1).clamp(0, 1000000) ~/ 30,
    );
    final preview = previewId == null ? mechanic : c.find(previewId!);
    final detail = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (usable)
              OutlinedButton.icon(
                onPressed: () => openBeside(mechanic, mechanic),
                icon: const Icon(Icons.edit_note),
                label: const Text('Edit specification'),
              ),
            if (usable)
              OutlinedButton.icon(
                onPressed: locked ? null : () => record(mechanic, 'code'),
                icon: const Icon(Icons.code),
                label: const Text('Attach code reference'),
              ),
            if (usable)
              FilledButton.tonalIcon(
                onPressed: locked ? null : () => record(mechanic, 'playtest'),
                icon: const Icon(Icons.sports_esports_outlined),
                label: const Text('Record playtest'),
              ),
            if (usable)
              OutlinedButton.icon(
                onPressed: locked
                    ? null
                    : () async {
                        final snapshot = mechanic;
                        final source = await showNoteLinkDialog(context, [
                          for (final o in c.activeObjects)
                            if (o.id != mechanic.id)
                              NoteLinkTarget(id: o.id, title: o.title),
                        ]);
                        if (source != null && mounted) {
                          await run(
                            () => c.linkGameplayResource(snapshot, source.id),
                            'Resource linked.',
                          );
                        }
                      },
                icon: const Icon(Icons.add_link),
                label: const Text('Link design or resource'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (usable)
          ExpansionTile(
            title: const Text('Continue development'),
            childrenPadding: const EdgeInsets.all(12),
            children: [
              TextField(
                controller: next,
                enabled: !locked,
                maxLength: 4000,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Next step',
                  helperText:
                      'Save open mechanic sources and their positions on this device.',
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: locked
                        ? null
                        : () => run(
                            () => c.saveGameplayResume(mechanic.id, next.text),
                            'Development position saved.',
                          ),
                    child: const Text('Save session'),
                  ),
                  FilledButton(
                    onPressed: locked || c.gameplayResume(mechanic.id) == null
                        ? null
                        : () async {
                            await run(
                              () => c.resumeGameplay(mechanic.id),
                              'Session restored. Changed sources start at fresh positions.',
                            );
                            if (context.mounted &&
                                message?.startsWith('Session restored') ==
                                    true) {
                              Navigator.pop(context);
                            }
                          },
                    child: const Text('Resume session'),
                  ),
                ],
              ),
              Text(
                '${related.where((o) => o.typeId == 'orbit.task' && !o.isCompleted && !['done', 'completed', 'cancelled'].contains(o.properties['status'])).length} unfinished linked tasks',
              ),
            ],
          ),
        const Divider(height: 24),
        if (preview == null || preview.isDeleted)
          const Text('Select a mechanic or source to read its details.')
        else ...[
          Text(preview.title, style: Theme.of(context).textTheme.titleLarge),
          if (preview.properties['sourceVersions'] is Map)
            for (final e
                in (preview.properties['sourceVersions'] as Map).entries)
              if (c.find(e.key)?.isDeleted != false ||
                  c.find(e.key)?.revision != e.value)
                Text(
                  '${c.find(e.key)?.title ?? 'Source'} ${c.find(e.key)?.isDeleted != false ? 'is missing' : 'has changed'}. Captured evidence is retained.',
                ),
          const SizedBox(height: 12),
          if (preview.typeId == 'orbit.note')
            MarkdownBody(data: preview.body, selectable: true)
          else
            Text(
              'Open this ${preview.typeId.replaceFirst('orbit.', '')} beside the specification.',
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: usable ? () => openBeside(mechanic, preview) : null,
            child: const Text('Open beside specification'),
          ),
        ],
      ],
    );
    final sources = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Implementation & evidence',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() {
            filter = v;
            page = 0;
          }),
          decoration: const InputDecoration(
            labelText: 'Search linked sources',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: builds.contains(buildFilter) ? buildFilter : '',
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Tested build'),
          items: [
            const DropdownMenuItem(value: '', child: Text('All builds')),
            for (final b in builds)
              DropdownMenuItem(
                value: b,
                child: Text(b, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(() {
            buildFilter = v ?? '';
            page = 0;
          }),
        ),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Link a diagram, decision, screenshot or task, or record code and playtests.',
            ),
          ),
        for (final o in filtered.skip(currentPage * 30).take(30))
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextButton(
                    onPressed: () => setState(() => previewId = o.id),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(o.title),
                    ),
                  ),
                  Text(
                    '${o.properties['category'] ?? o.typeId.replaceFirst('orbit.', '')}${o.properties['build'] == null ? '' : ' · ${o.properties['build']}'}${o.properties['verificationOutcome'] == null ? '' : ' · ${o.properties['verificationOutcome']}'}',
                  ),
                  if (o.typeId == 'orbit.task') ...[
                    Text(
                      'Status: ${o.properties['status'] ?? (o.isCompleted ? 'done' : 'todo')}',
                    ),
                    if (related.any(
                      (v) => v.properties['verificationTaskId'] == o.id,
                    ))
                      Text(
                        'Latest verification: ${related.firstWhere((v) => v.properties['verificationTaskId'] == o.id).properties['verificationOutcome']}',
                      ),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton(
                        onPressed: usable
                            ? () => openBeside(mechanic, o)
                            : null,
                        child: const Text('Open'),
                      ),
                      if (o.properties['category'] == 'Playtest')
                        TextButton(
                          onPressed: locked || o.isReadOnly
                              ? null
                              : () => finding(o),
                          child: const Text('Create fix task'),
                        ),
                      if (o.typeId == 'orbit.task')
                        TextButton(
                          onPressed: locked
                              ? null
                              : () =>
                                    record(mechanic!, 'verification', task: o),
                          child: const Text('Verify fix'),
                        ),
                      if (usable &&
                          gameplayIds(
                            mechanic.properties['gameplayResourceIds'],
                          ).contains(o.id))
                        TextButton(
                          onPressed: locked
                              ? null
                              : () => run(
                                  () => c.linkGameplayResource(
                                    mechanic,
                                    o.id,
                                    remove: true,
                                  ),
                                  'Unlinked. Original preserved.',
                                ),
                          child: const Text('Unlink'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (filtered.length > 30)
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: currentPage == 0
                    ? null
                    : () => setState(() => page = currentPage - 1),
                child: const Text('Previous'),
              ),
              Text('${currentPage + 1} / ${(filtered.length + 29) ~/ 30}'),
              TextButton(
                onPressed: (currentPage + 1) * 30 >= filtered.length
                    ? null
                    : () => setState(() => page = currentPage + 1),
                child: const Text('Next'),
              ),
            ],
          ),
        if (usable)
          for (final id in gameplayIds(
            mechanic.properties['gameplayResourceIds'],
          ))
            if (c.find(id)?.isDeleted != false)
              ListTile(
                title: const Text('Missing linked resource'),
                subtitle: Text(id),
                trailing: IconButton(
                  tooltip: 'Remove missing link',
                  icon: const Icon(Icons.link_off),
                  onPressed: locked
                      ? null
                      : () => run(
                          () => c.linkGameplayResource(
                            mechanic,
                            id,
                            remove: true,
                          ),
                          'Missing link removed.',
                        ),
                ),
              ),
      ],
    );
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Gameplay workbench',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: mechanics.isEmpty
                              ? null
                              : () => showDialog<void>(
                                  context: context,
                                  builder: (_) => GameplayReleaseWorkspace(
                                    controller: c,
                                    mechanicIds: mechanics
                                        .map((m) => m.id)
                                        .toList(),
                                  ),
                                ),
                          icon: const Icon(Icons.fact_check_outlined),
                          label: const Text('Playtest & Release'),
                        ),
                        for (final m in mechanics)
                          ChoiceChip(
                            label: Text(m.title),
                            selected: selected == m.id,
                            onSelected: (_) => choose(m.id),
                          ),
                        OutlinedButton.icon(
                          onPressed:
                              busy ||
                                  c.repository.readOnly ||
                                  c.repository.workspaceId != workspace
                              ? null
                              : () async {
                                  final name = await _textPrompt(
                                    context,
                                    'New mechanic',
                                    'Mechanic name',
                                  );
                                  if (name != null && mounted) {
                                    await run(
                                      () async {
                                        final o = await c.create(
                                          'orbit.note',
                                          title: name,
                                          body:
                                              '# $name\n\n## Purpose & feel\n\n## Input & control rules\n\n## Feedback\n\n## Edge cases\n\n## Acceptance criteria\n',
                                          properties: {
                                            'folder': widget.folder,
                                            'project': widget.project,
                                            'category': 'Mechanic Spec',
                                          },
                                        );
                                        if (o != null && mounted) choose(o.id);
                                        return o != null;
                                      },
                                      'Mechanic created. Edit its specification to define the behaviour.',
                                    );
                                  }
                                },
                          icon: const Icon(Icons.add),
                          label: const Text('New mechanic'),
                        ),
                      ],
                    ),
                    if (message != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(message!),
                        ),
                      ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final large =
                            MediaQuery.textScalerOf(context).scale(14) / 14;
                        if (constraints.maxWidth < 800 * large) {
                          return Column(
                            children: [
                              detail,
                              const Divider(height: 32),
                              sources,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: detail),
                            const SizedBox(width: 28),
                            Expanded(flex: 2, child: sources),
                          ],
                        );
                      },
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

Future<String?> _textPrompt(
  BuildContext context,
  String title,
  String label,
) async {
  final input = TextEditingController();
  final route = DialogRoute<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      scrollable: true,
      title: Text(title),
      content: TextField(
        controller: input,
        autofocus: true,
        maxLength: 300,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (input.text.trim().isNotEmpty) {
              Navigator.pop(ctx, input.text.trim());
            }
          },
          child: const Text('Create'),
        ),
      ],
    ),
  );
  final value = await Navigator.of(context).push(route);
  await route.completed;
  input.dispose();
  return value;
}

class _GameplayRecordDialog extends StatefulWidget {
  const _GameplayRecordDialog({
    required this.c,
    required this.mechanic,
    required this.kind,
    this.task,
  });
  final WorkspaceController c;
  final UniversalObject mechanic;
  final UniversalObject? task;
  final String kind;
  @override
  State<_GameplayRecordDialog> createState() => _GameplayRecordDialogState();
}

class _GameplayRecordDialogState extends State<_GameplayRecordDialog> {
  final fields = <String, TextEditingController>{};
  final resources = <String>[];
  String outcome = 'passed';
  String? error;
  bool busy = false;
  late final String workspace = widget.c.repository.workspaceId;
  TextEditingController input(String key) =>
      fields.putIfAbsent(key, () => TextEditingController());

  Future<void> browseExcerpt() async {
    final value = await showDialog<SourceExcerpt>(
      context: context,
      builder: (_) => const SourceBrowserDialog(capture: true),
    );
    if (!mounted || value == null) return;
    setState(() {
      input('repository').text = value.repository;
      input('path').text = value.path;
      input('start').text = '${value.start}';
      input('end').text = '${value.end}';
      input('excerpt').text = value.text;
      // A different capture must never inherit an unrelated revision claim.
      input('commit').clear();
      input('branch').clear();
      error = null;
    });
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(String key, String label, {int lines = 1, int max = 20000}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          key: ValueKey('gameplay-$key'),
          controller: input(key),
          enabled: !busy,
          minLines: lines,
          maxLines: lines == 1 ? 1 : 8,
          maxLength: max,
          decoration: InputDecoration(
            labelText: label,
            alignLabelWithHint: true,
          ),
        ),
      );
  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    final c = widget.c;
    if (c.repository.workspaceId != workspace ||
        c.find(widget.mechanic.id)?.body != widget.mechanic.body ||
        c.find(widget.mechanic.id)?.updatedAt != widget.mechanic.updatedAt ||
        c.find(widget.mechanic.id)?.revision != widget.mechanic.revision) {
      setState(() {
        busy = false;
        error = 'The mechanic changed. Close and reopen this form.';
      });
      return;
    }
    final code = widget.kind == 'code'
        ? GameplayCodeReference(
            repository: input('repository').text,
            path: input('path').text.trim(),
            revision: input('commit').text.trim(),
            startLine: int.tryParse(input('start').text) ?? 0,
            endLine: int.tryParse(input('end').text) ?? 0,
            excerpt: input('excerpt').text,
            branch: input('branch').text.trim(),
          )
        : null;
    final result = await c.createGameplayRecord(
      mechanicId: widget.mechanic.id,
      kind: widget.kind,
      title: input('title').text,
      build: input('build').text,
      expected: input('expected').text,
      observed: input('observed').text,
      taskId: widget.task?.id ?? '',
      outcome: outcome,
      code: code,
      resources: resources,
    );
    if (!mounted) return;
    if (result != null) {
      Navigator.pop(context, result);
    } else {
      setState(() {
        busy = false;
        error = c.error ?? 'Could not save this record.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      scrollable: true,
      title: Text(
        widget.kind == 'code'
            ? 'Code reference'
            : widget.kind == 'playtest'
            ? 'Build playtest'
            : 'Verify ${widget.task!.title}',
      ),
      content: SizedBox(
        width: 620,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            field('title', 'Record title', max: 300),
            if (widget.kind == 'code') ...[
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : browseExcerpt,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Capture from source file'),
                ),
              ),
              const Text(
                'Captured files may contain uncommitted changes. Verify that the excerpt matches the commit you enter. Repository access is not required to read saved evidence.',
              ),
              const SizedBox(height: 12),
              field('repository', 'Repository name or location', max: 2000),
              field('path', 'Relative file path', max: 2000),
              field('commit', 'Full Git commit hash', max: 64),
              field('branch', 'Branch when captured (optional)', max: 500),
              field('start', 'First line', max: 8),
              field('end', 'Last line', max: 8),
              field('excerpt', 'Exact source excerpt', lines: 5, max: 100000),
            ] else ...[
              field('build', 'Build tested', max: 300),
              field('expected', 'Expected behaviour', lines: 3),
              field('observed', 'Observations / reproduction steps', lines: 3),
              if (widget.kind == 'verification')
                DropdownButtonFormField<String>(
                  initialValue: outcome,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Result'),
                  items: [
                    for (final s in ['passed', 'failed', 'blocked'])
                      DropdownMenuItem(value: s, child: Text(s)),
                  ],
                  onChanged: busy
                      ? null
                      : (v) => setState(() => outcome = v ?? 'passed'),
                ),
              if (widget.kind == 'verification')
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Verification preserves history. It does not complete or reopen the task automatically.',
                  ),
                ),
            ],
            const SizedBox(height: 12),
            for (final id in resources)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(widget.c.find(id)?.title ?? 'Missing evidence'),
                trailing: IconButton(
                  tooltip: 'Remove evidence link',
                  onPressed: busy
                      ? null
                      : () => setState(() => resources.remove(id)),
                  icon: const Icon(Icons.close),
                ),
              ),
            OutlinedButton.icon(
              onPressed: busy || resources.length >= 40
                  ? null
                  : () async {
                      final result = await showNoteLinkDialog(context, [
                        for (final o in widget.c.activeObjects)
                          if (o.id != widget.mechanic.id &&
                              !resources.contains(o.id))
                            NoteLinkTarget(id: o.id, title: o.title),
                      ]);
                      if (result != null && mounted) {
                        setState(() => resources.add(result.id));
                      }
                    },
              icon: const Icon(Icons.attach_file),
              label: const Text('Link screenshot, decision or code evidence'),
            ),
            if (error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? 'Saving…' : 'Save record'),
        ),
      ],
    ),
  );
}
