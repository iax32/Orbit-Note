import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import '../../domain/pdf_annotation.dart';
import '../../domain/object_reference.dart';

typedef SavePdfReview =
    Future<bool> Function(
      PdfAnnotation original,
      String body,
      int color,
      String style,
      bool resolved,
    );

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
    this.onEdit,
    this.onSummary,
    this.onExport,
  });
  final List<PdfAnnotation> annotations;
  final int page;
  final String? checksum;
  final ValueChanged<PdfAnnotation> onNavigate;
  final VoidCallback onClose;
  final ValueChanged<List<PdfAnnotation>> onCopy;
  final ValueChanged<List<PdfAnnotation>>? onExport;
  final ValueChanged<String>? onOpen;
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
        children: [Text(value), const Icon(Icons.expand_more, size: 16)],
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
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Highlights · ${widget.annotations.length}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Copy filtered review as Markdown',
                  onPressed: items.isEmpty ? null : () => widget.onCopy(items),
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
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
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('No matching review items.'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final a = items[index];
                        final matches = a.matches(widget.checksum);
                        final quote = a.source['quote'];
                        return ListTile(
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            matches
                                ? 'Page ${a.page} · ${a.resolved ? 'Resolved' : 'Open'} · ${a.isPageComment ? 'Comment' : a.style}'
                                : 'PDF version changed · review source before re-anchoring',
                          ),
                          onTap: matches ? () => widget.onNavigate(a) : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.onEdit != null)
                                IconButton(
                                  tooltip: 'Edit review item',
                                  onPressed: matches && !a.object.isReadOnly
                                      ? () => widget.onEdit!(a)
                                      : null,
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
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
                          ),
                        );
                      },
                    ),
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
