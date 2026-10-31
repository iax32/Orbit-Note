import 'universal_object.dart';

const objectSortLabels = {
  'name-asc': 'Name A–Z',
  'name-desc': 'Name Z–A',
  'modified-desc': 'Recently modified',
  'modified-asc': 'Oldest modified',
  'created-desc': 'Recently created',
  'created-asc': 'Oldest created',
};
Comparator<UniversalObject> objectComparator(String order) {
  final name = order.startsWith('name'), created = order.startsWith('created');
  final descending = order.endsWith('desc');
  return (a, b) {
    final comparison = name
        ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
        : created
        ? a.createdAt.compareTo(b.createdAt)
        : a.updatedAt.compareTo(b.updatedAt);
    return comparison == 0
        ? a.id.compareTo(b.id)
        : descending
        ? -comparison
        : comparison;
  };
}

void sortObjects(List<UniversalObject> objects, String order) =>
    objects.sort(objectComparator(order));

/// A view-local sort projection. Immutable objects make changed identities a
/// complete invalidation signal. Mutable input lists are inspected every time.
/// Small edits update sorted positions without sorting an entire Vault again.
class ObjectSortCache {
  String? _order;
  Map<String, UniversalObject> _previous = const {};
  List<UniversalObject> _sorted = const [];
  bool _duplicates = false;
  List<UniversalObject> resolve(List<UniversalObject> objects, String order) {
    final next = <String, UniversalObject>{};
    final changed = <UniversalObject>[];
    for (final object in objects) {
      next[object.id] = object;
      if (!identical(_previous[object.id], object)) changed.add(object);
    }
    final duplicates = next.length != objects.length;
    final compare = objectComparator(order);
    if (_order != order || _duplicates || duplicates || changed.length > 32) {
      _sorted = List.unmodifiable(
        List<UniversalObject>.of(objects)..sort(compare),
      );
    } else if (changed.isNotEmpty || next.length != _previous.length) {
      final replaced = changed.map((o) => o.id).toSet();
      final result = [
        for (final object in _sorted)
          if (next.containsKey(object.id) && !replaced.contains(object.id))
            object,
      ];
      for (final object in changed) {
        var lo = 0, hi = result.length;
        while (lo < hi) {
          final mid = (lo + hi) ~/ 2;
          if (compare(result[mid], object) < 0) {
            lo = mid + 1;
          } else {
            hi = mid;
          }
        }
        result.insert(lo, object);
      }
      _sorted = List.unmodifiable(result);
    }
    _order = order;
    _previous = next;
    _duplicates = duplicates;
    return _sorted;
  }
}
