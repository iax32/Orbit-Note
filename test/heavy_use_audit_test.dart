import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:orbit_note/domain/document_publication.dart';
import 'package:orbit_note/features/canvas/workshop_dialog.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/canvas/brainstorm.dart';
import 'package:orbit_note/features/canvas/brainstorm_dialog.dart';

void main() {
  testWidgets(
    'vote ranking preserves the identity of each row while it moves',
    (t) async {
      await t.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      CanvasElement note(String id, int votes) => CanvasElement({
        'id': id,
        'type': 'sticky',
        'text': 'Idea $id',
        'x': 0,
        'y': 0,
        'width': 220,
        'height': 180,
        'workshopVotes': votes,
      });
      await t.pumpWidget(
        MaterialApp(
          home: WorkshopDialog(
            notes: [note('a', 0), note('b', 2)],
            onLocate: (_) {},
          ),
        ),
      );
      await t.tap(find.text('Show highest votes first'));
      await t.pump();
      final before = t.element(find.text('Idea a'));
      final add = t.widget<IconButton>(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Add vote to idea 2',
        ),
      );
      add.onPressed!();
      add.onPressed!();
      add.onPressed!();
      await t.pump();
      expect(find.text('3 votes'), findsOneWidget);
      expect(identical(before, t.element(find.text('Idea a'))), true);
      await t.pumpWidget(const SizedBox());
    },
  );
  test(
    'CSV snapshot includes locked grouped and column-owned notes without hidden content',
    () {
      CanvasElement note(String id, Map<String, dynamic> flags) =>
          CanvasElement({
            'id': id,
            'type': 'sticky',
            'text': id,
            'x': 0,
            'y': 0,
            'width': 220,
            'height': 180,
            ...flags,
          });
      final notes = [
        note('locked', {'locked': true}),
        note('grouped', {'groupId': 'g'}),
        note('column', {'columnId': 'c'}),
        note('hidden', {'hidden': true}),
      ];
      expect(brainstormExportNotes(notes).map((e) => e.id), [
        'locked',
        'grouped',
        'column',
      ]);
      expect(
        brainstormExportNotes(notes, selection: {'locked'}).single.id,
        'locked',
      );
      expect(
        () => brainstormCsv(List.generate(10001, (i) => note('$i', {}))),
        throwsFormatException,
      );
    },
  );
  test('clustering keeps clear of locked and unselected notes', () {
    CanvasElement note(String id, double x, int color, {bool locked = false}) =>
        CanvasElement({
          'id': id,
          'type': 'sticky',
          'text': id,
          'x': x,
          'y': 0,
          'width': 220,
          'height': 180,
          'color': color,
          'locked': locked,
        });
    final selected = [note('a', 0, 1), note('b', 1000, 2)];
    final fixed = note('locked', 316, 3, locked: true);
    final moved = clusterBrainstormColors(
      selected,
      obstacles: [...selected, fixed],
    );
    expect(moved.every((e) => !e.bounds.intersects(fixed.bounds)), true);
    expect(fixed.x, 316);
  });
  testWidgets(
    'bulk drafts and changed tallies cannot be dismissed accidentally',
    (t) async {
      await t.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const BrainstormDialog(),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Do not lose this idea');
      await t.pump();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(find.text('Discard unapplied changes?'), findsOneWidget);
      await t.tap(find.text('Keep editing'));
      await t.pumpAndSettle();
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        'Do not lose this idea',
      );
      await t.pumpWidget(const SizedBox());
      final note = CanvasElement({
        'id': 'idea',
        'type': 'sticky',
        'text': 'Idea',
        'x': 0,
        'y': 0,
        'width': 220,
        'height': 180,
      });
      await t.pumpWidget(
        MaterialApp(
          home: WorkshopDialog(
            notes: [note],
            onLocate: (_) {},
            canSave: () => false,
          ),
        ),
      );
      await t.tap(find.byTooltip('Add vote to idea 1'));
      await t.pump();
      await t.tap(find.text('Save vote tallies'));
      await t.pumpAndSettle();
      expect(find.text('1 vote'), findsOneWidget);
      expect(find.textContaining('Your tally is still here'), findsOneWidget);
    },
  );
  test(
    'aligned heading does not split a code fence at its internal blank line',
    () {
      const source =
          '<!-- orbit:align=right -->\n# Heading\n```text\nBEFORE_CODE\n\nAFTER_CODE\n```\n\nNormal paragraph';
      final doc = PublicationDocument.parse(
        'Report',
        source,
        const PublicationStyle(),
      );
      final code = doc.nodes
          .whereType<md.Element>()
          .where((e) => e.tag == 'pre')
          .toList();
      expect(code, hasLength(1));
      expect(code.single.textContent, 'BEFORE_CODE\n\nAFTER_CODE\n');
      expect(doc.nodes.last.textContent, 'Normal paragraph');
    },
  );
  test(
    'consecutive alignment comments remain bounded and resolve the final paragraph',
    () {
      final source =
          '${'<!-- orbit:align=justify -->\n' * 1200}Visible paragraph';
      final doc = PublicationDocument.parse(
        'Report',
        source,
        const PublicationStyle(),
      );
      expect(doc.nodes.last.textContent, 'Visible paragraph');
      expect(
        (doc.nodes.last as md.Element).attributes['orbit-text-align'],
        'justify',
      );
    },
  );
  testWidgets(
    'rapid tally actions do not lose increments and timer ticks do not rebuild notes',
    (t) async {
      await t.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final note = CanvasElement({
        'id': 'idea',
        'type': 'sticky',
        'text': 'Stable idea',
        'x': 0,
        'y': 0,
        'width': 220,
        'height': 180,
      });
      await t.pumpWidget(
        MaterialApp(
          home: WorkshopDialog(notes: [note], onLocate: (_) {}),
        ),
      );
      final add = t.widget<IconButton>(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Add vote to idea 1',
        ),
      );
      add.onPressed!();
      add.onPressed!();
      await t.pump();
      expect(find.text('2 votes'), findsOneWidget);
      final before = t.widget<Text>(find.text('Stable idea'));
      await t.tap(find.text('Start timer'));
      await t.pump();
      final running = t.widget<Text>(find.text('Stable idea'));
      await t.pump(const Duration(milliseconds: 500));
      expect(
        identical(running, t.widget<Text>(find.text('Stable idea'))),
        true,
      );
      expect(before.data, running.data);
      await t.pumpWidget(const SizedBox());
    },
  );
}
