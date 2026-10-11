import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';
import '../../domain/universal_object.dart';

/// A generated semantic overview for a Project (PRJ-01, PRJ-02).
/// Displays derived context, tasks, notes, activity, and files without requiring duplicate maintenance.
class ProjectDashboardView extends ConsumerWidget {
  const ProjectDashboardView({
    super.key,
    required this.projectName,
    required this.controller,
  });

  final String projectName;
  final WorkspaceController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      ref.watch(workspaceProvider);
    } catch (_) {}
    final colors = OrbitColors.of(context);
    final c = controller;

    final lowerProject = projectName.toLowerCase().trim();
    final allProjectObjects = c.activeObjects.where((o) {
      final p = o.properties['project']?.toString().toLowerCase().trim();
      if (p == lowerProject) return true;
      if (o.typeId == 'orbit.note' &&
          (o.body.contains('[[$projectName]]') ||
              o.body.contains('[[$projectName|'))) {
        return true;
      }
      return false;
    }).toList();

    final tasks = allProjectObjects
        .where((o) => o.typeId == 'orbit.task')
        .toList();
    final openTasks = tasks.where((t) => !t.isCompleted).toList();
    final completedTasks = tasks.where((t) => t.isCompleted).toList();
    final totalTasks = tasks.length;
    final progress = totalTasks > 0
        ? (completedTasks.length / totalTasks)
        : 0.0;

    final notes =
        allProjectObjects.where((o) => o.typeId == 'orbit.note').toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final files =
        allProjectObjects.where((o) => o.typeId == 'orbit.file').toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final canvases = allProjectObjects
        .where((o) => o.typeId == 'orbit.canvas')
        .toList();

    final recentActivity = allProjectObjects.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
            children: [
              // Project Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.folder_special_outlined,
                      size: 28,
                      color: colors.accent,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Text(
                              projectName,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: colors.raised,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: colors.border),
                              ),
                              child: Text(
                                'Project overview',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colors.subtle,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Semantic context generated across all notes, tasks, and files.',
                          style: TextStyle(fontSize: 13, color: colors.subtle),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Task'),
                        onPressed: () async {
                          final task = await c.create(
                            'orbit.task',
                            title: 'New Task',
                            properties: {'project': projectName},
                          );
                          if (task != null) c.openObject(task.id);
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.note_add_outlined, size: 16),
                        label: const Text('New Note'),
                        onPressed: () async {
                          final note = await c.create(
                            'orbit.note',
                            title: '$projectName Note',
                            properties: {'project': projectName},
                          );
                          if (note != null) c.openObject(note.id);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Progress Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.zero,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TASK COMPLETION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: colors.subtle,
                          ),
                        ),
                        Text(
                          '${completedTasks.length} / $totalTasks completed (${(progress * 100).toInt()}%)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: colors.raised,
                        valueColor: AlwaysStoppedAnimation(colors.accent),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Tasks & Notes Two-Column Layout
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth > 700;
                  final tasksWidget = _buildTasksSection(
                    context,
                    openTasks,
                    completedTasks,
                    colors,
                    c,
                  );
                  final notesWidget = _buildNotesSection(
                    context,
                    notes,
                    canvases,
                    files,
                    colors,
                    c,
                  );

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: tasksWidget),
                        const SizedBox(width: 24),
                        Expanded(child: notesWidget),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      tasksWidget,
                      const SizedBox(height: 24),
                      notesWidget,
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              // Activity History Section
              _buildActivitySection(
                context,
                recentActivity.take(8).toList(),
                colors,
                c,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTasksSection(
    BuildContext context,
    List<UniversalObject> openTasks,
    List<UniversalObject> completedTasks,
    OrbitColors colors,
    WorkspaceController c,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.checklist_outlined, size: 18),
              const SizedBox(width: 8),
              const Text(
                'TASKS',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                '${openTasks.length} open',
                style: TextStyle(fontSize: 13, color: colors.subtle),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (openTasks.isEmpty && completedTasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No tasks in this project yet.',
                  style: TextStyle(fontSize: 13, color: colors.subtle),
                ),
              ),
            )
          else ...[
            for (final task in openTasks)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: false,
                        onChanged: (val) {
                          if (val == true) {
                            c.edit(
                              task.id,
                              properties: {
                                ...task.properties,
                                'completed': true,
                                'completedAt': DateTime.now().toIso8601String(),
                              },
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => c.openObject(task.id),
                        child: Text(
                          task.title,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (completedTasks.isNotEmpty) ...[
              const SizedBox(height: 8),
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    '${completedTasks.length} completed tasks',
                    style: TextStyle(fontSize: 13, color: colors.subtle),
                  ),
                  children: [
                    for (final task in completedTasks)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: Checkbox(
                                value: true,
                                onChanged: (val) {
                                  if (val == false) {
                                    c.edit(
                                      task.id,
                                      properties: {
                                        ...task.properties,
                                        'completed': false,
                                      },
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () => c.openObject(task.id),
                                child: Text(
                                  task.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    decoration: TextDecoration.lineThrough,
                                    color: colors.subtle,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildNotesSection(
    BuildContext context,
    List<UniversalObject> notes,
    List<UniversalObject> canvases,
    List<UniversalObject> files,
    OrbitColors colors,
    WorkspaceController c,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.description_outlined, size: 18),
              const SizedBox(width: 8),
              const Text(
                'NOTES & RESOURCES',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                '${notes.length + canvases.length + files.length} items',
                style: TextStyle(fontSize: 13, color: colors.subtle),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (notes.isEmpty && canvases.isEmpty && files.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No notes or files tagged with this project.',
                  style: TextStyle(fontSize: 13, color: colors.subtle),
                ),
              ),
            )
          else ...[
            for (final note in notes.take(5))
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => c.openObject(note.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          note.title,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        note.updatedAt.toLocal().toString().split(' ').first,
                        style: TextStyle(fontSize: 13, color: colors.subtle),
                      ),
                    ],
                  ),
                ),
              ),
            for (final canvas in canvases.take(3))
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => c.openObject(canvas.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.dashboard_outlined, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          canvas.title,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'Canvas',
                        style: TextStyle(fontSize: 13, color: colors.subtle),
                      ),
                    ],
                  ),
                ),
              ),
            for (final file in files.take(3))
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => c.openObject(file.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          file.title,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'File',
                        style: TextStyle(fontSize: 13, color: colors.subtle),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivitySection(
    BuildContext context,
    List<UniversalObject> recent,
    OrbitColors colors,
    WorkspaceController c,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timeline_outlined, size: 18),
              SizedBox(width: 8),
              Text(
                'RECENT ACTIVITY',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No recent activity recorded.',
                  style: TextStyle(fontSize: 13, color: colors.subtle),
                ),
              ),
            )
          else
            for (final item in recent)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      item.typeId == 'orbit.task'
                          ? Icons.check_circle_outline
                          : item.typeId == 'orbit.note'
                          ? Icons.edit_outlined
                          : Icons.access_time,
                      size: 15,
                      color: colors.subtle,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => c.openObject(item.id),
                        child: Text(
                          item.title,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    Text(
                      '${item.updatedAt.toLocal().toString().split(' ').first} ${item.updatedAt.toLocal().hour.toString().padLeft(2, '0')}:${item.updatedAt.toLocal().minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 13, color: colors.subtle),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
