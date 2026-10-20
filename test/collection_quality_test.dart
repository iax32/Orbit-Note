import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/domain/smart_view_query.dart';
import 'package:orbit_note/features/workspace/collection_table_view.dart';
import 'package:orbit_note/features/workspace/saved_view_host.dart';
import 'package:orbit_note/features/workspace/timeline_view.dart';
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
  late ProviderContainer container;
  late WorkspaceController c;
  setUp(() async {
    store = MemoryStore();
    repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    container.read(workspaceProvider);
    c = container.read(workspaceProvider.notifier);
    for (var i = 0; i < 100 && c.loading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  });
  tearDown(() async {
    store.writeGate = null;
    store.failWrites = false;
    await c.flushAll();
    c.cancelAllTimers();
    container.dispose();
  });
  Future<UniversalObject> add(
    WidgetTester tester,
    String type,
    String title, [
    Map<String, dynamic> properties = const {},
  ]) async => (await tester.runAsync(
    () => c.create(type, title: title, properties: properties),
  ))!;
  Future<void> host(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(1280, 900),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: orbitDarkTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget table(UniversalObject view) =>
      CollectionTableView(controller: c, viewObject: view);
  Finder dialogInput() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );

  testWidgets(
    'table sort saves both fields without overwriting newer view data',
    (tester) async {
      await add(tester, 'orbit.note', 'An item');
      final view = await add(tester, 'orbit.view', 'Table', {
        'viewType': 'table',
        'columns': ['title'],
        'future': {'keep': true},
      });
      await host(tester, table(view));
      c.updateProperty(view.id, 'newer', 'retained');
      await tester.tap(find.text('TITLE / NAME'));
      await tester.pump();
      expect(c.find(view.id)!.properties['sortOption'], 'title');
      expect(c.find(view.id)!.properties['sortAscending'], true);
      expect(c.find(view.id)!.properties['newer'], 'retained');
      expect(c.find(view.id)!.properties['future'], {'keep': true});
      c.cancelAllTimers();
    },
  );

  testWidgets(
    'adding a tag preserves concurrent tags and unrelated properties',
    (tester) async {
      final note = await add(tester, 'orbit.note', 'Evidence', {
        'tags': ['initial'],
      });
      final view = await add(tester, 'orbit.view', 'Table', {
        'viewType': 'table',
        'columns': ['title', 'tags'],
      });
      await host(tester, table(view));
      await tester.tap(find.byIcon(Icons.add).last);
      await tester.pumpAndSettle();
      c.edit(
        note.id,
        properties: {
          ...c.find(note.id)!.properties,
          'tags': ['initial', 'external'],
          'priority': 'high',
          'future': 42,
        },
      );
      await tester.enterText(dialogInput(), 'new');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(c.find(note.id)!.properties['tags'], [
        'initial',
        'external',
        'new',
      ]);
      expect(c.find(note.id)!.properties['priority'], 'high');
      expect(c.find(note.id)!.properties['future'], 42);
      c.cancelAllTimers();
    },
  );

  testWidgets('a competing rename keeps the later title and unapplied draft', (
    tester,
  ) async {
    final note = await add(tester, 'orbit.note', 'Original');
    final view = await add(tester, 'orbit.view', 'Table', {
      'viewType': 'table',
      'columns': ['title'],
    });
    await host(tester, table(view));
    await tester.tap(find.byTooltip('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(dialogInput(), 'My draft title');
    c.edit(note.id, title: 'Changed elsewhere');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(c.find(note.id)!.title, 'Changed elsewhere');
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      tester.widget<TextField>(dialogInput()).controller!.text,
      'My draft title',
    );
    c.cancelAllTimers();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('manual collection progress counts its members only', (
    tester,
  ) async {
    final member = await add(tester, 'orbit.task', 'Member', {
      'completed': false,
    });
    await add(tester, 'orbit.task', 'Foreign finished task', {
      'completed': true,
    });
    final view = await add(tester, 'orbit.view', 'Curated', {
      'viewType': 'table',
      'manual': true,
      'memberIds': [member.id],
      'columns': ['title'],
    });
    await host(tester, SavedViewHost(controller: c, viewObject: view));
    expect(find.text('0 / 1 complete · 0%'), findsOneWidget);
    expect(find.text('Foreign finished task'), findsNothing);
  });

  testWidgets('timeline respects manual membership across projects', (
    tester,
  ) async {
    final member = await add(tester, 'orbit.task', 'Member deadline', {
      'dueDate': '2026-10-18',
    });
    await add(tester, 'orbit.task', 'Foreign deadline', {
      'dueDate': '2026-10-18',
    });
    final view = await add(tester, 'orbit.view', 'Curated', {
      'viewType': 'timeline',
      'manual': true,
      'memberIds': [member.id],
    });
    await host(tester, TimelineView(controller: c, viewObject: view));
    expect(find.text('Member deadline'), findsOneWidget);
    expect(find.text('Foreign deadline'), findsNothing);
  });

  testWidgets('saved views preserve unsupported presentation settings', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 10, 18);
    for (final key in ['folder', 'scope', 'viewType', 'preset']) {
      final view = UniversalObject(
        id: 'unsupported-$key',
        workspaceId: repo.workspaceId,
        typeId: 'orbit.view',
        title: 'Imported view',
        createdAt: now,
        updatedAt: now,
        properties: {
          key: {'future': true},
        },
      );
      await host(tester, SavedViewHost(controller: c, viewObject: view));
      expect(find.text('Unsupported view settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(view.properties[key], {'future': true});
      expect(c.find(view.id), isNull);
    }
  });

  testWidgets('unsupported timelines explain failure without unrelated items', (
    tester,
  ) async {
    await add(tester, 'orbit.task', 'Unrelated deadline', {
      'dueDate': '2026-10-18',
    });
    final now = DateTime.utc(2026, 10, 18);
    for (final key in ['scope', 'memberIds']) {
      final view = UniversalObject(
        id: 'unsupported-$key',
        workspaceId: repo.workspaceId,
        typeId: 'orbit.view',
        title: 'Imported timeline',
        createdAt: now,
        updatedAt: now,
        properties: {key: 42},
      );
      await host(tester, TimelineView(controller: c, viewObject: view));
      expect(find.text('Unable to load this timeline'), findsOneWidget);
      expect(find.text('Unrelated deadline'), findsNothing);
      expect(find.text('Nothing scheduled yet'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(view.properties[key], 42);
    }
  });

  testWidgets(
    'imported scalar values and unknown columns retain a usable table',
    (tester) async {
      await add(tester, 'orbit.note', 'Imported item', {
        'status': '',
        'tags': ['valid'],
      });
      final view = await add(tester, 'orbit.view', 'Imported', {
        'viewType': 'table',
        'columns': ['future-column'],
        'sortOption': 7,
        'sortAscending': 'future',
      });
      await host(tester, table(view));
      expect(tester.takeException(), isNull);
      expect(find.text('Imported item'), findsOneWidget);
      expect(c.find(view.id)!.properties['columns'], ['future-column']);
    },
  );

  test(
    'manual collections without members are empty, including future metadata',
    () {
      final now = DateTime.utc(2026, 10, 18);
      final item = UniversalObject(
        id: 'item',
        workspaceId: 'test',
        typeId: 'orbit.note',
        title: 'Unrelated',
        createdAt: now,
        updatedAt: now,
      );
      final view = item.copyWith(
        properties: {
          'manual': true,
          'future': {'keep': 1},
        },
      );
      expect(resolveSmartView(view, [item]), isEmpty);
      expect(view.properties['future'], {'keep': 1});
    },
  );

  test(
    'large manual collections resolve missing and duplicate IDs without copies',
    () {
      final now = DateTime.utc(2026, 10, 18);
      final objects = List.generate(
        10000,
        (i) => UniversalObject(
          id: 'item-$i',
          workspaceId: 'test',
          typeId: 'orbit.note',
          title: 'Item $i',
          createdAt: now,
          updatedAt: now,
          properties: {'project': 'p-${i % 50}'},
        ),
      );
      final ids = [
        'missing',
        for (var i = 0; i < 10000; i += 2) 'item-$i',
        'item-2',
      ];
      final view = objects.first.copyWith(
        properties: {'manual': true, 'memberIds': ids},
      );
      final watch = Stopwatch()..start();
      final result = resolveSmartView(view, objects);
      watch.stop();
      expect(result.length, 5000);
      expect(result.map((o) => o.id).toSet().length, 5000);
      expect(result.last, same(objects[9998]));
      // Record the fixture, without imposing a hardware-dependent timing promise.
      debugPrint(
        'Manual collection: 10,000 objects / ${ids.length} membership entries / ${watch.elapsedMilliseconds} ms',
      );
    },
  );

  test(
    'unsupported membership refuses an unscoped fallback and preserves data',
    () {
      final now = DateTime.utc(2026, 10, 18);
      final item = UniversalObject(
        id: 'item',
        workspaceId: 'test',
        typeId: 'orbit.note',
        title: 'Item',
        createdAt: now,
        updatedAt: now,
      );
      for (final raw in [
        'future format',
        {'version': 2, 'future': true},
      ]) {
        final view = item.copyWith(properties: {'memberIds': raw});
        expect(() => resolveSmartView(view, [item]), throwsFormatException);
        expect(view.properties['memberIds'], raw);
      }
    },
  );

  test(
    'scoped query caches stay independent and refresh after object changes',
    () async {
      final a = (await c.create(
        'orbit.note',
        title: 'A',
        properties: {'folder': 'Alpha'},
      ))!;
      final b = (await c.create(
        'orbit.note',
        title: 'B',
        properties: {'folder': 'Beta'},
      ))!;
      final view = (await c.create('orbit.view', title: 'Shared'))!;
      final alpha = c.queryViewObjects(view, folderFilter: 'Alpha');
      expect(alpha.map((o) => o.id), [a.id]);
      expect(c.queryViewObjects(view, folderFilter: 'Beta').map((o) => o.id), [
        b.id,
      ]);
      expect(c.queryViewObjects(view, folderFilter: 'Alpha'), same(alpha));
      c.edit(a.id, title: 'A revised');
      expect(
        c.queryViewObjects(view, folderFilter: 'Alpha').single.title,
        'A revised',
      );
    },
  );

  testWidgets('pending creation attaches to its original manual collection', (
    tester,
  ) async {
    final a = await add(tester, 'orbit.view', 'A', {
      'manual': true,
      'memberIds': [],
      'columns': ['title'],
    });
    final b = await add(tester, 'orbit.view', 'B', {
      'manual': true,
      'memberIds': [],
      'columns': ['title'],
    });
    await host(tester, table(a));
    final addMenu = tester.widget<PopupMenuButton<String>>(
      find.byWidgetPredicate(
        (w) => w is PopupMenuButton<String> && w.tooltip == 'Add to Collection',
      ),
    );
    final gate = Completer<void>();
    store.writeGate = gate.future;
    await tester.runAsync(() async {
      addMenu.onSelected!('orbit.note');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await host(tester, table(b));
    await tester.runAsync(() async {
      gate.complete();
      store.writeGate = null;
      for (
        var i = 0;
        i < 500 && !c.objects.any((o) => o.title == 'Untitled Note');
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.pumpAndSettle();
    final created = c.objects.singleWhere((o) => o.title == 'Untitled Note');
    expect(c.find(a.id)!.properties['memberIds'], contains(created.id));
    expect(c.find(b.id)!.properties['memberIds'], isEmpty);
    expect(tester.takeException(), isNull);
    c.cancelAllTimers();
  });

  testWidgets('a tag dialog cannot resurrect a removed source', (tester) async {
    final note = await add(tester, 'orbit.note', 'Evidence');
    final view = await add(tester, 'orbit.view', 'Table', {
      'columns': ['title', 'tags'],
    });
    await host(tester, table(view));
    await tester.tap(find.byKey(ValueKey('collection-add-tag-${note.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(dialogInput(), 'Retain my draft');
    await tester.runAsync(() => c.trash(note.id));
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(c.find(note.id)!.isDeleted, true);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      tester.widget<TextField>(dialogInput()).controller!.text,
      'Retain my draft',
    );
    c.cancelAllTimers();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'a column menu from another collection cannot change the new view',
    (tester) async {
      final a = await add(tester, 'orbit.view', 'A', {
        'columns': ['title'],
      });
      final b = await add(tester, 'orbit.view', 'B', {
        'columns': ['title'],
      });
      await host(tester, table(a));
      await tester.tap(find.byTooltip('Customize Columns'));
      await tester.pumpAndSettle();
      await host(tester, table(b));
      await tester.tap(
        find.ancestor(
          of: find.text('Tags'),
          matching: find.byType(CheckedPopupMenuItem<String>),
        ),
      );
      await tester.pumpAndSettle();
      expect(c.find(a.id)!.properties['columns'], ['title']);
      expect(c.find(b.id)!.properties['columns'], ['title']);
      c.cancelAllTimers();
    },
  );

  testWidgets('read-only collection controls expose no editing actions', (
    tester,
  ) async {
    final note = await add(tester, 'orbit.note', 'Member');
    final now = DateTime.now();
    final view = UniversalObject(
      id: 'future-view',
      workspaceId: repo.workspaceId,
      typeId: 'orbit.view',
      title: 'Future definition',
      schemaVersion: 2,
      createdAt: now,
      updatedAt: now,
      properties: {
        'manual': true,
        'memberIds': [note.id],
      },
    );
    await host(tester, table(view));
    final addMenu = tester.widget<PopupMenuButton<String>>(
      find.byWidgetPredicate(
        (w) => w is PopupMenuButton<String> && w.tooltip == 'Add to Collection',
      ),
    );
    expect(addMenu.enabled, false);
    final rename = tester.widget<IconButton>(
      find.byWidgetPredicate((w) => w is IconButton && w.tooltip == 'Rename'),
    );
    expect(rename.onPressed, isNull);
    expect(c.find(note.id)!.title, 'Member');
  });

  testWidgets(
    'large text and long project paths remain usable in a narrow table',
    (tester) async {
      await prepareCapture(tester);
      final folder = List.filled(12, 'Research').join('/');
      final note = await add(tester, 'orbit.note', 'Detailed evidence', {
        'folder': folder,
        'tags': [List.filled(240, 'x').join()],
      });
      final view = await add(tester, 'orbit.view', 'Research table', {
        'folder': note.properties['folder'],
      });
      await host(tester, table(view), size: const Size(390, 844), scale: 2);
      await tester.ensureVisible(
        find.byKey(ValueKey('collection-add-tag-${note.id}')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await captureUi(tester, 'collection-large-text');
    },
  );

  testWidgets(
    'large tables mount a bounded row set and search the last record',
    (tester) async {
      await tester.runAsync(() async {
        for (var i = 0; i < 160; i++) {
          await c.create(
            'orbit.note',
            title: 'Item ${i.toString().padLeft(3, '0')}',
          );
        }
      });
      final view = await add(tester, 'orbit.view', 'Large table', {
        'columns': ['title'],
      });
      await host(tester, table(view));
      final rows = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('collection-row-'),
      );
      expect(rows.evaluate().length, lessThan(80));
      expect(find.text('Item 159'), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'Item 159');
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: rows, matching: find.text('Item 159')),
        findsOneWidget,
      );
      expect(rows, findsOneWidget);
      c.cancelAllTimers();
    },
  );

  testWidgets('failed folder moves keep their draft and original source path', (
    tester,
  ) async {
    final note = await add(tester, 'orbit.note', 'Owned source');
    final view = await add(tester, 'orbit.view', 'Table', {
      'columns': ['title', 'folder'],
    });
    final before = repo.objectPath(note.id);
    await host(tester, table(view));
    await tester.tap(find.byKey(ValueKey('collection-folder-${note.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(dialogInput(), '../outside');
    await tester.runAsync(() async {
      final submit = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Move'))
          .onPressed!;
      await Function.apply(submit, const []);
    });
    await tester.pumpAndSettle();
    expect(repo.objectPath(note.id), before);
    expect(
      tester.widget<TextField>(dialogInput()).controller!.text,
      '../outside',
    );
    expect(
      tester.widget<TextField>(dialogInput()).decoration!.errorText,
      isNotNull,
    );
    c.cancelAllTimers();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'folder edits move durable files and preserve metadata after reopen',
    (tester) async {
      late Directory root;
      late WorkspaceRepository native;
      late ProviderContainer owner;
      late WorkspaceController nc;
      late UniversalObject note, view;
      var ownerDisposed = false;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp(
          'orbit-collection-quality-',
        );
        native = WorkspaceRepository(
          store: _IsolatedStore(root.path),
          index: MemoryObjectIndex(),
        );
        owner = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(native)],
        );
        owner.read(workspaceProvider);
        nc = owner.read(workspaceProvider.notifier);
        for (var i = 0; i < 500 && nc.loading; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        await native.createFolder('Notes/Research');
        note = (await nc.create(
          'orbit.note',
          title: 'Durable evidence',
          body: '# Keep this source',
          properties: {
            'future': {'keep': true},
          },
        ))!;
        view = (await nc.create(
          'orbit.view',
          title: 'Table',
          properties: {
            'columns': ['title', 'folder'],
          },
        ))!;
      });
      try {
        final before = native.objectPath(note.id)!;
        await host(
          tester,
          CollectionTableView(controller: nc, viewObject: view),
        );
        await tester.tap(find.byKey(ValueKey('collection-folder-${note.id}')));
        await tester.pumpAndSettle();
        await tester.enterText(dialogInput(), 'Research');
        await tester.runAsync(() async {
          final submit = tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, 'Move'))
              .onPressed!;
          await Function.apply(submit, const []);
        });
        await tester.pumpAndSettle();
        expect(native.objectPath(note.id), startsWith('Notes/Research/'));
        expect(
          await tester.runAsync(() => File('${root.path}/$before').exists()),
          false,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() async {
          await nc.flushAll();
          nc.cancelAllTimers();
          owner.dispose();
          ownerDisposed = true;
          await native.close();
          await native.initialize(path: root.path);
          final restored = native.objects.singleWhere((o) => o.id == note.id);
          expect(restored.body, '# Keep this source');
          expect(restored.properties['future'], {'keep': true});
          expect(native.objectPath(note.id), startsWith('Notes/Research/'));
        });
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() async {
          nc.cancelAllTimers();
          if (!ownerDisposed) owner.dispose();
          await native.close();
          expect(
            root.absolute.path.startsWith(Directory.systemTemp.absolute.path),
            true,
          );
          await root.delete(recursive: true);
        });
      }
    },
  );
}
