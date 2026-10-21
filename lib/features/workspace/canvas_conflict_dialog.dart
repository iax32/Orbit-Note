import 'dart:convert';
import 'package:flutter/material.dart';
import '../../app/collaboration_controller.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import '../../domain/collaboration.dart';

class CanvasConflictDialog extends StatefulWidget {
  const CanvasConflictDialog({
    super.key,
    required this.controller,
    required this.review,
  });
  final CollaborationController controller;
  final SharedCanvasReview review;
  @override
  State<CanvasConflictDialog> createState() => _CanvasConflictDialogState();
}

class _CanvasConflictDialogState extends State<CanvasConflictDialog> {
  late SharedCanvasReview review = widget.review;
  final choices = <String, CanvasConflictSide>{};
  CanvasConflictSide? order;
  bool busy = false;
  String? error;

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } on Object catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError
              ? e.message.toString()
              : 'Could not complete review. Your local board is preserved. Reload or try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final comparison = review.comparison;
    final complete =
        choices.length == comparison.placements.length &&
        (!comparison.hasOrderConflict || order != null);
    return PopScope(
      canPop: !busy,
      child: OrbitDialog(
        maxWidth: 860,
        title: const Text('Review shared Canvas edits'),
        contentSlivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  review.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Shared version ${review.serverVersion} · ${comparison.placements.length} overlapping items',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Independent edits merge automatically. Choose the complete version of each overlapping item. Removing a placement keeps its referenced note, task or file. Your previous board remains in file history.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              for (final p in comparison.placements) {
                                choices[p.id] = CanvasConflictSide.local;
                              }
                              if (comparison.hasOrderConflict) {
                                order = CanvasConflictSide.local;
                              }
                            }),
                      child: const Text('Choose all mine'),
                    ),
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              for (final p in comparison.placements) {
                                choices[p.id] = CanvasConflictSide.shared;
                              }
                              if (comparison.hasOrderConflict) {
                                order = CanvasConflictSide.shared;
                              }
                            }),
                      child: const Text('Choose all shared'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SliverList.builder(
            itemCount: comparison.placements.length,
            itemBuilder: (context, index) =>
                _placement(comparison.placements[index]),
          ),
          if (comparison.hasOrderConflict)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stacking order',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Text(
                      'Both versions reordered surviving items. The first item is furthest back; new items from both versions remain.',
                    ),
                    for (final side in CanvasConflictSide.values)
                      ExpansionTile(
                        title: Text(
                          side == CanvasConflictSide.local
                              ? 'My order'
                              : 'Shared order',
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: SelectableText(
                              ((side == CanvasConflictSide.local
                                          ? comparison.local
                                          : comparison
                                                .shared)['data']['elements']
                                      as List)
                                  .map((e) => e['id'])
                                  .join(' → '),
                            ),
                          ),
                        ],
                      ),
                    _choice(
                      'stacking-order',
                      order,
                      (v) => setState(() => order = v),
                    ),
                  ],
                ),
              ),
            ),
          if (error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            ),
          if (busy) const SliverToBoxAdapter(child: LinearProgressIndicator()),
        ],
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Keep reviewing later'),
          ),
          OutlinedButton(
            onPressed: busy
                ? null
                : () => run(() async {
                    final next = await widget.controller.reviewCanvas(
                      review.id,
                    );
                    if (mounted) {
                      setState(() {
                        review = next;
                        choices.clear();
                        order = null;
                      });
                    }
                  }),
            child: const Text('Reload comparison'),
          ),
          FilledButton(
            onPressed: busy || !complete
                ? null
                : () => run(() async {
                    await widget.controller.resolveCanvas(
                      review,
                      choices,
                      order: order,
                    );
                    if (context.mounted) Navigator.pop(context);
                  }),
            child: const Text('Save resolution & sync'),
          ),
        ],
      ),
    );
  }

  Widget _choice(
    String id,
    CanvasConflictSide? selected,
    ValueChanged<CanvasConflictSide> changed,
  ) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final side in CanvasConflictSide.values)
        ChoiceChip(
          key: ValueKey('canvas-review-$id-${side.name}'),
          label: Text(
            side == CanvasConflictSide.local ? 'Keep mine' : 'Use shared',
          ),
          selected: selected == side,
          onSelected: busy ? null : (_) => changed(side),
        ),
    ],
  );

  Widget _placement(CanvasPlacementConflict p) => Container(
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: OrbitColors.of(context).border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _placementLabel(p.local ?? p.shared ?? p.base!),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text('Placement ${p.id}', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final mine = _version('Mine', p.local, p.changedFields);
            final shared = _version('Shared', p.shared, p.changedFields);
            return constraints.maxWidth >= 600 &&
                    MediaQuery.textScalerOf(context).scale(14) < 22
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: mine),
                      const SizedBox(width: 16),
                      Expanded(child: shared),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [mine, const SizedBox(height: 12), shared],
                  );
          },
        ),
        ExpansionTile(
          title: const Text('Common base'),
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: _version('Before either edit', p.base, p.changedFields),
            ),
          ],
        ),
        _choice(p.id, choices[p.id], (v) => setState(() => choices[p.id] = v)),
      ],
    ),
  );

  Widget _version(
    String label,
    Map<String, dynamic>? value,
    List<String> fields,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      if (value == null)
        const Text('Removed from board')
      else
        for (final key in fields)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '$key: ${value.containsKey(key) ? _preview(value[key]) : '(not present)'}',
            ),
          ),
    ],
  );

  String _preview(dynamic value) {
    final text = value is String ? value : jsonEncode(value);
    return text.runes.length > 600
        ? '${String.fromCharCodes(text.runes.take(600))}… (preview shortened)'
        : text;
  }

  String _placementLabel(Map<String, dynamic> value) {
    final objectId = value['objectId'];
    final target = objectId is String
        ? widget.controller.workspace.find(objectId)
        : null;
    if (target != null) return target.title;
    final text = value['text'] ?? value['title'];
    if (text is String && text.trim().isNotEmpty) {
      return text.trim().split(RegExp(r'[\r\n]')).first;
    }
    return '${value['type'] ?? 'Placement'} · ${value['id']}';
  }
}
