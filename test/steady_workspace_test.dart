import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_drag_scroll.dart';
import 'package:orbit_note/app/orbit_operation.dart';
import 'package:orbit_note/app/retained_form.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/attachment_identity.dart';
import 'package:orbit_note/domain/edge_scroll.dart';
import 'package:orbit_note/domain/export_name.dart';
import 'package:orbit_note/features/notes/read_attachment_preview.dart';
import 'package:orbit_note/platform/staged_export_native.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';
import 'canvas_transfer_quality_test.dart' as canvas;
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/features/notes/export/publication_workspace.dart';
import 'package:orbit_note/features/canvas/reference_details_dialog.dart';
import 'package:orbit_note/features/workspace/recovery_dialog.dart';
import 'package:flutter/services.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'support/capture_ui.dart';

void main() {
  testWidgets(
    'dragging on a 1000-item Canvas pans at the edge with a single undoable move',
    (t) async {
      t.view.physicalSize = const Size(1200, 850);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final elements = [
        canvas.rectangle('moving'),
        for (var i = 1; i < 1000; i++)
          {
            ...canvas.rectangle('node-$i'),
            'x': 2000.0 + (i % 30) * 200,
            'y': 2000.0 + (i ~/ 30) * 150,
          },
      ];
      final original = canvas.board(elements);
      Map<String, dynamic>? saved;
      var writes = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'large',
              data: original,
              objects: const [],
              onOpenObject: (_) {},
              onChanged: (v) {
                saved = v;
                writes++;
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final start = canvas.at(t, const CanvasPoint(100, 90));
      final pointer = await t.startGesture(start);
      final edge = t.getBottomRight(canvas.surface) - const Offset(8, 8);
      await pointer.moveTo(edge);
      await t.pump();
      final before = canvas.painter(t).camera;
      final watch = Stopwatch()..start();
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
      // ignore: avoid_print
      print(
        'Large Canvas: 12 edge-pan frames / 1000 items: ${watch.elapsedMilliseconds} ms (test CPU)',
      );
      expect(canvas.painter(t).camera.x, greaterThan(before.x));
      expect(canvas.painter(t).camera.y, greaterThan(before.y));
      await pointer.up();
      await t.pumpAndSettle();
      expect(writes, 1);
      expect((saved!['elements'] as List).length, 1000);
      await t.tap(find.byTooltip('Undo (Ctrl+Z)'));
      await t.pumpAndSettle();
      final moved = (saved!['elements'] as List).cast<Map>().singleWhere(
        (e) => e['id'] == 'moving',
      );
      expect(moved['x'], 40.0);
      expect(moved['y'], 50.0);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'cancel preparation waits out an image read and retries without stale output',
    (t) async {
      final pending = Completer<Uint8List?>();
      await t.pumpWidget(
        MaterialApp(
          home: PublicationWorkspace(
            title: 'Large export',
            source: '![Figure](Attachments/test.png)',
            readImage: (_) => pending.future,
            previewBuilder: (_) => const Text('Ready output'),
          ),
        ),
      );
      await t.pump();
      await t.tap(find.text('Cancel preparation'));
      await t.pumpAndSettle();
      expect(find.textContaining('Preparation canceled.'), findsOneWidget);
      pending.complete(null);
      await t.pump();
      expect(find.text('Ready output'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  test('edge motion is bounded, smooth and inactive outside the viewport', () {
    expect(edgeScrollStep(0, 800), -12);
    expect(edgeScrollStep(24, 800), -6);
    expect(edgeScrollStep(400, 800), 0);
    expect(edgeScrollStep(800, 800), 12);
    expect(edgeScrollStep(801, 800), 0);
    expect(edgeScrollStep(double.nan, 800), 0);
    expect(edgeScrollStep(0, 0), 0);
  });

  test('portable export names preserve Unicode and avoid reserved names', () {
    expect(suggestedExportName('CON'), 'Orbit CON');
    expect(suggestedExportName('   '), 'Orbit document');
    expect(suggestedExportName('Übung 2: A/B?'), 'Übung 2 A B');
    expect(
      suggestedExportName('Homework', dated: DateTime(2026, 10, 27)),
      'Homework — 2026-10-27',
    );
    expect(suggestedExportName('🙂' * 100).length, lessThanOrEqualTo(120));
  });

  test(
    'header dimensions reject truncated data without decoding large images',
    () {
      final png = Uint8List(24)
        ..setAll(0, [137, 80, 78, 71])
        ..setAll(12, [73, 72, 68, 82]);
      final header = ByteData.sublistView(png)
        ..setUint32(16, 4000)
        ..setUint32(20, 2000);
      expect(attachmentImageSize(png), (width: 4000, height: 2000));
      header.setUint32(16, 0);
      expect(attachmentImageSize(png), isNull);
      for (var n = 0; n < 24; n++) {
        expect(attachmentImageSize(Uint8List(n)), isNull);
      }
    },
  );

  test(
    'independent duplicate keeps two identities and the same verified bytes',
    () async {
      final repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      addTearDown(repo.close);
      final bytes = Uint8List.fromList(utf8.encode('Original attachment'));
      final a = await repo.importAttachment(name: 'First.pdf', bytes: bytes);
      final reused = await repo.importAttachment(
        name: 'Again.pdf',
        bytes: bytes,
      );
      final copy = await repo.importAttachment(
        name: 'First.pdf',
        bytes: bytes,
        reuseExisting: false,
      );
      expect(reused.id, a.id);
      expect(copy.id, isNot(a.id));
      expect(copy.properties['contentRef'], a.properties['contentRef']);
      await repo.trash(copy.id);
      expect(
        (await repo.readAttachment(a.properties['contentRef'] as String)),
        bytes,
      );
      expect(repo.objects.singleWhere((o) => o.id == a.id).isDeleted, false);
    },
  );

  test(
    'staged export replaces complete files, cancels and preserves external changes',
    () async {
      final dir = await Directory.systemTemp.createTemp('orbit-staged-export-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/Homework.pdf');
      await file.writeAsString('old');
      final bytes = Uint8List(2 * 1024 * 1024)
        ..fillRange(0, 2 * 1024 * 1024, 73);
      var cancel = false, writes = 0;
      expect(
        await writeStagedExport(
          file.path,
          bytes,
          isCancelled: () => cancel,
          onProgress: (_, _) {
            writes++;
            cancel = true;
          },
        ),
        false,
      );
      expect(writes, 1);
      expect(await file.readAsString(), 'old');
      expect((await dir.list().toList()).length, 1);
      var changed = false;
      await expectLater(
        writeStagedExport(
          file.path,
          bytes,
          onProgress: (_, _) {
            if (!changed) {
              changed = true;
              file.writeAsStringSync('external edit');
            }
          },
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await file.readAsString(), 'external edit');
      expect(await writeStagedExport(file.path, bytes), true);
      expect(await file.readAsBytes(), bytes);
      expect((await dir.list().toList()).length, 1);
    },
  );

  testWidgets(
    'attachment reserves identical geometry while loading and retrying',
    (t) async {
      final pending = Completer<Uint8List?>();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    width: 400,
                    child: ReadAttachmentImage(
                      label: 'figure.png',
                      aspectRatio: 2,
                      load: () => pending.future,
                      builder: (_) =>
                          const SizedBox(height: 10, child: Text('Loaded')),
                    ),
                  ),
                  const Text('Following paragraph', key: ValueKey('after')),
                ],
              ),
            ),
          ),
        ),
      );
      final top = t.getTopLeft(find.byKey(const ValueKey('after')));
      pending.complete(Uint8List(1));
      await t.pumpAndSettle();
      expect(t.getTopLeft(find.byKey(const ValueKey('after'))), top);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'edge scroll continues at a stationary pointer and stops explicitly',
    (t) async {
      final controller = ScrollController(), key = GlobalKey();
      final drag = OrbitDragScroll(controller, key);
      await t.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 200,
              child: ListView.builder(
                key: key,
                controller: controller,
                itemExtent: 40,
                itemCount: 1000,
                itemBuilder: (_, i) => Text('$i'),
              ),
            ),
          ),
        ),
      );
      drag.update(t.getBottomRight(find.byKey(key)) - const Offset(20, 2));
      await t.pump(const Duration(milliseconds: 160));
      expect(controller.offset, greaterThan(50));
      drag.stop();
      final stopped = controller.offset;
      await t.pump(const Duration(milliseconds: 160));
      expect(controller.offset, stopped);
      await t.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets('long operation waits for a safe cancellation checkpoint', (
    t,
  ) async {
    final step = Completer<void>();
    OrbitOperationProgress? operation;
    String? result;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await runOrbitOperation<String>(context, 'Importing', (
                p,
              ) async {
                operation = p;
                p.report('1 of 100 files', progress: .01);
                await step.future;
                return p.canceled ? 'partial' : 'complete';
              });
            },
            child: const Text('Start'),
          ),
        ),
      ),
    );
    await t.tap(find.text('Start'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pump();
    expect(operation!.canceled, true);
    expect(find.textContaining('current safe step'), findsOneWidget);
    expect(result, isNull);
    step.complete();
    await t.pumpAndSettle();
    expect(result, 'partial');
  });

  testWidgets(
    'retained forms persist separately, explain changed sources and reject stale Vaults',
    (t) async {
      late ProviderContainer container;
      late WorkspaceController c;
      final store = MemoryStore();
      await t.runAsync(() async {
        container = ProviderContainer(
          overrides: [
            repositoryProvider.overrideWithValue(
              WorkspaceRepository(store: store, index: MemoryObjectIndex()),
            ),
          ],
        );
        c = container.read(workspaceProvider.notifier);
        await c.initialize();
      });
      RetainedForm? form;
      var source = 'original';
      final capture = GlobalKey();
      Widget host() => UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
          key: capture,
          child: MaterialApp(
            theme: orbitDarkTheme(),
            home: Builder(
              builder: (context) {
                form = RetainedForm.capture(
                  context,
                  'caption:owner:figure',
                  source,
                );
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => showReferenceDetails(
                        context,
                        CanvasElement({
                          'id': 'card',
                          'type': 'card',
                          'referenceCaption': 'Original caption',
                        }),
                        'Reference source',
                        ownerId: 'board',
                      ),
                      child: const Text('Open reference'),
                    ),
                    TextButton(
                      onPressed: () => showWorkspaceRecoveryDialog(
                        context: context,
                        repository: c.repository,
                      ),
                      child: const Text('Review recovery'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await t.pumpWidget(host());
      await t.runAsync(() async {
        store.failWrites = true;
        await expectLater(
          form!.keep({'caption': 'Not saved'}),
          throwsStateError,
        );
        expect(form!.recovered, isNull);
        store.failWrites = false;
      });
      await t.runAsync(() async {
        expect(await form!.keep({'caption': 'Unapplied'}), true);
      });
      await t.runAsync(() async {
        final restarted = ProviderContainer(
          overrides: [
            repositoryProvider.overrideWithValue(
              WorkspaceRepository(store: store, index: MemoryObjectIndex()),
            ),
          ],
        );
        final fresh = restarted.read(workspaceProvider.notifier);
        await fresh.initialize();
        expect(
          jsonEncode(fresh.session.extra['retainedForms']),
          contains('Unapplied'),
        );
        restarted.dispose();
      });
      source = 'externally changed';
      await t.pumpWidget(host());
      expect(form!.sourceChanged, true);
      expect(form!.recovered!['caption'], 'Unapplied');
      final stored = c.session.toJson();
      expect(jsonEncode(stored), contains('Unapplied'));
      expect(c.objects.any((o) => o.body.contains('Unapplied')), false);
      await t.runAsync(() async {
        expect(await form!.discard(), true);
      });
      expect(form!.recovered, isNull);
      await t.tap(find.text('Open reference'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('reference-caption')),
        'Retained caption',
      );
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(find.text('Keep draft and close'), findsOneWidget);
      await t.runAsync(() => t.tap(find.text('Keep draft and close')));
      await t.pumpAndSettle();
      for (
        var i = 0;
        i < 30 && find.text('Reference details').evaluate().isNotEmpty;
        i++
      ) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump(const Duration(milliseconds: 20));
      }
      expect(
        find.text('Reference details'),
        findsNothing,
        reason:
            '${c.error} · saving ${c.savingSettings} · ${jsonEncode(c.session.extra["retainedForms"])}',
      );
      await t.tap(find.text('Review recovery'));
      await t.pumpAndSettle();
      await t.tap(find.text('Kept form drafts · 1'));
      await t.pumpAndSettle();
      await t.tap(find.text('Reference details · Original unavailable'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('"caption": "Retained caption"'),
        findsOneWidget,
      );
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      await t.tap(find.text('Open reference'));
      await t.pumpAndSettle();
      expect(find.text('Retained caption'), findsOneWidget);
      expect(find.textContaining('Recovered unapplied form.'), findsOneWidget);
      await prepareCapture(t);
      await captureUi(
        t,
        'steady-retained-reference',
        target: find.byKey(capture),
      );
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      await t.runAsync(() => t.tap(find.text('Discard changes')));
      await t.pumpAndSettle();
      expect(find.text('Reference details'), findsNothing);
      final stale = form!;
      await t.runAsync(() async {
        await c.initialize();
        expect(stale.current, false);
        await expectLater(
          stale.keep({'caption': 'Wrong Vault'}),
          throwsStateError,
        );
      });
      await t.pumpWidget(const SizedBox());
      await t.runAsync(() async {
        container.dispose();
      });
      expect(t.takeException(), isNull);
    },
  );
}
