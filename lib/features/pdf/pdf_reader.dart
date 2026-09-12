import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;

import '../../app/orbit_theme.dart';
import '../../app/orbit_components.dart';
import '../../domain/research_document.dart';
import '../../domain/object_reference.dart';
import '../../domain/pdf_annotation.dart';
import '../../canvas/scene.dart';
import '../../platform/pdf_forms.dart';
import 'pdf_work_widgets.dart';
import 'pdf_content_fit.dart';

List<CanvasElement> pdfSelectionRegions(
  List<PdfPageTextRange> ranges,
  List<PdfPage> pages,
) => [
  for (final range in ranges)
    for (final fragment in range.enumerateFragmentBoundingRects())
      ...() {
        final page = pages[range.pageNumber - 1];
        final raw = fragment.bounds.toRect(page: page);
        final rect = Rect.fromLTWH(
          raw.left / page.width,
          raw.top / page.height,
          raw.width / page.width,
          raw.height / page.height,
        );
        final clipped = rect.intersect(const Rect.fromLTWH(0, 0, 1, 1));
        if (clipped.isEmpty) return <CanvasElement>[];
        return [
          CanvasElement({
            'id': '${range.pageNumber}:${fragment.start}:${fragment.end}',
            'type': 'rectangle',
            'page': range.pageNumber,
            'x': clipped.left,
            'y': clipped.top,
            'width': clipped.width,
            'height': clipped.height,
            'color': 0xff8b7cf6,
          }),
        ];
      }(),
];

/// Reads repository-owned bytes. PDFium never receives a workspace filesystem
/// path or permission to overwrite the original document.
class OrbitPdfReader extends StatefulWidget {
  const OrbitPdfReader({
    super.key,
    required this.objectId,
    required this.title,
    required this.loadBytes,
    required this.onOpenOriginal,
    required this.onOpenExternal,
    required this.onReadingState,
    required this.onQuote,
    required this.onBookmarks,
    this.initialPage = 1,
    this.initialZoom,
    this.bookmarks = const [],
    this.readOnly = false,
    this.checksum,
    this.annotations = const [],
    this.onHighlight,
    this.onOpenAnnotation,
    this.onCreateDocument,
    this.formValues = const {},
    this.onFormChanged,
    this.onSaveFilledCopy,
  });
  final String objectId, title;
  final Map<String, dynamic> formValues;
  final Future<bool> Function(String, Object)? onFormChanged;
  final Future<bool> Function(Uint8List)? onSaveFilledCopy;
  final Future<Uint8List?> Function() loadBytes;
  final VoidCallback onOpenOriginal;
  final ValueChanged<Uri> onOpenExternal;
  final void Function(int page, double zoom) onReadingState;
  final Future<void> Function(String text, int page) onQuote;
  final ValueChanged<List<int>> onBookmarks;
  final int initialPage;
  final double? initialZoom;
  final List<int> bookmarks;
  final bool readOnly;
  final String? checksum;
  final List<PdfAnnotation> annotations;
  final Future<bool> Function(
    String quote,
    List<CanvasElement> regions,
    String comment,
  )?
  onHighlight;
  final ValueChanged<String>? onOpenAnnotation;
  final Future<bool> Function(
    ResearchDocument document,
    int page,
    String quote,
  )?
  onCreateDocument;

  @override
  State<OrbitPdfReader> createState() => _OrbitPdfReaderState();
}

class _OrbitPdfReaderState extends State<OrbitPdfReader> {
  final _viewer = PdfViewerController();
  PdfTextSearcher? _search;
  late Future<Uint8List?> _bytes = widget.loadBytes();
  final _query = TextEditingController();
  final _pageInput = TextEditingController();
  final _annotationInput = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _saveTimer;
  bool _ready = false;
  bool _forms = false, _comfort = false, _savingCopy = false;
  bool _textOnly = false;
  int _fitGeneration = 0;
  final _contentWidths = <int, Future<Rect>>{};

  Future<void> _fitComfort({bool keepVerticalPosition = false}) async {
    if (!_ready || !_viewer.isReady || !_comfort || _textOnly) return;
    final generation = ++_fitGeneration;
    final pageNumber = _page.clamp(1, _viewer.pageCount);
    try {
      if (!_contentWidths.containsKey(pageNumber) &&
          _contentWidths.length >= 32) {
        _contentWidths.remove(_contentWidths.keys.first);
      }
      final area = await (_contentWidths[pageNumber] ??= measurePdfContentWidth(
        _viewer.document.pages[pageNumber - 1],
      ));
      if (!mounted ||
          generation != _fitGeneration ||
          !_comfort ||
          _textOnly ||
          !_viewer.isReady ||
          _page != pageNumber) {
        return;
      }
      final page = _viewer.layout.pageLayouts[pageNumber - 1];
      final zoom = ((_viewer.viewSize.width - 16) / (page.width * area.width))
          .clamp(_viewer.minScale, _viewer.maxScale);
      final top = keepVerticalPosition
          ? _viewer.centerPosition.dy -
                _viewer.viewSize.height / (2 * _viewer.currentZoom)
          : page.top;
      await _viewer.goTo(
        _viewer.calcMatrixFor(
          Offset(
            page.left + page.width * area.center.dx,
            top + (_viewer.viewSize.height / 2 - 8) / zoom,
          ),
          zoom: zoom,
        ),
        duration: Duration.zero,
      );
    } catch (_) {
      if (mounted &&
          generation == _fitGeneration &&
          _comfort &&
          !_textOnly &&
          _viewer.isReady) {
        await _viewer.goTo(
          _viewer.calcMatrixFitWidthForPage(pageNumber: pageNumber),
          duration: Duration.zero,
        );
      }
    }
  }

  bool _thumbnails = false;
  bool _finding = false;
  bool _showAnnotations = false;
  bool _creatingDocument = false;
  String _annotationQuery = '';
  int _page = 1;
  List<PdfOutlineNode> _outline = const [];

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    _pageInput.text = '$_page';
    _viewer.addListener(_positionChanged);
  }

  @override
  void didUpdateWidget(OrbitPdfReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPage != oldWidget.initialPage &&
        _viewer.isReady &&
        widget.initialPage != _page) {
      _go(widget.initialPage);
    }
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void _positionChanged() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted && _viewer.isReady) {
        widget.onReadingState(_viewer.pageNumber ?? _page, _viewer.currentZoom);
      }
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _search?.dispose();
    _viewer.removeListener(_positionChanged);
    _query.dispose();
    _pageInput.dispose();
    _annotationInput.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _go(int page) {
    if (_viewer.isReady) {
      _viewer.goToPage(
        pageNumber: page.clamp(1, _viewer.pageCount),
        duration: Duration.zero,
      );
    }
  }

  void _find() {
    _comfort = false;
    _textOnly = false;
    setState(() => _finding = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocus.requestFocus();
      }
    });
  }

  Future<void> _saveFilledCopy() async {
    if (_savingCopy ||
        !_ready ||
        widget.readOnly ||
        widget.onSaveFilledCopy == null) {
      return;
    }
    setState(() => _savingCopy = true);
    try {
      final bytes = await applyPdfFields(_viewer.document, widget.formValues);
      if (!mounted) return;
      final saved = await widget.onSaveFilledCopy!(bytes);
      _notice(
        saved
            ? 'Filled copy saved as a separate PDF in this Vault.'
            : 'Could not save filled copy. Your field drafts are retained.',
      );
    } catch (error) {
      _notice('Could not create filled copy: $error');
    } finally {
      if (mounted) setState(() => _savingCopy = false);
    }
  }

  Future<void> _createDocument(ResearchDocument document) async {
    if (_creatingDocument || widget.readOnly || !_viewer.isReady) return;
    final create = widget.onCreateDocument;
    if (create == null) return;
    setState(() => _creatingDocument = true);
    try {
      var quote = '';
      var page = _page;
      final selection = _viewer.textSelectionDelegate;
      if (selection.isCopyAllowed && selection.hasSelectedText) {
        final ranges = await selection.getSelectedTextRanges();
        if (!mounted) return;
        if (ranges.isNotEmpty) {
          quote = ranges.map((r) => r.text).join('\n');
          page = ranges.first.pageNumber;
        }
      }
      final saved = await create(document, page, quote);
      if (!saved) {
        _notice('Document could not be saved. Your PDF is unchanged.');
      }
    } catch (error) {
      _notice('Could not create the document: $error');
    } finally {
      if (mounted) setState(() => _creatingDocument = false);
    }
  }

  void _notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _copyReference() async {
    await Clipboard.setData(
      ClipboardData(
        text: ObjectReference(
          widget.objectId,
          page: _page,
        ).markdown(widget.title),
      ),
    );
    _notice('Page reference copied. Paste it into a note.');
  }

  Future<void> _quote(
    PdfViewerContextMenuBuilderParams params, {
    required bool copy,
  }) async {
    try {
      final ranges = await params.textSelectionDelegate.getSelectedTextRanges();
      if (!mounted || ranges.isEmpty) {
        return;
      }
      final text = ranges.map((r) => r.text).join('\n');
      final page = ranges.first.pageNumber;
      params.dismissContextMenu();
      if (copy) {
        await Clipboard.setData(
          ClipboardData(
            text: ObjectReference(
              widget.objectId,
              page: page,
            ).quoteMarkdown(widget.title, text),
          ),
        );
        _notice('Quote and page reference copied.');
      } else {
        await widget.onQuote(text, page);
      }
    } catch (error) {
      _notice('Could not extract the selected text: $error');
    }
  }

  Future<String?> _password() async {
    if (!mounted) {
      return null;
    }
    final input = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => OrbitDialog(
        title: const Text('Unlock PDF'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the document password. A damaged PDF can also trigger this prompt; cancel to return to recovery options.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: input,
                autofocus: true,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                onSubmitted: (value) => Navigator.pop(context, value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
    // Dialog route disposal follows its reverse transition.
    Future<void>.delayed(const Duration(seconds: 1), input.dispose);
    return password;
  }

  Future<void> _highlight(
    PdfViewerContextMenuBuilderParams params, {
    required bool comment,
  }) async {
    final save = widget.onHighlight;
    if (save == null) return;
    try {
      final ranges = await params.textSelectionDelegate.getSelectedTextRanges();
      if (!mounted || ranges.isEmpty || !_viewer.isReady) return;
      final quote = ranges.map((r) => r.text).join('\n');
      final regions = pdfSelectionRegions(ranges, _viewer.document.pages);
      params.dismissContextMenu();
      var text = '';
      if (comment) {
        final result = await showDialog<String>(
          context: context,
          builder: (context) => OrbitDialog(
            title: const Text('Comment on this passage'),
            content: SizedBox(
              width: 460,
              child: TextField(
                autofocus: true,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'What would you like to remember?',
                ),
                onChanged: (v) => text = v,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, text),
                child: const Text('Save highlight'),
              ),
            ],
          ),
        );
        if (result == null || !mounted) return;
        text = result;
      }
      final saved = await save(quote, regions, text);
      if (!mounted) return;
      if (saved) setState(() => _showAnnotations = true);
      _notice(
        saved
            ? 'Highlight saved. Open its note to edit comments or link it elsewhere.'
            : 'Highlight could not be saved. The original PDF is unchanged.',
      );
    } catch (e) {
      _notice('Could not save this selection: $e');
    }
  }

  void _paintAnnotations(Canvas canvas, Rect pageRect, PdfPage page) {
    for (final annotation in widget.annotations) {
      if (!annotation.matches(widget.checksum)) continue;
      for (final region in annotation.regions) {
        if (region.data['page'] != page.pageNumber) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            pageRect.left + region.x * pageRect.width,
            pageRect.top + region.y * pageRect.height,
            region.width * pageRect.width,
            region.height * pageRect.height,
          ),
          Paint()..color = Color(region.color).withAlpha(72),
        );
      }
    }
  }

  Widget _annotationPanel() {
    final query = _annotationQuery.trim().toLowerCase();
    final annotations = widget.annotations
        .where(
          (a) => '${a.object.title}\n${a.source['quote']}\n${a.object.body}'
              .toLowerCase()
              .contains(query),
        )
        .toList();
    return Container(
      height: 230,
      decoration: BoxDecoration(
        color: OrbitColors.of(context).raised,
        border: Border(top: BorderSide(color: OrbitColors.of(context).border)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 16,
                  color: OrbitColors.of(context).accent,
                ),
                const SizedBox(width: 8),
                Text(
                  'Highlights · ${widget.annotations.length}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Close highlights',
                  onPressed: () => setState(() => _showAnnotations = false),
                  icon: const Icon(Icons.close, size: 16),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _annotationInput,
              decoration: const InputDecoration(
                hintText: 'Filter highlights and comments',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _annotationQuery = value),
            ),
          ),
          Expanded(
            child: annotations.isEmpty
                ? const Center(
                    child: Text(
                      'No matching highlights. Select PDF text to add a highlight.',
                    ),
                  )
                : ListView.builder(
                    itemCount: annotations.length,
                    itemBuilder: (context, index) {
                      final annotation = annotations[index];
                      final matches = annotation.matches(widget.checksum);
                      return Material(
                        color: OrbitColors.of(context).raised,
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            matches ? Icons.format_quote : Icons.history,
                            color: OrbitColors.of(context).accent,
                          ),
                          title: Text(
                            annotation.source['quote'] is String
                                ? annotation.source['quote'] as String
                                : annotation.object.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            matches
                                ? 'Page ${annotation.source['page']} · click to return'
                                : 'PDF version changed · review source before re-anchoring',
                          ),
                          onTap: matches && annotation.source['page'] is int
                              ? () => _go(annotation.source['page'] as int)
                              : null,
                          trailing: IconButton(
                            tooltip: 'Open highlight note and comments',
                            onPressed: () => widget.onOpenAnnotation?.call(
                              annotation.object.id,
                            ),
                            icon: const Icon(Icons.open_in_new, size: 18),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.picture_as_pdf_outlined, size: 32),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(
                onPressed: () => setState(() {
                  _bytes = widget.loadBytes();
                }),
                child: const Text('Retry'),
              ),
              TextButton(
                onPressed: widget.onOpenOriginal,
                child: const Text('Open original externally'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.keyF, control: true): _find,
    },
    child: Focus(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: _comfort ? 'Original page' : 'Comfort reading',
                      isSelected: _comfort,
                      onPressed: _ready
                          ? () {
                              setState(() {
                                _comfort = !_comfort;
                                _textOnly = false;
                                _forms = false;
                              });
                              if (_comfort) {
                                _fitComfort();
                              } else {
                                _fitGeneration++;
                                _viewer.goTo(
                                  _viewer.calcMatrixFitWidthForPage(
                                    pageNumber: _page,
                                  ),
                                  duration: Duration.zero,
                                );
                              }
                            }
                          : null,
                      icon: const Icon(Icons.chrome_reader_mode_outlined),
                    ),
                    IconButton(
                      tooltip: _textOnly
                          ? 'Return to visual reading'
                          : 'Text-only reading',
                      isSelected: _textOnly,
                      onPressed:
                          _ready &&
                              (_viewer.document.permissions?.allowsCopying ??
                                  true)
                          ? () {
                              setState(() {
                                _textOnly = !_textOnly;
                                _comfort = true;
                                _forms = false;
                              });
                              if (!_textOnly) _fitComfort();
                            }
                          : null,
                      icon: const Icon(Icons.text_fields),
                    ),
                    if (widget.onFormChanged != null)
                      IconButton(
                        tooltip: 'Fill PDF forms',
                        isSelected: _forms,
                        onPressed: _ready && !widget.readOnly
                            ? () => setState(() {
                                _forms = !_forms;
                                _comfort = false;
                                _textOnly = false;
                              })
                            : null,
                        icon: const Icon(Icons.check_box_outlined),
                      ),
                    if (_forms && widget.onSaveFilledCopy != null)
                      OrbitControl(
                        label: _savingCopy ? 'Saving…' : 'Save filled copy',
                        onPressed:
                            _savingCopy ||
                                widget.formValues.isEmpty ||
                                widget.readOnly
                            ? null
                            : _saveFilledCopy,
                      ),
                    IconButton(
                      tooltip: 'Page thumbnails',
                      isSelected: _thumbnails,
                      onPressed: _ready
                          ? () => setState(() => _thumbnails = !_thumbnails)
                          : null,
                      icon: const Icon(Icons.view_sidebar_outlined),
                    ),
                    PopupMenuButton<int>(
                      tooltip: 'PDF outline',
                      enabled: _outline.isNotEmpty,
                      icon: const Icon(Icons.format_list_bulleted),
                      itemBuilder: (_) => _outlineItems(_outline),
                      onSelected: _go,
                    ),
                    IconButton(
                      tooltip: 'Previous page',
                      onPressed: _ready && _page > 1
                          ? () => _go(_page - 1)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    SizedBox(
                      width: 58,
                      child: TextField(
                        controller: _pageInput,
                        enabled: _ready,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.all(8),
                        ),
                        onSubmitted: (value) =>
                            _go(int.tryParse(value) ?? _page),
                      ),
                    ),
                    Text(' / ${_ready ? _viewer.pageCount : '—'}'),
                    IconButton(
                      tooltip: 'Next page',
                      onPressed: _ready && _page < _viewer.pageCount
                          ? () => _go(_page + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                    IconButton(
                      tooltip: 'Zoom out',
                      onPressed: _ready
                          ? () => _viewer.zoomDown(duration: Duration.zero)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    IconButton(
                      tooltip: 'Fit page width',
                      onPressed: _ready
                          ? () => _viewer.setZoom(
                              _viewer.centerPosition,
                              _viewer.coverScale,
                              duration: Duration.zero,
                            )
                          : null,
                      icon: const Icon(Icons.fit_screen),
                    ),
                    IconButton(
                      tooltip: 'Zoom in',
                      onPressed: _ready
                          ? () => _viewer.zoomUp(duration: Duration.zero)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                    IconButton(
                      tooltip: 'Find in PDF · Ctrl+F',
                      onPressed: _ready ? _find : null,
                      icon: const Icon(Icons.search),
                    ),
                    IconButton(
                      tooltip: 'Copy page reference',
                      onPressed: _ready ? _copyReference : null,
                      icon: const Icon(Icons.link),
                    ),
                    if (widget.onCreateDocument != null)
                      PopupMenuButton<ResearchDocument>(
                        tooltip: 'Create document from PDF',
                        enabled:
                            _ready && !widget.readOnly && !_creatingDocument,
                        onSelected: _createDocument,
                        itemBuilder: (_) => [
                          for (final document in ResearchDocument.values)
                            PopupMenuItem(
                              value: document,
                              child: Text(document.label),
                            ),
                        ],
                        icon: const Icon(Icons.post_add_rounded),
                      ),
                    IconButton(
                      tooltip: 'Highlights and comments',
                      isSelected: _showAnnotations,
                      onPressed: () =>
                          setState(() => _showAnnotations = !_showAnnotations),
                      icon: const Icon(Icons.edit_note_rounded),
                    ),
                    IconButton(
                      tooltip: widget.bookmarks.contains(_page)
                          ? 'Remove page bookmark'
                          : 'Bookmark page',
                      onPressed: !_ready || widget.readOnly
                          ? null
                          : () {
                              final pages = widget.bookmarks.toSet();
                              if (!pages.remove(_page)) {
                                pages.add(_page);
                              }
                              widget.onBookmarks(pages.toList()..sort());
                            },
                      icon: Icon(
                        widget.bookmarks.contains(_page)
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                      ),
                    ),
                    PopupMenuButton<int>(
                      tooltip: 'Saved pages',
                      enabled: widget.bookmarks.isNotEmpty,
                      icon: const Icon(Icons.bookmarks_outlined),
                      itemBuilder: (_) => [
                        for (final page in widget.bookmarks)
                          PopupMenuItem(value: page, child: Text('Page $page')),
                      ],
                      onSelected: _go,
                    ),
                    IconButton(
                      tooltip: 'Open original externally',
                      onPressed: widget.onOpenOriginal,
                      icon: const Icon(Icons.open_in_new),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_finding && _ready)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _query,
                      focusNode: _searchFocus,
                      decoration: const InputDecoration(
                        hintText: 'Find text in this PDF',
                        isDense: true,
                      ),
                      onChanged: (value) => _search!.startTextSearch(value),
                      onSubmitted: (_) => _search!.goToNextMatch(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _search!.isSearching
                        ? 'Searching…'
                        : '${_search!.matches.length} matches',
                  ),
                  IconButton(
                    tooltip: 'Previous match',
                    onPressed: _search!.hasMatches
                        ? _search!.goToPrevMatch
                        : null,
                    icon: const Icon(Icons.keyboard_arrow_up),
                  ),
                  IconButton(
                    tooltip: 'Next match',
                    onPressed: _search!.hasMatches
                        ? _search!.goToNextMatch
                        : null,
                    icon: const Icon(Icons.keyboard_arrow_down),
                  ),
                  IconButton(
                    tooltip: 'Close PDF search',
                    onPressed: () {
                      _search!.resetTextSearch();
                      setState(() => _finding = false);
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          Expanded(
            child: FutureBuilder<Uint8List?>(
              future: _bytes,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return _fallback(
                    'PDF bytes are unavailable. The file reference has been preserved.',
                  );
                }
                return Stack(
                  children: [
                    Row(
                      children: [
                        if (_thumbnails && _ready)
                          SizedBox(
                            width: 130,
                            child: ListView.builder(
                              itemCount: _viewer.pageCount,
                              itemBuilder: (context, index) => InkWell(
                                onTap: () => _go(index + 1),
                                child: Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: index + 1 == _page
                                          ? OrbitColors.of(context).accent
                                          : OrbitColors.of(context).border,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        height: 120,
                                        child: PdfPageView(
                                          document: _viewer.document,
                                          pageNumber: index + 1,
                                        ),
                                      ),
                                      Text('${index + 1}'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Expanded(
                          child: PdfViewer.data(
                            snapshot.data!,
                            sourceName: '${widget.objectId}:${widget.key}',
                            controller: _viewer,
                            initialPageNumber: widget.initialPage,
                            passwordProvider: _password,
                            params: PdfViewerParams(
                              onViewSizeChanged: (size, oldSize, controller) {
                                if (oldSize != null &&
                                    oldSize.width != size.width) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted) {
                                      _fitComfort(keepVerticalPosition: true);
                                    }
                                  });
                                }
                              },
                              pageOverlaysBuilder:
                                  _forms && widget.onFormChanged != null
                                  ? (context, rect, page) => [
                                      PdfFormLayer(
                                        key: ValueKey(
                                          'forms:${page.pageNumber}',
                                        ),
                                        document: _viewer.document,
                                        page: page,
                                        values: widget.formValues,
                                        onChanged: widget.onFormChanged!,
                                      ),
                                    ]
                                  : null,
                              backgroundColor: OrbitColors.of(context).panel,
                              onViewerReady: (document, controller) async {
                                if (!mounted) {
                                  return;
                                }
                                setState(() {
                                  _search?.dispose();
                                  _search = PdfTextSearcher(controller)
                                    ..addListener(_refresh);
                                  _ready = true;
                                  if (controller.viewSize.width < 600) {
                                    _comfort = true;
                                  }
                                });
                                if (_comfort) await _fitComfort();
                                final zoom = _comfort
                                    ? null
                                    : widget.initialZoom;
                                if (zoom != null && zoom.isFinite) {
                                  await controller.setZoom(
                                    controller.centerPosition,
                                    zoom.clamp(
                                      controller.minScale,
                                      controller.maxScale,
                                    ),
                                    duration: Duration.zero,
                                  );
                                }
                                try {
                                  final outline = await document.loadOutline();
                                  if (mounted) {
                                    setState(() => _outline = outline);
                                  }
                                } catch (_) {
                                  /* A malformed outline does not prevent reading. */
                                }
                              },
                              onPageChanged: (page) {
                                if (mounted && page != null) {
                                  final changed = _page != page;
                                  setState(() {
                                    _page = page;
                                    _pageInput.text = '$page';
                                  });
                                  _positionChanged();
                                  if (changed) _fitComfort();
                                }
                              },
                              errorBannerBuilder: (_, error, _, _) => _fallback(
                                'This PDF could not be opened. Its original bytes are unchanged.',
                              ),
                              pagePaintCallbacks: [
                                _paintAnnotations,
                                if (_search != null)
                                  _search!.pageTextMatchPaintCallback,
                              ],
                              linkHandlerParams: PdfLinkHandlerParams(
                                onLinkTap: (link) {
                                  if (link.dest != null) {
                                    _viewer.goToDest(
                                      link.dest,
                                      duration: Duration.zero,
                                    );
                                  }
                                  final url = link.url;
                                  if (url != null &&
                                      {
                                        'http',
                                        'https',
                                        'mailto',
                                      }.contains(url.scheme)) {
                                    widget.onOpenExternal(url);
                                  }
                                },
                              ),
                              customizeContextMenuItems: (params, items) {
                                if (params
                                        .textSelectionDelegate
                                        .isCopyAllowed &&
                                    params
                                        .textSelectionDelegate
                                        .hasSelectedText) {
                                  items.add(
                                    ContextMenuButtonItem(
                                      label: 'Copy quote with source',
                                      onPressed: () =>
                                          _quote(params, copy: true),
                                    ),
                                  );
                                  if (!widget.readOnly) {
                                    if (widget.onHighlight != null) {
                                      items.add(
                                        ContextMenuButtonItem(
                                          label: 'Highlight',
                                          onPressed: () => _highlight(
                                            params,
                                            comment: false,
                                          ),
                                        ),
                                      );
                                      items.add(
                                        ContextMenuButtonItem(
                                          label: 'Highlight and comment',
                                          onPressed: () =>
                                              _highlight(params, comment: true),
                                        ),
                                      );
                                    }
                                    items.add(
                                      ContextMenuButtonItem(
                                        label: 'Create linked note',
                                        onPressed: () =>
                                            _quote(params, copy: false),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_textOnly && _ready)
                      Positioned.fill(
                        child: PdfComfortPage(
                          key: ValueKey('comfort:$_page'),
                          page:
                              _viewer.document.pages[(_page - 1).clamp(
                                0,
                                _viewer.pageCount - 1,
                              )],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          if (_showAnnotations) _annotationPanel(),
        ],
      ),
    ),
  );

  List<PopupMenuEntry<int>> _outlineItems(
    List<PdfOutlineNode> nodes, [
    int depth = 0,
  ]) => [
    for (final node in nodes) ...[
      PopupMenuItem(
        value: node.dest?.pageNumber,
        enabled: node.dest != null,
        child: Padding(
          padding: EdgeInsets.only(left: depth * 12.0),
          child: Text(node.title),
        ),
      ),
      if (depth < 10) ..._outlineItems(node.children, depth + 1),
    ],
  ];
}
