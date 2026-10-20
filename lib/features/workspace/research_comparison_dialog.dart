import 'package:flutter/material.dart';
import '../../app/workspace_controller.dart';
import '../../domain/research_comparison.dart';
import '../../domain/universal_object.dart';

Future<void> showResearchComparison(
  BuildContext context,
  WorkspaceController controller, {
  required bool Function(UniversalObject) matchesScope,
  required String folder,
  String target = '',
}) => showDialog<void>(
  context: context,
  builder: (_) => ResearchComparisonDialog(
    controller: controller,
    matchesScope: matchesScope,
    folder: folder,
    target: target,
  ),
);

class ResearchComparisonDialog extends StatefulWidget {
  const ResearchComparisonDialog({
    super.key,
    required this.controller,
    required this.matchesScope,
    required this.folder,
    this.target = '',
  });
  final WorkspaceController controller;
  final bool Function(UniversalObject) matchesScope;
  final String folder, target;
  @override
  State<ResearchComparisonDialog> createState() =>
      _ResearchComparisonDialogState();
}

class _ResearchComparisonDialogState extends State<ResearchComparisonDialog> {
  late final int generation;
  List<UniversalObject> records = [];
  List<ResearchBuild> builds = [];
  ResearchBuild? baseline, candidate;
  final search = TextEditingController();
  String query = '', filter = 'All', message = '';
  bool saving = false;
  int visible = 30;
  String? savedReport;
  final Map<String, String> tasks = {};
  String rowKey(ResearchComparisonRow row) =>
      row.sources.map((o) => o.id).join(',');
  @override
  void initState() {
    super.initState();
    generation = widget.controller.workspaceGeneration;
    refresh();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  bool get current => generation == widget.controller.workspaceGeneration;
  void refresh() {
    if (!current) return;
    records = widget.controller.activeObjects
        .where(
          (o) =>
              !o.isDeleted &&
              o.properties['category'] == 'Function' &&
              widget.matchesScope(o),
        )
        .toList();
    builds =
        records
            .map(ResearchBuild.of)
            .whereType<ResearchBuild>()
            .toSet()
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label));
    if (!builds.contains(baseline)) baseline = builds.firstOrNull;
    final choices = builds
        .where((b) => b.binaryId == baseline?.binaryId && b != baseline)
        .toList();
    if (!choices.contains(candidate)) candidate = choices.firstOrNull;
    tasks.clear();
    visible = 30;
    message = '';
    savedReport = null;
  }

  Future<void> save(
    ResearchBuildComparison comparison, [
    ResearchComparisonRow? row,
  ]) async {
    if (saving || !current) return;
    setState(() => saving = true);
    final result = row == null
        ? await widget.controller.saveResearchComparison(
            comparison,
            folder: widget.folder,
            target: widget.target,
          )
        : await widget.controller.createComparisonInvestigation(
            comparison,
            row,
            folder: widget.folder,
            target: widget.target,
          );
    if (!mounted) return;
    setState(() {
      saving = false;
      message = result == null
          ? widget.controller.error ?? 'Save failed; original records remain.'
          : row == null
          ? 'Comparison saved as a linked note.'
          : 'Investigation task created.';
      if (result != null) {
        if (row == null) {
          savedReport = result.id;
        } else {
          tasks[rowKey(row)] = result.id;
        }
      }
    });
  }

  void open(String id) {
    if (!current) return;
    Navigator.pop(context);
    widget.controller.openObject(id);
  }

  Widget source(UniversalObject o, String label) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        TextButton(onPressed: () => open(o.id), child: Text(o.title)),
        for (final key in [
          'moduleId',
          'addressSpace',
          'address',
          'rva',
          'moduleBase',
          'returnType',
          'parameters',
          'callingConvention',
          'purpose',
          'status',
          'confidence',
        ])
          if (o.properties[key]?.toString().isNotEmpty == true)
            SelectableText('$key: ${o.properties[key]}'),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    ResearchBuildComparison? comparison;
    String? issue;
    if (!current) {
      issue =
          'The Vault changed. Close this comparison and reopen it in the current project.';
    } else if (baseline == null || candidate == null) {
      issue =
          'Import or record two builds of the same binary with binaryId and binaryVersion. '
          'Unique module IDs and stable symbol names are required for pairing.';
    } else {
      try {
        comparison = ResearchBuildComparison(records, baseline!, candidate!);
      } on FormatException catch (e) {
        issue = e.message;
      }
    }
    final filtered =
        comparison?.rows
            .where(
              (r) =>
                  (filter == 'All' || r.state == filter) &&
                  '${r.symbol} ${r.module}'.toLowerCase().contains(
                    query.toLowerCase(),
                  ),
            )
            .toList() ??
        [];
    final excluded = records.where((o) => ResearchBuild.of(o) == null).length;
    final candidates = builds.where(
      (b) => b.binaryId == baseline?.binaryId && b != baseline,
    );
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .5,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Compare function maps',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: saving
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const Text(
                      'Compare recorded build knowledge. This does not inspect binaries or prove behaviour.',
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (_, size) => Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final isBaseline in [true, false])
                            SizedBox(
                              width: size.maxWidth < 550
                                  ? size.maxWidth
                                  : (size.maxWidth - 12) / 2,
                              child: DropdownButtonFormField<ResearchBuild>(
                                key: ValueKey(
                                  '${isBaseline ? 'baseline' : 'candidate'}-${isBaseline ? baseline?.key : candidate?.key}',
                                ),
                                initialValue: isBaseline ? baseline : candidate,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: isBaseline
                                      ? 'Baseline build'
                                      : 'Candidate build',
                                ),
                                items: [
                                  for (final b
                                      in isBaseline ? builds : candidates)
                                    DropdownMenuItem(
                                      value: b,
                                      child: Text(
                                        b.label,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: saving || !current
                                    ? null
                                    : (value) => setState(() {
                                        if (isBaseline) {
                                          baseline = value;
                                          candidate = builds
                                              .where(
                                                (b) =>
                                                    b.binaryId ==
                                                        baseline?.binaryId &&
                                                    b != baseline,
                                              )
                                              .firstOrNull;
                                        } else {
                                          candidate = value;
                                        }
                                        visible = 30;
                                        message = '';
                                        savedReport = null;
                                        tasks.clear();
                                      }),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (excluded > 0)
                      Text(
                        '$excluded records excluded: binary/build identity unrecorded.',
                      ),
                    if (issue != null) Text(issue),
                    if (comparison != null) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ChoiceChip(
                            label: const Text('All'),
                            selected: filter == 'All',
                            onSelected: (_) => setState(() {
                              filter = 'All';
                              visible = 30;
                            }),
                          ),
                          for (final state in ResearchBuildComparison.states)
                            ChoiceChip(
                              label: Text('$state ${comparison.counts[state]}'),
                              selected: filter == state,
                              onSelected: (_) => setState(() {
                                filter = state;
                                visible = 30;
                              }),
                            ),
                        ],
                      ),
                      TextField(
                        controller: search,
                        onChanged: (v) => setState(() {
                          query = v;
                          visible = 30;
                        }),
                        decoration: const InputDecoration(
                          labelText: 'Filter symbols or modules',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ],
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        TextButton(
                          onPressed: saving || !current
                              ? null
                              : () => setState(refresh),
                          child: const Text('Refresh comparison'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: saving || comparison == null
                              ? null
                              : () => save(comparison!),
                          icon: const Icon(Icons.note_add_outlined),
                          label: const Text('Save comparison note'),
                        ),
                        if (savedReport != null)
                          TextButton(
                            onPressed: () => open(savedReport!),
                            child: const Text('Open saved report'),
                          ),
                      ],
                    ),
                    if (message.isNotEmpty)
                      Semantics(liveRegion: true, child: Text(message)),
                  ],
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: comparison == null
                  ? const Center(
                      child: Text(
                        'Build context keeps research from different binaries separate.',
                      ),
                    )
                  : filtered.isEmpty
                  ? const Center(
                      child: Text('No recorded functions match these filters.'),
                    )
                  : ListView.builder(
                      itemCount:
                          filtered.take(visible).length +
                          (filtered.length > visible ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == visible) {
                          return TextButton(
                            onPressed: () => setState(() => visible += 30),
                            child: Text(
                              'Show more · ${filtered.length - visible} remaining',
                            ),
                          );
                        }
                        final row = filtered[i];
                        return Card(
                          elevation: 0,
                          child: ExpansionTile(
                            key: ValueKey('${row.module}-${row.symbol}-$i'),
                            title: Text(row.symbol),
                            subtitle: Text(
                              '${row.state} · ${row.module}\n${row.fields.join(', ')}',
                            ),
                            children: [
                              LayoutBuilder(
                                builder: (_, size) {
                                  final a = Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (final o in row.before)
                                        source(o, 'Baseline'),
                                    ],
                                  );
                                  final b = Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (final o in row.after)
                                        source(o, 'Candidate'),
                                    ],
                                  );
                                  return size.maxWidth <
                                          700 *
                                              MediaQuery.textScalerOf(
                                                context,
                                              ).scale(14) /
                                              14
                                      ? Column(children: [a, b])
                                      : Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(child: a),
                                            Expanded(child: b),
                                          ],
                                        );
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: TextButton.icon(
                                  onPressed: saving
                                      ? null
                                      : tasks.containsKey(rowKey(row))
                                      ? () => open(tasks[rowKey(row)]!)
                                      : () => save(comparison!, row),
                                  icon: Icon(
                                    tasks.containsKey(rowKey(row))
                                        ? Icons.open_in_new
                                        : Icons.add_task,
                                  ),
                                  label: Text(
                                    tasks.containsKey(rowKey(row))
                                        ? 'Open investigation task'
                                        : 'Create investigation task',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
