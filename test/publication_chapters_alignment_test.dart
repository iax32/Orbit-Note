import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:pdfrx/pdfrx.dart';
import 'package:orbit_note/domain/document_publication.dart';
import 'package:orbit_note/domain/publication_preset.dart';
import 'package:orbit_note/features/notes/export/publication_export.dart';
import 'support/pdf_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'global H1 rule survives settings and starts chapters without blank pages',
    () async {
      expect(await initPdfTesting(), true);
      const style = PublicationStyle(contents: false, h1PageBreaks: true);
      final restored = PublicationStyle.fromJson(style.toJson());
      expect(restored.h1PageBreaks, true);
      expect(PublicationStyle.fromJson({}).h1PageBreaks, false);
      expect(PublicationPreset.compact.apply(style).h1PageBreaks, true);
      for (final separator in ['', '<!-- orbit:pagebreak -->\n\n']) {
        final doc = PublicationDocument.parse(
          'First',
          '# First\n\nFIRST_BODY\n\n## Subsection\n\nSUB_BODY\n\n$separator# Second\n\nSECOND_BODY',
          restored,
        );
        final export = PublicationExport(doc);
        final pdf = await PdfDocument.openData(await export.pdf());
        try {
          expect(pdf.pages.length, 2);
          expect(
            (await pdf.pages.first.loadText())!.fullText,
            contains('SUB_BODY'),
          );
          expect(
            (await pdf.pages.last.loadText())!.fullText,
            contains('SECOND_BODY'),
          );
        } finally {
          await pdf.dispose();
        }
        expect(export.html(), contains('break-before:page'));
        final zip = ZipDecoder().decodeBytes(export.docx());
        final xml = utf8.decode(
          zip.files.singleWhere((f) => f.name == 'word/document.xml').content
              as List<int>,
        );
        expect(xml, contains('<w:pageBreakBefore/>'));
      }
    },
  );
  test(
    'paragraph alignment exports without losing inline syntax or aligning code',
    () async {
      const text =
          '<!-- orbit:align=justify -->\nA **bold** paragraph with [link](https://example.org). This is a longer justified paragraph that wraps to several lines to verify its margins and paragraph alignment while preserving the last line naturally.\n\n<!-- orbit:align=right -->\n# Chapter\n\n```\n<!-- orbit:align=justify -->\nCODE_LITERAL\n```';
      final doc = PublicationDocument.parse(
        'Report',
        text,
        const PublicationStyle(contents: false, h1PageBreaks: true),
      );
      final paragraph = doc.nodes.whereType<md.Element>().first;
      expect(paragraph.attributes['orbit-text-align'], 'justify');
      final heading = doc.nodes.whereType<md.Element>().singleWhere(
        (e) => e.tag == 'h1',
      );
      expect(heading.attributes['orbit-text-align'], 'right');
      expect(heading.attributes['orbit-h1-pagebreak'], 'true');
      final export = PublicationExport(doc);
      expect(export.html(), contains('text-align:justify'));
      expect(export.html(), contains('text-align:right;break-before:page'));
      final zip = ZipDecoder().decodeBytes(export.docx());
      final xml = utf8.decode(
        zip.files.singleWhere((f) => f.name == 'word/document.xml').content
            as List<int>,
      );
      expect(xml, contains('<w:jc w:val="both"/>'));
      expect(xml, contains('CODE_LITERAL'));
      final bytes = await export.pdf();
      expect(bytes, isNotEmpty);
      final pdf = await PdfDocument.openData(bytes);
      try {
        final page = pdf.pages.last;
        final text = (await page.loadText())!;
        final index = text.fullText.indexOf('Chapter');
        expect(index, greaterThanOrEqualTo(0));
        expect(text.charRects[index].left, greaterThan(page.width / 2));
      } finally {
        await pdf.dispose();
      }
      final dir = Directory('.local/pdf-profile-qa')
        ..createSync(recursive: true);
      File('${dir.path}/chapters-alignment.pdf').writeAsBytesSync(bytes);
    },
  );
}
