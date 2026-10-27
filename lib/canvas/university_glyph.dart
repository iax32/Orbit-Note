import 'geometry.dart';
import 'scene.dart';
import 'uml_interaction.dart';

bool isUniversityItem(CanvasElement e) =>
    e.data['universityNode'] is Map ||
    e.data['universityEdge'] is String ||
    e.data['universityModel'] is Map ||
    e.data['universityKey'] is String;

bool isUniversityGlyph(CanvasElement e) =>
    e.data['universityNode'] is Map &&
    e.data['uml'] is! Map &&
    e.data['umlNode'] is! Map;
UmlGlyph universityGlyph(CanvasElement e) {
  final glyph = UmlGlyph(),
      b = e.bounds,
      meta = e.data['universityNode'] as Map;
  final kind = meta['kind'];
  void text(
    String value,
    CanvasBounds bounds, {
    bool bold = false,
    bool center = true,
  }) => glyph.texts.add((
    text: value,
    bounds: bounds,
    size: 14,
    bold: bold,
    center: center,
  ));
  if ({'start', 'final', 'flowFinal', 'initial'}.contains(kind)) {
    final diameter = b.width < b.height ? b.width : b.height;
    if (kind == 'start' || kind == 'initial') {
      glyph.solidOvals.add(
        CanvasBounds(b.center.x - 8, b.center.y - 8, 16, 16),
      );
    } else {
      glyph.ovals.add((
        bounds: CanvasBounds(
          b.center.x - diameter / 2,
          b.center.y - diameter / 2,
          diameter,
          diameter,
        ),
        fill: true,
      ));
      if (kind == 'final') {
        glyph.solidOvals.add(
          CanvasBounds(
            b.center.x - diameter * .3,
            b.center.y - diameter * .3,
            diameter * .6,
            diameter * .6,
          ),
        );
      } else {
        glyph.paths.add((
          points: [
            CanvasPoint(b.left + 8, b.top + 8),
            CanvasPoint(b.right - 8, b.bottom - 8),
          ],
          dashed: false,
        ));
        glyph.paths.add((
          points: [
            CanvasPoint(b.right - 8, b.top + 8),
            CanvasPoint(b.left + 8, b.bottom - 8),
          ],
          dashed: false,
        ));
      }
    }
    return glyph;
  }
  if ({'fork', 'join'}.contains(kind)) {
    glyph.solidBoxes.add(b);
    return glyph;
  }
  if ({'decision', 'merge', 'nary'}.contains(kind)) {
    glyph.paths.add((
      points: [
        CanvasPoint(b.center.x, b.top),
        CanvasPoint(b.right, b.center.y),
        CanvasPoint(b.center.x, b.bottom),
        CanvasPoint(b.left, b.center.y),
        CanvasPoint(b.center.x, b.top),
      ],
      dashed: false,
    ));
    text(
      e.text,
      CanvasBounds(
        b.left + b.width * .22,
        b.top + b.height * .25,
        b.width * .56,
        b.height * .5,
      ),
    );
    return glyph;
  }
  glyph.boxes.add((bounds: b, fill: true));
  final lines = e.text.split('\n');
  text(
    lines.first,
    CanvasBounds(b.left + 10, b.top + 6, b.width - 20, 30),
    bold: true,
  );
  if (lines.length > 1) {
    glyph.paths.add((
      points: [
        CanvasPoint(b.left, b.top + 40),
        CanvasPoint(b.right, b.top + 40),
      ],
      dashed: false,
    ));
    text(
      lines.skip(1).join('\n'),
      CanvasBounds(
        b.left + 10,
        b.top + 46,
        b.width - 20,
        meta['composite'] == true ? 84 : b.height - 54,
      ),
      center: false,
    );
  }
  return glyph;
}
