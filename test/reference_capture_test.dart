import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/canvas/reference_capture.dart';
import 'package:orbit_note/canvas/canvas_search.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/main.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/canvas/reference_details_dialog.dart';
import 'support/memory_store.dart';

class ReferenceNativeStore extends NativeWorkspaceStore {
  ReferenceNativeStore(this.path);
  final String path;
  @override
  Future<void> initialize({String? path}) =>
      super.initialize(path: path ?? this.path);
}

class ReferenceDropFile extends DropItemFile {
  ReferenceDropFile(this.fileName, this.bytes)
    : super.fromData(bytes, name: fileName);
  final String fileName;
  final Uint8List bytes;
  @override
  String get name => fileName;
  @override
  String get path => fileName;
  @override
  Future<int> length() async => bytes.length;
  @override
  Future<Uint8List> readAsBytes() async => bytes;
}

class FailedReferenceFile extends ReferenceDropFile {
  FailedReferenceFile() : super('unavailable.txt', Uint8List(0));
  @override
  Future<Uint8List> readAsBytes() async => throw StateError('File unavailable');
}

class FailedReferenceMetadataRepo extends WorkspaceRepository {
  FailedReferenceMetadataRepo()
    : super(store: MemoryStore(), index: MemoryObjectIndex());
  @override
  Future<UniversalObject> save(UniversalObject object) {
    if (object.properties['referenceBoardId'] is String &&
        object.typeId == 'orbit.file') {
      throw StateError('Metadata save unavailable');
    }
    return super.save(object);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'metadata failure leaves the owned source discoverable and missing boards reject capture',
    () async {
      final repo = FailedReferenceMetadataRepo();
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      final c = container.read(workspaceProvider.notifier);
      for (var i = 0; i < 300 && c.loading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      try {
        await expectLater(
          c.captureCreativeReference(
            'missing',
            'no.txt',
            Uint8List.fromList([65]),
          ),
          throwsStateError,
        );
        expect(c.activeObjects.where((o) => o.typeId == 'orbit.file'), isEmpty);
        final board = (await c.create('orbit.canvas', title: 'Board'))!;
        await expectLater(
          c.captureCreativeReference(
            board.id,
            'retained.txt',
            Uint8List.fromList([65]),
          ),
          throwsStateError,
        );
        final source = c.activeObjects
            .where((o) => o.typeId == 'orbit.file')
            .single;
        expect(
          await repo.readAttachment(source.properties['contentRef'] as String),
          Uint8List.fromList([65]),
        );
      } finally {
        container.dispose();
        await repo.close();
      }
    },
  );
  testWidgets('reference details fit narrow enlarged-text layouts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, dynamic>? details;
    await tester.pumpWidget(
      MaterialApp(
        theme: orbitDarkTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                details = await showReferenceDetails(
                  context,
                  CanvasElement({
                    'id': 'a',
                    'type': 'card',
                    'referenceCaption': 12,
                    'referenceSourceUrl': false,
                  }),
                  'A long reference filename for a texture study',
                );
              },
              child: const Text('Details'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Save details'));
    await tester.pumpAndSettle();
    expect(details?['referenceStatus'], 'Inbox');
    expect(tester.takeException(), isNull);
  });
  Map<String, dynamic> columnData({bool locked = false}) => {
    'schemaVersion': 1,
    'unknown': 'retained',
    'elements': [
      {
        'id': 'column',
        'type': 'column',
        'text': 'Inspiration',
        'x': 0.0,
        'y': 0.0,
        'width': 300.0,
        'height': 180.0,
        'locked': locked,
      },
    ],
  };
  test(
    'capture packs columns, extends them and keeps locked columns untouched',
    () {
      var serial = 0;
      final scene = CanvasScene.fromJson(columnData());
      final packed = capturedReferencePlacements(
        scene,
        ['a', 'b'],
        const CanvasPoint(80, 90),
        () => '${serial++}',
      );
      expect(
        packed.where((e) => e.type == 'card').map((e) => e.data['columnId']),
        ['column', 'column'],
      );
      expect(packed[2].bounds.top, greaterThan(packed[1].bounds.bottom));
      expect(
        packed.first.bounds.bottom,
        greaterThan(packed.last.bounds.bottom),
      );
      final locked = capturedReferencePlacements(
        CanvasScene.fromJson(columnData(locked: true)),
        ['a', 'b', 'c', 'd'],
        const CanvasPoint(80, 90),
        () => '${serial++}',
      );
      expect(locked.every((e) => e.data['columnId'] == null), isTrue);
      expect(locked[3].y, greaterThan(locked[0].bounds.bottom));
      expect(
        capturedReferencePlacements(
          CanvasScene.fromJson({'schemaVersion': 99}),
          ['a'],
          const CanvasPoint(0, 0),
          () => 'x',
        ),
        isEmpty,
      );
    },
  );
  test(
    'details validate source URLs, search commentary and export linked evidence',
    () {
      final details = referenceDetails(
        caption: 'Lighting contrast',
        sourceUrl: 'https://example.com/reference',
        tags: 'light, texture, light',
        status: 'Chosen',
      );
      expect(details['referenceTags'], ['light', 'texture']);
      for (final url in [
        'javascript:alert(1)',
        'file:///secret',
        'https://user:pass@example.com',
      ]) {
        expect(
          () => referenceDetails(
            caption: '',
            sourceUrl: url,
            tags: '',
            status: 'Inbox',
          ),
          throwsFormatException,
        );
      }
      final e = CanvasElement({
        'id': 'ref',
        'type': 'card',
        'objectId': 'source',
        'x': 0,
        'y': 0,
        'width': 300,
        'height': 260,
        ...details,
        'unknown': 7,
      });
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [e.data],
      });
      for (final query in ['contrast', 'texture', 'Chosen', 'example.com']) {
        expect(
          searchCanvasElements(
            scene: scene,
            query: query,
            objectLookup: const MapCanvasObjectLookup({}),
          ),
          hasLength(1),
        );
      }
      final summary = referenceSummaryMarkdown(
        'board',
        'Moodboard',
        [e],
        {'source': 'Lamp'},
      );
      expect(summary, contains('[[source|Lamp]]'));
      expect(summary, contains('[[board|Source board]]'));
      expect(summary, contains('Lighting contrast'));
      expect(summary, contains('State: Chosen'));
    },
  );
  test(
    'owned references and placement details survive native restart and placement removal',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-reference-');
      final repo = WorkspaceRepository(
        store: ReferenceNativeStore(root.path),
        index: MemoryObjectIndex(),
      );
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      final c = container.read(workspaceProvider.notifier);
      for (var i = 0; i < 300 && c.loading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      try {
        expect(c.loading, isFalse);
        final board = (await c.create(
          'orbit.canvas',
          title: 'Reference board',
          data: columnData(),
          properties: {
            'folder': 'Notes',
            'project': 'project-id',
            'creativeProject': true,
          },
        ))!;
        final bytes = Uint8List.fromList(
          utf8.encode('Owned research material'),
        );
        final source = await c.captureCreativeReference(
          board.id,
          'research.txt',
          bytes,
        );
        expect(source.properties['project'], 'project-id');
        final scene = CanvasScene.fromJson(board.data);
        for (final e in capturedReferencePlacements(
          scene,
          [source.id],
          const CanvasPoint(60, 60),
          () => 'placement',
        )) {
          scene.put(e);
        }
        scene.put(
          scene['placement']!.copy({
            ...referenceDetails(
              caption: 'Material study',
              sourceUrl: '',
              tags: 'material',
              status: 'Review',
            ),
            'extra': 'keep',
          }),
        );
        c.edit(board.id, data: scene.toJson());
        await c.flushAll();
        await repo.close();
        final reopened = WorkspaceRepository(
          store: ReferenceNativeStore(root.path),
          index: MemoryObjectIndex(),
        );
        try {
          await reopened.initialize();
          final savedBoard = reopened.objects.firstWhere(
            (o) => o.id == board.id,
          );
          final savedScene = CanvasScene.fromJson(savedBoard.data);
          expect(
            savedScene['placement']!.data['referenceCaption'],
            'Material study',
          );
          expect(savedScene['placement']!.data['extra'], 'keep');
          final savedSource = reopened.objects.firstWhere(
            (o) => o.id == source.id,
          );
          expect(
            await reopened.readAttachment(
              savedSource.properties['contentRef'] as String,
            ),
            bytes,
          );
          savedScene.remove('placement');
          await reopened.save(savedBoard.copyWith(data: savedScene.toJson()));
          expect(
            reopened.objects.any((o) => o.id == source.id && !o.isDeleted),
            isTrue,
          );
        } finally {
          await reopened.close();
        }
      } finally {
        container.dispose();
        await repo.close();
        await root.delete(recursive: true);
      }
    },
  );
  testWidgets(
    'capture and caption editing use one-step undo and retain unknown fields',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var data = columnData();
      final capture = CanvasCaptureController();
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'board',
              title: 'Moodboard',
              data: data,
              captureController: capture,
              onChanged: (v) => data = v,
              objects: const [
                CanvasObjectReference(
                  id: 'source',
                  title: 'Reference',
                  typeId: 'orbit.note',
                ),
              ],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final surface = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
      );
      final origin = tester.getTopLeft(surface);
      final ticket = capture.prepare(
        globalPosition: origin + const Offset(100, 90),
      );
      await tester.tapAt(origin + const Offset(900, 500));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.dragFrom(
        origin + const Offset(900, 500),
        const Offset(-400, 0),
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(ticket?.call(['source']), isTrue);
      expect((data['elements'] as List).cast<Map>().last['columnId'], 'column');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add / organize board content'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit reference details…'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('reference-caption')),
        'Use this lighting',
      );
      await tester.enterText(
        find.byKey(const ValueKey('reference-source')),
        'javascript:bad',
      );
      await tester.tap(find.text('Save details'));
      await tester.pumpAndSettle();
      expect(
        find.text('Use a complete HTTP or HTTPS source address.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('reference-source')),
        'https://example.com',
      );
      await tester.tap(find.text('Save details'));
      await tester.pumpAndSettle();
      Map card() => (data['elements'] as List).cast<Map>().firstWhere(
        (e) => e['type'] == 'card',
      );
      expect(card()['referenceCaption'], 'Use this lighting');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(card()['referenceCaption'], '');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(data['elements'], hasLength(1));
      expect(data['unknown'], 'retained');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(capture.place(['source']), isFalse);
    },
  );
  testWidgets('creative-board file drops create spaced canonical references', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = WorkspaceRepository(
      store: MemoryStore(),
      index: MemoryObjectIndex(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: const OrbitNoteApp(),
      ),
    );
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(
      tester.element(find.byType(OrbitNoteApp)),
    ).read(workspaceProvider.notifier);
    final board = (await c.create(
      'orbit.canvas',
      title: 'References',
      properties: {
        'creativeProject': true,
        'folder': 'Notes',
        'project': 'project',
      },
      data: columnData(),
    ))!;
    c.openObject(board.id);
    await tester.pumpAndSettle();
    final surface = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
    );
    final origin = tester.getTopLeft(surface);
    tester
        .widget<DropTarget>(find.byKey(const ValueKey('content-drop-target')))
        .onDragDone!(
      DropDoneDetails(
        files: [
          ReferenceDropFile('one.txt', Uint8List.fromList([65])),
          FailedReferenceFile(),
          ReferenceDropFile('two.txt', Uint8List.fromList([66])),
        ],
        localPosition: const Offset(100, 100),
        globalPosition: origin + const Offset(100, 100),
      ),
    );
    await tester.pumpAndSettle();
    final cards = (c.find(board.id)!.data['elements'] as List)
        .cast<Map>()
        .where((e) => e['type'] == 'card')
        .toList();
    expect(cards, hasLength(2));
    expect(cards[1]['y'] as num, greaterThan((cards[0]['y'] as num) + 260));
    expect(cards.every((e) => e['columnId'] == 'column'), isTrue);
    for (final card in cards) {
      expect(
        c.find(card['objectId'] as String)?.properties['project'],
        'project',
      );
    }
    await c.flushAll();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
