import 'package:flutter/material.dart';
import '../../app/orbit_theme.dart';

/// Shows the compact "Go to Line" modal dialog.
///
/// Allows jumping to a 1-indexed line and optional column (e.g. `24` or `24:5`).
Future<({int line, int column})?> showGoToLineDialog(
  BuildContext context, {
  required int totalLines,
  required int currentLine,
  int currentColumn = 1,
}) {
  return showDialog<({int line, int column})>(
    context: context,
    builder: (ctx) => _GoToLineDialog(
      totalLines: totalLines,
      currentLine: currentLine,
      currentColumn: currentColumn,
    ),
  );
}

class _GoToLineDialog extends StatefulWidget {
  const _GoToLineDialog({
    required this.totalLines,
    required this.currentLine,
    required this.currentColumn,
  });

  final int totalLines;
  final int currentLine;
  final int currentColumn;

  @override
  State<_GoToLineDialog> createState() => _GoToLineDialogState();
}

class _GoToLineDialogState extends State<_GoToLineDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.currentColumn > 1
        ? '${widget.currentLine}:${widget.currentColumn}'
        : '${widget.currentLine}',
  );
  final FocusNode _focusNode = FocusNode();
  String? _error;
  late ({int line, int column})? _target;

  @override
  void initState() {
    super.initState();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
    _target = _parse(_controller.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  ({int line, int column})? _parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final match = RegExp(r'^(\d+)(?:[:,\s]+(\d+))?$').firstMatch(text);
    if (match == null) return null;

    final parsedLine = int.tryParse(match.group(1)!);
    if (parsedLine == null) return null;

    final parsedCol = match.group(2) != null
        ? int.tryParse(match.group(2)!) ?? 1
        : 1;

    final line = parsedLine.clamp(1, widget.totalLines);
    final col = parsedCol < 1 ? 1 : parsedCol;
    return (line: line, column: col);
  }

  void _onChanged(String value) {
    final parsed = _parse(value);
    setState(() {
      _target = parsed;
      if (value.trim().isNotEmpty && parsed == null) {
        _error = 'Enter a valid line number or line:col';
      } else {
        _error = null;
      }
    });
  }

  void _submit() {
    final parsed = _parse(_controller.text);
    if (parsed != null) {
      Navigator.of(context).pop(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = OrbitColors.of(context);

    return Dialog(
      backgroundColor: c.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.format_line_spacing_rounded,
                      size: 18,
                      color: c.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Go to Line',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: c.text,
                          ),
                        ),
                        Text(
                          'Lines 1 to ${widget.totalLines}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: c.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Input field
              TextField(
                key: const ValueKey('go-to-line-input'),
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                style: TextStyle(fontSize: 14, color: c.text),
                decoration: InputDecoration(
                  hintText: 'line[:column] (e.g. 24 or 24:5)',
                  hintStyle: TextStyle(fontSize: 13, color: c.muted),
                  isDense: true,
                  filled: true,
                  fillColor: c.raised,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: c.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: c.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: c.accent, width: 1.5),
                  ),
                  errorText: _error,
                  prefixIcon: Icon(
                    Icons.pin_drop_outlined,
                    size: 18,
                    color: c.muted,
                  ),
                ),
                onChanged: _onChanged,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),

              // Target preview
              if (_target != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'Jump to Ln ${_target!.line}, Col ${_target!.column}',
                    style: TextStyle(
                      fontSize: 11,
                      color: c.accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel', style: TextStyle(color: c.muted)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const ValueKey('go-to-line-submit'),
                    onPressed: _target != null ? _submit : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: OrbitColors.of(context).onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    child: const Text('Go'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
