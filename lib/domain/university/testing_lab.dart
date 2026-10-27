import 'state_lab.dart';

class CoverageReport {
  CoverageReport(
    this.visited,
    this.branches,
    this.duPairs,
    this.missingNodes,
    this.missingEdges,
    this.missingDu,
  );
  final Set<String> visited,
      branches,
      duPairs,
      missingNodes,
      missingEdges,
      missingDu;
}

CoverageReport labCoverage(Map<String, dynamic> model) {
  final nodes = labRows(model['nodes'], limit: 100),
      edges = labRows(model['edges']),
      tests = labRows(model['tests']);
  final byId = {for (final n in nodes) labText(n, 'id'): n};
  if (byId.length != nodes.length || byId.containsKey('')) {
    throw const FormatException('Use unique CFG node IDs.');
  }
  final allEdges = <String>{};
  for (final e in edges) {
    if (!byId.containsKey(e['from']) || !byId.containsKey(e['to'])) {
      throw const FormatException('Missing CFG endpoint.');
    }
    if (!allEdges.add('${e['from']} → ${e['to']}')) {
      throw const FormatException('Duplicate CFG edge.');
    }
  }
  List<String> names(Map n, String key) => labText(
    n,
    key,
  ).split(RegExp(r'[ ,]+')).where((s) => s.isNotEmpty).toList();
  final allDu = <String>{};
  // Reaching-definitions fixed point. Definitions killed by the same variable.
  final incoming = {for (final id in byId.keys) id: <String>{}},
      outgoing = {for (final id in byId.keys) id: <String>{}};
  for (var pass = 0; pass < nodes.length * nodes.length + 1; pass++) {
    var changed = false;
    for (final n in nodes) {
      final id = n['id'] as String;
      final reach = {
        for (final e in edges.where((e) => e['to'] == id))
          ...outgoing[e['from']]!,
      };
      incoming[id] = reach;
      final defs = names(n, 'defs').toSet();
      final next = {
        ...reach.where((d) => !defs.contains(d.split('@').first)),
        for (final v in defs) '$v@$id',
      };
      if (next.length != outgoing[id]!.length ||
          !next.containsAll(outgoing[id]!)) {
        changed = true;
        outgoing[id] = next;
      }
    }
    if (!changed) break;
    if (pass == nodes.length * nodes.length) {
      throw const FormatException('Data-flow analysis did not converge.');
    }
  }
  for (final n in nodes) {
    final id = n['id'] as String;
    for (final v in names(n, 'uses')) {
      for (final d in incoming[id]!.where((d) => d.startsWith('$v@'))) {
        allDu.add('$v: ${d.split('@').last} → $id');
      }
    }
  }
  final visited = <String>{}, branches = <String>{}, du = <String>{};
  for (final test in tests) {
    final path = labText(
      test,
      'path',
    ).split(RegExp(r'[ ,]+')).where((s) => s.isNotEmpty).toList();
    if (path.length > 2000) {
      throw const FormatException('Test path exceeds 2000 nodes.');
    }
    final definitions = <String, String>{};
    for (var i = 0; i < path.length; i++) {
      final id = path[i], n = byId[id];
      if (n == null) throw FormatException('Unknown node in test path: $id');
      if (i > 0) {
        final edge = '${path[i - 1]} → $id';
        if (!allEdges.contains(edge)) {
          throw FormatException('Impossible test path: $edge');
        }
        branches.add(edge);
      }
      visited.add(id);
      for (final v in names(n, 'uses')) {
        if (definitions.containsKey(v)) du.add('$v: ${definitions[v]} → $id');
      }
      for (final v in names(n, 'defs')) {
        definitions[v] = id;
      }
    }
  }
  return CoverageReport(
    visited,
    branches,
    du,
    byId.keys.toSet().difference(visited),
    allEdges.difference(branches),
    allDu.difference(du),
  );
}

List<Map<String, Object>> boundaryCases(List<Map<String, dynamic>> partitions) {
  if (partitions.length > 50) {
    throw const FormatException('At most 50 input partitions.');
  }
  final rows = <Map<String, Object>>[];
  for (final p in partitions) {
    final min = p['min'], max = p['max'], step = p['step'] ?? 1;
    if (min is! num ||
        max is! num ||
        step is! num ||
        !min.isFinite ||
        !max.isFinite ||
        !step.isFinite ||
        step <= 0 ||
        min > max) {
      throw const FormatException('Use finite min ≤ max and a positive step.');
    }
    for (final x in {
      min - step,
      min,
      min + step,
      max - step,
      max,
      max + step,
    }) {
      rows.add({
        'input': labText(p, 'name'),
        'value': x,
        'partition': x < min || x > max ? 'outside' : 'inside',
      });
    }
  }
  return rows;
}

/// Small, bounded JUnit XML import. No DTD/entity processing or code execution.
List<Map<String, String>> junitCases(String xml) {
  if (xml.length > 2000000 ||
      RegExp(r'<!DOCTYPE|<!ENTITY', caseSensitive: false).hasMatch(xml)) {
    throw const FormatException(
      'Use JUnit XML without DTD/entities (max 2 MB).',
    );
  }
  String decode(String text) => text
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
  final rows = <Map<String, String>>[];
  for (final m in RegExp(
    r'<testcase\b([^>]*?)(?:/>|>([\s\S]*?)</testcase>)',
  ).allMatches(xml)) {
    if (rows.length >= 5000) {
      throw const FormatException('At most 5000 test cases.');
    }
    final attrs = {
      for (final a in RegExp(
        '([A-Za-z]+)=["\x27]([^"\x27]*)["\x27]',
      ).allMatches(m[1]!))
        a[1]!: decode(a[2]!),
    };
    final body = m[2] ?? '';
    rows.add({
      'name': attrs['name'] ?? 'Unnamed',
      'class': attrs['classname'] ?? '',
      'status': RegExp(r'<(?:failure|error)\b').hasMatch(body)
          ? 'failed'
          : body.contains('<skipped')
          ? 'skipped'
          : 'passed',
      'time': attrs['time'] ?? '',
      'details': decode(body.replaceAll(RegExp(r'<[^>]*>'), '')),
    });
  }
  if (rows.isEmpty) {
    throw const FormatException('No supported JUnit testcase records found.');
  }
  return rows;
}

Map<String, Set<bool>> conditionCoverage(Map<String, dynamic> model) {
  final result = <String, Set<bool>>{};
  for (final node in labRows(model['nodes'], limit: 100)) {
    for (final name in labText(
      node,
      'conditions',
    ).split(RegExp(r'[ ,]+')).where((s) => s.isNotEmpty)) {
      result[name] = <bool>{};
    }
  }
  for (final test in labRows(model['tests'])) {
    final observations = labMap(test['conditions'] ?? {});
    for (final e in observations.entries) {
      if (!result.containsKey(e.key) || e.value is! bool) {
        throw const FormatException(
          'Condition evidence needs a declared name and boolean outcome.',
        );
      }
      result[e.key]!.add(e.value as bool);
    }
  }
  return result;
}
