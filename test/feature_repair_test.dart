import 'package:flutter/material.dart';
import 'package:orbit_note/app/orbit_components.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/calendar_event.dart';
import 'package:orbit_note/features/workspace/calendar_view.dart';
import 'package:orbit_note/features/workspace/workspace_views.dart';
import 'package:orbit_note/features/notes/rich/equation_editor.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  test('month grids use distinct civil midnights across clock changes', () {
    for (final month in [DateTime(2026, 3), DateTime(2026, 10)]) {
      final days = calendarMonthDays(month);
      expect(days.map(calendarDate).toSet(), hasLength(42));
      expect(days.every((d) => d.hour == 0), isTrue);
      expect(days.first.weekday, DateTime.monday);
    }
  });
  test(
    'local event time conversion and unchanged precise instants are preserved',
    () {
      final date = DateTime(2026, 9, 10);
      expect(
        eventLocalInstant(date, 9, 30),
        DateTime(2026, 9, 10, 9, 30).toUtc(),
      );
      final original = DateTime(2026, 9, 10, 9, 30, 42, 123).toUtc();
      expect(eventLocalInstant(date, 9, 30, original: original), original);
    },
  );
  testWidgets('symbol selection targets the active visual fraction slot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EquationEditor(source: r'\frac{1}{2}', display: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('visual-denominator-0')));
    await tester.enterText(find.byKey(const ValueKey('latex-search')), 'alpha');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'alpha').first);
    await tester.pumpAndSettle();
    final source = tester
        .widget<TextField>(find.byKey(const ValueKey('equation-source')))
        .controller!
        .text;
    expect(source, r'\frac{1}{\alpha }');
  });
  testWidgets(
    'event dialog persists once, keeps unknown fields and reports failed saves',
    (tester) async {
      final store = MemoryStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      container.read(workspaceProvider);
      final controller = container.read(workspaceProvider.notifier);
      await tester.runAsync(() async {
        while (controller.loading) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
      });
      final date = DateTime(2026, 9, 10, 9);
      final properties = <String, dynamic>{
        'allDay': false,
        'startAt': date.toUtc().toIso8601String(),
        'endAt': date.add(const Duration(hours: 1)).toUtc().toIso8601String(),
        'custom': {'keep': true},
        'contextId': 'missing-context',
      };
      final event = await tester.runAsync(
        () => controller.saveEvent(
          title: 'Lecture',
          body: 'Context',
          properties: properties,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventDetail(object: event!, controller: controller),
          ),
        ),
      );
      await tester.tap(find.text('Edit dates'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      store.failWrites = true;
      await tester.enterText(
        find
            .descendant(
              of: find.byType(OrbitDialog),
              matching: find.byType(TextField),
            )
            .first,
        'Renamed',
      );
      await tester.tap(find.text('Save'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('event-save-error')), findsOneWidget);
      expect(controller.find(event.id)!.title, 'Lecture');
      store.failWrites = false;
      await tester.tap(find.text('Save'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      final saved = controller.find(event.id)!;
      expect(saved.title, 'Renamed');
      expect(saved.properties, {
        ...properties,
        'aliases': ['Lecture'],
      });
      await tester.runAsync(() async {
        await repo.refresh();
      });
      expect(repo.objects.single.properties, saved.properties);
      await tester.pump(const Duration(milliseconds: 400));
      final context = tester.element(find.byType(EventDetail));
      final invalid = saved.copyWith(
        properties: {...saved.properties, 'startAt': '2026-02-30T09:00:00Z'},
      );
      final dialog = showEventDialog(context, controller, event: invalid);
      await tester.pumpAndSettle();
      expect(find.text('Event dates need review'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      expect(controller.find(saved.id)!.properties, saved.properties);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await dialog;
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
}
