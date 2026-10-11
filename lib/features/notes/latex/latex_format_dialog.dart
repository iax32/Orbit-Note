import 'package:flutter/material.dart';
import 'latex_converter.dart';
import 'latex_preview.dart';

enum FormatConversionAction { cancel, convertInPlace, createCopy }

/// Modal dialog for safe, explicit switching between Markdown and LaTeX formats.
/// Never performs silent or destructive format changes.
class FormatConversionDialog extends StatefulWidget {
  const FormatConversionDialog({
    super.key,
    required this.title,
    required this.body,
    required this.currentFormat,
  });

  final String title;
  final String body;
  final String currentFormat; // 'markdown' or 'latex'

  static Future<({FormatConversionAction action, String convertedBody})?> show(
    BuildContext context, {
    required String title,
    required String body,
    required String currentFormat,
  }) {
    return showDialog<({FormatConversionAction action, String convertedBody})>(
      context: context,
      builder: (_) => FormatConversionDialog(
        title: title,
        body: body,
        currentFormat: currentFormat,
      ),
    );
  }

  @override
  State<FormatConversionDialog> createState() => _FormatConversionDialogState();
}

class _FormatConversionDialogState extends State<FormatConversionDialog> {
  late final bool _isToLatex = widget.currentFormat != 'latex';
  late final LatexConversionResult _result;
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    if (_isToLatex) {
      _result = LatexConverter.markdownToLatex(
        widget.body,
        title: widget.title.isEmpty ? 'Untitled Document' : widget.title,
      );
    } else {
      _result = LatexConverter.latexToMarkdown(widget.body);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final targetFormatName = _isToLatex ? 'LaTeX' : 'Markdown';
    final currentFormatName = _isToLatex ? 'Markdown' : 'LaTeX';

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isToLatex ? Icons.functions_rounded : Icons.description_outlined,
            color: const Color(0xFF8B7CF6),
            size: 22,
          ),
          const SizedBox(width: 10),
          Text('Convert to $targetFormatName'),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF23252E)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Converting from $currentFormatName to $targetFormatName',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        icon: Icon(
                          _showPreview
                              ? Icons.info_outline
                              : Icons.visibility_outlined,
                          size: 16,
                        ),
                        label: Text(
                          _showPreview ? 'Show Details' : 'Preview Output',
                        ),
                        onPressed: () =>
                            setState(() => _showPreview = !_showPreview),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isToLatex
                        ? 'Headings become \\section commands, math blocks are wrapped in equation environments, and academic packages (amsmath, amssymb, amsthm) are initialized.'
                        : 'LaTeX sections become Markdown headings, theorem environments become styled callouts, and equations are mapped to display math.',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            if (_result.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: Colors.amber,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Conversion Notices',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    for (final w in _result.warnings)
                      Padding(
                        padding: const EdgeInsets.only(left: 22, top: 2),
                        child: Text(
                          '• $w',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            Expanded(
              child: _showPreview
                  ? Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: _isToLatex
                          ? LatexPreview(
                              latex: _result.converted,
                              contentWidth: 540,
                              fontSize: 13,
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: SelectableText(_result.converted),
                            ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF181A20)
                            : const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Source Preview',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${_result.converted.length} chars',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              child: SelectableText(
                                _result.converted,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(context, (
            action: FormatConversionAction.convertInPlace,
            convertedBody: _result.converted,
          )),
          child: const Text('Convert In-Place'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: Text('Create $targetFormatName Copy (Safe)'),
          onPressed: () => Navigator.pop(context, (
            action: FormatConversionAction.createCopy,
            convertedBody: _result.converted,
          )),
        ),
      ],
    );
  }
}
