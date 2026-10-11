import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/orbit_components.dart';
import '../../app/workspace_controller.dart';
import '../../domain/calendar_event.dart';
import '../../domain/calendar_planning.dart';
import '../../domain/event_recurrence.dart';
import '../../domain/study_card.dart';
import '../../domain/universal_object.dart';
import '../../platform/export_file.dart';
import 'calendar_plan_editor.dart';
import 'event_repeat_dialog.dart';
import 'event_occurrence_dialog.dart';
import 'study_workspace.dart';
import 'task_planning_panel.dart';

Future<void> showCalendarPlanning(
  BuildContext context,
  WorkspaceController c, {
  String? course,
  List<UniversalObject> Function()? scope,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      CalendarPlanningWorkspace(controller: c, course: course, scope: scope),
);

class CalendarPlanningWorkspace extends ConsumerStatefulWidget {
  const CalendarPlanningWorkspace({
    super.key,
    required this.controller,
    this.course,
    this.scope,
  });
  final WorkspaceController controller;
  final String? course;
  final List<UniversalObject> Function()? scope;
  @override
  ConsumerState<CalendarPlanningWorkspace> createState() =>
      _CalendarPlanningWorkspaceState();
}

class _CalendarPlanningWorkspaceState
    extends ConsumerState<CalendarPlanningWorkspace> {
  late DateTime _day;
  String? _course;
  String _mode = 'Agenda', _kind = 'all', _search = '';
  bool _completed = false, _exporting = false;
  String? _message;
  late final TextEditingController _searchField;
  WorkspaceController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    final saved = c.session.noteViews['calendarPlanning'];
    final supported = saved?['version'] == 1;
    _day = supported
        ? parseCalendarDate(saved?['date']) ?? DateTime.now()
        : DateTime.now();
    _course =
        widget.course ??
        (supported && saved?['course'] is String
            ? saved!['course'] as String
            : null);
    if (supported) {
      if (['Agenda', 'Week', 'Day', 'Unscheduled'].contains(saved?['mode'])) {
        _mode = saved!['mode'] as String;
      }
      if ([
        'all',
        'tasks',
        'events',
        ...calendarPlanKinds,
      ].contains(saved?['kind'])) {
        _kind = saved!['kind'] as String;
      }
      _completed = saved?['completed'] == true;
      _search = saved?['search'] is String ? saved!['search'] as String : '';
    }
    _searchField = TextEditingController(text: _search);
  }

  @override
  void dispose() {
    _searchField.dispose();
    super.dispose();
  }

  void _move(int sign) => setState(
    () => _day = DateTime(
      _day.year,
      _day.month,
      _day.day +
          sign *
              (_mode == 'Day'
                  ? 1
                  : _mode == 'Week'
                  ? 7
                  : 30),
    ),
  );

  @override
  Widget build(BuildContext context) {
    ref.watch(workspaceProvider);
    final scoped =
        widget.scope?.call() ?? c.activeObjects.where(c.inActiveSpace).toList();
    final objects = filterCalendarObjects(
      scoped,
      course: _course,
      kind: _kind,
      search: _search,
      showCompleted: _completed,
    );
    final courses = <String>{
      ?_course,
      for (final o in scoped)
        if (o.properties['course'] is String &&
            (o.properties['course'] as String).isNotEmpty)
          o.properties['course'] as String,
    }.toList()..sort();
    final rangeStart = _mode == 'Week'
        ? DateTime(_day.year, _day.month, _day.day - _day.weekday + 1)
        : DateTime(_day.year, _day.month, _day.day);
    final rangeEnd = DateTime(
      rangeStart.year,
      rangeStart.month,
      rangeStart.day +
          (_mode == 'Day'
              ? 1
              : _mode == 'Week'
              ? 7
              : 30),
    );
    final projection = projectEventRange(objects, rangeStart, rangeEnd);
    final unscheduled = objects
        .where(
          (o) =>
              o.typeId == 'orbit.task' &&
              parseCalendarDate(o.properties['scheduledDate']) == null,
        )
        .toList();
    final overdue = objects
        .where(
          (o) =>
              o.typeId == 'orbit.task' &&
              !calendarTaskFinished(o) &&
              isDueDateOverdue(parseCalendarDate(o.properties['dueDate'])),
        )
        .length;
    final effort = unscheduled.fold<int>(
      0,
      (sum, o) =>
          sum +
          (calendarPlanKind(o) == null
              ? 0
              : (o.properties['calendarPlan'] as Map)['estimateMinutes']
                    as int),
    );
    return OrbitDialog(
      title: const Text('Calendar & course planning'),
      maxWidth: 1250,
      content: SizedBox(
        height: math.max(220, MediaQuery.sizeOf(context).height * .68),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (projection.issues.isNotEmpty)
              Tooltip(
                message: projection.issues.join('\n'),
                child: Text(
                  'Some repeats need review: ${projection.issues.join(' · ')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Flexible(
              flex: 4,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!c.hasWorkspace)
                      const Text(
                        'The Vault is closed. Reopen it to plan your work.',
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final mode in [
                          'Agenda',
                          'Week',
                          'Day',
                          'Unscheduled',
                        ])
                          ChoiceChip(
                            label: Text(mode),
                            selected: _mode == mode,
                            onSelected: (_) => setState(() => _mode = mode),
                          ),
                        IconButton(
                          tooltip: 'Previous period',
                          onPressed: () => _move(-1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        TextButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _day,
                              firstDate: DateTime(1),
                              lastDate: DateTime(9999, 12, 31),
                            );
                            if (d != null && mounted) setState(() => _day = d);
                          },
                          child: Text(calendarDate(_day)),
                        ),
                        IconButton(
                          tooltip: 'Next period',
                          onPressed: () => _move(1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _day = DateTime.now()),
                          child: const Text('Today'),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'New planning item',
                          enabled: c.hasWorkspace && !c.repository.readOnly,
                          onSelected: (k) => showCalendarPlanEditor(
                            context,
                            c,
                            kind: k,
                            course: _course,
                            day: _day,
                          ),
                          itemBuilder: (_) => [
                            for (final k in calendarPlanKinds)
                              PopupMenuItem(
                                value: k,
                                child: Text(
                                  'New ${k == 'study' ? 'study session' : k}',
                                ),
                              ),
                          ],
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('+ New'),
                          ),
                        ),
                        if (c.canUndoPlanning)
                          TextButton.icon(
                            onPressed: c.undoPlanning,
                            icon: const Icon(Icons.undo),
                            label: const Text('Undo planning change'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String>(
                            initialValue: _course ?? '',
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Course',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('All courses'),
                              ),
                              for (final name in courses)
                                DropdownMenuItem(
                                  value: name,
                                  child: Text(
                                    name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => _course = v == '' ? null : v),
                          ),
                        ),
                        SizedBox(
                          width: 170,
                          child: DropdownButtonFormField<String>(
                            initialValue: _kind,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Items',
                            ),
                            items: [
                              for (final k in [
                                'all',
                                'tasks',
                                'events',
                                ...calendarPlanKinds,
                              ])
                                DropdownMenuItem(
                                  value: k,
                                  child: Text(calendarPlanLabel(k)),
                                ),
                            ],
                            onChanged: (v) => setState(() => _kind = v!),
                          ),
                        ),
                        SizedBox(
                          width: 240,
                          child: TextField(
                            controller: _searchField,
                            decoration: const InputDecoration(
                              labelText: 'Search title and description',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (v) => setState(() => _search = v),
                          ),
                        ),
                        FilterChip(
                          label: const Text('Show completed'),
                          selected: _completed,
                          onSelected: (v) => setState(() => _completed = v),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _search = '';
                            _searchField.clear();
                          }),
                          child: const Text('Clear search'),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '$overdue overdue · ${unscheduled.length} tasks without a work day · $effort estimated minutes unscheduled',
                      ),
                    ),
                    if (_message != null)
                      Semantics(liveRegion: true, child: Text(_message!)),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 6,
              child: !c.hasWorkspace
                  ? const SizedBox()
                  : _mode == 'Unscheduled'
                  ? _taskQueue(unscheduled)
                  : _mode == 'Agenda'
                  ? _agenda(projection.objects, scoped)
                  : _timeline(projection.objects, scoped),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: !c.hasWorkspace || c.repository.readOnly
              ? null
              : () async {
                  final ok = await c.rememberCalendarPlanning({
                    'version': 1,
                    'date': calendarDate(_day),
                    'mode': _mode,
                    'course': _course,
                    'kind': _kind,
                    'search': _search,
                    'completed': _completed,
                  });
                  if (mounted) {
                    setState(
                      () => _message = ok
                          ? 'This calendar view will reopen on this device.'
                          : c.error ?? 'Calendar view could not be saved.',
                    );
                  }
                },
          child: const Text('Remember view'),
        ),
        TextButton.icon(
          onPressed: _exporting || !c.hasWorkspace
              ? null
              : () async {
                  setState(() => _exporting = true);
                  try {
                    final ok = await exportFile(
                      'orbit-calendar.ics',
                      exportCalendarIcs(objects),
                      mimeType: 'text/calendar',
                    );
                    if (mounted) {
                      setState(
                        () => _message = ok
                            ? 'Exported filtered items. This is a snapshot, not calendar sync.'
                            : 'Export cancelled.',
                      );
                    }
                  } on Object catch (e) {
                    if (mounted) setState(() => _message = 'Export failed: $e');
                  } finally {
                    if (mounted) setState(() => _exporting = false);
                  }
                },
          icon: const Icon(Icons.ios_share),
          label: const Text('Export filtered calendar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _taskQueue(List<UniversalObject> tasks) {
    if (tasks.isEmpty) {
      return const Center(
        child: Text('No unscheduled tasks match these filters.'),
      );
    }
    tasks.sort(
      (a, b) => (a.properties['dueDate']?.toString() ?? '9999').compareTo(
        b.properties['dueDate']?.toString() ?? '9999',
      ),
    );
    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (_, i) => _item(
        tasks[i],
        tasks,
        label:
            'Deadline ${tasks[i].properties['dueDate'] ?? 'not set'} · work day not set',
      ),
    );
  }

  Widget _agenda(List<UniversalObject> objects, List<UniversalObject> scoped) {
    final rows = <({DateTime day, CalendarEntry? entry})>[];
    for (var i = 0; i < 30; i++) {
      final day = DateTime(_day.year, _day.month, _day.day + i);
      final entries = entriesOn(objects, day);
      if (entries.isNotEmpty) {
        rows.add((day: day, entry: null));
        rows.addAll(entries.map((e) => (day: day, entry: e)));
      }
    }
    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'No dated items in the next 30 days. Check Unscheduled or change the filters.',
        ),
      );
    }
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final row = rows[i];
        return row.entry == null
            ? Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                child: Text(
                  calendarDate(row.day),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              )
            : CalendarPlanningActions(
                controller: c,
                entry: row.entry!,
                child: _item(
                  row.entry!.object,
                  scoped,
                  label: row.entry!.label,
                ),
              );
      },
    );
  }

  String _time(double minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes.toInt() % 60).toString().padLeft(2, '0')}';

  Widget _timeline(
    List<UniversalObject> objects,
    List<UniversalObject> scoped,
  ) {
    final start = _mode == 'Day'
        ? _day
        : DateTime(_day.year, _day.month, _day.day - _day.weekday + 1);
    final days = List.generate(
      _mode == 'Day' ? 1 : 7,
      (i) => DateTime(start.year, start.month, start.day + i),
    );
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final hourHeight = 64.0 * scale;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = _mode == 'Day'
            ? math.max(240.0, constraints.maxWidth - 64)
            : 240.0 * scale;
        final color = Theme.of(context).colorScheme;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 64 + columnWidth * days.length,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 64),
                      for (final day in days)
                        SizedBox(
                          width: columnWidth,
                          height: 180 * scale,
                          child: Column(
                            children: [
                              TextButton(
                                onPressed: () => setState(() {
                                  _day = day;
                                  _mode = 'Day';
                                }),
                                child: Text(calendarDate(day)),
                              ),
                              Expanded(
                                child: ListView(
                                  children: [
                                    for (final e in entriesOn(objects, day))
                                      if (e.object.typeId == 'orbit.task' ||
                                          e.label == 'All day')
                                        ListTile(
                                          dense: true,
                                          title: Text(
                                            e.object.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: Text(e.label),
                                          onTap: () =>
                                              _details(e.object, scoped),
                                        ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  SizedBox(
                    height: hourHeight * 24,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 64,
                          child: Column(
                            children: [
                              for (var h = 0; h < 24; h++)
                                SizedBox(
                                  height: hourHeight,
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: Text(
                                      '${h.toString().padLeft(2, '0')}:00',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        for (final day in days)
                          SizedBox(
                            width: columnWidth,
                            child: Stack(
                              children: [
                                for (var h = 0; h < 24; h++)
                                  Positioned(
                                    top: h * hourHeight,
                                    left: 0,
                                    right: 0,
                                    child: Divider(
                                      height: 1,
                                      color: color.outlineVariant,
                                    ),
                                  ),
                                for (final slot in calendarTimeSlots(
                                  objects,
                                  day,
                                ))
                                  Positioned(
                                    top: slot.startMinute / 60 * hourHeight,
                                    left:
                                        slot.lane * columnWidth / slot.lanes +
                                        3,
                                    width: math.max(
                                      2,
                                      columnWidth / slot.lanes - 6,
                                    ),
                                    height: math.max(
                                      4,
                                      (slot.endMinute - slot.startMinute) /
                                          60 *
                                          hourHeight,
                                    ),
                                    child: Tooltip(
                                      message:
                                          '${slot.object.title} · ${_time(slot.startMinute)}–${_time(slot.endMinute)}',
                                      child: Semantics(
                                        button: true,
                                        label:
                                            '${slot.object.title}, ${_time(slot.startMinute)} to ${_time(slot.endMinute)}',
                                        child: Material(
                                          color:
                                              calendarPlanKind(slot.object) ==
                                                  'exam'
                                              ? color.tertiaryContainer
                                              : calendarPlanKind(slot.object) ==
                                                    'study'
                                              ? color.secondaryContainer
                                              : color.primaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          child: InkWell(
                                            onTap: () =>
                                                _details(slot.object, scoped),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            child: ClipRect(
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                child: Text(
                                                  '${_time(slot.startMinute)} ${slot.object.title}',
                                                  style: TextStyle(
                                                    color:
                                                        calendarPlanKind(
                                                              slot.object,
                                                            ) ==
                                                            'exam'
                                                        ? color
                                                              .onTertiaryContainer
                                                        : calendarPlanKind(
                                                                slot.object,
                                                              ) ==
                                                              'study'
                                                        ? color
                                                              .onSecondaryContainer
                                                        : color
                                                              .onPrimaryContainer,
                                                  ),
                                                  overflow: TextOverflow.fade,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _item(
    UniversalObject o,
    List<UniversalObject> scoped, {
    String? label,
  }) {
    final conflicts = calendarConflicts(o, scoped);
    final kind =
        calendarPlanKind(o) ?? (o.typeId == 'orbit.task' ? 'task' : 'event');
    return Card(
      elevation: 0,
      child: ListTile(
        isThreeLine: conflicts.isNotEmpty,
        leading: Icon(
          o.typeId == 'orbit.task'
              ? Icons.check_box_outlined
              : kind == 'exam'
              ? Icons.school_outlined
              : Icons.event_outlined,
        ),
        title: Text(o.title),
        subtitle: Text(
          '${label ?? kind} · ${o.properties['course'] ?? 'No course'}${conflicts.isEmpty ? '' : '\nOverlaps ${conflicts.length} timed event(s)'}',
        ),
        trailing: IconButton(
          tooltip: 'Details and linked work',
          onPressed: () => _details(o, scoped),
          icon: const Icon(Icons.more_horiz),
        ),
        onTap: () => _details(o, scoped),
      ),
    );
  }

  Future<void> _details(UniversalObject o, List<UniversalObject> scoped) async {
    final current = c.find(o.id);
    if (current == null || current.isDeleted) return;
    final occurrence = o is EventOccurrence ? o : null;
    if (occurrence != null && !identical(occurrence.source, current)) {
      setState(() => _message = 'This event changed. Reopen its occurrence.');
      return;
    }
    final displayed = occurrence ?? current;
    final course = current.properties['course']?.toString();
    EventSchedule? schedule;
    if (current.typeId == 'orbit.event') {
      try {
        schedule = EventSchedule.fromProperties(displayed.properties);
      } on Object {
        /* shown below */
      }
    }
    final localDay = schedule?.allDay == true
        ? schedule!.start
        : schedule?.start.toLocal() ?? _day;
    final endDay = schedule?.allDay == true
        ? schedule!.end
        : schedule?.end.toLocal() ?? localDay;
    final conflicts = calendarConflicts(
      displayed,
      projectEventRange(
        scoped,
        DateTime(localDay.year, localDay.month, localDay.day),
        DateTime(endDay.year, endDay.month, endDay.day + 1),
      ).objects,
    );
    final examDay = schedule?.allDay == true
        ? schedule!.start
        : schedule?.start.toLocal();
    final cards = course == null
        ? <UniversalObject>[]
        : c.studyCards
              .where((card) => card.properties['course'] == course)
              .toList();
    final workload = examDay == null
        ? 0
        : studyQueue(
            cards,
            DateTime.now().toUtc(),
            horizon: DateTime(
              examDay.year,
              examDay.month,
              examDay.day + 1,
            ).toUtc().subtract(const Duration(microseconds: 1)),
          ).length;
    await showDialog<void>(
      context: context,
      builder: (ctx) => OrbitDialog(
        title: Text(current.title),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (occurrence != null)
              Text(
                '${occurrence.occurrenceKey}${occurrence.changed ? ' · rescheduled' : ' · recurring event'}',
              ),
            Text(
              '${calendarPlanKind(current) ?? current.typeId} · ${course ?? 'No course'}',
            ),
            if (schedule != null)
              Text(
                schedule.allDay
                    ? 'All day: ${calendarDate(schedule.start)} → ${calendarDate(schedule.end)} (exclusive end)'
                    : '${schedule.start.toLocal()} → ${schedule.end.toLocal()} · Device local time',
              ),
            if (current.typeId == 'orbit.task')
              Text(
                'Deadline: ${current.properties['dueDate'] ?? 'not set'}\nWork day: ${current.properties['scheduledDate'] ?? 'not set'}',
              ),
            if (schedule != null &&
                !schedule.allDay &&
                schedule.start.toLocal().timeZoneOffset !=
                    schedule.end.toLocal().timeZoneOffset)
              Text(
                'Clock change during event · ${schedule.end.difference(schedule.start).inMinutes} elapsed minutes. UTC instants are preserved.',
              ),
            if (current.body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SelectableText(current.body),
              ),
            if (calendarPlanKind(current) != null)
              Text(
                '${(current.properties['calendarPlan'] as Map)['estimateMinutes']} estimated effort minutes',
              ),
            for (final conflict in conflicts)
              ListTile(
                leading: const Icon(Icons.warning_amber),
                title: Text('Overlaps ${conflict.title}'),
                onTap: () {
                  Navigator.pop(ctx);
                  c.openObject(conflict.id);
                },
              ),
            for (final id in calendarResources(current))
              ListTile(
                leading: const Icon(Icons.link),
                title: Text(
                  c.find(id)?.isDeleted == false
                      ? c.find(id)!.title
                      : 'Missing linked resource',
                ),
                onTap: c.find(id)?.isDeleted != false
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                        c.openObject(id);
                      },
              ),
            if (calendarPlanKind(current) == 'exam' && course != null)
              Text(
                '$workload review cards due through this exam. Ratings keep their actual due dates.',
              ),
          ],
        ),
        actions: [
          if (occurrence != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                showEventOccurrenceDialog(context, c, occurrence);
              },
              child: const Text('Change this occurrence'),
            ),
          if (current.typeId == 'orbit.event')
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                showEventRepeatDialog(context, c, current);
              },
              child: const Text('Repeat & history'),
            ),
          if (current.typeId == 'orbit.task')
            TextButton(
              onPressed: c.repository.readOnly || current.isReadOnly
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      showTaskPlanningDialog(context, c, current);
                    },
              child: const Text('Repeat & dependencies'),
            ),
          if (current.typeId == 'orbit.task')
            TextButton(
              onPressed:
                  c.repository.readOnly ||
                      current.isReadOnly ||
                      calendarTaskFinished(current)
                  ? null
                  : () async {
                      final ok = await c.completePlannedTask(current);
                      if (!ctx.mounted) return;
                      if (ok) {
                        Navigator.pop(ctx);
                      } else {
                        await showDialog<void>(
                          context: ctx,
                          builder: (errorContext) => OrbitDialog(
                            title: const Text('Task could not be completed'),
                            content: Text(
                              c.error ?? 'Refresh the item and try again.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(errorContext),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
              child: const Text('Complete task'),
            ),
          if (calendarPlanKind(current) == 'exam' && course != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                showStudyWorkspace(
                  context,
                  c,
                  course: course,
                  exam: examDay == null
                      ? null
                      : DateTime(
                          examDay.year,
                          examDay.month,
                          examDay.day + 1,
                        ).toUtc().subtract(const Duration(microseconds: 1)),
                );
              },
              child: const Text('Review for exam'),
            ),
          TextButton(
            onPressed: c.repository.readOnly || current.isReadOnly
                ? null
                : () {
                    Navigator.pop(ctx);
                    showCalendarPlanEditor(context, c, original: current);
                  },
            child: const Text('Edit plan'),
          ),
          TextButton(
            onPressed: c.repository.readOnly
                ? null
                : () {
                    Navigator.pop(ctx);
                    showCalendarPlanEditor(
                      context,
                      c,
                      kind: 'study',
                      course: course,
                      day: _day,
                      linkedWork: current,
                    );
                  },
            child: const Text('Plan linked study session'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              c.openObject(current.id);
            },
            child: const Text('Open original'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
