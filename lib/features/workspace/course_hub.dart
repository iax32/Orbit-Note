import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/workspace_controller.dart';
import '../../domain/course_progress.dart';
import '../../domain/universal_object.dart';
import 'calendar_planning_workspace.dart';
import 'study_workspace.dart';

Future<void> showCourseHub(BuildContext context, WorkspaceController c) =>
    showDialog<void>(
      context: context,
      builder: (_) => CourseHub(controller: c),
    );

class CourseHub extends ConsumerStatefulWidget {
  const CourseHub({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  ConsumerState<CourseHub> createState() => _CourseHubState();
}

class _CourseHubState extends ConsumerState<CourseHub> {
  String _query = '', _status = 'active', _semester = '', _kind = 'all';
  String? _selected, _notice;
  bool _busy = false;
  int _limit = 40;

  Future<void> _details([UniversalObject? course]) async {
    final c = widget.controller;
    final generation = c.workspaceGeneration;
    final name = TextEditingController(
      text: course == null ? '' : c.courseName(course),
    );
    final code = TextEditingController(
      text: '${course?.properties['courseCode'] ?? ''}',
    );
    final semester = TextEditingController(
      text: '${course?.properties['semester'] ?? ''}',
    );
    final credits = TextEditingController(
      text: '${course?.properties['ects'] ?? 5}',
    );
    final lecturer = TextEditingController(
      text: '${course?.properties['lecturer'] ?? ''}',
    );
    var status = '${course?.properties['courseStatus'] ?? 'active'}';
    if (!{'active', 'passed', 'archived'}.contains(status)) status = 'active';
    final form = GlobalKey<FormState>();
    Map<String, dynamic>? result;
    try {
      result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => AlertDialog(
            title: Text(
              course == null ? 'Add university course' : 'Course details',
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Form(
                  key: form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: name,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Course name',
                        ),
                        maxLength: 120,
                        validator: (s) => s == null || s.trim().isEmpty
                            ? 'Enter a name'
                            : null,
                      ),
                      TextFormField(
                        controller: code,
                        decoration: const InputDecoration(
                          labelText: 'Course code',
                        ),
                      ),
                      TextFormField(
                        controller: semester,
                        decoration: const InputDecoration(
                          labelText: 'Semester',
                          hintText: 'e.g. Winter 2026/27',
                        ),
                      ),
                      TextFormField(
                        controller: credits,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'ECTS credits',
                        ),
                        validator: (s) {
                          final value = num.tryParse(s ?? '');
                          return value == null ||
                                  !value.isFinite ||
                                  value < 0 ||
                                  value > 120
                              ? 'Enter credits from 0 to 120'
                              : null;
                        },
                      ),
                      TextFormField(
                        controller: lecturer,
                        decoration: const InputDecoration(
                          labelText: 'Lecturer',
                        ),
                      ),
                      if (course != null)
                        DropdownButtonFormField<String>(
                          initialValue: status,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Course status',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'active',
                              child: Text('Active'),
                            ),
                            DropdownMenuItem(
                              value: 'passed',
                              child: Text('Passed'),
                            ),
                            DropdownMenuItem(
                              value: 'archived',
                              child: Text('Archived'),
                            ),
                          ],
                          onChanged: (v) => update(() => status = v ?? status),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        course == null
                            ? 'Creates an overview, lecture, practice Canvas, and linked task, board, calendar and timeline views. Everything remains editable.'
                            : 'Changing the display name keeps existing course links and folder paths. Archive hides the course from Active; its material remains available.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (form.currentState!.validate()) {
                    Navigator.pop(ctx, {
                      'courseDisplayName': name.text.trim(),
                      'courseCode': code.text.trim(),
                      'semester': semester.text.trim(),
                      'ects': num.parse(credits.text),
                      'lecturer': lecturer.text.trim(),
                      'courseStatus': status,
                    });
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    } finally {
      // Dialog route dismissal completes before its fields are disposed.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final text in [name, code, semester, credits, lecturer]) {
          text.dispose();
        }
      });
    }
    if (result == null || !mounted || generation != c.workspaceGeneration) {
      return;
    }
    setState(() {
      _busy = true;
      _notice = null;
    });
    if (course == null) {
      final created = await c.createUniversityCourse(
        result['courseDisplayName'] as String,
        semester: result['semester'] as String,
        ects: result['ects'] as num,
        courseCode: result['courseCode'] as String,
        lecturer: result['lecturer'] as String,
      );
      if (!mounted) return;
      setState(() {
        _selected = created?.id ?? _selected;
        _notice = created == null
            ? c.error
            : 'Course added. Open the overview to write your goals.';
        _busy = false;
      });
    } else {
      final saved = await c.saveCourseDetails(course, result);
      if (!mounted) return;
      setState(() {
        _notice = saved
            ? 'Course details saved.'
            : c.error ?? 'Could not save course details.';
        _busy = false;
      });
    }
  }

  Future<void> _add(UniversalObject course, String kind) async {
    final c = widget.controller,
        generation = widget.controller.workspaceGeneration;
    final title = TextEditingController(), due = TextEditingController();
    final form = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Add ${kind == 'note'
              ? 'lecture note'
              : kind == 'exercise'
              ? 'practice Canvas'
              : 'assignment'}',
        ),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: title,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (s) =>
                        s == null || s.trim().isEmpty ? 'Enter a title' : null,
                  ),
                  if (kind == 'assignment')
                    TextFormField(
                      controller: due,
                      decoration: const InputDecoration(
                        labelText: 'Deadline (optional)',
                        hintText: 'YYYY-MM-DD',
                      ),
                      validator: (s) {
                        if (s == null || s.trim().isEmpty) return null;
                        final parsed = DateTime.tryParse(s.trim());
                        return parsed == null ||
                                !RegExp(
                                  r'^\d{4}-\d{2}-\d{2}$',
                                ).hasMatch(s.trim()) ||
                                '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}' !=
                                    s.trim()
                            ? 'Use a valid YYYY-MM-DD date'
                            : null;
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final label = title.text, date = due.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      title.dispose();
      due.dispose();
    });
    if (accepted != true || !mounted || generation != c.workspaceGeneration) {
      return;
    }
    setState(() => _busy = true);
    final item = await c.addCourseMaterial(
      course.id,
      kind,
      label,
      dueDate: date.isEmpty ? null : date,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _notice = item == null
          ? c.error ?? 'Could not add material.'
          : 'Added ${item.title}.';
    });
  }

  Future<void> _link(UniversalObject course) async {
    final c = widget.controller,
        generation = widget.controller.workspaceGeneration;
    var query = '';
    final selected = await showDialog<UniversalObject>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) {
          final candidates = c.activeObjects
              .where(
                (o) =>
                    o.properties['isCourseOverview'] != true &&
                    !o.isReadOnly &&
                    !belongsToCourse(o, course) &&
                    o.title.toLowerCase().contains(query),
              )
              .take(50)
              .toList();
          return AlertDialog(
            title: const Text('Link existing material'),
            content: SizedBox(
              width: 580,
              height: 420,
              child: Column(
                children: [
                  const Text(
                    'Links the original object. If it belongs to another course, choosing it reassigns its course; its files and content stay intact.',
                  ),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search material',
                    ),
                    onChanged: (v) => update(() => query = v.toLowerCase()),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final item in candidates)
                          ListTile(
                            title: Text(item.title),
                            subtitle: Text(
                              '${item.typeId.replaceFirst('orbit.', '')} · ${item.properties['course'] ?? 'Unassigned'}',
                            ),
                            onTap: () => Navigator.pop(ctx, item),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
    if (selected == null || !mounted || generation != c.workspaceGeneration) {
      return;
    }
    final saved = await c.linkCourseMaterial(course.id, selected);
    if (mounted) {
      setState(
        () => _notice = saved
            ? 'Material linked.'
            : c.error ?? 'Material changed. Try linking it again.',
      );
    }
  }

  Widget _metric(String label, int done, int total) => SizedBox(
    width: 180,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        Text(total == 0 ? 'No records yet' : '$done of $total'),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: total == 0 ? 0 : done / total),
      ],
    ),
  );

  Widget _courseDetails(UniversalObject course) {
    final c = widget.controller,
        progress = CourseProgress(course, widget.controller.objects);
    final members =
        progress.members
            .where((o) => _kind == 'all' || o.typeId == _kind)
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final editable = !course.isReadOnly && !c.repository.readOnly;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          c.courseName(course),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(
          '${course.properties['courseCode'] ?? ''} · ${course.properties['semester'] ?? 'Semester not set'} · ${course.properties['ects'] ?? 0} ECTS',
        ),
        if ('${course.properties['lecturer'] ?? ''}'.isNotEmpty)
          Text('Lecturer: ${course.properties['lecturer']}'),
        const SizedBox(height: 20),
        Wrap(
          spacing: 20,
          runSpacing: 16,
          children: [
            _metric(
              'Assignments & tasks',
              progress.completedTasks,
              progress.tasks,
            ),
            _metric(
              'Practice solved',
              progress.solvedExercises,
              progress.exercises,
            ),
            _metric(
              'Concepts understood',
              progress.understoodConcepts,
              progress.concepts,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${progress.overdue} overdue · ${progress.members.length} linked items. Progress reflects your recorded states, not an inferred grade.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () {
                c.openObject(course.id);
                Navigator.pop(context);
              },
              child: const Text('Open overview'),
            ),
            OutlinedButton(
              onPressed: _busy || !editable ? null : () => _details(course),
              child: const Text('Edit details'),
            ),
            OutlinedButton(
              onPressed: () => showStudyWorkspace(
                context,
                c,
                course: '${course.properties['course'] ?? ''}',
                courseId: course.id,
              ),
              child: const Text('Study & review'),
            ),
            OutlinedButton(
              onPressed: () => showCalendarPlanning(
                context,
                c,
                course: '${course.properties['course'] ?? ''}',
                courseId: course.id,
                scope: () => CourseProgress(
                  c.find(course.id) ?? course,
                  c.objects,
                ).members,
              ),
              child: const Text('Assignments & exams'),
            ),
            FilledButton.tonal(
              onPressed: _busy || !editable
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final board = await c.createCoursePlanningBoard(
                        course.id,
                      );
                      if (!mounted) return;
                      setState(() {
                        _busy = false;
                        _notice = board == null
                            ? c.error ?? 'Could not create the study board.'
                            : null;
                      });
                      if (board != null) {
                        c.openObject(board.id);
                        Navigator.pop(context);
                      }
                    },
              child: const Text('Open study board'),
            ),
          ],
        ),
        const Divider(height: 32),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: _busy || !editable ? null : () => _add(course, 'note'),
              icon: const Icon(Icons.note_add_outlined),
              label: const Text('Lecture'),
            ),
            TextButton.icon(
              onPressed: _busy || !editable
                  ? null
                  : () => _add(course, 'exercise'),
              icon: const Icon(Icons.dashboard_outlined),
              label: const Text('Practice Canvas'),
            ),
            TextButton.icon(
              onPressed: _busy || !editable
                  ? null
                  : () => _add(course, 'assignment'),
              icon: const Icon(Icons.task_alt),
              label: const Text('Assignment'),
            ),
            TextButton.icon(
              onPressed: _busy || !editable ? null : () => _link(course),
              icon: const Icon(Icons.link),
              label: const Text('Link material'),
            ),
          ],
        ),
        DropdownButtonFormField<String>(
          initialValue: _kind,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Material type'),
          items: [
            for (final entry in {
              'all': 'All material',
              'orbit.note': 'Notes',
              'orbit.task': 'Tasks',
              'orbit.canvas': 'Canvases',
              'orbit.file': 'Files',
              'orbit.view': 'Views',
            }.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (v) => setState(() {
            _kind = v ?? 'all';
            _limit = 40;
          }),
        ),
        if (members.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'No material in this category. Add or link something above.',
            ),
          ),
        for (final item in members.take(_limit))
          Card(
            child: ListTile(
              title: Text(item.title),
              subtitle: Text(
                '${item.typeId.replaceFirst('orbit.', '')}${item.properties['dueDate'] == null ? '' : ' · Due ${item.properties['dueDate']}'}',
              ),
              leading: item.typeId == 'orbit.task'
                  ? Checkbox(
                      value: item.isCompleted,
                      onChanged: !editable || item.isReadOnly
                          ? null
                          : (_) => c.edit(
                              item.id,
                              properties: {
                                ...c.find(item.id)!.properties,
                                'completed': !item.isCompleted,
                              },
                            ),
                    )
                  : Icon(
                      item.typeId == 'orbit.canvas'
                          ? Icons.dashboard_outlined
                          : Icons.description_outlined,
                    ),
              onTap: () {
                c.openObject(item.id);
                Navigator.pop(context);
              },
              trailing: PopupMenuButton<String>(
                tooltip: 'Material actions',
                onSelected: (v) async {
                  if (v == 'unlink') {
                    final removed = await c.linkCourseMaterial(
                      course.id,
                      item,
                      remove: true,
                    );
                    if (mounted) {
                      setState(
                        () => _notice = removed
                            ? 'Removed course membership. Original content is preserved.'
                            : 'Could not remove membership.',
                      );
                    }
                  }
                  if (v == 'solved' ||
                      v == 'review' ||
                      v == 'stuck' ||
                      v == 'not_started') {
                    c.edit(
                      item.id,
                      properties: {
                        ...c.find(item.id)!.properties,
                        'exerciseStatus': v,
                      },
                    );
                  }
                },
                itemBuilder: (_) => [
                  if (editable &&
                      !item.isReadOnly &&
                      item.properties.containsKey('exerciseStatus'))
                    for (final state in [
                      'not_started',
                      'stuck',
                      'review',
                      'solved',
                    ])
                      PopupMenuItem(
                        value: state,
                        child: Text('Practice: ${state.replaceAll('_', ' ')}'),
                      ),
                  if (editable && !item.isReadOnly)
                    const PopupMenuItem(
                      value: 'unlink',
                      child: Text('Remove from course'),
                    ),
                ],
              ),
            ),
          ),
        if (members.length > _limit)
          TextButton(
            onPressed: () => setState(() => _limit += 40),
            child: Text('Show more (${members.length - _limit} remaining)'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(workspaceProvider);
    final c = widget.controller, all = widget.controller.courses;
    if (_semester.isNotEmpty &&
        !all.any((o) => o.properties['semester'] == _semester)) {
      _semester = '';
    }
    final filtered = all
        .where(
          (o) =>
              (_status == 'all' ||
                  '${o.properties['courseStatus'] ?? 'active'}' == _status) &&
              (_semester.isEmpty || o.properties['semester'] == _semester) &&
              '${c.courseName(o)} ${o.properties['courseCode'] ?? ''} ${o.properties['lecturer'] ?? ''}'
                  .toLowerCase()
                  .contains(_query),
        )
        .toList();
    final selected =
        filtered.where((o) => o.id == _selected).firstOrNull ??
        filtered.firstOrNull;
    final semesters =
        all
            .map((o) => '${o.properties['semester'] ?? ''}')
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    num ects(UniversalObject o) =>
        o.properties['ects'] is num && (o.properties['ects'] as num).isFinite
        ? (o.properties['ects'] as num).clamp(0, 120)
        : 0;
    final earned = all
        .where((o) => o.properties['courseStatus'] == 'passed')
        .fold<num>(0, (n, o) => n + ects(o));
    final active = all
        .where((o) => (o.properties['courseStatus'] ?? 'active') == 'active')
        .fold<num>(0, (n, o) => n + ects(o));
    return Dialog(
      child: SizedBox(
        width: 1100,
        height: 820,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text(
                      'Courses',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(width: 16),
                    Text('$earned ECTS passed · $active ECTS active'),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: _busy || c.repository.readOnly
                          ? null
                          : () => _details(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add course'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SizedBox(
                      width: 260,
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Search courses',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) =>
                            setState(() => _query = v.toLowerCase()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: [
                          for (final s in [
                            'active',
                            'passed',
                            'archived',
                            'all',
                          ])
                            DropdownMenuItem(
                              value: s,
                              child: Text(s[0].toUpperCase() + s.substring(1)),
                            ),
                        ],
                        onChanged: (v) =>
                            setState(() => _status = v ?? 'active'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(semesters.join('|')),
                        initialValue: semesters.contains(_semester)
                            ? _semester
                            : '',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Semester',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('All semesters'),
                          ),
                          for (final s in semesters)
                            DropdownMenuItem(value: s, child: Text(s)),
                        ],
                        onChanged: (v) => setState(() => _semester = v ?? ''),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_notice != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 64),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_notice!, semanticsLabel: _notice),
                  ),
                ),
              ),
            Expanded(
              child: selected == null
                  ? Center(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            all.isEmpty
                                ? 'Add your first course. Keep lecture notes, practice, assignments and exam planning together.'
                                : 'No courses match these filters.',
                          ),
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow =
                            constraints.maxWidth /
                                MediaQuery.textScalerOf(context).scale(1) <
                            720;
                        if (narrow) {
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey(
                                    '${selected.id}:$_status:$_semester:$_query',
                                  ),
                                  initialValue: selected.id,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Selected course',
                                  ),
                                  items: [
                                    for (final o in filtered)
                                      DropdownMenuItem(
                                        value: o.id,
                                        child: Text(
                                          c.courseName(o),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: (v) => setState(() {
                                    _selected = v;
                                    _kind = 'all';
                                    _limit = 40;
                                  }),
                                ),
                              ),
                              Expanded(child: _courseDetails(selected)),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            SizedBox(
                              width: 280,
                              child: ListView(
                                children: [
                                  for (final o in filtered)
                                    ListTile(
                                      selected: o.id == selected.id,
                                      title: Text(c.courseName(o)),
                                      subtitle: Text(
                                        '${o.properties['semester'] ?? ''} · ${o.properties['ects'] ?? 0} ECTS',
                                      ),
                                      onTap: () => setState(() {
                                        _selected = o.id;
                                        _kind = 'all';
                                        _limit = 40;
                                      }),
                                    ),
                                ],
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(child: _courseDetails(selected)),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
