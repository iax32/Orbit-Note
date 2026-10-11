import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/domain/pdf_quote_transfer.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';
import 'support/pdf_fixture.dart';

void main() {
  group('PdfQuoteDragData Model', () {
    test('formats citation and markdownQuote properly', () {
      final data = PdfQuoteDragData(
        objectId: 'doc-456',
        title: 'Quantum Computing',
        page: 12,
        text: 'Superposition allows quantum parallelism.',
        checksum: 'sha256-abc',
      );

      expect(data.citation, 'Quantum Computing · p. 12');
      expect(
        data.markdownQuote,
        '> Superposition allows quantum parallelism.\n\n[[doc-456#page=12|Quantum Computing · p. 12]]\n',
      );

      final json = data.toJson();
      final revived = PdfQuoteDragData.fromJson(json);
      expect(revived.objectId, data.objectId);
      expect(revived.title, data.title);
      expect(revived.page, data.page);
      expect(revived.text, data.text);
      expect(revived.checksum, data.checksum);
    });
  });

  group('WorkspaceController PDF Quote Extraction', () {
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

    test('extractPdfQuoteToActiveNote appends quote to active note', () async {
      final pdfFile = await repo.importAttachment(
        name: 'Transformer Paper.pdf',
        bytes: researchPdf(),
      );
      await controller.refresh();

      final note = await controller.create(
        'orbit.note',
        title: 'My Research Note',
      );
      expect(note, isNotNull);
      controller.openObject(note!.id);

      final ok = await controller.extractPdfQuoteToActiveNote(
        'Attention is all you need.',
        5,
        pdfFile.id,
        'Transformer Paper',
      );
      expect(ok, isTrue);

      final updated = controller.find(note.id);
      expect(updated, isNotNull);
      expect(updated!.body, contains('> Attention is all you need.'));
      expect(
        updated.body,
        contains('[[${pdfFile.id}#page=5|Transformer Paper · p. 5]]'),
      );
    });

    test(
      'extractPdfQuoteToActiveNote returns false if no active note',
      () async {
        final pdfFile = await repo.importAttachment(
          name: 'Some Doc.pdf',
          bytes: researchPdf(),
        );
        await controller.refresh();
        controller.session.activeId = null;

        final ok = await controller.extractPdfQuoteToActiveNote(
          'Some orphaned quote',
          1,
          pdfFile.id,
          'Some Doc',
        );
        expect(ok, isFalse);
      },
    );

    test('extractPdfQuoteToCanvas adds card to existing canvas', () async {
      final pdfFile = await repo.importAttachment(
        name: 'GNN Survey.pdf',
        bytes: researchPdf(),
      );
      await controller.refresh();

      final canvas = await controller.create(
        'orbit.canvas',
        title: 'Brainstorm Canvas',
      );
      expect(canvas, isNotNull);
      controller.openObject(canvas!.id);

      final ok = await controller.extractPdfQuoteToCanvas(
        'Graph neural networks generalize convolutions to non-Euclidean data.',
        8,
        pdfFile.id,
        'GNN Survey',
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
      expect(card.text, contains('Graph neural networks generalize'));
      expect(card.text, contains('GNN Survey, p. 8'));
    });

    test('extractPdfQuoteToCanvas creates new canvas if none exists', () async {
      final pdfFile = await repo.importAttachment(
        name: 'RLHF Guide.pdf',
        bytes: researchPdf(),
      );
      await controller.refresh();

      expect(controller.ofType('orbit.canvas').isEmpty, isTrue);

      final ok = await controller.extractPdfQuoteToCanvas(
        'Reinforcement learning from human feedback.',
        2,
        pdfFile.id,
        'RLHF Guide',
      );
      expect(ok, isTrue);

      final canvases = controller.ofType('orbit.canvas');
      expect(canvases.length, 1);
      final scene = CanvasScene.fromJson(canvases.first.properties);
      expect(scene.elements.length, 1);
      expect(scene.elements.first.text, contains('Reinforcement learning'));
      expect(scene.elements.first.text, contains('RLHF Guide, p. 2'));
    });
  });

  group('RichMarkdownEditor Drag & Drop', () {
    testWidgets('dropping PdfQuoteDragData inserts quote into editor', (
      tester,
    ) async {
      String currentBody = '# Intro\n\nSome text';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichMarkdownEditor(
              body: currentBody,
              onChanged: (newBody) => currentBody = newBody,
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

      final dragTargetFinder = find.byType(DragTarget<PdfQuoteDragData>);
      expect(dragTargetFinder, findsOneWidget);

      final dragTarget = tester.widget<DragTarget<PdfQuoteDragData>>(
        dragTargetFinder,
      );
      final quote = PdfQuoteDragData(
        objectId: 'pdf-99',
        title: 'Quantum Supremacy',
        page: 3,
        text: 'Quantum supremacy achieved in 2019.',
      );

      dragTarget.onAcceptWithDetails?.call(
        DragTargetDetails<PdfQuoteDragData>(
          data: quote,
          offset: const Offset(100, 100),
        ),
      );
      await tester.pumpAndSettle();

      expect(currentBody, contains('> Quantum supremacy achieved in 2019.'));
      expect(
        currentBody,
        contains('[[pdf-99#page=3|Quantum Supremacy · p. 3]]'),
      );
    });
  });
}
