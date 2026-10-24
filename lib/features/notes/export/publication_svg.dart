import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_svg/flutter_svg.dart';

bool isPublicationSvg(Uint8List bytes) => RegExp(
  r'^(?:\ufeff)?\s*(?:<\?xml[^>]*>\s*)?(?:<!--[\s\S]*?-->\s*)*<svg(?:\s|>)',
  caseSensitive: false,
).hasMatch(utf8.decode(bytes.take(4096).toList(), allowMalformed: true));

/// Static diagrams only. No scripts, embedded/remote images, external CSS/fonts
/// or foreign HTML are evaluated or fetched while publishing a local document.
Future<Uint8List> renderPublicationSvg(Uint8List bytes) async {
  if (bytes.length > 2 * 1024 * 1024) {
    throw const FormatException('SVG exceeds the 2 MiB diagram limit.');
  }
  final source = utf8.decode(bytes);
  final externalReference =
      RegExp(
        r"""href\s*=\s*["']([^"']*)["']|url\(\s*([^)]*)\)""",
        caseSensitive: false,
      ).allMatches(source).any((match) {
        var value = (match[1] ?? match[2] ?? '').trim();
        if (value.startsWith('"') || value.startsWith("'")) {
          value = value.substring(1, value.length - 1).trim();
        }
        return !value.startsWith('#');
      });
  if (externalReference ||
      RegExp(
        r'<!DOCTYPE|<!ENTITY|<(?:[\w-]+:)?(?:script|image|foreignObject|filter|animate\w*|set)\b|@(?:import|font-face)|\bon\w+\s*=',
        caseSensitive: false,
      ).hasMatch(source)) {
    throw const FormatException(
      'SVG requires external or unsupported active content. Import a PNG preview instead.',
    );
  }
  final info = await vg.loadPicture(SvgStringLoader(source), null);
  try {
    final size = info.size;
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0 ||
        size.width * size.height > 100000000) {
      throw const FormatException(
        'SVG dimensions exceed the publishing limit.',
      );
    }
    final longest = size.width > size.height ? size.width : size.height;
    final scale = longest > 1600 ? 1600 / longest : 1.0;
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
      ..scale(scale)
      ..drawPicture(info.picture);
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(
        (size.width * scale).ceil().clamp(1, 1600),
        (size.height * scale).ceil().clamp(1, 1600),
      );
      try {
        final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  } finally {
    info.picture.dispose();
  }
}
