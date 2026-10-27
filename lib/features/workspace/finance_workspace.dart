import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import '../../app/workspace_controller.dart';
import '../../domain/finance.dart';
import '../../domain/calendar_event.dart';
import '../../domain/universal_object.dart';
import '../notes/note_link_dialog.dart';
import '../../platform/export_file.dart';

// A route's result arrives before its exit transition finishes. Forms retain
// their controllers until the overlay is actually removed.
Future<T?> _financeDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
  );
  final result = await navigator.push(route);
  await route.completed;
  return result;
}

Future<void> showFinanceWorkspace(
  BuildContext context,
  WorkspaceController controller,
) => showDialog<void>(
  context: context,
  builder: (_) => RepaintBoundary(
    key: const ValueKey('finance-capture'),
    child: FinanceWorkspace(controller: controller),
  ),
);

class FinanceWorkspace extends ConsumerStatefulWidget {
  const FinanceWorkspace({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  ConsumerState<FinanceWorkspace> createState() => _FinanceWorkspaceState();
}

class _FinanceWorkspaceState extends ConsumerState<FinanceWorkspace> {
  WorkspaceController get c => widget.controller;
  late final int _opening = c.workspaceGeneration;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _section = 'Overview', _currency = 'EUR', _query = '', _account = '';
  String? _notice;
  bool _busy = false, _archived = false;
  int _limit = 60;
  String _memo(String text) {
    final chars = text.runes.take(501).toList();
    return '${String.fromCharCodes(chars.take(500))}${chars.length > 500 ? '…' : ''}';
  }

  String get month => calendarDate(_month).substring(0, 7);
  bool get current => c.workspaceGeneration == _opening && c.hasWorkspace;

  Future<void> _run(
    Future<Object?> Function() action, {
    String? success,
  }) async {
    if (_busy || !current) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final result = await action();
      if (!mounted) return;
      setState(
        () => _notice = !current
            ? 'The Vault changed. Reopen Finance.'
            : result == null || result == false
            ? c.error ?? 'The operation could not be saved.'
            : result is String
            ? result
            : success,
      );
    } catch (e) {
      if (mounted) setState(() => _notice = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(String kind, [UniversalObject? original]) async {
    if (!current) return;
    final beforeIds = c.financeIndex.records.map((o) => o.id).toSet();
    final saved = await showFinanceEditor(
      context,
      c,
      kind,
      original: original,
      initialMonth: month,
      initialCurrency: _currency,
    );
    if (saved == true && mounted && current) {
      final result = original == null
          ? c.financeIndex.records
                .where(
                  (o) => !beforeIds.contains(o.id) && financeKind(o) == kind,
                )
                .firstOrNull
          : c.find(original.id);
      setState(() {
        _notice = 'Saved. Changes stay linked to this Vault.';
        _query = '';
        _account = '';
        if (result != null) {
          final data = financeData(result);
          _currency = data['currency'] as String;
          final date =
              parseCalendarDate(data['date']) ??
              parseCalendarDate('${data['month']}-01');
          if (date != null) _month = DateTime(date.year, date.month);
        }
      });
    }
  }

  Future<void> _remove(UniversalObject record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move transaction to Trash?'),
        content: Text(
          '“${record.title}” will stop affecting balances and reports. Its note and history can be restored from Trash.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(
        () => c.trash(record.id, expected: record),
        success: 'Moved to Trash. Restore the note there if needed.',
      );
    }
  }

  Widget _metric(String label, int value) => SizedBox(
    width: 235,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 8),
            Text(
              moneyText(value, _currency),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _overview(FinanceIndex index) {
    final summary = index.summary(month, _currency);
    final accounts = index.accounts
        .where((o) => financeData(o)['currency'] == _currency)
        .toList();
    final balance = accounts.fold<int>(
      0,
      (sum, a) => addFinanceMoney(
        sum,
        index.balance(a, through: calendarDate(DateTime.now())),
      ),
    );
    final categories = summary.categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _metric('Ledger balance · today', balance),
            _metric('Income · $month', summary.income),
            _metric('Expenses · $month', summary.expenses),
            _metric(
              'Net cash flow · $month',
              summary.income - summary.expenses,
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Monthly cash flow includes recorded future dates and pending transactions. Transfers are excluded. Cleared balances are available in Accounts. Currencies are never combined or converted.',
        ),
        const SizedBox(height: 22),
        Text(
          'Spending by category',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (categories.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No expenses in this month. Add an account, then record your first expense.',
            ),
          ),
        for (final e in categories.take(30))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  children: [Text(e.key), Text(moneyText(e.value, _currency))],
                ),
                const SizedBox(height: 5),
                LinearProgressIndicator(
                  value: summary.expenses == 0 ? 0 : e.value / summary.expenses,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => c.createFinanceReport(month, _currency),
                      success:
                          'Created a linked monthly review note in Finance.',
                    ),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Create review note'),
            ),
            OutlinedButton.icon(
              onPressed: () => _run(() async {
                await Clipboard.setData(
                  ClipboardData(text: index.report(month, _currency)),
                );
                return true;
              }, success: 'Monthly Markdown report copied.'),
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy report'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Six-month cash flow',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (var offset = 5; offset >= 0; offset--)
          Builder(
            builder: (_) {
              final date = DateTime(_month.year, _month.month - offset);
              final label = calendarDate(date).substring(0, 7);
              final totals = index.summary(label, _currency);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(label),
                subtitle: Text(
                  'In ${moneyText(totals.income, _currency)} · Out ${moneyText(totals.expenses, _currency)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setState(() => _month = date),
              );
            },
          ),
        const SizedBox(height: 24),
        Text(
          'Account balances',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final account in accounts) _accountCard(index, account),
      ],
    );
  }

  Widget _accountCard(FinanceIndex index, UniversalObject account) {
    final data = financeData(account),
        currency = financeData(account)['currency'] as String;
    return _card(
      account,
      '${data['archived'] == true ? 'Archived · ' : ''}Ledger: ${moneyText(index.balance(account, through: calendarDate(DateTime.now())), currency)}\nCleared: ${moneyText(index.balance(account, through: calendarDate(DateTime.now()), clearedOnly: true), currency)}\nStarting balance: ${moneyText(data['openingMinor'] as int, currency)} (assumed cleared)',
      kind: 'account',
    );
  }

  Widget _card(
    UniversalObject record,
    String details, {
    required String kind,
    List<Widget> actions = const [],
    Widget? progress,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(record.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          SelectableText(details),
          if (progress != null)
            Padding(padding: const EdgeInsets.only(top: 10), child: progress),
          Wrap(
            spacing: 2,
            runSpacing: 2,
            children: [
              TextButton(
                onPressed: _busy ? null : () => _edit(kind, record),
                child: const Text('Edit'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  c.openObject(record.id);
                },
                child: const Text('Open note'),
              ),
              TextButton(
                onPressed: () => _run(
                  () async {
                    await Clipboard.setData(
                      ClipboardData(text: '[[${record.id}|${record.title}]]'),
                    );
                    return true;
                  },
                  success:
                      'Live object link copied. Paste it in a note or Canvas.',
                ),
                child: const Text('Copy link'),
              ),
              if (financeData(record)['receiptId'] is String &&
                  financeData(record)['receiptId'] != '')
                TextButton(
                  onPressed:
                      c
                              .find(financeData(record)['receiptId'] as String)
                              ?.isDeleted !=
                          false
                      ? null
                      : () {
                          Navigator.pop(context);
                          c.openObject(
                            financeData(record)['receiptId'] as String,
                          );
                        },
                  child: Text(
                    c
                                .find(
                                  financeData(record)['receiptId'] as String,
                                )
                                ?.isDeleted !=
                            false
                        ? 'Missing receipt / source'
                        : 'Receipt / source',
                  ),
                ),
              ...actions,
              if (kind == 'transaction')
                TextButton(
                  onPressed: _busy ? null : () => _remove(record),
                  child: const Text('Delete'),
                )
              else
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => c.saveFinance(record, record.title, {
                            'archived': financeData(record)['archived'] != true,
                          }),
                          success: 'Archive status updated.',
                        ),
                  child: Text(
                    financeData(record)['archived'] == true
                        ? 'Unarchive'
                        : 'Archive',
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _records(FinanceIndex index) {
    final kind = switch (_section) {
      'Transactions' => 'transaction',
      'Accounts' => 'account',
      'Budgets' => 'budget',
      'Bills' => 'bill',
      _ => 'goal',
    };
    final records =
        index.ofKind(kind).where((o) {
          final d = financeData(o);
          if (!_archived && d['archived'] == true) return false;
          if (kind != 'account' && d['currency'] != _currency) return false;
          if (kind == 'budget' && d['month'] != month) return false;
          if (kind == 'transaction' &&
              (!(d['date'] as String).startsWith('$month-') ||
                  _account.isNotEmpty &&
                      d['accountId'] != _account &&
                      d['toAccountId'] != _account)) {
            return false;
          }
          return _query.isEmpty ||
              '${o.title} ${d['category'] ?? ''} ${d['payee'] ?? ''} ${o.body}'
                  .toLowerCase()
                  .contains(_query.toLowerCase());
        }).toList()..sort(
          (a, b) => kind == 'transaction'
              ? '${financeData(b)['date']}'.compareTo(
                  '${financeData(a)['date']}',
                )
              : a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
    final totals = kind == 'budget' ? index.summary(month, _currency) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (kind == 'account')
          const Text(
            'Starting balances are the balances before your recorded ledger. Negative balances are supported. Archive accounts instead of deleting their history.',
          ),
        if (kind == 'goal')
          const Text(
            'Savings goals track earmarked progress manually. They do not move money or subtract it from account balances.',
          ),
        if (kind == 'bill')
          const Text(
            'Bills are schedules, not automatic charges. Record each occurrence explicitly. At most three upcoming/unpaid occurrences per bill are shown here.',
          ),
        if (records.isEmpty)
          Padding(
            padding: const EdgeInsets.all(28),
            child: Text(
              'No ${_section.toLowerCase()} match. Use Add to get started.',
            ),
          ),
        for (final record in records.take(_limit))
          Builder(
            builder: (_) {
              try {
                final d = financeData(record);
                if (kind == 'account') return _accountCard(index, record);
                if (kind == 'transaction') {
                  return _card(
                    record,
                    '${d['date']} · ${d['direction']} · ${moneyText(d['amountMinor'] as int, _currency)}\n${index.byId[d['accountId']]?.title ?? 'Missing account'}${d['direction'] == 'transfer' ? ' → ${index.byId[d['toAccountId']]?.title ?? 'Missing destination'}' : ' · ${d['category'] ?? 'Other'}'}\n${d['cleared'] == true ? 'Cleared' : 'Pending'}${'${d['date']}'.compareTo(calendarDate(DateTime.now())) > 0 ? ' · Future date' : ''}${record.body.isEmpty ? '' : '\n${_memo(record.body)}'}',
                    kind: kind,
                    actions: [
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => c.saveFinance(record, record.title, {
                                  'cleared': d['cleared'] != true,
                                }),
                                success: 'Transaction status saved.',
                              ),
                        child: Text(
                          d['cleared'] == true
                              ? 'Mark pending'
                              : 'Mark cleared',
                        ),
                      ),
                    ],
                  );
                }
                if (kind == 'budget') {
                  final spent =
                          totals!.categories[financeCategory(d['category'])] ??
                          0,
                      limit = d['limitMinor'] as int;
                  return _card(
                    record,
                    '${d['month']} · ${d['category']}\n${moneyText(spent, _currency)} spent of ${moneyText(limit, _currency)}\n${spent > limit ? 'Over budget by ${moneyText(spent - limit, _currency)}' : '${moneyText(limit - spent, _currency)} remaining'}',
                    kind: kind,
                    progress: LinearProgressIndicator(
                      value: limit == 0
                          ? (spent > 0 ? 1 : 0)
                          : (spent / limit).clamp(0, 1),
                      minHeight: 6,
                    ),
                  );
                }
                if (kind == 'goal') {
                  return _card(
                    record,
                    '${moneyText(d['savedMinor'] as int, _currency)} tracked of ${moneyText(d['targetMinor'] as int, _currency)}${d['dueDate'] == null || d['dueDate'] == '' ? '' : '\nTarget date: ${d['dueDate']}'}',
                    kind: kind,
                    progress: LinearProgressIndicator(
                      value:
                          ((d['savedMinor'] as int) / (d['targetMinor'] as int))
                              .clamp(0, 1),
                      minHeight: 6,
                    ),
                  );
                }
                final dates = index.dueDates(
                  record,
                  DateTime.now().add(const Duration(days: 31)),
                  limit: 3,
                );
                return _card(
                  record,
                  '${moneyText(d['amountMinor'] as int, _currency)} · ${d['frequency']} · ${d['direction']}\n${index.byId[d['accountId']]?.title ?? 'Missing account'} · From ${d['startDate']}',
                  kind: kind,
                  actions: [
                    for (final date in dates)
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => c.recordBill(record, date),
                                success:
                                    'Occurrence recorded once in the ledger.',
                              ),
                        child: Text(
                          '${date.compareTo(calendarDate(DateTime.now())) < 0 ? 'Overdue · ' : ''}Record $date',
                        ),
                      ),
                  ],
                );
              } on FormatException catch (e) {
                // Cards are built after the parent report's error boundary.
                // Keep the record and its edit/open actions accessible when an
                // aggregate exceeds the exact range or a schedule is too long.
                return _card(
                  record,
                  'Needs attention: ${e.message}',
                  kind: kind,
                );
              }
            },
          ),
        if (records.length > _limit)
          TextButton(
            onPressed: () => setState(() => _limit += 60),
            child: Text('Show more · ${records.length - _limit} remaining'),
          ),
      ],
    );
  }

  Future<void> _import() async {
    final input = TextEditingController(
      text: 'date,type,amount,category,payee,memo\n',
    );
    var accountId =
        c.financeIndex.accounts
            .where((a) => financeData(a)['archived'] != true)
            .firstOrNull
            ?.id ??
        '';
    List<FinanceImportRow>? preview;
    String? error;
    bool saving = false;
    try {
      await _financeDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => PopScope(
            canPop: !saving,
            child: AlertDialog(
              title: const Text('Import transactions · preview first'),
              content: SizedBox(
                width: 680,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Paste Orbit CSV (maximum 500 rows). Dates: YYYY-MM-DD; types: expense/income/transfer; amounts: positive, no grouping separators. Account IDs/currency columns are optional. Identical rows preserve their occurrence count; reimporting the same rows skips existing IDs, including Trash.',
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                update(() {
                                  saving = true;
                                  error = null;
                                });
                                try {
                                  final file = await openFile(
                                    acceptedTypeGroups: [
                                      const XTypeGroup(
                                        label: 'CSV',
                                        extensions: ['csv'],
                                      ),
                                    ],
                                  );
                                  if (file != null) {
                                    if (await file.length() > 1000000) {
                                      throw const FormatException(
                                        'Import at most 1 MB of CSV.',
                                      );
                                    }
                                    final text = await file.readAsString();
                                    if (ctx.mounted && current) {
                                      update(() {
                                        input.text = text;
                                        preview = null;
                                      });
                                    }
                                  }
                                } catch (e) {
                                  if (ctx.mounted) update(() => error = '$e');
                                } finally {
                                  if (ctx.mounted) update(() => saving = false);
                                }
                              },
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('Choose CSV file'),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: accountId.isEmpty ? null : accountId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Default account',
                        ),
                        items: [
                          for (final a in c.financeIndex.accounts.where(
                            (a) => financeData(a)['archived'] != true,
                          ))
                            DropdownMenuItem(
                              value: a.id,
                              child: Text(
                                '${a.title} · ${financeData(a)['currency']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: saving
                            ? null
                            : (v) => update(() {
                                accountId = v ?? '';
                                preview = null;
                              }),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: input,
                        minLines: 6,
                        maxLines: 12,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'CSV text',
                          alignLabelWithHint: true,
                        ),
                        onChanged: (_) => update(() => preview = null),
                      ),
                      if (error != null)
                        Semantics(liveRegion: true, child: Text(error!)),
                      if (preview != null) ...[
                        Text(
                          '${preview!.length} rows · ${preview!.where((r) => r.duplicate).length} already recorded',
                        ),
                        for (final r in preview!.take(12))
                          Text(
                            '${r.duplicate ? 'Skip' : 'Add'} · ${r.data['date']} · ${r.title} · ${moneyText(r.data['amountMinor'] as int, r.data['currency'] as String)}',
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                OutlinedButton(
                  onPressed: saving
                      ? null
                      : () {
                          try {
                            if (!current) {
                              throw const FormatException('The Vault changed.');
                            }
                            final rows = c.previewFinanceImport(
                              input.text,
                              accountId,
                            );
                            update(() {
                              preview = rows;
                              error = null;
                            });
                          } catch (e) {
                            update(() {
                              error = '$e';
                              preview = null;
                            });
                          }
                        },
                  child: const Text('Preview'),
                ),
                FilledButton(
                  onPressed: saving || preview == null || preview!.isEmpty
                      ? null
                      : () async {
                          if (!current) {
                            update(() => error = 'The Vault changed.');
                            return;
                          }
                          update(() {
                            saving = true;
                            error = null;
                          });
                          final result = await c.importFinanceCsv(
                            input.text,
                            accountId,
                            expectedRows: preview,
                          );
                          if (!ctx.mounted) return;
                          if (result == null) {
                            update(() {
                              saving = false;
                              preview = null;
                              error =
                                  c.error ??
                                  'Import failed; your CSV is retained.';
                            });
                          } else {
                            Navigator.pop(ctx);
                            if (mounted) {
                              setState(
                                () => _notice =
                                    '${result.added} imported; ${result.skipped} skipped.',
                              );
                            }
                          }
                        },
                  child: Text(saving ? 'Importing…' : 'Import previewed rows'),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      input.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(workspaceProvider);
    if (!current) {
      return AlertDialog(
        title: const Text('Finance'),
        content: const Text(
          'The Vault changed. Close and reopen this workspace.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }
    final index = c.financeIndex;
    final kind = switch (_section) {
      'Accounts' => 'account',
      'Budgets' => 'budget',
      'Bills' => 'bill',
      'Goals' => 'goal',
      _ => 'transaction',
    };
    Widget content;
    try {
      content = _section == 'Overview' ? _overview(index) : _records(index);
    } catch (e) {
      content = SelectableText('Finance report needs attention: $e');
    }
    return Dialog(
      insetPadding: const EdgeInsets.all(14),
      child: SizedBox(
        width: 1200,
        height: 790,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Finance',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close finance',
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Text(
                  'Your money, in your Vault. Manual tracking · no bank connection.',
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final section in [
                        'Overview',
                        'Transactions',
                        'Accounts',
                        'Budgets',
                        'Bills',
                        'Goals',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(section),
                            selected: _section == section,
                            onSelected: (_) => setState(() {
                              _section = section;
                              _limit = 60;
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Previous month',
                      onPressed: () => setState(
                        () => _month = DateTime(_month.year, _month.month - 1),
                      ),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(month),
                    IconButton(
                      tooltip: 'Next month',
                      onPressed: () => setState(
                        () => _month = DateTime(_month.year, _month.month + 1),
                      ),
                      icon: const Icon(Icons.chevron_right),
                    ),
                    DropdownButton<String>(
                      value: _currency,
                      items: [
                        for (final code in financeCurrencies.keys)
                          DropdownMenuItem(value: code, child: Text(code)),
                      ],
                      onChanged: (v) => setState(() => _currency = v!),
                    ),
                    FilledButton.icon(
                      onPressed: _busy || c.repository.readOnly
                          ? null
                          : () => _edit(kind),
                      icon: const Icon(Icons.add),
                      label: Text('Add $kind'),
                    ),
                    OutlinedButton(
                      onPressed: _busy || c.repository.readOnly
                          ? null
                          : _import,
                      child: const Text('Import CSV'),
                    ),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () async {
                                await Clipboard.setData(
                                  ClipboardData(
                                    text: financeCsv(
                                      index.transactions.where(
                                        (o) =>
                                            (financeData(o)['date'] as String)
                                                .startsWith('$month-') &&
                                            financeData(o)['currency'] ==
                                                _currency,
                                      ),
                                    ),
                                  ),
                                );
                                return true;
                              },
                              success:
                                  'Selected month/currency copied as CSV. Spreadsheet formula-like text is escaped.',
                            ),
                      child: const Text('Copy CSV'),
                    ),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              final text = financeCsv(
                                index.transactions.where(
                                  (o) =>
                                      (financeData(o)['date'] as String)
                                          .startsWith('$month-') &&
                                      financeData(o)['currency'] == _currency,
                                ),
                              );
                              final saved = await exportFile(
                                'finance-$month-$_currency.csv',
                                text,
                                mimeType: 'text/csv',
                              );
                              return saved
                                  ? 'CSV exported. Formula-like text cells are escaped for spreadsheets.'
                                  : 'CSV export cancelled.';
                            }),
                      child: const Text('Export CSV'),
                    ),
                  ],
                ),
                if (_section != 'Overview') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Search title, category, payee or memo',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) => setState(() {
                            _query = v;
                            _limit = 60;
                          }),
                        ),
                      ),
                      IconButton(
                        tooltip: _archived
                            ? 'Hide archived'
                            : 'Include archived',
                        onPressed: () => setState(() => _archived = !_archived),
                        icon: Icon(
                          _archived
                              ? Icons.inventory_2
                              : Icons.inventory_2_outlined,
                        ),
                      ),
                    ],
                  ),
                  if (_section == 'Transactions')
                    DropdownButton<String>(
                      isExpanded: true,
                      value: index.accounts.any((a) => a.id == _account)
                          ? _account
                          : '',
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('All accounts'),
                        ),
                        for (final a in index.accounts)
                          DropdownMenuItem(
                            value: a.id,
                            child: Text(
                              a.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _account = v ?? ''),
                    ),
                ],
                if (_notice != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Semantics(liveRegion: true, child: Text(_notice!)),
                  ),
                if (index.issues.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(index.issues.take(4).join('\n')),
                  ),
                const Divider(),
                content,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool?> showFinanceEditor(
  BuildContext context,
  WorkspaceController c,
  String kind, {
  UniversalObject? original,
  required String initialMonth,
  required String initialCurrency,
}) async {
  final generation = c.workspaceGeneration;
  final previous = original == null
      ? <String, dynamic>{}
      : financeData(original);
  var currency = '${previous['currency'] ?? initialCurrency}',
      direction = '${previous['direction'] ?? 'expense'}',
      frequency = '${previous['frequency'] ?? 'monthly'}';
  var accountId = '${previous['accountId'] ?? ''}',
      destination = '${previous['toAccountId'] ?? ''}',
      receipt = '${previous['receiptId'] ?? ''}',
      cleared = previous['cleared'] == true;
  final accounts = c.financeIndex.accounts
      .where(
        (a) =>
            financeData(a)['archived'] != true ||
            a.id == accountId ||
            a.id == destination,
      )
      .toList();
  if (accountId.isEmpty && accounts.isNotEmpty) {
    accountId = accounts.first.id;
    currency = financeData(accounts.first)['currency'] as String;
  }
  final inputs = <String, TextEditingController>{};
  TextEditingController input(String key, [String initial = '']) =>
      inputs.putIfAbsent(
        key,
        () => TextEditingController(text: '${previous[key] ?? initial}'),
      );
  final title = TextEditingController(text: original?.title ?? ''),
      memo = TextEditingController(text: original?.body ?? '');
  final amountKey = switch (kind) {
    'account' => 'openingMinor',
    'budget' => 'limitMinor',
    'goal' => 'targetMinor',
    _ => 'amountMinor',
  };
  final amount = TextEditingController(
    text: moneyText(previous[amountKey] as int? ?? 0, currency, code: false),
  );
  final saved = TextEditingController(
    text: moneyText(previous['savedMinor'] as int? ?? 0, currency, code: false),
  );
  final form = GlobalKey<FormState>();
  String? error;
  bool saving = false;
  try {
    return await _financeDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) {
          Widget field(
            String key,
            String label, {
            String initial = '',
            bool required = false,
          }) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: input(key, initial),
              enabled: !saving,
              decoration: InputDecoration(
                labelText: label,
                suffixIcon: ['date', 'startDate', 'dueDate'].contains(key)
                    ? IconButton(
                        tooltip: 'Choose date',
                        icon: const Icon(Icons.calendar_today_outlined),
                        onPressed: saving
                            ? null
                            : () async {
                                final old = parseCalendarDate(
                                  input(key, initial).text,
                                );
                                final day = await showDatePicker(
                                  context: ctx,
                                  initialDate:
                                      old != null &&
                                          old.year >= 1900 &&
                                          old.year <= 2200
                                      ? old
                                      : DateTime.now(),
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime(2200, 12, 31),
                                );
                                if (ctx.mounted && day != null) {
                                  update(
                                    () => input(key, initial).text =
                                        calendarDate(day),
                                  );
                                }
                              },
                      )
                    : null,
              ),
              validator: required
                  ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
                  : null,
            ),
          );
          Widget accountPicker(bool target) {
            final id = target ? destination : accountId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: accounts.any((a) => a.id == id) ? id : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: target ? 'Destination account' : 'Account',
                ),
                items: [
                  for (final a in accounts)
                    DropdownMenuItem(
                      value: a.id,
                      child: Text(
                        '${a.title} · ${financeData(a)['currency']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: saving
                    ? null
                    : (v) => update(() {
                        if (target) {
                          destination = v ?? '';
                        } else {
                          accountId = v ?? '';
                          currency =
                              financeData(
                                    accounts.firstWhere((a) => a.id == v),
                                  )['currency']
                                  as String;
                        }
                      }),
                validator: (v) => v == null || v.isEmpty
                    ? 'Create and choose an account first.'
                    : null,
              ),
            );
          }

          return PopScope(
            canPop: !saving,
            child: AlertDialog(
              title: Text('${original == null ? 'New' : 'Edit'} $kind'),
              content: SizedBox(
                width: 560,
                child: Form(
                  key: form,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: title,
                          autofocus: true,
                          enabled: !saving,
                          decoration: const InputDecoration(labelText: 'Title'),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Enter a title.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        if (kind == 'transaction' || kind == 'bill') ...[
                          DropdownButtonFormField<String>(
                            initialValue: direction,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Type',
                            ),
                            items: [
                              for (final d in [
                                'expense',
                                'income',
                                if (kind == 'transaction') 'transfer',
                              ])
                                DropdownMenuItem(value: d, child: Text(d)),
                            ],
                            onChanged: saving
                                ? null
                                : (v) => update(() => direction = v!),
                          ),
                          const SizedBox(height: 12),
                          accountPicker(false),
                          if (direction == 'transfer') accountPicker(true),
                        ] else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DropdownButtonFormField<String>(
                              initialValue: currency,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Currency',
                              ),
                              items: [
                                for (final code in financeCurrencies.keys)
                                  DropdownMenuItem(
                                    value: code,
                                    child: Text(code),
                                  ),
                              ],
                              onChanged: saving
                                  ? null
                                  : (v) => update(() => currency = v!),
                            ),
                          ),
                        TextFormField(
                          controller: amount,
                          enabled: !saving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: InputDecoration(
                            labelText:
                                '${kind == 'account'
                                    ? 'Starting balance'
                                    : kind == 'budget'
                                    ? 'Monthly limit'
                                    : kind == 'goal'
                                    ? 'Savings target'
                                    : 'Amount'} · $currency',
                            helperText:
                                'Plain decimal amount; no thousands separators.',
                          ),
                          validator: (v) {
                            try {
                              parseMoney(
                                v ?? '',
                                currency,
                                signed: kind == 'account',
                              );
                              return null;
                            } catch (e) {
                              return '$e'.replaceFirst('FormatException: ', '');
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        if (kind == 'transaction') ...[
                          field(
                            'date',
                            'Date · YYYY-MM-DD',
                            initial: calendarDate(DateTime.now()),
                            required: true,
                          ),
                          CheckboxListTile(
                            value: cleared,
                            onChanged: saving
                                ? null
                                : (v) => update(() => cleared = v!),
                            title: const Text('Cleared / confirmed'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                        if (kind == 'budget')
                          field(
                            'month',
                            'Budget month · YYYY-MM',
                            initial: initialMonth,
                            required: true,
                          ),
                        if (kind == 'bill') ...[
                          field(
                            'startDate',
                            'First due date · YYYY-MM-DD',
                            initial: calendarDate(DateTime.now()),
                            required: true,
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: frequency,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Repeat',
                            ),
                            items: [
                              for (final f in ['weekly', 'monthly', 'yearly'])
                                DropdownMenuItem(value: f, child: Text(f)),
                            ],
                            onChanged: saving
                                ? null
                                : (v) => update(() => frequency = v!),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (kind == 'goal') ...[
                          TextFormField(
                            controller: saved,
                            enabled: !saving,
                            decoration: InputDecoration(
                              labelText: 'Manually tracked savings · $currency',
                            ),
                          ),
                          const SizedBox(height: 12),
                          field(
                            'dueDate',
                            'Target date · YYYY-MM-DD (optional)',
                          ),
                        ],
                        if (['transaction', 'bill', 'budget'].contains(kind))
                          field(
                            'category',
                            'Category',
                            initial: 'Other',
                            required: kind == 'budget',
                          ),
                        if (kind == 'transaction' || kind == 'bill')
                          field('payee', 'Payee / payer (optional)'),
                        if (kind == 'transaction')
                          TextButton.icon(
                            onPressed: saving
                                ? null
                                : () async {
                                    final result = await showNoteLinkDialog(
                                      ctx,
                                      c.linkTargets,
                                    );
                                    if (ctx.mounted && result != null) {
                                      update(() => receipt = result.id);
                                    }
                                  },
                            icon: const Icon(Icons.attach_file),
                            label: Text(
                              receipt.isEmpty
                                  ? 'Link a receipt or note'
                                  : c.find(receipt)?.title ??
                                        'Missing linked source',
                            ),
                          ),
                        if (receipt.isNotEmpty)
                          TextButton(
                            onPressed: saving
                                ? null
                                : () => update(() => receipt = ''),
                            child: const Text('Remove source link'),
                          ),
                        TextFormField(
                          controller: memo,
                          enabled: !saving,
                          minLines: 2,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            labelText: 'Notes / memo',
                          ),
                        ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(error!),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!form.currentState!.validate()) return;
                          if (generation != c.workspaceGeneration) {
                            update(
                              () => error =
                                  'The Vault changed. Your draft is retained here.',
                            );
                            return;
                          }
                          try {
                            final data = <String, dynamic>{
                              ...previous,
                              'version': 1,
                              'kind': kind,
                              'currency': currency,
                              amountKey: parseMoney(
                                amount.text,
                                currency,
                                signed: kind == 'account',
                              ),
                              if (kind == 'transaction' || kind == 'bill') ...{
                                'direction': direction,
                                'accountId': accountId,
                                'category': input('category').text.trim(),
                                'payee': input('payee').text.trim(),
                              },
                              if (kind == 'transaction') ...{
                                'date': input('date').text.trim(),
                                'cleared': cleared,
                                'receiptId': receipt,
                                'toAccountId': direction == 'transfer'
                                    ? destination
                                    : '',
                              },
                              if (kind == 'budget') ...{
                                'month': input('month').text.trim(),
                                'category': input('category').text.trim(),
                              },
                              if (kind == 'bill') ...{
                                'startDate': input('startDate').text.trim(),
                                'frequency': frequency,
                              },
                              if (kind == 'goal') ...{
                                'savedMinor': parseMoney(saved.text, currency),
                                'dueDate': input('dueDate').text.trim(),
                              },
                            };
                            validateFinance(data);
                            update(() {
                              saving = true;
                              error = null;
                            });
                            final ok = original == null
                                ? await c.createFinance(
                                        title.text,
                                        data,
                                        body: memo.text,
                                      ) !=
                                      null
                                : await c.saveFinance(
                                    original,
                                    title.text,
                                    data,
                                    body: memo.text,
                                  );
                            if (!ctx.mounted) return;
                            if (ok) {
                              Navigator.pop(ctx, true);
                            } else {
                              update(() {
                                saving = false;
                                error =
                                    c.error ??
                                    'Save failed. Your draft is kept here.';
                              });
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              update(() {
                                saving = false;
                                error = '$e';
                              });
                            }
                          }
                        },
                  child: Text(saving ? 'Saving…' : 'Save'),
                ),
              ],
            ),
          );
        },
      ),
    );
  } finally {
    title.dispose();
    memo.dispose();
    amount.dispose();
    saved.dispose();
    for (final controller in inputs.values) {
      controller.dispose();
    }
  }
}
