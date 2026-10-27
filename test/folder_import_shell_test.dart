import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/main.dart';
import 'support/memory_store.dart';

void main() {
  testWidgets(
    'folder menu imports multiple picked files into that folder in All items',
    (t) async {
      t.view.physicalSize = const Size(1450, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final directory = (await t.runAsync(() async {
        final directory = await Directory.systemTemp.createTemp(
          'orbit-folder-picker-',
        );
        await File(
          '${directory.path}/example.txt',
        ).writeAsString('Plain source');
        await File(
          '${directory.path}/lecture.pdf',
        ).writeAsBytes([37, 80, 68, 70, 0, 255]);
        return directory;
      }))!;
      final text = File('${directory.path}/example.txt');
      final pdf = File('${directory.path}/lecture.pdf');
      addTearDown(() => t.runAsync(() => directory.delete(recursive: true)));
      var picks = 0;
      const channel = MethodChannel('plugins.flutter.io/file_selector');
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'openFile') {
          expect((call.arguments as Map)['multiple'], isTrue);
          picks++;
          return [text.path, pdf.path];
        }
        return null;
      });
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final store = FolderMemoryStore();
      store.folderList.addAll(['Notes/Course', 'Notes/Course/Week 1']);
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await t.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repo)],
          child: const OrbitNoteApp(),
        ),
      );
      await t.pumpAndSettle();
      final c = ProviderScope.containerOf(
        t.element(find.byType(OrbitNoteApp)),
      ).read(workspaceProvider.notifier);
      c.cancelAllTimers();
      c.pausePdfIndex(true);
      final folder = find.byKey(const ValueKey('folder:Notes/Course/Week 1'));
      expect(folder, findsOneWidget);
      await t.tap(folder, buttons: kSecondaryMouseButton);
      await t.pumpAndSettle();
      await t.tap(find.text('Import files here…'));
      await t.pumpAndSettle();
      expect(find.text('Import 2 files'), findsOneWidget);
      expect(find.text('Destination: Notes/Course/Week 1'), findsOneWidget);
      expect(c.objects.where((o) => o.typeId == 'orbit.file'), isEmpty);
      await t.tap(find.widgetWithText(FilledButton, 'Import files'));
      for (
        var i = 0;
        i < 40 && c.objects.where((o) => o.typeId == 'orbit.file').length < 2;
        i++
      ) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump();
      }
      await t.pumpAndSettle();
      expect(picks, 1);
      final imported = c.objects
          .where((o) => o.typeId == 'orbit.file')
          .toList();
      expect(imported.length, 2);
      for (final file in imported) {
        expect(repo.objectFolder(file.id), 'Notes/Course/Week 1');
        expect(find.byKey(ValueKey('folder-item:${file.id}')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('loose-group:pdfs')), findsNothing);
      await t.tap(find.byKey(const ValueKey('explorer-type-menu')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('filter-chip-notes')));
      await t.pumpAndSettle();
      for (final file in imported) {
        expect(find.byKey(ValueKey('folder-item:${file.id}')), findsNothing);
      }
      await t.tap(find.byTooltip('Show files & PDFs'));
      await t.pumpAndSettle();
      for (final file in imported) {
        expect(find.byKey(ValueKey('folder-item:${file.id}')), findsOneWidget);
      }
      await t.tap(find.byKey(const ValueKey('explorer-type-menu')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('filter-chip-pdfs')));
      await t.pumpAndSettle();
      final pdfObject = imported.singleWhere((o) => o.title.endsWith('.pdf'));
      final textObject = imported.singleWhere((o) => o.title.endsWith('.txt'));
      expect(
        find.byKey(ValueKey('folder-item:${pdfObject.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('folder-item:${textObject.id}')),
        findsNothing,
      );
      expect(t.takeException(), isNull);
      c.cancelAllTimers();
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
  );
}
