import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/workspace/collection_kanban_view.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'support/memory_store.dart';
import 'support/capture_ui.dart';

class _IsolatedStore extends NativeWorkspaceStore {
  _IsolatedStore(this.root);
  final String root;
  @override
  Future<void> initialize({String? path}) => super.initialize(path: root);
}

void main() {
  late MemoryStore store;
  late WorkspaceRepository repo;
  late ProviderContainer owner;
  late WorkspaceController c;
  setUp(() async {
    store = MemoryStore();
    repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
    owner = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    owner.read(workspaceProvider);
    c = owner.read(workspaceProvider.notifier);
    for (var i = 0; i < 100 && c.loading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  });
  tearDown(() async {
    store.failWrites = false;
    store.writeGate = null;
    await c.flushAll();
    c.cancelAllTimers();
    owner.dispose();
  });
  Future<UniversalObject> add(
    WidgetTester t,
    String type,
    String title, [
    Map<String, dynamic> properties = const {},
  ]) async => (await t.runAsync(
    () => c.create(type, title: title, properties: properties),
  ))!;
  Future<void> host(
    WidgetTester t,
    UniversalObject view, {
    Size size = const Size(1400, 850),
    double scale = 1,
    WorkspaceController? controller,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: orbitDarkTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: CollectionKanbanView(
            controller: controller ?? c,
            viewObject: view,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  DragTarget<String> target(WidgetTester t, String label) => t.widget(
    find
        .ancestor(
          of: find.text(label),
          matching: find.byType(DragTarget<String>),
        )
        .first,
  );
  Future<void> drop(WidgetTester t, String label, String id) async {
    final callback = target(t, label).onAcceptWithDetails!;
    await t.runAsync(() async {
      await Function.apply(callback, [
        DragTargetDetails<String>(data: id, offset: Offset.zero),
      ]);
    });
    await t.pumpAndSettle();
  }

  testWidgets('a project named none stays separate from unassigned cards', (
    t,
  ) async {
    await add(t, 'orbit.note', 'Named project', {'project': 'none'});
    await add(t, 'orbit.note', 'Unassigned source');
    final view = await add(t, 'orbit.view', 'Board', {'groupBy': 'project'});
    await host(t, view);
    final named = find.ancestor(
      of: find.text('none'),
      matching: find.byType(DragTarget<String>),
    );
    expect(
      find.descendant(of: named, matching: find.text('Named project')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: named, matching: find.text('Unassigned source')),
      findsNothing,
    );
    expect(find.text('Named project'), findsOneWidget);
  });

  testWidgets('failed inline creation retains the title for retry', (t) async {
    final view = await add(t, 'orbit.view', 'Board');
    await host(t, view);
    await t.tap(find.byTooltip('Add item to Backlog'));
    await t.pumpAndSettle();
    await t.enterText(
      find.widgetWithText(TextField, 'Enter title...'),
      'Keep my draft',
    );
    store.failWrites = true;
    await t.runAsync(() async {
      final submit = t
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add'))
          .onPressed!;
      await Function.apply(submit, const []);
    });
    await t.pumpAndSettle();
    expect(find.text('Keep my draft'), findsOneWidget);
    expect(c.objects.where((o) => o.title == 'Keep my draft'), isEmpty);
    store.failWrites = false;
  });

  testWidgets('old completion controls preserve newer properties', (t) async {
    final task = await add(t, 'orbit.task', 'Work', {'status': 'backlog'});
    final view = await add(t, 'orbit.view', 'Board');
    await host(t, view);
    final checkbox = t.widget<Checkbox>(find.byType(Checkbox));
    c.updateProperty(task.id, 'newer', {'keep': true});
    checkbox.onChanged!(true);
    expect(c.find(task.id)!.properties['newer'], {'keep': true});
    expect(c.find(task.id)!.isCompleted, true);
    c.cancelAllTimers();
  });

  testWidgets('old drag targets cannot edit a newly selected board', (t) async {
    final task = await add(t, 'orbit.task', 'Work', {
      'status': 'backlog',
      'priority': 'low',
    });
    final a = await add(t, 'orbit.view', 'A');
    final b = await add(t, 'orbit.view', 'B', {'groupBy': 'priority'});
    await host(t, a);
    final oldTarget = target(t, 'Done');
    await host(t, b);
    oldTarget.onAcceptWithDetails!(
      DragTargetDetails<String>(data: task.id, offset: Offset.zero),
    );
    expect(c.find(task.id)!.properties['status'], 'backlog');
    expect(c.find(task.id)!.properties['priority'], 'low');
    expect(find.text('No Priority'), findsOneWidget);
    c.cancelAllTimers();
  });

  testWidgets('drops reject objects outside manual membership', (t) async {
    final member = await add(t, 'orbit.task', 'Member', {'status': 'backlog'});
    final foreign = await add(t, 'orbit.task', 'Foreign', {
      'status': 'backlog',
    });
    final view = await add(t, 'orbit.view', 'Board', {
      'manual': true,
      'memberIds': [member.id],
    });
    await host(t, view);
    await drop(t, 'Done', foreign.id);
    expect(c.find(foreign.id)!.properties['status'], 'backlog');
    c.cancelAllTimers();
  });

  testWidgets('read-only definitions disable add drag and completion', (
    t,
  ) async {
    final task = await add(t, 'orbit.task', 'Member', {'status': 'backlog'});
    final now = DateTime.utc(2026, 10, 19);
    final view = UniversalObject(
      id: 'readonly',
      workspaceId: repo.workspaceId,
      typeId: 'orbit.view',
      title: 'Future',
      createdAt: now,
      updatedAt: now,
      schemaVersion: 2,
    );
    await host(t, view);
    expect(t.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    final done = target(t, 'Done');
    expect(
      done.onWillAcceptWithDetails!(
        DragTargetDetails<String>(data: task.id, offset: Offset.zero),
      ),
      false,
    );
    expect(
      t
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Add item to Backlog',
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('unknown grouping and preset remain preserved and readable', (
    t,
  ) async {
    for (final property in ['groupBy', 'preset']) {
      final view = await add(t, 'orbit.view', 'Future board', {
        property: 'future-value',
      });
      await host(t, view);
      expect(t.takeException(), isNull);
      expect(find.text('Unsupported board settings'), findsOneWidget);
      expect(c.find(view.id)!.properties[property], 'future-value');
    }
  });

  testWidgets('a folder named root stays separate from unfiled sources', (
    t,
  ) async {
    await add(t, 'orbit.note', 'Named folder', {'folder': 'root'});
    await add(t, 'orbit.note', 'Unfiled source');
    final view = await add(t, 'orbit.view', 'Folders', {'groupBy': 'folder'});
    await host(t, view);
    final root = find.ancestor(
      of: find.text('root'),
      matching: find.byType(DragTarget<String>),
    );
    expect(
      find.descendant(of: root, matching: find.text('Named folder')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: root, matching: find.text('Unfiled source')),
      findsNothing,
    );
  });

  testWidgets(
    'pending add is single-submit and merges original membership after switching',
    (t) async {
      final a = await add(t, 'orbit.view', 'A', {
        'manual': true,
        'memberIds': [],
      });
      final b = await add(t, 'orbit.view', 'B', {
        'groupBy': 'priority',
        'manual': true,
        'memberIds': [],
      });
      final member = await add(t, 'orbit.note', 'Concurrent member');
      await host(t, a);
      await t.tap(find.byTooltip('Add item to Backlog'));
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextField, 'Enter title...'),
        'Pending task',
      );
      final submit = t
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add'))
          .onPressed!;
      final gate = Completer<void>();
      store.writeGate = gate.future;
      Future<dynamic>? operation;
      try {
        await t.runAsync(() async {
          operation = Function.apply(submit, const []) as Future<dynamic>;
          Function.apply(submit, const []);
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });
        c.updateProperty(a.id, 'memberIds', [
          member.id,
          {'future': true},
        ]);
        await host(t, b);
      } finally {
        store.writeGate = null;
        gate.complete();
        await t.runAsync(() async => await operation);
      }
      await t.pumpAndSettle();
      final created = c.objects.singleWhere((o) => o.title == 'Pending task');
      expect(c.find(a.id)!.properties['memberIds'], [
        member.id,
        {'future': true},
        created.id,
      ]);
      expect(c.find(b.id)!.properties['memberIds'], isEmpty);
      expect(created.properties['status'], 'backlog');
      expect(t.takeException(), isNull);
      c.cancelAllTimers();
    },
  );

  testWidgets(
    'completion from a departed board and trashed sources are inert',
    (t) async {
      final task = await add(t, 'orbit.task', 'Shared task', {
        'status': 'backlog',
      });
      final a = await add(t, 'orbit.view', 'A');
      final b = await add(t, 'orbit.view', 'B');
      await host(t, a);
      final old = t.widget<Checkbox>(find.byType(Checkbox)).onChanged!;
      await host(t, b);
      old(true);
      expect(c.find(task.id)!.isCompleted, false);
      final done = target(t, 'Done');
      await t.runAsync(() => c.trash(task.id));
      done.onAcceptWithDetails!(
        DragTargetDetails<String>(data: task.id, offset: Offset.zero),
      );
      expect(c.find(task.id)!.isDeleted, true);
      expect(c.find(task.id)!.isCompleted, false);
      c.cancelAllTimers();
    },
  );

  testWidgets('old option callbacks cannot rewrite another board', (t) async {
    final a = await add(t, 'orbit.view', 'A');
    final b = await add(t, 'orbit.view', 'B', {
      'groupBy': 'priority',
      'future': 42,
    });
    await host(t, a);
    final old = t
        .widget<DropdownButton<String>>(
          find.byType(DropdownButton<String>).first,
        )
        .onChanged!;
    await host(t, b);
    old('folder');
    expect(c.find(b.id)!.properties['groupBy'], 'priority');
    expect(c.find(b.id)!.properties['future'], 42);
  });

  testWidgets(
    'manual membership takes precedence over course-derived membership',
    (t) async {
      final course = await add(t, 'orbit.note', 'Course');
      final member = await add(t, 'orbit.note', 'Curated evidence', {
        'project': 'Other',
      });
      final view = await add(t, 'orbit.view', 'Manual course evidence', {
        'courseId': course.id,
        'manual': true,
        'memberIds': [member.id],
      });
      await host(t, view);
      expect(find.text('Curated evidence'), findsOneWidget);
      expect(find.text('Course'), findsNothing);
    },
  );

  testWidgets('same-column drops avoid unnecessary saves', (t) async {
    final task = await add(t, 'orbit.task', 'Work', {
      'status': 'backlog',
      'completed': false,
    });
    final view = await add(t, 'orbit.view', 'Board');
    await host(t, view);
    await drop(t, 'Backlog', task.id);
    expect(c.find(task.id), same(task));
    expect(c.dirty.contains(task.id), false);
  });

  testWidgets('many project columns and cards are lazy and remain searchable', (
    t,
  ) async {
    await t.runAsync(() async {
      for (var i = 0; i < 180; i++) {
        await c.create(
          'orbit.note',
          title: 'Evidence $i',
          properties: {'project': 'Project $i'},
        );
      }
    });
    final view = await add(t, 'orbit.view', 'Large board', {
      'groupBy': 'project',
    });
    await host(t, view);
    expect(find.byType(DragTarget<String>).evaluate().length, lessThan(15));
    expect(find.text('Evidence 179'), findsNothing);
    await t.enterText(find.byType(TextField), 'Evidence 179');
    await t.pumpAndSettle();
    expect(
      find.byKey(
        ValueKey(
          'board-card-${c.objects.singleWhere((o) => o.title == 'Evidence 179').id}',
        ),
      ),
      findsOneWidget,
    );
    c.cancelAllTimers();
  });

  testWidgets(
    'narrow enlarged-text board previews remain reachable and close with Escape',
    (t) async {
      await prepareCapture(t);
      await add(t, 'orbit.note', 'Long evidence title', {
        'status': 'backlog',
        'folder': List.filled(12, 'Research').join('/'),
        'tags': [List.filled(240, 'x').join()],
      });
      final view = await add(t, 'orbit.view', 'Board');
      await host(t, view, size: const Size(390, 844), scale: 2);
      await t.tap(find.byTooltip('Task details').first);
      await t.pumpAndSettle();
      expect(find.text('Card Preview'), findsOneWidget);
      expect(t.takeException(), isNull);
      await captureUi(t, 'kanban-narrow-preview');
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.text('Card Preview'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('a failed title retries once without clearing the draft early', (
    t,
  ) async {
    final view = await add(t, 'orbit.view', 'Board');
    await host(t, view);
    await t.tap(find.byTooltip('Add item to Backlog'));
    await t.pumpAndSettle();
    await t.enterText(
      find.widgetWithText(TextField, 'Enter title...'),
      'Retry this task',
    );
    for (final failed in [true, false]) {
      store.failWrites = failed;
      await t.runAsync(() async {
        final callback = t
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add'))
            .onPressed!;
        await Function.apply(callback, const []);
      });
      await t.pumpAndSettle();
      if (failed) {
        expect(
          t
              .widget<TextField>(
                find.widgetWithText(TextField, 'Enter title...'),
              )
              .controller!
              .text,
          'Retry this task',
        );
      }
    }
    expect(c.objects.where((o) => o.title == 'Retry this task'), hasLength(1));
    expect(find.widgetWithText(TextField, 'Enter title...'), findsNothing);
    c.cancelAllTimers();
  });

  testWidgets(
    'external regrouping retains a title and requires a new column choice',
    (t) async {
      final view = await add(t, 'orbit.view', 'Board');
      await host(t, view);
      await t.tap(find.byTooltip('Add item to Backlog'));
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextField, 'Enter title...'),
        'Retained title',
      );
      c.updateProperty(view.id, 'groupBy', 'priority');
      c.cancelAllTimers();
      await host(t, c.find(view.id)!);
      expect(find.widgetWithText(TextField, 'Enter title...'), findsNothing);
      expect(find.textContaining('Your title is retained'), findsOneWidget);
      await t.ensureVisible(find.byTooltip('Add item to 🔴 Urgent'));
      await t.tap(find.byTooltip('Add item to 🔴 Urgent'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<TextField>(find.widgetWithText(TextField, 'Enter title...'))
            .controller!
            .text,
        'Retained title',
      );
      expect(c.objects.where((o) => o.title == 'Retained title'), isEmpty);
      c.cancelAllTimers();
    },
  );

  testWidgets('departed inline callbacks cannot submit another board draft', (
    t,
  ) async {
    final a = await add(t, 'orbit.view', 'A');
    final b = await add(t, 'orbit.view', 'B');
    await host(t, a);
    await t.tap(find.byTooltip('Add item to Backlog'));
    await t.pumpAndSettle();
    final oldSubmit = t
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add'))
        .onPressed!;
    final oldKeyboard = t
        .widget<TextField>(find.widgetWithText(TextField, 'Enter title...'))
        .onSubmitted!;
    await host(t, b);
    await t.tap(find.byTooltip('Add item to Backlog'));
    await t.pumpAndSettle();
    await t.enterText(
      find.widgetWithText(TextField, 'Enter title...'),
      'B live draft',
    );
    await t.runAsync(() async {
      await Function.apply(oldSubmit, const []);
    });
    oldKeyboard('B live draft');
    await t.pumpAndSettle();
    expect(c.objects.where((o) => o.title == 'B live draft'), isEmpty);
    expect(
      t
          .widget<TextField>(find.widgetWithText(TextField, 'Enter title...'))
          .controller!
          .text,
      'B live draft',
    );
    await t.pumpWidget(const SizedBox());
    await t.runAsync(() async {
      await Function.apply(oldSubmit, const []);
    });
    expect(t.takeException(), isNull);
    c.cancelAllTimers();
  });

  testWidgets('Other creation does not manufacture an unrelated task', (
    t,
  ) async {
    final view = await add(t, 'orbit.view', 'Types', {'groupBy': 'type'});
    await host(t, view);
    final button = t.widget<IconButton>(
      find.byWidgetPredicate(
        (w) =>
            w is IconButton &&
            (w.tooltip?.contains('Use New or Import') ?? false),
      ),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Other'), findsOneWidget);
    expect(c.objects.where((o) => o.typeId == 'orbit.task'), isEmpty);
  });

  testWidgets('Tasks only cannot create a hidden note or board', (t) async {
    final view = await add(t, 'orbit.view', 'Types', {
      'groupBy': 'type',
      'tasksOnly': true,
    });
    await host(t, view);
    final buttons = t.widgetList<IconButton>(
      find.byWidgetPredicate(
        (w) =>
            w is IconButton &&
            w.tooltip == 'Turn off Tasks only to create this type',
      ),
    );
    expect(buttons, hasLength(2));
    expect(buttons.every((b) => b.onPressed == null), true);
    expect(
      t
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Add item to Tasks',
            ),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'folder drops move durable files and preserve source after reopen',
    (t) async {
      late Directory root;
      late WorkspaceRepository native;
      late ProviderContainer nativeOwner;
      late WorkspaceController nc;
      late UniversalObject a, b, view;
      var disposed = false;
      await t.runAsync(() async {
        root = await Directory.systemTemp.createTemp('orbit-kanban-quality-');
        native = WorkspaceRepository(
          store: _IsolatedStore(root.path),
          index: MemoryObjectIndex(),
        );
        nativeOwner = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(native)],
        );
        nativeOwner.read(workspaceProvider);
        nc = nativeOwner.read(workspaceProvider.notifier);
        for (var i = 0; i < 500 && nc.loading; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        await native.createFolder('Notes/Alpha');
        await native.createFolder('Notes/Beta');
        a = (await nc.create(
          'orbit.note',
          title: 'Owned A',
          body: '# Keep source',
          properties: {'folder': 'Alpha', 'future': 42},
        ))!;
        b = (await nc.create(
          'orbit.note',
          title: 'Owned B',
          properties: {'folder': 'Beta'},
        ))!;
        view = (await nc.create(
          'orbit.view',
          title: 'Folders',
          properties: {'groupBy': 'folder'},
        ))!;
      });
      try {
        final before = native.objectPath(a.id)!;
        await host(t, view, controller: nc);
        await drop(t, b.properties['folder'] as String, a.id);
        expect(native.objectPath(a.id), startsWith('Notes/Beta/'));
        expect(
          await t.runAsync(() => File('${root.path}/$before').exists()),
          false,
        );
        await t.pumpWidget(const SizedBox());
        await t.runAsync(() async {
          await nc.flushAll();
          nc.cancelAllTimers();
          nativeOwner.dispose();
          disposed = true;
          await native.close();
          await native.initialize(path: root.path);
          final restored = native.objects.singleWhere((o) => o.id == a.id);
          expect(restored.body, '# Keep source');
          expect(restored.properties['future'], 42);
          expect(native.objectPath(a.id), startsWith('Notes/Beta/'));
        });
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.runAsync(() async {
          nc.cancelAllTimers();
          if (!disposed) nativeOwner.dispose();
          await native.close();
          expect(
            root.absolute.path.startsWith(
              '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}',
            ),
            true,
          );
          await root.delete(recursive: true);
        });
      }
    },
  );
}
