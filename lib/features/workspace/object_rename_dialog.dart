import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../app/workspace_controller.dart';
import '../../domain/universal_object.dart';
import '../../domain/backlinks.dart';

Future<void> showObjectRenameDialog(
  BuildContext context,
  WorkspaceController controller,
  UniversalObject object,
) {
  if (!identical(controller.find(object.id), object)) return Future.value();
  final generation = controller.workspaceGeneration;
  final origin = FocusManager.instance.primaryFocus;
  return showOrbitDialog<void>(
    context: context,
    builder: (_) => _ObjectRenameDialog(
      controller: controller,
      object: object,
      generation: generation,
    ),
  ).whenComplete(() {
    if (origin?.context != null) origin!.requestFocus();
  });
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
  late final references = findLinkedMentions(
    targetId: widget.object.id,
    objects: widget.controller.objects,
    targets: widget.controller.linkTargets,
  );
  late final otherNames = {
    for (final other in widget.controller.activeObjects)
      if (other.id != widget.object.id) other.title.toLowerCase(),
  };
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
          SelectableText(
            widget.controller.repository.objectPath(widget.object.id) ??
                widget.object.properties['folder'] as String? ??
                'Vault root',
          ),
          const SizedBox(height: 8),
          Text(
            '${references.length} incoming references · links keep their identity',
          ),
          for (final reference in references.take(5))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${reference.source.title} · ${widget.controller.repository.objectPath(reference.source.id) ?? 'Vault'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (references.length > 5)
            Text('And ${references.length - 5} more in Backlinks.'),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('object-rename-input'),
            controller: input,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => submit(),
          ),
          if (otherNames.contains(input.text.trim().toLowerCase()))
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Another item has this name. Use its folder to distinguish it.',
              ),
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
