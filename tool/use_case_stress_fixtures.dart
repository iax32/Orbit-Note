import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/canvas/uml_interaction.dart';

CanvasElement _case(String id, double x, double y, double w, double h) =>
    newInteractionNode(
      id,
      UmlNodeKind.useCase,
      CanvasPoint(x, y),
    ).copy({'width': w, 'height': h, 'text': 'Function $id'});

CanvasElement _link(
  String id,
  CanvasElement a,
  CanvasElement b, [
  UmlLinkKind kind = UmlLinkKind.association,
]) {
  final edge = CanvasElement({'id': id, 'type': 'connector'});
  return edge.copy(
    editInteractionLink(
      edge,
      [a, b],
      kind: kind,
      from: a.id,
      to: b.id,
      fromMultiplicity: kind == UmlLinkKind.association ? '1' : '',
    ),
  );
}

/// Synthetic narrow-gutter, central-actor coffee-machine topology; no Vault IDs.
Map<String, dynamic> coffeeMachineRoutingFixture() {
  final actor = newInteractionNode(
    'a',
    UmlNodeKind.actor,
    const CanvasPoint(350, 320),
  );
  final right = [
    _case('r0', 680, 380, 180, 84),
    _case('r1', 690, 280, 170, 90),
    _case('r2', 690, 190, 170, 80),
    _case('r3', 620, 480, 240, 62),
    _case('r4', 650, 550, 210, 56),
    _case('r5', 670, 620, 190, 80),
    _case('r6', 600, 710, 260, 88),
    _case('r7', 740, 810, 120, 64),
    _case('r8', 670, 890, 190, 70),
  ];
  final left = [
    _case('on', 180, 90, 140, 52),
    _case('off', 190, 170, 140, 60),
    _case('prepare', 200, 250, 130, 54),
    _case('profiles', 10, 430, 320, 120),
    _case('customize', 60, 310, 270, 115),
  ];
  final rinse = _case('rinse', 720, 75, 210, 60);
  return {
    'schemaVersion': 1,
    'elements': [
      actor.data,
      ...right.map((e) => e.data),
      ...left.map((e) => e.data),
      rinse.data,
      for (final c in [...right, ...left.skip(2)])
        _link('a-${c.id}', actor, c).data,
      _link('on-rinse', left[0], rinse, UmlLinkKind.include).data,
      _link('off-rinse', left[1], rinse, UmlLinkKind.extend).data,
      _link('descale-rinse', right[7], rinse, UmlLinkKind.include).data,
      _link('drain-rinse', right[8], rinse, UmlLinkKind.include).data,
    ],
  };
}

Map<String, dynamic> highDegreeRoutingFixture(
  int count, {
  bool bothSides = true,
}) {
  if (count < 1 || count > 128) throw ArgumentError.value(count, 'count');
  final rows = bothSides ? (count + 1) ~/ 2 : count;
  final actor = newInteractionNode(
    'a',
    UmlNodeKind.actor,
    CanvasPoint(470, rows * 90.0 - 80),
  );
  final cases = [
    for (var i = 0; i < count; i++)
      _case(
        'c$i',
        bothSides && i.isEven ? 0 : 1000,
        (bothSides ? i ~/ 2 : i) * 180.0,
        220,
        100,
      ),
  ];
  return {
    'schemaVersion': 1,
    'future': {'kept': true},
    'elements': [
      actor.data,
      ...cases.map((e) => e.data),
      for (final c in cases) _link('a-${c.id}', actor, c).data,
    ],
  };
}
