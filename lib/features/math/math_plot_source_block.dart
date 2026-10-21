import 'package:flutter/material.dart';
import '../../domain/math_plot_definition.dart';
import '../notes/rich/code_block.dart';
import '../notes/read_search_overlay.dart';
import 'math_plot_block.dart';

/// Keeps graph parsing off the typing/hover path. Unknown recipes stay code.
class MathPlotSourceBlock extends StatefulWidget {
  const MathPlotSourceBlock({
    super.key,
    required this.source,
    this.onEdit,
    this.onSourceChanged,
    this.onUndo,
    this.onRedo,
    this.onFocused,
  });
  final String source;
  final Future<MathPlotDefinition?> Function(MathPlotDefinition)? onEdit;
  final ValueChanged<String>? onSourceChanged;
  final VoidCallback? onUndo, onRedo, onFocused;
  @override
  State<MathPlotSourceBlock> createState() => MathPlotSourceBlockState();
}

class MathPlotSourceBlockState extends State<MathPlotSourceBlock> {
  MathPlotDefinition? _definition;
  bool _sourceEditing = false;
  final _codeKey = GlobalKey<NoteCodeBlockState>();
  bool selectSource(int offset, {int length = 0, bool requestFocus = true}) {
    final existing = _codeKey.currentState;
    if (existing != null) {
      return existing.selectSource(
        offset,
        length: length,
        requestFocus: requestFocus,
      );
    }
    final original = widget.source;
    setState(() => _sourceEditing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.source == original) {
        _codeKey.currentState?.selectSource(
          offset,
          length: length,
          requestFocus: requestFocus,
        );
      }
    });
    return true;
  }

  @override
  void initState() {
    super.initState();
    _definition = MathPlotDefinition.tryParse(widget.source);
    _sourceEditing = _definition == null;
  }

  @override
  void didUpdateWidget(MathPlotSourceBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _definition = MathPlotDefinition.tryParse(widget.source);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _definition;
    final searching =
        ReadSearchActivity.of(context) && widget.onSourceChanged == null;
    if (d == null || _sourceEditing || searching) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (d != null && !searching)
            TextButton(
              onPressed: () {
                if (_codeKey
                        .currentState
                        ?.controller
                        .value
                        .composing
                        .isCollapsed ==
                    false) {
                  return;
                }
                setState(() => _sourceEditing = false);
              },
              child: const Text('Show plot'),
            ),
          NoteCodeBlock(
            key: _codeKey,
            code: widget.source,
            language: 'orbit-plot',
            onChanged: widget.onSourceChanged,
            onUndo: widget.onUndo,
            onRedo: widget.onRedo,
            onFocused: widget.onFocused,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.onSourceChanged != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _sourceEditing = true),
              child: const Text('Edit plot source'),
            ),
          ),
        MathPlotBlock(
          definition: d,
          onEdit: widget.onEdit == null
              ? null
              : () async {
                  final before = widget.source;
                  final result = await widget.onEdit!(d);
                  if (!mounted || result == null || widget.source != before) {
                    return;
                  }
                  widget.onSourceChanged?.call(result.json);
                },
        ),
      ],
    );
  }
}
