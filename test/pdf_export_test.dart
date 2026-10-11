import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/export/pdf_export_service.dart';
import 'package:orbit_note/features/notes/latex/latex_document.dart';
import 'package:orbit_note/features/notes/latex/latex_templates.dart';

void main() {
  group('PdfExportService', () {
    test('generates valid %PDF-1.4 file from LaTeX document', () {
      final doc = LatexDocument.fromLatex(LatexTemplates.assignment.content);
      final pdfBytes = PdfExportService.generateLatexPdf(doc);

      expect(pdfBytes.isNotEmpty, isTrue);

      // Verify PDF header
      final header = utf8.decode(pdfBytes.sublist(0, 8));
      expect(header, startsWith('%PDF-1.4'));

      // Verify PDF trailer and EOF
      final tail = utf8.decode(pdfBytes.sublist(pdfBytes.length - 30));
      expect(tail, contains('%%EOF'));
      expect(tail, contains('startxref'));
    });

    test('generates valid %PDF-1.4 file from Markdown document', () {
      final pdfBytes = PdfExportService.generateMarkdownPdf(
        title: 'Meeting Notes',
        body: '''
# Project Status
Everything on track.

## Objectives
- Deploy LaTeX authoring
- Verify pure Dart PDF export

\$\$
\\sum_{i=1}^n i = \\frac{n(n+1)}{2}
\$\$
''',
      );

      expect(pdfBytes.isNotEmpty, isTrue);
      final header = utf8.decode(pdfBytes.sublist(0, 8));
      expect(header, startsWith('%PDF-1.4'));
      final tail = utf8.decode(pdfBytes.sublist(pdfBytes.length - 30));
      expect(tail, contains('%%EOF'));
    });
  });
}
