import '../media_clipboard.dart';
import 'dart:async';
import '../../../domain/linked_section.dart';
import '../../../domain/document_review.dart';
import '../../../domain/document_citations.dart';
import '../linked_section.dart';
import '../note_typography.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../../domain/wiki_links.dart';
import '../../../domain/object_reference.dart';
import '../../../domain/universal_object.dart';
import '../../../domain/pdf_quote_transfer.dart';
import '../../../app/orbit_components.dart';
import '../../../app/orbit_theme.dart';
import '../orbit_internal_link.dart';
import '../markdown_editing.dart';
import '../markdown_clipboard.dart';
import '../note_format_toolbar.dart';
import '../note_link_dialog.dart';
import 'markdown_document.dart';
import 'markdown_block_index.dart';
import 'markdown_block_editing.dart';
import 'note_math.dart';
import 'code_block.dart';
import 'fenced_code_source.dart';
import 'rich_table_editor.dart';
import 'rich_math_block.dart';
import 'callout_block.dart';
import 'hover_chrome.dart';
import 'math_grid_editor.dart';
import 'dynamic_view_block.dart';
import 'snapshot_block.dart';
import 'media_section_source.dart';
import '../../../domain/note_composition.dart';
import '../note_composition.dart';
import 'media_section.dart';
import 'figure_details_dialog.dart';
import '../../../domain/grammar/spell_grammar_engine.dart';
import '../../../domain/grammar/text_issue_cursor.dart';

bool _changedLineBreaks(String before, String after) {
  if (!before.contains('\n') && !after.contains('\n')) return false;
  var start = 0;
  while (start < before.length &&
      start < after.length &&
      before[start] == after[start]) {
    start++;
  }
  var a = before.length, b = after.length;
  while (a > start && b > start && before[a - 1] == after[b - 1]) {
    a--;
    b--;
  }
  if (before.substring(start, a).contains('\n') ||
      after.substring(start, b).contains('\n')) {
    return true;
  }
  // Emptying a soft-wrapped line creates a paragraph even without adding a LF.
  final separators = RegExp(r'\n(?=[ \t\r]*\n)');
  return separators.allMatches(before).length !=
      separators.allMatches(after).length;
}

class RichMarkdownEditor extends StatefulWidget {
  const RichMarkdownEditor({
    super.key,
    required this.body,
    required this.onChanged,
    required this.onUndo,
    required this.onRedo,
    required this.linkTargets,
    required this.linkBindings,
    required this.onOpenLink,
    this.allObjects = const [],
    this.onOpenInNewTab,
    this.onOpenToSide,
    this.onShowBacklinks,
    this.onRevealInExplorer,
    this.fontSize = 16,
    this.lineHeight = 1.6,
    this.contentWidth = 800,
    this.initialState = const {},
    this.onState,
    this.imageBuilder,
    this.resolveClipboardImage,
    this.onInsertAttachment,
    this.onInsertLinkedSection,
    this.objectBlockBuilder,
    this.onCompositionCommand,
    this.attachmentRevision = 0,
    this.inheritedDefinitions = const {},
    this.onOpenFootnote,
    this.focusedStart,
    this.focusedEnd,
    this.onPasteImage,
    this.onCreateTask,
    this.onCopyBlockReference,
    this.noteId,
    this.fontFamily,
    this.spellCheckEnabled = true,
    this.embedded = false,
    this.userDictionary = const [],
    this.onAddToUserDictionary,
  });
  final String body;
  final ValueChanged<String> onChanged, onOpenLink;
  final VoidCallback onUndo, onRedo;
  final List<NoteLinkTarget> linkTargets;
  final Map<String, String> linkBindings;
  final List<UniversalObject> allObjects;
  final ValueChanged<String>? onOpenInNewTab;
  final ValueChanged<String>? onOpenToSide;
  final ValueChanged<String>? onShowBacklinks;
  final ValueChanged<String>? onRevealInExplorer;
  final double fontSize, contentWidth, lineHeight;
  final String? fontFamily;
  final bool spellCheckEnabled;
  final bool embedded;
  final List<String> userDictionary;
  final ValueChanged<String>? onAddToUserDictionary;
  final Map<String, dynamic> initialState;
  final ValueChanged<Map<String, dynamic>>? onState;
  final String Function(String)? resolveClipboardImage;
  final Widget Function(BuildContext, String)? imageBuilder;
  final Future<String?> Function()? onInsertAttachment, onPasteImage;
  final Future<String?> Function()? onInsertLinkedSection;
  final Widget Function(NoteObjectBlock, bool)? objectBlockBuilder;
  final Future<void> Function(String)? onCompositionCommand;
  final int attachmentRevision;
  final Map<String, String> inheritedDefinitions;
  final ValueChanged<String>? onOpenFootnote;
  final int? focusedStart, focusedEnd;
  final Future<void> Function(String title)? onCreateTask;
  final Future<void> Function(int sourceOffset)? onCopyBlockReference;
  final String? noteId;
  @override
  State<RichMarkdownEditor> createState() => RichMarkdownEditorState();
}

class RichMarkdownEditorState extends State<RichMarkdownEditor> {
  final _columnKeys =
      <(MarkdownBlock, int), GlobalKey<RichMarkdownEditorState>>{};
  (MarkdownBlock, int, TextSelection)? _columnSelection;
  TextSelection? get _columnDocumentSelection {
    final value = _columnSelection;
    if (value == null || document.blocks.isEmpty || current != value.$1) {
      return null;
    }
    final columns = NoteColumns.parse(value.$1.source);
    if (columns == null || value.$2 >= columns.parts.length) return null;
    final start =
        _positions.offsetOf(_positions.indexOf(value.$1)) +
        columns.offsets[value.$2];
    return TextSelection(
      baseOffset:
          start + value.$3.baseOffset.clamp(0, columns.parts[value.$2].length),
      extentOffset:
          start +
          value.$3.extentOffset.clamp(0, columns.parts[value.$2].length),
    );
  }

  // Keep ordinary lecture notes fully interactive; very large workspaces are
  // still lazy once their block count becomes expensive to lay out at once.
  static const _virtualizationThreshold = 320;
  List<MarkdownBlock> _visibleBlocks = const [];
  int _focusRequest = 0;
  late MarkdownDocument document = MarkdownDocument.parse(
    widget.body,
    inheritedDefinitions: widget.inheritedDefinitions,
  );
  MarkdownBlockIndex? _positionIndex;
  MarkdownBlockIndex get _positions =>
      _positionIndex ??= MarkdownBlockIndex(document.blocks);
  List<Map<String, Object>>? _recordedHeadings;
  String? _inlineSource;
  InlineProjection? _inlineProjection;

  InlineProjection _project(MarkdownBlock block) {
    final source = block.content;
    if (_inlineSource != source) {
      _inlineSource = source;
      _inlineProjection = InlineProjection(
        source,
        referenceDefinitions: document.referenceDefinitions,
      );
    }
    return _inlineProjection!;
  }

  void _invalidatePositions() {
    _positionIndex = null;
    _recordedHeadings = null;
  }

  late final ScrollController scroll = ScrollController(
    initialScrollOffset: (widget.initialState['scroll'] as num? ?? 0)
        .toDouble()
        .clamp(0, 1e8),
  );
  final keys = <MarkdownBlock, GlobalKey<_RichTextBlockState>>{};
  final anchors = <MarkdownBlock, GlobalKey>{};
  final cache = <MarkdownBlock, Widget>{};
  late int active = (widget.initialState['block'] as int? ?? 0).clamp(
    0,
    document.blocks.length - 1,
  );
  late int caret = widget.initialState['caret'] as int? ?? 0;
  late int selectionBase = widget.initialState['base'] as int? ?? caret;
  MarkdownBlock? _draggingBlock;
  List<MarkdownBlock>? _draggingBlocks;
  MarkdownBlock? _dropTargetBlock;
  bool _dropOnTop = true;
  late final EnglishSpellGrammarEngine grammarEngine =
      EnglishSpellGrammarEngine(userDictionary: widget.userDictionary);
  final Set<String> _collapsedHeadings = {};
  final Set<MarkdownBlock> _continuousMath = {};
  final Map<MarkdownBlock, Map<String, (String, bool)>> _inheritedMarks = {};
  Map<NoteFormatAction, String> get formatStates {
    final selection = _crossDocumentSelection;
    if (selection == null || selection.isCollapsed) {
      return keys[current]?.currentState?.formatStates ?? const {};
    }
    final styles = <Set<String>>[];
    for (var i = 0; i < document.blocks.length; i++) {
      final b = document.blocks[i];
      if (!{
        MarkdownBlockKind.text,
        MarkdownBlockKind.heading,
        MarkdownBlockKind.list,
      }.contains(b.kind)) {
        continue;
      }
      final start = _positions.offsetOf(i) + b.prefix.length;
      final p = InlineProjection(
        b.content,
        referenceDefinitions: document.referenceDefinitions,
      );
      final a = p.visibleOffset(
        (selection.start - start).clamp(0, b.content.length),
      );
      final end = p.visibleOffset(
        (selection.end - start).clamp(0, b.content.length),
      );
      styles.addAll(p.styles.skip(a).take(end - a));
    }
    return {
      for (final e in [
        (NoteFormatAction.bold, 'bold'),
        (NoteFormatAction.italic, 'italic'),
        (NoteFormatAction.highlight, 'highlight'),
        (NoteFormatAction.underline, 'underline'),
        (NoteFormatAction.strike, 'strike'),
      ])
        e.$1: styles.isNotEmpty && styles.every((s) => s.contains(e.$2))
            ? 'on'
            : styles.any((s) => s.contains(e.$2))
            ? 'mixed'
            : 'off',
    };
  }

  final Map<MarkdownBlock, String> _headingIds = {};
  int _nextHeadingId = 0;
  String? _fingerprintSource, _fingerprint;
  int? _newMathOffset;
  static final List<String> _recentCommands = [];
  int? _selectedBlockStart;
  int? _selectedBlockEnd;
  TextSelection? _crossDocumentSelection;
  int? _dragSelectionAnchor;
  bool _dragSelecting = false;
  bool _insertingAttachment = false;
  late final FocusNode _editorFocusNode = FocusNode(
    debugLabel: 'RichMarkdownEditor',
    onKeyEvent: _handleEditorKeyEvent,
  );

  bool get hasMultiBlockSelection =>
      _selectedBlockStart != null && _selectedBlockEnd != null;
  int get selectedBlockMin => hasMultiBlockSelection
      ? (_selectedBlockStart! < _selectedBlockEnd!
            ? _selectedBlockStart!
            : _selectedBlockEnd!)
      : active;
  int get selectedBlockMax => hasMultiBlockSelection
      ? (_selectedBlockStart! > _selectedBlockEnd!
            ? _selectedBlockStart!
            : _selectedBlockEnd!)
      : active;

  bool isBlockSelected(MarkdownBlock block) {
    if (!hasMultiBlockSelection) return false;
    final idx = _positions.indexOf(block);
    if (idx < 0) return false;
    return idx >= selectedBlockMin && idx <= selectedBlockMax;
  }

  List<MarkdownBlock> get selectedBlocks {
    if (!hasMultiBlockSelection) return [];
    final min = selectedBlockMin;
    final max = selectedBlockMax;
    return document.blocks.sublist(min, max + 1);
  }

  bool get hasCrossDocumentSelection =>
      _crossDocumentSelection != null && !_crossDocumentSelection!.isCollapsed;

  TextSelection? get crossDocumentSelection => _crossDocumentSelection;

  void selectDocumentRange(int start, int end) {
    final length = _positions.source.length;
    final base = start.clamp(0, length).toInt();
    final extent = end.clamp(0, length).toInt();
    if (base == extent) {
      clearCrossDocumentSelection();
      _focusOffset(base);
      return;
    }
    final first = _positions.blockAt(base), last = _positions.blockAt(extent);
    if (first == last &&
        {
          MarkdownBlockKind.text,
          MarkdownBlockKind.heading,
          MarkdownBlockKind.list,
        }.contains(document.blocks[first].kind)) {
      clearCrossDocumentSelection();
      _focusOffset(base, length: extent - base);
      return;
    }
    setState(() {
      _crossDocumentSelection = TextSelection(
        baseOffset: base,
        extentOffset: extent,
      );
      _selectedBlockStart = null;
      _selectedBlockEnd = null;
    });
    _focusOffset(extent);
  }

  void clearCrossDocumentSelection() {
    if (_crossDocumentSelection == null && _dragSelectionAnchor == null) return;
    setState(() {
      _crossDocumentSelection = null;
      _dragSelectionAnchor = null;
    });
  }

  void selectBlockRange(int start, int end) {
    if (document.blocks.isEmpty) return;
    final clampedStart = start.clamp(0, document.blocks.length - 1);
    final clampedEnd = end.clamp(0, document.blocks.length - 1);
    setState(() {
      _selectedBlockStart = clampedStart;
      _selectedBlockEnd = clampedEnd;
      active = clampedEnd;
    });
    _editorFocusNode.requestFocus();
  }

  void selectAllBlocks() {
    if (document.blocks.isNotEmpty) {
      selectBlockRange(0, document.blocks.length - 1);
    }
  }

  void clearBlockSelection() {
    if (_selectedBlockStart != null || _selectedBlockEnd != null) {
      setState(() {
        _selectedBlockStart = null;
        _selectedBlockEnd = null;
      });
    }
  }

  int _nextNonBlankIndex(int from, {required bool down}) {
    var i = down ? from + 1 : from - 1;
    while (i >= 0 && i < document.blocks.length) {
      if (document.blocks[i].kind != MarkdownBlockKind.blank) return i;
      i = down ? i + 1 : i - 1;
    }
    return (down ? document.blocks.length - 1 : 0).clamp(
      0,
      document.blocks.length - 1,
    );
  }

  void extendSelection({required bool down}) {
    if (document.blocks.isEmpty) return;
    final anchor = _selectedBlockStart ?? active;
    var currentEnd = _selectedBlockEnd ?? active;
    currentEnd = _nextNonBlankIndex(currentEnd, down: down);
    selectBlockRange(anchor, currentEnd);
  }

  void _extendFromBlock(MarkdownBlock block, {required bool down}) {
    final idx = _positions.indexOf(block);
    if (idx < 0) return;
    if (!hasMultiBlockSelection) {
      final target = _nextNonBlankIndex(idx, down: down);
      selectBlockRange(idx, target);
    } else {
      extendSelection(down: down);
    }
  }

  Future<bool> _writeClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(
              'Could not access the clipboard. Your note is unchanged.',
            ),
          ),
        );
      }
      return false;
    }
  }

  Future<bool> copySelectedBlocks() async {
    if (!hasMultiBlockSelection) return false;
    final min = selectedBlockMin;
    var max = selectedBlockMax;
    if (max + 1 < document.blocks.length &&
        document.blocks[max + 1].kind == MarkdownBlockKind.blank) {
      max = max + 1;
    }
    final blocks = document.blocks.sublist(min, max + 1);
    if (blocks.isEmpty) return false;
    final text = portableClipboardMarkdown(
      blocks.map((b) => b.source).join(),
      widget.resolveClipboardImage,
    );
    if (!await _writeClipboard(text)) return false;
    if (mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('${blocks.length} blocks copied to clipboard'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return true;
  }

  Future<void> copyCrossDocumentSelection() async {
    await _copyCrossDocumentSelection();
  }

  Future<bool> _copyCrossDocumentSelection() async {
    final selection = _crossDocumentSelection;
    if (selection == null || selection.isCollapsed) return false;
    final start = selection.start.clamp(0, _positions.source.length);
    final end = selection.end.clamp(start, _positions.source.length);
    return _writeClipboard(
      portableClipboardMarkdown(
        _positions.source.substring(start, end),
        widget.resolveClipboardImage,
      ),
    );
  }

  Future<void> cutCrossDocumentSelection() async {
    final source = _positions.source;
    final selection = _crossDocumentSelection;
    try {
      if (!await _copyCrossDocumentSelection()) return;
      if (mounted &&
          _positions.source == source &&
          _crossDocumentSelection == selection) {
        deleteCrossDocumentSelection();
      }
    } catch (_) {
      // Failed clipboard writes must not delete user content.
    }
  }

  bool deleteCrossDocumentSelection() {
    final selection = _crossDocumentSelection;
    if (selection == null || selection.isCollapsed) return false;
    final start = selection.start.clamp(0, _positions.source.length);
    final end = selection.end.clamp(start, _positions.source.length);
    final nextBody = _positions.source.replaceRange(start, end, '');
    clearCrossDocumentSelection();
    _load(nextBody);
    widget.onChanged(nextBody);
    _focusOffset(start.clamp(0, nextBody.length));
    setState(() {});
    return true;
  }

  bool replaceCrossDocumentSelection(String replacement) {
    final selection = _crossDocumentSelection;
    if (selection == null || selection.isCollapsed) return false;
    final start = selection.start.clamp(0, _positions.source.length);
    final end = selection.end.clamp(start, _positions.source.length);
    final nextBody = _positions.source.replaceRange(start, end, replacement);
    clearCrossDocumentSelection();
    _load(nextBody);
    widget.onChanged(nextBody);
    _focusOffset((start + replacement.length).clamp(0, nextBody.length));
    setState(() {});
    return true;
  }

  Future<void> cutSelectedBlocks() async {
    if (!hasMultiBlockSelection) return;
    final source = _positions.source;
    final start = _selectedBlockStart, end = _selectedBlockEnd;
    try {
      if (!await copySelectedBlocks()) return;
      if (mounted &&
          _positions.source == source &&
          _selectedBlockStart == start &&
          _selectedBlockEnd == end) {
        deleteSelectedBlocks(cut: true);
      }
    } catch (_) {
      // Clipboard failure leaves the original placement intact.
    }
  }

  void deleteSelectedBlocks({bool cut = false}) {
    if (!hasMultiBlockSelection) return;
    final min = selectedBlockMin;
    var max = selectedBlockMax;
    final isAll = min == 0 && max >= document.blocks.length - 1;

    if (isAll) {
      clearBlockSelection();
      _load('');
      widget.onChanged('');
      _focusOffset(0);
      setState(() {});
      return;
    }

    if (max + 1 < document.blocks.length &&
        document.blocks[max + 1].kind == MarkdownBlockKind.blank &&
        min > 0 &&
        document.blocks[min - 1].kind == MarkdownBlockKind.blank) {
      max = max + 1;
    }

    final startOffset = _positions.offsetOf(min);
    final endOffset =
        _positions.offsetOf(max) + document.blocks[max].source.length;
    final nextBody = _positions.source.replaceRange(startOffset, endOffset, '');

    clearBlockSelection();
    _load(nextBody);
    widget.onChanged(nextBody);
    _focusOffset(startOffset.clamp(0, nextBody.length));
    setState(() {});
  }

  void replaceSelectedBlocksWithText(String character) {
    if (!hasMultiBlockSelection) return;
    final min = selectedBlockMin;
    var max = selectedBlockMax;
    final isAll = min == 0 && max >= document.blocks.length - 1;

    if (isAll) {
      final nextBody = '$character\n\n';
      clearBlockSelection();
      _load(nextBody);
      widget.onChanged(nextBody);
      _focusOffset(character.length);
      setState(() {});
      return;
    }

    if (max + 1 < document.blocks.length &&
        document.blocks[max + 1].kind == MarkdownBlockKind.blank &&
        min > 0 &&
        document.blocks[min - 1].kind == MarkdownBlockKind.blank) {
      max = max + 1;
    }

    final startOffset = _positions.offsetOf(min);
    final endOffset =
        _positions.offsetOf(max) + document.blocks[max].source.length;
    final replacement = '$character\n\n';
    final nextBody = _positions.source.replaceRange(
      startOffset,
      endOffset,
      replacement,
    );

    clearBlockSelection();
    _load(nextBody);
    widget.onChanged(nextBody);
    _focusOffset(startOffset + character.length);
    setState(() {});
  }

  void _focusBlock(int blockIndex, {bool atStart = true}) {
    if (document.blocks.isEmpty) return;
    final idx = blockIndex.clamp(0, document.blocks.length - 1);
    final block = document.blocks[idx];
    final offset = atStart
        ? _positions.offsetOf(idx) + block.prefix.length
        : _positions.offsetOf(idx) + block.source.length;
    _focusOffset(offset);
  }

  KeyEventResult _handleEditorKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    final isCommand = keyboard.isControlPressed || keyboard.isMetaPressed;

    if (hasCrossDocumentSelection) {
      if (isCommand && event.logicalKey == LogicalKeyboardKey.keyC) {
        copyCrossDocumentSelection();
        return KeyEventResult.handled;
      }
      if (isCommand && event.logicalKey == LogicalKeyboardKey.keyX) {
        cutCrossDocumentSelection();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.backspace ||
          event.logicalKey == LogicalKeyboardKey.delete) {
        deleteCrossDocumentSelection();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        clearCrossDocumentSelection();
        return KeyEventResult.handled;
      }
    }
    if (hasMultiBlockSelection) {
      if (isCommand && event.logicalKey == LogicalKeyboardKey.keyC) {
        copySelectedBlocks();
        return KeyEventResult.handled;
      }
      if (isCommand && event.logicalKey == LogicalKeyboardKey.keyX) {
        cutSelectedBlocks();
        return KeyEventResult.handled;
      }
      if (isCommand && event.logicalKey == LogicalKeyboardKey.keyV) {
        final before = _positions.source;
        final selection = currentDocumentSelection;
        readMarkdownClipboard().then((text) {
          if (mounted &&
              text != null &&
              text.isNotEmpty &&
              _positions.source == before &&
              currentDocumentSelection == selection) {
            replaceSelectedBlocksWithText(text);
          }
        });
        return KeyEventResult.handled;
      }
      if (isCommand && event.logicalKey == LogicalKeyboardKey.keyD) {
        duplicateSelectedBlocks();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.backspace ||
          event.logicalKey == LogicalKeyboardKey.delete) {
        deleteSelectedBlocks();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        clearBlockSelection();
        _focusBlock(active, atStart: false);
        return KeyEventResult.handled;
      }
      if (isCommand && event.logicalKey == LogicalKeyboardKey.keyA) {
        selectAllBlocks();
        return KeyEventResult.handled;
      }
      if (keyboard.isShiftPressed && !isCommand && !keyboard.isAltPressed) {
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          extendSelection(down: true);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          extendSelection(down: false);
          return KeyEventResult.handled;
        }
      }
      if (!keyboard.isShiftPressed && !isCommand && !keyboard.isAltPressed) {
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          final next = selectedBlockMax + 1;
          clearBlockSelection();
          _focusBlock(next, atStart: true);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          final prev = selectedBlockMin - 1;
          clearBlockSelection();
          _focusBlock(prev, atStart: false);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          final min = selectedBlockMin;
          clearBlockSelection();
          _focusBlock(min, atStart: true);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          final max = selectedBlockMax;
          clearBlockSelection();
          _focusBlock(max, atStart: false);
          return KeyEventResult.handled;
        }
      }
      if (isCommand && event.logicalKey == LogicalKeyboardKey.keyZ) {
        clearBlockSelection();
        keyboard.isShiftPressed ? widget.onRedo() : widget.onUndo();
        return KeyEventResult.handled;
      }
      if (isCommand && event.logicalKey == LogicalKeyboardKey.keyY) {
        clearBlockSelection();
        widget.onRedo();
        return KeyEventResult.handled;
      }
      if (keyboard.isAltPressed && !isCommand && !keyboard.isShiftPressed) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          moveSelectedBlocksUp();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          moveSelectedBlocksDown();
          return KeyEventResult.handled;
        }
      }
      if (!isCommand &&
          !keyboard.isAltPressed &&
          event.character != null &&
          event.character!.isNotEmpty &&
          event.logicalKey != LogicalKeyboardKey.enter &&
          event.logicalKey != LogicalKeyboardKey.tab) {
        replaceSelectedBlocksWithText(event.character!);
        return KeyEventResult.handled;
      }
    } else {
      if (isCommand && event.logicalKey == LogicalKeyboardKey.keyA) {
        selectAllBlocks();
        return KeyEventResult.handled;
      }
      if (isCommand && event.logicalKey == LogicalKeyboardKey.keyD) {
        duplicateCurrentBlock();
        return KeyEventResult.handled;
      }
      if (keyboard.isAltPressed && !isCommand && !keyboard.isShiftPressed) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          moveCurrentBlockUp();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          moveCurrentBlockDown();
          return KeyEventResult.handled;
        }
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  void initState() {
    super.initState();
    final mathOffsets = widget.initialState['continuousMath'];
    if (mathOffsets is List &&
        widget.initialState['headingDocument'] == _documentFingerprint) {
      for (final offset in mathOffsets.whereType<int>()) {
        if (offset < 0 || offset > _positions.source.length) continue;
        final index = _positions.blockAt(offset);
        final block = document.blocks[index];
        if (_positions.offsetOf(index) == offset &&
            block.kind == MarkdownBlockKind.text &&
            inlineMathMatches(block.content).isNotEmpty) {
          _continuousMath.add(block);
        }
      }
    }
    final initialCollapsed = widget.initialState['collapsed'];
    if (initialCollapsed is List) {
      _collapsedHeadings.addAll(initialCollapsed.whereType<String>());
    }
    final saved = widget.initialState['headings'];
    if (saved is List &&
        widget.initialState['headingDocument'] == _documentFingerprint) {
      for (final item in saved.whereType<Map>()) {
        final index = item['block'], id = item['id'];
        if (index is int &&
            index >= 0 &&
            index < document.blocks.length &&
            id is String &&
            !_headingIds.containsValue(id) &&
            document.blocks[index].kind == MarkdownBlockKind.heading) {
          _headingIds[document.blocks[index]] = id;
        }
      }
    } else if (saved == null) {
      // Migrate old text-based view state once, without changing Markdown.
      final counts = <String, int>{};
      for (final block in document.blocks) {
        if (block.kind != MarkdownBlockKind.heading) continue;
        final text = '${block.level}:${block.content.trim()}';
        final ordinal = counts.update(text, (n) => n + 1, ifAbsent: () => 0);
        final old = ordinal == 0 ? text : '$text#$ordinal';
        if (_collapsedHeadings.remove(old)) {
          _collapsedHeadings.add(_headingKey(block));
        }
      }
    }
    scroll.addListener(record);
  }

  String get _documentFingerprint {
    final source = _positions.source;
    if (source != _fingerprintSource) {
      _fingerprintSource = source;
      _fingerprint = sha256.convert(utf8.encode(source)).toString();
    }
    return _fingerprint!;
  }

  int get currentDocumentOffset {
    if (document.blocks.isEmpty) return 0;
    if (_columnDocumentSelection != null) {
      return _columnDocumentSelection!.extentOffset;
    }
    final structured = _structuredDocumentSelection();
    if (structured != null) return structured.extentOffset;
    final blockIndex = active.clamp(0, document.blocks.length - 1);
    final block = document.blocks[blockIndex];
    final blockOffset = _positions.offsetOf(blockIndex);
    final contentOffset = _project(block).sourceOffset(caret);
    return (blockOffset + block.prefix.length + contentOffset).clamp(
      0,
      _positions.source.length,
    );
  }

  TextSelection get currentDocumentSelection {
    if (document.blocks.isEmpty) {
      return const TextSelection.collapsed(offset: 0);
    }
    if (hasCrossDocumentSelection) return _crossDocumentSelection!;
    if (hasMultiBlockSelection) {
      final min = selectedBlockMin;
      final max = selectedBlockMax;
      final start = _positions.offsetOf(min);
      final end = _positions.offsetOf(max) + document.blocks[max].source.length;
      return TextSelection(baseOffset: start, extentOffset: end);
    }
    if (_columnDocumentSelection != null) return _columnDocumentSelection!;
    final structured = _structuredDocumentSelection();
    if (structured != null) return structured;
    final blockIndex = active.clamp(0, document.blocks.length - 1);
    final block = document.blocks[blockIndex];
    final blockOffset = _positions.offsetOf(blockIndex);
    final proj = _project(block);
    final base =
        (blockOffset + block.prefix.length + proj.sourceOffset(selectionBase))
            .clamp(0, _positions.source.length);
    final extent =
        (blockOffset + block.prefix.length + proj.sourceOffset(caret)).clamp(
          0,
          _positions.source.length,
        );
    return TextSelection(baseOffset: base, extentOffset: extent);
  }

  TextSelection? _structuredDocumentSelection() {
    if (document.blocks.isEmpty) return null;
    final index = active.clamp(0, document.blocks.length - 1);
    final block = document.blocks[index];
    if (block.kind != MarkdownBlockKind.table &&
        block.kind != MarkdownBlockKind.callout &&
        block.kind != MarkdownBlockKind.code) {
      return null;
    }
    TextSelection? selection;
    void visit(Element element) {
      if (element is StatefulElement) {
        final state = element.state;
        if (state is RichTableEditorState) selection = state.sourceSelection;
        if (state is CalloutBlockState) selection = state.sourceSelection;
        if (state is NoteCodeBlockState) {
          final local = state.sourceSelection;
          if (local != null) {
            selection = TextSelection(
              baseOffset: block.prefix.length + local.baseOffset,
              extentOffset: block.prefix.length + local.extentOffset,
            );
          }
        }
      }
      element.visitChildren(visit);
    }

    final anchor = anchors[block]?.currentContext;
    if (anchor is Element) visit(anchor);
    if (selection == null) return null;
    final offset = _positions.offsetOf(index);
    return TextSelection(
      baseOffset: (offset + selection!.baseOffset).clamp(
        0,
        _positions.source.length,
      ),
      extentOffset: (offset + selection!.extentOffset).clamp(
        0,
        _positions.source.length,
      ),
    );
  }

  void _activateStructured(MarkdownBlock block) {
    final index = _positions.indexOf(block);
    if (index < 0) return;
    active = index;
    clearBlockSelection();
    record();
  }

  void record() {
    if (widget.onState == null) return;
    final selection = currentDocumentSelection;
    widget.onState!({
      'block': active,
      'caret': caret,
      'base': selectionBase,
      'docOffset': currentDocumentOffset,
      'selection': {
        'base': selection.baseOffset,
        'extent': selection.extentOffset,
      },
      'scroll': scroll.hasClients ? scroll.offset : 0,
      'collapsed': _collapsedHeadings.toList(),
      'continuousMath': [
        for (final block in _continuousMath)
          _positions.offsetOf(_positions.indexOf(block)),
      ],
      'headingDocument': _documentFingerprint,
      'headings': _recordedHeadings ??= List.unmodifiable([
        for (var i = 0; i < document.blocks.length; i++)
          if (document.blocks[i].kind == MarkdownBlockKind.heading)
            Map<String, Object>.unmodifiable({
              'block': i,
              'id': _headingKey(document.blocks[i]),
            }),
      ]),
    });
  }

  @override
  void dispose() {
    _editorFocusNode.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RichMarkdownEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(
      widget.inheritedDefinitions,
      oldWidget.inheritedDefinitions,
    )) {
      _load(widget.body);
      cache.clear();
    }
    if (!listEquals(widget.allObjects, oldWidget.allObjects) ||
        widget.attachmentRevision != oldWidget.attachmentRevision) {
      cache.removeWhere(
        (block, _) =>
            block.source.contains('<!-- orbit:section ') ||
            block.source.contains('<!-- orbit:object ') ||
            block.source.contains('<!-- orbit:columns '),
      );
    }
    if (widget.body != _positions.source) {
      MarkdownBlock? focusedStructuredBlock;
      final focusContext = FocusManager.instance.primaryFocus?.context;
      final codeSelection = focusContext
          ?.findAncestorStateOfType<NoteCodeBlockState>()
          ?.sourceSelection;
      if (focusContext?.findAncestorStateOfType<RichTableEditorState>() !=
              null ||
          focusContext?.findAncestorStateOfType<CalloutBlockState>() != null ||
          focusContext?.findAncestorStateOfType<NoteCodeBlockState>() != null) {
        final byContext = {
          for (final entry in anchors.entries)
            if (entry.value.currentContext != null)
              entry.value.currentContext!: entry.key,
        };
        focusContext?.visitAncestorElements((element) {
          focusedStructuredBlock = byContext[element];
          return focusedStructuredBlock == null;
        });
      }
      final wasEditing =
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorStateOfType<RichMarkdownEditorState>() ==
          this;
      _load(widget.body);
      if (focusedStructuredBlock != null &&
          _positions.indexOf(focusedStructuredBlock!) >= 0) {
        // Retained fields clamp their own selection. A generic prose jump would
        // move a table caret to the first cell or a callout into another block.
        active = _positions.indexOf(focusedStructuredBlock!);
      } else if (wasEditing &&
          codeSelection != null &&
          current.kind == MarkdownBlockKind.code) {
        final base = codeSelection.baseOffset.clamp(0, current.content.length);
        final extent = codeSelection.extentOffset.clamp(
          0,
          current.content.length,
        );
        _focusOffset(
          _positions.offsetOf(active) + current.prefix.length + base,
          length: extent - base,
        );
      } else if (wasEditing) {
        _focusOffset(
          _positions.offsetOf(active) +
              current.prefix.length +
              InlineProjection(
                current.content,
                referenceDefinitions: document.referenceDefinitions,
              ).sourceOffset(caret),
        );
      }
    }
    if (widget.fontSize != oldWidget.fontSize ||
        widget.fontFamily != oldWidget.fontFamily ||
        widget.lineHeight != oldWidget.lineHeight ||
        widget.contentWidth != oldWidget.contentWidth ||
        !mapEquals(widget.linkBindings, oldWidget.linkBindings)) {
      cache.clear();
    }
    if (!listEquals(widget.userDictionary, oldWidget.userDictionary)) {
      grammarEngine.setUserDictionary(widget.userDictionary);
      cache.clear();
      for (final key in keys.values) {
        key.currentState?.controller.refreshStyle();
      }
    }
    if (widget.spellCheckEnabled != oldWidget.spellCheckEnabled) {
      cache.clear();
      for (final key in keys.values) {
        key.currentState?.controller.refreshStyle();
      }
    }
  }

  void _load(String source) {
    final next = MarkdownDocument.parse(
      source,
      inheritedDefinitions: widget.inheritedDefinitions,
    );
    if (!mapEquals(document.referenceDefinitions, next.referenceDefinitions)) {
      // Unchanged prose can gain or lose a shortcut link when a raw definition
      // changes. Rebuild its widget while retaining the field/controller key.
      cache.clear();
    }
    // Reuse unaffected blocks so a save acknowledgement cannot reset controllers.
    var prefix = 0;
    while (prefix < next.blocks.length &&
        prefix < document.blocks.length &&
        next.blocks[prefix].source == document.blocks[prefix].source) {
      next.blocks[prefix] = document.blocks[prefix];
      prefix++;
    }
    var a = document.blocks.length - 1, b = next.blocks.length - 1;
    while (a >= prefix &&
        b >= prefix &&
        document.blocks[a].source == next.blocks[b].source) {
      next.blocks[b--] = document.blocks[a--];
    }
    if (a == b) {
      for (var i = prefix; i <= a; i++) {
        final old = document.blocks[i], replacement = next.blocks[i];
        if (old.kind == MarkdownBlockKind.heading &&
            replacement.kind == old.kind) {
          _headingIds[replacement] = _headingKey(old);
        }
        if ({
              MarkdownBlockKind.math,
              MarkdownBlockKind.table,
              MarkdownBlockKind.callout,
              MarkdownBlockKind.code,
              MarkdownBlockKind.media,
            }.contains(old.kind) &&
            (old.kind != MarkdownBlockKind.code ||
                (!DynamicViewBlock.isDynamicView(old.language, old.content) &&
                    !SnapshotBlock.isSnapshot(old.language, old.content))) &&
            replacement.kind == old.kind &&
            old.prefix == replacement.prefix &&
            old.suffix == replacement.suffix) {
          old.source = replacement.source;
          next.blocks[i] = old;
          cache.remove(old);
        }
      }
    }
    document = next;
    _columnKeys.removeWhere((key, _) => !next.blocks.contains(key.$1));
    _continuousMath.removeWhere((b) => !next.blocks.contains(b));
    _inheritedMarks.removeWhere((b, _) => !next.blocks.contains(b));
    _inlineSource = null;
    _inlineProjection = null;
    _invalidatePositions();
    final cross = _crossDocumentSelection;
    if (cross != null) {
      final length = next.source.length;
      final base = cross.baseOffset.clamp(0, length).toInt();
      final extent = cross.extentOffset.clamp(0, length).toInt();
      _crossDocumentSelection = base == extent
          ? null
          : TextSelection(baseOffset: base, extentOffset: extent);
    }
    final retained = document.blocks.toSet();
    keys.removeWhere((k, _) => !retained.contains(k));
    anchors.removeWhere((k, _) => !retained.contains(k));
    cache.removeWhere((k, _) => !retained.contains(k));
    _headingIds.removeWhere((k, _) => !retained.contains(k));
    active = active.clamp(0, document.blocks.length - 1);
    if (hasMultiBlockSelection) {
      _selectedBlockStart = _selectedBlockStart!.clamp(
        0,
        document.blocks.length - 1,
      );
      _selectedBlockEnd = _selectedBlockEnd!.clamp(
        0,
        document.blocks.length - 1,
      );
    }
  }

  void _replace(
    MarkdownBlock block,
    String source, {
    bool structural = false,
    int? focusOffset,
  }) {
    final index = _positions.indexOf(block);
    if (index < 0 || source == block.source) return;
    final start = _positions.offsetOf(index);
    final body = _positions.source.replaceRange(
      start,
      start + block.source.length,
      source,
    );
    final referenceDefinitionsChanged =
        !mapEquals(document.referenceDefinitions, {
          ...MarkdownDocument.referenceDefinitionsFor(body),
          ...widget.inheritedDefinitions,
        });
    if (structural || referenceDefinitionsChanged) {
      _load(body);
    } else {
      block.source = source;
      _invalidatePositions();
      cache.remove(block);
    }
    widget.onChanged(_positions.source);
    setState(() {});
    if (focusOffset != null) _focusOffset(start + focusOffset);
  }

  void _focusOffset(int offset, {int length = 0}) {
    _columnSelection = null;
    final request = ++_focusRequest;
    active = _positions.blockAt(offset).clamp(0, document.blocks.length - 1);
    var block = document.blocks[active];
    if (_collapsedHeadings.isNotEmpty) {
      var expandedAny = false;
      for (var i = active; i >= 0; i--) {
        final b = document.blocks[i];
        if (b.kind == MarkdownBlockKind.heading) {
          final key = _headingKey(b);
          if (_collapsedHeadings.remove(key)) {
            expandedAny = true;
          }
        }
      }
      if (expandedAny) {
        setState(() {});
      }
    }
    // An empty paragraph between existing blocks is still an editing target.
    // Its transient text field contributes exactly the original blank source.
    if (block.kind == MarkdownBlockKind.blank) {
      block = MarkdownBlock(
        block.source,
        MarkdownBlockKind.text,
        suffix: block.source,
      );
      document.blocks[active] = block;
      _invalidatePositions();
    }
    // Focusing an existing trailing blank must not leave the parser's synthetic
    // end-of-document field beside it. Remove only that zero-byte projection;
    // preserve every authored blank line and the focused editing target.
    if (block.kind == MarkdownBlockKind.text &&
        block.content.isEmpty &&
        active < document.blocks.length - 1 &&
        document.blocks.last.source.isEmpty &&
        document.blocks
            .skip(active + 1)
            .every(
              (b) => b.kind == MarkdownBlockKind.blank || b.source.isEmpty,
            )) {
      final trailing = document.blocks.removeLast();
      _invalidatePositions();
      keys.remove(trailing);
      cache.remove(trailing);
      anchors.remove(trailing);
    }
    final raw = (offset - _positions.offsetOf(active) - block.prefix.length)
        .clamp(0, block.content.length);
    final local = InlineProjection(
      block.content,
      referenceDefinitions: document.referenceDefinitions,
    ).visibleOffset(raw);
    final end = InlineProjection(
      block.content,
      referenceDefinitions: document.referenceDefinitions,
    ).visibleOffset((raw + length).clamp(0, block.content.length));
    caret = end;
    selectionBase = local;
    record();
    // Materialize a distant target before asking its TextField for focus.
    // Measurements from the built range refine the seek on successive frames;
    // a fixed paragraph height cannot handle tables or wrapped prose.
    void focusWhenMounted(Duration _) {
      if (!mounted || request != _focusRequest || current != block) return;
      if (document.blocks.length > _virtualizationThreshold &&
          anchors[block]?.currentContext == null &&
          scroll.hasClients) {
        if (_seekBlock(block)) {
          WidgetsBinding.instance.addPostFrameCallback(focusWhenMounted);
          WidgetsBinding.instance.scheduleFrame();
        }
        return;
      }
      final field = keys[block]?.currentState;
      final columns = NoteColumns.parse(block.source);
      if (columns != null) {
        for (var i = 0; i < columns.parts.length; i++) {
          final partStart = columns.offsets[i];
          if (raw >= partStart && raw < partStart + columns.parts[i].length) {
            final nested = _columnKeys[(block, i)]?.currentState;
            if (nested != null) {
              nested.jumpTo(
                raw - partStart,
                length: length.clamp(
                  0,
                  columns.parts[i].length - raw + partStart,
                ),
              );
              return;
            }
          }
        }
      }
      if (field != null) {
        field.focusAt(local, extent: end);
      } else {
        // Returning from an empty paragraph must not select the entire preceding
        // code/table block: a repeated Backspace would then delete that block.
        final editors = <EditableText>[];
        var specializedSelection = false;
        void visit(Element element) {
          if (element is StatefulElement) {
            final state = element.state;
            if (state is RichTableEditorState) {
              specializedSelection = state.selectSource(raw, length: length);
            } else if (state is CalloutBlockState) {
              specializedSelection = state.selectSource(raw, length: length);
            } else if (state is NoteCodeBlockState) {
              specializedSelection = state.selectSource(raw, length: length);
            }
          }
          if (element.widget is EditableText) {
            editors.add(element.widget as EditableText);
          }
          element.visitChildren(visit);
        }

        final anchor = anchors[block]?.currentContext;
        if (anchor is Element) {
          visit(anchor);
        }
        clearBlockSelection();
        if (specializedSelection) {
          // The structured editor selected its exact cell/body/title range.
        } else if (editors.isNotEmpty) {
          final editor = raw == 0 ? editors.first : editors.last;
          editor.controller.selection = TextSelection.collapsed(
            offset: raw == 0 ? 0 : editor.controller.text.length,
          );
          editor.focusNode.requestFocus();
        } else {
          _editorFocusNode.requestFocus();
        }
      }
      final context = anchors[block]?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: .15,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          duration: Duration.zero,
        );
      }
    }

    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback(focusWhenMounted);
  }

  bool _seekBlock(MarkdownBlock target) {
    final targetIndex = _visibleBlocks.indexOf(target);
    if (targetIndex < 0) return false;
    final measurements = <({int index, double offset, double height})>[];
    for (var i = 0; i < _visibleBlocks.length; i++) {
      final box = anchors[_visibleBlocks[i]]?.currentContext
          ?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport == null) continue;
      final position = viewport.getOffsetToReveal(box, 0).offset;
      measurements.add((index: i, offset: position, height: box.size.height));
    }
    if (measurements.isEmpty) return false;
    final first = measurements.first, last = measurements.last;
    final average = first.index == last.index
        ? math.max(first.height, 16.0)
        : math.max(
            (last.offset + last.height - first.offset) /
                (last.index - first.index + 1),
            1.0,
          );
    final nearest = targetIndex < first.index ? first : last;
    final estimate = nearest.offset + (targetIndex - nearest.index) * average;
    final position = estimate.clamp(0.0, scroll.position.maxScrollExtent);
    if ((position - scroll.offset).abs() < .5) return false;
    scroll.jumpTo(position);
    return true;
  }

  void jumpTo(int offset, {int length = 0}) =>
      _focusOffset(offset, length: length);
  MarkdownBlock get current =>
      document.blocks[active.clamp(0, document.blocks.length - 1)];
  void insertMarkdown(String value) {
    final block = current;
    final field = keys[block]?.currentState;
    if (field != null && !value.contains('\n') && !value.startsWith('![')) {
      field.insert(value);
      return;
    }
    final separator = block.source.isEmpty || block.source.endsWith('\n')
        ? '\n'
        : '\n\n';
    final insert = '$separator$value';
    _replace(
      block,
      '${block.source}$insert${value.endsWith('\n') ? '' : '\n'}',
      structural: true,
      focusOffset: block.source.length + separator.length,
    );
  }

  Future<void> insertFrom(Future<String?> Function()? callback) async {
    if (callback == null || _insertingAttachment) return;
    _insertingAttachment = true;
    final block = current;
    final originalSource = _positions.source, originalNote = widget.noteId;
    final originalCaret = caret, originalBase = selectionBase;
    final originalValue = keys[block]?.currentState?.controller.value;
    try {
      final content = await callback();
      if (!mounted || content == null) return;
      if (widget.noteId != originalNote ||
          _positions.source != originalSource ||
          !identical(current, block) ||
          caret != originalCaret ||
          selectionBase != originalBase ||
          keys[block]?.currentState?.controller.value != originalValue) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: const Text('The insertion position changed.'),
            action: widget.noteId == originalNote
                ? SnackBarAction(
                    label: 'Insert here',
                    onPressed: () {
                      if (mounted && widget.noteId == originalNote) {
                        insertMarkdown(content);
                      }
                    },
                  )
                : null,
          ),
        );
        return;
      }
      insertMarkdown(content);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Could not insert attachment: $error')),
        );
      }
    } finally {
      _insertingAttachment = false;
    }
  }

  Future<void> format(NoteFormatAction action) async {
    final tag = switch (action) {
      NoteFormatAction.bold => '**',
      NoteFormatAction.italic => '*',
      NoteFormatAction.highlight => '==',
      NoteFormatAction.underline => '<u>',
      NoteFormatAction.strike => '~~',
      _ => null,
    };
    if (tag != null && hasCrossDocumentSelection) {
      final selection = _crossDocumentSelection!;
      final mark = switch (action) {
        NoteFormatAction.bold => 'bold',
        NoteFormatAction.italic => 'italic',
        NoteFormatAction.highlight => 'highlight',
        NoteFormatAction.underline => 'underline',
        _ => 'strike',
      };
      final ranges =
          <
            ({
              int start,
              int end,
              InlineProjection p,
              int a,
              int b,
              bool marked,
            })
          >[];
      for (var i = 0; i < document.blocks.length; i++) {
        final block = document.blocks[i];
        if (!{
          MarkdownBlockKind.text,
          MarkdownBlockKind.heading,
          MarkdownBlockKind.list,
        }.contains(block.kind)) {
          continue;
        }
        final start = _positions.offsetOf(i) + block.prefix.length;
        final end = start + block.content.length;
        final a = selection.start.clamp(start, end),
            b = selection.end.clamp(start, end);
        if (a >= b) continue;
        final p = InlineProjection(
          block.content,
          referenceDefinitions: document.referenceDefinitions,
        );
        final va = p.visibleOffset(a - start), vb = p.visibleOffset(b - start);
        final styles = p.styles.skip(va).take(vb - va).toList();
        ranges.add((
          start: start,
          end: end,
          p: p,
          a: va,
          b: vb,
          marked: styles.isNotEmpty && styles.every((s) => s.contains(mark)),
        ));
      }
      final remove = ranges.isNotEmpty && ranges.every((r) => r.marked);
      var source = _positions.source, delta = 0;
      for (final r in ranges.reversed) {
        if (!remove && r.marked) continue;
        final next = r.p.formatRange(
          r.a,
          r.b,
          tag,
          tag == '<u>' ? '</u>' : tag,
        );
        source = source.replaceRange(r.start, r.end, next);
        delta += next.length - (r.end - r.start);
      }
      if (source != _positions.source) {
        _load(source);
        widget.onChanged(source);
        selectDocumentRange(
          selection.baseOffset <= selection.extentOffset
              ? selection.start
              : selection.end + delta,
          selection.baseOffset <= selection.extentOffset
              ? selection.end + delta
              : selection.start,
        );
      }
      return;
    }
    final nested = FocusManager.instance.primaryFocus?.context
        ?.findAncestorStateOfType<RichMarkdownEditorState>();
    if (nested != null &&
        nested != this &&
        nested.context.findAncestorStateOfType<RichMarkdownEditorState>() ==
            this) {
      await nested.format(action);
      return;
    }
    final field = keys[current]?.currentState;
    switch (action) {
      case NoteFormatAction.alignLeft:
      case NoteFormatAction.alignCenter:
      case NoteFormatAction.alignRight:
        if (!current.canAlign) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('Select a paragraph or heading to align its text.'),
            ),
          );
          return;
        }
        final alignment = switch (action) {
          NoteFormatAction.alignCenter => 'center',
          NoteFormatAction.alignRight => 'right',
          _ => 'left',
        };
        final source = current.withAlignment(
          alignment,
          lineEnding: MarkdownBlockEditing.eol(document),
        );
        if (source == current.source) return;
        final selection =
            field?.controller.selection ??
            TextSelection(baseOffset: selectionBase, extentOffset: caret);
        _replace(current, source, structural: true);
        final aligned = current;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && document.blocks.contains(aligned)) {
            keys[aligned]?.currentState?.focusAt(
              selection.baseOffset,
              extent: selection.extentOffset,
            );
          }
        });
      case NoteFormatAction.bold:
        field?.wrap('**');
      case NoteFormatAction.italic:
        field?.wrap('*');
      case NoteFormatAction.underline:
        field?.wrap('<u>', closing: '</u>');
      case NoteFormatAction.strike:
        field?.wrap('~~');
      case NoteFormatAction.highlight:
        field?.wrap('==');
      case NoteFormatAction.inlineCode:
        field?.wrap('`');
      case NoteFormatAction.heading:
        command('Heading 2');
      case NoteFormatAction.bullet:
        command('Bullet list');
      case NoteFormatAction.numbered:
        command('Numbered list');
      case NoteFormatAction.checklist:
        command('Checklist');
      case NoteFormatAction.quote:
        command('Quote');
      case NoteFormatAction.codeBlock:
        command('Code block');
      case NoteFormatAction.table:
        command('Table');
      case NoteFormatAction.math:
        command('Inline equation');
      case NoteFormatAction.link:
        final originalSource = _positions.source;
        final originalNote = widget.noteId;
        final originalSelection = field?.controller.value;
        final target = await showNoteLinkDialog(context, widget.linkTargets);
        if (!mounted ||
            target == null ||
            _positions.source != originalSource ||
            widget.noteId != originalNote ||
            field?.mounted == false ||
            field?.controller.value != originalSelection) {
          return;
        }
        field?.insert(
          '[[${target.id}|${target.title.replaceAll('|', ' ').replaceAll(']', '')}]]',
        );
    }
    record();
  }

  void insertFootnote() {
    final nextNum = _nextFootnoteIndex(_positions.source);
    final ref = '[^$nextNum]';
    final field = keys[current]?.currentState;
    if (field != null) {
      field.insert(ref);
    }
    final lastBlock = document.blocks.last;
    final separator = lastBlock.source.endsWith('\n\n')
        ? ''
        : lastBlock.source.endsWith('\n')
        ? '\n'
        : '\n\n';
    _replace(
      lastBlock,
      '${lastBlock.source}$separator[^$nextNum]: \n',
      structural: true,
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

  static const commands = [
    'Text',
    'Heading 1',
    'Heading 2',
    'Heading 3',
    'Bullet list',
    'Numbered list',
    'Checklist',
    'Quote',
    'Callout',
    'Highlight',
    'Underline',
    'Footnote',
    'Definition',
    'Theorem',
    'Lemma',
    'Proof',
    'Example',
    'Question',
    'Code block',
    'Table',
    'Inline equation',
    'Block equation',
    'Matrix',
    'Cases',
    'Math symbols',
    'Image / file',
    'Image and text',
    'Two columns',
    'Three columns',
    'Inline drawing',
    'Live object',
    'Linked section',
    'Horizontal rule',
    'Tasks View',
    'Related Notes',
    'Recent Notes',
    'Recent Activity',
    'Backlinks',
    'Project Progress',
    'Upcoming Deadlines',
    'Completed Tasks',
    'Current Date',
    'Current Timestamp',
  ];
  Future<void> command(String name, {bool fromSlash = false}) async {
    if (name == 'Inline drawing' || name == 'Live object') {
      await widget.onCompositionCommand?.call(name);
      return;
    }
    if (name == 'Linked section') {
      await insertFrom(widget.onInsertLinkedSection);
      return;
    }
    final nested = FocusManager.instance.primaryFocus?.context
        ?.findAncestorStateOfType<RichMarkdownEditorState>();
    if (!fromSlash &&
        nested != null &&
        nested != this &&
        nested.context.findAncestorStateOfType<RichMarkdownEditorState>() ==
            this) {
      await nested.command(name);
      return;
    }
    final block = current;
    final content = fromSlash ? '' : block.content;
    if (name == 'Two columns' || name == 'Three columns') {
      try {
        final value = NoteColumns.create([
          fromSlash ? '' : block.source,
          if (name == 'Three columns') '\n',
          '\n',
        ], eol: MarkdownBlockEditing.eol(document));
        _replace(block, value, structural: true);
      } on FormatException catch (error) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    }
    if (name == 'Image and text') {
      final before = block.source;
      final note = widget.noteId, documentBefore = _positions.source;
      final insert = widget.onInsertAttachment;
      if (insert == null) return;
      final raw = await insert();
      if (raw == null || !mounted) return;
      final match = RegExp(
        r'^!\[[^\]]*\]\((?:<([^>]+)>|([^ )]+))',
      ).firstMatch(raw.trim());
      if (match == null) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Choose an image for an image-and-text section.'),
          ),
        );
        return;
      }
      final section = MediaSectionSource.create(
        match[1] ?? match[2]!,
        body: content.isEmpty ? '### Title\n\n- Add a detail\n' : content,
        eol: MarkdownBlockEditing.eol(document),
      );
      if (_positions.indexOf(block) < 0 ||
          block.source != before ||
          widget.noteId != note ||
          _positions.source != documentBefore) {
        return;
      }
      _replace(block, section, structural: true);
      return;
    }
    final prefix = switch (name) {
      'Text' => '',
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
      _replace(
        block,
        '${block.alignmentPrefix}$prefix$content${block.suffix}',
        structural: true,
        focusOffset:
            block.alignmentPrefix.length + prefix.length + content.length,
      );
      return;
    }
    if (name == 'Current Date') {
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      _replace(
        block,
        fromSlash
            ? dateStr
            : (block.source.isEmpty ? dateStr : '${block.source} $dateStr'),
        structural: true,
        focusOffset: fromSlash
            ? dateStr.length
            : (block.source.isEmpty
                  ? dateStr.length
                  : block.source.length + 1 + dateStr.length),
      );
      return;
    }
    if (name == 'Current Timestamp') {
      final now = DateTime.now();
      final timeStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      _replace(
        block,
        fromSlash
            ? timeStr
            : (block.source.isEmpty ? timeStr : '${block.source} $timeStr'),
        structural: true,
        focusOffset: fromSlash
            ? timeStr.length
            : (block.source.isEmpty
                  ? timeStr.length
                  : block.source.length + 1 + timeStr.length),
      );
      return;
    }
    if (name == 'Highlight') {
      await format(NoteFormatAction.highlight);
      return;
    }
    if (name == 'Underline') {
      await format(NoteFormatAction.underline);
      return;
    }
    if (name == 'Footnote') {
      insertFootnote();
      return;
    }
    if (name == 'Image / file') {
      await insertFrom(widget.onInsertAttachment);
      return;
    }
    if (name == 'Inline equation') {
      const code = r'\square';
      final start = _positions.offsetOf(_positions.indexOf(block));
      if (fromSlash) {
        _newMathOffset = start;
        _replace(block, '\$$code\$\n', structural: true);
      } else {
        final field = keys[block]?.currentState;
        if (field == null) {
          _newMathOffset = start + block.source.length + 2;
          _replace(block, '${block.source}\n\n\$$code\$\n', structural: true);
          return;
        }
        final selection = field.controller.selection;
        final offset = selection.isValid
            ? selection.start
            : field.controller.text.length;
        _newMathOffset =
            start +
            block.prefix.length +
            field.controller.projection.sourceOffset(offset);
        field.insert('\$$code\$');
        _replace(block, block.source, structural: true);
        setState(() {
          cache.remove(block);
        });
      }
      return;
    }
    if (name == 'Block equation') {
      const code = r'\square';
      final syntax = '\$\$\n$code\n\$\$\n';
      _newMathOffset =
          _positions.offsetOf(_positions.indexOf(block)) +
          (block.source.isEmpty || fromSlash ? 0 : block.source.length + 1);
      _replace(
        block,
        block.source.isEmpty || fromSlash ? syntax : '${block.source}\n$syntax',
        structural: true,
      );
      return;
    }
    if (name == 'Matrix') {
      final code = await showMathGrid(
        context,
        initial: MathGrid('pmatrix', [
          ['1', '0'],
          ['0', '1'],
        ]),
      );
      if (code == null || !mounted) return;
      final syntax = '\$\$\n$code\n\$\$\n';
      _replace(
        block,
        block.source.isEmpty ? syntax : '${block.source}\n$syntax',
        structural: true,
      );
      return;
    }
    if (name == 'Cases') {
      const code =
          '\\begin{cases}\n\\square & \\text{if } \\square \\\\\n\\square & \\text{if } \\square\n\\end{cases}';
      final syntax = '\$\$\n$code\n\$\$\n';
      _replace(
        block,
        block.source.isEmpty ? syntax : '${block.source}\n$syntax',
        structural: true,
      );
      return;
    }
    if (name == 'Math symbols') {
      await _showMathSymbolsPalette(block);
      return;
    }
    var syntax = switch (name) {
      'Code block' => '```text\n${content.isEmpty ? 'code' : content}\n```\n',
      'Horizontal rule' => '---\n',
      'Callout' =>
        '> [!NOTE]\n> ${content.isEmpty ? 'A useful observation.' : content}\n',
      'Definition' =>
        '> [!DEFINITION]\n> ${content.isEmpty ? 'A definition statement.' : content}\n',
      'Theorem' =>
        '> [!THEOREM]\n> ${content.isEmpty ? 'A theorem statement.' : content}\n',
      'Lemma' =>
        '> [!LEMMA]\n> ${content.isEmpty ? 'A lemma statement.' : content}\n',
      'Proof' =>
        '> [!PROOF]\n> ${content.isEmpty ? 'Proof of the statement.' : content}\n',
      'Example' =>
        '> [!EXAMPLE]\n> ${content.isEmpty ? 'An example.' : content}\n',
      'Question' =>
        '> [!QUESTION]\n> ${content.isEmpty ? 'A question or unclear item.' : content}\n',
      _ => '',
    };
    if (name == 'Table') {
      var rows = 2, columns = 2;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, set) => AlertDialog(
            title: const Text('Insert table'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('Rows'),
                    const SizedBox(width: 16),
                    DropdownButton<int>(
                      value: rows,
                      items: List.generate(
                        10,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text('${i + 1}'),
                        ),
                      ),
                      onChanged: (v) => set(() => rows = v!),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Columns'),
                    const SizedBox(width: 16),
                    DropdownButton<int>(
                      value: columns,
                      items: List.generate(
                        8,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text('${i + 1}'),
                        ),
                      ),
                      onChanged: (v) => set(() => columns = v!),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Insert'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || accepted != true || !document.blocks.contains(block)) {
        return;
      }
      syntax = MarkdownTable([
        List.generate(columns, (i) => 'Column ${i + 1}'),
        ...List.generate(rows, (_) => List.filled(columns, '')),
      ], List.filled(columns, '---')).encode();
    }
    if (name == 'Tasks View') {
      syntax = '```orbit-view\ntype: tasks\nstatus: open\n```\n';
    } else if (name == 'Related Notes' || name == 'Backlinks') {
      syntax = '```orbit-view\ntype: related_notes\n```\n';
    } else if (name == 'Recent Notes') {
      syntax = '```orbit-view\ntype: recent_notes\n```\n';
    } else if (name == 'Recent Activity') {
      syntax = '```orbit-view\ntype: activity\n```\n';
    } else if (name == 'Project Progress') {
      syntax = '```orbit-view\ntype: progress\n```\n';
    } else if (name == 'Upcoming Deadlines') {
      syntax = '```orbit-view\ntype: upcoming\n```\n';
    } else if (name == 'Completed Tasks') {
      syntax = '```orbit-view\ntype: tasks\nstatus: completed\n```\n';
    }
    if (syntax.isEmpty) return;
    if (fromSlash ||
        block.content.isEmpty ||
        name.endsWith('View') ||
        name.contains('Notes') ||
        name.contains('Activity') ||
        name.contains('Progress') ||
        name.contains('Deadlines') ||
        name.contains('Tasks') ||
        name == 'Code block' ||
        name == 'Callout' ||
        name == 'Definition' ||
        name == 'Theorem' ||
        name == 'Lemma' ||
        name == 'Proof' ||
        name == 'Example' ||
        name == 'Question') {
      _replace(block, syntax, structural: true);
    } else {
      insertMarkdown(syntax);
    }
  }

  Future<void> _showMathSymbolsPalette(MarkdownBlock block) async {
    const symbols = [
      '∀',
      '∃',
      '∈',
      '∉',
      '⊂',
      '⊆',
      '∪',
      '∩',
      '⇒',
      '⇔',
      '¬',
      '∧',
      '∨',
      'ℕ',
      'ℤ',
      'ℚ',
      'ℝ',
      '∑',
      '∏',
      '√',
      '∞',
      '∫',
      '≈',
      '≠',
      '≤',
      '≥',
      '×',
      '·',
      '±',
      '∅',
    ];
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Math symbols'),
        content: SizedBox(
          width: 340,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final sym in symbols)
                InkWell(
                  onTap: () => Navigator.pop(ctx, sym),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(
                          ctx,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      sym,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (selected != null && mounted && document.blocks.contains(block)) {
      keys[block]?.currentState?.insert(selected);
      _replace(block, block.source, structural: true);
      setState(() => cache.remove(block));
    }
  }

  Future<void> slash(MarkdownBlock block) async {
    active = _positions.indexOf(block);
    final box =
        anchors[block]?.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final point = box.localToGlobal(Offset.zero);
    final validRecents = _recentCommands
        .where((c) => commands.contains(c))
        .toList();

    const basicCommands = [
      'Text',
      'Heading 1',
      'Heading 2',
      'Heading 3',
      'Bullet list',
      'Numbered list',
      'Checklist',
      'Quote',
    ];
    const richCommands = [
      'Two columns',
      'Three columns',
      'Inline drawing',
      'Live object',
      'Image / file',
      'Image and text',
      'Linked section',
      'Table',
      'Code block',
      'Inline equation',
      'Block equation',
      'Matrix',
      'Cases',
      'Math symbols',
    ];
    const knowledgeCommands = [
      'Callout',
      'Definition',
      'Theorem',
      'Lemma',
      'Proof',
      'Example',
      'Question',
      'Footnote',
      'Highlight',
      'Underline',
      'Horizontal rule',
      'Current Date',
      'Current Timestamp',
    ];
    const dynamicCommands = [
      'Tasks View',
      'Related Notes',
      'Recent Notes',
      'Recent Activity',
      'Backlinks',
      'Project Progress',
      'Upcoming Deadlines',
      'Completed Tasks',
    ];

    PopupMenuItem<String> headerItem(String label, IconData icon) =>
        PopupMenuItem<String>(
          enabled: false,
          height: 24,
          child: Row(
            children: [
              Icon(
                icon,
                size: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        );

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        point.dx,
        point.dy + 35,
        point.dx + 260,
        0,
      ),
      items: [
        if (validRecents.isNotEmpty) ...[
          headerItem('RECENT', Icons.history),
          for (final c in validRecents)
            PopupMenuItem(
              value: c,
              child: Row(
                children: [
                  const Icon(Icons.history, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(c, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          const PopupMenuDivider(),
        ],
        headerItem('BASIC BLOCKS', Icons.edit_note),
        for (final c in basicCommands) PopupMenuItem(value: c, child: Text(c)),
        const PopupMenuDivider(),
        headerItem('DYNAMIC VIEWS', Icons.widgets_outlined),
        for (final c in dynamicCommands)
          PopupMenuItem(
            value: c,
            child: Row(
              children: [
                Icon(
                  c.contains('Tasks')
                      ? Icons.checklist_outlined
                      : c.contains('Progress')
                      ? Icons.donut_large_outlined
                      : c.contains('Deadlines')
                      ? Icons.event_outlined
                      : c.contains('Activity')
                      ? Icons.timeline_outlined
                      : Icons.hub_outlined,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(c, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        const PopupMenuDivider(),
        headerItem('RICH MEDIA & MATH', Icons.data_object),
        for (final c in richCommands) PopupMenuItem(value: c, child: Text(c)),
        const PopupMenuDivider(),
        headerItem('KNOWLEDGE & CALLOUTS', Icons.lightbulb_outline),
        for (final c in knowledgeCommands)
          PopupMenuItem(value: c, child: Text(c)),
      ],
    );
    if (!mounted || result == null || !document.blocks.contains(block)) return;
    _recentCommands.remove(result);
    _recentCommands.insert(0, result);
    if (_recentCommands.length > 4) _recentCommands.removeLast();
    active = _positions.indexOf(block);
    await command(result, fromSlash: true);
  }

  void _applyBoundaryEdit(MarkdownSourceEdit edit) {
    if (edit.source != _positions.source) {
      _load(edit.source);
      widget.onChanged(edit.source);
      setState(() {});
    }
    _focusOffset(edit.offset);
    if (edit.notice != null) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(edit.notice!)));
    }
  }

  void _enter(MarkdownBlock block, TextEditingValue value) {
    final field = keys[block]?.currentState;
    final inherited = <String, (String, bool)>{...?field?._pendingMarks};
    final states = field?.formatStates ?? const <NoteFormatAction, String>{};
    for (final e in [
      (NoteFormatAction.bold, '**', '**'),
      (NoteFormatAction.italic, '*', '*'),
      (NoteFormatAction.highlight, '==', '=='),
      (NoteFormatAction.underline, '<u>', '</u>'),
      (NoteFormatAction.strike, '~~', '~~'),
    ]) {
      if (states[e.$1] == 'on') inherited[e.$2] = (e.$3, true);
    }
    _applyBoundaryEdit(
      MarkdownBlockEditing.split(
        document,
        _positions.indexOf(block),
        value.selection.start,
        value.selection.end,
      ),
    );
    final target = current;
    if (inherited.isNotEmpty) {
      _inheritedMarks[target] = inherited;
      cache.remove(target);
    }
  }

  void _splitBlock(MarkdownBlock block, String left, String right) {
    final eol = block.source.contains('\r\n') ? '\r\n' : '\n';
    final ending = block.source.endsWith('\n') ? eol : '';
    var nextPrefix = block.alignmentPrefix;
    if (block.kind == MarkdownBlockKind.list) {
      nextPrefix = block.prefix.replaceFirst(RegExp(r'\[[xX]\]'), '[ ]');
      nextPrefix = nextPrefix.replaceFirstMapped(
        RegExp(r'\d+(?=[.)])'),
        (m) => '${int.parse(m[0]!) + 1}',
      );
    }
    final first = '${block.prefix}$left${block.suffix}'.replaceFirst(
      RegExp(r'\r?\n$'),
      '',
    );
    final separator = block.kind == MarkdownBlockKind.list ? eol : '$eol$eol';
    final secondStart = first.length + separator.length + nextPrefix.length;
    _replace(
      block,
      '$first$separator$nextPrefix$right$ending',
      structural: true,
      focusOffset: secondStart,
    );
  }

  bool _joinPrevious(MarkdownBlock block) {
    final edit = MarkdownBlockEditing.backspace(
      document,
      _positions.indexOf(block),
    );
    if (edit == null) return false;
    _applyBoundaryEdit(edit);
    return true;
  }

  bool _joinNext(MarkdownBlock block) {
    final edit = MarkdownBlockEditing.deleteForward(
      document,
      _positions.indexOf(block),
    );
    if (edit == null) return false;
    _applyBoundaryEdit(edit);
    return true;
  }

  void _indent(MarkdownBlock block, bool outdent) {
    final next = MarkdownEditing.indentList(
      TextEditingValue(
        text: block.source,
        selection: TextSelection.collapsed(offset: block.prefix.length + caret),
      ),
      outdent: outdent,
    );
    if (next != null) {
      _replace(
        block,
        next.text,
        structural: true,
        focusOffset: next.selection.extentOffset,
      );
    }
  }

  int? _takeMathFocus(MarkdownBlock block) {
    final offset = _newMathOffset;
    if (offset == null) return null;
    final start = _positions.offsetOf(_positions.indexOf(block));
    if (offset < start || offset >= start + block.source.length) return null;
    _newMathOffset = null;
    return offset - start - block.prefix.length;
  }

  Widget blockView(MarkdownBlock block) {
    final linked = LinkedSection.parse(block.source);
    if (linked != null) {
      return LinkedSectionCard(
        link: linked,
        objects: widget.allObjects,
        ancestors: {if (widget.noteId != null) widget.noteId!},
        onOpen: widget.onOpenLink,
        imageBuilder: widget.imageBuilder,
        typography: NoteTypography(
          fontFamily: widget.fontFamily ?? 'Segoe UI',
          fontSize: widget.fontSize,
          lineHeight: widget.lineHeight,
        ),
        onRemove: () => _replace(block, '', structural: true),
        onCopy: (text) => _replace(
          block,
          text.endsWith('\n')
              ? text
              : '$text${MarkdownBlockEditing.eol(document)}',
          structural: true,
        ),
      );
    }
    if (block.kind == MarkdownBlockKind.blank) {
      return HoverChrome(
        child: SizedBox(
          height: 16,
          child: Row(
            children: [
              Expanded(child: Divider(color: Theme.of(context).dividerColor)),
              SizedBox(
                width: 28,
                child: IconButton(
                  tooltip: 'Insert paragraph here',
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    final offset = _positions.offsetOf(
                      _positions.indexOf(block),
                    );
                    final eol = block.source.contains('\r\n') ? '\r\n' : '\n';
                    final body = _positions.source.replaceRange(
                      offset,
                      offset,
                      '$eol$eol',
                    );
                    _load(body);
                    widget.onChanged(body);
                    _focusOffset(offset + eol.length);
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (block.kind == MarkdownBlockKind.table) {
      return RichTableEditor(
        source: block.source,
        textStyle: NoteTypography(
          fontFamily: widget.fontFamily,
          fontSize: widget.fontSize,
          lineHeight: widget.lineHeight,
        ).body(),
        onFocused: () => _activateStructured(block),
        onChanged: (v) => _replace(block, v),
        onUndo: widget.onUndo,
        onRedo: widget.onRedo,
      );
    }
    if (block.kind == MarkdownBlockKind.callout) {
      return CalloutBlock(
        source: block.source,
        textStyle: NoteTypography(
          fontFamily: widget.fontFamily,
          fontSize: widget.fontSize,
          lineHeight: widget.lineHeight,
        ).body(),
        onFocused: () => _activateStructured(block),
        onChanged: (v) => _replace(block, v),
        onUndo: widget.onUndo,
        onRedo: widget.onRedo,
      );
    }
    if (block.kind == MarkdownBlockKind.math) {
      final autofocus = _takeMathFocus(block) != null;
      return Center(
        child: RichMathBlock(
          content: block.content,
          autofocus: autofocus,
          onUndo: widget.onUndo,
          onRedo: widget.onRedo,
          onChanged: (v) {
            final needsSeparator =
                block.prefix.endsWith('\n') &&
                !block.suffix.startsWith(RegExp(r'\r?\n')) &&
                v.isNotEmpty;
            final separator = needsSeparator
                ? (block.source.contains('\r\n') ? '\r\n' : '\n')
                : '';
            _replace(
              block,
              '${block.prefix}$v$separator${block.suffix}',
              structural: needsSeparator,
            );
          },
        ),
      );
    }
    if (block.kind == MarkdownBlockKind.code) {
      // A delimiter-line edit can grow the fence and replace this block during
      // _load. Keep the original position so a second input event arriving
      // before the next frame still edits the current code block instead of
      // being discarded by an obsolete block identity.
      final codeBlockIndex = _positions.indexOf(block);
      if (DynamicViewBlock.isDynamicView(block.language, block.content)) {
        return DynamicViewBlock(
          source: block.source,
          noteId: widget.noteId,
          onChanged: (v) => _replace(block, v),
        );
      }
      if (SnapshotBlock.isSnapshot(block.language, block.content)) {
        return SnapshotBlock(
          source: block.source,
          onChanged: (v) => _replace(block, v),
        );
      }
      return NoteCodeBlock(
        code: block.content,
        language: block.language,
        onUndo: widget.onUndo,
        onRedo: widget.onRedo,
        onFocused: () => _activateStructured(block),
        onChanged: (v) {
          var currentBlock = block;
          if (_positions.indexOf(currentBlock) < 0 &&
              codeBlockIndex >= 0 &&
              codeBlockIndex < document.blocks.length &&
              document.blocks[codeBlockIndex].kind == MarkdownBlockKind.code) {
            currentBlock = document.blocks[codeBlockIndex];
          }
          final edited = replaceFencedCodeContent(currentBlock, v);
          final structural =
              edited.prefix != currentBlock.prefix ||
              edited.suffix != currentBlock.suffix;
          final selection = FocusManager.instance.primaryFocus?.context
              ?.findAncestorStateOfType<NoteCodeBlockState>()
              ?.sourceSelection;
          _replace(
            currentBlock,
            edited.source,
            structural: structural,
            focusOffset: structural && selection != null
                ? edited.prefix.length + selection.extentOffset
                : null,
          );
        },
      );
    }
    final linkedObject = NoteObjectBlock.parse(block.source);
    if (linkedObject != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          widget.objectBlockBuilder?.call(linkedObject, true) ??
              TextButton(
                onPressed: () =>
                    widget.onOpenLink('orbit-object:${linkedObject.id}'),
                child: Text(linkedObject.label),
              ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _replace(block, '', structural: true),
              child: const Text('Remove embed'),
            ),
          ),
        ],
      );
    }
    final columns = NoteColumns.parse(block.source);
    if (columns != null) {
      Widget editor(int i) => RichMarkdownEditor(
        key: _columnKeys.putIfAbsent((
          block,
          i,
        ), () => GlobalKey<RichMarkdownEditorState>()),
        body: columns.parts[i],
        inheritedDefinitions: document.referenceDefinitions,
        embedded: true,
        onState: (value) {
          final selection = value['selection'];
          if (selection is Map &&
              selection['base'] is int &&
              selection['extent'] is int &&
              _positions.indexOf(block) >= 0) {
            active = _positions.indexOf(block);
            _columnSelection = (
              block,
              i,
              TextSelection(
                baseOffset: selection['base'] as int,
                extentOffset: selection['extent'] as int,
              ),
            );
            record();
          }
        },
        onChanged: (body) {
          try {
            final current = NoteColumns.parse(block.source);
            if (current != null && _positions.indexOf(block) >= 0) {
              _replace(block, current.replace(i, body));
            }
          } on FormatException catch (error) {
            ScaffoldMessenger.maybeOf(
              context,
            )?.showSnackBar(SnackBar(content: Text(error.message)));
          }
        },
        onUndo: widget.onUndo,
        onRedo: widget.onRedo,
        linkTargets: widget.linkTargets,
        linkBindings: widget.linkBindings,
        onOpenLink: widget.onOpenLink,
        allObjects: widget.allObjects,
        fontSize: widget.fontSize,
        fontFamily: widget.fontFamily,
        lineHeight: widget.lineHeight,
        imageBuilder: widget.imageBuilder,
        onInsertAttachment: widget.onInsertAttachment,
        objectBlockBuilder: widget.objectBlockBuilder,
        onCompositionCommand: widget.onCompositionCommand,
        attachmentRevision: widget.attachmentRevision,
        spellCheckEnabled: widget.spellCheckEnabled,
        userDictionary: widget.userDictionary,
        onAddToUserDictionary: widget.onAddToUserDictionary,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            children: [
              TextButton(
                onPressed: () => _replace(
                  block,
                  NoteColumns.create(
                    columns.parts.reversed.toList(),
                    eol: columns.eol,
                  ),
                ),
                child: const Text('Reverse columns'),
              ),
              TextButton(
                onPressed: () =>
                    _replace(block, columns.stacked, structural: true),
                child: const Text('Stack as Markdown'),
              ),
            ],
          ),
          NoteColumnsLayout(
            children: [
              for (var i = 0; i < columns.parts.length; i++) editor(i),
            ],
          ),
        ],
      );
    }
    if (block.kind == MarkdownBlockKind.media) {
      final section = MediaSectionSource.parse(block.source)!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HoverChrome(
            child: Wrap(
              children: [
                PopupMenuButton<String>(
                  tooltip: 'Image layout',
                  onSelected: (value) {
                    final parts = value.split(':');
                    _replace(
                      block,
                      section.configure(parts[0], int.parse(parts[1])),
                      structural: true,
                    );
                  },
                  itemBuilder: (_) => [
                    for (final side in ['left', 'right'])
                      for (final size in [160, 200, 260])
                        PopupMenuItem(
                          value: '$side:$size',
                          child: Text('Image $side · $size px'),
                        ),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Image layout'),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final before = block.source, note = widget.noteId;
                    final value = await showFigureDetails(
                      context,
                      section.figure,
                      widget.linkTargets,
                    );
                    if (value == null || !mounted) return;
                    if (widget.noteId != note ||
                        block.source != before ||
                        _positions.indexOf(block) < 0) {
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'This figure changed. Reopen caption and sources before applying.',
                          ),
                        ),
                      );
                      return;
                    }
                    _replace(
                      block,
                      section.withFigure(value),
                      structural: true,
                    );
                  },
                  child: const Text('Caption and sources'),
                ),
                TextButton(
                  onPressed: () => _replace(
                    block,
                    '${section.imageMarkdown}\n${section.body}',
                    structural: true,
                  ),
                  child: const Text('Stack as Markdown'),
                ),
                TextButton(
                  onPressed: widget.onInsertAttachment == null
                      ? null
                      : () async {
                          final before = block.source;
                          final note = widget.noteId,
                              documentBefore = _positions.source;
                          final raw = await widget.onInsertAttachment!();
                          if (!mounted ||
                              raw == null ||
                              block.source != before ||
                              _positions.indexOf(block) < 0 ||
                              widget.noteId != note ||
                              _positions.source != documentBefore) {
                            return;
                          }
                          final match = RegExp(
                            r'^!\[[^\]]*\]\((?:<([^>]+)>|([^ )]+))',
                          ).firstMatch(raw.trim());
                          if (match == null) return;
                          final next = MediaSectionSource.parse(
                            MediaSectionSource.create(
                              match[1] ?? match[2]!,
                              body: section.body,
                              eol: MarkdownBlockEditing.eol(document),
                            ),
                          )!;
                          _replace(
                            block,
                            next.configure(section.side, section.width),
                            structural: true,
                          );
                        },
                  child: const Text('Replace image'),
                ),
                TextButton(
                  onPressed: () =>
                      _replace(block, section.body, structural: true),
                  child: const Text('Remove image'),
                ),
              ],
            ),
          ),
          MediaSectionLayout(
            section: section,
            footer: section.figure == null
                ? null
                : FigureFooter(
                    details: section.figure!,
                    fontFamily: widget.fontFamily,
                    onOpen: widget.onOpenLink,
                    missingNotes: {
                      for (final citation in section.figure!.citations)
                        if (citation.destination.startsWith('orbit-object:') &&
                            !widget.linkTargets.any(
                              (t) =>
                                  t.id == Uri.parse(citation.destination).path,
                            ))
                          citation.destination,
                    },
                  ),
            image: InkWell(
              onTap: () => widget.onOpenLink(section.image),
              child:
                  widget.imageBuilder?.call(context, section.image) ??
                  const Icon(Icons.image_outlined, size: 120),
            ),
            text: RichMarkdownEditor(
              body: section.textBody,
              inheritedDefinitions: document.referenceDefinitions,
              embedded: true,
              onChanged: (body) {
                final source = section.replaceTextBody(body);
                _replace(
                  block,
                  source,
                  structural: MediaSectionSource.parse(source) == null,
                );
              },
              onUndo: widget.onUndo,
              onRedo: widget.onRedo,
              linkTargets: widget.linkTargets,
              linkBindings: widget.linkBindings,
              onOpenLink: widget.onOpenLink,
              allObjects: widget.allObjects,
              fontSize: widget.fontSize,
              fontFamily: widget.fontFamily,
              lineHeight: widget.lineHeight,
              imageBuilder: widget.imageBuilder,
              onInsertAttachment: widget.onInsertAttachment,
              objectBlockBuilder: widget.objectBlockBuilder,
              onCompositionCommand: widget.onCompositionCommand,
              attachmentRevision: widget.attachmentRevision,
              spellCheckEnabled: widget.spellCheckEnabled,
              userDictionary: widget.userDictionary,
              onAddToUserDictionary: widget.onAddToUserDictionary,
            ),
          ),
        ],
      );
    }
    if (block.kind == MarkdownBlockKind.rule) return const Divider(height: 32);
    if (block.kind == MarkdownBlockKind.image) {
      final match = RegExp(
        r'^!\[([^\]]*)\]\((?:<([^>]+)>|([^ )]+))(?: +"[^"]*")?\)',
      ).firstMatch(block.content);
      if (match != null) {
        final imageUri = match[2] ?? match[3]!;
        final altText = match[1] ?? '';
        return _RichImageBlock(
          onSelect: () {
            final index = _positions.indexOf(block);
            if (index >= 0) selectBlockRange(index, index);
          },
          onCopy: () async {
            await _writeClipboard(
              portableClipboardMarkdown(
                block.source,
                widget.resolveClipboardImage,
              ),
            );
          },
          onCut: () async {
            final source = _positions.source;
            try {
              if (!await _writeClipboard(
                portableClipboardMarkdown(
                  block.source,
                  widget.resolveClipboardImage,
                ),
              )) {
                return;
              }
              if (mounted &&
                  _positions.source == source &&
                  _positions.indexOf(block) >= 0) {
                _replace(block, '', structural: true);
              }
            } catch (_) {}
          },
          imageUri: imageUri,
          altText: altText,
          imageBuilder: widget.imageBuilder,
          onOpen: () => widget.onOpenLink(imageUri),
          onRemove: () => _replace(block, '', structural: true),
          onAddText: () => _replace(
            block,
            MediaSectionSource.create(
              imageUri,
              imageMarkdown: block.content,
              eol: MarkdownBlockEditing.eol(document),
            ),
            structural: true,
          ),
        );
      }
    }
    // Inline equations are individually editable widgets among real text fields.
    if (block.kind == MarkdownBlockKind.text &&
        !_continuousMath.contains(block) &&
        inlineMathMatches(block.content).isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _continuousMath.add(block);
                  cache.remove(block);
                });
                record();
              },
              icon: const Icon(Icons.text_fields, size: 16),
              label: const Text('Edit paragraph continuously'),
            ),
          ),
          _InlineMathParagraph(
            alignment: block.alignment,
            focusEquationAt: _takeMathFocus(block),
            source: block.content,
            lineEnding: MarkdownBlockEditing.eol(document),
            fontSize: widget.fontSize,
            fontFamily: widget.fontFamily,
            lineHeight: widget.lineHeight,
            onChanged: (v, offset) {
              final structural =
                  offset != null && _changedLineBreaks(block.content, v);
              _replace(
                block,
                block.replaceContent(v),
                structural: structural,
                focusOffset: structural ? block.prefix.length + offset : null,
              );
            },
            onUndo: widget.onUndo,
            onRedo: widget.onRedo,
            onSplit: (left, right) => _splitBlock(block, left, right),
            grammarEngine: grammarEngine,
            spellCheckEnabled: widget.spellCheckEnabled,
            onAddToDictionary: widget.onAddToUserDictionary,
            onIgnore: (word) {
              grammarEngine.ignoreWord(word);
              for (final k in keys.values) {
                k.currentState?.controller.refreshStyle();
              }
            },
          ),
        ],
      );
    }
    final raw =
        block.kind == MarkdownBlockKind.raw ||
        block.kind == MarkdownBlockKind.image;
    final field = _RichTextBlock(
      key: keys.putIfAbsent(block, () => GlobalKey<_RichTextBlockState>()),
      source: raw ? block.source : block.content,
      raw: raw,
      lineEnding: MarkdownBlockEditing.eol(document),
      grammarEngine: grammarEngine,
      spellCheckEnabled: widget.spellCheckEnabled,
      referenceDefinitions: document.referenceDefinitions,
      linkTargets: widget.linkTargets,
      linkBindings: widget.linkBindings,
      allObjects: widget.allObjects,
      onOpenLink: widget.onOpenLink,
      onOpenFootnote: widget.onOpenFootnote,
      initialMarks: _inheritedMarks.remove(block) ?? const {},
      onOpenInNewTab: widget.onOpenInNewTab,
      onOpenToSide: widget.onOpenToSide,
      onShowBacklinks: widget.onShowBacklinks,
      onRevealInExplorer: widget.onRevealInExplorer,
      onAddToDictionary: widget.onAddToUserDictionary,
      onIgnore: (word) {
        grammarEngine.ignoreWord(word);
        for (final k in keys.values) {
          k.currentState?.controller.refreshStyle();
        }
      },
      textAlign: switch (block.alignment) {
        'center' => TextAlign.center,
        'right' => TextAlign.right,
        _ => TextAlign.left,
      },
      style: raw
          ? TextStyle(
              fontSize: widget.fontSize,
              height: widget.lineHeight,
              fontFamily: 'monospace',
            )
          : block.kind == MarkdownBlockKind.heading
          ? NoteTypography(
              fontFamily: widget.fontFamily,
              fontSize: widget.fontSize,
              lineHeight: widget.lineHeight,
            ).heading(block.level)
          : NoteTypography(
              fontFamily: widget.fontFamily,
              fontSize: widget.fontSize,
              lineHeight: widget.lineHeight,
            ).body(),
      initialCaret: _positions.indexOf(block) == active ? caret : 0,
      initialBase: _positions.indexOf(block) == active ? selectionBase : 0,
      onFocus: (position) {
        final index = _positions.indexOf(block);
        // A structural paste replaces this block before its old controller
        // finishes notifying listeners. Ignore that stale selection so it cannot
        // cancel the focus request for the newly created paragraph.
        if (index < 0) return;
        active = index;
        caret = position.extentOffset;
        selectionBase = position.baseOffset;
        record();
      },
      onChanged: (v) {
        final state = keys[block]?.currentState;
        final structural =
            state?.controller.value.composing.isCollapsed == true &&
            ((raw && RegExp(r'^ {0,3}\[.*\]:').hasMatch(block.source)) ||
                (!raw && _changedLineBreaks(block.content, v)));
        final localCaret = structural
            ? raw
                  ? state!.controller.selection.extentOffset
                  : block.prefix.length +
                        InlineProjection(
                          v,
                          referenceDefinitions: document.referenceDefinitions,
                        ).sourceOffset(state!.controller.selection.extentOffset)
            : null;
        _replace(
          block,
          raw ? v : block.replaceContent(v),
          structural: structural,
          focusOffset: localCaret,
        );
        if (v == '/') slash(block);
        if (v.endsWith('[[')) {
          active = _positions.indexOf(block);
          format(NoteFormatAction.link);
        }
      },
      onEnter: raw ? null : (v) => _enter(block, v),
      onJoinPrevious: raw ? null : () => _joinPrevious(block),
      onJoinNext: raw ? null : () => _joinNext(block),
      onIndent: block.kind == MarkdownBlockKind.list
          ? (out) => _indent(block, out)
          : null,
      onUndo: widget.onUndo,
      onRedo: widget.onRedo,
      onPasteImage: widget.onPasteImage == null
          ? null
          : () => insertFrom(widget.onPasteImage),
      onSelectAllDocument: selectAllBlocks,
      onExtendSelectionDown: () => _extendFromBlock(block, down: true),
      onExtendSelectionUp: () => _extendFromBlock(block, down: false),
      onMoveUp: () => moveCurrentBlockUp(),
      onMoveDown: () => moveCurrentBlockDown(),
      onDuplicate: () => duplicateCurrentBlock(),
      hasDocumentSelection: () => hasCrossDocumentSelection,
      onReplaceDocumentSelection: replaceCrossDocumentSelection,
      onCopyDocumentSelection: copyCrossDocumentSelection,
      onCutDocumentSelection: cutCrossDocumentSelection,
      onDeleteDocumentSelection: deleteCrossDocumentSelection,
    );
    if (raw) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preserved source block',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            field,
          ],
        ),
      );
    }
    if (_continuousMath.contains(block)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          field,
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: () => setState(() {
                  _continuousMath.remove(block);
                  cache.remove(block);
                }),
                child: const Text('Rendered equations'),
              ),
              for (final m in inlineMathMatches(block.content))
                EditableMathExpression(
                  source: m[1]!,
                  onUndo: widget.onUndo,
                  onRedo: widget.onRedo,
                  onChanged: (v) => _replace(
                    block,
                    block.replaceContent(
                      block.content.replaceRange(m.start, m.end, '\$$v\$'),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (block.kind == MarkdownBlockKind.list) ...[
          SizedBox(width: block.level * 7.0),
          if (block.checked != null)
            SizedBox(
              width: 32,
              height: 30,
              child: Checkbox(
                value: block.checked,
                onChanged: (v) => _replace(
                  block,
                  block.source.replaceFirst(
                    RegExp(r'\[[ xX]\]'),
                    v == true ? '[x]' : '[ ]',
                  ),
                  structural: true,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 5, right: 10),
              child: Text(
                RegExp(r'\d+[.)]').firstMatch(block.prefix)?[0] ?? '•',
              ),
            ),
        ],
        if (block.kind == MarkdownBlockKind.quote)
          Container(
            width: 3,
            height: 32,
            margin: const EdgeInsets.only(right: 12),
            color: Theme.of(context).colorScheme.primary,
          ),
        Expanded(child: field),
      ],
    );
  }

  List<MarkdownBlock> get movableBlocks {
    final result = <MarkdownBlock>[];
    for (var i = 0; i < document.blocks.length; i++) {
      final b = document.blocks[i];
      if (b.kind == MarkdownBlockKind.blank) continue;
      // Pinned index 0 frontmatter raw block cannot be moved
      if (i == 0 &&
          b.kind == MarkdownBlockKind.raw &&
          b.source.startsWith('---')) {
        continue;
      }
      result.add(b);
    }
    return result;
  }

  void _moveBlocks(
    List<MarkdownBlock> sourceBlocks,
    MarkdownBlock targetBlock, {
    required bool after,
  }) {
    final nonBlankSources = sourceBlocks
        .where((b) => b.kind != MarkdownBlockKind.blank)
        .toList();
    if (nonBlankSources.isEmpty) return;
    if (nonBlankSources.contains(targetBlock)) return;
    if (targetBlock.kind == MarkdownBlockKind.raw &&
        targetBlock.source.startsWith('---')) {
      return;
    }

    final groups = <List<MarkdownBlock>>[];
    final leadingBlanks = <MarkdownBlock>[];
    List<MarkdownBlock>? frontmatterGroup;

    for (var i = 0; i < document.blocks.length; i++) {
      final b = document.blocks[i];
      if (i == 0 &&
          b.kind == MarkdownBlockKind.raw &&
          b.source.startsWith('---')) {
        frontmatterGroup = [b];
        continue;
      }
      if (b.kind == MarkdownBlockKind.blank) {
        if (groups.isNotEmpty) {
          groups.last.add(b);
        } else if (frontmatterGroup != null) {
          frontmatterGroup.add(b);
        } else {
          leadingBlanks.add(b);
        }
      } else {
        groups.add([b]);
      }
    }

    final fromIndices =
        nonBlankSources
            .map((b) => groups.indexWhere((g) => g.first == b))
            .where((idx) => idx >= 0)
            .toSet()
            .toList()
          ..sort();
    if (fromIndices.isEmpty) return;

    final movingGroups = <List<MarkdownBlock>>[];
    for (final idx in fromIndices.reversed) {
      movingGroups.insert(0, groups.removeAt(idx));
    }

    var toGroupIdx = groups.indexWhere((g) => g.first == targetBlock);
    if (toGroupIdx < 0) return;

    var insertIdx = toGroupIdx;
    if (after) {
      insertIdx += 1;
    }
    groups.insertAll(insertIdx, movingGroups);

    final finalBlocks = <MarkdownBlock>[
      ...leadingBlanks,
      ...?frontmatterGroup,
      for (final g in groups) ...g,
    ];

    final buffer = StringBuffer();
    var movedOffset = 0;
    var movedEndOffset = 0;
    final headingIds = [
      for (final b in finalBlocks)
        if (b.kind == MarkdownBlockKind.heading) _headingKey(b),
    ];
    final eol = _positions.source.contains('\r\n') ? '\r\n' : '\n';
    final firstMovedBlock = nonBlankSources.first;
    final lastMovedBlock = nonBlankSources.last;

    for (var i = 0; i < finalBlocks.length; i++) {
      final b = finalBlocks[i];
      if (identical(b, firstMovedBlock)) movedOffset = buffer.length;
      if (identical(b, lastMovedBlock)) {
        movedEndOffset = buffer.length + b.source.length;
      }
      buffer.write(b.source);
      if (!b.source.endsWith('\n') && i < finalBlocks.length - 1) {
        buffer.write(eol);
      }
      if (i < finalBlocks.length - 1 &&
          b.kind == MarkdownBlockKind.text &&
          finalBlocks[i + 1].kind == MarkdownBlockKind.text) {
        // A moved final paragraph may have no trailing spacer. Keep it a
        // separate paragraph without altering any existing blank lines.
        buffer.write(eol);
      }
    }

    final newSource = buffer.toString();
    _load(newSource);

    var headingIndex = 0;
    for (final block in document.blocks) {
      if (block.kind == MarkdownBlockKind.heading &&
          headingIndex < headingIds.length) {
        _headingIds[block] = headingIds[headingIndex++];
      }
    }
    widget.onChanged(newSource);

    final activeIdx = _positions.blockAt(movedOffset);
    if (nonBlankSources.length > 1) {
      final endMovedIdx = _positions.blockAt(
        (movedEndOffset - 1).clamp(movedOffset, newSource.length),
      );
      if (activeIdx >= 0 && endMovedIdx >= activeIdx) {
        selectBlockRange(activeIdx, endMovedIdx);
      } else {
        clearBlockSelection();
        active = activeIdx >= 0 ? activeIdx : 0;
      }
    } else {
      clearBlockSelection();
      active = activeIdx >= 0 ? activeIdx : 0;
      _focusOffset(_positions.offsetOf(activeIdx));
    }

    record();
    setState(() {});
  }

  void moveCurrentBlockUp() {
    final block = current;
    final allMovable = movableBlocks;
    final idx = allMovable.indexOf(block);
    if (idx > 0) {
      _moveBlocks([block], allMovable[idx - 1], after: false);
    }
  }

  void moveCurrentBlockDown() {
    final block = current;
    final allMovable = movableBlocks;
    final idx = allMovable.indexOf(block);
    if (idx >= 0 && idx < allMovable.length - 1) {
      _moveBlocks([block], allMovable[idx + 1], after: true);
    }
  }

  void moveSelectedBlocksUp() {
    if (!hasMultiBlockSelection) {
      moveCurrentBlockUp();
      return;
    }
    final nonBlank = selectedBlocks
        .where((b) => b.kind != MarkdownBlockKind.blank)
        .toList();
    if (nonBlank.isEmpty) return;
    final allMovable = movableBlocks;
    final firstIdx = allMovable.indexOf(nonBlank.first);
    if (firstIdx > 0) {
      _moveBlocks(selectedBlocks, allMovable[firstIdx - 1], after: false);
    }
  }

  void moveSelectedBlocksDown() {
    if (!hasMultiBlockSelection) {
      moveCurrentBlockDown();
      return;
    }
    final nonBlank = selectedBlocks
        .where((b) => b.kind != MarkdownBlockKind.blank)
        .toList();
    if (nonBlank.isEmpty) return;
    final allMovable = movableBlocks;
    final lastIdx = allMovable.indexOf(nonBlank.last);
    if (lastIdx >= 0 && lastIdx < allMovable.length - 1) {
      _moveBlocks(selectedBlocks, allMovable[lastIdx + 1], after: true);
    }
  }

  void duplicateSelectedBlocks() {
    if (!hasMultiBlockSelection) return;
    final edit = MarkdownBlockEditing.duplicate(
      document,
      selectedBlockMin,
      selectedBlockMax,
    );
    _load(edit.source);
    widget.onChanged(edit.source);
    final first = _positions.blockAt(edit.offset);
    final last = _positions.blockAt(
      (edit.endOffset - 1).clamp(edit.offset, edit.source.length),
    );
    selectBlockRange(first, last);
    record();
    setState(() {});
  }

  void duplicateCurrentBlock() {
    final index = _positions.indexOf(current);
    _applyBoundaryEdit(MarkdownBlockEditing.duplicate(document, index, index));
  }

  void _turnInto(MarkdownBlock block, String type) {
    final index = _positions.indexOf(block);
    if (index < 0) return;
    final edit = MarkdownBlockEditing.convert(document, index, type);
    if (edit != null &&
        (edit.source != _positions.source || edit.notice != null)) {
      _applyBoundaryEdit(edit);
    }
  }

  Future<void> _createTaskFromBlock(MarkdownBlock block) async {
    final title = block.content.trim().split('\n').first;
    if (title.isEmpty) return;
    if (widget.onCreateTask != null) {
      await widget.onCreateTask!(title);
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text('Created task: $title'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      _turnInto(block, 'Checklist');
    }
  }

  Future<void> _showTurnIntoMenu(
    BuildContext context,
    MarkdownBlock block,
  ) async {
    final originalSource = _positions.source, originalNote = widget.noteId;
    final box =
        anchors[block]?.currentContext?.findRenderObject() as RenderBox?;
    final point = box != null ? box.localToGlobal(Offset.zero) : Offset.zero;

    final type = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        point.dx + 48,
        point.dy + 28,
        point.dx + 260,
        0,
      ),
      items: const [
        PopupMenuItem(value: 'Text', child: Text('Text (Paragraph)')),
        PopupMenuItem(value: 'Heading 1', child: Text('Heading 1 (#)')),
        PopupMenuItem(value: 'Heading 2', child: Text('Heading 2 (##)')),
        PopupMenuItem(value: 'Heading 3', child: Text('Heading 3 (###)')),
        PopupMenuItem(value: 'Bullet list', child: Text('Bullet list (-)')),
        PopupMenuItem(
          value: 'Numbered list',
          child: Text('Numbered list (1.)'),
        ),
        PopupMenuItem(value: 'Checklist', child: Text('Checklist (- [ ])')),
        PopupMenuItem(value: 'Quote', child: Text('Quote (>)')),
        PopupMenuItem(value: 'Callout', child: Text('Callout (> [!NOTE])')),
        PopupMenuItem(value: 'Code block', child: Text('Code block (```)')),
      ],
    );
    if (type == null ||
        !mounted ||
        !document.blocks.contains(block) ||
        _positions.source != originalSource ||
        widget.noteId != originalNote) {
      return;
    }
    _turnInto(block, type);
  }

  Future<void> _showBlockContextMenu(
    BuildContext context,
    MarkdownBlock block,
  ) async {
    final originalSource = _positions.source, originalNote = widget.noteId;
    final box =
        anchors[block]?.currentContext?.findRenderObject() as RenderBox?;
    final point = box != null ? box.localToGlobal(Offset.zero) : Offset.zero;

    final allMovable = movableBlocks;
    final isSelected = hasMultiBlockSelection && isBlockSelected(block);
    final originalSelection = (_selectedBlockStart, _selectedBlockEnd);
    final movingSelection = isSelected ? selectedBlocks : [block];
    final nonBlankMoving = movingSelection
        .where((b) => b.kind != MarkdownBlockKind.blank)
        .toList();
    final firstIdx = nonBlankMoving.isNotEmpty
        ? allMovable.indexOf(nonBlankMoving.first)
        : -1;
    final lastIdx = nonBlankMoving.isNotEmpty
        ? allMovable.indexOf(nonBlankMoving.last)
        : -1;

    final canMoveUp = firstIdx > 0;
    final canMoveDown = lastIdx >= 0 && lastIdx < allMovable.length - 1;

    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        point.dx + 48,
        point.dy + 28,
        point.dx + 260,
        0,
      ),
      items: [
        PopupMenuItem(
          value: 'move_up',
          enabled: canMoveUp,
          child: Row(
            children: [
              const Icon(Icons.arrow_upward, size: 18),
              const SizedBox(width: 10),
              Flexible(
                child: Text(isSelected ? 'Move selected blocks up' : 'Move up'),
              ),
              const SizedBox(width: 8),
              Text(
                'Alt+↑',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'move_down',
          enabled: canMoveDown,
          child: Row(
            children: [
              const Icon(Icons.arrow_downward, size: 18),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  isSelected ? 'Move selected blocks down' : 'Move down',
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Alt+↓',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'duplicate',
          child: Row(
            children: [
              const Icon(Icons.copy_all, size: 18),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  isSelected ? 'Duplicate selected blocks' : 'Duplicate',
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Ctrl+D',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              const Icon(Icons.content_copy, size: 18),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  hasMultiBlockSelection && isBlockSelected(block)
                      ? 'Copy selected blocks'
                      : 'Copy Markdown',
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'copy_link',
          enabled:
              block.kind == MarkdownBlockKind.text &&
              block.content.trim().isNotEmpty &&
              widget.onCopyBlockReference != null,
          child: const Row(
            children: [
              Icon(Icons.link, size: 18),
              SizedBox(width: 10),
              Flexible(child: Text('Copy link to block')),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'turn_into',
          child: Row(
            children: [
              Icon(Icons.swap_horiz, size: 18),
              SizedBox(width: 10),
              Flexible(child: Text('Turn into...')),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'create_task',
          child: Row(
            children: [
              Icon(Icons.task_alt, size: 18),
              SizedBox(width: 10),
              Flexible(child: Text('Create Task from block')),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                size: 18,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  hasMultiBlockSelection && isBlockSelected(block)
                      ? 'Delete selected blocks'
                      : 'Delete',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (action == null ||
        !mounted ||
        !document.blocks.contains(block) ||
        _positions.source != originalSource ||
        widget.noteId != originalNote) {
      return;
    }
    if (!isSelected) active = _positions.indexOf(block);
    if (isSelected &&
        originalSelection != (_selectedBlockStart, _selectedBlockEnd)) {
      return;
    }

    switch (action) {
      case 'move_up':
        if (canMoveUp) {
          if (isSelected) {
            moveSelectedBlocksUp();
          } else {
            _moveBlocks([block], allMovable[firstIdx - 1], after: false);
          }
        }
      case 'move_down':
        if (canMoveDown) {
          if (isSelected) {
            moveSelectedBlocksDown();
          } else {
            _moveBlocks([block], allMovable[lastIdx + 1], after: true);
          }
        }
      case 'duplicate':
        if (isSelected) {
          duplicateSelectedBlocks();
        } else {
          duplicateCurrentBlock();
        }
      case 'copy':
        if (hasMultiBlockSelection && isBlockSelected(block)) {
          copySelectedBlocks();
        } else {
          if (!await _writeClipboard(
            portableClipboardMarkdown(
              block.source,
              widget.resolveClipboardImage,
            ),
          )) {
            return;
          }
          if (mounted) {
            ScaffoldMessenger.maybeOf(this.context)?.showSnackBar(
              const SnackBar(
                content: Text('Markdown copied to clipboard'),
                duration: Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      case 'copy_link':
        await widget.onCopyBlockReference?.call(
          _positions.offsetOf(_positions.indexOf(block)) + block.prefix.length,
        );
      case 'turn_into':
        if (context.mounted) _showTurnIntoMenu(context, block);
      case 'create_task':
        _createTaskFromBlock(block);
      case 'delete':
        if (hasMultiBlockSelection && isBlockSelected(block)) {
          deleteSelectedBlocks();
        } else {
          _replace(block, '', structural: true, focusOffset: 0);
        }
    }
  }

  Future<void> _showAddBelowMenu(
    BuildContext context,
    MarkdownBlock block,
  ) async {
    final originalSource = _positions.source, originalNote = widget.noteId;
    final box =
        anchors[block]?.currentContext?.findRenderObject() as RenderBox?;
    final point = box != null ? box.localToGlobal(Offset.zero) : Offset.zero;

    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        point.dx + 24,
        point.dy + 28,
        point.dx + 220,
        0,
      ),
      items: const [
        PopupMenuItem(value: 'Text', child: Text('Text')),
        PopupMenuItem(value: 'Heading 1', child: Text('Heading 1')),
        PopupMenuItem(value: 'Heading 2', child: Text('Heading 2')),
        PopupMenuItem(value: 'Heading 3', child: Text('Heading 3')),
        PopupMenuItem(value: 'Bullet list', child: Text('Bullet list')),
        PopupMenuItem(value: 'Numbered list', child: Text('Numbered list')),
        PopupMenuItem(value: 'Checklist', child: Text('Checklist')),
        PopupMenuItem(value: 'Quote', child: Text('Quote')),
        PopupMenuItem(value: 'Callout', child: Text('Callout')),
        PopupMenuItem(value: 'Definition', child: Text('Definition')),
        PopupMenuItem(value: 'Theorem', child: Text('Theorem')),
        PopupMenuItem(value: 'Proof', child: Text('Proof')),
        PopupMenuItem(value: 'Example', child: Text('Example')),
        PopupMenuItem(value: 'Question', child: Text('Question')),
        PopupMenuItem(value: 'Code block', child: Text('Code block')),
        PopupMenuItem(value: 'Table', child: Text('Table')),
        PopupMenuItem(value: 'Inline equation', child: Text('Inline equation')),
        PopupMenuItem(value: 'Block equation', child: Text('Block equation')),
        PopupMenuItem(value: 'Matrix', child: Text('Matrix')),
        PopupMenuItem(value: 'Cases', child: Text('Cases')),
        PopupMenuItem(value: 'Horizontal rule', child: Text('Divider')),
      ],
    );
    if (choice == null ||
        !mounted ||
        !document.blocks.contains(block) ||
        _positions.source != originalSource ||
        widget.noteId != originalNote) {
      return;
    }
    _insertBlockBelow(block, choice);
  }

  void _insertBlockBelow(MarkdownBlock block, String type) {
    if (!document.blocks.contains(block)) return;
    final eol = block.source.contains('\r\n') ? '\r\n' : '\n';
    final syntax = switch (type) {
      'Text' => '',
      'Heading 1' => '# ',
      'Heading 2' => '## ',
      'Heading 3' => '### ',
      'Bullet list' => '- ',
      'Numbered list' => '1. ',
      'Checklist' => '- [ ] ',
      'Quote' => '> ',
      'Callout' => '> [!NOTE]$eol> A useful observation.',
      'Definition' => '> [!DEFINITION]$eol> A definition statement.',
      'Theorem' => '> [!THEOREM]$eol> A theorem statement.',
      'Proof' => '> [!PROOF]$eol> Proof of the statement.',
      'Example' => '> [!EXAMPLE]$eol> An example.',
      'Question' => '> [!QUESTION]$eol> A question or unclear item.',
      'Code block' => '```text${eol}code$eol```',
      'Table' =>
        '| Column 1 | Column 2 |$eol| --- | --- |$eol| Value 1 | Value 2 |',
      'Inline equation' => r'$x^2$',
      'Block equation' => '\$\$$eol\\frac{a}{b}$eol\$\$',
      'Matrix' =>
        '\$\$$eol\\begin{pmatrix}$eol 1 & 0 \\\\$eol 0 & 1$eol\\end{pmatrix}$eol\$\$',
      'Cases' =>
        '\$\$$eol\\begin{cases}$eol \\square & \\text{if } \\square \\\\$eol \\square & \\text{if } \\square$eol\\end{cases}$eol\$\$',
      'Horizontal rule' => '---',
      _ => '',
    };

    final isList =
        type == 'Bullet list' || type == 'Numbered list' || type == 'Checklist';
    final bothLists = block.kind == MarkdownBlockKind.list && isList;
    final bothQuotes = block.kind == MarkdownBlockKind.quote && type == 'Quote';
    _applyBoundaryEdit(
      MarkdownBlockEditing.insertAfter(
        document,
        _positions.indexOf(block),
        syntax,
        sibling: bothLists || bothQuotes,
      ),
    );
  }

  Widget _buildDropIndicator(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Container(
        height: 2.5,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
              blurRadius: 4,
              spreadRadius: 0.5,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragFeedback(
    BuildContext context,
    MarkdownBlock block,
    List<MarkdownBlock> blocks,
  ) {
    final theme = Theme.of(context);
    final count = blocks.length;
    final firstBlock = blocks.firstWhere(
      (b) => b.kind != MarkdownBlockKind.blank,
      orElse: () => block,
    );
    final preview = firstBlock.content.trim().isEmpty
        ? (firstBlock.kind == MarkdownBlockKind.code
              ? 'Code block'
              : firstBlock.kind == MarkdownBlockKind.table
              ? 'Table'
              : firstBlock.kind == MarkdownBlockKind.math
              ? 'Equation'
              : 'Empty block')
        : firstBlock.content.trim().split('\n').first;

    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (count > 1)
            Positioned(
              left: 4,
              top: 4,
              right: -4,
              bottom: -4,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.7,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
              ),
            ),
          Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh.withValues(
                alpha: 0.95,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.8),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.drag_indicator,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (count > 1) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockHandleRow(BuildContext context, MarkdownBlock block) {
    final theme = Theme.of(context);
    final isSelected = hasMultiBlockSelection && isBlockSelected(block);
    final dragData = isSelected ? selectedBlocks : [block];
    return Padding(
      padding: const EdgeInsets.only(top: 2, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 24,
            child: IconButton(
              tooltip: 'Add block below',
              padding: EdgeInsets.zero,
              iconSize: 15,
              icon: Icon(
                Icons.add,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              hoverColor: theme.colorScheme.primary.withValues(alpha: 0.12),
              onPressed: () => _showAddBelowMenu(context, block),
            ),
          ),
          SizedBox(
            width: 22,
            height: 24,
            child: Draggable<List<MarkdownBlock>>(
              key: ValueKey('block-drag-${_positions.indexOf(block)}'),
              data: dragData,
              onDragStarted: () => setState(() {
                _draggingBlock = block;
                _draggingBlocks = dragData;
              }),
              onDragEnd: (_) => setState(() {
                _draggingBlock = null;
                _draggingBlocks = null;
                _dropTargetBlock = null;
              }),
              onDraggableCanceled: (_, _) => setState(() {
                _draggingBlock = null;
                _draggingBlocks = null;
                _dropTargetBlock = null;
              }),
              feedback: _buildDragFeedback(context, block, dragData),
              childWhenDragging: const SizedBox.shrink(),
              child: Tooltip(
                message: isSelected
                    ? 'Drag ${selectedBlocks.length} blocks · Click for options'
                    : 'Drag to move · Click for options',
                waitDuration: const Duration(milliseconds: 500),
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  mouseCursor: SystemMouseCursors.grab,
                  onTap: () => _showBlockContextMenu(context, block),
                  child: Center(
                    child: Icon(
                      Icons.drag_indicator,
                      size: 16,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (block.kind == MarkdownBlockKind.heading) ...[
            SizedBox(
              width: 22,
              height: 24,
              child: IconButton(
                tooltip: _collapsedHeadings.contains(_headingKey(block))
                    ? 'Expand section'
                    : 'Collapse section',
                padding: EdgeInsets.zero,
                iconSize: 16,
                icon: Icon(
                  _collapsedHeadings.contains(_headingKey(block))
                      ? Icons.chevron_right
                      : Icons.keyboard_arrow_down,
                  color: theme.colorScheme.primary,
                ),
                onPressed: () {
                  setState(() {
                    final key = _headingKey(block);
                    if (_collapsedHeadings.contains(key)) {
                      _collapsedHeadings.remove(key);
                    } else {
                      _collapsedHeadings.add(key);
                    }
                  });
                  record();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _headingKey(MarkdownBlock block) {
    return _headingIds.putIfAbsent(block, () {
      String id;
      do {
        id = 'heading-${_nextHeadingId++}';
      } while (_headingIds.containsValue(id) ||
          _collapsedHeadings.contains(id));
      return id;
    });
  }

  RenderEditable? _editableFor(MarkdownBlock block) {
    final context = anchors[block]?.currentContext;
    if (context == null) return null;
    RenderEditable? result;
    void visit(RenderObject object) {
      if (result != null) return;
      if (object is RenderEditable) {
        result = object;
        return;
      }
      object.visitChildren(visit);
    }

    final render = context.findRenderObject();
    if (render != null) visit(render);
    return result;
  }

  int? _sourceOffsetAtGlobal(Offset global) {
    for (var i = 0; i < _visibleBlocks.length; i++) {
      final block = _visibleBlocks[i];
      final render = anchors[block]?.currentContext?.findRenderObject();
      if (render is! RenderBox || !render.attached || !render.hasSize) continue;
      final topLeft = render.localToGlobal(Offset.zero);
      final rect = topLeft & render.size;
      if (!rect.contains(global)) continue;
      final columns = NoteColumns.parse(block.source);
      if (columns != null) {
        for (var column = 0; column < columns.parts.length; column++) {
          final nested = _columnKeys[(block, column)]?.currentState;
          final local = nested?._sourceOffsetAtGlobal(global);
          if (local != null) {
            return _positions.offsetOf(_positions.indexOf(block)) +
                columns.offsets[column] +
                local;
          }
        }
      }
      final editable = _editableFor(block);
      final blockOffset = _positions.offsetOf(_positions.indexOf(block));
      if (editable == null) return blockOffset + block.source.length;
      final position = editable
          .getPositionForPoint(editable.globalToLocal(global))
          .offset
          .clamp(0, editable.text?.toPlainText().length ?? block.content.length)
          .toInt();
      final raw = block.kind == MarkdownBlockKind.raw
          ? position
          : InlineProjection(
              block.content,
              referenceDefinitions: document.referenceDefinitions,
            ).sourceOffset(position);
      return (blockOffset + block.prefix.length + raw).clamp(
        0,
        _positions.source.length,
      );
    }
    return null;
  }

  void _beginPointerSelection(MarkdownBlock block, PointerDownEvent event) {
    final offset = _sourceOffsetAtGlobal(event.position);
    _dragSelectionAnchor =
        offset ?? _positions.offsetOf(_positions.indexOf(block));
    _dragSelecting = true;
    if (!HardwareKeyboard.instance.isShiftPressed) {
      _crossDocumentSelection = null;
    }
  }

  void _continuePointerSelection(PointerMoveEvent event) {
    if (!_dragSelecting || _dragSelectionAnchor == null) return;
    final offset = _sourceOffsetAtGlobal(event.position);
    if (offset == null || offset == _dragSelectionAnchor) return;
    // Native text/cell selection owns gestures inside one block. Replacing its
    // subtree with document-selection chrome mid-drag destroys the editor state.
    if (_positions.blockAt(offset) ==
        _positions.blockAt(_dragSelectionAnchor!)) {
      if (_crossDocumentSelection != null) {
        setState(() => _crossDocumentSelection = null);
      }
      return;
    }
    setState(() {
      _crossDocumentSelection = TextSelection(
        baseOffset: _dragSelectionAnchor!,
        extentOffset: offset,
      );
      _selectedBlockStart = null;
      _selectedBlockEnd = null;
    });
  }

  void _endPointerSelection([PointerEvent? _]) {
    _dragSelecting = false;
  }

  void _insertPdfQuote(PdfQuoteDragData quote) {
    final text = quote.markdownQuote.trim();
    if (document.blocks.isNotEmpty) {
      final last = document.blocks.last;
      _replace(
        last,
        '${last.source.trimRight()}\n\n$text\n\n',
        structural: true,
      );
    } else {
      widget.onChanged('$text\n\n');
    }
  }

  Widget _buildBlockEntry(BuildContext context, MarkdownBlock block) {
    return Container(
      key: anchors.putIfAbsent(block, () => GlobalKey()),
      child: () {
        final isFrontmatter =
            _positions.indexOf(block) == 0 &&
            block.kind == MarkdownBlockKind.raw &&
            block.source.startsWith('---');
        final isBlank = block.kind == MarkdownBlockKind.blank;
        final blockContent = cache.putIfAbsent(block, () => blockView(block));

        final isSelected = isBlockSelected(block);
        final crossSelection = _crossDocumentSelection;
        final blockStart = _positions.offsetOf(_positions.indexOf(block));
        final blockEnd = blockStart + block.source.length;
        final isCrossSelected =
            crossSelection != null &&
            crossSelection.start < blockEnd &&
            crossSelection.end > blockStart;
        final selectedContent = isSelected || isCrossSelected
            ? Container(
                key: ValueKey(
                  isSelected
                      ? 'selected-block-${_positions.indexOf(block)}'
                      : 'cross-selected-block-${_positions.indexOf(block)}',
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: blockContent,
              )
            : blockContent;
        // Prose clicks enter text editing. Handles must
        // retain the range they operate on or drag.
        final wrappedContent = Listener(
          onPointerDown: (event) {
            _beginPointerSelection(block, event);
            _focusRequest++;
            final index = _positions.indexOf(block);
            if (HardwareKeyboard.instance.isShiftPressed) {
              final anchor = _selectedBlockStart ?? active;
              selectBlockRange(anchor, index);
            } else {
              if (hasMultiBlockSelection &&
                  block.kind != MarkdownBlockKind.image) {
                clearBlockSelection();
              }
              active = index;
              record();
            }
          },
          onPointerMove: _continuePointerSelection,
          onPointerUp: _endPointerSelection,
          onPointerCancel: _endPointerSelection,
          child: selectedContent,
        );

        if (isBlank || isFrontmatter) {
          return wrappedContent;
        }

        return DragTarget<List<MarkdownBlock>>(
          key: ValueKey('block-drop-${_positions.indexOf(block)}'),
          onWillAcceptWithDetails: (details) => !details.data.contains(block),
          onMove: (details) {
            final box =
                anchors[block]?.currentContext?.findRenderObject()
                    as RenderBox?;
            if (box != null) {
              final local = box.globalToLocal(details.offset);
              final isTop = local.dy < (box.size.height / 2);
              if (_dropTargetBlock != block || _dropOnTop != isTop) {
                setState(() {
                  _dropTargetBlock = block;
                  _dropOnTop = isTop;
                });
                record();
              }
            }
          },
          onLeave: (_) {
            if (_dropTargetBlock == block) {
              setState(() {
                _dropTargetBlock = null;
              });
            }
          },
          onAcceptWithDetails: (details) {
            final sourceBlocks = details.data;
            final after = !_dropOnTop;
            setState(() {
              _dropTargetBlock = null;
              _draggingBlock = null;
              _draggingBlocks = null;
            });
            _moveBlocks(sourceBlocks, block, after: after);
          },
          builder: (context, candidateData, rejectedData) {
            final showTopIndicator = _dropTargetBlock == block && _dropOnTop;
            final showBottomIndicator =
                _dropTargetBlock == block && !_dropOnTop;
            final isBeingDragged =
                _draggingBlocks?.contains(block) ?? (_draggingBlock == block);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showTopIndicator) _buildDropIndicator(context),
                Opacity(
                  opacity: isBeingDragged ? 0.35 : 1.0,
                  child: HoverChrome(
                    content: wrappedContent,
                    child: _buildBlockHandleRow(context, block),
                  ),
                ),
                if (showBottomIndicator) _buildDropIndicator(context),
              ],
            );
          },
        );
      }(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hiddenBlocks = <MarkdownBlock>{};
    int? collapsedLevel;
    for (int i = 0; i < document.blocks.length; i++) {
      final b = document.blocks[i];
      if (b.kind == MarkdownBlockKind.heading) {
        if (collapsedLevel != null && b.level <= collapsedLevel) {
          collapsedLevel = null;
        }
        final key = _headingKey(b);
        if (_collapsedHeadings.contains(key)) {
          collapsedLevel = b.level;
          continue;
        }
      }
      if (collapsedLevel != null) {
        hiddenBlocks.add(b);
      }
    }
    final visibleBlocks = document.blocks
        .where(
          (block) =>
              !hiddenBlocks.contains(block) &&
              (widget.focusedStart == null ||
                  _positions.offsetOf(_positions.indexOf(block)) >=
                          widget.focusedStart! &&
                      _positions.offsetOf(_positions.indexOf(block)) <
                          (widget.focusedEnd ?? _positions.source.length)) &&
              ReviewAnnotation.parse(block.source) == null &&
              !DocumentCitations.metadataLine(block.source),
        )
        .toList(growable: false);
    _visibleBlocks = visibleBlocks;

    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final block in visibleBlocks) _buildBlockEntry(context, block),
        ],
      );
    }

    return Focus(
      focusNode: _editorFocusNode,
      autofocus: false,
      child: DragTarget<PdfQuoteDragData>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (details) => _insertPdfQuote(details.data),
        builder: (context, candidateData, rejectedData) {
          final isDropHover = candidateData.isNotEmpty;
          return Container(
            decoration: isDropHover
                ? BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  )
                : null,
            child: Scrollbar(
              controller: scroll,
              child: document.blocks.length > _virtualizationThreshold
                  ? ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(28, 8, 28, 80),
                      itemCount: visibleBlocks.length + 1,
                      findChildIndexCallback: (key) {
                        if (key is! ObjectKey || key.value is! MarkdownBlock) {
                          return null;
                        }
                        final index = visibleBlocks.indexOf(
                          key.value as MarkdownBlock,
                        );
                        return index < 0 ? null : index;
                      },
                      itemBuilder: (context, index) {
                        if (index == visibleBlocks.length) {
                          return Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: widget.contentWidth,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: HoverChrome(
                                  child: TextButton.icon(
                                    onPressed: () {
                                      final last = document.blocks.last;
                                      _replace(
                                        last,
                                        '${last.source}${last.source.endsWith('\n') ? '\n' : '\n\n'}',
                                        structural: true,
                                        focusOffset: last.source.length + 2,
                                      );
                                    },
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('New paragraph'),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return Center(
                          key: ObjectKey(visibleBlocks[index]),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: widget.contentWidth,
                            ),
                            child: _buildBlockEntry(
                              context,
                              visibleBlocks[index],
                            ),
                          ),
                        );
                      },
                    )
                  : SingleChildScrollView(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(28, 8, 28, 80),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: widget.contentWidth,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final block in visibleBlocks)
                                _buildBlockEntry(context, block),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: HoverChrome(
                                  child: TextButton.icon(
                                    onPressed: () {
                                      final last = document.blocks.last;
                                      _replace(
                                        last,
                                        '${last.source}${last.source.endsWith('\n') ? '\n' : '\n\n'}',
                                        structural: true,
                                        focusOffset: last.source.length + 2,
                                      );
                                    },
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('New paragraph'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _StyledController extends TextEditingController {
  void refreshStyle() => notifyListeners();
  _StyledController(
    String source, {
    this.raw = false,
    this.grammarEngine,
    this.spellCheckEnabled = true,
    this.referenceDefinitions = const {},
  }) : projection = InlineProjection(
         source,
         referenceDefinitions: referenceDefinitions,
       ),
       super(
         text: raw
             ? source
             : InlineProjection(
                 source,
                 referenceDefinitions: referenceDefinitions,
               ).text,
       );

  InlineProjection projection;
  final bool raw;
  EnglishSpellGrammarEngine? grammarEngine;
  bool spellCheckEnabled;
  Map<String, String> referenceDefinitions;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (!value.composing.isCollapsed) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final issues = (spellCheckEnabled && grammarEngine != null)
        ? grammarEngine!.analyze(text)
        : const <TextIssue>[];

    final issueCursor = TextIssueCursor(issues);

    if (raw || projection.text != text) {
      if (issues.isEmpty) {
        return super.buildTextSpan(
          context: context,
          style: style,
          withComposing: withComposing,
        );
      }
      final spans = <TextSpan>[];
      var start = 0;
      while (start < text.length) {
        final currentIssue = issueCursor.at(start);
        var end = start + 1;
        while (end < text.length && issueCursor.at(end) == currentIssue) {
          end++;
        }
        spans.add(
          TextSpan(
            text: text.substring(start, end),
            style: currentIssue == null
                ? null
                : TextStyle(
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.wavy,
                    decorationColor: currentIssue.type == IssueType.spelling
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF3B82F6),
                  ),
          ),
        );
        start = end;
      }
      return TextSpan(style: style, children: spans);
    }

    final spans = <TextSpan>[];
    var start = 0;
    while (start < text.length) {
      final marks = projection.styles[start];
      final currentIssue = issueCursor.at(start);
      var end = start + 1;
      while (end < text.length &&
          setEquals(projection.styles[end], marks) &&
          issueCursor.at(end) == currentIssue) {
        end++;
      }
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final isCode = marks.contains('code');
      final effectiveIssue = isCode ? null : currentIssue;

      spans.add(
        TextSpan(
          text: text.substring(start, end),
          style: TextStyle(
            fontWeight: marks.contains('bold') || marks.contains('footnote')
                ? FontWeight.bold
                : null,
            fontStyle: marks.contains('italic') ? FontStyle.italic : null,
            fontFamily: isCode ? 'monospace' : style?.fontFamily,
            fontSize: marks.contains('footnote') ? 11 : null,
            decoration: () {
              final decorations = <TextDecoration>[];
              if (marks.contains('strike')) {
                decorations.add(TextDecoration.lineThrough);
              }
              if (marks.contains('link') ||
                  marks.contains('underline') ||
                  effectiveIssue != null) {
                decorations.add(TextDecoration.underline);
              }
              if (decorations.isEmpty) return null;
              if (decorations.length == 1) return decorations.first;
              return TextDecoration.combine(decorations);
            }(),
            decorationStyle: effectiveIssue != null
                ? TextDecorationStyle.wavy
                : null,
            decorationColor: effectiveIssue != null
                ? (effectiveIssue.type == IssueType.spelling
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF3B82F6))
                : null,
            color: marks.contains('footnote') || marks.contains('link')
                ? Theme.of(context).colorScheme.primary
                : marks.contains('highlight')
                ? (isDark ? const Color(0xFFFDE047) : const Color(0xFF713F12))
                : null,
            backgroundColor: marks.contains('highlight')
                ? (isDark
                      ? const Color(0xFFEAB308).withValues(alpha: 0.35)
                      : const Color(0xFFFEF08A))
                : null,
          ),
        ),
      );
      start = end;
    }
    return TextSpan(style: style, children: spans);
  }
}

class _RichImageBlock extends StatefulWidget {
  const _RichImageBlock({
    required this.imageUri,
    required this.altText,
    required this.onOpen,
    required this.onRemove,
    required this.onAddText,
    required this.onSelect,
    required this.onCopy,
    required this.onCut,
    this.imageBuilder,
  });

  final String imageUri;
  final String altText;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  final VoidCallback onAddText;
  final VoidCallback onSelect;
  final Future<void> Function() onCopy, onCut;
  final Widget Function(BuildContext, String)? imageBuilder;

  @override
  State<_RichImageBlock> createState() => _RichImageBlockState();
}

class _RichImageBlockState extends State<_RichImageBlock> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final imageWidget =
        widget.imageBuilder?.call(context, widget.imageUri) ??
        const Icon(Icons.image_outlined, size: 48);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onSelect,
        onSecondaryTapUp: (details) async {
          final res = await showMenu<String>(
            context: context,
            position: RelativeRect.fromLTRB(
              details.globalPosition.dx,
              details.globalPosition.dy,
              details.globalPosition.dx,
              details.globalPosition.dy,
            ),
            items: const [
              PopupMenuItem(
                value: 'text',
                child: Text('Add text beside image'),
              ),
              PopupMenuItem(
                value: 'open',
                child: Row(
                  children: [
                    Icon(Icons.open_in_new, size: 16),
                    SizedBox(width: 8),
                    Text('Open original'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.copy, size: 16),
                    SizedBox(width: 8),
                    Text('Copy image'),
                  ],
                ),
              ),
              PopupMenuItem(value: 'cut', child: Text('Cut image')),
              PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 16),
                    SizedBox(width: 8),
                    Text('Remove embed'),
                  ],
                ),
              ),
            ],
          );
          if (res == 'open') {
            widget.onOpen();
          } else if (res == 'text') {
            widget.onAddText();
          } else if (res == 'copy') {
            await widget.onCopy();
          } else if (res == 'cut') {
            await widget.onCut();
          } else if (res == 'remove') {
            widget.onRemove();
          }
        },
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageWidget,
            ),
            AnimatedOpacity(
              duration: OrbitMotionScope.duration(context, OrbitMotion.micro),
              opacity: _hovered ? 1.0 : 0.0,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.floating.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.border),
                    boxShadow: OrbitDepth.floating,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Add text beside image',
                        icon: const Icon(Icons.view_sidebar_outlined, size: 15),
                        onPressed: widget.onAddText,
                      ),
                      IconButton(
                        tooltip: 'Open original',
                        icon: const Icon(Icons.open_in_new, size: 15),
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onOpen,
                      ),
                      IconButton(
                        tooltip: 'Remove embed',
                        icon: const Icon(Icons.close, size: 15),
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onRemove,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RichTextBlock extends StatefulWidget {
  const _RichTextBlock({
    super.key,
    required this.source,
    required this.onChanged,
    required this.style,
    required this.onUndo,
    required this.onRedo,
    this.raw = false,
    this.lineEnding = '\n',
    this.textAlign = TextAlign.left,
    this.initialCaret = 0,
    this.initialBase,
    this.hintText = 'Write something, or / for commands',
    this.linkTargets = const [],
    this.linkBindings = const {},
    this.referenceDefinitions = const {},
    this.allObjects = const [],
    this.onOpenLink,
    this.onOpenFootnote,
    this.initialMarks = const {},
    this.onOpenInNewTab,
    this.onOpenToSide,
    this.onShowBacklinks,
    this.onRevealInExplorer,
    this.onFocus,
    this.onEnter,
    this.onJoinPrevious,
    this.onJoinNext,
    this.onIndent,
    this.onPasteImage,
    this.onSelectAllDocument,
    this.onExtendSelectionDown,
    this.onExtendSelectionUp,
    this.onMoveUp,
    this.onMoveDown,
    this.onDuplicate,
    this.hasDocumentSelection,
    this.onReplaceDocumentSelection,
    this.onCopyDocumentSelection,
    this.onCutDocumentSelection,
    this.onDeleteDocumentSelection,
    this.grammarEngine,
    this.spellCheckEnabled = true,
    this.onAddToDictionary,
    this.onIgnore,
  });
  final String source;
  final bool raw;
  final String lineEnding;
  final TextAlign textAlign;
  final int initialCaret;
  final int? initialBase;
  final String hintText;
  final TextStyle style;
  final List<NoteLinkTarget> linkTargets;
  final Map<String, String> linkBindings;
  final Map<String, String> referenceDefinitions;
  final List<UniversalObject> allObjects;
  final ValueChanged<String>? onOpenLink;
  final ValueChanged<String>? onOpenInNewTab;
  final ValueChanged<String>? onOpenToSide;
  final ValueChanged<String>? onShowBacklinks;
  final ValueChanged<String>? onRevealInExplorer;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onOpenFootnote;
  final Map<String, (String, bool)> initialMarks;
  final ValueChanged<TextSelection>? onFocus;
  final ValueChanged<TextEditingValue>? onEnter;
  final bool Function()? onJoinPrevious;
  final bool Function()? onJoinNext;
  final ValueChanged<bool>? onIndent;
  final VoidCallback onUndo, onRedo;
  final VoidCallback? onPasteImage;
  final VoidCallback? onSelectAllDocument;
  final VoidCallback? onExtendSelectionDown;
  final VoidCallback? onExtendSelectionUp;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onDuplicate;
  final bool Function()? hasDocumentSelection;
  final bool Function(String)? onReplaceDocumentSelection;
  final Future<void> Function()? onCopyDocumentSelection;
  final Future<void> Function()? onCutDocumentSelection;
  final bool Function()? onDeleteDocumentSelection;
  final EnglishSpellGrammarEngine? grammarEngine;
  final bool spellCheckEnabled;
  final ValueChanged<String>? onAddToDictionary;
  final ValueChanged<String>? onIgnore;
  @override
  State<_RichTextBlock> createState() => _RichTextBlockState();
}

class _RichTextBlockState extends State<_RichTextBlock> {
  Map<NoteFormatAction, String> get formatStates {
    final p = controller.projection, sel = controller.selection;
    if (!sel.isValid) return const {};
    final styles = sel.isCollapsed
        ? (p.styles.isEmpty
              ? <Set<String>>[]
              : [
                  p.styles[(sel.start > 0 ? sel.start - 1 : 0).clamp(
                    0,
                    p.styles.length - 1,
                  )],
                ])
        : p.styles.skip(sel.start).take(sel.end - sel.start).toList();
    final result = <NoteFormatAction, String>{};
    for (final e in [
      (NoteFormatAction.bold, '**', 'bold'),
      (NoteFormatAction.italic, '*', 'italic'),
      (NoteFormatAction.highlight, '==', 'highlight'),
      (NoteFormatAction.underline, '<u>', 'underline'),
      (NoteFormatAction.strike, '~~', 'strike'),
    ]) {
      final pending = _pendingMarks[e.$2];
      result[e.$1] = pending != null
          ? (pending.$2 ? 'on' : 'off')
          : styles.isNotEmpty && styles.every((s) => s.contains(e.$3))
          ? 'on'
          : styles.any((s) => s.contains(e.$3))
          ? 'mixed'
          : 'off';
    }
    return result;
  }

  bool _outsideFormatting = false;
  final Map<String, (String, bool)> _pendingMarks = {};
  bool _applyingEdit = false;
  int _editRevision = 0, _pasteRequest = 0;
  ProjectedLink? _hoveredLink;
  Timer? _peekTimer;
  Timer? _dismissTimer;
  OverlayEntry? _peekOverlayEntry;
  late final _StyledController controller = _StyledController(
    widget.source,
    raw: widget.raw,
    grammarEngine: widget.grammarEngine,
    spellCheckEnabled: widget.spellCheckEnabled,
    referenceDefinitions: widget.referenceDefinitions,
  );
  late final FocusNode focus = FocusNode(onKeyEvent: keyEvent);
  late String source = widget.source;
  TextSelection _beforeSelection = const TextSelection.collapsed(offset: 0);
  @override
  void initState() {
    super.initState();
    controller.selection = TextSelection(
      baseOffset: (widget.initialBase ?? widget.initialCaret).clamp(
        0,
        controller.text.length,
      ),
      extentOffset: widget.initialCaret.clamp(0, controller.text.length),
    );
    controller.addListener(selection);
    focus.addListener(selection);
    _pendingMarks.addAll(widget.initialMarks);
  }

  void selection() {
    if (controller.text == (widget.raw ? source : controller.projection.text)) {
      if (!_applyingEdit && controller.selection != _beforeSelection) {
        _pendingMarks.clear();
      }
      _beforeSelection = controller.selection;
    }
    if (focus.hasFocus) {
      if (controller.selection.isValid) {
        widget.onFocus?.call(controller.selection);
      }
    }
  }

  @override
  void didUpdateWidget(_RichTextBlock old) {
    super.didUpdateWidget(old);
    if (widget.source != source) {
      _editRevision++;
      source = widget.source;
      _pendingMarks.clear();
      _sync();
    }
    if (widget.initialMarks.isNotEmpty &&
        !mapEquals(old.initialMarks, widget.initialMarks)) {
      _pendingMarks.addAll(widget.initialMarks);
    }
    if (old.grammarEngine != widget.grammarEngine ||
        old.spellCheckEnabled != widget.spellCheckEnabled ||
        !mapEquals(old.referenceDefinitions, widget.referenceDefinitions)) {
      controller.grammarEngine = widget.grammarEngine;
      controller.spellCheckEnabled = widget.spellCheckEnabled;
      controller.referenceDefinitions = widget.referenceDefinitions;
      _sync();
      controller.refreshStyle();
    }
  }

  void _sync({int? caret}) {
    controller.projection = InlineProjection(
      source,
      referenceDefinitions: widget.referenceDefinitions,
    );
    final next = widget.raw ? source : controller.projection.text;
    if (controller.text != next) {
      controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(
          offset: (caret ?? controller.selection.extentOffset).clamp(
            0,
            next.length,
          ),
        ),
      );
    } else {
      controller.refreshStyle();
    }
  }

  void focusAt(int offset, {int? extent}) {
    controller.selection = TextSelection(
      baseOffset: offset.clamp(0, controller.text.length),
      extentOffset: (extent ?? offset).clamp(0, controller.text.length),
    );
    focus.requestFocus();
  }

  void insert(String markdown) {
    if (!mounted) return;
    _editRevision++;
    _pendingMarks.clear();
    final p = controller.projection;
    final sel = controller.selection.isValid
        ? controller.selection
        : TextSelection.collapsed(offset: controller.text.length);
    if (markdown.startsWith('[[') &&
        markdown.endsWith(']]') &&
        !sel.isCollapsed) {
      final target = markdown.substring(2, markdown.length - 2);
      if (!target.contains('|')) {
        markdown =
            '[[$target|${controller.text.substring(sel.start, sel.end)}]]';
      }
    }
    final left = widget.raw
        ? source.substring(0, sel.start)
        : p.fragment(0, sel.start);
    final right = widget.raw
        ? source.substring(sel.end)
        : p.fragment(sel.end, p.text.length);
    source = '$left$markdown$right';
    controller.projection = InlineProjection(
      source,
      referenceDefinitions: widget.referenceDefinitions,
    );
    final caret = widget.raw
        ? left.length + markdown.length
        : InlineProjection(
                left,
                referenceDefinitions: widget.referenceDefinitions,
              ).text.length +
              InlineProjection(
                markdown,
                referenceDefinitions: widget.referenceDefinitions,
              ).text.length;
    _sync(caret: caret);
    focusAt(caret);
    widget.onChanged(source);
  }

  void wrap(String tag, {String? closing}) {
    _editRevision++;
    final closeTag = closing ?? tag;
    final p = controller.projection;
    final sel = controller.selection.isValid
        ? controller.selection
        : TextSelection.collapsed(offset: controller.text.length);
    if (sel.isCollapsed) {
      // Keep typing style transient until there is text to serialize.
      if (_pendingMarks.containsKey(tag)) {
        _pendingMarks.remove(tag);
      } else {
        final mark = switch (tag) {
          '**' => 'bold',
          '*' => 'italic',
          '~~' => 'strike',
          '==' => 'highlight',
          '<u>' => 'underline',
          '`' => 'code',
          _ => '',
        };
        final pos = sel.start > 0 ? sel.start - 1 : sel.start;
        final enabled =
            p.styles.isNotEmpty &&
            p.styles[pos.clamp(0, p.styles.length - 1)].contains(mark);
        _pendingMarks[tag] = (closeTag, !enabled);
      }
      focus.requestFocus();
      return;
    }
    final next = p.formatRange(sel.start, sel.end, tag, closeTag);
    if (next == source) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Try formatting a smaller selection, or use Source for this combination.',
          ),
        ),
      );
      focus.requestFocus();
      return;
    }
    source = next;
    _sync();
    controller.selection = sel;
    focus.requestFocus();
    widget.onChanged(source);
  }

  void _applyFix(TextIssue issue, String replacement) {
    _editRevision++;
    final original = controller.text;
    if (issue.start < 0 ||
        issue.end > original.length ||
        !controller.value.composing.isCollapsed ||
        original.substring(issue.start, issue.end) != issue.originalText) {
      return;
    }
    final newText = original.replaceRange(issue.start, issue.end, replacement);
    final newOffset = issue.start + replacement.length;
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    source = widget.raw
        ? newText
        : controller.projection.edit(
            newText,
            selectionStart: issue.start,
            selectionEnd: issue.end,
            outsideFormatting: false,
          );
    controller.projection = InlineProjection(
      source,
      referenceDefinitions: widget.referenceDefinitions,
    );
    widget.onChanged(source);
    controller.refreshStyle();
  }

  Future<void> _paste({bool plain = false}) async {
    final value = controller.value, before = source;
    if (!value.composing.isCollapsed) return;
    final revision = _editRevision, request = ++_pasteRequest;
    ClipboardData? data;
    try {
      final pasted = await readMarkdownClipboard(preferHtml: !plain);
      data = pasted == null ? null : ClipboardData(text: pasted);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(
              'Could not access the clipboard. Your note is unchanged.',
            ),
          ),
        );
      }
      return;
    }
    if (!mounted ||
        !focus.hasFocus ||
        controller.value != value ||
        source != before ||
        revision != _editRevision ||
        request != _pasteRequest) {
      return;
    }
    final text = data?.text ?? '';
    final sel = value.selection;
    final isUrl =
        !plain &&
        !widget.raw &&
        sel.isValid &&
        !sel.isCollapsed &&
        !text.contains(RegExp(r'\s')) &&
        Uri.tryParse(text)?.hasScheme == true &&
        (text.startsWith('http://') || text.startsWith('https://'));
    if (isUrl) {
      insert('[${controller.text.substring(sel.start, sel.end)}]($text)');
    } else if (text.isNotEmpty) {
      final pasted = widget.raw
          ? text
          : text.replaceAll(RegExp(r'\r\n|[\r\n]'), widget.lineEnding);
      final range = sel.isValid
          ? sel
          : TextSelection.collapsed(offset: controller.text.length);
      controller.value = TextEditingValue(
        text: controller.text.replaceRange(range.start, range.end, pasted),
        selection: TextSelection.collapsed(offset: range.start + pasted.length),
      );
      // Use the typing path so inherited/pending marks and deliberate formatting
      // exits behave identically for typing and paste.
      _changed(controller.text);
    } else {
      widget.onPasteImage?.call();
    }
  }

  Widget _buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final engine = widget.grammarEngine;
    final enabled = widget.spellCheckEnabled;
    final items = <ContextMenuButtonItem>[];

    if (enabled && engine != null) {
      final value = editableTextState.textEditingValue;
      final sel = value.selection;
      final pos = sel.isCollapsed ? sel.baseOffset : sel.start;
      final issues = engine.analyze(controller.text);

      TextIssue? activeIssue;
      for (final issue in issues) {
        if (sel.isCollapsed) {
          if (pos >= issue.start && pos < issue.end) {
            activeIssue = issue;
            break;
          }
        } else {
          if (sel.start < issue.end && sel.end > issue.start) {
            activeIssue = issue;
            break;
          }
        }
      }

      if (activeIssue != null) {
        for (final suggestion in activeIssue.suggestions) {
          items.add(
            ContextMenuButtonItem(
              label: 'Replace with: "$suggestion"',
              onPressed: () {
                editableTextState.hideToolbar();
                _applyFix(activeIssue!, suggestion);
              },
            ),
          );
        }
        if (activeIssue.type == IssueType.spelling) {
          final word = activeIssue.originalText;
          items.add(
            ContextMenuButtonItem(
              label: 'Add "$word" to Dictionary',
              onPressed: () {
                editableTextState.hideToolbar();
                widget.onAddToDictionary?.call(word);
                controller.refreshStyle();
              },
            ),
          );
        }
        final word = activeIssue.originalText;
        items.add(
          ContextMenuButtonItem(
            label: 'Ignore "$word"',
            onPressed: () {
              editableTextState.hideToolbar();
              widget.onIgnore?.call(word);
              controller.refreshStyle();
            },
          ),
        );
      }
    }

    for (final item in editableTextState.contextMenuButtonItems) {
      items.add(
        item.type == ContextMenuButtonType.paste
            ? ContextMenuButtonItem(
                type: item.type,
                label: item.label,
                onPressed: () {
                  editableTextState.hideToolbar();
                  _paste();
                },
              )
            : item,
      );
    }

    final sel = editableTextState.textEditingValue.selection;
    final pos = sel.isCollapsed ? sel.baseOffset : sel.start;
    final activeLink = controller.projection.linkAtVisibleOffset(pos);
    if (activeLink != null) {
      final dest = _resolveLinkDestination(activeLink);
      final isExternal =
          dest.startsWith('http://') || dest.startsWith('https://');
      final targetId = dest.startsWith('orbit-object:')
          ? Uri.decodeComponent(
              dest.substring('orbit-object:'.length).split('#').first,
            )
          : '';
      items.insertAll(0, [
        ContextMenuButtonItem(
          label: 'Open "${activeLink.label}"',
          onPressed: () {
            editableTextState.hideToolbar();
            widget.onOpenLink?.call(dest);
          },
        ),
        ContextMenuButtonItem(
          label: 'Open in new tab',
          onPressed: () {
            editableTextState.hideToolbar();
            if (widget.onOpenInNewTab != null) {
              widget.onOpenInNewTab!(dest);
            } else {
              widget.onOpenLink?.call(dest);
            }
          },
        ),
        if (!isExternal)
          ContextMenuButtonItem(
            label: 'Open to the right',
            onPressed: () {
              editableTextState.hideToolbar();
              if (widget.onOpenToSide != null) {
                widget.onOpenToSide!(dest);
              } else {
                widget.onOpenLink?.call(dest);
              }
            },
          ),
        ContextMenuButtonItem(
          label: 'Copy link',
          onPressed: () {
            editableTextState.hideToolbar();
            Clipboard.setData(ClipboardData(text: dest));
          },
        ),
        if (!isExternal && targetId.isNotEmpty) ...[
          ContextMenuButtonItem(
            label: 'Show backlinks',
            onPressed: () {
              editableTextState.hideToolbar();
              widget.onShowBacklinks?.call(targetId);
            },
          ),
          ContextMenuButtonItem(
            label: 'Reveal in Explorer',
            onPressed: () {
              editableTextState.hideToolbar();
              widget.onRevealInExplorer?.call(targetId);
            },
          ),
        ],
      ]);
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: items,
    );
  }

  KeyEventResult keyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    final isCommand = keyboard.isControlPressed || keyboard.isMetaPressed;
    final hasDocumentSelection = widget.hasDocumentSelection?.call() == true;
    if (hasDocumentSelection &&
        isCommand &&
        event.logicalKey == LogicalKeyboardKey.keyC) {
      final callback = widget.onCopyDocumentSelection;
      if (callback != null) {
        callback();
        return KeyEventResult.handled;
      }
    }
    if (hasDocumentSelection &&
        isCommand &&
        event.logicalKey == LogicalKeyboardKey.keyX) {
      final callback = widget.onCutDocumentSelection;
      if (callback != null) {
        callback();
        return KeyEventResult.handled;
      }
    }
    if (hasDocumentSelection &&
        !isCommand &&
        !keyboard.isAltPressed &&
        (event.logicalKey == LogicalKeyboardKey.backspace ||
            event.logicalKey == LogicalKeyboardKey.delete)) {
      final callback = widget.onDeleteDocumentSelection;
      if (callback?.call() == true) return KeyEventResult.handled;
    }
    if (hasDocumentSelection &&
        !isCommand &&
        !keyboard.isAltPressed &&
        event.character != null &&
        event.character!.isNotEmpty) {
      final callback = widget.onReplaceDocumentSelection;
      if (callback?.call(event.character!) == true) {
        return KeyEventResult.handled;
      }
    }
    if (!controller.value.composing.isCollapsed) {
      // Do not let the enclosing document consume IME undo as document undo.
      return isCommand &&
              {
                LogicalKeyboardKey.keyZ,
                LogicalKeyboardKey.keyY,
              }.contains(event.logicalKey)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (widget.onSelectAllDocument != null &&
        isCommand &&
        event.logicalKey == LogicalKeyboardKey.keyA) {
      if (controller.text.isEmpty ||
          controller.selection.start == 0 &&
              controller.selection.end == controller.text.length) {
        widget.onSelectAllDocument!();
      } else {
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
        keyboard.isShiftPressed &&
        !isCommand &&
        !keyboard.isAltPressed &&
        widget.onExtendSelectionDown != null) {
      final position = controller.selection.extentOffset;
      if (position >= controller.text.length) {
        widget.onExtendSelectionDown!();
        return KeyEventResult.handled;
      }
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
        keyboard.isShiftPressed &&
        !isCommand &&
        !keyboard.isAltPressed &&
        widget.onExtendSelectionUp != null) {
      final position = controller.selection.extentOffset;
      if (position <= 0) {
        widget.onExtendSelectionUp!();
        return KeyEventResult.handled;
      }
    }
    if (keyboard.isAltPressed &&
        !keyboard.isControlPressed &&
        !keyboard.isMetaPressed) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
          widget.onMoveUp != null) {
        widget.onMoveUp!();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
          widget.onMoveDown != null) {
        widget.onMoveDown!();
        return KeyEventResult.handled;
      }
      if (keyboard.isShiftPressed &&
          event.logicalKey == LogicalKeyboardKey.arrowDown &&
          widget.onDuplicate != null) {
        widget.onDuplicate!();
        return KeyEventResult.handled;
      }
    }
    if ({
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.home,
      LogicalKeyboardKey.end,
    }.contains(event.logicalKey)) {
      _pendingMarks.clear();
    }
    if (!widget.raw) {
      final position = controller.selection.extentOffset;
      if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
          !_outsideFormatting &&
          controller.projection.outsideOffset(position) >
              controller.projection.sourceOffset(position, end: true)) {
        _outsideFormatting = true;
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
          _outsideFormatting) {
        _outsideFormatting = false;
        return KeyEventResult.handled;
      }
      if ({
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.home,
        LogicalKeyboardKey.end,
      }.contains(event.logicalKey)) {
        _outsideFormatting = false;
      }
    }
    if (isCommand) {
      if (!keyboard.isShiftPressed &&
          !widget.raw &&
          (event.logicalKey == LogicalKeyboardKey.keyB ||
              event.logicalKey == LogicalKeyboardKey.keyI)) {
        wrap(event.logicalKey == LogicalKeyboardKey.keyB ? '**' : '*');
        return KeyEventResult.handled;
      }
      if (keyboard.isShiftPressed &&
          event.logicalKey == LogicalKeyboardKey.keyH) {
        wrap('==');
        return KeyEventResult.handled;
      }
      if (!keyboard.isShiftPressed &&
          event.logicalKey == LogicalKeyboardKey.keyU) {
        wrap('<u>', closing: '</u>');
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyZ) {
        keyboard.isShiftPressed ? widget.onRedo() : widget.onUndo();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyY) {
        widget.onRedo();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyV) {
        _paste(plain: keyboard.isShiftPressed);
        return KeyEventResult.handled;
      }
    }
    if (!isCommand &&
        !keyboard.isAltPressed &&
        event.logicalKey == LogicalKeyboardKey.delete &&
        controller.selection.isCollapsed &&
        controller.selection.end == controller.text.length &&
        widget.onJoinNext?.call() == true) {
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        !keyboard.isShiftPressed &&
        widget.onEnter != null) {
      widget.onEnter!(controller.value);
      return KeyEventResult.handled;
    }
    if (!isCommand &&
        !keyboard.isAltPressed &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        controller.selection.isCollapsed &&
        controller.selection.start == 0 &&
        widget.onJoinPrevious?.call() == true) {
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.tab && widget.onIndent != null) {
      widget.onIndent!(keyboard.isShiftPressed);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  RenderEditable? _findRenderEditable() {
    RenderEditable? result;
    void visitor(RenderObject child) {
      if (child is RenderEditable) {
        result = child;
        return;
      }
      child.visitChildren(visitor);
    }

    context.findRenderObject()?.visitChildren(visitor);
    return result;
  }

  void _removePeekOverlay() {
    _peekTimer?.cancel();
    _dismissTimer?.cancel();
    _peekOverlayEntry?.remove();
    _peekOverlayEntry = null;
  }

  String _resolveLinkDestination(ProjectedLink link) {
    if (link.isWiki) {
      final wikiLink = WikiLink(
        target: link.target,
        label: link.label,
        start: link.sourceStart,
        end: link.sourceEnd,
      );
      final resolution = resolveWikiLink(
        wikiLink,
        widget.linkTargets,
        bindings: widget.linkBindings,
      );
      if (resolution.status == WikiLinkStatus.resolved) {
        final reference = ObjectReference.parse(link.target);
        return 'orbit-object:${resolution.target!.id}'
            '${reference.isPrecise ? '#${reference.fragment}' : ''}';
      } else if (resolution.status == WikiLinkStatus.unresolved) {
        return 'orbit-missing:${Uri.encodeComponent(link.target)}';
      } else {
        return 'orbit-ambiguous:${Uri.encodeComponent(link.target)}';
      }
    }
    return link.target;
  }

  void _showLinkPeek(ProjectedLink link, RenderEditable render) {
    if (_peekOverlayEntry != null || !mounted) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final destination = _resolveLinkDestination(link);
    final caretRect = render.getLocalRectForCaret(
      TextPosition(offset: link.visibleStart),
    );
    final globalTopLeft = render.localToGlobal(caretRect.topLeft);
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    const cardWidth = 330.0;
    const estimatedHeight = 190.0;

    final showAbove =
        globalTopLeft.dy + estimatedHeight + 20 > screenSize.height &&
        globalTopLeft.dy > estimatedHeight + 20;
    final top = showAbove
        ? globalTopLeft.dy - estimatedHeight - 6
        : globalTopLeft.dy + caretRect.height + 6;
    final left = globalTopLeft.dx
        .clamp(12.0, math.max(12.0, screenSize.width - cardWidth - 12.0))
        .toDouble();

    _peekOverlayEntry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _removePeekOverlay(),
            ),
          ),
          Positioned(
            top: top,
            left: left,
            child: MouseRegion(
              onEnter: (_) => _dismissTimer?.cancel(),
              onExit: (_) {
                _dismissTimer?.cancel();
                _dismissTimer = Timer(const Duration(milliseconds: 220), () {
                  if (mounted) _removePeekOverlay();
                });
              },
              child: OrbitPeekCard(
                href: destination,
                label: link.label,
                allObjects: widget.allObjects,
                linkTargets: widget.linkTargets,
                onOpen: (target) {
                  _removePeekOverlay();
                  widget.onOpenLink?.call(target);
                },
                onOpenInNewTab: (target) {
                  _removePeekOverlay();
                  if (widget.onOpenInNewTab != null) {
                    widget.onOpenInNewTab!(target);
                  } else {
                    widget.onOpenLink?.call(target);
                  }
                },
                onClose: _removePeekOverlay,
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_peekOverlayEntry!);
  }

  void _onHover(PointerHoverEvent event) {
    if (widget.raw) return;
    final render = _findRenderEditable();
    if (render == null) return;
    final localOffset = render.globalToLocal(event.position);
    final textPos = render.getPositionForPoint(localOffset);
    final link = controller.projection.linkAtVisibleOffset(textPos.offset);

    bool isOver = false;
    if (link != null) {
      final startRect = render.getLocalRectForCaret(
        TextPosition(offset: link.visibleStart),
      );
      final endRect = render.getLocalRectForCaret(
        TextPosition(offset: math.max(0, link.visibleEnd - 1)),
      );
      final top = math.min(startRect.top, endRect.top) - 4;
      final bottom = math.max(startRect.bottom, endRect.bottom) + 4;
      if (localOffset.dy >= top && localOffset.dy <= bottom) {
        isOver = true;
      }
    }

    final effectiveLink = isOver ? link : null;
    if (effectiveLink != _hoveredLink) {
      setState(() => _hoveredLink = effectiveLink);
      if (effectiveLink != null) {
        _dismissTimer?.cancel();
        _peekTimer?.cancel();
        _peekTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted &&
              _hoveredLink == effectiveLink &&
              _peekOverlayEntry == null) {
            _showLinkPeek(effectiveLink, render);
          }
        });
      } else {
        _peekTimer?.cancel();
        _dismissTimer?.cancel();
        _dismissTimer = Timer(const Duration(milliseconds: 220), () {
          if (mounted) _removePeekOverlay();
        });
      }
    }
  }

  void _onExit(PointerExitEvent event) {
    if (_hoveredLink != null) {
      setState(() => _hoveredLink = null);
      _peekTimer?.cancel();
      _dismissTimer?.cancel();
      _dismissTimer = Timer(const Duration(milliseconds: 220), () {
        if (mounted) _removePeekOverlay();
      });
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    if (widget.onOpenFootnote != null &&
        event.buttons == kPrimaryMouseButton &&
        !widget.raw) {
      final render = _findRenderEditable();
      if (render != null) {
        final offset = render.getPositionForPoint(event.position).offset;
        for (final m in RegExp(
          r'\[\^([^\]\s]+)\]',
        ).allMatches(controller.text)) {
          if (offset >= m.start &&
              offset < m.end &&
              controller.projection.styles[offset].contains('footnote') &&
              render
                  .getBoxesForSelection(
                    TextSelection(baseOffset: m.start, extentOffset: m.end),
                  )
                  .any(
                    (box) => box
                        .toRect()
                        .inflate(2)
                        .contains(render.globalToLocal(event.position)),
                  )) {
            widget.onOpenFootnote!(m[1]!);
            return;
          }
        }
      }
    }
    if (_hoveredLink == null) return;
    final link = _hoveredLink!;
    final destination = _resolveLinkDestination(link);

    if (event.buttons == kSecondaryMouseButton) {
      _showLinkContextMenu(event.position, link, destination);
      return;
    }

    if (event.buttons == kMiddleMouseButton) {
      _removePeekOverlay();
      if (widget.onOpenInNewTab != null) {
        widget.onOpenInNewTab!(destination);
      } else {
        widget.onOpenLink?.call(destination);
      }
      return;
    }

    final keyboard = HardwareKeyboard.instance;
    final isCommand = keyboard.isControlPressed || keyboard.isMetaPressed;
    if (isCommand) {
      _removePeekOverlay();
      if (widget.onOpenInNewTab != null) {
        widget.onOpenInNewTab!(destination);
      } else {
        widget.onOpenLink?.call(destination);
      }
      return;
    }

    _removePeekOverlay();
    widget.onOpenLink?.call(destination);
  }

  Future<void> _showLinkContextMenu(
    Offset globalPos,
    ProjectedLink link,
    String destination,
  ) async {
    _removePeekOverlay();
    final colors = OrbitColors.of(context);
    final targetId = destination.startsWith('orbit-object:')
        ? Uri.decodeComponent(
            destination.substring('orbit-object:'.length).split('#').first,
          )
        : '';
    final isExternal =
        destination.startsWith('http://') || destination.startsWith('https://');

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPos.dx,
        globalPos.dy,
        globalPos.dx,
        globalPos.dy,
      ),
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 280),
      items: [
        PopupMenuItem(
          value: 'open',
          height: 36,
          child: Row(
            children: [
              Icon(Icons.arrow_forward_rounded, size: 16, color: colors.subtle),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Open "${link.label}"',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'open_tab',
          height: 36,
          child: Row(
            children: [
              Icon(Icons.tab_outlined, size: 16, color: colors.subtle),
              const SizedBox(width: 10),
              const Expanded(child: Text('Open in new tab')),
            ],
          ),
        ),
        if (!isExternal)
          PopupMenuItem(
            value: 'open_side',
            height: 36,
            child: Row(
              children: [
                Icon(
                  Icons.vertical_split_outlined,
                  size: 16,
                  color: colors.subtle,
                ),
                const SizedBox(width: 10),
                const Expanded(child: Text('Open to the right')),
              ],
            ),
          ),
        const PopupMenuDivider(height: 8),
        PopupMenuItem(
          value: 'copy',
          height: 36,
          child: Row(
            children: [
              Icon(Icons.copy_outlined, size: 16, color: colors.subtle),
              const SizedBox(width: 10),
              const Expanded(child: Text('Copy link')),
            ],
          ),
        ),
        if (!isExternal && targetId.isNotEmpty) ...[
          PopupMenuItem(
            value: 'backlinks',
            height: 36,
            child: Row(
              children: [
                Icon(Icons.hub_outlined, size: 16, color: colors.subtle),
                const SizedBox(width: 10),
                const Expanded(child: Text('Show backlinks')),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'explorer',
            height: 36,
            child: Row(
              children: [
                Icon(
                  Icons.folder_open_outlined,
                  size: 16,
                  color: colors.subtle,
                ),
                const SizedBox(width: 10),
                const Expanded(child: Text('Reveal in Explorer')),
              ],
            ),
          ),
        ],
      ],
    );

    if (!mounted || result == null) return;
    switch (result) {
      case 'open':
        widget.onOpenLink?.call(destination);
      case 'open_tab':
        if (widget.onOpenInNewTab != null) {
          widget.onOpenInNewTab!(destination);
        } else {
          widget.onOpenLink?.call(destination);
        }
      case 'open_side':
        if (widget.onOpenToSide != null) {
          widget.onOpenToSide!(destination);
        } else {
          widget.onOpenLink?.call(destination);
        }
      case 'copy':
        await Clipboard.setData(ClipboardData(text: destination));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Link copied to clipboard'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      case 'backlinks':
        widget.onShowBacklinks?.call(targetId);
      case 'explorer':
        widget.onRevealInExplorer?.call(targetId);
    }
  }

  @override
  void dispose() {
    _peekTimer?.cancel();
    _dismissTimer?.cancel();
    _removePeekOverlay();
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: _hoveredLink != null
        ? SystemMouseCursors.click
        : SystemMouseCursors.text,
    onHover: _onHover,
    onExit: _onExit,
    child: Listener(
      onPointerDown: _onPointerDown,
      child: TextField(
        controller: controller,
        focusNode: focus,
        maxLines: null,
        textAlign: widget.textAlign,
        style: widget.style,
        contextMenuBuilder: _buildContextMenu,
        decoration: InputDecoration(
          hintText: widget.hintText,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: _changed,
      ),
    ),
  );

  void _changed(String value) {
    _editRevision++;
    _applyingEdit = true;
    final previousLength = controller.projection.text.length;
    source = widget.raw
        ? value
        : controller.projection.edit(
            value,
            selectionStart: _beforeSelection.start,
            selectionEnd: _beforeSelection.end,
            outsideFormatting: _outsideFormatting,
          );
    if (!widget.raw &&
        _pendingMarks.isNotEmpty &&
        controller.value.composing.isCollapsed) {
      final added =
          value.length -
          previousLength +
          (_beforeSelection.end - _beforeSelection.start);
      if (added > 0) {
        for (final entry in _pendingMarks.entries) {
          final projection = InlineProjection(
            source,
            referenceDefinitions: widget.referenceDefinitions,
          );
          final mark = switch (entry.key) {
            '**' => 'bold',
            '*' => 'italic',
            '~~' => 'strike',
            '==' => 'highlight',
            '<u>' => 'underline',
            '`' => 'code',
            _ => '',
          };
          final selected = projection.styles
              .skip(_beforeSelection.start)
              .take(added);
          final enabled =
              selected.isNotEmpty && selected.every((s) => s.contains(mark));
          if (enabled != entry.value.$2) {
            source = projection.formatRange(
              _beforeSelection.start,
              _beforeSelection.start + added,
              entry.key,
              entry.value.$1,
            );
          }
        }
      }
    }
    controller.projection = InlineProjection(
      source,
      referenceDefinitions: widget.referenceDefinitions,
    );
    widget.onChanged(source);
    if (controller.value.composing.isCollapsed) _sync();
    _applyingEdit = false;
  }
}

class _InlineMathParagraph extends StatelessWidget {
  const _InlineMathParagraph({
    required this.source,
    required this.lineEnding,
    required this.fontSize,
    this.lineHeight = 1.6,
    this.fontFamily,
    required this.onChanged,
    required this.onUndo,
    required this.onRedo,
    required this.onSplit,
    this.alignment = 'left',
    this.focusEquationAt,
    this.grammarEngine,
    this.spellCheckEnabled = true,
    this.onAddToDictionary,
    this.onIgnore,
  });
  final String source;
  final String lineEnding;
  final String alignment;
  final int? focusEquationAt;
  final double fontSize;
  final double lineHeight;
  final String? fontFamily;
  final void Function(String, int?) onChanged;
  final VoidCallback onUndo, onRedo;
  final void Function(String, String) onSplit;
  final EnglishSpellGrammarEngine? grammarEngine;
  final bool spellCheckEnabled;
  final ValueChanged<String>? onAddToDictionary;
  final ValueChanged<String>? onIgnore;
  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    var offset = 0;
    void prose(int start, int end) {
      final text = source.substring(start, end);
      var selection = const TextSelection.collapsed(offset: 0);
      widgets.add(
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 24, maxWidth: 650),
          child: IntrinsicWidth(
            child: _RichTextBlock(
              key: ValueKey('math-text-$start'),
              source: text,
              lineEnding: lineEnding,
              hintText: '',
              style: NoteTypography(
                fontFamily: fontFamily,
                fontSize: fontSize,
                lineHeight: lineHeight,
              ).body(),
              grammarEngine: grammarEngine,
              spellCheckEnabled: spellCheckEnabled,
              onAddToDictionary: onAddToDictionary,
              onIgnore: onIgnore,
              onFocus: (value) => selection = value,
              onChanged: (v) => onChanged(
                source.replaceRange(start, end, v),
                start +
                    InlineProjection(v).sourceOffset(selection.extentOffset),
              ),
              onUndo: onUndo,
              onRedo: onRedo,
              onEnter: (value) {
                final p = InlineProjection(text);
                final left = p.edit(
                  p.text.substring(0, value.selection.start),
                  selectionStart: value.selection.start,
                  selectionEnd: p.text.length,
                );
                final right = p.edit(
                  p.text.substring(value.selection.end),
                  selectionStart: 0,
                  selectionEnd: value.selection.end,
                );
                onSplit(
                  '${source.substring(0, start)}$left',
                  '$right${source.substring(end)}',
                );
              },
            ),
          ),
        ),
      );
    }

    for (final m in inlineMathMatches(source)) {
      prose(offset, m.start);
      widgets.add(
        EditableMathExpression(
          source: m[1]!,
          autofocus:
              focusEquationAt != null &&
              focusEquationAt! >= m.start &&
              focusEquationAt! < m.end,
          onUndo: onUndo,
          onRedo: onRedo,
          onChanged: (v) =>
              onChanged(source.replaceRange(m.start, m.end, '\$$v\$'), null),
        ),
      );
      offset = m.end;
    }
    prose(offset, source.length);
    return Wrap(
      alignment: switch (alignment) {
        'center' => WrapAlignment.center,
        'right' => WrapAlignment.end,
        _ => WrapAlignment.start,
      },
      crossAxisAlignment: WrapCrossAlignment.center,
      children: widgets,
    );
  }
}
