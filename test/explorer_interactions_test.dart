import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/object_reference.dart';
import 'package:orbit_note/features/workspace/note_folder_explorer.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';
import 'support/capture_ui.dart';

void main() {
  testWidgets(
    'explorer right-click, stable reference, split and keyboard collapse work',
    (tester) async {
      await prepareCapture(tester);
      var clipboard = '';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      container.read(workspaceProvider);
      final c = container.read(workspaceProvider.notifier);
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && c.loading; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: orbitDarkTheme(),
            home: Consumer(
              builder: (context, ref, _) {
                ref.watch(workspaceProvider);
                return Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 320,
                      child: NoteFolderExplorer(
                        controller: c,
                        notes: c.ofType('orbit.note'),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final note = (await c.create('orbit.note'))!;
      c.edit(
        note.id,
        title: 'Research journal',
        body: 'Keep these exact bytes.',
      );
      await c.flushAll();
      await tester.pumpAndSettle();
      final row = find.byKey(ValueKey('folder-note:${note.id}'));
      await tester.tap(row, buttons: 2);
      await tester.pumpAndSettle();
      expect(find.text('Copy note reference'), findsOneWidget);
      await captureUi(tester, 'explorer-context');
      await tester.tap(find.text('Copy note reference'));
      await tester.pumpAndSettle();
      expect(clipboard, ObjectReference(note.id).markdown('Research journal'));
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open beside'));
      await tester.pumpAndSettle();
      expect(c.session.secondaryId, note.id);
      final folder = find.byKey(const ValueKey('folder:Notes'));
      await tester.tap(folder);
      await tester.pumpAndSettle();
      expect(row, findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(row, findsNothing);
      await c.flushAll();
      await tester.runAsync(() => c.initialize());
      expect(c.session.collapsedFolders, contains('Notes'));
      expect(c.find(note.id)!.body, 'Keep these exact bytes.');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
