part of 'workspace_controller.dart';

extension ResearchWorkflows on WorkspaceController {
  Future<UniversalObject?> createResearchCollection({
    required String title,
    String? folder,
    String? project,
    List<Map<String, dynamic>> entries = const [],
  }) => create(
    'orbit.view',
    title: title,
    properties: {
      'viewType': 'research',
      'researchVersion': 1,
      'researchLayout': 'Gallery',
      'referenceEntries': entries,
      'folder': ?folder,
      'project': ?project,
    },
  );

  /// Existing placement commentary is copied into the collection, never source bytes.
  List<Map<String, dynamic>> researchBoardEntries(String boardId) {
    final board = find(boardId);
    if (board == null || board.typeId != 'orbit.canvas') return const [];
    final ids = <String>{};
    return [
      for (final e in CanvasScene.fromJson(board.data).elements)
        if (e.data['objectId'] is String &&
            ids.add(e.data['objectId'] as String))
          {
            'objectId': e.data['objectId'],
            'boardId': board.id,
            'placementId': e.id,
            for (final key in [
              'referenceCaption',
              'referenceTags',
              'referenceStatus',
              'referenceSourceUrl',
            ])
              if (e.data[key] != null) key: e.data[key],
          },
    ];
  }

  Future<UniversalObject?> saveResearchRecord({
    UniversalObject? previous,
    required String kind,
    required String title,
    required String body,
    required String state,
    required String confidence,
    required String importance,
    required List<String> evidence,
    required List<String> assumptions,
    required List<String> supersedes,
    String? project,
    String? folder,
  }) async {
    try {
      if (title.trim().isEmpty) {
        throw const FormatException('Enter a statement.');
      }
      if (previous != null &&
          (previous.properties['researchVersion'] != 1 ||
              previous.properties['researchKind'] != kind)) {
        throw StateError(
          'Unsupported research record. Its saved data is preserved.',
        );
      }
      if (previous != null &&
          researchVersion(find(previous.id) ?? previous) !=
              researchVersion(previous)) {
        throw StateError(
          'This record changed while editing. Reopen it to keep the latest version.',
        );
      }
      if (previous != null &&
          (find(previous.id) == null || find(previous.id)!.isDeleted)) {
        throw StateError('This record is no longer available.');
      }
      final linked = {...evidence, ...assumptions, ...supersedes};
      for (final id in assumptions) {
        final source = find(id);
        if (source != null &&
            source.properties['researchKind'] != 'assumption') {
          throw const FormatException(
            'Choose an assumption for an assumption dependency.',
          );
        }
      }
      for (final id in supersedes) {
        final source = find(id);
        if (source != null && source.properties['researchKind'] != kind) {
          throw const FormatException(
            'Superseded records must have the same kind.',
          );
        }
      }
      if (previous != null && linked.contains(previous.id)) {
        throw const FormatException('A record cannot depend on itself.');
      }
      for (final id in linked) {
        // Existing missing links are retained; newly introduced links must resolve.
        final old = previous == null
            ? <String>{}
            : {
                ...researchIds(previous.properties['evidenceIds']),
                ...researchIds(previous.properties['assumptionIds']),
                ...researchIds(previous.properties['supersedesIds']),
              };
        if (!old.contains(id) && (find(id) == null || find(id)!.isDeleted)) {
          throw const FormatException(
            'A selected source is no longer available.',
          );
        }
      }
      for (final id in linked) {
        await flush(id);
        if (dirty.contains(id) || failures.containsKey(id)) {
          throw StateError(
            'Save or recover the linked source before recording its version.',
          );
        }
      }
      if (previous != null &&
          researchVersion(find(previous.id) ?? previous) !=
              researchVersion(previous)) {
        throw StateError(
          'This record changed while saving its sources. Reopen it before saving.',
        );
      }
      final properties = {
        ...?previous?.properties,
        'researchVersion': 1,
        'researchKind': kind,
        'researchState': state,
        'confidence': confidence,
        'importance': importance,
        'evidenceIds': evidence,
        'assumptionIds': assumptions,
        'supersedesIds': supersedes,
        // Keep previous acknowledged versions until the user explicitly reviews.
        'evidenceVersions': {
          ...researchEvidenceVersions([...evidence, ...assumptions], objects),
          if (previous?.properties['evidenceVersions'] is Map)
            for (final e
                in (previous!.properties['evidenceVersions'] as Map).entries)
              if (e.key is String &&
                  [...evidence, ...assumptions].contains(e.key))
                e.key as String: e.value,
        },
        'recordedAt':
            previous?.properties['recordedAt'] ??
            DateTime.now().toUtc().toIso8601String(),
        if (previous != null)
          'revisions': [
            researchCheckpoint(previous, const Uuid().v4()),
            ...getDocumentSnapshots(previous.id),
          ].take(30).toList(),
        if (project != null && project.isNotEmpty) 'project': project,
        'folder': ?folder,
      };
      validateResearchProperties(properties);
      if (previous == null) {
        return create(
          'orbit.note',
          title: title.trim(),
          body: body,
          properties: properties,
        );
      }
      if (previous.isReadOnly || repository.readOnly) {
        throw StateError('This record is read-only.');
      }
      edit(
        previous.id,
        title: title.trim(),
        body: body,
        properties: properties,
      );
      await flush(previous.id);
      if (dirty.contains(previous.id) || failures.containsKey(previous.id)) {
        throw StateError(
          failures[previous.id] ?? 'The record has not been saved.',
        );
      }
      return find(previous.id);
    } on Object catch (e) {
      error = '$e';
      notify();
      return null;
    }
  }

  Future<bool> reviewResearchDecision(String id) async {
    final workspace = repository.workspaceId;
    final o = find(id);
    if (o == null ||
        o.isDeleted ||
        o.isReadOnly ||
        repository.readOnly ||
        o.properties['researchVersion'] != 1 ||
        o.properties['researchKind'] != 'decision') {
      return false;
    }
    for (final sourceId in [
      ...researchIds(o.properties['evidenceIds']),
      ...researchIds(o.properties['assumptionIds']),
    ]) {
      await flush(sourceId);
      if (repository.workspaceId != workspace) return false;
      if (dirty.contains(sourceId) || failures.containsKey(sourceId)) {
        return false;
      }
    }
    if (find(id) == null || researchVersion(find(id)!) != researchVersion(o)) {
      return false;
    }
    try {
      validateResearchProperties(o.properties);
    } on Object catch (e) {
      error = '$e';
      notify();
      return false;
    }
    edit(
      id,
      properties: {
        ...o.properties,
        'evidenceVersions': researchEvidenceVersions([
          ...researchIds(o.properties['evidenceIds']),
          ...researchIds(o.properties['assumptionIds']),
        ], objects),
        'reviewedAt': DateTime.now().toUtc().toIso8601String(),
        'revisions': [
          researchCheckpoint(o, const Uuid().v4()),
          ...getDocumentSnapshots(id),
        ].take(30).toList(),
      },
    );
    await flush(id);
    return !dirty.contains(id) && !failures.containsKey(id);
  }
}
