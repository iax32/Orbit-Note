import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../app/workspace_controller.dart';
import '../../domain/universal_object.dart';
import '../workspace/object_bridges.dart';

Future<String?> showDiagramNoteDialog(
  BuildContext context,
  WorkspaceController controller,
  UniversalObject source,
  List<String> ids,
) => showDialog<String>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      _DiagramNoteDialog(controller: controller, source: source, ids: ids),
);

class _DiagramNoteDialog extends StatefulWidget {
  const _DiagramNoteDialog({
    required this.controller,
    required this.source,
    required this.ids,
  });
  final WorkspaceController controller;
  final UniversalObject source;
  final List<String> ids;
  @override
  State<_DiagramNoteDialog> createState() => _DiagramNoteDialogState();
}

class _DiagramNoteDialogState extends State<_DiagramNoteDialog> {
  late final title = TextEditingController(
    text: '${widget.source.title} · Diagram',
  );
  bool existing = false, busy = false;
  UniversalObject? target;
  String? error;
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (busy || (existing && target == null)) return;
    if (title.text.trim().isEmpty || title.text.length > 200) {
      setState(() => error = 'Enter a diagram title of up to 200 characters.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.controller.exportCanvasDiagramToNote(
        widget.source,
        widget.ids,
        expectedNote: existing ? target : null,
        title: title.text,
      );
      if (!mounted) return;
      if (result == null) {
        setState(
          () => error =
              'Could not save the diagram note. Check the Vault save status, or reopen this dialog if the source or destination changed. Your existing text is preserved.',
        );
      } else {
        Navigator.pop(context, result.id);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'The diagram could not be saved. Your source is unchanged. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: OrbitDialog(
      title: const Text('Export diagram to Markdown'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.ids.length} linked diagram items from ${widget.source.title}',
            ),
            const SizedBox(height: 16),
            const Text(
              'The note displays a live vector diagram. Changes in Canvas update it automatically. The source stays editable.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: title,
              enabled: !busy,
              decoration: const InputDecoration(labelText: 'Diagram title'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<bool>(
              initialValue: existing,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Destination'),
              items: const [
                DropdownMenuItem(
                  value: false,
                  child: Text('Create a new note'),
                ),
                DropdownMenuItem(
                  value: true,
                  child: Text('Add to an existing note'),
                ),
              ],
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                      existing = v!;
                      error = null;
                    }),
            ),
            if (existing) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final selected = await showObjectReferencePicker(
                          context,
                          widget.controller,
                          title: 'Choose a Markdown note',
                          types: {'orbit.note'},
                        );
                        if (!mounted || selected == null) return;
                        if (selected.isReadOnly ||
                            selected.properties['documentFormat'] == 'latex') {
                          setState(
                            () => error = 'Choose an editable Markdown note.',
                          );
                          return;
                        }
                        setState(() {
                          target = selected;
                          error = null;
                        });
                      },
                icon: const Icon(Icons.description_outlined),
                label: Text(target?.title ?? 'Choose note…'),
              ),
              const Text(
                'The diagram is added at the end. Existing text is retained.',
              ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Semantics(
                  liveRegion: true,
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
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy || (existing && target == null) ? null : send,
          child: Text(
            busy
                ? 'Saving…'
                : existing
                ? 'Add diagram'
                : 'Create note',
          ),
        ),
      ],
    ),
  );
}
