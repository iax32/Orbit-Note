import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/domain/workspace_failure.dart';
import 'package:orbit_note/infrastructure/storage/object_codec.dart';

void main() {
  final codec = ObjectCodec();
  UniversalObject note() => UniversalObject(
    id: '11111111-1111-4111-8111-111111111111',
    workspaceId: '22222222-2222-4222-8222-222222222222',
    typeId: 'orbit.note',
    title: 'Test note',
    body: '# Hello\n\n- [ ] Task\n',
    createdAt: DateTime.utc(2026, 9, 8),
    updatedAt: DateTime.utc(2026, 9, 8),
    properties: {
      'tags': ['study'],
      'vendor:flag': {'nested': 1},
    },
    extra: {'vendor:record': 'preserve'},
  );

  test('Markdown round trip keeps identity, body and unknown values', () {
    final original = note();
    final source = codec.encode(original);
    final decoded = codec.decode(source, original.workspaceId, markdown: true);
    expect(decoded.toJson(), original.toJson());
    expect(decoded.body, original.body);
    expect(source, contains('# Hello'));
    expect(() => decoded.properties['tags'].add('new'), throwsUnsupportedError);
  });

  test(
    'updating known metadata preserves unrelated YAML text and comments',
    () {
      const source = '''---
# A human comment
orbit:
  id: 11111111-1111-4111-8111-111111111111
  typeId: orbit.note
  schemaVersion: 1
  title: Before
  createdAt: 2026-09-08T00:00:00Z
  updatedAt: 2026-09-08T00:00:00Z
  revision: 1
  deletedAt: null
  custom: "do not touch" # Keep this comment
properties:
  tags: [study]
external: 'original quoting' # Keep this too
---
Body without trailing newline''';
      final object = codec.decode(source, 'workspace', markdown: true);
      final changed = codec.encode(
        object.copyWith(title: 'After'),
        previousSource: source,
      );
      expect(changed, contains('# A human comment'));
      expect(changed, contains('custom: "do not touch" # Keep this comment'));
      expect(changed, contains("external: 'original quoting' # Keep this too"));
      expect(changed, endsWith('Body without trailing newline'));
      expect(codec.decode(changed, 'workspace', markdown: true).title, 'After');
    },
  );

  test('future JSON version remains inspectable but cannot be serialized', () {
    final object = note();
    final future =
        '''{
      "format":"orbit-note-board","version":7,"vendor:data":{"a":3},
      "object":${_jsonObject(object)},"data":{"elements":[],"futureField":7}
    }''';
    final decoded = codec.decode(future, object.workspaceId, markdown: false);
    expect(decoded.isReadOnly, isTrue);
    expect(decoded.documentExtra['vendor:data'], {'a': 3});
    expect(decoded.data['futureField'], 7);
    expect(() => codec.encode(decoded), throwsA(isA<WorkspaceReadOnly>()));
  });

  test('unknown structured metadata and nested data survive body edits', () {
    final object = UniversalObject(
      id: note().id,
      workspaceId: note().workspaceId,
      typeId: 'orbit.canvas',
      title: 'Board',
      createdAt: note().createdAt,
      updatedAt: note().updatedAt,
      data: {
        'elements': [
          {'id': 'placement', 'objectId': note().id},
        ],
        'custom': [1, 2],
      },
      extra: {'extraEnvelope': true},
      documentExtra: {'extraRoot': 'keep'},
    );
    final decoded = codec.decode(
      codec.encode(object),
      object.workspaceId,
      markdown: false,
    );
    expect(decoded.data, object.data);
    expect(decoded.extra, object.extra);
    expect(decoded.documentExtra, object.documentExtra);
    expect(decoded.copyWith(title: 'Renamed').id, object.id);
  });
}

String _jsonObject(UniversalObject object) =>
    '''{
  "id":"${object.id}","typeId":"orbit.canvas","schemaVersion":1,
  "title":"Future","createdAt":"2026-09-08T00:00:00Z",
  "updatedAt":"2026-09-08T00:00:00Z","revision":1,"properties":{}
}''';
