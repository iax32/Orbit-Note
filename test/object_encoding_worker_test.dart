import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/infrastructure/storage/object_codec.dart';
import 'package:orbit_note/infrastructure/storage/object_encoding_execution.dart';

ObjectEncoding crashableEncoder(
  UniversalObject object,
  String? previousSource,
) {
  if (object.title == 'Crash') Isolate.exit();
  final source = ObjectCodec().encode(object);
  final bytes = Uint8List.fromList(utf8.encode(source));
  return (source: source, bytes: bytes, hash: sha256.convert(bytes).toString());
}

UniversalObject decodeSeed(String source, String workspace) =>
    ObjectCodec().decode(source, workspace, markdown: false);

class _MutableJson {
  int value = 1;
  Map<String, dynamic> toJson() => {'value': value};
}

UniversalObject board(String workspace) => UniversalObject(
  id: 'same-board-id',
  workspaceId: workspace,
  typeId: 'orbit.canvas',
  title: 'Board',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  extra: {'futureEnvelope': true},
  documentExtra: {
    'futureRoot': [1, 2],
  },
  data: {
    'padding': 'x' * 70000,
    'elements': [
      {
        'id': 'a',
        'type': 'ink',
        'points': [
          {
            'x': 1.0,
            'y': 2.0,
            'pressure': .4,
            'future': [3, 4],
          },
        ],
      },
      {
        'id': 'b',
        'type': 'future',
        'unknown': {'preserved': true},
      },
      'opaque',
    ],
  },
);

void main() {
  test(
    'a stopped worker fails promptly and the next job starts from authoritative data',
    () async {
      final executor = createObjectSaveExecutor(crashableEncoder, decodeSeed);
      addTearDown(executor.close);
      final object = board('work');
      final source = ObjectCodec().encode(object);
      await expectLater(
        executor
            .encode(
              object.copyWith(title: 'Crash'),
              previousObject: object,
              previousSource: source,
              size: 70000,
            )
            .timeout(const Duration(seconds: 5)),
        throwsA(isA<StateError>()),
      );
      expect(
        (await executor.encode(
          object,
          previousObject: object,
          previousSource: source,
          size: 70000,
        )).source,
        source,
      );
    },
  );
  test(
    'cached encoder preserves same-ID edits, deletion, order and opaque fields exactly',
    () async {
      final codec = ObjectCodec();
      addTearDown(codec.close);
      var current = board('workspace');
      var source = codec.encode(current);
      for (var step = 0; step < 4; step++) {
        final old = current;
        final elements = old.data['elements'] as List;
        final nextElements = step == 0
            ? [
                {
                  ...elements[0] as Map,
                  'points': [
                    {'x': 9.0, 'y': 2.0, 'pressure': .8},
                  ],
                },
                elements[1],
                elements[2],
              ]
            : step == 1
            ? [elements[2], elements[0]]
            : step == 2
            ? [
                ...elements,
                {'id': 'new', 'type': 'sticky', 'text': 'New 😀'},
              ]
            : elements.reversed.toList();
        current = old.copyWith(
          title: 'Step $step',
          revision: old.revision + 1,
          data: {...old.data, 'elements': nextElements},
        );
        final encoded = await codec.encodeForSave(
          current,
          previousObject: old,
          previousSource: source,
        );
        expect(encoded.source, codec.encode(current));
        expect(utf8.decode(encoded.bytes), encoded.source);
        expect(encoded.hash, sha256.convert(encoded.bytes).toString());
        source = encoded.source;
      }
    },
  );

  test(
    'queued boards with the same identity in different Vaults never share cached content',
    () async {
      final codec = ObjectCodec();
      addTearDown(codec.close);
      final first = board('one'),
          second = board('two').copyWith(title: 'Different');
      final encodings = await Future.wait([
        codec.encodeForSave(
          first,
          previousObject: first,
          previousSource: codec.encode(first),
        ),
        codec.encodeForSave(
          second,
          previousObject: second,
          previousSource: codec.encode(second),
        ),
        codec.encodeForSave(
          first,
          previousObject: first,
          previousSource: codec.encode(first),
        ),
      ]);
      expect(encodings.map((e) => e.source), [
        codec.encode(first),
        codec.encode(second),
        codec.encode(first),
      ]);
      await codec.close();
      expect(
        (await codec.encodeForSave(
          second,
          previousObject: second,
          previousSource: codec.encode(second),
        )).source,
        codec.encode(second),
      );
    },
  );

  test(
    'failed jobs reset derived state and unrelated previous sources fall back safely',
    () async {
      final codec = ObjectCodec();
      addTearDown(codec.close);
      final object = board('work');
      final source = codec.encode(object);
      await codec.encodeForSave(
        object,
        previousObject: object,
        previousSource: source,
      );
      final invalid = object.copyWith(
        data: {...object.data, 'invalid': double.nan},
      );
      await expectLater(
        codec.encodeForSave(
          invalid,
          previousObject: object,
          previousSource: source,
        ),
        throwsA(anything),
      );
      expect(
        (await codec.encodeForSave(
          object,
          previousObject: object,
          previousSource: 'wrong previous source',
        )).source,
        source,
      );
      final note = UniversalObject(
        id: 'note',
        workspaceId: 'work',
        typeId: 'orbit.note',
        title: 'Long note',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        body: 'Text 😀\n' * 10000,
      );
      final original = codec.encode(note);
      expect(
        (await codec.encodeForSave(
          note.copyWith(title: 'Changed'),
          previousSource: original,
        )).source,
        codec.encode(note.copyWith(title: 'Changed'), previousSource: original),
      );
    },
  );

  test(
    'legacy mutable toJson values cannot become stale cached element records',
    () async {
      final codec = ObjectCodec();
      addTearDown(codec.close);
      final mutable = _MutableJson();
      final base = board('work');
      final elements = base.data['elements'] as List;
      final object = base.copyWith(
        data: {
          ...base.data,
          'elements': [
            {...elements[0] as Map, 'legacy': mutable},
            ...elements.skip(1),
          ],
        },
      );
      final source = codec.encode(object);
      expect(
        isImmutableObjectData(
          (object.data['elements'] as List).first as Map<String, dynamic>,
        ),
        false,
      );
      await codec.encodeForSave(
        object,
        previousObject: object,
        previousSource: source,
      );
      mutable.value = 2;
      final changed = await codec.encodeForSave(
        object,
        previousObject: object,
        previousSource: source,
      );
      expect(changed.source, codec.encode(object));
      expect(changed.source, isNot(source));
    },
  );
}
