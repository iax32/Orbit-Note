/// Lossless, structured projection of a LaTeX document into editable visual blocks.
/// The original LaTeX syntax, comments, and unknown commands are preserved 100%.
library;

enum LatexBlockKind {
  preamble,
  title,
  section,
  subsection,
  subsubsection,
  paragraph,
  equation,
  aligned,
  theorem,
  proof,
  table,
  figure,
  list,
  pageBreak,
  comment,
  raw,
}

typedef LatexBlockType = LatexBlockKind;

class LatexBlock {
  LatexBlock(
    this.source,
    this.kind, {
    this.prefix = '',
    this.suffix = '',
    this.envName = '',
    this.envArg = '',
    this.isNumbered = true,
  });

  /// Constructor specifying raw fields directly
  LatexBlock.raw({
    required this.kind,
    required this.source,
    this.prefix = '',
    this.suffix = '',
    this.envName = '',
    this.envArg = '',
    this.isNumbered = true,
  });

  factory LatexBlock.fromFields({
    required LatexBlockKind type,
    String rawContent = '',
    String options = '',
    String environment = '',
    bool numbered = true,
    String? caption,
    String? imagePath,
    String? label,
  }) {
    String prefix = '';
    String suffix = '\n';
    String env = environment;
    String source = '';

    switch (type) {
      case LatexBlockKind.section:
        prefix = numbered ? r'\section{' : r'\section*{';
        suffix = '}\n';
        source = '$prefix$rawContent$suffix';
        break;
      case LatexBlockKind.subsection:
        prefix = numbered ? r'\subsection{' : r'\subsection*{';
        suffix = '}\n';
        source = '$prefix$rawContent$suffix';
        break;
      case LatexBlockKind.subsubsection:
        prefix = numbered ? r'\subsubsection{' : r'\subsubsection*{';
        suffix = '}\n';
        source = '$prefix$rawContent$suffix';
        break;
      case LatexBlockKind.paragraph:
        prefix = '';
        suffix = '\n\n';
        source = '$rawContent$suffix';
        break;
      case LatexBlockKind.equation:
        env = numbered ? 'equation' : 'equation*';
        prefix = '\\begin{$env}\n  ';
        suffix = '\n\\end{$env}\n';
        source = '$prefix$rawContent$suffix';
        break;
      case LatexBlockKind.aligned:
        env = numbered ? 'align' : 'align*';
        prefix = '\\begin{$env}\n  ';
        suffix = '\n\\end{$env}\n';
        source = '$prefix$rawContent$suffix';
        break;
      case LatexBlockKind.theorem:
        env = environment.isNotEmpty ? environment : 'theorem';
        final optStr = options.isNotEmpty ? '[$options]' : '';
        prefix = '\\begin{$env}$optStr\n  ';
        suffix = '\n\\end{$env}\n';
        source = '$prefix$rawContent$suffix';
        break;
      case LatexBlockKind.proof:
        env = 'proof';
        final optStr = options.isNotEmpty ? '[$options]' : '';
        prefix = '\\begin{proof}$optStr\n  ';
        suffix = '\n\\end{proof}\n';
        source = '$prefix$rawContent$suffix';
        break;
      case LatexBlockKind.table:
        env = 'tabular';
        final cols = options.isNotEmpty ? options : 'c c c';
        final capStr = caption != null && caption.isNotEmpty
            ? '\\caption{$caption}\n'
            : '';
        prefix =
            '\\begin{table}[h]\n\\centering\n$capStr\\begin{tabular}{$cols}\n';
        suffix = '\n\\end{tabular}\n\\end{table}\n';
        source = '$prefix$rawContent$suffix';
        break;
      case LatexBlockKind.figure:
        env = 'figure';
        final capStr = caption != null && caption.isNotEmpty
            ? '\\caption{$caption}\n'
            : '';
        final imgStr = imagePath != null && imagePath.isNotEmpty
            ? '\\includegraphics[width=\\textwidth]{$imagePath}\n'
            : '';
        prefix = '\\begin{figure}[h]\n\\centering\n';
        suffix = '$imgStr$capStr\\end{figure}\n';
        source = '$prefix$suffix';
        break;
      case LatexBlockKind.list:
        env = environment == 'enumerate' ? 'enumerate' : 'itemize';
        prefix = '\\begin{$env}\n';
        suffix = '\n\\end{$env}\n';
        source = '$prefix$rawContent$suffix';
        break;
      case LatexBlockKind.pageBreak:
        source = '\\newpage\n';
        break;
      case LatexBlockKind.comment:
        source = '% $rawContent\n';
        break;
      case LatexBlockKind.preamble:
      case LatexBlockKind.title:
      case LatexBlockKind.raw:
        source = rawContent;
        break;
    }

    return LatexBlock(
      source,
      type,
      prefix: prefix,
      suffix: suffix,
      envName: env,
      envArg: options,
      isNumbered: numbered,
    );
  }

  String source;
  final LatexBlockKind kind;
  final String prefix;
  final String suffix;
  final String envName;
  final String envArg;
  final bool isNumbered;

  LatexBlockKind get type => kind;
  String get rawContent => content;
  String get options => envArg;
  String get environment => envName;
  bool get numbered => isNumbered;

  /// Inner editable content of the block.
  String get content {
    if (source.length >= prefix.length + suffix.length) {
      return source.substring(prefix.length, source.length - suffix.length);
    }
    return source;
  }

  void updateContent(String newContent) {
    source = '$prefix$newContent$suffix';
  }

  /// Title or heading label if this is a section or theorem block.
  String get headingTitle => content.trim();

  String? get caption {
    final m = RegExp(r'\\caption\{([^}]+)\}').firstMatch(source);
    return m?.group(1);
  }

  String? get imagePath {
    final m = RegExp(
      r'\\includegraphics(?:\[[^\]]*\])?\{([^}]+)\}',
    ).firstMatch(source);
    return m?.group(1);
  }

  String? get label {
    final m = RegExp(r'\\label\{([^}]+)\}').firstMatch(source);
    return m?.group(1);
  }

  LatexBlock copyWith({
    LatexBlockKind? type,
    String? rawContent,
    String? options,
    String? environment,
    bool? numbered,
    String? caption,
    String? imagePath,
    String? label,
  }) {
    return LatexBlock.fromFields(
      type: type ?? kind,
      rawContent: rawContent ?? content,
      options: options ?? envArg,
      environment: environment ?? envName,
      numbered: numbered ?? isNumbered,
      caption: caption ?? this.caption,
      imagePath: imagePath ?? this.imagePath,
      label: label ?? this.label,
    );
  }

  @override
  String toString() => 'LatexBlock($kind, content: "$content")';
}

class LatexDocument {
  LatexDocument(this.blocks);

  final List<LatexBlock> blocks;

  String get source => blocks.map((b) => b.source).join();
  String toLatex() => source;

  static LatexDocument fromLatex(String source) => parse(source);

  String get title {
    final titleBlock = blocks.cast<LatexBlock?>().firstWhere(
      (b) => b?.kind == LatexBlockKind.title,
      orElse: () => null,
    );
    if (titleBlock != null) {
      final m = RegExp(r'\\title\{([^}]+)\}').firstMatch(titleBlock.source);
      if (m != null) return m.group(1)!;
    }
    final preambleBlock = blocks.cast<LatexBlock?>().firstWhere(
      (b) => b?.kind == LatexBlockKind.preamble,
      orElse: () => null,
    );
    if (preambleBlock != null) {
      final m = RegExp(r'\\title\{([^}]+)\}').firstMatch(preambleBlock.source);
      if (m != null) return m.group(1)!;
    }
    return '';
  }

  String get author {
    for (final b in blocks) {
      final m = RegExp(r'\\author\{([^}]+)\}').firstMatch(b.source);
      if (m != null) return m.group(1)!;
    }
    return '';
  }

  String get date {
    for (final b in blocks) {
      final m = RegExp(r'\\date\{([^}]+)\}').firstMatch(b.source);
      if (m != null) return m.group(1)!;
    }
    return '';
  }

  String get abstractText {
    for (final b in blocks) {
      if (b.envName == 'abstract') return b.content.trim();
    }
    return '';
  }

  String get documentClass {
    for (final b in blocks) {
      final m = RegExp(
        r'\\documentclass(?:\[[^\]]*\])?\{([a-zA-Z0-9]+)\}',
      ).firstMatch(b.source);
      if (m != null) return m.group(1)!;
    }
    return 'article';
  }

  String get paperSize {
    for (final b in blocks) {
      if (b.source.contains('letterpaper')) return 'letterpaper';
      if (b.source.contains('a4paper')) return 'a4paper';
    }
    return 'a4paper';
  }

  String get fontSize {
    for (final b in blocks) {
      final m = RegExp(r'\b(1[012]pt)\b').firstMatch(b.source);
      if (m != null) return m.group(1)!;
    }
    return '11pt';
  }

  String get margins {
    for (final b in blocks) {
      final m = RegExp(r'margin=([0-9.]+(?:in|cm|mm))').firstMatch(b.source);
      if (m != null) return m.group(1)!;
    }
    return '1in';
  }

  List<String> get packages {
    final pkgs = <String>{};
    for (final b in blocks) {
      final matches = RegExp(
        r'\\usepackage(?:\[[^\]]*\])?\{([a-zA-Z0-9,\s]+)\}',
      ).allMatches(b.source);
      for (final m in matches) {
        for (final p in m.group(1)!.split(',')) {
          final trimmed = p.trim();
          if (trimmed.isNotEmpty) pkgs.add(trimmed);
        }
      }
    }
    return pkgs.toList();
  }

  String get preamble {
    return blocks
        .where((b) => b.kind == LatexBlockKind.preamble)
        .map((b) => b.source)
        .join();
  }

  LatexDocument copyWith({
    List<LatexBlock>? blocks,
    String? title,
    String? author,
    String? date,
    String? abstractText,
    String? documentClass,
    String? paperSize,
    String? fontSize,
    String? margins,
    List<String>? packages,
    String? preamble,
  }) {
    if (blocks != null) {
      return LatexDocument(blocks);
    }

    // If modifying document metadata, rebuild preamble/title blocks
    final newDocClass = documentClass ?? this.documentClass;
    final newPaperSize = paperSize ?? this.paperSize;
    final newFontSize = fontSize ?? this.fontSize;
    final newMargins = margins ?? this.margins;
    final newPkgs = packages ?? this.packages;
    final newTitle = title ?? this.title;
    final newAuthor = author ?? this.author;
    final newDate = date ?? this.date;

    final preambleBuf = StringBuffer();
    preambleBuf.writeln(
      '\\documentclass[$newFontSize,$newPaperSize]{$newDocClass}',
    );
    preambleBuf.writeln('\\usepackage[$newMargins]{geometry}');
    for (final pkg in newPkgs) {
      if (pkg != 'geometry') {
        preambleBuf.writeln('\\usepackage{$pkg}');
      }
    }
    if (preamble != null && preamble.isNotEmpty) {
      preambleBuf.writeln(preamble);
    }
    preambleBuf.writeln();

    final titleBuf = StringBuffer();
    if (newTitle.isNotEmpty) titleBuf.writeln('\\title{$newTitle}');
    if (newAuthor.isNotEmpty) titleBuf.writeln('\\author{$newAuthor}');
    if (newDate.isNotEmpty) titleBuf.writeln('\\date{$newDate}');
    if (titleBuf.isNotEmpty) titleBuf.writeln('\\maketitle\n');

    final updatedBlocks = <LatexBlock>[
      LatexBlock(preambleBuf.toString(), LatexBlockKind.preamble),
      LatexBlock('\\begin{document}\n\n', LatexBlockKind.raw),
    ];

    if (titleBuf.isNotEmpty) {
      updatedBlocks.add(LatexBlock(titleBuf.toString(), LatexBlockKind.title));
    }

    // Keep existing content blocks (excluding old preamble, begin{document}, title, end{document})
    for (final b in this.blocks) {
      if (b.kind != LatexBlockKind.preamble &&
          b.kind != LatexBlockKind.title &&
          !b.source.contains(r'\begin{document}') &&
          !b.source.contains(r'\end{document}')) {
        updatedBlocks.add(b);
      }
    }

    updatedBlocks.add(LatexBlock('\\end{document}\n', LatexBlockKind.raw));

    return LatexDocument(updatedBlocks);
  }

  static LatexDocument parse(String source) {
    if (source.trim().isEmpty) {
      return LatexDocument([LatexBlock(source, LatexBlockKind.paragraph)]);
    }

    final blocks = <LatexBlock>[];
    final lines = source.split('\n');
    if (lines.last.isEmpty) lines.removeLast();
    var i = 0;

    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      // Blank lines between blocks
      if (trimmed.isEmpty) {
        if (blocks.isNotEmpty && blocks.last.kind == LatexBlockKind.paragraph) {
          blocks.last.source += '\n';
        } else {
          blocks.add(LatexBlock('\n', LatexBlockKind.paragraph));
        }
        i++;
        continue;
      }

      // Preamble: \documentclass, \usepackage, or \newcommand
      if (trimmed.startsWith(r'\documentclass') ||
          trimmed.startsWith(r'\usepackage') ||
          trimmed.startsWith(r'\newcommand')) {
        final start = i;
        while (i < lines.length &&
            (lines[i].trim().startsWith(r'\documentclass') ||
                lines[i].trim().startsWith(r'\usepackage') ||
                lines[i].trim().startsWith(r'\newcommand') ||
                lines[i].trim().isEmpty)) {
          i++;
        }
        final raw = '${lines.sublist(start, i).join('\n')}\n';
        blocks.add(LatexBlock(raw, LatexBlockKind.preamble));
        continue;
      }

      // \begin{document} / \end{document}
      if (trimmed == r'\begin{document}' || trimmed == r'\end{document}') {
        blocks.add(LatexBlock('$line\n', LatexBlockKind.raw));
        i++;
        continue;
      }

      // Title/Author/Date/maketitle
      if (trimmed.startsWith(r'\title') ||
          trimmed.startsWith(r'\author') ||
          trimmed.startsWith(r'\date') ||
          trimmed == r'\maketitle') {
        final start = i;
        while (i < lines.length &&
            (lines[i].trim().startsWith(r'\title') ||
                lines[i].trim().startsWith(r'\author') ||
                lines[i].trim().startsWith(r'\date') ||
                lines[i].trim() == r'\maketitle' ||
                lines[i].trim().isEmpty)) {
          i++;
        }
        final raw = '${lines.sublist(start, i).join('\n')}\n';
        blocks.add(LatexBlock(raw, LatexBlockKind.title));
        continue;
      }

      // Sections
      final secMatch = RegExp(
        r'^\\(section|subsection|subsubsection)(\*?)\{(.*)\}\s*$',
      ).firstMatch(trimmed);
      if (secMatch != null) {
        final level = secMatch.group(1)!;
        final star = secMatch.group(2)!;
        final kind = level == 'section'
            ? LatexBlockKind.section
            : (level == 'subsection'
                  ? LatexBlockKind.subsection
                  : LatexBlockKind.subsubsection);
        blocks.add(
          LatexBlock(
            '$line\n',
            kind,
            prefix: '\\$level$star{',
            suffix: '}\n',
            isNumbered: star.isEmpty,
          ),
        );
        i++;
        continue;
      }

      // Display math: \[ ... \] or $$ ... $$
      if (trimmed.startsWith(r'\[') || trimmed.startsWith(r'$$')) {
        final isBracket = trimmed.startsWith(r'\[');
        final closeToken = isBracket ? r'\]' : r'$$';
        final start = i;
        var end = i;
        if (trimmed.endsWith(closeToken) && trimmed.length > 2) {
          end = i;
          i++;
        } else {
          i++;
          while (i < lines.length && !lines[i].contains(closeToken)) {
            i++;
          }
          if (i < lines.length) {
            end = i;
            i++;
          }
        }
        final raw = '${lines.sublist(start, end + 1).join('\n')}\n';
        final prefix = isBracket ? r'\[' : r'$$';
        final suffix = '${isBracket ? r'\]' : r'$$'}\n';
        blocks.add(
          LatexBlock(
            raw,
            LatexBlockKind.equation,
            prefix: prefix,
            suffix: suffix,
            isNumbered: false,
          ),
        );
        continue;
      }

      // Environments: \begin{...}
      final beginMatch = RegExp(
        r'^\\begin\{([a-zA-Z0-9*]+)\}(?:\[(.*?)\])?',
      ).firstMatch(trimmed);
      if (beginMatch != null) {
        final env = beginMatch.group(1)!;
        final optArg = beginMatch.group(2) ?? '';
        final endToken = '\\end{$env}';
        final start = i;
        var end = i;
        while (i < lines.length && !lines[i].contains(endToken)) {
          i++;
        }
        if (i < lines.length) {
          end = i;
          i++;
        }
        final raw = '${lines.sublist(start, end + 1).join('\n')}\n';

        LatexBlockKind kind;
        if (env == 'equation' || env == 'equation*') {
          kind = LatexBlockKind.equation;
        } else if (env == 'align' ||
            env == 'align*' ||
            env == 'aligned' ||
            env == 'gather' ||
            env == 'multline') {
          kind = LatexBlockKind.aligned;
        } else if ({
          'theorem',
          'definition',
          'lemma',
          'proposition',
          'corollary',
          'example',
          'remark',
          'note',
        }.contains(env)) {
          kind = LatexBlockKind.theorem;
        } else if (env == 'proof') {
          kind = LatexBlockKind.proof;
        } else if ({'center', 'flushleft', 'flushright'}.contains(env)) {
          kind = LatexBlockKind.paragraph;
        } else if (env == 'tabular' || env == 'table') {
          kind = LatexBlockKind.table;
        } else if (env == 'figure') {
          kind = LatexBlockKind.figure;
        } else if (env == 'itemize' ||
            env == 'enumerate' ||
            env == 'description') {
          kind = LatexBlockKind.list;
        } else {
          kind = LatexBlockKind.raw;
        }

        final prefixHeader = optArg.isNotEmpty
            ? '\\begin{$env}[$optArg]\n'
            : '\\begin{$env}\n';
        final suffixFooter = '\n\\end{$env}\n';

        blocks.add(
          LatexBlock(
            raw,
            kind,
            prefix: prefixHeader,
            suffix: suffixFooter,
            envName: env,
            envArg: optArg,
            isNumbered: !env.endsWith('*'),
          ),
        );
        continue;
      }

      // Page break
      if (trimmed == r'\newpage' || trimmed == r'\clearpage') {
        blocks.add(LatexBlock('$line\n', LatexBlockKind.pageBreak));
        i++;
        continue;
      }

      // Comments
      if (trimmed.startsWith('%')) {
        blocks.add(LatexBlock('$line\n', LatexBlockKind.comment));
        i++;
        continue;
      }

      // Default: Paragraph text
      final start = i;
      while (i < lines.length &&
          lines[i].trim().isNotEmpty &&
          !lines[i].trim().startsWith(r'\section') &&
          !lines[i].trim().startsWith(r'\subsection') &&
          !lines[i].trim().startsWith(r'\subsubsection') &&
          !lines[i].trim().startsWith(r'\begin{') &&
          lines[i].trim() != r'\end{document}' &&
          !lines[i].trim().startsWith(r'\[') &&
          !lines[i].trim().startsWith(r'$$') &&
          !lines[i].trim().startsWith(r'\newpage') &&
          !lines[i].trim().startsWith(r'%')) {
        i++;
      }
      final raw = '${lines.sublist(start, i).join('\n')}\n';
      blocks.add(LatexBlock(raw, LatexBlockKind.paragraph));
    }

    if (!source.endsWith('\n') && blocks.isNotEmpty) {
      final last = blocks.last;
      blocks[blocks.length - 1] = LatexBlock.raw(
        kind: last.kind,
        source: last.source.substring(0, last.source.length - 1),
        prefix: last.prefix,
        suffix: last.suffix.endsWith('\n')
            ? last.suffix.substring(0, last.suffix.length - 1)
            : last.suffix,
        envName: last.envName,
        envArg: last.envArg,
        isNumbered: last.isNumbered,
      );
    }
    return LatexDocument(blocks);
  }
}
