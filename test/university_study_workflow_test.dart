import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/notes/rich/callout_block.dart';
import 'package:orbit_note/features/workspace/saved_view_host.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/workspace_store.dart';
import 'support/memory_store.dart';

class TestFolderStore extends MemoryStore implements WorkspaceFolderStore {
  final folders = <String>['Notes'];
  @override
  Future<List<String>> listFolders() async => List.of(folders);
  @override
  Future<void> createFolder(String path) async {
    if (!folders.contains(path)) {
      folders.add(path);
    }
  }

  @override
  Future<void> deleteFolder(String path) async {
    folders.remove(path);
    folders.removeWhere((f) => f.startsWith('$path/'));
    files.removeWhere((k, _) => k.startsWith('$path/'));
  }

  @override
  Future<void> movePath(
    String source,
    String target,
    Map<String, FileReplacement> replacements,
  ) async {
    final content = files.remove(source);
    if (content != null) {
      files[target] = content;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('University, Mathematics, and Visual Study Workflows', () {
    late ProviderContainer container;
    late WorkspaceController controller;
    late TestFolderStore store;

    setUp(() async {
      store = TestFolderStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      container.read(workspaceProvider);
      controller = container.read(workspaceProvider.notifier);
      for (var i = 0; i < 100 && controller.loading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
    });

    tearDown(() async {
      await controller.flushAll();
      container.dispose();
    });

    test('Academic Callouts parse new university types and numbering', () {
      final text = '''
> [!THEOREM] 4.1 Fundamental Theorem of Calculus
> Let f be continuous on [a, b]...
''';
      final callout = ParsedCallout.parse(text);
      expect(callout, isNotNull);
      expect(callout.type, CalloutType.theorem);
      expect(callout.title, '4.1 Fundamental Theorem of Calculus');
      expect(
        callout.headerDisplay,
        'Theorem 4.1 Fundamental Theorem of Calculus',
      );

      // Test Corollary without number
      final corollaryText = '''
> [!COROLLARY] Immediate Consequence
> Every differentiable function is continuous.
''';
      final corollary = ParsedCallout.parse(corollaryText);
      expect(corollary, isNotNull);
      expect(corollary.type, CalloutType.corollary);
      expect(corollary.headerDisplay, 'Corollary: Immediate Consequence');

      // Test Question
      final questionText = '''
> [!QUESTION] Unclear Step in Proof
> Why does the sequence converge uniformly?
''';
      final question = ParsedCallout.parse(questionText);
      expect(question, isNotNull);
      expect(question.type, CalloutType.question);
      expect(question.headerDisplay, 'Question: Unclear Step in Proof');
    });

    test(
      'createUniversityCourse creates complete structured course environment',
      () async {
        final course = await controller.createUniversityCourse(
          'AKMath',
          semester: 'WS 2026/27',
          ects: 6,
          lecturer: 'Prof. Dr. Hilbert',
        );

        expect(course, isNotNull);
        expect(course!.title, 'AKMath Overview');
        expect(course.properties['course'], 'AKMath');
        expect(course.properties['semester'], 'WS 2026/27');
        expect(course.properties['ects'], 6);
        expect(course.properties['lecturer'], 'Prof. Dr. Hilbert');
        expect(course.properties['isCourseOverview'], true);

        // Verify folder structure
        expect(store.folders, contains('University/AKMath'));
        expect(store.folders, contains('University/AKMath/Lectures'));
        expect(store.folders, contains('University/AKMath/Exercises'));
        expect(store.folders, contains('University/AKMath/Exam Preparation'));

        // Verify Starter Lecture Note
        final lecture = controller.objects.firstWhere(
          (o) => o.title == 'Lecture 01 - Foundations',
        );
        expect(lecture.properties['folder'], 'University/AKMath/Lectures');
        expect(lecture.properties['course'], 'AKMath');
        expect(lecture.body, contains('[!DEFINITION] 1.1 Fundamental Concept'));
        expect(lecture.body, contains('[!PROOF]'));

        // Verify Starter Exercise Canvas
        final exercise = controller.objects.firstWhere(
          (o) => o.title == 'Exercise 01 - Practice Sheet',
        );
        expect(exercise.typeId, 'orbit.canvas');
        expect(exercise.properties['folder'], 'University/AKMath/Exercises');
        expect(exercise.properties['course'], 'AKMath');
        expect(exercise.properties['exerciseStatus'], 'not_started');
        expect(exercise.properties['difficulty'], 'medium');
        expect(exercise.properties['confidence'], 'medium');
        expect(exercise.properties['backgroundStyle'], 'grid');

        // Verify Scoped Views
        final views = controller.objects
            .where((o) => o.typeId == 'orbit.view')
            .toList();
        expect(views.length, 5);
        final viewTypes = views.map((v) => v.properties['viewType']).toSet();
        expect(
          viewTypes,
          containsAll(['tasks', 'board', 'calendar', 'timeline', 'exercises']),
        );
      },
    );

    test(
      'Exercise properties and practice filters update without duplicate objects',
      () async {
        await controller.createUniversityCourse('DiscreteMath');

        final exercise = controller.objects.firstWhere(
          (o) => o.title == 'Exercise 01 - Practice Sheet',
        );

        // User marks exercise as stuck and sets topic and confidence
        controller.edit(
          exercise.id,
          properties: {
            ...exercise.properties,
            'exerciseStatus': 'stuck',
            'confidence': 'low',
            'topic': 'Equivalence Relations',
            'difficulty': 'hard',
          },
        );

        final updated = controller.find(exercise.id);
        expect(updated, isNotNull);
        expect(updated!.properties['exerciseStatus'], 'stuck');
        expect(updated.properties['confidence'], 'low');
        expect(updated.properties['topic'], 'Equivalence Relations');
        expect(updated.properties['difficulty'], 'hard');

        // Ensure object identity is maintained (single object, no clone)
        final allWithSameTitle = controller.objects.where(
          (o) => o.title == 'Exercise 01 - Practice Sheet',
        );
        expect(allWithSameTitle.length, 1);
      },
    );

    test(
      'Canvas preserves Universal Object identity when dropping objects',
      () async {
        await controller.createUniversityCourse('LinearAlgebra');
        final lecture = controller.objects.firstWhere(
          (o) => o.title == 'Lecture 01 - Foundations',
        );
        final canvas = controller.objects.firstWhere(
          (o) => o.title == 'Exercise 01 - Practice Sheet',
        );

        // Drop lecture card onto the canvas at (150, 200)
        final existingElements = List<dynamic>.from(
          canvas.data['elements'] as List? ?? [],
        );
        final droppedCard = <String, dynamic>{
          'id': 'elem-drop-1',
          'type': 'card',
          'objectId': lecture.id,
          'x': 150.0,
          'y': 200.0,
          'width': 240.0,
          'height': 120.0,
        };
        existingElements.add(droppedCard);

        controller.edit(
          canvas.id,
          data: {...canvas.data, 'elements': existingElements},
        );

        final updatedCanvas = controller.find(canvas.id)!;
        final elements = (updatedCanvas.data['elements'] as List)
            .map((e) => CanvasElement(Map<String, dynamic>.from(e as Map)))
            .toList();

        expect(elements.length, 1);
        expect(elements.first.type, 'card');
        expect(elements.first.objectId, lecture.id);
        expect(elements.first.x, 150);
        expect(elements.first.y, 200);

        // Verify the lecture note itself remains the exact universal object
        expect(
          controller.find(elements.first.objectId!)!.title,
          'Lecture 01 - Foundations',
        );
      },
    );

    testWidgets(
      'SavedViewHost renders ExerciseTableView and CourseDashboardView',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        late UniversalObject exerciseView;
        await tester.runAsync(() async {
          await controller.createUniversityCourse('Calculus');
          exerciseView = controller.objects.firstWhere(
            (o) =>
                o.typeId == 'orbit.view' &&
                o.properties['viewType'] == 'exercises',
          );
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SavedViewHost(
                viewObject: exerciseView,
                controller: controller,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should show Exercise Table View components
        expect(find.text('EXERCISE'), findsOneWidget);
        expect(find.text('TOPIC'), findsOneWidget);
        expect(find.text('STATUS'), findsOneWidget);
        expect(find.text('DIFFICULTY'), findsOneWidget);
        expect(find.text('CONFIDENCE'), findsOneWidget);
        expect(find.text('Exercise 01 - Practice Sheet'), findsOneWidget);

        // Switch to Overview tab
        await tester.runAsync(() async {
          await tester.tap(find.text('Overview'));
        });
        await tester.pumpAndSettle();

        // Should render Course Dashboard View
        expect(find.text('Calculus'), findsWidgets);
        expect(find.text('Exercise Practice Progress'), findsOneWidget);
        expect(find.text('Deadlines & Exam Countdown'), findsOneWidget);
        expect(find.text('Focus Practice Areas & Weak Topics'), findsOneWidget);
      },
    );
  });
}
