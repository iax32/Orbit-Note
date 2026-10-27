import '../domain/university/lab_document.dart';
import '../domain/university/state_lab.dart';
import '../domain/university/distributed_lab.dart';
import 'geometry.dart';
import 'scene.dart';
import 'uml.dart';
import 'uml_interaction.dart';

/// All teaching nodes remain ordinary editable placements with stable connector
/// endpoints. The frame stores the portable model; no alternate canvas engine.
List<CanvasElement> universityDiagram(
  UniversityDocument doc,
  String Function() id,
  CanvasPoint at, {
  CanvasElement? existingFrame,
  List<CanvasElement> existing = const [],
}) {
  final m = doc.model, kind = doc.kind;
  if (kind == UniversityLabKind.distributed) {
    return _distributedDiagram(
      doc,
      id,
      at,
      existingFrame: existingFrame,
      existing: existing,
    );
  }
  final rows = kind == UniversityLabKind.state
      ? labRows(m['states'], limit: 100)
      : kind == UniversityLabKind.distributed
      ? [
          for (final p in (m['processes'] as List))
            {'id': p, 'name': p, 'kind': 'process'},
        ]
      : {
          UniversityLabKind.activity,
          UniversityLabKind.uml,
          UniversityLabKind.testing,
        }.contains(kind)
      ? labRows(m['nodes'], limit: 150)
      : <Map<String, dynamic>>[];
  final result = <CanvasElement>[], placements = <String, CanvasElement>{};
  final frame = existingFrame?.id ?? id();
  final oldNodes = <String, CanvasElement>{
    for (final e in existing)
      if (e.data['universityNode'] is Map)
        '${(e.data['universityNode'] as Map)['id']}': e,
  };
  final oldEdges = <String, CanvasElement>{
    for (final e in existing)
      if (e.data['universityEdge'] is String)
        e.data['universityEdge'] as String: e,
  };
  final layout = <String, CanvasBounds>{};
  var width = rows.length < 4 ? 960.0 : 1280.0;
  var height = rows.isEmpty ? 540.0 : ((rows.length + 3) ~/ 4) * 210.0 + 180;
  if (kind == UniversityLabKind.state) {
    final lab = StateLab(m);
    double measure(String key) {
      final children = rows.where((r) => r['parent'] == key).toList();
      if (children.isEmpty) return 260;
      return children.fold<double>(
        40,
        (sum, r) => sum + measure(r['id'] as String) + 24,
      );
    }

    double place(String key, double x, double y) {
      final children = rows.where((r) => r['parent'] == key).toList(),
          w = measure(key);
      var nextX = x + 20, maxHeight = 0.0;
      for (final child in children) {
        final h = place(child['id'] as String, nextX, y + 145);
        if (h > maxHeight) maxHeight = h;
        nextX += measure(child['id'] as String) + 24;
      }
      final h = children.isEmpty ? 130.0 : maxHeight + 175;
      layout[key] = CanvasBounds(x, y, w, h);
      return h;
    }

    final roots = rows.where((r) => labText(r, 'parent').isEmpty).toList();
    var maxWidth = 260.0, maxHeight = 130.0;
    for (final root in roots) {
      final w = measure(root['id'] as String),
          h = place(root['id'] as String, 0, 0);
      if (w > maxWidth) maxWidth = w;
      if (h > maxHeight) maxHeight = h;
    }
    for (var i = 0; i < roots.length; i++) {
      place(
        roots[i]['id'] as String,
        at.x + 100 + (i % 2) * (maxWidth + 220),
        at.y + 110 + (i ~/ 2) * (maxHeight + 220),
      );
    }
    width = (roots.length == 1 ? 1 : 2) * (maxWidth + 220) + 160;
    height = ((roots.length + 1) ~/ 2) * (maxHeight + 220) + 120;
    rows.sort(
      (a, b) => lab
          .path(a['id'] as String)
          .length
          .compareTo(lab.path(b['id'] as String).length),
    );
  }
  final lanes = kind == UniversityLabKind.activity
      ? rows
            .map(
              (r) =>
                  labText(r, 'lane').isEmpty ? 'Control' : labText(r, 'lane'),
            )
            .toSet()
            .toList()
      : <String>[];
  if (lanes.isNotEmpty) {
    width = lanes.length * 320.0 + 60;
    var tallest = 0;
    for (final lane in lanes) {
      final members = rows
          .where(
            (r) =>
                (labText(r, 'lane').isEmpty ? 'Control' : labText(r, 'lane')) ==
                lane,
          )
          .toList();
      if (members.length > tallest) tallest = members.length;
      for (var i = 0; i < members.length; i++) {
        layout[members[i]['id'] as String] = CanvasBounds(
          at.x + 55 + lanes.indexOf(lane) * 320,
          at.y + 145 + i * 170,
          260,
          120,
        );
      }
    }
    height = tallest * 170.0 + 190;
  }
  result.add(
    CanvasElement({
      ...?existingFrame?.data,
      'id': frame,
      'type': 'frame',
      'x': at.x,
      'y': at.y,
      'width': width,
      'height': height,
      'text': doc.title,
      'universityModel': doc.data,
    }),
  );
  for (var i = 0; i < lanes.length; i++) {
    result.add(
      CanvasElement({
        'id': id(),
        'type': 'frame',
        'groupId': frame,
        'x': at.x + 30 + i * 320,
        'y': at.y + 80,
        'width': 300.0,
        'height': height - 110,
        'text': lanes[i],
      }),
    );
  }
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i],
        old = oldNodes[row['id']],
        nodeKind = kind == UniversityLabKind.state
            ? (row['final'] == true ? 'final' : 'state')
            : labText(row, 'kind'),
        nodeId = old?.id ?? id();
    final bounds = layout[row['id']];
    final x = old?.x ?? bounds?.left ?? at.x + 40 + (i % 4) * 300,
        y = old?.y ?? bounds?.top ?? at.y + 85 + (i ~/ 4) * 210;
    var type = 'rectangle',
        w = bounds?.width ?? 240.0,
        h = bounds?.height ?? 130.0;
    if ({'decision', 'merge', 'nary'}.contains(nodeKind)) {
      type = 'diamond';
      w = 170;
      h = 110;
    }
    if ({'start', 'final', 'flowFinal'}.contains(nodeKind) ||
        row['final'] == true) {
      type = 'ellipse';
      w = 70;
      h = 70;
    }
    if ({'fork', 'join'}.contains(nodeKind)) {
      h = 18;
    }
    final text = StringBuffer(
      labText(row, 'name').isEmpty ? row['id'] : row['name'],
    );
    if (kind == UniversityLabKind.state) {
      for (final transition in labRows(
        m['transitions'],
      ).where((t) => t['internal'] == true && t['from'] == row['id'])) {
        text.write(
          '\n${labText(transition, 'event')} [${labText(transition, 'guard')}] / ${labText(transition, 'actions')}',
        );
      }
    }
    for (final field in [
      'entry',
      'do',
      'exit',
      'parent',
      'region',
      'lane',
      'signal',
      'actions',
      'slots',
      'defs',
      'uses',
    ]) {
      if (labText(row, field).isNotEmpty) {
        text.write('\n$field / ${row[field]}');
      }
    }
    final node = CanvasElement({
      ...?old?.data,
      'id': nodeId,
      'type': type,
      'x': x,
      'y': y,
      'width': old?.width ?? w,
      'height': old?.height ?? h,
      'text': text.toString(),
      'strokeWidth': 1.5,
      'groupId': frame,
      'universityNode': {
        'id': row['id'],
        'kind': nodeKind,
        'modelKind': kind.name,
        'composite':
            kind == UniversityLabKind.state &&
            rows.any((r) => r['parent'] == row['id']),
      },
      if (kind == UniversityLabKind.uml &&
          {'class', 'associationClass'}.contains(nodeKind))
        'uml': {
          'attributes': labText(
            row,
            'attributes',
          ).split('\n').where((s) => s.isNotEmpty).toList(),
          'operations': labText(
            row,
            'operations',
          ).split('\n').where((s) => s.isNotEmpty).toList(),
          'abstract': row['abstract'] == true,
          'stereotype': nodeKind == 'associationClass'
              ? 'association class'
              : '',
        },
    });
    placements[row['id'] as String] = node;
    result.add(node);
  }
  final edges = kind == UniversityLabKind.state
      ? labRows(m['transitions'])
      : m['edges'] is List
      ? labRows(m['edges'])
      : <Map<String, dynamic>>[];
  for (var edgeIndex = 0; edgeIndex < edges.length; edgeIndex++) {
    final e = edges[edgeIndex],
        edgeKey = labText(edges[edgeIndex], 'id').isEmpty
            ? 'edge:$edgeIndex'
            : labText(edges[edgeIndex], 'id'),
        old =
            oldEdges[labText(edges[edgeIndex], 'id').isEmpty
                ? 'edge:$edgeIndex'
                : labText(edges[edgeIndex], 'id')];
    if (e['internal'] == true) continue;
    final a = placements[e['from']], b = placements[e['to']];
    if (a == null || b == null) {
      throw const FormatException('Cannot draw a missing endpoint.');
    }
    final label = [
      labText(e, 'label'),
      labText(e, 'event'),
      if (labText(e, 'guard').isNotEmpty) '[${e['guard']}]',
      if (labText(e, 'actions').isNotEmpty) '/ ${e['actions']}',
    ].where((s) => s.isNotEmpty).join('\n');
    final relationship = UmlRelationship.values
        .where((r) => r.name == e['kind'])
        .firstOrNull;
    result.add(
      CanvasElement({
        ...?old?.data,
        'id': old?.id ?? id(),
        'universityEdge': edgeKey,
        'type': 'connector',
        'groupId': frame,
        'startId': a.id,
        'endId': b.id,
        'startX': a.x + a.width,
        'startY': a.y + a.height / 2,
        'endX': b.x,
        'endY': b.y + b.height / 2,
        'routing': 'orthogonal',
        'routingOffset': (edgeIndex % 5 - 2) * 22.0,
        'startAnchorOffset': .2 + (edgeIndex % 4) * .18,
        'endAnchorOffset': .25 + (edgeIndex % 3) * .22,
        'text': label,
        'strokeWidth': 1.5,
        'startMarker': relationship?.startMarker ?? 'none',
        'endMarker': relationship?.endMarker ?? 'arrow',
        'strokeStyle': relationship?.dashed == true ? 'dashed' : 'solid',
        'startMultiplicity': labText(e, 'fromMultiplicity'),
        'endMultiplicity': labText(e, 'toMultiplicity'),
        if (relationship != null) 'umlRelationship': relationship.name,
      }),
    );
  }
  if (rows.isEmpty) {
    result.add(
      CanvasElement({
        'id': id(),
        'type': 'text',
        'groupId': frame,
        'x': at.x + 36,
        'y': at.y + 80,
        'width': width - 72,
        'height': 420,
        'text': doc.report(),
      }),
    );
  }
  return result;
}

List<CanvasElement> _distributedDiagram(
  UniversityDocument doc,
  String Function() id,
  CanvasPoint at, {
  CanvasElement? existingFrame,
  List<CanvasElement> existing = const [],
}) {
  final model = doc.model,
      trace = distributedTrace(model),
      events = labRows(model['events'], limit: 500),
      processes = (model['processes'] as List).cast<String>();
  final old = {
    for (final e in existing)
      if (e.data['universityKey'] is String)
        e.data['universityKey'] as String: e,
  };
  String keyId(String key) => old[key]?.id ?? id();
  final frame = existingFrame?.id ?? id(),
      height = trace.length * 85.0 + 180,
      width = processes.length * 300.0 + 80;
  final result = <CanvasElement>[
    CanvasElement({
      ...?existingFrame?.data,
      'id': frame,
      'type': 'frame',
      'x': at.x,
      'y': at.y,
      'width': width,
      'height': height,
      'text': doc.title,
      'universityModel': doc.data,
    }),
  ];
  for (var i = 0; i < processes.length; i++) {
    result.add(
      CanvasElement({
        'id': keyId('process:$i'),
        'universityKey': 'process:$i',
        'type': 'rectangle',
        'groupId': frame,
        'x': at.x + 45 + i * 300,
        'y': at.y + 70,
        'width': 190.0,
        'height': height - 100,
        'text': processes[i],
        'umlNode': {'kind': 'lifeline'},
      }),
    );
  }
  final senders = <String, CanvasElement>{};
  for (var i = 0; i < trace.length; i++) {
    final s = trace[i], e = events[i], key = 'event:$i', prior = old[key];
    final event = CanvasElement({
      ...?prior?.data,
      'id': keyId(key),
      'universityKey': key,
      'type': 'rectangle',
      'groupId': frame,
      'x': prior?.x ?? at.x + 50 + processes.indexOf(s.process) * 300,
      'y': prior?.y ?? at.y + 145 + i * 85,
      'width': 200.0,
      'height': 64.0,
      'text':
          '${s.process}: ${s.detail}\nL=${s.lamport} · V=${s.vector.join(',')}',
      'universityNode': {'id': key, 'kind': 'event'},
    });
    result.add(event);
    final message = labText(e, 'message');
    if (e['kind'] == 'send') senders[message] = event;
    if (e['kind'] == 'receive') {
      final from = senders[message]!;
      result.add(
        CanvasElement({
          'id': keyId('message:$message'),
          'universityKey': 'message:$message',
          'type': 'connector',
          'groupId': frame,
          'startId': from.id,
          'endId': event.id,
          'startX': from.x + from.width / 2,
          'startY': from.y + from.height / 2,
          'endX': event.x + event.width / 2,
          'endY': event.y + event.height / 2,
          'text': message,
          'routing': 'straight',
          'endMarker': 'arrow',
          'strokeWidth': 1.5,
        }),
      );
    }
  }
  return result;
}

UniversityDocument? universityModelFromSelection(
  CanvasScene scene,
  Set<String> selection,
) {
  final frames = scene.elements
      .where(
        (e) =>
            e.data['universityModel'] is Map &&
            (selection.contains(e.id) ||
                scene.elements.any(
                  (n) => selection.contains(n.id) && n.groupId == e.id,
                )),
      )
      .toList();
  if (frames.length > 1) {
    throw const FormatException('Select one university frame.');
  }
  if (frames.isEmpty) return null;
  final frame = frames.single,
      doc = UniversityDocument(labMap(frames.single.data['universityModel'])),
      model = _modelFromMembers(
        frame,
        scene.elements.where((e) => e.groupId == frame.id).toList(),
      );
  return doc.updated({'model': model});
}

Map<String, dynamic> _modelFromMembers(
  CanvasElement frame,
  List<CanvasElement> members,
) {
  final doc = UniversityDocument(labMap(frame.data['universityModel'])),
      model = doc.model;
  final nodes = {
    for (final e in members)
      if (e.data['universityNode'] is Map)
        '${(e.data['universityNode'] as Map)['id']}': e,
  };
  final ids = {for (final e in nodes.entries) e.value.id: e.key};
  final key = doc.kind == UniversityLabKind.state ? 'states' : 'nodes';
  if (model[key] is List) {
    model[key] = [
      for (final original in labRows(model[key]))
        (() {
          final node = nodes[original['id']];
          if (node == null) return original;
          final row = Map<String, dynamic>.from(original),
              lines = node.text.split('\n');
          if (row['name'] is String && lines.isNotEmpty) {
            row['name'] = lines.first;
          }
          if (isUmlClass(node)) {
            row['attributes'] = UmlClass(node).attributes.join('\n');
            row['operations'] = UmlClass(node).operations.join('\n');
          }
          for (final line in lines.skip(1)) {
            final m = RegExp(
              r'^(entry|do|exit|parent|region|lane|signal|actions|slots|defs|uses) / (.*)$',
            ).firstMatch(line);
            if (m != null) row[m[1]!] = m[2]!;
          }
          return row;
        })(),
    ];
  }
  final edgeKey = doc.kind == UniversityLabKind.state ? 'transitions' : 'edges',
      edges = {
        for (final e in members)
          if (e.data['universityEdge'] is String) e.data['universityEdge']: e,
      };
  if (model[edgeKey] is List) {
    model[edgeKey] = [
      for (final (index, original) in labRows(model[edgeKey]).indexed)
        (() {
          final lookup = labText(original, 'id').isEmpty
                  ? 'edge:$index'
                  : labText(original, 'id'),
              edge = edges[lookup];
          if (edge == null) return original;
          final row = {...original};
          if (ids[edge.startId] != null) row['from'] = ids[edge.startId];
          if (ids[edge.endId] != null) row['to'] = ids[edge.endId];
          if (doc.kind == UniversityLabKind.uml) {
            if (row.containsKey('fromMultiplicity') ||
                (edge.data['startMultiplicity'] as String? ?? '').isNotEmpty) {
              row['fromMultiplicity'] = edge.data['startMultiplicity'] ?? '';
            }
            if (row.containsKey('toMultiplicity') ||
                (edge.data['endMultiplicity'] as String? ?? '').isNotEmpty) {
              row['toMultiplicity'] = edge.data['endMultiplicity'] ?? '';
            }
            if (edge.data['umlRelationship'] is String) {
              row['kind'] = edge.data['umlRelationship'];
            }
          }
          return row;
        })(),
    ];
  }
  return model;
}

Map<String, dynamic> umlModelFromCanvas(CanvasScene scene) {
  final classes = scene.elements.where(isUmlClass).toList();
  final nodes = [
    for (final e in classes)
      {
        'id': e.id,
        'name': e.text,
        'kind': 'class',
        'attributes': UmlClass(e).attributes.join('\n'),
        'operations': UmlClass(e).operations.join('\n'),
      },
  ];
  final known = nodes.map((n) => n['id']).toSet();
  final edges = [
    for (final e in scene.elements.where(
      (e) =>
          e.type == 'connector' &&
          known.contains(e.startId) &&
          known.contains(e.endId),
    ))
      {
        'id': e.id,
        'from': e.startId,
        'to': e.endId,
        'kind': 'association',
        'fromMultiplicity': e.data['startMultiplicity'] ?? '',
        'toMultiplicity': e.data['endMultiplicity'] ?? '',
      },
  ];
  for (final e in scene.elements.where(
    (e) => umlNodeKind(e) == UmlNodeKind.lifeline,
  )) {
    final name = e.text.split(':').last.trim(),
        type = classes.where((c) => c.text == name).firstOrNull;
    nodes.add({
      'id': e.id,
      'name': e.text,
      'kind': 'object',
      'class': type?.id ?? name,
    });
  }
  final messages = [
    for (final e in scene.elements.where(
      (e) =>
          e.data['umlLink'] is Map &&
          !{
            'association',
            'generalization',
            'include',
            'extend',
            'constraint',
          }.contains((e.data['umlLink'] as Map)['kind']),
    ))
      {
        'id': e.id,
        'from': e.startId,
        'to': e.endId,
        'label': e.text,
        'messageKind': (e.data['umlLink'] as Map)['kind'],
      },
  ];
  return {
    'nodes': nodes,
    'edges': [
      ...edges,
      for (final m in messages) {...m, 'kind': 'message'},
    ],
    'messages': messages,
    'fragments': [],
    'trace': messages.map((e) => e['id']).join(' '),
    'variables': {},
  };
}
