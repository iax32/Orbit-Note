import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/workspace_controller.dart';

Future<void> showEditorDraftReview(
  BuildContext context,
  WorkspaceController c,
) => showDialog<void>(
  context: context,
  builder: (_) => _DraftReview(controller: c),
);

class _DraftReview extends ConsumerStatefulWidget {
  const _DraftReview({required this.controller});
  final WorkspaceController controller;
  @override
  ConsumerState<_DraftReview> createState() => _DraftReviewState();
}

class _DraftReviewState extends ConsumerState<_DraftReview> {
  final _busy = <String>{};
  String? _error;
  @override
  Widget build(BuildContext context) {
    ref.watch(workspaceProvider);
    final c = widget.controller;
    return AlertDialog(
      title: const Text('Conflicting editor drafts'),
      content: SizedBox(
        width: 760,
        height: 440,
        child: ListView(
          children: [
            const Text(
              'The shared note was kept. These drafts remain in this session until you save a separate copy or discard them. Resolve them before closing or switching Vaults.',
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (c.editorDraftConflicts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('All drafts resolved.'),
              ),
            for (final entry in c.editorDraftConflicts.entries.toList())
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        entry.value.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      ExpansionTile(
                        title: const Text(
                          'Compare shared note and retained draft',
                        ),
                        children: [
                          const Text('Shared note'),
                          SelectableText(
                            entry.value.typeId == 'orbit.canvas'
                                ? jsonEncode(
                                    c.find(entry.value.objectId)?.data ?? {},
                                  )
                                : c.find(entry.value.objectId)?.body ??
                                      'Source removed',
                          ),
                          const Divider(),
                          const Text('Retained draft'),
                          SelectableText(
                            entry.value.typeId == 'orbit.canvas'
                                ? jsonEncode(entry.value.data)
                                : entry.value.body,
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton(
                            onPressed: _busy.contains(entry.key)
                                ? null
                                : () async {
                                    setState(() => _busy.add(entry.key));
                                    final copy = await c.recoverEditorDraft(
                                      entry.key,
                                    );
                                    if (!mounted) return;
                                    setState(() {
                                      _busy.remove(entry.key);
                                      _error = copy == null
                                          ? c.error ??
                                                'Could not save the draft. It is still retained.'
                                          : null;
                                    });
                                  },
                            child: const Text('Save as separate object'),
                          ),
                          TextButton(
                            onPressed: _busy.contains(entry.key)
                                ? null
                                : () => c.discardEditorDraft(entry.key),
                            child: const Text('Discard retained draft'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
