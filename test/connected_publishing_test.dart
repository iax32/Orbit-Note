import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/document_publication.dart';
import 'package:orbit_note/domain/note_composition.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/canvas/diagram_reference.dart';
import 'package:orbit_note/canvas/connectors.dart';
import 'package:orbit_note/features/notes/export/publication_canvas.dart';
import 'package:orbit_note/features/notes/export/publication_export.dart';
import 'package:orbit_note/features/notes/export/publication_workspace.dart';
import 'package:pdfrx/pdfrx.dart';
import 'support/pdf_fixture.dart';

UniversalObject object(
  String id,
  String type, {
  String? title,
  String body = '',
  String workspace = 'w',
  Map<String, dynamic> properties = const {},
  Map<String, dynamic> data = const {},
}) => UniversalObject(
  id: id,
  workspaceId: workspace,
  typeId: type,
  title: title ?? id,
  body: body,
  properties: properties,
  data: data,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026, 10, 22),
  revision: 7,
);
final board = object(
  'board',
  'orbit.canvas',
  title: 'Mechanics blueprint',
  data: {
    'schemaVersion': 1,
    'backgroundStyle': 'blueprint_classic',
    'elements': [
      {
        'id': 'player',
        'type': 'rectangle',
        'x': 10,
        'y': 10,
        'width': 260,
        'height': 160,
        'text': 'Player',
        'color': 0xffeeeeee,
        'uml': {
          'attributes': ['+ speed: float'],
          'operations': ['+ move(dt): void'],
        },
      },
      {
        'id': 'controller',
        'type': 'rectangle',
        'x': 370,
        'y': 10,
        'width': 260,
        'height': 160,
        'text': 'Controller',
        'color': 0xffeeeeee,
        'uml': {
          'attributes': ['- input: Vector2'],
          'operations': ['+ tick(): void'],
        },
      },
      {
        'id': 'edge',
        'type': 'connector',
        'startId': 'player',
        'endId': 'controller',
        'routing': 'elbow',
        'startMultiplicity': '1',
        'endMultiplicity': '1',
        'color': 0xffeeeeee,
      },
      {
        'id': 'outside',
        'type': 'sticky',
        'x': 1000,
        'y': 300,
        'width': 220,
        'height': 120,
        'text': 'UNSELECTED_SECRET',
      },
      {
        'id': 'hidden',
        'type': 'text',
        'x': 0,
        'y': 700,
        'width': 300,
        'height': 60,
        'text': 'HIDDEN_SECRET',
        'hidden': true,
      },
    ],
  },
);
PublicationDocument publish(
  String source,
  List<UniversalObject> objects, {
  String owner = 'owner',
  bool canvasDetails = false,
  Map<String, String> paths = const {},
}) => PublicationDocument.parse(
  'Connected report',
  source,
  PublicationStyle(contents: false, canvasDetails: canvasDetails),
  ownerId: owner,
  objects: objects,
  objectPaths: paths,
  snapshotTime: DateTime.utc(2026, 10, 22),
);
Future<String> pdfText(Uint8List bytes) async {
  expect(await initPdfTesting(), true);
  final pdf = await PdfDocument.openData(bytes);
  try {
    return (await Future.wait(
      pdf.pages.map((p) => p.loadText()),
    )).map((p) => p!.fullText).join('\n');
  } finally {
    await pdf.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Segoe UI')
      ..addFont(rootBundle.load('assets/publishing/Lato-Regular.ttf'));
    await loader.load();
  });
  test(
    'task and collection snapshots preserve source identity, status and scoped membership',
    () async {
      final owner = object('owner', 'orbit.note');
      final task = object(
        'fix',
        'orbit.task',
        title: 'Fix camera',
        body: 'Reproduce jitter\nVerify smooth motion.',
        properties: {
          'completed': true,
          'dueDate': '2026-10-24',
          'priority': 'high',
          'token': 'NEVER_EXPORT_SECRET',
        },
      );
      final outside = object(
        'foreign',
        'orbit.task',
        workspace: 'other',
        title: 'FOREIGN_SECRET',
      );
      final view = object(
        'tasks',
        'orbit.view',
        title: 'Release checks',
        properties: {
          'memberIds': ['fix', 'foreign'],
        },
      );
      final source =
          '${const NoteObjectBlock('fix', 'Task').encode()}\n${const NoteObjectBlock('tasks', 'Collection').encode()}';
      final original = task.toJson().toString();
      final doc = publish(source, [owner, task, view, outside]);
      final export = PublicationExport(doc);
      final output = await export.pdf();
      await Directory('tmp/pdfs').create(recursive: true);
      await File('tmp/pdfs/connected-cards-review.pdf').writeAsBytes(output);
      final text = await pdfText(output);
      for (final value in [
        'Fix camera',
        'Completed',
        '2026-10-24',
        'high',
        'Reproduce jitter',
        'Release checks',
        '1 item(s)',
        'orbit-object:fix',
        'revision 7',
      ]) {
        expect(text, contains(value));
      }
      expect(text, isNot(contains('FOREIGN_SECRET')));
      expect(text, isNot(contains('NEVER_EXPORT_SECRET')));
      expect(export.html(), contains('Collection snapshot'));
      final zip = ZipDecoder().decodeBytes(export.docx());
      expect(
        utf8.decode(zip.findFile('word/document.xml')!.content),
        contains('Fix camera'),
      );
      expect(task.toJson().toString(), original);
      expect(source, contains('<!-- orbit:object v=1 -->'));
    },
  );
  test(
    'precise Canvas snapshots include selected UML nodes and their relation only',
    () {
      final source = diagramMarkdown(board.id, 'Player and controller', [
        'player',
        'controller',
      ]);
      final doc = publish(source, [board], canvasDetails: true);
      final canvas = doc.objectSnapshots.canvases.values.single;
      expect(
        canvas.scene.elements.map((e) => e.id),
        containsAll(['player', 'controller', 'edge']),
      );
      expect(canvas.scene.length, 3);
      final text = doc.nodes.map((n) => n.textContent).join();
      expect(text, contains('speed: float'));
      expect(text, isNot(contains('UNSELECTED_SECRET')));
      expect(text, isNot(contains('HIDDEN_SECRET')));
      expect(text, contains('orbit-object:board#elements='));
    },
  );
  test(
    'unavailable, deleted, ambiguous and foreign sources retain labelled references',
    () {
      final owner = object('owner', 'orbit.note');
      final source = const NoteObjectBlock('x', 'Missing record').encode();
      final foreign = object(
        'x',
        'orbit.task',
        workspace: 'other',
        body: 'FOREIGN_SECRET',
      );
      final deleted = object(
        'x',
        'orbit.task',
      ).copyWith(deletedAt: DateTime.utc(2026));
      for (final values in [
        [owner, foreign],
        [owner, deleted],
        [owner, object('x', 'orbit.task'), object('x', 'orbit.task')],
      ]) {
        final doc = publish(source, values);
        final text = doc.nodes.map((n) => n.textContent).join();
        expect(text, contains('Source unavailable'));
        expect(text, contains('orbit-object:x'));
        expect(text, isNot(contains('FOREIGN_SECRET')));
        expect(doc.warnings.any((w) => w.contains('unavailable')), true);
      }
    },
  );
  test(
    'future/missing Canvas selections never broaden to the entire board',
    () {
      for (final fragment in [
        'elements=%5B%22missing%22%5D',
        'future=abc',
        'page=2',
      ]) {
        final source = NoteObjectBlock(
          'board',
          'Diagram',
          fragment: fragment,
        ).encode();
        final doc = publish(source, [board]);
        expect(doc.objectSnapshots.canvases, isEmpty);
        expect(
          doc.nodes.map((n) => n.textContent).join(),
          isNot(contains('UNSELECTED_SECRET')),
        );
        expect(
          doc.warnings.any((w) => w.contains('Canvas preview unavailable')),
          true,
        );
      }
    },
  );
  test(
    'literal object syntax, unsupported formats and note-private metadata stay safe',
    () {
      final raw = const NoteObjectBlock('secret', 'Note').encode();
      final source = '```markdown\n$raw```\n\n$raw';
      final secret = object(
        'secret',
        'orbit.note',
        body: '---\npassword: PRIVATE_SECRET\n---\nNOTE_BODY',
      );
      final doc = publish(source, [secret]);
      expect(doc.objectSnapshots.objectCount, 1);
      final text = doc.nodes.map((n) => n.textContent).join();
      expect(text, contains('<!-- orbit:object v=1 -->'));
      expect(text, isNot(contains('PRIVATE_SECRET')));
      expect(text, isNot(contains('NOTE_BODY')));
      final future = board.copyWith(data: {...board.data, 'schemaVersion': 9});
      expect(
        publish(const NoteObjectBlock('board', 'Board').encode(), [
          future,
        ]).objectSnapshots.canvases,
        isEmpty,
      );
    },
  );
  test(
    'collection queries use captured paths, invalid queries have explicit fallback',
    () {
      final a = object('a', 'orbit.task', properties: {'completed': false});
      final b = object('b', 'orbit.task');
      final view = object(
        'view',
        'orbit.view',
        properties: {'folder': 'Notes/Engineering'},
      );
      final source = const NoteObjectBlock('view', 'Collection').encode();
      final doc = publish(
        source,
        [a, b, view],
        paths: {'a': 'Notes/Engineering/a.md', 'b': 'Notes/Personal/b.md'},
      );
      final text = doc.nodes.map((n) => n.textContent).join();
      expect(text, contains('1 item(s)'));
      expect(text, contains('orbit-object:a'));
      expect(text, isNot(contains('orbit-object:b')));
      final invalid = view.copyWith(
        properties: {
          'smartQuery': {'version': 99},
        },
      );
      expect(
        publish(source, [
          a,
          invalid,
        ]).warnings.any((w) => w.contains('could not resolve')),
        true,
      );
    },
  );
  test(
    'static render reuses Canvas painter and embeds in PDF HTML and Word',
    () async {
      final doc = publish(
        diagramMarkdown('board', 'Mechanics', ['player', 'controller']),
        [board],
      );
      final snapshot = doc.objectSnapshots.canvases.values.single;
      final warnings = <String>[];
      final png = await renderPublicationCanvas(
        snapshot,
        objects: [board],
        warn: warnings.add,
      );
      expect(png, isNotNull);
      final size = ByteData.sublistView(png!);
      expect(size.getUint32(16), lessThanOrEqualTo(1600));
      expect(size.getUint32(20), lessThanOrEqualTo(1600));
      final export = PublicationExport(doc, images: {snapshot.key: png});
      final bytes = await export.pdf();
      final text = await pdfText(bytes);
      expect(text, isNot(contains('Canvas contents')));
      expect(text, isNot(contains('Source:')));
      expect(text, isNot(contains('orbit-object:')));
      expect(doc.objectSnapshots.canvases, hasLength(1));
      final detailed = PublicationDocument.parse(
        'Detailed',
        diagramMarkdown('board', 'Mechanics', ['player', 'controller']),
        const PublicationStyle(canvasDetails: true),
        objects: [board],
      );
      final detailedText = await pdfText(
        await PublicationExport(detailed, images: {snapshot.key: png}).pdf(),
      );
      expect(detailedText, contains('Canvas contents'));
      expect(detailedText, contains('Source:'));
      expect(detailedText, contains('Player'));
      expect(PublicationStyle.fromJson({}).canvasDetails, false);
      expect(
        PublicationStyle.fromJson(
          const PublicationStyle(canvasDetails: true).toJson(),
        ).canvasDetails,
        true,
      );
      expect(text, isNot(contains('[Image:')));
      expect(export.html(), contains('data:image/png;base64,'));
      final zip = ZipDecoder().decodeBytes(export.docx());
      expect(zip.findFile('word/media/image1.png'), isNotNull);
      await Directory('tmp/pdfs').create(recursive: true);
      await File(
        'tmp/pdfs/connected-publishing-review.pdf',
      ).writeAsBytes(bytes);
      await File('tmp/pdfs/connected-canvas-review.png').writeAsBytes(png);
    },
  );
  test(
    'Canvas attachments stay local and failure retains a useful static preview',
    () async {
      final data = {
        'schemaVersion': 1,
        'elements': [
          {
            'id': 'local',
            'type': 'image',
            'x': 0,
            'y': 0,
            'width': 200,
            'height': 100,
            'contentRef': 'Attachments/missing.png',
          },
          {
            'id': 'external',
            'type': 'image',
            'x': 220,
            'y': 0,
            'width': 200,
            'height': 100,
            'contentRef': 'https://example.com/private.png',
          },
        ],
      };
      final source = object('images', 'orbit.canvas', data: data);
      final snapshot = publish(
        const NoteObjectBlock('images', 'Images').encode(),
        [source],
      ).objectSnapshots.canvases.values.single;
      final reads = <String>[], warnings = <String>[];
      final png = await renderPublicationCanvas(
        snapshot,
        objects: [source],
        warn: warnings.add,
        readImage: (path) async {
          reads.add(path);
          return null;
        },
      );
      expect(png, isNotNull);
      expect(reads, ['Attachments/missing.png']);
      expect(warnings.where((w) => w.contains('placeholder')).length, 2);
    },
  );
  testWidgets(
    'publishing captures connected sources and reuses rendered images on style changes',
    (tester) async {
      final values = [board];
      Uint8List? output;
      await tester.pumpWidget(
        MaterialApp(
          home: PublicationWorkspace(
            title: 'Connected',
            source: const NoteObjectBlock('board', 'Board').encode(),
            objects: values,
            previewBuilder: (bytes) {
              output = bytes;
              return const Text('Snapshot ready');
            },
          ),
        ),
      );
      Future<void> ready() async {
        for (var i = 0; i < 150; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pump();
          if (find.text('Snapshot ready').evaluate().isNotEmpty &&
              find.byType(LinearProgressIndicator).evaluate().isEmpty) {
            return;
          }
        }
        fail('Connected preview did not finish');
      }

      await ready();
      expect(output, isNotNull);
      values[0] = board.copyWith(
        title: 'CHANGED_AFTER_OPEN',
        data: {'schemaVersion': 1, 'elements': []},
      );
      await tester.ensureVisible(find.text('Letter'));
      await tester.tap(find.text('Letter'));
      await tester.pump(const Duration(milliseconds: 350));
      await ready();
      await tester.runAsync(() async {
        final text = await pdfText(output!);
        expect(text, contains('Mechanics blueprint'));
        expect(text, isNot(contains('CHANGED_AFTER_OPEN')));
        expect(text, isNot(contains('[Image:')));
      });
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'Canvas image attachment renders completely and unknown placements are reported',
    () async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const ui.Rect.fromLTWH(0, 0, 120, 80),
        ui.Paint()..color = const Color(0xffff0000),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(120, 80);
      final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final png = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      image.dispose();
      picture.dispose();
      final source = object(
        'art',
        'orbit.canvas',
        data: {
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'image',
              'type': 'image',
              'x': 0,
              'y': 0,
              'width': 240,
              'height': 160,
              'contentRef': 'Attachments/red.png',
            },
            {
              'id': 'unknown',
              'type': 'future-widget',
              'x': 300,
              'y': 0,
              'width': 100,
              'height': 100,
            },
            {'invalid': 'opaque'},
          ],
        },
      );
      final doc = publish(const NoteObjectBlock('art', 'Art').encode(), [
        source,
      ]);
      expect(
        doc.warnings.any((w) => w.contains('unsupported Canvas placement')),
        true,
      );
      expect(doc.warnings.any((w) => w.contains('invalid or duplicate')), true);
      final warnings = <String>[];
      final snapshot = doc.objectSnapshots.canvases.values.single;
      final result = (await renderPublicationCanvas(
        snapshot,
        objects: [source],
        warn: warnings.add,
        readImage: (_) async => png,
      ))!;
      expect(warnings, isEmpty);
      final codec = await ui.instantiateImageCodec(result);
      final rendered = (await codec.getNextFrame()).image;
      try {
        final pixels = (await rendered.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final bytes = pixels.buffer.asUint8List(
          pixels.offsetInBytes,
          pixels.lengthInBytes,
        );
        var red = 0;
        for (var i = 0; i < bytes.length; i += 4) {
          if (bytes[i] > 220 && bytes[i + 1] < 30 && bytes[i + 2] < 30) {
            red++;
          }
        }
        expect(red, greaterThan(10000));
      } finally {
        rendered.dispose();
        codec.dispose();
      }
    },
  );
  test(
    'snapshot caps, stale precise targets and unsafe descriptions are explicit',
    () {
      final task = object(
        'task',
        'orbit.task',
        title: '<script>title</script>',
        body:
            '![injected](https://example.com/private) <script>unsafe</script>',
      );
      final repeated = List.filled(
        105,
        const NoteObjectBlock('task', 'Task').encode(),
      ).join('\n');
      final doc = publish(repeated, [task]);
      expect(doc.warnings.any((w) => w.contains('first 100 linked')), true);
      final export = PublicationExport(doc);
      expect(export.elements.where((e) => e.tag == 'img'), isEmpty);
      expect(export.html(), isNot(contains('<script>unsafe')));
      final precise = publish(
        const NoteObjectBlock('task', 'Precise', fragment: 'page=2').encode(),
        [task],
      );
      expect(
        precise.nodes.map((n) => n.textContent).join(),
        isNot(contains('unsafe')),
      );
      expect(
        precise.warnings.any((w) => w.contains('without broadening')),
        true,
      );
    },
  );
  test(
    'short UML relationships keep multiplicities separate in Canvas and exports',
    () {
      final snapshot = publish(
        diagramMarkdown('board', 'Diagram', ['player', 'controller']),
        [board],
      ).objectSnapshots.canvases.values.single;
      final scene = snapshot.scene;
      final edge = scene['edge']!;
      final labels = connectorEndLabels(
        edge,
        resolveConnectorEndpoints(edge, scene),
      );
      expect(labels.length, 2);
      expect(labels.first.bounds.intersects(labels.last.bounds), false);
      expect(labels.map((l) => l.text), ['1', '1']);
      expect(board.data['elements'], isNotEmpty);
    },
  );
  test(
    'linked image files use safe encoded attachment sources and related context names',
    () {
      final image = object(
        'image',
        'orbit.file',
        title: 'Reference image',
        properties: {
          'mimeType': 'image/png',
          'contentRef': 'Attachments/hash/figure (1)#.png',
        },
      );
      final doc = publish(
        const NoteObjectBlock('image', 'Reference').encode(),
        [image],
      );
      final export = PublicationExport(doc);
      final node = export.elements.singleWhere((e) => e.tag == 'img');
      expect(node.attributes['src'], contains('%23'));
      expect(node.attributes['src'], startsWith('Attachments/'));
      final course = object('course', 'orbit.course', title: 'Game physics');
      final task = object(
        'task',
        'orbit.task',
        properties: {'courseId': 'course'},
      );
      final related = publish(const NoteObjectBlock('task', 'Task').encode(), [
        course,
        task,
      ]);
      expect(
        related.nodes.map((n) => n.textContent).join(),
        contains('Course: Game physics'),
      );
      final unsafe = image.copyWith(
        properties: {
          'mimeType': 'image/png',
          'contentRef': '../Private/secret.png',
        },
      );
      expect(
        PublicationExport(
          publish(const NoteObjectBlock('image', 'Reference').encode(), [
            unsafe,
          ]),
        ).elements.where((e) => e.tag == 'img'),
        isEmpty,
      );
    },
  );
}
