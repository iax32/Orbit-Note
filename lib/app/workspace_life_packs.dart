part of 'workspace_controller.dart';

extension WorkspaceLifePacks on WorkspaceController {
  /// Ordinary recoverable objects, with explicit partial results and stable
  /// retry keys. Never claim that a multi-file pack save is atomic.
  Future<LifePackResult> installLifePack(
    String pack,
    String title, {
    required String requestId,
    List<String> exercises = const [],
    double target = 1,
    String unit = 'times',
    int weeks = 4,
    List<int> weekdays = const [1, 3, 5],
  }) async {
    final generation = workspaceGeneration, ids = <String>[];
    if (!lifePacks.containsKey(pack) ||
        title.trim().isEmpty ||
        requestId.isEmpty ||
        !target.isFinite ||
        target <= 0 ||
        weeks < 1 ||
        weeks > 26 ||
        weekdays.isEmpty ||
        weekdays.any((d) => d < 1 || d > 7) ||
        exercises.length > 30 ||
        pack == 'training' &&
            exercises.where((s) => s.trim().isNotEmpty).isEmpty) {
      return const LifePackResult([], error: 'Review the pack setup fields.');
    }
    Future<UniversalObject> ensure(
      String slot,
      String presetId, {
      Map<String, dynamic> fields = const {},
    }) async {
      if (generation != workspaceGeneration) {
        throw StateError('The Vault changed. Reopen the pack setup.');
      }
      final preset = lifePresets.firstWhere((p) => p.id == presetId);
      final object = await createLife(
        preset.kind,
        '${title.trim()} · ${preset.title}',
        body: preset.body,
        fields: {...preset.fields, ...fields},
        actionKey: 'pack:$requestId:$slot',
      );
      if (object == null) {
        throw StateError(
          error ?? 'A pack record could not be saved. Retry to continue.',
        );
      }
      ids.add(object.id);
      return object;
    }

    try {
      switch (pack) {
        case 'foundations':
          final goal = await ensure('goal', 'goal');
          await ensure(
            'habit',
            'weekly',
            fields: {
              'goalId': goal.id,
              'frequency': 'daily',
              'target': target,
              'minimum': target,
              'unit': unit,
            },
          );
          await ensure('routine', 'morning', fields: {'goalId': goal.id});
          await ensure(
            'journal',
            'daily',
            fields: {'date': calendarDate(DateTime.now()), 'goalId': goal.id},
          );
        case 'training':
          final exerciseIds = <String>[];
          for (var i = 0; i < exercises.length; i++) {
            final name = exercises[i].trim();
            if (name.isEmpty) continue;
            if (generation != workspaceGeneration) {
              throw StateError('The Vault changed. Reopen the pack setup.');
            }
            final exercise = await createLife(
              LifeKind.exercise,
              name,
              body: '## My instructions\n\n## Equipment\n\n## Substitutions\n',
              actionKey: 'pack:$requestId:exercise:$i',
            );
            if (exercise == null) {
              throw StateError(
                error ?? 'Could not save an exercise. Retry to continue.',
              );
            }
            ids.add(exercise.id);
            exerciseIds.add(exercise.id);
          }
          final workout = await ensure(
            'workout',
            'workout',
            fields: {'exerciseIds': exerciseIds},
          );
          await ensure(
            'program',
            'program',
            fields: {
              'workoutIds': [workout.id],
              'weekCount': weeks,
              'weekdays': weekdays,
            },
          );
        case 'learning':
          final goal = await ensure('goal', 'goal');
          final skill = await ensure(
            'skill',
            'skill',
            fields: {'goalId': goal.id},
          );
          await ensure(
            'habit',
            'weekly',
            fields: {
              'goalId': goal.id,
              'resources': [skill.id],
              'target': target,
              'unit': unit,
            },
          );
          await ensure(
            'journal',
            'daily',
            fields: {
              'date': calendarDate(DateTime.now()),
              'resources': [skill.id],
            },
          );
        case 'home':
          await ensure('meal', 'meal');
          await ensure('groceries', 'groceries');
          await ensure('home', 'home');
          await ensure('routine', 'shutdown');
        case 'outdoors':
          final goal = await ensure('goal', 'goal');
          await ensure('trip', 'trip', fields: {'goalId': goal.id});
          await ensure(
            'journal',
            'nature',
            fields: {'date': calendarDate(DateTime.now()), 'goalId': goal.id},
          );
      }
      if (generation != workspaceGeneration) {
        throw StateError('The Vault changed. Reopen the pack setup.');
      }
      final key = 'pack:$requestId:board';
      var board = activeObjects
          .where(
            (o) =>
                o.typeId == 'orbit.canvas' &&
                o.properties['lifePackActionKey'] == key,
          )
          .firstOrNull;
      if (board == null) {
        final lock = '$generation|$key',
            pending = _lifeOperations['$generation|$key'];
        if (pending != null) {
          board = await pending;
        } else {
          final future = _createLifeBoard(
            '${title.trim()} · workspace',
            ids,
            properties: {'lifePackActionKey': key},
          );
          _lifeOperations[lock] = future;
          try {
            board = await future;
          } finally {
            if (identical(_lifeOperations[lock], future)) {
              _lifeOperations.remove(lock);
            }
          }
        }
      }
      if (board == null) {
        throw StateError(
          error ??
              'The records were saved, but the board was not. Retry to finish.',
        );
      }
      return LifePackResult(ids, boardId: board.id);
    } on Object catch (e) {
      return LifePackResult(ids, error: '$e');
    }
  }
}
