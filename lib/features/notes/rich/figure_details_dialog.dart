import 'package:flutter/material.dart';
import '../../../app/orbit_components.dart';
import '../../../domain/wiki_links.dart';
import '../note_link_dialog.dart';
import 'figure_details.dart';

Future<FigureDetails?> showFigureDetails(
  BuildContext context,
  FigureDetails? initial,
  List<NoteLinkTarget> targets,
) => showDialog<FigureDetails>(
  context: context,
  builder: (_) => _FigureDialog(initial: initial, targets: targets),
);

class _FigureDialog extends StatefulWidget {
  const _FigureDialog({this.initial, required this.targets});
  final FigureDetails? initial;
  final List<NoteLinkTarget> targets;
  @override
  State<_FigureDialog> createState() => _FigureDialogState();
}

class _FigureDialogState extends State<_FigureDialog> {
  late final caption = TextEditingController(
    text: widget.initial?.caption ?? '',
  );
  final rows = <({TextEditingController label, TextEditingController url})>[];
  final controllers = <TextEditingController>[];
  String? error;
  @override
  void initState() {
    super.initState();
    for (final item in widget.initial?.citations ?? <FigureCitation>[]) {
      add(item.label, item.destination);
    }
  }

  void add([String label = '', String destination = '']) {
    final a = TextEditingController(text: label),
        b = TextEditingController(text: destination);
    controllers.addAll([a, b]);
    rows.add((label: a, url: b));
  }

  @override
  void dispose() {
    caption.dispose();
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OrbitDialog(
    title: const Text('Figure caption and sources'),
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: caption,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: 'Figure caption',
            hintText: 'Describe what the image shows',
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Sources remain ordinary Markdown links. Nothing is fetched or uploaded.',
        ),
        for (var i = 0; i < rows.length; i++)
          Padding(
            key: ObjectKey(rows[i].label),
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: rows[i].label,
                  decoration: InputDecoration(
                    labelText: 'Source ${i + 1} label',
                  ),
                ),
                TextField(
                  controller: rows[i].url,
                  decoration: const InputDecoration(
                    labelText: 'Source address',
                    hintText: 'https://… or Attachments/file.pdf',
                  ),
                  keyboardType: TextInputType.url,
                ),
                Wrap(
                  children: [
                    TextButton.icon(
                      onPressed: widget.targets.isEmpty
                          ? null
                          : () async {
                              final row = rows[i];
                              final target = await showNoteLinkDialog(
                                context,
                                widget.targets,
                              );
                              if (target != null &&
                                  mounted &&
                                  rows.contains(row)) {
                                setState(() {
                                  row.label.text = target.title;
                                  row.url.text = 'orbit-object:${target.id}';
                                });
                              }
                            },
                      icon: const Icon(Icons.link),
                      label: const Text('Link a note'),
                    ),
                    IconButton(
                      tooltip: 'Move source up',
                      onPressed: i == 0
                          ? null
                          : () => setState(() {
                              final row = rows.removeAt(i);
                              rows.insert(i - 1, row);
                            }),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: 'Remove source ${i + 1}',
                      onPressed: () => setState(() => rows.removeAt(i)),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: rows.length >= 20 ? null : () => setState(() => add()),
          icon: const Icon(Icons.add),
          label: const Text('Add source'),
        ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          try {
            final value = FigureDetails(caption.text.trim(), [
              for (final row in rows)
                FigureCitation(row.label.text.trim(), row.url.text.trim()),
            ]);
            value.validate();
            Navigator.pop(context, value);
          } on FormatException catch (e) {
            setState(() => error = e.message);
          }
        },
        child: const Text('Apply'),
      ),
    ],
  );
}
