import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';

void main() {
  testWidgets('all ink nibs retain exact pressure, grain and overlap pixels', (
    tester,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const styles = [
      'ballpoint',
      'fountain',
      'marker',
      'pencil',
      'calligraphy',
      'brush',
      'highlighter',
    ];
    for (var row = 0; row < styles.length; row++) {
      for (var variant = 0; variant < 3; variant++) {
        final ink = CanvasElement({
          'id': '$row-$variant',
          'type': 'ink',
          'x': 12 + variant * 170,
          'y': 12 + row * 58,
          'color': 0xff7046d1,
          'strokeWidth': 9,
          'penStyle': styles[row],
          'isHighlighter': styles[row] == 'highlighter',
          'points': [
            for (var i = 0; i < 40; i++)
              {
                'x': i * 3.5,
                'y': (i % 8 < 4 ? i % 4 : 4 - i % 4) * 5.0,
                if (variant != 0) 'pressure': 0.15 + (i % 11) / 13,
              },
          ],
        });
        OrbitCanvasPainter.paintInk(canvas, ink, Color(ink.color));
        if (variant == 2) {
          OrbitCanvasPainter.paintInk(
            canvas,
            ink.translated(const CanvasPoint(0, 4)),
            Color(ink.color),
            startSegment: 5,
            endSegment: 28,
          );
        }
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(530, 430);
    try {
      await expectLater(
        image,
        matchesGoldenFile('goldens/ink-pressure-before.png'),
      );
    } finally {
      image.dispose();
      picture.dispose();
    }
  });
}
