import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';

class ShortcutEntry {
  const ShortcutEntry({
    required this.category,
    required this.title,
    required this.keys,
    this.description,
  });

  final String category;
  final String title;
  final List<String> keys;
  final String? description;
}

const orbitShortcutsList = <ShortcutEntry>[
  ShortcutEntry(
    category: 'Document Review',
    title: 'Comment on selected passage',
    keys: ['Ctrl', 'Alt', 'M'],
  ),
  ShortcutEntry(
    category: 'Interface',
    title: 'Zoom in (whole app)',
    keys: ['Ctrl', '+'],
  ),
  ShortcutEntry(
    category: 'Interface',
    title: 'Zoom out (whole app)',
    keys: ['Ctrl', '-'],
  ),
  ShortcutEntry(
    category: 'Interface',
    title: 'Reset app zoom',
    keys: ['Ctrl', '0'],
  ),
  // Text Formatting
  ShortcutEntry(
    category: 'Text Formatting',
    title: 'Bold',
    keys: ['Ctrl', 'B'],
  ),
  ShortcutEntry(
    category: 'Text Formatting',
    title: 'Italic',
    keys: ['Ctrl', 'I'],
  ),
  ShortcutEntry(
    category: 'Text Formatting',
    title: 'Underline',
    keys: ['Ctrl', 'U'],
  ),
  ShortcutEntry(
    category: 'Text Formatting',
    title: 'Highlight',
    keys: ['Ctrl', 'Shift', 'H'],
  ),
  ShortcutEntry(
    category: 'Text Formatting',
    title: 'Insert link or internal note',
    keys: ['Ctrl', 'K'],
  ),
  ShortcutEntry(
    category: 'Text Formatting',
    title: 'Insert current date (YYYY-MM-DD)',
    keys: ['Ctrl', 'Shift', 'D'],
  ),
  ShortcutEntry(
    category: 'Text Formatting',
    title: 'Copy entire note (Markdown)',
    keys: ['Ctrl', 'Shift', 'C'],
    description: 'Copies entire document markdown to clipboard',
  ),

  // Navigation & Finding
  ShortcutEntry(
    category: 'Navigation & Search',
    title: 'Find in note',
    keys: ['Ctrl', 'F'],
  ),
  ShortcutEntry(
    category: 'Navigation & Search',
    title: 'Find & Replace',
    keys: ['Ctrl', 'H'],
  ),
  ShortcutEntry(
    category: 'Navigation & Search',
    title: 'Document revision history',
    keys: ['Alt', 'H'],
    description:
        'Inspect previous snapshots, view line diffs, and restore prior versions',
  ),
  ShortcutEntry(
    category: 'Navigation & Search',
    title: 'Bionic speed reading toggle',
    keys: ['Alt', 'B'],
    description:
        'Toggle academic saccade eye-fixation bolding in read and split modes',
  ),
  ShortcutEntry(
    category: 'Navigation & Search',
    title: 'Go to line',
    keys: ['Ctrl', 'G'],
    description: 'Jump to specific line and column in document',
  ),
  ShortcutEntry(
    category: 'Navigation & Search',
    title: 'Quick Switcher (Jump to document)',
    keys: ['Ctrl', 'E'],
    description: 'Instantly jump between tabs, recent documents, and bookmarks',
  ),
  ShortcutEntry(
    category: 'Navigation & Search',
    title: 'Collapse / Expand all folders in Explorer',
    keys: ['Ctrl', 'Shift', 'E'],
    description: 'Toggles all folders collapsed or expanded in Explorer',
  ),
  ShortcutEntry(
    category: 'Navigation & Search',
    title: 'Duplicate document in Explorer',
    keys: ['Ctrl', 'D'],
    description: 'Duplicates the focused note, canvas, or view',
  ),
  ShortcutEntry(
    category: 'Navigation & Search',
    title: 'Command palette',
    keys: ['Ctrl', 'P'],
  ),
  ShortcutEntry(
    category: 'Navigation & Search',
    title: 'Keyboard shortcuts',
    keys: ['Ctrl', '/'],
  ),
  ShortcutEntry(
    category: 'Navigation & Search',
    title: 'Toggle Focus Mode',
    keys: ['F11'],
  ),
  ShortcutEntry(
    category: 'Navigation & Search',
    title: 'Toggle Outline panel',
    keys: ['Alt', 'O'],
  ),

  // Editor Modes
  ShortcutEntry(
    category: 'Editor Modes',
    title: 'Rich Editor',
    keys: ['Alt', '1'],
  ),
  ShortcutEntry(
    category: 'Editor Modes',
    title: 'Source Mode',
    keys: ['Alt', '2'],
  ),
  ShortcutEntry(
    category: 'Editor Modes',
    title: 'Split Mode',
    keys: ['Alt', '3'],
  ),
  ShortcutEntry(
    category: 'Editor Modes',
    title: 'Read Mode',
    keys: ['Alt', '4'],
  ),

  // Blocks & Structure
  ShortcutEntry(
    category: 'Blocks & Structure',
    title: 'Slash command menu',
    keys: ['/'],
    description: 'Insert headings, tables, callouts, dates, math',
  ),
  ShortcutEntry(
    category: 'Blocks & Structure',
    title: 'Link to note or object',
    keys: ['[', '['],
  ),
  ShortcutEntry(
    category: 'Blocks & Structure',
    title: 'Duplicate selected block(s)',
    keys: ['Ctrl', 'D'],
  ),
  ShortcutEntry(
    category: 'Blocks & Structure',
    title: 'Duplicate line downwards',
    keys: ['Shift', 'Alt', '↓'],
    description: 'Duplicate current line or selected lines below',
  ),
  ShortcutEntry(
    category: 'Blocks & Structure',
    title: 'Move line / block up',
    keys: ['Alt', '↑'],
    description: 'Move current line or block up',
  ),
  ShortcutEntry(
    category: 'Blocks & Structure',
    title: 'Move line / block down',
    keys: ['Alt', '↓'],
    description: 'Move current line or block down',
  ),
  ShortcutEntry(
    category: 'Blocks & Structure',
    title: 'Select all blocks',
    keys: ['Ctrl', 'A'],
  ),

  // Mathematics & Academic
  ShortcutEntry(
    category: 'Math & Academic',
    title: 'Inline math equation',
    keys: [r'$', r'$'],
    description: 'Type \$expression\$ for inline KaTeX math',
  ),
  ShortcutEntry(
    category: 'Math & Academic',
    title: 'Display block equation',
    keys: [r'$$', r'$$'],
    description: 'Type \$\$ on a new line for standalone display math',
  ),
  ShortcutEntry(
    category: 'Math & Academic',
    title: 'Insert today date command',
    keys: ['/date'],
  ),
  ShortcutEntry(
    category: 'Math & Academic',
    title: 'Insert current timestamp',
    keys: ['/time'],
  ),
];

/// Displays the keyboard shortcuts cheatsheet modal.
Future<void> showShortcutsCheatsheet(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => const _ShortcutsDialogView(),
  );
}

class _ShortcutsDialogView extends StatefulWidget {
  const _ShortcutsDialogView();

  @override
  State<_ShortcutsDialogView> createState() => _ShortcutsDialogViewState();
}

class _ShortcutsDialogViewState extends State<_ShortcutsDialogView> {
  final TextEditingController _search = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = OrbitColors.of(context);

    final filtered = orbitShortcutsList.where((s) {
      if (_filter.isEmpty) return true;
      final q = _filter.toLowerCase();
      return s.title.toLowerCase().contains(q) ||
          s.category.toLowerCase().contains(q) ||
          s.keys.any((k) => k.toLowerCase().contains(q)) ||
          (s.description?.toLowerCase().contains(q) ?? false);
    }).toList();

    // Group by category
    final categories = <String, List<ShortcutEntry>>{};
    for (final s in filtered) {
      categories.putIfAbsent(s.category, () => []).add(s);
    }

    return Dialog(
      backgroundColor: c.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 660),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.keyboard_outlined,
                      size: 18,
                      color: c.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Keyboard Shortcuts',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: c.text,
                          ),
                        ),
                        Text(
                          'Quick navigation, formatting, and authoring shortcuts',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: c.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Bar
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: c.raised,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 16, color: c.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _search,
                        autofocus: false,
                        style: TextStyle(fontSize: 12, color: c.text),
                        decoration: InputDecoration(
                          hintText: 'Search shortcuts…',
                          hintStyle: TextStyle(fontSize: 12, color: c.muted),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                        ),
                        onChanged: (v) => setState(() => _filter = v.trim()),
                      ),
                    ),
                    if (_filter.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _search.clear();
                          setState(() => _filter = '');
                        },
                        child: Icon(Icons.clear, size: 14, color: c.muted),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Shortcuts List
              Expanded(
                child: categories.isEmpty
                    ? Center(
                        child: Text(
                          'No shortcuts matching "$_filter"',
                          style: TextStyle(color: c.muted, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        itemCount: categories.length,
                        itemBuilder: (ctx, idx) {
                          final category = categories.keys.elementAt(idx);
                          final items = categories[category]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 12,
                                  bottom: 6,
                                  left: 4,
                                ),
                                child: Text(
                                  category.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: c.accent,
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: c.raised,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: c.border),
                                ),
                                child: Column(
                                  children: [
                                    for (var i = 0; i < items.length; i++) ...[
                                      if (i > 0)
                                        Divider(
                                          height: 1,
                                          color: c.border.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    items[i].title,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: c.text,
                                                    ),
                                                  ),
                                                  if (items[i].description !=
                                                      null)
                                                    Text(
                                                      items[i].description!,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: c.muted,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            OrbitShortcutRow(
                                              keys: items[i].keys,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
