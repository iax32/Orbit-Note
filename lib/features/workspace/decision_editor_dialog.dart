import 'package:flutter/material.dart';
import '../../app/workspace_controller.dart';
import '../../domain/research_workspace.dart';
import '../../domain/universal_object.dart';

Future<List<String>?> pickResearchObjects(
  BuildContext context,
  WorkspaceController controller, {
  required String title,
  Iterable<String> selected = const [],
  bool Function(UniversalObject)? accepts,
  int maxSelection = 100,
}) => showDialog<List<String>>(
  context: context,
  builder: (_) => _ResearchPicker(
    controller: controller,
    title: title,
    selected: selected,
    accepts: accepts,
    maxSelection: maxSelection,
  ),
);

class _ResearchPicker extends StatefulWidget {
  const _ResearchPicker({
    required this.controller,
    required this.title,
    required this.selected,
    this.accepts,
    required this.maxSelection,
  });
  final WorkspaceController controller;
  final String title;
  final Iterable<String> selected;
  final bool Function(UniversalObject)? accepts;
  final int maxSelection;
  @override
  State<_ResearchPicker> createState() => _ResearchPickerState();
}

class _ResearchPickerState extends State<_ResearchPicker> {
  late final Set<String> selected = widget.selected.toSet();
  String query = '';
  @override
  Widget build(BuildContext context) {
    final results = widget.controller.activeObjects
        .where(
          (o) =>
              (widget.accepts?.call(o) ?? true) &&
              '${o.title} ${o.properties['projectName'] ?? ''}'
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        )
        .toList();
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 600,
        height: MediaQuery.sizeOf(context).height * .5,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Find sources'),
              onChanged: (s) => setState(() => query = s),
            ),
            Text(
              '${selected.length} selected · maximum ${widget.maxSelection}',
            ),
            Expanded(
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (_, i) {
                  final o = results[i];
                  return CheckboxListTile(
                    value: selected.contains(o.id),
                    title: Text(o.title),
                    subtitle: Text(o.typeId),
                    onChanged:
                        !selected.contains(o.id) &&
                            selected.length >= widget.maxSelection
                        ? null
                        : (value) => setState(() {
                            if (value == true) {
                              selected.add(o.id);
                            } else {
                              selected.remove(o.id);
                            }
                          }),
                  );
                },
              ),
            ),
            for (final id
                in selected
                    .where(
                      (id) =>
                          widget.controller.find(id) == null ||
                          widget.controller.find(id)!.isDeleted,
                    )
                    .take(5))
              TextButton(
                onPressed: () => setState(() => selected.remove(id)),
                child: Text('Remove missing link · $id'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, selected.toList()),
          child: const Text('Use selected'),
        ),
      ],
    );
  }
}

Future<UniversalObject?> showDecisionEditor(
  BuildContext context,
  WorkspaceController controller, {
  String kind = 'decision',
  UniversalObject? record,
  String? folder,
  String? project,
  List<String> evidence = const [],
}) => showDialog<UniversalObject>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _DecisionEditor(
    controller: controller,
    kind: kind,
    record: record,
    folder: folder,
    project: project,
    evidence: evidence,
  ),
);

class _DecisionEditor extends StatefulWidget {
  const _DecisionEditor({
    required this.controller,
    required this.kind,
    this.record,
    this.folder,
    this.project,
    required this.evidence,
  });
  final WorkspaceController controller;
  final String kind;
  final UniversalObject? record;
  final String? folder, project;
  final List<String> evidence;
  @override
  State<_DecisionEditor> createState() => _DecisionEditorState();
}

class _DecisionEditorState extends State<_DecisionEditor> {
  late final title = TextEditingController(text: widget.record?.title ?? '');
  late final body = TextEditingController(
    text:
        widget.record?.body ??
        (widget.kind == 'decision'
            ? '## Rationale\n\n\n## Alternatives considered\n\n\n## Tradeoffs and validation\n\n'
            : '## Why this matters\n\n\n## Verification plan\n\n\n## Findings\n\n'),
  );
  late String state =
      widget.record?.properties['researchState']?.toString() ??
      (widget.kind == 'decision' ? 'Proposed' : 'Unverified');
  late String confidence =
      widget.record?.properties['confidence']?.toString() ?? 'Unspecified';
  late String importance =
      widget.record?.properties['importance']?.toString() ?? 'Unspecified';
  late List<String> evidence = widget.record == null
      ? [...widget.evidence]
      : researchIds(widget.record!.properties['evidenceIds']);
  late List<String> assumptions = researchIds(
    widget.record?.properties['assumptionIds'],
  );
  late List<String> supersedes = researchIds(
    widget.record?.properties['supersedesIds'],
  );
  String? error;
  bool saving = false;
  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Widget choice(
    String label,
    String value,
    List<String> values,
    ValueChanged<String> change,
  ) => DropdownButtonFormField<String>(
    initialValue: values.contains(value) ? value : null,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [for (final s in values) DropdownMenuItem(value: s, child: Text(s))],
    onChanged: saving
        ? null
        : (s) {
            if (s != null) setState(() => change(s));
          },
  );
  Widget links(
    String label,
    List<String> ids,
    ValueChanged<List<String>> change, {
    String? kind,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton.icon(
        onPressed: saving
            ? null
            : () async {
                final result = await pickResearchObjects(
                  context,
                  widget.controller,
                  title: label,
                  selected: ids,
                  accepts: (o) =>
                      o.id != widget.record?.id &&
                      (kind == null || o.properties['researchKind'] == kind),
                );
                if (result != null && mounted) setState(() => change(result));
              },
        icon: const Icon(Icons.add_link),
        label: Text('$label · ${ids.length}'),
      ),
      Wrap(
        spacing: 6,
        children: [
          for (final id in ids)
            InputChip(
              label: Text(
                widget.controller.find(id)?.title ?? 'Missing source',
              ),
              onDeleted: saving
                  ? null
                  : () => setState(() => change([...ids]..remove(id))),
            ),
        ],
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: Text('${widget.record == null ? 'New' : 'Edit'} ${widget.kind}'),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: title,
                enabled: !saving,
                decoration: const InputDecoration(labelText: 'Statement'),
                maxLines: null,
              ),
              const SizedBox(height: 12),
              choice(
                'State',
                state,
                widget.kind == 'decision' ? decisionStates : assumptionStates,
                (s) => state = s,
              ),
              const SizedBox(height: 12),
              choice(
                widget.kind == 'decision' ? 'Confidence' : 'Importance',
                widget.kind == 'decision' ? confidence : importance,
                const ['Unspecified', 'Low', 'Medium', 'High'],
                (s) {
                  if (widget.kind == 'decision') {
                    confidence = s;
                  } else {
                    importance = s;
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: body,
                enabled: !saving,
                minLines: 6,
                maxLines: 14,
                decoration: const InputDecoration(
                  labelText: 'Reasoning and alternatives · Markdown',
                ),
              ),
              links('Supporting evidence', evidence, (v) => evidence = v),
              if (widget.kind == 'decision')
                links(
                  'Depends on assumptions',
                  assumptions,
                  (v) => assumptions = v,
                  kind: 'assumption',
                ),
              links(
                'Supersedes',
                supersedes,
                (v) => supersedes = v,
                kind: widget.kind,
              ),
              const Text(
                'Links retain source identity. Changes suggest review; they never rewrite your reasoning.',
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  setState(() {
                    saving = true;
                    error = null;
                  });
                  final result = await widget.controller.saveResearchRecord(
                    previous: widget.record,
                    kind: widget.kind,
                    title: title.text,
                    body: body.text,
                    state: state,
                    confidence: confidence,
                    importance: importance,
                    evidence: evidence,
                    assumptions: assumptions,
                    supersedes: supersedes,
                    folder: widget.folder,
                    project: widget.project,
                  );
                  if (!mounted || !context.mounted) return;
                  if (result != null) {
                    Navigator.pop(context, result);
                  } else {
                    setState(() {
                      saving = false;
                      error =
                          widget.controller.error ??
                          'Could not save this record.';
                    });
                  }
                },
          child: Text(saving ? 'Saving…' : 'Save record'),
        ),
      ],
    ),
  );
}
