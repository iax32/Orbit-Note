import 'dart:math' as math;
import 'geometry.dart';
import 'scene.dart';

List<String> brainstormIdeas(String source, {bool paragraphs = false}) {
  if (source.length > 60000) {
    throw const FormatException('Use at most 60,000 characters.');
  }
  final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final ideas = normalized
      .split(paragraphs ? RegExp(r'\n[ \t]*\n+') : '\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (ideas.length > 200) {
    throw const FormatException('Create at most 200 ideas at once.');
  }
  if (ideas.any((s) => s.length > 2000)) {
    throw const FormatException(
      'Keep each idea under 2,000 characters or split it.',
    );
  }
  return ideas;
}

List<CanvasElement> createBrainstormStickies(
  List<String> ideas,
  String Function() id, {
  required CanvasPoint origin,
  required int color,
  int columns = 4,
}) {
  if (ideas.length > 200 ||
      columns < 1 ||
      columns > 8 ||
      ideas.any((s) => s.length > 2000)) {
    throw const FormatException('Invalid bulk sticky request.');
  }
  final output = <CanvasElement>[];
  var y = origin.y;
  for (var row = 0; row * columns < ideas.length; row++) {
    var height = 180.0;
    for (
      var col = 0;
      col < columns && row * columns + col < ideas.length;
      col++
    ) {
      final text = ideas[row * columns + col];
      final lines = text
          .split('\n')
          .fold<int>(
            0,
            (n, line) => n + math.max(1, (line.runes.length / 21).ceil()),
          );
      final h = math.max(180.0, lines * 24.0 + 40);
      output.add(
        CanvasElement({
          'id': id(),
          'type': 'sticky',
          'text': text,
          'x': origin.x + col * 244,
          'y': y,
          'width': 220.0,
          'height': h,
          'color': color,
        }),
      );
      height = math.max(height, h);
    }
    y += height + 24;
  }
  if (output.map((e) => e.id).toSet().length != output.length ||
      output.any((e) => !e.renderable)) {
    throw const FormatException(
      'Sticky identities or coordinates are invalid.',
    );
  }
  return output;
}

bool brainstormEligible(CanvasElement e) =>
    e.type == 'sticky' &&
    !e.hidden &&
    !e.locked &&
    e.renderable &&
    e.groupId == null &&
    e.data['columnId'] == null;

/// Move existing placements only. Bound connectors retain their endpoint IDs.
List<CanvasElement> clusterBrainstormColors(
  Iterable<CanvasElement> input, {
  Iterable<CanvasElement> obstacles = const [],
}) {
  final notes = input.where(brainstormEligible).toList();
  if (notes.length > 200) {
    throw const FormatException(
      'Cluster at most 200 ungrouped stickies at once.',
    );
  }
  if (notes.length < 2) return [];
  final bounds = notes.map((e) => e.bounds).reduce((a, b) => a.union(b));
  final groups = <int, List<CanvasElement>>{};
  for (final e in notes) {
    (groups[e.color] ??= []).add(e);
  }
  final colors = groups.keys.toList()..sort();
  final output = <CanvasElement>[];
  var x = bounds.left;
  for (final color in colors) {
    final items = groups[color]!
      ..sort(
        (a, b) =>
            a.y.compareTo(b.y) != 0 ? a.y.compareTo(b.y) : a.x.compareTo(b.x),
      );
    final columns = math.min(3, math.sqrt(items.length).ceil());
    final width = items.map((e) => e.bounds.width).reduce(math.max);
    var y = bounds.top;
    for (var row = 0; row * columns < items.length; row++) {
      var h = 0.0;
      for (
        var col = 0;
        col < columns && row * columns + col < items.length;
        col++
      ) {
        final e = items[row * columns + col];
        output.add(
          e.translated(
            CanvasPoint(
              x + col * (width + 24) - e.bounds.left,
              y - e.bounds.top,
            ),
          ),
        );
        h = math.max(h, e.bounds.height);
      }
      y += h + 24;
    }
    x += columns * (width + 24) + 72;
  }
  final ids = notes.map((e) => e.id).toSet();
  final occupied = obstacles
      .where(
        (e) =>
            !ids.contains(e.id) &&
            !e.hidden &&
            e.renderable &&
            !const {
              'frame',
              'section',
              'connector',
              'arrow',
              'line',
            }.contains(e.type),
      )
      .map((e) => e.bounds)
      .toList();
  final arrangedBounds = output
      .map((e) => e.bounds)
      .reduce((a, b) => a.union(b));
  if (occupied.any((b) => arrangedBounds.inflate(24).intersects(b))) {
    final right = occupied.map((b) => b.right).reduce(math.max);
    final offset = CanvasPoint(
      math.max(0, right + 80 - arrangedBounds.left),
      0,
    );
    final shifted = output.map((e) => e.translated(offset)).toList();
    if (shifted.any((e) => !e.renderable)) {
      throw const FormatException(
        'Not enough space to cluster here. Move the selected ideas nearer the Canvas origin.',
      );
    }
    return shifted;
  }
  return output;
}

int brainstormVotes(CanvasElement e) {
  final value = e.data['workshopVotes'];
  return value is int ? value.clamp(0, 999) : 0;
}

List<CanvasElement> brainstormExportNotes(
  Iterable<CanvasElement> input, {
  Set<String> selection = const {},
}) => input
    .where(
      (e) =>
          e.type == 'sticky' &&
          !e.hidden &&
          e.renderable &&
          (selection.isEmpty || selection.contains(e.id)),
    )
    .toList();

String brainstormCsv(Iterable<CanvasElement> input) {
  String cell(Object value) {
    final text = value.toString();
    final safe = RegExp(r'^\s*[=+@-]').hasMatch(text) ? "'$text" : text;
    return '"${safe.replaceAll('"', '""')}"';
  }

  final output = StringBuffer('"id","text","color","votes"');
  var count = 0, characters = 0;
  for (final e in input.where((e) => e.type == 'sticky' && !e.hidden)) {
    count++;
    characters += e.text.length + e.id.length;
    if (count > 10000 || characters > 2000000) {
      throw const FormatException(
        'CSV exceeds 10,000 notes or two million text characters. Export a smaller selection.',
      );
    }
    output.write('\r\n');
    output.write(
      [
        e.id,
        e.text,
        '#${(e.color & 0xffffff).toRadixString(16).padLeft(6, '0')}',
        brainstormVotes(e),
      ].map(cell).join(','),
    );
  }
  return output.toString();
}
