part of 'workspace_controller.dart';

extension WorkspacePdfReview on WorkspaceController {
  Future<UniversalObject?> createPdfReviewBoard(
    UniversalObject source,
    List<PdfAnnotation> items,
  ) async {
    final opening = workspaceGeneration, file = find(source.id);
    final unique =
        {for (final item in items) item.object.id: item}.values.toList()..sort(
          (a, b) => a.page != b.page
              ? a.page.compareTo(b.page)
              : a.object.id.compareTo(b.object.id),
        );
    if (_pdfReviewBatchBusy ||
        repository.readOnly ||
        source.workspaceId != repository.workspaceId ||
        file == null ||
        file.isDeleted ||
        file.isReadOnly ||
        file.typeId != 'orbit.file' ||
        file.properties['mimeType'] != 'application/pdf' ||
        file.properties['checksum'] != source.properties['checksum'] ||
        unique.isEmpty ||
        unique.length > 1000 ||
        unique.any(
          (a) =>
              !identical(find(a.object.id), a.object) ||
              !PdfAnnotation.isAnnotation(a.object) ||
              a.fileId != source.id ||
              !a.matches(source.properties['checksum'] as String?) ||
              dirty.contains(a.object.id) ||
              _saving.containsKey(a.object.id) ||
              editorDraftConflicts.values.any((d) => d.objectId == a.object.id),
        )) {
      return null;
    }
    final board = await create(
      'orbit.canvas',
      open: false,
      title: 'Review · ${source.title}',
      properties: {
        'project': source.properties['project'],
        for (final key in ['folder', 'projectName', 'courseId'])
          if (source.properties[key] != null) key: source.properties[key],
        'sourcePdfId': source.id,
      },
      data: {
        'schemaVersion': 1,
        'elements': [
          {
            'id': const Uuid().v4(),
            'type': 'card',
            'objectId': source.id,
            'referenceTarget': ObjectReference(
              source.id,
              page: unique.first.page,
            ).target,
            'text': source.title,
            'x': 40.0,
            'y': 40.0,
            'width': 640.0,
            'height': 180.0,
            'presentation': 'preview',
          },
          for (var i = 0; i < unique.length; i++)
            {
              'id': const Uuid().v4(),
              'type': 'card',
              'objectId': unique[i].object.id,
              'referenceTarget': unique[i].object.id,
              'text': unique[i].object.title,
              'x': 40.0 + (i % 3) * 340.0,
              'y': 260.0 + (i ~/ 3) * 260.0,
              'width': 320.0,
              'height': 220.0,
              'presentation': 'preview',
            },
        ],
      },
    );
    return opening == workspaceGeneration ? board : null;
  }

  Future<PdfReviewBatchResult> changePdfReviews(
    UniversalObject source,
    List<PdfAnnotation> items,
    PdfReviewBatchAction action, {
    int? color,
    bool Function()? isCancelled,
    void Function(int, int)? onProgress,
  }) async {
    final repo = repository, opening = workspaceGeneration;
    final changes = <PdfReviewChange>[], failures = <String, String>{};
    var unchanged = 0, cancelled = false;
    bool current() =>
        identical(repository, repo) &&
        opening == workspaceGeneration &&
        repo.workspaceId == source.workspaceId;
    final unique = {for (final a in items) a.object.id: a}.values.toList();
    PdfReviewBatchResult result() => PdfReviewBatchResult(
      workspaceId: source.workspaceId,
      fileId: source.id,
      action: action,
      changes: changes,
      failures: failures,
      unchanged: unchanged,
      cancelled: cancelled,
      requested: unique.length,
    );
    if (_pdfReviewBatchBusy || unique.isEmpty || unique.length > 1000) {
      for (final a in unique) {
        failures[a.object.id] =
            'Choose 1–1,000 items and finish the current batch first.';
      }
      return result();
    }
    _pdfReviewBatchBusy = true;
    try {
      for (final item in unique) {
        if (!current() || isCancelled?.call() == true) {
          cancelled = true;
          break;
        }
        final before = item.object, file = find(source.id);
        if (repo.readOnly ||
            file == null ||
            file.isDeleted ||
            file.isReadOnly ||
            file.typeId != 'orbit.file' ||
            file.properties['mimeType'] != 'application/pdf' ||
            item.fileId != source.id ||
            !identical(find(before.id), before) ||
            !PdfAnnotation.isAnnotation(before) ||
            before.isReadOnly ||
            dirty.contains(before.id) ||
            _saving.containsKey(before.id) ||
            editorDraftConflicts.values.any((d) => d.objectId == before.id) ||
            (action != PdfReviewBatchAction.trash &&
                (!item.matches(source.properties['checksum'] as String?) ||
                    file.properties['checksum'] !=
                        source.properties['checksum']))) {
          failures[before.id] =
              'Changed, read-only, unsaved or stale-source item; reopen it before editing.';
        } else {
          final candidate = changedPdfReview(item, action, color: color);
          if (candidate == null) {
            failures[before.id] =
                'Unsupported review format or action for this item.';
          } else if (candidate.isDeleted == before.isDeleted &&
              jsonValuesEqual(candidate.properties, before.properties)) {
            unchanged++;
          } else {
            try {
              final saved = await repo.save(candidate);
              changes.add(PdfReviewChange(before, saved));
              if (!current()) {
                cancelled = true;
                break;
              }
              _mergeSavedDeletion(saved);
              if (saved.isDeleted) _closeTrashedTabs(saved.id);
              notify();
            } catch (_) {
              failures[before.id] =
                  'Save failed; the original note is retained. Retry after checking the Vault.';
            }
          }
        }
        onProgress?.call(
          changes.length + failures.length + unchanged,
          unique.length,
        );
      }
    } finally {
      _pdfReviewBatchBusy = false;
    }
    return result();
  }

  Future<PdfReviewBatchResult> undoPdfReviewBatch(
    PdfReviewBatchResult receipt, {
    bool Function()? isCancelled,
    void Function(int, int)? onProgress,
  }) async {
    final repo = repository, opening = workspaceGeneration;
    final changes = <PdfReviewChange>[], failures = <String, String>{};
    var cancelled = false;
    final work = receipt.changes;
    if (_pdfReviewBatchBusy) {
      for (final change in work) {
        failures[change.after.id] = 'Another review batch is running.';
      }
    } else {
      _pdfReviewBatchBusy = true;
      try {
        for (final change in work) {
          if (opening != workspaceGeneration ||
              !identical(repo, repository) ||
              repo.workspaceId != receipt.workspaceId ||
              isCancelled?.call() == true) {
            cancelled = true;
            break;
          }
          final current = find(change.after.id), before = change.before;
          if (repo.readOnly ||
              current == null ||
              current.isReadOnly ||
              !jsonValuesEqual(current.toJson(), change.after.toJson()) ||
              dirty.contains(current.id) ||
              _saving.containsKey(current.id) ||
              editorDraftConflicts.values.any(
                (d) => d.objectId == current.id,
              )) {
            failures[change.after.id] =
                'A newer edit is retained. Restore or review this note individually.';
          } else {
            try {
              final saved = await repo.save(
                current.copyWith(
                  body: before.body,
                  properties: before.properties,
                  data: before.data,
                  deletedAt: before.deletedAt,
                  clearDeletedAt: !before.isDeleted,
                ),
              );
              changes.add(PdfReviewChange(current, saved));
              if (opening != workspaceGeneration ||
                  !identical(repo, repository)) {
                cancelled = true;
                break;
              }
              _mergeSavedDeletion(saved);
              notify();
            } catch (_) {
              failures[current.id] =
                  'Undo could not be saved. The latest committed note is retained.';
            }
          }
          onProgress?.call(changes.length + failures.length, work.length);
        }
      } finally {
        _pdfReviewBatchBusy = false;
      }
    }
    return PdfReviewBatchResult(
      workspaceId: receipt.workspaceId,
      fileId: receipt.fileId,
      action: receipt.action,
      changes: changes,
      failures: failures,
      requested: work.length,
      cancelled: cancelled,
    );
  }
}
