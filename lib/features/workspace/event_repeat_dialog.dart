import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../app/workspace_controller.dart';
import '../../domain/calendar_event.dart';
import '../../domain/event_recurrence.dart';
import '../../domain/universal_object.dart';

Future<void> showEventRepeatDialog(
  BuildContext context,
  WorkspaceController c,
  UniversalObject original,
) async {
  final raw = original.properties['eventRecurrence'];
  EventSchedule schedule;
  try {
    schedule = EventSchedule.fromProperties(original.properties);
    if (raw != null) {
      if (raw is! Map) throw const FormatException('Unsupported repeat data.');
      EventRecurrence(Map<String, dynamic>.from(raw));
    }
  } on Object catch (e) {
    await showOrbitDialog<void>(
      context: context,
      builder: (ctx) => OrbitDialog(
        title: const Text('Repeat data needs review'),
        content: Text('$e\nOriginal data is preserved.'),
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
  final old = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  final start = schedule.allDay ? schedule.start : schedule.start.toLocal();
  var frequency = old['frequency'] as String? ?? 'weekly';
  var overlap = old['overlap'] as String? ?? 'earlier';
  var paused = old['paused'] == true;
  final interval = TextEditingController(text: '${old['interval'] ?? 1}');
  final count = TextEditingController(text: '${old['count'] ?? ''}');
  final until = TextEditingController(text: '${old['until'] ?? ''}');
  bool busy = false;
  String? error;
  final readonly = original.isReadOnly || c.repository.readOnly;
  Map<String, dynamic> rule() => {
    ...old,
    'version': 1,
    'frequency': frequency,
    'interval': int.tryParse(interval.text),
    'anchorDate': old['anchorDate'] ?? calendarDate(start),
    'processed': old['processed'] ?? 0,
    'paused': paused,
    'overlap': overlap,
    'count': count.text.trim().isEmpty ? null : int.tryParse(count.text),
    'until': until.text.trim().isEmpty ? null : until.text.trim(),
  };
  Future<void> run(
    BuildContext ctx,
    StateSetter refresh,
    Future<bool> Function() action,
  ) async {
    refresh(() {
      busy = true;
      error = null;
    });
    final ok = await action();
    if (!ctx.mounted) return;
    if (ok) {
      Navigator.pop(ctx);
    } else {
      refresh(() {
        busy = false;
        error = c.error ?? 'This item changed. Reopen it and try again.';
      });
    }
  }

  try {
    if (!context.mounted) return;
    await showOrbitDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) {
          final preview = <String>[];
          try {
            var next = original.copyWith(
              properties: {...original.properties, 'eventRecurrence': rule()},
            );
            for (var i = 0; i < 6; i++) {
              if ((next.properties['eventRecurrence'] as Map)['finished'] ==
                  true) {
                break;
              }
              final s = EventSchedule.fromProperties(next.properties);
              preview.add(
                s.allDay ? calendarDate(s.start) : '${s.start.toLocal()}',
              );
              next = next.copyWith(
                properties: advanceEventOccurrence(
                  next,
                  'completed',
                  DateTime.now(),
                ),
              );
            }
          } on Object catch (e) {
            preview.add('$e');
          }
          final history = original.properties['eventOccurrenceHistory'];
          return PopScope(
            canPop: !busy,
            child: OrbitDialog(
              maxWidth: 680,
              title: const Text('Event repeat & history'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(original.title),
                  const Text(
                    'The calendar shows the current occurrence. Record it to advance one date; missed dates stay available. History and links remain on this event.',
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: frequency,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Repeat'),
                    items: [
                      for (final f in ['daily', 'weekly', 'monthly', 'yearly'])
                        DropdownMenuItem(value: f, child: Text(f)),
                    ],
                    onChanged: busy || readonly
                        ? null
                        : (v) => refresh(() => frequency = v!),
                  ),
                  TextField(
                    controller: interval,
                    enabled: !busy && !readonly,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Every (1–366 periods)',
                    ),
                    onChanged: (_) => refresh(() {}),
                  ),
                  TextField(
                    controller: count,
                    enabled: !busy && !readonly,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Total occurrences (optional, 1–10,000)',
                    ),
                    onChanged: (_) => refresh(() {}),
                  ),
                  TextField(
                    controller: until,
                    enabled: !busy && !readonly,
                    decoration: const InputDecoration(
                      labelText: 'Last start date (optional, YYYY-MM-DD)',
                    ),
                    onChanged: (_) => refresh(() {}),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pause series'),
                    value: paused,
                    onChanged: busy || readonly
                        ? null
                        : (v) => refresh(() => paused = v),
                  ),
                  if (!schedule.allDay) ...[
                    const Text(
                      'Repeats use this device’s local start clock and retain elapsed duration. Changing device timezone changes future local dates. A nonexistent time stops the advance; edit the event time first.',
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: overlap,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'When the clock repeats an hour',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'earlier',
                          child: Text('Use the earlier instant'),
                        ),
                        DropdownMenuItem(
                          value: 'later',
                          child: Text('Use the later instant'),
                        ),
                      ],
                      onChanged: busy || readonly
                          ? null
                          : (v) => refresh(() => overlap = v!),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text('Upcoming starts\n${preview.join('\n')}'),
                  if (old['finished'] == true)
                    const Text(
                      'Series finished. The last occurrence remains on the calendar.',
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Recorded occurrences: ${history is List ? history.length : 0}',
                  ),
                  if (raw != null)
                    const Text(
                      'Record and skip use the saved repeat settings. Save changes before recording an occurrence.',
                    ),
                  if (original.properties['eventOccurrenceOverrides'] is Map)
                    ExpansionTile(
                      title: const Text('Individual occurrence changes'),
                      children: [
                        for (final entry
                            in ((original.properties['eventOccurrenceOverrides']
                                            as Map)['items']
                                        is Map
                                    ? (original.properties['eventOccurrenceOverrides']
                                              as Map)['items']
                                          as Map
                                    : <String, dynamic>{})
                                .entries)
                          ListTile(
                            title: Text(
                              '${entry.key} · ${entry.value is Map ? entry.value['status'] : 'unsupported'}',
                            ),
                            subtitle: Text(
                              entry.value is Map
                                  ? '${entry.value['startDate'] ?? entry.value['startAt'] ?? 'Original date cancelled'}'
                                  : 'Data retained',
                            ),
                            trailing: TextButton(
                              onPressed: busy || readonly
                                  ? null
                                  : () => run(
                                      ctx,
                                      refresh,
                                      () => c.changeEventOccurrence(
                                        original,
                                        entry.key.toString(),
                                        restore: true,
                                      ),
                                    ),
                              child: const Text('Restore'),
                            ),
                          ),
                      ],
                    ),
                  if (history is List && history.isNotEmpty)
                    ExpansionTile(
                      title: const Text('Occurrence history'),
                      children: [
                        for (final h in history.reversed.take(100))
                          ListTile(
                            title: Text(
                              h is Map
                                  ? '${h['outcome']} · ${h['startDate'] ?? h['startAt']}'
                                  : 'Unsupported history record',
                            ),
                            subtitle: Text(
                              h is Map
                                  ? '${h['recordedAt']} · ${h['deviceZone'] ?? 'date only'}'
                                  : '$h',
                            ),
                          ),
                        if (history.length > 100)
                          const Text(
                            'Showing the most recent 100. All entries remain in the original event file and document history.',
                          ),
                      ],
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
                  child: const Text('Close'),
                ),
                if (raw != null && !paused && old['finished'] != true)
                  for (final outcome in ['skipped', 'completed'])
                    TextButton(
                      onPressed: busy || readonly
                          ? null
                          : () => run(
                              ctx,
                              refresh,
                              () => c.recordEventOccurrence(original, outcome),
                            ),
                      child: Text(
                        outcome == 'skipped'
                            ? 'Skip occurrence'
                            : 'Record completed',
                      ),
                    ),
                FilledButton(
                  onPressed: busy || readonly
                      ? null
                      : () async {
                          if (count.text.trim().isNotEmpty &&
                              int.tryParse(count.text) == null) {
                            refresh(
                              () => error =
                                  'Enter a whole-number occurrence count.',
                            );
                            return;
                          }
                          await run(
                            ctx,
                            refresh,
                            () => c.configureEventRepeat(original, rule()),
                          );
                        },
                  child: const Text('Save repeat'),
                ),
              ],
            ),
          );
        },
      ),
    );
  } finally {
    interval.dispose();
    count.dispose();
    until.dispose();
  }
}
