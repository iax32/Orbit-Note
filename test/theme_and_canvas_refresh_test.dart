import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/app_preferences.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/orbit_theme_cache.dart';
import 'package:orbit_note/domain/json_values.dart';
import 'package:flutter/services.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_scene_viewport.dart';

class _ReadOnlySamples extends ListBase<int> {
  _ReadOnlySamples(int count)
    : values = List.unmodifiable(List.generate(count, (i) => i));
  final List<int> values;
  int reads = 0;
  @override
  int get length => values.length;
  @override
  set length(int value) => throw UnsupportedError('immutable');
  @override
  int operator [](int index) {
    reads++;
    return values[index];
  }

  @override
  void operator []=(int index, int value) =>
      throw UnsupportedError('immutable');
}

class _PalettePainter extends CustomPainter {
  _PalettePainter(this.colors, this.scheme, this.count);
  final OrbitColors colors;
  final ColorScheme scheme;
  final VoidCallback count;
  @override
  void paint(Canvas canvas, Size size) {
    count();
    canvas.drawColor(colors.canvasBackground, BlendMode.src);
  }

  @override
  bool shouldRepaint(_PalettePainter old) =>
      colors != old.colors || scheme != old.scheme;
}

void main() {
  testWidgets(
    'adopted authoritative Canvas revisions do not reset on every parent refresh',
    (tester) async {
      var object = UniversalObject(
        id: 'board',
        workspaceId: 'work',
        typeId: 'orbit.canvas',
        title: 'Board',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        data: {
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'box',
              'type': 'rectangle',
              'x': 40.0,
              'y': 40.0,
              'width': 100.0,
              'height': 80.0,
            },
          ],
        },
      );
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, set) {
                update = set;
                return CanvasEditor(
                  canvasId: object.id,
                  data: {...object.data},
                  draftBaseData: object.data,
                  objects: const [],
                  onOpenObject: (_) {},
                  onChanged: (next) {
                    update(() => object = object.copyWith(data: next));
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final viewport = find.byType(CanvasSceneViewport);
      await tester.tapAt(tester.getTopLeft(viewport) + const Offset(80, 80));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      update(
        () => object = object.copyWith(
          data: {
            'schemaVersion': 1,
            'elements': [
              {
                'id': 'box',
                'type': 'rectangle',
                'x': 220.0,
                'y': 40.0,
                'width': 100.0,
                'height': 80.0,
              },
            ],
          },
        ),
      );
      await tester.pump();
      final scene = tester.widget<CanvasSceneViewport>(viewport).scene;
      expect(scene['box']!.x, 220);
      for (var i = 0; i < 10; i++) {
        update(() {});
        await tester.pump();
      }
      expect(
        identical(tester.widget<CanvasSceneViewport>(viewport).scene, scene),
        true,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(tester.widget<CanvasSceneViewport>(viewport).scene['box']!.x, 220);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    },
  );
  test('equivalent preference snapshots reuse the exact MaterialApp theme', () {
    final cache = OrbitThemeCache();
    final p = AppPreferences(
      themePreset: 'paper',
      colorOverrides: {'canvasGrid': 0xffababab},
    );
    final original = cache.resolve(p, Brightness.light);
    for (var i = 0; i < 100; i++) {
      p.colorOverrides = Map.of(p.colorOverrides);
      p.customThemes = [...p.customThemes];
      expect(identical(cache.resolve(p, Brightness.light), original), true);
    }
    expect(
      identical(cache.resolve(p, Brightness.dark), original),
      true,
      reason: 'Manual appearance ignores platform changes',
    );
    p.followSystemAppearance = true;
    final light = cache.resolve(p, Brightness.light);
    expect(identical(light, cache.resolve(p, Brightness.dark)), false);
  });
  test(
    'real appearance and in-place override changes always invalidate the memo',
    () {
      final changes = <void Function(AppPreferences)>[
        (p) => p.themePreset = 'paper',
        (p) => p.compact = true,
        (p) => p.uiZoom = 1.2,
        (p) => p.fontFamily = 'Arial',
        (p) => p.documentFontFamily = 'Georgia',
        (p) => p.monoFontFamily = 'Courier New',
        (p) => p.codeFontSize = 18,
        (p) => p.showLineNumbers = false,
        (p) => p.defaultCodeWrap = true,
        (p) => p.cornerStyle = 'subtle',
        (p) => p.accentColor = 'cyan',
        (p) => p.colorOverrides['canvasBackground'] = 0xff222222,
        (p) => p.customThemes.add({
          'id': 'future-custom',
          'extra': {'future': 42},
        }),
      ];
      for (final change in changes) {
        final cache = OrbitThemeCache();
        final p = AppPreferences(colorOverrides: {}, customThemes: []);
        final before = cache.resolve(p, Brightness.light);
        change(p);
        expect(identical(before, cache.resolve(p, Brightness.light)), false);
      }
    },
  );
  test('no-op palette interpolation is stable at every animation fraction', () {
    for (final p in [
      const OrbitColors(),
      OrbitThemePack.fromId('paper').colors,
    ]) {
      for (var i = 0; i <= 100; i++) {
        expect(identical(p.lerp(p.copyWith(), i / 100), p), true);
      }
      expect(p.lerp(p.copyWith(text: Colors.red), .5), isNot(p));
    }
  });
  test(
    'immutable drawing echoes are compared once; real updates and rejection still win',
    () {
      final cache = ImmutableJsonEqualityCache();
      final inputSamples = _ReadOnlySamples(50000),
          expectedSamples = _ReadOnlySamples(50000);
      final input = <String, dynamic>{'elements': inputSamples, 'future': 42};
      final target = <String, dynamic>{
        'elements': expectedSamples,
        'future': 42,
      };
      expect(cache.matches(input, target), true);
      final reads = inputSamples.reads + expectedSamples.reads;
      for (var i = 0; i < 50; i++) {
        expect(cache.matches({...input}, target), true);
      }
      expect(
        inputSamples.reads + expectedSamples.reads,
        reads,
        reason: 'Parent refresh must not walk 50k samples again',
      );
      final rejected = <String, dynamic>{
        'elements': const [3],
        'future': 42,
      };
      expect(cache.matches({...input}, rejected), false);
      final remote = <String, dynamic>{
        'elements': const [7, 8],
        'future': 43,
      };
      expect(cache.matches({...remote}, target), false);
      expect(cache.matches({...remote}, remote), true);
      expect(cache.matches({...remote, 'future': 44}, remote), false);
    },
  );
  testWidgets(
    'ordinary app refreshes do not animate or repaint an unchanged palette',
    (tester) async {
      final p = AppPreferences(themePreset: 'paper', colorOverrides: {});
      final cache = OrbitThemeCache();
      var paints = 0;
      late StateSetter update;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return MaterialApp(
              theme: cache.resolve(p, Brightness.light),
              themeAnimationDuration: const Duration(milliseconds: 160),
              home: Builder(
                builder: (context) => RepaintBoundary(
                  child: CustomPaint(
                    painter: _PalettePainter(
                      OrbitColors.of(context),
                      Theme.of(context).colorScheme,
                      () => paints++,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      final initial = paints;
      for (var i = 0; i < 20; i++) {
        update(() => p.colorOverrides = Map.of(p.colorOverrides));
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(
        paints,
        initial,
        reason:
            'Save/sync/camera refreshes must not restart the theme animation',
      );
      update(() => p.themePreset = 'orbit');
      await tester.pumpAndSettle();
      expect(paints, greaterThan(initial));
      expect(tester.takeException(), isNull);
    },
  );
}
