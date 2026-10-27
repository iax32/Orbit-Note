import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../app/workspace_controller.dart';
import '../../domain/research_dossier.dart';
import '../../domain/universal_object.dart';
import '../../domain/object_reference.dart';
import '../../domain/note_composition.dart';
import '../../domain/wiki_links.dart';
import '../notes/rich/markdown_document.dart';
import '../notes/note_link_dialog.dart';
import 'research_comparison_dialog.dart';

Future<void> showResearchDossier(
  BuildContext context,
  WorkspaceController controller,
) => showDialog<void>(
  context: context,
  builder: (_) => RepaintBoundary(
    key: const ValueKey('dossier-capture'),
    child: ResearchDossierWorkspace(controller: controller),
  ),
);

class ResearchDossierWorkspace extends ConsumerStatefulWidget {
  const ResearchDossierWorkspace({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  ConsumerState<ResearchDossierWorkspace> createState() => _DossierState();
}

class _DossierState extends ConsumerState<ResearchDossierWorkspace> {
  WorkspaceController get c => widget.controller;
  late final generation = c.workspaceGeneration;
  String? rootId, selectedId, message;
  String query = '', kind = 'all', state = 'all', buildFilter = '';
  final _search = TextEditingController(),
      _buildFilter = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    _buildFilter.dispose();
    super.dispose();
  }

  bool reviewOnly = false, busy = false;
  int limit = 50;
  bool get current => generation == c.workspaceGeneration && c.hasWorkspace;
  Future<void> edit(
    String type, {
    UniversalObject? previous,
    String? template,
  }) async {
    final saved = await showDossierEditor(
      context,
      c,
      kind: type,
      rootId: rootId,
      previous: previous,
      template: template,
    );
    if (!mounted || !current || saved == null) return;
    setState(() {
      selectedId = saved.id;
      if (type == 'dossier') {
        rootId = saved.id;
      } else {
        rootId = dossierData(saved)['dossierId'];
      }
      kind = state = 'all';
      query = buildFilter = '';
      _search.clear();
      _buildFilter.clear();
      reviewOnly = false;
      limit = 50;
    });
  }

  Future<void> copy(String text, String notice) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted && current) setState(() => message = notice);
    } catch (e) {
      if (mounted && current) setState(() => message = 'Could not copy: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(workspaceProvider);
    if (!current) {
      return AlertDialog(
        title: const Text('Research dossier'),
        content: const Text(
          'The Vault changed. Close and reopen this workspace.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }
    final all = c.activeObjects.where(isDossierRecord).toList();
    final roots = all.where((o) => dossierData(o)['kind'] == 'dossier').toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    rootId ??= roots.firstOrNull?.id;
    final root = roots.where((o) => o.id == rootId).firstOrNull;
    final scoped = all
        .where((o) => o.id == rootId || dossierData(o)['dossierId'] == rootId)
        .toList();
    final lookup = c.objects;
    final filtered =
        scoped.where((o) {
          final d = dossierData(o);
          return (kind == 'all' || d['kind'] == kind) &&
              (state == 'all' || d['state'] == state) &&
              (buildFilter.isEmpty ||
                  '${d['build'] ?? ''}'.toLowerCase().contains(
                    buildFilter.toLowerCase(),
                  )) &&
              (query.isEmpty ||
                  '${o.title} ${d['summary']} ${d['symbol']} ${d['address']} ${d['aliases']}'
                      .toLowerCase()
                      .contains(query.toLowerCase())) &&
              (!reviewOnly || dossierWarnings(o, lookup).isNotEmpty);
        }).toList()..sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
    final selected =
        scoped.where((o) => o.id == selectedId).firstOrNull ?? root;
    Widget records() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${filtered.length} records · ${scoped.where((o) => dossierData(o)['state'] == 'confirmed').length} confirmed',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        for (final o in filtered.take(limit))
          Card(
            child: ListTile(
              selected: selected?.id == o.id,
              title: Text(o.title),
              subtitle: Text(
                '${dossierData(o)['kind']} · ${dossierData(o)['state']} · ${dossierData(o)['build'] ?? ''}',
              ),
              onTap: () => setState(() => selectedId = o.id),
            ),
          ),
        if (filtered.length > limit)
          TextButton(
            onPressed: () => setState(() => limit += 50),
            child: const Text('Show more records'),
          ),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No matching research. Create a record or adjust the filters.',
            ),
          ),
      ],
    );
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: SizedBox(
        width: 1280,
        height: 860,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.manage_search_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Research dossiers',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close research dossiers',
                    onPressed: busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Connected notes for functions, structures, offsets and evidence. Observations stay yours.',
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            SizedBox(
                              width: box.maxWidth.clamp(0, 400),
                              child: DropdownButtonFormField<String>(
                                key: ValueKey(root?.id),
                                initialValue: root?.id,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Dossier',
                                ),
                                items: [
                                  for (final r in roots)
                                    DropdownMenuItem(
                                      value: r.id,
                                      child: Text(
                                        r.title,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (v) => setState(() {
                                  rootId = v;
                                  selectedId = null;
                                  limit = 50;
                                }),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => edit('dossier'),
                              icon: const Icon(
                                Icons.create_new_folder_outlined,
                              ),
                              label: const Text('New dossier'),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'New research record',
                              enabled: root != null,
                              onSelected: (v) => edit(v),
                              itemBuilder: (_) => [
                                for (final k in dossierKinds.where(
                                  (k) => k != 'dossier',
                                ))
                                  PopupMenuItem(
                                    value: k,
                                    child: Text('New $k'),
                                  ),
                              ],
                              child: const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('+ New record'),
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Research templates',
                              enabled: root != null,
                              onSelected: (v) => edit('journal', template: v),
                              itemBuilder: (_) => [
                                for (final t in dossierTemplates.keys)
                                  PopupMenuItem(value: t, child: Text(t)),
                              ],
                              child: const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('Templates'),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: root == null
                                  ? null
                                  : () => showResearchComparison(
                                      context,
                                      c,
                                      matchesScope: (o) =>
                                          dossierData(o)['dossierId'] ==
                                          root.id,
                                      folder:
                                          '${root.properties['folder'] ?? 'Research dossiers'}',
                                      target: root.title,
                                    ),
                              icon: const Icon(Icons.compare_arrows),
                              label: const Text('Compare recorded builds'),
                            ),
                            OutlinedButton.icon(
                              onPressed: root == null || busy
                                  ? null
                                  : () async {
                                      if (busy) return;
                                      setState(() => busy = true);
                                      try {
                                        final board = await c.createDossierMap(
                                          root.id,
                                        );
                                        if (mounted && current) {
                                          setState(
                                            () => message = board == null
                                                ? c.error
                                                : 'Research map created. Open it from your notes list.',
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted && current) {
                                          setState(() => message = '$e');
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() => busy = false);
                                        }
                                      }
                                    },
                              icon: const Icon(Icons.account_tree_outlined),
                              label: const Text('Create Canvas map'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(
                              width: box.maxWidth.clamp(0, 290),
                              child: TextField(
                                controller: _search,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Find name, symbol, address or alias',
                                  prefixIcon: Icon(Icons.search),
                                ),
                                onChanged: (v) => setState(() {
                                  query = v;
                                  limit = 50;
                                }),
                              ),
                            ),
                            SizedBox(
                              width: 170,
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: kind,
                                key: ValueKey('kind-$kind'),
                                decoration: const InputDecoration(
                                  labelText: 'Record type',
                                ),
                                items: [
                                  for (final k in ['all', ...dossierKinds])
                                    DropdownMenuItem(value: k, child: Text(k)),
                                ],
                                onChanged: (v) =>
                                    setState(() => kind = v ?? 'all'),
                              ),
                            ),
                            SizedBox(
                              width: 170,
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: state,
                                key: ValueKey('state-$state'),
                                decoration: const InputDecoration(
                                  labelText: 'Review state',
                                ),
                                items: [
                                  for (final s in ['all', ...dossierStates])
                                    DropdownMenuItem(value: s, child: Text(s)),
                                ],
                                onChanged: (v) =>
                                    setState(() => state = v ?? 'all'),
                              ),
                            ),
                            SizedBox(
                              width: 170,
                              child: TextField(
                                controller: _buildFilter,
                                decoration: const InputDecoration(
                                  labelText: 'Recorded build filter',
                                ),
                                onChanged: (v) =>
                                    setState(() => buildFilter = v),
                              ),
                            ),
                            FilterChip(
                              label: const Text('Needs review'),
                              selected: reviewOnly,
                              onSelected: (v) => setState(() => reviewOnly = v),
                            ),
                          ],
                        ),
                        if (message != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: SelectableText(message!),
                          ),
                        const SizedBox(height: 16),
                        if (box.maxWidth >= 900)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 310, child: records()),
                              const SizedBox(width: 18),
                              Expanded(child: detail(selected)),
                            ],
                          )
                        else ...[
                          records(),
                          const Divider(),
                          detail(selected),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget detail(UniversalObject? record) {
    if (record == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Create a dossier for a game, subsystem or research project. Add evidence as you investigate; nothing is inferred or marked verified automatically.',
        ),
      );
    }
    final d = dossierData(record),
        warnings = dossierWarnings(record, c.objects);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(record.title, style: Theme.of(context).textTheme.headlineSmall),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            OutlinedButton.icon(
              onPressed: () => edit(d['kind'], previous: record),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit research'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                c.openObject(record.id);
              },
              child: const Text('Open note'),
            ),
            TextButton(
              onPressed: () => copy(
                ObjectReference(record.id).markdown(record.title),
                'Live reference copied. Paste into a note or Canvas.',
              ),
              child: const Text('Copy reference'),
            ),
            TextButton(
              onPressed: () => copy(
                dossierLiveEmbed(record),
                'Live summary copied. Paste into a note; changes follow the source.',
              ),
              child: const Text('Copy live summary'),
            ),
          ],
        ),
        for (final w in warnings)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(w)),
              ],
            ),
          ),
        const SizedBox(height: 10),
        preview(record.body),
        if (dossierRows(d, 'links').isNotEmpty) ...[
          const Divider(),
          Text(
            'Connected evidence',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final link in dossierRows(d, 'links'))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.find(link['id'])?.title ?? 'Missing source'),
              subtitle: Text('${link['role']} · ${link['offset'] ?? ''}'),
              trailing: const Icon(Icons.open_in_new),
              onTap: c.find(link['id'])?.isDeleted != false
                  ? null
                  : () {
                      Navigator.pop(context);
                      c.openObject(link['id']);
                    },
            ),
        ],
        ExpansionTile(
          title: const Text('Review history'),
          children: [
            for (final h in dossierRows(d, 'history').reversed)
              ListTile(
                title: Text('${h['state']} · ${h['build'] ?? ''}'),
                subtitle: Text(
                  '${h['at']} · sources reviewed: ${h['reviewedSources']}',
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget markdown(String source) {
    var display = source;
    for (final link in parseWikiLinks(source).reversed) {
      final ref = ObjectReference.parse(link.target),
          target = c.find(ObjectReference.parse(link.target).id);
      if (target != null && link.label == link.target) {
        display = display.replaceRange(
          link.start,
          link.end,
          ref.markdown(target.title),
        );
      }
    }
    return MarkdownBody(
      data: wikiLinksToMarkdown(display, c.linkTargets),
      styleSheet: MarkdownStyleSheet.fromTheme(
        Theme.of(context),
      ).copyWith(a: TextStyle(color: Theme.of(context).colorScheme.primary)),
      selectable: true,
      onTapLink: (text, href, title) {
        if (href == null || !href.startsWith('orbit-object:')) return;
        final target = ObjectReference.parse(
          href.substring('orbit-object:'.length),
        );
        if (c.find(target.id)?.isDeleted == false) {
          Navigator.pop(context);
          c.openObject(target.id);
        }
      },
    );
  }

  Widget preview(String body) {
    final widgets = <Widget>[], pending = StringBuffer();
    void flush() {
      if (pending.isNotEmpty) {
        widgets.add(markdown(pending.toString()));
        pending.clear();
      }
    }

    for (final block in MarkdownDocument.parse(body).blocks) {
      final columns = NoteColumns.parse(block.source);
      if (columns == null) {
        pending.write(block.source);
        continue;
      }
      flush();
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: LayoutBuilder(
            builder: (context, box) => box.maxWidth >= 580
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < columns.parts.length; i++) ...[
                        if (i > 0) const SizedBox(width: 20),
                        Expanded(child: markdown(columns.parts[i])),
                      ],
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final part in columns.parts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: markdown(part),
                        ),
                    ],
                  ),
          ),
        ),
      );
    }
    flush();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }
}

Future<UniversalObject?> showDossierEditor(
  BuildContext context,
  WorkspaceController c, {
  required String kind,
  String? rootId,
  UniversalObject? previous,
  String? template,
}) async {
  final generation = c.workspaceGeneration;
  final original = previous == null
      ? <String, dynamic>{}
      : dossierData(previous);
  final root = rootId == null ? null : c.find(rootId);
  final defaultBuild = root == null ? '' : dossierData(root)['build'] ?? '';
  final fields = <String, TextEditingController>{
    for (final key in [
      'title',
      'summary',
      'build',
      'symbol',
      'module',
      'moduleId',
      'address',
      'convention',
      'prototype',
      'parameters',
      'returns',
      'aliases',
      'notes',
    ])
      key: TextEditingController(
        text: key == 'title'
            ? previous?.title ?? template ?? ''
            : key == 'notes'
            ? template == null
                  ? ''
                  : dossierTemplates[template]
            : '${original[key] ?? (key == 'build' ? defaultBuild : '')}',
      ),
  };
  var state = '${original['state'] ?? 'suspected'}',
      confidence = '${original['confidence'] ?? 'low'}',
      space = '${original['addressSpace'] ?? 'rva'}';
  final rowControllers = <Map<String, TextEditingController>>[];
  var rowPage = 0;
  final rowExtras =
      <Map<String, TextEditingController>, Map<String, dynamic>>{};
  final retired = <TextEditingController>[];
  final columns = dossierColumns[kind] ?? const <String>[];
  void addRow([Map<String, dynamic> row = const {}]) {
    final controllers = {
      for (final col in columns)
        col: TextEditingController(text: '${row[col] ?? ''}'),
    };
    rowControllers.add(controllers);
    rowExtras[controllers] = row;
  }

  for (final r in dossierRows(original, 'rows')) {
    addRow(r);
  }
  final links = dossierRows(original, 'links');
  String? error;
  bool saving = false, review = false;
  var role = 'evidence';
  UniversalObject? result;
  late DialogRoute<UniversalObject> route;
  try {
    route = DialogRoute<UniversalObject>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, set) {
          Widget field(String key, String label, {int lines = 1}) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: fields[key],
              maxLines: lines,
              enabled: !saving,
              decoration: InputDecoration(labelText: label),
            ),
          );
          return PopScope(
            canPop: !saving,
            child: AlertDialog(
              title: Text(previous == null ? 'New $kind' : 'Edit $kind'),
              content: SizedBox(
                width: 820,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      field('title', 'Title'),
                      field(
                        'build',
                        kind == 'dossier'
                            ? 'Current game build / version'
                            : 'Recorded game build / version',
                      ),
                      field(
                        'summary',
                        kind == 'glossary'
                            ? 'Definition'
                            : kind == 'hypothesis'
                            ? 'Hypothesis / statement'
                            : 'Summary',
                        lines: 3,
                      ),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: state,
                        decoration: const InputDecoration(
                          labelText: 'Research state',
                        ),
                        items: [
                          for (final s in dossierStates)
                            DropdownMenuItem(value: s, child: Text(s)),
                        ],
                        onChanged: saving ? null : (v) => set(() => state = v!),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: confidence,
                        decoration: const InputDecoration(
                          labelText: 'Confidence',
                        ),
                        items: [
                          for (final s in ['low', 'medium', 'high'])
                            DropdownMenuItem(value: s, child: Text(s)),
                        ],
                        onChanged: saving
                            ? null
                            : (v) => set(() => confidence = v!),
                      ),
                      const SizedBox(height: 12),
                      if ([
                        'function',
                        'structure',
                        'offset',
                      ].contains(kind)) ...[
                        field('symbol', 'Symbol / field name'),
                        field('module', 'Module / owning structure'),
                        field(
                          'moduleId',
                          'Stable module identity (for build comparison)',
                        ),
                        field('address', 'Address / offset (hex, optional)'),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: space,
                          decoration: const InputDecoration(
                            labelText: 'Address space',
                          ),
                          items: [
                            for (final s in ['rva', 'virtual', 'file', 'field'])
                              DropdownMenuItem(value: s, child: Text(s)),
                          ],
                          onChanged: saving
                              ? null
                              : (v) => set(() => space = v!),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (kind == 'function') ...[
                        field('convention', 'Calling convention (recorded)'),
                        field('prototype', 'Function signature'),
                        field('parameters', 'Parameters and types', lines: 2),
                        field(
                          'returns',
                          'Return value and side effects',
                          lines: 2,
                        ),
                      ],
                      if (kind == 'glossary')
                        field('aliases', 'Aliases / abbreviations'),
                      if (columns.isNotEmpty) ...[
                        Text(
                          kind == 'structure'
                              ? 'Memory layout · offsets in hex, sizes in decimal bytes'
                              : kind == 'function'
                              ? 'Instruction annotations · recorded text only'
                              : 'Experiment observations',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (rowControllers.length > 12)
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              TextButton(
                                onPressed: saving || rowPage == 0
                                    ? null
                                    : () => set(() => rowPage--),
                                child: const Text('Previous rows'),
                              ),
                              Text(
                                'Page ${rowPage + 1} of ${(rowControllers.length + 11) ~/ 12}',
                              ),
                              TextButton(
                                onPressed:
                                    saving ||
                                        (rowPage + 1) * 12 >=
                                            rowControllers.length
                                    ? null
                                    : () => set(() => rowPage++),
                                child: const Text('Next rows'),
                              ),
                            ],
                          ),
                        for (
                          var i = rowPage * 12;
                          i < rowControllers.length && i < (rowPage + 1) * 12;
                          i++
                        )
                          Card(
                            key: ObjectKey(rowControllers[i]),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text('Row ${i + 1}')),
                                      IconButton(
                                        tooltip: 'Remove row ${i + 1}',
                                        onPressed: saving
                                            ? null
                                            : () => set(() {
                                                retired.addAll(
                                                  rowControllers
                                                      .removeAt(i)
                                                      .values,
                                                );
                                                if (rowPage * 12 >=
                                                    rowControllers.length) {
                                                  rowPage =
                                                      rowControllers.isEmpty
                                                      ? 0
                                                      : (rowControllers.length -
                                                                1) ~/
                                                            12;
                                                }
                                              }),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                  for (final col in columns)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: TextField(
                                        controller: rowControllers[i][col],
                                        enabled: !saving,
                                        maxLines:
                                            col == 'explanation' ||
                                                col == 'observation'
                                            ? 2
                                            : 1,
                                        decoration: InputDecoration(
                                          labelText: col,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: saving || rowControllers.length >= 500
                              ? null
                              : () => set(() {
                                  addRow();
                                  rowPage = (rowControllers.length - 1) ~/ 12;
                                }),
                          icon: const Icon(Icons.add),
                          label: const Text('Add recorded row'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Evidence and relationships',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: role,
                        decoration: const InputDecoration(
                          labelText: 'New link role',
                        ),
                        items: [
                          for (final r in dossierRoles)
                            DropdownMenuItem(value: r, child: Text(r)),
                        ],
                        onChanged: saving ? null : (v) => set(() => role = v!),
                      ),
                      for (var i = 0; i < links.length; i++)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            c.find(links[i]['id'])?.title ?? 'Missing source',
                          ),
                          subtitle: Text(
                            '${links[i]['role']} · ${links[i]['offset'] ?? ''}',
                          ),
                          trailing: IconButton(
                            tooltip: 'Remove linked source ${i + 1}',
                            onPressed: saving
                                ? null
                                : () => set(() => links.removeAt(i)),
                            icon: const Icon(Icons.link_off),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: saving || links.length >= 200
                            ? null
                            : () async {
                                final target = await showNoteLinkDialog(
                                  context,
                                  c.linkTargets
                                      .where((t) => t.id != previous?.id)
                                      .toList(),
                                );
                                if (!context.mounted || target == null) return;
                                if (!links.any(
                                  (l) =>
                                      l['id'] == target.id && l['role'] == role,
                                )) {
                                  set(
                                    () => links.add({
                                      'id': target.id,
                                      'role': role,
                                      'offset': '',
                                    }),
                                  );
                                }
                              },
                        icon: const Icon(Icons.add_link),
                        label: const Text('Link evidence / research'),
                      ),
                      if (links.isNotEmpty) ...[
                        const Text(
                          'Pointer/field labels are editable below. Sources retain their recorded revision until explicitly reviewed.',
                        ),
                        for (var i = 0; i < links.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: TextFormField(
                              key: ValueKey(
                                '${links[i]['id']}:${links[i]['role']}',
                              ),
                              initialValue: '${links[i]['offset'] ?? ''}',
                              enabled: !saving,
                              decoration: InputDecoration(
                                labelText:
                                    '${links[i]['role']} · offset / relationship label',
                              ),
                              onChanged: (v) => links[i]['offset'] = v,
                            ),
                          ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'I reviewed the linked sources; acknowledge their current versions',
                          ),
                          value: review,
                          onChanged: saving
                              ? null
                              : (v) => set(() => review = v ?? false),
                        ),
                      ],
                      if (previous == null)
                        field('notes', 'Research notes / template', lines: 7)
                      else
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Use Open note for free writing, screenshots and diagrams. Text outside the structured summary is preserved. The summary itself is refreshed from these fields.',
                          ),
                        ),
                      if (error != null) SelectableText(error!),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (saving) return;
                          set(() {
                            saving = true;
                            error = null;
                          });
                          if (generation != c.workspaceGeneration) {
                            set(() {
                              saving = false;
                              error =
                                  'The Vault changed. Close and reopen this editor.';
                            });
                            return;
                          }
                          final saved = await c.saveDossierRecord(
                            previous: previous,
                            title: fields['title']!.text,
                            notes: fields['notes']!.text,
                            reviewSources: review,
                            data: {
                              ...original,
                              'version': 1,
                              'kind': kind,
                              'state': state,
                              'confidence': confidence,
                              'addressSpace': space,
                              if (kind != 'dossier')
                                'dossierId': original['dossierId'] ?? rootId,
                              for (final key in fields.keys.where(
                                (k) => !['title', 'notes'].contains(k),
                              ))
                                key: fields[key]!.text,
                              'rows': [
                                for (final row in rowControllers)
                                  {
                                    ...?rowExtras[row],
                                    for (final e in row.entries)
                                      e.key: e.value.text,
                                  },
                              ],
                              'links': links,
                            },
                          );
                          if (!context.mounted) return;
                          if (saved == null) {
                            set(() {
                              saving = false;
                              error =
                                  c.error ??
                                  'Could not save. Your draft is still here.';
                            });
                          } else {
                            Navigator.pop(context, saved);
                          }
                        },
                  child: Text(saving ? 'Saving…' : 'Save research'),
                ),
              ],
            ),
          );
        },
      ),
    );
    result = await Navigator.of(context, rootNavigator: true).push(route);
    await route.completed;
  } finally {
    for (final f in fields.values) {
      f.dispose();
    }
    for (final row in rowControllers) {
      for (final f in row.values) {
        f.dispose();
      }
    }
    for (final f in retired) {
      f.dispose();
    }
  }
  return result;
}
