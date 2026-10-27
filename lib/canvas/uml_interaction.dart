import 'dart:math' as math;

import 'geometry.dart';
import 'scene.dart';

/// UML notation on existing placements. Unknown fields remain owned by the scene.
enum UmlNodeKind {
  actor('Actor', 'rectangle', 120, 160),
  useCase('Use case', 'ellipse', 240, 120),
  system('System boundary', 'rectangle', 720, 520),
  note('UML note / constraint', 'rectangle', 260, 140),
  lifeline('Lifeline', 'rectangle', 160, 640),
  activation('Activation', 'rectangle', 18, 140),
  fragment('Combined fragment', 'rectangle', 620, 300);

  const UmlNodeKind(this.label, this.shape, this.width, this.height);
  final String label, shape;
  final double width, height;
}

UmlNodeKind? umlNodeKind(CanvasElement e) {
  final raw = e.data['umlNode'];
  if (raw is! Map) return null;
  return UmlNodeKind.values.where((v) => v.name == raw['kind']).firstOrNull;
}

bool isInteractionNode(CanvasElement e) => umlNodeKind(e) != null;
bool isInteractionItem(CanvasElement e) =>
    isInteractionNode(e) || e.data['umlLink'] is Map;

const umlFragmentOperators = [
  'alt',
  'opt',
  'loop',
  'par',
  'critical',
  'strict',
  'seq',
  'break',
  'assert',
  'neg',
  'ignore',
  'consider',
];

Map umlNodeDetails(CanvasElement e) =>
    e.data['umlNode'] is Map ? e.data['umlNode'] as Map : const {};

List<String> umlNodeLines(CanvasElement e) =>
    (umlNodeDetails(e)['lines'] is List
            ? umlNodeDetails(e)['lines'] as List
            : const [])
        .whereType<String>()
        .take(16)
        .toList();

String interactionSearchText(CanvasElement e) => [
  e.text,
  if (umlNodeKind(e) case final kind?) kind.label,
  if (umlNodeDetails(e)['stereotype'] case final String value) value,
  if (umlNodeDetails(e)['operator'] case final String value) value,
  ...umlNodeLines(e),
].join('\n');

String interactionLinkDescription(CanvasElement e, CanvasScene scene) => [
  '${scene[e.startId ?? '']?.text ?? 'Missing source'} → ${scene[e.endId ?? '']?.text ?? 'Missing target'}',
  '${umlLinkKind(e)?.label ?? 'Relationship'}${e.text.isEmpty ? '' : ': ${e.text}'}',
  for (final end in ['start', 'end'])
    if (e.data['${end}Multiplicity'] is String &&
        (e.data['${end}Multiplicity'] as String).isNotEmpty)
      '${end == 'start' ? 'From' : 'To'} multiplicity: ${e.data['${end}Multiplicity']}',
].join('\n');

CanvasElement newInteractionNode(String id, UmlNodeKind kind, CanvasPoint at) =>
    CanvasElement({
      'id': id,
      'type': kind.shape,
      'x': at.x,
      'y': at.y,
      'width': kind.width,
      'height': kind.height,
      'strokeWidth': 1.5,
      'text': switch (kind) {
        UmlNodeKind.lifeline => 'instance:Class',
        UmlNodeKind.activation => '',
        UmlNodeKind.fragment => '',
        _ => kind.label,
      },
      'umlNode': {
        'kind': kind.name,
        if (kind == UmlNodeKind.fragment) ...{
          'operator': 'alt',
          'lines': ['[condition]', '[else]'],
        },
      },
    });

Map<String, dynamic> editInteractionNode(
  CanvasElement e, {
  required String name,
  String stereotype = '',
  String lines = '',
  String operator = 'alt',
  bool destroyed = false,
}) {
  final kind = umlNodeKind(e);
  if (kind == null) throw const FormatException('Unsupported UML item.');
  if (name.trim().isEmpty &&
      kind != UmlNodeKind.activation &&
      kind != UmlNodeKind.fragment) {
    throw const FormatException('Enter a name or note.');
  }
  if (name.length > 1200 || stereotype.length > 80 || lines.length > 2400) {
    throw const FormatException('Use a shorter name, note or guard list.');
  }
  if (kind != UmlNodeKind.note && name.length > 160) {
    throw const FormatException('Keep diagram names under 160 characters.');
  }
  final rows = lines
      .split(RegExp(r'\r\n|\r|\n'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (rows.length > 16 || rows.any((s) => s.length > 160)) {
    throw const FormatException(
      'Use up to 16 lines, each at most 160 characters.',
    );
  }
  if (!umlFragmentOperators.contains(operator)) {
    throw const FormatException('Choose a supported UML fragment operator.');
  }
  final patch = <String, dynamic>{
    'text': name.trim(),
    'umlNode': {
      ...umlNodeDetails(e),
      'kind': kind.name,
      'stereotype': stereotype.trim(),
      'lines': rows,
      'operator': operator,
      'destroyed': destroyed,
    },
  };
  final wide = math
      .max(e.width, name.runes.length * 8.0 + (stereotype.isEmpty ? 24 : 40))
      .clamp(e.width, math.max(e.width, 480))
      .toDouble();
  if ([
    UmlNodeKind.actor,
    UmlNodeKind.useCase,
    UmlNodeKind.lifeline,
  ].contains(kind)) {
    patch['width'] = wide;
  }
  // Do not shrink manually enlarged geometry. Text uses shared wrapping below.
  if (kind == UmlNodeKind.useCase) {
    final nameRows =
        wrapUmlText(name, wide * .7, 14).length + (stereotype.isEmpty ? 0 : 1);
    patch['height'] = math.max(
      e.height,
      math.max(
        nameRows * 18.0 / (rows.isEmpty ? .65 : .28),
        120 + rows.length * 60.0,
      ),
    );
  } else if (kind == UmlNodeKind.actor) {
    patch['height'] = math.max(
      e.height,
      112 +
          wrapUmlText(name, wide - 8, 14).length * 18.0 +
          (stereotype.isEmpty ? 0 : 18),
    );
  } else if (kind == UmlNodeKind.fragment) {
    patch['height'] = math.max(e.height, 60 + rows.length * 60.0);
  } else if (kind == UmlNodeKind.note) {
    patch['height'] = math.max(
      e.height,
      40 + wrapUmlText(name, e.width - 36, 14).length * 19.0,
    );
  }
  return patch;
}

enum UmlLinkKind {
  association('Association', 'none', false),
  include('Include', 'arrow', true),
  extend('Extend', 'arrow', true),
  generalization('Generalization', 'hollowTriangle', false),
  constraint('Note / constraint link', 'none', true),
  synchronous('Synchronous call', 'filledTriangle', false),
  asynchronous('Asynchronous message', 'arrow', false),
  reply('Return message', 'arrow', true),
  create('Create message', 'arrow', true),
  destroy('Destroy message', 'filledTriangle', false);

  const UmlLinkKind(this.label, this.marker, this.dashed);
  final String label, marker;
  final bool dashed;
  bool get sequence => index >= synchronous.index;
  String get guidance => switch (this) {
    include => 'From the calling use case → the required included use case.',
    extend =>
      'From the optional extension → the base use case. Add a guard or extension point below.',
    generalization =>
      'From the specialized actor/use case → its general parent. The triangle points to the parent.',
    association =>
      'Connect an actor and a use case. Endpoint multiplicities describe participation (for example 1 and 2).',
    constraint => 'Connect a note/constraint to the item it describes.',
    create =>
      'Points to the new participant header. Move that lifeline down to its creation time.',
    destroy =>
      'Points to the end of the target lifeline. Enable its destruction marker.',
    _ =>
      'From sender → receiver. A self-call returns lower on the same lifeline.',
  };
}

UmlLinkKind? umlLinkKind(CanvasElement e) {
  final raw = e.data['umlLink'];
  return raw is Map
      ? UmlLinkKind.values.where((v) => v.name == raw['kind']).firstOrNull
      : null;
}

Map<String, dynamic> editInteractionLink(
  CanvasElement e,
  List<CanvasElement> nodes, {
  required UmlLinkKind kind,
  required String from,
  required String to,
  String label = '',
  String detail = '',
  String fromMultiplicity = '',
  String toMultiplicity = '',
  double position = .3,
}) {
  final a = nodes.where((n) => n.id == from && !n.hidden).firstOrNull;
  final b = nodes.where((n) => n.id == to && !n.hidden).firstOrNull;
  if (a == null || b == null) {
    throw const FormatException('Choose both endpoints.');
  }
  final ak = umlNodeKind(a), bk = umlNodeKind(b);
  if (!position.isFinite || position < .12 || position > .9) {
    throw const FormatException(
      'Choose a message position between 12% and 90%.',
    );
  }
  final valid = kind.sequence
      ? ak == UmlNodeKind.lifeline &&
            bk == UmlNodeKind.lifeline &&
            (from != to ||
                ![UmlLinkKind.create, UmlLinkKind.destroy].contains(kind))
      : from != to &&
            switch (kind) {
              UmlLinkKind.association => {
                ak,
                bk,
              }.containsAll({UmlNodeKind.actor, UmlNodeKind.useCase}),
              UmlLinkKind.include || UmlLinkKind.extend =>
                ak == UmlNodeKind.useCase && bk == UmlNodeKind.useCase,
              UmlLinkKind.generalization =>
                ak == bk &&
                    [UmlNodeKind.actor, UmlNodeKind.useCase].contains(ak),
              UmlLinkKind.constraint =>
                ak == UmlNodeKind.note || bk == UmlNodeKind.note,
              _ => false,
            };
  if (!valid) {
    throw FormatException(
      'Invalid endpoints for ${kind.label}. ${kind.guidance}',
    );
  }
  if ([
    label,
    detail,
    fromMultiplicity,
    toMultiplicity,
  ].any((s) => s.length > 160 || s.contains('\n') || s.contains('\r'))) {
    throw const FormatException(
      'Keep each label on one line, at most 160 characters.',
    );
  }
  final text = switch (kind) {
    UmlLinkKind.include || UmlLinkKind.extend =>
      '«${kind.name}»${detail.trim().isEmpty ? '' : '\n${detail.trim()}'}',
    UmlLinkKind.create => label.trim().isEmpty ? '«create»' : label.trim(),
    _ => label.trim(),
  };
  final retainGeometry =
      e.startId == from && e.endId == to && umlLinkKind(e) == kind;
  return {
    'umlLink': {
      ...(e.data['umlLink'] is Map ? e.data['umlLink'] as Map : const {}),
      'kind': kind.name,
      'label': label.trim(),
      'detail': detail.trim(),
      'position': position,
    },
    'text': text,
    'startId': from,
    'endId': to,
    'startMarker': 'none',
    'endMarker': kind.marker,
    'strokeStyle': kind.dashed ? 'dashed' : 'solid',
    'routing': retainGeometry
        ? e.routing
        : kind.sequence && from == to
        ? 'orthogonal'
        : 'straight',
    'startAnchor': retainGeometry ? e.startAnchor : 'auto',
    'endAnchor': retainGeometry ? e.endAnchor : 'auto',
    'startAnchorOffset': retainGeometry ? e.data['startAnchorOffset'] : .5,
    'endAnchorOffset': retainGeometry ? e.data['endAnchorOffset'] : .5,
    'startMultiplicity': fromMultiplicity.trim(),
    'endMultiplicity': toMultiplicity.trim(),
  };
}

/// Lightweight shared vector layout for native Canvas, note previews and SVG.
/// No font rasterization or separate diagram engine is introduced.
class UmlGlyph {
  final solidOvals = <CanvasBounds>[];
  final solidBoxes = <CanvasBounds>[];
  final boxes = <({CanvasBounds bounds, bool fill})>[];
  final ovals = <({CanvasBounds bounds, bool fill})>[];
  final paths = <({List<CanvasPoint> points, bool dashed})>[];
  final texts =
      <
        ({
          String text,
          CanvasBounds bounds,
          double size,
          bool bold,
          bool center,
        })
      >[];
}

List<String> wrapUmlText(String text, double width, double size) {
  final limit = math.max(1, (width / (size * .62)).floor());
  final result = <String>[];
  for (final line in text.split(RegExp(r'\r\n|\r|\n'))) {
    var current = <int>[];
    for (final word in line.split(' ')) {
      final runes = word.runes.toList();
      if (current.isNotEmpty && current.length + 1 + runes.length > limit) {
        result.add(String.fromCharCodes(current));
        current = [];
      }
      if (current.isNotEmpty) current.add(32);
      for (final rune in runes) {
        if (current.length >= limit) {
          result.add(String.fromCharCodes(current));
          current = [];
        }
        current.add(rune);
      }
    }
    result.add(String.fromCharCodes(current));
  }
  return result;
}

UmlGlyph interactionGlyph(CanvasElement e) {
  final g = UmlGlyph(), b = e.bounds;
  final x = b.left, y = b.top, w = b.width, h = b.height;
  void path(List<CanvasPoint> p, {bool dashed = false}) =>
      g.paths.add((points: p, dashed: dashed));
  CanvasPoint p(double dx, double dy) => CanvasPoint(x + dx, y + dy);
  void text(
    String s,
    CanvasBounds r, {
    double size = 14,
    bool bold = false,
    bool center = true,
  }) {
    if (s.isNotEmpty) {
      g.texts.add((text: s, bounds: r, size: size, bold: bold, center: center));
    }
  }

  final stereotype = umlNodeDetails(e)['stereotype'];
  final name = stereotype is String && stereotype.isNotEmpty
      ? '«$stereotype»\n${e.text}'
      : e.text;
  switch (umlNodeKind(e)) {
    case UmlNodeKind.actor:
      final cx = w / 2, figure = math.min(94.0, h * .62), r = figure * .12;
      g.ovals.add((
        bounds: CanvasBounds(x + cx - r, y + 4, r * 2, r * 2),
        fill: false,
      ));
      path([p(cx, 4 + r * 2), p(cx, figure * .63)]);
      path([
        p(cx - figure * .29, figure * .40),
        p(cx + figure * .29, figure * .40),
      ]);
      path([
        p(cx - figure * .26, figure),
        p(cx, figure * .63),
        p(cx + figure * .26, figure),
      ]);
      text(
        name,
        CanvasBounds(x + 4, y + figure + 10, w - 8, h - figure - 12),
        bold: true,
      );
    case UmlNodeKind.useCase:
      g.ovals.add((bounds: b, fill: true));
      final lines = umlNodeLines(e);
      final inset = w * .15;
      final top = y + h * .16;
      text(
        name,
        CanvasBounds(
          x + inset,
          top,
          w - inset * 2,
          lines.isEmpty ? h * .68 : h * .28,
        ),
        bold: true,
      );
      if (lines.isNotEmpty) {
        path([p(inset, h * .46), p(w - inset, h * .46)]);
        text(
          'extension points\n${lines.join('\n')}',
          CanvasBounds(x + inset, y + h * .48, w - inset * 2, h * .36),
          size: 12,
          center: false,
        );
      }
    case UmlNodeKind.system:
      g.boxes.add((bounds: b, fill: false));
      text(
        name,
        CanvasBounds(x + 16, y + 12, w - 32, 44),
        bold: true,
        center: false,
      );
    case UmlNodeKind.note:
      path([p(0, 0), p(w - 18, 0), p(w, 18), p(w, h), p(0, h), p(0, 0)]);
      path([p(w - 18, 0), p(w - 18, 18), p(w, 18)]);
      text(name, b.deflate(16), center: false);
    case UmlNodeKind.lifeline:
      final header = math.min(64.0, h * .25);
      g.boxes.add((bounds: CanvasBounds(x, y, w, header), fill: true));
      text(name, CanvasBounds(x + 8, y + 8, w - 16, header - 16), bold: true);
      path([p(w / 2, header), p(w / 2, h)], dashed: true);
      if (umlNodeDetails(e)['destroyed'] == true) {
        path([p(w / 2 - 10, h - 10), p(w / 2 + 10, h + 0)]);
        path([p(w / 2 + 10, h - 10), p(w / 2 - 10, h + 0)]);
      }
    case UmlNodeKind.activation:
      g.boxes.add((bounds: b, fill: true));
    case UmlNodeKind.fragment:
      g.boxes.add((bounds: b, fill: false));
      final op = umlNodeDetails(e)['operator'];
      final operator = op is String ? op : 'alt';
      final tabWidth = math
          .max(72.0, operator.length * 9.0 + 24)
          .clamp(1, math.max(1, w))
          .toDouble();
      path([p(0, 32), p(tabWidth - 12, 32), p(tabWidth, 20), p(tabWidth, 0)]);
      text(
        operator,
        CanvasBounds(x + 8, y + 6, tabWidth - 16, 22),
        bold: true,
        center: false,
      );
      text(
        e.text,
        CanvasBounds(
          x + tabWidth + 8,
          y + 6,
          math.max(1, w - tabWidth - 16),
          22,
        ),
        center: false,
      );
      final guards = umlNodeLines(e);
      for (var i = 0; i < guards.length; i++) {
        final top = 40 + i * (h - 40) / guards.length;
        if (i > 0) path([p(0, top - 6), p(w, top - 6)], dashed: true);
        text(
          guards[i],
          CanvasBounds(x + 12, y + top, w - 24, 36),
          size: 12,
          center: false,
        );
      }
    case null:
      break;
  }
  return g;
}

List<CanvasElement> useCaseStarter(String Function() id, CanvasPoint at) {
  CanvasElement node(UmlNodeKind kind, double x, double y, String name) =>
      newInteractionNode(
        id(),
        kind,
        at + CanvasPoint(x, y),
      ).copy({'text': name});
  final system = node(UmlNodeKind.system, 180, 0, 'System');
  final actor = node(UmlNodeKind.actor, 0, 150, 'User');
  final main = node(UmlNodeKind.useCase, 260, 90, 'Complete a goal');
  final required = node(UmlNodeKind.useCase, 600, 90, 'Required step');
  final optional = node(UmlNodeKind.useCase, 430, 330, 'Optional step');
  final nodes = [system, actor, main, required, optional];
  CanvasElement link(UmlLinkKind kind, CanvasElement a, CanvasElement b) {
    final e = CanvasElement({
      'id': id(),
      'type': 'connector',
      'strokeWidth': 1.5,
    });
    return e.copy(
      editInteractionLink(e, nodes, kind: kind, from: a.id, to: b.id),
    );
  }

  return [
    ...nodes,
    link(UmlLinkKind.association, actor, main),
    link(UmlLinkKind.include, main, required),
    link(UmlLinkKind.extend, optional, main),
  ];
}

List<CanvasElement> sequenceStarter(String Function() id, CanvasPoint at) {
  final a = newInteractionNode(
    id(),
    UmlNodeKind.lifeline,
    at,
  ).copy({'text': 'client:Client'});
  final b = newInteractionNode(
    id(),
    UmlNodeKind.lifeline,
    at + const CanvasPoint(400, 0),
  ).copy({'text': 'service:Service'});
  final nodes = [a, b];
  CanvasElement link(
    UmlLinkKind kind,
    CanvasElement from,
    CanvasElement to,
    double pos,
    String label,
  ) {
    final e = CanvasElement({
      'id': id(),
      'type': 'connector',
      'strokeWidth': 1.5,
    });
    return e.copy(
      editInteractionLink(
        e,
        nodes,
        kind: kind,
        from: from.id,
        to: to.id,
        position: pos,
        label: label,
      ),
    );
  }

  return [
    ...nodes,
    link(UmlLinkKind.synchronous, a, b, .24, 'request()'),
    link(UmlLinkKind.synchronous, b, b, .40, 'validate()'),
    link(UmlLinkKind.reply, b, a, .65, 'result'),
  ];
}
