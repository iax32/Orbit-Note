import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../app/orbit_components.dart';

typedef _OutlineEntry = ({PdfOutlineNode node, String path});

class PdfOutlineDialog extends StatefulWidget {
  const PdfOutlineDialog({
    super.key,
    required this.nodes,
    this.loadFailed = false,
  });
  final List<PdfOutlineNode> nodes;
  final bool loadFailed;
  @override
  State<PdfOutlineDialog> createState() => _PdfOutlineDialogState();
}

class _PdfOutlineDialogState extends State<PdfOutlineDialog> {
  final scroll = ScrollController();
  final selectionReveal = OrbitListSelectionReveal();
  late final focus = FocusNode(onKeyEvent: onKey);
  late final entries = flatten();
  String query = '';
  int selected = 0;

  @override
  void initState() {
    super.initState();
    selectFirst();
    selectionReveal.reveal(scroll);
  }

  void selectFirst() {
    final index = results.indexWhere((entry) => entry.node.dest != null);
    selected = index < 0 ? 0 : index;
  }

  List<_OutlineEntry> flatten() {
    final output = <_OutlineEntry>[];
    final pending = [
      for (final node in widget.nodes.reversed) (node: node, path: ''),
    ];
    while (pending.isNotEmpty) {
      final entry = pending.removeLast();
      output.add(entry);
      final path = [
        if (entry.path.isNotEmpty) entry.path,
        entry.node.title,
      ].join(' › ');
      pending.addAll(
        entry.node.children.reversed.map((node) => (node: node, path: path)),
      );
    }
    return output;
  }

  List<_OutlineEntry> get results {
    final words = query.trim().toLowerCase().split(RegExp(r'\s+'));
    return entries.where((e) {
      final text = '${e.path} ${e.node.title}'.toLowerCase();
      return words.every(text.contains);
    }).toList();
  }

  void openSelected() {
    final items = results;
    if (items.isEmpty) return;
    final destination = items[selected.clamp(0, items.length - 1)].node.dest;
    if (destination != null) Navigator.pop(context, destination);
  }

  KeyEventResult onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.arrowDown &&
        event.logicalKey != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    final items = results;
    if (items.isNotEmpty) {
      final direction = event.logicalKey == LogicalKeyboardKey.arrowDown
          ? 1
          : -1;
      var next = selected + direction;
      while (next >= 0 &&
          next < items.length &&
          items[next].node.dest == null) {
        next += direction;
      }
      if (next < 0 || next >= items.length) return KeyEventResult.handled;
      setState(() => selected = next);
      selectionReveal.reveal(scroll, forward: direction > 0);
    }
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    selectionReveal.cancel();
    focus.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = results;
    return OrbitDialog(
      title: const Text('PDF outline'),
      contentScrollController: scroll,
      contentSlivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              TextField(
                autofocus: true,
                focusNode: focus,
                decoration: const InputDecoration(
                  labelText: 'Find a section',
                  hintText: 'Search headings and parent sections',
                ),
                onChanged: (value) {
                  setState(() {
                    query = value;
                    selectFirst();
                  });
                  if (scroll.hasClients) scroll.jumpTo(0);
                  selectionReveal.reveal(scroll);
                },
                onSubmitted: (_) => openSelected(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        if (items.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                entries.isEmpty
                    ? widget.loadFailed
                          ? 'The PDF outline could not be read. You can still navigate by page.'
                          : 'This PDF has no embedded outline.'
                    : 'No matching sections.',
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final entry = items[index];
              final node = entry.node;
              return Tooltip(
                key: selected == index ? selectionReveal.marker : null,
                message: [
                  entry.path,
                  node.title,
                ].where((s) => s.isNotEmpty).join(' › '),
                child: ListTile(
                  selected: selected == index,
                  enabled: node.dest != null,
                  title: Text(
                    node.title.isEmpty ? 'Untitled section' : node.title,
                  ),
                  subtitle: Text(
                    [
                      if (entry.path.isNotEmpty) entry.path,
                      if (node.dest != null)
                        'Page ${node.dest!.pageNumber}'
                      else
                        'Section group',
                    ].join(' · '),
                  ),
                  onTap: node.dest == null
                      ? null
                      : () => Navigator.pop(context, node.dest),
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
  }
}
