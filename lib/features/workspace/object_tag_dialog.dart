import 'package:flutter/material.dart';
import '../../app/workspace_controller.dart';

Future<void> showObjectTagDialog(
  BuildContext context,
  WorkspaceController c,
) async {
  final object = c.find(c.session.activeId);
  if (object == null || object.isDeleted || object.isReadOnly) return;
  final generation = c.workspaceGeneration;
  final tag = await showDialog<String>(
    context: context,
    builder: (_) => const _TagDialog(),
  );
  if (tag != null) {
    await c.addTagToObject(object.id, tag, expectedGeneration: generation);
  }
}

class _TagDialog extends StatefulWidget {
  const _TagDialog();
  @override
  State<_TagDialog> createState() => _TagDialogState();
}

class _TagDialogState extends State<_TagDialog> {
  final text = TextEditingController();
  bool submitted = false;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  void submit() {
    if (mounted &&
        !submitted &&
        text.text.trim().replaceFirst(RegExp(r'^#'), '').isNotEmpty) {
      submitted = true;
      Navigator.pop(context, text.text);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add Tag'),
    content: TextField(
      controller: text,
      autofocus: true,
      onSubmitted: (_) => submit(),
      decoration: const InputDecoration(
        hintText: 'e.g. research, ideas, draft',
        prefixText: '#',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: submit, child: const Text('Add')),
    ],
  );
}
