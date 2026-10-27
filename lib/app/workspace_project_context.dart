part of 'workspace_controller.dart';

extension ConnectedProjects on WorkspaceController {
  void openProjectReference(
    ObjectReference reference, {
    String? sourceVersion,
  }) {
    final object = find(reference.id);
    if (object == null || object.isDeleted) {
      error = 'The connected source is unavailable.';
      notify();
      return;
    }
    final changed =
        sourceVersion != null && sourceVersion != researchVersion(object);
    final target = changed ? ObjectReference(reference.id) : reference;
    requestLocation(target);
    if (object.properties['mimeType'] == 'application/pdf') {
      final key = 'pdf:secondary:${object.id}';
      final annotation = target.anchorType == 'annotation'
          ? find(target.anchorId)
          : null;
      final validAnnotation =
          annotation != null && PdfAnnotation(annotation).fileId == object.id;
      session.noteViews = {
        ...session.noteViews,
        key: {
          ...?session.noteViews[key],
          'page':
              target.page ??
              (validAnnotation ? PdfAnnotation(annotation).page : 1),
          'annotationId': validAnnotation ? annotation.id : null,
          'request': locationRequests[target.id]!.serial,
        },
      };
    }
    if (changed) {
      error =
          'The connected source changed. Its current content is open; the old precise position was not reused.';
    }
    openObject(target.id, secondary: true);
  }

  Future<bool> _saveProjectProperties(
    UniversalObject source,
    Map<String, dynamic> properties,
    List<String> keys,
  ) async {
    final workspace = repository.workspaceId;
    final generation = workspaceGeneration;
    if (source.workspaceId != workspace ||
        source.isReadOnly ||
        source.isDeleted ||
        repository.readOnly) {
      return false;
    }
    final before = {
      for (final key in keys)
        if (source.properties.containsKey(key)) key: source.properties[key],
    };
    final after = {
      for (final key in keys)
        if (properties.containsKey(key)) key: properties[key],
    };
    if (!editObjectMetadata(
      source,
      generation: generation,
      changes: after,
      remove: keys.where((key) => !after.containsKey(key)).toSet(),
    )) {
      return false;
    }
    await flush(source.id);
    final updated = find(source.id);
    if (!_alive ||
        workspaceGeneration != generation ||
        repository.workspaceId != workspace ||
        updated == null ||
        updated.isDeleted ||
        dirty.contains(source.id) ||
        failures.containsKey(source.id) ||
        keys.any(
          (key) =>
              updated.properties.containsKey(key) != after.containsKey(key) ||
              !jsonValuesEqual(updated.properties[key], after[key]),
        )) {
      return false;
    }
    _projectMutationUndo[source.id] = (
      workspace: workspace,
      before: before,
      after: after,
    );
    return true;
  }

  bool canUndoProjectMutation(String id) =>
      _projectMutationUndo[id]?.workspace == repository.workspaceId;
  Future<bool> undoProjectMutation(String id) async {
    final undo = _projectMutationUndo[id], source = find(id);
    if (undo == null ||
        source?.isDeleted != false ||
        source!.isReadOnly ||
        repository.readOnly ||
        undo.workspace != repository.workspaceId) {
      return false;
    }
    final keys = {...undo.before.keys, ...undo.after.keys};
    if (keys.any(
      (key) =>
          source.properties.containsKey(key) != undo.after.containsKey(key) ||
          jsonEncode(source.properties[key]) != jsonEncode(undo.after[key]),
    )) {
      return false;
    }
    final properties = Map<String, dynamic>.from(source.properties);
    for (final key in keys) {
      properties.remove(key);
    }
    properties.addAll(undo.before);
    final ok = await _saveProjectProperties(source, properties, keys.toList());
    if (ok) _projectMutationUndo.remove(id);
    return ok;
  }

  Future<bool> clearProjectSavedContext() async {
    final id = selectedProjectId;
    if (id == null || !projectContextAvailable) return false;
    final records = session.projectContext['projects'];
    final next = records is Map
        ? Map<String, dynamic>.from(records)
        : <String, dynamic>{};
    next.remove(id);
    session.projectContext = {...session.projectContext, 'projects': next};
    await saveSession();
    notify();
    return !_settingsSaveFailed;
  }

  Future<bool> assignObjectProject(
    String objectId,
    String projectId, {
    UniversalObject? expected,
    int? expectedGeneration,
  }) async {
    if (expectedGeneration != null &&
            expectedGeneration != workspaceGeneration ||
        expected != null && expected.id != objectId) {
      return false;
    }
    final object = find(objectId);
    if (!projectChoices.containsKey(projectId) ||
        object?.isDeleted != false ||
        object!.isReadOnly ||
        repository.readOnly) {
      return false;
    }
    return _saveProjectProperties(
      expected ?? object,
      {
        ...object.properties,
        'project': projectId,
        'projectName': projectChoices[projectId],
      },
      ['project', 'projectName'],
    );
  }

  Future<bool> reviewProjectConnection(
    String sourceId,
    String connectionId,
  ) async {
    final source = find(sourceId);
    if (source?.isDeleted != false ||
        source!.isReadOnly ||
        repository.readOnly ||
        !ProjectConnection.supported(source.properties['orbitConnections'])) {
      return false;
    }
    final raw = source.properties['orbitConnections'];
    final link = ProjectConnection.read(
      raw,
    ).where((r) => r.id == connectionId).firstOrNull;
    final target = link == null ? null : find(link.target.id);
    if (raw is! Map || target?.isDeleted != false) return false;
    return _saveProjectProperties(
      source,
      {
        ...source.properties,
        'orbitConnections': {
          ...raw,
          'items': [
            for (final r in raw['items'] as List)
              if (r is Map && r['id'] == connectionId)
                {
                  ...r,
                  'versionToken': researchVersion(target!),
                  'reviewedAt': DateTime.now().toUtc().toIso8601String(),
                }
              else
                r,
          ],
        },
      },
      ['orbitConnections'],
    );
  }

  String? get selectedProjectId =>
      projectContextAvailable && session.projectContext['selected'] is String
      ? session.projectContext['selected'] as String
      : null;
  bool get projectPanelPinned =>
      projectContextAvailable && session.projectContext['panel'] == true;
  bool get projectContextAvailable =>
      projectContextSupported(session.projectContext);
  Map<String, String> get projectChoices {
    if (identical(_projectChoicesSource, objects)) return _projectChoicesCache;
    final byId = {
      for (final o in objects)
        if (!o.isDeleted) o.id: o,
    };
    final result = <String, String>{};
    for (final o in byId.values) {
      final id = objectProject(o);
      if (id == null || result.containsKey(id)) continue;
      final root = byId[id];
      final name =
          root?.properties['projectName'] ?? o.properties['projectName'];
      result[id] = name is String ? name : root?.title ?? id;
    }
    _projectChoicesSource = objects;
    _projectChoicesCache = Map.unmodifiable(result);
    return _projectChoicesCache;
  }

  List<UniversalObject> projectObjects(String id) =>
      activeObjects.where((o) => o.id == id || objectProject(o) == id).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  Map<String, dynamic> projectRecord(String id) {
    final records = session.projectContext['projects'];
    final value = records is Map ? records[id] : null;
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  bool _setProjectRecord(String id, Map<String, dynamic> record) {
    if (!projectContextAvailable) return false;
    final records = session.projectContext['projects'];
    final next = <String, dynamic>{
      ...?(records is Map ? Map<String, dynamic>.from(records) : null),
    };
    if (!next.containsKey(id) && next.length >= 30) {
      error =
          'Up to 30 project contexts can be saved. Clear an older context first.';
      return false;
    }
    next[id] = record;
    session.projectContext = {
      ...session.projectContext,
      'version': 1,
      'projects': next,
    };
    persistSession();
    return true;
  }

  Future<bool> selectProject(String? id) async {
    final workspace = repository.workspaceId;
    if (!projectContextAvailable ||
        !await flushAll() ||
        repository.workspaceId != workspace) {
      return false;
    }
    if (id != null && !projectChoices.containsKey(id)) return false;
    session.projectContext = {
      ...session.projectContext,
      'version': 1,
      'selected': id,
    };
    await saveSession();
    notify();
    return !_settingsSaveFailed;
  }

  void pinProjectPanel(bool pin) => updateSession((s) {
    if (!projectContextAvailable) return;
    s.projectContext = {...s.projectContext, 'version': 1, 'panel': pin};
    if (pin) s.inspectorVisible = true;
  });
  Map<String, dynamic> projectCreationProperties(
    Map<String, dynamic> explicit,
  ) {
    final id = selectedProjectId;
    // Explicit ownership always wins, including an intentionally empty project.
    if (!projectContextAvailable ||
        id == null ||
        !projectChoices.containsKey(id) ||
        [
          'project',
          'courseId',
          'course',
          'context',
        ].any(explicit.containsKey)) {
      return explicit;
    }
    final course = find(id);
    if (course?.properties['isCourseOverview'] == true &&
        course?.properties['courseId'] == id) {
      return {
        'courseId': id,
        'course': course!.properties['course'] ?? course.title,
        ...explicit,
      };
    }
    return {'project': id, 'projectName': projectChoices[id], ...explicit};
  }

  bool get projectRecording =>
      projectContextAvailable &&
      selectedProjectId != null &&
      projectRecord(selectedProjectId!)['recording'] == true;
  void setProjectContinuationDraft(String text) {
    final id = selectedProjectId;
    if (id != null && text.length <= 4000) {
      _setProjectRecord(id, {...projectRecord(id), 'draft': text});
    }
  }

  void setProjectRecording(bool enabled) {
    final id = selectedProjectId;
    if (id == null) return;
    _setProjectRecord(id, {...projectRecord(id), 'recording': enabled});
    notify();
  }

  void recordProjectActivity(UniversalObject object, String action) {
    final id = selectedProjectId;
    if (!projectContextAvailable ||
        id == null ||
        !projectRecording ||
        !(object.id == id || objectProject(object) == id)) {
      return;
    }
    final record = projectRecord(id);
    final events = record['events'] is List
        ? record['events'] as List
        : const [];
    // Coalesce repeated saves/opens; do not log every keystroke.
    if (events.isNotEmpty && events.first is Map) {
      final last = events.first as Map;
      final time = DateTime.tryParse(last['at']?.toString() ?? '');
      if (last['object'] == object.id &&
          last['action'] == action &&
          time != null &&
          DateTime.now().toUtc().difference(time).inSeconds < 60) {
        return;
      }
    }
    _setProjectRecord(id, {
      ...record,
      'events': [
        {
          'object': object.id,
          'action': action,
          'at': DateTime.now().toUtc().toIso8601String(),
        },
        ...events.take(299),
      ],
    });
  }

  void clearProjectActivity() {
    final id = selectedProjectId;
    if (id != null) _setProjectRecord(id, {...projectRecord(id), 'events': []});
    notify();
  }

  Future<bool> saveProjectContinuation(String text) async {
    final id = selectedProjectId;
    final workspace = repository.workspaceId;
    if (id == null ||
        text.length > 4000 ||
        !projectContextAvailable ||
        !await flushAll()) {
      return false;
    }
    if (selectedProjectId != id || repository.workspaceId != workspace) {
      return false;
    }
    final descriptor = WorkspaceContext.capture(session.toJson());
    try {
      WorkspaceContext.validate({
        'version': 1,
        'id': id,
        'name': id,
        'kind': 'space',
        'context': descriptor,
      });
    } on Object {
      error = 'Too many views or unsupported working position.';
      notify();
      return false;
    }
    if (!_setProjectRecord(id, {
      ...projectRecord(id),
      'nextStep': text,
      'draft': text,
      'context': descriptor,
      'versions': {
        for (final objectId in session.tabs)
          if (find(objectId) != null)
            objectId: researchVersion(find(objectId)!),
      },
      'savedAt': DateTime.now().toUtc().toIso8601String(),
    })) {
      return false;
    }
    await saveSession();
    notify();
    return !_settingsSaveFailed;
  }

  Future<bool> resumeProject() async {
    final id = selectedProjectId;
    final workspace = repository.workspaceId;
    if (id == null || !projectContextAvailable || !await flushAll()) {
      return false;
    }
    if (selectedProjectId != id || repository.workspaceId != workspace) {
      return false;
    }
    final record = projectRecord(id), descriptor = projectRecord(id)['context'];
    if (descriptor is! Map) return false;
    try {
      WorkspaceContext.validate({
        'version': 1,
        'id': id,
        'name': id,
        'kind': 'space',
        'context': descriptor,
      });
    } on Object {
      error = 'Unsupported saved position was retained.';
      notify();
      return false;
    }
    final current = session.toJson();
    final versions = record['versions'] is Map
        ? record['versions'] as Map
        : const {};
    final changed = versions.keys
        .whereType<String>()
        .where(
          (key) =>
              find(key) == null || researchVersion(find(key)!) != versions[key],
        )
        .toSet();
    final restored = <String, dynamic>{
      ...current,
      for (final key in WorkspaceContext.contextKeys)
        if (descriptor.containsKey(key)) key: descriptor[key],
    };
    for (final key in ['positions', 'cameras', 'noteViews']) {
      if (restored[key] is Map) {
        final positions = Map<String, dynamic>.from(restored[key] as Map);
        positions.removeWhere(
          (key, _) => changed.any((id) => key == id || key.endsWith(':$id')),
        );
        restored[key] = positions;
      }
    }
    session = SessionState.fromJson(restored);
    studyResumeSerial++;
    final missing = session.tabs
        .where((id) => find(id)?.isDeleted != false)
        .length;
    session.tabs = session.tabs
        .where((id) => find(id)?.isDeleted == false)
        .toList();
    if (find(session.activeId)?.isDeleted != false) {
      session.activeId = session.tabs.firstOrNull;
    }
    if (find(session.secondaryId)?.isDeleted != false) {
      session.secondaryId = null;
    }
    error = missing > 0 || changed.isNotEmpty
        ? '$missing unavailable documents skipped; ${changed.length} changed sources use fresh positions.'
        : null;
    _setProjectRecord(id, {
      ...record,
      'lastResumedAt': DateTime.now().toUtc().toIso8601String(),
    });
    await saveSession();
    notify();
    return !_settingsSaveFailed;
  }

  Future<UniversalObject> importProjectAttachment(
    String name,
    Uint8List bytes, {
    String? folder,
    bool reuseExisting = true,
  }) async {
    final workspace = repository.workspaceId, generation = workspaceGeneration;
    final props = projectCreationProperties({'folder': ?folder});
    final object = await repository.importAttachment(
      name: name,
      bytes: bytes,
      folder: folder,
      reuseExisting: reuseExisting,
    );
    if (repository.workspaceId != workspace ||
        workspaceGeneration != generation) {
      throw StateError('Vault changed during capture.');
    }
    if (folder != null) props['folder'] = object.properties['folder'];
    try {
      final hasOwner = [
        'project',
        'course',
        'context',
      ].any(object.properties.containsKey);
      final needsEnrichment = props.entries.any(
        (entry) => object.properties[entry.key] != entry.value,
      );
      final saved = !needsEnrichment || hasOwner
          ? object
          : await repository.save(
              object.copyWith(properties: {...object.properties, ...props}),
            );
      if (repository.workspaceId != workspace ||
          workspaceGeneration != generation) {
        throw StateError('Vault changed during capture.');
      }
      mergeRepositoryObjects();
      recordProjectActivity(saved, 'captured');
      notify();
      return saved;
    } finally {
      if (repository.workspaceId == workspace &&
          workspaceGeneration == generation) {
        mergeRepositoryObjects();
        notify();
      }
    }
  }

  Future<bool> addProjectConnection(
    String sourceId,
    String kind,
    String target,
    String note, {
    String? expectedSourceVersion,
    int? expectedGeneration,
  }) async {
    if (expectedGeneration != null &&
        expectedGeneration != workspaceGeneration) {
      return false;
    }
    final source = find(sourceId), reference = ObjectReference.parse(target);
    final destination = find(reference.id);
    if (!projectConnectionKinds.contains(kind) ||
        note.length > 2000 ||
        target.length > 1000 ||
        source?.isDeleted != false ||
        source!.isReadOnly ||
        expectedSourceVersion != null &&
            researchVersion(source) != expectedSourceVersion ||
        destination?.isDeleted != false ||
        sourceId == reference.id ||
        repository.readOnly ||
        !ProjectConnection.supported(source.properties['orbitConnections'])) {
      return false;
    }
    final raw = source.properties['orbitConnections'];
    final entries = raw is Map ? raw['items'] as List : const [];
    if (entries.length >= 200) return false;
    if (ProjectConnection.read(
      raw,
    ).any((r) => r.kind == kind && r.target.target == target)) {
      return false;
    }
    return _saveProjectProperties(
      source,
      {
        ...source.properties,
        'orbitConnections': {
          ...?(raw is Map ? Map<String, dynamic>.from(raw) : null),
          'version': 1,
          'items': [
            ...entries,
            {
              'id': const Uuid().v4(),
              'kind': kind,
              'target': target,
              'note': note.trim(),
              'versionToken': researchVersion(destination!),
              'createdAt': DateTime.now().toUtc().toIso8601String(),
            },
          ],
        },
      },
      ['orbitConnections'],
    );
  }

  Future<bool> removeProjectConnection(
    String sourceId,
    String connectionId,
  ) async {
    final source = find(sourceId);
    if (source?.isDeleted != false ||
        source!.isReadOnly ||
        repository.readOnly ||
        !ProjectConnection.supported(source.properties['orbitConnections'])) {
      return false;
    }
    final raw = source.properties['orbitConnections'];
    if (raw is! Map ||
        !ProjectConnection.read(raw).any((r) => r.id == connectionId)) {
      return false;
    }
    return _saveProjectProperties(
      source,
      {
        ...source.properties,
        'orbitConnections': {
          ...raw,
          'items': (raw['items'] as List)
              .where((r) => r is! Map || r['id'] != connectionId)
              .toList(),
        },
      },
      ['orbitConnections'],
    );
  }
}
