import 'package:flutter/material.dart';
import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';
import '../../domain/universal_object.dart';
import 'workspace_views.dart';

enum ExerciseFilter { all, unsolved, stuck, review, lowConfidence, solved }

class ExerciseTableView extends StatefulWidget {
  const ExerciseTableView({
    super.key,
    required this.controller,
    required this.viewObject,
    this.folderFilter,
    this.scope,
  });

  final WorkspaceController controller;
  final UniversalObject viewObject;
  final String? folderFilter;
  final String? scope;

  @override
  State<ExerciseTableView> createState() => _ExerciseTableViewState();
}

class _ExerciseTableViewState extends State<ExerciseTableView> {
  ExerciseFilter _activeFilter = ExerciseFilter.all;
  String? _selectedTopic;
  String _searchQuery = '';

  bool _matchesScope(UniversalObject o) {
    final folder = widget.folderFilter;
    final scope = widget.scope;
    if (folder != null && folder.isNotEmpty) {
      final f = o.properties['folder'];
      if (f is String && (f == folder || f.startsWith('$folder/'))) {
        return true;
      }
      final p = widget.controller.repository.objectPath(o.id);
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

  bool _isExercise(UniversalObject o) {
    if (o.isDeleted) return false;
    if (!_matchesScope(o)) return false;

    if (o.properties.containsKey('exerciseStatus') ||
        o.properties.containsKey('difficulty') ||
        o.properties.containsKey('confidence')) {
      return true;
    }

    final folder = o.properties['folder'] as String?;
    final p = widget.controller.repository.objectPath(o.id) ?? '';
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

  Future<void> _createNewExercise({required bool isCanvas}) async {
    final folder = widget.folderFilter != null
        ? (widget.folderFilter!.contains('Exercises')
              ? widget.folderFilter!
              : '${widget.folderFilter}/Exercises')
        : 'Exercises';
    final course = widget.scope ?? '';
    final count = widget.controller.objects.where(_isExercise).length + 1;
    final numStr = count.toString().padLeft(2, '0');
    final title = 'Exercise $numStr';

    if (isCanvas) {
      await widget.controller.createExerciseCanvas(
        folder: folder,
        title: title,
        course: course,
        topic: _selectedTopic ?? '',
      );
    } else {
      await widget.controller.create(
        'orbit.note',
        title: title,
        body:
            '''# $title
**Course:** ${course.isNotEmpty ? course : 'General'} | **Topic:** ${_selectedTopic ?? 'Topic'}

## Problem Statement
Write the exercise question or theorem to prove here.

## Scratchpad & Workings
> [!PROOF]
> Direct calculation and steps...

## Solution
> [!REMARK]
> Concluding result and notes.
''',
        properties: {
          'folder': folder,
          if (course.isNotEmpty) 'course': course,
          if (_selectedTopic != null) 'topic': _selectedTopic,
          'exerciseStatus': 'not_started',
          'difficulty': 'medium',
          'confidence': 'medium',
        },
      );
    }
  }

  void _updateExerciseProperty(UniversalObject o, String key, dynamic value) {
    widget.controller.edit(o.id, properties: {...o.properties, key: value});
  }

  Future<void> _promptEditTopic(UniversalObject o) async {
    final currentTopic = (o.properties['topic'] as String?) ?? '';
    final textCtrl = TextEditingController(text: currentTopic);

    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Topic'),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Relations, Limits, Topology',
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
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (res != null) {
      _updateExerciseProperty(o, 'topic', res);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final allExercises = widget.controller.objects.where(_isExercise).toList();

    // Extract all unique topics
    final topics = <String>{};
    for (final e in allExercises) {
      final t = e.properties['topic'] as String?;
      if (t != null && t.trim().isNotEmpty) {
        topics.add(t.trim());
      }
    }

    // Apply filtering
    final filtered = allExercises.where((e) {
      final status =
          (e.properties['exerciseStatus'] as String?) ?? 'not_started';
      final conf = (e.properties['confidence'] as String?) ?? 'medium';
      final topic = (e.properties['topic'] as String?) ?? '';

      // Topic filter
      if (_selectedTopic != null && _selectedTopic!.isNotEmpty) {
        if (topic.toLowerCase() != _selectedTopic!.toLowerCase()) {
          return false;
        }
      }

      // Search query
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final title = e.title.toLowerCase();
        if (!title.contains(q) && !topic.toLowerCase().contains(q)) {
          return false;
        }
      }

      // Quick filter
      return switch (_activeFilter) {
        ExerciseFilter.all => true,
        ExerciseFilter.unsolved => status != 'solved',
        ExerciseFilter.stuck => status == 'stuck',
        ExerciseFilter.review => status == 'review',
        ExerciseFilter.lowConfidence => conf == 'low',
        ExerciseFilter.solved => status == 'solved',
      };
    }).toList();

    // Sort: unsolved/stuck first, then title
    filtered.sort((a, b) {
      final aStatus =
          (a.properties['exerciseStatus'] as String?) ?? 'not_started';
      final bStatus =
          (b.properties['exerciseStatus'] as String?) ?? 'not_started';
      final aSolved = aStatus == 'solved' ? 1 : 0;
      final bSolved = bStatus == 'solved' ? 1 : 0;
      if (aSolved != bSolved) return aSolved.compareTo(bSolved);
      return a.title.compareTo(b.title);
    });

    // Counts for stats
    final totalCount = allExercises.length;
    final solvedCount = allExercises
        .where((e) => e.properties['exerciseStatus'] == 'solved')
        .length;
    final stuckCount = allExercises
        .where((e) => e.properties['exerciseStatus'] == 'stuck')
        .length;
    final reviewCount = allExercises
        .where((e) => e.properties['exerciseStatus'] == 'review')
        .length;
    final lowConfCount = allExercises
        .where((e) => e.properties['confidence'] == 'low')
        .length;
    final unsolvedCount = totalCount - solvedCount;

    final progressRatio = totalCount > 0 ? solvedCount / totalCount : 0.0;
    final progressPercent = (progressRatio * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Controls / Filters Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: colors.panel,
            border: Border(bottom: BorderSide(color: colors.divider)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Row 1: Actions, Stats & Search
              Row(
                children: [
                  // Progress badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.raised,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 60,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: progressRatio,
                              backgroundColor: colors.border,
                              valueColor: AlwaysStoppedAnimation(
                                colors.success,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$solvedCount / $totalCount Solved ($progressPercent%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Search box
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: TextStyle(fontSize: 12, color: colors.text),
                        decoration: InputDecoration(
                          hintText: 'Search exercises or topics...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: colors.subtle,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 16,
                            color: colors.subtle,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                            horizontal: 8,
                          ),
                          filled: true,
                          fillColor: colors.raised,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: colors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: colors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: colors.accent),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Create buttons
                  PopupMenuButton<String>(
                    tooltip: 'Add Exercise',
                    icon: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 14, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Add Exercise',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onSelected: (val) {
                      if (val == 'canvas') {
                        _createNewExercise(isCanvas: true);
                      } else {
                        _createNewExercise(isCanvas: false);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'canvas',
                        child: Row(
                          children: [
                            Icon(Icons.dashboard_outlined, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'New Exercise Canvas (Grid)',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'note',
                        child: Row(
                          children: [
                            Icon(Icons.description_outlined, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'New Exercise Note',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Row 2: Filter Pills & Topic dropdown
              Row(
                children: [
                  _FilterPill(
                    label: 'All',
                    count: totalCount,
                    selected: _activeFilter == ExerciseFilter.all,
                    onTap: () =>
                        setState(() => _activeFilter = ExerciseFilter.all),
                    colors: colors,
                  ),
                  const SizedBox(width: 6),
                  _FilterPill(
                    label: 'Unsolved',
                    count: unsolvedCount,
                    selected: _activeFilter == ExerciseFilter.unsolved,
                    onTap: () =>
                        setState(() => _activeFilter = ExerciseFilter.unsolved),
                    colors: colors,
                  ),
                  const SizedBox(width: 6),
                  _FilterPill(
                    label: 'Stuck',
                    count: stuckCount,
                    selected: _activeFilter == ExerciseFilter.stuck,
                    badgeColor: colors.danger,
                    onTap: () =>
                        setState(() => _activeFilter = ExerciseFilter.stuck),
                    colors: colors,
                  ),
                  const SizedBox(width: 6),
                  _FilterPill(
                    label: 'Needs Review',
                    count: reviewCount,
                    selected: _activeFilter == ExerciseFilter.review,
                    badgeColor: colors.accent,
                    onTap: () =>
                        setState(() => _activeFilter = ExerciseFilter.review),
                    colors: colors,
                  ),
                  const SizedBox(width: 6),
                  _FilterPill(
                    label: 'Low Confidence',
                    count: lowConfCount,
                    selected: _activeFilter == ExerciseFilter.lowConfidence,
                    badgeColor: colors.warning,
                    onTap: () => setState(
                      () => _activeFilter = ExerciseFilter.lowConfidence,
                    ),
                    colors: colors,
                  ),
                  const SizedBox(width: 6),
                  _FilterPill(
                    label: 'Solved',
                    count: solvedCount,
                    selected: _activeFilter == ExerciseFilter.solved,
                    badgeColor: colors.success,
                    onTap: () =>
                        setState(() => _activeFilter = ExerciseFilter.solved),
                    colors: colors,
                  ),

                  const Spacer(),

                  // Topic selector
                  if (topics.isNotEmpty) ...[
                    Text(
                      'Topic: ',
                      style: TextStyle(fontSize: 12, color: colors.subtle),
                    ),
                    const SizedBox(width: 4),
                    DropdownButton<String?>(
                      value: _selectedTopic,
                      underline: const SizedBox.shrink(),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        size: 16,
                        color: colors.subtle,
                      ),
                      style: TextStyle(fontSize: 12, color: colors.text),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Topics'),
                        ),
                        ...topics.map(
                          (t) => DropdownMenuItem<String?>(
                            value: t,
                            child: Text(t),
                          ),
                        ),
                      ],
                      onChanged: (val) => setState(() => _selectedTopic = val),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: colors.raised,
            border: Border(bottom: BorderSide(color: colors.divider)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  'EXERCISE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: colors.subtle,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'TOPIC',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: colors.subtle,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'STATUS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: colors.subtle,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'DIFFICULTY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: colors.subtle,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'CONFIDENCE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: colors.subtle,
                  ),
                ),
              ),
              SizedBox(
                width: 84,
                child: Text(
                  'ACTIONS',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: colors.subtle,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Table Body
        Expanded(
          child: filtered.isEmpty
              ? (allExercises.isEmpty
                    ? EmptyWorkspace(
                        icon: Icons.table_chart_outlined,
                        title: 'No exercises in this view',
                        description:
                            'Track sheets, exercises, difficulty, and confidence in one place.',
                        action: () => _createNewExercise(isCanvas: true),
                        label: 'Create Exercise Canvas',
                      )
                    : Center(
                        child: Text(
                          'No exercises match your filter.',
                          style: TextStyle(color: colors.subtle),
                        ),
                      ))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: filtered.length,
                  separatorBuilder: (ctx, i) => Divider(
                    height: 1,
                    thickness: 1,
                    color: colors.divider.withValues(alpha: 0.5),
                  ),
                  itemBuilder: (ctx, i) {
                    final e = filtered[i];
                    return _ExerciseRow(
                      exercise: e,
                      colors: colors,
                      onOpen: () => widget.controller.openObject(e.id),
                      onDelete: () => widget.controller.trash(e.id),
                      onEditTopic: () => _promptEditTopic(e),
                      onStatusChanged: (status) =>
                          _updateExerciseProperty(e, 'exerciseStatus', status),
                      onDifficultyChanged: (diff) =>
                          _updateExerciseProperty(e, 'difficulty', diff),
                      onConfidenceChanged: (conf) =>
                          _updateExerciseProperty(e, 'confidence', conf),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.exercise,
    required this.colors,
    required this.onOpen,
    required this.onDelete,
    required this.onEditTopic,
    required this.onStatusChanged,
    required this.onDifficultyChanged,
    required this.onConfidenceChanged,
  });

  final UniversalObject exercise;
  final OrbitColors colors;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback onEditTopic;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onDifficultyChanged;
  final ValueChanged<String> onConfidenceChanged;

  @override
  Widget build(BuildContext context) {
    final status =
        (exercise.properties['exerciseStatus'] as String?) ?? 'not_started';
    final difficulty =
        (exercise.properties['difficulty'] as String?) ?? 'medium';
    final confidence =
        (exercise.properties['confidence'] as String?) ?? 'medium';
    final topic = (exercise.properties['topic'] as String?) ?? '';
    final isCanvas = exercise.typeId == 'orbit.canvas';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          // Title + Icon
          Expanded(
            flex: 4,
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      isCanvas
                          ? Icons.dashboard_outlined
                          : Icons.description_outlined,
                      size: 16,
                      color: colors.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        exercise.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Topic
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: onEditTopic,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: topic.isNotEmpty
                        ? colors.raised
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: topic.isNotEmpty ? colors.border : colors.divider,
                      style: topic.isNotEmpty
                          ? BorderStyle.solid
                          : BorderStyle.none,
                    ),
                  ),
                  child: Text(
                    topic.isNotEmpty ? topic : '+ Add topic',
                    style: TextStyle(
                      fontSize: 12,
                      color: topic.isNotEmpty ? colors.text : colors.muted,
                      fontStyle: topic.isNotEmpty
                          ? FontStyle.normal
                          : FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),

          // Status Badge
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: PopupMenuButton<String>(
                initialValue: status,
                tooltip: 'Change Status',
                onSelected: onStatusChanged,
                child: _StatusBadge(status: status, colors: colors),
                itemBuilder: (ctx) => const [
                  PopupMenuItem(
                    value: 'not_started',
                    child: Text('Not Started'),
                  ),
                  PopupMenuItem(value: 'attempted', child: Text('Attempted')),
                  PopupMenuItem(value: 'stuck', child: Text('Stuck')),
                  PopupMenuItem(value: 'review', child: Text('Needs Review')),
                  PopupMenuItem(value: 'solved', child: Text('Solved')),
                ],
              ),
            ),
          ),

          // Difficulty Badge
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: PopupMenuButton<String>(
                initialValue: difficulty,
                tooltip: 'Change Difficulty',
                onSelected: onDifficultyChanged,
                child: _DifficultyBadge(difficulty: difficulty, colors: colors),
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'easy', child: Text('Easy')),
                  PopupMenuItem(value: 'medium', child: Text('Medium')),
                  PopupMenuItem(value: 'hard', child: Text('Hard')),
                ],
              ),
            ),
          ),

          // Confidence Badge
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: PopupMenuButton<String>(
                initialValue: confidence,
                tooltip: 'Change Confidence',
                onSelected: onConfidenceChanged,
                child: _ConfidenceBadge(confidence: confidence, colors: colors),
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'low', child: Text('Low Confidence')),
                  PopupMenuItem(
                    value: 'medium',
                    child: Text('Medium Confidence'),
                  ),
                  PopupMenuItem(value: 'high', child: Text('High Confidence')),
                ],
              ),
            ),
          ),

          // Actions
          SizedBox(
            width: 84,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Open',
                  icon: Icon(
                    Icons.arrow_forward,
                    size: 15,
                    color: colors.subtle,
                  ),
                  onPressed: onOpen,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
                IconButton(
                  tooltip: 'Trash',
                  icon: Icon(
                    Icons.delete_outline,
                    size: 15,
                    color: colors.subtle,
                  ),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.colors});
  final String status;
  final OrbitColors colors;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (status) {
      'attempted' => ('Attempted', Icons.access_time_rounded, colors.warning),
      'stuck' => ('Stuck', Icons.help_outline_rounded, colors.danger),
      'review' => ('Needs Review', Icons.sync_problem_rounded, colors.accent),
      'solved' => ('Solved', Icons.check_circle_rounded, colors.success),
      _ => ('Not Started', Icons.radio_button_unchecked, colors.subtle),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  const _DifficultyBadge({required this.difficulty, required this.colors});
  final String difficulty;
  final OrbitColors colors;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (difficulty) {
      'easy' => ('Easy', colors.success),
      'hard' => ('Hard', colors.danger),
      _ => ('Medium', colors.warning),
    };

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
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence, required this.colors});
  final String confidence;
  final OrbitColors colors;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (confidence) {
      'low' => ('Low', colors.danger),
      'high' => ('High', colors.success),
      _ => ('Medium', colors.warning),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    required this.colors,
    this.badgeColor,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final OrbitColors colors;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final activeColor = badgeColor ?? colors.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? activeColor.withValues(alpha: 0.5)
                : colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? activeColor : colors.subtle,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? activeColor : colors.raised,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : colors.subtle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
