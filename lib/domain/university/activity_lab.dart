import 'expression.dart';
import 'state_lab.dart';

class ActivityStep {
  ActivityStep(this.node, this.tokens, this.values, this.actions);
  final String node;
  final Map<String, List<String>> tokens;
  final LabValues values;
  final List<String> actions;
}

/// Token game over an explicit activity, not an arbitrary-code interpreter.
class ActivityLab {
  ActivityLab(Map<String, dynamic> model, {this.depth = 0})
    : nodes = labRows(model['nodes'], limit: 100),
      edges = labRows(model['edges']) {
    if (depth > 8) {
      throw const FormatException('At most eight nested subactivities.');
    }
    for (final n in nodes) {
      final id = labText(n, 'id');
      if (id.isEmpty ||
          byId.containsKey(id) ||
          !{
            'start',
            'action',
            'decision',
            'merge',
            'fork',
            'join',
            'final',
            'flowFinal',
            'send',
            'receive',
            'call',
            'object',
          }.contains(n['kind'])) {
        throw const FormatException(
          'Activity nodes need unique IDs and supported kinds.',
        );
      }
      byId[id] = n;
    }
    for (var i = 0; i < edges.length; i++) {
      final e = edges[i];
      if (!byId.containsKey(e['from']) || !byId.containsKey(e['to'])) {
        throw const FormatException('Missing activity endpoint.');
      }
      e['_key'] = '$i';
    }
    final starts = nodes.where((n) => n['kind'] == 'start').toList();
    if (starts.length != 1) {
      throw const FormatException('Use exactly one activity start.');
    }
    values.addAll(
      labMap(model['variables'] ?? {}).map((k, v) {
        if (v is! num && v is! bool) {
          throw const FormatException('Variables must be numeric or boolean.');
        }
        if (v is num) LabExpression.finite(v);
        return MapEntry(k, v as Object);
      }),
    );
    tokens[starts.single['id'] as String] = ['start'];
  }
  final int depth;
  final List<Map<String, dynamic>> nodes, edges;
  final byId = <String, Map<String, dynamic>>{};
  final tokens = <String, List<String>>{};
  final values = <String, Object>{};
  final signals = <String>[];
  final steps = <ActivityStep>[];
  List<String> get enabled => tokens.keys.where((id) {
    final n = byId[id]!;
    if (n['kind'] == 'receive' && !signals.contains(labText(n, 'signal'))) {
      return false;
    }
    if (n['kind'] != 'join') return true;
    return edges
        .where((e) => e['to'] == id && e['exception'] != true)
        .every((e) => tokens[id]!.contains(e['_key']));
  }).toList();
  void signal(String name) {
    if (name.trim().isEmpty || signals.length >= 100) {
      throw const FormatException('Use at most 100 queued named signals.');
    }
    signals.add(name);
  }

  ActivityStep step(String id) {
    if (!enabled.contains(id) || steps.length >= 500) {
      throw const FormatException(
        'Choose an enabled action (maximum 500 steps).',
      );
    }
    final oldValues = Map<String, Object>.from(values),
        oldTokens = {
          for (final e in tokens.entries) e.key: List<String>.from(e.value),
        },
        oldSignals = List<String>.from(signals);
    final n = byId[id]!, kind = n['kind'];
    final log = <String>[];
    try {
      if (kind == 'join') {
        for (final e in edges.where(
          (e) => e['to'] == id && e['exception'] != true,
        )) {
          tokens[id]!.remove(e['_key']);
        }
      } else {
        tokens[id]!.removeAt(0);
      }
      if (tokens[id]!.isEmpty) tokens.remove(id);
      if (kind == 'final') {
        tokens.clear();
        log.add('Activity terminated');
      } else if (kind != 'flowFinal') {
        if (kind == 'receive') signals.remove(labText(n, 'signal'));
        if (kind == 'send') {
          signal(labText(n, 'signal'));
          log.add('Sent ${n['signal']}');
        }
        var outgoing = <Map<String, dynamic>>[];
        var handled = false;
        try {
          labActions(labText(n, 'actions'), values, log);
          if (kind == 'call') {
            final nested = ActivityLab(labMap(n['activity']), depth: depth + 1);
            for (var i = 0; i < 100 && nested.enabled.isNotEmpty; i++) {
              nested.step(nested.enabled.first);
            }
            if (nested.tokens.isNotEmpty) {
              throw const FormatException(
                'Subactivity is unfinished or waiting.',
              );
            }
            log.add('Subactivity completed (${nested.steps.length} steps)');
          }
        } on FormatException catch (error) {
          values
            ..clear()
            ..addAll(oldValues);
          outgoing = edges
              .where((e) => e['from'] == id && e['exception'] == true)
              .toList();
          if (outgoing.length != 1) rethrow;
          handled = true;
          log.add('Handled exception: ${error.message}');
        }
        if (!handled) {
          outgoing = edges
              .where(
                (e) =>
                    e['from'] == id &&
                    e['exception'] != true &&
                    labGuard(labText(e, 'guard'), values),
              )
              .toList();
        }
        if (kind == 'decision' && outgoing.length != 1) {
          throw const FormatException(
            'A decision needs exactly one true outgoing guard.',
          );
        }
        if (kind != 'fork' && kind != 'decision' && outgoing.length > 1) {
          throw const FormatException(
            'Use an explicit fork for parallel control flows.',
          );
        }
        final interrupt = labText(n, 'interruptRegion');
        if (interrupt.isNotEmpty) {
          tokens.removeWhere(
            (key, _) => labText(byId[key]!, 'region') == interrupt,
          );
        }
        for (final e in outgoing) {
          tokens
              .putIfAbsent(e['to'] as String, () => [])
              .add(e['_key'] as String);
        }
      }
      final result = ActivityStep(
        id,
        {for (final e in tokens.entries) e.key: List.unmodifiable(e.value)},
        Map.unmodifiable(values),
        List.unmodifiable(log),
      );
      steps.add(result);
      return result;
    } catch (_) {
      values
        ..clear()
        ..addAll(oldValues);
      tokens
        ..clear()
        ..addAll(oldTokens);
      signals
        ..clear()
        ..addAll(oldSignals);
      rethrow;
    }
  }
}
