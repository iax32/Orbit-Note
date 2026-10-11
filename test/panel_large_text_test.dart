import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/pdf/pdf_notes_panel.dart';
import 'package:orbit_note/features/pdf/pdf_review_panel.dart';

import 'pdf_review_panel_test.dart' show annotation;

Future<void> mount(WidgetTester tester, Widget child, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: orbitDarkTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(2.5)),
        child: child!,
      ),
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pump();
}

void main() {
  for (final size in [const Size(320, 640), const Size(568, 320)]) {
    testWidgets('PDF review actions and stale warning reflow at $size', (
      tester,
    ) async {
      var opened = 0, copied = 0, closed = 0;
      await mount(
        tester,
        PdfReviewPanel(
          annotations: [
            annotation('Long reference title with important source details', 1),
          ],
          page: 1,
          checksum: 'changed',
          onNavigate: (_) => fail('Stale citation must not navigate'),
          onClose: () => closed++,
          onCopy: (items) => copied = items.length,
          onExport: (_) {},
          onSummary: (_) async => true,
          onAnnotatedCopy: (_) {},
          onEdit: (_) => fail('Stale citation must not edit'),
          onOpen: (_) => opened++,
          onOpenSource: () => opened++,
        ),
        size,
      );
      expect(tester.takeException(), isNull);
      await reveal(tester, find.byTooltip('Copy filtered review as Markdown'));
      await tester.tap(find.byTooltip('Copy filtered review as Markdown'));
      expect(copied, 1);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text('PDF version changed · review source before re-anchoring'),
        findsOneWidget,
      );
      await reveal(tester, find.byTooltip('Open current PDF source to verify'));
      await tester.tap(find.byTooltip('Open current PDF source to verify'));
      await reveal(tester, find.byTooltip('Open highlight note and comments'));
      await tester.tap(find.byTooltip('Open highlight note and comments'));
      expect(opened, 2);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 1500));
      await tester.pumpAndSettle();
      await reveal(tester, find.byTooltip('Close highlights'));
      await tester.tap(find.byTooltip('Close highlights'));
      expect(closed, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Connected notes retain readable titles and source warnings at $size',
      (tester) async {
        var opened = 0, created = 0;
        final note = annotation(
          'Long connected note with a descriptive source title',
          1,
        ).object;
        await mount(
          tester,
          PdfNotesPanel(
            notes: [note],
            fileId: 'file',
            checksum: 'changed',
            onOpen: (_) => opened++,
            onClose: () {},
            onCreate: () => created++,
          ),
          size,
        );
        expect(tester.takeException(), isNull);
        await reveal(tester, find.byTooltip('New note at current PDF page'));
        await tester.tap(find.byTooltip('New note at current PDF page'));
        expect(created, 1);
        await reveal(tester, find.byType(TextField));
        await tester.enterText(find.byType(TextField), 'descriptive');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(opened, 1);
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -1000),
        );
        await tester.pumpAndSettle();
        final title = tester.widget<Text>(find.text(note.title));
        expect(title.maxLines, isNull);
        final warning = tester.widget<Text>(
          find.text('Source version changed · review before using'),
        );
        expect(warning.maxLines, isNull);
        await reveal(tester, find.text(note.title));
        await tester.tap(find.text(note.title));
        expect(opened, 2);
        final citation = find.byType(Draggable<PdfQuoteDragData>);
        await reveal(tester, citation);
        final gesture = await tester.startGesture(tester.getCenter(citation));
        await gesture.moveBy(const Offset(30, 15));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Canvas layers preserve commands in a narrow dialog at $size', (
      tester,
    ) async {
      Map<String, dynamic> data = {
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'front',
            'type': 'sticky',
            'text': 'Long architectural design notes for the front layer',
            'x': 10,
            'y': 10,
            'width': 100,
            'height': 100,
          },
          {
            'id': 'back',
            'type': 'rectangle',
            'x': 150,
            'y': 10,
            'width': 100,
            'height': 100,
          },
        ],
      };
      await mount(
        tester,
        CanvasEditor(
          canvasId: 'board',
          data: data,
          objects: const [],
          onOpenObject: (_) {},
          onChanged: (value) => data = value,
        ),
        const Size(1000, 700),
      );
      await tester.tap(find.byTooltip('Layers & element list'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final layer = find.ancestor(
        of: find.text('Rectangle'),
        matching: find.byType(ListTile),
      );
      await tester.scrollUntilVisible(
        find.text('Rectangle'),
        60,
        scrollable: find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Scrollable),
            )
            .last,
      );
      await reveal(tester, layer);
      await tester.tap(layer);
      await tester.pumpAndSettle();
      final hide = find.byTooltip('Hide layer').first;
      await reveal(tester, hide);
      await tester.tap(hide);
      await tester.pumpAndSettle();
      expect(
        (data['elements'] as List).firstWhere(
          (e) => e['id'] == 'back',
        )['hidden'],
        true,
      );
      await reveal(tester, find.byTooltip('Lock layer').first);
      await tester.tap(find.byTooltip('Lock layer').first);
      await tester.pumpAndSettle();
      expect(
        (data['elements'] as List).firstWhere(
          (e) => e['id'] == 'back',
        )['locked'],
        true,
      );
      await reveal(tester, find.text('Show All'));
      await tester.tap(find.text('Show All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unlock All'));
      await tester.pumpAndSettle();
      expect(
        (data['elements'] as List).every(
          (e) => e['hidden'] != true && e['locked'] != true,
        ),
        true,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Layers & Stacking Order'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Canvas citation inspector scrolls all details and actions at $size',
      (tester) async {
        var opened = 0, dismissed = 0;
        final element = CanvasElement({
          'id': 'card',
          'type': 'card',
          'x': 0,
          'y': 0,
          'width': 240,
          'height': 140,
          'sourceId': 'pdf',
          'checksum': 'old',
          'page': 12,
          'sourceTitle':
              'A long architectural source title that must remain readable',
          'quote':
              'A citation with enough content to require scrolling in an enlarged inspector. ' *
              12,
        });
        await mount(
          tester,
          Align(
            alignment: Alignment.topLeft,
            child: CanvasCardPreviewTooltip(
              element: element,
              object: null,
              objects: const {
                'pdf': CanvasObjectReference(
                  id: 'pdf',
                  title: 'Source',
                  typeId: 'orbit.file',
                  properties: {'checksum': 'new'},
                ),
              },
              onOpen: () {},
              onToggleTask: (_) {},
              onCyclePresentation: () {},
              onDismiss: () => dismissed++,
              onEnterTooltip: () {},
              onExitTooltip: () {},
              onCopyQuote: () async {},
              onOpenSource: () => opened++,
            ),
          ),
          size,
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(CanvasCardPreviewTooltip)).width,
          lessThanOrEqualTo(size.width),
        );
        await reveal(tester, find.text('Source changed · verify citation'));
        await reveal(
          tester,
          find.byKey(const ValueKey('canvas-card-tooltip-open-source')),
        );
        await tester.tap(
          find.byKey(const ValueKey('canvas-card-tooltip-open-source')),
        );
        await tester.tap(
          find.byKey(const ValueKey('canvas-card-tooltip-dismiss')),
        );
        expect(opened, 1);
        expect(dismissed, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Canvas task inspector keeps reference and task commands at $size',
      (tester) async {
        var opened = 0;
        String? toggled, clipboard;
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
        const object = CanvasObjectReference(
          id: 'task',
          title: 'Review the architecture and recoverable storage design',
          typeId: 'orbit.task',
          body: 'Detailed project context. ',
          properties: {
            'priority': 'urgent',
            'project': 'Architecture review',
            'dueDate': '2026-10-15',
          },
        );
        await mount(
          tester,
          Align(
            alignment: Alignment.topLeft,
            child: CanvasCardPreviewTooltip(
              element: CanvasElement({
                'id': 'card',
                'type': 'card',
                'objectId': 'task',
                'x': 0,
                'y': 0,
                'width': 240,
                'height': 140,
              }),
              object: object,
              objects: const {'task': object},
              onOpen: () => opened++,
              onToggleTask: (id) => toggled = id,
              onCyclePresentation: () {},
              onDismiss: () {},
              onEnterTooltip: () {},
              onExitTooltip: () {},
            ),
          ),
          size,
        );
        expect(tester.takeException(), isNull);
        final toggle = find.byKey(
          const ValueKey('canvas-card-tooltip-toggle-action'),
        );
        await reveal(tester, toggle);
        await tester.tap(toggle);
        expect(toggled, 'task');
        final copy = find.byKey(
          const ValueKey('canvas-card-tooltip-copy-link'),
        );
        await reveal(tester, copy);
        await tester.tap(copy);
        await tester.pump();
        expect(clipboard, '[[task|${object.title}]]');
        final open = find.byKey(
          const ValueKey('canvas-card-tooltip-open-button'),
        );
        await reveal(tester, open);
        await tester.tap(open);
        expect(opened, 1);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }
}
