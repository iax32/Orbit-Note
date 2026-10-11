import 'package:flutter/material.dart';
import 'latex_document.dart';

/// Academic Document Inspector & Settings sidebar panel.
class LatexInspector extends StatefulWidget {
  const LatexInspector({
    super.key,
    required this.doc,
    required this.onDocChanged,
    this.onSelectBlock,
    this.onClose,
  });

  final LatexDocument doc;
  final ValueChanged<LatexDocument> onDocChanged;
  final ValueChanged<int>? onSelectBlock;
  final VoidCallback? onClose;

  @override
  State<LatexInspector> createState() => _LatexInspectorState();
}

class _LatexInspectorState extends State<LatexInspector> {
  int _activeTab =
      0; // 0: Structure/Outline, 1: Document Settings, 2: Packages & Preamble
  final TextEditingController _newPackageController = TextEditingController();
  late TextEditingController _preambleController;

  @override
  void initState() {
    super.initState();
    _preambleController = TextEditingController(text: widget.doc.preamble);
  }

  @override
  void didUpdateWidget(LatexInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.doc.preamble != widget.doc.preamble &&
        _preambleController.text != widget.doc.preamble) {
      _preambleController.text = widget.doc.preamble;
    }
  }

  @override
  void dispose() {
    _newPackageController.dispose();
    _preambleController.dispose();
    super.dispose();
  }

  void _update(LatexDocument Function(LatexDocument) fn) {
    final next = fn(widget.doc);
    widget.onDocChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF1E1F24) : Colors.white,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: theme.dividerColor)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'LaTeX Document',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (widget.onClose != null)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: widget.onClose,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 28,
                        height: 28,
                      ),
                      splashRadius: 14,
                    ),
                ],
              ),
            ),

            // Tabs
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  _tabButton(0, 'Outline', Icons.format_list_bulleted_rounded),
                  _tabButton(1, 'Format', Icons.settings_outlined),
                  _tabButton(2, 'Preamble', Icons.code_rounded),
                ],
              ),
            ),

            // Content
            Expanded(
              child: switch (_activeTab) {
                0 => _buildOutline(context),
                1 => _buildSettings(context),
                _ => _buildPreambleAndPackages(context),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(int index, String label, IconData icon) {
    final theme = Theme.of(context);
    final isSelected = _activeTab == index;
    final primary = theme.colorScheme.primary;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutline(BuildContext context) {
    final theme = Theme.of(context);
    final outlineItems =
        <({int index, String title, IconData icon, int depth})>[];

    for (var i = 0; i < widget.doc.blocks.length; i++) {
      final block = widget.doc.blocks[i];
      if (block.type == LatexBlockType.section) {
        outlineItems.add((
          index: i,
          title: block.rawContent,
          icon: Icons.title_rounded,
          depth: 0,
        ));
      } else if (block.type == LatexBlockType.subsection) {
        outlineItems.add((
          index: i,
          title: block.rawContent,
          icon: Icons.short_text_rounded,
          depth: 1,
        ));
      } else if (block.type == LatexBlockType.subsubsection) {
        outlineItems.add((
          index: i,
          title: block.rawContent,
          icon: Icons.notes_rounded,
          depth: 2,
        ));
      } else if (block.type == LatexBlockType.theorem) {
        final label = block.options.isNotEmpty
            ? '${block.environment} (${block.options})'
            : block.environment;
        outlineItems.add((
          index: i,
          title: label,
          icon: Icons.bookmark_border_rounded,
          depth: 1,
        ));
      } else if (block.type == LatexBlockType.proof) {
        outlineItems.add((
          index: i,
          title: 'Proof',
          icon: Icons.check_box_outline_blank_rounded,
          depth: 1,
        ));
      } else if (block.type == LatexBlockType.equation) {
        outlineItems.add((
          index: i,
          title: 'Equation',
          icon: Icons.functions_rounded,
          depth: 1,
        ));
      }
    }

    if (outlineItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No sections or blocks found in this document.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: outlineItems.length,
      itemBuilder: (context, idx) {
        final item = outlineItems[idx];
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.only(
            left: 16.0 + (item.depth * 16),
            right: 16,
          ),
          leading: Icon(
            item.icon,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          title: Text(
            item.title.isEmpty ? 'Untitled' : item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: item.depth == 0 ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          onTap: () => widget.onSelectBlock?.call(item.index),
        );
      },
    );
  }

  Widget _buildSettings(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Document Class',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue:
              [
                'article',
                'report',
                'book',
                'amsart',
                'exam',
              ].contains(widget.doc.documentClass)
              ? widget.doc.documentClass
              : 'article',
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: 'article',
              child: Text('Article (assignments, papers)'),
            ),
            DropdownMenuItem(
              value: 'report',
              child: Text('Report (longer projects)'),
            ),
            DropdownMenuItem(
              value: 'book',
              child: Text('Book (multi-chapter)'),
            ),
            DropdownMenuItem(value: 'amsart', child: Text('AMS-TeX Article')),
            DropdownMenuItem(
              value: 'exam',
              child: Text('Exam / Exercise Sheet'),
            ),
          ],
          onChanged: (v) {
            if (v != null) _update((d) => d.copyWith(documentClass: v));
          },
        ),

        const SizedBox(height: 18),
        Text(
          'Paper Size',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue:
              ['a4paper', 'letterpaper'].contains(widget.doc.paperSize)
              ? widget.doc.paperSize
              : 'a4paper',
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: 'a4paper',
              child: Text('A4 (International Standard)'),
            ),
            DropdownMenuItem(value: 'letterpaper', child: Text('US Letter')),
          ],
          onChanged: (v) {
            if (v != null) _update((d) => d.copyWith(paperSize: v));
          },
        ),

        const SizedBox(height: 18),
        Text(
          'Base Font Size',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: ['10pt', '11pt', '12pt'].contains(widget.doc.fontSize)
              ? widget.doc.fontSize
              : '11pt',
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: '10pt', child: Text('10 pt')),
            DropdownMenuItem(value: '11pt', child: Text('11 pt (Standard)')),
            DropdownMenuItem(value: '12pt', child: Text('12 pt (Large)')),
          ],
          onChanged: (v) {
            if (v != null) _update((d) => d.copyWith(fontSize: v));
          },
        ),

        const SizedBox(height: 18),
        Text(
          'Margins (Geometry)',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue:
              ['1in', '2cm', '1.25in', '1.5in'].contains(widget.doc.margins)
              ? widget.doc.margins
              : '1in',
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: '1in', child: Text('1 inch (Standard)')),
            DropdownMenuItem(value: '2cm', child: Text('2 cm (Compact)')),
            DropdownMenuItem(
              value: '1.25in',
              child: Text('1.25 inches (Wide)'),
            ),
            DropdownMenuItem(
              value: '1.5in',
              child: Text('1.5 inches (Thesis)'),
            ),
          ],
          onChanged: (v) {
            if (v != null) _update((d) => d.copyWith(margins: v));
          },
        ),
      ],
    );
  }

  Widget _buildPreambleAndPackages(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Active Packages',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: widget.doc.packages.map((pkg) {
            return Chip(
              label: Text(pkg, style: const TextStyle(fontSize: 12)),
              deleteIcon: const Icon(Icons.close_rounded, size: 14),
              onDeleted: () {
                final nextPkgs = List<String>.from(widget.doc.packages)
                  ..remove(pkg);
                _update((d) => d.copyWith(packages: nextPkgs));
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newPackageController,
                decoration: const InputDecoration(
                  hintText: 'e.g. tikz, booktabs',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onSubmitted: _addPackage,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              icon: const Icon(Icons.add_rounded, size: 18),
              onPressed: () => _addPackage(_newPackageController.text),
            ),
          ],
        ),

        const SizedBox(height: 24),
        Text(
          'Custom Preamble & Macros',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          r'Define custom \newcommand or configurations here.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _preambleController,
          maxLines: 8,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: r'\newcommand{\R}{\mathbb{R}}',
          ),
          onChanged: (v) => _update((d) => d.copyWith(preamble: v)),
        ),
      ],
    );
  }

  void _addPackage(String pkg) {
    final clean = pkg.trim();
    if (clean.isEmpty || widget.doc.packages.contains(clean)) return;
    final nextPkgs = List<String>.from(widget.doc.packages)..add(clean);
    _newPackageController.clear();
    _update((d) => d.copyWith(packages: nextPkgs));
  }
}
