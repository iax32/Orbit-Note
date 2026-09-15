import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/orbit_theme.dart';
import 'equation_editor.dart';
import 'math_edit_document.dart';
import 'note_math.dart';
import 'latex_catalog.dart';
import 'latex_symbol_catalog.dart';

class EditableMathExpression extends StatefulWidget {
  const EditableMathExpression({
    super.key,
    required this.source,
    required this.onChanged,
    this.display = false,
    this.onUndo,
    this.onRedo,
    this.extraActions = const [],
    this.autofocus = false,
  });
  final String source;
  final ValueChanged<String> onChanged;
  final bool display;
  final bool autofocus;
  final VoidCallback? onUndo, onRedo;
  final List<Widget> extraActions;
  @override
  State<EditableMathExpression> createState() => _EditableMathExpressionState();
}

class _EditableMathExpressionState extends State<EditableMathExpression> {
  late String _source = widget.source;
  final _keys = <String, GlobalKey<_MathFieldState>>{};
  final _parts = <String, MathPart>{};
  final _up = <String, String>{}, _down = <String, String>{};
  String? _active;
  late int? _pendingOffset = widget.autofocus ? 0 : null;
  final _catalog = OverlayPortalController();
  final _anchor = GlobalKey();
  ScrollPosition? _pageScroll;
  bool _selectAll = false;
  int _fractions = 0;
  late MathEditDocument _document;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _pageScroll)) {
      _pageScroll?.removeListener(_trackCatalog);
      _pageScroll = position;
      _pageScroll?.addListener(_trackCatalog);
    }
  }

  void _trackCatalog() {
    if (mounted && _catalog.isShowing) setState(() {});
  }

  @override
  void dispose() {
    _pageScroll?.removeListener(_trackCatalog);
    super.dispose();
  }

  @override
  void didUpdateWidget(EditableMathExpression oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.source != _source) {
      final focused = _keys[_active]?.currentState?.focus.hasFocus == true;
      final offset = _parts[_active]?.start;
      _source = widget.source;
      _pendingOffset = focused ? offset?.clamp(0, _source.length) : null;
    }
    if (widget.autofocus && !oldWidget.autofocus) _pendingOffset = 0;
  }

  void _commit(String value, {int? focusOffset}) {
    // Markdown's inline delimiter grammar excludes boundary whitespace. TeX
    // ignores it here; trim only newly edited boundaries, never stored input.
    if (!widget.display) {
      final leading = value.length - value.trimLeft().length;
      value = value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
      focusOffset = focusOffset == null
          ? null
          : (focusOffset - leading).clamp(0, value.length);
    }
    // An empty pair of inline dollars ceases to be an inline equation. Keep a
    // visible, selectable slot until the user removes the equation itself.
    if (value.isEmpty) {
      value = r'\square';
      focusOffset = 0;
    }
    final changed = value != _source;
    setState(() {
      _selectAll = false;
      _source = value;
      _pendingOffset = focusOffset;
      _document = MathEditDocument(value);
      _parts
        ..clear()
        ..addAll(_document.editableParts);
    });
    if (changed) widget.onChanged(value);
  }

  void _edit(String path, String next) {
    if (_selectAll) {
      _commit(encodeMathText(next), focusOffset: encodeMathText(next).length);
      return;
    }
    final part = _parts[path];
    if (part == null) return;
    final projection = MathTextProjection(
      _source.substring(part.start, part.end),
    );
    final update = _document.replace(
      part.start,
      part.end,
      projection.edit(next),
      within: part,
    );
    _commit(update.$1);
  }

  void _insert(
    String kind, {
    String? path,
    TextEditingValue? before,
    bool template = false,
  }) {
    final key = path ?? _active;
    final part = _parts[key];
    final field = _keys[key]?.currentState;
    var start = _source.length, end = start;
    String selected = '';
    if (part != null && field != null) {
      final projection = MathTextProjection(
        _source.substring(part.start, part.end),
      );
      final value = before ?? field.controller.value;
      final selection = value.selection.isValid
          ? value.selection
          : TextSelection.collapsed(offset: projection.text.length);
      var from = selection.start.clamp(0, projection.text.length);
      final to = selection.end.clamp(0, projection.text.length);
      if (from == to && {'Fraction', 'Power', 'Subscript'}.contains(kind)) {
        final operand = RegExp(
          r'(\([^()]*\)|[a-zA-Z0-9α-ωΑ-Ω.]+)$',
        ).firstMatch(projection.text.substring(0, from));
        if (operand != null) from = operand.start;
      }
      start = part.start + projection.sourceStart(from);
      end =
          part.start +
          (to == from ? projection.sourceStart(to) : projection.sourceEnd(to));
      selected = _source.substring(start, end);
      if (selected.trim() == r'\square') selected = '';
    }
    if (_selectAll) {
      start = 0;
      end = _source.length;
      selected = _source;
    }
    final operand = selected.isEmpty ? r'\square' : selected;
    var tex = switch (kind) {
      'Fraction' => '\\frac{$operand}{\\square}',
      'Power' => '{$operand}^{\\square}',
      'Subscript' => '{$operand}_{\\square}',
      'Root' => '\\sqrt{$operand}',
      'Sum' => r'\sum_{\square}^{\square} \square',
      'Integral' => r'\int_{\square}^{\square} \square',
      _ => kind,
    };
    if (template && selected.isNotEmpty && tex.contains(r'\square')) {
      tex = tex.replaceFirst(r'\square', selected);
    }
    if (RegExp(r'\\[a-zA-Z]+$').hasMatch(tex)) tex += ' ';
    final update = _document.replace(
      start,
      end,
      tex,
      within: _selectAll ? null : part,
    );
    final placeholder = tex.indexOf(r'\square');
    _commit(
      update.$1,
      focusOffset: update.$2 + (placeholder < 0 ? tex.length : placeholder),
    );
  }

  bool _move(
    String from,
    int direction, {
    bool vertical = false,
    bool tab = false,
  }) {
    final order = _parts.entries
        .where(
          (e) =>
              !tab ||
              e.value.start != e.value.end ||
              e.value.label != 'Expression',
        )
        .map((e) => e.key)
        .toList();
    final i = order.indexOf(from);
    final target = vertical
        ? (direction < 0 ? _up[from] : _down[from])
        : (i + direction >= 0 && i + direction < order.length
              ? order[i + direction]
              : null);
    final state = _keys[target]?.currentState;
    if (state == null) return false;
    state.focus.requestFocus();
    state.selectPlaceholderOrCaret(
      direction < 0 ? state.controller.text.length : 0,
    );
    return true;
  }

  void _link(List<String> top, List<String> bottom) {
    for (var i = 0; i < top.length && bottom.isNotEmpty; i++) {
      _down.putIfAbsent(top[i], () => bottom[i.clamp(0, bottom.length - 1)]);
    }
    for (var i = 0; i < bottom.length && top.isNotEmpty; i++) {
      _up.putIfAbsent(bottom[i], () => top[i.clamp(0, top.length - 1)]);
    }
  }

  Widget _part(
    MathPart part,
    String path,
    double size, {
    String? fieldKey,
    bool boundary = false,
  }) {
    final colors = OrbitColors.of(context);
    switch (part.kind) {
      case MathPartKind.text:
        _parts[path] = part;
        return _MathField(
          key: _keys.putIfAbsent(path, () => GlobalKey<_MathFieldState>()),
          fieldKey: fieldKey ?? 'math-field-$path',
          text: MathTextProjection(
            _source.substring(part.start, part.end),
          ).text,
          label: part.label,
          boundary: boundary,
          size: size,
          onFocus: () {
            _active = path;
            _selectAll = false;
          },
          onChanged: (old, next) {
            if (next.composing.isCollapsed &&
                old.composing.isCollapsed &&
                old.selection.isValid) {
              for (final entry in const {
                '/': 'Fraction',
                '^': 'Power',
                '_': 'Subscript',
              }.entries) {
                if (next.text ==
                    old.text.replaceRange(
                      old.selection.start,
                      old.selection.end,
                      entry.key,
                    )) {
                  _insert(entry.value, path: path, before: old);
                  return;
                }
              }
            }
            _edit(path, next.text);
          },
          onMove: (direction, vertical, tab) =>
              _move(path, direction, vertical: vertical, tab: tab),
          onEmptyBackspace: () {
            if (_selectAll) return false;
            final target = _parts[path];
            if (target == null) return false;
            final result = _document.removeEmptyPart(target);
            if (result == null) return false;
            _commit(result.$1, focusOffset: result.$2);
            return true;
          },
        );
      case MathPartKind.group:
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < part.children.length; i++)
              _part(
                part.children[i],
                '$path.$i',
                size,
                fieldKey: part.children.length == 1 ? fieldKey : null,
                boundary:
                    part.children.length > 1 &&
                    part.children[i].start == part.children[i].end,
              ),
          ],
        );
      case MathPartKind.fraction:
        final index = _fractions++;
        var first = _parts.length;
        final top = _part(
          part.children[0],
          '$path.n',
          size * .92,
          fieldKey: 'frac-num-$index',
        );
        final tops = _parts.keys.skip(first).toList();
        first = _parts.length;
        final bottom = _part(
          part.children[1],
          '$path.d',
          size * .92,
          fieldKey: 'frac-den-$index',
        );
        _link(tops, _parts.keys.skip(first).toList());
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: top),
                Container(
                  height: 1.3,
                  color: colors.text.withValues(alpha: .8),
                ),
                Center(child: bottom),
              ],
            ),
          ),
        );
      case MathPartKind.root:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (part.children.length > 1)
              Padding(
                padding: EdgeInsets.only(bottom: size),
                child: _part(part.children[1], '$path.degree', size * .65),
              ),
            Text(
              '√',
              style: TextStyle(
                fontSize: size * 1.7,
                fontFamily: 'serif',
                color: colors.text,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.text)),
              ),
              child: _part(part.children[0], '$path.root', size),
            ),
          ],
        );
      case MathPartKind.scripts:
      case MathPartKind.operator:
        Widget? upper, lower;
        List<String> tops = [], bottoms = [];
        for (var i = 0; i < part.children.length; i++) {
          final child = part.children[i], first = _parts.length;
          final view = _part(child, '$path.$i', size * .72);
          final fields = _parts.keys.skip(first).toList();
          if (child.label == 'Exponent' || child.label == 'Upper limit') {
            upper = view;
            tops = fields;
          } else {
            lower = view;
            bottoms = fields;
          }
        }
        _link(tops, bottoms);
        if (part.kind == MathPartKind.operator) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?upper,
              Text(
                const {
                  r'\sum': '∑',
                  r'\prod': '∏',
                  r'\int': '∫',
                  r'\lim': 'lim',
                  r'\bigcup': '⋃',
                  r'\bigcap': '⋂',
                }[part.command]!,
                style: TextStyle(
                  fontSize: size * 1.6,
                  fontFamily: 'serif',
                  color: colors.text,
                ),
              ),
              ?lower,
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            upper ?? SizedBox(height: size * .75),
            lower ?? SizedBox(height: size * .75),
          ],
        );
      case MathPartKind.opaque:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: NoteMath(_source.substring(part.start, part.end)),
        );
    }
  }

  Future<void> _advanced() async {
    final original = _source;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => EquationEditor(source: original, display: widget.display),
    );
    if (result != null && mounted && _source == original) _commit(result);
  }

  void _catalogInsert(LatexEntry entry) {
    _insert(entry.source, template: true);
  }

  void _closeCatalog({bool restoreFocus = false}) {
    if (!_catalog.isShowing) return;
    setState(() => _catalog.hide());
    if (restoreFocus) _keys[_active]?.currentState?.focus.requestFocus();
  }

  Widget _catalogPanel(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final box = _anchor.currentContext?.findRenderObject() as RenderBox?;
    final origin = box?.localToGlobal(Offset.zero) ?? const Offset(16, 80);
    final width = (screen.width - 32).clamp(200.0, 650.0);
    final bottom = origin.dy + (box?.size.height ?? 30) + 8;
    final below =
        (screen.height - MediaQuery.viewInsetsOf(context).bottom - bottom - 16)
            .clamp(0.0, 370.0);
    final above = (origin.dy - 24).clamp(0.0, 370.0);
    final placeBelow = below >= above;
    final height = placeBelow ? below : above;
    final top = placeBelow ? bottom : origin.dy - height - 8;
    final left = (origin.dx + (box?.size.width ?? 0) / 2 - width / 2).clamp(
      16.0,
      (screen.width - width - 16).clamp(16.0, double.infinity),
    );
    final colors = OrbitColors.of(context);
    return Positioned(
      top: top,
      left: left,
      width: width,
      height: height,
      child: TapRegion(
        groupId: _catalog,
        child: Material(
          key: const ValueKey('latex-catalog-panel'),
          color: colors.raised,
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: SizedBox(
              height: height.clamp(220.0, double.infinity),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('Symbols & templates')),
                        IconButton(
                          tooltip: 'Close symbol table',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _closeCatalog(restoreFocus: true),
                          icon: const Icon(Icons.close, size: 17),
                        ),
                      ],
                    ),
                    Expanded(
                      child: LatexSymbolCatalog(onInsert: _catalogInsert),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbar() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextButton.icon(
        onPressed: () => setState(() {
          _catalog.isShowing ? _catalog.hide() : _catalog.show();
        }),
        icon: const Icon(Icons.apps_rounded, size: 16),
        label: const Text('Symbols & templates'),
      ),
      ...widget.extraActions,
      IconButton(
        tooltip: 'Copy LaTeX',
        visualDensity: VisualDensity.compact,
        onPressed: _copyEquation,
        icon: const Icon(Icons.copy_outlined, size: 15),
      ),
      IconButton(
        tooltip: 'Advanced equation editor',
        visualDensity: VisualDensity.compact,
        onPressed: _advanced,
        icon: const Icon(Icons.tune_rounded, size: 17),
      ),
    ],
  );

  Future<void> _copyEquation({bool cut = false}) async {
    final original = _source;
    try {
      await Clipboard.setData(ClipboardData(text: original));
      if (cut && mounted && _selectAll && _source == original) {
        _commit('', focusOffset: 0);
      }
    } catch (_) {
      _clipboardFailure('Could not copy the equation. It has been kept.');
    }
  }

  Future<void> _pasteEquation() async {
    final original = _source;
    try {
      final data = await Clipboard.getData('text/plain');
      if (!mounted ||
          !_selectAll ||
          _source != original ||
          data?.text == null) {
        return;
      }
      final text = data!.text!;
      final value = text.contains(r'\') ? text : encodeMathText(text);
      _commit(value, focusOffset: value.length);
    } catch (_) {
      _clipboardFailure('Could not paste. Your equation has been kept.');
    }
  }

  void _clipboardFailure(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  KeyEventResult _equationKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final control =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (key == LogicalKeyboardKey.escape) {
      if (_catalog.isShowing) {
        _closeCatalog(restoreFocus: true);
        return KeyEventResult.handled;
      }
      if (_selectAll) {
        setState(() => _selectAll = false);
        return KeyEventResult.handled;
      }
    }
    if (control && key == LogicalKeyboardKey.keyA) {
      final field = _keys[_active]?.currentState;
      if (field == null || !field.focus.hasFocus) return KeyEventResult.ignored;
      field.controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: field.controller.text.length,
      );
      setState(() => _selectAll = true);
      return KeyEventResult.handled;
    }
    if (_selectAll &&
        control &&
        (key == LogicalKeyboardKey.keyC || key == LogicalKeyboardKey.keyX)) {
      _copyEquation(cut: key == LogicalKeyboardKey.keyX);
      return KeyEventResult.handled;
    }
    if (_selectAll && control && key == LogicalKeyboardKey.keyV) {
      _pasteEquation();
      return KeyEventResult.handled;
    }
    if (_selectAll &&
        (key == LogicalKeyboardKey.backspace ||
            key == LogicalKeyboardKey.delete)) {
      _commit('', focusOffset: 0);
      return KeyEventResult.handled;
    }
    if (_selectAll &&
        (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowRight)) {
      setState(() {
        _selectAll = false;
        _pendingOffset = key == LogicalKeyboardKey.arrowLeft
            ? 0
            : _source.length;
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    _document = MathEditDocument(_source);
    _parts.clear();
    _up.clear();
    _down.clear();
    _fractions = 0;
    final original = _source;
    final expression = _document.root == null
        ? NoteMath(
            _source,
            display: widget.display,
            onEdit: (v) {
              if (_source == original) _commit(v);
            },
          )
        : _part(_document.root!, '0', widget.display ? 22 : 18);
    _keys.removeWhere((path, _) => !_parts.containsKey(path));
    if (_pendingOffset != null) {
      final offset = _pendingOffset!;
      _pendingOffset = null;
      final candidates =
          _parts.entries
              .where((e) => e.value.start <= offset && e.value.end >= offset)
              .toList()
            ..sort(
              (a, b) => (a.value.end - a.value.start).compareTo(
                b.value.end - b.value.start,
              ),
            );
      if (candidates.isNotEmpty) {
        final path = candidates.first.key;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final state = _keys[path]?.currentState;
          state?.focus.requestFocus();
          final part = _parts[path];
          if (state != null && part != null) {
            final local =
                MathTextProjection(
                  _source.substring(part.start, part.end),
                ).visibleOffset(
                  (offset - part.start).clamp(0, part.end - part.start),
                );
            state.selectPlaceholderOrCaret(local);
          }
          if (widget.autofocus && !_catalog.isShowing) {
            if (state != null) {
              Scrollable.ensureVisible(state.context, alignment: .3);
            }
            setState(() => _catalog.show());
          }
        });
      }
    }
    return CallbackShortcuts(
      bindings: {
        if (widget.onUndo != null)
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
              widget.onUndo!,
        if (widget.onRedo != null)
          const SingleActivator(LogicalKeyboardKey.keyY, control: true):
              widget.onRedo!,
        if (widget.onRedo != null)
          const SingleActivator(
            LogicalKeyboardKey.keyZ,
            control: true,
            shift: true,
          ): widget.onRedo!,
        if (widget.onUndo != null)
          const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
              widget.onUndo!,
        if (widget.onRedo != null)
          const SingleActivator(
            LogicalKeyboardKey.keyZ,
            meta: true,
            shift: true,
          ): widget.onRedo!,
      },
      child: Focus(
        onKeyEvent: _equationKey,
        child: TapRegion(
          groupId: _catalog,
          onTapOutside: (_) => _closeCatalog(),
          child: OverlayPortal(
            controller: _catalog,
            overlayChildBuilder: _catalogPanel,
            child: Column(
              key: _anchor,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: _selectAll
                        ? OrbitColors.of(context).accent.withValues(alpha: .22)
                        : null,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        expression,
                        if (!widget.display)
                          IconButton(
                            tooltip: 'Symbols & templates',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.apps_rounded, size: 15),
                            onPressed: () => setState(() {
                              _catalog.isShowing
                                  ? _catalog.hide()
                                  : _catalog.show();
                            }),
                          ),
                      ],
                    ),
                  ),
                ),
                if (widget.display)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _toolbar(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MathField extends StatefulWidget {
  const _MathField({
    super.key,
    required this.fieldKey,
    required this.text,
    required this.label,
    required this.boundary,
    required this.size,
    required this.onFocus,
    required this.onChanged,
    required this.onMove,
    required this.onEmptyBackspace,
  });
  final String fieldKey, text, label;
  final bool boundary;
  final double size;
  final VoidCallback onFocus;
  final void Function(TextEditingValue, TextEditingValue) onChanged;
  final bool Function(int, bool, bool) onMove;
  final bool Function() onEmptyBackspace;
  @override
  State<_MathField> createState() => _MathFieldState();
}

class _MathFieldState extends State<_MathField> {
  late final controller = TextEditingController(text: widget.text);
  late TextEditingValue _accepted = controller.value;
  late final focus = FocusNode(
    skipTraversal: widget.boundary,
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent || !controller.value.composing.isCollapsed) {
        return KeyEventResult.ignored;
      }
      final key = event.logicalKey;
      if (HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed ||
          HardwareKeyboard.instance.isAltPressed) {
        return KeyEventResult.ignored;
      }
      var direction = 0, vertical = false;
      if (key == LogicalKeyboardKey.backspace &&
          (controller.text.isEmpty || controller.text.trim() == '□') &&
          widget.onEmptyBackspace()) {
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.tab) {
        direction = HardwareKeyboard.instance.isShiftPressed ? -1 : 1;
      } else if (HardwareKeyboard.instance.isShiftPressed) {
        return KeyEventResult.ignored;
      } else if (key == LogicalKeyboardKey.arrowUp) {
        direction = -1;
        vertical = true;
      } else if (key == LogicalKeyboardKey.arrowDown) {
        direction = 1;
        vertical = true;
      } else if (controller.selection.isCollapsed &&
          key == LogicalKeyboardKey.arrowLeft &&
          controller.selection.start == 0) {
        direction = -1;
      } else if (controller.selection.isCollapsed &&
          key == LogicalKeyboardKey.arrowRight &&
          controller.selection.end == controller.text.length) {
        direction = 1;
      }
      if (direction != 0 &&
          widget.onMove(direction, vertical, key == LogicalKeyboardKey.tab)) {
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
  );
  void selectPlaceholderOrCaret(int offset) {
    controller.selection = controller.text.trim() == '□'
        ? TextSelection(baseOffset: 0, extentOffset: controller.text.length)
        : TextSelection.collapsed(
            offset: offset.clamp(0, controller.text.length),
          );
  }

  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      if (controller.text == _accepted.text) _accepted = controller.value;
    });
    focus.addListener(() {
      if (focus.hasFocus) {
        widget.onFocus();
        if (controller.text.trim() == '□') selectPlaceholderOrCaret(0);
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(_MathField oldWidget) {
    super.didUpdateWidget(oldWidget);
    focus.skipTraversal = widget.boundary;
    if (widget.text != controller.text) {
      final selection = controller.selection;
      controller.value = TextEditingValue(
        text: widget.text,
        selection: TextSelection(
          baseOffset: selection.baseOffset.clamp(0, widget.text.length),
          extentOffset: selection.extentOffset.clamp(0, widget.text.length),
        ),
      );
      _accepted = controller.value;
    }
  }

  @override
  void dispose() {
    focus.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final size = widget.size.clamp(12.0, 24.0);
    final style = TextStyle(
      fontSize: size,
      fontFamily: 'serif',
      color: colors.text,
      height: 1.25,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: widget.text.isEmpty ? '□' : widget.text,
        style: style,
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = widget.boundary
        ? 10.0
        : (painter.width + 6).clamp(20.0, 640.0);
    painter.dispose();
    return Semantics(
      label: widget.label,
      child: Container(
        width: width,
        constraints: BoxConstraints(minHeight: size * 1.55),
        child: TextField(
          key: ValueKey(widget.fieldKey),
          controller: controller,
          focusNode: focus,
          style: style,
          textAlign: TextAlign.center,
          cursorColor: colors.accent,
          autocorrect: false,
          enableSuggestions: false,
          smartDashesType: SmartDashesType.disabled,
          smartQuotesType: SmartQuotesType.disabled,
          keyboardType: TextInputType.text,
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.boundary ? '' : '□',
            filled: false,
            hintStyle: style.copyWith(
              color: colors.subtle.withValues(alpha: .45),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: widget.boundary ? 0 : 2,
              vertical: 1,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: (_) {
            final previous = _accepted;
            _accepted = controller.value;
            widget.onChanged(previous, controller.value);
          },
          onSubmitted: (_) => widget.onMove(1, false, true),
        ),
      ),
    );
  }
}
