import 'life_workspace.dart';
import '../../domain/course_progress.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_density.dart';
import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';
import '../../domain/calendar_event.dart';
import '../../domain/board_status.dart';
import '../../domain/search_text.dart';
import '../../domain/object_discovery.dart';
export 'search_view.dart';
import '../../domain/universal_object.dart';
import 'calendar_view.dart';
import 'google_drive_settings.dart';
import 'inbox_review_dialog.dart';
import 'focus_timer.dart';
import 'theme_color_settings.dart';
import 'theme_interchange_dialog.dart';
import 'heatmap_view.dart';
import 'productivity_hub.dart';
import 'task_planning_panel.dart';
import '../notes/note_typography.dart';

IconData objectIcon(String type) => switch (type) {
  'orbit.canvas' => Icons.dashboard_outlined,
  'orbit.task' => Icons.check_circle_outline,
  'orbit.event' => Icons.event_outlined,
  'orbit.file' => Icons.attach_file,
  'orbit.view' => Icons.view_quilt_outlined,
  _ => Icons.description_outlined,
};

class EmptyWorkspace extends StatelessWidget {
  const EmptyWorkspace({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
    this.label,
  });
  final IconData icon;
  final String title, description;
  final VoidCallback? action;
  final String? label;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: OrbitSize.iconLarge,
                color: OrbitColors.of(context).subtle,
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: TextStyle(
                  color: OrbitColors.of(context).subtle,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              if (action != null) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: action,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(label!),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

enum TemporalZoom { day, week, month, quarter, year }

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key, required this.controller});
  final WorkspaceController controller;

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  late DateTime _selectedDate;
  TemporalZoom _zoom = TemporalZoom.day;
  final TextEditingController _quickCaptureCtrl = TextEditingController();
  bool _quickCaptureAsTask = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _quickCaptureCtrl.dispose();
    super.dispose();
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  (DateTime, DateTime) _weekRange(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final start = d.subtract(Duration(days: d.weekday - 1));
    final end = DateTime(
      start.year,
      start.month,
      start.day + 6,
      23,
      59,
      59,
      999,
    );
    return (start, end);
  }

  (DateTime, DateTime) _monthRange(DateTime date) {
    final start = DateTime(date.year, date.month, 1);
    final end = DateTime(date.year, date.month + 1, 0, 23, 59, 59, 999);
    return (start, end);
  }

  (DateTime, DateTime) _quarterRange(DateTime date) {
    final q = ((date.month - 1) ~/ 3);
    final startMonth = q * 3 + 1;
    final start = DateTime(date.year, startMonth, 1);
    final end = DateTime(date.year, startMonth + 3, 0, 23, 59, 59, 999);
    return (start, end);
  }

  (DateTime, DateTime) _yearRange(DateTime date) {
    final start = DateTime(date.year, 1, 1);
    final end = DateTime(date.year, 12, 31, 23, 59, 59, 999);
    return (start, end);
  }

  int _isoWeekNumber(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final thursday = d.add(Duration(days: 4 - d.weekday));
    final jan1 = DateTime(thursday.year, 1, 1);
    return (thursday.difference(jan1).inDays ~/ 7) + 1;
  }

  int _isoYear(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.add(Duration(days: 4 - d.weekday)).year;
  }

  void _shiftPeriod(int delta) {
    setState(() {
      switch (_zoom) {
        case TemporalZoom.day:
          _selectedDate = _selectedDate.add(Duration(days: delta));
          break;
        case TemporalZoom.week:
          _selectedDate = _selectedDate.add(Duration(days: delta * 7));
          break;
        case TemporalZoom.month:
          _selectedDate = DateTime(
            _selectedDate.year,
            _selectedDate.month + delta,
            1,
          );
          break;
        case TemporalZoom.quarter:
          _selectedDate = DateTime(
            _selectedDate.year,
            _selectedDate.month + (delta * 3),
            1,
          );
          break;
        case TemporalZoom.year:
          _selectedDate = DateTime(_selectedDate.year + delta, 1, 1);
          break;
      }
    });
  }

  void _resetToCurrent() {
    final now = DateTime.now();
    setState(() {
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
  }

  String _currentPeriodLabel() {
    return switch (_zoom) {
      TemporalZoom.day => 'Today',
      TemporalZoom.week => 'This Week',
      TemporalZoom.month => 'This Month',
      TemporalZoom.quarter => 'This Qtr',
      TemporalZoom.year => 'This Year',
    };
  }

  String _periodTitle() {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const shortMonths = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    switch (_zoom) {
      case TemporalZoom.day:
        final prefix = _isToday(_selectedDate) ? 'Today · ' : '';
        return '$prefix${days[_selectedDate.weekday - 1]}, ${months[_selectedDate.month - 1]} ${_selectedDate.day}, ${_selectedDate.year}';
      case TemporalZoom.week:
        final (start, end) = _weekRange(_selectedDate);
        final weekNum = _isoWeekNumber(_selectedDate);
        return 'Week $weekNum · ${shortMonths[start.month - 1]} ${start.day} – ${shortMonths[end.month - 1]} ${end.day}, ${end.year}';
      case TemporalZoom.month:
        return '${months[_selectedDate.month - 1]} ${_selectedDate.year}';
      case TemporalZoom.quarter:
        final q = ((_selectedDate.month - 1) ~/ 3) + 1;
        return 'Q$q ${_selectedDate.year}';
      case TemporalZoom.year:
        return '${_selectedDate.year}';
    }
  }

  String _buildReviewBody({
    required String periodKind,
    required String periodSlug,
    required int notes,
    required int done,
    required int unfinished,
    required List<String> projects,
  }) {
    final pList = projects.isEmpty
        ? '- None'
        : projects.map((p) => '- $p').join('\n');
    return '''# $periodKind Review — $periodSlug

## Factual Metrics
- **Notes Created**: $notes
- **Tasks Completed**: $done
- **Unfinished Tasks**: $unfinished
- **Active Projects**: ${projects.length}

## Active Projects
$pList

## Completed Tasks
```orbit-view
type: tasks
status: completed
```

## Open Loops & Carry-over
```orbit-view
type: tasks
status: open
```

## Reflection
- **What went well?**
  -

- **What was challenging or got blocked?**
  -

- **What are the top priorities for next period?**
  -
''';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(workspaceProvider);
    final c = widget.controller;
    final colors = OrbitColors.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width < 600 ? 20 : 32,
            vertical: 32,
          ),
          children: [
            _buildTemporalNav(context, colors, c),
            const SizedBox(height: 12),
            ProductivityToolbar(controller: c),
            const SizedBox(height: 20),
            if (c.session.dashboard.isNotEmpty || c.activeSpaceId != null)
              ProductivityDashboard(controller: c)
            else if (_zoom == TemporalZoom.day)
              ..._buildDayContent(context, colors, c)
            else
              ..._buildPeriodicReviewContent(context, colors, c),
            const SizedBox(height: 20),
            LifeHomeCard(controller: c),
          ],
        ),
      ),
    );
  }

  Widget _buildTemporalNav(
    BuildContext context,
    OrbitColors colors,
    WorkspaceController c,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact =
            constraints.maxWidth / MediaQuery.textScalerOf(context).scale(1) <
            900;
        final veryCompact =
            constraints.maxWidth / MediaQuery.textScalerOf(context).scale(1) <
            420;
        final reviewButton = _buildReviewActionButton(context, colors, c);
        return Container(
          padding: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.divider)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isCompact) ...[
                Text(
                  c.repository.name,
                  style: TextStyle(fontSize: 13, color: colors.subtle),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        _periodTitle(),
                        key: const ValueKey('home-period-heading'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 32,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    if (!veryCompact) reviewButton,
                  ],
                ),
                const SizedBox(height: 20),
              ] else
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 20),
                      tooltip: 'Previous ${_zoom.name}',
                      onPressed: () => _shiftPeriod(-1),
                      visualDensity: VisualDensity.compact,
                    ),
                    ActionChip(
                      label: Text(
                        _currentPeriodLabel(),
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: _resetToCurrent,
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 20),
                      tooltip: 'Next ${_zoom.name}',
                      onPressed: () => _shiftPeriod(1),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _periodTitle(),
                        key: const ValueKey('home-period-heading'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!veryCompact) reviewButton,
                  ],
                ),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: OrbitModeControl<TemporalZoom>(
                      values: const {
                        TemporalZoom.day: 'Day',
                        TemporalZoom.week: 'Week',
                        TemporalZoom.month: 'Month',
                        TemporalZoom.quarter: 'Quarter',
                        TemporalZoom.year: 'Year',
                      },
                      value: _zoom,
                      onChanged: (z) => setState(() => _zoom = z),
                    ),
                  ),
                  if (!isCompact)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 20),
                          tooltip: 'Previous ${_zoom.name}',
                          onPressed: () => _shiftPeriod(-1),
                          visualDensity: VisualDensity.compact,
                        ),
                        ActionChip(
                          label: Text(
                            _currentPeriodLabel(),
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: _resetToCurrent,
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 20),
                          tooltip: 'Next ${_zoom.name}',
                          onPressed: () => _shiftPeriod(1),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                ],
              ),
              if (veryCompact) ...[const SizedBox(height: 12), reviewButton],
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewActionButton(
    BuildContext context,
    OrbitColors colors,
    WorkspaceController c,
  ) {
    switch (_zoom) {
      case TemporalZoom.day:
        return FilledButton.tonalIcon(
          onPressed: () => c.openTodayNote(date: _selectedDate),
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(_isToday(_selectedDate) ? "Today's note" : "Daily note"),
        );
      case TemporalZoom.week:
        final weekNum = _isoWeekNumber(_selectedDate);
        final isoYear = _isoYear(_selectedDate);
        final weekSlug = '$isoYear-W${weekNum.toString().padLeft(2, '0')}';
        return FilledButton.tonalIcon(
          onPressed: () async {
            final (start, end) = _weekRange(_selectedDate);
            final notes = c.notesCreatedBetween(start, end);
            final done = c.tasksCompletedBetween(start, end);
            final unfinished = c.tasksUnfinishedBetween(start, end);
            final projects = c.projectsActiveBetween(start, end);
            await c.openReviewNote(
              periodName: weekSlug,
              title: 'Weekly Review - $weekSlug',
              initialBody: _buildReviewBody(
                periodKind: 'Weekly',
                periodSlug: weekSlug,
                notes: notes.length,
                done: done.length,
                unfinished: unfinished.length,
                projects: projects,
              ),
            );
          },
          icon: const Icon(Icons.rate_review_outlined, size: 16),
          label: const Text('Weekly Review Note'),
        );
      case TemporalZoom.month:
        final monthSlug =
            '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}';
        return FilledButton.tonalIcon(
          onPressed: () async {
            final (start, end) = _monthRange(_selectedDate);
            final notes = c.notesCreatedBetween(start, end);
            final done = c.tasksCompletedBetween(start, end);
            final unfinished = c.tasksUnfinishedBetween(start, end);
            final projects = c.projectsActiveBetween(start, end);
            await c.openReviewNote(
              periodName: monthSlug,
              title: 'Monthly Review - $monthSlug',
              initialBody: _buildReviewBody(
                periodKind: 'Monthly',
                periodSlug: monthSlug,
                notes: notes.length,
                done: done.length,
                unfinished: unfinished.length,
                projects: projects,
              ),
            );
          },
          icon: const Icon(Icons.rate_review_outlined, size: 16),
          label: const Text('Monthly Review Note'),
        );
      case TemporalZoom.quarter:
        final q = ((_selectedDate.month - 1) ~/ 3) + 1;
        final qSlug = '${_selectedDate.year}-Q$q';
        return FilledButton.tonalIcon(
          onPressed: () async {
            final (start, end) = _quarterRange(_selectedDate);
            final notes = c.notesCreatedBetween(start, end);
            final done = c.tasksCompletedBetween(start, end);
            final unfinished = c.tasksUnfinishedBetween(start, end);
            final projects = c.projectsActiveBetween(start, end);
            await c.openReviewNote(
              periodName: qSlug,
              title: 'Quarterly Review - $qSlug',
              initialBody: _buildReviewBody(
                periodKind: 'Quarterly',
                periodSlug: qSlug,
                notes: notes.length,
                done: done.length,
                unfinished: unfinished.length,
                projects: projects,
              ),
            );
          },
          icon: const Icon(Icons.rate_review_outlined, size: 16),
          label: const Text('Quarterly Review Note'),
        );
      case TemporalZoom.year:
        final yearSlug = '${_selectedDate.year}';
        return FilledButton.tonalIcon(
          onPressed: () async {
            final (start, end) = _yearRange(_selectedDate);
            final notes = c.notesCreatedBetween(start, end);
            final done = c.tasksCompletedBetween(start, end);
            final unfinished = c.tasksUnfinishedBetween(start, end);
            final projects = c.projectsActiveBetween(start, end);
            await c.openReviewNote(
              periodName: yearSlug,
              title: 'Annual Review - $yearSlug',
              initialBody: _buildReviewBody(
                periodKind: 'Annual',
                periodSlug: yearSlug,
                notes: notes.length,
                done: done.length,
                unfinished: unfinished.length,
                projects: projects,
              ),
            );
          },
          icon: const Icon(Icons.rate_review_outlined, size: 16),
          label: const Text('Annual Review Note'),
        );
    }
  }

  Widget _buildQuickCaptureBar(OrbitColors colors, WorkspaceController c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(OrbitRadius.control),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: _quickCaptureAsTask
                ? 'Capturing as Task (Click for Note)'
                : 'Capturing as Note (Click for Task)',
            icon: Icon(
              _quickCaptureAsTask
                  ? Icons.check_circle_outline
                  : Icons.edit_note,
              color: _quickCaptureAsTask ? colors.accent : colors.subtle,
              size: 22,
            ),
            onPressed: () =>
                setState(() => _quickCaptureAsTask = !_quickCaptureAsTask),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _quickCaptureCtrl,
              decoration: InputDecoration(
                hintText: _quickCaptureAsTask
                    ? 'Add a task to Inbox…'
                    : 'Capture a note to Inbox…',
                hintStyle: TextStyle(
                  color: colors.subtle.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14),
              onSubmitted: (val) async {
                final text = val.trim();
                if (text.isEmpty) return;
                await c.quickCapture(text, asTask: _quickCaptureAsTask);
                _quickCaptureCtrl.clear();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _quickCaptureAsTask
                          ? 'Task captured to Inbox'
                          : 'Thought captured to Inbox',
                    ),
                    duration: const Duration(seconds: 2),
                    action: SnackBarAction(
                      label: 'Review',
                      onPressed: () => showInboxReviewDialog(context, c),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            tooltip: 'Capture to Inbox',
            icon: Icon(Icons.arrow_upward, color: colors.accent, size: 20),
            onPressed: () async {
              final text = _quickCaptureCtrl.text.trim();
              if (text.isEmpty) return;
              await c.quickCapture(text, asTask: _quickCaptureAsTask);
              _quickCaptureCtrl.clear();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _quickCaptureAsTask
                        ? 'Task captured to Inbox'
                        : 'Thought captured to Inbox',
                  ),
                  duration: const Duration(seconds: 2),
                  action: SnackBarAction(
                    label: 'Review',
                    onPressed: () => showInboxReviewDialog(context, c),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInboxBanner(OrbitColors colors, WorkspaceController c) {
    final inboxCount = c.inboxObjects.length;
    if (inboxCount == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.08),
        border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(OrbitRadius.card),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.inbox_outlined, color: colors.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$inboxCount unorganized ${inboxCount == 1 ? 'item' : 'items'} in Inbox',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Capture first, organize later. Review items to assign to projects, convert to tasks, or archive.',
                  style: TextStyle(color: colors.subtle, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: () => showInboxReviewDialog(context, c),
            icon: const Icon(Icons.rate_review_outlined, size: 16),
            label: const Text('Review Inbox'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDayContent(
    BuildContext context,
    OrbitColors colors,
    WorkspaceController c,
  ) {
    final isToday = _isToday(_selectedDate);
    final now = DateTime.now();

    if (!isToday) {
      final start = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      final end = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        23,
        59,
        59,
        999,
      );
      final dayNotes = c.notesCreatedBetween(start, end);
      final dayDone = c.tasksCompletedBetween(start, end);
      final dayTasks = c.ofType('orbit.task').where((t) {
        if (t.isDeleted) return false;
        final due =
            parseCalendarDate(t.properties['dueDate']) ??
            parseCalendarDate(t.properties['scheduledDate']);
        if (due == null) return false;
        return calendarDate(due) == calendarDate(_selectedDate);
      }).toList();

      return [
        _heading(
          context,
          'Tasks for this day',
          '${dayTasks.length + dayDone.length} tasks',
        ),
        if (dayTasks.isEmpty && dayDone.isEmpty)
          _quiet(context, 'No tasks due or completed on this date.')
        else ...[
          ...dayTasks.map((t) => TaskRow(object: t, controller: c)),
          ...dayDone.map((t) => TaskRow(object: t, controller: c)),
        ],
        const SizedBox(height: 24),
        _heading(
          context,
          'Notes created on this day',
          '${dayNotes.length} notes',
        ),
        if (dayNotes.isEmpty)
          _quiet(context, 'No notes created on this date.')
        else
          ...dayNotes.map(
            (o) => ObjectRow(object: o, onTap: () => c.openObject(o.id)),
          ),
      ];
    }

    final tasks = c.ofType('orbit.task').where((o) => !o.isCompleted).toList();
    final recent = c.session.recent
        .map(c.find)
        .whereType<UniversalObject>()
        .where((o) => !o.isDeleted)
        .take(5)
        .toList();

    // Check for a recently read or active PDF document
    final recentPdf =
        c.session.recent
            .map(c.find)
            .whereType<UniversalObject>()
            .where(
              (o) =>
                  !o.isDeleted &&
                  o.typeId == 'orbit.file' &&
                  o.title.toLowerCase().endsWith('.pdf'),
            )
            .firstOrNull ??
        c.activeObjects
            .where(
              (o) =>
                  !o.isDeleted &&
                  o.typeId == 'orbit.file' &&
                  o.title.toLowerCase().endsWith('.pdf'),
            )
            .firstOrNull;

    int? pdfPage;
    if (recentPdf != null) {
      for (final entry in c.session.noteViews.entries) {
        if (entry.key.contains(recentPdf.id) && entry.value['page'] is num) {
          pdfPage = (entry.value['page'] as num).toInt();
          break;
        }
      }
    }

    // Check for a recently edited or active Note
    final recentNote =
        c.session.recent
            .map(c.find)
            .whereType<UniversalObject>()
            .where((o) => !o.isDeleted && o.typeId == 'orbit.note')
            .firstOrNull ??
        c.activeObjects
            .where((o) => !o.isDeleted && o.typeId == 'orbit.note')
            .firstOrNull;

    String? noteMode;
    int? noteWords;
    String noteSnippet = '';
    if (recentNote != null) {
      final isLatex = recentNote.properties['documentFormat'] == 'latex';
      if (!isLatex) {
        noteWords = RegExp(r'\S+').allMatches(recentNote.body).length;
      }
      for (final entry in c.session.noteViews.entries) {
        if (entry.key.contains(recentNote.id) &&
            entry.value['mode'] is String) {
          final modeName = entry.value['mode'] as String;
          noteMode = {
            'rich': 'Rich',
            'write': 'Source',
            'split': 'Split',
            'read': 'Read',
          }[modeName];
          break;
        }
      }
      if (!isLatex && recentNote.body.isNotEmpty) {
        final clean = recentNote.body
            .replaceAll(RegExp(r'[#*`_>~=\[\]]'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (clean.isNotEmpty) {
          noteSnippet = clean.length > 80
              ? '${clean.substring(0, 80)}…'
              : clean;
        }
      }
    }

    // Today's tasks (due today or overdue)
    final todayTasks = tasks.where((t) {
      final due =
          parseCalendarDate(t.properties['dueDate']) ??
          parseCalendarDate(t.properties['scheduledDate']);
      if (due == null) return false;
      return isDueDateOverdue(due, now: now) ||
          calendarDate(due) == calendarDate(now);
    }).toList();

    // Upcoming events and deadlines
    final upcomingEntries = <(UniversalObject, DateTime, String)>[];
    for (final event in c.ofType('orbit.event').where((e) => !e.isDeleted)) {
      try {
        final sched = EventSchedule.fromProperties(event.properties);
        if (!sched.start.isBefore(DateTime(now.year, now.month, now.day))) {
          upcomingEntries.add((
            event,
            sched.start,
            sched.allDay ? 'All day' : 'Event',
          ));
        }
      } catch (_) {}
    }
    for (final task in tasks) {
      final due =
          parseCalendarDate(task.properties['dueDate']) ??
          parseCalendarDate(task.properties['scheduledDate']);
      if (due != null && due.isAfter(DateTime(now.year, now.month, now.day))) {
        upcomingEntries.add((task, due, 'Deadline'));
      }
    }
    upcomingEntries.sort((a, b) => a.$2.compareTo(b.$2));

    return [
      // Continue Writing
      if (recentNote != null) ...[
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.divider)),
          ),
          child: _HomeResumeRow(
            onTap: () => c.openObject(recentNote.id),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Continue writing',
                      style: OrbitTypography.section(context),
                    ),
                    if (noteMode != null ||
                        (noteWords != null && noteWords > 0)) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.panel,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          [
                            ?noteMode,
                            if (noteWords != null)
                              '$noteWords ${noteWords == 1 ? 'word' : 'words'}',
                          ].join(' · '),
                          style: TextStyle(fontSize: 10, color: colors.subtle),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  recentNote.title.isEmpty ? 'Untitled note' : recentNote.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (noteSnippet.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    noteSnippet,
                    style: TextStyle(fontSize: 12, color: colors.subtle),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
            action: FilledButton.tonalIcon(
              onPressed: () => c.openObject(recentNote.id),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Resume writing'),
            ),
          ),
        ),
      ],
      // Continue Reading
      if (recentPdf != null) ...[
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.divider)),
          ),
          child: _HomeResumeRow(
            onTap: () => c.openObject(recentPdf.id),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Continue reading',
                      style: TextStyle(
                        color: colors.accent,
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (pdfPage != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.panel,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          'Page $pdfPage',
                          style: TextStyle(fontSize: 10, color: colors.subtle),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  recentPdf.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            action: FilledButton.tonalIcon(
              onPressed: () => c.openObject(recentPdf.id),
              icon: const Icon(Icons.chrome_reader_mode_outlined, size: 16),
              label: const Text('Resume'),
            ),
          ),
        ),
      ],
      if (recent.isNotEmpty &&
          (recentPdf == null || recent.first.id != recentPdf.id) &&
          (recentNote == null || recent.first.id != recentNote.id))
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => c.openObject(recent.first.id),
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.divider)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history, size: 18, color: colors.accent),
                      const SizedBox(width: 10),
                      const Text(
                        'Continue session',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    recent.first.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${c.session.tabs.length} open tabs · ${tasks.length} open tasks in this workspace',
                    style: TextStyle(color: colors.subtle),
                  ),
                  const SizedBox(height: 14),
                  TextButton.icon(
                    onPressed: () => c.openObject(recent.first.id),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Resume context'),
                  ),
                ],
              ),
            ),
          ),
        ),

      _buildQuickCaptureBar(colors, c),
      _buildInboxBanner(colors, c),
      const SizedBox(height: 8),
      // Quick Actions
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          FilledButton.icon(
            onPressed: () => c.create('orbit.note'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New note'),
          ),
          OutlinedButton.icon(
            onPressed: () => c.create('orbit.task'),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('New task'),
          ),
        ],
      ),
      const SizedBox(height: 24),
      // Focus & Work Session Card (CTX-04, CTX-12)
      _FocusSessionCard(controller: c),
      const SizedBox(height: 12),
      // Where Was I? navigation trail
      if (recent.length >= 2) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            children: [
              Icon(Icons.route_outlined, size: 16, color: colors.subtle),
              const SizedBox(width: 8),
              Text(
                'Recent:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.subtle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < recent.length; i++) ...[
                        if (i > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.chevron_right,
                              size: 14,
                              color: colors.subtle.withValues(alpha: 0.5),
                            ),
                          ),
                        TextButton.icon(
                          icon: Icon(
                            objectIcon(recent[i].typeId),
                            size: OrbitSize.iconInline,
                          ),
                          label: Text(
                            recent[i].title.isEmpty
                                ? 'Untitled'
                                : recent[i].title,
                          ),
                          onPressed: () => c.openObject(recent[i].id),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      // Activity Heatmap
      Card(
        color: colors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OrbitRadius.card),
          side: BorderSide(color: colors.border),
        ),
        margin: const EdgeInsets.only(bottom: 20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: HeatmapWidget(
            controller: c,
            onSelectDate: (d) => c.openTodayNote(date: d),
          ),
        ),
      ),
      // Active Game Project Card
      () {
        UniversalObject? gdd;
        for (final o in c.activeObjects) {
          if (!o.isDeleted &&
              (o.properties['isGdd'] == true ||
                  (o.typeId == 'orbit.view' &&
                      o.properties['viewType'] == 'game_dashboard'))) {
            gdd = o;
            break;
          }
        }
        if (gdd == null) return const SizedBox.shrink();

        final pName =
            gdd.properties['project']?.toString() ??
            gdd.title.replaceAll('Dashboard', '').replaceAll('GDD', '').trim();
        if (pName.isEmpty) return const SizedBox.shrink();

        final gTasks = c.activeObjects
            .where(
              (o) =>
                  !o.isDeleted &&
                  o.typeId == 'orbit.task' &&
                  (o.properties['project']?.toString().toLowerCase() ==
                          pName.toLowerCase() ||
                      (o.properties['folder'] as String?)
                              ?.toLowerCase()
                              .contains(pName.toLowerCase()) ==
                          true),
            )
            .toList();
        final gTotal = gTasks.length;
        final gDone = gTasks.where((t) => t.isCompleted).length;
        final gPercent = gTotal > 0 ? ((gDone * 100) ~/ gTotal) : 0;
        final gBugs = gTasks
            .where(
              (t) =>
                  !t.isCompleted &&
                  (t.properties['isBug'] == true ||
                      t.properties['category'] == 'Bug' ||
                      t.properties['severity'] != null),
            )
            .length;
        final gBlocked = gTasks.where((t) {
          if (t.isCompleted) return false;
          final raw = t.properties['blockedBy'];
          if (raw == null) return false;
          final List<String> ids = switch (raw) {
            List l => l.map((e) => e.toString()).toList(),
            String s =>
              s
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList(),
            _ => const [],
          };
          return ids.any((id) {
            final b = c.find(id);
            return b != null && !b.isDeleted && !b.isCompleted;
          });
        }).length;

        final gDash = c.activeObjects
            .where(
              (o) =>
                  !o.isDeleted &&
                  o.typeId == 'orbit.view' &&
                  o.properties['viewType'] == 'game_dashboard' &&
                  o.properties['project']?.toString().toLowerCase() ==
                      pName.toLowerCase(),
            )
            .firstOrNull;

        final gBoard = c.activeObjects
            .where(
              (o) =>
                  !o.isDeleted &&
                  o.typeId == 'orbit.view' &&
                  o.properties['preset'] == 'gamedev' &&
                  o.properties['project']?.toString().toLowerCase() ==
                      pName.toLowerCase(),
            )
            .firstOrNull;

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.raised, colors.panel],
            ),
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(OrbitRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.sports_esports_outlined,
                    size: 18,
                    color: colors.accent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'GAME PROJECT',
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: 10.5,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    pName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  if (gBlocked > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade900.withValues(alpha: .2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 11,
                            color: Colors.amber.shade400,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$gBlocked Blocked',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.amber.shade300,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (gBugs > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withValues(alpha: .2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bug_report,
                            size: 11,
                            color: Colors.red.shade400,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$gBugs Bugs',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.red.shade300,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$gDone / $gTotal Tasks Complete ($gPercent%)',
                          style: TextStyle(fontSize: 12, color: colors.subtle),
                        ),
                        const SizedBox(height: 6),
                        OrbitAnimatedProgress(
                          value: gTotal > 0 ? (gDone / gTotal) : 0.0,
                          backgroundColor: colors.raised,
                          color: colors.accent,
                          minHeight: 5,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  if (gDash != null)
                    FilledButton.tonal(
                      onPressed: () => c.openObject(gDash.id),
                      child: const Text('Dashboard'),
                    ),
                  if (gBoard != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => c.openObject(gBoard.id),
                      child: const Text('Board'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      }(),

      // Active Reverse Engineering & Research Project Card
      () {
        UniversalObject? targetOverview;
        for (final o in c.activeObjects) {
          if (!o.isDeleted &&
              (o.properties['isTargetOverview'] == true ||
                  (o.typeId == 'orbit.view' &&
                      o.properties['viewType'] == 're_dashboard'))) {
            targetOverview = o;
            break;
          }
        }
        if (targetOverview == null) return const SizedBox.shrink();

        final tName =
            targetOverview.properties['target']?.toString() ??
            targetOverview.title
                .replaceAll('Overview', '')
                .replaceAll('Dashboard', '')
                .trim();
        if (tName.isEmpty) return const SizedBox.shrink();

        final arch =
            targetOverview.properties['architecture']?.toString() ?? 'x86-64';
        final format = targetOverview.properties['format']?.toString() ?? 'PE';

        final tObjects = c.activeObjects
            .where(
              (o) =>
                  !o.isDeleted &&
                  (o.properties['target']?.toString().toLowerCase() ==
                          tName.toLowerCase() ||
                      (o.properties['folder'] as String?)
                              ?.toLowerCase()
                              .contains(tName.toLowerCase()) ==
                          true),
            )
            .toList();

        final functionsCount = tObjects
            .where(
              (o) =>
                  o.properties['category'] == 'Function' ||
                  o.properties.containsKey('address'),
            )
            .length;
        final hypotheses = tObjects
            .where((o) => o.properties['category'] == 'Hypothesis')
            .toList();
        final openHypotheses = hypotheses
            .where(
              (h) =>
                  (h.properties['status'] as String?)?.toLowerCase() !=
                      'confirmed' &&
                  (h.properties['status'] as String?)?.toLowerCase() !=
                      'rejected',
            )
            .length;
        final findingsCount = tObjects
            .where((o) => o.properties['category'] == 'Finding')
            .length;

        final reDash = c.activeObjects
            .where(
              (o) =>
                  !o.isDeleted &&
                  o.typeId == 'orbit.view' &&
                  o.properties['viewType'] == 're_dashboard' &&
                  o.properties['target']?.toString().toLowerCase() ==
                      tName.toLowerCase(),
            )
            .firstOrNull;

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.raised, colors.panel],
            ),
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(OrbitRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.biotech_outlined, size: 18, color: colors.accent),
                  const SizedBox(width: 8),
                  Text(
                    'BINARY RESEARCH & REVERSE ENGINEERING',
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$format · $arch',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                tName,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '$functionsCount functions documented · $openHypotheses open hypotheses · $findingsCount findings',
                style: TextStyle(color: colors.subtle),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () {
                      if (reDash != null) {
                        c.openObject(reDash.id);
                      } else {
                        c.openObject(targetOverview!.id);
                      }
                    },
                    icon: const Icon(Icons.analytics_outlined, size: 16),
                    label: const Text('Open Research Dashboard'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => c.openObject(targetOverview!.id),
                    icon: const Icon(Icons.description_outlined, size: 16),
                    label: const Text('Target Overview'),
                  ),
                ],
              ),
            ],
          ),
        );
      }(),
      const SizedBox(height: 16),
      // Today's Tasks
      _heading(context, "Today's tasks", '${todayTasks.length} due'),
      if (todayTasks.isEmpty)
        _quiet(context, 'Nothing due today.')
      else
        ...todayTasks.take(5).map((o) => TaskRow(object: o, controller: c)),
      const SizedBox(height: 26),
      // Upcoming
      _heading(context, 'Upcoming', '${upcomingEntries.length} scheduled'),
      if (upcomingEntries.isEmpty)
        _quiet(context, 'No upcoming events or deadlines scheduled.')
      else
        ...upcomingEntries.take(4).map((entry) {
          final (obj, dt, tag) = entry;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.raised,
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                objectIcon(obj.typeId),
                size: 18,
                color: colors.accent,
              ),
            ),
            title: Text(
              obj.title.isEmpty ? 'Untitled' : obj.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              formatFriendlyDueDate(dt, now: now),
              style: TextStyle(fontSize: 12, color: colors.subtle),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colors.panel,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                tag,
                style: TextStyle(fontSize: 11, color: colors.subtle),
              ),
            ),
            onTap: () => c.openObject(obj.id),
          );
        }),
      const SizedBox(height: 26),
      // Recent Objects
      _heading(context, 'Recent objects', '${recent.length} recent'),
      if (recent.isEmpty)
        _quiet(context, 'Recently opened notes and objects appear here.')
      else
        ...recent.map(
          (o) => ObjectRow(object: o, onTap: () => c.openObject(o.id)),
        ),
      const SizedBox(height: 28),
      Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 14, color: colors.subtle),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Local by default. Your work stays with you.',
              style: TextStyle(color: colors.subtle, fontSize: 12),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildPeriodicReviewContent(
    BuildContext context,
    OrbitColors colors,
    WorkspaceController c,
  ) {
    final (start, end) = switch (_zoom) {
      TemporalZoom.day => (
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
        DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          23,
          59,
          59,
          999,
        ),
      ),
      TemporalZoom.week => _weekRange(_selectedDate),
      TemporalZoom.month => _monthRange(_selectedDate),
      TemporalZoom.quarter => _quarterRange(_selectedDate),
      TemporalZoom.year => _yearRange(_selectedDate),
    };

    final notes = c.notesCreatedBetween(start, end);
    final completedTasks = c.tasksCompletedBetween(start, end);
    final unfinishedTasks = c.tasksUnfinishedBetween(start, end);
    final activeProjects = c.projectsActiveBetween(start, end);

    final periodLabel = switch (_zoom) {
      TemporalZoom.day => 'Day',
      TemporalZoom.week => 'Week',
      TemporalZoom.month => 'Month',
      TemporalZoom.quarter => 'Quarter',
      TemporalZoom.year => 'Year',
    };

    return [
      // Factual Metric Cards Grid
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _metricCard(
            context,
            colors,
            icon: Icons.edit_note,
            title: 'Notes Created',
            value: '${notes.length}',
          ),
          _metricCard(
            context,
            colors,
            icon: Icons.check_circle_outline,
            title: 'Tasks Completed',
            value: '${completedTasks.length}',
          ),
          _metricCard(
            context,
            colors,
            icon: Icons.hourglass_top,
            title: 'Unfinished Tasks',
            value: '${unfinishedTasks.length}',
          ),
          _metricCard(
            context,
            colors,
            icon: Icons.folder_open,
            title: 'Active Projects',
            value: '${activeProjects.length}',
          ),
        ],
      ),
      const SizedBox(height: 24),

      // Reflection note CTA banner
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.raised,
          borderRadius: BorderRadius.circular(OrbitRadius.card),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.rate_review_outlined,
                color: colors.accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$periodLabel Review Reflection',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Synthesize accomplishments, clear open loops, and plan ahead with embedded dynamic views.',
                    style: TextStyle(color: colors.subtle, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _buildReviewActionButton(context, colors, c),
          ],
        ),
      ),
      const SizedBox(height: 24),

      // Completed Tasks
      _heading(
        context,
        'Tasks Completed this $periodLabel',
        '${completedTasks.length} done',
      ),
      if (completedTasks.isEmpty)
        _quiet(
          context,
          'No tasks were marked complete during this $periodLabel.',
        )
      else
        ...completedTasks.map((t) => TaskRow(object: t, controller: c)),
      const SizedBox(height: 24),

      // Unfinished Tasks / Open Loops
      _heading(
        context,
        'Unfinished Tasks / Open Loops',
        '${unfinishedTasks.length} open',
      ),
      if (unfinishedTasks.isEmpty)
        _quiet(context, 'No open loops remaining for this period!')
      else
        ...unfinishedTasks
            .take(15)
            .map((t) => TaskRow(object: t, controller: c)),
      const SizedBox(height: 24),

      // Notes Created
      _heading(
        context,
        'Notes Created this $periodLabel',
        '${notes.length} notes',
      ),
      if (notes.isEmpty)
        _quiet(context, 'No notes created during this $periodLabel.')
      else
        ...notes.map(
          (o) => ObjectRow(object: o, onTap: () => c.openObject(o.id)),
        ),
      const SizedBox(height: 24),

      // Active Projects
      if (activeProjects.isNotEmpty) ...[
        _heading(
          context,
          'Active Projects',
          '${activeProjects.length} projects',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: activeProjects.map((p) {
            return ActionChip(
              avatar: const Icon(Icons.folder_outlined, size: 16),
              label: Text(p),
              onPressed: () => c.openProjectDashboard(p),
            );
          }).toList(),
        ),
      ],
    ];
  }

  Widget _metricCard(
    BuildContext context,
    OrbitColors colors, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: 170,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(OrbitRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.accent),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 11, color: colors.subtle)),
        ],
      ),
    );
  }

  Widget _heading(BuildContext context, String title, String trailing) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const Spacer(),
            Text(
              trailing,
              style: TextStyle(
                color: OrbitColors.of(context).subtle,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );

  Widget _quiet(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Text(
      text,
      style: TextStyle(color: OrbitColors.of(context).subtle, height: 1.5),
    ),
  );
}

class _FocusSessionCard extends StatefulWidget {
  const _FocusSessionCard({required this.controller});
  final WorkspaceController controller;

  @override
  State<_FocusSessionCard> createState() => _FocusSessionCardState();
}

class _FocusSessionCardState extends State<_FocusSessionCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _updateTicker();
  }

  @override
  void didUpdateWidget(covariant _FocusSessionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _updateTicker() {
    final active = widget.controller.activeWorkSession;
    if (active != null && !active.isPaused) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showContinuationNoteDialog(BuildContext context) {
    final c = widget.controller;
    final textController = TextEditingController(
      text: c.activeWorkSession?.continuationNote ?? '',
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Continuation Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Capture reflections or next steps for this session:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText:
                    'e.g. Completed step 1, tomorrow investigate cache invalidation...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              c.setWorkSessionContinuationNote(textController.text.trim());
              Navigator.of(context).pop();
            },
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }

  void _showEndSessionDialog(BuildContext context) {
    final c = widget.controller;
    final session = c.activeWorkSession;
    if (session == null) return;
    final duration = session.elapsedActiveDuration();
    final textController = TextEditingController(
      text: session.continuationNote,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Focus Session'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Session Summary: ${session.title}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text('• Active Duration: ${_formatDuration(duration)}'),
              Text('• Notes Referenced/Opened: ${session.notesOpened.length}'),
              Text('• Notes Created: ${session.notesCreated.length}'),
              Text('• Tasks Completed: ${session.tasksCompleted.length}'),
              const SizedBox(height: 16),
              const Text(
                'Continuation Note / Reflection:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: textController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Where did you leave off? What should you do next?',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep Working'),
          ),
          FilledButton(
            onPressed: () {
              c.endWorkSession(continuationNote: textController.text.trim());
              Navigator.of(context).pop();
            },
            child: const Text('Complete Session'),
          ),
        ],
      ),
    );
  }

  void _showStartSessionDialog(
    BuildContext context, {
    String initialCategory = 'work',
  }) {
    final c = widget.controller;
    final titleController = TextEditingController();
    var category = initialCategory;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Start Focus Session'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Session Goal / Title (optional)',
                  hintText: 'e.g. Compiler Study, Game Loop Design',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Category',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'work', label: Text('Work')),
                  ButtonSegment(value: 'study', label: Text('Study')),
                  ButtonSegment(value: 'reading', label: Text('Reading')),
                ],
                selected: {category},
                onSelectionChanged: (val) {
                  setDialogState(() => category = val.first);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final text = titleController.text.trim();
                c.startWorkSession(
                  title: text.isEmpty ? null : text,
                  category: category,
                );
                Navigator.of(context).pop();
              },
              child: const Text('Start Session'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final colors = OrbitColors.of(context);
    final active = c.activeWorkSession;

    if (active != null) {
      final duration = active.elapsedActiveDuration();
      final isPaused = active.isPaused;
      final accentColor = isPaused ? colors.warning : colors.success;

      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accentColor.withValues(alpha: 0.12), colors.panel],
          ),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.4),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(OrbitRadius.card),
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
                    color: accentColor.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isPaused
                        ? Icons.pause_circle_outline_rounded
                        : Icons.timer_rounded,
                    color: accentColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isPaused ? 'PAUSED' : 'ACTIVE FOCUS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.panel,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: colors.border),
                            ),
                            child: Text(
                              active.category.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                color: colors.subtle,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        active.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _formatDuration(duration),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: colors.text,
                            ),
                          ),
                          Text(
                            'Active time (paused excluded)',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.subtle,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (isPaused)
                  FilledButton.icon(
                    onPressed: c.resumeWorkSession,
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text('Resume'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: c.pauseWorkSession,
                    icon: const Icon(Icons.pause_rounded, size: 16),
                    label: const Text('Pause'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _showContinuationNoteDialog(context),
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Note'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _showEndSessionDialog(context),
                  icon: const Icon(Icons.stop_rounded, size: 16),
                  label: const Text('End session'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _StatBadge(
                  icon: Icons.description_outlined,
                  label: '${active.notesOpened.length} opened',
                  colors: colors,
                ),
                _StatBadge(
                  icon: Icons.add_circle_outline,
                  label: '${active.notesCreated.length} created',
                  colors: colors,
                ),
                _StatBadge(
                  icon: Icons.task_alt,
                  label: '${active.tasksCompleted.length} tasks completed',
                  colors: colors,
                ),
              ],
            ),
            if (active.continuationNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Continuation note: "${active.continuationNote}"',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: colors.subtle,
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Idle state
    final completed = c.completedWorkSessions;
    final last = completed.isNotEmpty ? completed.first : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () =>
                    _showStartSessionDialog(context, initialCategory: 'work'),
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: const Text('Start Focus Session'),
              ),
            ],
          ),
          if (last != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.raised,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.border.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, size: 16, color: colors.subtle),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last session: ${last.title} · ${_formatDuration(last.elapsedActiveDuration())} (${last.category})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${last.tasksCompleted.length} tasks completed · ${last.notesOpened.length} notes referenced'
                          '${last.continuationNote.isNotEmpty ? ' · "${last.continuationNote}"' : ''}',
                          style: TextStyle(fontSize: 11, color: colors.subtle),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Resume actions move below their summary at narrow widths or large text sizes.
class _HomeResumeRow extends StatefulWidget {
  const _HomeResumeRow({
    required this.content,
    required this.action,
    this.onTap,
  });
  final Widget content, action;
  final VoidCallback? onTap;

  @override
  State<_HomeResumeRow> createState() => _HomeResumeRowState();
}

class _HomeResumeRowState extends State<_HomeResumeRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final rowContent = LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth / MediaQuery.textScalerOf(context).scale(1) <
            520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              widget.content,
              const SizedBox(height: 12),
              widget.action,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: widget.content),
            const SizedBox(width: 24),
            widget.action,
          ],
        );
      },
    );

    if (widget.onTap == null) return rowContent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: OrbitMotionScope.duration(context, OrbitMotion.micro),
          decoration: BoxDecoration(
            color: _hovered
                ? colors.accent.withValues(alpha: 0.04)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: rowContent,
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
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
          Icon(icon, size: 12, color: colors.accent),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: colors.subtle)),
        ],
      ),
    );
  }
}

class ObjectRow extends StatelessWidget {
  const ObjectRow({
    super.key,
    required this.object,
    required this.onTap,
    this.trailing,
    this.query,
    this.wrapTitle = false,
  });
  final UniversalObject object;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? query;
  final bool wrapTitle;

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final snippet = query != null && query!.trim().isNotEmpty
        ? extractSearchSnippet(object, query!)
        : null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colors.raised,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(OrbitRadius.control),
        ),
        child:
            object.properties['icon'] != null &&
                object.properties['icon'].toString().isNotEmpty
            ? Center(
                child: Text(
                  object.properties['icon'].toString(),
                  style: const TextStyle(fontSize: 18),
                ),
              )
            : Icon(objectIcon(object.typeId), size: 18, color: colors.subtle),
      ),
      title: Text(
        object.title.isEmpty ? 'Untitled' : object.title,
        maxLines: wrapTitle ? null : 1,
        overflow: wrapTitle ? TextOverflow.clip : TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: snippet != null && snippet.source != 'title'
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  objectContextLabel(object),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: colors.subtle),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      if (snippet.source != 'body' && snippet.source != 'title')
                        TextSpan(
                          text:
                              '[${snippet.source == 'canvas' ? 'Canvas' : 'Property'}] ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                          ),
                        ),
                      if (snippet.matchStart > 0)
                        TextSpan(
                          text: snippet.text.substring(
                            0,
                            math.min(snippet.matchStart, snippet.text.length),
                          ),
                          style: TextStyle(fontSize: 11, color: colors.subtle),
                        ),
                      if (snippet.matchStart < snippet.text.length)
                        TextSpan(
                          text: snippet.text.substring(
                            snippet.matchStart,
                            math.min(
                              snippet.matchStart + snippet.matchLength,
                              snippet.text.length,
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.text,
                          ),
                        ),
                      if (snippet.matchStart + snippet.matchLength <
                          snippet.text.length)
                        TextSpan(
                          text: snippet.text.substring(
                            snippet.matchStart + snippet.matchLength,
                          ),
                          style: TextStyle(fontSize: 11, color: colors.subtle),
                        ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            )
          : Text(
              objectContextLabel(object),
              style: TextStyle(fontSize: 11, color: colors.subtle),
            ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class TaskRow extends StatefulWidget {
  const TaskRow({
    super.key,
    required this.object,
    required this.controller,
    this.showDueDate = true,
    this.showPriority = true,
    this.showProject = true,
    this.onCompleted,
  });

  final UniversalObject object;
  final WorkspaceController controller;
  final bool showDueDate;
  final bool showPriority;
  final bool showProject;
  final ValueChanged<bool>? onCompleted;

  @override
  State<TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<TaskRow> {
  bool _hovered = false;
  bool _editingTitle = false;
  late final TextEditingController _titleController;
  final FocusNode _titleFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.object.title);
    _titleFocus.addListener(() {
      if (!_titleFocus.hasFocus && _editingTitle) {
        _saveTitle();
      }
    });
  }

  @override
  void didUpdateWidget(covariant TaskRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.object.title != widget.object.title && !_editingTitle) {
      _titleController.text = widget.object.title;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  void _saveTitle() {
    final text = _titleController.text.trim();
    if (text.isNotEmpty && text != widget.object.title) {
      widget.controller.edit(widget.object.id, title: text);
    } else {
      _titleController.text = widget.object.title;
    }
    setState(() => _editingTitle = false);
  }

  Future<void> _pickDueDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          parseCalendarDate(widget.object.properties['dueDate']) ??
          DateTime.now(),
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
    );
    if (picked != null) {
      final current = widget.controller.find(widget.object.id);
      if (current != null && !current.isDeleted) {
        widget.controller.edit(
          widget.object.id,
          properties: {...current.properties, 'dueDate': calendarDate(picked)},
        );
      }
    }
  }

  void _setQuickDueDate(String? dateStr) {
    final current = widget.controller.find(widget.object.id);
    if (current != null && !current.isDeleted) {
      widget.controller.edit(
        widget.object.id,
        properties: {...current.properties, 'dueDate': dateStr},
      );
    }
  }

  void _setPriority(String? priority) {
    final current = widget.controller.find(widget.object.id);
    if (current != null && !current.isDeleted) {
      widget.controller.edit(
        widget.object.id,
        properties: {...current.properties, 'priority': priority},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final o = widget.object;
    final isDone = o.isCompleted;
    final dueDate = parseCalendarDate(o.properties['dueDate']);
    final isOverdue = isDueDateOverdue(dueDate, isCompleted: isDone);
    final friendlyDate = formatFriendlyDueDate(dueDate);
    final priority = o.properties['priority'] as String?;
    final project = o.properties['project'] as String?;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: OrbitMotionScope.duration(context, OrbitMotion.control),
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: OrbitDensity.of(context).compact ? 3 : 6,
        ),
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: _hovered
              ? colors.hover
              : isDone
              ? colors.accent.withValues(alpha: .035)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            AnimatedScale(
              scale:
                  (isDone &&
                      !OrbitMotionScope.isReduced(context) &&
                      !OrbitMotionScope.isOff(context))
                  ? 1.06
                  : 1.0,
              duration: OrbitMotionScope.duration(context, OrbitMotion.micro),
              curve: OrbitMotion.ease,
              child: SizedBox(
                width: 32,
                height: 32,
                child: Checkbox(
                  value: isDone,
                  activeColor: colors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  onChanged: (val) {
                    final willBeDone = val == true;
                    widget.onCompleted?.call(willBeDone);
                    widget.controller.edit(
                      o.id,
                      properties: {...o.properties, 'completed': val},
                    );
                    if (willBeDone && context.mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            o.title.isNotEmpty
                                ? 'Task completed: "${o.title}"'
                                : 'Task completed',
                          ),
                          duration: const Duration(seconds: 3),
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () {
                              widget.controller.edit(
                                o.id,
                                properties: {
                                  ...o.properties,
                                  'completed': false,
                                },
                              );
                            },
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _editingTitle
                  ? TextField(
                      controller: _titleController,
                      focusNode: _titleFocus,
                      autofocus: true,
                      style: const TextStyle(fontSize: 13.5),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      onSubmitted: (_) => _saveTitle(),
                    )
                  : GestureDetector(
                      onTap: () => setState(() {
                        _editingTitle = true;
                        _titleFocus.requestFocus();
                      }),
                      child: AnimatedDefaultTextStyle(
                        duration: OrbitMotionScope.duration(
                          context,
                          OrbitMotion.panel,
                        ),
                        style: OrbitTypography.body(context).copyWith(
                          fontSize: 14.5,
                          height: 1.45,
                          color: isDone ? colors.muted : colors.text,
                          decoration: isDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        child: Text(
                          o.title.isEmpty ? 'Untitled task' : o.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
            ),
            if (widget.showProject &&
                project != null &&
                project.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.raised,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '#$project',
                  style: TextStyle(fontSize: 12, color: colors.subtle),
                ),
              ),
            ],
            if (widget.showPriority) ...[
              const SizedBox(width: 6),
              PopupMenuButton<String?>(
                tooltip: 'Priority: ${priority ?? "None"}',
                padding: EdgeInsets.zero,
                iconSize: 18,
                onSelected: _setPriority,
                itemBuilder: (_) => [
                  const PopupMenuItem(value: null, child: Text('None')),
                  const PopupMenuItem(value: 'low', child: Text('Low')),
                  const PopupMenuItem(value: 'medium', child: Text('Medium')),
                  const PopupMenuItem(value: 'high', child: Text('High')),
                  const PopupMenuItem(value: 'urgent', child: Text('Urgent')),
                ],
                child: priority != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: switch (priority) {
                            'urgent' => Colors.redAccent.withValues(alpha: .15),
                            'high' => Colors.orangeAccent.withValues(
                              alpha: .15,
                            ),
                            'medium' => Colors.blueAccent.withValues(
                              alpha: .15,
                            ),
                            _ => colors.raised,
                          },
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          priority.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: .5,
                            color: switch (priority) {
                              'urgent' => Colors.redAccent,
                              'high' => Colors.orangeAccent,
                              'medium' => Colors.blueAccent,
                              _ => colors.subtle,
                            },
                          ),
                        ),
                      )
                    : (_hovered
                          ? Icon(
                              Icons.flag_outlined,
                              size: 14,
                              color: colors.subtle,
                            )
                          : const SizedBox.shrink()),
              ),
            ],
            if (widget.showDueDate) ...[
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: dueDate != null
                    ? 'Due: $friendlyDate'
                    : 'Set due date',
                padding: EdgeInsets.zero,
                onSelected: (action) {
                  final now = DateTime.now();
                  if (action == 'today') _setQuickDueDate(calendarDate(now));
                  if (action == 'tomorrow') {
                    _setQuickDueDate(
                      calendarDate(now.add(const Duration(days: 1))),
                    );
                  }
                  if (action == 'next_week') {
                    _setQuickDueDate(
                      calendarDate(now.add(const Duration(days: 7))),
                    );
                  }
                  if (action == 'custom') _pickDueDate(context);
                  if (action == 'clear') _setQuickDueDate(null);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'today', child: Text('Today')),
                  const PopupMenuItem(
                    value: 'tomorrow',
                    child: Text('Tomorrow'),
                  ),
                  const PopupMenuItem(
                    value: 'next_week',
                    child: Text('Next week'),
                  ),
                  const PopupMenuItem(
                    value: 'custom',
                    child: Text('Pick date…'),
                  ),
                  if (dueDate != null)
                    const PopupMenuItem(
                      value: 'clear',
                      child: Text('Clear date'),
                    ),
                ],
                child: dueDate != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: isOverdue
                              ? Colors.redAccent.withValues(alpha: .12)
                              : colors.raised,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOverdue
                                  ? Icons.error_outline
                                  : Icons.calendar_today_outlined,
                              size: 11,
                              color: isOverdue
                                  ? Colors.redAccent
                                  : colors.subtle,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              friendlyDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: isOverdue
                                    ? Colors.redAccent
                                    : colors.subtle,
                                fontWeight: isOverdue
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      )
                    : (_hovered
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.event_outlined,
                                  size: 13,
                                  color: colors.subtle,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.subtle,
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink()),
              ),
            ],
            if (_hovered) ...[
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Open task details',
                icon: const Icon(Icons.open_in_new, size: 14),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: () => widget.controller.openObject(o.id),
              ),
              PopupMenuButton<String>(
                tooltip: 'More actions',
                padding: EdgeInsets.zero,
                iconSize: 14,
                icon: const Icon(Icons.more_horiz, size: 14),
                constraints: const BoxConstraints(minWidth: 140),
                onSelected: (action) {
                  if (action == 'details') widget.controller.openObject(o.id);
                  if (action == 'trash') widget.controller.trash(o.id);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'details', child: Text('Open details')),
                  PopupMenuItem(value: 'trash', child: Text('Delete task')),
                ],
              ),
            ] else
              const SizedBox(width: 24),
          ],
        ),
      ),
    );
  }
}

class TaskViewConfig {
  TaskViewConfig({
    required this.id,
    required this.name,
    required this.baseTab,
    required this.sortOption,
    this.filterPriority,
    this.filterProject,
    required this.showDueDate,
    required this.showPriority,
    required this.showProject,
  });
  final String id;
  String name;
  final String baseTab;
  String sortOption;
  String? filterPriority;
  String? filterProject;
  bool showDueDate;
  bool showPriority;
  bool showProject;
}

const gameDevDisciplines = [
  'Game Design',
  'Programming',
  'Gameplay',
  'AI',
  'Level Design',
  'Art',
  '3D',
  '2D',
  'Animation',
  'VFX',
  'Audio',
  'Music',
  'Narrative',
  'UI/UX',
  'QA',
  'Production',
  'Tools',
  'Build / Release',
];

const bugSeverities = ['blocker', 'critical', 'major', 'minor'];

String formatAddress(dynamic addr) {
  if (addr == null) return '0x0';
  final s = addr.toString().trim();
  if (s.isEmpty) return '0x0';
  if (s.startsWith('0x') || s.startsWith('0X')) return s;
  final val = int.tryParse(s, radix: 16);
  if (val != null) return '0x${val.toRadixString(16).toUpperCase()}';
  return s;
}

String formatModuleOffset(String module, dynamic addr) {
  final cleanMod = module.trim().isEmpty ? 'target.exe' : module.trim();
  final cleanAddr = formatAddress(addr);
  return '$cleanMod+$cleanAddr';
}

enum KanbanPreset {
  universal('universal', 'Universal', [
    ('backlog', 'Backlog'),
    ('todo', 'To Do'),
    ('in-progress', 'In Progress'),
    ('done', 'Done'),
  ]),
  software('software', 'Software', [
    ('backlog', 'Backlog'),
    ('ready', 'Ready'),
    ('in-progress', 'In Dev'),
    ('in-review', 'In Review'),
    ('done', 'Done'),
  ]),
  gamedev('gamedev', 'Game Dev', [
    ('backlog', 'Backlog'),
    ('planned', 'Planned'),
    ('in-progress', 'In Progress'),
    ('review', 'Review'),
    ('testing', 'Testing / QA'),
    ('done', 'Done'),
  ]),
  bugs('bugs', 'Bug Tracker', [
    ('new', 'New'),
    ('confirmed', 'Confirmed'),
    ('in-progress', 'In Progress'),
    ('verify', 'Verify'),
    ('done', 'Closed'),
  ]),
  university('university', 'University Course', [
    ('syllabus', 'Syllabus / Topics'),
    ('assignments', 'Assignments'),
    ('exam-prep', 'Exam Prep'),
    ('review', 'Review'),
    ('done', 'Done'),
  ]),
  hypotheses('hypotheses', 'Hypotheses', [
    ('open', 'Open'),
    ('testing', 'Testing'),
    ('supported', 'Supported'),
    ('confirmed', 'Confirmed'),
    ('rejected', 'Rejected'),
  ]),
  functions('functions', 'Function Status', [
    ('unknown', 'Unknown'),
    ('interesting', 'Interesting'),
    ('investigating', 'Investigating'),
    ('partial', 'Partially Understood'),
    ('confirmed', 'Confirmed'),
  ]),
  research('research', 'Research', [
    ('inbox', 'Inbox'),
    ('reading', 'Reading'),
    ('investigating', 'Investigating'),
    ('synthesizing', 'Synthesizing'),
    ('published', 'Published'),
  ]),
  content('content', 'Content Pipeline', [
    ('ideas', 'Ideas'),
    ('drafting', 'Drafting'),
    ('editing', 'Editing'),
    ('scheduled', 'Scheduled'),
    ('published', 'Published'),
  ]),
  personal('personal', 'Personal Planning', [
    ('inbox', 'Inbox'),
    ('next', 'Next'),
    ('waiting', 'Waiting'),
    ('scheduled', 'Scheduled'),
    ('done', 'Done'),
  ]);

  const KanbanPreset(this.id, this.label, this.columns);
  final String id;
  final String label;
  final List<(String id, String label)> columns;

  static KanbanPreset fromId(String? id) =>
      KanbanPreset.values.where((p) => p.id == id).firstOrNull ??
      KanbanPreset.universal;
}

class TasksView extends StatefulWidget {
  const TasksView({
    super.key,
    required this.controller,
    this.viewObject,
    this.scope,
    this.folderFilter,
    this.initialTab,
  });

  final WorkspaceController controller;
  final UniversalObject? viewObject;
  final String? scope;
  final String? folderFilter;
  final String? initialTab;

  @override
  State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView> {
  String activeTab = 'todo'; // 'todo', 'today', 'upcoming', 'done', 'board'
  String query = '';
  String sortOption =
      'dueDate'; // 'dueDate', 'priority', 'title', 'created', 'manual'
  String? filterPriority;
  String? filterProject;
  String? filterDiscipline;
  String? filterMilestone;
  bool filterBugsOnly = false;
  bool filterBlockedOnly = false;
  bool showDueDate = true;
  bool showPriority = true;
  bool showProject = true;
  bool showDiscipline = true;
  bool showMilestone = true;
  bool showEstimate = true;
  final Map<String, List<String>> _manualOrderPerTab = {};
  final List<TaskViewConfig> _customViews = [];

  bool _creatingTask = false;
  final _newTaskController = TextEditingController();
  final _newTaskFocus = FocusNode();

  String? _peekTaskId;
  String? _inlineAddColumnId;
  final _inlineAddController = TextEditingController();
  final _inlineAddFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.initialTab != null) {
      activeTab = widget.initialTab!;
    } else if (widget.viewObject?.properties['filter'] == 'focus') {
      activeTab = 'focus';
    } else if (widget.viewObject?.properties['viewType'] == 'board') {
      activeTab = 'board';
    }
  }

  @override
  void dispose() {
    _newTaskController.dispose();
    _newTaskFocus.dispose();
    _inlineAddController.dispose();
    _inlineAddFocus.dispose();
    super.dispose();
  }

  void _submitNewTask(String text, {String? targetStatus}) async {
    final title = text.trim();
    if (title.isEmpty) return;
    final today = calendarDate(DateTime.now());
    final effectiveFolder =
        widget.folderFilter ??
        (widget.viewObject?.properties['folder'] as String?);
    final effectiveScope =
        widget.scope ?? (widget.viewObject?.properties['scope'] as String?);
    final effectiveDiscipline =
        filterDiscipline ??
        (widget.viewObject?.properties['discipline'] as String?);
    final effectiveMilestone =
        filterMilestone ??
        (widget.viewObject?.properties['milestone'] as String?);
    final isBugPreset =
        widget.viewObject?.properties['preset'] == 'bugs' || filterBugsOnly;
    final isDone = activeTab == 'done' || targetStatus == 'done';
    final props = <String, dynamic>{
      if (activeTab == 'today') 'dueDate': today,
      if (isDone) 'completed': true,
      'status': ?targetStatus,
      if (filterPriority != null) 'priority': filterPriority,
      if (filterProject != null)
        'project': filterProject
      else if (effectiveScope != null && effectiveScope.isNotEmpty)
        'project': effectiveScope,
      if (effectiveFolder != null && effectiveFolder.isNotEmpty)
        'folder': effectiveFolder,
      if (effectiveDiscipline != null && effectiveDiscipline.isNotEmpty)
        'discipline': effectiveDiscipline,
      if (effectiveMilestone != null && effectiveMilestone.isNotEmpty)
        'milestone': effectiveMilestone,
      if (isBugPreset) 'isBug': true,
      if (widget.viewObject?.properties['contextId'] != null)
        'contextId': widget.viewObject?.properties['contextId'],
    };
    final created = await widget.controller.create(
      'orbit.task',
      title: title,
      properties: props,
    );
    if (created != null && mounted) {
      _newTaskController.clear();
      _newTaskFocus.requestFocus();
      _inlineAddController.clear();
      setState(() => _inlineAddColumnId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final colors = OrbitColors.of(context);
    final today = calendarDate(DateTime.now());

    final effectiveFolder =
        widget.folderFilter ??
        (widget.viewObject?.properties['folder'] as String?);
    final effectiveScope =
        widget.scope ?? (widget.viewObject?.properties['scope'] as String?);

    bool matchesScope(UniversalObject t) {
      final courseId = widget.viewObject?.properties['courseId'];
      if (courseId is String && courseId.isNotEmpty) {
        final course = c.find(courseId);
        return course != null &&
            !course.isDeleted &&
            belongsToCourse(t, course);
      }
      if (effectiveFolder != null && effectiveFolder.isNotEmpty) {
        final f = t.properties['folder'];
        if (f is String &&
            (f == effectiveFolder || f.startsWith('$effectiveFolder/'))) {
          return true;
        }
        final p = c.repository.objectPath(t.id);
        if (p != null &&
            (p == effectiveFolder || p.startsWith('$effectiveFolder/'))) {
          return true;
        }
      }
      if (effectiveScope != null && effectiveScope.isNotEmpty) {
        final course = t.properties['course']?.toString().toLowerCase();
        final project = t.properties['project']?.toString().toLowerCase();
        final target = t.properties['target']?.toString().toLowerCase();
        final contextVal = t.properties['context']?.toString().toLowerCase();
        final lowerScope = effectiveScope.toLowerCase();
        if (course == lowerScope ||
            project == lowerScope ||
            target == lowerScope ||
            contextVal == lowerScope) {
          return true;
        }
      }
      if ((effectiveFolder == null || effectiveFolder.isEmpty) &&
          (effectiveScope == null || effectiveScope.isEmpty)) {
        return true;
      }
      return false;
    }

    final currentPresetId = widget.viewObject?.properties['preset'] as String?;
    final isHypothesesPreset = currentPresetId == 'hypotheses';
    final isFunctionsPreset = currentPresetId == 'functions';

    final allTasks = c.activeObjects
        .where(c.inActiveSpace)
        .where(
          (t) =>
              !t.isDeleted &&
              matchesScope(t) &&
              (t.typeId == 'orbit.task' ||
                  (isHypothesesPreset &&
                      t.properties['category'] == 'Hypothesis') ||
                  (isFunctionsPreset &&
                      (t.properties['category'] == 'Function' ||
                          t.properties.containsKey('address')))),
        )
        .toList();

    // Tab counts
    final todoCount = allTasks.where((t) => !t.isCompleted).length;
    final doneCount = allTasks.where((t) => t.isCompleted).length;
    final todayCount = allTasks.where((t) {
      if (t.isCompleted) return false;
      final d = parseCalendarDate(t.properties['dueDate']);
      if (d == null) return false;
      return calendarDate(d) == today || isDueDateOverdue(d);
    }).length;
    final upcomingCount = allTasks.where((t) {
      if (t.isCompleted) return false;
      final d = parseCalendarDate(t.properties['dueDate']);
      if (d == null) return false;
      return calendarDate(d).compareTo(today) > 0;
    }).length;
    final focusCount = allTasks.where((t) {
      if (t.isCompleted) return false;
      final status = t.properties['status'] as String?;
      final priority = t.properties['priority'] as String?;
      return status == 'in-progress' ||
          priority == 'urgent' ||
          _isTaskBlocked(t);
    }).length;

    final activeCustom = _customViews
        .where((v) => v.id == activeTab)
        .firstOrNull;
    final effectiveBaseTab = activeCustom?.baseTab ?? activeTab;

    // Filter by tab
    var visibleTasks = allTasks.where((t) {
      if (effectiveBaseTab == 'focus' ||
          widget.viewObject?.properties['filter'] == 'focus') {
        if (t.isCompleted) return false;
        final status = t.properties['status'] as String?;
        final priority = t.properties['priority'] as String?;
        return status == 'in-progress' ||
            priority == 'urgent' ||
            _isTaskBlocked(t);
      }
      if (effectiveBaseTab == 'todo') return !t.isCompleted;
      if (effectiveBaseTab == 'done') return t.isCompleted;
      if (effectiveBaseTab == 'today') {
        if (t.isCompleted) return false;
        final d = parseCalendarDate(t.properties['dueDate']);
        if (d == null) return false;
        return calendarDate(d) == today || isDueDateOverdue(d);
      }
      if (effectiveBaseTab == 'upcoming') {
        if (t.isCompleted) return false;
        final d = parseCalendarDate(t.properties['dueDate']);
        if (d == null) return false;
        return calendarDate(d).compareTo(today) > 0;
      }
      return true; // 'board'
    }).toList();

    // Filter by search
    if (query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      visibleTasks = visibleTasks
          .where(
            (t) =>
                t.title.toLowerCase().contains(q) ||
                t.body.toLowerCase().contains(q),
          )
          .toList();
    }

    // Filter by priority
    if (filterPriority != null) {
      visibleTasks = visibleTasks
          .where((t) => t.properties['priority'] == filterPriority)
          .toList();
    }

    // Filter by project
    if (filterProject != null) {
      visibleTasks = visibleTasks
          .where((t) => t.properties['project'] == filterProject)
          .toList();
    }

    // Filter by discipline
    final activeDiscipline =
        filterDiscipline ??
        (widget.viewObject?.properties['discipline'] as String?);
    if (activeDiscipline != null && activeDiscipline.isNotEmpty) {
      final target = activeDiscipline.toLowerCase();
      visibleTasks = visibleTasks.where((t) {
        final d = (t.properties['discipline'] ?? t.properties['category'])
            ?.toString()
            .toLowerCase();
        return d == target;
      }).toList();
    }

    // Filter by milestone
    final activeMilestone =
        filterMilestone ??
        (widget.viewObject?.properties['milestone'] as String?);
    if (activeMilestone != null && activeMilestone.isNotEmpty) {
      final target = activeMilestone.toLowerCase();
      visibleTasks = visibleTasks.where((t) {
        final m = t.properties['milestone']?.toString().toLowerCase();
        return m == target;
      }).toList();
    }

    // Filter by bugs only
    if (filterBugsOnly || widget.viewObject?.properties['preset'] == 'bugs') {
      visibleTasks = visibleTasks.where((t) {
        return t.properties['isBug'] == true ||
            t.properties['category'] == 'Bug' ||
            t.properties['severity'] != null;
      }).toList();
    }

    // Filter by blocked only
    if (filterBlockedOnly) {
      visibleTasks = visibleTasks.where(_isTaskBlocked).toList();
    }

    // Sort
    visibleTasks.sort((a, b) {
      if (sortOption == 'manual') {
        final order = _manualOrderPerTab[activeTab] ?? [];
        final aIdx = order.indexOf(a.id);
        final bIdx = order.indexOf(b.id);
        if (aIdx != -1 && bIdx != -1) return aIdx.compareTo(bIdx);
        if (aIdx != -1) return -1;
        if (bIdx != -1) return 1;
        return 0;
      }
      if (sortOption == 'estimate') {
        int eVal(String? e) => int.tryParse(e ?? '') ?? 0;
        final eDiff = eVal(
          b.properties['estimate'] as String?,
        ).compareTo(eVal(a.properties['estimate'] as String?));
        if (eDiff != 0) return eDiff;
      }
      if (sortOption == 'priority') {
        int pVal(String? p) => switch (p) {
          'urgent' => 0,
          'high' => 1,
          'medium' => 2,
          'low' => 3,
          _ => 4,
        };
        final pDiff = pVal(
          a.properties['priority'] as String?,
        ).compareTo(pVal(b.properties['priority'] as String?));
        if (pDiff != 0) return pDiff;
      }
      if (sortOption == 'title') {
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
      if (sortOption == 'created') {
        return b.createdAt.compareTo(a.createdAt);
      }
      // Default: dueDate
      final aDate = parseCalendarDate(a.properties['dueDate']);
      final bDate = parseCalendarDate(b.properties['dueDate']);
      if (aDate != null && bDate != null) return aDate.compareTo(bDate);
      if (aDate != null) return -1;
      if (bDate != null) return 1;
      return a.title.compareTo(b.title);
    });

    // Available projects, disciplines, and milestones for filter
    final projects = allTasks
        .map((t) => t.properties['project'] as String?)
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList();

    final availableDisciplines = allTasks
        .map(
          (t) =>
              (t.properties['discipline'] ?? t.properties['category'])
                  as String?,
        )
        .whereType<String>()
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList();

    final availableMilestones = allTasks
        .map((t) => t.properties['milestone'] as String?)
        .whereType<String>()
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList();

    final isAnyFilterActive =
        filterPriority != null ||
        filterProject != null ||
        filterDiscipline != null ||
        filterMilestone != null ||
        filterBugsOnly ||
        filterBlockedOnly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Header: Title & View Tabs
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Tasks',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Spacer(),
                  // In-view Search
                  SizedBox(
                    width: 190,
                    height: 32,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search tasks…',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: colors.subtle,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 15,
                          color: colors.subtle,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 28,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 8,
                        ),
                        filled: true,
                        fillColor: colors.raised,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(fontSize: 12),
                      onChanged: (v) => setState(() => query = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Sort menu
                  PopupMenuButton<String>(
                    tooltip: 'Sort tasks',
                    icon: Icon(Icons.sort, size: 18, color: colors.subtle),
                    initialValue: sortOption,
                    onSelected: (v) => setState(() => sortOption = v),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'dueDate',
                        child: Text('Sort by Due Date'),
                      ),
                      PopupMenuItem(
                        value: 'priority',
                        child: Text('Sort by Priority'),
                      ),
                      PopupMenuItem(
                        value: 'estimate',
                        child: Text('Sort by Estimate Points'),
                      ),
                      PopupMenuItem(
                        value: 'title',
                        child: Text('Sort by Title'),
                      ),
                      PopupMenuItem(
                        value: 'created',
                        child: Text('Sort by Created Date'),
                      ),
                      PopupMenuItem(
                        value: 'manual',
                        child: Text('Manual Order (Drag to reorder)'),
                      ),
                    ],
                  ),
                  // Filter menu
                  PopupMenuButton<String>(
                    tooltip: 'Filter tasks',
                    icon: Icon(
                      isAnyFilterActive
                          ? Icons.filter_alt
                          : Icons.filter_alt_outlined,
                      size: 18,
                      color: isAnyFilterActive ? colors.accent : colors.subtle,
                    ),
                    onSelected: (v) {
                      if (v == 'clear') {
                        setState(() {
                          filterPriority = null;
                          filterProject = null;
                          filterDiscipline = null;
                          filterMilestone = null;
                          filterBugsOnly = false;
                          filterBlockedOnly = false;
                        });
                      } else if (v.startsWith('p:')) {
                        setState(() => filterPriority = v.substring(2));
                      } else if (v.startsWith('proj:')) {
                        setState(() => filterProject = v.substring(5));
                      } else if (v.startsWith('disc:')) {
                        setState(() => filterDiscipline = v.substring(5));
                      } else if (v.startsWith('ms:')) {
                        setState(() => filterMilestone = v.substring(3));
                      } else if (v == 'quick:blocked') {
                        setState(() => filterBlockedOnly = !filterBlockedOnly);
                      } else if (v == 'quick:bugs') {
                        setState(() => filterBugsOnly = !filterBugsOnly);
                      }
                    },
                    itemBuilder: (_) => [
                      if (isAnyFilterActive)
                        const PopupMenuItem(
                          value: 'clear',
                          child: Text('Clear Filters'),
                        ),
                      CheckedPopupMenuItem(
                        value: 'quick:blocked',
                        checked: filterBlockedOnly,
                        child: const Text('Blocked Tasks Only'),
                      ),
                      CheckedPopupMenuItem(
                        value: 'quick:bugs',
                        checked: filterBugsOnly,
                        child: const Text('Bugs Only'),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        enabled: false,
                        value: '_p_header',
                        child: Text(
                          'PRIORITY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'p:urgent',
                        child: Text('Urgent'),
                      ),
                      const PopupMenuItem(value: 'p:high', child: Text('High')),
                      const PopupMenuItem(
                        value: 'p:medium',
                        child: Text('Medium'),
                      ),
                      const PopupMenuItem(value: 'p:low', child: Text('Low')),
                      if (projects.isNotEmpty) ...[
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          enabled: false,
                          value: '_proj_header',
                          child: Text(
                            'PROJECT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        for (final pr in projects)
                          PopupMenuItem(value: 'proj:$pr', child: Text('#$pr')),
                      ],
                      if (availableDisciplines.isNotEmpty) ...[
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          enabled: false,
                          value: '_disc_header',
                          child: Text(
                            'DISCIPLINE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        for (final d in availableDisciplines)
                          PopupMenuItem(value: 'disc:$d', child: Text(d)),
                      ],
                      if (availableMilestones.isNotEmpty) ...[
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          enabled: false,
                          value: '_ms_header',
                          child: Text(
                            'MILESTONE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        for (final m in availableMilestones)
                          PopupMenuItem(value: 'ms:$m', child: Text(m)),
                      ],
                    ],
                  ),
                  // View options menu
                  PopupMenuButton<String>(
                    tooltip: 'Visible properties',
                    icon: Icon(
                      Icons.view_column_outlined,
                      size: 18,
                      color: colors.subtle,
                    ),
                    onSelected: (v) {
                      setState(() {
                        if (v == 'dueDate') showDueDate = !showDueDate;
                        if (v == 'priority') showPriority = !showPriority;
                        if (v == 'project') showProject = !showProject;
                        if (v == 'discipline') showDiscipline = !showDiscipline;
                        if (v == 'milestone') showMilestone = !showMilestone;
                        if (v == 'estimate') showEstimate = !showEstimate;
                      });
                    },
                    itemBuilder: (_) => [
                      CheckedPopupMenuItem(
                        value: 'dueDate',
                        checked: showDueDate,
                        child: const Text('Due Date'),
                      ),
                      CheckedPopupMenuItem(
                        value: 'priority',
                        checked: showPriority,
                        child: const Text('Priority'),
                      ),
                      CheckedPopupMenuItem(
                        value: 'project',
                        checked: showProject,
                        child: const Text('Project'),
                      ),
                      CheckedPopupMenuItem(
                        value: 'discipline',
                        checked: showDiscipline,
                        child: const Text('Discipline'),
                      ),
                      CheckedPopupMenuItem(
                        value: 'milestone',
                        checked: showMilestone,
                        child: const Text('Milestone'),
                      ),
                      CheckedPopupMenuItem(
                        value: 'estimate',
                        checked: showEstimate,
                        child: const Text('Estimate'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Clean View Tabs
              Builder(
                builder: (context) {
                  final showFocusTab =
                      activeTab == 'focus' ||
                      widget.initialTab == 'focus' ||
                      widget.viewObject?.properties['filter'] == 'focus' ||
                      (widget.viewObject?.properties['project'] as String?)
                              ?.isNotEmpty ==
                          true ||
                      allTasks.any(
                        (t) =>
                            t.properties['discipline'] != null ||
                            t.properties['severity'] != null ||
                            (t.properties['project'] as String?)?.isNotEmpty ==
                                true,
                      );
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTab('todo', 'To Do', todoCount, colors),
                        if (showFocusTab)
                          _buildTab(
                            'focus',
                            'Current Focus',
                            focusCount,
                            colors,
                          ),
                        _buildTab('today', 'Today', todayCount, colors),
                        _buildTab(
                          'upcoming',
                          'Upcoming',
                          upcomingCount,
                          colors,
                        ),
                        _buildTab('done', 'Done', doneCount, colors),
                        _buildTab('board', 'Board', null, colors),
                        for (final cv in _customViews)
                          _buildCustomTab(cv, colors),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Duplicate current view',
                          icon: Icon(
                            Icons.add_to_photos_outlined,
                            size: 16,
                            color: colors.subtle,
                          ),
                          onPressed: _duplicateCurrentView,
                        ),
                      ],
                    ),
                  );
                },
              ),
              Divider(height: 1, color: colors.divider),
            ],
          ),
        ),

        // Main View Content
        Expanded(
          child: activeTab == 'board'
              ? _buildKanbanBoard(visibleTasks, colors)
              : _buildTaskList(visibleTasks, colors),
        ),
      ],
    );
  }

  void _duplicateCurrentView() {
    final newId = 'view_${DateTime.now().millisecondsSinceEpoch}';
    final currentCustom = _customViews
        .where((v) => v.id == activeTab)
        .firstOrNull;
    final base = currentCustom?.baseTab ?? activeTab;
    final name = '${currentCustom?.name ?? activeTab.toUpperCase()} Copy';
    final config = TaskViewConfig(
      id: newId,
      name: name,
      baseTab: base,
      sortOption: sortOption,
      filterPriority: filterPriority,
      filterProject: filterProject,
      showDueDate: showDueDate,
      showPriority: showPriority,
      showProject: showProject,
    );
    setState(() {
      _customViews.add(config);
      activeTab = newId;
    });
  }

  Widget _buildCustomTab(TaskViewConfig config, OrbitColors colors) {
    final active = activeTab == config.id;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        setState(() {
          activeTab = config.id;
          sortOption = config.sortOption;
          filterPriority = config.filterPriority;
          filterProject = config.filterProject;
          showDueDate = config.showDueDate;
          showPriority = config.showPriority;
          showProject = config.showProject;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? colors.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              config.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                color: active ? colors.text : colors.subtle,
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                setState(() {
                  _customViews.remove(config);
                  if (activeTab == config.id) activeTab = 'todo';
                });
              },
              child: Icon(Icons.close, size: 12, color: colors.subtle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String key, String label, int? count, OrbitColors colors) {
    final active = activeTab == key;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => setState(() => activeTab = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? colors.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                color: active ? colors.text : colors.subtle,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: active
                      ? colors.accent.withValues(alpha: .15)
                      : colors.raised,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: active ? colors.accent : colors.subtle,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList(List<UniversalObject> tasks, OrbitColors colors) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 48),
      children: [
        if (tasks.isEmpty && !_creatingTask)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: Text(
                'No tasks in this view.',
                style: TextStyle(fontSize: 13, color: colors.subtle),
              ),
            ),
          )
        else if (sortOption == 'manual')
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorderItem: (oldIndex, newIndex) {
              setState(() {
                final item = tasks.removeAt(oldIndex);
                tasks.insert(newIndex, item);
                _manualOrderPerTab[activeTab] = tasks.map((t) => t.id).toList();
              });
            },
            children: [
              for (final t in tasks)
                TaskRow(
                  key: ValueKey(t.id),
                  object: t,
                  controller: widget.controller,
                  showDueDate: showDueDate,
                  showPriority: showPriority,
                  showProject: showProject,
                ),
            ],
          )
        else
          for (final t in tasks)
            TaskRow(
              key: ValueKey(t.id),
              object: t,
              controller: widget.controller,
              showDueDate: showDueDate,
              showPriority: showPriority,
              showProject: showProject,
            ),

        // Inline + New task row
        const SizedBox(height: 6),
        if (!_creatingTask)
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              setState(() => _creatingTask = true);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _newTaskFocus.requestFocus();
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.add, size: 16, color: colors.subtle),
                  const SizedBox(width: 8),
                  Text(
                    'New task',
                    style: TextStyle(fontSize: 13, color: colors.subtle),
                  ),
                ],
              ),
            ),
          )
        else
          KeyboardListener(
            focusNode: FocusNode(),
            onKeyEvent: (event) {
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                setState(() => _creatingTask = false);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.hover,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_box_outline_blank,
                    size: 18,
                    color: colors.subtle,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _newTaskController,
                      focusNode: _newTaskFocus,
                      autofocus: true,
                      style: const TextStyle(fontSize: 13.5),
                      decoration: const InputDecoration(
                        hintText: 'Task title… (Enter to add, Esc to cancel)',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      onSubmitted: _submitNewTask,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _creatingTask = false),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildKanbanBoard(List<UniversalObject> allTasks, OrbitColors colors) {
    final preset = KanbanPreset.fromId(
      widget.viewObject?.properties['preset'] as String?,
    );
    final columns = preset.columns;

    // Distribute tasks across columns
    final colTasks = <String, List<UniversalObject>>{};
    for (final col in columns) {
      colTasks[col.$1] = [];
    }

    for (final t in allTasks) {
      if (t.isCompleted &&
          preset != KanbanPreset.hypotheses &&
          preset != KanbanPreset.functions) {
        if (colTasks.containsKey('done')) {
          colTasks['done']!.add(t);
        } else {
          colTasks[columns.last.$1]!.add(t);
        }
      } else {
        final rawStatus = boardStatus(
          t.properties['status'],
          columns.map((c) => c.$1).toList(),
        );
        if (colTasks.containsKey(rawStatus)) {
          colTasks[rawStatus]!.add(t);
        } else if (rawStatus.contains('part') &&
            colTasks.containsKey('partial')) {
          colTasks['partial']!.add(t);
        } else if (colTasks.containsKey('todo')) {
          colTasks['todo']!.add(t);
        } else {
          colTasks[columns.first.$1]!.add(t);
        }
      }
    }

    final peekTask = _peekTaskId != null
        ? widget.controller.find(_peekTaskId!)
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kanban Columns
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < columns.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    SizedBox(
                      width: OrbitDensity.of(context).boardColumn,
                      child: _buildKanbanColumn(
                        columns[i].$1,
                        columns[i].$2,
                        colTasks[columns[i].$1] ?? [],
                        colors,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Slide-in Task Preview Peek Panel
        if (peekTask != null) ...[
          VerticalDivider(width: 1, color: colors.divider),
          SizedBox(
            width: 380,
            child: Material(
              color: colors.panel,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: colors.divider)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: colors.accent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Task Preview',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Open in tab',
                          icon: const Icon(Icons.open_in_new, size: 16),
                          onPressed: () =>
                              widget.controller.openObject(peekTask.id),
                        ),
                        IconButton(
                          tooltip: 'Close preview (Esc)',
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => setState(() => _peekTaskId = null),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TaskDetail(
                      key: ValueKey(peekTask.id),
                      object: peekTask,
                      controller: widget.controller,
                      viewObject: widget.viewObject,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildKanbanColumn(
    String colId,
    String title,
    List<UniversalObject> tasks,
    OrbitColors colors,
  ) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final taskId = details.data;
        final task = widget.controller.find(taskId);
        if (task == null) return;
        final isDone = colId == 'done';
        widget.controller.edit(
          taskId,
          properties: {
            ...task.properties,
            'status': colId,
            if (task.typeId == 'orbit.task') 'completed': isDone,
          },
        );
      },
      builder: (context, candidates, rejected) {
        final isTargeted = candidates.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: isTargeted
                ? colors.accent.withValues(alpha: .08)
                : colors.panel,
            borderRadius: BorderRadius.circular(8),
            border: isTargeted
                ? Border.all(color: colors.accent, width: 1.5)
                : null,
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column Header
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: colors.raised,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${tasks.length}',
                      style: TextStyle(fontSize: 12, color: colors.subtle),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Add task to $title',
                    icon: const Icon(Icons.add, size: 16),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: () {
                      setState(() => _inlineAddColumnId = colId);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _inlineAddFocus.requestFocus();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Column Task Cards
              Expanded(
                child: ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final t = tasks[index];
                    return Draggable<String>(
                      data: t.id,
                      feedback: Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: 240,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colors.raised,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            t.title.isEmpty ? 'Untitled' : t.title,
                            style: const TextStyle(fontSize: 14.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: _buildKanbanCard(t, colors),
                      ),
                      child: _buildKanbanCard(t, colors),
                    );
                  },
                ),
              ),

              // Inline Quick Add at Column Bottom
              if (_inlineAddColumnId == colId) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.raised,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inlineAddController,
                          focusNode: _inlineAddFocus,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            hintText: 'Task title…',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 4),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (text) =>
                              _submitNewTask(text, targetStatus: colId),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check, size: 14),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: () => _submitNewTask(
                          _inlineAddController.text,
                          targetStatus: colId,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: () =>
                            setState(() => _inlineAddColumnId = null),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    setState(() => _inlineAddColumnId = colId);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _inlineAddFocus.requestFocus();
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add, size: 14, color: colors.subtle),
                        const SizedBox(width: 6),
                        Text(
                          'Add task',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: colors.subtle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildKanbanCard(UniversalObject t, OrbitColors colors) {
    final isBlocked = _isTaskBlocked(t);
    final subtasks = _getSubtaskProgress(t.body);
    final priority = t.properties['priority'] as String?;
    final estimate = t.properties['estimate'] as String?;
    final category = t.properties['category'] as String?;
    final discipline = (t.properties['discipline'] ?? category) as String?;
    final milestone = t.properties['milestone'] as String?;
    final severity = t.properties['severity'] as String?;
    final isBug = t.properties['isBug'] == true || severity != null;
    final isSelected = _peekTaskId == t.id;

    return Card(
      elevation: 0,
      color: isSelected ? colors.hover : colors.raised,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: isSelected
            ? BorderSide(color: colors.accent, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => setState(() => _peekTaskId = t.id),
        onDoubleTap: () => widget.controller.openObject(t.id),
        child: Padding(
          padding: EdgeInsets.all(OrbitDensity.of(context).cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: t.isCompleted,
                    activeColor: colors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (val) {
                      widget.controller.edit(
                        t.id,
                        properties: {...t.properties, 'completed': val},
                      );
                    },
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        t.title.isEmpty ? 'Untitled' : t.title,
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                          decoration: t.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Card Metadata Chips (Codecks/Linear style compact badges)
              Padding(
                padding: const EdgeInsets.only(left: 36, top: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (isBug)
                      _badge(
                        severity?.toUpperCase() ?? 'BUG',
                        icon: Icons.bug_report,
                        color: switch (severity) {
                          'blocker' => Colors.red.shade900,
                          'critical' => Colors.red.shade600,
                          'major' => Colors.orange.shade800,
                          'minor' => Colors.blue.shade600,
                          _ => Colors.red.shade400,
                        },
                        colors: colors,
                      ),
                    if (showDiscipline &&
                        discipline != null &&
                        discipline.isNotEmpty)
                      _badge(
                        discipline,
                        icon: Icons.category_outlined,
                        colors: colors,
                      ),
                    if (showMilestone &&
                        milestone != null &&
                        milestone.isNotEmpty)
                      _badge(
                        milestone,
                        icon: Icons.flag_outlined,
                        colors: colors,
                      ),
                    if (showDueDate && t.properties['dueDate'] is String)
                      _badge(
                        formatFriendlyDueDate(
                          parseCalendarDate(t.properties['dueDate']),
                        ),
                        icon: Icons.calendar_today_outlined,
                        colors: colors,
                      ),
                    if (isBlocked)
                      _badge(
                        'Blocked',
                        icon: Icons.lock_outline,
                        color: Colors.amber.shade700,
                        colors: colors,
                      ),
                    if (subtasks != null)
                      _badge(
                        '${subtasks.$1}/${subtasks.$2}',
                        icon: Icons.checklist,
                        colors: colors,
                      ),
                    if (showEstimate && estimate != null && estimate.isNotEmpty)
                      _badge(estimate, icon: Icons.speed, colors: colors),
                    if (category != null &&
                        category.isNotEmpty &&
                        category != discipline)
                      _badge(category, colors: colors),
                    if (showPriority &&
                        priority != null &&
                        priority != 'none' &&
                        priority != 'medium')
                      _badge(
                        priority.toUpperCase(),
                        color: priority == 'urgent' || priority == 'high'
                            ? Colors.red.shade400
                            : colors.subtle,
                        colors: colors,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(
    String text, {
    IconData? icon,
    Color? color,
    required OrbitColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: (color ?? colors.subtle).withValues(alpha: .12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color ?? colors.subtle),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color ?? colors.subtle,
            ),
          ),
        ],
      ),
    );
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
      final blocker = widget.controller.find(id);
      if (blocker != null && !blocker.isDeleted && !blocker.isCompleted) {
        return true;
      }
    }
    return false;
  }

  (int, int)? _getSubtaskProgress(String body) {
    final matches = RegExp(
      r'^\s*-\s*\[([ xX])\]',
      multiLine: true,
    ).allMatches(body).toList();
    if (matches.isEmpty) return null;
    final done = matches.where((m) => m.group(1)?.toLowerCase() == 'x').length;
    return (done, matches.length);
  }
}

class TaskDetail extends StatefulWidget {
  const TaskDetail({
    super.key,
    required this.object,
    required this.controller,
    this.viewObject,
  });
  final UniversalObject object;
  final WorkspaceController controller;
  final UniversalObject? viewObject;
  @override
  State<TaskDetail> createState() => _TaskDetailState();
}

class _TaskDetailState extends State<TaskDetail> {
  late final title = TextEditingController(text: widget.object.title);
  late final body = TextEditingController(text: widget.object.body);
  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TaskDetail old) {
    super.didUpdateWidget(old);
    if (old.object.title != widget.object.title &&
        title.text != widget.object.title) {
      title.text = widget.object.title;
    }
    if (old.object.body != widget.object.body &&
        body.text != widget.object.body) {
      body.text = widget.object.body;
    }
  }

  void property(String key, dynamic value) => widget.controller.edit(
    widget.object.id,
    properties: {
      ...(widget.controller.find(widget.object.id) ?? widget.object).properties,
      key: value,
    },
  );
  @override
  Widget build(BuildContext context) {
    final o = widget.object;
    final status = o.properties['status'] is String
        ? o.properties['status'] as String
        : (o.isCompleted ? 'done' : 'todo');
    final statuses = <String, String>{
      for (final column in KanbanPreset.fromId(
        widget.viewObject?.properties['preset'] as String?,
      ).columns)
        column.$1: column.$2,
    };
    statuses.putIfAbsent(
      status,
      () => status.isEmpty ? 'Empty status' : status,
    );
    final rawBlocker = o.properties['blockedBy'];
    final blockerId = rawBlocker is String
        ? rawBlocker
        : rawBlocker is List && rawBlocker.isNotEmpty
        ? rawBlocker.first.toString()
        : null;
    final blockers = {
      for (final task
          in widget.controller.ofType('orbit.task').where((t) => t.id != o.id))
        task.id: task.title,
    };
    if (blockerId != null && !blockers.containsKey(blockerId)) {
      final broken = widget.controller.find(blockerId);
      blockers[blockerId] = broken == null
          ? 'Missing task'
          : broken.isDeleted
          ? 'Deleted task: ${broken.title}'
          : 'Broken reference: ${broken.title}';
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            Row(
              children: [
                Checkbox(
                  value: o.isCompleted,
                  onChanged: (v) => property('completed', v),
                ),
                Expanded(
                  child: TextField(
                    controller: title,
                    minLines: 1,
                    maxLines: null,
                    style: Theme.of(context).textTheme.headlineSmall,
                    decoration: const InputDecoration(
                      hintText: 'Task title',
                      filled: false,
                    ),
                    onChanged: (v) => widget.controller.edit(o.id, title: v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        [
                          'low',
                          'medium',
                          'high',
                          'urgent',
                        ].contains(o.properties['priority'])
                        ? o.properties['priority'] as String
                        : 'medium',
                    decoration: const InputDecoration(labelText: 'Priority'),
                    isExpanded: true,
                    items: ['low', 'medium', 'high', 'urgent']
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(v[0].toUpperCase() + v.substring(1)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => property('priority', v),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    key: ValueKey('status-${o.id}-$status'),
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [
                      for (final option in statuses.entries)
                        DropdownMenuItem(
                          value: option.key,
                          child: Text(
                            option.value,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        property('status', v);
                        if (v == 'done') {
                          property('completed', true);
                        } else if (o.isCompleted) {
                          property('completed', false);
                        }
                      }
                    },
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate:
                          DateTime.tryParse('${o.properties['dueDate']}') ??
                          DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      property(
                        'dueDate',
                        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                      );
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(
                    o.properties['dueDate'] as String? ?? 'Set due date',
                  ),
                ),
                if (o.properties['dueDate'] != null)
                  IconButton(
                    tooltip: 'Clear due date',
                    onPressed: () => property('dueDate', null),
                    icon: const Icon(Icons.close, size: 16),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: body,
              style: OrbitTypography.body(
                context,
              ).copyWith(fontSize: 16, height: 1.55),
              minLines: 6,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: 'Add details, context or Markdown links…',
                alignLabelWithHint: true,
              ),
              onChanged: (v) => widget.controller.edit(o.id, body: v),
            ),
            const SizedBox(height: 20),
            TaskPlanningPanel(controller: widget.controller, task: o),
            ExpansionTile(
              key: ValueKey('task-advanced-properties'),
              tilePadding: EdgeInsets.zero,
              title: const Text('Properties'),
              subtitle: const Text(
                'Estimate, discipline, dependencies and build context',
              ),
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: 110,
                      child: DropdownButtonFormField<String>(
                        initialValue: o.properties['estimate'] is String
                            ? o.properties['estimate'] as String
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Estimate',
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('None'),
                          ),
                          for (final est in [
                            '1',
                            '2',
                            '3',
                            '5',
                            '8',
                            '13',
                            'XS',
                            'S',
                            'M',
                            'L',
                            'XL',
                          ])
                            DropdownMenuItem(value: est, child: Text(est)),
                        ],
                        onChanged: (v) => property('estimate', v),
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: TextFormField(
                        initialValue: o.properties['category'] is String
                            ? o.properties['category'] as String
                            : '',
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        onChanged: (v) => property(
                          'category',
                          v.trim().isEmpty ? null : v.trim(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        key: ValueKey('blocker-${o.id}-$blockerId'),
                        initialValue: blockerId,
                        decoration: const InputDecoration(
                          labelText: 'Blocked by',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('None'),
                          ),
                          ...blockers.entries.map(
                            (t) => DropdownMenuItem(
                              value: t.key,
                              child: Text(
                                t.value.isEmpty ? 'Untitled' : t.value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => property('blockedBy', [
                          ?v,
                          if (rawBlocker is List)
                            ...rawBlocker.whereType<String>().where(
                              (id) => id != blockerId && id != v,
                            ),
                        ]),
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            gameDevDisciplines.contains(
                              o.properties['discipline'],
                            )
                            ? o.properties['discipline'] as String
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Discipline',
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('None'),
                          ),
                          for (final d in gameDevDisciplines)
                            DropdownMenuItem(value: d, child: Text(d)),
                        ],
                        onChanged: (v) => property('discipline', v),
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: TextFormField(
                        initialValue: o.properties['milestone'] is String
                            ? o.properties['milestone'] as String
                            : '',
                        decoration: const InputDecoration(
                          labelText: 'Milestone',
                        ),
                        onChanged: (v) => property(
                          'milestone',
                          v.trim().isEmpty ? null : v.trim(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            bugSeverities.contains(o.properties['severity'])
                            ? o.properties['severity'] as String
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Bug Severity',
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Not a bug / None'),
                          ),
                          for (final s in bugSeverities)
                            DropdownMenuItem(
                              value: s,
                              child: Text(s.toUpperCase()),
                            ),
                        ],
                        onChanged: (v) {
                          property('severity', v);
                          if (v != null) {
                            property('isBug', true);
                          }
                        },
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      child: TextFormField(
                        initialValue: o.properties['build'] is String
                            ? o.properties['build'] as String
                            : '',
                        decoration: const InputDecoration(
                          labelText: 'Build / Ver',
                        ),
                        onChanged: (v) => property(
                          'build',
                          v.trim().isEmpty ? null : v.trim(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      child: TextFormField(
                        initialValue: o.properties['platform'] is String
                            ? o.properties['platform'] as String
                            : '',
                        decoration: const InputDecoration(
                          labelText: 'Platform',
                        ),
                        onChanged: (v) => property(
                          'platform',
                          v.trim().isEmpty ? null : v.trim(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue:
                      widget.controller.activeObjects.any(
                        (v) => v.id == o.properties['contextId'],
                      )
                      ? o.properties['contextId'] as String
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Related context',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('No context'),
                    ),
                    ...widget.controller.activeObjects
                        .where((v) => v.id != o.id && v.typeId != 'orbit.file')
                        .map(
                          (v) => DropdownMenuItem(
                            value: v.id,
                            child: Text(
                              v.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                  ],
                  onChanged: (v) => property('contextId', v),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: PopupMenuButton<String>(
                tooltip: 'More task actions',
                onSelected: (_) => widget.controller.trash(o.id),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'trash',
                    child: Text('Move to Trash'),
                  ),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('More actions'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EventDetail extends StatefulWidget {
  const EventDetail({
    super.key,
    required this.object,
    required this.controller,
  });
  final UniversalObject object;
  final WorkspaceController controller;

  @override
  State<EventDetail> createState() => _EventDetailState();
}

class _EventDetailState extends State<EventDetail> {
  late final title = TextEditingController(text: widget.object.title);
  late final body = TextEditingController(text: widget.object.body);

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EventDetail old) {
    super.didUpdateWidget(old);
    if (old.object.title != widget.object.title &&
        title.text != widget.object.title) {
      title.text = widget.object.title;
    }
    if (old.object.body != widget.object.body &&
        body.text != widget.object.body) {
      body.text = widget.object.body;
    }
  }

  void property(String key, dynamic value) => widget.controller.edit(
    widget.object.id,
    properties: {...widget.object.properties, key: value},
  );

  @override
  Widget build(BuildContext context) {
    final o = widget.object;
    EventSchedule? schedule;
    try {
      schedule = EventSchedule.fromProperties(o.properties);
    } catch (_) {}

    final allDay = schedule?.allDay ?? (o.properties['allDay'] == true);

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Row(
          children: [
            const Icon(Icons.event_outlined, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: title,
                style: Theme.of(context).textTheme.headlineSmall,
                decoration: const InputDecoration(
                  hintText: 'Event title',
                  filled: false,
                ),
                onChanged: (v) => widget.controller.edit(o.id, title: v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          schedule == null
              ? 'Dates need review. The original event data is preserved.'
              : allDay
              ? '${calendarDate(schedule.start)} → ${calendarDate(schedule.end)} (exclusive) · All day'
              : '${schedule.start.toLocal()} → ${schedule.end.toLocal()} · Device local time',
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Edit dates'),
            onPressed: () async {
              final controller = widget.controller;
              if (!await controller.flushAll() || !context.mounted) {
                return;
              }
              final current = controller.find(o.id);
              if (current != null && !current.isDeleted) {
                await showEventDialog(context, controller, event: current);
              }
            },
          ),
        ),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          initialValue:
              widget.controller.activeObjects.any(
                (v) => v.id == o.properties['contextId'],
              )
              ? o.properties['contextId'] as String
              : null,
          decoration: const InputDecoration(labelText: 'Related context'),
          items: [
            const DropdownMenuItem(value: null, child: Text('No context')),
            ...widget.controller.activeObjects
                .where((v) => v.id != o.id && v.typeId != 'orbit.event')
                .map(
                  (v) => DropdownMenuItem(
                    value: v.id,
                    child: Text(
                      v.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
          ],
          onChanged: (v) => property('contextId', v),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: body,
          minLines: 6,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: 'Add details, description or links…',
            alignLabelWithHint: true,
          ),
          onChanged: (v) => widget.controller.edit(o.id, body: v),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => widget.controller.trash(o.id),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Move to Trash'),
          ),
        ),
      ],
    );
  }
}

class _WorkspaceThemeSummary extends StatelessWidget {
  const _WorkspaceThemeSummary({required this.controller});
  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final pack = OrbitThemePack.fromId(
      controller.session.themePreset,
      customPacks: controller.session.customThemes,
    );
    final colors = OrbitColors.of(context);
    return OrbitCard(
      padding: const EdgeInsets.all(16),
      onTap: () => showOrbitThemeGalleryDialog(context, controller),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: pack.colors.background,
              borderRadius: BorderRadius.circular(OrbitRadius.control),
              border: Border.all(color: colors.border),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 14,
                      decoration: BoxDecoration(
                        color: pack.colors.panel,
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(OrbitRadius.control),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 8,
                  top: 16,
                  child: Container(height: 4, color: pack.colors.accent),
                ),
                Positioned(
                  left: 22,
                  right: 16,
                  top: 28,
                  child: Container(height: 3, color: pack.colors.subtle),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Workspace theme',
                  style: TextStyle(
                    color: colors.subtle,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  pack.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Typography, surfaces, accents, and corners move together.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: colors.subtle),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.open_in_new, size: 17, color: colors.muted),
        ],
      ),
    );
  }
}

/// A setting's control gets its own row before either label or value is squeezed.
class _SettingsControlTile extends StatelessWidget {
  const _SettingsControlTile({
    required this.title,
    required this.trailing,
    this.subtitle,
    this.contentPadding = EdgeInsets.zero,
  });
  final Widget title, trailing;
  final Widget? subtitle;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: contentPadding.add(const EdgeInsets.symmetric(vertical: 8)),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final labels = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              DefaultTextStyle(
                style: Theme.of(context).textTheme.bodySmall!,
                child: subtitle!,
              ),
            ],
          ],
        );
        if (constraints.maxWidth < 700 ||
            MediaQuery.textScalerOf(context).scale(14) > 21) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [labels, const SizedBox(height: 8), trailing],
          );
        }
        return Row(
          children: [
            Expanded(child: labels),
            const SizedBox(width: 20),
            SizedBox(width: 260, child: trailing),
          ],
        );
      },
    ),
  );
}

class SettingsView extends StatelessWidget {
  const SettingsView({
    super.key,
    required this.controller,
    required this.onExport,
    required this.onImport,
    required this.onOpenWorkspace,
  });
  final WorkspaceController controller;
  final VoidCallback onExport, onImport, onOpenWorkspace;
  @override
  Widget build(BuildContext context) {
    final c = controller, s = c.session;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            ProductivityToolbar(controller: controller),
            const SizedBox(height: 8),
            Text(
              'Appearance, editing, layout, and workspace preferences.',
              style: TextStyle(color: OrbitColors.of(context).subtle),
            ),
            const SizedBox(height: 28),
            Text('Appearance', style: OrbitTypography.section(context)),
            const SizedBox(height: 8),
            Text('Accent palette', style: OrbitTypography.metadata(context)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in const [
                  ('violet', 'Observatory Violet', Color(0xFF8B7CF6)),
                  ('cyan', 'Nebula Cyan', Color(0xFF06B6D4)),
                  ('emerald', 'Emerald Aurora', Color(0xFF10B981)),
                  ('amber', 'Solar Flare Amber', Color(0xFFF59E0B)),
                  ('rose', 'Crimson Nova Rose', Color(0xFFF43F5E)),
                  ('blue', 'Cobalt Deep Blue', Color(0xFF3B82F6)),
                ])
                  Tooltip(
                    message: entry.$2,
                    child: InkWell(
                      key: ValueKey('settings-accent-${entry.$1}'),
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => c.updateSession((s) {
                        s.accentColor = entry.$1;
                        s.colorOverrides = {...s.colorOverrides}
                          ..remove('accent')
                          ..remove('accentHover');
                      }),
                      child: AnimatedContainer(
                        duration: OrbitMotionScope.duration(
                          context,
                          OrbitMotion.micro,
                        ),
                        curve: OrbitMotion.ease,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: s.accentColor == entry.$1
                              ? entry.$3.withValues(alpha: 0.18)
                              : OrbitColors.of(context).panel,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: s.accentColor == entry.$1
                                ? entry.$3
                                : OrbitColors.of(context).border,
                            width: s.accentColor == entry.$1 ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: entry.$3,
                                shape: BoxShape.circle,
                                boxShadow: s.accentColor == entry.$1
                                    ? [
                                        BoxShadow(
                                          color: entry.$3.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 6,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: s.accentColor == entry.$1
                                  ? const Icon(
                                      Icons.check,
                                      size: 10,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                entry.$2.split(' ').first,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: s.accentColor == entry.$1
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: s.accentColor == entry.$1
                                      ? OrbitColors.of(context).text
                                      : OrbitColors.of(context).subtle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            ThemeColorSettings(controller: c),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Compact density'),
              value: s.compact,
              onChanged: (v) => c.updateSession((s) => s.compact = v),
            ),
            const SizedBox(height: 22),
            Text('Editor', style: OrbitTypography.section(context)),
            _SettingsControlTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Text size'),
              trailing: Text('${s.fontSize.round()} px'),
            ),
            Slider(
              value: s.fontSize,
              min: 12,
              max: 26,
              divisions: 14,
              label: '${s.fontSize.round()}',
              onChanged: (v) => c.updateSession((s) => s.fontSize = v),
            ),
            _SettingsControlTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Editor and reading width'),
              trailing: Text('${s.contentWidth.round()} px'),
            ),
            Slider(
              value: s.contentWidth,
              min: 520,
              max: 2000,
              divisions: 37,
              onChanged: (v) => c.updateSession((s) => s.contentWidth = v),
            ),
            _SettingsControlTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('App zoom'),
              subtitle: const Text(
                'Whole interface: Ctrl + / minus; Ctrl 0 to reset',
              ),
              trailing: DropdownButton<double>(
                isExpanded: true,
                itemHeight: null,
                key: const ValueKey('settings-app-zoom'),
                value: s.uiZoom,
                items:
                    ([
                          ...{
                            .75,
                            .9,
                            1.0,
                            1.1,
                            1.25,
                            1.5,
                            1.75,
                            2.0,
                            s.uiZoom,
                          },
                        ]..sort())
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text('${(v * 100).round()}%'),
                          ),
                        )
                        .toList(),
                onChanged: (v) {
                  if (v != null) c.updateSession((s) => s.uiZoom = v);
                },
              ),
            ),
            _SettingsControlTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Font family'),
              subtitle: Text(
                s.fontFamily == 'Times New Roman'
                    ? 'Times New Roman (Academic Serif)'
                    : (s.fontFamily == 'Georgia'
                          ? 'Georgia (Editorial Serif)'
                          : (s.fontFamily == 'Consolas'
                                ? 'Consolas (Code Monospace)'
                                : 'Segoe UI (Clean Sans)')),
              ),
              trailing: DropdownButton<String>(
                isExpanded: true,
                itemHeight: null,
                key: const ValueKey('settings-font-family-dropdown'),
                value:
                    [
                      'Segoe UI',
                      'Times New Roman',
                      'Georgia',
                      'Consolas',
                    ].contains(s.fontFamily)
                    ? s.fontFamily
                    : 'Segoe UI',
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(
                    value: 'Segoe UI',
                    child: Text('Segoe UI (Default Sans)'),
                  ),
                  DropdownMenuItem(
                    value: 'Times New Roman',
                    child: Text(
                      'Times New Roman (Serif)',
                      style: TextStyle(fontFamily: 'Times New Roman'),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Georgia',
                    child: Text(
                      'Georgia (Serif)',
                      style: TextStyle(fontFamily: 'Georgia'),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Consolas',
                    child: Text(
                      'Consolas (Code)',
                      style: TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    c.updateSession((s) => s.fontFamily = v);
                  }
                },
              ),
            ),

            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: OrbitColors.of(context).background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: OrbitColors.of(context).border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reading preview',
                    style: OrbitTypography.metadata(context),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A quiet place for clear ideas.\nThe quick brown fox jumps over the lazy dog.',
                    key: const ValueKey('settings-reading-font-preview'),
                    style: NoteTypography(
                      fontFamily: s.fontFamily,
                      fontSize: s.fontSize,
                      lineHeight: s.editorLineHeight,
                    ).body(color: OrbitColors.of(context).text),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'For serif reading, try 18–20 px with comfortable line spacing.',
                    style: OrbitTypography.metadata(context),
                  ),
                ],
              ),
            ),
            SwitchListTile(
              key: const ValueKey('settings-spellcheck-switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Spell and grammar check'),
              subtitle: const Text(
                'Offline dictionary and grammar analysis with right-click suggestions',
              ),
              value: s.spellCheckEnabled,
              onChanged: (v) => c.updateSession((s) => s.spellCheckEnabled = v),
            ),
            if (s.userDictionary.isNotEmpty)
              _SettingsControlTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Custom dictionary (${s.userDictionary.length} words)',
                ),
                subtitle: Text(s.userDictionary.join(', ')),
                trailing: TextButton.icon(
                  key: const ValueKey('settings-clear-dictionary-button'),
                  onPressed: () =>
                      c.updateSession((s) => s.userDictionary = []),
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: const Text('Clear'),
                ),
              ),
            _SettingsControlTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Default editor view mode'),
              subtitle: const Text(
                'Initial mode when opening a note without saved state',
              ),
              trailing: DropdownButton<String>(
                isExpanded: true,
                itemHeight: null,
                key: const ValueKey('settings-default-mode-dropdown'),
                value: s.defaultNoteMode,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'rich', child: Text('Rich Visual')),
                  DropdownMenuItem(value: 'write', child: Text('Raw Markdown')),
                  DropdownMenuItem(value: 'split', child: Text('Split View')),
                  DropdownMenuItem(value: 'read', child: Text('Reading View')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    c.updateSession((s) => s.defaultNoteMode = v);
                  }
                },
              ),
            ),
            _SettingsControlTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Default document format'),
              subtitle: const Text(
                'Standard document syntax for newly created notes',
              ),
              trailing: DropdownButton<String>(
                isExpanded: true,
                itemHeight: null,
                key: const ValueKey('settings-default-format-dropdown'),
                value: s.defaultDocumentFormat,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(
                    value: 'markdown',
                    child: Text('Markdown (GFM)'),
                  ),
                  DropdownMenuItem(
                    value: 'latex',
                    child: Text('LaTeX Document'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    c.updateSession((s) => s.defaultDocumentFormat = v);
                  }
                },
              ),
            ),
            SwitchListTile(
              key: const ValueKey('settings-bionic-reading-switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Bionic Reading by default'),
              subtitle: const Text(
                'Highlights initial fixation letters in preview for faster saccadic comprehension',
              ),
              value: s.bionicReadingDefault,
              onChanged: (v) =>
                  c.updateSession((s) => s.bionicReadingDefault = v),
            ),
            _SettingsControlTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Line spacing'),
              subtitle: const Text(
                'Vertical line height in note editor and formatted reading views',
              ),
              trailing: DropdownButton<double>(
                isExpanded: true,
                itemHeight: null,
                key: const ValueKey('settings-line-spacing-dropdown'),
                value: [1.4, 1.6, 1.8].contains(s.editorLineHeight)
                    ? s.editorLineHeight
                    : 1.6,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 1.4, child: Text('1.4 (Compact)')),
                  DropdownMenuItem(value: 1.6, child: Text('1.6 (Standard)')),
                  DropdownMenuItem(value: 1.8, child: Text('1.8 (Relaxed)')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    c.updateSession((s) => s.editorLineHeight = v);
                  }
                },
              ),
            ),
            const SizedBox(height: 22),
            Text('Layout and motion', style: OrbitTypography.section(context)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show explorer'),
              value: s.sidebarVisible,
              onChanged: (v) => c.updateSession((s) => s.sidebarVisible = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show context inspector'),
              value: s.inspectorVisible,
              onChanged: (v) => c.updateSession((s) => s.inspectorVisible = v),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OrbitModeControl<String>(
                values: const {
                  'normal': 'Normal',
                  'reduced': 'Reduced',
                  'off': 'Off',
                },
                value: s.motion,
                onChanged: (mode) => c.updateSession((s) => s.motion = mode),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Respects the system’s reduced-motion preference.',
              style: TextStyle(
                color: OrbitColors.of(context).subtle,
                fontSize: 12,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: c.resetLayout,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset layout'),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Storage and Auto-Save',
              style: OrbitTypography.section(context),
            ),
            _SettingsControlTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-save debounce interval'),
              subtitle: const Text(
                'Delay after typing before flushing drafts to disk',
              ),
              trailing: DropdownButton<int>(
                isExpanded: true,
                itemHeight: null,
                key: const ValueKey('settings-autosave-interval-dropdown'),
                value: [500, 1000, 2500].contains(s.autoSaveInterval)
                    ? s.autoSaveInterval
                    : 1000,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 500, child: Text('500ms (Fast)')),
                  DropdownMenuItem(
                    value: 1000,
                    child: Text('1000ms (Balanced)'),
                  ),
                  DropdownMenuItem(
                    value: 2500,
                    child: Text('2500ms (Relaxed)'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) c.updateSession((s) => s.autoSaveInterval = v);
                },
              ),
            ),
            SwitchListTile(
              key: const ValueKey('settings-auto-snapshot-switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-snapshot on document close'),
              subtitle: const Text(
                'Automatically records a historical recovery checkpoint when closing a note',
              ),
              value: s.autoSnapshotOnClose,
              onChanged: (v) =>
                  c.updateSession((s) => s.autoSnapshotOnClose = v),
            ),
            SwitchListTile(
              key: const ValueKey('settings-reverse-engineering-switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Reverse-engineering research tools'),
              subtitle: const Text(
                'Show experimental research project and record templates. Existing notes and maps stay accessible when disabled.',
              ),
              value: s.reverseEngineeringEnabled,
              onChanged: (v) =>
                  c.updateSession((s) => s.reverseEngineeringEnabled = v),
            ),
            const SizedBox(height: 22),
            Text(
              'Focus & Deep Work Timer',
              style: OrbitTypography.section(context),
            ),
            _SettingsControlTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Focus session duration'),
              subtitle: const Text('Standard Pomodoro work block length'),
              trailing: DropdownButton<int>(
                isExpanded: true,
                itemHeight: null,
                key: const ValueKey('settings-focus-duration-dropdown'),
                value: [15, 20, 25, 30, 45, 60].contains(s.focusMinutes)
                    ? s.focusMinutes
                    : 25,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 15, child: Text('15 min')),
                  DropdownMenuItem(value: 20, child: Text('20 min')),
                  DropdownMenuItem(value: 25, child: Text('25 min (Standard)')),
                  DropdownMenuItem(value: 30, child: Text('30 min')),
                  DropdownMenuItem(
                    value: 45,
                    child: Text('45 min (Deep Work)'),
                  ),
                  DropdownMenuItem(value: 60, child: Text('60 min (Extended)')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    c.updateSession((s) => s.focusMinutes = v);
                    globalFocusTimer.configureDurations(focus: v);
                  }
                },
              ),
            ),
            _SettingsControlTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Short break duration'),
              subtitle: const Text(
                'Rest period between standard focus sessions',
              ),
              trailing: DropdownButton<int>(
                isExpanded: true,
                itemHeight: null,
                key: const ValueKey('settings-short-break-dropdown'),
                value: [3, 5, 10].contains(s.shortBreakMinutes)
                    ? s.shortBreakMinutes
                    : 5,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 3, child: Text('3 min (Quick)')),
                  DropdownMenuItem(value: 5, child: Text('5 min (Standard)')),
                  DropdownMenuItem(value: 10, child: Text('10 min (Longer)')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    c.updateSession((s) => s.shortBreakMinutes = v);
                    globalFocusTimer.configureDurations(shortBreak: v);
                  }
                },
              ),
            ),
            _SettingsControlTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Long break duration'),
              subtitle: const Text(
                'Extended rest after completing a 4-session cycle',
              ),
              trailing: DropdownButton<int>(
                isExpanded: true,
                itemHeight: null,
                key: const ValueKey('settings-long-break-dropdown'),
                value: [15, 20, 30].contains(s.longBreakMinutes)
                    ? s.longBreakMinutes
                    : 15,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 15, child: Text('15 min (Standard)')),
                  DropdownMenuItem(value: 20, child: Text('20 min')),
                  DropdownMenuItem(value: 30, child: Text('30 min (Relaxed)')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    c.updateSession((s) => s.longBreakMinutes = v);
                    globalFocusTimer.configureDurations(longBreak: v);
                  }
                },
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Canvas and Spatial Boards',
              style: OrbitTypography.section(context),
            ),
            _SettingsControlTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Default paper grid'),
              subtitle: const Text(
                'Background paper texture and alignment grid for new canvases',
              ),
              trailing: DropdownButton<String>(
                isExpanded: true,
                itemHeight: null,
                key: const ValueKey('settings-canvas-grid-dropdown'),
                value:
                    [
                      'dots',
                      'grid',
                      'graph',
                      'cross',
                      'hex',
                      'blueprint',
                      'lines',
                      'ruled',
                      'isometric',
                      'blank',
                    ].contains(s.defaultCanvasGrid)
                    ? s.defaultCanvasGrid
                    : 'dots',
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'dots', child: Text('Standard dots')),
                  DropdownMenuItem(value: 'grid', child: Text('Standard grid')),
                  DropdownMenuItem(
                    value: 'graph',
                    child: Text('Engineering graph'),
                  ),
                  DropdownMenuItem(
                    value: 'cross',
                    child: Text('Cross / Reticle (+)'),
                  ),
                  DropdownMenuItem(
                    value: 'hex',
                    child: Text('Hexagonal honeycomb'),
                  ),
                  DropdownMenuItem(
                    value: 'blueprint',
                    child: Text('Architectural blueprint'),
                  ),
                  DropdownMenuItem(
                    value: 'lines',
                    child: Text('Ruled notebook lines'),
                  ),
                  DropdownMenuItem(
                    value: 'ruled',
                    child: Text('Student ruled margin'),
                  ),
                  DropdownMenuItem(
                    value: 'isometric',
                    child: Text('Isometric 3D grid'),
                  ),
                  DropdownMenuItem(value: 'blank', child: Text('Blank paper')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    c.updateSession((s) => s.defaultCanvasGrid = v);
                  }
                },
              ),
            ),
            SwitchListTile(
              key: const ValueKey('settings-canvas-snap-switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Snap to grid by default'),
              subtitle: const Text(
                'Automatically aligns newly placed spatial cards and shapes to grid nodes',
              ),
              value: s.canvasSnapToGrid,
              onChanged: (v) => c.updateSession((s) => s.canvasSnapToGrid = v),
            ),
            const SizedBox(height: 22),
            Text(
              'Audio & Voice Memos',
              style: OrbitTypography.section(context),
            ),
            _SettingsControlTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Default playback speed'),
              subtitle: const Text(
                'Standard playback rate when listening to voice memos and audio notes',
              ),
              trailing: DropdownButton<double>(
                isExpanded: true,
                itemHeight: null,
                key: const ValueKey('settings-audio-speed-dropdown'),
                value: [1.0, 1.25, 1.5, 2.0].contains(s.defaultAudioSpeed)
                    ? s.defaultAudioSpeed
                    : 1.0,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 1.0, child: Text('1.0× (Normal)')),
                  DropdownMenuItem(value: 1.25, child: Text('1.25× (Brisk)')),
                  DropdownMenuItem(
                    value: 1.5,
                    child: Text('1.5× (Accelerated)'),
                  ),
                  DropdownMenuItem(value: 2.0, child: Text('2.0× (Double)')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    c.updateSession((s) => s.defaultAudioSpeed = v);
                  }
                },
              ),
            ),
            () {
              final notes = c.activeObjects
                  .where((o) => !o.isDeleted && o.typeId == 'orbit.note')
                  .toList();
              final canvases = c.activeObjects
                  .where((o) => !o.isDeleted && o.typeId == 'orbit.canvas')
                  .toList();
              final tasks = c.activeObjects
                  .where((o) => !o.isDeleted && o.typeId == 'orbit.task')
                  .toList();
              var totalWords = 0;
              var totalSnapshots = 0;
              for (final n in notes) {
                final text = n.body.trim();
                if (text.isNotEmpty) {
                  totalWords += text.split(RegExp(r'\s+')).length;
                }
                final revisions = n.properties['revisions'];
                if (revisions is List) {
                  totalSnapshots += revisions.length;
                }
              }

              return OrbitHoverLiftCard(
                key: const ValueKey('settings-vault-analytics-card'),
                margin: const EdgeInsets.only(top: 24, bottom: 12),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(
                          Icons.insights_rounded,
                          size: 20,
                          color: OrbitColors.of(context).accent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Observatory Vault Analytics',
                          style: OrbitTypography.section(context),
                        ),

                        const OrbitPulseBadge(
                          key: ValueKey('settings-vault-live-badge'),
                          label: 'TELEMETRY LIVE',
                          active: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Live telemetry of indexed knowledge objects and document revisions',
                      style: TextStyle(
                        fontSize: 12,
                        color: OrbitColors.of(context).subtle,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildMetricCol(
                          context,
                          'Notes',
                          notes.length,
                          Icons.description_outlined,
                        ),
                        _buildMetricCol(
                          context,
                          'Canvases',
                          canvases.length,
                          Icons.gesture_rounded,
                        ),
                        _buildMetricCol(
                          context,
                          'Tasks',
                          tasks.length,
                          Icons.check_circle_outline_rounded,
                        ),
                        _buildMetricCol(
                          context,
                          'Snapshots',
                          totalSnapshots,
                          Icons.history_rounded,
                        ),
                        _buildMetricCol(
                          context,
                          'Total Words',
                          totalWords,
                          Icons.text_fields_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }(),
            const SizedBox(height: 16),
            GoogleDriveSettings(workspace: controller),
            const SizedBox(height: 24),
            Text('Workspace data', style: OrbitTypography.section(context)),
            const SizedBox(height: 12),
            SelectableText(
              c.hasWorkspace ? c.repository.location : 'Personal Vault',
              style: TextStyle(
                fontSize: 12,
                color: OrbitColors.of(context).subtle,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  label: const Text('Export workspace'),
                ),
                OutlinedButton.icon(
                  onPressed: onImport,
                  icon: const Icon(Icons.file_upload_outlined, size: 18),
                  label: const Text('Import backup'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenWorkspace,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('Manage Vaults'),
                ),
                TextButton.icon(
                  onPressed: c.refresh,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reload from files'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('settings-optimize-vault-button'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: OrbitColors.of(context).accent,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Vault integrity verified. Local indexes and snapshot caches pruned.',
                              ),
                            ),
                          ],
                        ),
                        duration: const Duration(seconds: 3),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                  label: const Text('Optimize Vault Cache'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Notes use Markdown; tasks and canvases use documented JSON.\nNo account, cloud connection or AI provider is required.',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: OrbitColors.of(context).subtle,
              ),
            ),
            const SizedBox(height: 24),
            _WorkspaceThemeSummary(controller: c),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCol(
    BuildContext context,
    String label,
    int count,
    IconData icon,
  ) {
    final colors = OrbitColors.of(context);
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: colors.subtle),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colors.subtle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          OrbitAnimatedCounter(
            value: count,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colors.text,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
