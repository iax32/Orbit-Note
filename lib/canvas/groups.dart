import 'dart:math' as math;

import 'geometry.dart';
import 'scene.dart';

/// Pure domain helper functions for Canvas Groups (CAN-04, CAN-05).
/// Groups own spatial organization and placement coordination only,
/// never mutating or copying underlying universal knowledge objects.

/// Returns all renderable elements belonging to the specified [groupId] in the scene.
List<CanvasElement> getGroupMembers(CanvasScene scene, String groupId) =>
    scene.elements.where((e) => e.renderable && e.groupId == groupId).toList();

/// Returns all distinct group IDs currently present across renderable elements in the scene.
List<String> getAllGroupIds(CanvasScene scene) => scene.elements
    .where((e) => e.renderable && e.groupId != null)
    .map((e) => e.groupId!)
    .toSet()
    .toList();

/// Computes the union bounding box enclosing all members of the group.
/// Returns null if the group has no members.
CanvasBounds? calculateGroupBounds(CanvasScene scene, String groupId) {
  final members = getGroupMembers(scene, groupId);
  if (members.isEmpty) return null;
  return members.map((e) => e.bounds).reduce((a, b) => a.union(b));
}

/// Returns true if any member of the group is locked.
/// Invariant: Locked members prevent parent / group transformations.
bool isGroupLocked(CanvasScene scene, String groupId) =>
    getGroupMembers(scene, groupId).any((e) => e.locked);

/// Generates updated elements assigning a new unique groupId to all items in [ids].
/// Returns empty list if fewer than 2 elements are provided.
List<CanvasElement> groupElements(
  CanvasScene scene,
  Iterable<String> ids, {
  String? newGroupId,
}) {
  final targets = ids
      .map((id) => scene[id])
      .whereType<CanvasElement>()
      .where((e) => e.renderable)
      .toList();
  if (targets.length < 2) return const [];
  final gid =
      newGroupId ??
      'grp_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(10000)}';
  return targets.map((e) => e.copy({'groupId': gid})).toList();
}

/// Generates updated elements clearing groupId from all members of groups containing [ids].
List<CanvasElement> ungroupElements(CanvasScene scene, Iterable<String> ids) {
  final groupIds = ids
      .map((id) => scene[id]?.groupId)
      .whereType<String>()
      .toSet();
  if (groupIds.isEmpty) return const [];
  final toUngroup = scene.elements
      .where((e) => groupIds.contains(e.groupId))
      .toList();
  return toUngroup.map((e) {
    final updatedData = Map<String, dynamic>.from(e.data)..remove('groupId');
    return CanvasElement(updatedData);
  }).toList();
}

/// Clones all elements in a group with new element IDs, translated by [offset],
/// and bound under a newly generated shared groupId.
List<CanvasElement> duplicateGroupElements(
  CanvasScene scene,
  String groupId,
  String Function() idGenerator, {
  CanvasPoint offset = const CanvasPoint(32, 32),
}) {
  final members = getGroupMembers(scene, groupId);
  if (members.isEmpty) return const [];
  final newGid =
      'grp_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(10000)}';
  return members.map((e) {
    final newId = idGenerator();
    return e.translated(offset).copy({'id': newId, 'groupId': newGid});
  }).toList();
}

/// Returns true if all members of [groupId] are contained within [selection].
bool isEntireGroupSelected(
  CanvasScene scene,
  String groupId,
  Set<String> selection,
) {
  final members = getGroupMembers(scene, groupId);
  if (members.isEmpty) return false;
  return members.every((m) => selection.contains(m.id));
}
