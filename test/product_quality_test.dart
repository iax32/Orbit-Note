import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_components.dart';
import 'package:orbit_note/app/orbit_app.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/features/workspace/command_palette.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  testWidgets(
    'mode selection keeps geometry and supports keyboard activation',
    (tester) async {
      var selected = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Align(
                alignment: Alignment.topLeft,
                child: OrbitControl(
                  label: 'Read',
                  selected: selected,
                  onPressed: () => setState(() => selected = !selected),
                ),
              ),
            ),
          ),
        ),
      );
      final before = tester.getSize(find.byType(OrbitControl));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, isTrue);
      expect(tester.getSize(find.byType(OrbitControl)), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'palette arrows open selected recent item and search resets selection',
    (tester) async {
      final repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final c = container.read(workspaceProvider.notifier);
      await c.initialize();
      final first = (await c.create('orbit.note', title: 'First reading'))!;
      final second = (await c.create('orbit.note', title: 'Second reading'))!;
      await c.create('orbit.canvas', title: 'Reading board');
      c.updateSession((s) => s.recent = [first.id, second.id]);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: orbitDarkTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showCommandPalette(context, c),
                  child: const Text('Open palette'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open palette'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Second reading'))
            .selected,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(c.session.activeId, second.id);
      expect(find.byType(CommandPalette), findsNothing);
      await tester.tap(find.text('Open palette'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 12; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      }
      await tester.tap(find.byTooltip('Filter palette by type'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();
      expect(find.text('Reading board'), findsNothing);
      expect(find.text('New note'), findsNothing);
      expect(find.text('First reading'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'First reading');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(c.session.activeId, first.id);
      expect(tester.takeException(), isNull);
      await c.flushAll();
    },
  );

  testWidgets('palette remains scrollable at narrow width and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = WorkspaceRepository(
      store: MemoryStore(),
      index: MemoryObjectIndex(),
    );
    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final c = container.read(workspaceProvider.notifier);
    await c.initialize();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: orbitDarkTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(body: CommandPalette(controller: c)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 40; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    expect(find.text('Reload from files').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(1366, 768),
    const Size(1920, 1080),
    const Size(2560, 1440),
    const Size(3840, 2160),
  ]) {
    testWidgets('workspace layouts at $size and 100–200% display scaling', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final c = container.read(workspaceProvider.notifier);
      await c.initialize();
      c.updateSession((s) {
        s.motion = 'off';
        s.spellCheckEnabled = false;
      });
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const OrbitNoteApp(),
        ),
      );
      await tester.pumpAndSettle();
      for (final scale in [1.0, 1.25, 1.5, 2.0]) {
        tester.view.devicePixelRatio = scale;
        for (final destination in [
          OrbitDestination.home,
          OrbitDestination.tasks,
          OrbitDestination.calendar,
          OrbitDestination.settings,
          OrbitDestination.graph,
        ]) {
          c.navigate(destination);
          // Continuous decorative animations need not settle to check layout.
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            tester.takeException(),
            isNull,
            reason: '$size at $scale, $destination',
          );
        }
      }
      await c.flushAll();
    });
  }
}
