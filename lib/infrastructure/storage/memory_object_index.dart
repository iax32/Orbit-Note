import '../../domain/universal_object.dart';
import '../../domain/search_text.dart';
import 'object_index.dart';

ObjectIndex createObjectIndex() => MemoryObjectIndex();

/// Rebuildable browser query index; canonical content lives in WorkspaceStore.
class MemoryObjectIndex implements ObjectIndex, PdfTextCache {
  Future<void> _writes = Future.value();
  Future<void> _write(Future<void> Function() operation) {
    final next = _writes.then((_) => operation());
    _writes = next.catchError((Object _) {});
    return next;
  }

  final _pdfText = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> readPdfText(String id) async => _pdfText[id];
  @override
  Future<void> writePdfText(String id, Map<String, dynamic> document) async =>
      _pdfText[id] = document;
  @override
  Future<void> removePdfText(String id) async => _pdfText.remove(id);
  final _objects = <String, UniversalObject>{};
  final _text = <String, String>{};
  @override
  Future<void> initialize(String location) async {}
  @override
  Future<void> replaceAll(List<UniversalObject> objects) {
    final snapshot = List<UniversalObject>.of(objects);
    return _write(() async {
      final text = <String, String>{};
      final snapshots = <String, UniversalObject>{};
      final slice = Stopwatch()..start();
      for (final object in snapshot) {
        text[object.id] = searchableText(object).toLowerCase();
        snapshots[object.id] = object;
        if (slice.elapsedMilliseconds >= 4) {
          await Future<void>.delayed(Duration.zero);
          slice.reset();
        }
      }
      // Publish atomically after successful preparation. Failed rebuilds
      // must not leave old objects paired with a partially cleared search map.
      _text
        ..clear()
        ..addAll(text);
      _objects
        ..clear()
        ..addAll(snapshots);
    });
  }

  @override
  Future<void> upsert(UniversalObject object) => _write(() async {
    final text = searchableText(object).toLowerCase();
    _objects[object.id] = object;
    _text[object.id] = text;
  });

  @override
  Future<List<String>> search(String query) async {
    final term = query.toLowerCase();
    return _objects.values
        .where((o) => !o.isDeleted && (_text[o.id]?.contains(term) ?? false))
        .map((o) => o.id)
        .toList();
  }

  @override
  Future<void> close() => _writes;
}
