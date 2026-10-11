import 'dart:convert';
import 'dart:math' as math;

import 'geometry.dart';
import 'scene.dart';

/// Layout style for converting outline text to diagrams.
enum OutlineDiagramLayout { mindMap, treeHorizontal, treeVertical }

/// Result of importing a diagram or canvas snippet into Canvas elements.
class DiagramImportResult {
  const DiagramImportResult({
    required this.elements,
    required this.groupId,
    required this.elementIds,
    required this.summary,
    required this.bounds,
  });

  final List<CanvasElement> elements;
  final String groupId;
  final Set<String> elementIds;
  final String summary;
  final CanvasBounds bounds;
}

/// A pre-built diagram template ready for instant placement.
class DiagramTemplate {
  const DiagramTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.iconName,
    required this.generator,
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final String iconName;
  final List<CanvasElement> Function(
    CanvasPoint center, {
    String Function()? idGenerator,
  })
  generator;
}

/// Default high-contrast harmonious accent colors for diagram nodes.
const List<int> _diagramPalette = [
  0xff6366f1, // Indigo
  0xff8b5cf6, // Violet
  0xff3b82f6, // Blue
  0xff0ea5e9, // Sky
  0xff10b981, // Emerald
  0xff14b8a6, // Teal
  0xfff59e0b, // Amber
  0xfff97316, // Orange
  0xffec4899, // Pink
  0xffa855f7, // Purple
];

int _defaultCounter = 0;
String _fallbackId() =>
    'diag_${DateTime.now().microsecondsSinceEpoch}_${_defaultCounter++}';

/// Parses a Mermaid flowchart string into a list of positioned [CanvasElement]s.
///
/// Supports:
/// - Directions: `graph TD`, `graph TB`, `graph BT`, `graph LR`, `graph RL`
///   and `flowchart TD/TB/BT/LR/RL`.
/// - Node shapes:
///   - `[text]` -> rectangle
///   - `(text)` -> sticky / rounded
///   - `([text])` -> card / capsule
///   - `[[text]]` -> card / subroutine
///   - `[(text)]` -> card / database cylinder
///   - `((text))` -> ellipse / circle
///   - `{text}` / `{{text}}` -> diamond (decision / condition)
///   - `>text]` -> rectangle (asymmetric flag)
/// - Connections:
///   - `-->` -> directed arrow
///   - `---` -> solid line
///   - `-.->` or `-.-` -> dashed connector
///   - `==>` or `===` -> thick connector
///   - `<-->` -> bidirectional arrow
/// - Connection labels: `-->|Label|` or `-- Label -->`
DiagramImportResult parseMermaidFlowchart(
  String source, {
  CanvasPoint? origin,
  String Function()? idGenerator,
}) {
  final gen = idGenerator ?? _fallbackId;
  final targetOrigin = origin ?? const CanvasPoint(0, 0);
  final lines = source.split(RegExp(r'\r?\n'));

  var direction = 'TD';
  final rawNodes = <String, _MermaidNodeRaw>{};
  final rawEdges = <_MermaidEdgeRaw>[];

  // RegEx patterns for parsing Mermaid
  final headerRegex = RegExp(
    r'^\s*(graph|flowchart)\s+(TD|TB|BT|LR|RL)\s*$',
    caseSensitive: false,
  );
  final subGraphRegex = RegExp(r'^\s*(subgraph|end)\b', caseSensitive: false);

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('%%') || subGraphRegex.hasMatch(line)) {
      continue;
    }

    final headerMatch = headerRegex.firstMatch(line);
    if (headerMatch != null) {
      direction = headerMatch.group(2)!.toUpperCase();
      continue;
    }

    // Split multiple statements separated by semicolon
    final statements = line
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    for (final statement in statements) {
      _parseMermaidStatement(statement, rawNodes, rawEdges);
    }
  }

  if (rawNodes.isEmpty && rawEdges.isEmpty) {
    return DiagramImportResult(
      elements: const [],
      groupId: 'grp_${gen()}',
      elementIds: const {},
      summary: 'No valid Mermaid nodes or connections found.',
      bounds: CanvasBounds(targetOrigin.x, targetOrigin.y, 0, 0),
    );
  }

  // Assign IDs and calculate layout
  final idMap = <String, String>{};
  for (final key in rawNodes.keys) {
    idMap[key] = gen();
  }

  // Layout the graph using layered topological sorting
  final layout = _layoutDirectedGraph(
    rawNodes.keys.toList(),
    rawEdges,
    direction: direction,
    rawNodes: rawNodes,
  );

  final groupId = 'grp_${gen()}';
  final elements = <CanvasElement>[];
  final elementIds = <String>{};

  // Center the layout at targetOrigin
  CanvasBounds? unionBounds;
  for (final pos in layout.nodePositions.values) {
    final b = CanvasBounds(pos.x, pos.y, pos.width, pos.height);
    unionBounds = unionBounds?.union(b) ?? b;
  }

  final layoutBounds = unionBounds ?? const CanvasBounds(0, 0, 400, 300);
  final deltaX = targetOrigin.x - (layoutBounds.left + layoutBounds.width / 2);
  final deltaY = targetOrigin.y - (layoutBounds.top + layoutBounds.height / 2);

  // Generate Node Elements
  var colorIndex = 0;
  for (final entry in rawNodes.entries) {
    final rawKey = entry.key;
    final nodeInfo = entry.value;
    final pos = layout.nodePositions[rawKey]!;
    final elementId = idMap[rawKey]!;
    final color = _diagramPalette[colorIndex % _diagramPalette.length];
    colorIndex++;

    final elem = CanvasElement({
      'id': elementId,
      'type': nodeInfo.shapeType,
      'text': nodeInfo.label,
      'x': pos.x + deltaX,
      'y': pos.y + deltaY,
      'width': pos.width,
      'height': pos.height,
      'color': color,
      'groupId': groupId,
    });
    elements.add(elem);
    elementIds.add(elementId);
  }

  // Generate Edge Connectors
  for (final edge in rawEdges) {
    final startId = idMap[edge.source];
    final endId = idMap[edge.target];
    if (startId == null || endId == null) continue;

    final connectorId = gen();
    final isHorizontal = direction == 'LR' || direction == 'RL';
    final routing = isHorizontal ? 'curved' : 'orthogonal';

    final connMap = <String, dynamic>{
      'id': connectorId,
      'type': 'connector',
      'startId': startId,
      'endId': endId,
      'routing': routing,
      'strokeStyle': edge.dashed ? 'dashed' : 'solid',
      'strokeWidth': edge.thick ? 4.0 : 2.5,
      'startMarker': edge.bidirectional ? 'arrow' : 'none',
      'endMarker': edge.hasArrow ? 'arrow' : 'none',
      'color': 0xff8b5cf6,
      'groupId': groupId,
    };
    if (edge.label.isNotEmpty) {
      connMap['text'] = edge.label;
    }

    final conn = CanvasElement(connMap);
    elements.add(conn);
    elementIds.add(connectorId);
  }

  final finalBounds = CanvasBounds(
    layoutBounds.left + deltaX,
    layoutBounds.top + deltaY,
    layoutBounds.width,
    layoutBounds.height,
  );

  return DiagramImportResult(
    elements: elements,
    groupId: groupId,
    elementIds: elementIds,
    summary:
        'Imported Mermaid diagram: ${rawNodes.length} nodes, ${rawEdges.length} connections.',
    bounds: finalBounds,
  );
}

void _parseMermaidStatement(
  String statement,
  Map<String, _MermaidNodeRaw> nodes,
  List<_MermaidEdgeRaw> edges,
) {
  final edgePattern = RegExp(
    r'(.*?)\s*('
    r'-->\|([^|]+)\||' // -->|label|
    r'--\s+([^->]+)\s+-->|' // -- label -->
    r'-\.\s+([^.]+)\s+\.->|' // -. label .->
    r'==\s+([^=]+)\s+==>|' // == label ==>
    r'<-->|' // bidirectional
    r'-->|' // directed
    r'-\.->|' // dashed arrow
    r'-\.-|' // dashed line
    r'==>|' // thick arrow
    r'===|' // thick line
    r'---|' // solid line
    r'--' // line
    r')\s*(.*)',
  );

  final edgeMatch = edgePattern.firstMatch(statement);
  if (edgeMatch != null) {
    final leftPart = edgeMatch.group(1)!.trim();
    final fullEdgeOp = edgeMatch.group(2)!;
    final rightPart = edgeMatch.group(7)!.trim();

    var label = '';
    if (edgeMatch.group(3) != null) {
      label = edgeMatch.group(3)!.trim();
    } else if (edgeMatch.group(4) != null) {
      label = edgeMatch.group(4)!.trim();
    } else if (edgeMatch.group(5) != null) {
      label = edgeMatch.group(5)!.trim();
    } else if (edgeMatch.group(6) != null) {
      label = edgeMatch.group(6)!.trim();
    }

    final hasArrow = fullEdgeOp.contains('>');
    final bidirectional = fullEdgeOp.contains('<-->');
    final dashed = fullEdgeOp.contains('.');
    final thick = fullEdgeOp.contains('==');

    final nextEdgeMatch = edgePattern.firstMatch(rightPart);
    final String targetPart;
    if (nextEdgeMatch != null) {
      targetPart = nextEdgeMatch.group(1)!.trim();
      _parseMermaidStatement(rightPart, nodes, edges);
    } else {
      targetPart = rightPart;
    }

    final sourceNode = _parseNodeSpec(leftPart);
    final targetNode = _parseNodeSpec(targetPart);

    nodes.putIfAbsent(sourceNode.id, () => sourceNode);
    nodes.putIfAbsent(targetNode.id, () => targetNode);

    if (sourceNode.isExplicit) nodes[sourceNode.id] = sourceNode;
    if (targetNode.isExplicit) nodes[targetNode.id] = targetNode;

    edges.add(
      _MermaidEdgeRaw(
        source: sourceNode.id,
        target: targetNode.id,
        label: label,
        hasArrow: hasArrow,
        bidirectional: bidirectional,
        dashed: dashed,
        thick: thick,
      ),
    );
    return;
  }

  // Single standalone node declaration e.g.: A[Label]
  if (statement.isNotEmpty) {
    final singleNode = _parseNodeSpec(statement);
    if (singleNode.id.isNotEmpty) {
      nodes[singleNode.id] = singleNode;
    }
  }
}

String _cleanLabel(String raw) {
  var s = raw.trim();
  if ((s.startsWith('"') && s.endsWith('"')) ||
      (s.startsWith("'") && s.endsWith("'"))) {
    if (s.length >= 2) s = s.substring(1, s.length - 1).trim();
  }
  return s;
}

_MermaidNodeRaw _parseNodeSpec(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return _MermaidNodeRaw(
      id: '',
      label: '',
      shapeType: 'rectangle',
      isExplicit: false,
    );
  }

  // 1. Double bracket subroutine: A[[Label]]
  final subMatch = RegExp(
    r'^([a-zA-Z0-9_.-]+)\[\[(.*?)\]\]$',
  ).firstMatch(trimmed);
  if (subMatch != null) {
    return _MermaidNodeRaw(
      id: subMatch.group(1)!,
      label: _cleanLabel(subMatch.group(2)!),
      shapeType: 'card',
      isExplicit: true,
    );
  }

  // 2. Cylinder / Database: A[(Label)]
  final dbMatch = RegExp(
    r'^([a-zA-Z0-9_.-]+)\[\((.*?)\)\]$',
  ).firstMatch(trimmed);
  if (dbMatch != null) {
    return _MermaidNodeRaw(
      id: dbMatch.group(1)!,
      label: _cleanLabel(dbMatch.group(2)!),
      shapeType: 'card',
      isExplicit: true,
    );
  }

  // 3. Capsule: A([Label])
  final capMatch = RegExp(
    r'^([a-zA-Z0-9_.-]+)\(\[(.*?)\]\)$',
  ).firstMatch(trimmed);
  if (capMatch != null) {
    return _MermaidNodeRaw(
      id: capMatch.group(1)!,
      label: _cleanLabel(capMatch.group(2)!),
      shapeType: 'card',
      isExplicit: true,
    );
  }

  // 4. Circle / Ellipse: A((Label))
  final circleMatch = RegExp(
    r'^([a-zA-Z0-9_.-]+)\(\((.*?)\)\)$',
  ).firstMatch(trimmed);
  if (circleMatch != null) {
    return _MermaidNodeRaw(
      id: circleMatch.group(1)!,
      label: _cleanLabel(circleMatch.group(2)!),
      shapeType: 'ellipse',
      isExplicit: true,
    );
  }

  // 5. Hexagon: A{{Label}}
  final hexMatch = RegExp(
    r'^([a-zA-Z0-9_.-]+)\{\{(.*?)\}\}$',
  ).firstMatch(trimmed);
  if (hexMatch != null) {
    return _MermaidNodeRaw(
      id: hexMatch.group(1)!,
      label: _cleanLabel(hexMatch.group(2)!),
      shapeType: 'diamond',
      isExplicit: true,
    );
  }

  // 6. Diamond / Decision: A{Label}
  final diamondMatch = RegExp(
    r'^([a-zA-Z0-9_.-]+)\{(.*?)\}$',
  ).firstMatch(trimmed);
  if (diamondMatch != null) {
    return _MermaidNodeRaw(
      id: diamondMatch.group(1)!,
      label: _cleanLabel(diamondMatch.group(2)!),
      shapeType: 'diamond',
      isExplicit: true,
    );
  }

  // 7. Rounded rectangle / sticky: A(Label)
  final roundMatch = RegExp(
    r'^([a-zA-Z0-9_.-]+)\((.*?)\)$',
  ).firstMatch(trimmed);
  if (roundMatch != null) {
    return _MermaidNodeRaw(
      id: roundMatch.group(1)!,
      label: _cleanLabel(roundMatch.group(2)!),
      shapeType: 'sticky',
      isExplicit: true,
    );
  }

  // 8. Standard rectangle: A[Label]
  final rectMatch = RegExp(r'^([a-zA-Z0-9_.-]+)\[(.*?)\]$').firstMatch(trimmed);
  if (rectMatch != null) {
    return _MermaidNodeRaw(
      id: rectMatch.group(1)!,
      label: _cleanLabel(rectMatch.group(2)!),
      shapeType: 'rectangle',
      isExplicit: true,
    );
  }

  // 9. Asymmetric flag: A>Label]
  final flagMatch = RegExp(r'^([a-zA-Z0-9_.-]+)>(.*?)\]$').firstMatch(trimmed);
  if (flagMatch != null) {
    return _MermaidNodeRaw(
      id: flagMatch.group(1)!,
      label: _cleanLabel(flagMatch.group(2)!),
      shapeType: 'rectangle',
      isExplicit: true,
    );
  }

  // Bare identifier
  return _MermaidNodeRaw(
    id: trimmed,
    label: trimmed,
    shapeType: 'rectangle',
    isExplicit: false,
  );
}

class _MermaidNodeRaw {
  _MermaidNodeRaw({
    required this.id,
    required this.label,
    required this.shapeType,
    required this.isExplicit,
  });

  final String id;
  final String label;
  final String shapeType;
  final bool isExplicit;
}

class _MermaidEdgeRaw {
  _MermaidEdgeRaw({
    required this.source,
    required this.target,
    required this.label,
    required this.hasArrow,
    required this.bidirectional,
    required this.dashed,
    required this.thick,
  });

  final String source;
  final String target;
  final String label;
  final bool hasArrow;
  final bool bidirectional;
  final bool dashed;
  final bool thick;
}

class _NodeBounds {
  const _NodeBounds({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

class _GraphLayoutResult {
  const _GraphLayoutResult({required this.nodePositions});

  final Map<String, _NodeBounds> nodePositions;
}

_GraphLayoutResult _layoutDirectedGraph(
  List<String> nodeIds,
  List<_MermaidEdgeRaw> edges, {
  required String direction,
  required Map<String, _MermaidNodeRaw> rawNodes,
}) {
  final inDegree = <String, int>{for (final id in nodeIds) id: 0};
  final adj = <String, List<String>>{for (final id in nodeIds) id: []};

  for (final edge in edges) {
    if (adj.containsKey(edge.source) && inDegree.containsKey(edge.target)) {
      adj[edge.source]!.add(edge.target);
      inDegree[edge.target] = (inDegree[edge.target] ?? 0) + 1;
    }
  }

  // Topological rank assignment with cycle protection
  final ranks = <String, int>{for (final id in nodeIds) id: 0};
  final queue = <String>[];
  for (final entry in inDegree.entries) {
    if (entry.value == 0) {
      queue.add(entry.key);
    }
  }

  if (queue.isEmpty && nodeIds.isNotEmpty) {
    queue.add(nodeIds.first);
  }

  final visited = <String>{};
  while (queue.isNotEmpty) {
    final curr = queue.removeAt(0);
    visited.add(curr);
    final currRank = ranks[curr] ?? 0;

    for (final next in adj[curr] ?? const <String>[]) {
      if ((ranks[next] ?? 0) < currRank + 1) {
        ranks[next] = currRank + 1;
      }
      if (!visited.contains(next) && !queue.contains(next)) {
        queue.add(next);
      }
    }
  }

  final layers = <int, List<String>>{};
  for (final id in nodeIds) {
    final r = ranks[id] ?? 0;
    layers.putIfAbsent(r, () => []).add(id);
  }

  final isHorizontal = direction == 'LR' || direction == 'RL';
  final isReversed = direction == 'BT' || direction == 'RL';

  final nodeDimensions = <String, (double, double)>{};
  for (final id in nodeIds) {
    final raw = rawNodes[id];
    final text = raw?.label ?? id;
    final shape = raw?.shapeType ?? 'rectangle';
    final lines = text.split('\n');
    final maxLineLen = lines.fold<int>(0, (m, l) => math.max(m, l.length));

    double w;
    double h;
    if (shape == 'diamond') {
      w = math.max(140.0, maxLineLen * 9.5 + 40.0);
      h = math.max(90.0, lines.length * 24.0 + 40.0);
    } else if (shape == 'ellipse') {
      w = math.max(130.0, maxLineLen * 9.0 + 36.0);
      h = math.max(76.0, lines.length * 22.0 + 36.0);
    } else {
      w = math.max(150.0, math.min(320.0, maxLineLen * 8.5 + 34.0));
      h = math.max(72.0, lines.length * 22.0 + 30.0);
    }
    nodeDimensions[id] = (w, h);
  }

  final nodePositions = <String, _NodeBounds>{};
  final sortedRanks = layers.keys.toList()..sort();
  if (isReversed) {
    sortedRanks.sort((a, b) => b.compareTo(a));
  }

  const layerSpacing = 240.0;
  const intraSpacing = 40.0;

  var currentLayerCoord = 0.0;

  for (final rank in sortedRanks) {
    final nodesInLayer = layers[rank]!;

    double layerSpan = 0.0;
    for (var i = 0; i < nodesInLayer.length; i++) {
      final id = nodesInLayer[i];
      final (w, h) = nodeDimensions[id]!;
      layerSpan += isHorizontal ? h : w;
      if (i > 0) layerSpan += intraSpacing;
    }

    var currentIntraCoord = -layerSpan / 2;

    for (final id in nodesInLayer) {
      final (w, h) = nodeDimensions[id]!;
      if (isHorizontal) {
        nodePositions[id] = _NodeBounds(
          x: currentLayerCoord,
          y: currentIntraCoord,
          width: w,
          height: h,
        );
        currentIntraCoord += h + intraSpacing;
      } else {
        nodePositions[id] = _NodeBounds(
          x: currentIntraCoord,
          y: currentLayerCoord,
          width: w,
          height: h,
        );
        currentIntraCoord += w + intraSpacing;
      }
    }

    double maxThickness = 0.0;
    for (final id in nodesInLayer) {
      final (w, h) = nodeDimensions[id]!;
      maxThickness = math.max(maxThickness, isHorizontal ? w : h);
    }
    currentLayerCoord += maxThickness + (layerSpacing - 100);
  }

  return _GraphLayoutResult(nodePositions: nodePositions);
}

/// Imports Orbit Canvas JSON with ID remapping, connector rewiring, and center placement.
DiagramImportResult parseCanvasJson(
  dynamic jsonSource, {
  CanvasPoint? targetCenter,
  String Function()? idGenerator,
}) {
  final gen = idGenerator ?? _fallbackId;
  final target = targetCenter ?? const CanvasPoint(0, 0);

  Map<String, dynamic> rootMap;
  if (jsonSource is String) {
    try {
      final decoded = jsonDecode(jsonSource);
      if (decoded is Map<String, dynamic>) {
        rootMap = decoded;
      } else if (decoded is List) {
        rootMap = {'elements': decoded};
      } else {
        throw const FormatException('Expected JSON object or array.');
      }
    } catch (e) {
      return DiagramImportResult(
        elements: const [],
        groupId: 'grp_${gen()}',
        elementIds: const {},
        summary: 'Failed to parse JSON: $e',
        bounds: CanvasBounds(target.x, target.y, 0, 0),
      );
    }
  } else if (jsonSource is Map<String, dynamic>) {
    rootMap = jsonSource;
  } else if (jsonSource is List) {
    rootMap = {'elements': jsonSource};
  } else {
    return DiagramImportResult(
      elements: const [],
      groupId: 'grp_${gen()}',
      elementIds: const {},
      summary: 'Unsupported JSON input type.',
      bounds: CanvasBounds(target.x, target.y, 0, 0),
    );
  }

  final rawElements = rootMap['elements'];
  if (rawElements is! List || rawElements.isEmpty) {
    return DiagramImportResult(
      elements: const [],
      groupId: 'grp_${gen()}',
      elementIds: const {},
      summary: 'No elements found in Canvas JSON.',
      bounds: CanvasBounds(target.x, target.y, 0, 0),
    );
  }

  final idMap = <String, String>{};
  final groupMap = <String, String>{};
  final rawList = <Map<String, dynamic>>[];

  for (final item in rawElements) {
    if (item is Map) {
      final map = Map<String, dynamic>.from(item);
      final oldId = map['id']?.toString() ?? '';
      if (oldId.isNotEmpty) {
        idMap[oldId] = gen();
      }
      final oldGroup = map['groupId']?.toString();
      if (oldGroup != null &&
          oldGroup.isNotEmpty &&
          !groupMap.containsKey(oldGroup)) {
        groupMap[oldGroup] = 'grp_${gen()}';
      }
      rawList.add(map);
    }
  }

  final newClusterGroupId = 'grp_${gen()}';

  CanvasBounds? origBounds;
  for (final map in rawList) {
    final isConn =
        map['type'] == 'connector' ||
        map['type'] == 'arrow' ||
        map['type'] == 'line';
    if (isConn && map['startX'] == null && map['x'] == null) {
      continue;
    }
    final x = (map['x'] is num)
        ? (map['x'] as num).toDouble()
        : (map['startX'] as num?)?.toDouble() ?? 0.0;
    final y = (map['y'] is num)
        ? (map['y'] as num).toDouble()
        : (map['startY'] as num?)?.toDouble() ?? 0.0;
    final w = (map['width'] is num) ? (map['width'] as num).toDouble() : 200.0;
    final h = (map['height'] is num)
        ? (map['height'] as num).toDouble()
        : 100.0;
    final b = CanvasBounds(x, y, w, h);
    origBounds = origBounds?.union(b) ?? b;
  }

  final sourceBounds = origBounds ?? const CanvasBounds(0, 0, 800, 600);
  final offsetX = target.x - (sourceBounds.left + sourceBounds.width / 2);
  final offsetY = target.y - (sourceBounds.top + sourceBounds.height / 2);

  final importedElements = <CanvasElement>[];
  final elementIds = <String>{};

  for (final map in rawList) {
    final oldId = map['id']?.toString() ?? '';
    final newId = idMap[oldId] ?? gen();

    final copy = Map<String, dynamic>.of(map);
    copy['id'] = newId;

    if (copy['startId'] != null && idMap.containsKey(copy['startId'])) {
      copy['startId'] = idMap[copy['startId']];
    }
    if (copy['endId'] != null && idMap.containsKey(copy['endId'])) {
      copy['endId'] = idMap[copy['endId']];
    }

    if (copy['x'] is num) {
      copy['x'] = (copy['x'] as num).toDouble() + offsetX;
    }
    if (copy['y'] is num) {
      copy['y'] = (copy['y'] as num).toDouble() + offsetY;
    }
    if (copy['startX'] is num) {
      copy['startX'] = (copy['startX'] as num).toDouble() + offsetX;
    }
    if (copy['startY'] is num) {
      copy['startY'] = (copy['startY'] as num).toDouble() + offsetY;
    }
    if (copy['endX'] is num) {
      copy['endX'] = (copy['endX'] as num).toDouble() + offsetX;
    }
    if (copy['endY'] is num) {
      copy['endY'] = (copy['endY'] as num).toDouble() + offsetY;
    }

    final oldGid = copy['groupId']?.toString();
    if (oldGid != null && groupMap.containsKey(oldGid)) {
      copy['groupId'] = groupMap[oldGid];
    } else {
      copy['groupId'] = newClusterGroupId;
    }

    final elem = CanvasElement(copy);
    if (elem.renderable) {
      importedElements.add(elem);
      elementIds.add(newId);
    }
  }

  final finalBounds = CanvasBounds(
    sourceBounds.left + offsetX,
    sourceBounds.top + offsetY,
    sourceBounds.width,
    sourceBounds.height,
  );

  return DiagramImportResult(
    elements: importedElements,
    groupId: newClusterGroupId,
    elementIds: elementIds,
    summary: 'Imported ${importedElements.length} elements from Canvas JSON.',
    bounds: finalBounds,
  );
}

/// Parses indented Markdown lists into hierarchical Tree or Radial Mind Map diagrams.
DiagramImportResult parseOutlineDiagram(
  String outlineText, {
  CanvasPoint? origin,
  OutlineDiagramLayout layout = OutlineDiagramLayout.mindMap,
  String Function()? idGenerator,
}) {
  final gen = idGenerator ?? _fallbackId;
  final center = origin ?? const CanvasPoint(0, 0);

  final lines = outlineText.split(RegExp(r'\r?\n'));
  final rawNodes = <_OutlineNode>[];
  final stack = <(int, _OutlineNode)>[];

  for (final rawLine in lines) {
    if (rawLine.trim().isEmpty) continue;

    var indent = 0;
    var idx = 0;
    while (idx < rawLine.length) {
      if (rawLine[idx] == ' ') {
        indent += 1;
      } else if (rawLine[idx] == '\t') {
        indent += 2;
      } else {
        break;
      }
      idx++;
    }

    var content = rawLine.substring(idx).trim();
    var effectiveIndent = indent;
    if (content.startsWith('#')) {
      final headingMatch = RegExp(r'^(#+)\s*(.*)').firstMatch(content);
      if (headingMatch != null) {
        effectiveIndent = (headingMatch.group(1)!.length - 1) * 2;
        content = headingMatch.group(2)!.trim();
      }
    } else {
      content = content.replaceFirst(RegExp(r'^(?:[-*+]|\d+\.)\s+'), '').trim();
      if (stack.isNotEmpty && stack.first.$1 == 0) {
        effectiveIndent = indent + 2;
      }
    }
    if (content.isEmpty) continue;

    final node = _OutlineNode(id: gen(), text: content);
    rawNodes.add(node);

    while (stack.isNotEmpty && stack.last.$1 >= effectiveIndent) {
      stack.removeLast();
    }

    if (stack.isNotEmpty) {
      final parent = stack.last.$2;
      parent.children.add(node);
      node.parent = parent;
    }

    stack.add((effectiveIndent, node));
  }

  if (rawNodes.isEmpty) {
    return DiagramImportResult(
      elements: const [],
      groupId: 'grp_${gen()}',
      elementIds: const {},
      summary: 'No outline items found.',
      bounds: CanvasBounds(center.x, center.y, 0, 0),
    );
  }

  final roots = rawNodes.where((n) => n.parent == null).toList();
  final groupId = 'grp_${gen()}';
  final elements = <CanvasElement>[];
  final elementIds = <String>{};

  if (layout == OutlineDiagramLayout.mindMap) {
    _layoutMindMap(roots, center, elements, elementIds, groupId, gen);
  } else if (layout == OutlineDiagramLayout.treeHorizontal) {
    _layoutTreeHorizontal(roots, center, elements, elementIds, groupId, gen);
  } else {
    _layoutTreeVertical(roots, center, elements, elementIds, groupId, gen);
  }

  CanvasBounds? union;
  for (final elem in elements) {
    union = union?.union(elem.bounds) ?? elem.bounds;
  }

  return DiagramImportResult(
    elements: elements,
    groupId: groupId,
    elementIds: elementIds,
    summary: 'Generated diagram with ${rawNodes.length} nodes from outline.',
    bounds: union ?? CanvasBounds(center.x, center.y, 0, 0),
  );
}

class _OutlineNode {
  _OutlineNode({required this.id, required this.text});
  final String id;
  final String text;
  _OutlineNode? parent;
  final List<_OutlineNode> children = [];
}

void _layoutMindMap(
  List<_OutlineNode> roots,
  CanvasPoint center,
  List<CanvasElement> elements,
  Set<String> elementIds,
  String groupId,
  String Function() gen,
) {
  final centralRoot = roots.first;
  const centralW = 180.0;
  const centralH = 80.0;

  final centralElem = CanvasElement({
    'id': centralRoot.id,
    'type': 'card',
    'text': centralRoot.text,
    'x': center.x - centralW / 2,
    'y': center.y - centralH / 2,
    'width': centralW,
    'height': centralH,
    'color': 0xff6366f1,
    'groupId': groupId,
  });
  elements.add(centralElem);
  elementIds.add(centralRoot.id);

  final branchNodes = centralRoot.children.isNotEmpty
      ? centralRoot.children
      : roots.skip(1).toList();

  final leftBranches = <_OutlineNode>[];
  final rightBranches = <_OutlineNode>[];

  for (var i = 0; i < branchNodes.length; i++) {
    if (i % 2 == 0) {
      rightBranches.add(branchNodes[i]);
    } else {
      leftBranches.add(branchNodes[i]);
    }
  }

  _layoutSubBranchRadial(
    rightBranches,
    centralRoot.id,
    center.x + 220,
    center.y,
    1,
    elements,
    elementIds,
    groupId,
    gen,
  );

  _layoutSubBranchRadial(
    leftBranches,
    centralRoot.id,
    center.x - 380,
    center.y,
    -1,
    elements,
    elementIds,
    groupId,
    gen,
  );
}

void _layoutSubBranchRadial(
  List<_OutlineNode> nodes,
  String parentId,
  double startX,
  double centerY,
  int directionMultiplier,
  List<CanvasElement> elements,
  Set<String> elementIds,
  String groupId,
  String Function() gen,
) {
  if (nodes.isEmpty) return;

  const nodeW = 160.0;
  const nodeH = 65.0;
  const vGap = 20.0;
  final totalH = nodes.length * nodeH + (nodes.length - 1) * vGap;
  var currentY = centerY - totalH / 2;

  var colorIdx = directionMultiplier > 0 ? 2 : 4;

  for (final node in nodes) {
    final color = _diagramPalette[colorIdx % _diagramPalette.length];
    colorIdx++;

    final elem = CanvasElement({
      'id': node.id,
      'type': 'rectangle',
      'text': node.text,
      'x': startX,
      'y': currentY,
      'width': nodeW,
      'height': nodeH,
      'color': color,
      'groupId': groupId,
    });
    elements.add(elem);
    elementIds.add(node.id);

    final conn = CanvasElement({
      'id': gen(),
      'type': 'connector',
      'startId': parentId,
      'endId': node.id,
      'routing': 'curved',
      'strokeStyle': 'solid',
      'color': color,
      'endMarker': 'arrow',
      'groupId': groupId,
    });
    elements.add(conn);
    elementIds.add(conn.id);

    if (node.children.isNotEmpty) {
      _layoutSubBranchRadial(
        node.children,
        node.id,
        startX + directionMultiplier * (nodeW + 80),
        currentY + nodeH / 2,
        directionMultiplier,
        elements,
        elementIds,
        groupId,
        gen,
      );
    }

    currentY += nodeH + vGap;
  }
}

void _layoutTreeHorizontal(
  List<_OutlineNode> roots,
  CanvasPoint center,
  List<CanvasElement> elements,
  Set<String> elementIds,
  String groupId,
  String Function() gen,
) {
  const nodeW = 170.0;
  const nodeH = 68.0;
  const hGap = 100.0;
  const vGap = 28.0;

  var currentY = center.y - 150;

  void placeNode(_OutlineNode node, double x, int depth, int branchIndex) {
    final color =
        _diagramPalette[(depth + branchIndex) % _diagramPalette.length];
    final elem = CanvasElement({
      'id': node.id,
      'type': depth == 0 ? 'card' : 'rectangle',
      'text': node.text,
      'x': x,
      'y': currentY,
      'width': nodeW,
      'height': nodeH,
      'color': color,
      'groupId': groupId,
    });
    elements.add(elem);
    elementIds.add(node.id);

    if (node.parent != null) {
      final conn = CanvasElement({
        'id': gen(),
        'type': 'connector',
        'startId': node.parent!.id,
        'endId': node.id,
        'routing': 'curved',
        'color': color,
        'endMarker': 'arrow',
        'groupId': groupId,
      });
      elements.add(conn);
      elementIds.add(conn.id);
    }

    if (node.children.isEmpty) {
      currentY += nodeH + vGap;
    } else {
      for (var i = 0; i < node.children.length; i++) {
        placeNode(
          node.children[i],
          x + nodeW + hGap,
          depth + 1,
          branchIndex + i,
        );
      }
    }
  }

  for (var r = 0; r < roots.length; r++) {
    placeNode(roots[r], center.x - 280, 0, r);
  }
}

void _layoutTreeVertical(
  List<_OutlineNode> roots,
  CanvasPoint center,
  List<CanvasElement> elements,
  Set<String> elementIds,
  String groupId,
  String Function() gen,
) {
  const nodeW = 160.0;
  const nodeH = 64.0;
  const hGap = 36.0;
  const vGap = 80.0;

  var currentX = center.x - 200;

  void placeNode(_OutlineNode node, double y, int depth, int branchIndex) {
    final color =
        _diagramPalette[(depth + branchIndex) % _diagramPalette.length];
    final elem = CanvasElement({
      'id': node.id,
      'type': depth == 0 ? 'card' : 'rectangle',
      'text': node.text,
      'x': currentX,
      'y': y,
      'width': nodeW,
      'height': nodeH,
      'color': color,
      'groupId': groupId,
    });
    elements.add(elem);
    elementIds.add(node.id);

    if (node.parent != null) {
      final conn = CanvasElement({
        'id': gen(),
        'type': 'connector',
        'startId': node.parent!.id,
        'endId': node.id,
        'routing': 'orthogonal',
        'color': color,
        'endMarker': 'arrow',
        'groupId': groupId,
      });
      elements.add(conn);
      elementIds.add(conn.id);
    }

    if (node.children.isEmpty) {
      currentX += nodeW + hGap;
    } else {
      for (var i = 0; i < node.children.length; i++) {
        placeNode(
          node.children[i],
          y + nodeH + vGap,
          depth + 1,
          branchIndex + i,
        );
      }
    }
  }

  for (var r = 0; r < roots.length; r++) {
    placeNode(roots[r], center.y - 180, 0, r);
  }
}

/// Parses standard SVG shapes (rect, circle, ellipse, line, text) into native Canvas elements.
DiagramImportResult parseSvgDiagram(
  String svgText, {
  CanvasPoint? targetCenter,
  String Function()? idGenerator,
}) {
  final gen = idGenerator ?? _fallbackId;
  final center = targetCenter ?? const CanvasPoint(0, 0);

  final elements = <CanvasElement>[];
  final elementIds = <String>{};
  final groupId = 'grp_${gen()}';

  final rectMatches = RegExp(r'<rect\s+([^>]+)>').allMatches(svgText);
  for (final m in rectMatches) {
    final attrs = _parseXmlAttributes(m.group(1)!);
    final x = double.tryParse(attrs['x'] ?? '0') ?? 0.0;
    final y = double.tryParse(attrs['y'] ?? '0') ?? 0.0;
    final w = double.tryParse(attrs['width'] ?? '160') ?? 160.0;
    final h = double.tryParse(attrs['height'] ?? '80') ?? 80.0;
    final strokeColor = _parseColorHex(attrs['stroke']) ?? 0xff6366f1;

    final elem = CanvasElement({
      'id': gen(),
      'type': 'rectangle',
      'x': x,
      'y': y,
      'width': w,
      'height': h,
      'color': strokeColor,
      'groupId': groupId,
    });
    elements.add(elem);
    elementIds.add(elem.id);
  }

  final circleMatches = RegExp(r'<circle\s+([^>]+)>').allMatches(svgText);
  for (final m in circleMatches) {
    final attrs = _parseXmlAttributes(m.group(1)!);
    final cx = double.tryParse(attrs['cx'] ?? '0') ?? 0.0;
    final cy = double.tryParse(attrs['cy'] ?? '0') ?? 0.0;
    final r = double.tryParse(attrs['r'] ?? '40') ?? 40.0;
    final strokeColor = _parseColorHex(attrs['stroke']) ?? 0xff8b5cf6;

    final elem = CanvasElement({
      'id': gen(),
      'type': 'ellipse',
      'x': cx - r,
      'y': cy - r,
      'width': r * 2,
      'height': r * 2,
      'color': strokeColor,
      'groupId': groupId,
    });
    elements.add(elem);
    elementIds.add(elem.id);
  }

  final ellipseMatches = RegExp(r'<ellipse\s+([^>]+)>').allMatches(svgText);
  for (final m in ellipseMatches) {
    final attrs = _parseXmlAttributes(m.group(1)!);
    final cx = double.tryParse(attrs['cx'] ?? '0') ?? 0.0;
    final cy = double.tryParse(attrs['cy'] ?? '0') ?? 0.0;
    final rx = double.tryParse(attrs['rx'] ?? '60') ?? 60.0;
    final ry = double.tryParse(attrs['ry'] ?? '40') ?? 40.0;
    final strokeColor = _parseColorHex(attrs['stroke']) ?? 0xff8b5cf6;

    final elem = CanvasElement({
      'id': gen(),
      'type': 'ellipse',
      'x': cx - rx,
      'y': cy - ry,
      'width': rx * 2,
      'height': ry * 2,
      'color': strokeColor,
      'groupId': groupId,
    });
    elements.add(elem);
    elementIds.add(elem.id);
  }

  final lineMatches = RegExp(r'<line\s+([^>]+)>').allMatches(svgText);
  for (final m in lineMatches) {
    final attrs = _parseXmlAttributes(m.group(1)!);
    final x1 = double.tryParse(attrs['x1'] ?? '0') ?? 0.0;
    final y1 = double.tryParse(attrs['y1'] ?? '0') ?? 0.0;
    final x2 = double.tryParse(attrs['x2'] ?? '100') ?? 100.0;
    final y2 = double.tryParse(attrs['y2'] ?? '100') ?? 100.0;
    final strokeColor = _parseColorHex(attrs['stroke']) ?? 0xff3b82f6;

    final elem = CanvasElement({
      'id': gen(),
      'type': 'line',
      'startX': x1,
      'startY': y1,
      'endX': x2,
      'endY': y2,
      'color': strokeColor,
      'groupId': groupId,
    });
    elements.add(elem);
    elementIds.add(elem.id);
  }

  final textMatches = RegExp(
    r'<text\s+([^>]+)>(.*?)</text>',
    dotAll: true,
  ).allMatches(svgText);
  for (final m in textMatches) {
    final attrs = _parseXmlAttributes(m.group(1)!);
    final textContent = m.group(2)!.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    if (textContent.isEmpty) continue;

    final x = double.tryParse(attrs['x'] ?? '0') ?? 0.0;
    final y = double.tryParse(attrs['y'] ?? '0') ?? 0.0;
    final color = _parseColorHex(attrs['fill']) ?? 0xffe2e8f0;

    final elem = CanvasElement({
      'id': gen(),
      'type': 'text',
      'text': textContent,
      'x': x,
      'y': math.max(0.0, y - 16),
      'width': math.max(80.0, textContent.length * 9.0 + 20),
      'height': 40.0,
      'color': color,
      'groupId': groupId,
    });
    elements.add(elem);
    elementIds.add(elem.id);
  }

  if (elements.isEmpty) {
    return DiagramImportResult(
      elements: const [],
      groupId: groupId,
      elementIds: const {},
      summary:
          'No recognized SVG shapes found (supports rect, circle, ellipse, line, text).',
      bounds: CanvasBounds(center.x, center.y, 0, 0),
    );
  }

  CanvasBounds? origBounds;
  for (final e in elements) {
    origBounds = origBounds?.union(e.bounds) ?? e.bounds;
  }
  final b = origBounds ?? const CanvasBounds(0, 0, 400, 300);
  final dx = center.x - (b.left + b.width / 2);
  final dy = center.y - (b.top + b.height / 2);

  final centeredElements = elements
      .map((e) => e.translated(CanvasPoint(dx, dy)))
      .toList();

  return DiagramImportResult(
    elements: centeredElements,
    groupId: groupId,
    elementIds: elementIds,
    summary: 'Imported ${centeredElements.length} vector elements from SVG.',
    bounds: CanvasBounds(b.left + dx, b.top + dy, b.width, b.height),
  );
}

Map<String, String> _parseXmlAttributes(String raw) {
  final result = <String, String>{};
  final matches = RegExp(
    r'([a-zA-Z0-9_-]+)=["'
    "'"
    r']([^"'
    "'"
    r']*)["'
    "'"
    r']',
  ).allMatches(raw);
  for (final m in matches) {
    result[m.group(1)!] = m.group(2)!;
  }
  return result;
}

int? _parseColorHex(String? raw) {
  if (raw == null) return null;
  final clean = raw.trim().replaceFirst('#', '');
  if (clean.length == 6) {
    final v = int.tryParse('ff$clean', radix: 16);
    return v;
  } else if (clean.length == 8) {
    return int.tryParse(clean, radix: 16);
  }
  return null;
}

/// Catalog of curated production diagram templates ready for 1-click insertion.
List<DiagramTemplate> getDiagramTemplates() {
  return [
    DiagramTemplate(
      id: 'flowchart_decision',
      name: 'Decision Flowchart',
      description:
          'Start, Input, Decision diamond with Yes/No branches, Process, and End states.',
      category: 'Workflows & Logic',
      iconName: 'call_split',
      generator: (center, {idGenerator}) {
        final gen = idGenerator ?? _fallbackId;
        final gid = 'grp_${gen()}';
        final x = center.x - 360;
        final y = center.y - 120;

        final nStart = CanvasElement({
          'id': gen(),
          'type': 'ellipse',
          'text': 'Start',
          'x': x,
          'y': y + 60,
          'width': 120.0,
          'height': 60.0,
          'color': 0xff10b981,
          'groupId': gid,
        });

        final nInput = CanvasElement({
          'id': gen(),
          'type': 'rectangle',
          'text': 'Validate Input Payload',
          'x': x + 180,
          'y': y + 50,
          'width': 180.0,
          'height': 80.0,
          'color': 0xff6366f1,
          'groupId': gid,
        });

        final nDecision = CanvasElement({
          'id': gen(),
          'type': 'diamond',
          'text': 'Is Valid?',
          'x': x + 420,
          'y': y + 40,
          'width': 140.0,
          'height': 100.0,
          'color': 0xfff59e0b,
          'groupId': gid,
        });

        final nProcess = CanvasElement({
          'id': gen(),
          'type': 'card',
          'text': 'Execute Core Transaction\n& Commit Changes',
          'x': x + 620,
          'y': y - 20,
          'width': 200.0,
          'height': 80.0,
          'color': 0xff3b82f6,
          'groupId': gid,
        });

        final nError = CanvasElement({
          'id': gen(),
          'type': 'card',
          'text': 'Log Validation Error\nReturn 400 Bad Request',
          'x': x + 620,
          'y': y + 140,
          'width': 200.0,
          'height': 80.0,
          'color': 0xffec4899,
          'groupId': gid,
        });

        final nEnd = CanvasElement({
          'id': gen(),
          'type': 'ellipse',
          'text': 'End / Return',
          'x': x + 880,
          'y': y + 60,
          'width': 120.0,
          'height': 60.0,
          'color': 0xff10b981,
          'groupId': gid,
        });

        final c1 = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startId': nStart.id,
          'endId': nInput.id,
          'routing': 'orthogonal',
          'endMarker': 'arrow',
          'color': 0xff10b981,
          'groupId': gid,
        });

        final c2 = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startId': nInput.id,
          'endId': nDecision.id,
          'routing': 'orthogonal',
          'endMarker': 'arrow',
          'color': 0xff6366f1,
          'groupId': gid,
        });

        final cYes = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startId': nDecision.id,
          'endId': nProcess.id,
          'text': 'Yes',
          'routing': 'orthogonal',
          'endMarker': 'arrow',
          'color': 0xff10b981,
          'groupId': gid,
        });

        final cNo = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startId': nDecision.id,
          'endId': nError.id,
          'text': 'No',
          'routing': 'orthogonal',
          'endMarker': 'arrow',
          'color': 0xffec4899,
          'groupId': gid,
        });

        final c3 = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startId': nProcess.id,
          'endId': nEnd.id,
          'routing': 'orthogonal',
          'endMarker': 'arrow',
          'color': 0xff3b82f6,
          'groupId': gid,
        });

        final c4 = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startId': nError.id,
          'endId': nEnd.id,
          'routing': 'orthogonal',
          'endMarker': 'arrow',
          'color': 0xffec4899,
          'groupId': gid,
        });

        return [
          nStart,
          nInput,
          nDecision,
          nProcess,
          nError,
          nEnd,
          c1,
          c2,
          cYes,
          cNo,
          c3,
          c4,
        ];
      },
    ),
    DiagramTemplate(
      id: 'cloud_architecture',
      name: 'Microservices & Cloud Architecture',
      description:
          'Web/Mobile Clients, API Gateway, Auth/Core services, DB Cluster & Redis Cache.',
      category: 'Software Architecture',
      iconName: 'cloud_outlined',
      generator: (center, {idGenerator}) {
        final gen = idGenerator ?? _fallbackId;
        final gid = 'grp_${gen()}';
        final x = center.x - 420;
        final y = center.y - 140;

        final nClientWeb = CanvasElement({
          'id': gen(),
          'type': 'rectangle',
          'text': 'Web Client\nFlutter / WebApp',
          'x': x,
          'y': y,
          'width': 160.0,
          'height': 80.0,
          'color': 0xff0ea5e9,
          'groupId': gid,
        });

        final nClientMobile = CanvasElement({
          'id': gen(),
          'type': 'rectangle',
          'text': 'Mobile App\nAndroid / iOS',
          'x': x,
          'y': y + 140,
          'width': 160.0,
          'height': 80.0,
          'color': 0xff0ea5e9,
          'groupId': gid,
        });

        final nGateway = CanvasElement({
          'id': gen(),
          'type': 'card',
          'text':
              'API Gateway / Load Balancer\nRate Limiting & TLS Termination',
          'x': x + 240,
          'y': y + 60,
          'width': 220.0,
          'height': 100.0,
          'color': 0xff8b5cf6,
          'groupId': gid,
        });

        final nAuthService = CanvasElement({
          'id': gen(),
          'type': 'rectangle',
          'text': 'Auth Service\nJWT / OAuth2 / Sessions',
          'x': x + 530,
          'y': y,
          'width': 190.0,
          'height': 80.0,
          'color': 0xfff59e0b,
          'groupId': gid,
        });

        final nCoreService = CanvasElement({
          'id': gen(),
          'type': 'rectangle',
          'text': 'Core API Service\nBusiness Logic & REST',
          'x': x + 530,
          'y': y + 140,
          'width': 190.0,
          'height': 80.0,
          'color': 0xff6366f1,
          'groupId': gid,
        });

        final nDatabase = CanvasElement({
          'id': gen(),
          'type': 'card',
          'text': 'Primary Database\nPostgreSQL / SQLite Cluster',
          'x': x + 790,
          'y': y + 140,
          'width': 200.0,
          'height': 80.0,
          'color': 0xff10b981,
          'groupId': gid,
        });

        final nCache = CanvasElement({
          'id': gen(),
          'type': 'card',
          'text': 'Redis Cache\nIn-Memory Key/Value',
          'x': x + 790,
          'y': y,
          'width': 200.0,
          'height': 80.0,
          'color': 0xffec4899,
          'groupId': gid,
        });

        final cWeb = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startId': nClientWeb.id,
          'endId': nGateway.id,
          'routing': 'orthogonal',
          'endMarker': 'arrow',
          'color': 0xff0ea5e9,
          'groupId': gid,
        });

        final cMob = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startId': nClientMobile.id,
          'endId': nGateway.id,
          'routing': 'orthogonal',
          'endMarker': 'arrow',
          'color': 0xff0ea5e9,
          'groupId': gid,
        });

        final cGwAuth = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startId': nGateway.id,
          'endId': nAuthService.id,
          'routing': 'orthogonal',
          'endMarker': 'arrow',
          'color': 0xff8b5cf6,
          'groupId': gid,
        });

        final cGwCore = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startId': nGateway.id,
          'endId': nCoreService.id,
          'routing': 'orthogonal',
          'endMarker': 'arrow',
          'color': 0xff8b5cf6,
          'groupId': gid,
        });

        final cCoreDb = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startId': nCoreService.id,
          'endId': nDatabase.id,
          'routing': 'orthogonal',
          'endMarker': 'arrow',
          'color': 0xff10b981,
          'groupId': gid,
        });

        final cAuthCache = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startId': nAuthService.id,
          'endId': nCache.id,
          'routing': 'orthogonal',
          'endMarker': 'arrow',
          'color': 0xffec4899,
          'groupId': gid,
        });

        return [
          nClientWeb,
          nClientMobile,
          nGateway,
          nAuthService,
          nCoreService,
          nDatabase,
          nCache,
          cWeb,
          cMob,
          cGwAuth,
          cGwCore,
          cCoreDb,
          cAuthCache,
        ];
      },
    ),
    DiagramTemplate(
      id: 'sequence_flow',
      name: 'API Sequence Diagram',
      description:
          'Client, Auth Server, Resource Server, Database with labeled step transitions.',
      category: 'Software Architecture',
      iconName: 'swap_horiz',
      generator: (center, {idGenerator}) {
        final gen = idGenerator ?? _fallbackId;
        final gid = 'grp_${gen()}';
        final x = center.x - 380;
        final y = center.y - 180;

        final p1 = CanvasElement({
          'id': gen(),
          'type': 'rectangle',
          'text': 'Client (App)',
          'x': x,
          'y': y,
          'width': 140.0,
          'height': 50.0,
          'color': 0xff3b82f6,
          'groupId': gid,
        });

        final p2 = CanvasElement({
          'id': gen(),
          'type': 'rectangle',
          'text': 'Auth Server',
          'x': x + 240,
          'y': y,
          'width': 140.0,
          'height': 50.0,
          'color': 0xfff59e0b,
          'groupId': gid,
        });

        final p3 = CanvasElement({
          'id': gen(),
          'type': 'rectangle',
          'text': 'API Resource Server',
          'x': x + 480,
          'y': y,
          'width': 160.0,
          'height': 50.0,
          'color': 0xff8b5cf6,
          'groupId': gid,
        });

        final p4 = CanvasElement({
          'id': gen(),
          'type': 'rectangle',
          'text': 'Database',
          'x': x + 720,
          'y': y,
          'width': 140.0,
          'height': 50.0,
          'color': 0xff10b981,
          'groupId': gid,
        });

        final s1 = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startX': x + 70,
          'startY': y + 90,
          'endX': x + 310,
          'endY': y + 90,
          'text': '1. POST /login (credentials)',
          'endMarker': 'arrow',
          'color': 0xff3b82f6,
          'groupId': gid,
        });

        final s2 = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startX': x + 310,
          'startY': y + 140,
          'endX': x + 70,
          'endY': y + 140,
          'text': '2. 200 OK (JWT Token)',
          'strokeStyle': 'dashed',
          'endMarker': 'arrow',
          'color': 0xfff59e0b,
          'groupId': gid,
        });

        final s3 = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startX': x + 70,
          'startY': y + 200,
          'endX': x + 560,
          'endY': y + 200,
          'text': '3. GET /profile (Bearer Token)',
          'endMarker': 'arrow',
          'color': 0xff3b82f6,
          'groupId': gid,
        });

        final s4 = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startX': x + 560,
          'startY': y + 250,
          'endX': x + 790,
          'endY': y + 250,
          'text': '4. Query User Data',
          'endMarker': 'arrow',
          'color': 0xff8b5cf6,
          'groupId': gid,
        });

        final s5 = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startX': x + 790,
          'startY': y + 300,
          'endX': x + 560,
          'endY': y + 300,
          'text': '5. Return User Record',
          'strokeStyle': 'dashed',
          'endMarker': 'arrow',
          'color': 0xff10b981,
          'groupId': gid,
        });

        final s6 = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startX': x + 560,
          'startY': y + 350,
          'endX': x + 70,
          'endY': y + 350,
          'text': '6. 200 OK (User Profile JSON)',
          'strokeStyle': 'dashed',
          'endMarker': 'arrow',
          'color': 0xff8b5cf6,
          'groupId': gid,
        });

        return [p1, p2, p3, p4, s1, s2, s3, s4, s5, s6];
      },
    ),
    DiagramTemplate(
      id: 'erd_diagram',
      name: 'Entity Relationship Diagram (ERD)',
      description:
          'Relational data model: User, Order, OrderItem, and Product with 1:N relations.',
      category: 'Data & Modeling',
      iconName: 'schema_outlined',
      generator: (center, {idGenerator}) {
        final gen = idGenerator ?? _fallbackId;
        final gid = 'grp_${gen()}';
        final x = center.x - 380;
        final y = center.y - 120;

        final tUser = CanvasElement({
          'id': gen(),
          'type': 'card',
          'text':
              'User Table [users]\n• id: UUID (PK)\n• email: VARCHAR\n• name: VARCHAR\n• created_at: TIMESTAMP',
          'x': x,
          'y': y,
          'width': 220.0,
          'height': 120.0,
          'color': 0xff6366f1,
          'groupId': gid,
        });

        final tOrder = CanvasElement({
          'id': gen(),
          'type': 'card',
          'text':
              'Order Table [orders]\n• id: UUID (PK)\n• user_id: UUID (FK)\n• total_cents: INT\n• status: VARCHAR',
          'x': x + 300,
          'y': y,
          'width': 220.0,
          'height': 120.0,
          'color': 0xff3b82f6,
          'groupId': gid,
        });

        final tOrderItem = CanvasElement({
          'id': gen(),
          'type': 'card',
          'text':
              'Order Item [order_items]\n• id: UUID (PK)\n• order_id: UUID (FK)\n• product_id: UUID (FK)\n• quantity: INT',
          'x': x + 300,
          'y': y + 180,
          'width': 220.0,
          'height': 120.0,
          'color': 0xff0ea5e9,
          'groupId': gid,
        });

        final tProduct = CanvasElement({
          'id': gen(),
          'type': 'card',
          'text':
              'Product Table [products]\n• id: UUID (PK)\n• title: VARCHAR\n• price_cents: INT\n• stock_count: INT',
          'x': x + 600,
          'y': y + 180,
          'width': 220.0,
          'height': 120.0,
          'color': 0xff10b981,
          'groupId': gid,
        });

        final cUserOrder = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startId': tUser.id,
          'endId': tOrder.id,
          'text': '1 : N (places)',
          'routing': 'orthogonal',
          'endMarker': 'arrow',
          'color': 0xff6366f1,
          'groupId': gid,
        });

        final cOrderItems = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startId': tOrder.id,
          'endId': tOrderItem.id,
          'text': '1 : N (contains)',
          'routing': 'orthogonal',
          'endMarker': 'arrow',
          'color': 0xff3b82f6,
          'groupId': gid,
        });

        final cItemProduct = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startId': tOrderItem.id,
          'endId': tProduct.id,
          'text': 'N : 1 (references)',
          'routing': 'orthogonal',
          'endMarker': 'arrow',
          'color': 0xff10b981,
          'groupId': gid,
        });

        return [
          tUser,
          tOrder,
          tOrderItem,
          tProduct,
          cUserOrder,
          cOrderItems,
          cItemProduct,
        ];
      },
    ),
    DiagramTemplate(
      id: 'ai_state_machine',
      name: 'AI State Machine',
      description:
          'Finite State Machine: Idle, Patrol, Investigate, Combat, and Recovery states.',
      category: 'Workflows & Logic',
      iconName: 'psychology_outlined',
      generator: (center, {idGenerator}) {
        final gen = idGenerator ?? _fallbackId;
        final gid = 'grp_${gen()}';
        final x = center.x - 300;
        final y = center.y - 120;

        final sIdle = CanvasElement({
          'id': gen(),
          'type': 'ellipse',
          'text': 'IDLE\n[Standby]',
          'x': x,
          'y': y + 80,
          'width': 130.0,
          'height': 80.0,
          'color': 0xff6366f1,
          'groupId': gid,
        });

        final sPatrol = CanvasElement({
          'id': gen(),
          'type': 'rectangle',
          'text': 'PATROL\nFollow Waypoints',
          'x': x + 200,
          'y': y,
          'width': 160.0,
          'height': 70.0,
          'color': 0xff3b82f6,
          'groupId': gid,
        });

        final sInvestigate = CanvasElement({
          'id': gen(),
          'type': 'diamond',
          'text': 'ALERT?\nNoise / Sight',
          'x': x + 210,
          'y': y + 160,
          'width': 140.0,
          'height': 90.0,
          'color': 0xfff59e0b,
          'groupId': gid,
        });

        final sCombat = CanvasElement({
          'id': gen(),
          'type': 'card',
          'text': 'COMBAT ENGAGE\nAttack & Seek Cover',
          'x': x + 440,
          'y': y + 80,
          'width': 180.0,
          'height': 80.0,
          'color': 0xffec4899,
          'groupId': gid,
        });

        final c1 = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startId': sIdle.id,
          'endId': sPatrol.id,
          'text': 'Timer Expired',
          'routing': 'curved',
          'endMarker': 'arrow',
          'color': 0xff3b82f6,
          'groupId': gid,
        });

        final c2 = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startId': sPatrol.id,
          'endId': sInvestigate.id,
          'text': 'Sound Detected',
          'routing': 'curved',
          'endMarker': 'arrow',
          'color': 0xfff59e0b,
          'groupId': gid,
        });

        final c3 = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startId': sInvestigate.id,
          'endId': sCombat.id,
          'text': 'Enemy Confirmed',
          'routing': 'curved',
          'endMarker': 'arrow',
          'color': 0xffec4899,
          'groupId': gid,
        });

        final c4 = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startId': sCombat.id,
          'endId': sIdle.id,
          'text': 'Target Lost / Victory',
          'routing': 'curved',
          'endMarker': 'arrow',
          'color': 0xff6366f1,
          'groupId': gid,
        });

        return [sIdle, sPatrol, sInvestigate, sCombat, c1, c2, c3, c4];
      },
    ),
    DiagramTemplate(
      id: 'mindmap_strategy',
      name: 'Product Strategy Mind Map',
      description:
          'Central product vision with 4 radial pillars: Architecture, UX, AI, & Scale.',
      category: 'Brainstorming & Ideas',
      iconName: 'hub_outlined',
      generator: (center, {idGenerator}) {
        final gen = idGenerator ?? _fallbackId;
        final gid = 'grp_${gen()}';
        final x = center.x;
        final y = center.y;

        final root = CanvasElement({
          'id': gen(),
          'type': 'card',
          'text': 'Orbit Note\nPersonal Knowledge OS',
          'x': x - 110,
          'y': y - 50,
          'width': 220.0,
          'height': 100.0,
          'color': 0xff6366f1,
          'groupId': gid,
        });

        final pArchitecture = CanvasElement({
          'id': gen(),
          'type': 'rectangle',
          'text':
              'Local-First Engine\n• SQLite + Plain Markdown\n• Zero Remote Lock-in',
          'x': x - 340,
          'y': y - 140,
          'width': 190.0,
          'height': 80.0,
          'color': 0xff3b82f6,
          'groupId': gid,
        });

        final pCanvas = CanvasElement({
          'id': gen(),
          'type': 'rectangle',
          'text':
              'Universal Canvas\n• Spatial Cards & Ink\n• Connectors & Diagrams',
          'x': x + 150,
          'y': y - 140,
          'width': 190.0,
          'height': 80.0,
          'color': 0xff10b981,
          'groupId': gid,
        });

        final pGraph = CanvasElement({
          'id': gen(),
          'type': 'rectangle',
          'text':
              'Knowledge Relations\n• Bi-directional Links\n• Context Inspector',
          'x': x - 340,
          'y': y + 80,
          'width': 190.0,
          'height': 80.0,
          'color': 0xfff59e0b,
          'groupId': gid,
        });

        final pAI = CanvasElement({
          'id': gen(),
          'type': 'rectangle',
          'text':
              'Local AI Assistant\n• Private Retrieval\n• Reviewed Mutations',
          'x': x + 150,
          'y': y + 80,
          'width': 190.0,
          'height': 80.0,
          'color': 0xffec4899,
          'groupId': gid,
        });

        final c1 = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startId': root.id,
          'endId': pArchitecture.id,
          'routing': 'curved',
          'endMarker': 'arrow',
          'color': 0xff3b82f6,
          'groupId': gid,
        });

        final c2 = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startId': root.id,
          'endId': pCanvas.id,
          'routing': 'curved',
          'endMarker': 'arrow',
          'color': 0xff10b981,
          'groupId': gid,
        });

        final c3 = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startId': root.id,
          'endId': pGraph.id,
          'routing': 'curved',
          'endMarker': 'arrow',
          'color': 0xfff59e0b,
          'groupId': gid,
        });

        final c4 = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startId': root.id,
          'endId': pAI.id,
          'routing': 'curved',
          'endMarker': 'arrow',
          'color': 0xffec4899,
          'groupId': gid,
        });

        return [root, pArchitecture, pCanvas, pGraph, pAI, c1, c2, c3, c4];
      },
    ),
    DiagramTemplate(
      id: 'roadmap_timeline',
      name: 'Product Milestone Roadmap',
      description:
          'Horizontal release roadmap: Q1 Foundation, Q2 Core, Q3 Integrations, Q4 Scale.',
      category: 'Product & Planning',
      iconName: 'timeline',
      generator: (center, {idGenerator}) {
        final gen = idGenerator ?? _fallbackId;
        final gid = 'grp_${gen()}';
        final x = center.x - 440;
        final y = center.y - 50;

        final q1 = CanvasElement({
          'id': gen(),
          'type': 'card',
          'text':
              'M1: Storage & Identity\n• Universal Object Model\n• Markdown Persistence\n• Fast Search Engine',
          'x': x,
          'y': y,
          'width': 190.0,
          'height': 100.0,
          'color': 0xff6366f1,
          'groupId': gid,
        });

        final q2 = CanvasElement({
          'id': gen(),
          'type': 'card',
          'text':
              'M2: Note & Canvas OS\n• Rich Markdown Editor\n• Spatial Canvas & Ink\n• Dynamic Connectors',
          'x': x + 240,
          'y': y,
          'width': 190.0,
          'height': 100.0,
          'color': 0xff3b82f6,
          'groupId': gid,
        });

        final q3 = CanvasElement({
          'id': gen(),
          'type': 'card',
          'text':
              'M3: Research & PDF\n• Native PDF Annotation\n• Passage Linking\n• Split Co-Browsing',
          'x': x + 480,
          'y': y,
          'width': 190.0,
          'height': 100.0,
          'color': 0xff10b981,
          'groupId': gid,
        });

        final q4 = CanvasElement({
          'id': gen(),
          'type': 'card',
          'text':
              'M4: Diagrams & Sync\n• Diagram Importers\n• P2P Replica Sync\n• Local AI Insights',
          'x': x + 720,
          'y': y,
          'width': 190.0,
          'height': 100.0,
          'color': 0xfff59e0b,
          'groupId': gid,
        });

        final c12 = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startId': q1.id,
          'endId': q2.id,
          'routing': 'orthogonal',
          'endMarker': 'arrow',
          'color': 0xff6366f1,
          'groupId': gid,
        });

        final c23 = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startId': q2.id,
          'endId': q3.id,
          'routing': 'orthogonal',
          'endMarker': 'arrow',
          'color': 0xff3b82f6,
          'groupId': gid,
        });

        final c34 = CanvasElement({
          'id': gen(),
          'type': 'connector',
          'startId': q3.id,
          'endId': q4.id,
          'routing': 'orthogonal',
          'endMarker': 'arrow',
          'color': 0xff10b981,
          'groupId': gid,
        });

        return [q1, q2, q3, q4, c12, c23, c34];
      },
    ),
  ];
}
