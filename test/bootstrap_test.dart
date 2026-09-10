import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/main.dart';
import 'support/memory_store.dart';

void main() {
  testWidgets('Orbit Note starts without account or service setup', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
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
    expect(find.text('Room for your next idea.'), findsOneWidget);
    await tester.tap(find.text('New note'));
    await tester.pumpAndSettle();
    expect(repository.objects.single.typeId, 'orbit.note');
    expect(tester.takeException(), isNull);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OrbitNoteApp)),
    );
    final c = container.read(workspaceProvider.notifier);
    c.edit(repository.objects.single.id, body: 'A real local note');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(repository.objects.single.body, 'A real local note');
    c.navigate(OrbitDestination.tasks);
    await tester.pumpAndSettle();
    expect(find.text('Add a task and press Enter'), findsOneWidget);
    c.navigate(OrbitDestination.home);
    tester.view.physicalSize = const Size(390, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await c.flushAll();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
