import 'package:flutter/material.dart';
import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';
import '../../domain/universal_object.dart';
import 'analysis_dashboard_view.dart';
import 'calendar_view.dart';
import 'collection_kanban_view.dart';
import 'collection_table_view.dart';
import 'course_dashboard_view.dart';
import 'exercise_table_view.dart';
import 'function_table_view.dart';
import 'game_dashboard_view.dart';
import 'heatmap_view.dart';
import 'ioc_table_view.dart';
import 'milestone_view.dart';
import 'project_dashboard_view.dart';
import 'timeline_view.dart';
import 'workspace_views.dart';
import 'smart_view_surface.dart';
import 'research_workspace_view.dart';
import 'gantt_view.dart';

class SavedViewHost extends StatefulWidget {
  const SavedViewHost({
    super.key,
    required this.viewObject,
    required this.controller,
  });

  final UniversalObject viewObject;
  final WorkspaceController controller;

  @override
  State<SavedViewHost> createState() => _SavedViewHostState();
}

class _SavedViewHostState extends State<SavedViewHost> {
  late final TextEditingController _titleController;
  final FocusNode _titleFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.viewObject.title);
  }

  @override
  void didUpdateWidget(covariant SavedViewHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewObject.title != widget.viewObject.title &&
        _titleController.text != widget.viewObject.title) {
      _titleController.text = widget.viewObject.title;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  void _updateProperty(String key, dynamic value) {
    widget.controller.edit(
      widget.viewObject.id,
      properties: {...widget.viewObject.properties, key: value},
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final c = widget.controller;
    final v = c.find(widget.viewObject.id) ?? widget.viewObject;
    if (v.properties['viewType'] == 'research') {
      return ResearchWorkspaceView(controller: c, view: v);
    }
    if (v.properties['smartQuery'] != null) {
      return SmartViewSurface(controller: c, view: v);
    }
    if (v.properties['viewType'] == 'gantt') {
      return GanttView(controller: c, view: v);
    }
    final viewType = (v.properties['viewType'] as String?) ?? 'tasks';
    final folder = v.properties['folder'] as String?;
    final scope = v.properties['scope'] as String?;
    final preset = (v.properties['preset'] as String?) ?? 'universal';

    // Calculate scoped task completion progress
    bool matchesScope(UniversalObject o) {
      if (folder != null && folder.isNotEmpty) {
        final f = o.properties['folder'];
        if (f is String && (f == folder || f.startsWith('$folder/'))) {
          return true;
        }
        final p = c.repository.objectPath(o.id);
        if (p != null && (p == folder || p.startsWith('$folder/'))) {
          return true;
        }
      }
      if (scope != null && scope.isNotEmpty) {
        final course = o.properties['course']?.toString().toLowerCase();
        final project = o.properties['project']?.toString().toLowerCase();
        final contextVal = o.properties['context']?.toString().toLowerCase();
        final lowerScope = scope.toLowerCase();
        if (course == lowerScope ||
            project == lowerScope ||
            contextVal == lowerScope) {
          return true;
        }
      }
      if ((folder == null || folder.isEmpty) &&
          (scope == null || scope.isEmpty)) {
        return true;
      }
      return false;
    }

    final scopedTasks = c
        .ofType('orbit.task')
        .where((t) => !t.isDeleted && matchesScope(t))
        .toList();
    final totalTasks = scopedTasks.length;
    final completedTasks = scopedTasks.where((t) => t.isCompleted).length;
    final progressPercent = totalTasks == 0
        ? 0
        : ((completedTasks * 100) ~/ totalTasks);

    final isCourse =
        preset == 'university' ||
        viewType == 'exercises' ||
        viewType == 'overview' ||
        v.properties['course'] != null ||
        (folder != null && folder.toLowerCase().contains('university'));

    final isGame =
        preset == 'gamedev' ||
        preset == 'bugs' ||
        viewType == 'game_dashboard' ||
        viewType == 'milestones' ||
        v.properties['game'] != null ||
        (folder != null && folder.toLowerCase().contains('game'));

    final isRe =
        preset == 'hypotheses' ||
        preset == 'functions' ||
        viewType == 're_dashboard' ||
        viewType == 'functions' ||
        viewType == 'iocs' ||
        v.properties['target'] != null ||
        (folder != null &&
            (folder.toLowerCase().contains('reverse engineering') ||
                folder.toLowerCase().contains('internals') ||
                folder.toLowerCase().contains('malware') ||
                folder.toLowerCase().contains('security')));

    final showCourseTabs =
        isCourse || viewType == 'exercises' || viewType == 'overview';
    final showGameTabs =
        isGame || viewType == 'game_dashboard' || viewType == 'milestones';
    final showReTabs =
        isRe ||
        viewType == 're_dashboard' ||
        viewType == 'functions' ||
        viewType == 'iocs';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // View Header bar
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
          decoration: BoxDecoration(
            color: colors.panel,
            border: Border(bottom: BorderSide(color: colors.divider)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    switch (viewType) {
                      'table' => Icons.table_chart_outlined,
                      'board' => Icons.view_kanban_outlined,
                      'calendar' => Icons.calendar_month_outlined,
                      'timeline' => Icons.timeline_outlined,
                      'heatmap' => Icons.auto_awesome_outlined,
                      'exercises' => Icons.table_chart_outlined,
                      'overview' => Icons.dashboard_outlined,
                      'project' => Icons.folder_special_outlined,
                      'game_dashboard' => Icons.sports_esports_outlined,
                      'milestones' => Icons.flag_outlined,
                      're_dashboard' => Icons.biotech_outlined,
                      'functions' => Icons.code_outlined,
                      'iocs' => Icons.fingerprint,
                      _ => Icons.checklist_outlined,
                    },
                    size: 20,
                    color: colors.accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _titleController,
                      focusNode: _titleFocus,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 0,
                        ),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: 'View Title',
                      ),
                      onSubmitted: (newTitle) {
                        if (newTitle.trim().isNotEmpty) {
                          c.edit(v.id, title: newTitle.trim());
                        }
                      },
                    ),
                  ),
                  if (folder != null && folder.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.raised,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_outlined,
                            size: 13,
                            color: colors.subtle,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            folder,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.subtle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Duplicate View
                  IconButton(
                    tooltip: 'Duplicate View',
                    icon: Icon(
                      Icons.copy_outlined,
                      size: 16,
                      color: colors.subtle,
                    ),
                    onPressed: () => c.duplicateView(v.id),
                  ),
                  // Delete View
                  IconButton(
                    tooltip: 'Delete View',
                    icon: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: colors.subtle,
                    ),
                    onPressed: () => c.trash(v.id),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 4,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // View Type Switcher Tabs
                  _ViewTab(
                    icon: Icons.checklist_outlined,
                    label: 'List',
                    selected: viewType == 'tasks' || viewType == 'list',
                    onTap: () => _updateProperty('viewType', 'tasks'),
                    colors: colors,
                  ),
                  const SizedBox(width: 4),
                  _ViewTab(
                    icon: Icons.view_kanban_outlined,
                    label: 'Board',
                    selected: viewType == 'board',
                    onTap: () => _updateProperty('viewType', 'board'),
                    colors: colors,
                  ),
                  const SizedBox(width: 4),
                  _ViewTab(
                    icon: Icons.table_chart_outlined,
                    label: 'Table',
                    selected: viewType == 'table',
                    onTap: () => _updateProperty('viewType', 'table'),
                    colors: colors,
                  ),
                  const SizedBox(width: 4),
                  _ViewTab(
                    icon: Icons.calendar_month_outlined,
                    label: 'Calendar',
                    selected: viewType == 'calendar',
                    onTap: () => _updateProperty('viewType', 'calendar'),
                    colors: colors,
                  ),
                  const SizedBox(width: 4),
                  _ViewTab(
                    icon: Icons.timeline_outlined,
                    label: 'Timeline',
                    selected: viewType == 'timeline',
                    onTap: () => _updateProperty('viewType', 'timeline'),
                    colors: colors,
                  ),
                  const SizedBox(width: 4),
                  _ViewTab(
                    icon: Icons.auto_awesome_outlined,
                    label: 'Heatmap',
                    selected: viewType == 'heatmap',
                    onTap: () => _updateProperty('viewType', 'heatmap'),
                    colors: colors,
                  ),
                  if (showCourseTabs) ...[
                    const SizedBox(width: 4),
                    _ViewTab(
                      icon: Icons.table_chart_outlined,
                      label: 'Exercises',
                      selected: viewType == 'exercises',
                      onTap: () => _updateProperty('viewType', 'exercises'),
                      colors: colors,
                    ),
                    const SizedBox(width: 4),
                    _ViewTab(
                      icon: Icons.dashboard_outlined,
                      label: 'Overview',
                      selected: viewType == 'overview',
                      onTap: () => _updateProperty('viewType', 'overview'),
                      colors: colors,
                    ),
                  ],
                  if (showGameTabs) ...[
                    const SizedBox(width: 4),
                    _ViewTab(
                      icon: Icons.sports_esports_outlined,
                      label: 'Dashboard',
                      selected: viewType == 'game_dashboard',
                      onTap: () =>
                          _updateProperty('viewType', 'game_dashboard'),
                      colors: colors,
                    ),
                    const SizedBox(width: 4),
                    _ViewTab(
                      icon: Icons.flag_outlined,
                      label: 'Milestones',
                      selected: viewType == 'milestones',
                      onTap: () => _updateProperty('viewType', 'milestones'),
                      colors: colors,
                    ),
                  ],
                  if (showReTabs) ...[
                    const SizedBox(width: 4),
                    _ViewTab(
                      icon: Icons.biotech_outlined,
                      label: 'Dashboard',
                      selected: viewType == 're_dashboard',
                      onTap: () => _updateProperty('viewType', 're_dashboard'),
                      colors: colors,
                    ),
                    const SizedBox(width: 4),
                    _ViewTab(
                      icon: Icons.code_outlined,
                      label: 'Functions',
                      selected: viewType == 'functions',
                      onTap: () => _updateProperty('viewType', 'functions'),
                      colors: colors,
                    ),
                    const SizedBox(width: 4),
                    _ViewTab(
                      icon: Icons.fingerprint,
                      label: 'Indicators',
                      selected: viewType == 'iocs',
                      onTap: () => _updateProperty('viewType', 'iocs'),
                      colors: colors,
                    ),
                  ],
                  const SizedBox(width: 8),
                  // Preset dropdown if in Board mode
                  if (viewType == 'board') ...[
                    DropdownButton<String>(
                      value: preset,
                      underline: const SizedBox.shrink(),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        size: 16,
                        color: colors.subtle,
                      ),
                      style: TextStyle(fontSize: 12, color: colors.text),
                      onChanged: (val) {
                        if (val != null) _updateProperty('preset', val);
                      },
                      items: const [
                        DropdownMenuItem(
                          value: 'universal',
                          child: Text('Universal Columns'),
                        ),
                        DropdownMenuItem(
                          value: 'software',
                          child: Text('Software Dev'),
                        ),
                        DropdownMenuItem(
                          value: 'gamedev',
                          child: Text('Game Dev'),
                        ),
                        DropdownMenuItem(
                          value: 'bugs',
                          child: Text('Bug Tracker'),
                        ),
                        DropdownMenuItem(
                          value: 'university',
                          child: Text('University Course'),
                        ),
                        DropdownMenuItem(
                          value: 'hypotheses',
                          child: Text('Hypotheses'),
                        ),
                        DropdownMenuItem(
                          value: 'functions',
                          child: Text('Function Status'),
                        ),
                        DropdownMenuItem(
                          value: 'research',
                          child: Text('Research'),
                        ),
                        DropdownMenuItem(
                          value: 'content',
                          child: Text('Content Pipeline'),
                        ),
                        DropdownMenuItem(
                          value: 'personal',
                          child: Text('Personal Planning'),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                  ],
                  // Course / Project progress bar
                  // The project dashboard already reports its own membership.
                  if (totalTasks > 0 && viewType != 'project') ...[
                    SizedBox(
                      width: 100,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: completedTasks / totalTasks,
                          backgroundColor: colors.raised,
                          valueColor: AlwaysStoppedAnimation(colors.accent),
                          minHeight: 5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$completedTasks / $totalTasks complete · $progressPercent%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colors.subtle,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        // Embedded View Body
        Expanded(
          child: switch (viewType) {
            'table' => CollectionTableView(
              key: ValueKey('table-${v.id}'),
              controller: c,
              viewObject: v,
              folderFilter: folder,
              scope: scope,
            ),
            'board' => CollectionKanbanView(
              key: ValueKey(
                'board-${v.id}-${v.properties['groupBy'] ?? 'status'}-$preset',
              ),
              controller: c,
              viewObject: v,
              folderFilter: folder,
              scope: scope,
            ),
            'calendar' => CalendarView(
              key: ValueKey('calendar-${v.id}'),
              controller: c,
              viewObject: v,
              folderFilter: folder,
              scope: scope,
            ),
            'timeline' => TimelineView(
              key: ValueKey('timeline-${v.id}'),
              controller: c,
              viewObject: v,
              folderFilter: folder,
              scope: scope,
            ),
            'heatmap' => HeatmapView(
              key: ValueKey('heatmap-${v.id}'),
              controller: c,
              viewObject: v,
              folderFilter: folder,
              scope: scope,
            ),
            'exercises' => ExerciseTableView(
              key: ValueKey('exercises-${v.id}'),
              controller: c,
              viewObject: v,
              folderFilter: folder,
              scope: scope,
            ),
            'overview' => CourseDashboardView(
              key: ValueKey('overview-${v.id}'),
              controller: c,
              viewObject: v,
              folderFilter: folder,
              scope: scope,
              onSelectViewType: (vt) => _updateProperty('viewType', vt),
            ),
            'game_dashboard' => GameDashboardView(
              key: ValueKey('game_dashboard-${v.id}'),
              controller: c,
              viewObject: v,
              folderFilter: folder,
              scope: scope,
              onSelectViewType: (vt) => _updateProperty('viewType', vt),
            ),
            'milestones' => MilestoneView(
              key: ValueKey('milestones-${v.id}'),
              controller: c,
              viewObject: v,
              folderFilter: folder,
              scope: scope,
              onSelectViewType: (vt) => _updateProperty('viewType', vt),
            ),
            're_dashboard' => AnalysisDashboardView(
              key: ValueKey('re_dashboard-${v.id}'),
              controller: c,
              viewObject: v,
              folderFilter: folder,
              scope: scope,
              onSelectViewType: (vt) => _updateProperty('viewType', vt),
            ),
            'functions' => FunctionTableView(
              key: ValueKey('functions-${v.id}'),
              controller: c,
              viewObject: v,
              folderFilter: folder,
              scope: scope,
            ),
            'iocs' => IocTableView(
              key: ValueKey('iocs-${v.id}'),
              controller: c,
              viewObject: v,
              folderFilter: folder,
              scope: scope,
            ),
            'project' => ProjectDashboardView(
              projectName: (v.properties['project'] ?? v.title).toString(),
              controller: c,
            ),
            _ => TasksView(
              key: ValueKey('tasks-${v.id}'),
              controller: c,
              viewObject: v,
              folderFilter: folder,
              scope: scope,
              initialTab: 'todo',
            ),
          },
        ),
      ],
    );
  }
}

class _ViewTab extends StatelessWidget {
  const _ViewTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final OrbitColors colors;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? colors.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? colors.accent : colors.subtle,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? colors.accent : colors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
