part of 'collaboration.dart';

enum CanvasConflictSide { local, shared }

/// A placement alternative, including removal. Referenced objects are untouched.
class CanvasPlacementConflict {
  CanvasPlacementConflict._(this.id, this.base, this.local, this.shared);
  final String id;
  final Map<String, dynamic>? base, local, shared;

  String get label {
    final value = local ?? shared ?? base!;
    final text = value['text'] ?? value['title'];
    if (text is String && text.trim().isNotEmpty) {
      return text.trim().split(RegExp(r'[\r\n]')).first;
    }
    return '${value['type'] ?? 'Placement'} · $id';
  }

  List<String> get changedFields => [
    for (final key in {...?base?.keys, ...?local?.keys, ...?shared?.keys})
      if (!collaborationEqual(local?[key], shared?[key]) ||
          (local?.containsKey(key) != shared?.containsKey(key)))
        key,
  ];
}

/// Immutable three-way comparison. Only actual overlap needs a choice; other
/// fields keep the existing merge rules. Unsupported document conflicts refuse
/// review instead of dropping metadata or guessing at an unknown common base.
class CanvasConflictReview {
  CanvasConflictReview._(
    this.base,
    this.local,
    this.shared,
    this.placements,
    this.hasOrderConflict,
  );

  factory CanvasConflictReview.create(
    Map<String, dynamic> base,
    Map<String, dynamic> local,
    Map<String, dynamic> shared,
  ) {
    final snapshots = [base, local, shared].map(_freezeCanvasSnapshot).toList();
    if (snapshots.any((s) => collaborationObject(s).typeId != 'orbit.canvas')) {
      throw const FormatException(
        'Only Canvas placements can be reviewed here.',
      );
    }
    final recorder = _CanvasReviewChoices();
    _mergeCollaboration(
      snapshots[0],
      snapshots[1],
      snapshots[2],
      review: recorder,
    );
    return CanvasConflictReview._(
      snapshots[0],
      snapshots[1],
      snapshots[2],
      List.unmodifiable(recorder.conflicts),
      recorder.orderConflict,
    );
  }

  final Map<String, dynamic> base, local, shared;
  final List<CanvasPlacementConflict> placements;
  final bool hasOrderConflict;

  Map<String, dynamic> resolve(
    Map<String, CanvasConflictSide> choices, {
    CanvasConflictSide? order,
  }) {
    final requiredIds = placements.map((p) => p.id).toSet();
    if (choices.length != requiredIds.length ||
        !requiredIds.containsAll(choices.keys) ||
        (hasOrderConflict && order == null)) {
      throw StateError(
        'Choose a version for every overlapping item and order.',
      );
    }
    return _mergeCollaboration(
      base,
      local,
      shared,
      review: _CanvasReviewChoices(choices: choices, orderChoice: order),
    );
  }
}

Map<String, dynamic> _freezeCanvasSnapshot(Map<String, dynamic> value) {
  dynamic freeze(dynamic v) => v is Map
      ? Map<String, dynamic>.unmodifiable(
          v.map((key, value) => MapEntry(key as String, freeze(value))),
        )
      : v is List
      ? List<dynamic>.unmodifiable(v.map(freeze))
      : v;
  return freeze(value) as Map<String, dynamic>;
}

class _CanvasReviewChoices {
  _CanvasReviewChoices({this.choices, this.orderChoice});
  final Map<String, CanvasConflictSide>? choices;
  final CanvasConflictSide? orderChoice;
  final conflicts = <CanvasPlacementConflict>[];
  bool orderConflict = false;

  dynamic placement(String id, dynamic base, dynamic local, dynamic shared) {
    Map<String, dynamic>? value(dynamic v) => identical(v, _absent)
        ? null
        : Map<String, dynamic>.unmodifiable(v as Map<String, dynamic>);
    conflicts.add(
      CanvasPlacementConflict._(id, value(base), value(local), value(shared)),
    );
    if (choices != null && !choices!.containsKey(id)) {
      throw StateError('The comparison changed. Review it again.');
    }
    return choices?[id] == CanvasConflictSide.shared ? shared : local;
  }

  CanvasConflictSide order() {
    orderConflict = true;
    return orderChoice ?? CanvasConflictSide.local;
  }
}
