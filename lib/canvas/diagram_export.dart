import 'dart:math' as math;

import 'scene.dart';

/// Exports elements from a [CanvasScene] into standard Mermaid flowchart syntax.
///
/// Supports:
/// - Shapes: rectangle (`[]`), sticky (`()`), card (`([])`), ellipse (`(())`),
///   diamond (`{}`), section (`>]`), and frame subgraphs.
/// - Connectors: solid (`-->`), dashed (`-.->`), thick (`==>`), bidirectional (`<-->`),
///   undirected (`---`), and edge labels (`-->|text|`).
/// - Auto-layout direction detection (`TD`, `LR`, `BT`, `RL`).
/// - Subgroup preservation via `groupId` or enclosing frames.
/// - Pure Dart implementation independent of Flutter or web services.
String exportToMermaid(
  CanvasScene scene, {
  Iterable<String>? elementIds,
  String direction = 'TD',
  bool includeSubgraphs = true,
  bool wrapMarkdownFence = false,
}) {
  final targetIds = elementIds?.toSet();

  // 1. Separate candidates into nodes and potential connectors
  final candidateNodes = <CanvasElement>[];
  final candidateEdges = <CanvasElement>[];

  for (final elem in scene.elementsInOrder) {
    if (elem.hidden || !elem.renderable) continue;
    if (targetIds != null && !targetIds.contains(elem.id)) continue;

    if (_isConnector(elem)) {
      candidateEdges.add(elem);
    } else if (_isNode(elem)) {
      candidateNodes.add(elem);
    }
  }

  // Also check if any connectors in the scene connect selected nodes
  if (targetIds != null && targetIds.isNotEmpty) {
    final nodeIds = candidateNodes.map((n) => n.id).toSet();
    for (final elem in scene.elementsInOrder) {
      if (elem.hidden || !elem.renderable || !_isConnector(elem)) continue;
      if (candidateEdges.contains(elem)) continue;
      if (elem.startId != null &&
          elem.endId != null &&
          nodeIds.contains(elem.startId) &&
          nodeIds.contains(elem.endId)) {
        candidateEdges.add(elem);
      }
    }
  }

  if (candidateNodes.isEmpty && candidateEdges.isEmpty) {
    final emptyDiagram = 'flowchart $direction\n';
    return wrapMarkdownFence ? '```mermaid\n$emptyDiagram```\n' : emptyDiagram;
  }

  // 2. Resolve layout direction if 'auto'
  var resolvedDirection = direction.toUpperCase();
  if (resolvedDirection == 'AUTO') {
    resolvedDirection = _detectFlowDirection(candidateNodes, candidateEdges);
  }
  if (!['TD', 'TB', 'BT', 'LR', 'RL'].contains(resolvedDirection)) {
    resolvedDirection = 'TD';
  }

  // 3. Map element IDs to clean Mermaid-safe identifiers
  final idMap = <String, String>{};
  var nodeCounter = 1;
  for (final node in candidateNodes) {
    idMap[node.id] = _sanitizeMermaidId(node.id, nodeCounter++);
  }

  // 4. Grouping / Subgraphs
  final buffer = StringBuffer();
  buffer.writeln('flowchart $resolvedDirection');

  final processedNodeIds = <String>{};

  if (includeSubgraphs) {
    // A. Group by groupId
    final groups = <String, List<CanvasElement>>{};
    for (final node in candidateNodes) {
      if (node.groupId != null && node.groupId!.isNotEmpty) {
        groups.putIfAbsent(node.groupId!, () => []).add(node);
      }
    }

    var groupCounter = 1;
    for (final entry in groups.entries) {
      if (entry.value.length < 2) continue; // Singletons need no subgraph
      final groupKey = 'group_${groupCounter++}';
      final firstElem = entry.value.first;
      final groupLabel =
          firstElem.groupId != null && !firstElem.groupId!.startsWith('grp_')
          ? firstElem.groupId!
          : 'Group ${groupCounter - 1}';

      buffer.writeln('  subgraph $groupKey["${_escapeLabel(groupLabel)}"]');
      for (final node in entry.value) {
        final mId = idMap[node.id]!;
        buffer.writeln('    ${_formatNodeSyntax(node, mId)}');
        processedNodeIds.add(node.id);
      }
      buffer.writeln('  end');
    }

    // B. Group by frame containment (if frame contains nodes)
    final frames = candidateNodes.where((n) => n.type == 'frame').toList();
    for (final frame in frames) {
      if (processedNodeIds.contains(frame.id)) continue;
      final contained = candidateNodes.where((n) {
        if (n.id == frame.id || processedNodeIds.contains(n.id)) return false;
        return frame.bounds.left <= n.bounds.left &&
            frame.bounds.right >= n.bounds.right &&
            frame.bounds.top <= n.bounds.top &&
            frame.bounds.bottom >= n.bounds.bottom;
      }).toList();

      if (contained.isNotEmpty) {
        final frameKey = idMap[frame.id]!;
        final frameTitle = frame.text.isNotEmpty ? frame.text : 'Frame';
        buffer.writeln('  subgraph $frameKey["${_escapeLabel(frameTitle)}"]');
        for (final node in contained) {
          final mId = idMap[node.id]!;
          buffer.writeln('    ${_formatNodeSyntax(node, mId)}');
          processedNodeIds.add(node.id);
        }
        buffer.writeln('  end');
        processedNodeIds.add(frame.id);
      }
    }
  }

  // 5. Output remaining standalone / top-level nodes
  for (final node in candidateNodes) {
    if (processedNodeIds.contains(node.id)) continue;
    final mId = idMap[node.id]!;
    buffer.writeln('  ${_formatNodeSyntax(node, mId)}');
    processedNodeIds.add(node.id);
  }

  // 6. Output Edges / Connectors
  for (final edge in candidateEdges) {
    final startId = edge.startId;
    final endId = edge.endId;
    if (startId == null || endId == null) continue;

    final startMId = idMap[startId];
    final endMId = idMap[endId];
    if (startMId == null || endMId == null) continue;

    final edgeSyntax = _formatEdgeSyntax(edge);
    buffer.writeln('  $startMId $edgeSyntax $endMId');
  }

  final mermaidCode = buffer.toString();
  if (wrapMarkdownFence) {
    return '```mermaid\n$mermaidCode```\n';
  }
  return mermaidCode;
}

/// Converts a selection of canvas elements into a cohesive Markdown note
/// with metadata, source canvas backlinks, embedded Mermaid diagrams, and
/// extracted item summaries.
String extractSelectionToMarkdown(
  CanvasScene scene,
  Iterable<String> selection, {
  required String canvasId,
  String canvasTitle = 'Canvas',
}) {
  final targetIds = selection.toSet();
  final selectedNodes = scene.elementsInOrder
      .where((e) => targetIds.contains(e.id) && _isNode(e))
      .toList();

  final selectedEdges = scene.elementsInOrder
      .where((e) => targetIds.contains(e.id) && _isConnector(e))
      .toList();

  final buffer = StringBuffer();

  // Document Title
  buffer.writeln('# $canvasTitle — Extracted Notes');
  buffer.writeln();

  // Context & Backlink
  buffer.writeln(
    '> Extracted from spatial canvas [$canvasTitle](orbit://canvas/$canvasId)',
  );
  buffer.writeln();

  // Embedded Mermaid Diagram if there are multiple nodes or connectors
  if (selectedNodes.length >= 2 || selectedEdges.isNotEmpty) {
    final mermaid = exportToMermaid(
      scene,
      elementIds: targetIds,
      direction: 'TD',
      wrapMarkdownFence: true,
    );
    buffer.writeln('## Diagram Overview');
    buffer.writeln();
    buffer.write(mermaid);
    buffer.writeln();
  }

  // Detailed Items
  if (selectedNodes.isNotEmpty) {
    buffer.writeln('## Extracted Elements');
    buffer.writeln();

    for (final node in selectedNodes) {
      final title = _resolveNodeTitle(node);
      final subtitle = _resolveNodeSubtitle(node);

      switch (node.type) {
        case 'sticky':
          buffer.writeln('### Sticky: $title');
          if (node.text.isNotEmpty && node.text != title) {
            buffer.writeln(node.text);
          }
          buffer.writeln();

        case 'card':
          final isTask = node.data['isTask'] == true;
          if (isTask) {
            final isDone = node.data['isDone'] == true;
            buffer.writeln('- [${isDone ? 'x' : ' '}] $title');
          } else {
            buffer.writeln('### $title');
            if (subtitle.isNotEmpty) {
              buffer.writeln('*$subtitle*');
              buffer.writeln();
            }
            if (node.text.isNotEmpty && node.text != title) {
              final body = node.text
                  .split(RegExp(r'\r?\n'))
                  .skip(1)
                  .join('\n')
                  .trim();
              if (body.isNotEmpty) {
                buffer.writeln(body);
                buffer.writeln();
              }
            }
            if (node.objectId != null && node.objectId!.isNotEmpty) {
              buffer.writeln('Referenced object: [[${node.objectId}|$title]]');
              buffer.writeln();
            }
          }

        case 'rectangle':
        case 'frame':
        case 'ellipse':
        case 'diamond':
          buffer.writeln('### ${_capitalize(node.type)}: $title');
          if (node.text.isNotEmpty && node.text != title) {
            buffer.writeln(node.text);
          }
          buffer.writeln();

        case 'text':
          buffer.writeln(node.text);
          buffer.writeln();

        default:
          buffer.writeln('- **$title**');
      }
    }
  }

  // Extracted Connections
  if (selectedEdges.isNotEmpty) {
    buffer.writeln('## Relationships');
    buffer.writeln();
    for (final edge in selectedEdges) {
      final fromElem = edge.startId != null ? scene[edge.startId!] : null;
      final toElem = edge.endId != null ? scene[edge.endId!] : null;
      if (fromElem != null && toElem != null) {
        final fromTitle = _resolveNodeTitle(fromElem);
        final toTitle = _resolveNodeTitle(toElem);
        final label = edge.text.trim().isNotEmpty
            ? ' (${edge.text.trim()})'
            : '';
        buffer.writeln('- $fromTitle --> $toTitle$label');
      }
    }
    buffer.writeln();
  }

  return buffer.toString();
}

bool _isNode(CanvasElement e) {
  return e.type == 'rectangle' ||
      e.type == 'sticky' ||
      e.type == 'card' ||
      e.type == 'ellipse' ||
      e.type == 'diamond' ||
      e.type == 'frame' ||
      e.type == 'text' ||
      e.type == 'section' ||
      e.type == 'column';
}

bool _isConnector(CanvasElement e) {
  return e.type == 'connector' || e.type == 'arrow' || e.type == 'line';
}

String _sanitizeMermaidId(String rawId, int fallbackIndex) {
  // Strip non-alphanumeric chars
  final cleaned = rawId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  if (cleaned.isEmpty || RegExp(r'^[0-9]').hasMatch(cleaned)) {
    return 'node_$fallbackIndex';
  }
  return cleaned;
}

String _escapeLabel(String text) {
  return text
      .replaceAll('"', "'")
      .replaceAll('\r\n', '<br/>')
      .replaceAll('\n', '<br/>')
      .trim();
}

String _resolveNodeTitle(CanvasElement elem) {
  if (elem.type == 'card') {
    final nested = elem.data['data'] is Map ? elem.data['data'] as Map : null;
    if (elem.data['title'] is String &&
        (elem.data['title'] as String).isNotEmpty) {
      return elem.data['title'] as String;
    }
    if (nested?['title'] is String && (nested!['title'] as String).isNotEmpty) {
      return nested['title'] as String;
    }
  }
  if (elem.text.trim().isNotEmpty) {
    final firstLine = elem.text.split(RegExp(r'\r?\n')).first.trim();
    if (firstLine.isNotEmpty) return firstLine;
  }
  return _capitalize(elem.type.isNotEmpty ? elem.type : 'Node');
}

String _resolveNodeSubtitle(CanvasElement elem) {
  final nested = elem.data['data'] is Map ? elem.data['data'] as Map : null;
  if (elem.data['subtitle'] is String) {
    return elem.data['subtitle'] as String;
  }
  if (nested?['subtitle'] is String) {
    return nested!['subtitle'] as String;
  }
  return '';
}

String _formatNodeSyntax(CanvasElement node, String mermaidId) {
  final title = _resolveNodeTitle(node);
  final subtitle = _resolveNodeSubtitle(node);
  final fullLabel = subtitle.isNotEmpty ? '$title<br/>$subtitle' : title;
  final escaped = _escapeLabel(fullLabel);

  switch (node.type) {
    case 'rectangle':
    case 'frame':
    case 'column':
    case 'text':
      return '$mermaidId["$escaped"]';
    case 'sticky':
      return '$mermaidId("$escaped")';
    case 'card':
      return '$mermaidId(["$escaped"])';
    case 'ellipse':
      return '$mermaidId(("$escaped"))';
    case 'diamond':
      return '$mermaidId{"$escaped"}';
    case 'section':
      return '$mermaidId>"$escaped"]';
    default:
      return '$mermaidId["$escaped"]';
  }
}

String _formatEdgeSyntax(CanvasElement edge) {
  final isDashed = edge.strokeStyle == 'dashed' || edge.strokeStyle == 'dotted';
  final isThick = edge.strokeWidth >= 3.5;
  final hasStartArrow = edge.startMarker == 'arrow';
  final hasEndArrow =
      edge.endMarker == 'arrow' ||
      (edge.type == 'arrow' && edge.endMarker != 'none');
  final isBidirectional = hasStartArrow && hasEndArrow;
  final isUndirected = !hasStartArrow && !hasEndArrow;

  String stem;
  if (isBidirectional) {
    stem = isDashed ? '<-.->' : (isThick ? '<==>' : '<-->');
  } else if (isUndirected) {
    stem = isDashed ? '-.-' : (isThick ? '===' : '---');
  } else if (hasStartArrow && !hasEndArrow) {
    stem = isDashed ? '<-.-' : (isThick ? '<==' : '<--');
  } else {
    // Standard forward directed arrow
    stem = isDashed ? '-.->' : (isThick ? '==>' : '-->');
  }

  final label = edge.text.trim();
  if (label.isEmpty) {
    return stem;
  }

  final escapedLabel = _escapeLabel(label);
  return '$stem|$escapedLabel|';
}

String _detectFlowDirection(
  List<CanvasElement> nodes,
  List<CanvasElement> edges,
) {
  if (edges.isEmpty) {
    if (nodes.length >= 2) {
      var minX = double.infinity;
      var maxX = -double.infinity;
      var minY = double.infinity;
      var maxY = -double.infinity;
      for (final n in nodes) {
        minX = math.min(minX, n.x);
        maxX = math.max(maxX, n.x + n.width);
        minY = math.min(minY, n.y);
        maxY = math.max(maxY, n.y + n.height);
      }
      final spanX = (maxX - minX).abs();
      final spanY = (maxY - minY).abs();
      return spanX > spanY * 1.3 ? 'LR' : 'TD';
    }
    return 'TD';
  }

  final nodeMap = {for (final n in nodes) n.id: n};
  var dxSum = 0.0;
  var dySum = 0.0;

  for (final edge in edges) {
    final s = nodeMap[edge.startId];
    final e = nodeMap[edge.endId];
    if (s != null && e != null) {
      dxSum += (e.x - s.x).abs();
      dySum += (e.y - s.y).abs();
    }
  }

  return dxSum > dySum * 1.2 ? 'LR' : 'TD';
}

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}
