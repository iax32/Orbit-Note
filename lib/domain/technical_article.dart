import 'dart:convert';
import 'package:markdown/markdown.dart' as md;
import 'publication_layout.dart';

/// Optional article fields live in the existing portable publishing record.
/// Unknown fields and future versions are retained, never silently replaced.
class ArticleMetadata {
  ArticleMetadata(Map<String, dynamic> data) : data = Map.unmodifiable(data) {
    if (data['version'] != 1) {
      throw const FormatException('Unsupported article metadata version.');
    }
    for (final key in fields) {
      final value = data[key];
      if (value != null &&
          (value is! String ||
              value.length > 2000 ||
              value.contains(RegExp(r'[\r\n\x00-\x1f]')))) {
        throw FormatException('Invalid article field: $key.');
      }
    }
    if (data['indexable'] != null && data['indexable'] is! bool) {
      throw const FormatException('Invalid indexing choice.');
    }
    for (final key in ['canonicalUrl', 'authorUrl', 'imageUrl']) {
      if (text(key).isNotEmpty && !webUrl(text(key))) {
        throw FormatException(
          '$key must be an absolute HTTP or HTTPS URL without credentials.',
        );
      }
    }
    if (text('language').isNotEmpty &&
        !RegExp(
          r'^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$',
        ).hasMatch(text('language'))) {
      throw const FormatException('Use a language tag such as en or de-AT.');
    }
    for (final key in ['published', 'modified']) {
      final value = text(key);
      if (value.isNotEmpty &&
          (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
              DateTime.tryParse(value)?.toIso8601String().substring(0, 10) !=
                  value)) {
        throw const FormatException(
          'Dates must be real calendar dates: YYYY-MM-DD.',
        );
      }
    }
    if (text('published').isNotEmpty &&
        text('modified').isNotEmpty &&
        text('modified').compareTo(text('published')) < 0) {
      throw const FormatException('Updated date cannot precede publication.');
    }
  }
  final Map<String, dynamic> data;
  static const fields = [
    'title',
    'description',
    'author',
    'authorUrl',
    'canonicalUrl',
    'imageUrl',
    'language',
    'published',
    'modified',
  ];
  String text(String key) => data[key] as String? ?? '';
  bool get indexable => data['indexable'] != false;
  static bool webUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        ['http', 'https'].contains(uri.scheme) &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !value.contains(RegExp(r'\s'));
  }

  static ArticleMetadata? fromSource(String source) {
    final value = PublicationSettings.parse(source)?.data['article'];
    if (value == null) return null;
    if (value is! Map) throw const FormatException('Invalid article metadata.');
    return ArticleMetadata(Map<String, dynamic>.from(value));
  }

  String apply(String source) {
    final old = PublicationSettings.parse(source);
    // A caller cannot replace a future version by constructing a fresh record.
    fromSource(source);
    return PublicationSettings.update(
      source,
      Map<String, dynamic>.from(old?.data['style'] as Map? ?? const {}),
      {
        for (final e in (old?.data['blocks'] as Map? ?? const {}).entries)
          e.key as String: Map<String, dynamic>.from(e.value as Map),
      },
      article: {...?(old?.data['article'] as Map?), ...data},
    );
  }

  Map<String, dynamic> schema(String fallbackTitle) => {
    '@context': 'https://schema.org',
    '@type': 'Article',
    'headline': text('title').isEmpty ? fallbackTitle : text('title'),
    if (text('description').isNotEmpty) 'description': text('description'),
    if (text('canonicalUrl').isNotEmpty)
      'mainEntityOfPage': text('canonicalUrl'),
    if (text('author').isNotEmpty)
      'author': {
        '@type': 'Person',
        'name': text('author'),
        if (text('authorUrl').isNotEmpty) 'url': text('authorUrl'),
      },
    if (text('published').isNotEmpty) 'datePublished': text('published'),
    if (text('modified').isNotEmpty) 'dateModified': text('modified'),
    if (text('imageUrl').isNotEmpty) 'image': [text('imageUrl')],
    if (text('language').isNotEmpty) 'inLanguage': text('language'),
  };
  String schemaJson(String title) => const JsonEncoder.withIndent('  ')
      .convert(schema(title))
      .replaceAll('<', r'\u003c')
      .replaceAll('>', r'\u003e')
      .replaceAll('&', r'\u0026')
      .replaceAll('\u2028', r'\u2028')
      .replaceAll('\u2029', r'\u2029');
  String cmsHandoff(String fallbackTitle) =>
      '''# CMS publishing handoff

Post title: ${text('title').isEmpty ? fallbackTitle : text('title')}
Meta description: ${text('description')}
Canonical URL: ${text('canonicalUrl')}
Author: ${text('author')}
Author profile: ${text('authorUrl')}
Article language: ${text('language')}
Publication date: ${text('published')}
Updated date: ${text('modified')}
Representative image: ${text('imageUrl')}
Indexing intended: ${indexable ? 'allowed' : 'noindex'}

- Paste the article fragment in a CMS HTML block and preview it. Set the post title separately.
- Upload local figures to the CMS, replace their URLs, and retain descriptive alt text and captions.
- Set description, canonical, author and dates through the CMS or its SEO fields. Avoid duplicate Article schema if the CMS already generates it.
- Verify the public page returns HTTP 200, is accessible without login, and has no accidental noindex or robots.txt block.
- Use Search Console URL Inspection and sitemap submission after publishing. Check Page indexing, Manual Actions and Security Issues when diagnosing missing pages.
- Review original evidence, citations, build details, limitations and code examples. Avoid keyword stuffing, bought links, misleading dates and scaled low-value content.

These are editorial and technical checks, not a ranking, indexing or penalty guarantee. Orbit does not inspect your live website or publish it.
''';
}

/// Deterministic editorial prompts, not a fabricated SEO score or penalty scan.
List<String> articleChecks(
  String title,
  String source,
  ArticleMetadata metadata,
) => [
  ...articleMetadataChecks(title, metadata),
  ...articleContentChecks(source),
];

List<String> articleMetadataChecks(String title, ArticleMetadata metadata) => [
  if ((metadata.text('title').isEmpty ? title : metadata.text('title'))
      .trim()
      .isEmpty)
    'Add a descriptive article title.',
  if (metadata.text('description').isEmpty)
    'Write a useful summary for the meta description; Google may choose a different snippet.',
  if (metadata.text('author').isEmpty)
    'Identify the author and their relevant first-hand experience.',
  if (metadata.text('canonicalUrl').isEmpty)
    'Set the final canonical URL after choosing the CMS permalink.',
  if (!metadata.indexable)
    'Exported HTML requests noindex. Change this only when the article is ready for public indexing.',
];

List<String> articleContentChecks(String source) {
  if (source.length > 2000000) {
    throw const FormatException('Review up to 2 million characters at a time.');
  }
  final settings = PublicationSettings.parse(source);
  final body = source.substring(settings?.end ?? 0);
  final nodes = md.Document(
    extensionSet: md.ExtensionSet.gitHubWeb,
  ).parseLines(body.split(RegExp(r'\r?\n')));
  var imagesWithoutAlt = 0,
      privateLinks = 0,
      externalLinks = 0,
      previousLevel = 0,
      headingGaps = false;
  final prose = StringBuffer();
  void visit(md.Node node) {
    if (node is md.Text) {
      prose.write('${node.text} ');
      return;
    }
    final e = node as md.Element;
    if (['code', 'pre'].contains(e.tag)) return;
    if (e.tag == 'img' && (e.attributes['alt'] ?? '').trim().isEmpty) {
      imagesWithoutAlt++;
    }
    if (e.tag == 'a') {
      final href = e.attributes['href'] ?? '';
      if (ArticleMetadata.webUrl(href)) externalLinks++;
      if (href.startsWith('orbit:') ||
          href.startsWith('orbit-object:') ||
          href.startsWith('attachment:')) {
        privateLinks++;
      }
    }
    if (RegExp(r'^h[1-6]$').hasMatch(e.tag)) {
      final level = int.parse(e.tag.substring(1));
      if (previousLevel > 0 && level > previousLevel + 1) headingGaps = true;
      previousLevel = level;
    }
    for (final child in e.children ?? <md.Node>[]) {
      visit(child);
    }
  }

  for (final node in nodes) {
    visit(node);
  }
  return [
    if (imagesWithoutAlt > 0)
      '$imagesWithoutAlt image(s) need descriptive alternative text.',
    if (privateLinks > 0 || prose.toString().contains('[['))
      'Resolve private Vault links before publishing; public readers cannot open them.',
    if (externalLinks == 0)
      'Add relevant public sources or reproducible supporting material where useful.',
    if (headingGaps)
      'Review skipped heading levels for reader navigation and accessibility.',
    if (RegExp(
      r'\[(?:TODO|Fill in|Game /|Build /|Your |Question|Observation|Result)',
      caseSensitive: false,
    ).hasMatch(prose.toString()))
      'Replace unfinished template prompts before publishing.',
    'Manually verify evidence, reproducibility, build/version context and the distinction between observations and hypotheses.',
    'Live-site indexing, speed, mobile layout, robots rules and Google policy compliance require checks on the published page.',
  ];
}
