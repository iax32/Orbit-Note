import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> prepareCapture(WidgetTester tester) async {
  if (!const bool.fromEnvironment('ORBIT_CAPTURE_UI') || !Platform.isWindows) {
    return;
  }
  await tester.runAsync(() async {
    for (final font in {
      'Segoe UI': 'segoeui.ttf',
      'monospace': 'consola.ttf',
    }.entries) {
      final loader = FontLoader(font.key)
        ..addFont(
          File(
            'C:/Windows/Fonts/${font.value}',
          ).readAsBytes().then((v) => v.buffer.asByteData()),
        );
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
}

Future<void> captureUi(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('ORBIT_CAPTURE_UI')) return;
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await Directory('work/ui').create(recursive: true);
    await File('work/ui/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  });
}
