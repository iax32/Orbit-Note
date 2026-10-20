import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/domain/note_writing_appearance.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/note_writing_surface.dart';

Widget editor({
  String id = 'one',
  String body = 'Keep **this** and 🌙.\n\nSecond paragraph.',
  Map<String, dynamic> view = const {},
  ValueChanged<Map<String, dynamic>>? onView,
  ValueChanged<String>? onBody,
  bool readOnly = false,
  double scale = 1,
}) => MaterialApp(
  theme: ThemeData.dark(),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(
      body: NoteEditor(
        noteId: id,
        title: 'Notes',
        body: body,
        onTitleChanged: (_) {},
        onBodyChanged: onBody ?? (_) {},
        onOpenObject: (_) {},
        linkTargets: const [],
        viewOnly: readOnly,
        initialViewState: view,
        onViewStateChanged: onView,
      ),
    ),
  ),
);

Future<void> choose(WidgetTester tester, WritingDesign design) async {
  await tester.tap(find.byKey(const ValueKey('note-appearance-button')));
  await tester.pumpAndSettle();
  final tile = find.byKey(ValueKey('writing-design-${design.name}'));
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'preferences validate future and malformed values, preserving unknown fields',
    () {
      for (final data in [
        null,
        false,
        [],
        {'version': 9, 'design': 'crt'},
      ]) {
        expect(
          NoteWritingAppearance.fromData(data).design,
          WritingDesign.orbit,
        );
      }
      final malformed = NoteWritingAppearance.fromData({
        'version': 1,
        'design': 'future',
        'paper': 'future',
        'spacing': double.nan,
      });
      expect(malformed.spacing, 32);
      expect(malformed.paper, WritingPaper.plain);
      final saved = const NoteWritingAppearance(design: WritingDesign.crt)
          .toData(
            original: {
              'unknown': {
                'nested': [1, 'keep'],
              },
            },
          );
      expect(saved['unknown'], {
        'nested': [1, 'keep'],
      });
      final session = SessionState(
        noteViews: {
          'primary:one': {'writingAppearance': saved},
        },
      );
      final reopened = SessionState.fromJson(
        jsonDecode(jsonEncode(session.toJson())),
      );
      expect(reopened.noteViews['primary:one']!['writingAppearance'], saved);
    },
  );

  test('designs provide readable ink on light and dark paper', () {
    double ratio(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
    }

    for (final base in [ThemeData.light(), ThemeData.dark()]) {
      for (final design in WritingDesign.values) {
        final scheme = writingSurfaceTheme(
          NoteWritingAppearance(design: design),
          base,
        ).colorScheme;
        expect(
          ratio(scheme.onSurface, scheme.surface),
          greaterThan(7),
          reason: design.name,
        );
        expect(
          ratio(scheme.onSurfaceVariant, scheme.surface),
          greaterThan(4.5),
          reason: design.name,
        );
      }
    }
  });

  testWidgets(
    'apply preserves native source selection and content and restores via view state',
    (tester) async {
      Map<String, dynamic> saved = {};
      var writes = 0;
      const body = 'Keep **this** and 🌙.\n\nSecond paragraph.';
      await tester.pumpWidget(
        editor(
          view: {'mode': 'write'},
          onView: (v) => saved = v,
          onBody: (_) => writes++,
        ),
      );
      await tester.pumpAndSettle();
      final source = tester
          .widget<TextField>(find.byKey(const ValueKey('note-body')))
          .controller!;
      source.selection = const TextSelection(baseOffset: 5, extentOffset: 13);
      await choose(tester, WritingDesign.pixelBook);
      await tester.ensureVisible(
        find.byKey(const ValueKey('writing-paper-grid')),
      );
      await tester.tap(find.byKey(const ValueKey('writing-paper-grid')));
      await tester.tap(find.byKey(const ValueKey('writing-apply')));
      await tester.pumpAndSettle();
      final after = tester
          .widget<TextField>(find.byKey(const ValueKey('note-body')))
          .controller!;
      expect(identical(after, source), isTrue);
      expect(
        after.selection,
        const TextSelection(baseOffset: 5, extentOffset: 13),
      );
      expect(after.text, body);
      expect(writes, 0);
      expect(saved['writingAppearance']['design'], 'pixelBook');
      final state = SessionState.fromJson(
        jsonDecode(
          jsonEncode(SessionState(noteViews: {'one': saved}).toJson()),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(editor(view: state.noteViews['one']!));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<NoteWritingSurface>(find.byType(NoteWritingSurface).first)
            .appearance
            .paper,
        WritingPaper.grid,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('note-body')))
            .style!
            .fontFamily,
        'OrbitPixel',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cancel and unrelated view updates retain unfamiliar appearance',
    (tester) async {
      final future = {
        'version': 12,
        'design': 'future',
        'metadata': [1, 'keep'],
      };
      Map<String, dynamic> saved = {};
      await tester.pumpWidget(
        editor(
          view: {'mode': 'write', 'writingAppearance': future},
          onView: (v) => saved = v,
        ),
      );
      await tester.pumpAndSettle();
      await choose(tester, WritingDesign.crt);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<TextField>(find.byKey(const ValueKey('note-body')))
          .controller!;
      controller.selection = const TextSelection.collapsed(offset: 3);
      await tester.pump();
      expect(saved['writingAppearance'], future);
      expect(
        tester
            .widget<NoteWritingSurface>(find.byType(NoteWritingSurface).first)
            .appearance
            .design,
        WritingDesign.orbit,
      );
    },
  );

  testWidgets('stale picker cannot apply to another note', (tester) async {
    Map<String, dynamic> saved = {};
    await tester.pumpWidget(editor(onView: (v) => saved = v));
    await tester.pumpAndSettle();
    await choose(tester, WritingDesign.crt);
    await tester.pumpWidget(editor(id: 'two', onView: (v) => saved = v));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('writing-apply')));
    await tester.pumpAndSettle();
    expect(saved['writingAppearance'], isNull);
    expect(
      tester
          .widget<NoteWritingSurface>(find.byType(NoteWritingSurface).first)
          .appearance
          .design,
      WritingDesign.orbit,
    );
  });

  testWidgets('read only appearance and reset never write to content', (
    tester,
  ) async {
    var writes = 0;
    await tester.pumpWidget(editor(readOnly: true, onBody: (_) => writes++));
    await tester.pumpAndSettle();
    await choose(tester, WritingDesign.classicBook);
    await tester.tap(find.byKey(const ValueKey('writing-apply')));
    await tester.pumpAndSettle();
    await choose(tester, WritingDesign.retro);
    await tester.tap(find.byKey(const ValueKey('writing-reset')));
    await tester.tap(find.byKey(const ValueKey('writing-apply')));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(
      tester
          .widget<NoteWritingSurface>(find.byType(NoteWritingSurface).first)
          .appearance
          .design,
      WritingDesign.orbit,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('all frames and paper support narrow screens at enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final design in WritingDesign.values) {
      for (final paper in WritingPaper.values) {
        await tester.pumpWidget(
          editor(
            scale: 2,
            view: {
              'mode': 'read',
              'writingAppearance': NoteWritingAppearance(
                design: design,
                paper: paper,
              ).toData(),
            },
          ),
        );
        // Changing the note identity restores the next pane preference.
        await tester.pumpWidget(
          editor(
            id: '${design.name}-${paper.name}',
            scale: 2,
            view: {
              'mode': 'read',
              'writingAppearance': NoteWritingAppearance(
                design: design,
                paper: paper,
              ).toData(),
            },
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${design.name}/${paper.name}',
        );
      }
    }
    await choose(tester, WritingDesign.crt);
    final paper = find.byKey(const ValueKey('writing-paper-grid'));
    await tester.ensureVisible(paper);
    await tester.tap(paper);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('writing-apply')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Alt T opens the recovery control without changing text', (
    tester,
  ) async {
    await tester.pumpWidget(editor(view: {'mode': 'write'}));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-body')));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
    expect(find.text('Writing surface'), findsOneWidget);
    expect(find.byKey(const ValueKey('writing-reset')), findsOneWidget);
  });

  testWidgets(
    'quiet writing restores all editor controls and preserves the draft',
    (tester) async {
      Map<String, dynamic> saved = {};
      var writes = 0;
      await tester.pumpWidget(
        editor(
          view: {'mode': 'write'},
          onView: (v) => saved = v,
          onBody: (_) => writes++,
        ),
      );
      await tester.pumpAndSettle();
      await choose(tester, WritingDesign.classicBook);
      await tester.tap(find.byKey(const ValueKey('writing-apply')));
      await tester.pumpAndSettle();
      expect(saved['writingAppearance']['quiet'], isTrue);
      expect(find.byKey(const ValueKey('note-font-family-menu')), findsNothing);
      final source = tester
          .widget<TextField>(find.byKey(const ValueKey('note-body')))
          .controller!;
      final before = source.value;
      await tester.tap(find.byKey(const ValueKey('note-show-editor-tools')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('note-font-family-menu')),
        findsOneWidget,
      );
      expect(source.value, before);
      expect(saved['writingAppearance']['quiet'], isFalse);
      expect(writes, 0);
    },
  );

  testWidgets('disabled design typography retains the selected custom font', (
    tester,
  ) async {
    await tester.pumpWidget(
      editor(
        view: {
          'mode': 'write',
          'writingAppearance': const NoteWritingAppearance(
            design: WritingDesign.pixelBook,
            styledFont: false,
          ).toData(),
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('note-body')))
          .style!
          .fontFamily,
      'Segoe UI',
    );
  });

  testWidgets('unchanged appearance reuses its theme while typing', (
    tester,
  ) async {
    const appearance = NoteWritingAppearance(design: WritingDesign.crt);
    ThemeData? before, after;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteWritingSurface(
            appearance: appearance,
            child: Builder(
              builder: (context) {
                before = Theme.of(context);
                return const Text('Before');
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteWritingSurface(
            appearance: NoteWritingAppearance.fromData(appearance.toData()),
            child: Builder(
              builder: (context) {
                after = Theme.of(context);
                return const Text('After');
              },
            ),
          ),
        ),
      ),
    );
    expect(identical(before, after), isTrue);
    expect(tester.takeException(), isNull);
  });
}
