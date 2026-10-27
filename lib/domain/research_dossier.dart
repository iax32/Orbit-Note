import 'dart:convert';
import 'universal_object.dart';
import 'reverse_engineering.dart';
import 'linked_section.dart';
import 'object_reference.dart';
import 'research_workspace.dart';
import 'note_composition.dart';

const dossierKinds = [
  'dossier',
  'function',
  'structure',
  'offset',
  'hypothesis',
  'journal',
  'build',
  'glossary',
];
const dossierStates = ['suspected', 'testing', 'confirmed', 'disproved'];
const dossierRoles = [
  'evidence',
  'contradicts',
  'caller',
  'callee',
  'pointer',
  'field',
  'defines',
  'related',
];
const dossierColumns = {
  'structure': ['offset', 'name', 'type', 'size', 'explanation'],
  'function': ['address', 'instruction', 'explanation', 'branch'],
  'journal': ['step', 'input', 'observation', 'conclusion'],
};
const dossierTemplates = {
  'Entity structure':
      '## Object identity and lifetime\n\n## Fields and ownership\n\n## Creation / destruction observations\n\n## Evidence and alternative interpretations',
  'Inventory system':
      '## Item identity and containers\n\n## Capacity and stack rules\n\n## Persistence and serialization\n\n## Observations and open questions',
  'Coordinate transformations':
      '## Coordinate spaces, units and handedness\n\n## Vectors, matrices and conventions\n\n\$\$\np_{clip} = P V M p_{local}\n\$\$\n\n## Recorded examples\n\n## Validation and uncertainty',
  'Save-file format':
      '## Exact game build and sample provenance\n\n## Header, sections and field layout\n\n## Before / after observations\n\n## Checksums, compression and unknown fields\n\n## Conclusions and limitations',
  'Networking observations':
      '## Protocol and session context\n\n## Observed message structure\n\n## Sequence and timing\n\n## State transitions\n\n## Evidence and unresolved questions',
  'Engine architecture':
      '## Engine and exact build\n\n## Subsystems and ownership\n\n## Call relationships\n\n## Threading and lifecycle observations\n\n## Evidence and open questions',
  'Investigation log':
      '## Question\n\n## Hypothesis\n\n## Reproducible environment\n\n## Steps and controls\n\n## Observations\n\n## Alternative explanations\n\n## Conclusion and next investigation',
};

Map<String, dynamic> dossierData(UniversalObject o) =>
    o.properties['researchDossier'] is Map
    ? Map<String, dynamic>.from(o.properties['researchDossier'] as Map)
    : {};

void validateDossier(Map<String, dynamic> data) {
  if (data['version'] != 1 ||
      !dossierKinds.contains(data['kind']) ||
      !dossierStates.contains(data['state'])) {
    throw const FormatException(
      'Unsupported research dossier record or state. Original data is preserved.',
    );
  }
  for (final key in [
    'dossierId',
    'build',
    'summary',
    'symbol',
    'module',
    'moduleId',
    'address',
    'addressSpace',
    'convention',
    'prototype',
    'parameters',
    'returns',
    'aliases',
  ]) {
    if (data[key] != null &&
        (data[key] is! String || (data[key] as String).length > 10000)) {
      throw FormatException('Invalid or oversized $key.');
    }
  }
  if (data['kind'] != 'dossier' && '${data['dossierId'] ?? ''}'.isEmpty) {
    throw const FormatException('Choose a dossier.');
  }
  if (!['low', 'medium', 'high'].contains(data['confidence'])) {
    throw const FormatException('Choose a confidence level.');
  }
  if (data['address'] != null && data['address'] != '') {
    normalizeResearchAddress(data['address'] as String);
  }
  if (data['addressSpace'] != null &&
      !['virtual', 'rva', 'file', 'field'].contains(data['addressSpace'])) {
    throw const FormatException('Choose an address space.');
  }
  final rows = data['rows'] ?? const [];
  if (rows is! List || rows.length > 500) {
    throw const FormatException('Use up to 500 recorded rows.');
  }
  for (final row in rows) {
    if (row is! Map ||
        (dossierColumns[data['kind']] ?? const <String>[]).any(
          (key) =>
              row[key] != null &&
              (row[key] is! String || (row[key] as String).length > 10000),
        )) {
      throw const FormatException('Rows must contain bounded text.');
    }
    if (data['kind'] == 'structure') {
      final offset = normalizeResearchAddress('${row['offset'] ?? ''}');
      final rawSize = '${row['size'] ?? ''}';
      final size = BigInt.tryParse(rawSize);
      if (size == null ||
          size <= BigInt.zero ||
          size > BigInt.from(1048576) ||
          BigInt.parse(offset.substring(2), radix: 16) + size >
              (BigInt.one << 64)) {
        throw const FormatException(
          'Each structure field needs a hex offset and size in bytes (1–1048576).',
        );
      }
    }
  }
  final links = data['links'] ?? const [];
  if (links is! List || links.length > 200) {
    throw const FormatException('Use up to 200 linked records.');
  }
  for (final link in links) {
    if (link is! Map ||
        link['id'] is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(link['id']) ||
        !dossierRoles.contains(link['role']) ||
        link['offset'] != null &&
            (link['offset'] is! String ||
                (link['offset'] as String).length > 500) ||
        link['revision'] != null &&
            (link['revision'] is! int || link['revision'] < 1) ||
        link['sourceVersion'] != null &&
            (link['sourceVersion'] is! String ||
                (link['sourceVersion'] as String).length > 1000)) {
      throw const FormatException(
        'Choose valid linked evidence and relationship roles.',
      );
    }
  }
  if (data['history'] != null &&
      (data['history'] is! List || (data['history'] as List).length > 100)) {
    throw const FormatException('Invalid review history.');
  }
  if (jsonEncode(data).length > 200000) {
    throw const FormatException(
      'Research metadata exceeds 200,000 characters.',
    );
  }
}

final _dossierValidity = Expando<bool>('dossier validation');
bool isDossierRecord(UniversalObject o) {
  if (o.isDeleted || o.typeId != 'orbit.note') return false;
  return _dossierValidity[o] ??= _validDossier(o);
}

bool _validDossier(UniversalObject o) {
  try {
    validateDossier(dossierData(o));
    return true;
  } catch (_) {
    return false;
  }
}

List<Map<String, dynamic>> dossierRows(Map<String, dynamic> data, String key) =>
    [
      if (data[key] is List)
        for (final r in data[key] as List)
          if (r is Map) Map<String, dynamic>.from(r),
    ];

List<String> dossierWarnings(
  UniversalObject record,
  Iterable<UniversalObject> objects,
) {
  final data = dossierData(record), all = {for (final o in objects) o.id: o};
  final warnings = <String>[];
  final root = all[data['dossierId']];
  if (data['kind'] != 'dossier' && (root == null || root.isDeleted)) {
    warnings.add('Dossier is missing or in Trash.');
  }
  final currentBuild = root == null
      ? ''
      : '${dossierData(root)['build'] ?? ''}';
  if (currentBuild.isNotEmpty &&
      currentBuild != data['build'] &&
      !['dossier', 'build', 'glossary'].contains(data['kind'])) {
    warnings.add(
      'Needs rechecking for build $currentBuild; recorded build: ${data['build'] == '' ? 'unrecorded' : data['build']}.',
    );
  }
  for (final link in dossierRows(data, 'links')) {
    final target = all[link['id']];
    if (target == null || target.isDeleted) {
      warnings.add('Missing linked ${link['role']}: ${link['id']}');
    } else if (link['sourceVersion'] == null
        ? link['revision'] != target.revision
        : link['sourceVersion'] != researchVersion(target)) {
      warnings.add('Source changed: ${target.title}. Review its evidence.');
    }
  }
  if (data['kind'] == 'structure') {
    final rows = dossierRows(data, 'rows');
    final sorted = [...rows]
      ..sort(
        (a, b) =>
            BigInt.parse(
              normalizeResearchAddress(a['offset']).substring(2),
              radix: 16,
            ).compareTo(
              BigInt.parse(
                normalizeResearchAddress(b['offset']).substring(2),
                radix: 16,
              ),
            ),
      );
    BigInt end = BigInt.zero;
    for (final row in sorted) {
      final offset = BigInt.parse(
        normalizeResearchAddress(row['offset']).substring(2),
        radix: 16,
      );
      if (offset < end) {
        warnings.add(
          'Overlapping field ${row['name']} at ${row['offset']}; record a union/alias explanation if intentional.',
        );
      }
      final next = offset + BigInt.parse(row['size']);
      if (next > end) end = next;
    }
  }
  return warnings;
}

String _cell(Object? v) => '${v ?? ''}'
    .replaceAll('\\', '\\\\')
    .replaceAll('|', '\\|')
    .replaceAll('\r', ' ')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('\n', '<br>');
String _literal(Object? v) => '${v ?? ''}'
    .replaceAll(RegExp(r'[\r\n]'), ' ')
    .replaceAllMapped(RegExp(r'[\\`*_\[\]<>#]'), (m) => '\\${m[0]}');
const dossierStart = '<!-- orbit:dossier-summary:start -->';
const dossierEnd = '<!-- orbit:dossier-summary:end -->';

String dossierSummary(Map<String, dynamic> data) {
  validateDossier(data);
  final b = StringBuffer('## Research summary\n\n');
  b.writeln(
    '**${_literal(data['kind'])}** · ${_literal(data['state'])} · confidence: ${_literal(data['confidence'])} · build: ${_literal(data['build'] ?? 'unrecorded')}\n',
  );
  b.writeln('${data['summary'] ?? ''}\n');
  for (final key in [
    'symbol',
    'module',
    'addressSpace',
    'address',
    'convention',
    'prototype',
    'parameters',
    'returns',
    'aliases',
  ]) {
    if (data[key] != null && data[key] != '') {
      b.writeln('**$key:** ${_literal(data[key])}  ');
    }
  }
  final columns = dossierColumns[data['kind']];
  final rows = dossierRows(data, 'rows');
  if (columns != null && rows.isNotEmpty && data['kind'] != 'function') {
    b.writeln(
      '\n| ${columns.join(' | ')} |\n| ${columns.map((_) => '---').join(' | ')} |',
    );
    for (final row in rows) {
      b.writeln('| ${columns.map((c) => _cell(row[c])).join(' | ')} |');
    }
  }
  if (data['kind'] == 'function') {
    b.writeln('\n<!-- orbit:columns v=1 -->\n### Recorded instructions\n');
    final code = rows
        .map((r) => '${r['address'] ?? ''}  ${r['instruction'] ?? ''}')
        .join('\n');
    var fence = '```';
    while (code.contains(fence)) {
      fence += '`';
    }
    b.writeln(
      '${fence}asm\n$code\n$fence\n<!-- orbit:column -->\n### Interpretation\n',
    );
    for (final row in rows) {
      b.writeln(
        '- ${_literal(row['address'])}: ${_literal(row['explanation'])}${row['branch'] == '' || row['branch'] == null ? '' : ' · branch: ${_literal(row['branch'])}'}',
      );
    }
    b.writeln('<!-- /orbit:columns -->');
  }
  final links = dossierRows(data, 'links');
  if (links.isNotEmpty) {
    b.writeln('\n### Linked research\n');
    for (final link in links) {
      b.writeln(
        '- ${_literal(link['role'])}${link['offset'] == null || link['offset'] == '' ? '' : ' · ${_literal(link['offset'])}'}: ${ObjectReference(link['id']).markdown('${link['label'] ?? link['id']}')}',
      );
    }
  }
  if (data['kind'] != 'dossier') {
    b.writeln(
      '\nDossier: ${ObjectReference(data['dossierId']).markdown('${data['dossierTitle'] ?? data['dossierId']}')}',
    );
  }
  return b.toString();
}

String updateDossierBody(
  String original,
  Map<String, dynamic> data, {
  bool creating = false,
  String notes = '',
}) {
  final summary = '$dossierStart\n${dossierSummary(data)}$dossierEnd';
  if (creating) {
    return '$summary\n\n${notes.isEmpty ? '## Research notes\n\n## Evidence and open questions\n' : notes}\n';
  }
  final starts = <int>[], ends = <int>[];
  final fence = NoteLayoutFence();
  for (final line in RegExp(r'[^\n]*\n|[^\n]+$').allMatches(original)) {
    final text = line[0]!.replaceFirst(RegExp(r'\r?\n$'), '');
    if (!fence.outside(text)) continue;
    if (text == dossierStart) starts.add(line.start);
    if (text == dossierEnd) ends.add(line.start);
  }
  if (starts.length != 1 || ends.length != 1 || ends.single <= starts.single) {
    throw const FormatException(
      'The generated summary markers changed. Restore them from note history before using the structured editor; your note is preserved.',
    );
  }
  return original.replaceRange(
    starts.single,
    ends.single + dossierEnd.length,
    summary,
  );
}

String dossierLiveEmbed(UniversalObject record) => LinkedSection(
  ObjectReference(
    record.id,
    anchorType: 'heading',
    anchorId: 'Research summary',
  ),
  dossierSummary(dossierData(record)),
  section: true,
).encode();
