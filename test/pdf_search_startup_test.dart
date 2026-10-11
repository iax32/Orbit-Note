import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:orbit_note/platform/pdf_text_extraction.dart';
import 'support/pdf_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dll = File('build/native_assets/windows/pdfium.dll');
  test(
    'PDF indexing initializes its worker before a reader has ever opened',
    () async {
      // Configure the test DLL/cache without calling initPdfTesting or creating
      // a PdfViewer. The platform extractor must initialize pdfrx itself.
      Pdfrx.pdfiumModulePath = dll.absolute.path;
      final cache = await Directory(
        '.local/pdf-startup-test-cache',
      ).create(recursive: true);
      Pdfrx.cacheDirectoryPath = cache.absolute.path;
      final pages = await extractPdfText(researchPdf()).toList();
      expect(pages, hasLength(2));
      expect(pages.first.text, contains('Orbit research page one'));
      expect(pages.last.text, contains('Orbit research page two'));
    },
    skip: !Platform.isWindows || !dll.existsSync(),
  );
}
