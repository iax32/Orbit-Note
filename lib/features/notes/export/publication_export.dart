import 'dart:convert';
import 'dart:math' as math;
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../domain/document_publication.dart';
import '../../../domain/publication_layout.dart';
import '../../../domain/technical_article.dart';
import 'publication_theme.dart';

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

/// Retain RichText's pagination while aligning against the full column width.
class _PublicationAlignedText extends pw.RichText {
  _PublicationAlignedText({
    required super.text,
    super.textAlign,
    super.overflow,
  });
  @override
  void layout(
    pw.Context context,
    pw.BoxConstraints constraints, {
    bool parentUsesSize = false,
  }) {
    super.layout(
      context,
      constraints.maxWidth.isFinite
          ? pw.BoxConstraints(
              minWidth: constraints.maxWidth,
              maxWidth: constraints.maxWidth,
              minHeight: constraints.minHeight,
              maxHeight: constraints.maxHeight,
            )
          : constraints,
      parentUsesSize: parentUsesSize,
    );
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
    this.pdfTheme,
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
  final PublicationPdfTheme? pdfTheme;
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
          : e.attributes['orbit-text-align'];
      final css = <String>[
        if (const ['left', 'right', 'center', 'justify'].contains(alignment))
          'text-align:$alignment',
        if (publicationHeadingTarget(e) &&
            (e.attributes['orbit-pageBreakBefore'] == 'true' ||
                e.attributes['orbit-h1-pagebreak'] == 'true'))
          'break-before:page',
      ].join(';');
      final attributes =
          '${id == null ? '' : ' id="${publicationEscape(id)}"'}'
          '${start == null ? '' : ' start="${publicationEscape(start)}"'}'
          '${language != null && RegExp(r'^language-[A-Za-z0-9_+.-]{1,40}$').hasMatch(language) ? ' class="${publicationEscape(language)}"' : ''}'
          '${css.isEmpty ? '' : ' style="$css"'}';
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
        '${List.generate(6, (i) => 'h${i + 1}{font-size:${style.headingSize(i + 1)}pt}').join()}h1,h2,h3,h4,h5,h6{break-after:avoid}p{orphans:3;widows:3}table{border-collapse:collapse;width:100%}th,td{border:1px solid #ccc;padding:6px;overflow-wrap:anywhere}pre{white-space:pre-wrap;background:#f3f3f3;padding:12px;overflow-wrap:anywhere}'
        '.print-layout .figure{width:100%}.figure{max-width:100%;max-height:${style.height - 2 * style.margin - 100}pt;object-fit:contain}.equation{max-width:100%;max-height:48pt;vertical-align:middle}.pagebreak{break-before:page}.title-page{break-after:page;padding-top:30%}blockquote{border-left:3px solid #bbb;padding-left:14px}a{color:#35538c}.fallback{color:#744}header{color:#666}.layout-caption{font-size:90%;color:#555}figure{break-inside:avoid}thead{display:table-header-group}.no-repeat thead{display:table-row-group} @media print{body{margin:0;padding:0}}'
        '</style></head><body><header>${publicationEscape(style.header)}</header>'
        '<section class="${style.titlePage ? 'title-page' : ''}"><h1$titleAnchor>${publicationEscape(document.title)}</h1>${article == null ? '<p>${publicationEscape(style.author)}</p>' : byline}</section>'
        '${style.contents && document.headings.isNotEmpty ? '<nav aria-label="Contents" style="break-after:page"><h2>Contents</h2><ul>${document.headings.map((h) => '<li><a href="#${h.id}">${publicationEscape(h.text)}</a>${headingPages[h.id] == null ? '' : ' <small>PDF page ${headingPages[h.id]}</small>'}</li>').join()}</ul></nav>' : ''}'
        '$body$endnotes</body></html>';
  }

  Future<Uint8List> pdf({Future<void> Function(pw.Document)? appendPages}) =>
      _pdf(false, appendPages);
  Future<Uint8List> _pdf(
    bool finalPass,
    Future<void> Function(pw.Document)? appendPages,
  ) async {
    final tocPages = Map<String, int>.of(headingPages);
    headingPages.clear();
    final s = document.style;
    final family = s.serif ? 'CrimsonText' : 'Lato';
    final customPrefix = pdfTheme?.fontPrefix;
    final pixel = pdfTheme?.fontFamily == 'OrbitPixel';
    String fontAsset(String face) => customPrefix == null
        ? 'assets/publishing/$family-$face.ttf'
        : pixel
        ? '$customPrefix.ttf'
        : '$customPrefix-$face.ttf';
    final base = pw.Font.ttf(await rootBundle.load(fontAsset('Regular')));
    final coverage = TtfParser(
      await rootBundle.load(fontAsset('Regular')),
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
    final bold = pw.Font.ttf(await rootBundle.load(fontAsset('Bold')));
    final italicFont = pw.Font.ttf(await rootBundle.load(fontAsset('Italic')));
    final boldItalicFont = pw.Font.ttf(
      await rootBundle.load(fontAsset('BoldItalic')),
    );
    PdfColor color(int value) => PdfColor.fromInt(value);
    final ink = pdfTheme == null
        ? PdfColors.black
        : color(pdfTheme!.theme.colorScheme.onSurface.toARGB32());
    final subtle = pdfTheme == null
        ? PdfColors.grey700
        : color(pdfTheme!.theme.colorScheme.onSurfaceVariant.toARGB32());
    final accent = pdfTheme == null
        ? PdfColors.black
        : color(pdfTheme!.theme.colorScheme.primary.toARGB32());
    final border = pdfTheme == null
        ? PdfColors.grey400
        : color(pdfTheme!.theme.colorScheme.outlineVariant.toARGB32());
    final bodyStyle = pw.TextStyle(
      font: base,
      fontSize: s.fontSize,
      lineSpacing: 3,
      fontFallback: [fallback],
      color: ink,
    );
    final theme =
        pw.ThemeData.withFont(
          base: base,
          bold: bold,
          italic: italicFont,
          boldItalic: boldItalicFont,
        ).copyWith(
          defaultTextStyle: bodyStyle,
          paragraphStyle: bodyStyle,
          bulletStyle: bodyStyle,
          tableCell: bodyStyle,
          tableHeader: bodyStyle.copyWith(fontWeight: pw.FontWeight.bold),
          header0: pw.TextStyle(color: ink),
          header1: pw.TextStyle(color: ink),
          header2: pw.TextStyle(color: ink),
          header3: pw.TextStyle(color: ink),
          header4: pw.TextStyle(color: ink),
          header5: pw.TextStyle(color: ink),
        );
    final pdf = pw.Document(
      title: document.title,
      author: s.author,
      creator: 'Orbit Note',
    );
    // Keep content clear of book bindings and desktop-theme title bars, even
    // when an older document chose the smallest permitted print margin.
    final printMargin =
        pdfTheme != null &&
            pdfTheme!.appearance.design.name != 'orbit' &&
            s.margin < 40
        ? 40.0
        : s.margin;
    final format = PdfPageFormat(s.width, s.height, marginAll: printMargin);
    final backdrop = pdfTheme == null
        ? null
        : pw.MemoryImage(
            await pdfTheme!.page(
              s.width,
              s.height,
              printMargin,
              s.fontSize,
              warn,
            ),
          );
    final pdfEquations = <String, Uint8List>{};
    for (final entry in equations.entries) {
      if (pdfTheme == null) {
        pdfEquations[entry.key] = entry.value;
        continue;
      }
      try {
        pdfEquations[entry.key] = await pdfTheme!.equation(entry.key);
      } catch (_) {
        warn(
          'Equation rendering unavailable in this editor theme; complete TeX retained.',
        );
      }
    }
    final pageWidth = s.width - 2 * printMargin;
    // Reserve room for running text/footer and breathing space on every page.
    final pageHeight = s.height - 2 * printMargin - 100;
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
        final bytes = e.tag == 'img' ? images[src] : pdfEquations[src];
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
          color: e.tag == 'a' ? accent : null,
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

    pw.TextAlign paragraphAlignment(md.Element e) =>
        switch (e.attributes['orbit-text-align']) {
          'center' => pw.TextAlign.center,
          'right' => pw.TextAlign.right,
          'justify' => pw.TextAlign.justify,
          _ => pw.TextAlign.left,
        };
    List<pw.Widget> blocks(List<md.Node> nodes, {int depth = 0}) {
      final result = <pw.Widget>[];
      double headingHeight(md.Element e) {
        final size = s.headingSize(int.parse(e.tag[1]));
        final lines = math.max(
          1,
          (e.textContent.runes.length * size * .6 / pageWidth).ceil(),
        );
        return (lines * size * 1.35 + 26).clamp(38, pageHeight * .8).toDouble();
      }

      for (var nodeIndex = 0; nodeIndex < nodes.length; nodeIndex++) {
        final n = nodes[nodeIndex];
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
          final height = headingHeight(e);
          final next = nodeIndex + 1 < nodes.length
              ? nodes[nodeIndex + 1]
              : null;
          var following = s.fontSize * 3 + 12;
          if (next is md.Element &&
              publicationLayoutTarget(next) &&
              next.tag == 'p') {
            final options = publicationBlockLayout(next);
            final image = next.children!.single as md.Element;
            final data = images[image.attributes['src']];
            if (options.pageBreakBefore) {
              following = 0;
            } else if (data != null) {
              following =
                  _imageHeight(
                    data,
                    pageWidth * options.width / 100,
                    math.max(40, pageHeight - height - 24),
                  ) +
                  24;
            }
          }
          final options = publicationBlockLayout(e);
          final previous = nodeIndex > 0 ? nodes[nodeIndex - 1] : null;
          final freshFirst =
              nodeIndex == 0 &&
              (s.titlePage || s.contents || e.textContent == document.title);
          if ((options.pageBreakBefore ||
                  e.attributes['orbit-h1-pagebreak'] == 'true') &&
              !freshFirst &&
              !(previous is md.Element && previous.tag == 'pagebreak')) {
            result.add(pw.NewPage());
          } else if (!(next is md.Element && next.tag == 'pagebreak')) {
            result.add(
              pw.NewPage(freeSpace: math.min(pageHeight, height + following)),
            );
          }
          result.add(
            _PublicationAnchor(
              pages: headingPages,
              name: e.attributes['id']!,
              child: pw.Header(
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: border, width: .3),
                  ),
                ),
                level: int.parse(e.tag[1]) - 1,
                title: e.textContent,
                text: e.textContent,
                child: _PublicationAlignedText(
                  textAlign: paragraphAlignment(e),
                  text: pw.TextSpan(
                    children: [inline(e)],
                    style: pw.TextStyle(
                      fontSize: s.headingSize(int.parse(e.tag[1])),
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
              border: pw.TableBorder.all(color: border),
              children: [
                for (final (index, row) in sourceRows.indexed)
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: row.any((c) => c is md.Element && c.tag == 'th')
                          ? pdfTheme == null
                                ? PdfColors.grey200
                                : color(
                                    pdfTheme!
                                        .theme
                                        .colorScheme
                                        .surfaceContainerHigh
                                        .toARGB32(),
                                  )
                          : index.isOdd
                          ? pdfTheme == null
                                ? PdfColors.grey100
                                : color(
                                    pdfTheme!
                                        .theme
                                        .colorScheme
                                        .surfaceContainerLow
                                        .toARGB32(),
                                  )
                          : pdfTheme == null
                          ? PdfColors.white
                          : color(
                              pdfTheme!.theme.colorScheme.surface.toARGB32(),
                            ),
                    ),
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

          final spare = pageWidth * (100 - options.width) / 100;
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
          final desiredWidth = pageWidth * options.width / 100;
          final previous = nodeIndex > 0 ? nodes[nodeIndex - 1] : null;
          final figureHeight =
              previous is md.Element &&
                  publicationHeadingTarget(previous) &&
                  !options.pageBreakBefore
              ? math.max(40.0, pageHeight - headingHeight(previous) - 24)
              : pageHeight;
          final fittedWidth = bytes == null
              ? desiredWidth
              : _imageWidth(bytes, desiredWidth, figureHeight);
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
                      height: _imageHeight(bytes, fittedWidth, figureHeight),
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
          result.add(pw.Divider(color: border));
          continue;
        }
        if (e.tag == 'blockquote') {
          result.addAll(blocks(e.children ?? []));
          continue;
        }
        if (e.tag == 'math') {
          final bytes = pdfEquations[e.textContent];
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
            child: _PublicationAlignedText(
              text: inline(e),
              textAlign: paragraphAlignment(e),
              overflow: pw.TextOverflow.span,
            ),
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
          pageTheme: pw.PageTheme(
            pageFormat: format,
            theme: theme,
            buildBackground: backdrop == null
                ? null
                : (_) => pw.FullPage(
                    ignoreMargins: true,
                    child: pw.Image(backdrop, fit: pw.BoxFit.fill),
                  ),
          ),
          maxPages: 500,
          header: (context) {
            // MultiPage's maxPages is a debug progress guard, not a release-mode
            // document limit. Fail visibly rather than silently truncate or hang.
            if (context.pageNumber > 500) {
              throw const FormatException(
                'PDF exceeds 500 pages. Export smaller sections; no partial PDF was saved.',
              );
            }
            if (s.header.trim().isEmpty) return pw.SizedBox();
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text(
                s.header,
                style: pw.TextStyle(fontSize: 9, color: subtle),
              ),
            );
          },
          footer: (context) => s.pageNumbers
              ? pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 8),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          document.title,
                          maxLines: 1,
                          style: pw.TextStyle(fontSize: 8, color: subtle),
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Text(
                        '${context.pageNumber} / ${context.pagesCount}',
                        style: pw.TextStyle(fontSize: 9, color: subtle),
                      ),
                    ],
                  ),
                )
              : pw.SizedBox(),
          build: (_) => [
            if (s.titlePage) ...[
              pw.SizedBox(height: 80),
              pw.Text(
                document.title,
                style: pw.TextStyle(font: bold, fontSize: s.headingSize(1) + 5),
                overflow: pw.TextOverflow.span,
              ),
              pw.SizedBox(height: 20),
              pw.Text(s.author, overflow: pw.TextOverflow.span),
              pw.NewPage(),
            ] else if (!titleInBody)
              pw.Header(
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: border, width: .3),
                  ),
                ),
                level: 0,
                title: document.title,
                text: document.title,
                child: pw.Text(
                  document.title,
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: s.headingSize(1) + 1,
                  ),
                  overflow: pw.TextOverflow.span,
                ),
              ),
            if (s.contents && document.headings.isNotEmpty) ...[
              pw.Text(
                'Contents',
                style: pw.TextStyle(font: bold, fontSize: s.headingSize(2)),
              ),
              pw.SizedBox(height: 16),
              for (final heading in document.headings)
                pw.Padding(
                  padding: pw.EdgeInsets.only(
                    left: (heading.level - 1) * 12,
                    bottom: 8,
                  ),
                  child: heading.text.length > 300
                      ? pw.RichText(
                          overflow: pw.TextOverflow.span,
                          text: pw.TextSpan(
                            text:
                                '${heading.text}  ${tocPages[heading.id] ?? ''}',
                            annotation: pw.AnnotationLink(heading.id),
                          ),
                        )
                      : pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              child: pw.RichText(
                                text: pw.TextSpan(
                                  text: heading.text,
                                  annotation: pw.AnnotationLink(heading.id),
                                ),
                              ),
                            ),
                            pw.SizedBox(width: 12),
                            pw.SizedBox(
                              width: 34,
                              child: pw.Align(
                                alignment: pw.Alignment.topRight,
                                child: pw.Text(
                                  '${tocPages[heading.id] ?? ''}',
                                  style: pw.TextStyle(color: subtle),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              pw.NewPage(),
            ],
            ...blocks(document.nodes),
            if (document.footnotes.isNotEmpty) ...[
              pw.Header(
                level: 0,
                text: 'Footnotes',
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: border, width: .3),
                  ),
                ),
              ),
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
    final needsFinalPass =
        !finalPass && s.contents && document.headings.isNotEmpty;
    if (!needsFinalPass) await appendPages?.call(pdf);
    if (pdf.document.pdfPageList.pages.length > 500) {
      throw const FormatException(
        'PDF exceeds 500 pages. No partial PDF was saved.',
      );
    }
    final bytes = await pdf.save();
    pageCount = pdf.document.pdfPageList.pages.length;
    if (needsFinalPass) return await _pdf(true, appendPages);
    return bytes;
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
      properties:
          (e.attributes['orbit-text-align'] == null
              ? ''
              : '<w:jc w:val="${e.attributes['orbit-text-align'] == 'justify' ? 'both' : e.attributes['orbit-text-align']}"/>') +
          (heading
              ? '<w:pStyle w:val="Heading${e.tag[1]}"/>${(e.attributes['orbit-pageBreakBefore'] == 'true' || e.attributes['orbit-h1-pagebreak'] == 'true') ? '<w:pageBreakBefore/>' : ''}'
              : ''),
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
      '<w:styles $ns><w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="$font" w:hAnsi="$font"/><w:sz w:val="${(s.fontSize * 2).round()}"/></w:rPr></w:rPrDefault></w:docDefaults><w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:rPr><w:b/><w:sz w:val="${((s.headingSize(1) + 5) * 2).round()}"/></w:rPr></w:style>${List.generate(6, (i) => '<w:style w:type="paragraph" w:styleId="Heading${i + 1}"><w:name w:val="heading ${i + 1}"/><w:pPr><w:keepNext/><w:outlineLvl w:val="$i"/></w:pPr><w:rPr><w:b/><w:sz w:val="${(s.headingSize(i + 1) * 2).round()}"/></w:rPr></w:style>').join()}</w:styles>',
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
