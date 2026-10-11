part of 'workspace_controller.dart';

extension WorkspaceStudy on WorkspaceController {
  List<UniversalObject> get studyCards =>
      activeObjects.where(StudyCard.supported).toList();

  Future<UniversalObject?> createStudyCard({
    required String question,
    required String answer,
    String course = '',
    UniversalObject? source,
    String passage = '',
    int? page,
    String? checksum,
    DateTime? now,
  }) async {
    Completer<void>? operation;
    try {
      if (question.trim().isEmpty ||
          answer.trim().isEmpty ||
          question.length > 2000 ||
          answer.length > 100000 ||
          course.length > 500 ||
          repository.readOnly ||
          _planningBusy) {
        throw const FormatException(
          'Provide a question and answer within the card limits.',
        );
      }
      _planningBusy = true;
      operation = Completer<void>();
      _productivityOperation = operation;
      final at = now ?? DateTime.now();
      if (source != null &&
          (!identical(find(source.id), source) ||
              source.isDeleted ||
              dirty.contains(source.id))) {
        throw const FormatException(
          'Save or refresh the source before creating a card.',
        );
      }
      final pdf = source?.properties['pdfSource'];
      final resolvedPage =
          page ??
          (pdf is Map && pdf['page'] is int ? pdf['page'] as int : null);
      final resolvedChecksum =
          checksum ??
          (pdf is Map && pdf['checksum'] is String
              ? pdf['checksum'] as String
              : null);
      final record = StudyCard.initial(
        at,
        source: source == null
            ? null
            : {
                'objectId': source.id,
                'title': source.title,
                'revision': source.revision,
                'capturedAt': at.toUtc().toIso8601String(),
                'passage': passage,
                'page': ?resolvedPage,
                'checksum': ?resolvedChecksum,
                if (pdf is Map) 'pdfSource': {...pdf},
              },
      );
      StudyCard.validate(record);
      if (source != null && checksum != null && source.typeId == 'orbit.file') {
        final vault = repository.workspaceId;
        if (await repository.pdfSourceChecksum(
                  source.properties['contentRef'] as String,
                ) !=
                checksum ||
            repository.workspaceId != vault ||
            !identical(find(source.id), source)) {
          throw const FormatException(
            'The source changed. Refresh before creating a card.',
          );
        }
      }
      final sourceCourse = source?.properties['course'];
      return await create(
        'orbit.note',
        title: question.trim(),
        body: answer.trim(),
        properties: {
          'folder': source?.properties['folder'] ?? 'Study',
          'course': course.trim().isNotEmpty
              ? course.trim()
              : sourceCourse ?? '',
          'studyCard': record,
          if (pdf is Map) 'pdfSource': {...pdf},
          if (source?.typeId == 'orbit.file' &&
              source?.properties['mimeType'] == 'application/pdf' &&
              page != null)
            'pdfSource': {
              'objectId': source!.id,
              'page': page,
              'checksum': checksum,
            },
        },
      );
    } on Object catch (e) {
      error = '$e';
      notify();
      return null;
    } finally {
      if (operation != null) {
        _planningBusy = false;
        operation.complete();
        if (identical(_productivityOperation, operation)) {
          _productivityOperation = null;
        }
      }
    }
  }

  Future<bool> reviewStudyCard(
    UniversalObject expected,
    StudyRating rating, {
    DateTime? now,
  }) async {
    try {
      final changed = StudyCard(
        expected,
      ).reviewed(rating, now ?? DateTime.now());
      return _commitProductivity(
        expected,
        {'studyCard': changed},
        title: expected.title,
        body: expected.body,
      );
    } on Object catch (e) {
      error = '$e';
      notify();
      return false;
    }
  }

  Future<bool> suspendStudyCard(
    UniversalObject expected,
    bool suspended,
  ) async {
    if (!StudyCard.supported(expected)) return false;
    return _commitProductivity(expected, {
      'studyCard': {...StudyCard(expected).record, 'suspended': suspended},
    });
  }

  Future<bool> editStudyCard(
    UniversalObject expected,
    String question,
    String answer,
    String course,
  ) async {
    if (!StudyCard.supported(expected) ||
        question.trim().isEmpty ||
        answer.trim().isEmpty ||
        question.length > 2000 ||
        answer.length > 100000 ||
        course.length > 500) {
      error = 'Provide a question and answer within the card limits.';
      notify();
      return false;
    }
    return _commitProductivity(
      expected,
      {'course': course.trim()},
      title: question.trim(),
      body: answer.trim(),
    );
  }

  Future<bool> markStudyUnderstanding(
    UniversalObject expected,
    String value,
  ) async {
    if (!studyUnderstandingStates.contains(value)) return false;
    return _commitProductivity(expected, {'studyUnderstanding': value});
  }

  String? studySourceWarning(UniversalObject card) {
    final source = StudyCard(card).source;
    if (source == null) return null;
    final original = find(source['objectId'] as String);
    if (original == null || original.isDeleted) {
      return 'Source missing. The captured passage is retained.';
    }
    if (original.revision != source['revision']) {
      return 'Source edited since capture. Verify this answer.';
    }
    final pdf = source['pdfSource'];
    if (pdf is Map && pdf['objectId'] is String) {
      final file = find(pdf['objectId'] as String);
      if (file == null || file.isDeleted) {
        return 'Original PDF missing. The captured passage is retained.';
      }
      if (file.properties['checksum'] != pdf['checksum']) {
        return 'Original PDF replaced. Verify this answer.';
      }
      return null;
    }
    if (source['checksum'] != null &&
        original.properties['checksum'] != source['checksum']) {
      return 'Source replaced since capture. Verify this answer.';
    }
    return null;
  }

  bool openStudySource(UniversalObject card) {
    final source = StudyCard(card).source;
    if (source == null) return false;
    final original = find(source['objectId'] as String);
    if (original == null || original.isDeleted) return false;
    if (openPdfSource(card.id)) return true;
    openObject(original.id);
    return true;
  }
}
