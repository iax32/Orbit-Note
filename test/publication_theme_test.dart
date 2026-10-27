import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/domain/document_publication.dart';
import 'package:orbit_note/domain/note_writing_appearance.dart';
import 'package:orbit_note/domain/writing_photo.dart';
import 'package:orbit_note/features/notes/export/publication_theme.dart';
import 'package:orbit_note/features/notes/export/publication_export.dart';
import 'package:orbit_note/features/notes/export/publication_workspace.dart';
import 'support/pdf_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'private photo renders with its reading sheet and is captured only once',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 20, 20),
        Paint()..color = const Color(0xffff0000),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(20, 20);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      image.dispose();
      picture.dispose();
      var reads = 0;
      final look = NoteWritingAppearance(
        photo: WritingPhoto(id: 'a' * 64, opacity: 1),
      );
      final theme = PublicationPdfTheme(
        orbitTheme(preset: 'paper'),
        appearance: look,
        readPhoto: (_) async {
          reads++;
          return bytes;
        },
      );
      final warnings = <String>[];
      final png = await theme.page(200, 280, 40, 11, warnings.add);
      await theme.page(220, 300, 40, 11, warnings.add);
      expect(reads, 1);
      expect(warnings, isEmpty);
      final codec = await ui.instantiateImageCodec(png);
      final frame = await codec.getNextFrame();
      final pixels = (await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final edge = (100 * 600 + 10) * 4;
      expect(pixels.getUint8(edge), 255);
      expect(pixels.getUint8(edge + 1), 0);
      final center = (100 * 600 + 300) * 4;
      expect(pixels.getUint8(center + 1), greaterThan(150));
      frame.image.dispose();
      codec.dispose();
      expect(look.photo!.id, 'a' * 64);
    },
  );
  test(
    'missing photo keeps the page design and high contrast never reads a photo',
    () async {
      final look = NoteWritingAppearance(
        design: WritingDesign.pixelBook,
        photo: WritingPhoto(id: 'b' * 64),
      );
      final warnings = <String>[];
      var reads = 0;
      final theme = PublicationPdfTheme(
        orbitTheme(preset: 'paper'),
        appearance: look,
        readPhoto: (_) async {
          reads++;
          return null;
        },
      );
      expect(await theme.page(200, 280, 40, 11, warnings.add), isNotEmpty);
      expect(warnings.single, contains('photo unavailable'));
      final contrast = PublicationPdfTheme(
        orbitTheme(preset: 'paper'),
        appearance: look,
        highContrast: true,
        readPhoto: (_) async {
          reads++;
          return null;
        },
      );
      await contrast.page(200, 280, 40, 11, warnings.add);
      expect(reads, 1);
    },
  );
  test(
    'all editor designs reuse a complete bounded page surface and exact palette',
    () async {
      for (final design in WritingDesign.values) {
        final appearance = NoteWritingAppearance(
          design: design,
          paper: WritingPaper.ruled,
        );
        final theme = PublicationPdfTheme(
          orbitTheme(preset: 'paper'),
          appearance: appearance,
        );
        final warnings = <String>[];
        final png = await theme.page(200, 280, 40, 11, warnings.add);
        final cached = await theme.page(200, 280, 40, 11, warnings.add);
        expect(identical(png, cached), true);
        final codec = await ui.instantiateImageCodec(png);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 600);
        expect(frame.image.height, 840);
        frame.image.dispose();
        codec.dispose();
        expect(warnings, isEmpty);
      }
    },
  );
  test(
    'pixel book, warm grid and CRT preserve searchable content on every PDF page',
    () async {
      expect(await initPdfTesting(), true);
      final base = orbitTheme(preset: 'paper');
      for (final design in [
        WritingDesign.pixelBook,
        WritingDesign.orbit,
        WritingDesign.crt,
      ]) {
        final look = PublicationPdfTheme(
          base,
          appearance: NoteWritingAppearance(
            design: design,
            paper: WritingPaper.grid,
          ),
        );
        final source =
            '# Heading\n\n${List.generate(24, (i) => 'Paragraph $i. ${'Readable content ' * 20}\n\n').join()}\nLAST_SENTINEL';
        final doc = PublicationDocument.parse(
          'Theme test',
          source,
          const PublicationStyle(contents: false, margin: 24),
        );
        final exp = PublicationExport(doc, pdfTheme: look);
        final data = await exp.pdf();
        final pdf = await PdfDocument.openData(data);
        try {
          expect(pdf.pages.length, greaterThan(1));
          final all = [
            for (final page in pdf.pages) (await page.loadText())!.fullText,
          ].join();
          expect(all, contains('LAST_SENTINEL'));
          expect(all, contains('Heading'));
          for (final page in pdf.pages) {
            final rendered = await page.render(width: 300, height: 424);
            expect(rendered, isNotNull);
            rendered!.dispose();
            final text = (await page.loadText())!;
            for (final rect in text.charRects.where((r) => r.isNotEmpty)) {
              expect(
                rect.left,
                greaterThanOrEqualTo(design == WritingDesign.orbit ? 22 : 38),
              );
              expect(rect.right, lessThanOrEqualTo(page.width - 22));
            }
          }
          if (Platform.environment['ORBIT_THEME_PDF_PREVIEW'] == '1') {
            await Directory('.local/themed-pdf').create(recursive: true);
            await File(
              '.local/themed-pdf/${design.name}.pdf',
            ).writeAsBytes(data);
          }
        } finally {
          await pdf.dispose();
        }
      }
    },
  );
  testWidgets(
    'theme export opt-out stays reachable at narrow widths and large text',
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
            ).copyWith(textScaler: TextScaler.linear(1.6)),
            child: child!,
          ),
          home: PublicationWorkspace(
            title: 'Design',
            source: 'Text',
            pdfTheme: PublicationPdfTheme(orbitTheme(preset: 'paper')),
            previewBuilder: (_) => const Text('Prepared'),
          ),
        ),
      );
      for (var i = 0; i < 100; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await t.pump();
        if (find.text('Prepared').evaluate().isNotEmpty) break;
      }
      await t.tap(find.text('Document style'));
      await t.pumpAndSettle();
      expect(find.text('Use editor design in PDF'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
