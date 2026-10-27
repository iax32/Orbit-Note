import 'state_lab.dart';

class DistributedStep {
  DistributedStep(
    this.event,
    this.process,
    this.lamport,
    this.vector,
    this.detail,
  );
  final String event, process, detail;
  final int lamport;
  final List<int> vector;
}

List<DistributedStep> distributedTrace(Map<String, dynamic> model) {
  final names =
      (model['processes'] as List?)?.whereType<String>().toList() ?? [];
  if (names.isEmpty ||
      names.length > 30 ||
      names.toSet().length != names.length ||
      names.any((s) => s.isEmpty)) {
    throw const FormatException('Use 1–30 unique process names.');
  }
  final clocks = {for (final p in names) p: 0},
      vectors = {for (final p in names) p: List<int>.filled(names.length, 0)};
  final messages = <String, (String, String, int, List<int>)>{},
      sent = <String>{},
      crashed = <String>{};
  final result = <DistributedStep>[];
  for (final e in labRows(model['events'], limit: 500)) {
    final p = labText(e, 'process'),
        kind = labText(e, 'kind'),
        message = labText(e, 'message');
    if (!clocks.containsKey(p)) throw FormatException('Unknown process: $p');
    if (kind == 'restart') crashed.remove(p);
    if (crashed.contains(p)) {
      throw FormatException('$p is crashed; restart it first.');
    }
    var detail = kind;
    if (kind == 'receive') {
      final m = messages.remove(message);
      if (m == null || m.$2 != p) {
        throw const FormatException(
          'Receive requires an undelivered message addressed to this process.',
        );
      }
      clocks[p] = clocks[p]! > m.$3 ? clocks[p]! : m.$3;
      for (var i = 0; i < names.length; i++) {
        if (vectors[p]![i] < m.$4[i]) vectors[p]![i] = m.$4[i];
      }
      detail = 'receive $message from ${m.$1}';
    } else if (!{
      'local',
      'send',
      'crash',
      'restart',
      'drop',
      'write',
      'read',
      'replicate',
    }.contains(kind)) {
      throw const FormatException('Unsupported distributed event.');
    }
    clocks[p] = clocks[p]! + 1;
    vectors[p]![names.indexOf(p)]++;
    if (kind == 'send') {
      final to = labText(e, 'to');
      if (!clocks.containsKey(to) || message.isEmpty || !sent.add(message)) {
        throw const FormatException(
          'Send needs a unique message ID and valid recipient.',
        );
      }
      messages[message] = (p, to, clocks[p]!, List.of(vectors[p]!));
      detail = 'send $message to $to';
    }
    if (kind == 'drop' && messages.remove(message) == null) {
      throw const FormatException('Only an in-flight message can be dropped.');
    }
    if (kind == 'crash') crashed.add(p);
    // Replication is represented as actual send/receive events, not fabricated
    // consistency verdicts from incomplete read/write histories.
    if ({'write', 'read', 'replicate'}.contains(kind)) {
      detail = '$kind ${labText(e, 'detail')} (observation)';
    }
    result.add(
      DistributedStep(
        '${result.length + 1}',
        p,
        clocks[p]!,
        List.unmodifiable(vectors[p]!),
        detail,
      ),
    );
  }
  return result;
}

String vectorRelation(List<int> a, List<int> b) {
  if (a.length != b.length || a.isEmpty) {
    throw const FormatException('Compare equal nonempty vector dimensions.');
  }
  var less = false, greater = false;
  for (var i = 0; i < a.length; i++) {
    less |= a[i] < b[i];
    greater |= a[i] > b[i];
  }
  return less && greater
      ? 'concurrent'
      : less
      ? 'before'
      : greater
      ? 'after'
      : 'equal';
}

/// Election over an explicitly selected reachable membership, not an assertion
/// of consensus under arbitrary partitions.
String electLeader(List<String> alive, {bool ring = false}) {
  if (alive.isEmpty ||
      alive.toSet().length != alive.length ||
      alive.length > 100) {
    throw const FormatException('Choose nonempty unique reachable members.');
  }
  final ordered = List<String>.from(alive)
    ..sort((a, b) {
      final x = int.tryParse(a), y = int.tryParse(b);
      return x != null && y != null ? x.compareTo(y) : a.compareTo(b);
    });
  return '${ring ? 'Ring' : 'Bully'} reachable-set winner: ${ordered.last}';
}

List<String> electionMessages(List<String> alive, {bool ring = false}) {
  final verdict = electLeader(alive, ring: ring);
  int compare(String a, String b) {
    final x = int.tryParse(a), y = int.tryParse(b);
    return x != null && y != null ? x.compareTo(y) : a.compareTo(b);
  }

  final winner = (List<String>.from(alive)..sort(compare)).last,
      log = <String>[];
  if (ring) {
    var candidate = alive.first;
    for (var i = 0; i < alive.length; i++) {
      final from = alive[i], to = alive[(i + 1) % alive.length];
      if (compare(from, candidate) > 0) candidate = from;
      log.add('$from → $to: candidate $candidate');
    }
    for (var i = 0; i < alive.length; i++) {
      log.add(
        '${alive[i]} → ${alive[(i + 1) % alive.length]}: coordinator $winner',
      );
    }
  } else {
    final ordered = List<String>.from(alive)..sort(compare);
    for (var i = 0; i < ordered.length - 1; i++) {
      for (final higher in ordered.skip(i + 1)) {
        log.add('${ordered[i]} → $higher: ELECTION');
        log.add('$higher → ${ordered[i]}: OK');
      }
    }
    for (final peer in alive.where((p) => p != winner)) {
      log.add('$winner → $peer: COORDINATOR');
    }
  }
  return [...log, verdict];
}

List<String> checkReplicaObservations(Map<String, dynamic> model) {
  final lastRead = <String, int>{},
      lastWrite = <String, int>{},
      issues = <String>[];
  for (final e in labRows(model['events'], limit: 500)) {
    if (!{'read', 'write'}.contains(e['kind'])) continue;
    final version = e['version'],
        key = labText(e, 'key'),
        client = labText(e, 'process');
    if (version is! int || version < 0 || key.isEmpty) {
      throw const FormatException(
        'Read/write observations need a key and nonnegative integer version.',
      );
    }
    final id = '$client/$key',
        read = lastRead[id] ?? -1,
        write = lastWrite[id] ?? -1;
    if (e['kind'] == 'read') {
      if (version < read) {
        issues.add('$id: monotonic-read violation ($version < $read)');
      }
      if (version < write) {
        issues.add('$id: read-your-writes violation ($version < $write)');
      }
      lastRead[id] = version > read ? version : read;
    } else {
      if (version <= write) {
        issues.add('$id: monotonic-write version did not advance');
      }
      if (version < read) {
        issues.add('$id: write follows an older version than the last read');
      }
      lastWrite[id] = version > write ? version : write;
    }
  }
  return issues;
}
