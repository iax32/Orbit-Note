import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:orbit_note/features/pdf/pdf_outline_dialog.dart';

void main() {
  testWidgets(
    'outline searches parent headings and returns exact destinations',
    (tester) async {
      const destination = PdfDest(7, PdfDestCommand.xyz, [20, 400, 1.5]);
      PdfDest? chosen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Outline'),
                onPressed: () async {
                  chosen = await showDialog<PdfDest>(
                    context: context,
                    builder: (_) => const PdfOutlineDialog(
                      nodes: [
                        PdfOutlineNode(
                          title: 'Biology',
                          dest: null,
                          children: [
                            PdfOutlineNode(
                              title: 'Introduction',
                              dest: destination,
                              children: [],
                            ),
                          ],
                        ),
                        PdfOutlineNode(
                          title: 'Physics',
                          dest: null,
                          children: [
                            PdfOutlineNode(
                              title: 'Introduction',
                              dest: PdfDest(9, PdfDestCommand.fit, null),
                              children: [],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Outline'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  biology INTRO  ');
      await tester.pumpAndSettle();
      expect(find.text('Introduction'), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(chosen, destination);
    },
  );

  testWidgets(
    'deep outlines remain searchable and keyboard selection scrolls',
    (tester) async {
      var deep = const PdfOutlineNode(
        title: 'Deep target',
        dest: PdfDest(42, PdfDestCommand.fit, null),
        children: [],
      );
      for (var i = 0; i < 15; i++) {
        deep = PdfOutlineNode(title: 'Group $i', dest: null, children: [deep]);
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfOutlineDialog(
              nodes: [
                deep,
                for (var i = 0; i < 50; i++)
                  PdfOutlineNode(
                    title: 'Section $i',
                    dest: PdfDest(i + 1, PdfDestCommand.fit, null),
                    children: [],
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Deep target');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Deep target'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Section');
      await tester.pumpAndSettle();
      for (var i = 0; i < 30; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
      }
      // Variable-height rows reveal their measured geometry after layout.
      await tester.pumpAndSettle();
      expect(find.text('Section 30'), findsOneWidget);
      expect(
        tester
            .widget<ListTile>(
              find.ancestor(
                of: find.text('Section 30'),
                matching: find.byType(ListTile),
              ),
            )
            .selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty outline explains missing headings at large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const Scaffold(body: PdfOutlineDialog(nodes: [])),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('This PDF has no embedded outline.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
