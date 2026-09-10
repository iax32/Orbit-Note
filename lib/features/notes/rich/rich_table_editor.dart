import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'markdown_document.dart';

class RichTableEditor extends StatefulWidget {
  const RichTableEditor({
    super.key,
    required this.source,
    required this.onChanged,
    required this.onUndo,
    required this.onRedo,
  });
  final String source;
  final ValueChanged<String> onChanged;
  final VoidCallback onUndo, onRedo;
  @override
  State<RichTableEditor> createState() => _RichTableEditorState();
}

class _RichTableEditorState extends State<RichTableEditor> {
  late MarkdownTable table = MarkdownTable.tryParse(widget.source)!;
  final controllers = <(int, int), TextEditingController>{};
  final nodes = <(int, int), FocusNode>{};
  String? emitted;
  int row = 0, col = 0;
  @override
  void didUpdateWidget(RichTableEditor old) {
    super.didUpdateWidget(old);
    if (widget.source != emitted && widget.source != old.source) {
      table = MarkdownTable.tryParse(widget.source)!;
      _sync();
    }
  }

  void _sync() {
    for (final entry in controllers.entries) {
      final (r, c) = entry.key;
      if (r < table.rows.length && c < table.columns) {
        final text = table.rows[r][c].replaceAll(r'\|', '|');
        if (entry.value.text != text) {
          entry.value.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(
              offset: entry.value.selection.extentOffset.clamp(0, text.length),
            ),
          );
        }
      }
    }
  }

  void changed() {
    emitted = table.encode();
    widget.onChanged(emitted!);
    setState(() {});
  }

  void operation(String action) {
    row = row.clamp(0, table.rows.length - 1);
    col = col.clamp(0, table.columns - 1);
    switch (action) {
      case 'above':
        if (table.rows.length < 1000) {
          table.rows.insert(row == 0 ? 1 : row, List.filled(table.columns, ''));
        }
      case 'below':
        if (table.rows.length < 1000) {
          table.rows.insert(row + 1, List.filled(table.columns, ''));
        }
      case 'delete-row':
        if (row > 0) table.rows.removeAt(row);
      case 'left':
      case 'right':
        if (table.columns >= 50) return;
        final at = action == 'left' ? col : col + 1;
        table.alignments.insert(at, '---');
        for (final r in table.rows) {
          r.insert(at, '');
        }
      case 'delete-column':
        if (table.columns <= 1) return;
        table.alignments.removeAt(col);
        for (final r in table.rows) {
          r.removeAt(col);
        }
      case 'align-left':
        table.alignments[col] = ':---';
      case 'align-center':
        table.alignments[col] = ':---:';
      case 'align-right':
        table.alignments[col] = '---:';
    }
    _sync();
    changed();
  }

  Future<void> pasteGrid({bool atCaret = false}) async {
    final atRow = row, atCol = col;
    final before = widget.source;
    final controller = controllers[(atRow, atCol)];
    final selection = controller?.selection;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted || data?.text == null || widget.source != before) return;
    final text = data!.text!
        .replaceAll('\r\n', '\n')
        .replaceFirst(RegExp(r'\n$'), '');
    if (atCaret &&
        !data.text!.contains(RegExp(r'[\t\r\n]')) &&
        controller != null) {
      if (controller.selection != selection) return;
      final range = selection?.isValid == true
          ? selection!
          : TextSelection.collapsed(offset: controller.text.length);
      final next = controller.text.replaceRange(range.start, range.end, text);
      controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: range.start + text.length),
      );
      table.rows[atRow][atCol] = MarkdownTable.cellText(next);
      changed();
      return;
    }
    final rows = text.split('\n').map((l) => l.split('\t')).toList();
    final width = rows.fold(0, (n, r) => n > r.length ? n : r.length);
    if (atRow + rows.length > 1000 || atCol + width > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This paste exceeds the editable table limit (1,000 rows / 50 columns). Paste it into Source to retain the full text.',
          ),
        ),
      );
      return;
    }
    while (table.columns < atCol + width) {
      table.alignments.add('---');
      for (final r in table.rows) {
        r.add('');
      }
    }
    while (table.rows.length < atRow + rows.length) {
      table.rows.add(List.filled(table.columns, ''));
    }
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        table.rows[atRow + r][atCol + c] = MarkdownTable.cellText(rows[r][c]);
      }
    }
    _sync();
    changed();
  }

  void navigate(int r, int c, bool backward) {
    var index = r * table.columns + c + (backward ? -1 : 1);
    if (index < 0) return;
    if (index >= table.rows.length * table.columns) {
      if (table.rows.length >= 1000) return;
      table.rows.add(List.filled(table.columns, ''));
      changed();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        row = index ~/ table.columns;
        col = index % table.columns;
        nodes[(index ~/ table.columns, index % table.columns)]?.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    for (final n in nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  static const actions = <String, String>{
    'above': 'Add row above',
    'below': 'Add row below',
    'delete-row': 'Delete row',
    'left': 'Add column left',
    'right': 'Add column right',
    'delete-column': 'Delete column',
    'align-left': 'Align left',
    'align-center': 'Align center',
    'align-right': 'Align right',
  };
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              '${table.rows.length - 1} rows · ${table.columns} columns',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          IconButton(
            tooltip: 'Copy cell',
            onPressed: () => Clipboard.setData(
              ClipboardData(
                text: table
                    .rows[row.clamp(0, table.rows.length - 1)][col.clamp(
                      0,
                      table.columns - 1,
                    )]
                    .replaceAll(r'\|', '|'),
              ),
            ),
            icon: const Icon(Icons.copy, size: 16),
          ),
          IconButton(
            tooltip: 'Paste cells (TSV)',
            onPressed: pasteGrid,
            icon: const Icon(Icons.content_paste, size: 16),
          ),
          PopupMenuButton<String>(
            tooltip: 'Table operations',
            onSelected: operation,
            itemBuilder: (_) => actions.entries
                .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
          ),
        ],
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(170),
          border: TableBorder.all(color: Theme.of(context).dividerColor),
          children: [
            for (var r = 0; r < table.rows.length; r++)
              TableRow(
                decoration: r == 0
                    ? BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      )
                    : null,
                children: [
                  for (var c = 0; c < table.columns; c++)
                    Builder(
                      builder: (context) {
                        final controller = controllers.putIfAbsent(
                          (r, c),
                          () => TextEditingController(
                            text: table.rows[r][c].replaceAll(r'\|', '|'),
                          ),
                        );
                        final focus = nodes.putIfAbsent(
                          (r, c),
                          () => FocusNode(
                            onKeyEvent: (_, event) {
                              if (event is! KeyDownEvent) {
                                return KeyEventResult.ignored;
                              }
                              if (!controller.value.composing.isCollapsed) {
                                return HardwareKeyboard
                                            .instance
                                            .isControlPressed &&
                                        {
                                          LogicalKeyboardKey.keyZ,
                                          LogicalKeyboardKey.keyY,
                                        }.contains(event.logicalKey)
                                    ? KeyEventResult.handled
                                    : KeyEventResult.ignored;
                              }
                              if (event.logicalKey == LogicalKeyboardKey.tab) {
                                navigate(
                                  r,
                                  c,
                                  HardwareKeyboard.instance.isShiftPressed,
                                );
                                return KeyEventResult.handled;
                              }
                              if (HardwareKeyboard.instance.isControlPressed) {
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.keyZ) {
                                  HardwareKeyboard.instance.isShiftPressed
                                      ? widget.onRedo()
                                      : widget.onUndo();
                                  return KeyEventResult.handled;
                                }
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.keyY) {
                                  widget.onRedo();
                                  return KeyEventResult.handled;
                                }
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.keyV) {
                                  row = r;
                                  col = c;
                                  pasteGrid(atCaret: true);
                                  return KeyEventResult.handled;
                                }
                              }
                              return KeyEventResult.ignored;
                            },
                          ),
                        );
                        return TextField(
                          key: ValueKey('rich-cell-$r-$c'),
                          controller: controller,
                          focusNode: focus,
                          maxLines: null,
                          style: TextStyle(
                            fontWeight: r == 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          textAlign: table.alignments[c] == ':---:'
                              ? TextAlign.center
                              : table.alignments[c].endsWith(':')
                              ? TextAlign.right
                              : TextAlign.left,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.all(10),
                          ),
                          onTap: () {
                            row = r;
                            col = c;
                          },
                          onChanged: (value) {
                            row = r;
                            col = c;
                            table.rows[r][c] = MarkdownTable.cellText(value);
                            changed();
                          },
                          contextMenuBuilder: (context, state) =>
                              AdaptiveTextSelectionToolbar.buttonItems(
                                anchors: state.contextMenuAnchors,
                                buttonItems: [
                                  ...state.contextMenuButtonItems,
                                  for (final action in actions.entries)
                                    ContextMenuButtonItem(
                                      label: action.value,
                                      onPressed: () {
                                        state.hideToolbar();
                                        row = r;
                                        col = c;
                                        operation(action.key);
                                      },
                                    ),
                                ],
                              ),
                        );
                      },
                    ),
                ],
              ),
          ],
        ),
      ),
    ],
  );
}
