import 'dart:async';
import '../../../app/orbit_components.dart';
import '../../../app/orbit_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:highlight/highlight.dart' as hl;
import 'package:markdown/markdown.dart' as md;

class CodeController extends TextEditingController {
  CodeController({required String text, required this.language})
    : super(text: text);
  final String language;
  String? _cachedText;
  List<TextSpan>? _spans;
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
    if (_cachedText != text) {
      _cachedText = text;
      const colors = {
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
                  .parse(text, language: language)
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
  });
  final String code, language;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onUndo, onRedo;
  @override
  State<NoteCodeBlock> createState() => _NoteCodeBlockState();
}

class _NoteCodeBlockState extends State<NoteCodeBlock> {
  late CodeController controller = CodeController(
    text: widget.code,
    language: widget.language.split(RegExp(r'\s+')).first,
  );
  final focus = FocusNode();
  bool copied = false;
  Timer? timer;
  @override
  void didUpdateWidget(NoteCodeBlock old) {
    super.didUpdateWidget(old);
    if (widget.code != controller.text) {
      controller.value = TextEditingValue(
        text: widget.code,
        selection: TextSelection.collapsed(
          offset: controller.selection.extentOffset.clamp(
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
  Widget build(BuildContext context) => Container(
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
                widget.language.isEmpty ? 'Code' : widget.language,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: controller.text));
                if (!mounted) return;
                setState(() => copied = true);
                timer?.cancel();
                timer = Timer(const Duration(seconds: 2), () {
                  if (mounted) setState(() => copied = false);
                });
              },
              icon: Icon(copied ? Icons.check : Icons.copy, size: 14),
              label: AnimatedSwitcher(
                duration: OrbitMotionScope.duration(context, OrbitMotion.micro),
                child: Text(
                  copied ? 'Copied ✓' : 'Copy code',
                  key: ValueKey(copied),
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
                width: (maxLine * 9.0 + 32).clamp(constraints.maxWidth, 100000),
                child: Focus(
                  onKeyEvent: (_, event) {
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
                      setState(() {});
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}

class CodeElementBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    if (element.tag != 'pre' || element.children?.first is! md.Element) {
      return null;
    }
    final code = element.children!.first as md.Element;
    return NoteCodeBlock(
      code: code.textContent.replaceFirst(RegExp(r'\n$'), ''),
      language: (code.attributes['class'] ?? '').replaceFirst('language-', ''),
    );
  }
}
