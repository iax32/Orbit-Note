import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_components.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/features/workspace/settings_view.dart';
import 'package:orbit_note/features/notes/rich/code_workspace.dart';
import 'package:orbit_note/features/notes/rich/code_surface.dart';
import 'support/memory_store.dart';
import 'support/settings_navigation.dart';

void main() {
  Future<WorkspaceController> mount(
    WidgetTester t, {
    Size size = const Size(1320, 1000),
    double scale = 1,
    SessionState? session,
    VoidCallback? onExport,
    double keyboardInset = 0,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(
          WorkspaceRepository(store: MemoryStore(), index: MemoryObjectIndex()),
        ),
      ],
    );
    final c = container.read(workspaceProvider.notifier);
    await c.initialize();
    if (session != null) c.session = session;
    c.session.motion = 'off';
    addTearDown(() {
      c.cancelAllTimers();
      container.dispose();
    });
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: orbitThemeForPreferences(
            c.session.preferences,
            Brightness.dark,
          ),
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
              viewInsets: EdgeInsets.only(bottom: keyboardInset),
            ),
            child: OrbitMotionScope(
              preference: 'off',
              osReduced: true,
              child: Scaffold(
                body: SettingsView(
                  controller: c,
                  onExport: onExport ?? () {},
                  onImport: () {},
                  onOpenWorkspace: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    return c;
  }

  Future<void> reset(WidgetTester t) async {
    await t.ensureVisible(find.byKey(const ValueKey('settings-reset-section')));
    await t.tap(find.byKey(const ValueKey('settings-reset-section')));
    await t.pumpAndSettle();
    await t.tap(find.text('Reset preferences'));
    await t.pumpAndSettle();
  }

  test(
    'new code defaults and all paper choices survive portable session reload without losing unknown data',
    () {
      final old = SessionState.fromJson({
        'future': {'keep': 7},
      });
      expect(old.defaultCodeWrap, false);
      expect(old.codeFontSize, 14);
      final s = SessionState.fromJson({
        'defaultCodeWrap': true,
        'codeFontSize': 22,
        'monoFontFamily': 'OrbitTerminal',
        'showLineNumbers': false,
        'defaultCanvasGrid': 'blueprint_classic',
        'future': {'keep': 7},
      });
      final copy = SessionState.fromJson(
        jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
      );
      expect(copy.defaultCodeWrap, true);
      expect(copy.codeFontSize, 22);
      expect(copy.showLineNumbers, false);
      expect(copy.monoFontFamily, 'OrbitTerminal');
      expect(copy.defaultCanvasGrid, 'blueprint_classic');
      expect(copy.extra['future'], {'keep': 7});
      expect(SessionState.fromJson({'codeFontSize': 999}).codeFontSize, 26);
      expect(
        SessionState.fromJson({
          'codeFontSize': 'bad',
          'defaultCodeWrap': 'yes',
        }).codeFontSize,
        14,
      );
      expect(
        SessionState.fromJson({'codeFontSize': double.nan}).codeFontSize,
        14,
      );
    },
  );
  testWidgets(
    'desktop categories and search reveal real settings without changing preferences',
    (t) async {
      final c = await mount(t);
      final before = jsonEncode(c.session.toJson());
      expect(
        find.byKey(const ValueKey('settings-category-code')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('settings-code-numbers')), findsNothing);
      await searchSettings(t, 'line numbers');
      expect(
        find.byKey(const ValueKey('settings-code-numbers')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('settings-spellcheck-switch')),
        findsNothing,
      );
      expect(jsonEncode(c.session.toJson()), before);
      await searchSettings(t, 'absolutely-no-setting');
      expect(find.text('No matching settings'), findsOneWidget);
      await t.tap(find.byTooltip('Clear search'));
      await t.pumpAndSettle();
      expect(find.text('Theme & color'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('settings-category-code')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('settings-code-numbers')));
      await t.pumpAndSettle();
      expect(c.session.showLineNumbers, false);
      expect(
        t
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('settings-code-numbers')),
            )
            .value,
        false,
      );
      await t.tap(find.byKey(const ValueKey('settings-code-wrap')));
      await t.pump();
      await c.flushAll();
      final saved = SessionState.fromJson(
        await c.repository.readDeviceSettings(),
      );
      expect(saved.showLineNumbers, false);
      expect(saved.defaultCodeWrap, true);
    },
  );
  testWidgets(
    'section reset and Undo restore only their preferences and preserve current unrelated edits',
    (t) async {
      final c = await mount(
        t,
        session: SessionState(
          showLineNumbers: false,
          defaultCodeWrap: true,
          codeFontSize: 22,
          monoFontFamily: 'OrbitTerminal',
          fontSize: 21,
          extra: {'future': 9},
        ),
      );
      await t.tap(find.byKey(const ValueKey('settings-category-code')));
      await t.pumpAndSettle();
      await reset(t);
      expect(c.session.codeFontSize, 14);
      expect(c.session.defaultCodeWrap, false);
      expect(c.session.showLineNumbers, true);
      expect(c.session.fontSize, 21);
      c.updateSession((s) => s.fontSize = 24);
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(c.session.codeFontSize, 22);
      expect(c.session.defaultCodeWrap, true);
      expect(c.session.showLineNumbers, false);
      expect(c.session.monoFontFamily, 'OrbitTerminal');
      expect(c.session.fontSize, 24);
      expect(c.session.extra['future'], 9);
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(seconds: 1));
    },
  );
  testWidgets('Undo does not overwrite settings changed after a reset', (
    t,
  ) async {
    final c = await mount(
      t,
      session: SessionState(codeFontSize: 22, defaultCodeWrap: true),
    );
    await t.tap(find.byKey(const ValueKey('settings-category-code')));
    await t.pumpAndSettle();
    await reset(t);
    c.updateSession((s) => s.codeFontSize = 19);
    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect(c.session.codeFontSize, 19);
    expect(c.session.defaultCodeWrap, false);
    expect(
      find.text('Preferences changed after the reset. Undo was not applied.'),
      findsOneWidget,
    );
  });
  testWidgets('reset Undo cannot change a replacement Vault session', (
    t,
  ) async {
    final c = await mount(t, session: SessionState(codeFontSize: 22));
    await t.tap(find.byKey(const ValueKey('settings-category-code')));
    await t.pumpAndSettle();
    await reset(t);
    c.session = SessionState(codeFontSize: 18);
    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect(c.session.codeFontSize, 18);
    expect(
      find.text('Preferences changed after the reset. Undo was not applied.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'layout reset restores motion defaults, preserves unknown data and supports guarded Undo',
    (t) async {
      final original = {
        'profile': 'paper',
        'speed': 1.5,
        'readingProgress': true,
        'future': {'retained': 42},
      };
      final c = await mount(t, session: SessionState(motionOptions: original));
      await t.tap(find.byKey(const ValueKey('settings-category-layout')));
      await t.pumpAndSettle();
      await reset(t);
      expect(c.session.motionOptions['profile'], 'fluid');
      expect(c.session.motionOptions['readingProgress'], false);
      expect(c.session.motionOptions['future'], {'retained': 42});
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(c.session.motionOptions, original);
      await t.pump(const Duration(seconds: 1));
    },
  );
  testWidgets(
    'appearance recovery resets known overrides and Undo restores them exactly',
    (t) async {
      final c = await mount(
        t,
        session: SessionState(
          themePreset: 'paper',
          colorOverrides: {'text': 0xff123456, 'futureRole': 0xff443322},
        ),
      );
      await reset(t);
      expect(c.session.themePreset, 'orbit');
      expect(c.session.colorOverrides, {'futureRole': 0xff443322});
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(c.session.themePreset, 'paper');
      expect(c.session.colorOverrides, {
        'text': 0xff123456,
        'futureRole': 0xff443322,
      });
      await t.tap(find.byKey(const ValueKey('settings-reset-section')));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(c.session.themePreset, 'paper');
    },
  );
  testWidgets(
    'advanced color recovery stays readable when all custom roles are black',
    (t) async {
      final c = await mount(
        t,
        session: SessionState(
          colorOverrides: {
            for (final role in OrbitColors.roleLabels.keys) role: 0xff000000,
          },
        ),
      );
      final advanced = find.text('Advanced theme controls');
      await t.scrollUntilVisible(
        advanced,
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('settings-content')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.pump();
      final palette = Theme.of(t.element(advanced)).extension<OrbitColors>()!;
      expect(
        OrbitContrast.ratio(palette.text, palette.panel),
        greaterThanOrEqualTo(7),
      );
      expect(palette.panel, isNot(const Color(0xff000000)));
      await t.tap(advanced);
      await t.pumpAndSettle();
      final customize = find.byKey(const ValueKey('settings-custom-colors'));
      await t.scrollUntilVisible(
        customize,
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('settings-content')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.pump();
      await t.tap(find.text('Customize interface colors'));
      await t.pumpAndSettle();
      final reset = find.byKey(const ValueKey('theme-colors-reset'));
      await t.ensureVisible(reset);
      await t.pump();
      await t.tap(reset);
      await t.pumpAndSettle();
      expect(c.session.colorOverrides, isEmpty);
      await t.pump(const Duration(seconds: 1));
    },
  );
  testWidgets(
    'dictionary editor validates, deduplicates and supports recoverable clearing',
    (t) async {
      final c = await mount(
        t,
        session: SessionState(userDictionary: ['Orbit']),
      );
      await searchSettings(t, 'custom dictionary');
      await t.tap(find.byKey(const ValueKey('settings-manage-dictionary')));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('settings-dictionary-words')),
        'Orbit\norbit\nShaderGraph\nGPU',
      );
      await t.tap(find.text('Save words'));
      await t.pumpAndSettle();
      expect(c.session.userDictionary, ['Orbit', 'ShaderGraph', 'GPU']);
      await t.pump(const Duration(seconds: 1));
      await t.tap(
        find.byKey(const ValueKey('settings-clear-dictionary-button')),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Clear words'));
      await t.pumpAndSettle();
      expect(c.session.userDictionary, isEmpty);
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(c.session.userDictionary, ['Orbit', 'ShaderGraph', 'GPU']);
      await t.pump(const Duration(seconds: 1));
    },
  );
  testWidgets('stale dictionary drafts do not overwrite later edits', (
    t,
  ) async {
    final c = await mount(
      t,
      session: SessionState(userDictionary: ['Original']),
    );
    await searchSettings(t, 'custom dictionary');
    await t.tap(find.byKey(const ValueKey('settings-manage-dictionary')));
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const ValueKey('settings-dictionary-words')),
      'MyDraft',
    );
    c.updateSession((s) => s.userDictionary = ['Newer']);
    await t.tap(find.text('Save words'));
    await t.pumpAndSettle();
    expect(c.session.userDictionary, ['Newer']);
    expect(
      find.text(
        'The Vault or dictionary changed. Close and reopen this editor.',
      ),
      findsOneWidget,
    );
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
  });
  testWidgets(
    'files section exposes real backup actions and no fake optimization result',
    (t) async {
      var exports = 0;
      await mount(t, onExport: () => exports++);
      await searchSettings(t, 'Workspace data');
      await t.tap(find.text('Export workspace'));
      await t.pump();
      expect(exports, 1);
      expect(
        find.byKey(const ValueKey('settings-optimize-vault-button')),
        findsNothing,
      );
      expect(find.textContaining('Vault integrity verified'), findsNothing);
    },
  );
  for (final size in [const Size(320, 640), const Size(568, 320)]) {
    testWidgets(
      'settings search and controls work at $size with 250% text and keyboard',
      (t) async {
        final c = await mount(
          t,
          size: size,
          scale: 2.5,
          keyboardInset: size.height > 400 ? 100 : 60,
        );
        expect(t.takeException(), isNull);
        await searchSettings(t, 'default document format');
        final control = find.byKey(
          const ValueKey('settings-default-format-dropdown'),
        );
        await t.scrollUntilVisible(
          control,
          160,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('settings-content')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await t.ensureVisible(control);
        await t.pump();
        await t.tap(control);
        await t.pumpAndSettle();
        await t.tap(find.text('LaTeX Document').last);
        await t.pumpAndSettle();
        expect(c.session.defaultDocumentFormat, 'latex');
        expect(t.takeException(), isNull);
        await searchSettings(t, 'code numbers');
        final numbers = find.byKey(const ValueKey('settings-code-numbers'));
        await t.scrollUntilVisible(
          numbers,
          160,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('settings-content')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await t.ensureVisible(numbers);
        await t.pump();
        await t.tap(numbers);
        await t.pumpAndSettle();
        expect(c.session.showLineNumbers, false);
        expect(t.takeException(), isNull);
        await t.pump(const Duration(seconds: 1));
      },
    );
  }
  testWidgets(
    'code workspace uses defaults and live font changes keep source, focus and selection',
    (t) async {
      final theme = ValueNotifier(
        orbitTheme(
          monoFontFamily: 'OrbitTerminal',
          codeFontSize: 20,
          showLineNumbers: false,
          defaultCodeWrap: true,
        ),
      );
      addTearDown(theme.dispose);
      const source = 'const text = "unchanged";\nreturn text;';
      await t.pumpWidget(
        ValueListenableBuilder(
          valueListenable: theme,
          builder: (_, value, _) => MaterialApp(
            theme: value,
            home: Scaffold(
              body: CodeWorkspace(
                code: source,
                language: 'javascript',
                canApply: () => true,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final surface = t.widget<CodeSurface>(find.byType(CodeSurface));
      expect(surface.wrap, true);
      expect(surface.numbers, false);
      final field = find.byKey(const ValueKey('code-workspace-editor'));
      await t.tap(field);
      await t.pump();
      final controller = t.widget<TextField>(field).controller!;
      controller.selection = const TextSelection(
        baseOffset: 6,
        extentOffset: 10,
      );
      theme.value = orbitTheme(
        monoFontFamily: 'Consolas',
        codeFontSize: 24,
        showLineNumbers: true,
        defaultCodeWrap: false,
      );
      await t.pumpAndSettle();
      expect(t.widget<TextField>(field).style!.fontFamily, 'Consolas');
      expect(t.widget<TextField>(field).style!.fontSize, 24);
      expect(controller.text, source);
      expect(
        controller.selection,
        const TextSelection(baseOffset: 6, extentOffset: 10),
      );
      expect(t.widget<TextField>(field).focusNode!.hasFocus, true);
      expect(t.widget<CodeSurface>(find.byType(CodeSurface)).wrap, true);
      expect(t.widget<CodeSurface>(find.byType(CodeSurface)).numbers, false);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Ctrl F focuses settings search and Escape clears without editing preferences',
    (t) async {
      final c = await mount(t);
      final before = jsonEncode(c.session.toJson());
      await t.tap(find.byKey(const ValueKey('settings-search')));
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyF);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('settings-search')))
            .focusNode!
            .hasFocus,
        true,
      );
      await searchSettings(t, 'line numbers');
      await t.tap(find.byKey(const ValueKey('settings-search')));
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('settings-search')))
            .controller!
            .text,
        isEmpty,
      );
      expect(jsonEncode(c.session.toJson()), before);
    },
  );
}
