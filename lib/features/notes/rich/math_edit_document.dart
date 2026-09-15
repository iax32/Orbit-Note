import 'latex_catalog.dart';

/// Temporary visual projection; edits splice the original TeX, never serialize
/// an entire expression tree. Unknown commands remain opaque source slices.
enum MathPartKind { text, fraction, root, scripts, operator, group, opaque }

class MathPart {
  MathPart(
    this.kind,
    this.start,
    this.end, {
    this.children = const [],
    this.label = 'Expression',
    this.command = '',
    this.braced = true,
  });
  final MathPartKind kind;
  final int start, end;
  final List<MathPart> children;
  final String label, command;
  final bool braced;
}

final mathGlyphs = <String, String>{
  for (final entry in latexCatalog)
    if (RegExp(r'^\\[a-zA-Z]+$').hasMatch(entry.source) &&
        entry.glyph.runes.length == 1)
      entry.source: entry.glyph,
  r'\alpha': 'α',
  r'\beta': 'β',
  r'\gamma': 'γ',
  r'\delta': 'δ',
  r'\epsilon': 'ε',
  r'\theta': 'θ',
  r'\lambda': 'λ',
  r'\mu': 'μ',
  r'\pi': 'π',
  r'\rho': 'ρ',
  r'\sigma': 'σ',
  r'\tau': 'τ',
  r'\phi': 'φ',
  r'\psi': 'ψ',
  r'\omega': 'ω',
  r'\Gamma': 'Γ',
  r'\Delta': 'Δ',
  r'\Theta': 'Θ',
  r'\Lambda': 'Λ',
  r'\Sigma': 'Σ',
  r'\Phi': 'Φ',
  r'\Psi': 'Ψ',
  r'\Omega': 'Ω',
  r'\infty': '∞',
  r'\times': '×',
  r'\cdot': '·',
  r'\div': '÷',
  r'\pm': '±',
  r'\le': '≤',
  r'\leq': '≤',
  r'\ge': '≥',
  r'\geq': '≥',
  r'\ne': '≠',
  r'\neq': '≠',
  r'\approx': '≈',
  r'\to': '→',
  r'\in': '∈',
  r'\notin': '∉',
  r'\subset': '⊂',
  r'\subseteq': '⊆',
  r'\cup': '∪',
  r'\cap': '∩',
  r'\forall': '∀',
  r'\exists': '∃',
  r'\land': '∧',
  r'\lor': '∨',
  r'\neg': '¬',
  r'\partial': '∂',
  r'\nabla': '∇',
  r'\square': '□',
  r'\quad': '  ',
  r'\qquad': '    ',
  r'\,': ' ',
  r'\;': ' ',
  r'\!': '',
  r'\{': '{',
  r'\}': '}',
  r'\%': '%',
  r'\&': '&',
  r'\#': '#',
  r'\$': r'$',
};

class MathTextProjection {
  MathTextProjection(this.source) {
    final display = StringBuffer();
    var i = 0;
    while (i < source.length) {
      final macro = RegExp(r'\\(?:[a-zA-Z]+|.)').matchAsPrefix(source, i);
      final glyph = macro == null ? null : mathGlyphs[macro[0]];
      var end = glyph == null ? i + 1 : macro!.end;
      if (glyph != null &&
          RegExp(r'[a-zA-Z]$').hasMatch(macro![0]!) &&
          end < source.length &&
          source[end] == ' ') {
        end++;
      }
      final value = glyph ?? source[i];
      display.write(value);
      for (var j = 0; j < value.length; j++) {
        starts.add(i);
        ends.add(end);
      }
      i = end;
    }
    text = display.toString();
  }
  final String source;
  late final String text;
  final starts = <int>[], ends = <int>[];
  int sourceStart(int offset) =>
      offset >= starts.length ? source.length : starts[offset];
  int sourceEnd(int offset) => offset <= 0 ? 0 : ends[offset - 1];

  int visibleOffset(int sourceOffset) {
    for (var i = 0; i < starts.length; i++) {
      if (sourceOffset <= starts[i]) return i;
      if (sourceOffset < ends[i]) return i + 1;
    }
    return text.length;
  }

  /// Map only the changed visible range. Untouched commands keep their spelling.
  String edit(String next) {
    if (next == text) return source;
    var start = 0, end = text.length, nextEnd = next.length;
    while (start < end && start < nextEnd && text[start] == next[start]) {
      start++;
    }
    while (end > start &&
        nextEnd > start &&
        text[end - 1] == next[nextEnd - 1]) {
      end--;
      nextEnd--;
    }
    // A spacing macro can occupy several visible positions. If it is touched,
    // replace that macro as a unit, including its surviving visible spaces.
    while (start > 0 &&
        start < starts.length &&
        starts[start] == starts[start - 1]) {
      start--;
    }
    while (end > 0 && end < ends.length && ends[end] == ends[end - 1]) {
      end++;
      nextEnd++;
    }
    final insertion = encodeMathText(next.substring(start, nextEnd));
    return spliceMathSource(
      source,
      sourceStart(start),
      end == start ? sourceStart(start) : sourceEnd(end),
      insertion,
    );
  }
}

/// Keep a control word from absorbing letters joined at an edited boundary.
String spliceMathSource(String source, int start, int end, String value) {
  final prefix = source.substring(0, start), suffix = source.substring(end);
  String separate(String a, String b) =>
      RegExp(r'\\[a-zA-Z]+$').hasMatch(a) && RegExp(r'^[a-zA-Z]').hasMatch(b)
      ? '$a $b'
      : '$a$b';
  return separate(separate(prefix, value), suffix);
}

String encodeMathText(String text) {
  final reverse = {
    for (final e in mathGlyphs.entries)
      if (e.value.length == 1 &&
          (e.value.codeUnitAt(0) > 127 || r'{}%&#$'.contains(e.value)))
        e.value: e.key,
  };
  return text.split('').map((c) {
    final command = reverse[c];
    if (command != null) {
      return RegExp(r'[a-zA-Z]$').hasMatch(command) ? '$command ' : command;
    }
    return switch (c) {
      '%' => r'\%',
      '&' => r'\&',
      '#' => r'\#',
      r'$' => r'\$',
      _ => c,
    };
  }).join();
}

class MathEditDocument {
  MathEditDocument(this.source) {
    try {
      if (source.length > 32768 ||
          RegExp(r'\\(?:begin|left|right)(?![a-zA-Z])').hasMatch(source) ||
          RegExp(r'(?<!\\)%').hasMatch(source)) {
        throw const FormatException();
      }
      root = _sequence(0, source.length, 'Expression', 0);
    } on FormatException {
      root = null;
    }
  }
  final String source;
  MathPart? root;
  int _nodes = 0;

  /// Backspace in an empty argument removes just that structure/argument.
  /// Other authored arguments survive verbatim.
  (String, int)? removeEmptyPart(MathPart leaf) {
    final value = source.substring(leaf.start, leaf.end).trim();
    if (value.isNotEmpty && value != r'\square') return null;
    final chain = <MathPart>[];
    bool locate(MathPart part) {
      chain.add(part);
      if (identical(part, leaf)) return true;
      for (final child in part.children) {
        if (locate(child)) return true;
      }
      chain.removeLast();
      return false;
    }

    if (root == null || !locate(root!)) return null;
    String argument(MathPart part) => source.substring(
      part.start + (part.braced ? 1 : 0),
      part.end - (part.braced ? 1 : 0),
    );
    for (var i = chain.length - 2; i >= 0; i--) {
      final part = chain[i], child = chain[i + 1];
      if (part.kind == MathPartKind.group) continue;
      final content = argument(child).trim();
      if (content.isNotEmpty && content != r'\square') return null;
      if (part.kind == MathPartKind.fraction) {
        final other = part.children.firstWhere((p) => !identical(p, child));
        final kept = argument(other);
        return (
          source.replaceRange(part.start, part.end, kept),
          part.start + kept.length,
        );
      }
      if (part.kind == MathPartKind.root) {
        if (part.children.length > 1 && identical(child, part.children[1])) {
          return (source.replaceRange(child.start, child.end, ''), part.start);
        }
        if (part.children.length == 1) {
          return (source.replaceRange(part.start, part.end, ''), part.start);
        }
      }
      if (part.kind == MathPartKind.scripts ||
          part.kind == MathPartKind.operator) {
        var marker = child.start - 1;
        while (marker > part.start && RegExp(r'\s').hasMatch(source[marker])) {
          marker--;
        }
        if (source[marker] == '^' || source[marker] == '_') {
          return (source.replaceRange(marker, child.end, ''), marker);
        }
      }
      return null;
    }
    return null;
  }

  /// Structural addresses are transient field locations, never object IDs.
  /// Refresh them between input events, even when no frame has built yet.
  Map<String, MathPart> get editableParts {
    final result = <String, MathPart>{};
    void visit(MathPart part, String path) {
      switch (part.kind) {
        case MathPartKind.text:
          result[path] = part;
        case MathPartKind.opaque:
          break;
        case MathPartKind.fraction:
          visit(part.children[0], '$path.n');
          visit(part.children[1], '$path.d');
        case MathPartKind.root:
          if (part.children.length > 1) visit(part.children[1], '$path.degree');
          visit(part.children[0], '$path.root');
        default:
          for (var i = 0; i < part.children.length; i++) {
            visit(part.children[i], '$path.$i');
          }
      }
    }

    if (root != null) visit(root!, '0');
    return result;
  }

  /// Expand an originally unbraced argument only when that argument is edited.
  /// The returned offset points to the inserted source after any new brace.
  (String, int) replace(int start, int end, String value, {MathPart? within}) {
    MathPart? argument;
    void visit(MathPart part, MathPart? ancestor) {
      final owner = !part.braced ? part : ancestor;
      if (within != null
          ? identical(part, within)
          : (!part.braced &&
                start >= part.start &&
                end <= part.end &&
                start < end)) {
        argument = owner;
      }
      for (final child in part.children) {
        visit(child, owner);
      }
    }

    if (root != null) visit(root!, null);
    if (argument != null) {
      final a = argument!;
      final content = source
          .substring(a.start, a.end)
          .replaceRange(start - a.start, end - a.start, value);
      return (source.replaceRange(a.start, a.end, '{$content}'), start + 1);
    }
    final result = spliceMathSource(source, start, end, value);
    final hasNewDelimiter =
        RegExp(r'\\[a-zA-Z]+$').hasMatch(source.substring(0, start)) &&
        RegExp(r'^[a-zA-Z]').hasMatch(value);
    return (result, start + (hasNewDelimiter ? 1 : 0));
  }

  int _skip(int i, int end) {
    while (i < end && RegExp(r'\s').hasMatch(source[i])) {
      i++;
    }
    return i;
  }

  MathPart _argument(
    int at,
    int end,
    String label,
    int depth, {
    String close = '}',
  }) {
    final i = _skip(at, end);
    if (i >= end) throw const FormatException();
    final open = close == ']' ? '[' : '{';
    if (source[i] == open) {
      var level = 1, j = i + 1;
      while (j < end) {
        if (source[j] == r'\') {
          j += 2;
          continue;
        }
        if (source[j] == open) level++;
        if (source[j] == close) {
          level--;
          if (level == 0) break;
        }
        j++;
      }
      if (j >= end) throw const FormatException();
      final seq = _sequence(i + 1, j, label, depth + 1);
      return MathPart(
        MathPartKind.group,
        i,
        j + 1,
        children: [seq],
        label: label,
      );
    }
    final macro = RegExp(r'\\(?:[a-zA-Z]+|.)').matchAsPrefix(source, i);
    final j = macro?.end ?? i + 1;
    final seq = _sequence(i, j, label, depth + 1);
    return MathPart(
      MathPartKind.group,
      i,
      j,
      children: [seq],
      label: label,
      braced: false,
    );
  }

  MathPart _sequence(int start, int end, String label, int depth) {
    if (depth > 16 || ++_nodes > 512) throw const FormatException();
    final parts = <MathPart>[];
    var i = start, run = start;
    void flush(int stop) {
      parts.add(MathPart(MathPartKind.text, run, stop, label: label));
    }

    while (i < end) {
      if (++_nodes > 4096) throw const FormatException();
      final command = RegExp(r'\\(?:[a-zA-Z]+|.)').matchAsPrefix(source, i);
      final name = command?[0];
      MathPart? part;
      if ({r'\frac', r'\dfrac', r'\tfrac'}.contains(name)) {
        final top = _argument(command!.end, end, 'Numerator', depth);
        final bottom = _argument(top.end, end, 'Denominator', depth);
        part = MathPart(
          MathPartKind.fraction,
          i,
          bottom.end,
          children: [top, bottom],
          command: name!,
        );
      } else if (name == r'\sqrt') {
        var at = _skip(command!.end, end);
        MathPart? degree;
        if (at < end && source[at] == '[') {
          degree = _argument(at, end, 'Root degree', depth, close: ']');
          at = degree.end;
        }
        final body = _argument(at, end, 'Inside root', depth);
        part = MathPart(
          MathPartKind.root,
          i,
          body.end,
          children: [body, ?degree],
        );
      } else if (source[i] == '^' || source[i] == '_') {
        final args = <MathPart>[];
        final seen = <String>{};
        var at = i;
        while (at < end && (source[at] == '^' || source[at] == '_')) {
          final marker = source[at];
          if (!seen.add(marker)) throw const FormatException();
          final arg = _argument(
            at + 1,
            end,
            marker == '^' ? 'Exponent' : 'Subscript',
            depth,
          );
          args.add(arg);
          at = arg.end;
        }
        part = MathPart(MathPartKind.scripts, i, at, children: args);
      } else if ({
        r'\sum',
        r'\prod',
        r'\int',
        r'\lim',
        r'\bigcup',
        r'\bigcap',
      }.contains(name)) {
        final args = <MathPart>[];
        var at = command!.end;
        final seen = <String>{};
        while (at < end && (source[at] == '^' || source[at] == '_')) {
          final marker = source[at];
          if (!seen.add(marker)) throw const FormatException();
          final arg = _argument(
            at + 1,
            end,
            marker == '^' ? 'Upper limit' : 'Lower limit',
            depth,
          );
          args.add(arg);
          at = arg.end;
        }
        part = MathPart(
          MathPartKind.operator,
          i,
          at,
          command: name!,
          children: args,
        );
      } else if (source[i] == '{') {
        part = _argument(i, end, label, depth);
      } else if (source[i] == '}') {
        throw const FormatException();
      } else if (command != null && !mathGlyphs.containsKey(name)) {
        var at = command.end;
        while (at < end && source[at] == '{') {
          at = _argument(at, end, label, depth).end;
        }
        part = MathPart(MathPartKind.opaque, i, at);
      }
      if (part != null) {
        flush(i);
        parts.add(part);
        i = part.end;
        run = i;
      } else {
        i = command?.end ?? i + 1;
      }
    }
    flush(end);
    if (parts.isEmpty) {
      parts.add(MathPart(MathPartKind.text, start, end, label: label));
    }
    return MathPart(
      MathPartKind.group,
      start,
      end,
      children: parts,
      label: label,
      command: 'sequence',
    );
  }
}
