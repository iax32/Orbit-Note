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
  Brightness? _brightness;
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
    final brightness = Theme.of(context).brightness;
    if (_cachedText != text ||
        _brightness != brightness ||
        _cachedLanguage != language) {
      _cachedLanguage = language;
      _brightness = brightness;
      _cachedText = text;
      final colors = brightness == Brightness.light
          ? {
              'keyword': const Color(0xff6833a8),
              'string': const Color(0xff276b39),
              'comment': const Color(0xff666976),
              'number': const Color(0xff8b520c),
              'built_in': const Color(0xff245e9b),
              'title': const Color(0xff245e9b),
            }
          : {
              'keyword': Color(0xffb69aff),
              'string': Color(0xffa5d6a7),
              'comment': Color(0xff8d91a8),
              'number': Color(0xffffcc80),
              'built_in': Color(0xff90caf9),
              'title': Color(0xff90caf9),
            };
      TextSpan span(hl.Node node) => TextSpan(
        text: node.value,
        style: TextStyle(color: colors[node.className]),
        children: node.children?.map(span).toList(),
      );
      try {
        _spans = text.length > 50000 || language.isEmpty
            ? [TextSpan(text: text)]
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
                  .nodes
                  ?.map(span)
                  .toList();
      } catch (_) {
        _spans = [TextSpan(text: text)];
      }
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
  });
  final String code, language;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onUndo, onRedo;
  final VoidCallback? onFocused;
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
  TextSelection? get sourceSelection =>
      controller.selection.isValid ? controller.selection : null;

  @override
  void initState() {
    super.initState();
    focus.addListener(() {
      if (focus.hasFocus) widget.onFocused?.call();
    });
  }

  bool selectSource(int offset, {int length = 0}) {
    final selection = TextSelection(
      baseOffset: offset.clamp(0, controller.text.length),
      extentOffset: (offset + length).clamp(0, controller.text.length),
    );
    controller.selection = selection;
    focus.requestFocus();
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
                      child: KeyedSubtree(
                        key: _field,
                        child: TextField(
                          key: const ValueKey('rich-code'),
                          controller: controller,
                          focusNode: focus,
                          readOnly: widget.onChanged == null,
                          maxLines: null,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
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
