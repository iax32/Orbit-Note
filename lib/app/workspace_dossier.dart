part of 'workspace_controller.dart';

extension DossierWorkflows on WorkspaceController {
  Future<UniversalObject?> saveDossierRecord({
    UniversalObject? previous,
    required String title,
    required Map<String, dynamic> data,
    String notes = '',
    bool reviewSources = false,
  }) async {
    final generation = workspaceGeneration;
    try {
      final draft = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(data)) as Map,
      );
      if (!hasWorkspace ||
          loading ||
          repository.readOnly ||
          title.trim().isEmpty ||
          title.length > 300 ||
          notes.length > 200000) {
        throw const FormatException(
          'Enter a title up to 300 characters in a writable Vault.',
        );
      }
      if (previous != null &&
          (!identical(find(previous.id), previous) ||
              previous.isDeleted ||
              previous.isReadOnly ||
              !isDossierRecord(previous))) {
        throw const FormatException(
          'This record changed or is unavailable. Reopen it; your draft is retained.',
        );
      }
      final old = previous == null
          ? <String, dynamic>{}
          : dossierData(previous);
      if (previous != null &&
          (old['kind'] != draft['kind'] ||
              old['dossierId'] != draft['dossierId'])) {
        throw const FormatException(
          'Keep record kind and dossier identity intact.',
        );
      }
      final next = {...old, ...draft, 'version': 1};
      validateDossier(next);
      UniversalObject? root;
      if (next['kind'] != 'dossier') {
        root = find(next['dossierId']);
        if (root == null ||
            !isDossierRecord(root) ||
            dossierData(root)['kind'] != 'dossier') {
          throw const FormatException(
            'The dossier is missing. Restore it before saving.',
          );
        }
      }
      final oldLinks = {
        for (final l in dossierRows(old, 'links')) '${l['role']}:${l['id']}': l,
      };
      final links = <Map<String, dynamic>>[];
      final sources = <UniversalObject>[];
      for (final proposed in dossierRows(next, 'links')) {
        final key = '${proposed['role']}:${proposed['id']}';
        final prior = oldLinks[key];
        if (proposed['id'] == previous?.id) {
          throw const FormatException(
            'Choose another record instead of linking a record to itself.',
          );
        }
        final source = find(proposed['id']);
        if (source == null || source.isDeleted) {
          if (prior == null) {
            throw const FormatException(
              'A selected source is missing or in Trash.',
            );
          }
          links.add({...prior, ...proposed});
          continue;
        }
        await flush(source.id);
        if (generation != workspaceGeneration ||
            dirty.contains(source.id) ||
            failures.containsKey(source.id)) {
          throw const FormatException(
            'Save or recover the linked source first.',
          );
        }
        final current = find(source.id)!;
        sources.add(current);
        links.add({
          ...?prior,
          ...proposed,
          'revision': prior == null || reviewSources
              ? current.revision
              : prior['revision'],
          'sourceVersion': prior == null || reviewSources
              ? researchVersion(current)
              : prior['sourceVersion'],
          'label': current.title,
        });
      }
      if (generation != workspaceGeneration ||
          root != null && !identical(find(root.id), root)) {
        throw const FormatException(
          'The Vault or dossier changed while saving. Reopen the editor.',
        );
      }
      next['links'] = links;
      if (root != null) next['dossierTitle'] = root.title;
      next['history'] = [
        ...dossierRows(old, 'history'),
        {
          'at': DateTime.now().toUtc().toIso8601String(),
          'state': next['state'],
          'build': next['build'] ?? '',
          'reviewedSources': reviewSources ? 'yes' : 'no',
        },
      ].reversed.take(100).toList().reversed.toList();
      validateDossier(next);
      final body = updateDossierBody(
        previous?.body ?? '',
        next,
        creating: previous == null,
        notes: notes,
      );
      final bridges = <String, dynamic>{
        if (next['kind'] == 'glossary')
          'aliases': '${next['aliases'] ?? ''}'
              .split(RegExp(r'[,;\r\n]'))
              .map((a) => a.trim())
              .where((a) => a.isNotEmpty)
              .toSet()
              .toList(),
        if (next['kind'] == 'function') ...{
          'category': 'Function',
          'binaryId': root!.id,
          'binaryVersion': next['build'] ?? '',
          'moduleId': next['moduleId'] ?? '',
          'module': next['module'] ?? '',
          'symbol': next['symbol'] ?? '',
          'address': next['address'] ?? '',
          'addressSpace': next['addressSpace'] ?? 'rva',
          'purpose': next['summary'] ?? '',
          'parameters': next['parameters'] ?? '',
          'returnType': next['returns'] ?? '',
          'callingConvention': next['convention'] ?? '',
          'status': next['state'],
          'confidence': next['confidence'],
        },
      };
      if (previous == null) {
        return create(
          'orbit.note',
          open: false,
          title: title.trim(),
          body: body,
          properties: {
            'researchDossier': next,
            'category': 'Research ${next['kind']}',
            ...bridges,
            'folder': root?.properties['folder'] ?? 'Research dossiers',
          },
        );
      }
      final ok = await _commitProductivity(
        previous,
        {'researchDossier': next, ...bridges},
        title: title.trim(),
        body: body,
        prerequisites: [?root, ...sources],
      );
      return ok ? find(previous.id) : null;
    } catch (e) {
      if (generation == workspaceGeneration) {
        error = '$e';
        notify();
      }
      return null;
    }
  }

  Future<UniversalObject?> createDossierMap(String rootId) async {
    final root = find(rootId);
    if (root == null ||
        !isDossierRecord(root) ||
        dossierData(root)['kind'] != 'dossier') {
      return null;
    }
    final records = activeObjects
        .where(
          (o) => isDossierRecord(o) && dossierData(o)['dossierId'] == rootId,
        )
        .toList();
    if (records.isEmpty || records.length > 200) {
      error =
          'A research map needs 1–200 records. Split larger investigations into dossiers.';
      notify();
      return null;
    }
    final selected = {for (final o in records) o.id: o};
    for (final o in records) {
      for (final l in dossierRows(dossierData(o), 'links')) {
        final target = find(l['id']);
        if (target != null && !target.isDeleted) selected[target.id] = target;
      }
    }
    if (selected.length > 500) {
      error = 'Map has more than 500 linked sources. Split this investigation.';
      notify();
      return null;
    }
    final placements = {for (final id in selected.keys) id: const Uuid().v4()};
    final values = selected.values.toList();
    final elements = <Map<String, dynamic>>[
      for (var i = 0; i < values.length; i++)
        {
          'id': placements[values[i].id],
          'type': 'card',
          'objectId': values[i].id,
          'x': (i % 4) * 400.0,
          'y': (i ~/ 4) * 280.0,
          'width': 330.0,
          'height': 210.0,
        },
    ];
    for (final record in records) {
      for (final link in dossierRows(dossierData(record), 'links')) {
        if (!placements.containsKey(link['id'])) continue;
        elements.add({
          'id': const Uuid().v4(),
          'type': 'connector',
          'startId': placements[record.id],
          'endId': placements[link['id']],
          'x': 0.0,
          'y': 0.0,
          'width': 0.0,
          'height': 0.0,
          'routing': 'orthogonal',
          'endMarker': 'arrow',
          'text':
              '${link['role']}${link['offset'] == '' || link['offset'] == null ? '' : ' · ${link['offset']}'}',
        });
      }
    }
    return create(
      'orbit.canvas',
      title: '${root.title} · research map',
      data: {'schemaVersion': 1, 'elements': elements},
      properties: {'folder': root.properties['folder'], 'dossierId': root.id},
    );
  }
}
