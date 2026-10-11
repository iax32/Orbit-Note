import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/features/notes/media_clipboard.dart';
import 'package:orbit_note/features/notes/markdown_clipboard.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String clipboard = '';
  bool fail = false;
  Completer<void>? pending;
  setUp(() {
    clipboard = '';
    fail = false;
    pending = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            if (fail) throw PlatformException(code: 'clipboard-denied');
            await pending?.future;
            clipboard = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.getData') {
            return call.arguments == 'text/html' ? null : {'text': clipboard};
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  String payload(List<Map<String, dynamic>> elements) =>
      '$canvasClipboardPrefix${jsonEncode({'elements': elements})}';
  test('mixed images and prose transfer without treating code as an image', () {
    final items = markdownCanvasItems(
      'Before\n\n![A](<Attachments/a b.png>)\n\nAfter\n\n```md\n![Example](fake.png)\n```',
    );
    expect(items.map((e) => e['type']), ['sticky', 'image', 'sticky']);
    expect(items[1]['contentRef'], 'Attachments/a b.png');
    expect(items.last['text'], contains('![Example](fake.png)'));
  });
  test(
    'relative image paths become portable without rewriting code or prose',
    () {
      const source =
          '![A](<../Attachments/a b.png>)\r\n\r\n```md\r\n![A](../fake.png)\r\n```\r\n';
      expect(
        portableClipboardMarkdown(source, (v) => v.substring(3)),
        source.replaceFirst('../Attachments', 'Attachments'),
      );
    },
  );
  test('image-and-text sections retain the image and accompanying text', () {
    const source =
        '<!-- orbit:media left width=200 -->\n![A](<../Attachments/a.png>)\n\nCaption\n<!-- /orbit:media -->\n';
    final portable = portableClipboardMarkdown(source, (v) => v.substring(3));
    final items = markdownCanvasItems(portable);
    expect(items.first['contentRef'], 'Attachments/a.png');
    expect(items.last['text'], 'Caption');
  });
  test(
    'Canvas images, object cards and text have portable Markdown fallbacks',
    () {
      final result = canvasClipboardMarkdown(
        payload([
          {'type': 'image', 'contentRef': 'Attachments/a b.png', 'text': 'A'},
          {'type': 'card', 'objectId': 'task-1', 'text': 'Task'},
          {'type': 'sticky', 'text': 'Details'},
        ]),
      );
      expect(
        result,
        '![A](<Attachments/a b.png>)\n\n[[task-1|Task]]\n\nDetails',
      );
    },
  );
  test('malformed and unrepresentable Canvas payloads remain literal', () {
    expect(canvasClipboardMarkdown('$canvasClipboardPrefix{broken'), isNull);
    expect(
      canvasClipboardMarkdown(
        payload([
          {'type': 'ink'},
        ]),
      ),
      isNull,
    );
    expect(
      canvasClipboardMarkdown(
        payload([
          {'type': 'image', 'contentRef': 'a>\n![x](b)'},
        ]),
      ),
      isNull,
    );
  });
  test(
    'note clipboard reader recognizes Canvas before optional HTML',
    () async {
      clipboard = payload([
        {'type': 'image', 'contentRef': 'Attachments/a.png', 'text': 'A'},
      ]);
      expect(await readMarkdownClipboard(), '![A](<Attachments/a.png>)');
    },
  );

  Future<void> command(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  late String body;
  late StateSetter updateNote;
  Future<void> note(WidgetTester tester) async {
    body = '![Diagram](<../Attachments/a.png>)\n\nKeep this';
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: orbitDarkTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) {
              updateNote = update;
              return NoteEditor(
                noteId: 'note',
                title: 'Note',
                body: body,
                onTitleChanged: (_) {},
                onBodyChanged: (v) => update(() => body = v),
                linkTargets: const [],
                onOpenObject: (_) {},
                resolveClipboardImage: (v) => v.replaceFirst('../', ''),
                imageBuilder: (_, uri) => const SizedBox(
                  width: 250,
                  height: 120,
                  child: Center(child: Text('Image preview')),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'click image, cut, undo; Canvas paste repeats linked image and undo',
    (tester) async {
      await note(tester);
      final original = body;
      await tester.tap(find.text('Image preview'));
      await tester.pumpAndSettle();
      await command(tester, LogicalKeyboardKey.keyX);
      expect(body, isNot(contains('![Diagram]')));
      expect(body, contains('Keep this'));
      expect(clipboard, contains('Attachments/a.png'));
      expect(clipboard, isNot(contains('../')));
      await command(tester, LogicalKeyboardKey.keyZ);
      expect(body, original);

      Map<String, dynamic> data = {'schemaVersion': 1, 'elements': []};
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'board',
              data: data,
              onChanged: (v) => data = v,
              objects: const [
                CanvasObjectReference(
                  id: 'image-object',
                  title: 'Diagram',
                  typeId: 'orbit.file',
                  properties: {
                    'contentRef': 'Attachments/a.png',
                    'mimeType': 'image/png',
                  },
                ),
              ],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final surface = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
      );
      await tester.tap(surface);
      await command(tester, LogicalKeyboardKey.keyV);
      final first = (data['elements'] as List).single as Map;
      expect(first['type'], 'image');
      expect(first['contentRef'], 'Attachments/a.png');
      expect(first['objectId'], 'image-object');
      await command(tester, LogicalKeyboardKey.keyV);
      expect(data['elements'], hasLength(2));
      expect((data['elements'] as List).last['id'], isNot(first['id']));
      await command(tester, LogicalKeyboardKey.keyZ);
      expect(data['elements'], hasLength(1));
      await tester.tap(surface);
      await command(tester, LogicalKeyboardKey.keyX);
      expect(data['elements'], isEmpty);
      expect(await readMarkdownClipboard(), '![Diagram](<Attachments/a.png>)');
      await command(tester, LogicalKeyboardKey.keyZ);
      expect(data['elements'], hasLength(1));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'clipboard failure and pending cut never remove changed note content',
    (tester) async {
      await note(tester);
      final original = body;
      await tester.tap(find.text('Image preview'));
      fail = true;
      await command(tester, LogicalKeyboardKey.keyX);
      expect(body, original);
      fail = false;
      pending = Completer<void>();
      await tester.tap(find.text('Image preview'));
      await command(tester, LogicalKeyboardKey.keyX);
      updateNote(() => body = '$original\n\nNew edit');
      await tester.pumpAndSettle();
      pending!.complete();
      await tester.pumpAndSettle();
      expect(body, contains('![Diagram]'));
      expect(body, contains('New edit'));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'Source paste at a caret converts Canvas data; undo restores source',
    (tester) async {
      await note(tester);
      await tester.tap(find.text('Source'));
      await tester.pumpAndSettle();
      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == body,
      );
      await tester.tap(field);
      final controller = tester.widget<TextField>(field).controller!;
      controller.selection = const TextSelection.collapsed(offset: 0);
      final original = body;
      clipboard = payload([
        {'type': 'image', 'text': 'Other', 'contentRef': 'Attachments/b.png'},
      ]);
      await command(tester, LogicalKeyboardKey.keyV);
      expect(body, startsWith('![Other](<Attachments/b.png>)'));
      expect(body, isNot(contains(canvasClipboardPrefix)));
      await command(tester, LogicalKeyboardKey.keyZ);
      expect(body, original);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  test('note object links create linked cards, not duplicated objects', () {
    expect(markdownCanvasItems('[[task-1|Task]]'), [
      {'type': 'card', 'objectId': 'task-1', 'text': 'Task'},
    ]);
    expect(
      markdownCanvasItems('A sentence with [[task-1]]').single['type'],
      'sticky',
    );
  });
  testWidgets(
    'Source image cut resolves paths, deletes selection and supports undo',
    (tester) async {
      await note(tester);
      await tester.tap(find.text('Source'));
      await tester.pumpAndSettle();
      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == body,
      );
      await tester.tap(field);
      tester.widget<TextField>(field).controller!.selection = TextSelection(
        baseOffset: 0,
        extentOffset: body.indexOf('\n'),
      );
      final original = body;
      await command(tester, LogicalKeyboardKey.keyX);
      expect(clipboard, '![Diagram](<Attachments/a.png>)');
      expect(body, isNot(contains('![Diagram]')));
      await command(tester, LogicalKeyboardKey.keyZ);
      expect(body, original);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  testWidgets(
    'Canvas content replaces a selected rich image without JSON leakage',
    (tester) async {
      await note(tester);
      await tester.tap(find.text('Image preview'));
      clipboard = payload([
        {'type': 'image', 'text': 'Other', 'contentRef': 'Attachments/b.png'},
      ]);
      await command(tester, LogicalKeyboardKey.keyV);
      expect(body, contains('![Other](<Attachments/b.png>)'));
      expect(body, contains('Keep this'));
      expect(body, isNot(contains(canvasClipboardPrefix)));
      expect(body, isNot(contains('![Diagram]')));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  testWidgets(
    'Canvas paste remaps groups and endpoints; failed cut retains placements',
    (tester) async {
      Map<String, dynamic> data = {
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'a',
            'type': 'sticky',
            'text': 'A',
            'x': 10,
            'y': 10,
            'groupId': 'g',
            'objectId': 'object-a',
          },
          {
            'id': 'b',
            'type': 'sticky',
            'text': 'B',
            'x': 300,
            'y': 10,
            'groupId': 'g',
          },
          {
            'id': 'line',
            'type': 'connector',
            'startId': 'a',
            'endId': 'b',
            'startX': 100,
            'startY': 60,
            'endX': 300,
            'endY': 60,
          },
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'board',
              data: data,
              onChanged: (v) => data = v,
              objects: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final surface = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
      );
      await tester.tap(surface);
      await command(tester, LogicalKeyboardKey.keyA);
      await command(tester, LogicalKeyboardKey.keyC);
      await command(tester, LogicalKeyboardKey.keyV);
      final pasted = (data['elements'] as List).skip(3).cast<Map>().toList();
      expect(pasted, hasLength(3));
      expect(pasted[0]['objectId'], 'object-a');
      expect(pasted[0]['groupId'], pasted[1]['groupId']);
      expect(pasted[0]['groupId'], isNot('g'));
      expect(pasted[2]['startId'], pasted[0]['id']);
      expect(pasted[2]['endId'], pasted[1]['id']);
      expect(pasted[2]['startX'], 132);
      await command(tester, LogicalKeyboardKey.keyZ);
      expect(data['elements'], hasLength(3));
      await command(tester, LogicalKeyboardKey.keyA);
      fail = true;
      await command(tester, LogicalKeyboardKey.keyX);
      expect(data['elements'], hasLength(3));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
