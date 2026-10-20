part of 'workspace_controller.dart';

extension TechnicalEvidenceWorkflows on WorkspaceController {
  Future<UniversalObject?> createSourceEvidence(
    SourceExcerpt excerpt, {
    required String folder,
    String? ownerId,
  }) async {
    final owner = ownerId == null ? null : find(ownerId);
    if (repository.readOnly ||
        excerpt.path.isEmpty ||
        excerpt.repository.isEmpty ||
        excerpt.start < 1 ||
        excerpt.end < excerpt.start ||
        excerpt.end > 1000000 ||
        excerpt.text.trim().isEmpty ||
        excerpt.text.length > 100000 ||
        excerpt.path.startsWith('/') ||
        RegExp(r'^[a-zA-Z]:').hasMatch(excerpt.path) ||
        excerpt.path.contains('\\') ||
        excerpt.path.length > 4096 ||
        excerpt.repository.length > 4096 ||
        excerpt.path
            .split('/')
            .any((s) => s.isEmpty || s == '..' || s == '.') ||
        excerpt.language.contains(RegExp(r'[\r\n` ]')) ||
        (excerpt.sourceSha256.isNotEmpty &&
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(excerpt.sourceSha256)) ||
        (ownerId != null && (owner?.isDeleted != false || owner!.isReadOnly))) {
      error =
          'Choose a valid, nonempty source excerpt up to 100,000 characters in this workspace.';
      notify();
      return null;
    }
    final metadata = {
      'version': 1,
      'method': 'working-tree-capture',
      'repository': excerpt.repository,
      'path': excerpt.path,
      'startLine': excerpt.start,
      'endLine': excerpt.end,
      'language': excerpt.language,
      'excerptSha256': sha256.convert(utf8.encode(excerpt.text)).toString(),
      if (excerpt.sourceSha256.isNotEmpty) 'sourceSha256': excerpt.sourceSha256,
      'capturedAt': DateTime.now().toUtc().toIso8601String(),
    };
    return create(
      'orbit.note',
      open: false,
      title:
          '${p.posix.basename(excerpt.path)} · lines ${excerpt.start}–${excerpt.end}',
      body:
          '## Source evidence\n\n'
          '**Source:** ${_technicalLiteral(excerpt.path)} · lines ${excerpt.start}–${excerpt.end}\n\n'
          'This is a working-tree snapshot, not a verified Git commit.\n\n'
          '${owner == null ? '' : 'Project context: [[${owner.id}]]\n\n'}'
          '${excerpt.markdown}\n\n## Observations\n\n',
      properties: {
        'folder': folder,
        'category': 'Source Evidence',
        'sourceCapture': metadata,
        if (owner != null) ...{
          'resourceIds': [owner.id],
          for (final key in ['projectId', 'project', 'target'])
            if (owner.properties[key] != null) key: owner.properties[key],
        },
      },
    );
  }

  bool _comparisonIsCurrent(ResearchBuildComparison comparison) {
    if (repository.readOnly || comparison.sources.isEmpty) return false;
    return comparison.sources.every((o) {
      final current = find(o.id);
      return current != null &&
          !current.isDeleted &&
          !current.isReadOnly &&
          current.workspaceId == o.workspaceId &&
          o.workspaceId == repository.workspaceId &&
          current.revision == o.revision &&
          current.body == o.body &&
          jsonEncode(current.properties) == jsonEncode(o.properties) &&
          !dirty.contains(o.id) &&
          !failures.containsKey(o.id);
    });
  }

  Future<UniversalObject?> saveResearchComparison(
    ResearchBuildComparison comparison, {
    required String folder,
    String target = '',
  }) async {
    if (!_comparisonIsCurrent(comparison)) {
      error =
          'Function records changed, are unsaved or unavailable. Refresh the comparison before saving.';
      notify();
      return null;
    }
    return create(
      'orbit.note',
      open: false,
      title:
          '${comparison.baseline.binaryId} · ${comparison.baseline.version} → ${comparison.candidate.version}',
      body: comparison.markdown,
      properties: {
        'folder': folder,
        'category': 'Build Comparison',
        'researchComparisonVersion': 1,
        if (target.isNotEmpty) 'target': target,
        'binaryId': comparison.baseline.binaryId,
        'baselineBuild': comparison.baseline.version,
        'candidateBuild': comparison.candidate.version,
        'resourceIds': comparison.sources.map((o) => o.id).toList(),
        'sourceVersions': {
          for (final o in comparison.sources) o.id: o.revision,
        },
        'comparisonCounts': comparison.counts,
      },
    );
  }

  Future<UniversalObject?> createComparisonInvestigation(
    ResearchBuildComparison comparison,
    ResearchComparisonRow row, {
    required String folder,
    String target = '',
  }) async {
    if (!_comparisonIsCurrent(comparison) || !comparison.rows.contains(row)) {
      error = 'Refresh this comparison before creating an investigation.';
      notify();
      return null;
    }
    return create(
      'orbit.task',
      open: false,
      title: 'Review ${row.symbol} · ${comparison.candidate.version}',
      body:
          '## Investigate recorded map difference\n\n'
          'Classification: ${row.state}\n\n'
          'Compare the original function records and verify against your specialist tools.\n\n'
          '${row.sources.map((o) => '- [[${o.id}]]').join('\n')}\n\n'
          '- [ ] Verify module and build identity\n'
          '- [ ] Check the recorded location and prototype\n'
          '- [ ] Record evidence and resolve uncertainty\n',
      properties: {
        'folder': folder,
        if (target.isNotEmpty) 'target': target,
        'category': 'Build Investigation',
        'binaryId': comparison.baseline.binaryId,
        'baselineBuild': comparison.baseline.version,
        'candidateBuild': comparison.candidate.version,
        'resourceIds': row.sources.map((o) => o.id).toList(),
        'sourceVersions': {for (final o in row.sources) o.id: o.revision},
      },
    );
  }
}

String _technicalLiteral(String value) => value
    .replaceAll(RegExp(r'[\r\n]'), ' ')
    .replaceAllMapped(RegExp(r'[\\`*_\[\]<>#|]'), (m) => '\\${m[0]}');
