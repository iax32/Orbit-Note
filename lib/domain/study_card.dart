import 'dart:convert';
import 'universal_object.dart';

enum StudyRating { again, hard, good, easy }

/// Versioned metadata on an ordinary Markdown note. The note title is the
/// question and its body is the answer; neither has a second content owner.
class StudyCard {
  StudyCard._(this.object);
  static final _cache = Expando<StudyCard>();
  static final _supported = Expando<bool>();
  factory StudyCard(UniversalObject object) {
    final cached = _cache[object];
    if (cached != null) return cached;
    validate(object.properties['studyCard']);
    return _cache[object] = StudyCard._(object);
  }
  final UniversalObject object;
  Map<String, dynamic> get record =>
      Map<String, dynamic>.from(object.properties['studyCard'] as Map);
  static bool supported(UniversalObject o) {
    if (o.typeId != 'orbit.note' || o.isDeleted) return false;
    final cached = _supported[o];
    if (cached != null) return cached;
    try {
      StudyCard(o);
      return _supported[o] = true;
    } on FormatException {
      return _supported[o] = false;
    }
  }

  DateTime get due => DateTime.parse(record['due'] as String).toUtc();
  bool get suspended => record['suspended'] == true;
  List<Map<String, dynamic>> get history => (record['history'] as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  Map<String, dynamic>? get source => record['source'] == null
      ? null
      : Map<String, dynamic>.from(record['source'] as Map);

  static Map<String, dynamic> initial(
    DateTime now, {
    Map<String, dynamic>? source,
  }) => {
    'version': 1,
    'due': now.toUtc().toIso8601String(),
    'intervalDays': 0,
    'suspended': false,
    'history': <dynamic>[],
    'source': ?source,
  };

  Map<String, dynamic> reviewed(StudyRating rating, DateTime now) {
    final at = now.toUtc();
    if (suspended || at.isBefore(due)) {
      throw const FormatException('This card is not due for review.');
    }
    final entries = history;
    if (entries.isNotEmpty &&
        at.isBefore(DateTime.parse(entries.last['at'] as String))) {
      throw const FormatException('Review time precedes the last review.');
    }
    if (entries.length >= 10000) {
      throw const FormatException(
        'Review history is full. Export this card before starting a new one.',
      );
    }
    final old = record['intervalDays'] as int;
    final days = switch (rating) {
      StudyRating.again => 0,
      StudyRating.hard => old < 1 ? 1 : (old * 1.2).ceil(),
      StudyRating.good => old < 1 ? 3 : (old * 2).ceil(),
      StudyRating.easy => old < 1 ? 7 : (old * 3).ceil(),
    }.clamp(0, 3650);
    final next = at.add(
      rating == StudyRating.again
          ? const Duration(minutes: 10)
          : Duration(days: days),
    );
    return {
      ...record,
      'due': next.toIso8601String(),
      'intervalDays': days,
      'history': [
        ...entries,
        {
          'at': at.toIso8601String(),
          'rating': rating.name,
          'previousDue': due.toIso8601String(),
          'previousIntervalDays': old,
          'due': next.toIso8601String(),
          'intervalDays': days,
        },
      ],
    };
  }

  static void validate(Object? raw) {
    if (raw is! Map || raw['version'] != 1) {
      throw const FormatException('Unsupported study card format.');
    }
    bool time(Object? v) =>
        v is String &&
        RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(v) &&
        DateTime.tryParse(v) != null;
    bool interval(Object? v) => v is int && v >= 0 && v <= 3650;
    if (!time(raw['due']) ||
        !interval(raw['intervalDays']) ||
        raw['suspended'] is! bool ||
        raw['history'] is! List ||
        (raw['history'] as List).length > 10000) {
      throw const FormatException('Invalid study schedule.');
    }
    DateTime? prior;
    for (final entry in raw['history'] as List) {
      if (entry is! Map ||
          !time(entry['at']) ||
          !time(entry['due']) ||
          !time(entry['previousDue']) ||
          !interval(entry['intervalDays']) ||
          !interval(entry['previousIntervalDays']) ||
          !StudyRating.values.any((r) => r.name == entry['rating'])) {
        throw const FormatException('Invalid review history.');
      }
      final at = DateTime.parse(entry['at'] as String);
      if (prior != null && at.isBefore(prior)) {
        throw const FormatException('Review history is out of order.');
      }
      prior = at;
    }
    final source = raw['source'];
    if (source != null &&
        (source is! Map ||
            source['objectId'] is! String ||
            (source['objectId'] as String).isEmpty ||
            source['title'] is! String ||
            source['passage'] is! String ||
            (source['passage'] as String).length > 100000 ||
            !time(source['capturedAt']) ||
            source['revision'] is! int ||
            (source['page'] != null &&
                (source['page'] is! int ||
                    (source['page'] as int) < 1 ||
                    (source['page'] as int) > 999999)) ||
            (source['checksum'] != null &&
                (source['checksum'] is! String ||
                    !RegExp(
                      r'^[a-fA-F0-9]{64}$',
                    ).hasMatch(source['checksum'] as String))))) {
      throw const FormatException('Invalid study source.');
    }
  }
}

const studyUnderstandingStates = ['uncertain', 'learning', 'understood'];

List<UniversalObject> studyQueue(
  Iterable<UniversalObject> objects,
  DateTime now, {
  String? course,
  DateTime? horizon,
}) {
  final result = objects
      .where(
        (o) =>
            StudyCard.supported(o) &&
            (course == null || o.properties['course'] == course) &&
            !StudyCard(o).suspended &&
            !StudyCard(o).due.isAfter(horizon ?? now.toUtc()),
      )
      .toList();
  result.sort((a, b) {
    final due = StudyCard(a).due.compareTo(StudyCard(b).due);
    return due != 0 ? due : a.id.compareTo(b.id);
  });
  return result;
}

String exportStudyCards(Iterable<UniversalObject> objects) =>
    const JsonEncoder.withIndent('  ').convert({
      'format': 'orbit-note-study',
      'version': 1,
      'cards': [
        for (final o in objects)
          if (o.typeId == 'orbit.note' &&
              o.properties['studyCard'] != null &&
              !o.isDeleted)
            {
              ...o.toJson(),
              'body': o.body,
              'documentExtra': o.documentExtra,
              'formatVersion': o.formatVersion,
            },
      ],
    });
