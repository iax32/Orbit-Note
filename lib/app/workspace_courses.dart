part of 'workspace_controller.dart';

extension WorkspaceCourses on WorkspaceController {
  bool matchesStudyCourse(UniversalObject object, String key) {
    final record = find(key);
    return record?.properties['isCourseOverview'] == true
        ? !record!.isDeleted && belongsToCourse(object, record)
        : object.properties['course'] == key;
  }

  List<UniversalObject> get courses =>
      activeObjects
          .where(
            (o) =>
                o.typeId == 'orbit.note' &&
                o.properties['isCourseOverview'] == true,
          )
          .toList()
        ..sort((a, b) => courseName(a).compareTo(courseName(b)));

  String courseName(UniversalObject course) =>
      '${course.properties['courseDisplayName'] ?? course.properties['course'] ?? course.title}';

  Future<bool> saveCourseDetails(
    UniversalObject expected,
    Map<String, dynamic> changes,
  ) async {
    const keys = {
      'courseDisplayName',
      'semester',
      'ects',
      'courseCode',
      'lecturer',
      'courseStatus',
    };
    final current = find(expected.id);
    if (current == null ||
        current.isDeleted ||
        current.isReadOnly ||
        repository.readOnly ||
        !courses.any((c) => c.id == current.id)) {
      return false;
    }
    if (changes.keys.any((k) => !keys.contains(k)) ||
        changes.entries.any(
          (e) =>
              e.key != 'ects' &&
              (e.value is! String ||
                  (e.value as String).length >
                      (e.key == 'courseDisplayName' ? 120 : 500)),
        ) ||
        changes['courseDisplayName'] is! String ||
        (changes['courseDisplayName'] as String).trim().isEmpty ||
        changes['ects'] is! num ||
        !(changes['ects'] as num).isFinite ||
        (changes['ects'] as num) < 0 ||
        (changes['ects'] as num) > 120 ||
        !{'active', 'passed', 'archived'}.contains(changes['courseStatus'])) {
      error =
          'Enter a course name, ECTS between 0 and 120, and a supported status.';
      notify();
      return false;
    }
    if (changes.keys.any(
      (k) =>
          current.properties[k] != expected.properties[k] &&
          current.properties[k] != changes[k],
    )) {
      error =
          'Course details changed in another editor. Reopen the form to review them.';
      notify();
      return false;
    }
    final generation = workspaceGeneration;
    edit(current.id, properties: {...current.properties, ...changes});
    await flush(current.id);
    return generation == workspaceGeneration &&
        !dirty.contains(current.id) &&
        !failures.containsKey(current.id);
  }

  Future<UniversalObject?> addCourseMaterial(
    String courseId,
    String kind,
    String title, {
    String? dueDate,
  }) async {
    final course = find(courseId);
    if (course == null ||
        course.isDeleted ||
        course.isReadOnly ||
        course.properties['isCourseOverview'] != true ||
        !{'note', 'exercise', 'assignment'}.contains(kind) ||
        title.trim().isEmpty ||
        dueDate != null && parseCalendarDate(dueDate) == null) {
      return null;
    }
    final folder = '${course.properties['folder'] ?? 'University'}';
    return create(
      kind == 'exercise'
          ? 'orbit.canvas'
          : kind == 'assignment'
          ? 'orbit.task'
          : 'orbit.note',
      title: title.trim(),
      open: false,
      properties: {
        'courseId': course.id,
        'course': course.properties['course'],
        'project': '',
        'context': '',
        'folder': kind == 'note'
            ? '$folder/Lectures'
            : kind == 'exercise'
            ? '$folder/Exercises'
            : folder,
        if (kind == 'exercise') ...{
          'exerciseStatus': 'not_started',
          'backgroundStyle': 'grid',
        },
        if (kind == 'assignment' && dueDate != null) 'dueDate': dueDate,
      },
    );
  }

  Future<bool> linkCourseMaterial(
    String courseId,
    UniversalObject expected, {
    bool remove = false,
  }) async {
    final course = find(courseId), current = find(expected.id);
    if (course == null ||
        course.isDeleted ||
        course.isReadOnly ||
        course.properties['isCourseOverview'] != true ||
        current == null ||
        current.isDeleted ||
        current.isReadOnly ||
        current.properties['isCourseOverview'] == true ||
        current.properties['courseId'] != expected.properties['courseId'] ||
        current.properties['course'] != expected.properties['course']) {
      return false;
    }
    if (remove && !belongsToCourse(current, course)) return false;
    final generation = workspaceGeneration;
    edit(
      current.id,
      properties: {
        ...current.properties,
        'courseId': remove ? '' : course.id,
        'course': remove ? '' : course.properties['course'],
      },
    );
    await flush(current.id);
    return generation == workspaceGeneration &&
        !dirty.contains(current.id) &&
        !failures.containsKey(current.id);
  }

  Future<UniversalObject?> createCoursePlanningBoard(String courseId) async {
    final course = find(courseId);
    if (course == null ||
        course.isDeleted ||
        course.isReadOnly ||
        course.properties['isCourseOverview'] != true) {
      return null;
    }
    final existing = find(course.properties['courseBoardId'] as String?);
    if (existing != null && !existing.isDeleted) return existing;
    if (!_courseBoardsCreating.add(courseId)) return null;
    try {
      final members = CourseProgress(course, objects).members;
      final cards = members
          .where((o) => o.typeId != 'orbit.view')
          .take(18)
          .toList();
      int columnFor(UniversalObject member) =>
          member.typeId == 'orbit.task' || member.typeId == 'orbit.canvas'
          ? 1
          : member.properties['studyUnderstanding'] == 'uncertain'
          ? 2
          : 0;
      final columnCards = [
        for (var i = 0; i < 3; i++)
          cards.where((o) => columnFor(o) == i).toList(),
      ];
      final generation = workspaceGeneration;
      final views = <UniversalObject>[];
      for (final (label, rules) in <(String, List<Map<String, dynamic>>)>[
        ('Course material', []),
        (
          'Open assignments',
          [
            {'field': 'typeId', 'op': 'equals', 'value': 'orbit.task'},
            {'field': 'completed', 'op': 'equals', 'value': false},
          ],
        ),
      ]) {
        final view = await create(
          'orbit.view',
          open: false,
          title: '${courseName(course)} — $label',
          properties: {
            'courseId': course.id,
            'course': course.properties['course'],
            'folder': course.properties['folder'],
            'project': '',
            'context': '',
            'viewType': 'table',
            'smartQuery': {...SmartViewQuery.empty(), 'rules': rules},
          },
        );
        if (view == null || generation != workspaceGeneration) return null;
        views.add(view);
      }
      final board = await create(
        'orbit.canvas',
        open: false,
        title: '${courseName(course)} — Study board',
        properties: {
          'courseId': course.id,
          'course': course.properties['course'],
          'folder': course.properties['folder'],
          'project': '',
          'context': '',
        },
        data: {
          'schemaVersion': 1,
          'elements': [
            for (var i = 0; i < 3; i++)
              {
                'id': 'course-column-$i',
                'type': 'column',
                'text': [
                  'Lectures & references',
                  'Practice & assignments',
                  'Review before exam',
                ][i],
                'x': i * 340.0,
                'y': 250.0,
                'width': 320.0,
                'height': (columnCards[i].length * 150.0 + 100).clamp(
                  620,
                  3000,
                ),
                'color': [0xff8b7cf6, 0xff6f7fea, 0xff65c6a3][i],
              },
            {
              'id': const Uuid().v4(),
              'type': 'card',
              'objectId': course.id,
              'x': 0.0,
              'y': 0.0,
              'width': 320.0,
              'height': 200.0,
            },
            for (final (i, view) in views.indexed)
              {
                'id': const Uuid().v4(),
                'type': 'card',
                'objectId': view.id,
                'viewConfig': {'view': view.id, 'limit': 5},
                'presentation': 'preview',
                'x': (i + 1) * 340.0,
                'y': 0.0,
                'width': 320.0,
                'height': 200.0,
              },
            for (var column = 0; column < 3; column++)
              for (final (row, member) in columnCards[column].indexed)
                {
                  'id': const Uuid().v4(),
                  'type': 'card',
                  'objectId': member.id,
                  'columnId': 'course-column-$column',
                  'x': column * 340.0 + 16,
                  'y': 310.0 + row * 150.0,
                  'width': 288.0,
                  'height': 130.0,
                },
          ],
        },
      );
      if (board == null || generation != workspaceGeneration) return null;
      final latest = find(course.id);
      if (latest == null || latest.isDeleted) return board;
      edit(
        course.id,
        properties: {...latest.properties, 'courseBoardId': board.id},
      );
      await flush(course.id);
      return board;
    } finally {
      _courseBoardsCreating.remove(courseId);
    }
  }
}
