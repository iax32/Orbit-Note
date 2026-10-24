import 'package:flutter/material.dart';

import '../../app/orbit_components.dart';
import '../../canvas/scene.dart';
import '../../canvas/uml_interaction.dart';

Future<Map<String, dynamic>?> showInteractionEditor(
  BuildContext context,
  CanvasElement element,
  List<CanvasElement> nodes, {
  bool sequence = false,
  bool creating = false,
}) => showDialog<Map<String, dynamic>>(
  context: context,
  builder: (_) => _InteractionDialog(
    element: element,
    nodes: nodes,
    sequence: sequence,
    creating: creating,
  ),
);

class _InteractionDialog extends StatefulWidget {
  const _InteractionDialog({
    required this.element,
    required this.nodes,
    required this.sequence,
    required this.creating,
  });
  final CanvasElement element;
  final List<CanvasElement> nodes;
  final bool sequence, creating;
  @override
  State<_InteractionDialog> createState() => _InteractionDialogState();
}

class _InteractionDialogState extends State<_InteractionDialog> {
  String text(Object? value) => value is String ? value : '';
  late final node = umlNodeKind(widget.element);
  late final details = umlNodeDetails(widget.element);
  late final Map link = widget.element.data['umlLink'] is Map
      ? widget.element.data['umlLink'] as Map
      : const {};
  late var relationship =
      umlLinkKind(widget.element) ??
      (widget.sequence ? UmlLinkKind.synchronous : UmlLinkKind.association);
  late final name = TextEditingController(
    text: node != null
        ? widget.element.text
        : link['label'] is String
        ? link['label'] as String
        : widget.element.text,
  );
  late final stereotype = TextEditingController(
    text: text(details['stereotype']),
  );
  late final lines = TextEditingController(
    text: umlNodeLines(widget.element).join('\n'),
  );
  late final detail = TextEditingController(text: text(link['detail']));
  late final start = TextEditingController(
    text: text(widget.element.data['startMultiplicity']),
  );
  late final end = TextEditingController(
    text: text(widget.element.data['endMultiplicity']),
  );
  late var operator = umlFragmentOperators.contains(details['operator'])
      ? details['operator'] as String
      : 'alt';
  late bool destroyed = details['destroyed'] == true;
  List<CanvasElement> get choices => widget.nodes
      .where(
        (e) => switch (relationship) {
          UmlLinkKind.include ||
          UmlLinkKind.extend => umlNodeKind(e) == UmlNodeKind.useCase,
          UmlLinkKind.association || UmlLinkKind.generalization => [
            UmlNodeKind.actor,
            UmlNodeKind.useCase,
          ].contains(umlNodeKind(e)),
          UmlLinkKind.constraint => true,
          _ => umlNodeKind(e) == UmlNodeKind.lifeline,
        },
      )
      .toList();
  late String? from = choices.any((e) => e.id == widget.element.startId)
      ? widget.element.startId
      : choices.firstOrNull?.id;
  late String? to = choices.any((e) => e.id == widget.element.endId)
      ? widget.element.endId
      : choices.where((e) => e.id != from).firstOrNull?.id ??
            (widget.sequence ? from : null);
  late double position =
      link['position'] is num && (link['position'] as num).isFinite
      ? (link['position'] as num).toDouble().clamp(.12, .9)
      : .3;
  String? error;
  @override
  void dispose() {
    for (final c in [name, stereotype, lines, detail, start, end]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(
    String label,
    TextEditingController controller, {
    int count = 1,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: controller,
      minLines: count,
      maxLines: count == 1 ? 1 : count + 5,
      maxLength: count == 1 ? 160 : 2400,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: true,
      ),
    ),
  );

  Widget picker(
    String label,
    String? value,
    ValueChanged<String?> changed,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final e in choices)
          DropdownMenuItem(
            value: e.id,
            child: Text(
              '${e.text.isEmpty ? umlNodeKind(e)?.label : e.text} · ${umlNodeKind(e)?.label}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (v) => setState(() => changed(v)),
    ),
  );

  void save() {
    try {
      if (node == null && (from == null || to == null)) {
        throw const FormatException(
          'Add and choose the required endpoints first.',
        );
      }
      final patch = node != null
          ? editInteractionNode(
              widget.element,
              name: name.text,
              stereotype: stereotype.text,
              lines: lines.text,
              operator: operator,
              destroyed: destroyed,
            )
          : editInteractionLink(
              widget.element,
              widget.nodes,
              kind: relationship,
              from: from!,
              to: to!,
              label: name.text,
              detail: detail.text,
              fromMultiplicity: start.text,
              toMultiplicity: end.text,
              position: position,
            );
      Navigator.pop(context, patch);
    } on FormatException catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => OrbitDialog(
    title: Text(
      node == null
          ? (widget.sequence ? 'Sequence message' : 'Use-case relationship')
          : '${widget.creating ? 'New' : 'Edit'} ${node!.label.toLowerCase()}',
    ),
    content: SizedBox(
      width: 540,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (node != null) ...[
              if (node != UmlNodeKind.activation)
                field(
                  node == UmlNodeKind.note ? 'Note or constraint' : 'Name',
                  name,
                  count: node == UmlNodeKind.note ? 4 : 2,
                ),
              if ([
                UmlNodeKind.actor,
                UmlNodeKind.useCase,
                UmlNodeKind.lifeline,
              ].contains(node))
                field(
                  'Stereotype (optional)',
                  stereotype,
                  hint: 'external system, interface…',
                ),
              if (node == UmlNodeKind.useCase)
                field(
                  'Extension points · one per line',
                  lines,
                  count: 3,
                  hint: 'after validation\nbefore confirmation',
                ),
              if (node == UmlNodeKind.lifeline)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Destruction marker at end of lifeline'),
                  value: destroyed,
                  onChanged: (v) => setState(() => destroyed = v!),
                ),
              if (node == UmlNodeKind.fragment) ...[
                DropdownButtonFormField<String>(
                  initialValue: operator,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Interaction operator',
                  ),
                  items: [
                    for (final op in umlFragmentOperators)
                      DropdownMenuItem(value: op, child: Text(op)),
                  ],
                  onChanged: (v) => setState(() => operator = v!),
                ),
                const SizedBox(height: 16),
                field(
                  'Operand guards · one per region',
                  lines,
                  count: 4,
                  hint: '[condition]\n[else]',
                ),
                const Text(
                  'Regions are separated by dashed lines. Resize and layer the frame to enclose messages; nested frames stay editable.',
                ),
              ],
              if (node == UmlNodeKind.activation)
                const Text(
                  'Place this execution bar over a lifeline. Resize its duration with the normal Canvas handles. Group it with the lifeline to move them together.',
                ),
              if (node == UmlNodeKind.system)
                const Text(
                  'Place use cases inside and actors outside. The boundary is a visual frame, not an automatic container.',
                ),
            ] else ...[
              DropdownButtonFormField<UmlLinkKind>(
                initialValue: relationship,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Relationship type',
                ),
                items: [
                  for (final r in UmlLinkKind.values.where(
                    (r) => r.sequence == widget.sequence,
                  ))
                    DropdownMenuItem(value: r, child: Text(r.label)),
                ],
                onChanged: (v) => setState(() {
                  relationship = v!;
                  if (!choices.any((e) => e.id == from)) {
                    from = choices.firstOrNull?.id;
                  }
                  if (!choices.any((e) => e.id == to)) {
                    to = choices.where((e) => e.id != from).firstOrNull?.id;
                  }
                  error = null;
                }),
              ),
              const SizedBox(height: 12),
              Text(relationship.guidance),
              const SizedBox(height: 16),
              picker('From / sender', from, (v) => from = v),
              picker('To / receiver', to, (v) => to = v),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    final old = from;
                    from = to;
                    to = old;
                  }),
                  icon: const Icon(Icons.swap_vert),
                  label: const Text('Swap direction'),
                ),
              ),
              if ([
                UmlLinkKind.include,
                UmlLinkKind.extend,
              ].contains(relationship))
                field(
                  'Guard / extension point (optional)',
                  detail,
                  hint: '[condition] at extension point',
                )
              else
                field(
                  'Message or label (optional)',
                  name,
                  hint: widget.sequence ? '1: request(value)' : null,
                ),
              if (relationship == UmlLinkKind.association) ...[
                field(
                  'From multiplicity (optional)',
                  start,
                  hint: '1, 2, 0..*, 1..*',
                ),
                field(
                  'To multiplicity (optional)',
                  end,
                  hint: '1, 2, 0..*, 1..*',
                ),
              ],
              if (widget.sequence) ...[
                Text(
                  'Message position · ${(position * 100).round()}% of lifeline',
                ),
                Slider(
                  value: position,
                  min: .12,
                  max: .9,
                  divisions: 78,
                  label: '${(position * 100).round()}%',
                  semanticFormatterCallback: (v) =>
                      '${(v * 100).round()} percent of lifeline',
                  onChanged: (v) => setState(() => position = v),
                ),
              ],
            ],
            if (error != null)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
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
        onPressed: save,
        child: Text(widget.creating ? 'Add to Canvas' : 'Apply'),
      ),
    ],
  );
}
