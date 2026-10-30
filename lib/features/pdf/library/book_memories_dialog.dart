import '../../../app/orbit_components.dart';
import 'package:flutter/material.dart';
import '../../../app/orbit_theme.dart';
import '../../../app/workspace_controller.dart';
import '../../../domain/pdf_annotation.dart';
import 'pdf_book_model.dart';

/// Modal dialog presenting a book's bookmarks, highlights, reading time, and 1-click note export.
class BookMemoriesDialog extends StatefulWidget {
  const BookMemoriesDialog({
    super.key,
    required this.book,
    required this.controller,
    this.bookmarks = const [],
    this.annotations = const [],
    this.onJumpToPage,
  });

  final PdfBookMeta book;
  final WorkspaceController controller;
  final List<int> bookmarks;
  final List<PdfAnnotation> annotations;
  final ValueChanged<int>? onJumpToPage;

  static Future<void> show(
    BuildContext context, {
    required PdfBookMeta book,
    required WorkspaceController controller,
    List<int> bookmarks = const [],
    List<PdfAnnotation> annotations = const [],
    ValueChanged<int>? onJumpToPage,
  }) {
    return showOrbitDialog<void>(
      context: context,
      builder: (_) => BookMemoriesDialog(
        book: book,
        controller: controller,
        bookmarks: bookmarks,
        annotations: annotations,
        onJumpToPage: onJumpToPage,
      ),
    );
  }

  @override
  State<BookMemoriesDialog> createState() => _BookMemoriesDialogState();
}

class _BookMemoriesDialogState extends State<BookMemoriesDialog> {
  int _selectedTab = 0; // 0: Bookmarks, 1: Highlights

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    return Dialog(
      backgroundColor: colors.panel,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Reading notes',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.subtle, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('Bookmarks (${widget.bookmarks.length})'),
                      selected: _selectedTab == 0,
                      onSelected: (_) => setState(() => _selectedTab = 0),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(
                        'Highlights & Notes (${widget.annotations.length})',
                      ),
                      selected: _selectedTab == 1,
                      onSelected: (_) => setState(() => _selectedTab = 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _selectedTab == 0
                    ? _buildBookmarksList(context, colors)
                    : _buildHighlightsList(context, colors),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: const ValueKey('export-reading-archive-button'),
                    onPressed: () => _exportToNote(context),
                    child: const Text(
                      'Export to Orbit Note',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.maybePop(context),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookmarksList(BuildContext context, OrbitColors colors) {
    if (widget.bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border_rounded, size: 36, color: colors.subtle),
            const SizedBox(height: 8),
            Text(
              'No saved bookmarks in this book yet',
              style: TextStyle(fontSize: 12, color: colors.subtle),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: widget.bookmarks.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: colors.border),
      itemBuilder: (context, idx) {
        final pageNum = widget.bookmarks[idx];
        return ListTile(
          dense: true,
          onTap: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            widget.onJumpToPage?.call(pageNum);
          },
          leading: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.bookmark_rounded, size: 16, color: colors.accent),
          ),
          title: Text('Bookmark on Page $pageNum'),
          trailing: IconButton(
            tooltip: 'Jump to page',
            icon: const Icon(Icons.arrow_forward, size: 18),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
              widget.onJumpToPage?.call(pageNum);
            },
          ),
        );
      },
    );
  }

  Widget _buildHighlightsList(BuildContext context, OrbitColors colors) {
    if (widget.annotations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.format_quote_rounded, size: 36, color: colors.subtle),
            const SizedBox(height: 8),
            Text(
              'No highlights or annotations recorded',
              style: TextStyle(fontSize: 12, color: colors.subtle),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: widget.annotations.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: colors.border),
      itemBuilder: (context, idx) {
        final anno = widget.annotations[idx];
        return ListTile(
          dense: true,
          leading: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Color(anno.color),
              shape: BoxShape.circle,
            ),
          ),
          title: Text(
            anno.quote.isNotEmpty ? '"${anno.quote}"' : 'Highlighted Area',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
          subtitle: Text(
            'Page ${anno.pageNumber}${anno.note.isNotEmpty ? ' Â· ${anno.note}' : ''}',
            style: TextStyle(fontSize: 11, color: colors.subtle),
          ),
          trailing: widget.onJumpToPage != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                    widget.onJumpToPage?.call(anno.pageNumber);
                  },
                )
              : null,
        );
      },
    );
  }

  Future<void> _exportToNote(BuildContext context) async {
    final sb = StringBuffer();
    sb.writeln('# Reading Notes: ${widget.book.title}');
    if (widget.book.author.isNotEmpty) {
      sb.writeln('**Author:** ${widget.book.author}');
    }
    sb.writeln('**Source Document:** [[${widget.book.title}]]');
    sb.writeln('**Reading Time:** ${widget.book.formattedReadingTime}');
    sb.writeln(
      '**Last Read Page:** ${widget.book.lastReadPage} of ${widget.book.totalPages}',
    );
    sb.writeln();
    sb.writeln('---');
    sb.writeln();

    if (widget.bookmarks.isNotEmpty) {
      sb.writeln('## Saved Page Bookmarks');
      for (final p in widget.bookmarks) {
        sb.writeln('- Bookmark on page $p');
      }
      sb.writeln();
    }

    if (widget.annotations.isNotEmpty) {
      sb.writeln('## Highlights & Key Excerpts');
      for (final a in widget.annotations) {
        if (a.quote.isNotEmpty) {
          sb.writeln('> "${a.quote}" (Page ${a.pageNumber})');
          if (a.note.isNotEmpty) {
            sb.writeln('  *Note: ${a.note}*');
          }
          sb.writeln();
        }
      }
    }

    sb.writeln('## Synthesis & Key Takeaways');
    sb.writeln('- What was the primary thesis or revelation of this book?');
    sb.writeln('- Practical concepts and applications to remember:');
    sb.writeln();

    final created = await widget.controller.create(
      'orbit.note',
      title: 'Reading Notes: ${widget.book.title}',
      body: sb.toString(),
      properties: {
        'tags': ['reading', 'books', 'notes'],
      },
    );

    if (context.mounted) {
      if (created == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not create reading notes. Please try again.'),
          ),
        );
        return;
      }
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Created reading study note for "${widget.book.title}"',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
