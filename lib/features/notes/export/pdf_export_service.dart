import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../platform/export_file.dart';
import '../latex/latex_document.dart';

/// Pure-Dart PDF generator producing standard %PDF-1.4 documents.
/// Zero external native C++ dependencies, 100% offline, cross-platform.
class PdfExportService {
  /// Generate a PDF document from a structured LaTeX document
  static Uint8List generateLatexPdf(LatexDocument doc) {
    final isA4 = doc.paperSize != 'letterpaper';
    final pageWidth = isA4 ? 595.28 : 612.0;
    final pageHeight = isA4 ? 841.89 : 792.0;
    final margin = doc.margins.contains('2cm')
        ? 56.7
        : 72.0; // 1in = 72pt, 2cm = 56.7pt
    final printableWidth = pageWidth - (margin * 2);

    final builder = _PdfBuilder(
      pageWidth: pageWidth,
      pageHeight: pageHeight,
      margin: margin,
      printableWidth: printableWidth,
    );

    // Title & Header
    if (doc.title.isNotEmpty) {
      builder.addHeading(
        doc.title,
        20,
        isBold: true,
        isCentered: true,
        spaceAfter: 8,
      );
    }
    if (doc.author.isNotEmpty) {
      builder.addHeading(
        doc.author,
        12,
        isBold: false,
        isCentered: true,
        spaceAfter: 4,
      );
    }
    if (doc.date.isNotEmpty) {
      builder.addHeading(
        doc.date,
        10,
        isItalic: true,
        isCentered: true,
        spaceAfter: 16,
      );
    }

    if (doc.abstractText.isNotEmpty) {
      builder.addHeading(
        'Abstract',
        11,
        isBold: true,
        isCentered: true,
        spaceAfter: 6,
      );
      builder.addParagraph(
        doc.abstractText,
        9.5,
        isItalic: true,
        indent: 24,
        spaceAfter: 18,
      );
    }

    int secNum = 0;
    int subsecNum = 0;
    int subsubsecNum = 0;
    int eqNum = 0;
    int thmNum = 0;
    int defNum = 0;

    for (final block in doc.blocks) {
      switch (block.type) {
        case LatexBlockType.section:
          secNum++;
          subsecNum = 0;
          subsubsecNum = 0;
          final prefix = block.numbered ? '$secNum. ' : '';
          builder.addHeading(
            '$prefix${block.rawContent}',
            14,
            isBold: true,
            spaceBefore: 14,
            spaceAfter: 6,
          );
          break;

        case LatexBlockType.subsection:
          subsecNum++;
          subsubsecNum = 0;
          final prefix = block.numbered ? '$secNum.$subsecNum ' : '';
          builder.addHeading(
            '$prefix${block.rawContent}',
            12,
            isBold: true,
            spaceBefore: 10,
            spaceAfter: 4,
          );
          break;

        case LatexBlockType.subsubsection:
          subsubsecNum++;
          final prefix = block.numbered
              ? '$secNum.$subsecNum.$subsubsecNum '
              : '';
          builder.addHeading(
            '$prefix${block.rawContent}',
            10.5,
            isBold: true,
            spaceBefore: 8,
            spaceAfter: 4,
          );
          break;

        case LatexBlockType.paragraph:
          builder.addParagraph(block.rawContent, 10, spaceAfter: 8);
          break;

        case LatexBlockType.equation:
          eqNum++;
          final isNumbered =
              block.environment != 'equation*' && block.environment != 'align*';
          builder.addEquation(
            block.rawContent,
            eqNumber: isNumbered ? eqNum : null,
          );
          break;

        case LatexBlockType.aligned:
          eqNum++;
          builder.addEquation(
            block.rawContent,
            eqNumber: block.environment != 'align*' ? eqNum : null,
          );
          break;

        case LatexBlockType.theorem:
          final env = block.environment.toLowerCase();
          final isThm =
              env.contains('theorem') ||
              env.contains('lemma') ||
              env.contains('prop') ||
              env.contains('cor');
          if (isThm) {
            thmNum++;
          } else {
            defNum++;
          }
          final count = isThm ? thmNum : defNum;
          final capitalized = env.isNotEmpty
              ? '${env[0].toUpperCase()}${env.substring(1)}'
              : 'Theorem';
          final title = block.options.isNotEmpty
              ? '$capitalized $count (${block.options})'
              : '$capitalized $count';
          builder.addTheoremBox(
            title: title,
            body: block.rawContent,
            isItalic: isThm,
          );
          break;

        case LatexBlockType.proof:
          final title = block.options.isNotEmpty
              ? 'Proof (${block.options}).'
              : 'Proof.';
          builder.addProof(title: title, body: block.rawContent);
          break;

        case LatexBlockType.table:
          builder.addTable(block.rawContent, caption: block.caption);
          break;

        case LatexBlockType.figure:
          builder.addFigure(
            imagePath: block.imagePath ?? '',
            caption: block.caption,
          );
          break;

        case LatexBlockType.list:
          final isEnumerate = block.environment == 'enumerate';
          final items = block.rawContent
              .split(RegExp(r'\\item\b'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
          for (var i = 0; i < items.length; i++) {
            final prefix = isEnumerate ? '${i + 1}. ' : '• ';
            builder.addParagraph(
              '$prefix${items[i]}',
              10,
              indent: 16,
              spaceAfter: 3,
            );
          }
          builder.addSpacing(6);
          break;

        case LatexBlockType.pageBreak:
          builder.newPage();
          break;

        case LatexBlockType.comment:
        case LatexBlockType.preamble:
        case LatexBlockType.title:
          break;

        case LatexBlockType.raw:
          if (block.rawContent.trim().isNotEmpty) {
            builder.addParagraph(block.rawContent, 10, spaceAfter: 8);
          }
          break;
      }
    }

    return builder.build();
  }

  /// Generate a PDF document from a Markdown note
  static Uint8List generateMarkdownPdf({
    required String title,
    required String body,
  }) {
    final builder = _PdfBuilder(
      pageWidth: 595.28,
      pageHeight: 841.89,
      margin: 72.0,
      printableWidth: 595.28 - 144.0,
    );

    if (title.isNotEmpty) {
      builder.addHeading(title, 20, isBold: true, spaceAfter: 16);
    }

    final lines = body.split('\n');
    var inCodeBlock = false;
    final codeBuffer = StringBuffer();

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.startsWith('```')) {
        if (inCodeBlock) {
          builder.addCodeBlock(codeBuffer.toString());
          codeBuffer.clear();
          inCodeBlock = false;
        } else {
          inCodeBlock = true;
        }
        continue;
      }

      if (inCodeBlock) {
        codeBuffer.writeln(line);
        continue;
      }

      if (line.startsWith('# ')) {
        builder.addHeading(
          line.substring(2).trim(),
          16,
          isBold: true,
          spaceBefore: 14,
          spaceAfter: 6,
        );
      } else if (line.startsWith('## ')) {
        builder.addHeading(
          line.substring(3).trim(),
          13,
          isBold: true,
          spaceBefore: 10,
          spaceAfter: 4,
        );
      } else if (line.startsWith('### ')) {
        builder.addHeading(
          line.substring(4).trim(),
          11,
          isBold: true,
          spaceBefore: 8,
          spaceAfter: 4,
        );
      } else if (line.startsWith(r'$$') &&
          line.endsWith(r'$$') &&
          line.length > 4) {
        builder.addEquation(line.substring(2, line.length - 2).trim());
      } else if (line.trim().startsWith('- ') || line.trim().startsWith('* ')) {
        builder.addParagraph(
          '• ${line.trim().substring(2).trim()}',
          10,
          indent: 16,
          spaceAfter: 3,
        );
      } else if (line.trim().isNotEmpty) {
        builder.addParagraph(line.trim(), 10, spaceAfter: 8);
      } else {
        builder.addSpacing(4);
      }
    }

    if (inCodeBlock && codeBuffer.isNotEmpty) {
      builder.addCodeBlock(codeBuffer.toString());
    }

    return builder.build();
  }

  /// Export document as PDF file
  static Future<bool> exportDocument({
    required BuildContext context,
    required String title,
    required String body,
    bool isLatex = false,
  }) async {
    try {
      final Uint8List bytes;
      if (isLatex) {
        final doc = LatexDocument.fromLatex(body);
        bytes = generateLatexPdf(doc);
      } else {
        bytes = generateMarkdownPdf(title: title, body: body);
      }

      final safeName =
          '${title.isEmpty ? "Document" : title.replaceAll(RegExp(r'[\\/:*?"<>|]'), "_")}.pdf';
      final exported = await exportBinaryFile(
        safeName,
        bytes,
        mimeType: 'application/pdf',
      );

      if (exported && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported "$safeName" successfully')),
        );
      }
      return exported;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to export PDF: $e')));
      }
      return false;
    }
  }
}

/// Internal PDF stream builder
class _PdfBuilder {
  _PdfBuilder({
    required this.pageWidth,
    required this.pageHeight,
    required this.margin,
    required this.printableWidth,
  }) {
    _currentY = pageHeight - margin;
  }

  final double pageWidth;
  final double pageHeight;
  final double margin;
  final double printableWidth;

  final List<StringBuffer> _pages = [StringBuffer()];
  int _currentPageIndex = 0;
  late double _currentY;

  StringBuffer get _currentStream => _pages[_currentPageIndex];

  void newPage() {
    _pages.add(StringBuffer());
    _currentPageIndex++;
    _currentY = pageHeight - margin;
  }

  void _checkPageOverflow(double neededHeight) {
    if (_currentY - neededHeight < margin) {
      newPage();
    }
  }

  void addSpacing(double height) {
    _currentY -= height;
    _checkPageOverflow(0);
  }

  void addHeading(
    String text,
    double fontSize, {
    bool isBold = false,
    bool isItalic = false,
    bool isCentered = false,
    double spaceBefore = 0,
    double spaceAfter = 4,
  }) {
    _checkPageOverflow(fontSize + spaceBefore + spaceAfter);
    _currentY -= spaceBefore;

    final fontName = isBold ? '/F2' : (isItalic ? '/F3' : '/F1');
    final clean = _sanitize(text);

    _currentStream.writeln('BT');
    _currentStream.writeln('$fontName $fontSize Tf');

    final estWidth = clean.length * fontSize * 0.52;
    final x = isCentered
        ? (margin + (printableWidth - estWidth) / 2).clamp(
            margin,
            pageWidth - margin,
          )
        : margin;

    _currentStream.writeln('$x $_currentY Td');
    _currentStream.writeln('($clean) Tj');
    _currentStream.writeln('ET');

    _currentY -= (fontSize * 1.3 + spaceAfter);
  }

  void addParagraph(
    String text,
    double fontSize, {
    bool isItalic = false,
    double indent = 0,
    double spaceAfter = 6,
  }) {
    final fontName = isItalic ? '/F3' : '/F1';
    final lineHeight = fontSize * 1.45;
    final wrapWidth = printableWidth - indent;
    final lines = _wrapText(text, fontSize, wrapWidth);

    _checkPageOverflow(lines.length * lineHeight + spaceAfter);

    for (final line in lines) {
      final clean = _sanitize(line);
      _currentStream.writeln('BT');
      _currentStream.writeln('$fontName $fontSize Tf');
      _currentStream.writeln('${margin + indent} $_currentY Td');
      _currentStream.writeln('($clean) Tj');
      _currentStream.writeln('ET');
      _currentY -= lineHeight;
    }

    _currentY -= spaceAfter;
  }

  void addEquation(String latex, {int? eqNumber}) {
    final fontSize = 11.0;
    final height = 28.0;
    _checkPageOverflow(height + 12);
    _currentY -= 6;

    final clean = _sanitize(latex);
    final estWidth = clean.length * fontSize * 0.5;
    final x = (margin + (printableWidth - estWidth) / 2).clamp(
      margin,
      pageWidth - margin,
    );

    // Centered equation in Courier/Italic
    _currentStream.writeln('BT');
    _currentStream.writeln('/F4 $fontSize Tf');
    _currentStream.writeln('$x $_currentY Td');
    _currentStream.writeln('($clean) Tj');
    _currentStream.writeln('ET');

    // Equation number on the right
    if (eqNumber != null) {
      final numStr = '($eqNumber)';
      final numX = pageWidth - margin - (numStr.length * 7.0);
      _currentStream.writeln('BT');
      _currentStream.writeln('/F1 10 Tf');
      _currentStream.writeln('$numX $_currentY Td');
      _currentStream.writeln('($numStr) Tj');
      _currentStream.writeln('ET');
    }

    _currentY -= (height + 6);
  }

  void addTheoremBox({
    required String title,
    required String body,
    bool isItalic = false,
  }) {
    final lines = _wrapText(body, 10, printableWidth - 24);
    final boxHeight = 24.0 + (lines.length * 14.5) + 12.0;

    _checkPageOverflow(boxHeight + 10);
    _currentY -= 6;

    final topY = _currentY;
    final bottomY = topY - boxHeight;

    // Draw left vertical bar (2pt wide)
    _currentStream.writeln('0.55 0.49 0.96 RG'); // Orbit violet
    _currentStream.writeln('2 w');
    _currentStream.writeln('$margin $bottomY m $margin $topY l S');
    _currentStream.writeln('0 0 0 RG'); // Reset color to black

    _currentY -= 14;
    // Title
    _currentStream.writeln('BT');
    _currentStream.writeln('/F2 10.5 Tf');
    _currentStream.writeln('${margin + 12} $_currentY Td');
    _currentStream.writeln('(${_sanitize(title)}) Tj');
    _currentStream.writeln('ET');

    _currentY -= 14;

    // Body
    final fontName = isItalic ? '/F3' : '/F1';
    for (final line in lines) {
      _currentStream.writeln('BT');
      _currentStream.writeln('$fontName 10 Tf');
      _currentStream.writeln('${margin + 12} $_currentY Td');
      _currentStream.writeln('(${_sanitize(line)}) Tj');
      _currentStream.writeln('ET');
      _currentY -= 14.5;
    }

    _currentY -= 10;
  }

  void addProof({required String title, required String body}) {
    addHeading(title, 10.5, isItalic: true, spaceBefore: 4, spaceAfter: 4);
    addParagraph(body, 10, indent: 12, spaceAfter: 4);

    // QED tombstone
    final x = pageWidth - margin - 14;
    _currentStream.writeln('BT');
    _currentStream.writeln('/F2 11 Tf');
    _currentStream.writeln('$x $_currentY Td');
    _currentStream.writeln('(Q.E.D.) Tj');
    _currentStream.writeln('ET');
    _currentY -= 14;
  }

  void addCodeBlock(String code) {
    final lines = code.split('\n');
    final blockHeight = lines.length * 13.0 + 16.0;
    _checkPageOverflow(blockHeight + 8);

    _currentY -= 4;
    for (final line in lines) {
      _currentStream.writeln('BT');
      _currentStream.writeln('/F4 9.5 Tf');
      _currentStream.writeln('${margin + 8} $_currentY Td');
      _currentStream.writeln('(${_sanitize(line)}) Tj');
      _currentStream.writeln('ET');
      _currentY -= 13.0;
    }
    _currentY -= 6;
  }

  void addTable(String rawContent, {String? caption}) {
    final rows = rawContent
        .split(r'\\')
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty && !r.startsWith(r'\hline'))
        .toList();
    if (rows.isEmpty) return;

    final grid = rows
        .map((r) => r.split('&').map((c) => c.trim()).toList())
        .toList();
    final colCount = grid.first.length;
    if (colCount == 0) return;

    final colWidth = printableWidth / colCount;
    final rowHeight = 18.0;
    final tableHeight =
        grid.length * rowHeight + (caption != null ? 24.0 : 8.0);

    _checkPageOverflow(tableHeight);

    for (var r = 0; r < grid.length; r++) {
      final y = _currentY;
      for (var c = 0; c < grid[r].length; c++) {
        final x = margin + (c * colWidth);
        final cellText = _sanitize(grid[r][c]);
        _currentStream.writeln('BT');
        _currentStream.writeln('${r == 0 ? '/F2' : '/F1'} 9.5 Tf');
        _currentStream.writeln('${x + 4} ${y - 12} Td');
        _currentStream.writeln('($cellText) Tj');
        _currentStream.writeln('ET');
      }
      _currentY -= rowHeight;
    }

    if (caption != null && caption.isNotEmpty) {
      addHeading(
        'Table: $caption',
        9,
        isItalic: true,
        isCentered: true,
        spaceBefore: 4,
        spaceAfter: 6,
      );
    } else {
      _currentY -= 8;
    }
  }

  void addFigure({required String imagePath, String? caption}) {
    final height = 48.0;
    _checkPageOverflow(height + 20);

    _currentY -= 8;
    // Figure placeholder box
    _currentStream.writeln('0.85 0.85 0.85 rg');
    _currentStream.writeln(
      '$margin ${_currentY - height} $printableWidth $height re f',
    );
    _currentStream.writeln('0 0 0 rg');

    _currentStream.writeln('BT');
    _currentStream.writeln('/F4 9 Tf');
    _currentStream.writeln('${margin + 16} ${_currentY - 26} Td');
    _currentStream.writeln('([Figure: ${_sanitize(imagePath)}]) Tj');
    _currentStream.writeln('ET');

    _currentY -= (height + 6);
    if (caption != null && caption.isNotEmpty) {
      addHeading(
        'Figure: $caption',
        9,
        isItalic: true,
        isCentered: true,
        spaceAfter: 6,
      );
    }
  }

  List<String> _wrapText(String text, double fontSize, double maxWidth) {
    final words = text.split(RegExp(r'\s+'));
    final lines = <String>[];
    var curLine = StringBuffer();
    final maxChars = (maxWidth / (fontSize * 0.52)).floor();

    for (final w in words) {
      if (curLine.length + w.length + 1 > maxChars && curLine.isNotEmpty) {
        lines.add(curLine.toString());
        curLine = StringBuffer();
      }
      if (curLine.isNotEmpty) curLine.write(' ');
      curLine.write(w);
    }
    if (curLine.isNotEmpty) lines.add(curLine.toString());
    return lines.isEmpty ? [''] : lines;
  }

  String _sanitize(String text) {
    return text
        .replaceAll(r'\', r'\\')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)')
        .replaceAll(RegExp(r'[\r\n]+'), ' ');
  }

  Uint8List build() {
    // Add page numbers at bottom of each page
    final totalPages = _pages.length;
    for (var p = 0; p < totalPages; p++) {
      final numStr = '${p + 1}';
      final stream = _pages[p];
      stream.writeln('BT');
      stream.writeln('/F1 9 Tf');
      stream.writeln('${pageWidth / 2 - 4} 36 Td');
      stream.writeln('($numStr) Tj');
      stream.writeln('ET');
    }

    final out = BytesBuilder();
    final offsets = <int>[];

    void write(String s) {
      final bytes = utf8.encode(s);
      out.add(bytes);
    }

    write('%PDF-1.4\n%OrbitNote\n');

    // 1: Catalog
    offsets.add(out.length);
    write('1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');

    // 2: Pages root
    offsets.add(out.length);
    final pageObjectRefs = List.generate(
      totalPages,
      (i) => '${7 + i * 2} 0 R',
    ).join(' ');
    write(
      '2 0 obj\n<< /Type /Pages /Kids [$pageObjectRefs] /Count $totalPages >>\nendobj\n',
    );

    // Fonts: 3: Times-Roman, 4: Times-Bold, 5: Times-Italic, 6: Courier
    // Let's declare standard type 1 fonts
    offsets.add(out.length);
    write(
      '3 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Times-Roman >>\nendobj\n',
    );

    offsets.add(out.length);
    write(
      '4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Times-Bold >>\nendobj\n',
    );

    offsets.add(out.length);
    write(
      '5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Times-Italic >>\nendobj\n',
    );

    offsets.add(out.length);
    write(
      '6 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>\nendobj\n',
    );

    // Next object index starts at 7
    var nextObj = 7;
    for (var p = 0; p < totalPages; p++) {
      final pageObj = nextObj++;
      final contentObj = nextObj++;

      final contentBytes = utf8.encode(_pages[p].toString());

      // Page object
      offsets.add(out.length);
      write(
        '$pageObj 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $pageWidth $pageHeight]\n'
        '/Contents $contentObj 0 R\n'
        '/Resources << /Font << /F1 3 0 R /F2 4 0 R /F3 5 0 R /F4 6 0 R >> >> >>\nendobj\n',
      );

      // Content object
      offsets.add(out.length);
      write(
        '$contentObj 0 obj\n<< /Length ${contentBytes.length} >>\nstream\n',
      );
      out.add(contentBytes);
      write('\nendstream\nendobj\n');
    }

    final startXref = out.length;
    final totalObjects = offsets.length + 1; // 0th is free object

    write('xref\n0 $totalObjects\n0000000000 65535 f \n');
    for (final off in offsets) {
      write('${off.toString().padLeft(10, '0')} 00000 n \n');
    }

    write(
      'trailer\n<< /Size $totalObjects /Root 1 0 R >>\nstartxref\n$startXref\n%%EOF\n',
    );

    return out.toBytes();
  }
}
