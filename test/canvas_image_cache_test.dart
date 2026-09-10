import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/canvas/canvas_images.dart';

void main() {
  testWidgets('dense image viewport has a bounded stable decode set', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(
        recorder,
      ).drawRect(const ui.Rect.fromLTWH(0, 0, 2, 2), ui.Paint());
      final picture = recorder.endRecording();
      final image = await picture.toImage(2, 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      var loads = 0;
      final cache = CanvasImageCache(
        loader: (_) async {
          loads++;
          return data!.buffer.asUint8List();
        },
        onChanged: () {},
      );
      final refs = List.generate(40, (i) => 'Attachments/$i.png');
      try {
        for (var i = 0; i < 30; i++) {
          cache.updateVisible(refs);
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(cache.images.length, 24);
        expect(loads, 24);
        for (var i = 0; i < 20; i++) {
          cache.updateVisible(refs.skip(24));
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(cache.images.length, lessThanOrEqualTo(24));
        expect(loads, 40);
        expect(cache.images.containsKey('Attachments/39.png'), isTrue);
      } finally {
        cache.dispose();
      }
    });
  });
}
