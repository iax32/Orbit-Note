import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/model_asset.dart';
import 'package:orbit_note/features/files/model_asset_viewer.dart';
import 'package:orbit_note/features/notes/note_templates.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/canvas/scene.dart';

const obj = 'v 0 0 0\nv 1 0 0\nv 1 1 0\nv 0 1 0\nf -4/1 -3/2 -2/3 -1/4\n';
Uint8List glb({
  bool sparse = false,
  bool draco = false,
  bool badView = false,
  bool meshopt = false,
}) {
  final binary = ByteData(36);
  for (final pair in <int, double>{12: 1, 28: 1}.entries) {
    binary.setFloat32(pair.key, pair.value, Endian.little);
  }
  final doc = {
    'asset': {'version': '2.0'},
    'buffers': [
      {'byteLength': 36},
    ],
    'bufferViews': [
      {
        'buffer': 0,
        'byteLength': badView ? 12 : 36,
        if (meshopt) 'extensions': {'EXT_meshopt_compression': {}},
      },
    ],
    'accessors': [
      {
        'bufferView': 0,
        'componentType': 5126,
        'count': 3,
        'type': 'VEC3',
        if (sparse) 'sparse': {},
      },
    ],
    'meshes': [
      {
        'primitives': [
          {
            'attributes': {'POSITION': 0},
            'material': 0,
            if (draco) 'extensions': {'KHR_draco_mesh_compression': {}},
          },
        ],
      },
    ],
    'materials': [
      {
        'pbrMetallicRoughness': {
          'baseColorFactor': [1, 0, 0, 1],
        },
      },
    ],
    'nodes': [
      {'mesh': 0},
      {
        'mesh': 0,
        'translation': [2, 0, 0],
      },
    ],
    'scenes': [
      {
        'nodes': [0, 1],
      },
    ],
    'scene': 0,
  };
  final json = utf8.encode(jsonEncode(doc)).toList();
  while (json.length % 4 != 0) {
    json.add(32);
  }
  final result = Uint8List(12 + 8 + json.length + 8 + 36);
  final data = ByteData.sublistView(result);
  data.setUint32(0, 0x46546c67, Endian.little);
  data.setUint32(4, 2, Endian.little);
  data.setUint32(8, result.length, Endian.little);
  data.setUint32(12, json.length, Endian.little);
  data.setUint32(16, 0x4e4f534a, Endian.little);
  result.setRange(20, 20 + json.length, json);
  final offset = 20 + json.length;
  data.setUint32(offset, 36, Endian.little);
  data.setUint32(offset + 4, 0x004e4942, Endian.little);
  result.setRange(offset + 8, result.length, binary.buffer.asUint8List());
  return result;
}

class AssetStore extends NativeWorkspaceStore {
  AssetStore(this.root);
  final String root;
  @override
  Future<void> initialize({String? path}) =>
      super.initialize(path: path ?? root);
}

void main() {
  test(
    'OBJ negative indices triangulate polygons, normalize bounds and retain bytes',
    () {
      final bytes = Uint8List.fromList(utf8.encode(obj)),
          before = bytes.toList();
      final model = parseModelAsset(bytes, 'prop.OBJ');
      expect(model.points.length, 4);
      expect(model.faces.length, 2);
      expect(model.points.first.x, -.5);
      expect(model.points.last.y, .5);
      expect(bytes, before);
      expect(isModelAsset('character.GLB'), true);
    },
  );
  test(
    'GLB instances, transforms, material tint and non-indexed triangles',
    () {
      final model = parseModelAsset(glb(), 'prop.glb');
      expect(model.faces.length, 2);
      expect(model.points.length, 6);
      expect(model.faces.first.color, 0xffff0000);
      expect(model.points[3].x - model.points[0].x, closeTo(2 / 3, 1e-6));
    },
  );
  test(
    'malformed, compressed, sparse and invalid-bound geometry fail visibly',
    () {
      for (final bytes in [
        Uint8List(3),
        glb(sparse: true),
        glb(draco: true),
        glb(meshopt: true),
        glb(badView: true),
      ]) {
        expect(() => parseModelAsset(bytes, 'bad.glb'), throwsFormatException);
      }
      for (final source in [
        'v NaN 0 0\nv 0 1 0\nf 1 2 3',
        'v 0 0 0\nf 0 1 2',
        'v 0 0 0\nf 1 1 1',
      ]) {
        expect(
          () => parseModelAsset(
            Uint8List.fromList(utf8.encode(source)),
            'bad.obj',
          ),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'new writing templates have unique IDs and searchable useful structures',
    () {
      expect(
        NoteTemplates.all.map((t) => t.id).toSet().length,
        NoteTemplates.all.length,
      );
      expect(NoteTemplates.storyTemplates.length, 6);
      for (final template in NoteTemplates.storyTemplates) {
        expect(NoteTemplates.byId(template.id), template);
        expect(template.body, contains('| ---'));
        expect(NoteTemplates.search(template.name), contains(template));
      }
    },
  );
  testWidgets('viewer rotates, wireframes and recovers missing assets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModelAssetViewer(
            name: 'prop.obj',
            loadBytes: () async => Uint8List.fromList(utf8.encode(obj)),
            onOpenOriginal: () {},
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('4 vertices · 2 triangles'), findsOneWidget);
    await tester.tap(find.text('Wireframe'));
    await tester.pump();
    expect(tester.widget<FilterChip>(find.byType(FilterChip)).selected, true);
    await tester.drag(find.byType(CustomPaint).last, const Offset(60, 20));
    await tester.pump();
    await tester.tap(find.byTooltip('Fit model'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModelAssetViewer(
            key: const ValueKey('missing'),
            name: 'missing.glb',
            loadBytes: () async => null,
            onOpenOriginal: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Asset is missing'), findsOneWidget);
    expect(find.text('Open original'), findsOneWidget);
  });
  testWidgets('model controls and viewport fit narrow enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: ModelAssetViewer(
              name: 'Long environment model.obj',
              loadBytes: () async => Uint8List.fromList(utf8.encode(obj)),
              onOpenOriginal: () {},
              onPlace: () {},
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('4 vertices'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'Canvas model placements retain one asset identity and recover after restart',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-model-');
      Future<(ProviderContainer, WorkspaceController)> open() async {
        final container = ProviderContainer(
          overrides: [
            repositoryProvider.overrideWithValue(
              WorkspaceRepository(
                store: AssetStore(root.path),
                index: MemoryObjectIndex(),
              ),
            ),
          ],
        );
        final c = container.read(workspaceProvider.notifier);
        while (c.loading) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
        return (container, c);
      }

      final (container, c) = await open();
      late String assetId, boardId;
      try {
        final asset = await c.repository.importAttachment(
          name: 'prop.obj',
          bytes: Uint8List.fromList(utf8.encode(obj)),
        );
        // Controller owns the canonical object list used by validated placement.
        await c.refresh();
        assetId = asset.id;
        final board = (await c.create('orbit.canvas', title: 'Assets'))!;
        boardId = board.id;
        expect(await c.placeModelAsset(assetId, boardId), true);
        expect(await c.placeModelAsset(assetId, boardId), true);
        final scene = CanvasScene.fromJson(c.find(boardId)!.data);
        expect(scene.elements.length, 2);
        expect(scene.elements.map((e) => e.objectId).toSet(), {assetId});
        scene.remove(scene.elements.first.id);
        c.edit(boardId, data: scene.toJson());
        await c.flush(boardId);
        expect(c.find(assetId)!.isDeleted, false);
        await c.closeWorkspace();
      } finally {
        container.dispose();
      }
      final (again, restored) = await open();
      try {
        expect(
          CanvasScene.fromJson(restored.find(boardId)!.data).elements.length,
          1,
        );
        expect(
          await restored.repository.readAttachment(
            restored.find(assetId)!.properties['contentRef'] as String,
          ),
          utf8.encode(obj),
        );
      } finally {
        await restored.closeWorkspace();
        again.dispose();
        await root.delete(recursive: true);
      }
    },
  );
}
