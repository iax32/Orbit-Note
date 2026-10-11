import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/orbit_theme.dart';
import '../../app/orbit_components.dart';
import '../../app/workspace_controller.dart';
import '../../domain/calendar_event.dart';

const _miniMonthNames = [
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

/// Compact monthly calendar widget designed for Orbit Note's Explorer sidebar.
///
/// Features:
/// - Month/Year header with prev/next navigation, quick "Today" affordance,
///   and collapsible toggle to save sidebar height.
/// - 7-day column grid (Monday to Sunday) showing civil days of current month.
/// - Prominent visual indicator for "Today" and selection state.
/// - Activity dots beneath days that have existing daily notes or scheduled events/tasks.
/// - Clicking any date opens or creates the corresponding daily note (`YYYY-MM-DD`).
class ExplorerMiniCalendar extends ConsumerStatefulWidget {
  const ExplorerMiniCalendar({
    super.key,
    required this.controller,
    this.onDateSelected,
  });

  final WorkspaceController controller;
  final ValueChanged<DateTime>? onDateSelected;

  @override
  ConsumerState<ExplorerMiniCalendar> createState() =>
      _ExplorerMiniCalendarState();
}

class _ExplorerMiniCalendarState extends ConsumerState<ExplorerMiniCalendar> {
  late DateTime _visibleMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  void _previousMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _visibleMonth = DateTime(now.year, now.month);
      _selectedDay = today;
    });
  }

  void _selectDate(DateTime day) {
    setState(() {
      _selectedDay = day;
      if (day.month != _visibleMonth.month) {
        _visibleMonth = DateTime(day.year, day.month);
      }
    });
    widget.onDateSelected?.call(day);
    widget.controller.openTodayNote(date: day);
  }

  bool _hasDailyNote(DateTime day) {
    final slug =
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return widget.controller.activeObjects.any(
      (o) =>
          !o.isDeleted &&
          o.typeId == 'orbit.note' &&
          (o.title == slug || o.properties['dailyDate'] == slug),
    );
  }

  bool _hasEventsOrTasks(DateTime day) {
    return entriesOn(widget.controller.activeObjects, day).isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(workspaceProvider);
    final colors = OrbitColors.of(context);
    final isCollapsed = widget.controller.explorerCalendarCollapsed;

    final allDays = calendarMonthDays(_visibleMonth);
    // If the 6th row (indices 35..41) belongs entirely to next month, omit it to save vertical space.
    final hasWeek6 = allDays
        .skip(35)
        .take(7)
        .any((d) => d.month == _visibleMonth.month);
    final visibleDays = hasWeek6 ? allDays : allDays.take(35).toList();

    return Container(
      key: const ValueKey('explorer-mini-calendar'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colors.raised.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context, colors, isCollapsed),
          AnimatedSize(
            duration: OrbitMotionScope.duration(
              context,
              OrbitMotion.panel,
              spatial: true,
            ),
            curve: OrbitMotion.ease,
            alignment: Alignment.topCenter,
            child: isCollapsed
                ? const SizedBox(width: double.infinity)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 6),
                      _buildWeekdayHeader(colors),
                      const SizedBox(height: 4),
                      OrbitContentTransition(
                        identity: _visibleMonth,
                        child: _buildDayGrid(visibleDays, colors),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _miniIconButton({
    required Key key,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
    double turns = 0,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: AnimatedRotation(
            turns: turns,
            duration: OrbitMotionScope.duration(
              context,
              OrbitMotion.control,
              spatial: true,
            ),
            curve: OrbitMotion.ease,
            child: Icon(icon, size: 14, color: color),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    OrbitColors colors,
    bool isCollapsed,
  ) {
    final monthName = _miniMonthNames[_visibleMonth.month - 1];
    final today = DateTime.now();
    final title = isCollapsed
        ? '${today.day} ${_miniMonthNames[today.month - 1]} ${today.year}'
        : '$monthName ${_visibleMonth.year}';

    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: _goToToday,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 13,
                    color: colors.accent,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Tooltip(
          message: 'Jump to today',
          child: InkWell(
            key: const ValueKey('mini-cal-today'),
            borderRadius: BorderRadius.circular(4),
            onTap: _goToToday,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                'Today',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 1),
        if (!isCollapsed)
          _miniIconButton(
            key: const ValueKey('mini-cal-prev'),
            icon: Icons.chevron_left,
            tooltip: 'Previous month',
            onTap: _previousMonth,
            color: colors.subtle,
          ),
        if (!isCollapsed)
          _miniIconButton(
            key: const ValueKey('mini-cal-next'),
            icon: Icons.chevron_right,
            tooltip: 'Next month',
            onTap: _nextMonth,
            color: colors.subtle,
          ),
        _miniIconButton(
          key: const ValueKey('mini-cal-collapse'),
          icon: Icons.keyboard_arrow_down,
          turns: isCollapsed ? 0 : .5,
          tooltip: isCollapsed ? 'Expand calendar' : 'Collapse calendar',
          onTap: () {
            widget.controller.toggleExplorerCalendar();
            setState(() {});
          },
          color: colors.subtle,
        ),
      ],
    );
  }

  Widget _buildWeekdayHeader(OrbitColors colors) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: [
        for (final day in days)
          Expanded(
            child: Center(
              child: Text(
                day,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: colors.subtle,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDayGrid(List<DateTime> visibleDays, OrbitColors colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int w = 0; w < visibleDays.length; w += 7)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              children: [
                for (int d = 0; d < 7; d++)
                  Expanded(child: _buildDayCell(visibleDays[w + d], colors)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDayCell(DateTime day, OrbitColors colors) {
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final isCurrentMonth = day.month == _visibleMonth.month;
    final isSelected =
        _selectedDay != null &&
        day.year == _selectedDay!.year &&
        day.month == _selectedDay!.month &&
        day.day == _selectedDay!.day;
    final hasDaily = _hasDailyNote(day);
    final hasEvents = _hasEventsOrTasks(day);

    final dayKey =
        'mini-cal-day-${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

    final monthName = _miniMonthNames[day.month - 1];
    final tooltipText =
        '$monthName ${day.day}, ${day.year}'
        '${hasDaily ? '\n• Daily note exists' : ''}'
        '${hasEvents ? '\n• Has scheduled tasks or events' : ''}'
        '\nClick to open or create daily note';

    return Tooltip(
      message: tooltipText,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        key: ValueKey(dayKey),
        borderRadius: BorderRadius.circular(5),
        onTap: () => _selectDate(day),
        child: AnimatedContainer(
          duration: OrbitMotionScope.duration(context, OrbitMotion.control),
          curve: OrbitMotion.ease,
          constraints: const BoxConstraints(minHeight: 24),
          padding: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.accent.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: isToday
                ? Border.all(color: colors.accent, width: 1.2)
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isToday
                      ? FontWeight.w700
                      : (isSelected ? FontWeight.w600 : FontWeight.normal),
                  color: isToday
                      ? colors.accent
                      : (isCurrentMonth
                            ? colors.text
                            : colors.muted.withValues(alpha: 0.4)),
                ),
              ),
              if (hasDaily || hasEvents)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (hasDaily)
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.accent,
                          ),
                        ),
                      if (hasDaily && hasEvents) const SizedBox(width: 1.5),
                      if (hasEvents)
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.warning,
                          ),
                        ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}
