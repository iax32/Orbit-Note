import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/explorer_group.dart';
import 'package:orbit_note/features/workspace/note_folder_explorer.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  testWidgets(
    'loose files group by type, nested files stay put, filters and right-click use the actual folder',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = FolderMemoryStore();
      store.folderList.addAll(['Notes/Course', 'Notes/Course/Week 1']);
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      final c = container.read(workspaceProvider.notifier);
      await c.initialize();
      c.cancelAllTimers();
      c.pausePdfIndex(true);
      addTearDown(container.dispose);
      final pdf = await repo.importAttachment(
        name: 'Lecture.PDF',
        bytes: Uint8List.fromList([1]),
      );
      final image = await repo.importAttachment(
        name: 'diagram.png',
        bytes: Uint8List.fromList([2]),
      );
      final code = await repo.importAttachment(
        name: 'main.cpp',
        bytes: Uint8List.fromList([3]),
      );
      final model = await repo.importAttachment(
        name: 'chair.glb',
        bytes: Uint8List.fromList([4]),
      );
      final nested = await repo.importAttachment(
        name: 'Nested.pdf',
        bytes: Uint8List.fromList([5]),
        folder: 'Notes/Course/Week 1',
      );
      final alpha = await repo.importAttachment(
        name: 'Alpha.pdf',
        bytes: Uint8List.fromList([6]),
      );
      c.session.noteSort = 'name-asc';
      c.mergeRepositoryObjects();
      String? destination;
      bool? pdfOnly;
      Future<void> show(List<String>? ids) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
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
                          notes: c.activeObjects,
                          visibleObjects: c.activeObjects
                              .where((o) => ids == null || ids.contains(o.id))
                              .toList(),
                          groupLooseItems: true,
                          onImportFiles: (folder, onlyPdf) async {
                            destination = folder;
                            pdfOnly = onlyPdf;
                          },
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
      }

      await show(null);
      for (final group in ['pdfs', 'images', 'code', 'models']) {
        expect(find.byKey(ValueKey('loose-group:$group')), findsOneWidget);
      }
      expect(
        find.text('PDFs · 2'),
        findsOneWidget,
      ); // Nested PDF is not flattened.
      for (final item in [pdf, image, code, model, nested]) {
        expect(find.byKey(ValueKey('folder-item:${item.id}')), findsOneWidget);
      }
      expect(
        tester.getTopLeft(find.byKey(ValueKey('folder-item:${alpha.id}'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(ValueKey('folder-item:${pdf.id}'))).dy,
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('folder:Notes/Course/Week 1')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('folder-item:${nested.id}')), findsNothing);
      expect(find.byKey(ValueKey('folder-item:${pdf.id}')), findsOneWidget);
      final folder = find.byKey(const ValueKey('folder:Notes/Course/Week 1'));
      await tester.tap(folder, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import PDFs here…'));
      await tester.pumpAndSettle();
      expect(destination, 'Notes/Course/Week 1');
      expect(pdfOnly, isTrue);
      await tester.tap(folder, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import files here…'));
      await tester.pumpAndSettle();
      expect(destination, 'Notes/Course/Week 1');
      expect(pdfOnly, isFalse);
      await show([nested.id]);
      expect(find.byKey(ValueKey('folder-item:${nested.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('folder-item:${pdf.id}')), findsNothing);
      expect(find.byKey(const ValueKey('loose-group:pdfs')), findsNothing);
      expect(
        explorerGroup(pdf.copyWith(title: 'Renamed without extension')),
        ExplorerGroup.pdfs,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
