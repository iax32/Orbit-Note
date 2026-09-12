import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';

void main() {
  testWidgets(
    'Ctrl+V falls back to a clipboard image when no text is present',
    (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') return {'text': ''};
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      Map<String, dynamic> latest = {'schemaVersion': 1, 'elements': []};
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'board',
              data: latest,
              onChanged: (v) => latest = v,
              objects: const [],
              onOpenObject: (_) {},
              onPasteImage: () async => const CanvasImageReference(
                contentRef: 'Attachments/clipboard.png',
              ),
            ),
          ),
        ),
      );
      await tester.tapAt(const Offset(250, 220));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(
        (latest['elements'] as List).single['contentRef'],
        'Attachments/clipboard.png',
      );
    },
  );
  testWidgets('touch pans in pen mode and pen gestures still create ink', (
    tester,
  ) async {
    Map<String, dynamic> latest = {'schemaVersion': 1, 'elements': []};
    Map<String, dynamic>? camera;
    await tester.pumpWidget(
      MaterialApp(
        theme: orbitDarkTheme(),
        home: Scaffold(
          body: CanvasEditor(
            canvasId: 'board',
            data: latest,
            onChanged: (v) => latest = v,
            objects: const [],
            onOpenObject: (_) {},
            onCameraChanged: (v) => camera = v,
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Pen (P)'));
    final touch = await tester.startGesture(
      const Offset(250, 220),
      kind: PointerDeviceKind.touch,
    );
    await touch.moveBy(const Offset(80, 40));
    await touch.up();
    await tester.pump();
    expect(latest['elements'], isEmpty);
    expect(camera, isNotNull);
    final pen = await tester.startGesture(
      const Offset(250, 220),
      kind: PointerDeviceKind.stylus,
    );
    await pen.moveBy(const Offset(80, 40));
    await pen.up();
    await tester.pump();
    expect((latest['elements'] as List).single['type'], 'ink');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Canvas publishes text drafts and persists reference images', (
    tester,
  ) async {
    Map<String, dynamic> latest = {'schemaVersion': 1, 'elements': []};
    await tester.pumpWidget(
      MaterialApp(
        theme: orbitDarkTheme(),
        home: Scaffold(
          body: CanvasEditor(
            canvasId: 'board',
            data: latest,
            onChanged: (v) => latest = v,
            objects: const [],
            onOpenObject: (_) {},
            onInsertImage: () async => const CanvasImageReference(
              contentRef: 'Attachments/original.png',
              width: 320,
              height: 160,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Sticky note (S)'));
    await tester.tapAt(const Offset(250, 220));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Draft survives leaving Canvas',
    );
    await tester.pump();
    expect(
      (latest['elements'] as List).first['text'],
      'Draft survives leaving Canvas',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Insert image'));
    await tester.pumpAndSettle();
    final images = (latest['elements'] as List).where(
      (e) => e['type'] == 'image',
    );
    expect(images.single['contentRef'], 'Attachments/original.png');
    expect(images.single['height'], 160);
    expect(tester.takeException(), isNull);
  });

  testWidgets('displays canvas title and allows renaming canvas', (
    tester,
  ) async {
    String currentTitle = 'Initial Board Name';
    String? changedTitle;
    final data = {'schemaVersion': 1, 'elements': <dynamic>[]};

    await tester.pumpWidget(
      MaterialApp(
        theme: orbitDarkTheme(),
        home: Scaffold(
          body: CanvasEditor(
            canvasId: 'board-1',
            title: currentTitle,
            onTitleChanged: (val) => changedTitle = val,
            data: data,
            onChanged: (_) {},
            objects: const [],
            onOpenObject: (_) {},
          ),
        ),
      ),
    );

    // Verify title is rendered in the canvas title field
    final titleFinder = find.byKey(const ValueKey('canvas-title-field'));
    expect(titleFinder, findsOneWidget);
    final field = tester.widget<TextField>(titleFinder);
    expect(field.controller?.text, 'Initial Board Name');

    // Tap rename button
    final renameButton = find.byTooltip('Rename canvas');
    expect(renameButton, findsOneWidget);
    await tester.tap(renameButton);
    await tester.pumpAndSettle();

    // Verify typing updates title via onTitleChanged
    await tester.enterText(titleFinder, 'My Architecture Map');
    await tester.pump();
    expect(changedTitle, 'My Architecture Map');

    // Submit title
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  });
}
