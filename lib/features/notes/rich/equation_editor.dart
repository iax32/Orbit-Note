import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/orbit_theme.dart';
import 'latex_catalog.dart';
import 'note_math.dart';
import 'visual_math_model.dart';

class EquationEditor extends StatefulWidget {
  const EquationEditor({
    super.key,
    required this.source,
    required this.display,
  });

  final String source;
  final bool display;

  @override
  State<EquationEditor> createState() => _EquationEditorState();
}

class _EquationEditorState extends State<EquationEditor> {
  late final TextEditingController input = TextEditingController(
    text: widget.source,
  );
  late final FocusNode focus = FocusNode(
    onKeyEvent: (_, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.tab &&
          input.value.composing.isCollapsed &&
          !HardwareKeyboard.instance.isControlPressed) {
        final start = input.selection.isValid ? input.selection.start : 0;
        final end = input.selection.isValid ? input.selection.end : 0;
        final next = HardwareKeyboard.instance.isShiftPressed
            ? (start == 0 ? -1 : input.text.lastIndexOf(r'\square', start - 1))
            : input.text.indexOf(r'\square', end);
        if (next >= 0) {
          input.selection = TextSelection(
            baseOffset: next,
            extentOffset: next + 7,
          );
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    },
  );

  String query = '', category = 'All';
  bool showSource = true;

  void _applyModelUpdate(String newSource) {
    input.text = newSource;
    setState(() {});
  }

  void insert(LatexEntry entry) {
    final selection = input.selection.isValid
        ? input.selection
        : TextSelection.collapsed(offset: input.text.length);
    var value = entry.source;
    final selected = selection.textInside(input.text);
    if (selected.isNotEmpty && value.contains(r'\square')) {
      value = value.replaceFirst(r'\square', selected);
    }
    // Separate a control word from subsequent typed letters without changing
    // its meaning, including insertion in the middle of an existing formula.
    if (RegExp(r'\\[a-zA-Z]+$').hasMatch(value)) {
      value += ' ';
    }
    final placeholder = value.indexOf(r'\square');
    input.value = TextEditingValue(
      text: input.text.replaceRange(selection.start, selection.end, value),
      selection: placeholder < 0
          ? TextSelection.collapsed(offset: selection.start + value.length)
          : TextSelection(
              baseOffset: selection.start + placeholder,
              extentOffset: selection.start + placeholder + 7,
            ),
    );
    focus.requestFocus();
    setState(() {});
  }

  @override
  void dispose() {
    input.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final model = VisualMathModel(input.text);
    final entries = latexCatalog
        .where(
          (e) =>
              (category == 'All' || e.category == category) &&
              '${e.name} ${e.source} ${e.glyph}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.functions, color: colors.accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.display
                  ? 'Block Equation Studio'
                  : 'Inline Equation Studio',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: showSource ? 'Hide LaTeX Source' : 'Show LaTeX Source',
            icon: Icon(showSource ? Icons.code_off : Icons.code, size: 18),
            onPressed: () => setState(() => showSource = !showSource),
          ),
        ],
      ),
      content: SizedBox(
        width: 720,
        height: (MediaQuery.sizeOf(context).height * 0.75).clamp(480.0, 800.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Live Rendered Preview Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colors.raised,
                borderRadius: BorderRadius.circular(OrbitRadius.card),
                border: Border.all(color: colors.border),
              ),
              constraints: const BoxConstraints(minHeight: 50, maxHeight: 85),
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: NoteMath(input.text, display: widget.display),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 2. Visual Equation Slots & Spacing Toolbar
            _VisualEquationStudioHeader(
              model: model,
              onUpdate: _applyModelUpdate,
            ),
            const SizedBox(height: 6),

            // 3. Raw TeX Source Input (Kept synced for power users & test compatibility)
            if (showSource) ...[
              TextField(
                key: const ValueKey('equation-source'),
                controller: input,
                focusNode: focus,
                minLines: 1,
                maxLines: 2,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'LaTeX Source',
                  helperText:
                      'Tab moves to next placeholder. Visual slots update this live.',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 6),
            ],

            // 4. Symbol Search & Categories
            TextField(
              key: const ValueKey('latex-search'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 18),
                hintText: 'Search 200+ math symbols or names…',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              onChanged: (v) => setState(() => query = v),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final name in {
                    'All',
                    ...latexCatalog.map((e) => e.category),
                  })
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(name, style: const TextStyle(fontSize: 11)),
                        selected: category == name,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setState(() => category = name),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // 5. Symbol Grid / List
            Expanded(
              child: ListView.builder(
                itemCount: entries.length,
                itemBuilder: (_, i) {
                  final entry = entries[i];
                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: Text(
                      entry.name,
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      entry.source,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: colors.subtle),
                    ),
                    leading: SizedBox(
                      width: 44,
                      child: FittedBox(child: NoteMath(entry.source)),
                    ),
                    onTap: () => insert(entry),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${entries.length} entries · click symbol to insert · Tab cycles placeholders',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, input.text),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

/// Visual studio toolbar and interactive slot cards for fractions, scripts, and spacing.
class _VisualEquationStudioHeader extends StatelessWidget {
  const _VisualEquationStudioHeader({
    required this.model,
    required this.onUpdate,
  });

  final VisualMathModel model;
  final ValueChanged<String> onUpdate;

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final hasFractions = model.hasFractions;
    final hasScripts = model.hasScripts;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(OrbitRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // One-click spacing actions row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Spacing & Rows: ',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.subtle,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                _StudioChip(
                  tooltip: 'Add space between equations (\\quad)',
                  label: '+ Space (\\quad)',
                  icon: Icons.space_bar,
                  onTap: () => onUpdate(model.addSpacing()),
                ),
                const SizedBox(width: 4),
                _StudioChip(
                  tooltip: 'Add wide space (\\qquad)',
                  label: '+ Wide (\\qquad)',
                  icon: Icons.space_bar,
                  onTap: () =>
                      onUpdate(model.addSpacing(spaceToken: r'\qquad ')),
                ),
                const SizedBox(width: 4),
                _StudioChip(
                  tooltip: 'Add new equation line or vertical space (\\\\)',
                  label: '+ New Line (\\\\)',
                  icon: Icons.keyboard_return,
                  onTap: () => onUpdate(model.addLineBreak()),
                ),
                const SizedBox(width: 8),
                _StudioChip(
                  tooltip: 'Insert fraction structure',
                  label: 'Fraction (a/b)',
                  icon: Icons.horizontal_rule,
                  onTap: () => onUpdate(model.insertFraction()),
                ),
                const SizedBox(width: 4),
                _StudioChip(
                  tooltip: 'Insert subscript (number below)',
                  label: 'xₙ Sub',
                  icon: Icons.subscript,
                  onTap: () => onUpdate(model.insertSubscript(r'\square')),
                ),
              ],
            ),
          ),

          // Interactive Visual Fraction / Slot Cards
          if (hasFractions || hasScripts) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < model.fractions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _StudioFractionCard(
                      fractionIndex: i,
                      fraction: model.fractions[i],
                      onNumeratorChanged: (val) {
                        onUpdate(model.updateFractionNumerator(i, val));
                      },
                      onDenominatorChanged: (val) {
                        onUpdate(model.updateFractionDenominator(i, val));
                      },
                    ),
                  ],
                  for (var i = 0; i < model.scripts.length; i++)
                    if (model.scripts[i].subscript != null) ...[
                      const SizedBox(width: 8),
                      _StudioScriptCard(
                        script: model.scripts[i],
                        onSubscriptChanged: (val) {
                          onUpdate(model.updateScriptSubscript(i, val));
                        },
                      ),
                    ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StudioChip extends StatelessWidget {
  const _StudioChip({
    required this.tooltip,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OrbitRadius.control),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colors.raised,
            borderRadius: BorderRadius.circular(OrbitRadius.control),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: colors.accent),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A visual card for editing a fraction with direct top (numerator)
/// and bottom (denominator - "the number below it") slots and Arrow Up/Down navigation.
class _StudioFractionCard extends StatefulWidget {
  const _StudioFractionCard({
    required this.fractionIndex,
    required this.fraction,
    required this.onNumeratorChanged,
    required this.onDenominatorChanged,
  });

  final int fractionIndex;
  final VisualFraction fraction;
  final ValueChanged<String> onNumeratorChanged;
  final ValueChanged<String> onDenominatorChanged;

  @override
  State<_StudioFractionCard> createState() => _StudioFractionCardState();
}

class _StudioFractionCardState extends State<_StudioFractionCard> {
  late final TextEditingController _numCtrl;
  late final TextEditingController _denCtrl;
  final FocusNode _numFocus = FocusNode();
  final FocusNode _denFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _numCtrl = TextEditingController(text: widget.fraction.numerator);
    _denCtrl = TextEditingController(text: widget.fraction.denominator);

    // Arrow key navigation between top and bottom slots
    _numFocus.onKeyEvent = (_, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _denFocus.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    _denFocus.onKeyEvent = (_, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _numFocus.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  @override
  void didUpdateWidget(covariant _StudioFractionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fraction.numerator != _numCtrl.text && !_numFocus.hasFocus) {
      _numCtrl.text = widget.fraction.numerator;
    }
    if (widget.fraction.denominator != _denCtrl.text && !_denFocus.hasFocus) {
      _denCtrl.text = widget.fraction.denominator;
    }
  }

  @override
  void dispose() {
    _numCtrl.dispose();
    _denCtrl.dispose();
    _numFocus.dispose();
    _denFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    return Container(
      key: ValueKey('visual-fraction-${widget.fractionIndex}'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(OrbitRadius.control),
        border: Border.all(color: colors.accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Numerator input
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Top: ',
                style: TextStyle(fontSize: 11, color: colors.subtle),
              ),
              SizedBox(
                width: 90,
                height: 28,
                child: TextField(
                  key: ValueKey('visual-numerator-${widget.fractionIndex}'),
                  controller: _numCtrl,
                  focusNode: _numFocus,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                  ),
                  onChanged: widget.onNumeratorChanged,
                ),
              ),
            ],
          ),
          // Fraction bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            width: 125,
            height: 2,
            color: colors.accent,
          ),
          // Denominator input ("write the number below it")
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bottom: ',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(
                width: 90,
                height: 28,
                child: TextField(
                  key: ValueKey('visual-denominator-${widget.fractionIndex}'),
                  controller: _denCtrl,
                  focusNode: _denFocus,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'number below',
                    hintStyle: TextStyle(
                      fontSize: 10,
                      color: colors.subtle.withValues(alpha: 0.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                  ),
                  onChanged: widget.onDenominatorChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudioScriptCard extends StatefulWidget {
  const _StudioScriptCard({
    required this.script,
    required this.onSubscriptChanged,
  });

  final VisualScript script;
  final ValueChanged<String> onSubscriptChanged;

  @override
  State<_StudioScriptCard> createState() => _StudioScriptCardState();
}

class _StudioScriptCardState extends State<_StudioScriptCard> {
  late final TextEditingController _subCtrl;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _subCtrl = TextEditingController(text: widget.script.subscript ?? '');
  }

  @override
  void didUpdateWidget(covariant _StudioScriptCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.script.subscript != null &&
        widget.script.subscript != _subCtrl.text &&
        !_focus.hasFocus) {
      _subCtrl.text = widget.script.subscript!;
    }
  }

  @override
  void dispose() {
    _subCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(OrbitRadius.control),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.script.base} (below): ',
            style: TextStyle(
              fontSize: 11,
              color: colors.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(
            width: 70,
            height: 28,
            child: TextField(
              controller: _subCtrl,
              focusNode: _focus,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
              ),
              onChanged: widget.onSubscriptChanged,
            ),
          ),
        ],
      ),
    );
  }
}
