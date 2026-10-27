import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../app/workspace_controller.dart';
import '../../app/retained_form.dart';
import '../../canvas/scene.dart';
import '../../domain/object_reference.dart';
import '../../domain/research_workspace.dart';
import '../../domain/universal_object.dart';
import '../notes/document_history_dialog.dart';
import '../notes/read_attachment_preview.dart';
import '../canvas/reference_details_dialog.dart';
import 'decision_editor_dialog.dart';

/// One saved definition shared by open tabs, document embeds and Canvas links.
class ResearchWorkspaceView extends ConsumerStatefulWidget {
  const ResearchWorkspaceView({
    super.key,
    required this.controller,
    required this.view,
  });
  final WorkspaceController controller;
  final UniversalObject view;
  @override
  ConsumerState<ResearchWorkspaceView> createState() =>
      _ResearchWorkspaceViewState();
}

class _ResearchWorkspaceViewState extends ConsumerState<ResearchWorkspaceView> {
  final _boardPlacements = <String, Map<String, CanvasElement>>{};
  final compare = <String>{};
  String? message;
  bool busy = false;
  int tablePage = 0;
  String? transientLayout;
  @override
  void didUpdateWidget(covariant ResearchWorkspaceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.view.id != widget.view.id) {
      compare.clear();
      transientLayout = null;
      tablePage = 0;
      message = null;
      _boardPlacements.clear();
    }
  }

  WorkspaceController get c => widget.controller;
  UniversalObject get view => c.find(widget.view.id) ?? widget.view;
  bool get editable =>
      !view.isReadOnly &&
      !view.isDeleted &&
      !c.repository.readOnly &&
      view.properties['researchVersion'] == 1;
  List<Map<String, dynamic>> get entries {
    final raw = view.properties['referenceEntries'];
    return raw is List
        ? [
            for (final e in raw)
              if (e is Map && e['objectId'] is String)
                Map<String, dynamic>.from(e),
          ]
        : [];
  }

  Map<String, dynamic> currentEntry(Map<String, dynamic> e) {
    if (e['boardId'] == null || e['localCommentary'] == true) {
      return e;
    }
    final board = c.find(e['boardId']?.toString() ?? '');
    if (board == null || board.isDeleted || board.typeId != 'orbit.canvas') {
      return {...e, '_boardUnavailable': true};
    }
    final placement = _boardPlacements.putIfAbsent(
      board.id,
      () => {
        for (final p in CanvasScene.fromJson(board.data).elements) p.id: p,
      },
    )[e['placementId']];
    if (placement?.data['objectId'] != e['objectId']) {
      return {...e, '_boardUnavailable': true};
    }
    if (placement == null) {
      return {...e, '_boardUnavailable': true};
    }
    if (e['localCommentary'] == true) return e;
    return {
      ...e,
      for (final key in [
        'referenceCaption',
        'referenceTags',
        'referenceStatus',
        'referenceSourceUrl',
      ])
        if (placement.data[key] != null) key: placement.data[key],
    };
  }

  Future<void> save(Map<String, dynamic> changes) async {
    if (!editable || busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    final id = view.id;
    final properties = {...view.properties, ...changes};
    try {
      validateResearchProperties(properties);
    } on Object catch (e) {
      setState(() {
        busy = false;
        message = '$e';
      });
      return;
    }
    c.edit(id, properties: properties);
    await c.flush(id);
    if (mounted) {
      setState(() {
        busy = false;
        if (c.dirty.contains(id) || c.failures.containsKey(id)) {
          message = c.failures[id] ?? c.error ?? 'Changes are not saved yet.';
        }
      });
    }
  }

  Future<void> addReferences() async {
    final expected = researchVersion(view);
    final chosen = await pickResearchObjects(
      context,
      c,
      title: 'Add references from any project',
      maxSelection: 5000,
      selected: entries.map((e) => e['objectId'] as String),
      accepts: (o) => o.id != view.id,
    );
    if (chosen == null || !mounted) return;
    if (researchVersion(view) != expected) {
      setState(
        () => message = 'The collection changed. Reopen the source picker.',
      );
      return;
    }
    final existing = {for (final e in entries) e['objectId']: e};
    await save({
      'referenceEntries': [
        for (final id in chosen) existing[id] ?? {'objectId': id},
      ],
    });
  }

  Future<void> importBoard() async {
    final expected = researchVersion(view);
    final ids = await pickResearchObjects(
      context,
      c,
      title: 'Reuse references from boards',
      accepts: (o) => o.typeId == 'orbit.canvas',
    );
    if (ids == null || !mounted) return;
    if (researchVersion(view) != expected) {
      setState(
        () => message = 'The collection changed. Reopen the board picker.',
      );
      return;
    }
    final merged = {for (final e in entries) e['objectId'] as String: e};
    for (final id in ids) {
      for (final e in c.researchBoardEntries(id)) {
        merged.putIfAbsent(e['objectId'] as String, () => e);
      }
    }
    await save({'referenceEntries': merged.values.toList()});
  }

  Future<void> record(String kind, {UniversalObject? existing}) async {
    await showDecisionEditor(
      context,
      c,
      kind: kind,
      record: existing,
      folder: view.properties['folder']?.toString(),
      project: view.properties['project']?.toString(),
      evidence: compare.toList(),
    );
    if (mounted) setState(() {});
  }

  Widget filter(String label, String key, Iterable<String> values) {
    final value = view.properties[key]?.toString() ?? '';
    final options = {'', ...values.where((s) => s.isNotEmpty), value}.toList()
      ..sort();
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String>(
        key: ValueKey('$key:$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final s in options)
            DropdownMenuItem(
              value: s,
              child: Text(
                s.isEmpty
                    ? 'All'
                    : key == 'researchProject'
                    ? (c.find(s)?.title ?? s)
                    : s,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: !editable || busy ? null : (s) => save({key: s}),
      ),
    );
  }

  Widget preview(UniversalObject? source) {
    if (source == null || source.isDeleted) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Source unavailable. The collection link is retained.'),
      );
    }
    final ref = source.properties['contentRef'];
    if ((source.typeId == 'orbit.image' ||
            source.properties['mimeType']?.toString().startsWith('image/') ==
                true) &&
        ref is String) {
      return SizedBox(
        height: 170,
        child: ReadAttachmentImage(
          key: ValueKey(source.id),
          label: source.title,
          revision: source.revision,
          load: () => c.repository.readAttachment(ref),
          onOpenOriginal: () => c.openObject(source.id),
          retryableBuilder: (bytes, retry) => Image.memory(
            bytes,
            fit: BoxFit.contain,
            cacheWidth: 720,
            errorBuilder: (_, _, _) => TextButton(
              onPressed: retry,
              child: const Text('Preview unavailable · Retry'),
            ),
          ),
          builder: (bytes) => Image.memory(bytes, fit: BoxFit.contain),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        source.body.isEmpty
            ? '${source.typeId.replaceFirst('orbit.', '')} · Open the original to inspect this source.'
            : source.body.substring(0, source.body.length.clamp(0, 4000)),
        maxLines: 8,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget card(Map<String, dynamic> raw) {
    final e = currentEntry(raw);
    final id = e['objectId'] as String;
    final o = c.find(id);
    final missing = o == null || o.isDeleted;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: compare.contains(id),
              title: Text(
                missing ? 'Missing source' : o.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(e['referenceStatus']?.toString() ?? 'Inbox'),
              onChanged: !compare.contains(id) && compare.length >= 4
                  ? null
                  : (value) => setState(() {
                      if (value == true) {
                        compare.add(id);
                      } else {
                        compare.remove(id);
                      }
                    }),
            ),
            preview(o),
            if (e['_boardUnavailable'] == true)
              const Text(
                'Board placement unavailable · Showing captured collection details',
              ),
            if (e['referenceCaption']?.toString().isNotEmpty == true)
              Text(e['referenceCaption'].toString()),
            if (e['referenceSourceUrl']?.toString().isNotEmpty == true)
              SelectableText(e['referenceSourceUrl'].toString()),
            if (e['referenceTags'] is List)
              Wrap(
                spacing: 6,
                children: [
                  for (final tag
                      in (e['referenceTags'] as List).whereType<String>())
                    Text('#$tag'),
                ],
              ),
            Wrap(
              spacing: 8,
              children: [
                if (editable)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final expected = researchVersion(view);
                            final retained = RetainedForm.capture(
                              context,
                              'reference:${view.id}:$id',
                              {'id': id, 'type': 'card', ...e},
                            );
                            final result = await showReferenceDetails(
                              context,
                              CanvasElement({'id': id, 'type': 'card', ...e}),
                              o?.title ?? 'Missing source',
                              ownerId: view.id,
                            );
                            if (result == null || !mounted) return;
                            if (researchVersion(view) != expected) {
                              setState(
                                () => message =
                                    'The collection changed while editing. Reopen reference details.',
                              );
                              return;
                            }
                            await save({
                              'referenceEntries': [
                                for (final entry in entries)
                                  if (entry['objectId'] == id)
                                    {
                                      ...entry,
                                      ...result,
                                      'localCommentary': true,
                                    }
                                  else
                                    entry,
                              ],
                            });
                            if (mounted &&
                                !c.dirty.contains(view.id) &&
                                !c.failures.containsKey(view.id)) {
                              await retained?.complete();
                            }
                          },
                    child: const Text('Edit collection details'),
                  ),
                if (editable &&
                    e['localCommentary'] == true &&
                    e['boardId'] != null)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => save({
                            'referenceEntries': [
                              for (final entry in entries)
                                if (entry['objectId'] == id)
                                  {...entry, 'localCommentary': false}
                                else
                                  entry,
                            ],
                          }),
                    child: const Text('Use board details'),
                  ),
                TextButton(
                  onPressed: missing ? null : () => c.openObject(id),
                  child: const Text('Open source'),
                ),
                if (e['boardId'] is String && c.find(e['boardId']) != null)
                  TextButton(
                    onPressed: () => c.openObject(e['boardId'] as String),
                    child: const Text('Open board'),
                  ),
                TextButton(
                  onPressed: () => Clipboard.setData(
                    ClipboardData(
                      text: ObjectReference(
                        id,
                      ).markdown(o?.title ?? 'Missing source'),
                    ),
                  ),
                  child: const Text('Copy link'),
                ),
                if (editable)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            await save({
                              'referenceEntries': entries
                                  .where((e) => e['objectId'] != id)
                                  .toList(),
                            });
                            if (mounted) setState(() => compare.remove(id));
                          },
                    child: const Text('Remove from collection'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget records() {
    final scope = view.properties['project']?.toString() ?? '';
    final folder = view.properties['folder']?.toString() ?? '';
    final list =
        c.activeObjects
            .where(
              (o) =>
                  isResearchRecord(o) &&
                  (scope.isNotEmpty
                      ? o.properties['project'] == scope
                      : folder.isEmpty || o.properties['folder'] == folder),
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'Record a decision or assumption to connect reasoning with evidence.',
        ),
      );
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (_, i) {
        final o = list[i];
        final reasons = researchReviewReasons(o, c.objects);
        final refs = [
          ...researchIds(o.properties['evidenceIds']),
          ...researchIds(o.properties['assumptionIds']),
        ];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(o.title, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '${o.properties['researchKind']} · ${o.properties['researchState']} · ${o.properties['recordedAt'] ?? o.createdAt.toIso8601String()}',
                ),
                Text(
                  'Confidence: ${o.properties['confidence'] ?? 'Unspecified'} · Importance: ${o.properties['importance'] ?? 'Unspecified'}',
                ),
                if (c.getDocumentSnapshots(o.id).isNotEmpty)
                  ExpansionTile(
                    title: const Text('Decision and verification timeline'),
                    children: [
                      for (final checkpoint in c.getDocumentSnapshots(o.id))
                        ListTile(
                          title: Text(
                            checkpoint['label']?.toString() ?? 'Earlier record',
                          ),
                          subtitle: Text(
                            '${checkpoint['timestamp'] ?? ''}\n${checkpoint['title'] ?? ''}',
                          ),
                        ),
                    ],
                  ),
                if (o.properties['reviewedAt'] != null)
                  Text('Last reviewed: ${o.properties['reviewedAt']}'),
                Text(
                  o.body.substring(0, o.body.length.clamp(0, 4000)),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
                for (final reason in reasons)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Review needed · $reason',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final id in refs)
                      ActionChip(
                        label: Text(c.find(id)?.title ?? 'Missing source'),
                        onPressed: c.find(id) == null || c.find(id)!.isDeleted
                            ? null
                            : () => c.openObject(id),
                      ),
                  ],
                ),
                if (researchIds(o.properties['supersedesIds']).isNotEmpty)
                  Text(
                    'Supersedes: ${researchIds(o.properties['supersedesIds']).map((id) => c.find(id)?.title ?? id).join(', ')}',
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => c.openObject(o.id),
                      child: const Text('Open note'),
                    ),
                    TextButton(
                      onPressed:
                          !editable ||
                              o.isReadOnly ||
                              o.properties['researchVersion'] != 1
                          ? null
                          : () => record(
                              o.properties['researchKind'] as String,
                              existing: o,
                            ),
                      child: const Text('Edit record'),
                    ),
                    TextButton(
                      onPressed: () => showDocumentHistoryDialog(
                        context: context,
                        controller: c,
                        objectId: o.id,
                        currentTitle: o.title,
                        currentBody: o.body,
                      ),
                      child: const Text('Revision history'),
                    ),
                    if (o.properties['researchKind'] == 'decision')
                      TextButton(
                        onPressed: !editable || o.isReadOnly || busy
                            ? null
                            : () async {
                                final ok = await c.reviewResearchDecision(o.id);
                                if (mounted) {
                                  setState(
                                    () => message = ok
                                        ? 'Reviewed current source versions. Missing or disproved assumptions still need attention.'
                                        : c.error ??
                                              'Review could not be saved.',
                                  );
                                }
                              },
                        child: const Text('Mark reviewed'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget brief() {
    final id = view.properties['briefId']?.toString();
    final source = id == null ? null : c.find(id);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Project brief',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (editable)
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        final ids = await pickResearchObjects(
                          context,
                          c,
                          title: 'Link a project brief',
                          maxSelection: 1,
                          accepts: (o) => o.typeId == 'orbit.note',
                        );
                        if (ids != null && mounted) {
                          await save({'briefId': ids.firstOrNull});
                        }
                      },
                child: const Text('Choose brief'),
              ),
            if (source == null || source.isDeleted)
              const Text(
                'Link an existing brief to keep the project goal beside its evidence.',
              )
            else ...[
              TextButton(
                onPressed: () => c.openObject(source.id),
                child: Text(source.title),
              ),
              MarkdownBody(
                data: source.body,
                selectable: true,
                imageBuilder: (_, title, alt) =>
                    Text(alt ?? title ?? 'Image · Open brief to view'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(workspaceProvider);
    _boardPlacements.clear();
    try {
      validateResearchProperties(view.properties);
    } on Object catch (e) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '$e\nThe saved collection is preserved; no entries have been removed.',
          ),
        ),
      );
    }
    if (view.properties['researchVersion'] != 1) {
      return const Center(
        child: Text(
          'Unsupported research collection. Its saved data is preserved.',
        ),
      );
    }
    if (!researchLayouts.contains(view.properties['researchLayout'])) {
      return const Center(
        child: Text(
          'Unsupported research layout. Its saved data is preserved.',
        ),
      );
    }
    final layout =
        transientLayout ?? view.properties['researchLayout']!.toString();
    final all = entries.map(currentEntry).toList();
    final filtered = all.where((e) {
      final o = c.find(e['objectId'] as String);
      bool matches(String key, dynamic value) =>
          view.properties[key] == null ||
          view.properties[key] == '' ||
          view.properties[key] == value;
      final query =
          view.properties['researchSearch']?.toString().toLowerCase() ?? '';
      final tag =
          view.properties['researchTag']?.toString().toLowerCase() ?? '';
      return matches('researchType', researchSourceType(o)) &&
          matches('researchStatus', e['referenceStatus'] ?? 'Inbox') &&
          matches('researchProject', o?.properties['project'] ?? '') &&
          '${o?.title ?? ''} ${e['referenceCaption'] ?? ''} ${e['referenceTags'] ?? ''}'
              .toLowerCase()
              .contains(query) &&
          (tag.isEmpty ||
              (e['referenceTags'] is List &&
                  (e['referenceTags'] as List).whereType<String>().any(
                    (s) => s.toLowerCase() == tag,
                  )));
    }).toList();
    final pages = ((filtered.length + 49) ~/ 50).clamp(1, 100);
    tablePage = tablePage.clamp(0, pages - 1);
    Widget content;
    if (layout == 'Decisions') {
      content = records();
    } else if (layout == 'Compare') {
      final selected = all
          .where((e) => compare.contains(e['objectId']))
          .toList();
      content = selected.isEmpty
          ? const Center(
              child: Text(
                'Select up to four references in Gallery or Table, then Compare.',
              ),
            )
          : LayoutBuilder(
              builder: (_, box) => SingleChildScrollView(
                child: Wrap(
                  children: [
                    for (final e in selected)
                      SizedBox(
                        width: box.maxWidth < 600
                            ? box.maxWidth
                            : box.maxWidth / (selected.length.clamp(1, 2)),
                        child: card(e),
                      ),
                  ],
                ),
              ),
            );
    } else if (layout == 'Table') {
      content = SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Source')),
              DataColumn(label: Text('State')),
              DataColumn(label: Text('Caption')),
              DataColumn(label: Text('Tags')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Project')),
            ],
            rows: [
              for (final e in filtered.skip(tablePage * 50).take(50))
                DataRow(
                  selected: compare.contains(e['objectId']),
                  onSelectChanged: (value) => setState(() {
                    if (value == true && compare.length < 4) {
                      compare.add(e['objectId'] as String);
                    } else if (value == false) {
                      compare.remove(e['objectId']);
                    }
                  }),
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 220,
                        child: Text(
                          c.find(e['objectId'])?.title ?? 'Missing source',
                          maxLines: 3,
                        ),
                      ),
                      onTap:
                          c.find(e['objectId']) == null ||
                              c.find(e['objectId'])!.isDeleted
                          ? null
                          : () => c.openObject(e['objectId'] as String),
                    ),
                    DataCell(Text(e['referenceStatus']?.toString() ?? 'Inbox')),
                    DataCell(
                      SizedBox(
                        width: 220,
                        child: Text(
                          e['referenceCaption']?.toString() ?? '',
                          maxLines: 4,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        e['referenceTags'] is List
                            ? (e['referenceTags'] as List).join(', ')
                            : '',
                      ),
                    ),
                    DataCell(Text(researchSourceType(c.find(e['objectId'])))),
                    DataCell(
                      Text(
                        c
                                .find(e['objectId'])
                                ?.properties['projectName']
                                ?.toString() ??
                            c
                                .find(
                                  c
                                          .find(e['objectId'])
                                          ?.properties['project']
                                          ?.toString() ??
                                      '',
                                )
                                ?.title ??
                            'Unassigned',
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    } else {
      content = filtered.isEmpty
          ? Center(
              child: Text(
                all.isEmpty
                    ? 'Add sources or reuse a reference board to begin.'
                    : 'No references match these filters.',
              ),
            )
          : LayoutBuilder(
              builder: (_, box) => ListView.builder(
                itemCount: (filtered.length / (box.maxWidth >= 700 ? 2 : 1))
                    .ceil(),
                itemBuilder: (_, row) {
                  final columns = box.maxWidth >= 700 ? 2 : 1;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var j = 0; j < columns; j++)
                        Expanded(
                          child: row * columns + j < filtered.length
                              ? card(filtered[row * columns + j])
                              : const SizedBox(),
                        ),
                    ],
                  );
                },
              ),
            );
    }
    return LayoutBuilder(
      builder: (context, bounds) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            flex: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    (bounds.maxHeight.isFinite ? bounds.maxHeight : 600) * .4,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        view.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        '${filtered.length} of ${all.length} linked sources · ${compare.length}/4 selected',
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final kind in researchLayouts)
                            ChoiceChip(
                              label: Text(kind),
                              selected: layout == kind,
                              onSelected: busy
                                  ? null
                                  : (_) => editable
                                        ? save({'researchLayout': kind})
                                        : setState(
                                            () => transientLayout = kind,
                                          ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: editable && !busy ? addReferences : null,
                            icon: const Icon(Icons.add_link),
                            label: const Text('Add references'),
                          ),
                          OutlinedButton(
                            onPressed: editable && !busy ? importBoard : null,
                            child: const Text('Reuse board references'),
                          ),
                          OutlinedButton(
                            onPressed: editable && !busy
                                ? () => record('decision')
                                : null,
                            child: const Text('New decision'),
                          ),
                          OutlinedButton(
                            onPressed: editable && !busy
                                ? () => record('assumption')
                                : null,
                            child: const Text('New assumption'),
                          ),
                          TextButton(
                            onPressed: () => Clipboard.setData(
                              ClipboardData(
                                text: '```orbit-view\nview: ${view.id}\n```',
                              ),
                            ),
                            child: const Text('Copy live embed'),
                          ),
                          TextButton(
                            onPressed: compare.isEmpty
                                ? null
                                : () => setState(compare.clear),
                            child: const Text('Clear selection'),
                          ),
                          if (layout == 'Table') ...[
                            TextButton(
                              onPressed: tablePage == 0
                                  ? null
                                  : () => setState(() => tablePage--),
                              child: const Text('Previous page'),
                            ),
                            Text('Page ${tablePage + 1} of $pages'),
                            TextButton(
                              onPressed: tablePage + 1 >= pages
                                  ? null
                                  : () => setState(() => tablePage++),
                              child: const Text('Next page'),
                            ),
                          ],
                          if (editable)
                            TextButton(
                              onPressed: () => save({
                                'researchSearch': '',
                                'researchTag': '',
                                'researchType': '',
                                'researchStatus': '',
                                'researchProject': '',
                              }),
                              child: const Text('Reset filters'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            width: 220,
                            child: TextFormField(
                              key: ValueKey(
                                'search:${view.properties['researchSearch']}',
                              ),
                              initialValue:
                                  view.properties['researchSearch']
                                      ?.toString() ??
                                  '',
                              enabled: editable && !busy,
                              decoration: const InputDecoration(
                                labelText: 'Search references · Enter',
                              ),
                              onFieldSubmitted: (s) =>
                                  save({'researchSearch': s}),
                            ),
                          ),
                          filter(
                            'Source type',
                            'researchType',
                            all.map(
                              (e) => researchSourceType(c.find(e['objectId'])),
                            ),
                          ),
                          filter(
                            'Review state',
                            'researchStatus',
                            all.map(
                              (e) =>
                                  e['referenceStatus']?.toString() ?? 'Inbox',
                            ),
                          ),
                          filter(
                            'Tag',
                            'researchTag',
                            all.expand(
                              (e) => e['referenceTags'] is List
                                  ? (e['referenceTags'] as List)
                                        .whereType<String>()
                                  : <String>[],
                            ),
                          ),
                          filter(
                            'Project',
                            'researchProject',
                            all.map(
                              (e) =>
                                  c
                                      .find(e['objectId'])
                                      ?.properties['project']
                                      ?.toString() ??
                                  '',
                            ),
                          ),
                        ],
                      ),
                      if (message != null)
                        Text(
                          message!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (_, box) => box.maxWidth >= 1000
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: content),
                        SizedBox(width: 300, child: brief()),
                      ],
                    )
                  : Column(
                      children: [
                        TextButton(
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Project brief'),
                              content: SizedBox(
                                width: 600,
                                height: MediaQuery.sizeOf(context).height * .5,
                                child: brief(),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          ),
                          child: const Text('Project brief'),
                        ),
                        Expanded(child: content),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
