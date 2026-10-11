import 'package:flutter/material.dart';
import '../../../app/orbit_theme.dart';
import '../../../app/workspace_controller.dart';
import '../../../domain/universal_object.dart';
import '../../../domain/pdf_annotation.dart';
import '../reading_rooms/reading_room_model.dart';
import 'pdf_book_model.dart';
import 'book_memories_dialog.dart';

/// A reading-first library of existing PDF objects; no copied book content.
class OrbitLibraryView extends StatefulWidget {
  const OrbitLibraryView({
    super.key,
    required this.controller,
    required this.onOpenBook,
    this.onImportPdf,
  });
  final WorkspaceController controller;
  final void Function(String bookId, {String? roomId}) onOpenBook;
  final VoidCallback? onImportPdf;
  @override
  State<OrbitLibraryView> createState() => _OrbitLibraryViewState();
}

class _OrbitLibraryViewState extends State<OrbitLibraryView> {
  String _selectedShelf = 'all';
  String _query = '';
  String _sort = 'recent';
  String? _roomId;
  bool _list = false;
  final _search = TextEditingController();
  static const _shelves = <String, String>{
    'all': 'All books',
    'reading': 'Reading',
    'favorites': 'Favorites',
    'finished': 'Finished',
    'study': 'Study',
    'tech': 'Tech & code',
  };
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _isPdf(UniversalObject o) =>
      o.typeId == 'orbit.file' &&
      (o.properties['mimeType'] == 'application/pdf' ||
          o.properties['isPdf'] == true ||
          o.title.toLowerCase().endsWith('.pdf'));
  bool _inShelf(PdfBookMeta b) => switch (_selectedShelf) {
    'reading' => b.hasStarted && !b.isFinished,
    'favorites' => b.isFavorite,
    'finished' => b.isFinished,
    'study' =>
      b.shelf.toLowerCase().contains('study') ||
          b.shelf.toLowerCase().contains('university'),
    'tech' =>
      b.shelf.toLowerCase().contains('tech') ||
          b.shelf.toLowerCase().contains('code'),
    _ => true,
  };
  void _open(PdfBookMeta book) {
    final savedRoom = widget.controller.find(book.id)?.properties['lastRoomId'];
    widget.onOpenBook(
      book.id,
      roomId: _roomId ?? (savedRoom is String ? savedRoom : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final objects = widget.controller.activeObjects.where(_isPdf).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final books = objects.map((o) {
      final page =
          widget.controller.session.noteViews['pdf:primary:${o.id}']?['page'] ??
          widget.controller.session.noteViews['pdf:secondary:${o.id}']?['page'];
      return PdfBookMeta.fromObject(o, currentPage: page is int ? page : null);
    }).toList();
    final matches = books
        .where(
          (b) =>
              _inShelf(b) &&
              ('${b.title} ${b.author} ${b.shelf}').toLowerCase().contains(
                _query.trim().toLowerCase(),
              ),
        )
        .toList();
    if (_sort == 'title') {
      matches.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    }
    if (_sort == 'progress') {
      matches.sort((a, b) => b.progress.compareTo(a.progress));
    }
    final resumed = books
        .where((b) => b.hasStarted && !b.isFinished)
        .firstOrNull;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (Navigator.canPop(context))
                              IconButton(
                                tooltip: 'Back to workspace',
                                onPressed: () => Navigator.maybePop(context),
                                icon: const Icon(Icons.arrow_back),
                              ),
                            Text(
                              'Bookshelf',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            Text(
                              '${books.length} ${books.length == 1 ? 'book' : 'books'}',
                              style: TextStyle(color: colors.subtle),
                            ),
                            if (widget.onImportPdf != null)
                              OutlinedButton.icon(
                                key: const ValueKey(
                                  'library-import-pdf-button',
                                ),
                                onPressed: widget.onImportPdf,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add PDF'),
                              ),
                            PopupMenuButton<String>(
                              key: const ValueKey('library-reading-room'),
                              tooltip: 'Reading room',
                              initialValue: _roomId ?? 'saved',
                              onSelected: (id) => setState(
                                () => _roomId = id == 'saved' ? null : id,
                              ),
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'saved',
                                  child: Text('Use each book’s saved room'),
                                ),
                                for (final room in ReadingRoomCatalog.all)
                                  PopupMenuItem(
                                    value: room.id,
                                    child: Row(
                                      children: [
                                        Icon(room.icon, size: 18),
                                        const SizedBox(width: 12),
                                        Flexible(child: Text(room.name)),
                                      ],
                                    ),
                                  ),
                              ],
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.spa_outlined, size: 18),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        _roomId == null
                                            ? 'Reading room'
                                            : ReadingRoomCatalog.all
                                                  .firstWhere(
                                                    (r) => r.id == _roomId,
                                                  )
                                                  .name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(Icons.expand_more, size: 16),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your PDFs, reading progress and saved notes.',
                          style: TextStyle(color: colors.subtle),
                        ),
                        if (resumed != null &&
                            _query.isEmpty &&
                            _selectedShelf == 'all') ...[
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: colors.panel,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colors.border),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final content = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CONTINUE READING',
                                      style: TextStyle(
                                        color: colors.subtle,
                                        fontSize: 11,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      resumed.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _pageLabel(resumed),
                                      style: TextStyle(color: colors.subtle),
                                    ),
                                  ],
                                );
                                final button = FilledButton.icon(
                                  key: const ValueKey(
                                    'hero-continue-reading-btn',
                                  ),
                                  onPressed: () => _open(resumed),
                                  icon: const Icon(
                                    Icons.arrow_forward,
                                    size: 18,
                                  ),
                                  label: const Text('Continue'),
                                );
                                return constraints.maxWidth < 500
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          content,
                                          const SizedBox(height: 12),
                                          button,
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Expanded(child: content),
                                          const SizedBox(width: 16),
                                          button,
                                        ],
                                      );
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        TextField(
                          key: const ValueKey('library-search-field'),
                          controller: _search,
                          decoration: InputDecoration(
                            hintText: 'Search title, author or shelf',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      _search.clear();
                                      setState(() => _query = '');
                                    },
                                  ),
                          ),
                          onChanged: (q) => setState(() => _query = q),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final shelf in _shelves.entries)
                              ChoiceChip(
                                key: ValueKey('shelf-tab-${shelf.key}'),
                                label: Text(shelf.value),
                                selected: _selectedShelf == shelf.key,
                                onSelected: (_) =>
                                    setState(() => _selectedShelf = shelf.key),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${matches.length} ${matches.length == 1 ? 'book' : 'books'} shown',
                                style: TextStyle(color: colors.subtle),
                              ),
                            ),
                            PopupMenuButton<String>(
                              key: const ValueKey('library-sort'),
                              tooltip: 'Sort books',
                              initialValue: _sort,
                              onSelected: (s) => setState(() => _sort = s),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'recent',
                                  child: Text('Recently updated'),
                                ),
                                PopupMenuItem(
                                  value: 'title',
                                  child: Text('Title A–Z'),
                                ),
                                PopupMenuItem(
                                  value: 'progress',
                                  child: Text('Reading progress'),
                                ),
                              ],
                              icon: const Icon(Icons.sort),
                            ),
                            IconButton(
                              key: const ValueKey('library-layout'),
                              tooltip: _list ? 'Show cards' : 'Show list',
                              onPressed: () => setState(() => _list = !_list),
                              icon: Icon(
                                _list
                                    ? Icons.grid_view_outlined
                                    : Icons.view_list_outlined,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (matches.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.all(24),
                    sliver: SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          children: [
                            Icon(
                              Icons.menu_book_outlined,
                              size: 36,
                              color: colors.subtle,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              books.isEmpty
                                  ? 'A place for your reading'
                                  : 'No books in this view',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              books.isEmpty
                                  ? 'Add a PDF to start your library.'
                                  : 'Try another shelf or search.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (matches.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    sliver: _list
                        ? SliverList.separated(
                            itemCount: matches.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) =>
                                _bookCard(matches[i], colors, compact: true),
                          )
                        : SliverLayoutBuilder(
                            builder: (context, constraints) {
                              final scale = MediaQuery.textScalerOf(
                                context,
                              ).scale(1);
                              final columns =
                                  (constraints.crossAxisExtent / (320 * scale))
                                      .floor()
                                      .clamp(1, 3);
                              return SliverGrid(
                                delegate: SliverChildBuilderDelegate(
                                  (_, i) => _bookCard(matches[i], colors),
                                  childCount: matches.length,
                                ),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      mainAxisExtent: 300 * scale,
                                      crossAxisSpacing: 14,
                                      mainAxisSpacing: 14,
                                    ),
                              );
                            },
                          ),
                  ),
                if (books.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Text(
                        '${books.fold<int>(0, (n, b) => n + b.bookmarksCount)} saved bookmarks · ${books.fold<int>(0, (n, b) => n + b.readingTimeMinutes)} minutes read',
                        style: TextStyle(color: colors.muted, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _pageLabel(PdfBookMeta book) => !book.hasStarted && book.progress == 0
      ? 'Not started'
      : book.totalPages > 1
      ? 'Page ${book.lastReadPage} of ${book.totalPages}'
      : 'Page ${book.lastReadPage}';

  Widget _bookCard(
    PdfBookMeta book,
    OrbitColors colors, {
    bool compact = false,
  }) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              size: 18,
              color: colors.secondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                book.isFinished ? 'FINISHED' : 'PDF',
                style: TextStyle(color: colors.subtle, fontSize: 11),
              ),
            ),
            IconButton(
              key: ValueKey('book-favorite-btn-${book.id}'),
              tooltip: book.isFavorite ? 'Remove favorite' : 'Add favorite',
              icon: Icon(
                book.isFavorite ? Icons.star : Icons.star_border,
                size: 20,
                color: book.isFavorite ? colors.warning : colors.subtle,
              ),
              onPressed: () {
                widget.controller.updateProperty(
                  book.id,
                  'isFavorite',
                  !book.isFavorite,
                );
                setState(() {});
              },
            ),
          ],
        ),
        Text(
          book.title,
          maxLines: compact ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.text,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (book.author != 'Unknown Author' && book.author.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.subtle, fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          _pageLabel(book),
          style: TextStyle(color: colors.subtle, fontSize: 12),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: book.progress,
          minHeight: 3,
          backgroundColor: colors.border,
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${book.bookmarksCount} saved',
              style: TextStyle(color: colors.muted, fontSize: 12),
            ),
            TextButton(
              key: ValueKey('book-memories-btn-${book.id}'),
              onPressed: () {
                final props =
                    widget.controller.find(book.id)?.properties ?? const {};
                final raw = props['pdfBookmarks'] ?? props['bookmarks'];
                BookMemoriesDialog.show(
                  context,
                  book: book,
                  controller: widget.controller,
                  annotations: widget.controller.activeObjects
                      .where((o) => o.typeId == 'orbit.note')
                      .map(PdfAnnotation.new)
                      .where((a) => a.fileId == book.id)
                      .toList(),
                  onJumpToPage: (page) {
                    widget.controller.updateSession((s) {
                      final key = 'pdf:primary:${book.id}';
                      final prior = s.noteViews[key];
                      s.noteViews = {
                        ...s.noteViews,
                        key: {
                          ...?prior,
                          'page': page,
                          'request':
                              ((prior?['request'] as num?)?.toInt() ?? 0) + 1,
                        },
                      };
                    });
                    _open(book);
                  },
                  bookmarks: raw is List
                      ? raw.whereType<int>().where((p) => p > 0).toList()
                      : const [],
                );
              },
              child: const Text('Reading notes'),
            ),
          ],
        ),
      ],
    );
    return Material(
      color: colors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('book-card-${book.id}'),
        onTap: () => _open(book),
        child: Padding(padding: const EdgeInsets.all(16), child: content),
      ),
    );
  }
}
