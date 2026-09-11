import '../canvas/scene.dart';
import 'universal_object.dart';

/// Versioned text regions reuse Canvas rectangles in normalized page space.
class PdfAnnotation {
  PdfAnnotation(this.object);
  final UniversalObject object;
  Map get source => object.properties['pdfSource'] is Map
      ? object.properties['pdfSource'] as Map
      : const {};
  String? get checksum =>
      source['checksum'] is String ? source['checksum'] as String : null;
  String? get fileId =>
      source['objectId'] is String ? source['objectId'] as String : null;
  List<CanvasElement> get regions => source['regions'] is List
      ? (source['regions'] as List)
            .whereType<Map>()
            .map((v) => CanvasElement(Map<String, dynamic>.from(v)))
            .where(validRegion)
            .toList()
      : const [];
  bool matches(String? version) => version != null && checksum == version;
  static bool validRegion(CanvasElement e) =>
      e.renderable &&
      e.type == 'rectangle' &&
      e.data['page'] is int &&
      (e.data['page'] as int) > 0 &&
      (e.data['page'] as int) <= 999999 &&
      e.x >= 0 &&
      e.y >= 0 &&
      e.width > 0 &&
      e.height > 0 &&
      e.x + e.width <= 1.000001 &&
      e.y + e.height <= 1.000001;
  static bool isAnnotation(UniversalObject o) =>
      !o.isDeleted &&
      o.typeId == 'orbit.note' &&
      o.properties['pdfHighlightVersion'] == 1;
}
