import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import '../../domain/universal_object.dart';
import 'workspace_views.dart' show objectIcon;

/// Document Breadcrumbs Trail displaying the document hierarchy:
/// Vault > Folder > Subfolder > Document Title
///
/// Each segment provides an interactive popover menu for instant jump navigation
/// to sibling documents and child folders, quick document actions (copy path,
/// copy wiki-link, move to folder), and new note creation.
class DocumentBreadcrumbs extends StatelessWidget {
  const DocumentBreadcrumbs({
    super.key,
    required this.vaultName,
    required this.folderPath,
    required this.documentTitle,
    this.documentId,
    this.documentIcon,
    this.isLatex = false,
    this.allFolders = const [],
    this.allObjects = const [],
    this.folderLookup,
    this.onOpenObject,
    this.onCreateNoteInFolder,
    this.onMoveToFolder,
    this.onToggleBookmark,
    this.isBookmarked = false,
    this.onTogglePin,
    this.isPinned = false,
    this.onSwitchVault,
  });

  final String vaultName;
  final String folderPath;
  final String documentTitle;
  final String? documentId;
  final String? documentIcon;
  final bool isLatex;
  final List<String> allFolders;
  final List<UniversalObject> allObjects;
  final String Function(UniversalObject object)? folderLookup;
  final ValueChanged<String>? onOpenObject;
  final ValueChanged<String>? onCreateNoteInFolder;
  final ValueChanged<String>? onMoveToFolder;
  final VoidCallback? onToggleBookmark;
  final bool isBookmarked;
  final VoidCallback? onTogglePin;
  final bool isPinned;
  final VoidCallback? onSwitchVault;

  String _resolveObjectFolder(UniversalObject o) {
    if (folderLookup != null) {
      return folderLookup!(o);
    }
    final raw = o.properties['folder'];
    if (raw is String && raw.isNotEmpty) {
      return raw == 'Notes' || raw.startsWith('Notes/') ? raw : 'Notes/$raw';
    }
    return 'Notes';
  }

  String _normalizeFolder(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == 'Notes') return 'Notes';
    if (trimmed.startsWith('Notes/')) return trimmed;
    return 'Notes/$trimmed';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtleColor = theme.colorScheme.onSurface.withValues(alpha: 0.35);
    final normalized = _normalizeFolder(folderPath);
    final folderSegments = normalized.split('/');

    final children = <Widget>[];

    // 1. Vault Segment
    children.add(
      _buildVaultSegment(
        context: context,
        theme: theme,
        normalizedFolder: normalized,
      ),
    );

    // 2. Folder Segments
    for (int i = 0; i < folderSegments.length; i++) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(Icons.chevron_right, size: 14, color: subtleColor),
        ),
      );

      final segmentName = folderSegments[i];
      final subPath = folderSegments.take(i + 1).join('/');

      children.add(
        _buildFolderSegment(
          context: context,
          theme: theme,
          segmentIndex: i,
          segmentName: segmentName,
          subPath: subPath,
        ),
      );
    }

    // 3. Document Segment
    children.add(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Icon(Icons.chevron_right, size: 14, color: subtleColor),
      ),
    );

    children.add(
      _buildDocumentSegment(
        context: context,
        theme: theme,
        normalizedFolder: normalized,
      ),
    );

    return Semantics(
      label: 'Document breadcrumbs',
      child: Container(
        height: 28,
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildVaultSegment({
    required BuildContext context,
    required ThemeData theme,
    required String normalizedFolder,
  }) {
    final displayName = vaultName.isEmpty ? 'Personal Vault' : vaultName;

    return PopupMenuButton<String>(
      popUpAnimationStyle: OrbitMotionScope.popupStyle(context),
      key: const ValueKey('breadcrumb-vault'),
      tooltip: 'Vault: $displayName · Click for options',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
      position: PopupMenuPosition.under,
      itemBuilder: (context) {
        return [
          PopupMenuItem<String>(
            enabled: false,
            child: Row(
              children: [
                Icon(
                  Icons.workspaces_outline,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          if (onCreateNoteInFolder != null)
            PopupMenuItem<String>(
              value: 'new_root_note',
              child: Row(
                children: [
                  Icon(Icons.add, size: 15, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'New note in Vault root',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          if (onSwitchVault != null)
            const PopupMenuItem<String>(
              value: 'switch_vault',
              child: Row(
                children: [
                  Icon(Icons.folder_shared_outlined, size: 15),
                  SizedBox(width: 8),
                  Text('Switch Vault...', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
        ];
      },
      onSelected: (action) {
        if (action == 'new_root_note') {
          onCreateNoteInFolder?.call('Notes');
        } else if (action == 'switch_vault') {
          onSwitchVault?.call();
        }
      },
      child: _BreadcrumbChip(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspaces_outline,
              size: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderSegment({
    required BuildContext context,
    required ThemeData theme,
    required int segmentIndex,
    required String segmentName,
    required String subPath,
  }) {
    return PopupMenuButton<String>(
      popUpAnimationStyle: OrbitMotionScope.popupStyle(context),
      key: ValueKey('breadcrumb-folder-$segmentIndex'),
      tooltip: 'Folder: $subPath · Click for folder contents',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
      position: PopupMenuPosition.under,
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String>>[];

        // Header
        items.add(
          PopupMenuItem<String>(
            enabled: false,
            child: Row(
              children: [
                Icon(
                  Icons.folder_open,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    segmentName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
        items.add(const PopupMenuDivider());

        // Child subfolders
        final childFolders =
            allFolders
                .where((f) => f != subPath && p.posix.dirname(f) == subPath)
                .toList()
              ..sort();

        for (final cf in childFolders) {
          final base = p.posix.basename(cf);
          items.add(
            PopupMenuItem<String>(
              value: 'folder:$cf',
              child: Row(
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 15,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      base,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Notes and objects in this folder
        final folderObjects =
            allObjects
                .where(
                  (o) => !o.isDeleted && _resolveObjectFolder(o) == subPath,
                )
                .toList()
              ..sort(
                (a, b) =>
                    a.title.toLowerCase().compareTo(b.title.toLowerCase()),
              );

        for (final obj in folderObjects.take(20)) {
          final isCurrent = obj.id == documentId;
          items.add(
            PopupMenuItem<String>(
              value: 'open:${obj.id}',
              child: Row(
                children: [
                  Icon(
                    objectIcon(obj.typeId),
                    size: 15,
                    color: isCurrent
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      obj.title.isEmpty ? 'Untitled' : obj.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isCurrent
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isCurrent ? theme.colorScheme.primary : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isCurrent)
                    Icon(
                      Icons.check,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                ],
              ),
            ),
          );
        }

        if (childFolders.isEmpty && folderObjects.isEmpty) {
          items.add(
            const PopupMenuItem<String>(
              enabled: false,
              child: Text(
                'Folder is empty',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          );
        }

        if (onCreateNoteInFolder != null) {
          items.add(const PopupMenuDivider());
          items.add(
            PopupMenuItem<String>(
              value: 'new_note:$subPath',
              child: Row(
                children: [
                  Icon(Icons.add, size: 15, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'New note in "$segmentName"',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return items;
      },
      onSelected: (action) {
        if (action.startsWith('open:')) {
          final id = action.substring(5);
          onOpenObject?.call(id);
        } else if (action.startsWith('new_note:')) {
          final folder = action.substring(9);
          onCreateNoteInFolder?.call(folder);
        } else if (action.startsWith('folder:')) {
          final cf = action.substring(7);
          final first = allObjects
              .where((o) => !o.isDeleted && _resolveObjectFolder(o) == cf)
              .firstOrNull;
          if (first != null) {
            onOpenObject?.call(first.id);
          } else {
            onCreateNoteInFolder?.call(cf);
          }
        }
      },
      child: _BreadcrumbChip(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                segmentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentLeading(ThemeData theme) {
    if (documentIcon != null && documentIcon!.isNotEmpty) {
      return Text(documentIcon!, style: const TextStyle(fontSize: 12));
    } else if (isLatex) {
      return Icon(
        Icons.functions_rounded,
        size: 13,
        color: theme.colorScheme.primary,
      );
    } else {
      return Icon(
        Icons.description_outlined,
        size: 13,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
      );
    }
  }

  Widget _buildDocumentSegment({
    required BuildContext context,
    required ThemeData theme,
    required String normalizedFolder,
  }) {
    final title = documentTitle.isEmpty ? 'Untitled' : documentTitle;

    return PopupMenuButton<String>(
      popUpAnimationStyle: OrbitMotionScope.popupStyle(context),
      key: const ValueKey('breadcrumb-document'),
      tooltip: 'Document: $title · Click for quick actions',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 300),
      position: PopupMenuPosition.under,
      itemBuilder: (context) {
        return [
          PopupMenuItem<String>(
            enabled: false,
            child: Row(
              children: [
                _buildDocumentLeading(theme),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'copy_path',
            child: Row(
              children: [
                Icon(Icons.link, size: 15),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Copy relative path',
                    style: TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'copy_wikilink',
            child: Row(
              children: [
                Icon(Icons.code, size: 15),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Copy wiki-link [[...]]',
                    style: TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (documentId != null)
            const PopupMenuItem<String>(
              value: 'copy_id',
              child: Row(
                children: [
                  Icon(Icons.fingerprint, size: 15),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Copy object ID',
                      style: TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          if (onMoveToFolder != null) ...[
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'move_folder',
              child: Row(
                children: [
                  Icon(Icons.drive_file_move_outlined, size: 15),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Move to folder...',
                      style: TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (onToggleBookmark != null) ...[
            PopupMenuItem<String>(
              value: 'toggle_bookmark',
              child: Row(
                children: [
                  Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    size: 15,
                    color: isBookmarked
                        ? OrbitColors.of(context).warning
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isBookmarked ? 'Remove bookmark' : 'Bookmark note',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (onTogglePin != null) ...[
            PopupMenuItem<String>(
              value: 'toggle_pin',
              child: Row(
                children: [
                  Icon(
                    isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 15,
                    color: isPinned ? OrbitColors.of(context).accent : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isPinned ? 'Unpin tab' : 'Pin tab',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ];
      },
      onSelected: (action) async {
        if (action == 'copy_path') {
          final relPath = '$normalizedFolder/$title.md';
          await Clipboard.setData(ClipboardData(text: relPath));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Copied path "$relPath" to clipboard'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else if (action == 'copy_wikilink') {
          final link = '[[$title]]';
          await Clipboard.setData(ClipboardData(text: link));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Copied wiki-link $link to clipboard'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else if (action == 'copy_id') {
          if (documentId != null) {
            await Clipboard.setData(ClipboardData(text: documentId!));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied ID "$documentId" to clipboard'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        } else if (action == 'move_folder') {
          final target = await showMoveToFolderDialog(
            context,
            allFolders,
            currentFolder: normalizedFolder,
          );
          if (target != null && target != normalizedFolder) {
            onMoveToFolder?.call(target);
          }
        } else if (action == 'toggle_bookmark') {
          onToggleBookmark?.call();
        } else if (action == 'toggle_pin') {
          onTogglePin?.call();
        }
      },
      child: _BreadcrumbChip(
        initialColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDocumentLeading(theme),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for moving the current document to any known folder in the vault.
Future<String?> showMoveToFolderDialog(
  BuildContext context,
  List<String> folders, {
  String? currentFolder,
}) {
  final cleanFolders = folders.isEmpty ? ['Notes'] : folders;
  return showOrbitDialog<String>(
    context: context,
    builder: (context) {
      String filter = '';
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final filtered = cleanFolders
              .where((f) => f.toLowerCase().contains(filter.toLowerCase()))
              .toList();

          return OrbitDialog(
            title: const Text('Move to Folder'),
            content: SizedBox(
              width: 340,
              height: 320,
              child: Column(
                children: [
                  if (cleanFolders.length > 5) ...[
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Filter folders...',
                        prefixIcon: Icon(Icons.search, size: 16),
                        isDense: true,
                      ),
                      onChanged: (v) => setDialogState(() => filter = v),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'No matching folders',
                              style: TextStyle(fontSize: 12),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final f = filtered[i];
                              final isCurrent = f == currentFolder;
                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.folder_outlined,
                                  size: 16,
                                  color: isCurrent
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                                title: Text(
                                  f,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isCurrent
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: isCurrent
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                ),
                                trailing: isCurrent
                                    ? const Icon(Icons.check, size: 14)
                                    : null,
                                onTap: () => Navigator.pop(context, f),
                              );
                            },
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
            ],
          );
        },
      );
    },
  );
}

class _BreadcrumbChip extends StatefulWidget {
  const _BreadcrumbChip({required this.child, this.initialColor});

  final Widget child;
  final Color? initialColor;

  @override
  State<_BreadcrumbChip> createState() => _BreadcrumbChipState();
}

class _BreadcrumbChipState extends State<_BreadcrumbChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final baseColor = widget.initialColor ?? Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: OrbitMotionScope.duration(context, OrbitMotion.micro),
        curve: OrbitMotion.ease,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: _hovered ? colors.hover : baseColor,
        ),
        child: widget.child,
      ),
    );
  }
}
