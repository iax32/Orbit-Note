part of 'workspace_controller.dart';

extension WorkspaceLife on WorkspaceController {
  LifeIndex get lifeIndex => LifeIndex(objects);
  List<UniversalObject> get personalTemplates =>
      activeObjects.where((o) => lifeKind(o) == LifeKind.template).toList();

  Future<UniversalObject?> createLife(
    LifeKind kind,
    String title, {
    String body = '',
    Map<String, dynamic> fields = const {},
    String? actionKey,
  }) async {
    if (!hasWorkspace ||
        loading ||
        repository.readOnly ||
        title.trim().isEmpty) {
      return null;
    }
    final generation = workspaceGeneration;
    Future<UniversalObject?> operation() async {
      try {
        final data = <String, dynamic>{
          'state': 'active',
          ...fields,
          'version': 1,
          'kind': kind.name,
          'actionKey': ?actionKey,
        };
        _validateLifeLinks(kind, data);
        validateLifeData(data);
        for (final key in lifeLinkFields) {
          final id = data[key];
          if (id is String && id.isNotEmpty && find(id)?.isDeleted != false) {
            throw const FormatException(
              'A linked source is missing. Refresh the form.',
            );
          }
        }
        for (final key in lifeListLinks) {
          if (lifeIds(data, key).any((id) => find(id)?.isDeleted != false)) {
            throw const FormatException(
              'A linked source is missing. Refresh the form.',
            );
          }
        }
        if (actionKey != null) {
          final existing = activeObjects
              .where(
                (o) =>
                    lifeData(o)['actionKey'] == actionKey &&
                    lifeKind(o) == kind,
              )
              .firstOrNull;
          if (existing != null) return existing;
        }
        final result = await create(
          'orbit.note',
          open: false,
          title: title.trim(),
          body: body,
          properties: {
            'life': data,
            'tags': ['life', kind.name],
          },
        );
        return generation == workspaceGeneration ? result : null;
      } on Object catch (e) {
        if (generation == workspaceGeneration) {
          error = '$e';
          notify();
        }
        return null;
      }
    }

    if (actionKey == null) return operation();
    final key = '$generation|${kind.name}|$actionKey';
    final pending = _lifeOperations[key];
    if (pending != null) return pending;
    final future = operation();
    _lifeOperations[key] = future;
    try {
      return await future;
    } finally {
      if (identical(_lifeOperations[key], future)) _lifeOperations.remove(key);
    }
  }

  Future<bool> saveLife(
    UniversalObject expected,
    Map<String, dynamic> changes, {
    String? title,
    String? body,
  }) async {
    try {
      if (lifeKind(expected) == null ||
          changes.containsKey('version') && changes['version'] != 1 ||
          changes.containsKey('kind') &&
              changes['kind'] != lifeData(expected)['kind']) {
        throw const FormatException(
          'Unsupported Life record. Keep the original source.',
        );
      }
      final previous = lifeData(expected);
      if (changes.containsKey('actionKey') &&
          changes['actionKey'] != previous['actionKey']) {
        throw const FormatException(
          'A recorded action identity cannot be changed.',
        );
      }
      if ([
            LifeKind.habitLog,
            LifeKind.routineLog,
          ].contains(lifeKind(expected)) &&
          [
            'date',
            'parentId',
          ].any((k) => changes.containsKey(k) && changes[k] != previous[k])) {
        throw const FormatException(
          'Keep the dated record attached to its original day and source.',
        );
      }
      final data = {...lifeData(expected), ...changes};
      _validateLifeLinks(
        lifeKind(expected)!,
        data,
        id: expected.id,
        previous: expected,
      );
      validateLifeData(data);
      final beforeRefs = lifeReferences(expected).toSet();
      final candidate = expected.copyWith(
        properties: {...expected.properties, 'life': data},
      );
      for (final id in lifeReferences(candidate)) {
        if (id == expected.id ||
            !beforeRefs.contains(id) && find(id)?.isDeleted != false) {
          throw const FormatException('Choose an existing linked item.');
        }
      }
      return _commitProductivity(
        expected,
        {'life': data},
        title: title,
        body: body,
      );
    } on Object catch (e) {
      error = '$e';
      notify();
      return false;
    }
  }

  Future<UniversalObject?> recordLifeHabit(
    UniversalObject habit,
    DateTime day, {
    double value = 1,
    String outcome = 'done',
    String note = '',
  }) async {
    if (lifeKind(habit) != LifeKind.habit ||
        habit.isReadOnly ||
        !identical(find(habit.id), habit)) {
      return null;
    }
    final date = calendarDate(day), key = 'habit:${habit.id}:$date';
    final existing = activeObjects
        .where(
          (o) =>
              lifeData(o)['actionKey'] == key &&
              lifeKind(o) == LifeKind.habitLog,
        )
        .firstOrNull;
    final fields = {
      'parentId': habit.id,
      'date': date,
      'value': value,
      'outcome': outcome,
      'unit': lifeData(habit)['unit'] ?? 'times',
    };
    if (existing != null) {
      return await saveLife(existing, fields, body: note)
          ? find(existing.id)
          : null;
    }
    return createLife(
      LifeKind.habitLog,
      '${habit.title} · $date',
      fields: fields,
      body: note,
      actionKey: key,
    );
  }

  Future<UniversalObject?> routineRecord(
    UniversalObject routine,
    DateTime day, {
    List<int>? checked,
  }) async {
    if (lifeKind(routine) != LifeKind.routine ||
        !identical(find(routine.id), routine)) {
      return null;
    }
    final date = calendarDate(day), key = 'routine:${routine.id}:$date';
    final existing = activeObjects
        .where(
          (o) =>
              lifeKind(o) == LifeKind.routineLog &&
              lifeData(o)['actionKey'] == key,
        )
        .firstOrNull;
    final fields = {
      'parentId': routine.id,
      'date': date,
      'checked': checked ?? <int>[],
      'items': existing == null
          ? lifeIds(lifeData(routine), 'items')
          : lifeIds(lifeData(existing), 'items'),
    };
    if (existing != null) {
      return checked == null
          ? existing
          : await saveLife(existing, fields)
          ? find(existing.id)
          : null;
    }
    return createLife(
      LifeKind.routineLog,
      '${routine.title} · $date',
      fields: fields,
      actionKey: key,
    );
  }

  Future<UniversalObject?> startLifeWorkout(
    UniversalObject workout, {
    String? programId,
    DateTime? now,
  }) async {
    if (lifeKind(workout) != LifeKind.workout ||
        !identical(find(workout.id), workout)) {
      return null;
    }
    final current = activeObjects
        .where(
          (o) =>
              lifeKind(o) == LifeKind.session &&
              lifeData(o)['workoutId'] == workout.id &&
              lifeData(o)['state'] == 'active',
        )
        .firstOrNull;
    if (current != null) return current;
    final lock = '$workspaceGeneration|startWorkout|${workout.id}';
    final pending = _lifeOperations[lock];
    if (pending != null) return pending;
    final future = _startLifeWorkout(workout, programId: programId, now: now);
    _lifeOperations[lock] = future;
    try {
      return await future;
    } finally {
      if (identical(_lifeOperations[lock], future)) {
        _lifeOperations.remove(lock);
      }
    }
  }

  Future<UniversalObject?> _startLifeWorkout(
    UniversalObject workout, {
    String? programId,
    DateTime? now,
  }) async {
    final d = lifeData(workout), day = now ?? DateTime.now();
    final sets = <Map<String, dynamic>>[];
    for (final id in lifeIds(d, 'exerciseIds')) {
      final exercise = find(id);
      if (lifeKind(exercise) != LifeKind.exercise) continue;
      for (
        var i = 0;
        i < (d['setsPerExercise'] as num? ?? 3).clamp(1, 10);
        i++
      ) {
        sets.add({
          'id': const Uuid().v4(),
          'exerciseId': id,
          'completed': false,
          'reps': 0,
          'weight': 0,
          'distance': 0,
          'seconds': 0,
          'weightUnit': d['weightUnit'] ?? 'kg',
          'distanceUnit': d['distanceUnit'] ?? 'km',
        });
      }
    }
    if (sets.isEmpty) {
      error = 'Choose at least one available exercise before starting.';
      notify();
      return null;
    }
    return createLife(
      LifeKind.session,
      '${workout.title} · ${calendarDate(day)}',
      fields: {
        'workoutId': workout.id,
        'programId': ?programId,
        'date': calendarDate(day),
        'startedAt': day.toUtc().toIso8601String(),
        'sets': sets,
        'restSeconds': d['restSeconds'] ?? 90,
        'resources': lifeIds(d, 'resources'),
      },
      body: '## Session observations\n\n',
      actionKey: 'session:${workout.id}:${day.toUtc().toIso8601String()}',
    );
  }

  Future<bool> updateLifeSet(
    UniversalObject session,
    String id,
    Map<String, dynamic> changes, {
    bool duplicate = false,
    bool remove = false,
  }) async {
    if (lifeKind(session) != LifeKind.session ||
        lifeData(session)['state'] != 'active') {
      return false;
    }
    final sets = lifeData(session)['sets'] as List? ?? [];
    if (!sets.any((s) => s['id'] == id)) return false;
    final result = <dynamic>[];
    for (final raw in sets) {
      final set = Map<String, dynamic>.from(raw as Map);
      if (set['id'] != id) {
        result.add(set);
        continue;
      }
      if (remove) continue;
      result.add(duplicate ? set : {...set, ...changes, 'id': id});
      if (duplicate) {
        result.add({
          ...set,
          ...changes,
          'id': const Uuid().v4(),
          'completed': false,
        });
      }
    }
    return saveLife(session, {'sets': result});
  }

  Future<bool> restLifeSession(UniversalObject session, int seconds) async {
    if (lifeKind(session) != LifeKind.session ||
        lifeData(session)['state'] != 'active' ||
        seconds < 0 ||
        seconds > 3600) {
      return false;
    }
    return saveLife(session, {
      'restUntil': DateTime.now()
          .toUtc()
          .add(Duration(seconds: seconds))
          .toIso8601String(),
    });
  }

  Future<bool> finishLifeSession(UniversalObject session) async {
    if (lifeKind(session) != LifeKind.session ||
        lifeData(session)['state'] != 'active') {
      return false;
    }
    return saveLife(session, {
      'state': 'completed',
      'finishedAt': DateTime.now().toUtc().toIso8601String(),
      'restUntil': null,
    });
  }

  Future<bool> appendLifeSet(
    UniversalObject session,
    UniversalObject exercise,
  ) async {
    if (lifeKind(session) != LifeKind.session ||
        lifeData(session)['state'] != 'active' ||
        lifeKind(exercise) != LifeKind.exercise ||
        !identical(find(exercise.id), exercise)) {
      return false;
    }
    return saveLife(session, {
      'sets': [
        ...lifeData(session)['sets'] as List? ?? [],
        {
          'id': const Uuid().v4(),
          'exerciseId': exercise.id,
          'completed': false,
          'reps': 0,
          'weight': 0,
          'distance': 0,
          'seconds': 0,
          'weightUnit': 'kg',
          'distanceUnit': 'km',
        },
      ],
    });
  }

  Future<UniversalObject?> lifeAction(
    UniversalObject source,
    String title, {
    String? dueDate,
    bool milestone = false,
  }) async {
    if (!identical(find(source.id), source) ||
        source.isDeleted ||
        source.isReadOnly) {
      return null;
    }
    if (title.trim().isEmpty ||
        milestone && dueDate == null ||
        dueDate != null && parseCalendarDate(dueDate) == null) {
      return null;
    }
    return create(
      'orbit.task',
      open: false,
      title: title,
      properties: {
        'lifeGoalId': source.id,
        'resources': [source.id],
        'dueDate': ?dueDate,
        if (milestone) 'ganttMilestone': true,
        if (milestone && dueDate != null) 'scheduledDate': dueDate,
      },
    );
  }

  Future<UniversalObject?> scheduleLife(
    UniversalObject source,
    DateTime date, {
    int minutes = 60,
    String? actionKey,
  }) async {
    if (!identical(find(source.id), source) ||
        source.isDeleted ||
        source.isReadOnly ||
        minutes < 1 ||
        minutes > 1440) {
      return null;
    }
    final key = actionKey ?? 'life-event:${source.id}:${calendarDate(date)}';
    final lock = '$workspaceGeneration|calendar|$key';
    final pending = _lifeOperations[lock];
    if (pending != null) return pending;
    final future = _scheduleLife(source, date, minutes, key);
    _lifeOperations[lock] = future;
    try {
      return await future;
    } finally {
      if (identical(_lifeOperations[lock], future)) {
        _lifeOperations.remove(lock);
      }
    }
  }

  Future<UniversalObject?> _scheduleLife(
    UniversalObject source,
    DateTime date,
    int minutes,
    String key,
  ) async {
    final existing = activeObjects
        .where(
          (o) =>
              o.typeId == 'orbit.event' &&
              o.properties['lifeScheduleKey'] == key,
        )
        .firstOrNull;
    if (existing != null) return existing;
    final start = DateTime(date.year, date.month, date.day, 9);
    return create(
      'orbit.event',
      open: false,
      title: source.title,
      properties: {
        'allDay': false,
        'startAt': start.toUtc().toIso8601String(),
        'endAt': start
            .add(Duration(minutes: minutes))
            .toUtc()
            .toIso8601String(),
        'resources': [source.id],
        'lifeScheduleKey': key,
        'lifeSourceId': source.id,
      },
    );
  }

  Future<int> scheduleLifeProgram(
    UniversalObject program,
    DateTime start,
  ) async {
    if (lifeKind(program) != LifeKind.program ||
        !identical(find(program.id), program)) {
      return 0;
    }
    final generation = workspaceGeneration,
        data = lifeData(program),
        ids = lifeIds(lifeData(program), 'workoutIds');
    final weeks = (data['weekCount'] as num? ?? 4).toInt().clamp(1, 26),
        weekdays = lifeIdsAsWeekdays(data);
    if (ids.isEmpty || weekdays.isEmpty) return 0;
    var count = 0, slot = 0;
    for (var i = 0; i < weeks * 7; i++) {
      if (generation != workspaceGeneration) break;
      final date = lifeDay(start, i);
      if (!weekdays.contains(date.weekday)) continue;
      final source = find(ids[slot++ % ids.length]);
      if (source == null || source.isDeleted) continue;
      final event = await scheduleLife(
        source,
        date,
        minutes: (data['minutes'] as num? ?? 60).toInt(),
        actionKey: 'program:${program.id}:${calendarDate(start)}:$i',
      );
      if (event == null) break;
      count++;
    }
    return count;
  }

  Future<UniversalObject?> createLifeReview(String period, DateTime at) async {
    if (!['week', 'month', 'year'].contains(period)) return null;
    final start = period == 'year'
        ? DateTime(at.year)
        : period == 'month'
        ? DateTime(at.year, at.month)
        : lifeDay(at, 1 - at.weekday);
    final end = period == 'year'
        ? DateTime(at.year + 1)
        : period == 'month'
        ? DateTime(at.year, at.month + 1)
        : lifeDay(start, 7);
    final index = lifeIndex, entries = index.inPeriod(start, end);
    final tasks = activeObjects
        .where(
          (o) =>
              o.typeId == 'orbit.task' &&
              o.isCompleted &&
              DateTime.tryParse('${o.properties['completedAt']}') != null &&
              !DateTime.parse(
                '${o.properties['completedAt']}',
              ).toLocal().isBefore(start) &&
              DateTime.parse(
                '${o.properties['completedAt']}',
              ).toLocal().isBefore(end),
        )
        .toList();
    final upcoming = activeObjects
        .where(
          (o) =>
              o.typeId == 'orbit.task' &&
              !o.isCompleted &&
              parseCalendarDate(o.properties['dueDate']) != null &&
              !parseCalendarDate(o.properties['dueDate'])!.isBefore(end) &&
              parseCalendarDate(
                o.properties['dueDate'],
              )!.isBefore(lifeDay(end, 7)),
        )
        .toList();
    final body = StringBuffer(
      '# ${period[0].toUpperCase()}${period.substring(1)} review\n\nRecorded period: ${calendarDate(start)} to ${calendarDate(lifeDay(end, -1))}.\n\n',
    );
    for (final kind in [
      LifeKind.habitLog,
      LifeKind.session,
      LifeKind.practice,
      LifeKind.journal,
      LifeKind.checkin,
    ]) {
      final rows = entries
          .where(
            (o) =>
                lifeKind(o) == kind &&
                (kind != LifeKind.session ||
                    lifeData(o)['state'] == 'completed'),
          )
          .toList();
      body.writeln('## ${kind.label} · ${rows.length} records\n');
      for (final o in rows) {
        body.writeln('- [[${o.id}|${o.title.replaceAll(']', '')}]]');
      }
      body.writeln();
    }
    body.writeln(
      '## Completed tasks with recorded completion dates · ${tasks.length}\n',
    );
    for (final o in tasks) {
      body.writeln('- [[${o.id}|${o.title.replaceAll(']', '')}]]');
    }
    body.writeln('\n## Upcoming commitments\n');
    for (final o in upcoming) {
      body.writeln(
        '- [[${o.id}|${o.title.replaceAll(']', '')}]] · ${o.properties['dueDate']}',
      );
    }
    body.writeln(
      '\n## My conclusions\nWhat helped? What needs to change?\n\n## Next period\nOne outcome and a realistic first action.\n\nCounts reflect dated records only; missing tracking is unknown.',
    );
    return createLife(
      LifeKind.review,
      '$period review · ${calendarDate(start)}',
      body: body.toString(),
      fields: {
        'date': calendarDate(start),
        'period': period,
        'resources': [
          ...entries.map((o) => o.id),
          ...tasks.map((o) => o.id),
        ].take(200).toList(),
      },
      actionKey: 'review:$period:${calendarDate(start)}',
    );
  }

  Future<UniversalObject?> savePersonalTemplate(
    UniversalObject source,
    String title,
  ) async {
    if (lifeKind(source) == LifeKind.template) {
      error =
          'This record is already a template. Use it to create an independent copy.';
      notify();
      return null;
    }
    if (source.isDeleted ||
        source.isReadOnly ||
        !identical(find(source.id), source) ||
        !['orbit.note', 'orbit.canvas'].contains(source.typeId)) {
      return null;
    }
    final generation = workspaceGeneration;
    await flush(source.id);
    final current = find(source.id);
    if (generation != workspaceGeneration ||
        current == null ||
        current.isDeleted ||
        dirty.contains(source.id) ||
        current.body != source.body ||
        jsonEncode(current.data) != jsonEncode(source.data) ||
        jsonEncode(current.properties) != jsonEncode(source.properties)) {
      return null;
    }
    return createLife(
      LifeKind.template,
      title,
      body: source.body,
      fields: {
        'templateFormat': source.typeId == 'orbit.canvas' ? 'canvas' : 'note',
        if (source.typeId == 'orbit.canvas') 'templateData': source.data,
        'resources': [source.id],
        'templateProperties': {...source.properties}
          ..remove('lifeScheduleKey')
          ..remove('templateSourceId'),
      },
    );
  }

  Future<UniversalObject?> usePersonalTemplate(
    UniversalObject template,
    String title,
  ) async {
    if (lifeKind(template) != LifeKind.template ||
        !identical(find(template.id), template)) {
      return null;
    }
    final d = lifeData(template);
    if (!['note', 'canvas'].contains(d['templateFormat']) ||
        d['templateFormat'] == 'canvas' && d['templateData'] is! Map) {
      return null;
    }
    return create(
      d['templateFormat'] == 'canvas' ? 'orbit.canvas' : 'orbit.note',
      open: false,
      title: title,
      body: template.body,
      data: d['templateFormat'] == 'canvas'
          ? remapLifeCanvas(
              Map<String, dynamic>.from(d['templateData'] as Map),
              () => const Uuid().v4(),
            )
          : null,
      properties: {
        if (d['templateProperties'] is Map)
          ...Map<String, dynamic>.from(d['templateProperties'] as Map),
        if (d['templateProperties'] is Map &&
            d['templateProperties']['life'] is Map)
          'life': {
            ...Map<String, dynamic>.from(
              d['templateProperties']['life'] as Map,
            ),
          }..remove('actionKey'),
        'templateSourceId': template.id,
      },
    );
  }

  Future<UniversalObject?> createLifeBoard(
    String title,
    List<String> ids,
  ) async {
    if (ids.isEmpty ||
        ids.length > 200 ||
        ids.toSet().length != ids.length ||
        ids.any((id) => find(id)?.isDeleted != false)) {
      error = 'Choose between 1 and 200 available, distinct objects.';
      notify();
      return null;
    }
    return _createLifeBoard(title, ids);
  }

  Future<UniversalObject?> _createLifeBoard(
    String title,
    List<String> ids, {
    Map<String, dynamic> properties = const {},
  }) async {
    return create(
      'orbit.canvas',
      properties: properties,
      open: false,
      title: title,
      data: {
        'schemaVersion': 1,
        'elements': [
          for (var i = 0; i < ids.length; i++)
            {
              'id': const Uuid().v4(),
              'type': 'card',
              'objectId': ids[i],
              'x': (i % 3) * 340.0,
              'y': (i ~/ 3) * 240.0,
              'width': 300.0,
              'height': 200.0,
              'presentation': 'preview',
            },
        ],
      },
    );
  }

  void _validateLifeLinks(
    LifeKind kind,
    Map<String, dynamic> data, {
    String? id,
    UniversalObject? previous,
  }) {
    for (final pair in [
      ('exerciseIds', LifeKind.exercise),
      ('workoutIds', LifeKind.workout),
    ]) {
      for (final target in lifeIds(data, pair.$1)) {
        if (find(target)?.isDeleted != false &&
            previous != null &&
            lifeReferences(previous).contains(target)) {
          continue;
        }
        if (lifeKind(find(target)) != pair.$2) {
          throw FormatException(
            'Choose an available ${pair.$2.label.toLowerCase()}.',
          );
        }
      }
    }
    if (kind == LifeKind.skill &&
        data['parentId'] is String &&
        data['parentId'] != '') {
      var next = data['parentId'] as String?;
      final visited = <String>{?id};
      while (next != null && next.isNotEmpty) {
        if (!visited.add(next)) {
          throw const FormatException('A skill cannot be its own ancestor.');
        }
        final source = find(next);
        if (source?.isDeleted != false &&
            previous != null &&
            lifeData(previous)['parentId'] == next) {
          break;
        }
        if (lifeKind(source) != LifeKind.skill) {
          throw const FormatException('Choose an available parent skill.');
        }
        next = lifeData(source!)['parentId'] as String?;
      }
    }
    for (final set in data['sets'] as List? ?? []) {
      final target = set['exerciseId'];
      if (lifeKind(find('$target')) != LifeKind.exercise &&
          !(previous != null &&
              lifeReferences(previous).contains(target) &&
              find('$target')?.isDeleted != false)) {
        throw const FormatException(
          'Choose an available exercise for each set.',
        );
      }
    }
    if ([LifeKind.habitLog, LifeKind.routineLog].contains(kind)) {
      final parent = find('${data['parentId']}');
      if (lifeKind(parent) !=
          (kind == LifeKind.habitLog ? LifeKind.habit : LifeKind.routine)) {
        throw const FormatException(
          'The tracked habit or routine is unavailable.',
        );
      }
      if (parseCalendarDate(data['date']) == null) {
        throw const FormatException('A dated record needs a valid date.');
      }
    }
  }
}
