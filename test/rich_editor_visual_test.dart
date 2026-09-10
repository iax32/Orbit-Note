import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/rich/note_math.dart';
import 'package:orbit_note/features/notes/rich/code_block.dart';

void main() {
  testWidgets('mixed Rich lecture and narrow Notes remain usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1050);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const capture = bool.fromEnvironment('ORBIT_CAPTURE_UI');
    if (capture && Platform.isWindows) {
      await tester.runAsync(() async {
        final text = FontLoader('Segoe UI')
          ..addFont(
            File(
              r'C:\Windows\Fonts\segoeui.ttf',
            ).readAsBytes().then((b) => b.buffer.asByteData()),
          );
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await text.load();
        await icons.load();
        final mono = FontLoader('monospace')
          ..addFont(
            File(
              r'C:\Windows\Fonts\consola.ttf',
            ).readAsBytes().then((b) => b.buffer.asByteData()),
          );
        await mono.load();
        final manifest =
            jsonDecode(await rootBundle.loadString('FontManifest.json'))
                as List;
        for (final family in manifest.cast<Map<String, dynamic>>()) {
          if (!(family['family'] as String).startsWith(
            'packages/flutter_math_fork/',
          )) {
            continue;
          }
          final loader = FontLoader(family['family'] as String);
          for (final font in family['fonts'] as List) {
            loader.addFont(rootBundle.load(font['asset'] as String));
          }
          await loader.load();
        }
      });
    }
    const source =
        '# Connections, made clear\n\n'
        'A place for **careful thinking**, _small discoveries_ and useful connections.\n\n'
        '- Read the lecture notes\n- [x] Work through the first example\n\n'
        '## The idea in one equation\n\n'
        '\$\$\n\\int_0^1 x^2\\,dx = \\frac{1}{3}\n\$\$\n\n'
        '| Concept | Observation |\n| :--- | :--- |\n| Derivative | Local change |\n| Integral | Accumulated change |\n\n'
        '```python\ndef square(x):\n    return x * x\n```\n';
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: NoteEditor(
              noteId: 'visual-lecture',
              title: 'Calculus · Lecture 01',
              body: source,
              onTitleChanged: (_) {},
              onBodyChanged: (_) {},
              linkTargets: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NoteMath), findsOneWidget);
    expect(find.byType(NoteCodeBlock), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (capture) {
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        await Directory('work/ui').create(recursive: true);
        await File(
          'work/ui/rich-lecture.png',
        ).writeAsBytes(data!.buffer.asUint8List());
      });
    }
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('note-mode-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Source').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note-body')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
