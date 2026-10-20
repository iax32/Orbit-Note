import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/pdf/pdf_notes_panel.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'support/memory_store.dart';
import 'support/pdf_fixture.dart';

class GatedStore extends MemoryStore {
  Completer<void>? entered;
  @override
  Future<void> write(
    String path,
    Uint8List bytes, {
    required String? expectedHash,
  }) {
    if (writeGate != null && entered?.isCompleted == false) entered!.complete();
    return super.write(path, bytes, expectedHash: expectedHash);
  }
}

Future<void> realTap(WidgetTester tester, Finder target) async {
  await tester.runAsync(() async {
    await tester.tap(target);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
}

Future<void> finishSnackBars(WidgetTester tester) async {
  tester
      .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
      .removeCurrentSnackBar();
  await tester.pumpAndSettle();
  await tester.runAsync(
    () async => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GatedStore store;
  late WorkspaceRepository repo;
  late WorkspaceController c;
  late UniversalObject pdf;
  setUp(() async {
    store = GatedStore();
    repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
    await repo.initialize();
    c = WorkspaceController()
      ..repository = repo
      ..hasWorkspace = true
      ..loading = false;
    pdf = await repo.importAttachment(name: 'Source.pdf', bytes: researchPdf());
    c.mergeRepositoryObjects();
  });
  tearDown(() async {
    store.failWrites = false;
    store.writeGate = null;
    await c.flushAll();
    c.cancelAllTimers();
    await repo.close();
  });
  Future<UniversalObject> quote() async =>
      (await c.createPdfQuote(pdf.id, 1, 'Important evidence'))!;

  test(
    'default and caller-owned session lists support independent tab and archive commands',
    () {
      final first = SessionState(
        tabs: const ['one'],
        pinnedTabs: const ['one'],
      );
      final second = SessionState();
      first.tabs.add('two');
      first.pinnedTabs.remove('one');
      first.closedTabs.add('one');
      first.archivedFolders.add('Archive');
      expect(second.tabs, isEmpty);
      expect(second.closedTabs, isEmpty);
      expect(second.archivedFolders, isEmpty);
      c.session = SessionState(autoSnapshotOnClose: false);
      // No notes are needed to exercise session-only pin/close/reopen state.
      c.closeTab('unknown');
      expect(c.session.closedTabs, ['unknown']);
    },
  );

  test(
    'an in-flight quote creation cannot inject its note into a switched repository',
    () async {
      final other = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      await other.initialize();
      final gate = Completer<void>();
      store.writeGate = gate.future;
      store.entered = Completer<void>();
      final pending = c.createPdfQuote(pdf.id, 1, 'Old workspace');
      await store.entered!.future;
      c.repository = other;
      c.objects = [];
      gate.complete();
      store.writeGate = null;
      expect(await pending, isNull);
      expect(c.objects, isEmpty);
      c.repository = repo;
      c.mergeRepositoryObjects();
      await other.close();
    },
  );

  test(
    'accidental quote note deletes, returns to PDF, and restores without close snapshots',
    () async {
      final note = await quote();
      c.session.secondaryId = pdf.id;
      c.session.pinnedTabs = [note.id];
      c.session.closedTabs = [note.id];
      c.lastClosed = note.id;
      final result = await c.deletePdfLinkedNote(note, pdf.id);
      expect(result, isNotNull);
      expect(result!.isDeleted, true);
      expect(c.session.activeId, pdf.id);
      expect(c.session.secondaryId, isNull);
      expect(c.session.tabs, [pdf.id]);
      expect(c.session.pinnedTabs, isNot(contains(note.id)));
      expect(c.session.closedTabs, isNot(contains(note.id)));
      expect(c.lastClosed, isNull);
      expect(c.dirty, isEmpty);
      expect(result.properties, note.properties);
      expect(c.pdfLinkedNotes(pdf.id), isEmpty);
      expect(await c.restore(note.id, expected: result), true);
      expect(c.find(note.id)!.body, note.body);
      expect(c.pdfLinkedNotes(pdf.id).single.id, note.id);
      expect(
        await repo.readAttachment(pdf.properties['contentRef'] as String),
        researchPdf(),
      );
    },
  );

  test(
    'failed deletion stays open and retry succeeds; a newer Trash revision rejects Undo',
    () async {
      final note = await quote();
      store.failWrites = true;
      expect(await c.deletePdfLinkedNote(note, pdf.id), isNull);
      expect(c.find(note.id)!.isDeleted, false);
      expect(c.session.activeId, note.id);
      store.failWrites = false;
      final retry = await c.deletePdfLinkedNote(note, pdf.id);
      expect(retry, isNotNull, reason: c.error);
      final deleted = retry!;
      await repo.save(deleted.copyWith(body: 'New retained Trash content'));
      c.mergeRepositoryObjects();
      expect(await c.restore(deleted.id, expected: deleted), false);
      expect(c.find(deleted.id)!.body, 'New retained Trash content');
      expect(await c.restore(deleted.id), true);
    },
  );

  test(
    'unsaved invalid titles give a retryable error instead of silently refusing deletion',
    () async {
      final note = await quote();
      c.edit(note.id, title: '');
      expect(await c.trash(note.id), false);
      expect(c.error, contains('save status'));
      expect(c.find(note.id)!.isDeleted, false);
      c.edit(note.id, title: note.title);
      expect(await c.trash(note.id), true, reason: c.error);
      expect(c.failures, isEmpty);
    },
  );

  test(
    'renaming before Trash saves aliases without requiring a second delete',
    () async {
      final note = await quote();
      c.edit(note.id, title: 'Renamed evidence');
      expect(await c.trash(note.id), true, reason: c.error);
      expect(c.find(note.id)!.title, 'Renamed evidence');
      expect(c.find(note.id)!.properties['aliases'], contains(note.title));
    },
  );

  test(
    'competing drafts and stale linked-note snapshots cannot delete current writing',
    () async {
      final note = await quote();
      c.edit(note.id, body: 'New writing');
      expect(await c.deletePdfLinkedNote(note, pdf.id), isNull);
      c.editorDraftConflicts['pane'] = EditorDraftConflict(
        objectId: note.id,
        title: note.title,
        base: note.body,
        body: 'Other pane',
        workspace: repo.workspaceId,
      );
      expect(await c.trash(note.id), false);
      c.editorDraftConflicts.clear();
      expect(await c.trash(note.id), true, reason: c.error);
      expect(c.find(note.id)!.body, 'New writing');
    },
  );

  test(
    'duplicate deletes are bounded and typing during the write survives Trash and restore',
    () async {
      final note = await quote();
      final gate = Completer<void>();
      store.writeGate = gate.future;
      store.entered = Completer<void>();
      final pending = c.trash(note.id);
      await store.entered!.future;
      expect(await c.trash(note.id), false);
      c.edit(note.id, body: 'Last keystrokes during deletion');
      gate.complete();
      store.writeGate = null;
      expect(await pending, true, reason: c.error);
      await c.flush(note.id);
      expect(c.find(note.id)!.isDeleted, true);
      expect(c.find(note.id)!.body, 'Last keystrokes during deletion');
      expect(await c.restore(note.id), true);
      expect(c.find(note.id)!.body, 'Last keystrokes during deletion');
      expect(c.failures, isEmpty);
    },
  );

  test(
    'quote-to-note preserves authored whitespace and reports failed saves',
    () async {
      final note = (await c.create('orbit.note', body: 'Keep  \r\nexact  '))!;
      store.failWrites = true;
      expect(
        await c.extractPdfQuoteToActiveNote('Passage', 1, pdf.id, pdf.title),
        false,
      );
      expect(c.find(note.id)!.body, startsWith('Keep  \r\nexact  \r\n\r\n'));
      store.failWrites = false;
      await c.flush(note.id);
      expect(c.find(note.id)!.body, contains('> Passage'));
      c.edit(note.id, properties: {'documentFormat': 'latex'});
      await c.flush(note.id);
      final before = c.find(note.id)!;
      expect(
        await c.extractPdfQuoteToActiveNote(
          'Must not insert',
          1,
          pdf.id,
          pdf.title,
        ),
        false,
      );
      expect(c.find(note.id)!.body, before.body);
    },
  );

  test(
    'Canvas extraction writes scene data and preserves existing elements and unknown metadata',
    () async {
      final canvas = (await c.create(
        'orbit.canvas',
        properties: {'future': 42},
        data: {
          'schemaVersion': 1,
          'futureScene': true,
          'elements': [
            {
              'id': 'keep',
              'type': 'text',
              'text': 'Existing',
              'x': 20,
              'y': 30,
            },
          ],
        },
      ))!;
      expect(
        await c.extractPdfQuoteToCanvas(
          'Evidence',
          1,
          pdf.id,
          pdf.title,
          targetCanvasId: canvas.id,
        ),
        true,
      );
      final updated = c.find(canvas.id)!;
      expect(updated.properties, canvas.properties);
      expect(updated.data['futureScene'], true);
      final scene = CanvasScene.fromJson(updated.data);
      expect(scene['keep']!.text, 'Existing');
      expect(scene.elements, hasLength(2));
      expect(scene.elements.last.data['referenceTarget'], '${pdf.id}#page=1');
      store.failWrites = true;
      expect(
        await c.extractPdfQuoteToCanvas(
          'Retained draft',
          1,
          pdf.id,
          pdf.title,
          targetCanvasId: canvas.id,
        ),
        false,
      );
      expect(c.session.secondaryId, isNot(canvas.id));
      store.failWrites = false;
      await c.flush(canvas.id);
      expect(
        CanvasScene.fromJson(c.find(canvas.id)!.data).elements,
        hasLength(3),
      );
      expect(
        await c.extractPdfQuoteToCanvas(
          'Wrong destination',
          1,
          pdf.id,
          pdf.title,
          targetCanvasId: pdf.id,
        ),
        false,
      );
      expect(await c.extractPdfQuoteToCanvas('', 1, pdf.id, pdf.title), false);
      expect(
        await c.extractPdfQuoteToCanvas('Invalid page', 0, pdf.id, pdf.title),
        false,
      );
    },
  );

  testWidgets(
    'connected note deletion releases failed busy state, retries and offers working Undo',
    (tester) async {
      final note = (await tester.runAsync(quote))!;
      var notes = [note];
      var calls = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return PdfNotesPanel(
                  notes: notes,
                  fileId: pdf.id,
                  checksum: 'v1',
                  onOpen: (_) {},
                  onClose: () {},
                  onDelete: (original) async {
                    calls++;
                    if (calls == 1) throw StateError('Simulated failure');
                    final deleted = await c.deletePdfLinkedNote(
                      original,
                      pdf.id,
                    );
                    if (deleted != null) update(() => notes = []);
                    return deleted;
                  },
                  onRestore: (deleted) async {
                    final ok = await c.restore(deleted.id, expected: deleted);
                    if (ok) update(() => notes = [c.find(deleted.id)!]);
                    return ok;
                  },
                );
              },
            ),
          ),
        ),
      );
      final remove = find.byKey(ValueKey('delete-pdf-note-${note.id}'));
      await tester.ensureVisible(remove);
      await realTap(tester, remove);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not delete this note.'),
        findsOneWidget,
      );
      expect(tester.widget<IconButton>(remove).onPressed, isNotNull);
      await realTap(tester, remove);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(c.find(note.id)!.isDeleted, true);
      await realTap(tester, find.text('Undo'));
      await tester.pumpAndSettle();
      expect(c.find(note.id)!.isDeleted, false);
      expect(
        find.byKey(ValueKey('delete-pdf-note-${note.id}')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await finishSnackBars(tester);
    },
  );

  testWidgets(
    'source banner exposes recoverable deletion at narrow width and 2x text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final note = (await tester.runAsync(quote))!;
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: NoteEditor(
              noteId: note.id,
              title: note.title,
              body: note.body,
              linkTargets: const [],
              allObjects: c.activeObjects,
              controller: c,
              pdfSource: Map<String, dynamic>.from(
                note.properties['pdfSource'] as Map,
              ),
              onTitleChanged: (_) {},
              onBodyChanged: (_) {},
              onOpenObject: (_) {},
              onOpenPdfSource: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final remove = find.byKey(const ValueKey('delete-linked-pdf-note'));
      await tester.ensureVisible(remove);
      await realTap(tester, remove);
      await tester.pumpAndSettle();
      expect(c.find(note.id)!.isDeleted, true);
      await realTap(tester, find.text('Undo'));
      await tester.pumpAndSettle();
      expect(c.find(note.id)!.isDeleted, false);
      expect(tester.takeException(), isNull);
      await finishSnackBars(tester);
    },
  );

  test(
    'native quote deletion, restart and restore retain source bytes and unknown metadata',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'orbit-pdf-note-life-',
      );
      final native = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: MemoryObjectIndex(),
      );
      final controller = WorkspaceController()
        ..repository = native
        ..hasWorkspace = true
        ..loading = false;
      try {
        await native.initialize(path: root.path);
        final source = await native.importAttachment(
          name: 'Original.pdf',
          bytes: researchPdf(),
        );
        controller.mergeRepositoryObjects();
        final note = (await controller.createPdfQuote(
          source.id,
          1,
          'Retain this',
        ))!;
        controller.edit(
          note.id,
          properties: {
            ...note.properties,
            'future': {'keep': 42},
          },
        );
        expect(await controller.trash(note.id), true);
        controller.cancelAllTimers();
        await native.close();
        await native.initialize(path: root.path);
        controller.mergeRepositoryObjects();
        expect(controller.find(note.id)!.isDeleted, true);
        expect(await controller.restore(note.id), true);
        controller.cancelAllTimers();
        await native.close();
        await native.initialize(path: root.path);
        controller.mergeRepositoryObjects();
        expect(controller.find(note.id)!.body, note.body);
        expect(controller.find(note.id)!.properties['future'], {'keep': 42});
        expect(
          await native.readAttachment(
            source.properties['contentRef'] as String,
          ),
          researchPdf(),
        );
      } finally {
        controller.cancelAllTimers();
        await native.close();
        await root.delete(recursive: true);
      }
    },
  );
}
