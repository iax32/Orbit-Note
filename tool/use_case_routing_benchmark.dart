import 'dart:convert';
import 'dart:io';

import 'package:orbit_note/canvas/connectors.dart';
import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/canvas/uml_interaction.dart';
import 'package:orbit_note/canvas/use_case_arrangement.dart';
import 'use_case_stress_fixtures.dart';

Map<String, dynamic> routingBenchmarkFixture() {
  CanvasElement node(
    String id,
    UmlNodeKind kind,
    double x,
    double y,
    String text,
  ) => newInteractionNode(id, kind, CanvasPoint(x, y)).copy({'text': text});
  final a = node('a', UmlNodeKind.actor, 30, 90, 'Lecturer');
  final b = node('b', UmlNodeKind.actor, 50, 400, 'Participant');
  final cases = [
    node('c0', UmlNodeKind.useCase, 300, 20, 'Reserve rooms'),
    node('c1', UmlNodeKind.useCase, 300, 185, 'Organize performance'),
    node('c2', UmlNodeKind.useCase, 300, 350, 'Borrow costumes'),
    node('c3', UmlNodeKind.useCase, 235, 530, 'Print scripts'),
    node('c4', UmlNodeKind.useCase, 690, 155, 'Organize props'),
    node('c5', UmlNodeKind.useCase, 690, 475, 'Rehearse play'),
  ];
  CanvasElement link(
    String id,
    CanvasElement from,
    CanvasElement to,
    String count, [
    UmlLinkKind kind = UmlLinkKind.association,
  ]) {
    final e = CanvasElement({'id': id, 'type': 'connector'});
    return e.copy(
      editInteractionLink(
        e,
        [from, to],
        kind: kind,
        from: from.id,
        to: to.id,
        fromMultiplicity: count,
      ),
    );
  }

  return {
    'schemaVersion': 1,
    'elements': [
      a.data,
      b.data,
      ...cases.map((e) => e.data),
      for (final i in [0, 1, 3, 4, 5])
        link('a-$i', a, cases[i], i >= 4 ? '1' : '').data,
      for (final i in [2, 3, 4, 5])
        link(
          'b-$i',
          b,
          cases[i],
          i == 4
              ? '2'
              : i == 5
              ? '2..*'
              : '0..1',
        ).data,
      link('include', cases[1], cases[4], '', UmlLinkKind.include).data,
      link('extend', cases[3], cases[5], '', UmlLinkKind.extend).data,
    ],
  };
}

Map<String, dynamic> routingSnapshot(CanvasScene scene) => {
  for (final edge in scene.elements.where(isConnectorElement))
    edge.id: () {
      final e = resolveConnectorEndpoints(edge, scene);
      return {
        'blocked': e.routeBlocked,
        'points': [
          e.start,
          ...e.controlPoints,
          e.end,
        ].map((p) => [p.x, p.y]).toList(),
        'labels': connectorEndLabels(edge, e)
            .map(
              (l) => {
                'text': l.text,
                'box': [
                  l.bounds.left,
                  l.bounds.top,
                  l.bounds.width,
                  l.bounds.height,
                ],
              },
            )
            .toList(),
      };
    }(),
};

void main(List<String> args) {
  String option(String key, String fallback) =>
      args
          .where((s) => s.startsWith('$key='))
          .map((s) => s.substring(key.length + 1))
          .firstOrNull ??
      fallback;
  final moves = int.parse(option('--moves', '4'));
  final output = option('--output', '.local/use-case-routing-benchmark.json');
  final fixturePath = option('--fixture', '');
  final stages = <String, dynamic>{};
  T measure<T>(String name, T Function() action) {
    final watch = Stopwatch()..start();
    final value = action();
    stages[name] = {'microseconds': watch.elapsedMicroseconds};
    stdout.writeln('$name: ${watch.elapsedMilliseconds} ms');
    return value;
  }

  final scene = measure(
    'cold_layout',
    () => CanvasScene.fromJson(
      fixturePath.isEmpty
          ? args.contains('--coffee')
                ? coffeeMachineRoutingFixture()
                : int.parse(option('--degree', '0')) > 0
                ? highDegreeRoutingFixture(
                    int.parse(option('--degree', '0')),
                    bothSides: !args.contains('--one-side'),
                  )
                : routingBenchmarkFixture()
          : jsonDecode(File(fixturePath).readAsStringSync())
                as Map<String, dynamic>,
    ),
  );
  if (args.contains('--organize')) {
    measure('organize_layout', () {
      final edits = organizeUseCases(scene);
      scene.batch(() {
        for (final e in edits) {
          scene.put(e);
        }
      });
    });
  }
  final actorId =
      scene['a']?.id ??
      scene.elements
          .where(
            (e) =>
                e.data['umlNode'] is Map &&
                (e.data['umlNode'] as Map)['kind'] == 'actor',
          )
          .firstOrNull
          ?.id ??
      scene.elements.firstWhere((e) => !isConnectorElement(e)).id;
  final initial = routingSnapshot(scene);
  measure('warm_120_queries', () {
    for (var i = 0; i < 120; i++) {
      scene.query(CanvasBounds(i.toDouble(), 0, 1000, 800));
      routingSnapshot(scene);
    }
  });
  measure(
    'appearance_only',
    () => scene.put(scene[actorId]!.copy({'color': 0xffabcdef})),
  );
  measure('stacking_only', () => scene.bringToFront(actorId));
  measure('stacking_read', () => routingSnapshot(scene));
  final moveTimes = <int>[];
  for (var i = 0; i < moves; i++) {
    final watch = Stopwatch()..start();
    scene.put(scene[actorId]!.translated(const CanvasPoint(2, 1)));
    routingSnapshot(scene);
    moveTimes.add(watch.elapsedMicroseconds);
    stdout.writeln('move $i: ${watch.elapsedMilliseconds} ms');
  }
  scene.beginInteractiveRouting();
  final dragTimes = <int>[];
  for (var i = 0; i < 24; i++) {
    final watch = Stopwatch()..start();
    scene.batch(() {
      scene.put(scene[actorId]!.translated(const CanvasPoint(1, .5)));
      for (final edge
          in scene.elements
              .where((e) => isConnectorElement(e) && e.startId == actorId)
              .toList()) {
        final p = resolveConnectorEndpoints(edge, scene);
        scene.put(edge.copy(connectorEndpointData(p.start, p.end)));
      }
    });
    routingSnapshot(scene);
    dragTimes.add(watch.elapsedMicroseconds);
  }
  measure('finish_drag', scene.finishInteractiveRouting);
  final ordered = [...dragTimes]..sort();
  stdout.writeln(
    '24 interactive moves: p50=${ordered[ordered.length ~/ 2]} us p95=${ordered[(ordered.length * .95).floor()]} us',
  );
  final report = {
    'synthetic': fixturePath.isEmpty,
    'anonymizedLayout': fixturePath.isNotEmpty,
    'platform': Platform.operatingSystem,
    'stages': stages,
    'moveMicroseconds': moveTimes,
    'interactiveMicroseconds': dragTimes,
    'initialRoutes': initial,
    'finalRoutes': routingSnapshot(scene),
  };
  final file = File(output);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
}
