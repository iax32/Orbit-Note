import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_scroll_safe_drag.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/features/workspace/workspace_shell.dart';
import 'package:orbit_note/features/workspace/note_folder_explorer.dart';
import 'package:orbit_note/features/workspace/orbit_explorer_row.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';
import 'support/capture_ui.dart';

void main() {
  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.stylus]) {
    testWidgets(
      '$kind swipe scrolls instead of dragging or opening; holding still drags',
      (t) async {
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        var opened = 0;
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 300,
                child: ListView.builder(
                  controller: scroll,
                  itemCount: 100,
                  itemBuilder: (_, i) => OrbitScrollSafeDrag<int>(
                    data: i,
                    feedback: const Material(
                      key: ValueKey('drag-feedback'),
                      child: Text('Moving item'),
                    ),
                    child: OrbitExplorerRow(
                      leading: const Icon(Icons.description_outlined),
                      title: Text('Item $i'),
                      onTap: () => opened++,
                      menu: PopupMenuButton<String>(
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'move', child: Text('Move')),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final at = t.getCenter(find.text('Item 3'));
        final swipe = await t.startGesture(at, kind: kind);
        await swipe.moveBy(const Offset(0, -90));
        await t.pump(const Duration(milliseconds: 16));
        await swipe.moveBy(const Offset(0, -90));
        await swipe.up();
        await t.pumpAndSettle();
        expect(scroll.offset, greaterThan(70));
        expect(opened, 0);
        expect(find.byKey(const ValueKey('drag-feedback')), findsNothing);
        final row = find.byType(OrbitExplorerRow).hitTestable().first;
        final hold = await t.startGesture(t.getCenter(row), kind: kind);
        await t.pump(kLongPressTimeout + const Duration(milliseconds: 20));
        await hold.moveBy(const Offset(30, 10));
        await t.pump();
        expect(find.byKey(const ValueKey('drag-feedback')), findsOneWidget);
        await hold.up();
        await t.pumpAndSettle();
        expect(opened, 0);
        await t.tap(find.byType(OrbitExplorerRow).hitTestable().first);
        await t.pumpAndSettle();
        expect(opened, 1);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets('mouse drag stays immediate on a tablet theme', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: orbitDarkTheme().copyWith(platform: TargetPlatform.android),
        home: Scaffold(
          body: OrbitScrollSafeDrag<int>(
            data: 1,
            feedback: const Material(
              key: ValueKey('drag-feedback'),
              child: Text('Moving'),
            ),
            child: const SizedBox(
              width: 100,
              height: 60,
              child: Text('Mouse item'),
            ),
          ),
        ),
      ),
    );
    final gesture = await t.startGesture(
      t.getCenter(find.text('Mouse item')),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(35, 20));
    await t.pump();
    expect(find.byKey(const ValueKey('drag-feedback')), findsOneWidget);
    await gesture.up();
    await t.pumpAndSettle();
  });
  for (final size in [const Size(820, 600), const Size(360, 640)]) {
    testWidgets(
      'tablet explorer reserves item space and keeps tools at $size',
      (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final container = ProviderContainer(
          overrides: [
            repositoryProvider.overrideWithValue(
              WorkspaceRepository(
                store: FolderMemoryStore(),
                index: MemoryObjectIndex(),
              ),
            ),
          ],
        );
        final c = container.read(workspaceProvider.notifier);
        await c.initialize();
        await c.create('orbit.note', title: 'Tablet notes', open: true);
        c.session.motion = 'off';
        c.cancelAllTimers();
        c.pausePdfIndex(true);
        addTearDown(() {
          c.cancelAllTimers();
          container.dispose();
        });
        await prepareCapture(t);
        await t.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: orbitDarkTheme().copyWith(
                platform: TargetPlatform.android,
              ),
              home: const WorkspaceShell(),
            ),
          ),
        );
        await t.pumpAndSettle();
        // Narrow touch layouts expose their explorer through the drawer.
        final scaffold = t.state<ScaffoldState>(find.byType(Scaffold).first);
        scaffold.openDrawer();
        await t.pumpAndSettle();
        final explorer = find.byType(NoteFolderExplorer).hitTestable().first;
        expect(t.getSize(explorer).height, greaterThan(size.height * .4));
        final before = t.getSize(explorer).height;
        await t.tap(
          find
              .byKey(const ValueKey('compact-explorer-tools'))
              .hitTestable()
              .first,
        );
        await t.pumpAndSettle();
        expect(c.session.extra['compactExplorerToolsExpanded'], true);
        expect(t.getSize(explorer).height, greaterThan(size.height * .4));
        expect(t.getSize(explorer).height, lessThanOrEqualTo(before));
        await t.tap(
          find
              .byKey(const ValueKey('compact-explorer-tools'))
              .hitTestable()
              .first,
        );
        await t.pumpAndSettle();
        expect(c.session.extra['compactExplorerToolsExpanded'], false);
        final reopened = SessionState.fromJson(c.session.toJson());
        expect(reopened.extra['compactExplorerToolsExpanded'], false);
        await captureUi(t, 'tablet-explorer-${size.width.toInt()}');
        await t.ensureVisible(
          find.byKey(const ValueKey('explorer-filter')).hitTestable().first,
        );
        await t.enterText(
          find.byKey(const ValueKey('explorer-filter')).hitTestable().first,
          'Tablet',
        );
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Clear filter').hitTestable().first);
        await t.pumpAndSettle();
        expect(
          t
              .widget<TextField>(
                find
                    .byKey(const ValueKey('explorer-filter'))
                    .hitTestable()
                    .first,
              )
              .controller!
              .text,
          isEmpty,
        );
        expect(t.takeException(), isNull);
        c.cancelAllTimers();
        await t.pumpWidget(const SizedBox());
        c.cancelAllTimers();
      },
    );
  }
}
