import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/features/workspace/harmonized_palette_dialog.dart';
import 'package:orbit_note/features/workspace/heatmap_view.dart';
import 'package:orbit_note/features/workspace/orbit_cover_banner.dart';
import 'package:orbit_note/features/workspace/theme_color_settings.dart';
import 'package:orbit_note/features/workspace/theme_interchange_dialog.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  group('Theme Engine & Semantic Tokens', () {
    test(
      'curated built-in theme families are defined with distinct palettes',
      () {
        expect(OrbitThemePack.builtIn.length, greaterThanOrEqualTo(13));
        final ids = OrbitThemePack.builtIn.map((p) => p.id).toSet();
        expect(
          ids,
          containsAll([
            'orbit',
            'observatory',
            'paper',
            'midnight',
            'aurora',
            'obsidian-ember',
            'nord-mist',
            'dracula-velvet',
            'catppuccin-mocha',
            'rose-pine',
            'solarized-paper',
            'gruvbox-night',
            'coastal-light',
          ]),
        );

        final orbit = OrbitThemePack.fromId('orbit');
        expect(orbit.brightness, Brightness.dark);
        expect(orbit.colors.accent, const Color(0xFFB0A0FF));

        final paper = OrbitThemePack.fromId('paper');
        expect(paper.brightness, Brightness.light);
        expect(paper.colors.background, const Color(0xFFF7F5EE));
        expect(paper.colors.text, const Color(0xFF24211E));

        final midnight = OrbitThemePack.fromId('midnight');
        expect(midnight.brightness, Brightness.dark);
        expect(midnight.colors.background, const Color(0xFF000000));

        final observatory = OrbitThemePack.fromId('observatory');
        expect(observatory.colors.accent, const Color(0xFF06B6D4));

        final aurora = OrbitThemePack.fromId('aurora');
        expect(aurora.colors.accent.g, greaterThan(aurora.colors.accent.r));
        expect(
          OrbitContrast.ratio(aurora.colors.accent, aurora.colors.pressed),
          greaterThanOrEqualTo(4.5),
        );

        final obsidian = OrbitThemePack.fromId('obsidian-ember');
        expect(obsidian.brightness, Brightness.dark);
        expect(obsidian.documentFontFamily, 'Georgia');

        final solarized = OrbitThemePack.fromId('solarized-paper');
        expect(solarized.brightness, Brightness.light);
        expect(solarized.cornerStyle, 'subtle');
      },
    );

    test('theme pack JSON serialization round-trips safely', () {
      final paper = OrbitThemePack.paper;
      final json = paper.toJson();
      expect(json['id'], 'paper');
      expect(json['brightness'], 'light');
      expect(json['colors'], isA<Map>());

      final restored = OrbitThemePack.fromJson(json);
      expect(restored.id, 'paper');
      expect(restored.brightness, Brightness.light);
      expect(restored.colors.background, paper.colors.background);
      expect(restored.colors.text, paper.colors.text);
    });

    test(
      'corrupted or partial JSON gracefully falls back to default values',
      () {
        final corrupted = OrbitThemePack.fromJson({
          'id': 'custom-theme',
          'brightness': 'invalid',
          'colors': {'background': 'not-a-color', 'accent': '#123456'},
        });

        expect(corrupted.id, 'custom-theme');
        expect(corrupted.brightness, Brightness.dark);
        // Valid accent was parsed
        expect(corrupted.colors.accent, const Color(0xFF123456));
        // Invalid background falls back to default orbit background
        expect(
          corrupted.colors.background,
          OrbitThemePack.orbit.colors.background,
        );
      },
    );

    test('semantic tokens cover full design system and aliases work', () {
      const colors = OrbitColors();
      expect(colors.textPrimary, colors.text);
      expect(colors.textSecondary, colors.subtle);
      expect(colors.textMuted, colors.muted);
      expect(colors.accentSecondary, colors.secondary);

      expect(
        colors.roles.keys,
        containsAll([
          'background',
          'workspace',
          'panel',
          'panelSecondary',
          'raised',
          'floating',
          'input',
          'hover',
          'pressed',
          'selected',
          'selectedMuted',
          'border',
          'divider',
          'focus',
          'accent',
          'secondary',
          'accentHover',
          'text',
          'subtle',
          'muted',
          'textDisabled',
          'success',
          'warning',
          'danger',
          'link',
          'linkVisited',
          'canvasBackground',
          'canvasGrid',
          'graphEdge',
        ]),
      );
    });

    test('corner styles map correctly between rounded and subtle', () {
      expect(OrbitCorners.rounded.style, 'rounded');
      expect(OrbitCorners.rounded.control, 8.0);
      expect(OrbitCorners.rounded.card, 12.0);

      expect(OrbitCorners.subtle.style, 'subtle');
      expect(OrbitCorners.subtle.control, 4.0);
      expect(OrbitCorners.subtle.card, 6.0);

      expect(OrbitCorners.fromStyle('subtle'), OrbitCorners.subtle);
      expect(OrbitCorners.fromStyle('rounded'), OrbitCorners.rounded);
      expect(OrbitCorners.fromStyle(null), OrbitCorners.rounded);
    });

    test('orbitTheme builds correct Brightness.light for paper theme', () {
      final lightTheme = orbitTheme(preset: 'paper');
      expect(lightTheme.brightness, Brightness.light);
      expect(lightTheme.colorScheme.brightness, Brightness.light);
      expect(lightTheme.scaffoldBackgroundColor, const Color(0xFFF7F5EE));

      final darkTheme = orbitTheme(preset: 'orbit');
      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.colorScheme.brightness, Brightness.dark);
      expect(darkTheme.scaffoldBackgroundColor, const Color(0xFF141418));
    });

    test('SessionState preserves themePreset and cornerStyle', () {
      final session = SessionState(
        themePreset: 'aurora',
        cornerStyle: 'subtle',
        documentFontFamily: 'Georgia',
        monoFontFamily: 'Fira Code',
      );

      final json = session.toJson();
      expect(json['themePreset'], 'aurora');
      expect(json['cornerStyle'], 'subtle');
      expect(json['documentFontFamily'], 'Georgia');
      expect(json['monoFontFamily'], 'Fira Code');

      final restored = SessionState.fromJson(json);
      expect(restored.themePreset, 'aurora');
      expect(restored.cornerStyle, 'subtle');
      expect(restored.documentFontFamily, 'Georgia');
      expect(restored.monoFontFamily, 'Fira Code');
    });
  });

  group('Appearance Widgets & Live Preview', () {
    testWidgets(
      'LiveThemePreviewCard renders title, link, button, and corner indicators',
      (tester) async {
        final repo = WorkspaceRepository(
          store: MemoryStore(),
          index: MemoryObjectIndex(),
        );
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);
        final controller = container.read(workspaceProvider.notifier);
        await controller.initialize();
        controller.updateSession((s) {
          s.motion = 'off';
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitTheme(),
            home: Scaffold(body: LiveThemePreviewCard(controller: controller)),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('theme-live-preview')),
          findsOneWidget,
        );
        expect(find.text('Aa Heading'), findsOneWidget);
        expect(find.text('Primary Action'), findsOneWidget);
        expect(find.text('Secondary Tag'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 700));
      },
    );

    testWidgets('ThemePresetSelector allows selecting different theme packs', (
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
      final controller = container.read(workspaceProvider.notifier);
      await controller.initialize();
      controller.updateSession((s) {
        s.motion = 'off';
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitTheme(),
          home: Scaffold(body: ThemePresetSelector(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('theme-preset-orbit')), findsOneWidget);
      expect(find.byKey(const ValueKey('theme-preset-paper')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('theme-preset-midnight')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('theme-preset-observatory')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('theme-preset-aurora')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('theme-preset-paper')));
      await tester.pumpAndSettle();

      expect(controller.session.themePreset, 'paper');
      expect(controller.session.documentFontFamily, 'Georgia');
      await tester.pump(const Duration(milliseconds: 700));
    });

    testWidgets('CornerStyleSelector updates session corner style', (
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
      final controller = container.read(workspaceProvider.notifier);
      await controller.initialize();
      controller.updateSession((s) {
        s.motion = 'off';
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitTheme(),
          home: Scaffold(body: CornerStyleSelector(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      final subtleBtn = find.text('Subtle (4px)');
      await tester.tap(subtleBtn);
      await tester.pumpAndSettle();

      expect(controller.session.cornerStyle, 'subtle');
      await tester.pump(const Duration(milliseconds: 700));
    });
  });

  group('Generic Heatmap View & Cover Banners', () {
    testWidgets('HeatmapWidget renders months, legend, and day cells', (
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
      final controller = container.read(workspaceProvider.notifier);
      await controller.initialize();
      controller.updateSession((s) {
        s.motion = 'off';
      });

      // Seed a note
      await controller.create(
        'orbit.note',
        title: '2026-10-04 Research Log',
        properties: {'daily': true},
      );

      DateTime? selectedDate;
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitTheme(),
          home: Scaffold(
            body: HeatmapWidget(
              controller: controller,
              year: 2026,
              onSelectDate: (d) => selectedDate = d,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2026 Heatmap'), findsOneWidget);
      expect(find.text('Jan'), findsOneWidget);
      expect(find.text('Oct'), findsOneWidget);
      expect(find.text('Dec'), findsOneWidget);
      expect(find.text('Less'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);

      final cell = find.byKey(const ValueKey('heatmap-cell-2026-10-04'));
      expect(cell, findsOneWidget);

      await tester.ensureVisible(cell);
      await tester.pumpAndSettle();
      await tester.tap(cell);
      await tester.pumpAndSettle();
      expect(selectedDate, DateTime(2026, 10, 4));
      await tester.pump(const Duration(milliseconds: 700));
    });

    testWidgets('OrbitCoverBanner renders gradient presets and overlays', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrbitCoverBanner(
              cover: 'gradient:ocean',
              heightPreset: 'standard',
              editable: true,
              onChangeCover: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OrbitCoverBanner), findsOneWidget);
      expect(find.text('Change cover'), findsOneWidget);
    });
  });

  group('Theme Interchange & File Dialogs', () {
    testWidgets(
      'showOrbitThemeExportDialog configures name and writes .orbit-theme.json',
      (tester) async {
        final repo = WorkspaceRepository(
          store: MemoryStore(),
          index: MemoryObjectIndex(),
        );
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);
        final controller = container.read(workspaceProvider.notifier);
        await controller.initialize();
        controller.updateSession((s) {
          s.motion = 'off';
          s.themePreset = 'aurora';
          s.cornerStyle = 'subtle';
          s.colorOverrides = {'accent': 0xFF00FF00};
        });

        String? exportedFileName;
        String? exportedContent;

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitTheme(),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showOrbitThemeExportDialog(
                    context,
                    controller,
                    exportFn: (name, content) async {
                      exportedFileName = name;
                      exportedContent = content;
                      return true;
                    },
                  ),
                  child: const Text('Open Export'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Export'));
        await tester.pumpAndSettle();

        expect(find.text('Export Theme'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('theme-export-name-input')),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const ValueKey('theme-export-name-input')),
          'Emerald Forest Pro',
        );
        await tester.enterText(
          find.byKey(const ValueKey('theme-export-desc-input')),
          'A custom emerald theme for research.',
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('theme-export-confirm-button')),
        );
        await tester.pumpAndSettle();

        expect(exportedFileName, 'emerald_forest_pro.orbit-theme.json');
        expect(exportedContent, isNotNull);

        final decoded = jsonDecode(exportedContent!) as Map<String, dynamic>;
        expect(decoded['name'], 'Emerald Forest Pro');
        expect(decoded['description'], 'A custom emerald theme for research.');
        expect(decoded['cornerStyle'], 'subtle');
        expect(decoded['colors']['accent'], '#ff00ff00');

        await tester.pump(const Duration(milliseconds: 700));
      },
    );

    testWidgets(
      'showOrbitThemeImportDialog parses valid JSON and applies to session on confirmation',
      (tester) async {
        final repo = WorkspaceRepository(
          store: MemoryStore(),
          index: MemoryObjectIndex(),
        );
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);
        final controller = container.read(workspaceProvider.notifier);
        await controller.initialize();
        controller.updateSession((s) {
          s.motion = 'off';
          s.themePreset = 'orbit';
          s.cornerStyle = 'rounded';
        });

        final themeJson = jsonEncode({
          'id': 'custom-cyberpunk',
          'name': 'Cyberpunk Neon',
          'description': 'High-contrast neon theme.',
          'brightness': 'dark',
          'cornerStyle': 'subtle',
          'documentFontFamily': 'Georgia',
          'monoFontFamily': 'Fira Code',
          'colors': {
            'background': '#ff05050a',
            'panel': '#ff0d0d16',
            'accent': '#ffff0055',
            'text': '#ffeef5ff',
          },
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitTheme(),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showOrbitThemeImportDialog(
                    context,
                    controller,
                    directJsonContent: themeJson,
                  ),
                  child: const Text('Open Import'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Import'));
        await tester.pumpAndSettle();

        expect(find.text('Import: Cyberpunk Neon'), findsOneWidget);
        expect(find.text('High-contrast neon theme.'), findsOneWidget);
        expect(find.text('Subtle (4px)'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('theme-import-apply-button')),
        );
        await tester.pumpAndSettle();

        expect(controller.session.themePreset, 'custom-cyberpunk');
        expect(controller.session.cornerStyle, 'subtle');
        expect(controller.session.documentFontFamily, 'Georgia');
        expect(controller.session.monoFontFamily, 'Fira Code');
        expect(
          controller.session.colorOverrides['accent'],
          const Color(0xffff0055).toARGB32(),
        );

        await tester.pump(const Duration(milliseconds: 700));
      },
    );

    testWidgets('showOrbitThemeImportDialog handles invalid JSON gracefully', (
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
      final controller = container.read(workspaceProvider.notifier);
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showOrbitThemeImportDialog(
                  context,
                  controller,
                  directJsonContent: 'not valid json {{{',
                ),
                child: const Text('Open Bad Import'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Bad Import'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not parse theme: invalid JSON file.'),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 700));
    });
  });

  group('Theme Gallery & Custom Themes Management', () {
    test(
      'SessionState preserves customThemes list and fromId resolves them',
      () {
        final customPackJson = {
          'id': 'custom-cyber',
          'name': 'Cyberpunk',
          'description': 'Neon theme',
          'brightness': 'dark',
          'colors': {'accent': '#ffff0055'},
        };
        final session = SessionState(customThemes: [customPackJson]);
        expect(session.customThemes.length, 1);
        expect(session.customThemes.first['name'], 'Cyberpunk');

        final serialized = session.toJson();
        expect(serialized['customThemes'], isA<List>());
        expect((serialized['customThemes'] as List).length, 1);

        final restored = SessionState.fromJson(serialized);
        expect(restored.customThemes.length, 1);
        expect(restored.customThemes.first['id'], 'custom-cyber');

        final resolved = OrbitThemePack.fromId(
          'custom-cyber',
          customPacks: session.customThemes,
        );
        expect(resolved.id, 'custom-cyber');
        expect(resolved.name, 'Cyberpunk');
        expect(resolved.colors.accent, const Color(0xffff0055));
      },
    );

    testWidgets(
      'showOrbitThemeImportDialog persists imported custom theme to customThemes',
      (tester) async {
        final repo = WorkspaceRepository(
          store: MemoryStore(),
          index: MemoryObjectIndex(),
        );
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);
        final controller = container.read(workspaceProvider.notifier);
        await controller.initialize();
        controller.updateSession((s) {
          s.motion = 'off';
        });

        final themeJson = jsonEncode({
          'id': 'custom-matrix',
          'name': 'Matrix Green',
          'description': 'Monochrome green terminal',
          'brightness': 'dark',
          'colors': {'accent': '#ff00ff66'},
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitTheme(),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showOrbitThemeImportDialog(
                    context,
                    controller,
                    directJsonContent: themeJson,
                  ),
                  child: const Text('Import'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Import'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('theme-import-apply-button')),
        );
        await tester.pumpAndSettle();

        expect(controller.session.themePreset, 'custom-matrix');
        expect(
          controller.session.customThemes.any(
            (m) => m['id'] == 'custom-matrix',
          ),
          isTrue,
        );
        await tester.pump(const Duration(milliseconds: 700));
      },
    );

    testWidgets(
      'showOrbitThemeGalleryDialog lists themes and allows applying a different theme',
      (tester) async {
        final repo = WorkspaceRepository(
          store: MemoryStore(),
          index: MemoryObjectIndex(),
        );
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);
        final controller = container.read(workspaceProvider.notifier);
        await controller.initialize();
        controller.updateSession((s) {
          s.motion = 'off';
          s.themePreset = 'orbit';
          s.customThemes = [
            {
              'id': 'custom-sepia',
              'name': 'Warm Sepia',
              'description': 'A gentle parchment theme',
              'brightness': 'light',
              'colors': {'accent': '#ffb08850'},
            },
          ];
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitTheme(),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      showOrbitThemeGalleryDialog(context, controller),
                  child: const Text('Open Gallery'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Gallery'));
        await tester.pumpAndSettle();

        expect(find.text('Theme Gallery'), findsOneWidget);
        expect(find.text('Orbit Graphite'), findsOneWidget);
        expect(find.text('Paper Warm Light'), findsOneWidget);
        expect(find.text('Warm Sepia'), findsOneWidget);
        expect(find.text('CUSTOM'), findsOneWidget);

        // Apply paper theme
        final applyPaper = find.byKey(
          const ValueKey('theme-gallery-apply-paper'),
        );
        expect(applyPaper, findsOneWidget);
        await tester.ensureVisible(applyPaper);
        await tester.pumpAndSettle();
        await tester.tap(applyPaper);
        await tester.pumpAndSettle();

        expect(controller.session.themePreset, 'paper');
        await tester.pump(const Duration(milliseconds: 700));
      },
    );

    testWidgets('showOrbitThemeGalleryDialog allows renaming a custom theme', (
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
      final controller = container.read(workspaceProvider.notifier);
      await controller.initialize();
      controller.updateSession((s) {
        s.motion = 'off';
        s.customThemes = [
          {
            'id': 'custom-neon',
            'name': 'Neon Original',
            'brightness': 'dark',
            'colors': {'accent': '#ffff00aa'},
          },
        ];
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    showOrbitThemeGalleryDialog(context, controller),
                child: const Text('Open Gallery'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Gallery'));
      await tester.pumpAndSettle();

      final renameBtn = find.byKey(
        const ValueKey('theme-gallery-rename-custom-neon'),
      );
      expect(renameBtn, findsOneWidget);
      await tester.ensureVisible(renameBtn);
      await tester.pumpAndSettle();
      await tester.tap(renameBtn);
      await tester.pumpAndSettle();

      expect(find.text('Rename Theme'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('theme-rename-input')),
        'Neon Ultra',
      );
      await tester.tap(
        find.byKey(const ValueKey('theme-rename-confirm-button')),
      );
      await tester.pumpAndSettle();

      expect(controller.session.customThemes.first['name'], 'Neon Ultra');
      expect(find.text('Neon Ultra'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));
    });

    testWidgets(
      'showOrbitThemeGalleryDialog deletes custom theme and falls back to orbit if active',
      (tester) async {
        final repo = WorkspaceRepository(
          store: MemoryStore(),
          index: MemoryObjectIndex(),
        );
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);
        final controller = container.read(workspaceProvider.notifier);
        await controller.initialize();
        controller.updateSession((s) {
          s.motion = 'off';
          s.themePreset = 'custom-delete-me';
          s.colorOverrides = {'accent': 0xFF123456};
          s.customThemes = [
            {
              'id': 'custom-delete-me',
              'name': 'Delete Me',
              'brightness': 'dark',
              'colors': {'accent': '#ff123456'},
            },
          ];
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitTheme(),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      showOrbitThemeGalleryDialog(context, controller),
                  child: const Text('Open Gallery'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Gallery'));
        await tester.pumpAndSettle();

        final deleteBtn = find.byKey(
          const ValueKey('theme-gallery-delete-custom-delete-me'),
        );
        expect(deleteBtn, findsOneWidget);
        await tester.ensureVisible(deleteBtn);
        await tester.pumpAndSettle();
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        expect(find.text('Delete Theme'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('theme-delete-confirm-button')),
        );
        await tester.pumpAndSettle();

        expect(controller.session.customThemes, isEmpty);
        expect(controller.session.themePreset, 'orbit');
        expect(controller.session.colorOverrides, isEmpty);
        await tester.pump(const Duration(milliseconds: 700));
      },
    );

    testWidgets(
      'ThemeColorSettings contains Theme Gallery button that opens the dialog',
      (tester) async {
        final repo = WorkspaceRepository(
          store: MemoryStore(),
          index: MemoryObjectIndex(),
        );
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);
        final controller = container.read(workspaceProvider.notifier);
        await controller.initialize();
        controller.updateSession((s) {
          s.motion = 'off';
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitTheme(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ThemeColorSettings(controller: controller),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Expand ThemeColorSettings ExpansionTile
        await tester.tap(find.byKey(const ValueKey('settings-custom-colors')));
        await tester.pumpAndSettle();

        final galleryBtn = find.byKey(const ValueKey('theme-gallery-button'));
        await tester.ensureVisible(galleryBtn);
        await tester.pumpAndSettle();
        expect(galleryBtn, findsOneWidget);

        await tester.tap(galleryBtn);
        await tester.pumpAndSettle();

        expect(find.text('Theme Gallery'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 700));
      },
    );
  });

  group('Harmonized Color Palette Generator & WCAG Accessibility', () {
    test(
      'OrbitContrast computes correct WCAG 2.1 relative luminance and contrast ratios',
      () {
        expect(
          OrbitContrast.ratio(Colors.black, Colors.white),
          closeTo(21.0, 0.1),
        );
        expect(OrbitContrast.ratio(Colors.white, Colors.white), 1.0);
        expect(OrbitContrast.ratio(Colors.black, Colors.black), 1.0);

        expect(OrbitContrast.isWcagAa(Colors.white, Colors.black), isTrue);
        expect(OrbitContrast.isWcagAaa(Colors.white, Colors.black), isTrue);
        expect(
          OrbitContrast.isWcagAa(const Color(0xFF222222), Colors.black),
          isFalse,
        );
      },
    );

    test(
      'OrbitColors.fromSeed generates WCAG AAA compliant dark and light palettes across hues',
      () {
        final testSeeds = [
          const Color(0xFF8B7CF6), // Violet
          const Color(0xFF06B6D4), // Cyan
          const Color(0xFF10B981), // Emerald
          const Color(0xFFF59E0B), // Amber
          const Color(0xFFF43F5E), // Rose
        ];

        for (final seed in testSeeds) {
          // Dark Mode
          final dark = OrbitColors.fromSeed(seed, brightness: Brightness.dark);
          expect(dark.accent, isNotNull);
          expect(
            OrbitContrast.ratio(dark.text, dark.background),
            greaterThanOrEqualTo(7.0),
            reason: 'Dark text contrast must meet WCAG AAA',
          );
          expect(
            OrbitContrast.ratio(dark.subtle, dark.background),
            greaterThanOrEqualTo(4.5),
            reason: 'Dark subtle contrast must meet WCAG AA',
          );
          expect(dark.workspace, isNotNull);
          expect(dark.panel, isNotNull);
          expect(dark.raised, isNotNull);
          expect(dark.border, isNotNull);

          // Light Mode
          final light = OrbitColors.fromSeed(
            seed,
            brightness: Brightness.light,
          );
          expect(light.accent, isNotNull);
          expect(
            OrbitContrast.ratio(light.text, light.background),
            greaterThanOrEqualTo(7.0),
            reason: 'Light text contrast must meet WCAG AAA',
          );
          expect(
            OrbitContrast.ratio(light.subtle, light.background),
            greaterThanOrEqualTo(4.5),
            reason: 'Light subtle contrast must meet WCAG AA',
          );
          expect(light.workspace, isNotNull);
          expect(light.panel, isNotNull);
          expect(light.raised, isNotNull);
          expect(light.border, isNotNull);
        }
      },
    );

    test(
      'OrbitThemePack.fromSeed produces valid pack that serializes and deserializes',
      () {
        final seed = const Color(0xFF10B981); // Emerald
        final pack = OrbitThemePack.fromSeed(
          seed,
          name: 'Emerald Nebula',
          brightness: Brightness.dark,
        );

        expect(pack.name, 'Emerald Nebula');
        expect(pack.brightness, Brightness.dark);
        expect(pack.colors.accent, isNotNull);

        final json = pack.toJson();
        expect(json['name'], 'Emerald Nebula');
        expect(json['brightness'], 'dark');
        expect(json['colors'], isA<Map>());

        final restored = OrbitThemePack.fromJson(json);
        expect(restored.name, 'Emerald Nebula');
        expect(restored.brightness, Brightness.dark);
        expect(restored.colors.background, pack.colors.background);
      },
    );

    testWidgets(
      'showHarmonizedPaletteDialog allows selecting presets, switching mode, and applying palette',
      (tester) async {
        final repo = WorkspaceRepository(
          store: MemoryStore(),
          index: MemoryObjectIndex(),
        );
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);
        final controller = container.read(workspaceProvider.notifier);
        await controller.initialize();
        controller.updateSession((s) {
          s.motion = 'off';
          s.themePreset = 'orbit';
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitTheme(),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      showHarmonizedPaletteDialog(context, controller),
                  child: const Text('Open Generator'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Generator'));
        await tester.pumpAndSettle();

        expect(find.text('Harmonized Palette Generator'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('theme-seed-live-preview')),
          findsOneWidget,
        );
        expect(find.textContaining('AAA'), findsOneWidget);

        // Tap Emerald preset
        final emeraldChip = find.byKey(
          const ValueKey('theme-seed-preset-emerald'),
        );
        await tester.tap(emeraldChip);
        await tester.pumpAndSettle();

        // Apply immediately
        final applyBtn = find.byKey(const ValueKey('theme-seed-apply-button'));
        await tester.tap(applyBtn);
        await tester.pumpAndSettle();

        // Verify session was updated with custom overrides
        expect(controller.session.colorOverrides, isNotEmpty);
        await tester.pump(const Duration(milliseconds: 700));
      },
    );

    testWidgets(
      'showHarmonizedPaletteDialog allows saving generated theme to gallery and customThemes',
      (tester) async {
        final repo = WorkspaceRepository(
          store: MemoryStore(),
          index: MemoryObjectIndex(),
        );
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);
        final controller = container.read(workspaceProvider.notifier);
        await controller.initialize();
        controller.updateSession((s) {
          s.motion = 'off';
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitTheme(),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      showHarmonizedPaletteDialog(context, controller),
                  child: const Text('Open Generator'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Generator'));
        await tester.pumpAndSettle();

        // Tap Rose preset
        final roseChip = find.byKey(const ValueKey('theme-seed-preset-rose'));
        await tester.tap(roseChip);
        await tester.pumpAndSettle();

        // Enter custom name
        await tester.enterText(
          find.byKey(const ValueKey('theme-seed-name-input')),
          'Harmonized Rose Studio',
        );
        await tester.pumpAndSettle();

        // Tap Save to Gallery
        final saveBtn = find.byKey(const ValueKey('theme-seed-save-button'));
        await tester.ensureVisible(saveBtn);
        await tester.pumpAndSettle();
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        expect(
          controller.session.customThemes.any(
            (m) => m['name'] == 'Harmonized Rose Studio',
          ),
          isTrue,
        );
        await tester.pump(const Duration(milliseconds: 700));
      },
    );

    testWidgets(
      'ThemeColorSettings renders Generate from Seed button and launches dialog',
      (tester) async {
        final repo = WorkspaceRepository(
          store: MemoryStore(),
          index: MemoryObjectIndex(),
        );
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);
        final controller = container.read(workspaceProvider.notifier);
        await controller.initialize();
        controller.updateSession((s) {
          s.motion = 'off';
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitTheme(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ThemeColorSettings(controller: controller),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Expand ThemeColorSettings ExpansionTile
        await tester.tap(find.byKey(const ValueKey('settings-custom-colors')));
        await tester.pumpAndSettle();

        final genBtn = find.byKey(
          const ValueKey('theme-generate-palette-button'),
        );
        await tester.ensureVisible(genBtn);
        await tester.pumpAndSettle();
        expect(genBtn, findsOneWidget);

        await tester.tap(genBtn);
        await tester.pumpAndSettle();

        expect(find.text('Harmonized Palette Generator'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 700));
      },
    );

    testWidgets(
      'Theme Gallery dialog includes Generate button that opens palette generator',
      (tester) async {
        final repo = WorkspaceRepository(
          store: MemoryStore(),
          index: MemoryObjectIndex(),
        );
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);
        final controller = container.read(workspaceProvider.notifier);
        await controller.initialize();
        controller.updateSession((s) {
          s.motion = 'off';
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitTheme(),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      showOrbitThemeGalleryDialog(context, controller),
                  child: const Text('Open Gallery'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Gallery'));
        await tester.pumpAndSettle();

        final genBtn = find.byKey(
          const ValueKey('theme-gallery-generate-button'),
        );
        expect(genBtn, findsOneWidget);
        await tester.tap(genBtn);
        await tester.pumpAndSettle();

        expect(find.text('Harmonized Palette Generator'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 700));
      },
    );
  });
}
