import 'object_reference.dart';
import 'research_workspace.dart';
import 'universal_object.dart';

const projectConnectionKinds = [
  'supports',
  'implements',
  'blocks',
  'verified by',
  'references',
  'part of',
  'depends on',
  'inspired by',
];

String? objectProject(UniversalObject object) {
  if (object.properties['isCourseOverview'] == true &&
      object.properties['courseId'] == object.id) {
    return object.id;
  }
  for (final key in ['project', 'courseId', 'course', 'context']) {
    final value = object.properties[key];
    if (value is String && value.trim().isNotEmpty) return value;
  }
  return object.properties['isCreativeBrief'] == true ? object.id : null;
}

/// Explicit authored relationships. Unknown records survive edits untouched.
class ProjectConnection {
  const ProjectConnection(this.raw);
  final Map<String, dynamic> raw;
  String get id => raw['id'] as String;
  String get kind => raw['kind'] as String;
  ObjectReference get target => ObjectReference.parse(raw['target'] as String);
  String get note => raw['note'] as String? ?? '';
  static bool supported(dynamic value) =>
      value == null ||
      value is Map &&
          value['version'] == 1 &&
          value['items'] is List &&
          (value['items'] as List).length <= 200;
  static List<ProjectConnection> read(dynamic value) =>
      supported(value) && value is Map
      ? (value['items'] as List)
            .whereType<Map>()
            .where(
              (r) =>
                  r['id'] is String &&
                  r['target'] is String &&
                  projectConnectionKinds.contains(r['kind']) &&
                  (r['note'] == null || r['note'] is String),
            )
            .map((r) => ProjectConnection(Map<String, dynamic>.from(r)))
            .toList()
      : const [];
  String? warning(UniversalObject? object) {
    if (object == null || object.isDeleted) return 'Source unavailable';
    if (raw['versionToken'] != researchVersion(object)) {
      return 'Source changed · review connection';
    }
    return null;
  }
}

/// Device-local context contains only IDs, positions and deliberate activity.
bool projectContextSupported(Map<String, dynamic> value) =>
    value.isEmpty ||
    value['version'] == 1 &&
        (value['selected'] == null || value['selected'] is String) &&
        (value['panel'] == null || value['panel'] is bool) &&
        (value['projects'] == null ||
            value['projects'] is Map &&
                (value['projects'] as Map).length <= 30 &&
                (value['projects'] as Map).entries.every(
                  (e) => e.key is String && e.value is Map,
                ));
