part of 'workspace_controller.dart';

extension WorkspaceProductivity on WorkspaceController {
  List<UniversalObject> queryViewObjects(UniversalObject view) {
    final day = calendarDate(DateTime.now());
    if (!identical(_querySnapshot, objects) || day != _queryDay) {
      _querySnapshot = objects;
      _queryDay = day;
      _viewQueryCache.clear();
    }
    final current = find(view.id) ?? view;
    return _viewQueryCache.putIfAbsent(
      current.id,
      () => List.unmodifiable(
        resolveSmartView(current, objects, pathFor: repository.objectPath),
      ),
    );
  }

  String? queryViewIssue(UniversalObject view) {
    try {
      queryViewObjects(view);
      return null;
    } on Object catch (e) {
      return '$e';
    }
  }

  Future<bool> saveSmartQuery(
    UniversalObject expected,
    Map<String, dynamic> query,
  ) async {
    if (expected.typeId != 'orbit.view') return false;
    try {
      SmartViewQuery(query);
    } on Object catch (e) {
      error = '$e';
      notify();
      return false;
    }
    return _commitProductivity(expected, {'smartQuery': query});
  }

  Future<bool> _commitProductivity(
    UniversalObject expected,
    Map<String, dynamic> changes, {
    bool replaceProperties = false,
    String? title,
    String? body,
    List<UniversalObject> prerequisites = const [],
  }) async {
    if (_planningBusy ||
        repository.readOnly ||
        expected.isReadOnly ||
        expected.isDeleted) {
      return false;
    }
    _planningBusy = true;
    final operation = Completer<void>();
    _productivityOperation = operation;
    final vault = repository.workspaceId;
    try {
      // Dialogs and external adapters may retain mutable draft maps.
      final committed = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(changes)) as Map,
      );
      if (!identical(find(expected.id), expected)) {
        throw const FormatException(
          'This item changed. Reopen it before applying.',
        );
      }
      await flush(expected.id);
      if (prerequisites.any(
        (o) => !identical(find(o.id), o) || dirty.contains(o.id) || o.isDeleted,
      )) {
        throw const FormatException(
          'The working calendar changed. Reopen the schedule to review its dates.',
        );
      }
      final current = find(expected.id);
      if (!_alive ||
          !hasWorkspace ||
          repository.workspaceId != vault ||
          dirty.contains(expected.id) ||
          current == null ||
          current.isDeleted ||
          ((title != null || body != null) &&
              (current.title != expected.title ||
                  current.body != expected.body)) ||
          jsonEncode(current.properties) != jsonEncode(expected.properties)) {
        throw const FormatException(
          'Resolve changed or unsaved content before applying.',
        );
      }
      final saved = await repository.save(
        current.copyWith(
          title: title,
          body: body,
          properties: replaceProperties
              ? committed
              : {...current.properties, ...committed},
        ),
      );
      if (!_alive || !hasWorkspace || repository.workspaceId != vault) {
        return false;
      }
      mergeRepositoryObjects();
      _planningUndo = (before: current, after: saved);
      error = null;
      notify();
      return true;
    } on Object catch (e) {
      if (_alive && hasWorkspace && repository.workspaceId == vault) {
        error = '$e';
        notify();
      }
      return false;
    } finally {
      _planningBusy = false;
      operation.complete();
      if (identical(_productivityOperation, operation)) {
        _productivityOperation = null;
      }
    }
  }

  bool get canUndoPlanning => _planningUndo != null && !_planningBusy;
  Future<bool> undoPlanning() async {
    final command = _planningUndo;
    if (command == null) return false;
    final current = find(command.after.id);
    if (current == null ||
        current.revision != command.after.revision ||
        current.title != command.after.title ||
        current.body != command.after.body ||
        dirty.contains(current.id) ||
        jsonEncode(current.properties) !=
            jsonEncode(command.after.properties)) {
      error =
          'This item changed after the action. Use document history to review it.';
      notify();
      return false;
    }
    final ok = await _commitProductivity(
      current,
      command.before.properties,
      replaceProperties: true,
      title: command.before.title,
      body: command.before.body,
    );
    if (ok) {
      _planningUndo = null;
      notify();
    }
    return ok;
  }

  Future<bool> configureTask(
    UniversalObject task,
    Map<String, dynamic> changes,
  ) async {
    if (task.typeId != 'orbit.task') return false;
    try {
      final normalized = {...changes};
      if (changes.containsKey('status') && !changes.containsKey('completed')) {
        normalized['completed'] = changes['status'] == 'done';
      }
      if (normalized.containsKey('completed')) {
        normalized['status'] = normalized['completed'] == true
            ? 'done'
            : (normalized['status'] == 'done'
                  ? 'todo'
                  : normalized['status'] ?? 'todo');
        normalized['completedAt'] = normalized['completed'] == true
            ? DateTime.now().toUtc().toIso8601String()
            : null;
      }
      final properties = completeTaskOccurrence(task, {
        ...task.properties,
        ...normalized,
      }, DateTime.now());
      validateTaskWorkCalendar(task, properties);
      if ([
        'scheduledDate',
        'scheduledEndDate',
        'ganttMilestone',
      ].any(changes.containsKey)) {
        validateGanttSchedule(properties);
      }
      for (final field in ['dueDate', 'scheduledDate']) {
        if (changes.containsKey(field) &&
            properties[field] != null &&
            parseCalendarDate(properties[field]) == null) {
          throw FormatException('Use a valid YYYY-MM-DD $field.');
        }
      }
      validateTaskPlanning(
        task.copyWith(properties: properties),
        objects,
        previous: task,
      );
      final calendarId = properties['workCalendarId'];
      final calendar = calendarId is String ? find(calendarId) : null;
      return _commitProductivity(
        task,
        properties,
        prerequisites: [
          if (calendar != null &&
              [
                'scheduledDate',
                'scheduledEndDate',
                'workCalendarId',
                'workDurationDays',
              ].any(changes.containsKey))
            calendar,
        ],
      );
    } on Object catch (e) {
      error = '$e';
      notify();
      return false;
    }
  }

  Future<bool> completePlannedTask(UniversalObject task) async {
    return configureTask(task, {'completed': true});
  }

  Future<bool> rescheduleObject(
    UniversalObject expected,
    DateTime day, {
    String field = 'scheduledDate',
  }) async {
    final target = calendarDate(day);
    if (expected.typeId == 'orbit.task') {
      if (!{'dueDate', 'scheduledDate'}.contains(field)) return false;
      final task = GanttTask(expected);
      if (field == 'scheduledDate' && task.valid) {
        try {
          return configureTask(
            expected,
            workingMove(expected, day, planningObjects),
          );
        } on Object catch (e) {
          error = '$e';
          notify();
          return false;
        }
      }
      return configureTask(expected, {field: target});
    }
    if (expected.typeId != 'orbit.event') return false;
    try {
      final schedule = EventSchedule.fromProperties(expected.properties);
      if (schedule.allDay) {
        final from = DateTime.utc(
          schedule.start.year,
          schedule.start.month,
          schedule.start.day,
        );
        final until = DateTime.utc(
          schedule.end.year,
          schedule.end.month,
          schedule.end.day,
        );
        final start = DateTime.utc(day.year, day.month, day.day);
        return _commitProductivity(expected, {
          'startDate': target,
          'endDate': calendarDate(start.add(until.difference(from))),
        });
      }
      final local = schedule.start.toLocal();
      final minute = eventLocalInstant(day, local.hour, local.minute);
      final start = minute.add(
        Duration(
          seconds: local.second,
          microseconds: local.microsecond + local.millisecond * 1000,
        ),
      );
      return _commitProductivity(expected, {
        'startAt': start.toIso8601String(),
        'endAt': start
            .add(schedule.end.difference(schedule.start))
            .toIso8601String(),
      });
    } on Object catch (e) {
      error = '$e';
      notify();
      return false;
    }
  }

  List<Map<String, dynamic>> get savedContexts =>
      WorkspaceContext.items(session.spaces);
  bool get contextsSupported => WorkspaceContext.supported(session.spaces);
  String? get activeSpaceId => session.spaces['activeId'] is String
      ? session.spaces['activeId'] as String
      : null;
  Map<String, dynamic>? get activeSpace {
    for (final entry in savedContexts) {
      if (entry['id'] == activeSpaceId &&
          entry['version'] == 1 &&
          entry['kind'] == 'space') {
        return entry;
      }
    }
    return null;
  }

  bool inActiveSpace(UniversalObject object) {
    final space = activeSpace;
    final project = space?['project'], folder = space?['folder'];
    if (project is String &&
        project.isNotEmpty &&
        ![
          'project',
          'course',
          'context',
        ].any((k) => object.properties[k] == project)) {
      return false;
    }
    if (folder is String && folder.isNotEmpty) {
      final f = object.properties['folder'];
      if (f != folder &&
          !(f is String && f.startsWith('$folder/')) &&
          repository.objectPath(object.id)?.startsWith('$folder/') != true) {
        return false;
      }
    }
    return !object.isDeleted;
  }

  Future<bool> saveContext({
    required String name,
    String? id,
    bool layoutOnly = false,
    String? project,
    String? folder,
    bool appearance = false,
  }) async {
    if (!contextsSupported ||
        repository.readOnly ||
        name.trim().isEmpty ||
        name.length > 100 ||
        savedContexts.length >= 30 && id == null) {
      return false;
    }
    final old = savedContexts.where((r) => r['id'] == id).firstOrNull;
    if (id != null && old == null) return false;
    if (old != null && old['version'] != 1) return false;
    final record = <String, dynamic>{
      ...?old,
      'version': 1,
      'id': id ?? const Uuid().v4(),
      'name': name.trim(),
      'kind': layoutOnly ? 'layout' : 'space',
      'project': project,
      'folder': folder,
      'context': {
        ...?old?['context'] as Map?,
        ...WorkspaceContext.capture(session.toJson(), layoutOnly: layoutOnly),
      },
      'dashboard': jsonDecode(jsonEncode(session.dashboard)),
      'appearance': appearance
          ? {
              for (final k in WorkspaceContext.appearanceKeys)
                k: session.toJson()[k],
            }
          : null,
    };
    try {
      WorkspaceContext.validate(record);
    } on Object {
      return false;
    }
    updateSession(
      (s) => s.spaces = {
        ...s.spaces,
        'version': 1,
        'items': [
          for (final r in savedContexts)
            if (r['id'] != record['id']) r,
          record,
        ],
      },
    );
    await saveSession();
    return !_settingsSaveFailed;
  }

  Future<bool> duplicateContext(String id) async {
    final entry = savedContexts.where((r) => r['id'] == id).firstOrNull;
    if (entry == null ||
        entry['version'] != 1 ||
        !contextsSupported ||
        repository.readOnly ||
        savedContexts.length >= 30) {
      return false;
    }
    updateSession(
      (s) => s.spaces = {
        ...s.spaces,
        'version': 1,
        'items': [
          ...savedContexts,
          {
            ...entry,
            'id': const Uuid().v4(),
            'name':
                '${(entry['name'] as String).substring(0, (entry['name'] as String).length.clamp(0, 95))} copy',
          },
        ],
      },
    );
    await saveSession();
    return !_settingsSaveFailed;
  }

  Future<bool> renameContext(String id, String name) async {
    final entry = savedContexts.where((r) => r['id'] == id).firstOrNull;
    if (entry == null || entry['version'] != 1) return false;
    if (!contextsSupported ||
        repository.readOnly ||
        name.trim().isEmpty ||
        name.length > 100) {
      return false;
    }
    updateSession(
      (s) => s.spaces = {
        ...s.spaces,
        'items': [
          for (final r in savedContexts)
            if (r['id'] == id) {...r, 'name': name.trim()} else r,
        ],
      },
    );
    await saveSession();
    return !_settingsSaveFailed;
  }

  Future<bool> removeContext(String id) async {
    if (!contextsSupported || repository.readOnly) return false;
    if (activeSpaceId == id && !await switchContext(null)) return false;
    updateSession(
      (s) => s.spaces = {
        ...s.spaces,
        'items': [
          for (final r in savedContexts)
            if (r['id'] != id) r,
        ],
      },
    );
    await saveSession();
    return !_settingsSaveFailed;
  }

  Future<bool> switchContext(String? id) async {
    if (!contextsSupported || repository.readOnly || !await flushAll()) {
      return false;
    }
    if (id != null && id == activeSpaceId) return true;
    final library = session.spaces;
    final records = savedContexts;
    final target = records.where((r) => r['id'] == id).firstOrNull;
    if (id != null && target == null) return false;
    try {
      if (target != null) WorkspaceContext.validate(target);
    } on Object catch (e) {
      error = '$e';
      notify();
      return false;
    }
    final current = session.toJson();
    final base = activeSpaceId != null && library['base'] is Map
        ? Map<String, dynamic>.from(library['base'] as Map)
        : {
            ...WorkspaceContext.capture(current),
            'dashboard': session.dashboard,
            for (final k in WorkspaceContext.appearanceKeys) k: current[k],
          };
    final updated = [
      for (final r in records)
        if (r['id'] == activeSpaceId)
          {
            ...r,
            'context': {
              ...?r['context'] as Map?,
              ...WorkspaceContext.capture(current),
            },
            'dashboard': session.dashboard,
          }
        else
          r,
    ];
    final descriptor = target?['context'] as Map? ?? base;
    final allowed = target?['kind'] == 'layout'
        ? WorkspaceContext.layoutKeys
        : WorkspaceContext.contextKeys;
    final restored = {
      ...current,
      if (target?['kind'] != 'layout')
        for (final k in WorkspaceContext.appearanceKeys)
          if (base.containsKey(k)) k: base[k],
      for (final k in allowed)
        if (descriptor.containsKey(k)) k: descriptor[k],
      if (target?['appearance'] is Map)
        for (final k in WorkspaceContext.appearanceKeys)
          if ((target!['appearance'] as Map).containsKey(k))
            k: (target['appearance'] as Map)[k],
      'dashboard': target?['dashboard'] ?? base['dashboard'],
      'spaces': {
        ...library,
        'version': 1,
        'items': updated,
        'activeId': target?['kind'] == 'layout' ? activeSpaceId : id,
        'base': base,
      },
    };
    session = SessionState.fromJson(
      Map<String, dynamic>.from(jsonDecode(jsonEncode(restored)) as Map),
    );
    session.tabs = session.tabs
        .where((id) => find(id)?.isDeleted == false)
        .toList();
    if (find(session.activeId)?.isDeleted != false) {
      session.activeId = session.tabs.firstOrNull;
    }
    if (find(session.secondaryId)?.isDeleted != false) {
      session.secondaryId = null;
    }
    notify();
    await saveSession();
    return !_settingsSaveFailed;
  }

  Future<bool> saveDashboard(Map<String, dynamic> value) async {
    if (repository.readOnly ||
        session.dashboard.isNotEmpty && session.dashboard['version'] != 1) {
      return false;
    }
    try {
      DashboardDefinition.validate(value);
    } on Object catch (e) {
      error = '$e';
      notify();
      return false;
    }
    updateSession((s) => s.dashboard = value);
    await saveSession();
    return !_settingsSaveFailed;
  }
}
