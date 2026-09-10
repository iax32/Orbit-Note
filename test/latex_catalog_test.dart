import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/rich/latex_catalog.dart';

void main() {
  group('LaTeX Catalog & Templates', () {
    test('contains comprehensive math templates', () {
      expect(latexTemplates.isNotEmpty, isTrue);
      final names = latexTemplates.map((e) => e.name).toSet();
      expect(names.contains('Fraction'), isTrue);
      expect(names.contains('Square root'), isTrue);
      expect(names.contains('Sum with limits'), isTrue);
      expect(names.contains('Definite integral'), isTrue);
      expect(names.contains('Limit'), isTrue);
      expect(names.contains('Matrix 2 by 2'), isTrue);
    });

    test('catalog contains all registered symbols from flutter_math_fork', () {
      expect(latexCatalog.length, greaterThan(200));

      final categories = latexCatalog.map((e) => e.category).toSet();
      expect(categories.isNotEmpty, isTrue);
      expect(categories.contains('Structures'), isTrue);
      expect(categories.contains('Greek'), isTrue);
      expect(categories.contains('Arrows'), isTrue);

      for (final entry in latexCatalog) {
        expect(entry.name.isNotEmpty, isTrue);
        expect(entry.source.isNotEmpty, isTrue);
        expect(entry.category.isNotEmpty, isTrue);
      }
    });

    test('Greek alphabet symbols are present', () {
      final greekSources = latexCatalog
          .where((e) => e.category == 'Greek')
          .map((e) => e.source)
          .toSet();

      expect(greekSources.contains(r'\alpha'), isTrue);
      expect(greekSources.contains(r'\beta'), isTrue);
      expect(greekSources.contains(r'\gamma'), isTrue);
      expect(greekSources.contains(r'\theta'), isTrue);
      expect(greekSources.contains(r'\pi'), isTrue);
      expect(greekSources.contains(r'\sigma'), isTrue);
      expect(greekSources.contains(r'\omega'), isTrue);
      expect(greekSources.contains(r'\Gamma'), isTrue);
      expect(greekSources.contains(r'\Delta'), isTrue);
      expect(greekSources.contains(r'\Omega'), isTrue);
    });

    test('Math relations and operators are present', () {
      final sources = latexCatalog.map((e) => e.source).toSet();
      expect(sources.contains(r'\leq'), isTrue);
      expect(sources.contains(r'\geq'), isTrue);
      expect(sources.contains(r'\neq'), isTrue);
      expect(sources.contains(r'\approx'), isTrue);
      expect(sources.contains(r'\times'), isTrue);
      expect(sources.contains(r'\div'), isTrue);
      expect(sources.contains(r'\pm'), isTrue);
      expect(sources.contains(r'\infty'), isTrue);
    });
  });
}
