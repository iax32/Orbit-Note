import 'dart:ffi';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as native;
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;
import '../domain/pdf_annotation.dart';
import '../domain/pdf_ink.dart';
import '../canvas/scene.dart';

/// Writes only an in-memory derivative, on PDFium's owning worker. No actions
/// or JavaScript are executed. The original bytes and live viewer stay untouched.
Future<Uint8List> exportPdfAnnotations(
  Uint8List source,
  String fileId,
  String checksum,
  List<PdfAnnotation> annotations, {
  List<CanvasElement> ink = const [],
}) async {
  if (source.length > 64 * 1024 * 1024 ||
      sha256.convert(source).toString() != checksum) {
    throw StateError(
      'PDF bytes differ from the source version or exceed 64 MiB.',
    );
  }
  if ((annotations.isEmpty && ink.isEmpty) ||
      annotations.length > 2000 ||
      ink.length > PdfInkDocument.maxStrokes) {
    throw StateError('Add drawings or select up to 2,000 review items.');
  }
  var samples = 0;
  final ids = <String>{};
  for (final stroke in ink) {
    if (PdfInkDocument.validateStroke(stroke.data) == null ||
        !ids.add(stroke.id)) {
      throw StateError('Drawing contains unsupported or invalid strokes.');
    }
    samples += (stroke.data['points'] as List).length;
    if (samples > 500000) {
      throw StateError(
        'This PDF export exceeds 500,000 ink samples. Drawings are retained.',
      );
    }
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
    final (bytes, items, strokes) = message;
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
      for (final stroke in strokes) {
        _writeInk(api, doc, stroke);
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
  }, (source, annotations, ink));
}

/// One standard Ink annotation and one vector appearance stream per stroke.
/// Building an appearance once avoids PDFium regenerating it for each pressure
/// segment (quadratic work for long strokes). Round caps, quadratic smoothing,
/// pressure widths and per-segment highlighter alpha match the shared renderer.
void _writeInk(
  native.PDFium api,
  native.FPDF_DOCUMENT doc,
  CanvasElement stroke,
) {
  final number = stroke.data['page'] as int;
  if (number > api.FPDF_GetPageCount(doc)) {
    throw StateError('Drawing page is missing.');
  }
  final page = api.FPDF_LoadPage(doc, number - 1);
  if (page == nullptr) throw StateError('Cannot load drawing page.');
  final px = calloc<Double>(), py = calloc<Double>();
  try {
    final width = (stroke.data['pageWidth'] as num).toDouble();
    final height = (stroke.data['pageHeight'] as num).toDouble();
    if ((api.FPDF_GetPageWidthF(page) - width).abs() > .02 ||
        (api.FPDF_GetPageHeightF(page) - height).abs() > .02) {
      throw StateError('Drawing geometry differs from the PDF page.');
    }
    (double, double) point(double x, double y) {
      _require(
        api.FPDF_DeviceToPage(
          page,
          0,
          0,
          1000000,
          1000000,
          0,
          (x / width * 1000000).round(),
          (y / height * 1000000).round(),
          px,
          py,
        ),
      );
      return (px.value, py.value);
    }

    final samples = stroke.inkSamples!;
    final points = [
      for (final p in samples)
        point(
          stroke.x + (p['x'] as num).toDouble(),
          stroke.y + (p['y'] as num).toDouble(),
        ),
    ];
    final annot = api.FPDFPage_CreateAnnot(page, 15); // Ink
    if (annot == nullptr) throw StateError('Cannot create drawing annotation.');
    final nativePoints = calloc<native.FS_POINTF>(points.length);
    final rect = calloc<native.FS_RECTF>();
    try {
      for (var i = 0; i < points.length; i++) {
        nativePoints[i]
          ..x = points[i].$1
          ..y = points[i].$2;
      }
      if (api.FPDFAnnot_AddInkStroke(annot, nativePoints, points.length) < 0) {
        throw StateError('Cannot save drawing points.');
      }
      final nib = stroke.data['isHighlighter'] == true
          ? math.max(16.0, stroke.strokeWidth)
          : stroke.strokeWidth;
      final zero = point(0, 0), unit = point(1, 0);
      final unitScale = math.sqrt(
        math.pow(unit.$1 - zero.$1, 2) + math.pow(unit.$2 - zero.$2, 2),
      );
      final pad = nib * unitScale;
      rect.ref
        ..left = points.map((p) => p.$1).reduce(math.min) - pad
        ..right = points.map((p) => p.$1).reduce(math.max) + pad
        ..bottom = points.map((p) => p.$2).reduce(math.min) - pad
        ..top = points.map((p) => p.$2).reduce(math.max) + pad;
      _require(api.FPDFAnnot_SetRect(annot, rect));
      final alpha = stroke.data['isHighlighter'] == true
          ? 97
          : ((stroke.color >> 24) & 255);
      _require(
        api.FPDFAnnot_SetColor(
          annot,
          native.FPDFANNOT_COLORTYPE.FPDFANNOT_COLORTYPE_Color,
          (stroke.color >> 16) & 255,
          (stroke.color >> 8) & 255,
          stroke.color & 255,
          alpha,
        ),
      );
      _require(api.FPDFAnnot_SetBorder(annot, 0, 0, nib * unitScale));
      _require(api.FPDFAnnot_SetFlags(annot, 4));
      final key = 'NM'.toNativeUtf8(), name = stroke.id.toNativeUtf16();
      try {
        _require(api.FPDFAnnot_SetStringValue(annot, key.cast(), name.cast()));
      } finally {
        calloc.free(key);
        calloc.free(name);
      }
      String f(double n) => n.toStringAsFixed(5);
      String xy((double, double) p) => '${f(p.$1)} ${f(p.$2)}';
      final content = StringBuffer('q\n');
      if (alpha < 255) content.writeln('/GS gs');
      final corners = [
        point(0, 0),
        point(width, 0),
        point(width, height),
        point(0, height),
      ];
      content.writeln(
        '${xy(corners[0])} m ${xy(corners[1])} l ${xy(corners[2])} l ${xy(corners[3])} l h W n',
      );
      final color =
          '${f(((stroke.color >> 16) & 255) / 255)} ${f(((stroke.color >> 8) & 255) / 255)} ${f((stroke.color & 255) / 255)}';
      content.writeln('$color RG $color rg 1 J 1 j');
      final pressure = samples.any((p) => (p['pressure'] as num) < .95);
      if (points.length == 1) {
        final p = points[0], r = nib * unitScale / 2, k = r * .5522847498307936;
        content.writeln(
          '${f(p.$1 + r)} ${f(p.$2)} m '
          '${f(p.$1 + r)} ${f(p.$2 + k)} ${f(p.$1 + k)} ${f(p.$2 + r)} ${f(p.$1)} ${f(p.$2 + r)} c '
          '${f(p.$1 - k)} ${f(p.$2 + r)} ${f(p.$1 - r)} ${f(p.$2 + k)} ${f(p.$1 - r)} ${f(p.$2)} c '
          '${f(p.$1 - r)} ${f(p.$2 - k)} ${f(p.$1 - k)} ${f(p.$2 - r)} ${f(p.$1)} ${f(p.$2 - r)} c '
          '${f(p.$1 + k)} ${f(p.$2 - r)} ${f(p.$1 + r)} ${f(p.$2 - k)} ${f(p.$1 + r)} ${f(p.$2)} c f',
        );
      } else if (pressure) {
        for (var i = 1; i < points.length; i++) {
          final average =
              (((samples[i - 1]['pressure'] as num) +
                          (samples[i]['pressure'] as num)) /
                      2)
                  .clamp(.1, 1);
          final w = math.max(.8, nib * (.35 + average * .9)) * unitScale;
          content.writeln(
            '${f(w)} w ${xy(points[i - 1])} m ${xy(points[i])} l S',
          );
        }
      } else {
        content.writeln('${f(nib * unitScale)} w ${xy(points[0])} m');
        var current = points[0];
        for (var i = 1; i < points.length - 1; i++) {
          final control = points[i],
              end = (
                (points[i].$1 + points[i + 1].$1) / 2,
                (points[i].$2 + points[i + 1].$2) / 2,
              );
          final c1 = (
            current.$1 + (control.$1 - current.$1) * 2 / 3,
            current.$2 + (control.$2 - current.$2) * 2 / 3,
          );
          final c2 = (
            end.$1 + (control.$1 - end.$1) * 2 / 3,
            end.$2 + (control.$2 - end.$2) * 2 / 3,
          );
          content.writeln('${xy(c1)} ${xy(c2)} ${xy(end)} c');
          current = end;
        }
        content.writeln('${xy(points.last)} l S');
      }
      content.writeln('Q');
      final appearance = content.toString().toNativeUtf16();
      try {
        _require(api.FPDFAnnot_SetAP(annot, 0, appearance.cast()));
      } finally {
        calloc.free(appearance);
      }
    } finally {
      calloc.free(nativePoints);
      calloc.free(rect);
      api.FPDFPage_CloseAnnot(annot);
    }
  } finally {
    calloc.free(px);
    calloc.free(py);
    api.FPDF_ClosePage(page);
  }
}

void _require(int result) {
  if (result == 0) {
    throw StateError('PDF engine could not export this annotation.');
  }
}
