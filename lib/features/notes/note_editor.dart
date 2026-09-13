import '../../app/orbit_components.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../domain/wiki_links.dart';
import 'markdown_editing.dart';
import 'note_format_toolbar.dart';
import 'note_link_dialog.dart';
import 'note_outline.dart';
import 'rich/rich_markdown_editor.dart';
import 'rich/document_history.dart';
import 'rich/note_math.dart';
import 'rich/note_highlight.dart';
import 'rich/note_underline.dart';
import 'rich/callout_block.dart';
import 'rich/equation_editor.dart';
import 'rich/code_block.dart';

enum NoteEditorMode { rich, write, split, read }

enum FindScope { document, selection }

/// A Markdown editor and preview. The application owns save/conflict semantics.
class NoteEditor extends StatefulWidget {
  const NoteEditor({
    super.key,
    required this.noteId,
    required this.title,
    required this.body,
    required this.onTitleChanged,
    required this.onBodyChanged,
    required this.linkTargets,
    required this.onOpenObject,
    this.fontSize = 16,
    this.contentWidth = 780,
    this.initialScrollOffset = 0,
    this.onScrollChanged,
    this.imageBuilder,
    this.onInsertAttachment,
    this.onPasteImage,
    this.onOpenExternalLink,
    this.onOpenAttachment,
    this.initialViewState = const {},
    this.onViewStateChanged,
    this.linkBindings = const {},
    this.onClosePane,
    this.onCreateTask,
    this.icon,
    this.cover,
    this.onIconChanged,
    this.onCoverChanged,
    this.pdfSource,
    this.onOpenPdfSource,
  });

  final String noteId;
  final String title;
  final String body;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onBodyChanged;
  final List<NoteLinkTarget> linkTargets;
  final ValueChanged<String> onOpenObject;
  final double fontSize;
  final double contentWidth;
  final double initialScrollOffset;
  final ValueChanged<double>? onScrollChanged;
  final Widget Function(BuildContext, String)? imageBuilder;

  /// Return portable Markdown to insert, or null if the picker is cancelled.
  final Future<String?> Function()? onInsertAttachment;
  final Future<String?> Function()? onPasteImage;
  final ValueChanged<String>? onOpenExternalLink;
  final ValueChanged<String>? onOpenAttachment;
  final Map<String, dynamic> initialViewState;
  final Map<String, String> linkBindings;
  final VoidCallback? onClosePane;
  final ValueChanged<Map<String, dynamic>>? onViewStateChanged;
  final Future<void> Function(String title)? onCreateTask;
  final String? icon;
  final String? cover;
  final ValueChanged<String?>? onIconChanged;
  final ValueChanged<String?>? onCoverChanged;
  final Map<String, dynamic>? pdfSource;
  final void Function(String fileId, int page)? onOpenPdfSource;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late final TextEditingController _title = TextEditingController(
    text: widget.title,
  );
  late final TextEditingController _body = TextEditingController(
    text: widget.body,
  );
  final TextEditingController _find = TextEditingController();
  final TextEditingController _replacement = TextEditingController();
  final FocusNode _bodyFocus = FocusNode();
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _findFocus = FocusNode();
  final UndoHistoryController _undo = UndoHistoryController();
  final _history = DocumentHistory();
  final _richKey = GlobalKey<RichMarkdownEditorState>();
  final _sourceFieldKey = GlobalKey();
  late String _historyText = widget.body;
  bool _historyPaused = false;
  late double _splitRatio =
      (widget.initialViewState['splitRatio'] as num? ?? .5).toDouble().clamp(
        .2,
        .8,
      );
  late Map<String, dynamic> _richState = widget.initialViewState['rich'] is Map
      ? Map<String, dynamic>.from(widget.initialViewState['rich'] as Map)
      : {};
  late final ScrollController _sourceScroll = ScrollController(
    initialScrollOffset: math.max(0, widget.initialScrollOffset),
  );
  late final ScrollController _previewScroll = ScrollController(
    initialScrollOffset: _offset('previewScroll'),
  );
  NoteEditorMode _mode = NoteEditorMode.write;
  bool _showFind = false;
  bool _inserting = false;
  int _findCount = 0;
  FindScope _findScope = FindScope.document;
  int _scopeStart = 0;
  int _scopeEnd = 0;
  int _currentMatchIndex = 0;
  bool _matchCase = false;
  bool _matchWholeWord = false;
  TextSelection _lastSelection = const TextSelection.collapsed(offset: -1);
  late double _lastPreviewOffset = _offset('previewScroll');

  @override
  void initState() {
    super.initState();
    _mode = NoteEditorMode.values.firstWhere(
      (m) => m.name == widget.initialViewState['mode'],
      orElse: () => NoteEditorMode.rich,
    );
    final base = widget.initialViewState['base'];
    final extent = widget.initialViewState['extent'];
    _body.selection = TextSelection(
      baseOffset: base is int ? base.clamp(0, _body.text.length) : 0,
      extentOffset: extent is int ? extent.clamp(0, _body.text.length) : 0,
    );
    _body.addListener(_recordView);
    _body.addListener(_recordBody);
    _body.addListener(_recordSelection);
    _undo.onUndo.addListener(_undoDocument);
    _undo.onRedo.addListener(_redoDocument);
    _bodyFocus.onKeyEvent = _sourceKey;
    _previewScroll.addListener(_recordView);
    _sourceScroll.addListener(_recordScroll);
  }

  void _recordSelection() {
    if (_lastSelection != _body.selection) {
      _lastSelection = _body.selection;
      if (mounted) setState(() {});
    }
  }

  double _offset(String key) {
    final value = widget.initialViewState[key];
    return value is num && value.isFinite ? value.toDouble().clamp(0, 1e8) : 0;
  }

  void _recordView() {
    if (_previewScroll.hasClients) _lastPreviewOffset = _previewScroll.offset;
    widget.onViewStateChanged?.call({
      'mode': _mode.name,
      'base': _body.selection.baseOffset.clamp(0, _body.text.length),
      'extent': _body.selection.extentOffset.clamp(0, _body.text.length),
      'previewScroll': _lastPreviewOffset,
      'splitRatio': _splitRatio,
      'rich': _richState,
    });
  }

  void _jumpToHeading(NoteHeading heading) {
    if (_mode == NoteEditorMode.rich) {
      _richKey.currentState?.jumpTo(heading.offset);
      return;
    }
    if (_mode == NoteEditorMode.read) {
      setState(() => _mode = NoteEditorMode.split);
    }
    _body.selection = TextSelection.collapsed(offset: heading.offset);
    _bodyFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      EditableTextState? editable;
      void visit(Element element) {
        if (element is StatefulElement && element.state is EditableTextState) {
          editable = element.state as EditableTextState;
        }
        element.visitChildElements(visit);
      }

      _sourceFieldKey.currentContext?.visitChildElements(visit);
      editable?.bringIntoView(TextPosition(offset: heading.offset));
    });
    _recordView();
  }

  void _recordScroll() => widget.onScrollChanged?.call(_sourceScroll.offset);

  @override
  void didUpdateWidget(NoteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.noteId != widget.noteId) {
      _title.text = widget.title;
      _body.text = widget.body;
      _find.clear();
      _showFind = false;
      _findScope = FindScope.document;
      _currentMatchIndex = 0;
      _scopeStart = 0;
      _scopeEnd = 0;
      _mode = NoteEditorMode.values.firstWhere(
        (m) => m.name == widget.initialViewState['mode'],
        orElse: () => NoteEditorMode.rich,
      );
      _splitRatio = (widget.initialViewState['splitRatio'] as num? ?? .5)
          .toDouble()
          .clamp(.2, .8);
      _richState = widget.initialViewState['rich'] is Map
          ? Map<String, dynamic>.from(widget.initialViewState['rich'] as Map)
          : {};
      final base = widget.initialViewState['base'];
      final extent = widget.initialViewState['extent'];
      _body.selection = TextSelection(
        baseOffset: base is int ? base.clamp(0, _body.text.length) : 0,
        extentOffset: extent is int ? extent.clamp(0, _body.text.length) : 0,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _sourceScroll.hasClients) {
          _sourceScroll.jumpTo(
            widget.initialScrollOffset.clamp(
              0,
              _sourceScroll.position.maxScrollExtent,
            ),
          );
        }
        if (mounted && _previewScroll.hasClients) {
          _previewScroll.jumpTo(
            _offset(
              'previewScroll',
            ).clamp(0, _previewScroll.position.maxScrollExtent),
          );
        }
      });
    } else {
      _syncController(_title, widget.title);
      _syncController(_body, widget.body);
    }
  }

  void _syncController(TextEditingController controller, String text) {
    if (controller.text == text) return;
    if (identical(controller, _body)) {
      _history.clear();
      _historyPaused = true;
    }
    final oldSelection = controller.selection;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: oldSelection.baseOffset.clamp(0, text.length),
        extentOffset: oldSelection.extentOffset.clamp(0, text.length),
      ),
    );
    _historyPaused = false;
  }

  @override
  void dispose() {
    _body.removeListener(_recordSelection);
    _sourceScroll.removeListener(_recordScroll);
    _sourceScroll.dispose();
    _previewScroll.dispose();
    _title.dispose();
    _body.dispose();
    _find.dispose();
    _replacement.dispose();
    _bodyFocus.dispose();
    _titleFocus.dispose();
    _findFocus.dispose();
    _undo.dispose();
    super.dispose();
  }

  void _apply(TextEditingValue value) {
    _body.value = value;
    widget.onBodyChanged(value.text);
    setState(() {});
    _bodyFocus.requestFocus();
  }

  void _recordBody() {
    if (_historyText == _body.text) return;
    if (!_historyPaused) _history.record(_historyText, _body.text);
    _historyText = _body.text;
    _undo.value = UndoHistoryValue(
      canUndo: _history.canUndo,
      canRedo: _history.canRedo,
    );
  }

  void _historyApply(String value) {
    _historyPaused = true;
    _body.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(
        offset: _body.selection.extentOffset.clamp(0, value.length),
      ),
    );
    _historyPaused = false;
    _undo.value = UndoHistoryValue(
      canUndo: _history.canUndo,
      canRedo: _history.canRedo,
    );
    widget.onBodyChanged(value);
    setState(() {});
  }

  void _undoDocument() => _historyApply(_history.undo(_body.text));
  void _redoDocument() => _historyApply(_history.redo(_body.text));
  Future<void> _insertCommand(String command) async {
    if (_mode == NoteEditorMode.rich) {
      await _richKey.currentState?.command(command);
      return;
    }
    if (command == 'Inline equation') {
      await _insertEquation(display: false);
      return;
    }
    if (command == 'Block equation') {
      await _insertEquation(display: true);
      return;
    }
    final prefix = switch (command) {
      'Heading 1' => '# ',
      'Heading 2' => '## ',
      'Heading 3' => '### ',
      'Bullet list' => '- ',
      'Numbered list' => '1. ',
      'Checklist' => '- [ ] ',
      'Quote' => '> ',
      _ => null,
    };
    if (prefix != null) {
      _apply(MarkdownEditing.prefixLines(_body.value, prefix));
      return;
    }
    if (command == 'Code block') {
      await _format(NoteFormatAction.codeBlock);
      return;
    }
    if (command == 'Table') {
      await _format(NoteFormatAction.table);
      return;
    }
    if (command == 'Image / file') {
      await _insertFrom(widget.onInsertAttachment);
      return;
    }
    if (command == 'Horizontal rule') {
      _apply(MarkdownEditing.insert(_body.value, '\n---\n'));
    }
    if (command == 'Callout') {
      _apply(
        MarkdownEditing.insert(
          _body.value,
          '\n> [!NOTE]\n> A useful observation.\n',
        ),
      );
    }
    if (command == 'Highlight') {
      await _format(NoteFormatAction.highlight);
      return;
    }
    if (command == 'Underline') {
      await _format(NoteFormatAction.underline);
      return;
    }
    if (command == 'Footnote') {
      _insertFootnote();
      return;
    }
  }

  void _insertFootnote() {
    if (_mode == NoteEditorMode.rich) {
      _richKey.currentState?.insertFootnote();
      return;
    }
    final nextNum = _nextFootnoteIndex(_body.text);
    final ref = '[^$nextNum]';
    final def = '[^$nextNum]: ';
    final sel = _body.selection.isValid
        ? _body.selection
        : TextSelection.collapsed(offset: _body.text.length);
    final text = _body.text;
    final newText = text.replaceRange(sel.start, sel.end, ref);
    final separator = newText.endsWith('\n\n')
        ? ''
        : newText.endsWith('\n')
        ? '\n'
        : '\n\n';
    final fullText = '$newText$separator$def';
    _apply(
      TextEditingValue(
        text: fullText,
        selection: TextSelection.collapsed(offset: fullText.length),
      ),
    );
  }

  static int _nextFootnoteIndex(String text) {
    var maxIndex = 0;
    for (final match in RegExp(r'\[\^(\d+)\]').allMatches(text)) {
      final n = int.tryParse(match.group(1) ?? '');
      if (n != null && n > maxIndex) {
        maxIndex = n;
      }
    }
    return maxIndex + 1;
  }

  KeyEventResult _sourceKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !_body.value.composing.isCollapsed) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed) {
      if (keyboard.isShiftPressed &&
          event.logicalKey == LogicalKeyboardKey.keyH) {
        _format(NoteFormatAction.highlight);
        return KeyEventResult.handled;
      }
      if (!keyboard.isShiftPressed &&
          event.logicalKey == LogicalKeyboardKey.keyU) {
        _format(NoteFormatAction.underline);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyZ) {
        keyboard.isShiftPressed ? _redoDocument() : _undoDocument();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyY) {
        _redoDocument();
        return KeyEventResult.handled;
      }
    }
    TextEditingValue? next;
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        !keyboard.isShiftPressed) {
      next = MarkdownEditing.continueList(_body.value);
    }
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      next = MarkdownEditing.indentList(
        _body.value,
        outdent: keyboard.isShiftPressed,
      );
    }
    if (next != null) {
      _apply(next);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _format(NoteFormatAction action) async {
    if (_mode == NoteEditorMode.rich) {
      await _richKey.currentState?.format(action);
      return;
    }
    switch (action) {
      case NoteFormatAction.heading:
        _apply(MarkdownEditing.prefixLines(_body.value, '## '));
      case NoteFormatAction.bold:
        _apply(MarkdownEditing.wrap(_body.value, '**'));
      case NoteFormatAction.italic:
        _apply(MarkdownEditing.wrap(_body.value, '*'));
      case NoteFormatAction.underline:
        _apply(MarkdownEditing.wrap(_body.value, '<u>', closing: '</u>'));
      case NoteFormatAction.strike:
        _apply(MarkdownEditing.wrap(_body.value, '~~'));
      case NoteFormatAction.highlight:
        _apply(MarkdownEditing.wrap(_body.value, '=='));
      case NoteFormatAction.bullet:
        _apply(MarkdownEditing.prefixLines(_body.value, '- '));
      case NoteFormatAction.numbered:
        _apply(MarkdownEditing.prefixLines(_body.value, '1. '));
      case NoteFormatAction.checklist:
        _apply(MarkdownEditing.prefixLines(_body.value, '- [ ] '));
      case NoteFormatAction.quote:
        _apply(MarkdownEditing.prefixLines(_body.value, '> '));
      case NoteFormatAction.inlineCode:
        _apply(MarkdownEditing.wrap(_body.value, '`', placeholder: 'code'));
      case NoteFormatAction.codeBlock:
        _apply(
          MarkdownEditing.wrap(
            _body.value,
            '\n```\n',
            closing: '\n```\n',
            placeholder: 'code',
          ),
        );
      case NoteFormatAction.table:
        _apply(
          MarkdownEditing.insert(
            _body.value,
            '\n| Column | Column |\n| --- | --- |\n| Value | Value |\n',
          ),
        );
      case NoteFormatAction.link:
        final noteId = widget.noteId;
        final value = _body.value;
        final target = await showNoteLinkDialog(context, widget.linkTargets);
        if (!mounted || target == null || widget.noteId != noteId) return;
        // The dialog is modal, so its saved selection still identifies insertion.
        final label = target.title.replaceAll('|', ' ').replaceAll(']', '');
        _apply(MarkdownEditing.insert(value, '[[${target.id}|$label]]'));
      case NoteFormatAction.math:
        await _insertEquation(display: false);
    }
  }

  Future<void> _insertEquation({bool display = false}) async {
    final selection = _body.selection;
    final selected = selection.isValid ? selection.textInside(_body.text) : '';
    final code = await showDialog<String>(
      context: context,
      builder: (_) => EquationEditor(
        source: selected.isEmpty
            ? (display ? r'\frac{a}{b}' : 'x^2')
            : selected,
        display: display,
      ),
    );
    if (!mounted || code == null) return;
    if (display) {
      _apply(MarkdownEditing.insert(_body.value, '\n\$\$\n$code\n\$\$\n'));
    } else {
      _apply(MarkdownEditing.insert(_body.value, '\$$code\$'));
    }
  }

  Future<void> _insertFrom(Future<String?> Function()? callback) async {
    if (_mode == NoteEditorMode.rich) {
      await _richKey.currentState?.insertFrom(callback);
      return;
    }
    if (callback == null || _inserting) return;
    final noteId = widget.noteId;
    setState(() => _inserting = true);
    try {
      final content = await callback();
      if (!mounted || widget.noteId != noteId || content == null) return;
      _apply(MarkdownEditing.insert(_body.value, content));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not insert attachment: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _inserting = false);
    }
  }

  RegExp? _buildSearchRegex() {
    final query = _find.text;
    if (query.isEmpty) return null;
    var pattern = RegExp.escape(query);
    if (_matchWholeWord) {
      pattern = r'\b' + pattern + r'\b';
    }
    return RegExp(pattern, caseSensitive: _matchCase);
  }

  List<TextRange> _computeMatches() {
    final regex = _buildSearchRegex();
    if (regex == null) return const [];
    final text = _body.text;
    final int startLimit;
    final int endLimit;
    if (_findScope == FindScope.selection) {
      startLimit = _scopeStart.clamp(0, text.length);
      endLimit = _scopeEnd.clamp(startLimit, text.length);
    } else {
      startLimit = 0;
      endLimit = text.length;
    }
    if (startLimit >= endLimit) return const [];
    final scopeText = text.substring(startLimit, endLimit);
    final matches = <TextRange>[];
    for (final m in regex.allMatches(scopeText)) {
      matches.add(
        TextRange(start: startLimit + m.start, end: startLimit + m.end),
      );
    }
    return matches;
  }

  void _updateMatches({bool focusMatch = false, bool fromStart = false}) {
    if (_find.text.isEmpty) {
      setState(() {
        _findCount = 0;
        _currentMatchIndex = 0;
      });
      return;
    }
    final matches = _computeMatches();
    setState(() {
      _findCount = matches.length;
      if (matches.isEmpty) {
        _currentMatchIndex = 0;
      } else if (fromStart || _currentMatchIndex == 0) {
        _currentMatchIndex = 1;
      } else if (_currentMatchIndex > matches.length) {
        _currentMatchIndex = matches.length;
      }
    });
    if (focusMatch && matches.isNotEmpty) {
      final match = matches[_currentMatchIndex - 1];
      _body.selection = TextSelection(
        baseOffset: match.start,
        extentOffset: match.end,
      );
    }
  }

  void _openFind() {
    final sel = _body.selection;
    if (sel.isValid && !sel.isCollapsed) {
      _scopeStart = math.min(sel.start, sel.end);
      _scopeEnd = math.max(sel.start, sel.end);
      final selectedText = sel.textInside(_body.text);
      final isMultiLine = selectedText.contains('\n');
      if (!isMultiLine && selectedText.length <= 40) {
        _find.text = selectedText;
        _findScope = FindScope.document;
      } else {
        _findScope = FindScope.selection;
      }
    } else {
      _findScope = FindScope.document;
    }
    setState(() {
      _showFind = true;
      _mode = NoteEditorMode.write;
    });
    if (_find.text.isNotEmpty) {
      _find.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _find.text.length,
      );
      _updateMatches(focusMatch: false);
    }
    _findFocus.requestFocus();
  }

  void _findNext({bool fromStart = false}) {
    if (_find.text.isEmpty) {
      setState(() {
        _findCount = 0;
        _currentMatchIndex = 0;
      });
      return;
    }
    final matches = _computeMatches();
    if (matches.isEmpty) {
      setState(() {
        _findCount = 0;
        _currentMatchIndex = 0;
      });
      return;
    }
    int nextIndex;
    if (fromStart) {
      nextIndex = 0;
    } else {
      final currentEnd = _body.selection.end;
      nextIndex = matches.indexWhere((m) => m.start >= currentEnd);
      if (nextIndex < 0) {
        nextIndex = 0;
      }
    }
    final match = matches[nextIndex];
    _body.selection = TextSelection(
      baseOffset: match.start,
      extentOffset: match.end,
    );
    if (!fromStart) _bodyFocus.requestFocus();
    setState(() {
      _findCount = matches.length;
      _currentMatchIndex = nextIndex + 1;
    });
  }

  void _findPrevious() {
    if (_find.text.isEmpty) return;
    final matches = _computeMatches();
    if (matches.isEmpty) return;
    final currentStart = _body.selection.start;
    int prevIndex = matches.lastIndexWhere((m) => m.end <= currentStart);
    if (prevIndex < 0) {
      prevIndex = matches.length - 1;
    }
    final match = matches[prevIndex];
    _body.selection = TextSelection(
      baseOffset: match.start,
      extentOffset: match.end,
    );
    _bodyFocus.requestFocus();
    setState(() {
      _findCount = matches.length;
      _currentMatchIndex = prevIndex + 1;
    });
  }

  void _replace({bool all = false}) {
    if (_find.text.isEmpty) return;
    final regex = _buildSearchRegex();
    if (regex == null) return;
    if (all) {
      if (_findScope == FindScope.selection) {
        final text = _body.text;
        final sStart = _scopeStart.clamp(0, text.length);
        final sEnd = _scopeEnd.clamp(sStart, text.length);
        final before = text.substring(0, sStart);
        final selected = text.substring(sStart, sEnd);
        final after = text.substring(sEnd);

        final replacedSelected = selected.replaceAllMapped(
          regex,
          (_) => _replacement.text,
        );
        final next = '$before$replacedSelected$after';
        _scopeEnd = sStart + replacedSelected.length;
        _apply(
          TextEditingValue(
            text: next,
            selection: TextSelection(
              baseOffset: sStart,
              extentOffset: _scopeEnd,
            ),
          ),
        );
      } else {
        final next = _body.text.replaceAllMapped(
          regex,
          (_) => _replacement.text,
        );
        _apply(
          TextEditingValue(
            text: next,
            selection: TextSelection.collapsed(
              offset: _body.selection.extentOffset.clamp(0, next.length),
            ),
          ),
        );
      }
    } else {
      final selection = _body.selection;
      if (selection.isValid && !selection.isCollapsed) {
        final selectedText = selection.textInside(_body.text);
        final isMatch = _matchCase
            ? selectedText == _find.text
            : selectedText.toLowerCase() == _find.text.toLowerCase();
        if (isMatch) {
          final diff = _replacement.text.length - selectedText.length;
          _apply(MarkdownEditing.insert(_body.value, _replacement.text));
          if (_findScope == FindScope.selection) {
            _scopeEnd = (_scopeEnd + diff).clamp(
              _scopeStart,
              _body.text.length,
            );
          }
        }
      }
    }
    _findNext();
  }

  void _toggleFindScope() {
    setState(() {
      if (_findScope == FindScope.document) {
        final sel = _body.selection;
        if (_bodyFocus.hasFocus &&
            sel.isValid &&
            !sel.isCollapsed &&
            sel.start != sel.end) {
          _scopeStart = math.min(sel.start, sel.end);
          _scopeEnd = math.max(sel.start, sel.end);
        } else if (_scopeStart >= _scopeEnd) {
          if (sel.isValid && !sel.isCollapsed && sel.start != sel.end) {
            _scopeStart = math.min(sel.start, sel.end);
            _scopeEnd = math.max(sel.start, sel.end);
          } else {
            _scopeStart = 0;
            _scopeEnd = _body.text.length;
          }
        }
        _findScope = FindScope.selection;
      } else {
        _findScope = FindScope.document;
      }
    });
    _updateMatches(focusMatch: true);
  }

  void _toggleMatchCase() {
    setState(() => _matchCase = !_matchCase);
    _updateMatches(focusMatch: true);
  }

  void _toggleMatchWholeWord() {
    setState(() => _matchWholeWord = !_matchWholeWord);
    _updateMatches(focusMatch: true);
  }

  void _closeFind() {
    setState(() {
      _showFind = false;
      _findScope = FindScope.document;
    });
    _bodyFocus.requestFocus();
  }

  Future<void> _openLink(String? href) async {
    if (href == null) return;
    if (href.startsWith('#fn-')) {
      if (_previewScroll.hasClients) {
        _previewScroll.animateTo(
          _previewScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    if (href.startsWith('#fnref-')) {
      if (_previewScroll.hasClients) {
        _previewScroll.animateTo(
          0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    switch (uri.scheme) {
      case 'orbit-object':
        widget.onOpenObject(
          '${Uri.decodeComponent(uri.path)}${uri.hasFragment ? '#${uri.fragment}' : ''}',
        );
      case 'orbit-ambiguous':
        final target = await showNoteLinkDialog(
          context,
          widget.linkTargets,
          initialQuery: Uri.decodeComponent(uri.path),
        );
        if (target != null && mounted) widget.onOpenObject(target.id);
      case 'orbit-missing':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No object matches “${Uri.decodeComponent(uri.path)}”. Use Object link to choose a target.',
            ),
          ),
        );
      case 'http':
      case 'https':
      case 'mailto':
        if (widget.onOpenExternalLink != null) {
          widget.onOpenExternalLink!(href);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(href),
              action: SnackBarAction(
                label: 'Copy link',
                onPressed: () => Clipboard.setData(ClipboardData(text: href)),
              ),
            ),
          );
        }
      default:
        if (uri.scheme.isEmpty && widget.onOpenAttachment != null) {
          widget.onOpenAttachment!(href);
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This link is not available in the current view.'),
          ),
        );
    }
  }

  KeyEventResult _clipboardKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        !_titleFocus.hasFocus &&
        HardwareKeyboard.instance.isControlPressed) {
      if (event.logicalKey == LogicalKeyboardKey.keyZ) {
        HardwareKeyboard.instance.isShiftPressed
            ? _redoDocument()
            : _undoDocument();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyY) {
        _redoDocument();
        return KeyEventResult.handled;
      }
    }
    if (_bodyFocus.hasFocus &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyV &&
        HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isShiftPressed &&
        widget.onPasteImage != null) {
      // Let EditableText handle ordinary text paste, including platform behavior.
      // Only ask the image adapter when there is no text representation.
      Clipboard.getData(Clipboard.kTextPlain).then((data) {
        if (mounted && _bodyFocus.hasFocus && (data?.text ?? '').isEmpty) {
          _insertFrom(widget.onPasteImage);
        }
      });
    }
    return KeyEventResult.ignored;
  }

  static const _coverPresets = [
    (
      'gradient:violet',
      'Violet Aurora',
      [Color(0xFF8B7CF6), Color(0xFF6366F1), Color(0xFF4C1D95)],
    ),
    (
      'gradient:sunset',
      'Sunset Glow',
      [Color(0xFFF97316), Color(0xFFEC4899), Color(0xFF8B5CF6)],
    ),
    (
      'gradient:ocean',
      'Ocean Deep',
      [Color(0xFF06B6D4), Color(0xFF3B82F6), Color(0xFF1E3A8A)],
    ),
    (
      'gradient:forest',
      'Forest Emerald',
      [Color(0xFF10B981), Color(0xFF059669), Color(0xFF064E3B)],
    ),
    (
      'gradient:amber',
      'Amber Horizon',
      [Color(0xFFF59E0B), Color(0xFFD97706), Color(0xFF78350F)],
    ),
    (
      'gradient:graphite',
      'Graphite Sleek',
      [Color(0xFF374151), Color(0xFF1F2937), Color(0xFF111827)],
    ),
  ];

  static const _emojiPresets = [
    '📝',
    '💡',
    '🚀',
    '🎯',
    '📚',
    '🔬',
    '🎨',
    '📌',
    '⚙️',
    '📁',
    '🌟',
    '🏷️',
    '🧠',
    '💻',
    '⚡',
    '☕',
    '📅',
    '📊',
    '🔍',
    '💎',
    '🔑',
    '💬',
    '📖',
    '✨',
  ];

  void _showIconPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Note Icon'),
        content: SizedBox(
          width: 300,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final emoji in _emojiPresets)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onIconChanged?.call(emoji);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.icon == emoji
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          if (widget.icon != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onIconChanged?.call(null);
              },
              child: const Text('Remove icon'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showCoverPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Note Cover'),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final preset in _coverPresets)
                  ListTile(
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: preset.$3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    title: Text(preset.$2),
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onCoverChanged?.call(preset.$1);
                    },
                  ),
              ],
            ),
          ),
        ),
        actions: [
          if (widget.cover != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onCoverChanged?.call(null);
              },
              child: const Text('Remove cover'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverBanner() {
    if (widget.cover == null || widget.cover!.isEmpty) {
      return const SizedBox.shrink();
    }
    final match = _coverPresets.where((p) => p.$1 == widget.cover);
    final colors = match.isNotEmpty
        ? match.first.$3
        : const [Color(0xFF374151), Color(0xFF1F2937)];
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      alignment: Alignment.bottomRight,
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.tonalIcon(
            onPressed: _showCoverPicker,
            icon: const Icon(Icons.palette_outlined, size: 16),
            label: const Text('Change cover', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Remove cover',
            onPressed: () => widget.onCoverChanged?.call(null),
            icon: const Icon(Icons.close, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader() {
    final hasIcon = widget.icon != null && widget.icon!.isNotEmpty;
    final hasCover = widget.cover != null && widget.cover!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          if (hasIcon)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _showIconPicker,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(widget.icon!, style: const TextStyle(fontSize: 32)),
              ),
            ),
          if (!hasIcon)
            TextButton.icon(
              onPressed: _showIconPicker,
              icon: const Icon(Icons.add_reaction_outlined, size: 16),
              label: const Text('Add icon', style: TextStyle(fontSize: 12)),
            ),
          if (!hasCover)
            TextButton.icon(
              onPressed: _showCoverPicker,
              icon: const Icon(Icons.image_outlined, size: 16),
              label: const Text('Add cover', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildPdfSourceBanner() {
    final pdfSource = widget.pdfSource!;
    final pdfId = pdfSource['objectId'] as String?;
    final page = pdfSource['page'] as int? ?? 1;
    if (pdfId == null) return const SizedBox.shrink();

    String pdfTitle = 'PDF document';
    if (pdfSource['title'] is String &&
        (pdfSource['title'] as String).isNotEmpty) {
      pdfTitle = pdfSource['title'] as String;
    } else {
      for (final t in widget.linkTargets) {
        if (t.id == pdfId) {
          pdfTitle = t.title;
          break;
        }
      }
    }

    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('pdf-source-banner'),
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.picture_as_pdf_outlined,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'PDF Source: $pdfTitle · Page $page',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.onOpenPdfSource != null)
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
              ),
              onPressed: () => widget.onOpenPdfSource!(pdfId, page),
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('View in PDF'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 600;
      final mode = !wide && _mode == NoteEditorMode.split
          ? NoteEditorMode.write
          : _mode;
      final words = RegExp(r'\S+').allMatches(_body.text).length;
      final chars = _body.text.runes.length;
      final readMinutes = math.max(1, (words / 200).ceil());
      final sel = _body.selection;
      final hasSelection = sel.isValid && !sel.isCollapsed;
      final selWords = hasSelection
          ? RegExp(r'\S+').allMatches(sel.textInside(_body.text)).length
          : 0;
      final selChars = hasSelection
          ? sel.textInside(_body.text).runes.length
          : 0;
      final selReadTime = selWords < 100
          ? '< 1 min read'
          : '~${math.max(1, (selWords / 200).ceil())} min read';
      final statsLabel = hasSelection
          ? 'Selection: $selWords of $words ${words == 1 ? 'word' : 'words'} ($selChars chars, $selReadTime)  ·  Document: $words ${words == 1 ? 'word' : 'words'} ($chars characters, ~$readMinutes min read)'
          : '$words ${words == 1 ? 'word' : 'words'}  ·  $chars characters  ·  ~$readMinutes min read';
      final theme = Theme.of(context);
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyB, control: true): () =>
              _format(NoteFormatAction.bold),
          const SingleActivator(LogicalKeyboardKey.keyI, control: true): () =>
              _format(NoteFormatAction.italic),
          const SingleActivator(LogicalKeyboardKey.keyU, control: true): () =>
              _format(NoteFormatAction.underline),
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
              _format(NoteFormatAction.link),
          const SingleActivator(LogicalKeyboardKey.keyF, control: true):
              _openFind,
          const SingleActivator(LogicalKeyboardKey.keyH, control: true):
              _openFind,
          const SingleActivator(
            LogicalKeyboardKey.keyH,
            control: true,
            shift: true,
          ): () =>
              _format(NoteFormatAction.highlight),
          if (widget.onPasteImage != null)
            const SingleActivator(
              LogicalKeyboardKey.keyV,
              control: true,
              shift: true,
            ): () =>
                _insertFrom(widget.onPasteImage),
        },
        child: Focus(
          onKeyEvent: _clipboardKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  children: [
                    if (widget.icon != null && widget.icon!.isNotEmpty)
                      Text(widget.icon!, style: const TextStyle(fontSize: 16))
                    else
                      const Icon(Icons.description_outlined, size: 16),
                    const SizedBox(width: 8),
                    if (constraints.maxWidth > 650)
                      Text('Markdown', style: theme.textTheme.labelMedium),
                    const Spacer(),
                    PopupMenuButton<NoteHeading>(
                      tooltip: 'Note outline',
                      icon: const Icon(Icons.format_list_bulleted, size: 18),
                      onSelected: _jumpToHeading,
                      itemBuilder: (_) {
                        final headings = noteOutline(_body.text);
                        return headings.isEmpty
                            ? [
                                const PopupMenuItem<NoteHeading>(
                                  enabled: false,
                                  child: Text('No headings yet'),
                                ),
                              ]
                            : headings
                                  .map(
                                    (h) => PopupMenuItem(
                                      value: h,
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          left: (h.level - 1) * 10.0,
                                        ),
                                        child: Text(h.title),
                                      ),
                                    ),
                                  )
                                  .toList();
                      },
                    ),
                    IconButton(
                      tooltip: 'Find in note · Ctrl+F',
                      onPressed: _openFind,
                      icon: const Icon(Icons.search_rounded, size: 18),
                    ),
                    if ((constraints.maxWidth -
                                (widget.onClosePane == null ? 0 : 48)) /
                            MediaQuery.textScalerOf(context).scale(1) <
                        500)
                      PopupMenuButton<NoteEditorMode>(
                        key: const ValueKey('note-mode-menu'),
                        tooltip: 'Editor mode',
                        itemBuilder: (_) => [
                          for (final entry in {
                            NoteEditorMode.rich: 'Rich',
                            NoteEditorMode.write: 'Source',
                            if (wide) NoteEditorMode.split: 'Split',
                            NoteEditorMode.read: 'Read',
                          }.entries)
                            PopupMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                        ],
                        onSelected: (value) {
                          setState(() => _mode = value);
                          _recordView();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                {
                                  NoteEditorMode.rich: 'Rich',
                                  NoteEditorMode.write: 'Source',
                                  NoteEditorMode.split: 'Split',
                                  NoteEditorMode.read: 'Read',
                                }[mode]!,
                              ),
                              const Icon(Icons.expand_more, size: 16),
                            ],
                          ),
                        ),
                      )
                    else
                      OrbitModeControl<NoteEditorMode>(
                        values: {
                          NoteEditorMode.rich: 'Rich',
                          NoteEditorMode.write: 'Source',
                          if (wide) NoteEditorMode.split: 'Split',
                          NoteEditorMode.read: 'Read',
                        },
                        value: mode,
                        onChanged: (value) {
                          setState(() => _mode = value);
                          _recordView();
                        },
                      ),
                    if (widget.onClosePane != null)
                      IconButton(
                        tooltip: 'Close split',
                        onPressed: widget.onClosePane,
                        icon: const Icon(Icons.close, size: 16),
                      ),
                  ],
                ),
              ),
              _buildCoverBanner(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: widget.contentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPageHeader(),
                        if (widget.pdfSource != null) _buildPdfSourceBanner(),
                        TextField(
                          key: const ValueKey('note-title'),
                          focusNode: _titleFocus,
                          controller: _title,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Untitled note',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: widget.onTitleChanged,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _bodyFocus.requestFocus(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (mode != NoteEditorMode.read)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: NoteFormatToolbar(
                    onCommand: _insertCommand,
                    onFormat: _format,
                    undoController: _undo,
                    onInsertAttachment: widget.onInsertAttachment == null
                        ? null
                        : () => _insertFrom(widget.onInsertAttachment),
                    onPasteImage: widget.onPasteImage == null
                        ? null
                        : () => _insertFrom(widget.onPasteImage),
                  ),
                ),
              if (_inserting) const LinearProgressIndicator(minHeight: 2),
              if (_showFind) _findBar(),
              if (_showFind)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 4,
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 180,
                        child: TextField(
                          key: const ValueKey('note-replacement'),
                          controller: _replacement,
                          decoration: const InputDecoration(
                            hintText: 'Replace with',
                            isDense: true,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _findCount > 0 ? _replace : null,
                        child: const Text('Replace'),
                      ),
                      TextButton(
                        onPressed: _findCount > 0
                            ? () => _replace(all: true)
                            : null,
                        child: Text(
                          _findScope == FindScope.selection
                              ? 'Replace all in selection'
                              : 'Replace all',
                        ),
                      ),
                      if (_findScope == FindScope.selection)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: const Text(
                            'In Selection',
                            style: TextStyle(fontSize: 11),
                          ),
                          onDeleted: _toggleFindScope,
                          deleteIcon: const Icon(Icons.close, size: 14),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: mode == NoteEditorMode.split
                    ? Row(
                        children: [
                          SizedBox(
                            width: (constraints.maxWidth - 6) * _splitRatio,
                            child: _source(),
                          ),
                          MouseRegion(
                            cursor: SystemMouseCursors.resizeColumn,
                            child: GestureDetector(
                              key: const ValueKey('note-split-divider'),
                              onDoubleTap: () {
                                setState(() => _splitRatio = .5);
                                _recordView();
                              },
                              onHorizontalDragUpdate: (event) {
                                setState(
                                  () => _splitRatio =
                                      (_splitRatio +
                                              event.delta.dx /
                                                  (constraints.maxWidth - 6))
                                          .clamp(.2, .8),
                                );
                                _recordView();
                              },
                              child: Container(
                                width: 6,
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                          ),
                          Expanded(child: _preview()),
                        ],
                      )
                    : mode == NoteEditorMode.read
                    ? _preview()
                    : mode == NoteEditorMode.rich
                    ? RichMarkdownEditor(
                        key: _richKey,
                        body: _body.text,
                        fontSize: widget.fontSize,
                        contentWidth: widget.contentWidth,
                        initialState: _richState,
                        onState: (v) {
                          _richState = v;
                          _recordView();
                        },
                        onChanged: (v) {
                          _body.value = TextEditingValue(
                            text: v,
                            selection: TextSelection.collapsed(
                              offset: _body.selection.extentOffset.clamp(
                                0,
                                v.length,
                              ),
                            ),
                          );
                          widget.onBodyChanged(v);
                          setState(() {});
                        },
                        onUndo: _undoDocument,
                        onRedo: _redoDocument,
                        linkTargets: widget.linkTargets,
                        linkBindings: widget.linkBindings,
                        onOpenLink: _openLink,
                        imageBuilder: widget.imageBuilder,
                        onInsertAttachment: widget.onInsertAttachment,
                        onPasteImage: widget.onPasteImage,
                        onCreateTask: widget.onCreateTask,
                      )
                    : _source(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 10,
                ),
                child: Tooltip(
                  message: hasSelection
                      ? 'Selection: $selWords words ($selReadTime) · Document: $words words, $chars characters, ~$readMinutes min read time (200 wpm)'
                      : 'Document metrics: $words words, $chars characters, ~$readMinutes min read time (200 wpm)',
                  child: Text(
                    statsLabel,
                    key: const ValueKey('document-stats'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _findBar() {
    final theme = Theme.of(context);
    final isSelectionScope = _findScope == FindScope.selection;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyC, alt: true):
            _toggleMatchCase,
        const SingleActivator(LogicalKeyboardKey.keyW, alt: true):
            _toggleMatchWholeWord,
        const SingleActivator(LogicalKeyboardKey.keyS, alt: true):
            _toggleFindScope,
        const SingleActivator(LogicalKeyboardKey.escape): _closeFind,
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _find,
                focusNode: _findFocus,
                decoration: InputDecoration(
                  hintText: 'Find in this note',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon: _find.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          tooltip: 'Clear search',
                          onPressed: () {
                            _find.clear();
                            _updateMatches();
                          },
                        )
                      : null,
                ),
                onChanged: (_) => _findNext(fromStart: true),
                onSubmitted: (_) {
                  if (HardwareKeyboard.instance.isShiftPressed) {
                    _findPrevious();
                  } else {
                    _findNext();
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Match case · Alt+C',
              isSelected: _matchCase,
              style: _matchCase
                  ? IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                    )
                  : null,
              onPressed: _toggleMatchCase,
              icon: const Text(
                'Aa',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            IconButton(
              tooltip: 'Match whole word · Alt+W',
              isSelected: _matchWholeWord,
              style: _matchWholeWord
                  ? IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                    )
                  : null,
              onPressed: _toggleMatchWholeWord,
              icon: const Text(
                r'\bW\b',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
            IconButton(
              tooltip: isSelectionScope
                  ? 'Find in selection (active) · Alt+S'
                  : 'Find in selection · Alt+S',
              isSelected: isSelectionScope,
              style: isSelectionScope
                  ? IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                    )
                  : null,
              onPressed: _toggleFindScope,
              icon: const Icon(Icons.select_all_rounded, size: 18),
            ),
            const SizedBox(width: 6),
            Text(
              '$_findCount ${_findCount == 1 ? 'match' : 'matches'}',
              style: theme.textTheme.labelSmall,
            ),
            if (_findCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '($_currentMatchIndex of $_findCount)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Previous match',
              onPressed: _findCount > 0 ? _findPrevious : null,
              icon: const Icon(Icons.arrow_upward_rounded, size: 18),
            ),
            IconButton(
              tooltip: 'Next match',
              onPressed: _findCount > 0 ? _findNext : null,
              icon: const Icon(Icons.arrow_downward_rounded, size: 18),
            ),
            IconButton(
              tooltip: 'Close find',
              onPressed: _closeFind,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _source() => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.contentWidth + 56),
      child: Scrollbar(
        controller: _sourceScroll,
        child: SizedBox(
          key: _sourceFieldKey,
          child: TextField(
            key: const ValueKey('note-body'),
            controller: _body,
            focusNode: _bodyFocus,
            scrollController: _sourceScroll,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            keyboardType: TextInputType.multiline,
            style: TextStyle(fontSize: widget.fontSize, height: 1.65),
            decoration: InputDecoration(
              hintText:
                  'Start writing. Your ideas belong here.\n\nUse [[ to write a link, or Ctrl+K to choose an object.',
              hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.65,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.fromLTRB(28, 8, 28, 40),
            ),
            onChanged: (value) {
              widget.onBodyChanged(value);
              setState(() {});
            },
          ),
        ),
      ),
    ),
  );

  Widget _preview() {
    final theme = Theme.of(context);
    return Scrollbar(
      controller: _previewScroll,
      child: SingleChildScrollView(
        controller: _previewScroll,
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 48),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.contentWidth),
            child: _body.text.trim().isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 44),
                    child: Text(
                      'Your note is ready for its first idea.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : MarkdownBody(
                    inlineSyntaxes: [
                      HighlightInlineSyntax(),
                      MarkTagInlineSyntax(),
                      UnderlineInlineSyntax(),
                      InsInlineSyntax(),
                      MathInlineSyntax(),
                    ],
                    blockSyntaxes: const [
                      CalloutBlockSyntax(),
                      MathBlockSyntax(),
                    ],
                    builders: {
                      'callout': CalloutElementBuilder(),
                      'mark': HighlightElementBuilder(),
                      'u': UnderlineElementBuilder(),
                      'ins': UnderlineElementBuilder(),
                      'math-inline': MathElementBuilder(),
                      'math-block': MathElementBuilder(display: true),
                      'pre': CodeElementBuilder(),
                    },
                    key: const ValueKey('note-preview'),
                    data: wikiLinksToMarkdown(
                      _body.text,
                      widget.linkTargets,
                      bindings: widget.linkBindings,
                    ),
                    selectable: true,
                    onTapLink: (text, href, title) => _openLink(href),
                    imageBuilder: (uri, title, alt) =>
                        widget.imageBuilder?.call(context, uri.toString()) ??
                        _imageFallback(alt ?? title ?? ''),
                    styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                      p: TextStyle(
                        fontSize: widget.fontSize,
                        height: 1.7,
                        color: theme.colorScheme.onSurface,
                      ),
                      h1: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      h2: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      h3: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      a: TextStyle(
                        color: theme.colorScheme.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: theme.colorScheme.primary.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      code: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: widget.fontSize - 1,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                      codeblockPadding: const EdgeInsets.all(16),
                      codeblockDecoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      blockquoteDecoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.6,
                            ),
                            width: 3,
                          ),
                        ),
                      ),
                      blockquotePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      horizontalRuleDecoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: theme.dividerColor),
                        ),
                      ),
                      tableBorder: TableBorder.all(color: theme.dividerColor),
                      tableCellsPadding: const EdgeInsets.all(10),
                      blockSpacing: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _imageFallback(String label) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.image_outlined),
        const SizedBox(width: 8),
        Flexible(child: Text(label.isEmpty ? 'Image unavailable' : label)),
      ],
    ),
  );
}
