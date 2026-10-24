import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercise the visible settings search in both compact and desktop layouts.
Future<void> searchSettings(WidgetTester tester, String query) async {
  final search = find.byKey(const ValueKey('settings-search'));
  if (search.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      search,
      -400,
      maxScrolls: 60,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('settings-content')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(search);
  await tester.enterText(search, query);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump(const Duration(milliseconds: 350));
}
