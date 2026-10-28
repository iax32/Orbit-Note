import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/domain/collaboration.dart';
import 'package:orbit_note/features/canvas/canvas_presence_overlay.dart';
import 'package:orbit_note/features/canvas/canvas_images.dart';
import 'canvas_shared_presence_test.dart' show CanvasSessions;

Map<String, dynamic> stroke([int length = 128]) => {
  'points': [
    for (var i = 0; i < length; i++)
      {'x': i.toDouble(), 'y': i * .5, 'pressure': .7},
  ],
  'color': 0xff7755ee,
  'strokeWidth': 3.0,
  'penStyle': 'fountain',
};

Future<void> until(bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 4));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) fail('Live update did not arrive');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('ink awareness rejects oversized, nonfinite and hostile values', () {
    expect(collaborationInkPreview(stroke()), isNotNull);
    expect(
      utf8.encode(jsonEncode(collaborationInkPreview(stroke()))).length,
      lessThan(16 * 1024),
    );
    for (final value in [
      stroke(129),
      {...stroke(), 'color': -1},
      {...stroke(), 'strokeWidth': double.infinity},
      {
        ...stroke(),
        'points': [
          {'x': double.nan, 'y': 1, 'pressure': .5},
        ],
      },
      {
        ...stroke(),
        'points': [
          {'x': 1, 'y': 1, 'pressure': 1000},
        ],
      },
    ]) {
      expect(collaborationInkPreview(value), isNull);
    }
    expect(
      collaborationInkPreview({
        ...stroke(),
        'futureScript': 'ignore',
      })!.containsKey('futureScript'),
      false,
    );
  });
  test(
    'automatic ink awareness arrives without full document/attachment pump',
    () async {
      HttpOverrides.global = null;
      final f = CanvasSessions();
      await f.open(automaticPolling: true);
      addTearDown(f.close);
      final before = f.transport.stateRequests;
      final original = jsonEncode(f.secondWorkspace.find(f.id)!.data);
      final watch = Stopwatch()..start();
      for (var i = 0; i < 40; i++) {
        f.first.previewCanvasInk(f.id, stroke());
      }
      await until(
        () => f.second.presenceChanges.value.any((p) => p['ink'] is Map),
      );
      watch.stop();
      // Forty pointer updates coalesce into a single bounded awareness message.
      expect(f.transport.presence.length, lessThan(5));
      expect(f.transport.stateRequests, before);
      expect(jsonEncode(f.secondWorkspace.find(f.id)!.data), original);
      // ignore: avoid_print
      print('Live ink local transport: ${watch.elapsedMilliseconds} ms');
      f.first.previewCanvasInk(f.id, null);
      await until(
        () => f.second.presenceChanges.value.every((p) => p['ink'] == null),
      );
      expect(jsonEncode(f.secondWorkspace.find(f.id)!.data), original);
    },
  );
  test(
    'image bytes and completed ink still converge durably on two clients',
    () async {
      final f = CanvasSessions();
      await f.open();
      addTearDown(f.close);
      final recorder = ui.PictureRecorder();
      ui.Canvas(
        recorder,
      ).drawRect(const ui.Rect.fromLTWH(0, 0, 2, 2), ui.Paint());
      final picture = recorder.endRecording();
      final image = await picture.toImage(2, 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      final png = data!.buffer.asUint8List();
      f.firstStore.files['Attachments/pasted.png'] = png;
      f.firstWorkspace.edit(
        f.id,
        data: {
          ...f.initial,
          'elements': [
            ...f.initial['elements'] as List,
            {
              'id': '00000000-0000-4000-8000-000000000099',
              'type': 'image',
              'x': 0,
              'y': 0,
              'width': 100,
              'height': 100,
              'contentRef': 'Attachments/pasted.png',
            },
            {
              ...stroke(),
              'id': '00000000-0000-4000-8000-000000000098',
              'type': 'ink',
              'x': 0,
              'y': 0,
              'width': 128,
              'height': 64,
            },
          ],
        },
      );
      await f.first.pump();
      await f.second.pump();
      expect(f.secondStore.files['Attachments/pasted.png'], png);
      expect(
        (f.secondWorkspace.find(f.id)!.data['elements'] as List).length,
        66,
      );
      expect(f.first.conflicts, isEmpty);
      expect(f.second.conflicts, isEmpty);
      expect(f.secondWorkspace.find(f.id)!.data['future'], f.initial['future']);
      final remote = f.secondWorkspace.find(f.id)!.data['elements'] as List;
      final reference =
          remote.firstWhere((e) => e['type'] == 'image')['contentRef']
              as String;
      final cache = CanvasImageCache(
        loader: f.secondRepo.readAttachment,
        onChanged: () {},
      );
      addTearDown(cache.dispose);
      cache.updateVisible([reference]);
      await until(
        () => cache.images.isNotEmpty || cache.failedReferences.isNotEmpty,
      );
      expect(cache.failedReferences, isEmpty);
      expect(cache.images[reference]!.width, 2);
    },
  );
  testWidgets(
    'remote ink paints using the Canvas ink engine without changing selection',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CanvasPresenceOverlay(
              scene: CanvasScene.fromJson({'schemaVersion': 1, 'elements': []}),
              camera: CanvasCamera(),
              peers: [
                {
                  'session': 'peer',
                  'name': 'Tablet',
                  'role': 'editor',
                  'active': true,
                  'x': 30,
                  'y': 20,
                  'ink': stroke(),
                },
              ],
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('peer-ink-peer')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
