import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_components.dart';

Widget host(Widget child, {String mode = 'normal', bool osReduced = false}) =>
    MaterialApp(
      home: OrbitMotionScope(
        preference: mode,
        osReduced: osReduced,
        child: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('content transition retains editor focus and immediate input', (
    tester,
  ) async {
    final focus = FocusNode();
    final controller = TextEditingController();
    addTearDown(focus.dispose);
    addTearDown(controller.dispose);
    Widget content(int identity) => host(
      OrbitContentTransition(
        identity: identity,
        child: TextField(focusNode: focus, controller: controller),
      ),
    );
    await tester.pumpWidget(content(0));
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Kept text');
    await tester.pumpWidget(content(1));
    expect(focus.hasFocus, isTrue);
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Still typing');
    expect(controller.text, 'Still typing');
    await tester.pumpWidget(content(2));
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final mode in ['normal', 'reduced', 'off']) {
    testWidgets('$mode transition settles and keeps the current content only', (
      tester,
    ) async {
      Widget content(int identity) => host(
        OrbitContentTransition(
          identity: identity,
          child: Text('Page $identity'),
        ),
        mode: mode,
      );
      await tester.pumpWidget(content(0));
      await tester.pumpWidget(content(1));
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(OrbitContentTransition),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, mode == 'off' ? 1 : lessThan(1));
      final transform = tester.widget<Transform>(
        find.descendant(
          of: find.byType(OrbitContentTransition),
          matching: find.byType(Transform),
        ),
      );
      expect(
        transform.transform.storage[13],
        mode == 'normal' ? greaterThan(0) : 0,
      );
      expect(find.text('Page 0'), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });
  }

  testWidgets('OS reduction cancels travel during a transition', (
    tester,
  ) async {
    Widget content(int identity, bool reduced) => host(
      OrbitContentTransition(identity: identity, child: const Text('Content')),
      osReduced: reduced,
    );
    await tester.pumpWidget(content(0, false));
    await tester.pumpWidget(content(1, false));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpWidget(content(1, true));
    final transform = tester.widget<Transform>(
      find.descendant(
        of: find.byType(OrbitContentTransition),
        matching: find.byType(Transform),
      ),
    );
    expect(transform.transform.storage[13], 0);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets(
    'disclosures retain text and remove hidden focus on rapid reversal',
    (tester) async {
      final controller = TextEditingController(text: 'Retain draft');
      final focus = FocusNode();
      addTearDown(focus.dispose);
      addTearDown(controller.dispose);
      Widget content(bool visible) => host(
        Align(
          alignment: Alignment.topLeft,
          child: OrbitDisclosure(
            visible: visible,
            child: SizedBox(
              width: 300,
              height: 100,
              child: TextField(controller: controller, focusNode: focus),
            ),
          ),
        ),
      );
      await tester.pumpWidget(content(true));
      await tester.tap(find.byType(TextField));
      await tester.pumpWidget(content(false));
      expect(find.byType(TextField), findsNothing);
      expect(focus.hasFocus, isFalse);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpWidget(content(true));
      await tester.pumpAndSettle();
      expect(controller.text, 'Retain draft');
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
