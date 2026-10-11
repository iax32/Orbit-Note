import 'universal_object.dart';

/// Build-local verification. A pass on another build is never release evidence.
UniversalObject? gameplayVerification(
  Iterable<UniversalObject> objects,
  String taskId,
  String build,
) {
  final matches =
      objects
          .where(
            (o) =>
                !o.isDeleted &&
                o.properties['gameplayKind'] == 'verification' &&
                o.properties['verificationTaskId'] == taskId &&
                o.properties['build'] == build,
          )
          .toList()
        ..sort((a, b) {
          final order = b.createdAt.compareTo(a.createdAt);
          return order != 0 ? order : b.id.compareTo(a.id);
        });
  return matches.firstOrNull;
}

String gameplayTaskReview(
  Iterable<UniversalObject> objects,
  UniversalObject task,
  String build,
) {
  final verification = gameplayVerification(objects, task.id, build);
  if (verification == null) return 'Awaiting retest';
  return switch (verification.properties['verificationOutcome']) {
    'passed' =>
      task.isCompleted || task.properties['status'] == 'done'
          ? 'Verified'
          : 'Verified · task open',
    'failed' => 'Failed fix',
    'blocked' => 'Blocked test',
    _ => 'Unknown result',
  };
}

/// Ordinary Markdown checklists remain authoritative and editable.
(int, int) gameplayChecklist(String body) {
  var total = 0, done = 0;
  var fence = '';
  for (final line in body.split(RegExp(r'\r\n|\r|\n'))) {
    final marker = RegExp(r'^ {0,3}(`{3,}|~{3,})').firstMatch(line);
    if (marker != null) {
      final run = marker.group(1)!;
      if (fence.isEmpty) {
        fence = run;
      } else if (run[0] == fence[0] && run.length >= fence.length) {
        fence = '';
      }
      continue;
    }
    if (fence.isNotEmpty) continue;
    final check = RegExp(r'^\s*[-+*] \[([ xX])\] \S').firstMatch(line);
    if (check != null) {
      total++;
      if (check.group(1) != ' ') done++;
    }
  }
  return (done, total);
}

bool gameplayRunPassed(UniversalObject run) {
  final (done, total) = gameplayChecklist(run.body);
  return total > 0 &&
      run.properties['gameplayVersion'] == 1 &&
      done == total &&
      run.properties['testOutcome'] == 'passed';
}

bool gameplayPlanCovered(UniversalObject plan, UniversalObject? run) =>
    run != null &&
    !run.isDeleted &&
    !plan.isDeleted &&
    run.properties['testPlanId'] == plan.id &&
    run.properties['sourcePlanRevision'] == plan.revision &&
    gameplayRunPassed(run);

const gameplayTestPresets = {
  'Mechanics': [
    'Inputs respond as specified',
    'Boundary and failure cases',
    'Feedback and animation',
    'Pause and resume behaviour',
  ],
  'Levels': [
    'Spawn and checkpoints',
    'Progression and exits',
    'Navigation and collision',
    'Soft-lock recovery',
  ],
  'Controls': [
    'Keyboard and mouse',
    'Controller mapping',
    'Remapping persists',
    'Focus loss and reconnect',
  ],
  'Saves': [
    'New game and save',
    'Load and restart',
    'Missing or damaged save',
    'Version compatibility',
  ],
  'Performance': [
    'Frame time on target hardware',
    'Memory during long sessions',
    'Loading and streaming',
    'Record hardware and measurement method',
  ],
};
