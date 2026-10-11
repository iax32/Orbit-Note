import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/notes/orbit_internal_link.dart';
import 'package:orbit_note/features/notes/rich/code_block.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';
import 'package:orbit_note/features/workspace/workspace_views.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

Future<({WorkspaceController controller, ProviderContainer container})>
_setupTestWorkspace() async {
  final store = MemoryStore();
  final repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
  await repo.initialize();
  final container = ProviderContainer(
    overrides: [repositoryProvider.overrideWithValue(repo)],
  );
  final c = container.read(workspaceProvider.notifier);
  await c.initialize();
  return (controller: c, container: container);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.now();

  UniversalObject makeObject({
    required String id,
    required String title,
    String typeId = 'orbit.note',
    String body = '',
    Map<String, dynamic> properties = const {},
  }) {
    return UniversalObject(
      id: id,
      workspaceId: 'ws-1',
      typeId: typeId,
      title: title,
      body: body,
      properties: properties,
      data: const {},
      createdAt: now,
      updatedAt: now,
    );
  }

  Widget wrapWithTheme(Widget child) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [OrbitColors()]),
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('OrbitInternalLink tests', () {
    testWidgets('renders link text with appropriate styling', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          OrbitInternalLink(
            href: 'orbit:note-alpha',
            text: 'Alpha Note',
            onOpen: (_) {},
          ),
        ),
      );

      expect(find.text('Alpha Note'), findsOneWidget);
    });

    testWidgets('single click triggers onOpen', (tester) async {
      String? openedHref;
      await tester.pumpWidget(
        wrapWithTheme(
          OrbitInternalLink(
            href: 'orbit:note-alpha',
            text: 'Alpha Note',
            onOpen: (href) => openedHref = href,
          ),
        ),
      );

      await tester.tap(find.text('Alpha Note'));
      await tester.pumpAndSettle();

      expect(openedHref, equals('orbit:note-alpha'));
    });

    testWidgets('Ctrl+Click triggers onOpenInNewTab', (tester) async {
      String? openedTabHref;
      String? openedHref;

      await tester.pumpWidget(
        wrapWithTheme(
          OrbitInternalLink(
            href: 'orbit:note-alpha',
            text: 'Alpha Note',
            onOpen: (href) => openedHref = href,
            onOpenInNewTab: (href) => openedTabHref = href,
          ),
        ),
      );

      // Simulate Ctrl+Click
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.text('Alpha Note'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(openedTabHref, equals('orbit:note-alpha'));
      expect(openedHref, isNull);
    });

    testWidgets('middle click triggers onOpenInNewTab', (tester) async {
      String? openedTabHref;

      await tester.pumpWidget(
        wrapWithTheme(
          OrbitInternalLink(
            href: 'orbit:note-alpha',
            text: 'Alpha Note',
            onOpen: (_) {},
            onOpenInNewTab: (href) => openedTabHref = href,
          ),
        ),
      );

      final center = tester.getCenter(find.text('Alpha Note'));
      final gesture = await tester.startGesture(
        center,
        kind: PointerDeviceKind.mouse,
        buttons: kMiddleMouseButton,
      );
      await gesture.up();
      await tester.pumpAndSettle();

      expect(openedTabHref, equals('orbit:note-alpha'));
    });

    testWidgets('right-click reveals desktop context menu', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          OrbitInternalLink(
            href: 'orbit:note-alpha',
            text: 'Alpha Note',
            onOpen: (_) {},
          ),
        ),
      );

      final center = tester.getCenter(find.text('Alpha Note'));
      final gesture = await tester.startGesture(
        center,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Open in new tab'), findsOneWidget);
      expect(find.text('Copy link'), findsOneWidget);
    });

    testWidgets('hover triggers OrbitPeekCard after 300ms', (tester) async {
      final targetNote = makeObject(
        id: 'note-alpha',
        title: 'Alpha Note',
        body: 'Alpha note body content describing system design.',
      );

      await tester.pumpWidget(
        wrapWithTheme(
          OrbitInternalLink(
            href: 'orbit:note-alpha',
            text: 'Alpha Note',
            allObjects: [targetNote],
            onOpen: (_) {},
          ),
        ),
      );

      // Move mouse over the link
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.text('Alpha Note')));
      await tester.pump();

      // Before 300ms, peek card is not yet displayed
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(OrbitPeekCard), findsNothing);

      // After 300ms, peek card is displayed
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(OrbitPeekCard), findsOneWidget);

      // Move mouse away
      await gesture.moveTo(const Offset(5, 5));
      await tester.pump();

      // Within 220ms grace period, peek card stays open
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(OrbitPeekCard), findsOneWidget);

      // After grace period, peek card is dismissed
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(OrbitPeekCard), findsNothing);

      await gesture.removePointer();
    });

    testWidgets('keyboard Enter activates link', (tester) async {
      String? openedHref;

      await tester.pumpWidget(
        wrapWithTheme(
          OrbitInternalLink(
            href: 'orbit:note-alpha',
            text: 'Alpha Note',
            onOpen: (href) => openedHref = href,
          ),
        ),
      );

      // Focus the link
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      // Send Enter
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(openedHref, equals('orbit:note-alpha'));
    });
  });

  group('Editor microinteraction polish tests', () {
    testWidgets('rich editor contains no ActionChip widgets under links', (
      tester,
    ) async {
      final doc =
          'See [[Alpha Note]] for details.\n\nAlso check [Web](https://orbit.app).';

      await tester.pumpWidget(
        wrapWithTheme(
          RichMarkdownEditor(
            body: doc,
            onChanged: (_) {},
            onUndo: () {},
            onRedo: () {},
            linkTargets: const [],
            linkBindings: const {},
            onOpenLink: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure no ActionChips are rendered below blocks
      expect(find.byType(ActionChip), findsNothing);
    });

    testWidgets(
      'code block copy button uses AnimatedOpacity for subtle hover',
      (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            const NoteCodeBlock(
              code: 'void main() => print("test");',
              language: 'dart',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Ensure AnimatedOpacity wraps the copy button
        expect(find.byType(AnimatedOpacity), findsWidgets);
        expect(find.text('Copy code'), findsOneWidget);
      },
    );

    testWidgets('clicking anywhere on Home resume row triggers navigation', (
      tester,
    ) async {
      final env = await _setupTestWorkspace();
      final c = env.controller;

      final note = (await c.create(
        'orbit.note',
        title: 'Quantum Computing Notes',
      ))!;
      c.edit(note.id, body: 'Draft notes on qubits.');

      c.updateSession((s) {
        s.recent = [note.id];
        s.destination = OrbitDestination.home;
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: env.container,
          child: MaterialApp(
            home: Scaffold(body: HomeView(controller: c)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clicking directly on the note title (not the button) opens the note
      await tester.tap(find.text('Quantum Computing Notes'));
      await tester.pumpAndSettle();

      expect(c.session.activeId, equals(note.id));
      env.container.dispose();
    });
  });
}
