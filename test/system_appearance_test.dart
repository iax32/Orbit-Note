import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/app_preferences.dart';
import 'package:orbit_note/app/orbit_app.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/features/workspace/system_appearance_setting.dart';
import 'package:orbit_note/features/workspace/theme_color_settings.dart';
import 'package:orbit_note/features/workspace/theme_interchange_dialog.dart';
import 'package:orbit_note/features/workspace/harmonized_palette_dialog.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  Future<
    ({WorkspaceController c, ProviderContainer container, MemoryStore store})
  >
  setup() async {
    final store = MemoryStore();
    final container = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(
          WorkspaceRepository(store: store, index: MemoryObjectIndex()),
        ),
      ],
    );
    final c = container.read(workspaceProvider.notifier);
    await c.initialize();
    c.updateSession((s) {
      s.motion = 'off';
      s.spellCheckEnabled = false;
      s.themePreset = 'palette-sage-dark';
      s.accentColor = 'theme';
    });
    addTearDown(() {
      c.cancelAllTimers();
      container.dispose();
    });
    return (c: c, container: container, store: store);
  }

  Future<void> finish(WidgetTester t, WorkspaceController c) async {
    await t.pumpWidget(const SizedBox.shrink());
    c.cancelAllTimers();
  }

  Future<void> shell(
    WidgetTester t,
    ProviderContainer container,
    Widget child, {
    double scale = 1,
  }) async {
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            ref.watch(workspaceProvider);
            final c = ref.read(workspaceProvider.notifier);
            return MaterialApp(
              theme: orbitThemeForPreferences(
                c.session.preferences,
                MediaQuery.platformBrightnessOf(context),
              ),
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(body: SingleChildScrollView(child: child)),
                ),
              ),
            );
          },
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  void brightness(WidgetTester t, Brightness value) {
    t.binding.platformDispatcher.platformBrightnessTestValue = value;
  }

  test(
    'system appearance is explicit, restartable and compatible with old/future session fields',
    () {
      for (final value in [null, false, 'true', 1, {}, []]) {
        expect(
          SessionState.fromJson({
            'followSystemAppearance': value,
          }).followSystemAppearance,
          false,
        );
      }
      final s = SessionState.fromJson({
        'themePreset': 'palette-sage-dark',
        'followSystemAppearance': true,
        'futureAppearance': {'version': 7},
        'colorOverrides': {'futureRole': 0xff234567},
      });
      final restarted = SessionState.fromJson(
        jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
      );
      expect(restarted.followSystemAppearance, true);
      expect(restarted.themePreset, s.themePreset);
      expect(restarted.extra['futureAppearance'], {'version': 7});
      expect(restarted.colorOverrides['futureRole'], 0xff234567);
      expect(restarted.extra.containsKey('followSystemAppearance'), false);
      expect(SessionState.fromJson({}).followSystemAppearance, false);
    },
  );

  test(
    'every paired palette follows both OS modes without changing saved identity or styling',
    () {
      for (final pack in OrbitThemePack.builtIn.where(
        (p) => p.companion != null,
      )) {
        final s = SessionState(
          themePreset: pack.id,
          followSystemAppearance: true,
          accentColor: 'theme',
          documentFontFamily: 'Georgia',
          cornerStyle: 'subtle',
        );
        final before = jsonEncode(s.toJson());
        for (final os in Brightness.values) {
          final theme = orbitThemeForPreferences(s.preferences, os);
          final effective = OrbitThemePack.forPreferences(s.preferences, os);
          expect(theme.brightness, os, reason: pack.id);
          expect(effective.familyId, pack.familyId);
          expect(theme.colorScheme.primary, effective.colors.accent);
          expect(theme.extension<OrbitColors>()!.roles, effective.colors.roles);
          expect(jsonEncode(s.toJson()), before);
        }
        s.followSystemAppearance = false;
        expect(
          OrbitThemePack.forPreferences(
            s.preferences,
            pack.companion!.brightness,
          ).id,
          pack.id,
        );
      }
    },
  );

  test(
    'unpaired, unknown and custom palettes retain their look; user accents and overrides survive mode changes',
    () {
      final custom = OrbitThemePack.fromSeed(
        const Color(0xff598d84),
        id: 'my-palette',
      ).toJson();
      for (final id in ['orbit', 'paper', 'future-palette', 'my-palette']) {
        final p = AppPreferences(
          themePreset: id,
          customThemes: [custom],
          followSystemAppearance: true,
        );
        final saved = OrbitThemePack.fromId(id, customPacks: [custom]);
        for (final os in Brightness.values) {
          expect(OrbitThemePack.forPreferences(p, os).toJson(), saved.toJson());
        }
        expect(p.themePreset, id);
      }
      final p = AppPreferences(
        themePreset: 'palette-sage-dark',
        followSystemAppearance: true,
        accentColor: 'rose',
        documentFontFamily: 'Georgia',
        colorOverrides: {'link': 0xffabcded, 'futureRole': 0xff112233},
      );
      for (final os in Brightness.values) {
        final theme = orbitThemeForPreferences(p, os);
        expect(theme.brightness, os);
        expect(
          OrbitContrast.ratio(
            theme.colorScheme.primary,
            theme.extension<OrbitColors>()!.pressed,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(p.accentColor, 'rose');
        expect(theme.extension<OrbitColors>()!.link, const Color(0xffabcded));
        expect(p.documentFontFamily, 'Georgia');
        expect(p.colorOverrides['futureRole'], 0xff112233);
      }
    },
  );

  testWidgets(
    'actual app reacts to OS changes without disturbing selected text, note identity or durable bytes',
    (t) async {
      final h = await setup(), c = h.c;
      t.view.physicalSize = const Size(1400, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(
        t.binding.platformDispatcher.clearPlatformBrightnessTestValue,
      );
      brightness(t, Brightness.light);
      c.updateSession((s) {
        s.followSystemAppearance = true;
        s.defaultNoteMode = 'write';
        s.sidebarVisible = false;
        s.inspectorVisible = false;
        s.autoSnapshotOnClose = false;
      });
      final note = (await c.create(
        'orbit.note',
        title: 'Keep writing',
        body: 'A selected passage stays here.',
      ))!;
      c.openObject(note.id);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: const OrbitNoteApp(),
        ),
      );
      await t.pumpAndSettle();
      final field = find.byKey(const ValueKey('note-body'));
      await t.tap(field);
      final input = t.widget<TextField>(field);
      const selection = TextSelection(baseOffset: 2, extentOffset: 18);
      input.controller!.selection = selection;
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 2));
      c.cancelAllTimers();
      final before = jsonEncode(c.session.toJson());
      final bytes = {
        for (final e in h.store.files.entries) e.key: e.value.toList(),
      };
      ThemeData theme() =>
          t.widget<MaterialApp>(find.byType(MaterialApp)).theme!;
      expect(theme().brightness, Brightness.light);
      for (final os in [Brightness.dark, Brightness.light, Brightness.dark]) {
        brightness(t, os);
        await t.pumpAndSettle();
        expect(theme().brightness, os);
        expect(
          t
              .widget<MaterialApp>(find.byType(MaterialApp))
              .themeAnimationDuration,
          Duration.zero,
        );
        final after = t.widget<TextField>(field);
        expect(after.controller, same(input.controller));
        expect(after.focusNode!.hasFocus, true);
        expect(after.controller!.selection, selection);
        expect(after.controller!.text, note.body);
        expect(c.session.activeId, note.id);
        expect(jsonEncode(c.session.toJson()), before);
        expect({
          for (final e in h.store.files.entries) e.key: e.value.toList(),
        }, bytes);
      }
      expect(t.takeException(), isNull);
      await finish(t, c);
    },
  );

  testWidgets(
    'turning following off freezes the visible mode and allows recovery for unsupported themes',
    (t) async {
      final h = await setup(), c = h.c;
      addTearDown(
        t.binding.platformDispatcher.clearPlatformBrightnessTestValue,
      );
      brightness(t, Brightness.light);
      await shell(t, h.container, SystemAppearanceSetting(controller: c));
      final toggle = find.byKey(
        const ValueKey('settings-follow-system-appearance'),
      );
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(c.session.followSystemAppearance, true);
      expect(c.session.themePreset, 'palette-sage-dark');
      expect(find.textContaining('Now: Sage Garden Light'), findsOneWidget);
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(c.session.followSystemAppearance, false);
      expect(c.session.themePreset, 'palette-sage-light');
      brightness(t, Brightness.dark);
      await t.pumpAndSettle();
      expect(
        t.widget<MaterialApp>(find.byType(MaterialApp)).theme!.brightness,
        Brightness.light,
      );
      c.updateSession((s) {
        s.themePreset = 'future-palette';
        s.followSystemAppearance = true;
      });
      await shell(t, h.container, SystemAppearanceSetting(controller: c));
      expect(t.widget<SwitchListTile>(toggle).onChanged, isNotNull);
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(c.session.themePreset, 'future-palette');
      expect(c.session.followSystemAppearance, false);
      expect(t.widget<SwitchListTile>(toggle).onChanged, isNull);
      expect(t.takeException(), isNull);
      await finish(t, c);
    },
  );

  testWidgets(
    'manual palette selection exits system mode and browser tracks the OS-selected member',
    (t) async {
      final h = await setup(), c = h.c;
      addTearDown(
        t.binding.platformDispatcher.clearPlatformBrightnessTestValue,
      );
      brightness(t, Brightness.light);
      c.updateSession((s) => s.followSystemAppearance = true);
      await shell(t, h.container, ThemePresetSelector(controller: c));
      expect(find.text('Active: Sage Garden Light'), findsOneWidget);
      brightness(t, Brightness.dark);
      await t.pumpAndSettle();
      expect(find.text('Active: Sage Garden Dark'), findsOneWidget);
      await t.enterText(
        find.byKey(const ValueKey('theme-palette-search')),
        'Sage Garden Light',
      );
      await t.pumpAndSettle();
      final light = find.byKey(
        const ValueKey('theme-preset-palette-sage-light'),
      );
      await t.ensureVisible(light);
      await t.tap(light);
      await t.pumpAndSettle();
      expect(c.session.themePreset, 'palette-sage-light');
      expect(c.session.followSystemAppearance, false);
      expect(
        t.widget<MaterialApp>(find.byType(MaterialApp)).theme!.brightness,
        Brightness.light,
      );
      await finish(t, c);
    },
  );

  testWidgets(
    'open gallery tracks system changes and its toggle refreshes the active palette',
    (t) async {
      final h = await setup(), c = h.c;
      addTearDown(
        t.binding.platformDispatcher.clearPlatformBrightnessTestValue,
      );
      brightness(t, Brightness.light);
      await shell(
        t,
        h.container,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showOrbitThemeGalleryDialog(context, c),
            child: const Text('Browse themes'),
          ),
        ),
      );
      await t.tap(find.text('Browse themes'));
      await t.pumpAndSettle();
      final toggle = find.byKey(
        const ValueKey('settings-follow-system-appearance'),
      );
      await t.ensureVisible(toggle);
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(c.session.followSystemAppearance, true);
      expect(find.text('Active: Sage Garden Light'), findsOneWidget);
      brightness(t, Brightness.dark);
      await t.pumpAndSettle();
      expect(find.text('Active: Sage Garden Dark'), findsOneWidget);
      await t.ensureVisible(toggle);
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(c.session.followSystemAppearance, false);
      brightness(t, Brightness.light);
      await t.pumpAndSettle();
      expect(find.text('Active: Sage Garden Dark'), findsOneWidget);
      expect(t.takeException(), isNull);
      await finish(t, c);
    },
  );

  testWidgets(
    'theme export and preview match visible system mode and explicit accents',
    (t) async {
      final h = await setup(), c = h.c;
      addTearDown(
        t.binding.platformDispatcher.clearPlatformBrightnessTestValue,
      );
      brightness(t, Brightness.light);
      c.updateSession((s) {
        s.followSystemAppearance = true;
        s.accentColor = 'rose';
        s.documentFontFamily = 'Georgia';
      });
      String? exported;
      await shell(
        t,
        h.container,
        Column(
          children: [
            LiveThemePreviewCard(controller: c),
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showOrbitThemeExportDialog(
                  context,
                  c,
                  exportFn: (_, content) async {
                    exported = content;
                    return true;
                  },
                ),
                child: const Text('Export current'),
              ),
            ),
          ],
        ),
      );
      final preview = t.element(
        find.byKey(const ValueKey('theme-live-preview')),
      );
      expect(Theme.of(preview).brightness, Brightness.light);
      expect(
        OrbitColors.of(preview).accent,
        Theme.of(preview).colorScheme.primary,
      );
      await t.tap(find.text('Export current'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('theme-export-name-input')),
        'My current look',
      );
      brightness(t, Brightness.dark);
      await t.pumpAndSettle();
      expect(
        t
            .widget<TextField>(
              find.byKey(const ValueKey('theme-export-name-input')),
            )
            .controller!
            .text,
        'My current look',
      );
      await t.tap(find.byKey(const ValueKey('theme-export-confirm-button')));
      await t.pumpAndSettle();
      final pack = OrbitThemePack.fromJson(
        jsonDecode(exported!) as Map<String, dynamic>,
      );
      expect(pack.brightness, Brightness.dark);
      expect(
        pack.colors.workspace,
        OrbitThemePack.fromId('palette-sage-dark').colors.workspace,
      );
      expect(
        pack.colors.accent,
        t
            .widget<MaterialApp>(find.byType(MaterialApp))
            .theme!
            .colorScheme
            .primary,
      );
      expect(pack.documentFontFamily, 'Georgia');
      expect(c.session.followSystemAppearance, true);
      await finish(t, c);
    },
  );

  testWidgets(
    'imported and generated palettes explicitly return to manual appearance',
    (t) async {
      final h = await setup(), c = h.c;
      c.updateSession((s) => s.followSystemAppearance = true);
      await shell(
        t,
        h.container,
        Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                onPressed: () => showOrbitThemeImportDialog(
                  context,
                  c,
                  directJsonContent: jsonEncode(OrbitThemePack.paper.toJson()),
                ),
                child: const Text('Import'),
              ),
              TextButton(
                onPressed: () => showHarmonizedPaletteDialog(context, c),
                child: const Text('Generate'),
              ),
            ],
          ),
        ),
      );
      await t.tap(find.text('Import'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('theme-import-apply-button')));
      await t.pumpAndSettle();
      expect(c.session.followSystemAppearance, false);
      expect(c.session.themePreset, 'paper');
      c.updateSession((s) {
        s.themePreset = 'palette-sage-dark';
        s.followSystemAppearance = true;
      });
      await t.pumpAndSettle();
      await t.tap(find.text('Generate'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('theme-seed-apply-button')));
      await t.pumpAndSettle();
      expect(c.session.followSystemAppearance, false);
      expect(c.session.themePreset, startsWith('harmonized-'));
      await finish(t, c);
    },
  );

  test(
    'Spaces persist system appearance and old fixed descriptors do not inherit it',
    () async {
      final h = await setup(), c = h.c;
      c.updateSession((s) => s.followSystemAppearance = true);
      expect(await c.saveContext(name: 'System pair', appearance: true), true);
      final paired = c.savedContexts.single['id'] as String;
      c.updateSession((s) {
        s.themePreset = 'paper';
        s.followSystemAppearance = false;
      });
      expect(await c.saveContext(name: 'Fixed paper', appearance: true), true);
      final fixed = c.savedContexts.last['id'] as String;
      // Simulate a Space saved by a version before this preference existed.
      c.updateSession(
        (s) => s.spaces = {
          ...s.spaces,
          'items': [
            for (final r in c.savedContexts)
              if (r['id'] == fixed)
                {
                  ...r,
                  'appearance': {...r['appearance'] as Map}
                    ..remove('followSystemAppearance'),
                }
              else
                r,
          ],
        },
      );
      expect(await c.switchContext(paired), true);
      expect(c.session.followSystemAppearance, true);
      expect(c.session.themePreset, 'palette-sage-dark');
      expect(await c.switchContext(fixed), true);
      expect(c.session.followSystemAppearance, false);
      expect(c.session.themePreset, 'paper');
      final restored = SessionState.fromJson(
        jsonDecode(jsonEncode(c.session.toJson())) as Map<String, dynamic>,
      );
      expect(
        (restored.spaces['items'] as List)
            .first['appearance']['followSystemAppearance'],
        true,
      );
      expect(await c.switchContext(null), true);
      expect(c.session.followSystemAppearance, false);
      expect(await c.switchContext(paired), true);
      await c.closeWorkspace();
      final reopened = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(
            WorkspaceRepository(store: h.store, index: MemoryObjectIndex()),
          ),
        ],
      );
      final next = reopened.read(workspaceProvider.notifier);
      addTearDown(() {
        next.cancelAllTimers();
        reopened.dispose();
      });
      await next.initialize();
      expect(next.session.followSystemAppearance, true);
      expect(next.session.themePreset, 'palette-sage-dark');
      expect(next.activeSpaceId, paired);
    },
  );

  testWidgets(
    'system control and live preview remain usable at narrow width with 200 percent text',
    (t) async {
      final h = await setup(), c = h.c;
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await shell(
        t,
        h.container,
        Column(
          children: [
            SystemAppearanceSetting(controller: c),
            LiveThemePreviewCard(controller: c),
          ],
        ),
        scale: 2,
      );
      await t.tap(
        find.byKey(const ValueKey('settings-follow-system-appearance')),
      );
      await t.pumpAndSettle();
      expect(c.session.followSystemAppearance, true);
      expect(t.takeException(), isNull);
      await finish(t, c);
    },
  );
}
