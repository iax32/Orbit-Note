import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_components.dart';
import 'package:orbit_note/app/orbit_theme.dart';

void main() {
  testWidgets(
    'Orbit controls activate by keyboard and disabled controls remain inert',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: Column(
              children: [
                OrbitControl(label: 'Write', onPressed: () => calls++),
                const OrbitControl(label: 'Unavailable', onPressed: null),
              ],
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(calls, 1);
      await tester.tap(find.text('Unavailable'));
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('motion preferences cap spatial travel and honor the OS', (
    tester,
  ) async {
    for (final (mode, os, duration, spatial) in [
      ('normal', false, OrbitMotion.panel, OrbitMotion.panel),
      ('reduced', false, OrbitMotion.micro, Duration.zero),
      ('normal', true, OrbitMotion.micro, Duration.zero),
      ('off', false, Duration.zero, Duration.zero),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: OrbitMotionScope(
            preference: mode,
            osReduced: os,
            child: Builder(
              builder: (context) {
                expect(
                  OrbitMotionScope.duration(context, OrbitMotion.panel),
                  duration,
                );
                expect(
                  OrbitMotionScope.duration(
                    context,
                    OrbitMotion.panel,
                    spatial: true,
                  ),
                  spatial,
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    }
  });
  testWidgets(
    'Orbit dialog actions remain reachable with large text on a narrow window',
    (tester) async {
      tester.view.physicalSize = const Size(480, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var saved = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: OrbitDialog(
            title: const Text('Workspace preferences'),
            content: Column(
              children: List.generate(20, (i) => Text('Preference $i')),
            ),
            actions: [
              TextButton(
                onPressed: () => saved = true,
                child: const Text('Save preferences'),
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Save preferences'));
      expect(saved, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
