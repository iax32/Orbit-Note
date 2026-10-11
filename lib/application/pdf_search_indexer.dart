import 'dart:async';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../domain/pdf_search.dart';
import '../domain/orbit_search.dart';
import '../domain/universal_object.dart';
import '../domain/object_discovery.dart';
import '../domain/ocr_document.dart';
import 'workspace_repository.dart';
import 'search_execution.dart';

typedef PdfTextExtractor = Stream<PdfTextPage> Function(Uint8List bytes);

/// One serial worker per open Vault. Partial/failed documents never enter search.
/// Only disposable cache writes occur; original attachment metadata stays exact.
class PdfSearchIndexer {
  PdfSearchIndexer(
    this.repository, {
    required this.extract,
    required this.onChanged,
  });
  final WorkspaceRepository repository;
  final PdfTextExtractor extract;
  final void Function() onChanged;
  final _sources = <String, UniversalObject>{};
  final _keys = <String, String>{};
  final _versions = <String, int>{};
  final _queue = <String>{};
  final documents = <String, PdfTextDocument>{};
  final entries = <String, PdfIndexEntry>{};
  bool running = false, paused = false, _closed = false;
  Future<void>? _work;
  int revision = 0;

  void synchronize(List<UniversalObject> objects) {
    if (_closed) return;
    final sources = {
      for (final o in objects)
        if (!o.isDeleted &&
            o.typeId == 'orbit.file' &&
            (objectKindLabel(o) == 'PDF' || o.properties['ocr'] != null))
          o.id: o,
    };
    var changed = false;
    for (final id in _sources.keys.toList()) {
      if (sources.containsKey(id)) continue;
      _versions[id] = (_versions[id] ?? 0) + 1;
      _sources.remove(id);
      _keys.remove(id);
      _queue.remove(id);
      documents.remove(id);
      entries.remove(id);
      changed = true;
      unawaited(repository.removePdfTextCache(id).catchError((Object _) {}));
    }
    for (final o in sources.values) {
      final key =
          '${o.properties['contentRef']}|${o.properties['checksum']}|${o.properties['ocr'].hashCode}';
      _sources[o.id] = o;
      if (_keys[o.id] == key) continue;
      _keys[o.id] = key;
      _invalidate(o.id);
      changed = true;
    }
    if (changed) {
      revision++;
      onChanged();
    }
    _start();
  }

  void _invalidate(String id) {
    _versions[id] = (_versions[id] ?? 0) + 1;
    documents.remove(id);
    entries[id] = const PdfIndexEntry('Pending');
    _queue.add(id);
  }

  void invalidatePath(String path) {
    var changed = false;
    for (final o in _sources.values) {
      if (path != '*' && o.properties['contentRef'] != path) continue;
      _invalidate(o.id);
      changed = true;
    }
    if (changed) {
      revision++;
      onChanged();
      _start();
    }
  }

  void retry() {
    for (final id in _sources.keys) {
      if (entries[id]?.phase == 'Failed') _invalidate(id);
    }
    paused = false;
    onChanged();
    _start();
  }

  void setPaused(bool value) {
    paused = value;
    onChanged();
    if (!value) _start();
  }

  bool isCurrent(OrbitSearchResult result) =>
      result.sourceChecksum == null ||
      documents[result.object.id]?.checksum == result.sourceChecksum &&
          documents[result.object.id]?.path == result.sourcePath;
  void _start() {
    if (!_closed && !paused && !running && _queue.isNotEmpty) _work = _run();
  }

  Future<void> _run() async {
    running = true;
    onChanged();
    try {
      while (!_closed && !paused && _queue.isNotEmpty) {
        final id = _queue.first;
        _queue.remove(id);
        await _process(id);
        await Future<void>.delayed(Duration.zero);
      }
    } finally {
      running = false;
      if (!_closed) onChanged();
    }
  }

  Future<void> _process(String id) async {
    final object = _sources[id];
    if (object == null) return;
    final token = _versions[id];
    bool current() => !_closed && !paused && _versions[id] == token;
    void check() {
      if (!current()) throw const _Interrupted();
    }

    String? cacheWarning;
    try {
      final path = object.properties['contentRef'];
      if (path is! String) throw StateError('PDF has no attachment source.');
      entries[id] = const PdfIndexEntry('Verifying');
      onChanged();
      final checksum = await repository.pdfSourceChecksum(path);
      check();
      if (checksum == null) {
        throw StateError('PDF attachment is missing or unreadable.');
      }
      var document = await repository.readPdfTextCache(id);
      check();
      final recorded = OcrDocument.parse(object.properties['ocr']);
      final ocr = recorded?.path == path && recorded?.checksum == checksum
          ? recorded
          : null;
      if (objectKindLabel(object) != 'PDF') {
        document = PdfTextDocument(path, checksum, [ocr?.text(0) ?? '']);
      }
      if (document?.path != path || document?.checksum != checksum) {
        final bytes = await repository.readPdfSearchSource(path);
        check();
        final actual = await runSearchWork(
          () => sha256.convert(bytes).toString(),
          size: bytes.length,
        );
        check();
        if (actual != checksum) {
          throw StateError(
            'Source changed during verification. Retry indexing.',
          );
        }
        final pages = <String>[];
        var chars = 0;
        final progressClock = Stopwatch()..start();
        var lastProgress = -100;
        await for (final page in extract(bytes)) {
          check();
          if (page.number != pages.length + 1 || page.total < page.number) {
            throw StateError('Incomplete PDF extraction.');
          }
          chars += page.text.length;
          if (chars > PdfTextDocument.maxTextCharacters) {
            throw StateError(
              'Extracted PDF text exceeds the 32 Mi-character safety limit.',
            );
          }
          pages.add(page.text);
          entries[id] = PdfIndexEntry(
            'Indexing',
            pages: page.number,
            total: page.total,
          );
          if (progressClock.elapsedMilliseconds - lastProgress >= 100 ||
              page.number == page.total) {
            lastProgress = progressClock.elapsedMilliseconds;
            onChanged();
          }
        }
        check();
        if (pages.isEmpty || pages.length != entries[id]?.total) {
          throw StateError('Incomplete PDF extraction.');
        }
        if (await repository.pdfSourceChecksum(path) != checksum) {
          throw StateError('Source changed during extraction. Retry indexing.');
        }
        check();
        document = PdfTextDocument(path, checksum, List.unmodifiable(pages));
        try {
          await repository.writePdfTextCache(id, document);
        } on Object {
          cacheWarning =
              'Text is searchable for this session; the disk cache could not be saved.';
        }
        check();
      }
      if (await repository.pdfSourceChecksum(path) != checksum) {
        throw StateError('Source changed before publication. Retry indexing.');
      }
      check();
      final merged = List<String>.from(document!.pages);
      final recognizedPages = <int>{};
      if (ocr != null && ocr.pages.length == merged.length) {
        for (var p = 0; p < merged.length; p++) {
          if (ocr.pages[p]['corrected'] != null ||
              merged[p].trim().isEmpty ||
              objectKindLabel(object) != 'PDF') {
            merged[p] = ocr.text(p);
            recognizedPages.add(p);
          }
        }
      }
      document = PdfTextDocument(
        path,
        checksum,
        List.unmodifiable(merged),
        ocr: ocr,
        ocrPages: recognizedPages,
      );
      documents[id] = document;
      final blank = document.pages.where((p) => p.trim().isEmpty).length;
      final detail = [
        if (object.properties['ocr'] != null && ocr == null)
          'Saved recognition is unsupported or belongs to an older source. Review or recognize again.',
        if (recognizedPages.isNotEmpty)
          '${recognizedPages.length} pages use local recognition; check against the original. Corrections return to the page without claiming exact text geometry.',
        if (!document.hasText)
          ocr == null
              ? 'No extractable text; scanned pages need OCR.'
              : 'Recognition found no readable text. Try a clearer source or correct the page text.'
        else if (blank > 0)
          ocr == null
              ? '$blank/${document.pages.length} pages have no extractable text; scanned pages need OCR.'
              : '$blank/${document.pages.length} pages remain without readable text after recognition.',
        ?cacheWarning,
      ].join(' ');
      entries[id] = PdfIndexEntry(
        document.hasText ? 'Indexed' : 'No text',
        pages: document.pages.length,
        total: document.pages.length,
        unsearchablePages: blank,
        detail: detail.isEmpty ? null : detail,
      );
      revision++;
      onChanged();
    } on _Interrupted {
      if (!_closed && _sources.containsKey(id)) {
        _queue.add(id);
        entries[id] = const PdfIndexEntry('Pending');
      }
    } on Object catch (e) {
      if (!_closed && _versions[id] == token) {
        documents.remove(id);
        entries[id] = PdfIndexEntry('Failed', detail: e.toString());
        revision++;
        onChanged();
      }
    }
  }

  Future<void> close() async {
    _closed = true;
    _queue.clear();
    documents.clear();
    await _work;
  }
}

class _Interrupted implements Exception {
  const _Interrupted();
}
