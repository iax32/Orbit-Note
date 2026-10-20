import 'orbit_tab_strip.dart';
import '../../app/drive_vault_scheduler.dart';
import '../../platform/vault_discovery.dart';
import 'course_hub.dart';
import 'object_bridges.dart';
import '../notes/editor_draft_review.dart';
import '../notes/ocr_review_dialog.dart';
import '../notes/ocr_image_highlight.dart';
import 'backup_import_dialog.dart';
import '../../app/orbit_density.dart';
import '../../app/orbit_components.dart';
import 'dart:async';
import '../../canvas/scene.dart';
import 'dart:convert';
import 'dart:ui' show AppExitResponse;
import 'dart:ui' as ui;

import '../../canvas/diagram_import.dart';
import '../../canvas/geometry.dart';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:crypto/crypto.dart';
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
import '../../app/google_cloud_controller.dart';
import '../../app/drive_sync_controller.dart';
import '../../app/collaboration_controller.dart';
import 'collaboration_settings.dart';
import '../../domain/universal_object.dart';
import '../../domain/attachment_safety.dart';
import '../../domain/object_sort.dart';
import '../../domain/object_discovery.dart';
import '../../domain/object_reference.dart';
import '../../domain/pdf_annotation.dart';
import '../../domain/code_preview.dart';
import '../../application/backup_bundle.dart';
import '../../application/workspace_repository.dart';
import '../../platform/import_backup.dart';
import '../../platform/vault_folder.dart';
import '../../platform/export_file.dart';
import '../../platform/open_attachment.dart';
import '../canvas/canvas_editor.dart';
import '../canvas/diagram_note_dialog.dart';
import '../../canvas/diagram_reference.dart';
import '../notes/note_editor.dart';
import '../notes/read_attachment_preview.dart';
import '../notes/attachment_recovery_dialog.dart';
import '../notes/latex/latex_template_dialog.dart';
import '../notes/note_template_dialog.dart';
import '../notes/shortcuts_dialog.dart';
import '../pdf/pdf_reader.dart';
import '../pdf/library/pdf_book_model.dart';
import '../pdf/library/book_memories_dialog.dart';
import '../pdf/library/pdf_library_view.dart';
import '../files/code_file_preview.dart';
import '../files/model_asset_viewer.dart';
import '../notes/note_link_dialog.dart';
import '../../domain/wiki_links.dart';
import '../../domain/model_asset.dart';
import 'command_palette.dart';
import 'quick_switcher_dialog.dart';
import 'focus_timer.dart';
import 'calendar_view.dart';
import 'workspace_views.dart';
import 'productivity_hub.dart';
import 'note_folder_explorer.dart';
import 'graph_view.dart';
import 'saved_view_host.dart';
import 'object_inspector.dart';
import 'object_rename_dialog.dart';
import 'project_context_panel.dart';
import 'explorer_mini_calendar.dart';
import 'code_ide_workspace.dart';

class WorkspaceShell extends ConsumerStatefulWidget {
  const WorkspaceShell({super.key});
  @override
  ConsumerState<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends ConsumerState<WorkspaceShell> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _canvasCaptures = <String, CanvasCaptureController>{};
  bool _capturingReferences = false;

  Future<void> captureReferenceFiles(
    String canvasId,
    Iterable<XFile> files, {
    Offset? globalPosition,
  }) async {
    if (_capturingReferences) {
      message('A reference capture is already running.');
      return;
    }
    final batch = files.toList();
    if (batch.isEmpty) return;
    if (batch.length > 100) {
      message('Import up to 100 references at a time.');
      return;
    }
    _capturingReferences = true;
    final workspace = c.repository.workspaceId,
        generation = c.workspaceGeneration;
    final place = _canvasCaptures[canvasId]?.prepare(
      globalPosition: globalPosition,
    );
    final ids = <String>[];
    var failed = 0;
    try {
      message('Capturing ${batch.length} reference files…');
      for (final file in batch) {
        if (!_captureStillCurrent(generation, workspace)) return;
        try {
          final bytes = await readIncomingFile(file);
          if (!_captureStillCurrent(generation, workspace)) return;
          final source = await c.captureCreativeReference(
            canvasId,
            file.name,
            bytes,
          );
          ids.add(source.id);
        } catch (e) {
          failed++;
          message('Could not capture ${file.name}: $e');
        }
      }
      if (!_captureStillCurrent(generation, workspace)) return;
      final board = c.find(canvasId);
      final placed =
          board != null &&
          !board.isDeleted &&
          !board.isReadOnly &&
          place?.call(ids) == true;
      message(
        placed
            ? 'Captured ${ids.length} references${failed > 0 ? '; $failed failed' : ''}. Edit captions in Add / organize board content.'
            : '${ids.length} files saved to Vault${failed > 0 ? '; $failed failed' : ''}. The board is unavailable; sources are retained.',
      );
    } finally {
      _capturingReferences = false;
    }
  }

  late final AppLifecycleListener lifecycle;
  bool dropping = false;
  bool explorerDropping = false;
  String explorerFilter = '';
  String explorerTypeFilter = 'all';
  bool _secondaryFocused = false;
  bool _secondaryVisible = false;
  final _primaryPaneFocus = FocusScopeNode(debugLabel: 'Orbit primary pane');
  final _secondaryPaneFocus = FocusScopeNode(
    debugLabel: 'Orbit secondary pane',
  );
  bool get _targetSecondary => _secondaryFocused && _secondaryVisible;
  int _editorFocusSerial = 0;
  int? _editorFocusGeneration;
  String? _editorFocusId;
  String _editorFocusPane = 'primary';

  void _focusPaneEditor({bool secondary = false}) {
    if (!mounted) return;
    final id = secondary ? c.session.secondaryId : c.session.activeId;
    setState(() {
      _secondaryFocused = secondary;
      _editorFocusId = id;
      _editorFocusPane = secondary ? 'secondary' : 'primary';
      _editorFocusSerial++;
      _editorFocusGeneration = c.workspaceGeneration;
    });
    (secondary ? _secondaryPaneFocus : _primaryPaneFocus).requestFocus();
  }

  void _closeSecondaryPane() {
    c.updateSession((s) => s.secondaryId = null);
    _focusPaneEditor();
  }

  void _cycleFocusedTab({bool reverse = false}) {
    final secondary = _targetSecondary && c.session.secondaryId != null;
    c.cycleTab(reverse: reverse, secondary: secondary);
    _focusPaneEditor(secondary: secondary);
  }

  WorkspaceController get c => ref.read(workspaceProvider.notifier);
  @override
  void initState() {
    super.initState();
    ref.read(googleCloudProvider);
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
    _primaryPaneFocus.dispose();
    _secondaryPaneFocus.dispose();
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
      builder: (context) => OrbitDialog(
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
      final discovered = await discoverVaults(recent);
      String label(String path) {
        for (final vault in discovered.vaults) {
          if (vaultPathsEqual(path, vault.path)) return vault.name;
        }
        return path.split(RegExp(r'[/\\]')).last;
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => OrbitDialog(
          title: const Text('Your Vaults'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Text(
                      'ACTIONS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.create_new_folder_outlined),
                    title: const Text('New Vault'),
                    subtitle: const Text('Create a new local vault folder'),
                    onTap: () {
                      Navigator.pop(dialogContext);
                      newVault();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.folder_open),
                    title: const Text('Open Folder as Vault'),
                    subtitle: const Text(
                      'Open an existing directory on your device',
                    ),
                    onTap: () {
                      Navigator.pop(dialogContext);
                      openWorkspace();
                    },
                  ),
                  const Divider(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Text(
                      'YOUR VAULTS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  if (recent.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No recent vaults found.'),
                    ),
                  for (final path in recent)
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      selected: path == c.repository.location,
                      leading: Icon(
                        path == c.repository.location
                            ? Icons.folder_special_outlined
                            : Icons.folder_outlined,
                      ),
                      trailing: path == c.repository.location
                          ? const Icon(Icons.check, size: 18)
                          : const Icon(Icons.chevron_right, size: 18),
                      title: Text(label(path)),
                      subtitle: Text(
                        path,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () async {
                        Navigator.pop(dialogContext);
                        await c.initialize(path: path);
                        if (mounted && c.error != null) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(c.error!)));
                        }
                      },
                    ),
                  if (c.hasWorkspace) ...[
                    const Divider(height: 24),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Text(
                        'MANAGE CURRENT VAULT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
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

  Future<void> showHelpDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => OrbitDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, size: 20),
            SizedBox(width: 8),
            Text('Orbit Note Help & Shortcuts'),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Orbit Note is a local-first personal knowledge OS. Your notes, canvases, and attachments live directly in your local vault folder as Markdown and open files.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 18),
                const Text(
                  'KEYBOARD SHORTCUTS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                _shortcutRow('Ctrl + P', 'Command palette & quick switcher'),
                _shortcutRow('Ctrl + B', 'Toggle sidebar'),
                _shortcutRow('Ctrl + Tab', 'Cycle next tab'),
                _shortcutRow('Ctrl + Shift + Tab', 'Cycle previous tab'),
                _shortcutRow('Ctrl + Shift + T', 'Reopen last closed tab'),
                const SizedBox(height: 18),
                const Text(
                  'CANVAS & EDITOR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                _shortcutRow('Space + Drag', 'Pan canvas scene'),
                _shortcutRow('Scroll Wheel', 'Zoom canvas in / out'),
                _shortcutRow('[[Note Name]]', 'Wiki-link to another note'),
                _shortcutRow(
                  '::card:: / ::callout::',
                  'Milanote & Notion style blocks',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _shortcutRow(String shortcut, String description) {
    final colors = OrbitColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colors.raised,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              shortcut,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.text,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: TextStyle(fontSize: 12, color: colors.subtle),
            ),
          ),
        ],
      ),
    );
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
        builder: (context) => BackupImportDialog(bundle: bundle),
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
    final length = await file.length();
    if (length > 100 * 1024 * 1024) {
      throw const FormatException(
        'Files over 100 MiB are not supported by this recovery path.',
      );
    }
    return file.readAsBytes();
  }

  bool _captureStillCurrent(int generation, String workspace) =>
      mounted &&
      c.hasWorkspace &&
      !c.loading &&
      c.workspaceGeneration == generation &&
      c.repository.workspaceId == workspace;

  Future<UniversalObject?> importBytes(
    String name,
    Uint8List bytes, {
    int? captureGeneration,
    String? captureWorkspace,
  }) async {
    final generation = captureGeneration ?? c.workspaceGeneration;
    final workspace = captureWorkspace ?? c.repository.workspaceId;
    if (!_captureStillCurrent(generation, workspace)) return null;
    try {
      final attachment = await c.importProjectAttachment(name, bytes);
      if (!_captureStillCurrent(generation, workspace)) return null;
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
    if (object.properties['mimeType'] == 'application/pdf') {
      return ObjectReference(object.id).markdown(label);
    }
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
    final generation = c.workspaceGeneration,
        workspace = c.repository.workspaceId;
    try {
      final file = await openFile();
      if (file == null) return null;
      final object = await importBytes(
        file.name,
        await readIncomingFile(file),
        captureGeneration: generation,
        captureWorkspace: workspace,
      );
      return object == null ? null : attachmentMarkdown(object, noteId: noteId);
    } catch (e) {
      message('File selection failed: $e');
      return null;
    }
  }

  Future<String?> pasteImage({String? noteId}) async {
    final generation = c.workspaceGeneration,
        workspace = c.repository.workspaceId;
    try {
      final bytes = await Pasteboard.image;
      if (bytes == null) {
        message('No image on the clipboard.');
        return null;
      }
      final object = await importBytes(
        'Screenshot.png',
        bytes,
        captureGeneration: generation,
        captureWorkspace: workspace,
      );
      return object == null ? null : attachmentMarkdown(object, noteId: noteId);
    } catch (e) {
      message('Image paste is unavailable: $e');
      return null;
    }
  }

  Future<CanvasImageReference?> canvasImage(
    String name,
    Uint8List bytes, {
    int? captureGeneration,
    String? captureWorkspace,
  }) async {
    final generation = captureGeneration ?? c.workspaceGeneration;
    final workspace = captureWorkspace ?? c.repository.workspaceId;
    if (!_captureStillCurrent(generation, workspace)) return null;
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    final double ratio;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      ratio = descriptor.height / descriptor.width;
    } finally {
      descriptor?.dispose();
      buffer.dispose();
    }
    final object = await importBytes(
      name,
      bytes,
      captureGeneration: generation,
      captureWorkspace: workspace,
    );
    if (object == null) return null;
    return CanvasImageReference(
      contentRef: object.properties['contentRef'] as String,
      title: name,
      width: 320,
      height: 320 * ratio,
    );
  }

  Future<CanvasImageReference?> selectCanvasImage() async {
    final generation = c.workspaceGeneration,
        workspace = c.repository.workspaceId;
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
          : await canvasImage(
              file.name,
              await readIncomingFile(file),
              captureGeneration: generation,
              captureWorkspace: workspace,
            );
    } catch (e) {
      message('Image could not be inserted: $e');
      return null;
    }
  }

  Future<CanvasImageReference?> pasteCanvasImage() async {
    final generation = c.workspaceGeneration,
        workspace = c.repository.workspaceId;
    try {
      final bytes = await Pasteboard.image;
      if (bytes == null) {
        message('No image on the clipboard.');
        return null;
      }
      return await canvasImage(
        'Screenshot.png',
        bytes,
        captureGeneration: generation,
        captureWorkspace: workspace,
      );
    } catch (e) {
      message('Image paste is unavailable: $e');
      return null;
    }
  }

  Future<UniversalObject?> pickAndOpenPdf() async {
    final generation = c.workspaceGeneration,
        workspace = c.repository.workspaceId;
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'PDF Documents', extensions: ['pdf']),
        ],
      );
      if (file == null) return null;
      final bytes = await readIncomingFile(file);
      final object = await importBytes(
        file.name,
        bytes,
        captureGeneration: generation,
        captureWorkspace: workspace,
      );
      if (object != null) {
        c.openObject(object.id);
        message('Opened ${object.title}');
      }
      return object;
    } catch (e) {
      message('Could not open PDF: $e');
      return null;
    }
  }

  Future<UniversalObject?> pickAndOpenImage() async {
    final generation = c.workspaceGeneration,
        workspace = c.repository.workspaceId;
    final target = c.find(c.session.activeId);
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Images',
            extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif', 'svg'],
          ),
        ],
      );
      if (file == null) return null;
      final bytes = await readIncomingFile(file);
      if (!_captureStillCurrent(generation, workspace)) return null;
      if (target?.typeId == 'orbit.canvas' &&
          !file.name.toLowerCase().endsWith('.svg')) {
        final img = await canvasImage(
          file.name,
          bytes,
          captureGeneration: generation,
          captureWorkspace: workspace,
        );
        if (img != null) {
          final latest = c.find(target!.id);
          if (!_captureStillCurrent(generation, workspace) ||
              latest == null ||
              latest.isDeleted ||
              latest.isReadOnly) {
            return null;
          }
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
                  'width': img.width,
                  'height': img.height,
                  'contentRef': img.contentRef,
                  'text': img.title,
                },
              ],
            },
          );
          message('Inserted ${file.name} on canvas');
        }
        return null;
      }
      final object = await importBytes(
        file.name,
        bytes,
        captureGeneration: generation,
        captureWorkspace: workspace,
      );
      if (object != null) {
        c.openObject(object.id);
        message('Opened ${object.title}');
      }
      return object;
    } catch (e) {
      message('Could not open image: $e');
      return null;
    }
  }

  Future<UniversalObject?> pickAndImportFile({
    List<XTypeGroup> groups = const [],
  }) async {
    final generation = c.workspaceGeneration,
        workspace = c.repository.workspaceId;
    try {
      final file = await openFile(acceptedTypeGroups: groups);
      if (file == null || !_captureStillCurrent(generation, workspace)) {
        return null;
      }
      final bytes = await readIncomingFile(file);
      final object = await importBytes(
        file.name,
        bytes,
        captureGeneration: generation,
        captureWorkspace: workspace,
      );
      if (object != null && _captureStillCurrent(generation, workspace)) {
        c.openObject(object.id);
        message('Imported ${object.title}');
      }
      return object;
    } catch (e) {
      if (_captureStillCurrent(generation, workspace)) {
        message('Could not import file: $e');
      }
      return null;
    }
  }

  Future<UniversalObject?> pickAndOpenCode() => pickAndImportFile(
    groups: [
      XTypeGroup(
        label: 'Source code and text',
        extensions: codeLanguages.keys.toList(),
      ),
    ],
  );

  Future<UniversalObject?> pickAndOpenModel() => pickAndImportFile(
    groups: const [
      XTypeGroup(label: '3D models', extensions: ['obj', 'glb']),
    ],
  );

  Widget attachmentImage(BuildContext context, String raw) {
    final refPath = Uri.decodeFull(raw).replaceFirst(RegExp(r'^\.\./'), '');
    final matches = c.activeObjects.where(
      (object) =>
          object.typeId == 'orbit.file' &&
          object.properties['contentRef'] == refPath,
    );
    final file = matches.length == 1 ? matches.single : null;
    final local = refPath.startsWith('Attachments/');
    final rawLength = file?.properties['byteLength'];
    return ReadAttachmentImage(
      label: refPath,
      showReplacementStatus: true,
      title: file?.title ?? p.posix.basename(refPath),
      mimeType: file?.properties['mimeType'] is String
          ? file!.properties['mimeType'] as String
          : null,
      recordedByteLength: rawLength is int && rawLength >= 0 ? rawLength : null,
      onRecover: file != null && !file.isReadOnly && !c.repository.readOnly
          ? () => recoverAttachment(file, refPath)
          : null,
      onOpenOriginal: local
          ? () => openOriginalReference(
              refPath,
              file?.title ?? p.posix.basename(refPath),
            )
          : null,
      onReveal: local && !c.repository.isBrowser
          ? () => openOriginalReference(
              refPath,
              file?.title ?? p.posix.basename(refPath),
              reveal: true,
            )
          : null,
      onCopyReference: () async {
        try {
          await Clipboard.setData(ClipboardData(text: refPath));
          message('Attachment reference copied.');
        } catch (e) {
          message('Could not copy attachment reference: $e');
        }
      },
      revision: c.attachmentRevision,
      load: () => c.repository.readAttachment(refPath),
      builder: (bytes) => Image.memory(
        bytes,
        fit: BoxFit.contain,
        cacheWidth: 1200,
        errorBuilder: (_, _, _) => const Text('Image preview unavailable'),
      ),
      retryableBuilder: (bytes, retry) => OcrImageHighlight(
        bytes: bytes,
        match: file == null ? null : c.pdfSearchRequests[file.id],
        image: Image.memory(
          bytes,
          fit: BoxFit.contain,
          cacheWidth: 1200,
          errorBuilder: (_, _, _) =>
              ReadAttachmentDecodeFailure(label: refPath, onRetry: retry),
        ),
      ),
    );
  }

  Future<({int length, String checksum})> inspectIncomingAttachment(
    XFile file,
    AttachmentRecoveryProgress report,
  ) async {
    final total = await file.length();
    if (total > WorkspaceRepository.maxAttachmentRecoveryBytes) {
      throw const FormatException(
        'Files over 100 MiB are not supported by this recovery path.',
      );
    }
    var length = 0;
    final digest = await sha256
        .bind(
          file.openRead().map((chunk) {
            length += chunk.length;
            if (length > WorkspaceRepository.maxAttachmentRecoveryBytes) {
              throw const FormatException(
                'The selected file changed beyond the 100 MiB recovery limit.',
              );
            }
            report(length, total, 'Verifying selected file…');
            return chunk;
          }),
        )
        .first;
    if (length != total) {
      throw const FormatException(
        'The selected file changed while it was being verified.',
      );
    }
    report(length, total, 'Verification complete');
    return (length: length, checksum: digest.toString());
  }

  String resolveNotePath(String id, String raw) {
    final decoded = Uri.decodeFull(raw);
    if (decoded.startsWith('Attachments/')) return decoded;
    final owner = c.repository.objectPath(id) ?? 'Notes/note.md';
    return p.posix.normalize(p.posix.join(p.posix.dirname(owner), decoded));
  }

  Future<void> recoverAttachment(UniversalObject file, String reference) async {
    await c.flush(file.id);
    final expected = c.find(file.id);
    if (!mounted ||
        expected == null ||
        c.dirty.contains(file.id) ||
        c.failures.containsKey(file.id)) {
      message('Save the attachment metadata before opening recovery.');
      return;
    }
    Future<bool> chooseSource({
      required bool original,
      required AttachmentRecoveryProgress report,
      required AttachmentRecoveryCancellation isCancelled,
    }) async {
      final selected = await openFile();
      if (selected == null || !mounted) return false;
      late final ({int length, String checksum}) inspection;
      try {
        inspection = await inspectIncomingAttachment(selected, report);
      } catch (e) {
        message('Could not verify selected file: $e');
        return false;
      }
      if (!mounted) return false;
      final selectedChecksum = inspection.checksum;
      final recordedChecksum = expected.properties['checksum'] as String?;
      final matchesRecorded =
          recordedChecksum != null && recordedChecksum == selectedChecksum;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            original
                ? 'Restore missing original?'
                : 'Use new attachment source?',
          ),
          content: SelectableText(
            '${selected.name} · ${inspection.length} bytes\nSHA-256: $selectedChecksum\n\n${original ? 'Recorded SHA-256: ${recordedChecksum ?? 'unknown'}\n${matchesRecorded ? 'Checksum matches. The missing original can be restored.' : 'Checksum does not match. Choose the original file or relink it as a new source.'}' : 'Links to this file object will use the new source. The original bytes and Markdown paths are retained.'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: original && !matchesRecorded
                  ? null
                  : () => Navigator.pop(context, true),
              child: Text(original ? 'Restore original' : 'Relink source'),
            ),
          ],
        ),
      );
      if (accepted != true) return false;
      final ok = original
          ? await c.recoverMissingAttachmentStream(
              reference,
              selected.openRead(),
              selectedChecksum,
              onProgress: (bytesRead) =>
                  report(bytesRead, inspection.length, 'Restoring original…'),
              isCancelled: isCancelled,
            )
          : await c.changeAttachmentSource(
              expected,
              name: selected.name,
              byteStream: selected.openRead(),
              expectedChecksum: selectedChecksum,
              onProgress: (bytesRead, _, _) =>
                  report(bytesRead, inspection.length, 'Saving new source…'),
              isCancelled: isCancelled,
            );
      if (!ok) message(c.error ?? 'Source recovery failed.');
      return ok;
    }

    // A native interrupted transfer is discoverable without touching the
    // authored object. Browser stores simply return an empty inventory.
    final staged = await c.repository.attachmentRecoveryStages().then(
      (stages) => stages
          .where(
            (stage) =>
                (stage.operation == 'restore' && stage.target == reference) ||
                (stage.operation == 'relink' &&
                    stage.expectedHash == expected.properties['checksum']),
          )
          .toList(),
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AttachmentRecoveryDialog(
        object: expected,
        reference: reference,
        staged: staged,
        onRestoreOriginal: (report, isCancelled) => chooseSource(
          original: true,
          report: report,
          isCancelled: isCancelled,
        ),
        onRelink: (report, isCancelled) => chooseSource(
          original: false,
          report: report,
          isCancelled: isCancelled,
        ),
        onRestoreVersion: (path, report, isCancelled) async {
          final ok = await c.changeAttachmentSource(
            expected,
            retainedReference: path,
            onProgress: (bytesRead, totalBytes, phase) =>
                report(bytesRead, totalBytes, phase),
            isCancelled: isCancelled,
          );
          if (!ok) message(c.error ?? 'Could not restore source version.');
          return ok;
        },
        onOpen: (path) => openOriginalReference(path, p.posix.basename(path)),
        onForgetVersion: (path, report, isCancelled) async {
          final ok = await c.forgetAttachmentSourceVersion(
            expected,
            path,
            onProgress: report,
            isCancelled: isCancelled,
          );
          if (!ok) message(c.error ?? 'Could not clean up retained source.');
          return ok;
        },
        onResume: (stage, report, isCancelled) async {
          final selected = await openFile();
          if (selected == null || !mounted) return false;
          late final ({int length, String checksum}) inspection;
          try {
            inspection = await inspectIncomingAttachment(selected, report);
          } catch (e) {
            message('Could not verify selected file: $e');
            return false;
          }
          if (inspection.checksum != stage.expectedHash ||
              stage.length > inspection.length) {
            message(
              'The selected file does not match this interrupted transfer or is shorter than its saved prefix.',
            );
            return false;
          }
          final source = selected.openRead(stage.length);
          final ok = stage.operation == 'restore'
              ? await c.recoverMissingAttachmentStream(
                  stage.target,
                  source,
                  stage.expectedHash,
                  resumableStageId: stage.id,
                  onProgress: (bytesRead) => report(
                    bytesRead,
                    inspection.length,
                    'Resuming original…',
                  ),
                  isCancelled: isCancelled,
                )
              : await c.changeAttachmentSource(
                  expected,
                  name: stage.sourceName ?? selected.name,
                  byteStream: source,
                  expectedChecksum: stage.expectedHash,
                  resumableStageId: stage.id,
                  onProgress: (bytesRead, _, _) =>
                      report(bytesRead, inspection.length, 'Resuming source…'),
                  isCancelled: isCancelled,
                );
          if (!ok) message(c.error ?? 'Could not resume transfer.');
          return ok;
        },
        onDiscard: (stage) async {
          try {
            await c.repository.discardAttachmentRecoveryStage(stage.id);
            return true;
          } catch (e) {
            message('Could not discard interrupted transfer: $e');
            return false;
          }
        },
      ),
    );
  }

  void openAttachmentReference(String raw) {
    final reference = ObjectReference.parse(Uri.decodeFull(raw));
    final path = reference.id.replaceFirst(RegExp(r'^\.\./'), '');
    final matches = c.activeObjects
        .where((o) => o.properties['contentRef'] == path)
        .toList();
    if (matches.length == 1) {
      openLinkedObject(
        ObjectReference(matches.single.id, page: reference.page).target,
      );
    } else {
      message('Attachment reference could not be resolved.');
    }
  }

  void openLinkedObject(String target) {
    final reference = ObjectReference.parse(target);
    c.requestLocation(reference);
    final object = c.find(reference.id);
    if (object == null || object.isDeleted) {
      message('The referenced object is unavailable.');
      return;
    }
    if (reference.anchorType == 'annotation') {
      final annotationObject = c.find(reference.anchorId);
      if (annotationObject != null &&
          annotationObject.typeId == 'orbit.note' &&
          !annotationObject.isDeleted &&
          PdfAnnotation(annotationObject).fileId == object.id) {
        c.openPdfNote(annotationObject.id);
        return;
      }
      message('PDF annotation is unavailable. The parent document is open.');
    }
    if (reference.page != null &&
        object.properties['mimeType'] == 'application/pdf') {
      final key = 'pdf:primary:${object.id}';
      c.updateSession(
        (s) => s.noteViews = {
          ...s.noteViews,
          key: {...?s.noteViews[key], 'page': reference.page},
        },
      );
    } else if (object.typeId == 'orbit.note' &&
        object.properties['pdfSource'] is Map) {
      c.openPdfNote(object.id);
      return;
    }
    final active = c.find(c.session.activeId);
    if (active?.typeId == 'orbit.canvas' &&
        reference.id != active?.id &&
        object.typeId != 'orbit.canvas') {
      c.updateSession((s) => s.secondaryId = reference.id);
      return;
    }
    c.openObject(reference.id);
  }

  Future<void> openOriginal(
    UniversalObject object, {
    bool reveal = false,
  }) async {
    final current = c.find(object.id);
    final reference = current?.properties['contentRef'];
    if (current == null || current.isDeleted || reference is! String) {
      message('Original attachment reference is unavailable.');
      return;
    }
    await openOriginalReference(
      reference,
      current.title,
      reveal: reveal,
      source: current,
    );
  }

  Future<void> openOriginalReference(
    String path,
    String title, {
    bool reveal = false,
    UniversalObject? source,
  }) async {
    final repo = c.repository, generation = c.workspaceGeneration;
    final attachmentRevision = c.attachmentRevision;
    final workspace = repo.workspaceId, location = repo.location;
    bool current() {
      if (!_captureStillCurrent(generation, workspace) ||
          !identical(repo, c.repository) ||
          attachmentRevision != c.attachmentRevision) {
        return false;
      }
      if (source == null) return true;
      final latest = c.find(source.id);
      return latest != null &&
          !latest.isDeleted &&
          latest.properties['contentRef'] == path &&
          latest.properties['checksum'] == source.properties['checksum'];
    }

    try {
      if (!current()) return;
      if (!reveal && attachmentNeedsConfirmation(path)) {
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => OrbitDialog(
            title: const Text('Open this file externally?'),
            content: Text(
              '$title\n\nThis file type may run code or use an unknown application. Only open it if you trust its source. You can use Show in Explorer instead.',
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
        if (confirmed != true || !current()) return;
      }
      // Folder recovery remains usable for missing or unreadable originals.
      if (!reveal && await repo.readAttachment(path) == null) {
        if (current()) message('Original attachment is missing.');
        return;
      }
      if (!current()) return;
      if (!await openAttachment(location, path, reveal: reveal) && current()) {
        message('No application is available to open this file.');
      }
    } catch (e) {
      if (current()) message('Could not open original: $e');
    }
  }

  Future<void> renameObject(UniversalObject object) =>
      showObjectRenameDialog(context, c, object);

  Future<void> revealObjectInExplorer(String id) async {
    try {
      final relPath = c.repository.objectPath(id);
      if (relPath == null) {
        message('File path not found for this object.');
        return;
      }
      final opened = await openAttachment(
        c.repository.location,
        relPath,
        reveal: true,
      );
      if (!opened) {
        message('Could not reveal file in explorer.');
      }
    } catch (e) {
      message('Could not reveal file: $e');
    }
  }

  Future<void> dropFiles(
    DropDoneDetails details, {
    bool forceToVault = false,
  }) async {
    final workspaceId = c.repository.workspaceId,
        generation = c.workspaceGeneration;
    var target = c.find(c.session.activeId);
    if (!forceToVault) {
      for (final entry in _canvasCaptures.entries) {
        if (entry.value.prepare(globalPosition: details.globalPosition) !=
            null) {
          target = c.find(entry.key);
          break;
        }
      }
    }

    bool targetAvailable() {
      if (!_captureStillCurrent(generation, workspaceId)) return false;
      final latest = c.find(target?.id);
      return latest != null &&
          !latest.isDeleted &&
          !latest.isReadOnly &&
          !c.repository.readOnly &&
          (latest.typeId != 'orbit.canvas' ||
              !CanvasScene.fromJson(latest.data).readOnly);
    }

    // If forceToVault or no active note/canvas, import directly into Vault and open the first file.
    if (forceToVault ||
        target == null ||
        !['orbit.note', 'orbit.canvas'].contains(target.typeId)) {
      UniversalObject? firstOpened;
      for (final file in details.files) {
        if (!_captureStillCurrent(generation, workspaceId)) return;
        final fileName = file.name.trim().isNotEmpty
            ? file.name.trim()
            : (file.path.trim().isNotEmpty
                  ? p.basename(file.path).trim()
                  : 'attachment');
        try {
          final bytes = await readIncomingFile(file);
          if (!_captureStillCurrent(generation, workspaceId)) return;
          final object = await importBytes(
            fileName,
            bytes,
            captureGeneration: generation,
            captureWorkspace: workspaceId,
          );
          if (object != null && firstOpened == null) {
            firstOpened = object;
          }
        } catch (e) {
          message('Could not import $fileName: $e');
        }
      }
      if (firstOpened != null &&
          _captureStillCurrent(generation, workspaceId)) {
        c.openObject(firstOpened.id);
        message('Imported ${firstOpened.title} to Vault');
      }
      return;
    }

    // Target is Canvas
    if (target.typeId == 'orbit.canvas') {
      if (target.properties['creativeProject'] == true) {
        await captureReferenceFiles(
          target.id,
          details.files,
          globalPosition: details.globalPosition,
        );
        return;
      }
      for (final file in details.files) {
        if (!targetAvailable()) {
          return;
        }
        final fileName = file.name.trim().isNotEmpty
            ? file.name.trim()
            : (file.path.trim().isNotEmpty
                  ? p.basename(file.path).trim()
                  : 'attachment');
        final nameLower = fileName.toLowerCase();
        final Uint8List bytes;
        try {
          bytes = await readIncomingFile(file);
        } catch (e) {
          message('Could not read $fileName: $e');
          continue;
        }
        if (!targetAvailable()) return;

        // 1. Bitmapped images
        final isBitmapImage = [
          'png',
          'jpg',
          'jpeg',
          'webp',
          'gif',
        ].any(nameLower.endsWith);
        if (isBitmapImage) {
          try {
            final image = await canvasImage(
              fileName,
              bytes,
              captureGeneration: generation,
              captureWorkspace: workspaceId,
            );
            if (image != null && targetAvailable()) {
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
              message('Inserted ${image.title} on canvas');
            }
          } catch (e) {
            message('Could not insert image $fileName: $e');
          }
          continue;
        }

        // 2. Mermaid diagram files
        if (nameLower.endsWith('.mermaid') || nameLower.endsWith('.mmd')) {
          try {
            final content = utf8.decode(bytes);
            final camera = c.session.cameras[target.id] ?? {};
            final center = CanvasPoint(
              (camera['x'] as num? ?? 0) + 300,
              (camera['y'] as num? ?? 0) + 200,
            );
            final result = parseMermaidFlowchart(content, origin: center);
            final latest = c.find(target.id)!;
            c.edit(
              target.id,
              data: {
                ...latest.data,
                'elements': [
                  ...?latest.data['elements'] as List?,
                  ...result.elements.map((e) => e.data),
                ],
              },
            );
            message(result.summary);
          } catch (e) {
            message('Could not parse diagram $fileName: $e');
          }
          continue;
        }

        // 3. SVG vector files
        if (nameLower.endsWith('.svg')) {
          try {
            final content = utf8.decode(bytes);
            final camera = c.session.cameras[target.id] ?? {};
            final center = CanvasPoint(
              (camera['x'] as num? ?? 0) + 300,
              (camera['y'] as num? ?? 0) + 200,
            );
            final result = parseSvgDiagram(content, targetCenter: center);
            final latest = c.find(target.id)!;
            c.edit(
              target.id,
              data: {
                ...latest.data,
                'elements': [
                  ...?latest.data['elements'] as List?,
                  ...result.elements.map((e) => e.data),
                ],
              },
            );
            message(result.summary);
          } catch (e) {
            message('Could not import SVG $fileName: $e');
          }
          continue;
        }

        // 4. PDF documents and other files: import into Vault and attach as interactive card
        try {
          final object = await importBytes(
            fileName,
            bytes,
            captureGeneration: generation,
            captureWorkspace: workspaceId,
          );
          if (object != null && targetAvailable()) {
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
                    'type': 'card',
                    'objectId': object.id,
                    'text': object.title,
                    'x': (camera['x'] as num? ?? 0) + 80,
                    'y': (camera['y'] as num? ?? 0) + 80,
                    'width': 260.0,
                    'height': 130.0,
                  },
                ],
              },
            );
            message('Attached ${object.title} as canvas card');
          }
        } catch (e) {
          message('Could not attach $fileName: $e');
        }
      }
      return;
    }

    // Target is Note: insert markdown attachment link / image
    if (target.typeId == 'orbit.note') {
      for (final file in details.files) {
        if (!targetAvailable()) {
          return;
        }
        final fileName = file.name.trim().isNotEmpty
            ? file.name.trim()
            : (file.path.trim().isNotEmpty
                  ? p.basename(file.path).trim()
                  : 'attachment');
        try {
          final bytes = await readIncomingFile(file);
          if (!_captureStillCurrent(generation, workspaceId)) return;
          final object = await importBytes(
            fileName,
            bytes,
            captureGeneration: generation,
            captureWorkspace: workspaceId,
          );
          final latest = c.find(target.id);
          if (object != null && latest != null && targetAvailable()) {
            c.edit(
              target.id,
              body:
                  '${latest.body}\n\n${attachmentMarkdown(object, noteId: target.id)}\n',
            );
            message('Attached ${object.title} to note');
          }
        } catch (e) {
          message('Could not attach $fileName: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(workspaceProvider);
    ref.watch(driveSyncStartupProvider);
    ref.watch(driveScheduleStartupProvider);
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
        const SingleActivator(
          LogicalKeyboardKey.space,
          control: true,
          shift: true,
        ): () =>
            showSpaceManager(context, c),
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () =>
            showCommandPalette(context, c),
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): () =>
            showQuickSwitcher(context, c),
        const SingleActivator(LogicalKeyboardKey.keyE, control: true): () =>
            showQuickSwitcher(context, c),
        const SingleActivator(LogicalKeyboardKey.slash, control: true): () =>
            showShortcutsCheatsheet(context),
        const SingleActivator(LogicalKeyboardKey.f11): () =>
            c.updateSession((s) => s.focusMode = !s.focusMode),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            c.create('orbit.note'),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            c.flushAll(),
        const SingleActivator(LogicalKeyboardKey.keyW, control: true): () {
          if (_targetSecondary && c.session.secondaryId != null) {
            _closeSecondaryPane();
          } else if (c.session.activeId != null) {
            c.closeTab(c.session.activeId!);
            _focusPaneEditor();
          }
        },
        const SingleActivator(LogicalKeyboardKey.tab, control: true): () =>
            _cycleFocusedTab(),
        const SingleActivator(
          LogicalKeyboardKey.tab,
          control: true,
          shift: true,
        ): () =>
            _cycleFocusedTab(reverse: true),
        const SingleActivator(
          LogicalKeyboardKey.keyT,
          control: true,
          shift: true,
        ): () =>
            c.reopenClosedTab(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () =>
            c.navigateBack(),
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): () =>
            c.navigateForward(),
        const SingleActivator(
          LogicalKeyboardKey.keyB,
          control: true,
          shift: true,
        ): () =>
            c.updateSession((s) => s.sidebarVisible = !s.sidebarVisible),
        const SingleActivator(
          LogicalKeyboardKey.keyD,
          control: true,
          shift: true,
        ): () {
          if (c.session.activeId != null) {
            c.toggleBookmark(c.session.activeId!);
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Listener(
          onPointerDown: (event) {
            if (event.buttons == 8) {
              if (c.canNavigateBack) c.navigateBack();
            } else if (event.buttons == 16) {
              if (c.canNavigateForward) c.navigateForward();
            }
          },
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
                                  onHorizontalDragUpdate: (e) =>
                                      c.updateSession(
                                        (s) => s.sidebarWidth =
                                            (s.sidebarWidth + e.delta.dx).clamp(
                                              180,
                                              380,
                                            ),
                                      ),
                                  child: Container(
                                    width: 4,
                                    color: colors.panel,
                                  ),
                                ),
                              ),
                            ],
                            Expanded(
                              child: Column(
                                children: [
                                  header(wide: wide, sidebar: sidebar),
                                  if (!c.session.focusMode)
                                    ProjectContextBar(controller: c),
                                  if (c.error != null)
                                    errorBanner(
                                      c.error!,
                                      () => c.updateSession(
                                        (_) => c.error = null,
                                      ),
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
                                      key: const ValueKey(
                                        'content-drop-target',
                                      ),
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
                                        child: OrbitContentTransition(
                                          identity: (
                                            c.session.destination,
                                            c.session.activeId,
                                          ),
                                          child: content(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (inspector)
                              SizedBox(
                                width: 300,
                                child: OrbitEntrance(
                                  spatial: true,
                                  offset: const Offset(6, 0),
                                  child: inspectorView(),
                                ),
                              ),
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
      decoration: BoxDecoration(
        color: colors.panel,
        border: Border(right: BorderSide(color: colors.divider)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Tooltip(
                      message: 'Orbit Note',
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: colors.panel,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(16),
                          ),
                          border: Border.all(color: colors.border),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.blur_circular,
                              color: colors.accent,
                              size: 25,
                            ),
                            Image.asset(
                              'assets/logo.png',
                              width: 32,
                              height: 32,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ...destinations.take(5).map((d) => railButton(d)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: OrbitControl(
                      key: const ValueKey('rail-bookshelf-button'),
                      tooltip: 'Bookshelf & Reading Rooms',
                      icon: Icons.local_library_outlined,
                      onPressed: _openBookshelf,
                    ),
                  ),
                  const Spacer(),
                  railButton(destinations[5]),
                  railButton(destinations[6]),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
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
    final colors = OrbitColors.of(context);
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          left: 0,
          child: AnimatedContainer(
            duration: OrbitMotionScope.duration(context, OrbitMotion.panel),
            curve: OrbitMotion.ease,
            width: 3,
            height: selected ? 22 : 0,
            decoration: BoxDecoration(
              color: selected ? colors.accent : Colors.transparent,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(3),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: OrbitControl(
            tooltip: d.label,
            icon: d.icon,
            selected: selected,
            onPressed: () => c.navigate(d.destination),
          ),
        ),
      ],
    );
  }

  void _openBookshelf() {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog.fullscreen(
        child: OrbitLibraryView(
          controller: c,
          onOpenBook: (bookId, {roomId}) {
            if (roomId != null) c.updateProperty(bookId, 'lastRoomId', roomId);
            Navigator.pop(context);
            c.openObject(bookId);
          },
          onImportPdf: () => pickAndOpenPdf(),
        ),
      ),
    );
  }

  IconData _objectIconFor(UniversalObject o) {
    if (o.typeId == 'orbit.file') {
      final mime = o.properties['mimeType'] as String? ?? '';
      final title = o.title.toLowerCase();
      if (mime == 'application/pdf' || title.endsWith('.pdf')) {
        return Icons.picture_as_pdf_outlined;
      }
      if (mime.startsWith('image/') ||
          ['png', 'jpg', 'jpeg', 'webp', 'gif', 'svg'].any(title.endsWith)) {
        return Icons.image_outlined;
      }
      if (isModelAsset(o.properties['originalName'] as String? ?? o.title)) {
        return Icons.view_in_ar_outlined;
      }
      return Icons.attach_file;
    }
    return objectIcon(o.typeId);
  }

  Widget _newObjectMenu() => PopupMenuButton<String>(
    key: const ValueKey('explorer-new-menu'),
    tooltip: 'New or import',
    onSelected: (value) {
      switch (value) {
        case 'pdf':
          pickAndOpenPdf();
        case 'bookshelf':
          _openBookshelf();
        case 'image':
          pickAndOpenImage();
        case 'code':
          pickAndOpenCode();
        case 'model':
          pickAndOpenModel();
        case 'courses':
          showCourseHub(context, c);
        case 'import':
          pickAndImportFile();
        default:
          c.create(value);
      }
    },
    itemBuilder: (_) => [
      for (final item in <(String, IconData, String)>[
        ('orbit.note', Icons.note_add_outlined, 'Note'),
        ('orbit.canvas', Icons.dashboard_outlined, 'Canvas'),
        ('orbit.task', Icons.check_circle_outline, 'Task'),
        ('orbit.event', Icons.event_outlined, 'Event'),
        ('pdf', Icons.picture_as_pdf_outlined, 'Open PDF'),
        (
          'bookshelf',
          Icons.local_library_outlined,
          'Bookshelf & Reading Rooms',
        ),
        ('image', Icons.image_outlined, 'Open image'),
        ('code', Icons.code_outlined, 'Open code file'),
        ('model', Icons.view_in_ar_outlined, 'Open 3D model (OBJ / GLB)'),
        ('courses', Icons.school_outlined, 'Courses & study progress'),
        ('import', Icons.file_upload_outlined, 'Import file'),
      ])
        PopupMenuItem(
          value: item.$1,
          child: Row(
            children: [
              Icon(item.$2, size: 17),
              const SizedBox(width: 12),
              Flexible(child: Text(item.$3)),
            ],
          ),
        ),
    ],
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 17),
          SizedBox(width: 8),
          Text('New'),
          SizedBox(width: 8),
          Icon(Icons.expand_more, size: 16),
        ],
      ),
    ),
  );

  Widget explorer() {
    final colors = OrbitColors.of(context), destination = c.session.destination;
    final type = destination == OrbitDestination.canvas
        ? 'orbit.canvas'
        : destination == OrbitDestination.tasks
        ? 'orbit.task'
        : destination == OrbitDestination.calendar
        ? 'orbit.event'
        : 'orbit.note';

    final List<UniversalObject> objects;
    if (destination == OrbitDestination.trash) {
      objects = c.objects.where((o) => o.isDeleted).toList();
    } else {
      switch (explorerTypeFilter) {
        case 'notes':
          objects = c.ofType('orbit.note');
        case 'canvases':
          objects = c.ofType('orbit.canvas');
        case 'pdfs':
          objects = c.activeObjects
              .where(
                (o) =>
                    !o.isDeleted &&
                    o.typeId == 'orbit.file' &&
                    (o.properties['mimeType'] == 'application/pdf' ||
                        o.title.toLowerCase().endsWith('.pdf')),
              )
              .toList();
        case 'images':
          objects = c.activeObjects
              .where(
                (o) =>
                    !o.isDeleted &&
                    o.typeId == 'orbit.file' &&
                    ((o.properties['mimeType'] as String? ?? '').startsWith(
                          'image/',
                        ) ||
                        [
                          'png',
                          'jpg',
                          'jpeg',
                          'webp',
                          'gif',
                          'svg',
                        ].any(o.title.toLowerCase().endsWith)),
              )
              .toList();
        case 'tasks':
          objects = c.ofType('orbit.task');
        case 'all':
          objects = c.activeObjects
              .where(
                (o) =>
                    !o.isDeleted &&
                    (o.typeId == 'orbit.note' ||
                        o.typeId == 'orbit.canvas' ||
                        o.typeId == 'orbit.file' ||
                        o.typeId == 'orbit.task' ||
                        o.typeId == 'orbit.event' ||
                        o.typeId == 'orbit.view'),
              )
              .toList();
        default:
          objects = c.ofType(type);
      }
    }

    if (destination != OrbitDestination.trash) {
      objects.removeWhere((o) => !c.inActiveSpace(o));
    }
    if (c.activeTagFilter != null && c.activeTagFilter!.isNotEmpty) {
      final tag = c.activeTagFilter!.toLowerCase();
      objects.removeWhere((o) {
        final tags = (o.properties['tags'] is List)
            ? (o.properties['tags'] as List)
                  .map(
                    (e) => e
                        .toString()
                        .trim()
                        .replaceAll(RegExp(r'^#'), '')
                        .toLowerCase(),
                  )
                  .toSet()
            : <String>{};
        if (tags.contains(tag)) return false;
        final pattern = RegExp(
          r'(?:^|\s)#' + RegExp.escape(tag) + r'(?:\s|$)',
          caseSensitive: false,
        );
        return !pattern.hasMatch(o.body);
      });
    }

    if (explorerFilter.trim().isNotEmpty) {
      final query = explorerFilter.trim().toLowerCase();
      objects.removeWhere((o) {
        final titleMatch = o.title.toLowerCase().contains(query);
        final bodyMatch = o.body.toLowerCase().contains(query);
        final pathMatch = (o.properties['contentRef'] as String? ?? '')
            .toLowerCase()
            .contains(query);
        return !titleMatch && !bodyMatch && !pathMatch;
      });
    }

    sortObjects(objects, c.session.noteSort);

    final label = destination == OrbitDestination.trash
        ? 'TRASH'
        : explorerTypeFilter == 'all'
        ? 'ALL ITEMS'
        : explorerTypeFilter == 'pdfs'
        ? 'PDFS'
        : explorerTypeFilter == 'images'
        ? 'IMAGES'
        : explorerTypeFilter == 'canvases'
        ? 'CANVASES'
        : explorerTypeFilter == 'tasks'
        ? 'TASKS'
        : explorerTypeFilter == 'notes'
        ? 'NOTES'
        : destination == OrbitDestination.canvas
        ? 'CANVASES'
        : destination == OrbitDestination.tasks
        ? 'TASKS'
        : destination == OrbitDestination.calendar
        ? 'EVENTS'
        : destination == OrbitDestination.graph
        ? 'GRAPH'
        : 'NOTES';

    return DropTarget(
      key: const ValueKey('explorer-drop-target'),
      onDragDone: (details) => dropFiles(details, forceToVault: true),
      onDragEntered: (_) => setState(() => explorerDropping = true),
      onDragExited: (_) => setState(() => explorerDropping = false),
      child: AnimatedContainer(
        duration: OrbitMotionScope.duration(context, OrbitMotion.control),
        decoration: BoxDecoration(
          color: colors.panel,
          border: explorerDropping
              ? Border.all(color: colors.accent, width: 2)
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (explorerDropping)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  color: colors.accent.withValues(alpha: 0.18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.file_download_outlined,
                        size: 16,
                        color: colors.accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Drop files to import into Vault',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 12, 12),
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
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.subtle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (destination != OrbitDestination.trash)
                ExplorerMiniCalendar(controller: c),
              // Creation and import share one menu to keep the tree prominent.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _newObjectMenu(),
                      IconButton(
                        tooltip: 'Open code workspace (HTML / Python / C++)',
                        onPressed: () => showCodeIde(context, controller: c),
                        icon: const Icon(
                          Icons.developer_mode_outlined,
                          size: 19,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Open code file',
                        onPressed: pickAndOpenCode,
                        icon: const Icon(Icons.code_outlined, size: 19),
                      ),
                      IconButton(
                        tooltip: 'Open 3D model (OBJ / GLB)',
                        onPressed: pickAndOpenModel,
                        icon: const Icon(Icons.view_in_ar_outlined, size: 19),
                      ),
                      IconButton(
                        tooltip: 'Courses & study progress',
                        onPressed: () => showCourseHub(context, c),
                        icon: const Icon(Icons.school_outlined, size: 19),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: OutlinedButton(
                  onPressed: () => showCommandPalette(context, c),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Find anything',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(4),
                          ),
                          color: colors.raised,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 3,
                          ),
                          child: Text('Ctrl P', style: TextStyle(fontSize: 10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Section Header Row
              Padding(
                padding: const EdgeInsets.only(left: 18, right: 8),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        '$label · ${objects.length}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: .3,
                          color: colors.subtle,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (destination == OrbitDestination.notes)
                      IconButton(
                        tooltip: c.showAttachments
                            ? 'Hide files & PDFs'
                            : 'Show files & PDFs',
                        onPressed: c.toggleShowAttachments,
                        icon: Icon(
                          c.showAttachments
                              ? Icons.attachment
                              : Icons.attachment_outlined,
                          size: 16,
                          color: c.showAttachments
                              ? colors.accent
                              : colors.subtle,
                        ),
                        constraints: const BoxConstraints.tightFor(
                          width: 28,
                          height: 28,
                        ),
                        padding: EdgeInsets.zero,
                        splashRadius: 16,
                      ),
                    if (destination == OrbitDestination.trash)
                      TextButton.icon(
                        onPressed: objects.isEmpty
                            ? null
                            : () async {
                                final generation = c.workspaceGeneration,
                                    workspace = c.repository.workspaceId;
                                final reviewed = {
                                  for (final o in objects.where(
                                    (o) => o.isDeleted,
                                  ))
                                    o.id: o,
                                };
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => OrbitDialog(
                                    title: const Text('Empty Trash'),
                                    content: const Text(
                                      'Permanently delete all items in Trash? This cannot be undone.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Empty Trash'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true &&
                                    _captureStillCurrent(
                                      generation,
                                      workspace,
                                    ) &&
                                    reviewed.values.every(
                                      (o) => identical(c.find(o.id), o),
                                    ) &&
                                    c.objects
                                            .where((o) => o.isDeleted)
                                            .length ==
                                        reviewed.length) {
                                  await c.emptyTrash();
                                }
                              },
                        icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                        label: const Text(
                          'Empty',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    if (destination != OrbitDestination.trash)
                      IconButton(
                        tooltip: 'Create ${type.replaceFirst('orbit.', '')}',
                        onPressed: () => c.create(type),
                        icon: const Icon(Icons.add, size: 17),
                        constraints: const BoxConstraints.tightFor(
                          width: 28,
                          height: 28,
                        ),
                        padding: EdgeInsets.zero,
                        splashRadius: 16,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('explorer-filter'),
                        decoration: InputDecoration(
                          hintText: 'Filter titles & content',
                          isDense: true,
                          suffixIcon: explorerFilter.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 14),
                                  tooltip: 'Clear filter',
                                  onPressed: () =>
                                      setState(() => explorerFilter = ''),
                                )
                              : null,
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
                            (e) => PopupMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              // A compact filter menu replaces the permanent chip strip.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    PopupMenuButton<String>(
                      key: const ValueKey('explorer-type-menu'),
                      tooltip: 'Filter by type',
                      initialValue: explorerTypeFilter,
                      onSelected: (value) =>
                          setState(() => explorerTypeFilter = value),
                      itemBuilder: (_) => [
                        for (final item in const {
                          'all': 'All items',
                          'notes': 'Notes',
                          'canvases': 'Canvases',
                          'pdfs': 'PDFs',
                          'images': 'Images',
                          'tasks': 'Tasks',
                        }.entries)
                          PopupMenuItem(
                            key: ValueKey('filter-chip-${item.key}'),
                            value: item.key,
                            child: Row(
                              children: [
                                Icon(
                                  explorerTypeFilter == item.key
                                      ? Icons.check
                                      : null,
                                  size: 17,
                                ),
                                const SizedBox(width: 12),
                                Text(item.value),
                              ],
                            ),
                          ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.filter_list, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              explorerTypeFilter == 'all'
                                  ? 'All items'
                                  : '${explorerTypeFilter[0].toUpperCase()}${explorerTypeFilter.substring(1)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.expand_more, size: 16),
                          ],
                        ),
                      ),
                    ),
                    if ((explorerTypeFilter == 'notes' ||
                            destination == OrbitDestination.notes) &&
                        destination != OrbitDestination.trash &&
                        c.repository.supportsFolders)
                      IconButton(
                        key: const ValueKey('explorer-collapse-expand-all'),
                        visualDensity: VisualDensity.compact,
                        iconSize: 16,
                        tooltip: c.areAllFoldersCollapsed
                            ? 'Expand all folders (Ctrl+Shift+E)'
                            : 'Collapse all folders (Ctrl+Shift+E)',
                        icon: Icon(
                          c.areAllFoldersCollapsed
                              ? Icons.unfold_more_rounded
                              : Icons.unfold_less_rounded,
                          color: colors.subtle,
                        ),
                        onPressed: () {
                          if (c.areAllFoldersCollapsed) {
                            c.expandAllFolders();
                          } else {
                            c.collapseAllFolders();
                          }
                        },
                      ),
                    PopupMenuButton<String>(
                      key: const ValueKey('explorer-tag-filter-button'),
                      tooltip: 'Filter by tag…',
                      icon: Icon(
                        c.activeTagFilter != null
                            ? Icons.label_rounded
                            : Icons.label_outline_rounded,
                        size: 16,
                        color: c.activeTagFilter != null
                            ? colors.accent
                            : colors.subtle,
                      ),
                      onSelected: (tag) {
                        if (tag == '__clear__') {
                          c.clearTagFilter();
                        } else {
                          c.activeTagFilter = tag;
                        }
                      },
                      itemBuilder: (_) => [
                        if (c.activeTagFilter != null)
                          const PopupMenuItem(
                            value: '__clear__',
                            child: Row(
                              children: [
                                Icon(Icons.close_rounded, size: 16),
                                SizedBox(width: 8),
                                Text('Clear tag filter'),
                              ],
                            ),
                          ),
                        if (c.allTags.isEmpty)
                          const PopupMenuItem(
                            enabled: false,
                            value: '',
                            child: Text('No tags found in vault'),
                          )
                        else
                          for (final tag in c.allTags)
                            PopupMenuItem(
                              key: ValueKey('tag-menu-item-$tag'),
                              value: tag,
                              child: Row(
                                children: [
                                  Icon(
                                    c.activeTagFilter == tag
                                        ? Icons.check
                                        : Icons.label_outlined,
                                    size: 16,
                                    color: c.activeTagFilter == tag
                                        ? colors.accent
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('#$tag')),
                                  Text(
                                    '${c.countForTag(tag)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ],
                ),
              ),
              if (c.activeTagFilter != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: colors.accent.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.label_rounded,
                                size: 12,
                                color: colors.accent,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '#${c.activeTagFilter}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: colors.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        key: const ValueKey('clear-active-tag-filter'),
                        onTap: () => c.clearTagFilter(),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: colors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child:
                    (destination == OrbitDestination.notes ||
                            explorerTypeFilter == 'notes') &&
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
                              : 'No matching items in Vault.',
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
                            child: OrbitHoverRegion(
                              builder: (context, reveal) => ListTile(
                                dense: true,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                selected: c.session.activeId == o.id,
                                selectedTileColor: colors.hover,
                                leading: Icon(_objectIconFor(o), size: 16),
                                minLeadingWidth: 16,
                                title: Text(
                                  o.title.isEmpty ? 'Untitled' : o.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onTap: () => c.openObject(o.id),
                                trailing: Opacity(
                                  opacity: reveal || c.session.activeId == o.id
                                      ? 1
                                      : 0,
                                  child: PopupMenuButton<String>(
                                    tooltip: 'Object actions',
                                    icon: const Icon(
                                      Icons.more_horiz,
                                      size: 16,
                                    ),
                                    onSelected: (v) async {
                                      if (!identical(c.find(o.id), o)) return;
                                      final generation = c.workspaceGeneration,
                                          workspace = c.repository.workspaceId;
                                      if (v == 'trash') {
                                        c.trash(o.id, expected: o);
                                      }
                                      if (v == 'restore') {
                                        c.restore(o.id, expected: o);
                                      }
                                      if (v == 'delete_forever') {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => OrbitDialog(
                                            title: const Text(
                                              'Delete permanently',
                                            ),
                                            content: Text(
                                              'Permanently delete “${o.title.isEmpty ? 'Untitled' : o.title}”? This cannot be undone.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('Cancel'),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed == true &&
                                            _captureStillCurrent(
                                              generation,
                                              workspace,
                                            )) {
                                          await c.deletePermanently(
                                            o.id,
                                            expected: o,
                                          );
                                        }
                                      }
                                      if (v == 'rename') {
                                        renameObject(o);
                                      }
                                      if (v == 'split') {
                                        c.openObject(o.id, secondary: true);
                                      }
                                      if (v == 'reveal') {
                                        revealObjectInExplorer(o.id);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      if (!o.isDeleted) ...[
                                        const PopupMenuItem(
                                          value: 'rename',
                                          child: Text('Rename'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'split',
                                          child: Text('Open beside'),
                                        ),
                                        if (c.repository.objectPath(o.id) !=
                                                null &&
                                            !kIsWeb)
                                          const PopupMenuItem(
                                            value: 'reveal',
                                            child: Text(
                                              'Reveal in File Explorer',
                                            ),
                                          ),
                                        const PopupMenuItem(
                                          value: 'trash',
                                          child: Text('Move to Trash'),
                                        ),
                                      ] else ...[
                                        const PopupMenuItem(
                                          value: 'restore',
                                          child: Text('Restore'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete_forever',
                                          child: Text('Delete permanently'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              _buildVaultSwitcherFooter(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVaultSwitcherFooter(OrbitColors colors) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: colors.panel,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message:
                  '${c.repository.name}\n${c.activeObjects.length} objects · Click to switch vault',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(OrbitRadius.control),
                  onTap: switchVault,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.unfold_more, size: 18, color: colors.subtle),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            c.repository.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Help & shortcuts · Ctrl+/',
            icon: Icon(Icons.help_outline, size: 18, color: colors.subtle),
            splashRadius: 18,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
            onPressed: () => showShortcutsCheatsheet(context),
          ),
          IconButton(
            tooltip: 'Spaces & layouts · Ctrl+Shift+Space',
            icon: Icon(
              Icons.workspaces_outline,
              size: 18,
              color: colors.subtle,
            ),
            onPressed: () => showSpaceManager(context, c),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: Icon(Icons.settings_outlined, size: 18, color: colors.subtle),
            splashRadius: 18,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
            onPressed: () => c.navigate(OrbitDestination.settings),
          ),
        ],
      ),
    );
  }

  Widget header({required bool wide, required bool sidebar}) {
    final colors = OrbitColors.of(context);
    final compactHeader =
        MediaQuery.sizeOf(context).width < 520 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.35;
    final destinationLabel = destinations
        .firstWhere((d) => d.destination == c.session.destination)
        .label;
    final activeObject = c.find(c.session.activeId);
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: colors.workspace,
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            if (wide && !sidebar)
              Tooltip(
                message: 'Switch Vault',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: TextButton.icon(
                    onPressed: switchVault,
                    icon: const Icon(Icons.folder_special_outlined, size: 18),
                    label: Text(
                      c.repository.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
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
            if (!compactHeader) ...[
              GestureDetector(
                onSecondaryTapDown: (details) {
                  if (c.canNavigateBack) {
                    _showNavigationHistoryMenu(
                      context,
                      details.globalPosition,
                      isBack: true,
                    );
                  }
                },
                onLongPressStart: (details) {
                  if (c.canNavigateBack) {
                    _showNavigationHistoryMenu(
                      context,
                      details.globalPosition,
                      isBack: true,
                    );
                  }
                },
                child: IconButton(
                  key: const ValueKey('nav-back-button'),
                  tooltip: c.canNavigateBack
                      ? 'Back (Alt+Left) · Right-click for history'
                      : 'Back (Alt+Left)',
                  onPressed: c.canNavigateBack ? c.navigateBack : null,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  splashRadius: 16,
                ),
              ),
              GestureDetector(
                onSecondaryTapDown: (details) {
                  if (c.canNavigateForward) {
                    _showNavigationHistoryMenu(
                      context,
                      details.globalPosition,
                      isBack: false,
                    );
                  }
                },
                onLongPressStart: (details) {
                  if (c.canNavigateForward) {
                    _showNavigationHistoryMenu(
                      context,
                      details.globalPosition,
                      isBack: false,
                    );
                  }
                },
                child: IconButton(
                  key: const ValueKey('nav-forward-button'),
                  tooltip: c.canNavigateForward
                      ? 'Forward (Alt+Right) · Right-click for history'
                      : 'Forward (Alt+Right)',
                  onPressed: c.canNavigateForward ? c.navigateForward : null,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  splashRadius: 16,
                ),
              ),
            ],
            const SizedBox(width: 4),
            Expanded(
              child: Row(
                children: [
                  Text(
                    destinationLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                  if (activeObject != null && !compactHeader) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '/',
                        style: TextStyle(color: colors.muted, fontSize: 13),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        activeObject.title.isEmpty
                            ? 'Untitled'
                            : activeObject.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: colors.subtle),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Open & Import Files',
              icon: const Icon(Icons.add_circle_outline, size: 19),
              onSelected: (value) async {
                switch (value) {
                  case 'new_note':
                    await c.create('orbit.note', title: 'Untitled Note');
                    break;
                  case 'new_template':
                    if (!context.mounted) return;
                    final template = await NoteTemplateDialog.show(context);
                    if (template != null) {
                      await c.create(
                        'orbit.note',
                        title: template.defaultTitle,
                        body: template.body,
                        properties: {
                          if (template.tags.isNotEmpty) 'tags': template.tags,
                        },
                      );
                    }
                    break;
                  case 'new_latex':
                    if (!context.mounted) return;
                    final template = await LatexTemplateDialog.show(context);
                    if (template != null) {
                      await c.create(
                        'orbit.note',
                        title: template.name,
                        body: template.body,
                        properties: {'documentFormat': 'latex'},
                      );
                    }
                    break;
                  case 'new_canvas':
                    await c.create('orbit.canvas', title: 'Untitled Canvas');
                    break;
                  case 'open_pdf':
                    await pickAndOpenPdf();
                    break;
                  case 'open_image':
                    await pickAndOpenImage();
                    break;
                  case 'open_code':
                    await pickAndOpenCode();
                    break;
                  case 'open_model':
                    await pickAndOpenModel();
                    break;
                  case 'courses':
                    await showCourseHub(context, c);
                    break;
                  case 'import_file':
                    await pickAndImportFile();
                    break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'new_note',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.note_add_outlined, size: 18),
                      SizedBox(width: 8),
                      Flexible(child: Text('New Note')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  key: ValueKey('new-note-from-template'),
                  value: 'new_template',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_stories_outlined, size: 18),
                      SizedBox(width: 8),
                      Flexible(child: Text('New Note from Template…')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'new_latex',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.functions_rounded,
                        size: 18,
                        color: Color(0xFF8B7CF6),
                      ),
                      SizedBox(width: 8),
                      Flexible(child: Text('New LaTeX Document')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'new_canvas',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.dashboard_customize_outlined, size: 18),
                      SizedBox(width: 8),
                      Flexible(child: Text('New Canvas')),
                    ],
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'open_pdf',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                      SizedBox(width: 8),
                      Flexible(child: Text('Open PDF…')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'open_image',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        size: 18,
                        color: Colors.purpleAccent,
                      ),
                      SizedBox(width: 8),
                      Flexible(child: Text('Open Image…')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'open_code',
                  child: Text('Open code file…'),
                ),
                PopupMenuItem(
                  value: 'open_model',
                  child: Text('Open 3D model (OBJ / GLB)…'),
                ),
                PopupMenuItem(
                  value: 'courses',
                  child: Text('Courses & study progress…'),
                ),
                PopupMenuItem(
                  value: 'import_file',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.file_upload_outlined,
                        size: 18,
                        color: Colors.tealAccent,
                      ),
                      SizedBox(width: 8),
                      Flexible(child: Text('Import File…')),
                    ],
                  ),
                ),
              ],
            ),
            if (c.editorDraftConflicts.isNotEmpty)
              IconButton(
                tooltip: 'Review conflicting editor drafts',
                onPressed: () => showEditorDraftReview(context, c),
                icon: const Icon(Icons.warning_amber_outlined),
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
                  c.session.focusMode
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen,
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
                  PopupMenuItem(
                    value: 'horizontal',
                    child: Text('Split right'),
                  ),
                  PopupMenuItem(value: 'vertical', child: Text('Split down')),
                ],
              ),
            if (wide)
              IconButton(
                tooltip: 'Toggle explorer',
                onPressed: () => c.updateSession(
                  (s) => s.sidebarVisible = !s.sidebarVisible,
                ),
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
  }

  Future<void> _showNavigationHistoryMenu(
    BuildContext context,
    Offset position, {
    required bool isBack,
  }) async {
    final history = isBack ? c.backHistory : c.forwardHistory;
    if (history.isEmpty) return;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final selectedId = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        for (final obj in history)
          PopupMenuItem<String>(
            value: obj.id,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_objectIconFor(obj), size: 16),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Text(
                    obj.title.isEmpty ? 'Untitled' : obj.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if ((obj.properties['folder'] as String?)?.isNotEmpty ??
                    false) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(${obj.properties['folder']})',
                    style: TextStyle(
                      fontSize: 11,
                      color: OrbitColors.of(context).muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
    if (selectedId != null && mounted) {
      c.jumpToHistoryObject(selectedId);
    }
  }

  Future<void> _showTabContextMenu(
    BuildContext context,
    String id,
    Offset globalPosition,
  ) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final object = c.find(id);
    final tabIndex = c.session.tabs.indexOf(id);
    final hasTabsToRight =
        tabIndex >= 0 && tabIndex < c.session.tabs.length - 1;
    final hasOtherTabs = c.session.tabs.length > 1;
    final relPath = c.repository.objectPath(id);
    final canReveal = relPath != null && !kIsWeb;
    final isPinned = c.isPinned(id);
    final isBookmarked = c.isBookmarked(id);

    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: 'bookmark',
          child: Row(
            children: [
              Icon(
                isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                size: 16,
                color: isBookmarked ? const Color(0xFFF59E0B) : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(isBookmarked ? 'Remove Bookmark' : 'Bookmark Tab'),
              ),
              const SizedBox(width: 12),
              const Text(
                'Ctrl+Shift+D',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: isPinned ? 'unpin' : 'pin',
          child: Row(
            children: [
              Icon(
                isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(isPinned ? 'Unpin Tab' : 'Pin Tab'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'close',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Close Tab'),
              SizedBox(width: 16),
              Text(
                'Ctrl+W',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        if (hasOtherTabs)
          const PopupMenuItem(
            value: 'close_others',
            child: Text('Close Other Tabs'),
          ),
        if (hasTabsToRight)
          const PopupMenuItem(
            value: 'close_right',
            child: Text('Close Tabs to the Right'),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'copy_ref', child: Text('Copy Reference')),
        PopupMenuItem(
          value: 'duplicate_tab',
          child: const Row(
            children: [
              Icon(Icons.copy_rounded, size: 16),
              SizedBox(width: 8),
              Text('Duplicate Tab'),
            ],
          ),
        ),
        if (canReveal)
          const PopupMenuItem(
            value: 'reveal',
            child: Text('Reveal in File Explorer'),
          ),
      ],
    );

    if (action == null || !mounted) return;
    switch (action) {
      case 'duplicate_tab':
        await c.duplicateObject(id);
      case 'bookmark':
        c.toggleBookmark(id);
      case 'pin':
        c.pinTab(id);
      case 'unpin':
        c.unpinTab(id);
      case 'close':
        c.closeTab(id);
      case 'close_others':
        c.closeOtherTabs(id);
      case 'close_right':
        c.closeTabsToTheRight(id);
      case 'copy_ref':
        if (object != null) {
          await Clipboard.setData(
            ClipboardData(
              text: ObjectReference(object.id).markdown(object.title),
            ),
          );
          if (context.mounted) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(
                content: Text(
                  'Copied reference to "${object.title.isEmpty ? 'Untitled' : object.title}" to clipboard',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      case 'reveal':
        revealObjectInExplorer(id);
    }
  }

  Future<void> _showEmptyTabBarContextMenu(
    BuildContext context,
    Offset globalPosition,
  ) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final canReopen = c.session.closedTabs.isNotEmpty || c.lastClosed != null;

    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          enabled: canReopen,
          value: 'reopen',
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Reopen Closed Tab'),
              SizedBox(width: 16),
              Text(
                'Ctrl+Shift+T',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        const PopupMenuItem(value: 'new_note', child: Text('New Note')),
        const PopupMenuItem(
          value: 'new_template',
          child: Text('New Note from Template…'),
        ),
        const PopupMenuItem(
          value: 'new_latex',
          child: Text('New LaTeX Document'),
        ),
      ],
    );

    if (action == null || !mounted) return;
    if (action == 'reopen') {
      c.reopenClosedTab();
    } else if (action == 'new_note') {
      c.create('orbit.note');
    } else if (action == 'new_template') {
      if (!context.mounted) return;
      final template = await NoteTemplateDialog.show(context);
      if (template != null) {
        await c.create(
          'orbit.note',
          title: template.defaultTitle,
          body: template.body,
          properties: {if (template.tags.isNotEmpty) 'tags': template.tags},
        );
      }
    } else if (action == 'new_latex') {
      if (!context.mounted) return;
      final template = await LatexTemplateDialog.show(context);
      if (template != null) {
        await c.create(
          'orbit.note',
          title: template.name,
          body: template.body,
          properties: {'documentFormat': 'latex'},
        );
      }
    }
  }

  Widget tabs() {
    final colors = OrbitColors.of(context);
    return SizedBox(
      height: OrbitDensity.of(context).controlHeight + 10,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onSecondaryTapDown: (details) =>
                  _showEmptyTabBarContextMenu(context, details.globalPosition),
              child: OrbitTabStrip(
                controller: c,
                onActivate: (id) {
                  _secondaryFocused = false;
                  c.openObject(id);
                  _focusPaneEditor();
                },
                onContextMenu: (id, position) =>
                    _showTabContextMenu(context, id, position),
              ),
            ),
          ),
          FocusTimerMiniButton(controller: globalFocusTimer),
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: IconButton(
              key: const ValueKey('quick-switcher-button'),
              tooltip: 'Quick switcher (Ctrl+O)',
              icon: const Icon(Icons.flash_on_outlined, size: 16),
              onPressed: () => showQuickSwitcher(context, c),
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              padding: EdgeInsets.zero,
              splashRadius: 14,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: IconButton(
              key: const ValueKey('new-tab-button'),
              tooltip: 'New note (Ctrl+N)',
              icon: const Icon(Icons.add, size: 16),
              onPressed: () => c.create('orbit.note'),
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              padding: EdgeInsets.zero,
              splashRadius: 14,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PopupMenuButton<String>(
              key: const ValueKey('workspace-bookmarks-button'),
              tooltip: 'Bookmarked tabs & notes',
              icon: Icon(
                c.session.bookmarkedTabs.isNotEmpty
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                size: 16,
                color: c.session.bookmarkedTabs.isNotEmpty
                    ? const Color(0xFFF59E0B)
                    : colors.subtle,
              ),
              constraints: const BoxConstraints(minWidth: 180, maxWidth: 280),
              padding: EdgeInsets.zero,
              splashRadius: 14,
              onSelected: (id) => c.openObject(id),
              itemBuilder: (context) {
                final bookmarked = c.bookmarkedObjects;
                if (bookmarked.isEmpty) {
                  return const [
                    PopupMenuItem(
                      enabled: false,
                      child: Text(
                        'No bookmarked tabs',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ];
                }
                return [
                  const PopupMenuItem(
                    enabled: false,
                    child: Text(
                      'BOOKMARKED TABS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  for (final item in bookmarked)
                    PopupMenuItem(
                      value: item.id,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bookmark,
                            size: 14,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              item.title,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                ];
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget content() {
    _secondaryVisible = false;
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
            ? 'No canvas open'
            : 'No note open',
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
            (secondary.id != object.id || object.typeId == 'orbit.note') &&
            constraints.maxWidth >= 720) {
          _secondaryVisible = true;
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
                child: secondary.typeId == 'orbit.note'
                    ? objectView(secondary, pane: 'secondary')
                    : Column(
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              tooltip: 'Close split',
                              onPressed: _closeSecondaryPane,
                              icon: const Icon(Icons.close, size: 16),
                            ),
                          ),
                          Expanded(
                            child: objectView(secondary, pane: 'secondary'),
                          ),
                        ],
                      ),
              ),
            ],
          );
        }
        _secondaryFocused = false;
        return objectView(object);
      },
    );
  }

  Widget objectView(UniversalObject object, {String pane = 'primary'}) {
    final positionKey = '$pane:${object.id}';
    final otherObject = c.find(
      pane == 'primary' ? c.session.secondaryId : c.session.activeId,
    );
    final hasActiveNoteBeside =
        otherObject != null &&
        !otherObject.isDeleted &&
        otherObject.typeId == 'orbit.note';
    final hasActiveCanvasBeside =
        otherObject != null &&
        !otherObject.isDeleted &&
        otherObject.typeId == 'orbit.canvas';
    final collaboration = ref.watch(collaborationProvider);
    final content = switch (object.typeId) {
      'orbit.note' => ListenableBuilder(
        listenable: collaboration.viewerChanges,
        builder: (context, _) => NoteEditor(
          viewOnly:
              object.isReadOnly ||
              c.repository.readOnly ||
              collaboration.viewer && collaboration.shares(object.id),
          location: c.locationRequests[object.id]?.reference,
          locationSerial: c.locationRequests[object.id]?.serial ?? 0,
          locationOffset: c.locationRequests[object.id]?.offset,
          locationLength: c.locationRequests[object.id]?.length ?? 0,
          key: ValueKey('$pane:note-${object.id}:${c.studyResumeSerial}'),
          noteId: object.id,
          focusRequestSerial:
              _editorFocusGeneration == c.workspaceGeneration &&
                  _editorFocusPane == pane &&
                  _editorFocusId == object.id
              ? _editorFocusSerial
              : 0,
          editorDraftId: '$pane:${object.id}',
          controller: c,
          onClosePane: pane == 'secondary' ? _closeSecondaryPane : null,
          title: object.title,
          body: object.body,
          onTitleChanged: (v) => c.edit(object.id, title: v),
          onBodyChanged: (v) => c.edit(object.id, body: v),
          linkTargets: c.linkTargets,
          linkBindings: object.linkBindings,
          onOpenObject: openLinkedObject,
          onToggleBacklinks: () =>
              c.updateSession((s) => s.inspectorVisible = !s.inspectorVisible),
          fontSize: c.session.fontSize,
          lineHeight: c.session.editorLineHeight,
          contentWidth: c.session.contentWidth,
          onContentWidthChanged: (width) =>
              c.updateSession((s) => s.contentWidth = width),
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
          resolveClipboardImage: (raw) => Uri.tryParse(raw)?.hasScheme == true
              ? raw
              : resolveNotePath(object.id, raw),
          onInsertAttachment: () => insertAttachment(noteId: object.id),
          onPasteImage: () => pasteImage(noteId: object.id),
          onOpenAttachment: (raw) =>
              openAttachmentReference(resolveNotePath(object.id, raw)),
          onOpenExternalLink: (v) => launchUrl(Uri.parse(v)),
          onCreateTask: (title) async =>
              await c.create('orbit.task', title: title),
          icon: object.properties['icon'] as String?,
          cover: object.properties['cover'] as String?,
          onIconChanged: (v) {
            final next = Map<String, dynamic>.from(object.properties);
            if (v == null) {
              next.remove('icon');
            } else {
              next['icon'] = v;
            }
            c.edit(object.id, properties: next);
          },
          onCoverChanged: (v) {
            final next = Map<String, dynamic>.from(object.properties);
            if (v == null) {
              next.remove('cover');
            } else {
              next['cover'] = v;
            }
            c.edit(object.id, properties: next);
          },
          pdfSource: object.properties['pdfSource'] is Map
              ? Map<String, dynamic>.from(object.properties['pdfSource'] as Map)
              : null,
          fontFamily: c.session.fontFamily,
          onFontFamilyChanged: (v) => c.updateSession((s) => s.fontFamily = v),
          spellCheckEnabled: c.session.spellCheckEnabled,
          userDictionary: c.session.userDictionary,
          onToggleSpellCheck: () => c.updateSession(
            (s) => s.spellCheckEnabled = !s.spellCheckEnabled,
          ),
          onAddToUserDictionary: (word) {
            if (!c.session.userDictionary.contains(word)) {
              c.updateSession(
                (s) => s.userDictionary = [...s.userDictionary, word],
              );
            }
          },
          onOpenPdfSource: (fileId, page) {
            if (!c.openPdfSource(object.id, secondary: pane == 'primary')) {
              message('The source PDF is unavailable. This note is preserved.');
            }
          },
          documentFormat:
              object.properties['documentFormat'] as String? ?? 'markdown',
          onDocumentFormatChanged: (newFormat) {
            final next = Map<String, dynamic>.from(object.properties);
            next['documentFormat'] = newFormat;
            c.edit(object.id, properties: next);
          },
          onCreateCopy: (title, body, format) async {
            final copy = await c.create(
              'orbit.note',
              title: title,
              body: body,
              properties: {'documentFormat': format},
            );
            if (copy != null) {
              openLinkedObject(copy.id);
            }
          },
          isBookmarked: c.isBookmarked(object.id),
          onToggleBookmark: () => c.toggleBookmark(object.id),
          isFocusMode: c.session.focusMode,
          onToggleFocusMode: () =>
              c.updateSession((s) => s.focusMode = !s.focusMode),
          isPinned: c.isPinned(object.id),
          onTogglePin: () {
            if (c.isPinned(object.id)) {
              c.unpinTab(object.id);
            } else {
              c.pinTab(object.id);
            }
          },
          vaultName: c.repository.name.isNotEmpty
              ? c.repository.name
              : 'Personal Vault',
          folderPath: c.repository.objectFolder(object.id),
          allFolders: c.repository.folders,
          allObjects: c.activeObjects,
          folderLookup: (o) => c.repository.objectFolder(o.id),
          onMoveToFolder: (targetFolder) async {
            await c.moveObjectToFolder(object.id, targetFolder);
            message('Moved note to $targetFolder');
          },
          onCreateNoteInFolder: (folder) async {
            final newNote = await c.create(
              'orbit.note',
              properties: {'folder': folder},
            );
            if (newNote != null) {
              openLinkedObject(newNote.id);
            }
          },
        ),
      ),
      'orbit.canvas' => ListenableBuilder(
        listenable: collaboration,
        builder: (context, _) => CanvasEditor(
          readOnly:
              object.isReadOnly ||
              c.repository.readOnly ||
              collaboration.viewer && collaboration.shares(object.id),
          remoteCursors: collaboration.peers
              .where(
                (p) => p['objectId'] == object.id && p['space'] == 'canvas',
              )
              .toList(),
          onPresence: (x, y) =>
              collaboration.cursor(object.id, x, y, space: 'canvas'),
          captureController: _canvasCaptures.putIfAbsent(
            object.id,
            CanvasCaptureController.new,
          ),
          onCaptureReferences: () async {
            try {
              final files = await openFiles();
              await captureReferenceFiles(object.id, files);
            } catch (e) {
              message('Could not select references: $e');
            }
          },
          focusElementId:
              c.locationRequests[object.id]?.reference.anchorType == 'element'
              ? c.locationRequests[object.id]?.reference.anchorId
              : null,
          focusElementIds:
              diagramElementIds(
                c.locationRequests[object.id]?.reference ??
                    ObjectReference(object.id),
              ) ??
              const [],
          locationSerial: c.locationRequests[object.id]?.serial ?? 0,
          fontFamily: c.session.fontFamily,
          defaultBackgroundStyle: c.session.defaultCanvasGrid,
          defaultSnapToGrid: c.session.canvasSnapToGrid,
          defaultAudioSpeed: c.session.defaultAudioSpeed,
          title: object.title,
          onTitleChanged: (v) => c.edit(object.id, title: v),
          onOpenExternal: (uri) => launchUrl(uri),
          onOpenAttachment: (ref) =>
              openOriginalReference(ref, p.posix.basename(ref)),
          key: ValueKey('$pane:${object.id}:${c.studyResumeSerial}'),
          imageLoader: c.repository.readAttachment,
          imageRevision: c.attachmentRevision,
          onInsertImage: selectCanvasImage,
          onPasteImage: pasteCanvasImage,
          canvasId: object.id,
          data: {
            ...(c.editorDraftConflicts['$pane:canvas:${object.id}']?.data ??
                object.data),
            if (object.properties['canvasPreset'] != null)
              'canvasPreset': object.properties['canvasPreset'],
            if (object.properties['backgroundStyle'] != null)
              'backgroundStyle': object.properties['backgroundStyle'],
          },
          onChanged: (v) => c.edit(object.id, data: v),
          draftBaseData: object.data,
          retainConflictingDraft: c.editorDraftConflicts.containsKey(
            '$pane:canvas:${object.id}',
          ),
          onDraftChanged: (base, next) => c.publishCanvasDraft(
            '$pane:canvas:${object.id}',
            object.id,
            base,
            next,
          ),
          objects: c.activeObjects
              .where((o) => o.id != object.id)
              .map(
                (o) => CanvasObjectReference(
                  id: o.id,
                  title: o.title,
                  typeId: o.typeId,
                  body: o.body,
                  properties: o.properties,
                  viewMemberIds:
                      o.typeId == 'orbit.view' &&
                          o.properties['smartQuery'] != null &&
                          c.queryViewIssue(o) == null
                      ? c.queryViewObjects(o).map((row) => row.id).toList()
                      : null,
                  viewQueryIssue:
                      o.typeId == 'orbit.view' &&
                          o.properties['smartQuery'] != null
                      ? c.queryViewIssue(o)
                      : null,
                ),
              )
              .toList(),
          onOpenObject: openLinkedObject,
          onPickReference: () async {
            final picked = await showObjectReferencePicker(
              context,
              c,
              title: 'Place a live object',
              exclude: object.id,
            );
            return picked == null ? null : ObjectReference(picked.id);
          },
          onShowObjectConnections: (id) =>
              showObjectConnections(context, c, id),
          onToggleTask: (taskId) {
            final task = c.find(taskId);
            if (task != null) {
              final isDone =
                  task.isCompleted || task.properties['status'] == 'done';
              c.edit(
                taskId,
                properties: {
                  ...task.properties,
                  'completed': !isDone,
                  'status': !isDone ? 'done' : 'open',
                  'completedAt': !isDone
                      ? DateTime.now().toIso8601String()
                      : null,
                },
              );
            }
          },
          onUpdateObjectProperties: (id, props) {
            c.edit(id, properties: props);
          },
          onExportDiagramToNote: (ids) async {
            final source = c.find(object.id);
            if (source == null || source.isDeleted) return;
            final noteId = await showDiagramNoteDialog(context, c, source, ids);
            if (mounted && noteId != null) openLinkedObject(noteId);
          },
          onExportSelectionToNote: (elements, markdown) async {
            final noteTitle = elements.isNotEmpty
                ? (elements.first.type == 'card' &&
                          elements.first.data['title'] is String &&
                          (elements.first.data['title'] as String).isNotEmpty
                      ? elements.first.data['title'] as String
                      : (elements.first.text.trim().isNotEmpty
                            ? elements.first.text
                                  .split(RegExp(r'\r?\n'))
                                  .first
                                  .trim()
                            : '${object.title} Extract'))
                : '${object.title} Extract';
            final newNote = await c.create(
              'orbit.note',
              title: noteTitle,
              body: markdown,
              properties: object.properties['creativeProject'] == true
                  ? {
                      'folder': object.properties['folder'],
                      'project': object.properties['project'],
                      'projectName': object.properties['projectName'],
                      'sourceBoardId': object.id,
                    }
                  : const {},
            );
            if (newNote != null) {
              openLinkedObject(newNote.id);
              message('Created note "$noteTitle" from canvas selection');
            }
          },
          breadcrumbs: () {
            final chain = <CanvasBreadcrumb>[
              CanvasBreadcrumb(id: object.id, title: object.title),
            ];
            final visited = <String>{object.id};
            var currentId = object.id;

            while (true) {
              final parents = c.activeObjects
                  .where(
                    (o) =>
                        o.typeId == 'orbit.canvas' && !visited.contains(o.id),
                  )
                  .where((o) {
                    final elements = o.data['elements'];
                    if (elements is List) {
                      return elements.any(
                        (e) => e is Map && e['objectId'] == currentId,
                      );
                    }
                    return false;
                  })
                  .toList();
              if (parents.isEmpty) break;
              final parent = parents.first;
              visited.add(parent.id);
              chain.insert(
                0,
                CanvasBreadcrumb(id: parent.id, title: parent.title),
              );
              currentId = parent.id;
            }
            return chain.length > 1 ? chain : null;
          }(),
          camera: c.session.cameras[object.id],
          onCameraChanged: (v) {
            c.session.cameras = {...c.session.cameras, object.id: v};
            c.persistSession();
          },
        ),
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
      'orbit.view' => SavedViewHost(
        key: ValueKey('$pane:view-${object.id}'),
        viewObject: object,
        controller: c,
      ),
      'orbit.file' when objectKindLabel(object) == 'PDF' => OrbitPdfReader(
        key: ValueKey(
          '$pane:pdf:${object.id}:${object.properties['contentRef']}:${object.properties['checksum']}:${c.studyResumeSerial}',
        ),
        objectId: object.id,
        title: object.title,
        checksum: object.properties['checksum'] as String?,
        initialSearchChecksum: pane == 'primary'
            ? c.pdfSearchRequests[object.id]?.sourceChecksum
            : null,
        initialRecognizedMatch:
            pane == 'primary' &&
            c.pdfSearchRequests[object.id]?.matchKind == 'Recognized text',
        initialSearchRegions: pane == 'primary'
            ? c.pdfSearchRequests[object.id]?.sourceRegions ?? const []
            : const [],
        onRecognizeText: () => showOcrReview(context, c, objectId: object.id),
        initialSearchOffset: pane == 'primary'
            ? c.pdfSearchRequests[object.id]?.sourceOffset
            : null,
        initialSearchLength: pane == 'primary'
            ? c.pdfSearchRequests[object.id]?.matchLength ?? 0
            : 0,
        formValues:
            object.properties['pdfFormDraft'] is Map &&
                (object.properties['pdfFormDraft'] as Map)['version'] == 1 &&
                (object.properties['pdfFormDraft'] as Map)['checksum'] ==
                    object.properties['checksum'] &&
                (object.properties['pdfFormDraft'] as Map)['values'] is Map
            ? Map<String, dynamic>.from(
                (object.properties['pdfFormDraft'] as Map)['values'] as Map,
              )
            : const {},
        onFormChanged: kIsWeb
            ? null
            : (key, value) => c.savePdfFormField(
                object.id,
                object.properties['checksum'] as String,
                key,
                value,
              ),
        onSaveFilledCopy: (bytes) async =>
            await importBytes(
              '${object.title.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '')} · filled.pdf',
              bytes,
            ) !=
            null,
        onSaveAnnotatedCopy: kIsWeb
            ? null
            : (bytes, annotations) =>
                  c.saveAnnotatedPdfCopy(object, annotations, bytes),
        annotations: c.activeObjects
            .where(PdfAnnotation.isAnnotation)
            .map(PdfAnnotation.new)
            .where((a) => a.fileId == object.id)
            .toList(),
        onOpenAnnotation: (id) {
          c.openPdfNote(id, besidePdfId: object.id);
        },
        linkedNotes: c.pdfLinkedNotes(object.id),
        onOpenLinkedNote: (id) => c.openPdfNote(id, besidePdfId: object.id),
        onDeleteLinkedNote: (note) => c.deletePdfLinkedNote(note, object.id),
        onRestoreLinkedNote: (note) => c.restore(note.id, expected: note),
        initialAnnotationId:
            c.session.noteViews['pdf:$pane:${object.id}']?['annotationId']
                as String?,
        navigationRequest:
            (c.session.noteViews['pdf:$pane:${object.id}']?['request'] as num?)
                ?.toInt() ??
            0,
        hasActiveNoteBeside: hasActiveNoteBeside,
        hasActiveCanvasBeside: hasActiveCanvasBeside,
        onExtractToCanvas: (text, page) async {
          final targetCanvasId = hasActiveCanvasBeside ? otherObject.id : null;
          final ok = await c.extractPdfQuoteToCanvas(
            text,
            page,
            object.id,
            object.title,
            targetCanvasId: targetCanvasId,
          );
          if (ok) {
            message('Extracted quote to canvas');
            return true;
          }
          return false;
        },
        onInsertIntoActiveNote: (text, page) async {
          final success = await c.extractPdfQuoteToActiveNote(
            text,
            page,
            object.id,
            object.title,
          );
          if (success) {
            message('Inserted quote into note');
            return true;
          }
          return false;
        },
        onUpdateReview: (annotation, body, color, style, resolved) =>
            c.updatePdfReview(
              annotation,
              body: body,
              color: color,
              style: style,
              resolved: resolved,
            ),
        onDeleteReview: c.deletePdfReview,
        onRestoreReview: c.restorePdfReview,
        onReviewBatch: (items, action, {color, isCancelled, onProgress}) =>
            c.changePdfReviews(
              object,
              items,
              action,
              color: color,
              isCancelled: isCancelled,
              onProgress: onProgress,
            ),
        onUndoReviewBatch: c.undoPdfReviewBatch,
        onReviewBoard: (items) async {
          final board = await c.createPdfReviewBoard(object, items);
          if (board == null) return false;
          message('Canvas review board created: ${board.title}');
          c.openObject(board.id);
          c.openObject(object.id, secondary: true);
          return true;
        },
        onPageComment: (page, comment) async =>
            await c.createPdfPageComment(
              object.id,
              object.properties['checksum'] as String,
              page,
              comment,
            ) !=
            null,
        onReviewSummary: (ids) async {
          final note = await c.createPdfReviewSummary(object.id, ids);
          if (note == null) return false;
          c.updateSession((s) => s.secondaryId = object.id);
          return true;
        },
        onExportReview: (markdown) => exportFile(
          'Orbit PDF review.md',
          markdown,
          mimeType: 'text/markdown',
        ),
        onHighlight: (quote, regions, comment) async =>
            await c.createPdfHighlight(
              object.id,
              object.properties['checksum'] as String,
              quote,
              regions,
              comment: comment,
            ) !=
            null,
        loadBytes: () => c.repository.readAttachment(
          object.properties['contentRef'] as String,
        ),
        onOpenOriginal: () => openOriginal(object),
        onOpenExternal: (uri) => launchUrl(uri),
        initialPage:
            (c.session.noteViews['pdf:$pane:${object.id}']?['page'] as num?)
                ?.toInt() ??
            (object.properties['lastReadPage'] is int &&
                    (object.properties['lastReadPage'] as int) > 0
                ? object.properties['lastReadPage'] as int
                : 1),
        initialReadingRoomId: object.properties['lastRoomId'] is String
            ? object.properties['lastRoomId'] as String
            : null,
        initialZoom:
            (c.session.noteViews['pdf:$pane:${object.id}']?['zoom'] as num?)
                ?.toDouble(),
        initialFavorite: object.properties['isFavorite'] == true,
        onToggleFavorite: (fav) {
          final latest = c.find(object.id);
          if (latest != null) {
            c.edit(
              object.id,
              properties: {...latest.properties, 'isFavorite': fav},
            );
          }
        },
        onOpenMemories: () {
          final meta = PdfBookMeta.fromObject(object);
          BookMemoriesDialog.show(
            context,
            book: meta,
            controller: c,
            bookmarks:
                (object.properties['pdfBookmarks'] is List
                        ? object.properties['pdfBookmarks'] as List
                        : const [])
                    .whereType<int>()
                    .toList(),
            annotations: c.activeObjects
                .where(PdfAnnotation.isAnnotation)
                .map(PdfAnnotation.new)
                .where((a) => a.fileId == object.id)
                .toList(),
          );
        },
        onOpenBookshelf: _openBookshelf,
        onReadingState: (page, zoom) {
          c.session.noteViews = {
            ...c.session.noteViews,
            'pdf:$pane:${object.id}': {
              ...?c.session.noteViews['pdf:$pane:${object.id}'],
              'page': page,
              'zoom': zoom,
            },
          };
          c.persistSession();
        },
        readOnly: c.repository.readOnly || object.isReadOnly,
        bookmarks:
            (object.properties['pdfBookmarks'] is List
                    ? object.properties['pdfBookmarks'] as List
                    : const [])
                .whereType<int>()
                .where((p) => p > 0)
                .toList(),
        onBookmarks: (pages) {
          final latest = c.find(object.id);
          if (latest != null) {
            c.edit(
              object.id,
              properties: {...latest.properties, 'pdfBookmarks': pages},
            );
          }
        },
        bookmarkNames: {
          if (object.properties['pdfBookmarkNames'] is Map)
            for (final entry
                in (object.properties['pdfBookmarkNames'] as Map).entries)
              if (int.tryParse('${entry.key}') != null && entry.value is String)
                int.parse('${entry.key}'): entry.value as String,
        },
        onRenameBookmark: (page, name) => c.renamePdfBookmark(
          object.id,
          page,
          name,
          expectedChecksum: object.properties['checksum'] as String?,
        ),
        onQuote: (text, page) async {
          final note = await c.createPdfQuote(
            object.id,
            page,
            text,
            expectedChecksum: object.properties['checksum'] as String?,
          );
          if (note != null) {
            c.updateSession((s) {
              s.secondaryId = object.id;
              s.noteViews = {
                ...s.noteViews,
                'pdf:secondary:${object.id}': {'page': page},
              };
            });
          } else {
            throw StateError(
              'The linked note could not be saved. Please retry.',
            );
          }
        },
        onCreateDocument: (document, page, quote) async {
          final note = await c.createPdfQuote(
            object.id,
            page,
            quote,
            document: document,
            expectedChecksum: object.properties['checksum'] as String?,
          );
          if (note == null) return false;
          c.updateSession((s) {
            s.secondaryId = object.id;
            s.noteViews = {
              ...s.noteViews,
              'pdf:secondary:${object.id}': {'page': page},
            };
          });
          return true;
        },
      ),
      'orbit.file'
          when isModelAsset(
            object.properties['originalName'] as String? ?? object.title,
          ) =>
        ModelAssetViewer(
          key: ValueKey(
            '$pane:model:${object.id}:${object.properties['contentRef']}:${object.properties['checksum']}',
          ),
          name: object.properties['originalName'] as String? ?? object.title,
          sourceVersion: (
            c.repository.workspaceId,
            c.workspaceGeneration,
            c.attachmentRevision,
            object.id,
            object.properties['contentRef'],
            object.properties['checksum'],
          ),
          byteLength: object.properties['byteLength'] is int
              ? object.properties['byteLength'] as int
              : null,
          loadBytes: () => c.repository.readAttachment(
            object.properties['contentRef'] as String,
          ),
          onOpenOriginal: () => openOriginal(object),
          onPlace: c.repository.readOnly
              ? null
              : () async {
                  final workspace = c.repository.workspaceId;
                  final target = await showNoteLinkDialog(context, [
                    for (final board in c.activeObjects)
                      if (board.typeId == 'orbit.canvas' && !board.isReadOnly)
                        NoteLinkTarget(id: board.id, title: board.title),
                  ]);
                  if (!mounted ||
                      workspace != c.repository.workspaceId ||
                      target == null) {
                    return;
                  }
                  final ok = await c.placeModelAsset(object.id, target.id);
                  if (mounted) {
                    message(
                      ok
                          ? 'Linked asset added to Canvas.'
                          : c.error ??
                                'Could not save the placement; the draft is retained.',
                    );
                  }
                },
        ),
      'orbit.file'
          when previewLanguage(
                object.properties['originalName'] as String? ?? object.title,
              ) !=
              null =>
        CodeFilePreview(
          key: ValueKey(
            '$pane:code:${object.id}:${object.properties['checksum']}',
          ),
          title: object.title,
          sourceVersion: (
            c.repository.workspaceId,
            c.workspaceGeneration,
            c.attachmentRevision,
            object.id,
            object.properties['contentRef'],
            object.properties['checksum'],
          ),
          byteLength: object.properties['byteLength'] is int
              ? object.properties['byteLength'] as int
              : null,
          language: previewLanguage(
            object.properties['originalName'] as String? ?? object.title,
          )!,
          loadBytes: () => c.repository.readAttachment(
            object.properties['contentRef'] as String,
          ),
          onOpenOriginal: () => openOriginal(object),
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
          if ((object.properties['mimeType'] as String? ?? '').startsWith(
            'image/',
          ))
            TextButton.icon(
              onPressed: () => showOcrReview(context, c, objectId: object.id),
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Recognize and review text'),
            ),
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
    final view = Column(
      children: [
        ObjectBridgeBar(controller: c, object: object),
        Expanded(child: content),
      ],
    );
    final readOnly = object.isReadOnly || c.repository.readOnly;
    final paneFocus = pane == 'secondary'
        ? _secondaryPaneFocus
        : _primaryPaneFocus;
    return FocusScope(
      key: ValueKey('workspace-pane:$pane'),
      node: paneFocus,
      onFocusChange: (focused) {
        if (focused) _secondaryFocused = pane == 'secondary';
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          _secondaryFocused = pane == 'secondary';
          if (readOnly) paneFocus.requestFocus();
        },
        child: readOnly
            ? Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Read-only: this format requires a newer compatible version.',
                    ),
                  ),
                  Expanded(child: AbsorbPointer(child: view)),
                ],
              )
            : ['orbit.note', 'orbit.canvas'].contains(object.typeId)
            ? SharedDocumentSurface(
                controller: collaboration,
                objectId: object.id,
                canvas: object.typeId == 'orbit.canvas',
                child: view,
              )
            : view,
      ),
    );
  }

  Widget inspectorView() {
    if (c.projectPanelPinned) return ProjectContextPanel(controller: c);
    return ObjectInspector(
      controller: c,
      onRename: renameObject,
      onClose: () => c.updateSession((s) => s.inspectorVisible = false),
    );
  }

  Widget statusBar() {
    final activeObject = c.find(c.session.activeId);
    final isNote =
        c.session.destination == OrbitDestination.notes &&
        activeObject?.typeId == 'orbit.note';
    String? noteStats;
    if (isNote && activeObject != null) {
      final body = activeObject.body;
      final characters = body.length;
      final words = body.trim().isEmpty
          ? 0
          : body.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      final readingMinutes = (words / 200).ceil();
      final wordsLabel = '$words ${words == 1 ? 'word' : 'words'}';
      final charsLabel =
          '$characters ${characters == 1 ? 'character' : 'characters'}';
      final readLabel = '$readingMinutes min read';
      noteStats = '$wordsLabel · $charsLabel · $readLabel';
      if (activeObject.properties['documentFormat'] == 'latex') {
        noteStats = 'LaTeX document · $charsLabel';
      }
    }

    return Container(
      height: 29,
      color: OrbitColors.of(context).panel,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(
            c.failures.isEmpty
                ? Icons.check_circle_outline
                : Icons.error_outline,
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
          if (noteStats != null) ...[
            Flexible(
              flex: 2,
              child: Tooltip(
                message: noteStats,
                child: Text(
                  noteStats,
                  key: const ValueKey('note-live-statistics'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: OrbitColors.of(context).subtle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
          ],
          Text(
            c.repository.isBrowser ? 'Browser storage' : 'Local workspace',
            style: TextStyle(
              fontSize: 10,
              color: OrbitColors.of(context).subtle,
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.cloud_off_outlined, size: 12),
        ],
      ),
    );
  }
}
