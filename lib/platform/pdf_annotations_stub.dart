import 'dart:typed_data';
import '../domain/pdf_annotation.dart';

Future<Uint8List> exportPdfAnnotations(
  Uint8List source,
  String fileId,
  String checksum,
  List<PdfAnnotation> annotations,
) async =>
    throw UnsupportedError('Annotated PDF export requires a native platform.');
