import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/rich/callout_block.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';

void main() {
  group('Callout Parser', () {
    test(
      'academic callouts remain ordinary source-preserving Markdown blocks',
      () {
        for (final name in [
          'DEFINITION',
          'THEOREM',
          'LEMMA',
          'PROPOSITION',
          'COROLLARY',
          'PROOF',
          'EXAMPLE',
          'COUNTEREXAMPLE',
          'REMARK',
          'QUESTION',
        ]) {
          final source = '> [!$name]\n> A useful result.\n';
          expect(ParsedCallout.parse(source).type.name, name);
          expect(ParsedCallout.parse(source).toMarkdown(), source);
          expect(MarkdownDocument.parse(source).source, source);
        }
      },
    );

    test('supports optional academic numbering in headerDisplay', () {
      final def = ParsedCallout.parse('> [!DEFINITION] 3.2 Relations\n> Body');
      expect(def.headerDisplay, 'Definition 3.2 Relations');

      final thm = ParsedCallout.parse('> [!THEOREM] 4.1\n> Body');
      expect(thm.headerDisplay, 'Theorem 4.1');

      final ex = ParsedCallout.parse('> [!EXAMPLE] Equivalence\n> Body');
      expect(ex.headerDisplay, 'Example: Equivalence');

      final alreadyPrefixed = ParsedCallout.parse(
        '> [!LEMMA] Lemma 2.1\n> Body',
      );
      expect(alreadyPrefixed.headerDisplay, 'Lemma 2.1');
    });
    test('detects and parses standard callouts', () {
      const source =
          '> [!NOTE] Architecture Review\n> This is a crucial note.\n> Second line.\n';
      expect(ParsedCallout.isCallout(source), isTrue);

      final parsed = ParsedCallout.parse(source);
      expect(parsed.type, CalloutType.note);
      expect(parsed.title, 'Architecture Review');
      expect(parsed.body, 'This is a crucial note.\nSecond line.');
    });

    test('parses all callout types correctly', () {
      for (final type in CalloutType.values) {
        final text = '> [!${type.name}]\n> Content\n';
        final parsed = ParsedCallout.parse(text);
        expect(parsed.type, type);
      }
    });

    test('reconstructs clean standard markdown', () {
      const original =
          '> [!WARNING] Caution Ahead\n> Don\'t delete this file.\n';
      final parsed = ParsedCallout.parse(original);
      final markdown = parsed.toMarkdown();
      expect(markdown, original);
    });

    test('MarkdownDocument parses callout as MarkdownBlockKind.callout', () {
      const docSource =
          '# Title\n\n> [!TIP]\n> Remember to save.\n\nParagraph text.\n';
      final doc = MarkdownDocument.parse(docSource);
      final calloutBlock = doc.blocks.firstWhere(
        (b) => b.kind == MarkdownBlockKind.callout,
      );
      expect(calloutBlock, isNotNull);
      expect(calloutBlock.source, contains('> [!TIP]'));
    });
  });

  group('CalloutBlock Widget', () {
    testWidgets('renders callout icon, title, and body', (tester) async {
      String current = '> [!IMPORTANT]\n> Key takeaway.\n';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => CalloutBlock(
                source: current,
                onChanged: (v) => setState(() => current = v),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Important'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Updated takeaway.');
      await tester.pumpAndSettle();

      expect(current, contains('> Updated takeaway.'));
    });
  });
}
