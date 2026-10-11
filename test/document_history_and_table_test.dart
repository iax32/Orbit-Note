import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';
import 'package:orbit_note/features/notes/bionic_reading.dart';
import 'package:orbit_note/features/notes/document_history_dialog.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/table_editor_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkspaceController controller;
  late MemoryStore store;

  setUp(() async {
    store = MemoryStore();
    controller = WorkspaceController();
    controller.repository = WorkspaceRepository(
      store: store,
      index: MemoryObjectIndex(),
    );
    await controller.initialize();
  });

  tearDown(() async {
    controller.cancelAllTimers();
    await controller.closeWorkspace();
  });

  group('WorkspaceController Document Snapshots & Revisions', () {
    test('getDocumentSnapshots returns empty list initially', () async {
      final note = await controller.create(
        'orbit.note',
        title: 'Test Note',
        body: 'Initial draft',
      );
      expect(note, isNotNull);
      final snapshots = controller.getDocumentSnapshots(note!.id);
      expect(snapshots, isEmpty);
    });

    test(
      'createDocumentSnapshot captures revision, timestamp, and word count',
      () async {
        final note = await controller.create(
          'orbit.note',
          title: 'Quantum Computing',
          body: 'Quantum computers use qubits rather than binary bits.',
        );
        expect(note, isNotNull);

        final snap = await controller.createDocumentSnapshot(
          note!.id,
          label: 'First Draft',
        );
        expect(snap, isNotNull);
        expect(snap!['title'], 'Quantum Computing');
        expect(snap['body'], contains('qubits'));
        expect(snap['label'], 'First Draft');
        expect((snap['wordCount'] as int), greaterThan(5));

        final snapshots = controller.getDocumentSnapshots(note.id);
        expect(snapshots.length, 1);
        expect(snapshots.first['id'], snap['id']);
      },
    );

    test('retains max 30 snapshots and purges oldest FIFO', () async {
      final note = await controller.create(
        'orbit.note',
        title: 'Rolling Note',
        body: 'Start',
      );
      expect(note, isNotNull);

      for (var i = 1; i <= 35; i++) {
        controller.edit(note!.id, body: 'Revision $i content');
        await controller.createDocumentSnapshot(note.id, label: 'Rev $i');
      }

      final snapshots = controller.getDocumentSnapshots(note!.id);
      expect(snapshots.length, 30);
      // Newest should be 'Rev 35'
      expect(snapshots.first['label'], 'Rev 35');
      // Oldest retained should be 'Rev 6' (35 - 30 + 1)
      expect(snapshots.last['label'], 'Rev 6');
    });

    test(
      'restoreDocumentSnapshot creates automatic pre-restore checkpoint and reverts content',
      () async {
        final note = await controller.create(
          'orbit.note',
          title: 'Chapter 1',
          body: 'Original Version',
        );
        expect(note, isNotNull);

        final snap1 = await controller.createDocumentSnapshot(
          note!.id,
          label: 'Version 1',
        );
        expect(snap1, isNotNull);

        // Make changes
        controller.edit(
          note.id,
          title: 'Chapter 1 (Edited)',
          body: 'Heavily edited work in progress',
        );

        // Revert to snapshot 1
        final success = await controller.restoreDocumentSnapshot(
          note.id,
          snap1!['id'] as String,
        );
        expect(success, isTrue);

        final current = controller.find(note.id);
        expect(current?.title, 'Chapter 1');
        expect(current?.body, 'Original Version');

        // Check that a pre-restore checkpoint was created
        final snaps = controller.getDocumentSnapshots(note.id);
        expect(snaps.first['label'], 'Pre-restore checkpoint');
        expect(snaps.first['body'], 'Heavily edited work in progress');
      },
    );
  });

  group('LCS Line Diff Computation', () {
    test('identifies additions, deletions, and unchanged lines', () {
      const oldText = 'Line A\nLine B\nLine C';
      const newText = 'Line A\nLine Modified\nLine C\nLine D';

      final diff = computeSimpleDiff(oldText, newText);
      expect(diff, isNotEmpty);

      final added = diff.where((d) => d.type == DiffType.added).toList();
      final removed = diff.where((d) => d.type == DiffType.removed).toList();
      final unchanged = diff
          .where((d) => d.type == DiffType.unchanged)
          .toList();

      expect(added.any((d) => d.text == 'Line Modified'), isTrue);
      expect(added.any((d) => d.text == 'Line D'), isTrue);
      expect(removed.any((d) => d.text == 'Line B'), isTrue);
      expect(unchanged.any((d) => d.text == 'Line A'), isTrue);
      expect(unchanged.any((d) => d.text == 'Line C'), isTrue);
    });

    test('handles empty original or empty updated text', () {
      final diffFromEmpty = computeSimpleDiff('', 'Hello\nWorld');
      expect(diffFromEmpty.every((d) => d.type == DiffType.added), isTrue);

      final diffToEmpty = computeSimpleDiff('Hello\nWorld', '');
      expect(diffToEmpty.every((d) => d.type == DiffType.removed), isTrue);
    });
  });

  group('Bionic Reading Engine', () {
    test('fixationLength calculates optimal fixation points', () {
      expect(BionicReading.fixationLength(1), 1);
      expect(BionicReading.fixationLength(2), 1);
      expect(BionicReading.fixationLength(3), 1);
      expect(BionicReading.fixationLength(4), 2);
      expect(BionicReading.fixationLength(5), 2);
      expect(BionicReading.fixationLength(8), 3);
      expect(BionicReading.fixationLength(10), 4);
    });

    test('toBionicMarkdown bolds word prefixes correctly', () {
      final result = BionicReading.toBionicMarkdown('Orbit Note is fast');
      expect(result, '**Or**bit **No**te **i**s **fa**st');
    });

    test('preserves code blocks, inline code, and URLs', () {
      const input =
          'Check out https://github.com and `flutter test`\n```dart\nvoid main() {}\n```';
      final bionic = BionicReading.toBionicMarkdown(input);

      // URLs preserved
      expect(bionic, contains('https://github.com'));
      // Inline code preserved
      expect(bionic, contains('`flutter test`'));
      // Code blocks preserved
      expect(bionic, contains('```dart\nvoid main() {}\n```'));
    });

    test('preserves LaTeX math formulas', () {
      const input = r'The equation is $E = mc^2$ and display $$\int_0^1 x dx$$';
      final bionic = BionicReading.toBionicMarkdown(input);

      expect(bionic, contains(r'$E = mc^2$'));
      expect(bionic, contains(r'$$\int_0^1 x dx$$'));
    });
  });

  group('MarkdownTableDialog Widget', () {
    testWidgets('renders table dimension pickers and alignment controls', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MarkdownTableDialog())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Insert Markdown Table'), findsOneWidget);
      expect(find.textContaining('COLUMNS:'), findsOneWidget);
      expect(find.textContaining('ROWS:'), findsOneWidget);
      expect(find.byKey(const ValueKey('table-insert-btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('table-cancel-btn')), findsOneWidget);
    });

    testWidgets('allows customizing headers and generates valid GFM markdown', (
      tester,
    ) async {
      String? generated;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const ValueKey('open-btn'),
                onPressed: () async {
                  generated = await showMarkdownTableDialog(ctx);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open-btn')));
      await tester.pumpAndSettle();

      // Enter custom header in first column
      final headerFinder = find.byKey(const ValueKey('table-col-header-0'));
      expect(headerFinder, findsOneWidget);
      await tester.enterText(headerFinder, 'Features');
      await tester.pumpAndSettle();

      // Tap Insert Table
      await tester.tap(find.byKey(const ValueKey('table-insert-btn')));
      await tester.pumpAndSettle();

      expect(generated, isNotNull);
      expect(generated, contains('| Features |'));
      expect(generated, contains('| :---'));
    });
  });

  group('NoteEditor History and Bionic Reading UI Integration', () {
    testWidgets('header includes note-history-button and note-bionic-toggle', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditor(
              noteId: 'ui-test-note',
              title: 'UI Test Note',
              body: 'Testing history button and bionic reading toggle.',
              controller: controller,
              initialViewState: const {'mode': 'write'},
              onTitleChanged: (_) {},
              onBodyChanged: (_) {},
              linkTargets: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const ValueKey('note-history-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-bionic-toggle')), findsOneWidget);

      // Tap bionic toggle
      await tester.tap(find.byKey(const ValueKey('note-bionic-toggle')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('DocumentHistoryDialog renders snapshots list and actions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final note = await tester.runAsync(
        () => controller.create(
          'orbit.note',
          title: 'History Note',
          body: 'Initial content for testing.',
        ),
      );
      expect(note, isNotNull);

      await tester.runAsync(
        () =>
            controller.createDocumentSnapshot(note!.id, label: 'Release v1.0'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentHistoryDialog(
              controller: controller,
              objectId: note!.id,
              currentTitle: note.title,
              currentBody: 'Updated body for testing.',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Revision History & Snapshots'), findsOneWidget);
      expect(find.text('Release v1.0'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('create-snapshot-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('restore-snapshot-button')),
        findsOneWidget,
      );
    });
  });
}
