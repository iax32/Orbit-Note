import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../../app/workspace_controller.dart';
import '../../domain/universal_object.dart';
import '../../domain/object_reference.dart';
import '../../app/orbit_components.dart';
import 'orbit_explorer_row.dart';

/// Real on-disk Notes folders. Objects keep their identity when their owner moves.
class NoteFolderExplorer extends StatelessWidget {
  Widget _drag(String path, String? noteId, Widget child) =>
      Draggable<({String path, String? noteId})>(
        data: (path: path, noteId: noteId),
        maxSimultaneousDrags: controller.repository.readOnly || path == 'Notes'
            ? 0
            : 1,
        feedback: Material(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Text(p.posix.basename(path)),
          ),
        ),
        child: child,
      );

  Widget _drop(String folder, Widget child) =>
      DragTarget<({String path, String? noteId})>(
        onWillAcceptWithDetails: (details) {
          final source = details.data;
          return !controller.repository.readOnly &&
              source.path != folder &&
              p.posix.dirname(source.path) != folder &&
              !folder.startsWith('${source.path}/');
        },
        onAcceptWithDetails: (details) => controller.organize(
          () => details.data.noteId == null
              ? controller.repository.moveFolder(
                  details.data.path,
                  '$folder/${p.posix.basename(details.data.path)}',
                )
              : controller.repository.moveNote(details.data.noteId!, folder),
        ),
        builder: (context, candidates, rejected) => ColoredBox(
          color: candidates.isEmpty
              ? Colors.transparent
              : Theme.of(context).colorScheme.primary.withValues(alpha: .12),
          child: child,
        ),
      );
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
      builder: (context) => OrbitDialog(
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
          child: _drop(
            folder,
            _drag(
              folder,
              null,
              OrbitExplorerRow(
                key: ValueKey('folder:$folder'),
                leading: Icon(
                  collapsed ? Icons.chevron_right : Icons.expand_more,
                  size: 16,
                ),
                onExpand: () => controller.updateSession(
                  (s) => s.collapsedFolders = s.collapsedFolders
                      .where((f) => f != folder)
                      .toList(),
                ),
                onCollapse: () => controller.updateSession(
                  (s) => s.collapsedFolders = {
                    ...s.collapsedFolders,
                    folder,
                  }.toList(),
                ),
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
                menu: PopupMenuButton<String>(
                  tooltip: 'Folder actions',
                  icon: const Icon(Icons.more_horiz, size: 16),
                  onSelected: (action) =>
                      _folderAction(context, folder, action),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      enabled: !repo.readOnly,
                      value: 'new',
                      child: const Text('New folder'),
                    ),
                    if (folder != 'Notes') ...[
                      PopupMenuItem(
                        enabled: !repo.readOnly,
                        value: 'rename',
                        child: const Text('Rename folder'),
                      ),
                      PopupMenuItem(
                        enabled: !repo.readOnly,
                        value: 'move',
                        child: const Text('Move folder…'),
                      ),
                    ],
                  ],
                ),
              ),
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
            child: _drag(
              repo.objectPath(note.id)!,
              note.id,
              OrbitExplorerRow(
                key: ValueKey('folder-note:${note.id}'),
                selected: controller.session.activeId == note.id,
                leading: const Icon(Icons.description_outlined, size: 16),
                title: Text(
                  note.title.isEmpty ? 'Untitled' : note.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () => controller.openObject(note.id),
                menu: PopupMenuButton<String>(
                  tooltip: 'Object actions',
                  icon: const Icon(Icons.more_horiz, size: 16),
                  onSelected: (action) async {
                    if (action == 'copy') {
                      await Clipboard.setData(
                        ClipboardData(
                          text: ObjectReference(note.id).markdown(note.title),
                        ),
                      );
                    }
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
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'split',
                      child: Text('Open beside'),
                    ),
                    const PopupMenuItem(
                      value: 'copy',
                      child: Text('Copy note reference'),
                    ),
                    PopupMenuItem(
                      enabled: !repo.readOnly && !note.isReadOnly,
                      value: 'move',
                      child: const Text('Move to folder…'),
                    ),
                    PopupMenuItem(
                      enabled: !repo.readOnly && !note.isReadOnly,
                      value: 'trash',
                      child: const Text('Move to Trash'),
                    ),
                  ],
                ),
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
