import 'dart:convert';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:orbit_note/app/orbit_app.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/features/notes/latex/latex_preview.dart';
import 'package:orbit_note/features/notes/latex/latex_syntax_highlighter.dart';
import 'package:orbit_note/features/notes/rich/callout_block.dart';
import 'package:orbit_note/features/notes/rich/code_block.dart';
import 'package:orbit_note/features/notes/rich/note_highlight.dart';
import 'package:orbit_note/features/workspace/graph_view.dart';
import 'package:orbit_note/features/workspace/theme_color_settings.dart';
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

Iterable<TextSpan> spans(TextSpan span) sync* {
  yield span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    if (child is TextSpan) yield* spans(child);
  }
}

void main() {
  test(
    'all six explicit accent choices adapt readably to every built-in without overriding authored colors',
    () {
      for (final pack in OrbitThemePack.builtIn) {
        for (final accent in OrbitColors.accentPresets.values) {
          final theme = orbitTheme(preset: pack.id, accentColor: accent),
              c = theme.extension<OrbitColors>()!;
          for (final surface in surfaces(c)) {
            expect(
              OrbitContrast.ratio(c.accent, surface),
              greaterThanOrEqualTo(4.5),
              reason: pack.id,
            );
            expect(
              OrbitContrast.ratio(c.accentHover, surface),
              greaterThanOrEqualTo(4.5),
              reason: pack.id,
            );
          }
          expect(
            HSLColor.fromColor(c.accent).hue,
            closeTo(HSLColor.fromColor(accent).hue, 1.5),
          );
        }
      }
      final explicit = orbitTheme(
        preset: 'palette-sage-light',
        accentColor: const Color(0xff10b981),
        colorOverrides: {'accent': 0xff123456, 'accentHover': 0xff234567},
      );
      expect(explicit.colorScheme.primary, const Color(0xff123456));
      expect(
        explicit.extension<OrbitColors>()!.accentHover,
        const Color(0xff234567),
      );
    },
  );
  test(
    'all 113 built-ins meet semantic contrast on every actual state surface',
    () {
      expect(OrbitThemePack.builtIn.length, 113);
      for (final pack in OrbitThemePack.builtIn) {
        final c = pack.colors, theme = orbitTheme(preset: pack.id);
        for (final background in surfaces(c)) {
          for (final entry in {
            'text': c.text,
            'subtle': c.subtle,
            'muted': c.muted,
            'accent': c.accent,
            'secondary': c.secondary,
            'accentHover': c.accentHover,
            'success': c.success,
            'warning': c.warning,
            'danger': c.danger,
            'link': c.link,
            'visited': c.linkVisited,
          }.entries) {
            expect(
              OrbitContrast.ratio(entry.value, background),
              greaterThanOrEqualTo(entry.key == 'text' ? 7 : 4.5),
              reason:
                  '${pack.id}: ${entry.key} on ${background.toARGB32().toRadixString(16)}',
            );
          }
          expect(
            OrbitContrast.ratio(c.focus, background),
            greaterThanOrEqualTo(3),
          );
        }
        for (final role in [
          c.accent,
          c.success,
          c.warning,
          c.danger,
          c.secondary,
        ]) {
          expect(
            OrbitContrast.ratio(role, c.tinted(role)),
            greaterThanOrEqualTo(4.5),
            reason: pack.id,
          );
          expect(
            OrbitContrast.ratio(role, OrbitContrast.inkOn(role)),
            greaterThanOrEqualTo(4.5),
          );
        }
        expect(theme.textTheme.bodyMedium!.color, c.text);
        expect(theme.textTheme.headlineLarge!.color, c.text);
        expect(theme.canvasColor, c.panel);
        expect(theme.cardColor, c.raised);
        expect(theme.colorScheme.onPrimary, c.onAccent);
        expect(theme.inputDecorationTheme.fillColor, c.input);
        expect(theme.dialogTheme.backgroundColor, c.floating);
        expect(theme.popupMenuTheme.color, c.floating);
        expect(
          (theme.inputDecorationTheme.focusedBorder! as OutlineInputBorder)
              .borderSide
              .color,
          c.focus,
        );
        expect(
          OrbitContrast.ratio(
            theme.colorScheme.onErrorContainer,
            theme.colorScheme.errorContainer,
          ),
          greaterThanOrEqualTo(4.5),
        );
      }
      expect(
        OrbitThemePack.fromId('orbit').colors.roles,
        const OrbitColors().roles,
      );
      expect(
        OrbitThemePack.fromId('orbit').colors.background,
        const Color(0xff141418),
      );
      expect(
        OrbitThemePack.fromId('orbit').colors.accent,
        const Color(0xffb0a0ff),
      );
      expect(
        OrbitThemePack.fromId('paper').colors.background,
        OrbitThemePack.paper.colors.background,
      );
      expect(
        OrbitThemePack.fromId('observatory').colors.panel,
        OrbitThemePack.observatory.colors.panel,
      );
    },
  );

  test(
    'new and missing preferences follow theme; explicit accents, authored colors and unknown fields survive restart',
    () {
      expect(SessionState().accentColor, 'theme');
      expect(SessionState.fromJson({}).accentColor, 'theme');
      final s = SessionState.fromJson({
        'themePreset': 'orbit',
        'accentColor': 'violet',
        'followSystemAppearance': true,
        'futureAppearance': {'mode': 4},
        'colorOverrides': {'warning': 0xffac7700, 'futureRole': 0xff223344},
        'folderColors': {'Ideas': 0xffbd33ab},
      });
      final roundTrip = SessionState.fromJson(
        jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
      );
      expect(roundTrip.accentColor, 'violet');
      expect(roundTrip.colorOverrides, s.colorOverrides);
      expect(roundTrip.folderColors, s.folderColors);
      expect(roundTrip.extra['futureAppearance'], {'mode': 4});
      expect(roundTrip.followSystemAppearance, true);
      final custom = OrbitThemePack.fromJson({
        'id': 'authored-colors',
        'name': 'My colors',
        'colors': {'text': '#ff224466', 'warning': '#ff556677'},
      });
      expect(custom.colors.text, const Color(0xff224466));
      expect(custom.colors.warning, const Color(0xff556677));
    },
  );

  testWidgets(
    'fallback surfaces respect light appearance instead of leaking graphite',
    (t) async {
      OrbitColors? actual;
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Builder(
            builder: (context) {
              actual = OrbitColors.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(
        actual!.background,
        OrbitThemePack.fromId('paper').colors.background,
      );
      expect(
        OrbitContrast.ratio(actual!.text, actual!.panel),
        greaterThanOrEqualTo(7),
      );
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) {
              actual = OrbitColors.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(actual!.roles, const OrbitColors().roles);
    },
  );

  testWidgets(
    'code and LaTeX tokens change between same-mode palettes without moving selection or changing source',
    (t) async {
      final code = CodeController(
        text: 'if True:\n  return "yes" # detail',
        language: 'python',
      );
      final latex = LatexTextEditingController(
        text: r'\section{Title} $x+1$ % detail',
      );
      final theme = ValueNotifier(orbitTheme());
      addTearDown(code.dispose);
      addTearDown(latex.dispose);
      addTearDown(theme.dispose);
      BuildContext? context;
      await t.pumpWidget(
        ValueListenableBuilder(
          valueListenable: theme,
          builder: (_, value, _) => MaterialApp(
            theme: value,
            home: Scaffold(
              body: Builder(
                builder: (ctx) {
                  context = ctx;
                  return Column(
                    children: [
                      TextField(
                        key: const ValueKey('code-field'),
                        controller: code,
                        maxLines: 3,
                      ),
                      TextField(controller: latex, maxLines: 2),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await t.tap(find.byKey(const ValueKey('code-field')));
      code.selection = const TextSelection(baseOffset: 0, extentOffset: 2);
      latex.selection = const TextSelection(baseOffset: 1, extentOffset: 8);
      final codeText = code.text, latexText = latex.text;
      Color? previous;
      for (final id in ['orbit', 'palette-cobalt-dark', 'palette-sage-light']) {
        theme.value = orbitTheme(preset: id);
        await t.pumpAndSettle();
        final c = OrbitThemePack.fromId(id).colors;
        final tokenSpans = spans(
          code.buildTextSpan(
            context: context!,
            style: TextStyle(color: c.text),
            withComposing: false,
          ),
        ).toList();
        expect(
          tokenSpans.any((s) => s.style?.color == c.secondary),
          true,
          reason: id,
        );
        expect(tokenSpans.any((s) => s.style?.color == c.success), true);
        if (previous != null) expect(c.secondary, isNot(previous));
        previous = c.secondary;
        final latexSpans = spans(
          latex.buildTextSpan(
            context: context!,
            style: TextStyle(color: c.text),
            withComposing: false,
          ),
        ).toList();
        expect(
          latexSpans.firstWhere((s) => s.text == r'\section').style!.color,
          c.accent,
        );
        expect(
          latexSpans.firstWhere((s) => s.text == r'$x+1$').style!.color,
          c.success,
        );
        expect(
          code.selection,
          const TextSelection(baseOffset: 0, extentOffset: 2),
        );
        expect(
          latex.selection,
          const TextSelection(baseOffset: 1, extentOffset: 8),
        );
        expect(code.text, codeText);
        expect(latex.text, latexText);
      }
      code.value = code.value.copyWith(
        composing: const TextRange(start: 0, end: 2),
      );
      final composed = code.buildTextSpan(
        context: context!,
        style: const TextStyle(),
        withComposing: true,
      );
      expect(composed.toPlainText(), code.text);
      expect(
        spans(
          composed,
        ).any((s) => s.style?.decoration == TextDecoration.underline),
        true,
      );
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Rich and Read callouts, highlights and LaTeX preview all use the selected palette',
    (t) async {
      var writes = 0;
      for (final id in ['orbit', 'palette-sage-light', 'palette-cobalt-dark']) {
        final c = OrbitThemePack.fromId(id).colors;
        await t.pumpWidget(
          MaterialApp(
            theme: orbitTheme(preset: id),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    CalloutBlock(
                      source: '> [!WARNING] Take care\n> Details',
                      onChanged: (_) => writes++,
                    ),
                    MarkdownBody(
                      data: '> [!WARNING] Read care\n> Details\n\n==Marked==',
                      blockSyntaxes: const [CalloutBlockSyntax()],
                      inlineSyntaxes: [HighlightInlineSyntax()],
                      builders: {
                        'callout': CalloutElementBuilder(),
                        'mark': HighlightElementBuilder(),
                      },
                    ),
                    const LatexPreview(
                      latex: r'\title{Palette preview}\section{Details} Text.',
                      contentWidth: 700,
                      fontSize: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final warningIcons = t.widgetList<Icon>(
          find.byIcon(Icons.warning_amber_rounded),
        );
        expect(warningIcons.length, greaterThanOrEqualTo(2));
        expect(warningIcons.every((w) => w.color == c.warning), true);
        expect(t.widget<Text>(find.text('Marked')).style!.color, c.warning);
        final preview = t.element(find.byType(LatexPreview));
        expect(OrbitColors.of(preview).workspace, c.workspace);
        final papers = t.widgetList<Container>(
          find.descendant(
            of: find.byType(LatexPreview),
            matching: find.byType(Container),
          ),
        );
        expect(
          papers.any(
            (w) =>
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color == c.workspace,
          ),
          true,
        );
        expect(writes, 0);
        expect(t.takeException(), isNull);
      }
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'advanced color controls follow the current family and recover from unreadable overrides',
    (t) async {
      final container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(
            WorkspaceRepository(
              store: MemoryStore(),
              index: MemoryObjectIndex(),
            ),
          ),
        ],
      );
      final c = container.read(workspaceProvider.notifier);
      await c.initialize();
      addTearDown(() {
        c.cancelAllTimers();
        container.dispose();
      });
      for (final id in ['orbit', 'palette-sage-light', 'palette-cobalt-dark']) {
        c.updateSession((s) {
          s.themePreset = id;
          s.colorOverrides = {'text': 0xff000000, 'panel': 0xff000000};
          s.motion = 'off';
        });
        await t.pumpWidget(
          MaterialApp(
            theme: orbitThemeForPreferences(
              c.session.preferences,
              Brightness.light,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ThemeColorSettings(controller: c),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final recovery = Theme.of(
          t.element(find.byKey(const ValueKey('settings-custom-colors'))),
        );
        expect(recovery.brightness, OrbitThemePack.fromId(id).brightness);
        expect(
          recovery.extension<OrbitColors>()!.panel,
          OrbitThemePack.fromId(id).colors.panel,
        );
        expect(
          OrbitContrast.ratio(
            recovery.textTheme.bodyMedium!.color!,
            recovery.extension<OrbitColors>()!.panel,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(c.session.colorOverrides, {
          'text': 0xff000000,
          'panel': 0xff000000,
        });
      }
      await t.pumpWidget(const SizedBox());
      c.cancelAllTimers();
    },
  );

  testWidgets(
    'minimap cache invalidates for semantic-only changes without modifying authored scene colors',
    (t) async {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'future': {'keep': true},
        'elements': [
          {
            'id': 'card',
            'type': 'card',
            'x': 10,
            'y': 10,
            'width': 200,
            'height': 120,
            'color': 0xffdd33aa,
            'futureValue': 'keep',
          },
        ],
      });
      final before = jsonEncode(scene.toJson());
      final palette = OrbitThemePack.fromId('palette-sage-light').colors;
      final changed = palette.copyWith(warning: const Color(0xff7b1878));
      final scheme = orbitTheme(preset: 'palette-sage-light').colorScheme;
      final cache = CanvasPictureCache();
      final textCache = CanvasTextCache();
      addTearDown(cache.dispose);
      addTearDown(textCache.dispose);
      Future<String> render(CustomPainter painter) async {
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), const Size(240, 180));
        final picture = recorder.endRecording();
        final image = await picture.toImage(240, 180);
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final hash = sha256.convert(bytes!.buffer.asUint8List()).toString();
        image.dispose();
        picture.dispose();
        return hash;
      }

      CanvasMinimapPainter mini(OrbitColors colors) => CanvasMinimapPainter(
        scene: scene,
        camera: CanvasCamera(),
        viewportSize: const Size(240, 180),
        colors: scheme,
        semanticColors: colors,
        pictureCache: cache,
        searchMatchIds: const {'card'},
      );
      final a = mini(palette), b = mini(changed);
      expect(b.shouldRepaint(a), true);
      await t.runAsync(() async {
        expect(await render(a), isNot(await render(b)));
      });
      final paintA = OrbitCanvasPainter(
        scene: scene,
        camera: CanvasCamera(),
        selection: const {},
        objects: const {},
        colors: scheme,
        semanticColors: palette,
        textCache: textCache,
        searchMatchIds: const {'card'},
      );
      final paintB = OrbitCanvasPainter(
        scene: scene,
        camera: CanvasCamera(),
        selection: const {},
        objects: const {},
        colors: scheme,
        semanticColors: changed,
        textCache: textCache,
        searchMatchIds: const {'card'},
      );
      expect(paintB.shouldRepaint(paintA), true);
      await t.runAsync(() async {
        expect(await render(paintA), isNot(await render(paintB)));
      });
      OrbitCanvasPainter grid(OrbitColors colors) => OrbitCanvasPainter(
        scene: CanvasScene.fromJson({'schemaVersion': 1, 'elements': []}),
        camera: CanvasCamera(),
        selection: const {},
        objects: const {},
        colors: scheme,
        semanticColors: colors,
        textCache: textCache,
        backgroundStyle: 'grid',
      );
      final gridA = grid(palette);
      final gridB = grid(palette.copyWith(canvasGrid: const Color(0xffa32266)));
      expect(gridB.shouldRepaint(gridA), true);
      await t.runAsync(() async {
        expect(await render(gridA), isNot(await render(gridB)));
      });
      expect(jsonEncode(scene.toJson()), before);
      expect(scene['card']!.color, 0xffdd33aa);
    },
  );

  testWidgets(
    'actual app uses the new default and live palette changes keep notes and graph categories intact',
    (t) async {
      t.view.physicalSize = const Size(1400, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
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
      addTearDown(() {
        c.cancelAllTimers();
        container.dispose();
      });
      c.updateSession((s) {
        s.motion = 'off';
        s.spellCheckEnabled = false;
      });
      final note = (await c.create(
        'orbit.note',
        title: 'Original',
        body: 'Keep my **source** and colors.',
      ))!;
      final savedBody = c.find(note.id)!.body;
      final authored = {
        for (final e in store.files.entries)
          if (e.key.endsWith('.md')) e.key: e.value.toList(),
      };
      expect(authored, isNotEmpty);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const OrbitNoteApp(),
        ),
      );
      await t.pumpAndSettle();
      for (final id in ['orbit', 'palette-sage-light', 'palette-cobalt-dark']) {
        c.updateSession((s) => s.themePreset = id);
        c.navigate(OrbitDestination.graph);
        await t.pumpAndSettle();
        final theme = t.widget<MaterialApp>(find.byType(MaterialApp)).theme!,
            colors = OrbitThemePack.fromId(id).colors;
        expect(theme.colorScheme.primary, colors.accent);
        expect(theme.textTheme.bodyMedium!.color, colors.text);
        expect(find.byType(GraphView), findsOneWidget);
        final node = GraphNode(
          id: 'task',
          title: 'Task',
          type: 'orbit.task',
          x: 0,
          y: 0,
        );
        expect(node.colorFor(colors), colors.warning);
        expect(c.find(note.id)!.body, savedBody);
        expect({
          for (final e in store.files.entries)
            if (e.key.endsWith('.md')) e.key: e.value.toList(),
        }, authored);
        expect(t.takeException(), isNull);
      }
      await t.pumpWidget(const SizedBox());
      c.cancelAllTimers();
    },
  );
}
