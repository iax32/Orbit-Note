import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/canvas/connectors.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';

void main() {
  String clipboard = '';
  Completer<void>? readGate, writeGate;
  bool failWrite = false;
  setUp(() {
    clipboard = '';
    failWrite = false;
    readGate = writeGate = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        final captured = clipboard;
        await readGate?.future;
        return call.arguments == 'text/html' ? null : {'text': captured};
      }
      if (call.method == 'Clipboard.setData') {
        if (failWrite) throw PlatformException(code: 'denied');
        await writeGate?.future;
        clipboard = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('pasteboard'),
      (_) async => null,
    );
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(const MethodChannel('pasteboard'), null);
  });
  Future<void> command(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool shift = false,
  }) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
  }

  for (final cut in [true, false]) {
    testWidgets(
      'pending Source ${cut ? 'cut' : 'paste'} respects new read-only state',
      (tester) async {
        final readOnly = ValueNotifier(false);
        addTearDown(readOnly.dispose);
        final edits = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder(
                valueListenable: readOnly,
                builder: (_, value, _) => NoteEditor(
                  noteId: 'note',
                  title: 'Note',
                  body: 'Original',
                  viewOnly: value,
                  initialViewState: const {'mode': 'write'},
                  spellCheckEnabled: false,
                  onBodyChanged: edits.add,
                  onTitleChanged: (_) {},
                  onOpenObject: (_) {},
                  linkTargets: const [],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final field = find.byKey(const ValueKey('note-body'));
        await tester.tap(field);
        await tester.pumpAndSettle();
        tester.widget<TextField>(field).controller!.selection =
            const TextSelection(baseOffset: 0, extentOffset: 4);
        clipboard = 'Replacement';
        if (cut) {
          writeGate = Completer<void>();
        } else {
          readGate = Completer<void>();
        }
        await command(
          tester,
          cut ? LogicalKeyboardKey.keyX : LogicalKeyboardKey.keyV,
        );
        readOnly.value = true;
        await tester.pump();
        (cut ? writeGate : readGate)!.complete();
        await tester.pumpAndSettle();
        expect(edits, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final blocks in [false, true]) {
    testWidgets(
      'pending ${blocks ? 'block' : 'text range'} cut cannot delete another identical note',
      (tester) async {
        final owner = ValueNotifier('first');
        addTearDown(owner.dispose);
        final edits = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<String>(
                valueListenable: owner,
                builder: (context, id, _) => RichMarkdownEditor(
                  noteId: id,
                  body: 'First paragraph\n\nSecond paragraph',
                  onChanged: (value) => edits.add('$id:$value'),
                  onUndo: () {},
                  onRedo: () {},
                  linkTargets: const [],
                  linkBindings: const {},
                  onOpenLink: (_) {},
                  spellCheckEnabled: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final editor = tester.state<RichMarkdownEditorState>(
          find.byType(RichMarkdownEditor),
        );
        if (blocks) {
          editor.selectBlockRange(0, 2);
        } else {
          editor.selectDocumentRange(2, 24);
        }
        await tester.pumpAndSettle();
        writeGate = Completer<void>();
        final pending = blocks
            ? editor.cutSelectedBlocks()
            : editor.cutCrossDocumentSelection();
        await tester.pump();
        owner.value = 'second';
        await tester.pump();
        writeGate!.complete();
        await pending;
        await tester.pumpAndSettle();
        expect(edits, isEmpty);
      },
    );
  }
  testWidgets('pending Source cut cannot delete same text in another note', (
    tester,
  ) async {
    final owner = ValueNotifier('first');
    addTearDown(owner.dispose);
    final edits = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<String>(
            valueListenable: owner,
            builder: (context, id, _) => NoteEditor(
              noteId: id,
              title: 'Note',
              body: 'Identical text',
              initialViewState: const {'mode': 'write', 'base': 0, 'extent': 9},
              onBodyChanged: (value) => edits.add('$id:$value'),
              onTitleChanged: (_) {},
              linkTargets: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Finder bodyField() => find.byWidgetPredicate(
      (w) => w is TextField && w.controller?.text == 'Identical text',
    );
    await tester.tap(bodyField());
    await tester.pumpAndSettle();
    final controller = tester.widget<TextField>(bodyField()).controller!;
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 9);
    writeGate = Completer<void>();
    await command(tester, LogicalKeyboardKey.keyX);
    owner.value = 'second';
    await tester.pump();
    writeGate!.complete();
    await tester.pumpAndSettle();
    expect(edits, isEmpty);
  });
  testWidgets('plain document paste retains Canvas payload as literal source', (
    tester,
  ) async {
    var body = 'First\n\nSecond';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => RichMarkdownEditor(
              noteId: 'note',
              body: body,
              onChanged: (v) => update(() => body = v),
              onUndo: () {},
              onRedo: () {},
              linkTargets: const [],
              linkBindings: const {},
              onOpenLink: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final editor = tester.state<RichMarkdownEditorState>(
      find.byType(RichMarkdownEditor),
    );
    editor.selectDocumentRange(0, body.length);
    clipboard =
        'orbit-canvas/1\n${jsonEncode({
          'elements': [
            {'id': 'a', 'type': 'image', 'contentRef': 'Attachments/a.png', 'x': 0, 'y': 0},
          ],
        })}';
    await tester.pump();
    await editor.pasteDocumentSelection(plain: true);
    await tester.pumpAndSettle();
    expect(body, clipboard);
  });

  Map<String, dynamic> sticky(String id) => {
    'id': id,
    'type': 'sticky',
    'text': id,
    'x': 10,
    'y': 10,
  };
  String payload(List<dynamic> elements) =>
      'orbit-canvas/1\n${jsonEncode({'elements': elements})}';

  for (final cut in [false, true]) {
    for (final returnToOriginal in [false, true]) {
      testWidgets(
        'pending table ${cut ? 'cut' : 'paste'} refuses identical note switch${returnToOriginal ? ' and return' : ''}',
        (tester) async {
          final owner = ValueNotifier('first');
          addTearDown(owner.dispose);
          final writes = <String>[];
          const source = '| A | B |\n| --- | --- |\n| One | Two |\n';
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ValueListenableBuilder<String>(
                  valueListenable: owner,
                  builder: (context, id, _) => RichMarkdownEditor(
                    noteId: id,
                    body: source,
                    onChanged: (v) => writes.add('$id:$v'),
                    onUndo: () {},
                    onRedo: () {},
                    linkTargets: const [],
                    linkBindings: const {},
                    onOpenLink: (_) {},
                    spellCheckEnabled: false,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final field = find.byKey(const ValueKey('rich-cell-1-0'));
          await tester.tap(field);
          await tester.pumpAndSettle();
          final controller = tester.widget<TextField>(field).controller!;
          controller.selection = const TextSelection(
            baseOffset: 0,
            extentOffset: 3,
          );
          if (cut) {
            writeGate = Completer<void>();
            await command(tester, LogicalKeyboardKey.keyX);
          } else {
            readGate = Completer<void>();
            clipboard = 'Replacement';
            await command(tester, LogicalKeyboardKey.keyV);
          }
          owner.value = 'second';
          await tester.pump();
          if (returnToOriginal) {
            owner.value = 'first';
            await tester.pump();
          }
          if (cut) {
            writeGate!.complete();
          } else {
            readGate!.complete();
          }
          await tester.pumpAndSettle();
          expect(writes, isEmpty);
          expect(tester.widget<TextField>(field).controller!.text, 'One');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  Future<void> board(
    WidgetTester tester,
    ValueNotifier<Map<String, dynamic>> data,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<Map<String, dynamic>>(
            valueListenable: data,
            builder: (context, value, _) => CanvasEditor(
              canvasId: 'board',
              data: value,
              objects: const [],
              onOpenObject: (_) {},
              onChanged: (v) => data.value = v,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
      ),
    );
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> connectedBoard() => {
    'schemaVersion': 1,
    'backgroundStyle': 'dots',
    'extension': {'kept': true},
    'elements': [
      {
        'id': 'a',
        'type': 'rectangle',
        'x': 10.0,
        'y': 40.0,
        'width': 100.0,
        'height': 80.0,
      },
      {
        'id': 'b',
        'type': 'rectangle',
        'x': 310.0,
        'y': 40.0,
        'width': 100.0,
        'height': 80.0,
      },
      {
        'id': 'link',
        'type': 'connector',
        'startId': 'a',
        'endId': 'b',
        'startAnchor': 'right',
        'endAnchor': 'left',
        'startX': 0.0,
        'startY': 0.0,
        'endX': 0.0,
        'endY': 0.0,
        'custom': ['keep'],
        'routing': 'straight',
      },
    ],
  };

  testWidgets(
    'unfamiliar connector field types render and hit-test without losing source',
    (tester) async {
      final initial = {
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'future-connector',
            'type': 'connector',
            'startId': ['future'],
            'endId': 42,
            'startAnchor': {'custom': true},
            'endAnchor': false,
            'routing': 9,
            'startX': 20.0,
            'startY': 80.0,
            'endX': 320.0,
            'endY': 80.0,
          },
        ],
      };
      final data = ValueNotifier<Map<String, dynamic>>(initial);
      addTearDown(data.dispose);
      await board(tester, data);
      expect(tester.takeException(), isNull);
      final scene = CanvasScene.fromJson(initial);
      final connector = scene['future-connector']!;
      final endpoints = resolveConnectorEndpoints(connector, scene);
      expect(endpoints.start.x, 20);
      expect(endpoints.end.x, 320);
      expect(
        hitTestConnector(
          connector,
          scene,
          const CanvasPoint(100, 80),
          tolerance: 5,
        ),
        isTrue,
      );
      expect(data.value, initial);
    },
  );

  testWidgets(
    'duplicated connected nodes link to the duplicates and undo together',
    (tester) async {
      final original = connectedBoard();
      final data = ValueNotifier<Map<String, dynamic>>(original);
      addTearDown(data.dispose);
      await board(tester, data);
      await command(tester, LogicalKeyboardKey.keyA);
      await command(tester, LogicalKeyboardKey.keyD);
      await tester.pumpAndSettle();
      final scene = CanvasScene.fromJson(data.value);
      final elements = scene.toJson()['elements'] as List;
      final copies = elements
          .whereType<Map>()
          .where((e) => !{'a', 'b', 'link'}.contains(e['id']))
          .toList();
      expect(copies, hasLength(3));
      final link = CanvasElement(
        Map<String, dynamic>.from(
          copies.singleWhere((e) => e['type'] == 'connector'),
        ),
      );
      final left = copies.singleWhere(
        (e) => e['type'] == 'rectangle' && e['x'] == 30.0,
      );
      final right = copies.singleWhere(
        (e) => e['type'] == 'rectangle' && e['x'] == 330.0,
      );
      expect(link.startId, left['id']);
      expect(link.endId, right['id']);
      expect(link.data['custom'], ['keep']);
      final endpoints = resolveConnectorEndpoints(link, scene);
      expect(endpoints.start.x, 130);
      expect(endpoints.start.y, 100);
      expect(endpoints.end.x, 330);
      expect(endpoints.end.y, 100);
      await command(tester, LogicalKeyboardKey.keyZ);
      await tester.pumpAndSettle();
      expect(data.value, original);
      await command(tester, LogicalKeyboardKey.keyY);
      await tester.pumpAndSettle();
      expect((data.value['elements'] as List), hasLength(6));
    },
  );

  for (final type in ['line', 'arrow', 'connector']) {
    testWidgets('duplicate free $type offsets visible endpoints and undoes', (
      tester,
    ) async {
      final original = <String, dynamic>{
        'schemaVersion': 1,
        'backgroundStyle': 'dots',
        'elements': [
          {
            'id': 'free',
            'type': type,
            'x': 20.0,
            'y': 80.0,
            'width': 300.0,
            'height': 0.0,
            'startX': 20.0,
            'startY': 80.0,
            'endX': 320.0,
            'endY': 80.0,
            'custom': ['keep'],
          },
        ],
      };
      final data = ValueNotifier(original);
      addTearDown(data.dispose);
      await board(tester, data);
      await command(tester, LogicalKeyboardKey.keyA);
      await command(tester, LogicalKeyboardKey.keyD);
      await tester.pumpAndSettle();
      final scene = CanvasScene.fromJson(data.value);
      final duplicate = (scene.toJson()['elements'] as List)
          .whereType<Map>()
          .singleWhere((e) => e['id'] != 'free');
      final endpoints = resolveConnectorEndpoints(
        CanvasElement(Map<String, dynamic>.from(duplicate)),
        scene,
      );
      expect(endpoints.start.x, 40);
      expect(endpoints.start.y, 100);
      expect(endpoints.end.x, 340);
      expect(endpoints.end.y, 100);
      expect(duplicate['custom'], ['keep']);
      await command(tester, LogicalKeyboardKey.keyZ);
      await tester.pumpAndSettle();
      expect(data.value, original);
    });
  }

  testWidgets(
    'copied connector stores visible endpoint geometry for detached paste',
    (tester) async {
      final original = connectedBoard();
      final data = ValueNotifier<Map<String, dynamic>>(original);
      addTearDown(data.dispose);
      await board(tester, data);
      final surface = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
      );
      final painter =
          tester.widget<CustomPaint>(surface).painter! as OrbitCanvasPainter;
      final point = painter.camera.toScreen(const CanvasPoint(210, 80));
      await tester.tapAt(tester.getTopLeft(surface) + Offset(point.x, point.y));
      await command(tester, LogicalKeyboardKey.keyC);
      await tester.pumpAndSettle();
      final captured =
          jsonDecode(clipboard.substring('orbit-canvas/1\n'.length)) as Map;
      final link = (captured['elements'] as List).whereType<Map>().singleWhere(
        (e) => e['id'] == 'link',
      );
      expect(link['startX'], 110);
      expect(link['startY'], 80);
      expect(link['endX'], 310);
      expect(link['endY'], 80);
      clipboard = payload([link]);
      await command(tester, LogicalKeyboardKey.keyV);
      await tester.pumpAndSettle();
      final pasted = (data.value['elements'] as List)
          .whereType<Map>()
          .singleWhere((e) => e['type'] == 'connector' && e['id'] != 'link');
      expect(pasted['startId'], isNull);
      expect(pasted['endId'], isNull);
      expect(pasted['startX'], 142);
      expect(pasted['startY'], 112);
      expect(pasted['endX'], 342);
      expect(pasted['endY'], 112);
      expect(pasted['custom'], ['keep']);
      await command(tester, LogicalKeyboardKey.keyZ);
      await tester.pumpAndSettle();
      expect(data.value, original);
    },
  );

  for (final bad in ['duplicate', 'unsupported', 'non-map']) {
    testWidgets('Canvas rejects $bad payload atomically', (tester) async {
      final initial = {
        'schemaVersion': 1,
        'elements': [sticky('existing')],
      };
      final data = ValueNotifier<Map<String, dynamic>>(initial);
      addTearDown(data.dispose);
      await board(tester, data);
      clipboard = payload([
        sticky('a'),
        switch (bad) {
          'duplicate' => sticky('a'),
          'unsupported' => {'id': 'b', 'type': 'future-widget', 'x': 0, 'y': 0},
          _ => 'broken',
        },
      ]);
      await command(tester, LogicalKeyboardKey.keyV);
      await tester.pumpAndSettle();
      expect(data.value, initial);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('delayed Canvas paste cannot reinsert after a newer delete', (
    tester,
  ) async {
    final data = ValueNotifier<Map<String, dynamic>>({
      'schemaVersion': 1,
      'elements': [sticky('existing')],
    });
    addTearDown(data.dispose);
    await board(tester, data);
    clipboard = 'Delayed text';
    readGate = Completer<void>();
    await command(tester, LogicalKeyboardKey.keyV);
    await command(tester, LogicalKeyboardKey.keyA);
    await command(tester, LogicalKeyboardKey.delete);
    expect(data.value['elements'], isEmpty);
    readGate!.complete();
    await tester.pumpAndSettle();
    expect(data.value['elements'], isEmpty);
  });
  test(
    'invalid Canvas text and section styles have safe render values and preserve source',
    () {
      for (final value in [-50.0, double.infinity, double.nan]) {
        final element = CanvasElement({
          ...sticky('s'),
          'type': 'section',
          'fontSize': value,
          'strokeWidth': value,
        });
        expect(element.sectionFontSize.isFinite, isTrue);
        expect(element.sectionFontSize, greaterThan(0));
        expect(element.sectionStrokeWidth.isFinite, isTrue);
        expect(element.sectionStrokeWidth, greaterThanOrEqualTo(0));
        expect(element.data['fontSize'], value.isNaN ? isNaN : value);
      }
    },
  );
  for (final mode in ['rich', 'write']) {
    testWidgets(
      '$mode keyboard cut waits for success and preserves text on clipboard denial',
      (tester) async {
        var body = '**Keep** this text';
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, update) => NoteEditor(
                  noteId: 'safe-cut',
                  title: 'Note',
                  body: body,
                  initialViewState: {'mode': mode},
                  onBodyChanged: (v) => update(() => body = v),
                  onTitleChanged: (_) {},
                  linkTargets: const [],
                  onOpenObject: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final f = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.controller?.text == (mode == 'rich' ? 'Keep this text' : body),
        );
        await tester.tap(f);
        await tester.pumpAndSettle();
        final c = tester.widget<TextField>(f).controller!;
        c.selection = const TextSelection(baseOffset: 0, extentOffset: 4);
        failWrite = true;
        await command(tester, LogicalKeyboardKey.keyX);
        await tester.pumpAndSettle();
        expect(body, '**Keep** this text');
        failWrite = false;
        writeGate = Completer<void>();
        await command(tester, LogicalKeyboardKey.keyX);
        expect(body, '**Keep** this text');
        writeGate!.complete();
        await tester.pumpAndSettle();
        expect(body, mode == 'rich' ? ' this text' : 'ep** this text');
        await command(tester, LogicalKeyboardKey.keyZ);
        await tester.pumpAndSettle();
        expect(body, '**Keep** this text');
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final failed in [false, true]) {
    testWidgets(
      'pending Canvas image ${failed ? 'failure' : 'board switch'} adds no wrong placement',
      (tester) async {
        final owner = ValueNotifier('first');
        addTearDown(owner.dispose);
        final image = Completer<CanvasImageReference?>();
        final edits = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<String>(
                valueListenable: owner,
                builder: (context, id, _) => CanvasEditor(
                  canvasId: id,
                  data: const {'schemaVersion': 1, 'elements': []},
                  objects: const [],
                  onOpenObject: (_) {},
                  onChanged: (v) => edits.add(id),
                  onPasteImage: () => image.future,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
          ),
        );
        await command(tester, LogicalKeyboardKey.keyV);
        await tester.pump();
        if (failed) {
          image.completeError(StateError('Failed image'));
        } else {
          owner.value = 'second';
          await tester.pump();
          image.complete(
            const CanvasImageReference(contentRef: 'Attachments/a.png'),
          );
        }
        await tester.pumpAndSettle();
        expect(edits, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('returning to the original note cannot revive a pending cut', (
    tester,
  ) async {
    final owner = ValueNotifier('first');
    addTearDown(owner.dispose);
    final edits = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<String>(
            valueListenable: owner,
            builder: (context, id, _) => RichMarkdownEditor(
              noteId: id,
              body: 'One\n\nTwo',
              onChanged: edits.add,
              onUndo: () {},
              onRedo: () {},
              linkTargets: const [],
              linkBindings: const {},
              onOpenLink: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final editor = tester.state<RichMarkdownEditorState>(
      find.byType(RichMarkdownEditor),
    );
    editor.selectDocumentRange(0, 8);
    await tester.pump();
    writeGate = Completer<void>();
    final cut = editor.cutCrossDocumentSelection();
    await tester.pump();
    owner.value = 'second';
    await tester.pump();
    owner.value = 'first';
    await tester.pump();
    editor.selectDocumentRange(0, 8);
    await tester.pump();
    writeGate!.complete();
    await cut;
    await tester.pumpAndSettle();
    expect(edits, isEmpty);
  });

  testWidgets(
    'older Canvas clipboard completion cannot duplicate a newer paste',
    (tester) async {
      final data = ValueNotifier<Map<String, dynamic>>({
        'schemaVersion': 1,
        'elements': [],
      });
      addTearDown(data.dispose);
      await board(tester, data);
      clipboard = 'Old';
      final gate = Completer<void>();
      readGate = gate;
      await command(tester, LogicalKeyboardKey.keyV);
      clipboard = 'New';
      readGate = null;
      await command(tester, LogicalKeyboardKey.keyV);
      await tester.pumpAndSettle();
      gate.complete();
      await tester.pumpAndSettle();
      expect((data.value['elements'] as List).map((v) => (v as Map)['text']), [
        'New',
      ]);
      await command(tester, LogicalKeyboardKey.keyZ);
      await tester.pumpAndSettle();
      expect(data.value['elements'], isEmpty);
    },
  );

  testWidgets('invalid Canvas paste retains selection and existing undo', (
    tester,
  ) async {
    final data = ValueNotifier<Map<String, dynamic>>({
      'schemaVersion': 1,
      'elements': [sticky('existing')],
    });
    addTearDown(data.dispose);
    await board(tester, data);
    await command(tester, LogicalKeyboardKey.keyA);
    clipboard = payload([sticky('a'), 'invalid']);
    await command(tester, LogicalKeyboardKey.keyV);
    await tester.pumpAndSettle();
    await command(tester, LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(data.value['elements'], isEmpty);
    await command(tester, LogicalKeyboardKey.keyZ);
    await tester.pumpAndSettle();
    expect((data.value['elements'] as List).single['id'], 'existing');
  });
}
