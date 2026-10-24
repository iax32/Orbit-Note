import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../domain/document_publication.dart';
import '../../../domain/publication_layout.dart';
import '../../../domain/technical_article.dart';

PublicationBlockLayout publicationBlockLayout(md.Element node) =>
    PublicationBlockLayout.fromJson({
      'width': int.tryParse(node.attributes['orbit-width'] ?? '') ?? 100,
      'alignment': node.attributes['orbit-alignment'] ?? 'left',
      'caption': node.attributes['orbit-caption'] ?? '',
      'pageBreakBefore': node.attributes['orbit-pageBreakBefore'] == 'true',
      'repeatHeader': node.attributes['orbit-repeatHeader'] != 'false',
    });

class _PublicationAnchor extends pw.Anchor {
  _PublicationAnchor({
    required super.name,
    required super.child,
    required this.pages,
  });
  final Map<String, int> pages;
  @override
  void paint(pw.Context context) {
    if (pages.containsKey(name)) {
      paintChild(context);
    } else {
      pages[name] = context.pageNumber;
      super.paint(context);
    }
  }
}

double _imageHeight(Uint8List bytes, double width, double maxHeight) {
  final png = bytes.length >= 24 && bytes[0] == 137
      ? ByteData.sublistView(bytes)
      : null;
  final ratio = (png?.getUint32(20) ?? 250) / (png?.getUint32(16) ?? 400);
  return (width * ratio).clamp(1, maxHeight).toDouble();
}

double _imageWidth(Uint8List bytes, double width, double maxHeight) {
  final png = bytes.length >= 24 && bytes[0] == 137
      ? ByteData.sublistView(bytes)
      : null;
  final ratio = (png?.getUint32(20) ?? 250) / (png?.getUint32(16) ?? 400);
  return width.clamp(1, maxHeight / ratio).toDouble();
}

String publicationEscape(String text) => const HtmlEscape().convert(text);
String publicationFileName(String title) {
  final name = title.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_').trim();
  return name.isEmpty
      ? 'Document'
      : name.substring(0, name.length.clamp(0, 100));
}

bool safePublicationLink(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      (uri.scheme == 'https' ||
          uri.scheme == 'http' ||
          uri.scheme == 'mailto' ||
          (uri.scheme.isEmpty && value.startsWith('#')));
}

class PublicationExport {
  PublicationExport(
    this.document, {
    this.images = const {},
    this.equations = const {},
    List<String> warnings = const [],
  }) : warnings = [...document.warnings, ...warnings] {
    if (RegExp(
      r'[\x00-\x08\x0b\x0c\x0e-\x1f\ufffe\uffff]',
    ).hasMatch(document.source)) {
      warn(
        'Word omits control characters that XML cannot represent; the original note is unchanged.',
      );
    }
    for (final element in elements) {
      if (element.tag.startsWith('math')) {
        warn(
          'Equations are exported as rendered images with their TeX in alternative text; Word equations are not native editable equation objects.',
        );
      }
      if (element.tag == 'a' &&
          !safePublicationLink(element.attributes['href'] ?? '')) {
        warn(
          'Internal or unsupported links retain their label without an exported destination.',
        );
      }
    }
    warn(
      'HTML print headers and page numbers depend on browser print settings.',
    );
    warn(
      'PDF page positions are exact for this preview. Word font substitution and browser pagination can change page positions; refresh the Word contents field after opening.',
    );
  }
  final PublicationDocument document;
  final Map<String, Uint8List> images, equations;
  final List<String> warnings;
  final headingPages = <String, int>{};
  int pageCount = 0;
  final _footnoteIds = <String, int>{};
  int footnoteNumber(String id) =>
      _footnoteIds.putIfAbsent(id, () => _footnoteIds.length + 1);
  Iterable<md.Element> get elements sync* {
    Iterable<md.Element> walk(md.Node node) sync* {
      if (node is md.Element) {
        yield node;
        for (final child in node.children ?? <md.Node>[]) {
          yield* walk(child);
        }
      }
    }

    for (final node in document.nodes) {
      yield* walk(node);
    }
  }

  void warn(String text) {
    if (!warnings.contains(text)) warnings.add(text);
  }

  String html({bool articleFragment = false}) {
    final style = document.style;
    String node(md.Node n, {bool layout = true}) {
      if (n is md.Text) return publicationEscape(n.text);
      final e = n as md.Element;
      if (layout && publicationLayoutTarget(e)) {
        final options = publicationBlockLayout(e);
        final margin = options.alignment == 'center'
            ? 'auto'
            : options.alignment == 'right'
            ? '0 0 0 auto'
            : '0';
        final tag = e.tag == 'table' ? 'div' : 'figure';
        return '<$tag class="print-layout ${options.repeatHeader ? '' : 'no-repeat'}" style="width:${options.width}%;margin:$margin;${options.pageBreakBefore ? 'break-before:page;' : ''}">${node(e, layout: false)}${options.caption.isEmpty ? '' : '<${tag == 'figure' ? 'figcaption' : 'p'} class="layout-caption">${publicationEscape(options.caption)}</${tag == 'figure' ? 'figcaption' : 'p'}>'}</$tag>';
      }
      if (e.tag == 'pagebreak') return '<div class="pagebreak"></div>';
      if (e.tag == 'input') {
        return e.attributes.containsKey('checked') ? '☑ ' : '☐ ';
      }
      if (e.tag == 'footnote') {
        final id = e.attributes['id']!;
        return '<sup><a href="#fn-${footnoteNumber(id)}">${footnoteNumber(id)}</a></sup>';
      }
      if (e.tag == 'img' || e.tag.startsWith('math')) {
        final src = e.tag == 'img' ? e.attributes['src']! : e.textContent;
        if (articleFragment && e.tag == 'img' && ArticleMetadata.webUrl(src)) {
          return '<img src="${publicationEscape(src)}" alt="${publicationEscape(e.attributes['alt'] ?? '')}">';
        }
        final bytes = e.tag == 'img' ? images[src] : equations[src];
        if (bytes == null) {
          return '<span class="fallback">${publicationEscape(e.tag == 'img' ? '[Image: ${e.attributes['alt'] ?? src}]' : src)}</span>';
        }
        final mime = bytes.length > 3 && bytes[0] == 0xff
            ? 'image/jpeg'
            : 'image/png';
        return '<img class="${e.tag == 'img' ? 'figure' : 'equation'}" alt="${publicationEscape(e.attributes['alt'] ?? src)}" src="data:$mime;base64,${base64Encode(bytes)}">';
      }
      final content = (e.children ?? []).map(node).join();
      if (e.tag == 'a') {
        final href = e.attributes['href'] ?? '';
        if (!safePublicationLink(href)) return content;
        return '<a href="${publicationEscape(href)}">$content</a>';
      }
      const tags = {
        'p',
        'h1',
        'h2',
        'h3',
        'h4',
        'h5',
        'h6',
        'strong',
        'em',
        'del',
        'code',
        'pre',
        'blockquote',
        'ul',
        'ol',
        'li',
        'table',
        'thead',
        'tbody',
        'tr',
        'th',
        'td',
        'hr',
        'br',
      };
      if (!tags.contains(e.tag)) return content;
      final id = e.attributes['id'];
      final start = e.tag == 'ol' ? e.attributes['start'] : null;
      final language = e.tag == 'code' ? e.attributes['class'] : null;
      final alignment = e.tag == 'th' || e.tag == 'td'
          ? e.attributes['align']
          : null;
      final attributes =
          '${id == null ? '' : ' id="${publicationEscape(id)}"'}'
          '${start == null ? '' : ' start="${publicationEscape(start)}"'}'
          '${language != null && RegExp(r'^language-[A-Za-z0-9_+.-]{1,40}$').hasMatch(language) ? ' class="${publicationEscape(language)}"' : ''}'
          '${const ['left', 'right', 'center'].contains(alignment) ? ' style="text-align:$alignment"' : ''}';
      if (e.tag == 'hr' || e.tag == 'br') return '<${e.tag}$attributes>';
      return '<${e.tag}$attributes>$content</${e.tag}>';
    }

    final article = document.article;
    final title = article?.text('title').isNotEmpty == true
        ? article!.text('title')
        : document.title;
    final leading = document.nodes.firstOrNull;
    final leadingTitle =
        leading is md.Element &&
        leading.tag == 'h1' &&
        (leading.textContent == document.title ||
            articleFragment && leading.textContent == title);
    final titleId = leadingTitle ? leading.attributes['id'] : null;
    final titleAnchor = titleId == null
        ? ''
        : ' id="${publicationEscape(titleId)}"';
    final body = document.nodes.indexed
        .where((entry) => !(entry.$1 == 0 && leadingTitle))
        .map((entry) => node(entry.$2))
        .join('\n');
    final footnotes = document.footnotes.entries
        .map(
          (e) =>
              '<li id="fn-${footnoteNumber(e.key)}" value="${footnoteNumber(e.key)}">${publicationEscape(e.value)}</li>',
        )
        .join();
    final endnotes = footnotes.isEmpty
        ? ''
        : '<section><h2>Footnotes</h2><ol>$footnotes</ol></section>';
    final byline = article == null
        ? ''
        : '<p class="article-byline">${publicationEscape(article.text('author'))}'
              '${article.text('published').isEmpty ? '' : ' · Published <time datetime="${article.text('published')}">${article.text('published')}</time>'}'
              '${article.text('modified').isEmpty ? '' : ' · Updated <time datetime="${article.text('modified')}">${article.text('modified')}</time>'}</p>';
    if (articleFragment) {
      return '<article$titleAnchor>$byline$body$endnotes</article>';
    }
    final metadata = article == null
        ? ''
        : [
            if (article.text('description').isNotEmpty)
              '<meta name="description" content="${publicationEscape(article.text('description'))}">',
            if (article.text('canonicalUrl').isNotEmpty)
              '<link rel="canonical" href="${publicationEscape(article.text('canonicalUrl'))}">',
            if (!article.indexable)
              '<meta name="robots" content="noindex,nofollow">',
            '<meta property="og:type" content="article">',
            '<meta property="og:title" content="${publicationEscape(title)}">',
            if (article.text('description').isNotEmpty)
              '<meta property="og:description" content="${publicationEscape(article.text('description'))}">',
            if (article.text('imageUrl').isNotEmpty)
              '<meta property="og:image" content="${publicationEscape(article.text('imageUrl'))}">',
            '<script type="application/ld+json">${article.schemaJson(document.title)}</script>',
          ].join();
    return '<!doctype html><html lang="${publicationEscape(article?.text('language').isNotEmpty == true ? article!.text('language') : 'en')}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
        '<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; img-src data:; style-src \'unsafe-inline\'; base-uri \'none\'; form-action \'none\'">'
        '<title>${publicationEscape(title)}</title>$metadata<style>'
        '@page{size:${style.letter ? 'Letter' : 'A4'};margin:${style.margin}pt}'
        'body{max-width:${style.width - 2 * style.margin}pt;margin:40px auto;padding:20px;background:white;color:#202124;font:${style.fontSize}pt ${style.serif ? 'Georgia,serif' : 'Arial,sans-serif'};line-height:1.5}'
        'h1,h2,h3,h4,h5,h6{break-after:avoid}p{orphans:3;widows:3}table{border-collapse:collapse;width:100%}th,td{border:1px solid #ccc;padding:6px;overflow-wrap:anywhere}pre{white-space:pre-wrap;background:#f3f3f3;padding:12px;overflow-wrap:anywhere}'
        '.print-layout .figure{width:100%}.figure{max-width:100%;max-height:${style.height - 2 * style.margin - 100}pt;object-fit:contain}.equation{max-width:100%;max-height:48pt;vertical-align:middle}.pagebreak{break-before:page}.title-page{break-after:page;padding-top:30%}blockquote{border-left:3px solid #bbb;padding-left:14px}a{color:#35538c}.fallback{color:#744}header{color:#666}.layout-caption{font-size:90%;color:#555}figure{break-inside:avoid}thead{display:table-header-group}.no-repeat thead{display:table-row-group} @media print{body{margin:0;padding:0}}'
        '</style></head><body><header>${publicationEscape(style.header)}</header>'
        '<section class="${style.titlePage ? 'title-page' : ''}"><h1$titleAnchor>${publicationEscape(document.title)}</h1>${article == null ? '<p>${publicationEscape(style.author)}</p>' : byline}</section>'
        '${style.contents && document.headings.isNotEmpty ? '<nav aria-label="Contents" style="break-after:page"><h2>Contents</h2><ul>${document.headings.map((h) => '<li><a href="#${h.id}">${publicationEscape(h.text)}</a>${headingPages[h.id] == null ? '' : ' <small>PDF page ${headingPages[h.id]}</small>'}</li>').join()}</ul></nav>' : ''}'
        '$body$endnotes</body></html>';
  }

  Future<Uint8List> pdf() => _pdf(false);
  Future<Uint8List> _pdf(bool finalPass) async {
    final tocPages = Map<String, int>.of(headingPages);
    headingPages.clear();
    final s = document.style;
    final family = s.serif ? 'CrimsonText' : 'Lato';
    final base = pw.Font.ttf(
      await rootBundle.load('assets/publishing/$family-Regular.ttf'),
    );
    final coverage = TtfParser(
      await rootBundle.load('assets/publishing/$family-Regular.ttf'),
    ).charToGlyphIndexMap;
    final fallbackData = await rootBundle.load(
      'assets/publishing/Lato-Regular.ttf',
    );
    final fallbackCoverage = TtfParser(fallbackData).charToGlyphIndexMap;
    final fallback = pw.Font.ttf(fallbackData);
    final mono = pw.Font.ttf(
      await rootBundle.load('assets/writing/SpaceMono-Regular.ttf'),
    );
    final missingRunes =
        ('${document.title}\n${s.author}\n${s.header}\n${document.nodes.map((n) => n.textContent).join()}\n${document.footnotes.values.join()}')
            .runes
            .where(
              (r) =>
                  r > 32 &&
                  !coverage.containsKey(r) &&
                  !fallbackCoverage.containsKey(r),
            )
            .toSet();
    if (missingRunes.isNotEmpty) {
      warn(
        'PDF font lacks ${missingRunes.length} character(s): ${String.fromCharCodes(missingRunes.take(12))}. HTML and Word retain the original Unicode text.',
      );
    }
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/publishing/$family-Bold.ttf'),
    );
    final italicFont = pw.Font.ttf(
      await rootBundle.load('assets/publishing/$family-Italic.ttf'),
    );
    final boldItalicFont = pw.Font.ttf(
      await rootBundle.load('assets/publishing/$family-BoldItalic.ttf'),
    );
    final theme =
        pw.ThemeData.withFont(
          base: base,
          bold: bold,
          italic: italicFont,
          boldItalic: boldItalicFont,
        ).copyWith(
          defaultTextStyle: pw.TextStyle(
            font: base,
            fontSize: s.fontSize,
            lineSpacing: 3,
            fontFallback: [fallback],
          ),
        );
    final pdf = pw.Document(
      title: document.title,
      author: s.author,
      creator: 'Orbit Note',
    );
    final format = PdfPageFormat(s.width, s.height, marginAll: s.margin);
    final pageWidth = s.width - 2 * s.margin;
    // Reserve room for running text/footer and breathing space on every page.
    final pageHeight = s.height - 2 * s.margin - 100;
    pw.InlineSpan inline(md.Node n, {double? maxWidth}) {
      final availableWidth = maxWidth ?? pageWidth;
      if (n is md.Text) return pw.TextSpan(text: n.text);
      final e = n as md.Element;
      if (e.tag == 'input') {
        return pw.TextSpan(
          text: e.attributes.containsKey('checked') ? '[x] ' : '[ ] ',
        );
      }
      if (e.tag == 'footnote') {
        final id = e.attributes['id']!;
        return pw.TextSpan(
          text: '[${footnoteNumber(id)}]',
          annotation: document.footnotes.containsKey(id)
              ? pw.AnnotationLink('fn-${footnoteNumber(id)}')
              : null,
        );
      }
      if (e.tag == 'img' || e.tag.startsWith('math')) {
        final src = e.tag == 'img' ? e.attributes['src']! : e.textContent;
        final bytes = e.tag == 'img' ? images[src] : equations[src];
        if (bytes != null) {
          final png = bytes.length >= 24 && bytes[0] == 137
              ? ByteData.sublistView(bytes)
              : null;
          final ratio =
              (png?.getUint32(16) ?? 400) / (png?.getUint32(20) ?? 250);
          final desiredHeight = e.tag == 'img' ? 160.0 : s.fontSize * 1.6;
          final width = (ratio * desiredHeight).clamp(1.0, availableWidth);
          return pw.WidgetSpan(
            child: pw.Image(
              pw.MemoryImage(bytes),
              width: width,
              height: width / ratio,
            ),
          );
        }
        return pw.TextSpan(
          text: e.tag == 'img'
              ? '[Image: ${e.attributes['alt'] ?? src}]'
              : e.textContent,
        );
      }
      return pw.TextSpan(
        text: e.tag == 'br' ? '\n' : null,
        style: pw.TextStyle(
          fontWeight: e.tag == 'strong' ? pw.FontWeight.bold : null,
          fontStyle: e.tag == 'em' ? pw.FontStyle.italic : null,
          decoration: e.tag == 'del' ? pw.TextDecoration.lineThrough : null,
          font: e.tag == 'code' ? mono : null,
          fontFallback: [fallback],
        ),
        annotation:
            e.tag == 'a' && safePublicationLink(e.attributes['href'] ?? '')
            ? (e.attributes['href']!.startsWith('#')
                  ? pw.AnnotationLink(e.attributes['href']!.substring(1))
                  : pw.AnnotationUrl(e.attributes['href']!))
            : null,
        children: (e.children ?? [])
            .map((c) => inline(c, maxWidth: availableWidth))
            .toList(),
      );
    }

    List<pw.Widget> blocks(List<md.Node> nodes, {int depth = 0}) {
      final result = <pw.Widget>[];
      for (final n in nodes) {
        if (n is md.Text) {
          result.add(pw.Paragraph(text: n.text));
          continue;
        }
        final e = n as md.Element;
        if (e.tag == 'pagebreak') {
          result.add(pw.NewPage());
          continue;
        }
        if (RegExp(r'^h[1-6]$').hasMatch(e.tag)) {
          result.add(
            _PublicationAnchor(
              pages: headingPages,
              name: e.attributes['id']!,
              child: pw.Header(
                level: int.parse(e.tag[1]) - 1,
                title: e.textContent,
                text: e.textContent,
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: [inline(e)],
                    style: pw.TextStyle(
                      fontSize: (25 - int.parse(e.tag[1]) * 2).toDouble(),
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  overflow: pw.TextOverflow.span,
                ),
              ),
            ),
          );
          continue;
        }
        if (e.tag == 'table') {
          final options = publicationBlockLayout(e);
          if (options.pageBreakBefore) result.add(pw.NewPage());
          final sourceRows = <List<md.Node>>[];
          void collect(md.Node child) {
            if (child is! md.Element) return;
            if (child.tag == 'tr') {
              sourceRows.add(child.children ?? []);
            } else {
              for (final c in child.children ?? []) {
                collect(c);
              }
            }
          }

          collect(e);
          final tableWidth = pageWidth * options.width / 100;
          final columns = sourceRows.fold<int>(
            0,
            (max, row) => row.length > max ? row.length : max,
          );
          final cellWidth = tableWidth / (columns == 0 ? 1 : columns) - 10;
          pw.Widget table(pw.Context context, pw.BoxConstraints? constraints) {
            // The PDF table engine can paginate between rows, never within a
            // row. Measure before deciding; do not drop a row that exceeds a page.
            var records = cellWidth < 60;
            for (final row in sourceRows) {
              for (final cell in row) {
                final measured = pw.RichText(
                  text: inline(cell, maxWidth: cellWidth.clamp(1, pageWidth)),
                );
                measured.layout(
                  context,
                  pw.BoxConstraints(maxWidth: cellWidth.clamp(1, pageWidth)),
                );
                if (measured.box!.height > pageHeight / 2) records = true;
              }
            }
            if (records) {
              warn(
                'A wide table or tall row uses labelled records in PDF so every cell can flow across pages. HTML and Word retain the table.',
              );
              final headers = sourceRows.isEmpty
                  ? <md.Node>[]
                  : sourceRows.first;
              final spans = <pw.InlineSpan>[];
              for (var r = 0; r < sourceRows.length; r++) {
                final row = sourceRows[r];
                final isHeader = row.any(
                  (c) => c is md.Element && c.tag == 'th',
                );
                if (isHeader && sourceRows.length > 1) continue;
                spans.add(
                  pw.TextSpan(
                    text: 'Row $r\n',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                );
                for (var c = 0; c < row.length; c++) {
                  final label = c < headers.length
                      ? headers[c].textContent
                      : 'Column ${c + 1}';
                  spans.add(
                    pw.TextSpan(
                      text: '$label: ',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  );
                  spans.add(inline(row[c], maxWidth: tableWidth));
                  spans.add(const pw.TextSpan(text: '\n'));
                }
                spans.add(const pw.TextSpan(text: '\n'));
              }
              return pw.RichText(
                text: pw.TextSpan(children: spans),
                overflow: pw.TextOverflow.span,
              );
            }
            return pw.Table(
              defaultColumnWidth: const pw.FlexColumnWidth(),
              border: pw.TableBorder.all(color: PdfColors.grey400),
              children: [
                for (final row in sourceRows)
                  pw.TableRow(
                    repeat:
                        options.repeatHeader &&
                        row.any((c) => c is md.Element && c.tag == 'th'),
                    children: [
                      for (final cell in row)
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [inline(cell, maxWidth: cellWidth)],
                              style: pw.TextStyle(
                                fontWeight:
                                    cell is md.Element && cell.tag == 'th'
                                    ? pw.FontWeight.bold
                                    : null,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            );
          }

          final spare = (s.width - 2 * s.margin) * (100 - options.width) / 100;
          result.add(
            pw.Padding(
              padding: pw.EdgeInsets.only(
                left: options.alignment == 'right'
                    ? spare
                    : options.alignment == 'center'
                    ? spare / 2
                    : 0,
                right: options.alignment == 'left'
                    ? spare
                    : options.alignment == 'center'
                    ? spare / 2
                    : 0,
              ),
              child: pw.LayoutBuilder(builder: table),
            ),
          );
          if (options.caption.isNotEmpty) {
            result.add(
              pw.Padding(
                padding: pw.EdgeInsets.only(
                  left: options.alignment == 'right'
                      ? spare
                      : options.alignment == 'center'
                      ? spare / 2
                      : 0,
                  right: options.alignment == 'left'
                      ? spare
                      : options.alignment == 'center'
                      ? spare / 2
                      : 0,
                ),
                child: pw.Paragraph(
                  text: options.caption,
                  style: pw.TextStyle(fontSize: s.fontSize - 1),
                ),
              ),
            );
          }
          continue;
        }
        if (publicationLayoutTarget(e)) {
          final options = publicationBlockLayout(e);
          if (options.pageBreakBefore) result.add(pw.NewPage());
          final image = e.children!.single as md.Element;
          final bytes = images[image.attributes['src']];
          final desiredWidth = (s.width - 2 * s.margin) * options.width / 100;
          final fittedWidth = bytes == null
              ? desiredWidth
              : _imageWidth(bytes, desiredWidth, pageHeight);
          final spare = pageWidth - fittedWidth;
          final padding = pw.EdgeInsets.only(
            bottom: 8,
            left: options.alignment == 'right'
                ? spare
                : options.alignment == 'center'
                ? spare / 2
                : 0,
            right: options.alignment == 'left'
                ? spare
                : options.alignment == 'center'
                ? spare / 2
                : 0,
          );
          result.add(
            pw.Padding(
              padding: padding,
              child: bytes == null
                  ? pw.Paragraph(
                      text:
                          '[Image: ${image.attributes['alt'] ?? image.attributes['src']}]',
                    )
                  : pw.Image(
                      pw.MemoryImage(bytes),
                      width: fittedWidth,
                      height: _imageHeight(bytes, fittedWidth, pageHeight),
                      fit: pw.BoxFit.contain,
                    ),
            ),
          );
          if (options.caption.isNotEmpty) {
            final captionSpare = pageWidth - desiredWidth;
            result.add(
              pw.Padding(
                padding: pw.EdgeInsets.only(
                  left: options.alignment == 'right'
                      ? captionSpare
                      : options.alignment == 'center'
                      ? captionSpare / 2
                      : 0,
                  right: options.alignment == 'left'
                      ? captionSpare
                      : options.alignment == 'center'
                      ? captionSpare / 2
                      : 0,
                ),
                child: pw.Paragraph(
                  text: options.caption,
                  style: pw.TextStyle(fontSize: s.fontSize - 1),
                ),
              ),
            );
          }
          continue;
        }
        if (e.tag == 'ul' || e.tag == 'ol') {
          var number = int.tryParse(e.attributes['start'] ?? '') ?? 1;
          for (final li in e.children ?? <md.Node>[]) {
            if (li is md.Element) {
              final indent = (depth * 14.0).clamp(0.0, pageWidth - 80);
              var marker = '${e.tag == 'ol' ? '${number++}.' : '•'} ';
              final pending = <md.Node>[];
              void flush() {
                if (pending.isEmpty && marker.isEmpty) return;
                result.add(
                  pw.Padding(
                    padding: pw.EdgeInsets.only(left: indent, bottom: 4),
                    child: pw.RichText(
                      overflow: pw.TextOverflow.span,
                      text: pw.TextSpan(
                        children: [
                          pw.TextSpan(text: marker),
                          for (final child in pending)
                            inline(child, maxWidth: pageWidth - indent),
                        ],
                      ),
                    ),
                  ),
                );
                marker = '';
                pending.clear();
              }

              for (final child in li.children ?? <md.Node>[]) {
                if (child is md.Element && child.tag == 'p') {
                  if (pending.isNotEmpty) flush();
                  pending.addAll(child.children ?? []);
                  flush();
                } else if (child is md.Element &&
                    const {
                      'ul',
                      'ol',
                      'pre',
                      'table',
                      'math',
                      'blockquote',
                    }.contains(child.tag)) {
                  if (pending.isNotEmpty || marker.isNotEmpty) flush();
                  result.addAll(blocks([child], depth: depth + 1));
                } else {
                  pending.add(child);
                }
              }
              if (pending.isNotEmpty) flush();
            }
          }
          continue;
        }
        if (e.tag == 'pre') {
          result.add(
            pw.Paragraph(
              text: e.textContent,
              style: pw.TextStyle(
                font: mono,
                fontSize: s.fontSize - 1,
                fontFallback: [fallback],
              ),
              textAlign: pw.TextAlign.left,
            ),
          );
          continue;
        }
        if (e.tag == 'hr') {
          result.add(pw.Divider());
          continue;
        }
        if (e.tag == 'blockquote') {
          result.addAll(blocks(e.children ?? []));
          continue;
        }
        if (e.tag == 'math') {
          final bytes = equations[e.textContent];
          final desiredWidth = bytes == null
              ? pageWidth
              : _imageWidth(
                  bytes,
                  ByteData.sublistView(bytes).getUint32(16) *
                      s.fontSize /
                      44 *
                      1.3,
                  pageHeight,
                ).clamp(1.0, pageWidth);
          result.add(
            bytes == null
                ? pw.Paragraph(text: e.textContent)
                : pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8),
                    child: pw.Center(
                      child: pw.Image(
                        pw.MemoryImage(bytes),
                        width: _imageWidth(bytes, desiredWidth, pageHeight),
                        height: _imageHeight(bytes, desiredWidth, pageHeight),
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ),
          );
          if (bytes != null &&
              (ByteData.sublistView(bytes).getUint32(16) * s.fontSize / 44 >
                      pageWidth * 1.5 ||
                  ByteData.sublistView(bytes).getUint32(20) * s.fontSize / 44 >
                      pageHeight)) {
            warn(
              'Large equations are fitted to the page and followed by their complete TeX source for readability.',
            );
            result.add(
              pw.Paragraph(
                text: e.textContent,
                textAlign: pw.TextAlign.left,
                style: pw.TextStyle(
                  font: mono,
                  fontSize: s.fontSize - 1,
                  fontFallback: [fallback],
                ),
              ),
            );
          }
          continue;
        }
        result.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 9),
            child: pw.RichText(text: inline(e), overflow: pw.TextOverflow.span),
          ),
        );
      }
      return result;
    }

    if (document.footnotes.isNotEmpty) {
      warn(
        'PDF/HTML collect footnotes as linked endnotes. Word exports native footnotes.',
      );
    }
    final endnotePages = <String, int>{};
    final first = document.nodes.firstOrNull;
    final titleInBody =
        first is md.Element &&
        first.tag == 'h1' &&
        first.textContent.replaceFirst(RegExp(r'^\d+(?:\.\d+)*\.\s+'), '') ==
            document.title;
    try {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: format,
          theme: theme,
          maxPages: 500,
          header: (context) {
            // MultiPage's maxPages is a debug progress guard, not a release-mode
            // document limit. Fail visibly rather than silently truncate or hang.
            if (context.pageNumber > 500) {
              throw const FormatException(
                'PDF exceeds 500 pages. Export smaller sections; no partial PDF was saved.',
              );
            }
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text(
                s.header,
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            );
          },
          footer: (context) => s.pageNumbers
              ? pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 8),
                    child: pw.Text(
                      '${context.pageNumber} / ${context.pagesCount}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                )
              : pw.SizedBox(),
          build: (_) => [
            if (s.titlePage) ...[
              pw.SizedBox(height: 80),
              pw.Text(
                document.title,
                style: pw.TextStyle(font: bold, fontSize: 28),
                overflow: pw.TextOverflow.span,
              ),
              pw.SizedBox(height: 20),
              pw.Text(s.author, overflow: pw.TextOverflow.span),
              pw.NewPage(),
            ] else if (!titleInBody)
              pw.Header(
                level: 0,
                title: document.title,
                text: document.title,
                child: pw.Text(
                  document.title,
                  style: pw.TextStyle(font: bold, fontSize: 24),
                  overflow: pw.TextOverflow.span,
                ),
              ),
            if (s.contents && document.headings.isNotEmpty) ...[
              pw.Text(
                'Contents',
                style: pw.TextStyle(font: bold, fontSize: 22),
              ),
              pw.SizedBox(height: 16),
              for (final heading in document.headings)
                pw.Padding(
                  padding: pw.EdgeInsets.only(
                    left: (heading.level - 1) * 12,
                    bottom: 8,
                  ),
                  child: pw.RichText(
                    overflow: pw.TextOverflow.span,
                    text: pw.TextSpan(
                      text: '${heading.text}  ${tocPages[heading.id] ?? ''}',
                      annotation: pw.AnnotationLink(heading.id),
                    ),
                  ),
                ),
              pw.NewPage(),
            ],
            ...blocks(document.nodes),
            if (document.footnotes.isNotEmpty) ...[
              pw.Header(level: 0, text: 'Footnotes'),
              for (final entry in document.footnotes.entries)
                _PublicationAnchor(
                  pages: endnotePages,
                  name: 'fn-${footnoteNumber(entry.key)}',
                  child: pw.Paragraph(
                    text: '${footnoteNumber(entry.key)}. ${entry.value}',
                  ),
                ),
            ],
          ],
        ),
      );
    } on FormatException catch (error) {
      return Future<Uint8List>.error(error);
    }
    final bytes = await pdf.save();
    pageCount = pdf.document.pdfPageList.pages.length;
    return !finalPass && s.contents && document.headings.isNotEmpty
        ? _pdf(true)
        : bytes;
  }

  Uint8List docx() => _WordExport(this).build();
}

class _WordExport {
  _WordExport(this.export);
  final PublicationExport export;
  final archive = Archive();
  final relationships = <String>[];
  int imageNumber = 0, linkNumber = 0, drawingNumber = 0;
  String x(String value) => publicationEscape(
    value.replaceAll(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\ufffe\uffff]'), ''),
  );
  void file(String path, String value) =>
      archive.addFile(ArchiveFile.string(path, value));
  String paragraph(String value, {String properties = ''}) =>
      '<w:p><w:pPr>$properties</w:pPr>$value</w:p>';
  String captionIndent(PublicationBlockLayout options, {double? width}) {
    final available =
        export.document.style.width - 2 * export.document.style.margin;
    final spare = available - (width ?? available * options.width / 100);
    final left = options.alignment == 'right'
        ? spare
        : options.alignment == 'center'
        ? spare / 2
        : 0.0;
    return '<w:ind w:left="${(left * 20).round()}" w:right="${((spare - left) * 20).round()}"/><w:jc w:val="left"/>';
  }

  String run(String text, {String properties = ''}) =>
      '<w:r><w:rPr>$properties</w:rPr>${text.split(RegExp(r'\r\n|\n|\r')).map((line) => '<w:t xml:space="preserve">${x(line)}</w:t>').join('<w:br/>')}</w:r>';
  String drawing(Uint8List bytes, String alt, bool math, {int percent = 100}) {
    final n = ++imageNumber;
    final ext = bytes[0] == 0xff ? 'jpg' : 'png';
    archive.addFile(ArchiveFile.bytes('word/media/image$n.$ext', bytes));
    relationships.add(
      '<Relationship Id="img$n" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image$n.$ext"/>',
    );
    final png = bytes.length >= 24 && bytes[0] == 137
        ? ByteData.sublistView(bytes)
        : null;
    final pxWidth = png?.getUint32(16) ?? 400,
        pxHeight = png?.getUint32(20) ?? 250;
    final maxWidth =
        ((export.document.style.width - 2 * export.document.style.margin) *
                12700)
            .round();
    var width = math
        ? ((pxWidth / 2) * 9144).round().clamp(1, maxWidth)
        : (maxWidth * percent / 100).round();
    var height = (width * pxHeight / pxWidth).round();
    final maxHeight =
        ((export.document.style.height -
                    2 * export.document.style.margin -
                    100) *
                12700)
            .round();
    if (height > maxHeight) {
      width = (width * maxHeight / height).round();
      height = maxHeight;
    }
    return '<w:r><w:drawing><wp:inline><wp:extent cx="$width" cy="$height"/><wp:docPr id="${++drawingNumber}" name="Image $n" descr="${x(alt)}"/><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic><pic:nvPicPr><pic:cNvPr id="$n" name="Image $n"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="img$n"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$width" cy="$height"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>';
  }

  String inline(md.Node n, [String properties = '']) {
    if (n is md.Text) return run(n.text, properties: properties);
    final e = n as md.Element;
    if (e.tag == 'input') {
      return run(e.attributes.containsKey('checked') ? '[x] ' : '[ ] ');
    }
    if (e.tag == 'footnote') {
      final id = e.attributes['id']!;
      if (!export.document.footnotes.containsKey(id)) return run('[^$id]');
      return '<w:r><w:footnoteReference w:id="${export.footnoteNumber(id)}"/></w:r>';
    }
    if (e.tag == 'img' || e.tag.startsWith('math')) {
      final src = e.tag == 'img' ? e.attributes['src']! : e.textContent;
      final bytes = e.tag == 'img' ? export.images[src] : export.equations[src];
      return bytes == null
          ? run(e.tag == 'img' ? '[Image: ${e.attributes['alt'] ?? src}]' : src)
          : drawing(bytes, e.attributes['alt'] ?? src, e.tag != 'img');
    }
    if (e.tag == 'br') return '<w:r><w:br/></w:r>';
    final more =
        properties +
        (e.tag == 'strong'
            ? '<w:b/>'
            : e.tag == 'em'
            ? '<w:i/>'
            : e.tag == 'del'
            ? '<w:strike/>'
            : '');
    final content = (e.children ?? []).map((c) => inline(c, more)).join();
    if (e.tag == 'a' && safePublicationLink(e.attributes['href'] ?? '')) {
      final href = e.attributes['href']!;
      if (href.startsWith('#')) {
        return '<w:hyperlink w:anchor="${x(href.substring(1).replaceAll('-', '_'))}">$content</w:hyperlink>';
      }
      final id = 'link${++linkNumber}';
      relationships.add(
        '<Relationship Id="$id" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="${x(href)}" TargetMode="External"/>',
      );
      return '<w:hyperlink r:id="$id">$content</w:hyperlink>';
    }
    return content;
  }

  String block(md.Node n, [int depth = 0]) {
    if (n is md.Text) return paragraph(run(n.text));
    final e = n as md.Element;
    if (e.tag == 'pagebreak') {
      return paragraph('<w:r><w:br w:type="page"/></w:r>');
    }
    if (e.tag == 'table') {
      final options = publicationBlockLayout(e);
      final rows = <String>[];
      void collect(md.Node node) {
        if (node is! md.Element) return;
        if (node.tag == 'tr') {
          rows.add(
            '<w:tr><w:trPr>${options.repeatHeader && (node.children ?? []).any((cell) => cell is md.Element && cell.tag == 'th') ? '<w:tblHeader/>' : ''}</w:trPr>${(node.children ?? []).map((cell) => '<w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/></w:tcPr>${paragraph(inline(cell))}</w:tc>').join()}</w:tr>',
          );
        } else {
          for (final child in node.children ?? []) {
            collect(child);
          }
        }
      }

      collect(e);
      return '${options.pageBreakBefore ? paragraph('<w:r><w:br w:type="page"/></w:r>') : ''}<w:tbl><w:tblPr><w:tblW w:w="${options.width * 50}" w:type="pct"/><w:jc w:val="${options.alignment}"/><w:tblBorders>${['top', 'left', 'bottom', 'right', 'insideH', 'insideV'].map((edge) => '<w:$edge w:val="single" w:sz="4" w:color="CCCCCC"/>').join()}</w:tblBorders></w:tblPr>${rows.join()}</w:tbl>${options.caption.isEmpty ? '' : paragraph(run(options.caption), properties: captionIndent(options))}';
    }
    if (publicationLayoutTarget(e)) {
      final options = publicationBlockLayout(e);
      final image = e.children!.single as md.Element;
      final bytes = export.images[image.attributes['src']];
      final s = export.document.style;
      final width = bytes == null
          ? null
          : _imageWidth(
              bytes,
              (s.width - 2 * s.margin) * options.width / 100,
              s.height - 2 * s.margin - 100,
            );
      return '${options.pageBreakBefore ? paragraph('<w:r><w:br w:type="page"/></w:r>') : ''}${paragraph(bytes == null ? run('[Image: ${image.attributes['alt'] ?? image.attributes['src']}]') : drawing(bytes, image.attributes['alt'] ?? '', false, percent: options.width), properties: '<w:jc w:val="${options.alignment}"/>${options.caption.isEmpty ? '' : '<w:keepNext/>'}')}${options.caption.isEmpty ? '' : paragraph(run(options.caption), properties: captionIndent(options, width: width))}';
    }
    if (e.tag == 'ul' || e.tag == 'ol') {
      var i = int.tryParse(e.attributes['start'] ?? '') ?? 1;
      return (e.children ?? []).map((li) {
        if (li is! md.Element) return paragraph(inline(li));
        final nested = (li.children ?? [])
            .where((c) => c is md.Element && (c.tag == 'ul' || c.tag == 'ol'))
            .toList();
        final prose = (li.children ?? []).where((c) => !nested.contains(c));
        return paragraph(
              run('${e.tag == 'ol' ? '${i++}.' : '•'} ') +
                  prose.map((c) => inline(c)).join(),
              properties: '<w:ind w:left="${depth * 360}"/>',
            ) +
            nested.map((c) => block(c, depth + 1)).join();
      }).join();
    }
    if (e.tag == 'blockquote') return (e.children ?? []).map(block).join();
    final heading = RegExp(r'^h[1-6]$').hasMatch(e.tag);
    var content = inline(e);
    if (heading) {
      final id = e.attributes['id']!.replaceAll('-', '_');
      final number = int.parse(id.split('_').last);
      content =
          '<w:bookmarkStart w:id="$number" w:name="$id"/>$content<w:bookmarkEnd w:id="$number"/>';
    }
    return paragraph(
      content,
      properties: heading ? '<w:pStyle w:val="Heading${e.tag[1]}"/>' : '',
    );
  }

  Uint8List build() {
    final d = export.document, s = d.style;
    var body =
        paragraph(run(d.title), properties: '<w:pStyle w:val="Title"/>') +
        paragraph(run(s.author));
    if (s.titlePage) body += paragraph('<w:r><w:br w:type="page"/></w:r>');
    if (s.contents && d.headings.isNotEmpty) {
      body += paragraph(
        run('Contents'),
        properties: '<w:pStyle w:val="Title"/>',
      );
      body +=
          '<w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText xml:space="preserve"> TOC \\o "1-6" \\h \\z \\u </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r></w:p>';
      for (final h in d.headings) {
        body += paragraph(
          '<w:hyperlink w:anchor="${h.id.replaceAll('-', '_')}">${run(h.text)}</w:hyperlink>${run('  ')}<w:fldSimple w:instr="PAGEREF ${h.id.replaceAll('-', '_')} \\h">${run('${export.headingPages[h.id] ?? ''}')}</w:fldSimple>',
        );
      }
    }
    if (s.contents && d.headings.isNotEmpty) {
      body += '<w:p><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>';
      body += paragraph('<w:r><w:br w:type="page"/></w:r>');
    }
    body += d.nodes.map(block).join();
    final footnotes = d.footnotes.entries
        .map(
          (e) =>
              '<w:footnote w:id="${export.footnoteNumber(e.key)}">${paragraph('<w:r><w:footnoteRef/></w:r>${run(' ${e.value}')}')}</w:footnote>',
        )
        .join();
    const ns =
        'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';
    file(
      'word/footnotes.xml',
      '<?xml version="1.0" encoding="UTF-8"?><w:footnotes $ns><w:footnote w:type="separator" w:id="-1"><w:p><w:r><w:separator/></w:r></w:p></w:footnote><w:footnote w:type="continuationSeparator" w:id="0"><w:p><w:r><w:continuationSeparator/></w:r></w:p></w:footnote>$footnotes</w:footnotes>',
    );
    file('word/header.xml', '<w:hdr $ns>${paragraph(run(s.header))}</w:hdr>');
    file(
      'word/footer.xml',
      '<w:ftr $ns>${paragraph(s.pageNumbers ? '<w:fldSimple w:instr="PAGE">${run('1')}</w:fldSimple>' : '')}</w:ftr>',
    );
    final sect =
        '<w:sectPr><w:headerReference w:type="default" r:id="header"/><w:footerReference w:type="default" r:id="footer"/><w:pgSz w:w="${(s.width * 20).round()}" w:h="${(s.height * 20).round()}"/><w:pgMar w:top="${(s.margin * 20).round()}" w:bottom="${(s.margin * 20).round()}" w:left="${(s.margin * 20).round()}" w:right="${(s.margin * 20).round()}" w:header="360" w:footer="360"/></w:sectPr>';
    file(
      'word/document.xml',
      '<?xml version="1.0" encoding="UTF-8"?><w:document $ns xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><w:body>$body$sect</w:body></w:document>',
    );
    final font = s.serif ? 'Georgia' : 'Arial';
    file(
      'word/styles.xml',
      '<w:styles $ns><w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="$font" w:hAnsi="$font"/><w:sz w:val="${(s.fontSize * 2).round()}"/></w:rPr></w:rPrDefault></w:docDefaults><w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:rPr><w:b/><w:sz w:val="56"/></w:rPr></w:style>${List.generate(6, (i) => '<w:style w:type="paragraph" w:styleId="Heading${i + 1}"><w:name w:val="heading ${i + 1}"/><w:pPr><w:keepNext/><w:outlineLvl w:val="$i"/></w:pPr><w:rPr><w:b/><w:sz w:val="${36 - i * 2}"/></w:rPr></w:style>').join()}</w:styles>',
    );
    for (final pair in {
      'styles': 'styles',
      'footnotes': 'footnotes',
      'header': 'header',
      'footer': 'footer',
    }.entries) {
      relationships.add(
        '<Relationship Id="${pair.key}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/${pair.value}" Target="${pair.value}.xml"/>',
      );
    }
    file(
      'word/_rels/document.xml.rels',
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${relationships.join()}</Relationships>',
    );
    file(
      '_rels/.rels',
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="document" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>',
    );
    file(
      '[Content_Types].xml',
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/><Default Extension="jpg" ContentType="image/jpeg"/>${{'document': 'document.main', 'styles': 'styles', 'footnotes': 'footnotes', 'header': 'header', 'footer': 'footer'}.entries.map((e) => '<Override PartName="/word/${e.key}.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.${e.value}+xml"/>').join()}</Types>',
    );
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }
}
