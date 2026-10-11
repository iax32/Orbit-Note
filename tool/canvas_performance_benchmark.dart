// Standalone benchmark intentionally writes its measurements to stdout.
// ignore_for_file: avoid_print
import 'package:orbit_note/canvas/scene.dart';

// CPU microbenchmark, not an end-to-end frame-rate claim.
void main() {
  for (final count in [1000, 10000, 100000]) {
    final scene = CanvasScene.fromJson({
      'schemaVersion': 1,
      'elements': [
        for (var i = 0; i < count; i++)
          {
            'id': 'n$i',
            'type': 'rectangle',
            'x': (i % 100) * 250.0,
            'y': (i ~/ 100) * 180.0,
            'width': 180.0,
            'height': 100.0,
          },
        {'id': 'edge', 'type': 'connector', 'startId': 'n0', 'endId': 'n1'},
      ],
    });
    for (var i = 0; i < 50; i++) {
      scene.put(scene['n0']!.copy({'x': i.toDouble()}));
    }
    final watch = Stopwatch()..start();
    for (var i = 0; i < 300; i++) {
      scene.put(scene['n0']!.copy({'x': i.toDouble()}));
    }
    watch.stop();
    print(
      '$count elements: 300 connected-item moves = '
      '${watch.elapsedMicroseconds / 1000} ms',
    );
    final boundsWatch = Stopwatch()..start();
    var checksum = 0.0;
    for (var i = 0; i < 100; i++) {
      checksum += scene.contentBounds!.width;
    }
    boundsWatch.stop();
    print(
      '$count elements: 100 content-bounds reads = '
      '${boundsWatch.elapsedMicroseconds / 1000} ms ($checksum)',
    );
  }
}
