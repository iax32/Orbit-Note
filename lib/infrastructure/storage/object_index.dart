import '../../domain/universal_object.dart';

abstract interface class ObjectIndex {
  Future<void> initialize(String location);
  Future<void> replaceAll(List<UniversalObject> objects);
  Future<void> upsert(UniversalObject object);
  Future<List<String>> search(String query);
  Future<void> close();
}
