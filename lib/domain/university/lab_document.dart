import 'dart:convert';
import '../writing_structure.dart';
import 'activity_lab.dart';
import 'distributed_lab.dart';
import 'protocol_lab.dart';
import 'state_lab.dart';
import 'testing_lab.dart';
import 'uml_lab.dart';

enum UniversityLabKind {
  state('State diagrams'),
  activity('Activity diagrams'),
  uml('Connected UML'),
  testing('Tests & coverage'),
  distributed('Distributed systems'),
  protocol('SMQP & Java lab'),
  contracts('Dafny contracts');

  const UniversityLabKind(this.label);
  final String label;
}

class UniversityDocument {
  UniversityDocument(Map<String, dynamic> data)
    : data = Map<String, dynamic>.from(jsonDecode(jsonEncode(data)) as Map) {
    if (data['version'] != 1 ||
        data['kind'] is! String ||
        !UniversityLabKind.values.any((k) => k.name == data['kind']) ||
        data['model'] is! Map) {
      throw const FormatException(
        'Unsupported university model. Original content remains unchanged.',
      );
    }
    if (jsonEncode(data).length > 500000) {
      throw const FormatException('University model exceeds 500 KB.');
    }
  }
  final Map<String, dynamic> data;
  UniversityLabKind get kind =>
      UniversityLabKind.values.firstWhere((k) => k.name == data['kind']);
  String get title => labText(data, 'title');
  Map<String, dynamic> get model => labMap(data['model']);
  UniversityDocument updated(Map<String, dynamic> patch) =>
      UniversityDocument({...data, ...patch});
  static bool metadataLine(String line) {
    if (line.trim() == '<!-- /orbit:university -->') return true;
    final match = RegExp(
      r'^<!-- orbit:university (.*) -->$',
    ).firstMatch(line.trim());
    if (match == null) return false;
    try {
      UniversityDocument(labMap(jsonDecode(match[1]!)));
      return true;
    } catch (_) {
      return false;
    }
  }

  static List<({int start, int end, String payload})> records(String source) {
    final protected = writingLiteralRanges(source),
        result = <({int start, int end, String payload})>[];
    RegExpMatch? opening;
    for (final m in RegExp(
      r'^<!-- orbit:university ([^\r\n]*) -->\r?$|^<!-- /orbit:university -->\r?$',
      multiLine: true,
    ).allMatches(source)) {
      if (protected.any((r) => m.start > r.$1 && m.start < r.$2)) continue;
      if (m[1] != null) {
        if (opening != null) {
          throw const FormatException(
            'Nested university model markers; repair in Source.',
          );
        }
        opening = m;
      } else if (opening != null) {
        result.add((start: opening.start, end: m.end, payload: opening[1]!));
        opening = null;
      }
    }
    if (opening != null) {
      throw const FormatException(
        'Unfinished university model; preserve and repair it in Source.',
      );
    }
    return result;
  }

  static UniversityDocument? fromMarkdown(String source) {
    final found = records(source);
    if (found.isEmpty) return null;
    if (found.length > 1) {
      throw const FormatException('Use one university model per note.');
    }
    return UniversityDocument(labMap(jsonDecode(found.single.payload)));
  }

  static String maskMetadata(String source) {
    final protected = writingLiteralRanges(source);
    return source.replaceAllMapped(RegExp(r'[^\n]*\n|[^\n]+$'), (m) {
      if (protected.any((r) => m.start > r.$1 && m.start < r.$2) ||
          !metadataLine(m[0]!.trimRight())) {
        return m[0]!;
      }
      return m[0]!.replaceAll(RegExp(r'[^\r\n]'), ' ');
    });
  }

  String get markdown {
    final encoded = jsonEncode(
      data,
    ).replaceAll('<', r'\u003c').replaceAll('>', r'\u003e');
    return '<!-- orbit:university $encoded -->\n## ${title.replaceAll(RegExp(r'[\r\n]'), ' ')}\n\n${report()}\n<!-- /orbit:university -->';
  }

  String applyTo(String source) {
    final matches = records(source);
    if (matches.length > 1) {
      throw const FormatException(
        'Open a note with one university model; keep additional models in separate notes.',
      );
    }
    if (matches.isEmpty) validateWritingAppend(source);
    return matches.isEmpty
        ? '$source${source.endsWith('\n\n') ? '' : '\n\n'}$markdown\n'
        : source.replaceRange(
            matches.single.start,
            matches.single.end,
            markdown,
          );
  }

  String report({int? through}) {
    final m = model, out = StringBuffer();
    final course = labText(data, 'course'), source = labText(data, 'source');
    if (course.isNotEmpty) out.writeln('Course: ${cell(course)}\n');
    if (source.isNotEmpty) out.writeln('Source / task: ${cell(source)}\n');
    out.writeln(
      '*Offline teaching model · ${kind.label}. Results apply to the explicitly entered model.*\n',
    );
    void table(List<String> headers, Iterable<List<Object?>> rows) {
      out.writeln(
        '| ${headers.join(' | ')} |\n| ${headers.map((_) => '---').join(' | ')} |',
      );
      for (final row in rows) {
        if (out.length > 1000000) {
          throw const FormatException(
            'Report exceeds 1 MB; split the model into exercises.',
          );
        }
        out.writeln('| ${row.map((v) => cell('$v')).join(' | ')} |');
      }
      out.writeln();
    }

    switch (kind) {
      case UniversityLabKind.state:
        final lab = StateLab(m),
            events = labText(
              m,
              'events',
            ).split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).toList();
        for (final e in events.take(through ?? events.length)) {
          lab.send(e);
        }
        final names = {
          for (final s in lab.states)
            s['id']: labText(s, 'name').isEmpty ? s['id'] : s['name'],
        };
        table(
          ['Event', 'Active states', 'Variables', 'Actions'],
          lab.steps.map(
            (s) => [
              s.event,
              s.states.map((id) => names[id]).join(', '),
              s.values.entries.map((e) => '${e.key}=${e.value}').join(', '),
              s.actions.join('; '),
            ],
          ),
        );
      case UniversityLabKind.activity:
        final lab = ActivityLab(m),
            schedule = labText(
              m,
              'schedule',
            ).split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).toList();
        for (final entry in schedule.take(through ?? schedule.length)) {
          if (entry.startsWith('signal:')) {
            lab.signal(entry.substring(7));
          } else {
            lab.step(entry);
          }
        }
        table(
          ['Action', 'Tokens after action', 'Variables', 'Effects'],
          lab.steps.map(
            (s) => [
              s.node,
              s.tokens.keys.join(', '),
              s.values,
              s.actions.join('; '),
            ],
          ),
        );
        out.writeln(
          'Enabled: ${lab.enabled.join(', ')}\n\n${lab.tokens.isEmpty ? 'Completed.' : 'Unfinished / waiting tokens: ${lab.tokens.keys.join(', ')}'}',
        );
      case UniversityLabKind.uml:
        final issues = [
          ...checkUmlModel(m),
          if (m['messages'] is List && (m['messages'] as List).isNotEmpty)
            ...checkSequenceTrace(m),
        ];
        out.writeln(
          issues.isEmpty
              ? 'No structural issues found in the declared subset. This is not a proof of domain correctness.'
              : issues.map((s) => '- $s').join('\n'),
        );
        table(
          ['Item', 'Kind', 'Definition'],
          labRows(m['nodes']).map(
            (n) => [
              n['id'],
              n['kind'],
              [
                n['name'],
                n['attributes'],
                n['operations'],
                n['slots'],
              ].whereType<String>().join('; '),
            ],
          ),
        );
      case UniversityLabKind.testing:
        final coverage = labCoverage(m);
        table(
          ['Criterion', 'Covered', 'Missing'],
          [
            [
              'Basic blocks',
              coverage.visited.length,
              coverage.missingNodes.join(', '),
            ],
            [
              'Edges / branches',
              coverage.branches.length,
              coverage.missingEdges.join(', '),
            ],
            [
              'DU pairs',
              coverage.duPairs.length,
              coverage.missingDu.join(', '),
            ],
          ],
        );
        out.writeln(
          'Coverage is calculated from entered execution paths, not measured from running arbitrary source code.\n',
        );
        table(
          ['Atomic condition', 'Observed outcomes', 'Missing'],
          conditionCoverage(m).entries.map(
            (e) => [
              e.key,
              e.value.join(', '),
              {true, false}.difference(e.value).join(', '),
            ],
          ),
        );
        table(
          ['Input', 'Boundary value', 'Partition'],
          boundaryCases(
            labRows(m['partitions'] ?? []),
          ).map((r) => [r['input'], r['value'], r['partition']]),
        );
        table(
          ['Case', 'Input', 'Expected', 'Actual', 'Result'],
          labRows(m['tests']).map(
            (t) => [
              t['name'] ?? '',
              t['input'] ?? '',
              t['expected'] ?? '',
              t['actual'] ?? '',
              t['observed'] != false && t.containsKey('actual')
                  ? (t['actual'] == t['expected'] ? 'matched' : 'mismatch')
                  : 'not run',
            ],
          ),
        );
        if (labText(m, 'junit').trim().isNotEmpty) {
          table(
            ['Class', 'Test', 'Status', 'Time'],
            junitCases(
              labText(m, 'junit'),
            ).map((r) => [r['class'], r['name'], r['status'], r['time']]),
          );
        }
      case UniversityLabKind.distributed:
        final trace = distributedTrace(m);
        table(
          ['Event', 'Process', 'Lamport', 'Vector', 'Observation'],
          trace
              .take(through ?? trace.length)
              .map((s) => [s.event, s.process, s.lamport, s.vector, s.detail]),
        );
        if (trace.length > 1) {
          out.writeln(
            'First ↔ last vector relation: ${vectorRelation(trace.first.vector, trace.last.vector)}. A smaller Lamport timestamp alone does not prove causality.\n',
          );
        }
        final alive = labText(
          m,
          'reachable',
        ).split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).toList();
        if (alive.isNotEmpty) {
          out.writeln(
            '${electLeader(alive)}\n\n${electLeader(alive, ring: true)}\n\nElection assumes the entered reachable membership; partitions are not a global consensus guarantee.',
          );
          out.writeln(
            '\nSingle-initiator ring trace:\n${electionMessages(alive, ring: true).map((s) => '- $s').join('\n')}\n',
          );
          out.writeln(
            '\nBully trace (reachable, responsive membership):\n${electionMessages(alive).map((s) => '- $s').join('\n')}\n',
          );
        }
        final consistency = checkReplicaObservations(m);
        out.writeln(
          '\nVersion-observation checks: ${consistency.isEmpty ? 'No violations observed in entered per-client versions.' : consistency.join('; ')}\nAssumes one comparable version order per key; not a linearizability/causal/eventual-consistency proof.',
        );
      case UniversityLabKind.protocol:
        final s = checkProtocolTranscript(labText(m, 'transcript'));
        out.writeln(
          'Protocol phase: ${s.phase}; awaiting response: ${s.pending ?? 'none'}.\n',
        );
        out.writeln('```text\n${s.log.join('\n')}\n```\n');
        out.writeln(
          'Java lab checklist:\n- [ ] Java 21 toolchain selected\n- [ ] Run the selected JUnit test locally\n- [ ] Review protected files before saving/pushing\n- [ ] Explain socket lifecycle, background subscriber and error paths\n\nBuild system: ${labText(m, 'buildSystem')} · protected paths: ${labText(m, 'protectedPaths')}',
        );
      case UniversityLabKind.contracts:
        final code = labText(m, 'code');
        if (code.length > 100000 || code.contains('```')) {
          throw const FormatException(
            'Use Dafny source up to 100,000 characters without Markdown fences.',
          );
        }
        out.writeln('```dafny\n$code\n```\n');
        table(
          ['Contract', 'Explanation'],
          [
            ['requires', 'Caller obligations'],
            ['ensures', 'Result/state guarantees'],
            ['modifies', 'Permitted heap changes'],
            ['invariant', 'Loop property'],
            ['decreases', 'Termination measure'],
          ],
        );
        out.writeln(
          'Verification: ${cell(labText(m, 'verification').isEmpty ? 'Not run. Use the explicit local Dafny verifier action.' : labText(m, 'verification'))}',
        );
    }
    return out.toString();
  }

  static String cell(String source) =>
      source.replaceAll('|', r'\|').replaceAll(RegExp(r'\r\n|\r|\n'), '<br>');
}
