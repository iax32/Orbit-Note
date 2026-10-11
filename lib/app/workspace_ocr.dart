part of 'workspace_controller.dart';

extension WorkspaceOcr on WorkspaceController {
  List<UniversalObject> get ocrAttachments => activeObjects
      .where(
        (o) =>
            o.typeId == 'orbit.file' &&
            (objectKindLabel(o) == 'PDF' ||
                (o.properties['mimeType'] as String? ?? '').startsWith(
                  'image/',
                )),
      )
      .toList();

  void _ocrNotify() {
    if (!_alive) return;
    if (!_pdfIndexEvents.isClosed) _pdfIndexEvents.add(null);
    notify();
  }

  void pauseOcr(bool value) {
    ocrPaused = value;
    if (value) {
      _ocrResume ??= Completer<void>();
    } else {
      _ocrResume?.complete();
      _ocrResume = null;
    }
    _ocrNotify();
  }

  void cancelOcr() {
    _ocrGeneration++;
    if (_ocrResume != null) {
      _ocrResume!.complete();
      _ocrResume = null;
    }
    ocrPaused = false;
    if (ocrRunning) {
      ocrStatus =
          'Cancelling after the current page; saved recognition stays intact.';
    }
    _ocrNotify();
  }

  Future<void> recognizeFiles(List<String> ids) {
    if (ocrRunning || repository.readOnly || !hasWorkspace) {
      return Future.value();
    }
    final token = ++_ocrGeneration;
    ocrRunning = true;
    _ocrWork = _recognizeFiles(ids.toSet().toList(), token);
    return _ocrWork!;
  }

  Future<void> _recognizeFiles(List<String> ids, int token) async {
    final vault = repository.workspaceId;
    bool current() =>
        _alive &&
        hasWorkspace &&
        repository.workspaceId == vault &&
        token == _ocrGeneration;
    try {
      for (final id in ids) {
        if (!current()) break;
        final source = find(id);
        if (source == null ||
            source.isReadOnly ||
            source.isDeleted ||
            source.typeId != 'orbit.file') {
          continue;
        }
        try {
          final existing = source.properties['ocr'];
          if (existing != null && OcrDocument.parse(existing) == null) {
            throw const FormatException(
              'Unsupported saved recognition; preserved without overwriting.',
            );
          }
          final path = source.properties['contentRef'];
          if (path is! String) throw StateError('No attachment source.');
          ocrStatus = '${source.title} · Verifying source';
          _ocrNotify();
          final bytes = await repository.readPdfSearchSource(path);
          final checksum = await runSearchWork(
            () => sha256.convert(bytes).toString(),
            size: bytes.length,
          );
          if (!current()) break;
          final pages = <Map<String, dynamic>>[];
          var language = '', characters = 0;
          int? expectedTotal;
          await for (final result in _extractOcr(
            bytes,
            objectKindLabel(source) == 'PDF',
          )) {
            if (_ocrResume != null) await _ocrResume!.future;
            if (!current()) break;
            if (result['total'] != null) {
              if (result['total'] is! int ||
                  result['total'] <= 0 ||
                  expectedTotal != null && expectedTotal != result['total']) {
                throw const FormatException(
                  'Inconsistent recognition page count.',
                );
              }
              expectedTotal = result['total'] as int;
            }
            final page = <String, dynamic>{
              'text': result['text'],
              'lines': result['lines'],
            };
            if (page['text'] is! String) {
              throw const FormatException('Invalid recognition response.');
            }
            characters += (page['text'] as String).length;
            if (characters > OcrDocument.maxCharacters ||
                pages.length >= OcrDocument.maxPages) {
              throw const FormatException(
                'Recognition exceeds the 500-page / 2 Mi-character limit.',
              );
            }
            language = result['language'] as String? ?? '';
            pages.add(page);
            ocrStatus =
                '${source.title} · ${pages.length}${result['total'] == null ? '' : '/${result['total']}'} pages recognized';
            _ocrNotify();
            if (_ocrResume != null) await _ocrResume!.future;
          }
          if (!current()) break;
          if (expectedTotal != null && pages.length != expectedTotal) {
            throw const FormatException(
              'Incomplete recognition. Previous saved text is preserved.',
            );
          }
          final prior = OcrDocument.parse(existing);
          if (prior?.checksum == checksum &&
              prior?.path == path &&
              prior?.pages.length == pages.length) {
            for (var p = 0; p < pages.length; p++) {
              pages[p] = {...prior!.pages[p], ...pages[p]};
              if (prior.pages[p]['corrected'] != null) {
                pages[p]['corrected'] = prior.pages[p]['corrected'];
              }
            }
          }
          final record = OcrDocument(path, checksum, language, pages);
          if (!identical(find(id), source) ||
              await repository.pdfSourceChecksum(path) != checksum) {
            throw StateError(
              'The file changed during recognition. Retry with its current source.',
            );
          }
          if (!current()) break;
          if (!await _commitProductivity(source, {
            'ocr': {...?existing as Map?, ...record.toJson()},
          })) {
            throw StateError(error ?? 'Recognition could not be saved. Retry.');
          }
          ocrFailures.remove(id);
        } on Object catch (e) {
          if (current()) ocrFailures[id] = '$e';
        }
      }
    } finally {
      ocrRunning = false;
      ocrPaused = false;
      if (_ocrResume != null) {
        _ocrResume!.complete();
        _ocrResume = null;
      }
      ocrStatus = current()
          ? (ocrFailures.isEmpty
                ? 'Recognition finished. Review the text against its source.'
                : 'Recognition finished with errors. Failed files can be retried.')
          : 'Recognition cancelled. Previously saved text is unchanged.';
      _ocrNotify();
    }
  }

  Future<bool> correctRecognition(
    UniversalObject expected,
    int page,
    String? text,
  ) async {
    final record = OcrDocument.parse(expected.properties['ocr']);
    if (record == null || page < 0 || page >= record.pages.length) return false;
    final pages = [for (final p in record.pages) Map<String, dynamic>.from(p)];
    pages[page].remove('corrected');
    if (text != null && text != pages[page]['text']) {
      pages[page]['corrected'] = text;
    }
    try {
      final changed = OcrDocument(
        record.path,
        record.checksum,
        record.language,
        pages,
      );
      return _commitProductivity(expected, {
        'ocr': {...expected.properties['ocr'] as Map, ...changed.toJson()},
      });
    } on Object catch (e) {
      error = '$e';
      _ocrNotify();
      return false;
    }
  }

  Future<UniversalObject?> createRecognitionNote(
    UniversalObject expected,
    int page,
    String text,
  ) async {
    final record = OcrDocument.parse(expected.properties['ocr']);
    if (record == null ||
        page < 0 ||
        page >= record.pages.length ||
        text.trim().isEmpty ||
        !identical(find(expected.id), expected) ||
        repository.readOnly ||
        expected.isReadOnly) {
      return null;
    }
    final vault = repository.workspaceId;
    if (await repository.pdfSourceChecksum(record.path) != record.checksum ||
        repository.workspaceId != vault ||
        !identical(find(expected.id), expected)) {
      error =
          'The source changed. Recognize again before extracting a passage.';
      _ocrNotify();
      return null;
    }
    return create(
      'orbit.note',
      title: '${expected.title} — recognized passage',
      body:
          '${ObjectReference(expected.id, page: page + 1).quoteMarkdown(expected.title, text)}\nRecognized locally; verify against the original.\n',
      properties: {
        'folder': expected.properties['folder'] ?? 'Notes',
        'ocrSourceId': expected.id,
        if (objectKindLabel(expected) == 'PDF')
          'pdfSource': {
            'objectId': expected.id,
            'page': page + 1,
            'checksum': record.checksum,
          },
        'sourceChecksum': record.checksum,
        'sourcePage': page + 1,
        if (expected.properties['project'] != null)
          'project': expected.properties['project'],
      },
    );
  }
}
