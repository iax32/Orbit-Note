import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/orbit_components.dart';
import '../../../app/orbit_theme.dart';
import '../rich/structured_math_editor.dart';
import '../rich/note_math.dart';
import 'latex_prose_controller.dart';
import '../rich/math_grid_editor.dart';
import 'latex_document.dart';
import 'latex_math_palette.dart';
import '../../math/math_lab_dialog.dart';

/// The Visual Academic Editor for LaTeX documents.
class RichLatexEditor extends StatefulWidget {
  const RichLatexEditor({
    super.key,
    required this.body,
    required this.onChanged,
    required this.contentWidth,
    required this.fontSize,
    this.scrollController,
    this.onUndo,
    this.onRedo,
    this.onMathLab,
    this.imageBuilder,
    this.onInsertAttachment,
  });

  final VoidCallback? onUndo, onRedo, onMathLab;
  final String body;
  final ValueChanged<String> onChanged;
  final double contentWidth;
  final double fontSize;
  final ScrollController? scrollController;
  final Widget Function(BuildContext, String)? imageBuilder;
  final Future<String?> Function()? onInsertAttachment;

  @override
  State<RichLatexEditor> createState() => RichLatexEditorState();
}

class RichLatexEditorState extends State<RichLatexEditor> {
  late LatexDocument _doc;
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _dateController;
  late TextEditingController _abstractController;
  int? _activeIndex;
  final _focusNodes = <int, FocusNode>{};
  final _locationKeys = <int, GlobalKey>{};

  void restoreEditingFocus() {
    if (!mounted) return;
    // Preamble/raw blocks can precede the first visible prose field.
    final node = _focusNodes[_activeIndex] ?? _focusNodes.values.firstOrNull;
    node?.requestFocus();
  }

  void jumpTo(int sourceOffset) {
    var offset = 0;
    for (var index = 0; index < _doc.blocks.length; index++) {
      final block = _doc.blocks[index];
      final end = offset + block.source.length;
      if (sourceOffset < end || index == _doc.blocks.length - 1) {
        setState(() => _activeIndex = index);
        final context = _locationKeys[index]?.currentContext;
        if (context != null) Scrollable.ensureVisible(context, alignment: .25);
        _focusNodes[index]?.requestFocus();
        return;
      }
      offset = end;
    }
  }

  final _equationKeys = <int, GlobalKey<EditableMathExpressionState>>{};
  bool _metadata = false;
  final _sourceBlocks = <LatexBlock>{};
  final Map<int, TextEditingController> _blockControllers = {};

  @override
  void initState() {
    super.initState();
    _doc = LatexDocument.fromLatex(widget.body);
    _titleController = TextEditingController(text: _doc.title);
    _authorController = TextEditingController(text: _doc.author);
    _dateController = TextEditingController(text: _doc.date);
    _abstractController = TextEditingController(text: _doc.abstractText);
    _initBlockControllers();
  }

  @override
  void didUpdateWidget(RichLatexEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.body != oldWidget.body) {
      final currentSerialized = _doc.toLatex();
      if (widget.body.trim() != currentSerialized.trim()) {
        setState(() {
          _doc = LatexDocument.fromLatex(widget.body);
          if (_activeIndex != null && _activeIndex! >= _doc.blocks.length) {
            _activeIndex = null;
          }
          _titleController.text = _doc.title;
          _authorController.text = _doc.author;
          _dateController.text = _doc.date;
          _abstractController.text = _doc.abstractText;
          _disposeBlockControllers();
          _initBlockControllers();
        });
      }
    }
  }

  void _initBlockControllers() {
    for (var i = 0; i < _doc.blocks.length; i++) {
      final block = _doc.blocks[i];
      _blockControllers[i] = _isProse(block)
          ? LatexProseController(block.rawContent)
          : TextEditingController(text: block.rawContent);
    }
  }

  void _disposeBlockControllers() {
    for (final c in _blockControllers.values) {
      c.dispose();
    }
    _blockControllers.clear();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _dateController.dispose();
    _abstractController.dispose();
    _disposeBlockControllers();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _notifyChanged() {
    final newLatex = _doc.toLatex();
    widget.onChanged(newLatex);
  }

  void _updateBlock(int index, LatexBlock newBlock) {
    setState(() {
      final nextBlocks = List<LatexBlock>.from(_doc.blocks);
      nextBlocks[index] = newBlock;
      _doc = _doc.copyWith(blocks: nextBlocks);
      final controller = _blockControllers[index];
      if (controller is LatexProseController) {
        controller.setSource(newBlock.rawContent);
      } else if (controller != null && controller.text != newBlock.rawContent) {
        controller.text = newBlock.rawContent;
      }
      _notifyChanged();
    });
  }

  void _insertBlock(int index, LatexBlock block) {
    setState(() {
      final nextBlocks = List<LatexBlock>.from(_doc.blocks);
      nextBlocks.insert(index, block);
      _doc = _doc.copyWith(blocks: nextBlocks);
      _activeIndex = index;
      _disposeBlockControllers();
      _initBlockControllers();
      _notifyChanged();
    });
  }

  void _removeBlock(int index) {
    setState(() {
      final nextBlocks = List<LatexBlock>.from(_doc.blocks);
      nextBlocks.removeAt(index);
      _activeIndex = null;
      _doc = _doc.copyWith(blocks: nextBlocks);
      _disposeBlockControllers();
      _initBlockControllers();
      _notifyChanged();
    });
  }

  void _moveBlock(int index, int delta) {
    final target = _neighbor(index, delta);
    if (target == null) return;
    setState(() {
      final nextBlocks = List<LatexBlock>.from(_doc.blocks);
      final item = nextBlocks.removeAt(index);
      nextBlocks.insert(target, item);
      _doc = _doc.copyWith(blocks: nextBlocks);
      _activeIndex = target;
      _disposeBlockControllers();
      _initBlockControllers();
      _notifyChanged();
    });
  }

  int? _neighbor(int index, int direction) {
    var next = index + direction;
    while (next >= 0 && next < _doc.blocks.length) {
      if (_visible(next)) return next;
      next += direction;
    }
    return null;
  }

  void _splitParagraph(int index) {
    final controller = _blockControllers[index] as LatexProseController;
    final selection = controller.selection;
    if (!selection.isValid) return;
    final left = LatexProseController(controller.source);
    final right = LatexProseController(controller.source);
    left.value = TextEditingValue(
      text: controller.text.substring(0, selection.start),
    );
    right.value = TextEditingValue(
      text: controller.text.substring(selection.end),
    );
    final next = right.source.trim();
    _doc.blocks[index].updateContent('${left.source.trimRight()}\n\n');
    left.dispose();
    right.dispose();
    _insertBlock(
      index + 1,
      LatexBlock.fromFields(type: LatexBlockType.paragraph, rawContent: next),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNodes[index + 1]?.requestFocus();
      _blockControllers[index + 1]?.selection = const TextSelection.collapsed(
        offset: 0,
      );
    });
  }

  TextEditingController _getControllerForBlock(int index) {
    if (!_blockControllers.containsKey(index)) {
      final block = _doc.blocks[index];
      _blockControllers[index] = _isProse(block)
          ? LatexProseController(block.rawContent)
          : TextEditingController(text: block.rawContent);
    }
    return _blockControllers[index]!;
  }

  bool _isProse(LatexBlock block) => const {
    LatexBlockType.paragraph,
    LatexBlockType.section,
    LatexBlockType.subsection,
    LatexBlockType.subsubsection,
    LatexBlockType.theorem,
    LatexBlockType.proof,
  }.contains(block.type);

  bool _visible(int i) {
    final block = _doc.blocks[i];
    final start = _doc.blocks.indexWhere(
      (b) => b.source.trim() == r'\begin{document}',
    );
    if (start >= 0 && i < start) return false;
    if (block.type == LatexBlockType.preamble ||
        block.type == LatexBlockType.title) {
      return false;
    }
    if (block.source.trim() == r'\begin{document}' ||
        block.source.trim() == r'\end{document}') {
      return false;
    }
    return block.rawContent.trim().isNotEmpty || i == _activeIndex;
  }

  void _setContent(int index, String text) {
    _doc.blocks[index].updateContent(text);
    _notifyChanged();
  }

  int get _insertionIndex {
    if (_activeIndex != null && _activeIndex! < _doc.blocks.length) {
      return _activeIndex! + 1;
    }
    final end = _doc.blocks.indexWhere(
      (b) => b.source.trim() == r'\end{document}',
    );
    return end < 0 ? _doc.blocks.length : end;
  }

  void insertMath(String source) {
    final index = _activeIndex;
    if (index != null && index < _doc.blocks.length) {
      final key = _equationKeys[index];
      if (key?.currentState != null) {
        key!.currentState!.insertLatex(source);
        return;
      }
    }
    final target = _insertionIndex;
    _insertBlock(
      target,
      LatexBlock.fromFields(type: LatexBlockType.equation, rawContent: source),
    );
    setState(() => _activeIndex = target);
  }

  void _format(String command) {
    final index = _activeIndex;
    final controller = _blockControllers[index];
    if (index == null || controller is! LatexProseController) return;
    controller.format(command);
    _setContent(index, controller.source);
    _focusNodes[index]?.requestFocus();
    setState(() {});
  }

  void _align(String environment) {
    final index = _activeIndex;
    if (index == null || _doc.blocks[index].type != LatexBlockType.paragraph) {
      return;
    }
    final current = _doc.blocks[index];
    final prefix = '\\begin{$environment}\n';
    final suffix = '\n\\end{$environment}\n';
    _updateBlock(
      index,
      LatexBlock.raw(
        kind: LatexBlockType.paragraph,
        source: '$prefix${current.rawContent.trimRight()}$suffix',
        prefix: prefix,
        suffix: suffix,
        envName: environment,
      ),
    );
  }

  void _addParagraph() {
    final index = _insertionIndex;
    _insertBlock(index, LatexBlock.fromFields(type: LatexBlockType.paragraph));
    setState(() => _activeIndex = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[index]?.requestFocus();
    });
  }

  Widget _toolbar() {
    final index = _activeIndex;
    final prose = _blockControllers[index] is LatexProseController;
    return TextFieldTapRegion(
      child: Material(
        color: OrbitColors.of(context).panel,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Row(
            children: [
              PopupMenuButton<LatexBlockType>(
                tooltip: 'Paragraph style',
                onSelected: (type) {
                  if (index != null && prose) {
                    final controller =
                        _blockControllers[index] as LatexProseController;
                    _updateBlock(
                      index,
                      LatexBlock.fromFields(
                        type: type,
                        rawContent: controller.source.trimRight(),
                      ),
                    );
                  } else {
                    final target = _insertionIndex;
                    _insertBlock(target, LatexBlock.fromFields(type: type));
                    setState(() => _activeIndex = target);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: LatexBlockType.paragraph,
                    child: Text('Normal text'),
                  ),
                  PopupMenuItem(
                    value: LatexBlockType.section,
                    child: Text('Heading 1'),
                  ),
                  PopupMenuItem(
                    value: LatexBlockType.subsection,
                    child: Text('Heading 2'),
                  ),
                  PopupMenuItem(
                    value: LatexBlockType.subsubsection,
                    child: Text('Heading 3'),
                  ),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Text('Text style'),
                      SizedBox(width: 8),
                      Icon(Icons.expand_more, size: 16),
                    ],
                  ),
                ),
              ),
              const OrbitToolbarDivider(),
              for (final item in <(String, String, IconData)>[
                ('textbf', 'Bold (Ctrl+B)', Icons.format_bold),
                ('textit', 'Italic (Ctrl+I)', Icons.format_italic),
                ('underline', 'Underline (Ctrl+U)', Icons.format_underlined),
              ])
                IconButton(
                  tooltip: item.$2,
                  isSelected:
                      prose &&
                      (_blockControllers[index] as LatexProseController)
                          .isStyleActive(item.$1),
                  icon: Icon(item.$3, size: 18),
                  onPressed: prose ? () => _format(item.$1) : null,
                ),
              const OrbitToolbarDivider(),
              for (final item in <(String, String, IconData)>[
                ('flushleft', 'Align left', Icons.format_align_left),
                ('center', 'Align center', Icons.format_align_center),
                ('flushright', 'Align right', Icons.format_align_right),
              ])
                IconButton(
                  tooltip: item.$2,
                  onPressed:
                      index != null &&
                          _doc.blocks[index].type == LatexBlockType.paragraph
                      ? () => _align(item.$1)
                      : null,
                  icon: Icon(item.$3, size: 18),
                ),
              const OrbitToolbarDivider(),
              TextButton.icon(
                onPressed: () => insertMath(r'\square'),
                icon: const Icon(Icons.functions, size: 17),
                label: const Text('Equation'),
              ),
              Tooltip(
                message: 'Math Symbol Palette',
                child: TextButton.icon(
                  onPressed: _showSymbols,
                  icon: const Icon(Icons.apps_outlined, size: 17),
                  label: const Text('Symbols'),
                ),
              ),
              IconButton(
                tooltip: 'Matrix & Cases Grid Builder',
                icon: const Icon(Icons.grid_on, size: 18),
                onPressed: () async {
                  final value = await showMathGridEditor(context);
                  if (mounted && value != null) insertMath(value);
                },
              ),
              TextButton.icon(
                onPressed: _openMathLab,
                icon: const Icon(Icons.calculate_outlined, size: 17),
                label: const Text('Math Lab'),
              ),
              const OrbitToolbarDivider(),
              IconButton(
                tooltip: 'Undo',
                onPressed: widget.onUndo,
                icon: const Icon(Icons.undo, size: 18),
              ),
              IconButton(
                tooltip: 'Redo',
                onPressed: widget.onRedo,
                icon: const Icon(Icons.redo, size: 18),
              ),
              IconButton(
                tooltip: 'Document title, author and date',
                isSelected: _metadata,
                onPressed: () => setState(() => _metadata = !_metadata),
                icon: const Icon(Icons.article_outlined, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void insertMathBlock(String source) => _insertBlock(
    _insertionIndex,
    LatexBlock.fromFields(type: LatexBlockType.equation, rawContent: source),
  );

  Future<void> _openMathLab() async {
    if (widget.onMathLab != null) {
      widget.onMathLab!();
      return;
    }
    if (_blockControllers.values.any((c) => !c.value.composing.isCollapsed)) {
      return;
    }
    final original = _doc.toLatex(), index = _activeIndex;
    final result = await showMathLab(context);
    if (!mounted ||
        result == null ||
        original != _doc.toLatex() ||
        index != _activeIndex) {
      return;
    }
    insertMathBlock(result.tex);
  }

  void _showSymbols() => showDialog<void>(
    context: context,
    builder: (_) => LatexMathPalette(onInsert: insertMath),
  );

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final visible = [
      for (var i = 0; i < _doc.blocks.length; i++)
        if (_visible(i)) i,
    ];
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () =>
            _format('textbf'),
        const SingleActivator(LogicalKeyboardKey.keyI, control: true): () =>
            _format('textit'),
        const SingleActivator(LogicalKeyboardKey.keyU, control: true): () =>
            _format('underline'),
      },
      child: Column(
        children: [
          _toolbar(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Scrollbar(
                controller: widget.scrollController,
                child: SingleChildScrollView(
                  controller: widget.scrollController,
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth < 600 ? 8 : 28,
                    vertical: 20,
                  ),
                  child: Center(
                    child: Container(
                      key: const ValueKey('latex-document-page'),
                      constraints: BoxConstraints(
                        maxWidth: widget.contentWidth,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: constraints.maxWidth < 600 ? 16 : 48,
                        vertical: 36,
                      ),
                      decoration: BoxDecoration(
                        color: colors.panel,
                        border: Border.all(color: colors.border),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          inputDecorationTheme: const InputDecorationTheme(
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_metadata)
                              _buildHeaderFields(context)
                            else if (_doc.title.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 28),
                                child: Text(
                                  _doc.title,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: widget.fontSize * 1.6,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            for (final i in visible) ...[
                              KeyedSubtree(
                                key: _locationKeys.putIfAbsent(
                                  i,
                                  () => GlobalKey(),
                                ),
                                child: _buildBlockCard(
                                  i,
                                  _doc.blocks[i],
                                  context,
                                ),
                              ),
                              _buildInsertDivider(i + 1),
                            ],
                            TextButton.icon(
                              key: const ValueKey('latex-add-paragraph'),
                              onPressed: _addParagraph,
                              icon: const Icon(Icons.add, size: 16),
                              label: Text(
                                visible.isEmpty
                                    ? 'Start writing'
                                    : 'Continue writing',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _setMetadata(String command, String value) {
    final marker = '\\$command{';
    for (final block in _doc.blocks) {
      final start = block.source.indexOf(marker);
      if (start < 0) continue;
      var end = start + marker.length, depth = 1;
      while (end < block.source.length && depth > 0) {
        if (block.source[end] == '\\') {
          end += 2;
          continue;
        }
        if (block.source[end] == '{') depth++;
        if (block.source[end] == '}') depth--;
        end++;
      }
      if (depth == 0) {
        block.source = block.source.replaceRange(
          start + marker.length,
          end - 1,
          value,
        );
        return;
      }
    }
    final index = _doc.blocks.indexWhere(
      (b) => b.source.trim() == r'\begin{document}',
    );
    final insertionIndex = index < 0 ? 0 : index;
    _doc.blocks.insert(
      insertionIndex,
      LatexBlock('$marker$value}\n', LatexBlockType.title),
    );
    if (_activeIndex != null && _activeIndex! >= insertionIndex) {
      _activeIndex = _activeIndex! + 1;
    }
    _disposeBlockControllers();
    _initBlockControllers();
  }

  Widget _buildHeaderFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title
        TextField(
          controller: _titleController,
          style: TextStyle(
            fontSize: widget.fontSize * 1.6,
            fontWeight: FontWeight.bold,
            fontFamily: 'serif',
          ),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            hintText: 'Document Title',
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 4),
          ),
          onChanged: (v) {
            _setMetadata('title', v);
            _notifyChanged();
          },
        ),
        const SizedBox(height: 8),

        // Author & Date
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            SizedBox(
              width: 180,
              child: TextField(
                controller: _authorController,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: widget.fontSize * 1.0,
                  fontFamily: 'serif',
                ),
                decoration: const InputDecoration(
                  hintText: 'Author(s)',
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (v) {
                  _setMetadata('author', v);
                  _notifyChanged();
                },
              ),
            ),
            const Text(' · ', style: TextStyle(color: Colors.grey)),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _dateController,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: widget.fontSize * 0.95,
                  fontFamily: 'serif',
                  fontStyle: FontStyle.italic,
                ),
                decoration: const InputDecoration(
                  hintText: 'Date',
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (v) {
                  _setMetadata('date', v);
                  _notifyChanged();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInsertDivider(int targetIndex) => OrbitHoverRegion(
    builder: (context, visible) => SizedBox(
      height: 20,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: OrbitMotionScope.duration(context, OrbitMotion.micro),
        child: Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: 'Insert here',
            icon: const Icon(Icons.add, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 24, height: 20),
            onPressed: () => _showAddBlockMenu(context, targetIndex),
          ),
        ),
      ),
    ),
  );

  Future<void> _showAddBlockMenu(BuildContext context, int targetIndex) async {
    final type = await showDialog<LatexBlockType>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Insert'),
        children: [
          for (final item in <(LatexBlockType, String, IconData)>[
            (LatexBlockType.paragraph, 'Paragraph', Icons.notes),
            (LatexBlockType.section, 'Heading', Icons.title),
            (LatexBlockType.equation, 'Equation', Icons.functions),
            (LatexBlockType.theorem, 'Theorem', Icons.bookmark_outline),
            (LatexBlockType.proof, 'Proof', Icons.check),
            (LatexBlockType.table, 'Table', Icons.table_chart_outlined),
            (LatexBlockType.figure, 'Figure', Icons.image_outlined),
            (
              LatexBlockType.pageBreak,
              'Page break',
              Icons.insert_page_break_outlined,
            ),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, item.$1),
              child: Row(
                children: [
                  Icon(item.$3, size: 18),
                  const SizedBox(width: 12),
                  Text(item.$2),
                ],
              ),
            ),
        ],
      ),
    );
    if (!mounted || type == null) return;
    _insertBlock(
      targetIndex.clamp(0, _doc.blocks.length),
      LatexBlock.fromFields(
        type: type,
        rawContent: type == LatexBlockType.equation ? r'\square' : '',
      ),
    );
    setState(() => _activeIndex = targetIndex);
  }

  Widget _buildBlockCard(int index, LatexBlock block, BuildContext context) =>
      Focus(
        onFocusChange: (focused) {
          if (focused && _activeIndex != index) {
            setState(() => _activeIndex = index);
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildBlockBody(index, block, context)),
            SizedBox(
              width: 28,
              child: PopupMenuButton<String>(
                tooltip: 'Paragraph actions',
                icon: Icon(
                  Icons.more_horiz,
                  size: 16,
                  color: OrbitColors.of(context).muted,
                ),
                padding: EdgeInsets.zero,
                onSelected: (action) {
                  switch (action) {
                    case 'above':
                      _insertBlock(
                        index,
                        LatexBlock.fromFields(type: LatexBlockType.paragraph),
                      );
                      setState(() => _activeIndex = index);
                    case 'below':
                      _insertBlock(
                        index + 1,
                        LatexBlock.fromFields(type: LatexBlockType.paragraph),
                      );
                      setState(() => _activeIndex = index + 1);
                    case 'up':
                      _moveBlock(index, -1);
                    case 'down':
                      _moveBlock(index, 1);
                    case 'source':
                      setState(
                        () => _sourceBlocks.contains(block)
                            ? _sourceBlocks.remove(block)
                            : _sourceBlocks.add(block),
                      );
                    case 'delete':
                      _removeBlock(index);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'above',
                    child: Text('Insert paragraph above'),
                  ),
                  const PopupMenuItem(
                    value: 'below',
                    child: Text('Insert paragraph below'),
                  ),
                  PopupMenuItem(
                    value: 'up',
                    enabled: _neighbor(index, -1) != null,
                    child: const Text('Move up'),
                  ),
                  PopupMenuItem(
                    value: 'down',
                    enabled: _neighbor(index, 1) != null,
                    child: const Text('Move down'),
                  ),
                  const PopupMenuItem(
                    value: 'source',
                    child: Text('Edit LaTeX source'),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete paragraph'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _proseField(
    int index,
    LatexBlock block, {
    double? size,
    FontWeight? weight,
  }) {
    final controller = _getControllerForBlock(index) as LatexProseController;
    final node = _focusNodes.putIfAbsent(index, () => FocusNode());
    final equations = RegExp(
      r'(?<!\\)\$(?!\$)(.+?)(?<!\\)\$',
    ).allMatches(controller.source).toList();
    final field = Focus(
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter &&
            !HardwareKeyboard.instance.isShiftPressed &&
            !HardwareKeyboard.instance.isControlPressed &&
            !HardwareKeyboard.instance.isAltPressed &&
            !HardwareKeyboard.instance.isMetaPressed) {
          _splitParagraph(index);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TextField(
        key: ValueKey('latex-prose-$index'),
        controller: controller,
        focusNode: node,
        maxLines: null,
        textAlign: switch (block.environment) {
          'center' => TextAlign.center,
          'flushright' => TextAlign.right,
          _ => TextAlign.left,
        },
        style: TextStyle(
          fontSize: size ?? widget.fontSize,
          height: 1.55,
          fontWeight: weight,
        ),
        decoration: const InputDecoration(hintText: 'Write here…'),
        onChanged: (_) => _setContent(index, controller.source),
      ),
    );
    if (equations.isEmpty) return field;
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final equation in equations) {
      final text = LatexProseController(
        controller.source.substring(cursor, equation.start),
      );
      spans.add(text.buildTextSpan(context: context, withComposing: false));
      text.dispose();
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: InkWell(
            key: ValueKey('latex-inline-$index-${equation.start}'),
            onTap: () => _editInlineEquation(index, equation),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: NoteMath(equation.group(1)!, display: false),
            ),
          ),
        ),
      );
      cursor = equation.end;
    }
    final tail = LatexProseController(controller.source.substring(cursor));
    spans.add(tail.buildTextSpan(context: context, withComposing: false));
    tail.dispose();
    return Focus(
      onFocusChange: (_) {
        if (mounted) setState(() {});
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Offstage(offstage: !node.hasFocus, child: field),
          if (!node.hasFocus)
            GestureDetector(
              onTap: () {
                controller.selection = TextSelection.collapsed(
                  offset: controller.text.trimRight().length,
                );
                node.requestFocus();
              },
              child: Text.rich(
                TextSpan(children: spans),
                style: TextStyle(
                  fontSize: size ?? widget.fontSize,
                  height: 1.55,
                  fontWeight: weight,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _editInlineEquation(int index, RegExpMatch equation) async {
    final block = _doc.blocks[index];
    final original = block.rawContent;
    var value = equation.group(1)!;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Edit equation'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: EditableMathExpression(
                source: value,
                display: true,
                onChanged: (next) {
                  update(() => value = next);
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (mounted &&
                    index < _doc.blocks.length &&
                    identical(_doc.blocks[index], block) &&
                    block.rawContent == original) {
                  final next = original.replaceRange(
                    equation.start,
                    equation.end,
                    '\$$value\$',
                  );
                  (_blockControllers[index] as LatexProseController).setSource(
                    next,
                  );
                  _setContent(index, next);
                  setState(() {});
                }
                Navigator.pop(ctx);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockBody(int index, LatexBlock block, BuildContext context) {
    if (_sourceBlocks.contains(block)) {
      return TextFormField(
        key: ObjectKey(block),
        initialValue: block.rawContent,
        maxLines: null,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        decoration: const InputDecoration(labelText: 'LaTeX source'),
        onChanged: (value) {
          _setContent(index, value);
          final c = _blockControllers[index];
          if (c is LatexProseController) c.setSource(value);
        },
      );
    }
    switch (block.type) {
      case LatexBlockType.section:
      case LatexBlockType.subsection:
      case LatexBlockType.subsubsection:
        return _proseField(
          index,
          block,
          size:
              widget.fontSize *
              (block.type == LatexBlockType.section ? 1.4 : 1.15),
          weight: FontWeight.w600,
        );
      case LatexBlockType.paragraph:
        return _proseField(index, block);
      case LatexBlockType.equation:
      case LatexBlockType.aligned:
        return _buildEquationBlockEditor(index, block, context);

      case LatexBlockType.theorem:
        return _buildTheoremBlockEditor(index, block, context);

      case LatexBlockType.proof:
        return _buildProofBlockEditor(index, block, context);

      case LatexBlockType.table:
        return _buildTableBlockEditor(index, block, context);

      case LatexBlockType.figure:
        return _buildFigureBlockEditor(index, block, context);

      case LatexBlockType.list:
        return TextField(
          controller: _getControllerForBlock(index),
          maxLines: null,
          style: TextStyle(fontSize: widget.fontSize, height: 1.6),
          decoration: const InputDecoration(
            hintText: "\\item First item\n\\item Second item",
            border: InputBorder.none,
            isDense: true,
          ),
          onChanged: (v) => _setContent(
            index,
            _blockControllers[index] is LatexProseController
                ? (_blockControllers[index] as LatexProseController).source
                : v,
          ),
        );

      case LatexBlockType.pageBreak:
        return const Center(
          child: Text('Page break', style: TextStyle(color: Colors.grey)),
        );

      default:
        return TextField(
          controller: _getControllerForBlock(index),
          maxLines: null,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
          ),
          onChanged: (v) => _setContent(
            index,
            _blockControllers[index] is LatexProseController
                ? (_blockControllers[index] as LatexProseController).source
                : v,
          ),
        );
    }
  }

  Widget _buildEquationBlockEditor(
    int index,
    LatexBlock block,
    BuildContext context,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: EditableMathExpression(
      key: _equationKeys.putIfAbsent(
        index,
        () => GlobalKey<EditableMathExpressionState>(),
      ),
      source: block.rawContent.trim().isEmpty
          ? r'\square'
          : block.rawContent.trim(),
      display: true,
      showToolbar: _activeIndex == index,
      onUndo: widget.onUndo,
      onRedo: widget.onRedo,
      onChanged: (value) => _setContent(index, value),
    ),
  );

  Widget _buildTheoremBlockEditor(
    int index,
    LatexBlock block,
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            DropdownButton<String>(
              value:
                  [
                    'theorem',
                    'lemma',
                    'definition',
                    'proposition',
                    'corollary',
                    'example',
                    'remark',
                  ].contains(block.environment.toLowerCase())
                  ? block.environment.toLowerCase()
                  : 'theorem',
              items: const [
                DropdownMenuItem(value: 'theorem', child: Text('Theorem')),
                DropdownMenuItem(value: 'lemma', child: Text('Lemma')),
                DropdownMenuItem(
                  value: 'definition',
                  child: Text('Definition'),
                ),
                DropdownMenuItem(
                  value: 'proposition',
                  child: Text('Proposition'),
                ),
                DropdownMenuItem(value: 'corollary', child: Text('Corollary')),
                DropdownMenuItem(value: 'example', child: Text('Example')),
                DropdownMenuItem(value: 'remark', child: Text('Remark')),
              ],
              onChanged: (v) {
                if (v != null) {
                  _updateBlock(index, block.copyWith(environment: v));
                }
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: block.options,
                decoration: const InputDecoration(
                  hintText: 'Name (optional)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) =>
                    _updateBlock(index, block.copyWith(options: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _getControllerForBlock(index),
          maxLines: null,
          style: TextStyle(
            fontSize: widget.fontSize,
            fontFamily: 'serif',
            fontStyle: FontStyle.italic,
          ),
          decoration: const InputDecoration(
            hintText: 'Write the statement…',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => _setContent(
            index,
            _blockControllers[index] is LatexProseController
                ? (_blockControllers[index] as LatexProseController).source
                : v,
          ),
        ),
      ],
    );
  }

  Widget _buildProofBlockEditor(
    int index,
    LatexBlock block,
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Proof.',
              style: TextStyle(
                fontFamily: 'serif',
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: block.options,
                decoration: const InputDecoration(
                  hintText: 'Optional proof note (e.g. of Theorem 1)',
                  isDense: true,
                  border: InputBorder.none,
                ),
                onChanged: (v) =>
                    _updateBlock(index, block.copyWith(options: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _getControllerForBlock(index),
          maxLines: null,
          style: TextStyle(fontSize: widget.fontSize, fontFamily: 'serif'),
          decoration: const InputDecoration(
            hintText: 'Write the proof…',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => _setContent(
            index,
            _blockControllers[index] is LatexProseController
                ? (_blockControllers[index] as LatexProseController).source
                : v,
          ),
        ),
        const SizedBox(height: 4),
        const Align(
          alignment: Alignment.centerRight,
          child: Text('□', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildTableBlockEditor(
    int index,
    LatexBlock block,
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          initialValue: block.caption ?? '',
          decoration: const InputDecoration(
            labelText: 'Table Caption',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => _updateBlock(index, block.copyWith(caption: v)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _getControllerForBlock(index),
          maxLines: 4,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: const InputDecoration(
            labelText:
                'Tabular Data (separate cells with & and rows with \\\\)',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => _setContent(
            index,
            _blockControllers[index] is LatexProseController
                ? (_blockControllers[index] as LatexProseController).source
                : v,
          ),
        ),
      ],
    );
  }

  Widget _buildFigureBlockEditor(
    int index,
    LatexBlock block,
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: block.imagePath ?? '',
                decoration: const InputDecoration(
                  labelText: 'Image Path / Reference',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) =>
                    _updateBlock(index, block.copyWith(imagePath: v)),
              ),
            ),
            if (widget.onInsertAttachment != null) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.attach_file, size: 16),
                label: const Text('Browse'),
                onPressed: () async {
                  final ref = await widget.onInsertAttachment!();
                  if (ref != null) {
                    _updateBlock(index, block.copyWith(imagePath: ref));
                  }
                },
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: block.caption ?? '',
          decoration: const InputDecoration(
            labelText: 'Figure Caption',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => _updateBlock(index, block.copyWith(caption: v)),
        ),
      ],
    );
  }
}
