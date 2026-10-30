import '../../../app/orbit_components.dart';
import 'package:flutter/material.dart';
import '../../workspace/research_workspace_view.dart';
import '../../workspace/gantt_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/orbit_theme.dart';
import '../../../app/workspace_controller.dart';
import '../../../domain/universal_object.dart';
import 'snapshot_block.dart';

/// Configuration for an embedded Dynamic View inside a note (EDT-14).
/// Stored cleanly in Markdown as an ```orbit-view fenced code block.
class DynamicViewConfig {
  const DynamicViewConfig({
    this.type = 'tasks',
    this.project,
    this.folder,
    this.status = 'all',
    this.period = 'all',
    this.sort = 'modified',
    this.limit = 10,
    this.title,
    this.format = 'list',
    this.viewId,
  });

  final String
  type; // tasks, notes, recent_notes, related_notes, backlinks, activity, progress, upcoming, files, table
  final String? project;
  final String? folder;
  final String status; // all, open, completed
  final String period; // all, today, this_week, this_month
  final String sort; // modified, created, due, title
  final int limit;
  final String? title;
  final String format; // list, table
  final String? viewId;

  static DynamicViewConfig parse(String raw) {
    final map = <String, String>{};
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final idx = trimmed.indexOf(':');
      if (idx > 0) {
        final key = trimmed.substring(0, idx).trim().toLowerCase();
        final val = trimmed.substring(idx + 1).trim();
        map[key] = val;
      }
    }
    return DynamicViewConfig(
      type: map['type'] ?? 'tasks',
      project: map['project'],
      folder: map['folder'],
      status: map['status'] ?? 'all',
      period: map['period'] ?? 'all',
      sort: map['sort'] ?? 'modified',
      limit: int.tryParse(map['limit'] ?? '') ?? 10,
      title: map['title'],
      format: map['format'] ?? (map['type'] == 'table' ? 'table' : 'list'),
      viewId: map['view'] ?? map['viewid'],
    );
  }

  static DynamicViewConfig fromYaml(String raw) => parse(raw);

  String toYaml() {
    final buffer = StringBuffer();
    buffer.writeln('type: $type');
    if (title != null && title!.trim().isNotEmpty) {
      buffer.writeln('title: ${title!.trim()}');
    }
    if (project != null && project!.trim().isNotEmpty) {
      buffer.writeln('project: ${project!.trim()}');
    }
    if (folder != null && folder!.trim().isNotEmpty) {
      buffer.writeln('folder: ${folder!.trim()}');
    }
    if (format != 'list') buffer.writeln('format: $format');
    if (viewId != null && viewId!.trim().isNotEmpty) {
      buffer.writeln('view: ${viewId!.trim()}');
    }
    if (status != 'all') buffer.writeln('status: $status');
    if (period != 'all') buffer.writeln('period: $period');
    if (sort != 'modified') buffer.writeln('sort: $sort');
    if (limit != 10) buffer.writeln('limit: $limit');
    return buffer.toString().trim();
  }

  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('```orbit-view');
    buffer.writeln('type: $type');
    if (title != null && title!.trim().isNotEmpty) {
      buffer.writeln('title: ${title!.trim()}');
    }
    if (project != null && project!.trim().isNotEmpty) {
      buffer.writeln('project: ${project!.trim()}');
    }
    if (folder != null && folder!.trim().isNotEmpty) {
      buffer.writeln('folder: ${folder!.trim()}');
    }
    if (format != 'list') buffer.writeln('format: $format');
    if (viewId != null && viewId!.trim().isNotEmpty) {
      buffer.writeln('view: ${viewId!.trim()}');
    }
    if (status != 'all') buffer.writeln('status: $status');
    if (period != 'all') buffer.writeln('period: $period');
    if (sort != 'modified') buffer.writeln('sort: $sort');
    if (limit != 10) buffer.writeln('limit: $limit');
    buffer.write('```');
    return buffer.toString();
  }

  DynamicViewConfig copyWith({
    String? type,
    String? project,
    String? folder,
    String? status,
    String? period,
    String? sort,
    int? limit,
    String? title,
    String? format,
    String? viewId,
  }) => DynamicViewConfig(
    type: type ?? this.type,
    project: project ?? this.project,
    folder: folder ?? this.folder,
    status: status ?? this.status,
    period: period ?? this.period,
    sort: sort ?? this.sort,
    limit: limit ?? this.limit,
    title: title ?? this.title,
    format: format ?? this.format,
    viewId: viewId ?? this.viewId,
  );
}

/// An interactive, query-backed Dynamic View block embedded in Markdown.
class DynamicViewBlock extends ConsumerStatefulWidget {
  const DynamicViewBlock({
    super.key,
    required this.source,
    required this.onChanged,
    this.controller,
    this.noteId,
  });

  final String source;
  final ValueChanged<String> onChanged;
  final WorkspaceController? controller;
  final String? noteId;

  static bool isDynamicView(String language, String content) =>
      language == 'orbit-view' || language == 'view';

  @override
  ConsumerState<DynamicViewBlock> createState() => _DynamicViewBlockState();
}

class _DynamicViewBlockState extends ConsumerState<DynamicViewBlock> {
  late DynamicViewConfig _config;

  @override
  void initState() {
    super.initState();
    _config = DynamicViewConfig.parse(widget.source);
  }

  @override
  void didUpdateWidget(covariant DynamicViewBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _config = DynamicViewConfig.parse(widget.source);
    }
  }

  WorkspaceController? _getController() {
    if (widget.controller != null) return widget.controller;
    try {
      return ref.read(workspaceProvider.notifier);
    } catch (_) {
      return null;
    }
  }

  void _updateConfig(DynamicViewConfig newConfig) {
    setState(() => _config = newConfig);
    widget.onChanged(newConfig.toMarkdown());
  }

  void _freezeAsSnapshot(List<UniversalObject> currentItems) {
    final now = DateTime.now().toUtc();
    final snapshotItems = <SnapshotItem>[];
    for (final item in currentItems) {
      if (item.typeId == 'orbit.task') {
        snapshotItems.add(
          SnapshotItem(
            text: item.title,
            completed: item.isCompleted,
            objectId: item.id,
            meta: item.properties['project']?.toString(),
          ),
        );
      } else {
        snapshotItems.add(
          SnapshotItem(
            text: item.title,
            objectId: item.id,
            meta: item.typeId.replaceFirst('orbit.', ''),
          ),
        );
      }
    }

    final snapshotConfig = SnapshotConfig(
      type: _config.type,
      title: _config.title ?? _defaultHeaderTitle(_config.type),
      frozenAt: now.toIso8601String(),
      items: snapshotItems,
    );

    widget.onChanged(snapshotConfig.toMarkdown());
  }

  String _defaultHeaderTitle(String type) => switch (type) {
    'table' => 'Structured Table',
    'tasks' => 'Tasks',
    'notes' || 'recent_notes' => 'Recent Notes',
    'related_notes' || 'backlinks' => 'Related Notes & Backlinks',
    'activity' => 'Recent Activity',
    'progress' || 'project_progress' => 'Project Progress',
    'upcoming' || 'calendar' => 'Upcoming Deadlines & Events',
    'files' => 'Files & Attachments',
    _ => 'Dynamic View',
  };

  IconData _defaultIcon(String type) => switch (type) {
    'table' => Icons.table_chart_outlined,
    'tasks' => Icons.checklist_outlined,
    'notes' || 'recent_notes' => Icons.description_outlined,
    'related_notes' || 'backlinks' => Icons.hub_outlined,
    'activity' => Icons.timeline_outlined,
    'progress' || 'project_progress' => Icons.donut_large_outlined,
    'upcoming' || 'calendar' => Icons.event_outlined,
    'files' => Icons.attach_file_outlined,
    _ => Icons.widgets_outlined,
  };

  void _showConfigDialog(BuildContext context) {
    final c = _getController();
    final availableProjects =
        c?.activeObjects
            .map((o) => o.properties['project']?.toString())
            .whereType<String>()
            .where((p) => p.trim().isNotEmpty)
            .toSet()
            .toList() ??
        [];
    availableProjects.sort();

    var tempType = _config.type;
    var tempProject = _config.project;
    var tempStatus = _config.status;
    var tempPeriod = _config.period;
    var tempSort = _config.sort;
    var tempLimit = _config.limit;

    showOrbitDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          final colors = OrbitColors.of(dialogCtx);
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.tune, size: 20, color: colors.accent),
                const SizedBox(width: 8),
                const Text('Configure Dynamic View'),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // View Type
                    const Text(
                      'VIEW TYPE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: tempType,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'tasks',
                          child: Text('Tasks Checklist'),
                        ),
                        DropdownMenuItem(
                          value: 'recent_notes',
                          child: Text('Recent Notes'),
                        ),
                        DropdownMenuItem(
                          value: 'related_notes',
                          child: Text('Related Notes (Semantic / Tags)'),
                        ),
                        DropdownMenuItem(
                          value: 'backlinks',
                          child: Text('Backlinks'),
                        ),
                        DropdownMenuItem(
                          value: 'activity',
                          child: Text('Recent Activity Log'),
                        ),
                        DropdownMenuItem(
                          value: 'progress',
                          child: Text('Project Progress Bar'),
                        ),
                        DropdownMenuItem(
                          value: 'upcoming',
                          child: Text('Upcoming Deadlines'),
                        ),
                        DropdownMenuItem(
                          value: 'files',
                          child: Text('Attached Files'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setModalState(() => tempType = v);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Project Filter
                    const Text(
                      'PROJECT FILTER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      initialValue: tempProject,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Projects'),
                        ),
                        for (final p in availableProjects)
                          DropdownMenuItem(value: p, child: Text(p)),
                      ],
                      onChanged: (v) => setModalState(() => tempProject = v),
                    ),
                    const SizedBox(height: 16),

                    // Status (for tasks)
                    if (tempType == 'tasks' || tempType == 'progress') ...[
                      const Text(
                        'STATUS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: tempStatus,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('All Tasks'),
                          ),
                          DropdownMenuItem(
                            value: 'open',
                            child: Text('Open / Incomplete Only'),
                          ),
                          DropdownMenuItem(
                            value: 'completed',
                            child: Text('Completed Only'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setModalState(() => tempStatus = v);
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Period
                    const Text(
                      'TIME PERIOD',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: tempPeriod,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Any Time')),
                        DropdownMenuItem(value: 'today', child: Text('Today')),
                        DropdownMenuItem(
                          value: 'this_week',
                          child: Text('This Week'),
                        ),
                        DropdownMenuItem(
                          value: 'this_month',
                          child: Text('This Month'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setModalState(() => tempPeriod = v);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Limit
                    Row(
                      children: [
                        const Text(
                          'Max items to display: ',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: tempLimit,
                          items: const [
                            DropdownMenuItem(value: 5, child: Text('5')),
                            DropdownMenuItem(value: 10, child: Text('10')),
                            DropdownMenuItem(value: 20, child: Text('20')),
                            DropdownMenuItem(value: 50, child: Text('50')),
                          ],
                          onChanged: (v) {
                            if (v != null) setModalState(() => tempLimit = v);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  _updateConfig(
                    _config.copyWith(
                      type: tempType,
                      project: tempProject,
                      status: tempStatus,
                      period: tempPeriod,
                      sort: tempSort,
                      limit: tempLimit,
                    ),
                  );
                },
                child: const Text('Save View'),
              ),
            ],
          );
        },
      ),
    );
  }

  List<UniversalObject> _queryObjects(WorkspaceController? c) {
    if (c == null) return [];
    var pool = c.activeObjects;
    var savedQuery = false;
    if (_config.viewId != null) {
      final definition = c.find(_config.viewId!);
      if (definition?.properties['smartQuery'] != null) {
        try {
          pool = c.queryViewObjects(definition!);
          savedQuery = true;
        } on Object {
          return [];
        }
      }
    }

    // Filter by project
    if (_config.project != null && _config.project!.trim().isNotEmpty) {
      final p = _config.project!.trim().toLowerCase();
      pool = pool.where((o) {
        final proj = o.properties['project']?.toString().toLowerCase();
        return proj == p;
      }).toList();
    }

    // Filter by folder
    if (_config.folder != null && _config.folder!.trim().isNotEmpty) {
      final f = _config.folder!.trim();
      pool = pool.where((o) {
        final folderProp = o.properties['folder']?.toString();
        return folderProp == f ||
            (folderProp != null && folderProp.startsWith('$f/'));
      }).toList();
    }

    // Filter by time period
    final now = DateTime.now();
    if (_config.period == 'today') {
      final start = DateTime(now.year, now.month, now.day);
      pool = pool.where((o) => o.updatedAt.isAfter(start)).toList();
    } else if (_config.period == 'this_week') {
      final start = now.subtract(Duration(days: now.weekday - 1));
      final weekStart = DateTime(start.year, start.month, start.day);
      pool = pool.where((o) => o.updatedAt.isAfter(weekStart)).toList();
    } else if (_config.period == 'this_month') {
      final monthStart = DateTime(now.year, now.month, 1);
      pool = pool.where((o) => o.updatedAt.isAfter(monthStart)).toList();
    }

    // Filter by saved view (if referencing a saved view)
    if (_config.viewId != null) {
      final savedView = c.find(_config.viewId!);
      if (savedView != null) {
        final memberIds = savedView.properties['memberIds'];
        if (memberIds is List) {
          final idSet = memberIds.map((e) => e.toString()).toSet();
          pool = pool.where((o) => idSet.contains(o.id)).toList();
        } else {
          final svFolder = savedView.properties['folder']?.toString();
          if (svFolder != null && svFolder.isNotEmpty) {
            pool = pool.where((o) {
              final fp = o.properties['folder']?.toString();
              return fp == svFolder ||
                  (fp != null && fp.startsWith('$svFolder/'));
            }).toList();
          }
        }
      }
    }

    // Filter by type
    switch (_config.type) {
      case 'table':
        var tableItems = pool.toList();
        if (_config.status == 'open') {
          tableItems = tableItems.where((t) => !t.isCompleted).toList();
        } else if (_config.status == 'completed') {
          tableItems = tableItems.where((t) => t.isCompleted).toList();
        }
        if (!savedQuery) {
          tableItems.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        }
        return tableItems.take(_config.limit).toList();

      case 'tasks':
        var tasks = pool.where((o) => o.typeId == 'orbit.task').toList();
        if (_config.status == 'open') {
          tasks = tasks.where((t) => !t.isCompleted).toList();
        } else if (_config.status == 'completed') {
          tasks = tasks.where((t) => t.isCompleted).toList();
        }
        if (!savedQuery) {
          tasks.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        }
        return tasks.take(_config.limit).toList();

      case 'notes':
      case 'recent_notes':
        final notes = pool.where((o) => o.typeId == 'orbit.note').toList();
        if (!savedQuery) {
          notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        }
        return notes.take(_config.limit).toList();

      case 'related_notes':
      case 'backlinks':
        if (widget.noteId != null) {
          final targetId = widget.noteId!;
          final related = pool.where((o) {
            if (o.id == targetId) return false;
            if (o.body.contains(targetId)) return true;
            final targetObj = c.find(targetId);
            if (targetObj != null && targetObj.title.isNotEmpty) {
              if (o.body.contains('[[${targetObj.title}]]') ||
                  o.body.contains('[[${targetObj.title}|')) {
                return true;
              }
            }
            return false;
          }).toList();
          if (!savedQuery) {
            related.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          }
          return related.take(_config.limit).toList();
        }
        final notes = pool.where((o) => o.typeId == 'orbit.note').toList();
        if (!savedQuery) {
          notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        }
        return notes.take(_config.limit).toList();

      case 'activity':
        final recents = pool.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return recents.take(_config.limit).toList();

      case 'progress':
      case 'project_progress':
        return pool.where((o) => o.typeId == 'orbit.task').toList();

      case 'upcoming':
      case 'calendar':
        final tasksWithDue = pool.where((o) {
          if (o.typeId != 'orbit.task' || o.isCompleted) return false;
          final due = o.properties['dueDate'] ?? o.properties['scheduledDate'];
          return due != null && due.toString().isNotEmpty;
        }).toList();
        if (!savedQuery) {
          tasksWithDue.sort((a, b) {
            final dueA = a.properties['dueDate']?.toString() ?? '';
            final dueB = b.properties['dueDate']?.toString() ?? '';
            return dueA.compareTo(dueB);
          });
        }
        return tasksWithDue.take(_config.limit).toList();

      case 'files':
        final files = pool.where((o) => o.typeId == 'orbit.file').toList();
        if (!savedQuery) {
          files.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        }
        return files.take(_config.limit).toList();

      default:
        return pool.take(_config.limit).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      ref.watch(workspaceProvider);
    } catch (_) {}
    final colors = OrbitColors.of(context);
    final c = _getController();
    final researchView = c?.find(_config.viewId);
    if (c != null && researchView?.properties['viewType'] == 'research') {
      return SizedBox(
        height: 600,
        child: ResearchWorkspaceView(controller: c, view: researchView!),
      );
    }
    if (c != null && researchView?.properties['viewType'] == 'gantt') {
      return SizedBox(
        height: 600,
        child: GanttView(controller: c, view: researchView!),
      );
    }
    final items = _queryObjects(c);
    final definition = c?.find(_config.viewId);
    final queryIssue = definition?.properties['smartQuery'] != null
        ? c?.queryViewIssue(definition!)
        : null;
    final title =
        _config.title ?? definition?.title ?? _defaultHeaderTitle(_config.type);
    final icon = _defaultIcon(_config.type);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: colors.raised.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(OrbitRadius.card),
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: colors.panel,
              border: Border(
                bottom: BorderSide(color: colors.border.withValues(alpha: 0.5)),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: colors.accent),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_config.project != null &&
                    _config.project!.trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _config.project!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: colors.accent,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.raised,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${items.length}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colors.subtle,
                    ),
                  ),
                ),
                const Spacer(),
                // Freeze as Snapshot button
                IconButton(
                  tooltip: 'Freeze as Snapshot (Historical record)',
                  icon: const Icon(Icons.lock_clock_outlined, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  onPressed: items.isEmpty
                      ? null
                      : () => _freezeAsSnapshot(items),
                ),
                // Configure settings button
                IconButton(
                  tooltip: 'Configure dynamic view',
                  icon: const Icon(Icons.settings_outlined, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  onPressed: () => _showConfigDialog(context),
                ),
              ],
            ),
          ),

          // Content body
          Padding(
            padding: const EdgeInsets.all(12),
            child: queryIssue != null
                ? Text('$queryIssue\nThe saved definition is preserved.')
                : _buildBody(context, items, colors, c),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<UniversalObject> items,
    OrbitColors colors,
    WorkspaceController? c,
  ) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            'No matching items found for this view.',
            style: TextStyle(fontSize: 12, color: colors.subtle),
          ),
        ),
      );
    }

    if (_config.type == 'progress' || _config.type == 'project_progress') {
      final total = items.length;
      final completed = items.where((t) => t.isCompleted).length;
      final pct = total > 0 ? (completed / total) : 0.0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completed of $total tasks completed',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${(pct * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: colors.border.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation(colors.accent),
            ),
          ),
        ],
      );
    }

    if (_config.format == 'table' || _config.type == 'table') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
            decoration: BoxDecoration(
              color: colors.raised,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    'TITLE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: colors.subtle,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'STATUS / TYPE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: colors.subtle,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'UPDATED',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: colors.subtle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          for (final item in items)
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => c?.openObject(item.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Row(
                  children: [
                    if (item.typeId == 'orbit.task') ...[
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: Checkbox(
                          value: item.isCompleted,
                          onChanged: (checked) {
                            if (checked != null && c != null) {
                              c.edit(
                                item.id,
                                properties: {
                                  ...item.properties,
                                  'completed': checked,
                                  'status': checked ? 'done' : 'todo',
                                },
                              );
                              setState(() {});
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      flex: 5,
                      child: Text(
                        item.title.isEmpty ? 'Untitled' : item.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          decoration:
                              (item.typeId == 'orbit.task' && item.isCompleted)
                              ? TextDecoration.lineThrough
                              : null,
                          color:
                              (item.typeId == 'orbit.task' && item.isCompleted)
                              ? colors.subtle
                              : colors.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        (item.properties['status'] as String?) ??
                            (item.typeId == 'orbit.task'
                                ? (item.isCompleted ? 'done' : 'todo')
                                : item.typeId.replaceFirst('orbit.', '')),
                        style: TextStyle(fontSize: 11, color: colors.accent),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        item.updatedAt.toLocal().toString().split(' ').first,
                        textAlign: TextAlign.end,
                        style: TextStyle(fontSize: 11, color: colors.subtle),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    if (_config.type == 'tasks') {
      return Column(
        children: [
          for (final task in items)
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => c?.openObject(task.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: task.isCompleted,
                        onChanged: (checked) {
                          if (checked != null && c != null) {
                            c.edit(
                              task.id,
                              properties: {
                                ...task.properties,
                                'completed': checked,
                                'completedAt': checked
                                    ? DateTime.now().toIso8601String()
                                    : null,
                              },
                            );
                            setState(() {});
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 13,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.isCompleted ? colors.subtle : colors.text,
                        ),
                      ),
                    ),
                    if (task.properties['project'] != null)
                      Text(
                        '${task.properties['project']}',
                        style: TextStyle(fontSize: 11, color: colors.subtle),
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    // Default list for notes, activity, upcoming, files
    return Column(
      children: [
        for (final item in items)
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => c?.openObject(item.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              child: Row(
                children: [
                  Icon(
                    item.typeId == 'orbit.note'
                        ? Icons.description_outlined
                        : item.typeId == 'orbit.canvas'
                        ? Icons.dashboard_outlined
                        : item.typeId == 'orbit.file'
                        ? Icons.attach_file
                        : Icons.circle_outlined,
                    size: 15,
                    color: colors.subtle,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    item.updatedAt.toLocal().toString().split(' ').first,
                    style: TextStyle(fontSize: 11, color: colors.subtle),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
