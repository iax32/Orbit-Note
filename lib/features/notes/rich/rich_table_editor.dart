import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../markdown_clipboard.dart';
import 'markdown_document.dart';
import 'rich_clipboard.dart';
import 'structured_text_projection.dart';

class RichTableEditor extends StatefulWidget {
  const RichTableEditor({
    super.key,
    required this.source,
    required this.onChanged,
    required this.onUndo,
    required this.onRedo,
    this.onFocused,
    this.textStyle,
  });
  final String source;
  final ValueChanged<String> onChanged;
  final VoidCallback onUndo, onRedo;
  final VoidCallback? onFocused;
  final TextStyle? textStyle;
  @override
  State<RichTableEditor> createState() => RichTableEditorState();
}

class RichTableEditorState extends State<RichTableEditor> {
  late MarkdownTable table = MarkdownTable.tryParse(widget.source)!;
  final controllers = <(int, int), TextEditingController>{};
  final nodes = <(int, int), FocusNode>{};
  final cellContexts = <(int, int), BuildContext>{};
  String? emitted;
  int _revision = 0, _clipboardRequest = 0;
  int row = 0, col = 0;
  (int, int)? _selectionAnchor, _selectionFocus;
  (int, int)? _pointerCell;
  Offset? _pointerOrigin;
  bool _dragSelecting = false;

  bool get hasRectangleSelection =>
      _selectionAnchor != null &&
      _selectionFocus != null &&
      _selectionAnchor != _selectionFocus;

  (int, int, int, int)? get selectedRectangle {
    final anchor = _selectionAnchor, focus = _selectionFocus;
    if (anchor == null || focus == null || anchor == focus) return null;
    return (
      anchor.$1 <= focus.$1 ? anchor.$1 : focus.$1,
      anchor.$1 >= focus.$1 ? anchor.$1 : focus.$1,
      anchor.$2 <= focus.$2 ? anchor.$2 : focus.$2,
      anchor.$2 >= focus.$2 ? anchor.$2 : focus.$2,
    );
  }

  bool isCellSelected(int r, int c) {
    final range = selectedRectangle;
    return range != null &&
        r >= range.$1 &&
        r <= range.$2 &&
        c >= range.$3 &&
        c <= range.$4;
  }

  /// Selects a rectangular range using table row/column coordinates.
  /// Coordinates include the header row at index 0.
  void selectRectangle({
    required int startRow,
    required int startColumn,
    required int endRow,
    required int endColumn,
  }) {
    final maxRow = table.rows.length - 1;
    final maxColumn = table.columns - 1;
    _selectionAnchor = (
      startRow.clamp(0, maxRow),
      startColumn.clamp(0, maxColumn),
    );
    _selectionFocus = (endRow.clamp(0, maxRow), endColumn.clamp(0, maxColumn));
    row = _selectionFocus!.$1;
    col = _selectionFocus!.$2;
    setState(() {});
  }

  void clearRectangleSelection() {
    if (_selectionAnchor == null && _selectionFocus == null) return;
    _selectionAnchor = null;
    _selectionFocus = null;
    setState(() {});
  }

  (int, int)? _cellAtGlobalPosition(Offset position) {
    for (final entry in cellContexts.entries) {
      final renderObject = entry.value.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) continue;
      final origin = renderObject.localToGlobal(Offset.zero);
      if ((origin & renderObject.size).contains(position)) return entry.key;
    }
    return null;
  }

  void _pointerDown(PointerDownEvent event) {
    if (event.buttons & kPrimaryButton == 0) return;
    final cell = _cellAtGlobalPosition(event.position);
    if (cell == null) return;
    _pointerCell = cell;
    _pointerOrigin = event.position;
    _dragSelecting = false;
  }

  void _pointerMove(PointerMoveEvent event) {
    final anchor = _pointerCell, origin = _pointerOrigin;
    if (anchor == null ||
        origin == null ||
        event.buttons & kPrimaryButton == 0) {
      return;
    }
    final cell = _cellAtGlobalPosition(event.position);
    if (cell == null) return;
    if (!_dragSelecting && (event.position - origin).distance < 6) return;
    _dragSelecting = true;
    _selectionAnchor = anchor;
    _selectionFocus = cell;
    row = cell.$1;
    col = cell.$2;
    setState(() {});
  }

  void _pointerUp(PointerEvent event) {
    if (_dragSelecting) setState(() {});
    _pointerCell = null;
    _pointerOrigin = null;
    _dragSelecting = false;
  }

  void _tapCell(int r, int c) {
    final extend = HardwareKeyboard.instance.isShiftPressed;
    if (extend && _selectionAnchor != null) {
      _selectionFocus = (r, c);
    } else {
      _selectionAnchor = (r, c);
      _selectionFocus = (r, c);
    }
    row = r;
    col = c;
    setState(() {});
  }

  void _moveSelection(int rowDelta, int columnDelta) {
    final current = _selectionFocus ?? (row, col);
    final nextRow = (current.$1 + rowDelta).clamp(0, table.rows.length - 1);
    final nextColumn = (current.$2 + columnDelta).clamp(0, table.columns - 1);
    if (HardwareKeyboard.instance.isShiftPressed) {
      _selectionAnchor ??= current;
      _selectionFocus = (nextRow, nextColumn);
    } else {
      _selectionAnchor = (nextRow, nextColumn);
      _selectionFocus = (nextRow, nextColumn);
    }
    row = nextRow;
    col = nextColumn;
    setState(() {});
  }

  TextSelection? get sourceSelection {
    final source = emitted ?? widget.source;
    final cell = MarkdownTable.sourceCells(
      source,
    ).where((c) => c.row == row && c.column == col).firstOrNull;
    final controller = controllers[(row, col)];
    if (cell == null || controller == null || !controller.selection.isValid) {
      return null;
    }
    final projection = StructuredTextProjection.cell(
      source.substring(cell.start, cell.end),
    );
    return TextSelection(
      baseOffset:
          cell.start + projection.sourceOffset(controller.selection.baseOffset),
      extentOffset:
          cell.start +
          projection.sourceOffset(
            controller.selection.extentOffset,
            end: !controller.selection.isCollapsed,
          ),
    );
  }

  bool selectSource(int offset, {int length = 0}) {
    final source = emitted ?? widget.source;
    final cells = MarkdownTable.sourceCells(source);
    if (cells.isEmpty) return false;
    final cell =
        cells.where((c) => offset >= c.start && offset <= c.end).firstOrNull ??
        (offset <= cells.first.start ? cells.first : cells.last);
    final controller = controllers[(cell.row, cell.column)];
    final focus = nodes[(cell.row, cell.column)];
    if (controller == null || focus == null) return false;
    final projection = StructuredTextProjection.cell(
      source.substring(cell.start, cell.end),
    );
    final start = projection.visibleOffset(
      (offset - cell.start).clamp(0, cell.end - cell.start),
    );
    final end = projection.visibleOffset(
      (offset + length - cell.start).clamp(0, cell.end - cell.start),
    );
    final selection = TextSelection(baseOffset: start, extentOffset: end);
    row = cell.row;
    col = cell.column;
    _selectionAnchor = (row, col);
    _selectionFocus = (row, col);
    controller.selection = selection;
    focus.requestFocus();
    final revision = _revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          revision != _revision ||
          controller.selection != selection) {
        return;
      }
      final context = focus.context;
      if (context != null) Scrollable.ensureVisible(context, alignment: .15);
    });
    return true;
  }

  @override
  void didUpdateWidget(RichTableEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.source != emitted && widget.source != oldWidget.source) {
      emitted = null;
      table = MarkdownTable.tryParse(widget.source)!;
      _revision++;
      _sync();
    }
  }

  void _sync() {
    cellContexts.removeWhere(
      (key, _) => key.$1 >= table.rows.length || key.$2 >= table.columns,
    );
    for (final entry in controllers.entries) {
      final (r, c) = entry.key;
      final valid = r < table.rows.length && c < table.columns;
      final text = valid ? MarkdownTable.visibleCell(table.rows[r][c]) : '';
      if (!valid) nodes[entry.key]?.unfocus();
      if (entry.value.text != text) {
        entry.value.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(
            offset: entry.value.selection.extentOffset.clamp(0, text.length),
          ),
        );
      }
    }
    row = row.clamp(0, table.rows.length - 1);
    col = col.clamp(0, table.columns - 1);
    final range = selectedRectangle;
    if (range != null) {
      final maxRow = table.rows.length - 1;
      final maxColumn = table.columns - 1;
      _selectionAnchor = (
        range.$1.clamp(0, maxRow).toInt(),
        range.$3.clamp(0, maxColumn).toInt(),
      );
      _selectionFocus = (
        range.$2.clamp(0, maxRow).toInt(),
        range.$4.clamp(0, maxColumn).toInt(),
      );
    }
  }

  void changed() {
    _revision++;
    emitted = table.encode();
    widget.onChanged(emitted!);
    setState(() {});
  }

  void operation(String action) {
    row = row.clamp(0, table.rows.length - 1);
    col = col.clamp(0, table.columns - 1);
    switch (action) {
      case 'copy-csv':
        unawaited(copySelectionAsCsv());
        return;
      case 'copy-html':
        unawaited(copySelectionAsHtml());
        return;
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
    row = row.clamp(0, table.rows.length - 1);
    col = col.clamp(0, table.columns - 1);
    changed();
    _focusCell(row, col);
  }

  void _focusCell(int r, int c) {
    final revision = _revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _revision) return;
      row = r;
      col = c;
      nodes[(r, c)]?.requestFocus();
    });
  }

  void _clipboardError() {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text(
          'Could not access the clipboard. Your table is unchanged.',
        ),
      ),
    );
  }

  List<List<String>>? _parseCsv(String value) {
    if (value.isEmpty) return null;
    final normalized = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    // Infer the separator from the first physical row while respecting quoted
    // fields. A tab inside a quoted CSV value must not turn comma data into TSV.
    var quoted = false;
    var tabs = 0;
    var commas = 0;
    for (var i = 0; i < normalized.length; i++) {
      final character = normalized[i];
      if (character == '"') {
        if (quoted && i + 1 < normalized.length && normalized[i + 1] == '"') {
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (!quoted && character == '\n') {
        break;
      } else if (!quoted && character == '\t') {
        tabs++;
      } else if (!quoted && character == ',') {
        commas++;
      }
    }
    final delimiter = tabs > 0 && tabs >= commas ? '\t' : ',';
    final rows = <List<String>>[];
    var cells = <String>[];
    var current = StringBuffer();
    quoted = false;
    var fieldStart = true;
    var sawValue = false;
    void finishRow() {
      cells.add(current.toString());
      final hasContent = sawValue || cells.length > 1 || cells.first.isNotEmpty;
      if (hasContent) rows.add(cells);
      cells = <String>[];
      current = StringBuffer();
      fieldStart = true;
      sawValue = false;
    }

    for (var i = 0; i < normalized.length; i++) {
      final character = normalized[i];
      if (character == '"') {
        if (quoted && i + 1 < normalized.length && normalized[i + 1] == '"') {
          current.write('"');
          sawValue = true;
          i++;
        } else if (quoted) {
          quoted = false;
        } else if (fieldStart) {
          quoted = true;
          fieldStart = false;
          sawValue = true;
        } else {
          current.write(character);
          sawValue = true;
          fieldStart = false;
        }
      } else if (!quoted && character == delimiter) {
        cells.add(current.toString());
        current = StringBuffer();
        fieldStart = true;
        sawValue = false;
      } else if (!quoted && character == '\n') {
        finishRow();
      } else {
        current.write(character);
        fieldStart = false;
        sawValue = true;
      }
    }
    if (quoted || current.isNotEmpty || cells.isNotEmpty || sawValue) {
      finishRow();
    }
    if (rows.isEmpty) return null;
    return rows;
  }

  List<List<String>>? _parseHtmlTable(String html) {
    final markdown = htmlToMarkdown(html);
    final parsed = MarkdownTable.tryParse(markdown);
    if (parsed == null) return null;
    return parsed.rows
        .map(
          (cells) =>
              cells.map(MarkdownTable.visibleCell).toList(growable: false),
        )
        .toList(growable: false);
  }

  Future<List<List<String>>?> _readGridClipboard() async {
    try {
      final html = await Clipboard.getData('text/html');
      final value = html?.text;
      if (value != null &&
          RegExp(r'<table(?:\s|>)', caseSensitive: false).hasMatch(value)) {
        final grid = _parseHtmlTable(value);
        if (grid != null && grid.isNotEmpty) return grid;
      }
    } catch (_) {
      // Providers may expose text/plain but reject text/html.
    }
    try {
      final plain = await Clipboard.getData(Clipboard.kTextPlain);
      final value = plain?.text;
      return value == null || value.isEmpty ? null : _parseCsv(value);
    } catch (_) {
      _clipboardError();
      return null;
    }
  }

  String _gridText({bool csv = false}) {
    final range = selectedRectangle;
    final minRow = range?.$1 ?? row;
    final maxRow = range?.$2 ?? row;
    final minColumn = range?.$3 ?? col;
    final maxColumn = range?.$4 ?? col;
    final delimiter = csv ? ',' : '\t';
    String encode(String value) =>
        csv ? '"${value.replaceAll('"', '""')}"' : value;
    return List.generate(
      maxRow - minRow + 1,
      (r) => List.generate(
        maxColumn - minColumn + 1,
        (c) => encode(
          MarkdownTable.visibleCell(table.rows[minRow + r][minColumn + c]),
        ),
      ).join(delimiter),
    ).join('\n');
  }

  Future<void> copyCell() async {
    final text = _gridText();
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {
      _clipboardError();
    }
  }

  Future<void> copySelection() async {
    if (!hasRectangleSelection) {
      await copyCell();
      return;
    }
    try {
      await Clipboard.setData(ClipboardData(text: _gridText()));
    } catch (_) {
      _clipboardError();
    }
  }

  Future<void> copySelectionAsCsv() async {
    try {
      await Clipboard.setData(ClipboardData(text: _gridText(csv: true)));
    } catch (_) {
      _clipboardError();
    }
  }

  String _gridHtml() {
    final range = selectedRectangle;
    final minRow = range?.$1 ?? row;
    final maxRow = range?.$2 ?? row;
    final minColumn = range?.$3 ?? col;
    final maxColumn = range?.$4 ?? col;
    String escape(String value) => value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAllMapped(
          RegExp(r'&lt;br&gt;', caseSensitive: false),
          (_) => '<br>',
        );
    final rows = <String>[];
    for (var r = minRow; r <= maxRow; r++) {
      final tag = r == 0 ? 'th' : 'td';
      final cells = List.generate(
        maxColumn - minColumn + 1,
        (c) =>
            '<$tag>${escape(MarkdownTable.visibleCell(table.rows[r][minColumn + c]))}</$tag>',
      ).join();
      rows.add('<tr>$cells</tr>');
    }
    return '<table><tbody>${rows.join()}</tbody></table>';
  }

  Future<void> copySelectionAsHtml() async {
    final accepted = await writeRichClipboard(
      plainText: _gridText(),
      html: _gridHtml(),
    );
    if (!accepted) _clipboardError();
  }

  Future<void> pasteGrid({bool atCaret = false}) async {
    final selected = selectedRectangle;
    final atRow = !atCaret && selected != null ? selected.$1 : row;
    final atCol = !atCaret && selected != null ? selected.$3 : col;
    final before = widget.source;
    final revision = _revision, request = ++_clipboardRequest;
    final controller = controllers[(atRow, atCol)];
    final value = controller?.value;
    List<List<String>>? rows;
    try {
      rows = await _readGridClipboard();
    } catch (_) {
      _clipboardError();
      return;
    }
    if (!mounted ||
        rows == null ||
        widget.source != before ||
        _revision != revision ||
        _clipboardRequest != request ||
        row != atRow ||
        col != atCol ||
        controller?.value != value ||
        atCaret && nodes[(atRow, atCol)]?.hasFocus != true) {
      return;
    }
    if (rows.isEmpty) return;
    final selection = value?.selection;
    if (atCaret &&
        rows.length == 1 &&
        rows.first.length == 1 &&
        controller != null) {
      final text = rows.first.first;
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
      _sync();
      changed();
    }
    _focusCell(index ~/ table.columns, index % table.columns);
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
    'copy-csv': 'Copy selection as CSV',
    'copy-html': 'Copy selection as HTML',
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

  KeyEventResult _handleCellKey(
    int r,
    int c,
    TextEditingController controller,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent || !controller.value.composing.isCollapsed) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed || keyboard.isMetaPressed) {
      if (event.logicalKey == LogicalKeyboardKey.keyC &&
          hasRectangleSelection) {
        unawaited(copySelection());
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyA) {
        selectRectangle(
          startRow: 0,
          startColumn: 0,
          endRow: table.rows.length - 1,
          endColumn: table.columns - 1,
        );
        return KeyEventResult.handled;
      }
    }
    if (event.logicalKey == LogicalKeyboardKey.escape &&
        hasRectangleSelection) {
      clearRectangleSelection();
      return KeyEventResult.handled;
    }
    if (keyboard.isShiftPressed) {
      final delta = switch (event.logicalKey) {
        LogicalKeyboardKey.arrowUp => (-1, 0),
        LogicalKeyboardKey.arrowDown => (1, 0),
        LogicalKeyboardKey.arrowLeft => (0, -1),
        LogicalKeyboardKey.arrowRight => (0, 1),
        _ => null,
      };
      if (delta != null) {
        _moveSelection(delta.$1, delta.$2);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              hasRectangleSelection
                  ? '${selectedRectangle!.$2 - selectedRectangle!.$1 + 1} × ${selectedRectangle!.$4 - selectedRectangle!.$3 + 1} selected'
                  : '${table.rows.length - 1} rows · ${table.columns} columns',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          IconButton(
            tooltip: hasRectangleSelection
                ? 'Copy selected cells'
                : 'Copy cell',
            onPressed: copySelection,
            icon: const Icon(Icons.copy, size: 16),
          ),
          IconButton(
            tooltip: 'Paste cells (TSV, CSV, or HTML)',
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
        child: Listener(
          onPointerDown: _pointerDown,
          onPointerMove: _pointerMove,
          onPointerUp: _pointerUp,
          onPointerCancel: _pointerUp,
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
                          cellContexts[(r, c)] = context;
                          final controller = controllers.putIfAbsent(
                            (r, c),
                            () => TextEditingController(
                              text: MarkdownTable.visibleCell(table.rows[r][c]),
                            ),
                          );
                          final focus = nodes.putIfAbsent((r, c), () {
                            final node = FocusNode(
                              onKeyEvent: (_, event) {
                                if (event is! KeyDownEvent) {
                                  return KeyEventResult.ignored;
                                }
                                if (!controller.value.composing.isCollapsed) {
                                  return (HardwareKeyboard
                                                  .instance
                                                  .isControlPressed ||
                                              HardwareKeyboard
                                                  .instance
                                                  .isMetaPressed) &&
                                          {
                                            LogicalKeyboardKey.keyZ,
                                            LogicalKeyboardKey.keyY,
                                          }.contains(event.logicalKey)
                                      ? KeyEventResult.handled
                                      : KeyEventResult.ignored;
                                }
                                final tableKey = _handleCellKey(
                                  r,
                                  c,
                                  controller,
                                  event,
                                );
                                if (tableKey != KeyEventResult.ignored) {
                                  return tableKey;
                                }
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.tab) {
                                  navigate(
                                    r,
                                    c,
                                    HardwareKeyboard.instance.isShiftPressed,
                                  );
                                  return KeyEventResult.handled;
                                }
                                if (HardwareKeyboard
                                        .instance
                                        .isControlPressed ||
                                    HardwareKeyboard.instance.isMetaPressed) {
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
                            );
                            node.addListener(() {
                              if (node.hasFocus) {
                                row = r;
                                col = c;
                                widget.onFocused?.call();
                              }
                            });
                            return node;
                          });
                          final field = TextField(
                            key: ValueKey('rich-cell-$r-$c'),
                            controller: controller,
                            focusNode: focus,
                            maxLines: null,
                            style: (widget.textStyle ?? const TextStyle())
                                .copyWith(
                                  fontWeight: r == 0
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                ),
                            textAlign:
                                table.alignments[c].startsWith(':') &&
                                    table.alignments[c].endsWith(':')
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
                              _tapCell(r, c);
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
                                    for (final item
                                        in state.contextMenuButtonItems)
                                      if (item.type ==
                                          ContextMenuButtonType.paste)
                                        ContextMenuButtonItem(
                                          type: item.type,
                                          label: item.label,
                                          onPressed: () {
                                            state.hideToolbar();
                                            _tapCell(r, c);
                                            pasteGrid(atCaret: true);
                                          },
                                        )
                                      else
                                        item,
                                    for (final action in actions.entries)
                                      ContextMenuButtonItem(
                                        label: action.value,
                                        onPressed: () {
                                          state.hideToolbar();
                                          _tapCell(r, c);
                                          operation(action.key);
                                        },
                                      ),
                                  ],
                                ),
                          );
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              color: isCellSelected(r, c)
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primary.withValues(alpha: .18)
                                  : null,
                              border: isCellSelected(r, c)
                                  ? Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      width: 1.2,
                                    )
                                  : null,
                            ),
                            child: field,
                          );
                        },
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    ],
  );
}
