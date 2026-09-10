import '../../domain/universal_object.dart';
import '../../domain/search_text.dart';
import 'object_index.dart';

ObjectIndex createObjectIndex() => MemoryObjectIndex();

/// Rebuildable browser query index; canonical content lives in WorkspaceStore.
class MemoryObjectIndex implements ObjectIndex {
  final _objects = <String, UniversalObject>{};
  @override
  Future<void> initialize(String location) async {}
  @override
  Future<void> replaceAll(List<UniversalObject> objects) async {
    _objects
      ..clear()
      ..addEntries(objects.map((o) => MapEntry(o.id, o)));
  }

  @override
  Future<void> upsert(UniversalObject object) async {
    _objects[object.id] = object;
  }

  @override
  Future<List<String>> search(String query) async {
    final term = query.toLowerCase();
    return _objects.values
        .where(
          (o) => !o.isDeleted && searchableText(o).toLowerCase().contains(term),
        )
        .map((o) => o.id)
        .toList();
  }

  @override
  Future<void> close() async {}
}
