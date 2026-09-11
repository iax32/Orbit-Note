import 'dart:convert';
import 'dart:typed_data';

/// A real two-page PDF with extractable text; no downloaded sample or generator.
Uint8List researchPdf() {
  const a = 'BT /F1 18 Tf 40 200 Td (Orbit research page one) Tj ET';
  const b = 'BT /F1 18 Tf 40 200 Td (Orbit research page two) Tj ET';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R 6 0 R] /Count 2 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 300] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Length ${a.length} >>\nstream\n$a\nendstream',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 300] /Resources << /Font << /F1 4 0 R >> >> /Contents 7 0 R >>',
    '<< /Length ${b.length} >>\nstream\n$b\nendstream',
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
