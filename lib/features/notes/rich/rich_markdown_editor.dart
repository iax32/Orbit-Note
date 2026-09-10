import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../domain/wiki_links.dart';
import '../markdown_editing.dart';
import '../note_format_toolbar.dart';
import '../note_link_dialog.dart';
import 'markdown_document.dart';
import 'note_math.dart';
import 'equation_editor.dart';
import 'code_block.dart';
import 'rich_table_editor.dart';
import 'rich_math_block.dart';
import 'callout_block.dart';

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
    this.fontSize = 16,
    this.contentWidth = 800,
    this.initialState = const {},
    this.onState,
    this.imageBuilder,
    this.onInsertAttachment,
    this.onPasteImage,
  });
  final String body;
  final ValueChanged<String> onChanged, onOpenLink;
  final VoidCallback onUndo, onRedo;
  final List<NoteLinkTarget> linkTargets;
  final Map<String, String> linkBindings;
  final double fontSize, contentWidth;
  final Map<String, dynamic> initialState;
  final ValueChanged<Map<String, dynamic>>? onState;
  final Widget Function(BuildContext, String)? imageBuilder;
  final Future<String?> Function()? onInsertAttachment, onPasteImage;
  @override
  State<RichMarkdownEditor> createState() => RichMarkdownEditorState();
}

class RichMarkdownEditorState extends State<RichMarkdownEditor> {
  late MarkdownDocument document = MarkdownDocument.parse(widget.body);
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
  @override
  void initState() {
    super.initState();
    scroll.addListener(record);
  }

  void record() => widget.onState?.call({
    'block': active,
    'caret': caret,
    'base': selectionBase,
    'scroll': scroll.hasClients ? scroll.offset : 0,
  });
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RichMarkdownEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.body != document.source) {
      final wasEditing =
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorStateOfType<RichMarkdownEditorState>() ==
          this;
      _load(widget.body);
      if (wasEditing) {
        _focusOffset(
          document.offsetOf(active) +
              current.prefix.length +
              InlineProjection(current.content).sourceOffset(caret),
        );
      }
    }
    if (widget.fontSize != oldWidget.fontSize ||
        widget.contentWidth != oldWidget.contentWidth ||
        !mapEquals(widget.linkBindings, oldWidget.linkBindings)) {
      cache.clear();
    }
  }

  void _load(String source) {
    final next = MarkdownDocument.parse(source);
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
        if (old.kind == MarkdownBlockKind.math &&
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
    final retained = document.blocks.toSet();
    keys.removeWhere((k, _) => !retained.contains(k));
    anchors.removeWhere((k, _) => !retained.contains(k));
    cache.removeWhere((k, _) => !retained.contains(k));
    active = active.clamp(0, document.blocks.length - 1);
  }

  void _replace(
    MarkdownBlock block,
    String source, {
    bool structural = false,
    int? focusOffset,
  }) {
    final index = document.blocks.indexOf(block);
    if (index < 0 || source == block.source) return;
    final start = document.offsetOf(index);
    if (structural) {
      final body = document.source.replaceRange(
        start,
        start + block.source.length,
        source,
      );
      _load(body);
    } else {
      block.source = source;
      cache.remove(block);
    }
    widget.onChanged(document.source);
    setState(() {});
    if (focusOffset != null) _focusOffset(start + focusOffset);
  }

  void _focusOffset(int offset) {
    active = document.blockAt(offset).clamp(0, document.blocks.length - 1);
    var block = document.blocks[active];
    // An empty paragraph between existing blocks is still an editing target.
    // Its transient text field contributes exactly the original blank source.
    if (block.kind == MarkdownBlockKind.blank) {
      block = MarkdownBlock(
        block.source,
        MarkdownBlockKind.text,
        suffix: block.source,
      );
      document.blocks[active] = block;
    }
    final raw = (offset - document.offsetOf(active) - block.prefix.length)
        .clamp(0, block.content.length);
    final local = InlineProjection(block.content).visibleOffset(raw);
    caret = local;
    selectionBase = local;
    record();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      keys[block]?.currentState?.focusAt(local);
      final context = anchors[block]?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: .15,
          duration: Duration.zero,
        );
      }
    });
  }

  void jumpTo(int offset) => _focusOffset(offset);
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
    if (callback == null) return;
    final block = current;
    final content = await callback();
    if (!mounted || content == null || !document.blocks.contains(block)) return;
    active = document.blocks.indexOf(block);
    insertMarkdown(content);
  }

  Future<void> format(NoteFormatAction action) async {
    final field = keys[current]?.currentState;
    switch (action) {
      case NoteFormatAction.bold:
        field?.wrap('**');
      case NoteFormatAction.italic:
        field?.wrap('*');
      case NoteFormatAction.strike:
        field?.wrap('~~');
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
        final target = await showNoteLinkDialog(context, widget.linkTargets);
        if (!mounted || target == null) return;
        field?.insert(
          '[[${target.id}|${target.title.replaceAll('|', ' ').replaceAll(']', '')}]]',
        );
    }
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
    'Code block',
    'Table',
    'Inline equation',
    'Block equation',
    'Image / file',
    'Horizontal rule',
  ];
  Future<void> command(String name, {bool fromSlash = false}) async {
    final block = current;
    final content = fromSlash ? '' : block.content;
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
        '$prefix$content${block.suffix}',
        structural: true,
        focusOffset: prefix.length + content.length,
      );
      return;
    }
    if (name == 'Image / file') {
      await insertFrom(widget.onInsertAttachment);
      return;
    }
    if (name == 'Inline equation') {
      final code = await showDialog<String>(
        context: context,
        builder: (_) => const EquationEditor(source: 'x^2', display: false),
      );
      if (code == null || !mounted) return;
      if (fromSlash) {
        _replace(block, '\$$code\$\n', structural: true);
      } else {
        keys[block]?.currentState?.insert('\$$code\$');
        _replace(block, block.source, structural: true);
        setState(() {
          cache.remove(block);
        });
      }
      return;
    }
    if (name == 'Block equation') {
      final code = await showDialog<String>(
        context: context,
        builder: (_) =>
            const EquationEditor(source: r'\frac{a}{b}', display: true),
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
    var syntax = switch (name) {
      'Code block' => '```text\n${content.isEmpty ? 'code' : content}\n```\n',
      'Horizontal rule' => '---\n',
      'Callout' =>
        '> [!NOTE]\n> ${content.isEmpty ? 'A useful observation.' : content}\n',
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
    if (syntax.isEmpty) return;
    if (fromSlash ||
        block.content.isEmpty ||
        name == 'Code block' ||
        name == 'Callout') {
      _replace(block, syntax, structural: true);
    } else {
      insertMarkdown(syntax);
    }
  }

  Future<void> slash(MarkdownBlock block) async {
    active = document.blocks.indexOf(block);
    final box =
        anchors[block]?.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final point = box.localToGlobal(Offset.zero);
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        point.dx,
        point.dy + 35,
        point.dx + 260,
        0,
      ),
      items: commands
          .map((c) => PopupMenuItem(value: c, child: Text(c)))
          .toList(),
    );
    if (!mounted || result == null || !document.blocks.contains(block)) return;
    active = document.blocks.indexOf(block);
    await command(result, fromSlash: true);
  }

  void _enter(MarkdownBlock block, TextEditingValue value) {
    if (block.kind == MarkdownBlockKind.list && block.content.trim().isEmpty) {
      _replace(block, '\n', structural: true, focusOffset: 1);
      return;
    }
    final projection = InlineProjection(block.content);
    final start = value.selection.start.clamp(0, projection.text.length);
    final end = value.selection.end.clamp(start, projection.text.length);
    // Delete each half through the inline projection to retain balanced marks
    // and link targets on both sides of the explicit paragraph split.
    final left = projection.edit(
      projection.text.substring(0, start),
      selectionStart: start,
      selectionEnd: projection.text.length,
    );
    final right = projection.edit(
      projection.text.substring(end),
      selectionStart: 0,
      selectionEnd: end,
    );
    _splitBlock(block, left, right);
  }

  void _splitBlock(MarkdownBlock block, String left, String right) {
    final eol = block.source.contains('\r\n') ? '\r\n' : '\n';
    final ending = block.source.endsWith('\n') ? eol : '';
    var nextPrefix = '';
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
    final index = document.blocks.indexOf(block);
    var previous = index - 1;
    while (previous >= 0 &&
        document.blocks[previous].kind == MarkdownBlockKind.blank) {
      previous--;
    }
    if (previous < 0) return false;
    final before = document.blocks[previous];
    if (!{
      MarkdownBlockKind.text,
      MarkdownBlockKind.heading,
      MarkdownBlockKind.list,
      MarkdownBlockKind.quote,
    }.contains(before.kind)) {
      return false;
    }
    final start = document.offsetOf(previous);
    final visibleCaret = InlineProjection(before.content).text.length;
    var left = before.content, right = block.content;
    for (final (marker, mark) in [
      ('**', 'bold'),
      ('__', 'bold'),
      ('~~', 'strike'),
      ('*', 'italic'),
      ('_', 'italic'),
      ('`', 'code'),
    ]) {
      final a = InlineProjection(left), b = InlineProjection(right);
      if (left.endsWith(marker) &&
          right.startsWith(marker) &&
          a.styles.isNotEmpty &&
          b.styles.isNotEmpty &&
          a.styles.last.contains(mark) &&
          b.styles.first.contains(mark)) {
        left = left.substring(0, left.length - marker.length);
        right = right.substring(marker.length);
      }
    }
    final joined = '$left$right';
    final caretOffset =
        start +
        before.prefix.length +
        InlineProjection(joined).sourceOffset(visibleCaret, end: true);
    final body = document.source.replaceRange(
      start,
      document.offsetOf(index) + block.source.length,
      before.replaceContent(joined),
    );
    _load(body);
    widget.onChanged(body);
    _focusOffset(caretOffset);
    setState(() {});
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

  Widget blockView(MarkdownBlock block) {
    if (block.kind == MarkdownBlockKind.blank) {
      return SizedBox(
        height: 28,
        child: Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: 'Insert paragraph here',
            padding: EdgeInsets.zero,
            iconSize: 16,
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              final offset = document.offsetOf(document.blocks.indexOf(block));
              final eol = block.source.contains('\r\n') ? '\r\n' : '\n';
              final body = document.source.replaceRange(
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
      );
    }
    if (block.kind == MarkdownBlockKind.table) {
      return RichTableEditor(
        source: block.source,
        onChanged: (v) => _replace(block, v),
        onUndo: widget.onUndo,
        onRedo: widget.onRedo,
      );
    }
    if (block.kind == MarkdownBlockKind.callout) {
      return CalloutBlock(
        source: block.source,
        onChanged: (v) => _replace(block, v),
      );
    }
    if (block.kind == MarkdownBlockKind.math) {
      return Center(
        child: RichMathBlock(
          content: block.content,
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
      return NoteCodeBlock(
        code: block.content,
        language: block.language,
        onUndo: widget.onUndo,
        onRedo: widget.onRedo,
        onChanged: (v) {
          var prefix = block.prefix, suffix = block.suffix;
          if (!suffix.startsWith(RegExp(r'\r?\n')) && v.isNotEmpty) {
            suffix = '${block.source.contains('\r\n') ? '\r\n' : '\n'}$suffix';
          }
          final fence = RegExp(r'`{3,}|~{3,}').firstMatch(prefix);
          if (fence != null &&
              v.split('\n').any((l) => l.trim().startsWith(fence[0]!))) {
            var delimiter = fence[0]!;
            while (v.contains(delimiter)) {
              delimiter += delimiter[0];
            }
            prefix = prefix.replaceFirst(fence[0]!, delimiter);
            suffix = suffix.replaceFirst(
              RegExp('${RegExp.escape(fence[0]![0])}{3,}'),
              delimiter,
            );
            _replace(block, '$prefix$v$suffix', structural: true);
          } else {
            _replace(
              block,
              '$prefix$v$suffix',
              structural: suffix != block.suffix,
            );
          }
        },
      );
    }
    if (block.kind == MarkdownBlockKind.rule) return const Divider(height: 32);
    if (block.kind == MarkdownBlockKind.image) {
      final match = RegExp(
        r'^!\[([^\]]*)\]\((?:<([^>]+)>|([^ )]+))(?: +"[^"]*")?\)',
      ).firstMatch(block.content);
      if (match != null) {
        return Column(
          children: [
            widget.imageBuilder?.call(context, match[2] ?? match[3]!) ??
                const Icon(Icons.image_outlined),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => widget.onOpenLink(match[2] ?? match[3]!),
                  child: const Text('Open original'),
                ),
                TextButton(
                  onPressed: () => _replace(block, '', structural: true),
                  child: const Text('Remove embed'),
                ),
              ],
            ),
          ],
        );
      }
    }
    // Inline equations are individually editable widgets among real text fields.
    if (block.kind == MarkdownBlockKind.text &&
        inlineMathMatches(block.content).isNotEmpty) {
      return _InlineMathParagraph(
        source: block.content,
        fontSize: widget.fontSize,
        onChanged: (v) => _replace(block, block.replaceContent(v)),
        onUndo: widget.onUndo,
        onRedo: widget.onRedo,
        onSplit: (left, right) => _splitBlock(block, left, right),
      );
    }
    final raw =
        block.kind == MarkdownBlockKind.raw ||
        block.kind == MarkdownBlockKind.image;
    final field = _RichTextBlock(
      key: keys.putIfAbsent(block, () => GlobalKey<_RichTextBlockState>()),
      source: raw ? block.source : block.content,
      raw: raw,
      style: TextStyle(
        fontSize: block.kind == MarkdownBlockKind.heading
            ? widget.fontSize + (7 - block.level) * 2
            : widget.fontSize,
        fontWeight: block.kind == MarkdownBlockKind.heading
            ? FontWeight.w600
            : null,
        height: 1.65,
        fontFamily: raw ? 'monospace' : null,
      ),
      initialCaret: document.blocks.indexOf(block) == active ? caret : 0,
      initialBase: document.blocks.indexOf(block) == active ? selectionBase : 0,
      onFocus: (position) {
        active = document.blocks.indexOf(block);
        caret = position.extentOffset;
        selectionBase = position.baseOffset;
        record();
      },
      onChanged: (v) {
        _replace(block, raw ? v : block.replaceContent(v));
        if (v == '/') slash(block);
        if (v.endsWith('[[')) {
          active = document.blocks.indexOf(block);
          format(NoteFormatAction.link);
        }
      },
      onEnter: raw ? null : (v) => _enter(block, v),
      onJoinPrevious: raw ? null : () => _joinPrevious(block),
      onIndent: block.kind == MarkdownBlockKind.list
          ? (out) => _indent(block, out)
          : null,
      onUndo: widget.onUndo,
      onRedo: widget.onRedo,
      onPasteImage: widget.onPasteImage == null
          ? null
          : () => insertFrom(widget.onPasteImage),
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
    final links = parseWikiLinks(block.content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
        ),
        if (links.isNotEmpty)
          Wrap(
            spacing: 4,
            children: [
              for (final link in links)
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(link.label),
                  onPressed: () {
                    final target = resolveWikiLink(
                      link,
                      widget.linkTargets,
                      bindings: widget.linkBindings,
                    ).target;
                    if (target != null) {
                      widget.onOpenLink('orbit-object:${target.id}');
                    }
                  },
                ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: scroll,
    child: SingleChildScrollView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 80),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.contentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final block in document.blocks)
                Container(
                  key: anchors.putIfAbsent(block, () => GlobalKey()),
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Listener(
                    onPointerDown: (_) {
                      active = document.blocks.indexOf(block);
                      record();
                    },
                    child: cache.putIfAbsent(block, () => blockView(block)),
                  ),
                ),
              TextButton.icon(
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
            ],
          ),
        ),
      ),
    ),
  );
}

class _StyledController extends TextEditingController {
  void refreshStyle() => notifyListeners();
  _StyledController(String source, {this.raw = false})
    : projection = InlineProjection(source),
      super(text: raw ? source : InlineProjection(source).text);
  InlineProjection projection;
  final bool raw;
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (raw || projection.text != text || !value.composing.isCollapsed) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final spans = <TextSpan>[];
    var start = 0;
    while (start < text.length) {
      var end = start + 1;
      while (end < text.length &&
          projection.styles[end].join(',') ==
              projection.styles[start].join(',')) {
        end++;
      }
      final marks = projection.styles[start];
      spans.add(
        TextSpan(
          text: text.substring(start, end),
          style: TextStyle(
            fontWeight: marks.contains('bold') ? FontWeight.bold : null,
            fontStyle: marks.contains('italic') ? FontStyle.italic : null,
            fontFamily: marks.contains('code') ? 'monospace' : null,
            decoration: marks.contains('strike')
                ? TextDecoration.lineThrough
                : marks.contains('link')
                ? TextDecoration.underline
                : null,
            color: marks.contains('link')
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
        ),
      );
      start = end;
    }
    return TextSpan(style: style, children: spans);
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
    this.initialCaret = 0,
    this.initialBase,
    this.hintText = 'Write something, or / for commands',
    this.onFocus,
    this.onEnter,
    this.onJoinPrevious,
    this.onIndent,
    this.onPasteImage,
  });
  final String source;
  final bool raw;
  final int initialCaret;
  final int? initialBase;
  final String hintText;
  final TextStyle style;
  final ValueChanged<String> onChanged;
  final ValueChanged<TextSelection>? onFocus;
  final ValueChanged<TextEditingValue>? onEnter;
  final bool Function()? onJoinPrevious;
  final ValueChanged<bool>? onIndent;
  final VoidCallback onUndo, onRedo;
  final VoidCallback? onPasteImage;
  @override
  State<_RichTextBlock> createState() => _RichTextBlockState();
}

class _RichTextBlockState extends State<_RichTextBlock> {
  late final _StyledController controller = _StyledController(
    widget.source,
    raw: widget.raw,
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
  }

  void selection() {
    if (controller.text == (widget.raw ? source : controller.projection.text)) {
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
      source = widget.source;
      _sync();
    }
  }

  void _sync({int? caret}) {
    controller.projection = InlineProjection(source);
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

  void focusAt(int offset) {
    controller.selection = TextSelection.collapsed(
      offset: offset.clamp(0, controller.text.length),
    );
    focus.requestFocus();
  }

  void insert(String markdown) {
    final p = controller.projection;
    var sel = controller.selection.isValid
        ? controller.selection
        : TextSelection.collapsed(offset: controller.text.length);
    if (markdown.startsWith('[[') &&
        sel.isCollapsed &&
        controller.text.substring(0, sel.start).endsWith('[[')) {
      sel = TextSelection(baseOffset: sel.start - 2, extentOffset: sel.end);
    }
    final a = widget.raw ? sel.start : p.sourceOffset(sel.start),
        b = widget.raw
            ? sel.end
            : sel.isCollapsed
            ? a
            : p.sourceOffset(sel.end, end: true);
    source = source.replaceRange(a, b, markdown);
    _sync(caret: sel.start + InlineProjection(markdown).text.length);
    widget.onChanged(source);
    focus.requestFocus();
  }

  void wrap(String marker) {
    final sel = controller.selection;
    if (!sel.isValid) return;
    final p = controller.projection;
    final a = p.sourceOffset(sel.start),
        b = sel.isCollapsed ? a : p.sourceOffset(sel.end, end: true);
    source = source.replaceRange(
      a,
      b,
      '$marker${sel.isCollapsed ? 'text' : source.substring(a, b)}$marker',
    );
    _sync(caret: sel.end + (sel.isCollapsed ? 4 : 0));
    widget.onChanged(source);
    focus.requestFocus();
  }

  KeyEventResult keyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (!controller.value.composing.isCollapsed) {
      // Do not let the enclosing document consume IME undo as document undo.
      return keyboard.isControlPressed &&
              {
                LogicalKeyboardKey.keyZ,
                LogicalKeyboardKey.keyY,
              }.contains(event.logicalKey)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (keyboard.isControlPressed) {
      if (event.logicalKey == LogicalKeyboardKey.keyZ) {
        keyboard.isShiftPressed ? widget.onRedo() : widget.onUndo();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyY) {
        widget.onRedo();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyV &&
          widget.onPasteImage != null) {
        Clipboard.getData(Clipboard.kTextPlain).then((data) {
          if (mounted && (data?.text ?? '').isEmpty) widget.onPasteImage!();
        });
      }
    }
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        !keyboard.isShiftPressed &&
        widget.onEnter != null) {
      widget.onEnter!(controller.value);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
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

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    focusNode: focus,
    maxLines: null,
    style: widget.style,
    decoration: InputDecoration(
      hintText: widget.hintText,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      filled: false,
      isDense: true,
      contentPadding: EdgeInsets.zero,
    ),
    onChanged: (value) {
      source = widget.raw
          ? value
          : controller.projection.edit(
              value,
              selectionStart: _beforeSelection.start,
              selectionEnd: _beforeSelection.end,
            );
      controller.projection = InlineProjection(source);
      widget.onChanged(source);
      if (controller.value.composing.isCollapsed) _sync();
    },
  );
}

class _InlineMathParagraph extends StatelessWidget {
  const _InlineMathParagraph({
    required this.source,
    required this.fontSize,
    required this.onChanged,
    required this.onUndo,
    required this.onRedo,
    required this.onSplit,
  });
  final String source;
  final double fontSize;
  final ValueChanged<String> onChanged;
  final VoidCallback onUndo, onRedo;
  final void Function(String, String) onSplit;
  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    var offset = 0;
    void prose(int start, int end) {
      final text = source.substring(start, end);
      widgets.add(
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 24, maxWidth: 650),
          child: IntrinsicWidth(
            child: _RichTextBlock(
              key: ValueKey('math-text-$start'),
              source: text,
              hintText: '',
              style: TextStyle(fontSize: fontSize, height: 1.65),
              onChanged: (v) => onChanged(source.replaceRange(start, end, v)),
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
          onChanged: (v) =>
              onChanged(source.replaceRange(m.start, m.end, '\$$v\$')),
        ),
      );
      offset = m.end;
    }
    prose(offset, source.length);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: widgets,
    );
  }
}
