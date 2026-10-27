import 'package:flutter/services.dart';
import 'package:flutter/material.dart' show ColorScheme;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../domain/canvas_pdf_layout.dart';
import '../../../domain/note_composition.dart';
import '../../../domain/publication_objects.dart';
import '../../../domain/universal_object.dart';
import 'publication_canvas.dart';

class CanvasPdfPart {
  const CanvasPdfPart(
    this.object, {
    this.orientation = 'auto',
    this.a3 = false,
    this.tiles = true,
    this.overview = true,
  });
  final UniversalObject object;
  final String orientation;
  final bool a3, tiles, overview;
}

Future<void> appendCanvasPdfPages(
  pw.Document pdf,
  List<CanvasPdfPart> parts, {
  required List<UniversalObject> objects,
  required void Function(String) warn,
  Future<Uint8List?> Function(String)? readImage,
  bool Function()? isCancelled,
  ColorScheme? canvasColors,
}) async {
  if (parts.length > 20) {
    throw const FormatException('Choose at most 20 Canvases per PDF.');
  }
  final font = pw.Font.ttf(
    await rootBundle.load('assets/publishing/Lato-Regular.ttf'),
  );
  for (final part in parts) {
    if (isCancelled?.call() == true) {
      throw const FormatException('Export preparation cancelled.');
    }
    if (part.object.typeId != 'orbit.canvas' ||
        part.object.isDeleted ||
        part.object.isReadOnly) {
      throw const FormatException(
        'Canvas source is unavailable or unsupported.',
      );
    }
    final snapshot = PublicationCanvasSnapshot(
      part.object.id,
      part.object,
      NoteObjectBlock(part.object.id, part.object.title),
    );
    final bounds = snapshot.scene.contentBounds?.inflate(32);
    if (bounds == null) {
      throw FormatException('Canvas is empty: ${part.object.title}');
    }
    final plan = CanvasPdfLayout(
      bounds,
      orientation: part.orientation,
      a3: part.a3,
      tiles: part.tiles,
    );
    final showOverview = part.overview && part.tiles && plan.pages.length > 1;
    final regions = [if (showOverview) bounds, ...plan.pages];
    if (regions.length > 100) {
      throw const FormatException(
        'Canvas exceeds 100 pages including its overview. Disable overview or use a larger paper size.',
      );
    }
    if (pdf.document.pdfPageList.pages.length + regions.length > 500) {
      throw const FormatException(
        'Combined PDF exceeds 500 pages. No partial file was saved.',
      );
    }
    if (!part.tiles && plan.scale < .5) {
      warn(
        'Small diagram text on one fitted page: ${part.object.title}. Choose readable pages or A3 for larger text.',
      );
    }
    for (final warning in snapshot.warnings) {
      warn(warning);
    }
    for (var i = 0; i < regions.length; i++) {
      if (isCancelled?.call() == true) {
        throw const FormatException('Export preparation cancelled.');
      }
      final region = regions[i];
      final overview = showOverview && i == 0;
      final detail = i - (showOverview ? 1 : 0);
      final imageScale = overview
          ? CanvasPdfLayout(
              bounds,
              orientation: part.orientation,
              a3: part.a3,
              tiles: false,
            ).scale
          : plan.scale;
      final bytes = await renderPublicationCanvas(
        snapshot,
        objects: objects,
        warn: warn,
        readImage: readImage,
        pageBounds: region,
        printPaper: canvasColors == null,
        canvasColors: canvasColors,
        longestEdge: 2400,
      );
      if (bytes == null) {
        throw FormatException('Canvas rendering failed: ${part.object.title}');
      }
      final image = pw.MemoryImage(bytes);
      pdf.addPage(
        pw.Page(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat(plan.width, plan.height),
            margin: const pw.EdgeInsets.all(32),
            theme: pw.ThemeData.withFont(base: font).copyWith(
              defaultTextStyle: pw.TextStyle(
                color: canvasColors == null
                    ? PdfColors.black
                    : PdfColor.fromInt(canvasColors.onSurface.toARGB32()),
              ),
            ),
            buildBackground: canvasColors == null
                ? null
                : (_) => pw.FullPage(
                    ignoreMargins: true,
                    child: pw.Container(
                      color: PdfColor.fromInt(canvasColors.surface.toARGB32()),
                    ),
                  ),
          ),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Outline(
                name:
                    'canvas-${part.object.id}-${pdf.document.pdfPageList.pages.length}-$i',
                title: i == 0
                    ? part.object.title
                    : '${part.object.title} · detail ${detail + 1}',
                level: i == 0 ? 0 : 1,
                child: pw.Text(
                  '${part.object.title}${overview ? ' · Overview' : ''}',
                  maxLines: 2,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Expanded(
                child: pw.Align(
                  alignment: overview || plan.pages.length == 1
                      ? pw.Alignment.topCenter
                      : pw.Alignment.topLeft,
                  child: pw.Image(
                    image,
                    width: region.width * imageScale,
                    height: region.height * imageScale,
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                overview
                    ? 'Page ${context.pageNumber} · Complete diagram; readable detail pages follow'
                    : plan.pages.length == 1
                    ? 'Page ${context.pageNumber}'
                    : 'Page ${context.pageNumber} · Detail ${detail + 1}/${plan.pages.length} · row ${detail ~/ plan.columns + 1}/${plan.rows}, column ${detail % plan.columns + 1}/${plan.columns}',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: canvasColors == null
                      ? PdfColors.grey700
                      : PdfColor.fromInt(
                          canvasColors.onSurfaceVariant.toARGB32(),
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
