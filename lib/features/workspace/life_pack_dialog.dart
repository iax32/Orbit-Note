import '../../app/orbit_components.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../app/workspace_controller.dart';
import '../../domain/life_templates.dart';
import '../../domain/universal_object.dart';

Future<UniversalObject?> showLifePackSetup(
  BuildContext context,
  WorkspaceController c,
) => showOrbitDialog<UniversalObject>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _LifePackDialog(controller: c),
);

class _LifePackDialog extends StatefulWidget {
  const _LifePackDialog({required this.controller});
  final WorkspaceController controller;
  @override
  State<_LifePackDialog> createState() => _LifePackDialogState();
}

class _LifePackDialogState extends State<_LifePackDialog> {
  final name = TextEditingController(),
      amount = TextEditingController(text: '1'),
      unit = TextEditingController(text: 'times'),
      exercises = TextEditingController(),
      weeks = TextEditingController(text: '4');
  final requestId = const Uuid().v4();
  late final generation = widget.controller.workspaceGeneration;
  String pack = 'foundations';
  String? error;
  bool saving = false, partial = false;
  List<int> weekdays = [1, 3, 5];
  @override
  void dispose() {
    for (final c in [name, amount, unit, exercises, weeks]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    final target = double.tryParse(amount.text),
        count = int.tryParse(weeks.text);
    if (name.text.trim().isEmpty ||
        target == null ||
        !target.isFinite ||
        target <= 0 ||
        count == null ||
        count < 1 ||
        count > 26 ||
        weekdays.isEmpty ||
        pack == 'training' && exercises.text.trim().isEmpty) {
      setState(
        () => error =
            'Enter a name, a positive amount, valid weeks and your exercises where needed.',
      );
      return;
    }
    if (generation != widget.controller.workspaceGeneration) {
      setState(() => error = 'The Vault changed. Close and reopen this setup.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final result = await widget.controller.installLifePack(
      pack,
      name.text.trim(),
      requestId: requestId,
      target: target,
      unit: unit.text.trim(),
      exercises: exercises.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      weeks: count,
      weekdays: weekdays,
    );
    if (!mounted) return;
    setState(() => saving = false);
    if (generation != widget.controller.workspaceGeneration ||
        !result.complete) {
      setState(() {
        partial = result.ids.isNotEmpty;
        error =
            '${result.ids.length} records available. ${result.error ?? 'The Vault changed.'} Retry continues the same setup.';
      });
      return;
    }
    Navigator.pop(context, widget.controller.find(result.boardId!));
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: const Text('Set up a connected Life pack'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AbsorbPointer(
                absorbing: saving || partial,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: pack,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Pack'),
                      items: [
                        for (final p in lifePacks.entries)
                          DropdownMenuItem(
                            value: p.key,
                            child: Text(
                              p.value.$1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => pack = v!),
                    ),
                    const SizedBox(height: 12),
                    Text(lifePacks[pack]!.$2),
                    const SizedBox(height: 18),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'My workspace / goal name',
                      ),
                    ),
                    if (['foundations', 'learning'].contains(pack)) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: amount,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Habit amount (your choice)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: unit,
                        decoration: const InputDecoration(
                          labelText: 'Habit unit (minutes, pages, sessions…)',
                        ),
                      ),
                    ],
                    if (pack == 'training') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: exercises,
                        minLines: 3,
                        maxLines: 7,
                        decoration: const InputDecoration(
                          labelText: 'Your exercises · one name per line',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: weeks,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Program weeks (1–26)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Planned weekdays'),
                      Wrap(
                        spacing: 4,
                        children: [
                          for (var day = 1; day <= 7; day++)
                            FilterChip(
                              label: Text(
                                [
                                  'Mon',
                                  'Tue',
                                  'Wed',
                                  'Thu',
                                  'Fri',
                                  'Sat',
                                  'Sun',
                                ][day - 1],
                              ),
                              selected: weekdays.contains(day),
                              onSelected: (v) => setState(
                                () => weekdays = v
                                    ? {...weekdays, day}.toList()
                                    : (weekdays..remove(day)),
                              ),
                            ),
                        ],
                      ),
                      const Text(
                        'Use the program’s Schedule action to choose calendar dates. This setup does not record completed workouts.',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Creates editable local notes and a Canvas of live references. No automatic progress, account or AI service.',
              ),
              if (saving)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: SelectableText(error!),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: Text(partial ? 'Close · keep saved records' : 'Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(partial ? 'Retry setup' : 'Create workspace'),
        ),
      ],
    ),
  );
}
