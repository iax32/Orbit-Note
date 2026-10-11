part of 'workspace_controller.dart';

extension GameplayWorkflows on WorkspaceController {
  Future<UniversalObject?> createGameplayTestPlan({
    required String mechanicId,
    required String title,
    required String checklist,
  }) async {
    final mechanic = find(mechanicId);
    if (mechanic?.isDeleted != false ||
        mechanic!.isReadOnly ||
        repository.readOnly ||
        mechanic.properties['category'] != 'Mechanic Spec' ||
        (mechanic.properties['gameplayVersion'] != null &&
            mechanic.properties['gameplayVersion'] != 1) ||
        title.trim().isEmpty ||
        title.length > 300 ||
        checklist.length > 20000 ||
        gameplayChecklist(checklist).$2 == 0 ||
        gameplayChecklist(checklist).$2 > 200) {
      error = 'Choose a mechanic, a title and 1–200 Markdown checklist items.';
      notify();
      return null;
    }
    return create(
      'orbit.note',
      title: title.trim(),
      body: checklist,
      properties: {
        'gameplayVersion': 1,
        'gameplayKind': 'testPlan',
        'category': 'Test Plan',
        'mechanicId': mechanicId,
        'folder': mechanic.properties['folder'] ?? 'Notes',
        if (mechanic.properties['project'] != null)
          'project': mechanic.properties['project'],
      },
    );
  }

  Future<UniversalObject?> startGameplayTestRun(
    UniversalObject plan,
    String build,
  ) async {
    final workspace = repository.workspaceId;
    final owner = plan.properties['mechanicId'];
    if (repository.readOnly ||
        plan.isDeleted ||
        plan.isReadOnly ||
        plan.properties['gameplayKind'] != 'testPlan' ||
        plan.properties['gameplayVersion'] != 1 ||
        build.trim().isEmpty ||
        build.length > 300 ||
        gameplayChecklist(plan.body).$2 == 0 ||
        gameplayChecklist(plan.body).$2 > 200 ||
        plan.body.length > 20000 ||
        owner is! String ||
        find(owner)?.isDeleted != false) {
      error =
          'Choose an available test plan and a build (up to 300 characters).';
      notify();
      return null;
    }
    await flush(plan.id);
    final current = find(plan.id);
    if (workspace != repository.workspaceId ||
        current?.isDeleted != false ||
        current!.body != plan.body ||
        jsonEncode(current.properties) != jsonEncode(plan.properties) ||
        dirty.contains(plan.id) ||
        failures.containsKey(plan.id) ||
        find(owner)?.isDeleted != false ||
        repository.readOnly) {
      error =
          'The plan changed or could not be saved. Refresh before starting.';
      notify();
      return null;
    }
    // Each run starts unchecked; the original plan and previous runs are retained.
    final body = plan.body.replaceAllMapped(
      RegExp(r'^(\s*[-+*] )\[[xX]\]', multiLine: true),
      (m) => '${m[1]}[ ]',
    );
    return create(
      'orbit.note',
      title: '${plan.title} · ${build.trim()}',
      body:
          '$body\n\n## Observations and evidence\n\nPlan: [[${plan.id}|${plan.title}]]\n',
      properties: {
        ...plan.properties,
        'gameplayKind': 'testRun',
        'category': 'Test Run',
        'testPlanId': plan.id,
        'sourcePlanRevision': current.revision,
        'build': build.trim(),
        'testOutcome': 'pending',
        'resourceIds': [
          plan.id,
          ...gameplayIds(plan.properties['resourceIds']),
        ],
        'sourceVersions': {plan.id: current.revision},
      },
    );
  }

  Future<bool> setGameplayTestOutcome(
    UniversalObject snapshot,
    String outcome,
  ) async {
    final workspace = repository.workspaceId;
    final current = find(snapshot.id);
    if (repository.readOnly ||
        current?.isDeleted != false ||
        current!.isReadOnly ||
        current.body != snapshot.body ||
        jsonEncode(current.properties) != jsonEncode(snapshot.properties) ||
        current.properties['gameplayKind'] != 'testRun' ||
        current.properties['gameplayVersion'] != 1 ||
        !['pending', 'passed', 'failed', 'blocked'].contains(outcome) ||
        outcome == 'passed' &&
            !gameplayRunPassed(
              current.copyWith(
                properties: {...current.properties, 'testOutcome': 'passed'},
              ),
            )) {
      error = 'Refresh this run; a pass requires every checklist item checked.';
      notify();
      return false;
    }
    updateProperty(current.id, 'testOutcome', outcome);
    await flush(current.id);
    return workspace == repository.workspaceId &&
        !dirty.contains(current.id) &&
        !failures.containsKey(current.id);
  }

  List<UniversalObject> gameplayRelated(String mechanicId) =>
      activeObjects
          .where(
            (o) =>
                o.properties['mechanicId'] == mechanicId ||
                gameplayIds(
                  find(mechanicId)?.properties['gameplayResourceIds'],
                ).contains(o.id),
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<UniversalObject?> createGameplayRecord({
    required String mechanicId,
    required String kind,
    required String title,
    String build = '',
    String expected = '',
    String observed = '',
    String taskId = '',
    String outcome = '',
    List<String> resources = const [],
    GameplayCodeReference? code,
  }) async {
    try {
      final workspace = repository.workspaceId;
      final mechanic = find(mechanicId);
      if (mechanic == null ||
          mechanic.isDeleted ||
          mechanic.isReadOnly ||
          mechanic.typeId != 'orbit.note' ||
          repository.readOnly ||
          title.trim().isEmpty ||
          title.length > 300 ||
          !['code', 'playtest', 'verification'].contains(kind)) {
        throw const FormatException(
          'Choose an editable mechanic and enter a title.',
        );
      }
      if (mechanic.properties['gameplayVersion'] != null &&
          mechanic.properties['gameplayVersion'] != 1) {
        throw const FormatException(
          'This mechanic uses an unsupported gameplay version.',
        );
      }
      if (resources.length > 40 ||
          resources.contains(mechanicId) ||
          expected.length > 20000 ||
          observed.length > 20000 ||
          build.length > 300) {
        throw const FormatException('Record exceeds the supported limits.');
      }
      final task = taskId.isEmpty ? null : find(taskId);
      if (kind == 'code') {
        if (code == null) throw const FormatException('Add a code reference.');
        code.validate();
      } else if (code != null) {
        throw const FormatException(
          'Code citations belong in a code reference record.',
        );
      } else if (build.trim().isEmpty ||
          expected.trim().isEmpty ||
          observed.trim().isEmpty) {
        throw const FormatException(
          'Enter the tested build, expected behaviour and observations.',
        );
      }
      if (kind == 'verification' &&
          (task == null ||
              task.isDeleted ||
              task.typeId != 'orbit.task' ||
              !gameplayRelated(mechanicId).any((o) => o.id == task.id) ||
              !['passed', 'failed', 'blocked'].contains(outcome))) {
        throw const FormatException(
          'Choose a task for this mechanic and a verification result.',
        );
      }
      if (kind != 'verification' && taskId.isNotEmpty) {
        throw const FormatException(
          'Task results belong in a verification record.',
        );
      }
      final linked = {mechanicId, ...resources, if (task != null) task.id};
      for (final id in linked) {
        if (find(id)?.isDeleted != false) {
          throw const FormatException('A linked source is missing.');
        }
        await flush(id);
        if (dirty.contains(id) || failures.containsKey(id)) {
          throw StateError('Save or recover the linked sources first.');
        }
      }
      // Revalidate after asynchronous source saves, including a workspace switch.
      if (!identical(find(mechanicId), mechanic) &&
          (find(mechanicId)?.body != mechanic.body ||
              jsonEncode(find(mechanicId)?.properties) !=
                  jsonEncode(mechanic.properties))) {
        throw StateError('The mechanic changed. Reopen the record form.');
      }
      if (repository.workspaceId != workspace ||
          linked.any((id) => find(id)?.isDeleted != false) ||
          repository.readOnly) {
        throw StateError('A linked source is no longer available.');
      }
      final properties = <String, dynamic>{
        'gameplayVersion': 1,
        'gameplayKind': kind,
        'mechanicId': mechanicId,
        'folder': mechanic.properties['folder'] ?? 'Notes',
        if (mechanic.properties['project'] != null)
          'project': mechanic.properties['project'],
        'category': kind == 'playtest'
            ? 'Playtest'
            : kind == 'code'
            ? 'Code Reference'
            : 'Verification',
        'resourceIds': resources.toSet().toList(),
        'sourceVersions': {for (final id in linked) id: find(id)!.revision},
        if (code != null) 'codeReference': code.toJson(),
        if (kind != 'code') ...{
          'build': build.trim(),
          'expected': expected,
          'observed': observed,
        },
        if (task != null) 'verificationTaskId': task.id,
        if (kind == 'verification') 'verificationOutcome': outcome,
      };
      return create(
        'orbit.note',
        title: title.trim(),
        properties: properties,
        body:
            '# ${title.trim()}\n\nMechanic: [[$mechanicId|${mechanic.title}]]\n\n'
            '${code?.markdown ?? 'Build tested: ${build.trim()}\n\n## Expected behaviour\n$expected\n\n## Observations\n$observed\n'}'
            '${task == null ? '' : '\nTask: [[${task.id}|${task.title}]]\n\nResult: $outcome\n'}'
            '\n## Linked evidence\n${resources.map((id) => '- [[$id|${find(id)!.title}]]').join('\n')}\n',
      );
    } on Object catch (e) {
      error = '$e';
      notify();
      return null;
    }
  }

  Future<bool> linkGameplayResource(
    UniversalObject mechanic,
    String id, {
    bool remove = false,
  }) async {
    final current = find(mechanic.id);
    if (repository.readOnly ||
        current == null ||
        current.isDeleted ||
        current.isReadOnly ||
        current.body != mechanic.body ||
        jsonEncode(current.properties) != jsonEncode(mechanic.properties) ||
        current.properties['gameplayVersion'] != null &&
            current.properties['gameplayVersion'] != 1 ||
        !remove && (find(id)?.isDeleted != false || id == mechanic.id)) {
      error = 'The mechanic or resource changed. Refresh before linking.';
      notify();
      return false;
    }
    final ids = gameplayIds(current.properties['gameplayResourceIds']).toSet();
    remove ? ids.remove(id) : ids.add(id);
    if (ids.length > 100) {
      error = 'Keep at most 100 linked resources.';
      notify();
      return false;
    }
    edit(
      current.id,
      properties: {
        ...current.properties,
        'gameplayVersion': 1,
        'gameplayResourceIds': ids.toList(),
      },
    );
    await flush(current.id);
    return !dirty.contains(current.id) && !failures.containsKey(current.id);
  }

  Map<String, dynamic>? gameplayResume(String mechanicId) => savedContexts
      .where(
        (r) => r['gameplayMechanic'] == mechanicId && _validGameplayResume(r),
      )
      .firstOrNull;

  bool _validGameplayResume(Map<String, dynamic> r) {
    try {
      WorkspaceContext.validate(r);
      return r['gameplayVersion'] == 1 &&
          r['gameplayRevisions'] is Map &&
          (r['context'] as Map)['tabs'] is List &&
          r['gameplayNextStep'] is String;
    } on Object {
      return false;
    }
  }

  Future<bool> saveGameplayResume(String mechanicId, String nextStep) async {
    final workspace = repository.workspaceId;
    if (!contextsSupported ||
        repository.readOnly ||
        find(mechanicId)?.isDeleted != false ||
        nextStep.length > 4000 ||
        !await flushAll()) {
      return false;
    }
    if (repository.workspaceId != workspace ||
        find(mechanicId)?.isDeleted != false) {
      return false;
    }
    if (savedContexts.any(
      (r) => r['gameplayMechanic'] == mechanicId && !_validGameplayResume(r),
    )) {
      return false;
    }
    final old = gameplayResume(mechanicId);
    if (old == null && savedContexts.length >= 30) return false;
    final relevant = {
      mechanicId,
      ...gameplayRelated(mechanicId).map((o) => o.id),
    };
    final ids = {mechanicId, ...session.tabs.where(relevant.contains)}.toList();
    final context = WorkspaceContext.capture(session.toJson());
    context['tabs'] = ids;
    context['activeId'] = ids.contains(session.activeId)
        ? session.activeId
        : mechanicId;
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
      'kind': 'space',
      'id': old?['id'] ?? const Uuid().v4(),
      'name': 'Gameplay: ${find(mechanicId)!.title}'.substring(
        0,
        ('Gameplay: ${find(mechanicId)!.title}').length.clamp(0, 100),
      ),
      'gameplayVersion': 1,
      'gameplayMechanic': mechanicId,
      'gameplayNextStep': nextStep,
      'gameplayRevisions': {for (final id in ids) id: find(id)!.revision},
      'context': context,
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

  Future<bool> resumeGameplay(String mechanicId) async {
    final workspace = repository.workspaceId;
    final record = gameplayResume(mechanicId);
    if (record == null ||
        record['version'] != 1 ||
        repository.readOnly ||
        !await flushAll()) {
      return false;
    }
    if (repository.workspaceId != workspace) return false;
    try {
      WorkspaceContext.validate(record);
    } on Object {
      return false;
    }
    final descriptor = record['context'] as Map;
    final ids = (descriptor['tabs'] as List)
        .whereType<String>()
        .where((id) => find(id)?.isDeleted == false)
        .toList();
    if (ids.isEmpty) {
      error = 'Saved gameplay sources are missing.';
      notify();
      return false;
    }
    final revisions = record['gameplayRevisions'] as Map? ?? const {};
    final changed = ids
        .where((id) => revisions[id] != find(id)!.revision)
        .toSet();
    final state = session.toJson();
    for (final field in ['positions', 'noteViews', 'cameras']) {
      final merged = Map<String, dynamic>.from(state[field] as Map);
      merged.removeWhere(
        (key, _) => changed.any((id) => key == id || key.endsWith(':$id')),
      );
      for (final e in (descriptor[field] as Map? ?? const {}).entries) {
        if (e.key is String &&
            ids.any(
              (id) => e.key == id || (e.key as String).endsWith(':$id'),
            ) &&
            !changed.any(
              (id) => e.key == id || (e.key as String).endsWith(':$id'),
            )) {
          merged[e.key] = e.value;
        }
      }
      state[field] = merged;
    }
    state['tabs'] = {...session.tabs, ...ids}.toList();
    state['activeId'] = ids.contains(descriptor['activeId'])
        ? descriptor['activeId']
        : ids.first;
    state['secondaryId'] = ids.contains(descriptor['secondaryId'])
        ? descriptor['secondaryId']
        : null;
    session = SessionState.fromJson(state);
    studyResumeSerial++;
    error = changed.isEmpty
        ? null
        : 'Changed sources reopened at fresh positions.';
    notify();
    await saveSession();
    return !_settingsSaveFailed;
  }
}
