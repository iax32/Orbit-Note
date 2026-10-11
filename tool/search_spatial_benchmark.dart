// CPU diagnostics only; not a whole-app FPS benchmark.
// ignore_for_file: avoid_print
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/domain/orbit_search.dart';
import 'package:orbit_note/domain/universal_object.dart';

void main() {
  for (final count in [1000, 5000, 10000]) {
    final index = CanvasSpatialIndex();
    final bounds = <String, CanvasBounds>{};
    for (var i = 0; i < count; i++) {
      bounds['$i'] = CanvasBounds((i % 100) * 250, (i ~/ 100) * 180, 180, 100);
      index.put('$i', bounds['$i']!);
    }
    const view = CanvasBounds(0, 0, 1000, 720);
    final expected = bounds.entries
        .where((e) => e.value.intersects(view))
        .map((e) => e.key)
        .toSet();
    final actual = index.query(view);
    if (actual.length != expected.length || !actual.containsAll(expected)) {
      throw StateError('Index disagrees with brute force');
    }
    final candidates = index.lastCandidateCount;
    final indexed = Stopwatch()..start();
    var checksum = 0;
    for (var i = 0; i < 300; i++) {
      checksum += index.query(view).length;
    }
    indexed.stop();
    final brute = Stopwatch()..start();
    for (var i = 0; i < 300; i++) {
      checksum += bounds.values.where((b) => b.intersects(view)).length;
    }
    brute.stop();
    print(
      '$count bounds: $candidates index candidates vs $count linear; '
      '300 queries indexed=${indexed.elapsedMicroseconds}us linear=${brute.elapsedMicroseconds}us checksum=$checksum',
    );
    final objects = [
      for (var i = 0; i < count; i++)
        UniversalObject(
          id: '$i',
          workspaceId: 'w',
          typeId: 'orbit.note',
          title: 'Note $i',
          body: 'A paragraph about partition $i.\n',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
    ];
    final search = Stopwatch()..start();
    final results = const OrbitSearchCoordinator().project(
      objects,
      'partition',
    );
    search.stop();
    print(
      '$count candidate documents: rich projection=${search.elapsedMicroseconds}us, ${results.length} bounded results. '
      'Projection stress only, excludes SQLite and isolate startup.',
    );
  }
}
