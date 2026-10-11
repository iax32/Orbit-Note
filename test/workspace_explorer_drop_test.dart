import 'dart:convert';
import 'dart:typed_data';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/main.dart';
import 'support/memory_store.dart';

class TestDropItem extends DropItemFile {
  TestDropItem(this._testName, Uint8List bytes)
    : _bytes = bytes,
      super.fromData(bytes, name: _testName);

  final String _testName;
  final Uint8List _bytes;

  @override
  String get name => _testName;

  @override
  String get path => _testName;

  @override
  Future<int> length() async => _bytes.length;

  @override
  Future<Uint8List> readAsBytes() async => _bytes;
}

void main() {
  testWidgets(
    'Explorer quick actions, filter chips, search, and header menu work smoothly',
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

      // 1. Check quick action buttons in Explorer
      await tester.tap(find.byKey(const ValueKey('explorer-new-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Note'), findsOneWidget);
      expect(find.text('Canvas'), findsOneWidget);
      expect(find.text('Open PDF'), findsOneWidget);
      expect(find.text('Open image'), findsOneWidget);
      expect(find.text('Import file'), findsOneWidget);

      // 2. Tap Note quick action to create a note
      await tester.tap(find.text('Note'));
      await tester.pumpAndSettle();
      expect(c.ofType('orbit.note').length, 1);

      // 3. Tap Canvas quick action to create a canvas
      await tester.tap(find.byKey(const ValueKey('explorer-new-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Canvas'));
      await tester.pumpAndSettle();
      expect(c.ofType('orbit.canvas').length, 1);

      // 4. Create sample objects: PDF file, Image file, Task
      final pdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.4 sample pdf'));
      final pdfObj = await repository.importAttachment(
        name: 'User Guide.pdf',
        bytes: pdfBytes,
      );

      final imgBytes = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
      ]); // PNG signature
      final imgObj = await repository.importAttachment(
        name: 'Architecture.png',
        bytes: imgBytes,
      );

      await c.create('orbit.task', title: 'Finish Documentation');
      c.objects = [...c.objects, pdfObj, imgObj];
      c.notify();
      await tester.pumpAndSettle();

      // 5. Check type filter chips
      await tester.tap(find.byKey(const ValueKey('explorer-type-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('filter-chip-all')), findsOneWidget);
      expect(find.byKey(const ValueKey('filter-chip-notes')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('filter-chip-canvases')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('filter-chip-pdfs')), findsOneWidget);
      expect(find.byKey(const ValueKey('filter-chip-images')), findsOneWidget);
      expect(find.byKey(const ValueKey('filter-chip-tasks')), findsOneWidget);

      Future<void> tapChip(String key) async {
        if (find.byKey(ValueKey('filter-chip-$key')).evaluate().isEmpty) {
          await tester.tap(find.byKey(const ValueKey('explorer-type-menu')));
          await tester.pumpAndSettle();
        }
        final chip = find.byKey(ValueKey('filter-chip-$key'));
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip, warnIfMissed: false);
        await tester.pumpAndSettle();
      }

      // Test 'Canvases' filter
      await tapChip('canvases');
      expect(find.text('CANVASES · 1'), findsOneWidget);

      // Test 'PDFs' filter
      await tapChip('pdfs');
      expect(find.text('PDFS · 1'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'User Guide.pdf'), findsOneWidget);

      // Test 'Images' filter
      await tapChip('images');
      expect(find.text('IMAGES · 1'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Architecture.png'), findsOneWidget);

      // Test 'Tasks' filter
      await tapChip('tasks');
      expect(find.text('TASKS · 1'), findsOneWidget);
      expect(
        find.widgetWithText(ListTile, 'Finish Documentation'),
        findsOneWidget,
      );

      // Test 'All' filter
      await tapChip('all');
      expect(find.text('ALL ITEMS · 5'), findsOneWidget);

      // 6. Test search filter and clear button
      final searchField = find.byKey(const ValueKey('explorer-filter'));
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'Guide');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'User Guide.pdf'), findsOneWidget);
      expect(
        find.widgetWithText(ListTile, 'Finish Documentation'),
        findsNothing,
      );

      // Clear search
      final clearBtn = find.byTooltip('Clear filter');
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(ListTile, 'Finish Documentation'),
        findsOneWidget,
      );

      // 7. Check header quick menu "Open & Import Files"
      final headerMenu = find.byTooltip('Open & Import Files');
      expect(headerMenu, findsOneWidget);
      await tester.tap(headerMenu);
      await tester.pumpAndSettle();

      expect(find.text('New Note'), findsOneWidget);
      expect(find.text('New Canvas'), findsOneWidget);
      expect(find.text('Open PDF…'), findsOneWidget);
      expect(find.text('Open Image…'), findsOneWidget);
      expect(find.text('Import File…'), findsOneWidget);

      // Dismiss popup
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // 8. Check DropTarget exists around explorer and content
      final dropTargets = tester
          .widgetList<DropTarget>(find.byType(DropTarget))
          .toList();
      expect(dropTargets.length, 2);

      // Clean up
      await c.flushAll();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Drop files onto Canvas, Note, and Explorer targets', (
    tester,
  ) async {
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

    // 1. Create a canvas
    final canvas = (await c.create(
      'orbit.canvas',
      title: 'Interactive Board',
    ))!;
    c.openObject(canvas.id);
    await tester.pumpAndSettle();

    final contentTargetFinder = find.byKey(
      const ValueKey('content-drop-target'),
    );
    expect(contentTargetFinder, findsOneWidget);
    final contentTarget = tester.widget<DropTarget>(contentTargetFinder);

    final explorerTargetFinder = find.byKey(
      const ValueKey('explorer-drop-target'),
    );
    expect(explorerTargetFinder, findsWidgets);
    final explorerTarget = tester.widget<DropTarget>(
      explorerTargetFinder.first,
    );

    // A. Drop a PDF onto Canvas -> should create a card element
    final pdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.4 spec document'));
    contentTarget.onDragDone!(
      DropDoneDetails(
        files: [TestDropItem('System_Spec.pdf', pdfBytes)],
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ),
    );
    await tester.pumpAndSettle();

    var updatedCanvas = c.find(canvas.id)!;
    var elements = (updatedCanvas.data['elements'] as List?) ?? [];
    expect(elements.any((e) => e['type'] == 'card'), isTrue);

    // B. Drop a Mermaid diagram onto Canvas -> should parse and insert elements
    final mermaidBytes = Uint8List.fromList(
      utf8.encode('flowchart TD\n  StepA[Start] --> StepB[Process]'),
    );
    contentTarget.onDragDone!(
      DropDoneDetails(
        files: [TestDropItem('Workflow.mermaid', mermaidBytes)],
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ),
    );
    await tester.pumpAndSettle();

    updatedCanvas = c.find(canvas.id)!;
    elements = (updatedCanvas.data['elements'] as List?) ?? [];
    expect(elements.length, greaterThan(1));

    // 2. Create a Note
    final note = (await c.create('orbit.note', title: 'Project Notes'))!;
    c.openObject(note.id);
    await tester.pumpAndSettle();

    final noteContentTarget = tester.widget<DropTarget>(
      find.byKey(const ValueKey('content-drop-target')),
    );

    // C. Drop a PDF onto Note -> should append markdown link to note body
    final manualPdfBytes = Uint8List.fromList(
      utf8.encode('%PDF-1.4 distinct manual document content'),
    );
    noteContentTarget.onDragDone!(
      DropDoneDetails(
        files: [TestDropItem('Manual.pdf', manualPdfBytes)],
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ),
    );
    await tester.pumpAndSettle();

    var updatedNote = c.find(note.id)!;
    expect(updatedNote.body.contains('Manual'), isTrue);

    // D. Drop a file onto Explorer -> should force import to vault and open it
    final sampleDocBytes = Uint8List.fromList(utf8.encode('hello world data'));
    explorerTarget.onDragDone!(
      DropDoneDetails(
        files: [TestDropItem('VaultImportedDoc.txt', sampleDocBytes)],
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      c.activeObjects.any((o) => o.title == 'VaultImportedDoc.txt'),
      isTrue,
    );
    expect(c.session.activeId, isNotNull);
    final active = c.find(c.session.activeId!)!;
    expect(active.title, 'VaultImportedDoc.txt');

    // Clean up
    await c.flushAll();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
