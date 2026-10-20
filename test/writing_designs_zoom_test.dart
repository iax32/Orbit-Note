import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/app_zoom.dart';
import 'package:orbit_note/domain/note_writing_appearance.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/note_writing_surface.dart';
import 'package:orbit_note/features/notes/pixel_font_scope.dart';

const additions = [
  WritingDesign.blueprint,
  WritingDesign.fieldJournal,
  WritingDesign.typewriter,
  WritingDesign.amberTerminal,
];

void main() {
  test('new designs and pixel sizing retain unknown preference data', () {
    for (final design in additions) {
      final look = NoteWritingAppearance(
        design: design,
        paper: writingDefaultPaper(design),
        pixelSnap: false,
      );
      final data = jsonDecode(
        jsonEncode(
          look.toData(
            original: {
              'future': ['keep'],
            },
          ),
        ),
      );
      expect(NoteWritingAppearance.fromData(data), look);
      expect(data['future'], ['keep']);
      expect(writingDesignFont(look), isNotNull);
    }
    expect(
      NoteWritingAppearance.fromData({
        'version': 1,
        'design': 'pixelBook',
      }).pixelSnap,
      isTrue,
    );
  });

  test(
    'pixel cells align at every zoom and display density after OS scaling',
    () {
      for (final ratio in [1.0, 1.25, 1.5, 2.0, 3.0]) {
        for (final os in [1.0, 1.3, 2.0]) {
          for (final size in [12.0, 16.0, 20.0, 28.0, 40.0]) {
            double previous = 0;
            for (final zoom in appZoomSteps) {
              final original = TextScaler.linear(os * zoom);
              final scaler = PixelFontTextScaler(original, ratio);
              final physical = scaler.scale(size) * ratio;
              expect(
                physical / 8,
                closeTo((physical / 8).roundToDouble(), 1e-9),
              );
              expect(
                (physical - original.scale(size) * ratio).abs(),
                lessThanOrEqualTo(4.000001),
              );
              expect(physical, greaterThanOrEqualTo(previous));
              previous = physical;
            }
          }
        }
      }
      expect(const PixelFontTextScaler(TextScaler.noScaling, 1).scale(0), 0);
    },
  );

  for (final mode in ['write', 'rich', 'read', 'split']) {
    testWidgets(
      'Ctrl-plus keeps pixel text aligned and note state intact in $mode',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var zoom = 1.0;
        var writes = 0;
        const body = 'Keep these words and emoji 🎮.\n\nSecond paragraph.';
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => StatefulBuilder(
              builder: (context, update) => AppZoom(
                zoom: zoom,
                onChanged: (v) => update(() => zoom = v),
                child: child!,
              ),
            ),
            home: Scaffold(
              body: NoteEditor(
                noteId: 'pixel-zoom',
                title: 'Pixel notebook',
                body: body,
                onTitleChanged: (_) => writes++,
                onBodyChanged: (_) => writes++,
                onOpenObject: (_) {},
                linkTargets: const [],
                initialViewState: {
                  'mode': mode,
                  'writingAppearance': const NoteWritingAppearance(
                    design: WritingDesign.pixelBook,
                  ).toData(),
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final title = tester
            .widget<TextField>(find.byKey(const ValueKey('note-title')))
            .controller!;
        final bodyFields = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              (w.controller?.text.startsWith('Keep these') ?? false),
        );
        TextEditingController? controller;
        EditableTextState? nativeState;
        if (bodyFields.evaluate().isNotEmpty) {
          await tester.tap(bodyFields.first);
          await tester.pumpAndSettle();
          controller = tester.widget<TextField>(bodyFields.first).controller!;
          controller.selection = const TextSelection(
            baseOffset: 5,
            extentOffset: 10,
          );
          nativeState = tester.state<EditableTextState>(
            find.descendant(
              of: bodyFields.first,
              matching: find.byType(EditableText),
            ),
          );
        }
        for (var step = 0; step < 4; step++) {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.equal);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await tester.pumpAndSettle();
          expect(zoom, appZoomSteps[3 + step]);
          final scopes = find.byType(PixelFontScope);
          expect(scopes, findsNWidgets(2));
          for (final element in scopes.evaluate()) {
            final text = find.descendant(
              of: find.byWidget(element.widget),
              matching: find.byType(EditableText),
            );
            if (text.evaluate().isNotEmpty) {
              final native = tester.widget<EditableText>(text.first);
              final physicalSize = MediaQuery.textScalerOf(
                text.evaluate().first,
              ).scale(native.style.fontSize!);
              expect(
                physicalSize / 8,
                closeTo((physicalSize / 8).roundToDouble(), 1e-9),
              );
            }
          }
          if (controller != null) {
            expect(
              tester.widget<TextField>(bodyFields.first).controller,
              same(controller),
            );
            expect(
              tester.state<EditableTextState>(
                find.descendant(
                  of: bodyFields.first,
                  matching: find.byType(EditableText),
                ),
              ),
              same(nativeState),
            );
            expect(
              controller.selection,
              const TextSelection(baseOffset: 5, extentOffset: 10),
            );
          }
          // App chrome keeps the regular zoom scaler, not pixel sizing.
          final button = find.byKey(const ValueKey('note-appearance-button'));
          expect(
            MediaQuery.textScalerOf(button.evaluate().first).scale(16),
            closeTo(16 * zoom, .001),
          );
          expect(title.text, 'Pixel notebook');
          expect(writes, 0);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets(
    'new designs apply with useful paper, cancel and reset preserve text',
    (tester) async {
      Map<String, dynamic> saved = {};
      var writes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditor(
              noteId: 'new-designs',
              title: 'Notes',
              body: 'Keep the draft.',
              onTitleChanged: (_) => writes++,
              onBodyChanged: (_) => writes++,
              onOpenObject: (_) {},
              linkTargets: const [],
              initialViewState: const {'mode': 'write'},
              onViewStateChanged: (v) => saved = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final controller = tester
          .widget<TextField>(find.byKey(const ValueKey('note-body')))
          .controller!;
      for (final design in additions) {
        await tester.tap(find.byKey(const ValueKey('note-appearance-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('writing-reset')));
        await tester.pumpAndSettle();
        final tile = find.byKey(ValueKey('writing-design-${design.name}'));
        await tester.ensureVisible(tile);
        await tester.tap(tile);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('writing-apply')));
        await tester.pumpAndSettle();
        expect(saved['writingAppearance']['design'], design.name);
        expect(
          saved['writingAppearance']['paper'],
          writingDefaultPaper(design).name,
        );
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('note-body')))
              .controller,
          same(controller),
        );
        expect(controller.text, 'Keep the draft.');
      }
      expect(writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pixel sizing opt-out preserves controller and restores continuous zoom',
    (tester) async {
      final key = GlobalKey();
      Map<String, dynamic> saved = {};
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.1)),
            child: Scaffold(
              body: NoteEditor(
                key: key,
                noteId: 'snap',
                title: 'Notes',
                body: 'Unchanged words.',
                onTitleChanged: (_) {},
                onBodyChanged: (_) {},
                onOpenObject: (_) {},
                linkTargets: const [],
                initialViewState: {
                  'mode': 'write',
                  'writingAppearance': const NoteWritingAppearance(
                    design: WritingDesign.pixelBook,
                  ).toData(),
                },
                onViewStateChanged: (v) => saved = v,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('note-body'));
      final controller = tester.widget<TextField>(field).controller!;
      await tester.tap(field);
      controller.selection = const TextSelection(
        baseOffset: 1,
        extentOffset: 6,
      );
      await tester.tap(find.byKey(const ValueKey('note-appearance-button')));
      await tester.pumpAndSettle();
      final option = find.byKey(const ValueKey('writing-pixel-snap'));
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('writing-apply')));
      await tester.pumpAndSettle();
      expect(saved['writingAppearance']['pixelSnap'], false);
      expect(tester.widget<TextField>(field).controller, same(controller));
      expect(
        controller.selection,
        const TextSelection(baseOffset: 1, extentOffset: 6),
      );
      expect(
        MediaQuery.textScalerOf(
          find
              .descendant(of: field, matching: find.byType(EditableText))
              .evaluate()
              .first,
        ).scale(16),
        closeTo(17.6, .001),
      );
    },
  );
}
