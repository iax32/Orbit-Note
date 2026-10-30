import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_components.dart';
import 'package:orbit_note/features/canvas/canvas_focus_controls.dart';

void main() {
  const position = ValueKey('canvas-focus-position');
  const body = ValueKey('test-controls');
  Widget controls({
    bool expanded = false,
    void Function(Offset, bool)? onChanged,
  }) => CanvasFocusControls(
    expanded: expanded,
    onPlacementChanged: onChanged,
    toolbar: const Material(
      key: ValueKey('tools'),
      child: SizedBox(height: 56),
    ),
    dock: const Material(child: SizedBox(width: 192, height: 48)),
  );
  Widget host(
    Widget child, {
    Size size = const Size(640, 480),
    String motion = 'normal',
    bool reduced = false,
  }) => MaterialApp(
    home: OrbitMotionScope(
      preference: motion,
      osReduced: reduced,
      child: Scaffold(
        body: Center(
          child: SizedBox(
            key: body,
            width: size.width,
            height: size.height,
            child: child,
          ),
        ),
      ),
    ),
  );
  Future<void> choose(WidgetTester t, String label) async {
    await t.tap(find.byKey(position));
    await t.pumpAndSettle();
    await t.tap(find.text(label));
    await t.pumpAndSettle();
  }

  testWidgets('drag clamps, snaps and keeps the parent Canvas untouched', (
    t,
  ) async {
    Offset? anchor;
    var parentBuilds = 0;
    await t.pumpWidget(
      host(
        Builder(
          builder: (_) {
            parentBuilds++;
            return controls(onChanged: (value, locked) => anchor = value);
          },
        ),
      ),
    );
    final before = t.getRect(find.byKey(position));
    await t.drag(find.byKey(position), const Offset(-1000, 1000));
    await t.pumpAndSettle();
    final after = t.getRect(find.byKey(position));
    final bounds = t.getRect(find.byKey(body));
    expect(after.left, lessThan(before.left));
    expect(after.bottom, closeTo(bounds.bottom - 8, 1));
    expect(anchor, const Offset(0, 1));
    expect(parentBuilds, 1);
    await choose(t, 'Lock position');
    final locked = t.getRect(find.byKey(position));
    await t.drag(find.byKey(position), const Offset(150, -150));
    await t.pumpAndSettle();
    expect(t.getRect(find.byKey(position)), locked);
    await choose(t, 'Reset position');
    expect(t.getRect(find.byKey(position)), before);
    expect(t.takeException(), isNull);
  });
  testWidgets('bottom docking opens upwards and survives narrow resize', (
    t,
  ) async {
    await t.pumpWidget(host(controls(expanded: true)));
    await choose(t, 'Bottom left');
    final grip = t.getRect(find.byKey(position));
    final tools = t.getRect(find.byKey(const ValueKey('tools')));
    expect(grip.bottom, lessThan(tools.top));
    expect(grip.left, closeTo(t.getRect(find.byKey(body)).left + 8, 1));
    await t.pumpWidget(
      host(controls(expanded: true), size: const Size(240, 240)),
    );
    await t.pumpAndSettle();
    final bounds = t.getRect(find.byKey(body));
    for (final key in [position, const ValueKey('tools')]) {
      final rect = t.getRect(find.byKey(key));
      expect(rect.left, greaterThanOrEqualTo(bounds.left));
      expect(rect.right, lessThanOrEqualTo(bounds.right));
      expect(rect.top, greaterThanOrEqualTo(bounds.top));
      expect(rect.bottom, lessThanOrEqualTo(bounds.bottom));
    }
    expect(t.takeException(), isNull);
  });
  testWidgets('grabbing a settling toolbar interrupts motion without a jump', (
    t,
  ) async {
    await t.pumpWidget(host(controls()));
    await t.tap(find.byKey(position));
    await t.pumpAndSettle();
    await t.tap(find.text('Bottom right'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 30));
    final start = t.getCenter(find.byKey(position));
    final gesture = await t.startGesture(start);
    await gesture.moveBy(const Offset(-30, 0));
    await t.pump();
    final after = t.getCenter(find.byKey(position));
    expect((after.dy - start.dy).abs(), lessThan(2));
    await gesture.up();
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  for (final mode in ['normal', 'reduced', 'off', 'os-reduced']) {
    testWidgets('$mode motion keeps direct dragging and hidden tools usable', (
      t,
    ) async {
      await t.pumpWidget(
        host(
          controls(),
          motion: mode == 'os-reduced' ? 'normal' : mode,
          reduced: mode == 'os-reduced',
        ),
      );
      final animation = t.widget<AnimatedAlign>(find.byType(AnimatedAlign));
      expect(
        animation.duration,
        mode == 'normal' ? const Duration(milliseconds: 180) : Duration.zero,
      );
      final menu = t.widget<PopupMenuButton<String>>(find.byKey(position));
      expect(
        menu.popUpAnimationStyle!.duration,
        mode == 'normal' ? const Duration(milliseconds: 200) : Duration.zero,
      );
      expect(find.byKey(const ValueKey('tools')), findsNothing);
      await t.drag(find.byKey(position), const Offset(-60, 80));
      await t.pumpAndSettle();
      expect(find.byKey(position), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
