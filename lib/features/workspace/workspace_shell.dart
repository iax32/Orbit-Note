import 'dart:async';
import 'dart:ui' show AppExitResponse;
import 'dart:ui' as ui;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

import '../../app/orbit_theme.dart';
import '../../app/session_state.dart';
import '../../app/workspace_controller.dart';
import '../../domain/universal_object.dart';
import '../../domain/attachment_safety.dart';
import '../../domain/object_sort.dart';
import '../../application/backup_bundle.dart';
import '../../platform/import_backup.dart';
import '../../platform/vault_folder.dart';
import '../../platform/export_file.dart';
import '../../platform/open_attachment.dart';
import '../canvas/canvas_editor.dart';
import '../notes/note_editor.dart';
import 'command_palette.dart';
import 'calendar_view.dart';
import 'workspace_views.dart';
import 'note_folder_explorer.dart';
import 'graph_view.dart';

class WorkspaceShell extends ConsumerStatefulWidget {
  const WorkspaceShell({super.key});
  @override
  ConsumerState<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends ConsumerState<WorkspaceShell> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late final AppLifecycleListener lifecycle;
  bool dropping = false;
  String explorerFilter = '';
  WorkspaceController get c => ref.read(workspaceProvider.notifier);
  @override
  void initState() {
    super.initState();
    lifecycle = AppLifecycleListener(
      onResume: () => unawaited(c.checkExternalChanges()),
      onInactive: () => unawaited(c.flushAll()),
      onExitRequested: () async =>
          await c.flushAll() ? AppExitResponse.exit : AppExitResponse.cancel,
    );
  }

  @override
  void dispose() {
    lifecycle.dispose();
    super.dispose();
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> exportWorkspace() async {
    if (!await c.flushAll()) {
      message('Resolve unsaved changes before exporting.');
      return;
    }
    try {
      if (await exportFile(
        'Orbit Note.workspace.json',
        await c.repository.exportBundle(),
      )) {
        message('Workspace exported with original files and recovery history.');
      }
    } catch (e) {
      message('Export failed: $e');
    }
  }

  Future<void> openWorkspace() async {
    if (c.repository.isBrowser) {
      message(
        'Browser workspaces use browser storage. Export regularly; desktop folders are available in the Windows app.',
      );
      return;
    }
    if (!await c.flushAll()) {
      message('Resolve unsaved changes before opening another workspace.');
      return;
    }
    try {
      final path = await getDirectoryPath(confirmButtonText: 'Open workspace');
      if (path != null) await c.initialize(path: path);
    } catch (e) {
      message('Could not open workspace: $e');
    }
  }

  Future<String?> vaultName({
    String initial = '',
    String? heading,
    String field = 'Vault name',
  }) async {
    final input = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          heading ?? (initial.isEmpty ? 'New Vault' : 'Rename Vault'),
        ),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: InputDecoration(labelText: field),
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

  Future<void> newVault() async {
    if (!await c.flushAll()) return;
    try {
      if (c.repository.isBrowser) {
        message('Folder Vaults are available on desktop.');
        return;
      }
      final name = await vaultName();
      if (name == null) return;
      final parent = await getDirectoryPath(
        confirmButtonText: 'Create Vault here',
      );
      if (parent == null) return;
      final path = await createVaultFolder(parent, name);
      await c.initialize(path: path);
      if (c.hasWorkspace && c.repository.location == path) {
        await c.renameWorkspace(name);
      }
    } catch (e) {
      message('Could not create Vault: $e');
    }
  }

  Future<void> switchVault() async {
    try {
      final recent = await c.repository.recentLocations();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Your Vaults'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.create_new_folder_outlined),
                    title: const Text('New Vault'),
                    onTap: () {
                      Navigator.pop(dialogContext);
                      newVault();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.folder_open),
                    title: const Text('Open Folder'),
                    onTap: () {
                      Navigator.pop(dialogContext);
                      openWorkspace();
                    },
                  ),
                  for (final path in recent)
                    ListTile(
                      title: Text(path.split(RegExp(r'[/\\]')).last),
                      subtitle: Text(
                        path,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Navigator.pop(dialogContext);
                        c.initialize(path: path);
                      },
                    ),
                  if (c.hasWorkspace) ...[
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('Rename current Vault'),
                      onTap: () async {
                        Navigator.pop(dialogContext);
                        final name = await vaultName(
                          initial: c.repository.name,
                        );
                        if (name != null) await c.renameWorkspace(name);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.close),
                      title: const Text('Close Vault'),
                      onTap: () async {
                        Navigator.pop(dialogContext);
                        try {
                          await c.closeWorkspace();
                        } catch (e) {
                          message('$e');
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      message('Vault list is unavailable: $e');
    }
  }

  Future<void> restoreBackup() async {
    if (c.repository.isBrowser) {
      message('Import into a new folder is available on desktop.');
      return;
    }
    if (!await c.flushAll()) return;
    try {
      final selected = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Orbit backup', extensions: ['json']),
        ],
      );
      if (selected == null) return;
      if (await selected.length() > BackupBundle.maxEncodedBytes) {
        message('Backup exceeds the 128 MiB import limit.');
        return;
      }
      final bundle = await compute(
        BackupBundle.parse,
        await selected.readAsString(),
      );
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import into a new workspace'),
          content: Text(
            '${bundle.name}\n${bundle.files.length} files · ${(bundle.totalBytes / 1048576).toStringAsFixed(1)} MiB\n\nReview notices: ${bundle.warnings.isEmpty ? "None" : bundle.warnings.take(5).join("; ")}\n\nChoose a parent folder next. Orbit creates a separate workspace and preserves existing files. Imported recovery journals are retained for review and never replayed automatically.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Choose folder'),
            ),
          ],
        ),
      );
      if (accepted != true) return;
      final parent = await getDirectoryPath(confirmButtonText: 'Import here');
      if (parent == null) return;
      final path = await importBackup(bundle, parent);
      await c.initialize(path: path);
      message('Backup imported into a separate workspace.');
    } catch (e) {
      message(
        'Import failed. Existing workspaces are unchanged; an incomplete .orbit-import folder may remain: $e',
      );
    }
  }

  Future<Uint8List> readIncomingFile(XFile file) async {
    if (await file.length() > 64 * 1024 * 1024) {
      throw const FormatException(
        'Files over 64 MiB are not supported by this capture path.',
      );
    }
    return file.readAsBytes();
  }

  Future<UniversalObject?> importBytes(String name, Uint8List bytes) async {
    try {
      final attachment = await c.repository.importAttachment(
        name: name,
        bytes: bytes,
      );
      // Preserve any active note drafts while adding the newly owned attachment.
      if (c.find(attachment.id) == null) c.objects = [...c.objects, attachment];
      c.notify();
      return attachment;
    } catch (e) {
      message('Could not attach file: $e');
      return null;
    }
  }

  String attachmentMarkdown(UniversalObject object, {String? noteId}) {
    final path = object.properties['contentRef'] as String;
    final label = object.title.replaceAll(RegExp(r'[\[\]\\]'), '');
    final image = (object.properties['mimeType'] as String? ?? '').startsWith(
      'image/',
    );
    final owner =
        c.repository.objectPath(noteId ?? c.session.activeId ?? '') ??
        'Notes/note.md';
    final relative = p.posix.relative(path, from: p.posix.dirname(owner));
    return '${image ? '!' : ''}[$label](<$relative>)';
  }

  Future<String?> insertAttachment({String? noteId}) async {
    try {
      final file = await openFile();
      if (file == null) return null;
      final object = await importBytes(file.name, await readIncomingFile(file));
      return object == null ? null : attachmentMarkdown(object, noteId: noteId);
    } catch (e) {
      message('File selection failed: $e');
      return null;
    }
  }

  Future<String?> pasteImage({String? noteId}) async {
    try {
      final bytes = await Pasteboard.image;
      if (bytes == null) {
        message('No image on the clipboard.');
        return null;
      }
      final object = await importBytes('Screenshot.png', bytes);
      return object == null ? null : attachmentMarkdown(object, noteId: noteId);
    } catch (e) {
      message('Image paste is unavailable: $e');
      return null;
    }
  }

  Future<CanvasImageReference?> canvasImage(
    String name,
    Uint8List bytes,
  ) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final ratio = descriptor.height / descriptor.width;
    descriptor.dispose();
    buffer.dispose();
    final object = await importBytes(name, bytes);
    if (object == null) return null;
    return CanvasImageReference(
      contentRef: object.properties['contentRef'] as String,
      title: name,
      width: 320,
      height: 320 * ratio,
    );
  }

  Future<CanvasImageReference?> selectCanvasImage() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Images',
            extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif'],
          ),
        ],
      );
      return file == null
          ? null
          : await canvasImage(file.name, await readIncomingFile(file));
    } catch (e) {
      message('Image could not be inserted: $e');
      return null;
    }
  }

  Future<CanvasImageReference?> pasteCanvasImage() async {
    try {
      final bytes = await Pasteboard.image;
      if (bytes == null) {
        message('No image on the clipboard.');
        return null;
      }
      return await canvasImage('Screenshot.png', bytes);
    } catch (e) {
      message('Image paste is unavailable: $e');
      return null;
    }
  }

  Widget attachmentImage(BuildContext context, String raw) {
    final refPath = Uri.decodeFull(raw).replaceFirst(RegExp(r'^\.\./'), '');
    return FutureBuilder<Uint8List?>(
      future: c.repository.readAttachment(refPath),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.contain,
            cacheWidth: 1200,
            errorBuilder: (_, _, _) => const Text('Image preview unavailable'),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return const Text(
          'Attachment unavailable — original reference retained',
        );
      },
    );
  }

  String resolveNotePath(String id, String raw) {
    final decoded = Uri.decodeFull(raw);
    if (decoded.startsWith('Attachments/')) return decoded;
    final owner = c.repository.objectPath(id) ?? 'Notes/note.md';
    return p.posix.normalize(p.posix.join(p.posix.dirname(owner), decoded));
  }

  void openAttachmentReference(String raw) {
    final path = Uri.decodeFull(raw).replaceFirst(RegExp(r'^\.\./'), '');
    final matches = c.activeObjects
        .where((o) => o.properties['contentRef'] == path)
        .toList();
    if (matches.length == 1) {
      c.openObject(matches.single.id);
    } else {
      message('Attachment reference could not be resolved.');
    }
  }

  Future<void> openOriginal(
    UniversalObject object, {
    bool reveal = false,
  }) async {
    try {
      final path = object.properties['contentRef'] as String;
      if (!reveal && attachmentNeedsConfirmation(path)) {
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Open this file externally?'),
            content: Text(
              '${object.title}\n\nThis file type may run code or use an unknown application. Only open it if you trust its source. You can use Show in Explorer instead.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open file'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }
      if (await c.repository.readAttachment(path) == null) {
        message('Original attachment is missing.');
        return;
      }
      if (!await openAttachment(c.repository.location, path, reveal: reveal)) {
        message('No application is available to open this file.');
      }
    } catch (e) {
      message('Could not open original: $e');
    }
  }

  Future<void> renameObject(UniversalObject object) async {
    final input = TextEditingController(text: object.title);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename object'),
        content: TextField(
          controller: input,
          autofocus: true,
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(context, v.trim());
          },
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
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    // Dialog exit animation may still own the input for a frame.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    input.dispose();
    if (result != null) c.edit(object.id, title: result);
  }

  Future<void> dropFiles(DropDoneDetails details) async {
    final workspaceId = c.repository.workspaceId;
    final target = c.find(c.session.activeId);
    if (target == null ||
        !['orbit.note', 'orbit.canvas'].contains(target.typeId)) {
      message('Open a note or Canvas to insert dropped files.');
      return;
    }
    for (final file in details.files) {
      if (c.repository.workspaceId != workspaceId ||
          c.find(target.id) == null) {
        return;
      }
      if (target.typeId == 'orbit.canvas') {
        try {
          final image = await canvasImage(
            file.name,
            await readIncomingFile(file),
          );
          if (image != null) {
            final latest = c.find(target.id)!;
            final camera = c.session.cameras[target.id] ?? {};
            c.edit(
              target.id,
              data: {
                ...latest.data,
                'elements': [
                  ...?latest.data['elements'] as List?,
                  {
                    'id': const Uuid().v4(),
                    'type': 'image',
                    'x': (camera['x'] as num? ?? 0) + 80,
                    'y': (camera['y'] as num? ?? 0) + 80,
                    'width': image.width,
                    'height': image.height,
                    'contentRef': image.contentRef,
                    'text': image.title,
                  },
                ],
              },
            );
          }
        } catch (e) {
          message(
            'Drop an image on Canvas; other file types can be attached to notes. $e',
          );
        }
        continue;
      }
      try {
        final object = await importBytes(
          file.name,
          await readIncomingFile(file),
        );
        final latest = c.find(target.id);
        if (object != null &&
            latest != null &&
            c.repository.workspaceId == workspaceId) {
          c.edit(
            target.id,
            body: '${latest.body}\n\n${attachmentMarkdown(object)}\n',
          );
        }
      } catch (e) {
        message('Could not attach ${file.name}: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(workspaceProvider);
    final colors = OrbitColors.of(context);
    if (c.loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.blur_circular, size: 42, color: colors.accent),
              const SizedBox(height: 24),
              const Text('Opening your workspace…'),
              const SizedBox(height: 20),
              const SizedBox(width: 180, child: LinearProgressIndicator()),
            ],
          ),
        ),
      );
    }
    if (!c.hasWorkspace) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.blur_circular, color: colors.accent, size: 48),
                  const SizedBox(height: 24),
                  Text(
                    'A home for your ideas.',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A Vault is an ordinary folder you own. No account. No cloud required.',
                  ),
                  if (c.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(c.error!),
                    ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: newVault,
                        icon: const Icon(Icons.add),
                        label: const Text('New Vault'),
                      ),
                      OutlinedButton.icon(
                        onPressed: openWorkspace,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Open Folder'),
                      ),
                      TextButton(
                        onPressed: switchVault,
                        child: const Text('Recent Vaults'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () =>
            showCommandPalette(context, c),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            c.create('orbit.note'),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            c.flushAll(),
        const SingleActivator(LogicalKeyboardKey.keyW, control: true): () {
          if (c.session.activeId != null) c.closeTab(c.session.activeId!);
        },
        const SingleActivator(
          LogicalKeyboardKey.keyT,
          control: true,
          shift: true,
        ): () {
          if (c.lastClosed != null) c.openObject(c.lastClosed!);
        },
        const SingleActivator(
          LogicalKeyboardKey.keyB,
          control: true,
          shift: true,
        ): () =>
            c.updateSession((s) => s.sidebarVisible = !s.sidebarVisible),
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 800;
            final sidebar =
                wide &&
                c.session.sidebarVisible &&
                !c.session.focusMode &&
                constraints.maxWidth >= 1050;
            final inspector =
                c.session.inspectorVisible &&
                !c.session.focusMode &&
                constraints.maxWidth >= 1220;
            return Scaffold(
              key: scaffoldKey,
              backgroundColor: colors.background,
              drawer: Drawer(
                backgroundColor: colors.panel,
                child: SafeArea(child: explorer()),
              ),
              body: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (wide) activityRail(),
                          if (sidebar) ...[
                            SizedBox(
                              width: c.session.sidebarWidth,
                              child: explorer(),
                            ),
                            MouseRegion(
                              cursor: SystemMouseCursors.resizeColumn,
                              child: GestureDetector(
                                onHorizontalDragUpdate: (e) => c.updateSession(
                                  (s) => s.sidebarWidth =
                                      (s.sidebarWidth + e.delta.dx).clamp(
                                        180,
                                        380,
                                      ),
                                ),
                                child: Container(width: 4, color: colors.panel),
                              ),
                            ),
                          ],
                          Expanded(
                            child: Column(
                              children: [
                                header(wide: wide, sidebar: sidebar),
                                if (c.error != null)
                                  errorBanner(
                                    c.error!,
                                    () =>
                                        c.updateSession((_) => c.error = null),
                                  ),
                                if (c.failures.isNotEmpty)
                                  errorBanner(
                                    c.failures.values.first,
                                    () => c.retry(c.failures.keys.first),
                                    recovery: () => c.saveConflictCopy(
                                      c.failures.keys.first,
                                    ),
                                  ),
                                if (c.repository.issues.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    child: Text(
                                      c.repository.issues.join(' · '),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                if (c.session.tabs.isNotEmpty) tabs(),
                                Expanded(
                                  child: DropTarget(
                                    onDragDone: dropFiles,
                                    onDragEntered: (_) =>
                                        setState(() => dropping = true),
                                    onDragExited: (_) =>
                                        setState(() => dropping = false),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        border: dropping
                                            ? Border.all(
                                                color: colors.accent,
                                                width: 2,
                                              )
                                            : null,
                                      ),
                                      child: content(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (inspector)
                            SizedBox(width: 260, child: inspectorView()),
                        ],
                      ),
                    ),
                    statusBar(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget errorBanner(
    String text,
    VoidCallback retry, {
    VoidCallback? recovery,
  }) => Material(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: retry,
            child: Text(recovery == null ? 'Dismiss' : 'Retry'),
          ),
          if (recovery != null)
            TextButton(onPressed: recovery, child: const Text('Save a copy')),
        ],
      ),
    ),
  );
  Widget activityRail() {
    final colors = OrbitColors.of(context);
    return Container(
      width: 68,
      color: colors.panel,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Tooltip(
              message: 'Orbit Note',
              child: Icon(Icons.blur_circular, color: colors.accent, size: 31),
            ),
          ),
          ...destinations.take(5).map((d) => railButton(d)),
          const Spacer(),
          railButton(destinations[5]),
          railButton(destinations[6]),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  static const destinations =
      <({OrbitDestination destination, String label, IconData icon})>[
        (
          destination: OrbitDestination.home,
          label: 'Home',
          icon: Icons.home_outlined,
        ),
        (
          destination: OrbitDestination.notes,
          label: 'Notes',
          icon: Icons.description_outlined,
        ),
        (
          destination: OrbitDestination.canvas,
          label: 'Canvas',
          icon: Icons.dashboard_outlined,
        ),
        (
          destination: OrbitDestination.tasks,
          label: 'Tasks',
          icon: Icons.check_circle_outline,
        ),
        (
          destination: OrbitDestination.calendar,
          label: 'Calendar',
          icon: Icons.calendar_month_outlined,
        ),
        (
          destination: OrbitDestination.graph,
          label: 'Graph',
          icon: Icons.hub_outlined,
        ),
        (
          destination: OrbitDestination.search,
          label: 'Search',
          icon: Icons.search,
        ),
        (
          destination: OrbitDestination.trash,
          label: 'Trash',
          icon: Icons.delete_outline,
        ),
        (
          destination: OrbitDestination.settings,
          label: 'Settings',
          icon: Icons.tune,
        ),
      ];
  Widget railButton(
    ({OrbitDestination destination, String label, IconData icon}) d,
  ) {
    final selected = c.session.destination == d.destination;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Tooltip(
        message: d.label,
        child: Semantics(
          label: d.label,
          selected: selected,
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => c.navigate(d.destination),
            child: Container(
              width: 46,
              height: 48,
              decoration: BoxDecoration(
                color: selected
                    ? OrbitColors.of(context).accent.withValues(alpha: .13)
                    : null,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                d.icon,
                size: 21,
                color: selected
                    ? OrbitColors.of(context).accent
                    : OrbitColors.of(context).subtle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget explorer() {
    final colors = OrbitColors.of(context), destination = c.session.destination;
    final type = destination == OrbitDestination.canvas
        ? 'orbit.canvas'
        : destination == OrbitDestination.tasks
        ? 'orbit.task'
        : destination == OrbitDestination.calendar
        ? 'orbit.event'
        : 'orbit.note';
    final objects = destination == OrbitDestination.trash
        ? c.objects.where((o) => o.isDeleted).toList()
        : c.ofType(type);
    objects.removeWhere(
      (o) => !o.title.toLowerCase().contains(explorerFilter.toLowerCase()),
    );
    sortObjects(objects, c.session.noteSort);
    final label = destination == OrbitDestination.canvas
        ? 'CANVASES'
        : destination == OrbitDestination.tasks
        ? 'TASKS'
        : destination == OrbitDestination.calendar
        ? 'EVENTS'
        : destination == OrbitDestination.graph
        ? 'GRAPH'
        : destination == OrbitDestination.trash
        ? 'TRASH'
        : 'NOTES';
    return Material(
      color: colors.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 12, 16),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: colors.raised,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.workspaces_outline,
                    size: 17,
                    color: colors.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.repository.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Personal Vault',
                        style: TextStyle(fontSize: 10, color: colors.subtle),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: OutlinedButton(
              onPressed: () => showCommandPalette(context, c),
              child: const Row(
                children: [
                  Icon(Icons.search, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Find anything',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  Text('⌃ P', style: TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 18, right: 8),
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: colors.subtle,
                  ),
                ),
                const Spacer(),
                if (destination != OrbitDestination.trash)
                  IconButton(
                    tooltip: 'Create ${type.replaceFirst('orbit.', '')}',
                    onPressed: () => c.create(type),
                    icon: const Icon(Icons.add, size: 17),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('explorer-filter'),
                    decoration: const InputDecoration(
                      hintText: 'Filter titles',
                      isDense: true,
                    ),
                    onChanged: (value) =>
                        setState(() => explorerFilter = value),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Sort notes',
                  icon: const Icon(Icons.sort, size: 18),
                  initialValue: c.session.noteSort,
                  onSelected: (value) =>
                      c.updateSession((s) => s.noteSort = value),
                  itemBuilder: (_) => objectSortLabels.entries
                      .map(
                        (e) =>
                            PopupMenuItem(value: e.key, child: Text(e.value)),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                type == 'orbit.note' &&
                    destination != OrbitDestination.trash &&
                    c.repository.supportsFolders
                ? NoteFolderExplorer(
                    controller: c,
                    notes: objects,
                    filtering: explorerFilter.isNotEmpty,
                  )
                : objects.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      destination == OrbitDestination.trash
                          ? 'Nothing in Trash.'
                          : 'A quiet space for new ideas.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: colors.subtle,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: objects.length,
                    itemBuilder: (context, index) {
                      final o = objects[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7),
                          ),
                          selected: c.session.activeId == o.id,
                          selectedTileColor: colors.hover,
                          leading: Icon(objectIcon(o.typeId), size: 16),
                          minLeadingWidth: 16,
                          title: Text(
                            o.title.isEmpty ? 'Untitled' : o.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () => c.openObject(o.id),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Object actions',
                            icon: const Icon(Icons.more_horiz, size: 16),
                            onSelected: (v) {
                              if (v == 'trash') c.trash(o.id);
                              if (v == 'restore') c.restore(o.id);
                              if (v == 'split') {
                                c.openObject(o.id, secondary: true);
                              }
                            },
                            itemBuilder: (_) => [
                              if (!o.isDeleted) ...[
                                const PopupMenuItem(
                                  value: 'split',
                                  child: Text('Open beside'),
                                ),
                                const PopupMenuItem(
                                  value: 'trash',
                                  child: Text('Move to Trash'),
                                ),
                              ] else
                                const PopupMenuItem(
                                  value: 'restore',
                                  child: Text('Restore'),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              '${c.activeObjects.length} objects · local workspace',
              style: TextStyle(color: colors.subtle, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget header({required bool wide, required bool sidebar}) => SizedBox(
    height: 54,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          if (wide)
            IconButton(
              tooltip: 'Switch Vault',
              onPressed: switchVault,
              icon: const Icon(Icons.folder_copy_outlined, size: 18),
            ),
          if (!sidebar)
            IconButton(
              tooltip: 'Open explorer',
              onPressed: () => scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu, size: 20),
            ),
          if (!wide)
            PopupMenuButton<OrbitDestination>(
              tooltip: 'Navigate',
              icon: const Icon(Icons.blur_circular),
              onSelected: c.navigate,
              itemBuilder: (_) => destinations
                  .map(
                    (d) => PopupMenuItem(
                      value: d.destination,
                      child: Text(d.label),
                    ),
                  )
                  .toList(),
            ),
          Expanded(
            child: Text(
              destinations
                  .firstWhere((d) => d.destination == c.session.destination)
                  .label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            tooltip: 'Command palette (Ctrl+P)',
            onPressed: () => showCommandPalette(context, c),
            icon: const Icon(Icons.search, size: 19),
          ),
          if (wide)
            IconButton(
              tooltip: c.session.focusMode ? 'Exit Focus' : 'Focus mode',
              onPressed: () =>
                  c.updateSession((s) => s.focusMode = !s.focusMode),
              icon: Icon(
                c.session.focusMode ? Icons.fullscreen_exit : Icons.fullscreen,
                size: 19,
              ),
            ),
          if (wide && c.session.activeId != null)
            PopupMenuButton<String>(
              tooltip: 'Split workspace',
              icon: const Icon(Icons.vertical_split_outlined, size: 19),
              onSelected: (axis) => c.updateSession((s) {
                s.secondaryId = s.activeId;
                s.splitAxis = axis;
              }),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'horizontal', child: Text('Split right')),
                PopupMenuItem(value: 'vertical', child: Text('Split down')),
              ],
            ),
          if (wide)
            IconButton(
              tooltip: 'Toggle explorer',
              onPressed: () =>
                  c.updateSession((s) => s.sidebarVisible = !s.sidebarVisible),
              icon: const Icon(Icons.view_sidebar_outlined, size: 19),
            ),
          IconButton(
            tooltip: 'Context inspector',
            onPressed: () => c.updateSession(
              (s) => s.inspectorVisible = !s.inspectorVisible,
            ),
            icon: const Icon(Icons.info_outline, size: 19),
          ),
        ],
      ),
    ),
  );
  Widget tabs() => SizedBox(
    height: 38,
    child: ReorderableListView.builder(
      scrollDirection: Axis.horizontal,
      buildDefaultDragHandles: false,
      onReorderItem: c.reorderTab,
      itemCount: c.session.tabs.length,
      itemBuilder: (context, index) {
        final id = c.session.tabs[index], object = c.find(id);
        final selected = c.session.activeId == id;
        return ReorderableDragStartListener(
          key: ValueKey(id),
          index: index,
          child: Material(
            color: selected
                ? OrbitColors.of(context).raised
                : Colors.transparent,
            child: InkWell(
              onTap: () => c.openObject(id),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 220),
                padding: const EdgeInsets.only(left: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected
                          ? OrbitColors.of(context).accent
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(objectIcon(object?.typeId ?? ''), size: 14),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        object?.title ?? 'Missing object',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    if (c.dirty.contains(id))
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.circle, size: 5),
                      ),
                    IconButton(
                      tooltip: 'Close tab',
                      onPressed: () => c.closeTab(id),
                      icon: const Icon(Icons.close, size: 12),
                      constraints: const BoxConstraints.tightFor(
                        width: 30,
                        height: 30,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
  Widget content() {
    final destination = c.session.destination,
        object = c.find(c.session.activeId);
    if (destination == OrbitDestination.home) return HomeView(controller: c);
    if (destination == OrbitDestination.settings) {
      return SettingsView(
        controller: c,
        onExport: exportWorkspace,
        onImport: restoreBackup,
        onOpenWorkspace: switchVault,
      );
    }
    if (destination == OrbitDestination.search) {
      return SearchView(controller: c);
    }
    if (destination == OrbitDestination.trash) {
      final objects = c.objects.where((o) => o.isDeleted).toList();
      return objects.isEmpty
          ? const EmptyWorkspace(
              icon: Icons.delete_outline,
              title: 'Trash is empty',
              description:
                  'Deleted objects stay recoverable here. Removing a canvas card never deletes its source.',
            )
          : ListView(
              padding: const EdgeInsets.all(28),
              children: [
                Text(
                  'Trash',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 20),
                ...objects.map(
                  (o) => ObjectRow(
                    object: o,
                    onTap: () => c.restore(o.id),
                    trailing: TextButton(
                      onPressed: () => c.restore(o.id),
                      child: const Text('Restore'),
                    ),
                  ),
                ),
              ],
            );
    }
    if (destination == OrbitDestination.tasks &&
        (object == null || object.typeId != 'orbit.task')) {
      return TasksView(controller: c);
    }
    if (destination == OrbitDestination.calendar &&
        (object == null || object.typeId != 'orbit.event')) {
      return CalendarView(controller: c);
    }
    if (destination == OrbitDestination.graph) {
      return GraphView(controller: c);
    }
    if (object == null || object.isDeleted) {
      return EmptyWorkspace(
        icon: destination == OrbitDestination.canvas
            ? Icons.dashboard_outlined
            : Icons.description_outlined,
        title: destination == OrbitDestination.canvas
            ? 'Think outside the page.'
            : 'Your next thought starts here.',
        description: destination == OrbitDestination.canvas
            ? 'Bring notes, shapes and sketches together on one canvas.'
            : 'Create a note or open one from the explorer.',
        label: destination == OrbitDestination.canvas
            ? 'Create canvas'
            : 'Create note',
        action: () => c.create(
          destination == OrbitDestination.canvas
              ? 'orbit.canvas'
              : 'orbit.note',
        ),
      );
    }
    final secondary = c.find(c.session.secondaryId);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (secondary != null &&
            !secondary.isDeleted &&
            constraints.maxWidth >= 720) {
          final vertical = c.session.splitAxis == 'vertical';
          return Flex(
            direction: vertical ? Axis.vertical : Axis.horizontal,
            children: [
              Expanded(
                flex: (c.session.splitRatio * 1000).round(),
                child: objectView(object),
              ),
              MouseRegion(
                cursor: vertical
                    ? SystemMouseCursors.resizeRow
                    : SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  onPanUpdate: (event) => c.updateSession(
                    (s) => s.splitRatio =
                        (s.splitRatio +
                                (vertical
                                    ? event.delta.dy / constraints.maxHeight
                                    : event.delta.dx / constraints.maxWidth))
                            .clamp(.25, .75),
                  ),
                  child: Container(
                    width: vertical ? null : 6,
                    height: vertical ? 6 : null,
                    color: OrbitColors.of(context).border,
                  ),
                ),
              ),
              Expanded(
                flex: ((1 - c.session.splitRatio) * 1000).round(),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Close split',
                        onPressed: () =>
                            c.updateSession((s) => s.secondaryId = null),
                        icon: const Icon(Icons.close, size: 16),
                      ),
                    ),
                    Expanded(child: objectView(secondary, pane: 'secondary')),
                  ],
                ),
              ),
            ],
          );
        }
        return objectView(object);
      },
    );
  }

  Widget objectView(UniversalObject object, {String pane = 'primary'}) {
    final positionKey = '$pane:${object.id}';
    final view = switch (object.typeId) {
      'orbit.note' => NoteEditor(
        key: ValueKey('$pane:note-${object.id}'),
        noteId: object.id,
        title: object.title,
        body: object.body,
        onTitleChanged: (v) => c.edit(object.id, title: v),
        onBodyChanged: (v) => c.edit(object.id, body: v),
        linkTargets: c.linkTargets,
        linkBindings: object.linkBindings,
        onOpenObject: c.openObject,
        fontSize: c.session.fontSize,
        contentWidth: c.session.contentWidth,
        initialScrollOffset:
            c.session.positions[positionKey] ??
            c.session.positions[object.id] ??
            0,
        onScrollChanged: (v) {
          c.session.positions = {...c.session.positions, positionKey: v};
          c.persistSession();
        },
        initialViewState: c.session.noteViews[positionKey] ?? const {},
        onViewStateChanged: (v) {
          c.session.noteViews = {...c.session.noteViews, positionKey: v};
          c.persistSession();
        },
        imageBuilder: (context, raw) =>
            attachmentImage(context, resolveNotePath(object.id, raw)),
        onInsertAttachment: () => insertAttachment(noteId: object.id),
        onPasteImage: () => pasteImage(noteId: object.id),
        onOpenAttachment: (raw) =>
            openAttachmentReference(resolveNotePath(object.id, raw)),
        onOpenExternalLink: (v) => launchUrl(Uri.parse(v)),
      ),
      'orbit.canvas' => CanvasEditor(
        key: ValueKey('$pane:${object.id}'),
        imageLoader: c.repository.readAttachment,
        onInsertImage: selectCanvasImage,
        onPasteImage: pasteCanvasImage,
        canvasId: object.id,
        data: object.data,
        onChanged: (v) => c.edit(object.id, data: v),
        objects: c.activeObjects
            .where((o) => o.id != object.id)
            .map(
              (o) => CanvasObjectReference(
                id: o.id,
                title: o.title,
                typeId: o.typeId,
                body: o.body,
              ),
            )
            .toList(),
        onOpenObject: c.openObject,
        camera: c.session.cameras[object.id],
        onCameraChanged: (v) {
          c.session.cameras = {...c.session.cameras, object.id: v};
          c.persistSession();
        },
      ),
      'orbit.task' => TaskDetail(
        key: ValueKey(object.id),
        object: object,
        controller: c,
      ),
      'orbit.event' => EventDetail(
        key: ValueKey(object.id),
        object: object,
        controller: c,
      ),
      _ => ListView(
        padding: const EdgeInsets.all(28),
        children: [
          Text(object.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          if ((object.properties['mimeType'] as String? ?? '').startsWith(
            'image/',
          ))
            attachmentImage(context, object.properties['contentRef'] as String),
          const SizedBox(height: 20),
          const Text('Original attachment is preserved in the workspace.'),
          if (!c.repository.isBrowser)
            Wrap(
              spacing: 12,
              children: [
                TextButton.icon(
                  onPressed: () => openOriginal(object),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open original'),
                ),
                TextButton.icon(
                  onPressed: () => openOriginal(object, reveal: true),
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('Show in folder'),
                ),
              ],
            ),
          const SizedBox(height: 16),
          SelectableText(
            object.properties['contentRef'] as String? ?? object.typeId,
          ),
        ],
      ),
    };
    if (!object.isReadOnly && !c.repository.readOnly) return view;
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Read-only: this format requires a newer compatible version.',
          ),
        ),
        Expanded(child: AbsorbPointer(child: view)),
      ],
    );
  }

  Widget inspectorView() {
    final o = c.find(c.session.activeId), colors = OrbitColors.of(context);
    return Material(
      color: colors.panel,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const Text(
                'CONTEXT',
                style: TextStyle(fontSize: 10, letterSpacing: 1.5),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Close inspector',
                onPressed: () =>
                    c.updateSession((s) => s.inspectorVisible = false),
                icon: const Icon(Icons.close, size: 15),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (o == null)
            Text(
              'Open an object to see its context.',
              style: TextStyle(color: colors.subtle, height: 1.5),
            )
          else ...[
            Icon(objectIcon(o.typeId), size: 30, color: colors.accent),
            const SizedBox(height: 16),
            Text(
              o.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              o.typeId.replaceFirst('orbit.', ''),
              style: TextStyle(fontSize: 12, color: colors.subtle),
            ),
            const SizedBox(height: 26),
            const Text(
              'Backlinks',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            if (c.backlinks(o.id).isEmpty)
              Text(
                'No linked notes yet.',
                style: TextStyle(fontSize: 12, color: colors.subtle),
              )
            else
              ...c
                  .backlinks(o.id)
                  .map(
                    (v) =>
                        ObjectRow(object: v, onTap: () => c.openObject(v.id)),
                  ),
            const SizedBox(height: 24),
            Text(
              'Updated ${o.updatedAt.toLocal().toString().split('.').first}',
              style: TextStyle(fontSize: 11, color: colors.subtle),
            ),
            const SizedBox(height: 8),
            SelectableText(
              'ID ${o.id}',
              style: TextStyle(fontSize: 10, color: colors.subtle),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => renameObject(o),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Rename'),
            ),
            TextButton.icon(
              onPressed: () => c.trash(o.id),
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Move to Trash'),
            ),
          ],
        ],
      ),
    );
  }

  Widget statusBar() => Container(
    height: 29,
    color: OrbitColors.of(context).panel,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Row(
      children: [
        Icon(
          c.failures.isEmpty ? Icons.check_circle_outline : Icons.error_outline,
          size: 12,
          color: c.failures.isEmpty
              ? OrbitColors.of(context).success
              : Theme.of(context).colorScheme.error,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            c.saveLabel,
            style: TextStyle(
              fontSize: 10,
              color: OrbitColors.of(context).subtle,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          c.repository.isBrowser ? 'Browser storage' : 'Local workspace',
          style: TextStyle(fontSize: 10, color: OrbitColors.of(context).subtle),
        ),
        const SizedBox(width: 10),
        const Icon(Icons.cloud_off_outlined, size: 12),
      ],
    ),
  );
}
