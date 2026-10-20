import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';
import 'package:orbit_note/domain/knowledge_insights.dart';
import 'package:orbit_note/features/notes/document_checks_dialog.dart';
import 'package:orbit_note/features/notes/note_editor.dart';

void main() {
  testWidgets(
    'chosen link repair is one undoable edit and cancellation changes nothing',
    (tester) async {
      final repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      await repo.initialize(path: 'test');
      const original = 'Before [[Missing#^anchor|written label]] after.';
      final note = await repo.create(
        typeId: 'orbit.note',
        title: 'Host',
        body: original,
      );
      final target = await repo.create(
        typeId: 'orbit.note',
        title: 'Correct source',
        body: 'Target paragraph ^anchor',
      );
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      container.read(workspaceProvider);
      final c = container.read(workspaceProvider.notifier);
      await tester.runAsync(() async {
        while (c.loading) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
      });
      var body = original;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (_, setState) => NoteEditor(
                  noteId: note.id,
                  title: 'Host',
                  body: body,
                  controller: c,
                  allObjects: c.objects,
                  onTitleChanged: (_) {},
                  onBodyChanged: (value) {
                    c.edit(note.id, body: value);
                    setState(() => body = value);
                  },
                  linkTargets: const [],
                  onOpenObject: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> repair() async {
        await tester.tap(find.byTooltip('Writing tools'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Document Checks'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Choose a source for this link'));
        await tester.pumpAndSettle();
      }

      await repair();
      await tester.tap(find.byTooltip('Cancel reference picker'));
      await tester.pumpAndSettle();
      expect(body, original);
      await repair();
      await tester.tap(find.text('Correct source').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use reference'));
      await tester.pumpAndSettle();
      expect(body, 'Before [[${target.id}#^anchor|written label]] after.');
      await tester.tap(find.byTooltip('Undo · Ctrl+Z'));
      await tester.pumpAndSettle();
      expect(body, original);
      container.dispose();
      await tester.pump(const Duration(seconds: 1));
    },
  );
  testWidgets(
    'checks paginate, filter and return exact source ranges at large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      DocumentCheckChoice? selected;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  selected = await showDialog<DocumentCheckChoice>(
                    context: context,
                    builder: (_) => DocumentChecksDialog(
                      source: 'text',
                      hasVault: true,
                      findings: List.generate(
                        65,
                        (i) => DocumentFinding(
                          i.isEven ? 'Links' : 'Footnotes',
                          'Finding $i',
                          0,
                          4,
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byTooltip('Next findings page').hitTestable(),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next findings page'));
      await tester.pumpAndSettle();
      expect(find.text('65 findings · Page 2 of 3'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Finding 30').hitTestable(),
        -200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finding 30'));
      await tester.pumpAndSettle();
      expect(selected?.finding.start, 0);
      expect(selected?.finding.end, 4);
    },
  );
  testWidgets('editor checks open exact source without mutating Markdown', (
    tester,
  ) async {
    const body = '# Heading\nA passage [^missing].\n';
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteEditor(
            noteId: 'n',
            title: 'Note',
            body: body,
            onTitleChanged: (_) {},
            onBodyChanged: (_) => changes++,
            linkTargets: const [],
            onOpenObject: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Writing tools'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Document Checks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Missing definition for [^missing].'));
    await tester.pumpAndSettle();
    final field = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .firstWhere((e) => e.controller.text == body);
    expect(field.controller.selection.textInside(body), '[^missing]');
    expect(changes, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('a changed document refuses stale check navigation', (
    tester,
  ) async {
    var body = 'Text [^missing].';
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return NoteEditor(
                noteId: 'n',
                title: 'Note',
                body: body,
                onTitleChanged: (_) {},
                onBodyChanged: (_) {},
                linkTargets: const [],
                onOpenObject: (_) {},
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Writing tools'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Document Checks'));
    await tester.pumpAndSettle();
    update(() => body = 'Changed document.');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Missing definition for [^missing].'));
    await tester.pumpAndSettle();
    expect(
      find.text('The document changed. Run Document Checks again.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
