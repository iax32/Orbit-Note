import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_draft_guard.dart';
import '../../domain/document_publication.dart';
import '../../domain/technical_article.dart';
import '../../domain/universal_object.dart';
import '../../platform/export_file.dart';
import 'export/publication_export.dart';

class ArticlePublishingDialog extends StatefulWidget {
  const ArticlePublishingDialog({
    super.key,
    required this.title,
    required this.source,
    this.objects = const [],
    this.ownerId = '',
    this.onApply,
  });
  final String title, source, ownerId;
  final List<UniversalObject> objects;
  final bool Function(String before, String next)? onApply;
  @override
  State<ArticlePublishingDialog> createState() =>
      _ArticlePublishingDialogState();
}

class _ArticlePublishingDialogState extends State<ArticlePublishingDialog> {
  static const labels = {
    'title': 'Search title',
    'description': 'Meta description',
    'author': 'Author',
    'authorUrl': 'Author profile URL',
    'canonicalUrl': 'Canonical article URL',
    'imageUrl': 'Representative image URL',
    'language': 'Language',
    'published': 'First published (YYYY-MM-DD)',
    'modified': 'Updated (YYYY-MM-DD)',
  };
  late final fields = {
    for (final key in ArticleMetadata.fields) key: TextEditingController(),
  };
  bool indexable = true, busy = false;
  String? error, notice, metadataError;
  List<String> contentChecks = const [];
  late String source;
  late Map<String, String> appliedFields;
  late bool appliedIndexable;
  void rememberFields() {
    appliedFields = {for (final e in fields.entries) e.key: e.value.text};
    appliedIndexable = indexable;
  }

  bool get dirty =>
      indexable != appliedIndexable ||
      fields.entries.any((e) => e.value.text != appliedFields[e.key]);
  @override
  void initState() {
    super.initState();
    source = widget.source;
    try {
      final old = ArticleMetadata.fromSource(source);
      for (final entry in fields.entries) {
        entry.value.text = old?.text(entry.key) ?? '';
      }
      if (old == null) {
        fields['title']!.text = widget.title;
        fields['language']!.text = 'en';
      }
      indexable = old?.indexable ?? true;
    } on FormatException catch (failure) {
      metadataError = failure.message;
    }
    try {
      contentChecks = articleContentChecks(source);
    } on FormatException catch (failure) {
      contentChecks = [failure.message];
    }
    rememberFields();
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  ArticleMetadata get metadata => ArticleMetadata({
    'version': 1,
    for (final entry in fields.entries) entry.key: entry.value.text.trim(),
    'indexable': indexable,
  });

  Future<void> openGuide(String path) async {
    try {
      if (!await launchUrl(
        Uri.https('developers.google.com', path),
        mode: LaunchMode.externalApplication,
      )) {
        throw const FormatException('The browser could not open the guide.');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not open the browser. Your article settings are retained. Google Search Central: developers.google.com/search/docs',
        );
      }
    }
  }

  Future<void> action(String kind) async {
    if (busy || metadataError != null) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      final settings = metadata, next = settings.apply(source);
      if (kind == 'save') {
        if (widget.onApply?.call(source, next) != true) {
          throw const FormatException(
            'The note changed or cannot be edited. Reopen this panel; the current text is preserved.',
          );
        }
        source = next;
        rememberFields();
        notice =
            'Article settings applied. The note uses its normal autosave and history.';
      } else if (kind == 'handoff' || kind == 'schema') {
        await Clipboard.setData(
          ClipboardData(
            text: kind == 'handoff'
                ? settings.cmsHandoff(widget.title)
                : settings.schemaJson(widget.title),
          ),
        );
        notice = kind == 'handoff'
            ? 'CMS handoff copied.'
            : 'Article JSON-LD copied. Check existing CMS schema before adding it.';
      } else {
        final document = PublicationDocument.parse(
          widget.title,
          next,
          const PublicationStyle(contents: false),
          objects: widget.objects,
          ownerId: widget.ownerId,
        );
        final exporter = PublicationExport(document);
        final html = exporter.html(articleFragment: kind == 'cms');
        if (kind == 'cms') {
          await Clipboard.setData(ClipboardData(text: html));
          notice =
              'CMS HTML copied. Set the post title separately; upload figures and preview links/code formatting. ${exporter.warnings.join(' ')}';
        } else {
          final saved = await exportFile(
            '${publicationFileName(widget.title)}.html',
            html,
            mimeType: 'text/html',
          );
          notice = !saved
              ? 'Export cancelled.'
              : 'HTML exported. ${exporter.warnings.join(' ')}';
        }
      }
    } catch (failure) {
      error = '$failure';
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    List<String> checks;
    try {
      checks = [
        ...articleMetadataChecks(widget.title, metadata),
        ...contentChecks,
      ];
    } catch (failure) {
      checks = ['$failure'];
    }
    return OrbitDraftGuard(
      dirty: dirty,
      busy: busy,
      builder: (context, requestClose) => OrbitDialog(
        maxWidth: 820,
        title: const Text('Article publishing'),
        content: SizedBox(
          width: 760,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .65,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Prepare a technical article for WordPress or another CMS. These offline checks improve clarity and publishing readiness; they cannot predict rankings or diagnose a Google penalty.',
                  ),
                  const SizedBox(height: 16),
                  if (metadataError != null)
                    Text(
                      'Article metadata is unsupported and retained: $metadataError',
                    ),
                  for (final entry in fields.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        key: ValueKey('article-${entry.key}'),
                        controller: entry.value,
                        enabled: !busy && metadataError == null,
                        maxLength: 2000,
                        minLines: 1,
                        maxLines: entry.key == 'description' ? 3 : 1,
                        decoration: InputDecoration(
                          labelText: labels[entry.key],
                          counterText: '',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Allow indexing of exported HTML'),
                    subtitle: const Text(
                      'The CMS and host can override this. A noindex draft is intentionally excluded.',
                    ),
                    value: indexable,
                    onChanged: busy || metadataError != null
                        ? null
                        : (v) => setState(() => indexable = v),
                  ),
                  const Divider(),
                  Text(
                    'Editorial and publishing checks',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  for (final check in checks)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text('• $check'),
                    ),
                  const ExpansionTile(
                    title: Text('WordPress handoff and Google diagnostics'),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Paste CMS HTML into a Custom HTML block and set the post title separately. Head metadata and JSON-LD do not belong in the post body; configure them through your CMS. WordPress may sanitize SVG or scripts. Export Canvas figures, upload them to the CMS, replace private links, and preview the public page.\n\nCheck HTTP 200, public access, canonical URL, robots rules, noindex, a sitemap and Search Console URL Inspection. For missing pages or traffic drops, check Page indexing, Manual Actions and Security Issues. Avoid keyword stuffing and automated low-value content. There is no guaranteed first-place ranking or automatic “shadowban” detector.',
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => openGuide(
                          '/search/docs/fundamentals/seo-starter-guide',
                        ),
                        child: const Text('Google SEO guide'),
                      ),
                      TextButton(
                        onPressed: () => openGuide(
                          '/search/docs/monitor-debug/debugging-search-traffic-drops',
                        ),
                        child: const Text('Search traffic diagnostics'),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in {
                        'cms': 'Copy CMS HTML',
                        'handoff': 'Copy CMS handoff',
                        'schema': 'Copy Article JSON-LD',
                        'html': 'Export standalone HTML',
                      }.entries)
                        OutlinedButton(
                          onPressed: busy || metadataError != null
                              ? null
                              : () => action(entry.key),
                          child: Text(entry.value),
                        ),
                    ],
                  ),
                  if (notice != null)
                    Semantics(
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(notice!),
                      ),
                    ),
                  if (error != null)
                    Semantics(liveRegion: true, child: Text(error!)),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : requestClose,
            child: const Text('Close'),
          ),
          if (widget.onApply != null)
            FilledButton(
              onPressed: busy || metadataError != null
                  ? null
                  : () => action('save'),
              child: const Text('Apply to note'),
            ),
        ],
      ),
    );
  }
}
