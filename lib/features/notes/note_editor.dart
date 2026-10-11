import 'media_clipboard.dart';
import '../../domain/note_composition.dart';
import 'note_composition.dart';
import 'note_object_surface.dart';
import 'replacement_review.dart';
import 'rich/media_section_source.dart';
import '../../app/orbit_components.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../domain/wiki_links.dart';
import '../../domain/object_reference.dart';
import '../../domain/document_anchors.dart';
import '../../domain/document_review.dart';
import 'document_review_panel.dart';
import 'writing_workspace.dart';
import 'citation_workspace.dart';
import '../../domain/document_citations.dart';
import '../../domain/citation_library.dart';
import '../../domain/writing_structure.dart';
import '../../domain/document_footnotes.dart';
import 'package:uuid/uuid.dart';
import 'markdown_editing.dart';
import 'linked_section.dart';
import 'markdown_clipboard.dart';
import 'note_format_toolbar.dart';
import 'note_typography.dart';
import 'note_link_dialog.dart';
import 'note_outline.dart';
import 'note_text_index.dart';
import 'note_find_index.dart';
import '../../domain/grammar/text_issue_cursor.dart';
import 'unresolved_link_dialog.dart';
import 'rich/rich_markdown_editor.dart';
import 'rich/document_history.dart';
import 'rich/note_math.dart';
import 'rich/note_highlight.dart';
import 'rich/note_underline.dart';
import 'rich/callout_block.dart';
import 'rich/equation_editor.dart';
import 'rich/code_block.dart';
import 'rich/markdown_document.dart';
import 'rich/note_alignment.dart';
import 'rich/media_section.dart';
import '../../domain/grammar/spell_grammar_engine.dart';
import 'latex/latex_document.dart';
import 'latex/latex_syntax_highlighter.dart';
import 'latex/latex_preview.dart';
import 'read_search_overlay.dart';
import 'read_attachment_preview.dart';
import 'latex/latex_inspector.dart';
import 'latex/latex_math_palette.dart';
import 'latex/rich_latex_editor.dart';
import 'latex/latex_format_dialog.dart';
import 'rich/math_grid_editor.dart';
import 'export/pdf_export_service.dart';
import 'export/publication_workspace.dart';
import 'document_stats_dialog.dart';
import 'shortcuts_dialog.dart';
import 'note_outline_panel.dart';
import 'go_to_line_dialog.dart';
import 'word_goal_dialog.dart';
import '../workspace/document_breadcrumbs.dart';
import '../workspace/study_workspace.dart';
import '../../domain/universal_object.dart';
import '../../app/workspace_controller.dart';
import 'document_history_dialog.dart';
import 'bionic_reading.dart';
import 'table_editor_dialog.dart';
import 'note_template_dialog.dart';
import '../../app/orbit_theme.dart';
import 'package:markdown/markdown.dart' as md;

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
    this.lineHeight = 1.6,
    this.contentWidth = 1080,
    this.viewOnly = false,
    this.onContentWidthChanged,
    this.initialScrollOffset = 0,
    this.onScrollChanged,
    this.imageBuilder,
    this.resolveClipboardImage,
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
    this.fontFamily = 'Segoe UI',
    this.onFontFamilyChanged,
    this.spellCheckEnabled = true,
    this.userDictionary = const [],
    this.onAddToUserDictionary,
    this.onToggleSpellCheck,
    this.onToggleBacklinks,
    this.documentFormat = 'markdown',
    this.onDocumentFormatChanged,
    this.onCreateCopy,
    this.isBookmarked = false,
    this.onToggleBookmark,
    this.isFocusMode = false,
    this.onToggleFocusMode,
    this.isPinned = false,
    this.onTogglePin,
    this.vaultName = 'Personal Vault',
    this.folderPath = 'Notes',
    this.allFolders = const [],
    this.allObjects = const [],
    this.folderLookup,
    this.onMoveToFolder,
    this.onCreateNoteInFolder,
    this.showBreadcrumbs = true,
    this.controller,
    this.location,
    this.locationSerial = 0,
    this.locationOffset,
    this.locationLength = 0,
  });

  final String noteId;
  final String title;
  final String body;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onBodyChanged;
  final bool viewOnly;
  final List<NoteLinkTarget> linkTargets;
  final ValueChanged<String> onOpenObject;
  final double fontSize;
  final double lineHeight;
  final double contentWidth;
  final ValueChanged<double>? onContentWidthChanged;
  final double initialScrollOffset;
  final ValueChanged<double>? onScrollChanged;
  final String Function(String)? resolveClipboardImage;
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
  final String fontFamily;
  final ValueChanged<String>? onFontFamilyChanged;
  final bool spellCheckEnabled;
  final List<String> userDictionary;
  final ValueChanged<String>? onAddToUserDictionary;
  final VoidCallback? onToggleSpellCheck;
  final VoidCallback? onToggleBacklinks;
  final String documentFormat;
  final ValueChanged<String>? onDocumentFormatChanged;
  final Future<void> Function(String title, String body, String format)?
  onCreateCopy;
  final bool isBookmarked;
  final VoidCallback? onToggleBookmark;
  final bool isFocusMode;
  final VoidCallback? onToggleFocusMode;
  final bool isPinned;
  final VoidCallback? onTogglePin;
  final String vaultName;
  final String folderPath;
  final List<String> allFolders;
  final List<UniversalObject> allObjects;
  final String Function(UniversalObject object)? folderLookup;
  final ValueChanged<String>? onMoveToFolder;
  final ValueChanged<String>? onCreateNoteInFolder;
  final bool showBreadcrumbs;
  final WorkspaceController? controller;
  final ObjectReference? location;
  final int locationSerial;
  final int? locationOffset;
  final int locationLength;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _GrammarAnnotatedController extends TextEditingController {
  _GrammarAnnotatedController({
    super.text,
    required this.grammarEngine,
    required this.spellCheckEnabled,
    this.isLatex = false,
  });
  final EnglishSpellGrammarEngine grammarEngine;
  bool spellCheckEnabled;
  bool isLatex;

  void refresh() => notifyListeners();

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (isLatex) {
      return LatexTextEditingController(text: text).buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    if (!value.composing.isCollapsed || !spellCheckEnabled) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final issues = grammarEngine.analyze(text);
    if (issues.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final issueCursor = TextIssueCursor(issues);

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
}

class _NoteEditorState extends State<NoteEditor> {
  late final EnglishSpellGrammarEngine _grammarEngine =
      EnglishSpellGrammarEngine(userDictionary: widget.userDictionary);
  late final _GrammarAnnotatedController _title = _GrammarAnnotatedController(
    text: widget.title,
    grammarEngine: _grammarEngine,
    spellCheckEnabled: widget.spellCheckEnabled,
  );
  late final _GrammarAnnotatedController _body = _GrammarAnnotatedController(
    text: widget.body,
    grammarEngine: _grammarEngine,
    spellCheckEnabled: widget.spellCheckEnabled,
    isLatex: widget.documentFormat == 'latex',
  );
  final TextEditingController _find = TextEditingController();
  final TextEditingController _replacement = TextEditingController();
  final FocusNode _bodyFocus = FocusNode();
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _findFocus = FocusNode();
  final UndoHistoryController _undo = UndoHistoryController();
  final _history = DocumentHistory();
  final _richKey = GlobalKey<RichMarkdownEditorState>();
  final _richLatexKey = GlobalKey<RichLatexEditorState>();
  final _sourceFieldKey = GlobalKey();
  late String _historyText = widget.body;
  NoteTextIndex? _cachedTextIndex;
  NoteTextIndex? _selectionOwner, _selectedTextIndex;
  TextSelection? _indexedSelection;
  NoteTextIndex get _textIndex {
    if (_cachedTextIndex?.source != _body.text) {
      _cachedTextIndex = NoteTextIndex(_body.text);
    }
    return _cachedTextIndex!;
  }

  NoteTextIndex _selectionIndex(TextSelection selection) {
    final owner = _textIndex;
    if (!identical(_selectionOwner, owner) || _indexedSelection != selection) {
      _selectionOwner = owner;
      _indexedSelection = selection;
      _selectedTextIndex = NoteTextIndex(selection.textInside(owner.source));
    }
    return _selectedTextIndex!;
  }

  String? _outlineSource;
  bool? _outlineLatex;
  List<NoteHeading> _outlineHeadings = const [];
  List<NoteHeading> get _headings {
    if (_outlineSource != _body.text || _outlineLatex != _isLatex) {
      _outlineSource = _body.text;
      _outlineLatex = _isLatex;
      _outlineHeadings = noteOutline(_body.text, isLatex: _isLatex);
    }
    return _outlineHeadings;
  }

  String? _compositionHistoryStart;
  TextEditingController? _composingHistoryController;
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
  final _readSearch = GlobalKey<ReadSearchOverlayState>();
  NoteFindIndex? _findIndex;
  late String _findSource = widget.body;
  bool get _findRich =>
      !_isLatex &&
      (_mode == NoteEditorMode.rich || _mode == NoteEditorMode.read);
  NoteFindIndex get _searchIndex {
    if (_findIndex?.source != _body.text || _findIndex?.rich != _findRich) {
      _findIndex = NoteFindIndex(_body.text, rich: _findRich);
    }
    return _findIndex!;
  }

  bool _matchCase = false;
  bool _matchWholeWord = false;
  TextSelection _lastSelection = const TextSelection.collapsed(offset: -1);
  late double _lastPreviewOffset = _offset('previewScroll');
  bool _showLatexInspector = false;
  double _readingProgress = 0.0;
  bool _showOutlinePanel = false;
  bool _showReviewPanel = false;
  late bool _outlineOnly = widget.initialViewState['outlineOnly'] == true;
  late String? _focusedSectionKey =
      widget.initialViewState['focusedSection'] as String?;
  List<UniversalObject> get _writingObjects => [
    for (final o in widget.allObjects)
      if (o.id == widget.noteId) o.copyWith(body: _body.text) else o,
  ];
  bool _applyWriting(String before, String next) {
    if (!mounted ||
        _body.text != before ||
        _isComposing ||
        widget.controller?.repository.readOnly == true ||
        widget.controller?.find(widget.noteId)?.isReadOnly == true) {
      _reviewError(
        'The note changed. Reopen the writing tool before applying.',
      );
      return false;
    }
    _apply(
      TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(
          offset: _body.selection.extentOffset.clamp(0, next.length),
        ),
      ),
    );
    _recordView();
    return true;
  }

  void _navigateWriting(int start, int length) {
    final owner = widget.noteId, source = _body.text;
    setState(() {
      _outlineOnly = false;
      _focusedSectionKey = null;
    });
    _setMode(NoteEditorMode.rich);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.noteId == owner && _body.text == source) {
        _richKey.currentState?.selectDocumentRange(start, start + length);
      }
    });
  }

  void _focusWriting(String key) {
    final owner = widget.noteId, source = _body.text;
    final section = resolveWritingSection(_body.text, key);
    if (section == null) {
      _reviewError(
        'This heading is ambiguous. Give it a unique title or block anchor.',
      );
      return;
    }
    setState(() {
      _outlineOnly = false;
      _focusedSectionKey = key;
    });
    _setMode(NoteEditorMode.rich);
    _recordView();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.noteId == owner && _body.text == source) {
        _richKey.currentState?.jumpTo(section.start);
      }
    });
  }

  Future<void> _repairSectionUse(UniversalObject host, SectionUse use) async {
    final before = host.body;
    final encoded = await showLinkedSectionPicker(
      context,
      _writingObjects,
      host.id,
      widget.controller,
    );
    if (!mounted || encoded == null) return;
    try {
      if (host.id == widget.noteId) {
        _applyWriting(before, before.replaceRange(use.start, use.end, encoded));
        return;
      }
      final controller = widget.controller;
      if (controller == null ||
          controller.find(host.id)?.body != before ||
          host.isReadOnly) {
        throw StateError('The referencing note changed or is read-only.');
      }
      controller.edit(
        host.id,
        body: before.replaceRange(use.start, use.end, encoded),
      );
      await controller.flush(host.id);
    } catch (e) {
      _reviewError(e);
    }
  }

  Widget _writingWorkspace({int tab = 0}) => WritingWorkspace(
    key: ValueKey('writing-${widget.noteId}'),
    source: _body.text,
    noteId: widget.noteId,
    objects: _writingObjects,
    initialTab: tab,
    onApply: _applyWriting,
    onNavigate: _navigateWriting,
    onFocus: _focusWriting,
    onOpen: widget.onOpenObject,
    onRepair: _repairSectionUse,
  );
  Future<void> _openWriting({int tab = 0}) async {
    if (!mounted || _isLatex) return;
    final owner = widget.noteId;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .88,
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _body,
            builder: (_, value, _) => WritingWorkspace(
              source: value.text,
              noteId: owner,
              objects: _writingObjects,
              initialTab: tab,
              onApply: (before, next) =>
                  owner == widget.noteId && _applyWriting(before, next),
              onNavigate: (at, length) {
                Navigator.pop(sheetContext);
                if (owner == widget.noteId) _navigateWriting(at, length);
              },
              onFocus: (key) {
                Navigator.pop(sheetContext);
                if (owner == widget.noteId) _focusWriting(key);
              },
              onOpen: widget.onOpenObject,
              onRepair: (host, use) async {
                if (owner == widget.noteId) await _repairSectionUse(host, use);
              },
              onClose: () => Navigator.pop(sheetContext),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editFootnote(String id) async {
    final before = _body.text,
        owner = widget.noteId,
        model = DocumentFootnotes(_body.text);
    final defs = model.definitions.where((d) => d.id == id).toList();
    if (defs.length > 1) {
      _reviewError('Duplicate footnote definitions need repair in Source.');
      return;
    }
    final draft = await showFootnoteDraft(
      context,
      id,
      defs.firstOrNull?.text ?? '',
    );
    if (!mounted || draft == null || owner != widget.noteId) return;
    try {
      _applyWriting(before, model.save(id, draft.$2, renamedId: draft.$1));
    } catch (e) {
      _reviewError(e);
    }
  }

  bool _reviewDockAvailable = false;
  TextSelection _reviewSelection = const TextSelection.collapsed(offset: -1);
  String? _reviewSelectionSource;
  String? _reviewSelectionOwner;

  TextSelection _passageSelection() => _mode == NoteEditorMode.rich
      ? _richKey.currentState?.currentDocumentSelection ?? _body.selection
      : _body.selection;

  void _reviewError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$error')));
  }

  Future<void> _openReviews() async {
    if (!mounted) return;
    _reviewSelection = _passageSelection();
    _reviewSelectionSource = _body.text;
    _reviewSelectionOwner = widget.noteId;
    if (_reviewDockAvailable) {
      setState(() => _showReviewPanel = !_showReviewPanel);
      return;
    }
    final owner = widget.noteId;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .8,
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _body,
            builder: (_, value, _) => DocumentReviewPanel(
              source: value.text,
              onClose: () => Navigator.pop(sheetContext),
              onAction: (id, action) {
                if (owner == widget.noteId) _reviewAction(id, action);
              },
              onAdd: (suggestion) {
                Navigator.pop(sheetContext);
                if (owner == widget.noteId) _addReview(suggestion);
              },
              onJump: (review) {
                Navigator.pop(sheetContext);
                if (owner == widget.noteId) _jumpReview(review);
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addReview(bool suggestion) async {
    if (!mounted) return;
    final selection = _passageSelection();
    final selected = selection.isValid && !selection.isCollapsed
        ? selection
        : _reviewSelectionSource == _body.text &&
              _reviewSelectionOwner == widget.noteId
        ? _reviewSelection
        : const TextSelection.collapsed(offset: -1);
    final before = _body.text, owner = widget.noteId;
    if (_isComposing ||
        !selected.isValid ||
        selected.isCollapsed ||
        selected.end > before.length) {
      _reviewError('Select a passage in Rich or Source mode first.');
      return;
    }
    final draft = await showReviewComposer(
      context,
      before.substring(selected.start, selected.end),
      suggestion: suggestion,
    );
    if (!mounted || draft == null) return;
    if (owner != widget.noteId || before != _body.text || _isComposing) {
      _reviewError(
        'The note changed while composing. Select the passage again.',
      );
      return;
    }
    try {
      final next = DocumentReview.add(
        before,
        id: const Uuid().v4(),
        start: selected.start,
        end: selected.end,
        message: draft.message,
        replacement: draft.replacement,
      );
      _apply(TextEditingValue(text: next, selection: selected));
      if (_reviewDockAvailable) {
        setState(() => _showReviewPanel = true);
      } else {
        await _openReviews();
      }
    } catch (error) {
      _reviewError(error);
    }
  }

  void _reviewAction(String id, String action) {
    if (!mounted) return;
    if (_isComposing) {
      _reviewError('Finish composing text before changing a review.');
      return;
    }
    try {
      final selection = _passageSelection();
      final selected = selection.isValid && !selection.isCollapsed
          ? selection
          : _reviewSelectionSource == _body.text &&
                _reviewSelectionOwner == widget.noteId
          ? _reviewSelection
          : const TextSelection.collapsed(offset: -1);
      final source = _body.text;
      final next = switch (action) {
        'accept' => DocumentReview.accept(source, id),
        'remove' => DocumentReview.remove(source, id),
        'reattach' => DocumentReview.reattach(
          source,
          id,
          selected.start,
          selected.end,
        ),
        _ => DocumentReview.updateState(source, id, action),
      };
      _apply(
        TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(
            offset: _body.selection.extentOffset.clamp(0, next.length),
          ),
        ),
      );
      _reviewSelection = const TextSelection.collapsed(offset: -1);
    } catch (error) {
      _reviewError(error);
    }
  }

  void _jumpReview(ReviewAnnotation review) {
    if (!mounted) return;
    final source = _body.text, owner = widget.noteId;
    final location = locateReview(_body.text, review);
    if (location.start == null) {
      _reviewError(location.warning!);
      return;
    }
    if (_mode == NoteEditorMode.read) {
      setState(() => _mode = NoteEditorMode.rich);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _body.text != source || widget.noteId != owner) return;
      _jumpToHeading(
        NoteHeading('', 1, location.start!),
        matchLength: review.quote.length,
      );
      _body.selection = TextSelection(
        baseOffset: location.start!,
        extentOffset: location.start! + review.quote.length,
      );
      _reviewSelection = _body.selection;
      _reviewSelectionSource = _body.text;
      _reviewSelectionOwner = widget.noteId;
    });
  }

  int? _targetWords;
  int _footerMetricMode = 0;
  bool _bionicReading = false;

  void _toggleOutlinePanel() {
    setState(() => _showOutlinePanel = !_showOutlinePanel);
    _recordView();
  }

  String _stripMarkdown(String text) {
    var s = text;
    s = s.replaceAll(RegExp(r'```[a-zA-Z0-9_-]*\n?'), '');
    s = s.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    s = s.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
    s = s.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');
    s = s.replaceAll(RegExp(r'__([^_]+)__'), r'$1');
    s = s.replaceAll(RegExp(r'_([^_]+)_'), r'$1');
    s = s.replaceAll(RegExp(r'~~([^~]+)~~'), r'$1');
    s = s.replaceAll(RegExp(r'==([^=]+)=='), r'$1');
    s = s.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');
    s = s.replaceAllMapped(
      RegExp(r'\[\[([^\]|]+)(?:\|([^\]]+))?\]\]'),
      (m) => m[2] ?? m[1] ?? '',
    );
    s = s.replaceAll(RegExp(r'^\s*[-*+]\s+\[[ xX]\]\s+', multiLine: true), '');
    s = s.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '');
    s = s.replaceAll(RegExp(r'^\s*>\s+', multiLine: true), '');
    return s.trim();
  }

  void _copyAsHtml() {
    final html = md.markdownToHtml(
      _body.text,
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );
    Clipboard.setData(ClipboardData(text: html));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied document as HTML to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _copyAsPlainText() {
    final plain = _isLatex ? _body.text : _stripMarkdown(_body.text);
    Clipboard.setData(ClipboardData(text: plain));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied plain text to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _copyEntireNoteMarkdown() {
    Clipboard.setData(ClipboardData(text: _body.text));
    final words = DocumentStats.compute(_body.text, isLatex: _isLatex).words;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied entire note to clipboard ($words words)'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showHistoryDialog() async {
    if (widget.controller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document history requires workspace mode'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    await showDocumentHistoryDialog(
      context: context,
      controller: widget.controller!,
      objectId: widget.noteId,
      currentTitle: _title.text.isEmpty ? widget.title : _title.text,
      currentBody: _body.text,
      onRestored: (data) {
        if (!mounted) return;
        _title.text = data.title;
        _body.text = data.body;
        widget.onTitleChanged(data.title);
        widget.onBodyChanged(data.body);
      },
    );
  }

  bool get _isLatex => widget.documentFormat == 'latex';

  void _setMode(NoteEditorMode next, {bool restoreCaret = true}) {
    if (_mode != next) {
      final selection = _mode == NoteEditorMode.rich && !_isLatex
          ? _richKey.currentState?.currentDocumentSelection ?? _body.selection
          : _body.selection;
      if (selection.isValid) _body.selection = selection;
      if (restoreCaret &&
          next == NoteEditorMode.rich &&
          _mode != NoteEditorMode.rich) {
        final offset = _body.selection.isValid
            ? _body.selection.extentOffset
            : 0;
        _richState = Map<String, dynamic>.from(_richState)
          ..['docOffset'] = offset;
      }
      final owner = widget.noteId, source = _body.text;
      setState(() {
        _mode = next;
        _outlineOnly = false;
        if (next != NoteEditorMode.rich) _focusedSectionKey = null;
      });
      _recordView();
      if (_showFind) _updateMatches(fromStart: true);
      if (restoreCaret && next == NoteEditorMode.rich) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              widget.noteId == owner &&
              _body.text == source &&
              _mode == next &&
              _body.selection.isValid &&
              !_isLatex) {
            _richKey.currentState?.selectDocumentRange(
              selection.baseOffset,
              selection.extentOffset,
            );
          }
        });
      }
      if (_showFind) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _showFind && _mode == next) {
            _updateMatches(fromStart: true, focusMatch: true);
            _findFocus.requestFocus();
          }
        });
      }
    }
  }

  void _insertCurrentDate() {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (_mode == NoteEditorMode.rich && !_isLatex) {
      _richKey.currentState?.command('Current Date');
    } else {
      _apply(MarkdownEditing.insert(_body.value, dateStr));
    }
  }

  Future<void> _handleFormatSwitch() async {
    final result = await FormatConversionDialog.show(
      context,
      title: widget.title,
      body: _body.text,
      currentFormat: widget.documentFormat,
    );
    if (result == null || !mounted) return;

    final targetFormat = _isLatex ? 'markdown' : 'latex';

    if (result.action == FormatConversionAction.convertInPlace) {
      _body.text = result.convertedBody;
      widget.onBodyChanged(result.convertedBody);
      widget.onDocumentFormatChanged?.call(targetFormat);
      setState(() {
        _body.isLatex = targetFormat == 'latex';
      });
    } else if (result.action == FormatConversionAction.createCopy) {
      final copyTitle =
          '${widget.title} (${targetFormat == 'latex' ? 'LaTeX' : 'Markdown'})';
      await widget.onCreateCopy?.call(
        copyTitle,
        result.convertedBody,
        targetFormat,
      );
    }
  }

  void _insertSource(String snippet) {
    final selection = _body.selection;
    final curText = _body.text;
    if (selection.isValid && selection.start >= 0) {
      final newText = curText.replaceRange(
        selection.start,
        selection.end,
        snippet,
      );
      _body.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + snippet.length,
        ),
      );
    } else {
      _body.value = TextEditingValue(
        text: '$curText\n$snippet\n',
        selection: TextSelection.collapsed(
          offset: curText.length + snippet.length + 2,
        ),
      );
    }
    widget.onBodyChanged(_body.text);
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _body.isLatex = _isLatex;
    final defaultModeName =
        widget.controller?.session.defaultNoteMode ?? 'rich';
    final fallbackMode = NoteEditorMode.values.firstWhere(
      (m) => m.name == defaultModeName,
      orElse: () => NoteEditorMode.rich,
    );
    _mode = NoteEditorMode.values.firstWhere(
      (m) => m.name == widget.initialViewState['mode'],
      orElse: () => fallbackMode,
    );
    _showOutlinePanel = widget.initialViewState['showOutline'] == true;
    _targetWords = widget.initialViewState['targetWords'] as int?;
    if (widget.initialViewState.containsKey('bionic')) {
      _bionicReading = widget.initialViewState['bionic'] == true;
    } else {
      _bionicReading = widget.controller?.session.bionicReadingDefault == true;
    }
    final base = widget.initialViewState['base'];
    final extent = widget.initialViewState['extent'];
    _body.selection = TextSelection(
      baseOffset: base is int ? base.clamp(0, _body.text.length) : 0,
      extentOffset: extent is int ? extent.clamp(0, _body.text.length) : 0,
    );
    _body.addListener(_recordView);
    _body.addListener(_recordBody);
    _body.addListener(_recordSelection);
    _body.addListener(_refreshFindDocument);
    _undo.onUndo.addListener(_undoDocument);
    _undo.onRedo.addListener(_redoDocument);
    _bodyFocus.onKeyEvent = _sourceKey;
    _previewScroll.addListener(_recordView);
    _sourceScroll.addListener(_recordScroll);
    _scheduleLocation();
  }

  void _scheduleLocation() {
    if (widget.location == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reference = widget.location!;
      final fragment = resolveDocumentFragment(
        _body.text,
        reference,
        latex: _isLatex,
      );
      final offset = widget.locationOffset ?? fragment?.start;
      if (offset == null) {
        if (reference.isPrecise) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text(
                'Location missing or ambiguous. The parent document is open.',
              ),
            ),
          );
        }
        return;
      }
      // Exact navigation uses editable blocks rather than estimating a preview's
      // scroll position from source length.
      if (_mode == NoteEditorMode.read) {
        setState(() => _mode = NoteEditorMode.rich);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _jumpToHeading(
              NoteHeading('', 1, offset),
              matchLength: widget.locationLength,
            );
          }
        });
      } else {
        _jumpToHeading(
          NoteHeading('', 1, offset),
          matchLength: widget.locationLength,
        );
      }
    });
  }

  Future<void> _referenceCurrentBlock({
    required bool place,
    int? sourceOffset,
  }) async {
    final controller = widget.controller;
    if (controller == null || _isLatex) return;
    final selection = _mode == NoteEditorMode.rich
        ? _richKey.currentState?.currentDocumentSelection ?? _body.selection
        : _body.selection;
    final offset = sourceOffset ?? (selection.isValid ? selection.start : 0);
    final selectedSource = _body.text;
    try {
      String? boardId;
      if (place) {
        final boards = controller
            .ofType('orbit.canvas')
            .where((o) => !o.isReadOnly)
            .toList();
        boardId = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('Place current block on Canvas'),
            children: [
              if (boards.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Create a Canvas first.'),
                ),
              for (final board in boards)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, board.id),
                  child: Text(
                    board.title.isEmpty ? 'Untitled Canvas' : board.title,
                  ),
                ),
            ],
          ),
        );
        if (boardId == null || !mounted) return;
      }
      if (controller.find(widget.noteId)?.body != selectedSource) {
        throw StateError('The source changed; select the block again');
      }
      final reference = place
          ? await controller.placeNoteBlock(widget.noteId, offset, boardId!)
          : await controller.referenceNoteBlock(widget.noteId, offset);
      if (!mounted) return;
      if (place) {
        widget.onOpenObject(reference.target);
      } else {
        await Clipboard.setData(
          ClipboardData(text: reference.markdown(_title.text)),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Copied a stable reference to this block'),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not create the reference. Choose a prose block and check local save status.',
            ),
          ),
        );
      }
    }
  }

  void _recordSelection() {
    if (_lastSelection != _body.selection) {
      _lastSelection = _body.selection;
      if (mounted) {
        if (SchedulerBinding.instance.schedulerPhase ==
            SchedulerPhase.persistentCallbacks) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        } else {
          setState(() {});
        }
      }
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
      'showOutline': _showOutlinePanel,
      'outlineOnly': _outlineOnly,
      'focusedSection': _focusedSectionKey,
      'targetWords': _targetWords,
      'bionic': _bionicReading,
    });
  }

  void _jumpToHeading(NoteHeading heading, {int matchLength = 0}) {
    if (_mode == NoteEditorMode.rich) {
      if (!_isLatex) {
        _richKey.currentState?.jumpTo(heading.offset, length: matchLength);
      } else {
        _richLatexKey.currentState?.jumpTo(heading.offset);
      }
      _body.selection = TextSelection.collapsed(offset: heading.offset);
      _recordView();
      return;
    }
    if (_mode == NoteEditorMode.read) {
      if (_previewScroll.hasClients && _body.text.isNotEmpty) {
        final ratio = (heading.offset / _body.text.length).clamp(0.0, 1.0);
        final targetOffset = ratio * _previewScroll.position.maxScrollExtent;
        _previewScroll.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
      return;
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
    if (_mode == NoteEditorMode.split &&
        _previewScroll.hasClients &&
        _body.text.isNotEmpty) {
      final ratio = (heading.offset / _body.text.length).clamp(0.0, 1.0);
      final targetOffset = ratio * _previewScroll.position.maxScrollExtent;
      _previewScroll.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
    _recordView();
  }

  Future<void> _goToLine() async {
    final sel = _body.selection;
    final pos = MarkdownEditing.lineAndColumnOf(
      _body.text,
      sel.isValid ? sel.start : 0,
    );
    final total = MarkdownEditing.totalLinesOf(_body.text);
    final result = await showGoToLineDialog(
      context,
      totalLines: total,
      currentLine: pos.line,
      currentColumn: pos.column,
    );
    if (result != null && mounted) {
      final targetOffset = MarkdownEditing.offsetOfLine(
        _body.text,
        result.line,
        result.column,
      );
      if (_mode == NoteEditorMode.rich) {
        if (!_isLatex) {
          _richKey.currentState?.jumpTo(targetOffset);
        }
        _body.selection = TextSelection.collapsed(offset: targetOffset);
        _recordView();
        return;
      }
      if (_mode == NoteEditorMode.read) {
        if (_previewScroll.hasClients && _body.text.isNotEmpty) {
          final ratio = (targetOffset / _body.text.length).clamp(0.0, 1.0);
          final scrollTarget = ratio * _previewScroll.position.maxScrollExtent;
          _previewScroll.animateTo(
            scrollTarget,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          );
        }
        return;
      }
      _body.selection = TextSelection.collapsed(offset: targetOffset);
      _bodyFocus.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        EditableTextState? editable;
        void visit(Element element) {
          if (element is StatefulElement &&
              element.state is EditableTextState) {
            editable = element.state as EditableTextState;
          }
          element.visitChildElements(visit);
        }

        _sourceFieldKey.currentContext?.visitChildElements(visit);
        editable?.bringIntoView(TextPosition(offset: targetOffset));
      });
      if (_mode == NoteEditorMode.split &&
          _previewScroll.hasClients &&
          _body.text.isNotEmpty) {
        final ratio = (targetOffset / _body.text.length).clamp(0.0, 1.0);
        final scrollTarget = ratio * _previewScroll.position.maxScrollExtent;
        _previewScroll.animateTo(
          scrollTarget,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
      _recordView();
    }
  }

  void _recordScroll() {
    widget.onScrollChanged?.call(_sourceScroll.offset);
    if (_sourceScroll.hasClients &&
        _sourceScroll.position.maxScrollExtent > 0) {
      final p = (_sourceScroll.offset / _sourceScroll.position.maxScrollExtent)
          .clamp(0.0, 1.0);
      if ((p - _readingProgress).abs() > 0.005) {
        setState(() => _readingProgress = p);
      }
    }
  }

  @override
  void didUpdateWidget(NoteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locationSerial != widget.locationSerial ||
        oldWidget.noteId != widget.noteId) {
      _scheduleLocation();
    }
    if (oldWidget.noteId != widget.noteId) {
      _title.text = widget.title;
      _body.text = widget.body;
      _find.clear();
      _showFind = false;
      _findScope = FindScope.document;
      _currentMatchIndex = 0;
      _scopeStart = 0;
      _scopeEnd = 0;
      final defaultModeName =
          widget.controller?.session.defaultNoteMode ?? 'rich';
      final fallbackMode = NoteEditorMode.values.firstWhere(
        (m) => m.name == defaultModeName,
        orElse: () => NoteEditorMode.rich,
      );
      _mode = NoteEditorMode.values.firstWhere(
        (m) => m.name == widget.initialViewState['mode'],
        orElse: () => fallbackMode,
      );
      _showOutlinePanel = widget.initialViewState['showOutline'] == true;
      _outlineOnly = widget.initialViewState['outlineOnly'] == true;
      _focusedSectionKey = widget.initialViewState['focusedSection'] as String?;
      _targetWords = widget.initialViewState['targetWords'] as int?;
      if (widget.initialViewState.containsKey('bionic')) {
        _bionicReading = widget.initialViewState['bionic'] == true;
      } else {
        _bionicReading =
            widget.controller?.session.bionicReadingDefault == true;
      }
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
    if (!listEquals(widget.userDictionary, oldWidget.userDictionary)) {
      _grammarEngine.setUserDictionary(widget.userDictionary);
      _title.refresh();
      _body.refresh();
    }
    if (widget.spellCheckEnabled != oldWidget.spellCheckEnabled) {
      _title.spellCheckEnabled = widget.spellCheckEnabled;
      _body.spellCheckEnabled = widget.spellCheckEnabled;
      _title.refresh();
      _body.refresh();
    }
    if (widget.documentFormat != oldWidget.documentFormat) {
      _body.isLatex = _isLatex;
      _body.refresh();
    }
  }

  Widget _buildEditorContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
    _GrammarAnnotatedController controller,
    ValueChanged<String> onChanged,
  ) {
    final enabled = widget.spellCheckEnabled;
    final items = <ContextMenuButtonItem>[];

    if (enabled) {
      final value = editableTextState.textEditingValue;
      final sel = value.selection;
      final pos = sel.isCollapsed ? sel.baseOffset : sel.start;
      final issues = _grammarEngine.analyze(controller.text);

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
                final original = controller.text;
                if (activeIssue!.start >= 0 &&
                    activeIssue.end <= original.length &&
                    controller.value.composing.isCollapsed &&
                    original.substring(activeIssue.start, activeIssue.end) ==
                        activeIssue.originalText) {
                  final newText = original.replaceRange(
                    activeIssue.start,
                    activeIssue.end,
                    suggestion,
                  );
                  final newOffset = activeIssue.start + suggestion.length;
                  controller.value = TextEditingValue(
                    text: newText,
                    selection: TextSelection.collapsed(offset: newOffset),
                  );
                  onChanged(newText);
                  controller.refresh();
                }
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
                widget.onAddToUserDictionary?.call(word);
                _grammarEngine.addWord(word);
                _title.refresh();
                _body.refresh();
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
              _grammarEngine.ignoreWord(word);
              _title.refresh();
              _body.refresh();
            },
          ),
        );
      }
    }

    items.addAll(editableTextState.contextMenuButtonItems);
    if (!_isLatex &&
        identical(controller, _body) &&
        !controller.selection.isCollapsed) {
      items.add(
        ContextMenuButtonItem(
          label: 'Comment on selection',
          onPressed: () {
            editableTextState.hideToolbar();
            _addReview(false);
          },
        ),
      );
      items.add(
        ContextMenuButtonItem(
          label: 'Suggest replacement',
          onPressed: () {
            editableTextState.hideToolbar();
            _addReview(true);
          },
        ),
      );
    }
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: items,
    );
  }

  void _syncController(TextEditingController controller, String text) {
    if (controller.text == text) return;
    if (identical(controller, _body)) {
      _history.clear();
      _compositionHistoryStart = null;
      _stopCompositionHistoryListener();
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
    _stopCompositionHistoryListener();
    _body.removeListener(_recordSelection);
    _body.removeListener(_refreshFindDocument);
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
    if (_historyPaused) {
      _historyText = _body.text;
      _updateHistoryAvailability();
      return;
    }
    if (_isComposing) {
      _compositionHistoryStart ??= _historyText;
      final controller = _focusedEditable?.widget.controller;
      if (controller != null &&
          !identical(controller, _body) &&
          !identical(controller, _composingHistoryController)) {
        _stopCompositionHistoryListener();
        _composingHistoryController = controller;
        controller.addListener(_compositionHistoryChanged);
      }
      _historyText = _body.text;
      return;
    }
    final compositionStart = _compositionHistoryStart;
    _compositionHistoryStart = null;
    _stopCompositionHistoryListener();
    if (compositionStart != null) {
      _history.record(compositionStart, _body.text);
      _historyText = _body.text;
      _updateHistoryAvailability();
      return;
    }
    if (_historyText == _body.text) return;
    _history.record(_historyText, _body.text);
    _historyText = _body.text;
    _updateHistoryAvailability();
  }

  EditableTextState? get _focusedEditable => FocusManager
      .instance
      .primaryFocus
      ?.context
      ?.findAncestorStateOfType<EditableTextState>();

  bool get _isComposing {
    final editable = _focusedEditable;
    return editable != null &&
        !editable.widget.controller.value.composing.isCollapsed;
  }

  void _stopCompositionHistoryListener() {
    _composingHistoryController?.removeListener(_compositionHistoryChanged);
    _composingHistoryController = null;
  }

  void _compositionHistoryChanged() {
    // EditableText notifies its controller before onChanged projects Rich text
    // into the document. Record the final source after that projection completes.
    Future.microtask(() {
      if (mounted) _recordBody();
    });
  }

  void _updateHistoryAvailability() {
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

  void _undoDocument() {
    if (_isComposing) return;
    _recordBody();
    _historyApply(_history.undo(_body.text));
  }

  void _redoDocument() {
    if (_isComposing) return;
    _recordBody();
    _historyApply(_history.redo(_body.text));
  }

  Widget _objectBlock(NoteObjectBlock block, bool editable) =>
      NoteObjectSurface(
        key: ValueKey(block.id),
        block: block,
        objects: widget.allObjects,
        controller: widget.controller,
        editable: editable && !widget.viewOnly && _mode != NoteEditorMode.read,
        onOpen: widget.onOpenObject,
      );

  (int, int) _compositionRange() {
    final selection = _passageSelection();
    final doc = MarkdownDocument.parse(_body.text);
    final start = selection.isValid
        ? selection.start.clamp(0, _body.text.length)
        : 0;
    final end = selection.isValid && !selection.isCollapsed
        ? selection.end - 1
        : start;
    final first = doc.blockAt(start), last = doc.blockAt(end);
    for (final block in doc.blocks.sublist(first, last + 1)) {
      if (![
        MarkdownBlockKind.text,
        MarkdownBlockKind.list,
        MarkdownBlockKind.quote,
        MarkdownBlockKind.blank,
      ].contains(block.kind)) {
        throw const FormatException(
          'Select prose or list blocks. Structured blocks keep their own editing tools.',
        );
      }
    }
    return (
      doc.offsetOf(first),
      doc.offsetOf(last) + doc.blocks[last].source.length,
    );
  }

  Future<void> _compositionCommand(String command) async {
    if (_isComposing || _mode == NoteEditorMode.read) return;
    if (command == 'Review replacements') {
      if (!_showFind) {
        _openFind();
        return;
      }
      await _reviewReplacements();
      return;
    }
    final owner = widget.noteId, before = _body.text;
    final controller = widget.controller;
    final workspace = controller?.repository.workspaceId;
    if (controller?.repository.readOnly == true ||
        controller?.find(owner)?.isReadOnly == true) {
      return;
    }
    try {
      if (command == 'Two columns' ||
          command == 'Three columns' ||
          command == 'Convert selection') {
        final range = _compositionRange();
        final selected = before.substring(range.$1, range.$2);
        String converted;
        if (command == 'Convert selection') {
          final kind = await showDialog<String>(
            context: context,
            builder: (context) => SimpleDialog(
              title: const Text('Convert selected blocks'),
              children: [
                for (final label in [
                  'Paragraphs',
                  'Checklist',
                  'Callout',
                  'Table',
                  'Canvas cards',
                ])
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, label),
                    child: Text(label),
                  ),
              ],
            ),
          );
          if (kind == null ||
              !mounted ||
              widget.noteId != owner ||
              _body.text != before) {
            return;
          }
          if (kind == 'Canvas cards') {
            if (controller == null) {
              throw const FormatException(
                'Open a local Vault to place linked blocks.',
              );
            }
            final target = await showNoteLinkDialog(context, [
              for (final o in controller.activeObjects)
                if (o.typeId == 'orbit.canvas' && !o.isReadOnly)
                  NoteLinkTarget(id: o.id, title: o.title),
            ]);
            if (target == null ||
                !mounted ||
                widget.noteId != owner ||
                _body.text != before ||
                workspace != controller.repository.workspaceId) {
              return;
            }
            if (controller.find(owner)?.body != before) {
              throw const FormatException(
                'Save the current note before placing linked blocks.',
              );
            }
            final doc = MarkdownDocument.parse(before);
            final offsets = [
              for (var i = 0; i < doc.blocks.length; i++)
                if (doc.offsetOf(i) >= range.$1 &&
                    doc.offsetOf(i) < range.$2 &&
                    doc.blocks[i].kind != MarkdownBlockKind.blank)
                  doc.offsetOf(i),
            ];
            // Work backwards: adding an anchor must not shift the next source offset.
            var expected = before;
            for (final offset in offsets.reversed) {
              if (controller.repository.workspaceId != workspace ||
                  controller.find(owner)?.body != expected) {
                throw const FormatException(
                  'The source changed. Existing placements remain recoverable.',
                );
              }
              await controller.placeNoteBlock(owner, offset, target.id);
              expected = controller.find(owner)!.body;
            }
            if (mounted && widget.noteId == owner) {
              widget.onOpenObject(target.id);
            }
            return;
          }
          converted = convertProseBlocks(selected, kind);
        } else {
          converted = NoteColumns.create([
            selected,
            if (command == 'Three columns') '\n',
            '\n',
          ], eol: before.contains('\r\n') ? '\r\n' : '\n');
        }
        if (mounted &&
            widget.noteId == owner &&
            workspace == controller?.repository.workspaceId) {
          _applyWriting(
            before,
            before.replaceRange(range.$1, range.$2, converted),
          );
        }
        return;
      }
      await _insertFrom(() async {
        UniversalObject? target;
        if (command == 'Inline drawing') {
          final choice = await showDialog<String>(
            context: context,
            builder: (context) => SimpleDialog(
              title: const Text('Inline drawing'),
              children: [
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, 'new'),
                  child: const Text('Create a drawing'),
                ),
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, 'existing'),
                  child: const Text('Use an existing Canvas'),
                ),
              ],
            ),
          );
          if (choice == null ||
              !mounted ||
              _body.text != before ||
              widget.noteId != owner ||
              workspace != controller?.repository.workspaceId) {
            return null;
          }
          if (choice == 'new') {
            if (controller == null) {
              throw const FormatException('Open a Vault to create a drawing.');
            }
            target = await controller.create(
              'orbit.canvas',
              open: false,
              title: '${_title.text} — Drawing',
              properties: {
                'folder': controller.find(owner)?.properties['folder'],
                'project': controller.find(owner)?.properties['project'],
              },
            );
            if (target == null) {
              throw const FormatException('The drawing could not be saved.');
            }
          }
        }
        if (target == null) {
          if (!mounted) return null;
          final selected = await showNoteLinkDialog(context, [
            for (final o in widget.allObjects)
              if (!o.isDeleted &&
                  o.id != owner &&
                  (command != 'Inline drawing' || o.typeId == 'orbit.canvas'))
                NoteLinkTarget(id: o.id, title: o.title),
          ]);
          if (selected == null || !mounted) return null;
          target = (controller?.activeObjects ?? widget.allObjects)
              .where((o) => o.id == selected.id)
              .firstOrNull;
        }
        if (target == null ||
            target.isDeleted ||
            workspace != controller?.repository.workspaceId ||
            widget.noteId != owner) {
          return null;
        }
        return '\n\n${NoteObjectBlock(target.id, target.title).encode()}\n';
      });
    } catch (error) {
      _reviewError(error);
    }
  }

  Future<void> _reviewReplacements() async {
    if (_isComposing) return;
    final before = _body.text, owner = widget.noteId;
    final workspace = widget.controller?.repository.workspaceId;
    final replacement = _replacement.text;
    final index = _searchIndex, matches = _computeMatches();
    if (matches.isEmpty) return;
    final chosen = await showReplacementReview(
      context,
      index,
      matches,
      replacement,
    );
    if (chosen == null ||
        !mounted ||
        widget.noteId != owner ||
        workspace != widget.controller?.repository.workspaceId) {
      return;
    }
    try {
      _applyWriting(before, index.replace(chosen, replacement));
      _updateMatches(focusMatch: false);
    } on FormatException {
      _reviewError(
        'Could not safely replace this markup. Try editing it in Source.',
      );
    } catch (error) {
      _reviewError(error);
    }
  }

  Future<void> _insertCommand(String command) async {
    if (command == 'Image and text' && _mode != NoteEditorMode.rich) {
      final selection = _passageSelection();
      final text = selection.isValid && !selection.isCollapsed
          ? selection.textInside(_body.text)
          : '\n';
      await _insertFrom(() async {
        final image = await widget.onInsertAttachment?.call();
        if (image == null) return null;
        final match = RegExp(
          r'^!\[[^\]]*\]\((?:<([^>]+)>|([^ )]+))',
        ).firstMatch(image.trim());
        if (match == null) {
          throw const FormatException('Choose an image for this layout.');
        }
        return '\n\n${MediaSectionSource.create(match[1] ?? match[2]!, imageMarkdown: image.trim(), body: text)}\n';
      });
      return;
    }
    if ([
      'Two columns',
      'Three columns',
      'Live object',
      'Inline drawing',
      'Convert selection',
      'Review replacements',
    ].contains(command)) {
      await _compositionCommand(command);
      return;
    }
    if (command == 'Citations & bibliography') {
      final owner = widget.noteId;
      final workspace = widget.controller?.repository.workspaceId;
      final selection = _passageSelection();
      final original = _body.text;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .88,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _body,
              builder: (_, value, _) => CitationWorkspace(
                source: value.text,
                onOpenLibrary: (id) {
                  if (owner != widget.noteId ||
                      workspace != widget.controller?.repository.workspaceId) {
                    return;
                  }
                  if (!widget.allObjects.any(
                    (o) => o.id == id && !o.isDeleted,
                  )) {
                    _reviewError(
                      'The library is unavailable. This note retains its source metadata.',
                    );
                    return;
                  }
                  Navigator.pop(sheetContext);
                  widget.onOpenObject(id);
                },
                libraries: [
                  for (final object in widget.allObjects)
                    if (!object.isDeleted &&
                        object.id != owner &&
                        object.typeId == 'orbit.note' &&
                        object.properties['citationLibrary'] == 1)
                      CitationLibrary(object.id, object.title, object.body),
                ],
                onCreateLibrary: widget.controller == null
                    ? null
                    : (title, body) async {
                        final controller = widget.controller!;
                        if (owner != widget.noteId ||
                            workspace != controller.repository.workspaceId ||
                            controller.repository.readOnly) {
                          throw const FormatException(
                            'The workspace changed or is read-only.',
                          );
                        }
                        Navigator.pop(sheetContext);
                        final library = await controller.create(
                          'orbit.note',
                          title: title,
                          body: body,
                          properties: {'citationLibrary': 1},
                        );
                        if (library == null) {
                          _reviewError(
                            controller.error ??
                                'Could not create source library.',
                          );
                          return;
                        }
                        await controller.flush(library.id);
                      },
                onApply: (before, next) =>
                    owner == widget.noteId &&
                    workspace == widget.controller?.repository.workspaceId &&
                    _applyWriting(before, next),
                onInsert: (content) {
                  if (owner != widget.noteId ||
                      workspace != widget.controller?.repository.workspaceId ||
                      !selection.isValid ||
                      selection.end > _body.text.length ||
                      _body.text.substring(0, selection.end) !=
                          original.substring(0, selection.end)) {
                    _reviewError(
                      'Return to your writing position and reopen citations before inserting.',
                    );
                    return;
                  }
                  final before = _body.text;
                  if (!DocumentCitations(
                    before,
                  ).canInsert(selection.start, selection.end)) {
                    _reviewError(
                      'Choose prose outside code, metadata, citations or generated References.',
                    );
                    return;
                  }
                  final next = before.replaceRange(
                    selection.start,
                    selection.end,
                    content,
                  );
                  try {
                    if (_applyWriting(
                      before,
                      DocumentCitations(next).refresh(addBibliography: false),
                    )) {
                      Navigator.pop(sheetContext);
                    }
                  } catch (error) {
                    _reviewError(error);
                  }
                },
                onClose: () => Navigator.pop(sheetContext),
              ),
            ),
          ),
        ),
      );
      return;
    }
    if (command == 'Publish document') {
      final controller = widget.controller;
      final workspace = controller?.repository.workspaceId;
      await showPublicationWorkspace(
        context,
        title: _title.text,
        source: _body.text,
        ownerId: widget.noteId,
        objects: List.of(widget.allObjects),
        readImage: controller == null
            ? null
            : (source) async {
                if (controller.repository.workspaceId != workspace) return null;
                final path =
                    widget.resolveClipboardImage?.call(source) ?? source;
                return controller.repository.readAttachment(path);
              },
      );
      return;
    }
    if (command == 'Page break') {
      await _insertFrom(() async => '\n\n<!-- orbit:pagebreak -->\n\n');
      return;
    }
    if (command == 'Writing workspace') {
      await _openWriting();
      return;
    }
    if (command == 'Manage footnotes') {
      await _openWriting(tab: 1);
      return;
    }
    if (command == 'Linked section uses') {
      await _openWriting(tab: 2);
      return;
    }
    if (command == 'Outline planning') {
      setState(() {
        _outlineOnly = !_outlineOnly;
        _focusedSectionKey = null;
      });
      _recordView();
      return;
    }
    if (command == 'Review annotations') {
      await _openReviews();
      return;
    }
    if (command == 'Comment on selection' || command == 'Suggest replacement') {
      await _addReview(command == 'Suggest replacement');
      return;
    }
    if (command == 'Linked section' && _mode != NoteEditorMode.rich) {
      await _insertFrom(() async {
        final section = await showLinkedSectionPicker(
          context,
          widget.allObjects,
          widget.noteId,
          widget.controller,
        );
        return section == null ? null : '\n\n$section\n';
      });
      return;
    }
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

    // Alt+Up / Alt+Down / Shift+Alt+Down
    if (keyboard.isAltPressed &&
        !keyboard.isControlPressed &&
        !keyboard.isMetaPressed) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
          !keyboard.isShiftPressed) {
        final next = MarkdownEditing.moveLine(_body.value, up: true);
        if (next != null) {
          _apply(next);
          return KeyEventResult.handled;
        }
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
          !keyboard.isShiftPressed) {
        final next = MarkdownEditing.moveLine(_body.value, up: false);
        if (next != null) {
          _apply(next);
          return KeyEventResult.handled;
        }
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
          keyboard.isShiftPressed) {
        final next = MarkdownEditing.duplicateLine(_body.value);
        if (next != null) {
          _apply(next);
          return KeyEventResult.handled;
        }
      }
    }

    if (keyboard.isControlPressed &&
        !keyboard.isAltPressed &&
        !keyboard.isMetaPressed) {
      if (event.logicalKey == LogicalKeyboardKey.keyG) {
        _goToLine();
        return KeyEventResult.handled;
      }
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

    // Backspace empty bracket/quote pair
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        !keyboard.isControlPressed &&
        !keyboard.isAltPressed &&
        !keyboard.isMetaPressed &&
        !keyboard.isShiftPressed) {
      final next = MarkdownEditing.handleBackspacePair(_body.value);
      if (next != null) {
        _apply(next);
        return KeyEventResult.handled;
      }
    }

    // Auto-wrap selection or auto-pair brackets / quotes
    if (!keyboard.isControlPressed &&
        !keyboard.isAltPressed &&
        !keyboard.isMetaPressed &&
        event.character != null &&
        event.character!.isNotEmpty) {
      final next = MarkdownEditing.handleAutoWrapOrPair(
        _body.value,
        event.character!,
      );
      if (next != null) {
        _apply(next);
        return KeyEventResult.handled;
      }
    }

    TextEditingValue? next;
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        !keyboard.isShiftPressed &&
        !keyboard.isControlPressed &&
        !keyboard.isAltPressed) {
      next = MarkdownEditing.continueList(_body.value);
    }
    if (event.logicalKey == LogicalKeyboardKey.tab &&
        !keyboard.isControlPressed &&
        !keyboard.isAltPressed) {
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
      if (mounted) setState(() {});
      return;
    }
    switch (action) {
      case NoteFormatAction.alignLeft:
      case NoteFormatAction.alignCenter:
      case NoteFormatAction.alignRight:
        final document = MarkdownDocument.parse(_body.text);
        final index = document.blockAt(
          _body.selection.isValid ? _body.selection.start : 0,
        );
        final block = document.blocks[index];
        if (!block.canAlign) {
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
        final replacement = block.withAlignment(
          alignment,
          lineEnding: document.source.contains('\r\n') ? '\r\n' : '\n',
        );
        if (replacement == block.source) return;
        final start = document.offsetOf(index);
        final delta = replacement.length - block.source.length;
        int mapOffset(int offset) {
          if (offset < start) return offset;
          if (offset >= start + block.alignmentPrefix.length) {
            return offset + delta;
          }
          return start +
              (offset - start).clamp(0, block.alignmentPrefix.length + delta);
        }
        final selection = _body.selection.isValid
            ? _body.selection
            : const TextSelection.collapsed(offset: 0);
        _apply(
          TextEditingValue(
            text: _body.text.replaceRange(
              start,
              start + block.source.length,
              replacement,
            ),
            selection: TextSelection(
              baseOffset: mapOffset(selection.baseOffset),
              extentOffset: mapOffset(selection.extentOffset),
            ),
          ),
        );
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
        final tableMarkdown = await showMarkdownTableDialog(context);
        if (!mounted || tableMarkdown == null || tableMarkdown.isEmpty) return;
        _apply(MarkdownEditing.insert(_body.value, '\n$tableMarkdown\n'));
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
    if (callback == null || _inserting) return;
    final noteId = widget.noteId;
    final originalValue = _body.value, originalMode = _mode;
    setState(() => _inserting = true);
    try {
      if (_mode == NoteEditorMode.rich) {
        await _richKey.currentState?.insertFrom(callback);
        return;
      }
      final content = await callback();
      if (!mounted || widget.noteId != noteId || content == null) return;
      if (_body.value != originalValue || _mode != originalMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('The insertion position changed.'),
            action: SnackBarAction(
              label: 'Insert here',
              onPressed: () {
                if (!mounted || widget.noteId != noteId) return;
                if (_mode == NoteEditorMode.rich) {
                  _richKey.currentState?.insertMarkdown(content);
                } else {
                  _apply(MarkdownEditing.insert(_body.value, content));
                }
              },
            ),
          ),
        );
        return;
      }
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

  void _refreshFindDocument() {
    final next = _body.text;
    if (next == _findSource) return;
    final previous = _findSource;
    _findSource = next;
    _findIndex = null;
    if (!_showFind) return;
    var start = 0, oldEnd = previous.length, newEnd = next.length;
    while (start < oldEnd && start < newEnd && previous[start] == next[start]) {
      start++;
    }
    while (oldEnd > start &&
        newEnd > start &&
        previous[oldEnd - 1] == next[newEnd - 1]) {
      oldEnd--;
      newEnd--;
    }
    int translate(int offset, {required bool trailing}) {
      if (offset < start || offset == start && !trailing) return offset;
      if (offset >= oldEnd) return offset + newEnd - oldEnd;
      return trailing ? newEnd : start;
    }

    _scopeStart = translate(_scopeStart, trailing: false).clamp(0, next.length);
    _scopeEnd = translate(
      _scopeEnd,
      trailing: true,
    ).clamp(_scopeStart, next.length);
    void refresh() {
      if (mounted && _showFind) _updateMatches();
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
    } else {
      refresh();
    }
  }

  List<NoteFindMatch> _computeMatches() => _searchIndex.matches(
    _find.text,
    matchCase: _matchCase,
    wholeWord: _matchWholeWord,
    start: _findScope == FindScope.selection ? _scopeStart : 0,
    end: _findScope == FindScope.selection ? _scopeEnd : null,
  );

  void _selectFindMatch(NoteFindMatch match) {
    _body.selection = TextSelection(
      baseOffset: match.start,
      extentOffset: match.end,
    );
    if (_mode == NoteEditorMode.rich) {
      final searchedSource = _body.text;
      final query = _find.text;
      bool stillCurrent() =>
          mounted &&
          _showFind &&
          _mode == NoteEditorMode.rich &&
          _body.text == searchedSource &&
          _find.text == query;
      void jump() {
        if (!stillCurrent()) return;
        if (_isLatex) {
          _richLatexKey.currentState?.jumpTo(match.start);
        } else {
          _richKey.currentState?.jumpTo(
            match.start,
            length: match.end - match.start,
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (stillCurrent()) {
            _body.selection = TextSelection(
              baseOffset: match.start,
              extentOffset: match.end,
            );
            _findFocus.requestFocus();
          }
        });
      }

      if (!_isLatex && _richKey.currentState?.widget.body != searchedSource) {
        // Replacement may change fences/block identity. Navigate only after the
        // child receives the new source, then restore Find after field focus.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          jump();
          WidgetsBinding.instance.ensureVisualUpdate();
        });
      } else {
        jump();
      }
    } else if (_mode == NoteEditorMode.read) {
      final searchedSource = _body.text, query = _find.text;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !_showFind ||
            _mode != NoteEditorMode.read ||
            _body.text != searchedSource ||
            _find.text != query) {
          return;
        }
        if (!(_readSearch.currentState?.revealSelected() ?? false)) {
          _jumpToHeading(NoteHeading('', 1, match.start));
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_showFind || _body.selection.end != match.end) return;
        EditableTextState? editable;
        void visit(Element element) {
          if (element is StatefulElement &&
              element.state is EditableTextState) {
            editable = element.state as EditableTextState;
          }
          element.visitChildElements(visit);
        }

        _sourceFieldKey.currentContext?.visitChildElements(visit);
        editable?.bringIntoView(TextPosition(offset: match.end));
      });
    }
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
      _selectFindMatch(match);
    }
  }

  void _openFind() {
    if (_isComposing) return;
    if (_showFind) {
      _find.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _find.text.length,
      );
      _findFocus.requestFocus();
      return;
    }
    final sel = _mode == NoteEditorMode.rich && !_isLatex
        ? _richKey.currentState?.currentDocumentSelection ?? _body.selection
        : _body.selection;
    if (sel.isValid && !sel.isCollapsed) {
      _scopeStart = math.min(sel.start, sel.end);
      _scopeEnd = math.max(sel.start, sel.end);
      final selectedText = _searchIndex.selectedText(sel.start, sel.end);
      final isMultiLine = selectedText.contains('\n');
      if (!isMultiLine && selectedText.length <= 40) {
        _find.text = selectedText;
        _findScope = FindScope.document;
      } else {
        _findScope = FindScope.selection;
      }
    } else {
      _findScope = FindScope.document;
      _scopeStart = _scopeEnd = 0;
    }
    setState(() {
      _showFind = true;
    });
    if (_find.text.isNotEmpty) {
      _find.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _find.text.length,
      );
    }
    _updateMatches(focusMatch: false);
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
    _selectFindMatch(match);
    _findFocus.requestFocus();
    setState(() {
      _findCount = matches.length;
      _currentMatchIndex = nextIndex + 1;
    });
  }

  void _findPrevious() {
    if (_find.text.isEmpty) return;
    final matches = _computeMatches();
    if (matches.isEmpty) {
      _updateMatches();
      return;
    }
    final currentStart = _body.selection.start;
    int prevIndex = matches.lastIndexWhere((m) => m.end <= currentStart);
    if (prevIndex < 0) {
      prevIndex = matches.length - 1;
    }
    final match = matches[prevIndex];
    _selectFindMatch(match);
    _findFocus.requestFocus();
    setState(() {
      _findCount = matches.length;
      _currentMatchIndex = prevIndex + 1;
    });
  }

  void _replace({bool all = false}) {
    if (_find.text.isEmpty || _isComposing) return;
    final matches = _computeMatches();
    if (matches.isEmpty) {
      _updateMatches();
      return;
    }
    final selection = _body.selection;
    final selected = matches
        .where((m) => m.start == selection.start && m.end == selection.end)
        .firstOrNull;
    // A random editor selection never authorizes replacement outside scope.
    final edits = all
        ? matches
        : [
            selected ??
                matches[_currentMatchIndex.clamp(1, matches.length) - 1],
          ];
    final String next;
    try {
      next = _searchIndex.replace(edits, _replacement.text);
    } on FormatException {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Could not safely replace this markup. Try editing it in Source.',
          ),
        ),
      );
      return;
    }
    if (next != _body.text) {
      final caret = all
          ? selection.extentOffset
          : _searchIndex.replacementEnd(edits.first, _replacement.text, next);
      _body.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: caret.clamp(0, next.length)),
      );
      widget.onBodyChanged(next);
      setState(() {});
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
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              const SnackBar(
                content: Text('Select text before searching in a selection.'),
              ),
            );
            return;
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
    if (_mode == NoteEditorMode.rich) {
      if (_isLatex) {
        _richLatexKey.currentState?.jumpTo(_body.selection.start);
      } else {
        _richKey.currentState?.jumpTo(
          _body.selection.start,
          length: _body.selection.end - _body.selection.start,
        );
      }
    } else if (_mode != NoteEditorMode.read) {
      _bodyFocus.requestFocus();
    }
  }

  Future<void> _openLink(String? href) async {
    if (href == null) return;
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      _openLinkInNewTab(href);
      return;
    }
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
        showUnresolvedLinkDialog(context, Uri.decodeComponent(uri.path));
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

  void _openLinkInNewTab(String href) {
    final uri = Uri.tryParse(href);
    if (uri != null && uri.scheme == 'orbit-object') {
      final id = Uri.decodeComponent(uri.path);
      widget.controller?.openObject(id);
      widget.onOpenObject(id);
    } else {
      _openLink(href);
    }
  }

  void _openLinkToSide(String href) {
    final uri = Uri.tryParse(href);
    if (uri != null && uri.scheme == 'orbit-object') {
      final id = Uri.decodeComponent(uri.path);
      if (widget.controller != null) {
        widget.controller!.openObject(id, secondary: true);
      } else {
        widget.onOpenObject(id);
      }
    } else {
      _openLink(href);
    }
  }

  void _showBacklinksFor(String targetId) {
    widget.onToggleBacklinks?.call();
  }

  void _revealInExplorer(String targetId) {
    widget.controller?.openObject(targetId);
  }

  KeyEventResult _clipboardKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        !_titleFocus.hasFocus &&
        HardwareKeyboard.instance.isControlPressed) {
      if (event.logicalKey == LogicalKeyboardKey.keyG) {
        _goToLine();
        return KeyEventResult.handled;
      }
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
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      final snapshot = _body.value;
      final sel = snapshot.selection;
      if (!_isLatex &&
          sel.isValid &&
          !sel.isCollapsed &&
          (event.logicalKey == LogicalKeyboardKey.keyC ||
              event.logicalKey == LogicalKeyboardKey.keyX)) {
        final cut = event.logicalKey == LogicalKeyboardKey.keyX;
        Future<void> transfer() async {
          try {
            await Clipboard.setData(
              ClipboardData(
                text: portableClipboardMarkdown(
                  sel.textInside(snapshot.text),
                  widget.resolveClipboardImage,
                ),
              ),
            );
            if (cut && mounted && _body.value == snapshot) {
              _apply(
                TextEditingValue(
                  text: snapshot.text.replaceRange(sel.start, sel.end, ''),
                  selection: TextSelection.collapsed(offset: sel.start),
                ),
              );
            }
          } catch (_) {}
        }

        transfer();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyV &&
          sel.isValid &&
          !HardwareKeyboard.instance.isShiftPressed &&
          snapshot.composing.isCollapsed) {
        readMarkdownClipboard().then((pasted) {
          if (!mounted || !_bodyFocus.hasFocus || _body.value != snapshot) {
            return;
          }
          var text = pasted ?? '';
          final url = text.trim();
          if (!sel.isCollapsed &&
              (url.startsWith('https://') || url.startsWith('http://'))) {
            text = '[${sel.textInside(snapshot.text)}]($url)';
          }
          if (text.isNotEmpty) {
            _apply(
              TextEditingValue(
                text: snapshot.text.replaceRange(sel.start, sel.end, text),
                selection: TextSelection.collapsed(
                  offset: sel.start + text.length,
                ),
              ),
            );
          } else if (widget.onPasteImage != null) {
            _insertFrom(widget.onPasteImage);
          }
        });
        return KeyEventResult.handled;
      }
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
    final pdfId = pdfSource['objectId'] is String
        ? pdfSource['objectId'] as String
        : null;
    final page = pdfSource['page'] is int && (pdfSource['page'] as int) > 0
        ? pdfSource['page'] as int
        : 1;
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
      if (widget.viewOnly) {
        return _isLatex
            ? LatexPreview(
                latex: _body.text,
                contentWidth: widget.contentWidth,
                fontSize: widget.fontSize,
                scrollController: _previewScroll,
                imageBuilder: widget.imageBuilder,
              )
            : _preview();
      }
      final focusedSection = resolveWritingSection(
        _body.text,
        _focusedSectionKey,
      );
      _reviewDockAvailable =
          constraints.maxWidth >= 1100 &&
          MediaQuery.textScalerOf(context).scale(16) <= 24;
      final wide = constraints.maxWidth >= 600;
      final mode = !wide && _mode == NoteEditorMode.split
          ? NoteEditorMode.write
          : _mode;
      final words = _textIndex.words;
      final chars = _textIndex.characters;
      final charsNoSpaces = _footerMetricMode == 2
          ? _textIndex.charactersNoSpaces
          : 0;
      final readMinutes = math.max(1, (words / 200).ceil());
      final sel = _body.selection;
      final hasSelection = sel.isValid && !sel.isCollapsed;
      final selectedIndex = hasSelection ? _selectionIndex(sel) : null;
      if (!hasSelection) {
        _selectionOwner = null;
        _selectedTextIndex = null;
        _indexedSelection = null;
      }
      final selWords = hasSelection ? selectedIndex!.words : 0;
      final selChars = hasSelection ? selectedIndex!.characters : 0;
      final selReadTime = selWords < 100
          ? '< 1 min read'
          : '~${math.max(1, (selWords / 200).ceil())} min read';
      final activeMetricLabel = switch (_footerMetricMode) {
        1 => '$chars characters',
        2 => '$charsNoSpaces chars (no spaces)',
        3 => '~$readMinutes min read ($words words)',
        _ =>
          '$words ${words == 1 ? 'word' : 'words'}  ·  $chars characters  ·  ~$readMinutes min read',
      };
      final statsLabel = hasSelection
          ? 'Selection: $selWords of $words ${words == 1 ? 'word' : 'words'} ($selChars chars, $selReadTime)  ·  Document: $words ${words == 1 ? 'word' : 'words'} ($chars characters, ~$readMinutes min read)'
          : activeMetricLabel;
      final cursorOffset = sel.isValid ? sel.extentOffset : _body.text.length;
      final lineCol = _textIndex.lineAndColumn(cursorOffset);
      final selectionSummary = hasSelection
          ? (() {
              final numLines = selectedIndex!.lines;
              final numChars = selectedIndex.source.length;
              return numLines > 1
                  ? '$numLines lines, $numChars selected'
                  : '$numChars selected';
            })()
          : null;
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
          const SingleActivator(LogicalKeyboardKey.keyG, control: true):
              _goToLine,
          const SingleActivator(
            LogicalKeyboardKey.keyC,
            control: true,
            shift: true,
          ): _copyEntireNoteMarkdown,
          const SingleActivator(
            LogicalKeyboardKey.keyH,
            control: true,
            shift: true,
          ): () =>
              _format(NoteFormatAction.highlight),
          const SingleActivator(
            LogicalKeyboardKey.keyF,
            control: true,
            shift: true,
          ): _insertFootnote,
          const SingleActivator(
            LogicalKeyboardKey.keyD,
            control: true,
            shift: true,
          ): _insertCurrentDate,
          const SingleActivator(LogicalKeyboardKey.slash, control: true): () =>
              showShortcutsCheatsheet(context),
          const SingleActivator(LogicalKeyboardKey.digit1, alt: true): () =>
              _setMode(NoteEditorMode.rich),
          const SingleActivator(LogicalKeyboardKey.digit2, alt: true): () =>
              _setMode(NoteEditorMode.write),
          if (wide)
            const SingleActivator(LogicalKeyboardKey.digit3, alt: true): () =>
                _setMode(NoteEditorMode.split),
          const SingleActivator(LogicalKeyboardKey.digit4, alt: true): () =>
              _setMode(NoteEditorMode.read),
          const SingleActivator(LogicalKeyboardKey.keyO, alt: true):
              _toggleOutlinePanel,
          if (!_isLatex)
            const SingleActivator(
              LogicalKeyboardKey.keyM,
              control: true,
              alt: true,
            ): () =>
                _addReview(false),
          const SingleActivator(LogicalKeyboardKey.keyH, alt: true):
              _showHistoryDialog,
          const SingleActivator(
            LogicalKeyboardKey.keyH,
            control: true,
            alt: true,
          ): _showHistoryDialog,
          const SingleActivator(LogicalKeyboardKey.keyB, alt: true): () {
            setState(() => _bionicReading = !_bionicReading);
            _recordView();
          },
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
              if (widget.showBreadcrumbs && !widget.isFocusMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: DocumentBreadcrumbs(
                    vaultName: widget.vaultName,
                    folderPath: widget.folderPath,
                    documentTitle: _title.text,
                    documentId: widget.noteId,
                    documentIcon: widget.icon,
                    isLatex: _isLatex,
                    allFolders: widget.allFolders,
                    allObjects: widget.allObjects,
                    folderLookup: widget.folderLookup,
                    onOpenObject: widget.onOpenObject,
                    onCreateNoteInFolder: widget.onCreateNoteInFolder,
                    onMoveToFolder: widget.onMoveToFolder,
                    onToggleBookmark: widget.onToggleBookmark,
                    isBookmarked: widget.isBookmarked,
                    onTogglePin: widget.onTogglePin,
                    isPinned: widget.isPinned,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
                child: Row(
                  children: [
                    if (widget.icon != null && widget.icon!.isNotEmpty)
                      Text(widget.icon!, style: const TextStyle(fontSize: 16))
                    else
                      Icon(
                        _isLatex
                            ? Icons.functions_rounded
                            : Icons.description_outlined,
                        size: 16,
                        color: _isLatex ? const Color(0xFF8B7CF6) : null,
                      ),
                    const SizedBox(width: 8),
                    if (constraints.maxWidth > 650)
                      Text(
                        _isLatex ? 'LaTeX' : 'Markdown',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: _isLatex ? const Color(0xFF8B7CF6) : null,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            if (widget.onContentWidthChanged != null)
                              PopupMenuButton<double>(
                                tooltip: 'Writing width',
                                icon: const Icon(
                                  Icons.width_normal_outlined,
                                  size: 18,
                                ),
                                onSelected: widget.onContentWidthChanged,
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 800,
                                    child: Text('Focused · 800 px'),
                                  ),
                                  PopupMenuItem(
                                    value: 1080,
                                    child: Text('Wide · 1080 px'),
                                  ),
                                  PopupMenuItem(
                                    value: 1600,
                                    child: Text('Spacious · 1600 px'),
                                  ),
                                  PopupMenuItem(
                                    value: 2000,
                                    child: Text('Full workspace · 2000 px'),
                                  ),
                                ],
                              ),
                            IconButton(
                              key: const ValueKey('note-outline-toggle'),
                              icon: Icon(
                                _showOutlinePanel
                                    ? Icons.toc_rounded
                                    : Icons.toc_outlined,
                                size: 18,
                                color: _showOutlinePanel
                                    ? const Color(0xFF8B7CF6)
                                    : null,
                              ),
                              tooltip: _showOutlinePanel
                                  ? 'Hide outline panel (Alt+O)'
                                  : 'Show outline panel (Alt+O)',
                              onPressed: _toggleOutlinePanel,
                            ),
                            if (!_isLatex)
                              IconButton(
                                tooltip: 'Publish document',
                                onPressed: () =>
                                    _insertCommand('Publish document'),
                                icon: const Icon(
                                  Icons.ios_share_outlined,
                                  size: 18,
                                ),
                              ),
                            if (!_isLatex)
                              PopupMenuButton<String>(
                                tooltip: 'Writing tools',
                                icon: const Icon(Icons.edit_note),
                                onSelected: _insertCommand,
                                itemBuilder: (_) => [
                                  for (final label in [
                                    'Publish document',
                                    'Page break',
                                    'Writing workspace',
                                    'Outline planning',
                                    'Manage footnotes',
                                    'Citations & bibliography',
                                    'Linked section uses',
                                    'Two columns',
                                    'Three columns',
                                    'Image and text',
                                    'Inline drawing',
                                    'Live object',
                                    'Convert selection',
                                    'Review replacements',
                                  ])
                                    PopupMenuItem(
                                      value: label,
                                      child: Text(label),
                                    ),
                                ],
                              ),
                            if (!_isLatex)
                              IconButton(
                                key: const ValueKey('note-review-toggle'),
                                tooltip: 'Document review',
                                onPressed: _openReviews,
                                icon: const Icon(
                                  Icons.rate_review_outlined,
                                  size: 18,
                                ),
                              ),
                            PopupMenuButton<NoteHeading>(
                              tooltip: 'Note outline',
                              icon: const Icon(
                                Icons.format_list_bulleted,
                                size: 18,
                              ),
                              onSelected: _jumpToHeading,
                              itemBuilder: (_) {
                                final headings = _headings;
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
                            PopupMenuButton<String>(
                              key: const ValueKey('note-font-family-menu'),
                              tooltip: 'Font: ${widget.fontFamily}',
                              icon: const Icon(
                                Icons.text_fields_rounded,
                                size: 18,
                              ),
                              initialValue: widget.fontFamily,
                              onSelected: (font) {
                                widget.onFontFamilyChanged?.call(font);
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'Segoe UI',
                                  child: Text('Segoe UI (Default Sans)'),
                                ),
                                PopupMenuItem(
                                  value: 'Times New Roman',
                                  child: Text(
                                    'Times New Roman (Serif)',
                                    style: TextStyle(
                                      fontFamily: 'Times New Roman',
                                    ),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'Georgia',
                                  child: Text(
                                    'Georgia (Serif)',
                                    style: TextStyle(fontFamily: 'Georgia'),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'Consolas',
                                  child: Text(
                                    'Consolas (Code)',
                                    style: TextStyle(fontFamily: 'monospace'),
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              key: const ValueKey('note-spellcheck-toggle'),
                              tooltip: widget.spellCheckEnabled
                                  ? 'Disable spell & grammar check'
                                  : 'Enable spell & grammar check',
                              onPressed: widget.onToggleSpellCheck,
                              icon: Icon(
                                widget.spellCheckEnabled
                                    ? Icons.spellcheck
                                    : Icons.spellcheck_outlined,
                                size: 18,
                                color: widget.spellCheckEnabled
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.5,
                                      ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Find in note · Ctrl+F',
                              onPressed: _openFind,
                              icon: const Icon(Icons.search_rounded, size: 18),
                            ),
                            if (widget.onToggleBacklinks != null)
                              IconButton(
                                key: const ValueKey('note-backlinks-toggle'),
                                tooltip: 'Backlinks & Local Graph',
                                onPressed: widget.onToggleBacklinks,
                                icon: const Icon(Icons.hub_outlined, size: 18),
                              ),
                            ActionChip(
                              key: const ValueKey('document-format-badge'),
                              tooltip:
                                  'Format: ${_isLatex ? "LaTeX Document" : "Markdown Note"}. Click to convert safely.',
                              avatar: Icon(
                                _isLatex
                                    ? Icons.functions_rounded
                                    : Icons.description_outlined,
                                size: 14,
                                color: _isLatex
                                    ? const Color(0xFF8B7CF6)
                                    : null,
                              ),
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _isLatex ? 'LaTeX' : 'Markdown',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _isLatex
                                          ? const Color(0xFF8B7CF6)
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.arrow_drop_down, size: 14),
                                ],
                              ),
                              onPressed: _handleFormatSwitch,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                            ),
                            if (_targetWords != null && _targetWords! > 0)
                              Tooltip(
                                message: words >= _targetWords!
                                    ? 'Word goal reached: $words / $_targetWords words'
                                    : 'Word goal: $words / $_targetWords words (${((words / _targetWords!) * 100).toInt()}%)',
                                child: InkWell(
                                  key: const ValueKey('note-word-goal-badge'),
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () => showWordGoalDialog(
                                    context,
                                    currentWords: words,
                                    targetWords: _targetWords,
                                    onTargetWordsChanged: (val) {
                                      setState(() => _targetWords = val);
                                      _recordView();
                                    },
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: words >= _targetWords!
                                          ? Colors.green.withValues(alpha: 0.15)
                                          : const Color(
                                              0xFF8B7CF6,
                                            ).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: words >= _targetWords!
                                            ? Colors.green.withValues(
                                                alpha: 0.4,
                                              )
                                            : const Color(
                                                0xFF8B7CF6,
                                              ).withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        WordGoalProgressRing(
                                          progress: words / _targetWords!,
                                          size: 13,
                                          strokeWidth: 2,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          '$words/$_targetWords',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: words >= _targetWords!
                                                ? Colors.green
                                                : const Color(0xFF8B7CF6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            if (_isLatex) ...[
                              if (mode != NoteEditorMode.rich)
                                IconButton(
                                  tooltip: 'Math Symbol Palette',
                                  icon: const Icon(
                                    Icons.functions_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    showDialog<void>(
                                      context: context,
                                      builder: (_) => LatexMathPalette(
                                        onInsert: (source) {
                                          if (_mode == NoteEditorMode.rich) {
                                            _richLatexKey.currentState
                                                ?.insertMath(source);
                                          } else {
                                            _insertSource(source);
                                          }
                                        },
                                      ),
                                    );
                                  },
                                ),
                              if (mode != NoteEditorMode.rich)
                                IconButton(
                                  tooltip: 'Matrix & Cases Grid Builder',
                                  icon: const Icon(
                                    Icons.grid_on_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () async {
                                    final res = await showMathGridEditor(
                                      context,
                                    );
                                    if (res != null) {
                                      if (_mode == NoteEditorMode.rich) {
                                        _richLatexKey.currentState?.insertMath(
                                          res,
                                        );
                                      } else {
                                        _insertSource(res);
                                      }
                                    }
                                  },
                                ),
                              IconButton(
                                tooltip: 'LaTeX Document Settings & Outline',
                                isSelected: _showLatexInspector,
                                icon: const Icon(Icons.tune_rounded, size: 18),
                                onPressed: () => setState(
                                  () => _showLatexInspector =
                                      !_showLatexInspector,
                                ),
                              ),
                            ],
                            IconButton(
                              tooltip: 'Export as PDF',
                              icon: const Icon(
                                Icons.picture_as_pdf_outlined,
                                size: 18,
                              ),
                              onPressed: () => PdfExportService.exportDocument(
                                context: context,
                                title: widget.title,
                                body: _body.text,
                                isLatex: _isLatex,
                              ),
                            ),
                            if (widget.controller != null && !_isLatex)
                              IconButton(
                                tooltip: 'Make study card from selection',
                                icon: const Icon(
                                  Icons.style_outlined,
                                  size: 18,
                                ),
                                onPressed:
                                    widget.controller!.repository.readOnly
                                    ? null
                                    : () async {
                                        final c = widget.controller!;
                                        final selection =
                                            _mode == NoteEditorMode.rich
                                            ? _richKey
                                                      .currentState
                                                      ?.currentDocumentSelection ??
                                                  _body.selection
                                            : _body.selection;
                                        final text = _body.text;
                                        final passage =
                                            selection.isValid &&
                                                !selection.isCollapsed
                                            ? selection.textInside(text)
                                            : text;
                                        await c.flush(widget.noteId);
                                        if (!context.mounted) return;
                                        final source = c.find(widget.noteId);
                                        if (source == null ||
                                            source.body != text ||
                                            c.dirty.contains(source.id)) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Save or refresh the note before making a card.',
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        await showStudyCardEditor(
                                          context,
                                          c,
                                          source: source,
                                          passage: passage,
                                        );
                                      },
                              ),
                            PopupMenuButton<String>(
                              key: const ValueKey('note-copy-as-menu'),
                              tooltip: 'Copy as...',
                              icon: const Icon(
                                Icons.copy_all_outlined,
                                size: 18,
                              ),
                              onSelected: (action) async {
                                if (action == 'block_reference' ||
                                    action == 'place_block') {
                                  await _referenceCurrentBlock(
                                    place: action == 'place_block',
                                  );
                                  return;
                                }
                                if (action == 'markdown') {
                                  _copyEntireNoteMarkdown();
                                }
                                if (action == 'plain') _copyAsPlainText();
                                if (action == 'html') _copyAsHtml();
                                if (action == 'stats') {
                                  final stats = DocumentStats.compute(
                                    _body.text,
                                    isLatex: _isLatex,
                                  );
                                  final summary = stats.formatSummary(
                                    title: _title.text,
                                  );
                                  Clipboard.setData(
                                    ClipboardData(text: summary),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Copied document analytics to clipboard',
                                      ),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                                if (action == 'wikilink') {
                                  final title = _title.text.isEmpty
                                      ? 'Untitled'
                                      : _title.text;
                                  final link = '[[$title]]';
                                  Clipboard.setData(ClipboardData(text: link));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Copied wiki-link $link to clipboard',
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                                if (action == 'path') {
                                  final folder = widget.folderPath.isEmpty
                                      ? 'Notes'
                                      : widget.folderPath;
                                  final title = _title.text.isEmpty
                                      ? 'Untitled'
                                      : _title.text;
                                  final path = '$folder/$title.md';
                                  Clipboard.setData(ClipboardData(text: path));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Copied path "$path" to clipboard',
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                                if (action == 'goal') {
                                  showWordGoalDialog(
                                    context,
                                    currentWords: words,
                                    targetWords: _targetWords,
                                    onTargetWordsChanged: (val) {
                                      setState(() => _targetWords = val);
                                      _recordView();
                                    },
                                  );
                                }
                                if (action == 'history') {
                                  _showHistoryDialog();
                                }
                                if (action == 'insert_template') {
                                  final template =
                                      await NoteTemplateDialog.show(
                                        context,
                                        insertMode: true,
                                      );
                                  if (template != null) {
                                    _insertSource(template.body);
                                  }
                                }
                                if (action == 'bionic') {
                                  setState(
                                    () => _bionicReading = !_bionicReading,
                                  );
                                  _recordView();
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'markdown',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.description_outlined,
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Markdown'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'goal',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.flag_outlined, size: 16),
                                      SizedBox(width: 8),
                                      Text('Word Goal…'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'plain',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.text_snippet_outlined,
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Plain Text'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'html',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.code_rounded, size: 16),
                                      SizedBox(width: 8),
                                      Text('HTML'),
                                    ],
                                  ),
                                ),
                                if (widget.controller != null && !_isLatex)
                                  const PopupMenuItem(
                                    value: 'block_reference',
                                    child: Text('Copy current block reference'),
                                  ),
                                if (widget.controller != null && !_isLatex)
                                  const PopupMenuItem(
                                    value: 'place_block',
                                    child: Text(
                                      'Place current block on Canvas…',
                                    ),
                                  ),
                                PopupMenuItem(
                                  value: 'wikilink',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.link_rounded, size: 16),
                                      SizedBox(width: 8),
                                      Text('Wiki-Link'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'path',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.folder_open_outlined,
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Relative Path'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'stats',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.analytics_outlined, size: 16),
                                      SizedBox(width: 8),
                                      Text('Stats'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'history',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.history_rounded, size: 16),
                                      SizedBox(width: 8),
                                      Flexible(
                                        child: Text('Revision History…'),
                                      ),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'insert_template',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.dashboard_customize_outlined,
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Flexible(child: Text('Insert Template…')),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'bionic',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.auto_stories_outlined,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          _bionicReading
                                              ? 'Disable Bionic Reading'
                                              : 'Bionic Speed Reading',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
                                  _setMode(value);
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
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 48,
                                ),
                                child: OrbitModeControl<NoteEditorMode>(
                                  values: {
                                    NoteEditorMode.rich: 'Rich',
                                    NoteEditorMode.write: 'Source',
                                    if (wide) NoteEditorMode.split: 'Split',
                                    NoteEditorMode.read: 'Read',
                                  },
                                  value: mode,
                                  onChanged: (value) {
                                    _setMode(value);
                                  },
                                ),
                              ),
                            if (widget.onTogglePin != null)
                              IconButton(
                                key: const ValueKey('note-pin-toggle'),
                                tooltip: widget.isPinned
                                    ? 'Unpin tab'
                                    : 'Pin tab',
                                onPressed: widget.onTogglePin,
                                icon: Icon(
                                  widget.isPinned
                                      ? Icons.push_pin_rounded
                                      : Icons.push_pin_outlined,
                                  size: 18,
                                  color: widget.isPinned
                                      ? const Color(0xFF8B7CF6)
                                      : null,
                                ),
                              ),
                            if (widget.onToggleBookmark != null)
                              IconButton(
                                key: const ValueKey('note-bookmark-toggle'),
                                tooltip: widget.isBookmarked
                                    ? 'Remove from bookmarks (Ctrl+Shift+D)'
                                    : 'Bookmark note (Ctrl+Shift+D)',
                                onPressed: widget.onToggleBookmark,
                                icon: Icon(
                                  widget.isBookmarked
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_border_rounded,
                                  size: 18,
                                  color: widget.isBookmarked
                                      ? const Color(0xFFF59E0B)
                                      : null,
                                ),
                              ),
                            if (widget.onToggleFocusMode != null)
                              IconButton(
                                key: const ValueKey('note-focus-mode-toggle'),
                                tooltip: widget.isFocusMode
                                    ? 'Exit focus mode (F11)'
                                    : 'Focus mode (F11)',
                                onPressed: widget.onToggleFocusMode,
                                icon: Icon(
                                  widget.isFocusMode
                                      ? Icons.fullscreen_exit_rounded
                                      : Icons.center_focus_strong_outlined,
                                  size: 18,
                                  color: widget.isFocusMode
                                      ? const Color(0xFF8B7CF6)
                                      : null,
                                ),
                              ),
                            IconButton(
                              key: const ValueKey('note-shortcuts-button'),
                              tooltip: 'Keyboard shortcuts · Ctrl+/',
                              onPressed: () => showShortcutsCheatsheet(context),
                              icon: const Icon(
                                Icons.keyboard_outlined,
                                size: 18,
                              ),
                            ),
                            IconButton(
                              key: const ValueKey('note-history-button'),
                              tooltip: 'Document revision history (Alt+H)',
                              onPressed: _showHistoryDialog,
                              icon: const Icon(Icons.history_rounded, size: 18),
                            ),
                            IconButton(
                              key: const ValueKey('note-bionic-toggle'),
                              tooltip: _bionicReading
                                  ? 'Disable bionic reading (Alt+B)'
                                  : 'Bionic speed reading (Alt+B)',
                              onPressed: () {
                                setState(
                                  () => _bionicReading = !_bionicReading,
                                );
                                _recordView();
                              },
                              icon: Icon(
                                _bionicReading
                                    ? Icons.auto_stories_rounded
                                    : Icons.auto_stories_outlined,
                                size: 18,
                                color: _bionicReading
                                    ? const Color(0xFF8B7CF6)
                                    : null,
                              ),
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
                    ),
                  ],
                ),
              ),
              if (!_isLatex) _buildCoverBanner(),
              if (!_isLatex && (_outlineOnly || _focusedSectionKey != null))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    children: [
                      Text(
                        _outlineOnly
                            ? 'Outline planning'
                            : focusedSection == null
                            ? 'Focused section no longer resolves'
                            : 'Focusing: ${focusedSection.title}',
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _outlineOnly = false;
                            _focusedSectionKey = null;
                          });
                          _recordView();
                        },
                        icon: const Icon(Icons.unfold_more),
                        label: const Text('Show full document'),
                      ),
                    ],
                  ),
                ),
              if (_isLatex && widget.pdfSource != null) _buildPdfSourceBanner(),
              if (!_isLatex)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: widget.contentWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPageHeader(),
                          if (widget.pdfSource != null) _buildPdfSourceBanner(),
                          TextField(
                            key: const ValueKey('note-title'),
                            focusNode: _titleFocus,
                            controller: _title,
                            contextMenuBuilder: (context, state) =>
                                _buildEditorContextMenu(
                                  context,
                                  state,
                                  _title,
                                  widget.onTitleChanged,
                                ),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: NoteTypography(
                                fontFamily: widget.fontFamily,
                              ).headingWeight,
                              fontFamily: widget.fontFamily,
                              fontFamilyFallback: NoteTypography(
                                fontFamily: widget.fontFamily,
                              ).fallbacks,
                              letterSpacing: 0,
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
              if (!_isLatex && mode != NoteEditorMode.read)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 8,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: widget.contentWidth,
                      ),
                      child: NoteFormatToolbar(
                        formatStates: _mode == NoteEditorMode.rich
                            ? _richKey.currentState?.formatStates ?? const {}
                            : const {},
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
                          minLines: 1,
                          maxLines: 3,
                          keyboardType: TextInputType.multiline,
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
                        onPressed: _findCount > 0 ? _reviewReplacements : null,
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
              AnimatedOpacity(
                opacity: _readingProgress > 0.01 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: SizedBox(
                  height: 2.5,
                  child: LinearProgressIndicator(
                    key: const ValueKey('note-reading-progress-bar'),
                    value: _readingProgress,
                    minHeight: 2.5,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isLatex
                          ? const Color(0xFF8B7CF6)
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    // Inline equation fields scroll horizontally and must not
                    // reset the document's reading progress. Notifications can
                    // also arrive during layout, so update chrome after it.
                    if (notification.metrics.axis != Axis.vertical) {
                      return false;
                    }
                    final metrics = notification.metrics;
                    final progress = metrics.maxScrollExtent > 0
                        ? (metrics.pixels / metrics.maxScrollExtent).clamp(
                            0.0,
                            1.0,
                          )
                        : 0.0;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted &&
                          (progress - _readingProgress).abs() > 0.005) {
                        setState(() => _readingProgress = progress);
                      }
                    });
                    return false;
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: OrbitContentTransition(
                          identity: mode,
                          child: _outlineOnly && !_isLatex
                              ? _writingWorkspace()
                              : mode == NoteEditorMode.split
                              ? Row(
                                  children: [
                                    SizedBox(
                                      width:
                                          (constraints.maxWidth - 6) *
                                          _splitRatio,
                                      child: _source(),
                                    ),
                                    MouseRegion(
                                      cursor: SystemMouseCursors.resizeColumn,
                                      child: GestureDetector(
                                        key: const ValueKey(
                                          'note-split-divider',
                                        ),
                                        onDoubleTap: () {
                                          setState(() => _splitRatio = .5);
                                          _recordView();
                                        },
                                        onHorizontalDragUpdate: (event) {
                                          setState(
                                            () => _splitRatio =
                                                (_splitRatio +
                                                        event.delta.dx /
                                                            (constraints
                                                                    .maxWidth -
                                                                6))
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
                                    Expanded(
                                      child: _isLatex
                                          ? LatexPreview(
                                              latex: _body.text,
                                              contentWidth: widget.contentWidth,
                                              fontSize: widget.fontSize,
                                              scrollController: _previewScroll,
                                              imageBuilder: widget.imageBuilder,
                                            )
                                          : _preview(),
                                    ),
                                  ],
                                )
                              : mode == NoteEditorMode.read
                              ? (_isLatex
                                    ? LatexPreview(
                                        latex: _body.text,
                                        contentWidth: widget.contentWidth,
                                        fontSize: widget.fontSize,
                                        scrollController: _previewScroll,
                                        imageBuilder: widget.imageBuilder,
                                      )
                                    : _preview())
                              : mode == NoteEditorMode.rich
                              ? (_isLatex
                                    ? RichLatexEditor(
                                        key: _richLatexKey,
                                        onUndo: _undoDocument,
                                        onRedo: _redoDocument,
                                        body: _body.text,
                                        onChanged: (v) {
                                          _body.value = TextEditingValue(
                                            text: v,
                                            selection: TextSelection.collapsed(
                                              offset: _body
                                                  .selection
                                                  .extentOffset
                                                  .clamp(0, v.length),
                                            ),
                                          );
                                          widget.onBodyChanged(v);
                                          setState(() {});
                                        },
                                        contentWidth: widget.contentWidth,
                                        fontSize: widget.fontSize,
                                        scrollController: _sourceScroll,
                                        imageBuilder: widget.imageBuilder,
                                        onInsertAttachment:
                                            widget.onInsertAttachment,
                                      )
                                    : RichMarkdownEditor(
                                        key: _richKey,
                                        focusedStart: focusedSection?.start,
                                        focusedEnd: focusedSection?.end,
                                        onOpenFootnote: _editFootnote,
                                        noteId: widget.noteId,
                                        objectBlockBuilder: _objectBlock,
                                        onCompositionCommand:
                                            _compositionCommand,
                                        attachmentRevision:
                                            widget
                                                .controller
                                                ?.attachmentRevision ??
                                            0,
                                        fontFamily: widget.fontFamily,
                                        lineHeight: widget.lineHeight,
                                        spellCheckEnabled:
                                            widget.spellCheckEnabled,
                                        userDictionary: widget.userDictionary,
                                        onAddToUserDictionary:
                                            widget.onAddToUserDictionary,
                                        body: _body.text,
                                        fontSize: widget.fontSize,
                                        contentWidth: widget.contentWidth,
                                        initialState: _richState,
                                        onState: (v) {
                                          _richState = v;
                                          if (_mode == NoteEditorMode.rich) {
                                            final selMap = v['selection'];
                                            if (selMap is Map) {
                                              final b = selMap['base'];
                                              final e = selMap['extent'];
                                              if (b is int && e is int) {
                                                final newSel = TextSelection(
                                                  baseOffset: b.clamp(
                                                    0,
                                                    _body.text.length,
                                                  ),
                                                  extentOffset: e.clamp(
                                                    0,
                                                    _body.text.length,
                                                  ),
                                                );
                                                if (_body.selection != newSel) {
                                                  _body.selection = newSel;
                                                }
                                              }
                                            } else if (v['docOffset'] is int) {
                                              final docOffset =
                                                  (v['docOffset'] as int).clamp(
                                                    0,
                                                    _body.text.length,
                                                  );
                                              final newSel =
                                                  TextSelection.collapsed(
                                                    offset: docOffset,
                                                  );
                                              if (_body.selection != newSel) {
                                                _body.selection = newSel;
                                              }
                                            }
                                          }
                                          _recordView();
                                        },
                                        onChanged: (v) {
                                          _body.value = TextEditingValue(
                                            text: v,
                                            selection: TextSelection.collapsed(
                                              offset: _body
                                                  .selection
                                                  .extentOffset
                                                  .clamp(0, v.length),
                                            ),
                                          );
                                          widget.onBodyChanged(v);
                                          setState(() {});
                                        },
                                        onUndo: _undoDocument,
                                        onRedo: _redoDocument,
                                        linkTargets: widget.linkTargets,
                                        linkBindings: widget.linkBindings,
                                        allObjects: widget.allObjects,
                                        onInsertLinkedSection: () =>
                                            showLinkedSectionPicker(
                                              context,
                                              widget.allObjects,
                                              widget.noteId,
                                              widget.controller,
                                            ),
                                        onOpenLink: _openLink,
                                        onOpenInNewTab: _openLinkInNewTab,
                                        onOpenToSide: _openLinkToSide,
                                        onShowBacklinks: _showBacklinksFor,
                                        onRevealInExplorer: _revealInExplorer,
                                        imageBuilder: widget.imageBuilder,
                                        resolveClipboardImage:
                                            widget.resolveClipboardImage,
                                        onInsertAttachment:
                                            widget.onInsertAttachment,
                                        onPasteImage: widget.onPasteImage,
                                        onCreateTask: widget.onCreateTask,
                                        onCopyBlockReference:
                                            widget.controller == null
                                            ? null
                                            : (offset) =>
                                                  _referenceCurrentBlock(
                                                    place: false,
                                                    sourceOffset: offset,
                                                  ),
                                      ))
                              : _source(),
                        ),
                      ),
                      if (_showReviewPanel && _reviewDockAvailable && !_isLatex)
                        SizedBox(
                          width: 360,
                          child: DocumentReviewPanel(
                            source: _body.text,
                            onAction: _reviewAction,
                            onJump: _jumpReview,
                            onAdd: _addReview,
                            onClose: () =>
                                setState(() => _showReviewPanel = false),
                          ),
                        ),
                      if (_showOutlinePanel)
                        OrbitEntrance(
                          spatial: true,
                          offset: const Offset(6, 0),
                          child: NoteOutlinePanel(
                            headings: _headings,
                            onHeadingSelected: _jumpToHeading,
                            onClose: () =>
                                setState(() => _showOutlinePanel = false),
                            isDocked: true,
                          ),
                        ),
                      if (_showLatexInspector && _isLatex)
                        OrbitEntrance(
                          spatial: true,
                          offset: const Offset(6, 0),
                          child: LatexInspector(
                            doc: LatexDocument.fromLatex(_body.text),
                            onDocChanged: (d) {
                              final next = d.toLatex();
                              _body.value = TextEditingValue(
                                text: next,
                                selection: TextSelection.collapsed(
                                  offset: _body.selection.extentOffset.clamp(
                                    0,
                                    next.length,
                                  ),
                                ),
                              );
                              widget.onBodyChanged(next);
                              setState(() {});
                            },
                            onClose: () =>
                                setState(() => _showLatexInspector = false),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () => showDocumentStatsDialog(
                              context,
                              title: widget.title,
                              text: _body.text,
                              selectedText: hasSelection
                                  ? sel.textInside(_body.text)
                                  : null,
                              isLatex: _isLatex,
                              targetWords: _targetWords,
                              onTargetWordsChanged: (val) {
                                setState(() => _targetWords = val);
                                _recordView();
                              },
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Tooltip(
                                message: 'Full document analytics',
                                child: Icon(
                                  Icons.analytics_outlined,
                                  size: 13,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (_targetWords != null && _targetWords! > 0) ...[
                            InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: () => showWordGoalDialog(
                                context,
                                currentWords: words,
                                targetWords: _targetWords,
                                onTargetWordsChanged: (val) {
                                  setState(() => _targetWords = val);
                                  _recordView();
                                },
                              ),
                              child: Builder(
                                builder: (context) {
                                  final colors = OrbitColors.of(context);
                                  final isGoalMet = words >= _targetWords!;
                                  return Container(
                                    key: const ValueKey(
                                      'footer-target-goal-badge',
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isGoalMet
                                          ? colors.success.withValues(
                                              alpha: 0.15,
                                            )
                                          : colors.accent.withValues(
                                              alpha: 0.15,
                                            ),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isGoalMet
                                            ? colors.success.withValues(
                                                alpha: 0.4,
                                              )
                                            : colors.accent.withValues(
                                                alpha: 0.4,
                                              ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        WordGoalProgressRing(
                                          progress: words / _targetWords!,
                                          size: 11,
                                          strokeWidth: 1.8,
                                          color: colors.accent,
                                          completedColor: colors.success,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          isGoalMet
                                              ? '✓ Goal reached ($words/$_targetWords)'
                                              : '$words/$_targetWords words (${((words / _targetWords!) * 100).toInt()}%)',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isGoalMet
                                                ? colors.success
                                                : colors.accent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          InkWell(
                            key: const ValueKey('document-stats-toggle'),
                            borderRadius: BorderRadius.circular(4),
                            onTap: () {
                              setState(() {
                                _footerMetricMode = (_footerMetricMode + 1) % 4;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Tooltip(
                                message: 'Cycle metric mode',
                                child: Icon(
                                  Icons.swap_horiz_rounded,
                                  size: 13,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: () => showDocumentStatsDialog(
                                context,
                                title: widget.title,
                                text: _body.text,
                                selectedText: hasSelection
                                    ? sel.textInside(_body.text)
                                    : null,
                                isLatex: _isLatex,
                                targetWords: _targetWords,
                                onTargetWordsChanged: (val) {
                                  setState(() => _targetWords = val);
                                  _recordView();
                                },
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                child: Tooltip(
                                  message: hasSelection
                                      ? 'Selection: $selWords words ($selReadTime) · Document: $words words, $chars characters, ~$readMinutes min read time (200 wpm) · Click for full report'
                                      : 'Document metrics: $words words, $chars characters, ~$readMinutes min read time (200 wpm) · Click for full report',
                                  child: Text(
                                    statsLabel,
                                    key: const ValueKey('document-stats'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      key: const ValueKey('note-line-col-indicator'),
                      borderRadius: BorderRadius.circular(6),
                      onTap: _goToLine,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Tooltip(
                          message: 'Go to Line (Ctrl+G)',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.pin_drop_outlined,
                                size: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                selectionSummary != null
                                    ? 'Ln ${lineCol.line}, Col ${lineCol.column} ($selectionSummary)'
                                    : 'Ln ${lineCol.line}, Col ${lineCol.column}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
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
                minLines: 1,
                maxLines: 3,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.done,
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
                onEditingComplete: () {},
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
            contextMenuBuilder: (context, state) =>
                _buildEditorContextMenu(context, state, _body, (v) {
                  widget.onBodyChanged(v);
                  setState(() {});
                }),
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            keyboardType: TextInputType.multiline,
            style: NoteTypography(
              fontFamily: widget.fontFamily,
              fontSize: widget.fontSize,
              lineHeight: widget.lineHeight,
            ).body(),
            decoration: InputDecoration(
              hintText:
                  'Start writing. Your ideas belong here.\n\nUse [[ to write a link, or Ctrl+K to choose an object.',
              hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: widget.lineHeight,
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

  ReadSearchRequest? _readSearchRequest() {
    if (_mode != NoteEditorMode.read || !_showFind || _find.text.isEmpty) {
      return null;
    }
    final matches = _searchIndex.matches(
      _find.text,
      matchCase: _matchCase,
      wholeWord: _matchWholeWord,
    );
    final scoped = _computeMatches().map((m) => (m.start, m.end)).toSet();
    return ReadSearchRequest(
      query: _find.text,
      expectedCount: matches.length,
      expectedSegments: [
        for (final match in matches) _searchIndex.segmentText(match),
      ],
      visibleIndices: {
        for (var i = 0; i < matches.length; i++)
          if (scoped.contains((matches[i].start, matches[i].end))) i,
      },
      selectedIndex: matches.indexWhere(
        (m) => m.start == _body.selection.start && m.end == _body.selection.end,
      ),
      matchCase: _matchCase,
      wholeWord: _matchWholeWord,
    );
  }

  Widget _preview() {
    final theme = Theme.of(context);
    final readingSource = _body.text.contains('<!-- orbit:')
        ? DocumentCitations(_body.text).publication(refreshContent: false)
        : _body.text;
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
                : ReadSearchOverlay(
                    key: _readSearch,
                    request: _readSearchRequest(),
                    child: MarkdownBody(
                      inlineSyntaxes: [
                        HighlightInlineSyntax(),
                        MarkTagInlineSyntax(),
                        UnderlineInlineSyntax(),
                        InsInlineSyntax(),
                        MathInlineSyntax(),
                      ],
                      blockSyntaxes: const [
                        NoteCompositionSyntax(),
                        LinkedSectionSyntax(),
                        MediaSectionSyntax(),
                        AlignmentBlockSyntax(),
                        CalloutBlockSyntax(),
                        MathBlockSyntax(),
                      ],
                      builders: {
                        'orbit-composition': NoteCompositionBuilder(
                          typography: NoteTypography(
                            fontFamily: widget.fontFamily,
                            fontSize: widget.fontSize,
                            lineHeight: widget.lineHeight,
                          ),
                          onOpen: _openLink,
                          objectBuilder: _objectBlock,
                          imageBuilder: (uri, title, alt) =>
                              widget.imageBuilder?.call(
                                context,
                                uri.toString(),
                              ) ??
                              _imageFallback(alt ?? 'Image'),
                          blockSyntaxes: const [
                            NoteCompositionSyntax(),
                            MediaSectionSyntax(),
                            LinkedSectionSyntax(),
                            CalloutBlockSyntax(),
                            MathBlockSyntax(),
                          ],
                          builders: {
                            'orbit-composition': NoteCompositionBuilder(
                              typography: NoteTypography(
                                fontFamily: widget.fontFamily,
                                fontSize: widget.fontSize,
                                lineHeight: widget.lineHeight,
                              ),
                              onOpen: _openLink,
                              objectBuilder: _objectBlock,
                            ),
                            'orbit-media': MediaSectionBuilder(
                              typography: NoteTypography(
                                fontFamily: widget.fontFamily,
                                fontSize: widget.fontSize,
                                lineHeight: widget.lineHeight,
                              ),
                              onTapLink: (_, href, _) => _openLink(href),
                              imageBuilder: (uri, title, alt) =>
                                  widget.imageBuilder?.call(
                                    context,
                                    uri.toString(),
                                  ) ??
                                  _imageFallback(alt ?? 'Image'),
                            ),
                            'orbit-section': LinkedSectionBuilder(
                              objects: widget.allObjects,
                              ancestors: {widget.noteId},
                              onOpen: _openLink,
                              imageBuilder: widget.imageBuilder,
                              typography: NoteTypography(
                                fontFamily: widget.fontFamily,
                                fontSize: widget.fontSize,
                                lineHeight: widget.lineHeight,
                              ),
                            ),
                          },
                        ),
                        'orbit-section': LinkedSectionBuilder(
                          objects: widget.allObjects,
                          ancestors: {widget.noteId},
                          onOpen: _openLink,
                          imageBuilder: widget.imageBuilder,
                          typography: NoteTypography(
                            fontFamily: widget.fontFamily,
                            fontSize: widget.fontSize,
                            lineHeight: widget.lineHeight,
                          ),
                        ),
                        'orbit-media': MediaSectionBuilder(
                          typography: NoteTypography(
                            fontFamily: widget.fontFamily,
                            fontSize: widget.fontSize,
                            lineHeight: widget.lineHeight,
                          ),
                          onTapLink: (text, href, title) => _openLink(href),
                          imageBuilder: (uri, title, alt) =>
                              widget.imageBuilder?.call(
                                context,
                                uri.toString(),
                              ) ??
                              _imageFallback(alt ?? title ?? uri.toString()),
                        ),
                        'orbit-aligned': AlignmentElementBuilder(
                          fontSize: widget.fontSize,
                          fontFamily: widget.fontFamily,
                          lineHeight: widget.lineHeight,
                          onTapLink: (text, href, title) => _openLink(href),
                          imageBuilder: (uri, title, alt) =>
                              widget.imageBuilder?.call(
                                context,
                                uri.toString(),
                              ) ??
                              _imageFallback(alt ?? title ?? uri.toString()),
                          onOpenAttachment: (raw) => _openLink(raw),
                        ),
                        'callout': CalloutElementBuilder(
                          typography: NoteTypography(
                            fontFamily: widget.fontFamily,
                            fontSize: widget.fontSize,
                            lineHeight: widget.lineHeight,
                          ),
                          onTapLink: (text, href, title) => _openLink(href),
                          imageBuilder: (uri, title, alt) =>
                              widget.imageBuilder?.call(
                                context,
                                uri.toString(),
                              ) ??
                              _imageFallback(alt ?? title ?? uri.toString()),
                          onOpenAttachment: (raw) => _openLink(raw),
                        ),
                        'mark': HighlightElementBuilder(),
                        'u': UnderlineElementBuilder(),
                        'ins': UnderlineElementBuilder(),
                        'math-inline': MathElementBuilder(),
                        'math-block': MathElementBuilder(display: true),
                        'pre': CodeElementBuilder(
                          controller: widget.controller,
                          noteId: widget.noteId,
                        ),
                      },
                      key: const ValueKey('note-preview'),
                      data: _bionicReading
                          ? BionicReading.toBionicMarkdown(
                              wikiLinksToMarkdown(
                                readingSource,
                                widget.linkTargets,
                                bindings: widget.linkBindings,
                              ),
                            )
                          : wikiLinksToMarkdown(
                              readingSource,
                              widget.linkTargets,
                              bindings: widget.linkBindings,
                            ),
                      selectable: true,
                      onTapLink: (text, href, title) => _openLink(href),
                      imageBuilder: (uri, title, alt) => ReadAttachmentPreview(
                        uri: uri,
                        description: alt ?? title,
                        onOpen: (raw) => _openLink(raw),
                        child:
                            widget.imageBuilder?.call(
                              context,
                              uri.toString(),
                            ) ??
                            _imageFallback(alt ?? title ?? ''),
                      ),
                      styleSheet:
                          NoteTypography(
                                fontFamily: widget.fontFamily,
                                fontSize: widget.fontSize,
                                lineHeight: widget.lineHeight,
                              )
                              .markdown(theme)
                              .copyWith(
                                a: TextStyle(
                                  color: theme.colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                  decorationColor: theme.colorScheme.primary
                                      .withValues(alpha: 0.4),
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
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.6),
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
                                tableBorder: TableBorder.all(
                                  color: theme.dividerColor,
                                ),
                                tableCellsPadding: const EdgeInsets.all(10),
                                blockSpacing: 16,
                              ),
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
