import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/orbit_components.dart';
import '../../app/workspace_controller.dart';
import '../../domain/knowledge_insights.dart';
import '../../domain/object_reference.dart';
import '../../domain/universal_object.dart';

class VaultInsightsDialog extends StatefulWidget {
  const VaultInsightsDialog({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<VaultInsightsDialog> createState() => _VaultInsightsDialogState();
}

class _VaultInsightsDialogState extends State<VaultInsightsDialog> {
  late VaultInsights report;
  late String workspace;
  late Map<String, int> pdfPhases;
  late int dirty, failures, warnings;
  late bool readOnly;
  String category = 'Connected';
  int page = 0;
  bool copied = false;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  void refresh() {
    final c = widget.controller;
    workspace = c.repository.workspaceId;
    report = VaultInsights(c.objects, c.objectConnections);
    dirty = c.dirty.length;
    failures = c.failures.length;
    warnings = c.repository.issues.length;
    readOnly = c.repository.readOnly;
    pdfPhases = {};
    for (final entry in c.pdfIndexEntries.values) {
      pdfPhases.update(entry.phase, (n) => n + 1, ifAbsent: () => 1);
    }
    page = 0;
    copied = false;
  }

  List<UniversalObject> get rows => switch (category) {
    'Isolated notes' => report.isolatedNotes,
    'Repeated titles' => report.duplicateGroups.expand((g) => g).toList(),
    'Missing sources' => report.missingSources.toSet().toList(),
    'Recent' => report.recent,
    _ => report.busiest,
  };
  @override
  Widget build(BuildContext context) {
    final entries = rows;
    final pages = (entries.length / 30).ceil().clamp(1, 1000000);
    return OrbitDialog(
      maxWidth: 840,
      title: const Text('Vault Insights'),
      contentSlivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Snapshot of the entire active Vault, including current drafts. Graph filters do not change these counts. Refresh to update.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  metric('Objects', report.active.length),
                  metric('Connected pairs', report.connectionPairs),
                  metric('Connected groups', report.components),
                  metric('References', report.referenceCount),
                  metric(
                    'Tasks done',
                    '${report.completedTasks} / ${report.tasks}',
                  ),
                  metric('Trash objects', report.trash),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Object types',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              for (final entry in report.types.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(entry.key.replaceFirst('orbit.', '')),
                      ),
                      Text('${entry.value}'),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 100,
                        child: LinearProgressIndicator(
                          value:
                              entry.value /
                              report.active.length.clamp(1, 100000000),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'Local diagnostics',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${readOnly ? "Read-only Vault" : "Writable Vault"} · $dirty unsaved objects · $failures save failures · $warnings repository warnings',
              ),
              Text(
                pdfPhases.isEmpty
                    ? 'No PDF index entries in this snapshot.'
                    : 'PDF index files: ${pdfPhases.entries.map((e) => "${e.key}: ${e.value}").join(" · ")}',
              ),
              const Text(
                'Counts describe current application state; they do not certify disk health, backups or sync. A connected group includes isolated objects. References count occurrences; connected pairs combine repeated links in either direction.',
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final label in [
                    'Connected',
                    'Isolated notes',
                    'Repeated titles',
                    'Missing sources',
                    'Recent',
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: category == label,
                      onSelected: (_) => setState(() {
                        category = label;
                        page = 0;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(switch (category) {
                'Isolated notes' =>
                  'Notes with no incoming or outgoing resolved object connections. They may be intentional.',
                'Repeated titles' =>
                  'Case-insensitive equal titles. Distinct objects are preserved; this does not imply duplicate content.',
                'Missing sources' =>
                  'Detected placements and metadata references to unavailable IDs. Open Connections to inspect or recover the source. Wiki mentions are checked inside Document Checks.',
                'Recent' =>
                  'Objects last updated within seven days. This is not an edit history or activity score.',
                _ =>
                  'Objects ranked by distinct active neighbors, combining incoming and outgoing references.',
              }),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No objects in this category.'),
                ),
            ],
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, i) {
            final object = entries[page * 30 + i];
            return ListTile(
              title: Text(object.title.isEmpty ? 'Untitled' : object.title),
              subtitle: Text(
                '${object.typeId.replaceFirst("orbit.", "")} · ${report.degree[object.id] ?? 0} neighbors · ${object.properties['folder'] ?? 'Vault'}',
              ),
              trailing: const Icon(Icons.arrow_forward, size: 18),
              onTap: () {
                final c = widget.controller;
                if (c.repository.workspaceId != workspace ||
                    c.find(object.id)?.isDeleted != false) {
                  setState(refresh);
                  return;
                }
                Navigator.pop(context);
                c.openReference(ObjectReference(object.id));
              },
            );
          }, childCount: (entries.length - page * 30).clamp(0, 30)),
        ),
        SliverToBoxAdapter(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              IconButton(
                tooltip: 'Previous insights page',
                onPressed: page > 0 ? () => setState(() => page--) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${entries.length} objects · Page ${page + 1} of $pages'),
              IconButton(
                tooltip: 'Next insights page',
                onPressed: page + 1 < pages
                    ? () => setState(() => page++)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ],
      actions: [
        TextButton(
          onPressed: () => setState(refresh),
          child: const Text('Refresh'),
        ),
        TextButton(
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(
                text: const JsonEncoder.withIndent('  ').convert({
                  ...report.aggregateReport(),
                  'unsavedObjects': dirty,
                  'saveFailures': failures,
                  'repositoryWarnings': warnings,
                  'readOnly': readOnly,
                  'pdfIndexPhases': pdfPhases,
                }),
              ),
            );
            if (mounted) setState(() => copied = true);
          },
          child: Text(copied ? 'Copied counts' : 'Copy diagnostic counts'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget metric(String label, Object value) => SizedBox(
    width: 180,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        Text(label),
      ],
    ),
  );
}
