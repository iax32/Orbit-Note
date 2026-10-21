import 'calendar_event.dart';
import 'universal_object.dart';

enum LifeKind {
  goal('Goal', 'Goals'),
  habit('Habit', 'Habits'),
  routine('Routine', 'Habits'),
  exercise('Exercise', 'Fitness'),
  workout('Workout', 'Fitness'),
  program('Program', 'Fitness'),
  session('Workout session', 'Fitness'),
  journal('Journal entry', 'Journal'),
  experiment('Personal experiment', 'Experiments'),
  checkin('Personal check-in', 'Check-ins'),
  skill('Skill / learning plan', 'Learning'),
  practice('Practice session', 'Learning'),
  life('Life plan', 'Life'),
  review('Period review', 'Reviews'),
  template('Personal template', 'Templates'),
  habitLog('Habit record', 'History'),
  routineLog('Routine record', 'History');

  const LifeKind(this.label, this.section);
  final String label, section;
}

const lifeSections = [
  'Home',
  'Goals',
  'Habits',
  'Fitness',
  'Journal',
  'Experiments',
  'Check-ins',
  'Learning',
  'Life',
  'Reviews',
  'Templates',
];
const lifeStates = ['active', 'paused', 'completed', 'archived', 'retired'];
const lifeLinkFields = [
  'parentId',
  'goalId',
  'programId',
  'workoutId',
  'courseId',
];
const lifeListLinks = [
  'resources',
  'exerciseIds',
  'workoutIds',
  'stepIds',
  'milestoneIds',
];

LifeKind? lifeKind(UniversalObject? object) {
  if (object == null || object.isDeleted) return null;
  final raw = object.properties['life'];
  if (raw is! Map || raw['version'] != 1) return null;
  try {
    validateLifeData(Map<String, dynamic>.from(raw));
  } on Object {
    return null;
  }
  return LifeKind.values.where((v) => v.name == raw['kind']).firstOrNull;
}

Map<String, dynamic> lifeData(UniversalObject object) =>
    object.properties['life'] is Map
    ? Map<String, dynamic>.from(object.properties['life'] as Map)
    : {};
List<String> lifeIds(Map<String, dynamic> data, String field) =>
    data[field] is List
    ? (data[field] as List).whereType<String>().toList()
    : [];
Iterable<String> lifeReferences(UniversalObject object) sync* {
  if (lifeKind(object) == null) return;
  final data = lifeData(object);
  for (final key in lifeLinkFields) {
    if (data[key] is String && data[key] != '') yield data[key] as String;
  }
  for (final key in lifeListLinks) {
    yield* lifeIds(data, key);
  }
  for (final set in data['sets'] as List? ?? []) {
    if (set is Map && set['exerciseId'] is String) {
      yield set['exerciseId'] as String;
    }
  }
}

/// Known fields are validated; additive opaque fields are retained by commands.
void validateLifeData(Map<String, dynamic> data) {
  if (data['version'] != 1 ||
      !LifeKind.values.any((k) => k.name == data['kind'])) {
    throw const FormatException(
      'This Life record version is not supported. Its original data is preserved.',
    );
  }
  if (data['state'] != null && !lifeStates.contains(data['state'])) {
    throw const FormatException('Choose a supported state.');
  }
  for (final key in [
    'date',
    'startDate',
    'endDate',
    'reviewDate',
    'pausedUntil',
  ]) {
    if (data[key] != null &&
        data[key] != '' &&
        parseCalendarDate(data[key]) == null) {
      throw FormatException('Choose a valid $key.');
    }
  }
  if (parseCalendarDate(data['startDate']) != null &&
      parseCalendarDate(data['endDate']) != null &&
      (data['startDate'] as String).compareTo(data['endDate'] as String) > 0) {
    throw const FormatException('The finish must be on or after the start.');
  }
  for (final key in [
    'target',
    'baseline',
    'value',
    'minimum',
    'minutes',
    'sleepHours',
    'outdoorMinutes',
    'weekCount',
    'restSeconds',
    'setsPerExercise',
  ]) {
    final v = data[key];
    if (v != null && (v is! num || !v.isFinite || v < 0 || v > 1000000)) {
      throw FormatException('Enter a finite non-negative $key.');
    }
  }
  for (final key in ['mood', 'energy', 'stress']) {
    final v = data[key];
    if (v != null && (v is! num || !v.isFinite || v < 1 || v > 5)) {
      throw FormatException('$key uses a 1–5 scale.');
    }
  }
  if (data['sleepHours'] is num && data['sleepHours'] > 24) {
    throw const FormatException('Sleep hours must be between 0 and 24.');
  }
  for (final field in ['startedAt', 'finishedAt']) {
    if (data[field] != null && DateTime.tryParse('${data[field]}') == null) {
      throw FormatException('Invalid $field timestamp.');
    }
  }
  for (final rule in [
    ('weekCount', 1, 26),
    ('setsPerExercise', 1, 10),
    ('restSeconds', 0, 3600),
  ]) {
    final v = data[rule.$1];
    if (v != null && (v is! int || v < rule.$2 || v > rule.$3)) {
      throw FormatException('Invalid ${rule.$1}.');
    }
  }
  if (data['kind'] == 'habit' && data['target'] is num && data['target'] <= 0) {
    throw const FormatException('Habit target must be greater than zero.');
  }
  if (data['restUntil'] != null &&
      DateTime.tryParse('${data['restUntil']}') == null) {
    throw const FormatException('Invalid rest deadline.');
  }
  if (data['frequency'] != null &&
      !['daily', 'weekly', 'weekdays'].contains(data['frequency'])) {
    throw const FormatException('Choose a supported habit frequency.');
  }
  if (data['weekdays'] != null &&
      (data['weekdays'] is! List ||
          (data['weekdays'] as List).any((v) => v is! int || v < 1 || v > 7))) {
    throw const FormatException('Choose valid weekdays.');
  }
  if (data['outcome'] != null &&
      ![
        'done',
        'skip',
        'break',
        'continue',
        'adapt',
        'stop',
      ].contains(data['outcome'])) {
    throw const FormatException('Choose a supported outcome.');
  }
  if (data['weightUnit'] != null &&
      !['kg', 'lb'].contains(data['weightUnit'])) {
    throw const FormatException('Weight units must be kg or lb.');
  }
  if (data['distanceUnit'] != null &&
      !['m', 'km', 'mi'].contains(data['distanceUnit'])) {
    throw const FormatException('Choose m, km or mi.');
  }
  for (final key in lifeLinkFields) {
    if (data[key] != null &&
        (data[key] is! String || (data[key] as String).length > 200)) {
      throw FormatException('Invalid $key reference.');
    }
  }
  for (final key in [...lifeListLinks, 'items']) {
    if (data[key] != null &&
        (data[key] is! List ||
            (data[key] as List).length > 200 ||
            (data[key] as List).any((v) => v is! String || v.length > 2000))) {
      throw FormatException('Invalid $key list.');
    }
  }
  if (data['checked'] != null &&
      (data['checked'] is! List ||
          (data['checked'] as List).any(
            (v) => v is! int || v < 0 || v >= 200,
          ))) {
    throw const FormatException('Invalid routine completion.');
  }
  final sets = data['sets'];
  if (sets != null) {
    if (sets is! List || sets.length > 1000) {
      throw const FormatException('A session supports up to 1,000 sets.');
    }
    final ids = <String>{};
    for (final set in sets) {
      if (set is! Map ||
          set['id'] is! String ||
          (set['id'] as String).isEmpty ||
          !ids.add(set['id'] as String) ||
          set['exerciseId'] is! String ||
          set['completed'] is! bool) {
        throw const FormatException('Invalid exercise set identity.');
      }
      for (final field in ['reps', 'weight', 'distance', 'seconds', 'effort']) {
        final v = set[field];
        if (v != null &&
            (v is! num ||
                !v.isFinite ||
                v < 0 ||
                v > (field == 'effort' ? 10 : 1000000))) {
          throw FormatException('Invalid set $field.');
        }
      }
      if (!['kg', 'lb'].contains(set['weightUnit']) ||
          !['m', 'km', 'mi'].contains(set['distanceUnit'])) {
        throw const FormatException('Set units are required.');
      }
    }
  }
  for (final entry in data.entries) {
    if (entry.value is String && (entry.value as String).length > 250000) {
      throw const FormatException('A Life field exceeds the editable limit.');
    }
  }
}

DateTime lifeDay(DateTime day, [int delta = 0]) =>
    DateTime(day.year, day.month, day.day + delta);
bool lifeHabitDue(UniversalObject habit, DateTime day) {
  final d = lifeData(habit), stamp = calendarDate(day);
  if (d['state'] != 'active' ||
      (d['startDate'] is String &&
          (d['startDate'] as String).compareTo(stamp) > 0) ||
      (parseCalendarDate(d['pausedUntil']) != null &&
          (d['pausedUntil'] as String).compareTo(stamp) >= 0)) {
    return false;
  }
  return d['frequency'] != 'weekdays' ||
      lifeIdsAsWeekdays(d).contains(day.weekday);
}

List<int> lifeIdsAsWeekdays(Map<String, dynamic> d) => d['weekdays'] is List
    ? (d['weekdays'] as List).whereType<int>().toList()
    : [];

class LifeIndex {
  LifeIndex(Iterable<UniversalObject> objects, {DateTime? now})
    : now = now ?? DateTime.now() {
    for (final o in objects) {
      if (o.isDeleted) continue;
      byId[o.id] = o;
      final refs = {
        ...lifeReferences(o),
        if (o.properties['lifeGoalId'] is String)
          o.properties['lifeGoalId'] as String,
        if (o.properties['resources'] is List)
          ...(o.properties['resources'] as List).whereType<String>(),
      };
      for (final id in refs) {
        _incoming.putIfAbsent(id, () => []).add(o);
      }
      final kind = lifeKind(o);
      if (kind != null) {
        records.add(o);
        byKind.putIfAbsent(kind, () => []).add(o);
        final parent = lifeData(o)['parentId'];
        if (parent is String) children.putIfAbsent(parent, () => []).add(o);
      }
    }
    for (final list in children.values) {
      list.sort(
        (a, b) => '${lifeData(a)['date']}'.compareTo('${lifeData(b)['date']}'),
      );
    }
  }
  final DateTime now;
  final byId = <String, UniversalObject>{};
  final records = <UniversalObject>[];
  final byKind = <LifeKind, List<UniversalObject>>{};
  final children = <String, List<UniversalObject>>{};
  List<UniversalObject> of(LifeKind kind) => byKind[kind] ?? [];
  final _incoming = <String, List<UniversalObject>>{};
  List<UniversalObject> linkedTo(String id) => _incoming[id] ?? const [];
  List<UniversalObject> habitLogs(String id, DateTime day) {
    final parent = byId[id];
    if (parent == null) return [];
    final d = lifeData(parent);
    final start = d['frequency'] == 'weekly'
        ? lifeDay(day, 1 - day.weekday)
        : lifeDay(day);
    final end = lifeDay(start, d['frequency'] == 'weekly' ? 7 : 1);
    return (children[id] ?? []).where((o) {
      final date = parseCalendarDate(lifeData(o)['date']);
      return lifeKind(o) == LifeKind.habitLog &&
          date != null &&
          !date.isBefore(start) &&
          date.isBefore(end);
    }).toList();
  }

  double habitValue(String id, DateTime day) => habitLogs(id, day).fold(
    0.0,
    (sum, o) =>
        sum +
        (lifeData(o)['outcome'] == 'done'
            ? (lifeData(o)['value'] as num? ?? 0).toDouble()
            : 0),
  );
  double? progress(UniversalObject o) {
    final d = lifeData(o), kind = lifeKind(o);
    if (kind == LifeKind.habit) {
      final target = d['target'] as num? ?? 1;
      return target <= 0
          ? null
          : (habitValue(o.id, now) / target).clamp(0, 1).toDouble();
    }
    if (kind == LifeKind.goal ||
        kind == LifeKind.skill ||
        kind == LifeKind.program) {
      final tasks = linkedTo(
        o.id,
      ).where((o) => o.typeId == 'orbit.task').toList();
      if (d['progressMode'] != 'measurement' && tasks.isNotEmpty) {
        return tasks.where((o) => o.isCompleted).length / tasks.length;
      }
      final target = d['target'] as num?, baseline = d['baseline'] as num? ?? 0;
      if (target != null && target != baseline && d['value'] is num) {
        return (((d['value'] as num? ?? baseline) - baseline) /
                (target - baseline))
            .clamp(0, 1)
            .toDouble();
      }
    }
    if (kind == LifeKind.session) {
      final sets = d['sets'] as List? ?? [];
      if (sets.isEmpty) return null;
      return sets.where((s) => s['completed'] == true).length / sets.length;
    }
    return null;
  }

  String summary(UniversalObject o) {
    final d = lifeData(o), kind = lifeKind(o);
    if (kind == LifeKind.habit) {
      return '${habitValue(o.id, now).toStringAsFixed(1)} / ${d['target'] ?? 1} ${d['unit'] ?? 'times'} · ${d['frequency'] ?? 'daily'}';
    }
    if (kind == LifeKind.session) {
      final sets = d['sets'] as List? ?? [];
      return '${sets.where((s) => s['completed'] == true).length}/${sets.length} sets · ${d['state']}';
    }
    final p = progress(o);
    if (p != null) {
      return '${(p * 100).round()}% · ${d['progressMode'] == 'measurement' ? 'recorded measurement' : 'linked actions'}';
    }
    if (kind == LifeKind.practice) {
      return '${d['minutes'] ?? 0} minutes · ${d['date'] ?? ''}';
    }
    return '${kind?.label ?? 'Linked item'} · ${d['state'] ?? 'active'}${d['date'] == null ? '' : ' · ${d['date']}'}';
  }

  List<UniversalObject> inPeriod(
    DateTime start,
    DateTime end, {
    LifeKind? kind,
  }) => records.where((o) {
    final day = parseCalendarDate(lifeData(o)['date']);
    return (kind == null || lifeKind(o) == kind) &&
        day != null &&
        !day.isBefore(start) &&
        day.isBefore(end);
  }).toList();
  List<({String date, double value})> series(
    LifeKind kind,
    String field, {
    int days = 30,
    String? unit,
  }) {
    final result = <({String date, double value})>[];
    final samples = <String, List<double>>{};
    for (final o in inPeriod(
      lifeDay(now, 1 - days),
      lifeDay(now, 1),
      kind: kind,
    )) {
      final d = lifeData(o), value = d[field];
      if (value is num &&
          value.isFinite &&
          (unit == null || (d['unit'] ?? '') == unit)) {
        samples.putIfAbsent('${d['date']}', () => []).add(value.toDouble());
      }
    }
    for (var i = 1 - days; i <= 0; i++) {
      final date = calendarDate(lifeDay(now, i)),
          values = samples[calendarDate(lifeDay(now, i))];
      if (values != null) {
        result.add((
          date: date,
          value: values.reduce((a, b) => a + b) / values.length,
        ));
      }
    }
    return result;
  }

  List<({String date, double value})> exerciseSeries(
    String exerciseId,
    String metric,
    String unit,
  ) {
    final values = <String, double>{};
    for (final session in of(
      LifeKind.session,
    ).where((s) => lifeData(s)['state'] == 'completed')) {
      final date = lifeData(session)['date'];
      if (parseCalendarDate(date) == null) continue;
      for (final set in lifeData(session)['sets'] as List? ?? []) {
        if (set['exerciseId'] != exerciseId || set['completed'] != true) {
          continue;
        }
        if (metric == 'weight' && set['weightUnit'] != unit ||
            metric == 'distance' && set['distanceUnit'] != unit) {
          continue;
        }
        final v = set[metric];
        if (v is num &&
            v.isFinite &&
            (!values.containsKey(date) || v > values[date]!)) {
          values[date as String] = v.toDouble();
        }
      }
    }
    return [
      for (final date in values.keys.toList()..sort())
        (date: date, value: values[date]!),
    ];
  }

  Map<String, double> exerciseRecords(String exerciseId) {
    final records = <String, double>{};
    for (final session in of(
      LifeKind.session,
    ).where((s) => lifeData(s)['state'] == 'completed')) {
      for (final s in lifeData(session)['sets'] as List? ?? []) {
        if (s is! Map ||
            s['exerciseId'] != exerciseId ||
            s['completed'] != true) {
          continue;
        }
        for (final f in ['weight', 'reps', 'distance', 'seconds']) {
          final v = s[f];
          if (v is! num || !v.isFinite) continue;
          final key =
              '$f${f == 'weight'
                  ? ' (${s['weightUnit']})'
                  : f == 'distance'
                  ? ' (${s['distanceUnit']})'
                  : ''}';
          if (!records.containsKey(key) || v > records[key]!) {
            records[key] = v.toDouble();
          }
        }
      }
    }
    return records;
  }
}
