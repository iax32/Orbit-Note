import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/canvas/brainstorm.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/features/canvas/brainstorm_dialog.dart';
import 'package:orbit_note/features/canvas/workshop_dialog.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'support/capture_ui.dart';
import 'package:orbit_note/app/orbit_theme.dart';

CanvasElement sticky(
  String id, {
  int color = 0xff123456,
  Map<String, dynamic> extra = const {},
}) => CanvasElement({
  'id': id,
  'type': 'sticky',
  'x': 30.0,
  'y': 50.0,
  'width': 220.0,
  'height': 180.0,
  'color': color,
  'text': 'Idea $id',
  ...extra,
});
void main() {
  test(
    '200-note color clustering stays bounded and does not overlap notes',
    () {
      final notes = List.generate(
        200,
        (i) => sticky('$i', color: 0xff000000 + i % 8),
      );
      final watch = Stopwatch()..start();
      final moved = clusterBrainstormColors(notes);
      watch.stop();
      expect(moved, hasLength(200));
      for (var i = 0; i < moved.length; i++) {
        for (var j = i + 1; j < moved.length; j++) {
          final a = moved[i].bounds, b = moved[j].bounds;
          expect(
            a.left < b.right &&
                a.right > b.left &&
                a.top < b.bottom &&
                a.bottom > b.top,
            false,
          );
        }
      }
      debugPrint('200-note clustering: ${watch.elapsedMicroseconds} us');
    },
  );
  test(
    'bulk input preserves multiline ideas and refuses partial over-limit input',
    () {
      expect(brainstormIdeas(' One\r\nTwo\n\nThree '), ['One', 'Two', 'Three']);
      expect(brainstormIdeas('One\ncontinued\n\nTwo', paragraphs: true), [
        'One\ncontinued',
        'Two',
      ]);
      expect(
        () => brainstormIdeas(List.filled(201, 'Idea').join('\n')),
        throwsFormatException,
      );
      expect(() => brainstormIdeas('x' * 2001), throwsFormatException);
      var id = 0;
      final items = createBrainstormStickies(
        ['x' * 700, 'Second', 'Third'],
        () => '${id++}',
        origin: const CanvasPoint(0, 0),
        color: 0xff123456,
        columns: 2,
      );
      expect(items, hasLength(3));
      expect(items.last.y, greaterThan(items.first.height));
      expect(
        () => createBrainstormStickies(
          ['A', 'B'],
          () => 'same',
          origin: const CanvasPoint(0, 0),
          color: 0,
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'clusters retain IDs metadata votes and locked/container positions through history and restart',
    () {
      final items = [
        sticky(
          'a',
          extra: {
            'future': {'keep': true},
            'workshopVotes': 4,
          },
        ),
        sticky('b', color: 0xff654321),
        sticky('c'),
        sticky('locked', extra: {'locked': true}),
        sticky('group', extra: {'groupId': 'g'}),
        sticky('column', extra: {'columnId': 'col'}),
      ];
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': items.map((e) => e.data).toList(),
      });
      final original = jsonEncode(scene.toJson());
      final history = CanvasHistory(scene);
      final moved = clusterBrainstormColors(scene.elements);
      expect(moved.map((e) => e.id).toSet(), {'a', 'b', 'c'});
      scene.batch(() {
        for (final e in moved) {
          history.put(e);
        }
      });
      history.commit();
      expect(scene['a']!.data['future'], {'keep': true});
      expect(scene['locked']!.x, 30);
      final restored = CanvasScene.fromJson(
        jsonDecode(jsonEncode(scene.toJson())) as Map<String, dynamic>,
      );
      expect(brainstormVotes(restored['a']!), 4);
      expect(restored['a']!.data, scene['a']!.data);
      history.undo();
      expect(jsonEncode(scene.toJson()), original);
      history.redo();
      expect(scene['a']!.data, moved.singleWhere((e) => e.id == 'a').data);
    },
  );
  test(
    'CSV retains quotes line breaks and scores and neutralizes spreadsheet formulas',
    () {
      final csv = brainstormCsv([
        sticky('a', extra: {'text': '=1+1', 'workshopVotes': 3}),
        sticky('b', extra: {'text': '"Quoted"\nMultiline'}),
      ]);
      expect(csv, contains('"\'=1+1"'));
      expect(csv, contains('""Quoted""\nMultiline'));
      expect(csv, contains('"3"'));
    },
  );
  testWidgets(
    'bulk and workshop controls tolerate narrow enlarged text and cancel timers on close',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          builder: (c, w) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(2)),
            child: w!,
          ),
          home: const BrainstormDialog(),
        ),
      );
      await t.enterText(find.byType(TextField), 'A\nB\nC');
      await t.pumpAndSettle();
      expect(find.textContaining('3 sticky notes'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(
        MaterialApp(
          builder: (c, w) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(2)),
            child: w!,
          ),
          home: WorkshopDialog(notes: [sticky('a')], onLocate: (_) {}),
        ),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Start timer'));
      await t.pumpAndSettle();
      await t.tap(find.text('Start timer'));
      await t.pump();
      expect(find.text('Pause timer'), findsOneWidget);
      await t.scrollUntilVisible(
        find.byTooltip('Add vote to idea 1'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pump();
      await t.tap(find.byTooltip('Add vote to idea 1'));
      await t.pump();
      expect(find.text('1 vote'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 2));
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('bulk insertion is one undo and redo batch in the real Canvas', (
    t,
  ) async {
    await prepareCapture(t);
    await t.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    Map<String, dynamic> latest = {'schemaVersion': 1, 'elements': []};
    var writes = 0;
    await t.pumpWidget(
      RepaintBoundary(
        child: MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'board',
              data: latest,
              onChanged: (v) {
                latest = v;
                writes++;
              },
              objects: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.byTooltip('Brainstorming & workshops'));
    await t.tap(find.byTooltip('Brainstorming & workshops'));
    await t.pumpAndSettle();
    await t.tap(find.text('Bulk sticky notes…'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'One\nTwo\nThree');
    await t.pump();
    await captureUi(t, 'brainstorm-bulk');
    await t.tap(find.text('Add sticky notes'));
    await t.pumpAndSettle();
    expect((latest['elements'] as List).length, 3);
    await t.ensureVisible(find.byTooltip('Undo (Ctrl+Z)'));
    await t.tap(find.byTooltip('Undo (Ctrl+Z)'));
    await t.pumpAndSettle();
    expect(latest['elements'], isEmpty);
    await t.tap(find.byTooltip('Redo (Ctrl+Shift+Z)'));
    await t.pumpAndSettle();
    expect((latest['elements'] as List).length, 3);
    await t.tap(find.byTooltip('Brainstorming & workshops'));
    await t.pumpAndSettle();
    await t.tap(find.text('Workshop timer & voting…'));
    await t.pumpAndSettle();
    await captureUi(t, 'brainstorm-workshop');
    await t.tap(find.byTooltip('Add vote to idea 1'));
    await t.pump();
    await t.tap(find.text('Save vote tallies'));
    await t.pumpAndSettle();
    expect((latest['elements'] as List).first['workshopVotes'], 1);
    await t.tap(find.byTooltip('Undo (Ctrl+Z)'));
    await t.pumpAndSettle();
    expect((latest['elements'] as List).first['workshopVotes'], isNull);
    Future<void> cluster() async {
      await t.tap(find.byTooltip('Brainstorming & workshops'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cluster stickies by color'));
      await t.pumpAndSettle();
    }

    await cluster();
    final afterCluster = writes;
    await cluster();
    expect(writes, afterCluster);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'bulk result refuses a switched board and read-only tools stay disabled',
    (t) async {
      await t.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() => t.binding.setSurfaceSize(null));
      var writes = 0;
      Widget app(String id, {bool readOnly = false}) => MaterialApp(
        home: Scaffold(
          body: CanvasEditor(
            canvasId: id,
            data: const {'schemaVersion': 1, 'elements': []},
            readOnly: readOnly,
            onChanged: (_) => writes++,
            objects: const [],
            onOpenObject: (_) {},
          ),
        ),
      );
      await t.pumpWidget(app('first'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byTooltip('Brainstorming & workshops'));
      await t.tap(find.byTooltip('Brainstorming & workshops'));
      await t.pumpAndSettle();
      await t.tap(find.text('Bulk sticky notes…'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Draft idea');
      await t.pump();
      await t.pumpWidget(app('other'));
      await t.pumpAndSettle();
      await t.tap(find.text('Add sticky notes'));
      await t.pumpAndSettle();
      expect(writes, 0);
      expect(find.textContaining('The board changed.'), findsOneWidget);
      await t.tap(find.byTooltip('Brainstorming & workshops'));
      await t.pumpAndSettle();
      await t.tap(find.text('Bulk sticky notes…'));
      await t.pumpAndSettle();
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        'Draft idea',
      );
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      await t.pumpWidget(app('other', readOnly: true));
      await t.pumpAndSettle();
      final menu = t.widget<PopupMenuButton<String>>(
        find.byWidgetPredicate(
          (w) =>
              w is PopupMenuButton<String> &&
              w.tooltip == 'Brainstorming & workshops',
        ),
      );
      expect(menu.enabled, true);
      await t.tap(find.byTooltip('Brainstorming & workshops'));
      await t.pumpAndSettle();
      final bulk = t.widget<PopupMenuItem<String>>(
        find.byWidgetPredicate(
          (w) => w is PopupMenuItem<String> && w.value == 'bulk',
        ),
      );
      final csv = t.widget<PopupMenuItem<String>>(
        find.byWidgetPredicate(
          (w) => w is PopupMenuItem<String> && w.value == 'csv',
        ),
      );
      expect(bulk.enabled, false);
      expect(csv.enabled, true);
    },
  );
}
