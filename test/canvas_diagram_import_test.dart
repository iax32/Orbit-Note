import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orbit_note/canvas/diagram_import.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_import_dialog.dart';

void main() {
  group('Mermaid Flowchart Parser & Layout Engine (CAN-04, CAN-15, CAN-16)', () {
    test('parses basic graph TD with rectangles and directed connectors', () {
      const source = '''
graph TD
  Start[Begin Process] --> Step1[Validate Input]
  Step1 --> Done[Complete]
''';

      var idCounter = 0;
      final result = parseMermaidFlowchart(
        source,
        origin: const CanvasPoint(500, 500),
        idGenerator: () => 'test_${idCounter++}',
      );

      expect(result.elements.length, 5); // 3 nodes + 2 connectors
      final nodes = result.elements
          .where((e) => e.type != 'connector')
          .toList();
      final conns = result.elements
          .where((e) => e.type == 'connector')
          .toList();

      expect(nodes.length, 3);
      expect(conns.length, 2);

      // Verify node types and text
      expect(
        nodes.map((n) => n.text).toSet(),
        containsAll(['Begin Process', 'Validate Input', 'Complete']),
      );
      for (final n in nodes) {
        expect(n.type, equals('rectangle'));
        expect(n.groupId, equals(result.groupId));
      }

      // Verify layout direction (TD: Y increases)
      final startNode = nodes.firstWhere((n) => n.text == 'Begin Process');
      final stepNode = nodes.firstWhere((n) => n.text == 'Validate Input');
      final doneNode = nodes.firstWhere((n) => n.text == 'Complete');

      expect(startNode.y < stepNode.y, isTrue);
      expect(stepNode.y < doneNode.y, isTrue);

      // Verify connectors link node IDs
      expect(conns[0].startId, equals(startNode.id));
      expect(conns[0].endId, equals(stepNode.id));
      expect(conns[0].endMarker, equals('arrow'));

      expect(conns[1].startId, equals(stepNode.id));
      expect(conns[1].endId, equals(doneNode.id));
      expect(conns[1].endMarker, equals('arrow'));
    });

    test('parses graph LR with horizontal positioning', () {
      const source = '''
graph LR
  Client[Web Client] --> Gateway[API Gateway] --> DB[(Database)]
''';

      var idCounter = 0;
      final result = parseMermaidFlowchart(
        source,
        origin: const CanvasPoint(0, 0),
        idGenerator: () => 'lr_${idCounter++}',
      );

      final nodes = result.elements
          .where((e) => e.type != 'connector')
          .toList();
      expect(nodes.length, 3);

      final client = nodes.firstWhere((n) => n.text == 'Web Client');
      final gateway = nodes.firstWhere((n) => n.text == 'API Gateway');
      final db = nodes.firstWhere((n) => n.text == 'Database');

      // LR: X increases
      expect(client.x < gateway.x, isTrue);
      expect(gateway.x < db.x, isTrue);

      // Database cylinder maps to 'card'
      expect(db.type, equals('card'));
    });

    test(
      'parses diverse node shapes (capsule, ellipse, diamond, sticky, subroutine)',
      () {
        const source = '''
graph TD
  A([Capsule Node]) --> B((Circle Node))
  B --> C{Decision Diamond}
  C --> D(Sticky Rounded)
  C --> E[[Subroutine Card]]
''';

        var idCounter = 0;
        final result = parseMermaidFlowchart(
          source,
          idGenerator: () => 'shape_${idCounter++}',
        );

        final nodes = result.elements
            .where((e) => e.type != 'connector')
            .toList();
        expect(nodes.length, 5);

        final capsule = nodes.firstWhere((n) => n.text == 'Capsule Node');
        final circle = nodes.firstWhere((n) => n.text == 'Circle Node');
        final diamond = nodes.firstWhere((n) => n.text == 'Decision Diamond');
        final sticky = nodes.firstWhere((n) => n.text == 'Sticky Rounded');
        final sub = nodes.firstWhere((n) => n.text == 'Subroutine Card');

        expect(capsule.type, equals('card'));
        expect(circle.type, equals('ellipse'));
        expect(diamond.type, equals('diamond'));
        expect(sticky.type, equals('sticky'));
        expect(sub.type, equals('card'));
      },
    );

    test('parses connector styles, edge labels, and bidirectional arrows', () {
      const source = '''
graph TD
  A -->|Pipe Label| B
  B -- Arrow Label --> C
  C -. Dashed .-> D
  D == Thick ==> E
  E <--> F
  F --- G
''';

      var idCounter = 0;
      final result = parseMermaidFlowchart(
        source,
        idGenerator: () => 'edge_${idCounter++}',
      );

      final conns = result.elements
          .where((e) => e.type == 'connector')
          .toList();
      expect(conns.length, 6);

      // 1. Pipe label: A -->|Pipe Label| B
      expect(conns[0].text, equals('Pipe Label'));
      expect(conns[0].endMarker, equals('arrow'));
      expect(conns[0].strokeStyle, equals('solid'));

      // 2. Arrow label: B -- Arrow Label --> C
      expect(conns[1].text, equals('Arrow Label'));
      expect(conns[1].endMarker, equals('arrow'));

      // 3. Dashed: C -. Dashed .-> D
      expect(conns[2].text, equals('Dashed'));
      expect(conns[2].strokeStyle, equals('dashed'));
      expect(conns[2].endMarker, equals('arrow'));

      // 4. Thick: D == Thick ==> E
      expect(conns[3].text, equals('Thick'));
      expect(conns[3].strokeWidth, equals(4.0));
      expect(conns[3].endMarker, equals('arrow'));

      // 5. Bidirectional: E <--> F
      expect(conns[4].startMarker, equals('arrow'));
      expect(conns[4].endMarker, equals('arrow'));

      // 6. Solid line: F --- G
      expect(conns[5].endMarker, equals('none'));
    });

    test('handles cycles defensively without infinite loop', () {
      const source = '''
graph TD
  A --> B
  B --> C
  C --> A
''';

      final result = parseMermaidFlowchart(source);
      final nodes = result.elements
          .where((e) => e.type != 'connector')
          .toList();
      final conns = result.elements
          .where((e) => e.type == 'connector')
          .toList();

      expect(nodes.length, 3);
      expect(conns.length, 3);
    });

    test('handles empty and whitespace sources gracefully', () {
      final result = parseMermaidFlowchart('');
      expect(result.elements, isEmpty);
      expect(result.elementIds, isEmpty);

      final result2 = parseMermaidFlowchart('   %% only comments\n\n');
      expect(result2.elements, isEmpty);
    });
  });

  group('Orbit Canvas JSON Importer (CAN-04, CAN-15)', () {
    test(
      'imports full canvas export with UUID remapping and connector preservation',
      () {
        final jsonPayload = {
          'schemaVersion': 1,
          'elements': [
            {
              'id': 'orig_card_1',
              'type': 'card',
              'text': 'Component A',
              'x': 100.0,
              'y': 100.0,
              'width': 200.0,
              'height': 80.0,
            },
            {
              'id': 'orig_card_2',
              'type': 'rectangle',
              'text': 'Component B',
              'x': 400.0,
              'y': 100.0,
              'width': 200.0,
              'height': 80.0,
            },
            {
              'id': 'orig_conn_1',
              'type': 'connector',
              'startId': 'orig_card_1',
              'endId': 'orig_card_2',
              'routing': 'orthogonal',
              'endMarker': 'arrow',
            },
          ],
        };

        var idCounter = 0;
        final result = parseCanvasJson(
          jsonPayload,
          targetCenter: const CanvasPoint(800, 600),
          idGenerator: () => 'remapped_${idCounter++}',
        );

        expect(result.elements.length, 3);
        expect(result.elementIds.length, 3);

        final card1 = result.elements.firstWhere(
          (e) => e.text == 'Component A',
        );
        final card2 = result.elements.firstWhere(
          (e) => e.text == 'Component B',
        );
        final conn = result.elements.firstWhere((e) => e.type == 'connector');

        // UUIDs are remapped!
        expect(card1.id, isNot(equals('orig_card_1')));
        expect(card2.id, isNot(equals('orig_card_2')));
        expect(conn.id, isNot(equals('orig_conn_1')));

        // Connector endpoints are updated to match new IDs!
        expect(conn.startId, equals(card1.id));
        expect(conn.endId, equals(card2.id));

        // All elements share new group ID!
        expect(card1.groupId, equals(result.groupId));
        expect(card2.groupId, equals(result.groupId));
        expect(conn.groupId, equals(result.groupId));

        // Elements are centered near targetCenter (800, 600)
        final midX = (card1.x + card2.x + card2.width) / 2;
        expect((midX - 800).abs() < 50, isTrue);
      },
    );

    test('imports JSON array directly without root object', () {
      final jsonArray = [
        {
          'id': 'node_1',
          'type': 'sticky',
          'text': 'Note 1',
          'x': 0.0,
          'y': 0.0,
          'width': 150.0,
          'height': 150.0,
        },
      ];

      final result = parseCanvasJson(jsonEncode(jsonArray));
      expect(result.elements.length, 1);
      expect(result.elements.first.type, equals('sticky'));
      expect(result.elements.first.text, equals('Note 1'));
    });

    test('handles invalid JSON string gracefully', () {
      final result = parseCanvasJson('{ invalid json string ...');
      expect(result.elements, isEmpty);
      expect(result.summary, contains('Failed to parse JSON'));
    });
  });

  group('Markdown Outline to Mind Map & Tree (CAN-10, CAN-13)', () {
    const sampleOutline = '''
# Core System
- Authentication
  - OAuth2 Provider
  - JWT Tokens
- Data Store
  - SQLite Database
  - Redis Cache
''';

    test('generates Radial Mind Map with radiating left-right branches', () {
      var idCounter = 0;
      final result = parseOutlineDiagram(
        sampleOutline,
        origin: const CanvasPoint(0, 0),
        layout: OutlineDiagramLayout.mindMap,
        idGenerator: () => 'mm_${idCounter++}',
      );

      final nodes = result.elements
          .where((e) => e.type != 'connector')
          .toList();
      final conns = result.elements
          .where((e) => e.type == 'connector')
          .toList();

      expect(nodes.length, 7); // Root + 2 main branches + 4 leaf subbranches
      expect(conns.length, 6); // 2 to main branches + 4 to leaves

      final root = nodes.firstWhere((n) => n.text == 'Core System');
      expect(root.type, equals('card'));

      // Verify connectors have arrow heads
      for (final conn in conns) {
        expect(conn.endMarker, equals('arrow'));
        expect(conn.routing, equals('curved'));
      }
    });

    test('generates Horizontal Tree layout', () {
      final result = parseOutlineDiagram(
        sampleOutline,
        layout: OutlineDiagramLayout.treeHorizontal,
      );

      final nodes = result.elements
          .where((e) => e.type != 'connector')
          .toList();
      final root = nodes.firstWhere((n) => n.text == 'Core System');
      final auth = nodes.firstWhere((n) => n.text == 'Authentication');

      // Tree horizontal: child X > parent X
      expect(auth.x > root.x, isTrue);
    });

    test('generates Vertical Tree layout', () {
      final result = parseOutlineDiagram(
        sampleOutline,
        layout: OutlineDiagramLayout.treeVertical,
      );

      final nodes = result.elements
          .where((e) => e.type != 'connector')
          .toList();
      final root = nodes.firstWhere((n) => n.text == 'Core System');
      final auth = nodes.firstWhere((n) => n.text == 'Authentication');

      // Tree vertical: child Y > parent Y
      expect(auth.y > root.y, isTrue);
    });
  });

  group('SVG Vector Diagram Importer', () {
    test('parses rect, circle, ellipse, line, text from SVG string', () {
      const svg = '''
<svg viewBox="0 0 800 600" xmlns="http://www.w3.org/2000/svg">
  <rect x="50" y="50" width="180" height="90" stroke="#6366f1" />
  <circle cx="400" cy="100" r="45" stroke="#10b981" />
  <ellipse cx="650" cy="100" rx="70" ry="40" stroke="#f59e0b" />
  <line x1="50" y1="300" x2="350" y2="300" stroke="#3b82f6" />
  <text x="100" y="450" fill="#ffffff">Architecture Overview</text>
</svg>
''';

      var idCounter = 0;
      final result = parseSvgDiagram(
        svg,
        targetCenter: const CanvasPoint(500, 500),
        idGenerator: () => 'svg_${idCounter++}',
      );

      expect(result.elements.length, 5);

      final rect = result.elements.firstWhere((e) => e.type == 'rectangle');
      final circle = result.elements.firstWhere(
        (e) => e.type == 'ellipse' && e.width == e.height,
      );
      final ellipse = result.elements.firstWhere(
        (e) => e.type == 'ellipse' && e.width != e.height,
      );
      final line = result.elements.firstWhere((e) => e.type == 'line');
      final text = result.elements.firstWhere((e) => e.type == 'text');

      expect(rect.width, equals(180.0));
      expect(circle.width, equals(90.0));
      expect(ellipse.width, equals(140.0));
      expect(line.hasEndpoints, isTrue);
      expect(text.text, equals('Architecture Overview'));
    });
  });

  group('Diagram Templates Catalog (CAN-15, CAN-16, CAN-17)', () {
    test('catalog contains 7 curated production diagram templates', () {
      final templates = getDiagramTemplates();
      expect(templates.length, 7);

      final templateIds = templates.map((t) => t.id).toSet();
      expect(
        templateIds,
        containsAll([
          'flowchart_decision',
          'cloud_architecture',
          'sequence_flow',
          'erd_diagram',
          'ai_state_machine',
          'mindmap_strategy',
          'roadmap_timeline',
        ]),
      );

      // Verify every template generates renderable elements and connectors
      for (final tmpl in templates) {
        final elements = tmpl.generator(const CanvasPoint(400, 300));
        expect(
          elements,
          isNotEmpty,
          reason: 'Template ${tmpl.name} produced empty elements',
        );

        for (final elem in elements) {
          expect(
            elem.renderable,
            isTrue,
            reason: 'Element ${elem.id} in ${tmpl.name} not renderable',
          );
          expect(
            elem.groupId,
            isNotNull,
            reason: 'Element ${elem.id} in ${tmpl.name} lacks groupId',
          );
        }

        final connectors = elements
            .where((e) => e.type == 'connector')
            .toList();
        expect(
          connectors,
          isNotEmpty,
          reason: 'Template ${tmpl.name} has no connectors',
        );
      }
    });
  });

  group('Canvas Editor & Import Dialog Integration (Widget Tests)', () {
    testWidgets('CanvasImportDialog renders all 4 tabs and template list', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CanvasImportDialog(center: const CanvasPoint(0, 0)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Dialog header & tab buttons
      expect(find.text('Import Diagrams & Content'), findsOneWidget);
      expect(find.text('Templates'), findsOneWidget);
      expect(find.text('Mermaid'), findsOneWidget);
      expect(find.text('Outline'), findsOneWidget);
      expect(find.text('File'), findsOneWidget);

      // In Templates tab by default
      expect(find.text('Decision Flowchart'), findsOneWidget);
      expect(find.text('Microservices & Cloud Architecture'), findsOneWidget);
      expect(find.text('Insert'), findsWidgets);

      // Switch to Mermaid tab
      await tester.tap(find.text('Mermaid'));
      await tester.pumpAndSettle();

      expect(find.text('MERMAID FLOWCHART CODE'), findsOneWidget);
      expect(find.text('Import Mermaid'), findsOneWidget);
      expect(find.text('Load Sample'), findsOneWidget);

      // Switch to Outline tab
      await tester.tap(find.text('Outline'));
      await tester.pumpAndSettle();

      expect(find.text('INDENTED OUTLINE / NOTES'), findsOneWidget);
      expect(find.text('Radial Mind Map'), findsOneWidget);
      expect(find.text('Tree (Horizontal)'), findsOneWidget);
      expect(find.text('Generate Diagram'), findsOneWidget);

      // Switch to File tab
      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();

      expect(find.text('Import Diagram or Canvas File'), findsOneWidget);
      expect(find.text('Choose File...'), findsOneWidget);
    });

    testWidgets(
      'Inserting a template from Dialog returns DiagramImportResult',
      (tester) async {
        DiagramImportResult? receivedResult;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    receivedResult = await CanvasImportDialog.show(
                      context,
                      center: const CanvasPoint(500, 500),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // Tap "Insert" on the first template (Decision Flowchart)
        final insertButtons = find.text('Insert');
        expect(insertButtons, findsWidgets);
        await tester.tap(insertButtons.first);
        await tester.pumpAndSettle();

        // Verify dialog closed and returned result
        expect(receivedResult, isNotNull);
        expect(receivedResult!.elements, isNotEmpty);
        expect(receivedResult!.groupId, isNotEmpty);
        expect(receivedResult!.summary, contains('Decision Flowchart'));
      },
    );

    testWidgets('CanvasEditor top toolbar displays Import button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CanvasEditor(
              canvasId: 'board',
              data: const {'schemaVersion': 1, 'elements': []},
              onChanged: (_) {},
              objects: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Import button presence with tooltip
      final importButton = find.byTooltip(
        'Import diagrams & templates (Ctrl+I)',
      );
      expect(importButton, findsOneWidget);
      expect(find.byIcon(Icons.file_upload_outlined), findsOneWidget);

      // Tap import button opens dialog
      await tester.tap(importButton);
      await tester.pumpAndSettle();

      expect(find.text('Import Diagrams & Content'), findsOneWidget);
    });
  });
}
