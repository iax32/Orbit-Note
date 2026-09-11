import '../../app/orbit_components.dart';
import 'package:flutter/material.dart';

import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';
import '../../domain/calendar_event.dart';
import '../../domain/universal_object.dart';
import 'workspace_views.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class CalendarView extends StatefulWidget {
  const CalendarView({super.key, required this.controller});
  final WorkspaceController controller;

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late DateTime _visibleMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  void _previousMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
      _selectedDay = DateTime(
        _visibleMonth.year,
        _visibleMonth.month,
        _selectedDay.day.clamp(
          1,
          DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day,
        ),
      );
    });
  }

  void _nextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
      _selectedDay = DateTime(
        _visibleMonth.year,
        _visibleMonth.month,
        _selectedDay.day.clamp(
          1,
          DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day,
        ),
      );
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _visibleMonth = DateTime(now.year, now.month);
      _selectedDay = DateTime(now.year, now.month, now.day);
    });
  }

  List<DateTime> _daysForGrid() => calendarMonthDays(_visibleMonth);

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final days = _daysForGrid();
    final dayEntries = entriesOn(widget.controller.objects, _selectedDay);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        final calendarPane = Column(
          children: [
            _buildHeader(context, colors),
            _buildWeekdayRow(colors),
            Expanded(child: _buildGrid(days, colors)),
          ],
        );

        final agendaPane = _buildAgenda(
          context,
          colors,
          dayEntries,
          isWide: wide,
        );

        if (wide) {
          return Row(
            children: [
              Expanded(flex: 3, child: calendarPane),
              VerticalDivider(width: 1, color: colors.border),
              SizedBox(width: 320, child: agendaPane),
            ],
          );
        } else {
          return Column(
            children: [
              Expanded(flex: 5, child: calendarPane),
              Divider(height: 1, color: colors.border),
              Expanded(flex: 4, child: agendaPane),
            ],
          );
        }
      },
    );
  }

  Widget _buildHeader(BuildContext context, OrbitColors colors) {
    final monthName = _months[_visibleMonth.month - 1];
    final title = '$monthName ${_visibleMonth.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: OrbitMotionScope.duration(context, OrbitMotion.panel),
              child: Text(
                title,
                key: ValueKey(title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _goToToday,
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Today'),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Previous month',
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: _previousMonth,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: 'Next month',
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: _nextMonth,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: () => showEventDialog(
              context,
              widget.controller,
              initialDate: _selectedDay,
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New event'),
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayRow(OrbitColors colors) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: Row(
      children: [
        for (final day in _weekdays)
          Expanded(
            child: Center(
              child: Text(
                day,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.subtle,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _buildGrid(List<DateTime> days, OrbitColors colors) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisExtent: 64,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final isCurrentMonth = day.month == _visibleMonth.month;
          final isToday =
              day.year == today.year &&
              day.month == today.month &&
              day.day == today.day;
          final isSelected =
              day.year == _selectedDay.year &&
              day.month == _selectedDay.month &&
              day.day == _selectedDay.day;

          final entries = entriesOn(widget.controller.objects, day);
          final eventCount = entries
              .where((e) => e.object.typeId == 'orbit.event')
              .length;
          final taskCount = entries
              .where((e) => e.object.typeId == 'orbit.task')
              .length;

          return InkWell(
            onTap: () {
              setState(() {
                _selectedDay = day;
                if (day.month != _visibleMonth.month) {
                  _visibleMonth = DateTime(day.year, day.month);
                }
              });
            },
            onDoubleTap: () =>
                showEventDialog(context, widget.controller, initialDate: day),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.raised
                    : (isToday
                          ? colors.accent.withAlpha(20)
                          : Colors.transparent),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? colors.accent
                      : (isToday ? colors.accent.withAlpha(80) : colors.border),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isToday ? colors.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isToday || isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isToday
                                ? Colors.white
                                : (isCurrentMonth
                                      ? colors.text
                                      : colors.subtle.withAlpha(120)),
                          ),
                        ),
                      ),
                      if (entries.isNotEmpty)
                        Text(
                          '${entries.length}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: colors.subtle,
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  if (entries.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (eventCount > 0)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 3),
                            decoration: BoxDecoration(
                              color: colors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (taskCount > 0)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.orange.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAgenda(
    BuildContext context,
    OrbitColors colors,
    List<CalendarEntry> entries, {
    required bool isWide,
  }) {
    final monthName = _months[_selectedDay.month - 1];
    final dayLabel =
        '${_weekdays[_selectedDay.weekday - 1]}, $monthName ${_selectedDay.day}, ${_selectedDay.year}';

    return Container(
      color: colors.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DAY AGENDA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: colors.accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dayLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Add event on this day',
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: () => showEventDialog(
                    context,
                    widget.controller,
                    initialDate: _selectedDay,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_available,
                            size: 36,
                            color: colors.subtle.withAlpha(120),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No events or deadlines',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.subtle,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => showEventDialog(
                              context,
                              widget.controller,
                              initialDate: _selectedDay,
                            ),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add event'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      if (entry.object.typeId == 'orbit.task') {
                        return _buildTaskCard(context, colors, entry);
                      }
                      return _buildEventCard(context, colors, entry);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(
    BuildContext context,
    OrbitColors colors,
    CalendarEntry entry,
  ) {
    final o = entry.object;
    EventSchedule? schedule;
    try {
      schedule = EventSchedule.fromProperties(o.properties);
    } catch (_) {}

    final timeText = schedule == null
        ? entry.label
        : schedule.allDay
        ? 'All day'
        : '${schedule.start.toLocal().hour.toString().padLeft(2, '0')}:${schedule.start.toLocal().minute.toString().padLeft(2, '0')} - '
              '${schedule.end.toLocal().hour.toString().padLeft(2, '0')}:${schedule.end.toLocal().minute.toString().padLeft(2, '0')}';

    final contextId = o.properties['contextId'] as String?;
    final contextObject = contextId != null
        ? widget.controller.find(contextId)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_outlined, size: 16, color: colors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  o.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Edit event',
                icon: const Icon(Icons.edit_outlined, size: 15),
                onPressed: () =>
                    showEventDialog(context, widget.controller, event: o),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.schedule, size: 13, color: colors.subtle),
              const SizedBox(width: 4),
              Text(
                timeText,
                style: TextStyle(fontSize: 11, color: colors.subtle),
              ),
              if (contextObject != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => widget.controller.openObject(contextObject.id),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: colors.accent.withAlpha(25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          objectIcon(contextObject.typeId),
                          size: 11,
                          color: colors.accent,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          contextObject.title,
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.accent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (o.body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              o.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: colors.subtle),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    OrbitColors colors,
    CalendarEntry entry,
  ) {
    final o = entry.object;
    final isDone = o.isCompleted;

    return Container(
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Checkbox(
            value: isDone,
            visualDensity: VisualDensity.compact,
            onChanged: (v) => widget.controller.edit(
              o.id,
              properties: {...o.properties, 'completed': v ?? false},
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => widget.controller.openObject(o.id),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color: isDone ? colors.subtle : colors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(25),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          entry.label,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                      if (o.properties['priority'] != null &&
                          o.properties['priority'] != 'medium') ...[
                        const SizedBox(width: 4),
                        Text(
                          '${o.properties['priority']}',
                          style: TextStyle(fontSize: 10, color: colors.subtle),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showEventDialog(
  BuildContext context,
  WorkspaceController controller, {
  DateTime? initialDate,
  UniversalObject? event,
}) async {
  final isEditing = event != null;
  final date = initialDate ?? DateTime.now();

  String initialTitle = event?.title ?? '';
  String initialBody = event?.body ?? '';
  bool allDay = true;
  bool saving = false;
  String? saveError;
  EventSchedule? originalSchedule;
  DateTime startDate = DateTime(date.year, date.month, date.day);
  DateTime endDate = DateTime(date.year, date.month, date.day + 1);
  TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);
  String? contextId = event?.properties['contextId'] is String
      ? event!.properties['contextId'] as String
      : null;

  if (isEditing) {
    try {
      final schedule = EventSchedule.fromProperties(event.properties);
      originalSchedule = schedule;
      allDay = schedule.allDay;
      if (allDay) {
        startDate = schedule.start;
        endDate = schedule.end;
      } else {
        final startLocal = schedule.start.toLocal();
        final endLocal = schedule.end.toLocal();
        startDate = DateTime(startLocal.year, startLocal.month, startLocal.day);
        endDate = DateTime(endLocal.year, endLocal.month, endLocal.day);
        startTime = TimeOfDay(hour: startLocal.hour, minute: startLocal.minute);
        endTime = TimeOfDay(hour: endLocal.hour, minute: endLocal.minute);
      }
    } catch (_) {
      await showDialog<void>(
        context: context,
        builder: (context) => OrbitDialog(
          title: const Text('Event dates need review'),
          content: const Text(
            'This event contains unsupported or invalid dates. Its original data '
            'has been preserved. Review the event’s open JSON file before editing dates.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
  }

  if (!context.mounted) {
    return;
  }
  final titleController = TextEditingController(text: initialTitle);
  final bodyController = TextEditingController(text: initialBody);

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => PopScope(
        canPop: !saving,
        child: OrbitDialog(
          title: Text(isEditing ? 'Edit event' : 'New event'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Event title',
                      hintText: 'Meeting, Lecture, Milestone…',
                    ),
                  ),
                  if (saveError != null)
                    Text(
                      saveError!,
                      key: const ValueKey('event-save-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('All day'),
                    value: allDay,
                    contentPadding: EdgeInsets.zero,
                    onChanged: saving
                        ? null
                        : (v) => setState(() {
                            allDay = v;
                            if (v && !endDate.isAfter(startDate)) {
                              endDate = DateTime(
                                startDate.year,
                                startDate.month,
                                startDate.day + 1,
                              );
                            } else if (!v && originalSchedule == null) {
                              endDate = startDate;
                            }
                          }),
                  ),
                  const SizedBox(height: 12),
                  if (allDay) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: startDate,
                                firstDate: DateTime(1),
                                lastDate: DateTime(9999, 12, 31),
                              );
                              if (picked != null) {
                                setState(() {
                                  startDate = picked;
                                  if (!endDate.isAfter(startDate)) {
                                    endDate = DateTime(
                                      startDate.year,
                                      startDate.month,
                                      startDate.day + 1,
                                    );
                                  }
                                });
                              }
                            },
                            icon: const Icon(
                              Icons.calendar_today_outlined,
                              size: 15,
                            ),
                            label: Text('From: ${calendarDate(startDate)}'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: endDate,
                                firstDate: DateTime(
                                  startDate.year,
                                  startDate.month,
                                  startDate.day + 1,
                                ),
                                lastDate: DateTime(9999, 12, 31),
                              );
                              if (picked != null) {
                                setState(() => endDate = picked);
                              }
                            },
                            icon: const Icon(
                              Icons.calendar_today_outlined,
                              size: 15,
                            ),
                            label: Text(
                              'Until (exclusive): ${calendarDate(endDate)}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const Text('Times use this device’s local time zone.'),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: startDate,
                                firstDate: DateTime(1),
                                lastDate: DateTime(9999, 12, 31),
                              );
                              if (picked != null) {
                                setState(() {
                                  startDate = picked;
                                  if (endDate.isBefore(startDate)) {
                                    endDate = startDate;
                                  }
                                });
                              }
                            },
                            child: Text(calendarDate(startDate)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: startTime,
                              );
                              if (picked != null) {
                                setState(() => startTime = picked);
                              }
                            },
                            child: Text(startTime.format(context)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: endDate,
                                firstDate: startDate,
                                lastDate: DateTime(9999, 12, 31),
                              );
                              if (picked != null) {
                                setState(() => endDate = picked);
                              }
                            },
                            child: Text(calendarDate(endDate)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: endTime,
                              );
                              if (picked != null) {
                                setState(() => endTime = picked);
                              }
                            },
                            child: Text(endTime.format(context)),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: contextId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Linked context (optional)',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('No context'),
                      ),
                      if (contextId != null &&
                          !controller.activeObjects.any(
                            (o) =>
                                o.id == contextId && o.typeId != 'orbit.event',
                          ))
                        DropdownMenuItem(
                          value: contextId,
                          child: const Text('Unavailable context (preserved)'),
                        ),
                      ...controller.activeObjects
                          .where(
                            (o) =>
                                (event == null || o.id != event.id) &&
                                o.typeId != 'orbit.event',
                          )
                          .map(
                            (o) => DropdownMenuItem(
                              value: o.id,
                              child: Text(
                                o.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                    ],
                    onChanged: (v) => setState(() => contextId = v),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: bodyController,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Notes / Agenda',
                      hintText: 'Add details, description or links…',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (isEditing)
              TextButton(
                onPressed: saving
                    ? null
                    : () async {
                        setState(() => saving = true);
                        await controller.trash(event.id);
                        if (!context.mounted) return;
                        if (controller.find(event.id)?.isDeleted == true) {
                          Navigator.pop(context);
                        } else {
                          setState(() {
                            saving = false;
                            saveError =
                                controller.error ??
                                'Could not delete the event.';
                          });
                        }
                      },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setState(() {
                        saving = true;
                        saveError = null;
                      });
                      try {
                        final properties = <String, dynamic>{
                          ...?event?.properties,
                          'allDay': allDay,
                        };
                        for (final field in [
                          'startDate',
                          'endDate',
                          'startAt',
                          'endAt',
                          'contextId',
                        ]) {
                          properties.remove(field);
                        }
                        if (allDay) {
                          properties['startDate'] = calendarDate(startDate);
                          properties['endDate'] = calendarDate(endDate);
                        } else {
                          final start = eventLocalInstant(
                            startDate,
                            startTime.hour,
                            startTime.minute,
                            original: originalSchedule?.allDay == false
                                ? originalSchedule!.start
                                : null,
                          );
                          final end = eventLocalInstant(
                            endDate,
                            endTime.hour,
                            endTime.minute,
                            original: originalSchedule?.allDay == false
                                ? originalSchedule!.end
                                : null,
                          );
                          properties['startAt'] = start.toIso8601String();
                          properties['endAt'] = end.toIso8601String();
                        }
                        if (contextId != null) {
                          properties['contextId'] = contextId;
                        }
                        EventSchedule.fromProperties(properties);
                        final saved = await controller.saveEvent(
                          original: event,
                          title: titleController.text.trim(),
                          body: bodyController.text,
                          properties: properties,
                        );
                        if (!context.mounted) return;
                        if (saved != null) {
                          Navigator.pop(context);
                          return;
                        }
                        setState(() {
                          saveError =
                              controller.error ?? 'Could not save the event.';
                          saving = false;
                        });
                      } catch (e) {
                        if (context.mounted) {
                          setState(() {
                            saveError = '$e';
                            saving = false;
                          });
                        }
                      }
                    },
              child: Text(isEditing ? 'Save' : 'Create'),
            ),
          ],
        ),
      ),
    ),
  );
  // The closing route still builds its fields during the exit animation.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  titleController.dispose();
  bodyController.dispose();
}
