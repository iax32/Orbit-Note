import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import 'note_templates.dart';

class CreativeBriefDialog extends StatefulWidget {
  const CreativeBriefDialog({super.key, this.projectWorkspace = false});
  final bool projectWorkspace;
  @override
  State<CreativeBriefDialog> createState() => _CreativeBriefDialogState();
}

class _CreativeBriefDialogState extends State<CreativeBriefDialog> {
  final fields = <String, TextEditingController>{
    for (final name in [
      'Project name',
      'Outcome',
      'Audience',
      'Constraints',
      'Deliverables',
      'References',
    ])
      name: TextEditingController(),
  };
  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OrbitDialog(
    title: const Text('Shape your project'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.projectWorkspace
                ? 'Create a connected brief, reference board, tasks and milestones. You can refine everything later.'
                : 'Start with what matters. These details become ordinary editable Markdown; you can refine everything later.',
          ),
          const SizedBox(height: 16),
          for (final entry in fields.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                key: ValueKey('brief-${entry.key}'),
                controller: entry.value,
                minLines: 1,
                maxLines: entry.key == 'Project name' ? 1 : 4,
                decoration: InputDecoration(
                  labelText: entry.key,
                  hintText: 'Optional',
                ),
              ),
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
        onPressed: () {
          String value(String name) => fields[name]!.text.trim();
          final title = value('Project name').isEmpty
              ? (widget.projectWorkspace
                    ? 'Creative Project'
                    : 'Creative Project Brief')
              : value('Project name');
          final heading = title.replaceAll(RegExp(r'[\r\n]+'), ' ');
          final details = StringBuffer('# $heading\n\n');
          for (final name in fields.keys.skip(1)) {
            if (value(name).isNotEmpty) {
              details.write('## $name\n${value(name)}\n\n');
            }
          }
          details.write(
            NoteTemplates.creativeBrief.body.substring(
              NoteTemplates.creativeBrief.body.indexOf(
                '## Deliverables & acceptance',
              ),
            ),
          );
          Navigator.pop(
            context,
            NoteTemplate(
              id: 'creative_brief',
              name: NoteTemplates.creativeBrief.name,
              description: NoteTemplates.creativeBrief.description,
              icon: NoteTemplates.creativeBrief.icon,
              defaultTitle: heading,
              body: details.toString(),
              tags: NoteTemplates.creativeBrief.tags,
            ),
          );
        },
        child: Text(
          widget.projectWorkspace ? 'Create project' : 'Create brief',
        ),
      ),
    ],
  );
}
