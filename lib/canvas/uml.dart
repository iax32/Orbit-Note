import 'dart:math' as math;

import 'geometry.dart';
import 'connectors.dart';
import 'scene.dart';

/// UML is a presentation of ordinary shapes and connectors, not a second scene.
bool isUmlClass(CanvasElement element) =>
    element.type == 'rectangle' && element.data['uml'] is Map;

/// The same neutral Orbit surface treatment in native paint and vector export.
class UmlPalette {
  UmlPalette(int surface, {int? foreground}) {
    final light =
        (((surface >> 16) & 255) * .2126 +
            ((surface >> 8) & 255) * .7152 +
            (surface & 255) * .0722) >
        150;
    text = foreground ?? (light ? 0xff25232c : 0xffeceaf2);
    body = surface;
    header = blend(text, surface, .045);
    border = blend(text, surface, .26);
    divider = blend(text, surface, .16);
  }
  late final int text, body, header, border, divider;
  static int blend(int foreground, int background, double alpha) {
    int channel(int shift) =>
        ((((foreground >> shift) & 255) * alpha) +
                (((background >> shift) & 255) * (1 - alpha)))
            .round();
    return 0xff000000 | channel(16) << 16 | channel(8) << 8 | channel(0);
  }
}

class UmlClass {
  UmlClass(this.element);
  final CanvasElement element;
  Map get details =>
      element.data['uml'] is Map ? element.data['uml'] as Map : const {};
  String get name => element.text;
  String get stereotype =>
      details['stereotype'] is String ? details['stereotype'] as String : '';
  bool get abstractClass => details['abstract'] == true;
  List<String> _lines(String key) => details[key] is List
      ? List.unmodifiable((details[key] as List).whereType<String>())
      : const [];
  List<String> get attributes => _lines('attributes');
  List<String> get operations => _lines('operations');
  String get searchableText =>
      [name, stereotype, ...attributes, ...operations].join('\n');
  double get headerHeight => stereotype.isEmpty ? 48 : 68;
  double get attributeHeight =>
      math.max(40, attributes.length * 22 + 20).toDouble();
  double get naturalHeight =>
      headerHeight +
      attributeHeight +
      math.max(40, operations.length * 22 + 20);
  double get naturalWidth =>
      searchableText
              .split('\n')
              .fold<int>(0, (n, line) => math.max(n, line.length)) *
          8.5 +
      32;

  Map<String, dynamic> edit({
    required String name,
    required String attributes,
    required String operations,
    String stereotype = '',
    bool abstractClass = false,
  }) {
    if (name.trim().isEmpty) throw const FormatException('Enter a class name.');
    if (name.contains('\n') ||
        name.length > 120 ||
        stereotype.length > 80 ||
        attributes.length > 12000 ||
        operations.length > 12000) {
      throw const FormatException(
        'Use a single class name and shorter member lists.',
      );
    }
    List<String> lines(String text) => text
        .split(RegExp(r'\r\n|\r|\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return {
      'text': name.trim(),
      'uml': {
        ...details,
        'stereotype': stereotype.trim(),
        'abstract': abstractClass,
        'attributes': lines(attributes),
        'operations': lines(operations),
      },
    };
  }
}

enum UmlRelationship {
  association('Association', 'none', 'none', false),
  dependency('Dependency', 'none', 'arrow', true),
  generalization('Generalization', 'none', 'hollowTriangle', false),
  realization('Realization', 'none', 'hollowTriangle', true),
  aggregation('Aggregation', 'hollowDiamond', 'none', false),
  composition('Composition', 'filledDiamond', 'none', false);

  const UmlRelationship(
    this.label,
    this.startMarker,
    this.endMarker,
    this.dashed,
  );
  final String label, startMarker, endMarker;
  final bool dashed;
  Map<String, dynamic> get style => {
    'umlRelationship': name,
    'startMarker': startMarker,
    'endMarker': endMarker,
    'strokeStyle': dashed ? 'dashed' : 'solid',
    'routing': 'orthogonal',
  };
  static UmlRelationship parse(Object? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => association);
}

CanvasElement newUmlClass(
  String id,
  CanvasPoint at, {
  String name = 'ClassName',
  List<String> attributes = const [],
  List<String> operations = const [],
}) {
  var element = CanvasElement({
    'id': id,
    'type': 'rectangle',
    'x': at.x,
    'y': at.y,
    'width': 280.0,
    'height': 180.0,
    'color': 0xff8b7cf6,
    'strokeWidth': 1.5,
    'text': name,
    'uml': {'attributes': attributes, 'operations': operations},
  });
  final model = UmlClass(element);
  element = element.copy({
    'width': model.naturalWidth.clamp(280, 800).toDouble(),
    'height': model.naturalHeight,
  });
  return element;
}

/// Every insertion gets fresh placement IDs; relations follow the same shapes.
List<CanvasElement> umlExample(String Function() id, CanvasPoint at) {
  final doctor = newUmlClass(
    id(),
    at,
    name: 'Aerztin',
    attributes: ['name: String', 'spezialgebiete: String [1..*]'],
  );
  final protocol = newUmlClass(
    id(),
    at + const CanvasPoint(460, 0),
    name: 'Behandlungsprotokoll',
    attributes: [
      'untersuchungsfrequenz: String',
      'therapiedauer: int',
      'kontrollintervall: String',
    ],
  );
  final patient = newUmlClass(
    id(),
    at + const CanvasPoint(0, 300),
    name: 'Patient',
    attributes: ['name: String', 'svnr: String'],
  );
  final visit = newUmlClass(
    id(),
    at + const CanvasPoint(460, 300),
    name: 'Besuch',
    attributes: ['besuchsdatum: Date', 'dauer: int'],
  );
  CanvasElement edge(
    CanvasElement from,
    CanvasElement to,
    double startOffset,
    double endOffset,
  ) => CanvasElement({
    'id': id(),
    'type': 'connector',
    'startId': from.id,
    'endId': to.id,
    'startAnchor': 'right',
    'endAnchor': 'left',
    'startAnchorOffset': startOffset,
    'endAnchorOffset': endOffset,
    ...connectorEndpointData(
      CanvasPoint(from.bounds.right, from.y + from.height * startOffset),
      CanvasPoint(to.bounds.left, to.y + to.height * endOffset),
    ),
    'startMultiplicity': '1',
    'endMultiplicity': '0..*',
    'color': 0xffa6b0bf,
    'strokeWidth': 1.5,
    ...UmlRelationship.association.style,
  });
  return [
    doctor,
    protocol,
    patient,
    visit,
    edge(doctor, protocol, .35, .35),
    edge(doctor, visit, .75, .35).copy({'routingOffset': -24.0}),
    edge(patient, protocol, .35, .75).copy({'routingOffset': 24.0}),
    edge(patient, visit, .75, .75),
  ];
}
