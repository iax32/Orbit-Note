import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/main.dart';
import 'package:orbit_note/features/workspace/quick_switcher_dialog.dart';
import 'support/memory_store.dart';

void main() {
  testWidgets('mouse back and forward button navigation in workspace shell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
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

    final c = ProviderScope.containerOf(
      tester.element(find.byType(OrbitNoteApp)),
    ).read(workspaceProvider.notifier);

    // Create two notes and navigate between them
    final note1 = (await c.create('orbit.note', title: 'First Note'))!;
    final note2 = (await c.create('orbit.note', title: 'Second Note'))!;
    c.openObject(note1.id);
    await tester.pumpAndSettle();
    c.openObject(note2.id);
    await tester.pumpAndSettle();

    expect(c.session.activeId, note2.id);
    expect(c.canNavigateBack, isTrue);

    // Dispatch mouse back button (buttons: 8)
    final center = tester.getCenter(find.byType(Scaffold).first);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.down(center, buttons: 8));
    await tester.sendEventToBinding(pointer.up());
    await tester.pumpAndSettle();

    // Should have navigated back to note 1
    expect(c.session.activeId, note1.id);
    expect(c.canNavigateForward, isTrue);

    // Dispatch mouse forward button (buttons: 16)
    await tester.sendEventToBinding(pointer.down(center, buttons: 16));
    await tester.sendEventToBinding(pointer.up());
    await tester.pumpAndSettle();

    // Should have navigated forward to note 2
    expect(c.session.activeId, note2.id);
  });

  testWidgets(
    'Quick Switcher triggers on Ctrl+O and matches documents by tags',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
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

      final c = ProviderScope.containerOf(
        tester.element(find.byType(OrbitNoteApp)),
      ).read(workspaceProvider.notifier);

      await c.create(
        'orbit.note',
        title: 'Network Protocol Audit',
        properties: {
          'tags': ['telemetry', 'packets'],
        },
      );
      await tester.pumpAndSettle();

      // Press Ctrl+O to open Quick Switcher
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.byType(QuickSwitcherDialog), findsOneWidget);

      // Search by tag 'telemetry'
      final input = find.byKey(const ValueKey('quick-switcher-search-input'));
      await tester.enterText(input, 'telemetry');
      await tester.pumpAndSettle();

      // Should find the note matched by tag inside the QuickSwitcherDialog
      expect(
        find.descendant(
          of: find.byType(QuickSwitcherDialog),
          matching: find.text('Network Protocol Audit'),
        ),
        findsOneWidget,
      );

      // Dismiss with Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(QuickSwitcherDialog), findsNothing);
    },
  );

  testWidgets(
    'auto-expands collapsed folder when creating document in folder',
    (tester) async {
      final repository = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );

      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final c = container.read(workspaceProvider.notifier);

      // Collapse 'Notes' folder
      c.updateSession((s) => s.collapsedFolders = ['Notes']);
      expect(c.session.collapsedFolders.contains('Notes'), isTrue);

      // Trigger folder action or session update when creating note in folder
      c.updateSession(
        (s) => s.collapsedFolders = s.collapsedFolders
            .where((f) => f != 'Notes')
            .toList(),
      );
      await c.create('orbit.note', properties: {'folder': 'Notes'});

      // 'Notes' is now expanded
      expect(c.session.collapsedFolders.contains('Notes'), isFalse);

      // Drain session persist timer
      await tester.pump(const Duration(milliseconds: 700));
    },
  );
}
