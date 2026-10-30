import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../app/workspace_controller.dart';
import '../../domain/calendar_event.dart';
import '../../domain/event_recurrence.dart';

Future<void> showEventOccurrenceDialog(
  BuildContext context,
  WorkspaceController c,
  EventOccurrence occurrence,
) async {
  final source = occurrence.source;
  final schedule = EventSchedule.fromProperties(occurrence.properties);
  final initial = schedule.allDay ? schedule.start : schedule.start.toLocal();
  var day = DateTime(initial.year, initial.month, initial.day);
  var clock = TimeOfDay.fromDateTime(initial);
  bool busy = false;
  String? error;
  final readonly =
      c.repository.readOnly ||
      source.isReadOnly ||
      (source.properties['eventRecurrence'] as Map)['finished'] == true;
  await showOrbitDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, refresh) {
        Future<void> save({bool cancel = false, bool restore = false}) async {
          refresh(() {
            busy = true;
            error = null;
          });
          try {
            Map<String, dynamic>? dates;
            if (!cancel && !restore) {
              if (schedule.allDay) {
                final span =
                    DateTime.utc(
                          schedule.end.year,
                          schedule.end.month,
                          schedule.end.day,
                        )
                        .difference(
                          DateTime.utc(
                            initial.year,
                            initial.month,
                            initial.day,
                          ),
                        )
                        .inDays;
                dates = {
                  'allDay': true,
                  'startDate': calendarDate(day),
                  'endDate': calendarDate(
                    DateTime(day.year, day.month, day.day + span),
                  ),
                };
              } else {
                final original = schedule.start.toLocal();
                DateTime start;
                if (calendarDate(day) == calendarDate(original) &&
                    clock.hour == original.hour &&
                    clock.minute == original.minute) {
                  start = schedule.start;
                } else {
                  final candidates = deviceClockCandidates(
                    DateTime.utc(
                      day.year,
                      day.month,
                      day.day,
                      clock.hour,
                      clock.minute,
                    ),
                  );
                  if (candidates.isEmpty) {
                    throw const FormatException(
                      'This local time does not exist. Choose another time.',
                    );
                  }
                  final r = source.properties['eventRecurrence'] as Map;
                  start = r['overlap'] == 'later'
                      ? candidates.last
                      : candidates.first;
                }
                dates = {
                  'allDay': false,
                  'startAt': start.toUtc().toIso8601String(),
                  'endAt': start
                      .add(schedule.end.difference(schedule.start))
                      .toUtc()
                      .toIso8601String(),
                };
              }
            }
            final ok = await c.changeEventOccurrence(
              source,
              occurrence.occurrenceKey,
              dates: dates,
              cancel: cancel,
              restore: restore,
            );
            if (!ctx.mounted) return;
            if (ok) {
              Navigator.pop(ctx);
            } else {
              refresh(() {
                busy = false;
                error = c.error ?? 'Event changed. Reopen the occurrence.';
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
        }

        return PopScope(
          canPop: !busy,
          child: OrbitDialog(
            title: const Text('Change this occurrence'),
            maxWidth: 600,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(source.title),
                Text(occurrence.occurrenceKey),
                const Text(
                  'Only this occurrence changes. The regular series dates, duration and linked resources stay intact.',
                ),
                Text(
                  'Start: ${calendarDate(day)}${schedule.allDay ? ' · all day' : ' · ${clock.format(ctx)}'}',
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: busy || readonly
                          ? null
                          : () async {
                              final chosen = await showDatePicker(
                                context: ctx,
                                initialDate: day,
                                firstDate: DateTime(1),
                                lastDate: DateTime(9999, 12, 31),
                              );
                              if (chosen != null && ctx.mounted) {
                                refresh(() => day = chosen);
                              }
                            },
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('Choose date'),
                    ),
                    if (!schedule.allDay)
                      TextButton.icon(
                        onPressed: busy || readonly
                            ? null
                            : () async {
                                final chosen = await showTimePicker(
                                  context: ctx,
                                  initialTime: clock,
                                );
                                if (chosen != null && ctx.mounted) {
                                  refresh(() => clock = chosen);
                                }
                              },
                        icon: const Icon(Icons.schedule),
                        label: const Text('Choose time'),
                      ),
                  ],
                ),
                if (!schedule.allDay)
                  const Text(
                    'Device local time; the series earlier/later clock policy applies.',
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
              if (occurrence.changed)
                TextButton(
                  onPressed: busy || readonly
                      ? null
                      : () => save(restore: true),
                  child: const Text('Restore original'),
                ),
              TextButton(
                onPressed: busy || readonly ? null : () => save(cancel: true),
                child: const Text('Cancel occurrence'),
              ),
              FilledButton(
                onPressed: busy || readonly ? null : () => save(),
                child: const Text('Reschedule this occurrence'),
              ),
            ],
          ),
        );
      },
    ),
  );
}
