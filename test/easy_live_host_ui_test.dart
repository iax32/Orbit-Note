import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/workspace/collaboration_settings.dart';
import 'canvas_shared_presence_test.dart' show CanvasSessions;

void main() {
  testWidgets(
    'live sharing opens with simple buttons and hides manual server fields',
    (tester) async {
      late CanvasSessions f;
      await tester.runAsync(() async {
        HttpOverrides.global = null;
        f = CanvasSessions();
        await f.open();
      });
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showCollaborationSettings(context, f.first),
                  child: const Text('Open sharing'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open sharing'));
      await tester.pumpAndSettle();
      if (Platform.isWindows) {
        expect(find.text('Start live sharing'), findsOneWidget);
      }
      // Fixture is already connected. Disconnect exposes the simple Join path.
      f.first.disconnect();
      await tester.pumpAndSettle();
      expect(find.text('Join shared Vault'), findsOneWidget);
      expect(find.text('Server owner key'), findsNothing);
      expect(find.text('Server address'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(f.close);
    },
  );
}
