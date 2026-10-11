import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/rich/math_edit_document.dart';

Iterable<MathPart> leaves(MathPart part) sync* {
  if (part.kind == MathPartKind.text) yield part;
  for (final child in part.children) {
    yield* leaves(child);
  }
}

void main() {
  test('no-edit projection preserves TeX spelling and all source bytes', () {
    for (final source in [
      r'A + \dfrac  {x}{y} + \fraction{keep}{exact}',
      r'\frac12 + x_1^2 + \sqrt[3]{\frac{a}{b}}',
      r'\sum_{i=0}^{n}\alpha + \int_0^\infty e^{-x}\,dx',
      r'\le + \leq + \quad x\!+y',
      r'\{ x \mid x \geq 0 \}',
    ]) {
      final doc = MathEditDocument(source);
      expect(doc.root, isNotNull, reason: source);
      for (final part in leaves(doc.root!)) {
        final text = MathTextProjection(source.substring(part.start, part.end));
        expect(text.edit(text.text), source.substring(part.start, part.end));
      }
      expect(doc.source, source);
    }
  });

  test(
    'nested denominator edits keep unknown commands and fraction variant',
    () {
      const source = r'\custom{keep} + \dfrac  {1 + \sqrt{\frac{x}{y}}}{ z }';
      final doc = MathEditDocument(source);
      final target = leaves(
        doc.root!,
      ).singleWhere((p) => source.substring(p.start, p.end) == 'y');
      expect(
        doc.replace(target.start, target.end, '42', within: target).$1,
        r'\custom{keep} + \dfrac  {1 + \sqrt{\frac{x}{42}}}{ z }',
      );
    },
  );

  test(
    'only the edited unbraced argument gets braces, including empty edit',
    () {
      const source = r'\frac12 + x^2';
      final doc = MathEditDocument(source);
      final target = leaves(
        doc.root!,
      ).firstWhere((p) => p.label == 'Denominator');
      expect(
        doc.replace(target.start, target.end, '20', within: target).$1,
        r'\frac1{20} + x^2',
      );
      expect(
        doc.replace(target.start, target.end, '', within: target).$1,
        r'\frac1{} + x^2',
      );
    },
  );

  test('typing after an unbraced exponent stays outside that exponent', () {
    final doc = MathEditDocument(r'x^2');
    final after = leaves(doc.root!).last;
    expect(after.start, 3);
    expect(doc.replace(3, 3, '+y', within: after).$1, r'x^2+y');
    final exponent = leaves(
      doc.root!,
    ).singleWhere((p) => p.label == 'Exponent');
    expect(doc.replace(3, 3, '+y', within: exponent).$1, r'x^{2+y}');
  });

  test(
    'Greek glyph editing preserves aliases and separates joined control words',
    () {
      final projection = MathTextProjection(r'\alpha+x \le y');
      expect(projection.text, 'α+x ≤y');
      expect(projection.edit('αx ≤y'), r'\alpha x \le y');
      expect(projection.edit('α+x ≤z'), r'\alpha+x \le z');
      expect(MathTextProjection(r'\alpha').edit('αx'), r'\alpha x');
      expect(MathTextProjection('').edit('αx'), r'\alpha x');
      expect(MathTextProjection(r'\alpha x').text, 'αx');
    },
  );

  test('editing part of a spacing macro keeps its surviving visible space', () {
    final projection = MathTextProjection(r'a\quad b');
    expect(projection.text, 'a  b');
    expect(projection.edit('a b'), 'a b');
    expect(projection.edit('a X b'), 'a X b');
    expect(projection.edit('a  c'), r'a\quad c');
  });

  test('literal reserved symbols stay escaped and display without code', () {
    const text = r'{x} + 50% & # $';
    final source = encodeMathText(text);
    expect(source, r'\{x\} + 50\% \& \# \$');
    expect(MathTextProjection(source).text, text);
    expect(MathEditDocument(source).root, isNotNull);
  });

  test('empty-argument deletion preserves all other source bytes', () {
    for (final (source, label, expected) in [
      (
        r'\custom{keep}+\dfrac  { a+1 }{}+z',
        'Denominator',
        r'\custom{keep}+ a+1 +z',
      ),
      (r'x_{}^{2}+y', 'Subscript', r'x^{2}+y'),
      (r'\sqrt[]{x}', 'Root degree', r'\sqrt{x}'),
      (r'\sum_{}^{n}x', 'Lower limit', r'\sum^{n}x'),
    ]) {
      final doc = MathEditDocument(source);
      final leaf = leaves(doc.root!).singleWhere((p) => p.label == label);
      expect(doc.removeEmptyPart(leaf)?.$1, expected);
    }
    final doc = MathEditDocument(r'\frac{a}{b}');
    expect(
      doc.removeEmptyPart(
        leaves(doc.root!).singleWhere((p) => p.label == 'Denominator'),
      ),
      isNull,
    );
  });

  test(
    'unsupported and malformed structures retain source and use safe fallback',
    () {
      for (final source in [
        r'\frac{x}{',
        r'\sqrt',
        r'x^{2',
        r'x^2^3',
        r'\begin{matrix}a&b\\c&d\end{matrix}',
        r'\left(x\right)',
        '% comment\n\\frac{x}{y}',
        'x' * 40000,
        '${'{' * 25}x${'}' * 25}',
      ]) {
        final doc = MathEditDocument(source);
        expect(
          doc.root,
          isNull,
          reason: source.substring(0, source.length.clamp(0, 80)),
        );
        expect(doc.source, source);
      }
    },
  );
}
