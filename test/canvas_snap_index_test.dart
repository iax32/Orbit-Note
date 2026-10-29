import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/equal_spacing.dart';
import 'package:orbit_note/canvas/snap_index.dart';

void main() {
  test(
    'alignment preserves global targets, original tie order and live connector bounds',
    () {
      final index = CanvasSnapIndex([
        const CanvasSnapTarget('first', CanvasBounds(100, 50000, 20, 20)),
        const CanvasSnapTarget('tie', CanvasBounds(102, -50000, 20, 20)),
        const CanvasSnapTarget(
          'connector',
          CanvasBounds(500, 500, 50, 50),
          dynamic: true,
          spacing: false,
        ),
      ]);
      expect(
        index.alignment(
          const CanvasBounds(101, 0, 0, 3),
          vertical: false,
          tolerance: 2,
        ),
        (delta: -1.0, position: 100.0),
      );
      expect(
        index.alignment(
          const CanvasBounds(300, 300, 20, 20),
          vertical: false,
          tolerance: 1,
          live: {'connector': const CanvasBounds(301, 900, 50, 50)},
        ),
        (delta: 1.0, position: 301.0),
      );
      expect(
        index.alignment(
          const CanvasBounds(700, 700, 20, 20),
          vertical: false,
          tolerance: 1,
        ),
        isNull,
      );
    },
  );
  test(
    'indexed spacing exactly matches existing semantics across mixed rows and columns',
    () {
      final random = Random(1908);
      final targets = [
        for (var i = 0; i < 400; i++)
          CanvasSnapTarget(
            '$i',
            CanvasBounds(
              random.nextInt(1000).toDouble(),
              random.nextInt(1000).toDouble(),
              10 + random.nextInt(70).toDouble(),
              10 + random.nextInt(70).toDouble(),
            ),
            spacing: i % 7 != 0,
          ),
      ];
      final index = CanvasSnapIndex(targets);
      for (var i = 0; i < 120; i++) {
        final moving = CanvasBounds(
          random.nextInt(1000).toDouble(),
          random.nextInt(1000).toDouble(),
          40,
          40,
        );
        for (final vertical in [false, true]) {
          final expected = equalCanvasSpacing(
            moving,
            targets.where((t) => t.spacing).map((t) => t.bounds),
            vertical: vertical,
            tolerance: 8,
          );
          final actual = index.spacing(
            moving,
            vertical: vertical,
            tolerance: 8,
          );
          expect(actual == null, expected == null);
          if (actual != null && expected != null) {
            expect(
              [
                actual.delta,
                actual.position,
                actual.before,
                actual.after,
                actual.gap,
              ],
              [
                expected.delta,
                expected.position,
                expected.before,
                expected.after,
                expected.gap,
              ],
            );
          }
        }
      }
    },
  );
  test(
    'duplicate alignment coordinates retain the first target at either side of a query',
    () {
      final index = CanvasSnapIndex([
        const CanvasSnapTarget('a', CanvasBounds(10, 0, 10, 10)),
        const CanvasSnapTarget('b', CanvasBounds(0, 0, 10, 10)),
      ]);
      expect(
        index.alignment(
          const CanvasBounds(12, 1000, 1, 1),
          vertical: false,
          tolerance: 4,
        ),
        (delta: -2.0, position: 10.0),
      );
    },
  );
}
