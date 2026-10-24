import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_app.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/features/workspace/theme_color_settings.dart';
import 'package:orbit_note/features/workspace/theme_interchange_dialog.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

List<Color> surfaces(OrbitColors c) => [
  c.background,
  c.workspace,
  c.panel,
  c.panelSecondary,
  c.raised,
  c.floating,
  c.input,
  c.hover,
  c.pressed,
  c.selected,
  c.selectedMuted,
];

void main() {
  final additions = OrbitThemePack.builtIn
      .where((p) => p.familyId != null)
      .toList();
  test('100 new distinct palettes form 50 reversible light and dark pairs', () {
    expect(additions.length, 100);
    expect(OrbitThemePack.builtIn.length, 113);
    expect(additions.where((p) => p.brightness == Brightness.light).length, 50);
    expect(additions.map((p) => p.familyId).toSet().length, 50);
    expect(OrbitThemePack.builtIn.map((p) => p.id).toSet().length, 113);
    expect(
      additions
          .map(
            (p) => jsonEncode(
              p.colors.roles.map((k, v) => MapEntry(k, v.toARGB32())),
            ),
          )
          .toSet()
          .length,
      100,
    );
    for (final pack in additions) {
      expect(pack.companion?.companion?.id, pack.id);
      expect(pack.companion?.brightness, isNot(pack.brightness));
      expect(pack.companion?.category, pack.category);
      expect(pack.colors.roles.values.every((c) => c.a == 1), true);
    }
  });
  test(
    'all 100 palettes keep actual content surfaces and Material controls readable',
    () {
      for (final pack in additions) {
        final c = pack.colors,
            theme = orbitTheme(preset: pack.id),
            scheme = theme.colorScheme;
        for (final surface in surfaces(c)) {
          for (final entry in {
            'text': c.text,
            'subtle': c.subtle,
            'muted': c.muted,
            'accent': c.accent,
            'secondary': c.secondary,
            'accentHover': c.accentHover,
            'link': c.link,
            'visited': c.linkVisited,
            'success': c.success,
            'warning': c.warning,
            'danger': c.danger,
          }.entries) {
            expect(
              OrbitContrast.ratio(entry.value, surface),
              greaterThanOrEqualTo(entry.key == 'text' ? 7 : 4.5),
              reason:
                  '${pack.id}: ${entry.key} on ${surface.toARGB32().toRadixString(16)}',
            );
          }
          expect(
            OrbitContrast.ratio(c.focus, surface),
            greaterThanOrEqualTo(3),
          );
        }
        for (final pair in [
          (scheme.primary, scheme.onPrimary),
          (scheme.secondary, scheme.onSecondary),
          (scheme.error, scheme.onError),
        ]) {
          expect(
            OrbitContrast.ratio(pair.$1, pair.$2),
            greaterThanOrEqualTo(4.5),
            reason: pack.id,
          );
        }
        expect(c.text, isNot(c.background));
      }
    },
  );
  test(
    'bright custom accents choose readable filled-button ink in light mode',
    () {
      final scheme = orbitTheme(
        preset: 'paper',
        accentColor: const Color(0xff50bdb0),
      ).colorScheme;
      expect(
        OrbitContrast.ratio(scheme.primary, scheme.onPrimary),
        greaterThanOrEqualTo(4.5),
      );
    },
  );
  test(
    'catalog themes and theme-following preference survive JSON restart',
    () {
      for (final pack in additions) {
        final restored = OrbitThemePack.fromJson(
          jsonDecode(jsonEncode(pack.toJson())) as Map<String, dynamic>,
        );
        expect(restored.colors.roles, pack.colors.roles);
        expect(restored.companion?.id, pack.companion?.id);
        final session = SessionState.fromJson(
          SessionState(themePreset: pack.id, accentColor: 'theme').toJson(),
        );
        expect(session.accentColor, 'theme');
        expect(
          OrbitThemePack.fromId(session.themePreset).colors.roles,
          pack.colors.roles,
        );
      }
      expect(SessionState.fromJson({}).accentColor, 'theme');
      expect(
        OrbitThemePack.fromId('paper').colors.background,
        const Color(0xfff7f5ee),
      );
    },
  );

  Future<WorkspaceController> controller() async {
    final repo = WorkspaceRepository(
      store: MemoryStore(),
      index: MemoryObjectIndex(),
    );
    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    final c = container.read(workspaceProvider.notifier);
    await c.initialize();
    c.updateSession((s) {
      s.motion = 'off';
      s.spellCheckEnabled = false;
    });
    addTearDown(() {
      c.cancelAllTimers();
      container.dispose();
    });
    return c;
  }

  Future<void> selector(
    WidgetTester tester,
    WorkspaceController c, {
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: orbitTheme(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: ThemePresetSelector(controller: c),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the actual app follows palette accents and still honors explicit accent choices',
    (tester) async {
      final repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      final c = container.read(workspaceProvider.notifier);
      await c.initialize();
      addTearDown(() {
        c.cancelAllTimers();
        container.dispose();
      });
      c.updateSession((s) {
        s.motion = 'off';
        s.spellCheckEnabled = false;
        s.themePreset = 'palette-lagoon-light';
        s.accentColor = 'theme';
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const OrbitNoteApp(),
        ),
      );
      await tester.pumpAndSettle();
      ThemeData theme() =>
          tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;
      expect(
        theme().colorScheme.primary,
        OrbitThemePack.fromId('palette-lagoon-light').colors.accent,
      );
      expect(theme().brightness, Brightness.light);
      c.updateSession((s) => s.accentColor = 'rose');
      await tester.pumpAndSettle();
      expect(c.session.accentColor, 'rose');
      expect(
        OrbitContrast.ratio(
          theme().colorScheme.primary,
          theme().extension<OrbitColors>()!.workspace,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      c.cancelAllTimers();
    },
  );
  testWidgets('full gallery can find and apply a newly added palette', (
    tester,
  ) async {
    final c = await controller();
    c.updateSession((s) => s.documentFontFamily = 'Georgia');
    await tester.pumpWidget(
      MaterialApp(
        theme: orbitTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showOrbitThemeGalleryDialog(context, c),
              child: const Text('Browse'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('theme-palette-search')),
      'orchid',
    );
    await tester.pumpAndSettle();
    final apply = find.byKey(
      const ValueKey('theme-gallery-apply-palette-orchid-dark'),
    );
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(c.session.themePreset, 'palette-orchid-dark');
    expect(c.session.documentFontFamily, 'Georgia');
    expect(c.session.accentColor, 'theme');
    expect(c.session.colorOverrides, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    c.cancelAllTimers();
  });
  testWidgets(
    'search filters modes, applies both pair members and preserves writing fonts',
    (tester) async {
      final c = await controller();
      c.updateSession((s) {
        s.documentFontFamily = 'Georgia';
        s.cornerStyle = 'subtle';
      });
      await selector(tester, c);
      expect(
        find
            .byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key as ValueKey<String>).value.startsWith('theme-preset-'),
            )
            .evaluate()
            .length,
        6,
      );
      await tester.enterText(
        find.byKey(const ValueKey('theme-palette-search')),
        'sage',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('theme-preset-palette-sage-light')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('theme-preset-palette-sage-dark')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('theme-mode-light')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('theme-preset-palette-sage-dark')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('theme-preset-palette-sage-light')),
      );
      await tester.pumpAndSettle();
      expect(c.session.themePreset, 'palette-sage-light');
      expect(c.session.accentColor, 'theme');
      expect(c.session.documentFontFamily, 'Georgia');
      await tester.ensureVisible(
        find.byKey(const ValueKey('theme-switch-pair')),
      );
      await tester.tap(find.byKey(const ValueKey('theme-switch-pair')));
      await tester.pumpAndSettle();
      expect(c.session.themePreset, 'palette-sage-dark');
      expect(
        find.byKey(const ValueKey('theme-preset-palette-sage-dark')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      c.cancelAllTimers();
    },
  );
  testWidgets(
    'pagination stays bounded and an empty search offers a way back',
    (tester) async {
      final c = await controller();
      await selector(tester, c);
      await tester.tap(find.byKey(const ValueKey('theme-page-next')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Page 2 of 19'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('theme-palette-search')),
        'no such palette',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No palettes match'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('theme-show-active')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('theme-preset-orbit')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      c.cancelAllTimers();
    },
  );
  testWidgets(
    'manual color overrides can be reset and undone without losing unknown roles',
    (tester) async {
      final c = await controller();
      c.updateSession(
        (s) =>
            s.colorOverrides = {'text': 0xffaabbcc, 'futureRole': 0xff123456},
      );
      await selector(tester, c);
      await tester.tap(find.byKey(const ValueKey('theme-use-palette-colors')));
      await tester.pumpAndSettle();
      expect(c.session.colorOverrides, {'futureRole': 0xff123456});
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(c.session.colorOverrides, {
        'text': 0xffaabbcc,
        'futureRole': 0xff123456,
      });
      await tester.pumpWidget(const SizedBox.shrink());
      c.cancelAllTimers();
    },
  );
  testWidgets(
    'collection filtering and show active reset the visible dropdown together',
    (tester) async {
      final c = await controller();
      await selector(tester, c);
      await tester.tap(find.byKey(const ValueKey('theme-family-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forest').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('12 palettes'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('theme-mode-light')));
      await tester.pumpAndSettle();
      expect(find.textContaining('6 palettes'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('theme-show-active')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.byKey(const ValueKey('theme-family-filter')),
            )
            .value,
        'All families',
      );
      expect(find.byKey(const ValueKey('theme-preset-orbit')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      c.cancelAllTimers();
    },
  );
  testWidgets('palette gallery fits a narrow screen at 200 percent text', (
    tester,
  ) async {
    final c = await controller();
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await selector(tester, c, scale: 2);
    await tester.enterText(
      find.byKey(const ValueKey('theme-palette-search')),
      'porcelain',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(
      find.byKey(const ValueKey('theme-preset-palette-porcelain-dark')),
    );
    await tester.tap(
      find.byKey(const ValueKey('theme-preset-palette-porcelain-dark')),
    );
    await tester.pumpAndSettle();
    expect(c.session.themePreset, 'palette-porcelain-dark');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    c.cancelAllTimers();
  });
}
