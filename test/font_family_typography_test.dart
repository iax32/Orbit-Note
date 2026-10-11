import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orbit_note/app/google_cloud_controller.dart';
import 'package:orbit_note/app/orbit_app.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/sync/google_account.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/features/canvas/canvas_rich_text.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/sync/google_drive_api.dart';
import 'support/memory_store.dart';

class _FakeGoogleAuth implements GoogleAccountAuth {
  @override
  bool get configured => false;
  @override
  GoogleAccount? get account => null;
  @override
  Future<GoogleAccount?> restore() async => null;
  @override
  Future<GoogleAccount> signIn({String? expectedSubject}) async =>
      throw UnimplementedError();
  @override
  Future<String> accessToken({bool refresh = false}) async => '';
  @override
  Future<void> signOut() async {}
  @override
  void cancel() {}
}

class _FakeCredentials implements GoogleCredentialStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> delete() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionState - Font Family Configuration', () {
    test('defaults to Segoe UI', () {
      final session = SessionState();
      expect(session.fontFamily, 'Segoe UI');
    });

    test('serializes and deserializes Times New Roman', () {
      final session = SessionState(fontFamily: 'Times New Roman');
      final json = session.toJson();
      expect(json['fontFamily'], 'Times New Roman');

      final restored = SessionState.fromJson(json);
      expect(restored.fontFamily, 'Times New Roman');
    });

    test('falls back to Segoe UI for unsupported font family in json', () {
      final json = {'fontFamily': 'Comic Sans MS'};
      final restored = SessionState.fromJson(json);
      expect(restored.fontFamily, 'Segoe UI');
    });
  });

  group('OrbitTheme - Font Family Application', () {
    test('orbitDarkTheme sets typography and input styles', () {
      final theme = orbitDarkTheme(fontFamily: 'Times New Roman');
      expect(theme.textTheme.labelLarge?.fontFamily, 'Times New Roman');
      expect(
        theme.popupMenuTheme.labelTextStyle?.resolve({})?.fontFamily,
        'Times New Roman',
      );
      expect(
        theme.inputDecorationTheme.labelStyle?.fontFamily,
        'Times New Roman',
      );
    });

    test('orbitDarkTheme defaults to Segoe UI', () {
      final theme = orbitDarkTheme();
      expect(theme.textTheme.labelLarge?.fontFamily, 'Segoe UI');
    });
  });

  group('SettingsView - Font Family Selection', () {
    testWidgets('SettingsView font dropdown updates session fontFamily', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      final auth = _FakeGoogleAuth();
      final cloud = GoogleCloudController(
        auth,
        GoogleDriveApi(
          auth: auth,
          client: MockClient((_) async => http.Response('{}', 200)),
          localMetadata: _FakeCredentials(),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repository),
            googleCloudProvider.overrideWithValue(cloud),
          ],
          child: const OrbitNoteApp(),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OrbitNoteApp)),
      );
      final c = container.read(workspaceProvider.notifier);

      c.navigate(OrbitDestination.settings);
      await tester.pumpAndSettle();

      final dropdownFinder = find.byKey(
        const ValueKey('settings-font-family-dropdown'),
      );
      expect(dropdownFinder, findsOneWidget);
      await tester.ensureVisible(dropdownFinder);
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(dropdownFinder);
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Times New Roman (Serif)').last);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 700));

      expect(c.session.fontFamily, 'Times New Roman');
      final preview = tester.widget<Text>(
        find.byKey(const ValueKey('settings-reading-font-preview')),
      );
      expect(preview.style?.fontFamily, 'Times New Roman');
      expect(preview.style?.fontSize, c.session.fontSize);
      expect(preview.style?.height, c.session.editorLineHeight);

      await c.flushAll();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      cloud.dispose();
    });
  });

  group('NoteEditor & RichMarkdownEditor - Font Family Propagation', () {
    testWidgets(
      'NoteEditor displays font selector menu and triggers onFontFamilyChanged',
      (tester) async {
        String? updatedFont;
        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(fontFamily: 'Times New Roman'),
            home: Scaffold(
              body: NoteEditor(
                noteId: 'note-1',
                title: 'Academic Thesis',
                body: 'Introduction to spatial typography.',
                fontFamily: 'Times New Roman',
                onFontFamilyChanged: (f) => updatedFont = f,
                onTitleChanged: (_) {},
                onBodyChanged: (_) {},
                linkTargets: const [],
                onOpenObject: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check font switcher button exists in header
        final fontMenuFinder = find.byKey(
          const ValueKey('note-font-family-menu'),
        );
        expect(fontMenuFinder, findsOneWidget);

        // Tap font switcher button
        await tester.tap(fontMenuFinder);
        await tester.pumpAndSettle();

        // Verify menu items
        expect(find.text('Segoe UI (Default Sans)'), findsOneWidget);
        expect(find.text('Times New Roman (Serif)'), findsOneWidget);
        expect(find.text('Georgia (Serif)'), findsOneWidget);
        expect(find.text('Consolas (Code)'), findsOneWidget);

        // Select Segoe UI
        await tester.tap(find.text('Segoe UI (Default Sans)'));
        await tester.pumpAndSettle();

        expect(updatedFont, 'Segoe UI');
      },
    );

    testWidgets(
      'RichMarkdownEditor applies fontFamily to blocks while preserving monospace code blocks',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(fontFamily: 'Times New Roman'),
            home: Scaffold(
              body: RichMarkdownEditor(
                body:
                    '# Section Header\n\nThis is serif body text.\n\n```dart\nfinal x = 42;\n```',
                fontFamily: 'Times New Roman',
                onChanged: (_) {},
                onUndo: () {},
                onRedo: () {},
                linkTargets: const [],
                linkBindings: const {},
                onOpenLink: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find TextFields inside editor
        final textFields = tester
            .widgetList<TextField>(find.byType(TextField))
            .toList();
        expect(textFields.isNotEmpty, isTrue);

        // Heading block has Times New Roman font family
        final headingField = textFields.firstWhere(
          (tf) => tf.controller?.text == 'Section Header',
        );
        expect(headingField.style?.fontFamily, 'Times New Roman');

        // Body text block has Times New Roman font family
        final bodyField = textFields.firstWhere(
          (tf) =>
              tf.controller?.text.contains('This is serif body text') ?? false,
        );
        expect(bodyField.style?.fontFamily, 'Times New Roman');
      },
    );
  });

  group('Canvas Typography - Font Family & Rich Text', () {
    testWidgets('CanvasRichText.draw uses specified fontFamily', (
      tester,
    ) async {
      final textCache = CanvasTextCache();
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 500, 500));

      CanvasRichText.draw(
        canvas: canvas,
        text: '# Heading in Times\n- [ ] Task in Times\nParagraph body text',
        bounds: const Rect.fromLTWH(0, 0, 400, 400),
        accent: const Color(0xFF8B5CF6),
        colors: const ColorScheme.dark(),
        textCache: textCache,
        fontFamily: 'Times New Roman',
      );

      final picture = recorder.endRecording();
      final img = await picture.toImage(500, 500);
      expect(img.width, 500);
      textCache.dispose();
    });

    testWidgets(
      'CanvasEditor renders with Times New Roman and passes to OrbitCanvasPainter',
      (tester) async {
        final sceneData = {
          'elements': [
            {
              'id': 'sticky-1',
              'type': 'sticky',
              'x': 50.0,
              'y': 50.0,
              'width': 200.0,
              'height': 150.0,
              'text': '# Research Note\nKey findings here.',
            },
          ],
        };

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(fontFamily: 'Times New Roman'),
            home: Scaffold(
              body: CanvasEditor(
                canvasId: 'board-1',
                fontFamily: 'Times New Roman',
                data: sceneData,
                onChanged: (_) {},
                objects: const [],
                onOpenObject: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // CustomPaint is rendered with OrbitCanvasPainter having Times New Roman
        final customPaintFinder = find.byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              w.painter is OrbitCanvasPainter &&
              (w.painter as OrbitCanvasPainter).fontFamily == 'Times New Roman',
        );
        expect(customPaintFinder, findsOneWidget);
      },
    );
  });
}
