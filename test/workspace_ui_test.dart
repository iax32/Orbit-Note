import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/main.dart';
import 'support/memory_store.dart';

void main() {
  testWidgets('two panes, focus recovery, Canvas and settings remain usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const capture = bool.fromEnvironment('ORBIT_CAPTURE_UI');
    if (capture && Platform.isWindows) {
      await tester.runAsync(() async {
        final loader = FontLoader('Segoe UI');
        loader.addFont(
          File(
            r'C:\Windows\Fonts\segoeui.ttf',
          ).readAsBytes().then((v) => v.buffer.asByteData()),
        );
        await loader.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      });
    }
    final repository = WorkspaceRepository(
      store: MemoryStore(),
      index: MemoryObjectIndex(),
    );
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repository)],
          child: const OrbitNoteApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OrbitNoteApp)),
    );
    final c = container.read(workspaceProvider.notifier);
    Future<void> snapshot(String name) async {
      if (!capture) return;
      await tester.pumpAndSettle();
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        await Directory('work/ui').create(recursive: true);
        await File(
          'work/ui/$name.png',
        ).writeAsBytes(data!.buffer.asUint8List());
      });
    }

    final note = (await c.create('orbit.note', title: 'Canvas Architecture'))!;
    c.edit(
      note.id,
      body:
          '# A quiet place to connect ideas\n\nCreate once. View anywhere.\n\n## A shared foundation\n\n- Notes retain their identity\n- Cards reference the original\n- Everything saves locally\n\n> Build one coherent workspace.',
    );
    await c.flushAll();
    c.navigate(OrbitDestination.home);
    await tester.pumpAndSettle();
    await snapshot('home');
    c.openObject(note.id);
    c.updateSession((s) {
      s.secondaryId = note.id;
      s.splitRatio = .5;
      s.noteViews = {
        'primary:${note.id}': {'mode': 'write'},
        'secondary:${note.id}': {'mode': 'write'},
      };
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note-body')), findsNWidgets(2));
    await snapshot('notes-split');
    await tester.enterText(
      find.byKey(const ValueKey('note-body')).first,
      'One object in two panes',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('note-body')).last)
          .controller!
          .text,
      'One object in two panes',
    );
    c.updateSession((s) => s.splitAxis = 'vertical');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close split'));
    await tester.pumpAndSettle();
    c.updateSession((s) => s.focusMode = true);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Exit Focus'), findsOneWidget);
    await tester.tap(find.byTooltip('Exit Focus'));
    await tester.pumpAndSettle();
    final board = (await c.create(
      'orbit.canvas',
      title: 'A connected workspace',
    ))!;
    c.edit(
      board.id,
      data: {
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'card',
            'type': 'card',
            'objectId': note.id,
            'x': 140.0,
            'y': 120.0,
            'width': 280.0,
            'height': 170.0,
          },
          {
            'id': 'sticky',
            'type': 'sticky',
            'text': 'Think in connections.\nKeep the originals.',
            'x': 530.0,
            'y': 280.0,
            'width': 250.0,
            'height': 180.0,
            'color': 0xff8b7cf6,
          },
          {
            'id': 'arrow',
            'type': 'arrow',
            'x': 430.0,
            'y': 210.0,
            'width': 80.0,
            'height': 120.0,
            'color': 0xff8b7cf6,
          },
        ],
      },
    );
    await c.flushAll();
    await tester.pumpAndSettle();
    await snapshot('canvas');
    expect(tester.takeException(), isNull);
    c.navigate(OrbitDestination.settings);
    await tester.pumpAndSettle();
    await snapshot('settings');
    expect(tester.takeException(), isNull);
    await c.flushAll();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
