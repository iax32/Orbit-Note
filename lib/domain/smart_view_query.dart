import 'course_progress.dart';
import 'universal_object.dart';
import 'calendar_event.dart';

/// Versioned, bounded data queries; no SQL, scripts or copied content.
class SmartViewQuery {
  SmartViewQuery(this.json) {
    if (json['version'] != 1 || !{'all', 'any'}.contains(json['match'])) {
      throw const FormatException(
        'Unsupported Smart View query version or mode.',
      );
    }
    final rules = json['rules'];
    if (rules is! List || rules.length > 32) {
      throw const FormatException('A query supports up to 32 filters.');
    }
    for (final rule in rules) {
      if (rule is! Map ||
          !validField(rule['field']) ||
          !operators.contains(rule['op']) ||
          (rule['value'] != null &&
              rule['value'] is! String &&
              rule['value'] is! num &&
              rule['value'] is! bool) ||
          rule['value'] is num && !(rule['value'] as num).isFinite ||
          '${rule['value'] ?? ''}'.length > 2000) {
        throw const FormatException('Unsupported query filter.');
      }
      if ({'before', 'after', 'on'}.contains(rule['op']) &&
          !{'today', 'tomorrow', 'week-end'}.contains(rule['value']) &&
          parseCalendarDate(rule['value']) == null) {
        throw const FormatException(
          'Date filters need YYYY-MM-DD or a relative date.',
        );
      }
      if ({'gte', 'lte'}.contains(rule['op']) &&
          num.tryParse('${rule['value']}')?.isFinite != true) {
        throw const FormatException('Number filters need a finite number.');
      }
    }
    if (!validField(json['sort'] ?? 'updatedAt') ||
        (json['descending'] != null && json['descending'] is! bool) ||
        (json['group'] != null && !validField(json['group']))) {
      throw const FormatException('Unsupported query sorting or grouping.');
    }
    final columns = json['columns'];
    if (columns != null &&
        (columns is! List ||
            columns.isEmpty ||
            columns.length > 20 ||
            !columns.every(validField))) {
      throw const FormatException(
        'Choose between 1 and 20 supported table columns.',
      );
    }
  }
  final Map<String, dynamic> json;
  static const operators = [
    'equals',
    'notEquals',
    'contains',
    'empty',
    'notEmpty',
    'before',
    'after',
    'on',
    'gte',
    'lte',
  ];
  static bool validField(Object? field) =>
      field is String &&
      RegExp(r'^[a-zA-Z][a-zA-Z0-9_.:]{0,79}$').hasMatch(field);
  static Map<String, dynamic> empty() => {
    'version': 1,
    'match': 'all',
    'rules': <dynamic>[],
    'sort': 'updatedAt',
    'descending': true,
  };
  static Object? value(UniversalObject object, String field) => switch (field) {
    'title' => object.title,
    'typeId' => object.typeId,
    'createdAt' => object.createdAt.toIso8601String(),
    'updatedAt' => object.updatedAt.toIso8601String(),
    'completed' => object.isCompleted,
    _ =>
      object.properties[field.startsWith('relation:')
          ? field.substring(9)
          : field],
  };
  bool matches(UniversalObject object, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    bool test(dynamic raw) {
      final r = raw as Map;
      final field = r['field'] as String;
      final actual = value(object, field);
      final expected = r['value'];
      final text = '${actual ?? ''}'.toLowerCase();
      final needle = '${expected ?? ''}'.toLowerCase();
      bool equal(Object? v) => v is num && expected is num
          ? v == expected
          : '${v ?? ''}'.toLowerCase() == needle;
      DateTime? date(Object? v) => v is String
          ? (v.length == 10 ? parseCalendarDate(v) : DateTime.tryParse(v))
          : null;
      final boundary = switch (expected) {
        'today' => DateTime(clock.year, clock.month, clock.day),
        'tomorrow' => DateTime(clock.year, clock.month, clock.day + 1),
        'week-end' => DateTime(
          clock.year,
          clock.month,
          clock.day + 7 - clock.weekday,
        ),
        _ => date(expected),
      };
      final d = date(actual);
      final civil = d == null ? null : DateTime(d.year, d.month, d.day);
      final n = actual is num ? actual : num.tryParse('$actual');
      final compare = num.tryParse('$expected');
      return switch (r['op']) {
        'empty' =>
          actual == null || actual == '' || actual is List && actual.isEmpty,
        'notEmpty' =>
          actual != null && actual != '' && !(actual is List && actual.isEmpty),
        'equals' =>
          actual is List ? actual.any(equal) : actual != null && equal(actual),
        'notEquals' =>
          actual == null ||
              !(actual is List ? actual.any(equal) : equal(actual)),
        'contains' =>
          actual is List
              ? actual.any(equal)
              : actual != null && text.contains(needle),
        'before' =>
          civil != null && boundary != null && civil.isBefore(boundary),
        'after' => civil != null && boundary != null && civil.isAfter(boundary),
        'on' => civil != null && boundary != null && civil == boundary,
        'gte' => n != null && n.isFinite && compare != null && n >= compare,
        'lte' => n != null && n.isFinite && compare != null && n <= compare,
        _ => false,
      };
    }

    final rules = json['rules'] as List;
    return rules.isEmpty ||
        (json['match'] == 'any' ? rules.any(test) : rules.every(test));
  }

  List<UniversalObject> evaluate(
    Iterable<UniversalObject> objects, {
    DateTime? now,
  }) {
    final result = objects
        .where((o) => !o.isDeleted && matches(o, now: now))
        .toList();
    final field = json['sort'] as String? ?? 'updatedAt';
    result.sort((a, b) {
      final av = value(a, field), bv = value(b, field);
      if (av == null && bv != null) return 1;
      if (bv == null && av != null) return -1;
      final cmp = av is num && bv is num
          ? av.compareTo(bv)
          : '${av ?? ''}'.toLowerCase().compareTo('${bv ?? ''}'.toLowerCase());
      return cmp == 0
          ? a.id.compareTo(b.id)
          : json['descending'] == true
          ? -cmp
          : cmp;
    });
    return result;
  }
}

/// Legacy collection membership/scope stays unchanged; the query refines it.
List<UniversalObject> resolveSmartView(
  UniversalObject view,
  Iterable<UniversalObject> objects, {
  String? Function(String)? pathFor,
  DateTime? now,
}) {
  final p = view.properties;
  final members = p['memberIds'];
  if (members != null && members is! List) {
    throw const FormatException(
      'Unsupported collection membership. Its definition is preserved.',
    );
  }
  final memberIds = members is List
      ? members.whereType<String>().toSet()
      : null;
  final manual = p['manual'] == true || memberIds != null;
  final folder = p['folder'];
  final scope = p['scope'];
  if (folder != null && folder is! String ||
      scope != null && scope is! String) {
    throw const FormatException(
      'Unsupported collection scope. Its definition is preserved.',
    );
  }
  final courseId = p['courseId'];
  final course = courseId is String
      ? objects.where((o) => o.id == courseId && !o.isDeleted).firstOrNull
      : null;
  final candidates = objects.where((o) {
    if (o.isDeleted || o.typeId == 'orbit.view') return false;
    if (manual) return memberIds?.contains(o.id) ?? false;
    if (courseId is String && courseId.isNotEmpty) {
      return course != null && belongsToCourse(o, course);
    }
    if (folder is String && folder.isNotEmpty) {
      final f = o.properties['folder'];
      final path = pathFor?.call(o.id);
      return f == folder ||
          f is String && f.startsWith('$folder/') ||
          path != null && path.startsWith('$folder/');
    }
    if (scope is String && scope.isNotEmpty) {
      return ['project', 'courseId', 'course', 'context', 'target'].any(
        (key) =>
            '${o.properties[key] ?? ''}'.toLowerCase() == scope.toLowerCase(),
      );
    }
    return true;
  });
  final raw = p['smartQuery'];
  if (raw == null) return candidates.toList();
  if (raw is! Map) throw const FormatException('Unreadable saved query.');
  return SmartViewQuery(
    Map<String, dynamic>.from(raw),
  ).evaluate(candidates, now: now);
}
