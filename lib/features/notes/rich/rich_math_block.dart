import 'package:flutter/material.dart';
import '../../../app/orbit_theme.dart';
import 'note_math.dart';
import 'visual_math_model.dart';
import 'math_grid_editor.dart';

/// Direct fraction fields inside the document; complex TeX retains its renderer.
class EditableMathExpression extends StatelessWidget {
  const EditableMathExpression({
    super.key,
    required this.source,
    required this.onChanged,
  });
  final String source;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final model = VisualMathModel(source);
    if (model.fractions.isEmpty ||
        source.contains(r'\begin') ||
        source.contains(r'\left')) {
      return NoteMath(source, onEdit: onChanged);
    }
    final children = <Widget>[];
    var offset = 0;
    for (var i = 0; i < model.fractions.length; i++) {
      final fraction = model.fractions[i];
      if (fraction.startIndex < offset) continue;
      final before = source.substring(offset, fraction.startIndex);
      if (before.trim().isNotEmpty) children.add(NoteMath(before));
      children.add(
        _FractionSlotGroup(
          fraction: fraction,
          fractionIndex: i,
          onNumeratorChanged: (v) =>
              onChanged(model.updateFractionNumerator(i, v)),
          onDenominatorChanged: (v) =>
              onChanged(model.updateFractionDenominator(i, v)),
        ),
      );
      offset = fraction.endIndex;
    }
    final after = source.substring(offset);
    if (after.trim().isNotEmpty) children.add(NoteMath(after));
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: children,
    );
  }
}

/// A rich, in-place interactive block for LaTeX equations.
/// Provides direct visual slot editing (e.g. clicking below the fraction line
/// to write the denominator) and one-click spacing actions directly in the
/// rich editor without opening raw TeX code.
class RichMathBlock extends StatefulWidget {
  const RichMathBlock({
    super.key,
    required this.content,
    required this.onChanged,
  });

  final String content;
  final ValueChanged<String> onChanged;

  @override
  State<RichMathBlock> createState() => _RichMathBlockState();
}

class _RichMathBlockState extends State<RichMathBlock> {
  bool _hovered = false;
  bool _showSlots = true;

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final model = VisualMathModel(widget.content);
    final hasFractions = model.hasFractions;
    final hasScripts = model.hasScripts;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _hovered
              ? colors.raised.withValues(alpha: 0.4)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(OrbitRadius.card),
          border: Border.all(
            color: _hovered ? colors.border : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Floating quick toolbar for direct spacing & structure without opening code
            AnimatedOpacity(
              opacity: 1.0,
              duration: OrbitMotion.micro,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (MathGrid.parse(widget.content) != null)
                      _ToolbarButton(
                        tooltip: 'Edit equation cells',
                        icon: Icons.grid_on,
                        label: 'Edit grid',
                        onPressed: () async {
                          final original = widget.content;
                          final result = await showMathGrid(
                            context,
                            initial: MathGrid.parse(original),
                          );
                          if (result != null &&
                              mounted &&
                              widget.content == original) {
                            widget.onChanged(result);
                          }
                        },
                      ),
                    // Add space between equations without opening code
                    _ToolbarButton(
                      tooltip: 'Add space between equations or terms (\\quad)',
                      icon: Icons.space_bar,
                      label: '+ Space',
                      onPressed: () {
                        final updated = model.addSpacing();
                        widget.onChanged(updated);
                      },
                    ),
                    // Add new line / line break between equations
                    _ToolbarButton(
                      tooltip: 'Add line break between equations (\\\\)',
                      icon: Icons.keyboard_return,
                      label: '+ Line Break',
                      onPressed: () {
                        final updated = model.addLineBreak();
                        widget.onChanged(updated);
                      },
                    ),
                    // Wrap or insert fraction
                    _ToolbarButton(
                      tooltip: 'Add fraction (\\frac{top}{bottom})',
                      icon: Icons.horizontal_rule,
                      label: 'a/b Fraction',
                      onPressed: () {
                        final updated = model.insertFraction();
                        widget.onChanged(updated);
                      },
                    ),
                    // Add subscript (number below)
                    _ToolbarButton(
                      tooltip: 'Add subscript (number below it)',
                      icon: Icons.subscript,
                      label: 'xₙ Sub',
                      onPressed: () {
                        final updated = model.insertSubscript(r'\square');
                        widget.onChanged(updated);
                      },
                    ),
                    // Toggle in-place visual slots
                    if (hasFractions || hasScripts)
                      _ToolbarButton(
                        tooltip: _showSlots
                            ? 'Hide visual slots'
                            : 'Show visual slots',
                        icon: _showSlots ? Icons.visibility_off : Icons.tune,
                        label: _showSlots ? 'Hide Slots' : 'Edit Slots',
                        onPressed: () =>
                            setState(() => _showSlots = !_showSlots),
                      ),
                  ],
                ),
              ),
            ),

            // Live rendered math equation
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: NoteMath(
                widget.content,
                display: true,
                onEdit: widget.onChanged,
              ),
            ),

            // In-place visual slots (e.g. clicking directly to write the number below it)
            if (_showSlots && (hasFractions || hasScripts))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _InPlaceVisualSlots(
                  model: model,
                  onChanged: (newTex) {
                    widget.onChanged(newTex);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.raised,
        borderRadius: BorderRadius.circular(OrbitRadius.control),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(OrbitRadius.control),
          hoverColor: colors.hover,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: colors.accent),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// In-place visual slot chips allowing the user to click directly on the
/// numerator, denominator ("the number below it"), or subscript to edit them.
class _InPlaceVisualSlots extends StatefulWidget {
  const _InPlaceVisualSlots({required this.model, required this.onChanged});

  final VisualMathModel model;
  final ValueChanged<String> onChanged;

  @override
  State<_InPlaceVisualSlots> createState() => _InPlaceVisualSlotsState();
}

class _InPlaceVisualSlotsState extends State<_InPlaceVisualSlots> {
  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final model = widget.model;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.panel.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(OrbitRadius.control),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: [
          // Fractions slots
          for (var i = 0; i < model.fractions.length; i++)
            _FractionSlotGroup(
              fraction: model.fractions[i],
              fractionIndex: i,
              onNumeratorChanged: (val) {
                final updated = model.updateFractionNumerator(i, val);
                widget.onChanged(updated);
              },
              onDenominatorChanged: (val) {
                final updated = model.updateFractionDenominator(i, val);
                widget.onChanged(updated);
              },
            ),

          // Subscripts slots
          for (var i = 0; i < model.scripts.length; i++)
            if (model.scripts[i].subscript != null)
              _ScriptSlotGroup(
                script: model.scripts[i],
                onSubscriptChanged: (val) {
                  final updated = model.updateScriptSubscript(i, val);
                  widget.onChanged(updated);
                },
              ),
        ],
      ),
    );
  }
}

class _FractionSlotGroup extends StatefulWidget {
  const _FractionSlotGroup({
    required this.fraction,
    required this.fractionIndex,
    required this.onNumeratorChanged,
    required this.onDenominatorChanged,
  });

  final VisualFraction fraction;
  final int fractionIndex;
  final ValueChanged<String> onNumeratorChanged;
  final ValueChanged<String> onDenominatorChanged;

  @override
  State<_FractionSlotGroup> createState() => _FractionSlotGroupState();
}

class _FractionSlotGroupState extends State<_FractionSlotGroup> {
  late final TextEditingController _numCtrl;
  late final TextEditingController _denCtrl;
  final FocusNode _numFocus = FocusNode();
  final FocusNode _denFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _numCtrl = TextEditingController(text: widget.fraction.numerator);
    _denCtrl = TextEditingController(text: widget.fraction.denominator);
  }

  @override
  void didUpdateWidget(covariant _FractionSlotGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fraction.numerator != _numCtrl.text) {
      _numCtrl.value = TextEditingValue(
        text: widget.fraction.numerator,
        selection: TextSelection.collapsed(
          offset: _numCtrl.selection.extentOffset.clamp(
            0,
            widget.fraction.numerator.length,
          ),
        ),
      );
    }
    if (widget.fraction.denominator != _denCtrl.text) {
      _denCtrl.value = TextEditingValue(
        text: widget.fraction.denominator,
        selection: TextSelection.collapsed(
          offset: _denCtrl.selection.extentOffset.clamp(
            0,
            widget.fraction.denominator.length,
          ),
        ),
      );
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(OrbitRadius.control),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top / Numerator slot
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Top: ',
                style: TextStyle(fontSize: 11, color: colors.subtle),
              ),
              SizedBox(
                width: 65,
                height: 26,
                child: TextField(
                  key: ValueKey('frac-num-${widget.fractionIndex}'),
                  controller: _numCtrl,
                  focusNode: _numFocus,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.text,
                    fontFamily: 'monospace',
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                  ),
                  onSubmitted: widget.onNumeratorChanged,
                  onChanged: widget.onNumeratorChanged,
                ),
              ),
            ],
          ),
          // Fraction line
          Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            width: 95,
            height: 1.5,
            color: colors.accent.withValues(alpha: 0.6),
          ),
          // Bottom / Denominator slot ("write the number below it")
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bottom: ',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(
                width: 65,
                height: 26,
                child: TextField(
                  key: ValueKey('frac-den-${widget.fractionIndex}'),
                  controller: _denCtrl,
                  focusNode: _denFocus,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.text,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'below',
                    hintStyle: TextStyle(
                      fontSize: 10,
                      color: colors.subtle.withValues(alpha: 0.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                  ),
                  onSubmitted: widget.onDenominatorChanged,
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

class _ScriptSlotGroup extends StatefulWidget {
  const _ScriptSlotGroup({
    required this.script,
    required this.onSubscriptChanged,
  });

  final VisualScript script;
  final ValueChanged<String> onSubscriptChanged;

  @override
  State<_ScriptSlotGroup> createState() => _ScriptSlotGroupState();
}

class _ScriptSlotGroupState extends State<_ScriptSlotGroup> {
  late final TextEditingController _subCtrl;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _subCtrl = TextEditingController(text: widget.script.subscript ?? '');
  }

  @override
  void didUpdateWidget(covariant _ScriptSlotGroup oldWidget) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(
            width: 55,
            height: 26,
            child: TextField(
              controller: _subCtrl,
              focusNode: _focus,
              style: TextStyle(
                fontSize: 12,
                color: colors.text,
                fontFamily: 'monospace',
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
              ),
              onSubmitted: widget.onSubscriptChanged,
              onChanged: widget.onSubscriptChanged,
            ),
          ),
        ],
      ),
    );
  }
}
