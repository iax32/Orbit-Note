import 'calendar_event.dart';
import 'gantt_planning.dart';
import 'universal_object.dart';

class WorkingCalendar {
  WorkingCalendar(Map<String, dynamic> json) : json = Map.unmodifiable(json) {
    if (json['version'] != 1 || json['weekdays'] is! List) {
      throw const FormatException(
        'Unsupported working calendar. Original data is preserved.',
      );
    }
    final week = json['weekdays'] as List;
    if (week.isEmpty ||
        week.length > 7 ||
        week.any((d) => d is! int || d < 1 || d > 7) ||
        week.toSet().length != week.length) {
      throw const FormatException(
        'Choose at least one unique working weekday.',
      );
    }
    final raw = json['exceptions'];
    if (raw != null && (raw is! Map || raw.length > 1000)) {
      throw const FormatException(
        'A calendar supports up to 1,000 date exceptions.',
      );
    }
    if (raw is Map) {
      for (final e in raw.entries) {
        if (ganttDate(e.key) == null ||
            e.value is! Map ||
            e.value['working'] is! bool ||
            e.value['label'] != null &&
                (e.value['label'] is! String ||
                    (e.value['label'] as String).length > 200)) {
          throw const FormatException(
            'Each exception needs a date, working flag and optional short label.',
          );
        }
      }
    }
  }
  final Map<String, dynamic> json;
  static Map<String, dynamic> standard() => {
    'version': 1,
    'weekdays': [1, 2, 3, 4, 5],
    'exceptions': <String, dynamic>{},
  };
  Map get exceptions => json['exceptions'] as Map? ?? const {};
  bool isWorking(DateTime date) {
    final special = exceptions[calendarDate(date)];
    return special is Map
        ? special['working'] == true
        : (json['weekdays'] as List).contains(date.weekday);
  }

  String? label(DateTime day) =>
      (exceptions[calendarDate(day)] as Map?)?['label'] as String?;
  DateTime next(DateTime day, {bool backwards = false}) {
    var result = DateTime.utc(day.year, day.month, day.day);
    for (var i = 0; i < 8000; i++) {
      if (isWorking(result)) return result;
      result = result.add(Duration(days: backwards ? -1 : 1));
    }
    throw const FormatException(
      'No working day found within the scheduling horizon.',
    );
  }

  int count(DateTime start, DateTime end) {
    final from = DateTime.utc(start.year, start.month, start.day),
        until = DateTime.utc(end.year, end.month, end.day);
    final days = until.difference(from).inDays;
    if (days < 0 || days > 20000) {
      throw const FormatException(
        'Work ranges support up to 20,001 calendar days.',
      );
    }
    var count = 0;
    for (var i = 0; i <= days; i++) {
      if (isWorking(from.add(Duration(days: i)))) count++;
    }
    return count;
  }

  DateTime boundary(DateTime day, int duration, {bool backwards = false}) {
    if (duration < 1 || duration > 3660) {
      throw const FormatException('Use 1–3,660 working days.');
    }
    var result = next(day, backwards: backwards);
    var remaining = duration - 1;
    for (var i = 0; remaining > 0 && i < 20000; i++) {
      result = result.add(Duration(days: backwards ? -1 : 1));
      if (isWorking(result)) remaining--;
    }
    if (remaining != 0) {
      throw const FormatException(
        'Work duration exceeds the scheduling horizon.',
      );
    }
    return result;
  }
}

WorkingCalendar? resolveWorkingCalendar(
  Object? id,
  Map<String, UniversalObject> all,
) {
  if (id == null) return null;
  if (id is! String) {
    throw const FormatException('Unsupported calendar reference.');
  }
  final source = all[id];
  final raw = source?.properties['workingCalendar'];
  if (source == null ||
      source.isDeleted ||
      source.typeId != 'orbit.note' ||
      raw is! Map) {
    throw const FormatException(
      'Working calendar is missing. Choose another calendar explicitly.',
    );
  }
  return WorkingCalendar(Map<String, dynamic>.from(raw));
}

int workingEffort(GanttTask task, WorkingCalendar? calendar) {
  final stored = task.object.properties['workDurationDays'];
  if (stored != null) {
    if (stored is! int || stored < 1 || stored > 3660) {
      throw const FormatException('Unsupported working duration.');
    }
    return stored;
  }
  if (!task.valid) {
    throw const FormatException(
      'Set work dates or an explicit duration first.',
    );
  }
  return task.milestone
      ? 1
      : calendar?.count(task.start!, task.finish!) ?? task.duration;
}

Map<String, dynamic> workingRange(
  DateTime anchor,
  int effort,
  WorkingCalendar? calendar, {
  bool backwards = false,
  bool milestone = false,
}) {
  if (effort < 1 || effort > 3660) {
    throw const FormatException('Use 1–3,660 working days.');
  }
  final date = DateTime.utc(anchor.year, anchor.month, anchor.day);
  final first = calendar?.next(date, backwards: backwards) ?? date;
  final last = milestone
      ? first
      : calendar?.boundary(first, effort, backwards: backwards) ??
            first.add(Duration(days: (backwards ? -1 : 1) * (effort - 1)));
  return {
    'scheduledDate': calendarDate(backwards ? last : first),
    'scheduledEndDate': calendarDate(backwards ? first : last),
  };
}

Map<String, dynamic> workingMove(
  UniversalObject object,
  DateTime day,
  Map<String, UniversalObject> all,
) {
  final calendar = resolveWorkingCalendar(
    object.properties['workCalendarId'],
    all,
  );
  if (calendar == null) return GanttTask(object).shiftedTo(day);
  final task = GanttTask(object);
  if (!task.valid) throw const FormatException('Schedule this task first.');
  final effort = workingEffort(task, calendar);
  return {
    ...workingRange(day, effort, calendar, milestone: task.milestone),
    'workDurationDays': task.milestone ? 1 : effort,
  };
}

List<String> workingWarnings(
  GanttTask task,
  Map<String, UniversalObject> all, {
  Object? defaultCalendarId,
}) {
  try {
    final calendar = resolveWorkingCalendar(
      task.object.properties.containsKey('workCalendarId')
          ? task.object.properties['workCalendarId']
          : defaultCalendarId,
      all,
    );
    if (calendar == null || !task.valid) return [];
    final result = <String>[];
    if (!calendar.isWorking(task.start!)) {
      result.add('Starts on a non-working day');
    }
    if (!calendar.isWorking(task.finish!)) {
      result.add('Finishes on a non-working day');
    }
    final count = calendar.count(task.start!, task.finish!);
    if (!task.milestone && count == 0) {
      result.add('Range contains no working days');
    }
    if (task.object.properties['workDurationDays'] != null &&
        count != workingEffort(task, calendar) &&
        !task.milestone) {
      result.add('Range no longer matches the saved working effort');
    }
    return result;
  } on Object catch (e) {
    return ['$e'];
  }
}
