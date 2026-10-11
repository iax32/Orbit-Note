import '../../domain/universal_object.dart';

abstract interface class ObjectIndex {
  Future<void> initialize(String location);
  Future<void> replaceAll(List<UniversalObject> objects);
  Future<void> upsert(UniversalObject object);
  Future<List<String>> search(String query);
  Future<void> close();
}

/// Optional disposable PDF cache. Older/test indexes retain their API.
abstract interface class PdfTextCache {
  Future<Map<String, dynamic>?> readPdfText(String id);
  Future<void> writePdfText(String id, Map<String, dynamic> document);
  Future<void> removePdfText(String id);
}
