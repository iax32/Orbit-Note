import 'dart:convert';
import 'calendar_event.dart';
import 'task_planning.dart';
import 'universal_object.dart';

/// Recurrence advances one canonical event, never copies its linked knowledge.
class EventRecurrence {
  EventRecurrence(this.json) {
    TaskRecurrence(json);
    if (json['paused'] is! bool ||
        !['earlier', 'later'].contains(json['overlap']) ||
        json['processed'] is! int ||
        (json['processed'] as int) < 0 ||
        (json['processed'] as int) > 10000 ||
        json['finished'] != null && json['finished'] is! bool ||
        json['count'] != null &&
            (json['count'] is! int ||
                (json['count'] as int) < 1 ||
                (json['count'] as int) > 10000) ||
        json['until'] != null && parseCalendarDate(json['until']) == null) {
      throw const FormatException('Unsupported event recurrence settings.');
    }
  }
  final Map<String, dynamic> json;
}

/// Enumerate valid UTC instants for a wall clock using device-zone offsets.
/// A gap has no candidate; a repeated hour can have two.
List<DateTime> deviceClockCandidates(DateTime wall) {
  final local = DateTime(
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
    wall.millisecond,
    wall.microsecond,
  );
  final offsets = <Duration>{
    local.timeZoneOffset,
    local.subtract(const Duration(days: 2)).timeZoneOffset,
    local.add(const Duration(days: 2)).timeZoneOffset,
  };
  final civil = DateTime.utc(
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
    wall.millisecond,
    wall.microsecond,
  );
  final result = <DateTime>[];
  for (final offset in offsets) {
    final candidate = civil.subtract(offset);
    final back = candidate.toLocal();
    if (back.year == wall.year &&
        back.month == wall.month &&
        back.day == wall.day &&
        back.hour == wall.hour &&
        back.minute == wall.minute &&
        back.second == wall.second &&
        back.millisecond == wall.millisecond &&
        back.microsecond == wall.microsecond) {
      result.add(candidate);
    }
  }
  return result..sort();
}

typedef EventClockResolver = List<DateTime> Function(DateTime wall);

/// A read-only schedule presentation retaining the source universal UUID.
class EventOccurrence extends UniversalObject {
  EventOccurrence(
    this.source,
    this.occurrenceKey,
    Map<String, dynamic> dates, {
    this.changed = false,
  }) : super(
         id: source.id,
         workspaceId: source.workspaceId,
         typeId: source.typeId,
         title: source.title,
         body: source.body,
         createdAt: source.createdAt,
         updatedAt: source.updatedAt,
         revision: source.revision,
         properties: {...source.properties, ...dates},
       );
  final UniversalObject source;
  final String occurrenceKey;
  final bool changed;
  @override
  bool get isReadOnly => true;
}

class EventProjection {
  EventProjection(this.objects, this.issues);
  final List<UniversalObject> objects;
  final List<String> issues;
}

String eventOccurrenceKey(int ordinal) => 'occurrence:$ordinal';
Map<String, dynamic> eventScheduleFields(Map<String, dynamic> p) => {
  for (final key in ['allDay', 'startDate', 'endDate', 'startAt', 'endAt'])
    if (p.containsKey(key)) key: p[key],
};

void validateEventOverrides(Object? raw) {
  if (raw is! Map ||
      raw['version'] != 1 ||
      raw['items'] is! Map ||
      (raw['items'] as Map).length > 1000) {
    throw const FormatException(
      'Unsupported occurrence changes (limit 1,000).',
    );
  }
  for (final entry in (raw['items'] as Map).entries) {
    if (entry.key is! String ||
        !RegExp(
          r'^occurrence:(0|[1-9]\d{0,4})$',
        ).hasMatch(entry.key as String) ||
        entry.value is! Map ||
        !['cancelled', 'rescheduled'].contains(entry.value['status'])) {
      throw const FormatException('Unsupported occurrence change.');
    }
    if (entry.value['status'] == 'rescheduled') {
      EventSchedule.fromProperties(Map<String, dynamic>.from(entry.value));
    }
  }
}

/// Bounded window projection; includes overrides moved across window boundaries.
EventProjection projectEventRange(
  Iterable<UniversalObject> objects,
  DateTime from,
  DateTime until, {
  int limit = 10000,
}) {
  final result = <UniversalObject>[], issues = <String>[];
  bool intersects(Map<String, dynamic> p) {
    final s = EventSchedule.fromProperties(p);
    return s.allDay
        ? calendarDate(s.start).compareTo(calendarDate(until)) < 0 &&
              calendarDate(s.end).compareTo(calendarDate(from)) > 0
        : s.start.isBefore(until.toUtc()) && s.end.isAfter(from.toUtc());
  }

  for (final source in objects) {
    if (source is EventOccurrence ||
        source.isDeleted ||
        source.typeId != 'orbit.event' ||
        source.properties['eventRecurrence'] == null) {
      result.add(source);
      continue;
    }
    try {
      final raw = source.properties['eventRecurrence'];
      if (raw is! Map) throw const FormatException('Unsupported repeat data.');
      EventRecurrence(Map<String, dynamic>.from(raw));
      final overrides = source.properties['eventOccurrenceOverrides'];
      if (overrides != null) validateEventOverrides(overrides);
      final items = overrides == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from((overrides as Map)['items'] as Map);
      if (raw['finished'] == true) {
        final ordinal = ((raw['processed'] as int) - 1).clamp(0, 9999);
        final key = eventOccurrenceKey(ordinal);
        final change = items[key];
        if (!(change is Map && change['status'] == 'cancelled')) {
          final fields = change is Map && change['status'] == 'rescheduled'
              ? eventScheduleFields(Map<String, dynamic>.from(change))
              : eventScheduleFields(source.properties);
          result.add(
            EventOccurrence(source, key, fields, changed: change != null),
          );
        }
        continue;
      }
      final lastOverride = items.keys.fold<int>(-1, (max, key) {
        final n = int.parse(key.split(':').last);
        return n > max ? n : max;
      });
      var cursor = source.copyWith(
        properties: {
          ...source.properties,
          'eventOccurrenceHistory': [],
          'eventOccurrenceOverrides': null,
        },
      );
      var steps = 0;
      while (steps++ < limit) {
        final r = cursor.properties['eventRecurrence'] as Map;
        final key = eventOccurrenceKey(r['processed'] as int);
        final change = items[key];
        final fields = change is Map && change['status'] == 'rescheduled'
            ? eventScheduleFields(Map<String, dynamic>.from(change))
            : eventScheduleFields(cursor.properties);
        if (!(change is Map && change['status'] == 'cancelled') &&
            intersects(fields)) {
          result.add(
            EventOccurrence(source, key, fields, changed: change != null),
          );
        }
        final s = EventSchedule.fromProperties(cursor.properties);
        final start = s.allDay ? s.start : s.start.toLocal();
        if (r['paused'] == true ||
            r['finished'] == true ||
            !start.isBefore(until) && (r['processed'] as int) >= lastOverride) {
          break;
        }
        final next = advanceEventOccurrence(
          cursor,
          'completed',
          DateTime.utc(2000),
        );
        if ((next['eventRecurrence'] as Map)['finished'] == true) break;
        cursor = cursor.copyWith(
          properties: {...next, 'eventOccurrenceHistory': []},
        );
      }
      if (steps > limit) {
        issues.add(
          '${source.title}: recurrence preview reached its $limit-occurrence limit.',
        );
      }
    } on Object catch (e) {
      issues.add('${source.title}: $e');
      if (!result.any((o) => o.id == source.id)) result.add(source);
    }
  }
  return EventProjection(result, issues);
}

List<CalendarEntry> recurringEntriesOn(
  Iterable<UniversalObject> objects,
  DateTime day,
) => entriesOn(
  projectEventRange(
    objects,
    DateTime(day.year, day.month, day.day),
    DateTime(day.year, day.month, day.day + 1),
  ).objects,
  day,
);

EventOccurrence resolveEventOccurrence(UniversalObject source, String key) {
  if (!RegExp(r'^occurrence:(0|[1-9]\d{0,4})$').hasMatch(key)) {
    throw const FormatException('Invalid occurrence key.');
  }
  final target = int.parse(key.split(':').last);
  final raw = source.properties['eventRecurrence'];
  if (raw is! Map) throw const FormatException('Configure repeat first.');
  EventRecurrence(Map<String, dynamic>.from(raw));
  if (raw['finished'] == true) {
    throw const FormatException(
      'This series is finished; recorded history is retained.',
    );
  }
  if (target < (raw['processed'] as int) || target >= 10000) {
    throw const FormatException(
      'This occurrence is outside the active series.',
    );
  }
  var cursor = source.copyWith(
    properties: {
      ...source.properties,
      'eventOccurrenceHistory': [],
      'eventOccurrenceOverrides': null,
    },
  );
  while ((cursor.properties['eventRecurrence'] as Map)['processed'] < target) {
    final p = advanceEventOccurrence(cursor, 'completed', DateTime.utc(2000));
    if ((p['eventRecurrence'] as Map)['finished'] == true) {
      throw const FormatException('This occurrence is outside the series end.');
    }
    cursor = cursor.copyWith(properties: {...p, 'eventOccurrenceHistory': []});
  }
  return EventOccurrence(source, key, eventScheduleFields(cursor.properties));
}

Map<String, dynamic> advanceEventOccurrence(
  UniversalObject event,
  String outcome,
  DateTime recordedAt, {
  EventClockResolver? resolveClock,
  DateTime Function(DateTime)? localize,
}) {
  if (event.typeId != 'orbit.event' ||
      !['completed', 'skipped'].contains(outcome)) {
    throw const FormatException('Choose an event occurrence outcome.');
  }
  final raw = event.properties['eventRecurrence'];
  if (raw is! Map) throw const FormatException('Configure repeat first.');
  final rule = Map<String, dynamic>.from(raw);
  EventRecurrence(rule);
  if (rule['paused'] == true || rule['finished'] == true) {
    throw const FormatException('This series is paused or finished.');
  }
  final schedule = EventSchedule.fromProperties(event.properties);
  final local = schedule.allDay
      ? schedule.start
      : (localize ?? (d) => d.toLocal())(schedule.start);
  final processed = (rule['processed'] as int) + 1;
  final countFinished =
      rule['count'] != null && processed >= (rule['count'] as int);
  final nextDate = countFinished
      ? local
      : parseCalendarDate(TaskRecurrence(rule).next(calendarDate(local)))!;
  final finished =
      countFinished ||
      rule['until'] != null &&
          calendarDate(nextDate).compareTo(rule['until'] as String) > 0;
  final updates = <String, dynamic>{};
  if (!finished) {
    if (schedule.allDay) {
      final duration =
          DateTime.utc(schedule.end.year, schedule.end.month, schedule.end.day)
              .difference(
                DateTime.utc(
                  schedule.start.year,
                  schedule.start.month,
                  schedule.start.day,
                ),
              )
              .inDays;
      final endDate = DateTime.utc(
        nextDate.year,
        nextDate.month,
        nextDate.day + duration,
      );
      if (endDate.year > 9999) {
        throw const FormatException('Event exceeds supported dates.');
      }
      updates.addAll({
        'startDate': calendarDate(nextDate),
        'endDate': calendarDate(endDate),
      });
    } else {
      final wall = DateTime.utc(
        nextDate.year,
        nextDate.month,
        nextDate.day,
        local.hour,
        local.minute,
        local.second,
        local.millisecond,
        local.microsecond,
      );
      final candidates = (resolveClock ?? deviceClockCandidates)(wall)..sort();
      if (candidates.isEmpty) {
        throw const FormatException(
          'The next local time does not exist because of a clock change. Edit the current time before advancing; no history was changed.',
        );
      }
      final start = rule['overlap'] == 'later'
          ? candidates.last
          : candidates.first;
      final end = start.add(schedule.end.difference(schedule.start));
      if (end.year > 9999) {
        throw const FormatException('Event exceeds supported dates.');
      }
      updates.addAll({
        'startAt': start.toUtc().toIso8601String(),
        'endAt': end.toUtc().toIso8601String(),
      });
    }
  }
  final history = event.properties['eventOccurrenceHistory'];
  final overrides = event.properties['eventOccurrenceOverrides'];
  if (overrides != null) validateEventOverrides(overrides);
  final change = overrides is Map
      ? (overrides['items'] as Map)[eventOccurrenceKey(
          rule['processed'] as int,
        )]
      : null;
  final recordedSchedule = change is Map && change['status'] == 'rescheduled'
      ? EventSchedule.fromProperties(Map<String, dynamic>.from(change))
      : schedule;
  final recordedLocal = recordedSchedule.allDay
      ? recordedSchedule.start
      : (localize ?? (d) => d.toLocal())(recordedSchedule.start);
  if (change is Map &&
      change['status'] == 'cancelled' &&
      outcome != 'skipped') {
    throw const FormatException(
      'This occurrence was cancelled. Record it as skipped.',
    );
  }
  if (history != null && history is! List ||
      history is List && history.length >= 10000) {
    throw const FormatException(
      'Occurrence history is unsupported or has reached 10,000 entries. Export before continuing.',
    );
  }
  return {
    ...event.properties,
    ...updates,
    'eventRecurrence': {...rule, 'processed': processed, 'finished': finished},
    'eventOccurrenceHistory': [
      if (history is List) ...history,
      {
        'outcome': outcome,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        'allDay': recordedSchedule.allDay,
        if (recordedSchedule.allDay)
          'startDate': calendarDate(recordedSchedule.start),
        if (recordedSchedule.allDay)
          'endDate': calendarDate(recordedSchedule.end),
        if (!recordedSchedule.allDay)
          'startAt': recordedSchedule.start.toUtc().toIso8601String(),
        if (!recordedSchedule.allDay)
          'endAt': recordedSchedule.end.toUtc().toIso8601String(),
        'occurrenceKey': eventOccurrenceKey(rule['processed'] as int),
        'change': ?change,
        'rule': {...rule},
        'deviceZone': recordedLocal.timeZoneName,
        'offsetMinutes': recordedLocal.timeZoneOffset.inMinutes,
      },
    ],
  };
}

void validateEventRecurrence(
  UniversalObject event, {
  UniversalObject? previous,
}) {
  if (event is EventOccurrence) {
    throw const FormatException(
      'Save occurrence changes on the original event.',
    );
  }
  if (jsonEncode(event.properties['eventOccurrenceOverrides']) !=
          jsonEncode(previous?.properties['eventOccurrenceOverrides']) &&
      event.properties['eventOccurrenceOverrides'] != null) {
    if (event.typeId != 'orbit.event') {
      throw const FormatException('Only events have occurrence changes.');
    }
    validateEventOverrides(event.properties['eventOccurrenceOverrides']);
  }
  for (final key in ['eventRecurrence', 'eventOccurrenceHistory']) {
    final raw = event.properties[key];
    if (raw == null ||
        jsonEncode(raw) == jsonEncode(previous?.properties[key])) {
      continue;
    }
    if (event.typeId != 'orbit.event') {
      throw const FormatException('Only events can repeat.');
    }
    if (key == 'eventRecurrence') {
      if (raw is! Map) {
        throw const FormatException('Unsupported event recurrence.');
      }
      EventRecurrence(Map<String, dynamic>.from(raw));
      EventSchedule.fromProperties(event.properties);
    } else if (raw is! List ||
        raw.length > 10000 ||
        raw.any((e) => e is! Map)) {
      throw const FormatException('Unsupported occurrence history.');
    }
  }
}
