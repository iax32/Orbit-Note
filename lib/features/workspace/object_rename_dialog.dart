import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../app/workspace_controller.dart';
import '../../domain/universal_object.dart';

Future<void> showObjectRenameDialog(
  BuildContext context,
  WorkspaceController controller,
  UniversalObject object,
) {
  if (!identical(controller.find(object.id), object)) return Future.value();
  final generation = controller.workspaceGeneration;
  return showDialog<void>(
    context: context,
    builder: (_) => _ObjectRenameDialog(
      controller: controller,
      object: object,
      generation: generation,
    ),
  );
}

class _ObjectRenameDialog extends StatefulWidget {
  const _ObjectRenameDialog({
    required this.controller,
    required this.object,
    required this.generation,
  });
  final WorkspaceController controller;
  final UniversalObject object;
  final int generation;
  @override
  State<_ObjectRenameDialog> createState() => _ObjectRenameDialogState();
}

class _ObjectRenameDialogState extends State<_ObjectRenameDialog> {
  late final input = TextEditingController(text: widget.object.title);
  String? issue;
  bool submitted = false;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void submit() {
    if (!mounted || submitted) return;
    final name = input.text.trim();
    if (name.isEmpty) {
      setState(() => issue = 'Enter a name.');
      return;
    }
    final c = widget.controller;
    if (!c.editObjectMetadata(
      widget.object,
      generation: widget.generation,
      title: name,
    )) {
      setState(
        () => issue = widget.generation == c.workspaceGeneration
            ? c.error ?? 'Could not rename this item.'
            : 'The Vault changed. Close this dialog and reopen Rename.',
      );
      return;
    }
    submitted = true;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => OrbitDialog(
    title: const Text('Rename object'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('object-rename-input'),
            controller: input,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
            onSubmitted: (_) => submit(),
          ),
          if (issue != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                issue!,
                key: const ValueKey('object-rename-issue'),
                semanticsLabel: issue,
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
      FilledButton(onPressed: submit, child: const Text('Rename')),
    ],
  );
}
