import 'universal_object.dart';

Map<String, dynamic> collaborationSnapshot(UniversalObject object) => {
  'object': object.toJson(),
  'body': object.body,
  'data': object.data,
  'documentExtra': object.documentExtra,
  'formatVersion': object.formatVersion,
};

UniversalObject collaborationObject(Map<String, dynamic> value) {
  final object = UniversalObject.fromJson(
    Map<String, dynamic>.from(value['object'] as Map),
    body: value['body'] as String,
    data: Map<String, dynamic>.from(value['data'] as Map),
    documentExtra: Map<String, dynamic>.from(value['documentExtra'] as Map),
    formatVersion: value['formatVersion'] as int,
  );
  if (object.isReadOnly || object.isDeleted) {
    throw const FormatException('Only current, active objects can be shared.');
  }
  return object;
}

bool collaborationEqual(dynamic a, dynamic b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && collaborationEqual(a[k], b[k]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        Iterable<int>.generate(
          a.length,
        ).every((i) => collaborationEqual(a[i], b[i]));
  }
  return a == b;
}

class CollaborationConflict implements Exception {
  const CollaborationConflict(this.path);
  final String path;
  @override
  String toString() =>
      'Both people changed $path. Your local version is preserved; review it before retrying.';
}

/// Conservative three-way merge. Independent edits combine; uncertain changes
/// remain an explicit conflict rather than a clock-based overwrite.
Map<String, dynamic> mergeCollaboration(
  Map<String, dynamic> base,
  Map<String, dynamic> local,
  Map<String, dynamic> remote,
) {
  for (final key in [
    'id',
    'workspaceId',
    'typeId',
    'createdAt',
    'schemaVersion',
    'deletedAt',
  ]) {
    if (!collaborationEqual(
          (base['object'] as Map)[key],
          (local['object'] as Map)[key],
        ) ||
        !collaborationEqual(
          (base['object'] as Map)[key],
          (remote['object'] as Map)[key],
        )) {
      throw CollaborationConflict('object.$key');
    }
  }
  if (base['formatVersion'] != local['formatVersion'] ||
      base['formatVersion'] != remote['formatVersion']) {
    throw const CollaborationConflict('format version');
  }
  // These envelopes are retained by local saves, but the editing commands do
  // not mutate them. Refuse such changes instead of falsely acknowledging them.
  final before = collaborationObject(base);
  for (final value in [local, remote]) {
    final candidate = collaborationObject(value);
    if (!collaborationEqual(before.extra, candidate.extra) ||
        !collaborationEqual(before.documentExtra, candidate.documentExtra)) {
      throw const CollaborationConflict('unsupported document metadata');
    }
  }
  Map<String, dynamic> normalize(Map<String, dynamic> value) => {
    ...value,
    'object': {
      ...value['object'] as Map,
      'revision': 0,
      'updatedAt': (base['object'] as Map)['updatedAt'],
    },
  };
  return Map<String, dynamic>.from(
    _merge(normalize(base), normalize(local), normalize(remote), 'document')
        as Map,
  );
}

const _absent = Object();
dynamic _merge(dynamic base, dynamic local, dynamic remote, String path) {
  if (collaborationEqual(local, base)) return remote;
  if (collaborationEqual(remote, base) || collaborationEqual(local, remote)) {
    return local;
  }
  if (base is String &&
      local is String &&
      remote is String &&
      (path.endsWith('.body') || path.endsWith('.text'))) {
    return _mergeText(base, local, remote, path);
  }
  if (base is Map && local is Map && remote is Map) {
    final result = <String, dynamic>{};
    for (final key in {...base.keys, ...local.keys, ...remote.keys}) {
      final value = _merge(
        base.containsKey(key) ? base[key] : _absent,
        local.containsKey(key) ? local[key] : _absent,
        remote.containsKey(key) ? remote[key] : _absent,
        '$path.$key',
      );
      if (!identical(value, _absent)) result[key as String] = value;
    }
    return result;
  }
  if (path.endsWith('.elements') &&
      base is List &&
      local is List &&
      remote is List) {
    Map<String, dynamic> byId(List list) {
      final result = <String, dynamic>{};
      for (final value in list) {
        if (value is! Map ||
            value['id'] is! String ||
            (value['id'] as String).isEmpty ||
            result.containsKey(value['id'])) {
          throw CollaborationConflict(path);
        }
        result[value['id'] as String] = value;
      }
      return result;
    }

    final merged =
        _merge(byId(base), byId(local), byId(remote), '$path.byId') as Map;
    // Reordering is itself meaningful. Concurrent independent additions retain
    // server order and append new local placements, never duplicate an ID.
    final baseOrder = base.map((v) => (v as Map)['id']).toList();
    final localOrder = local.map((v) => (v as Map)['id']).toList();
    final remoteOrder = remote.map((v) => (v as Map)['id']).toList();
    final localExisting = localOrder.where(baseOrder.contains).toList();
    final remoteExisting = remoteOrder.where(baseOrder.contains).toList();
    final localReordered = !collaborationEqual(
      localExisting,
      baseOrder.where(localExisting.contains).toList(),
    );
    final remoteReordered = !collaborationEqual(
      remoteExisting,
      baseOrder.where(remoteExisting.contains).toList(),
    );
    if (localReordered &&
        remoteReordered &&
        !collaborationEqual(localExisting, remoteExisting)) {
      throw CollaborationConflict('$path.order');
    }
    final order = <dynamic>{
      ...(localReordered ? localOrder : remoteOrder),
      ...localOrder,
      ...remoteOrder,
    };
    return [
      for (final id in order)
        if (merged.containsKey(id)) merged[id],
    ];
  }
  throw CollaborationConflict(path);
}

({int start, int end, String text}) _splice(String before, String after) {
  var start = 0, end = before.length, afterEnd = after.length;
  while (start < end &&
      start < afterEnd &&
      before.codeUnitAt(start) == after.codeUnitAt(start)) {
    start++;
  }
  // Do not split surrogate pairs at either boundary.
  if (start > 0 &&
      start < before.length &&
      before.codeUnitAt(start) >= 0xdc00 &&
      before.codeUnitAt(start) <= 0xdfff) {
    start--;
  }
  while (end > start &&
      afterEnd > start &&
      before.codeUnitAt(end - 1) == after.codeUnitAt(afterEnd - 1)) {
    end--;
    afterEnd--;
  }
  if (end < before.length &&
      end > start &&
      before.codeUnitAt(end) >= 0xdc00 &&
      before.codeUnitAt(end) <= 0xdfff) {
    end++;
    afterEnd++;
  }
  return (start: start, end: end, text: after.substring(start, afterEnd));
}

String _mergeText(String base, String local, String remote, String path) {
  final a = _splice(base, local), b = _splice(base, remote);
  if (a.start == a.end && b.start == b.end && a.start == b.start) {
    return base.replaceRange(a.start, a.end, b.text + a.text);
  }
  if (a.end <= b.start) {
    return base
        .replaceRange(b.start, b.end, b.text)
        .replaceRange(a.start, a.end, a.text);
  }
  if (b.end <= a.start) {
    return base
        .replaceRange(a.start, a.end, a.text)
        .replaceRange(b.start, b.end, b.text);
  }
  throw CollaborationConflict(path);
}

bool collaborationContentEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
  Map normalize(Map value) => {
    ...value,
    'object': {...value['object'] as Map, 'revision': 0, 'updatedAt': ''},
  };
  return collaborationEqual(normalize(a), normalize(b));
}
