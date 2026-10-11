import 'dart:typed_data';
import 'package:pdfrx/pdfrx.dart';
import '../domain/pdf_search.dart';

/// PDFium/wasm executes extraction in pdfrx's worker. No filesystem paths,
/// passwords, scripts, or original-file write access are supplied.
Stream<PdfTextPage> extractPdfText(Uint8List bytes) async* {
  // Background indexing may run before any PdfViewer has initialized pdfrx.
  // This also installs the web worker adapter and local font/cache environment.
  await pdfrxFlutterInitialize();
  final document = await PdfDocument.openData(bytes);
  try {
    if (document.permissions?.allowsCopying == false) {
      throw UnsupportedError('This PDF does not permit text copying.');
    }
    for (final page in document.pages) {
      final text = await page.loadStructuredText();
      yield PdfTextPage(page.pageNumber, text.fullText, document.pages.length);
    }
  } finally {
    await document.dispose();
  }
}
