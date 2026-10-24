import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';
import '../../domain/universal_object.dart';
import '../../domain/object_discovery.dart';

/// Shows the Quick Switcher dialog to instantly jump between notes, canvases, and files.
Future<void> showQuickSwitcher(
  BuildContext context,
  WorkspaceController controller,
) => showOrbitDialog<void>(
  context: context,
  builder: (context) => QuickSwitcherDialog(controller: controller),
);

class QuickSwitcherDialog extends StatefulWidget {
  const QuickSwitcherDialog({super.key, required this.controller});

  final WorkspaceController controller;

  @override
  State<QuickSwitcherDialog> createState() => _QuickSwitcherDialogState();
}

class _QuickSwitcherDialogState extends State<QuickSwitcherDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode(debugLabel: 'QuickSwitcherSearch');
  final ScrollController _scrollController = ScrollController();
  final _selectionReveal = OrbitListSelectionReveal();
  String _query = '';
  int _selected = 0;
  bool _activating = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.onKeyEvent = _handleKeyEvent;
  }

  @override
  void dispose() {
    _selectionReveal.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final total = _buildItems().length;
      if (total > 0) {
        setState(() => _selected = (_selected + 1).clamp(0, total - 1));
        _selectionReveal.reveal(_scrollController);
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final total = _buildItems().length;
      if (total > 0) {
        setState(() => _selected = (_selected - 1).clamp(0, total - 1));
        _selectionReveal.reveal(_scrollController, forward: false);
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final items = _buildItems();
      if (event is KeyDownEvent &&
          items.isNotEmpty &&
          _selected < items.length) {
        _activateItem(items[_selected]);
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _updateQuery(String value) {
    _selectionReveal.cancel();
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    setState(() {
      _query = value;
      _selected = 0;
    });
  }

  String? _cachedQuery;
  List<UniversalObject>? _cachedObjects;
  List<_SwitcherEntry> _cachedItems = [];

  List<_SwitcherEntry> _buildItems() {
    if (_cachedQuery == _query &&
        identical(_cachedObjects, widget.controller.objects)) {
      return _cachedItems;
    }
    _cachedQuery = _query;
    _cachedObjects = widget.controller.objects;
    final c = widget.controller;
    final results = <_SwitcherEntry>[];
    final seenIds = <String>{};

    if (_query.trim().isEmpty) {
      // 1. Open Tabs
      for (final id in c.session.tabs) {
        final obj = c.find(id);
        if (obj != null && !obj.isDeleted && seenIds.add(obj.id)) {
          results.add(
            _SwitcherEntry(
              object: obj,
              badge: obj.id == c.session.activeId ? 'ACTIVE' : 'OPEN',
              category: 'Open Tabs',
            ),
          );
        }
      }

      // 2. Recent items
      for (final id in c.session.recent) {
        final obj = c.find(id);
        if (obj != null && !obj.isDeleted && seenIds.add(obj.id)) {
          results.add(
            _SwitcherEntry(object: obj, badge: 'RECENT', category: 'Recent'),
          );
        }
      }

      // 3. Bookmarks
      for (final obj in c.bookmarkedObjects) {
        if (!obj.isDeleted && seenIds.add(obj.id)) {
          results.add(
            _SwitcherEntry(
              object: obj,
              badge: 'BOOKMARKED',
              category: 'Bookmarks',
            ),
          );
        }
      }

      // 4. Fill with other objects up to 15
      for (final obj in c.objects) {
        if (!obj.isDeleted && seenIds.add(obj.id)) {
          results.add(_SwitcherEntry(object: obj, category: 'All items'));
          if (results.length >= 20) break;
        }
      }
    } else {
      final q = _query.trim().toLowerCase();
      final ranked = <({UniversalObject object, int rank})>[];
      for (final object in c.objects) {
        final rank = quickOpenRank(object, q);
        if (rank != null) ranked.add((object: object, rank: rank));
      }
      ranked.sort((a, b) {
        final rank = a.rank.compareTo(b.rank);
        if (rank != 0) return rank;
        final title = a.object.title.toLowerCase().compareTo(
          b.object.title.toLowerCase(),
        );
        return title != 0 ? title : a.object.id.compareTo(b.object.id);
      });
      final matches = ranked.map((entry) => entry.object).toList();

      for (final obj in matches) {
        final isOpen = c.session.tabs.contains(obj.id);
        final isBookmarked = c.isBookmarked(obj.id);
        results.add(
          _SwitcherEntry(
            object: obj,
            badge: isOpen
                ? 'OPEN'
                : isBookmarked
                ? 'BOOKMARKED'
                : null,
            category: 'Matches',
          ),
        );
      }

      // If no exact title match, provide Create option
      final hasExact = matches.any(
        (o) => o.title.toLowerCase() == _query.trim().toLowerCase(),
      );
      if (!hasExact && _query.trim().isNotEmpty) {
        results.add(_SwitcherEntry.createNote(_query.trim()));
      }
    }

    return _cachedItems = results;
  }

  void _activateItem(_SwitcherEntry item) {
    if (_activating) return;
    _activating = true;
    Navigator.of(context).pop();
    if (item.isCreate) {
      widget.controller.create('orbit.note', title: item.createTitle!);
    } else if (item.object != null) {
      widget.controller.openObject(item.object!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = OrbitColors.of(context);
    final items = _buildItems();

    if (_selected >= items.length) {
      _selected = items.isEmpty ? 0 : items.length - 1;
    }

    return Dialog(
      backgroundColor: c.floating,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.border),
      ),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Input Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 20, color: c.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('quick-switcher-search-input'),
                      controller: _searchController,
                      focusNode: _searchFocus,
                      autofocus: true,
                      style: TextStyle(
                        fontSize: 14,
                        color: c.text,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Open a note, task, project, or file…',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: c.muted,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: _updateQuery,
                      onSubmitted: (_) {
                        final items = _buildItems();
                        if (items.isNotEmpty && _selected < items.length) {
                          _activateItem(items[_selected]);
                        }
                      },
                    ),
                  ),
                  if (_query.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _updateQuery('');
                        _searchFocus.requestFocus();
                      },
                    ),
                  IconButton(
                    tooltip: 'Close Quick Switcher',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            Flexible(
              child: CustomScrollView(
                controller: _scrollController,
                shrinkWrap: true,
                slivers: [
                  if (items.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No items found',
                          style: TextStyle(fontSize: 13, color: c.muted),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 8,
                      ),
                      sliver: SliverList.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _SwitcherItemRow(
                            selectionMarker: index == _selected
                                ? _selectionReveal.marker
                                : null,
                            key: item.isCreate
                                ? const ValueKey('quick-switcher-create-option')
                                : ValueKey(
                                    'quick-switcher-item-${item.object!.id}',
                                  ),
                            item: item,
                            isSelected: index == _selected,
                            onTap: () => _activateItem(item),
                            onHover: () {
                              _selectionReveal.cancel();
                              setState(() => _selected = index);
                            },
                          );
                        },
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: c.panel,
                        border: Border(top: BorderSide(color: c.border)),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          _HintKey(keyLabel: '↑↓', actionLabel: 'Navigate'),
                          _HintKey(keyLabel: '↵', actionLabel: 'Open'),
                          _HintKey(keyLabel: 'Esc', actionLabel: 'Dismiss'),
                          Text(
                            '${items.length} ${items.length == 1 ? 'result' : 'results'}',
                            style: TextStyle(fontSize: 10, color: c.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitcherEntry {
  _SwitcherEntry({required this.object, this.badge, this.category})
    : isCreate = false,
      createTitle = null;

  _SwitcherEntry.createNote(this.createTitle)
    : object = null,
      badge = 'NEW',
      category = 'Actions',
      isCreate = true;

  final UniversalObject? object;
  final String? badge;
  final String? category;
  final bool isCreate;
  final String? createTitle;
}

class _SwitcherItemRow extends StatelessWidget {
  const _SwitcherItemRow({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onHover,
    this.selectionMarker,
  });

  final _SwitcherEntry item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onHover;
  final Key? selectionMarker;

  @override
  Widget build(BuildContext context) {
    final c = OrbitColors.of(context);
    final obj = item.object;
    final isLatex = obj?.properties['documentFormat'] == 'latex';
    final icon = item.isCreate
        ? Icons.add_circle_outline
        : switch (obj!.typeId) {
            'orbit.canvas' => Icons.space_dashboard_outlined,
            'orbit.task' => Icons.check_box_outlined,
            'orbit.file' =>
              objectKindLabel(obj) == 'PDF'
                  ? Icons.picture_as_pdf_outlined
                  : Icons.insert_drive_file_outlined,
            'orbit.project' => Icons.folder_special_outlined,
            'orbit.view' || 'orbit.collection' => Icons.table_chart_outlined,
            'orbit.event' => Icons.event_outlined,
            _ => isLatex ? Icons.functions_rounded : Icons.description_outlined,
          };
    final badgeColor = item.badge == 'BOOKMARKED'
        ? OrbitColors.of(context).warning
        : item.isCreate || item.badge == 'ACTIVE' || item.badge == 'OPEN'
        ? c.accent
        : c.muted;
    final badge = item.badge == null
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              item.badge!,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: badgeColor,
              ),
            ),
          );
    final contextLabel = obj == null ? '' : objectContextLabel(obj);

    return Semantics(
      button: true,
      selected: isSelected,
      child: MouseRegion(
        onEnter: (_) => onHover(),
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Material(
            color: isSelected
                ? c.accent.withValues(alpha: 0.15)
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: isSelected
                    ? c.accent.withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              onFocusChange: (focused) {
                if (focused) onHover();
              },
              child: Padding(
                key: selectionMarker,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked =
                        constraints.maxWidth < 420 ||
                        MediaQuery.textScalerOf(context).scale(13) > 20;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            icon,
                            size: 16,
                            color: item.isCreate || isLatex || isSelected
                                ? c.accent
                                : c.muted,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.isCreate)
                                Text.rich(
                                  TextSpan(
                                    text: 'Create new note ',
                                    children: [
                                      TextSpan(
                                        text: '"${item.createTitle}"',
                                        style: TextStyle(
                                          color: c.accent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  style: TextStyle(fontSize: 13, color: c.text),
                                )
                              else
                                Text(
                                  obj!.title.isEmpty
                                      ? 'Untitled document'
                                      : obj.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: c.text,
                                  ),
                                ),
                              if (contextLabel.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  contextLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: c.muted,
                                  ),
                                ),
                              ],
                              if (stacked && badge != null) ...[
                                const SizedBox(height: 6),
                                badge,
                              ],
                            ],
                          ),
                        ),
                        if (!stacked && badge != null) ...[
                          const SizedBox(width: 8),
                          badge,
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HintKey extends StatelessWidget {
  const _HintKey({required this.keyLabel, required this.actionLabel});

  final String keyLabel;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final c = OrbitColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: c.raised,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: c.border),
          ),
          child: Text(
            keyLabel,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: c.muted,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            actionLabel,
            style: TextStyle(fontSize: 10, color: c.muted),
          ),
        ),
      ],
    );
  }
}
