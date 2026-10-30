import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/orbit_draft_guard.dart';
import '../../app/retained_form.dart';
import 'package:flutter/services.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import '../../domain/pdf_annotation.dart';
import '../../domain/object_reference.dart';
import '../../domain/pdf_quote_transfer.dart';
import '../../domain/pdf_review_batch.dart';

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
    this.onDelete,
    this.deletingIds = const {},
    this.onSummary,
    this.onBoard,
    this.onExport,
    this.onAnnotatedCopy,
    this.savingAnnotatedCopy = false,
    this.expanded = false,
    this.onExpand,
    this.onBatch,
    this.onUndoBatch,
    this.colors = const {},
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
  final bool expanded;
  final VoidCallback? onExpand;
  final RunPdfReviewBatch? onBatch;
  final UndoPdfReviewBatch? onUndoBatch;
  final Map<String, int> colors;
  final ValueChanged<String>? onOpen;
  final VoidCallback? onOpenSource;
  final ValueChanged<PdfAnnotation>? onEdit;
  final Future<void> Function(PdfAnnotation)? onDelete;
  final Set<String> deletingIds;
  final Future<bool> Function(List<String>)? onSummary;
  final Future<bool> Function(List<PdfAnnotation>)? onBoard;
  @override
  State<PdfReviewPanel> createState() => _PdfReviewPanelState();
}

class _PdfReviewPanelState extends State<PdfReviewPanel> {
  String query = '', status = 'All', kind = 'All types', sort = 'Page';
  bool currentPage = false, saving = false;
  final _focus = FocusNode(debugLabel: 'PDF review navigation');
  final _scroll = ScrollController();
  final selected = <String>{};
  String? active, anchor, batchError;
  int pageIndex = 0, completed = 0, total = 0;
  static const pageSize = 50;
  bool running = false, cancel = false, undoing = false;
  PdfReviewBatchResult? receipt, report;
  @override
  void dispose() {
    cancel = true;
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PdfReviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final present = filtered.map((a) => a.object.id).toSet();
    selected.removeWhere((id) => !present.contains(id));
    if (!present.contains(active)) active = null;
  }

  void filterChanged(VoidCallback change) => setState(() {
    change();
    selected.clear();
    active = null;
    anchor = null;
    pageIndex = 0;
  });
  void select(PdfAnnotation item, {bool range = false}) {
    final items = filtered;
    setState(() {
      final from = items.indexWhere((a) => a.object.id == anchor);
      final to = items.indexWhere((a) => a.object.id == item.object.id);
      if (range && from >= 0 && to >= 0) {
        selected.addAll(
          items
              .sublist(math.min(from, to), math.max(from, to) + 1)
              .map((a) => a.object.id),
        );
      } else {
        if (!selected.remove(item.object.id)) selected.add(item.object.id);
        anchor = item.object.id;
      }
      active = item.object.id;
    });
    _focus.requestFocus();
  }

  void move(int direction, {bool range = false}) {
    final items = filtered;
    if (items.isEmpty) return;
    final prior = items.indexWhere((a) => a.object.id == active);
    final index = (prior < 0 ? 0 : prior + direction).clamp(
      0,
      items.length - 1,
    );
    final item = items[index];
    if (range) {
      anchor ??= prior < 0 ? item.object.id : items[prior].object.id;
      select(item, range: true);
    }
    setState(() {
      active = item.object.id;
      pageIndex = index ~/ pageSize;
    });
    if (item.matches(widget.checksum)) widget.onNavigate(item);
    _focus.requestFocus();
  }

  KeyEventResult keys(FocusNode node, KeyEvent event) {
    if (!_focus.hasPrimaryFocus ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent) ||
        running) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (event is KeyRepeatEvent &&
        key != LogicalKeyboardKey.arrowDown &&
        key != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (key == LogicalKeyboardKey.escape) {
      if (selected.isEmpty) {
        widget.onClose();
      } else {
        setState(selected.clear);
      }
    } else if ((keyboard.isControlPressed || keyboard.isMetaPressed) &&
        key == LogicalKeyboardKey.keyA) {
      setState(() => selected.addAll(filtered.map((a) => a.object.id)));
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      move(
        key == LogicalKeyboardKey.arrowDown ? 1 : -1,
        range: keyboard.isShiftPressed,
      );
    } else if (key == LogicalKeyboardKey.space) {
      final item = filtered.where((a) => a.object.id == active).firstOrNull;
      if (item != null) {
        select(item, range: keyboard.isShiftPressed);
      } else {
        move(1);
      }
    } else if (key == LogicalKeyboardKey.enter) {
      final item = filtered.where((a) => a.object.id == active).firstOrNull;
      if (item != null && item.matches(widget.checksum)) {
        widget.onNavigate(item);
      }
    } else if (key == LogicalKeyboardKey.delete &&
        selected.isNotEmpty &&
        widget.onBatch != null) {
      run(PdfReviewBatchAction.trash);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Future<void> run(PdfReviewBatchAction action, {int? color}) async {
    final change = widget.onBatch;
    final items = filtered
        .where((a) => selected.contains(a.object.id))
        .toList();
    if (running || change == null || items.isEmpty) return;
    if (action == PdfReviewBatchAction.trash) {
      final confirmed = await showOrbitDialog<bool>(
        context: context,
        builder: (context) => OrbitDialog(
          title: Text('Move ${items.length} review notes to Trash?'),
          content: const Text(
            'Their highlights and comments will be removed from this PDF. Original PDF bytes are unchanged. You can undo the completed items or restore notes from Trash.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Move to Trash'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true || running) return;
    }
    setState(() {
      running = true;
      cancel = false;
      completed = 0;
      total = items.length;
      batchError = null;
    });
    try {
      final result = await change(
        items,
        action,
        color: color,
        isCancelled: () => cancel || !mounted,
        onProgress: (done, count) {
          if (mounted) {
            setState(() {
              completed = done;
              total = count;
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          report = result;
          receipt = result.changes.isEmpty ? receipt : result;
          selected.clear();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => batchError =
              'The batch could not finish. Completed changes remain in note history; review the latest items before retrying.',
        );
      }
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  Future<void> undo() async {
    final change = widget.onUndoBatch, before = receipt;
    if (running || change == null || before == null) return;
    setState(() {
      running = true;
      undoing = true;
      cancel = false;
      completed = 0;
      total = before.changes.length;
    });
    try {
      final result = await change(
        before,
        isCancelled: () => cancel || !mounted,
        onProgress: (done, count) {
          if (mounted) {
            setState(() {
              completed = done;
              total = count;
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          report = result;
          final restored = result.changes.map((c) => c.before.id).toSet();
          final pending = before.changes
              .where((c) => !restored.contains(c.after.id))
              .toList();
          receipt = pending.isEmpty
              ? null
              : PdfReviewBatchResult(
                  workspaceId: before.workspaceId,
                  fileId: before.fileId,
                  action: before.action,
                  changes: pending,
                  requested: pending.length,
                );
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => batchError =
              'Undo could not finish. Later edits and committed notes are retained.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          running = false;
          undoing = false;
        });
      }
    }
  }

  List<PdfAnnotation> get filtered {
    final needle = query.trim().toLowerCase();
    final items = widget.annotations.where((a) {
      return (needle.isEmpty ||
              '${a.object.title}\n${a.source['quote']}\n${a.object.body}'
                  .toLowerCase()
                  .contains(needle)) &&
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

  Future<void> copyQuote(String quote) async {
    try {
      await Clipboard.setData(ClipboardData(text: quote));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clipboard unavailable. Review unchanged.'),
          ),
        );
      }
    }
  }

  Future<void> saveBoard(List<PdfAnnotation> items) async {
    if (saving || running || widget.onBoard == null) return;
    setState(() => saving = true);
    var saved = false;
    try {
      saved = await widget.onBoard!(items);
    } catch (_) {}
    if (!mounted) return;
    setState(() => saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Linked Canvas review board created. Original notes remain the source.'
              : 'Could not create the board. Check source versions and save status, then retry.',
        ),
      ),
    );
  }

  Widget choice(
    String value,
    List<String> values,
    ValueChanged<String> change,
  ) => PopupMenuButton<String>(
    popUpAnimationStyle: OrbitMotionScope.popupStyle(context),
    enabled: !running,
    tooltip: 'Review $value',
    initialValue: value,
    onSelected: (v) => filterChanged(() => change(v)),
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

  Widget tools(List<PdfAnnotation> items) {
    final activeIndex = items.indexWhere((a) => a.object.id == active);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (selected.isNotEmpty) Text('${selected.length} selected'),
              TextButton(
                onPressed: running || items.isEmpty
                    ? null
                    : () => setState(
                        () => selected.addAll(items.map((a) => a.object.id)),
                      ),
                child: const Text('Select all filtered'),
              ),
              if (selected.isNotEmpty)
                TextButton(
                  onPressed: running || selected.isEmpty
                      ? null
                      : () => setState(selected.clear),
                  child: const Text('Clear selection'),
                ),
              IconButton(
                tooltip:
                    'Focus review items · arrows, Shift+arrows, Space, Ctrl+A, Delete',
                onPressed: () {
                  _focus.requestFocus();
                  if (active == null) move(1);
                },
                icon: const Icon(Icons.keyboard_outlined),
              ),
              if (activeIndex >= 0)
                IconButton(
                  tooltip: 'Previous review item',
                  onPressed: running || items.isEmpty ? null : () => move(-1),
                  icon: const Icon(Icons.navigate_before),
                ),
              if (activeIndex >= 0)
                Text(
                  activeIndex < 0
                      ? '${items.length} review items'
                      : '${activeIndex + 1} of ${items.length} · p. ${items[activeIndex].page}',
                ),
              if (activeIndex >= 0)
                IconButton(
                  tooltip: 'Next review item',
                  onPressed: running || items.isEmpty ? null : () => move(1),
                  icon: const Icon(Icons.navigate_next),
                ),
              if (widget.onBatch != null && selected.isNotEmpty)
                PopupMenuButton<PdfReviewBatchAction>(
                  popUpAnimationStyle: OrbitMotionScope.popupStyle(context),
                  tooltip: 'Change selected review items',
                  enabled: !running && selected.isNotEmpty,
                  icon: const Icon(Icons.tune),
                  onSelected: (action) => run(action),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: PdfReviewBatchAction.resolve,
                      child: Text('Mark resolved'),
                    ),
                    const PopupMenuItem(
                      value: PdfReviewBatchAction.reopen,
                      child: Text('Reopen'),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: PdfReviewBatchAction.highlight,
                      child: Text('Highlight'),
                    ),
                    const PopupMenuItem(
                      value: PdfReviewBatchAction.underline,
                      child: Text('Underline'),
                    ),
                    const PopupMenuItem(
                      value: PdfReviewBatchAction.strikeout,
                      child: Text('Strikeout'),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: PdfReviewBatchAction.trash,
                      child: Text('Move selected notes to Trash…'),
                    ),
                  ],
                ),
              if (widget.onBatch != null &&
                  widget.colors.isNotEmpty &&
                  selected.isNotEmpty)
                PopupMenuButton<int>(
                  popUpAnimationStyle: OrbitMotionScope.popupStyle(context),
                  tooltip: 'Color selected review items',
                  enabled: !running && selected.isNotEmpty,
                  icon: const Icon(Icons.palette_outlined),
                  onSelected: (color) =>
                      run(PdfReviewBatchAction.color, color: color),
                  itemBuilder: (_) => [
                    for (final entry in widget.colors.entries)
                      PopupMenuItem(value: entry.value, child: Text(entry.key)),
                  ],
                ),
              if (receipt != null && widget.onUndoBatch != null)
                TextButton.icon(
                  onPressed: running ? null : undo,
                  icon: const Icon(Icons.undo),
                  label: Text('Undo batch (${receipt!.changes.length})'),
                ),
            ],
          ),
          if (activeIndex >= 0)
            Text(
              items[activeIndex].quote.isEmpty
                  ? items[activeIndex].object.title
                  : items[activeIndex].quote,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: OrbitColors.of(context).muted),
            ),
          if (widget.expanded)
            const ExpansionTile(
              dense: true,
              title: Text('Keyboard and selection'),
              children: [
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Shift+click selects a range. Arrows navigate; Space selects; Ctrl+A selects filtered items. Changing filters clears selection.',
                  ),
                ),
              ],
            ),
          if (selected.length > 1000)
            const Text(
              'Select up to 1,000 items per edit batch. Copy/export can include the full selection.',
            ),
          if (running)
            Semantics(
              liveRegion: true,
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: total == 0 ? null : completed / total,
                  ),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${undoing ? 'Undoing' : 'Updating'} $completed of $total',
                      ),
                      TextButton(
                        onPressed: cancel
                            ? null
                            : () => setState(() => cancel = true),
                        child: Text(
                          cancel
                              ? 'Stopping after current save…'
                              : 'Cancel batch',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (report != null && !running)
            Semantics(
              liveRegion: true,
              child: Text(
                '${report!.changes.length} saved · ${report!.unchanged} unchanged · ${report!.failures.length} need attention${report!.cancelled ? ' · stopped after ${report!.processed} of ${report!.requested}' : ''}',
              ),
            ),
          if (report?.failures.isNotEmpty == true)
            ExpansionTile(
              title: const Text('Items needing attention'),
              children: [
                for (final failure in report!.failures.entries.take(20))
                  ListTile(
                    dense: true,
                    title: Text(
                      widget.annotations
                              .where((a) => a.object.id == failure.key)
                              .firstOrNull
                              ?.object
                              .title ??
                          failure.key,
                    ),
                    subtitle: Text(failure.value),
                  ),
                if (report!.failures.length > 20)
                  Text(
                    '${report!.failures.length - 20} more items; narrow the selection to review them.',
                  ),
              ],
            ),
          if (batchError != null)
            Text(
              batchError!,
              style: TextStyle(color: OrbitColors.of(context).warning),
            ),
          if (items.length > pageSize)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: pageIndex <= 0
                      ? null
                      : () => setState(() {
                          pageIndex--;
                          _scroll.jumpTo(0);
                        }),
                  child: const Text('Previous results'),
                ),
                Text(
                  'Results ${pageIndex * pageSize + 1}–${math.min(items.length, (pageIndex + 1) * pageSize)} of ${items.length}',
                ),
                TextButton(
                  onPressed: (pageIndex + 1) * pageSize >= items.length
                      ? null
                      : () => setState(() {
                          pageIndex++;
                          _scroll.jumpTo(0);
                        }),
                  child: const Text('Next results'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = filtered;
    pageIndex = pageIndex.clamp(0, math.max(0, (items.length - 1) ~/ pageSize));
    final page = items.skip(pageIndex * pageSize).take(pageSize).toList();
    final exportItems = selected.isEmpty
        ? items
        : items.where((a) => selected.contains(a.object.id)).toList();
    return Focus(
      focusNode: _focus,
      onKeyEvent: keys,
      child: Material(
        color: OrbitColors.of(context).raised,
        child: Container(
          height: widget.expanded
              ? double.infinity
              : math.min(310, MediaQuery.sizeOf(context).height * .43),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: OrbitColors.of(context).border),
            ),
          ),
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    OrbitPanelHeader(
                      icon: Icons.edit_note_rounded,
                      title: 'Highlights · ${widget.annotations.length}',
                      subtitle: 'Review and annotate this document',
                      actions: [
                        if (widget.onExpand != null)
                          IconButton(
                            tooltip: widget.expanded
                                ? 'Collapse review workspace'
                                : 'Expand review workspace',
                            onPressed: running ? null : widget.onExpand,
                            icon: Icon(
                              widget.expanded
                                  ? Icons.close_fullscreen
                                  : Icons.open_in_full,
                            ),
                          ),
                        IconButton(
                          tooltip: selected.isEmpty
                              ? 'Copy filtered review as Markdown'
                              : 'Copy selected review as Markdown',
                          onPressed: items.isEmpty
                              ? null
                              : () => widget.onCopy(exportItems),
                          icon: const Icon(Icons.copy, size: 18),
                        ),
                        if (widget.onExport != null)
                          IconButton(
                            tooltip: selected.isEmpty
                                ? 'Export filtered review as Markdown'
                                : 'Export selected review as Markdown',
                            onPressed: items.isEmpty
                                ? null
                                : () => widget.onExport!(exportItems),
                            icon: const Icon(Icons.download_outlined, size: 18),
                          ),
                        if (widget.onSummary != null)
                          IconButton(
                            tooltip: selected.isEmpty
                                ? 'Save filtered review as note'
                                : 'Save selected review as note',
                            onPressed: saving || running || items.isEmpty
                                ? null
                                : () => saveSummary(exportItems),
                            icon: const Icon(Icons.note_add_outlined, size: 18),
                          ),
                        if (widget.onBoard != null)
                          IconButton(
                            tooltip: selected.isEmpty
                                ? 'Create filtered Canvas review board'
                                : 'Create selected Canvas review board',
                            onPressed: saving || running || exportItems.isEmpty
                                ? null
                                : () => saveBoard(exportItems),
                            icon: const Icon(
                              Icons.dashboard_customize_outlined,
                              size: 18,
                            ),
                          ),
                        if (widget.onAnnotatedCopy != null ||
                            widget.savingAnnotatedCopy)
                          IconButton(
                            tooltip: widget.savingAnnotatedCopy
                                ? 'Saving annotated PDF…'
                                : 'Save filtered review as annotated PDF',
                            onPressed:
                                items.isEmpty || widget.savingAnnotatedCopy
                                ? null
                                : () => widget.onAnnotatedCopy!(exportItems),
                            icon: const Icon(
                              Icons.picture_as_pdf_outlined,
                              size: 18,
                            ),
                          ),
                        IconButton(
                          tooltip: 'Close highlights',
                          onPressed: running ? null : widget.onClose,
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
                        enabled: !running,
                        onChanged: (v) => filterChanged(() => query = v),
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
                            onSelected: running
                                ? null
                                : (v) => filterChanged(() => currentPage = v),
                          ),
                          const SizedBox(width: 12),
                          Text('${items.length} shown'),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                    tools(items),
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
                  itemCount: page.length,
                  itemBuilder: (context, index) {
                    final a = page[index];
                    final matches = a.matches(widget.checksum);
                    final quote = a.source['quote'];
                    final deleting = widget.deletingIds.contains(a.object.id);
                    return OrbitActionTile(
                      dense: true,
                      leading: Checkbox(
                        key: ValueKey('review-select-${a.object.id}'),
                        value: selected.contains(a.object.id),
                        semanticLabel: 'Select ${a.object.title}',
                        onChanged: running
                            ? null
                            : (_) => select(
                                a,
                                range: HardwareKeyboard.instance.isShiftPressed,
                              ),
                        activeColor: Color(a.color),
                      ),
                      title: Row(
                        children: [
                          Icon(
                            a.resolved
                                ? Icons.check_circle_outline
                                : a.isPageComment
                                ? Icons.sticky_note_2_outlined
                                : Icons.format_paint_outlined,
                            color: Color(a.color),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              quote is String && quote.isNotEmpty
                                  ? quote
                                  : a.object.title,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        matches
                            ? 'Page ${a.page} · ${a.resolved ? 'Resolved' : 'Open'} · ${a.isPageComment ? 'Comment' : a.style}'
                            : 'PDF version changed · review source before re-anchoring',
                      ),
                      onTap: matches
                          ? () {
                              setState(() => active = a.object.id);
                              widget.onNavigate(a);
                            }
                          : null,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.drag_indicator,
                                            size: 14,
                                            color: OrbitColors.of(
                                              context,
                                            ).accent,
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
                            onPressed:
                                matches &&
                                    !a.object.isReadOnly &&
                                    !deleting &&
                                    !running
                                ? () => widget.onEdit!(a)
                                : null,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                          ),
                        if (quote is String && quote.trim().isNotEmpty)
                          IconButton(
                            tooltip: 'Copy quote text',
                            onPressed: () => copyQuote(quote.trim()),
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
                        if (widget.onDelete != null)
                          IconButton(
                            tooltip: deleting
                                ? 'Deleting review item…'
                                : 'Delete review item · move note to Trash',
                            onPressed:
                                deleting || a.object.isReadOnly || running
                                ? null
                                : () => widget.onDelete!(a),
                            icon: deleting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.delete_outline, size: 18),
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
  RetainedForm? _draft;
  bool _draftChecked = false, _recovered = false;
  Map<String, dynamic> get _values => {
    'body': body.text,
    'color': color,
    'style': style,
    'resolved': resolved,
  };
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_draftChecked) return;
    _draftChecked = true;
    _draft = RetainedForm.capture(
      context,
      'pdf-review:${widget.annotation.object.id}',
      _values,
    );
    final saved = _draft?.recovered;
    if (saved == null) return;
    if (saved['body'] is String) body.text = saved['body'] as String;
    if (saved['color'] is int) color = saved['color'] as int;
    if (['highlight', 'underline', 'strikeout'].contains(saved['style'])) {
      style = saved['style'] as String;
    }
    if (saved['resolved'] is bool) resolved = saved['resolved'] as bool;
    _recovered = true;
  }

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
    if (saving) return;
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
      await _draft?.complete();
      if (!mounted) return;
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
  Widget build(BuildContext context) => OrbitDraftGuard(
    onKeepDraft: _draft == null ? null : () => _draft!.keep(_values),
    onDiscardDraft: _recovered ? _draft!.discard : null,
    busy: saving,
    hasChanges: () =>
        _recovered ||
        body.text != widget.annotation.object.body ||
        color != widget.annotation.color ||
        style != widget.annotation.style ||
        resolved != widget.annotation.resolved,
    dirty:
        _recovered ||
        body.text != widget.annotation.object.body ||
        color != widget.annotation.color ||
        style != widget.annotation.style ||
        resolved != widget.annotation.resolved,
    builder: (context, requestClose) => OrbitDialog(
      title: Text('Review · page ${widget.annotation.page}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_recovered) _draft!.notice(),
              TextField(
                controller: body,
                onChanged: (_) => setState(() {}),
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
          onPressed: saving ? null : requestClose,
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
