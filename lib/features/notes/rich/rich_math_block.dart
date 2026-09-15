import 'package:flutter/material.dart';
import 'math_grid_editor.dart';
import 'structured_math_editor.dart';
import 'visual_math_model.dart';

export 'structured_math_editor.dart' show EditableMathExpression;

/// One editable expression, backed by source splices in the note's history.
class RichMathBlock extends StatefulWidget {
  const RichMathBlock({
    super.key,
    required this.content,
    required this.onChanged,
    this.onUndo,
    this.onRedo,
    this.autofocus = false,
  });
  final String content;
  final bool autofocus;
  final ValueChanged<String> onChanged;
  final VoidCallback? onUndo, onRedo;
  @override
  State<RichMathBlock> createState() => _RichMathBlockState();
}

class _RichMathBlockState extends State<RichMathBlock> {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: EditableMathExpression(
      source: widget.content,
      onChanged: widget.onChanged,
      display: true,
      autofocus: widget.autofocus,
      onUndo: widget.onUndo,
      onRedo: widget.onRedo,
      extraActions: [
        if (MathGrid.parse(widget.content) != null)
          TextButton(
            onPressed: () async {
              final original = widget.content;
              final result = await showMathGrid(
                context,
                initial: MathGrid.parse(original),
              );
              if (result != null && mounted && widget.content == original) {
                widget.onChanged(result);
              }
            },
            child: const Text('Edit grid'),
          ),
        TextButton(
          onPressed: () =>
              widget.onChanged(VisualMathModel(widget.content).addSpacing()),
          child: const Text('+ Space'),
        ),
        TextButton(
          onPressed: () =>
              widget.onChanged(VisualMathModel(widget.content).addLineBreak()),
          child: const Text('+ Line Break'),
        ),
      ],
    ),
  );
}
