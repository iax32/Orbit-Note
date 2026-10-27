import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/domain/canvas_pdf_layout.dart';
import 'package:orbit_note/domain/document_publication.dart';
import 'package:orbit_note/domain/publication_layout.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/notes/export/publication_export.dart';
import 'package:orbit_note/features/notes/export/publication_workspace.dart';
import 'package:orbit_note/features/notes/export/canvas_pdf_export.dart';
import 'support/pdf_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => expect(await initPdfTesting(), true));
  test(
    'heading page controls persist safely and export to PDF HTML and Word',
    () async {
      const source = '# First\n\nOpening text.\n\n# Second\n\nFOLLOWING_BODY';
      final initial = PublicationDocument.parse(
        'Report',
        source,
        const PublicationStyle(contents: false),
      );
      final heading = initial.nodes.whereType<md.Element>().singleWhere(
        (e) => e.textContent == 'Second',
      );
      final key = heading.attributes['orbit-key']!;
      final saved = PublicationSettings.update(
        source,
        const PublicationStyle(contents: false).toJson(),
        {
          key: {'pageBreakBefore': true, 'futureSetting': 42},
        },
      );
      expect(saved.endsWith(source), true);
      final doc = PublicationDocument.parse(
        'Report',
        saved,
        const PublicationStyle(contents: false),
      );
      final exp = PublicationExport(doc);
      final data = await exp.pdf();
      final pdf = await PdfDocument.openData(data);
      try {
        final texts = [
          for (final p in pdf.pages) (await p.loadText())!.fullText,
        ];
        expect(
          texts.indexWhere((t) => t.contains('Second')),
          greaterThan(texts.indexWhere((t) => t.contains('Opening text'))),
        );
        expect(texts.last, contains('FOLLOWING_BODY'));
      } finally {
        await pdf.dispose();
      }
      expect(exp.html(), contains('break-before:page'));
      final archive = ZipDecoder().decodeBytes(exp.docx());
      final xml = utf8.decode(
        archive.files.singleWhere((f) => f.name == 'word/document.xml').content
            as List<int>,
      );
      expect(xml, contains('<w:pageBreakBefore/>'));
      expect(
        PublicationSettings.parse(saved)!.data['blocks'][key]['futureSetting'],
        42,
      );
    },
  );
  test(
    'duplicate chapter names refuse ambiguous overrides and empty headings do not create contents rows',
    () {
      const text = '# \n\n# Same\n\nText\n\n# Same\n\nEnd';
      final first = PublicationDocument.parse(
        'Report',
        text,
        const PublicationStyle(),
      );
      expect(first.headings, hasLength(2));
      final key = (first.nodes.first as md.Element).attributes['orbit-key']!;
      final doc = PublicationDocument.parse(
        'Report',
        text,
        const PublicationStyle(),
        layouts: {
          key: {'pageBreakBefore': true},
        },
      );
      expect(doc.warnings.any((s) => s.contains('ambiguous')), true);
      expect(
        doc.nodes
            .whereType<md.Element>()
            .where((n) => n.tag == 'h1')
            .every((n) => n.attributes['orbit-pageBreakBefore'] == null),
        true,
      );
    },
  );
  test(
    'headings keep following prose on the same page across near-boundary cases',
    () async {
      for (final count in [8, 15, 22, 29, 36]) {
        final source =
            '# Report\n\n${List.generate(count, (i) => 'Paragraph $i. ${'Filler ' * 32}\n\n').join()}\n## Unique heading\n\nFOLLOWING_SENTINEL';
        final exp = PublicationExport(
          PublicationDocument.parse(
            'Report',
            source,
            const PublicationStyle(contents: false),
          ),
        );
        final pdf = await PdfDocument.openData(await exp.pdf());
        try {
          final texts = [
            for (final p in pdf.pages) (await p.loadText())!.fullText,
          ];
          expect(
            texts.singleWhere((t) => t.contains('Unique heading')),
            contains('FOLLOWING_SENTINEL'),
          );
        } finally {
          await pdf.dispose();
        }
      }
    },
  );
  test(
    'tiled Canvas starts with an overview and complete labelled detail pages',
    () async {
      final object = UniversalObject(
        id: 'diagram',
        workspaceId: 'w',
        typeId: 'orbit.canvas',
        title: 'Wide diagram',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        data: {
          'elements': [
            {
              'id': 'box',
              'type': 'rectangle',
              'x': 0,
              'y': 0,
              'width': 1300,
              'height': 900,
              'text': 'Diagram',
            },
          ],
        },
      );
      final plan = CanvasPdfLayout(const CanvasBounds(-32, -32, 1364, 964));
      final doc = pw.Document();
      await appendCanvasPdfPages(
        doc,
        [CanvasPdfPart(object)],
        objects: [object],
        warn: (_) {},
      );
      final pdf = await PdfDocument.openData(await doc.save());
      try {
        expect(pdf.pages.length, plan.pages.length + 1);
        expect(
          (await pdf.pages.first.loadText())!.fullText,
          contains('Overview'),
        );
        expect(
          (await pdf.pages.last.loadText())!.fullText,
          contains('Detail ${plan.pages.length}/${plan.pages.length}'),
        );
      } finally {
        await pdf.dispose();
      }
      expect(CanvasPdfLayout(const CanvasBounds(0, 0, 100, 100)).scale, 1);
    },
  );
  testWidgets(
    'chapter break control is reachable and changes only the publication draft',
    (t) async {
      String? applied;
      await t.pumpWidget(
        MaterialApp(
          home: PublicationWorkspace(
            title: 'Report',
            source: '# First\n\nText\n\n# Second\n\nMore',
            previewBuilder: (_) => const Text('Prepared'),
            onApply: (_, next) {
              applied = next;
              return true;
            },
          ),
        ),
      );
      Future<void> ready() async {
        for (var i = 0; i < 120; i++) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await t.pump();
          if (find.text('Prepared').evaluate().isNotEmpty &&
              find.byType(LinearProgressIndicator).evaluate().isEmpty) {
            return;
          }
        }
        fail('No preview');
      }

      await ready();
      final controls = find.byTooltip('Start chapter on a new page');
      await t.ensureVisible(controls.last);
      await t.tap(controls.last);
      await t.pump(const Duration(milliseconds: 350));
      await ready();
      expect(applied, isNull);
      await t.ensureVisible(find.text('Save settings to note'));
      await t.tap(find.text('Save settings to note'));
      await t.pumpAndSettle();
      expect(applied, contains('"pageBreakBefore":true'));
      expect(t.takeException(), isNull);
    },
  );
}
