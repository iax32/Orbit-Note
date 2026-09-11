import 'dart:math' as math;
import 'scene.dart';

/// Columns own placement geometry only, never the referenced knowledge object.
List<CanvasElement> columnMembers(CanvasScene scene, String columnId) => scene
    .elements
    .where((e) => e.data['columnId'] == columnId && e.type != 'column')
    .toList();

List<CanvasElement> arrangeColumn(
  CanvasElement column,
  Iterable<CanvasElement> children,
) {
  final members =
      children.where((e) => e.renderable && e.type != 'column').toList()
        ..sort((a, b) {
          final order = a.y.compareTo(b.y);
          return order == 0 ? a.x.compareTo(b.x) : order;
        });
  if (column.locked || members.any((e) => e.locked)) {
    return const [];
  }
  final width = math.max(
    260.0,
    members.fold<double>(0, (w, e) => math.max(w, e.width)) + 32,
  );
  var y = column.y + 54;
  final arranged = <CanvasElement>[];
  for (final member in members) {
    arranged.add(
      member.copy({'x': column.x + 16, 'y': y, 'columnId': column.id}),
    );
    y += member.height + 16;
  }
  return [
    column.copy({'width': width, 'height': math.max(150.0, y - column.y)}),
    ...arranged,
  ];
}
