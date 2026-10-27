import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/university/expression.dart';
import 'package:orbit_note/domain/university/state_lab.dart';
import 'package:orbit_note/domain/university/activity_lab.dart';
import 'package:orbit_note/domain/university/lab_document.dart';
import 'package:orbit_note/domain/university/lab_presets.dart';
import 'package:orbit_note/domain/university/testing_lab.dart';
import 'package:orbit_note/domain/university/distributed_lab.dart';
import 'package:orbit_note/domain/university/protocol_lab.dart';
import 'package:orbit_note/domain/university/uml_lab.dart';
import 'package:orbit_note/domain/university/assignment_protection.dart';
import 'package:orbit_note/canvas/university_diagram.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/domain/code_language.dart';

void main() {
  test('parallel-region stress stays bounded and deterministic', () {
    final model = <String, dynamic>{
      'variables': {'n': 0},
      'states': [
        {'id': 'root', 'initial': true},
        for (var i = 0; i < 90; i++)
          {'id': 's$i', 'parent': 'root', 'region': 'r$i', 'initial': true},
      ],
      'transitions': [
        for (var i = 0; i < 90; i++)
          {
            'from': 's$i',
            'to': 's$i',
            'event': 'tick',
            'internal': true,
            'actions': 'n++',
          },
      ],
    };
    final clock = Stopwatch()..start(), lab = StateLab(model);
    for (var i = 0; i < 200; i++) {
      lab.send('tick');
    }
    expect(lab.values['n'], 18000);
    expect(lab.active, hasLength(90));
    // A bounded synthetic performance guard, not a physical-device frame claim.
    expect(clock.elapsed, lessThan(const Duration(seconds: 5)));
    // ignore: avoid_print
    print('90 regions / 200 events: ${clock.elapsedMilliseconds} ms');
  });
  test(
    'completed composite states trigger completion only after their final child',
    () {
      final lab = StateLab({
        'states': [
          {'id': 'parent', 'initial': true},
          {'id': 'a', 'parent': 'parent', 'initial': true},
          {'id': 'f', 'parent': 'parent', 'final': true},
          {'id': 'done', 'final': true},
        ],
        'transitions': [
          {'from': 'a', 'to': 'f', 'event': 'finish'},
          {'from': 'parent', 'to': 'done', 'event': ''},
        ],
      });
      expect(lab.active, {'a'});
      lab.send('finish');
      expect(lab.active, {'done'});
    },
  );
  test(
    'metadata-looking text inside code fences remains literal and unfinished fences reject insertion',
    () {
      final doc = universityPreset(UniversityLabKind.state),
          literal = '```text\n${doc.markdown}\n```\n';
      expect(UniversityDocument.fromMarkdown(literal), isNull);
      final next = doc.applyTo(literal);
      expect(next.startsWith(literal), true);
      expect(UniversityDocument.fromMarkdown(next)!.data, doc.data);
      expect(UniversityDocument.maskMetadata(literal), literal);
      expect(() => doc.applyTo('```java\nunclosed'), throwsStateError);
    },
  );
  test(
    'condition observations and replica checks report evidence instead of inferred coverage',
    () {
      final m = universityPreset(UniversityLabKind.testing).model;
      (m['nodes'] as List).first['conditions'] = 'a';
      (m['tests'] as List).first['conditions'] = {'a': true};
      expect(conditionCoverage(m)['a'], {true});
      final violations = checkReplicaObservations({
        'events': [
          {'kind': 'write', 'process': 'P1', 'key': 'x', 'version': 4},
          {'kind': 'read', 'process': 'P1', 'key': 'x', 'version': 3},
        ],
      });
      expect(violations.join(), contains('read-your-writes'));
      expect(electionMessages(['1', '3', '2'], ring: true).last, contains('3'));
    },
  );
  for (final kind in UniversityLabKind.values) {
    test(
      '${kind.name} model saves and reopens losslessly with a readable report',
      () {
        final original = universityPreset(kind).updated({
          'future': {'keep': true},
          'title': 'Test --> <title>',
        });
        final markdown = original.applyTo('# Authored note\n\nDo not remove.');
        final recovered = UniversityDocument.fromMarkdown(markdown)!;
        expect(recovered.data, original.data);
        expect(recovered.applyTo(markdown), markdown);
        expect(markdown, contains('Do not remove.'));
        expect(recovered.report(), isNotEmpty);
        expect(
          () => UniversityDocument({...original.data, 'version': 99}),
          throwsFormatException,
        );
        final decoded = UniversityDocument(
          Map<String, dynamic>.from(
            jsonDecode(jsonEncode(original.data)) as Map,
          ),
        );
        expect(decoded.report(), original.report());
      },
    );
    test('${kind.name} inserts ordinary Canvas items with bound endpoints', () {
      var serial = 0;
      final doc = universityPreset(kind);
      final elements = universityDiagram(
        doc,
        () => 'id${serial++}',
        const CanvasPoint(30, 50),
      );
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': elements.map((e) => e.data).toList(),
      });
      expect(scene.elements.length, elements.length);
      final ids = elements.map((e) => e.id).toSet();
      for (final e in elements.where((e) => e.type == 'connector')) {
        expect(ids, contains(e.startId));
        expect(ids, contains(e.endId));
      }
      final recovered = universityModelFromSelection(scene, {
        elements.first.id,
      })!;
      expect(recovered.data, doc.data);
    });
  }
  test('expression precedence, strict types and short circuit', () {
    expect(LabExpression('2 + 3 * 4 == 14 && !false').evaluate({}), true);
    expect(LabExpression('false && 1 / 0 > 0').evaluate({}), false);
    expect(
      () => LabExpression('unknown + 1').evaluate({}),
      throwsFormatException,
    );
    expect(() => LabExpression('true + 1').evaluate({}), throwsFormatException);
    expect(() => LabExpression('1 / 0').evaluate({}), throwsFormatException);
    expect(() => LabExpression('System.exit(0)'), throwsFormatException);
    expect(() => LabExpression('1' * 2500), throwsFormatException);
  });
  test('hierarchical exit transition entry ordering and rollback', () {
    final lab = StateLab({
      'variables': {'x': 0},
      'states': [
        {'id': 'outer', 'initial': true, 'entry': 'x=x+1', 'exit': 'x=x+100'},
        {
          'id': 'a',
          'parent': 'outer',
          'initial': true,
          'entry': 'x=x+2',
          'exit': 'x=x+20',
        },
        {'id': 'b', 'parent': 'outer', 'entry': 'x=x+3'},
        {'id': 'done', 'entry': 'x=x+1000'},
      ],
      'transitions': [
        {'from': 'a', 'to': 'b', 'event': 'next', 'actions': 'x=x+4'},
        {'from': 'b', 'to': 'outer', 'event': 'reset'},
        {'from': 'outer', 'to': 'done', 'event': 'stop'},
        {'from': 'a', 'to': 'a', 'event': 'bad', 'actions': 'x=5; x=1/0'},
      ],
    });
    expect(lab.values['x'], 3);
    expect(lab.active, {'a'});
    expect(() => lab.send('bad'), throwsFormatException);
    expect(lab.values['x'], 3);
    expect(lab.active, {'a'});
    lab.send('next');
    expect(lab.values['x'], 30);
    expect(lab.active, {'b'});
    lab.send('reset');
    expect(lab.active, {'a'});
    lab.send('stop');
    expect(lab.active, {'done'});
    expect(lab.steps.last.actions, contains('x=x+1000'));
  });
  test('orthogonal regions and deep history keep both regions', () {
    final lab = StateLab({
      'variables': {},
      'states': [
        {'id': 'on', 'initial': true},
        {'id': 'off'},
        {'id': 'a', 'parent': 'on', 'region': 'one', 'initial': true},
        {'id': 'b', 'parent': 'on', 'region': 'one'},
        {'id': 'c', 'parent': 'on', 'region': 'two', 'initial': true},
      ],
      'transitions': [
        {'from': 'a', 'to': 'b', 'event': 'next'},
        {'from': 'on', 'to': 'off', 'event': 'off'},
        {'from': 'off', 'to': 'on', 'event': 'on', 'history': true},
      ],
    });
    expect(lab.active, {'a', 'c'});
    lab.send('next');
    expect(lab.active, {'b', 'c'});
    lab.send('off');
    lab.send('on');
    expect(lab.active, {'b', 'c'});
  });
  test(
    'ambiguous guards, hierarchy cycles and completion cycles refuse safely',
    () {
      expect(
        () => StateLab({
          'states': [
            {'id': 'a', 'parent': 'b'},
            {'id': 'b', 'parent': 'a'},
          ],
          'transitions': [],
        }),
        throwsFormatException,
      );
      expect(
        () => StateLab({
          'states': [
            {'id': 'a', 'initial': true},
          ],
          'transitions': [
            {'from': 'a', 'to': 'a', 'event': ''},
          ],
        }),
        throwsFormatException,
      );
      final lab = StateLab({
        'states': [
          {'id': 'a', 'initial': true},
          {'id': 'b'},
        ],
        'transitions': [
          {'from': 'a', 'to': 'a', 'event': 'go'},
          {'from': 'a', 'to': 'b', 'event': 'go'},
        ],
      });
      expect(() => lab.send('go'), throwsFormatException);
      expect(lab.active, {'a'});
    },
  );
  test(
    'fork/join, premature join and activity final follow token semantics',
    () {
      final lab = ActivityLab(
        universityPreset(UniversityLabKind.activity).model,
      );
      lab.step('start');
      lab.step('split');
      lab.step('parents');
      expect(lab.enabled, contains('daughter'));
      expect(lab.enabled, isNot(contains('join')));
      expect(() => lab.step('join'), throwsFormatException);
      lab.step('daughter');
      lab.step('join');
      lab.step('check');
      lab.step('end');
      expect(lab.tokens, isEmpty);
    },
  );
  test(
    'guards see completed actions and exceptions do not leak partial writes',
    () {
      final lab = ActivityLab({
        'variables': {'x': 0},
        'nodes': [
          {'id': 's', 'kind': 'start'},
          {'id': 'a', 'kind': 'action', 'actions': 'x=3; x=1/0'},
          {'id': 'f', 'kind': 'final'},
        ],
        'edges': [
          {'from': 's', 'to': 'a'},
          {'from': 'a', 'to': 'f', 'exception': true},
        ],
      });
      lab.step('s');
      lab.step('a');
      expect(lab.values['x'], 0);
      expect(lab.enabled, ['f']);
    },
  );
  test('coverage distinguishes missing paths and reaching DU pairs', () {
    final model = universityPreset(UniversityLabKind.testing).model;
    var result = labCoverage(model);
    expect(result.missingNodes, isEmpty);
    expect(result.missingEdges, isEmpty);
    expect(result.missingDu, isEmpty);
    model['tests'] = [(model['tests'] as List).first];
    result = labCoverage(model);
    expect(result.missingEdges, contains('condition → return'));
    expect(result.missingDu, contains('x: entry → return'));
    model['tests'] = [
      {'path': 'entry return'},
    ];
    expect(() => labCoverage(model), throwsFormatException);
  });
  test('boundary partitions and JUnit report status import', () {
    expect(
      boundaryCases([
        {'name': 'n', 'min': 0, 'max': 2, 'step': 1},
      ]).map((r) => r['value']),
      containsAll([-1, 0, 1, 2, 3]),
    );
    final rows = junitCases(
      '<testsuite><testcase name="ok"/><testcase name="bad"><failure>Expected &lt;1&gt;</failure></testcase><testcase name="later"><skipped/></testcase></testsuite>',
    );
    expect(rows.map((r) => r['status']), ['passed', 'failed', 'skipped']);
    expect(() => junitCases('<!DOCTYPE a><testsuite/>'), throwsFormatException);
  });
  test('vector clock causality, concurrency, drop and crash failures', () {
    final model = universityPreset(UniversityLabKind.distributed).model,
        trace = distributedTrace(model);
    expect(trace[1].vector, [2, 0, 0]);
    expect(trace[3].vector, [2, 1, 0]);
    expect(trace.last.vector, [2, 2, 2]);
    expect(vectorRelation(trace[1].vector, trace[2].vector), 'concurrent');
    expect(electLeader(['2', '10', '1']), contains('10'));
    model['events'] = [
      {'process': 'P1', 'kind': 'crash'},
      {'process': 'P1', 'kind': 'local'},
    ];
    expect(() => distributedTrace(model), throwsFormatException);
    model['events'] = [
      {'process': 'P2', 'kind': 'receive', 'message': 'missing'},
    ];
    expect(() => distributedTrace(model), throwsFormatException);
  });
  test(
    'SMQP checks greeting, stateful commands, errors and asynchronous delivery',
    () {
      final s = checkProtocolTranscript(
        universityPreset(UniversityLabKind.protocol).model['transcript']
            as String,
      );
      expect(s.phase, 'closed');
      expect(
        () => checkProtocolTranscript('S> ok SMQP\nC> subscribe'),
        throwsFormatException,
      );
      final retry = checkProtocolTranscript(
        'S> ok SMQP\nC> exchange direct a\nS> error nope',
      );
      expect(retry.phase, 'exchange');
      expect(retry.pending, isNull);
      retry.client('exchange direct b');
      expect(() => retry.client('queue q'), throwsFormatException);
    },
  );
  test(
    'connected UML reports invalid slots, multiplicities and inheritance cycles',
    () {
      final m = universityPreset(UniversityLabKind.uml).model;
      expect(checkUmlModel(m), isEmpty);
      (m['nodes'] as List).last['slots'] = 'missing=1';
      expect(checkUmlModel(m).join(), contains('unknown slot'));
      (m['edges'] as List).add({
        'id': 'cycle',
        'from': 'Person',
        'to': 'Student',
        'kind': 'generalization',
      });
      expect(checkUmlModel(m).join(), contains('Inheritance cycle'));
    },
  );
  test('Java/Dafny snippets and assignment path warnings are scoped', () {
    expect(codeLanguageId('Main.java'), 'java');
    expect(codeLanguageId('Main.dfy'), 'dafny');
    expect(
      offlineCodeSuggestions('mai', 3, 'java').first.edits.single.text,
      contains('static void main'),
    );
    expect(protectedUniversityPath('src/test/MainTest.java'), true);
    expect(protectedUniversityPath('src/main/java/Main.java'), false);
    expect(protectedUniversityPath('src/testimonials/Note.java'), false);
  });
}
