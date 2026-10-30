import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/orbit_components.dart';

class PdfBookmarksDialog extends StatefulWidget {
  const PdfBookmarksDialog({
    super.key,
    required this.pages,
    required this.names,
    required this.pageCount,
    required this.loadPreview,
    this.onRename,
  });
  final List<int> pages;
  final Map<int, String> names;
  final int pageCount;
  final Future<Uint8List?> Function(int) loadPreview;
  final Future<bool> Function(int, String)? onRename;
  @override
  State<PdfBookmarksDialog> createState() => _PdfBookmarksDialogState();
}

enum _BookmarkSort {
  page('Page: first to last'),
  pageDescending('Page: last to first'),
  name('Name: A–Z'),
  nameDescending('Name: Z–A');

  const _BookmarkSort(this.label);
  final String label;
}

class _PdfBookmarksDialogState extends State<PdfBookmarksDialog> {
  final scroll = ScrollController();
  final selectionReveal = OrbitListSelectionReveal();
  late final searchFocus = FocusNode(onKeyEvent: onKey);
  _BookmarkSort sort = _BookmarkSort.page;
  late final names = {...widget.names};
  String query = '';
  int? selected;
  Future<Uint8List?>? preview;
  late final pages = widget.pages.where((p) => p > 0).toSet().toList()..sort();
  String label(int page) =>
      names[page]?.isNotEmpty == true ? names[page]! : 'Page $page';
  List<int> get filtered {
    final result = pages
        .where(
          (p) => '${names[p] ?? ''} Page $p'.toLowerCase().contains(
            query.trim().toLowerCase(),
          ),
        )
        .toList();
    result.sort((a, b) {
      if (sort == _BookmarkSort.page) return a.compareTo(b);
      if (sort == _BookmarkSort.pageDescending) return b.compareTo(a);
      final byName = label(a).toLowerCase().compareTo(label(b).toLowerCase());
      if (byName == 0) return a.compareTo(b);
      return sort == _BookmarkSort.name ? byName : -byName;
    });
    return result;
  }

  void revealSelection({bool forward = true, bool reset = false}) {
    if (reset && scroll.hasClients) scroll.jumpTo(0);
    selectionReveal.reveal(scroll, forward: forward);
  }

  KeyEventResult onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (event is KeyDownEvent &&
          selected != null &&
          selected! <= widget.pageCount) {
        Navigator.pop(context, selected);
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey != LogicalKeyboardKey.arrowDown &&
        event.logicalKey != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    final matches = filtered;
    if (matches.isEmpty) return KeyEventResult.handled;
    final current = matches.indexOf(selected ?? -1);
    final index = current < 0
        ? 0
        : (current +
                  (event.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1))
              .clamp(0, matches.length - 1);
    if (selected != matches[index]) setState(() => select(matches[index]));
    revealSelection(forward: event.logicalKey == LogicalKeyboardKey.arrowDown);
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    selectionReveal.cancel();
    scroll.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (pages.isNotEmpty) select(pages.first);
  }

  void select(int page) {
    selected = page;
    preview = page <= widget.pageCount
        ? Future.sync(() => widget.loadPreview(page))
        : Future.value(null);
  }

  Future<void> rename(int page) async {
    final name = await showOrbitDialog<String>(
      context: context,
      builder: (_) => _BookmarkNameDialog(
        name: names[page] ?? '',
        onSave: (name) => widget.onRename!(page, name),
      ),
    );
    if (mounted && name != null) {
      setState(() {
        names[page] = name;
        if (!filtered.contains(selected)) {
          if (filtered.isEmpty) {
            selected = null;
            preview = null;
          } else {
            select(filtered.first);
          }
        }
      });
      revealSelection(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = filtered;
    return OrbitDialog(
      title: const Text('Saved pages'),
      contentScrollController: scroll,
      contentSlivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              TextField(
                autofocus: true,
                focusNode: searchFocus,
                decoration: const InputDecoration(
                  labelText: 'Find a bookmark',
                  hintText: 'Name or page number',
                ),
                onChanged: (value) {
                  setState(() {
                    query = value;
                    final next = filtered;
                    if (!next.contains(selected)) {
                      if (next.isEmpty) {
                        selected = null;
                        preview = null;
                      } else {
                        select(next.first);
                      }
                    }
                  });
                  revealSelection(reset: true);
                },
                onSubmitted: (_) {
                  if (selected != null && selected! <= widget.pageCount) {
                    Navigator.pop(context, selected);
                  }
                },
              ),
              PopupMenuButton<_BookmarkSort>(
                popUpAnimationStyle: OrbitMotionScope.popupStyle(context),
                tooltip: 'Sort bookmarks',
                initialValue: sort,
                onSelected: (value) {
                  setState(() => sort = value);
                  revealSelection(reset: true);
                  searchFocus.requestFocus();
                },
                itemBuilder: (_) => [
                  for (final value in _BookmarkSort.values)
                    PopupMenuItem(value: value, child: Text(value.label)),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(sort.label)),
                      const Icon(Icons.sort, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (matches.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                pages.isEmpty
                    ? 'Bookmark a page using the ribbon icon in the reader.'
                    : 'No matching bookmarks.',
              ),
            ),
          ),
        if (preview != null)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 160,
              child: FutureBuilder<Uint8List?>(
                key: ValueKey(selected),
                future: preview,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || snapshot.data == null) {
                    return const Center(
                      child: Text('Page preview unavailable.'),
                    );
                  }
                  return Image.memory(
                    snapshot.data!,
                    fit: BoxFit.contain,
                    semanticLabel: 'Preview of page $selected',
                  );
                },
              ),
            ),
          ),
        if (matches.isNotEmpty)
          SliverList.builder(
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final page = matches[index];
              return CallbackShortcuts(
                key: page == selected ? selectionReveal.marker : null,
                bindings: {
                  for (final direction in [-1, 1])
                    SingleActivator(
                      direction < 0
                          ? LogicalKeyboardKey.arrowUp
                          : LogicalKeyboardKey.arrowDown,
                    ): () {
                      final index = matches.indexOf(page);
                      final target =
                          matches[(index + direction).clamp(
                            0,
                            matches.length - 1,
                          )];
                      if (selected != target) {
                        setState(() => select(target));
                      }
                      revealSelection(forward: direction > 0);
                      searchFocus.requestFocus();
                    },
                  for (final key in [
                    LogicalKeyboardKey.enter,
                    LogicalKeyboardKey.numpadEnter,
                  ])
                    SingleActivator(key): () {
                      if (page <= widget.pageCount) {
                        Navigator.pop(context, page);
                      }
                    },
                },
                child: ListTile(
                  key: ValueKey('pdf-bookmark-$page'),
                  selected: page == selected,
                  title: Text(
                    names[page]?.isNotEmpty == true
                        ? names[page]!
                        : 'Page $page',
                  ),
                  subtitle: Text(
                    page > widget.pageCount
                        ? 'Page $page · unavailable in this PDF'
                        : 'Page $page',
                  ),
                  onTap: () => setState(() => select(page)),
                  trailing: widget.onRename == null
                      ? null
                      : IconButton(
                          tooltip: 'Rename bookmark on page $page',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => rename(page),
                        ),
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
        FilledButton(
          onPressed: selected == null || selected! > widget.pageCount
              ? null
              : () => Navigator.pop(context, selected),
          child: const Text('Open page'),
        ),
      ],
    );
  }
}

class _BookmarkNameDialog extends StatefulWidget {
  const _BookmarkNameDialog({required this.name, required this.onSave});
  final String name;
  final Future<bool> Function(String) onSave;
  @override
  State<_BookmarkNameDialog> createState() => _BookmarkNameDialogState();
}

class _BookmarkNameDialogState extends State<_BookmarkNameDialog> {
  late final input = TextEditingController(text: widget.name);
  bool busy = false;
  String? error;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    var saved = false;
    try {
      saved = await widget.onSave(input.text.trim());
    } catch (_) {}
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context, input.text.trim());
      return;
    }
    setState(() {
      busy = false;
      error =
          'Could not save. Your name is kept here; retry or copy it before closing.';
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: OrbitDialog(
      title: const Text('Name bookmark'),
      content: TextField(
        controller: input,
        autofocus: true,
        enabled: !busy,
        maxLength: 200,
        decoration: InputDecoration(
          labelText: 'Bookmark name',
          helper: const Text('Leave blank to use the page number.'),
          error: error == null ? null : Text(error!),
        ),
        onSubmitted: (_) => save(),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? 'Saving…' : 'Save name'),
        ),
      ],
    ),
  );
}
