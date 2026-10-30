import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../app/orbit_components.dart';
import '../../app/workspace_controller.dart';
import '../../domain/smart_view_query.dart';
import '../../domain/workspace_context.dart';
import '../../domain/universal_object.dart';
import 'smart_view_surface.dart';
import 'study_workspace.dart';
import 'calendar_planning_workspace.dart';

class ProductivityToolbar extends StatelessWidget {
  const ProductivityToolbar({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      OutlinedButton.icon(
        onPressed: () => showCalendarPlanning(context, controller),
        icon: const Icon(Icons.calendar_month_outlined),
        label: const Text('Calendar planning'),
      ),
      OutlinedButton.icon(
        onPressed: () => showStudyWorkspace(context, controller),
        icon: const Icon(Icons.school_outlined),
        label: const Text('Study & Review'),
      ),
      OutlinedButton.icon(
        onPressed: () => showSpaceManager(context, controller),
        icon: const Icon(Icons.workspaces_outline),
        label: Text(
          controller.activeSpace?['name'] as String? ?? 'Spaces & layouts',
        ),
      ),
      OutlinedButton.icon(
        onPressed: () => showDashboardEditor(context, controller),
        icon: const Icon(Icons.dashboard_customize_outlined),
        label: const Text('Customize dashboard'),
      ),
      OutlinedButton.icon(
        onPressed: controller.repository.readOnly
            ? null
            : () async {
                final view = await controller.create(
                  'orbit.view',
                  title: 'New Smart View',
                  properties: {
                    'viewType': 'table',
                    'smartQuery': SmartViewQuery.empty(),
                  },
                );
                if (view != null && context.mounted) {
                  await showSmartQueryBuilder(context, controller, view);
                }
              },
        icon: const Icon(Icons.filter_alt_outlined),
        label: const Text('New Smart View'),
      ),
    ],
  );
}

Future<void> showSpaceManager(
  BuildContext context,
  WorkspaceController c,
) async {
  await showOrbitDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => OrbitDialog(
        title: const Text('Spaces & layouts'),
        maxWidth: 660,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Spaces restore tabs, panes, reading positions and scope in this Vault. Layouts change pane arrangement. Your content stays in place.',
            ),
            if (c.error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  c.error!,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
              ),
            if (!c.contextsSupported)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'This context library uses an unsupported version. It is preserved; reset the current layout to recover navigation.',
                ),
              ),
            ListTile(
              title: const Text('All Vault'),
              subtitle: const Text(
                'Return to the context before entering a Space',
              ),
              selected: c.activeSpaceId == null,
              onTap: () async {
                if (await c.switchContext(null) && ctx.mounted) set(() {});
              },
            ),
            for (final r in c.savedContexts)
              ListTile(
                title: Text('${r['name']}'),
                subtitle: Text(
                  '${r['kind']} · ${r['project'] ?? r['folder'] ?? 'All objects'}',
                ),
                selected: c.activeSpaceId == r['id'],
                onTap: () async {
                  if (await c.switchContext(r['id'] as String) && ctx.mounted) {
                    set(() {});
                  }
                },
                trailing: PopupMenuButton<String>(
                  popUpAnimationStyle: OrbitMotionScope.popupStyle(context),
                  tooltip: 'Manage ${r['name']}',
                  onSelected: (action) async {
                    if (action == 'duplicate') {
                      await c.duplicateContext(r['id'] as String);
                    }
                    if (action == 'remove') {
                      await c.removeContext(r['id'] as String);
                    }
                    if (action == 'update') {
                      await c.saveContext(
                        name: r['name'] as String,
                        id: r['id'] as String,
                        layoutOnly: r['kind'] == 'layout',
                        project: r['project'] as String?,
                        folder: r['folder'] as String?,
                        appearance: r['appearance'] != null,
                      );
                    }
                    if (action == 'rename' && ctx.mounted) {
                      var name = r['name'] as String;
                      final result = await showOrbitDialog<String>(
                        context: ctx,
                        builder: (d) => OrbitDialog(
                          title: const Text('Rename context'),
                          content: TextFormField(
                            initialValue: name,
                            autofocus: true,
                            maxLength: 100,
                            onChanged: (v) => name = v,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(d),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(d, name),
                              child: const Text('Rename'),
                            ),
                          ],
                        ),
                      );
                      if (result != null) {
                        await c.renameContext(r['id'] as String, result);
                      }
                    }
                    if (ctx.mounted) set(() {});
                  },
                  itemBuilder: (_) => [
                    for (final item in {
                      'rename': 'Rename',
                      'update': 'Replace with current context',
                      'duplicate': 'Duplicate',
                      'remove': 'Remove saved context',
                    }.entries)
                      PopupMenuItem(
                        value: item.key,
                        enabled:
                            !c.repository.readOnly &&
                            c.contextsSupported &&
                            (r['version'] == 1 || item.key == 'remove'),
                        child: Text(item.value),
                      ),
                  ],
                ),
              ),
            if (c.error != null) Text(c.error!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              c.resetLayout();
              set(() {});
            },
            child: const Text('Reset layout'),
          ),
          OutlinedButton(
            onPressed: !c.contextsSupported || c.repository.readOnly
                ? null
                : () async {
                    await _saveSpaceDialog(ctx, c);
                    if (ctx.mounted) set(() {});
                  },
            child: const Text('Save current'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _saveSpaceDialog(
  BuildContext context,
  WorkspaceController c,
) async {
  String name = '', project = '', folder = '';
  bool layout = false, appearance = false, busy = false;
  String? error;
  await showOrbitDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => OrbitDialog(
        title: const Text('Save current context'),
        content: Column(
          children: [
            TextFormField(
              autofocus: true,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (v) => name = v,
            ),
            SwitchListTile(
              title: const Text('Layout only'),
              subtitle: const Text(
                'Save pane arrangement without replacing open tabs',
              ),
              value: layout,
              onChanged: (v) => set(() => layout = v),
            ),
            if (!layout) ...[
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Project / course scope (optional)',
                ),
                onChanged: (v) => project = v.trim(),
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Folder scope (optional)',
                ),
                onChanged: (v) => folder = v.trim(),
              ),
            ],
            SwitchListTile(
              title: const Text('Remember appearance'),
              value: appearance,
              onChanged: (v) => set(() => appearance = v),
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
            onPressed: busy || c.repository.readOnly
                ? null
                : () async {
                    set(() => busy = true);
                    final ok = await c.saveContext(
                      name: name,
                      layoutOnly: layout,
                      project: project.isEmpty ? null : project,
                      folder: folder.isEmpty ? null : folder,
                      appearance: appearance,
                    );
                    if (!ctx.mounted) return;
                    if (ok) {
                      Navigator.pop(ctx);
                    } else {
                      set(() {
                        busy = false;
                        error =
                            c.error ??
                            'Choose a name; up to 30 contexts are supported.';
                      });
                    }
                  },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

Future<void> showDashboardEditor(
  BuildContext context,
  WorkspaceController c,
) async {
  if (c.session.dashboard.isNotEmpty && c.session.dashboard['version'] != 1) {
    return;
  }
  final draft = c.session.dashboard.isEmpty
      ? <String, dynamic>{
          'version': 1,
          'widgets': DashboardDefinition.defaults(),
        }
      : Map<String, dynamic>.from(
          jsonDecode(jsonEncode(c.session.dashboard)) as Map,
        );
  final widgets = (draft['widgets'] as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  String? error;
  bool busy = false;
  await showOrbitDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => OrbitDialog(
        title: const Text('Customize dashboard'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choose widgets and their order. Wide widgets use more columns when there is room. Cancel keeps your current dashboard.',
            ),
            for (var i = 0; i < widgets.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text('${widgets[i]['kind']}'),
                    Wrap(
                      spacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Move widget ${i + 1} up',
                          onPressed: busy || i == 0
                              ? null
                              : () => set(() {
                                  final w = widgets.removeAt(i);
                                  widgets.insert(i - 1, w);
                                }),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          tooltip: 'Move widget ${i + 1} down',
                          onPressed: busy || i == widgets.length - 1
                              ? null
                              : () => set(() {
                                  final w = widgets.removeAt(i);
                                  widgets.insert(i + 1, w);
                                }),
                          icon: const Icon(Icons.arrow_downward),
                        ),
                        SizedBox(
                          width: 130,
                          child: DropdownButton<int>(
                            isExpanded: true,
                            value: widgets[i]['span'] as int,
                            items: [
                              for (final n in [1, 2, 3])
                                DropdownMenuItem(
                                  value: n,
                                  child: Text('$n column${n == 1 ? '' : 's'}'),
                                ),
                            ],
                            onChanged: busy
                                ? null
                                : (v) => set(() => widgets[i]['span'] = v),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove widget ${i + 1}',
                          onPressed: busy
                              ? null
                              : () => set(() => widgets.removeAt(i)),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    if (widgets[i]['kind'] == 'view')
                      DropdownButtonFormField<String>(
                        initialValue:
                            c
                                    .find(widgets[i]['viewId'] as String?)
                                    ?.isDeleted ==
                                false
                            ? widgets[i]['viewId'] as String?
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Saved Smart View',
                        ),
                        isExpanded: true,
                        items: [
                          for (final v
                              in c
                                  .ofType('orbit.view')
                                  .where(
                                    (o) => o.properties['smartQuery'] != null,
                                  ))
                            DropdownMenuItem(value: v.id, child: Text(v.title)),
                        ],
                        onChanged: (v) => widgets[i]['viewId'] = v,
                      ),
                  ],
                ),
              ),
            Wrap(
              spacing: 8,
              children: [
                for (final kind in DashboardDefinition.kinds)
                  OutlinedButton(
                    onPressed: busy || widgets.length >= 16
                        ? null
                        : () => set(
                            () => widgets.add({
                              'id': const Uuid().v4(),
                              'kind': kind,
                              'span': 1,
                            }),
                          ),
                    child: Text('Add $kind'),
                  ),
              ],
            ),
            if (error != null) Text(error!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    if (c.repository.readOnly) return;
                    set(() => busy = true);
                    c.updateSession((s) => s.dashboard = {});
                    await c.saveSession();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
            child: const Text('Restore default Home'),
          ),
          FilledButton(
            onPressed: busy || c.repository.readOnly
                ? null
                : () async {
                    set(() => busy = true);
                    final ok = await c.saveDashboard({
                      ...draft,
                      'widgets': widgets,
                    });
                    if (!ctx.mounted) return;
                    if (ok) {
                      Navigator.pop(ctx);
                    } else {
                      set(() {
                        busy = false;
                        error = c.error ?? 'Could not save dashboard.';
                      });
                    }
                  },
            child: const Text('Apply'),
          ),
        ],
      ),
    ),
  );
}

class ProductivityDashboard extends StatelessWidget {
  const ProductivityDashboard({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    List<Map<String, dynamic>> widgets;
    try {
      final definition = c.session.dashboard.isEmpty
          ? {'version': 1, 'widgets': DashboardDefinition.defaults()}
          : c.session.dashboard;
      DashboardDefinition.validate(definition);
      widgets = (definition['widgets'] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    } on Object {
      return const Text(
        'Dashboard definition unavailable. Reset the layout to restore Home; the stored definition is preserved.',
      );
    }
    return LayoutBuilder(
      builder: (ctx, bounds) {
        final columns = bounds.maxWidth >= 900
            ? 3
            : bounds.maxWidth >= 600
            ? 2
            : 1;
        final unit = (bounds.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final w in widgets)
              SizedBox(
                width:
                    unit * (w['span'] as int).clamp(1, columns) +
                    16 * ((w['span'] as int).clamp(1, columns) - 1),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _widget(context, c, w),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _widget(
    BuildContext context,
    WorkspaceController c,
    Map<String, dynamic> w,
  ) {
    final kind = w['kind'];
    final pool = c.activeObjects.where(c.inActiveSpace).toList();
    UniversalObject? view;
    List<UniversalObject> rows;
    String? issue;
    if (kind == 'view') {
      view = c.find(w['viewId'] as String?);
      if (view == null || view.isDeleted) {
        rows = [];
        issue = 'Saved view is missing. Choose another in Customize dashboard.';
      } else {
        try {
          rows = c.queryViewObjects(view).where(c.inActiveSpace).toList();
        } on Object catch (e) {
          rows = [];
          issue = '$e';
        }
      }
    } else {
      rows = switch (kind) {
        'tasks' =>
          pool
              .where((o) => o.typeId == 'orbit.task' && !o.isCompleted)
              .toList(),
        'projects' =>
          pool
              .where(
                (o) =>
                    o.properties['category'] == 'Project' ||
                    o.typeId == 'orbit.project',
              )
              .toList(),
        'inbox' => c.inboxObjects.where(c.inActiveSpace).toList(),
        'views' => pool.where((o) => o.typeId == 'orbit.view').toList(),
        'recent' => [
          for (final id in c.session.recent)
            if (c.find(id) case final o? when c.inActiveSpace(o)) o,
        ],
        _ => [],
      };
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          view?.title ?? '$kind',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (issue != null)
          Text(issue)
        else if (!DashboardDefinition.kinds.contains(kind))
          const Text(
            'This widget is unavailable. Its configuration is retained.',
          )
        else if (rows.isEmpty)
          const Text('No matching items in this Space.')
        else ...[
          Text('${rows.length} items'),
          for (final o in rows.take(8))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(o.title),
              leading: o.typeId == 'orbit.task'
                  ? Checkbox(
                      value: o.isCompleted,
                      onChanged: c.repository.readOnly || o.isReadOnly
                          ? null
                          : (value) => c.configureTask(o, {
                              'completed': value == true,
                            }),
                    )
                  : null,
              onTap: () => c.openObject(o.id),
            ),
          if (view != null)
            TextButton(
              onPressed: () => c.openObject(view!.id),
              child: const Text('Open full view'),
            ),
          if (rows.length > 8 && view == null)
            const Text('Showing the first 8 items.'),
        ],
      ],
    );
  }
}
