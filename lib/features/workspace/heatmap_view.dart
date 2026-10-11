import 'package:flutter/material.dart';
import '../../app/orbit_theme.dart';
import '../../app/orbit_density.dart';
import '../../app/workspace_controller.dart';
import '../../domain/universal_object.dart';

enum HeatmapMetric {
  all('All Activity', Icons.auto_awesome_outlined),
  dailyNotes('Daily Notes', Icons.today_outlined),
  tasks('Tasks Completed', Icons.check_circle_outline),
  sessions('Work Sessions', Icons.timer_outlined);

  const HeatmapMetric(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Generic Year/Month Heatmap widget that turns time into an interactive navigation canvas.
class HeatmapWidget extends StatefulWidget {
  const HeatmapWidget({
    super.key,
    required this.controller,
    this.year,
    this.metric = HeatmapMetric.all,
    this.onSelectDate,
  });

  final WorkspaceController controller;
  final int? year;
  final HeatmapMetric metric;
  final ValueChanged<DateTime>? onSelectDate;

  @override
  State<HeatmapWidget> createState() => _HeatmapWidgetState();
}

class _HeatmapWidgetState extends State<HeatmapWidget> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.year ?? DateTime.now().year;
  }

  @override
  void didUpdateWidget(covariant HeatmapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.year != null && widget.year != _year) {
      _year = widget.year!;
    }
  }

  Map<DateTime, List<UniversalObject>> _calculateActivity(
    HeatmapMetric metric,
  ) {
    final c = widget.controller;
    final activity = <DateTime, List<UniversalObject>>{};

    void record(DateTime dt, UniversalObject obj) {
      if (dt.year != _year) return;
      final key = DateTime(dt.year, dt.month, dt.day);
      activity.putIfAbsent(key, () => []).add(obj);
    }

    switch (metric) {
      case HeatmapMetric.dailyNotes:
        for (final note in c.ofType('orbit.note').where((o) => !o.isDeleted)) {
          final isDaily =
              note.properties['daily'] == true ||
              RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(note.title);
          if (isDaily) {
            record(note.updatedAt, note);
          }
        }
        break;

      case HeatmapMetric.tasks:
        for (final task in c.ofType('orbit.task').where((o) => !o.isDeleted)) {
          if (task.isCompleted) {
            final completedAt = task.properties['completedAt'] is String
                ? DateTime.tryParse(task.properties['completedAt'] as String)
                : null;
            record(completedAt ?? task.updatedAt, task);
          }
        }
        break;

      case HeatmapMetric.sessions:
        for (final session in c.session.completedWorkSessions) {
          final startStr = session['start'] as String?;
          final dt = startStr != null ? DateTime.tryParse(startStr) : null;
          if (dt != null) {
            final dummyObj = UniversalObject(
              id: 'session-${dt.millisecondsSinceEpoch}',
              workspaceId: c.session.activeId ?? 'local',
              typeId: 'orbit.session',
              title: session['title'] as String? ?? 'Focus Session',
              createdAt: dt,
              updatedAt: dt,
            );
            record(dt, dummyObj);
          }
        }
        break;

      case HeatmapMetric.all:
        for (final obj in c.activeObjects.where((o) => !o.isDeleted)) {
          record(obj.updatedAt, obj);
        }
        break;
    }

    return activity;
  }

  Color _cellColor(int count, OrbitColors colors) {
    if (count == 0) return colors.panelSecondary;
    if (count <= 2) return colors.accent.withValues(alpha: 0.28);
    if (count <= 5) return colors.accent.withValues(alpha: 0.52);
    if (count <= 8) return colors.accent.withValues(alpha: 0.78);
    return colors.accent;
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final activity = _calculateActivity(widget.metric);

    final startOfYear = DateTime(_year, 1, 1);
    final endOfYear = DateTime(_year, 12, 31);
    final totalDays = endOfYear.difference(startOfYear).inDays + 1;

    var activeDays = 0;
    var totalItems = 0;
    var maxStreak = 0;
    var currentStreak = 0;

    for (var i = 0; i < totalDays; i++) {
      final d = startOfYear.add(Duration(days: i));
      final items = activity[d] ?? const [];
      if (items.isNotEmpty) {
        activeDays++;
        totalItems += items.length;
        currentStreak++;
        if (currentStreak > maxStreak) maxStreak = currentStreak;
      } else {
        currentStreak = 0;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Previous year',
                  icon: const Icon(Icons.chevron_left, size: 18),
                  onPressed: () => setState(() => _year--),
                ),
                Text(
                  '$_year Heatmap',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  tooltip: 'Next year',
                  icon: const Icon(Icons.chevron_right, size: 18),
                  onPressed: () => setState(() => _year++),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.panel,
                borderRadius: BorderRadius.circular(OrbitRadius.small),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                '$totalItems items · $activeDays active days · $maxStreak day streak',
                style: TextStyle(fontSize: 12, color: colors.subtle),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 12-month grid layout
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var month = 1; month <= 12; month++)
                _buildMonthBlock(context, month, activity, colors),
            ],
          ),
        ),

        const SizedBox(height: 12),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Less', style: TextStyle(fontSize: 11, color: colors.subtle)),
            const SizedBox(width: 6),
            _legendCell(colors.panelSecondary, colors),
            const SizedBox(width: 4),
            _legendCell(colors.accent.withValues(alpha: 0.28), colors),
            const SizedBox(width: 4),
            _legendCell(colors.accent.withValues(alpha: 0.52), colors),
            const SizedBox(width: 4),
            _legendCell(colors.accent.withValues(alpha: 0.78), colors),
            const SizedBox(width: 4),
            _legendCell(colors.accent, colors),
            const SizedBox(width: 6),
            Text('More', style: TextStyle(fontSize: 11, color: colors.subtle)),
          ],
        ),
      ],
    );
  }

  Widget _legendCell(Color color, OrbitColors colors) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2.5),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
    );
  }

  Widget _buildMonthBlock(
    BuildContext context,
    int month,
    Map<DateTime, List<UniversalObject>> activity,
    OrbitColors colors,
  ) {
    const monthNames = [
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

    final firstDay = DateTime(_year, month, 1);
    final daysInMonth = DateTime(_year, month + 1, 0).day;
    final leadEmptyDays = firstDay.weekday - 1; // 0 = Mon, 6 = Sun

    return Container(
      margin: const EdgeInsets.only(right: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            monthNames[month - 1],
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.subtle,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 7 * 16.0,
            child: Wrap(
              spacing: 3,
              runSpacing: 3,
              children: [
                for (var e = 0; e < leadEmptyDays; e++)
                  const SizedBox(width: 13, height: 13),
                for (var day = 1; day <= daysInMonth; day++)
                  _buildDayCell(
                    DateTime(_year, month, day),
                    activity[DateTime(_year, month, day)] ?? const [],
                    colors,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(
    DateTime date,
    List<UniversalObject> items,
    OrbitColors colors,
  ) {
    final count = items.length;
    final cellBg = _cellColor(count, colors);
    final isToday = _isSameDay(date, DateTime.now());

    final formattedDate =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final tooltipText = StringBuffer('$formattedDate · $count items');
    if (items.isNotEmpty) {
      tooltipText.write('\n');
      for (final it in items.take(3)) {
        tooltipText.write('• ${it.title.isEmpty ? "Untitled" : it.title}\n');
      }
      if (items.length > 3) {
        tooltipText.write('+ ${items.length - 3} more');
      }
    }

    return Tooltip(
      message: tooltipText.toString().trim(),
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        key: ValueKey('heatmap-cell-$formattedDate'),
        borderRadius: BorderRadius.circular(2.5),
        onTap: () {
          if (widget.onSelectDate != null) {
            widget.onSelectDate!(date);
          } else {
            widget.controller.openTodayNote(date: date);
          }
        },
        child: Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: cellBg,
            borderRadius: BorderRadius.circular(2.5),
            border: Border.all(
              color: isToday
                  ? colors.text
                  : colors.border.withValues(alpha: 0.5),
              width: isToday ? 1.0 : 0.5,
            ),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Standalone full-screen Heatmap View for SavedViewHost.
class HeatmapView extends StatefulWidget {
  const HeatmapView({
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
  State<HeatmapView> createState() => _HeatmapViewState();
}

class _HeatmapViewState extends State<HeatmapView> {
  HeatmapMetric _metric = HeatmapMetric.all;

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final density = OrbitDensity.of(context);

    return Scaffold(
      backgroundColor: colors.workspace,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(density.cardPadding * 2),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Activity Heatmap',
                      style: OrbitTypography.workspaceTitle(context),
                    ),
                    SegmentedButton<HeatmapMetric>(
                      segments: [
                        for (final m in HeatmapMetric.values)
                          ButtonSegment(
                            value: m,
                            label: Text(m.label),
                            icon: Icon(m.icon, size: 16),
                          ),
                      ],
                      selected: {_metric},
                      onSelectionChanged: (val) {
                        if (val.isNotEmpty) setState(() => _metric = val.first);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Time as navigation. Select any date to open its daily context or inspect universal objects.',
                  style: TextStyle(color: colors.subtle),
                ),
                const SizedBox(height: 24),
                Card(
                  color: colors.panel,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(OrbitRadius.card),
                    side: BorderSide(color: colors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: HeatmapWidget(
                      controller: widget.controller,
                      metric: _metric,
                      onSelectDate: (d) =>
                          widget.controller.openTodayNote(date: d),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
