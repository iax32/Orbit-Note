import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/orbit_components.dart';
import '../../domain/wiki_links.dart';

Future<NoteLinkTarget?> showNoteLinkDialog(
  BuildContext context,
  List<NoteLinkTarget> targets, {
  String initialQuery = '',
}) => showOrbitDialog<NoteLinkTarget>(
  context: context,
  builder: (context) =>
      _LinkDialog(targets: targets, initialQuery: initialQuery),
);

class _LinkDialog extends StatefulWidget {
  const _LinkDialog({required this.targets, required this.initialQuery});

  final List<NoteLinkTarget> targets;
  final String initialQuery;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  late final TextEditingController _query = TextEditingController(
    text: widget.initialQuery,
  );
  final _searchFocus = FocusNode(debugLabel: 'NoteLinkSearch');
  final _scroll = ScrollController();
  final _reveal = OrbitListSelectionReveal();
  late List<NoteLinkTarget> _matches;
  int _selected = 0;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _filter();
    _searchFocus.onKeyEvent = _handleKey;
  }

  void _filter() {
    final query = _query.text.toLowerCase().trim();
    _matches =
        widget.targets
            .where(
              (target) =>
                  target.title.toLowerCase().contains(query) ||
                  target.aliases.any(
                    (alias) => alias.toLowerCase().contains(query),
                  ),
            )
            .toList()
          ..sort((a, b) {
            final title = a.title.toLowerCase().compareTo(
              b.title.toLowerCase(),
            );
            return title != 0 ? title : a.id.compareTo(b.id);
          });
  }

  void _queryChanged() {
    _reveal.cancel();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() {
      _filter();
      _selected = 0;
    });
  }

  void _finish([NoteLinkTarget? target]) {
    if (_completed) return;
    _completed = true;
    Navigator.pop(context, target);
  }

  void _chooseSelected() {
    if (_matches.isNotEmpty) _finish(_matches[_selected]);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      if (_matches.isNotEmpty) {
        final forward = key == LogicalKeyboardKey.arrowDown;
        setState(
          () => _selected = (_selected + (forward ? 1 : -1)).clamp(
            0,
            _matches.length - 1,
          ),
        );
        _reveal.reveal(_scroll, forward: forward);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (event is KeyDownEvent) _chooseSelected();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) _finish();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _reveal.cancel();
    _searchFocus.dispose();
    _scroll.dispose();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OrbitDialog(
      maxWidth: 560,
      title: const Text('Link to an object'),
      contentScrollController: _scroll,
      contentSlivers: [
        SliverToBoxAdapter(
          child: TextField(
            key: const ValueKey('note-link-search'),
            autofocus: true,
            controller: _query,
            focusNode: _searchFocus,
            decoration: InputDecoration(
              labelText: 'Search objects',
              hintText: 'Search by title or alias',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _query.clear();
                        _queryChanged();
                        _searchFocus.requestFocus();
                      },
                    ),
            ),
            onChanged: (_) => _queryChanged(),
            onSubmitted: (_) => _chooseSelected(),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _matches.isEmpty
                    ? 'No matching objects'
                    : '${_matches.length} ${_matches.length == 1 ? 'object' : 'objects'}',
              ),
            ),
          ),
        ),
        SliverList.builder(
          itemCount: _matches.length,
          itemBuilder: (context, index) {
            final target = _matches[index];
            return MergeSemantics(
              key: ValueKey('note-link-target-${target.id}'),
              child: Semantics(
                button: true,
                selected: index == _selected,
                child: ListTile(
                  selected: index == _selected,
                  onFocusChange: (focused) {
                    if (!focused) return;
                    _reveal.cancel();
                    setState(() => _selected = index);
                  },
                  leading: const Icon(Icons.link_rounded, size: 20),
                  title: Column(
                    key: index == _selected ? _reveal.marker : null,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        target.title.isEmpty ? 'Untitled object' : target.title,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        target.id,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      if (target.aliases.isNotEmpty)
                        Text(
                          'Aliases: ${target.aliases.join(', ')}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                    ],
                  ),
                  onTap: () => _finish(target),
                ),
              ),
            );
          },
        ),
      ],
      actions: [
        TextButton(onPressed: () => _finish(), child: const Text('Cancel')),
      ],
    );
  }
}
