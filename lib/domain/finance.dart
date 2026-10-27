import 'dart:convert';
import 'calendar_event.dart';
import 'universal_object.dart';

const financeCurrencies = {
  'EUR': 2,
  'USD': 2,
  'GBP': 2,
  'CHF': 2,
  'CAD': 2,
  'AUD': 2,
  'JPY': 0,
};
const financeCategories = [
  'Housing',
  'Groceries',
  'Dining',
  'Transport',
  'Utilities',
  'Health',
  'Education',
  'Entertainment',
  'Shopping',
  'Subscriptions',
  'Travel',
  'Salary',
  'Other',
];
const financeKinds = ['account', 'transaction', 'budget', 'bill', 'goal'];
const maxFinanceMoney = 9000000000000;
const maxFinanceTotal = 9000000000000000;
int addFinanceMoney(int a, int b) {
  if (b > 0 && a > maxFinanceTotal - b || b < 0 && a < -maxFinanceTotal - b) {
    throw const FormatException(
      'The total exceeds the exact supported money range. Narrow the report.',
    );
  }
  return a + b;
}

int parseMoney(String text, String currency, {bool signed = false}) {
  final places = financeCurrencies[currency];
  if (places == null) {
    throw const FormatException('Choose a supported currency.');
  }
  final input = text.trim();
  if (input.length > 64) throw const FormatException('The amount is too long.');
  if (!RegExp(r'^[+-]?\d+(?:[.,]\d+)?$').hasMatch(input)) {
    throw const FormatException(
      'Use a plain amount, for example 12.50 or 12,50; no thousands separators.',
    );
  }
  final parts = input
      .replaceAll(',', '.')
      .replaceFirst(RegExp(r'^[+-]'), '')
      .split('.');
  if (parts[0].length > 13 || parts.length > 1 && parts[1].length > places) {
    throw const FormatException(
      'The amount has too many digits or decimal places.',
    );
  }
  final scale = places == 0 ? 1 : 100;
  final value =
      int.parse(parts[0]) * scale +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(places, '0')));
  final result = input.startsWith('-') ? -value : value;
  if (result.abs() > maxFinanceMoney || !signed && result < 0) {
    throw const FormatException(
      'Enter a valid non-negative amount within the supported range.',
    );
  }
  return result;
}

String moneyText(int minor, String currency, {bool code = true}) {
  final places = financeCurrencies[currency] ?? 2,
      scale = places == 0 ? 1 : 100;
  final absolute = minor.abs();
  return '${minor < 0 ? '-' : ''}${absolute ~/ scale}${places == 0 ? '' : '.${(absolute % scale).toString().padLeft(places, '0')}'}${code ? ' $currency' : ''}';
}

Map<String, dynamic> financeData(UniversalObject object) =>
    object.properties['finance'] is Map
    ? Map<String, dynamic>.from(object.properties['finance'] as Map)
    : {};
// UniversalObject recursively freezes its data. Validation can follow object
// identity; replacements (including equal-revision remote edits) validate anew.
// Weak keys release old Vault snapshots instead of retaining them indefinitely.
final _validatedFinanceKinds = Expando<String>('validated finance kind');
String? financeKind(UniversalObject? object) {
  if (object == null || object.isDeleted || object.typeId != 'orbit.note') {
    return null;
  }
  final cached = _validatedFinanceKinds[object];
  if (cached != null) return cached.isEmpty ? null : cached;
  try {
    final data = financeData(object);
    validateFinance(data);
    final kind = data['kind'] as String;
    _validatedFinanceKinds[object] = kind;
    return kind;
  } catch (_) {
    _validatedFinanceKinds[object] = '';
    return null;
  }
}

String financeCategory(Object? value) => '$value'.trim().toLowerCase();

void validateFinance(Map<String, dynamic> data) {
  if (data['version'] != 1 || !financeKinds.contains(data['kind'])) {
    throw const FormatException(
      'Unsupported finance record; original data is preserved.',
    );
  }
  final kind = data['kind'];
  if (!financeCurrencies.containsKey(data['currency'])) {
    throw const FormatException('Choose a supported currency.');
  }
  for (final key in [
    'amountMinor',
    'openingMinor',
    'limitMinor',
    'targetMinor',
    'savedMinor',
  ]) {
    final value = data[key];
    if (value != null &&
        (value is! int ||
            value.abs() > maxFinanceMoney ||
            key != 'openingMinor' && value < 0)) {
      throw FormatException('Invalid exact amount: $key.');
    }
  }
  for (final key in ['date', 'startDate', 'dueDate']) {
    if (data[key] != null &&
        data[key] != '' &&
        parseCalendarDate(data[key]) == null) {
      throw FormatException('Choose a valid $key.');
    }
  }
  for (final key in [
    'category',
    'payee',
    'accountId',
    'toAccountId',
    'receiptId',
    'sourceId',
    'billId',
    'occurrence',
    'importKey',
  ]) {
    if (data[key] != null &&
        (data[key] is! String || (data[key] as String).length > 500)) {
      throw FormatException('Invalid $key.');
    }
  }
  if (data['archived'] != null && data['archived'] is! bool ||
      data['cleared'] != null && data['cleared'] is! bool) {
    throw const FormatException('Invalid finance status.');
  }
  if (kind == 'account' && data['openingMinor'] is! int) {
    throw const FormatException('Enter the starting account balance.');
  }
  if (kind == 'transaction' || kind == 'bill') {
    if (data['amountMinor'] is! int ||
        data['amountMinor'] <= 0 ||
        ![
          'expense',
          'income',
          if (kind == 'transaction') 'transfer',
        ].contains(data['direction']) ||
        (data['accountId'] ?? '') == '') {
      throw const FormatException(
        'Choose an account, type and positive amount.',
      );
    }
    if (parseCalendarDate(data[kind == 'bill' ? 'startDate' : 'date']) ==
        null) {
      throw const FormatException('Enter a valid date.');
    }
    if (data['direction'] == 'transfer' &&
        ((data['toAccountId'] ?? '') == '' ||
            data['toAccountId'] == data['accountId'])) {
      throw const FormatException('Transfers need two different accounts.');
    }
  }
  if (kind == 'budget') {
    if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch('${data['month']}') ||
        data['limitMinor'] is! int ||
        '${data['category'] ?? ''}'.trim().isEmpty) {
      throw const FormatException(
        'Choose a month, category and budget amount.',
      );
    }
  }
  if (kind == 'bill' &&
      !['weekly', 'monthly', 'yearly'].contains(data['frequency'])) {
    throw const FormatException('Choose a bill frequency.');
  }
  if (kind == 'goal' &&
      (data['targetMinor'] is! int ||
          data['targetMinor'] <= 0 ||
          data['savedMinor'] is! int)) {
    throw const FormatException(
      'Enter a positive savings target and tracked amount.',
    );
  }
  if (data['billId'] != null &&
      (data['billId'] != '' &&
          (parseCalendarDate(data['occurrence']) == null ||
              kind != 'transaction'))) {
    throw const FormatException('Invalid recorded bill occurrence.');
  }
  if (jsonEncode(data).length > 32000) {
    throw const FormatException('Finance metadata exceeds its limit.');
  }
}

Iterable<String> financeReferences(UniversalObject object) sync* {
  if (financeKind(object) == null) return;
  final data = financeData(object);
  for (final key in [
    'accountId',
    'toAccountId',
    'receiptId',
    'sourceId',
    'billId',
  ]) {
    if (data[key] is String && data[key] != '') yield data[key] as String;
  }
}

class FinanceIndex {
  FinanceIndex(Iterable<UniversalObject> source) {
    for (final object in source) {
      if (object.isDeleted || object.properties['finance'] == null) continue;
      final kind = financeKind(object);
      if (kind == null) {
        issues.add('Unsupported/damaged finance record: ${object.title}');
        continue;
      }
      records.add(object);
      byId[object.id] = object;
      _data[object.id] = financeData(object);
      _kinds.putIfAbsent(kind, () => []).add(object);
      if (kind == 'account') accounts.add(object);
      if (kind == 'transaction') transactions.add(object);
    }
    for (final transaction in transactions) {
      final data = _data[transaction.id]!;
      _accountTransactions
          .putIfAbsent(data['accountId'] as String, () => [])
          .add(transaction);
      if (data['direction'] == 'transfer' &&
          data['toAccountId'] != data['accountId']) {
        _accountTransactions
            .putIfAbsent(data['toAccountId'] as String, () => [])
            .add(transaction);
      }
      _monthlyTransactions
          .putIfAbsent((
            (data['date'] as String).substring(0, 7),
            data['currency'] as String,
          ), () => [])
          .add(transaction);
      if (data['billId'] is String) {
        _paid.add('${data['billId']}:${data['occurrence']}');
      }
      if (!_accountIds.contains(data['accountId']) ||
          _data[data['accountId']]?['currency'] != data['currency'] ||
          data['direction'] == 'transfer' &&
              (!_accountIds.contains(data['toAccountId']) ||
                  _data[data['toAccountId']]?['currency'] !=
                      data['currency'])) {
        issues.add(
          'Missing or mismatched account: ${transaction.title}; retained in cash-flow reports.',
        );
      }
    }
  }
  final records = <UniversalObject>[],
      accounts = <UniversalObject>[],
      transactions = <UniversalObject>[];
  final byId = <String, UniversalObject>{};
  final _paid = <String>{};
  final _data = <String, Map<String, dynamic>>{};
  final _kinds = <String, List<UniversalObject>>{};
  final _accountTransactions = <String, List<UniversalObject>>{};
  final _monthlyTransactions = <(String, String), List<UniversalObject>>{};
  late final _accountIds = accounts.map((o) => o.id).toSet();
  final issues = <String>[];
  List<UniversalObject> ofKind(String kind) =>
      List.of(_kinds[kind] ?? const <UniversalObject>[]);

  int balance(
    UniversalObject account, {
    String? through,
    bool clearedOnly = false,
  }) {
    final data = financeData(account);
    var balance = data['openingMinor'] as int;
    for (final o
        in _accountTransactions[account.id] ?? const <UniversalObject>[]) {
      final t = _data[o.id]!;
      if (clearedOnly && t['cleared'] != true) continue;
      if (t['currency'] != data['currency'] ||
          through != null && (t['date'] as String).compareTo(through) > 0) {
        continue;
      }
      final amount = t['amountMinor'] as int;
      if (t['accountId'] == account.id) {
        balance = addFinanceMoney(
          balance,
          t['direction'] == 'income' ? amount : -amount,
        );
      }
      if (t['direction'] == 'transfer' && t['toAccountId'] == account.id) {
        balance = addFinanceMoney(balance, amount);
      }
    }
    return balance;
  }

  ({int income, int expenses, Map<String, int> categories}) summary(
    String month,
    String currency, {
    String? through,
  }) {
    var income = 0, expenses = 0;
    final categories = <String, int>{};
    for (final o
        in _monthlyTransactions[(month, currency)] ??
            const <UniversalObject>[]) {
      final t = _data[o.id]!;
      if (!(t['date'] as String).startsWith('$month-') ||
          t['currency'] != currency ||
          through != null && (t['date'] as String).compareTo(through) > 0) {
        continue;
      }
      if (t['direction'] == 'income') {
        income = addFinanceMoney(income, t['amountMinor'] as int);
      }
      if (t['direction'] == 'expense') {
        expenses = addFinanceMoney(expenses, t['amountMinor'] as int);
        final category = '${t['category'] ?? 'Other'}'.trim();
        final key = category.isEmpty ? 'other' : category.toLowerCase();
        categories[key] = addFinanceMoney(
          categories[key] ?? 0,
          t['amountMinor'] as int,
        );
      }
    }
    return (income: income, expenses: expenses, categories: categories);
  }

  bool paid(String billId, String date) => _paid.contains('$billId:$date');
  List<String> dueDates(
    UniversalObject bill,
    DateTime through, {
    int limit = 40,
  }) {
    if (limit < 1 || limit > 16000) {
      throw const FormatException('Invalid bill projection limit.');
    }
    final data = financeData(bill);
    if (data['archived'] == true) return [];
    final start = parseCalendarDate(data['startDate'])!;
    final end = calendarDate(through);
    final result = <String>[];
    for (var i = 0; i < 16000; i++) {
      final DateTime day;
      if (data['frequency'] == 'weekly') {
        day = DateTime(start.year, start.month, start.day + i * 7);
      } else {
        final month = DateTime(
          start.year,
          start.month + i * (data['frequency'] == 'yearly' ? 12 : 1),
          1,
        );
        final last = DateTime(month.year, month.month + 1, 0).day;
        day = DateTime(
          month.year,
          month.month,
          start.day > last ? last : start.day,
        );
      }
      final date = calendarDate(day);
      if (date.compareTo(end) > 0) return result;
      if (!paid(bill.id, date)) result.add(date);
      if (result.length >= limit) return result;
    }
    throw const FormatException(
      'This bill spans too many occurrences. Review its start date.',
    );
  }

  String report(String month, String currency) {
    final totals = summary(month, currency);
    final b = StringBuffer('# Finance review · $month · $currency\n\n');
    b.writeln(
      'Income: ${moneyText(totals.income, currency)}  \nExpenses: ${moneyText(totals.expenses, currency)}  \nNet cash flow: ${moneyText(totals.income - totals.expenses, currency)}\n',
    );
    b.writeln(
      'Transfers are excluded. Recorded future transactions in this month are included. Currencies are never converted.\n\n## Categories\n\n| Category | Spending |\n| --- | ---: |',
    );
    for (final e in totals.categories.entries) {
      b.writeln(
        '| ${e.key.replaceAll('|', '/')} | ${moneyText(e.value, currency)} |',
      );
    }
    b.writeln('\n## Transactions\n');
    for (final o in transactions.where(
      (o) =>
          financeData(o)['currency'] == currency &&
          (financeData(o)['date'] as String).startsWith('$month-'),
    )) {
      final d = financeData(o);
      b.writeln(
        '- [[${o.id}|${o.title.replaceAll(']', '')}]] · ${d['date']} · ${d['direction']} · ${moneyText(d['amountMinor'] as int, currency)}',
      );
    }
    return b.toString();
  }
}

String financeCsv(Iterable<UniversalObject> records) {
  String cell(String v) =>
      '"${(RegExp(r'^[\s\uFEFF]*[=+@\-\t\r]').hasMatch(v) ? "'$v" : v).replaceAll('"', '""')}"';
  final b = StringBuffer(
    'date,type,amount,currency,accountId,toAccountId,category,payee,cleared,memo\r\n',
  );
  var count = 0;
  for (final o in records.where((o) => financeKind(o) == 'transaction')) {
    if (++count > 10000 || b.length + o.body.length > 8000000) {
      throw const FormatException(
        'CSV export is limited to 10,000 rows / 8 MB. Export a narrower period.',
      );
    }
    final d = financeData(o);
    b.writeln(
      [
        d['date'],
        d['direction'],
        moneyText(
          d['amountMinor'] as int,
          d['currency'] as String,
          code: false,
        ),
        d['currency'],
        d['accountId'],
        d['toAccountId'] ?? '',
        d['category'] ?? '',
        d['payee'] ?? '',
        d['cleared'] == true ? 'true' : 'false',
        o.body,
      ].map((v) => cell('$v')).join(','),
    );
  }
  return b.toString();
}

/// Explicit Orbit CSV schema, with quoted multiline values and strict row widths.
List<Map<String, String>> parseFinanceCsv(String input) {
  if (input.length > 1000000) {
    throw const FormatException('Import at most 1 MB of CSV at once.');
  }
  final rows = <List<String>>[], row = <String>[];
  var cell = StringBuffer(), quoted = false, closed = false;
  for (var i = 0; i < input.length; i++) {
    final ch = input[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
          closed = true;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"' && cell.isEmpty && !closed) {
      quoted = true;
    } else if (ch == ',' || ch == '\r' || ch == '\n') {
      row.add(cell.toString());
      cell = StringBuffer();
      closed = false;
      if (ch != ',') {
        if (ch == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
        if (row.any((v) => v.isNotEmpty)) rows.add(List.of(row));
        row.clear();
      }
    } else {
      if (closed || ch == '"') {
        throw const FormatException('Malformed CSV quoting.');
      }
      cell.write(ch);
    }
    if (rows.length > 501) {
      throw const FormatException('Import at most 500 rows at once.');
    }
  }
  if (quoted) throw const FormatException('Unclosed CSV quote.');
  row.add(cell.toString());
  if (row.any((v) => v.isNotEmpty)) rows.add(List.of(row));
  if (rows.isEmpty) {
    throw const FormatException('Paste the CSV header and rows.');
  }
  if (rows.length > 501) {
    throw const FormatException('Import at most 500 rows at once.');
  }
  final headers = rows
      .removeAt(0)
      .map((s) => s.replaceFirst('\ufeff', '').trim())
      .toList();
  if (headers.toSet().length != headers.length ||
      !['date', 'type', 'amount'].every(headers.contains)) {
    throw const FormatException('Required CSV columns: date,type,amount.');
  }
  return [
    for (final values in rows)
      if (values.length == headers.length)
        {for (var i = 0; i < headers.length; i++) headers[i]: values[i]}
      else
        throw const FormatException(
          'A CSV row has a different number of columns.',
        ),
  ];
}
