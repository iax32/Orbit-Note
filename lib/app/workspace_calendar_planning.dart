part of 'workspace_controller.dart';

extension WorkspaceCalendarPlanning on WorkspaceController {
  Future<bool> changeEventOccurrence(
    UniversalObject source,
    String key, {
    Map<String, dynamic>? dates,
    bool cancel = false,
    bool restore = false,
  }) async {
    try {
      if (source.typeId != 'orbit.event' || source is EventOccurrence) {
        return false;
      }
      final raw = source.properties['eventOccurrenceOverrides'];
      if (raw != null) validateEventOverrides(raw);
      final items = <String, dynamic>{
        if (raw is Map) ...Map<String, dynamic>.from(raw['items'] as Map),
      };
      if (restore) {
        if (!items.containsKey(key)) {
          throw const FormatException('No occurrence change to restore.');
        }
        items.remove(key);
      } else {
        final occurrence = resolveEventOccurrence(source, key);
        if (!cancel) {
          if (dates == null ||
              dates.keys.any(
                (k) => ![
                  'allDay',
                  'startDate',
                  'endDate',
                  'startAt',
                  'endAt',
                ].contains(k),
              )) {
            throw const FormatException('Choose valid occurrence dates.');
          }
          final schedule = EventSchedule.fromProperties(dates);
          if (schedule.allDay != occurrence.properties['allDay']) {
            throw const FormatException('Keep the series date type.');
          }
        }
        items[key] = {
          if (items[key] is Map)
            ...Map<String, dynamic>.from(items[key] as Map),
          'status': cancel ? 'cancelled' : 'rescheduled',
          ...?dates,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        };
      }
      final overrides = <String, dynamic>{
        if (raw is Map) ...Map<String, dynamic>.from(raw),
        'version': 1,
        'items': items,
      };
      validateEventOverrides(overrides);
      return await _commitProductivity(source, {
        'eventOccurrenceOverrides': overrides,
      });
    } on Object catch (e) {
      error = '$e';
      notify();
      return false;
    }
  }

  Future<bool> configureEventRepeat(
    UniversalObject event,
    Map<String, dynamic> rule,
  ) async {
    try {
      if (event.typeId != 'orbit.event') return false;
      final old = event.properties['eventRecurrence'];
      if (old != null) {
        if (old is! Map) {
          throw const FormatException('Unsupported repeat data.');
        }
        EventRecurrence(Map<String, dynamic>.from(old));
      }
      final merged = <String, dynamic>{
        if (old is Map) ...Map<String, dynamic>.from(old),
        ...rule,
        if (old is Map) 'processed': old['processed'],
        if (old is Map) 'anchorDate': old['anchorDate'],
        if (old is Map && old.containsKey('finished'))
          'finished': old['finished'],
      };
      EventRecurrence(merged);
      return await _commitProductivity(event, {'eventRecurrence': merged});
    } on Object catch (e) {
      error = '$e';
      notify();
      return false;
    }
  }

  Future<bool> recordEventOccurrence(
    UniversalObject event,
    String outcome,
  ) async {
    try {
      final next = advanceEventOccurrence(event, outcome, DateTime.now());
      return await _commitProductivity(event, next, replaceProperties: true);
    } on Object catch (e) {
      error = '$e';
      notify();
      return false;
    }
  }

  Future<UniversalObject?> saveCalendarPlan({
    UniversalObject? original,
    required String title,
    required String body,
    required String kind,
    required String course,
    String? courseId,
    required Map<String, dynamic> dates,
    int estimateMinutes = 60,
    List<String> resources = const [],
    String priority = 'medium',
  }) async {
    final type = kind == 'assignment' ? 'orbit.task' : 'orbit.event';
    final old = original?.properties['calendarPlan'];
    try {
      if (!hasWorkspace ||
          repository.readOnly ||
          title.trim().isEmpty ||
          title.length > 2000 ||
          course.length > 500 ||
          body.length > 100000 ||
          original != null && original.typeId != type ||
          old != null && (old is! Map || old['version'] != 1)) {
        throw const FormatException(
          'Reopen a supported editable item and provide a title within the planning limits.',
        );
      }
      final plan = <String, dynamic>{
        if (old is Map) ...Map<String, dynamic>.from(old),
        'version': 1,
        'kind': kind,
        'estimateMinutes': estimateMinutes,
        'resources': resources.toSet().toList(),
      };
      final allowedDates = type == 'orbit.task'
          ? {'dueDate', 'scheduledDate'}
          : {'allDay', 'startDate', 'endDate', 'startAt', 'endAt'};
      if (dates.keys.any((key) => !allowedDates.contains(key))) {
        throw const FormatException('Unsupported schedule fields.');
      }
      validateCalendarPlan(plan, type);
      final oldResources = original == null
          ? <String>[]
          : calendarResources(original);
      for (final id in resources) {
        if (find(id)?.isDeleted != false && !oldResources.contains(id)) {
          throw const FormatException(
            'A linked resource is missing. Refresh the picker.',
          );
        }
      }
      final courseRecord = courseId == null ? null : find(courseId);
      if (courseId != null &&
          (courseRecord == null ||
              courseRecord.isDeleted ||
              courseRecord.properties['isCourseOverview'] != true ||
              courseRecord.isReadOnly ||
              courseRecord.properties['course'] != course.trim())) {
        throw const FormatException(
          'Course changed. Reopen planning from its course hub.',
        );
      }
      final props = <String, dynamic>{
        ...?original?.properties,
        ...dates,
        'course': course.trim(),
        if (courseRecord != null) ...{
          'courseId': courseRecord.id,
          'folder': courseRecord.properties['folder'],
          if (original == null) 'project': '',
          if (original == null) 'context': '',
        },
        if (courseRecord == null &&
            original != null &&
            course.trim() != original.properties['course'])
          'courseId': '',
        'calendarPlan': plan,
        if (kind == 'assignment') 'priority': priority,
        if (original == null && kind == 'assignment') 'completed': false,
      };
      if (type == 'orbit.event') {
        EventSchedule.fromProperties(props);
      } else {
        if (original == null ||
            props['scheduledDate'] != original.properties['scheduledDate']) {
          validateGanttSchedule(props);
        }
        if (parseCalendarDate(props['dueDate']) == null ||
            props['scheduledDate'] != null &&
                parseCalendarDate(props['scheduledDate']) == null ||
            !['low', 'medium', 'high'].contains(priority)) {
          throw const FormatException(
            'Choose a valid deadline, optional scheduled date and priority.',
          );
        }
      }
      if (original != null) {
        if (type == 'orbit.task') validateTaskWorkCalendar(original, props);
        final ok = await _commitProductivity(
          original,
          props,
          replaceProperties: true,
          title: title.trim(),
          body: body,
        );
        return ok ? find(original.id) : null;
      }
      if (_planningBusy) return null;
      _planningBusy = true;
      final operation = Completer<void>();
      _productivityOperation = operation;
      try {
        return await create(
          type,
          title: title.trim(),
          body: body,
          properties: props,
        );
      } finally {
        _planningBusy = false;
        operation.complete();
        if (identical(_productivityOperation, operation)) {
          _productivityOperation = null;
        }
      }
    } on Object catch (e) {
      error = '$e';
      notify();
      return null;
    }
  }

  Future<bool> rememberCalendarPlanning(Map<String, dynamic> view) async {
    final old = session.noteViews['calendarPlanning'];
    if (!hasWorkspace ||
        repository.readOnly ||
        old != null && old['version'] != 1 ||
        view['version'] != 1 ||
        !['Agenda', 'Week', 'Day', 'Unscheduled'].contains(view['mode']) ||
        parseCalendarDate(view['date']) == null ||
        ![
          'all',
          'tasks',
          'events',
          ...calendarPlanKinds,
        ].contains(view['kind']) ||
        view['search'] is! String ||
        (view['search'] as String).length > 1000 ||
        view['completed'] is! bool ||
        view['course'] != null && view['course'] is! String) {
      return false;
    }
    updateSession(
      (s) => s.noteViews = {
        ...s.noteViews,
        'calendarPlanning': {...?old, ...view},
      },
    );
    await saveSession();
    return !_settingsSaveFailed;
  }
}
