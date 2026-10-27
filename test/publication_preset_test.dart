import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:orbit_note/domain/document_publication.dart';
import 'package:orbit_note/domain/publication_preset.dart';
import 'package:orbit_note/features/notes/export/publication_export.dart';
import 'package:orbit_note/features/notes/export/publication_workspace.dart';
import 'support/pdf_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'profiles preserve identity metadata and paper choice and stay valid',
    () {
      const original = PublicationStyle(
        letter: true,
        author: 'Ada',
        header: 'Research',
        canvasDetails: true,
      );
      for (final p in PublicationPreset.values) {
        final next = p.apply(original);
        next.validate();
        expect(next.letter, true);
        expect(next.author, 'Ada');
        expect(next.header, 'Research');
        expect(next.canvasDetails, true);
        expect(p.matches(next), true);
        for (var level = 1; level <= 6; level++) {
          expect(next.headingSize(level), greaterThan(next.fontSize));
        }
      }
      expect(PublicationPreset.compact.apply(original).contents, false);
      expect(PublicationPreset.reading.apply(original).fontSize, 16);
    },
  );
  test(
    'large print retains long headings and table cells across pages and formats',
    () async {
      expect(await initPdfTesting(), true);
      final heading = List.filled(55, 'Readable heading').join(' ');
      final body =
          '# $heading\n\n## Section\n\n| Item | Detail |\n| --- | --- |\n${List.generate(45, (i) => '| Row $i | Description $i with complete readable content. |').join('\n')}\n\n###### Final heading\n\nEND_SENTINEL';
      final style = PublicationPreset.reading.apply(const PublicationStyle());
      final export = PublicationExport(
        PublicationDocument.parse('Reading sample', body, style),
      );
      final bytes = await export.pdf();
      final pdf = await PdfDocument.openData(bytes);
      try {
        final text = [
          for (final p in pdf.pages) (await p.loadText())!.fullText,
        ].join('\n');
        expect(text, contains('Row 44'));
        expect(text, contains('END_SENTINEL'));
        expect(text, contains('Final heading'));
        expect(pdf.pages.length, greaterThan(2));
      } finally {
        await pdf.dispose();
      }
      expect(export.html(), contains('h6{font-size:18.0pt}'));
      final zip = ZipDecoder().decodeBytes(export.docx());
      final xml = utf8.decode(
        zip.files.singleWhere((f) => f.name == 'word/styles.xml').content
            as List<int>,
      );
      expect(xml, contains('<w:sz w:val="36"/>'));
      final dir = Directory('.local/pdf-profile-qa')
        ..createSync(recursive: true);
      File('${dir.path}/large-reading.pdf').writeAsBytesSync(bytes);
    },
  );
  testWidgets('compact preset stays a draft until explicitly saved', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    String? saved;
    await t.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: PublicationWorkspace(
          title: 'Report',
          source: '# Chapter\n\nParagraph',
          previewBuilder: (_) => const Text('Prepared'),
          onApply: (_, next) {
            saved = next;
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
        final dynamic state = t.state(find.byType(PublicationWorkspace));
        if (state.ready != null && state.busy == false) {
          return;
        }
      }
      fail('Preview unavailable');
    }

    await ready();
    await t.tap(find.text('Document style'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Document style presets'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Compact handout'));
    await t.tap(find.text('Compact handout'));
    await t.pump(const Duration(milliseconds: 350));
    await ready();
    expect(saved, isNull);
    expect(find.text('Body text · 10 pt'), findsOneWidget);
    await t.ensureVisible(find.text('Start every Heading 1 on a new page'));
    await t.tap(find.text('Start every Heading 1 on a new page'));
    await t.pump(const Duration(milliseconds: 350));
    await ready();
    await t.ensureVisible(find.text('Save settings to note'));
    await t.tap(find.text('Save settings to note'));
    await t.pumpAndSettle();
    expect(saved, contains('"contents":false'));
    expect(saved, contains('"fontSize":10.0'));
    expect(saved, contains('"h1PageBreaks":true'));
    expect(t.takeException(), isNull);
  });
}
