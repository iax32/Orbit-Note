import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import '../../app/session_state.dart';
import '../../app/workspace_controller.dart';
import '../../domain/calendar_event.dart';
import '../../domain/search_text.dart';
import '../../domain/universal_object.dart';
import 'calendar_view.dart';

IconData objectIcon(String type) => switch (type) {
  'orbit.canvas' => Icons.dashboard_outlined,
  'orbit.task' => Icons.check_circle_outline,
  'orbit.event' => Icons.event_outlined,
  'orbit.file' => Icons.attach_file,
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
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: OrbitColors.of(context).raised,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
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

class HomeView extends StatelessWidget {
  const HomeView({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller, colors = OrbitColors.of(context);
    final now = DateTime.now();
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

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 30),
          children: [
            Text(
              'YOUR PERSONAL SPACE',
              style: TextStyle(
                color: colors.accent,
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Room for your next idea.',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -.7,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Write it down. Connect the pieces. Pick up where you left off.',
              style: TextStyle(color: colors.subtle, height: 1.5),
            ),
            const SizedBox(height: 28),
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
                FilledButton.tonalIcon(
                  onPressed: () => c.openTodayNote(),
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: const Text("Today's note"),
                ),
                OutlinedButton.icon(
                  onPressed: () => c.create('orbit.canvas'),
                  icon: const Icon(Icons.dashboard_outlined, size: 18),
                  label: const Text('New canvas'),
                ),
                OutlinedButton.icon(
                  onPressed: () => c.create('orbit.task'),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('New task'),
                ),
                OutlinedButton.icon(
                  onPressed: () => c.create('orbit.event'),
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: const Text('New event'),
                ),
                OutlinedButton.icon(
                  onPressed: () => c.navigate(OrbitDestination.search),
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Continue Session / Continue Reading
            if (recentPdf != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 20),
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
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.picture_as_pdf_outlined,
                        color: colors.accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'CONTINUE READING',
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
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: colors.subtle,
                                    ),
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
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: () => c.openObject(recentPdf.id),
                      icon: const Icon(
                        Icons.chrome_reader_mode_outlined,
                        size: 16,
                      ),
                      label: const Text('Resume'),
                    ),
                  ],
                ),
              ),
            ],
            if (recent.isNotEmpty &&
                (recentPdf == null || recent.first.id != recentPdf.id))
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(22),
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
            const SizedBox(height: 16),
            // Today's Tasks
            _heading(context, "Today's tasks", '${todayTasks.length} due'),
            if (todayTasks.isEmpty)
              _quiet(
                context,
                'Nothing due today. Capture or schedule a task when you need one.',
              )
            else
              ...todayTasks
                  .take(5)
                  .map((o) => TaskRow(object: o, controller: c)),
            const SizedBox(height: 26),
            // Upcoming
            _heading(
              context,
              'Upcoming',
              '${upcomingEntries.length} scheduled',
            ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
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
              _quiet(
                context,
                'A thought, a plan, a canvas. Your recent objects will appear here.',
              )
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
          ],
        ),
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

class ObjectRow extends StatelessWidget {
  const ObjectRow({
    super.key,
    required this.object,
    required this.onTap,
    this.trailing,
    this.query,
  });
  final UniversalObject object;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? query;

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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: snippet != null
          ? Text.rich(
              TextSpan(
                children: [
                  if (snippet.source != 'body')
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
            )
          : Text(
              object.typeId.replaceFirst('orbit.', ''),
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
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: _hovered ? colors.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: isDone,
                activeColor: colors.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                onChanged: (val) {
                  widget.onCompleted?.call(val == true);
                  widget.controller.edit(
                    o.id,
                    properties: {...o.properties, 'completed': val},
                  );
                },
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
                        style: TextStyle(
                          fontSize: 13.5,
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
                  style: TextStyle(fontSize: 10.5, color: colors.subtle),
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
                            fontSize: 9.5,
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
                                fontSize: 11,
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
                                    fontSize: 10.5,
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

class TasksView extends StatefulWidget {
  const TasksView({super.key, required this.controller});
  final WorkspaceController controller;
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
  bool showDueDate = true;
  bool showPriority = true;
  bool showProject = true;
  final Map<String, List<String>> _manualOrderPerTab = {};
  final List<TaskViewConfig> _customViews = [];

  bool _creatingTask = false;
  final _newTaskController = TextEditingController();
  final _newTaskFocus = FocusNode();

  @override
  void dispose() {
    _newTaskController.dispose();
    _newTaskFocus.dispose();
    super.dispose();
  }

  void _submitNewTask(String text) async {
    final title = text.trim();
    if (title.isEmpty) return;
    final today = calendarDate(DateTime.now());
    final props = <String, dynamic>{
      if (activeTab == 'today') 'dueDate': today,
      if (activeTab == 'done') 'completed': true,
      if (filterPriority != null) 'priority': filterPriority,
      if (filterProject != null) 'project': filterProject,
    };
    final created = await widget.controller.create(
      'orbit.task',
      title: title,
      properties: props,
    );
    if (created != null && mounted) {
      _newTaskController.clear();
      _newTaskFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final colors = OrbitColors.of(context);
    final today = calendarDate(DateTime.now());

    final allTasks = c.ofType('orbit.task').where((t) => !t.isDeleted).toList();

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

    final activeCustom = _customViews
        .where((v) => v.id == activeTab)
        .firstOrNull;
    final effectiveBaseTab = activeCustom?.baseTab ?? activeTab;

    // Filter by tab
    var visibleTasks = allTasks.where((t) {
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

    // Available projects for filter
    final projects = allTasks
        .map((t) => t.properties['project'] as String?)
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList();

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
                      filterPriority != null || filterProject != null
                          ? Icons.filter_alt
                          : Icons.filter_alt_outlined,
                      size: 18,
                      color: filterPriority != null || filterProject != null
                          ? colors.accent
                          : colors.subtle,
                    ),
                    onSelected: (v) {
                      if (v == 'clear') {
                        setState(() {
                          filterPriority = null;
                          filterProject = null;
                        });
                      } else if (v.startsWith('p:')) {
                        setState(() => filterPriority = v.substring(2));
                      } else if (v.startsWith('proj:')) {
                        setState(() => filterProject = v.substring(5));
                      }
                    },
                    itemBuilder: (_) => [
                      if (filterPriority != null || filterProject != null)
                        const PopupMenuItem(
                          value: 'clear',
                          child: Text('Clear Filters'),
                        ),
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
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Clean View Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTab('todo', 'To Do', todoCount, colors),
                    _buildTab('today', 'Today', todayCount, colors),
                    _buildTab('upcoming', 'Upcoming', upcomingCount, colors),
                    _buildTab('done', 'Done', doneCount, colors),
                    _buildTab('board', 'Board', null, colors),
                    for (final cv in _customViews) _buildCustomTab(cv, colors),
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
              ),
              Divider(height: 1, color: colors.divider),
            ],
          ),
        ),

        // Main View Content
        Expanded(
          child: activeTab == 'board'
              ? _buildKanbanBoard(allTasks, colors)
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
                    icon: const Icon(Icons.close, size: 14),
                    tooltip: 'Cancel',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
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
    final todo = allTasks
        .where((t) => !t.isCompleted && t.properties['status'] != 'in-progress')
        .toList();
    final inProgress = allTasks
        .where((t) => !t.isCompleted && t.properties['status'] == 'in-progress')
        .toList();
    final done = allTasks.where((t) => t.isCompleted).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildKanbanColumn('To Do', todo, null, colors)),
          const SizedBox(width: 14),
          Expanded(
            child: _buildKanbanColumn(
              'In Progress',
              inProgress,
              'in-progress',
              colors,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: _buildKanbanColumn('Done', done, 'done', colors)),
        ],
      ),
    );
  }

  Widget _buildKanbanColumn(
    String title,
    List<UniversalObject> tasks,
    String? targetStatus,
    OrbitColors colors,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: colors.raised,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${tasks.length}',
                  style: TextStyle(fontSize: 10, color: colors.subtle),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final t = tasks[index];
                return Card(
                  elevation: 0,
                  color: colors.raised,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => widget.controller.openObject(t.id),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
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
                                    properties: {
                                      ...t.properties,
                                      'completed': val,
                                    },
                                  );
                                },
                              ),
                              Expanded(
                                child: Text(
                                  t.title.isEmpty ? 'Untitled' : t.title,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    decoration: t.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (t.properties['dueDate'] is String)
                            Padding(
                              padding: const EdgeInsets.only(left: 32, top: 4),
                              child: Text(
                                formatFriendlyDueDate(
                                  parseCalendarDate(t.properties['dueDate']),
                                ),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: colors.subtle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TaskDetail extends StatefulWidget {
  const TaskDetail({super.key, required this.object, required this.controller});
  final UniversalObject object;
  final WorkspaceController controller;
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
    properties: {...widget.object.properties, key: value},
  );
  @override
  Widget build(BuildContext context) {
    final o = widget.object;
    return ListView(
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
              width: 200,
              child: DropdownButtonFormField<String>(
                initialValue:
                    ['low', 'medium', 'high'].contains(o.properties['priority'])
                    ? o.properties['priority'] as String
                    : 'medium',
                decoration: const InputDecoration(labelText: 'Priority'),
                items: ['low', 'medium', 'high']
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
              label: Text(o.properties['dueDate'] as String? ?? 'Set due date'),
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
          minLines: 6,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: 'Add details, context or Markdown links…',
            alignLabelWithHint: true,
          ),
          onChanged: (v) => widget.controller.edit(o.id, body: v),
        ),
        const SizedBox(height: 20),
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

class SearchView extends StatefulWidget {
  const SearchView({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  String query = '';
  List<UniversalObject> results = [];
  Timer? _debounce;
  int _generation = 0;
  String? searchError;
  void _search(String value) {
    _debounce?.cancel();
    final generation = ++_generation;
    setState(() {
      query = value;
      results = [];
      searchError = null;
    });
    if (value.trim().isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 180), () async {
      try {
        final found = await widget.controller.search(value.trim());
        if (mounted && generation == _generation) {
          setState(() => results = found);
        }
      } catch (e) {
        if (mounted && generation == _generation) {
          setState(() => searchError = '$e');
        }
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search your knowledge…',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: _search,
          ),
        ),
        Expanded(
          child: query.trim().isEmpty
              ? const EmptyWorkspace(
                  icon: Icons.search,
                  title: 'Find the thread.',
                  description:
                      'Search note text, task details and object titles. Everything stays on this device.',
                )
              : results.isEmpty
              ? EmptyWorkspace(
                  icon: Icons.search_off,
                  title: searchError == null
                      ? 'No matches yet'
                      : 'Search unavailable',
                  description: 'Try a shorter phrase or another title.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: results.length,
                  itemBuilder: (_, i) => ObjectRow(
                    object: results[i],
                    query: query,
                    onTap: () => widget.controller.openObject(results[i].id),
                  ),
                ),
        ),
      ],
    );
  }
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
            Text(
              'Make room for your way.',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'A few thoughtful controls. Always a way back.',
              style: TextStyle(color: OrbitColors.of(context).subtle),
            ),
            const SizedBox(height: 28),
            const Text(
              'APPEARANCE',
              style: TextStyle(fontSize: 11, letterSpacing: 1.8),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.dark_mode_outlined),
              title: Text('Orbit Dark'),
              subtitle: Text('Graphite surfaces · muted violet accents'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Compact density'),
              value: s.compact,
              onChanged: (v) => c.updateSession((s) => s.compact = v),
            ),
            const SizedBox(height: 22),
            const Text(
              'EDITOR',
              style: TextStyle(fontSize: 11, letterSpacing: 1.8),
            ),
            ListTile(
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reading width'),
              trailing: Text('${s.contentWidth.round()} px'),
            ),
            Slider(
              value: s.contentWidth,
              min: 520,
              max: 1200,
              divisions: 17,
              onChanged: (v) => c.updateSession((s) => s.contentWidth = v),
            ),
            const SizedBox(height: 22),
            const Text(
              'LAYOUT & MOTION',
              style: TextStyle(fontSize: 11, letterSpacing: 1.8),
            ),
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
            const SizedBox(height: 24),
            const Text(
              'YOUR DATA',
              style: TextStyle(fontSize: 11, letterSpacing: 1.8),
            ),
            const SizedBox(height: 12),
            SelectableText(
              c.repository.location,
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
          ],
        ),
      ),
    );
  }
}
