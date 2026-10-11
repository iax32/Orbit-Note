import 'calendar_event.dart';
import 'task_planning.dart';
import 'universal_object.dart';

/// Calendar-day arithmetic deliberately avoids local daylight-saving offsets.
DateTime? ganttDate(Object? value) {
  final d = parseCalendarDate(value);
  return d == null ? null : DateTime.utc(d.year, d.month, d.day);
}

class GanttTask {
  GanttTask(this.object)
    : start = ganttDate(object.properties['scheduledDate']),
      end = ganttDate(object.properties['scheduledEndDate']),
      deadline = ganttDate(object.properties['dueDate']);
  final UniversalObject object;
  final DateTime? start, end, deadline;
  DateTime? get finish => end ?? start;
  bool get valid =>
      start != null &&
      !(end?.isBefore(start!) ?? false) &&
      !(object.properties['scheduledEndDate'] != null && end == null) &&
      !(milestone && end != null && end != start);
  bool get milestone => object.properties['ganttMilestone'] == true;
  int get duration => valid ? finish!.difference(start!).inDays + 1 : 0;

  List<String> warnings(Map<String, UniversalObject> all) {
    final result = <String>[];
    if (_hasDependencyCycle(all)) result.add('Dependency cycle needs review');
    if (object.properties['dueDate'] != null && deadline == null) {
      result.add('Invalid deadline');
    }
    if (milestone && end != null && start != null && end != start) {
      result.add('Milestone spans multiple days');
    }
    if (object.properties['scheduledDate'] != null && start == null) {
      result.add('Invalid scheduled start');
    }
    if (object.properties['scheduledEndDate'] != null && end == null) {
      result.add('Invalid scheduled finish');
    }
    if (end != null && start == null) result.add('Finish has no start');
    if (start != null && end?.isBefore(start!) == true) {
      result.add('Finish precedes start');
    }
    if (deadline != null && valid && finish!.isAfter(deadline!)) {
      result.add('Finishes after deadline');
    }
    for (final id in taskDependencies(object)) {
      final source = all[id];
      if (source == null || source.isDeleted || source.typeId != 'orbit.task') {
        result.add('Missing dependency: $id');
        continue;
      }
      if (source.isCompleted) continue;
      final blocker = GanttTask(source);
      if (!blocker.valid) {
        result.add('Unscheduled blocker: ${source.title}');
      } else if (valid && !start!.isAfter(blocker.finish!)) {
        result.add('Starts before blocker finishes: ${source.title}');
      }
    }
    return result;
  }

  /// Null means a missing/undated blocker makes an automatic suggestion unsafe.
  DateTime? afterBlockers(Map<String, UniversalObject> all) {
    if (_hasDependencyCycle(all)) return null;
    DateTime? earliest;
    for (final id in taskDependencies(object)) {
      final source = all[id];
      if (source == null || source.isDeleted || source.typeId != 'orbit.task') {
        return null;
      }
      if (source.isCompleted) continue;
      final blocker = GanttTask(source);
      if (!blocker.valid) return null;
      final next = blocker.finish!.add(const Duration(days: 1));
      if (earliest == null || next.isAfter(earliest)) earliest = next;
    }
    return earliest;
  }

  bool _hasDependencyCycle(Map<String, UniversalObject> all) {
    final pending = [...taskDependencies(object)];
    final visited = <String>{};
    while (pending.isNotEmpty) {
      final id = pending.removeLast();
      if (id == object.id) return true;
      if (!visited.add(id)) continue;
      final source = all[id];
      if (source != null &&
          !source.isDeleted &&
          source.typeId == 'orbit.task') {
        pending.addAll(taskDependencies(source));
      }
    }
    return false;
  }

  Map<String, dynamic> shiftedTo(DateTime day) {
    if (!valid) throw const FormatException('Schedule this task first.');
    final target = DateTime.utc(day.year, day.month, day.day);
    return {
      'scheduledDate': calendarDate(target),
      if (end != null)
        'scheduledEndDate': calendarDate(
          target.add(Duration(days: duration - 1)),
        ),
    };
  }
}

void validateGanttSchedule(Map<String, dynamic> properties) {
  for (final field in ['scheduledDate', 'scheduledEndDate']) {
    if (properties[field] != null && ganttDate(properties[field]) == null) {
      throw FormatException('Use a valid YYYY-MM-DD $field.');
    }
  }
  final start = ganttDate(properties['scheduledDate']);
  final end = ganttDate(properties['scheduledEndDate']);
  if (end != null && (start == null || end.isBefore(start))) {
    throw const FormatException(
      'Finish must be on or after the scheduled start.',
    );
  }
  if (properties['ganttMilestone'] == true && end != null && end != start) {
    throw const FormatException('A milestone must occupy a single day.');
  }
}
