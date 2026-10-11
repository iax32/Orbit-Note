import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/latex/latex_document.dart';
import 'package:orbit_note/features/notes/latex/latex_templates.dart';
import 'package:orbit_note/features/notes/latex/latex_converter.dart';
import 'package:orbit_note/features/notes/latex/latex_syntax_highlighter.dart';

void main() {
  group('LatexDocument Parser & Serializer', () {
    test('parses and round-trips university assignment template', () {
      final template = LatexTemplates.assignment;
      final doc = LatexDocument.fromLatex(template.content);

      expect(doc.title, equals('MATH 301: Real Analysis --- Homework 1'));
      expect(doc.author, equals('Student Name (ID: 12345678)'));
      expect(doc.documentClass, equals('article'));
      expect(doc.packages, contains('amsmath'));
      expect(doc.packages, contains('amssymb'));
      expect(doc.packages, contains('amsthm'));

      // Check blocks
      expect(doc.blocks.any((b) => b.type == LatexBlockType.section), isTrue);
      expect(doc.blocks.any((b) => b.type == LatexBlockType.proof), isTrue);
      expect(doc.blocks.any((b) => b.type == LatexBlockType.equation), isTrue);
      expect(doc.blocks.any((b) => b.type == LatexBlockType.aligned), isTrue);

      final serialized = doc.toLatex();
      expect(serialized, contains(r'\documentclass'));
      expect(serialized, contains(r'\begin{document}'));
      expect(serialized, contains(r'\end{document}'));
      expect(serialized, contains(r'\begin{proof}'));
    });

    test('preserves comments, raw environments, and custom preambles', () {
      const customTex = r'''
\documentclass[12pt,letterpaper]{report}
\usepackage{physics}
% Custom macro
\newcommand{\norm}[1]{\left\|#1\right\|}

\begin{document}
\title{Custom Physics Report}
\author{A. Researcher}
\date{\today}
\maketitle

\section{Introduction}
This is a paragraph with $\norm{x}$ vector norm.

% Notice to graders
\begin{customenv}
Custom block content
\end{customenv}

\end{document}
''';

      final doc = LatexDocument.fromLatex(customTex);
      expect(doc.documentClass, equals('report'));
      expect(doc.paperSize, equals('letterpaper'));
      expect(doc.fontSize, equals('12pt'));
      expect(doc.packages, contains('physics'));
      expect(doc.preamble, contains(r'\newcommand{\norm}'));

      final serialized = doc.toLatex();
      expect(serialized, contains(r'\newcommand{\norm}'));
      expect(serialized, contains(r'\begin{customenv}'));
      expect(serialized, contains('Custom block content'));
      expect(serialized, contains(r'\end{customenv}'));
    });
  });

  group('LatexConverter (Markdown <-> LaTeX)', () {
    test('converts markdown to latex with math blocks', () {
      const md = '''
# Real Analysis

Let \$f: [a, b] \\to \\mathbb{R}\$ be continuous.

\$\$
\\int_a^b f(x) dx \\le M(b - a)
\$\$

- First property
- Second property
''';

      final res = LatexConverter.markdownToLatex(md, title: 'Real Analysis');
      expect(res.latex, contains(r'\section{Real Analysis}'));
      expect(res.latex, contains(r'\['));
      expect(res.latex, contains(r'\int_a^b f(x) dx'));
      expect(res.latex, contains(r'\begin{itemize}'));
      expect(res.latex, contains(r'\item First property'));
    });

    test('converts latex back to markdown losslessly', () {
      final doc = LatexDocument([
        LatexBlock.fromFields(
          type: LatexBlockType.section,
          rawContent: 'Metric Spaces',
        ),
        LatexBlock.fromFields(
          type: LatexBlockType.paragraph,
          rawContent: 'A metric space is a pair (X, d).',
        ),
        LatexBlock.fromFields(
          type: LatexBlockType.equation,
          rawContent: r'd(x, y) \ge 0',
        ),
      ]);

      final res = LatexConverter.latexToMarkdown(doc.toLatex());
      expect(res.markdown, contains('# Metric Spaces'));
      expect(res.markdown, contains('A metric space is a pair (X, d).'));
      expect(res.markdown, contains(r'$$'));
      expect(res.markdown, contains(r'd(x, y) \ge 0'));
    });
  });

  group('LatexAutocomplete', () {
    test('suggests math environments and commands', () {
      final items = LatexAutocomplete.getSuggestions(
        text: r'\begin{eq',
        cursorPosition: 9,
      );
      expect(items.any((i) => i.label.contains('equation')), isTrue);

      final fracs = LatexAutocomplete.getSuggestions(
        text: r'\fr',
        cursorPosition: 3,
      );
      expect(fracs.any((i) => i.label == r'\frac'), isTrue);
    });

    test('suggests document labels for references', () {
      const docText =
          "\\begin{equation}\\label{eq:euler}\ne^{i\\pi} + 1 = 0\n\\end{equation}\nAs shown in \\ref{eq:";
      final refs = LatexAutocomplete.getSuggestions(
        text: docText,
        cursorPosition: docText.length,
      );
      expect(refs.any((i) => i.label == 'eq:euler'), isTrue);
    });
  });
}
