import 'dart:async';
import '../../../app/orbit_components.dart';
import '../../../app/orbit_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:highlight/highlight.dart' as hl;
import 'package:markdown/markdown.dart' as md;
import '../read_search_overlay.dart';
import '../pixel_font_scope.dart';
import '../../../app/workspace_controller.dart';
import 'dynamic_view_block.dart';
import 'snapshot_block.dart';
import 'code_workspace.dart';
import 'code_editing.dart';
import '../../math/math_plot_source_block.dart';

class CodeController extends TextEditingController {
  CodeController({required String text, required this.language})
    : super(text: text);
  String language;
  String? _cachedLanguage;
  String? _cachedText;
  List<TextSpan>? _spans;
  List<hl.Node>? _nodes;
  OrbitColors? _palette;
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
    final palette = OrbitColors.of(context);
    if (_cachedText != text || _cachedLanguage != language) {
      _cachedLanguage = language;
      _cachedText = text;
      _palette = null;
      try {
        _nodes = text.length > 50000 || language.isEmpty
            ? null
            : hl.highlight
                  .parse(
                    text,
                    language: switch (language.toLowerCase()) {
                      'html' => 'xml',
                      'js' => 'javascript',
                      'c++' => 'cpp',
                      'c#' => 'cs',
                      _ => language,
                    },
                  )
                  .nodes;
      } catch (_) {
        _nodes = null;
      }
    }
    if (_palette != palette) {
      _palette = palette;
      final colors = {
        'keyword': palette.secondary,
        'string': palette.success,
        'comment': palette.muted,
        'number': palette.warning,
        'built_in': palette.accent,
        'title': palette.accent,
      };
      TextSpan span(hl.Node node) => TextSpan(
        text: node.value,
        style: TextStyle(color: colors[node.className]),
        children: node.children?.map(span).toList(),
      );
      _spans = _nodes?.map(span).toList() ?? [TextSpan(text: text)];
    }
    return TextSpan(style: style, children: _spans);
  }
}

class NoteCodeBlock extends StatefulWidget {
  const NoteCodeBlock({
    super.key,
    required this.code,
    this.language = '',
    this.onChanged,
    this.onUndo,
    this.onRedo,
    this.onFocused,
    this.clipboardEpoch,
  });
  final String code, language;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onUndo, onRedo;
  final VoidCallback? onFocused;
  final int Function()? clipboardEpoch;
  @override
  State<NoteCodeBlock> createState() => NoteCodeBlockState();
}

class NoteCodeBlockState extends State<NoteCodeBlock> {
  late CodeController controller = CodeController(
    text: widget.code,
    language: widget.language.split(RegExp(r'\s+')).first,
  );
  final focus = FocusNode();
  final _field = GlobalKey();
  bool copied = false;
  bool _hovered = false;
  Timer? timer;
  int _revision = 0, _focusEpoch = 0, _clipboardRequest = 0;
  late String _observedText = controller.text;
  TextSelection? get sourceSelection =>
      controller.selection.isValid ? controller.selection : null;

  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      if (_observedText != controller.text) {
        _revision++;
        _observedText = controller.text;
      }
    });
    focus.addListener(() {
      _focusEpoch++;
      if (focus.hasFocus) widget.onFocused?.call();
    });
  }

  Future<void> _clipboard({required bool paste, bool cut = false}) async {
    final value = controller.value, revision = _revision, owner = _focusEpoch;
    final epoch = widget.clipboardEpoch?.call(), request = ++_clipboardRequest;
    final selection = value.selection;
    if (!selection.isValid ||
        !value.composing.isCollapsed ||
        (!paste && selection.isCollapsed) ||
        ((paste || cut) && widget.onChanged == null)) {
      return;
    }
    try {
      String replacement = '';
      if (paste) {
        final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
        if (text == null) return;
        replacement = text;
      } else {
        await Clipboard.setData(
          ClipboardData(text: selection.textInside(value.text)),
        );
        if (!cut) return;
      }
      if (!mounted ||
          !focus.hasFocus ||
          widget.onChanged == null ||
          _revision != revision ||
          _focusEpoch != owner ||
          _clipboardRequest != request ||
          widget.clipboardEpoch?.call() != epoch ||
          controller.value != value) {
        return;
      }
      controller.value = TextEditingValue(
        text: value.text.replaceRange(
          selection.start,
          selection.end,
          replacement,
        ),
        selection: TextSelection.collapsed(
          offset: selection.start + replacement.length,
        ),
      );
      widget.onChanged!(controller.text);
      widget.onFocused?.call();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(
              'Could not access the clipboard. Your code is unchanged.',
            ),
          ),
        );
      }
    }
  }

  bool selectSource(int offset, {int length = 0, bool requestFocus = true}) {
    final selection = TextSelection(
      baseOffset: offset.clamp(0, controller.text.length),
      extentOffset: (offset + length).clamp(0, controller.text.length),
    );
    controller.selection = selection;
    if (requestFocus) focus.requestFocus();
    final text = controller.text;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          controller.text != text ||
          controller.selection != selection) {
        return;
      }
      void visit(Element element) {
        if (element is StatefulElement && element.state is EditableTextState) {
          (element.state as EditableTextState).bringIntoView(
            TextPosition(offset: selection.extentOffset),
          );
        } else {
          element.visitChildren(visit);
        }
      }

      _field.currentContext?.visitChildElements(visit);
    });
    return true;
  }

  @override
  void didUpdateWidget(NoteCodeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    controller.language = widget.language.split(RegExp(r'\s+')).first;
    if (widget.code != controller.text) {
      controller.value = TextEditingValue(
        text: widget.code,
        selection: TextSelection(
          baseOffset: controller.selection.baseOffset.clamp(
            0,
            widget.code.length,
          ),
          extentOffset: controller.selection.extentOffset.clamp(
            0,
            widget.code.length,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      PixelFontScope(enabled: false, child: Builder(builder: _buildCode));

  Widget _buildCode(BuildContext context) {
    final langLower = widget.language.toLowerCase();
    final isBytes = langLower == 'hex' || langLower == 'bytes';
    final isAsm =
        langLower == 'asm' ||
        langLower == 'disasm' ||
        langLower == 'x86asm' ||
        langLower == 'x86' ||
        langLower == 'x64' ||
        langLower == 'arm';

    final displayLang = switch (langLower) {
      'yara' => 'YARA Rule',
      'sigma' => 'Sigma Rule',
      'hex' || 'bytes' => 'Hex / Raw Bytes',
      'asm' || 'disasm' || 'x86asm' || 'x86' || 'x64' => 'x86-64 Disassembly',
      'arm' => 'ARM Disassembly',
      _ => widget.language.isEmpty ? 'Code' : widget.language,
    };

    final copyLabel = copied
        ? (isBytes
              ? 'Copied Bytes ✓'
              : isAsm
              ? 'Copied Disasm ✓'
              : 'Copied ✓')
        : (isBytes
              ? 'Copy Bytes'
              : isAsm
              ? 'Copy Disassembly'
              : 'Copy code');

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    displayLang,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight:
                          (isBytes ||
                              isAsm ||
                              langLower == 'yara' ||
                              langLower == 'sigma')
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Expand code editor',
                  icon: const Icon(Icons.open_in_full, size: 16),
                  onPressed: () async {
                    final original = widget.code;
                    final result = await showDialog<String>(
                      context: context,
                      builder: (_) => CodeWorkspace(
                        code: original,
                        language: controller.language,
                        readOnly: widget.onChanged == null,
                        canApply: () => mounted && widget.code == original,
                      ),
                    );
                    if (!mounted || result == null || widget.code != original) {
                      return;
                    }
                    controller.text = result;
                    widget.onChanged?.call(result);
                    setState(() {});
                  },
                ),
                AnimatedOpacity(
                  duration: OrbitMotionScope.duration(
                    context,
                    OrbitMotion.micro,
                  ),
                  opacity: (_hovered || focus.hasFocus || copied) ? 1.0 : 0.0,
                  child: TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: controller.text),
                      );
                      if (!mounted) return;
                      setState(() => copied = true);
                      timer?.cancel();
                      timer = Timer(const Duration(seconds: 2), () {
                        if (mounted) setState(() => copied = false);
                      });
                    },
                    icon: Icon(copied ? Icons.check : Icons.copy, size: 14),
                    label: AnimatedSwitcher(
                      duration: OrbitMotionScope.duration(
                        context,
                        OrbitMotion.micro,
                      ),
                      child: Text(copyLabel, key: ValueKey(copied)),
                    ),
                  ),
                ),
              ],
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final maxLine = controller.text
                    .split('\n')
                    .fold(0, (n, line) => n > line.length ? n : line.length);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: (maxLine * 9.0 + 32).clamp(
                      constraints.maxWidth,
                      100000,
                    ),
                    child: Focus(
                      onKeyEvent: (_, event) {
                        if (widget.onChanged != null &&
                            event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.tab &&
                            controller.value.composing.isCollapsed) {
                          controller.value = indentCode(
                            controller.value,
                            outdent: HardwareKeyboard.instance.isShiftPressed,
                          );
                          widget.onChanged!(controller.text);
                          setState(() {});
                          return KeyEventResult.handled;
                        }
                        if (event is KeyDownEvent &&
                            HardwareKeyboard.instance.isControlPressed &&
                            !controller.value.composing.isCollapsed &&
                            {
                              LogicalKeyboardKey.keyZ,
                              LogicalKeyboardKey.keyY,
                            }.contains(event.logicalKey)) {
                          return KeyEventResult.handled;
                        }
                        if (event is KeyDownEvent &&
                            HardwareKeyboard.instance.isControlPressed &&
                            controller.value.composing.isCollapsed) {
                          if (event.logicalKey == LogicalKeyboardKey.keyZ &&
                              widget.onUndo != null) {
                            HardwareKeyboard.instance.isShiftPressed
                                ? widget.onRedo?.call()
                                : widget.onUndo!();
                            return KeyEventResult.handled;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.keyY &&
                              widget.onRedo != null) {
                            widget.onRedo!();
                            return KeyEventResult.handled;
                          }
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Actions(
                        actions: {
                          CopySelectionTextIntent:
                              CallbackAction<CopySelectionTextIntent>(
                                onInvoke: (intent) {
                                  unawaited(
                                    _clipboard(
                                      paste: false,
                                      cut: intent.collapseSelection,
                                    ),
                                  );
                                  return null;
                                },
                              ),
                          PasteTextIntent: CallbackAction<PasteTextIntent>(
                            onInvoke: (_) {
                              unawaited(_clipboard(paste: true));
                              return null;
                            },
                          ),
                        },
                        child: KeyedSubtree(
                          key: _field,
                          child: TextField(
                            key: const ValueKey('rich-code'),
                            controller: controller,
                            focusNode: focus,
                            readOnly: widget.onChanged == null,
                            maxLines: null,
                            style: TextStyle(
                              fontFamily: OrbitCodePreferences.of(
                                context,
                              ).fontFamily,
                              fontSize: OrbitCodePreferences.of(
                                context,
                              ).fontSize,
                              height: 1.6,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (v) {
                              widget.onChanged?.call(v);
                              widget.onFocused?.call();
                              setState(() {});
                            },
                            contextMenuBuilder: (context, state) =>
                                AdaptiveTextSelectionToolbar.buttonItems(
                                  anchors: state.contextMenuAnchors,
                                  buttonItems: [
                                    for (final item
                                        in state.contextMenuButtonItems)
                                      if ({
                                        ContextMenuButtonType.copy,
                                        ContextMenuButtonType.cut,
                                        ContextMenuButtonType.paste,
                                      }.contains(item.type))
                                        ContextMenuButtonItem(
                                          type: item.type,
                                          label: item.label,
                                          onPressed: () {
                                            state.hideToolbar();
                                            unawaited(
                                              _clipboard(
                                                paste:
                                                    item.type ==
                                                    ContextMenuButtonType.paste,
                                                cut:
                                                    item.type ==
                                                    ContextMenuButtonType.cut,
                                              ),
                                            );
                                          },
                                        )
                                      else
                                        item,
                                  ],
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class CodeElementBuilder extends MarkdownElementBuilder {
  CodeElementBuilder({this.controller, this.noteId});

  final WorkspaceController? controller;
  final String? noteId;

  @override
  bool isBlockElement() => true;
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    if (element.tag != 'pre' || element.children?.first is! md.Element) {
      return null;
    }
    final code = element.children!.first as md.Element;
    final text = code.textContent.replaceFirst(RegExp(r'\n$'), '');
    final language = (code.attributes['class'] ?? '').replaceFirst(
      'language-',
      '',
    );
    if (language == 'orbit-plot') {
      return ReadSearchText(
        text: text,
        leadingLength: 0,
        normalizeQueryLineEndings: true,
        child: MathPlotSourceBlock(source: text),
      );
    }
    if (DynamicViewBlock.isDynamicView(language, text)) {
      return DynamicViewBlock(
        source: text,
        controller: controller,
        noteId: noteId,
        onChanged: (_) {},
      );
    }
    if (SnapshotBlock.isSnapshot(language, text)) {
      return SnapshotBlock(source: text, onChanged: (_) {});
    }
    return ReadSearchText(
      text: text,
      leadingLength: 0,
      normalizeQueryLineEndings: true,
      child: NoteCodeBlock(code: text, language: language),
    );
  }
}
