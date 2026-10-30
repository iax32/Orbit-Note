import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_components.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/session_state.dart';
import 'support/capture_ui.dart';

Widget host(
  Widget child, {
  String mode = 'normal',
  bool reduced = false,
  Map<String, dynamic> options = const {},
  bool tickers = true,
}) => OrbitMotionScope(
  preference: mode,
  osReduced: reduced,
  options: options,
  child: MaterialApp(
    theme: orbitDarkTheme(),
    home: TickerMode(
      enabled: tickers,
      child: Scaffold(body: Center(child: child)),
    ),
  ),
);

void main() {
  test(
    'session UI hints remain mutable without changing caller-owned options',
    () {
      const source = {'settingsCategory': 'sync', 'future': 7};
      final session = SessionState(extra: source);
      expect(session.extra.remove('settingsCategory'), 'sync');
      session.extra['anotherHint'] = true;
      expect(source, {'settingsCategory': 'sync', 'future': 7});
      expect(session.toJson()['future'], 7);
      expect(
        SessionState.fromJson(session.toJson()).extra['anotherHint'],
        true,
      );
    },
  );
  testWidgets(
    'menu and sheet timing follows speed, reduction and category controls',
    (t) async {
      AnimationStyle? popup;
      Future<void> view({
        String mode = 'normal',
        bool reduced = false,
        Map<String, dynamic> options = const {},
      }) => t.pumpWidget(
        host(
          Builder(
            builder: (context) {
              popup = OrbitMotionScope.popupStyle(context);
              return const SizedBox();
            },
          ),
          mode: mode,
          reduced: reduced,
          options: options,
        ),
      );
      await view(options: {'speed': 2});
      expect(popup!.duration, const Duration(milliseconds: 90));
      for (final mode in ['off', 'reduced']) {
        await view(mode: mode);
        expect(popup, AnimationStyle.noAnimation);
      }
      await view(reduced: true);
      expect(popup, AnimationStyle.noAnimation);
      await view(options: {'navigation': false});
      expect(popup, AnimationStyle.noAnimation);
    },
  );

  testWidgets(
    'Orbit dialog arrival is visually restrained and keeps real controls',
    (t) async {
      await prepareCapture(t);
      await t.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('motion-capture'),
          child: host(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showOrbitDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Canvas tools'),
                    content: const Text(
                      'Your drawing stays in place. Choose a tool and keep working.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
                child: const Text('Open tools'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open tools'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      await captureUi(
        t,
        'orbit-dialog-arriving',
        target: find.byKey(const ValueKey('motion-capture')),
        settle: false,
      );
      await t.pumpAndSettle();
      await captureUi(
        t,
        'orbit-dialog-settled',
        target: find.byKey(const ValueKey('motion-capture')),
      );
      await t.tap(find.text('Done'));
      await t.pumpAndSettle();
      expect(find.text('Canvas tools'), findsNothing);
    },
  );

  for (final policy in ['normal', 'reduced', 'off', 'os', 'category']) {
    testWidgets('$policy modal returns immediately and mounts one focus tree', (
      t,
    ) async {
      String? result;
      var dialogBuilds = 0;
      await t.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showOrbitDialog<String>(
                  context: context,
                  barrierDismissible: false,
                  routeSettings: const RouteSettings(name: 'motion-check'),
                  builder: (context) {
                    dialogBuilds++;
                    return AlertDialog(
                      title: const Text('Single dialog'),
                      content: const TextField(),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, 'done'),
                          child: const Text('Accept'),
                        ),
                      ],
                    );
                  },
                );
              },
              child: const Text('Open'),
            ),
          ),
          mode: policy == 'reduced' || policy == 'off' ? policy : 'normal',
          reduced: policy == 'os',
          options: policy == 'category' ? {'navigation': false} : const {},
        ),
      );
      await t.tap(find.text('Open'));
      await t.pump();
      expect(find.byType(TextField), findsOneWidget);
      await t.enterText(find.byType(TextField), 'Immediate input');
      expect(find.text('Immediate input'), findsOneWidget);
      // Close during the arrival, without waiting for visual settlement.
      await t.tap(find.text('Accept'));
      await t.pump();
      expect(result, 'done');
      await t.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(dialogBuilds, 1);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('entrance policies preserve local field state and focus', (
    t,
  ) async {
    Widget view(String mode, bool reduced) => host(
      const OrbitEntrance(
        spatial: true,
        child: OrbitFadeScale(child: TextField()),
      ),
      mode: mode,
      reduced: reduced,
    );
    await t.pumpWidget(view('normal', false));
    await t.enterText(find.byType(TextField), 'Keep my draft');
    final field = t.state(find.byType(TextField));
    final editable = t.widget<EditableText>(find.byType(EditableText));
    for (final policy in [
      ('off', false),
      ('normal', false),
      ('reduced', false),
      ('normal', true),
    ]) {
      await t.pumpWidget(view(policy.$1, policy.$2));
      await t.pumpAndSettle();
      expect(identical(t.state(find.byType(TextField)), field), isTrue);
      expect(editable.focusNode.hasFocus, isTrue);
      expect(find.text('Keep my draft'), findsOneWidget);
    }
    expect(t.takeException(), isNull);
  });

  testWidgets('live modal reduction keeps its draft and input identity', (
    t,
  ) async {
    var mode = 'normal';
    late StateSetter change;
    await t.pumpWidget(
      StatefulBuilder(
        builder: (context, update) {
          change = update;
          return host(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showOrbitDialog<void>(
                  context: context,
                  builder: (_) => const AlertDialog(content: TextField()),
                ),
                child: const Text('Open'),
              ),
            ),
            mode: mode,
          );
        },
      ),
    );
    await t.tap(find.text('Open'));
    await t.pump();
    await t.enterText(find.byType(TextField), 'Unchanged modal draft');
    final field = t.state(find.byType(TextField));
    change(() => mode = 'off');
    await t.pumpAndSettle();
    expect(t.state(find.byType(TextField)), same(field));
    expect(find.text('Unchanged modal draft'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'hidden fading actions lose keyboard, pointer and semantic access',
    (t) async {
      var clicks = 0;
      final focus = FocusNode();
      addTearDown(focus.dispose);
      Widget view(bool visible) => host(
        OrbitActionReveal(
          visible: visible,
          child: TextButton(
            focusNode: focus,
            onPressed: () => clicks++,
            child: const Text('Context action'),
          ),
        ),
      );
      await t.pumpWidget(view(true));
      focus.requestFocus();
      await t.pump();
      final before = t.getRect(find.byType(TextButton));
      await t.pumpWidget(view(false));
      await t.pump();
      expect(focus.hasFocus, isFalse);
      await t.tapAt(before.center);
      expect(clicks, 0);
      expect(
        t
            .widget<ExcludeSemantics>(find.byType(ExcludeSemantics).first)
            .excluding,
        isTrue,
      );
      await t.pumpWidget(view(true));
      await t.pumpAndSettle();
      await t.tap(find.text('Context action'));
      expect(clicks, 1);
      expect(t.getRect(find.byType(TextButton)), before);
    },
  );

  testWidgets(
    'inactive, reduced, off, OS and hidden effects stop their tickers',
    (t) async {
      Widget view({
        String mode = 'normal',
        bool reduced = false,
        bool enabled = true,
        bool active = true,
        Map<String, dynamic> options = const {},
      }) => host(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OrbitBreathingGlow(active: active, child: const Text('Timer')),
            SizedBox(
              width: 150,
              child: OrbitPulseBadge(label: 'Active', active: active),
            ),
          ],
        ),
        mode: mode,
        reduced: reduced,
        tickers: enabled,
        options: options,
      );
      await t.pumpWidget(view());
      await t.pump(const Duration(milliseconds: 40));
      expect(t.hasRunningAnimations, isTrue);
      for (final widget in [
        view(mode: 'reduced'),
        view(mode: 'off'),
        view(reduced: true),
        view(enabled: false),
        view(active: false),
        view(options: {'navigation': false}),
      ]) {
        await t.pumpWidget(widget);
        await t.pump(const Duration(milliseconds: 300));
        expect(t.hasRunningAnimations, isFalse);
      }
      await t.pumpWidget(view());
      await t.pump(const Duration(milliseconds: 40));
      expect(t.hasRunningAnimations, isTrue);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'status changes never mount outgoing data or rebuild the static child per tick',
    (t) async {
      var builds = 0;
      final heavy = Builder(
        builder: (_) {
          builds++;
          return const Text('Heavy preview');
        },
      );
      Widget view(int id) => host(
        OrbitStateMotion(
          identity: id,
          child: Column(children: [Text('State $id'), heavy]),
        ),
      );
      await t.pumpWidget(view(0));
      await t.pumpAndSettle();
      await t.pumpWidget(view(1));
      final afterUpdate = builds;
      for (var frame = 0; frame < 16; frame++) {
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(builds, afterUpdate);
      expect(find.text('State 0'), findsNothing);
      expect(find.text('State 1'), findsOneWidget);
      expect(
        t
            .widget<Opacity>(
              find.descendant(
                of: find.byType(OrbitStateMotion),
                matching: find.byType(Opacity),
              ),
            )
            .opacity,
        1,
      );
      await t.pumpAndSettle();
      expect(t.hasRunningAnimations, isFalse);
      await t.pumpWidget(view(2));
      await t.pumpWidget(view(3));
      await t.pumpAndSettle();
      expect(find.text('State 2'), findsNothing);
      expect(find.text('State 3'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
