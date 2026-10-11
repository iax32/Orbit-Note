import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/workspace_controller.dart';
import '../../domain/gameplay_release.dart';
import '../../domain/universal_object.dart';
import '../../domain/gameplay_workbench.dart';

class GameplayReleaseWorkspace extends ConsumerStatefulWidget {
  const GameplayReleaseWorkspace({
    super.key,
    required this.controller,
    required this.mechanicIds,
  });
  final WorkspaceController controller;
  final List<String> mechanicIds;
  @override
  ConsumerState<GameplayReleaseWorkspace> createState() => _ReleaseState();
}

class _ReleaseState extends ConsumerState<GameplayReleaseWorkspace> {
  String baseline = '', target = '', queue = 'All';
  String? mechanicId, message;
  bool busy = false;
  late final workspace = widget.controller.repository.workspaceId;
  final title = TextEditingController();
  final checks = TextEditingController(
    text: gameplayTestPresets['Mechanics']!.map((s) => '- [ ] $s').join('\n'),
  );
  final newBuild = TextEditingController();
  WorkspaceController get c => widget.controller;
  @override
  void dispose() {
    title.dispose();
    checks.dispose();
    newBuild.dispose();
    super.dispose();
  }

  Future<void> save(Future<bool> Function() action) async {
    if (workspace != c.repository.workspaceId) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final ok = await action();
      if (mounted) {
        setState(
          () => message = ok ? 'Saved locally.' : c.error ?? 'Could not save.',
        );
      }
    } on Object catch (e) {
      if (mounted) setState(() => message = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void open(UniversalObject object) {
    c.openObject(object.id);
    Navigator.pop(context);
  }

  Widget evidence(UniversalObject object) {
    final ids = gameplayIds(object.properties['resourceIds']);
    final versions = object.properties['sourceVersions'];
    final changed =
        versions is Map &&
        versions.entries.any(
          (e) =>
              e.key is String &&
              (c.find(e.key as String)?.isDeleted != false ||
                  c.find(e.key as String)?.revision != e.value),
        );
    return ExpansionTile(
      key: ValueKey('release-evidence-${object.id}'),
      title: Text(object.title),
      subtitle: Text(
        '${object.properties['build'] ?? 'Design evidence'}${changed ? ' · Source changed or missing' : ''}',
      ),
      childrenPadding: const EdgeInsets.all(12),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectableText(object.body),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(
              onPressed: () => open(object),
              child: const Text('Open original'),
            ),
            for (final id in ids)
              if (c.find(id)?.isDeleted == false)
                OutlinedButton(
                  onPressed: () => open(c.find(id)!),
                  child: Text(c.find(id)!.title),
                )
              else
                Chip(label: Text('Missing evidence: $id')),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(workspaceProvider);
    if (workspace != c.repository.workspaceId) {
      return AlertDialog(
        title: const Text('Workspace changed'),
        content: const Text(
          'Close and reopen Playtest & Release in this Vault.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }
    final mechanics = [
      for (final id in widget.mechanicIds)
        if (c.find(id)?.isDeleted == false) c.find(id)!,
    ];
    final objects = <String, UniversalObject>{
      for (final m in mechanics)
        for (final o in c.gameplayRelated(m.id)) o.id: o,
    }.values.toList();
    final builds =
        objects
            .map((o) => o.properties['build'])
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final selectedBuild = builds.contains(target) ? target : '';
    final left = builds.contains(baseline) ? baseline : '';
    final locked =
        busy || c.repository.readOnly || workspace != c.repository.workspaceId;
    final tasks = objects.where((o) => o.typeId == 'orbit.task').toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    final findings = objects
        .where(
          (o) =>
              o.properties['gameplayKind'] == 'playtest' &&
              o.properties['build'] == selectedBuild,
        )
        .toList();
    final baselineFindings = objects
        .where(
          (o) =>
              o.properties['gameplayKind'] == 'playtest' &&
              o.properties['build'] == left,
        )
        .toList();
    final untriaged = findings
        .where(
          (f) => !tasks.any(
            (t) =>
                t.properties['sourceNoteId'] == f.id ||
                gameplayIds(f.properties['findingTaskIds']).contains(t.id),
          ),
        )
        .toList();
    final plans = objects
        .where((o) => o.properties['gameplayKind'] == 'testPlan')
        .toList();
    final runs =
        objects
            .where(
              (o) =>
                  o.properties['gameplayKind'] == 'testRun' &&
                  o.properties['build'] == selectedBuild,
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latestRuns = <String, UniversalObject>{};
    for (final run in runs) {
      latestRuns.putIfAbsent('${run.properties['testPlanId']}', () => run);
    }
    final unverified = tasks
        .where(
          (t) => gameplayTaskReview(objects, t, selectedBuild) != 'Verified',
        )
        .length;
    final regressions = left.isEmpty
        ? 0
        : tasks
              .where(
                (t) =>
                    gameplayVerification(
                          objects,
                          t.id,
                          left,
                        )?.properties['verificationOutcome'] ==
                        'passed' &&
                    gameplayTaskReview(objects, t, selectedBuild) ==
                        'Failed fix',
              )
              .length;
    final incompletePlans = plans
        .where((p) => !gameplayPlanCovered(p, latestRuns[p.id]))
        .length;
    Widget buildPicker(
      String label,
      String value,
      void Function(String) change,
    ) => SizedBox(
      width: 250,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        key: ValueKey('$label-$value-${builds.join(',')}'),
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          const DropdownMenuItem(value: '', child: Text('Choose build')),
          for (final b in builds)
            DropdownMenuItem(
              value: b,
              child: Text(b, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) => setState(() => change(v ?? '')),
      ),
    );
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Playtest & Release',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  children: [
                    const Text(
                      'Compare recorded evidence. This is a manual review aid, not an automated test or shipping certification.',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        buildPicker(
                          'Baseline build',
                          left,
                          (v) => baseline = v,
                        ),
                        buildPicker(
                          'Release build',
                          selectedBuild,
                          (v) => target = v,
                        ),
                      ],
                    ),
                    if (message != null)
                      Semantics(liveRegion: true, child: Text(message!)),
                    const SizedBox(height: 16),
                    if (selectedBuild.isEmpty)
                      const Text(
                        'Choose a release build to see readiness and regressions.',
                      )
                    else ...[
                      Text(
                        'Release review · $unverified tasks need attention · ${untriaged.length} findings without fix tasks · $incompletePlans incomplete test plans · $regressions regressions from baseline',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (tasks.isEmpty && plans.isEmpty)
                        const Text(
                          'No task or test-plan coverage recorded. Readiness is unknown.',
                        ),
                      if (plans.isEmpty)
                        const Text('No reusable test plans recorded.'),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final value in [
                            'All',
                            'Failed fix',
                            'Blocked test',
                            'Awaiting retest',
                            'Verified · task open',
                            'Verified',
                          ])
                            ChoiceChip(
                              label: Text(value),
                              selected: queue == value,
                              onSelected: (_) => setState(() => queue = value),
                            ),
                        ],
                      ),
                      for (final task in tasks)
                        if (queue == 'All' ||
                            gameplayTaskReview(objects, task, selectedBuild) ==
                                queue)
                          ExpansionTile(
                            title: Text(task.title),
                            subtitle: Text(
                              '${left.isEmpty ? '' : '$left: ${gameplayTaskReview(objects, task, left)} → '}$selectedBuild: ${gameplayTaskReview(objects, task, selectedBuild)}',
                            ),
                            children: [
                              TextButton(
                                onPressed: () => open(task),
                                child: const Text('Open fix task'),
                              ),
                              if (gameplayVerification(
                                    objects,
                                    task.id,
                                    selectedBuild,
                                  )
                                  case final result?)
                                evidence(result),
                              if (left.isNotEmpty)
                                if (gameplayVerification(objects, task.id, left)
                                    case final result?)
                                  evidence(result),
                            ],
                          ),
                      ExpansionTile(
                        title: Text(
                          'Findings · ${findings.length} (${untriaged.length} without fixes)',
                        ),
                        children: [for (final f in findings) evidence(f)],
                      ),
                      if (left.isNotEmpty)
                        ExpansionTile(
                          title: Text(
                            'Baseline findings · ${baselineFindings.length}',
                          ),
                          children: [
                            for (final f in baselineFindings) evidence(f),
                          ],
                        ),
                      ExpansionTile(
                        title: const Text('Test runs and evidence'),
                        children: [
                          for (final run in runs)
                            Column(
                              children: [
                                evidence(run),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    for (final outcome in [
                                      'pending',
                                      'passed',
                                      'failed',
                                      'blocked',
                                    ])
                                      TextButton(
                                        onPressed: locked
                                            ? null
                                            : () => save(
                                                () => c.setGameplayTestOutcome(
                                                  run,
                                                  outcome,
                                                ),
                                              ),
                                        child: Text(
                                          outcome ==
                                                  run.properties['testOutcome']
                                              ? '$outcome ✓'
                                              : outcome,
                                        ),
                                      ),
                                  ],
                                ),
                                Text(
                                  'Checklist ${gameplayChecklist(run.body).$1}/${gameplayChecklist(run.body).$2} · edit the original to record checks and observations',
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                    const Divider(height: 32),
                    ExpansionTile(
                      title: Text('Reusable test plans · ${plans.length}'),
                      initiallyExpanded: plans.isEmpty,
                      children: [
                        for (final plan in plans)
                          ListTile(
                            title: Text(plan.title),
                            subtitle: Text(
                              '${gameplayChecklist(plan.body).$2} checks',
                            ),
                            onTap: () => open(plan),
                            trailing: TextButton(
                              onPressed: locked
                                  ? null
                                  : () => save(
                                      () async =>
                                          await c.startGameplayTestRun(
                                            plan,
                                            newBuild.text,
                                          ) !=
                                          null,
                                    ),
                              child: const Text('Start run'),
                            ),
                          ),
                        TextField(
                          controller: newBuild,
                          maxLength: 300,
                          decoration: const InputDecoration(
                            labelText: 'Build for new run',
                          ),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: mechanics.any((m) => m.id == mechanicId)
                              ? mechanicId
                              : null,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Mechanic for new plan',
                          ),
                          items: [
                            for (final m in mechanics)
                              DropdownMenuItem(
                                value: m.id,
                                child: Text(
                                  m.title,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: locked
                              ? null
                              : (v) => setState(() => mechanicId = v),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final p in gameplayTestPresets.keys)
                              ActionChip(
                                label: Text(p),
                                onPressed: locked
                                    ? null
                                    : () => setState(() {
                                        title.text = '$p checks';
                                        checks.text = gameplayTestPresets[p]!
                                            .map((s) => '- [ ] $s')
                                            .join('\n');
                                      }),
                              ),
                          ],
                        ),
                        TextField(
                          controller: title,
                          maxLength: 300,
                          decoration: const InputDecoration(
                            labelText: 'Plan title',
                          ),
                        ),
                        TextField(
                          controller: checks,
                          minLines: 5,
                          maxLines: 12,
                          maxLength: 20000,
                          decoration: const InputDecoration(
                            labelText: 'Editable Markdown checklist',
                          ),
                        ),
                        FilledButton(
                          onPressed: locked || mechanicId == null
                              ? null
                              : () => save(
                                  () async =>
                                      await c.createGameplayTestPlan(
                                        mechanicId: mechanicId!,
                                        title: title.text,
                                        checklist: checks.text,
                                      ) !=
                                      null,
                                ),
                          child: const Text('Save test plan'),
                        ),
                      ],
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
}
