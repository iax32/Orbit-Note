import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/notes/media_clipboard.dart';
import 'support/pdf_fixture.dart';
import 'canvas_transfer_quality_test.dart' as canvas;

void main() {
  String clipboard = '';
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String;
      }
      if (call.method == 'Clipboard.getData') {
        return call.arguments == 'text/html' ? null : {'text': clipboard};
      }
      return null;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('pasteboard'),
      (_) async => null,
    );
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(const MethodChannel('pasteboard'), null);
  });
  Future<void> command(WidgetTester t, LogicalKeyboardKey key) async {
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(key);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pumpAndSettle();
  }

  testWidgets(
    'real 30-page PDF text pastes into a large Rich note and survives repeated cut undo redo',
    (t) async {
      await t.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      String extracted = '';
      await t.runAsync(() async {
        expect(await initPdfTesting(), true);
        final pdf = await PdfDocument.openData(
          largeResearchPdf(pageCount: 30, linesPerPage: 10),
        );
        try {
          extracted = [
            for (final page in pdf.pages) (await page.loadText())!.fullText,
          ].join('\r\n');
        } finally {
          await pdf.dispose();
        }
      });
      expect(extracted, contains('Orbit page 30 line 9'));
      var body = List.generate(
        500,
        (i) => 'Large paragraph $i with **formatting** and emoji 🎮.',
      ).join('\n\n');
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => NoteEditor(
                noteId: 'heavy-note',
                title: 'Research',
                body: body,
                spellCheckEnabled: false,
                onBodyChanged: (next) => update(() => body = next),
                onTitleChanged: (_) {},
                onOpenObject: (_) {},
                linkTargets: const [],
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      clipboard = PdfQuoteDragData(
        objectId: 'source-pdf',
        title: 'Native PDF',
        page: 1,
        text: extracted,
      ).markdownQuote;
      t
          .state<RichMarkdownEditorState>(find.byType(RichMarkdownEditor))
          .selectAllBlocks();
      await t.pump();
      await command(t, LogicalKeyboardKey.keyV);
      expect(body, contains('> Orbit page 30 line 9'));
      expect(body, contains('[[source-pdf#page=1|Native PDF · p. 1]]'));
      expect(body, isNot(contains('\r')));
      for (var i = 0; i < 5; i++) {
        final before = body;
        t
            .state<RichMarkdownEditorState>(find.byType(RichMarkdownEditor))
            .selectAllBlocks();
        await t.pump();
        await command(t, LogicalKeyboardKey.keyX);
        expect(body, isEmpty);
        expect(clipboard, contains('Orbit page 30 line 9'));
        await command(t, LogicalKeyboardKey.keyZ);
        expect(body, before);
        await command(t, LogicalKeyboardKey.keyY);
        expect(body, isEmpty);
        expect(
          t
              .state<RichMarkdownEditorState>(find.byType(RichMarkdownEditor))
              .document
              .source,
          isEmpty,
        );
        final fields = t
            .widgetList<TextField>(find.byType(TextField))
            .where((f) => f.focusNode?.hasFocus == true)
            .toList();
        expect(
          fields.map((f) => f.controller?.text.length).toList(),
          everyElement(0),
          reason: 'focused field after redo cycle $i',
        );
        await command(t, LogicalKeyboardKey.keyV);
        expect(
          body.trim().length,
          before.trim().length,
          reason: 'cycle $i clipboard ${clipboard.length}',
        );
        expect(body.trim(), before.trim());
      }
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'large connected Canvas selection moves cuts duplicates and undoes with intact identities',
    (t) async {
      await t.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final source = <Map<String, dynamic>>[
        for (var i = 0; i < 120; i++)
          {
            'id': 'n$i',
            'type': 'sticky',
            'x': 100.0 + i % 12 * 244,
            'y': 140.0 + i ~/ 12 * 204,
            'width': 220.0,
            'height': 180.0,
            'text': 'Idea $i 🎮',
            'future': {'number': i},
          },
        for (var i = 0; i < 60; i++)
          {
            'id': 'edge$i',
            'type': 'connector',
            'startId': 'n$i',
            'endId': 'n${i + 1}',
            'startX': 100.0 + i % 12 * 244,
            'startY': 140.0 + i ~/ 12 * 204,
            'endX': 344.0 + i % 12 * 244,
            'endY': 140.0 + i ~/ 12 * 204,
          },
      ];
      Map<String, dynamic> latest = {'schemaVersion': 1, 'elements': source};
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'heavy-board',
              data: latest,
              onChanged: (v) => latest = v,
              objects: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tapAt(canvas.at(t, const CanvasPoint(130, 170)));
      await command(t, LogicalKeyboardKey.keyA);
      final before = jsonEncode(latest['elements']);
      final point = canvas.at(t, const CanvasPoint(130, 170));
      await t.dragFrom(point, const Offset(48, 32));
      await t.pumpAndSettle();
      expect(jsonEncode(latest['elements']), isNot(before));
      await command(t, LogicalKeyboardKey.keyZ);
      expect(jsonEncode(latest['elements']), before);
      await command(t, LogicalKeyboardKey.keyA);
      await command(t, LogicalKeyboardKey.keyX);
      expect(latest['elements'], isEmpty);
      expect(clipboard, startsWith(canvasClipboardPrefix));
      await command(t, LogicalKeyboardKey.keyZ);
      expect((latest['elements'] as List), hasLength(180));
      for (var cycle = 0; cycle < 3; cycle++) {
        await command(t, LogicalKeyboardKey.keyV);
        final items = (latest['elements'] as List).cast<Map>();
        expect(items, hasLength(360));
        final ids = items.map((e) => e['id']).toSet();
        expect(ids, hasLength(360));
        for (final e in items.where((e) => e['type'] == 'connector')) {
          expect(ids.contains(e['startId']), true);
          expect(ids.contains(e['endId']), true);
        }
        await command(t, LogicalKeyboardKey.keyZ);
        expect((latest['elements'] as List), hasLength(180));
      }
      expect(t.takeException(), isNull);
    },
  );
}
