import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_math_fork/flutter_math.dart' show Math;
import 'package:orbit_note/app/app_zoom.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/domain/note_writing_appearance.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/note_typography.dart';
import 'package:orbit_note/features/notes/pixel_font_scope.dart';
import 'package:orbit_note/features/notes/rich/code_block.dart';
import 'package:orbit_note/features/notes/rich/note_math.dart';
import 'support/capture_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pixel headings use the original grid-aligned outline weight', () {
    const pixel = NoteTypography(fontFamily: 'OrbitPixel');
    expect(pixel.headingWeight, FontWeight.w400);
    for (var level = 1; level <= 6; level++) {
      expect(pixel.heading(level).fontWeight, FontWeight.w400);
    }
    expect(
      pixel.markdown(orbitDarkTheme()).tableHead!.fontWeight,
      FontWeight.w400,
    );
  });

  test('terminal headings select the bundled bold face', () {
    expect(
      const NoteTypography(fontFamily: 'OrbitTerminal').headingWeight,
      FontWeight.w700,
    );
    expect(
      const NoteTypography(fontFamily: 'OrbitBook').headingWeight,
      FontWeight.w700,
    );
    expect(
      const NoteTypography(fontFamily: 'Segoe UI').headingWeight,
      FontWeight.w600,
    );
  });

  testWidgets('nested pixel scopes restore continuous specialist text sizing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.1)),
          child: PixelFontScope(
            enabled: true,
            child: PixelFontScope(
              enabled: false,
              child: Builder(
                builder: (context) =>
                    Text(MediaQuery.textScalerOf(context).scale(13).toString()),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('14.3'), findsOneWidget);
  });

  testWidgets(
    'pixel notes retain precise continuous sizing in real code fields',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.1)),
            child: Scaffold(
              body: PixelFontScope(
                enabled: true,
                child: NoteCodeBlock(
                  code: 'print("Hello")',
                  language: 'python',
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      final code = find.byKey(const ValueKey('rich-code'));
      final controller = tester.widget<TextField>(code).controller!;
      controller.selection = const TextSelection(
        baseOffset: 1,
        extentOffset: 4,
      );
      final native = find.descendant(
        of: code,
        matching: find.byType(EditableText),
      );
      expect(
        MediaQuery.textScalerOf(native.evaluate().single).scale(14),
        closeTo(15.4, .00001),
      );
      expect(
        controller.selection,
        const TextSelection(baseOffset: 1, extentOffset: 4),
      );
    },
  );

  testWidgets('pixel notes retain continuous equation typography', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.1)),
          child: const Scaffold(
            body: PixelFontScope(
              enabled: true,
              child: NoteMath(r'\frac{1}{2} + x'),
            ),
          ),
        ),
      ),
    );
    // The math renderer reads the restored scaling below NoteMath's scope.
    final renderer = find.descendant(
      of: find.byType(NoteMath),
      matching: find.byType(Math),
    );
    expect(renderer, findsOneWidget);
    expect(
      MediaQuery.textScalerOf(renderer.evaluate().single).scale(17),
      closeTo(18.7, .00001),
    );
    expect(tester.takeException(), isNull);
  });

  for (final mode in ['rich', 'read', 'write', 'split']) {
    testWidgets('real-font zoom specimen and retained input in $mode', (
      tester,
    ) async {
      await prepareCapture(tester);
      if (const bool.fromEnvironment('ORBIT_CAPTURE_UI')) {
        for (final face in {
          'OrbitPixel': ['assets/writing/Tiny5.ttf'],
          'OrbitTerminal': [
            'assets/writing/SpaceMono-Regular.ttf',
            'assets/writing/SpaceMono-Bold.ttf',
            'assets/writing/SpaceMono-Italic.ttf',
            'assets/writing/SpaceMono-BoldItalic.ttf',
          ],
          'OrbitBook': [
            'assets/publishing/CrimsonText-Regular.ttf',
            'assets/publishing/CrimsonText-Bold.ttf',
            'assets/publishing/CrimsonText-Italic.ttf',
            'assets/publishing/CrimsonText-BoldItalic.ttf',
          ],
        }.entries) {
          final loader = FontLoader(face.key);
          for (final path in face.value) {
            loader.addFont(rootBundle.load(path));
          }
          await tester.runAsync(loader.load);
        }
      }
      tester.view.physicalSize = const Size(1600, 1250);
      tester.view.devicePixelRatio = 1.25;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var zoom = 1.0, writes = 0;
      await tester.pumpWidget(
        RepaintBoundary(
          child: MaterialApp(
            theme: orbitDarkTheme(),
            home: StatefulBuilder(
              builder: (context, update) => AppZoom(
                zoom: zoom,
                onChanged: (value) => update(() => zoom = value),
                child: Scaffold(
                  body: NoteEditor(
                    noteId: 'font-quality',
                    title: 'A Clear Heading',
                    body:
                        '# Chapter One\n\nA notebook for ideas. Bold **words**, symbols α + β and emoji 🎮.\n\n## A second heading\n\nKeep these words while zooming.\n\n```python\nprint("Hello")\n```',
                    onTitleChanged: (_) => writes++,
                    onBodyChanged: (_) => writes++,
                    onOpenObject: (_) {},
                    linkTargets: const [],
                    initialViewState: {
                      'mode': mode,
                      'writingAppearance': const NoteWritingAppearance(
                        design: WritingDesign.pixelBook,
                        quiet: true,
                      ).toData(),
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final title = find.byKey(const ValueKey('note-title'));
      final controller = tester.widget<TextField>(title).controller!;
      await tester.tap(title);
      controller.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 7,
      );
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.equal);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(title).controller, same(controller));
        expect(
          controller.selection,
          const TextSelection(baseOffset: 2, extentOffset: 7),
        );
        expect(writes, 0);
        expect(tester.takeException(), isNull);
      }
      expect(zoom, 1.75);
      await captureUi(
        tester,
        'writing-font-quality-$mode',
        pixelRatio: tester.view.devicePixelRatio,
      );
    });
  }

  for (final family in [
    'Times New Roman',
    'Georgia',
    'Consolas',
    'OrbitBook',
    'OrbitTerminal',
  ]) {
    testWidgets('$family keeps continuous zoom and selected text in the book', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(2400, 2000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var zoom = 1.0, writes = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.1)),
            child: StatefulBuilder(
              builder: (context, update) => AppZoom(
                zoom: zoom,
                onChanged: (v) => update(() => zoom = v),
                child: Scaffold(
                  body: NoteEditor(
                    noteId: family,
                    title: 'Readable heading',
                    body: '# A heading\n\nKeep this paragraph.',
                    fontFamily: family,
                    onTitleChanged: (_) => writes++,
                    onBodyChanged: (_) => writes++,
                    onOpenObject: (_) {},
                    linkTargets: const [],
                    initialViewState: {
                      'mode': 'rich',
                      'writingAppearance': const NoteWritingAppearance(
                        design: WritingDesign.pixelBook,
                        styledFont: false,
                        quiet: true,
                      ).toData(),
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final title = find.byKey(const ValueKey('note-title'));
      final controller = tester.widget<TextField>(title).controller!;
      await tester.tap(title);
      controller.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 8,
      );
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.equal);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        final field = tester.widget<TextField>(title);
        expect(field.controller, same(controller));
        expect(field.style!.fontFamily, family);
        expect(
          field.style!.fontWeight,
          NoteTypography(fontFamily: family).headingWeight,
        );
        expect(
          MediaQuery.textScalerOf(
            find
                .descendant(of: title, matching: find.byType(EditableText))
                .evaluate()
                .single,
          ).scale(17),
          closeTo(17 * 1.1 * zoom, .00001),
        );
        expect(
          controller.selection,
          const TextSelection(baseOffset: 2, extentOffset: 8),
        );
        expect(writes, 0);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
