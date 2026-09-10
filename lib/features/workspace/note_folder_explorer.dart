import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../app/workspace_controller.dart';
import '../../domain/universal_object.dart';

/// Real on-disk Notes folders. Objects keep their identity when their owner moves.
class NoteFolderExplorer extends StatelessWidget {
  const NoteFolderExplorer({
    super.key,
    required this.controller,
    required this.notes,
    this.filtering = false,
  });
  final WorkspaceController controller;
  final List<UniversalObject> notes;
  final bool filtering;

  Future<String?> _name(
    BuildContext context,
    String title, {
    String initial = '',
  }) async {
    final input = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Folder name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (input.text.trim().isNotEmpty) {
                Navigator.pop(context, input.text.trim());
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    input.dispose();
    return result;
  }

  Future<String?> _destination(BuildContext context, {String? exclude}) =>
      showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Move to folder'),
          children: [
            for (final folder in controller.repository.folders)
              if (folder != exclude &&
                  !(exclude != null && folder.startsWith('$exclude/')))
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, folder),
                  child: Text(folder),
                ),
          ],
        ),
      );

  Future<void> _folderAction(
    BuildContext context,
    String folder,
    String action,
  ) async {
    if (action == 'new') {
      final name = await _name(context, 'New folder');
      if (name != null) {
        await controller.organize(
          () => controller.repository.createFolder('$folder/$name'),
        );
      }
    } else if (action == 'rename') {
      final name = await _name(
        context,
        'Rename folder',
        initial: p.posix.basename(folder),
      );
      if (name != null && name != p.posix.basename(folder)) {
        await controller.organize(
          () => controller.repository.moveFolder(
            folder,
            '${p.posix.dirname(folder)}/$name',
          ),
        );
      }
    } else {
      final parent = await _destination(context, exclude: folder);
      if (parent != null && parent != p.posix.dirname(folder)) {
        await controller.organize(
          () => controller.repository.moveFolder(
            folder,
            '$parent/${p.posix.basename(folder)}',
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = controller.repository;
    final rows = <Widget>[];
    void visit(String folder, int depth) {
      final collapsed =
          !filtering && controller.session.collapsedFolders.contains(folder);
      rows.add(
        Padding(
          padding: EdgeInsets.only(left: depth * 12.0),
          child: ListTile(
            key: ValueKey('folder:$folder'),
            dense: true,
            leading: Icon(
              collapsed ? Icons.chevron_right : Icons.expand_more,
              size: 16,
            ),
            minLeadingWidth: 12,
            title: Text(
              p.posix.basename(folder),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            onTap: () => controller.updateSession(
              (s) => s.collapsedFolders = collapsed
                  ? s.collapsedFolders.where((f) => f != folder).toList()
                  : {...s.collapsedFolders, folder}.toList(),
            ),
            trailing: PopupMenuButton<String>(
              tooltip: 'Folder actions',
              icon: const Icon(Icons.more_horiz, size: 16),
              onSelected: (action) => _folderAction(context, folder, action),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'new', child: Text('New folder')),
                if (folder != 'Notes') ...[
                  const PopupMenuItem(
                    value: 'rename',
                    child: Text('Rename folder'),
                  ),
                  const PopupMenuItem(
                    value: 'move',
                    child: Text('Move folder…'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
      if (collapsed) return;
      for (final child in repo.folders.where(
        (f) => f != folder && p.posix.dirname(f) == folder,
      )) {
        visit(child, depth + 1);
      }
      for (final note in notes.where(
        (o) => p.posix.dirname(repo.objectPath(o.id) ?? '') == folder,
      )) {
        rows.add(
          Padding(
            padding: EdgeInsets.only(left: (depth + 1) * 12.0),
            child: ListTile(
              key: ValueKey('folder-note:${note.id}'),
              dense: true,
              selected: controller.session.activeId == note.id,
              leading: const Icon(Icons.description_outlined, size: 16),
              minLeadingWidth: 12,
              title: Text(
                note.title.isEmpty ? 'Untitled' : note.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () => controller.openObject(note.id),
              trailing: PopupMenuButton<String>(
                tooltip: 'Object actions',
                icon: const Icon(Icons.more_horiz, size: 16),
                onSelected: (action) async {
                  if (action == 'split') {
                    controller.openObject(note.id, secondary: true);
                  }
                  if (action == 'trash') await controller.trash(note.id);
                  if (action == 'move') {
                    if (!context.mounted) return;
                    final target = await _destination(context);
                    if (target != null && target != folder) {
                      await controller.organize(
                        () => repo.moveNote(note.id, target),
                      );
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'split', child: Text('Open beside')),
                  PopupMenuItem(value: 'move', child: Text('Move to folder…')),
                  PopupMenuItem(value: 'trash', child: Text('Move to Trash')),
                ],
              ),
            ),
          ),
        );
      }
    }

    visit('Notes', 0);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      children: rows,
    );
  }
}
