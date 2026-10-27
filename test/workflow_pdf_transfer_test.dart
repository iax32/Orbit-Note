import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/pdf/pdf_reader.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:pdfrx/pdfrx.dart';
import 'support/pdf_fixture.dart';

void main() {
  testWidgets(
    'native PDF keyboard copy pastes a sourced quote into Source with Undo',
    (t) async {
      await t.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.runAsync(() async {
        expect(await initPdfTesting(), true);
      });
      var clipboard = '', body = '';
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
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
        messenger.setMockMethodCallHandler(
          const MethodChannel('pasteboard'),
          null,
        );
      });
      Future<void> until(bool Function() ready) async {
        for (var i = 0; i < 150 && !ready(); i++) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await t.pump(const Duration(milliseconds: 20));
        }
        expect(ready(), true);
      }

      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrbitPdfReader(
              objectId: 'lecture',
              title: 'Lecture PDF',
              loadBytes: () async => researchPdf(),
              onOpenOriginal: () {},
              onOpenExternal: (_) {},
              onReadingState: (_, _) {},
              onQuote: (_, _) async {},
              onBookmarks: (_) {},
            ),
          ),
        ),
      );
      await until(
        () =>
            find.byType(PdfViewer).evaluate().isNotEmpty &&
            t.widget<PdfViewer>(find.byType(PdfViewer)).controller!.isReady,
      );
      final viewer = t.widget<PdfViewer>(find.byType(PdfViewer));
      await t.runAsync(
        () => viewer.controller!.textSelectionDelegate.selectAllText(),
      );
      await t.pump();
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      expect(
        viewer.params.onKey!(
          const PdfViewerKeyHandlerParams(),
          LogicalKeyboardKey.keyC,
          true,
        ),
        true,
      );
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await until(() => clipboard.isNotEmpty);
      expect(clipboard, isNot(contains('[[lecture')));
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => NoteEditor(
                noteId: 'note',
                title: 'Research',
                body: body,
                initialViewState: const {'mode': 'source'},
                spellCheckEnabled: false,
                onTitleChanged: (_) {},
                onBodyChanged: (v) => update(() => body = v),
                onOpenObject: (_) {},
                linkTargets: const [],
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final editor = find
          .byWidgetPredicate((w) => w is EditableText && w.maxLines == null)
          .first;
      await t.tap(editor);
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyV);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pumpAndSettle();
      expect(find.text('Paste PDF text'), findsOneWidget);
      await t.tap(find.text('Linked quote with page source'));
      await t.pumpAndSettle();
      expect(body, contains('[[lecture#page=1|Lecture PDF · p. 1]]'));
      expect(body, contains('> '));
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pumpAndSettle();
      expect(body, isEmpty);
      expect(t.takeException(), null);
    },
  );
}
