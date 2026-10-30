import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import '../../app/session_state.dart';
import '../../app/workspace_controller.dart';
import '../../domain/universal_object.dart';

/// Shows an interactive resolution dialog for an unresolved WikiLink (LNK-05).
Future<void> showUnresolvedLinkDialog(
  BuildContext context,
  String targetTitle, {
  WorkspaceController? controller,
}) async {
  WorkspaceController? c = controller;
  if (c == null) {
    try {
      c = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(workspaceProvider.notifier);
    } catch (_) {}
  }
  if (c == null) return;

  final referencingNotes = <UniversalObject>[];
  final unresolvedMap = c.unresolvedWikiLinks();
  final matchingRefs = unresolvedMap[targetTitle] ?? [];
  referencingNotes.addAll(matchingRefs);

  await showOrbitDialog<void>(
    context: context,
    builder: (dialogCtx) {
      final colors = OrbitColors.of(dialogCtx);
      return OrbitDialog(
        title: Row(
          children: [
            Icon(Icons.link_off_outlined, size: 20, color: colors.accent),
            const SizedBox(width: 8),
            Expanded(child: Text(targetTitle, overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This note does not exist yet.',
                style: TextStyle(fontSize: 13, color: colors.subtle),
              ),
              const SizedBox(height: 16),
              if (referencingNotes.isNotEmpty) ...[
                Text(
                  'MENTIONED IN (${referencingNotes.length})',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: colors.raised.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.5),
                    ),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: referencingNotes.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: colors.divider.withValues(alpha: 0.3),
                    ),
                    itemBuilder: (ctx, idx) {
                      final note = referencingNotes[idx];
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.description_outlined,
                          size: 16,
                        ),
                        title: Text(
                          note.title,
                          style: const TextStyle(fontSize: 13),
                        ),
                        onTap: () {
                          Navigator.pop(dialogCtx);
                          c?.openObject(note.id);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Creating this note will automatically resolve all existing [[$targetTitle]] links across your workspace.',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.subtle,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.search, size: 16),
            label: const Text('Search Similar'),
            onPressed: () {
              Navigator.pop(dialogCtx);
              c?.updateSession((s) {
                s.destination = OrbitDestination.search;
              });
            },
          ),
          FilledButton.icon(
            icon: const Icon(Icons.note_add_outlined, size: 16),
            label: const Text('Create Note'),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final newNote = await c?.create('orbit.note', title: targetTitle);
              if (newNote != null) {
                c?.openObject(newNote.id);
              }
            },
          ),
        ],
      );
    },
  );
}
