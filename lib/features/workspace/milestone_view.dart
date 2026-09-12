import 'package:flutter/material.dart';
import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';
import '../../domain/universal_object.dart';
import 'workspace_views.dart';

class MilestoneView extends StatefulWidget {
  const MilestoneView({
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

  @override
  State<MilestoneView> createState() => _MilestoneViewState();
}

class _MilestoneViewState extends State<MilestoneView> {
  String? _expandedMilestone;

  static const defaultMilestones = [
    'Prototype',
    'Vertical Slice',
    'Alpha',
    'Beta',
    'Release Candidate',
    'Release',
  ];

  bool _matchesScope(UniversalObject o) {
    final ff = widget.folderFilter;
    final sc = widget.scope;
    if (ff != null && ff.isNotEmpty) {
      final f = o.properties['folder'];
      if (f is String && (f == ff || f.startsWith('$ff/'))) {
        return true;
      }
      final p = widget.controller.repository.objectPath(o.id);
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

  int _parseEstimate(String? est) {
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

  Future<void> _quickAddTask(String milestone) async {
    final textCtrl = TextEditingController();
    String discipline = 'Gameplay';

    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('New Task for $milestone'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Task title…',
                  isDense: true,
                ),
                onSubmitted: (_) => Navigator.pop(ctx, true),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: discipline,
                decoration: const InputDecoration(
                  labelText: 'Discipline',
                  isDense: true,
                ),
                items: gameDevDisciplines
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => discipline = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (res == true && textCtrl.text.trim().isNotEmpty) {
      final targetFolder =
          widget.folderFilter ??
          'Games/${widget.scope ?? "Project"}/Production';
      await widget.controller.create(
        'orbit.task',
        title: textCtrl.text.trim(),
        properties: {
          'folder': targetFolder,
          if (widget.scope != null) 'project': widget.scope,
          'milestone': milestone,
          'discipline': discipline,
          'completed': false,
          'status': 'todo',
          'priority': 'medium',
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final scopedTasks = widget.controller
        .ofType('orbit.task')
        .where((t) => !t.isDeleted && _matchesScope(t))
        .toList();

    // Collect all milestones from tasks and defaults
    final taskMilestones = scopedTasks
        .map((t) => t.properties['milestone'] as String?)
        .whereType<String>()
        .where((m) => m.isNotEmpty)
        .toSet();

    final allMilestones = <String>[...defaultMilestones];
    for (final tm in taskMilestones) {
      if (!allMilestones.any((m) => m.toLowerCase() == tm.toLowerCase())) {
        allMilestones.add(tm);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.flag_outlined, size: 22, color: colors.accent),
            const SizedBox(width: 10),
            Text(
              'Production Milestones',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              '${scopedTasks.length} scoped tasks',
              style: TextStyle(fontSize: 12, color: colors.subtle),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Track release goals, target delivery phases, and discipline progress across milestones.',
          style: TextStyle(fontSize: 13, color: colors.subtle),
        ),
        const SizedBox(height: 20),

        // Milestones List
        for (final ms in allMilestones) ...[
          _buildMilestoneCard(
            ms,
            scopedTasks.where((t) {
              final taskMs = t.properties['milestone']
                  ?.toString()
                  .toLowerCase();
              return taskMs == ms.toLowerCase();
            }).toList(),
            colors,
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildMilestoneCard(
    String milestone,
    List<UniversalObject> tasks,
    OrbitColors colors,
  ) {
    final isExpanded =
        _expandedMilestone == milestone ||
        (_expandedMilestone == null && tasks.isNotEmpty);
    final total = tasks.length;
    final done = tasks.where((t) => t.isCompleted).length;
    final ratio = total > 0 ? done / total : 0.0;
    final percent = (ratio * 100).toInt();

    int totalPts = 0;
    int donePts = 0;
    final discMap = <String, ({int total, int done})>{};

    for (final t in tasks) {
      final pts = _parseEstimate(t.properties['estimate'] as String?);
      totalPts += pts;
      if (t.isCompleted) donePts += pts;

      final disc =
          (t.properties['discipline'] ?? t.properties['category'] ?? 'Other')
              .toString();
      final existing = discMap[disc] ?? (total: 0, done: 0);
      discMap[disc] = (
        total: existing.total + 1,
        done: existing.done + (t.isCompleted ? 1 : 0),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isExpanded
              ? colors.accent.withValues(alpha: 0.4)
              : colors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() {
                _expandedMilestone = isExpanded ? '' : milestone;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                        size: 18,
                        color: colors.subtle,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        milestone,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.raised,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$done/$total ($percent%)',
                          style: TextStyle(fontSize: 11, color: colors.subtle),
                        ),
                      ),
                      if (totalPts > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '$donePts/${totalPts}pt',
                          style: TextStyle(fontSize: 11, color: colors.subtle),
                        ),
                      ],
                      const Spacer(),
                      IconButton(
                        tooltip: 'Quick add task to $milestone',
                        icon: const Icon(Icons.add, size: 16),
                        onPressed: () => _quickAddTask(milestone),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                      backgroundColor: colors.raised,
                      valueColor: AlwaysStoppedAnimation(
                        percent == 100 ? Colors.teal : colors.accent,
                      ),
                    ),
                  ),
                  if (discMap.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final entry in discMap.entries)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.raised,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${entry.key}: ${entry.value.done}/${entry.value.total}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: entry.value.done == entry.value.total
                                    ? Colors.teal
                                    : colors.subtle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Expanded Tasks List
          if (isExpanded) ...[
            Divider(height: 1, color: colors.divider),
            if (tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No tasks tagged with "$milestone". Click + to add one.',
                    style: TextStyle(fontSize: 12, color: colors.subtle),
                  ),
                ),
              )
            else
              for (final t in tasks) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: t.isCompleted,
                        activeColor: colors.accent,
                        onChanged: (val) {
                          widget.controller.edit(
                            t.id,
                            properties: {...t.properties, 'completed': val},
                          );
                        },
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => widget.controller.openObject(t.id),
                          child: Text(
                            t.title.isEmpty ? 'Untitled' : t.title,
                            style: TextStyle(
                              fontSize: 13,
                              decoration: t.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      if (t.properties['discipline'] != null)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.raised,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            t.properties['discipline'].toString(),
                            style: TextStyle(
                              fontSize: 10.5,
                              color: colors.subtle,
                            ),
                          ),
                        ),
                      if (t.properties['estimate'] != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            '${t.properties['estimate']}pt',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: colors.subtle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: colors.divider.withValues(alpha: 0.5),
                ),
              ],
          ],
        ],
      ),
    );
  }
}
