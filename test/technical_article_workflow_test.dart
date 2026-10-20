import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/canvas/canvas_svg.dart';
import 'package:orbit_note/canvas/diagram_reference.dart';
import 'package:orbit_note/canvas/research_diagrams.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/domain/document_publication.dart';
import 'package:orbit_note/domain/note_composition.dart';
import 'package:orbit_note/domain/publication_layout.dart';
import 'package:orbit_note/domain/technical_article.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/features/canvas/research_diagram_dialog.dart';
import 'package:orbit_note/features/notes/article_publishing_dialog.dart';
import 'package:orbit_note/features/notes/export/publication_export.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/note_templates.dart';
import 'package:orbit_note/features/notes/technical_article_template_dialog.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'support/capture_ui.dart';
import 'support/memory_store.dart';

Widget host(Widget child, {double scale = 1}) => RepaintBoundary(
  child: MaterialApp(
    theme: orbitDarkTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(body: child),
  ),
);
Future<void> size(
  WidgetTester tester, [
  Size value = const Size(1280, 1000),
]) async {
  tester.view.physicalSize = value;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ArticleMetadata metadata([Map<String, dynamic> extra = const {}]) =>
    ArticleMetadata({
      'version': 1,
      'title': 'A measured memory layout',
      'description': 'An original experiment with a reproducible sample.',
      'author': 'Ada Researcher',
      'canonicalUrl': 'https://example.org/research/memory-layout/',
      'language': 'en',
      ...extra,
    });
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'article settings preserve authored CRLF, unfamiliar fields and print settings',
    () {
      final original = PublicationSettings.update(
        '# Paper\r\n\r\nAuthored prose.\r\n',
        {'author': 'Print author', 'futureStyle': 7},
        {},
      );
      final source = metadata({
        'futureArticle': {'keep': true},
      }).apply(original);
      final edited = metadata({
        'description': 'A revised explanation.',
      }).apply(source);
      final saved = PublicationSettings.update(edited, {'margin': 72}, {});
      expect(ArticleMetadata.fromSource(saved)!.data['futureArticle'], {
        'keep': true,
      });
      expect(
        ArticleMetadata.fromSource(saved)!.text('description'),
        'A revised explanation.',
      );
      expect(
        PublicationSettings.parse(saved)!.data['style'],
        containsPair('futureStyle', 7),
      );
      expect(
        saved.substring(PublicationSettings.parse(saved)!.end),
        '# Paper\r\n\r\nAuthored prose.\r\n',
      );
    },
  );
  test('future and malformed article records cannot be overwritten', () {
    for (final value in [
      {'version': 2, 'future': true},
      'unknown',
    ]) {
      final source = PublicationSettings.update(
        '# Keep',
        {},
        {},
        article: value is Map
            ? Map<String, dynamic>.from(value)
            : {'version': 'unknown'},
      );
      expect(() => metadata().apply(source), throwsFormatException);
      final doc = PublicationDocument.parse(
        'Keep',
        source,
        const PublicationStyle(),
      );
      expect(doc.article, isNull);
      expect(doc.warnings.join(), contains('Unsupported article metadata'));
      expect(source, anyOf(contains('unknown'), contains('future')));
    }
    expect(
      () => metadata().apply('<!-- orbit:publication broken -->\n# Keep'),
      throwsFormatException,
    );
  });
  test('article URLs, real dates, widths and scripts are validated', () {
    for (final url in [
      'javascript:alert(1)',
      'data:text/html,bad',
      'https://u:p@example.org/',
      '/relative',
      'https://example.org/a b',
    ]) {
      expect(() => metadata({'canonicalUrl': url}), throwsFormatException);
    }
    for (final date in ['2026-02-30', '2025-02-29', 'now', '2026-1-1']) {
      expect(() => metadata({'published': date}), throwsFormatException);
    }
    expect(
      () => metadata({'published': '2026-10-17', 'modified': '2026-10-16'}),
      throwsFormatException,
    );
    expect(
      metadata({'published': '2024-02-29'}).text('published'),
      '2024-02-29',
    );
    expect(
      () => metadata({'language': 'en" onload=bad'}),
      throwsFormatException,
    );
    final raw = metadata({
      'title': '</script><script>bad()</script>',
      'author': 'A & B',
    }).schemaJson('Title');
    expect(raw, isNot(contains('</script>')));
    expect(jsonDecode(raw)['headline'], contains('bad()'));
  });
  test(
    'standalone HTML has honest metadata; CMS fragment omits document chrome and duplicate title',
    () {
      final settings = metadata({
        'published': '2026-10-17',
        'indexable': false,
        'description': 'A "quote" & example.',
      });
      final document = PublicationDocument.parse(
        'Paper',
        settings.apply(
          '# Paper\n\n## Experiment\n\nMeasured prose.\n\n```cpp\nint value = 1;\n```',
        ),
        const PublicationStyle(),
      );
      final export = PublicationExport(document), html = export.html();
      expect(html, contains('rel="canonical"'));
      expect(html, contains('name="robots" content="noindex,nofollow"'));
      expect(html, contains('application/ld+json'));
      expect(html, contains('A &quot;quote&quot; &amp; example.'));
      expect(html, contains('Published <time'));
      expect(html, isNot(contains('dateModified')));
      expect(html, isNot(contains('name="keywords"')));
      final cms = export.html(articleFragment: true);
      expect(cms, contains(RegExp(r'<article[ >]')));
      expect(cms, contains('int value = 1;'));
      for (final forbidden in ['<head', '<script', '<style', '<h1', '<meta']) {
        expect(cms, isNot(contains(forbidden)));
      }
      expect(settings.cmsHandoff('Paper'), contains('Manual Actions'));
      expect(
        settings.cmsHandoff('Paper'),
        contains('Avoid duplicate Article schema'),
      );
    },
  );
  test(
    'editorial checks ignore code and identify missing text alternatives and private links',
    () {
      final checks = articleChecks(
        'Paper',
        '## Evidence\n\n![](image.png)\n\n[Source](orbit:private)\n\n```text\n[TODO] ![](example)\n```',
        metadata(),
      );
      expect(checks.join(), contains('1 image(s)'));
      expect(checks.join(), contains('private Vault links'));
      expect(checks.join(), isNot(contains('unfinished template')));
      expect(
        articleChecks('Paper', '[TODO: replace]', metadata()).join(),
        contains('unfinished template'),
      );
      expect(
        articleChecks(
          'Paper',
          diagramMarkdown('board', 'Evidence', ['shape']),
          metadata(),
        ).join(),
        contains('private Vault links'),
      );
      expect(
        articleChecks(
          'Paper',
          '```text\n[[literal example]]\n```',
          metadata(),
        ).join(),
        isNot(contains('private Vault links')),
      );
    },
  );
  test(
    'address calculations are exact across 32/64-bit limits and endian bytes',
    () {
      final value = AddressCalculation('0x140000000', '1234');
      expect(value.hex, '0x0000000140001234');
      expect(value.littleEndian, '34 12 00 40 01 00 00 00');
      expect(
        AddressCalculation('FFFFFFFFFFFFFFFF', '0').hex,
        '0xFFFFFFFFFFFFFFFF',
      );
      expect(AddressCalculation('FFFFFFFF', '0', bits: 32).hex, '0xFFFFFFFF');
      for (final pair in [
        ('FFFFFFFFFFFFFFFF', '1'),
        ('-1', '0'),
        ('10000000000000000', '0'),
        ('hi', '0'),
      ]) {
        expect(
          () => AddressCalculation(pair.$1, pair.$2),
          throwsFormatException,
        );
      }
      expect(
        () => AddressCalculation('100000000', '0', bits: 32),
        throwsFormatException,
      );
      expect(value.markdown, contains('does not resolve a pointer'));
    },
  );
  test(
    'all research diagrams use editable nodes, attached connectors and precise live references',
    () {
      for (final kind in ResearchDiagramKind.values) {
        var id = 0;
        final elements = researchDiagram(kind, () => 'node-${id++}');
        final scene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': elements.map((e) => e.data).toList(),
        });
        expect(scene.readOnly, isFalse);
        expect(scene.elementsInOrder, hasLength(5));
        final ids = diagramExportSelection(scene, const []);
        expect(ids, hasLength(3));
        final block = NoteObjectBlock.parse(
          diagramMarkdown('source', 'Recorded diagram', ids),
        )!;
        final resolved = ResolvedCanvasDiagram(
          scene,
          diagramElementIds(block.reference)!,
        );
        expect(resolved.scene.elementsInOrder, hasLength(5));
        expect(canvasToSvg(resolved.scene), contains('<svg'));
        expect(
          elements
              .where((e) => e.type == 'arrow')
              .every((e) => ids.contains(e.startId) && ids.contains(e.endId)),
          isTrue,
        );
        expect(diagramExportSelection(scene, [elements.last.id]), hasLength(2));
      }
    },
  );
  test(
    'article notes and research diagram references survive native restart without copied content',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'orbit-technical-article-',
      );
      WorkspaceRepository? repo;
      WorkspaceController? controller;
      try {
        repo = WorkspaceRepository(
          store: NativeWorkspaceStore(),
          index: MemoryObjectIndex(),
        );
        await repo.initialize(path: root.path);
        controller = WorkspaceController()
          ..repository = repo
          ..hasWorkspace = true
          ..loading = false;
        var id = 0;
        final board = (await controller.create(
          'orbit.canvas',
          open: false,
          title: 'Evidence',
          data: {
            'schemaVersion': 1,
            'future': {'keep': true},
            'elements': researchDiagram(
              ResearchDiagramKind.pointerChain,
              () => 'p${id++}',
            ).map((e) => e.data).toList(),
          },
        ))!;
        final note = (await controller.exportCanvasDiagramToNote(board, [
          'p0',
          'p1',
          'p2',
        ], title: 'Research article'))!;
        controller.edit(note.id, body: metadata().apply(note.body));
        await controller.flushAll();
        final expected = controller.find(note.id)!.body;
        controller.cancelAllTimers();
        await repo.close();
        repo = WorkspaceRepository(
          store: NativeWorkspaceStore(),
          index: MemoryObjectIndex(),
        );
        await repo.initialize(path: root.path);
        final restored = repo.objects.singleWhere((o) => o.id == note.id);
        expect(restored.body, expected);
        expect(
          ArticleMetadata.fromSource(restored.body)!.text('author'),
          'Ada Researcher',
        );
        expect(
          repo.objects.singleWhere((o) => o.id == board.id).data['future'],
          {'keep': true},
        );
      } finally {
        controller?.cancelAllTimers();
        await repo?.close();
        await root.delete(recursive: true);
      }
    },
  );
  testWidgets(
    'configurable article template records supplied context and portable metadata',
    (tester) async {
      await size(tester);
      NoteTemplate? result;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<NoteTemplate>(
                  context: context,
                  builder: (_) => TechnicalArticleTemplateDialog(
                    template: NoteTemplates.byId('article_memory')!,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tapVisible(tester, find.text('Open'));
      await tester.enterText(
        find.byKey(const ValueKey('article-template-Article title')),
        'My measured layout',
      );
      await tester.enterText(
        find.byKey(const ValueKey('article-template-Build / version')),
        'demo-42',
      );
      await tapVisible(tester, find.text('Create article'));
      expect(result!.body, contains('demo-42'));
      expect(result!.body, contains('Observed layout'));
      expect(
        ArticleMetadata.fromSource(result!.body)!.text('title'),
        'My measured layout',
      );
      expect(
        NoteTemplates.search(
          'reverse engineering',
        ).where((t) => t.id.startsWith('article_')).length,
        3,
      );
    },
  );
  testWidgets(
    'inserting an article section retains details without adding a misplaced metadata header',
    (tester) async {
      await size(tester);
      NoteTemplate? result;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<NoteTemplate>(
                  context: context,
                  builder: (_) => TechnicalArticleTemplateDialog(
                    template: NoteTemplates.byId('article_reverse')!,
                    insertMode: true,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tapVisible(tester, find.text('Open'));
      await tester.enterText(
        find.byKey(const ValueKey('article-template-Author')),
        'Ada',
      );
      await tapVisible(tester, find.text('Create article'));
      expect(result!.body, contains('**Author:** Ada'));
      expect(result!.body, isNot(contains(PublicationSettings.prefix)));
    },
  );
  testWidgets(
    'Canvas research preset inserts as one undoable change and copies a live diagram',
    (tester) async {
      await size(tester);
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        host(
          CanvasEditor(
            canvasId: 'board',
            data: const {'schemaVersion': 1, 'elements': []},
            onChanged: (_) {},
            objects: const [],
            onOpenObject: (_) {},
          ),
        ),
      );
      await tapVisible(tester, find.byTooltip('Shapes and diagrams'));
      await tapVisible(tester, find.text('Memory & research diagram…'));
      await tapVisible(tester, find.text('Insert diagram'));
      // The same painter/scene is used by the existing Canvas keyboard commands.
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<OrbitCanvasPainter>()
          .single;
      expect(painter.scene.elementsInOrder, hasLength(5));
      await tapVisible(tester, find.byTooltip('Shapes and diagrams'));
      await tapVisible(tester, find.text('Copy live diagram for Markdown'));
      expect(NoteObjectBlock.parse(clipboard!), isNotNull);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      final after = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<OrbitCanvasPainter>()
          .single;
      expect(after.scene.elementsInOrder, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'publishing dialog refuses stale application and retains metadata for retry',
    (tester) async {
      await size(tester);
      var attempts = 0;
      await tester.pumpWidget(
        host(
          ArticlePublishingDialog(
            title: 'Paper',
            source: '# Paper\n\nOriginal.',
            onApply: (_, _) {
              attempts++;
              return false;
            },
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('article-author')),
        'Ada',
      );
      await tapVisible(tester, find.text('Apply to note'));
      expect(attempts, 1);
      expect(find.textContaining('The note changed'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('article-author')))
            .controller!
            .text,
        'Ada',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'note research tool creates one linked Canvas with inherited context',
    (tester) async {
      await size(tester);
      final repo = WorkspaceRepository(
        store: MemoryStore(),
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      final controller = WorkspaceController()
        ..repository = repo
        ..hasWorkspace = true
        ..loading = false;
      final note = (await controller.create(
        'orbit.note',
        title: 'Investigation',
        open: false,
        properties: {'project': null, 'courseId': 'course-demo'},
      ))!;
      var body = '';
      try {
        await tester.pumpWidget(
          host(
            StatefulBuilder(
              builder: (context, setState) => NoteEditor(
                noteId: note.id,
                title: note.title,
                body: body,
                controller: controller,
                allObjects: controller.objects,
                linkTargets: const [],
                onOpenObject: (_) {},
                onTitleChanged: (_) {},
                initialViewState: const {'mode': 'write'},
                spellCheckEnabled: false,
                onBodyChanged: (value) {
                  controller.edit(note.id, body: value);
                  setState(() => body = value);
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tapVisible(tester, find.byTooltip('Writing tools'));
        await tapVisible(tester, find.text('Research diagram'));
        await tapVisible(tester, find.text('Insert diagram'));
        final block = NoteObjectBlock.parse(body.trim())!;
        final board = controller.find(block.id)!;
        expect(board.typeId, 'orbit.canvas');
        expect(board.properties['sourceNoteId'], note.id);
        expect(board.properties['courseId'], 'course-demo');
        expect(
          controller.objects.where((o) => o.typeId == 'orbit.canvas'),
          hasLength(1),
        );
        expect(diagramElementIds(block.reference), hasLength(3));
        expect(body, isNot(contains('Base: 0x140000000')));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await controller.flushAll();
      } finally {
        controller.cancelAllTimers();
        await repo.close();
      }
    },
  );
  testWidgets('CMS handoff stays reachable at narrow width with doubled text', (
    tester,
  ) async {
    await size(tester, const Size(390, 850));
    await prepareCapture(tester);
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      host(
        ArticlePublishingDialog(
          title: 'Paper',
          source: metadata().apply('# Paper\n\nMeasured content.'),
        ),
        scale: 2,
      ),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Copy CMS handoff'));
    expect(clipboard, contains('CMS publishing handoff'));
    expect(tester.takeException(), isNull);
    await captureUi(tester, 'technical-article-cms-large-text');
  });
  testWidgets(
    'research calculator inserts Markdown without requiring a Canvas',
    (tester) async {
      await size(tester);
      ResearchDiagramChoice? result;
      await prepareCapture(tester);
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showResearchDiagramDialog(
                  context,
                  allowCalculation: true,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tapVisible(tester, find.text('Open'));
      await captureUi(tester, 'technical-research-diagram-preset');
      await tester.enterText(find.byKey(const ValueKey('address-rva')), '20');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Insert calculation'));
      expect(result!.calculation, contains('0x0000000140000020'));
      expect(tester.takeException(), isNull);
    },
  );
}
