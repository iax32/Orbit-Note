import 'dart:convert';
import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../app/workspace_controller.dart';
import '../../domain/smart_view_query.dart';
import '../../domain/calendar_event.dart';
import '../../domain/universal_object.dart';
import 'calendar_view.dart';
import 'timeline_view.dart';
import 'gantt_view.dart';

Future<void> showSmartQueryBuilder(
  BuildContext context,
  WorkspaceController c,
  UniversalObject view,
) async {
  final raw = view.properties['smartQuery'];
  final draft = raw is Map
      ? Map<String, dynamic>.from(jsonDecode(jsonEncode(raw)) as Map)
      : SmartViewQuery.empty();
  try {
    SmartViewQuery(draft);
  } on Object {
    return;
  }
  final rules = (draft['rules'] as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();
  String? error;
  bool saving = false;
  var nextKey = 0;
  final keys = [for (final _ in rules) nextKey++];
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => OrbitDialog(
        maxWidth: 720,
        title: Text('Filters · ${view.title}'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'This definition is shared by its table, board, dashboard and embeds. Missing values remain absent.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: draft['match'] as String,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Match'),
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Text('All filters (AND)'),
                ),
                DropdownMenuItem(value: 'any', child: Text('Any filter (OR)')),
              ],
              onChanged: saving ? null : (v) => draft['match'] = v,
            ),
            for (var i = 0; i < rules.length; i++)
              Padding(
                key: ValueKey(keys[i]),
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      initialValue: rules[i]['field'] as String,
                      decoration: InputDecoration(
                        labelText: 'Property ${i + 1}',
                        helperText:
                            'title, typeId, tags, dueDate, completed, project, or a custom property',
                        suffixIcon: IconButton(
                          tooltip: 'Remove filter ${i + 1}',
                          onPressed: saving
                              ? null
                              : () => set(() {
                                  rules.removeAt(i);
                                  keys.removeAt(i);
                                }),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                      onChanged: saving
                          ? null
                          : (v) => rules[i]['field'] = v.trim(),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: rules[i]['op'] as String,
                      decoration: const InputDecoration(labelText: 'Condition'),
                      isExpanded: true,
                      items: [
                        for (final op in SmartViewQuery.operators)
                          DropdownMenuItem(value: op, child: Text(op)),
                      ],
                      onChanged: saving
                          ? null
                          : (v) => set(() => rules[i]['op'] = v),
                    ),
                    if (!{'empty', 'notEmpty'}.contains(rules[i]['op']))
                      TextFormField(
                        initialValue: '${rules[i]['value'] ?? ''}',
                        decoration: const InputDecoration(
                          labelText: 'Value',
                          helperText:
                              'Dates: YYYY-MM-DD, today, tomorrow, week-end. Relations: object ID.',
                        ),
                        onChanged: saving ? null : (v) => rules[i]['value'] = v,
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: saving || rules.length >= 32
                  ? null
                  : () => set(() {
                      rules.add({
                        'field': 'title',
                        'op': 'contains',
                        'value': '',
                      });
                      keys.add(nextKey++);
                    }),
              icon: const Icon(Icons.add),
              label: const Text('Add filter'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: draft['sort'] as String? ?? 'updatedAt',
              decoration: const InputDecoration(labelText: 'Sort property'),
              onChanged: (v) => draft['sort'] = v.trim(),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Descending order'),
              value: draft['descending'] == true,
              onChanged: saving
                  ? null
                  : (v) => set(() => draft['descending'] = v),
            ),
            TextFormField(
              initialValue: draft['group'] as String? ?? '',
              decoration: const InputDecoration(
                labelText: 'Group / board property',
                hintText: 'status',
              ),
              onChanged: (v) =>
                  draft['group'] = v.trim().isEmpty ? null : v.trim(),
            ),
            TextFormField(
              initialValue:
                  (draft['columns'] as List? ??
                          ['title', 'status', 'priority', 'dueDate'])
                      .join(', '),
              decoration: const InputDecoration(
                labelText: 'Table columns',
                helperText: 'Comma-separated property names',
              ),
              onChanged: (v) => draft['columns'] = v
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toSet()
                  .toList(),
            ),
            const SizedBox(height: 12),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: saving || c.repository.readOnly || view.isReadOnly
                ? null
                : () async {
                    draft['rules'] = rules;
                    try {
                      SmartViewQuery(draft);
                    } on Object catch (e) {
                      set(() => error = '$e');
                      return;
                    }
                    set(() => saving = true);
                    final ok = await c.saveSmartQuery(view, draft);
                    if (!ctx.mounted) return;
                    if (ok) {
                      Navigator.pop(ctx);
                    } else {
                      set(() {
                        saving = false;
                        error = c.error ?? 'Could not save query.';
                      });
                    }
                  },
            child: Text(saving ? 'Saving…' : 'Apply filters'),
          ),
        ],
      ),
    ),
  );
}

class SmartViewSurface extends StatelessWidget {
  const SmartViewSurface({
    super.key,
    required this.controller,
    required this.view,
  });
  final WorkspaceController controller;
  final UniversalObject view;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final v = c.find(view.id) ?? view;
    final issue = c.queryViewIssue(v);
    final objects = issue == null ? c.queryViewObjects(v) : <UniversalObject>[];
    final query = issue == null
        ? SmartViewQuery(
            Map<String, dynamic>.from(v.properties['smartQuery'] as Map),
          )
        : null;
    final kind = v.properties['viewType']?.toString() ?? 'table';
    final knownKind = [
      'list',
      'table',
      'board',
      'gallery',
      'calendar',
      'timeline',
      'gantt',
    ].contains(kind);
    final columns =
        (query?.json['columns'] as List? ??
                ['title', 'status', 'priority', 'dueDate'])
            .whereType<String>()
            .toList();
    final group = query?.json['group'] as String? ?? 'status';
    final groups = <String, List<UniversalObject>>{};
    if (kind == 'board' && group == 'status') {
      for (final status in ['todo', 'in-progress', 'done', 'Unassigned']) {
        groups[status] = [];
      }
    }
    for (final o in objects) {
      groups
          .putIfAbsent(
            '${SmartViewQuery.value(o, group) ?? 'Unassigned'}',
            () => [],
          )
          .add(o);
    }
    final listRows = <Object>[
      if (query?.json['group'] == null)
        ...objects
      else
        for (final entry in groups.entries) ...[entry.key, ...entry.value],
    ];
    return LayoutBuilder(
      builder: (context, bounds) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: bounds.maxHeight * .45),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      v.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      tooltip: 'Rename Smart View',
                      onPressed: c.repository.readOnly || v.isReadOnly
                          ? null
                          : () => _editProperty(context, c, v, 'title'),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    Text('${objects.length} objects'),
                    SizedBox(
                      width: 180,
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: knownKind ? kind : null,
                        hint: Text('Unsupported view: $kind'),
                        items: [
                          for (final k in [
                            'list',
                            'table',
                            'board',
                            'gallery',
                            'calendar',
                            'timeline',
                            'gantt',
                          ])
                            DropdownMenuItem(
                              value: k,
                              child: Text(
                                k,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: c.repository.readOnly || v.isReadOnly
                            ? null
                            : (k) => c.edit(
                                v.id,
                                properties: {...v.properties, 'viewType': k},
                              ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: issue != null
                          ? null
                          : () => showSmartQueryBuilder(context, c, v),
                      icon: const Icon(Icons.filter_list),
                      label: const Text('Filters'),
                    ),
                    IconButton(
                      tooltip: 'Duplicate Smart View',
                      onPressed: c.repository.readOnly
                          ? null
                          : () => c.duplicateView(v.id),
                      icon: const Icon(Icons.copy_outlined),
                    ),
                    if (c.canUndoPlanning)
                      TextButton.icon(
                        onPressed: c.undoPlanning,
                        icon: const Icon(Icons.undo),
                        label: const Text('Undo action'),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: issue != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('$issue\nThe saved definition is preserved.'),
                    ),
                  )
                : !knownKind
                ? const Center(
                    child: Text(
                      'This view kind is unavailable. Choose a supported presentation.',
                    ),
                  )
                : kind == 'calendar'
                ? CalendarView(controller: c, viewObject: v)
                : kind == 'timeline'
                ? TimelineView(controller: c, viewObject: v)
                : kind == 'gantt'
                ? GanttView(controller: c, view: v)
                : objects.isEmpty
                ? const Center(
                    child: Text(
                      'No objects match this query. Change filters to include more.',
                    ),
                  )
                : kind == 'table'
                ? LayoutBuilder(
                    builder: (context, bounds) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: (columns.length * 180.0).clamp(
                          bounds.maxWidth,
                          double.infinity,
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                for (final field in columns)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Text(
                                        field,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: ListView.builder(
                                key: const ValueKey('smart-view-table'),
                                itemCount: objects.length,
                                itemBuilder: (ctx, index) {
                                  final o = objects[index];
                                  return DecoratedBox(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Theme.of(ctx).dividerColor,
                                        ),
                                      ),
                                    ),
                                    child: IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          for (final field in columns)
                                            Expanded(
                                              child: InkWell(
                                                onTap: field == 'title'
                                                    ? () => c.openObject(o.id)
                                                    : () => _editProperty(
                                                        context,
                                                        c,
                                                        o,
                                                        field,
                                                      ),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  child: Text(
                                                    '${SmartViewQuery.value(o, field) ?? '—'}',
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : kind == 'board'
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final entry in groups.entries)
                          SizedBox(
                            width: 280,
                            child: DragTarget<String>(
                              onWillAcceptWithDetails: (d) =>
                                  c.find(d.data)?.isReadOnly == false &&
                                  !c.repository.readOnly &&
                                  !{
                                    'title',
                                    'typeId',
                                    'createdAt',
                                    'updatedAt',
                                  }.contains(group),
                              onAcceptWithDetails: (d) {
                                final o = c.find(d.data);
                                if (o != null) {
                                  final change = {
                                    group: entry.key == 'Unassigned'
                                        ? null
                                        : entry.key,
                                  };
                                  if (o.typeId == 'orbit.task') {
                                    c.configureTask(o, change);
                                  } else {
                                    c.edit(
                                      o.id,
                                      properties: {...o.properties, ...change},
                                    );
                                  }
                                }
                              },
                              builder: (ctx, candidates, rejected) =>
                                  ListView.builder(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: entry.value.length + 1,
                                    itemBuilder: (ctx, index) {
                                      if (index == 0) {
                                        return Text(
                                          '${entry.key} · ${entry.value.length}',
                                          style: Theme.of(
                                            ctx,
                                          ).textTheme.titleMedium,
                                        );
                                      }
                                      final o = entry.value[index - 1];
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Draggable<String>(
                                          data: o.id,
                                          maxSimultaneousDrags:
                                              c.repository.readOnly ||
                                                  o.isReadOnly
                                              ? 0
                                              : 1,
                                          feedback: Material(
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Text(o.title),
                                            ),
                                          ),
                                          child: Card(
                                            child: ListTile(
                                              title: Text(o.title),
                                              onTap: () => c.openObject(o.id),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                            ),
                          ),
                      ],
                    ),
                  )
                : kind == 'gallery'
                ? LayoutBuilder(
                    builder: (ctx, bounds) => GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: (bounds.maxWidth / 280).floor().clamp(
                          1,
                          6,
                        ),
                        mainAxisExtent: 200,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: objects.length,
                      itemBuilder: (ctx, index) {
                        final o = objects[index];
                        return Card(
                          child: InkWell(
                            onTap: () => c.openObject(o.id),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    o.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(ctx).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: Text(
                                      o.body.isEmpty
                                          ? '${o.properties['status'] ?? o.typeId}'
                                          : o.body,
                                      overflow: TextOverflow.fade,
                                    ),
                                  ),
                                  Text(
                                    o.typeId,
                                    style: Theme.of(ctx).textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: listRows.length,
                    itemBuilder: (ctx, index) {
                      final row = listRows[index];
                      if (row is String) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            row,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        );
                      }
                      final o = row as UniversalObject;
                      return ListTile(
                        title: Text(o.title),
                        subtitle: Text('${o.properties['status'] ?? o.typeId}'),
                        onTap: () => c.openObject(o.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

Future<void> _editProperty(
  BuildContext context,
  WorkspaceController c,
  UniversalObject object,
  String field,
) async {
  if (object.isReadOnly ||
      c.repository.readOnly ||
      {'typeId', 'createdAt', 'updatedAt'}.contains(field) ||
      field.startsWith('relation:')) {
    return;
  }
  final old = SmartViewQuery.value(object, field);
  if (old != null && old is! String && old is! num && old is! bool) return;
  var text = '${old ?? ''}';
  String? error;
  bool busy = false;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => OrbitDialog(
        title: Text('Edit $field'),
        content: Column(
          children: [
            TextFormField(
              initialValue: text,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Value'),
              onChanged: (v) => text = v,
            ),
            if (error != null) Text(error!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    dynamic value = text.trim().isEmpty ? null : text;
                    if (old is num) {
                      value = num.tryParse(text);
                      if (value == null || !value.isFinite) {
                        set(() => error = 'Enter a finite number.');
                        return;
                      }
                    }
                    if (old is bool || field == 'completed') {
                      if (!['true', 'false'].contains(text.toLowerCase())) {
                        set(() => error = 'Enter true or false.');
                        return;
                      }
                      value = text.toLowerCase() == 'true';
                    }
                    if (field.endsWith('Date') &&
                        value != null &&
                        parseCalendarDate(text) == null) {
                      set(() => error = 'Use YYYY-MM-DD.');
                      return;
                    }
                    if (!identical(c.find(object.id), object)) {
                      set(
                        () => error = 'This object changed. Reopen the editor.',
                      );
                      return;
                    }
                    set(() => busy = true);
                    if (object.typeId == 'orbit.task' && field != 'title') {
                      final ok = await c.configureTask(object, {field: value});
                      if (!ctx.mounted) return;
                      if (!ok) {
                        set(() {
                          busy = false;
                          error = c.error;
                        });
                        return;
                      }
                    } else {
                      c.edit(
                        object.id,
                        title: field == 'title' ? text : null,
                        properties: field == 'title'
                            ? null
                            : {...object.properties, field: value},
                      );
                      await c.flush(object.id);
                      if (c.dirty.contains(object.id)) {
                        if (ctx.mounted) {
                          set(() {
                            busy = false;
                            error =
                                c.error ??
                                'Save failed; the draft is retained.';
                          });
                        }
                        return;
                      }
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
