import 'package:flutter/material.dart';
import '../../app/orbit_theme.dart';

enum NoteFormatAction {
  heading,
  bold,
  italic,
  strike,
  bullet,
  numbered,
  checklist,
  quote,
  inlineCode,
  codeBlock,
  table,
  link,
  math,
}

class NoteFormatToolbar extends StatelessWidget {
  const NoteFormatToolbar({
    super.key,
    required this.onFormat,
    required this.undoController,
    this.onInsertAttachment,
    this.onPasteImage,
    this.onCommand,
  });

  final ValueChanged<NoteFormatAction> onFormat;
  final UndoHistoryController undoController;
  final VoidCallback? onInsertAttachment;
  final VoidCallback? onPasteImage;
  final ValueChanged<String>? onCommand;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      height: 44,
      decoration: BoxDecoration(
        color: OrbitColors.of(context).panel,
        border: Border.all(color: OrbitColors.of(context).border),
        borderRadius: BorderRadius.circular(OrbitRadius.control),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(OrbitRadius.control),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onCommand != null)
                PopupMenuButton<String>(
                  tooltip: 'Insert block or equation',
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  onSelected: onCommand,
                  itemBuilder: (_) =>
                      [
                            'Text',
                            'Heading 1',
                            'Heading 2',
                            'Heading 3',
                            'Bullet list',
                            'Numbered list',
                            'Checklist',
                            'Quote',
                            'Callout',
                            'Code block',
                            'Table',
                            'Inline equation',
                            'Block equation',
                            'Image / file',
                            'Horizontal rule',
                          ]
                          .map(
                            (label) =>
                                PopupMenuItem(value: label, child: Text(label)),
                          )
                          .toList(),
                ),
              for (final (action, icon, label) in const [
                (NoteFormatAction.heading, Icons.title_rounded, 'Heading'),
                (
                  NoteFormatAction.bold,
                  Icons.format_bold_rounded,
                  'Bold · Ctrl+B',
                ),
                (
                  NoteFormatAction.italic,
                  Icons.format_italic_rounded,
                  'Italic · Ctrl+I',
                ),
                (
                  NoteFormatAction.strike,
                  Icons.strikethrough_s_rounded,
                  'Strikethrough',
                ),
                (
                  NoteFormatAction.bullet,
                  Icons.format_list_bulleted_rounded,
                  'Bullet list',
                ),
                (
                  NoteFormatAction.numbered,
                  Icons.format_list_numbered_rounded,
                  'Numbered list',
                ),
                (
                  NoteFormatAction.checklist,
                  Icons.checklist_rounded,
                  'Checklist',
                ),
                (NoteFormatAction.quote, Icons.format_quote_rounded, 'Quote'),
                (
                  NoteFormatAction.inlineCode,
                  Icons.code_rounded,
                  'Inline code',
                ),
                (
                  NoteFormatAction.codeBlock,
                  Icons.data_object_rounded,
                  'Code block',
                ),
                (NoteFormatAction.table, Icons.table_chart_outlined, 'Table'),
                (
                  NoteFormatAction.link,
                  Icons.add_link_rounded,
                  'Object link · Ctrl+K',
                ),
                (
                  NoteFormatAction.math,
                  Icons.functions_rounded,
                  'Equation · LaTeX',
                ),
              ]) ...[
                if (action == NoteFormatAction.bullet ||
                    action == NoteFormatAction.inlineCode)
                  const SizedBox(height: 16, child: VerticalDivider(width: 12)),
                IconButton(
                  tooltip: label,
                  icon: Icon(icon, size: 18),
                  onPressed: () => onFormat(action),
                  visualDensity: VisualDensity.compact,
                ),
              ],
              if (onInsertAttachment != null)
                IconButton(
                  tooltip: 'Insert attachment',
                  icon: const Icon(Icons.attach_file_rounded, size: 18),
                  onPressed: onInsertAttachment,
                  visualDensity: VisualDensity.compact,
                ),
              if (onPasteImage != null)
                IconButton(
                  tooltip: 'Paste image · Ctrl+Shift+V',
                  icon: const Icon(Icons.content_paste_go_rounded, size: 18),
                  onPressed: onPasteImage,
                  visualDensity: VisualDensity.compact,
                ),
              const SizedBox(height: 20, child: VerticalDivider()),
              ValueListenableBuilder<UndoHistoryValue>(
                valueListenable: undoController,
                builder: (context, value, _) => Row(
                  children: [
                    IconButton(
                      tooltip: 'Undo · Ctrl+Z',
                      onPressed: value.canUndo ? undoController.undo : null,
                      icon: const Icon(Icons.undo_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      tooltip: 'Redo · Ctrl+Shift+Z',
                      onPressed: value.canRedo ? undoController.redo : null,
                      icon: const Icon(Icons.redo_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
