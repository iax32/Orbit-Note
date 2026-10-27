import 'dart:math' as math;
import 'geometry.dart';
import 'scene.dart';
import 'uml.dart';
import 'uml_interaction.dart';

class SequenceClassDraft {
  SequenceClassDraft(this.elements, this.warnings);
  final List<CanvasElement> elements;
  final List<String> warnings;
}

class _Operation {
  _Operation(this.name, this.parameters);
  final String name;
  final List<String> parameters;
  final returns = <String>{};
  String get signature =>
      '$name(${parameters.join(', ')})${returns.length == 1 ? ': ${returns.single}' : ''}';
}

class _Call {
  _Call(this.from, this.to, this.operation, this.time);
  final String from, to;
  final _Operation operation;
  final double time;
  bool closed = false;
}

String? _literalType(String text) {
  final s = text.trim();
  if (RegExp(r'^[+-]?\d+$').hasMatch(s)) return 'int';
  if (RegExp(r'^[+-]?\d+\.\d+$').hasMatch(s)) return 'double';
  if (s == 'true' || s == 'false') return 'bool';
  if (RegExp(r'^"(?:[^"\\]|\\.)*"$').hasMatch(s) ||
      RegExp(r"^'(?:[^'\\]|\\.)*'$").hasMatch(s)) {
    return 'String';
  }
  return null;
}

List<String> _arguments(String text) {
  if (text.trim().isEmpty) return [];
  final result = <String>[];
  var start = 0, depth = 0;
  String? quote;
  var escape = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quote != null) {
      if (escape) {
        escape = false;
      } else if (c == r'\') {
        escape = true;
      } else if (c == quote) {
        quote = null;
      }
      continue;
    }
    if (c == '"' || c == "'") {
      quote = c;
      continue;
    }
    if ('([{<'.contains(c)) depth++;
    if (')]}>'.contains(c)) depth--;
    if (depth < 0) throw const FormatException('Unbalanced message arguments.');
    if (c == ',' && depth == 0) {
      result.add(text.substring(start, i).trim());
      start = i + 1;
    }
  }
  if (quote != null || depth != 0) {
    throw const FormatException('Unbalanced message arguments.');
  }
  result.add(text.substring(start).trim());
  if (result.length > 16 || result.any((s) => s.isEmpty)) {
    throw const FormatException('Unsupported arguments.');
  }
  return result;
}

/// A reviewed, independent draft from explicit Canvas notation, never an image
/// interpretation or a live mutation of the source sequence. Unknown types stay ?.
SequenceClassDraft draftClassesFromSequence(
  CanvasScene scene,
  String Function() id, {
  Set<String> selection = const {},
}) {
  final usedIds = scene.elements.map((e) => e.id).toSet();
  String fresh() {
    final value = id();
    if (value.isEmpty || !usedIds.add(value)) {
      throw const FormatException(
        'Draft IDs conflict with existing placements.',
      );
    }
    return value;
  }

  final lifelines = scene.elements
      .where((e) => !e.hidden && umlNodeKind(e) == UmlNodeKind.lifeline)
      .toList();
  final messages = scene.elements
      .where((e) => !e.hidden && umlLinkKind(e)?.sequence == true)
      .toList();
  final scope = selection.isEmpty
      ? lifelines.map((e) => e.id).toSet()
      : <String>{
          ...selection,
          for (final e in messages.where((e) => selection.contains(e.id))) ...[
            e.startId ?? '',
            e.endId ?? '',
          ],
        };
  final chosen = lifelines.where((e) => scope.contains(e.id)).toList();
  if (chosen.isEmpty || chosen.length > 50 || messages.length > 500) {
    throw const FormatException(
      'Select 1–50 typed lifelines and at most 500 messages.',
    );
  }
  final warnings = <String>{};
  final types = <String, String>{};
  for (final e in chosen) {
    final colon = e.text.indexOf(':');
    final type = colon < 0 ? '' : e.text.substring(colon + 1).trim();
    if (type.isEmpty || type.length > 120 || type.contains('\n')) {
      warnings.add('Skipped untyped lifeline: ${e.text}');
      continue;
    }
    types[e.id] = type;
  }
  if (types.isEmpty) {
    throw const FormatException('Use typed lifelines such as a1:A or b1:B.');
  }
  final byId = {for (final e in chosen) e.id: e};
  double time(CanvasElement e) {
    final from = byId[e.startId]!;
    final link = e.data['umlLink'] as Map;
    final p = link['position'];
    return from.y +
        math.max(
          68,
          from.height *
              (p is num && p.isFinite ? p.toDouble().clamp(.12, .9) : .3),
        );
  }

  final ordered =
      messages
          .where(
            (e) => types.containsKey(e.startId) && types.containsKey(e.endId),
          )
          .toList()
        ..sort((a, b) {
          final t = time(a).compareTo(time(b));
          return t != 0 ? t : a.id.compareTo(b.id);
        });
  final operations = {
    for (final name in types.values.toSet()) name: <String, _Operation>{},
  };
  final calls = <_Call>[];
  final links =
      <
        String,
        ({String from, String to, Set<String> directions, List<String> sources})
      >{};
  for (final e in ordered) {
    final kind = umlLinkKind(e)!;
    final link = e.data['umlLink'] as Map;
    final label =
        (e.text.trim().isNotEmpty
                ? e.text
                : link['label'] is String
                ? link['label'] as String
                : '')
            .trim();
    if (kind == UmlLinkKind.reply) {
      final match = RegExp(r'^([A-Za-z_]\w*)\s*:\s*(.+)$').firstMatch(label);
      if (match == null) continue;
      final candidates = calls
          .where(
            (c) =>
                !c.closed &&
                c.from == e.endId &&
                c.to == e.startId &&
                c.operation.name == match[1] &&
                c.time < time(e),
          )
          .toList();
      final result = _literalType(match[2]!);
      if (candidates.length == 1 && result != null) {
        candidates.single.operation.returns.add(result);
        candidates.single.closed = true;
      } else {
        warnings.add('Return type needs review: $label');
      }
      continue;
    }
    if (kind != UmlLinkKind.synchronous && kind != UmlLinkKind.asynchronous) {
      continue;
    }
    final match = RegExp(
      r'^([A-Za-z_]\w*)\s*(?:\((.*)\))?\s*(?::\s*(.+))?$',
    ).firstMatch(label);
    if (match == null) {
      warnings.add('Operation needs manual review: $label');
      continue;
    }
    List<String> args;
    try {
      args = _arguments(match[2] ?? '');
    } on FormatException {
      warnings.add('Arguments need review: $label');
      continue;
    }
    final parameters = <String>[];
    for (var i = 0; i < args.length; i++) {
      final typed = RegExp(
        r'^([A-Za-z_]\w*)\s*:\s*([A-Za-z_][\w:<>,?.\[\] ]*)$',
      ).firstMatch(args[i]);
      final inferred = _literalType(args[i]);
      parameters.add(
        typed != null
            ? '${typed[1]}: ${typed[2]}'
            : 'arg${i + 1}: ${inferred ?? '?'}',
      );
      if (typed == null && inferred == null) {
        warnings.add('Unknown parameter type: $label');
      }
    }
    final receiver = types[e.endId]!;
    final key =
        '${match[1]}(${parameters.map((p) => p.substring(p.indexOf(':') + 1).trim()).join(',')})';
    final operation = operations[receiver]!.putIfAbsent(
      key,
      () => _Operation(match[1]!, parameters),
    );
    if (match[3]?.trim().isNotEmpty == true) {
      final annotation = match[3]!.trim();
      final result = _literalType(annotation);
      if (result != null) {
        operation.returns.add(result);
      } else if (RegExp(r'^[A-Za-z_][\w:<>,?.\[\] ]*$').hasMatch(annotation)) {
        operation.returns.add(annotation);
      } else {
        warnings.add('Return annotation needs review: $label');
      }
    }
    calls.add(_Call(e.startId!, e.endId!, operation, time(e)));
    if (e.startId == e.endId) {
      continue; // Self invocation alone is not a self association.
    }
    final sender = types[e.startId]!;
    final pair = [sender, receiver]..sort();
    final pairKey = '${pair[0]}\u0000${pair[1]}';
    final association = links.putIfAbsent(
      pairKey,
      () => (
        from: sender,
        to: receiver,
        directions: <String>{},
        sources: <String>[],
      ),
    );
    association.directions.add(
      sender == association.from ? 'forward' : 'reverse',
    );
    association.sources.add(e.id);
  }
  final elements = <CanvasElement>[];
  final classes = <String, CanvasElement>{};
  final bounds = scene.contentBounds ?? const CanvasBounds(0, 0, 0, 0);
  var index = 0;
  var cursorX = bounds.right + 140, cursorY = bounds.top, rowHeight = 0.0;
  for (final entry in operations.entries) {
    for (final op in entry.value.values) {
      if (op.returns.length > 1) {
        warnings.add('Conflicting return types: ${entry.key}.${op.name}');
      }
    }
    final signatures = entry.value.values.map((o) => o.signature).toList();
    if (signatures.length > 100 || signatures.join('\n').length > 12000) {
      throw const FormatException(
        'Too many operations in one class. Select a smaller sequence.',
      );
    }
    final c =
        newUmlClass(
          fresh(),
          CanvasPoint(cursorX, cursorY),
          name: entry.key,
          operations: signatures,
        ).copy({
          'sequenceSources': [
            for (final e in types.entries)
              if (e.value == entry.key) e.key,
          ],
        });
    classes[entry.key] = c;
    elements.add(c);
    index++;
    cursorX += c.width + 100;
    rowHeight = math.max(rowHeight, c.height);
    if (index % 3 == 0) {
      cursorX = bounds.right + 140;
      cursorY += rowHeight + 100;
      rowHeight = 0;
    }
  }
  for (final link in links.values) {
    final a = classes[link.from]!, b = classes[link.to]!;
    final navigation = link.directions.length > 1
        ? UmlNavigation.both
        : UmlNavigation.fromTo;
    elements.add(
      CanvasElement({
        'id': fresh(),
        'type': 'connector',
        ...UmlRelationship.association.style,
        ...navigation.style,
        'startId': a.id,
        'endId': b.id,
        'startX': a.bounds.right,
        'startY': a.bounds.center.y,
        'endX': b.x,
        'endY': b.bounds.center.y,
        'sequenceSources': link.sources,
        'startMultiplicity': '',
        'endMultiplicity': '',
      }),
    );
  }
  warnings.add(
    'Draft only: review parameter names, unknown types and reply matching. Attributes, visibility and multiplicities are not inferred.',
  );
  return SequenceClassDraft(elements, warnings.toList());
}
