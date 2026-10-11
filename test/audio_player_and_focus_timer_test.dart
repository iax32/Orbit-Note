import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_components.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/features/canvas/audio_player_card.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/features/workspace/focus_timer.dart';
import 'package:orbit_note/features/workspace/workspace_views.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';

import 'support/memory_store.dart';

Widget host(Widget child, {String mode = 'normal', bool osReduced = false}) =>
    MaterialApp(
      theme: orbitDarkTheme(),
      home: OrbitMotionScope(
        preference: mode,
        osReduced: osReduced,
        child: Scaffold(body: child),
      ),
    );

void main() {
  group('OrbitAudioPlayerCard Component', () {
    testWidgets('renders title, play button, speed, and mute controls', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const OrbitAudioPlayerCard(
            title: 'Design Critique Voice Memo',
            duration: Duration(minutes: 2, seconds: 30),
            transcript:
                'Discussion on observatory dark theme and motion tokens.',
          ),
        ),
      );

      expect(find.text('Design Critique Voice Memo'), findsOneWidget);
      expect(find.byKey(const ValueKey('audio-play-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('audio-speed-button')), findsOneWidget);
      expect(find.text('1.0x'), findsOneWidget);
      expect(find.byKey(const ValueKey('audio-mute-button')), findsOneWidget);
      expect(find.text('0:00 / 2:30'), findsOneWidget);
      expect(find.text('Transcript'), findsOneWidget);
    });

    testWidgets('play button toggles playback state and icon', (tester) async {
      bool? isPlaying;
      await tester.pumpWidget(
        host(
          OrbitAudioPlayerCard(
            title: 'Voice Note',
            duration: const Duration(seconds: 10),
            onPlayPause: (val) => isPlaying = val,
          ),
        ),
      );

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('audio-play-button')));
      await tester.pump();

      expect(isPlaying, isTrue);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('audio-play-button')));
      await tester.pump();

      expect(isPlaying, isFalse);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('speed button cycles through playback speeds', (tester) async {
      await tester.pumpWidget(
        host(const OrbitAudioPlayerCard(title: 'Lecture Note')),
      );

      expect(find.text('1.0x'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('audio-speed-button')));
      await tester.pump();
      expect(find.text('1.25x'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('audio-speed-button')));
      await tester.pump();
      expect(find.text('1.5x'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('audio-speed-button')));
      await tester.pump();
      expect(find.text('2.0x'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('audio-speed-button')));
      await tester.pump();
      expect(find.text('1.0x'), findsOneWidget);
    });

    testWidgets(
      'transcript toggle expands and reveals transcription with copy',
      (tester) async {
        await tester.pumpWidget(
          host(
            const OrbitAudioPlayerCard(
              title: 'Voice Note',
              transcript:
                  'Offline-first SQLite contract and markdown authority.',
            ),
          ),
        );

        // Initially closed
        expect(find.text('TRANSCRIPTION'), findsNothing);

        // Tap toggle
        await tester.tap(find.byKey(const ValueKey('audio-transcript-toggle')));
        await tester.pumpAndSettle();

        expect(find.text('TRANSCRIPTION'), findsOneWidget);
        expect(
          find.text('Offline-first SQLite contract and markdown authority.'),
          findsOneWidget,
        );
        expect(find.text('Copy'), findsOneWidget);
      },
    );
  });

  group('Canvas Audio Element & Painting', () {
    test('canvasElementTypes contains audio', () {
      expect(canvasElementTypes.contains('audio'), isTrue);
    });

    test('CanvasElement creates renderable audio element', () {
      final audioEl = CanvasElement({
        'id': 'audio-1',
        'type': 'audio',
        'x': 50.0,
        'y': 50.0,
        'width': 280.0,
        'height': 90.0,
        'text': 'Sprint Review Memo',
        'duration': '2:15',
        'progress': 0.45,
      });

      expect(audioEl.renderable, isTrue);
      expect(audioEl.type, 'audio');
      expect(audioEl.text, 'Sprint Review Memo');
    });

    testWidgets('OrbitCanvasPainter paints audio card without errors', (
      tester,
    ) async {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'audio-test',
            'type': 'audio',
            'x': 20.0,
            'y': 20.0,
            'width': 280.0,
            'height': 90.0,
            'text': 'Field Recording',
            'duration': '1:30',
            'progress': 0.6,
          },
        ],
      });

      await tester.pumpWidget(
        host(
          CustomPaint(
            size: const Size(600, 400),
            painter: OrbitCanvasPainter(
              textCache: CanvasTextCache(),
              images: const {},
              scene: scene,
              camera: const CanvasCamera(x: 0, y: 0, zoom: 1.0),
              selection: const {},
              objects: const {},
              colors: const ColorScheme.dark(),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    test('renderCanvasToPng renders audio element cleanly', () async {
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'audio-export',
            'type': 'audio',
            'x': 0.0,
            'y': 0.0,
            'width': 280.0,
            'height': 90.0,
            'text': 'Export Audio',
            'duration': '3:45',
            'progress': 0.25,
          },
        ],
      });

      final pngBytes = await renderCanvasToPng(
        scene: scene,
        colors: const ColorScheme.dark(),
        backgroundStyle: 'dots',
        scale: 1.0,
      );

      expect(pngBytes, isNotNull);
      expect(pngBytes!.isNotEmpty, isTrue);
      // PNG header check
      expect(pngBytes[0], 0x89);
      expect(pngBytes[1], 0x50); // P
      expect(pngBytes[2], 0x4E); // N
      expect(pngBytes[3], 0x47); // G
    });
  });

  group('FocusTimerController & Pomodoro Workflow', () {
    test('initializes with focus mode (25m)', () {
      final ctrl = FocusTimerController();
      expect(ctrl.mode, FocusMode.focus);
      expect(ctrl.totalSeconds, 25 * 60);
      expect(ctrl.remainingSeconds, 25 * 60);
      expect(ctrl.isRunning, isFalse);
      expect(ctrl.formattedTime, '25:00');
      expect(ctrl.progress, 0.0);
    });

    test('start, pause, and reset modify state and notify', () {
      final ctrl = FocusTimerController();
      int notifyCount = 0;
      ctrl.addListener(() => notifyCount++);

      ctrl.start();
      expect(ctrl.isRunning, isTrue);
      expect(notifyCount, 1);

      ctrl.pause();
      expect(ctrl.isRunning, isFalse);
      expect(notifyCount, 2);

      ctrl.tick();
      expect(ctrl.remainingSeconds, (25 * 60) - 1);
      expect(ctrl.formattedTime, '24:59');

      ctrl.reset();
      expect(ctrl.remainingSeconds, 25 * 60);
      expect(ctrl.formattedTime, '25:00');
    });

    test('setMode changes time and mode', () {
      final ctrl = FocusTimerController();
      ctrl.setMode(FocusMode.shortBreak);

      expect(ctrl.mode, FocusMode.shortBreak);
      expect(ctrl.totalSeconds, 5 * 60);
      expect(ctrl.remainingSeconds, 5 * 60);
      expect(ctrl.formattedTime, '5:00');
    });

    test('advances to short break after focus completes', () {
      final ctrl = FocusTimerController();
      // Fast forward to 1 second remaining
      while (ctrl.remainingSeconds > 1) {
        ctrl.tick();
      }

      ctrl.tick(); // Finishes focus block
      expect(ctrl.mode, FocusMode.shortBreak);
      expect(ctrl.completedSessions, 1);
      expect(ctrl.streakInCycle, 1);
      expect(ctrl.formattedTime, '5:00');
    });

    test('advances to long break after 4 focus sessions', () {
      final ctrl = FocusTimerController();
      // Simulate 4 complete focus sessions
      for (int i = 0; i < 4; i++) {
        ctrl.setMode(FocusMode.focus);
        while (ctrl.remainingSeconds > 1) {
          ctrl.tick();
        }
        ctrl.tick(); // Finishes focus
        if (i < 3) {
          expect(ctrl.mode, FocusMode.shortBreak);
        }
      }

      expect(ctrl.mode, FocusMode.longBreak);
      expect(ctrl.completedSessions, 4);
      expect(ctrl.streakInCycle, 0);
      expect(ctrl.formattedTime, '15:00');
    });
  });

  group('FocusTimerDialog & MiniButton Widgets', () {
    testWidgets(
      'FocusTimerDialog renders progress ring, digits, and controls',
      (tester) async {
        final ctrl = FocusTimerController();
        await tester.pumpWidget(host(FocusTimerDialog(controller: ctrl)));

        expect(find.text('Focus & Deep Work'), findsOneWidget);
        expect(find.text('25:00'), findsOneWidget);
        expect(find.text('DEEP FOCUS'), findsOneWidget);
        expect(find.text('Focus'), findsOneWidget);
        expect(find.text('Break'), findsOneWidget);
        expect(find.text('Rest'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('focus-timer-play-pause')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('focus-timer-reset')), findsOneWidget);
        expect(find.byKey(const ValueKey('focus-timer-skip')), findsOneWidget);
      },
    );

    testWidgets(
      'FocusTimerMiniButton renders formatted time and opens dialog',
      (tester) async {
        final ctrl = FocusTimerController();
        await tester.pumpWidget(host(FocusTimerMiniButton(controller: ctrl)));

        expect(
          find.byKey(const ValueKey('focus-timer-button')),
          findsOneWidget,
        );
        expect(find.text('25:00'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('focus-timer-button')));
        await tester.pumpAndSettle();

        expect(find.text('Focus & Deep Work'), findsOneWidget);

        // Dismiss the dialog cleanly to reset routes
        Navigator.of(tester.element(find.text('Focus & Deep Work'))).pop();
        await tester.pumpAndSettle();
      },
    );
  });

  group('TaskRow Completion Motion & Undo (MOT-04, TASK-01)', () {
    testWidgets(
      'checking task triggers completion and shows recoverable undo snackbar',
      (tester) async {
        final store = MemoryStore();
        final controller = WorkspaceController();
        controller.repository = WorkspaceRepository(
          store: store,
          index: MemoryObjectIndex(),
        );
        await controller.initialize();

        final task = await controller.create('orbit.task');
        expect(task, isNotNull);
        controller.edit(task!.id, title: 'Write Research Thesis');

        final updatedTask = controller.find(task.id)!;

        await tester.pumpWidget(
          host(TaskRow(object: updatedTask, controller: controller)),
        );

        expect(find.text('Write Research Thesis'), findsOneWidget);

        // Checkbox is unchecked initially
        final checkboxFinder = find.byType(Checkbox);
        expect(checkboxFinder, findsOneWidget);
        Checkbox cb = tester.widget<Checkbox>(checkboxFinder);
        expect(cb.value, isFalse);

        // Tap checkbox to complete
        await tester.tap(checkboxFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Verify task is now completed
        final completedTask = controller.find(task.id)!;
        expect(completedTask.isCompleted, isTrue);

        // Verify recoverable SnackBar with Undo action appears
        expect(
          find.text('Task completed: "Write Research Thesis"'),
          findsOneWidget,
        );
        expect(find.text('Undo'), findsOneWidget);

        // Tap Undo
        await tester.tap(find.text('Undo'));
        await tester.pump();

        // Verify task completion reverted
        final uncompletedTask = controller.find(task.id)!;
        expect(uncompletedTask.isCompleted, isFalse);

        // Flush debounce and session timers
        await tester.pump(const Duration(seconds: 2));
      },
    );
  });
}
