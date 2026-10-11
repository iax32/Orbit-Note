import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';
import 'package:orbit_note/domain/object_reference.dart';
import 'package:orbit_note/application/workspace_search.dart';
import 'package:orbit_note/domain/universal_object.dart';

void main() {
  test(
    'preferences delegate retains flat settings, unknown fields and workspace ownership',
    () {
      final original = SessionState(
        fontSize: 19,
        accentColor: 'teal',
        tabs: ['note'],
        activeId: 'note',
        colorOverrides: {'future': 0xff101010},
        noteViews: {
          'primary:note': {'base': 4, 'future': true},
        },
      ).toJson();
      final decoded = SessionState.fromJson({
        ...original,
        'futureSettings': {
          'keep': [1, 2],
        },
      });
      expect(decoded.preferences.fontSize, 19);
      decoded.preferences.fontSize = 21;
      expect(decoded.fontSize, 21);
      decoded.motion = 'reduced';
      expect(decoded.preferences.motion, 'reduced');
      final saved = decoded.toJson();
      expect(saved['tabs'], ['note']);
      expect(saved['noteViews'], original['noteViews']);
      expect(saved['colorOverrides'], original['colorOverrides']);
      expect(saved['futureSettings'], {
        'keep': [1, 2],
      });
      expect(saved.containsKey('preferences'), isFalse);
      expect(SessionState.fromJson(saved).fontSize, 21);
      expect(SessionState.fromJson({}).fontSize, 16);
    },
  );
  test('10k spatial queries equal brute force through incremental changes', () {
    final index = CanvasSpatialIndex();
    final bounds = <String, CanvasBounds>{};
    final random = Random(73);
    for (var i = 0; i < 10000; i++) {
      final b = CanvasBounds(
        random.nextDouble() * 20000 - 10000,
        random.nextDouble() * 20000 - 10000,
        i % 13 == 0 ? 0 : 100,
        i % 17 == 0 ? 0 : 80,
      );
      bounds['$i'] = b;
      index.put('$i', b);
    }
    void verify(CanvasBounds query) {
      expect(
        index.query(query),
        bounds.entries
            .where((e) => e.value.intersects(query))
            .map((e) => e.key)
            .toSet(),
      );
    }

    verify(const CanvasBounds(0, 0, 800, 600));
    expect(index.lastCandidateCount, lessThan(1000));
    for (var i = 0; i < 100; i++) {
      final key = '$i';
      final moved = CanvasBounds(i * 32 - 1800, i * 20 - 1800, 150, 100);
      bounds[key] = moved;
      index.put(key, moved);
      verify(CanvasBounds(i * 32 - 1900, i * 20 - 1900, 800, 600));
    }
    for (var i = 0; i < 100; i++) {
      bounds.remove('$i');
      index.remove('$i');
    }
    verify(const CanvasBounds(-2000, -2000, 5000, 5000));
    index.put('giant', const CanvasBounds(-1e12, -1e12, 2e12, 2e12));
    bounds['giant'] = const CanvasBounds(-1e12, -1e12, 2e12, 2e12);
    verify(const CanvasBounds(-1e12, -1e12, 2e12, 2e12));
    verify(const CanvasBounds(1e9, 1e9, 0, 0));
    expect(() => CanvasSpatialIndex(cellSize: 0), throwsArgumentError);
  });
  test(
    'large search projection uses background work without dropping live drafts',
    () async {
      final objects = [
        for (var i = 0; i < 400; i++)
          UniversalObject(
            id: '$i',
            workspaceId: 'w',
            typeId: 'orbit.note',
            title: 'Note $i',
            body: '${'Prose ' * 50}needle $i',
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
      ];
      final draft = objects.first.copyWith(body: 'A different live draft.');
      final results = await projectWorkspaceSearch(
        indexed: objects,
        snapshot: [draft, ...objects.skip(1)],
        drafts: {draft.id},
        query: 'needle',
      );
      expect(results.length, 100);
      expect(results.any((r) => r.object.id == draft.id), isFalse);
      expect(
        results.map((r) => r.object.id),
        orderedEquals(
          (await projectWorkspaceSearch(
            indexed: objects.reversed.toList(),
            snapshot: [draft, ...objects.skip(1)],
            drafts: {draft.id},
            query: 'needle',
          )).map((r) => r.object.id),
        ),
      );
    },
  );
  testWidgets(
    'precise note navigation reaches a rich block and repeated requests work',
    (tester) async {
      const body = 'First paragraph.\n\nSecond target paragraph. ^stable\n';
      Widget editor(int serial, {int? offset, int length = 0}) => MaterialApp(
        home: Scaffold(
          body: NoteEditor(
            noteId: 'n',
            title: 'Note',
            body: body,
            onTitleChanged: (_) {},
            onBodyChanged: (_) {},
            linkTargets: const [],
            onOpenObject: (_) {},
            location: const ObjectReference(
              'n',
              anchorType: 'block',
              anchorId: 'stable',
            ),
            locationSerial: serial,
            locationOffset: offset,
            locationLength: length,
          ),
        ),
      );
      await tester.pumpWidget(editor(1));
      await tester.pumpAndSettle();
      final state = tester.state<RichMarkdownEditorState>(
        find.byType(RichMarkdownEditor),
      );
      expect(state.currentDocumentSelection.start, body.indexOf('Second'));
      await tester.pumpWidget(
        editor(3, offset: body.indexOf('target'), length: 6),
      );
      await tester.pumpAndSettle();
      expect(state.currentDocumentSelection.textInside(body), 'target');
      await tester.pumpWidget(editor(2));
      await tester.pumpAndSettle();
      expect(state.currentDocumentSelection.start, body.indexOf('Second'));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'canvas element deep target restores camera and tolerates removal',
    (tester) async {
      Map<String, dynamic>? camera;
      Widget editor(bool exists, int serial) => MaterialApp(
        home: Scaffold(
          body: CanvasEditor(
            canvasId: 'board',
            data: {
              'schemaVersion': 1,
              'elements': [
                if (exists)
                  {
                    'id': 'e',
                    'type': 'sticky',
                    'text': 'Target',
                    'x': 5000,
                    'y': 3000,
                    'width': 200,
                    'height': 100,
                  },
              ],
            },
            onChanged: (_) {},
            objects: const [],
            onOpenObject: (_) {},
            focusElementId: 'e',
            locationSerial: serial,
            onCameraChanged: (v) => camera = v,
          ),
        ),
      );
      await tester.pumpWidget(editor(true, 1));
      await tester.pumpAndSettle();
      expect(camera?['x'], greaterThan(4000));
      expect(camera?['y'], greaterThan(2000));
      await tester.pumpWidget(editor(false, 2));
      await tester.pump();
      expect(
        find.text('Canvas element is missing or hidden. The board is open.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
