import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../canvas/reference_capture.dart';
import '../../canvas/scene.dart';
import '../../app/retained_form.dart';
import '../../app/orbit_draft_guard.dart';
import '../../domain/json_values.dart';

Future<Map<String, dynamic>?> showReferenceDetails(
  BuildContext context,
  CanvasElement element,
  String sourceTitle, {
  String? ownerId,
}) => showOrbitDialog<Map<String, dynamic>>(
  context: context,
  builder: (_) => _ReferenceDetailsDialog(
    element: element,
    sourceTitle: sourceTitle,
    draft: ownerId == null
        ? null
        : RetainedForm.capture(
            context,
            'reference:$ownerId:${element.id}',
            element.data,
          ),
  ),
);

class _ReferenceDetailsDialog extends StatefulWidget {
  const _ReferenceDetailsDialog({
    required this.element,
    required this.sourceTitle,
    this.draft,
  });
  final CanvasElement element;
  final String sourceTitle;
  final RetainedForm? draft;
  @override
  State<_ReferenceDetailsDialog> createState() =>
      _ReferenceDetailsDialogState();
}

class _ReferenceDetailsDialogState extends State<_ReferenceDetailsDialog> {
  late final caption = TextEditingController(text: _text('referenceCaption'));
  late final source = TextEditingController(text: _text('referenceSourceUrl'));
  late final tags = TextEditingController(
    text: widget.element.data['referenceTags'] is List
        ? (widget.element.data['referenceTags'] as List)
              .whereType<String>()
              .join(', ')
        : '',
  );
  late String status =
      referenceStates.contains(widget.element.data['referenceStatus'])
      ? widget.element.data['referenceStatus'] as String
      : 'Inbox';
  String? error;
  late final Map<String, dynamic> initial;
  bool get dirty => recovered || !jsonValuesEqual(values, initial);
  Map<String, dynamic> get values => {
    'caption': caption.text,
    'source': source.text,
    'tags': tags.text,
    'status': status,
  };
  bool recovered = false;
  @override
  void initState() {
    super.initState();
    initial = values;
    final saved = widget.draft?.recovered;
    if (saved != null) {
      caption.text = saved['caption'] is String
          ? saved['caption'] as String
          : caption.text;
      source.text = saved['source'] is String
          ? saved['source'] as String
          : source.text;
      tags.text = saved['tags'] is String ? saved['tags'] as String : tags.text;
      if (referenceStates.contains(saved['status'])) {
        status = saved['status'] as String;
      }
      recovered = true;
    }
    for (final c in [caption, source, tags]) {
      c.addListener(_changed);
    }
  }

  void _changed() => setState(() {});
  String _text(String key) => widget.element.data[key] is String
      ? widget.element.data[key] as String
      : '';
  @override
  void dispose() {
    caption.dispose();
    source.dispose();
    tags.dispose();
    super.dispose();
  }

  void save() {
    try {
      Navigator.pop(
        context,
        referenceDetails(
          caption: caption.text,
          sourceUrl: source.text,
          tags: tags.text,
          status: status,
        ),
      );
    } on FormatException catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => OrbitDraftGuard(
    dirty: dirty,
    hasChanges: () => dirty,
    onKeepDraft: widget.draft == null ? null : () => widget.draft!.keep(values),
    onDiscardDraft: recovered ? widget.draft!.discard : null,
    builder: (context, requestClose) => OrbitDialog(
      title: const Text('Reference details'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recovered) widget.draft!.notice(),
            Text(
              widget.sourceTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Describe why this reference matters. These details belong to this card; the original stays unchanged.',
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('reference-caption'),
              controller: caption,
              maxLength: 4000,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Caption / why it matters',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('reference-source'),
              controller: source,
              maxLength: 2048,
              decoration: InputDecoration(
                labelText: 'Source URL (optional)',
                errorText: error,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('reference-tags'),
              controller: tags,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Tags, separated by commas',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: status,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Review state'),
              items: [
                for (final s in referenceStates)
                  DropdownMenuItem(value: s, child: Text(s)),
              ],
              onChanged: (v) => setState(() => status = v ?? status),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: requestClose, child: const Text('Cancel')),
        FilledButton(onPressed: save, child: const Text('Save details')),
      ],
    ),
  );
}
