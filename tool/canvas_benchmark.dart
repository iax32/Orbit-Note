import 'dart:convert';
import 'dart:io';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';

void main() {
  final results = <Map<String, Object>>[];
  for (final count in [10000, 100000]) {
    final data = {
      'schemaVersion': 1,
      'elements': List.generate(
        count,
        (i) => {
          'id': 'item-$i',
          'type': 'rectangle',
          'x': (i % 1000) * 180.0,
          'y': (i ~/ 1000) * 120.0,
          'width': 140.0,
          'height': 80.0,
        },
      ),
    };
    final watch = Stopwatch()..start();
    final scene = CanvasScene.fromJson(data);
    final loadMs = watch.elapsedMicroseconds / 1000;
    final samples = <int>[];
    var visible = 0;
    for (var i = 0; i < 1100; i++) {
      watch
        ..reset()
        ..start();
      visible = scene
          .query(CanvasBounds((i % 50) * 500.0, 240, 1600, 1000))
          .length;
      final elapsed = watch.elapsedMicroseconds;
      if (i >= 100) samples.add(elapsed);
    }
    samples.sort();
    watch
      ..reset()
      ..start();
    for (var i = 0; i < 1000; i++) {
      scene.put(
        CanvasElement({
          'id': 'new-$i',
          'type': 'rectangle',
          'x': i * 20.0,
          'y': 0.0,
          'width': 10.0,
          'height': 10.0,
        }),
      );
    }
    final insertMs = watch.elapsedMicroseconds / 1000;
    watch
      ..reset()
      ..start();
    final bytes = jsonEncode(scene.toJson()).length;
    results.add({
      'elements': count,
      'loadMs': loadMs,
      'queryMedianUs': samples[500],
      'queryP95Us': samples[950],
      'visibleLastQuery': visible,
      'insert1000Ms': insertMs,
      'snapshotMs': watch.elapsedMicroseconds / 1000,
      'snapshotCharacters': bytes,
    });
  }
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(results));
}
