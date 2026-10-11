import 'dart:math' as math;
import 'geometry.dart';
import 'scene.dart';
import '../domain/object_reference.dart';

const referenceStates = ['Inbox', 'Review', 'Chosen', 'Archived'];

/// A placement's commentary is independent of its canonical source content.
Map<String, dynamic> referenceDetails({
  required String caption,
  required String sourceUrl,
  required String tags,
  required String status,
}) {
  final url = sourceUrl.trim();
  if (RegExp(r'[\x00-\x1f]').hasMatch(url)) {
    throw const FormatException('Use a complete HTTP or HTTPS source address.');
  }
  if (url.isNotEmpty) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException(
        'Use a complete HTTP or HTTPS source address.',
      );
    }
  }
  if (!referenceStates.contains(status)) {
    throw const FormatException('Choose a reference state.');
  }
  return {
    'referenceCaption': caption.trim(),
    'referenceSourceUrl': url,
    'referenceTags': tags
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(30)
        .toSet()
        .toList(),
    'referenceStatus': status,
  };
}

/// Creates spaced cards, extending an unlocked destination column as needed.
List<CanvasElement> capturedReferencePlacements(
  CanvasScene scene,
  List<String> objectIds,
  CanvasPoint origin,
  String Function() nextId,
) {
  if (scene.readOnly) return const [];
  final column = scene.elements
      .toList()
      .reversed
      .where(
        (e) =>
            e.type == 'column' &&
            e.renderable &&
            !e.hidden &&
            !e.locked &&
            e.bounds.width >= 112 &&
            e.bounds.contains(origin),
      )
      .firstOrNull;
  final result = <CanvasElement>[];
  var y = origin.y;
  if (column != null) {
    y = math.max(column.bounds.top + 60, origin.y);
    for (final member in scene.elements.where(
      (e) => e.data['columnId'] == column.id,
    )) {
      y = math.max(y, member.bounds.bottom + 18);
    }
  }
  for (final (i, objectId) in objectIds.indexed) {
    result.add(
      CanvasElement({
        'id': nextId(),
        'type': 'card',
        'objectId': objectId,
        'presentation': 'preview',
        'referenceStatus': 'Inbox',
        'referenceCaption': '',
        'referenceTags': <String>[],
        if (column != null) 'columnId': column.id,
        'x': column != null
            ? column.bounds.left + 16
            : origin.x + (i % 3) * 320,
        'y': column != null ? y + i * 278 : origin.y + (i ~/ 3) * 278,
        'width': column != null
            ? math.max(80, column.bounds.width - 32)
            : 300.0,
        'height': 260.0,
      }),
    );
  }
  if (column != null && result.isNotEmpty) {
    result.insert(
      0,
      column.copy({
        'height': math.max(
          column.bounds.height,
          result.last.bounds.bottom - column.bounds.top + 18,
        ),
      }),
    );
  }
  return result;
}

String referenceSummaryMarkdown(
  String boardId,
  String title,
  Iterable<CanvasElement> elements,
  Map<String, String> titles,
) {
  final out = StringBuffer(
    '# $title — References\n\n${ObjectReference(boardId).markdown('Source board')}\n\n',
  );
  for (final e in elements.where(
    (e) =>
        e.type == 'card' &&
        e.objectId != null &&
        e.data['referenceStatus'] is String,
  )) {
    out.writeln(
      '## ${ObjectReference(e.objectId!).markdown(titles[e.objectId] ?? 'Missing source')}',
    );
    out.writeln('\nState: ${e.data['referenceStatus']}');
    final caption = e.data['referenceCaption'];
    if (caption is String && caption.isNotEmpty) out.writeln('\n$caption');
    final url = e.data['referenceSourceUrl'];
    if (url is String && url.isNotEmpty) out.writeln('\nSource: <$url>');
    final tags = e.data['referenceTags'];
    if (tags is List && tags.isNotEmpty) {
      out.writeln('\nTags: ${tags.join(', ')}');
    }
    out.writeln();
  }
  return out.toString();
}
