import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:orbit_note/domain/object_sort.dart';
import 'package:orbit_note/domain/universal_object.dart';

UniversalObject item(int n) => UniversalObject(
  id: 'item-$n',
  workspaceId: 'fixture',
  typeId: 'orbit.note',
  title: 'Name ${n % 17}',
  createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: n % 13)),
  updatedAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: n % 23)),
  properties: {'future': n},
);
List<UniversalObject> reference(List<UniversalObject> input, String order) =>
    List<UniversalObject>.of(input)..sort((a, b) {
      final value = order.startsWith('name')
          ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
          : order.startsWith('created')
          ? a.createdAt.compareTo(b.createdAt)
          : a.updatedAt.compareTo(b.updatedAt);
      return value == 0
          ? a.id.compareTo(b.id)
          : order.endsWith('desc')
          ? -value
          : value;
    });
void main() {
  for (final order in objectSortLabels.keys) {
    test(
      'incremental $order matches full order through edits, remote replacement and deletion',
      () {
        final cache = ObjectSortCache();
        final source = List.generate(2000, item);
        void check() {
          final expected = reference(source, order);
          final result = cache.resolve(source, order);
          expect(result, orderedEquals(expected));
          expect(() => result.clear(), throwsUnsupportedError);
        }

        check();
        final unchanged = cache.resolve(source, order);
        expect(
          identical(unchanged, cache.resolve(List.of(source), order)),
          isTrue,
        );
        final clock = Stopwatch()..start();
        for (var i = 0; i < 40; i++) {
          final at = (i * 37) % source.length;
          source[at] = source[at].copyWith(
            title: 'Changed $i',
            updatedAt: DateTime.utc(2026, 2, i % 28 + 1),
          );
          check();
        }
        source.removeRange(10, 30);
        check();
        source.insert(11, item(9000));
        check();
        source.setAll(50, List.generate(80, (i) => item(10000 + i)));
        check();
        source.shuffle();
        check();
        expect(
          cache.resolve(source, 'name-desc'),
          orderedEquals(reference(source, 'name-desc')),
        );
        source.clear();
        expect(cache.resolve(source, order), isEmpty);
        // Diagnostic only; no hardware-dependent speed assertion.
        debugPrint(
          'sort $order: 40 edits/parity checks ${clock.elapsedMilliseconds}ms',
        );
      },
    );
  }
  test('duplicate IDs and caller mutations retain full-sort semantics', () {
    final cache = ObjectSortCache();
    final first = item(1), second = item(1).copyWith(title: 'Other');
    final source = [first, second, item(2)];
    expect(
      cache.resolve(source, 'name-asc'),
      orderedEquals(reference(source, 'name-asc')),
    );
    source.removeAt(1);
    expect(
      cache.resolve(source, 'name-asc'),
      orderedEquals(reference(source, 'name-asc')),
    );
    source.add(item(3));
    expect(
      cache.resolve(source, 'name-asc'),
      orderedEquals(reference(source, 'name-asc')),
    );
  });
}
