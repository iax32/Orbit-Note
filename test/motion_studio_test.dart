import 'dart:ui' as ui;
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'dart:ui' show PointerDeviceKind;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_components.dart';
import 'package:orbit_note/app/orbit_motion_effects.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/canvas/presentation.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/domain/motion_preferences.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_presentation_dialog.dart';
import 'package:orbit_note/features/pdf/pdf_motion_surface.dart';
import 'package:orbit_note/features/workspace/motion_studio.dart';

Widget host(
  Widget child, {
  String mode = 'normal',
  Map<String, dynamic> options = const {},
  bool osReduced = false,
  double scale = 1,
}) => MaterialApp(
  theme: orbitDarkTheme(),
  builder: (context, child) => OrbitMotionScope(
    preference: mode,
    osReduced: osReduced,
    options: options,
    child: MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
  ),
  home: Scaffold(body: child),
);

Map<String, dynamic> board() => {
  'schemaVersion': 1,
  'future': {'keep': 42},
  'elements': [
    {
      'id': 'stroke',
      'type': 'ink',
      'x': 30,
      'y': 30,
      'width': 120,
      'height': 70,
      'points': [
        {'x': 0, 'y': 0, 'pressure': .3, 'future': 7},
        {'x': 60, 'y': 70, 'pressure': .8},
        {'x': 120, 'y': 0, 'pressure': 1},
      ],
      'futureStroke': 'retained',
    },
    {
      'id': 'box',
      'type': 'rectangle',
      'x': 200,
      'y': 30,
      'width': 180,
      'height': 100,
      'text': 'Real authored diagram',
    },
    {
      'id': 'hidden',
      'type': 'sticky',
      'hidden': true,
      'x': 0,
      'y': 0,
      'width': 100,
      'height': 100,
      'text': 'Hidden',
    },
  ],
};

void main() {
  test('preferences bound malformed values and preserve future data', () {
    final p = MotionPreferences({
      'profile': 'future',
      'speed': double.nan,
      'readingProgress': 'yes',
      'future': 42,
    });
    expect(p.profile, 'fluid');
    expect(p.speed, 1);
    expect(p.readingProgress, false);
    expect(MotionPreferences({'speed': 100}).speed, 2);
    expect(MotionPreferences({'speed': -9}).speed, .5);
    expect(p.patch({'speed': 1.5})['future'], 42);
    final state = SessionState.fromJson({
      'motionOptions': {
        'profile': 'paper',
        'future': {'keep': true},
      },
    });
    final again = SessionState.fromJson(jsonDecode(jsonEncode(state.toJson())));
    expect(again.motionOptions, state.motionOptions);
    expect(SessionState.fromJson({}).motionOptions, isEmpty);
  });
  test('all supplied inspiration IDs are unique and searchable', () {
    expect(motionInspirations.length, 70);
    expect(motionInspirations.map((e) => e.id).toSet().length, 70);
    expect(
      motionInspirations.map((e) => e.family).toSet(),
      MotionFamily.values.toSet(),
    );
  });
  test(
    'presentation scrubbing preserves source, pressure and unknown data',
    () {
      final scene = CanvasScene.fromJson(board()),
          before = jsonEncode(scene.toJson());
      final timeline = CanvasPresentation(scene.elements);
      expect(timeline.ids, ['stroke', 'box']);
      expect(timeline.at(0), {'stroke': 0.0, 'box': 0.0});
      expect(timeline.at(.25), {'stroke': .5, 'box': 0.0});
      expect(timeline.at(1), {'stroke': 1.0, 'box': 1.0});
      expect(timeline.progressFor('missing', double.nan), 1);
      final partial = revealCanvasInk(scene['stroke']!, .5);
      expect((partial.data['points'] as List).length, 2);
      expect((partial.data['points'] as List).first['future'], 7);
      expect(partial.data['futureStroke'], 'retained');
      final tip =
          (revealCanvasInk(scene['stroke']!, .25).data['points'] as List).last;
      expect(tip['x'], 30);
      expect(tip['y'], 35);
      expect(tip['pressure'], closeTo(.55, .00001));
      expect(jsonEncode(scene.toJson()), before);
      expect(timeline.at(double.nan).values.every((v) => v == 1), true);
      expect(CanvasPresentation([]).at(.5), isEmpty);
    },
  );

  for (final mode in ['normal', 'reduced', 'off']) {
    testWidgets(
      '$mode effect retains native editor, composing range and focus through settling',
      (t) async {
        final focus = FocusNode(), text = TextEditingController();
        addTearDown(focus.dispose);
        addTearDown(text.dispose);
        Widget content(int n) => host(
          OrbitEffect(
            trigger: n,
            interactive: true,
            style: 'wave',
            family: 'editing',
            child: TextField(focusNode: focus, controller: text),
          ),
          mode: mode,
        );
        await t.pumpWidget(content(0));
        await t.tap(find.byType(TextField));
        text.value = const TextEditingValue(
          text: 'a 🧪 composing',
          selection: TextSelection(baseOffset: 2, extentOffset: 4),
          composing: TextRange(start: 5, end: 14),
        );
        final native = t.state(find.byType(EditableText));
        final before = text.value;
        await t.pumpWidget(content(1));
        await t.pump(const Duration(milliseconds: 35));
        expect(t.state(find.byType(EditableText)), same(native));
        await t.pumpAndSettle();
        expect(t.state(find.byType(EditableText)), same(native));
        expect(text.value, before);
        expect(focus.hasFocus, true);
        expect(t.takeException(), isNull);
      },
    );
    testWidgets(
      '$mode PDF surface retains one viewer across page and annotation changes',
      (t) async {
        Widget page(int n) => host(
          SizedBox(
            width: 500,
            height: 400,
            child: PdfMotionSurface(
              navigation: n,
              annotation: n,
              page: n + 1,
              pageCount: 8,
              child: const TextField(key: ValueKey('viewer')),
            ),
          ),
          mode: mode,
        );
        await t.pumpWidget(page(0));
        await t.enterText(find.byType(TextField), 'Kept');
        final native = t.state(find.byType(EditableText));
        await t.pumpWidget(page(1));
        await t.pumpAndSettle();
        expect(t.state(find.byType(EditableText)), same(native));
        expect(find.text('Kept'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(t.takeException(), isNull);
      },
    );
  }
  for (final style in MotionPreferences.textStyles) {
    testWidgets(
      '$style text replay completes without splitting Unicode graphemes',
      (t) async {
        const value = 'Hello 👨‍👩‍👧‍👦 e\u0301 🧪 world';
        await t.pumpWidget(
          host(OrbitTextReplay(text: value, style: style, replay: 1)),
        );
        await t.pump(const Duration(milliseconds: 150));
        final shown = t
            .widget<SelectableText>(find.byType(SelectableText))
            .data!;
        expect(shown.contains('\uFFFD'), false);
        await t.pumpAndSettle();
        expect(find.text(value), findsOneWidget);
        expect(t.hasRunningAnimations, false);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets('OS reduction exposes complete text immediately', (t) async {
    await t.pumpWidget(
      host(
        const OrbitTextReplay(
          text: 'Complete source',
          style: 'scramble',
          replay: 1,
        ),
        osReduced: true,
      ),
    );
    expect(find.text('Complete source'), findsOneWidget);
    expect(t.hasRunningAnimations, false);
  });
  testWidgets(
    'direct pointer input settles a text presentation before selecting',
    (t) async {
      await t.pumpWidget(
        host(
          const OrbitTextReplay(
            text: 'A long piece of authored source',
            style: 'typewriter',
            replay: 1,
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 50));
      await t.tapAt(
        t.getTopLeft(find.byType(OrbitTextReplay)) + const Offset(5, 5),
      );
      await t.pumpAndSettle();
      expect(find.text('A long piece of authored source'), findsOneWidget);
    },
  );
  testWidgets(
    'PDF progress is opt-in and lens remains bounded on a tiny surface',
    (t) async {
      await t.pumpWidget(
        host(
          const SizedBox(
            width: 110,
            height: 110,
            child: PdfMotionSurface(
              navigation: 1,
              annotation: 0,
              page: 4,
              pageCount: 8,
              lens: true,
              child: Text('Page'),
            ),
          ),
          options: {'readingProgress': true},
        ),
      );
      expect(
        t
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        .5,
      );
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(10, 10));
      await mouse.moveTo(const Offset(20, 20));
      await t.pump();
      expect(find.byType(RawMagnifier), findsNothing);
      expect(t.takeException(), isNull);
      await mouse.removePointer();
    },
  );
  testWidgets(
    'Canvas replay uses real content and leaves source unchanged on seek/pause/close',
    (t) async {
      final scene = CanvasScene.fromJson(board()), before = jsonEncode(board());
      await t.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showCanvasPresentation(
                context,
                scene: scene,
                objects: const {},
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Replay'));
      await t.tap(find.text('Replay'));
      await t.pump(const Duration(milliseconds: 100));
      await t.tap(find.text('Pause'));
      await t.pump();
      await t.drag(
        find.byKey(const ValueKey('canvas-replay-position')),
        const Offset(-100, 0),
      );
      await t.pump();
      await t.tap(find.text('Done'));
      await t.pumpAndSettle();
      expect(jsonEncode(scene.toJson()), before);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'preview owns image handles through provider disposal and the closing animation',
    (t) async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(const Color(0xff123456), ui.BlendMode.src);
      final picture = recorder.endRecording();
      final image = await t.runAsync(() => picture.toImage(32, 32));
      picture.dispose();
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'image',
            'type': 'image',
            'contentRef': 'capture',
            'x': 0,
            'y': 0,
            'width': 120,
            'height': 120,
          },
        ],
      });
      await t.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showCanvasPresentation(
                context,
                scene: scene,
                objects: const {},
                images: {'capture': image!},
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      image!.dispose();
      await t.pump();
      expect(t.takeException(), isNull);
      await t.tap(find.text('Done'));
      await t.pump(const Duration(milliseconds: 40));
      expect(t.takeException(), isNull);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );
  for (final mode in ['reduced', 'off']) {
    testWidgets('$mode Canvas replay exposes the whole board immediately', (
      t,
    ) async {
      await t.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showCanvasPresentation(
                context,
                scene: CanvasScene.fromJson(board()),
                objects: const {},
              ),
              child: const Text('Open'),
            ),
          ),
          mode: mode,
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Replay'));
      await t.tap(find.text('Replay'));
      await t.pumpAndSettle();
      final painter =
          t
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('canvas-presentation-surface')),
                  )
                  .painter!
              as OrbitCanvasPainter;
      expect(painter.revealProgress.values.every((p) => p == 1), true);
      expect(t.hasRunningAnimations, false);
      await t.tap(find.text('Done'));
      await t.pumpAndSettle();
    });
  }
  testWidgets('laser gestures never reach placement editing or save', (
    t,
  ) async {
    t.view.physicalSize = const Size(1400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    var saves = 0;
    await t.pumpWidget(
      host(
        CanvasEditor(
          canvasId: 'test',
          onOpenObject: (_) {},
          data: board(),
          objects: const [],
          onChanged: (_) => saves++,
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.byTooltip('Canvas motion & presentation'));
    await t.tap(find.byTooltip('Canvas motion & presentation'));
    await t.pumpAndSettle();
    await t.tap(find.text('Temporary laser pointer'));
    await t.pumpAndSettle();
    await t.dragFrom(const Offset(300, 300), const Offset(200, 70));
    await t.pumpAndSettle();
    expect(saves, 0);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(saves, 0);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'advanced controls remain reachable and preserve future preferences',
    (t) async {
      Map<String, dynamic> saved = {
        'future': {'retained': 42},
      };
      await t.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showMotionStudio(
                context,
                options: saved,
                onChanged: (v) => saved = v,
              ),
              child: const Text('Open'),
            ),
          ),
          mode: 'off',
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      final advanced = find.byKey(const ValueKey('motion-advanced-controls'));
      await t.ensureVisible(advanced);
      await t.tap(advanced);
      await t.pumpAndSettle();
      final toggle = find.widgetWithText(SwitchListTile, 'Focus typing');
      await t.ensureVisible(toggle);
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(saved['focusTyping'], true);
      expect(saved['future'], {'retained': 42});
      final reset = find.text('Restore quiet motion defaults');
      await t.ensureVisible(reset);
      await t.tap(reset);
      await t.pumpAndSettle();
      expect(saved['focusTyping'], false);
      expect(saved['future'], {'retained': 42});
      await t.tap(find.text('Done'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'studio fits 320px at large text and persists no note mutations',
    (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        host(
          scale: 2.5,
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showMotionStudio(context, text: 'Authored source'),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      expect(find.text('Text presentation'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.tap(find.text('Done'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );
}
