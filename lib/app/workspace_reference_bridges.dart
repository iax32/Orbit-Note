part of 'workspace_controller.dart';

extension WorkspaceReferenceBridges on WorkspaceController {
  Future<UniversalObject?> exportCanvasDiagramToNote(
    UniversalObject expectedSource,
    List<String> ids, {
    UniversalObject? expectedNote,
    String title = 'Class diagram',
  }) async {
    final generation = workspaceGeneration;
    bool sourceValid() {
      final current = find(expectedSource.id);
      return !repository.readOnly &&
          repository.workspaceId == expectedSource.workspaceId &&
          current != null &&
          !current.isDeleted &&
          current.typeId == 'orbit.canvas' &&
          current.workspaceId == expectedSource.workspaceId &&
          jsonValuesEqual(current.data, expectedSource.data) &&
          !CanvasScene.fromJson(current.data).readOnly &&
          !editorDraftConflicts.values.any((d) => d.objectId == current.id);
    }

    if (!sourceValid() || title.trim().isEmpty || title.length > 200) {
      return null;
    }
    final scene = CanvasScene.fromJson(expectedSource.data);
    if (ids.isEmpty ||
        ids.length > 1000 ||
        ids.toSet().length != ids.length ||
        ids.any(
          (id) =>
              scene[id] == null || scene[id]!.hidden || !scene[id]!.renderable,
        )) {
      return null;
    }
    final ref = diagramReference(expectedSource.id, ids);
    await flush(expectedSource.id);
    if (generation != workspaceGeneration ||
        !sourceValid() ||
        dirty.contains(expectedSource.id) ||
        failures.containsKey(expectedSource.id)) {
      return null;
    }
    if (expectedNote == null) {
      return create(
        'orbit.note',
        title: title.trim(),
        open: false,
        body: diagramMarkdown(expectedSource.id, title.trim(), ids),
        properties: {
          // Explicitly unassigned ownership also wins over active-project defaults.
          'project': expectedSource.properties['project'],
          for (final key in ['folder', 'project', 'projectName', 'courseId'])
            if (expectedSource.properties[key] != null)
              key: expectedSource.properties[key],
          'sourceBoardId': expectedSource.id,
        },
      );
    }
    final current = find(expectedNote.id);
    if (current == null ||
        current.isDeleted ||
        current.isReadOnly ||
        current.typeId != 'orbit.note' ||
        current.properties['documentFormat'] == 'latex' ||
        current.workspaceId != expectedSource.workspaceId ||
        editorDraftConflicts.values.any((d) => d.objectId == current.id)) {
      return null;
    }
    final eol = expectedNote.body.contains('\r\n') ? '\r\n' : '\n';
    final embed = NoteObjectBlock(
      expectedSource.id,
      title.trim(),
      fragment: ref.fragment,
    ).encode(eol: eol);
    final appended =
        '${expectedNote.body}${expectedNote.body.isEmpty ? '' : '$eol$eol'}$embed';
    // A retry after a failed write flushes the existing draft, never appends twice.
    if (current.body == expectedNote.body) {
      edit(current.id, body: appended);
    } else if (current.body != appended ||
        (!dirty.contains(current.id) && !failures.containsKey(current.id))) {
      return null;
    }
    await flush(current.id);
    if (generation != workspaceGeneration ||
        dirty.contains(current.id) ||
        failures.containsKey(current.id) ||
        find(current.id)?.body != appended) {
      return null;
    }
    return find(current.id);
  }

  List<ObjectConnection> get objectConnections {
    if (!identical(_connectionSnapshot, objects)) {
      _connectionSnapshot = objects;
      _connectionEdges = _connectionResolver.resolve(
        objects,
        pathFor: repository.objectPath,
      );
    }
    return _connectionEdges;
  }

  List<ObjectConnection> connectionsFrom(String id) =>
      objectConnections.where((r) => r.source.id == id).toList();
  List<ObjectConnection> connectionsTo(String id) =>
      objectConnections.where((r) => r.target.id == id).toList();

  bool openReference(
    ObjectReference reference, {
    bool secondary = false,
    int? offset,
  }) {
    final object = find(reference.id);
    if (object == null || object.isDeleted) {
      error =
          'The referenced object is unavailable. Its original reference is retained.';
      notify();
      return false;
    }
    final annotation = reference.anchorType == 'annotation'
        ? find(reference.anchorId)
        : null;
    final validAnnotation =
        annotation != null &&
        !annotation.isDeleted &&
        PdfAnnotation(annotation).fileId == object.id;
    if (reference.anchorType == 'annotation' && !validAnnotation) {
      error = 'The annotation is unavailable; the original document is open.';
    }
    requestLocation(reference, offset: offset);
    if (object.properties['mimeType'] == 'application/pdf' &&
        (reference.page != null || validAnnotation)) {
      final key = 'pdf:${secondary ? 'secondary' : 'primary'}:${object.id}';
      session.noteViews = {
        ...session.noteViews,
        key: {
          ...?session.noteViews[key],
          'page': reference.page ?? PdfAnnotation(annotation!).page,
          'annotationId': validAnnotation ? annotation.id : null,
          'request': locationRequests[object.id]!.serial,
        },
      };
    }
    openObject(object.id, secondary: secondary);
    return true;
  }

  Future<bool> embedReferenceInNote(
    UniversalObject expected,
    ObjectReference reference,
  ) async {
    final source = find(reference.id), current = find(expected.id);
    if (repository.readOnly ||
        current == null ||
        current.isDeleted ||
        current.isReadOnly ||
        current.typeId != 'orbit.note' ||
        current.properties['documentFormat'] == 'latex' ||
        current.workspaceId != expected.workspaceId ||
        current.body != expected.body ||
        source == null ||
        source.isDeleted ||
        current.workspaceId != source.workspaceId ||
        current.id == source.id ||
        editorDraftConflicts.values.any((d) => d.objectId == current.id)) {
      return false;
    }
    final generation = workspaceGeneration;
    final eol = current.body.contains('\r\n') ? '\r\n' : '\n';
    final embed = NoteObjectBlock(
      source.id,
      source.title,
      fragment: reference.isPrecise ? reference.fragment : null,
    ).encode(eol: eol);
    edit(
      current.id,
      body: '${current.body}${current.body.isEmpty ? '' : '$eol$eol'}$embed',
    );
    await flush(current.id);
    return generation == workspaceGeneration &&
        !dirty.contains(current.id) &&
        !failures.containsKey(current.id) &&
        find(current.id)?.body.contains(embed) == true;
  }

  Future<String?> placeReferenceOnCanvas(
    UniversalObject expected,
    ObjectReference reference,
  ) async {
    final source = find(reference.id), current = find(expected.id);
    if (repository.readOnly ||
        current == null ||
        current.isDeleted ||
        current.isReadOnly ||
        current.typeId != 'orbit.canvas' ||
        current.workspaceId != expected.workspaceId ||
        !identical(current.data, expected.data) ||
        CanvasScene.fromJson(current.data).readOnly ||
        source == null ||
        source.isDeleted ||
        source.workspaceId != current.workspaceId ||
        current.id == source.id ||
        editorDraftConflicts.values.any((d) => d.objectId == current.id)) {
      return null;
    }
    final generation = workspaceGeneration, placement = const Uuid().v4();
    final camera = session.cameras[current.id] ?? {};
    edit(
      current.id,
      data: {
        ...current.data,
        'elements': [
          ...?current.data['elements'] as List?,
          {
            'id': placement,
            'type': 'card',
            'objectId': source.id,
            'referenceTarget': reference.target,
            'presentation': 'preview',
            'x': (camera['x'] as num? ?? 0) + 60.0,
            'y': (camera['y'] as num? ?? 0) + 60.0,
            'width': 300.0,
            'height': 210.0,
          },
        ],
      },
    );
    await flush(current.id);
    return generation == workspaceGeneration &&
            !dirty.contains(current.id) &&
            !failures.containsKey(current.id) &&
            CanvasScene.fromJson(
              find(current.id)?.data ?? const {},
            ).elements.any((e) => e.id == placement)
        ? placement
        : null;
  }
}
