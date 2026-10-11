import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_components.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/canvas/audio_player_card.dart';
import 'package:orbit_note/features/workspace/focus_timer.dart';
import 'package:orbit_note/features/workspace/workspace_views.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionState Settings Serialization', () {
    test('default settings values are initialized correctly', () {
      final s = SessionState();
      expect(s.accentColor, 'violet');
      expect(s.autoSaveInterval, 1000);
      expect(s.autoSnapshotOnClose, isTrue);
      expect(s.defaultNoteMode, 'rich');
      expect(s.defaultDocumentFormat, 'markdown');
      expect(s.bionicReadingDefault, isFalse);
      expect(s.focusMinutes, 25);
      expect(s.shortBreakMinutes, 5);
      expect(s.longBreakMinutes, 15);
      expect(s.defaultCanvasGrid, 'dots');
      expect(s.canvasSnapToGrid, isFalse);
      expect(s.defaultAudioSpeed, 1.0);
      expect(s.editorLineHeight, 1.6);
      expect(s.showLineNumbers, isTrue);
    });

    test('toJson and fromJson preserves all new settings', () {
      final s = SessionState(
        accentColor: 'emerald',
        autoSaveInterval: 2500,
        autoSnapshotOnClose: false,
        defaultNoteMode: 'split',
        defaultDocumentFormat: 'latex',
        bionicReadingDefault: true,
        focusMinutes: 45,
        shortBreakMinutes: 10,
        longBreakMinutes: 30,
        defaultCanvasGrid: 'hex',
        canvasSnapToGrid: true,
        defaultAudioSpeed: 1.5,
        editorLineHeight: 1.8,
        showLineNumbers: false,
      );

      final json = s.toJson();
      expect(json['accentColor'], 'emerald');
      expect(json['autoSaveInterval'], 2500);
      expect(json['autoSnapshotOnClose'], isFalse);
      expect(json['defaultNoteMode'], 'split');
      expect(json['defaultDocumentFormat'], 'latex');
      expect(json['bionicReadingDefault'], isTrue);
      expect(json['focusMinutes'], 45);
      expect(json['shortBreakMinutes'], 10);
      expect(json['longBreakMinutes'], 30);
      expect(json['defaultCanvasGrid'], 'hex');
      expect(json['canvasSnapToGrid'], isTrue);
      expect(json['defaultAudioSpeed'], 1.5);
      expect(json['editorLineHeight'], 1.8);
      expect(json['showLineNumbers'], isFalse);

      final restored = SessionState.fromJson(json);
      expect(restored.accentColor, 'emerald');
      expect(restored.autoSaveInterval, 2500);
      expect(restored.autoSnapshotOnClose, isFalse);
      expect(restored.defaultNoteMode, 'split');
      expect(restored.defaultDocumentFormat, 'latex');
      expect(restored.bionicReadingDefault, isTrue);
      expect(restored.focusMinutes, 45);
      expect(restored.shortBreakMinutes, 10);
      expect(restored.longBreakMinutes, 30);
      expect(restored.defaultCanvasGrid, 'hex');
      expect(restored.canvasSnapToGrid, isTrue);
      expect(restored.defaultAudioSpeed, 1.5);
      expect(restored.editorLineHeight, 1.8);
      expect(restored.showLineNumbers, isFalse);
    });

    test('fromJson validates invalid options and clamps values', () {
      final json = {
        'accentColor': 'invalid_color',
        'autoSaveInterval': 999999,
        'autoSnapshotOnClose': false,
        'defaultNoteMode': 'invalid_mode',
        'defaultDocumentFormat': 'invalid_format',
        'bionicReadingDefault': true,
        'focusMinutes': 999,
        'shortBreakMinutes': 0,
        'longBreakMinutes': -10,
        'defaultCanvasGrid': 'invalid_grid',
        'canvasSnapToGrid': true,
        'defaultAudioSpeed': 99.0,
        'editorLineHeight': 0.5,
        'showLineNumbers': true,
      };

      final restored = SessionState.fromJson(json);
      expect(restored.accentColor, 'violet'); // fallback
      expect(restored.autoSaveInterval, 10000); // clamped to max 10000
      expect(restored.autoSnapshotOnClose, isFalse);
      expect(restored.defaultNoteMode, 'rich'); // fallback
      expect(restored.defaultDocumentFormat, 'markdown'); // fallback
      expect(restored.bionicReadingDefault, isTrue);
      expect(restored.focusMinutes, 120); // clamped to max 120
      expect(restored.shortBreakMinutes, 1); // clamped to min 1
      expect(restored.longBreakMinutes, 5); // clamped to min 5
      expect(restored.defaultCanvasGrid, 'dots'); // fallback
      expect(restored.canvasSnapToGrid, isTrue);
      expect(restored.defaultAudioSpeed, 1.0); // fallback
      expect(restored.editorLineHeight, 1.2); // clamped to min 1.2
      expect(restored.showLineNumbers, isTrue);
    });
  });

  group('OrbitColors & Theme Customization', () {
    test('contains all 6 accent presets', () {
      expect(OrbitColors.accentPresets.length, 6);
      expect(OrbitColors.accentPresets['violet'], const Color(0xFF8B7CF6));
      expect(OrbitColors.accentPresets['cyan'], const Color(0xFF06B6D4));
      expect(OrbitColors.accentPresets['emerald'], const Color(0xFF10B981));
      expect(OrbitColors.accentPresets['amber'], const Color(0xFFF59E0B));
      expect(OrbitColors.accentPresets['rose'], const Color(0xFFF43F5E));
      expect(OrbitColors.accentPresets['blue'], const Color(0xFF3B82F6));
    });

    test('accentFromPreset returns correct color and fallback', () {
      expect(OrbitColors.accentFromPreset('emerald'), const Color(0xFF10B981));
      expect(OrbitColors.accentFromPreset('unknown'), const Color(0xFF8B7CF6));
      expect(OrbitColors.accentFromPreset(null), const Color(0xFF8B7CF6));
    });

    test('copyWith updates accent and recalculates accentHover', () {
      const base = OrbitColors();
      final updated = base.copyWith(accent: const Color(0xFF10B981));
      expect(updated.accent, const Color(0xFF10B981));
      expect(updated.accentHover, isNot(base.accentHover));
    });

    test('orbitDarkTheme accepts accentColor without errors', () {
      final theme = orbitDarkTheme(accentColor: const Color(0xFF06B6D4));
      expect(theme.colorScheme.primary, const Color(0xFF06B6D4));
      final ext = theme.extension<OrbitColors>();
      expect(ext, isNotNull);
      expect(ext!.accent, const Color(0xFF06B6D4));
    });
  });

  group('FocusTimerController Durations', () {
    test('configureDurations updates mode minutes and seconds when idle', () {
      final ctrl = FocusTimerController();
      expect(ctrl.totalSeconds, 25 * 60);

      ctrl.configureDurations(focus: 30, shortBreak: 10, longBreak: 20);
      expect(ctrl.focusMinutes, 30);
      expect(ctrl.shortBreakMinutes, 10);
      expect(ctrl.longBreakMinutes, 20);
      expect(ctrl.totalSeconds, 30 * 60);
      expect(ctrl.remainingSeconds, 30 * 60);

      ctrl.setMode(FocusMode.shortBreak);
      expect(ctrl.totalSeconds, 10 * 60);
      expect(ctrl.remainingSeconds, 10 * 60);

      ctrl.setMode(FocusMode.longBreak);
      expect(ctrl.totalSeconds, 20 * 60);
      expect(ctrl.remainingSeconds, 20 * 60);
    });

    test('skip advances using configured custom durations', () {
      final ctrl = FocusTimerController();
      ctrl.configureDurations(focus: 20, shortBreak: 3, longBreak: 15);
      ctrl.setMode(FocusMode.focus);

      ctrl.skip();
      expect(ctrl.mode, FocusMode.shortBreak);
      expect(ctrl.totalSeconds, 3 * 60);
      expect(ctrl.completedSessions, 1);

      ctrl.skip();
      expect(ctrl.mode, FocusMode.focus);
      expect(ctrl.totalSeconds, 20 * 60);
    });
  });

  group('Animation Widgets', () {
    testWidgets('OrbitAnimatedCounter renders value and animates', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OrbitAnimatedCounter(
              value: 42,
              duration: Duration(milliseconds: 200),
            ),
          ),
        ),
      );

      expect(find.text('42'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OrbitAnimatedCounter(
              value: 100,
              duration: Duration(milliseconds: 200),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      // Mid-flight animation
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('OrbitAnimatedCounter respects formatter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrbitAnimatedCounter(
              value: 1500,
              formatter: (v) => '$v items',
            ),
          ),
        ),
      );

      expect(find.text('1500 items'), findsOneWidget);
    });

    testWidgets('OrbitAnimatedCounter snaps immediately when motion is off', (
      tester,
    ) async {
      await tester.pumpWidget(
        const OrbitMotionScope(
          preference: 'off',
          osReduced: false,
          child: MaterialApp(
            home: Scaffold(
              body: OrbitAnimatedCounter(
                value: 50,
                duration: Duration(milliseconds: 400),
              ),
            ),
          ),
        ),
      );

      expect(find.text('50'), findsOneWidget);

      await tester.pumpWidget(
        const OrbitMotionScope(
          preference: 'off',
          osReduced: false,
          child: MaterialApp(
            home: Scaffold(
              body: OrbitAnimatedCounter(
                value: 80,
                duration: Duration(milliseconds: 400),
              ),
            ),
          ),
        ),
      );

      // Snapped immediately without pumping frames
      await tester.pump();
      expect(find.text('80'), findsOneWidget);
    });

    testWidgets('OrbitHoverLiftCard renders child and handles tap', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: OrbitHoverLiftCard(
              onTap: () => tapped = true,
              child: const Text('Lift Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Lift Card Content'), findsOneWidget);
      await tester.tap(find.text('Lift Card Content'));
      expect(tapped, isTrue);
    });

    testWidgets(
      'OrbitBreathingGlow animates when active and disables when off',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: const Scaffold(
              body: OrbitBreathingGlow(
                active: true,
                child: Text('Breathing Target'),
              ),
            ),
          ),
        );

        expect(find.text('Breathing Target'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Breathing Target'), findsOneWidget);

        // Disable motion
        await tester.pumpWidget(
          const OrbitMotionScope(
            preference: 'off',
            osReduced: false,
            child: MaterialApp(
              home: Scaffold(
                body: OrbitBreathingGlow(
                  active: true,
                  child: Text('Breathing Target'),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Breathing Target'), findsOneWidget);
      },
    );

    testWidgets('OrbitAnimatedProgress renders and clamps values', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OrbitAnimatedProgress(value: 0.75, minHeight: 6),
          ),
        ),
      );

      expect(find.byType(OrbitAnimatedProgress), findsOneWidget);
    });

    testWidgets('OrbitPulseBadge renders and animates when active', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: const Scaffold(
            body: OrbitPulseBadge(label: 'LIVE TEST', active: true),
          ),
        ),
      );

      expect(find.text('LIVE TEST'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('LIVE TEST'), findsOneWidget);

      // Disable motion
      await tester.pumpWidget(
        const OrbitMotionScope(
          preference: 'off',
          osReduced: false,
          child: MaterialApp(
            home: Scaffold(
              body: OrbitPulseBadge(label: 'LIVE TEST', active: true),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('LIVE TEST'), findsOneWidget);
    });

    testWidgets('OrbitBounceButton triggers onTap and handles press', (
      tester,
    ) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrbitBounceButton(
              onTap: () => pressed = true,
              child: const Text('Bounce Me'),
            ),
          ),
        ),
      );

      expect(find.text('Bounce Me'), findsOneWidget);
      await tester.tap(find.text('Bounce Me'));
      expect(pressed, isTrue);
    });

    testWidgets('OrbitFadeSwitcher crossfades children', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OrbitFadeSwitcher(
              child: Text('First View', key: ValueKey('first')),
            ),
          ),
        ),
      );

      expect(find.text('First View'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OrbitFadeSwitcher(
              child: Text('Second View', key: ValueKey('second')),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Second View'), findsOneWidget);
    });

    testWidgets('OrbitAudioPlayerCard initializes with custom initialSpeed', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: const Scaffold(
            body: OrbitAudioPlayerCard(
              title: 'Speed Test Memo',
              initialSpeed: 1.5,
            ),
          ),
        ),
      );

      expect(find.text('Speed Test Memo'), findsOneWidget);
      expect(find.text('1.5x'), findsOneWidget);
    });
  });

  group('SettingsView Controls & Telemetry Widget Tests', () {
    testWidgets('SettingsView renders accent chips and allows selection', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final ctrl = WorkspaceController();
      ctrl.repository = WorkspaceRepository();
      ctrl.session = SessionState(accentColor: 'violet');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: SettingsView(
                controller: ctrl,
                onExport: () {},
                onImport: () {},
                onOpenWorkspace: () {},
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('settings-accent-cyan')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('settings-accent-emerald')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('settings-accent-emerald')));
      await tester.pump();
      expect(ctrl.session.accentColor, 'emerald');

      // Drain debounce timer
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets(
      'SettingsView renders editor defaults, storage and timer dropdowns',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final ctrl = WorkspaceController();
        ctrl.repository = WorkspaceRepository();
        ctrl.session = SessionState(
          defaultNoteMode: 'rich',
          defaultDocumentFormat: 'markdown',
          bionicReadingDefault: false,
          autoSaveInterval: 1000,
          autoSnapshotOnClose: true,
          focusMinutes: 25,
        );

        // Add dummy objects for vault analytics card
        ctrl.objects = [
          UniversalObject(
            id: 'note-1',
            workspaceId: 'ws-1',
            typeId: 'orbit.note',
            title: 'First Note',
            body: 'Hello world this is a test document',
            properties: {
              'revisions': [
                {'id': 'rev-1', 'title': 'v1'},
                {'id': 'rev-2', 'title': 'v2'},
              ],
            },
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          UniversalObject(
            id: 'canvas-1',
            workspaceId: 'ws-1',
            typeId: 'orbit.canvas',
            title: 'My Canvas',
            body: '',
            properties: const {},
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          UniversalObject(
            id: 'task-1',
            workspaceId: 'ws-1',
            typeId: 'orbit.task',
            title: 'Complete task',
            body: '',
            properties: const {},
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: orbitDarkTheme(),
              home: Scaffold(
                body: SettingsView(
                  controller: ctrl,
                  onExport: () {},
                  onImport: () {},
                  onOpenWorkspace: () {},
                ),
              ),
            ),
          ),
        );

        // Verify Bionic reading switch
        expect(
          find.byKey(const ValueKey('settings-bionic-reading-switch')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('settings-bionic-reading-switch')),
        );
        await tester.pump();
        expect(ctrl.session.bionicReadingDefault, isTrue);

        // Verify Auto-snapshot switch
        expect(
          find.byKey(const ValueKey('settings-auto-snapshot-switch')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('settings-auto-snapshot-switch')),
        );
        await tester.pump();
        expect(ctrl.session.autoSnapshotOnClose, isFalse);

        // Verify Vault Analytics card exists
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('settings-vault-analytics-card')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('settings-vault-analytics-card')),
          findsOneWidget,
        );
        expect(find.text('Observatory Vault Analytics'), findsOneWidget);
        expect(find.text('Notes'), findsOneWidget);
        expect(find.text('Canvases'), findsOneWidget);
        expect(find.text('Tasks'), findsOneWidget);
        expect(find.text('Snapshots'), findsOneWidget);
        expect(find.text('Total Words'), findsOneWidget);

        // Drain session debounce timer cleanly
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'SettingsView renders new canvas, audio, and line spacing settings',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final ctrl = WorkspaceController();
        ctrl.repository = WorkspaceRepository();
        ctrl.session = SessionState(
          defaultCanvasGrid: 'dots',
          canvasSnapToGrid: false,
          defaultAudioSpeed: 1.0,
          editorLineHeight: 1.6,
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: orbitDarkTheme(),
              home: Scaffold(
                body: SettingsView(
                  controller: ctrl,
                  onExport: () {},
                  onImport: () {},
                  onOpenWorkspace: () {},
                ),
              ),
            ),
          ),
        );

        // Verify line spacing dropdown
        expect(
          find.byKey(const ValueKey('settings-line-spacing-dropdown')),
          findsOneWidget,
        );

        // Verify canvas grid dropdown and snap switch
        expect(
          find.byKey(const ValueKey('settings-canvas-grid-dropdown')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('settings-canvas-snap-switch')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('settings-canvas-snap-switch')),
        );
        await tester.pump();
        expect(ctrl.session.canvasSnapToGrid, isTrue);

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('settings-audio-speed-dropdown')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        // Verify audio speed dropdown
        expect(
          find.byKey(const ValueKey('settings-audio-speed-dropdown')),
          findsOneWidget,
        );

        // Verify Live Telemetry badge
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('settings-vault-analytics-card')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('settings-vault-live-badge')),
          findsOneWidget,
        );
        expect(find.text('TELEMETRY LIVE'), findsOneWidget);

        // Verify Optimize Vault Cache button
        final optButton = find.byKey(
          const ValueKey('settings-optimize-vault-button'),
        );
        await tester.scrollUntilVisible(
          optButton,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        expect(optButton, findsOneWidget);
        await tester.tap(optButton);
        await tester.pump();
        expect(
          find.text(
            'Vault integrity verified. Local indexes and snapshot caches pruned.',
          ),
          findsOneWidget,
        );

        await tester.pump(const Duration(seconds: 1));
      },
    );
  });
}
