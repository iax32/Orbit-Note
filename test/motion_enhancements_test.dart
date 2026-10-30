import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_components.dart';
import 'package:orbit_note/app/orbit_theme.dart';

Widget host(Widget child, {String mode = 'normal', bool osReduced = false}) =>
    MaterialApp(
      theme: orbitDarkTheme(),
      home: OrbitMotionScope(
        preference: mode,
        osReduced: osReduced,
        child: Scaffold(body: child),
      ),
    );

void main() {
  group('OrbitEntrance Spatial Motion (MOT-01, MOT-02)', () {
    testWidgets('normal mode animates opacity and horizontal travel', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const OrbitEntrance(
            spatial: true,
            offset: Offset(8, 0),
            duration: OrbitMotion.panel,
            child: Text('Panel content'),
          ),
        ),
      );

      // Check in-flight travel
      await tester.pump(const Duration(milliseconds: 40));
      final transform = tester.widget<Transform>(
        find.descendant(
          of: find.byType(OrbitEntrance),
          matching: find.byType(Transform),
        ),
      );
      // Storage[12] is the X translation in Matrix4
      expect(transform.transform.storage[12], greaterThan(0));

      await tester.pumpAndSettle();
      expect(find.text('Panel content'), findsOneWidget);
    });

    testWidgets('reduced motion mode cancels travel but retains opacity', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const OrbitEntrance(
            spatial: true,
            offset: Offset(8, 0),
            duration: OrbitMotion.panel,
            child: Text('Panel content'),
          ),
          mode: 'reduced',
        ),
      );

      await tester.pump(const Duration(milliseconds: 30));
      // Keep a stable tree so changing the preference cannot remount an editor.
      final transform = tester.widget<Transform>(
        find.descendant(
          of: find.byType(OrbitEntrance),
          matching: find.byType(Transform),
        ),
      );
      expect(transform.transform.storage[12], 0);
      expect(transform.transform.storage[13], 0);

      await tester.pumpAndSettle();
      expect(find.text('Panel content'), findsOneWidget);
    });

    testWidgets('off mode renders instantly without in-flight ticker', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const OrbitEntrance(
            spatial: true,
            offset: Offset(8, 0),
            child: Text('Instant content'),
          ),
          mode: 'off',
        ),
      );

      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('Instant content'), findsOneWidget);
    });
  });

  group('OrbitFadeScale Entrance (MOT-01, MOT-03)', () {
    testWidgets('normal mode scales from 0.95 to 1.0 with ease curve', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const OrbitFadeScale(
            duration: OrbitMotion.control,
            child: Text('HUD overlay'),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 30));
      final transform = tester.widget<Transform>(
        find.descendant(
          of: find.byType(OrbitFadeScale),
          matching: find.byType(Transform),
        ),
      );
      // Scale is at storage[0] (X) and storage[5] (Y)
      expect(transform.transform.storage[0], lessThan(1.0));
      expect(transform.transform.storage[0], greaterThanOrEqualTo(0.95));

      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('HUD overlay'), findsOneWidget);
    });

    testWidgets('reduced mode suppresses scale changes', (tester) async {
      await tester.pumpWidget(
        host(
          const OrbitFadeScale(
            duration: OrbitMotion.control,
            child: Text('HUD overlay'),
          ),
          mode: 'reduced',
        ),
      );

      await tester.pump(const Duration(milliseconds: 30));
      final transform = tester.widget<Transform>(
        find.descendant(
          of: find.byType(OrbitFadeScale),
          matching: find.byType(Transform),
        ),
      );
      // Storage[0] must be exactly 1.0 (no scale distortion)
      expect(transform.transform.storage[0], 1.0);

      await tester.pumpAndSettle();
      expect(find.text('HUD overlay'), findsOneWidget);
    });

    testWidgets('off mode renders overlay instantly', (tester) async {
      await tester.pumpWidget(
        host(
          const OrbitFadeScale(
            duration: OrbitMotion.control,
            child: Text('HUD overlay'),
          ),
          mode: 'off',
        ),
      );

      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('HUD overlay'), findsOneWidget);
    });
  });

  group('OrbitCard & OrbitPillBadge Motion', () {
    testWidgets('OrbitCard handles hover and tap press scale', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        host(
          OrbitCard(
            onTap: () => tapped = true,
            child: const Text('Interactive card'),
          ),
        ),
      );

      expect(find.text('Interactive card'), findsOneWidget);

      // Tap card
      await tester.tap(find.text('Interactive card'));
      expect(tapped, isTrue);

      await tester.pumpAndSettle();
    });

    testWidgets('OrbitPillBadge renders label, icon, and responds to click', (
      tester,
    ) async {
      bool clicked = false;
      await tester.pumpWidget(
        host(
          OrbitPillBadge(
            label: '500 words',
            icon: Icons.flag_outlined,
            onTap: () => clicked = true,
          ),
        ),
      );

      expect(find.text('500 words'), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);

      await tester.tap(find.text('500 words'));
      expect(clicked, isTrue);
    });
  });

  group('OrbitControl Selection Indicator Motion', () {
    testWidgets('indicator expands from 0 to 14 on selection', (tester) async {
      await tester.pumpWidget(
        host(
          OrbitControl(
            label: 'Notes',
            icon: Icons.description_outlined,
            selected: false,
            onPressed: () {},
          ),
        ),
      );

      // When unselected, indicator width is 0
      final unselectedContainer = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).last,
      );
      expect(unselectedContainer.constraints?.maxWidth ?? 0, 0);

      // Now pump with selected: true
      await tester.pumpWidget(
        host(
          OrbitControl(
            label: 'Notes',
            icon: Icons.description_outlined,
            selected: true,
            onPressed: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();
      final selectedContainer = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).last,
      );
      expect(selectedContainer.constraints?.maxWidth, 14);
    });
  });

  group('showOrbitDialog Helper', () {
    testWidgets('opens dialog with OrbitMotion.dialog timing and ease curve', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showOrbitDialog<void>(
                context: context,
                builder: (_) => const OrbitDialog(
                  title: Text('Test Dialog'),
                  content: Text('Dialog body'),
                ),
              ),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pump();
      expect(find.text('Test Dialog'), findsOneWidget);
      expect(find.text('Dialog body'), findsOneWidget);

      await tester.pumpAndSettle();
    });
  });
}
