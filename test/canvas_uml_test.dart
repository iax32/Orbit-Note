import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/canvas/canvas_search.dart';
import 'package:orbit_note/canvas/canvas_svg.dart';
import 'package:orbit_note/canvas/connectors.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/canvas/uml.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/features/canvas/uml_dialog.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';

Map<String, dynamic> example() {
  var id = 0;
  return {
    'schemaVersion': 1,
    'futureRoot': true,
    'elements': umlExample(
      () => 'uml-${id++}',
      const CanvasPoint(40, 40),
    ).map((e) => e.data).toList(),
  };
}

Future<void> command(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

Future<void> umlMenu(WidgetTester tester, String action) async {
  await tester.ensureVisible(find.byTooltip('Shapes and diagrams'));
  await tester.tap(find.byTooltip('Shapes and diagrams'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'UML remains ordinary shape data and preserves unknown fields during editing',
    () {
      final before = newUmlClass('a', const CanvasPoint(10, 20)).copy({
        'future': 42,
        'uml': {
          'futureMember': {'keep': true},
          'attributes': ['old'],
          'operations': <String>[],
        },
      });
      final patch = UmlClass(before).edit(
        name: 'Actor',
        attributes: '+ hp: int\r\n- name: String',
        operations: '+ move(x: float): void',
        stereotype: 'interface',
        abstractClass: true,
      );
      final after = before.copy(patch);
      final scene = CanvasScene.fromJson({
        'futureRoot': true,
        'elements': [
          after.data,
          {'type': 'future', 'unknown': true},
        ],
      });
      final reloaded = CanvasScene.fromJson(
        jsonDecode(jsonEncode(scene.toJson())),
      );
      expect(reloaded['a']!.type, 'rectangle');
      expect(reloaded['a']!.data['future'], 42);
      final model = UmlClass(reloaded['a']!);
      expect(model.attributes, ['+ hp: int', '- name: String']);
      expect(model.operations, ['+ move(x: float): void']);
      expect(model.abstractClass, true);
      expect(model.details['futureMember'], {'keep': true});
      expect(reloaded.toJson()['futureRoot'], true);
      expect((reloaded.toJson()['elements'] as List).last, {
        'type': 'future',
        'unknown': true,
      });
      expect(
        () => model.edit(name: ' ', attributes: '', operations: ''),
        throwsFormatException,
      );
    },
  );

  test(
    'UML bound endpoints and endpoint label hit areas follow movement and undo',
    () {
      final scene = CanvasScene.fromJson(example());
      final history = CanvasHistory(scene);
      final edge = scene['uml-4']!;
      final before = resolveConnectorEndpoints(edge, scene);
      final label = connectorEndLabels(edge, before).first;
      expect(scene.hit(label.bounds.center)?.id, edge.id);
      history.put(scene['uml-0']!.translated(const CanvasPoint(0, 130)));
      history.commit();
      final moved = resolveConnectorEndpoints(edge, scene);
      expect(moved.start.y, before.start.y + 130);
      final movedLabel = connectorEndLabels(edge, moved).first;
      expect(
        scene.query(movedLabel.bounds).map((e) => e.id),
        contains(edge.id),
      );
      expect(history.undo(), true);
      expect(resolveConnectorEndpoints(edge, scene).start, before.start);
      history.put(scene['uml-0']!.copy({'width': 400.0}));
      history.commit();
      expect(resolveConnectorEndpoints(edge, scene).start.x, 440);
    },
  );

  test(
    'UML search covers members and SVG preserves compartments, escaped text and markers',
    () {
      final scene = CanvasScene.fromJson(example());
      expect(
        searchCanvasElements(
          scene: scene,
          objectLookup: const MapCanvasObjectLookup({}),
          query: 'kontrollintervall',
        ).single.title,
        'Behandlungsprotokoll',
      );
      final node = scene['uml-0']!;
      scene.put(
        node.copy(
          UmlClass(node).edit(
            name: 'A < B & C',
            attributes: '- map: List<T>',
            operations: '+ run(): bool',
          ),
        ),
      );
      for (final relationship in UmlRelationship.values) {
        scene.put(scene['uml-4']!.copy(relationship.style));
        final svg = canvasToSvg(scene);
        expect(svg, contains('- map: List&lt;T&gt;'));
        expect(svg, contains('A &lt; B &amp; C'));
        expect(svg, contains('+ run(): bool'));
        expect(svg, contains('0..*'));
        if (relationship == UmlRelationship.generalization ||
            relationship == UmlRelationship.aggregation ||
            relationship == UmlRelationship.composition) {
          expect(svg, contains('<polygon'));
        }
        if (relationship == UmlRelationship.dependency ||
            relationship == UmlRelationship.realization) {
          expect(svg, contains('stroke-dasharray'));
        }
      }
    },
  );

  test(
    'native save and restart preserve class members, edges and unknown data',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-uml-');
      final repo = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: MemoryObjectIndex(),
      );
      try {
        await repo.initialize(path: root.path);
        final board = await repo.create(
          typeId: 'orbit.canvas',
          title: 'UML',
          data: example(),
        );
        final scene = CanvasScene.fromJson(board.data);
        final original = scene['uml-0']!;
        scene.put(
          original.copy(
            UmlClass(original).edit(
              name: 'Doctor',
              attributes: '+ name: String',
              operations: '+ visit(): void',
            ),
          ),
        );
        await repo.save(board.copyWith(data: scene.toJson()));
        await repo.close();
        await repo.initialize(path: root.path);
        final reopened = repo.objects.singleWhere((o) => o.id == board.id);
        expect(reopened.data, scene.toJson());
        expect(
          UmlClass(CanvasScene.fromJson(reopened.data)['uml-0']!).operations,
          ['+ visit(): void'],
        );
      } finally {
        await repo.close();
        await root.delete(recursive: true);
      }
    },
  );

  Future<void> host(
    WidgetTester tester,
    Map<String, dynamic> data,
    ValueChanged<Map<String, dynamic>> changed, {
    bool readOnly = false,
  }) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: orbitDarkTheme(),
        home: Scaffold(
          body: CanvasEditor(
            canvasId: 'uml-board',
            data: data,
            onChanged: changed,
            objects: const [],
            onOpenObject: (_) {},
            readOnly: readOnly,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'create class, validate, cancel, edit members and undo as one command',
    (tester) async {
      var data = <String, dynamic>{'elements': []};
      await host(tester, data, (v) => data = v);
      await umlMenu(tester, 'New UML class…');
      await tester.enterText(find.widgetWithText(TextField, 'Class name'), '');
      await tester.tap(find.text('Add to canvas'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a class name.'), findsOneWidget);
      expect(data['elements'], isEmpty);
      await tester.enterText(
        find.widgetWithText(TextField, 'Class name'),
        'Player',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Attributes · one per line'),
        '- hp: int\n+ name: String',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Operations · one per line'),
        '+ jump(): void',
      );
      await tester.tap(find.text('Add to canvas'));
      await tester.pumpAndSettle();
      final saved = CanvasElement(
        (data['elements'] as List).single as Map<String, dynamic>,
      );
      expect(UmlClass(saved).attributes, ['- hp: int', '+ name: String']);
      await umlMenu(tester, 'Edit selected UML item…');
      await tester.enterText(
        find.widgetWithText(TextField, 'Class name'),
        'Changed',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect((data['elements'] as List).single['text'], 'Player');
      await umlMenu(tester, 'Edit selected UML item…');
      await tester.enterText(
        find.widgetWithText(TextField, 'Class name'),
        'Hero',
      );
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect((data['elements'] as List).single['id'], saved.id);
      expect((data['elements'] as List).single['text'], 'Hero');
      await command(tester, LogicalKeyboardKey.keyZ);
      expect((data['elements'] as List).single['text'], 'Player');
      await command(tester, LogicalKeyboardKey.keyZ);
      expect(data['elements'], isEmpty);
    },
  );

  testWidgets(
    'starter is one undo operation and copy/paste remaps all relationships',
    (tester) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
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
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      var data = <String, dynamic>{'elements': []};
      await host(tester, data, (v) => data = v);
      await umlMenu(tester, 'Insert UML example');
      expect(data['elements'], hasLength(8));
      final firstIds = (data['elements'] as List).map((e) => e['id']).toSet();
      await command(tester, LogicalKeyboardKey.keyC);
      expect(clipboard, startsWith('orbit-canvas/1'));
      await command(tester, LogicalKeyboardKey.keyV);
      expect(data['elements'], hasLength(16));
      final pasted = (data['elements'] as List)
          .where((e) => !firstIds.contains(e['id']))
          .toList();
      final pastedIds = pasted.map((e) => e['id']).toSet();
      for (final e in pasted.where((e) => e['type'] == 'connector')) {
        expect(pastedIds, containsAll([e['startId'], e['endId']]));
        expect(e['endMultiplicity'], '0..*');
      }
      await command(tester, LogicalKeyboardKey.keyZ);
      expect(data['elements'], hasLength(8));
      await command(tester, LogicalKeyboardKey.keyZ);
      expect(data['elements'], isEmpty);
    },
  );

  testWidgets(
    'relationship dialog creates attached composition with multiplicities',
    (tester) async {
      var data = example();
      await host(tester, data, (v) => data = v);
      await umlMenu(tester, 'Connect UML classes…');
      await tester.tap(
        find.widgetWithText(
          DropdownButtonFormField<UmlRelationship>,
          'Relationship type',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Composition').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'From multiplicity'),
        '1',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'To multiplicity'),
        '1..*',
      );
      await tester.tap(find.text('Add to canvas'));
      await tester.pumpAndSettle();
      final edge = (data['elements'] as List).last as Map;
      expect(edge['umlRelationship'], 'composition');
      expect(edge['startMarker'], 'filledDiamond');
      expect(edge['endMultiplicity'], '1..*');
      expect(edge['startId'], 'uml-0');
      expect(edge['endId'], 'uml-1');
    },
  );

  testWidgets(
    'stale UML dialog does not overwrite an externally replaced board',
    (tester) async {
      var data = example();
      late StateSetter update;
      await tester.pumpWidget(
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
      await tester.pumpAndSettle();
      await umlMenu(tester, 'New UML class…');
      update(() => data = {'elements': [], 'external': true});
      await tester.pump();
      await tester.tap(find.text('Add to canvas'));
      await tester.pumpAndSettle();
      expect(data['elements'], isEmpty);
      expect(data['external'], true);
      expect(
        find.textContaining('canvas changed while editing'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'locked classes do not open editors and read-only hides mutation tools',
    (tester) async {
      final data = {
        'elements': [
          newUmlClass(
            'locked',
            const CanvasPoint(30, 30),
          ).copy({'locked': true}).data,
        ],
      };
      await host(tester, data, (_) => fail('Must not mutate'));
      final surface = find
          .byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
          )
          .first;
      final at = tester.getTopLeft(surface) + const Offset(100, 60);
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tapAt(at);
      await tester.pumpAndSettle();
      expect(find.text('Edit UML class'), findsNothing);
      await host(tester, data, (_) => fail('Must not mutate'), readOnly: true);
      final menu = tester.widget<PopupMenuButton<String>>(
        find.byWidgetPredicate(
          (w) =>
              w is PopupMenuButton<String> &&
              w.tooltip == 'Shapes and diagrams',
        ),
      );
      expect(menu.enabled, false);
    },
  );

  testWidgets('class and relationship dialogs fit narrow screens at 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scene = CanvasScene.fromJson(example());
    for (final element in [scene['uml-0']!, scene['uml-4']!]) {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showUmlEditor(
                  context,
                  element,
                  scene.elements.where(isUmlClass).toList(),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'editing a manually enlarged class keeps geometry and unknown metadata',
    (tester) async {
      final element = newUmlClass('wide', const CanvasPoint(50, 60)).copy({
        'width': 1000.0,
        'height': 700.0,
        'future': {'keep': true},
        'uml': {
          'attributes': ['+ id: int'],
          'operations': <String>[],
          'futureSetting': 42,
        },
      });
      Map<String, dynamic>? patch;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    patch = await showUmlEditor(context, element, [element]),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Class name'),
        'Renamed',
      );
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      final updated = element.copy(patch!);
      expect(
        [updated.x, updated.y, updated.width, updated.height],
        [element.x, element.y, element.width, element.height],
      );
      expect(updated.data['future'], {'keep': true});
      expect(UmlClass(updated).details['futureSetting'], 42);
      expect(updated.text, 'Renamed');
    },
  );

  testWidgets('UML native paint covers compartment and closed marker paths', (
    tester,
  ) async {
    if (Platform.environment['ORBIT_UML_PREVIEW'] == '1' &&
        Platform.isWindows) {
      await tester.runAsync(() async {
        final loader = FontLoader('Segoe UI')
          ..addFont(
            File(
              'C:/Windows/Fonts/segoeui.ttf',
            ).readAsBytes().then((b) => b.buffer.asByteData()),
          );
        await loader.load();
      });
    }
    final scene = CanvasScene.fromJson(example());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final cache = CanvasTextCache();
    for (final relationship in UmlRelationship.values) {
      scene.put(scene['uml-4']!.copy(relationship.style));
      OrbitCanvasPainter(
        scene: scene,
        camera: const CanvasCamera(),
        selection: {},
        objects: {},
        colors: orbitDarkTheme().colorScheme,
        textCache: cache,
      ).paint(canvas, const Size(1000, 600));
    }
    final picture = recorder.endRecording();
    await tester.runAsync(() async {
      final image = await picture.toImage(1000, 600);
      expect(image.width, 1000);
      if (Platform.environment['ORBIT_UML_PREVIEW'] == '1') {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '.local/uml-preview.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      }
      image.dispose();
    });
    picture.dispose();
    cache.dispose();
  });
}
