import 'geometry.dart';
import 'scene.dart';

enum ResearchDiagramKind { memoryLayout, pointerChain, callFlow, evidence }

String researchDiagramTitle(ResearchDiagramKind kind) => switch (kind) {
  ResearchDiagramKind.memoryLayout => 'Memory layout',
  ResearchDiagramKind.pointerChain => 'Pointer chain',
  ResearchDiagramKind.callFlow => 'Call flow',
  ResearchDiagramKind.evidence => 'Evidence and validation',
};

/// Recorded examples only. Every result is an ordinary editable shared scene.
List<CanvasElement> researchDiagram(
  ResearchDiagramKind kind,
  String Function() id, {
  CanvasPoint at = const CanvasPoint(0, 0),
}) {
  final labels = switch (kind) {
    ResearchDiagramKind.memoryLayout => [
      'Module image\nBuild: [record exact version]\nBase: 0x140000000',
      'Player structure · example\n+0x00  id: uint32\n+0x04  health: float\n+0x08  position: vec3',
      'Field interpretation\nType and size are hypotheses\nCheck alignment and lifetime\nRecord confirming evidence',
    ],
    ResearchDiagramKind.pointerChain => [
      'Module + RVA\nExample: base + 0x1234\nRecord module and build',
      'Read pointer value\nExample offset: +0x20\nValue comes from recorded data',
      'Target structure\nExample field: +0x04\nRevalidate after a build change',
    ],
    ResearchDiagramKind.callFlow => [
      'Input / caller\nFunction: [symbol or RVA]\nArguments: [observed values]',
      'State update\nRead → transform → write\nRecord conditions and side effects',
      'Output / observer\nExpected: [result]\nObserved: [result]\nLink trace or test evidence',
    ],
    ResearchDiagramKind.evidence => [
      'Hypothesis\nWhat do you believe?\nConfidence: unverified',
      'Observation\nBuild, tool and exact location\nWhat did you actually measure?',
      'Validation\nReproduction steps and controls\nConfirmed / disproved / uncertain\nLink supporting sources',
    ],
  };
  final nodes = <CanvasElement>[
    for (var i = 0; i < labels.length; i++)
      CanvasElement({
        'id': id(),
        'type': 'rectangle',
        'text': labels[i],
        'x': at.x + i * 360,
        'y': at.y,
        'width': 300.0,
        'height': 190.0,
        'color': 0xff9b8cc4,
        'fontSize': 16.0,
        'researchDiagram': kind.name,
      }),
  ];
  return [
    ...nodes,
    for (var i = 0; i < nodes.length - 1; i++)
      CanvasElement({
        'id': id(),
        'type': 'arrow',
        'startId': nodes[i].id,
        'endId': nodes[i + 1].id,
        'x': at.x + i * 360 + 300,
        'y': at.y + 95,
        'width': 60.0,
        'height': 0.0,
        'color': 0xffa6a1b0,
        'endMarker': 'arrow',
        'researchDiagram': kind.name,
      }),
  ];
}

/// Unsigned arithmetic over recorded addresses, without inspecting a process.
class AddressCalculation {
  AddressCalculation(String base, String rva, {this.bits = 64}) {
    if (bits != 32 && bits != 64) {
      throw const FormatException('Choose 32 or 64 bits.');
    }
    BigInt parse(String value) {
      final clean = value.trim().replaceFirst(
        RegExp(r'^0x', caseSensitive: false),
        '',
      );
      if (!RegExp(r'^[0-9a-fA-F]{1,16}$').hasMatch(clean)) {
        throw const FormatException('Use unsigned hexadecimal addresses.');
      }
      return BigInt.parse(clean, radix: 16);
    }

    this.base = parse(base);
    this.rva = parse(rva);
    address = this.base + this.rva;
    if (address >= (BigInt.one << bits)) {
      throw const FormatException('Address exceeds the selected width.');
    }
  }
  final int bits;
  late final BigInt base, rva, address;
  String get hex =>
      '0x${address.toRadixString(16).toUpperCase().padLeft(bits ~/ 4, '0')}';
  String get littleEndian => [
    for (var i = 0; i < bits ~/ 8; i++)
      ((address >> (i * 8)) & BigInt.from(255))
          .toRadixString(16)
          .toUpperCase()
          .padLeft(2, '0'),
  ].join(' ');
  String get markdown =>
      '| Base | RVA | Virtual address | Width |\n| --- | --- | --- | --- |\n| 0x${base.toRadixString(16)} | 0x${rva.toRadixString(16)} | $hex | $bits-bit |\n\nLittle-endian address bytes: `$littleEndian`.\n\nRecorded address arithmetic only; this does not resolve a pointer or read memory.';
}
