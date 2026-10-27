import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/orbit_theme.dart';
import '../../app/orbit_components.dart';
import '../../app/workspace_controller.dart';
import '../../domain/object_discovery.dart';
import '../../domain/orbit_search.dart';
import '../../domain/search_workspace.dart';
import 'workspace_views.dart' show objectIcon;
import '../notes/ocr_review_dialog.dart';

// One bounded return point per controller; never retain a different Vault's data.
final _searchReturns = Expando<_SearchReturn>();

class _SearchReturn {
  _SearchReturn(
    this.generation,
    this.project,
    this.query,
    this.options,
    this.results,
    this.page,
    this.selected,
    this.scroll,
    this.preview,
  );
  final int generation, page, selected;
  final String? project;
  final String query;
  final SearchOptions options;
  final List<OrbitSearchResult> results;
  final double scroll;
  final bool preview;
}

class SearchView extends StatefulWidget {
  const SearchView({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final _query = TextEditingController();
  final _queryFocus = FocusNode();
  final _scroll = ScrollController();
  final _selectionReveal = OrbitListSelectionReveal();
  List<OrbitSearchResult> _results = [];
  OrbitSearchResult? _refreshSelection;
  SearchOptions _options = const SearchOptions();
  Timer? _debounce;
  int _generation = 0, _selected = 0;
  int _page = 0, _pdfRevision = 0;
  String? _projectScope;
  late int _ownerGeneration;
  static const _pageSize = 50;
  StreamSubscription<void>? _indexSubscription;
  Timer? _indexRefresh;
  List<OrbitSearchResult>? _filterSource;
  SearchOptions? _filterOptions;
  int _filterRevision = -1;
  List<OrbitSearchResult> _filterCache = [];
  bool _loading = false, _filters = false, _preview = false;
  String? _error;
  SearchLibrary get _library =>
      SearchLibrary(widget.controller.session.searchWorkspace);
  List<OrbitSearchResult> get _filtered {
    final revision = widget.controller.pdfIndexRevision;
    if (!identical(_filterSource, _results) ||
        !identical(_filterOptions, _options) ||
        _filterRevision != revision) {
      _filterSource = _results;
      _filterOptions = _options;
      _filterRevision = revision;
      _filterCache = _options.apply(
        _results.where(widget.controller.isCurrentSearchResult).toList(),
      );
    }
    return _filterCache;
  }

  List<OrbitSearchResult> get _shown =>
      _filtered.skip(_page * _pageSize).take(_pageSize).toList();

  OrbitSearchResult? _selectionIn(List<OrbitSearchResult> results) {
    final index = _page * _pageSize + _selected;
    return index < results.length ? results[index] : null;
  }

  void _retainSelection(OrbitSearchResult? previous) {
    final filtered = _filtered;
    var index = previous == null
        ? -1
        : filtered.indexWhere(
            (r) =>
                r.object.id == previous.object.id &&
                r.matchKind == previous.matchKind &&
                r.location.page == previous.location.page &&
                r.location.anchorType == previous.location.anchorType &&
                r.location.anchorId == previous.location.anchorId &&
                r.sourceOffset == previous.sourceOffset &&
                r.sourceChecksum == previous.sourceChecksum,
          );
    if (index < 0 && previous != null) {
      var distance = 1 << 62;
      for (var i = 0; i < filtered.length; i++) {
        final r = filtered[i];
        if (r.object.id != previous.object.id ||
            r.matchKind != previous.matchKind ||
            r.location.page != previous.location.page ||
            r.location.anchorType != previous.location.anchorType ||
            r.location.anchorId != previous.location.anchorId) {
          continue;
        }
        final difference =
            ((r.sourceOffset ?? 0) - (previous.sourceOffset ?? 0)).abs();
        if (difference < distance) {
          distance = difference;
          index = i;
        }
      }
    }
    if (index >= 0) {
      _page = index ~/ _pageSize;
      _selected = index % _pageSize;
    } else {
      _page = _page.clamp(
        0,
        (filtered.length - 1).clamp(0, filtered.length) ~/ _pageSize,
      );
      _selected = 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _ownerGeneration = widget.controller.workspaceGeneration;
    _projectScope = widget.controller.selectedProjectId;
    _listenIndex();
    final saved = _searchReturns[widget.controller];
    if (saved != null &&
        saved.generation == widget.controller.workspaceGeneration &&
        saved.project == _projectScope) {
      _query.text = saved.query;
      _options = saved.options;
      _filters = _options.hasFilters;
      _results = saved.results;
      _page = saved.page;
      _selected = saved.selected;
      _preview = saved.preview;
      _retainSelection(_selectionIn(_results));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.jumpTo(
            saved.scroll.clamp(0, _scroll.position.maxScrollExtent),
          );
        }
      });
      // Keep the visible return point while refreshing changed sources.
      _search(saved.query, refresh: true);
    }
  }

  void _rememberReturn() {
    if (_ownerGeneration != widget.controller.workspaceGeneration) return;
    _searchReturns[widget.controller] = _SearchReturn(
      widget.controller.workspaceGeneration,
      _projectScope,
      _query.text,
      _options,
      _results,
      _page,
      _selected,
      _scroll.hasClients ? _scroll.offset : 0,
      _preview,
    );
  }

  void _listenIndex() {
    _indexSubscription?.cancel();
    _indexRefresh?.cancel();
    _indexRefresh = null;
    _filterSource = null;
    _pdfRevision = widget.controller.pdfIndexRevision;
    _indexSubscription = widget.controller.pdfIndexChanges.listen((_) {
      if (!mounted) return;
      if (_pdfRevision != widget.controller.pdfIndexRevision) {
        final previous = _selectionIn(_filterCache);
        _refreshSelection ??= previous;
        _pdfRevision = widget.controller.pdfIndexRevision;
        _retainSelection(previous);
        _indexRefresh ??= Timer(const Duration(milliseconds: 250), () {
          _indexRefresh = null;
          if (mounted) _search(_query.text, refresh: true);
        });
      }
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(SearchView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ownerGeneration != widget.controller.workspaceGeneration ||
        oldWidget.controller != widget.controller) {
      _ownerGeneration = widget.controller.workspaceGeneration;
      _query.clear();
      _options = const SearchOptions();
      _results = [];
      _selected = _page = 0;
      _preview = _filters = false;
      _listenIndex();
      _search('');
    }
    final changedProject = _projectScope != widget.controller.selectedProjectId;
    _projectScope = widget.controller.selectedProjectId;
    if (oldWidget.controller != widget.controller || changedProject) {
      _listenIndex();
      _search(_query.text);
    }
  }

  void _changePage(int page) {
    _refreshSelection = null;
    _selectionReveal.cancel();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() {
      _page = page;
      _selected = 0;
    });
    _queryFocus.requestFocus();
  }

  void _libraryChange(Map<String, dynamic> value) {
    widget.controller.updateSession((s) => s.searchWorkspace = value);
    setState(() {});
  }

  void _search(String value, {bool refresh = false}) {
    if (refresh) {
      _refreshSelection ??= _selectionIn(_filterCache);
    } else {
      _refreshSelection = null;
    }
    _selectionReveal.cancel();
    _debounce?.cancel();
    if (!refresh && _scroll.hasClients) _scroll.jumpTo(0);
    final generation = ++_generation;
    setState(() {
      if (!refresh) {
        _results = [];
        _selected = 0;
        _page = 0;
      }
      _error = null;
      _loading = value.trim().isNotEmpty && (!refresh || _results.isEmpty);
    });
    if (value.trim().isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 180), () async {
      try {
        final found = await widget.controller.searchLocations(value.trim());
        if (mounted && generation == _generation) {
          setState(() {
            final previous = refresh
                ? _refreshSelection ?? _selectionIn(_filterCache)
                : null;
            _results = found;
            _loading = false;
            _refreshSelection = null;
            _retainSelection(previous);
          });
        }
      } catch (_) {
        if (mounted && generation == _generation) {
          setState(() {
            _error = 'Search is temporarily unavailable.';
            _loading = false;
          });
        }
      }
    });
  }

  void _restore(String query, [SearchOptions options = const SearchOptions()]) {
    _query.text = query;
    _query.selection = TextSelection.collapsed(offset: query.length);
    _options = options;
    _filters = options.hasFilters;
    _search(query);
    _queryFocus.requestFocus();
  }

  void _setOptions(Map<String, dynamic> change) => setState(() {
    _refreshSelection = null;
    _selectionReveal.cancel();
    _options = SearchOptions.fromJson({..._options.toJson(), ...change});
    _selected = 0;
    _page = 0;
    if (_scroll.hasClients) _scroll.jumpTo(0);
  });
  void _open(OrbitSearchResult result) {
    _rememberReturn();
    _libraryChange(_library.remember(_query.text));
    widget.controller.openSearchResult(result);
  }

  KeyEventResult _key(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent || !_queryFocus.hasFocus) {
      return KeyEventResult.ignored;
    }
    final shown = _shown;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_preview) {
        setState(() => _preview = false);
      } else {
        _query.clear();
        _search('');
      }
      return KeyEventResult.handled;
    }
    final direction = event.logicalKey == LogicalKeyboardKey.arrowDown
        ? 1
        : event.logicalKey == LogicalKeyboardKey.arrowUp
        ? -1
        : 0;
    if (direction != 0 && shown.isNotEmpty) {
      _refreshSelection = null;
      setState(
        () => _selected = (_selected + direction).clamp(0, shown.length - 1),
      );
      _selectionReveal.reveal(_scroll, forward: direction > 0);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter && shown.isNotEmpty) {
      _open(shown[_selected.clamp(0, shown.length - 1)]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _rememberReturn();
    _indexSubscription?.cancel();
    _indexRefresh?.cancel();
    _selectionReveal.cancel();
    _debounce?.cancel();
    _query.dispose();
    _queryFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    var name = _query.text.trim();
    String? problem;
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => OrbitDialog(
          title: const Text('Save search'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Keep this query, filters and sorting for next time.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: name,
                  autofocus: true,
                  maxLength: 80,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    error: problem == null ? null : Text(problem!),
                  ),
                  onChanged: (value) => update(() {
                    name = value;
                    problem = null;
                  }),
                ),
                if (_library.saved.any(
                  (s) => s.name.toLowerCase() == name.trim().toLowerCase(),
                ))
                  const Text('A search with this name will be updated.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = name.trim();
                if (value.isEmpty) {
                  update(() => problem = 'Enter a name.');
                  return;
                }
                Navigator.pop(context, value);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || chosen == null) return;
    try {
      _libraryChange(
        _library.save(SavedSearch(chosen, _query.text.trim(), _options)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _manage() async {
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => OrbitDialog(
          title: const Text('Saved searches'),
          content: _library.saved.isEmpty
              ? const Center(child: Text('No saved searches.'))
              : Column(
                  children: [
                    for (final search in _library.saved)
                      OrbitActionTile(
                        title: Text(search.name),
                        leading: const Icon(Icons.bookmark_outline),
                        subtitle: Text(search.query),
                        actions: [
                          IconButton(
                            tooltip: 'Remove ${search.name}',
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: _library.editable
                                ? () {
                                    final before = widget
                                        .controller
                                        .session
                                        .searchWorkspace;
                                    _libraryChange(
                                      _library.remove(search.name),
                                    );
                                    update(() {});
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text('Removed ${search.name}'),
                                        action: SnackBarAction(
                                          label: 'Undo',
                                          onPressed: () {
                                            // Restore only this entry, preserving later library edits.
                                            final raw = SearchLibrary(before)
                                                .saved
                                                .where(
                                                  (s) => s.name == search.name,
                                                );
                                            if (mounted &&
                                                raw.isNotEmpty &&
                                                !_library.saved.any(
                                                  (s) =>
                                                      s.name.toLowerCase() ==
                                                      search.name.toLowerCase(),
                                                )) {
                                              try {
                                                _libraryChange(
                                                  _library.restore(raw.first),
                                                );
                                              } catch (_) {
                                                ScaffoldMessenger.of(
                                                  this.context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Could not restore the search.',
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                          ),
                        ],
                        onTap: () {
                          Navigator.pop(context);
                          _restore(search.query, search.options);
                        },
                      ),
                  ],
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filter(
    String label,
    String key,
    String? value,
    Iterable<String> values,
  ) {
    final options = {...values, ?value}.toList()..sort();
    return PopupMenuButton<String>(
      tooltip: 'Filter by ${label.toLowerCase()}',
      onSelected: (v) => _setOptions({key: v.isEmpty ? null : v}),
      itemBuilder: (_) => [
        PopupMenuItem(
          height: 48,
          value: '',
          child: Text('All ${label.toLowerCase()}s'),
        ),
        for (final option in options)
          PopupMenuItem(height: 48, value: option, child: Text(option)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(value ?? label)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _highlight(String text, {int? lines, int? offset, int? length}) {
    final q = _query.text.trim().toLowerCase();
    final found = offset ?? (q.isEmpty ? -1 : text.toLowerCase().indexOf(q));
    final count = length ?? q.length;
    final style = Theme.of(context).textTheme.bodyMedium;
    return Text.rich(
      TextSpan(
        style: style,
        children: found < 0 || count <= 0 || found + count > text.length
            ? [TextSpan(text: text)]
            : [
                TextSpan(text: text.substring(0, found)),
                TextSpan(
                  text: text.substring(found, found + count),
                  style: TextStyle(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .18),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: text.substring(found + count)),
              ],
      ),
      maxLines: lines,
    );
  }

  Widget _previewContent(OrbitSearchResult result) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        result.object.title.isEmpty ? 'Untitled' : result.object.title,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text(
        '${result.context}${result.location.page == null ? '' : ' · Page ${result.location.page}'}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 12),
      Text(
        'Matched ${result.matchKind.toLowerCase()}',
        style: Theme.of(context).textTheme.labelMedium,
      ),
      const SizedBox(height: 12),
      SelectionArea(
        child: _highlight(
          readableSearchExcerpt(result),
          offset: result.excerptOffset,
          length: result.excerptLength,
        ),
      ),
      const Divider(),
      Text(
        'Updated ${_date(result.object.updatedAt.toLocal())}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );

  Widget _previewOpen(
    OrbitSearchResult result, {
    BuildContext? dialogContext,
  }) => FilledButton.icon(
    onPressed: () {
      if (dialogContext != null) Navigator.pop(dialogContext);
      _open(result);
    },
    icon: const Icon(Icons.open_in_new, size: 16),
    label: const Text('Open at match'),
  );

  Widget _peek(OrbitSearchResult result) => Column(
    children: [
      Expanded(
        child: SingleChildScrollView(
          child: Column(
            children: [
              OrbitPanelHeader(
                title: 'Preview',
                icon: Icons.visibility_outlined,
                actions: [
                  IconButton(
                    tooltip: 'Close preview',
                    onPressed: () => setState(() => _preview = false),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _previewContent(result),
              ),
            ],
          ),
        ),
      ),
      Padding(padding: const EdgeInsets.all(12), child: _previewOpen(result)),
    ],
  );

  String _date(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  Future<void> _showPeek(OrbitSearchResult result, bool wide) async {
    if (wide) {
      setState(() => _preview = true);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => OrbitDialog(
        title: const Text('Preview'),
        content: _previewContent(result),
        actions: [
          IconButton(
            tooltip: 'Close preview',
            onPressed: () => Navigator.pop(dialogContext),
            icon: const Icon(Icons.close),
          ),
          _previewOpen(result, dialogContext: dialogContext),
        ],
      ),
    );
  }

  Widget _start() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Search this Vault',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Find a passage, open its source, or return to a saved search.',
        ),
        const SizedBox(height: 24),
        if (_library.saved.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Saved searches'),
              TextButton(onPressed: _manage, child: const Text('Manage')),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final search in _library.saved)
                ActionChip(
                  avatar: const Icon(Icons.bookmark_outline, size: 16),
                  label: Text(search.name),
                  onPressed: () => _restore(search.query, search.options),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (_library.recent.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Recent searches'),
              TextButton(
                onPressed: _library.editable
                    ? () => _libraryChange(_library.clearRecent())
                    : null,
                child: const Text('Clear history'),
              ),
            ],
          ),
          for (final query in _library.recent)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history, size: 18),
              title: Text(query),
              trailing: const Icon(Icons.north_west, size: 16),
              onTap: () => _restore(query),
            ),
        ],
        const SizedBox(height: 24),
        const Text(
          '↑ ↓ select · Enter open · Escape clear',
          style: TextStyle(fontSize: 12),
        ),
      ],
    ),
  );

  Widget _pdfCoverage() {
    final c = widget.controller;
    final entries = c.pdfIndexEntries.values;
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final indexed = entries.where((e) => e.phase == 'Indexed').length;
    final failures = entries.where((e) => e.phase == 'Failed').length;
    final noText = entries.where((e) => e.phase == 'No text').length;
    final incomplete = entries
        .where((e) => e.phase == 'Indexed' && e.unsearchablePages > 0)
        .length;
    final active = entries.where((e) => e.phase == 'Indexing').firstOrNull;
    final pending = entries.length - indexed - failures - noText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              'PDF text: $indexed/${entries.length} indexed'
              '${pending == 0 ? '' : ' · $pending pending'}${failures == 0 ? '' : ' · $failures failed'}'
              '${noText == 0 ? '' : ' · $noText without text'}${incomplete == 0 ? '' : ' · $incomplete with incomplete text'}${c.pdfIndexPaused ? ' · paused' : ''}',
            ),
          ),
          if (active != null) Text('${active.pages}/${active.total} pages'),
          TextButton(
            onPressed: _showIndexDetails,
            child: const Text('Index details'),
          ),
          if (pending > 0)
            TextButton(
              onPressed: () => c.pausePdfIndex(!c.pdfIndexPaused),
              child: Text(
                c.pdfIndexPaused ? 'Resume indexing' : 'Pause indexing',
              ),
            ),
          if (failures > 0)
            TextButton(
              onPressed: c.retryPdfIndex,
              child: const Text('Retry failed PDFs'),
            ),
        ],
      ),
    );
  }

  Future<void> _showIndexDetails() => showOrbitDialog<void>(
    context: context,
    builder: (context) => StreamBuilder<void>(
      stream: widget.controller.pdfIndexChanges,
      builder: (context, _) {
        final c = widget.controller;
        final entries = c.pdfIndexEntries.entries.toList();
        return OrbitDialog(
          title: const Text('PDF search coverage'),
          contentSlivers: [
            SliverList.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final item = entries[index], state = item.value;
                return ListTile(
                  onTap: () => showOcrReview(context, c, objectId: item.key),
                  title: Text(c.find(item.key)?.title ?? 'Unavailable PDF'),
                  subtitle: Text(
                    '${state.phase}${state.total == 0 ? '' : ' · ${state.pages}/${state.total} pages'}'
                    '${state.detail == null ? '' : '\n${state.detail}'}',
                  ),
                );
              },
            ),
          ],
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final selected = shown.isEmpty
        ? null
        : shown[_selected.clamp(0, shown.length - 1)];
    final hasQuery = _query.text.trim().isNotEmpty;
    return LayoutBuilder(
      builder: (context, bounds) {
        final wide = bounds.maxWidth >= 900;
        return Focus(
          onKeyEvent: _key,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _query,
                  focusNode: _queryFocus,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search this Vault…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Recognize scanned PDFs and images',
                          onPressed: () =>
                              showOcrReview(context, widget.controller),
                          icon: const Icon(Icons.document_scanner_outlined),
                        ),
                        if (hasQuery)
                          IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _query.clear();
                              _search('');
                              _queryFocus.requestFocus();
                            },
                          ),
                      ],
                    ),
                  ),
                  onChanged: _search,
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: CustomScrollView(
                        controller: _scroll,
                        slivers: [
                          SliverToBoxAdapter(child: _pdfCoverage()),
                          SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Wrap(
                                    spacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      _filter(
                                        'Type',
                                        'kind',
                                        _options.kind,
                                        _results.map(
                                          (r) => objectKindLabel(r.object),
                                        ),
                                      ),
                                      _filter(
                                        'Project',
                                        'project',
                                        _options.project,
                                        _results
                                            .map(
                                              (r) => r
                                                  .object
                                                  .properties['project'],
                                            )
                                            .whereType<String>()
                                            .where((s) => s.isNotEmpty),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => setState(
                                          () => _filters = !_filters,
                                        ),
                                        icon: Icon(
                                          _filters
                                              ? Icons.expand_less
                                              : Icons.tune,
                                          size: 16,
                                        ),
                                        label: const Text('More filters'),
                                      ),
                                      PopupMenuButton<SearchOrder>(
                                        tooltip: 'Sort results',
                                        initialValue: _options.order,
                                        onSelected: (v) =>
                                            _setOptions({'order': v.name}),
                                        itemBuilder: (_) => [
                                          const PopupMenuItem(
                                            value: SearchOrder.relevance,
                                            child: Text('Relevance'),
                                          ),
                                          const PopupMenuItem(
                                            value: SearchOrder.modified,
                                            child: Text('Recently updated'),
                                          ),
                                          const PopupMenuItem(
                                            value: SearchOrder.title,
                                            child: Text('Title A–Z'),
                                          ),
                                        ],
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Text(switch (_options.order) {
                                            SearchOrder.relevance =>
                                              'Relevance ▾',
                                            SearchOrder.modified =>
                                              'Recently updated ▾',
                                            SearchOrder.title => 'Title A–Z ▾',
                                          }),
                                        ),
                                      ),
                                      if (_options.hasFilters)
                                        TextButton(
                                          onPressed: () => setState(() {
                                            _options = SearchOptions(
                                              order: _options.order,
                                            );
                                            _selected = 0;
                                          }),
                                          child: const Text('Clear filters'),
                                        ),
                                      TextButton.icon(
                                        onPressed: hasQuery && _library.editable
                                            ? _save
                                            : null,
                                        icon: const Icon(
                                          Icons.bookmark_add_outlined,
                                          size: 16,
                                        ),
                                        label: const Text('Save search'),
                                      ),
                                      if (_library.saved.isNotEmpty)
                                        PopupMenuButton<String>(
                                          tooltip: 'Saved searches',
                                          onSelected: (name) {
                                            final s = _library.saved.firstWhere(
                                              (s) => s.name == name,
                                            );
                                            _restore(s.query, s.options);
                                          },
                                          itemBuilder: (_) => [
                                            for (final s in _library.saved)
                                              PopupMenuItem(
                                                height: 48,
                                                value: s.name,
                                                child: Text(s.name),
                                              ),
                                          ],
                                          icon: const Icon(
                                            Icons.bookmarks_outlined,
                                            size: 18,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (_filters)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: Wrap(
                                      spacing: 8,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        _filter(
                                          'Folder',
                                          'folder',
                                          _options.folder,
                                          _results
                                              .map(
                                                (r) => r
                                                    .object
                                                    .properties['folder'],
                                              )
                                              .whereType<String>()
                                              .where((s) => s.isNotEmpty),
                                        ),
                                        _filter(
                                          'Tag',
                                          'tag',
                                          _options.tag,
                                          _results.expand(
                                            (r) =>
                                                r.object.properties['tags']
                                                    is List
                                                ? (r.object.properties['tags']
                                                          as List)
                                                      .whereType<String>()
                                                : <String>[],
                                          ),
                                        ),
                                        _filter(
                                          'Match',
                                          'matchKind',
                                          _options.matchKind,
                                          _results.map((r) => r.matchKind),
                                        ),
                                        FilterChip(
                                          label: const Text(
                                            'Hide completed tasks',
                                          ),
                                          selected: _options.hideCompleted,
                                          onSelected: (v) =>
                                              _setOptions({'hideCompleted': v}),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (hasQuery && !_loading && _error == null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 8,
                                    ),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          '${_filtered.length} results${_filtered.length > _pageSize ? ' · ${_page * _pageSize + 1}–${_page * _pageSize + shown.length}' : ''}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                        if (selected != null)
                                          TextButton.icon(
                                            onPressed: () =>
                                                _showPeek(selected, wide),
                                            icon: const Icon(
                                              Icons.vertical_split_outlined,
                                              size: 16,
                                            ),
                                            label: const Text('Preview'),
                                          ),
                                      ],
                                    ),
                                  ),

                                const Divider(height: 1),
                              ],
                            ),
                          ),
                          if (_loading)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: Semantics(
                                    label: 'Searching',
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              ),
                            )
                          else if (_error != null)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    Text(_error!),
                                    TextButton(
                                      onPressed: () => _search(_query.text),
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else if (!hasQuery)
                            SliverToBoxAdapter(child: _start())
                          else if (shown.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    Text(
                                      'No matches',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _options.hasFilters
                                          ? 'Clear filters or try another phrase.'
                                          : 'Try another title, phrase or tag.',
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              sliver: SliverList.builder(
                                itemCount: shown.length,
                                itemBuilder: (context, i) {
                                  final result = shown[i];
                                  return KeyedSubtree(
                                    key: i == _selected
                                        ? _selectionReveal.marker
                                        : null,
                                    child: OrbitActionTile(
                                      key: ValueKey('search-result-$i'),
                                      selected: _selected == i,
                                      dense: false,
                                      leading: Icon(
                                        objectIcon(result.object.typeId),
                                        size: 20,
                                      ),
                                      title: _highlight(
                                        result.object.title.isEmpty
                                            ? 'Untitled'
                                            : result.object.title,
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${result.context} · ${result.matchKind}${result.location.page == null ? '' : ' · Page ${result.location.page}'}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                          if (result.matchedText !=
                                              result.object.title)
                                            _highlight(
                                              readableSearchExcerpt(result),
                                              offset: result.excerptOffset,
                                              length: result.excerptLength,
                                            ),
                                        ],
                                      ),
                                      actions: [
                                        IconButton(
                                          tooltip:
                                              'Preview ${result.object.title}',
                                          icon: const Icon(
                                            Icons.visibility_outlined,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _refreshSelection = null;
                                              _selected = i;
                                            });
                                            _showPeek(result, wide);
                                          },
                                        ),
                                      ],
                                      onTap: () => _open(result),
                                    ),
                                  );
                                },
                              ),
                            ),
                          if (hasQuery &&
                              !_loading &&
                              _error == null &&
                              _filtered.length > _pageSize)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'Page ${_page + 1} of ${(_filtered.length / _pageSize).ceil()}',
                                    ),
                                    TextButton(
                                      onPressed: _page == 0
                                          ? null
                                          : () => _changePage(_page - 1),
                                      child: const Text('Previous results'),
                                    ),
                                    TextButton(
                                      onPressed:
                                          (_page + 1) * _pageSize >=
                                              _filtered.length
                                          ? null
                                          : () => _changePage(_page + 1),
                                      child: const Text('Next results'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (wide && _preview && selected != null) ...[
                      const VerticalDivider(width: 1),
                      SizedBox(
                        width: 340,
                        child: ColoredBox(
                          color: OrbitColors.of(context).panel,
                          child: _peek(selected),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
