import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/domain/pdf_annotation.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/features/pdf/pdf_notes_panel.dart';
import 'package:orbit_note/features/pdf/pdf_review_panel.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';
import 'support/pdf_fixture.dart';

void main() {
  group('PdfQuoteDragData & referenceTarget', () {
    test('computes referenceTarget and preserves all fields in JSON', () {
      final quote = PdfQuoteDragData(
        objectId: 'doc-101',
        title: 'Quantum Field Theory',
        page: 42,
        text: 'Symmetry principles dictate the interaction Lagrangian.',
        checksum: 'sha256-abcdef123456',
      );

      expect(quote.referenceTarget, 'doc-101#page=42');
      expect(quote.citation, 'Quantum Field Theory · p. 42');
      expect(
        quote.markdownQuote,
        '> Symmetry principles dictate the interaction Lagrangian.\n\n[[doc-101#page=42|Quantum Field Theory · p. 42]]\n',
      );

      final json = quote.toJson();
      expect(json['objectId'], 'doc-101');
      expect(json['title'], 'Quantum Field Theory');
      expect(json['page'], 42);
      expect(
        json['text'],
        'Symmetry principles dictate the interaction Lagrangian.',
      );
      expect(json['checksum'], 'sha256-abcdef123456');

      final revived = PdfQuoteDragData.fromJson(json);
      expect(revived.referenceTarget, quote.referenceTarget);
      expect(revived.checksum, quote.checksum);
    });
  });

  group('WorkspaceController PDF Quote Transclusion to Canvas', () {
    late MemoryStore store;
    late WorkspaceRepository repo;
    late ProviderContainer container;
    late WorkspaceController controller;

    setUp(() async {
      store = MemoryStore();
      repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
      container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      container.read(workspaceProvider);
      controller = container.read(workspaceProvider.notifier);
      for (var i = 0; i < 100 && controller.loading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      expect(controller.loading, isFalse);
    });

    tearDown(() async {
      store.writeGate = null;
      store.failWrites = false;
      await controller.flushAll();
      container.dispose();
    });

    test(
      'extractPdfQuoteToCanvas configures transclusion card and referenceTarget',
      () async {
        final pdfFile = await repo.importAttachment(
          name: 'General Relativity.pdf',
          bytes: researchPdf(),
        );
        await controller.refresh();

        final canvas = await controller.create(
          'orbit.canvas',
          title: 'Cosmology Board',
        );
        expect(canvas, isNotNull);
        controller.openObject(canvas!.id);

        final ok = await controller.extractPdfQuoteToCanvas(
          'Spacetime tells matter how to move; matter tells spacetime how to curve.',
          7,
          pdfFile.id,
          'General Relativity',
          targetCanvasId: canvas.id,
        );
        expect(ok, isTrue);

        final updated = controller.find(canvas.id);
        expect(updated, isNotNull);
        final scene = CanvasScene.fromJson(updated!.properties);
        expect(scene.elements.length, 1);
        final card = scene.elements.first;

        expect(card.type, 'card');
        expect(card.objectId, pdfFile.id);
        expect(card.cardPresentation, 'transclusion');
        expect(card.data['presentation'], 'transclusion');
        expect(card.data['referenceTarget'], '${pdfFile.id}#page=7');
        expect(card.data['quote'], contains('Spacetime tells matter'));
        expect(card.data['sourceTitle'], 'General Relativity');
        expect(card.data['page'], 7);
        expect(card.text, contains('Spacetime tells matter how to move'));
        expect(card.text, contains('General Relativity, p. 7'));
      },
    );
  });

  group('CanvasEditor PDF Quote Drag & Drop and Double-Click Navigation', () {
    testWidgets(
      'dropping PdfQuoteDragData places card with transclusion presentation and referenceTarget',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        Map<String, dynamic> canvasData = {
          'schemaVersion': 1,
          'elements': <Map<String, dynamic>>[],
        };

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: CanvasEditor(
                canvasId: 'research-board',
                data: canvasData,
                objects: const [],
                onOpenObject: (_) {},
                onChanged: (data) => canvasData = data,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final quote = PdfQuoteDragData(
          objectId: 'pdf-atlas-99',
          title: 'Galactic Dynamics',
          page: 19,
          text:
              'Dark matter halos stabilize spiral galaxy disks against bar instabilities.',
          checksum: 'checksum-atlas-99',
        );

        final dragTargetFinder = find.byType(DragTarget<Object>);
        expect(dragTargetFinder, findsOneWidget);

        final dragTarget = tester.widget<DragTarget<Object>>(dragTargetFinder);
        dragTarget.onAcceptWithDetails?.call(
          DragTargetDetails<Object>(
            data: quote,
            offset: const Offset(300, 250),
          ),
        );
        await tester.pumpAndSettle();

        final elements = canvasData['elements'] as List;
        expect(elements.length, 1);
        final card = elements.first as Map<String, dynamic>;

        expect(card['type'], 'card');
        expect(card['objectId'], 'pdf-atlas-99');
        expect(card['presentation'], 'transclusion');
        expect(card['referenceTarget'], 'pdf-atlas-99#page=19');
        expect(card['checksum'], 'checksum-atlas-99');
        expect(card['page'], 19);
        expect(card['sourceTitle'], 'Galactic Dynamics');
        expect(card['quote'], quote.text);
        expect(
          card['text'],
          contains('Dark matter halos stabilize spiral galaxy disks'),
        );
        expect(card['text'], contains('Galactic Dynamics, p. 19'));
      },
    );

    testWidgets('editing PDF quote card navigates directly to PDF page URL', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final elementData = {
        'id': 'card-quote-1',
        'type': 'card',
        'objectId': 'pdf-doc-55',
        'x': 200.0,
        'y': 200.0,
        'width': 280.0,
        'height': 140.0,
        'text':
            'Entropy increases in closed thermodynamic systems.\n\n— Thermodynamics, p. 15',
        'color': 0xFF8B5CF6,
        'presentation': 'transclusion',
        'referenceTarget': 'pdf-doc-55#page=15',
        'quote': 'Entropy increases in closed thermodynamic systems.',
        'sourceTitle': 'Thermodynamics',
        'page': 15,
        'data': {
          'presentation': 'transclusion',
          'referenceTarget': 'pdf-doc-55#page=15',
          'quote': 'Entropy increases in closed thermodynamic systems.',
          'sourceTitle': 'Thermodynamics',
          'page': 15,
        },
      };

      Map<String, dynamic> canvasData = {
        'schemaVersion': 1,
        'elements': [elementData],
      };

      const pdfObject = CanvasObjectReference(
        id: 'pdf-doc-55',
        typeId: 'orbit.file',
        title: 'Thermodynamics',
        properties: {'mimeType': 'application/pdf'},
      );

      String? openedTarget;

      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'physics-canvas',
              data: canvasData,
              objects: const [pdfObject],
              onOpenObject: (target) => openedTarget = target,
              onChanged: (data) => canvasData = data,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the card center to select it
      await tester.tapAt(const Offset(340, 320));
      await tester.pumpAndSettle();

      // Press Enter to edit/open
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(openedTarget, 'pdf-doc-55#page=15');
    });
  });

  group('CanvasCardPreviewTooltip for PDF Citation Cards', () {
    testWidgets('shows a stale-source warning when the PDF checksum changed', (
      tester,
    ) async {
      final element = CanvasElement({
        'id': 'stale-quote',
        'type': 'card',
        'objectId': 'pdf-stale',
        'x': 0.0,
        'y': 0.0,
        'width': 280.0,
        'height': 140.0,
        'quote': 'A citation from the old source.',
        'sourceTitle': 'Changed paper',
        'page': 4,
        'checksum': 'old-checksum',
      });
      const pdf = CanvasObjectReference(
        id: 'pdf-stale',
        title: 'Changed paper',
        typeId: 'orbit.file',
        properties: {'mimeType': 'application/pdf', 'checksum': 'new-checksum'},
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: CanvasCardPreviewTooltip(
              element: element,
              object: pdf,
              objects: const {'pdf-stale': pdf},
              onOpen: () {},
              onToggleTask: (_) {},
              onCyclePresentation: () {},
              onDismiss: () {},
              onEnterTooltip: () {},
              onExitTooltip: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Source changed · verify citation'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets(
      'renders PDF CITATION badge and quote styling with page navigation',
      (tester) async {
        final element = CanvasElement({
          'id': 'quote-elem-1',
          'type': 'card',
          'objectId': 'pdf-optics-1',
          'x': 50.0,
          'y': 50.0,
          'width': 280.0,
          'height': 140.0,
          'color': 0xFF06B6D4,
          'presentation': 'transclusion',
          'referenceTarget': 'pdf-optics-1#page=24',
          'quote':
              'Fermat’s principle states that light traverses the path of least time.',
          'sourceTitle': 'Wave Optics',
          'page': 24,
          'data': {
            'presentation': 'transclusion',
            'referenceTarget': 'pdf-optics-1#page=24',
            'quote':
                'Fermat’s principle states that light traverses the path of least time.',
            'sourceTitle': 'Wave Optics',
            'page': 24,
          },
        });

        const pdfObject = CanvasObjectReference(
          id: 'pdf-optics-1',
          title: 'Wave Optics',
          typeId: 'orbit.file',
          properties: {'mimeType': 'application/pdf'},
        );

        bool opened = false;
        bool cycled = false;
        bool copied = false;
        bool openedSource = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: CanvasCardPreviewTooltip(
                element: element,
                object: pdfObject,
                objects: const {'pdf-optics-1': pdfObject},
                onOpen: () => opened = true,
                onToggleTask: (_) {},
                onCyclePresentation: () => cycled = true,
                onDismiss: () {},
                onEnterTooltip: () {},
                onExitTooltip: () {},
                onCopyQuote: () async => copied = true,
                onOpenSource: () => openedSource = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify title & badges
        expect(find.text('Wave Optics'), findsOneWidget);
        expect(find.textContaining('PDF CITATION · P. 24'), findsOneWidget);
        expect(find.byIcon(Icons.format_quote_outlined), findsOneWidget);

        // Verify quote text excerpt in container
        expect(
          find.textContaining('Fermat’s principle states that light traverses'),
          findsOneWidget,
        );

        // Verify open button triggers onOpen
        final openBtn = find.byKey(const ValueKey('canvas-card-tooltip-open'));
        expect(openBtn, findsOneWidget);
        await tester.tap(openBtn);
        await tester.pump();
        expect(opened, isTrue);

        await tester.tap(
          find.byKey(const ValueKey('canvas-card-tooltip-copy-quote')),
        );
        await tester.pump();
        expect(copied, isTrue);
        await tester.tap(
          find.byKey(const ValueKey('canvas-card-tooltip-open-source')),
        );
        await tester.pump();
        expect(openedSource, isTrue);

        // Verify presentation cycle button triggers onCyclePresentation
        final cycleBtn = find.byKey(
          const ValueKey('canvas-card-tooltip-cycle-presentation'),
        );
        expect(cycleBtn, findsOneWidget);
        await tester.tap(cycleBtn);
        await tester.pump();
        expect(cycled, isTrue);
      },
    );
  });

  group('OrbitCanvasPainter PDF Quote Presentations Vector Painting', () {
    testWidgets(
      'paints transclusion, preview, card, and compact quote cards without errors',
      (tester) async {
        final elementsData = [
          // 1. Transclusion presentation
          {
            'id': 'quote-trans',
            'type': 'card',
            'objectId': 'pdf-doc',
            'x': 20.0,
            'y': 20.0,
            'width': 300.0,
            'height': 160.0,
            'color': 0xFF8B5CF6,
            'presentation': 'transclusion',
            'referenceTarget': 'pdf-doc#page=3',
            'quote':
                'Observable quantities in quantum mechanics are self-adjoint operators.',
            'sourceTitle': 'Mathematical Foundations',
            'page': 3,
            'data': {
              'presentation': 'transclusion',
              'referenceTarget': 'pdf-doc#page=3',
              'quote':
                  'Observable quantities in quantum mechanics are self-adjoint operators.',
              'sourceTitle': 'Mathematical Foundations',
              'page': 3,
            },
          },
          // 2. Preview presentation
          {
            'id': 'quote-prev',
            'type': 'card',
            'objectId': 'pdf-doc',
            'x': 340.0,
            'y': 20.0,
            'width': 300.0,
            'height': 160.0,
            'color': 0xFF10B981,
            'presentation': 'preview',
            'referenceTarget': 'pdf-doc#page=8',
            'quote': 'Hilbert spaces provide the natural kinematic setting.',
            'sourceTitle': 'Mathematical Foundations',
            'page': 8,
            'data': {
              'presentation': 'preview',
              'referenceTarget': 'pdf-doc#page=8',
              'quote': 'Hilbert spaces provide the natural kinematic setting.',
              'sourceTitle': 'Mathematical Foundations',
              'page': 8,
            },
          },
          // 3. Compact presentation
          {
            'id': 'quote-compact',
            'type': 'card',
            'objectId': 'pdf-doc',
            'x': 20.0,
            'y': 200.0,
            'width': 220.0,
            'height': 48.0,
            'color': 0xFF06B6D4,
            'presentation': 'compact',
            'referenceTarget': 'pdf-doc#page=12',
            'quote': 'Spectral theorem decomposes normal operators.',
            'sourceTitle': 'Mathematical Foundations',
            'page': 12,
            'data': {
              'presentation': 'compact',
              'referenceTarget': 'pdf-doc#page=12',
              'quote': 'Spectral theorem decomposes normal operators.',
              'sourceTitle': 'Mathematical Foundations',
              'page': 12,
            },
          },
          // 4. Default standard card presentation
          {
            'id': 'quote-standard',
            'type': 'card',
            'objectId': 'pdf-doc',
            'x': 260.0,
            'y': 200.0,
            'width': 280.0,
            'height': 140.0,
            'color': 0xFFF59E0B,
            'presentation': 'card',
            'referenceTarget': 'pdf-doc#page=15',
            'quote': 'Unitary time evolution preserves probabilities.',
            'sourceTitle': 'Mathematical Foundations',
            'page': 15,
            'data': {
              'presentation': 'card',
              'referenceTarget': 'pdf-doc#page=15',
              'quote': 'Unitary time evolution preserves probabilities.',
              'sourceTitle': 'Mathematical Foundations',
              'page': 15,
            },
          },
        ];

        final objects = {
          'pdf-doc': const CanvasObjectReference(
            id: 'pdf-doc',
            title: 'Mathematical Foundations',
            typeId: 'orbit.file',
            properties: {'mimeType': 'application/pdf'},
          ),
        };

        final textCache = CanvasTextCache();
        addTearDown(textCache.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: CustomPaint(
                size: const Size(800, 600),
                painter: OrbitCanvasPainter(
                  scene: CanvasScene.fromJson({'elements': elementsData}),
                  camera: const CanvasCamera(x: 0, y: 0, zoom: 1.0),
                  colors: orbitDarkTheme().colorScheme,
                  selection: {},
                  objects: objects,
                  textCache: textCache,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(CustomPaint), findsWidgets);
      },
    );
  });

  group('PDF Panels Draggable<PdfQuoteDragData> Integration', () {
    testWidgets(
      'PdfReviewPanel provides Draggable<PdfQuoteDragData> for highlighted quotes',
      (tester) async {
        final annotationObject = UniversalObject(
          id: 'ann-1',
          workspaceId: 'default',
          typeId: 'orbit.annotation',
          title: 'Important Lemma',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          properties: const {
            'pdfSource': {
              'objectId': 'pdf-doc-1',
              'page': 4,
              'color': 0xFFFFE082,
              'style': 'highlight',
              'quote': 'Every bounded sequence has a convergent subsequence.',
              'checksum': 'checksum-doc-1',
            },
          },
        );

        final annotation = PdfAnnotation(annotationObject);

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 600,
                child: PdfReviewPanel(
                  annotations: [annotation],
                  page: 4,
                  checksum: 'checksum-doc-1',
                  onNavigate: (_) {},
                  onClose: () {},
                  onCopy: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final draggableFinder = find.byType(Draggable<PdfQuoteDragData>);
        expect(draggableFinder, findsOneWidget);

        final draggable = tester.widget<Draggable<PdfQuoteDragData>>(
          draggableFinder,
        );
        expect(
          draggable.data?.text,
          'Every bounded sequence has a convergent subsequence.',
        );
        expect(draggable.data?.page, 4);
        expect(draggable.data?.objectId, 'pdf-doc-1');
        expect(draggable.data?.referenceTarget, 'pdf-doc-1#page=4');
      },
    );

    testWidgets(
      'PdfNotesPanel provides Draggable<PdfQuoteDragData> for notes with anchored quotes',
      (tester) async {
        final noteWithQuote = UniversalObject(
          id: 'note-bolzano',
          workspaceId: 'default',
          typeId: 'orbit.note',
          title: 'Bolzano-Weierstrass Theorem',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          properties: const {
            'pdfSource': {
              'objectId': 'analysis-textbook',
              'page': 18,
              'quote':
                  'Compactness in Euclidean space is equivalent to closed and bounded.',
            },
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: orbitDarkTheme(),
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 600,
                child: PdfNotesPanel(
                  fileId: 'analysis-textbook',
                  checksum: 'dummy-checksum',
                  notes: [noteWithQuote],
                  onOpen: (_) {},
                  onClose: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final draggableFinder = find.byType(Draggable<PdfQuoteDragData>);
        expect(draggableFinder, findsOneWidget);

        final draggable = tester.widget<Draggable<PdfQuoteDragData>>(
          draggableFinder,
        );
        expect(
          draggable.data?.text,
          'Compactness in Euclidean space is equivalent to closed and bounded.',
        );
        expect(draggable.data?.page, 18);
        expect(draggable.data?.objectId, 'analysis-textbook');
        expect(draggable.data?.referenceTarget, 'analysis-textbook#page=18');
      },
    );
  });
}
