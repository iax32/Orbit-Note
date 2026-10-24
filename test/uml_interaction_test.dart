import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/canvas/canvas_search.dart';
import 'package:orbit_note/canvas/canvas_svg.dart';
import 'package:orbit_note/canvas/connectors.dart';
import 'package:orbit_note/canvas/diagram_reference.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/canvas/uml_interaction.dart';
import 'package:orbit_note/domain/note_composition.dart';
import 'package:orbit_note/domain/publication_objects.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_diagram_preview.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/features/canvas/uml_interaction_dialog.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/export/publication_canvas.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';

Map<String, dynamic> starter(bool sequence) {
  var i = 0;
  return {
    'schemaVersion': 1,
    'futureRoot': 42,
    'elements': (sequence ? sequenceStarter : useCaseStarter)(
      () => 'node-${i++}',
      const CanvasPoint(40, 40),
    ).map((e) => e.data).toList(),
  };
}

Future<void> menu(WidgetTester t, String label) async {
  await t.ensureVisible(find.byTooltip('Use-case and sequence diagrams'));
  await t.tap(find.byTooltip('Use-case and sequence diagrams'));
  await t.pumpAndSettle();
  await t.ensureVisible(find.text(label));
  await t.tap(find.text(label));
  await t.pumpAndSettle();
}

Future<void> key(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await t.sendKeyEvent(k);
  await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await t.pumpAndSettle();
}

Future<void> host(
  WidgetTester t,
  Map<String, dynamic> data,
  ValueChanged<Map<String, dynamic>> change, {
  bool readOnly = false,
}) async {
  t.view.physicalSize = const Size(1360, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      theme: orbitDarkTheme(),
      home: Scaffold(
        body: CanvasEditor(
          canvasId: 'board',
          data: data,
          onChanged: change,
          objects: const [],
          onOpenObject: (_) {},
          readOnly: readOnly,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  test(
    'zero and subpixel imported UML geometry remains renderable without invalid clamps',
    () {
      for (final size in [0.0, .5, 1.0]) {
        final scene = CanvasScene.fromJson({
          'elements': [
            for (final kind in UmlNodeKind.values)
              newInteractionNode(
                kind.name,
                kind,
                const CanvasPoint(0, 0),
              ).copy({'width': size, 'height': size}).data,
          ],
        });
        for (final e in scene.elements) {
          expect(e.renderable, true);
          final glyph = interactionGlyph(e);
          for (final path in glyph.paths) {
            expect(
              path.points.every((p) => p.x.isFinite && p.y.isFinite),
              true,
            );
          }
        }
        expect(canvasToSvg(scene), startsWith('<?xml'));
      }
    },
  );
  test(
    'every use-case relationship enforces endpoint semantics and preserves unknown metadata',
    () {
      final nodes = [
        for (final k in UmlNodeKind.values)
          newInteractionNode(k.name, k, const CanvasPoint(0, 0)),
        newInteractionNode(
          'otherCase',
          UmlNodeKind.useCase,
          const CanvasPoint(300, 0),
        ),
        newInteractionNode(
          'otherActor',
          UmlNodeKind.actor,
          const CanvasPoint(0, 300),
        ),
      ];
      final edge = CanvasElement({
        'id': 'edge',
        'type': 'connector',
        'future': 42,
        'umlLink': {'futureLink': true},
      });
      for (final (kind, a, b) in [
        (UmlLinkKind.association, 'actor', 'useCase'),
        (UmlLinkKind.include, 'useCase', 'otherCase'),
        (UmlLinkKind.extend, 'otherCase', 'useCase'),
        (UmlLinkKind.generalization, 'actor', 'otherActor'),
        (UmlLinkKind.generalization, 'useCase', 'otherCase'),
        (UmlLinkKind.constraint, 'note', 'useCase'),
      ]) {
        final result = edge.copy(
          editInteractionLink(
            edge,
            nodes,
            kind: kind,
            from: a,
            to: b,
            detail: '[ready]',
            fromMultiplicity: '1',
            toMultiplicity: '2',
          ),
        );
        expect(result.data['future'], 42);
        expect((result.data['umlLink'] as Map)['futureLink'], true);
        expect(result.endId, b);
        expect(result.endMarker, kind.marker);
        if ([UmlLinkKind.include, UmlLinkKind.extend].contains(kind)) {
          expect(result.text, '«${kind.name}»\n[ready]');
          expect(result.strokeStyle, 'dashed');
        }
      }
      for (final kind in UmlLinkKind.values) {
        expect(
          () => editInteractionLink(
            edge,
            nodes,
            kind: kind,
            from: 'system',
            to: 'activation',
          ),
          throwsFormatException,
        );
        expect(
          () => editInteractionLink(
            edge,
            nodes,
            kind: kind,
            from: 'missing',
            to: 'useCase',
          ),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'all shapes and combined operators survive JSON, searches and portable SVG',
    () {
      final elements = <CanvasElement>[];
      var n = 0;
      for (final kind in UmlNodeKind.values) {
        final e = newInteractionNode(
          'n-${n++}',
          kind,
          CanvasPoint(n * 200, 20),
        );
        elements.add(
          e.copy(
            editInteractionNode(
              e,
              name: kind == UmlNodeKind.activation ? '' : 'A < B & C 🛰',
              stereotype: 'external',
              lines: '[ready]\n[else]',
              destroyed: true,
            ),
          ),
        );
      }
      for (final op in umlFragmentOperators) {
        final e = newInteractionNode(
          'n-${n++}',
          UmlNodeKind.fragment,
          CanvasPoint(n * 200, 400),
        );
        elements.add(
          e.copy(
            editInteractionNode(
              e,
              name: '{n}',
              operator: op,
              lines: '[x == 5]\n[else]',
            ),
          ),
        );
      }
      final scene = CanvasScene.fromJson(
        jsonDecode(
          jsonEncode({
            'futureRoot': true,
            'elements': elements.map((e) => e.data).toList(),
          }),
        ),
      );
      expect(scene.length, elements.length);
      expect(scene.toJson()['futureRoot'], true);
      for (final e in scene.elements) {
        expect(e.renderable, true);
        expect(
          interactionGlyph(e).texts.isNotEmpty ||
              umlNodeKind(e) == UmlNodeKind.activation,
          true,
        );
      }
      expect(
        searchCanvasElements(
          scene: scene,
          objectLookup: const MapCanvasObjectLookup({}),
          query: 'external',
        ),
        isNotEmpty,
      );
      for (final color in [0xff141418, 0xfffaf8ef, 0xff173631]) {
        final svg = canvasToSvg(scene, backgroundColor: color);
        expect(svg, contains('A &lt; B &amp; C 🛰'));
        expect(svg, contains('stroke-dasharray="8,5"'));
        expect(svg, contains('extension points'));
        for (final op in umlFragmentOperators) {
          expect(svg, contains('>$op</text>'));
        }
      }
    },
  );

  test(
    'sequence message geometry, markers, self calls and creation/destruction track lifelines',
    () {
      final scene = CanvasScene.fromJson(starter(true));
      final a = scene['node-0']!, b = scene['node-1']!;
      for (final kind in UmlLinkKind.values.where((k) => k.sequence)) {
        final e = CanvasElement({'id': 'message', 'type': 'connector'});
        final edge = e.copy(
          editInteractionLink(
            e,
            [a, b],
            kind: kind,
            from: a.id,
            to: b.id,
            position: .4,
            label: 'x(123)',
          ),
        );
        final p = resolveConnectorEndpoints(edge, scene);
        expect(p.start.x, a.bounds.center.x);
        expect(p.end.x, kind == UmlLinkKind.create ? b.x : b.bounds.center.x);
        expect(edge.endMarker, kind.marker);
        scene.put(edge);
        final before = p.end;
        scene.put(b.translated(const CanvasPoint(40, 30)));
        final after = resolveConnectorEndpoints(edge, scene).end;
        expect(after, before + const CanvasPoint(40, 30));
        expect(
          scene.query(CanvasBounds(after.x, after.y, 1, 1)).map((e) => e.id),
          contains(edge.id),
        );
        scene.put(b);
      }
      final self = scene['node-3']!;
      final p = resolveConnectorEndpoints(self, scene);
      expect(p.controlPoints, hasLength(2));
      expect(p.end.y, greaterThan(p.start.y));
      expect(hitTestConnector(self, scene, p.controlPoints.first), true);
      for (final kind in [UmlLinkKind.create, UmlLinkKind.destroy]) {
        expect(
          () => editInteractionLink(
            self,
            [a, b],
            kind: kind,
            from: a.id,
            to: a.id,
          ),
          throwsFormatException,
        );
      }
      expect(canvasToSvg(scene), contains('<polygon'));
    },
  );

  test(
    'hollow boundaries do not intercept interior selection and oval arrows meet the perimeter',
    () {
      final scene = CanvasScene.fromJson(starter(false));
      final boundary = scene['node-0']!, useCase = scene['node-2']!;
      scene.bringToFront(boundary.id);
      expect(scene.hit(useCase.bounds.center)?.id, useCase.id);
      expect(
        scene.hit(CanvasPoint(boundary.x + 10, boundary.y + 10))?.id,
        boundary.id,
      );
      final edge = scene['node-7']!;
      final end = resolveConnectorEndpoints(edge, scene).end;
      final delta = end - useCase.bounds.center;
      expect(
        delta.x * delta.x / (useCase.width * useCase.width / 4) +
            delta.y * delta.y / (useCase.height * useCase.height / 4),
        closeTo(1, .001),
      );
    },
  );

  test(
    'native restart retains both diagram kinds, unknown data and live Markdown references',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-interaction-');
      final repo = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: MemoryObjectIndex(),
      );
      try {
        await repo.initialize(path: root.path);
        for (final seq in [false, true]) {
          final source = await repo.create(
            typeId: 'orbit.canvas',
            title: 'UML $seq',
            data: starter(seq),
          );
          final scene = CanvasScene.fromJson(source.data);
          final ids = diagramExportSelection(scene, []);
          final note = await repo.create(
            typeId: 'orbit.note',
            title: 'Linked',
            body: diagramMarkdown(source.id, 'Diagram', ids),
          );
          await repo.close();
          await repo.initialize(path: root.path);
          final reopened = repo.objects.singleWhere((o) => o.id == source.id);
          expect(reopened.data, source.data);
          final savedNote = repo.objects.singleWhere((o) => o.id == note.id);
          final ref = NoteObjectBlock.parse(savedNote.body)!.reference;
          final resolved = ResolvedCanvasDiagram(
            CanvasScene.fromJson(reopened.data),
            diagramElementIds(ref)!,
          );
          expect(resolved.scene.length, scene.length);
          final snapshot = PublicationCanvasSnapshot(
            'uml',
            reopened,
            NoteObjectBlock.parse(savedNote.body)!,
          );
          expect(snapshot.scene.length, scene.length);
          expect(snapshot.warnings, isEmpty);
        }
      } finally {
        await repo.close();
        await root.delete(recursive: true);
      }
    },
  );

  for (final seq in [false, true]) {
    testWidgets(
      '${seq ? 'Sequence' : 'Use-case'} starter copy/paste, delete and undo keep links bound to fresh placements',
      (t) async {
        String? clipboard;
        t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboard = (call.arguments as Map)['text'] as String;
            }
            if (call.method == 'Clipboard.getData') return {'text': clipboard};
            return null;
          },
        );
        addTearDown(
          () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        var data = <String, dynamic>{'elements': []};
        await host(t, data, (v) => data = v);
        await menu(
          t,
          seq ? 'Insert sequence starter' : 'Insert use-case starter',
        );
        final count = (data['elements'] as List).length;
        final ids = (data['elements'] as List).map((e) => e['id']).toSet();
        await key(t, LogicalKeyboardKey.keyC);
        await key(t, LogicalKeyboardKey.keyV);
        expect(data['elements'], hasLength(count * 2));
        final copies = (data['elements'] as List)
            .where((e) => !ids.contains(e['id']))
            .toList();
        final copiedIds = copies.map((e) => e['id']).toSet();
        for (final e in copies.where((e) => e['type'] == 'connector')) {
          expect(copiedIds, containsAll({e['startId'], e['endId']}));
          expect(e['umlLink'], isMap);
        }
        await t.sendKeyEvent(LogicalKeyboardKey.delete);
        await t.pumpAndSettle();
        expect(data['elements'], hasLength(count));
        await key(t, LogicalKeyboardKey.keyZ);
        expect(data['elements'], hasLength(count * 2));
        await key(t, LogicalKeyboardKey.keyZ);
        expect(data['elements'], hasLength(count));
        await key(t, LogicalKeyboardKey.keyZ);
        expect(data['elements'], isEmpty);
      },
    );
  }

  testWidgets(
    'node creation rejects empty labels, keeps identity on edit and respects read-only',
    (t) async {
      var data = <String, dynamic>{'elements': []};
      await host(t, data, (v) => data = v);
      await menu(t, 'New actor…');
      await t.enterText(find.widgetWithText(TextField, 'Name'), '');
      await t.tap(find.text('Add to Canvas'));
      await t.pumpAndSettle();
      expect(find.text('Enter a name or note.'), findsOneWidget);
      expect(data['elements'], isEmpty);
      await t.enterText(find.widgetWithText(TextField, 'Name'), 'Student');
      await t.tap(find.text('Add to Canvas'));
      await t.pumpAndSettle();
      final first = (data['elements'] as List).single as Map;
      await menu(t, 'Edit selected diagram item…');
      await t.enterText(find.widgetWithText(TextField, 'Name'), 'Lecturer');
      await t.tap(find.text('Apply'));
      await t.pumpAndSettle();
      expect((data['elements'] as List).single['id'], first['id']);
      expect((data['elements'] as List).single['text'], 'Lecturer');
      await key(t, LogicalKeyboardKey.keyZ);
      expect((data['elements'] as List).single['text'], 'Student');
      await host(t, data, (_) => fail('Read-only mutation'), readOnly: true);
      final popup = t.widget<PopupMenuButton<String>>(
        find.byWidgetPredicate(
          (w) =>
              w is PopupMenuButton<String> &&
              w.tooltip == 'Use-case and sequence diagrams',
        ),
      );
      expect(popup.enabled, false);
    },
  );

  testWidgets('changed owner refuses delayed diagram form submission', (
    t,
  ) async {
    var data = <String, dynamic>{'elements': []};
    late StateSetter update;
    await t.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Scaffold(
              body: CanvasEditor(
                canvasId: 'board',
                data: data,
                onChanged: (v) => data = v,
                objects: const [],
                onOpenObject: (_) {},
              ),
            );
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    await menu(t, 'New use case…');
    update(() => data = {'elements': [], 'external': true});
    await t.pump();
    await t.tap(find.text('Add to Canvas'));
    await t.pumpAndSettle();
    expect(data['elements'], isEmpty);
    expect(data['external'], true);
    expect(find.textContaining('Canvas changed'), findsOneWidget);
  });

  for (final rich in [false, true]) {
    testWidgets(
      '${rich ? 'Rich' : 'Read'} note displays both live diagrams and replaces changed source',
      (t) async {
        final now = DateTime.utc(2026);
        var source = UniversalObject(
          id: 'board',
          workspaceId: 'vault',
          typeId: 'orbit.canvas',
          title: 'UML',
          data: starter(true),
          createdAt: now,
          updatedAt: now,
        );
        var body = diagramMarkdown(
          'board',
          'Sequence',
          diagramExportSelection(CanvasScene.fromJson(source.data), []),
        );
        late StateSetter update;
        await t.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Scaffold(
                  body: NoteEditor(
                    noteId: 'note',
                    title: 'Design',
                    body: body,
                    allObjects: [source],
                    linkTargets: const [],
                    initialViewState: {'mode': rich ? 'rich' : 'read'},
                    onTitleChanged: (_) {},
                    onBodyChanged: (v) => setState(() => body = v),
                    onOpenObject: (_) {},
                  ),
                );
              },
            ),
          ),
        );
        await t.pumpAndSettle();
        OrbitCanvasPainter painter() =>
            t
                    .widget<CustomPaint>(
                      find.byKey(const ValueKey('note-diagram-vector')),
                    )
                    .painter!
                as OrbitCanvasPainter;
        expect(painter().scene.elements.where(isInteractionNode), hasLength(2));
        final use = starter(false);
        update(() {
          source = source.copyWith(data: use);
          body = diagramMarkdown(
            'board',
            'Use cases',
            diagramExportSelection(CanvasScene.fromJson(use), []),
          );
        });
        await t.pumpAndSettle();
        expect(painter().scene.elements.where(isInteractionNode), hasLength(5));
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'all forms fit compact 250% text with keyboard and keep error/cancel reachable',
    (t) async {
      t.view.physicalSize = const Size(360, 740);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final scene = CanvasScene.fromJson(starter(true));
      for (final e in [
        for (final k in UmlNodeKind.values)
          newInteractionNode(k.name, k, const CanvasPoint(0, 0)),
        scene['node-2']!,
      ]) {
        await t.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(2.5),
                viewInsets: const EdgeInsets.only(bottom: 200),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showInteractionEditor(
                    context,
                    e,
                    scene.elements.where(isInteractionNode).toList(),
                    sequence: umlLinkKind(e)?.sequence == true,
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('Open'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.ensureVisible(find.text('Cancel'));
        await t.tap(find.text('Cancel'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'shared painter keeps its background inside its allocated preview',
    (t) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..drawColor(const Color(0xffff00ff), BlendMode.src);
      final cache = CanvasTextCache();
      OrbitCanvasPainter(
        scene: CanvasScene.fromJson({'elements': []}),
        camera: const CanvasCamera(),
        selection: {},
        objects: {},
        colors: orbitDarkTheme().colorScheme,
        textCache: cache,
        backgroundStyle: 'none',
      ).paint(canvas, const Size(40, 40));
      final picture = recorder.endRecording();
      await t.runAsync(() async {
        final image = await picture.toImage(80, 80);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final outside = (60 * 80 + 60) * 4;
        expect(bytes.getUint32(outside), 0xff00ffff);
        image.dispose();
      });
      cache.dispose();
      picture.dispose();
    },
  );

  testWidgets(
    'publication snapshots render both diagrams without dropping UML notation',
    (t) async {
      final now = DateTime.utc(2026);
      for (final seq in [false, true]) {
        final object = UniversalObject(
          id: 'board',
          workspaceId: 'vault',
          typeId: 'orbit.canvas',
          title: 'Diagram',
          data: starter(seq),
          createdAt: now,
          updatedAt: now,
        );
        final block = NoteObjectBlock.parse(
          diagramMarkdown(
            'board',
            'Diagram',
            diagramExportSelection(CanvasScene.fromJson(object.data), []),
          ),
        )!;
        final warnings = <String>[];
        await t.runAsync(() async {
          final bytes = await renderPublicationCanvas(
            PublicationCanvasSnapshot('uml', object, block),
            objects: [object],
            warn: warnings.add,
          );
          expect(bytes, isNotNull);
          expect(bytes!.length, greaterThan(500));
        });
        expect(warnings, isEmpty);
      }
    },
  );

  testWidgets('real-font vector previews of both UML kinds', (t) async {
    // Headless component render; no desktop app or private Vault is opened.
    for (final path in [
      'C:/Windows/Fonts/segoeui.ttf',
      'C:/Windows/Fonts/seguisb.ttf',
    ]) {
      if (File(path).existsSync()) {
        final loader = FontLoader('Segoe UI')
          ..addFont(
            Future.value(ByteData.sublistView(File(path).readAsBytesSync())),
          );
        await t.runAsync(loader.load);
      }
    }
    await t.runAsync(() async {
      if (Platform.isWindows) {
        final loader = FontLoader('Roboto')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                File('C:/Windows/Fonts/segoeui.ttf').readAsBytesSync(),
              ),
            ),
          );
        await loader.load();
      }
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });
    t.view.physicalSize = const Size(1200, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    for (final seq in [false, true]) {
      final scene = CanvasScene.fromJson(starter(seq));
      if (seq) {
        final fragment = newInteractionNode(
          'fragment',
          UmlNodeKind.fragment,
          const CanvasPoint(320, 280),
        ).copy({'width': 340.0, 'height': 180.0});
        scene.put(
          fragment.copy(
            editInteractionNode(
              fragment,
              name: '',
              operator: 'loop',
              lines: '[attempt < 3]',
            ),
          ),
        );
        final activation = newInteractionNode(
          'activation',
          UmlNodeKind.activation,
          const CanvasPoint(511, 192),
        ).copy({'height': 328.0});
        scene.put(activation);
        scene.sendToBack('fragment');
        final message = scene['node-3']!;
        scene.put(
          message.copy(
            editInteractionLink(
              message,
              scene.elements.where(isInteractionNode).toList(),
              kind: UmlLinkKind.synchronous,
              from: 'node-1',
              to: 'node-1',
              position: .56,
              label: 'validate()',
            ),
          ),
        );
        final reply = scene['node-4']!;
        scene.put(
          reply.copy(
            editInteractionLink(
              reply,
              scene.elements.where(isInteractionNode).toList(),
              kind: UmlLinkKind.reply,
              from: 'node-1',
              to: 'node-0',
              position: .75,
              label: 'result',
            ),
          ),
        );
      }
      await t.pumpWidget(
        MaterialApp(
          theme: seq
              ? orbitTheme(preset: 'palette-sage-light')
              : orbitDarkTheme(),
          home: Scaffold(
            body: RepaintBoundary(
              key: boundary,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: CanvasDiagramPreview(
                    scene: scene,
                    title: seq ? 'Sequence diagram' : 'Use-case diagram',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final r =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await t.runAsync(() async {
        final capture = await r.toImage(pixelRatio: 1.5);
        final bytes = await capture.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          'build/previews/orbit-uml-${seq ? 'sequence' : 'use-case'}.png',
        );
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(bytes!.buffer.asUint8List());
        capture.dispose();
      });
      expect(t.takeException(), isNull);
    }
  });
}
