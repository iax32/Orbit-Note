import 'package:flutter/material.dart';
import '../../domain/document_citations.dart';
import '../../domain/citation_library.dart';
import '../../domain/bibtex.dart';
import '../../platform/export_file.dart';
import 'citation_import_dialog.dart';

class CitationWorkspace extends StatefulWidget {
  const CitationWorkspace({
    super.key,
    required this.source,
    required this.onApply,
    required this.onInsert,
    required this.onClose,
    this.libraries = const [],
    this.onCreateLibrary,
    this.onOpenLibrary,
  });
  final String source;
  final bool Function(String before, String next) onApply;
  final void Function(String content) onInsert;
  final VoidCallback onClose;
  final List<CitationLibrary> libraries;
  final Future<void> Function(String title, String body)? onCreateLibrary;
  final ValueChanged<String>? onOpenLibrary;
  @override
  State<CitationWorkspace> createState() => _CitationWorkspaceState();
}

class _CitationWorkspaceState extends State<CitationWorkspace> {
  final query = TextEditingController();
  String? error;
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  void apply(String Function(DocumentCitations) change) {
    try {
      if (!widget.onApply(
        widget.source,
        change(DocumentCitations(widget.source)),
      )) {
        throw const FormatException(
          'The note changed. Reopen citations and try again.',
        );
      }
      setState(() => error = null);
    } catch (e) {
      setState(() => error = '$e');
    }
  }

  Future<void> importSources({bool reuse = false}) async {
    final before = widget.source;
    final plan = await showCitationImport(
      context,
      before,
      libraries: reuse ? widget.libraries : const [],
    );
    if (!mounted || plan == null) return;
    if (!widget.onApply(before, plan.result)) {
      setState(
        () => error =
            'The note changed while reviewing. Reopen the import before applying.',
      );
    } else {
      setState(() => error = null);
    }
  }

  Future<void> exportSources() async {
    try {
      final text = exportBibtex(DocumentCitations(widget.source));
      final saved = await exportFile(
        'references.bib',
        text,
        mimeType: 'application/x-bibtex',
      );
      if (mounted && saved) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('BibTeX exported')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = 'Export failed; the note is unchanged. $e');
      }
    }
  }

  Future<void> createLibrary() async {
    final before = widget.source;
    final title = TextEditingController(text: 'Source library');
    final route = DialogRoute<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create reusable source library'),
        content: TextField(
          controller: title,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Library name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, title.text.trim()),
            child: const Text('Create library'),
          ),
        ],
      ),
    );
    final name = await Navigator.of(context).push(route);
    await route.completed;
    title.dispose();
    if (!mounted || name == null || name.isEmpty) return;
    if (widget.source != before) {
      setState(
        () => error = 'Sources changed while naming the library. Try again.',
      );
      return;
    }
    try {
      await widget.onCreateLibrary?.call(
        name,
        sourceLibraryBody(DocumentCitations(before)),
      );
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> edit([CitationSource? item]) async {
    final before = widget.source;
    final fields = {
      'Identifier':
          item?.id ?? 'source-${DateTime.now().microsecondsSinceEpoch}',
      'Title': item?.title ?? '',
      'Author(s)': item?.author ?? '',
      'Year': item?.year ?? '',
      'Publisher / journal': item?.publisher ?? '',
      'DOI': item?.doi ?? '',
      'ISBN': item?.isbn ?? '',
      'URL': item?.url ?? '',
    }.map((k, v) => MapEntry(k, TextEditingController(text: v)));
    String? validation;
    final route = DialogRoute<CitationSource>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(
            item == null ? 'Add reference source' : 'Edit reference source',
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final field in fields.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: field.value,
                        readOnly: field.key == 'Identifier',
                        maxLength: 2000,
                        decoration: InputDecoration(
                          labelText: field.key,
                          counterText: '',
                        ),
                      ),
                    ),
                  if (validation != null) Text(validation!),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = CitationSource(
                  id: fields['Identifier']!.text,
                  title: fields['Title']!.text.trim(),
                  author: fields['Author(s)']!.text.trim(),
                  year: fields['Year']!.text.trim(),
                  publisher: fields['Publisher / journal']!.text.trim(),
                  doi: fields['DOI']!.text.trim(),
                  isbn: fields['ISBN']!.text.trim(),
                  url: fields['URL']!.text.trim(),
                );
                try {
                  value.validate();
                  Navigator.pop(context, value);
                } catch (e) {
                  update(() => validation = '$e');
                }
              },
              child: const Text('Save source'),
            ),
          ],
        ),
      ),
    );
    final draft = await Navigator.of(context).push(route);
    await route.completed;
    for (final controller in fields.values) {
      controller.dispose();
    }
    if (!mounted || draft == null) return;
    if (before != widget.source) {
      setState(
        () => error =
            'The note changed while editing. Your source was not overwritten.',
      );
      return;
    }
    apply(
      (model) =>
          DocumentCitations(model.save(draft)).refresh(addBibliography: false),
    );
  }

  Future<void> insert(CitationSource item) async {
    final before = widget.source;
    final locator = TextEditingController();
    final route = DialogRoute<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cite source'),
        content: TextField(
          controller: locator,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Page or section (optional)',
            hintText: 'p. 42',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, locator.text.trim()),
            child: const Text('Insert citation'),
          ),
        ],
      ),
    );
    final value = await Navigator.of(context).push(route);
    await route.completed;
    locator.dispose();
    if (!mounted || value == null) return;
    if (before != widget.source) {
      setState(
        () => error = 'The note changed. Reopen citations before inserting.',
      );
      return;
    }
    widget.onInsert(DocumentCitations.citation(item, value));
  }

  @override
  Widget build(BuildContext context) {
    final model = DocumentCitations(widget.source);
    final items = model.sources.values
        .where(
          (s) => '${s.description} ${s.id}'.toLowerCase().contains(
            query.text.toLowerCase(),
          ),
        )
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Citations & bibliography',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Close citations',
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const Text(
                'Local sources • readable Markdown • no document uploads',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: query,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Search sources',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: edit,
                    icon: const Icon(Icons.add),
                    label: const Text('Add source'),
                  ),
                  OutlinedButton(
                    onPressed: () => importSources(),
                    child: const Text('Import BibTeX'),
                  ),
                  OutlinedButton(
                    onPressed: widget.libraries.isEmpty
                        ? null
                        : () => importSources(reuse: true),
                    child: const Text('Reuse library sources'),
                  ),
                  OutlinedButton(
                    onPressed: model.sources.isEmpty ? null : exportSources,
                    child: const Text('Export BibTeX'),
                  ),
                  OutlinedButton(
                    onPressed:
                        widget.onCreateLibrary == null || model.sources.isEmpty
                        ? null
                        : createLibrary,
                    child: const Text('Create source library'),
                  ),
                  OutlinedButton(
                    onPressed: () =>
                        apply((m) => m.refresh(numberedStyle: false)),
                    child: const Text('Author–year bibliography'),
                  ),
                  OutlinedButton(
                    onPressed: () =>
                        apply((m) => m.refresh(numberedStyle: true)),
                    child: const Text('Numbered bibliography'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${model.sources.length} sources · ${model.occurrences.length} citations. Compact styles; not full APA, MLA or CSL formatting.',
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(error!, semanticsLabel: 'Citation error: $error'),
                ),
              for (final warning in model.warnings.toSet())
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(warning),
                ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Add a source, then cite it at your writing position. Only cited sources appear in References.',
                  ),
                ),
              for (final item in items)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(item.description),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: model.duplicates.contains(item.id)
                                  ? null
                                  : () => insert(item),
                              child: const Text('Cite'),
                            ),
                            TextButton(
                              onPressed: () => edit(item),
                              child: const Text('Edit metadata'),
                            ),
                            if (model.record(item.id)['citationLibrary']
                                    is Map &&
                                (model.record(item.id)['citationLibrary']
                                        as Map)['objectId']
                                    is String)
                              TextButton(
                                onPressed: widget.onOpenLibrary == null
                                    ? null
                                    : () => widget.onOpenLibrary!(
                                        (model.record(
                                                  item.id,
                                                )['citationLibrary']
                                                as Map)['objectId']
                                            as String,
                                      ),
                                child: const Text('Open source library'),
                              ),
                            TextButton(
                              onPressed:
                                  model.occurrences.any((c) => c.id == item.id)
                                  ? null
                                  : () => apply((m) => m.remove(item.id)),
                              child: const Text('Remove unused source'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
