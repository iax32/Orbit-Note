import 'dart:convert';
import 'calendar_event.dart';
import 'event_recurrence.dart';
import 'universal_object.dart';

const calendarPlanKinds = ['assignment', 'exam', 'study', 'lecture', 'meeting'];
String calendarPlanLabel(String kind) => switch (kind) {
  'all' => 'All items',
  'tasks' => 'Tasks',
  'events' => 'Events',
  'assignment' => 'Assignments',
  'exam' => 'Exams',
  'study' => 'Study sessions',
  'lecture' => 'Lectures',
  'meeting' => 'Meetings',
  _ => kind,
};

/// Optional portable metadata on existing tasks/events; never another owner.
void validateCalendarPlan(Object? raw, String type) {
  if (raw is! Map ||
      raw['version'] != 1 ||
      !calendarPlanKinds.contains(raw['kind']) ||
      (raw['kind'] == 'assignment'
          ? type != 'orbit.task'
          : type != 'orbit.event') ||
      raw['estimateMinutes'] is! int ||
      (raw['estimateMinutes'] as int) < 0 ||
      (raw['estimateMinutes'] as int) > 10080 ||
      raw['resources'] is! List ||
      (raw['resources'] as List).length > 100 ||
      !(raw['resources'] as List).every(
        (id) => id is String && id.isNotEmpty,
      )) {
    throw const FormatException('Unsupported calendar planning metadata.');
  }
}

String? calendarPlanKind(UniversalObject o) {
  try {
    validateCalendarPlan(o.properties['calendarPlan'], o.typeId);
  } on Object {
    return null;
  }
  return (o.properties['calendarPlan'] as Map)['kind'] as String;
}

List<String> calendarResources(UniversalObject o) {
  final p = o.properties['calendarPlan'];
  return calendarPlanKind(o) == null
      ? []
      : (p as Map)['resources'].cast<String>();
}

bool calendarTaskFinished(UniversalObject o) =>
    o.isCompleted ||
    ['completed', 'done', 'cancelled'].contains(o.properties['status']);

List<UniversalObject> filterCalendarObjects(
  Iterable<UniversalObject> objects, {
  String? course,
  String kind = 'all',
  String search = '',
  bool showCompleted = false,
}) => objects
    .where(
      (o) =>
          !o.isDeleted &&
          ['orbit.event', 'orbit.task'].contains(o.typeId) &&
          (course == null || o.properties['course'] == course) &&
          (showCompleted ||
              o.typeId != 'orbit.task' ||
              !calendarTaskFinished(o)) &&
          (kind == 'all' ||
              kind == 'tasks' && o.typeId == 'orbit.task' ||
              kind == 'events' && o.typeId == 'orbit.event' ||
              calendarPlanKind(o) == kind) &&
          (search.trim().isEmpty ||
              '${o.title} ${o.body} ${o.properties['course'] ?? ''}'
                  .toLowerCase()
                  .contains(search.trim().toLowerCase())),
    )
    .toList();

/// Actual overlapping timed events, exclusive end; all-day labels are not busy hours.
List<UniversalObject> calendarConflicts(
  UniversalObject event,
  Iterable<UniversalObject> objects,
) {
  EventSchedule target;
  try {
    target = EventSchedule.fromProperties(event.properties);
  } on Object {
    return [];
  }
  if (target.allDay) return [];
  return objects.where((o) {
    final sameOccurrence =
        o.id == event.id &&
        (o is! EventOccurrence ||
            event is! EventOccurrence ||
            o.occurrenceKey == event.occurrenceKey);
    if (sameOccurrence || o.isDeleted || o.typeId != 'orbit.event') {
      return false;
    }
    try {
      final s = EventSchedule.fromProperties(o.properties);
      return !s.allDay &&
          s.start.isBefore(target.end) &&
          s.end.isAfter(target.start);
    } on Object {
      return false;
    }
  }).toList();
}

class CalendarTimeSlot {
  const CalendarTimeSlot(
    this.object,
    this.startMinute,
    this.endMinute,
    this.lane,
    this.lanes,
  );
  final UniversalObject object;
  final double startMinute, endMinute;
  final int lane, lanes;
}

/// Clip each event to the civil day, and assign non-overlapping visual lanes.
List<CalendarTimeSlot> calendarTimeSlots(
  Iterable<UniversalObject> objects,
  DateTime day,
) {
  final from = DateTime(day.year, day.month, day.day);
  final until = DateTime(day.year, day.month, day.day + 1);
  final ranges = <({UniversalObject object, double start, double end})>[];
  for (final o in objects) {
    if (o.typeId != 'orbit.event' || o.isDeleted) continue;
    try {
      final s = EventSchedule.fromProperties(o.properties);
      if (s.allDay || !s.occursOn(day)) continue;
      final start = s.start.toLocal(), end = s.end.toLocal();
      double minute(DateTime t) => t.hour * 60 + t.minute + t.second / 60;
      final startMinute = start.isBefore(from) ? 0.0 : minute(start);
      var endMinute = !end.isBefore(until) ? 1440.0 : minute(end);
      // Repeated local hours cannot be drawn twice on a civil-hour grid.
      if (endMinute <= startMinute) {
        endMinute = (startMinute + s.end.difference(s.start).inSeconds / 60)
            .clamp(startMinute, 1440);
      }
      ranges.add((object: o, start: startMinute, end: endMinute));
    } on Object {
      /* Preserve invalid imported events outside the time grid. */
    }
  }
  ranges.sort((a, b) {
    final n = a.start.compareTo(b.start);
    return n == 0 ? a.object.id.compareTo(b.object.id) : n;
  });
  final slots = <CalendarTimeSlot>[];
  var i = 0;
  while (i < ranges.length) {
    final group = [ranges[i++]];
    var edge = group.first.end;
    while (i < ranges.length && ranges[i].start < edge) {
      final r = ranges[i++];
      group.add(r);
      if (r.end > edge) edge = r.end;
    }
    final laneEnds = <double>[];
    final assigned = <int>[];
    for (final r in group) {
      var lane = laneEnds.indexWhere((end) => end <= r.start);
      if (lane < 0) {
        lane = laneEnds.length;
        laneEnds.add(r.end);
      } else {
        laneEnds[lane] = r.end;
      }
      assigned.add(lane);
    }
    for (var j = 0; j < group.length; j++) {
      final r = group[j];
      slots.add(
        CalendarTimeSlot(
          r.object,
          r.start,
          r.end,
          assigned[j],
          laneEnds.length,
        ),
      );
    }
  }
  return slots;
}

/// RFC 5545 snapshot export. Canonical UUIDs are stable UIDs; no remote sync.
String exportCalendarIcs(Iterable<UniversalObject> objects, {DateTime? now}) {
  String escape(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\n', r'\n')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,');
  String date(DateTime t) => calendarDate(t).replaceAll('-', '');
  String instant(DateTime t) =>
      '${date(t.toUtc())}T${t.toUtc().hour.toString().padLeft(2, '0')}${t.toUtc().minute.toString().padLeft(2, '0')}${t.toUtc().second.toString().padLeft(2, '0')}Z';
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Orbit Note//Local Planning//EN',
    'CALSCALE:GREGORIAN',
  ];
  for (final source in objects) {
    var o = source;
    if (o.isDeleted) continue;
    final rule = o.properties['eventRecurrence'];
    final overrides = o.properties['eventOccurrenceOverrides'];
    if (o.typeId == 'orbit.event' &&
        rule is Map &&
        rule['version'] == 1 &&
        rule['processed'] is int &&
        overrides != null) {
      try {
        validateEventOverrides(overrides);
        final ordinal =
            (rule['processed'] as int) - (rule['finished'] == true ? 1 : 0);
        final change =
            (overrides as Map)['items'][eventOccurrenceKey(
              ordinal.clamp(0, 9999),
            )];
        if (change is Map && change['status'] == 'cancelled') continue;
        if (change is Map && change['status'] == 'rescheduled') {
          o = o.copyWith(
            properties: {
              ...o.properties,
              ...eventScheduleFields(Map<String, dynamic>.from(change)),
            },
          );
        }
      } on Object {
        /* Unsupported imported changes retain the original snapshot. */
      }
    }
    final event = o.typeId == 'orbit.event';
    EventSchedule? s;
    if (event) {
      try {
        s = EventSchedule.fromProperties(o.properties);
      } on Object {
        continue;
      }
    }
    final due = parseCalendarDate(o.properties['dueDate']);
    final scheduled = parseCalendarDate(o.properties['scheduledDate']);
    if (!event &&
        (o.typeId != 'orbit.task' || due == null && scheduled == null)) {
      continue;
    }
    final component = event ? 'VEVENT' : 'VTODO';
    lines.addAll([
      'BEGIN:$component',
      'UID:${o.id}@orbit-note',
      'DTSTAMP:${instant(now ?? DateTime.now())}',
      'SUMMARY:${escape(o.title)}',
      'DESCRIPTION:${escape(o.body)}',
    ]);
    if (s != null) {
      lines.addAll(
        s.allDay
            ? [
                'DTSTART;VALUE=DATE:${date(s.start)}',
                'DTEND;VALUE=DATE:${date(s.end)}',
              ]
            : ['DTSTART:${instant(s.start)}', 'DTEND:${instant(s.end)}'],
      );
    } else {
      if (due != null) lines.add('DUE;VALUE=DATE:${date(due)}');
      if (scheduled != null) {
        lines.add(
          due != null && !scheduled.isBefore(due)
              ? 'X-ORBIT-SCHEDULED-DATE:${date(scheduled)}'
              : 'DTSTART;VALUE=DATE:${date(scheduled)}',
        );
      }
      lines.add(
        'STATUS:${calendarTaskFinished(o) ? 'COMPLETED' : 'NEEDS-ACTION'}',
      );
    }
    final course = o.properties['course'];
    if (course is String && course.isNotEmpty) {
      lines.add('CATEGORIES:${escape(course)}');
    }
    lines.add('END:$component');
  }
  lines.add('END:VCALENDAR');
  // Fold at 75 UTF-8 octets without breaking a Unicode code point.
  String fold(String line) {
    final out = StringBuffer();
    var length = 0;
    for (final rune in line.runes) {
      final char = String.fromCharCode(rune),
          bytes = utf8.encode(String.fromCharCode(rune)).length;
      if (length + bytes > 75) {
        out.write('\r\n ');
        length = 1;
      }
      out.write(char);
      length += bytes;
    }
    return out.toString();
  }

  return '${lines.map(fold).join('\r\n')}\r\n';
}
