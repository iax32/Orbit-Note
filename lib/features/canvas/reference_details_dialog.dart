import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../canvas/reference_capture.dart';
import '../../canvas/scene.dart';

Future<Map<String, dynamic>?> showReferenceDetails(
  BuildContext context,
  CanvasElement element,
  String sourceTitle,
) => showDialog<Map<String, dynamic>>(
  context: context,
  builder: (_) =>
      _ReferenceDetailsDialog(element: element, sourceTitle: sourceTitle),
);

class _ReferenceDetailsDialog extends StatefulWidget {
  const _ReferenceDetailsDialog({
    required this.element,
    required this.sourceTitle,
  });
  final CanvasElement element;
  final String sourceTitle;
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
  Widget build(BuildContext context) => OrbitDialog(
    title: const Text('Reference details'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            onChanged: (v) => status = v ?? status,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: save, child: const Text('Save details')),
    ],
  );
}
