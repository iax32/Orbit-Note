import 'dart:ui' as ui;
import 'package:orbit_note/canvas/diagram_reference.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/domain/note_composition.dart';
import 'package:orbit_note/domain/publication_objects.dart';
import 'package:orbit_note/features/notes/export/publication_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/domain/canvas_pdf_layout.dart';
import 'package:orbit_note/domain/document_publication.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/notes/export/publication_export.dart';
import 'package:orbit_note/features/notes/export/canvas_pdf_export.dart';
import 'package:orbit_note/features/notes/export/pdf_bundle_dialog.dart';
import 'support/pdf_fixture.dart';

UniversalObject board(String id, {double width = 1300, double height = 2700}) =>
    UniversalObject(
      id: id,
      workspaceId: 'workspace',
      typeId: 'orbit.canvas',
      title: 'Diagram $id',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      data: {
        'elements': [
          {
            'id': 'a',
            'type': 'text',
            'x': -70,
            'y': -40,
            'width': width,
            'height': height,
            'text': 'Top label\nBottom preserved',
          },
          {
            'id': 'b',
            'type': 'rectangle',
            'x': width - 90,
            'y': height - 60,
            'width': 40,
            'height': 40,
          },
        ],
      },
    );
void main() {
  test(
    'diagram Markdown keeps selected UML, ordinary text and free message arrows together',
    () {
      final scene = CanvasScene.fromJson({
        'elements': [
          {
            'id': 'class',
            'type': 'rectangle',
            'x': 0,
            'y': 0,
            'width': 200,
            'height': 140,
            'uml': {},
            'text': 'A',
          },
          {
            'id': 'text',
            'type': 'text',
            'x': 0,
            'y': 160,
            'width': 300,
            'height': 80,
            'text': 'Explanation',
          },
          {
            'id': 'arrow',
            'type': 'connector',
            'startX': 0,
            'startY': 100,
            'endX': 300,
            'endY': 100,
          },
          {'id': 'hidden', 'type': 'text', 'hidden': true, 'text': 'Private'},
        ],
      });
      final ids = diagramExportSelection(scene, ['class', 'text', 'arrow']);
      expect(ids, containsAll(['class', 'text', 'arrow']));
      expect(ResolvedCanvasDiagram(scene, ids).scene.elements, hasLength(3));
      expect(
        diagramMarkdown('board', 'Combined', ids),
        contains('orbit-object:board'),
      );
    },
  );
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Canvas publication retains the supplied warm-paper palette', () async {
    final o = board('theme', width: 300, height: 200);
    final colors = ColorScheme.fromSeed(
      seedColor: Colors.brown,
      brightness: Brightness.light,
      surface: const Color(0xfffff3d2),
    );
    final png = await renderPublicationCanvas(
      PublicationCanvasSnapshot(
        'theme',
        o,
        const NoteObjectBlock('theme', 'Theme'),
      ),
      objects: [o],
      warn: (_) {},
      canvasColors: colors,
    );
    final codec = await ui.instantiateImageCodec(png!);
    final frame = await codec.getNextFrame();
    final pixels = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    expect(pixels!.getUint8(0), 255);
    expect(pixels.getUint8(1), 243);
    expect(pixels.getUint8(2), 210);
    frame.image.dispose();
    codec.dispose();
  });
  test(
    'readable tiles cover every edge with overlap and honor each paper orientation',
    () {
      const bounds = CanvasBounds(-100, -50, 1700, 3100);
      for (final orientation in ['auto', 'portrait', 'landscape']) {
        final p = CanvasPdfLayout(bounds, orientation: orientation);
        expect(p.pages.length, greaterThan(1));
        expect(p.scale, greaterThanOrEqualTo(.75));
        expect(p.pages.first.left, bounds.left);
        expect(p.pages.first.top, bounds.top);
        expect(p.pages.last.right, closeTo(bounds.right, .0001));
        expect(p.pages.last.bottom, closeTo(bounds.bottom, .0001));
        for (var r = 0; r < p.rows; r++) {
          for (var c = 1; c < p.columns; c++) {
            expect(
              p.pages[r * p.columns + c].left,
              lessThan(p.pages[r * p.columns + c - 1].right),
            );
          }
        }
        expect(p.width > p.height, orientation == 'landscape');
        final single = CanvasPdfLayout(
          bounds,
          orientation: orientation,
          tiles: false,
          a3: true,
        );
        expect(single.pages.length, 1);
        expect(single.pages.single.width, bounds.width);
      }
      expect(
        () => CanvasPdfLayout(const CanvasBounds(0, 0, double.nan, 3)),
        throwsFormatException,
      );
      expect(
        () => CanvasPdfLayout(const CanvasBounds(0, 0, 100000, 100000)),
        throwsFormatException,
      );
    },
  );
  test(
    'note followed by differently sized Canvas pages renders once after TOC and retains source',
    () async {
      expect(await initPdfTesting(), true);
      final a = board('a', width: 900, height: 550),
          b = board('b', width: 700, height: 1000);
      final export = PublicationExport(
        PublicationDocument.parse(
          'Combined',
          '# First section\n\nVisible note text.',
          const PublicationStyle(),
        ),
      );
      var calls = 0;
      final bytes = await export.pdf(
        appendPages: (pdf) async {
          calls++;
          await appendCanvasPdfPages(
            pdf,
            [
              CanvasPdfPart(a, orientation: 'landscape', tiles: false),
              CanvasPdfPart(b, a3: true, tiles: false),
            ],
            objects: [a, b],
            warn: export.warn,
          );
        },
      );
      expect(calls, 1);
      final pdf = await PdfDocument.openData(bytes);
      try {
        expect(pdf.pages.length, greaterThanOrEqualTo(3));
        final texts = [
          for (final page in pdf.pages) (await page.loadText())!.fullText,
        ];
        expect(texts.first, contains('Combined'));
        expect(texts[texts.length - 2], contains('Diagram a'));
        expect(texts.last, contains('Diagram b'));
        expect(
          pdf.pages[pdf.pages.length - 2].width,
          greaterThan(pdf.pages[pdf.pages.length - 2].height),
        );
        expect(pdf.pages.last.height, greaterThan(1100));
        expect(a.data['elements'], hasLength(2));
      } finally {
        await pdf.dispose();
      }
      await expectLater(
        export.pdf(
          appendPages: (_) async {
            throw const FormatException('fail');
          },
        ),
        throwsFormatException,
      );
    },
  );
  testWidgets(
    'bundle controls remain usable at narrow width and enlarged text',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.7)),
            child: child!,
          ),
          home: PdfBundleDialog(
            objects: [board('a'), board('b')],
            initialCanvasId: 'a',
            previewBuilder: (_) => const Text('Ready'),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Readable pages'), findsOneWidget);
      expect(find.text('Prepare PDF'), findsOneWidget);
      final button = t.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save PDF'),
      );
      expect(button.onPressed, isNull);
    },
  );
}
