import 'package:flutter/material.dart';
import '../../app/orbit_density.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';

/// Readable tabs with explicit overflow; the active tab never slips offscreen.
class OrbitTabStrip extends StatelessWidget {
  const OrbitTabStrip({
    super.key,
    required this.controller,
    required this.onActivate,
    required this.onContextMenu,
  });
  final WorkspaceController controller;
  final ValueChanged<String> onActivate;
  final void Function(String, Offset) onContextMenu;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final density = OrbitDensity.of(context);
      final all = controller.session.tabs;
      final capacity =
          ((constraints.maxWidth - density.controlHeight) / density.tabWidth)
              .floor()
              .clamp(0, all.length);
      final visible = all.take(capacity).toList();
      final active = controller.session.activeId;
      if (capacity > 0 &&
          active != null &&
          all.contains(active) &&
          !visible.contains(active)) {
        visible[visible.length - 1] = active;
      }
      final hidden = all.length - visible.length;
      final colors = OrbitColors.of(context);
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colors.panelSecondary,
          border: Border(
            top: BorderSide(color: colors.border.withValues(alpha: .7)),
            bottom: BorderSide(color: colors.divider),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: false,
                itemCount: visible.length,
                onReorderItem: (oldIndex, newIndex) {
                  final from = all.indexOf(visible[oldIndex]);
                  final to = newIndex >= visible.length
                      ? all.indexOf(visible.last) + 1
                      : all.indexOf(visible[newIndex]);
                  controller.reorderTab(from, to);
                },
                itemBuilder: (context, index) => ReorderableDragStartListener(
                  key: ValueKey(visible[index]),
                  index: index,
                  child: SizedBox(
                    width: density.tabWidth,
                    child: _ReadableTab(
                      id: visible[index],
                      controller: controller,
                      onActivate: onActivate,
                      onContextMenu: onContextMenu,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              height: double.infinity,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: colors.border)),
              ),
              child: Tooltip(
                message: 'Search open tabs and recent tabs',
                child: TextButton(
                  key: const ValueKey('tab-overflow-button'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _TabList(controller: controller),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size(
                      density.controlHeight,
                      density.controlHeight,
                    ),
                  ),
                  child: Text(hidden > 0 ? '+$hidden' : '⋯'),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _ReadableTab extends StatefulWidget {
  const _ReadableTab({
    required this.id,
    required this.controller,
    required this.onActivate,
    required this.onContextMenu,
  });
  final String id;
  final WorkspaceController controller;
  final ValueChanged<String> onActivate;
  final void Function(String, Offset) onContextMenu;
  @override
  State<_ReadableTab> createState() => _ReadableTabState();
}

class _ReadableTabState extends State<_ReadableTab> {
  bool hover = false;
  bool focus = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final colors = OrbitColors.of(context);
    final selected = c.session.activeId == widget.id;
    final title = c.find(widget.id)?.title ?? 'Missing object';
    final pinned = c.isPinned(widget.id);
    final bookmarked = c.isBookmarked(widget.id);
    final obj = c.find(widget.id);
    final rawColor = obj?.properties['accent'] ?? obj?.properties['color'];
    Color? tabAccent;
    if (rawColor is int) {
      tabAccent = Color(rawColor);
    } else if (rawColor is String) {
      if (OrbitColors.accentPresets.containsKey(rawColor)) {
        tabAccent = OrbitColors.accentPresets[rawColor];
      } else {
        final hex = rawColor.replaceAll('#', '');
        if (hex.length == 6) {
          final val = int.tryParse('FF$hex', radix: 16);
          if (val != null) tabAccent = Color(val);
        }
      }
    }
    if (tabAccent == null && obj != null) {
      final folder = c.objectFolder(obj.id);
      final val = c.folderColorValue(folder);
      if (val != null) {
        tabAccent = Color(val);
      }
    }
    return Tooltip(
      message: title,
      child: MouseRegion(
        onEnter: (_) => setState(() => hover = true),
        onExit: (_) => setState(() => hover = false),
        child: Listener(
          onPointerDown: (event) {
            if (event.buttons == 4) c.closeTab(widget.id);
          },
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onFocusChange: (value) => setState(() => focus = value),
              onTap: () => widget.onActivate(widget.id),
              onSecondaryTapDown: (details) =>
                  widget.onContextMenu(widget.id, details.globalPosition),
              child: AnimatedContainer(
                duration: OrbitMotionScope.duration(
                  context,
                  OrbitMotion.control,
                ),
                curve: OrbitMotion.ease,
                margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? colors.raised
                      : hover || focus
                      ? colors.hover
                      : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? (tabAccent ?? colors.border)
                        : Colors.transparent,
                    width: selected ? 1 : 0,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      pinned
                          ? Icons.push_pin_outlined
                          : Icons.description_outlined,
                      size: 16,
                      color: selected ? colors.text : colors.subtle,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title.isEmpty ? 'Untitled' : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: selected ? colors.text : colors.subtle,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (c.dirty.contains(widget.id))
                      const Icon(Icons.circle, size: 5),
                    AnimatedOpacity(
                      duration: OrbitMotion.control,
                      opacity: bookmarked || hover || focus || selected
                          ? 1
                          : 0.38,
                      child: IconButton(
                        key: ValueKey('tab-bookmark-${widget.id}'),
                        tooltip: bookmarked
                            ? 'Remove bookmark (Ctrl+Shift+D)'
                            : 'Bookmark tab (Ctrl+Shift+D)',
                        onPressed: () => c.toggleBookmark(widget.id),
                        constraints: const BoxConstraints.tightFor(
                          width: 28,
                          height: 28,
                        ),
                        padding: EdgeInsets.zero,
                        splashRadius: 14,
                        icon: Icon(
                          bookmarked ? Icons.bookmark : Icons.bookmark_border,
                          size: 16,
                        ),
                      ),
                    ),
                    Visibility(
                      visible: selected || hover || focus,
                      maintainSize: true,
                      maintainState: true,
                      maintainAnimation: true,
                      child: IconButton(
                        tooltip: pinned ? 'Unpin tab' : 'Close tab',
                        onPressed: () => pinned
                            ? c.unpinTab(widget.id)
                            : c.closeTab(widget.id),
                        icon: Icon(
                          pinned ? Icons.push_pin_outlined : Icons.close,
                          size: 16,
                        ),
                        constraints: const BoxConstraints.tightFor(
                          width: 28,
                          height: 28,
                        ),
                        padding: EdgeInsets.zero,
                        splashRadius: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabList extends StatefulWidget {
  const _TabList({required this.controller});
  final WorkspaceController controller;
  @override
  State<_TabList> createState() => _TabListState();
}

class _TabListState extends State<_TabList> {
  String query = '';
  bool recent = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final ids = (recent ? c.session.recent : c.session.tabs)
        .where(
          (id) => (c.find(id)?.title ?? '').toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    return AlertDialog(
      title: const Text('Tabs'),
      content: SizedBox(
        width: 480,
        height: 440,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Search tabs',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => query = v),
            ),
            SwitchListTile(
              title: const Text('Recently opened'),
              value: recent,
              onChanged: (v) => setState(() => recent = v),
            ),
            Expanded(
              child: ids.isEmpty
                  ? const Center(child: Text('No matching tabs'))
                  : ListView.builder(
                      itemCount: ids.length,
                      itemBuilder: (_, index) => ListTile(
                        selected: ids[index] == c.session.activeId,
                        leading: Icon(
                          c.isPinned(ids[index])
                              ? Icons.push_pin_outlined
                              : Icons.description_outlined,
                        ),
                        title: Text(
                          c.find(ids[index])?.title ?? 'Missing object',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          c.openObject(ids[index]);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        if (c.session.activeId != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              c.closeOtherTabs(c.session.activeId!);
            },
            child: const Text('Close others'),
          ),
        if (c.session.activeId != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              c.closeTabsToTheRight(c.session.activeId!);
            },
            child: const Text('Close to right'),
          ),
        if (c.session.closedTabs.isNotEmpty)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              c.reopenClosedTab();
            },
            child: const Text('Reopen closed tab'),
          ),
        if (c.closedTabGroups.isNotEmpty)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              c.reopenClosedTabGroup();
            },
            child: const Text('Reopen closed tab group'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
