import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/event_recurrence.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/workspace/event_repeat_dialog.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

Map<String, dynamic> rule({
  String frequency = 'weekly',
  int? count,
  String? until,
}) => {
  'version': 1,
  'frequency': frequency,
  'interval': 1,
  'anchorDate': '2026-01-31',
  'processed': 0,
  'paused': false,
  'overlap': 'earlier',
  'count': count,
  'until': until,
  'custom': 'preserve',
};
UniversalObject event(Map<String, dynamic> r, {bool timed = false}) =>
    UniversalObject(
      id: 'event',
      workspaceId: 'test',
      typeId: 'orbit.event',
      title: 'Lecture',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      properties: {
        'allDay': !timed,
        if (!timed) ...{'startDate': '2026-01-31', 'endDate': '2026-02-02'},
        if (timed) ...{
          'startAt': '2026-01-31T09:00:00.000Z',
          'endAt': '2026-01-31T10:30:00.000Z',
        },
        'eventRecurrence': r,
        'contextId': 'note',
        'custom': {'retained': true},
      },
    );
void main() {
  test('monthly clamp retains anchor and civil multi-day length', () {
    var e = event(rule(frequency: 'monthly'));
    final first = advanceEventOccurrence(e, 'completed', DateTime.utc(2026, 2));
    expect(first['startDate'], '2026-02-28');
    expect(first['endDate'], '2026-03-02');
    e = e.copyWith(properties: first);
    final second = advanceEventOccurrence(e, 'skipped', DateTime.utc(2026, 3));
    expect(second['startDate'], '2026-03-31');
    expect(second['contextId'], 'note');
    expect((second['eventOccurrenceHistory'] as List).length, 2);
    expect(
      (second['eventOccurrenceHistory'] as List).last['outcome'],
      'skipped',
    );
    expect((second['eventRecurrence'] as Map)['custom'], 'preserve');
  });
  test('count and inclusive until stop without discarding last occurrence', () {
    for (final r in [rule(count: 1), rule(until: '2026-02-01')]) {
      final p = advanceEventOccurrence(
        event(r),
        'completed',
        DateTime.utc(2026),
      );
      expect((p['eventRecurrence'] as Map)['finished'], true);
      expect(p['startDate'], '2026-01-31');
      expect(
        () => advanceEventOccurrence(
          event(r).copyWith(properties: p),
          'completed',
          DateTime.utc(2026),
        ),
        throwsFormatException,
      );
    }
  });
  test(
    'gap rejects advance and overlap policy chooses explicit UTC instant',
    () {
      final e = event(rule(), timed: true);
      expect(
        () => advanceEventOccurrence(
          e,
          'completed',
          DateTime.utc(2026),
          localize: (d) => d,
          resolveClock: (_) => [],
        ),
        throwsFormatException,
      );
      expect(e.properties['eventOccurrenceHistory'], isNull);
      final early = DateTime.utc(2026, 2, 7, 8),
          late = DateTime.utc(2026, 2, 7, 9);
      for (final policy in ['earlier', 'later']) {
        final p = advanceEventOccurrence(
          e.copyWith(
            properties: {
              ...e.properties,
              'eventRecurrence': {...rule(), 'overlap': policy},
            },
          ),
          'completed',
          DateTime.utc(2026),
          localize: (d) => d,
          resolveClock: (_) => [late, early],
        );
        final start = DateTime.parse(p['startAt'] as String);
        expect(start, policy == 'earlier' ? early : late);
        expect(
          DateTime.parse(p['endAt'] as String).difference(start),
          const Duration(minutes: 90),
        );
      }
    },
  );
  test(
    'paused, invalid rules, outcome and history refuse destructive updates',
    () {
      for (final r in [
        {...rule(), 'paused': true},
        {...rule(), 'version': 99},
        {...rule(), 'interval': 0},
      ]) {
        expect(
          () =>
              advanceEventOccurrence(event(r), 'completed', DateTime.utc(2026)),
          throwsFormatException,
        );
      }
      expect(
        () =>
            advanceEventOccurrence(event(rule()), 'bogus', DateTime.utc(2026)),
        throwsFormatException,
      );
      expect(
        () => advanceEventOccurrence(
          event(rule()).copyWith(
            properties: {
              ...event(rule()).properties,
              'eventOccurrenceHistory': 'future',
            },
          ),
          'completed',
          DateTime.utc(2026),
        ),
        throwsFormatException,
      );
    },
  );
  test('device clock resolver returns exact wall-clock matches', () {
    final local = DateTime(2026, 1, 15, 12, 34, 5, 6, 7);
    final candidates = deviceClockCandidates(local);
    expect(candidates, contains(local.toUtc()));
    for (final c in candidates) {
      expect(c.toLocal().hour, 12);
      expect(c.toLocal().microsecond, 7);
    }
  });
  group('recoverable event commands', () {
    late MemoryStore store;
    late ProviderContainer container;
    late WorkspaceController c;
    Future<void> open() async {
      container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(
            WorkspaceRepository(store: store, index: MemoryObjectIndex()),
          ),
        ],
      );
      container.read(workspaceProvider);
      c = container.read(workspaceProvider.notifier);
      while (c.loading) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
    }

    Future<UniversalObject> create() => c.repository.create(
      typeId: 'orbit.event',
      title: 'Lecture',
      properties: event(rule()).properties,
    );
    setUp(() async {
      store = MemoryStore();
      await open();
    });
    tearDown(() async {
      await c.closeWorkspace();
      container.dispose();
    });
    test(
      'same identity survives advance, guarded undo and empty-index restart',
      () async {
        final e = await create();
        c.mergeRepositoryObjects();
        expect(await c.recordEventOccurrence(e, 'completed'), true);
        expect(c.find(e.id)!.properties['startDate'], '2026-02-07');
        expect(await c.undoPlanning(), true);
        expect(c.find(e.id)!.properties['startDate'], '2026-01-31');
        expect(await c.recordEventOccurrence(c.find(e.id)!, 'skipped'), true);
        await c.closeWorkspace();
        container.dispose();
        await open();
        expect(c.find(e.id)!.properties['startDate'], '2026-02-07');
        expect(
          (c.find(e.id)!.properties['eventOccurrenceHistory'] as List)
              .single['outcome'],
          'skipped',
        );
      },
    );
    test('failed writes and stale actions preserve dates/history', () async {
      final e = await create();
      c.mergeRepositoryObjects();
      store.failWrites = true;
      expect(await c.recordEventOccurrence(e, 'completed'), false);
      expect(c.find(e.id)!.properties['eventOccurrenceHistory'], isNull);
      store.failWrites = false;
      expect(
        await c.configureEventRepeat(e, {...rule(), 'paused': true}),
        true,
      );
      expect(await c.recordEventOccurrence(e, 'completed'), false);
      expect(c.find(e.id)!.properties['startDate'], '2026-01-31');
    });
    testWidgets('repeat editor supports narrow enlarged text and preview', (
      tester,
    ) async {
      final e = (await tester.runAsync(create))!;
      c.mergeRepositoryObjects();
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(
              ctx,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => showEventRepeatDialog(ctx, c, e),
                child: const Text('Repeat'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Repeat'));
      await tester.pumpAndSettle();
      expect(find.text('Event repeat & history'), findsOneWidget);
      expect(find.textContaining('Upcoming starts'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Close'));
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });
  });
}
