import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/document_publication.dart';
import 'package:orbit_note/domain/publication_layout.dart';
import 'package:orbit_note/features/notes/export/publication_export.dart';
import 'package:orbit_note/features/notes/export/publication_math.dart';
import 'package:orbit_note/features/notes/export/publication_svg.dart';
import 'package:pdfrx/pdfrx.dart';
import 'support/pdf_fixture.dart';

Future<String> visibleText(Uint8List bytes, {double margin = 24}) async {
  expect(await initPdfTesting(), true);
  final pdf = await PdfDocument.openData(bytes);
  try {
    final texts = <String>[];
    for (final page in pdf.pages) {
      final text = (await page.loadText())!;
      texts.add(text.fullText);
      for (var i = 0; i < text.charRects.length; i++) {
        if (text.fullText[i].trim().isEmpty) continue;
        final rect = text.charRects[i];
        if (rect.isEmpty) continue;
        expect(
          rect.left,
          greaterThanOrEqualTo(margin - 2),
          reason: 'Left edge, page ${page.pageNumber}',
        );
        expect(
          rect.right,
          lessThanOrEqualTo(page.width - margin + 2),
          reason: 'Right edge, page ${page.pageNumber}',
        );
        expect(
          rect.bottom,
          greaterThanOrEqualTo(margin - 2),
          reason: 'Bottom edge, page ${page.pageNumber}',
        );
        expect(
          rect.top,
          lessThanOrEqualTo(page.height - margin + 2),
          reason: 'Top edge, page ${page.pageNumber}',
        );
      }
    }
    return texts.join('\n');
  } finally {
    await pdf.dispose();
  }
}

String passage(String prefix, int count) =>
    List.generate(count, (i) => '${prefix}token$i').join(' ');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in manifest.where(
      (entry) =>
          (entry['family'] as String).startsWith('packages/flutter_math_fork/'),
    )) {
      final loader = FontLoader(font['family'] as String);
      for (final face in font['fonts'] as List) {
        loader.addFont(rootBundle.load(face['asset'] as String));
      }
      await loader.load();
    }
  });
  test(
    'long formatted prose, list items, quotations and endnotes stay within pages',
    () async {
      final body =
          '''# Complete content

**${passage('prose', 700)}**

- ${passage('list', 500)}

> ${passage('quote', 350)}

Reference[^long].

[^long]: ${passage('foot', 400)}
''';
      for (final letter in [false, true]) {
        final export = PublicationExport(
          PublicationDocument.parse(
            'Pagination',
            body,
            PublicationStyle(
              letter: letter,
              margin: 90,
              fontSize: 18,
              contents: false,
            ),
          ),
        );
        final text = await visibleText(await export.pdf(), margin: 90);
        for (final entry in {
          'prose': 700,
          'list': 500,
          'quote': 350,
          'foot': 400,
        }.entries) {
          for (var i = 0; i < entry.value; i++) {
            expect(
              text,
              contains('${entry.key}token$i'),
              reason: '${entry.key}$i, Letter=$letter',
            );
          }
        }
      }
    },
  );

  test(
    'wide and over-height table cells use complete paginated records',
    () async {
      final source =
          '''# Tables

| Field | Observation |
| --- | --- |
| Long cell | ${passage('cell', 700)} |
| Last row | FINALTABLEROW |

| ${List.generate(10, (i) => 'Column$i').join(' | ')} |
| ${List.filled(10, '---').join(' | ')} |
| ${List.generate(10, (i) => 'VALUE$i').join(' | ')} |
''';
      final export = PublicationExport(
        PublicationDocument.parse(
          'Tables',
          source,
          const PublicationStyle(contents: false, fontSize: 18, margin: 90),
        ),
      );
      final text = await visibleText(await export.pdf(), margin: 90);
      for (var i = 0; i < 700; i++) {
        expect(text, contains('celltoken$i'));
      }
      for (var i = 0; i < 10; i++) {
        expect(text, contains('Column$i'));
        expect(text, contains('VALUE$i'));
      }
      expect(text, contains('FINALTABLEROW'));
      expect(export.warnings.any((w) => w.contains('labelled records')), true);
    },
  );

  test(
    'long code lines, ordered nested paragraphs and code keep their order',
    () async {
      final source =
          '''# Code

```cpp
${List.generate(150, (i) => 'line$i = call();').join('\n')}
ENDCODE
```

7. FIRSTPARAGRAPH

   SECONDPARAGRAPH

   - NESTEDITEM

   AFTERTHENESTEDITEM

   ```python
   ENDNESTEDCODE
   ```

8. LASTITEM

https://example.com/${'abcdefghij' * 75}/URLTAIL
''';
      final export = PublicationExport(
        PublicationDocument.parse(
          'Code',
          source,
          const PublicationStyle(contents: false),
        ),
      );
      final codePdf = await export.pdf();
      await Directory('tmp/pdfs').create(recursive: true);
      await File('tmp/pdfs/pdf-code-stress.pdf').writeAsBytes(codePdf);
      final text = await visibleText(codePdf, margin: 54);
      for (var i = 0; i < 150; i++) {
        expect(text, contains('line$i'));
      }
      expect(text, contains('ENDCODE'));
      expect(text.replaceAll(RegExp(r'\s'), ''), contains('URLTAIL'));
      var last = -1;
      for (final marker in [
        '7.',
        'FIRSTPARAGRAPH',
        'SECONDPARAGRAPH',
        'NESTEDITEM',
        'AFTERTHENESTEDITEM',
        'ENDNESTEDCODE',
        '8.',
        'LASTITEM',
      ]) {
        final index = text.indexOf(marker, last + 1);
        expect(index, greaterThan(last), reason: marker);
        last = index;
      }
    },
  );

  test(
    'long title, heading and contents flow without losing navigation',
    () async {
      final title = passage('title', 200);
      final heading = passage('heading', 200);
      final export = PublicationExport(
        PublicationDocument.parse(
          title,
          '# $heading\n\nBODYEND',
          const PublicationStyle(
            contents: true,
            titlePage: true,
            margin: 90,
            fontSize: 18,
          ),
        ),
      );
      final bytes = await export.pdf();
      final text = await visibleText(bytes, margin: 90);
      expect(text, contains('titletoken199'));
      expect(text, contains('headingtoken199'));
      expect(text, contains('BODYEND'));
      final page = export.headingPages['heading-1']!;
      final pdf = await PdfDocument.openData(bytes);
      try {
        expect(
          (await pdf.pages[page - 1].loadText())!.fullText,
          contains('headingtoken0'),
        );
        expect(
          (await pdf.pages[page - 1].loadText())!.fullText,
          isNot(contains('Contents')),
        );
        expect(
          (await Future.wait(
            pdf.pages.map((p) => p.loadLinks()),
          )).any((links) => links.isNotEmpty),
          true,
        );
      } finally {
        await pdf.dispose();
      }
    },
  );

  test(
    'tall figures and long captions fit, equations capture their full extent',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 100, 1800),
        ui.Paint()..color = const ui.Color(0xff176087),
      );
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 1750, 100, 50),
        ui.Paint()..color = const ui.Color(0xffff3d00),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(100, 1800);
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final bytes = png.buffer.asUint8List(
        png.offsetInBytes,
        png.lengthInBytes,
      );
      image.dispose();
      picture.dispose();
      const source = '![Tall](Attachments/tall.png)\n\nAFTERFIGURE';
      final parsed = PublicationDocument.parse(
        'Figures',
        source,
        const PublicationStyle(),
      );
      final key = publicationLayoutKey(parsed.nodes.first);
      final layouts = {
        key: PublicationBlockLayout(
          width: 25,
          caption: passage('caption', 100),
        ).toJson(),
      };
      final equation = List.filled(15, r'x^2 + y^2').join(' + ');
      final rendered = await renderPublicationMath(equation);
      final data = ByteData.sublistView(rendered);
      expect(
        data.getUint32(16),
        greaterThan(2000),
        reason: 'full formula extends beyond old fixed viewport',
      );
      final export = PublicationExport(
        PublicationDocument.parse(
          'Figures',
          '$source\n\n\u0024\u0024\n$equation\n\u0024\u0024\n\nAFTERMATH',
          const PublicationStyle(contents: false),
          layouts: layouts,
        ),
        images: {'Attachments/tall.png': bytes},
        equations: {equation: rendered},
      );
      final output = await export.pdf();
      final text = await visibleText(output, margin: 54);
      expect(text, contains('captiontoken99'));
      expect(text, contains('AFTERFIGURE'));
      expect(text, contains('AFTERMATH'));
      final pdf = await PdfDocument.openData(output);
      var blue = 0, red = 0;
      try {
        for (final page in pdf.pages) {
          final rendered = (await page.render(width: 595, height: 842))!;
          final image = await rendered.createImage();
          try {
            final rgba = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final pixels = rgba.buffer.asUint8List(
              rgba.offsetInBytes,
              rgba.lengthInBytes,
            );
            for (var i = 0; i < pixels.length; i += 4) {
              if (pixels[i] < 60 && pixels[i + 1] > 60 && pixels[i + 2] > 100) {
                blue++;
              }
              if (pixels[i] > 200 &&
                  pixels[i + 1] < 100 &&
                  pixels[i + 2] < 60) {
                red++;
              }
            }
          } finally {
            image.dispose();
            rendered.dispose();
          }
        }
      } finally {
        await pdf.dispose();
      }
      expect(blue, greaterThan(5000));
      expect(
        red,
        greaterThan(20),
        reason: 'the bottom of the tall figure is visible',
      );

      await Directory('tmp/pdfs').create(recursive: true);
      await File('tmp/pdfs/pdf-content-stress.pdf').writeAsBytes(output);
    },
  );

  test(
    'unsupported oversized math reports fallback instead of cropping',
    () async {
      await expectLater(
        renderPublicationMath(List.filled(300, 'x').join(' + ')),
        throwsFormatException,
      );
    },
  );
  testWidgets('page limit is explicit and refuses a partial PDF', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final export = PublicationExport(
        PublicationDocument.parse(
          'Bounded',
          List.generate(
            501,
            (i) => 'Page $i',
          ).join('\n\n<!-- orbit:pagebreak -->\n\n'),
          const PublicationStyle(contents: false),
        ),
      );
      Object? failure;
      try {
        await export.pdf();
      } catch (error) {
        failure = error;
      }
      expect(
        failure,
        isA<FormatException>().having(
          (e) => e.message,
          'limit',
          contains('500 pages'),
        ),
      );
    });
    expect(tester.takeException(), isNull);
  });

  test(
    'mixed article preserves headings, tables, math, code, footnotes and font fallback',
    () async {
      const equation = r'\frac{a}{b}=x^2';
      final math = await renderPublicationMath(equation);
      final source = r"""# Research report

A readable report with **strong text**, *emphasis*, `inlineCode()` and a [source](https://example.com).

## Findings

| Test | Outcome |
| --- | --- |
| Input | Visible content |
| Output | Final row retained |

- FIRSTITEM
  - SECONDLEVEL
- LASTITEM

```cpp
void render() {
    // Preserve indentation and complete lines.
    draw_image();
}
```

$$
\frac{a}{b}=x^2
$$

Greek α β, inequalities ≤ ≥ and infinity ∞ stay visible.[^note]

[^note]: Source note with café and a final ENDNOTE marker.
""";
      for (final serif in [false, true]) {
        final export = PublicationExport(
          PublicationDocument.parse(
            'Research report',
            source,
            PublicationStyle(
              serif: serif,
              header: 'Orbit Note · Research',
              contents: true,
            ),
          ),
          equations: {equation: math},
        );
        final bytes = await export.pdf();
        final text = await visibleText(bytes, margin: 54);
        expect(text, contains('Final row retained'));
        expect(text, contains('ENDNOTE'));
        expect(text, contains('α'));
        expect(text, contains('∞'));
        expect(export.warnings.any((w) => w.contains('PDF font lacks')), false);
        await Directory('tmp/pdfs').create(recursive: true);
        await File(
          'tmp/pdfs/pdf-article-${serif ? 'serif' : 'sans'}.pdf',
        ).writeAsBytes(bytes);
      }
    },
  );
  test(
    'static SVG diagrams become bounded image resources, active sources are refused',
    () async {
      final source = Uint8List.fromList(
        utf8.encode(
          '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="200" viewBox="0 0 400 200"><rect width="400" height="200" fill="#176087"/><circle cx="360" cy="100" r="30" fill="#ff3d00"/></svg>',
        ),
      );
      expect(isPublicationSvg(source), true);
      final bytes = await renderPublicationSvg(source);
      expect(ByteData.sublistView(bytes).getUint32(16), 400);
      expect(ByteData.sublistView(bytes).getUint32(20), 200);
      final export = PublicationExport(
        PublicationDocument.parse(
          'Diagram',
          '![Diagram](diagram.svg)\n\nAFTERSVG',
          const PublicationStyle(contents: false),
        ),
        images: {'diagram.svg': bytes},
      );
      final output = await export.pdf();
      expect(await visibleText(output, margin: 54), contains('AFTERSVG'));
      await File('tmp/pdfs/pdf-svg-diagram.pdf').writeAsBytes(output);
      for (final unsafe in [
        '<svg><image href="https://example.com/private.png"/></svg>',
        '<svg><script>fetch("https://example.com")</script></svg>',
        '<svg><foreignObject>HTML</foreignObject></svg>',
        '<!DOCTYPE svg [<!ENTITY x SYSTEM "file:///secret">]><svg/>',
        '<svg><filter id="blur"/></svg>',
      ]) {
        await expectLater(
          renderPublicationSvg(Uint8List.fromList(utf8.encode(unsafe))),
          throwsFormatException,
        );
      }
    },
  );
}
