import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import '../../application/search_execution.dart';
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;

import '../../app/orbit_theme.dart';
import '../../app/orbit_components.dart';
import '../../domain/research_document.dart';
import '../../domain/object_reference.dart';
import '../../domain/pdf_annotation.dart';
import '../../domain/pdf_review_batch.dart';
import '../../domain/pdf_quote_transfer.dart';
import '../../domain/universal_object.dart';
import '../../canvas/scene.dart';
import '../../platform/pdf_forms.dart';
import '../../platform/pdf_annotations.dart';
import 'pdf_work_widgets.dart';
import 'pdf_content_fit.dart';
import 'pdf_review_panel.dart';
import 'pdf_notes_panel.dart';
import 'pdf_zoom_dialog.dart';
import 'pdf_outline_dialog.dart';
import 'pdf_bookmarks_dialog.dart';
import 'reading_rooms/reading_room_model.dart';
import 'reading_rooms/reading_atmosphere_painter.dart';
import 'reading_rooms/reading_room_dialog.dart';

enum PdfPageMode { continuous, single, twoPage }

const pdfHighlightColors = <String, int>{
  'Yellow': 0xffeab308,
  'Green': 0xff22c55e,
  'Blue': 0xff3b82f6,
  'Purple': 0xff8b7cf6,
  'Coral': 0xffef4444,
};

List<CanvasElement> pdfSelectionRegions(
  List<PdfPageTextRange> ranges,
  List<PdfPage> pages, {
  int color = 0xff8b7cf6,
  String style = 'highlight',
}) => [
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
            'color': color,
            'style': style,
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
    this.initialReadingRoomId,
    this.initialZoom,
    this.bookmarks = const [],
    this.bookmarkNames = const {},
    this.onRenameBookmark,
    this.readOnly = false,
    this.checksum,
    this.annotations = const [],
    this.onHighlight,
    this.onOpenAnnotation,
    this.onCreateDocument,
    this.formValues = const {},
    this.onFormChanged,
    this.onSaveFilledCopy,
    this.onUpdateReview,
    this.onDeleteReview,
    this.onRestoreReview,
    this.onReviewBatch,
    this.onUndoReviewBatch,
    this.onReviewSummary,
    this.onReviewBoard,
    this.onExportReview,
    this.onPageComment,
    this.onSaveAnnotatedCopy,
    this.linkedNotes = const [],
    this.onOpenLinkedNote,
    this.onDeleteLinkedNote,
    this.onRestoreLinkedNote,
    this.initialAnnotationId,
    this.navigationRequest = 0,
    this.initialSearchChecksum,
    this.initialRecognizedMatch = false,
    this.initialSearchRegions = const [],
    this.onRecognizeText,
    this.initialSearchOffset,
    this.initialSearchLength = 0,
    this.onExtractToCanvas,
    this.onInsertIntoActiveNote,
    this.hasActiveNoteBeside = false,
    this.hasActiveCanvasBeside = false,
    this.initialFavorite = false,
    this.onToggleFavorite,
    this.onOpenMemories,
    this.onOpenBookshelf,
  });
  final bool initialFavorite;
  final ValueChanged<bool>? onToggleFavorite;
  final VoidCallback? onOpenMemories;
  final VoidCallback? onOpenBookshelf;
  final List<UniversalObject> linkedNotes;
  final ValueChanged<String>? onOpenLinkedNote;
  final Future<UniversalObject?> Function(UniversalObject)? onDeleteLinkedNote;
  final Future<bool> Function(UniversalObject)? onRestoreLinkedNote;
  final String? initialAnnotationId;
  final int navigationRequest;
  final String? initialSearchChecksum;
  final bool initialRecognizedMatch;
  final List<Map<String, double>> initialSearchRegions;
  final VoidCallback? onRecognizeText;
  final int? initialSearchOffset;
  final int initialSearchLength;
  final Future<bool> Function(String text, int page)? onExtractToCanvas;
  final Future<bool> Function(String text, int page)? onInsertIntoActiveNote;
  final bool hasActiveNoteBeside;
  final bool hasActiveCanvasBeside;
  final SavePdfReview? onUpdateReview;
  final Future<PdfAnnotation?> Function(PdfAnnotation)? onDeleteReview;
  final Future<bool> Function(PdfAnnotation)? onRestoreReview;
  final RunPdfReviewBatch? onReviewBatch;
  final UndoPdfReviewBatch? onUndoReviewBatch;
  final Future<bool> Function(List<String>)? onReviewSummary;
  final Future<bool> Function(List<PdfAnnotation>)? onReviewBoard;
  final Future<bool> Function(String)? onExportReview;
  final Future<bool> Function(int page, String comment)? onPageComment;
  final String objectId, title;
  final Map<String, dynamic> formValues;
  final Future<bool> Function(String, Object)? onFormChanged;
  final Future<bool> Function(Uint8List)? onSaveFilledCopy;
  final Future<bool> Function(Uint8List, List<PdfAnnotation>)?
  onSaveAnnotatedCopy;
  final Future<Uint8List?> Function() loadBytes;
  final VoidCallback onOpenOriginal;
  final ValueChanged<Uri> onOpenExternal;
  final void Function(int page, double zoom) onReadingState;
  final Future<void> Function(String text, int page) onQuote;
  final ValueChanged<List<int>> onBookmarks;
  final int initialPage;
  final String? initialReadingRoomId;
  final double? initialZoom;
  final List<int> bookmarks;
  final Map<int, String> bookmarkNames;
  final Future<bool> Function(int, String)? onRenameBookmark;
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
  PdfPageTextRange? _globalSearchRange;
  int? _globalOcrPage;
  PdfViewerController _viewer = PdfViewerController();
  PdfTextSearcher? _search;
  late Future<Uint8List?> _bytes = Future.sync(widget.loadBytes);
  int _documentEpoch = 0, _viewerEpoch = 0;
  late int _restorePage;
  double? _restoreZoom;
  bool _loadedOnce = false, _showNotes = false, _savingSelection = false;
  bool _reviewExpanded = false;
  final _reviewPanelKey = GlobalKey(debugLabel: 'PDF review workspace');
  bool _sourceNavigationPending = true;
  (int, double)? _pendingPosition;
  void Function(int, double)? _pendingPositionCallback;
  final _query = TextEditingController();
  final _pageInput = TextEditingController();
  bool _showMarkup = true;
  final _searchFocus = FocusNode();
  final _notesSearchFocus = FocusNode(debugLabel: 'Connected note search');
  final _readerFocus = FocusNode(debugLabel: 'PDF reader');
  final _thumbnailFocus = FocusNode(debugLabel: 'PDF thumbnails');
  final _thumbnailScroll = ScrollController();
  final _toolbarScroll = ScrollController();
  Timer? _saveTimer;
  bool _ready = false;
  bool _forms = false, _comfort = false, _savingCopy = false;
  bool _textOnly = false;
  bool _savingAnnotations = false;
  int _zoomPercent = 100;
  int _fitGeneration = 0;
  final _contentWidths = <int, Future<Rect>>{};
  PdfPageMode _pageMode = PdfPageMode.continuous;
  int _activeColor = 0xff8b7cf6;
  String? _activeHighlightId;
  late PdfAnnotationIndex _annotationIndex;
  final _pendingMarkup = <int, List<CanvasElement>>{};
  final _deletingReviewIds = <String>{};
  Timer? _highlightPulseTimer;
  ReadingRoom? _activeReadingRoom;
  String _paperTone = 'normal';
  bool _zenMode = false;
  bool _zenControlsVisible = true;
  late bool _isFavorite;
  int? _sessionSecondsRemaining;
  Timer? _sessionTimer;

  PdfPageLayout _layoutPages(List<PdfPage> pages, PdfViewerParams params) {
    if (_pageMode == PdfPageMode.single) {
      final height =
          pages.fold(0.0, (prev, page) => math.max(prev, page.height)) +
          params.margin * 2;
      final pageLayouts = <Rect>[];
      var x = params.margin;
      for (final page in pages) {
        pageLayouts.add(
          Rect.fromLTWH(x, (height - page.height) / 2, page.width, page.height),
        );
        x += page.width + params.margin;
      }
      return PdfPageLayout(
        pageLayouts: pageLayouts,
        documentSize: Size(x, height),
      );
    } else if (_pageMode == PdfPageMode.twoPage) {
      double maxWidth = 0;
      for (var i = 0; i < pages.length; i += 2) {
        final p1 = pages[i];
        final p2 = i + 1 < pages.length ? pages[i + 1] : null;
        final pairWidth =
            p1.width +
            (p2 != null ? p2.width + params.margin : 0) +
            params.margin * 2;
        maxWidth = math.max(maxWidth, pairWidth);
      }
      final pageLayouts = <Rect>[];
      var y = params.margin;
      for (var i = 0; i < pages.length; i += 2) {
        final p1 = pages[i];
        final p2 = i + 1 < pages.length ? pages[i + 1] : null;
        final pairWidth =
            p1.width + (p2 != null ? p2.width + params.margin : 0);
        final rowHeight = math.max(p1.height, p2?.height ?? 0);
        final startX = (maxWidth - pairWidth) / 2;
        pageLayouts.add(
          Rect.fromLTWH(
            startX,
            y + (rowHeight - p1.height) / 2,
            p1.width,
            p1.height,
          ),
        );
        if (p2 != null) {
          pageLayouts.add(
            Rect.fromLTWH(
              startX + p1.width + params.margin,
              y + (rowHeight - p2.height) / 2,
              p2.width,
              p2.height,
            ),
          );
        }
        y += rowHeight + params.margin;
      }
      return PdfPageLayout(
        pageLayouts: pageLayouts,
        documentSize: Size(maxWidth, y),
      );
    } else {
      final width =
          pages.fold(0.0, (w, p) => math.max(w, p.width)) + params.margin * 2;
      final pageLayout = <Rect>[];
      var y = params.margin;
      for (var i = 0; i < pages.length; i++) {
        final page = pages[i];
        final rect = Rect.fromLTWH(
          (width - page.width) / 2,
          y,
          page.width,
          page.height,
        );
        pageLayout.add(rect);
        y += page.height + params.margin;
      }
      return PdfPageLayout(
        pageLayouts: pageLayout,
        documentSize: Size(width, y),
      );
    }
  }

  void _setActiveHighlight(String id) {
    _highlightPulseTimer?.cancel();
    _activeHighlightId = id;
    if (_viewer.isReady) _viewer.invalidate();
    _highlightPulseTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _activeHighlightId == id) {
        _activeHighlightId = null;
        if (_viewer.isReady) _viewer.invalidate();
      }
    });
  }

  Future<void> _goToAnnotation(PdfAnnotation annotation) async {
    if (!annotation.matches(widget.checksum)) {
      _notice(
        'The PDF version changed. Review the source before returning to this highlight.',
      );
      return;
    }
    _fitGeneration++;
    setState(() {
      _textOnly = false;
      _comfort = false;
    });
    final targetPage = annotation.source['page'] is int
        ? annotation.source['page'] as int
        : 1;
    _setActiveHighlight(annotation.object.id);

    if (!_viewer.isReady) {
      _go(targetPage);
      return;
    }

    final bounds = annotation.boundsForPage(targetPage);
    if (bounds == null) {
      _go(targetPage);
      return;
    }

    final pageIndex = (targetPage - 1).clamp(
      0,
      _viewer.document.pages.length - 1,
    );
    final pageLayout = _viewer.layout.pageLayouts[pageIndex];

    final regionRect = Rect.fromLTWH(
      pageLayout.left + bounds.left * pageLayout.width,
      pageLayout.top + bounds.top * pageLayout.height,
      bounds.width * pageLayout.width,
      bounds.height * pageLayout.height,
    );

    final viewWidth = _viewer.viewSize.width > 0
        ? _viewer.viewSize.width
        : 800.0;
    final viewHeight = _viewer.viewSize.height > 0
        ? _viewer.viewSize.height
        : 600.0;

    final desiredScaleW = (viewWidth - 80) / math.max(regionRect.width, 80);
    final desiredScaleH = (viewHeight - 120) / math.max(regionRect.height, 60);
    final idealZoom = math
        .min(desiredScaleW, desiredScaleH)
        .clamp(_viewer.minScale, math.max(_viewer.minScale, 2.4))
        .toDouble();

    if (!idealZoom.isFinite ||
        !regionRect.center.dx.isFinite ||
        !regionRect.center.dy.isFinite) {
      _go(targetPage);
      return;
    }

    try {
      final matrix = _viewer.calcMatrixFor(regionRect.center, zoom: idealZoom);
      await _viewer.goTo(matrix, duration: const Duration(milliseconds: 200));
    } catch (_) {
      _go(targetPage);
    }
  }

  Future<void> _setPageMode(PdfPageMode mode) async {
    if (_pageMode == mode) return;
    _rememberPosition();
    setState(() {
      _restorePage = _page;
      _restoreZoom = _viewer.isReady ? _viewer.currentZoom : _restoreZoom;
      _pageMode = mode;
      _comfort = false;
      _textOnly = false;
      _resetViewer();
    });
  }

  void _resetViewer() {
    _globalSearchRange = null;
    _globalOcrPage = null;
    _viewerEpoch++;
    _fitGeneration++;
    _ready = false;
    _search?.dispose();
    _search = null;
    // A remounted viewer must have its own controller: disposal of the old
    // viewer would otherwise detach the controller already used by the new one.
    _viewer.removeListener(_positionChanged);
    _viewer = PdfViewerController()..addListener(_positionChanged);
    _outline = const [];
    _outlineLoading = true;
    _outlineFailed = false;
    _highlightPulseTimer?.cancel();
    _activeHighlightId = null;
    _pendingMarkup.clear();
  }

  void _retry() {
    setState(() {
      _rememberPosition();
      _restorePage = _page;
      _resetViewer();
      _documentEpoch++;
      _contentWidths.clear();
      _bytes = Future.sync(widget.loadBytes);
    });
  }

  Future<void> _navigateRequestedSource() async {
    _sourceNavigationPending = false;
    if (widget.initialSearchChecksum != null &&
        (widget.initialSearchOffset != null || widget.initialRecognizedMatch)) {
      try {
        final serial = widget.navigationRequest;
        final epoch = _viewerEpoch;
        final bytes = await _bytes;
        if (bytes == null) return;
        final hash = await runSearchWork(
          () => sha256.convert(bytes).toString(),
          size: bytes.length,
        );
        if (!mounted ||
            epoch != _viewerEpoch ||
            serial != widget.navigationRequest ||
            !_viewer.isReady) {
          return;
        }
        if (hash != widget.initialSearchChecksum) {
          _notice(
            'The PDF changed. Refresh global search before opening this match.',
          );
          return;
        }
        final page = widget.initialPage;
        if (page < 1 || page > _viewer.document.pages.length) return;
        if (widget.initialRecognizedMatch) {
          setState(() {
            _globalSearchRange = null;
            _globalOcrPage = page;
          });
          _go(page);
          _viewer.invalidate();
          _notice(
            widget.initialSearchRegions.isEmpty
                ? 'Recognized or corrected text · source page shown. Verify against the original.'
                : 'Recognized text · matching source lines highlighted. Verify against the original.',
          );
          return;
        }
        // Viewer pages load progressively. Formatting an unloaded page returns
        // empty text in pdfrx; wait for its actual page instance before mapping.
        final loadedPage = await _viewer.document.pages[page - 1].waitForLoaded(
          timeout: const Duration(seconds: 30),
        );
        if (loadedPage == null ||
            !mounted ||
            epoch != _viewerEpoch ||
            serial != widget.navigationRequest) {
          return;
        }
        final text = await loadedPage.loadStructuredText();
        if (!mounted ||
            epoch != _viewerEpoch ||
            serial != widget.navigationRequest ||
            !_viewer.isReady) {
          return;
        }
        final start = widget.initialSearchOffset!;
        final end = start + widget.initialSearchLength;
        if (start < 0 || end > text.fullText.length || end <= start) return;
        final range = PdfPageTextRange(pageText: text, start: start, end: end);
        setState(() => _globalSearchRange = range);
        await _search?.goToMatch(range);
      } on Object {
        if (mounted) {
          _notice('Could not locate this match. Refresh global search.');
        }
      }
      return;
    }
    _globalSearchRange = null;
    _globalOcrPage = null;
    final id = widget.initialAnnotationId;
    for (final annotation in widget.annotations) {
      if (annotation.object.id == id && annotation.matches(widget.checksum)) {
        await _goToAnnotation(annotation);
        return;
      }
    }
    _go(widget.initialPage);
  }

  void _openNote(String id, {bool annotation = false}) {
    _rememberPosition();
    _flushReadingState();
    (annotation ? widget.onOpenAnnotation : widget.onOpenLinkedNote)?.call(id);
  }

  Future<void> _copyReview(List<PdfAnnotation> items) async {
    try {
      await Clipboard.setData(
        ClipboardData(
          text: pdfReviewMarkdown(
            widget.title,
            widget.objectId,
            items,
            checksum: widget.checksum,
          ),
        ),
      );
      _notice('Review copied as Markdown with stable source links.');
    } catch (_) {
      _notice('Could not access the clipboard. Your notes are unchanged.');
    }
  }

  Future<void> _exportReview(List<PdfAnnotation> items) async {
    try {
      final saved = await widget.onExportReview!(
        pdfReviewMarkdown(
          widget.title,
          widget.objectId,
          items,
          checksum: widget.checksum,
        ),
      );
      if (saved) {
        _notice('Review exported as Markdown. Original PDF unchanged.');
      }
    } catch (_) {
      _notice('Could not export. The PDF and review notes are unchanged.');
    }
  }

  void _editReview(PdfAnnotation annotation) {
    if (widget.readOnly ||
        annotation.object.isReadOnly ||
        annotation.fileId != widget.objectId ||
        widget.onUpdateReview == null ||
        !annotation.matches(widget.checksum)) {
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PdfReviewEditor(
        annotation: annotation,
        colors: pdfHighlightColors,
        onSave: widget.onUpdateReview!,
      ),
    );
  }

  Future<void> _deleteReview(PdfAnnotation annotation) async {
    final remove = widget.onDeleteReview, restore = widget.onRestoreReview;
    final id = annotation.object.id,
        fileId = widget.objectId,
        epoch = _documentEpoch;
    if (widget.readOnly ||
        annotation.object.isReadOnly ||
        annotation.fileId != widget.objectId ||
        remove == null ||
        !_deletingReviewIds.add(id)) {
      return;
    }
    setState(() {});
    bool current() =>
        mounted && widget.objectId == fileId && _documentEpoch == epoch;
    PdfAnnotation? deleted;
    try {
      deleted = await remove(annotation);
    } catch (_) {}
    if (!mounted || !current()) {
      if (mounted) {
        setState(() => _deletingReviewIds.remove(id));
      } else {
        _deletingReviewIds.remove(id);
      }
      return;
    }
    setState(() => _deletingReviewIds.remove(id));
    if (deleted == null) {
      _notice(
        'Could not delete this review item. It may have changed or have unsaved edits; refresh and retry.',
      );
      return;
    }
    if (_activeHighlightId == id) _activeHighlightId = null;
    if (_viewer.isReady) _viewer.invalidate();
    final snapshot = deleted;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${annotation.isPageComment ? 'Comment' : 'Highlight'} and its note moved to Trash.',
          ),
          duration: const Duration(seconds: 8),
          action: restore == null
              ? null
              : SnackBarAction(
                  label: 'Undo',
                  onPressed: () async {
                    if (!current()) return;
                    var restored = false;
                    try {
                      restored = !widget.readOnly && await restore(snapshot);
                    } catch (_) {}
                    if (current() && !restored) {
                      _notice(
                        'Could not undo. The latest note is preserved; you can restore it from Trash.',
                      );
                    }
                  },
                ),
        ),
      );
  }

  Future<void> _addPageComment() async {
    final page = _page;
    final save = widget.onPageComment;
    final fileId = widget.objectId, checksum = widget.checksum;
    var text = '';
    var busy = false;
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, update) => PopScope(
          canPop: !busy,
          child: OrbitDialog(
            title: Text('Comment on page $page'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Add a page note, including on scans and diagrams. It links back to this PDF and stays editable in Orbit.',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      autofocus: true,
                      enabled: !busy,
                      minLines: 3,
                      maxLines: 8,
                      maxLength: 100000,
                      decoration: const InputDecoration(labelText: 'Comment'),
                      onChanged: (v) => text = v,
                    ),
                    if (error != null) Text(error!),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialog),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (text.trim().isEmpty) {
                          update(() => error = 'Write a comment first.');
                          return;
                        }
                        update(() {
                          busy = true;
                          error = null;
                        });
                        var saved = false;
                        try {
                          if (mounted &&
                              !widget.readOnly &&
                              widget.objectId == fileId &&
                              widget.checksum == checksum) {
                            saved = await save!(page, text);
                          }
                        } catch (_) {}
                        if (!dialog.mounted) return;
                        if (saved) {
                          Navigator.pop(dialog);
                          if (mounted) setState(() => _showAnnotations = true);
                        } else {
                          update(() {
                            busy = false;
                            error =
                                'Could not save. Your comment is kept here; retry.';
                          });
                        }
                      },
                child: Text(busy ? 'Saving…' : 'Save page comment'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHighlightDetail(PdfAnnotation annotation) {
    _setActiveHighlight(annotation.object.id);
    final quote = annotation.source['quote'] is String
        ? annotation.source['quote'] as String
        : '';
    final page = annotation.source['page'] is int
        ? annotation.source['page'] as int
        : 1;
    final comment = annotation.object.body.trim();
    final color = Color(annotation.color);
    final style = annotation.style;

    showDialog<void>(
      context: context,
      builder: (context) => OrbitDialog(
        title: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(
                  style == 'underline' ? 1 : 7,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${annotation.isPageComment ? 'Page comment' : 'Highlight'} · p. $page ($style)',
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (quote.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: OrbitColors.of(context).raised,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(left: BorderSide(color: color, width: 3)),
                    ),
                    child: SelectableText(
                      quote,
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ),
                if (comment.isNotEmpty && comment != quote) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Comment',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: OrbitColors.of(context).accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(comment),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (!widget.readOnly &&
              !annotation.object.isReadOnly &&
              widget.onDeleteReview != null)
            TextButton.icon(
              onPressed: _deletingReviewIds.contains(annotation.object.id)
                  ? null
                  : () {
                      Navigator.pop(context);
                      _deleteReview(annotation);
                    },
              icon: const Icon(Icons.delete_outline),
              label: Text(
                annotation.isPageComment
                    ? 'Delete comment'
                    : 'Delete highlight',
              ),
            ),
          if (!widget.readOnly &&
              !annotation.object.isReadOnly &&
              widget.onUpdateReview != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _editReview(annotation);
              },
              child: const Text('Edit review'),
            ),
          TextButton(
            onPressed: () async {
              try {
                await Clipboard.setData(ClipboardData(text: quote));
              } catch (_) {
                _notice('Clipboard unavailable. Review unchanged.');
                return;
              }
              if (context.mounted) {
                Navigator.pop(context);
                _notice('Quote copied to clipboard.');
              }
            },
            child: const Text('Copy quote'),
          ),
          if (widget.onOpenAnnotation != null)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _openNote(annotation.object.id, annotation: true);
              },
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open note & comments'),
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
        ],
      ),
    );
  }

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
      if (pageNumber - 1 >= _viewer.layout.pageLayouts.length) return;
      final page = _viewer.layout.pageLayouts[pageNumber - 1];
      final contentWidth = math.max(
        1.0,
        page.width * math.max(0.1, area.width),
      );
      final availableWidth = math.max(1.0, _viewer.viewSize.width - 16);
      final zoom = (availableWidth / contentWidth).clamp(
        _viewer.minScale,
        _viewer.maxScale,
      );

      final targetX = page.left + page.width * area.center.dx;
      final defaultTargetY =
          page.top + (_viewer.viewSize.height / 2 - 8) / zoom;
      final targetY =
          (keepVerticalPosition &&
              _viewer.centerPosition.dy.isFinite &&
              _viewer.centerPosition.dy >= page.top &&
              _viewer.centerPosition.dy <= page.bottom)
          ? _viewer.centerPosition.dy
          : defaultTargetY;

      await _viewer.goTo(
        _viewer.calcMatrixFor(Offset(targetX, targetY), zoom: zoom),
        duration: Duration.zero,
      );
    } catch (_) {
      if (mounted &&
          generation == _fitGeneration &&
          _comfort &&
          !_textOnly &&
          _viewer.isReady) {
        final matrix = _viewer.calcMatrixFitWidthForPage(
          pageNumber: pageNumber,
        );
        if (matrix != null) {
          await _viewer.goTo(matrix, duration: Duration.zero);
        }
      }
    }
  }

  bool _thumbnails = false;
  bool _finding = false;
  bool _showAnnotations = false;
  bool _creatingDocument = false;

  int _page = 1;
  List<PdfOutlineNode> _outline = const [];
  bool _outlineLoading = true, _outlineFailed = false;
  final _previousPages = <int>[];
  final _nextPages = <int>[];

  void _rememberPageJump() {
    if (_previousPages.isEmpty || _previousPages.last != _page) {
      _previousPages.add(_page);
    }
    if (_previousPages.length > 100) _previousPages.removeAt(0);
    _nextPages.clear();
  }

  void _visitHistory(bool forward) {
    if (!_ready) return;
    final from = forward ? _nextPages : _previousPages;
    final to = forward ? _previousPages : _nextPages;
    if (from.isEmpty) return;
    to.add(_page);
    final page = from.removeLast();
    _go(page, remember: false);
  }

  void _documentInfo() {
    if (!_ready || !_viewer.isReady) return;
    final document = _viewer.document;
    final page = document.pages[_page - 1];
    showDialog<void>(
      context: context,
      builder: (context) => OrbitDialog(
        title: const Text('Document information'),
        content: SizedBox(
          width: 460,
          child: SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.title),
                const SizedBox(height: 12),
                Text('Pages: ${document.pages.length}'),
                Text('Current page: $_page'),
                Text(
                  'Page size: ${(page.width * 25.4 / 72).toStringAsFixed(1)} × ${(page.height * 25.4 / 72).toStringAsFixed(1)} mm',
                ),
                Text('Encrypted: ${document.isEncrypted ? 'Yes' : 'No'}'),
                Text(
                  'Content copying: ${document.permissions == null
                      ? 'Not specified'
                      : document.permissions!.allowsCopying
                      ? 'Allowed'
                      : 'Restricted'}',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showOutline() async {
    if (!_ready) return;
    final epoch = _viewerEpoch;
    final destination = await showDialog<PdfDest>(
      context: context,
      builder: (_) =>
          PdfOutlineDialog(nodes: _outline, loadFailed: _outlineFailed),
    );
    if (!mounted ||
        !_ready ||
        !_viewer.isReady ||
        epoch != _viewerEpoch ||
        destination == null) {
      return;
    }
    _rememberPageJump();
    await _viewer.goToDest(destination, duration: Duration.zero);
  }

  Future<void> _showBookmarks() async {
    if (!_ready || !_viewer.isReady) return;
    final epoch = _viewerEpoch;
    final page = await showDialog<int>(
      context: context,
      builder: (_) => PdfBookmarksDialog(
        pages: widget.bookmarks,
        names: widget.bookmarkNames,
        pageCount: _viewer.pageCount,
        onRename: widget.readOnly || widget.onRenameBookmark == null
            ? null
            : (page, name) async {
                if (!mounted || epoch != _viewerEpoch || widget.readOnly) {
                  return false;
                }
                return widget.onRenameBookmark!(page, name);
              },
        loadPreview: (number) async {
          if (!mounted ||
              !_ready ||
              epoch != _viewerEpoch ||
              !_viewer.isReady) {
            return null;
          }
          final page = _viewer.document.pages[number - 1];
          final scale = 480 / math.max(page.width, page.height);
          final rendered = await page.render(
            fullWidth: page.width * scale,
            fullHeight: page.height * scale,
            backgroundColor: 0xffffffff,
          );
          if (rendered == null) return null;
          try {
            final image = await rendered.createImage();
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              if (!mounted || epoch != _viewerEpoch) return null;
              return bytes?.buffer.asUint8List();
            } finally {
              image.dispose();
            }
          } finally {
            rendered.dispose();
          }
        },
      ),
    );
    if (mounted && _ready && epoch == _viewerEpoch && page != null) _go(page);
  }

  Future<void> _readingTool(String tool) async {
    if (!_ready || !_viewer.isReady) return;
    if (tool == 'custom') {
      final epoch = _viewerEpoch;
      final zoom = await showDialog<double>(
        context: context,
        builder: (_) => PdfZoomDialog(
          current: _viewer.currentZoom * 100,
          minimum: _viewer.minScale * 100,
          maximum: _viewer.maxScale * 100,
        ),
      );
      if (!mounted || !_ready || epoch != _viewerEpoch || zoom == null) return;
      await _readingTool('$zoom');
      return;
    }
    _fitGeneration++;
    setState(() {
      _textOnly = false;
      _comfort = tool == 'content';
    });
    if (tool == 'content') {
      await _fitComfort();
      return;
    }
    if (tool == 'page' || tool == 'width') {
      await _viewer.goTo(
        tool == 'page'
            ? _viewer.calcMatrixForFit(pageNumber: _page)
            : _viewer.calcMatrixFitWidthForPage(pageNumber: _page),
        duration: Duration.zero,
      );
    } else {
      final zoom = double.tryParse(tool);
      if (zoom != null) {
        await _viewer.setZoom(
          _viewer.centerPosition,
          zoom.clamp(_viewer.minScale, _viewer.maxScale),
          duration: Duration.zero,
        );
      }
    }
    if (mounted && _viewer.isReady) {
      setState(() => _zoomPercent = (_viewer.currentZoom * 100).round());
    }
  }

  @override
  void initState() {
    super.initState();
    _annotationIndex = PdfAnnotationIndex(
      widget.annotations,
      widget.objectId,
      widget.checksum,
    );
    _restoreReadingRoom();
    _isFavorite = widget.initialFavorite;
    _page = math.max(1, widget.initialPage);
    _restorePage = _page;
    _restoreZoom = widget.initialZoom;
    _pageInput.text = '$_page';
    _viewer.addListener(_positionChanged);
  }

  void _restoreReadingRoom() {
    _activeReadingRoom = ReadingRoomCatalog.all
        .where((room) => room.id == widget.initialReadingRoomId)
        .firstOrNull;
  }

  @override
  void didUpdateWidget(OrbitPdfReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    final annotationsChanged = !_annotationIndex.matches(
      widget.annotations,
      widget.objectId,
      widget.checksum,
    );
    if (annotationsChanged) {
      _annotationIndex = PdfAnnotationIndex(
        widget.annotations,
        widget.objectId,
        widget.checksum,
        previous: _annotationIndex,
      );
    }
    if (widget.objectId != oldWidget.objectId ||
        widget.initialReadingRoomId != oldWidget.initialReadingRoomId) {
      _restoreReadingRoom();
    }
    if (widget.initialFavorite != oldWidget.initialFavorite) {
      _isFavorite = widget.initialFavorite;
    }
    if (widget.objectId != oldWidget.objectId ||
        widget.checksum != oldWidget.checksum ||
        (widget.initialSearchChecksum != null &&
            widget.initialSearchChecksum != oldWidget.initialSearchChecksum &&
            widget.initialSearchChecksum != widget.checksum)) {
      _flushReadingState();
      _restorePage = _page = math.max(1, widget.initialPage);
      _restoreZoom = widget.initialZoom;
      _pageInput.text = '$_page';
      _resetViewer();
      _documentEpoch++;
      _loadedOnce = false;
      _previousPages.clear();
      _nextPages.clear();
      _sourceNavigationPending = true;
      _contentWidths.clear();
      _bytes = Future.sync(widget.loadBytes);
      return;
    }
    if (_viewer.isReady && annotationsChanged) {
      _viewer.invalidate();
    }
    if (widget.navigationRequest != oldWidget.navigationRequest ||
        widget.initialAnnotationId != oldWidget.initialAnnotationId) {
      _sourceNavigationPending = true;
      if (_ready && _viewer.isReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _ready && _viewer.isReady) _navigateRequestedSource();
        });
      }
    } else if (widget.initialPage != oldWidget.initialPage &&
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
    _rememberPosition();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted && _viewer.isReady) {
        final percent = (_viewer.currentZoom * 100).round();
        if (percent != _zoomPercent) setState(() => _zoomPercent = percent);
        _flushReadingState();
      }
    });
  }

  void _rememberPosition() {
    if (!_ready || !_viewer.isReady) return;
    _pendingPosition = (_viewer.pageNumber ?? _page, _viewer.currentZoom);
    _pendingPositionCallback = widget.onReadingState;
  }

  void _flushReadingState() {
    _saveTimer?.cancel();
    final position = _pendingPosition;
    final callback = _pendingPositionCallback;
    _pendingPosition = null;
    _pendingPositionCallback = null;
    if (position != null) callback?.call(position.$1, position.$2);
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _flushReadingState();
    _highlightPulseTimer?.cancel();
    _search?.dispose();
    _viewer.removeListener(_positionChanged);
    _query.dispose();
    _pageInput.dispose();

    _searchFocus.dispose();
    _notesSearchFocus.dispose();
    _readerFocus.dispose();
    _thumbnailFocus.dispose();
    _thumbnailScroll.dispose();
    _toolbarScroll.dispose();
    super.dispose();
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
    });
    widget.onToggleFavorite?.call(_isFavorite);
  }

  void _openReadingRoomSheet() {
    ReadingRoomAmbienceSheet.show(
      context,
      initialRoom: _activeReadingRoom ?? ReadingRoomCatalog.rainyLibrary,
      activeColorFilter: _paperTone,
      onRoomChanged: (room) {
        setState(() => _activeReadingRoom = room);
      },
      onColorFilterChanged: (filter) {
        setState(() => _paperTone = filter);
      },
      onStartSession: (minutes, room) {
        _startSession(minutes, room);
      },
    );
  }

  void _startSession(int minutes, ReadingRoom room) {
    _sessionTimer?.cancel();
    setState(() {
      _activeReadingRoom = room;
      _sessionSecondsRemaining = minutes * 60;
    });
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_sessionSecondsRemaining != null && _sessionSecondsRemaining! > 0) {
        setState(() {
          _sessionSecondsRemaining = _sessionSecondsRemaining! - 1;
        });
        if (_sessionSecondsRemaining == 0) {
          timer.cancel();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '✨ Reading session complete ($minutes min in ${room.name})!',
                ),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } else {
        timer.cancel();
      }
    });
  }

  Widget _buildFilteredViewer(Widget child) {
    Widget filtered = child;
    switch (_paperTone) {
      case 'sepia':
        filtered = ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Color(0xFFEEDBB2),
            BlendMode.multiply,
          ),
          child: child,
        );
      case 'editorial':
        filtered = ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Color(0xFFF3EEE3),
            BlendMode.multiply,
          ),
          child: child,
        );
      case 'dark':
        filtered = ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            -0.85,
            0,
            0,
            0,
            220,
            0,
            -0.85,
            0,
            0,
            220,
            0,
            0,
            -0.85,
            0,
            220,
            0,
            0,
            0,
            1,
            0,
          ]),
          child: child,
        );
      case 'normal':
      default:
        break;
    }

    if (_activeReadingRoom != null) {
      return ReadingAtmosphere(room: _activeReadingRoom!, child: filtered);
    }
    return filtered;
  }

  void _go(int page, {bool remember = true}) {
    if (_viewer.isReady) {
      final target = page.clamp(1, _viewer.pageCount);
      if (remember && target != _page) _rememberPageJump();
      setState(() {
        _page = target;
        _pageInput.text = '$target';
      });
      _viewer.goToPage(pageNumber: target, duration: Duration.zero);
    }
  }

  double get _thumbnailExtent =>
      180 + MediaQuery.textScalerOf(context).scale(20);

  void _revealThumbnail() {
    if (!_thumbnailScroll.hasClients) return;
    final offset = ((_page - 1) * _thumbnailExtent).clamp(
      0.0,
      _thumbnailScroll.position.maxScrollExtent,
    );
    _thumbnailScroll.jumpTo(offset);
  }

  KeyEventResult _thumbnailKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      setState(() => _thumbnails = false);
      _readerFocus.requestFocus();
    } else if (key == LogicalKeyboardKey.enter) {
      _readerFocus.requestFocus();
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.home ||
        key == LogicalKeyboardKey.end) {
      _go(
        key == LogicalKeyboardKey.home
            ? 1
            : key == LogicalKeyboardKey.end
            ? _viewer.pageCount
            : _page + (key == LogicalKeyboardKey.arrowDown ? 1 : -1),
      );
      _revealThumbnail();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _find() {
    _globalSearchRange = null;
    _globalOcrPage = null;
    _comfort = false;
    _textOnly = false;
    setState(() => _finding = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocus.requestFocus();
      }
    });
  }

  Future<void> _saveAnnotatedCopy(List<PdfAnnotation> items) async {
    if (_savingAnnotations ||
        !_ready ||
        widget.readOnly ||
        widget.onSaveAnnotatedCopy == null ||
        widget.checksum == null) {
      return;
    }
    final checksum = widget.checksum!;
    final fileId = widget.objectId;
    final save = widget.onSaveAnnotatedCopy!;
    final snapshot = List<PdfAnnotation>.of(items);
    setState(() => _savingAnnotations = true);
    try {
      final source = await _bytes;
      if (source == null) throw StateError('Source PDF is unavailable.');
      final bytes = await exportPdfAnnotations(
        source,
        fileId,
        checksum,
        snapshot,
      );
      if (!mounted) return;
      if (widget.checksum != checksum ||
          widget.objectId != fileId ||
          widget.readOnly ||
          snapshot.any(
            (a) => !widget.annotations.any(
              (current) => identical(current.object, a.object),
            ),
          )) {
        throw StateError('The source or review changed. Please export again.');
      }
      final saved = await save(bytes, snapshot);
      if (!mounted) return;
      _notice(
        saved
            ? 'Annotated copy saved as a separate PDF in this Vault.'
            : 'Could not save the annotated copy. Review notes are retained; please retry.',
      );
    } catch (error) {
      if (mounted) _notice('Could not export annotated PDF: $error');
    } finally {
      if (mounted) setState(() => _savingAnnotations = false);
    }
  }

  Future<void> _saveFilledCopy() async {
    if (_savingCopy ||
        !_ready ||
        widget.readOnly ||
        widget.onSaveFilledCopy == null) {
      return;
    }
    final fileId = widget.objectId, checksum = widget.checksum;
    final values = Map<String, dynamic>.of(widget.formValues);
    final save = widget.onSaveFilledCopy!;
    setState(() => _savingCopy = true);
    try {
      final bytes = await applyPdfFields(_viewer.document, values);
      if (!mounted) return;
      if (widget.objectId != fileId ||
          widget.checksum != checksum ||
          widget.readOnly ||
          !mapEquals(values, widget.formValues)) {
        throw StateError(
          'The PDF or field drafts changed. Please save the copy again.',
        );
      }
      final saved = await save(bytes);
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
    try {
      await Clipboard.setData(
        ClipboardData(
          text: ObjectReference(
            widget.objectId,
            page: _page,
          ).markdown(widget.title),
        ),
      );
      _notice('Page reference copied. Paste it into a note.');
    } catch (_) {
      _notice('Clipboard unavailable. Your PDF and notes are unchanged.');
    }
  }

  Future<void> _quote(
    PdfViewerContextMenuBuilderParams params, {
    required bool copy,
  }) async {
    if (_savingSelection) return;
    final fileId = widget.objectId, checksum = widget.checksum;
    final save = widget.onQuote;
    _savingSelection = true;
    try {
      final ranges = await params.textSelectionDelegate.getSelectedTextRanges();
      if (!mounted ||
          ranges.isEmpty ||
          widget.objectId != fileId ||
          widget.checksum != checksum) {
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
        if (widget.readOnly) return;
        _rememberPosition();
        _flushReadingState();
        await save(text, page);
      }
    } catch (error) {
      _notice('Could not extract the selected text: $error');
    } finally {
      _savingSelection = false;
    }
  }

  Future<void> _extractToCanvas(
    PdfViewerContextMenuBuilderParams params,
  ) async {
    final save = widget.onExtractToCanvas;
    if (_savingSelection || widget.readOnly || save == null) return;
    final fileId = widget.objectId, checksum = widget.checksum;
    _savingSelection = true;
    try {
      final ranges = await params.textSelectionDelegate.getSelectedTextRanges();
      if (!mounted ||
          widget.readOnly ||
          ranges.isEmpty ||
          widget.objectId != fileId ||
          widget.checksum != checksum) {
        return;
      }
      final text = ranges.map((r) => r.text).join('\n');
      final page = ranges.first.pageNumber;
      params.dismissContextMenu();
      final saved = await save(text, page);
      if (mounted && widget.objectId == fileId && widget.checksum == checksum) {
        if (saved) {
          await params.textSelectionDelegate.clearTextSelection();
        } else {
          _notice(
            'Could not save this quote to Canvas. Your selection is retained; check the save status and retry.',
          );
        }
      }
    } catch (error) {
      _notice('Could not extract to canvas: $error');
    } finally {
      _savingSelection = false;
    }
  }

  Future<void> _extractToActiveNote(
    PdfViewerContextMenuBuilderParams params,
  ) async {
    final save = widget.onInsertIntoActiveNote;
    if (_savingSelection || widget.readOnly || save == null) return;
    final fileId = widget.objectId, checksum = widget.checksum;
    _savingSelection = true;
    try {
      final ranges = await params.textSelectionDelegate.getSelectedTextRanges();
      if (!mounted ||
          widget.readOnly ||
          ranges.isEmpty ||
          widget.objectId != fileId ||
          widget.checksum != checksum) {
        return;
      }
      final text = ranges.map((r) => r.text).join('\n');
      final page = ranges.first.pageNumber;
      params.dismissContextMenu();
      final saved = await save(text, page);
      if (mounted && widget.objectId == fileId && widget.checksum == checksum) {
        if (saved) {
          await params.textSelectionDelegate.clearTextSelection();
        } else {
          _notice(
            'Could not save this quote to the note. Your selection is retained; check the save status and retry.',
          );
        }
      }
    } catch (error) {
      _notice('Could not insert into active note: $error');
    } finally {
      _savingSelection = false;
    }
  }

  void _populateContextMenuItems(
    PdfViewerContextMenuBuilderParams params,
    List<ContextMenuButtonItem> items,
  ) {
    if (params.textSelectionDelegate.isCopyAllowed &&
        params.textSelectionDelegate.hasSelectedText) {
      items.add(
        ContextMenuButtonItem(
          label: 'Copy quote with source',
          onPressed: () => _quote(params, copy: true),
        ),
      );
      if (!widget.readOnly) {
        if (widget.onExtractToCanvas != null) {
          items.add(
            ContextMenuButtonItem(
              label: 'Extract to Canvas',
              onPressed: () => _extractToCanvas(params),
            ),
          );
        }
        if (widget.onInsertIntoActiveNote != null &&
            widget.hasActiveNoteBeside) {
          items.add(
            ContextMenuButtonItem(
              label: 'Insert into active note',
              onPressed: () => _extractToActiveNote(params),
            ),
          );
        }
        items.add(
          ContextMenuButtonItem(
            label: 'Extract to new note',
            onPressed: () => _quote(params, copy: false),
          ),
        );
        if (widget.onHighlight != null) {
          items.add(
            ContextMenuButtonItem(
              label: 'Highlight',
              onPressed: () => _highlight(
                params,
                comment: false,
                color: _activeColor,
                style: 'highlight',
              ),
            ),
          );
          items.add(
            ContextMenuButtonItem(
              label: 'Underline',
              onPressed: () => _highlight(
                params,
                comment: false,
                color: _activeColor,
                style: 'underline',
              ),
            ),
          );
          items.add(
            ContextMenuButtonItem(
              label: 'Strikeout',
              onPressed: () => _highlight(
                params,
                comment: false,
                color: _activeColor,
                style: 'strikeout',
              ),
            ),
          );
          items.add(
            ContextMenuButtonItem(
              label: 'Highlight and comment',
              onPressed: () => _highlight(
                params,
                comment: true,
                color: _activeColor,
                style: 'highlight',
              ),
            ),
          );
        }
      }
    }
  }

  Widget? _buildPdfContextMenu(
    BuildContext context,
    PdfViewerContextMenuBuilderParams params,
  ) {
    if (!params.isTextSelectionEnabled ||
        !params.textSelectionDelegate.hasSelectedText) {
      return null;
    }

    final items = <ContextMenuButtonItem>[
      if (params.textSelectionDelegate.isCopyAllowed)
        ContextMenuButtonItem(
          onPressed: () => params.textSelectionDelegate.copyTextSelection(),
          type: ContextMenuButtonType.copy,
        ),
      if (!params.textSelectionDelegate.isSelectingAllText)
        ContextMenuButtonItem(
          onPressed: () => params.textSelectionDelegate.selectAllText(),
          type: ContextMenuButtonType.selectAll,
        ),
    ];

    _populateContextMenuItems(params, items);

    if (items.isEmpty) {
      return null;
    }

    return Align(
      alignment: Alignment.topLeft,
      child: AdaptiveTextSelectionToolbar(
        anchors: TextSelectionToolbarAnchors(
          primaryAnchor: params.anchorA,
          secondaryAnchor: params.anchorB,
        ),
        children: [
          _PdfDraggableQuoteHandle(
            params: params,
            objectId: widget.objectId,
            title: widget.title,
            checksum: widget.checksum,
          ),
          ...AdaptiveTextSelectionToolbar.getAdaptiveButtons(context, items),
        ],
      ),
    );
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
    int? color,
    String style = 'highlight',
  }) async {
    final save = widget.onHighlight;
    if (save == null || widget.readOnly || _savingSelection) return;
    final fileId = widget.objectId, checksum = widget.checksum;
    final document = _viewer.document;
    bool current() =>
        mounted &&
        !widget.readOnly &&
        widget.objectId == fileId &&
        widget.checksum == checksum &&
        _viewer.isReady &&
        identical(_viewer.document, document);
    _savingSelection = true;
    try {
      final ranges = await params.textSelectionDelegate.getSelectedTextRanges();
      if (!current() || ranges.isEmpty) return;
      final quote = ranges.map((r) => r.text).join('\n');
      final highlightColor = color ?? _activeColor;
      final regions = pdfSelectionRegions(
        ranges,
        _viewer.document.pages,
        color: highlightColor,
        style: style,
      );
      params.dismissContextMenu();
      bool saved;
      if (comment) {
        if (!mounted) return;
        saved =
            await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) => PdfPassageCommentDialog(
                onSave: (text) async =>
                    current() && await save(quote, regions, text),
              ),
            ) ??
            false;
        if (!saved) return; // Cancel is not a persistence failure.
      } else {
        _pendingMarkup.clear();
        for (final region in regions) {
          (_pendingMarkup[region.data['page'] as int] ??= []).add(region);
        }
        _viewer.invalidate();
        saved = current() && await save(quote, regions, '');
      }
      if (!current()) return;
      if (saved) {
        await params.textSelectionDelegate.clearTextSelection();
        if (!current()) return;
        if (comment) setState(() => _showAnnotations = true);
      }
      _notice(
        saved
            ? 'Highlight saved. Click it to edit or delete; find all marks in Highlights and comments.'
            : 'Highlight could not be saved. The original PDF is unchanged.',
      );
    } catch (_) {
      if (current()) {
        _notice(
          'Could not save this selection. The original PDF is unchanged; retry from the selected text.',
        );
      }
    } finally {
      _savingSelection = false;
      _pendingMarkup.clear();
      if (mounted && _viewer.isReady) _viewer.invalidate();
    }
  }

  void _paintAnnotations(Canvas canvas, Rect pageRect, PdfPage page) {
    if (!_showMarkup) return;
    for (final entry in _annotationIndex.markupForPage(page.pageNumber)) {
      final annotation = entry.annotation;
      final isActive = _activeHighlightId == annotation.object.id;
      final style = annotation.style;
      final color = Color(annotation.color);

      _paintMarkupRegion(
        canvas,
        pageRect,
        entry.region,
        color,
        style,
        isActive,
      );
    }
    for (final region
        in _pendingMarkup[page.pageNumber] ?? const <CanvasElement>[]) {
      _paintMarkupRegion(
        canvas,
        pageRect,
        region,
        Color(region.color),
        region.data['style'] as String? ?? 'highlight',
        false,
      );
    }
  }

  void _paintMarkupRegion(
    Canvas canvas,
    Rect pageRect,
    CanvasElement region,
    Color color,
    String style,
    bool isActive,
  ) {
    final rect = Rect.fromLTWH(
      pageRect.left + region.x * pageRect.width,
      pageRect.top + region.y * pageRect.height,
      region.width * pageRect.width,
      region.height * pageRect.height,
    );

    if (style == 'underline') {
      canvas.drawLine(
        Offset(rect.left, rect.bottom - 1),
        Offset(rect.right, rect.bottom - 1),
        Paint()
          ..color = color.withAlpha(220)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    } else if (style == 'strikeout') {
      canvas.drawLine(
        Offset(rect.left, rect.center.dy),
        Offset(rect.right, rect.center.dy),
        Paint()
          ..color = color.withAlpha(220)
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round,
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()..color = color.withAlpha(75),
      );
    }

    if (isActive) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(3), const Radius.circular(4)),
        Paint()
          ..color = OrbitColors.of(context).accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  List<Widget> _buildAnnotationOverlays(
    BuildContext context,
    Rect pageRect,
    PdfPage page,
  ) {
    final overlays = <Widget>[];
    if (!_showMarkup) return overlays;
    for (final annotation in _annotationIndex.commentsForPage(
      page.pageNumber,
    )) {
      // Text markup is paint-only so it cannot consume selection drags. Its
      // editable note remains accessible from the review/connected-notes panel.
      final bounds = annotation.boundsForPage(page.pageNumber);
      if (bounds == null) continue;

      final left = bounds.left * pageRect.width;
      final top = bounds.top * pageRect.height;
      final width = bounds.width * pageRect.width;
      final height = bounds.height * pageRect.height;

      overlays.add(
        Positioned(
          left: left,
          top: top,
          width: math.max(width, 24),
          height: math.max(height, 16),
          child: Tooltip(
            message: annotation.source['quote'] is String
                ? '${annotation.source['quote']}'
                : annotation.object.title,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                hoverColor: Color(annotation.color).withAlpha(35),
                onTap: () => _showHighlightDetail(annotation),
                child: annotation.isPageComment
                    ? Icon(
                        Icons.sticky_note_2,
                        color: Color(annotation.color),
                        size: 24,
                      )
                    : null,
              ),
            ),
          ),
        ),
      );
    }
    return overlays;
  }

  Future<void> _showAnnotationMenu(
    PdfAnnotation annotation,
    Offset position,
  ) async {
    final epoch = _documentEpoch, checksum = widget.checksum;
    final global = _viewer.documentToGlobal(position);
    if (global == null) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final point = overlay.globalToLocal(global);
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromSize(
        Rect.fromLTWH(point.dx, point.dy, 1, 1),
        overlay.size,
      ),
      items: [
        const PopupMenuItem(value: 'details', child: Text('Highlight details')),
        if (!widget.readOnly &&
            !annotation.object.isReadOnly &&
            widget.onUpdateReview != null)
          const PopupMenuItem(
            value: 'edit',
            child: Text('Edit color, style and comment'),
          ),
        if (annotation.quote.isNotEmpty)
          const PopupMenuItem(value: 'copy', child: Text('Copy quote')),
        if (!widget.readOnly &&
            !annotation.object.isReadOnly &&
            widget.onDeleteReview != null)
          const PopupMenuItem(value: 'delete', child: Text('Delete highlight')),
      ],
    );
    if (!mounted ||
        epoch != _documentEpoch ||
        checksum != widget.checksum ||
        !widget.annotations.any(
          (a) => identical(a.object, annotation.object),
        )) {
      return;
    }
    switch (choice) {
      case 'details':
        _showHighlightDetail(annotation);
      case 'edit':
        _editReview(annotation);
      case 'delete':
        await _deleteReview(annotation);
      case 'copy':
        try {
          await Clipboard.setData(ClipboardData(text: annotation.quote));
        } catch (_) {
          if (mounted) _notice('Clipboard unavailable. Review unchanged.');
        }
    }
  }

  bool _tapMarkup(
    BuildContext context,
    PdfViewerController controller,
    PdfViewerGeneralTapHandlerDetails details,
  ) {
    if (!_showMarkup ||
        _forms ||
        !{
          PdfViewerGeneralTapType.tap,
          PdfViewerGeneralTapType.secondaryTap,
        }.contains(details.type) ||
        controller.textSelectionDelegate.hasSelectedText) {
      return false;
    }
    final layouts = controller.layout.pageLayouts;
    for (var i = 0; i < layouts.length; i++) {
      final rect = layouts[i];
      if (!rect.contains(details.documentPosition)) continue;
      final annotation = _annotationIndex.hitTest(
        i + 1,
        (details.documentPosition.dx - rect.left) / rect.width,
        (details.documentPosition.dy - rect.top) / rect.height,
      );
      if (annotation != null) {
        if (details.type == PdfViewerGeneralTapType.secondaryTap) {
          _showAnnotationMenu(annotation, details.documentPosition);
        } else {
          _showHighlightDetail(annotation);
        }
        return true;
      }
      break;
    }
    if (_zenMode && details.type == PdfViewerGeneralTapType.tap) {
      setState(() => _zenControlsVisible = !_zenControlsVisible);
      return true;
    }
    return false;
  }

  Widget _annotationPanel({bool expanded = false}) => PdfReviewPanel(
    key: _reviewPanelKey,
    expanded: expanded,
    onExpand: () => setState(() {
      _reviewExpanded = !_reviewExpanded;
      _showNotes = false;
    }),
    onBatch: widget.readOnly ? null : widget.onReviewBatch,
    onUndoBatch: widget.readOnly ? null : widget.onUndoReviewBatch,
    colors: pdfHighlightColors,
    annotations: widget.annotations,
    page: _page,
    checksum: widget.checksum,
    onNavigate: _goToAnnotation,
    onClose: () => setState(() {
      _showAnnotations = false;
      _reviewExpanded = false;
    }),
    onCopy: _copyReview,
    onExport: widget.onExportReview == null ? null : _exportReview,
    onAnnotatedCopy:
        widget.readOnly ||
            !_ready ||
            _savingAnnotations ||
            widget.onSaveAnnotatedCopy == null
        ? null
        : _saveAnnotatedCopy,
    savingAnnotatedCopy: _savingAnnotations,
    onOpen: widget.onOpenAnnotation == null
        ? null
        : (id) => _openNote(id, annotation: true),
    onOpenSource: widget.onOpenOriginal,
    onEdit: widget.readOnly || widget.onUpdateReview == null
        ? null
        : _editReview,
    onDelete: widget.readOnly || widget.onDeleteReview == null
        ? null
        : _deleteReview,
    deletingIds: Set.of(_deletingReviewIds),
    onSummary: widget.readOnly ? null : widget.onReviewSummary,
    onBoard: widget.readOnly ? null : widget.onReviewBoard,
  );

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
              OutlinedButton(onPressed: _retry, child: const Text('Retry')),
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
      const SingleActivator(LogicalKeyboardKey.digit0, control: true): () =>
          _readingTool('page'),
      const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
          _readingTool('1'),
      const SingleActivator(LogicalKeyboardKey.digit2, control: true): () =>
          _readingTool('width'),
      const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): () =>
          _go(_page + 1),
      const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () =>
          _go(_page - 1),
      const SingleActivator(LogicalKeyboardKey.f3): () =>
          _search?.goToNextMatch(),
      const SingleActivator(LogicalKeyboardKey.f3, shift: true): () =>
          _search?.goToPrevMatch(),
      const SingleActivator(
        LogicalKeyboardKey.keyZ,
        control: true,
        shift: true,
      ): () =>
          setState(() => _zenMode = !_zenMode),
      const SingleActivator(LogicalKeyboardKey.escape): () {
        if (_zenMode) setState(() => _zenMode = false);
      },
    },
    child: Focus(
      focusNode: _readerFocus,
      child: Column(
        children: [
          if (!_zenMode)
            OrbitWorkbenchToolbar(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Scrollbar(
                  controller: _toolbarScroll,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _toolbarScroll,
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
                            tooltip: 'Page thumbnails',
                            isSelected: _thumbnails,
                            onPressed: _ready
                                ? () {
                                    setState(() => _thumbnails = !_thumbnails);
                                    if (_thumbnails) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            if (!mounted || !_thumbnails) {
                                              return;
                                            }
                                            _thumbnailFocus.requestFocus();
                                            _revealThumbnail();
                                          });
                                    } else {
                                      _readerFocus.requestFocus();
                                    }
                                  }
                                : null,
                            icon: const Icon(Icons.view_sidebar_outlined),
                          ),
                          IconButton(
                            tooltip: 'PDF outline',
                            onPressed: _ready && !_outlineLoading
                                ? _showOutline
                                : null,
                            icon: const Icon(Icons.format_list_bulleted),
                          ),
                          const OrbitToolbarDivider(),
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
                                ? () {
                                    setState(() {
                                      _comfort = false;
                                      _textOnly = false;
                                    });
                                    _fitGeneration++;
                                    _viewer.zoomDown(duration: Duration.zero);
                                  }
                                : null,
                            icon: const Icon(Icons.remove),
                          ),
                          IconButton(
                            tooltip: 'Fit page width',
                            onPressed: _ready
                                ? () => _readingTool('width')
                                : null,
                            icon: const Icon(Icons.fit_screen),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'PDF zoom and reading tools',
                            enabled: _ready,
                            onSelected: _readingTool,
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'content',
                                child: Text('Fit content · images and tables'),
                              ),
                              PopupMenuItem(
                                value: 'page',
                                child: Text('Fit entire page · Ctrl+0'),
                              ),
                              PopupMenuItem(
                                value: 'width',
                                child: Text('Fit page width · Ctrl+2'),
                              ),
                              PopupMenuDivider(),
                              PopupMenuItem(value: '0.5', child: Text('50%')),
                              PopupMenuItem(value: '0.75', child: Text('75%')),
                              PopupMenuItem(
                                value: '1',
                                child: Text('100% · Ctrl+1'),
                              ),
                              PopupMenuItem(value: '1.5', child: Text('150%')),
                              PopupMenuItem(value: '2', child: Text('200%')),
                              PopupMenuItem(value: '4', child: Text('400%')),
                              PopupMenuItem(
                                value: 'custom',
                                child: Text('Custom zoom…'),
                              ),
                            ],
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              child: Text('$_zoomPercent%'),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Zoom in',
                            onPressed: _ready
                                ? () {
                                    setState(() {
                                      _comfort = false;
                                      _textOnly = false;
                                    });
                                    _fitGeneration++;
                                    _viewer.zoomUp(duration: Duration.zero);
                                  }
                                : null,
                            icon: const Icon(Icons.add),
                          ),
                          IconButton(
                            tooltip: 'Find in PDF · Ctrl+F',
                            onPressed: _ready ? _find : null,
                            icon: const Icon(Icons.search),
                          ),
                          const OrbitToolbarDivider(),
                          PopupMenuButton<PdfPageMode>(
                            tooltip: 'Page display mode',
                            initialValue: _pageMode,
                            icon: Icon(switch (_pageMode) {
                              PdfPageMode.continuous => Icons.view_day_outlined,
                              PdfPageMode.single =>
                                Icons.crop_portrait_outlined,
                              PdfPageMode.twoPage => Icons.menu_book_outlined,
                            }),
                            onSelected: _setPageMode,
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: PdfPageMode.continuous,
                                child: Text('Continuous vertical scroll'),
                              ),
                              PopupMenuItem(
                                value: PdfPageMode.single,
                                child: Text('Single page (horizontal flow)'),
                              ),
                              PopupMenuItem(
                                value: PdfPageMode.twoPage,
                                child: Text('Two-page spread (facing pages)'),
                              ),
                            ],
                          ),
                          IconButton(
                            tooltip: _comfort
                                ? 'Original page'
                                : 'Comfort reading',
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
                                    (_viewer
                                            .document
                                            .permissions
                                            ?.allowsCopying ??
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
                          if (widget.onPageComment != null)
                            IconButton(
                              tooltip: 'Add page comment',
                              onPressed: _ready && !widget.readOnly
                                  ? _addPageComment
                                  : null,
                              icon: const Icon(Icons.add_comment_outlined),
                            ),
                          IconButton(
                            tooltip: _showMarkup
                                ? 'Hide review markup'
                                : 'Show review markup',
                            onPressed: _ready
                                ? () {
                                    setState(() => _showMarkup = !_showMarkup);
                                    _viewer.invalidate();
                                  }
                                : null,
                            icon: Icon(
                              _showMarkup
                                  ? Icons.layers_outlined
                                  : Icons.layers_clear_outlined,
                            ),
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
                              label: _savingCopy
                                  ? 'Saving…'
                                  : 'Save filled copy',
                              onPressed:
                                  _savingCopy ||
                                      widget.formValues.isEmpty ||
                                      widget.readOnly
                                  ? null
                                  : _saveFilledCopy,
                            ),
                          const OrbitToolbarDivider(),
                          IconButton(
                            tooltip: 'Copy page reference',
                            onPressed: _ready ? _copyReference : null,
                            icon: const Icon(Icons.link),
                          ),
                          if (widget.onCreateDocument != null)
                            PopupMenuButton<ResearchDocument>(
                              tooltip: 'Create document from PDF',
                              enabled:
                                  _ready &&
                                  !widget.readOnly &&
                                  !_creatingDocument,
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
                            onPressed: () => setState(() {
                              _showAnnotations = !_showAnnotations;
                              if (_showAnnotations) _showNotes = false;
                            }),
                            icon: const Icon(Icons.edit_note_rounded),
                          ),
                          if (widget.onOpenLinkedNote != null)
                            IconButton(
                              tooltip: 'Connected notes',
                              isSelected: _showNotes,
                              onPressed: () => setState(() {
                                _showNotes = !_showNotes;
                                if (_showNotes) _showAnnotations = false;
                                if (_showNotes) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted && _showNotes) {
                                      _notesSearchFocus.requestFocus();
                                    }
                                  });
                                } else {
                                  _readerFocus.requestFocus();
                                }
                              }),
                              icon: const Icon(Icons.description_outlined),
                            ),
                          PopupMenuButton<int>(
                            tooltip: 'Highlight color',
                            icon: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Color(_activeColor),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: OrbitColors.of(context).border,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            onSelected: (color) =>
                                setState(() => _activeColor = color),
                            itemBuilder: (_) => [
                              for (final entry in pdfHighlightColors.entries)
                                PopupMenuItem(
                                  value: entry.value,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: Color(entry.value),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(entry.key),
                                      if (_activeColor == entry.value) ...[
                                        const Spacer(),
                                        Icon(
                                          Icons.check,
                                          size: 16,
                                          color: OrbitColors.of(context).accent,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                            ],
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
                          IconButton(
                            key: const ValueKey('pdf-favorite-button'),
                            tooltip: _isFavorite
                                ? 'Remove from favorites'
                                : 'Mark as favorite',
                            isSelected: _isFavorite,
                            onPressed: _toggleFavorite,
                            icon: Icon(
                              _isFavorite ? Icons.star : Icons.star_border,
                              color: _isFavorite ? Colors.amber : null,
                            ),
                          ),
                          IconButton(
                            key: const ValueKey('pdf-reading-room-button'),
                            tooltip: _activeReadingRoom != null
                                ? 'Virtual room: ${_activeReadingRoom!.name}'
                                : 'Virtual reading rooms & ambience',
                            isSelected: _activeReadingRoom != null,
                            onPressed: _openReadingRoomSheet,
                            icon: Icon(
                              _activeReadingRoom != null
                                  ? Icons.spa
                                  : Icons.spa_outlined,
                              color: _activeReadingRoom != null
                                  ? OrbitColors.of(context).accent
                                  : null,
                            ),
                          ),
                          IconButton(
                            key: const ValueKey('pdf-zen-mode-toggle'),
                            tooltip: 'Zen distraction-free reading',
                            isSelected: _zenMode,
                            onPressed: () =>
                                setState(() => _zenMode = !_zenMode),
                            icon: const Icon(Icons.fullscreen),
                          ),
                          IconButton(
                            tooltip: 'Saved pages',
                            onPressed: _ready ? _showBookmarks : null,
                            icon: const Icon(Icons.bookmarks_outlined),
                          ),
                          IconButton(
                            tooltip: 'Open original externally',
                            onPressed: widget.onOpenOriginal,
                            icon: const Icon(Icons.open_in_new),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Document tools',
                            enabled: _ready,
                            icon: const Icon(Icons.more_horiz),
                            onSelected: (value) {
                              switch (value) {
                                case 'back':
                                  _visitHistory(false);
                                case 'forward':
                                  _visitHistory(true);
                                case 'first':
                                  _go(1);
                                case 'last':
                                  _go(_viewer.pageCount);
                                case 'info':
                                  _documentInfo();
                                case 'ocr':
                                  widget.onRecognizeText?.call();
                                case 'rooms':
                                  _openReadingRoomSheet();
                                case 'memories':
                                  if (widget.onOpenMemories != null) {
                                    widget.onOpenMemories!();
                                  } else {
                                    _showBookmarks();
                                  }
                                case 'zen':
                                  setState(() => _zenMode = !_zenMode);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'back',
                                enabled: _previousPages.isNotEmpty,
                                child: const Text('Previous visited page'),
                              ),
                              PopupMenuItem(
                                value: 'forward',
                                enabled: _nextPages.isNotEmpty,
                                child: const Text('Next visited page'),
                              ),
                              const PopupMenuDivider(),
                              if (widget.onRecognizeText != null)
                                const PopupMenuItem(
                                  value: 'ocr',
                                  child: Text('Recognize and review text…'),
                                ),
                              const PopupMenuItem(
                                value: 'first',
                                child: Text('First page'),
                              ),
                              const PopupMenuItem(
                                value: 'last',
                                child: Text('Last page'),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'rooms',
                                child: Text(
                                  'Virtual reading rooms & ambience…',
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'memories',
                                child: Text('Book memories & notes archive…'),
                              ),
                              const PopupMenuItem(
                                value: 'zen',
                                child: Text('Zen distraction-free reading'),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'info',
                                child: Text('Document information'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if ((_globalSearchRange != null || _globalOcrPage != null) && _ready)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Global search match · Page ${_globalOcrPage ?? _globalSearchRange!.pageNumber}',
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _globalSearchRange = null;
                        _globalOcrPage = null;
                      });
                      _viewer.invalidate();
                    },
                    child: const Text('Clear match'),
                  ),
                ],
              ),
            ),
          if (_finding && _ready)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 4,
                children: [
                  SizedBox(
                    width: double.infinity,
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
                      _query.clear();
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
                final epoch = _viewerEpoch;
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
                          Focus(
                            focusNode: _thumbnailFocus,
                            onKeyEvent: _thumbnailKey,
                            onFocusChange: (_) => setState(() {}),
                            child: Container(
                              width: 130,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _thumbnailFocus.hasFocus
                                      ? OrbitColors.of(context).accent
                                      : Colors.transparent,
                                ),
                              ),
                              child: ListView.builder(
                                controller: _thumbnailScroll,
                                itemExtent: _thumbnailExtent,
                                itemCount: _viewer.pageCount,
                                itemBuilder: (context, index) => Semantics(
                                  label: 'Page ${index + 1}',
                                  selected: index + 1 == _page,
                                  button: true,
                                  child: InkWell(
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
                            ),
                          ),
                        Expanded(
                          child: _buildFilteredViewer(
                            PdfViewer.data(
                              snapshot.data!,
                              key: ValueKey(
                                '${widget.objectId}:${widget.key}:$_documentEpoch:$_viewerEpoch',
                              ),
                              sourceName:
                                  '${widget.objectId}:${widget.key}:${widget.checksum}:$_documentEpoch',
                              controller: _viewer,
                              initialPageNumber: _restorePage,
                              passwordProvider: _password,
                              params: PdfViewerParams(
                                layoutPages: _layoutPages,
                                onGeneralTap: _tapMarkup,
                                sizeDelegateProvider:
                                    const PdfViewerSizeDelegateProviderLegacy(
                                      minScale: .1,
                                      maxScale: 8,
                                      useAlternativeFitScaleAsMinScale: false,
                                    ),
                                onViewSizeChanged: (size, oldSize, controller) {
                                  if (oldSize != null &&
                                      oldSize.width != size.width) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (!mounted ||
                                              !_ready ||
                                              !controller.isReady) {
                                            return;
                                          }
                                          if (_comfort) {
                                            _fitComfort(
                                              keepVerticalPosition: true,
                                            );
                                          } else if (!_textOnly) {
                                            final matrix = controller
                                                .calcMatrixFitWidthForPage(
                                                  pageNumber: _page,
                                                );
                                            if (matrix != null) {
                                              controller.goTo(
                                                matrix,
                                                duration: Duration.zero,
                                              );
                                            }
                                          }
                                        });
                                  }
                                },
                                pageOverlaysBuilder: (context, rect, page) {
                                  if (_forms && widget.onFormChanged != null) {
                                    return [
                                      PdfFormLayer(
                                        key: ValueKey(
                                          'forms:${page.pageNumber}',
                                        ),
                                        document: _viewer.document,
                                        page: page,
                                        values: widget.formValues,
                                        onChanged: widget.onFormChanged!,
                                      ),
                                    ];
                                  }
                                  return _buildAnnotationOverlays(
                                    context,
                                    rect,
                                    page,
                                  );
                                },
                                backgroundColor: OrbitColors.of(context).panel,
                                onViewerReady: (document, controller) async {
                                  if (!mounted || epoch != _viewerEpoch) {
                                    return;
                                  }
                                  setState(() {
                                    _search?.dispose();
                                    _search = PdfTextSearcher(controller)
                                      ..addListener(_refresh);
                                    _ready = true;
                                    if (!_loadedOnce &&
                                        _restoreZoom == null &&
                                        controller.viewSize.width < 600) {
                                      _comfort = true;
                                    }
                                    _loadedOnce = true;
                                    _page =
                                        (controller.pageNumber ?? _restorePage)
                                            .clamp(1, controller.pageCount);
                                    _pageInput.text = '$_page';
                                  });
                                  if (_comfort) {
                                    await _fitComfort();
                                  }
                                  if (!mounted ||
                                      epoch != _viewerEpoch ||
                                      !controller.isReady) {
                                    return;
                                  }
                                  final zoom = _comfort ? null : _restoreZoom;
                                  if (zoom != null && zoom.isFinite) {
                                    await controller.setZoom(
                                      controller.centerPosition,
                                      zoom.clamp(
                                        controller.minScale,
                                        controller.maxScale,
                                      ),
                                      duration: Duration.zero,
                                    );
                                  } else if (!_comfort && !_textOnly) {
                                    final matrix = controller
                                        .calcMatrixFitWidthForPage(
                                          pageNumber: _page,
                                        );
                                    if (matrix != null) {
                                      await controller.goTo(
                                        matrix,
                                        duration: Duration.zero,
                                      );
                                    }
                                  }
                                  if (!mounted ||
                                      epoch != _viewerEpoch ||
                                      !controller.isReady) {
                                    return;
                                  }
                                  if (_query.text.isNotEmpty) {
                                    _search?.startTextSearch(_query.text);
                                  }
                                  if (_sourceNavigationPending &&
                                      (widget.initialAnnotationId != null ||
                                          widget.initialSearchChecksum !=
                                              null)) {
                                    await _navigateRequestedSource();
                                  }
                                  _sourceNavigationPending = false;
                                  if (!mounted || epoch != _viewerEpoch) {
                                    return;
                                  }
                                  _positionChanged();
                                  try {
                                    final outline = await document
                                        .loadOutline();
                                    if (mounted && epoch == _viewerEpoch) {
                                      setState(() {
                                        _outline = outline;
                                        _outlineLoading = false;
                                      });
                                    }
                                  } catch (_) {
                                    if (mounted && epoch == _viewerEpoch) {
                                      setState(() {
                                        _outlineFailed = true;
                                        _outlineLoading = false;
                                      });
                                    }
                                  }
                                },
                                onPageChanged: (page) {
                                  if (mounted &&
                                      epoch == _viewerEpoch &&
                                      page != null) {
                                    final changed = _page != page;
                                    if (changed) {
                                      setState(() {
                                        _page = page;
                                        _pageInput.text = '$page';
                                      });
                                    }
                                    _positionChanged();
                                    if (changed) _fitComfort();
                                  }
                                },
                                errorBannerBuilder: (_, error, _, _) => _fallback(
                                  'This PDF could not be opened. Its original bytes are unchanged.',
                                ),
                                pagePaintCallbacks: [
                                  (canvas, pageRect, page) {
                                    if (_globalOcrPage == page.pageNumber) {
                                      for (final region
                                          in widget.initialSearchRegions) {
                                        canvas.drawRect(
                                          Rect.fromLTWH(
                                            pageRect.left +
                                                region['x']! * pageRect.width,
                                            pageRect.top +
                                                region['y']! * pageRect.height,
                                            region['width']! * pageRect.width,
                                            region['height']! * pageRect.height,
                                          ),
                                          Paint()
                                            ..color = OrbitColors.of(
                                              context,
                                            ).accent.withValues(alpha: .3),
                                        );
                                      }
                                    }
                                    final range = _globalSearchRange;
                                    if (range == null ||
                                        range.pageNumber != page.pageNumber) {
                                      return;
                                    }
                                    for (final fragment
                                        in range
                                            .enumerateFragmentBoundingRects()) {
                                      final rect = fragment.bounds
                                          .toRect(
                                            page: page,
                                            scaledPageSize: pageRect.size,
                                          )
                                          .translate(
                                            pageRect.left,
                                            pageRect.top,
                                          );
                                      canvas.drawRect(
                                        rect,
                                        Paint()
                                          ..color = OrbitColors.of(
                                            context,
                                          ).accent.withValues(alpha: .3),
                                      );
                                    }
                                  },
                                  _paintAnnotations,
                                  if (_search != null)
                                    _search!.pageTextMatchPaintCallback,
                                ],
                                linkHandlerParams: PdfLinkHandlerParams(
                                  onLinkTap: (link) {
                                    if (link.dest != null) _rememberPageJump();
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
                                buildContextMenu: _buildPdfContextMenu,
                                customizeContextMenuItems: (params, items) =>
                                    _populateContextMenuItems(params, items),
                              ),
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
                    if (_zenMode && _zenControlsVisible)
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Material(
                            elevation: 0,
                            color: Colors.transparent,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: OrbitColors.of(context).panel,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: OrbitColors.of(context).border,
                                ),
                                boxShadow: OrbitDepth.floating,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Page $_page of ${_ready ? _viewer.pageCount : '—'} (${_ready ? ((_page / math.max(1, _viewer.pageCount)) * 100).toInt() : 0}%)',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  if (_sessionSecondsRemaining != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: OrbitColors.of(
                                          context,
                                        ).accent.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.timer_outlined,
                                            size: 12,
                                            color: OrbitColors.of(
                                              context,
                                            ).accent,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${(_sessionSecondsRemaining! ~/ 60).toString().padLeft(2, '0')}:${(_sessionSecondsRemaining! % 60).toString().padLeft(2, '0')}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: OrbitColors.of(
                                                context,
                                              ).accent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 10),
                                  Container(
                                    width: 1,
                                    height: 16,
                                    color: OrbitColors.of(context).border,
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    key: const ValueKey('zen-prev-page'),
                                    icon: const Icon(
                                      Icons.chevron_left,
                                      size: 20,
                                    ),
                                    tooltip: 'Previous page',
                                    onPressed: _page > 1
                                        ? () => _go(_page - 1)
                                        : null,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                  ),
                                  IconButton(
                                    key: const ValueKey('zen-next-page'),
                                    icon: const Icon(
                                      Icons.chevron_right,
                                      size: 20,
                                    ),
                                    tooltip: 'Next page',
                                    onPressed:
                                        _ready && _page < _viewer.pageCount
                                        ? () => _go(_page + 1)
                                        : null,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    key: const ValueKey('zen-bookmark-toggle'),
                                    icon: Icon(
                                      widget.bookmarks.contains(_page)
                                          ? Icons.bookmark
                                          : Icons.bookmark_border,
                                      size: 18,
                                      color: widget.bookmarks.contains(_page)
                                          ? OrbitColors.of(context).accent
                                          : null,
                                    ),
                                    tooltip: widget.bookmarks.contains(_page)
                                        ? 'Remove bookmark'
                                        : 'Bookmark page',
                                    onPressed: !_ready || widget.readOnly
                                        ? null
                                        : () {
                                            final pages = widget.bookmarks
                                                .toSet();
                                            if (!pages.remove(_page)) {
                                              pages.add(_page);
                                            }
                                            widget.onBookmarks(
                                              pages.toList()..sort(),
                                            );
                                          },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                  ),
                                  IconButton(
                                    key: const ValueKey('zen-ambience-button'),
                                    icon: Icon(
                                      _activeReadingRoom != null
                                          ? Icons.spa
                                          : Icons.spa_outlined,
                                      size: 18,
                                      color: _activeReadingRoom != null
                                          ? OrbitColors.of(context).accent
                                          : null,
                                    ),
                                    tooltip: 'Reading room ambience',
                                    onPressed: _openReadingRoomSheet,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                  ),
                                  IconButton(
                                    key: const ValueKey('zen-exit-button'),
                                    icon: const Icon(
                                      Icons.fullscreen_exit,
                                      size: 20,
                                    ),
                                    tooltip:
                                        'Exit Zen mode (show all controls)',
                                    onPressed: () =>
                                        setState(() => _zenMode = false),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_reviewExpanded && _showAnnotations)
                      Positioned.fill(child: _annotationPanel(expanded: true)),
                  ],
                );
              },
            ),
          ),
          if (!_reviewExpanded)
            OrbitDisclosure(
              visible: _showAnnotations,
              child: _annotationPanel(),
            ),
          if (widget.onOpenLinkedNote != null)
            OrbitDisclosure(
              visible: _showNotes,
              child: PdfNotesPanel(
                searchFocusNode: _notesSearchFocus,
                notes: widget.linkedNotes,
                fileId: widget.objectId,
                checksum: widget.checksum,
                onOpen: (id) => _openNote(id),
                onDelete: widget.readOnly ? null : widget.onDeleteLinkedNote,
                onRestore: widget.readOnly ? null : widget.onRestoreLinkedNote,
                onClose: () {
                  setState(() => _showNotes = false);
                  _readerFocus.requestFocus();
                },
                onCreate:
                    !_ready ||
                        widget.readOnly ||
                        _creatingDocument ||
                        widget.onCreateDocument == null
                    ? null
                    : () => _createDocument(ResearchDocument.research),
              ),
            ),
        ],
      ),
    ),
  );
}

class _PdfDraggableQuoteHandle extends StatefulWidget {
  const _PdfDraggableQuoteHandle({
    required this.params,
    required this.objectId,
    required this.title,
    this.checksum,
  });

  final PdfViewerContextMenuBuilderParams params;
  final String objectId;
  final String title;
  final String? checksum;

  @override
  State<_PdfDraggableQuoteHandle> createState() =>
      _PdfDraggableQuoteHandleState();
}

class _PdfDraggableQuoteHandleState extends State<_PdfDraggableQuoteHandle> {
  PdfQuoteDragData? _quoteData;

  @override
  void initState() {
    super.initState();
    _loadQuote();
  }

  Future<void> _loadQuote() async {
    try {
      final ranges = await widget.params.textSelectionDelegate
          .getSelectedTextRanges();
      if (!mounted || ranges.isEmpty) return;
      final text = ranges.map((r) => r.text).join('\n');
      final page = ranges.first.pageNumber;
      setState(() {
        _quoteData = PdfQuoteDragData(
          objectId: widget.objectId,
          title: widget.title,
          page: page,
          text: text,
          checksum: widget.checksum,
        );
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final data = _quoteData;
    if (data == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: colors.raised,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Tooltip(
        message: 'Drag into a note or canvas',
        child: Draggable<PdfQuoteDragData>(
          data: data,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          onDragCompleted: () {
            widget.params.dismissContextMenu();
          },
          feedback: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(8),
            color: colors.panel,
            child: Container(
              padding: const EdgeInsets.all(10),
              constraints: const BoxConstraints(maxWidth: 260),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.accent, width: 1.5),
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
                        color: colors.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.title} (p. ${data.page})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: colors.text),
                  ),
                ],
              ),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.drag_indicator, size: 14, color: colors.accent),
                const SizedBox(width: 4),
                Text(
                  'Drag quote',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
