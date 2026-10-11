import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/orbit_components.dart';
import '../../app/workspace_controller.dart';
import '../../domain/calendar_event.dart';
import '../../domain/gantt_planning.dart';
import '../../domain/working_calendar.dart';
import '../../domain/task_planning.dart';
import '../../domain/universal_object.dart';
import 'task_planning_panel.dart';
import 'working_calendar_dialog.dart';

Future<void> showGanttScheduleDialog(
  BuildContext context,
  WorkspaceController c,
  UniversalObject task, {
  DateTime? proposedStart,
  Object? defaultCalendarId,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _ScheduleDialog(
    controller: c,
    task: task,
    proposedStart: proposedStart,
    defaultCalendarId: defaultCalendarId,
  ),
);

class _ScheduleDialog extends StatefulWidget {
  const _ScheduleDialog({
    required this.controller,
    required this.task,
    this.proposedStart,
    this.defaultCalendarId,
  });
  final WorkspaceController controller;
  final UniversalObject task;
  final DateTime? proposedStart;
  final Object? defaultCalendarId;
  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  late final TextEditingController start, finish;
  late final TextEditingController effort;
  Object? calendarId;
  final Map<String, UniversalObject> calendarSnapshots = {};
  late bool milestone;
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final t = GanttTask(widget.task);
    calendarId = widget.task.properties.containsKey('workCalendarId')
        ? widget.task.properties['workCalendarId']
        : widget.defaultCalendarId;
    for (final cal in widget.controller.workingCalendars) {
      calendarSnapshots[cal.id] = cal;
    }
    Map<String, dynamic>? shifted;
    try {
      final calendar = resolveWorkingCalendar(
        calendarId,
        widget.controller.planningObjects,
      );
      effort = TextEditingController(
        text: t.valid
            ? '${workingEffort(t, calendar)}'
            : '${widget.task.properties['workDurationDays'] ?? 1}',
      );
      if (widget.proposedStart != null && t.valid) {
        shifted = calendar == null
            ? t.shiftedTo(widget.proposedStart!)
            : workingRange(
                widget.proposedStart!,
                workingEffort(t, calendar),
                calendar,
                milestone: t.milestone,
              );
      }
    } on Object catch (e) {
      error = '$e';
      effort = TextEditingController(
        text: '${widget.task.properties['workDurationDays'] ?? 1}',
      );
    }
    start = TextEditingController(
      text:
          shifted?['scheduledDate'] ??
          widget.task.properties['scheduledDate']?.toString() ??
          '',
    );
    finish = TextEditingController(
      text:
          shifted?['scheduledEndDate'] ??
          widget.task.properties['scheduledEndDate']?.toString() ??
          '',
    );
    milestone = t.milestone;
  }

  @override
  void dispose() {
    start.dispose();
    finish.dispose();
    effort.dispose();
    super.dispose();
  }

  Map<String, dynamic> get changes => {
    'scheduledDate': start.text.trim().isEmpty ? null : start.text.trim(),
    'scheduledEndDate': finish.text.trim().isEmpty ? null : finish.text.trim(),
    'ganttMilestone': milestone,
    'workCalendarId': calendarId,
    'workDurationDays': calendarId == null || start.text.trim().isEmpty
        ? null
        : (milestone ? 1 : int.tryParse(effort.text)),
  };
  Future<void> pickDate(TextEditingController field) async {
    final today = DateTime.now();
    final date = ganttDate(field.text);
    final initial = date != null && date.year >= 1900 && date.year <= 2200
        ? DateTime(date.year, date.month, date.day)
        : DateTime(today.year, today.month, today.day);
    final result = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
    );
    if (!mounted || result == null) return;
    setState(() => field.text = calendarDate(result));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final all = {for (final o in c.objects) o.id: o};
    final preview = GanttTask(
      widget.task.copyWith(properties: {...widget.task.properties, ...changes}),
    );
    WorkingCalendar? calendar;
    String? calendarIssue;
    try {
      calendar = resolveWorkingCalendar(calendarId, all);
    } on Object catch (e) {
      calendarIssue = '$e';
    }
    final blockerDate = GanttTask(widget.task).afterBlockers(all);
    DateTime? earliest;
    if (calendarIssue == null && blockerDate != null) {
      try {
        earliest = calendar?.next(blockerDate) ?? blockerDate;
      } on Object catch (e) {
        calendarIssue = '$e';
      }
    }
    final warnings = [
      ...preview.warnings(all),
      ...workingWarnings(preview, all),
    ];
    final activeDates = [if (calendarId != null) calendarId];
    void calculate(DateTime day, {bool backwards = false}) {
      try {
        if (calendarIssue != null) throw FormatException(calendarIssue);
        final count = milestone ? 1 : int.tryParse(effort.text) ?? 0;
        final dates = workingRange(
          day,
          count,
          calendar,
          backwards: backwards,
          milestone: milestone,
        );
        setState(() {
          start.text = dates['scheduledDate'];
          finish.text = dates['scheduledEndDate'];
          error = null;
        });
      } on Object catch (e) {
        setState(() => error = '$e');
      }
    }

    return PopScope(
      canPop: !saving,
      child: OrbitDialog(
        title: Text('Schedule · ${widget.task.title}'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Work dates are inclusive. Your deadline and recurring occurrence history stay unchanged.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: calendarId is String ? calendarId as String : '',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Work calendar'),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Calendar days · every day'),
                ),
                for (final cal in c.workingCalendars)
                  DropdownMenuItem(
                    value: cal.id,
                    child: Text(
                      cal.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                for (final id in activeDates)
                  if (id is String &&
                      !c.workingCalendars.any((cal) => cal.id == id))
                    DropdownMenuItem(
                      value: id,
                      child: const Text(
                        'Missing calendar · choose a replacement',
                      ),
                    ),
              ],
              onChanged: saving
                  ? null
                  : (id) => setState(() {
                      calendarId = id == '' ? null : id;
                      error = null;
                    }),
            ),
            if (calendarIssue != null)
              Text(
                calendarIssue,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: effort,
              enabled: !saving && !milestone,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: calendarId == null
                    ? 'Duration · calendar days'
                    : 'Effort · working days',
                helperText: 'Calculate dates below, then review before saving.',
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: saving || ganttDate(start.text) == null
                      ? null
                      : () => calculate(ganttDate(start.text)!),
                  child: const Text('Calculate finish'),
                ),
                TextButton(
                  onPressed: saving || preview.deadline == null
                      ? null
                      : () => calculate(preview.deadline!, backwards: true),
                  child: const Text('Plan back from deadline'),
                ),
              ],
            ),
            TextField(
              controller: start,
              enabled: !saving,
              decoration: InputDecoration(
                labelText: 'Start · YYYY-MM-DD',
                suffixIcon: IconButton(
                  tooltip: 'Choose start date',
                  onPressed: saving ? null : () => pickDate(start),
                  icon: const Icon(Icons.calendar_today_outlined),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: finish,
              enabled: !saving,
              decoration: InputDecoration(
                labelText: 'Finish · YYYY-MM-DD',
                suffixIcon: IconButton(
                  tooltip: 'Choose finish date',
                  onPressed: saving ? null : () => pickDate(finish),
                  icon: const Icon(Icons.calendar_today_outlined),
                ),
                helperText: 'Leave empty for a single-day task.',
              ),
              onChanged: (_) => setState(() {}),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Milestone'),
              value: milestone,
              onChanged: saving
                  ? null
                  : (v) => setState(() {
                      milestone = v!;
                      if (milestone) finish.text = start.text;
                    }),
            ),
            if (earliest != null)
              TextButton.icon(
                icon: const Icon(Icons.account_tree_outlined),
                label: Text('After blockers · ${calendarDate(earliest)}'),
                onPressed: saving ? null : () => calculate(earliest!),
              ),
            for (final id in taskDependencies(widget.task))
              Text('Depends on: ${all[id]?.title ?? id}'),
            if (widget.task.properties['dueDate'] != null)
              Text('Deadline: ${widget.task.properties['dueDate']}'),
            for (final warning in warnings)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  warning,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (error != null)
              Text(
                error!,
                semanticsLabel: 'Scheduling failed: $error',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: saving
                ? null
                : () => setState(() {
                    start.clear();
                    finish.clear();
                  }),
            child: const Text('Clear dates'),
          ),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    try {
                      if (calendarIssue != null) {
                        throw FormatException(calendarIssue);
                      }
                      if (calendarId != null &&
                          !milestone &&
                          start.text.trim().isNotEmpty &&
                          (int.tryParse(effort.text) == null ||
                              int.parse(effort.text) < 1 ||
                              int.parse(effort.text) > 3660)) {
                        throw const FormatException(
                          'Use 1–3,660 working days.',
                        );
                      }
                      validateGanttSchedule({
                        ...widget.task.properties,
                        ...changes,
                      });
                    } on Object catch (e) {
                      setState(() => error = '$e');
                      return;
                    }
                    setState(() {
                      saving = true;
                      error = null;
                    });
                    final ok = await c.saveWorkingSchedule(
                      widget.task,
                      changes,
                      expectedCalendar: calendarSnapshots[calendarId],
                    );
                    if (!mounted || !context.mounted) return;
                    if (ok) {
                      Navigator.pop(context);
                    } else {
                      setState(() {
                        saving = false;
                        error =
                            c.error ??
                            'This task changed. Reopen its schedule to try again.';
                      });
                    }
                  },
            child: Text(saving ? 'Saving…' : 'Save schedule'),
          ),
        ],
      ),
    );
  }
}

class GanttView extends ConsumerStatefulWidget {
  const GanttView({super.key, required this.controller, required this.view});
  final WorkspaceController controller;
  final UniversalObject view;
  @override
  ConsumerState<GanttView> createState() => _GanttViewState();
}

class _GanttViewState extends ConsumerState<GanttView> {
  late DateTime window;
  int page = 0;
  bool openOnly = false;
  String filter = '';
  static const dayWidth = 36.0, labelWidth = 260.0, rowHeight = 100.0;
  double get scaledRowHeight =>
      rowHeight *
      (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 4.0);
  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    window = DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 3));
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(workspaceProvider);
    final c = widget.controller;
    final view = c.find(widget.view.id) ?? widget.view;
    final p = view.properties;
    final issue = p['smartQuery'] != null ? c.queryViewIssue(view) : null;
    if (p['ganttVersion'] != null && p['ganttVersion'] != 1 || issue != null) {
      return Center(
        child: Text(
          issue ?? 'This Gantt definition is unsupported and preserved.',
        ),
      );
    }
    final pool = p['smartQuery'] != null ? c.queryViewObjects(view) : c.objects;
    bool matches(UniversalObject o) {
      if (o.isDeleted || o.typeId != 'orbit.task') return false;
      if (p['smartQuery'] != null) return true;
      final folder = p['folder'];
      final scope = p['scope'];
      if (folder is String && folder.isNotEmpty) {
        final f = o.properties['folder'], path = c.repository.objectPath(o.id);
        if (!(f is String && (f == folder || f.startsWith('$folder/'))) &&
            !(path?.startsWith('$folder/') ?? false)) {
          return false;
        }
      }
      if (scope is String &&
          scope.isNotEmpty &&
          !['project', 'course', 'context'].any(
            (k) =>
                o.properties[k]?.toString().toLowerCase() ==
                scope.toLowerCase(),
          )) {
        return false;
      }
      return true;
    }

    final tasks =
        pool
            .where(matches)
            .where(
              (o) =>
                  (!openOnly || !o.isCompleted) &&
                  o.title.toLowerCase().contains(filter),
            )
            .map(GanttTask.new)
            .toList()
          ..sort((a, b) {
            final date = (a.start ?? DateTime.utc(9999)).compareTo(
              b.start ?? DateTime.utc(9999),
            );
            return date != 0 ? date : a.object.id.compareTo(b.object.id);
          });
    final all = {for (final o in c.objects) o.id: o};
    WorkingCalendar? viewCalendar;
    String? calendarIssue;
    try {
      viewCalendar = resolveWorkingCalendar(p['workCalendarId'], all);
    } on Object catch (e) {
      calendarIssue = '$e';
    }
    final days = [14, 28, 56].contains(p['ganttDays'])
        ? (p['ganttDays'] as num).toInt()
        : 28;
    final totalPages = (tasks.length / 50).ceil().clamp(1, 1000000);
    final effectivePage = page.clamp(0, totalPages - 1);
    final rows = tasks.skip(effectivePage * 50).take(50).toList();
    final colors = Theme.of(context).colorScheme;
    final writable = !view.isReadOnly && !c.repository.readOnly;
    return LayoutBuilder(
      builder: (context, bounds) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: bounds.maxHeight * .35),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      view.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${tasks.length} tasks · ${tasks.where((t) => !t.valid).length} unscheduled',
                    ),
                    TextButton.icon(
                      onPressed: () => showGanttCalendars(context, c, view),
                      icon: const Icon(Icons.calendar_view_week_outlined),
                      label: Text(
                        p['workCalendarId'] == null
                            ? 'Calendars'
                            : all[p['workCalendarId']]?.title ??
                                  'Missing calendar',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _audit(
                        context,
                        c,
                        view,
                        tasks.map((t) => t.object.id).toList(),
                      ),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Schedule audit'),
                    ),
                    if (calendarIssue != null)
                      Text(
                        calendarIssue,
                        style: TextStyle(color: colors.error),
                      ),
                    IconButton(
                      tooltip: 'Previous period',
                      onPressed: () => setState(
                        () => window = window.subtract(Duration(days: days)),
                      ),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      '${calendarDate(window)} – ${calendarDate(window.add(Duration(days: days - 1)))}',
                    ),
                    IconButton(
                      tooltip: 'Next period',
                      onPressed: () => setState(
                        () => window = window.add(Duration(days: days)),
                      ),
                      icon: const Icon(Icons.chevron_right),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        final d = DateTime.now();
                        window = DateTime.utc(
                          d.year,
                          d.month,
                          d.day,
                        ).subtract(const Duration(days: 3));
                      }),
                      child: const Text('Today'),
                    ),
                    TextButton(
                      onPressed: tasks.any((t) => t.valid)
                          ? () => setState(
                              () => window = tasks
                                  .firstWhere((t) => t.valid)
                                  .start!
                                  .subtract(const Duration(days: 2)),
                            )
                          : null,
                      child: const Text('First scheduled'),
                    ),
                    DropdownButton<int>(
                      value: days,
                      items: [
                        for (final n in [14, 28, 56])
                          DropdownMenuItem(value: n, child: Text('$n days')),
                      ],
                      onChanged: writable
                          ? (n) => c.edit(
                              view.id,
                              properties: {...p, 'ganttDays': n},
                            )
                          : null,
                    ),
                    FilterChip(
                      label: const Text('Open only'),
                      selected: openOnly,
                      onSelected: (v) => setState(() {
                        openOnly = v;
                        page = 0;
                      }),
                    ),
                    SizedBox(
                      width: 210,
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Find task',
                        ),
                        onChanged: (v) => setState(() {
                          filter = v.toLowerCase();
                          page = 0;
                        }),
                      ),
                    ),
                    if (c.canUndoPlanning)
                      TextButton.icon(
                        onPressed: c.undoPlanning,
                        icon: const Icon(Icons.undo),
                        label: const Text('Undo last planning action'),
                      ),
                  ],
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: bounds.maxHeight * .15),
            child: const SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(
                  'Drag a work bar to preview a move. Click it to resize or set dates. ◆ milestone · │ deadline. Dependency lines connect visible tasks; hidden blockers remain in task details.',
                ),
              ),
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Text(
                      'No tasks in this scope. Add tasks or adjust the saved filters.',
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: labelWidth + days * dayWidth,
                      child: Column(
                        children: [
                          SizedBox(
                            height: 44,
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: labelWidth,
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text('Task / blockers'),
                                  ),
                                ),
                                for (var i = 0; i < days; i++)
                                  SizedBox(
                                    width: dayWidth,
                                    child: Center(
                                      child: Text(
                                        '${window.add(Duration(days: i)).day}',
                                        style: TextStyle(
                                          color:
                                              window
                                                      .add(Duration(days: i))
                                                      .weekday >
                                                  5
                                              ? colors.outline
                                              : colors.onSurface,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Stack(
                                children: [
                                  Column(
                                    children: [
                                      for (final task in rows)
                                        _row(
                                          context,
                                          c,
                                          task,
                                          all,
                                          days,
                                          view,
                                          viewCalendar,
                                        ),
                                    ],
                                  ),
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        painter: _Dependencies(
                                          rows: rows,
                                          window: window,
                                          days: days,
                                          rowHeight: scaledRowHeight,
                                          color: colors.primary.withValues(
                                            alpha: .65,
                                          ),
                                        ),
                                      ),
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
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: bounds.maxHeight * .15),
            child: SingleChildScrollView(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Previous task page',
                    onPressed: effectivePage > 0
                        ? () => setState(() => page = effectivePage - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    'Page ${effectivePage + 1} of $totalPages · up to 50 rows',
                  ),
                  IconButton(
                    tooltip: 'Next task page',
                    onPressed: effectivePage + 1 < totalPages
                        ? () => setState(() => page = effectivePage + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    WorkspaceController c,
    GanttTask task,
    Map<String, UniversalObject> all,
    int days,
    UniversalObject view,
    WorkingCalendar? calendar,
  ) {
    final o = task.object, scheme = Theme.of(context).colorScheme;
    final warnings = [
      ...task.warnings(all),
      ...workingWarnings(
        task,
        all,
        defaultCalendarId: view.properties['workCalendarId'],
      ),
    ];
    final writable = !o.isReadOnly && !c.repository.readOnly;
    final left = task.valid ? task.start!.difference(window).inDays : 0;
    final right = task.valid ? task.finish!.difference(window).inDays + 1 : 0;
    final visible = task.valid && right > 0 && left < days;
    final start = left.clamp(0, days), end = right.clamp(0, days);
    final deadline = task.deadline?.difference(window).inDays;
    final deps = taskDependencies(o);
    double drag = 0;
    return SizedBox(
      height: scaledRowHeight,
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: [
                        ...warnings,
                        for (final id in deps)
                          'Depends on ${all[id]?.title ?? id}',
                      ].join('\n'),
                      child: InkWell(
                        onTap: () => c.openObject(o.id),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              o.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                decoration: o.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            Text(
                              warnings.isNotEmpty
                                  ? '${warnings.length} planning warning(s)'
                                  : '${deps.length} dependencies',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: warnings.isNotEmpty
                                    ? scheme.error
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit dependencies for ${o.title}',
                    onPressed: writable
                        ? () => showTaskPlanningDialog(context, c, o)
                        : null,
                    icon: const Icon(Icons.account_tree_outlined, size: 18),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              child: Stack(
                children: [
                  for (var i = 0; i < days; i++)
                    Positioned(
                      left: i * dayWidth,
                      top: 0,
                      bottom: 0,
                      width: dayWidth,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color:
                              (calendar != null
                                  ? !calendar.isWorking(
                                      window.add(Duration(days: i)),
                                    )
                                  : window.add(Duration(days: i)).weekday > 5)
                              ? scheme.surfaceContainerHighest.withValues(
                                  alpha: .35,
                                )
                              : null,
                          border: Border(
                            left: BorderSide(
                              color: scheme.outlineVariant.withValues(
                                alpha: .4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (deadline != null && deadline >= 0 && deadline < days)
                    Positioned(
                      left: deadline * dayWidth + dayWidth / 2,
                      top: 8,
                      bottom: 8,
                      child: Tooltip(
                        message: 'Deadline ${calendarDate(task.deadline!)}',
                        child: Container(width: 2, color: scheme.error),
                      ),
                    ),
                  if (visible)
                    Positioned(
                      left: start * dayWidth + 2,
                      width: ((end - start) * dayWidth - 4).clamp(
                        20,
                        double.infinity,
                      ),
                      top: (scaledRowHeight - 48) / 2,
                      height: 48,
                      child: Semantics(
                        label:
                            '${o.title}, ${calendarDate(task.start!)} to ${calendarDate(task.finish!)}, ${warnings.join(', ')}',
                        button: true,
                        child: GestureDetector(
                          onHorizontalDragStart: writable
                              ? (_) => drag = 0
                              : null,
                          onHorizontalDragUpdate: writable
                              ? (d) => drag += d.delta.dx
                              : null,
                          onHorizontalDragEnd: writable
                              ? (_) {
                                  final delta = (drag / dayWidth).round();
                                  if (delta != 0) {
                                    showGanttScheduleDialog(
                                      context,
                                      c,
                                      o,
                                      proposedStart: task.start!.add(
                                        Duration(days: delta),
                                      ),
                                      defaultCalendarId:
                                          view.properties['workCalendarId'],
                                    );
                                  }
                                }
                              : null,
                          child: Tooltip(
                            message:
                                '${calendarDate(task.start!)} → ${calendarDate(task.finish!)}',
                            child: Material(
                              color: warnings.isNotEmpty
                                  ? scheme.errorContainer
                                  : o.isCompleted
                                  ? scheme.surfaceContainerHighest
                                  : scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                              child: InkWell(
                                onTap: writable
                                    ? () => showGanttScheduleDialog(
                                        context,
                                        c,
                                        o,
                                        defaultCalendarId:
                                            view.properties['workCalendarId'],
                                      )
                                    : () => c.openObject(o.id),
                                borderRadius: BorderRadius.circular(6),
                                child: Center(
                                  child: Text(
                                    task.milestone ? '◆' : '${task.duration}d',
                                    style: TextStyle(
                                      color: warnings.isNotEmpty
                                          ? scheme.onErrorContainer
                                          : o.isCompleted
                                          ? scheme.onSurface
                                          : scheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!visible)
                    Positioned(
                      left: 12,
                      top: 16,
                      bottom: 16,
                      child: TextButton(
                        onPressed: writable
                            ? () => showGanttScheduleDialog(
                                context,
                                c,
                                o,
                                defaultCalendarId:
                                    view.properties['workCalendarId'],
                              )
                            : null,
                        child: Text(
                          task.valid
                              ? '${calendarDate(task.start!)} → ${calendarDate(task.finish!)}'
                              : 'Set work dates',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _audit(
    BuildContext context,
    WorkspaceController c,
    UniversalObject view,
    List<String> ids,
  ) async {
    var auditPage = 0;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final all = c.planningObjects;
          final issues = <({UniversalObject task, List<String> warnings})>[];
          for (final id in ids) {
            final o = all[id];
            if (o == null || o.isDeleted) continue;
            final task = GanttTask(o);
            final warnings = [
              ...task.warnings(all),
              ...workingWarnings(
                task,
                all,
                defaultCalendarId: view.properties['workCalendarId'],
              ),
              if (!task.valid) 'Work dates are not scheduled',
            ];
            if (warnings.isNotEmpty) issues.add((task: o, warnings: warnings));
          }
          final pages = (issues.length / 25).ceil().clamp(1, 100000);
          auditPage = auditPage.clamp(0, pages - 1);
          return OrbitDialog(
            maxWidth: 720,
            title: Text('Schedule audit · ${issues.length} tasks need review'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Audit of the current task filters. Review one task at a time; no dates change automatically.',
                ),
                if (issues.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No scheduling issues found in this scope.'),
                  ),
                for (final item in issues.skip(auditPage * 25).take(25))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          item.task.title,
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                        for (final warning in item.warnings) Text('• $warning'),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => c.openObject(item.task.id),
                              child: const Text('Open task'),
                            ),
                            TextButton(
                              onPressed:
                                  item.task.isReadOnly || c.repository.readOnly
                                  ? null
                                  : () async {
                                      await showGanttScheduleDialog(
                                        ctx,
                                        c,
                                        item.task,
                                        defaultCalendarId:
                                            view.properties['workCalendarId'],
                                      );
                                      if (ctx.mounted) set(() {});
                                    },
                              child: const Text('Review schedule'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: auditPage > 0 ? () => set(() => auditPage--) : null,
                child: const Text('Previous'),
              ),
              Text('Page ${auditPage + 1} of $pages'),
              TextButton(
                onPressed: auditPage + 1 < pages
                    ? () => set(() => auditPage++)
                    : null,
                child: const Text('Next'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Dependencies extends CustomPainter {
  _Dependencies({
    required this.rows,
    required this.window,
    required this.days,
    required this.color,
    required this.rowHeight,
  });
  final List<GanttTask> rows;
  final DateTime window;
  final int days;
  final Color color;
  final double rowHeight;
  @override
  void paint(Canvas canvas, Size size) {
    final positions = {
      for (var i = 0; i < rows.length; i++) rows[i].object.id: i,
    };
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (var i = 0; i < rows.length; i++) {
      final target = rows[i];
      if (!target.valid) continue;
      final start = target.start!.difference(window).inDays;
      if (start < 0 || start >= days) continue;
      for (final id in taskDependencies(target.object)) {
        final j = positions[id];
        if (j == null || j == i || !rows[j].valid) continue;
        final finish = rows[j].finish!.difference(window).inDays + 1;
        if (finish <= 0 || finish > days) continue;
        final x1 =
            _GanttViewState.labelWidth + finish * _GanttViewState.dayWidth - 2;
        final x2 =
            _GanttViewState.labelWidth + start * _GanttViewState.dayWidth + 2;
        final y1 = j * rowHeight + rowHeight / 2 + 26,
            y2 = i * rowHeight + rowHeight / 2 - 26;
        canvas.drawPath(
          Path()
            ..moveTo(x1, y1)
            ..lineTo(x1 + 8, y1)
            ..lineTo(x1 + 8, y2)
            ..lineTo(x2, y2),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(x2 - 4, y2 - 3)
            ..lineTo(x2, y2)
            ..lineTo(x2 - 4, y2 + 3),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Dependencies oldDelegate) => true;
}
