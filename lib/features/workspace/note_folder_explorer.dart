import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../../app/workspace_controller.dart';
import '../../domain/universal_object.dart';
import '../../domain/object_reference.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import '../../platform/open_attachment.dart';
import '../../domain/object_sort.dart';
import 'orbit_explorer_row.dart';

/// Real on-disk Notes folders. Objects keep their identity when their owner moves.
IconData viewTypeIcon(String? viewType) => switch (viewType) {
  'board' => Icons.view_kanban_outlined,
  'calendar' => Icons.calendar_month_outlined,
  'timeline' => Icons.timeline_outlined,
  'exercises' => Icons.table_chart_outlined,
  'overview' => Icons.dashboard_outlined,
  'game_dashboard' => Icons.sports_esports_outlined,
  'milestones' => Icons.flag_outlined,
  _ => Icons.checklist_outlined,
};

class NoteFolderExplorer extends StatefulWidget {
  const NoteFolderExplorer({
    super.key,
    required this.controller,
    required this.notes,
    this.filtering = false,
  });
  final WorkspaceController controller;
  final List<UniversalObject> notes;
  final bool filtering;

  @override
  State<NoteFolderExplorer> createState() => _NoteFolderExplorerState();
}

class _NoteFolderExplorerState extends State<NoteFolderExplorer> {
  final Set<String> _selectedNoteIds = {};
  String? _anchorNoteId;
  final FocusNode _focusNode = FocusNode();
  int _focusedIndex = 0;
  bool _showArchived = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Widget _drag(String path, String? noteId, Widget child) =>
      Draggable<({String path, String? noteId})>(
        data: (path: path, noteId: noteId),
        maxSimultaneousDrags:
            widget.controller.repository.readOnly || path == 'Notes' ? 0 : 1,
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
          return !widget.controller.repository.readOnly &&
              source.path != folder &&
              p.posix.dirname(source.path) != folder &&
              !folder.startsWith('${source.path}/');
        },
        onAcceptWithDetails: (details) async {
          if (details.data.noteId == null) {
            await widget.controller.organize(
              () => widget.controller.repository.moveFolder(
                details.data.path,
                '$folder/${p.posix.basename(details.data.path)}',
              ),
            );
          } else {
            await widget.controller.moveObjectToFolder(
              details.data.noteId!,
              folder,
            );
          }
        },
        builder: (context, candidates, rejected) => ColoredBox(
          color: candidates.isEmpty
              ? Colors.transparent
              : Theme.of(context).colorScheme.primary.withValues(alpha: .12),
          child: child,
        ),
      );

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
          decoration: InputDecoration(
            labelText: title.toLowerCase().contains('folder')
                ? 'Folder name'
                : title,
          ),
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
            for (final folder in widget.controller.repository.folders)
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
    if (action == 'new_note') {
      await widget.controller.create(
        'orbit.note',
        properties: {'folder': folder},
      );
    } else if (action == 'new_canvas') {
      await widget.controller.create(
        'orbit.canvas',
        properties: {'folder': folder},
      );
    } else if (action == 'new_task_list') {
      final base = p.posix.basename(folder);
      await widget.controller.create(
        'orbit.view',
        title: '$base Tasks',
        properties: {'folder': folder, 'viewType': 'tasks'},
      );
    } else if (action == 'new_board') {
      final base = p.posix.basename(folder);
      await widget.controller.create(
        'orbit.view',
        title: '$base Board',
        properties: {
          'folder': folder,
          'viewType': 'board',
          'preset': 'university',
        },
      );
    } else if (action == 'new_calendar') {
      final base = p.posix.basename(folder);
      await widget.controller.create(
        'orbit.view',
        title: '$base Calendar',
        properties: {'folder': folder, 'viewType': 'calendar'},
      );
    } else if (action == 'new_timeline') {
      final base = p.posix.basename(folder);
      await widget.controller.create(
        'orbit.view',
        title: '$base Timeline',
        properties: {'folder': folder, 'viewType': 'timeline'},
      );
    } else if (action == 'new_game_project') {
      final name = await _name(context, 'New Game Project', initial: 'MyGame');
      if (name != null && name.trim().isNotEmpty) {
        await widget.controller.createGameProject(
          name.trim(),
          targetParentFolder: folder,
        );
      }
    } else if (action == 'new_gdd') {
      final name = await _name(
        context,
        'New GDD Note',
        initial: 'Game Design Document',
      );
      await widget.controller.createGameDesignDocument(
        folder: folder,
        title: name,
      );
    } else if (action == 'new_feature_spec') {
      final name = await _name(
        context,
        'New Feature Spec',
        initial: 'Feature Spec',
      );
      await widget.controller.createFeatureSpec(folder: folder, title: name);
    } else if (action == 'new_bug_report') {
      final name = await _name(context, 'New Bug Report', initial: 'Bug');
      await widget.controller.createBugReport(folder: folder, title: name);
    } else if (action == 'new_playtest') {
      final name = await _name(
        context,
        'New Playtest Session',
        initial: 'Playtest',
      );
      await widget.controller.createPlaytestSession(
        folder: folder,
        title: name,
      );
    } else if (action == 'new_dev_log') {
      await widget.controller.createDevLog(folder: folder);
    } else if (action == 'new_level_design') {
      final name = await _name(
        context,
        'New Level Design Doc',
        initial: 'Level 1',
      );
      await widget.controller.createLevelDesignDoc(folder: folder, title: name);
    } else if (action == 'new_course') {
      final name = await _name(
        context,
        'New University Course',
        initial: 'AKMath',
      );
      if (name != null && name.trim().isNotEmpty) {
        await widget.controller.createUniversityCourse(
          name.trim(),
          targetParentFolder: folder,
        );
      }
    } else if (action == 'new_lecture') {
      final name = await _name(context, 'New Lecture Note', initial: 'Lecture');
      await widget.controller.createLectureNote(folder: folder, title: name);
    } else if (action == 'new_exercise') {
      final name = await _name(
        context,
        'New Exercise Canvas',
        initial: 'Exercise',
      );
      await widget.controller.createExerciseCanvas(folder: folder, title: name);
    } else if (action == 'archive') {
      widget.controller.archiveFolder(folder);
    } else if (action == 'restore') {
      widget.controller.restoreFolder(folder);
    } else if (action == 'new') {
      final name = await _name(context, 'New folder');
      if (name != null) {
        await widget.controller.organize(
          () => widget.controller.repository.createFolder('$folder/$name'),
        );
      }
    } else if (action == 'rename') {
      final name = await _name(
        context,
        'Rename folder',
        initial: p.posix.basename(folder),
      );
      if (name != null && name != p.posix.basename(folder)) {
        await widget.controller.organize(
          () => widget.controller.repository.moveFolder(
            folder,
            '${p.posix.dirname(folder)}/$name',
          ),
        );
      }
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => OrbitDialog(
          title: const Text('Delete folder'),
          content: Text(
            'Delete “${p.posix.basename(folder)}”? Notes inside this folder will be moved to Trash.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await widget.controller.deleteFolder(folder);
      }
    } else if (action == 'reveal') {
      await openAttachment(
        widget.controller.repository.location,
        folder,
        reveal: true,
      );
    } else if (action == 'move') {
      final parent = await _destination(context, exclude: folder);
      if (parent != null && parent != p.posix.dirname(folder)) {
        await widget.controller.organize(
          () => widget.controller.repository.moveFolder(
            folder,
            '$parent/${p.posix.basename(folder)}',
          ),
        );
      }
    }
  }

  void _onNoteTap(String noteId, List<String> visibleNoteIds) {
    final isCtrl =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;

    setState(() {
      if (isCtrl) {
        if (_selectedNoteIds.contains(noteId)) {
          _selectedNoteIds.remove(noteId);
        } else {
          _selectedNoteIds.add(noteId);
          _anchorNoteId = noteId;
        }
      } else if (isShift &&
          _anchorNoteId != null &&
          visibleNoteIds.contains(_anchorNoteId)) {
        final start = visibleNoteIds.indexOf(_anchorNoteId!);
        final end = visibleNoteIds.indexOf(noteId);
        final minIdx = math.min(start, end);
        final maxIdx = math.max(start, end);
        _selectedNoteIds.clear();
        _selectedNoteIds.addAll(visibleNoteIds.sublist(minIdx, maxIdx + 1));
      } else {
        _selectedNoteIds.clear();
        _selectedNoteIds.add(noteId);
        _anchorNoteId = noteId;
        widget.controller.openObject(noteId);
      }
    });
  }

  Future<void> _batchMoveToFolder() async {
    if (_selectedNoteIds.isEmpty) return;
    final target = await _destination(context);
    if (target != null) {
      await widget.controller.organize(() async {
        for (final id in List.of(_selectedNoteIds)) {
          await widget.controller.repository.moveNote(id, target);
        }
      });
      setState(() => _selectedNoteIds.clear());
    }
  }

  Future<void> _batchCopyReferences() async {
    if (_selectedNoteIds.isEmpty) return;
    final refs = _selectedNoteIds
        .map(widget.controller.find)
        .whereType<UniversalObject>()
        .map((o) => ObjectReference(o.id).markdown(o.title))
        .join('\n');
    await Clipboard.setData(ClipboardData(text: refs));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied ${_selectedNoteIds.length} note references'),
        ),
      );
    }
  }

  Future<void> _batchMoveToTrash() async {
    if (_selectedNoteIds.isEmpty) return;
    final count = _selectedNoteIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => OrbitDialog(
        title: const Text('Move to Trash'),
        content: Text('Move $count notes to Trash?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      int moved = 0;
      try {
        for (final id in List.of(_selectedNoteIds)) {
          await widget.controller.trash(id);
          moved++;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Moved $moved of $count notes before error: $e'),
            ),
          );
        }
      }
      setState(() => _selectedNoteIds.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.controller.repository;
    final rows = <Widget>[];

    final visibleEntries = <({bool isFolder, String id, String folderPath})>[];
    final visibleNoteIds = <String>[];

    bool isFolderArchived(String f) => widget.controller.isArchivedFolder(f);

    bool objectInFolder(UniversalObject o, String folder) {
      if (o.isDeleted) return false;
      if (o.typeId == 'orbit.file' && !widget.controller.showAttachments) {
        return false;
      }
      final f = o.properties['folder'];
      if (f is String && f.isNotEmpty) {
        return f == folder;
      }
      final pth = repo.objectPath(o.id);
      if (pth != null && pth.isNotEmpty) {
        return p.posix.dirname(pth) == folder;
      }
      if (folder == 'Notes') {
        return o.typeId == 'orbit.note' ||
            o.typeId == 'orbit.canvas' ||
            o.typeId == 'orbit.view';
      }
      return false;
    }

    final allItems = widget.controller.activeObjects
        .where(
          (o) =>
              !o.isDeleted &&
              (o.typeId == 'orbit.note' ||
                  o.typeId == 'orbit.canvas' ||
                  o.typeId == 'orbit.view' ||
                  o.typeId == 'orbit.file'),
        )
        .toList();

    void collect(String folder) {
      if (isFolderArchived(folder)) return;
      visibleEntries.add((isFolder: true, id: folder, folderPath: folder));
      final collapsed =
          !widget.filtering &&
          widget.controller.session.collapsedFolders.contains(folder);
      if (collapsed) return;
      for (final child in repo.folders.where(
        (f) =>
            f != folder && p.posix.dirname(f) == folder && !isFolderArchived(f),
      )) {
        collect(child);
      }
      final folderObjects = allItems
          .where((o) => objectInFolder(o, folder))
          .toList();
      sortObjects(folderObjects, widget.controller.session.noteSort);
      for (final note in folderObjects) {
        visibleEntries.add((isFolder: false, id: note.id, folderPath: folder));
        visibleNoteIds.add(note.id);
      }
    }

    collect('Notes');

    void visit(String folder, int depth) {
      final collapsed =
          !widget.filtering &&
          widget.controller.session.collapsedFolders.contains(folder);
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
                onExpand: () => widget.controller.updateSession(
                  (s) => s.collapsedFolders = s.collapsedFolders
                      .where((f) => f != folder)
                      .toList(),
                ),
                onCollapse: () => widget.controller.updateSession(
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
                onTap: () => widget.controller.updateSession(
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
                      value: 'new_note',
                      child: const Text('New Note'),
                    ),
                    PopupMenuItem(
                      enabled: !repo.readOnly,
                      value: 'new_canvas',
                      child: const Text('New Canvas'),
                    ),
                    PopupMenuItem(
                      enabled: !repo.readOnly,
                      value: 'new_task_list',
                      child: const Text('New Task List'),
                    ),
                    PopupMenuItem(
                      enabled: !repo.readOnly,
                      value: 'new_board',
                      child: const Text('New Board'),
                    ),
                    PopupMenuItem(
                      enabled: !repo.readOnly,
                      value: 'new_calendar',
                      child: const Text('New Calendar'),
                    ),
                    PopupMenuItem(
                      enabled: !repo.readOnly,
                      value: 'new_timeline',
                      child: const Text('New Timeline'),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      enabled: !repo.readOnly,
                      value: 'new_game_project',
                      child: const Text('New Game Project…'),
                    ),
                    PopupMenuItem(
                      enabled: !repo.readOnly,
                      value: 'new_gdd',
                      child: const Text('New GDD Note'),
                    ),
                    PopupMenuItem(
                      enabled: !repo.readOnly,
                      value: 'new_feature_spec',
                      child: const Text('New Feature Spec'),
                    ),
                    PopupMenuItem(
                      enabled: !repo.readOnly,
                      value: 'new_bug_report',
                      child: const Text('New Bug Report'),
                    ),
                    PopupMenuItem(
                      enabled: !repo.readOnly,
                      value: 'new_playtest',
                      child: const Text('New Playtest Session'),
                    ),
                    PopupMenuItem(
                      enabled: !repo.readOnly,
                      value: 'new_dev_log',
                      child: const Text('New Dev Log'),
                    ),
                    PopupMenuItem(
                      enabled: !repo.readOnly,
                      value: 'new_level_design',
                      child: const Text('New Level Design Doc'),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      enabled: !repo.readOnly,
                      value: 'new_course',
                      child: const Text('New Course (University)…'),
                    ),
                    PopupMenuItem(
                      enabled: !repo.readOnly,
                      value: 'new_lecture',
                      child: const Text('New Lecture Note'),
                    ),
                    PopupMenuItem(
                      enabled: !repo.readOnly,
                      value: 'new_exercise',
                      child: const Text('New Exercise Canvas'),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      enabled: !repo.readOnly,
                      value: 'new',
                      child: Text(
                        folder == 'Notes' ? 'New folder' : 'New subfolder',
                      ),
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
                      if (!kIsWeb)
                        const PopupMenuItem(
                          value: 'reveal',
                          child: Text('Reveal in File Explorer'),
                        ),
                      PopupMenuItem(
                        enabled: !repo.readOnly,
                        value: 'archive',
                        child: const Text('Archive folder'),
                      ),
                      PopupMenuItem(
                        enabled: !repo.readOnly,
                        value: 'delete',
                        child: const Text('Delete folder'),
                      ),
                    ] else if (!kIsWeb) ...[
                      const PopupMenuItem(
                        value: 'reveal',
                        child: Text('Reveal in File Explorer'),
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
        (f) =>
            f != folder && p.posix.dirname(f) == folder && !isFolderArchived(f),
      )) {
        visit(child, depth + 1);
      }
      final folderObjects = allItems
          .where((o) => objectInFolder(o, folder))
          .toList();
      sortObjects(folderObjects, widget.controller.session.noteSort);
      for (final note in folderObjects) {
        final isMulti = _selectedNoteIds.contains(note.id);
        final hasBatch = _selectedNoteIds.length > 1 && isMulti;
        final isPdf =
            note.typeId == 'orbit.file' &&
            note.properties['mimeType'] == 'application/pdf';
        final leadingWidget =
            note.properties['icon'] != null &&
                note.properties['icon'].toString().isNotEmpty
            ? Text(
                note.properties['icon'].toString(),
                style: const TextStyle(fontSize: 14),
              )
            : note.typeId == 'orbit.canvas'
            ? const Icon(Icons.dashboard_outlined, size: 16)
            : note.typeId == 'orbit.view'
            ? Icon(
                viewTypeIcon(note.properties['viewType'] as String?),
                size: 16,
              )
            : note.typeId == 'orbit.file'
            ? Icon(
                isPdf
                    ? Icons.picture_as_pdf_outlined
                    : Icons.insert_drive_file_outlined,
                size: 16,
                color: isPdf ? Theme.of(context).colorScheme.error : null,
              )
            : const Icon(Icons.description_outlined, size: 16);

        rows.add(
          Padding(
            padding: EdgeInsets.only(left: (depth + 1) * 12.0),
            child: _drag(
              repo.objectPath(note.id) ?? note.title,
              note.id,
              OrbitExplorerRow(
                key: ValueKey(
                  note.typeId == 'orbit.note'
                      ? 'folder-note:${note.id}'
                      : 'folder-item:${note.id}',
                ),
                selected: widget.controller.session.activeId == note.id,
                multiSelected: isMulti,
                leading: leadingWidget,
                title: Text(
                  note.title.isEmpty ? 'Untitled' : note.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () => _onNoteTap(note.id, visibleNoteIds),
                menu: PopupMenuButton<String>(
                  tooltip: 'Object actions',
                  icon: const Icon(Icons.more_horiz, size: 16),
                  onSelected: (action) async {
                    if (action == 'batch_move') {
                      await _batchMoveToFolder();
                    } else if (action == 'batch_copy') {
                      await _batchCopyReferences();
                    } else if (action == 'batch_trash') {
                      await _batchMoveToTrash();
                    } else if (action == 'rename') {
                      if (!context.mounted) return;
                      final name = await _name(
                        context,
                        'Rename',
                        initial: note.title,
                      );
                      if (name != null &&
                          name.trim().isNotEmpty &&
                          name != note.title) {
                        widget.controller.edit(note.id, title: name.trim());
                      }
                    } else if (action == 'copy') {
                      await Clipboard.setData(
                        ClipboardData(
                          text: ObjectReference(note.id).markdown(note.title),
                        ),
                      );
                    } else if (action == 'split') {
                      widget.controller.openObject(note.id, secondary: true);
                    } else if (action == 'duplicate') {
                      if (note.typeId == 'orbit.view') {
                        await widget.controller.duplicateView(note.id);
                      }
                    } else if (action == 'reveal') {
                      final relPath = repo.objectPath(note.id);
                      if (relPath != null) {
                        await openAttachment(
                          repo.location,
                          relPath,
                          reveal: true,
                        );
                      }
                    } else if (action == 'trash') {
                      await widget.controller.trash(note.id);
                    } else if (action == 'move') {
                      if (!context.mounted) return;
                      final target = await _destination(context);
                      if (target != null && target != folder) {
                        await widget.controller.moveObjectToFolder(
                          note.id,
                          target,
                        );
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    if (hasBatch) ...[
                      PopupMenuItem(
                        value: 'batch_move',
                        child: Text(
                          'Move ${_selectedNoteIds.length} items to folder…',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'batch_copy',
                        child: Text(
                          'Copy ${_selectedNoteIds.length} references',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'batch_trash',
                        child: Text('Move ${_selectedNoteIds.length} to Trash'),
                      ),
                      const PopupMenuDivider(),
                    ],
                    PopupMenuItem(
                      enabled: !repo.readOnly && !note.isReadOnly,
                      value: 'rename',
                      child: Text(
                        note.typeId == 'orbit.note' ? 'Rename note' : 'Rename',
                      ),
                    ),
                    if (note.typeId == 'orbit.view')
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Text('Duplicate View'),
                      ),
                    const PopupMenuItem(
                      value: 'split',
                      child: Text('Open beside'),
                    ),
                    PopupMenuItem(
                      value: 'copy',
                      child: Text(
                        note.typeId == 'orbit.note'
                            ? 'Copy note reference'
                            : 'Copy reference',
                      ),
                    ),
                    PopupMenuItem(
                      enabled: !repo.readOnly && !note.isReadOnly,
                      value: 'move',
                      child: const Text('Move to folder…'),
                    ),
                    if (repo.objectPath(note.id) != null && !kIsWeb)
                      const PopupMenuItem(
                        value: 'reveal',
                        child: Text('Reveal in File Explorer'),
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

    // Archived Folders section
    final archivedFolders = repo.folders
        .where((f) => isFolderArchived(f))
        .toList();
    if (archivedFolders.isNotEmpty) {
      rows.add(const SizedBox(height: 8));
      rows.add(
        OrbitExplorerRow(
          key: const ValueKey('archived-header'),
          leading: Icon(
            _showArchived ? Icons.expand_more : Icons.chevron_right,
            size: 16,
          ),
          title: Text(
            'Archived (${archivedFolders.length})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          onTap: () => setState(() => _showArchived = !_showArchived),
          menu: PopupMenuButton<String>(
            tooltip: 'Archived options',
            icon: const Icon(Icons.more_horiz, size: 16),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'toggle',
                child: Text(_showArchived ? 'Collapse' : 'Expand'),
              ),
            ],
            onSelected: (_) => setState(() => _showArchived = !_showArchived),
          ),
        ),
      );

      if (_showArchived) {
        for (final archFolder in archivedFolders) {
          rows.add(
            Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: OrbitExplorerRow(
                key: ValueKey('archived-folder:$archFolder'),
                leading: const Icon(Icons.archive_outlined, size: 16),
                title: Text(
                  p.posix.basename(archFolder),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                onTap: () {},
                menu: PopupMenuButton<String>(
                  tooltip: 'Archived folder actions',
                  icon: const Icon(Icons.more_horiz, size: 16),
                  onSelected: (action) =>
                      _folderAction(context, archFolder, action),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'restore',
                      child: Text('Restore folder'),
                    ),
                    if (!kIsWeb)
                      const PopupMenuItem(
                        value: 'reveal',
                        child: Text('Reveal in File Explorer'),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete folder'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      }
    }

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final isCtrl =
            HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed;
        final isShift = HardwareKeyboard.instance.isShiftPressed;

        if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyA) {
          setState(() {
            _selectedNoteIds.clear();
            _selectedNoteIds.addAll(visibleNoteIds);
          });
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          if (visibleEntries.isNotEmpty) {
            setState(() {
              _focusedIndex = math.min(
                visibleEntries.length - 1,
                _focusedIndex + 1,
              );
              final item = visibleEntries[_focusedIndex];
              if (!item.isFolder) {
                if (isShift) {
                  if (_anchorNoteId != null &&
                      visibleNoteIds.contains(_anchorNoteId)) {
                    final start = visibleNoteIds.indexOf(_anchorNoteId!);
                    final end = visibleNoteIds.indexOf(item.id);
                    final minIdx = math.min(start, end);
                    final maxIdx = math.max(start, end);
                    _selectedNoteIds.clear();
                    _selectedNoteIds.addAll(
                      visibleNoteIds.sublist(minIdx, maxIdx + 1),
                    );
                  } else {
                    _selectedNoteIds.add(item.id);
                    _anchorNoteId = item.id;
                  }
                } else {
                  _selectedNoteIds.clear();
                  _selectedNoteIds.add(item.id);
                  _anchorNoteId = item.id;
                }
              }
            });
            return KeyEventResult.handled;
          }
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          if (visibleEntries.isNotEmpty) {
            setState(() {
              _focusedIndex = math.max(0, _focusedIndex - 1);
              final item = visibleEntries[_focusedIndex];
              if (!item.isFolder) {
                if (isShift) {
                  if (_anchorNoteId != null &&
                      visibleNoteIds.contains(_anchorNoteId)) {
                    final start = visibleNoteIds.indexOf(_anchorNoteId!);
                    final end = visibleNoteIds.indexOf(item.id);
                    final minIdx = math.min(start, end);
                    final maxIdx = math.max(start, end);
                    _selectedNoteIds.clear();
                    _selectedNoteIds.addAll(
                      visibleNoteIds.sublist(minIdx, maxIdx + 1),
                    );
                  } else {
                    _selectedNoteIds.add(item.id);
                    _anchorNoteId = item.id;
                  }
                } else {
                  _selectedNoteIds.clear();
                  _selectedNoteIds.add(item.id);
                  _anchorNoteId = item.id;
                }
              }
            });
            return KeyEventResult.handled;
          }
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          if (_focusedIndex >= 0 && _focusedIndex < visibleEntries.length) {
            final item = visibleEntries[_focusedIndex];
            if (item.isFolder) {
              final collapsed = widget.controller.session.collapsedFolders
                  .contains(item.id);
              if (collapsed) {
                widget.controller.updateSession(
                  (s) => s.collapsedFolders = s.collapsedFolders
                      .where((f) => f != item.id)
                      .toList(),
                );
              } else if (_focusedIndex + 1 < visibleEntries.length) {
                setState(() => _focusedIndex++);
              }
              return KeyEventResult.handled;
            }
          }
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          if (_focusedIndex >= 0 && _focusedIndex < visibleEntries.length) {
            final item = visibleEntries[_focusedIndex];
            if (item.isFolder) {
              final collapsed = widget.controller.session.collapsedFolders
                  .contains(item.id);
              if (!collapsed && item.id != 'Notes') {
                widget.controller.updateSession(
                  (s) => s.collapsedFolders = {
                    ...s.collapsedFolders,
                    item.id,
                  }.toList(),
                );
              } else {
                final parentFolder = p.posix.dirname(item.id);
                final parentIdx = visibleEntries.indexWhere(
                  (e) => e.isFolder && e.id == parentFolder,
                );
                if (parentIdx >= 0) setState(() => _focusedIndex = parentIdx);
              }
              return KeyEventResult.handled;
            } else {
              final parentFolder = item.folderPath;
              final parentIdx = visibleEntries.indexWhere(
                (e) => e.isFolder && e.id == parentFolder,
              );
              if (parentIdx >= 0) setState(() => _focusedIndex = parentIdx);
              return KeyEventResult.handled;
            }
          }
        }

        if (event.logicalKey == LogicalKeyboardKey.enter) {
          if (_focusedIndex >= 0 && _focusedIndex < visibleEntries.length) {
            final item = visibleEntries[_focusedIndex];
            if (item.isFolder) {
              final collapsed = widget.controller.session.collapsedFolders
                  .contains(item.id);
              widget.controller.updateSession(
                (s) => s.collapsedFolders = collapsed
                    ? s.collapsedFolders.where((f) => f != item.id).toList()
                    : {...s.collapsedFolders, item.id}.toList(),
              );
            } else {
              widget.controller.openObject(item.id);
            }
            return KeyEventResult.handled;
          }
        }

        if (event.logicalKey == LogicalKeyboardKey.space) {
          if (_focusedIndex >= 0 && _focusedIndex < visibleEntries.length) {
            final item = visibleEntries[_focusedIndex];
            if (!item.isFolder) {
              setState(() {
                if (_selectedNoteIds.contains(item.id)) {
                  _selectedNoteIds.remove(item.id);
                } else {
                  _selectedNoteIds.add(item.id);
                }
              });
              return KeyEventResult.handled;
            }
          }
        }

        return KeyEventResult.ignored;
      },
      child: Column(
        children: [
          if (_selectedNoteIds.length > 1)
            Container(
              key: const ValueKey('explorer-batch-bar'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: OrbitColors.of(context).raised,
                borderRadius: BorderRadius.circular(OrbitRadius.control),
                border: Border.all(color: OrbitColors.of(context).border),
              ),
              child: Row(
                children: [
                  Text(
                    '${_selectedNoteIds.length} notes selected',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Move to folder…',
                    icon: const Icon(Icons.drive_file_move_outlined, size: 16),
                    onPressed: _batchMoveToFolder,
                    splashRadius: 14,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy references',
                    icon: const Icon(Icons.link, size: 16),
                    onPressed: _batchCopyReferences,
                    splashRadius: 14,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Move to Trash',
                    icon: const Icon(Icons.delete_outline, size: 16),
                    onPressed: _batchMoveToTrash,
                    splashRadius: 14,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Clear selection',
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _selectedNoteIds.clear()),
                    splashRadius: 14,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              children: rows,
            ),
          ),
        ],
      ),
    );
  }
}
