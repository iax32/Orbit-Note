import 'package:flutter/material.dart';
import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';
import '../../domain/universal_object.dart';
import 'workspace_views.dart';

class GameDashboardView extends StatelessWidget {
  const GameDashboardView({
    super.key,
    required this.controller,
    required this.viewObject,
    this.folderFilter,
    this.scope,
    this.onSelectViewType,
  });

  final WorkspaceController controller;
  final UniversalObject viewObject;
  final String? folderFilter;
  final String? scope;
  final ValueChanged<String>? onSelectViewType;

  bool _matchesScope(UniversalObject o) {
    final ff = folderFilter;
    final sc = scope;
    if (ff != null && ff.isNotEmpty) {
      final f = o.properties['folder'];
      if (f is String && (f == ff || f.startsWith('$ff/'))) {
        return true;
      }
      final p = controller.repository.objectPath(o.id);
      if (p != null && (p == ff || p.startsWith('$ff/'))) {
        return true;
      }
    }
    if (sc != null && sc.isNotEmpty) {
      final project = o.properties['project']?.toString().toLowerCase();
      final contextVal = o.properties['context']?.toString().toLowerCase();
      final lowerScope = sc.toLowerCase();
      if (project == lowerScope || contextVal == lowerScope) {
        return true;
      }
    }
    if ((ff == null || ff.isEmpty) && (sc == null || sc.isEmpty)) {
      return true;
    }
    return false;
  }

  bool _isTaskBlocked(UniversalObject t) {
    final raw = t.properties['blockedBy'];
    if (raw == null) return false;
    final List<String> ids = switch (raw) {
      List l => l.map((e) => e.toString()).toList(),
      String s =>
        s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      _ => const [],
    };
    if (ids.isEmpty) return false;
    for (final id in ids) {
      final blocker = controller.find(id);
      if (blocker != null && !blocker.isDeleted && !blocker.isCompleted) {
        return true;
      }
    }
    return false;
  }

  int _parseEstimatePoints(String? est) {
    if (est == null || est.isEmpty) return 0;
    final parsed = int.tryParse(est);
    if (parsed != null) return parsed;
    return switch (est.toUpperCase()) {
      'XS' => 1,
      'S' => 2,
      'M' => 3,
      'L' => 5,
      'XL' => 8,
      _ => 0,
    };
  }

  Future<void> _quickCreateTask(
    BuildContext context, {
    bool isBug = false,
  }) async {
    final titleCtrl = TextEditingController();
    String selectedDiscipline = isBug ? 'QA' : 'Gameplay';
    String? selectedSeverity = isBug ? 'major' : null;

    final targetFolder =
        folderFilter ??
        (isBug
            ? 'Games/${scope ?? "Project"}/Production'
            : 'Games/${scope ?? "Project"}/Design');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isBug ? 'New Bug Report' : 'New Game Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: isBug
                      ? 'e.g. Collision glitch at level 1 spawn'
                      : 'e.g. Implement dash mechanics',
                  isDense: true,
                ),
                onSubmitted: (_) => Navigator.pop(ctx, true),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: selectedDiscipline,
                decoration: const InputDecoration(
                  labelText: 'Discipline',
                  isDense: true,
                ),
                items: gameDevDisciplines
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedDiscipline = val);
                  }
                },
              ),
              if (isBug) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedSeverity,
                  decoration: const InputDecoration(
                    labelText: 'Severity',
                    isDense: true,
                  ),
                  items: bugSeverities
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.toUpperCase()),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedSeverity = val);
                    }
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result == true && titleCtrl.text.trim().isNotEmpty) {
      if (isBug) {
        await controller.createBugReport(
          folder: targetFolder,
          title: titleCtrl.text.trim(),
          project: scope ?? '',
          severity: selectedSeverity ?? 'major',
          discipline: selectedDiscipline,
        );
      } else {
        await controller.create(
          'orbit.task',
          title: titleCtrl.text.trim(),
          properties: {
            'folder': targetFolder,
            if (scope != null) 'project': scope,
            'discipline': selectedDiscipline,
            'completed': false,
            'status': 'todo',
            'priority': 'medium',
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final scopedObjects = controller.objects
        .where((o) => !o.isDeleted && _matchesScope(o))
        .toList();

    // Find GDD if present
    UniversalObject? gddNote;
    for (final o in scopedObjects) {
      if (o.properties['isGdd'] == true ||
          o.title.toLowerCase().contains('gdd')) {
        gddNote = o;
        break;
      }
    }

    final projectName =
        gddNote?.properties['project']?.toString() ??
        scope ??
        viewObject.title
            .replaceAll('Dashboard', '')
            .replaceAll('Overview', '')
            .replaceAll('Board', '')
            .trim();

    final genre =
        gddNote?.properties['genre']?.toString() ??
        (viewObject.properties['genre'] as String?) ??
        'Game Project';

    final platform =
        gddNote?.properties['platform']?.toString() ??
        (viewObject.properties['platform'] as String?) ??
        'PC / Steam';

    final engine =
        gddNote?.properties['engine']?.toString() ??
        (viewObject.properties['engine'] as String?) ??
        'Engine';

    // Tasks metrics
    final scopedTasks = scopedObjects
        .where((o) => o.typeId == 'orbit.task')
        .toList();

    final totalTasks = scopedTasks.length;
    final completedTasks = scopedTasks.where((t) => t.isCompleted).length;
    final openTasks = scopedTasks.where((t) => !t.isCompleted).toList();
    final taskProgressPercent = totalTasks > 0
        ? ((completedTasks * 100) ~/ totalTasks)
        : 0;

    // Estimate Points
    int totalPoints = 0;
    int completedPoints = 0;
    for (final t in scopedTasks) {
      final pts = _parseEstimatePoints(t.properties['estimate'] as String?);
      totalPoints += pts;
      if (t.isCompleted) completedPoints += pts;
    }

    // Blocked tasks
    final blockedTasks = openTasks.where(_isTaskBlocked).toList();

    // Bug metrics
    final bugs = scopedTasks.where((t) {
      return t.properties['isBug'] == true ||
          t.properties['category'] == 'Bug' ||
          t.properties['severity'] != null;
    }).toList();

    final openBugs = bugs.where((b) => !b.isCompleted).toList();
    final blockerBugs = openBugs
        .where((b) => b.properties['severity'] == 'blocker')
        .toList();
    final criticalBugs = openBugs
        .where((b) => b.properties['severity'] == 'critical')
        .toList();
    final majorBugs = openBugs
        .where((b) => b.properties['severity'] == 'major')
        .toList();
    final minorBugs = openBugs
        .where((b) => b.properties['severity'] == 'minor')
        .toList();

    // Discipline Breakdown
    final disciplineMap = <String, ({int total, int done, int points})>{};
    for (final t in scopedTasks) {
      final disc =
          (t.properties['discipline'] ?? t.properties['category'] ?? 'General')
              .toString();
      final existing = disciplineMap[disc] ?? (total: 0, done: 0, points: 0);
      final pts = _parseEstimatePoints(t.properties['estimate'] as String?);
      disciplineMap[disc] = (
        total: existing.total + 1,
        done: existing.done + (t.isCompleted ? 1 : 0),
        points: existing.points + pts,
      );
    }
    final sortedDisciplines = disciplineMap.keys.toList()
      ..sort(
        (a, b) => (disciplineMap[b]!.total).compareTo(disciplineMap[a]!.total),
      );

    // Playtests
    final playtests = scopedObjects.where((o) {
      return o.properties['category'] == 'Playtest' ||
          o.title.toLowerCase().contains('playtest');
    }).toList();

    // Recent materials (Canvases, Notes, GDD)
    final materials = scopedObjects.where((o) {
      return o.typeId != 'orbit.task' &&
          o.typeId != 'orbit.view' &&
          o.id != viewObject.id;
    }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        // 1. Project Header Banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.sports_esports,
                      color: colors.accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          projectName,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            _headerBadge(
                              genre,
                              Icons.category_outlined,
                              colors,
                            ),
                            _headerBadge(
                              platform,
                              Icons.devices_outlined,
                              colors,
                            ),
                            _headerBadge(engine, Icons.build_outlined, colors),
                            if (playtests.isNotEmpty)
                              _headerBadge(
                                '${playtests.length} Playtests',
                                Icons.videogame_asset_outlined,
                                colors,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (gddNote != null)
                    OutlinedButton.icon(
                      onPressed: () => controller.openObject(gddNote!.id),
                      icon: const Icon(Icons.description_outlined, size: 16),
                      label: const Text('Open GDD'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Action Buttons Row
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _quickCreateTask(context, isBug: false),
                    icon: const Icon(Icons.add_task, size: 16),
                    label: const Text('New Task'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _quickCreateTask(context, isBug: true),
                    icon: const Icon(Icons.bug_report_outlined, size: 16),
                    label: const Text('New Bug'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      final targetFolder =
                          folderFilter ?? 'Games/$projectName/Design';
                      controller.createFeatureSpec(
                        folder: targetFolder,
                        project: projectName,
                      );
                    },
                    icon: const Icon(Icons.article_outlined, size: 16),
                    label: const Text('+ Spec'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      final targetFolder =
                          folderFilter ?? 'Games/$projectName/Playtests';
                      controller.createPlaytestSession(
                        folder: targetFolder,
                        project: projectName,
                      );
                    },
                    icon: const Icon(Icons.videogame_asset_outlined, size: 16),
                    label: const Text('+ Playtest Log'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      final targetFolder =
                          folderFilter ?? 'Games/$projectName/Production';
                      controller.createDevLog(
                        folder: targetFolder,
                        project: projectName,
                      );
                    },
                    icon: const Icon(Icons.history_edu_outlined, size: 16),
                    label: const Text('+ Dev Log'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. Production Metrics Cards Row
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 48) / 4;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _metricCard(
                  title: 'Task Progress',
                  value: '$completedTasks / $totalTasks',
                  sub: '$taskProgressPercent% complete',
                  icon: Icons.check_circle_outline,
                  color: Colors.teal,
                  progress: totalTasks > 0 ? completedTasks / totalTasks : 0,
                  width: cardWidth > 200 ? cardWidth : double.infinity,
                  colors: colors,
                ),
                _metricCard(
                  title: 'Estimate Points',
                  value: '$completedPoints / $totalPoints',
                  sub: totalPoints > 0
                      ? '${((completedPoints * 100) ~/ totalPoints)}% delivered'
                      : 'No points planned',
                  icon: Icons.speed,
                  color: Colors.blueAccent,
                  progress: totalPoints > 0 ? completedPoints / totalPoints : 0,
                  width: cardWidth > 200 ? cardWidth : double.infinity,
                  colors: colors,
                ),
                _metricCard(
                  title: 'Blocked Watchdog',
                  value: '${blockedTasks.length}',
                  sub: blockedTasks.isEmpty
                      ? 'All paths clear'
                      : 'Require attention',
                  icon: Icons.lock_outline,
                  color: blockedTasks.isEmpty
                      ? Colors.grey
                      : Colors.amber.shade700,
                  width: cardWidth > 200 ? cardWidth : double.infinity,
                  colors: colors,
                ),
                _metricCard(
                  title: 'Open Bugs',
                  value: '${openBugs.length}',
                  sub: blockerBugs.isNotEmpty
                      ? '${blockerBugs.length} blockers!'
                      : (criticalBugs.isNotEmpty
                            ? '${criticalBugs.length} critical'
                            : 'No critical bugs'),
                  icon: Icons.bug_report,
                  color: blockerBugs.isNotEmpty || criticalBugs.isNotEmpty
                      ? Colors.redAccent
                      : (openBugs.isEmpty ? Colors.teal : Colors.orangeAccent),
                  width: cardWidth > 200 ? cardWidth : double.infinity,
                  colors: colors,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        // 3. Disciplines Progress Breakdown & Blocked Tasks Watchdog
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Discipline Progress Breakdown
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.panel,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.category_outlined,
                          size: 16,
                          color: colors.accent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Discipline Breakdown',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (sortedDisciplines.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'No disciplines assigned yet. Add tasks to see breakdown.',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.subtle,
                            ),
                          ),
                        ),
                      )
                    else
                      for (final disc in sortedDisciplines) ...[
                        _buildDisciplineRow(
                          disc,
                          disciplineMap[disc]!.total,
                          disciplineMap[disc]!.done,
                          disciplineMap[disc]!.points,
                          colors,
                        ),
                        const SizedBox(height: 10),
                      ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Right: Blocked Tasks & Bug Severities
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Blocked Tasks Watchdog
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.panel,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 16,
                              color: Colors.amber.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Blocked Tasks (${blockedTasks.length})',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (blockedTasks.isEmpty)
                          Text(
                            'No tasks currently blocked by unfinished dependencies.',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.subtle,
                            ),
                          )
                        else
                          for (final bt in blockedTasks.take(5))
                            InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: () => controller.openObject(bt.id),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.lock,
                                      size: 12,
                                      color: Colors.amber.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        bt.title,
                                        style: const TextStyle(fontSize: 12.5),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (bt.properties['discipline'] != null)
                                      Text(
                                        bt.properties['discipline'].toString(),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: colors.subtle,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Bug Severity Breakdown
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.panel,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.bug_report_outlined,
                              size: 16,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Open Bug Severity',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _severityBadge(
                              'Blocker',
                              blockerBugs.length,
                              Colors.red.shade900,
                            ),
                            _severityBadge(
                              'Critical',
                              criticalBugs.length,
                              Colors.red.shade600,
                            ),
                            _severityBadge(
                              'Major',
                              majorBugs.length,
                              Colors.orange.shade800,
                            ),
                            _severityBadge(
                              'Minor',
                              minorBugs.length,
                              Colors.blue.shade600,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 4. Open Tasks List & Playtest Log Summary
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Open Tasks List
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.panel,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.checklist, size: 16, color: colors.accent),
                        const SizedBox(width: 8),
                        Text(
                          'Open Tasks (${openTasks.length})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => onSelectViewType?.call('tasks'),
                          child: const Text(
                            'View all',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (openTasks.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'All tasks completed! Great sprint.',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.subtle,
                            ),
                          ),
                        ),
                      )
                    else
                      for (final task in openTasks.take(8)) ...[
                        Row(
                          children: [
                            Checkbox(
                              value: task.isCompleted,
                              activeColor: colors.accent,
                              onChanged: (val) {
                                controller.edit(
                                  task.id,
                                  properties: {
                                    ...task.properties,
                                    'completed': val,
                                  },
                                );
                              },
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => controller.openObject(task.id),
                                child: Text(
                                  task.title.isEmpty ? 'Untitled' : task.title,
                                  style: const TextStyle(fontSize: 12.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (task.properties['discipline'] != null)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.raised,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  task.properties['discipline'].toString(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colors.subtle,
                                  ),
                                ),
                              ),
                            if (task.properties['estimate'] != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Text(
                                  '${task.properties['estimate']}pt',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    color: colors.subtle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const Divider(height: 1),
                      ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Right: Recent Game Materials (Canvases, Notes, GDD)
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.panel,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.folder_open_outlined,
                          size: 16,
                          color: colors.accent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Game Materials & Canvases',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (materials.isEmpty)
                      Text(
                        'No design notes or canvases yet.',
                        style: TextStyle(fontSize: 12, color: colors.subtle),
                      )
                    else
                      for (final m in materials.take(6))
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => controller.openObject(m.id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 4,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  m.typeId == 'orbit.canvas'
                                      ? Icons.brush_outlined
                                      : Icons.description_outlined,
                                  size: 15,
                                  color: colors.subtle,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    m.title.isEmpty ? 'Untitled' : m.title,
                                    style: const TextStyle(fontSize: 12.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  m.typeId == 'orbit.canvas'
                                      ? 'Canvas'
                                      : 'Note',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: colors.subtle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _headerBadge(String text, IconData icon, OrbitColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colors.subtle),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, color: colors.subtle)),
        ],
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
    double? progress,
    required double width,
    required OrbitColors colors,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.subtle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(fontSize: 11, color: colors.subtle)),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: colors.raised,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDisciplineRow(
    String name,
    int total,
    int done,
    int points,
    OrbitColors colors,
  ) {
    final ratio = total > 0 ? done / total : 0.0;
    final percent = (ratio * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '$done/$total ($percent%) · ${points}pt',
              style: TextStyle(fontSize: 11, color: colors.subtle),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 5,
            backgroundColor: colors.raised,
            valueColor: AlwaysStoppedAnimation(colors.accent),
          ),
        ),
      ],
    );
  }

  Widget _severityBadge(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
