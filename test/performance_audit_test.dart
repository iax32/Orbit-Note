import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:orbit_note/domain/finance.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/notes/note_find_index.dart';

void main() {
  test('large multi-account dashboard and repeated Unicode find remain exact', () {
    UniversalObject record(String id, Map<String, dynamic> data) =>
        UniversalObject(
          id: id,
          workspaceId: 'synthetic',
          typeId: 'orbit.note',
          title: id,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          properties: {
            'finance': {'version': 1, 'currency': 'EUR', ...data},
          },
        );
    final accounts = [
      for (var i = 0; i < 80; i++)
        record('account-$i', {'kind': 'account', 'openingMinor': 10000}),
    ];
    final objects = [
      ...accounts,
      for (var i = 0; i < 8000; i++)
        record('transaction-$i', {
          'kind': 'transaction',
          'direction': 'expense',
          'amountMinor': 11,
          'accountId': accounts[i % accounts.length].id,
          'date': '2026-10-26',
          'category': 'Groceries',
          'cleared': i.isEven,
        }),
    ];
    final watch = Stopwatch()..start();
    final index = FinanceIndex(objects);
    final construction = watch.elapsedMicroseconds;
    final rebuilt = FinanceIndex(objects);
    expect(rebuilt.transactions, hasLength(8000));
    final reuse = watch.elapsedMicroseconds - construction;
    for (var pass = 0; pass < 3; pass++) {
      for (var i = 0; i < accounts.length; i++) {
        expect(index.balance(accounts[i]), 8900);
        expect(
          index.balance(accounts[i], clearedOnly: true),
          i.isEven ? 8900 : 10000,
        );
      }
      expect(index.summary('2026-10', 'EUR').expenses, 88000);
    }
    // Diagnostic measurements, not a hardware frame-time guarantee.
    debugPrint(
      'Finance audit: cold index=$construction us, warm index=$reuse us, dashboard=${watch.elapsedMicroseconds - construction - reuse} us',
    );
    final source = List.generate(
      2000,
      (i) => 'Paragraph $i: **Straße café 😀** needle.\n\n',
    ).join();
    watch.reset();
    final find = NoteFindIndex(source, rich: true);
    final build = watch.elapsedMicroseconds;
    for (var i = 0; i < 3; i++) {
      for (final query in ['strasse', 'café', '😀', 'needle']) {
        expect(find.matches(query), hasLength(2000));
      }
    }
    debugPrint(
      'Find audit: build=$build us, queries=${watch.elapsedMicroseconds - build} us',
    );
  });
}
