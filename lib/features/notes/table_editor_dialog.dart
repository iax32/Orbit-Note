import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';

enum ColumnAlign {
  left('Left', ':---'),
  center('Center', ':---:'),
  right('Right', '---:');

  const ColumnAlign(this.label, this.markdown);
  final String label;
  final String markdown;
}

/// Shows the Visual Markdown Table Generator dialog matching MOT-02.
Future<String?> showMarkdownTableDialog(BuildContext context) =>
    showOrbitDialog<String>(
      context: context,
      builder: (ctx) => const MarkdownTableDialog(),
    );

/// Visual Table Generator dialog for structured note documentation (EDT-06).
class MarkdownTableDialog extends StatefulWidget {
  const MarkdownTableDialog({super.key});

  @override
  State<MarkdownTableDialog> createState() => _MarkdownTableDialogState();
}

class _MarkdownTableDialogState extends State<MarkdownTableDialog> {
  int _rows = 3;
  int _cols = 3;
  late List<TextEditingController> _headerControllers;
  late List<ColumnAlign> _alignments;

  @override
  void initState() {
    super.initState();
    _initColumns();
  }

  void _initColumns() {
    _headerControllers = List.generate(
      _cols,
      (i) => TextEditingController(text: 'Column ${i + 1}'),
    );
    _alignments = List.generate(_cols, (_) => ColumnAlign.left);
  }

  @override
  void dispose() {
    for (final c in _headerControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _updateColumnCount(int newCols) {
    if (newCols == _cols || newCols < 2 || newCols > 6) return;
    setState(() {
      if (newCols > _cols) {
        for (int i = _cols; i < newCols; i++) {
          _headerControllers.add(
            TextEditingController(text: 'Column ${i + 1}'),
          );
          _alignments.add(ColumnAlign.left);
        }
      } else {
        while (_headerControllers.length > newCols) {
          _headerControllers.removeLast().dispose();
          _alignments.removeLast();
        }
      }
      _cols = newCols;
    });
  }

  String _generateMarkdown() {
    final buffer = StringBuffer();
    // Header row
    buffer.write('| ');
    for (int i = 0; i < _cols; i++) {
      final name = _headerControllers[i].text.trim().replaceAll('|', '-');
      buffer.write(name.isEmpty ? 'Header' : name);
      buffer.write(' | ');
    }
    buffer.writeln();

    // Alignment row
    buffer.write('| ');
    for (int i = 0; i < _cols; i++) {
      buffer.write(_alignments[i].markdown);
      buffer.write(' | ');
    }
    buffer.writeln();

    // Data rows
    for (int r = 0; r < _rows; r++) {
      buffer.write('| ');
      for (int c = 0; c < _cols; c++) {
        buffer.write('       | ');
      }
      buffer.writeln();
    }

    return '\n${buffer.toString()}\n';
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);

    return OrbitDialog(
      title: Row(
        children: [
          Icon(Icons.table_chart_outlined, size: 20, color: colors.accent),
          const SizedBox(width: 8),
          const Text('Insert Markdown Table'),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dimension controls
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'COLUMNS: $_cols',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: colors.subtle,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            IconButton.filledTonal(
                              key: const ValueKey('table-cols-minus'),
                              icon: const Icon(Icons.remove, size: 16),
                              onPressed: _cols > 2
                                  ? () => _updateColumnCount(_cols - 1)
                                  : null,
                              constraints: const BoxConstraints.tightFor(
                                width: 32,
                                height: 32,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$_cols',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              key: const ValueKey('table-cols-plus'),
                              icon: const Icon(Icons.add, size: 16),
                              onPressed: _cols < 6
                                  ? () => _updateColumnCount(_cols + 1)
                                  : null,
                              constraints: const BoxConstraints.tightFor(
                                width: 32,
                                height: 32,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ROWS: $_rows',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: colors.subtle,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            IconButton.filledTonal(
                              key: const ValueKey('table-rows-minus'),
                              icon: const Icon(Icons.remove, size: 16),
                              onPressed: _rows > 1
                                  ? () => setState(() => _rows--)
                                  : null,
                              constraints: const BoxConstraints.tightFor(
                                width: 32,
                                height: 32,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$_rows',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              key: const ValueKey('table-rows-plus'),
                              icon: const Icon(Icons.add, size: 16),
                              onPressed: _rows < 10
                                  ? () => setState(() => _rows++)
                                  : null,
                              constraints: const BoxConstraints.tightFor(
                                width: 32,
                                height: 32,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Column definitions (Headers & Alignments)
              Text(
                'COLUMN HEADERS & ALIGNMENT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: colors.subtle,
                ),
              ),
              const SizedBox(height: 8),

              for (int i = 0; i < _cols; i++) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: ValueKey('table-col-header-$i'),
                          controller: _headerControllers[i],
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: 'Column ${i + 1}',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      DropdownButton<ColumnAlign>(
                        key: ValueKey('table-col-align-$i'),
                        value: _alignments[i],
                        underline: const SizedBox.shrink(),
                        items: ColumnAlign.values.map((align) {
                          return DropdownMenuItem(
                            value: align,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(switch (align) {
                                  ColumnAlign.left =>
                                    Icons.format_align_left_rounded,
                                  ColumnAlign.center =>
                                    Icons.format_align_center_rounded,
                                  ColumnAlign.right =>
                                    Icons.format_align_right_rounded,
                                }, size: 15),
                                const SizedBox(width: 6),
                                Text(
                                  align.label,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _alignments[i] = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Preview container
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.raised,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MARKDOWN PREVIEW',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: colors.subtle,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _generateMarkdown().trim(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('table-cancel-btn'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const ValueKey('table-insert-btn'),
          onPressed: () => Navigator.pop(context, _generateMarkdown()),
          icon: const Icon(Icons.table_rows_rounded, size: 16),
          label: const Text('Insert Table'),
        ),
      ],
    );
  }
}
