import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/workspace/note_folder_explorer.dart';
import 'package:orbit_note/features/workspace/orbit_explorer_row.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  testWidgets(
    'large Explorer keeps hidden items selectable and reaches the final lazy row',
    (t) async {
      late ProviderContainer container;
      late WorkspaceController c;
      await t.runAsync(() async {
        container = ProviderContainer(
          overrides: [
            repositoryProvider.overrideWithValue(
              WorkspaceRepository(
                store: FolderMemoryStore(),
                index: MemoryObjectIndex(),
              ),
            ),
          ],
        );
        c = container.read(workspaceProvider.notifier);
        await c.initialize();
      });
      addTearDown(() {
        c.cancelAllTimers();
        container.dispose();
      });
      c.objects = List.generate(
        1000,
        (i) => UniversalObject(
          id: 'item-$i',
          workspaceId: c.repository.workspaceId,
          typeId: 'orbit.note',
          title: 'Note ${i.toString().padLeft(4, '0')}',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
      c.session.noteSort = 'name-asc';
      final visible = List.of(c.objects);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                ref.watch(workspaceProvider);
                return Scaffold(
                  body: SizedBox(
                    width: 700,
                    child: NoteFolderExplorer(
                      controller: c,
                      notes: c.objects,
                      visibleObjects: visible,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(OrbitExplorerRow).evaluate().length, lessThan(100));
      await t.tap(find.text('Note 0000'));
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyA);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pumpAndSettle();
      expect(find.text('1000 items selected'), findsOneWidget);
      final list = t.widget<ListView>(
        find.descendant(
          of: find.byType(NoteFolderExplorer),
          matching: find.byType(ListView),
        ),
      );
      for (var i = 0; i < 8 && find.text('Note 0999').evaluate().isEmpty; i++) {
        list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
        await t.pumpAndSettle();
      }
      expect(find.text('Note 0999'), findsOneWidget);
      await t.tap(find.text('Note 0999'));
      await t.pumpAndSettle();
      expect(c.session.activeId, 'item-999');
      visible[999] = visible[999].copyWith(title: 'Renamed last');
      c.notify();
      await t.pumpAndSettle();
      expect(find.text('Renamed last'), findsOneWidget);
      c.updateSession((s) => s.noteSort = 'name-desc');
      await t.pumpAndSettle();
      list.controller!.jumpTo(0);
      await t.pumpAndSettle();
      expect(find.text('Renamed last'), findsOneWidget);
      c.cancelAllTimers();
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
  );
}
