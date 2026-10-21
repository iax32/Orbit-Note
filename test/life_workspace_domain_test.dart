import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/life_workspace.dart';
import 'package:orbit_note/domain/life_templates.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/domain/object_connections.dart';
import 'package:orbit_note/app/session_state.dart';

UniversalObject lifeObject(
  String id,
  LifeKind kind,
  Map<String, dynamic> fields, {
  String type = 'orbit.note',
}) => UniversalObject(
  id: id,
  workspaceId: 'vault',
  typeId: type,
  title: id,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  properties: {
    'life': {'version': 1, 'kind': kind.name, 'state': 'active', ...fields},
  },
);

void main() {
  test('every starter has valid metadata and meaningful editable prompts', () {
    expect(lifePresets.length, greaterThanOrEqualTo(30));
    expect(lifePresets.map((p) => p.id).toSet(), hasLength(lifePresets.length));
    for (final p in lifePresets) {
      validateLifeData({
        'version': 1,
        'kind': p.kind.name,
        'state': 'active',
        ...p.fields,
      });
      expect(p.body, contains('##'));
    }
  });
  for (final invalid in <Map<String, dynamic>>[
    {'version': 2},
    {'target': double.nan},
    {'value': double.infinity},
    {'date': '2026-02-30'},
    {'startDate': '2026-04-10', 'endDate': '2026-04-01'},
    {'mood': 6},
    {'sleepHours': 25},
    {
      'weekdays': [0, 8],
    },
    {'frequency': 'sometimes'},
    {'setsPerExercise': 1.5},
    {'weekCount': 27},
    {'restUntil': 'yesterday'},
    {
      'resources': [12],
    },
    {
      'checked': [-1],
    },
    {
      'sets': [
        {
          'id': 'x',
          'exerciseId': 'e',
          'completed': true,
          'weightUnit': 'stones',
          'distanceUnit': 'km',
        },
      ],
    },
  ]) {
    test('invalid typed fields are rejected: $invalid', () {
      expect(
        () => validateLifeData({
          'version': 1,
          'kind': 'goal',
          'state': 'active',
          ...invalid,
        }),
        throwsFormatException,
      );
    });
  }
  test(
    'future and malformed Life records remain ordinary readable objects',
    () {
      final o = lifeObject('a', LifeKind.goal, {
        'version': 2,
        'future': {'keep': true},
      });
      expect(lifeKind(o), isNull);
      expect(lifeData(o)['future'], {'keep': true});
      expect(
        lifeKind(lifeObject('b', LifeKind.session, {'sets': 'bad'})),
        isNull,
      );
    },
  );
  test(
    'weekly targets use Monday to Sunday civil dates across DST boundaries',
    () {
      final habit = lifeObject('h', LifeKind.habit, {
        'frequency': 'weekly',
        'target': 4,
      });
      final index = LifeIndex([
        habit,
        lifeObject('one', LifeKind.habitLog, {
          'parentId': 'h',
          'date': '2026-10-19',
          'value': 1,
          'outcome': 'done',
        }),
        lifeObject('two', LifeKind.habitLog, {
          'parentId': 'h',
          'date': '2026-10-25',
          'value': 2,
          'outcome': 'done',
        }),
        lifeObject('rest', LifeKind.habitLog, {
          'parentId': 'h',
          'date': '2026-10-24',
          'value': 8,
          'outcome': 'break',
        }),
        lifeObject('next', LifeKind.habitLog, {
          'parentId': 'h',
          'date': '2026-10-26',
          'value': 8,
          'outcome': 'done',
        }),
      ], now: DateTime(2026, 10, 25));
      expect(index.habitValue('h', index.now), 3);
      expect(index.progress(habit), .75);
      expect(lifeDay(DateTime(2026, 10, 25), 1), DateTime(2026, 10, 26));
    },
  );
  test(
    'scheduled weekdays and intentional breaks do not create daily failures',
    () {
      final h = lifeObject('h', LifeKind.habit, {
        'frequency': 'weekdays',
        'weekdays': [1, 3],
        'pausedUntil': '2026-10-21',
      });
      expect(lifeHabitDue(h, DateTime(2026, 10, 21)), false);
      expect(lifeHabitDue(h, DateTime(2026, 10, 26)), true);
      expect(lifeHabitDue(h, DateTime(2026, 10, 27)), false);
    },
  );
  test(
    'linked tasks and manually measured goals use distinct progress sources',
    () {
      final goal = lifeObject('g', LifeKind.goal, {});
      UniversalObject task(String id, bool done) => UniversalObject(
        id: id,
        workspaceId: 'vault',
        typeId: 'orbit.task',
        title: id,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        properties: {'lifeGoalId': 'g', 'completed': done},
      );
      final index = LifeIndex([goal, task('a', true), task('b', false)]);
      expect(index.progress(goal), .5);
      expect(index.summary(goal), contains('linked actions'));
      final measured = lifeObject('g', LifeKind.goal, {
        'progressMode': 'measurement',
        'baseline': 80,
        'target': 70,
        'value': 75,
      });
      expect(index.progress(measured), .5);
      expect(index.summary(measured), contains('recorded measurement'));
      expect(LifeIndex([goal]).progress(goal), isNull);
    },
  );
  test('check-in series leave gaps unknown and separate custom units', () {
    final index = LifeIndex([
      lifeObject('a', LifeKind.checkin, {
        'date': '2026-10-20',
        'value': 5,
        'unit': 'pages',
        'mood': 4,
      }),
      lifeObject('b', LifeKind.checkin, {
        'date': '2026-10-20',
        'value': 100,
        'unit': 'minutes',
        'mood': 2,
      }),
      lifeObject('c', LifeKind.checkin, {
        'date': '2026-10-18',
        'value': 3,
        'unit': 'pages',
      }),
    ], now: DateTime(2026, 10, 21));
    expect(index.series(LifeKind.checkin, 'mood'), [
      (date: '2026-10-20', value: 3.0),
    ]);
    expect(
      index
          .series(LifeKind.checkin, 'value', unit: 'pages')
          .map((s) => s.value),
      [3, 5],
    );
  });
  test(
    'exercise history separates pounds and kilograms and excludes unfinished sets',
    () {
      Map<String, dynamic> set(
        String id,
        String unit,
        num weight, {
        bool done = true,
      }) => {
        'id': id,
        'exerciseId': 'e',
        'completed': done,
        'weight': weight,
        'weightUnit': unit,
        'distanceUnit': 'km',
        'reps': 5,
      };
      final index = LifeIndex([
        lifeObject('s', LifeKind.session, {
          'state': 'completed',
          'date': '2026-10-20',
          'sets': [
            set('a', 'kg', 20),
            set('b', 'lb', 40),
            set('c', 'kg', 999, done: false),
          ],
        }),
        lifeObject('active', LifeKind.session, {
          'date': '2026-10-21',
          'sets': [set('d', 'kg', 1000)],
        }),
      ]);
      expect(index.exerciseRecords('e')['weight (kg)'], 20);
      expect(index.exerciseRecords('e')['weight (lb)'], 40);
      expect(index.exerciseSeries('e', 'weight', 'kg'), [
        (date: '2026-10-20', value: 20.0),
      ]);
    },
  );
  test(
    'personal Canvas copies rewire placements and retain universal and unknown identities',
    () {
      final source = {
        'elements': [
          {
            'id': 'a',
            'type': 'card',
            'objectId': 'canonical',
            'groupId': 'g',
            'future': {'id': 'opaque'},
          },
          {
            'id': 'b',
            'type': 'connector',
            'startId': 'a',
            'endId': 'c',
            'groupId': 'g',
          },
          {'id': 'c', 'type': 'sticky', 'columnId': 'a'},
        ],
        'future': {'retained': true},
      };
      var i = 0;
      final copy = remapLifeCanvas(source, () => 'new${i++}');
      expect(copy['elements'][0]['objectId'], 'canonical');
      expect(copy['elements'][1]['startId'], copy['elements'][0]['id']);
      expect(copy['elements'][1]['endId'], copy['elements'][2]['id']);
      expect(copy['elements'][2]['columnId'], copy['elements'][0]['id']);
      expect(copy['elements'][0]['future'], {'id': 'opaque'});
      expect(copy['future'], source['future']);
      expect((source['elements'] as List)[0]['id'], 'a');
      expect(() => remapLifeCanvas(source, () => 'same'), throwsStateError);
    },
  );
  test('life links enter the canonical connections graph', () {
    final goal = lifeObject('g', LifeKind.goal, {}),
        practice = lifeObject('p', LifeKind.practice, {'goalId': 'g'});
    final graph = ObjectConnectionResolver().resolve([goal, practice]);
    expect(graph.any((e) => e.source.id == 'p' && e.target.id == 'g'), isTrue);
  });
  test('Home settings survive serialization with unknown device settings', () {
    final session = SessionState.fromJson({
      'lifeWorkspace': {
        'homeSections': ['Goals'],
        'future': 42,
      },
      'opaque': 'keep',
    });
    final reopened = SessionState.fromJson(session.toJson());
    expect(reopened.lifeWorkspace, {
      'homeSections': ['Goals'],
      'future': 42,
    });
    expect(reopened.toJson()['opaque'], 'keep');
  });
  test(
    'large history has stable incoming links without repeatedly scanning all records',
    () {
      final habit = lifeObject('h', LifeKind.habit, {'target': 1});
      final index = LifeIndex([
        habit,
        for (var i = 0; i < 10000; i++)
          lifeObject('log$i', LifeKind.habitLog, {
            'parentId': 'h',
            'date': '2026-10-20',
            'value': 1,
            'outcome': 'done',
          }),
      ]);
      expect(index.children['h'], hasLength(10000));
      expect(index.linkedTo('h'), hasLength(10000));
      expect(index.habitValue('h', DateTime(2026, 10, 20)), 10000);
    },
  );
  test(
    'a target without a recorded current measurement does not invent progress',
    () {
      final goal = lifeObject('g', LifeKind.goal, {
        'progressMode': 'measurement',
        'target': 10,
      });
      expect(LifeIndex([goal]).progress(goal), isNull);
    },
  );
}
