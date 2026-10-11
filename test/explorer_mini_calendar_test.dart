import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/main.dart';
import 'package:orbit_note/features/workspace/explorer_mini_calendar.dart';
import 'support/memory_store.dart';

void main() {
  testWidgets(
    'Explorer mini calendar renders and interacts smoothly in Explorer view',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repository)],
          child: const OrbitNoteApp(),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OrbitNoteApp)),
      );
      final c = container.read(workspaceProvider.notifier);

      // 1. Verify calendar widget exists and displays current month
      expect(
        find.byKey(const ValueKey('explorer-mini-calendar')),
        findsOneWidget,
      );

      final now = DateTime.now();
      const monthNames = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      final currentMonthTitle = '${monthNames[now.month - 1]} ${now.year}';
      expect(find.text('${now.day} $currentMonthTitle'), findsOneWidget);

      // Fresh workspaces start compact; expand before navigating dates.
      expect(c.session.explorerCalendarCollapsed, isTrue);
      await tester.tap(find.byKey(const ValueKey('mini-cal-collapse')));
      await tester.pumpAndSettle();
      // 2. Navigation: next month
      expect(find.text(currentMonthTitle), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mini-cal-next')));
      await tester.pumpAndSettle();

      final nextMonthDate = DateTime(now.year, now.month + 1);
      final nextMonthTitle =
          '${monthNames[nextMonthDate.month - 1]} ${nextMonthDate.year}';
      expect(find.text(nextMonthTitle), findsOneWidget);

      // 3. Jump to today
      await tester.tap(find.byKey(const ValueKey('mini-cal-today')));
      await tester.pumpAndSettle();
      expect(find.text(currentMonthTitle), findsOneWidget);

      // 4. Collapse and expand toggle
      expect(find.text('M'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('mini-cal-collapse')));
      await tester.pumpAndSettle();
      expect(c.session.explorerCalendarCollapsed, isTrue);

      await tester.tap(find.byKey(const ValueKey('mini-cal-collapse')));
      await tester.pumpAndSettle();
      expect(c.session.explorerCalendarCollapsed, isFalse);

      // 5. Tap today cell to create and open daily note
      final todaySlug =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final cellKey = 'mini-cal-day-$todaySlug';

      expect(c.activeObjects.where((o) => o.title == todaySlug), isEmpty);

      await tester.tap(find.byKey(ValueKey(cellKey)));
      await tester.pumpAndSettle();

      final dailyNotes = c.activeObjects
          .where((o) => o.title == todaySlug)
          .toList();
      expect(dailyNotes.length, 1);
      expect(dailyNotes.first.properties['dailyDate'], todaySlug);
      expect(c.session.activeId, dailyNotes.first.id);

      // Tap same cell again -> doesn't duplicate
      await tester.tap(find.byKey(ValueKey(cellKey)));
      await tester.pumpAndSettle();
      expect(c.activeObjects.where((o) => o.title == todaySlug).length, 1);

      // 6. Create an event and verify it is integrated
      await c.create(
        'orbit.event',
        title: 'Team Sync',
        properties: {
          'allDay': true,
          'start': '${todaySlug}T09:00:00Z',
          'end': '${todaySlug}T10:00:00Z',
        },
      );
      await tester.pumpAndSettle();
      expect(
        c.activeObjects.any(
          (o) => o.typeId == 'orbit.event' && o.title == 'Team Sync',
        ),
        isTrue,
      );

      // 7. Tap another day cell (day 1 of current month)
      final day1 = DateTime(now.year, now.month, 1);
      final day1Slug =
          '${day1.year.toString().padLeft(4, '0')}-${day1.month.toString().padLeft(2, '0')}-01';
      await tester.tap(find.byKey(ValueKey('mini-cal-day-$day1Slug')));
      await tester.pumpAndSettle();

      expect(c.activeObjects.any((o) => o.title == day1Slug), isTrue);
      expect(c.session.activeId, isNotNull);

      // Enlarged text must fit the day cells, including activity indicators.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: ExplorerMiniCalendar(controller: c),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
