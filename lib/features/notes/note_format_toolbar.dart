import '../../app/orbit_density.dart';
import 'package:flutter/material.dart';
import '../../app/orbit_theme.dart';

enum NoteFormatAction {
  heading,
  bold,
  italic,
  underline,
  strike,
  highlight,
  bullet,
  numbered,
  checklist,
  quote,
  inlineCode,
  codeBlock,
  table,
  link,
  math,
  alignLeft,
  alignCenter,
  alignRight,
}

class NoteFormatToolbar extends StatelessWidget {
  const NoteFormatToolbar({
    super.key,
    required this.onFormat,
    required this.undoController,
    this.onInsertAttachment,
    this.onPasteImage,
    this.onCommand,
    this.formatStates = const {},
  });

  final ValueChanged<NoteFormatAction> onFormat;
  final UndoHistoryController undoController;
  final VoidCallback? onInsertAttachment;
  final VoidCallback? onPasteImage;
  final ValueChanged<String>? onCommand;
  final Map<NoteFormatAction, String> formatStates;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      height: OrbitDensity.of(context).controlHeight + 12,
      decoration: BoxDecoration(
        color: OrbitColors.of(context).panel,
        border: Border.all(color: OrbitColors.of(context).border),
        borderRadius: BorderRadius.circular(OrbitRadius.control),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButtonTheme(
        data: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: Size.square(OrbitDensity.of(context).smallControl),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(OrbitRadius.control),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (onCommand != null)
                        IconButton(
                          tooltip: 'Format block',
                          icon: const Icon(
                            Icons.view_agenda_outlined,
                            size: 18,
                          ),
                          onPressed: () => onCommand!('Format block'),
                        ),
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
                                    'Highlight',
                                    'Underline',
                                    'Footnote',
                                    'Code block',
                                    'Table',
                                    'Inline equation',
                                    'Block equation',
                                    'Image / file',
                                    'Image and text',
                                    'Two columns',
                                    'Three columns',
                                    'Inline drawing',
                                    'Live object',
                                    'Convert selection',
                                    'Linked section',
                                    'Comment on selection',
                                    'Suggest replacement',
                                    'Review annotations',
                                    'Horizontal rule',
                                    'BTW block',
                                    'Math Lab',
                                  ]
                                  .map(
                                    (label) => PopupMenuItem(
                                      value: label,
                                      child: Text(label),
                                    ),
                                  )
                                  .toList(),
                        ),
                      for (final (action, icon, label) in const [
                        (
                          NoteFormatAction.alignLeft,
                          Icons.format_align_left,
                          'Align left',
                        ),
                        (
                          NoteFormatAction.alignCenter,
                          Icons.format_align_center,
                          'Align center',
                        ),
                        (
                          NoteFormatAction.alignRight,
                          Icons.format_align_right,
                          'Align right',
                        ),
                        (
                          NoteFormatAction.heading,
                          Icons.title_rounded,
                          'Heading',
                        ),
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
                          NoteFormatAction.underline,
                          Icons.format_underlined_rounded,
                          'Underline · Ctrl+U',
                        ),
                        (
                          NoteFormatAction.strike,
                          Icons.strikethrough_s_rounded,
                          'Strikethrough',
                        ),
                        (
                          NoteFormatAction.highlight,
                          Icons.highlight_rounded,
                          'Highlight · Ctrl+Shift+H',
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
                        (
                          NoteFormatAction.quote,
                          Icons.format_quote_rounded,
                          'Quote',
                        ),
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
                        (
                          NoteFormatAction.table,
                          Icons.table_chart_outlined,
                          'Table',
                        ),
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
                        if (!{
                          NoteFormatAction.strike,
                          NoteFormatAction.quote,
                          NoteFormatAction.inlineCode,
                          NoteFormatAction.codeBlock,
                          NoteFormatAction.table,
                          NoteFormatAction.math,
                        }.contains(action)) ...[
                          if (action == NoteFormatAction.bullet ||
                              action == NoteFormatAction.inlineCode)
                            const SizedBox(
                              height: 16,
                              child: VerticalDivider(width: 12),
                            ),
                          IconButton(
                            tooltip: formatStates[action] == 'mixed'
                                ? '$label · Mixed formatting'
                                : label,
                            isSelected: formatStates[action] == 'on',
                            selectedIcon: Icon(icon, size: 18),
                            icon: Icon(icon, size: 18),
                            onPressed: () => onFormat(action),
                            visualDensity: VisualDensity.standard,
                          ),
                        ],
                      ],
                      PopupMenuButton<NoteFormatAction>(
                        tooltip: 'More formatting',
                        icon: const Icon(Icons.more_horiz, size: 18),
                        onSelected: onFormat,
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: NoteFormatAction.strike,
                            child: Text('Strikethrough'),
                          ),
                          PopupMenuItem(
                            value: NoteFormatAction.quote,
                            child: Text('Quote'),
                          ),
                          PopupMenuItem(
                            value: NoteFormatAction.inlineCode,
                            child: Text('Inline code'),
                          ),
                          PopupMenuItem(
                            value: NoteFormatAction.codeBlock,
                            child: Text('Code block'),
                          ),
                          PopupMenuItem(
                            value: NoteFormatAction.table,
                            child: Text('Table'),
                          ),
                          PopupMenuItem(
                            value: NoteFormatAction.math,
                            child: Text('Equation · LaTeX'),
                          ),
                        ],
                      ),
                      if (onInsertAttachment != null)
                        IconButton(
                          tooltip: 'Insert attachment',
                          icon: const Icon(Icons.attach_file_rounded, size: 18),
                          onPressed: onInsertAttachment,
                          visualDensity: VisualDensity.standard,
                        ),
                      if (onPasteImage != null)
                        IconButton(
                          tooltip: 'Paste image · Ctrl+Shift+V',
                          icon: const Icon(
                            Icons.content_paste_go_rounded,
                            size: 18,
                          ),
                          onPressed: onPasteImage,
                          visualDensity: VisualDensity.standard,
                        ),
                    ],
                  ),
                ),
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
                      visualDensity: VisualDensity.standard,
                    ),
                    IconButton(
                      tooltip: 'Redo · Ctrl+Shift+Z',
                      onPressed: value.canRedo ? undoController.redo : null,
                      icon: const Icon(Icons.redo_rounded, size: 18),
                      visualDensity: VisualDensity.standard,
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
