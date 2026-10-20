import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/features/workspace/note_folder_explorer.dart';
import 'package:orbit_note/features/workspace/orbit_explorer_row.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

class ExplorerVaultStore extends FolderMemoryStore {
  String selected = 'first';
  final vaults = <String, Map<String, Uint8List>>{};
  @override
  Future<void> initialize({String? path}) async {
    vaults[selected] = Map.of(files);
    selected = path ?? selected;
    files
      ..clear()
      ..addAll(vaults[selected] ?? {});
  }
}

void main() {
  for (final scenario in [
    'partial',
    'other-vault',
    'disposed',
    'changed-selection',
  ]) {
    testWidgets('bulk Trash confirmation: $scenario', (tester) async {
      tester.view.physicalSize = const Size(1000, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = WorkspaceRepository(
        store: ExplorerVaultStore(),
        index: MemoryObjectIndex(),
      );
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      final visible = ValueNotifier(true);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  ref.watch(workspaceProvider);
                  final c = ref.read(workspaceProvider.notifier);
                  return ValueListenableBuilder(
                    valueListenable: visible,
                    builder: (context, show, _) => show
                        ? NoteFolderExplorer(
                            controller: c,
                            notes: c.activeObjects.toList(),
                          )
                        : const Text('Closed explorer'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final c = container.read(workspaceProvider.notifier);
      c.pausePdfIndex(true);
      c.cancelAllTimers();
      final a = (await c.create('orbit.note', title: 'Note A'))!;
      final b = (await c.create('orbit.canvas', title: 'Board B'))!;
      final third = (await c.create('orbit.note', title: 'Note C'))!;
      await tester.pumpAndSettle();
      final aRow = find.byKey(ValueKey('folder-note:${a.id}'));
      final bRow = find.byKey(ValueKey('folder-item:${b.id}'));
      final cRow = tester.widget<OrbitExplorerRow>(
        find.byKey(ValueKey('folder-note:${third.id}')),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(aRow);
      await tester.tap(bRow);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('2 items selected'), findsOneWidget);
      await tester.tap(find.byTooltip('Move to Trash'));
      await tester.pumpAndSettle();
      expect(find.text('Move 2 items to Trash?'), findsOneWidget);
      if (scenario == 'partial') {
        c.edit(b.id, title: 'Changed after review');
        await c.flush(b.id);
      } else if (scenario == 'other-vault') {
        c.cancelAllTimers();
        await repo.initialize(path: 'second');
        c.mergeRepositoryObjects();
        c.notify();
      } else if (scenario == 'disposed') {
        visible.value = false;
      } else {
        cRow.onTap();
      }
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Move to Trash'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (scenario == 'other-vault') {
        await repo.initialize(path: 'first');
        c.mergeRepositoryObjects();
        c.notify();
      }
      if (scenario == 'partial') {
        expect(c.find(a.id)!.isDeleted, isTrue);
        expect(c.find(b.id)!.isDeleted, isFalse);
        expect(find.textContaining('Moved 1 of 2 items'), findsOneWidget);
        expect(tester.widget<OrbitExplorerRow>(bRow).multiSelected, isTrue);
      } else if (scenario == 'changed-selection') {
        expect(c.find(a.id)!.isDeleted, isTrue);
        expect(c.find(b.id)!.isDeleted, isTrue);
        expect(c.find(third.id)!.isDeleted, isFalse);
        expect(
          tester
              .widget<OrbitExplorerRow>(
                find.byKey(ValueKey('folder-note:${third.id}')),
              )
              .multiSelected,
          isTrue,
        );
      } else {
        expect(c.find(a.id)!.isDeleted, isFalse);
        expect(c.find(b.id)!.isDeleted, isFalse);
      }
      c.cancelAllTimers();
      await c.flushAll();
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      visible.dispose();
    });
  }
}
