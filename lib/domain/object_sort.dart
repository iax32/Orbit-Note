import 'universal_object.dart';

const objectSortLabels = {
  'name-asc': 'Name A–Z',
  'name-desc': 'Name Z–A',
  'modified-desc': 'Recently modified',
  'modified-asc': 'Oldest modified',
  'created-desc': 'Recently created',
  'created-asc': 'Oldest created',
};
void sortObjects(List<UniversalObject> objects, String order) {
  objects.sort((a, b) {
    final comparison = order.startsWith('name')
        ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
        : order.startsWith('created')
        ? a.createdAt.compareTo(b.createdAt)
        : a.updatedAt.compareTo(b.updatedAt);
    return comparison == 0
        ? a.id.compareTo(b.id)
        : order.endsWith('desc')
        ? -comparison
        : comparison;
  });
}
