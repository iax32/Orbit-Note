import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/project_context.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/workspace/object_bridges.dart';
import 'package:orbit_note/features/workspace/object_connection_dialog.dart';
import 'package:orbit_note/features/workspace/object_tag_dialog.dart';
import 'package:orbit_note/features/workspace/project_context_panel.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

Future<
  (
    WorkspaceController,
    MemoryStore,
    BuildContext,
    UniversalObject,
    UniversalObject,
  )
>
fixture(WidgetTester t, {double width = 1100, double scale = 1}) async {
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1;
  final store = MemoryStore();
  final container = ProviderContainer(
    overrides: [
      repositoryProvider.overrideWithValue(
        WorkspaceRepository(store: store, index: MemoryObjectIndex()),
      ),
    ],
  );
  final home = GlobalKey();
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          key: home,
          body: Consumer(
            builder: (context, ref, _) {
              ref.watch(workspaceProvider);
              return ProjectContextPanel(
                controller: ref.read(workspaceProvider.notifier),
              );
            },
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  final c = container.read(workspaceProvider.notifier);
  c.pausePdfIndex(true);
  c.cancelAllTimers();
  final project = (await c.create(
    'orbit.note',
    title: 'Project',
    properties: {'isCreativeBrief': true},
  ))!;
  final note = (await c.create(
    'orbit.note',
    title: 'Research',
    properties: {
      'future': {'keep': true},
    },
  ))!;
  c.openObject(note.id);
  await t.pumpAndSettle();
  addTearDown(() async {
    c.cancelAllTimers();
    await t.pumpWidget(const SizedBox());
    container.dispose();
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  });
  return (c, store, home.currentContext!, note, project);
}

void main() {
  testWidgets(
    'tag entry stays with its original document after active tab changes',
    (t) async {
      final (c, _, context, note, project) = await fixture(t);
      final done = showObjectTagDialog(context, c);
      await t.pumpAndSettle();
      c.openObject(project.id);
      await t.enterText(find.byType(TextField), 'draft');
      await t.tap(find.text('Add'));
      await t.pumpAndSettle();
      await done;
      c.cancelAllTimers();
      expect(c.find(note.id)!.properties['tags'], ['draft']);
      expect(c.find(project.id)!.properties['tags'], isNull);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'reference picker shows current names and removes deleted choices',
    (t) async {
      final (c, _, context, note, _) = await fixture(t);
      final done = showObjectReferencePicker(context, c);
      await t.pumpAndSettle();
      final old = t.widget<ListTile>(find.widgetWithText(ListTile, 'Research'));
      c.edit(note.id, title: 'New research');
      await t.pumpAndSettle();
      expect(find.text('New research'), findsOneWidget);
      await c.trash(note.id);
      old.onLongPress!();
      await t.pumpAndSettle();
      expect(find.text('New research'), findsNothing);
      expect(find.text('Use reference'), findsOneWidget);
      await t.tap(find.byTooltip('Cancel reference picker'));
      await t.pumpAndSettle();
      expect(await done, isNull);
      c.cancelAllTimers();
    },
  );

  testWidgets(
    'Enter never substitutes another object after selected object disappears',
    (t) async {
      final (c, _, context, note, _) = await fixture(t);
      final done = showObjectReferencePicker(context, c);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ListTile, 'Research'));
      await t.pumpAndSettle();
      await c.trash(note.id);
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(find.text('Use reference'), findsOneWidget);
      await t.tap(find.byTooltip('Cancel reference picker'));
      await t.pumpAndSettle();
      expect(await done, isNull);
      c.cancelAllTimers();
    },
  );

  testWidgets(
    'project picker checks live membership even for a retained row callback',
    (t) async {
      final (c, _, context, note, project) = await fixture(t);
      await c.assignObjectProject(note.id, project.id);
      final done = showObjectReferencePicker(context, c, project: project.id);
      await t.pumpAndSettle();
      final old = t.widget<ListTile>(find.widgetWithText(ListTile, 'Research'));
      c.updateProperty(note.id, 'project', 'elsewhere');
      old.onLongPress!();
      await t.pumpAndSettle();
      expect(find.text('Research'), findsNothing);
      await t.tap(find.byTooltip('Cancel reference picker'));
      await t.pumpAndSettle();
      expect(await done, isNull);
      c.cancelAllTimers();
    },
  );

  testWidgets(
    'failed connection save retains draft and retry does not duplicate the edge',
    (t) async {
      final (c, store, context, note, project) = await fixture(t);
      final done = showObjectConnectionEditor(
        context,
        c,
        note,
        project,
        generation: c.workspaceGeneration,
      );
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).last, 'Supporting evidence');
      store.failWrites = true;
      await t.tap(find.text('Add connection'));
      await t.pumpAndSettle();
      expect(find.text('Retry local save'), findsOneWidget);
      expect(c.dirty, contains(note.id));
      expect(
        ProjectConnection.read(c.find(note.id)!.properties['orbitConnections']),
        hasLength(1),
      );
      store.failWrites = false;
      await t.tap(find.text('Retry local save'));
      await t.pumpAndSettle();
      expect(await done, isTrue);
      expect(c.dirty, isNot(contains(note.id)));
      expect(
        ProjectConnection.read(c.find(note.id)!.properties['orbitConnections']),
        hasLength(1),
      );
      expect(c.find(note.id)!.properties['future'], {'keep': true});
      c.cancelAllTimers();
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('connection retry refuses a newer relation list', (t) async {
    final (c, store, context, note, project) = await fixture(t);
    final done = showObjectConnectionEditor(
      context,
      c,
      note,
      project,
      generation: c.workspaceGeneration,
    );
    await t.pumpAndSettle();
    store.failWrites = true;
    await t.tap(find.text('Add connection'));
    await t.pumpAndSettle();
    final raw = c.find(note.id)!.properties['orbitConnections'] as Map;
    c.updateProperty(note.id, 'orbitConnections', {...raw, 'future': 42});
    store.failWrites = false;
    await t.tap(find.text('Retry local save'));
    await t.pumpAndSettle();
    expect(find.text('Retry local save'), findsOneWidget);
    expect(
      (c.find(note.id)!.properties['orbitConnections'] as Map)['future'],
      42,
    );
    await t.tap(find.text('Cancel').last);
    await t.pumpAndSettle();
    expect(await done, isNull);
    c.cancelAllTimers();
  });

  for (final compact in [false, true]) {
    testWidgets(
      'connection form retains controls at ${compact ? '360px/200%' : 'desktop'}',
      (t) async {
        final (c, _, context, note, project) = await fixture(
          t,
          width: compact ? 360 : 1100,
          scale: compact ? 2 : 1,
        );
        final done = showObjectConnectionEditor(
          context,
          c,
          note,
          project,
          generation: c.workspaceGeneration,
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.tap(find.text('Cancel').last);
        await t.pumpAndSettle();
        expect(await done, isNull);
        expect(t.takeException(), isNull);
        c.cancelAllTimers();
      },
    );
  }

  testWidgets(
    'large Vault picker limits rows and finds aliases beyond its first page',
    (t) async {
      final (c, _, context, note, _) = await fixture(t);
      c.objects = [
        ...c.objects,
        for (var i = 0; i < 5000; i++)
          UniversalObject(
            id: 'synthetic-$i',
            workspaceId: note.workspaceId,
            typeId: 'orbit.note',
            title: 'Synthetic ${i.toString().padLeft(4, '0')}',
            createdAt: note.createdAt,
            updatedAt: note.updatedAt,
            properties: {
              'aliases': ['alias-$i'],
              'folder': 'Synthetic/References',
            },
          ),
      ];
      c.notify();
      final done = showObjectReferencePicker(context, c);
      await t.pumpAndSettle();
      expect(
        t.widgetList<ListTile>(find.byType(ListTile)).length,
        lessThanOrEqualTo(40),
      );
      await t.enterText(find.byType(TextField), 'alias-4999');
      await t.pumpAndSettle();
      expect(find.text('Synthetic 4999'), findsOneWidget);
      await t.tap(find.widgetWithText(ListTile, 'Synthetic 4999'));
      await t.pumpAndSettle();
      await t.tap(find.text('Use reference'));
      await t.pumpAndSettle();
      expect((await done)?.id, 'synthetic-4999');
      c.cancelAllTimers();
    },
  );
}
