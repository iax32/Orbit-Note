import '../../domain/universal_object.dart';
import '../../domain/search_text.dart';
import 'object_index.dart';

ObjectIndex createObjectIndex() => MemoryObjectIndex();

/// Rebuildable browser query index; canonical content lives in WorkspaceStore.
class MemoryObjectIndex implements ObjectIndex, PdfTextCache {
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
  Future<void> replaceAll(List<UniversalObject> objects) async {
    _text.clear();
    for (final object in objects) {
      _text[object.id] = searchableText(object).toLowerCase();
    }
    _objects
      ..clear()
      ..addEntries(objects.map((o) => MapEntry(o.id, o)));
  }

  @override
  Future<void> upsert(UniversalObject object) async {
    _objects[object.id] = object;
    _text[object.id] = searchableText(object).toLowerCase();
  }

  @override
  Future<List<String>> search(String query) async {
    final term = query.toLowerCase();
    return _objects.values
        .where((o) => !o.isDeleted && (_text[o.id]?.contains(term) ?? false))
        .map((o) => o.id)
        .toList();
  }

  @override
  Future<void> close() async {}
}
