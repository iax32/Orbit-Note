import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:markdown/markdown.dart' as md;

/// Print-only options. Ordinary Markdown remains the owning document.
class PublicationBlockLayout {
  const PublicationBlockLayout({
    this.width = 100,
    this.alignment = 'left',
    this.caption = '',
    this.pageBreakBefore = false,
    this.repeatHeader = true,
  });
  final int width;
  final String alignment, caption;
  final bool pageBreakBefore, repeatHeader;
  Map<String, dynamic> toJson() => {
    'width': width,
    'alignment': alignment,
    'caption': caption,
    'pageBreakBefore': pageBreakBefore,
    'repeatHeader': repeatHeader,
  };
  static PublicationBlockLayout fromJson(Map<String, dynamic> value) {
    final result = PublicationBlockLayout(
      width: value['width'] as int? ?? 100,
      alignment: value['alignment'] as String? ?? 'left',
      caption: value['caption'] as String? ?? '',
      pageBreakBefore: value['pageBreakBefore'] as bool? ?? false,
      repeatHeader: value['repeatHeader'] as bool? ?? true,
    );
    if (result.width < 25 ||
        result.width > 100 ||
        !['left', 'center', 'right'].contains(result.alignment) ||
        result.caption.length > 2000 ||
        result.caption.contains(RegExp(r'[\r\n]'))) {
      throw const FormatException('Invalid image/table print layout.');
    }
    return result;
  }
}

/// One bounded, versioned comment at the beginning of a note body. Future and
/// malformed records remain literal; updates preserve unfamiliar JSON fields.
class PublicationSettings {
  const PublicationSettings(this.data, this.end);
  final Map<String, dynamic> data;
  final int end;
  static const prefix = '<!-- orbit:publication ';
  static PublicationSettings? parse(String source) {
    if (!source.startsWith(prefix)) return null;
    final match = RegExp(
      r'^<!-- orbit:publication (.+) -->(?:\r?\n|$)',
    ).firstMatch(source);
    if (match == null || match.end > 256000) return null;
    try {
      final data = Map<String, dynamic>.from(jsonDecode(match[1]!) as Map);
      if (data['version'] != 1 ||
          data['style'] is! Map ||
          data['blocks'] is! Map) {
        return null;
      }
      final style = data['style'] as Map;
      for (final field in [
        'letter',
        'serif',
        'numberHeadings',
        'titlePage',
        'contents',
        'pageNumbers',
      ]) {
        if (style.containsKey(field) && style[field] is! bool) return null;
      }
      for (final field in ['author', 'header']) {
        if (style.containsKey(field) &&
            (style[field] is! String ||
                (style[field] as String).length > 500)) {
          return null;
        }
      }
      for (final field in ['margin', 'fontSize']) {
        final value = style[field];
        if (value != null &&
            (value is! num ||
                !value.isFinite ||
                value < (field == 'margin' ? 24 : 9) ||
                value > (field == 'margin' ? 90 : 18))) {
          return null;
        }
      }
      final blocks = data['blocks'] as Map;
      if (blocks.length > 1000) return null;
      for (final entry in blocks.entries) {
        if (entry.key is! String ||
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(entry.key as String)) {
          return null;
        }
        PublicationBlockLayout.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
      return PublicationSettings(data, match.end);
    } catch (_) {
      return null;
    }
  }

  static bool metadataLine(String line) => parse(line) != null;
  static String mask(String source) {
    final record = parse(source);
    if (record == null) return source;
    return source.substring(0, record.end).replaceAll(RegExp(r'[^\r\n]'), ' ') +
        source.substring(record.end);
  }

  static String update(
    String source,
    Map<String, dynamic> style,
    Map<String, Map<String, dynamic>> blocks, {
    Map<String, dynamic>? article,
  }) {
    final existing = parse(source);
    if (source.startsWith(prefix) && existing == null) {
      throw const FormatException(
        'Unknown publishing settings are preserved. Repair them in Source before saving settings.',
      );
    }
    final eol = source.contains('\r\n') ? '\r\n' : '\n';
    final json =
        jsonEncode({
              ...?existing?.data,
              'version': 1,
              'style': {
                ...?((existing?.data['style'] as Map?)
                    ?.cast<String, dynamic>()),
                ...style,
              },
              'blocks': blocks,
              'article': ?article,
            })
            .replaceAll('<', r'\u003c')
            .replaceAll('>', r'\u003e')
            .replaceAll('&', r'\u0026');
    final encoded = '$prefix$json -->$eol';
    if (encoded.length > 256000) {
      throw const FormatException('Publishing settings are too large.');
    }
    if (parse(encoded) == null) {
      throw const FormatException('Invalid publishing settings.');
    }
    return '$encoded${source.substring(existing?.end ?? 0)}';
  }
}

bool publicationLayoutTarget(md.Node node) =>
    node is md.Element &&
    (node.tag == 'table' ||
        (node.tag == 'p' &&
            node.children?.length == 1 &&
            node.children!.single is md.Element &&
            (node.children!.single as md.Element).tag == 'img'));

String publicationLayoutKey(md.Node node) {
  Object encode(md.Node n) => n is md.Text
      ? n.text
      : [
          (n as md.Element).tag,
          {
            for (final k in n.attributes.keys.toList()..sort())
              if (!k.startsWith('orbit-')) k: n.attributes[k],
          },
          (n.children ?? []).map(encode).toList(),
        ];
  return sha256.convert(utf8.encode(jsonEncode(encode(node)))).toString();
}
