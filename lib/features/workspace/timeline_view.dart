import 'package:flutter/material.dart';
import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';
import '../../domain/calendar_event.dart';
import '../../domain/universal_object.dart';

class TimelineEntry {
  final UniversalObject object;
  final DateTime date;
  final bool isTask;
  final bool isEvent;

  const TimelineEntry({
    required this.object,
    required this.date,
    required this.isTask,
    required this.isEvent,
  });
}

class TimelineView extends StatefulWidget {
  const TimelineView({
    super.key,
    required this.controller,
    this.viewObject,
    this.scope,
    this.folderFilter,
    this.onTaskTap,
  });

  final WorkspaceController controller;
  final UniversalObject? viewObject;
  final String? scope;
  final String? folderFilter;
  final void Function(UniversalObject task)? onTaskTap;

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final colors = OrbitColors.of(context);

    final effectiveScope =
        widget.scope ??
        (widget.viewObject?.properties['scope'] as String?)?.trim();
    final effectiveFolder =
        widget.folderFilter ??
        (widget.viewObject?.properties['folder'] as String?)?.trim();

    bool matchesScope(UniversalObject o) {
      if (effectiveFolder != null && effectiveFolder.isNotEmpty) {
        final f = o.properties['folder'];
        if (f is String && f == effectiveFolder) return true;
        final p = c.repository.objectPath(o.id);
        if (p != null && p.startsWith('$effectiveFolder/')) return true;
      }
      if (effectiveScope != null && effectiveScope.isNotEmpty) {
        final course = o.properties['course']?.toString().toLowerCase();
        final project = o.properties['project']?.toString().toLowerCase();
        final contextVal = o.properties['context']?.toString().toLowerCase();
        final lowerScope = effectiveScope.toLowerCase();
        if (course == lowerScope ||
            project == lowerScope ||
            contextVal == lowerScope) {
          return true;
        }
      }
      if ((effectiveFolder == null || effectiveFolder.isEmpty) &&
          (effectiveScope == null || effectiveScope.isEmpty)) {
        return true;
      }
      return false;
    }

    final entries = <TimelineEntry>[];

    // Collect Events
    final events = c
        .ofType('orbit.event')
        .where((e) => !e.isDeleted && matchesScope(e));
    for (final e in events) {
      final schedule = EventSchedule.fromProperties(e.properties);
      entries.add(
        TimelineEntry(
          object: e,
          date: schedule.start,
          isTask: false,
          isEvent: true,
        ),
      );
    }

    // Collect Tasks with Due Dates
    final tasks = c
        .ofType('orbit.task')
        .where((t) => !t.isDeleted && matchesScope(t));
    for (final t in tasks) {
      final dueStr = t.properties['dueDate'];
      if (dueStr is String) {
        final d = parseCalendarDate(dueStr);
        if (d != null) {
          entries.add(
            TimelineEntry(object: t, date: d, isTask: true, isEvent: false),
          );
        }
      }
    }

    // Filter by search query
    if (_filter.isNotEmpty) {
      final q = _filter.toLowerCase();
      entries.retainWhere(
        (entry) => entry.object.title.toLowerCase().contains(q),
      );
    }

    // Sort chronologically
    entries.sort((a, b) => a.date.compareTo(b.date));

    // Group by Year and Month
    final grouped = <String, List<TimelineEntry>>{};
    const monthNames = [
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
    for (final entry in entries) {
      final key = '${monthNames[entry.date.month - 1]} ${entry.date.year}';
      grouped.putIfAbsent(key, () => []).add(entry);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Filter timeline…',
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 16),
                  ),
                  onChanged: (v) => setState(() => _filter = v.trim()),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add milestone / event'),
                onPressed: () async {
                  final now = DateTime.now();
                  final today = calendarDate(now);
                  final tomorrow = calendarDate(
                    now.add(const Duration(days: 1)),
                  );
                  final props = <String, dynamic>{
                    'allDay': true,
                    'startDate': today,
                    'endDate': tomorrow,
                    if (effectiveScope != null && effectiveScope.isNotEmpty)
                      'course': effectiveScope,
                    if (effectiveFolder != null && effectiveFolder.isNotEmpty)
                      'folder': effectiveFolder,
                  };
                  await c.create(
                    'orbit.event',
                    title: 'New Milestone',
                    properties: props,
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    'No events or scheduled tasks in this timeline.',
                    style: TextStyle(color: colors.subtle, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(28, 10, 28, 40),
                  itemCount: grouped.keys.length,
                  itemBuilder: (context, groupIndex) {
                    final monthKey = grouped.keys.elementAt(groupIndex);
                    final monthEntries = grouped[monthKey]!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.raised,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              monthKey,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...monthEntries.map((entry) {
                            final o = entry.object;
                            final dayStr = '${entry.date.day}';
                            final isCompleted = o.isCompleted;
                            final priority = o.properties['priority']
                                ?.toString();
                            final estimate = o.properties['estimate']
                                ?.toString();
                            final category = o.properties['category']
                                ?.toString();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8, left: 8),
                              decoration: BoxDecoration(
                                color: colors.panel,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: colors.border.withValues(alpha: .5),
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: Container(
                                  width: 38,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: entry.isEvent
                                        ? colors.accent.withValues(alpha: .15)
                                        : colors.raised,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    dayStr,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: entry.isEvent
                                          ? colors.accent
                                          : colors.text,
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    if (entry.isTask)
                                      Checkbox(
                                        value: isCompleted,
                                        activeColor: colors.accent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        onChanged: (val) {
                                          c.edit(
                                            o.id,
                                            properties: {
                                              ...o.properties,
                                              'completed': val == true,
                                            },
                                          );
                                        },
                                      )
                                    else
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: Icon(
                                          Icons.event_outlined,
                                          size: 16,
                                          color: colors.accent,
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        o.title.isEmpty ? 'Untitled' : o.title,
                                        style: TextStyle(
                                          fontSize: 13,
                                          decoration: isCompleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                          color: isCompleted
                                              ? colors.subtle
                                              : colors.text,
                                        ),
                                      ),
                                    ),
                                    if (category != null &&
                                        category.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.raised,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          category,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: colors.subtle,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (estimate != null &&
                                        estimate.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.accent.withValues(
                                            alpha: .1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          estimate,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: colors.accent,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (priority != null &&
                                        priority != 'medium' &&
                                        priority != 'none') ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              priority == 'urgent' ||
                                                  priority == 'high'
                                              ? Theme.of(context)
                                                    .colorScheme
                                                    .error
                                                    .withValues(alpha: .15)
                                              : colors.raised,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          priority.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                priority == 'urgent' ||
                                                    priority == 'high'
                                                ? Theme.of(
                                                    context,
                                                  ).colorScheme.error
                                                : colors.subtle,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                onTap: () {
                                  if (entry.isTask &&
                                      widget.onTaskTap != null) {
                                    widget.onTaskTap!(o);
                                  } else {
                                    c.openObject(o.id);
                                  }
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
