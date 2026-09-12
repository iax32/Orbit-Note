import 'package:flutter/material.dart';
import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';
import '../../domain/calendar_event.dart';
import '../../domain/universal_object.dart';

class CourseDashboardView extends StatelessWidget {
  const CourseDashboardView({
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
      final course = o.properties['course']?.toString().toLowerCase();
      final project = o.properties['project']?.toString().toLowerCase();
      final contextVal = o.properties['context']?.toString().toLowerCase();
      final lowerScope = sc.toLowerCase();
      if (course == lowerScope ||
          project == lowerScope ||
          contextVal == lowerScope) {
        return true;
      }
    }
    if ((ff == null || ff.isEmpty) && (sc == null || sc.isEmpty)) {
      return true;
    }
    return false;
  }

  bool _isExercise(UniversalObject o) {
    if (o.isDeleted) return false;
    if (!_matchesScope(o)) return false;

    if (o.properties.containsKey('exerciseStatus') ||
        o.properties.containsKey('difficulty') ||
        o.properties.containsKey('confidence')) {
      return true;
    }

    final folder = o.properties['folder'] as String?;
    final p = controller.repository.objectPath(o.id) ?? '';
    if ((folder != null && folder.contains('Exercises')) ||
        p.contains('Exercises')) {
      return o.typeId == 'orbit.canvas' || o.typeId == 'orbit.note';
    }

    final title = o.title.toLowerCase();
    if (title.contains('exercise') ||
        title.contains('sheet') ||
        title.contains('practice') ||
        title.contains('aufgabe') ||
        title.contains('problem')) {
      return o.typeId == 'orbit.canvas' || o.typeId == 'orbit.note';
    }
    return false;
  }

  Future<void> _createNewTask(BuildContext context) async {
    final textCtrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Course Task'),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Finish Sheet 2, Read Chapter 3',
            isDense: true,
          ),
          onSubmitted: (val) => Navigator.pop(ctx, val.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, textCtrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (res != null && res.isNotEmpty) {
      await controller.create(
        'orbit.task',
        title: res,
        properties: {
          if (folderFilter != null) 'folder': folderFilter,
          if (scope != null) 'course': scope,
          'completed': false,
          'priority': 'medium',
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final scopedObjects = controller.objects
        .where((o) => !o.isDeleted && _matchesScope(o))
        .toList();

    // Find course overview note if available
    UniversalObject? overviewNote;
    for (final o in scopedObjects) {
      if (o.properties['isCourseOverview'] == true) {
        overviewNote = o;
        break;
      }
    }

    final courseName =
        overviewNote?.properties['course']?.toString() ??
        scope ??
        viewObject.title
            .replaceAll('Overview', '')
            .replaceAll('Tasks', '')
            .trim();
    final semester =
        overviewNote?.properties['semester']?.toString() ??
        (viewObject.properties['semester'] as String?) ??
        'WS 2026';
    final ects =
        overviewNote?.properties['ects']?.toString() ??
        (viewObject.properties['ects'] as String?) ??
        '5';
    final lecturer =
        overviewNote?.properties['lecturer']?.toString() ??
        (viewObject.properties['lecturer'] as String?) ??
        '';

    // Exercises metrics
    final exercises = scopedObjects.where(_isExercise).toList();
    final totalExercises = exercises.length;
    final solvedExercises = exercises
        .where((e) => e.properties['exerciseStatus'] == 'solved')
        .length;
    final stuckExercises = exercises
        .where((e) => e.properties['exerciseStatus'] == 'stuck')
        .toList();
    final reviewExercises = exercises
        .where((e) => e.properties['exerciseStatus'] == 'review')
        .toList();
    final lowConfExercises = exercises
        .where((e) => e.properties['confidence'] == 'low')
        .toList();

    final exerciseProgressRatio = totalExercises > 0
        ? solvedExercises / totalExercises
        : 0.0;
    final exerciseProgressPercent = (exerciseProgressRatio * 100).toInt();

    // Weak topics aggregation
    final weakTopicsMap =
        <String, ({int stuck, int lowConf, List<UniversalObject> items})>{};
    for (final e in [...stuckExercises, ...lowConfExercises]) {
      final topic = (e.properties['topic'] as String?)?.trim();
      final topicKey = (topic == null || topic.isEmpty)
          ? 'General Practice'
          : topic;
      final existing =
          weakTopicsMap[topicKey] ??
          (stuck: 0, lowConf: 0, items: <UniversalObject>[]);
      final isStuck = e.properties['exerciseStatus'] == 'stuck';
      final isLow = e.properties['confidence'] == 'low';
      if (!existing.items.any((item) => item.id == e.id)) {
        existing.items.add(e);
      }
      weakTopicsMap[topicKey] = (
        stuck: existing.stuck + (isStuck ? 1 : 0),
        lowConf: existing.lowConf + (isLow ? 1 : 0),
        items: existing.items,
      );
    }

    // Tasks metrics
    final scopedTasks = scopedObjects
        .where((o) => o.typeId == 'orbit.task')
        .toList();
    final openTasks = scopedTasks.where((t) => !t.isCompleted).toList();
    final completedTasks = scopedTasks.where((t) => t.isCompleted).toList();

    // Upcoming Deadlines & Countdown
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final upcomingItems =
        <
          ({
            UniversalObject object,
            DateTime date,
            int daysRemaining,
            bool isExam,
          })
        >[];
    for (final o in scopedObjects) {
      DateTime? targetDate;
      if (o.typeId == 'orbit.task' && !o.isCompleted) {
        targetDate = parseCalendarDate(o.properties['dueDate']);
      } else if (o.typeId == 'orbit.event') {
        targetDate = parseCalendarDate(o.properties['startDate']);
      }
      if (targetDate != null) {
        final diff = targetDate.difference(today).inDays;
        final isExam =
            o.title.toLowerCase().contains('exam') ||
            o.title.toLowerCase().contains('klausur') ||
            o.title.toLowerCase().contains('midterm') ||
            o.title.toLowerCase().contains('final');
        upcomingItems.add((
          object: o,
          date: targetDate,
          daysRemaining: diff,
          isExam: isExam,
        ));
      }
    }
    upcomingItems.sort((a, b) => a.date.compareTo(b.date));

    // Recent materials (lectures, canvases, notes)
    final recentMaterials =
        scopedObjects
            .where(
              (o) => o.typeId == 'orbit.note' || o.typeId == 'orbit.canvas',
            )
            .where((o) => o.properties['isCourseOverview'] != true)
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course Header Banner Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.raised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.school_outlined,
                    size: 28,
                    color: colors.accent,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        courseName.isNotEmpty
                            ? courseName
                            : 'University Course',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _MetaPill(
                            icon: Icons.calendar_today_outlined,
                            label: semester,
                            colors: colors,
                          ),
                          _MetaPill(
                            icon: Icons.stars_outlined,
                            label: '$ects ECTS',
                            colors: colors,
                          ),
                          if (lecturer.isNotEmpty)
                            _MetaPill(
                              icon: Icons.person_outline,
                              label: lecturer,
                              colors: colors,
                            ),
                          if (folderFilter != null)
                            _MetaPill(
                              icon: Icons.folder_outlined,
                              label: folderFilter!,
                              colors: colors,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Actions
                if (overviewNote != null)
                  FilledButton.tonalIcon(
                    onPressed: () => controller.openObject(overviewNote!.id),
                    icon: const Icon(Icons.description_outlined, size: 16),
                    label: const Text('Open Overview Note'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Toolbar
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  final folder = folderFilter != null
                      ? '$folderFilter/Lectures'
                      : 'Lectures';
                  controller.createLectureNote(
                    folder: folder,
                    course: scope ?? '',
                  );
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Lecture Note'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  final folder = folderFilter != null
                      ? '$folderFilter/Exercises'
                      : 'Exercises';
                  controller.createExerciseCanvas(
                    folder: folder,
                    course: scope ?? '',
                  );
                },
                icon: const Icon(Icons.dashboard_outlined, size: 16),
                label: const Text('New Exercise Canvas'),
              ),
              OutlinedButton.icon(
                onPressed: () => _createNewTask(context),
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('New Task'),
              ),
              if (onSelectViewType != null)
                FilledButton.icon(
                  onPressed: () => onSelectViewType!('exercises'),
                  icon: const Icon(Icons.table_chart_outlined, size: 16),
                  label: const Text('Exercise Table & Practice'),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Key Metrics Cards
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Exercise Mastery Card
              Expanded(
                flex: 4,
                child: _DashboardCard(
                  colors: colors,
                  title: 'Exercise Practice Progress',
                  icon: Icons.functions_outlined,
                  actionText: onSelectViewType != null ? 'Open Table' : null,
                  onAction: onSelectViewType != null
                      ? () => onSelectViewType!('exercises')
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$solvedExercises of $totalExercises Solved',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$exerciseProgressPercent%',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: exerciseProgressRatio,
                          backgroundColor: colors.border,
                          valueColor: AlwaysStoppedAnimation(colors.success),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _StatChip(
                            label: '$solvedExercises Solved',
                            color: colors.success,
                          ),
                          _StatChip(
                            label: '${stuckExercises.length} Stuck',
                            color: colors.danger,
                          ),
                          _StatChip(
                            label: '${reviewExercises.length} Review',
                            color: colors.accent,
                          ),
                          _StatChip(
                            label: '${lowConfExercises.length} Low Conf',
                            color: colors.warning,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // 2. Deadlines / Exam Countdown Card
              Expanded(
                flex: 4,
                child: _DashboardCard(
                  colors: colors,
                  title: 'Deadlines & Exam Countdown',
                  icon: Icons.alarm_outlined,
                  child: upcomingItems.isEmpty
                      ? Text(
                          'No upcoming deadlines or exams scheduled.',
                          style: TextStyle(fontSize: 12, color: colors.subtle),
                        )
                      : Column(
                          children: [
                            for (final item in upcomingItems.take(3))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      item.isExam
                                          ? Icons.assignment_late_outlined
                                          : Icons.event_outlined,
                                      size: 16,
                                      color: item.isExam
                                          ? colors.danger
                                          : colors.accent,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item.object.title,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: item.isExam
                                              ? colors.danger
                                              : colors.text,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: item.daysRemaining < 0
                                            ? colors.danger.withValues(
                                                alpha: 0.15,
                                              )
                                            : (item.daysRemaining <= 3
                                                  ? colors.warning.withValues(
                                                      alpha: 0.15,
                                                    )
                                                  : colors.raised),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item.daysRemaining == 0
                                            ? 'Today'
                                            : item.daysRemaining == 1
                                            ? 'Tomorrow'
                                            : item.daysRemaining < 0
                                            ? '${-item.daysRemaining}d overdue'
                                            : '${item.daysRemaining} days left',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: item.daysRemaining <= 3
                                              ? colors.danger
                                              : colors.subtle,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
              ),

              const SizedBox(width: 16),

              // 3. Task Status Card
              Expanded(
                flex: 3,
                child: _DashboardCard(
                  colors: colors,
                  title: 'Tasks',
                  icon: Icons.checklist_outlined,
                  actionText: '+ Task',
                  onAction: () => _createNewTask(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${openTasks.length}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'open tasks',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.subtle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${completedTasks.length} tasks completed',
                        style: TextStyle(fontSize: 11, color: colors.subtle),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Weak Topics / Practice Areas Card
          _DashboardCard(
            colors: colors,
            title: 'Focus Practice Areas & Weak Topics',
            icon: Icons.psychology_outlined,
            child: weakTopicsMap.isEmpty
                ? Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 20,
                        color: colors.success,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Great job! No stuck or low-confidence topics identified.',
                        style: TextStyle(fontSize: 13, color: colors.text),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Topics with exercises marked as Stuck or Low Confidence:',
                        style: TextStyle(fontSize: 12, color: colors.subtle),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          for (final entry in weakTopicsMap.entries)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: colors.raised,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: colors.danger.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.key,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: colors.text,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${entry.value.stuck} stuck · ${entry.value.lowConf} low confidence',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colors.danger,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  FilledButton.tonal(
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () {
                                      if (entry.value.items.isNotEmpty) {
                                        controller.openObject(
                                          entry.value.items.first.id,
                                        );
                                      } else if (onSelectViewType != null) {
                                        onSelectViewType!('exercises');
                                      }
                                    },
                                    child: const Text(
                                      'Practice',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),

          // Two Columns: Open Tasks & Recent Materials
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Course Tasks
              Expanded(
                flex: 5,
                child: _DashboardCard(
                  colors: colors,
                  title: 'Open Tasks',
                  icon: Icons.check_circle_outline,
                  actionText: '+ Add',
                  onAction: () => _createNewTask(context),
                  child: openTasks.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No open tasks for this course.',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.subtle,
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            for (final task in openTasks.take(6))
                              InkWell(
                                onTap: () => controller.openObject(task.id),
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                    horizontal: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: task.isCompleted,
                                        onChanged: (val) {
                                          controller.edit(
                                            task.id,
                                            properties: {
                                              ...task.properties,
                                              'completed': val ?? false,
                                            },
                                          );
                                        },
                                      ),
                                      Expanded(
                                        child: Text(
                                          task.title,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: colors.text,
                                            decoration: task.isCompleted
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (task.properties['dueDate'] != null)
                                        Text(
                                          formatFriendlyDueDate(
                                            parseCalendarDate(
                                              task.properties['dueDate'],
                                            ),
                                          ),
                                          style: TextStyle(
                                            fontSize: 11,
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

              const SizedBox(width: 16),

              // Right Column: Recent Course Notes & Canvases
              Expanded(
                flex: 5,
                child: _DashboardCard(
                  colors: colors,
                  title: 'Recent Materials',
                  icon: Icons.history_edu_outlined,
                  child: recentMaterials.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No notes or canvases yet.',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.subtle,
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            for (final item in recentMaterials.take(6))
                              InkWell(
                                onTap: () => controller.openObject(item.id),
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                    horizontal: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        item.typeId == 'orbit.canvas'
                                            ? Icons.dashboard_outlined
                                            : Icons.description_outlined,
                                        size: 16,
                                        color: colors.accent,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: colors.text,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        (item.properties['folder'] as String?)
                                                ?.split('/')
                                                .last ??
                                            '',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colors.muted,
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
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.colors,
    required this.title,
    required this.icon,
    required this.child,
    this.actionText,
    this.onAction,
  });

  final OrbitColors colors;
  final String title;
  final IconData icon;
  final Widget child;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: colors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
              ),
              if (actionText != null && onAction != null)
                InkWell(
                  onTap: onAction,
                  child: Text(
                    actionText!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final OrbitColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colors.subtle),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, color: colors.subtle)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
