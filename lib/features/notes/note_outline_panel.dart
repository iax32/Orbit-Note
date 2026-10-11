import 'package:flutter/material.dart';
import '../../app/orbit_theme.dart';
import '../../app/orbit_components.dart';
import 'note_outline.dart';

/// A dockable side rail or panel showing the note's structured table of contents.
class NoteOutlinePanel extends StatefulWidget {
  const NoteOutlinePanel({
    super.key,
    required this.headings,
    required this.onHeadingSelected,
    this.onClose,
    this.activeHeading,
    this.isDocked = true,
  });

  final List<NoteHeading> headings;
  final ValueChanged<NoteHeading> onHeadingSelected;
  final VoidCallback? onClose;
  final NoteHeading? activeHeading;
  final bool isDocked;

  @override
  State<NoteOutlinePanel> createState() => _NoteOutlinePanelState();
}

class _NoteOutlinePanelState extends State<NoteOutlinePanel> {
  final TextEditingController _filterController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = OrbitColors.of(context);
    final theme = Theme.of(context);

    final filteredHeadings = _filter.isEmpty
        ? widget.headings
        : widget.headings
              .where(
                (h) => h.title.toLowerCase().contains(_filter.toLowerCase()),
              )
              .toList();

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: c.panel,
        border: widget.isDocked
            ? Border(left: BorderSide(color: c.border))
            : Border.all(color: c.border),
        borderRadius: widget.isDocked ? null : BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: Row(
              children: [
                Icon(Icons.toc_rounded, size: 18, color: c.accent),
                const SizedBox(width: 8),
                Text(
                  'Outline',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: c.raised,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.border),
                  ),
                  child: Text(
                    '${widget.headings.length}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: c.muted,
                    ),
                  ),
                ),
                const Spacer(),
                if (widget.onClose != null)
                  IconButton(
                    key: const ValueKey('close-outline-panel'),
                    icon: const Icon(Icons.close, size: 16),
                    tooltip: 'Close outline (Alt+O)',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    onPressed: widget.onClose,
                  ),
              ],
            ),
          ),

          // Search Filter (shown when headings exist)
          if (widget.headings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Container(
                height: 30,
                decoration: BoxDecoration(
                  color: c.raised,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: c.border),
                ),
                child: TextField(
                  controller: _filterController,
                  onChanged: (val) => setState(() => _filter = val),
                  style: TextStyle(fontSize: 12, color: c.text),
                  decoration: InputDecoration(
                    hintText: 'Filter headings...',
                    hintStyle: TextStyle(fontSize: 11, color: c.muted),
                    prefixIcon: Icon(Icons.search, size: 14, color: c.muted),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 26,
                      minHeight: 26,
                    ),
                    suffixIcon: _filter.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _filterController.clear();
                              setState(() => _filter = '');
                            },
                            child: Icon(Icons.clear, size: 12, color: c.muted),
                          )
                        : null,
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 22,
                      minHeight: 22,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 7,
                      horizontal: 4,
                    ),
                  ),
                ),
              ),
            ),

          // Content list
          Expanded(
            child: widget.headings.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.format_list_bulleted_outlined,
                            size: 28,
                            color: c.muted.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No headings yet',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: c.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add headings with # to structure your note',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: c.muted.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : filteredHeadings.isEmpty
                ? Center(
                    child: Text(
                      'No matching headings',
                      style: TextStyle(fontSize: 12, color: c.muted),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 6,
                    ),
                    itemCount: filteredHeadings.length,
                    itemBuilder: (context, index) {
                      final h = filteredHeadings[index];
                      final isActive = widget.activeHeading == h;
                      return _OutlineItem(
                        heading: h,
                        isActive: isActive,
                        onTap: () => widget.onHeadingSelected(h),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _OutlineItem extends StatefulWidget {
  const _OutlineItem({
    required this.heading,
    required this.isActive,
    required this.onTap,
  });

  final NoteHeading heading;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_OutlineItem> createState() => _OutlineItemState();
}

class _OutlineItemState extends State<_OutlineItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = OrbitColors.of(context);
    final h = widget.heading;
    final indent = ((h.level - 1) * 12.0).clamp(0.0, 48.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: OrbitMotionScope.duration(context, OrbitMotion.control),
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: EdgeInsets.only(
            left: 6 + indent,
            right: 8,
            top: 5,
            bottom: 5,
          ),
          decoration: BoxDecoration(
            color: widget.isActive
                ? c.accent.withValues(alpha: 0.15)
                : _hovered
                ? c.accent.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: widget.isActive
                ? Border.all(color: c.accent.withValues(alpha: 0.4), width: 1)
                : null,
          ),
          child: Row(
            children: [
              // Level Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: widget.isActive
                      ? c.accent.withValues(alpha: 0.25)
                      : c.raised,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: widget.isActive
                        ? c.accent.withValues(alpha: 0.5)
                        : c.border,
                  ),
                ),
                child: Text(
                  'H${h.level}',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: widget.isActive ? c.accent : c.muted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  h.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: h.level == 1
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: widget.isActive ? c.accent : c.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
