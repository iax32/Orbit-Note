import '../../app/orbit_components.dart';
import 'life_pack_dialog.dart';
import 'finance_workspace.dart';
import '../../domain/event_recurrence.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/workspace_controller.dart';
import '../../domain/calendar_event.dart';
import '../../domain/life_workspace.dart';
import '../../domain/life_templates.dart';
import '../../domain/universal_object.dart';
import 'course_hub.dart';

Future<void> showLifeWorkspace(
  BuildContext context,
  WorkspaceController c, {
  String? objectId,
}) => showOrbitDialog<void>(
  context: context,
  builder: (_) => LifeWorkspace(controller: c, initialId: objectId),
);

Future<void> saveObjectAsLifeTemplate(
  BuildContext context,
  WorkspaceController c,
  UniversalObject source,
) async {
  final title = TextEditingController(text: source.title),
      generation = c.workspaceGeneration;
  var saving = false;
  String? error;
  try {
    await showOrbitDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: const Text('Save personal template'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    enabled: !saving,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Template title',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Reuse this note or Canvas from Life → Templates. Canvas cards keep their original object links.',
                  ),
                  if (error != null)
                    Semantics(liveRegion: true, child: Text(error!)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (title.text.trim().isEmpty) {
                          update(() => error = 'Enter a title.');
                          return;
                        }
                        if (generation != c.workspaceGeneration) {
                          update(
                            () => error =
                                'The Vault changed. Open this action again.',
                          );
                          return;
                        }
                        update(() => saving = true);
                        final result = await c.savePersonalTemplate(
                          source,
                          title.text.trim(),
                        );
                        if (!ctx.mounted) return;
                        if (result == null) {
                          update(() {
                            saving = false;
                            error =
                                c.error ??
                                'Could not save. Refresh the source and retry; your title is kept here.';
                          });
                          return;
                        }
                        Navigator.pop(ctx);
                      },
                child: Text(saving ? 'Saving…' : 'Save template'),
              ),
            ],
          ),
        ),
      ),
    );
  } finally {
    title.dispose();
  }
}

class LifeWorkspace extends ConsumerStatefulWidget {
  const LifeWorkspace({super.key, required this.controller, this.initialId});
  final String? initialId;
  final WorkspaceController controller;
  @override
  ConsumerState<LifeWorkspace> createState() => _LifeWorkspaceState();
}

class _LifeWorkspaceState extends ConsumerState<LifeWorkspace> {
  String _section = 'Home', _query = '', _filter = 'active';
  String? _selected, _notice;
  bool _busy = false;
  int _limit = 40;
  WorkspaceController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    final kind = lifeKind(c.find(widget.initialId ?? ''));
    if (kind != null) {
      _selected = widget.initialId;
      _section = kind.section;
      _filter = 'all';
    }
  }

  Future<void> _run(Future<Object?> Function() action) async {
    if (_busy) return;
    final generation = c.workspaceGeneration;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final result = await action();
      if (!mounted) return;
      if (generation != c.workspaceGeneration) {
        setState(
          () => _notice =
              'The Vault changed. Open Life again in the current Vault.',
        );
        return;
      }
      if (result == null || result == false) {
        setState(
          () => _notice =
              c.error ??
              'The change could not be saved. Refresh and try again.',
        );
      } else if (result is UniversalObject) {
        setState(() {
          final kind = lifeKind(result);
          if (kind != null) {
            _selected = result.id;
            _section = kind.section;
          } else {
            _notice =
                'Added “${result.title}”. It is available in connected items and the main workspace.';
          }
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => _notice = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _open(UniversalObject o) {
    Navigator.pop(context);
    c.openObject(o.id);
  }

  Future<void> _edit({
    UniversalObject? object,
    LifeKind? kind,
    LifePreset? preset,
    Map<String, dynamic> fields = const {},
  }) async {
    final generation = c.workspaceGeneration;
    final result = await showOrbitDialog<LifeFormResult>(
      context: context,
      builder: (_) => LifeRecordForm(
        controller: c,
        object: object,
        kind: kind ?? preset?.kind ?? lifeKind(object)!,
        preset: preset,
        fields: fields,
        persist: true,
      ),
    );
    if (result == null || !mounted || generation != c.workspaceGeneration) {
      return;
    }
    if (result.savedId != null) {
      setState(() {
        _selected = result.savedId;
        _section = result.kind.section;
      });
    }
  }

  Future<void> _library() async {
    final preset = await showOrbitDialog<LifePreset>(
      context: context,
      builder: (_) => const _LifeLibrary(),
    );
    if (preset != null && mounted) await _edit(preset: preset);
  }

  Future<String?> _name(String title, {String initial = ''}) async {
    final input = TextEditingController(text: initial);
    try {
      return await showOrbitDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: input,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Title'),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) Navigator.pop(ctx, v.trim());
            },
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
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    } finally {
      input.dispose();
    }
  }

  Future<DateTime?> _date() => showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(1900),
    lastDate: DateTime(2200),
  );
  Future<void> _action(UniversalObject source, {bool milestone = false}) async {
    final generation = c.workspaceGeneration;
    final title = await _name(
      milestone ? 'Add milestone' : 'Add linked action',
    );
    if (title == null || !mounted) return;
    final date = await _date();
    if (date == null || !mounted || generation != c.workspaceGeneration) return;
    await _run(
      () => c.lifeAction(
        source,
        title,
        dueDate: calendarDate(date),
        milestone: milestone,
      ),
    );
  }

  Future<void> _schedule(UniversalObject o) async {
    final generation = c.workspaceGeneration;
    final date = await _date();
    if (date == null || !mounted || generation != c.workspaceGeneration) return;
    await _run(() async {
      if (lifeKind(o) == LifeKind.program) {
        final count = await c.scheduleLifeProgram(o, date);
        if (mounted) {
          setState(
            () => _notice =
                '$count calendar entries available. ${c.error ?? 'Existing entries are reused on retry.'}',
          );
        }
        return count > 0;
      }
      return c.scheduleLife(o, date);
    });
  }

  Future<void> _board() async {
    final objects = c.lifeIndex.records
        .where((o) => _section == 'Home' || lifeKind(o)?.section == _section)
        .where((o) => !['habitLog', 'routineLog'].contains(lifeKind(o)?.name))
        .toList();
    if (objects.isEmpty) {
      setState(
        () => _notice =
            'Add a record first, then place its live card on a board.',
      );
      return;
    }
    final generation = c.workspaceGeneration;
    final chosen = await _chooseObjects(
      context,
      c,
      objects.map((o) => o.id).toList(),
      initial: objects.take(12).map((o) => o.id).toList(),
      title: 'Choose live board cards',
    );
    if (chosen == null ||
        chosen.isEmpty ||
        !mounted ||
        generation != c.workspaceGeneration) {
      return;
    }
    final title = await _name(
      'Create connected board',
      initial: '$_section board',
    );
    if (title != null && mounted && generation == c.workspaceGeneration) {
      await _run(() async {
        final board = await c.createLifeBoard(title, chosen);
        if (board != null && mounted) _open(board);
        return board;
      });
    }
  }

  Future<void> _saveTemplate() async {
    final generation = c.workspaceGeneration;
    final ids = await _chooseObjects(
      context,
      c,
      c.activeObjects
          .where(
            (o) =>
                ['orbit.note', 'orbit.canvas'].contains(o.typeId) &&
                lifeKind(o) != LifeKind.template,
          )
          .map((o) => o.id)
          .toList(),
      single: true,
      title: 'Save a note or Canvas as a template',
    );
    if (ids == null ||
        ids.isEmpty ||
        !mounted ||
        generation != c.workspaceGeneration) {
      return;
    }
    final source = c.find(ids.first)!;
    final title = await _name('Personal template', initial: source.title);
    if (title != null && mounted && generation == c.workspaceGeneration) {
      await _run(() => c.savePersonalTemplate(source, title));
    }
  }

  Widget _button(String label, VoidCallback action, {IconData? icon}) =>
      OutlinedButton.icon(
        onPressed: _busy || c.repository.readOnly ? null : action,
        icon: Icon(icon ?? Icons.add, size: 16),
        label: Text(label),
      );
  Widget _heading(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    ref.watch(workspaceProvider);
    final index = c.lifeIndex, selected = c.find(_selected ?? '');
    final rows =
        index.records
            .where(
              (o) =>
                  lifeKind(o)?.section == _section &&
                  (_filter == 'all' || lifeData(o)['state'] == _filter) &&
                  '${o.title} ${lifeData(o)['category'] ?? ''} ${o.body}'
                      .toLowerCase()
                      .contains(_query.toLowerCase()),
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1260, maxHeight: 900),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.spa_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Life workspace',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close Life workspace',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                  IconButton(
                    tooltip: 'Open Finance',
                    onPressed: () => showFinanceWorkspace(context, c),
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                  ),
                ],
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_notice != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Semantics(
                  liveRegion: true,
                  child: SelectableText(_notice!),
                ),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final s in lifeSections)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(s),
                        selected: _section == s,
                        onSelected: (_) => setState(() {
                          _section = s;
                          _selected = null;
                          _limit = 40;
                        }),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final detail =
                      selected != null &&
                      lifeKind(selected)?.section == _section;
                  final wide =
                      constraints.maxWidth >= 900 &&
                      MediaQuery.textScalerOf(ctx).scale(14) < 23;
                  if (detail && !wide) {
                    return ListView(
                      key: ValueKey('life-detail:${selected.id}'),
                      padding: const EdgeInsets.all(20),
                      children: [
                        TextButton.icon(
                          onPressed: () => setState(() => _selected = null),
                          icon: const Icon(Icons.arrow_back),
                          label: Text('Back to $_section'),
                        ),
                        ..._details(selected, index),
                      ],
                    );
                  }
                  final list = ListView(
                    key: ValueKey('life-list:$_section'),
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (_section == 'Home')
                        ..._home(index)
                      else ...[
                        _heading(
                          _section,
                          _descriptions[_section] ??
                              'Saved locally, linked throughout Orbit.',
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final kind in _kinds(_section))
                              _button(
                                'New ${kind.label.toLowerCase()}',
                                () => _edit(kind: kind),
                              ),
                            _button(
                              'Starter library',
                              _library,
                              icon: Icons.auto_stories_outlined,
                            ),
                            _button(
                              'Live board',
                              _board,
                              icon: Icons.dashboard_outlined,
                            ),
                            if (_section == 'Templates')
                              _button(
                                'Save existing note or Canvas',
                                _saveTemplate,
                                icon: Icons.bookmark_add_outlined,
                              ),
                            if (_section == 'Reviews')
                              for (final p in ['week', 'month', 'year'])
                                _button(
                                  '$p review',
                                  () => _run(
                                    () => c.createLifeReview(p, DateTime.now()),
                                  ),
                                  icon: Icons.fact_check_outlined,
                                ),
                            if (_section == 'Learning')
                              _button(
                                'Courses & study',
                                () => showCourseHub(context, c),
                                icon: Icons.school_outlined,
                              ),
                            _button(
                              'Finance',
                              () => showFinanceWorkspace(context, c),
                              icon: Icons.account_balance_wallet_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            labelText: 'Search this area',
                          ),
                          onChanged: (v) => setState(() {
                            _query = v;
                            _limit = 40;
                          }),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final state in [
                              'active',
                              'completed',
                              'paused',
                              'archived',
                              'retired',
                              'all',
                            ])
                              ChoiceChip(
                                label: Text(state),
                                selected: _filter == state,
                                onSelected: (_) =>
                                    setState(() => _filter = state),
                              ),
                          ],
                        ),
                        if (_section == 'Check-ins') ..._trends(index),
                        const SizedBox(height: 12),
                        if (rows.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 30),
                            child: Text(
                              'Nothing here yet. Start with a useful template or create your own.',
                            ),
                          ),
                        for (final o in rows.take(_limit))
                          Card(
                            child: ListTile(
                              selected: _selected == o.id,
                              title: Text(o.title),
                              subtitle: Text(index.summary(o)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => setState(() => _selected = o.id),
                            ),
                          ),
                        if (rows.length > _limit)
                          TextButton(
                            onPressed: () => setState(() => _limit += 40),
                            child: Text(
                              'Show more · ${rows.length - _limit} remaining',
                            ),
                          ),
                      ],
                    ],
                  );
                  if (!wide || !detail) return list;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 5, child: list),
                      const VerticalDivider(width: 1),
                      Expanded(
                        flex: 6,
                        child: ListView(
                          padding: const EdgeInsets.all(24),
                          children: _details(selected, index),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _home(LifeIndex index) {
    final now = DateTime.now(), today = calendarDate(DateTime.now());
    final config = c.session.lifeWorkspace;
    final visible = config['homeSections'] is List
        ? (config['homeSections'] as List).whereType<String>().toSet()
        : {'Priorities', 'Habits', 'Routines', 'Goals', 'Schedule', 'Week'};
    final tasks = c.activeObjects
        .where(
          (o) =>
              o.typeId == 'orbit.task' &&
              !o.isCompleted &&
              (o.properties['dueDate'] == today ||
                  o.properties['scheduledDate'] == today ||
                  o.properties['priority'] == 'high'),
        )
        .toList();
    final projection = projectEventRange(
      c.activeObjects,
      lifeDay(now),
      lifeDay(now, 1),
    );
    final events = entriesOn(projection.objects, now)
        .where((e) => e.object.typeId == 'orbit.event')
        .map((e) => e.object)
        .toList();
    return [
      _heading(
        'Make room for what matters',
        'Your plans, practice and reflections, connected to the rest of Orbit.',
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _button(
            'Quick journal',
            () => _edit(preset: lifePresets.firstWhere((p) => p.id == 'daily')),
          ),
          _button('Capture a task', () async {
            final generation = c.workspaceGeneration;
            final name = await _name('Quick task');
            if (name != null &&
                mounted &&
                generation == c.workspaceGeneration) {
              await _run(
                () => c.create(
                  'orbit.task',
                  open: false,
                  title: name,
                  properties: {'dueDate': today},
                ),
              );
            }
          }),
          _button('Check in', () => _edit(kind: LifeKind.checkin)),
          _button('Starter library', _library),
          _button('Set up a Life pack', () async {
            final board = await showLifePackSetup(context, c);
            if (board != null && mounted) _open(board);
          }, icon: Icons.auto_awesome_mosaic_outlined),
          _button('Live Life board', _board),
          _button(
            'Customize Home',
            () => _configureHome(visible),
            icon: Icons.tune,
          ),
        ],
      ),
      const SizedBox(height: 24),
      if (visible.contains('Priorities')) ...[
        _heading(
          'Today’s priorities',
          'Due today, scheduled today or marked high priority.',
        ),
        if (tasks.isEmpty) const Text('No priorities recorded for today.'),
        ...tasks.take(12).map(_linkedRow),
        const SizedBox(height: 20),
      ],
      if (visible.contains('Schedule')) ...[
        _heading(
          'Today’s schedule',
          'Calendar entries remain editable in the main Calendar.',
        ),
        if (events.isEmpty) const Text('No calendar entries today.'),
        ...events.map(_linkedRow),
        if (projection.issues.isNotEmpty)
          Text(
            'Some recurring entries could not be projected. Review them in Calendar.',
          ),
        const SizedBox(height: 20),
      ],
      if (visible.contains('Habits')) ...[
        _heading(
          'Today’s habits',
          'A missed record is unknown. Rest and skip records are explicit.',
        ),
        for (final habit
            in index.of(LifeKind.habit).where((o) => lifeHabitDue(o, now)))
          Card(
            child: ListTile(
              title: Text(habit.title),
              subtitle: Text(index.summary(habit)),
              trailing: IconButton(
                tooltip: 'Record habit',
                onPressed: _busy ? null : () => _habit(habit),
                icon: const Icon(Icons.add_task),
              ),
              onTap: () => setState(() {
                _section = 'Habits';
                _selected = habit.id;
              }),
            ),
          ),
        const SizedBox(height: 20),
      ],
      if (visible.contains('Routines')) ...[
        _heading('Routines', 'Choose a routine to follow its ordered steps.'),
        for (final o
            in index
                .of(LifeKind.routine)
                .where((o) => lifeData(o)['state'] == 'active'))
          _recordRow(o, index),
        const SizedBox(height: 20),
      ],
      if (visible.contains('Goals')) ...[
        _heading(
          'Goals in motion',
          'Progress comes from linked actions or an explicitly recorded measurement.',
        ),
        for (final o
            in index
                .of(LifeKind.goal)
                .where((o) => lifeData(o)['state'] == 'active'))
          _recordRow(o, index),
        const SizedBox(height: 20),
      ],
      if (index
          .of(LifeKind.session)
          .any((o) => lifeData(o)['state'] == 'active')) ...[
        _heading(
          'Resume a workout',
          'Your saved sets and rest deadline survive closing Orbit.',
        ),
        for (final o
            in index
                .of(LifeKind.session)
                .where((o) => lifeData(o)['state'] == 'active'))
          _recordRow(o, index),
      ],
      if (visible.contains('Week')) ...[
        _heading(
          'This week',
          'Counts include dated records only; they do not infer untracked activity.',
        ),
        Text(
          '${index.inPeriod(lifeDay(now, 1 - now.weekday), lifeDay(now, 8 - now.weekday)).where((o) => [LifeKind.session, LifeKind.practice, LifeKind.journal, LifeKind.habitLog].contains(lifeKind(o))).length} activity records',
        ),
        const SizedBox(height: 10),
        _button(
          'Write a grounded weekly review',
          () => _run(() => c.createLifeReview('week', now)),
          icon: Icons.fact_check_outlined,
        ),
      ],
    ];
  }

  Future<void> _configureHome(Set<String> visible) async {
    final selected = {...visible}, generation = c.workspaceGeneration;
    final result = await showOrbitDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Home sections'),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final s in [
                    'Priorities',
                    'Schedule',
                    'Habits',
                    'Routines',
                    'Goals',
                    'Week',
                  ])
                    CheckboxListTile(
                      title: Text(s),
                      value: selected.contains(s),
                      onChanged: (v) => update(() {
                        v == true ? selected.add(s) : selected.remove(s);
                      }),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result == true && mounted && generation == c.workspaceGeneration) {
      c.updateSession(
        (s) => s.lifeWorkspace = {
          ...s.lifeWorkspace,
          'homeSections': selected.toList(),
        },
      );
      await c.saveSession();
      if (mounted) setState(() {});
    }
  }

  Widget _recordRow(UniversalObject o, LifeIndex index) => ListTile(
    title: Text(o.title),
    subtitle: Text(index.summary(o)),
    onTap: () => setState(() {
      _selected = o.id;
      _section = lifeKind(o)!.section;
    }),
  );
  Widget _linkedRow(UniversalObject o) => ListTile(
    dense: true,
    leading: Icon(
      o.typeId == 'orbit.task' ? Icons.check_circle_outline : Icons.link,
    ),
    title: Text(o.title),
    subtitle: Text(
      o.typeId == 'orbit.task'
          ? (o.isCompleted ? 'Completed' : 'Open task')
          : lifeKind(o)?.label ??
                (o.typeId == 'orbit.event'
                    ? 'Calendar event · ${DateTime.tryParse('${o.properties['startAt']}')?.toLocal() ?? o.properties['startDate'] ?? ''}'
                    : 'Linked item'),
    ),
    trailing: o.typeId == 'orbit.task'
        ? IconButton(
            tooltip: o.isCompleted ? 'Reopen task' : 'Complete task',
            onPressed: _busy || c.repository.readOnly
                ? null
                : () => _run(
                    () => c.configureTask(o, {'completed': !o.isCompleted}),
                  ),
            icon: Icon(
              o.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            ),
          )
        : null,
    onTap: () => _open(o),
  );

  List<Widget> _details(UniversalObject o, LifeIndex index) {
    final kind = lifeKind(o)!, d = lifeData(o), progress = index.progress(o);
    final linked = {
      for (final id in lifeReferences(o)) id,
      ...index.linkedTo(o.id).map((o) => o.id),
    };
    return [
      _heading(o.title, index.summary(o)),
      if (progress != null) ...[
        Semantics(
          label: 'Progress ${(progress * 100).round()} percent',
          child: LinearProgressIndicator(value: progress),
        ),
        const SizedBox(height: 16),
      ],
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _button(
            'Edit details',
            () => _edit(object: o),
            icon: Icons.edit_outlined,
          ),
          _button('Open note', () => _open(o), icon: Icons.open_in_new),
          _button('Linked action', () => _action(o)),
          if ([LifeKind.goal, LifeKind.skill, LifeKind.program].contains(kind))
            _button('Milestone', () => _action(o, milestone: true)),
          _button(
            kind == LifeKind.program ? 'Schedule program' : 'Add to calendar',
            () => _schedule(o),
            icon: Icons.calendar_month_outlined,
          ),
          _button('Place on Canvas', () async {
            final board = await c.createLifeBoard('${o.title} board', [
              o.id,
              ...linked.take(11),
            ]);
            if (board != null && mounted) _open(board);
          }, icon: Icons.dashboard_outlined),
          if (kind == LifeKind.habit)
            _button('Record activity', () => _habit(o), icon: Icons.add_task),
          if (kind == LifeKind.workout)
            _button(
              'Start / resume workout',
              () => _run(() => c.startLifeWorkout(o)),
              icon: Icons.play_arrow,
            ),
          if (kind == LifeKind.skill)
            _button(
              'Log practice',
              () => _edit(kind: LifeKind.practice, fields: {'parentId': o.id}),
            ),
          if (kind == LifeKind.experiment)
            _button(
              'Dated observation',
              () => _edit(kind: LifeKind.checkin, fields: {'parentId': o.id}),
            ),
          if (kind == LifeKind.template)
            _button('Use template', () async {
              final name = await _name(
                'Create from template',
                initial: o.title,
              );
              if (name != null && mounted) {
                await _run(() async {
                  final created = await c.usePersonalTemplate(o, name);
                  if (created != null && mounted) _open(created);
                  return created;
                });
              }
            }, icon: Icons.copy_all),
        ],
      ),
      const SizedBox(height: 20),
      if (kind == LifeKind.habit) ..._habitHistory(o, index),
      if (kind == LifeKind.routine) ..._routine(o, index),
      if (kind == LifeKind.life) ..._items(o),
      if (kind == LifeKind.session) ..._session(o, index),
      if (kind == LifeKind.exercise) ..._exercise(o, index),
      if (kind == LifeKind.experiment) ...[
        Text(
          'Baseline: ${d['baseline'] ?? 'not recorded'} · Latest: ${d['value'] ?? 'not recorded'} ${d['unit'] ?? ''}',
        ),
        Text(
          'Outcome: ${d['outcome'] ?? 'not decided'} · Period: ${d['startDate'] ?? 'not set'} – ${d['endDate'] ?? 'not set'}',
        ),
        const SizedBox(height: 12),
        const Text(
          'Observations describe your records, not a controlled causal conclusion.',
        ),
        const SizedBox(height: 16),
      ],
      if (o.body.isNotEmpty) ...[
        const Text('Writing', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SelectableText(o.body),
        const SizedBox(height: 24),
      ],
      if (linked.isNotEmpty) ...[
        const Text(
          'Connected items',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        for (final id in linked.take(50))
          if (index.byId[id] case final target?)
            _linkedRow(target)
          else
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Unavailable source · $id'),
            ),
        if (linked.length > 50)
          Text(
            '${linked.length - 50} additional links are available through the note’s connections.',
          ),
      ],
      const SizedBox(height: 20),
      _button('Move to Trash', () async {
        final yes = await showOrbitDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Move “${o.title}” to Trash?'),
            content: const Text(
              'Linked objects remain. You can restore this record from Trash.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Move to Trash'),
              ),
            ],
          ),
        );
        if (yes == true && mounted) {
          await _run(() async {
            if (!identical(c.find(o.id), o)) return false;
            await c.trash(o.id);
            return c.find(o.id)?.isDeleted == true;
          });
        }
      }, icon: Icons.delete_outline),
    ];
  }

  Future<void> _habit(UniversalObject habit) async {
    var day = lifeDay(DateTime.now()), outcome = 'done';
    final value = TextEditingController(
          text: '${lifeData(habit)['target'] ?? 1}',
        ),
        note = TextEditingController();
    final generation = c.workspaceGeneration;
    String? error;
    try {
      final yes = await showOrbitDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => AlertDialog(
            title: Text('Record ${habit.title}'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: day,
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) update(() => day = date);
                      },
                      child: Text(calendarDate(day)),
                    ),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: outcome,
                      decoration: const InputDecoration(
                        labelText: 'Record type',
                      ),
                      items: [
                        for (final s in ['done', 'skip', 'break'])
                          DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: (s) => update(() => outcome = s!),
                    ),
                    TextField(
                      controller: value,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            'Amount (${lifeData(habit)['unit'] ?? 'times'})',
                      ),
                    ),
                    TextField(
                      controller: note,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Optional context',
                      ),
                    ),
                    if (error != null) Text(error!),
                    const Text(
                      'One record per day. Saving the same date replaces that day’s amount; it does not add a duplicate.',
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final v = double.tryParse(value.text);
                  if (v == null || !v.isFinite || v < 0) {
                    update(() => error = 'Enter a finite non-negative amount.');
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Save record'),
              ),
            ],
          ),
        ),
      );
      if (yes == true && mounted && generation == c.workspaceGeneration) {
        await _run(
          () => c.recordLifeHabit(
            habit,
            day,
            value: outcome == 'done' ? double.parse(value.text) : 0,
            outcome: outcome,
            note: note.text,
          ),
        );
      }
    } finally {
      value.dispose();
      note.dispose();
    }
  }

  List<Widget> _habitHistory(UniversalObject o, LifeIndex index) {
    final logs = index.children[o.id] ?? [];
    return [
      const Text(
        'Last 60 days · filled = target met, outline = recorded, dash = rest/skip, empty = unknown',
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (var i = -59; i <= 0; i++)
            Builder(
              builder: (ctx) {
                final date = lifeDay(index.now, i),
                    stamp = calendarDate(date),
                    record = logs
                        .where((l) => lifeData(l)['date'] == stamp)
                        .firstOrNull;
                final rest =
                        record != null && lifeData(record)['outcome'] != 'done',
                    done =
                        record != null &&
                        index.habitValue(o.id, date) >=
                            (lifeData(o)['target'] as num? ?? 1);
                final label =
                    '$stamp: ${record == null
                        ? 'unknown'
                        : rest
                        ? lifeData(record)['outcome']
                        : lifeData(record)['value']}';
                return Tooltip(
                  message: label,
                  child: Semantics(
                    label: label,
                    child: Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: done
                            ? Theme.of(ctx).colorScheme.primaryContainer
                            : Theme.of(ctx).colorScheme.surfaceContainerHighest,
                        border: record != null
                            ? Border.all(
                                color: Theme.of(ctx).colorScheme.primary,
                              )
                            : null,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: rest ? const Text('–') : null,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      const SizedBox(height: 20),
      for (final log in logs.reversed.take(14)) _linkedRow(log),
    ];
  }

  List<Widget> _routine(UniversalObject o, LifeIndex index) {
    final today = calendarDate(index.now),
        record = (index.children[o.id] ?? [])
            .where((r) => lifeData(r)['date'] == today)
            .firstOrNull;
    final checked =
        (record == null ? [] : lifeData(record)['checked'] as List? ?? [])
            .whereType<int>()
            .toSet();
    final items = record == null
        ? lifeIds(lifeData(o), 'items')
        : lifeIds(lifeData(record), 'items');
    return [
      Text('Today’s routine · $today'),
      for (var i = 0; i < items.length; i++)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${i + 1}. ${items[i]}'),
          value: checked.contains(i),
          onChanged: _busy
              ? null
              : (v) => _run(
                  () => c.routineRecord(
                    o,
                    index.now,
                    checked:
                        (v == true
                                ? {...checked, i}
                                : ({...checked}..remove(i)))
                            .toList(),
                  ),
                ),
        ),
      if (items.isEmpty)
        const Text('Edit details to add one ordered step per line.'),
      const SizedBox(height: 18),
    ];
  }

  List<Widget> _items(UniversalObject o) {
    final items = lifeIds(lifeData(o), 'items'),
        checked = (lifeData(o)['checked'] as List? ?? [])
            .whereType<int>()
            .toSet();
    return [
      for (var i = 0; i < items.length; i++)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(items[i]),
          value: checked.contains(i),
          onChanged: _busy
              ? null
              : (v) => _run(
                  () => c.saveLife(o, {
                    'checked':
                        (v == true
                                ? {...checked, i}
                                : ({...checked}..remove(i)))
                            .toList(),
                  }),
                ),
        ),
      const SizedBox(height: 12),
    ];
  }

  List<Widget> _session(UniversalObject o, LifeIndex index) {
    final d = lifeData(o),
        sets = (d['sets'] as List? ?? []).whereType<Map>().toList(),
        active = d['state'] == 'active';
    return [
      if (active)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LifeRestClock(
                  key: ValueKey(o.id),
                  deadline: DateTime.tryParse('${d['restUntil']}'),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final seconds in [60, 90, 120])
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() => c.restLifeSession(o, seconds)),
                        child: Text('${seconds}s rest'),
                      ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () =>
                                _run(() => c.saveLife(o, {'restUntil': null})),
                      child: const Text('Clear timer'),
                    ),
                  ],
                ),
                const Text(
                  'Each saved set is durable. Close and resume this session later.',
                ),
              ],
            ),
          ),
        ),
      if (active)
        _button('Add exercise set', () async {
          final generation = c.workspaceGeneration;
          final selected = await _chooseObjects(
            context,
            c,
            index.of(LifeKind.exercise).map((e) => e.id).toList(),
            single: true,
            title: 'Add exercise to session',
          );
          if (selected != null &&
              selected.isNotEmpty &&
              mounted &&
              generation == c.workspaceGeneration) {
            final exercise = c.find(selected.first);
            if (exercise != null) {
              await _run(() => c.appendLifeSet(o, exercise));
            }
          }
        }),
      for (final set in sets)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  index.byId['${set['exerciseId']}']?.title ??
                      'Unavailable exercise',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${set['reps'] ?? 0} reps · ${set['weight'] ?? 0} ${set['weightUnit']} · ${set['distance'] ?? 0} ${set['distanceUnit']} · ${set['seconds'] ?? 0}s · effort ${set['effort'] ?? '—'}/10',
                ),
                Text(_previousSet(index, o, set)),
                Wrap(
                  spacing: 4,
                  children: [
                    if (active)
                      TextButton.icon(
                        onPressed: _busy ? null : () => _set(o, set, index),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit set'),
                      ),
                    if (active)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => c.updateLifeSet(o, '${set['id']}', {
                                  'completed': set['completed'] != true,
                                }),
                              ),
                        child: Text(
                          set['completed'] == true
                              ? 'Mark unfinished'
                              : 'Complete set',
                        ),
                      ),
                    if (active)
                      IconButton(
                        tooltip: 'Duplicate set',
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => c.updateLifeSet(
                                  o,
                                  '${set['id']}',
                                  {},
                                  duplicate: true,
                                ),
                              ),
                        icon: const Icon(Icons.copy_outlined),
                      ),
                    if (active)
                      IconButton(
                        tooltip: 'Remove set',
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => c.updateLifeSet(
                                  o,
                                  '${set['id']}',
                                  {},
                                  remove: true,
                                ),
                              ),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    if (!active)
                      Text(
                        set['completed'] == true
                            ? 'Completed'
                            : 'Not completed',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      if (active)
        _button('Finish workout', () async {
          final yes = await showOrbitDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Finish workout?'),
              content: Text(
                '${sets.where((s) => s['completed'] == true).length} of ${sets.length} sets are completed. Unfinished sets remain recorded as unfinished.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Keep training'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Finish'),
                ),
              ],
            ),
          );
          if (yes == true && mounted) await _run(() => c.finishLifeSession(o));
        }, icon: Icons.flag_outlined),
      const SizedBox(height: 20),
    ];
  }

  String _previousSet(LifeIndex index, UniversalObject session, Map set) {
    final history =
        index
            .of(LifeKind.session)
            .where(
              (s) => s.id != session.id && lifeData(s)['state'] == 'completed',
            )
            .toList()
          ..sort(
            (a, b) => '${lifeData(b)['startedAt']}'.compareTo(
              '${lifeData(a)['startedAt']}',
            ),
          );
    for (final s in history) {
      for (final old in (lifeData(s)['sets'] as List? ?? []).reversed) {
        if (old['exerciseId'] == set['exerciseId'] &&
            old['completed'] == true) {
          return 'Previous · ${lifeData(s)['date']}: ${old['reps']} reps, ${old['weight']} ${old['weightUnit']}, ${old['distance']} ${old['distanceUnit']}, ${old['seconds']}s';
        }
      }
    }
    return 'No previous completed set recorded.';
  }

  Future<void> _set(UniversalObject session, Map set, LifeIndex index) async {
    final controls = {
      for (final f in ['reps', 'weight', 'distance', 'seconds', 'effort'])
        f: TextEditingController(text: '${set[f] ?? (f == 'effort' ? '' : 0)}'),
    };
    var weightUnit = '${set['weightUnit']}',
        distanceUnit = '${set['distanceUnit']}',
        exerciseId = '${set['exerciseId']}';
    String? error;
    final generation = c.workspaceGeneration;
    try {
      final result = await showOrbitDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => AlertDialog(
            title: const Text('Record exercise set'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        final ids = await _chooseObjects(
                          ctx,
                          c,
                          index.of(LifeKind.exercise).map((o) => o.id).toList(),
                          single: true,
                          title: 'Exercise or substitution',
                        );
                        if (ids != null && ids.isNotEmpty) {
                          update(() => exerciseId = ids.first);
                        }
                      },
                      child: Text(
                        index.byId[exerciseId]?.title ?? 'Choose exercise',
                      ),
                    ),
                    for (final entry in controls.entries)
                      TextField(
                        controller: entry.value,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: entry.key == 'effort'
                              ? 'Effort (0–10, optional)'
                              : entry.key,
                        ),
                      ),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: weightUnit,
                      decoration: const InputDecoration(
                        labelText: 'Weight unit',
                      ),
                      items: [
                        for (final u in ['kg', 'lb'])
                          DropdownMenuItem(value: u, child: Text(u)),
                      ],
                      onChanged: (v) => weightUnit = v!,
                    ),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: distanceUnit,
                      decoration: const InputDecoration(
                        labelText: 'Distance unit',
                      ),
                      items: [
                        for (final u in ['m', 'km', 'mi'])
                          DropdownMenuItem(value: u, child: Text(u)),
                      ],
                      onChanged: (v) => distanceUnit = v!,
                    ),
                    if (error != null) Text(error!),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (controls.entries.any((e) {
                    if (e.key == 'effort' && e.value.text.trim().isEmpty) {
                      return false;
                    }
                    final n = num.tryParse(e.value.text);
                    return n == null ||
                        !n.isFinite ||
                        n < 0 ||
                        n > (e.key == 'effort' ? 10 : 1000000);
                  })) {
                    update(
                      () => error =
                          'Enter valid non-negative values; effort is 0–10.',
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Save set'),
              ),
            ],
          ),
        ),
      );
      if (result == true && mounted && generation == c.workspaceGeneration) {
        await _run(
          () => c.updateLifeSet(session, '${set['id']}', {
            for (final entry in controls.entries)
              entry.key: entry.value.text.trim().isEmpty
                  ? null
                  : num.parse(entry.value.text),
            'weightUnit': weightUnit,
            'distanceUnit': distanceUnit,
            'exerciseId': exerciseId,
          }),
        );
      }
    } finally {
      for (final control in controls.values) {
        control.dispose();
      }
    }
  }

  Widget _chart(String title, List<({String date, double value})> samples) {
    if (samples.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            const SizedBox(height: 10),
            SizedBox(
              height: 90,
              child: CustomPaint(
                size: const Size(double.infinity, 90),
                painter: _LifeTrend(
                  samples,
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            ExpansionTile(
              title: const Text('Recorded values'),
              children: [
                for (final s in samples)
                  ListTile(
                    dense: true,
                    title: Text(s.date),
                    subtitle: Text(s.value.toStringAsFixed(2)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _exercise(UniversalObject o, LifeIndex index) {
    final records = index.exerciseRecords(o.id),
        history =
            index
                .of(LifeKind.session)
                .where(
                  (s) => (lifeData(s)['sets'] as List? ?? []).any(
                    (set) => set['exerciseId'] == o.id,
                  ),
                )
                .toList()
              ..sort(
                (a, b) => '${lifeData(b)['date']}'.compareTo(
                  '${lifeData(a)['date']}',
                ),
              );
    return [
      for (final field in ['instructions', 'equipment', 'substitutions'])
        if (lifeData(o)[field] is String && '${lifeData(o)[field]}'.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SelectableText('$field: ${lifeData(o)[field]}'),
          ),
      const Text('Recorded maxima · completed sets in completed sessions only'),
      for (final e in records.entries) Text('${e.key}: ${e.value}'),
      if (records.isEmpty) const Text('No completed results yet.'),
      const SizedBox(height: 16),
      for (final unit in ['kg', 'lb'])
        _chart(
          'Daily maximum weight ($unit)',
          index.exerciseSeries(o.id, 'weight', unit),
        ),
      for (final unit in ['km', 'm', 'mi'])
        _chart(
          'Daily longest distance ($unit)',
          index.exerciseSeries(o.id, 'distance', unit),
        ),
      _chart(
        'Daily maximum repetitions',
        index.exerciseSeries(o.id, 'reps', ''),
      ),
      if (history.length >= 2)
        _button(
          'Compare sessions',
          () => _compare(o, history, index),
          icon: Icons.compare_arrows,
        ),
      const Text('Session history and comparison'),
      for (final s in history.take(30))
        ExpansionTile(
          title: Text(s.title),
          subtitle: Text(index.summary(s)),
          children: [
            for (final set in (lifeData(s)['sets'] as List).where(
              (set) => set['exerciseId'] == o.id,
            ))
              ListTile(
                dense: true,
                title: Text(
                  '${set['reps']} reps · ${set['weight']} ${set['weightUnit']} · ${set['distance']} ${set['distanceUnit']} · ${set['seconds']}s',
                ),
                subtitle: Text(
                  set['completed'] == true ? 'Completed' : 'Unfinished',
                ),
              ),
            TextButton(
              onPressed: () => setState(() => _selected = s.id),
              child: const Text('Open session'),
            ),
          ],
        ),
      const SizedBox(height: 20),
    ];
  }

  Future<void> _compare(
    UniversalObject exercise,
    List<UniversalObject> sessions,
    LifeIndex index,
  ) async {
    var left = sessions.first.id, right = sessions[1].id;
    String totals(String id) {
      final session = index.byId[id]!;
      final totals = <String, double>{};
      var count = 0;
      for (final set in (lifeData(session)['sets'] as List).where(
        (s) => s['exerciseId'] == exercise.id && s['completed'] == true,
      )) {
        count++;
        for (final entry in {
          'repetitions': set['reps'],
          'seconds': set['seconds'],
          'distance (${set['distanceUnit']})': set['distance'],
          'weight × repetitions (${set['weightUnit']})':
              (set['weight'] as num? ?? 0) * (set['reps'] as num? ?? 0),
        }.entries) {
          totals[entry.key] =
              (totals[entry.key] ?? 0) + (entry.value as num? ?? 0).toDouble();
        }
      }
      return '$count completed sets\n${totals.entries.map((e) => '${e.key}: ${e.value.toStringAsFixed(1)}').join('\n')}';
    }

    await showOrbitDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text('Compare ${exercise.title}'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final side in [true, false]) ...[
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: side ? left : right,
                      decoration: InputDecoration(
                        labelText: side ? 'First session' : 'Second session',
                      ),
                      items: [
                        for (final s in sessions)
                          DropdownMenuItem(
                            value: s.id,
                            child: Text(
                              s.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => update(() {
                        side ? left = v! : right = v!;
                      }),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(totals(side ? left : right)),
                    const SizedBox(height: 20),
                  ],
                  const Text(
                    'Only completed sets count. Different units stay separate; no automatic strength or health conclusions.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _trends(LifeIndex index) => [
    const SizedBox(height: 18),
    const Text(
      'Recorded daily averages · missing days are unknown. These are observations, not diagnoses or causal conclusions.',
    ),
    for (final unit
        in index
            .of(LifeKind.checkin)
            .where((o) => lifeData(o)['value'] is num)
            .map((o) => '${lifeData(o)['unit'] ?? ''}')
            .toSet())
      _chart(
        'Custom measurement (${unit.isEmpty ? 'unspecified unit' : unit})',
        index.series(LifeKind.checkin, 'value', unit: unit),
      ),
    for (final field in [
      'sleepHours',
      'mood',
      'energy',
      'stress',
      'outdoorMinutes',
    ])
      Builder(
        builder: (ctx) {
          final samples = index.series(LifeKind.checkin, field);
          if (samples.isEmpty) return const SizedBox.shrink();
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$field · ${samples.length} recorded days'),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 90,
                    child: CustomPaint(
                      size: const Size(double.infinity, 90),
                      painter: _LifeTrend(
                        samples,
                        Theme.of(ctx).colorScheme.primary,
                      ),
                    ),
                  ),
                  ExpansionTile(
                    title: const Text('Accessible data table'),
                    children: [
                      for (final s in samples)
                        ListTile(
                          dense: true,
                          title: Text(s.date),
                          trailing: Text(s.value.toStringAsFixed(2)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
  ];
}

const _descriptions = {
  'Goals':
      'Choose an outcome, connect milestones and keep evidence beside your progress.',
  'Habits':
      'Flexible quantities and ordered routines. Rest, skipped activity and missing tracking stay distinct.',
  'Fitness':
      'Your exercise library, workouts, scheduled programs and durable training sessions.',
  'Journal':
      'Intentions, reflections, decisions and memories in ordinary editable notes.',
  'Experiments':
      'One change, a baseline, dated observations and a conclusion you can revisit.',
  'Check-ins':
      'Optional personal records. Track only what you want to understand.',
  'Learning':
      'Connect skills, practice, courses, resources and portfolio evidence.',
  'Life':
      'Meals, home, people, travel and the commitments that keep everyday life running.',
  'Reviews':
      'Reflect on actual dated activity, then create linked next actions.',
  'Templates':
      'Useful starting points and your own reusable notes and Canvas layouts.',
};
List<LifeKind> _kinds(String section) => LifeKind.values
    .where(
      (k) =>
          k.section == section &&
          ![LifeKind.session, LifeKind.review, LifeKind.template].contains(k),
    )
    .toList();

class _LifeRestClock extends StatefulWidget {
  const _LifeRestClock({super.key, this.deadline});
  final DateTime? deadline;
  @override
  State<_LifeRestClock> createState() => _LifeRestClockState();
}

class _LifeRestClockState extends State<_LifeRestClock> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant _LifeRestClock old) {
    super.didUpdateWidget(old);
    if (old.deadline != widget.deadline) _start();
  }

  void _start() {
    timer?.cancel();
    if (widget.deadline?.isAfter(DateTime.now().toUtc()) == true) {
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (widget.deadline?.isAfter(DateTime.now().toUtc()) != true) {
          timer?.cancel();
        }
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds =
        widget.deadline?.difference(DateTime.now().toUtc()).inSeconds ?? 0;
    return Text(
      seconds > 0
          ? 'Rest · ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}'
          : 'Ready when you are',
      style: Theme.of(context).textTheme.titleLarge,
    );
  }
}

class _LifeTrend extends CustomPainter {
  _LifeTrend(this.samples, this.color);
  final List<({String date, double value})> samples;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    final min = samples.map((s) => s.value).reduce((a, b) => a < b ? a : b),
        max = samples.map((s) => s.value).reduce((a, b) => a > b ? a : b);
    final first = parseCalendarDate(samples.first.date)!,
        last = parseCalendarDate(samples.last.date)!;
    int civil(DateTime d) =>
        DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;
    final length = (civil(last) - civil(first)).clamp(1, 36600),
        paint = Paint()
          ..color = color
          ..strokeWidth = 2;
    Offset? previous;
    int? priorDay;
    for (final s in samples) {
      final day = civil(parseCalendarDate(s.date)!);
      final point = Offset(
        5 + (day - civil(first)) / length * (size.width - 10),
        size.height -
            6 -
            (s.value - min) / (max == min ? 1 : max - min) * (size.height - 12),
      );
      if (previous != null && day - priorDay! == 1) {
        canvas.drawLine(previous, point, paint);
      }
      canvas.drawCircle(point, 3, paint);
      previous = point;
      priorDay = day;
    }
  }

  @override
  bool shouldRepaint(covariant _LifeTrend old) =>
      old.samples != samples || old.color != color;
}

Future<List<String>?> _chooseObjects(
  BuildContext context,
  WorkspaceController c,
  List<String> ids, {
  List<String> initial = const [],
  bool single = false,
  String title = 'Linked items',
}) async {
  final selected = initial.toSet();
  var query = '';
  var limit = 40;
  return showOrbitDialog<List<String>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) {
        final rows = ids
            .map(c.find)
            .whereType<UniversalObject>()
            .where(
              (o) =>
                  !o.isDeleted &&
                  o.title.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 540,
            height: 420,
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => update(() {
                    query = v;
                    limit = 40;
                  }),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final o in rows.take(limit))
                        CheckboxListTile(
                          title: Text(o.title),
                          subtitle: Text(lifeKind(o)?.label ?? o.typeId),
                          value: selected.contains(o.id),
                          onChanged: (v) {
                            if (single) {
                              Navigator.pop(ctx, [o.id]);
                              return;
                            }
                            update(() {
                              v == true
                                  ? selected.add(o.id)
                                  : selected.remove(o.id);
                            });
                          },
                        ),
                      if (rows.length > limit)
                        TextButton(
                          onPressed: () => update(() => limit += 40),
                          child: const Text('Show more'),
                        ),
                    ],
                  ),
                ),
                if (!single) Text('${selected.length} selected'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            if (!single)
              FilledButton(
                onPressed: () => Navigator.pop(ctx, selected.toList()),
                child: const Text('Use selection'),
              ),
          ],
        );
      },
    ),
  );
}

class LifeFormResult {
  const LifeFormResult(
    this.kind,
    this.title,
    this.body,
    this.fields, {
    this.savedId,
  });
  final String? savedId;
  final LifeKind kind;
  final String title, body;
  final Map<String, dynamic> fields;
}

class LifeRecordForm extends StatefulWidget {
  const LifeRecordForm({
    super.key,
    required this.controller,
    required this.kind,
    this.object,
    this.preset,
    this.fields = const {},
    this.persist = false,
  });
  final bool persist;
  final WorkspaceController controller;
  final LifeKind kind;
  final UniversalObject? object;
  final LifePreset? preset;
  final Map<String, dynamic> fields;
  @override
  State<LifeRecordForm> createState() => _LifeRecordFormState();
}

class _LifeRecordFormState extends State<LifeRecordForm> {
  late final Map<String, dynamic> _data;
  final _controls = <String, TextEditingController>{};
  String? _error;
  bool _saving = false;
  final _actionKey = const Uuid().v4();
  TextEditingController control(String key, [String initial = '']) =>
      _controls.putIfAbsent(
        key,
        () => TextEditingController(text: '${_data[key] ?? initial}'),
      );
  @override
  void initState() {
    super.initState();
    _data = {
      'version': 1,
      'kind': widget.kind.name,
      'state': 'active',
      if ([
        LifeKind.journal,
        LifeKind.practice,
        LifeKind.checkin,
      ].contains(widget.kind))
        'date': calendarDate(DateTime.now()),
      if (widget.kind == LifeKind.habit) ...{
        'frequency': 'daily',
        'target': 1,
        'unit': 'times',
      },
      if (widget.kind == LifeKind.workout) ...{
        'setsPerExercise': 3,
        'restSeconds': 90,
        'weightUnit': 'kg',
        'distanceUnit': 'km',
      },
      if (widget.kind == LifeKind.program) ...{
        'weekCount': 4,
        'minutes': 60,
        'weekdays': [1, 3, 5],
      },
      ...?widget.preset?.fields,
      if (widget.object != null) ...lifeData(widget.object!),
      ...widget.fields,
    };
    _controls['title'] = TextEditingController(
      text: widget.object?.title ?? widget.preset?.title ?? '',
    );
    _controls['body'] = TextEditingController(
      text: widget.object?.body ?? widget.preset?.body ?? '',
    );
  }

  @override
  void dispose() {
    for (final c in _controls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget text(
    String key,
    String label, {
    bool number = false,
    bool date = false,
    int lines = 1,
    String initial = '',
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: control(key, initial),
      maxLines: lines,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: date ? 'YYYY-MM-DD' : null,
        suffixIcon: date
            ? IconButton(
                tooltip: 'Choose $label',
                icon: const Icon(Icons.calendar_today_outlined),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate:
                        parseCalendarDate(control(key).text) ?? DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2200),
                  );
                  if (picked != null && mounted) {
                    setState(() => control(key).text = calendarDate(picked));
                  }
                },
              )
            : null,
      ),
    ),
  );
  Widget select(String key, String label, List<String> values) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: values.contains(_data[key])
          ? _data[key] as String
          : values.first,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final v in values)
          DropdownMenuItem(
            value: v,
            child: Text(v, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) => setState(() => _data[key] = v),
    ),
  );
  Widget links(
    String key,
    String label, {
    LifeKind? kind,
    bool single = false,
  }) {
    final ids = single
        ? (_data[key] is String && _data[key] != ''
              ? [_data[key] as String]
              : <String>[])
        : lifeIds(_data, key);
    final options = widget.controller.activeObjects
        .where(
          (o) =>
              o.id != widget.object?.id &&
              (kind == null || lifeKind(o) == kind) &&
              (key != 'courseId' || o.properties['isCourseOverview'] == true),
        )
        .map((o) => o.id)
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final id in ids)
                InputChip(
                  label: Text(
                    widget.controller.find(id)?.title ?? 'Unavailable source',
                  ),
                  onDeleted: () => setState(() {
                    single
                        ? _data[key] = ''
                        : _data[key] = ids.where((v) => v != id).toList();
                  }),
                ),
              ActionChip(
                label: const Text('Choose…'),
                onPressed: () async {
                  final chosen = await _chooseObjects(
                    context,
                    widget.controller,
                    options,
                    initial: ids,
                    single: single,
                    title: label,
                  );
                  if (chosen != null && mounted) {
                    setState(
                      () => _data[key] = single
                          ? (chosen.firstOrNull ?? '')
                          : chosen,
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget weekdays() => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Wrap(
      spacing: 4,
      children: [
        for (var i = 1; i <= 7; i++)
          FilterChip(
            label: Text(
              ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i - 1],
            ),
            selected: lifeIdsAsWeekdays(_data).contains(i),
            onSelected: (v) => setState(
              () => _data['weekdays'] = v
                  ? {...lifeIdsAsWeekdays(_data), i}.toList()
                  : (lifeIdsAsWeekdays(_data)..remove(i)),
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final k = widget.kind;
    return PopScope(
      canPop: !_saving,
      child: AbsorbPointer(
        absorbing: _saving,
        child: AlertDialog(
          title: Text(
            '${widget.object == null ? 'New' : 'Edit'} ${k.label.toLowerCase()}',
          ),
          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.preset != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(widget.preset!.description),
                    ),
                  text('title', 'Title'),
                  select('state', 'Status', lifeStates),
                  if ([LifeKind.goal, LifeKind.skill].contains(k)) ...[
                    select('progressMode', 'Progress source', [
                      'actions',
                      'measurement',
                    ]),
                    text('startDate', 'Start date', date: true),
                    text('endDate', 'Target date', date: true),
                    if (_data['progressMode'] == 'measurement') ...[
                      text('baseline', 'Starting measurement', number: true),
                      text('target', 'Target measurement', number: true),
                      text('value', 'Latest measurement', number: true),
                      text('unit', 'Measurement unit'),
                    ],
                    if (k == LifeKind.skill) ...[
                      links(
                        'parentId',
                        'Parent skill',
                        kind: LifeKind.skill,
                        single: true,
                      ),
                      text('selfAssessment', 'Self-assessment / current level'),
                    ],
                  ],
                  if (k == LifeKind.habit) ...[
                    select('frequency', 'Schedule', [
                      'daily',
                      'weekly',
                      'weekdays',
                    ]),
                    if (_data['frequency'] == 'weekdays') weekdays(),
                    text('target', 'Target amount', number: true),
                    text('minimum', 'Minimum version amount', number: true),
                    text('unit', 'Unit (times, minutes, pages…)'),
                    text('startDate', 'Start date', date: true),
                    text('pausedUntil', 'Planned break through', date: true),
                  ],
                  if ([LifeKind.routine, LifeKind.life].contains(k)) ...[
                    if (k == LifeKind.life)
                      text('category', 'Area (Meals, Home, Travel, People…)'),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: TextField(
                        controller: control(
                          'itemsText',
                          lifeIds(_data, 'items').join('\n'),
                        ),
                        minLines: 3,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'Checklist / ordered steps · one per line',
                        ),
                      ),
                    ),
                  ],
                  if (k == LifeKind.exercise) ...[
                    text('equipment', 'Equipment'),
                    text('instructions', 'Instructions', lines: 3),
                    text('substitutions', 'Substitutions', lines: 3),
                  ],
                  if (k == LifeKind.workout) ...[
                    links(
                      'exerciseIds',
                      'Exercises in workout',
                      kind: LifeKind.exercise,
                    ),
                    text(
                      'setsPerExercise',
                      'Starting sets per exercise (1–10)',
                      number: true,
                    ),
                    text(
                      'restSeconds',
                      'Default rest in seconds',
                      number: true,
                    ),
                    select('weightUnit', 'Weight unit', ['kg', 'lb']),
                    select('distanceUnit', 'Distance unit', ['km', 'm', 'mi']),
                  ],
                  if (k == LifeKind.program) ...[
                    links(
                      'workoutIds',
                      'Workouts to rotate',
                      kind: LifeKind.workout,
                    ),
                    weekdays(),
                    text('weekCount', 'Weeks (1–26)', number: true),
                    text('minutes', 'Calendar session minutes', number: true),
                  ],
                  if ([
                    LifeKind.journal,
                    LifeKind.checkin,
                    LifeKind.practice,
                    LifeKind.review,
                    LifeKind.habitLog,
                    LifeKind.routineLog,
                  ].contains(k))
                    text('date', 'Record date', date: true),
                  if (k == LifeKind.experiment) ...[
                    text('startDate', 'Start date', date: true),
                    text('endDate', 'Finish date', date: true),
                    text('baseline', 'Baseline', number: true),
                    text('value', 'Latest measurement', number: true),
                    text('unit', 'Measurement unit'),
                    select('outcome', 'Current decision', [
                      'continue',
                      'adapt',
                      'stop',
                    ]),
                    text('reviewDate', 'Review date', date: true),
                  ],
                  if (k == LifeKind.checkin) ...[
                    for (final field in [
                      ('sleepHours', 'Sleep hours (optional, 0–24)'),
                      ('mood', 'Mood (optional, 1–5)'),
                      ('energy', 'Energy (optional, 1–5)'),
                      ('stress', 'Stress (optional, 1–5)'),
                      ('outdoorMinutes', 'Outdoor minutes (optional)'),
                      ('value', 'Custom measurement (optional)'),
                    ])
                      text(field.$1, field.$2, number: true),
                    text('unit', 'Custom measurement unit'),
                    links(
                      'parentId',
                      'Related experiment',
                      kind: LifeKind.experiment,
                      single: true,
                    ),
                  ],
                  if (k == LifeKind.practice) ...[
                    text('minutes', 'Practice minutes', number: true),
                    links(
                      'parentId',
                      'Practiced skill',
                      kind: LifeKind.skill,
                      single: true,
                    ),
                  ],
                  if (k == LifeKind.life)
                    text('reviewDate', 'Next review / renewal', date: true),
                  links(
                    'goalId',
                    'Related goal',
                    kind: LifeKind.goal,
                    single: true,
                  ),
                  if ([LifeKind.skill, LifeKind.practice].contains(k))
                    links('courseId', 'Related course', single: true),
                  links(
                    'resources',
                    'Evidence, notes, files and other resources',
                  ),
                  text('body', 'Writing (Markdown)', lines: 8),
                  const Text(
                    'Writing stays editable as a normal note. Links point to original Orbit objects.',
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    try {
      if (control('title').text.trim().isEmpty) {
        throw const FormatException('Enter a title.');
      }
      final data = {..._data};
      const numeric = {
        'baseline',
        'target',
        'value',
        'minimum',
        'minutes',
        'setsPerExercise',
        'restSeconds',
        'weekCount',
        'sleepHours',
        'mood',
        'energy',
        'stress',
        'outdoorMinutes',
      };
      const integers = {'setsPerExercise', 'restSeconds', 'weekCount'};
      for (final entry in _controls.entries) {
        if (['title', 'body', 'itemsText'].contains(entry.key)) continue;
        final value = entry.value.text.trim();
        if (numeric.contains(entry.key)) {
          if (value.isEmpty) {
            data[entry.key] = null;
            continue;
          }
          final parsed = integers.contains(entry.key)
              ? int.tryParse(value)
              : num.tryParse(value);
          if (parsed == null) {
            throw FormatException('Enter a number for ${entry.key}.');
          }
          data[entry.key] = parsed;
        } else {
          data[entry.key] = value;
        }
      }
      if (_controls.containsKey('itemsText')) {
        final old = lifeIds(_data, 'items'),
            items = control('itemsText').text
                .split('\n')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
        // Index-based completions cannot follow rearranged text safely.
        if (old.join('\n') != items.join('\n')) data['checked'] = <int>[];
        data['items'] = items;
      }
      if (data['frequency'] == 'weekdays' && lifeIdsAsWeekdays(data).isEmpty ||
          widget.kind == LifeKind.program && lifeIdsAsWeekdays(data).isEmpty) {
        throw const FormatException('Choose at least one weekday.');
      }
      validateLifeData(data);
      final title = control('title').text.trim(), body = control('body').text;
      String? savedId;
      if (widget.persist) {
        final generation = widget.controller.workspaceGeneration;
        setState(() => _saving = true);
        final source = widget.object;
        final success = source == null
            ? await widget.controller.createLife(
                widget.kind,
                title,
                body: body,
                fields: data,
                actionKey: 'life-form:$_actionKey',
              )
            : await widget.controller.saveLife(
                source,
                data,
                title: title,
                body: body,
              );
        if (!mounted) return;
        setState(() => _saving = false);
        if (generation != widget.controller.workspaceGeneration ||
            success == null ||
            success == false) {
          setState(
            () => _error =
                widget.controller.error ??
                'Could not save. Your writing is kept here. Retry after refreshing the source.',
          );
          return;
        }
        savedId = success is UniversalObject ? success.id : source?.id;
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        LifeFormResult(widget.kind, title, body, data, savedId: savedId),
      );
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }
}

class _LifeLibrary extends StatefulWidget {
  const _LifeLibrary();
  @override
  State<_LifeLibrary> createState() => _LifeLibraryState();
}

class _LifeLibraryState extends State<_LifeLibrary> {
  String query = '', area = 'All';
  @override
  Widget build(BuildContext context) {
    final rows = lifePresets
        .where(
          (p) =>
              (area == 'All' || p.kind.section == area) &&
              '${p.title} ${p.description}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    return AlertDialog(
      title: const Text('Life starter library'),
      content: SizedBox(
        width: 680,
        height: 540,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search templates',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => query = v),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final s in [
                    'All',
                    'Goals',
                    'Habits',
                    'Fitness',
                    'Journal',
                    'Experiments',
                    'Check-ins',
                    'Learning',
                    'Life',
                  ])
                    Padding(
                      padding: const EdgeInsets.all(3),
                      child: ChoiceChip(
                        label: Text(s),
                        selected: area == s,
                        onSelected: (_) => setState(() => area = s),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final p in rows)
                    ListTile(
                      title: Text(p.title),
                      subtitle: Text(p.description),
                      trailing: const Icon(Icons.arrow_forward),
                      onTap: () => Navigator.pop(context, p),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class LifeHomeCard extends StatelessWidget {
  const LifeHomeCard({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  Widget build(BuildContext context) {
    final index = controller.lifeIndex;
    final goals = index
        .of(LifeKind.goal)
        .where((o) => lifeData(o)['state'] == 'active')
        .length;
    final habits = index
        .of(LifeKind.habit)
        .where((o) => lifeHabitDue(o, DateTime.now()))
        .length;
    final sessions = index
        .of(LifeKind.session)
        .where((o) => lifeData(o)['state'] == 'active')
        .length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 20,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Life workspace',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  index.records.isEmpty
                      ? 'Goals, habits, training and everyday life — connected.'
                      : '$goals active goals · $habits habits today · $sessions workouts to resume',
                ),
              ],
            ),
            FilledButton.tonalIcon(
              onPressed: () => showLifeWorkspace(context, controller),
              icon: const Icon(Icons.spa_outlined),
              label: const Text('Open Life'),
            ),
          ],
        ),
      ),
    );
  }
}
