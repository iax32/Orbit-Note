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
    this.searchFocusNode,
  });
  final List<UniversalObject> notes;
  final String fileId;
  final String? checksum;
  final ValueChanged<String> onOpen;
  final VoidCallback onClose;
  final VoidCallback? onCreate;
  final FocusNode? searchFocusNode;
  @override
  State<PdfNotesPanel> createState() => _PdfNotesPanelState();
}

class _PdfNotesPanelState extends State<PdfNotesPanel> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final notes = widget.notes
        .where(
          (n) => '${n.title}\n${n.body}'.toLowerCase().contains(
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
                      trailing:
                          (anchored &&
                              source['quote'] is String &&
                              (source['quote'] as String).trim().isNotEmpty)
                          ? Tooltip(
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
                            )
                          : null,
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
