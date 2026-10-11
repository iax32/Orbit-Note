import 'universal_object.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

const decisionStates = ['Proposed', 'Accepted', 'Superseded', 'Rejected'];
const assumptionStates = ['Unverified', 'Confirmed', 'Disproved', 'Superseded'];
const researchLayouts = ['Gallery', 'Table', 'Compare', 'Decisions'];

String researchSourceType(UniversalObject? source) {
  if (source == null || source.isDeleted) return 'Missing';
  final mime = source.properties['mimeType']?.toString() ?? '';
  if (mime == 'application/pdf') return 'PDF';
  if (mime.startsWith('image/')) return 'Image';
  return source.typeId.replaceFirst('orbit.', '');
}

Map<String, dynamic> researchCheckpoint(UniversalObject object, String id) => {
  'id': id,
  'revision': object.revision,
  'timestamp': DateTime.now().toUtc().toIso8601String(),
  'title': object.title,
  'body': object.body,
  'wordCount': object.body.trim().isEmpty
      ? 0
      : object.body.trim().split(RegExp(r'\s+')).length,
  'label': '${object.properties['researchState'] ?? 'Record'} · before update',
  'researchFields': {
    for (final key in [
      'researchState',
      'confidence',
      'importance',
      'evidenceIds',
      'assumptionIds',
      'supersedesIds',
      'evidenceVersions',
    ])
      if (object.properties[key] != null) key: object.properties[key],
  },
};

List<String> researchIds(dynamic value) => value is List
    ? value.whereType<String>().where((s) => s.isNotEmpty).toSet().toList()
    : const [];

List<({String id, String relation})> researchRelations(
  UniversalObject object,
) => [
  if (isResearchRecord(object)) ...[
    for (final id in researchIds(object.properties['evidenceIds']))
      (id: id, relation: 'Supported by'),
    for (final id in researchIds(object.properties['assumptionIds']))
      (id: id, relation: 'Depends on assumption'),
    for (final id in researchIds(object.properties['supersedesIds']))
      (id: id, relation: 'Supersedes'),
  ],
  if (object.properties['viewType'] == 'research') ...[
    if (object.properties['referenceEntries'] is List)
      for (final entry in object.properties['referenceEntries'] as List)
        if (entry is Map && entry['objectId'] is String)
          (id: entry['objectId'] as String, relation: 'Collection reference'),
    if (object.properties['briefId'] is String)
      (id: object.properties['briefId'] as String, relation: 'Project brief'),
  ],
];

bool isResearchRecord(UniversalObject o) =>
    o.typeId == 'orbit.note' &&
    o.properties['researchVersion'] != null &&
    {'decision', 'assumption'}.contains(o.properties['researchKind']);

/// Explicit source versions, not inferred truth or background web monitoring.
final _researchVersions = Expando<String>();
String researchVersion(UniversalObject o) => _researchVersions[o] ??=
    '${o.revision}:${o.updatedAt.toUtc().toIso8601String()}:${o.properties['checksum'] ?? ''}:${sha256.convert(utf8.encode(jsonEncode([o.title, o.body, o.properties, o.data])))}';

Map<String, String> researchEvidenceVersions(
  Iterable<String> ids,
  Iterable<UniversalObject> objects,
) {
  final byId = {
    for (final o in objects)
      if (!o.isDeleted) o.id: o,
  };
  return {
    for (final id in ids)
      if (byId[id] != null) id: researchVersion(byId[id]!),
  };
}

List<String> researchReviewReasons(
  UniversalObject decision,
  Iterable<UniversalObject> objects,
) {
  if (decision.properties['researchKind'] != 'decision') return const [];
  final byId = {
    for (final o in objects)
      if (!o.isDeleted) o.id: o,
  };
  final versions = decision.properties['evidenceVersions'];
  final result = <String>[];
  for (final id in researchIds(decision.properties['evidenceIds'])) {
    final source = byId[id];
    if (source == null) {
      result.add('Missing evidence · $id');
    } else if (versions is! Map || versions[id] != researchVersion(source)) {
      result.add('Evidence changed · ${source.title}');
    }
  }
  for (final id in researchIds(decision.properties['assumptionIds'])) {
    final source = byId[id];
    if (source == null) {
      result.add('Missing assumption · $id');
    } else if (source.properties['researchState'] == 'Disproved' ||
        source.properties['researchState'] == 'Superseded') {
      result.add(
        '${source.properties['researchState']} assumption · ${source.title}',
      );
    } else if (versions is! Map || versions[id] != researchVersion(source)) {
      result.add('Assumption changed · ${source.title}');
    }
  }
  return result;
}

void validateResearchProperties(Map<String, dynamic> p) {
  if (p['viewType'] == 'research') {
    if (p['researchVersion'] != 1) {
      throw const FormatException('Unsupported research collection version.');
    }
    final entries = p['referenceEntries'];
    if (entries is! List ||
        entries.length > 5000 ||
        entries.any(
          (e) =>
              e is! Map ||
              e['objectId'] is! String ||
              (e['objectId'] as String).isEmpty,
        )) {
      throw const FormatException(
        'A collection supports up to 5,000 linked references.',
      );
    }
    if (!researchLayouts.contains(p['researchLayout'])) {
      throw const FormatException('Choose a supported research layout.');
    }
  }
  if (p['researchKind'] != null && p['researchVersion'] != null) {
    final kind = p['researchKind'];
    if (p['researchVersion'] != 1 ||
        !{'decision', 'assumption'}.contains(kind)) {
      throw const FormatException('Unsupported research record.');
    }
    if (!(kind == 'decision' ? decisionStates : assumptionStates).contains(
      p['researchState'],
    )) {
      throw const FormatException('Choose a supported record state.');
    }
    for (final key in ['evidenceIds', 'assumptionIds', 'supersedesIds']) {
      final raw = p[key];
      if (raw is! List ||
          raw.length > 100 ||
          raw.any((id) => id is! String || id.isEmpty)) {
        throw const FormatException(
          'A record supports up to 100 links of each kind.',
        );
      }
    }
    if (!{'Low', 'Medium', 'High', 'Unspecified'}.contains(p['confidence']) ||
        !{'Low', 'Medium', 'High', 'Unspecified'}.contains(p['importance'])) {
      throw const FormatException(
        'Choose a supported confidence or importance.',
      );
    }
  }
}
