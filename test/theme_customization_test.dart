import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_app.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  test(
    'custom colors round-trip, tolerate old sessions and preserve unknown roles',
    () {
      final session = SessionState.fromJson({
        'colorOverrides': {
          'background': 0xff123456,
          'futureRole': 0xff345678,
          'invalid': 'blue',
          'transparent': 0x00123456,
          'overflow': 0x100000000,
        },
      });
      expect(session.colorOverrides, {
        'background': 0xff123456,
        'futureRole': 0xff345678,
      });
      expect(
        SessionState.fromJson(session.toJson()).colorOverrides,
        session.colorOverrides,
      );
      expect(SessionState.fromJson({}).colorOverrides, isEmpty);
      final theme = orbitDarkTheme(colorOverrides: session.colorOverrides);
      expect(theme.scaffoldBackgroundColor, const Color(0xff123456));
      expect(
        theme.extension<OrbitColors>()!.background,
        const Color(0xff123456),
      );
    },
  );

  test(
    'all roles override together and Material controls follow the palette',
    () {
      final overrides = {
        for (final key in OrbitColors.roleLabels.keys) key: 0xff234567,
      };
      final colors = const OrbitColors().withOverrides(overrides);
      expect(colors.roles.values, everyElement(const Color(0xff234567)));
      final theme = orbitDarkTheme(colorOverrides: overrides);
      expect(theme.colorScheme.primary, colors.accent);
      expect(theme.colorScheme.outline, colors.border);
      expect(theme.colorScheme.onSurface, colors.text);
      expect(theme.colorScheme.error, colors.danger);
      expect(
        const OrbitColors().withOverrides({}).roles,
        const OrbitColors().roles,
      );
    },
  );

  testWidgets('validated color edits apply live and recovery remains reachable', (
    tester,
  ) async {
    final repo = WorkspaceRepository(
      store: MemoryStore(),
      index: MemoryObjectIndex(),
    );
    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final c = container.read(workspaceProvider.notifier);
    await c.initialize();
    c.updateSession((s) {
      s.motion = 'off';
      s.spellCheckEnabled = false;
    });
    c.navigate(OrbitDestination.settings);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const OrbitNoteApp(),
      ),
    );
    await tester.pump();
    final expand = find.byKey(const ValueKey('settings-custom-colors'));
    await tester.ensureVisible(expand);
    await tester.tap(find.text('Customize interface colors'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final background = find.byKey(const ValueKey('theme-color-background'));
    await Scrollable.ensureVisible(tester.element(background), alignment: .5);
    await tester.pump();
    await tester.tap(background);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final hex = find.byKey(const ValueKey('theme-color-hex'));
    await tester.enterText(hex, 'bad!');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('theme-color-apply')))
          .onPressed,
      isNull,
    );
    await tester.enterText(hex, '123456');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('theme-color-apply')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.session.colorOverrides['background'], 0xff123456);
    expect(
      tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .theme!
          .scaffoldBackgroundColor,
      const Color(0xff123456),
    );
    // Recovery buttons use a stable neutral palette even for unreadable choices.
    c.updateSession(
      (s) => s.colorOverrides = {'background': 0xff000000, 'text': 0xff000000},
    );
    await tester.pump();
    final reset = find.byKey(const ValueKey('theme-colors-reset'));
    await Scrollable.ensureVisible(tester.element(reset), alignment: .5);
    await tester.pump();
    await tester.tap(reset);
    await tester.pump();
    expect(c.session.colorOverrides, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.runAsync(c.flushAll);
    c.cancelAllTimers();
  });
}
