import 'dart:async';
import 'package:flutter/material.dart';

import '../../app/orbit_theme.dart';
import '../../app/session_state.dart';
import '../../app/workspace_controller.dart';
import '../../domain/calendar_event.dart';
import '../../domain/universal_object.dart';
import 'calendar_view.dart';

IconData objectIcon(String type) => switch (type) {
  'orbit.canvas' => Icons.dashboard_outlined,
  'orbit.task' => Icons.check_circle_outline,
  'orbit.event' => Icons.event_outlined,
  'orbit.file' => Icons.attach_file,
  _ => Icons.description_outlined,
};

class EmptyWorkspace extends StatelessWidget {
  const EmptyWorkspace({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
    this.label,
  });
  final IconData icon;
  final String title, description;
  final VoidCallback? action;
  final String? label;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: OrbitColors.of(context).raised,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: TextStyle(
                  color: OrbitColors.of(context).subtle,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              if (action != null) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: action,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(label!),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class HomeView extends StatelessWidget {
  const HomeView({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller, colors = OrbitColors.of(context);
    final notes = c.ofType('orbit.note'),
        tasks = c.ofType('orbit.task').where((o) => !o.isCompleted).toList();
    final recent = c.session.recent
        .map(c.find)
        .whereType<UniversalObject>()
        .where((o) => !o.isDeleted)
        .take(5)
        .toList();
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 30),
      children: [
        Text(
          'YOUR PERSONAL SPACE',
          style: TextStyle(
            color: colors.accent,
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Room for your next idea.',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Write it down. Connect the pieces. Pick up where you left off.',
          style: TextStyle(color: colors.subtle, height: 1.5),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () => c.create('orbit.note'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New note'),
            ),
            OutlinedButton.icon(
              onPressed: () => c.create('orbit.canvas'),
              icon: const Icon(Icons.dashboard_outlined, size: 18),
              label: const Text('New canvas'),
            ),
            OutlinedButton.icon(
              onPressed: () => c.create('orbit.task'),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('New task'),
            ),
            OutlinedButton.icon(
              onPressed: () => c.create('orbit.event'),
              icon: const Icon(Icons.event_outlined, size: 18),
              label: const Text('New event'),
            ),
          ],
        ),
        const SizedBox(height: 32),
        if (recent.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: colors.raised,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.history, size: 18, color: colors.accent),
                    const SizedBox(width: 10),
                    const Text(
                      'Continue session',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  recent.first.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '${c.session.tabs.length} open tabs · ${tasks.length} open tasks in this workspace',
                  style: TextStyle(color: colors.subtle),
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: () => c.openObject(recent.first.id),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Resume context'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 30),
        _heading(context, 'Recent notes', '${notes.length} total'),
        if (notes.isEmpty)
          _quiet(
            context,
            'A thought, a plan, a paragraph. Your notes will appear here.',
          )
        else
          ...notes
              .take(5)
              .map(
                (o) => ObjectRow(object: o, onTap: () => c.openObject(o.id)),
              ),
        const SizedBox(height: 26),
        _heading(context, 'Open tasks', '${tasks.length} remaining'),
        if (tasks.isEmpty)
          _quiet(
            context,
            'Nothing waiting on you. Capture a task when you need one.',
          )
        else
          ...tasks.take(4).map((o) => TaskRow(object: o, controller: c)),
        const SizedBox(height: 28),
        Row(
          children: [
            Icon(Icons.cloud_off_outlined, size: 14, color: colors.subtle),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Local by default. Your work stays with you.',
                style: TextStyle(color: colors.subtle, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _heading(BuildContext context, String title, String trailing) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const Spacer(),
            Text(
              trailing,
              style: TextStyle(
                color: OrbitColors.of(context).subtle,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
  Widget _quiet(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Text(
      text,
      style: TextStyle(color: OrbitColors.of(context).subtle, height: 1.5),
    ),
  );
}

class ObjectRow extends StatelessWidget {
  const ObjectRow({
    super.key,
    required this.object,
    required this.onTap,
    this.trailing,
  });
  final UniversalObject object;
  final VoidCallback onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    leading: Icon(
      objectIcon(object.typeId),
      size: 20,
      color: OrbitColors.of(context).subtle,
    ),
    title: Text(
      object.title.isEmpty ? 'Untitled' : object.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 14),
    ),
    subtitle: Text(
      object.typeId.replaceFirst('orbit.', ''),
      style: TextStyle(fontSize: 11, color: OrbitColors.of(context).subtle),
    ),
    trailing: trailing,
    onTap: onTap,
  );
}

class TaskRow extends StatelessWidget {
  const TaskRow({super.key, required this.object, required this.controller});
  final UniversalObject object;
  final WorkspaceController controller;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Checkbox(
      value: object.isCompleted,
      onChanged: (value) => controller.edit(
        object.id,
        properties: {...object.properties, 'completed': value},
      ),
    ),
    title: Text(
      object.title,
      style: TextStyle(
        fontSize: 14,
        decoration: object.isCompleted ? TextDecoration.lineThrough : null,
      ),
    ),
    subtitle: object.properties['dueDate'] is String
        ? Text(
            'Due ${object.properties['dueDate']}',
            style: const TextStyle(fontSize: 12),
          )
        : null,
    trailing: IconButton(
      tooltip: 'Edit task',
      onPressed: () => controller.openObject(object.id),
      icon: const Icon(Icons.open_in_new, size: 16),
    ),
  );
}

class TasksView extends StatefulWidget {
  const TasksView({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView> {
  final input = TextEditingController();
  bool completed = false;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final tasks = c
        .ofType('orbit.task')
        .where((o) => o.isCompleted == completed)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Text('Tasks', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Small steps, connected to the bigger picture.',
          style: TextStyle(color: OrbitColors.of(context).subtle),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: input,
          decoration: const InputDecoration(
            hintText: 'Add a task and press Enter',
            prefixIcon: Icon(Icons.add),
          ),
          onSubmitted: (value) async {
            if (value.trim().isEmpty) return;
            await c.create('orbit.task', title: value.trim());
            input.clear();
            c.navigate(OrbitDestination.tasks);
          },
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          children: [
            ChoiceChip(
              label: const Text('Open'),
              selected: !completed,
              onSelected: (_) => setState(() => completed = false),
            ),
            ChoiceChip(
              label: const Text('Completed'),
              selected: completed,
              onSelected: (_) => setState(() => completed = true),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Text(
              completed
                  ? 'Completed tasks will appear here.'
                  : 'No open tasks. Enjoy the space.',
              style: TextStyle(color: OrbitColors.of(context).subtle),
            ),
          )
        else
          ...tasks.map((o) => TaskRow(object: o, controller: c)),
      ],
    );
  }
}

class TaskDetail extends StatefulWidget {
  const TaskDetail({super.key, required this.object, required this.controller});
  final UniversalObject object;
  final WorkspaceController controller;
  @override
  State<TaskDetail> createState() => _TaskDetailState();
}

class _TaskDetailState extends State<TaskDetail> {
  late final title = TextEditingController(text: widget.object.title);
  late final body = TextEditingController(text: widget.object.body);
  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TaskDetail old) {
    super.didUpdateWidget(old);
    if (old.object.title != widget.object.title &&
        title.text != widget.object.title) {
      title.text = widget.object.title;
    }
    if (old.object.body != widget.object.body &&
        body.text != widget.object.body) {
      body.text = widget.object.body;
    }
  }

  void property(String key, dynamic value) => widget.controller.edit(
    widget.object.id,
    properties: {...widget.object.properties, key: value},
  );
  @override
  Widget build(BuildContext context) {
    final o = widget.object;
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Row(
          children: [
            Checkbox(
              value: o.isCompleted,
              onChanged: (v) => property('completed', v),
            ),
            Expanded(
              child: TextField(
                controller: title,
                style: Theme.of(context).textTheme.headlineSmall,
                decoration: const InputDecoration(
                  hintText: 'Task title',
                  filled: false,
                ),
                onChanged: (v) => widget.controller.edit(o.id, title: v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                initialValue:
                    ['low', 'medium', 'high'].contains(o.properties['priority'])
                    ? o.properties['priority'] as String
                    : 'medium',
                decoration: const InputDecoration(labelText: 'Priority'),
                items: ['low', 'medium', 'high']
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(v[0].toUpperCase() + v.substring(1)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => property('priority', v),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate:
                      DateTime.tryParse('${o.properties['dueDate']}') ??
                      DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (date != null) {
                  property(
                    'dueDate',
                    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                  );
                }
              },
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(o.properties['dueDate'] as String? ?? 'Set due date'),
            ),
            if (o.properties['dueDate'] != null)
              IconButton(
                tooltip: 'Clear due date',
                onPressed: () => property('dueDate', null),
                icon: const Icon(Icons.close, size: 16),
              ),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          controller: body,
          minLines: 6,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: 'Add details, context or Markdown links…',
            alignLabelWithHint: true,
          ),
          onChanged: (v) => widget.controller.edit(o.id, body: v),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue:
              widget.controller.activeObjects.any(
                (v) => v.id == o.properties['contextId'],
              )
              ? o.properties['contextId'] as String
              : null,
          decoration: const InputDecoration(labelText: 'Related context'),
          items: [
            const DropdownMenuItem(value: null, child: Text('No context')),
            ...widget.controller.activeObjects
                .where((v) => v.id != o.id && v.typeId != 'orbit.file')
                .map(
                  (v) => DropdownMenuItem(
                    value: v.id,
                    child: Text(
                      v.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
          ],
          onChanged: (v) => property('contextId', v),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => widget.controller.trash(o.id),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Move to Trash'),
          ),
        ),
      ],
    );
  }
}

class EventDetail extends StatefulWidget {
  const EventDetail({
    super.key,
    required this.object,
    required this.controller,
  });
  final UniversalObject object;
  final WorkspaceController controller;

  @override
  State<EventDetail> createState() => _EventDetailState();
}

class _EventDetailState extends State<EventDetail> {
  late final title = TextEditingController(text: widget.object.title);
  late final body = TextEditingController(text: widget.object.body);

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EventDetail old) {
    super.didUpdateWidget(old);
    if (old.object.title != widget.object.title &&
        title.text != widget.object.title) {
      title.text = widget.object.title;
    }
    if (old.object.body != widget.object.body &&
        body.text != widget.object.body) {
      body.text = widget.object.body;
    }
  }

  void property(String key, dynamic value) => widget.controller.edit(
    widget.object.id,
    properties: {...widget.object.properties, key: value},
  );

  @override
  Widget build(BuildContext context) {
    final o = widget.object;
    EventSchedule? schedule;
    try {
      schedule = EventSchedule.fromProperties(o.properties);
    } catch (_) {}

    final allDay = schedule?.allDay ?? (o.properties['allDay'] == true);

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Row(
          children: [
            const Icon(Icons.event_outlined, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: title,
                style: Theme.of(context).textTheme.headlineSmall,
                decoration: const InputDecoration(
                  hintText: 'Event title',
                  filled: false,
                ),
                onChanged: (v) => widget.controller.edit(o.id, title: v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          schedule == null
              ? 'Dates need review. The original event data is preserved.'
              : allDay
              ? '${calendarDate(schedule.start)} → ${calendarDate(schedule.end)} (exclusive) · All day'
              : '${schedule.start.toLocal()} → ${schedule.end.toLocal()} · Device local time',
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Edit dates'),
            onPressed: () async {
              final controller = widget.controller;
              if (!await controller.flushAll() || !context.mounted) {
                return;
              }
              final current = controller.find(o.id);
              if (current != null && !current.isDeleted) {
                await showEventDialog(context, controller, event: current);
              }
            },
          ),
        ),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          initialValue:
              widget.controller.activeObjects.any(
                (v) => v.id == o.properties['contextId'],
              )
              ? o.properties['contextId'] as String
              : null,
          decoration: const InputDecoration(labelText: 'Related context'),
          items: [
            const DropdownMenuItem(value: null, child: Text('No context')),
            ...widget.controller.activeObjects
                .where((v) => v.id != o.id && v.typeId != 'orbit.event')
                .map(
                  (v) => DropdownMenuItem(
                    value: v.id,
                    child: Text(
                      v.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
          ],
          onChanged: (v) => property('contextId', v),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: body,
          minLines: 6,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: 'Add details, description or links…',
            alignLabelWithHint: true,
          ),
          onChanged: (v) => widget.controller.edit(o.id, body: v),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => widget.controller.trash(o.id),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Move to Trash'),
          ),
        ),
      ],
    );
  }
}

class SearchView extends StatefulWidget {
  const SearchView({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  String query = '';
  List<UniversalObject> results = [];
  Timer? _debounce;
  int _generation = 0;
  String? searchError;
  void _search(String value) {
    _debounce?.cancel();
    final generation = ++_generation;
    setState(() {
      query = value;
      results = [];
      searchError = null;
    });
    if (value.trim().isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 180), () async {
      try {
        final found = await widget.controller.search(value.trim());
        if (mounted && generation == _generation) {
          setState(() => results = found);
        }
      } catch (e) {
        if (mounted && generation == _generation) {
          setState(() => searchError = '$e');
        }
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search your knowledge…',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: _search,
          ),
        ),
        Expanded(
          child: query.trim().isEmpty
              ? const EmptyWorkspace(
                  icon: Icons.search,
                  title: 'Find the thread.',
                  description:
                      'Search note text, task details and object titles. Everything stays on this device.',
                )
              : results.isEmpty
              ? EmptyWorkspace(
                  icon: Icons.search_off,
                  title: searchError == null
                      ? 'No matches yet'
                      : 'Search unavailable',
                  description: 'Try a shorter phrase or another title.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: results.length,
                  itemBuilder: (_, i) => ObjectRow(
                    object: results[i],
                    onTap: () => widget.controller.openObject(results[i].id),
                  ),
                ),
        ),
      ],
    );
  }
}

class SettingsView extends StatelessWidget {
  const SettingsView({
    super.key,
    required this.controller,
    required this.onExport,
    required this.onImport,
    required this.onOpenWorkspace,
  });
  final WorkspaceController controller;
  final VoidCallback onExport, onImport, onOpenWorkspace;
  @override
  Widget build(BuildContext context) {
    final c = controller, s = c.session;
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Text(
          'Make room for your way.',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'A few thoughtful controls. Always a way back.',
          style: TextStyle(color: OrbitColors.of(context).subtle),
        ),
        const SizedBox(height: 28),
        const Text(
          'APPEARANCE',
          style: TextStyle(fontSize: 11, letterSpacing: 1.8),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.dark_mode_outlined),
          title: Text('Orbit Dark'),
          subtitle: Text('Graphite surfaces · muted violet accents'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Compact density'),
          value: s.compact,
          onChanged: (v) => c.updateSession((s) => s.compact = v),
        ),
        const SizedBox(height: 22),
        const Text(
          'EDITOR',
          style: TextStyle(fontSize: 11, letterSpacing: 1.8),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Text size'),
          trailing: Text('${s.fontSize.round()} px'),
        ),
        Slider(
          value: s.fontSize,
          min: 12,
          max: 26,
          divisions: 14,
          label: '${s.fontSize.round()}',
          onChanged: (v) => c.updateSession((s) => s.fontSize = v),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Reading width'),
          trailing: Text('${s.contentWidth.round()} px'),
        ),
        Slider(
          value: s.contentWidth,
          min: 520,
          max: 1200,
          divisions: 17,
          onChanged: (v) => c.updateSession((s) => s.contentWidth = v),
        ),
        const SizedBox(height: 22),
        const Text(
          'LAYOUT & MOTION',
          style: TextStyle(fontSize: 11, letterSpacing: 1.8),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show explorer'),
          value: s.sidebarVisible,
          onChanged: (v) => c.updateSession((s) => s.sidebarVisible = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show context inspector'),
          value: s.inspectorVisible,
          onChanged: (v) => c.updateSession((s) => s.inspectorVisible = v),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: ['normal', 'reduced', 'off']
              .map(
                (mode) => ChoiceChip(
                  label: Text(mode[0].toUpperCase() + mode.substring(1)),
                  selected: s.motion == mode,
                  onSelected: (_) => c.updateSession((s) => s.motion = mode),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        Text(
          'Respects the system’s reduced-motion preference.',
          style: TextStyle(color: OrbitColors.of(context).subtle, fontSize: 12),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: c.resetLayout,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset layout'),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'YOUR DATA',
          style: TextStyle(fontSize: 11, letterSpacing: 1.8),
        ),
        const SizedBox(height: 12),
        SelectableText(
          c.repository.location,
          style: TextStyle(fontSize: 12, color: OrbitColors.of(context).subtle),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Export workspace'),
            ),
            OutlinedButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: const Text('Import backup'),
            ),
            OutlinedButton.icon(
              onPressed: onOpenWorkspace,
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Manage Vaults'),
            ),
            TextButton.icon(
              onPressed: c.refresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reload from files'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Notes use Markdown; tasks and canvases use documented JSON.\nNo account, cloud connection or AI provider is required.',
          style: TextStyle(
            fontSize: 12,
            height: 1.6,
            color: OrbitColors.of(context).subtle,
          ),
        ),
      ],
    );
  }
}
