import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import '../../domain/pdf_annotation.dart';
import '../../domain/object_reference.dart';
import '../../domain/pdf_quote_transfer.dart';

typedef SavePdfReview =
    Future<bool> Function(
      PdfAnnotation original,
      String body,
      int color,
      String style,
      bool resolved,
    );

class PdfPassageCommentDialog extends StatefulWidget {
  const PdfPassageCommentDialog({super.key, required this.onSave});
  final Future<bool> Function(String) onSave;
  @override
  State<PdfPassageCommentDialog> createState() =>
      _PdfPassageCommentDialogState();
}

class _PdfPassageCommentDialogState extends State<PdfPassageCommentDialog> {
  String text = '';
  bool busy = false;
  String? error;
  Future<void> save() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    var saved = false;
    try {
      saved = await widget.onSave(text);
    } catch (_) {}
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      busy = false;
      error =
          'Could not save. Your comment is kept here; retry or copy it before closing.';
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: OrbitDialog(
      title: const Text('Comment on this passage'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                enabled: !busy,
                minLines: 3,
                maxLines: 8,
                maxLength: 100000,
                decoration: const InputDecoration(
                  hintText: 'What would you like to remember?',
                ),
                onChanged: (v) => text = v,
              ),
              if (error != null) Text(error!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? 'Saving…' : 'Save highlight'),
        ),
      ],
    ),
  );
}

class PdfReviewPanel extends StatefulWidget {
  const PdfReviewPanel({
    super.key,
    required this.annotations,
    required this.page,
    required this.checksum,
    required this.onNavigate,
    required this.onClose,
    required this.onCopy,
    this.onOpen,
    this.onOpenSource,
    this.onEdit,
    this.onSummary,
    this.onExport,
    this.onAnnotatedCopy,
    this.savingAnnotatedCopy = false,
  });
  final List<PdfAnnotation> annotations;
  final int page;
  final String? checksum;
  final ValueChanged<PdfAnnotation> onNavigate;
  final VoidCallback onClose;
  final ValueChanged<List<PdfAnnotation>> onCopy;
  final ValueChanged<List<PdfAnnotation>>? onExport;
  final ValueChanged<List<PdfAnnotation>>? onAnnotatedCopy;
  final bool savingAnnotatedCopy;
  final ValueChanged<String>? onOpen;
  final VoidCallback? onOpenSource;
  final ValueChanged<PdfAnnotation>? onEdit;
  final Future<bool> Function(List<String>)? onSummary;
  @override
  State<PdfReviewPanel> createState() => _PdfReviewPanelState();
}

class _PdfReviewPanelState extends State<PdfReviewPanel> {
  String query = '', status = 'All', kind = 'All types', sort = 'Page';
  bool currentPage = false, saving = false;

  List<PdfAnnotation> get filtered {
    final items = widget.annotations.where((a) {
      return '${a.object.title}\n${a.source['quote']}\n${a.object.body}'
              .toLowerCase()
              .contains(query.trim().toLowerCase()) &&
          (status == 'All' ||
              (status == 'Resolved' ? a.resolved : !a.resolved)) &&
          (!currentPage ||
              a.regions.any((r) => r.data['page'] == widget.page)) &&
          (kind == 'All types' ||
              (kind == 'Page comments'
                  ? a.isPageComment
                  : !a.isPageComment && a.style == kind.toLowerCase()));
    }).toList();
    items.sort((a, b) {
      final order = sort == 'Newest'
          ? b.object.createdAt.compareTo(a.object.createdAt)
          : a.page.compareTo(b.page);
      return order != 0 ? order : a.object.id.compareTo(b.object.id);
    });
    return items;
  }

  Future<void> saveSummary(List<PdfAnnotation> items) async {
    setState(() => saving = true);
    var saved = false;
    try {
      saved = await widget.onSummary!(items.map((a) => a.object.id).toList());
    } catch (_) {
      /* The source and annotations remain available for retry. */
    }
    if (!mounted) return;
    setState(() => saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Review summary saved as a linked note.'
              : 'Could not save the summary. Please retry.',
        ),
      ),
    );
  }

  Widget choice(
    String value,
    List<String> values,
    ValueChanged<String> change,
  ) => PopupMenuButton<String>(
    tooltip: 'Review $value',
    initialValue: value,
    onSelected: (v) => setState(() => change(v)),
    itemBuilder: (_) => [
      for (final v in values) PopupMenuItem(value: v, child: Text(v)),
    ],
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(value)),
          const Icon(Icons.expand_more, size: 16),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final items = filtered;
    return Material(
      color: OrbitColors.of(context).raised,
      child: Container(
        height: math.min(310, MediaQuery.sizeOf(context).height * .43),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: OrbitColors.of(context).border),
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  OrbitPanelHeader(
                    icon: Icons.edit_note_rounded,
                    title: 'Highlights · ${widget.annotations.length}',
                    subtitle: 'Review and annotate this document',
                    actions: [
                      IconButton(
                        tooltip: 'Copy filtered review as Markdown',
                        onPressed: items.isEmpty
                            ? null
                            : () => widget.onCopy(items),
                        icon: const Icon(Icons.copy, size: 18),
                      ),
                      if (widget.onExport != null)
                        IconButton(
                          tooltip: 'Export filtered review as Markdown',
                          onPressed: items.isEmpty
                              ? null
                              : () => widget.onExport!(items),
                          icon: const Icon(Icons.download_outlined, size: 18),
                        ),
                      if (widget.onSummary != null)
                        IconButton(
                          tooltip: 'Save filtered review as note',
                          onPressed: saving || items.isEmpty
                              ? null
                              : () => saveSummary(items),
                          icon: const Icon(Icons.note_add_outlined, size: 18),
                        ),
                      if (widget.onAnnotatedCopy != null ||
                          widget.savingAnnotatedCopy)
                        IconButton(
                          tooltip: widget.savingAnnotatedCopy
                              ? 'Saving annotated PDF…'
                              : 'Save filtered review as annotated PDF',
                          onPressed: items.isEmpty || widget.savingAnnotatedCopy
                              ? null
                              : () => widget.onAnnotatedCopy!(items),
                          icon: const Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 18,
                          ),
                        ),
                      IconButton(
                        tooltip: 'Close highlights',
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Filter highlights and comments',
                        prefixIcon: Icon(Icons.search, size: 18),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => query = v),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        choice(status, [
                          'All',
                          'Open',
                          'Resolved',
                        ], (v) => status = v),
                        choice(kind, [
                          'All types',
                          'Highlight',
                          'Underline',
                          'Strikeout',
                          'Page comments',
                        ], (v) => kind = v),
                        choice(sort, ['Page', 'Newest'], (v) => sort = v),
                        FilterChip(
                          label: const Text('This page'),
                          selected: currentPage,
                          onSelected: (v) => setState(() => currentPage = v),
                        ),
                        const SizedBox(width: 12),
                        Text('${items.length} shown'),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (items.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No matching review items.'),
                ),
              )
            else
              SliverList.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final a = items[index];
                  final matches = a.matches(widget.checksum);
                  final quote = a.source['quote'];
                  return OrbitActionTile(
                    dense: true,
                    leading: Icon(
                      a.resolved
                          ? Icons.check_circle_outline
                          : a.isPageComment
                          ? Icons.sticky_note_2_outlined
                          : Icons.format_paint_outlined,
                      color: Color(a.color),
                    ),
                    title: Text(
                      quote is String && quote.isNotEmpty
                          ? quote
                          : a.object.title,
                    ),
                    subtitle: Text(
                      matches
                          ? 'Page ${a.page} · ${a.resolved ? 'Resolved' : 'Open'} · ${a.isPageComment ? 'Comment' : a.style}'
                          : 'PDF version changed · review source before re-anchoring',
                    ),
                    onTap: matches ? () => widget.onNavigate(a) : null,
                    actions: [
                      if (quote is String && quote.trim().isNotEmpty)
                        Tooltip(
                          message: 'Drag citation onto note or canvas',
                          child: Draggable<PdfQuoteDragData>(
                            data: PdfQuoteDragData(
                              objectId: a.fileId ?? '',
                              title: a.object.title.isNotEmpty
                                  ? a.object.title
                                  : 'PDF Document',
                              page: a.page,
                              text: quote.trim(),
                              checksum: widget.checksum,
                            ),
                            dragAnchorStrategy: pointerDragAnchorStrategy,
                            feedback: Material(
                              elevation: 6,
                              borderRadius: BorderRadius.circular(8),
                              color: OrbitColors.of(context).raised,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                constraints: const BoxConstraints(
                                  maxWidth: 260,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: OrbitColors.of(context).accent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.drag_indicator,
                                          size: 14,
                                          color: OrbitColors.of(context).accent,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            '${a.object.title.isNotEmpty ? a.object.title : 'PDF'} (p. ${a.page})',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: OrbitColors.of(
                                                context,
                                              ).accent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      quote.trim(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: OrbitColors.of(context).text,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 6,
                              ),
                              child: Icon(
                                Icons.drag_indicator,
                                size: 18,
                                color: OrbitColors.of(context).subtle,
                              ),
                            ),
                          ),
                        ),
                      if (widget.onEdit != null)
                        IconButton(
                          tooltip: 'Edit review item',
                          onPressed: matches && !a.object.isReadOnly
                              ? () => widget.onEdit!(a)
                              : null,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                        ),
                      if (quote is String && quote.trim().isNotEmpty)
                        IconButton(
                          tooltip: 'Copy quote text',
                          onPressed: () => Clipboard.setData(
                            ClipboardData(text: quote.trim()),
                          ),
                          icon: const Icon(
                            Icons.content_copy_outlined,
                            size: 18,
                          ),
                        ),
                      if (widget.onOpenSource != null)
                        IconButton(
                          tooltip: matches
                              ? 'Open PDF source'
                              : 'Open current PDF source to verify',
                          onPressed: widget.onOpenSource,
                          icon: const Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 18,
                          ),
                        ),
                      if (!matches)
                        Tooltip(
                          message:
                              'The source PDF changed. Review this item before using it.',
                          child: Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: OrbitColors.of(context).warning,
                          ),
                        ),
                      IconButton(
                        tooltip: 'Open highlight note and comments',
                        onPressed: widget.onOpen == null
                            ? null
                            : () => widget.onOpen!(a.object.id),
                        icon: const Icon(Icons.open_in_new, size: 18),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class PdfReviewEditor extends StatefulWidget {
  const PdfReviewEditor({
    super.key,
    required this.annotation,
    required this.colors,
    required this.onSave,
  });
  final PdfAnnotation annotation;
  final Map<String, int> colors;
  final SavePdfReview onSave;
  @override
  State<PdfReviewEditor> createState() => _PdfReviewEditorState();
}

class _PdfReviewEditorState extends State<PdfReviewEditor> {
  late final body = TextEditingController(text: widget.annotation.object.body);
  late int color = widget.annotation.color;
  late String style = widget.annotation.style;
  late bool resolved = widget.annotation.resolved;
  bool saving = false;
  String? error;
  @override
  void dispose() {
    body.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
    });
    var saved = false;
    try {
      saved = await widget.onSave(
        widget.annotation,
        body.text,
        color,
        style,
        resolved,
      );
    } catch (_) {
      /* Keep the draft visible on persistence failures. */
    }
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      saving = false;
      error =
          'Could not save, or the note/source changed. Your draft is kept here. Copy it before reopening the latest note.';
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: OrbitDialog(
      title: Text('Review · page ${widget.annotation.page}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: body,
                enabled: !saving,
                minLines: 4,
                maxLines: 10,
                maxLength: 1000000,
                decoration: const InputDecoration(
                  labelText: 'Note & comments (Markdown)',
                  helperText:
                      'Edits the same Orbit note. The original PDF stays unchanged.',
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in widget.colors.entries)
                    ChoiceChip(
                      label: Text(c.key),
                      avatar: Icon(
                        Icons.circle,
                        color: Color(c.value),
                        size: 14,
                      ),
                      selected: color == c.value,
                      onSelected: saving
                          ? null
                          : (_) => setState(() => color = c.value),
                    ),
                ],
              ),
              if (!widget.annotation.isPageComment)
                Wrap(
                  spacing: 8,
                  children: [
                    for (final s in ['highlight', 'underline', 'strikeout'])
                      ChoiceChip(
                        label: Text(s),
                        selected: style == s,
                        onSelected: saving
                            ? null
                            : (_) => setState(() => style = s),
                      ),
                  ],
                ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Resolved'),
                value: resolved,
                onChanged: saving ? null : (v) => setState(() => resolved = v!),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            try {
              await Clipboard.setData(
                ClipboardData(
                  text: ObjectReference(
                    widget.annotation.object.id,
                  ).markdown(widget.annotation.object.title),
                ),
              );
            } catch (_) {
              if (mounted) {
                setState(
                  () =>
                      error = 'Clipboard unavailable. Your note is unchanged.',
                );
              }
            }
          },
          child: const Text('Copy reference'),
        ),
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(saving ? 'Saving…' : 'Save review'),
        ),
      ],
    ),
  );
}
