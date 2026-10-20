import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/features/notes/media_clipboard.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'support/capture_ui.dart';

Finder get surface => find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
);
OrbitCanvasPainter painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(surface).painter! as OrbitCanvasPainter;
Offset at(WidgetTester tester, CanvasPoint point) {
  final p = painter(tester).camera.toScreen(point);
  return tester.getTopLeft(surface) + Offset(p.x, p.y);
}

Map<String, dynamic> rectangle(String id) => {
  'id': id,
  'type': 'rectangle',
  'x': 40.0,
  'y': 50.0,
  'width': 140.0,
  'height': 90.0,
};
Map<String, dynamic> board(List<Map<String, dynamic>> elements) => {
  'schemaVersion': 1,
  'backgroundStyle': 'dots',
  'future': {'retained': true},
  'elements': elements,
};
String payload(List<Map<String, dynamic>> elements) =>
    '$canvasClipboardPrefix${jsonEncode({'elements': elements})}';
Future<void> command(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

void main() {
  String clipboard = '';
  Completer<void>? readGate, writeGate;
  setUp(() {
    clipboard = '';
    readGate = null;
    writeGate = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('pasteboard'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        await readGate?.future;
        return {'text': clipboard};
      }
      if (call.method == 'Clipboard.setData') {
        await writeGate?.future;
        clipboard = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(const MethodChannel('pasteboard'), null);
  });
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
      RepaintBoundary(
        child: MaterialApp(
          theme: orbitDarkTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget canvas(
    Map<String, dynamic> data, {
    String owner = 'board',
    bool readOnly = false,
    ValueChanged<Map<String, dynamic>>? change,
    CanvasCaptureController? capture,
    Future<CanvasImageReference?> Function()? pasteImage,
    List<CanvasObjectReference> objects = const [],
  }) => CanvasEditor(
    canvasId: owner,
    data: data,
    readOnly: readOnly,
    captureController: capture,
    onPasteImage: pasteImage,
    onChanged: change ?? (_) {},
    objects: objects,
    onOpenObject: (_) {},
  );

  for (final duplicate in [false, true]) {
    testWidgets(
      '${duplicate ? 'duplicate' : 'paste'} preserves local ink samples and pressure metadata',
      (tester) async {
        final samples = [
          {
            'x': 0.0,
            'y': 0.0,
            'pressure': .35,
            'time': 0,
            'tilt': .2,
            'future': 'keep',
          },
          {'x': 60.0, 'y': 30.0, 'pressure': .8, 'time': 20},
        ];
        final ink = {
          'id': 'ink',
          'type': 'ink',
          'x': 40.0,
          'y': 50.0,
          'width': 60.0,
          'height': 30.0,
          'points': samples,
        };
        var data = board([ink]);
        await host(
          tester,
          StatefulBuilder(
            builder: (_, refresh) =>
                canvas(data, change: (v) => refresh(() => data = v)),
          ),
        );
        await tester.tapAt(at(tester, const CanvasPoint(70, 65)));
        clipboard = payload([ink]);
        await command(
          tester,
          duplicate ? LogicalKeyboardKey.keyD : LogicalKeyboardKey.keyV,
        );
        await tester.pumpAndSettle();
        final copied = (data['elements'] as List).whereType<Map>().singleWhere(
          (e) => e['id'] != 'ink',
        );
        expect(copied['points'], samples);
        expect(copied['x'], duplicate ? 60 : 72);
        expect(copied['y'], duplicate ? 70 : 82);
        if (!duplicate) {
          await tester.runAsync(() async {
            final root = await Directory.systemTemp.createTemp(
              'orbit-canvas-transfer-',
            );
            WorkspaceRepository? repo;
            try {
              repo = WorkspaceRepository(
                store: NativeWorkspaceStore(),
                index: MemoryObjectIndex(),
              );
              await repo.initialize(path: root.path);
              final saved = await repo.create(
                typeId: 'orbit.canvas',
                title: 'Transfer',
                data: data,
              );
              await repo.close();
              repo = WorkspaceRepository(
                store: NativeWorkspaceStore(),
                index: MemoryObjectIndex(),
              );
              await repo.initialize(path: root.path);
              final restored = repo.objects.singleWhere(
                (o) => o.id == saved.id,
              );
              expect(restored.data['elements'], data['elements']);
              expect(restored.data['future'], {'retained': true});
            } finally {
              await repo?.close();
              expect(
                root.absolute.path.startsWith(
                  Directory.systemTemp.absolute.path,
                ),
                true,
              );
              await root.delete(recursive: true);
            }
          });
        }
        await command(tester, LogicalKeyboardKey.keyZ);
        expect((data['elements'] as List).single, ink);
      },
    );
  }

  for (final action in [
    'Align Left',
    'Distribute Horizontally',
    'Distribute Vertically',
  ]) {
    testWidgets('$action preserves local ink geometry and sample data', (
      tester,
    ) async {
      final samples = [
        {'x': 0.0, 'y': 0.0, 'pressure': .3, 'time': 1, 'future': 'keep'},
        {'x': 60.0, 'y': 30.0, 'pressure': .9, 'time': 20},
      ];
      final original = board([
        {...rectangle('left'), 'width': 60.0, 'height': 30.0},
        {
          'id': 'ink',
          'type': 'ink',
          'x': 240.0,
          'y': 190.0,
          'width': 60.0,
          'height': 30.0,
          'points': samples,
        },
        {
          ...rectangle('right'),
          'x': 540.0,
          'y': 450.0,
          'width': 60.0,
          'height': 30.0,
        },
      ]);
      var data = original;
      await host(
        tester,
        StatefulBuilder(
          builder: (_, refresh) =>
              canvas(data, change: (v) => refresh(() => data = v)),
        ),
      );
      await tester.tapAt(at(tester, const CanvasPoint(70, 65)));
      await command(tester, LogicalKeyboardKey.keyA);
      final align = find.byTooltip('Align selected elements');
      await tester.ensureVisible(align);
      await tester.tap(align);
      await tester.pumpAndSettle();
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      final ink = (data['elements'] as List).singleWhere(
        (e) => e['id'] == 'ink',
      );
      expect(ink['points'], samples);
      expect(
        ink['x'],
        action == 'Align Left'
            ? 40
            : action == 'Distribute Horizontally'
            ? 290
            : 240,
      );
      expect(ink['y'], action == 'Distribute Vertically' ? 250 : 190);
      await command(tester, LogicalKeyboardKey.keyZ);
      expect(data['elements'], original['elements']);
    });
  }

  testWidgets('a cancelled drag restores geometry and previous selection', (
    tester,
  ) async {
    final data = board([
      rectangle('a'),
      {...rectangle('b'), 'x': 260.0},
    ]);
    await host(tester, canvas(data));
    await tester.tapAt(at(tester, const CanvasPoint(80, 80)));
    await tester.pump();
    expect(painter(tester).selection, {'a'});
    final drag = await tester.startGesture(
      at(tester, const CanvasPoint(300, 80)),
      kind: PointerDeviceKind.mouse,
    );
    await drag.moveBy(const Offset(50, 30));
    await tester.pump();
    await drag.cancel();
    await tester.pump();
    expect(painter(tester).scene['b']!.x, 260);
    expect(painter(tester).selection, {'a'});
    await tester.pumpAndSettle();
  });

  testWidgets(
    'read-only transition cancels a live drag before later commands',
    (tester) async {
      var data = board([rectangle('a')]), readOnly = false;
      late StateSetter refresh;
      await host(
        tester,
        StatefulBuilder(
          builder: (_, update) {
            refresh = update;
            return canvas(
              data,
              readOnly: readOnly,
              change: (v) => update(() => data = v),
            );
          },
        ),
      );
      final drag = await tester.startGesture(
        at(tester, const CanvasPoint(80, 80)),
        kind: PointerDeviceKind.mouse,
      );
      await drag.moveBy(const Offset(40, 20));
      await tester.pump();
      refresh(() => readOnly = true);
      await tester.pump();
      await drag.moveBy(const Offset(40, 20));
      await drag.up();
      await tester.pump();
      expect(painter(tester).scene['a']!.x, 40);
      refresh(() => readOnly = false);
      await tester.pump();
      await command(tester, LogicalKeyboardKey.keyV);
      expect((data['elements'] as List).single['x'], 40);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'prepared drop cannot revive after leaving and returning to a board',
    (tester) async {
      final capture = CanvasCaptureController();
      final data = board([]);
      var owner = 'a', changes = 0;
      late StateSetter refresh;
      await host(
        tester,
        StatefulBuilder(
          builder: (_, update) {
            refresh = update;
            return canvas(
              data,
              owner: owner,
              capture: capture,
              change: (_) => changes++,
            );
          },
        ),
      );
      final ticket = capture.prepare()!;
      refresh(() => owner = 'b');
      await tester.pump();
      refresh(() => owner = 'a');
      await tester.pump();
      expect(ticket(['source']), false);
      expect(changes, 0);
    },
  );

  testWidgets(
    'drop uses the board viewport coordinates, retaining source identity',
    (tester) async {
      const source = CanvasObjectReference(
        id: 'note',
        typeId: 'orbit.note',
        title: 'Source',
      );
      var data = board([]);
      await host(
        tester,
        canvas(data, objects: [source], change: (v) => data = v),
      );
      final drop = tester.widget<DragTarget<Object>>(
        find.byType(DragTarget<Object>),
      );
      drop.onAcceptWithDetails!(
        DragTargetDetails<Object>(
          data: (path: 'Notes/source.md', noteId: 'note'),
          offset: at(tester, const CanvasPoint(350, 250)),
        ),
      );
      await tester.pump();
      final placed = (data['elements'] as List).single as Map;
      expect(placed['objectId'], source.id);
      expect(placed['x'], 220);
      expect(placed['y'], 190);
    },
  );

  test(
    'labelled drawings keep their full payload when Markdown cannot represent them',
    () {
      expect(
        canvasClipboardMarkdown(
          payload([
            {...rectangle('a'), 'text': 'Important shape'},
          ]),
        ),
        isNull,
      );
    },
  );

  testWidgets(
    'cancelled two-finger navigation restores the camera and original scene',
    (tester) async {
      await host(tester, canvas(board([rectangle('a')])));
      final initial = painter(tester).camera.toJson();
      final first = await tester.startGesture(
        at(tester, const CanvasPoint(80, 80)),
        pointer: 21,
      );
      await first.moveBy(const Offset(35, 20));
      await tester.pump();
      final second = await tester.startGesture(
        at(tester, const CanvasPoint(350, 250)),
        pointer: 22,
      );
      await second.moveBy(const Offset(80, 40));
      await tester.pump();
      expect(painter(tester).camera.toJson(), isNot(initial));
      await second.cancel();
      await first.up();
      await tester.pumpAndSettle();
      expect(painter(tester).camera.toJson(), initial);
      expect(painter(tester).scene['a']!.x, 40);
    },
  );

  for (final rich in [false, true]) {
    testWidgets(
      'Canvas cut → ${rich ? 'Rich' : 'Source'} → Canvas preserves labelled diagram data',
      (tester) async {
        var data = board([
          {
            ...rectangle('original'),
            'text': 'Keep the diagram',
            'future': {'style': 2},
          },
        ]);
        final original = data;
        await host(tester, canvas(data, change: (v) => data = v));
        await tester.tapAt(at(tester, const CanvasPoint(80, 80)));
        await command(tester, LogicalKeyboardKey.keyX);
        await tester.pumpAndSettle();
        expect(data['elements'], isEmpty);
        final copied = clipboard;
        await command(tester, LogicalKeyboardKey.keyZ);
        await tester.pumpAndSettle();
        expect(data['elements'], original['elements']);
        var body = 'Original';
        if (rich) {
          await host(
            tester,
            RichMarkdownEditor(
              noteId: 'note',
              body: body,
              onChanged: (v) => body = v,
              onUndo: () {},
              onRedo: () {},
              linkTargets: const [],
              linkBindings: const {},
              onOpenLink: (_) {},
              spellCheckEnabled: false,
            ),
          );
          final editor = tester.state<RichMarkdownEditorState>(
            find.byType(RichMarkdownEditor),
          );
          editor.selectDocumentRange(0, body.length);
          await tester.pump();
          await command(tester, LogicalKeyboardKey.keyV);
        } else {
          await host(
            tester,
            NoteEditor(
              noteId: 'note',
              title: 'Note',
              body: body,
              initialViewState: const {'mode': 'write'},
              onTitleChanged: (_) {},
              onBodyChanged: (v) => body = v,
              linkTargets: const [],
              onOpenObject: (_) {},
            ),
          );
          final field = find.byKey(const ValueKey('note-body'));
          await tester.tap(field);
          await tester.pump();
          tester.widget<TextField>(field).controller!.selection = TextSelection(
            baseOffset: 0,
            extentOffset: body.length,
          );
          await command(tester, LogicalKeyboardKey.keyV);
        }
        await tester.pumpAndSettle();
        expect(body, copied);
        clipboard = body;
        await host(tester, canvas(board([]), change: (v) => data = v));
        await tester.tapAt(at(tester, const CanvasPoint(400, 300)));
        await command(tester, LogicalKeyboardKey.keyV);
        await tester.pumpAndSettle();
        final restored = (data['elements'] as List).single as Map;
        expect(restored['id'], isNot('original'));
        expect(restored['type'], 'rectangle');
        expect(restored['text'], 'Keep the diagram');
        expect(restored['x'], 72);
        expect(restored['future'], {'style': 2});
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final cut in [false, true]) {
    testWidgets(
      '${cut ? 'cut' : 'paste'} during a drag has its own undo boundary',
      (tester) async {
        var data = board([rectangle('a')]);
        await host(tester, canvas(data, change: (v) => data = v));
        final drag = await tester.startGesture(
          at(tester, const CanvasPoint(80, 80)),
          kind: PointerDeviceKind.mouse,
        );
        await drag.moveBy(const Offset(45, 30));
        await tester.pump();
        clipboard = 'New content';
        await command(
          tester,
          cut ? LogicalKeyboardKey.keyX : LogicalKeyboardKey.keyV,
        );
        await tester.pumpAndSettle();
        await drag.cancel();
        await tester.pumpAndSettle();
        if (cut) {
          expect(data['elements'], isEmpty);
        } else {
          expect(data['elements'], hasLength(2));
          expect(painter(tester).scene['a']!.x, 40);
        }
        await command(tester, LogicalKeyboardKey.keyZ);
        await tester.pumpAndSettle();
        expect(data['elements'], [rectangle('a')]);
      },
    );
  }

  for (final operation in ['cut', 'paste', 'captured drop']) {
    testWidgets(
      'pending $operation cannot revive after read-only then writable',
      (tester) async {
        var data = board([rectangle('a')]), readOnly = false, changes = 0;
        final capture = CanvasCaptureController();
        late StateSetter refresh;
        await host(
          tester,
          StatefulBuilder(
            builder: (_, update) {
              refresh = update;
              return canvas(
                data,
                readOnly: readOnly,
                capture: capture,
                change: (v) {
                  changes++;
                  update(() => data = v);
                },
              );
            },
          ),
        );
        await tester.tapAt(at(tester, const CanvasPoint(80, 80)));
        await tester.pump();
        final ticket = capture.prepare()!;
        clipboard = 'Delayed content';
        if (operation == 'cut') {
          writeGate = Completer<void>();
          await command(tester, LogicalKeyboardKey.keyX);
        } else if (operation == 'paste') {
          readGate = Completer<void>();
          await command(tester, LogicalKeyboardKey.keyV);
        }
        refresh(() => readOnly = true);
        await tester.pump();
        refresh(() => readOnly = false);
        await tester.pump();
        if (operation == 'captured drop') expect(ticket(['source']), false);
        writeGate?.complete();
        readGate?.complete();
        await tester.pumpAndSettle();
        expect(changes, 0);
        expect(painter(tester).scene.elements, hasLength(1));
      },
    );
  }

  testWidgets('a second finger cancels the provisional drag before panning', (
    tester,
  ) async {
    var data = board([rectangle('a')]);
    await host(tester, canvas(data, change: (v) => data = v));
    final first = await tester.startGesture(
      at(tester, const CanvasPoint(80, 80)),
      pointer: 11,
    );
    await first.moveBy(const Offset(40, 20));
    await tester.pump();
    final second = await tester.startGesture(
      at(tester, const CanvasPoint(300, 250)),
      pointer: 12,
    );
    await second.moveBy(const Offset(40, 20));
    await tester.pump();
    await second.up();
    await first.up();
    await tester.pumpAndSettle();
    expect(painter(tester).scene['a']!.x, 40);
    expect((data['elements'] as List).single['x'], 40);
    await command(tester, LogicalKeyboardKey.keyA);
    await command(tester, LogicalKeyboardKey.keyD);
    await command(tester, LogicalKeyboardKey.keyZ);
    expect((data['elements'] as List).single['x'], 40);
  });

  testWidgets('external scene revision during a drag remains authoritative', (
    tester,
  ) async {
    var data = board([rectangle('a')]), writes = 0;
    late StateSetter refresh;
    await host(
      tester,
      StatefulBuilder(
        builder: (_, update) {
          refresh = update;
          return canvas(
            data,
            change: (v) {
              writes++;
              update(() => data = v);
            },
          );
        },
      ),
    );
    final drag = await tester.startGesture(
      at(tester, const CanvasPoint(80, 80)),
      kind: PointerDeviceKind.mouse,
    );
    await drag.moveBy(const Offset(45, 30));
    await tester.pump();
    refresh(
      () => data = board([
        {...rectangle('a'), 'x': 400.0, 'text': 'Updated elsewhere'},
      ]),
    );
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();
    expect(painter(tester).scene['a']!.x, 400);
    expect(painter(tester).scene['a']!.text, 'Updated elsewhere');
    expect(writes, 0);
  });

  testWidgets(
    'a newer copy supersedes a delayed cut without removing placements',
    (tester) async {
      var data = board([rectangle('a')]), writes = 0;
      await host(
        tester,
        canvas(
          data,
          change: (v) {
            writes++;
            data = v;
          },
        ),
      );
      await tester.tapAt(at(tester, const CanvasPoint(80, 80)));
      await tester.pump();
      final firstWrite = Completer<void>();
      var copies = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copies++;
            if (copies == 1) await firstWrite.future;
          }
          return null;
        },
      );
      await command(tester, LogicalKeyboardKey.keyX);
      await command(tester, LogicalKeyboardKey.keyC);
      firstWrite.complete();
      await tester.pumpAndSettle();
      expect(copies, 2);
      expect(writes, 0);
      expect(painter(tester).scene.elements, hasLength(1));
    },
  );

  testWidgets('late object drag refuses a disappeared source', (tester) async {
    var writes = 0;
    await host(tester, canvas(board([]), change: (_) => writes++));
    final drop = tester.widget<DragTarget<Object>>(
      find.byType(DragTarget<Object>),
    );
    final details = DragTargetDetails<Object>(
      data: (path: 'Notes/deleted.md', noteId: 'missing'),
      offset: at(tester, const CanvasPoint(350, 250)),
    );
    expect(drop.onWillAcceptWithDetails!(details), false);
    drop.onAcceptWithDetails!(details);
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(painter(tester).scene.elements, isEmpty);
  });

  testWidgets('pending image paste yields to a newer clipboard read', (
    tester,
  ) async {
    final image = Completer<CanvasImageReference?>();
    var writes = 0;
    await host(
      tester,
      canvas(
        board([]),
        change: (_) => writes++,
        pasteImage: () => image.future,
      ),
    );
    await tester.tapAt(at(tester, const CanvasPoint(400, 300)));
    await command(tester, LogicalKeyboardKey.keyV);
    clipboard = 'Newer text';
    readGate = Completer<void>();
    await command(tester, LogicalKeyboardKey.keyV);
    image.complete(
      const CanvasImageReference(contentRef: 'Attachments/older.png'),
    );
    await tester.pumpAndSettle();
    expect(writes, 0);
    readGate!.complete();
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(painter(tester).scene.elements.single.text, 'Newer text');
  });

  for (final imagePaste in [false, true]) {
    testWidgets(
      'slow ${imagePaste ? 'image' : 'text'} paste retains its original world position while panning',
      (tester) async {
        final image = Completer<CanvasImageReference?>();
        await host(tester, canvas(board([]), pasteImage: () => image.future));
        await tester.tapAt(at(tester, const CanvasPoint(400, 300)));
        final viewport = tester.getSize(surface);
        final center = painter(
          tester,
        ).camera.toWorld(CanvasPoint(viewport.width / 2, viewport.height / 2));
        if (!imagePaste) {
          clipboard = 'Text';
          readGate = Completer<void>();
        }
        await command(tester, LogicalKeyboardKey.keyV);
        final pan = await tester.startGesture(
          at(tester, const CanvasPoint(400, 300)),
          kind: PointerDeviceKind.mouse,
          buttons: kMiddleMouseButton,
        );
        await pan.moveBy(const Offset(100, 60));
        await pan.up();
        await tester.pumpAndSettle();
        if (imagePaste) {
          image.complete(
            const CanvasImageReference(
              contentRef: 'Attachments/a.png',
              width: 100,
              height: 80,
            ),
          );
        } else {
          readGate!.complete();
        }
        await tester.pumpAndSettle();
        final placed = painter(tester).scene.elements.single;
        expect(placed.x + placed.width / 2, center.x);
        expect(placed.y + placed.height / 2, center.y);
      },
    );
  }

  testWidgets(
    'image selection changes and invalid image results retain the original selection',
    (tester) async {
      final pending = Completer<CanvasImageReference?>();
      var loads = 0, writes = 0;
      await host(
        tester,
        canvas(
          board([
            rectangle('a'),
            {...rectangle('b'), 'x': 300.0},
          ]),
          change: (_) => writes++,
          pasteImage: () async => ++loads == 1
              ? await pending.future
              : const CanvasImageReference(contentRef: '', width: 0),
        ),
      );
      await tester.tapAt(at(tester, const CanvasPoint(80, 80)));
      await tester.pump();
      await command(tester, LogicalKeyboardKey.keyV);
      await tester.tapAt(at(tester, const CanvasPoint(330, 80)));
      await tester.pump();
      pending.complete(
        const CanvasImageReference(contentRef: 'Attachments/a.png'),
      );
      await tester.pumpAndSettle();
      expect(painter(tester).selection, {'b'});
      expect(writes, 0);
      // The earlier stale-load notice owns the current snackbar until it ends.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await command(tester, LogicalKeyboardKey.keyV);
      await tester.pumpAndSettle();
      expect(painter(tester).selection, {'b'});
      expect(writes, 0);
      expect(
        find.textContaining('no valid source or dimensions'),
        findsOneWidget,
      );
    },
  );

  Future<void> menu(WidgetTester tester, CanvasPoint point) async {
    final gesture = await tester.startGesture(
      at(tester, point),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('context Paste centers text at the chosen board location', (
    tester,
  ) async {
    await host(tester, canvas(board([])));
    clipboard = 'Here';
    await menu(tester, const CanvasPoint(350, 300));
    await tester.ensureVisible(find.text('Paste'));
    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle();
    final placed = painter(tester).scene.elements.single;
    expect(placed.x + placed.width / 2, 350);
    expect(placed.y + placed.height / 2, 300);
  });
  testWidgets('an old context menu cannot add to a different board', (
    tester,
  ) async {
    var owner = 'a', writes = 0;
    late StateSetter refresh;
    await host(
      tester,
      StatefulBuilder(
        builder: (_, update) {
          refresh = update;
          return canvas(board([]), owner: owner, change: (_) => writes++);
        },
      ),
    );
    await menu(tester, const CanvasPoint(350, 300));
    refresh(() => owner = 'b');
    await tester.pump();
    await tester.tap(find.text('Add Text'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(painter(tester).scene.elements, isEmpty);
  });

  testWidgets(
    'Canvas alignment menu wraps at narrow width and 200 percent text',
    (tester) async {
      await prepareCapture(tester);
      await host(
        tester,
        canvas(
          board([
            rectangle('a'),
            {...rectangle('b'), 'x': 260.0},
            {...rectangle('c'), 'x': 480.0},
          ]),
        ),
        size: const Size(390, 844),
        scale: 2,
      );
      await tester.tapAt(at(tester, const CanvasPoint(200, 300)));
      await command(tester, LogicalKeyboardKey.keyA);
      final align = find.byTooltip('Align selected elements');
      await tester.ensureVisible(align);
      await tester.tap(align);
      await tester.pumpAndSettle();
      expect(find.text('Distribute Horizontally'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await captureUi(tester, 'canvas-align-large-text');
      await tester.tap(find.text('Align Left'));
      await tester.pumpAndSettle();
      expect(painter(tester).scene['b']!.x, 40);
      expect(painter(tester).scene['c']!.x, 40);
    },
  );

  testWidgets(
    'Canvas selection and copy remain usable at narrow width and 200 percent text',
    (tester) async {
      await prepareCapture(tester);
      await host(
        tester,
        canvas(board([rectangle('a')])),
        size: const Size(390, 844),
        scale: 2,
      );
      await tester.tapAt(at(tester, const CanvasPoint(200, 300)));
      await command(tester, LogicalKeyboardKey.keyA);
      await command(tester, LogicalKeyboardKey.keyC);
      await tester.pumpAndSettle();
      expect(clipboard, contains(canvasClipboardPrefix));
      expect(painter(tester).selection, {'a'});
      final status = tester.getRect(
        find.text('1 selected · Delete removes placements'),
      );
      expect(status.left, greaterThanOrEqualTo(0));
      expect(status.right, lessThanOrEqualTo(390));
      expect(tester.takeException(), isNull);
      await captureUi(tester, 'canvas-transfer-large-text');
    },
  );

  test(
    'mixed unsupported shapes never partially erase a transferred selection',
    () {
      expect(
        canvasClipboardMarkdown(
          payload([
            {'id': 'text', 'type': 'sticky', 'text': 'Remember'},
            {...rectangle('diagram'), 'text': 'Diagram'},
            {'id': 'image', 'type': 'image', 'contentRef': 'Attachments/a.png'},
          ]),
        ),
        isNull,
      );
    },
  );
}
