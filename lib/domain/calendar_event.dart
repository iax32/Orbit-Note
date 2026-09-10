import 'universal_object.dart';
import 'workspace_failure.dart';

String calendarDate(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

DateTime? parseCalendarDate(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return null;
  }
  final date = DateTime.tryParse(value);
  return date != null && calendarDate(date) == value ? date : null;
}

/// Date-only intervals use exclusive end dates; timed intervals are UTC instants.
/// Calendar display converts timed intervals to the current device's local zone.
class EventSchedule {
  const EventSchedule(this.start, this.end, {required this.allDay});
  final DateTime start, end;
  final bool allDay;
  factory EventSchedule.fromProperties(Map<String, dynamic> properties) {
    final allDay = properties['allDay'];
    if (allDay is! bool) {
      throw const WorkspaceFailure('Choose all-day or timed dates.');
    }
    DateTime? instant(Object? value) => value is String && value.endsWith('Z')
        ? DateTime.tryParse(value)
        : null;
    final start = allDay
        ? parseCalendarDate(properties['startDate'])
        : instant(properties['startAt']);
    final end = allDay
        ? parseCalendarDate(properties['endDate'])
        : instant(properties['endAt']);
    if (start == null || end == null || !end.isAfter(start)) {
      throw const WorkspaceFailure(
        'An event needs valid dates and an end after its start.',
      );
    }
    final contextId = properties['contextId'];
    if (contextId != null && contextId is! String) {
      throw const WorkspaceFailure(
        'Event context must reference an object ID.',
      );
    }
    return EventSchedule(start, end, allDay: allDay);
  }
  bool occursOn(DateTime day) {
    final from = DateTime(day.year, day.month, day.day);
    final until = DateTime(day.year, day.month, day.day + 1);
    if (allDay) return start.isBefore(until) && end.isAfter(from);
    return start.isBefore(until.toUtc()) && end.isAfter(from.toUtc());
  }
}

class CalendarEntry {
  const CalendarEntry(this.object, this.label, this.start);
  final UniversalObject object;
  final String label;
  final DateTime start;
}

List<CalendarEntry> entriesOn(Iterable<UniversalObject> objects, DateTime day) {
  final entries = <CalendarEntry>[];
  for (final object in objects) {
    if (object.isDeleted) continue;
    if (object.typeId == 'orbit.event') {
      try {
        final schedule = EventSchedule.fromProperties(object.properties);
        if (schedule.occursOn(day)) {
          entries.add(
            CalendarEntry(
              object,
              schedule.allDay ? 'All day' : 'Timed event',
              schedule.start,
            ),
          );
        }
      } on WorkspaceFailure {
        /* Invalid imported dates stay available in the explorer. */
      }
    } else if (object.typeId == 'orbit.task') {
      for (final (field, label) in [
        ('dueDate', 'Deadline'),
        ('scheduledDate', 'Scheduled'),
      ]) {
        final date = parseCalendarDate(object.properties[field]);
        if (date != null && calendarDate(date) == calendarDate(day)) {
          entries.add(CalendarEntry(object, label, date));
        }
      }
    }
  }
  entries.sort((a, b) {
    final date = a.start.compareTo(b.start);
    return date != 0 ? date : a.object.title.compareTo(b.object.title);
  });
  return entries;
}
