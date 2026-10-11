import 'dart:convert';
import 'calendar_event.dart';
import 'universal_object.dart';

class TaskRecurrence {
  TaskRecurrence(this.json) {
    if (json['version'] != 1 ||
        !{'daily', 'weekly', 'monthly', 'yearly'}.contains(json['frequency']) ||
        json['interval'] is! int ||
        (json['interval'] as int) < 1 ||
        (json['interval'] as int) > 366 ||
        parseCalendarDate(json['anchorDate']) == null) {
      throw const FormatException(
        'Unsupported recurrence. Choose a frequency, interval and anchor date.',
      );
    }
  }
  final Map<String, dynamic> json;
  String next(String due) {
    final current = parseCalendarDate(due);
    if (current == null) {
      throw const FormatException('Recurring tasks need a valid due date.');
    }
    final interval = json['interval'] as int;
    final anchor = parseCalendarDate(json['anchorDate'])!;
    DateTime next;
    switch (json['frequency']) {
      case 'daily':
      case 'weekly':
        next = DateTime.utc(
          current.year,
          current.month,
          current.day + interval * (json['frequency'] == 'weekly' ? 7 : 1),
        );
      case 'monthly':
      case 'yearly':
        final month = DateTime.utc(
          current.year,
          current.month + interval * (json['frequency'] == 'yearly' ? 12 : 1),
        );
        final last = DateTime.utc(month.year, month.month + 1, 0).day;
        next = DateTime.utc(month.year, month.month, anchor.day.clamp(1, last));
      default:
        throw const FormatException('Unsupported recurrence.');
    }
    if (next.year > 9999) {
      throw const FormatException('Recurrence exceeds supported dates.');
    }
    return calendarDate(next);
  }
}

List<String> taskDependencies(UniversalObject o) {
  final raw = o.properties['blockedBy'];
  return raw is String && raw.isNotEmpty
      ? [raw]
      : raw is List
      ? raw.whereType<String>().toSet().toList()
      : [];
}

/// Validate new edges, preserving imported unresolved references on unrelated edits.
void validateTaskPlanning(
  UniversalObject object,
  Iterable<UniversalObject> objects, {
  UniversalObject? previous,
}) {
  final p = object.properties;
  final unchangedRecurrence =
      previous != null &&
      jsonEncode(p['recurrence']) ==
          jsonEncode(previous.properties['recurrence']) &&
      p['dueDate'] == previous.properties['dueDate'] &&
      object.isCompleted == previous.isCompleted;
  if (p['recurrence'] != null && !unchangedRecurrence) {
    final raw = p['recurrence'];
    if (raw is! Map) throw const FormatException('Unreadable recurrence.');
    TaskRecurrence(Map<String, dynamic>.from(raw));
    if (parseCalendarDate(p['dueDate']) == null) {
      throw const FormatException('Set a due date before repeating a task.');
    }
  }
  if (p['occurrenceHistory'] != null &&
      p['occurrenceHistory'] is! List &&
      (previous == null ||
          jsonEncode(p['occurrenceHistory']) !=
              jsonEncode(previous.properties['occurrenceHistory']))) {
    throw const FormatException('Unsupported occurrence history.');
  }
  final byId = {for (final o in objects) o.id: o, object.id: object};
  for (final key in ['blockedBy', 'parentTaskId']) {
    List<String> edges(UniversalObject o) => key == 'blockedBy'
        ? taskDependencies(o)
        : o.properties[key] is String &&
              (o.properties[key] as String).isNotEmpty
        ? [o.properties[key] as String]
        : [];
    final raw = p[key];
    if (previous != null &&
        jsonEncode(raw) == jsonEncode(previous.properties[key])) {
      continue;
    }
    if (raw != null &&
        raw is! String &&
        !(key == 'blockedBy' && raw is List && raw.every((v) => v is String))) {
      throw FormatException('$key must reference task IDs.');
    }
    final ids = edges(object);
    if (ids.length > 100) {
      throw const FormatException('A task supports up to 100 dependencies.');
    }
    for (final id in ids) {
      if (previous != null && edges(previous).contains(id)) continue;
      final target = byId[id];
      if (target == null || target.isDeleted || target.typeId != 'orbit.task') {
        throw const FormatException(
          'Choose an existing task for this relation.',
        );
      }
      final visited = <String>{};
      final pending = [id];
      while (pending.isNotEmpty) {
        final node = pending.removeLast();
        if (node == object.id) {
          throw const FormatException(
            'This relation would create a task cycle.',
          );
        }
        if (!visited.add(node)) continue;
        final next = byId[node];
        if (next != null) pending.addAll(edges(next));
      }
    }
  }
}

Map<String, dynamic> completeTaskOccurrence(
  UniversalObject task,
  Map<String, dynamic> properties,
  DateTime now,
) {
  if (properties['completed'] != true ||
      task.isCompleted ||
      properties['recurrence'] == null) {
    return properties;
  }
  final raw = properties['recurrence'];
  if (raw is! Map) throw const FormatException('Unsupported recurrence.');
  final rule = TaskRecurrence(Map<String, dynamic>.from(raw));
  final due = properties['dueDate'];
  if (due is! String) {
    throw const FormatException('Set the occurrence due date first.');
  }
  final history = properties['occurrenceHistory'];
  if (history != null && history is! List) {
    throw const FormatException('Unsupported occurrence history.');
  }
  if (history is List && history.length >= 10000) {
    throw const FormatException(
      'Export the occurrence history before adding more than 10,000 entries.',
    );
  }
  return {
    ...properties,
    'completed': false,
    'status': 'todo',
    'dueDate': rule.next(due),
    'completedAt': null,
    'occurrenceHistory': [
      if (history is List) ...history,
      {'date': due, 'completedAt': now.toUtc().toIso8601String()},
    ],
  };
}
