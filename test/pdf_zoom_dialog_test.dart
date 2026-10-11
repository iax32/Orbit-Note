import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/pdf/pdf_zoom_dialog.dart';

void main() {
  testWidgets(
    'custom zoom rejects invalid input and accepts a decimal percentage',
    (tester) async {
      double? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showDialog<double>(
                    context: context,
                    builder: (_) => const PdfZoomDialog(
                      current: 100,
                      minimum: 10,
                      maximum: 800,
                    ),
                  );
                },
                child: const Text('Zoom'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Zoom'));
      await tester.pumpAndSettle();
      for (final input in ['', 'NaN', 'Infinity', '0', '801', 'abc']) {
        await tester.enterText(find.byType(TextField), input);
        await tester.tap(find.text('Apply zoom'));
        await tester.pumpAndSettle();
        expect(find.text('Enter 10–800%.'), findsOneWidget);
        expect(result, isNull);
      }
      await tester.enterText(find.byType(TextField), ' 137.5% ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(result, 1.375);
      expect(find.byType(PdfZoomDialog), findsNothing);
    },
  );
}
