import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:orbit_note/domain/document_publication.dart';
import 'package:orbit_note/domain/linked_section.dart';
import 'package:orbit_note/domain/object_reference.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/notes/export/publication_export.dart';
import 'package:orbit_note/features/notes/export/publication_math.dart';
import 'package:orbit_note/features/notes/export/publication_workspace.dart';
import 'package:pdfrx/pdfrx.dart';
import 'support/pdf_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const body =
      '# Overview\r\n\r\nUnicode café — résumé. **Bold** and *italic*.[^a]\r\n\r\n'
      '| Name | Result |\r\n| --- | --- |\r\n| Orbit | Good |\r\n\r\n'
      '<!-- orbit:pagebreak -->\r\n\r\n## Details\r\n\r\n[^a]: First line\r\n    Second line\r\n';
  test(
    'snapshot preserves source ownership, headings, literal examples and footnotes',
    () {
      final d = PublicationDocument.parse(
        'Report',
        body,
        const PublicationStyle(numberHeadings: true),
      );
      expect(d.headings.map((h) => h.text), ['1. Overview', '1.1. Details']);
      expect(d.footnotes['a'], 'First line\nSecond line');
      expect(
        d.nodes.whereType<md.Element>().any((e) => e.tag == 'pagebreak'),
        true,
      );
      final literal = PublicationDocument.parse(
        'Code',
        '```md\n<!-- orbit:pagebreak -->\n[^missing]\n```',
        const PublicationStyle(),
      );
      expect(literal.warnings, isEmpty);
      expect(literal.footnotes, isEmpty);
      expect(
        literal.nodes.whereType<md.Element>().any((e) => e.tag == 'pagebreak'),
        false,
      );
      expect(body, contains('\r\n'));
      expect(
        () => PublicationDocument.parse(
          'Bad',
          body,
          const PublicationStyle(margin: 300),
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'linked section resolves current text and missing source retains fallback',
    () {
      final source = UniversalObject(
        id: 'source',
        workspaceId: 'vault',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        typeId: 'orbit.note',
        title: 'Source',
        body: '# Live\n\nCurrent paragraph.\n',
        properties: const {},
        data: const {},
      );
      final link = LinkedSection(
        ObjectReference.parse('source#Live'),
        'Old paragraph.',
        section: true,
      ).encode();
      final d = PublicationDocument.parse(
        'Report',
        link,
        const PublicationStyle(),
        objects: [source],
        ownerId: 'host',
      );
      expect(d.source, contains('Current paragraph.'));
      expect(d.source, isNot(contains('Old paragraph.')));
      final missing = PublicationDocument.parse(
        'Report',
        link,
        const PublicationStyle(),
        ownerId: 'host',
      );
      expect(missing.source, contains('Old paragraph.'));
      expect(missing.warnings, isNotEmpty);
      final fenced = PublicationDocument.parse(
        'Example',
        '```\n$link\n```',
        const PublicationStyle(),
        objects: [source],
      );
      expect(fenced.source, contains('Old paragraph.'));
    },
  );
  test(
    'HTML is standalone, escapes active content, and keeps navigable contents',
    () {
      final d = PublicationDocument.parse(
        '<Report>',
        '$body\n<script>alert(1)</script>\n\n[bad](javascript:alert)\n',
        const PublicationStyle(),
      );
      final html = PublicationExport(d).html();
      expect(html, contains('Content-Security-Policy'));
      expect(html, contains('href="#heading-1"'));
      expect(html, contains('id="fn-1"'));
      expect(html, contains('&lt;Report&gt;'));
      expect(html, isNot(contains('<script>')));
      expect(html, isNot(contains('href="javascript:')));
    },
  );
  test(
    'Word is editable OOXML with native footnotes, tables, heading links and page fields',
    () {
      final d = PublicationDocument.parse(
        'Report',
        body,
        const PublicationStyle(header: 'Orbit', author: 'Writer', letter: true),
      );
      final bytes = PublicationExport(d).docx();
      final archive = ZipDecoder().decodeBytes(bytes);
      String part(String name) =>
          utf8.decode(archive.findFile(name)!.content as List<int>);
      expect(part('word/document.xml'), contains('<w:tbl>'));
      expect(
        part('word/document.xml'),
        contains('<w:footnoteReference w:id="1"'),
      );
      expect(part('word/document.xml'), contains('w:anchor="heading_1"'));
      expect(part('word/document.xml'), contains('w:w="12240"'));
      expect(part('word/document.xml'), contains('w:br w:type="page"'));
      expect(part('word/footnotes.xml'), contains('First line'));
      expect(part('word/header.xml'), contains('Orbit'));
      expect(part('word/footer.xml'), contains('w:instr="PAGE"'));
      expect(
        part('word/_rels/document.xml.rels'),
        contains('relationships/footnotes'),
      );
    },
  );
  test(
    'PDF has real pages, Unicode text and clickable destination annotations',
    () async {
      final export = PublicationExport(
        PublicationDocument.parse(
          'Report',
          body,
          const PublicationStyle(contents: true, titlePage: true),
        ),
      );
      final bytes = await export.pdf();
      expect(await initPdfTesting(), true);
      final pdf = await PdfDocument.openData(bytes);
      try {
        expect(pdf.pages.length, greaterThanOrEqualTo(3));
        final texts = <String>[];
        for (final page in pdf.pages) {
          texts.add((await page.loadText())?.fullText ?? '');
        }
        expect(texts.join(), contains('café'));
        expect(texts.join(), contains('First line'));
        expect(texts[1], contains('Overview'));
        expect(texts[1], contains('Details'));
        expect((await pdf.pages[1].loadLinks()).isNotEmpty, true);
        final rendered = await pdf.pages[1].render(width: 595, height: 842);
        final image = await rendered!.createImage();
        try {
          await File('.local/publishing-review.png').writeAsBytes(
            (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!.buffer.asUint8List(),
          );
          await File('.local/publishing-review.pdf').writeAsBytes(bytes);
        } finally {
          image.dispose();
          rendered.dispose();
        }
        expect(export.warnings.any((w) => w.contains('endnotes')), true);
      } finally {
        await pdf.dispose();
      }
    },
  );
  test(
    'publication omits private frontmatter and warns about missing and duplicate footnotes',
    () {
      final source =
          '---\nprivateToken: secret\n---\n\n# Public\n\nText[^missing][^a]\n\n[^a]: First\n[^a]: Duplicate\n';
      final d = PublicationDocument.parse(
        'Public',
        source,
        const PublicationStyle(),
      );
      expect(d.source, isNot(contains('secret')));
      expect(d.footnotes['a'], 'First');
      expect(d.warnings.any((w) => w.contains('Duplicate')), true);
      expect(d.warnings.any((w) => w.contains('Missing')), true);
      expect(PublicationExport(d).html(), isNot(contains('secret')));
      expect(source, contains('secret'));
    },
  );
  testWidgets(
    'resource loading is shared during style changes and remote images are never fetched',
    (tester) async {
      final completer = Completer<Uint8List?>();
      var reads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PublicationWorkspace(
              title: 'Resources',
              source:
                  '![Local](Attachments/image.png)\n\n![Remote](https://example.com/image.png)',
              readImage: (_) {
                reads++;
                return completer.future;
              },
              previewBuilder: (_) => const Text('Prepared pages'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Letter'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(reads, 1);
      await tester.runAsync(() async {
        completer.complete(
          (await rootBundle.load('assets/logo.png')).buffer.asUint8List(),
        );
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();
      expect(find.text('Prepared pages'), findsOneWidget);
      expect(reads, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'equation rendering uses detached tree and creates an embedded PNG',
    (tester) async {
      Uint8List? png;
      await tester.runAsync(() async {
        png = await renderPublicationMath(r'\frac{a}{b}=x^2');
      });
      expect(png!.take(4), [137, 80, 78, 71]);
      await tester.runAsync(() async {
        await expectLater(
          renderPublicationMath(r'\notAValidOrbitCommand'),
          throwsFormatException,
        );
      });
      final d = PublicationDocument.parse(
        'Math',
        r'Value $x^2$.',
        const PublicationStyle(),
      );
      final export = PublicationExport(d, equations: {'x^2': png!});
      expect(export.html(), contains('data:image/png;base64,'));
      final archive = ZipDecoder().decodeBytes(export.docx());
      expect(archive.findFile('word/media/image1.png'), isNotNull);
      await tester.runAsync(() async {
        final pdfBytes = await export.pdf();
        expect(await initPdfTesting(), true);
        final pdf = await PdfDocument.openData(pdfBytes);
        try {
          expect(pdf.pages, isNotEmpty);
        } finally {
          await pdf.dispose();
        }
      });
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'compact publishing controls tolerate 200% text and regenerate preview',
    (tester) async {
      tester.view.physicalSize = const Size(480, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(480, 900),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: PublicationWorkspace(
                title: 'Long document title',
                source: body,
                previewBuilder: (_) =>
                    const Center(child: Text('Page preview')),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pump();
      expect(find.text('Page preview'), findsOneWidget);
      await tester.tap(find.text('Document style'));
      await tester.pumpAndSettle();
      expect(find.text('A4'), findsOneWidget);
      await tester.tap(find.text('Letter'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
