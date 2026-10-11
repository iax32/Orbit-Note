import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../app/workspace_controller.dart';
import '../../domain/working_calendar.dart';
import '../../domain/universal_object.dart';

Future<UniversalObject?> showWorkingCalendarEditor(
  BuildContext context,
  WorkspaceController c, {
  UniversalObject? calendar,
}) => showDialog<UniversalObject>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _CalendarEditor(controller: c, calendar: calendar),
);

class _CalendarEditor extends StatefulWidget {
  const _CalendarEditor({required this.controller, this.calendar});
  final WorkspaceController controller;
  final UniversalObject? calendar;
  @override
  State<_CalendarEditor> createState() => _CalendarEditorState();
}

class _CalendarEditorState extends State<_CalendarEditor> {
  late final TextEditingController name, exceptions;
  late Map<String, dynamic> definition;
  late Set<int> week;
  String? error;
  bool saving = false, supported = true;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(
      text: widget.calendar?.title ?? 'Project work week',
    );
    try {
      final raw = widget.calendar?.properties['workingCalendar'];
      definition = raw == null
          ? WorkingCalendar.standard()
          : Map<String, dynamic>.from(raw as Map);
      final cal = WorkingCalendar(definition);
      week = (definition['weekdays'] as List).cast<int>().toSet();
      final keys = cal.exceptions.keys.cast<String>().toList()..sort();
      exceptions = TextEditingController(
        text: [
          for (final date in keys)
            '$date | ${cal.exceptions[date]['working'] == true ? 'on' : 'off'} | ${cal.exceptions[date]['label'] ?? ''}',
        ].join('\n'),
      );
    } on Object catch (e) {
      supported = false;
      error = '$e';
      week = {};
      definition = {};
      exceptions = TextEditingController();
    }
  }

  @override
  void dispose() {
    name.dispose();
    exceptions.dispose();
    super.dispose();
  }

  Map<String, dynamic> draft() {
    final values = <String, dynamic>{};
    for (final line in exceptions.text.split('\n')) {
      if (line.trim().isEmpty) continue;
      final fields = line.split('|').map((s) => s.trim()).toList();
      if (fields.length < 2 ||
          fields.length > 3 ||
          !['on', 'off'].contains(fields[1]) ||
          values.containsKey(fields[0])) {
        throw const FormatException(
          'Use one unique date per line: YYYY-MM-DD | off or on | label.',
        );
      }
      final old = (definition['exceptions'] as Map?)?[fields[0]];
      values[fields[0]] = {
        if (old is Map) ...Map<String, dynamic>.from(old),
        'working': fields[1] == 'on',
        'label': fields.length == 3 ? fields[2] : '',
      };
    }
    final result = {
      ...definition,
      'version': 1,
      'weekdays': week.toList()..sort(),
      'exceptions': values,
    };
    WorkingCalendar(result);
    return result;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: OrbitDialog(
      title: const Text('Working calendar'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (supported) ...[
            TextField(
              controller: name,
              enabled: !saving,
              decoration: const InputDecoration(labelText: 'Calendar name'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Reusable across projects. Calendar edits flag affected work ranges; they never move tasks automatically.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 1; i <= 7; i++)
                  FilterChip(
                    label: Text(
                      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i - 1],
                    ),
                    selected: week.contains(i),
                    onSelected: saving
                        ? null
                        : (v) =>
                              setState(() => v ? week.add(i) : week.remove(i)),
                  ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final preset in {
                  'Mon–Fri': {1, 2, 3, 4, 5},
                  'Sun–Thu': {7, 1, 2, 3, 4},
                  'Every day': {1, 2, 3, 4, 5, 6, 7},
                }.entries)
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => setState(() => week = {...preset.value}),
                    child: Text(preset.key),
                  ),
              ],
            ),
            TextField(
              controller: exceptions,
              enabled: !saving,
              maxLines: 7,
              minLines: 3,
              decoration: const InputDecoration(
                labelText: 'Holidays and extra work days',
                helperText:
                    'One per line: 2026-12-25 | off | Winter break\nAn extra working day uses on instead of off.',
              ),
            ),
          ],
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (supported)
          FilledButton(
            onPressed:
                saving ||
                    widget.controller.repository.readOnly ||
                    widget.calendar?.isReadOnly == true
                ? null
                : () async {
                    Map<String, dynamic> value;
                    try {
                      value = draft();
                    } on Object catch (e) {
                      setState(() => error = '$e');
                      return;
                    }
                    setState(() {
                      saving = true;
                      error = null;
                    });
                    final result = await widget.controller.saveWorkingCalendar(
                      previous: widget.calendar,
                      title: name.text,
                      definition: value,
                    );
                    if (!mounted || !context.mounted) return;
                    if (result != null) {
                      Navigator.pop(context, result);
                    } else {
                      setState(() {
                        saving = false;
                        error =
                            widget.controller.error ??
                            'This calendar changed. Reopen it to try again.';
                      });
                    }
                  },
            child: Text(saving ? 'Saving…' : 'Save calendar'),
          ),
      ],
    ),
  );
}

Future<void> showGanttCalendars(
  BuildContext context,
  WorkspaceController c,
  UniversalObject view,
) async {
  Object? selected = view.properties['workCalendarId'];
  bool saving = false;
  String? error;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final calendars = c.workingCalendars;
        return PopScope(
          canPop: !saving,
          child: OrbitDialog(
            title: const Text('Project calendars'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Choose the default for new schedules in this view. Tasks already bound to a calendar keep their own calendar.',
                ),
                ListTile(
                  selected: selected == null,
                  leading: Icon(
                    selected == null
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  onTap: saving ? null : () => set(() => selected = null),
                  title: const Text('Calendar days · every day'),
                ),
                if (selected != null && !calendars.any((o) => o.id == selected))
                  Text(
                    'Selected calendar is missing or unsupported: $selected',
                  ),
                for (final cal in calendars)
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          selected: selected == cal.id,
                          leading: Icon(
                            selected == cal.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                          ),
                          onTap: saving
                              ? null
                              : () => set(() => selected = cal.id),
                          title: Text(cal.title),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit ${cal.title}',
                        onPressed:
                            saving || cal.isReadOnly || c.repository.readOnly
                            ? null
                            : () async {
                                await showWorkingCalendarEditor(
                                  ctx,
                                  c,
                                  calendar: cal,
                                );
                                if (ctx.mounted) set(() {});
                              },
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                OutlinedButton.icon(
                  onPressed: saving || c.repository.readOnly
                      ? null
                      : () async {
                          final result = await showWorkingCalendarEditor(
                            ctx,
                            c,
                          );
                          if (ctx.mounted && result != null) {
                            set(() => selected = result.id);
                          }
                        },
                  icon: const Icon(Icons.add),
                  label: const Text('New working calendar'),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: saving || view.isReadOnly || c.repository.readOnly
                    ? null
                    : () async {
                        if (selected != null && selected is! String) {
                          set(
                            () => error =
                                'Choose a supported calendar explicitly.',
                          );
                          return;
                        }
                        set(() => saving = true);
                        final ok = await c.assignGanttCalendar(
                          view,
                          selected as String?,
                        );
                        if (!ctx.mounted) return;
                        if (ok) {
                          Navigator.pop(ctx);
                        } else {
                          set(() {
                            saving = false;
                            error =
                                c.error ??
                                'The view changed. Reopen calendars.';
                          });
                        }
                      },
                child: Text(saving ? 'Saving…' : 'Use calendar'),
              ),
            ],
          ),
        );
      },
    ),
  );
}
