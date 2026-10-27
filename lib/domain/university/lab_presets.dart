import 'lab_document.dart';

UniversityDocument universityPreset(
  UniversityLabKind kind,
) => UniversityDocument({
  'version': 1,
  'kind': kind.name,
  'title': kind.label,
  'course': '',
  'source': '',
  'model': switch (kind) {
    UniversityLabKind.state => {
      'variables': {'seats': 2},
      'events': 'open reserve reserve cancel close',
      'states': [
        {'id': 'closed', 'name': 'Closed', 'initial': true},
        {'id': 'available', 'name': 'Available'},
        {'id': 'full', 'name': 'Full'},
        {'id': 'finished', 'name': 'Finished', 'final': true},
      ],
      'transitions': [
        {'from': 'closed', 'to': 'available', 'event': 'open'},
        {
          'from': 'available',
          'to': 'available',
          'event': 'reserve',
          'guard': 'seats > 1',
          'actions': 'seats--',
        },
        {
          'from': 'available',
          'to': 'full',
          'event': 'reserve',
          'guard': 'seats == 1',
          'actions': 'seats--',
        },
        {
          'from': 'full',
          'to': 'available',
          'event': 'cancel',
          'actions': 'seats++',
        },
        {
          'from': 'available',
          'to': 'available',
          'event': 'cancel',
          'actions': 'seats++',
          'internal': true,
        },
        {'from': 'available', 'to': 'finished', 'event': 'close'},
        {'from': 'full', 'to': 'finished', 'event': 'close'},
      ],
    },
    UniversityLabKind.activity => {
      'variables': {'budget': 100, 'cost': 80},
      'schedule': 'start split parents daughter join check end',
      'nodes': [
        {'id': 'start', 'name': 'Start', 'kind': 'start'},
        {'id': 'split', 'name': 'Parallel plans', 'kind': 'fork'},
        {
          'id': 'parents',
          'name': 'Visit city',
          'kind': 'action',
          'lane': 'Parents',
        },
        {
          'id': 'daughter',
          'name': 'Go to beach',
          'kind': 'action',
          'lane': 'Daughter',
        },
        {'id': 'join', 'name': 'Meet for lunch', 'kind': 'join'},
        {'id': 'check', 'name': 'Within budget?', 'kind': 'decision'},
        {'id': 'end', 'name': 'Completed', 'kind': 'final'},
        {'id': 'revise', 'name': 'Revise plan', 'kind': 'action'},
      ],
      'edges': [
        {'from': 'start', 'to': 'split'},
        {'from': 'split', 'to': 'parents'},
        {'from': 'split', 'to': 'daughter'},
        {'from': 'parents', 'to': 'join'},
        {'from': 'daughter', 'to': 'join'},
        {'from': 'join', 'to': 'check'},
        {'from': 'check', 'to': 'end', 'guard': 'cost <= budget'},
        {'from': 'check', 'to': 'revise', 'guard': 'cost > budget'},
        {'from': 'revise', 'to': 'end'},
      ],
    },
    UniversityLabKind.uml => {
      'nodes': [
        {
          'id': 'Person',
          'name': 'Person',
          'kind': 'class',
          'attributes': '+ name: String',
          'operations': '+ greet(): String',
        },
        {
          'id': 'Student',
          'name': 'Student',
          'kind': 'class',
          'attributes': '+ number: int',
          'operations': '+ study(): void',
        },
        {
          'id': 'alice',
          'name': 'alice:Person',
          'kind': 'object',
          'class': 'Person',
          'slots': 'name = Alice',
        },
      ],
      'edges': [
        {
          'id': 'inherits',
          'from': 'Student',
          'to': 'Person',
          'kind': 'generalization',
        },
        {
          'id': 'owns',
          'from': 'Person',
          'to': 'Student',
          'kind': 'association',
          'fromMultiplicity': '1',
          'toMultiplicity': '0..*',
        },
      ],
      'messages': [],
      'fragments': [],
      'trace': '',
      'variables': {},
    },
    UniversityLabKind.testing => {
      'nodes': [
        {'id': 'entry', 'name': 'x = 0', 'defs': 'x'},
        {'id': 'condition', 'name': 'input > 0?', 'uses': 'input'},
        {'id': 'positive', 'name': 'x = input', 'defs': 'x', 'uses': 'input'},
        {'id': 'return', 'name': 'return x', 'uses': 'x'},
      ],
      'edges': [
        {'from': 'entry', 'to': 'condition'},
        {'from': 'condition', 'to': 'positive'},
        {'from': 'positive', 'to': 'return'},
        {'from': 'condition', 'to': 'return'},
      ],
      'tests': [
        {
          'name': 'Positive',
          'input': '1',
          'expected': '1',
          'actual': '1',
          'path': 'entry condition positive return',
        },
        {
          'name': 'Zero',
          'input': '0',
          'expected': '0',
          'path': 'entry condition return',
        },
      ],
      'partitions': [
        {'name': 'grade', 'min': 0, 'max': 100, 'step': 1},
      ],
      'junit': '',
    },
    UniversityLabKind.distributed => {
      'processes': ['P1', 'P2', 'P3'],
      'reachable': '1 2 3',
      'events': [
        {'process': 'P1', 'kind': 'local'},
        {'process': 'P1', 'kind': 'send', 'to': 'P2', 'message': 'm1'},
        {'process': 'P3', 'kind': 'local'},
        {'process': 'P2', 'kind': 'receive', 'message': 'm1'},
        {'process': 'P2', 'kind': 'send', 'to': 'P3', 'message': 'm2'},
        {'process': 'P3', 'kind': 'receive', 'message': 'm2'},
      ],
    },
    UniversityLabKind.protocol => {
      'transcript':
          'S> ok SMQP\nC> exchange fanout animals\nS> ok\nC> queue cats\nS> ok\nC> bind none\nS> ok\nC> subscribe\nS> ok\nS> maine-coon\nC> exit\nS> ok bye',
      'buildSystem': 'Maven (assignment) / Gradle (select per project)',
      'protectedPaths':
          '.GitLab/**, src/main/resources/**, src/test/**, pom.xml',
    },
    UniversityLabKind.contracts => {
      'code':
          'method Min(a: int, b: int) returns (m: int)\n  ensures m <= a && m <= b\n  ensures m == a || m == b\n{\n  if a <= b { m := a; } else { m := b; }\n}\n\nmethod Find(a: array<int>, value: int) returns (index: int)\n  ensures -1 <= index < a.Length\n  ensures index >= 0 ==> a[index] == value\n{\n  index := 0;\n  while index < a.Length\n    invariant 0 <= index <= a.Length\n    decreases a.Length - index\n  {\n    if a[index] == value { return; }\n    index := index + 1;\n  }\n  index := -1;\n}',
      'verification': '',
    },
  },
});
