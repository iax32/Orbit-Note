import 'expression.dart';

Map<String, dynamic> labMap(Object? value) => value is Map
    ? Map<String, dynamic>.from(value)
    : throw const FormatException('Expected an object.');
List<Map<String, dynamic>> labRows(Object? value, {int limit = 300}) {
  if (value is! List || value.length > limit) {
    throw const FormatException('Missing or oversized list.');
  }
  return value.map(labMap).toList();
}

String labText(Map data, String key) =>
    data[key] is String ? data[key] as String : '';

class StateStep {
  StateStep(
    this.event,
    Iterable<String> states,
    LabValues values,
    Iterable<String> actions,
  ) : states = List.unmodifiable(states),
      values = Map.unmodifiable(values),
      actions = List.unmodifiable(actions);
  final String event;
  final List<String> states, actions;
  final LabValues values;
}

/// Explicit hierarchy/region semantics, bounded run-to-completion and no guessing
/// between two enabled transitions at the same priority.
class StateLab {
  StateLab(Map<String, dynamic> model)
    : states = labRows(model['states'], limit: 100),
      transitions = labRows(model['transitions']) {
    for (final state in states) {
      final id = labText(state, 'id');
      if (id.isEmpty || byId.containsKey(id)) {
        throw const FormatException('States need unique IDs.');
      }
      byId[id] = state;
    }
    if (states.isEmpty) throw const FormatException('Add states first.');
    for (final s in states) {
      final p = labText(s, 'parent');
      if (p.isNotEmpty && !byId.containsKey(p)) {
        throw FormatException('Missing parent: $p');
      }
      path(labText(s, 'id'));
    }
    for (final t in transitions) {
      if (!byId.containsKey(t['from']) || !byId.containsKey(t['to'])) {
        throw const FormatException('Transition endpoints must be states.');
      }
      if (t['internal'] == true && t['from'] != t['to']) {
        throw const FormatException(
          'Internal transitions must keep their state.',
        );
      }
    }
    values.addAll(
      labMap(model['variables'] ?? {}).map((k, v) {
        if (!RegExp(r'^[A-Za-z_]\w*$').hasMatch(k) || v is! num && v is! bool) {
          throw const FormatException(
            'Variables must be named numbers or booleans.',
          );
        }
        if (v is num) LabExpression.finite(v);
        return MapEntry(k, v as Object);
      }),
    );
    final log = <String>[];
    _enterChildren('', log);
    _completion(log);
    steps.add(StateStep('Start', active, values, log));
  }
  final List<Map<String, dynamic>> states, transitions;
  final byId = <String, Map<String, dynamic>>{};
  final active = <String>{};
  final values = <String, Object>{};
  final history = <String, List<String>>{};
  final steps = <StateStep>[];
  List<String> path(String id) {
    final result = <String>[];
    while (id.isNotEmpty) {
      if (result.contains(id) || result.length > 30) {
        throw const FormatException('Cyclic or too-deep state hierarchy.');
      }
      result.insert(0, id);
      id = labText(byId[id]!, 'parent');
    }
    return result;
  }

  bool _inside(String leaf, String ancestor) => path(leaf).contains(ancestor);
  void _enter(String id, List<String> log) {
    labActions(labText(byId[id]!, 'entry'), values, log);
    _enterChildren(id, log);
  }

  void _enterChildren(String parent, List<String> log) {
    final children = states
        .where((s) => labText(s, 'parent') == parent)
        .toList();
    if (children.isEmpty) {
      if (parent.isNotEmpty) active.add(parent);
      return;
    }
    final regions = {for (final s in children) labText(s, 'region')};
    for (final region in regions) {
      final candidates = children
          .where((s) => labText(s, 'region') == region && s['initial'] == true)
          .toList();
      if (candidates.length != 1) {
        throw FormatException(
          'Exactly one initial state is required in $parent/$region.',
        );
      }
      _enter(candidates.single['id'] as String, log);
    }
  }

  void _fire(Map<String, dynamic> t, List<String> log) {
    final from = t['from'] as String, to = t['to'] as String;
    if (t['internal'] == true) {
      labActions(labText(t, 'actions'), values, log);
      return;
    }
    final a = path(from), b = path(to);
    var common = 0;
    while (common < a.length && common < b.length && a[common] == b[common]) {
      common++;
    }
    if (common == a.length || common == b.length) {
      common--; // external self/parent transition re-enters
    }
    final exitRoot = a[common];
    final leaving = active.where((s) => _inside(s, exitRoot)).toList();
    for (final ancestor in states.map((s) => s['id'] as String)) {
      final old = active.where((s) => _inside(s, ancestor)).toList();
      if (old.isNotEmpty) history[ancestor] = old;
    }
    final exiting = {
      for (final leaf in leaving) ...path(leaf).skip(common),
    }.toList()..sort((x, y) => path(y).length.compareTo(path(x).length));
    for (final id in exiting) {
      labActions(labText(byId[id]!, 'exit'), values, log);
    }
    active.removeAll(leaving);
    labActions(labText(t, 'actions'), values, log);
    final remembered = t['history'] == true ? history[to] : null;
    if (remembered != null && remembered.isNotEmpty) {
      final entered = {
        for (final leaf in remembered) ...path(leaf).skip(common),
      }.toList()..sort((x, y) => path(x).length.compareTo(path(y).length));
      for (final id in entered) {
        labActions(labText(byId[id]!, 'entry'), values, log);
      }
      active.addAll(remembered);
    } else {
      // Enter the explicit path, initializing other orthogonal regions too.
      for (var i = common; i < b.length; i++) {
        final id = b[i];
        labActions(labText(byId[id]!, 'entry'), values, log);
        if (i == b.length - 1) {
          _enterChildren(id, log);
          break;
        }
        final next = byId[b[i + 1]]!;
        final siblings = states.where(
          (s) =>
              labText(s, 'parent') == id &&
              labText(s, 'region') != labText(next, 'region'),
        );
        for (final s in siblings.where((s) => s['initial'] == true)) {
          _enter(s['id'] as String, log);
        }
      }
    }
  }

  List<Map<String, dynamic>> _enabled(String event) {
    final leavesByAncestor = <String, Set<String>>{};
    for (final leaf in active) {
      for (final ancestor in path(leaf)) {
        leavesByAncestor.putIfAbsent(ancestor, () => {}).add(leaf);
      }
    }
    final enabled = transitions
        .where(
          (t) =>
              labText(t, 'event') == event &&
              (event.isNotEmpty ||
                  !states.any((s) => s['parent'] == t['from']) ||
                  active
                      .where((s) => _inside(s, t['from'] as String))
                      .every((s) => byId[s]!['final'] == true)) &&
              leavesByAncestor.containsKey(t['from']) &&
              labGuard(labText(t, 'guard'), values),
        )
        .toList();
    enabled.sort((a, b) {
      final depth = path(
        b['from'] as String,
      ).length.compareTo(path(a['from'] as String).length);
      return depth != 0
          ? depth
          : transitions.indexOf(a).compareTo(transitions.indexOf(b));
    });
    final chosen = <Map<String, dynamic>>[];
    final covered = <String, int>{};
    for (final t in enabled) {
      final leaves = leavesByAncestor[t['from']]!,
          depth = path(t['from'] as String).length;
      if (leaves.any((leaf) => covered[leaf] == depth)) {
        throw const FormatException(
          'Ambiguous enabled transitions; refine guards.',
        );
      }
      if (!leaves.any(covered.containsKey)) {
        chosen.add(t);
        for (final leaf in leaves) {
          covered[leaf] = depth;
        }
      }
    }
    return chosen;
  }

  void _completion(List<String> log) {
    for (var i = 0; i < 100; i++) {
      final ts = _enabled('');
      if (ts.isEmpty) return;
      for (final t in ts) {
        _fire(t, log);
      }
    }
    throw const FormatException('Completion cycle exceeded 100 transitions.');
  }

  StateStep send(String event) {
    if (event.isEmpty || steps.length >= 500) {
      throw const FormatException('Use named events, at most 499.');
    }
    final before = Map<String, Object>.from(values),
        old = Set<String>.from(active),
        saved = {
          for (final e in history.entries) e.key: List<String>.from(e.value),
        };
    final log = <String>[];
    try {
      final ts = _enabled(event);
      if (ts.isEmpty) log.add('No enabled transition');
      for (final t in ts) {
        _fire(t, log);
      }
      _completion(log);
      final result = StateStep(event, active, values, log);
      steps.add(result);
      return result;
    } catch (_) {
      values
        ..clear()
        ..addAll(before);
      active
        ..clear()
        ..addAll(old);
      history
        ..clear()
        ..addAll(saved);
      rethrow;
    }
  }
}
