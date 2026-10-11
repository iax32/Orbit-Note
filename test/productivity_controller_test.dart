import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/domain/smart_view_query.dart';
import 'support/memory_store.dart';

void main() {
  late MemoryStore store;
  late WorkspaceRepository repo;
  late ProviderContainer container;
  late WorkspaceController c;
  Future<void> open() async {
    repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    container.read(workspaceProvider);
    c = container.read(workspaceProvider.notifier);
    for (var i = 0; i < 200 && c.loading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    expect(c.hasWorkspace, true);
  }

  setUp(() async {
    store = MemoryStore();
    await open();
  });
  tearDown(() async {
    await c.closeWorkspace();
    container.dispose();
  });

  test(
    'failed durable query writes retain the old definition and can retry',
    () async {
      final view = (await c.create(
        'orbit.view',
        title: 'Reliable',
        properties: {'smartQuery': SmartViewQuery.empty()},
      ))!;
      final before = {...store.files};
      store.failWrites = true;
      expect(
        await c.saveSmartQuery(view, {
          ...SmartViewQuery.empty(),
          'sort': 'title',
        }),
        false,
      );
      expect(c.find(view.id)!.properties['smartQuery'], SmartViewQuery.empty());
      expect(store.files, before);
      store.failWrites = false;
      expect(
        await c.saveSmartQuery(c.find(view.id)!, {
          ...SmartViewQuery.empty(),
          'sort': 'title',
        }),
        true,
      );
    },
  );

  test(
    'flush waits for durable planning; concurrent commands cannot duplicate a recurrence',
    () async {
      final task = (await c.create(
        'orbit.task',
        title: 'Repeat',
        properties: {
          'dueDate': '2026-10-08',
          'recurrence': {
            'version': 1,
            'frequency': 'daily',
            'interval': 1,
            'anchorDate': '2026-10-08',
          },
        },
      ))!;
      final gate = Completer<void>();
      store.writeGate = gate.future;
      final completion = c.completePlannedTask(task);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(await c.completePlannedTask(task), false);
      var flushed = false;
      final flush = c.flushAll().then((result) {
        flushed = true;
        return result;
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(flushed, false);
      gate.complete();
      store.writeGate = null;
      expect(await completion, true);
      expect(await flush, true);
      expect(
        (c.find(task.id)!.properties['occurrenceHistory'] as List).length,
        1,
      );
    },
  );

  test(
    'invalid runtime values release the command lock; recurrence works through status edits',
    () async {
      final task = (await c.create(
        'orbit.task',
        title: 'Repeat',
        properties: {
          'dueDate': '2026-10-08',
          'recurrence': {
            'version': 1,
            'frequency': 'daily',
            'interval': 1,
            'anchorDate': '2026-10-08',
          },
        },
      ))!;
      expect(await c.configureTask(task, {'custom': double.nan}), false);
      expect(await c.configureTask(c.find(task.id)!, {'status': 'done'}), true);
      expect(c.find(task.id)!.properties['dueDate'], '2026-10-09');
      expect(c.find(task.id)!.isCompleted, false);
      expect(await c.undoPlanning(), true);
      expect(c.find(task.id)!.properties['dueDate'], '2026-10-08');
    },
  );

  test(
    'saved query drives canonical results, survives reopen and preserves source/unknown fields',
    () async {
      final note = (await c.create(
        'orbit.note',
        title: 'Course note',
        body: '# Original\n',
        properties: {
          'project': 'Math',
          'tags': ['exam'],
        },
      ))!;
      final view = (await c.create(
        'orbit.view',
        title: 'Exam sources',
        properties: {'smartQuery': SmartViewQuery.empty(), 'plugin': 'keep'},
      ))!;
      final q = {
        ...SmartViewQuery.empty(),
        'rules': [
          {'field': 'tags', 'op': 'contains', 'value': 'exam'},
        ],
        'extra': {'x': 2},
      };
      expect(await c.saveSmartQuery(view, q), true);
      expect(c.queryViewObjects(c.find(view.id)!).map((o) => o.id), [note.id]);
      c.edit(
        note.id,
        properties: {
          ...note.properties,
          'tags': ['other'],
        },
      );
      expect(c.queryViewObjects(c.find(view.id)!), isEmpty);
      await c.flushAll();
      await c.closeWorkspace();
      container.dispose();
      await open();
      expect(c.find(note.id)!.body, '# Original\n');
      expect(c.find(view.id)!.properties['plugin'], 'keep');
      expect((c.find(view.id)!.properties['smartQuery'] as Map)['extra'], {
        'x': 2,
      });
      expect(c.queryViewObjects(c.find(view.id)!), isEmpty);
    },
  );
  test(
    'query save rejects stale and future definitions without changing bytes',
    () async {
      final v = (await c.create(
        'orbit.view',
        properties: {'smartQuery': SmartViewQuery.empty()},
      ))!;
      c.edit(v.id, title: 'Later title');
      expect(await c.saveSmartQuery(v, SmartViewQuery.empty()), false);
      await c.flushAll();
      final latest = c.find(v.id)!;
      expect(
        await c.saveSmartQuery(latest, {
          ...SmartViewQuery.empty(),
          'version': 2,
        }),
        false,
      );
      expect((c.find(v.id)!.properties['smartQuery'] as Map)['version'], 1);
    },
  );
  test(
    'recurrence completion from any view is durable, single-identity, undoable and history survives restart',
    () async {
      final task = (await c.create(
        'orbit.task',
        title: 'Review',
        properties: {
          'dueDate': '2026-01-31',
          'recurrence': {
            'version': 1,
            'frequency': 'monthly',
            'interval': 1,
            'anchorDate': '2026-01-31',
          },
          'plugin': 'keep',
        },
      ))!;
      c.edit(task.id, properties: {...task.properties, 'completed': true});
      await c.flushAll();
      expect(c.find(task.id)!.properties['dueDate'], '2026-02-28');
      expect(c.find(task.id)!.isCompleted, false);
      expect(c.ofType('orbit.task').length, 1);
      expect(
        (c.find(task.id)!.properties['occurrenceHistory'] as List).length,
        1,
      );
      expect(await c.undoPlanning(), true);
      expect(
        c.find(task.id)!.properties.containsKey('occurrenceHistory'),
        false,
      );
      expect(c.find(task.id)!.properties['dueDate'], '2026-01-31');
      expect(await c.completePlannedTask(c.find(task.id)!), true);
      await c.closeWorkspace();
      container.dispose();
      await open();
      expect(
        (c.find(task.id)!.properties['occurrenceHistory'] as List).length,
        1,
      );
      expect(c.find(task.id)!.properties['plugin'], 'keep');
    },
  );
  test(
    'dependencies reject cycles, preserve later edits and subtasks keep real parent IDs',
    () async {
      final a = (await c.create('orbit.task', title: 'A'))!;
      final b = (await c.create('orbit.task', title: 'B'))!;
      expect(
        await c.configureTask(a, {
          'blockedBy': [b.id],
        }),
        true,
      );
      expect(
        await c.configureTask(b, {
          'blockedBy': [a.id],
        }),
        false,
      );
      final child = (await c.create(
        'orbit.task',
        title: 'Child',
        properties: {'parentTaskId': a.id},
      ))!;
      expect(
        await c.configureTask(c.find(a.id)!, {'parentTaskId': child.id}),
        false,
      );
      c.edit(a.id, body: 'Later user edit');
      await c.flush(a.id);
      expect(await c.undoPlanning(), false);
      expect(c.find(a.id)!.body, 'Later user edit');
    },
  );
  test(
    'task schedule and deadline stay separate; all-day and timed duration/subseconds survive moves and undo',
    () async {
      final t = (await c.create(
        'orbit.task',
        properties: {'dueDate': '2026-10-15', 'scheduledDate': '2026-10-08'},
      ))!;
      expect(await c.rescheduleObject(t, DateTime(2026, 10, 10)), true);
      expect(c.find(t.id)!.properties['dueDate'], '2026-10-15');
      expect(c.find(t.id)!.properties['scheduledDate'], '2026-10-10');
      expect(await c.undoPlanning(), true);
      expect(c.find(t.id)!.properties['scheduledDate'], '2026-10-08');
      final e = (await c.create(
        'orbit.event',
        properties: {
          'allDay': true,
          'startDate': '2026-10-08',
          'endDate': '2026-10-11',
        },
      ))!;
      expect(await c.rescheduleObject(e, DateTime(2026, 10, 20)), true);
      expect(c.find(e.id)!.properties['endDate'], '2026-10-23');
      final timed = (await c.create(
        'orbit.event',
        properties: {
          'allDay': false,
          'startAt': '2026-10-08T10:00:12.123456Z',
          'endAt': '2026-10-08T11:30:12.123456Z',
        },
      ))!;
      expect(await c.rescheduleObject(timed, DateTime(2026, 10, 9)), true);
      final p = c.find(timed.id)!.properties;
      expect(
        DateTime.parse(
          p['endAt'] as String,
        ).difference(DateTime.parse(p['startAt'] as String)),
        const Duration(minutes: 90),
      );
      expect(DateTime.parse(p['startAt'] as String).microsecond, 456);
    },
  );
  test(
    'Spaces restore independent tab/split/position/dashboard contexts and scoped search after restart',
    () async {
      final a = (await c.create(
        'orbit.note',
        title: 'Math needle',
        properties: {'project': 'Math'},
      ))!;
      final b = (await c.create(
        'orbit.note',
        title: 'Game needle',
        properties: {'project': 'Game'},
      ))!;
      c.openObject(a.id);
      c.updateSession((s) {
        s.secondaryId = b.id;
        s.positions = {a.id: 42};
        s.dashboard = {
          'version': 1,
          'widgets': [
            {'id': 't', 'kind': 'tasks', 'span': 2},
          ],
        };
      });
      expect(await c.saveContext(name: 'University', project: 'Math'), true);
      final uni = c.savedContexts.single['id'] as String;
      c.openObject(b.id);
      c.updateSession((s) {
        s.secondaryId = null;
        s.positions = {b.id: 90};
        s.dashboard = {'version': 1, 'widgets': []};
      });
      expect(await c.saveContext(name: 'Development', project: 'Game'), true);
      final dev = c.savedContexts.last['id'] as String;
      expect(await c.switchContext(uni), true);
      expect(c.session.activeId, a.id);
      expect(c.session.secondaryId, b.id);
      expect(c.session.positions[a.id], 42);
      expect(
        (await c.searchLocations('needle')).map((r) => r.object.id).toSet(),
        {a.id},
      );
      c.updateSession((s) => s.positions = {a.id: 72});
      expect(await c.switchContext(dev), true);
      expect(c.session.positions[b.id], 90);
      expect(await c.switchContext(uni), true);
      expect(c.session.positions[a.id], 72);
      await c.closeWorkspace();
      container.dispose();
      await open();
      expect(c.activeSpaceId, uni);
      expect(c.savedContexts.length, 2);
      expect(c.ofType('orbit.note').length, 2);
      expect(await c.removeContext(uni), true);
      expect(c.find(a.id), isNotNull);
      expect(c.activeSpaceId, isNull);
    },
  );
  test(
    'layouts preserve tabs; duplicate/rename/remove preserves unknown context data and reset retains knowledge',
    () async {
      final n = (await c.create('orbit.note', title: 'Original'))!;
      c.updateSession((s) {
        s.sidebarWidth = 340;
        s.sidebarVisible = false;
      });
      expect(await c.saveContext(name: 'Quiet', layoutOnly: true), true);
      final id = c.savedContexts.single['id'] as String;
      final newer = (await c.create('orbit.note', title: 'Newer'))!;
      c.updateSession((s) => s.sidebarWidth = 220);
      expect(await c.switchContext(id), true);
      expect(c.session.activeId, newer.id);
      expect(c.session.sidebarWidth, 340);
      expect(await c.duplicateContext(id), true);
      expect(c.savedContexts.length, 2);
      expect(await c.renameContext(id, 'Writing'), true);
      c.updateSession(
        (s) => s.spaces = {...s.spaces, 'version': 2, 'unknown': 'keep'},
      );
      expect(await c.saveContext(name: 'Refused'), false);
      c.resetLayout();
      expect(c.session.sidebarVisible, true);
      expect(c.session.spaces['unknown'], 'keep');
      expect(c.find(n.id), isNotNull);
    },
  );
  test(
    'future dashboard definitions stay preserved; invalid widgets do not replace working dashboard',
    () async {
      final valid = {
        'version': 1,
        'widgets': [
          {'id': 'x', 'kind': 'plugin.unknown', 'span': 1, 'unknown': 'keep'},
        ],
      };
      expect(await c.saveDashboard(valid), true);
      expect(
        await c.saveDashboard({
          'version': 1,
          'widgets': [
            {'id': 'x', 'kind': 'tasks', 'span': 7},
          ],
        }),
        false,
      );
      expect(c.session.dashboard, valid);
      c.updateSession((s) => s.dashboard = {...s.dashboard, 'version': 2});
      expect(await c.saveDashboard(valid), false);
      expect(c.session.dashboard['version'], 2);
    },
  );
}
