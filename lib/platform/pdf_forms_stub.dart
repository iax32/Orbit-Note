import 'dart:typed_data';
import 'package:pdfrx/pdfrx.dart';
import '../domain/pdf_form_field.dart';

Future<List<OrbitPdfField>> readPdfFields(
  PdfDocument document,
  int page,
) async => [];
Future<Uint8List> applyPdfFields(
  PdfDocument document,
  Map<String, dynamic> values,
) async {
  throw UnsupportedError(
    'PDF form export is currently available on native platforms.',
  );
}
