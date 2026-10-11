import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/domain/smart_view_query.dart';
import 'package:orbit_note/domain/task_planning.dart';
import 'package:orbit_note/domain/workspace_context.dart';
import 'package:orbit_note/app/session_state.dart';

UniversalObject object(
  String id, {
  String type = 'orbit.task',
  String title = 'Task',
  Map<String, dynamic> properties = const {},
}) => UniversalObject(
  id: id,
  workspaceId: 'vault',
  typeId: type,
  title: title,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 2, 1),
  properties: properties,
);

Map<String, dynamic> rule(
  String frequency,
  String anchor, [
  int interval = 1,
]) => {
  'version': 1,
  'frequency': frequency,
  'interval': interval,
  'anchorDate': anchor,
};

void main() {
  test(
    'unsupported planning data survives unrelated edits but cannot be completed',
    () {
      final imported = object(
        'a',
        properties: {
          'dueDate': '2026-10-08',
          'recurrence': {'version': 99, 'future': 'preserve'},
          'blockedBy': {'version': 99, 'future': 'preserve'},
        },
      );
      expect(
        () => validateTaskPlanning(imported.copyWith(title: 'Rename'), [
          imported,
        ], previous: imported),
        returnsNormally,
      );
      expect(
        () => completeTaskOccurrence(imported, {
          ...imported.properties,
          'completed': true,
        }, DateTime(2026)),
        throwsFormatException,
      );
    },
  );
  test(
    'query combines typed, tag, relation, relative date and numeric predicates',
    () {
      final rows = [
        object(
          'a',
          properties: {
            'project': 'Course',
            'tags': ['exam'],
            'credits': 6,
            'dueDate': '2026-10-08',
            'parentTaskId': 'root',
          },
        ),
        object('b', properties: {'credits': 2}),
        object('c'),
      ];
      final q = SmartViewQuery({
        ...SmartViewQuery.empty(),
        'rules': [
          {'field': 'project', 'op': 'equals', 'value': 'course'},
          {'field': 'tags', 'op': 'contains', 'value': 'exam'},
          {'field': 'credits', 'op': 'gte', 'value': 3},
          {'field': 'dueDate', 'op': 'on', 'value': 'today'},
          {'field': 'relation:parentTaskId', 'op': 'equals', 'value': 'root'},
        ],
      });
      expect(q.evaluate(rows, now: DateTime(2026, 10, 8)).map((o) => o.id), [
        'a',
      ]);
      final any = SmartViewQuery({
        ...q.json,
        'match': 'any',
        'rules': [
          {'field': 'credits', 'op': 'lte', 'value': 3},
          {'field': 'credits', 'op': 'empty'},
        ],
      });
      expect(any.evaluate(rows).map((o) => o.id).toSet(), {'b', 'c'});
    },
  );
  test(
    'manual membership, folder descendants and missing values remain explicit',
    () {
      final rows = [
        object('a', properties: {'folder': 'Uni/Math'}),
        object('b', properties: {'folder': 'Uni2'}),
        object('c'),
      ];
      final view = object(
        'view',
        type: 'orbit.view',
        properties: {'folder': 'Uni', 'smartQuery': SmartViewQuery.empty()},
      );
      expect(resolveSmartView(view, rows).map((o) => o.id), ['a']);
      expect(
        resolveSmartView(
          view.copyWith(
            properties: {
              ...view.properties,
              'memberIds': ['b'],
            },
          ),
          rows,
        ).map((o) => o.id),
        ['b'],
      );
      final q = SmartViewQuery({
        ...SmartViewQuery.empty(),
        'sort': 'credits',
        'descending': true,
      });
      expect(
        q
            .evaluate([
              object('z'),
              object('a', properties: {'credits': 3}),
              object('b', properties: {'credits': 6}),
            ])
            .map((o) => o.id),
        ['b', 'a', 'z'],
      );
    },
  );
  test(
    'future queries, invalid dates, operators, columns and non-finite values fail closed',
    () {
      for (final q in [
        {...SmartViewQuery.empty(), 'version': 2},
        {
          ...SmartViewQuery.empty(),
          'rules': [
            {'field': 'dueDate', 'op': 'before', 'value': '2026-02-30'},
          ],
        },
        {
          ...SmartViewQuery.empty(),
          'rules': [
            {'field': 'priority', 'op': 'sql', 'value': 'DROP'},
          ],
        },
        {...SmartViewQuery.empty(), 'columns': []},
        {
          ...SmartViewQuery.empty(),
          'rules': [
            {'field': 'credits', 'op': 'gte', 'value': double.nan},
          ],
        },
      ]) {
        expect(() => SmartViewQuery(q), throwsFormatException);
      }
    },
  );
  test(
    'monthly anchor restores month end; yearly leap dates and civil DST dates are stable',
    () {
      final monthly = TaskRecurrence(rule('monthly', '2026-01-31'));
      expect(monthly.next('2026-01-31'), '2026-02-28');
      expect(monthly.next('2026-02-28'), '2026-03-31');
      expect(
        TaskRecurrence(rule('yearly', '2024-02-29')).next('2024-02-29'),
        '2025-02-28',
      );
      expect(
        TaskRecurrence(rule('daily', '2026-03-28')).next('2026-03-28'),
        '2026-03-29',
      );
      expect(
        TaskRecurrence(rule('weekly', '2026-10-24', 2)).next('2026-10-24'),
        '2026-11-07',
      );
      expect(
        () => TaskRecurrence(rule('daily', 'invalid')),
        throwsFormatException,
      );
    },
  );
  test(
    'recurring completion records exactly one occurrence and preserves unknown metadata/history',
    () {
      final t = object(
        'a',
        properties: {
          'recurrence': rule('daily', '2026-01-01'),
          'dueDate': '2026-01-01',
          'completed': false,
          'plugin:value': {'x': 1},
        },
      );
      final props = completeTaskOccurrence(t, {
        ...t.properties,
        'completed': true,
      }, DateTime.utc(2026, 1, 3));
      expect(props['dueDate'], '2026-01-02');
      expect(props['completed'], false);
      expect((props['occurrenceHistory'] as List).single, {
        'date': '2026-01-01',
        'completedAt': '2026-01-03T00:00:00.000Z',
      });
      expect(props['plugin:value'], {'x': 1});
      expect(t.properties.containsKey('occurrenceHistory'), false);
    },
  );
  test(
    'dependency and parent cycles, self-links and missing new edges are rejected',
    () {
      final a = object('a'), b = object('b', properties: {'blockedBy': 'a'});
      expect(
        () => validateTaskPlanning(
          a.copyWith(
            properties: {
              'blockedBy': ['b'],
            },
          ),
          [a, b],
          previous: a,
        ),
        throwsFormatException,
      );
      expect(
        () => validateTaskPlanning(
          a.copyWith(properties: {'parentTaskId': 'a'}),
          [a, b],
        ),
        throwsFormatException,
      );
      expect(
        () => validateTaskPlanning(
          a.copyWith(
            properties: {
              'blockedBy': ['missing'],
            },
          ),
          [a, b],
        ),
        throwsFormatException,
      );
      final imported = a.copyWith(
        properties: {
          'blockedBy': ['missing'],
        },
      );
      expect(
        () => validateTaskPlanning(imported.copyWith(title: 'Rename'), [
          imported,
          b,
        ], previous: imported),
        returnsNormally,
      );
    },
  );
  test(
    'context snapshots are independent and exclude content/global preferences',
    () {
      final source = {
        'tabs': ['a'],
        'noteViews': {
          'a': {'caret': 2},
        },
        'fontSize': 21,
        'body': 'private',
      };
      final context = WorkspaceContext.capture(source);
      ((source['noteViews'] as Map)['a'] as Map)['caret'] = 9;
      expect((context['noteViews'] as Map)['a'], {'caret': 2});
      expect(context.containsKey('body'), false);
      expect(context.containsKey('fontSize'), false);
      expect(
        WorkspaceContext.capture(source, layoutOnly: true).containsKey('tabs'),
        false,
      );
    },
  );
  test(
    'old settings default safely; future libraries and unknown widgets remain preserved',
    () {
      final s = SessionState.fromJson({
        'version': 1,
        'plugin': {'x': 2},
      });
      expect(s.spaces, isEmpty);
      expect(s.dashboard, isEmpty);
      expect(s.toJson()['plugin'], {'x': 2});
      final future = {'version': 2, 'items': [], 'unknown': 'keep'};
      expect(WorkspaceContext.supported(future), false);
      expect(
        SessionState.fromJson({'spaces': future}).toJson()['spaces'],
        future,
      );
      expect(
        () => DashboardDefinition.validate({
          'version': 1,
          'widgets': [
            {'id': 'x', 'kind': 'plugin.future', 'span': 1, 'extra': 'keep'},
          ],
        }),
        returnsNormally,
      );
      expect(
        () => DashboardDefinition.validate({
          'version': 1,
          'widgets': [
            {'id': 'x', 'kind': 'tasks', 'span': 4},
          ],
        }),
        throwsFormatException,
      );
    },
  );
}
