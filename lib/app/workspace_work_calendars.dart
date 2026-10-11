part of 'workspace_controller.dart';

extension WorkspaceWorkCalendars on WorkspaceController {
  Map<String, UniversalObject> get planningObjects => {
    for (final o in objects) o.id: o,
  };
  List<UniversalObject> get workingCalendars => objects
      .where(
        (o) =>
            !o.isDeleted &&
            o.typeId == 'orbit.note' &&
            o.properties.containsKey('workingCalendar'),
      )
      .toList();

  Future<UniversalObject?> saveWorkingCalendar({
    UniversalObject? previous,
    required String title,
    required Map<String, dynamic> definition,
  }) async {
    try {
      if (title.trim().isEmpty || title.length > 200) {
        throw const FormatException('Give this calendar a short name.');
      }
      WorkingCalendar(definition);
      if (previous != null) {
        resolveWorkingCalendar(previous.id, planningObjects);
        final ok = await _commitProductivity(previous, {
          'workingCalendar': definition,
        }, title: title.trim());
        return ok ? find(previous.id) : null;
      }
      return create(
        'orbit.note',
        title: title.trim(),
        body:
            '# Working calendar\n\nWork weeks and date exceptions are stored in this note’s properties. Edit them from a Gantt timeline’s Calendars menu.',
        properties: {'workingCalendar': definition},
      );
    } on Object catch (e) {
      error = '$e';
      notify();
      return null;
    }
  }

  Future<bool> assignGanttCalendar(UniversalObject view, String? id) async {
    try {
      if (view.typeId != 'orbit.view' ||
          view.properties['ganttVersion'] != null &&
              view.properties['ganttVersion'] != 1) {
        return false;
      }
      resolveWorkingCalendar(id, planningObjects);
      return _commitProductivity(view, {'workCalendarId': id});
    } on Object catch (e) {
      error = '$e';
      notify();
      return false;
    }
  }

  void validateTaskWorkCalendar(
    UniversalObject before,
    Map<String, dynamic> after,
  ) {
    if (![
      'scheduledDate',
      'scheduledEndDate',
      'workCalendarId',
      'workDurationDays',
      'ganttMilestone',
    ].any((k) => after[k] != before.properties[k])) {
      return;
    }
    final id = after['workCalendarId'];
    // Explicit calendar-day scheduling detaches working-effort semantics.
    if (id == null) return;
    final cal = resolveWorkingCalendar(id, planningObjects)!;
    final task = GanttTask(before.copyWith(properties: after));
    if (after['workDurationDays'] != null) workingEffort(task, cal);
    if (task.valid &&
        !task.milestone &&
        cal.count(task.start!, task.finish!) == 0) {
      throw const FormatException(
        'This range contains no working days. Adjust dates or choose calendar days.',
      );
    }
  }

  Future<bool> saveWorkingSchedule(
    UniversalObject task,
    Map<String, dynamic> changes, {
    UniversalObject? expectedCalendar,
  }) async {
    try {
      if (task.typeId != 'orbit.task') {
        throw const FormatException('Only tasks have work schedules.');
      }
      final props = {...task.properties, ...changes};
      validateGanttSchedule(props);
      validateTaskWorkCalendar(task, props);
      final id = props['workCalendarId'];
      if (id != null &&
          (expectedCalendar == null ||
              expectedCalendar.id != id ||
              !identical(find(id as String), expectedCalendar))) {
        throw const FormatException(
          'The working calendar changed. Reopen the schedule.',
        );
      }
      return _commitProductivity(
        task,
        changes,
        prerequisites: [?expectedCalendar],
      );
    } on Object catch (e) {
      error = '$e';
      notify();
      return false;
    }
  }

  String workMoveSummary(UniversalObject task, DateTime day) {
    try {
      final changes = workingMove(task, day, planningObjects);
      return 'Work range → ${changes['scheduledDate']} – ${changes['scheduledEndDate'] ?? changes['scheduledDate']}';
    } on Object catch (e) {
      return '$e';
    }
  }
}
