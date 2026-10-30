import 'dart:typed_data';
import '../domain/pdf_annotation.dart';
import '../canvas/scene.dart';

Future<Uint8List> exportPdfAnnotations(
  Uint8List source,
  String fileId,
  String checksum,
  List<PdfAnnotation> annotations, {
  List<CanvasElement> ink = const [],
}) async =>
    throw UnsupportedError('Annotated PDF export requires a native platform.');
