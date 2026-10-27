import 'expression.dart';
import 'state_lab.dart';

List<String> checkUmlModel(Map<String, dynamic> model) {
  final nodes = labRows(model['nodes'], limit: 150),
      edges = labRows(model['edges']);
  final byId = <String, Map<String, dynamic>>{}, issues = <String>[];
  for (final n in nodes) {
    final id = labText(n, 'id');
    if (id.isEmpty || byId.containsKey(id)) {
      throw const FormatException('UML items need unique IDs.');
    }
    byId[id] = n;
  }
  for (final n in nodes) {
    if (n['kind'] == 'object') {
      final type = byId[n['class']];
      if (type == null || type['kind'] != 'class') {
        issues.add('${n['id']}: missing class');
        continue;
      }
      final attributes = labText(type, 'attributes')
          .split('\n')
          .map(
            (s) => s
                .trim()
                .replaceFirst(RegExp(r'^[+\-#~/]'), '')
                .split(':')
                .first
                .trim(),
          )
          .toSet();
      for (final slot in labText(
        n,
        'slots',
      ).split('\n').where((s) => s.trim().isNotEmpty)) {
        if (!attributes.contains(slot.split('=').first.trim())) {
          issues.add('${n['id']}: unknown slot ${slot.split('=').first}');
        }
      }
    }
    if (n['kind'] == 'associationClass' &&
        !edges.any((e) => e['id'] == n['association'])) {
      issues.add('${n['id']}: missing association');
    }
  }
  for (final e in edges) {
    final a = byId[e['from']], b = byId[e['to']];
    if (a == null || b == null) {
      issues.add('${e['id']}: missing endpoint');
      continue;
    }
    for (final key in ['fromMultiplicity', 'toMultiplicity']) {
      final m = labText(e, key);
      if (m.isNotEmpty && !_multiplicity(m)) {
        issues.add('${e['id']}: invalid $key ($m)');
      }
    }
    if (e['kind'] == 'composition') {
      final m = labText(e, 'fromMultiplicity');
      if (m.isNotEmpty && !{'0..1', '1'}.contains(m)) {
        issues.add(
          '${e['id']}: a composite owner end must not have multiple owners',
        );
      }
    }
    if (e['kind'] == 'message' &&
        !{'reply', 'create', 'destroy'}.contains(e['messageKind'])) {
      final type = b['kind'] == 'object' ? byId[b['class']] : b;
      final operation = labText(e, 'label').split('(').first.trim();
      final inherited = <Map<String, dynamic>>[],
          pending = <String>[if (type != null) labText(type, 'id')],
          seen = <String>{};
      while (pending.isNotEmpty) {
        final current = pending.removeLast();
        if (!seen.add(current) || byId[current] == null) continue;
        inherited.add(byId[current]!);
        pending.addAll(
          edges
              .where(
                (r) => r['kind'] == 'generalization' && r['from'] == current,
              )
              .map((r) => labText(r, 'to')),
        );
      }
      final operations = inherited
          .map((c) => labText(c, 'operations'))
          .join('\n')
          .split('\n')
          .map(
            (s) => s
                .trim()
                .replaceFirst(RegExp(r'^[+\-#~]'), '')
                .split('(')
                .first
                .trim(),
          )
          .toSet();
      if (!operations.contains(operation)) {
        issues.add(
          '${e['id']}: ${type?['id'] ?? b['id']} has no declared operation $operation',
        );
      }
    }
  }
  // Cyclic inheritance is a structural error even if all endpoints exist.
  final visiting = <String>{}, done = <String>{};
  bool cycle(String id) {
    if (visiting.contains(id)) return true;
    if (!done.add(id)) return false;
    visiting.add(id);
    final found = edges
        .where(
          (e) =>
              e['kind'] == 'generalization' &&
              e['from'] == id &&
              byId.containsKey(e['to']),
        )
        .any((e) => cycle(labText(e, 'to')));
    visiting.remove(id);
    return found;
  }

  for (final id in byId.keys) {
    if (cycle(id)) {
      issues.add('Inheritance cycle involving $id');
      break;
    }
  }
  return issues;
}

bool _multiplicity(String source) {
  if (source == '*') return true;
  final m = RegExp(r'^(\d+)(?:\.\.(\d+|\*))?$').firstMatch(source);
  if (m == null) return false;
  return m[2] == null || m[2] == '*' || int.parse(m[1]!) <= int.parse(m[2]!);
}

/// Checks declared message order/fragment membership. Does not invent ordering
/// between events on unrelated lifelines or infer an arbitrary program's trace.
List<String> checkSequenceTrace(Map<String, dynamic> model) {
  final messages = labRows(model['messages'] ?? []),
      fragments = labRows(model['fragments'] ?? []),
      issues = <String>[];
  final ids = messages.map((m) => labText(m, 'id')).toList();
  if (ids.toSet().length != ids.length || ids.contains('')) {
    throw const FormatException('Messages need unique IDs.');
  }
  final trace = labText(
    model,
    'trace',
  ).split(RegExp(r'[ ,]+')).where((s) => s.isNotEmpty).toList();
  if (trace.toSet().length != trace.length) {
    throw const FormatException(
      'Expand loop occurrences with distinct message IDs.',
    );
  }
  if (trace.any((s) => !ids.contains(s))) {
    throw const FormatException('Trace contains unknown message IDs.');
  }
  for (final p in {
    for (final m in messages) ...[labText(m, 'from'), labText(m, 'to')],
  }) {
    final order = messages
        .where((m) => m['from'] == p || m['to'] == p)
        .map((m) => m['id'] as String)
        .where(trace.contains)
        .toList();
    for (var i = 1; i < order.length; i++) {
      if (trace.indexOf(order[i]) < trace.indexOf(order[i - 1])) {
        issues.add(
          '$p: ${order[i - 1]} must precede ${order[i]} (declared order)',
        );
      }
    }
  }
  final variables = labMap(
    model['variables'] ?? {},
  ).map((k, v) => MapEntry(k, v as Object));
  for (final f in fragments) {
    final members = labText(
      f,
      'messages',
    ).split(RegExp(r'[ ,]+')).where((s) => s.isNotEmpty).toList();
    if (members.any((s) => !ids.contains(s))) {
      throw const FormatException('Fragment references unknown messages.');
    }
    final present = members.where(trace.contains).toList(),
        op = labText(f, 'operator');
    if (!{
      'opt',
      'assert',
      'neg',
      'strict',
      'par',
      'consider',
      'ignore',
      'break',
    }.contains(op)) {
      throw const FormatException(
        'Trace checker supports opt/assert/neg/strict/par/consider/ignore/break; expand alt/loop branches explicitly.',
      );
    }
    if (op == 'neg' && present.length == members.length) {
      issues.add('Forbidden fragment occurs');
    }
    if ({'opt', 'assert', 'break'}.contains(op)) {
      final enabled = labGuard(labText(f, 'guard'), variables);
      if (!enabled && present.isNotEmpty) issues.add('$op: guard is false');
      if (enabled && op == 'assert' && present.length != members.length) {
        issues.add('Required assertion messages are missing');
      }
      if (enabled &&
          op == 'break' &&
          present.isNotEmpty &&
          trace.last != present.last) {
        issues.add('Messages follow the declared break');
      }
    }
    if (op == 'strict') {
      for (var i = 1; i < present.length; i++) {
        if (trace.indexOf(present[i]) < trace.indexOf(present[i - 1])) {
          issues.add('Strict ordering violated');
        }
      }
    }
  }
  return issues;
}
