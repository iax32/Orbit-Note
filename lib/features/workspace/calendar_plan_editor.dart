import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../app/workspace_controller.dart';
import '../../domain/calendar_event.dart';
import '../../domain/calendar_planning.dart';
import '../../domain/universal_object.dart';

Future<void> showCalendarPlanEditor(
  BuildContext context,
  WorkspaceController c, {
  UniversalObject? original,
  String kind = 'assignment',
  String? course,
  DateTime? day,
  UniversalObject? linkedWork,
}) async {
  if (original?.properties['calendarPlan'] != null &&
      calendarPlanKind(original!) == null) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => OrbitDialog(
        title: const Text('Planning data needs review'),
        content: const Text(
          'This item uses unsupported planning metadata. Its original data is preserved; open the original to inspect it.',
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
  final title = TextEditingController(
    text:
        original?.title ??
        (linkedWork == null ? '' : 'Work on ${linkedWork.title}'),
  );
  final body = TextEditingController(text: original?.body ?? '');
  final subject = TextEditingController(
    text: original?.properties['course']?.toString() ?? course ?? '',
  );
  final estimate = TextEditingController(
    text:
        ((original?.properties['calendarPlan'] as Map?)?['estimateMinutes'] ??
                60)
            .toString(),
  );
  kind = original == null
      ? kind
      : calendarPlanKind(original) ??
            (original.typeId == 'orbit.task' ? 'assignment' : 'meeting');
  var start =
      parseCalendarDate(original?.properties['dueDate']) ??
      day ??
      DateTime.now();
  var end = DateTime(start.year, start.month, start.day);
  var scheduled = parseCalendarDate(original?.properties['scheduledDate']);
  var allDay = original == null
      ? kind == 'assignment'
      : original.properties['allDay'] != false;
  var startTime = const TimeOfDay(hour: 9, minute: 0),
      endTime = const TimeOfDay(hour: 10, minute: 0);
  EventSchedule? oldSchedule;
  if (original?.typeId == 'orbit.event') {
    try {
      oldSchedule = EventSchedule.fromProperties(original!.properties);
      start = oldSchedule.allDay
          ? oldSchedule.start
          : oldSchedule.start.toLocal();
      end = oldSchedule.allDay
          ? DateTime(
              oldSchedule.end.year,
              oldSchedule.end.month,
              oldSchedule.end.day - 1,
            )
          : oldSchedule.end.toLocal();
      startTime = TimeOfDay.fromDateTime(start);
      endTime = TimeOfDay.fromDateTime(end);
    } on Object {
      title.dispose();
      body.dispose();
      subject.dispose();
      estimate.dispose();
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => OrbitDialog(
            title: const Text('Event dates need review'),
            content: const Text(
              'This event contains unsupported dates. Open the original to review its data; the existing event has been preserved.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
      return;
    }
  }
  final resources = {
    if (original != null) ...calendarResources(original),
    if (linkedWork != null) linkedWork.id,
  };
  String priority = original?.properties['priority']?.toString() ?? 'medium';
  bool busy = false;
  String? error;
  final readonly = c.repository.readOnly || original?.isReadOnly == true;
  Future<DateTime?> pick(BuildContext ctx, DateTime initial) => showDatePicker(
    context: ctx,
    initialDate: initial,
    firstDate: DateTime(1),
    lastDate: DateTime(9999, 12, 31),
  );
  try {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) {
          final assignment = kind == 'assignment';
          return PopScope(
            canPop: !busy,
            child: OrbitDialog(
              maxWidth: 760,
              title: Text(
                original == null
                    ? 'New ${kind == 'study' ? 'study session' : kind}'
                    : 'Edit ${original.title}',
              ),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: title,
                    autofocus: true,
                    enabled: !busy && !readonly,
                    maxLength: 2000,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: kind,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Template'),
                    items: [
                      for (final k in calendarPlanKinds.where(
                        (k) =>
                            original == null ||
                            (original.typeId == 'orbit.task'
                                ? k == 'assignment'
                                : k != 'assignment'),
                      ))
                        DropdownMenuItem(
                          value: k,
                          child: Text(k == 'study' ? 'study session' : k),
                        ),
                    ],
                    onChanged: busy || readonly
                        ? null
                        : (v) => refresh(() {
                            kind = v!;
                            if (original == null) allDay = kind == 'assignment';
                          }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subject,
                    enabled: !busy && !readonly,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Course / subject',
                      helperText:
                          'Use the same course name as your notes and review cards.',
                    ),
                  ),
                  TextField(
                    controller: body,
                    enabled: !busy && !readonly,
                    maxLength: 100000,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Description / preparation',
                    ),
                  ),
                  TextField(
                    controller: estimate,
                    enabled: !busy && !readonly,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Estimated effort (minutes)',
                      helperText:
                          '0–10,080 minutes; this is your estimate, not tracked time.',
                    ),
                  ),
                  if (assignment)
                    DropdownButtonFormField<String>(
                      initialValue: ['low', 'medium', 'high'].contains(priority)
                          ? priority
                          : 'medium',
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: [
                        for (final p in ['low', 'medium', 'high'])
                          DropdownMenuItem(value: p, child: Text(p)),
                      ],
                      onChanged: busy || readonly ? null : (v) => priority = v!,
                    ),
                  if (!assignment)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('All day'),
                      subtitle: const Text(
                        'Timed events use this device’s local time zone.',
                      ),
                      value: allDay,
                      onChanged: busy || readonly
                          ? null
                          : (v) => refresh(() => allDay = v),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: busy || readonly
                            ? null
                            : () async {
                                final value = await pick(ctx, start);
                                if (value != null && ctx.mounted) {
                                  refresh(() {
                                    start = value;
                                    if (end.isBefore(start)) end = start;
                                  });
                                }
                              },
                        child: Text(
                          '${assignment ? 'Deadline' : 'Starts'}: ${calendarDate(start)}',
                        ),
                      ),
                      if (!assignment)
                        OutlinedButton(
                          onPressed: busy || readonly
                              ? null
                              : () async {
                                  final value = await pick(ctx, end);
                                  if (value != null && ctx.mounted) {
                                    refresh(() => end = value);
                                  }
                                },
                          child: Text(
                            'Ends: ${calendarDate(end)}${allDay ? ' (inclusive)' : ''}',
                          ),
                        ),
                      if (!assignment && !allDay) ...[
                        OutlinedButton(
                          onPressed: busy || readonly
                              ? null
                              : () async {
                                  final t = await showTimePicker(
                                    context: ctx,
                                    initialTime: startTime,
                                  );
                                  if (t != null && ctx.mounted) {
                                    refresh(() => startTime = t);
                                  }
                                },
                          child: Text('Start ${startTime.format(ctx)}'),
                        ),
                        OutlinedButton(
                          onPressed: busy || readonly
                              ? null
                              : () async {
                                  final t = await showTimePicker(
                                    context: ctx,
                                    initialTime: endTime,
                                  );
                                  if (t != null && ctx.mounted) {
                                    refresh(() => endTime = t);
                                  }
                                },
                          child: Text('End ${endTime.format(ctx)}'),
                        ),
                      ],
                      if (assignment)
                        OutlinedButton(
                          onPressed: busy || readonly
                              ? null
                              : () async {
                                  final d = await pick(ctx, scheduled ?? start);
                                  if (d != null && ctx.mounted) {
                                    refresh(() => scheduled = d);
                                  }
                                },
                          child: Text(
                            scheduled == null
                                ? 'Schedule work (optional)'
                                : 'Work on ${calendarDate(scheduled!)}',
                          ),
                        ),
                      if (assignment && scheduled != null)
                        TextButton(
                          onPressed: busy || readonly
                              ? null
                              : () => refresh(() => scheduled = null),
                          child: const Text('Clear scheduled day'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Linked notes, PDFs, assignments and resources'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final id in resources)
                        InputChip(
                          label: Text(
                            c.find(id)?.isDeleted == false
                                ? c.find(id)!.title
                                : 'Missing resource',
                          ),
                          onDeleted: busy || readonly
                              ? null
                              : () => refresh(() => resources.remove(id)),
                        ),
                    ],
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.link),
                    label: const Text('Link a resource'),
                    onPressed: busy || readonly
                        ? null
                        : () async {
                            final search = TextEditingController();
                            try {
                              final id = await showDialog<String>(
                                context: ctx,
                                builder: (picker) => StatefulBuilder(
                                  builder: (picker, update) {
                                    final candidates = c.activeObjects
                                        .where(
                                          (o) =>
                                              o.id != original?.id &&
                                              !resources.contains(o.id) &&
                                              o.title.toLowerCase().contains(
                                                search.text.toLowerCase(),
                                              ),
                                        )
                                        .toList();
                                    return OrbitDialog(
                                      title: const Text(
                                        'Link existing resource',
                                      ),
                                      content: Column(
                                        children: [
                                          TextField(
                                            controller: search,
                                            autofocus: true,
                                            decoration: const InputDecoration(
                                              labelText: 'Search resources',
                                            ),
                                            onChanged: (_) => update(() {}),
                                          ),
                                          SizedBox(
                                            height: 260,
                                            child: ListView.builder(
                                              itemCount: candidates.length,
                                              itemBuilder: (_, i) => ListTile(
                                                title: Text(
                                                  candidates[i].title,
                                                ),
                                                subtitle: Text(
                                                  candidates[i].typeId,
                                                ),
                                                onTap: () => Navigator.pop(
                                                  picker,
                                                  candidates[i].id,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(picker),
                                          child: const Text('Cancel'),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              );
                              if (id != null && ctx.mounted) {
                                refresh(() => resources.add(id));
                              }
                            } finally {
                              search.dispose();
                            }
                          },
                  ),
                  if (error != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: busy || readonly
                      ? null
                      : () async {
                          refresh(() {
                            busy = true;
                            error = null;
                          });
                          try {
                            final dates = assignment
                                ? <String, dynamic>{
                                    'dueDate': calendarDate(start),
                                    'scheduledDate': scheduled == null
                                        ? null
                                        : calendarDate(scheduled!),
                                  }
                                : <String, dynamic>{
                                    'allDay': allDay,
                                    if (allDay) ...{
                                      'startDate': calendarDate(start),
                                      'endDate': calendarDate(
                                        DateTime(
                                          end.year,
                                          end.month,
                                          end.day + 1,
                                        ),
                                      ),
                                    } else ...{
                                      'startAt': eventLocalInstant(
                                        start,
                                        startTime.hour,
                                        startTime.minute,
                                        original: oldSchedule?.allDay == false
                                            ? oldSchedule!.start
                                            : null,
                                      ).toIso8601String(),
                                      'endAt': eventLocalInstant(
                                        end,
                                        endTime.hour,
                                        endTime.minute,
                                        original: oldSchedule?.allDay == false
                                            ? oldSchedule!.end
                                            : null,
                                      ).toIso8601String(),
                                    },
                                  };
                            final saved = await c.saveCalendarPlan(
                              original: original,
                              title: title.text,
                              body: body.text,
                              kind: kind,
                              course: subject.text,
                              dates: dates,
                              estimateMinutes:
                                  int.tryParse(estimate.text) ?? -1,
                              resources: resources.toList(),
                              priority: priority,
                            );
                            if (!ctx.mounted) return;
                            if (saved != null) {
                              Navigator.pop(ctx);
                            } else {
                              refresh(() {
                                busy = false;
                                error =
                                    c.error ??
                                    'Item could not be saved. Try again.';
                              });
                            }
                          } on Object catch (e) {
                            if (ctx.mounted) {
                              refresh(() {
                                busy = false;
                                error = '$e';
                              });
                            }
                          }
                        },
                  child: const Text('Save'),
                ),
              ],
            ),
          );
        },
      ),
    );
  } finally {
    title.dispose();
    body.dispose();
    subject.dispose();
    estimate.dispose();
  }
}
