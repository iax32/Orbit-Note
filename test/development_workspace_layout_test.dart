import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/app_zoom.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/workspace/analysis_dashboard_view.dart';
import 'package:orbit_note/features/workspace/game_dashboard_view.dart';
import 'package:orbit_note/features/workspace/function_table_view.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  late WorkspaceController controller;
  late ProviderContainer container;
  setUp(() async {
    final repo = WorkspaceRepository(
      store: FolderMemoryStore(),
      index: MemoryObjectIndex(),
    );
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    container.read(workspaceProvider);
    controller = container.read(workspaceProvider.notifier);
    while (controller.loading) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  });
  tearDown(() async {
    await controller.flushAll();
    container.dispose();
  });
  UniversalObject view() => UniversalObject(
    id: 'view',
    workspaceId: 'workspace',
    typeId: 'orbit.view',
    title: 'Workspace',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    double zoom = 1,
  }) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: orbitDarkTheme(uiZoom: zoom),
        builder: (_, child) =>
            AppZoom(zoom: zoom, onChanged: (_) {}, child: child!),
        home: Scaffold(body: child),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'research dashboard reflows at 200% and handles empty hypothesis status',
    (tester) async {
      final hypothesis = (await tester.runAsync(
        () => controller.createResearchRecord(
          folder: 'Notes',
          category: 'Hypothesis',
          title: 'Investigate',
        ),
      ))!;
      controller.edit(
        hypothesis.id,
        properties: {...hypothesis.properties, 'status': ''},
      );
      await tester.runAsync(() => controller.flush(hypothesis.id));
      await mount(
        tester,
        AnalysisDashboardView(controller: controller, viewObject: view()),
        zoom: 2,
      );
      expect(find.text('Research workspace'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('New Function'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final action = tester.widget<FilledButton>(
        find
            .ancestor(
              of: find.text('New Function'),
              matching: find.byType(FilledButton),
            )
            .first,
      );
      action.onPressed!();
      await tester.pumpAndSettle();
      expect(find.text('Research record'), findsOneWidget);
      expect(find.text('Binary and address context'), findsOneWidget);
      expect(find.text('0x1400'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('game production cards and bug creation fit at 200%', (
    tester,
  ) async {
    await mount(
      tester,
      GameDashboardView(controller: controller, viewObject: view()),
      zoom: 2,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('New Bug'));
    await tester.pumpAndSettle();
    expect(find.text('New Bug Report'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow function browser keeps filters and scrollable actions', (
    tester,
  ) async {
    await tester.runAsync(
      () => controller.createResearchRecord(
        folder: 'Notes',
        category: 'Function',
        title: 'Decode',
      ),
    );
    await mount(
      tester,
      FunctionTableView(controller: controller, viewObject: view()),
      zoom: 2,
    );
    expect(find.text('1 of 1 functions'), findsOneWidget);
    expect(find.text('Confidence'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final horizontal = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    await tester.drag(horizontal, const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Open Note'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
