import '../../../app/orbit_components.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../note_find_index.dart';
import 'code_block.dart';
import 'code_editing.dart';
import 'document_history.dart';
import 'code_surface.dart';
import '../../../app/orbit_theme.dart';

/// A draft editor. Apply returns one change through the owning note's history.
class CodeWorkspace extends StatefulWidget {
  const CodeWorkspace({
    super.key,
    required this.code,
    required this.language,
    required this.canApply,
    this.readOnly = false,
    this.originalCode,
    this.initialComparison = false,
  });
  final String code, language;
  final bool Function() canApply;
  final bool readOnly;
  final String? originalCode;
  final bool initialComparison;
  @override
  State<CodeWorkspace> createState() => _CodeWorkspaceState();
}

class _CodeWorkspaceState extends State<CodeWorkspace> {
  late final editor = CodeController(
    text: widget.code,
    language: widget.language,
  );
  final query = TextEditingController();
  final replacement = TextEditingController();
  final focus = FocusNode();
  final queryFocus = FocusNode();
  final replaceFocus = FocusNode();
  late final original = CodeController(
    text: widget.originalCode ?? widget.code,
    language: widget.language,
  );
  final originalFocus = FocusNode();
  final draftSurface = GlobalKey();
  final originalSurface = GlobalKey();
  late final originalLines = codeLines(widget.originalCode ?? widget.code);
  final history = DocumentHistory();
  final _undoSelections = <(TextSelection, TextSelection)>[];
  final _redoSelections = <(TextSelection, TextSelection)>[];
  late TextEditingValue _committed;
  bool _replaying = false;
  bool wrap = false, matchCase = false, wholeWord = false, replacing = false;
  late bool comparison = widget.initialComparison;
  bool numbers = true;
  String? _lineSource;
  List<({int start, int contentEnd, int end})> _lines = [];
  List<({int start, int contentEnd, int end})> get lines {
    if (_lineSource != editor.text) {
      _lineSource = editor.text;
      _lines = codeLines(editor.text);
    }
    return _lines;
  }

  String unit = '  ';
  String? status;
  NoteFindIndex? _index;
  String? _searchKey;
  List<NoteFindMatch> _matches = [];

  @override
  void initState() {
    super.initState();
    editor.selection = const TextSelection.collapsed(offset: 0);
    _committed = editor.value;
    editor.addListener(editorChanged);
    query.addListener(refresh);
  }

  bool defaultsLoaded = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!defaultsLoaded) {
      final p = OrbitCodePreferences.of(context);
      wrap = p.wrap;
      numbers = p.lineNumbers;
      defaultsLoaded = true;
    }
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  void editorChanged() {
    if (!_replaying && editor.value.composing.isCollapsed) {
      if (_committed.text != editor.text) {
        history.record(_committed.text, editor.text);
        _undoSelections.add((_committed.selection, editor.selection));
        _redoSelections.clear();
        if (_undoSelections.length > 200) _undoSelections.removeAt(0);
      }
      _committed = editor.value;
    }
    refresh();
  }

  void undoDraft({bool redo = false}) {
    if (widget.readOnly ||
        !editor.value.composing.isCollapsed ||
        !(redo ? history.canRedo : history.canUndo)) {
      return;
    }
    final pair = (redo ? _redoSelections : _undoSelections).removeLast();
    (redo ? _undoSelections : _redoSelections).add(pair);
    final text = redo ? history.redo(editor.text) : history.undo(editor.text);
    final selection = redo ? pair.$2 : pair.$1;
    _replaying = true;
    editor.value = TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: selection.baseOffset.clamp(0, text.length),
        extentOffset: selection.extentOffset.clamp(0, text.length),
      ),
    );
    _committed = editor.value;
    _replaying = false;
    focus.requestFocus();
  }

  @override
  void dispose() {
    editor.removeListener(editorChanged);
    query.removeListener(refresh);
    editor.dispose();
    original.dispose();
    originalFocus.dispose();
    query.dispose();
    replacement.dispose();
    focus.dispose();
    queryFocus.dispose();
    replaceFocus.dispose();
    super.dispose();
  }

  List<NoteFindMatch> get matches {
    if (_index?.source != editor.text) {
      _index = NoteFindIndex(editor.text, rich: false);
      _searchKey = null;
    }
    final key = '$matchCase/$wholeWord/${query.text}';
    if (_searchKey != key) {
      _searchKey = key;
      _matches = _index!.matches(
        query.text,
        matchCase: matchCase,
        wholeWord: wholeWord,
      );
    }
    return _matches;
  }

  void findNext({bool previous = false}) {
    if (query.text.isEmpty) return;
    final found = matches;
    if (found.isEmpty) {
      setState(() => status = 'No matches');
      return;
    }
    final selection = editor.selection;
    final offset = selection.isValid
        ? (previous ? selection.start : selection.end)
        : 0;
    final match = previous
        ? found.where((m) => m.end <= offset).lastOrNull ?? found.last
        : found.where((m) => m.start >= offset).firstOrNull ?? found.first;
    editor.selection = TextSelection(
      baseOffset: match.start,
      extentOffset: match.end,
    );
    setState(() => status = null);
    focus.requestFocus();
  }

  void edit(TextEditingValue Function(TextEditingValue) operation) {
    if (widget.readOnly || !editor.value.composing.isCollapsed) return;
    try {
      editor.value = operation(editor.value);
      setState(() => status = null);
    } on FormatException catch (error) {
      setState(() => status = error.message);
    }
    focus.requestFocus();
  }

  void replace({bool all = false}) {
    if (widget.readOnly ||
        !editor.value.composing.isCollapsed ||
        query.text.isEmpty) {
      return;
    }
    final found = matches;
    if (found.isEmpty) {
      setState(() => status = 'No matches');
      return;
    }
    final selected = found
        .where(
          (m) =>
              editor.selection.start == m.start &&
              editor.selection.end == m.end,
        )
        .firstOrNull;
    if (!all && selected == null) {
      findNext();
      return;
    }
    final edits = all ? found : [selected!];
    var text = editor.text;
    for (final m in edits.reversed) {
      text = text.replaceRange(m.start, m.end, replacement.text);
    }
    final caret = edits.first.start + replacement.text.length;
    editor.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret),
    );
    setState(
      () =>
          status = '${edits.length} replacement${edits.length == 1 ? '' : 's'}',
    );
    focus.requestFocus();
  }

  Future<void> goToLine() async {
    var entry = '';
    final line = await showOrbitDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Go to line'),
        content: TextFormField(
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Line number',
            helperText: '1–${codeLines(editor.text).length}',
          ),
          onChanged: (v) => entry = v,
          onFieldSubmitted: (v) => Navigator.pop(context, int.tryParse(v) ?? 0),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(entry) ?? 0),
            child: const Text('Go'),
          ),
        ],
      ),
    );
    if (!mounted || line == null) return;
    final lines = codeLines(editor.text);
    if (line < 1 || line > lines.length) {
      setState(() => status = 'Choose a line from 1 to ${lines.length}.');
      return;
    }
    editor.selection = TextSelection.collapsed(offset: lines[line - 1].start);
    focus.requestFocus();
  }

  void action(String value) {
    switch (value) {
      case 'line':
        goToLine();
      case 'duplicate':
        edit(duplicateCodeLines);
      case 'up':
        edit((v) => moveCodeLines(v, down: false));
      case 'down':
        edit((v) => moveCodeLines(v, down: true));
      case 'comment':
        edit((v) => toggleCodeComments(v, widget.language));
      case 'copy':
        Clipboard.setData(ClipboardData(text: editor.text));
        setState(() => status = 'Draft copied');
      case 'delete':
        edit(deleteCodeLines);
      case 'trim':
        edit(trimCodeWhitespace);
      case 'reset':
        edit(
          (_) => TextEditingValue(
            text: widget.code,
            selection: const TextSelection.collapsed(offset: 0),
          ),
        );
      case 'numbers':
        setState(() => numbers = !numbers);
      case 'wrap-round':
        edit((v) => wrapCodeSelection(v, '(', ')'));
      case 'wrap-square':
        edit((v) => wrapCodeSelection(v, '[', ']'));
      case 'wrap-braces':
        edit((v) => wrapCodeSelection(v, '{', '}'));
      case 'wrap-quotes':
        edit((v) => wrapCodeSelection(v, '"', '"'));
      case 'wrap-ticks':
        edit((v) => wrapCodeSelection(v, '`', '`'));
    }
  }

  KeyEventResult keyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent || !editor.value.composing.isCollapsed) {
      return KeyEventResult.ignored;
    }
    final keys = HardwareKeyboard.instance;
    final control = keys.isControlPressed || keys.isMetaPressed;
    final key = event.logicalKey;
    if (control && key == LogicalKeyboardKey.keyF) {
      queryFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (control && key == LogicalKeyboardKey.keyH && !widget.readOnly) {
      setState(() => replacing = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) replaceFocus.requestFocus();
      });
      return KeyEventResult.handled;
    }
    if (control && key == LogicalKeyboardKey.keyG) {
      goToLine();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f3) {
      findNext(previous: keys.isShiftPressed);
      return KeyEventResult.handled;
    }
    if (widget.readOnly || !focus.hasFocus) return KeyEventResult.ignored;
    if (control &&
        (key == LogicalKeyboardKey.keyZ || key == LogicalKeyboardKey.keyY)) {
      undoDraft(redo: key == LogicalKeyboardKey.keyY || keys.isShiftPressed);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab && !control && !keys.isAltPressed) {
      edit((v) => indentCode(v, outdent: keys.isShiftPressed, unit: unit));
      return KeyEventResult.handled;
    }
    if (control &&
        key == LogicalKeyboardKey.slash &&
        supportsCodeComments(widget.language)) {
      action('comment');
      return KeyEventResult.handled;
    }
    if (control && key == LogicalKeyboardKey.keyD) {
      action('duplicate');
      return KeyEventResult.handled;
    }
    if (control && keys.isShiftPressed && key == LogicalKeyboardKey.keyK) {
      action('delete');
      return KeyEventResult.handled;
    }
    if (keys.isAltPressed &&
        !control &&
        (key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowDown)) {
      action(key == LogicalKeyboardKey.arrowUp ? 'up' : 'down');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter &&
        !control &&
        !keys.isAltPressed &&
        !keys.isShiftPressed) {
      edit((v) => newlineCode(v, unit: unit, language: widget.language));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final lines = this.lines;
    final caret = editor.selection.isValid ? editor.selection.extentOffset : 0;
    final lineIndex = codeLineAt(lines, caret.clamp(0, editor.text.length));
    final found = query.text.isEmpty ? const <NoteFindMatch>[] : matches;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: size.width * .9,
        height: size.height * .85,
        child: Focus(
          onKeyEvent: keyEvent,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: SizedBox(
                height: math.max(
                  constraints.maxHeight,
                  500 * scale.clamp(1, 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${widget.language.isEmpty ? 'Code' : widget.language} editor',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Compare original and draft',
                            isSelected: comparison,
                            icon: const Icon(Icons.compare_arrows),
                            onPressed: () =>
                                setState(() => comparison = !comparison),
                          ),
                          IconButton(
                            tooltip: 'Close code editor',
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            PopupMenuButton<String>(
                              popUpAnimationStyle: OrbitMotionScope.popupStyle(
                                context,
                              ),
                              tooltip: 'Code actions',
                              onSelected: action,
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'line',
                                  child: Text('Go to line · Ctrl+G'),
                                ),
                                const PopupMenuItem(
                                  value: 'copy',
                                  child: Text('Copy draft'),
                                ),
                                PopupMenuItem(
                                  value: 'numbers',
                                  child: Text(
                                    numbers
                                        ? 'Hide line numbers'
                                        : 'Show line numbers',
                                  ),
                                ),
                                if (!widget.readOnly) ...[
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete lines · Ctrl+Shift+K'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'trim',
                                    child: Text('Trim trailing whitespace'),
                                  ),
                                  PopupMenuItem(
                                    value: 'reset',
                                    enabled: editor.text != widget.code,
                                    child: const Text(
                                      'Reset draft to original',
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'wrap-round',
                                    child: Text('Wrap selection in ( )'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'wrap-square',
                                    child: Text('Wrap selection in [ ]'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'wrap-braces',
                                    child: Text('Wrap selection in { }'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'wrap-quotes',
                                    child: Text('Wrap selection in " "'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'wrap-ticks',
                                    child: Text('Wrap selection in ` `'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'duplicate',
                                    child: Text('Duplicate lines · Ctrl+D'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'up',
                                    child: Text('Move lines up · Alt+↑'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'down',
                                    child: Text('Move lines down · Alt+↓'),
                                  ),
                                  if (supportsCodeComments(widget.language))
                                    const PopupMenuItem(
                                      value: 'comment',
                                      child: Text('Toggle comments · Ctrl+/'),
                                    ),
                                ],
                              ],
                            ),
                            IconButton(
                              tooltip: 'Undo draft',
                              onPressed: !widget.readOnly && history.canUndo
                                  ? () => undoDraft()
                                  : null,
                              icon: const Icon(Icons.undo),
                            ),
                            IconButton(
                              tooltip: 'Redo draft',
                              onPressed: !widget.readOnly && history.canRedo
                                  ? () => undoDraft(redo: true)
                                  : null,
                              icon: const Icon(Icons.redo),
                            ),
                            FilterChip(
                              label: const Text('Wrap lines'),
                              selected: wrap,
                              onSelected: (v) => setState(() => wrap = v),
                            ),
                            if (!widget.readOnly) ...[
                              TextButton(
                                onPressed: () =>
                                    edit((v) => indentCode(v, unit: unit)),
                                child: const Text('Indent'),
                              ),
                              TextButton(
                                onPressed: () => edit(
                                  (v) =>
                                      indentCode(v, unit: unit, outdent: true),
                                ),
                                child: const Text('Outdent'),
                              ),
                              DropdownButton<String>(
                                value: unit,
                                hint: const Text('Indentation'),
                                items: const [
                                  DropdownMenuItem(
                                    value: '  ',
                                    child: Text('2 spaces'),
                                  ),
                                  DropdownMenuItem(
                                    value: '    ',
                                    child: Text('4 spaces'),
                                  ),
                                  DropdownMenuItem(
                                    value: '\t',
                                    child: Text('Tabs'),
                                  ),
                                ],
                                onChanged: (v) => setState(() => unit = v!),
                              ),
                            ],
                          ],
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: 145 * scale.clamp(1, 2),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  SizedBox(
                                    width: math.min(
                                      220,
                                      constraints.maxWidth - 32,
                                    ),
                                    child: TextField(
                                      controller: query,
                                      focusNode: queryFocus,
                                      onSubmitted: (_) => findNext(),
                                      decoration: const InputDecoration(
                                        labelText: 'Find in code',
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => findNext(previous: true),
                                    child: const Text('Previous match'),
                                  ),
                                  TextButton(
                                    onPressed: findNext,
                                    child: const Text('Next match'),
                                  ),
                                  FilterChip(
                                    label: const Text('Match case'),
                                    selected: matchCase,
                                    onSelected: (v) =>
                                        setState(() => matchCase = v),
                                  ),
                                  FilterChip(
                                    label: const Text('Whole word'),
                                    selected: wholeWord,
                                    onSelected: (v) =>
                                        setState(() => wholeWord = v),
                                  ),
                                  if (!widget.readOnly)
                                    FilterChip(
                                      label: const Text('Replace'),
                                      selected: replacing,
                                      onSelected: (v) =>
                                          setState(() => replacing = v),
                                    ),
                                ],
                              ),
                              if (replacing && !widget.readOnly)
                                Wrap(
                                  spacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: math.min(
                                        220,
                                        constraints.maxWidth - 32,
                                      ),
                                      child: TextField(
                                        controller: replacement,
                                        focusNode: replaceFocus,
                                        decoration: const InputDecoration(
                                          labelText: 'Replace with',
                                          isDense: true,
                                        ),
                                        onSubmitted: (_) => replace(),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => replace(),
                                      child: const Text('Replace selected'),
                                    ),
                                    TextButton(
                                      onPressed: () => replace(all: true),
                                      child: const Text('Replace all'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, area) {
                            Widget pane(bool isOriginal) => DecoratedBox(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    if (comparison)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: Text(
                                            isOriginal ? 'Original' : 'Draft',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.labelLarge,
                                          ),
                                        ),
                                      ),
                                    Expanded(
                                      child: CodeSurface(
                                        key: isOriginal
                                            ? originalSurface
                                            : draftSurface,
                                        controller: isOriginal
                                            ? original
                                            : editor,
                                        focus: isOriginal
                                            ? originalFocus
                                            : focus,
                                        fieldKey: ValueKey(
                                          isOriginal
                                              ? 'code-workspace-original'
                                              : 'code-workspace-editor',
                                        ),
                                        lines: isOriginal
                                            ? originalLines
                                            : lines,
                                        wrap: wrap,
                                        numbers: numbers,
                                        readOnly: isOriginal || widget.readOnly,
                                        autofocus: !isOriginal,
                                        onChanged: (_) =>
                                            setState(() => status = null),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                            if (!comparison) return pane(false);
                            final panes = [
                              Expanded(child: pane(true)),
                              SizedBox(width: 8, height: 8),
                              Expanded(child: pane(false)),
                            ];
                            return area.maxWidth < 800 || scale > 1.4
                                ? Column(children: panes)
                                : Row(children: panes);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 90),
                        child: SingleChildScrollView(
                          child: Text(
                            status ??
                                '${editor.text == widget.code ? 'Unchanged' : 'Modified'} · ${lines.length} lines · Ln ${lineIndex + 1}, Col ${caret - lines[lineIndex].start + 1}${query.text.isEmpty ? '' : ' · ${found.length} matches'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                      if (!widget.readOnly)
                        FilledButton(
                          onPressed: () {
                            if (!editor.value.composing.isCollapsed) {
                              setState(
                                () => status =
                                    'Finish composing text before applying.',
                              );
                              return;
                            }
                            if (!widget.canApply()) {
                              setState(
                                () => status =
                                    'The source changed. Copy your draft before closing; reopen to edit the new source.',
                              );
                              return;
                            }
                            Navigator.pop(context, editor.text);
                          },
                          child: const Text('Apply to note'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
