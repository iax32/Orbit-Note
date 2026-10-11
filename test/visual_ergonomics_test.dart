import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_app.dart';
import 'package:orbit_note/app/orbit_density.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/board_status.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/workspace/collection_kanban_view.dart';
import 'package:orbit_note/features/workspace/orbit_tab_strip.dart';
import 'package:orbit_note/features/workspace/workspace_views.dart';
import 'package:orbit_note/features/workspace/timeline_view.dart';
import 'package:orbit_note/features/workspace/game_dashboard_view.dart';
import 'package:orbit_note/features/workspace/milestone_view.dart';
import 'package:orbit_note/features/workspace/project_dashboard_view.dart';
import 'package:orbit_note/features/workspace/course_dashboard_view.dart';
import 'package:orbit_note/features/workspace/analysis_dashboard_view.dart';
import 'package:orbit_note/features/workspace/calendar_view.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  const capture = bool.fromEnvironment('ORBIT_CAPTURE_UI');
  test('known board aliases map without losing unknown statuses', () {
    expect(boardStatus('todo', ['backlog', 'planned', 'done']), 'planned');
    expect(boardStatus('To Do', ['todo', 'done']), 'todo');
    expect(boardStatus('in_progress', ['in-progress']), 'in-progress');
    expect(boardStatus('completed', ['done']), 'done');
    expect(boardStatus('Future workflow', ['todo', 'done']), 'none');
  });
  test('density reduces geometry while retaining readable typography', () {
    const comfortable = OrbitDensity();
    const compact = OrbitDensity(compact: true);
    expect(comfortable.rowHeight, 36);
    expect(compact.rowHeight, 30);
    expect(const OrbitDensity(scale: 1.25).boardColumn, 380);
    expect(orbitDarkTheme().textTheme.bodySmall!.fontSize, 12);
    expect(orbitDarkTheme(compact: true).textTheme.bodySmall!.fontSize, 12);
    final c = const OrbitColors();
    final contrast =
        (c.subtle.computeLuminance() + .05) /
        (c.panel.computeLuminance() + .05);
    expect(contrast, greaterThan(7));
  });

  late ProviderContainer container;
  late WorkspaceController c;
  final notes = <UniversalObject>[];
  final tasks = <UniversalObject>[];
  late UniversalObject board;
  Future<void> fixture(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      if (capture && Platform.isWindows) {
        final font = FontLoader('Segoe UI')
          ..addFont(
            File(
              r'C:\Windows\Fonts\segoeui.ttf',
            ).readAsBytes().then((bytes) => bytes.buffer.asByteData()),
          );
        await font.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      }
    });
    container = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(
          WorkspaceRepository(
            store: FolderMemoryStore(),
            index: MemoryObjectIndex(),
          ),
        ),
      ],
    );
    container.read(workspaceProvider);
    c = container.read(workspaceProvider.notifier);
    await c.initialize();
    notes.clear();
    tasks.clear();
    for (var i = 0; i < 15; i++) {
      notes.add(
        (await c.create(
          'orbit.note',
          title: i == 14
              ? 'Core mechanics specification — Afterglow'
              : 'Design reference ${i + 1}',
          body:
              '# Design intent\n\nMovement should feel precise and forgiving. Keep the player in control.\n\n## Goals\n\n- Fast feedback\n- Clear silhouettes\n- [ ] Review the camera rig\n\n${List.filled(15, 'The prototype connects exploration, movement and moment-to-moment feedback. Record the decisions beside the evidence.\n\n').join()}',
          properties: {
            'folder': 'Games/Afterglow/Design',
            'project': 'Afterglow',
          },
        ))!,
      );
    }
    for (var i = 0; i < 30; i++) {
      tasks.add(
        (await c.create(
          'orbit.task',
          title: i == 0
              ? 'Implement player movement and camera rig with accessible controls and controller support'
              : 'Iteration ${i + 1}: refine combat feedback',
          properties: {
            'folder': 'Games/Afterglow/Production',
            'project': 'Afterglow',
            'status': i % 3 == 0 ? 'todo' : 'in-progress',
            'priority': i % 4 == 0 ? 'high' : 'medium',
            'estimate': '5',
            'discipline': 'Gameplay',
            'milestone': [
              'Prototype',
              'Vertical Slice',
              'Alpha',
              'Beta',
              'Release',
            ][i % 5],
          },
        ))!,
      );
    }
    board = (await c.create(
      'orbit.view',
      title: 'Afterglow board',
      properties: {
        'folder': 'Games/Afterglow',
        'scope': 'Afterglow',
        'viewType': 'board',
        'preset': 'gamedev',
      },
    ))!;
    c.session.tabs = notes.map((o) => o.id).toList();
    c.session.activeId = notes.last.id;
    c.session.motion = 'off';
    c.session.spellCheckEnabled = false;
    addTearDown(() {
      c.cancelAllTimers();
      container.dispose();
    });
  }

  Future<void> render(WidgetTester tester, Widget widget, String name) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(key: key, child: widget),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: name);
    if (capture) {
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('.local/ergonomics-review').create(recursive: true);
        await File(
          '.local/ergonomics-review/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  }

  Widget page(Widget body) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: orbitDarkTheme(),
    home: Scaffold(body: body),
  );

  testWidgets(
    'crowded tabs keep the active document visible and overflow searchable',
    (tester) async {
      await fixture(tester);
      await render(tester, const OrbitNoteApp(), 'shell-note');
      expect(find.byKey(const ValueKey('tab-overflow-button')), findsOneWidget);
      expect(find.text(notes.last.title).hitTestable(), findsWidgets);
      await tester.pumpWidget(
        page(
          SizedBox(
            height: 48,
            child: OrbitTabStrip(
              controller: c,
              onActivate: c.openObject,
              onContextMenu: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('tab-overflow-button')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(
        find.widgetWithText(TextField, 'Search tabs'),
        'reference 3',
      );
      await tester.pump();
      expect(
        find.widgetWithText(ListTile, 'Design reference 3'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(ListTile, 'Design reference 3'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.session.activeId, notes[2].id);
      c.cancelAllTimers();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  testWidgets(
    'board cards stay readable, filters retain independent state and object identity',
    (tester) async {
      await fixture(tester);
      await render(
        tester,
        page(CollectionKanbanView(controller: c, viewObject: board)),
        'board',
      );
      expect(find.text(tasks.first.title), findsOneWidget);
      final text = tester.widget<Text>(find.text(tasks.first.title));
      expect(text.style!.fontSize, 14.5);
      expect(text.maxLines, 2);
      await tester.tap(find.text('Tasks only'));
      await tester.pump();
      await tester.tap(find.text('Hide empty columns'));
      await tester.pump();
      expect(c.find(board.id)!.properties['tasksOnly'], true);
      expect(c.find(board.id)!.properties['hideEmptyColumns'], true);
      expect(find.text('No Status'), findsNothing);
      expect(c.find(notes.first.id)!.isDeleted, false);
      c.cancelAllTimers();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  testWidgets(
    'working task, production dashboard, milestones and intentional empty timeline render',
    (tester) async {
      await fixture(tester);
      await render(
        tester,
        page(TaskDetail(object: tasks.first, controller: c)),
        'task-detail',
      );
      expect(find.text('Properties'), findsOneWidget);
      expect(find.text('Move to Trash').hitTestable(), findsNothing);
      await tester.tap(find.text('Properties'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Discipline'), findsOneWidget);
      await render(
        tester,
        page(
          GameDashboardView(
            controller: c,
            viewObject: board,
            scope: 'Afterglow',
          ),
        ),
        'dashboard',
      );
      await render(tester, page(TasksView(controller: c)), 'tasks');
      await render(
        tester,
        page(TasksView(controller: c, viewObject: board)),
        'tasks-board',
      );
      await render(
        tester,
        page(
          MilestoneView(controller: c, viewObject: board, scope: 'Afterglow'),
        ),
        'milestones',
      );
      await render(tester, page(TimelineView(controller: c)), 'timeline-empty');
      expect(find.text('Nothing scheduled yet'), findsOneWidget);
      expect(find.text('Add milestone / event'), findsOneWidget);
      c.cancelAllTimers();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  testWidgets(
    'project presets and Home render with realistic shared context',
    (tester) async {
      await fixture(tester);
      await render(
        tester,
        page(ProjectDashboardView(controller: c, projectName: 'Afterglow')),
        'coherence-project',
      );
      await render(
        tester,
        page(CourseDashboardView(controller: c, viewObject: board)),
        'coherence-course',
      );
      await render(
        tester,
        page(
          AnalysisDashboardView(
            controller: c,
            viewObject: board,
            scope: 'Afterglow',
          ),
        ),
        'coherence-research',
      );
      await render(tester, page(HomeView(controller: c)), 'coherence-home');
      c.cancelAllTimers();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  testWidgets(
    'tab overflow remains available at narrow width',
    (tester) async {
      await fixture(tester);
      tester.view.physicalSize = const Size(600, 600);
      await render(
        tester,
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: SizedBox(
              height: 48,
              child: OrbitTabStrip(
                controller: c,
                onActivate: c.openObject,
                onContextMenu: (_, _) {},
              ),
            ),
          ),
        ),
        'tabs-narrow',
      );
      expect(find.byKey(const ValueKey('tab-overflow-button')), findsOneWidget);
      expect(tester.takeException(), isNull);
      c.cancelAllTimers();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  testWidgets(
    'calendar workbench renders month and week planning views',
    (tester) async {
      await fixture(tester);
      final today = DateTime.now();
      await c.create(
        'orbit.event',
        title: 'Review combat prototype',
        properties: {
          'startDate':
              '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
          'endDate':
              '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${(today.day + 1).toString().padLeft(2, '0')}',
          'allDay': true,
        },
      );
      await c.flushAll();
      await render(tester, page(CalendarView(controller: c)), 'calendar-month');
      await tester.tap(find.text('Week'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('MON'), findsOneWidget);
      expect(find.text('Review combat prototype'), findsWidgets);
      c.cancelAllTimers();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
