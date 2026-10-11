import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/app_zoom.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/orbit_density.dart';
import 'package:orbit_note/app/orbit_theme.dart';

void main() {
  test(
    'zoom persists, bounds malformed values and preserves future settings',
    () {
      expect(SessionState.fromJson({}).uiZoom, 1);
      final s = SessionState.fromJson({'uiZoom': 1.5, 'future': 'keep'});
      expect(SessionState.fromJson(s.toJson()).uiZoom, 1.5);
      expect(s.toJson()['future'], 'keep');
      expect(SessionState.fromJson({'uiZoom': 999}).uiZoom, 2);
      expect(SessionState.fromJson({'uiZoom': double.nan}).uiZoom, 1);
      expect(nextAppZoom(2, 1), 2);
      expect(nextAppZoom(.75, -1), .75);
    },
  );

  testWidgets(
    'whole interface scales, hits align and editing state survives shortcuts',
    (tester) async {
      var zoom = 1.0;
      var taps = 0;
      late StateSetter refresh;
      final text = TextEditingController(text: 'Keep this note');
      addTearDown(text.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => StatefulBuilder(
            builder: (context, setState) {
              refresh = setState;
              return AppZoom(
                zoom: zoom,
                onChanged: (v) => setState(() => zoom = v),
                child: Theme(
                  data: orbitDarkTheme(uiZoom: zoom),
                  child: child!,
                ),
              );
            },
          ),
          home: Scaffold(
            body: Column(
              children: [
                TextField(controller: text),
                Builder(
                  builder: (context) => SizedBox(
                    key: const ValueKey('scaled'),
                    width: 100 * OrbitDensity.of(context).scale,
                    height: 40 * OrbitDensity.of(context).scale,
                    child: TextButton(
                      onPressed: () => taps++,
                      child: const Text('Press'),
                    ),
                  ),
                ),
                Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const AlertDialog(
                        title: Text('Still fits'),
                        content: Text('Readable dialog'),
                      ),
                    ),
                    child: const Text('Dialog'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      text.selection = const TextSelection(baseOffset: 2, extentOffset: 6);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(zoom, 1.1);
      expect(
        text.selection,
        const TextSelection(baseOffset: 2, extentOffset: 6),
      );
      expect(text.text, 'Keep this note');
      final rect = tester.getRect(find.byKey(const ValueKey('scaled')));
      expect(rect.width, closeTo(110, .01));
      await tester.tapAt(rect.center);
      await tester.pump();
      expect(taps, 1);
      refresh(() => zoom = 2);
      await tester.pump();
      await tester.tap(find.text('Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Still fits'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(zoom, 1);
    },
  );

  testWidgets('zoom composes accessibility scale and keyboard insets once', (
    tester,
  ) async {
    late MediaQueryData inside;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(800, 600),
            devicePixelRatio: 1.5,
            textScaler: TextScaler.linear(1.3),
            viewInsets: EdgeInsets.only(bottom: 100),
          ),
          child: AppZoom(
            zoom: 2,
            onChanged: (_) {},
            child: Builder(
              builder: (context) {
                inside = MediaQuery.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    expect(inside.size.width, 800);
    expect(inside.devicePixelRatio, 1.5);
    expect(inside.textScaler.scale(10), 26);
    expect(inside.viewInsets.bottom, 100);
  });
}
