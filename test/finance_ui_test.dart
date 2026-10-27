import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/finance.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/domain/calendar_event.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/features/workspace/finance_workspace.dart';
import 'support/memory_store.dart';
import 'support/capture_ui.dart';

void main() {
  late MemoryStore store;
  late ProviderContainer container;
  late WorkspaceController c;
  setUp(() async {
    store = MemoryStore();
    final repository = WorkspaceRepository(
      store: store,
      index: MemoryObjectIndex(),
    );
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repository)],
    );
    c = container.read(workspaceProvider.notifier);
    await c.initialize();
  });
  tearDown(() {
    c.cancelAllTimers();
    container.dispose();
  });
  Future<void> mount(
    WidgetTester t, {
    Size size = const Size(1400, 1000),
    double scale = 1,
    bool editor = false,
  }) async {
    await t.binding.setSurfaceSize(size);
    addTearDown(() => t.binding.setSurfaceSize(null));
    await prepareCapture(t);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: orbitTheme(preset: 'paper'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => editor
                    ? showFinanceEditor(
                        context,
                        c,
                        'account',
                        initialMonth: '2026-10',
                        initialCurrency: 'EUR',
                      )
                    : showFinanceWorkspace(context, c),
                child: const Text('Open finance'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open finance'));
    await t.pumpAndSettle();
  }

  Future<void> seed() async {
    final today = calendarDate(DateTime.now()),
        month = calendarDate(DateTime.now()).substring(0, 7);
    final a = (await c.createFinance('Everyday account', {
      'kind': 'account',
      'currency': 'EUR',
      'openingMinor': 240000,
    }))!;
    await c.createFinance('Salary', {
      'kind': 'transaction',
      'currency': 'EUR',
      'accountId': a.id,
      'direction': 'income',
      'amountMinor': 180000,
      'date': today,
      'category': 'Salary',
      'cleared': true,
    });
    await c.createFinance('Weekly groceries', {
      'kind': 'transaction',
      'currency': 'EUR',
      'accountId': a.id,
      'direction': 'expense',
      'amountMinor': 5349,
      'date': today,
      'category': 'Groceries',
      'payee': 'Local market',
    }, body: 'Food for this week.');
    await c.createFinance('Food budget', {
      'kind': 'budget',
      'currency': 'EUR',
      'month': month,
      'limitMinor': 30000,
      'category': 'Groceries',
    });
    await c.createFinance('Emergency reserve', {
      'kind': 'goal',
      'currency': 'EUR',
      'targetMinor': 300000,
      'savedMinor': 120000,
    });
    await c.createFinance('Internet', {
      'kind': 'bill',
      'currency': 'EUR',
      'accountId': a.id,
      'direction': 'expense',
      'amountMinor': 2990,
      'startDate': today,
      'frequency': 'monthly',
    });
  }

  Future<void> save(WidgetTester t) async {
    await t.runAsync(() async {
      await t.tap(find.widgetWithText(FilledButton, 'Save'));
      await c.flushAll();
    });
    await t.pumpAndSettle();
  }

  testWidgets(
    'all finance sections render and a receipt-ready transaction saves',
    (t) async {
      await t.runAsync(seed);
      await mount(t);
      await captureUi(
        t,
        'finance-overview',
        target: find.byKey(const ValueKey('finance-capture')),
      );
      for (final section in [
        'Transactions',
        'Accounts',
        'Budgets',
        'Bills',
        'Goals',
      ]) {
        await t.ensureVisible(find.widgetWithText(ChoiceChip, section));
        await t.tap(find.widgetWithText(ChoiceChip, section));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: section);
      }
      await t.ensureVisible(find.widgetWithText(ChoiceChip, 'Transactions'));
      await t.tap(find.widgetWithText(ChoiceChip, 'Transactions'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Add transaction'));
      await t.tap(find.text('Add transaction'));
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Train ticket',
      );
      await t.enterText(
        find.widgetWithText(TextFormField, 'Amount · EUR'),
        '4,50',
      );
      await save(t);
      expect(find.text('New transaction'), findsNothing);
      expect(
        c.financeIndex.transactions.any(
          (o) =>
              o.title == 'Train ticket' && financeData(o)['amountMinor'] == 450,
        ),
        isTrue,
      );
      expect(t.takeException(), isNull);
    },
  );

  for (final viewport in [const Size(390, 844), const Size(568, 320)]) {
    testWidgets(
      'finance and account entry remain reachable at $viewport enlarged text',
      (t) async {
        await t.runAsync(seed);
        await mount(t, size: viewport, scale: 2);
        expect(t.takeException(), isNull);
        await t.ensureVisible(find.widgetWithText(ChoiceChip, 'Accounts'));
        await t.tap(find.widgetWithText(ChoiceChip, 'Accounts'));
        await t.pumpAndSettle();
        await t.ensureVisible(find.text('Add account'));
        await t.tap(find.text('Add account'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.enterText(
          find.widgetWithText(TextFormField, 'Title'),
          'Cash wallet',
        );
        await t.ensureVisible(
          find.widgetWithText(TextFormField, 'Starting balance · EUR'),
        );
        await t.enterText(
          find.widgetWithText(TextFormField, 'Starting balance · EUR'),
          '50.00',
        );
        await t.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
        await save(t);
        expect(
          c.financeIndex.accounts.any((a) => a.title == 'Cash wallet'),
          isTrue,
        );
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'oversized account totals show recovery actions without breaking other cards',
    (t) async {
      UniversalObject record(String id, Map<String, dynamic> data) =>
          UniversalObject(
            id: id,
            workspaceId: c.repository.workspaceId,
            typeId: 'orbit.note',
            title: id,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            properties: {
              'finance': {'version': 1, 'currency': 'EUR', ...data},
            },
          );
      c.objects = [
        record('Overflow account', {'kind': 'account', 'openingMinor': 0}),
        record('Healthy account', {'kind': 'account', 'openingMinor': 500}),
        for (var i = 0; i < 1001; i++)
          record('expense-$i', {
            'kind': 'transaction',
            'direction': 'expense',
            'accountId': 'Overflow account',
            'date': '2026-10-26',
            'amountMinor': maxFinanceMoney,
          }),
      ];
      await mount(t);
      await t.tap(find.widgetWithText(ChoiceChip, 'Accounts'));
      await t.pumpAndSettle();
      expect(find.textContaining('Needs attention:'), findsOneWidget);
      expect(find.text('Healthy account'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('invalid precision and failed save retain the account draft', (
    t,
  ) async {
    await mount(t, editor: true);
    await t.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Draft account',
    );
    await t.enterText(
      find.widgetWithText(TextFormField, 'Starting balance · EUR'),
      '1.001',
    );
    await save(t);
    expect(find.textContaining('too many digits'), findsOneWidget);
    expect(c.financeIndex.accounts, isEmpty);
    await t.enterText(
      find.widgetWithText(TextFormField, 'Starting balance · EUR'),
      '100',
    );
    store.failWrites = true;
    await save(t);
    expect(find.textContaining('Simulated write failure'), findsOneWidget);
    expect(find.text('Draft account'), findsOneWidget);
    expect(c.financeIndex.accounts, isEmpty);
    store.failWrites = false;
    await save(t);
    expect(c.financeIndex.accounts.single.title, 'Draft account');
    expect(t.takeException(), isNull);
  });
}
