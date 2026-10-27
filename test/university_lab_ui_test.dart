import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/university/university_lab_dialog.dart';
import 'package:orbit_note/domain/university/lab_document.dart';
import 'package:orbit_note/domain/university/lab_presets.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/canvas/university_diagram.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'support/capture_ui.dart';
import 'canvas_transfer_quality_test.dart' as canvas;

void main() {
  for (final kind in UniversityLabKind.values) {
    testWidgets('${kind.name} lab runs and returns a recoverable model', (
      t,
    ) async {
      await t.binding.setSurfaceSize(const Size(1400, 1000));
      await prepareCapture(t);
      addTearDown(() => t.binding.setSurfaceSize(null));
      UniversityDocument? result;
      await t.pumpWidget(
        MaterialApp(
          theme: orbitTheme(preset: 'paper'),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showUniversityLab(
                    context,
                    initial: universityPreset(kind),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      await t.tap(find.text('Run / check'));
      await t.pumpAndSettle();
      await captureUi(
        t,
        'university-${kind.name}',
        target: find.byKey(const ValueKey('university-lab-capture')),
      );
      expect(t.takeException(), isNull);
      await t.tap(find.text('Save to note / Canvas'));
      await t.pumpAndSettle();
      expect(result?.kind, kind);
      expect(result?.report(), isNotEmpty);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
    'compact 200 percent text keeps lab actions reachable and invalid JSON cannot save',
    (t) async {
      await t.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(body: UniversityLabDialog()),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final vars = find.widgetWithText(
        TextField,
        'Initial variables · JSON object',
      );
      await t.ensureVisible(vars);
      await t.enterText(vars, '{');
      await t.pumpAndSettle();
      final events = find.widgetWithText(
        TextField,
        'Event sequence · space or comma separated',
      );
      await t.ensureVisible(events);
      await t.enterText(events, 'open');
      await t.pumpAndSettle();
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save to note / Canvas'),
            )
            .onPressed,
        isNull,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Rich note displays a compact model card and reopens its saved lab',
    (t) async {
      await t.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      var body = universityPreset(
        UniversityLabKind.state,
      ).applyTo('# Exercise');
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, set) => NoteEditor(
                noteId: 'uni',
                title: 'Exercise',
                body: body,
                onBodyChanged: (v) => set(() => body = v),
                onTitleChanged: (_) {},
                onOpenObject: (_) {},
                linkTargets: const [],
                spellCheckEnabled: false,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('University Lab · editable model'), findsOneWidget);
      await t.tap(find.text('University Lab · editable model'));
      await t.pumpAndSettle();
      expect(find.byType(UniversityLabDialog), findsOneWidget);
      await t.tap(find.text('Save to note / Canvas'));
      await t.pumpAndSettle();
      expect(
        UniversityDocument.fromMarkdown(body)?.kind,
        UniversityLabKind.state,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Canvas reopens a selected model and saves with one undoable edit',
    (t) async {
      await t.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      var i = 0;
      final elements = universityDiagram(
        universityPreset(UniversityLabKind.state),
        () => 'e${i++}',
        const CanvasPoint(60, 90),
      );
      final frame = elements.first.copy({
        'universityGeneratedIds': elements.skip(1).map((e) => e.id).toList(),
      });
      var data = <String, dynamic>{
        'schemaVersion': 1,
        'elements': [
          frame.data,
          ...elements.skip(1).map((e) => e.data),
          {
            'id': 'free-addition',
            'groupId': frame.id,
            'type': 'sticky',
            'x': 100.0,
            'y': 800.0,
            'width': 200.0,
            'height': 150.0,
            'text': 'Keep my free note',
          },
        ],
      };
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'uni-board',
              data: data,
              onChanged: (v) => data = v,
              objects: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final before = jsonEncode(data['elements']);
      await t.tapAt(canvas.at(t, const CanvasPoint(0, 0)));
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyA);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pump();
      await t.tap(
        find.byTooltip(
          'University Lab · state/activity diagrams, tests and distributed systems',
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(UniversityLabDialog), findsOneWidget);
      await t.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Updated university diagram',
      );
      await t.tap(find.text('Save to note / Canvas'));
      await t.pumpAndSettle();
      expect(
        (data['elements'] as List).where((e) => e['universityModel'] is Map),
        hasLength(1),
      );
      expect(
        (data['elements'] as List).where((e) => e['id'] == 'free-addition'),
        hasLength(1),
      );
      expect(
        (data['elements'] as List)
            .where((e) => e['universityModel'] is Map)
            .single['id'],
        frame.id,
      );
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pumpAndSettle();
      expect(jsonEncode(data['elements']), before);
      expect(t.takeException(), isNull);
    },
  );
}
