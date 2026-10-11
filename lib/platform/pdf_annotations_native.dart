import 'dart:ffi';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as native;
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;
import '../domain/pdf_annotation.dart';

/// Writes only an in-memory derivative, on PDFium's owning worker. No actions
/// or JavaScript are executed. The original bytes and live viewer stay untouched.
Future<Uint8List> exportPdfAnnotations(
  Uint8List source,
  String fileId,
  String checksum,
  List<PdfAnnotation> annotations,
) async {
  if (source.length > 64 * 1024 * 1024 ||
      sha256.convert(source).toString() != checksum) {
    throw StateError(
      'PDF bytes differ from the source version or exceed 64 MiB.',
    );
  }
  if (annotations.isEmpty || annotations.length > 2000) {
    throw StateError('Select between 1 and 2,000 review items.');
  }
  var regionCount = 0, textLength = 0;
  for (final item in annotations) {
    final raw = item.source['regions'];
    final regions = item.regions;
    regionCount += regions.length;
    textLength +=
        (item.object.body.length + item.object.title.length + 128) *
        regions.length;
    if (!PdfAnnotation.isAnnotation(item.object) ||
        item.object.isReadOnly ||
        item.fileId != fileId ||
        !item.matches(checksum) ||
        (item.source['kind'] != null && item.source['kind'] != 'pageComment') ||
        (item.object.properties['pdfReview'] != null &&
            (item.object.properties['pdfReview'] is! Map ||
                (item.object.properties['pdfReview'] as Map)['version'] !=
                    1)) ||
        raw is! List ||
        raw.length != regions.length ||
        regions.isEmpty ||
        regionCount > 10000 ||
        textLength > 2000000 ||
        regions.any(
          (r) =>
              r.data['style'] != null &&
              !{
                'highlight',
                'underline',
                'strikeout',
              }.contains(r.data['style']),
        )) {
      throw StateError(
        'Review contains stale, unsupported or oversized annotations.',
      );
    }
  }
  return PdfrxEntryFunctions.instance.compute((message) {
    final (bytes, items) = message;
    final api = native.getPdfium(modulePath: Pdfrx.pdfiumModulePath);
    final buffer = calloc<Uint8>(bytes.length);
    buffer.asTypedList(bytes.length).setAll(0, bytes);
    final doc = api.FPDF_LoadMemDocument64(
      buffer.cast(),
      bytes.length,
      nullptr,
    );
    try {
      if (doc == nullptr) throw StateError('Cannot open PDF for export.');
      if (api.FPDF_GetSecurityHandlerRevision(doc) != -1 ||
          api.FPDF_GetSignatureCount(doc) > 0 ||
          api.FPDF_GetFormType(doc) > 1) {
        throw UnsupportedError(
          'Protected, signed and XFA PDFs cannot be exported.',
        );
      }
      for (final item in items) {
        // Each rectangle becomes a standard annotation. Multi-line excerpts
        // retain exact per-region geometry and share their Orbit note reference.
        final regions = item.regions;
        for (var i = 0; i < regions.length; i++) {
          final region = regions[i];
          final number = region.data['page'] as int;
          if (number > api.FPDF_GetPageCount(doc)) {
            throw StateError('An annotation refers to a missing PDF page.');
          }
          final page = api.FPDF_LoadPage(doc, number - 1);
          if (page == nullptr) throw StateError('Cannot load PDF page.');
          try {
            final style = region.data['style'] ?? 'highlight';
            final type = item.isPageComment
                ? 1
                : switch (style) {
                    'underline' => 10,
                    'strikeout' => 12,
                    _ => 9,
                  };
            final annot = api.FPDFPage_CreateAnnot(page, type);
            if (annot == nullptr) {
              throw StateError('Cannot create PDF annotation.');
            }
            final rect = calloc<native.FS_RECTF>();
            final quad = calloc<native.FS_QUADPOINTSF>();
            final px = calloc<Double>(), py = calloc<Double>();
            try {
              (double, double) point(double x, double y) {
                // DeviceToPage accounts for intrinsic rotation and crop origin.
                _require(
                  api.FPDF_DeviceToPage(
                    page,
                    0,
                    0,
                    1000000,
                    1000000,
                    0,
                    (x * 1000000).round(),
                    (y * 1000000).round(),
                    px,
                    py,
                  ),
                );
                return (px.value, py.value);
              }

              final tl = point(region.x, region.y);
              final tr = point(region.x + region.width, region.y);
              final bl = point(region.x, region.y + region.height);
              final br = point(
                region.x + region.width,
                region.y + region.height,
              );
              final points = [tl, tr, bl, br];
              rect.ref
                ..left = points.map((p) => p.$1).reduce(math.min)
                ..right = points.map((p) => p.$1).reduce(math.max)
                ..bottom = points.map((p) => p.$2).reduce(math.min)
                ..top = points.map((p) => p.$2).reduce(math.max);
              _require(api.FPDFAnnot_SetRect(annot, rect));
              if (!item.isPageComment) {
                quad.ref
                  ..x1 = tl.$1
                  ..y1 = tl.$2
                  ..x2 = tr.$1
                  ..y2 = tr.$2
                  ..x3 = bl.$1
                  ..y3 = bl.$2
                  ..x4 = br.$1
                  ..y4 = br.$2;
                _require(api.FPDFAnnot_AppendAttachmentPoints(annot, quad));
              }
              final color = region.color == 0 ? item.color : region.color;
              _require(
                api.FPDFAnnot_SetColor(
                  annot,
                  native.FPDFANNOT_COLORTYPE.FPDFANNOT_COLORTYPE_Color,
                  (color >> 16) & 255,
                  (color >> 8) & 255,
                  color & 255,
                  type == 9 ? 90 : 255,
                ),
              );
              _require(
                api.FPDFAnnot_SetFlags(annot, 4),
              ); // Print, still editable.
              void string(String key, String value) {
                final k = key.toNativeUtf8(), v = value.toNativeUtf16();
                try {
                  _require(
                    api.FPDFAnnot_SetStringValue(annot, k.cast(), v.cast()),
                  );
                } finally {
                  calloc.free(k);
                  calloc.free(v);
                }
              }

              string('NM', '${item.object.id}:$i');
              string('T', item.object.title);
              string(
                'Contents',
                '${item.resolved ? 'Resolved' : 'Open'} review\n'
                    '${item.object.body}\n\nOrbit note: [[${item.object.id}]]',
              );
            } finally {
              calloc.free(px);
              calloc.free(py);
              calloc.free(rect);
              calloc.free(quad);
              api.FPDFPage_CloseAnnot(annot);
            }
          } finally {
            api.FPDF_ClosePage(page);
          }
        }
      }
      final output = BytesBuilder(copy: true);
      final writer = calloc<native.FPDF_FILEWRITE>();
      final callback =
          NativeCallable<
            Int Function(
              Pointer<native.FPDF_FILEWRITE>,
              Pointer<Void>,
              UnsignedLong,
            )
          >.isolateLocal((
            Pointer<native.FPDF_FILEWRITE> self,
            Pointer<Void> data,
            int size,
          ) {
            if (output.length + size > 80 * 1024 * 1024) return 0;
            output.add(data.cast<Uint8>().asTypedList(size));
            return 1;
          }, exceptionalReturn: 0);
      try {
        writer.ref.version = 1;
        writer.ref.WriteBlock = callback.nativeFunction;
        _require(api.FPDF_SaveAsCopy(doc, writer, 2));
        return output.takeBytes();
      } finally {
        callback.close();
        calloc.free(writer);
      }
    } finally {
      if (doc != nullptr) api.FPDF_CloseDocument(doc);
      calloc.free(buffer);
    }
  }, (source, annotations));
}

void _require(int result) {
  if (result == 0) {
    throw StateError('PDF engine could not export this annotation.');
  }
}
