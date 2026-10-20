import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/universal_object.dart';
import '../../domain/pdf_quote_transfer.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';

/// A view of the same notes shown by the editor and backlinks, never a copy.
class PdfNotesPanel extends StatefulWidget {
  const PdfNotesPanel({
    super.key,
    required this.notes,
    required this.fileId,
    required this.checksum,
    required this.onOpen,
    required this.onClose,
    this.onCreate,
    this.onDelete,
    this.onRestore,
    this.searchFocusNode,
  });
  final List<UniversalObject> notes;
  final String fileId;
  final String? checksum;
  final ValueChanged<String> onOpen;
  final VoidCallback onClose;
  final VoidCallback? onCreate;
  final Future<UniversalObject?> Function(UniversalObject)? onDelete;
  final Future<bool> Function(UniversalObject)? onRestore;
  final FocusNode? searchFocusNode;
  @override
  State<PdfNotesPanel> createState() => _PdfNotesPanelState();
}

class _PdfNotesPanelState extends State<PdfNotesPanel> {
  String query = '';
  String? error;
  final deleting = <String>{};

  Future<void> remove(UniversalObject note) async {
    final save = widget.onDelete, restore = widget.onRestore;
    final file = widget.fileId;
    if (save == null || note.isReadOnly || !deleting.add(note.id)) return;
    setState(() => error = null);
    UniversalObject? deleted;
    try {
      deleted = await save(note);
    } catch (_) {}
    if (!mounted) return;
    setState(() => deleting.remove(note.id));
    if (file != widget.fileId) return;
    if (deleted == null) {
      setState(
        () => error =
            'Could not delete this note. Check its save status or editing conflict, then retry. Your note is retained.',
      );
      return;
    }
    final snapshot = deleted;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: const Text(
          'Linked note moved to Trash. The original PDF is unchanged.',
        ),
        action: restore == null
            ? null
            : SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  var ok = false;
                  try {
                    ok = await restore(snapshot);
                  } catch (_) {}
                  if (mounted && widget.fileId == file && !ok) {
                    setState(
                      () => error =
                          'Could not undo. The latest note is retained in Trash.',
                    );
                  } else if (!ok && messenger.mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not undo. The latest note is retained in Trash.',
                        ),
                      ),
                    );
                  }
                },
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = widget.notes
        .where(
          (n) =>
              !n.isDeleted &&
              '${n.title}\n${n.body}'.toLowerCase().contains(
                query.toLowerCase().trim(),
              ),
        )
        .toList();
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: Material(
        color: OrbitColors.of(context).raised,
        child: SizedBox(
          height: math.min(310, MediaQuery.sizeOf(context).height * .43),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    OrbitPanelHeader(
                      icon: Icons.description_outlined,
                      title: 'Connected notes',
                      subtitle: '${widget.notes.length} linked notes',
                      actions: [
                        IconButton(
                          tooltip: 'New note at current PDF page',
                          onPressed: widget.onCreate,
                          icon: const Icon(Icons.note_add_outlined),
                        ),
                        IconButton(
                          tooltip: 'Close connected notes',
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        autofocus: widget.searchFocusNode == null,
                        focusNode: widget.searchFocusNode,
                        onSubmitted: (_) {
                          if (notes.isNotEmpty) widget.onOpen(notes.first.id);
                        },
                        decoration: const InputDecoration(
                          hintText: 'Find connected notes',
                          isDense: true,
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) => setState(() => query = v),
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Semantics(liveRegion: true, child: Text(error!)),
                      ),
                  ],
                ),
              ),
              if (notes.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Create a page note, highlight a passage, or link this PDF from an existing note.',
                    ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: notes.length,
                  itemBuilder: (context, i) {
                    final note = notes[i];
                    final source = note.properties['pdfSource'];
                    final anchored =
                        source is Map && source['objectId'] == widget.fileId;
                    final stale =
                        anchored && source['checksum'] != widget.checksum;
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.description_outlined),
                      title: Text(note.title),
                      subtitle: Text(
                        stale
                            ? 'Source version changed · review before using'
                            : anchored
                            ? 'Page ${source['page']} · open beside PDF'
                            : 'Links to this PDF',
                      ),
                      onTap: () => widget.onOpen(note.id),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (anchored &&
                              source['quote'] is String &&
                              (source['quote'] as String).trim().isNotEmpty)
                            Tooltip(
                              message: 'Drag citation onto note or canvas',
                              child: Draggable<PdfQuoteDragData>(
                                data: PdfQuoteDragData(
                                  objectId: widget.fileId,
                                  title: note.title.isNotEmpty
                                      ? note.title
                                      : 'PDF Document',
                                  page: (source['page'] as num?)?.toInt() ?? 1,
                                  text: (source['quote'] as String).trim(),
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
                                                '${note.title} (p. ${source['page'] ?? 1})',
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
                                          (source['quote'] as String).trim(),
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
                          if (widget.onDelete != null && !note.isReadOnly)
                            IconButton(
                              key: ValueKey('delete-pdf-note-${note.id}'),
                              tooltip: 'Move linked note to Trash',
                              onPressed: deleting.contains(note.id)
                                  ? null
                                  : () => remove(note),
                              icon: deleting.contains(note.id)
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.delete_outline, size: 18),
                            ),
                        ],
                      ),
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
