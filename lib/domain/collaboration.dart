import 'universal_object.dart';
import 'dart:typed_data';

part 'canvas_conflict_review.dart';

/// Ephemeral selected placement IDs; never a lock or durable document state.
List<String> collaborationSelectionIds(Object? value) => value is List
    ? value
          .whereType<String>()
          .where((id) => id.isNotEmpty && id.length <= 160)
          .take(64)
          .toSet()
          .toList()
    : const [];

Map<String, dynamic> collaborationSnapshot(UniversalObject object) => {
  'object': object.toJson(),
  'body': object.body,
  'data': object.data,
  'documentExtra': object.documentExtra,
  'formatVersion': object.formatVersion,
};

UniversalObject collaborationObject(
  Map<String, dynamic> value, {
  bool allowDeleted = false,
}) {
  final object = UniversalObject.fromJson(
    Map<String, dynamic>.from(value['object'] as Map),
    body: value['body'] as String,
    data: Map<String, dynamic>.from(value['data'] as Map),
    documentExtra: Map<String, dynamic>.from(value['documentExtra'] as Map),
    formatVersion: value['formatVersion'] as int,
  );
  if (object.isReadOnly || (object.isDeleted && !allowDeleted)) {
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

/// An edit preflight must not survive a restart/restore between HTTP requests.
class CollaborationHostChanged extends CollaborationConflict {
  const CollaborationHostChanged() : super('a restarted host');
  @override
  String toString() =>
      'The host restarted before accepting this edit. Your local version is preserved; check shared changes before reviewing.';
}

/// Conservative three-way merge. Independent edits combine; uncertain changes
/// remain an explicit conflict rather than a clock-based overwrite.
Map<String, dynamic> mergeCollaboration(
  Map<String, dynamic> base,
  Map<String, dynamic> local,
  Map<String, dynamic> remote,
) => _mergeCollaboration(base, local, remote);

Map<String, dynamic> mergeSharedDocument(
  Map<String, dynamic> base,
  Map<String, dynamic> local,
  Map<String, dynamic> remote,
) {
  final b = (base['object'] as Map)['deletedAt'];
  final l = (local['object'] as Map)['deletedAt'];
  final r = (remote['object'] as Map)['deletedAt'];
  if ((l != b && !collaborationContentEqual(base, remote)) ||
      (r != b && !collaborationContentEqual(base, local))) {
    if (!collaborationContentEqual(local, remote)) {
      throw const CollaborationConflict('deletion versus editing');
    }
  }
  return _mergeCollaboration(base, local, remote, lifecycle: true);
}

Map<String, dynamic> _mergeCollaboration(
  Map<String, dynamic> base,
  Map<String, dynamic> local,
  Map<String, dynamic> remote, {
  _CanvasReviewChoices? review,
  bool lifecycle = false,
}) {
  for (final key in [
    'id',
    'workspaceId',
    'typeId',
    'createdAt',
    'schemaVersion',
    if (!lifecycle) 'deletedAt',
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
  final before = collaborationObject(base, allowDeleted: lifecycle);
  void validatePlacements(UniversalObject object) {
    if (object.typeId != 'orbit.canvas') return;
    final elements = object.data['elements'];
    if (elements == null) return;
    final ids = <String>{};
    if (elements is! List ||
        elements.any(
          (element) =>
              element is! Map ||
              element['id'] is! String ||
              (element['id'] as String).isEmpty ||
              !ids.add(element['id'] as String),
        )) {
      throw const CollaborationConflict('Canvas placement identities');
    }
  }

  validatePlacements(before);
  for (final value in [local, remote]) {
    final candidate = collaborationObject(value, allowDeleted: lifecycle);
    validatePlacements(candidate);
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
    _merge(
          normalize(base),
          normalize(local),
          normalize(remote),
          'document',
          review,
        )
        as Map,
  );
}

const _absent = Object();
dynamic _merge(
  dynamic base,
  dynamic local,
  dynamic remote,
  String path, [
  _CanvasReviewChoices? review,
]) {
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
        review,
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

    final b = byId(base), l = byId(local), r = byId(remote);
    final merged = <String, dynamic>{};
    for (final id in {...b.keys, ...l.keys, ...r.keys}) {
      final before = b.containsKey(id) ? b[id] : _absent;
      final mine = l.containsKey(id) ? l[id] : _absent;
      final shared = r.containsKey(id) ? r[id] : _absent;
      dynamic value;
      try {
        value = _merge(before, mine, shared, '$path.byId.$id');
      } on CollaborationConflict {
        if (review == null) rethrow;
        value = review.placement(id, before, mine, shared);
      }
      if (!identical(value, _absent)) merged[id] = value;
    }
    // Reordering is itself meaningful. Concurrent independent additions retain
    // server order and append new local placements, never duplicate an ID.
    final baseOrder = base.map((v) => (v as Map)['id']).toList();
    final localOrder = local.map((v) => (v as Map)['id']).toList();
    final remoteOrder = remote.map((v) => (v as Map)['id']).toList();
    final baseIds = baseOrder.toSet(),
        localIds = localOrder.toSet(),
        remoteIds = remoteOrder.toSet();
    final localExisting = localOrder.where(baseIds.contains).toList();
    final remoteExisting = remoteOrder.where(baseIds.contains).toList();
    final localReordered = !collaborationEqual(
      localExisting,
      baseOrder.where(localIds.contains).toList(),
    );
    final remoteReordered = !collaborationEqual(
      remoteExisting,
      baseOrder.where(remoteIds.contains).toList(),
    );
    var useLocalOrder = localReordered;
    if (localReordered &&
        remoteReordered &&
        !collaborationEqual(
          localExisting.where(remoteIds.contains).toList(),
          remoteExisting.where(localIds.contains).toList(),
        )) {
      if (review == null) throw CollaborationConflict('$path.order');
      useLocalOrder = review.order() == CanvasConflictSide.local;
    }
    final order = <dynamic>{
      ...(useLocalOrder ? localOrder : remoteOrder),
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
  final mine = _textEdits(base, local), theirs = _textEdits(base, remote);
  final merged = [...theirs];
  for (final a in mine) {
    var handled = false;
    for (var i = 0; i < merged.length; i++) {
      final b = merged[i];
      if (a.start == b.start && a.end == b.end && a.text == b.text) {
        handled = true;
        break;
      }
      if (a.start == a.end && b.start == b.end && a.start == b.start) {
        merged[i] = (start: a.start, end: a.end, text: b.text + a.text);
        handled = true;
        break;
      }
      final intersects =
          (a.start < b.end && b.start < a.end) ||
          (a.start == a.end && a.start > b.start && a.start < b.end) ||
          (b.start == b.end && b.start > a.start && b.start < a.end);
      if (intersects) throw CollaborationConflict(path);
    }
    if (!handled) merged.add(a);
  }
  merged.sort((a, b) {
    final start = b.start.compareTo(a.start);
    return start != 0 ? start : b.end.compareTo(a.end);
  });
  var result = base;
  for (final edit in merged) {
    result = result.replaceRange(edit.start, edit.end, edit.text);
  }
  return result;
}

/// Bounded scalar-aware edit decomposition. Large uncertain windows fall back
/// to the existing conservative splice, never an unbounded quadratic diff.
List<({int start, int end, String text})> _textEdits(
  String before,
  String after,
) {
  if (before == after) return [];
  final outer = _splice(before, after);
  final a = before.substring(outer.start, outer.end).runes.toList();
  final b = outer.text.runes.toList();
  if (a.length > 4096 || b.length > 4096 || a.length * b.length > 1000000) {
    return [outer];
  }
  final rows = List.generate(a.length + 1, (_) => Uint16List(b.length + 1));
  for (var i = a.length - 1; i >= 0; i--) {
    for (var j = b.length - 1; j >= 0; j--) {
      rows[i][j] = a[i] == b[j]
          ? 1 + rows[i + 1][j + 1]
          : rows[i + 1][j] > rows[i][j + 1]
          ? rows[i + 1][j]
          : rows[i][j + 1];
    }
  }
  final edits = <({int start, int end, String text})>[];
  var i = 0, j = 0, offset = outer.start;
  int? start;
  var text = StringBuffer();
  void flush() {
    if (start != null) {
      edits.add((start: start!, end: offset, text: text.toString()));
      start = null;
      text = StringBuffer();
    }
  }

  while (i < a.length || j < b.length) {
    if (i < a.length && j < b.length && a[i] == b[j]) {
      flush();
      offset += a[i] > 0xffff ? 2 : 1;
      i++;
      j++;
    } else if (j < b.length &&
        (i == a.length || rows[i][j + 1] >= rows[i + 1][j])) {
      start ??= offset;
      text.writeCharCode(b[j++]);
    } else {
      start ??= offset;
      offset += a[i] > 0xffff ? 2 : 1;
      i++;
    }
  }
  flush();
  return edits;
}

bool collaborationContentEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
  Map normalize(Map value) => {
    ...value,
    'object': {...value['object'] as Map, 'revision': 0, 'updatedAt': ''},
  };
  return collaborationEqual(normalize(a), normalize(b));
}
