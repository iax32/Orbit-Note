import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../../domain/bibtex.dart';
import '../../domain/citation_library.dart';
import '../../domain/document_citations.dart';

Future<CitationImportPlan?> showCitationImport(
  BuildContext context,
  String source, {
  List<CitationLibrary> libraries = const [],
}) => showDialog<CitationImportPlan>(
  context: context,
  builder: (_) => CitationImportDialog(source: source, libraries: libraries),
);

class CitationImportDialog extends StatefulWidget {
  const CitationImportDialog({
    super.key,
    required this.source,
    this.libraries = const [],
  });
  final String source;
  final List<CitationLibrary> libraries;
  @override
  State<CitationImportDialog> createState() => _CitationImportDialogState();
}

class _CitationImportDialogState extends State<CitationImportDialog> {
  final text = TextEditingController();
  List<Map<String, dynamic>> records = [];
  List<String> warnings = [];
  final selected = <int>{};
  CitationImportPolicy policy = CitationImportPolicy.keepExisting;
  String? error, library;
  bool loading = false;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  void preview() {
    try {
      final imported = BibtexImport(text.text);
      setState(() {
        records = imported.records;
        warnings = imported.warnings;
        selected
          ..clear()
          ..addAll(List.generate(records.length, (i) => i));
        error = null;
      });
    } catch (e) {
      setState(() {
        error = '$e';
        records = [];
        selected.clear();
      });
    }
  }

  void useLibrary(String? id) {
    final choice = widget.libraries.where((l) => l.id == id).firstOrNull;
    if (choice == null) return;
    final model = DocumentCitations(choice.source);
    setState(() {
      library = id;
      error = null;
      warnings = model.warnings;
      records = [
        for (final item in model.sources.values)
          if (!model.duplicates.contains(item.id))
            {
              ...model.record(item.id),
              'citationLibrary': {'objectId': choice.id, 'title': choice.title},
            },
      ];
      selected
        ..clear()
        ..addAll(List.generate(records.length, (i) => i));
    });
  }

  Future<void> openBibtex() async {
    setState(() => loading = true);
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'BibTeX',
            extensions: ['bib'],
            mimeTypes: ['text/plain', 'application/x-bibtex'],
          ),
        ],
      );
      if (file == null || !mounted) return;
      if (await file.length() > 1024 * 1024) {
        throw const FormatException('BibTeX files must be at most 1 MiB.');
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > 1024 * 1024) {
        throw const FormatException('The file grew beyond the import limit.');
      }
      final value = utf8.decode(bytes);
      if (!mounted) return;
      text.text = value;
      preview();
    } catch (e) {
      if (mounted) setState(() => error = 'Could not read BibTeX: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    CitationImportPlan? plan;
    String? conflictError;
    try {
      plan = CitationImportPlan(widget.source, [
        for (final index in selected) records[index],
      ], policy);
    } catch (e) {
      conflictError = '$e';
    }
    return Dialog(
      child: SizedBox(
        width: 720,
        height: MediaQuery.sizeOf(context).height * .88,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.libraries.isEmpty
                                ? 'Import BibTeX'
                                : 'Source libraries',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close import',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  if (widget.libraries.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: library,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Source library',
                      ),
                      items: [
                        for (final item in widget.libraries)
                          DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: useLibrary,
                    )
                  else ...[
                    TextField(
                      controller: text,
                      minLines: 3,
                      maxLines: 7,
                      maxLength: 1024 * 1024,
                      decoration: const InputDecoration(
                        labelText: 'Paste BibTeX',
                        hintText:
                            '@article{key, title={Title}, author={Author}, year={2026}}',
                        counterText: '',
                      ),
                      onChanged: (_) => setState(() {
                        records = [];
                        selected.clear();
                        error = null;
                        warnings = [];
                      }),
                    ),
                    Wrap(
                      spacing: 12,
                      children: [
                        TextButton.icon(
                          onPressed: loading ? null : openBibtex,
                          icon: const Icon(Icons.file_open_outlined),
                          label: const Text('Open .bib file'),
                        ),
                        FilledButton(
                          onPressed: loading ? null : preview,
                          child: const Text('Preview import'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'Select sources and review conflicts before changing the note. Macro-based entries are skipped; TeX is never executed.',
                  ),
                  DropdownButtonFormField<CitationImportPolicy>(
                    initialValue: policy,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Identifier or DOI conflicts',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: CitationImportPolicy.keepExisting,
                        child: Text('Keep existing; skip incoming'),
                      ),
                      DropdownMenuItem(
                        value: CitationImportPolicy.renameIncoming,
                        child: Text('Add incoming with a new key'),
                      ),
                      DropdownMenuItem(
                        value: CitationImportPolicy.replaceExisting,
                        child: Text('Replace metadata; retain existing key'),
                      ),
                    ],
                    onChanged: (value) => setState(() => policy = value!),
                  ),
                  const SizedBox(height: 12),
                  if (error != null) Text(error!),
                  if (conflictError != null) Text(conflictError),
                  for (final warning in warnings.toSet())
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(warning),
                    ),
                  if (plan != null)
                    Text(
                      '${plan.added} added · ${plan.replaced} replaced · ${plan.skipped} skipped',
                    ),
                  for (final conflict in plan?.conflicts ?? <String>[])
                    Text(conflict),
                  for (var i = 0; i < records.length; i++)
                    CheckboxListTile(
                      value: selected.contains(i),
                      title: Text(CitationSource.fromJson(records[i]).title),
                      subtitle: Text(
                        '${records[i]['id']} · ${CitationSource.fromJson(records[i]).description}',
                      ),
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          selected.add(i);
                        } else {
                          selected.remove(i);
                        }
                      }),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: plan == null || selected.isEmpty || loading
                        ? null
                        : () => Navigator.pop(context, plan),
                    child: const Text('Import selected sources'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
