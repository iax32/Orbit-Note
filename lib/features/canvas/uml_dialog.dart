import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/orbit_components.dart';
import '../../canvas/scene.dart';
import '../../canvas/uml.dart';

Future<Map<String, dynamic>?> showUmlEditor(
  BuildContext context,
  CanvasElement element,
  List<CanvasElement> classes, {
  bool creating = false,
}) => showDialog<Map<String, dynamic>>(
  context: context,
  builder: (_) =>
      _UmlDialog(element: element, classes: classes, creating: creating),
);

class _UmlDialog extends StatefulWidget {
  const _UmlDialog({
    required this.element,
    required this.classes,
    required this.creating,
  });
  final CanvasElement element;
  final List<CanvasElement> classes;
  final bool creating;
  @override
  State<_UmlDialog> createState() => _UmlDialogState();
}

class _UmlDialogState extends State<_UmlDialog> {
  bool get isClass => isUmlClass(widget.element);
  late final model = UmlClass(widget.element);
  late final name = TextEditingController(text: widget.element.text);
  late final stereotype = TextEditingController(text: model.stereotype);
  late final attributes = TextEditingController(
    text: model.attributes.join('\n'),
  );
  late final operations = TextEditingController(
    text: model.operations.join('\n'),
  );
  late final startMultiplicity = TextEditingController(
    text: _text('startMultiplicity'),
  );
  late final endMultiplicity = TextEditingController(
    text: _text('endMultiplicity'),
  );
  late final startRole = TextEditingController(text: _text('startRole'));
  late final endRole = TextEditingController(text: _text('endRole'));
  late bool abstractClass = model.abstractClass;
  late var relationship = UmlRelationship.parse(
    widget.element.data['umlRelationship'],
  );
  late String? from = widget.classes.any((e) => e.id == widget.element.startId)
      ? widget.element.startId
      : widget.classes.firstOrNull?.id;
  late String? to = widget.classes.any((e) => e.id == widget.element.endId)
      ? widget.element.endId
      : widget.classes.where((e) => e.id != from).firstOrNull?.id;
  late String startAnchor = widget.element.startAnchor;
  late String endAnchor = widget.element.endAnchor;
  double offset(String key) {
    final value = widget.element.data[key];
    return value is num && value.isFinite ? value.toDouble().clamp(0, 1) : .5;
  }

  late double fromOffset = offset('startAnchorOffset');
  late double toOffset = offset('endAnchorOffset');
  late double lane =
      widget.element.data['routingOffset'] is num &&
          (widget.element.data['routingOffset'] as num).isFinite
      ? (widget.element.data['routingOffset'] as num).toDouble().clamp(
          -120,
          120,
        )
      : 0;
  String? error;
  String _text(String key) => widget.element.data[key] is String
      ? widget.element.data[key] as String
      : '';
  @override
  void dispose() {
    for (final c in [
      name,
      stereotype,
      attributes,
      operations,
      startMultiplicity,
      endMultiplicity,
      startRole,
      endRole,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(
    String label,
    TextEditingController controller, {
    int lines = 1,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: controller,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 4,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: true,
      ),
    ),
  );
  Widget classPicker(
    String label,
    String? value,
    ValueChanged<String?> change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final e in widget.classes)
          DropdownMenuItem(
            value: e.id,
            child: Text(e.text, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) => setState(() => change(v)),
    ),
  );
  Widget anchorPicker(
    String label,
    String value,
    ValueChanged<String> change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<String>(
      initialValue: {'auto', 'left', 'right', 'top', 'bottom'}.contains(value)
          ? value
          : 'auto',
      decoration: InputDecoration(labelText: label),
      items: [
        for (final v in ['auto', 'left', 'right', 'top', 'bottom'])
          DropdownMenuItem(value: v, child: Text(v)),
      ],
      onChanged: (v) => setState(() => change(v!)),
    ),
  );
  void save() {
    try {
      Map<String, dynamic> patch;
      if (isClass) {
        patch = model.edit(
          name: name.text,
          stereotype: stereotype.text,
          attributes: attributes.text,
          operations: operations.text,
          abstractClass: abstractClass,
        );
        final updated = UmlClass(widget.element.copy(patch));
        // Grow to fit new members, preserving deliberate manual enlargement.
        patch['height'] = math.max(
          widget.element.height,
          updated.naturalHeight,
        );
        patch['width'] = math
            .max(widget.element.width, updated.naturalWidth.clamp(280, 800))
            .toDouble();
      } else {
        if (from == null || to == null || from == to) {
          throw const FormatException('Choose two different classes.');
        }
        if ([
          startMultiplicity.text,
          endMultiplicity.text,
          startRole.text,
          endRole.text,
          name.text,
        ].any((s) => s.length > 120)) {
          throw const FormatException(
            'Keep relationship labels under 120 characters.',
          );
        }
        patch = {
          ...relationship.style,
          'startId': from,
          'endId': to,
          'startAnchor': startAnchor,
          'endAnchor': endAnchor,
          'startAnchorOffset': fromOffset,
          'endAnchorOffset': toOffset,
          'routingOffset': lane,
          'text': name.text.trim(),
          'startMultiplicity': startMultiplicity.text.trim(),
          'endMultiplicity': endMultiplicity.text.trim(),
          'startRole': startRole.text.trim(),
          'endRole': endRole.text.trim(),
        };
      }
      Navigator.pop(context, patch);
    } on FormatException catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => OrbitDialog(
    title: Text(
      isClass
          ? (widget.creating ? 'New UML class' : 'Edit UML class')
          : 'UML relationship',
    ),
    content: SizedBox(
      width: 540,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isClass) ...[
              field('Class name', name),
              field(
                'Stereotype (optional)',
                stereotype,
                hint: 'interface, enumeration…',
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Abstract class'),
                value: abstractClass,
                onChanged: (v) => setState(() => abstractClass = v!),
              ),
              const SizedBox(height: 12),
              field(
                'Attributes · one per line',
                attributes,
                lines: 3,
                hint: '- name: String\n+ items: Item [0..*]',
              ),
              field(
                'Operations · one per line',
                operations,
                lines: 3,
                hint: '+ save(): bool\n+ find(id: int): Item',
              ),
              const Text(
                'Use + public, − private, # protected or ~ package visibility. Empty compartments are kept.',
              ),
            ] else ...[
              classPicker('From class', from, (v) => from = v),
              classPicker('To class', to, (v) => to = v),
              DropdownButtonFormField<UmlRelationship>(
                initialValue: relationship,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Relationship type',
                ),
                items: [
                  for (final r in UmlRelationship.values)
                    DropdownMenuItem(value: r, child: Text(r.label)),
                ],
                onChanged: (v) => setState(() => relationship = v!),
              ),
              const SizedBox(height: 12),
              Text(switch (relationship) {
                UmlRelationship.generalization || UmlRelationship.realization =>
                  'Triangle points to the parent class / interface (To).',
                UmlRelationship.aggregation || UmlRelationship.composition =>
                  'Diamond marks the whole / owner (From).',
                _ =>
                  'From and To identify each endpoint. Multiplicities describe how many instances may participate.',
              }),
              const SizedBox(height: 16),
              field('Relationship label (optional)', name),
              field(
                'From multiplicity',
                startMultiplicity,
                hint: '1, 0..1, 0..*, 1..*',
              ),
              field('From role (optional)', startRole),
              anchorPicker(
                'From attachment side',
                startAnchor,
                (v) => startAnchor = v,
              ),
              Text('From attachment position · ${(fromOffset * 100).round()}%'),
              Slider(
                value: fromOffset,
                divisions: 20,
                label: '${(fromOffset * 100).round()}%',
                semanticFormatterCallback: (v) =>
                    'From attachment position ${(v * 100).round()} percent',
                onChanged: (v) => setState(() => fromOffset = v),
              ),
              field('To multiplicity', endMultiplicity, hint: '0..*'),
              field('To role (optional)', endRole),
              anchorPicker(
                'To attachment side',
                endAnchor,
                (v) => endAnchor = v,
              ),
              Text('To attachment position · ${(toOffset * 100).round()}%'),
              Slider(
                value: toOffset,
                divisions: 20,
                label: '${(toOffset * 100).round()}%',
                semanticFormatterCallback: (v) =>
                    'To attachment position ${(v * 100).round()} percent',
                onChanged: (v) => setState(() => toOffset = v),
              ),
              Text('Routing lane · ${lane.round()}'),
              Slider(
                value: lane,
                min: -120,
                max: 120,
                divisions: 40,
                label: '${lane.round()}',
                semanticFormatterCallback: (v) => 'Routing lane ${v.round()}',
                onChanged: (v) => setState(() => lane = v),
              ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
        child: Text(widget.creating ? 'Add to canvas' : 'Save changes'),
      ),
    ],
  );
}
