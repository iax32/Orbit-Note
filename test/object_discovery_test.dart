import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/object_discovery.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/features/workspace/workspace_views.dart';
import 'support/memory_store.dart';

UniversalObject item(
  String title, {
  String type = 'orbit.note',
  Map<String, dynamic> properties = const {},
}) => UniversalObject(
  id: title,
  workspaceId: 'vault',
  typeId: type,
  title: title,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  properties: properties,
);

void main() {
  test(
    'quick opening ranks titles, aliases, mixed context and fuzzy names',
    () {
      final note = item(
        'Linear Algebra',
        properties: {
          'aliases': ['Matrices'],
          'project': 'University',
          'folder': 'Math',
        },
      );
      expect(quickOpenRank(note, 'linear algebra'), 0);
      expect(quickOpenRank(note, 'matrices'), 1);
      expect(quickOpenRank(note, 'linear'), 2);
      expect(quickOpenRank(note, 'algebra'), 3);
      expect(quickOpenRank(note, 'University Algebra'), 4);
      expect(quickOpenRank(note, 'lnalg'), 5);
      expect(quickOpenRank(note, 'xyz'), isNull);
      expect(
        quickOpenRank(note.copyWith(deletedAt: DateTime(2026)), 'linear'),
        isNull,
      );
    },
  );
  test('discovery uses real type and project context without changing IDs', () {
    expect(objectKindLabel(item('photo.png', type: 'orbit.file')), 'File');
    expect(objectKindLabel(item('paper.PDF', type: 'orbit.file')), 'PDF');
    expect(
      objectKindLabel(item('Proof', properties: {'documentFormat': 'latex'})),
      'LaTeX document',
    );
    expect(
      objectContextLabel(
        item('Plan', properties: {'project': 'Orbit', 'folder': 'Design'}),
      ),
      'Note · Orbit · Design',
    );
  });
  testWidgets('search shows loading, context and visual type scope', (
    tester,
  ) async {
    final repo = WorkspaceRepository(
      store: MemoryStore(),
      index: MemoryObjectIndex(),
    );
    await repo.initialize();
    final controller = WorkspaceController()..repository = repo;
    final note = await repo.create(typeId: 'orbit.note', title: 'Orbit design');
    final task = await repo.create(typeId: 'orbit.task', title: 'Orbit review');
    controller.objects = [note, task];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SearchView(controller: controller)),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Orbit');
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No matches'), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('Orbit design'), findsOneWidget);
    expect(find.text('Orbit review'), findsOneWidget);
    await tester.tap(find.byTooltip('Filter by type'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Task'));
    await tester.pumpAndSettle();
    expect(find.text('Orbit design'), findsNothing);
    expect(find.text('Orbit review'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Orbit design'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
