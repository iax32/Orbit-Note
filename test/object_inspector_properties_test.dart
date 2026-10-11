import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/features/workspace/object_inspector.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  group('WorkspaceController Relations & Properties', () {
    test(
      'outboundLinks discovers resolved wiki-link targets from body',
      () async {
        final store = MemoryStore();
        final repo = WorkspaceRepository(
          store: store,
          index: MemoryObjectIndex(),
        );
        await repo.initialize();
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repo)],
        );
        final c = container.read(workspaceProvider.notifier);
        await c.initialize();

        final target1 = await c.create(
          'orbit.note',
          title: 'Quantum Computing',
        );
        final target2 = await c.create('orbit.note', title: 'Linear Algebra');
        final source = await c.create(
          'orbit.note',
          title: 'Quantum Algorithms',
          body:
              'Intro to [[Quantum Computing]] using [[Linear Algebra]] fundamentals.',
        );

        final outbound = c.outboundLinks(source!.id);
        expect(
          outbound.map((o) => o.id),
          containsAll([target1!.id, target2!.id]),
        );
        expect(outbound.length, 2);

        final backlinks1 = c.backlinks(target1.id);
        expect(backlinks1.map((o) => o.id), contains(source.id));
      },
    );

    test(
      'relatedObjects discovers items sharing project, folder, or tags',
      () async {
        final store = MemoryStore();
        final repo = WorkspaceRepository(
          store: store,
          index: MemoryObjectIndex(),
        );
        await repo.initialize();
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repo)],
        );
        final c = container.read(workspaceProvider.notifier);
        await c.initialize();

        final a = await c.create('orbit.note', title: 'Mission Architecture');
        c.updateProperty(a!.id, 'project', 'artemis');
        c.updateProperty(a.id, 'tags', ['space', 'propulsion']);

        final b = await c.create('orbit.note', title: 'Rocket Booster Design');
        c.updateProperty(b!.id, 'project', 'artemis');

        final d = await c.create('orbit.note', title: 'Lunar Geology');
        c.updateProperty(d!.id, 'tags', ['space', 'science']);

        final unrelated = await c.create('orbit.note', title: 'Grocery List');
        c.updateProperty(unrelated!.id, 'project', 'home');

        final relatedToA = c.relatedObjects(a.id);
        final relatedIds = relatedToA.map((o) => o.id).toSet();

        expect(relatedIds, contains(b.id));
        expect(relatedIds, contains(d.id));
        expect(relatedIds, isNot(contains(a.id)));
        expect(relatedIds, isNot(contains(unrelated.id)));
      },
    );

    test(
      'updateProperty and removeProperty safely mutate and persist properties',
      () async {
        final store = MemoryStore();
        final repo = WorkspaceRepository(
          store: store,
          index: MemoryObjectIndex(),
        );
        await repo.initialize();
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repo)],
        );
        final c = container.read(workspaceProvider.notifier);
        await c.initialize();

        final o = await c.create('orbit.note', title: 'Experiment Log');
        expect(c.find(o!.id)!.properties['priority'], isNull);

        c.updateProperty(o.id, 'priority', 'high');
        expect(c.find(o.id)!.properties['priority'], 'high');

        c.updateProperty(o.id, 'rating', 4.5);
        expect(c.find(o.id)!.properties['rating'], 4.5);

        c.updateProperty(o.id, 'reviewed', true);
        expect(c.find(o.id)!.properties['reviewed'], true);

        c.removeProperty(o.id, 'priority');
        expect(c.find(o.id)!.properties['priority'], isNull);
        expect(c.find(o.id)!.properties['rating'], 4.5);
      },
    );
  });

  group('ObjectInspector Widget', () {
    testWidgets('shows empty placeholder when no active object', (
      tester,
    ) async {
      final store = MemoryStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      final c = container.read(workspaceProvider.notifier);
      await c.initialize();

      c.session.activeId = null;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: ObjectInspector(controller: c, onRename: (_) {}),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Open an object to inspect properties and context.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'renders typed properties, relations tabs, and allows editing',
      (tester) async {
        final store = MemoryStore();
        final repo = WorkspaceRepository(
          store: store,
          index: MemoryObjectIndex(),
        );
        await repo.initialize();
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repo)],
        );
        final c = container.read(workspaceProvider.notifier);
        await c.initialize();

        final targetNote = await c.create(
          'orbit.note',
          title: 'Related Research',
        );
        final activeNote = await c.create(
          'orbit.note',
          title: 'Autonomous Navigation',
          body: 'Investigating [[Related Research]] for path planning.',
        );

        c.updateProperty(activeNote!.id, 'priority', 'high');
        c.updateProperty(activeNote.id, 'score', 98);
        c.updateProperty(activeNote.id, 'isCompleted', false);
        c.updateProperty(activeNote.id, 'due', '2026-10-15');
        c.updateProperty(activeNote.id, 'tags', ['ai', 'robotics']);
        c.updateProperty(activeNote.id, 'url', 'https://example.com/paper');
        c.openObject(activeNote.id);

        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        var renamed = false;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 320,
                  height: 900,
                  child: ObjectInspector(
                    controller: c,
                    onRename: (_) => renamed = true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Identity & metadata
        expect(find.text('Autonomous Navigation'), findsOneWidget);
        expect(find.text('NOTE'), findsOneWidget);
        expect(find.textContaining('ID: ${activeNote.id}'), findsOneWidget);

        // Properties
        expect(find.text('priority'), findsOneWidget);
        expect(find.text('high'), findsOneWidget);
        expect(find.text('score'), findsOneWidget);
        expect(find.text('98'), findsOneWidget);
        expect(find.text('isCompleted'), findsOneWidget);
        expect(find.byType(Switch), findsOneWidget);
        expect(find.text('2026-10-15'), findsOneWidget);
        expect(find.text('#ai'), findsOneWidget);
        expect(find.text('#robotics'), findsOneWidget);
        expect(find.text('https://example.com/paper'), findsOneWidget);

        // Boolean switch toggle
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(c.find(activeNote.id)!.properties['isCompleted'], true);

        // Relations tabs: Switch to Outbound
        await tester.scrollUntilVisible(find.text('Outbound'), 100);
        await tester.pump();
        expect(find.text('Outbound'), findsOneWidget);
        await tester.tap(find.text('Outbound'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text(targetNote!.title), 100);
        await tester.pump();
        expect(find.text(targetNote.title), findsOneWidget);

        // Relations tabs: Switch to Related
        await tester.ensureVisible(find.text('Related'));
        await tester.pump();
        await tester.tap(find.text('Related'));
        await tester.pumpAndSettle();

        // Rename button
        await tester.scrollUntilVisible(find.text('Rename Object'), 100);
        await tester.pump();
        await tester.tap(find.text('Rename Object'));
        expect(renamed, isTrue);

        // Remove property
        await tester.scrollUntilVisible(
          find.byTooltip('Remove priority'),
          -100,
        );
        await tester.pump();
        await tester.tap(find.byTooltip('Remove priority'));
        await tester.pumpAndSettle();
        expect(c.find(activeNote.id)!.properties['priority'], isNull);

        await c.flushAll();
        c.cancelAllTimers();
        await tester.pump();
      },
    );

    testWidgets(
      'Add property dialog validates and adds a new number property',
      (tester) async {
        final store = MemoryStore();
        final repo = WorkspaceRepository(
          store: store,
          index: MemoryObjectIndex(),
        );
        await repo.initialize();
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repo)],
        );
        final c = container.read(workspaceProvider.notifier);
        await c.initialize();

        final note = await c.create('orbit.note', title: 'Mission Telemetry');
        c.openObject(note!.id);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 320,
                  height: 900,
                  child: ObjectInspector(controller: c, onRename: (_) {}),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap + Add
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();

        expect(find.text('Add Property'), findsNWidgets(2));

        // Try adding with empty name
        await tester.tap(find.text('Add Property').last);
        await tester.pumpAndSettle();
        expect(find.text('Name cannot be empty'), findsOneWidget);

        // Enter property name
        await tester.enterText(find.byType(TextFormField).first, 'altitude');

        // Select 'Number' type
        await tester.tap(find.byType(DropdownButtonFormField<PropertyType>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Number').last);
        await tester.pumpAndSettle();

        // Enter number value
        await tester.enterText(find.byType(TextFormField).last, '408');

        // Submit
        await tester.tap(find.text('Add Property').last);
        await tester.pumpAndSettle();

        expect(c.find(note.id)!.properties['altitude'], 408);
        await tester.scrollUntilVisible(find.text('altitude'), -100);
        expect(find.text('altitude'), findsOneWidget);
        expect(find.text('408'), findsOneWidget);

        await c.flushAll();
        c.cancelAllTimers();
        await tester.pump();
      },
    );
  });
}
