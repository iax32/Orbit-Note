import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../app/workspace_controller.dart';
import '../../domain/calendar_event.dart';
import '../../domain/gantt_planning.dart';
import '../../domain/task_planning.dart';
import '../../domain/universal_object.dart';

class TaskPlanningPanel extends StatelessWidget {
  const TaskPlanningPanel({
    super.key,
    required this.controller,
    required this.task,
  });
  final WorkspaceController controller;
  final UniversalObject task;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final current = c.find(task.id) ?? task;
    final history = current.properties['occurrenceHistory'] is List
        ? current.properties['occurrenceHistory'] as List
        : const [];
    final blockers = taskDependencies(current);
    final parent = c.find(
      current.properties['parentTaskId'] is String
          ? current.properties['parentTaskId'] as String
          : null,
    );
    final children = c
        .ofType('orbit.task')
        .where((o) => o.properties['parentTaskId'] == current.id)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Planning', style: Theme.of(context).textTheme.titleMedium),
            OutlinedButton.icon(
              onPressed: current.isReadOnly || c.repository.readOnly
                  ? null
                  : () => showTaskPlanningDialog(context, c, current),
              icon: const Icon(Icons.tune),
              label: const Text('Repeat & dependencies'),
            ),
            OutlinedButton.icon(
              onPressed: current.isReadOnly || c.repository.readOnly
                  ? null
                  : () => c.create(
                      'orbit.task',
                      title: 'Subtask of ${current.title}',
                      properties: {
                        'parentTaskId': current.id,
                        if (current.properties['project'] != null)
                          'project': current.properties['project'],
                        if (current.properties['folder'] != null)
                          'folder': current.properties['folder'],
                      },
                    ),
              icon: const Icon(Icons.add),
              label: const Text('Add subtask'),
            ),
            if (c.canUndoPlanning)
              TextButton.icon(
                onPressed: c.undoPlanning,
                icon: const Icon(Icons.undo),
                label: const Text('Undo planning action'),
              ),
          ],
        ),
        if (current.properties['recurrence'] is Map)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Repeats ${(current.properties['recurrence'] as Map)['frequency']} · next due ${current.properties['dueDate']}\nCompleting records this occurrence and advances one date. Missed dates remain overdue.',
            ),
          ),
        if (parent != null)
          ListTile(
            title: Text('Parent · ${parent.title}'),
            onTap: () => c.openObject(parent.id),
          ),
        for (final id in blockers)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(c.find(id)?.title ?? 'Missing dependency'),
            subtitle: Text(
              c.find(id)?.isCompleted == true
                  ? 'Completed'
                  : 'Unresolved blocker',
            ),
            onTap: c.find(id)?.isDeleted == false
                ? () => c.openObject(id)
                : null,
          ),
        for (final o in children)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(o.title),
            leading: Checkbox(
              value: o.isCompleted,
              onChanged: c.repository.readOnly || o.isReadOnly
                  ? null
                  : (v) {
                      if (v == true) {
                        c.completePlannedTask(o);
                      } else {
                        c.configureTask(o, {'completed': false});
                      }
                    },
            ),
            onTap: () => c.openObject(o.id),
          ),
        if (history.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Completed occurrences · ${history.length}'),
            children: [
              for (final entry in history.reversed.take(20))
                if (entry is Map)
                  ListTile(
                    title: Text('${entry['date']}'),
                    subtitle: Text('${entry['completedAt']}'),
                  ),
              if (history.length > 20)
                TextButton(
                  onPressed: () => showOrbitDialog<void>(
                    context: context,
                    builder: (ctx) => OrbitDialog(
                      title: const Text('Occurrence history'),
                      contentSlivers: [
                        SliverList.builder(
                          itemCount: history.length,
                          itemBuilder: (_, i) {
                            final e = history[history.length - i - 1];
                            return ListTile(
                              title: Text(
                                e is Map
                                    ? '${e['date']} · ${e['completedAt']}'
                                    : '$e',
                              ),
                            );
                          },
                        ),
                      ],
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('All occurrences'),
                ),
            ],
          ),
      ],
    );
  }
}

Future<void> showTaskPlanningDialog(
  BuildContext context,
  WorkspaceController c,
  UniversalObject task,
) async {
  final raw = task.properties['recurrence'];
  if (raw != null) {
    try {
      if (raw is! Map) throw const FormatException('Unreadable recurrence.');
      TaskRecurrence(Map<String, dynamic>.from(raw));
    } on Object {
      await showOrbitDialog<void>(
        context: context,
        builder: (ctx) => OrbitDialog(
          title: const Text('Planning data needs review'),
          content: const Text(
            'This task has an unsupported recurrence. Its original data is preserved. Review the task source before changing its planning rules.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
  }
  String frequency = raw is Map
      ? raw['frequency'] as String? ?? 'none'
      : 'none';
  if (!['none', 'daily', 'weekly', 'monthly', 'yearly'].contains(frequency)) {
    return;
  }
  var interval = raw is Map ? '${raw['interval']}' : '1';
  var date = '${task.properties['dueDate'] ?? ''}';
  final dependencies = taskDependencies(task).toSet();
  var parent = task.properties['parentTaskId'] is String
      ? task.properties['parentTaskId'] as String
      : null;
  String? error;
  bool busy = false;
  final tasks = c.ofType('orbit.task').where((o) => o.id != task.id).toList();
  if (!context.mounted) return;
  await showOrbitDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => OrbitDialog(
        title: Text('Plan · ${task.title}'),
        maxWidth: 680,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              initialValue: date,
              decoration: const InputDecoration(
                labelText: 'Due date',
                helperText:
                    'YYYY-MM-DD; recurrence uses civil dates, not 24-hour intervals',
              ),
              onChanged: (v) => date = v,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: frequency,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Repeat'),
              items: [
                for (final f in [
                  'none',
                  'daily',
                  'weekly',
                  'monthly',
                  'yearly',
                ])
                  DropdownMenuItem(value: f, child: Text(f)),
              ],
              onChanged: busy ? null : (v) => set(() => frequency = v!),
            ),
            if (frequency != 'none')
              TextFormField(
                initialValue: interval,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Every',
                  helperText: '1–366 days/weeks/months/years',
                ),
                onChanged: (v) => interval = v,
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: tasks.any((t) => t.id == parent) ? parent : null,
              decoration: const InputDecoration(labelText: 'Parent task'),
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: null, child: Text('No parent')),
                for (final t in tasks)
                  DropdownMenuItem(value: t.id, child: Text(t.title)),
              ],
              onChanged: busy ? null : (v) => parent = v,
            ),
            const SizedBox(height: 16),
            const Text(
              'Dependencies · cycles are rejected. Completing a blocked task remains your explicit choice.',
            ),
            for (final id
                in dependencies
                    .where((id) => !tasks.any((t) => t.id == id))
                    .toList())
              CheckboxListTile(
                value: true,
                title: Text('Missing dependency · $id'),
                onChanged: busy
                    ? null
                    : (_) => set(() => dependencies.remove(id)),
              ),
            for (final t in tasks)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.title),
                value: dependencies.contains(t.id),
                onChanged: busy
                    ? null
                    : (v) => set(() {
                        if (v == true) {
                          dependencies.add(t.id);
                        } else {
                          dependencies.remove(t.id);
                        }
                      }),
              ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (date.trim().isNotEmpty &&
                        parseCalendarDate(date.trim()) == null) {
                      set(() => error = 'Enter a valid YYYY-MM-DD date.');
                      return;
                    }
                    final rule = frequency == 'none'
                        ? null
                        : <String, dynamic>{
                            if (raw is Map) ...Map<String, dynamic>.from(raw),
                            'version': 1,
                            'frequency': frequency,
                            'interval': int.tryParse(interval),
                            'anchorDate':
                                raw is Map &&
                                    raw['frequency'] == frequency &&
                                    task.properties['dueDate'] == date
                                ? raw['anchorDate']
                                : date.trim(),
                          };
                    set(() => busy = true);
                    final ok = await c.configureTask(task, {
                      'recurrence': rule,
                      'dueDate': date.trim().isEmpty ? null : date.trim(),
                      'blockedBy': dependencies.toList(),
                      'parentTaskId': parent,
                    });
                    if (!ctx.mounted) return;
                    if (ok) {
                      Navigator.pop(ctx);
                    } else {
                      set(() {
                        busy = false;
                        error = c.error ?? 'Could not save planning changes.';
                      });
                    }
                  },
            child: const Text('Apply'),
          ),
        ],
      ),
    ),
  );
}

class CalendarDragData {
  const CalendarDragData(this.object, this.field);
  final UniversalObject object;
  final String field;
}

Future<void> previewCalendarMove(
  BuildContext context,
  WorkspaceController c,
  CalendarDragData data,
  DateTime day,
) async {
  bool busy = false;
  String? error;
  await showOrbitDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => OrbitDialog(
        title: Text('Reschedule ${data.object.title}'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${data.field == 'dueDate'
                  ? 'Deadline'
                  : data.object.typeId == 'orbit.event'
                  ? 'Event start'
                  : 'Scheduled work'} → ${calendarDate(day)}',
            ),
            const SizedBox(height: 12),
            if (data.object.typeId == 'orbit.task' &&
                data.field == 'scheduledDate' &&
                GanttTask(data.object).valid &&
                GanttTask(data.object).end != null)
              Text(c.workMoveSummary(data.object, day)),
            const Text(
              'The same object will update everywhere. Moving scheduled work preserves its duration; deadlines stay separate. Event duration is preserved. You can undo this action.',
            ),
            if (error != null) Text(error!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    set(() => busy = true);
                    final ok = await c.rescheduleObject(
                      data.object,
                      day,
                      field: data.field,
                    );
                    if (!ctx.mounted) return;
                    if (ok) {
                      Navigator.pop(ctx);
                    } else {
                      set(() {
                        busy = false;
                        error = c.error ?? 'Could not move this item.';
                      });
                    }
                  },
            child: const Text('Move'),
          ),
        ],
      ),
    ),
  );
}

class CalendarPlanningActions extends StatelessWidget {
  const CalendarPlanningActions({
    super.key,
    required this.controller,
    required this.entry,
    required this.child,
  });
  final WorkspaceController controller;
  final CalendarEntry entry;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final data = CalendarDragData(
      entry.object,
      entry.label == 'Deadline' ? 'dueDate' : 'scheduledDate',
    );
    final enabled = !controller.repository.readOnly && !entry.object.isReadOnly;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        child,
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Draggable<CalendarDragData>(
              data: data,
              maxSimultaneousDrags: enabled ? 1 : 0,
              feedback: Material(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(entry.object.title),
                ),
              ),
              child: Tooltip(
                message: 'Drag ${entry.label.toLowerCase()} to a calendar day',
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.drag_indicator, size: 18),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: !enabled
                  ? null
                  : () async {
                      final day = await showDatePicker(
                        context: context,
                        initialDate: entry.start.toLocal(),
                        firstDate: DateTime(1),
                        lastDate: DateTime(9999, 12, 31),
                      );
                      if (day != null && context.mounted) {
                        await previewCalendarMove(
                          context,
                          controller,
                          data,
                          day,
                        );
                      }
                    },
              icon: const Icon(Icons.event_outlined, size: 16),
              label: Text('Move ${entry.label.toLowerCase()}'),
            ),
          ],
        ),
      ],
    );
  }
}
