part of 'workspace_controller.dart';

/// Personal continuation descriptors reuse the device-local Space library.
extension WorkspaceStudyResume on WorkspaceController {
  Map<String, dynamic>? studyResume(String course) => savedContexts
      .where(
        (r) =>
            r['studyCourse'] == course &&
            r['version'] == 1 &&
            r['studyVersion'] == 1 &&
            _validStudyResume(r),
      )
      .firstOrNull;

  bool _validStudyResume(Map<String, dynamic> r) {
    try {
      WorkspaceContext.validate(r);
      final context = r['context'] as Map;
      return context['tabs'] is List &&
          r['studyRevisions'] is Map &&
          (r['studyRevisions'] as Map).keys.every((k) => k is String) &&
          r['studyTitles'] is Map &&
          (r['studyContinuation'] == null ||
              r['studyContinuation'] is String) &&
          (r['studyDismissed'] == null || r['studyDismissed'] is List);
    } on Object {
      return false;
    }
  }

  List<UniversalObject> unfinishedStudyWork(String course) => activeObjects
      .where(
        (o) =>
            matchesStudyCourse(o, course) &&
            o.typeId == 'orbit.task' &&
            !o.isCompleted &&
            ![
              'done',
              'completed',
              'cancelled',
            ].contains(o.properties['status']),
      )
      .toList();

  List<UniversalObject> relatedStudyMaterial(String course) {
    final dismissed =
        studyResume(course)?['studyDismissed'] as List? ?? const [];
    return activeObjects
        .where(
          (o) =>
              matchesStudyCourse(o, course) &&
              o.properties['studyUnderstanding'] == 'uncertain' &&
              !dismissed.contains(o.id),
        )
        .toList();
  }

  Future<bool> saveStudyResume(String course, String continuation) async {
    if (!hasWorkspace ||
        repository.readOnly ||
        !contextsSupported ||
        course.trim().isEmpty ||
        course.length > 500 ||
        continuation.length > 4000 ||
        !await flushAll()) {
      return false;
    }
    final old = studyResume(course);
    if (savedContexts.any(
      (r) =>
          r['studyCourse'] == course &&
          (r['studyVersion'] != 1 || !_validStudyResume(r)),
    )) {
      return false;
    }
    if (old == null && savedContexts.length >= 30) return false;
    final ids = session.tabs
        .where(
          (id) =>
              find(id) != null &&
              matchesStudyCourse(find(id)!, course) &&
              find(id)?.isDeleted == false,
        )
        .toList();
    if (ids.isEmpty) {
      error =
          'Open a note, PDF, or Canvas assigned to this course before saving a continuation.';
      notify();
      return false;
    }
    final context = <String, dynamic>{
      ...?old?['context'] as Map?,
      ...WorkspaceContext.capture(session.toJson()),
    };
    context['tabs'] = ids;
    context['activeId'] = ids.contains(session.activeId)
        ? session.activeId
        : ids.first;
    context['secondaryId'] = ids.contains(session.secondaryId)
        ? session.secondaryId
        : null;
    for (final field in ['positions', 'noteViews', 'cameras']) {
      context[field] = {
        for (final e in (context[field] as Map).entries)
          if (e.key is String &&
              ids.any(
                (id) => e.key == id || (e.key as String).endsWith(':$id'),
              ))
            e.key: e.value,
      };
    }
    final record = <String, dynamic>{
      ...?old,
      'version': 1,
      'id': old?['id'] ?? const Uuid().v4(),
      'kind': 'space',
      'name':
          'Study: ${find(course)?.properties['isCourseOverview'] == true ? courseName(find(course)!) : course.substring(0, course.length.clamp(0, 90))}',
      'studyCourse': course,
      'studyVersion': 1,
      'context': context,
      'studyContinuation': continuation.trim(),
      'studySavedAt': DateTime.now().toUtc().toIso8601String(),
      'studyRevisions': {for (final id in ids) id: find(id)!.revision},
      'studyTitles': {for (final id in ids) id: find(id)!.title},
    };
    try {
      WorkspaceContext.validate(record);
    } on Object {
      error =
          'This continuation exceeds the supported view limits. Keep at most 30 course tabs open and try again.';
      notify();
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

  List<String> studyResumeWarnings(String course) {
    final record = studyResume(course);
    if (record == null) return [];
    final revisions = record['studyRevisions'] as Map? ?? const {};
    final titles = record['studyTitles'] as Map? ?? const {};
    return [
      for (final entry in revisions.entries)
        if (find(entry.key)?.isDeleted != false)
          '${titles[entry.key] ?? 'Source'} is missing; it will be skipped.'
        else if (find(entry.key)!.revision != entry.value)
          '${find(entry.key)!.title} changed; its saved position will be reset.',
    ];
  }

  Future<bool> resumeStudy(String course) async {
    final record = studyResume(course);
    if (record == null ||
        !hasWorkspace ||
        repository.readOnly ||
        !await flushAll()) {
      return false;
    }
    final descriptor = Map<String, dynamic>.from(record['context'] as Map);
    final ids = (descriptor['tabs'] as List)
        .whereType<String>()
        .where((id) => find(id)?.isDeleted == false)
        .toList();
    if (ids.isEmpty) {
      error =
          'The saved sources are missing. Open current course material to start again.';
      notify();
      return false;
    }
    final revisions = record['studyRevisions'] as Map? ?? const {};
    final changed = ids
        .where((id) => revisions[id] != find(id)!.revision)
        .toSet();
    final current = session.toJson();
    // Merge only course view state; keep other tabs, layout, and personal appearance.
    bool usable(String key) =>
        ids.any((id) => key == id || key.endsWith(':$id')) &&
        !changed.any((id) => key == id || key.endsWith(':$id'));
    for (final field in ['positions', 'noteViews', 'cameras']) {
      final merged = Map<String, dynamic>.from(current[field] as Map);
      merged.removeWhere(
        (key, value) => changed.any((id) => key == id || key.endsWith(':$id')),
      );
      final saved = descriptor[field] as Map? ?? const {};
      for (final e in saved.entries) {
        if (e.key is String && usable(e.key)) {
          merged[e.key as String] = e.value;
        }
      }
      current[field] = merged;
    }
    current['tabs'] = {...session.tabs, ...ids}.toList();
    current['activeId'] = ids.contains(descriptor['activeId'])
        ? descriptor['activeId']
        : ids.first;
    current['secondaryId'] = ids.contains(descriptor['secondaryId'])
        ? descriptor['secondaryId']
        : null;
    session = SessionState.fromJson(current);
    studyResumeSerial++;
    notify();
    await saveSession();
    return !_settingsSaveFailed;
  }

  Future<bool> dismissStudyMaterial(
    String course,
    String id, {
    bool reset = false,
  }) async {
    final record = studyResume(course);
    if (record == null || !contextsSupported || repository.readOnly) {
      return false;
    }
    final dismissed = {
      ...?(record['studyDismissed'] as List?)?.whereType<String>(),
    };
    if (reset) {
      dismissed.clear();
    } else {
      dismissed.add(id);
    }
    updateSession(
      (s) => s.spaces = {
        ...s.spaces,
        'items': [
          for (final r in savedContexts)
            if (r['id'] == record['id'])
              {...r, 'studyDismissed': dismissed.toList()}
            else
              r,
        ],
      },
    );
    await saveSession();
    return !_settingsSaveFailed;
  }
}
