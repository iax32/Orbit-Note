import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/workspace/folder_color_dialog.dart';
import 'package:orbit_note/features/workspace/note_folder_explorer.dart';
import 'package:orbit_note/features/workspace/object_inspector.dart';
import 'package:orbit_note/features/workspace/orbit_explorer_row.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

Future<(WorkspaceController, UniversalObject)> fixture(WidgetTester t) async {
  t.view.physicalSize = const Size(1100, 850);
  t.view.devicePixelRatio = 1;
  final repo = WorkspaceRepository(
    store: FolderMemoryStore(),
    index: MemoryObjectIndex(),
  );
  final container = ProviderContainer(
    overrides: [repositoryProvider.overrideWithValue(repo)],
  );
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              ref.watch(workspaceProvider);
              final c = ref.read(workspaceProvider.notifier);
              return Row(
                children: [
                  Expanded(
                    child: NoteFolderExplorer(
                      controller: c,
                      notes: c.activeObjects.toList(),
                    ),
                  ),
                  SizedBox(
                    width: 390,
                    child: ObjectInspector(controller: c, onRename: (_) {}),
                  ),
                ],
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
  final note = (await c.create(
    'orbit.note',
    title: 'Original title',
    properties: {
      'summary': 'Original summary',
      'score': 10,
      'future': {'keep': 1},
    },
  ))!;
  await t.pumpAndSettle();
  addTearDown(() async {
    c.cancelAllTimers();
    await t.pumpWidget(const SizedBox());
    container.dispose();
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  });
  return (c, note);
}

void main() {
  testWidgets(
    'Explorer color preserves properties edited while picker is open',
    (t) async {
      final (c, note) = await fixture(t);
      final row = t.widget<OrbitExplorerRow>(
        find.byKey(ValueKey('folder-note:${note.id}')),
      );
      row.menu.onSelected!('set_note_color');
      await t.pumpAndSettle();
      c.updateProperty(note.id, 'future', {'keep': 2});
      await t.tap(find.byKey(const ValueKey('folder-color-swatch-violet')));
      await t.tap(find.byKey(const ValueKey('folder-color-apply-button')));
      await t.pumpAndSettle();
      c.cancelAllTimers();
      expect(c.find(note.id)!.properties['future'], {'keep': 2});
      expect(c.find(note.id)!.properties['color'], 0xff8b7cf6);
    },
  );

  testWidgets(
    'Inspector refuses a stale string edit and keeps its draft visible',
    (t) async {
      final (c, note) = await fixture(t);
      await t.tap(find.text('Original summary'));
      await t.pumpAndSettle();
      await t.enterText(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextFormField),
        ),
        'My pending summary',
      );
      c.updateProperty(note.id, 'summary', 'Newer summary');
      await t.tap(find.widgetWithText(FilledButton, 'Save'));
      await t.pumpAndSettle();
      c.cancelAllTimers();
      expect(c.find(note.id)!.properties['summary'], 'Newer summary');
      expect(find.text('My pending summary'), findsOneWidget);
    },
  );

  testWidgets('Inspector rejects nonfinite numeric input before autosave', (
    t,
  ) async {
    final (c, note) = await fixture(t);
    await t.tap(find.text('10'));
    await t.pumpAndSettle();
    await t.enterText(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextFormField),
      ),
      'NaN',
    );
    await t.tap(find.widgetWithText(FilledButton, 'Save'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(c.find(note.id)!.properties['score'], 10);
    expect(find.byType(Dialog), findsOneWidget);
  });

  testWidgets('Explorer rename cannot overwrite a title changed during entry', (
    t,
  ) async {
    final (c, note) = await fixture(t);
    final row = t.widget<OrbitExplorerRow>(
      find.byKey(ValueKey('folder-note:${note.id}')),
    );
    row.menu.onSelected!('rename');
    await t.pumpAndSettle();
    await t.enterText(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(EditableText),
      ),
      'Pending title',
    );
    c.edit(note.id, title: 'Newer title');
    await t.tap(find.byType(FilledButton).last);
    await t.pumpAndSettle();
    expect(c.find(note.id)!.title, 'Newer title');
    expect(find.text('Pending title'), findsOneWidget);
    // A retained draft deliberately keeps the route pending on conflict.
    if (find.byType(Dialog).evaluate().isNotEmpty) {
      await t.tap(find.widgetWithText(TextButton, 'Cancel'));
      await t.pumpAndSettle();
    }
  });

  testWidgets(
    'color conflict keeps the selected draft and newer legacy accent',
    (t) async {
      final (c, note) = await fixture(t);
      t
          .widget<OrbitExplorerRow>(
            find.byKey(ValueKey('folder-note:${note.id}')),
          )
          .menu
          .onSelected!('set_note_color');
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('folder-color-swatch-violet')));
      c.updateProperty(note.id, 'accent', '#ff0000');
      await t.tap(find.byKey(const ValueKey('folder-color-apply-button')));
      await t.pumpAndSettle();
      c.cancelAllTimers();
      expect(c.find(note.id)!.properties['accent'], '#ff0000');
      expect(c.find(note.id)!.properties.containsKey('color'), isFalse);
      expect(find.byKey(const ValueKey('folder-color-dialog')), findsOneWidget);
      expect(
        find.textContaining('Your color choice is retained'),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('folder-color-cancel-button')));
      await t.pumpAndSettle();
    },
  );

  testWidgets('retained property Save cannot edit after inspector disposal', (
    t,
  ) async {
    final (c, note) = await fixture(t);
    await t.tap(find.text('Original summary'));
    await t.pumpAndSettle();
    await t.enterText(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextFormField),
      ),
      'Retired',
    );
    final save = t
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
        .onPressed!;
    await t.pumpWidget(const SizedBox());
    save();
    c.cancelAllTimers();
    expect(t.takeException(), isNull);
    expect(c.find(note.id)!.properties['summary'], 'Original summary');
  });

  for (final note in [false, true]) {
    testWidgets(
      'color controls fit 360px/200% text with keyboard; note=$note',
      (t) async {
        t.view.physicalSize = const Size(360, 640);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        Color? selected;
        await t.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(2),
                viewInsets: const EdgeInsets.only(bottom: 140),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showFolderColorDialog(
                    context,
                    folderName: 'A very long project name with Unicode 数学',
                    isNote: note,
                    currentColor: Colors.blue,
                    onColorSelected: (color) => selected = color,
                  ),
                  child: const Text('Choose'),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('Choose'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        final swatch = find.byKey(const ValueKey('folder-color-swatch-cyan'));
        await t.ensureVisible(swatch);
        await t.tap(swatch);
        final apply = find.byKey(const ValueKey('folder-color-apply-button'));
        await t.ensureVisible(apply);
        await t.tap(apply);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(selected?.toARGB32(), 0xff06b6d4);
      },
    );
  }

  testWidgets('Add Property cannot overwrite a key created during entry', (
    t,
  ) async {
    final (c, note) = await fixture(t);
    await t.tap(find.widgetWithText(TextButton, 'Add').first);
    await t.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextFormField),
    );
    await t.enterText(fields.at(0), 'newField');
    await t.enterText(fields.at(1), 'My pending value');
    c.updateProperty(note.id, 'newField', 'Newer value');
    await t.tap(find.widgetWithText(FilledButton, 'Add Property'));
    await t.pumpAndSettle();
    c.cancelAllTimers();
    expect(c.find(note.id)!.properties['newField'], 'Newer value');
    expect(find.text('My pending value'), findsOneWidget);
  });

  testWidgets('folder color dialog retains a newer explicit color', (t) async {
    final (c, _) = await fixture(t);
    t
        .widget<OrbitExplorerRow>(find.byKey(const ValueKey('folder:Notes')))
        .menu
        .onSelected!('set_folder_color');
    await t.pumpAndSettle();
    c.setFolderColor('Notes', 0xff123456);
    await t.tap(find.byKey(const ValueKey('folder-color-swatch-cyan')));
    await t.tap(find.byKey(const ValueKey('folder-color-apply-button')));
    await t.pumpAndSettle();
    c.cancelAllTimers();
    expect(c.session.folderColors['Notes'], 0xff123456);
    expect(find.byKey(const ValueKey('folder-color-dialog')), findsOneWidget);
  });

  testWidgets('folder rename refuses changed membership after naming', (
    t,
  ) async {
    final (c, _) = await fixture(t);
    await c.repository.createFolder('Notes/Research');
    c.notify();
    await t.pumpAndSettle();
    t
        .widget<OrbitExplorerRow>(
          find.byKey(const ValueKey('folder:Notes/Research')),
        )
        .menu
        .onSelected!('rename');
    await t.pumpAndSettle();
    await t.enterText(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextFormField),
      ),
      'Renamed',
    );
    await c.create(
      'orbit.note',
      title: 'Arrived during rename',
      properties: {'folder': 'Notes/Research'},
    );
    await t.tap(find.widgetWithText(FilledButton, 'Continue'));
    await t.pumpAndSettle();
    await t.pump(const Duration(milliseconds: 300));
    c.cancelAllTimers();
    expect(c.error, contains('folder changed'));
    expect(c.repository.folders, contains('Notes/Research'));
  });

  testWidgets('invalid custom hex cannot apply the previously selected color', (
    t,
  ) async {
    Color? applied;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showFolderColorDialog(
                context,
                folderName: 'Long project',
                currentColor: Colors.blue,
                onColorSelected: (value) => applied = value,
              ),
              child: const Text('Choose'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Choose'));
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const ValueKey('folder-color-hex-field')),
      'broken',
    );
    await t.pumpAndSettle();
    expect(
      t
          .widget<FilledButton>(
            find.byKey(const ValueKey('folder-color-apply-button')),
          )
          .onPressed,
      isNull,
    );
    expect(applied, isNull);
  });
}
