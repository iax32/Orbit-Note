import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/finance.dart';
import 'package:orbit_note/domain/object_connections.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/memory_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var sequence = 0;
  UniversalObject record(
    Map<String, dynamic> data, {
    String? id,
  }) => UniversalObject(
    id:
        id ??
        '00000000-0000-4000-8000-${(++sequence).toString().padLeft(12, '0')}',
    workspaceId: '11111111-1111-4111-8111-111111111111',
    typeId: 'orbit.note',
    title: '${data['kind']}',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    properties: {
      'finance': {'version': 1, 'currency': 'EUR', ...data},
    },
  );
  Map<String, dynamic> transaction(
    String account,
    int amount, {
    String direction = 'expense',
    String date = '2026-10-26',
  }) => {
    'kind': 'transaction',
    'direction': direction,
    'accountId': account,
    'amountMinor': amount,
    'date': date,
    'category': 'Groceries',
  };

  test('money stays exact and rejects rounding/grouping/unsafe precision', () {
    expect(parseMoney('0.10', 'EUR') + parseMoney('0,20', 'EUR'), 30);
    expect(parseMoney('-12.50', 'EUR', signed: true), -1250);
    expect(moneyText(-1250, 'EUR'), '-12.50 EUR');
    expect(parseMoney('123', 'JPY'), 123);
    expect(moneyText(123, 'JPY'), '123 JPY');
    for (final amount in [
      '1.001',
      '1,234.56',
      'NaN',
      'Infinity',
      '-1',
      '1e4',
      '.5',
      '999999999999999',
    ]) {
      expect(
        () => parseMoney(amount, 'EUR'),
        throwsFormatException,
        reason: amount,
      );
    }
    expect(() => parseMoney('1.0', 'JPY'), throwsFormatException);
    expect(() => addFinanceMoney(maxFinanceTotal, 1), throwsFormatException);
  });

  test('transfers move balances once and never inflate income/expenses', () {
    final a = record({'kind': 'account', 'openingMinor': 100000});
    final b = record({'kind': 'account', 'openingMinor': -5000});
    final usd = record({
      'kind': 'account',
      'openingMinor': 50000,
      'currency': 'USD',
    });
    final index = FinanceIndex([
      a,
      b,
      usd,
      record(transaction(a.id, 10000, direction: 'income')),
      record(transaction(a.id, 1250)),
      record({
        ...transaction(a.id, 20000, direction: 'transfer'),
        'toAccountId': b.id,
      }),
      record(transaction(a.id, 5000, date: '2026-11-01')),
      record({...transaction(usd.id, 100), 'currency': 'USD'}),
    ]);
    expect(index.balance(a, through: '2026-10-31'), 88750);
    expect(index.balance(b), 15000);
    expect(index.balance(a, clearedOnly: true), 100000);
    expect(index.summary('2026-10', 'EUR').income, 10000);
    expect(index.summary('2026-10', 'EUR').expenses, 1250);
    expect(index.summary('2026-10', 'USD').expenses, 100);
    expect(index.summary('2026-11', 'EUR').expenses, 5000);
    expect(index.report('2026-10', 'EUR'), contains('Transfers are excluded'));
  });

  test(
    'recurring bills keep month-end/leap anchors and ignore paid occurrences',
    () {
      final bill = record({
        'kind': 'bill',
        'accountId': 'a',
        'startDate': '2024-01-31',
        'frequency': 'monthly',
        'direction': 'expense',
        'amountMinor': 100,
      });
      expect(FinanceIndex([bill]).dueDates(bill, DateTime(2024, 3, 31)), [
        '2024-01-31',
        '2024-02-29',
        '2024-03-31',
      ]);
      final paid = record({
        ...transaction('a', 100, date: '2024-02-29'),
        'billId': bill.id,
        'occurrence': '2024-02-29',
      });
      expect(FinanceIndex([bill, paid]).dueDates(bill, DateTime(2024, 3, 31)), [
        '2024-01-31',
        '2024-03-31',
      ]);
      final leap = record({
        ...financeData(bill),
        'startDate': '2024-02-29',
        'frequency': 'yearly',
      });
      expect(
        FinanceIndex([leap]).dueDates(leap, DateTime(2028, 2, 29)).last,
        '2028-02-29',
      );
      final week = record({
        ...financeData(bill),
        'startDate': '2026-03-22',
        'frequency': 'weekly',
      });
      expect(FinanceIndex([week]).dueDates(week, DateTime(2026, 4, 5)), [
        '2026-03-22',
        '2026-03-29',
        '2026-04-05',
      ]);
    },
  );

  test('CSV handles quotes and multiline memo and refuses malformed input', () {
    final rows = parseFinanceCsv(
      'date,type,amount,payee,memo\r\n2026-10-26,expense,12.50,"Cafe, Vienna","line 1\nline ""2"""\r\n',
    );
    expect(rows.single['payee'], 'Cafe, Vienna');
    expect(rows.single['memo'], 'line 1\nline "2"');
    for (final text in [
      'date,type,amount\na,b',
      'date,type,amount\na,b,"unclosed',
      'date,date,type,amount',
      'date,type,amount\na,b,"x"oops',
    ]) {
      expect(() => parseFinanceCsv(text), throwsFormatException);
    }
    expect(
      () => parseFinanceCsv(
        'date,type,amount\n${List.filled(501, '2026-10-26,expense,1').join('\n')}',
      ),
      throwsFormatException,
    );
    final exported = financeCsv([
      record({...transaction('a', 123), 'payee': '=1+1'}),
    ]);
    expect(exported, contains("'=1+1"));
    expect(parseFinanceCsv(exported).single['amount'], '1.23');
  });

  test(
    'malformed/future records are visible issues; orphaned transactions retained',
    () {
      final malformed = record({
        'kind': 'account',
        'openingMinor': 0,
        'version': 2,
      });
      final expense = record(transaction('missing', 500));
      final index = FinanceIndex([malformed, expense]);
      expect(index.issues, hasLength(2));
      expect(index.summary('2026-10', 'EUR').expenses, 500);
    },
  );

  late MemoryStore store;
  late WorkspaceRepository repo;
  late ProviderContainer container;
  late WorkspaceController c;
  setUp(() async {
    store = MemoryStore();
    repo = WorkspaceRepository(store: store, index: MemoryObjectIndex());
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    c = container.read(workspaceProvider.notifier);
    await c.initialize();
  });
  tearDown(() {
    c.cancelAllTimers();
    container.dispose();
  });
  Future<UniversalObject> account(
    String title, {
    String currency = 'EUR',
  }) async => (await c.createFinance(title, {
    'kind': 'account',
    'currency': currency,
    'openingMinor': 100000,
  }))!;

  test(
    'commands refuse cross-currency/self transfers and used-account currency changes',
    () async {
      final eur = await account('Bank'),
          usd = await account('Dollar', currency: 'USD');
      final fields = {
        ...transaction(eur.id, 100, direction: 'transfer'),
        'currency': 'EUR',
        'toAccountId': usd.id,
      };
      expect(await c.createFinance('Bad conversion', fields), isNull);
      expect(
        await c.createFinance('Self', {...fields, 'toAccountId': eur.id}),
        isNull,
      );
      final expense = await c.createFinance('Groceries', {
        ...transaction(eur.id, 100),
        'currency': 'EUR',
      });
      expect(expense, isNotNull);
      expect(await c.saveFinance(eur, eur.title, {'currency': 'USD'}), isFalse);
      expect(c.financeIndex.balance(c.find(eur.id)!), 99900);
      final expenseId = expense!.id;
      expect(await c.trash(expenseId), isTrue);
      expect(
        await c.saveFinance(c.find(eur.id)!, eur.title, {'currency': 'USD'}),
        isFalse,
      );
      expect(await c.restore(expenseId), isTrue);
      expect(c.financeIndex.balance(c.find(eur.id)!), 99900);
      final connections = ObjectConnectionResolver().resolve(c.activeObjects);
      expect(
        connections.any(
          (edge) => edge.source.id == expenseId && edge.target.id == eur.id,
        ),
        isTrue,
      );
    },
  );

  test(
    'CSV preview validates all rows, imports duplicate occurrences, resumes idempotently',
    () async {
      final a = await account('Bank');
      const csv =
          'date,type,amount,category,payee,memo\n2026-10-26,expense,12.50,Groceries,Shop,food\n2026-10-26,expense,12.50,Groceries,Shop,food';
      expect(c.previewFinanceImport(csv, a.id), hasLength(2));
      final first = await c.importFinanceCsv(csv, a.id);
      expect(first, (added: 2, skipped: 0));
      expect(await c.importFinanceCsv(csv, a.id), (added: 0, skipped: 2));
      expect(c.financeIndex.summary('2026-10', 'EUR').expenses, 2500);
      final removed = c.financeIndex.transactions.first;
      await c.trash(removed.id);
      expect(await c.importFinanceCsv(csv, a.id), (added: 0, skipped: 2));
      expect(c.financeIndex.summary('2026-10', 'EUR').expenses, 1250);
      final before = repo.objects.length;
      expect(
        await c.importFinanceCsv('$csv\nnot-a-date,expense,1,Other,X,', a.id),
        isNull,
      );
      expect(repo.objects.length, before);
      expect(await c.restore(removed.id), isTrue);
      expect(c.financeIndex.summary('2026-10', 'EUR').expenses, 2500);
    },
  );

  test(
    'bill recording is exactly one note per occurrence and schedule edits are guarded',
    () async {
      final a = await account('Bank');
      final bill = (await c.createFinance('Rent', {
        'kind': 'bill',
        'currency': 'EUR',
        'accountId': a.id,
        'startDate': '2026-01-31',
        'frequency': 'monthly',
        'direction': 'expense',
        'amountMinor': 50000,
      }))!;
      final results = await Future.wait([
        c.recordBill(bill, '2026-02-28'),
        c.recordBill(bill, '2026-02-28'),
      ]);
      expect(results.whereType<UniversalObject>(), hasLength(1));
      final first = results.whereType<UniversalObject>().single;
      final repeated = await c.recordBill(bill, '2026-02-28');
      expect(repeated, isNotNull, reason: c.error);
      expect(repeated!.id, first.id);
      expect(c.financeIndex.transactions, hasLength(1));
      expect(
        await c.saveFinance(bill, bill.title, {'startDate': '2026-02-01'}),
        isFalse,
      );
      await c.trash(first.id);
      expect(await c.recordBill(bill, '2026-02-28'), isNull);
      expect(c.error, contains('Trash'));
    },
  );

  test(
    'CSV cannot apply a different currency than the reviewed preview',
    () async {
      final a = await account('Import destination');
      const csv = 'date,type,amount\n2026-10-26,expense,12.50';
      final plan = c.previewFinanceImport(csv, a.id);
      expect(await c.saveFinance(a, a.title, {'currency': 'USD'}), isTrue);
      expect(await c.importFinanceCsv(csv, a.id, expectedRows: plan), isNull);
      expect(c.financeIndex.transactions, isEmpty);
      expect(c.error, contains('after preview'));
    },
  );

  test(
    'budgets reject normalized duplicates; goals do not change account balance',
    () async {
      final a = await account('Bank');
      final budget = await c.createFinance('Food', {
        'kind': 'budget',
        'currency': 'EUR',
        'month': '2026-10',
        'category': 'Groceries',
        'limitMinor': 30000,
      });
      expect(budget, isNotNull);
      expect(
        await c.createFinance('Duplicate', {
          ...financeData(budget!),
          'category': ' groceries ',
        }),
        isNull,
      );
      await c.createFinance('Emergency fund', {
        'kind': 'goal',
        'currency': 'EUR',
        'targetMinor': 300000,
        'savedMinor': 100000,
      });
      expect(c.financeIndex.balance(a), 100000);
    },
  );

  test(
    'reopen preserves exact money/unknown data; stale saves and failed writes retain original',
    () async {
      final a = await account('Bank');
      final expense = (await c.createFinance('Food', {
        ...transaction(a.id, 1234),
        'currency': 'EUR',
        'future': {'retained': true},
      }, body: 'Original memo'))!;
      expect(
        await c.saveFinance(expense, 'Food updated', {'amountMinor': 1500}),
        isTrue,
      );
      expect(
        await c.saveFinance(expense, 'Stale', {'amountMinor': 2500}),
        isFalse,
      );
      await repo.refresh();
      c.mergeRepositoryObjects();
      expect(financeData(c.find(expense.id)!)['future'], {'retained': true});
      expect(financeData(c.find(expense.id)!)['amountMinor'], 1500);
      expect(c.find(expense.id)!.body, 'Original memo');
      store.failWrites = true;
      expect(
        await c.createFinance('No phantom', {
          ...transaction(a.id, 1000),
          'currency': 'EUR',
        }),
        isNull,
      );
      store.failWrites = false;
      expect(c.financeIndex.transactions, hasLength(1));
      final restored = WorkspaceRepository(
        store: MemoryStore()..files.addAll(store.files),
        index: MemoryObjectIndex(),
      );
      await restored.initialize();
      expect(
        FinanceIndex(
          restored.objects,
        ).balance(restored.objects.firstWhere((o) => o.id == a.id)),
        98500,
      );
      await restored.close();
    },
  );

  test(
    'queued finance edits snapshot inputs and cleared status reconciles balances',
    () async {
      final a = await account('Bank');
      final entry = (await c.createFinance('Pending', {
        ...transaction(a.id, 100),
        'currency': 'EUR',
        'cleared': false,
      }))!;
      expect(c.financeIndex.balance(a), 99900);
      expect(c.financeIndex.balance(a, clearedOnly: true), 100000);
      final gate = Completer<void>();
      store.writeGate = gate.future;
      final updates = <String, dynamic>{'amountMinor': 200, 'cleared': true};
      final pending = c.saveFinance(entry, entry.title, updates);
      updates['amountMinor'] = 99999;
      gate.complete();
      expect(await pending, isTrue);
      store.writeGate = null;
      expect(c.financeIndex.balance(a, clearedOnly: true), 99800);
      expect(financeData(c.find(entry.id)!)['amountMinor'], 200);
    },
  );

  test(
    'large ledger totals remain exact within a bounded calculation time',
    () {
      final a = record({'kind': 'account', 'openingMinor': 0});
      final ledger = [
        a,
        for (var i = 0; i < 5000; i++) record(transaction(a.id, 11)),
      ];
      final watch = Stopwatch()..start();
      final index = FinanceIndex(ledger);
      expect(index.summary('2026-10', 'EUR').expenses, 55000);
      expect(index.balance(a), -55000);
      watch.stop();
      // Broad regression guard, not a device frame-time promise.
      expect(watch.elapsedMilliseconds, lessThan(5000));
    },
  );

  test(
    'finance snapshots refresh on edits, trash, undo and in-place replacements',
    () async {
      final a = await account('Bank');
      final entry = (await c.createFinance('Food', {
        ...transaction(a.id, 100),
        'currency': 'EUR',
      }))!;
      final before = c.financeIndex;
      expect(identical(c.financeIndex, before), isTrue);
      expect(
        await c.saveFinance(entry, 'Updated', {'amountMinor': 200}),
        isTrue,
      );
      expect(identical(c.financeIndex, before), isFalse);
      expect(c.financeIndex.balance(a), 99800);
      expect(await c.trash(entry.id), isTrue);
      expect(c.financeIndex.balance(a), 100000);
      expect(await c.restore(entry.id), isTrue);
      expect(c.financeIndex.balance(a), 99800);
      final cached = c.financeIndex;
      final position = c.objects.indexWhere((o) => o.id == entry.id);
      final current = c.objects[position];
      c.objects[position] = current.copyWith(
        properties: {
          ...current.properties,
          'finance': {...financeData(current), 'amountMinor': 300},
        },
      );
      expect(identical(c.financeIndex, cached), isFalse);
      expect(c.financeIndex.balance(a), 99700);
    },
  );
}
