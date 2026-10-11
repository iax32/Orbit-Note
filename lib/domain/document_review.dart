import 'dart:convert';
import 'document_anchors.dart';
import 'object_reference.dart';

class ReviewAnnotation {
  const ReviewAnnotation(this.data, this.start, this.end);
  final Map<String, dynamic> data;

  /// Metadata source range, not the passage range.
  final int start, end;
  String get id => data['id'] as String;
  String get kind => data['kind'] as String;
  String get state => data['state'] as String;
  String get quote => data['quote'] as String;
  String get message => data['message'] as String;
  String get replacement => data['replacement'] as String? ?? '';
  String? get blockId => data['blockId'] as String?;
  bool get isOpen => state == 'open';
  static final marker = RegExp(r'^<!-- orbit:review (\{.*\}) -->\r?\n?$');
  static ReviewAnnotation? parse(String line, {int offset = 0}) {
    final match = marker.firstMatch(line);
    if (match == null) return null;
    try {
      final json = jsonDecode(match[1]!);
      if (json is! Map<String, dynamic> ||
          json['version'] != 1 ||
          json['id'] is! String ||
          (json['id'] as String).isEmpty ||
          !['comment', 'suggestion'].contains(json['kind']) ||
          ![
            'open',
            'resolved',
            'accepted',
            'rejected',
          ].contains(json['state']) ||
          (json['kind'] == 'comment' &&
              !['open', 'resolved'].contains(json['state'])) ||
          (json['kind'] == 'suggestion' && json['state'] == 'resolved') ||
          json['quote'] is! String ||
          (json['quote'] as String).trim().isEmpty ||
          json['message'] is! String ||
          json['prefix'] is! String ||
          json['suffix'] is! String ||
          json['offset'] is! int ||
          (json['offset'] as int) < 0 ||
          (json['blockId'] != null && json['blockId'] is! String) ||
          (json['kind'] == 'suggestion' && json['replacement'] is! String)) {
        return null;
      }
      return ReviewAnnotation(
        Map.unmodifiable(json),
        offset,
        offset + line.length,
      );
    } catch (_) {
      return null;
    }
  }

  static String encode(Map<String, dynamic> data, {String eol = '\n'}) =>
      '<!-- orbit:review ${jsonEncode(data).replaceAll('<', r'\u003c').replaceAll('>', r'\u003e')} -->$eol';
}

/// Only standalone, well-formed annotations outside fenced examples are read.
List<ReviewAnnotation> documentReviews(String source) {
  final result = <ReviewAnnotation>[];
  String? fence;
  for (final line in RegExp(r'[^\n]*\n|[^\n]+$').allMatches(source)) {
    final value = line[0]!;
    final delimiter = RegExp(r'^ {0,3}(`{3,}|~{3,})(.*)').firstMatch(value);
    if (delimiter != null) {
      if (fence == null) {
        fence = delimiter[1];
      } else if (delimiter[1]!.startsWith(fence[0]) &&
          delimiter[1]!.length >= fence.length &&
          delimiter[2]!.trim().isEmpty) {
        fence = null;
      }
      continue;
    }
    if (fence != null) continue;
    final review = ReviewAnnotation.parse(value, offset: line.start);
    if (review != null) result.add(review);
  }
  return result;
}

/// Mask records without changing UTF-16 coordinates; quote searches cannot match JSON.
String _prose(String source) {
  final result = StringBuffer();
  var offset = 0;
  for (final review in documentReviews(source)) {
    result.write(source.substring(offset, review.start));
    result.write(
      source
          .substring(review.start, review.end)
          .replaceAll(RegExp(r'[^\r\n]'), ' '),
    );
    offset = review.end;
  }
  result.write(source.substring(offset));
  return result.toString();
}

({int? start, String? warning}) locateReview(
  String source,
  ReviewAnnotation review,
) {
  if (documentReviews(source).where((r) => r.id == review.id).length != 1) {
    return (
      start: null,
      warning: 'Duplicate review identity. Location needs review.',
    );
  }
  final prose = _prose(source);
  var from = 0, end = prose.length;
  if (review.blockId != null) {
    final fragment = resolveDocumentFragment(
      prose,
      ObjectReference('', anchorType: 'block', anchorId: review.blockId),
    );
    if (fragment == null) {
      return (
        start: null,
        warning: 'Anchored passage is missing or ambiguous.',
      );
    }
    from = fragment.start;
    end = fragment.end;
  }
  final matches = <int>[];
  var cursor = from;
  while (cursor <= end - review.quote.length) {
    final at = prose.indexOf(review.quote, cursor);
    if (at < 0 || at + review.quote.length > end) break;
    matches.add(at);
    cursor = at + 1;
    if (matches.length > 1000) {
      return (
        start: null,
        warning: 'Too many matching passages. Reattach explicitly.',
      );
    }
  }
  if (matches.isEmpty) {
    return (
      start: null,
      warning: 'Passage changed or was removed. Reattach explicitly.',
    );
  }
  final prefix = review.data['prefix'] as String,
      suffix = review.data['suffix'] as String;
  final contextual = matches.where((at) {
    final finish = at + review.quote.length;
    return (prefix.isNotEmpty &&
            at >= prefix.length &&
            prose.substring(at - prefix.length, at) == prefix) ||
        (suffix.isNotEmpty &&
            finish + suffix.length <= prose.length &&
            prose.substring(finish, finish + suffix.length) == suffix);
  }).toList();
  if (review.blockId != null && matches.length == 1) {
    return (start: matches.single, warning: null);
  }
  if (contextual.length == 1) return (start: contextual.single, warning: null);
  if (matches.length == 1 &&
      prefix.isEmpty &&
      suffix.isEmpty &&
      matches.single == review.data['offset']) {
    return (start: matches.single, warning: null);
  }
  return (
    start: null,
    warning: 'Location is uncertain. Reattach to the intended passage.',
  );
}

class DocumentReview {
  static String _eol(String source) => source.contains('\r\n') ? '\r\n' : '\n';
  static ReviewAnnotation _find(String source, String id) {
    final matches = documentReviews(source).where((r) => r.id == id).toList();
    if (matches.length != 1) {
      throw StateError('Review is missing or duplicated.');
    }
    return matches.single;
  }

  static ({String source, Map<String, dynamic> anchor}) _anchor(
    String source,
    int start,
    int end,
    String id,
  ) {
    if (start < 0 ||
        end > source.length ||
        start >= end ||
        end - start > 16384) {
      throw ArgumentError('Select a passage up to 16,384 characters.');
    }
    while (end > start &&
        (source[end - 1] == '\n' || source[end - 1] == '\r')) {
      end--;
    }
    if (end <= start ||
        source.substring(start, end).trim().isEmpty ||
        documentReviews(source).any((r) => start < r.end && end > r.start)) {
      throw ArgumentError('Select document text, outside review metadata.');
    }
    final quote = source.substring(start, end);
    String? block;
    final fragments = documentFragments(source);
    final fragment = fragments
        .where((f) => start >= f.start && end <= f.end)
        .firstOrNull;
    if (fragment != null) {
      try {
        var anchorId = 'review-$id';
        var serial = 1;
        while (fragments.any((f) => f.blockId == anchorId)) {
          anchorId = 'review-$id-${serial++}';
        }
        final anchored = anchorDocumentBlock(
          source,
          '',
          start,
          anchorId,
          structured: true,
        );
        if (anchored.source.substring(start, end) == quote) {
          source = anchored.source;
          block = anchored.reference.anchorId;
        }
      } on StateError {
        /* Code/extension selections retain conservative context anchors. */
      }
    }
    final prose = _prose(source);
    return (
      source: source,
      anchor: {
        'quote': quote,
        'offset': start,
        'blockId': block,
        'prefix': prose.substring((start - 48).clamp(0, start), start),
        'suffix': prose.substring(end, (end + 48).clamp(end, prose.length)),
      },
    );
  }

  static String add(
    String source, {
    required String id,
    required int start,
    required int end,
    required String message,
    String? replacement,
  }) {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id) ||
        documentReviews(source).any((r) => r.id == id)) {
      throw ArgumentError('Invalid review identity.');
    }
    if (message.trim().isEmpty ||
        message.length > 4000 ||
        (replacement?.length ?? 0) > 20000) {
      throw ArgumentError(
        'Enter a comment up to 4,000 characters and replacement up to 20,000.',
      );
    }
    if (documentReviews(source).length >= 500) {
      throw StateError(
        'This note has 500 reviews. Remove finished entries before adding more.',
      );
    }
    // Reject an unfinished fence, rather than placing hidden metadata inside code.
    String? fence;
    for (final line in source.split('\n')) {
      final match = RegExp(r'^ {0,3}(`{3,}|~{3,})(.*)').firstMatch(line);
      if (match == null) continue;
      if (fence == null) {
        fence = match[1];
      } else if (match[1]!.startsWith(fence[0]) &&
          match[1]!.length >= fence.length &&
          match[2]!.trim().isEmpty) {
        fence = null;
      }
    }
    if (fence != null) {
      throw StateError(
        'Close the unfinished code fence before adding review annotations.',
      );
    }
    final anchored = _anchor(source, start, end, id);
    final eol = _eol(source);
    return '${anchored.source}$eol$eol${ReviewAnnotation.encode({'version': 1, 'id': id, 'kind': replacement == null ? 'comment' : 'suggestion', 'state': 'open', 'message': message, 'replacement': ?replacement, 'createdAt': DateTime.now().toUtc().toIso8601String(), ...anchored.anchor}, eol: eol)}';
  }

  static String updateState(String source, String id, String state) {
    final review = _find(source, id);
    if (!(review.kind == 'comment'
                ? ['open', 'resolved']
                : ['open', 'rejected'])
            .contains(state) ||
        review.state == 'accepted') {
      throw ArgumentError('Invalid review action.');
    }
    return source.replaceRange(
      review.start,
      review.end,
      ReviewAnnotation.encode({
        ...review.data,
        'state': state,
      }, eol: _eol(source)),
    );
  }

  static String remove(String source, String id) {
    final review = _find(source, id);
    return source.replaceRange(review.start, review.end, '');
  }

  static String accept(String source, String id) {
    final review = _find(source, id);
    if (review.kind != 'suggestion' || !review.isOpen) {
      throw StateError('This suggestion is no longer open.');
    }
    final location = locateReview(source, review);
    if (location.start == null) throw StateError(location.warning!);
    final updated = source.replaceRange(
      location.start!,
      location.start! + review.quote.length,
      review.replacement,
    );
    final current = _find(updated, id);
    return updated.replaceRange(
      current.start,
      current.end,
      ReviewAnnotation.encode({
        ...current.data,
        'state': 'accepted',
        'acceptedAt': DateTime.now().toUtc().toIso8601String(),
      }, eol: _eol(source)),
    );
  }

  static String reattach(String source, String id, int start, int end) {
    final review = _find(source, id);
    if (!review.isOpen) {
      throw StateError('Reopen this review before reattaching.');
    }
    final anchored = _anchor(source, start, end, id);
    final current = _find(anchored.source, id);
    return anchored.source.replaceRange(
      current.start,
      current.end,
      ReviewAnnotation.encode({
        ...review.data,
        ...anchored.anchor,
      }, eol: _eol(source)),
    );
  }
}
