import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import '../../canvas/canvas_search.dart';

class CanvasSearchOverlay extends StatefulWidget {
  const CanvasSearchOverlay({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.results,
    required this.activeIndex,
    required this.category,
    required this.onCategoryChanged,
    required this.onNext,
    required this.onPrevious,
    required this.onSelectIndex,
    required this.onClose,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final List<CanvasSearchResult> results;
  final int activeIndex;
  final CanvasSearchCategory category;
  final ValueChanged<CanvasSearchCategory> onCategoryChanged;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final ValueChanged<int> onSelectIndex;
  final VoidCallback onClose;

  @override
  State<CanvasSearchOverlay> createState() => _CanvasSearchOverlayState();
}

class _CanvasSearchOverlayState extends State<CanvasSearchOverlay> {
  bool _isExpanded = false;
  final _scroll = ScrollController();
  final _selectionReveal = OrbitListSelectionReveal();

  String? _activeId(CanvasSearchOverlay value) =>
      value.activeIndex >= 0 && value.activeIndex < value.results.length
      ? value.results[value.activeIndex].elementId
      : null;

  @override
  void didUpdateWidget(CanvasSearchOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isExpanded) return;
    final reset =
        widget.category != oldWidget.category ||
        widget.results.length != oldWidget.results.length;
    if (reset && _scroll.hasClients) _scroll.jumpTo(0);
    if (reset || _activeId(widget) != _activeId(oldWidget)) {
      _selectionReveal.reveal(
        _scroll,
        forward: reset || widget.activeIndex >= oldWidget.activeIndex,
      );
    }
  }

  @override
  void dispose() {
    _selectionReveal.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final hasQuery = widget.searchController.text.trim().isNotEmpty;
    final hasMatches = widget.results.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) => Material(
        color: Colors.transparent,
        child: Container(
          width: 440,
          constraints: BoxConstraints(
            maxHeight: constraints.hasBoundedHeight
                ? constraints.maxHeight
                : MediaQuery.sizeOf(context).height,
          ),
          decoration: BoxDecoration(
            color: colors.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search Input Row
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 4,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Row(
                          children: [
                            Icon(
                              Icons.search,
                              size: 18,
                              color: hasMatches ? colors.accent : colors.subtle,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: widget.searchController,
                                focusNode: widget.searchFocusNode,
                                autofocus: true,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.text,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search canvas... (Ctrl+F)',
                                  hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: colors.subtle,
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 0,
                                    vertical: 6,
                                  ),
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                                onSubmitted: (_) {
                                  if (hasMatches) {
                                    widget.onNext();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasQuery) ...[
                        // Match Counter Pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: hasMatches
                                ? colors.accent.withValues(alpha: 0.15)
                                : colors.raised,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            hasMatches
                                ? '${widget.activeIndex + 1} of ${widget.results.length}'
                                : '0 matches',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: hasMatches ? colors.accent : colors.subtle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Clear button
                        IconButton(
                          tooltip: 'Clear',
                          icon: Icon(
                            Icons.clear,
                            size: 16,
                            color: colors.subtle,
                          ),
                          splashRadius: 16,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          onPressed: () {
                            widget.searchController.clear();
                          },
                        ),
                      ],
                      // Prev button
                      IconButton(
                        tooltip: 'Previous (Shift+Enter)',
                        icon: Icon(
                          Icons.keyboard_arrow_up,
                          size: 18,
                          color: hasMatches
                              ? colors.text
                              : colors.subtle.withValues(alpha: 0.4),
                        ),
                        splashRadius: 16,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        onPressed: hasMatches ? widget.onPrevious : null,
                      ),
                      // Next button
                      IconButton(
                        tooltip: 'Next (Enter)',
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: hasMatches
                              ? colors.text
                              : colors.subtle.withValues(alpha: 0.4),
                        ),
                        splashRadius: 16,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        onPressed: hasMatches ? widget.onNext : null,
                      ),
                      if (hasMatches) ...[
                        // Toggle results drawer
                        IconButton(
                          tooltip: _isExpanded
                              ? 'Hide results'
                              : 'Show results',
                          icon: Icon(
                            _isExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 18,
                            color: colors.subtle,
                          ),
                          splashRadius: 16,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          onPressed: () {
                            setState(() => _isExpanded = !_isExpanded);
                            if (_isExpanded) {
                              _selectionReveal.reveal(_scroll);
                            } else {
                              _selectionReveal.cancel();
                            }
                          },
                        ),
                      ],
                      // Close button
                      IconButton(
                        tooltip: 'Close (Esc)',
                        icon: Icon(Icons.close, size: 16, color: colors.subtle),
                        splashRadius: 16,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        onPressed: widget.onClose,
                      ),
                    ],
                  ),
                ),

                Flexible(
                  child: CustomScrollView(
                    controller: _scroll,
                    shrinkWrap: true,
                    slivers: [
                      // Category filters and results share a bounded scroll surface.
                      SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.raised.withValues(alpha: 0.5),
                            border: Border(
                              top: BorderSide(
                                color: colors.border.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              _buildCategoryChip(
                                'All',
                                CanvasSearchCategory.all,
                                colors,
                              ),
                              const SizedBox(width: 4),
                              _buildCategoryChip(
                                'Cards',
                                CanvasSearchCategory.cards,
                                colors,
                              ),
                              const SizedBox(width: 4),
                              _buildCategoryChip(
                                'Text & Notes',
                                CanvasSearchCategory.text,
                                colors,
                              ),
                              const SizedBox(width: 4),
                              _buildCategoryChip(
                                'Shapes',
                                CanvasSearchCategory.shapes,
                                colors,
                              ),
                              const SizedBox(width: 4),
                              _buildCategoryChip(
                                'Media',
                                CanvasSearchCategory.media,
                                colors,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Expandable Match List
                      if (_isExpanded && hasMatches)
                        SliverList.builder(
                          itemCount: widget.results.length,
                          itemBuilder: (context, index) {
                            final item = widget.results[index];
                            final isSelected = index == widget.activeIndex;
                            return InkWell(
                              key: isSelected ? _selectionReveal.marker : null,
                              onTap: () {
                                widget.onSelectIndex(index);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colors.accent.withValues(alpha: 0.14)
                                      : Colors.transparent,
                                  border: Border(
                                    left: BorderSide(
                                      color: isSelected
                                          ? colors.accent
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _iconForElementType(item.elementType),
                                      size: 15,
                                      color: isSelected
                                          ? colors.accent
                                          : colors.subtle,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            item.title,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                              color: isSelected
                                                  ? colors.accent
                                                  : colors.text,
                                            ),
                                          ),
                                          if (item.snippet != item.title) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              item.snippet,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: colors.subtle,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.raised,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item.elementType,
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: colors.subtle,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(
    String label,
    CanvasSearchCategory cat,
    OrbitColors colors,
  ) {
    final selected = widget.category == cat;
    return InkWell(
      onTap: () => widget.onCategoryChanged(cat),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.raised,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : colors.subtle,
          ),
        ),
      ),
    );
  }

  IconData _iconForElementType(String type) {
    switch (type) {
      case 'card':
        return Icons.description_outlined;
      case 'sticky':
        return Icons.sticky_note_2_outlined;
      case 'text':
        return Icons.title;
      case 'frame':
        return Icons.crop_free;
      case 'column':
        return Icons.view_column_outlined;
      case 'rectangle':
      case 'ellipse':
      case 'diamond':
        return Icons.category_outlined;
      case 'arrow':
      case 'line':
      case 'connector':
        return Icons.arrow_forward;
      case 'image':
        return Icons.image_outlined;
      case 'link':
        return Icons.link;
      default:
        return Icons.extension_outlined;
    }
  }
}
