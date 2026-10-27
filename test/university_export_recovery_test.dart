import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:orbit_note/domain/university/lab_document.dart';
import 'package:orbit_note/domain/university/lab_presets.dart';
import 'package:orbit_note/domain/document_publication.dart';
import 'package:orbit_note/features/notes/export/publication_export.dart';
import 'package:orbit_note/canvas/university_diagram.dart';
import 'package:orbit_note/canvas/university_glyph.dart';
import 'package:orbit_note/canvas/canvas_svg.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'support/pdf_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'ordinary Markdown disk reopen retains unknown model data and generated report',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'orbit-university-test-',
      );
      addTearDown(() => folder.delete(recursive: true));
      final doc = universityPreset(UniversityLabKind.state).updated({
        'future': {'owned': 'keep'},
      });
      final file = File('${folder.path}/exercise.md');
      await file.writeAsString(
        doc.applyTo('# My solution\n\nOriginal prose.'),
        flush: true,
      );
      final recovered = UniversityDocument.fromMarkdown(
        await file.readAsString(),
      )!;
      expect(recovered.data, doc.data);
      expect(recovered.report(), doc.report());
    },
  );
  test(
    'regenerating a Canvas preserves placement identity geometry and unknown fields',
    () {
      var serial = 0;
      String id() => 'p${serial++}';
      final doc = universityPreset(UniversityLabKind.activity),
          first = universityDiagram(doc, id, const CanvasPoint(40, 70));
      final oldNode = first
          .firstWhere((e) => e.data['universityNode'] is Map)
          .copy({
            'x': 5000.0,
            'future': {'retain': true},
          });
      final existing = [
        for (final e in first.skip(1))
          if (e.id == oldNode.id) oldNode else e,
      ];
      final second = universityDiagram(
        doc.updated({'title': 'New title'}),
        id,
        const CanvasPoint(40, 70),
        existingFrame: first.first,
        existing: existing,
      );
      expect(second.first.id, first.first.id);
      final same = second.singleWhere((e) => e.id == oldNode.id);
      expect(same.x, 5000);
      expect(same.data['future'], {'retain': true});
      expect(
        second
            .where((e) => e.data['universityEdge'] is String)
            .map((e) => e.id),
        first.where((e) => e.data['universityEdge'] is String).map((e) => e.id),
      );
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': second.map((e) => e.data).toList(),
      });
      expect(
        universityModelFromSelection(scene, {same.id})!.title,
        'New title',
      );
    },
  );
  test(
    'activity glyphs and distributed message arrows survive vector export',
    () {
      var serial = 0;
      final doc = universityPreset(UniversityLabKind.activity),
          elements = universityDiagram(
            doc,
            () => 'g${serial++}',
            const CanvasPoint(0, 0),
          );
      final start = elements.singleWhere(
        (e) =>
            e.data['universityNode'] is Map &&
            (e.data['universityNode'] as Map)['kind'] == 'start',
      );
      final fork = elements.singleWhere(
        (e) =>
            e.data['universityNode'] is Map &&
            (e.data['universityNode'] as Map)['kind'] == 'fork',
      );
      expect(universityGlyph(start).solidOvals, isNotEmpty);
      expect(universityGlyph(fork).solidBoxes, isNotEmpty);
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': elements.map((e) => e.data).toList(),
      });
      expect(canvasToSvg(scene), contains('<ellipse'));
      final network = universityDiagram(
        universityPreset(UniversityLabKind.distributed),
        () => 'd${serial++}',
        const CanvasPoint(0, 0),
      );
      expect(network.where((e) => e.type == 'connector'), hasLength(2));
      expect(
        network.where((e) => e.data['universityKey'] == 'event:5').single.text,
        contains('V=2,2,2'),
      );
    },
  );
  test(
    'PDF HTML and Word export keep report and omit embedded JSON metadata',
    () async {
      expect(await initPdfTesting(), true);
      final source = universityPreset(
        UniversityLabKind.state,
      ).applyTo('# UNI_EXPORT_SENTINEL');
      final export = PublicationExport(
        PublicationDocument.parse(
          'University report',
          source,
          const PublicationStyle(contents: false),
        ),
      );
      final bytes = await export.pdf(), pdf = await PdfDocument.openData(bytes);
      try {
        final text = [
          for (final p in pdf.pages) (await p.loadText())!.fullText,
        ].join('\n');
        expect(text, contains('UNI_EXPORT_SENTINEL'));
        expect(text, contains('Active states'));
        expect(text, isNot(contains('orbit:university')));
        expect(text, isNot(contains('"version":1')));
      } finally {
        await pdf.dispose();
      }
      expect(export.docx(), isNotEmpty);
      expect(export.html(), contains('Active states'));
      expect(utf8.decode(utf8.encode(source)), source);
    },
  );
}
