import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:pdfrx/pdfrx.dart';

bool? _pdfiumReady;

/// Initializes Pdfrx and locates the PDFium dynamic library if available.
/// Returns true if native PDFium is ready for rendering or PDF inspection.
Future<bool> initPdfTesting() async {
  if (_pdfiumReady != null) return _pdfiumReady!;

  try {
    final cache = await Directory(
      '.local/pdf-test-cache',
    ).create(recursive: true);
    Pdfrx.cacheDirectoryPath = cache.absolute.path;

    if (Platform.isLinux && Pdfrx.pdfiumModulePath == null) {
      final candidates = [
        Platform.environment['PDFIUM_PATH'],
        '${Directory.current.path}/.local/lib/libpdfium.so',
        '${Directory.current.path}/.local/libpdfium.so',
        '/usr/local/lib/libpdfium.so',
        '/usr/lib/libpdfium.so',
        '${File(Platform.resolvedExecutable).parent.path}/lib/libpdfium.so',
        '${File(Platform.resolvedExecutable).parent.path}/libpdfium.so',
      ];
      for (final candidate in candidates) {
        if (candidate != null && File(candidate).existsSync()) {
          Pdfrx.pdfiumModulePath = File(candidate).absolute.path;
          break;
        }
      }
    } else if (Platform.isWindows && Pdfrx.pdfiumModulePath == null) {
      final candidates = [
        Platform.environment['PDFIUM_PATH'],
        '${Directory.current.path}/build/native_assets/windows/pdfium.dll',
        '${Directory.current.path}/build/windows/x64/runner/Release/pdfium.dll',
      ];
      for (final candidate in candidates) {
        if (candidate != null && File(candidate).existsSync()) {
          Pdfrx.pdfiumModulePath = File(candidate).absolute.path;
          break;
        }
      }
    }

    await pdfrxFlutterInitialize();
    _pdfiumReady = true;
  } catch (_) {
    _pdfiumReady = false;
  }
  return _pdfiumReady!;
}

/// A real two-page PDF with extractable text; no downloaded sample or generator.
Uint8List researchPdf({bool illustrated = false}) {
  final a =
      'BT /F1 18 Tf 40 200 Td (Orbit research page one) Tj ET'
      '${illustrated ? ' q 40 0 0 40 340 100 cm /Im1 Do Q 40 40 280 80 re S 40 80 m 320 80 l S 180 40 m 180 120 l S' : ''}';
  const b = 'BT /F1 18 Tf 40 200 Td (Orbit research page two) Tj ET';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R 6 0 R] /Count 2 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 300] /Resources << /Font << /F1 4 0 R >> ${illustrated ? '/XObject << /Im1 8 0 R >>' : ''} >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Length ${a.length} >>\nstream\n$a\nendstream',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 300] /Resources << /Font << /F1 4 0 R >> >> /Contents 7 0 R >>',
    '<< /Length ${b.length} >>\nstream\n$b\nendstream',
    if (illustrated)
      '<< /Type /XObject /Subtype /Image /Width 2 /Height 2 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /ASCIIHexDecode /Length 25 >>\nstream\nff000000ff000000ffffffff>\nendstream',
  ];
  final pdf = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(pdf.length);
    pdf.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xref = pdf.length;
  pdf.write('xref\n0 ${offsets.length}\n0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    pdf.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  pdf.write(
    'trailer\n<< /Size ${offsets.length} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n',
  );
  return Uint8List.fromList(ascii.encode(pdf.toString()));
}

Uint8List formPdf() {
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R /AcroForm 4 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 300] /Annots [5 0 R 6 0 R] /Resources << /Font << /Helv 7 0 R >> >> >>',
    '<< /Fields [5 0 R 6 0 R] /DA (/Helv 12 Tf 0 g) /DR << /Font << /Helv 7 0 R >> >> >>',
    '<< /Type /Annot /Subtype /Widget /FT /Tx /T (Name) /V (Original) /Rect [40 200 240 230] /P 3 0 R /DA (/Helv 12 Tf 0 g) /F 4 >>',
    '<< /Type /Annot /Subtype /Widget /FT /Btn /T (Approved) /V /Off /AS /Off /Rect [40 150 60 170] /P 3 0 R /F 4 /AP << /N << /Off 8 0 R /Yes 9 0 R >> >> >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Type /XObject /Subtype /Form /BBox [0 0 20 20] /Length 0 >>\nstream\n\nendstream',
    '<< /Type /XObject /Subtype /Form /BBox [0 0 20 20] /Length 22 >>\nstream\n0 0 20 20 re 0 g f\n\nendstream',
  ];
  final pdf = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(pdf.length);
    pdf.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xref = pdf.length;
  pdf.write('xref\n0 ${offsets.length}\n0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    pdf.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  pdf.write(
    'trailer\n<< /Size ${offsets.length} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n',
  );
  return Uint8List.fromList(ascii.encode(pdf.toString()));
}
