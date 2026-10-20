part of 'workspace_controller.dart';

class EditorDraftConflict {
  const EditorDraftConflict({
    required this.objectId,
    required this.title,
    required this.base,
    required this.body,
    required this.workspace,
    this.typeId = 'orbit.note',
    this.data = const {},
  });
  final String objectId, title, base, body, workspace, typeId;
  final Map<String, dynamic> data;
}

extension WorkspaceEditorDrafts on WorkspaceController {
  /// A pane must publish against the last body it actually observed, not
  /// whichever draft another pane published earlier in the same frame.
  bool publishEditorBody(
    String editorId,
    String objectId,
    String base,
    String body,
  ) {
    final current = find(objectId);
    if (current == null ||
        current.isDeleted ||
        current.isReadOnly ||
        repository.readOnly) {
      return false;
    }
    if (current.body != base && current.body != body) {
      editorDraftConflicts[editorId] = EditorDraftConflict(
        objectId: objectId,
        title: current.title,
        base: base,
        body: body,
        workspace: repository.workspaceId,
      );
      error =
          'Two editors changed the same note. Review the retained draft before switching Vaults or closing.';
      notify();
      return false;
    }
    editorDraftConflicts.remove(editorId);
    edit(objectId, body: body);
    return true;
  }

  bool publishCanvasDraft(
    String editorId,
    String objectId,
    Map<String, dynamic> base,
    Map<String, dynamic> data,
  ) {
    final current = find(objectId);
    if (current == null ||
        current.isDeleted ||
        current.isReadOnly ||
        repository.readOnly) {
      return false;
    }
    if (!jsonValuesEqual(current.data, base) &&
        !jsonValuesEqual(current.data, data)) {
      editorDraftConflicts[editorId] = EditorDraftConflict(
        objectId: objectId,
        title: current.title,
        base: jsonEncode(base),
        body: '',
        workspace: repository.workspaceId,
        typeId: 'orbit.canvas',
        data: current.copyWith(data: data).data,
      );
      error = 'Two editors changed the same Canvas. Review the retained draft.';
      notify();
      return false;
    }
    editorDraftConflicts.remove(editorId);
    edit(objectId, data: data);
    return true;
  }

  void discardEditorDraft(String editorId) {
    editorDraftConflicts.remove(editorId);
    notify();
  }

  Future<UniversalObject?> recoverEditorDraft(String editorId) {
    final draft = editorDraftConflicts[editorId];
    if (draft == null || draft.workspace != repository.workspaceId) {
      return Future.value(null);
    }
    final generation = workspaceGeneration;
    final pending = _editorDraftRecoveries[editorId];
    if (pending != null &&
        pending.generation == generation &&
        identical(pending.draft, draft)) {
      return pending.future;
    }
    late Future<UniversalObject?> future;
    future = _recoverEditorDraftCopy(editorId, draft, generation).whenComplete(
      () {
        if (identical(_editorDraftRecoveries[editorId]?.future, future)) {
          _editorDraftRecoveries.remove(editorId);
        }
      },
    );
    _editorDraftRecoveries[editorId] = (
      generation: generation,
      draft: draft,
      future: future,
    );
    return future;
  }

  Future<UniversalObject?> _recoverEditorDraftCopy(
    String editorId,
    EditorDraftConflict draft,
    int generation,
  ) async {
    final source = find(draft.objectId);
    final copy = await create(
      draft.typeId,
      open: false,
      title: '${draft.title} — recovered draft',
      body: draft.body,
      data: draft.data,
      properties: {
        ...?source?.properties,
        'recoveredFrom': draft.objectId,
        if (source?.properties['isCourseOverview'] == true) ...{
          'isCourseOverview': false,
          'courseId': source!.id,
        },
      },
    );
    if (copy != null &&
        generation == workspaceGeneration &&
        identical(editorDraftConflicts[editorId], draft)) {
      editorDraftConflicts.remove(editorId);
      notify();
    }
    return copy;
  }
}
