import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/shared_text_presence.dart';

void main() {
  for (final mode in ['write', 'rich']) {
    testWidgets(
      '$mode presence is source checked and leaves local selection intact',
      (tester) async {
        const source = 'Alpha **bold** omega 😀\n\nSecond paragraph.';
        final presence = ValueNotifier<List<Map<String, dynamic>>>([
          {
            'objectId': 'note-1',
            'space': 'note',
            'session': 'peer',
            'name': 'Zoë 😀',
            'textHash': sha256.convert(utf8.encode(source)).toString(),
            'textBase': 0,
            'textExtent': 5,
          },
        ]);
        addTearDown(presence.dispose);
        var changes = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NoteEditor(
                noteId: 'note-1',
                title: 'Shared note',
                body: source,
                initialViewState: {'mode': mode},
                remotePresence: presence,
                onTitleChanged: (_) {},
                onBodyChanged: (_) => changes++,
                linkTargets: const [],
                onOpenObject: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Zoë 😀 · Ln 1, Col 6'), findsOneWidget);
        final fields = tester
            .widgetList<TextField>(find.byType(TextField))
            .where((f) => f.controller?.text.contains('Alpha') == true);
        expect(fields, isNotEmpty);
        final controller = fields.first.controller!;
        controller.selection = const TextSelection(
          baseOffset: 1,
          extentOffset: 3,
        );
        await tester.pump();
        final local = controller.selection;
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is CustomPaint &&
                (w.foregroundPainter is SharedTextPresencePainter ||
                    w.painter is SharedTextPresencePainter),
          ),
          findsWidgets,
        );
        presence.value = [
          {...presence.value.single, 'textHash': 'stale-source'},
        ];
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Zoë 😀 · updating position'),
          findsOneWidget,
        );
        expect(controller.selection, local);
        expect(changes, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('presence labels wrap at narrow width and large text', (
    tester,
  ) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final presence = ValueNotifier<List<Map<String, dynamic>>>([
      for (var i = 0; i < 4; i++)
        {
          'objectId': 'note',
          'space': 'note',
          'session': 'peer$i',
          'name': 'Collaborator $i',
        },
    ]);
    addTearDown(presence.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 900),
            textScaler: TextScaler.linear(1.8),
          ),
          child: Scaffold(
            body: NoteEditor(
              noteId: 'note',
              title: 'Shared',
              body: 'Hello',
              initialViewState: const {'mode': 'write'},
              remotePresence: presence,
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
    expect(find.textContaining('Collaborator 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
