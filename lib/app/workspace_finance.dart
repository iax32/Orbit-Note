part of 'workspace_controller.dart';

class FinanceImportRow {
  const FinanceImportRow(
    this.id,
    this.title,
    this.body,
    this.data,
    this.duplicate,
  );
  final String id, title, body;
  final Map<String, dynamic> data;
  final bool duplicate;
}

extension WorkspaceFinance on WorkspaceController {
  FinanceIndex get financeIndex {
    var unchanged =
        _financeIndexGeneration == workspaceGeneration &&
        _financeSnapshot.length == objects.length;
    if (unchanged) {
      for (var i = 0; i < objects.length; i++) {
        if (!identical(_financeSnapshot[i], objects[i])) {
          unchanged = false;
          break;
        }
      }
    }
    if (!unchanged || _cachedFinanceIndex == null) {
      // Objects are immutable. Snapshot identities also detect in-place list
      // edits and equal-revision remote replacements without trusting timestamps.
      _financeSnapshot = List.of(objects);
      _financeIndexGeneration = workspaceGeneration;
      _cachedFinanceIndex = FinanceIndex(_financeSnapshot);
    }
    return _cachedFinanceIndex!;
  }

  Future<T?> _financeCommand<T>(Future<T> Function() action) async {
    if (_financeBusy || loading || !hasWorkspace || repository.readOnly) {
      return null;
    }
    final generation = workspaceGeneration;
    if (!await flushAll() ||
        generation != workspaceGeneration ||
        _financeBusy) {
      return null;
    }
    _financeBusy = true;
    final work = Completer<void>();
    _financeWork = work;
    try {
      final result = await action();
      if (generation != workspaceGeneration) return null;
      error = null;
      return result;
    } catch (e) {
      if (generation == workspaceGeneration) {
        error = '$e';
        notify();
      }
      return null;
    } finally {
      _financeBusy = false;
      work.complete();
      if (identical(_financeWork, work)) _financeWork = null;
    }
  }

  void _validateFinanceLinks(
    Map<String, dynamic> data, {
    UniversalObject? previous,
  }) {
    validateFinance(data);
    final before = previous == null
        ? <String, dynamic>{}
        : financeData(previous);
    final kind = data['kind'];
    for (final key in ['accountId', 'toAccountId']) {
      final id = data[key];
      if (id == null || id == '') continue;
      final account = find(id as String);
      if (financeKind(account) != 'account' ||
          financeData(account!)['currency'] != data['currency']) {
        throw const FormatException(
          'Choose existing accounts with the same currency. Cross-currency transfers need separate manually converted entries.',
        );
      }
      if (financeData(account)['archived'] == true && before[key] != id) {
        throw const FormatException('This account is archived.');
      }
    }
    for (final key in ['sourceId', 'receiptId']) {
      final id = data[key];
      if (id is String &&
          id.isNotEmpty &&
          find(id)?.isDeleted != false &&
          before[key] != id) {
        throw const FormatException(
          'The linked receipt or source is unavailable.',
        );
      }
    }
    if (kind == 'account' &&
        previous != null &&
        financeData(previous)['currency'] != data['currency'] &&
        financeIndex.transactions.any(
          (t) => financeReferences(t).contains(previous.id),
        )) {
      throw const FormatException(
        'An account with recorded transactions cannot change currency. Create a new account instead.',
      );
    }
    if (kind == 'budget' &&
        activeObjects.any(
          (o) =>
              o.id != previous?.id &&
              financeKind(o) == 'budget' &&
              financeData(o)['archived'] != true &&
              financeData(o)['month'] == data['month'] &&
              financeData(o)['currency'] == data['currency'] &&
              financeCategory(financeData(o)['category']) ==
                  financeCategory(data['category']),
        )) {
      throw const FormatException(
        'A budget already exists for this month, category and currency. Edit that budget.',
      );
    }
  }

  Future<UniversalObject> _writeFinance(
    String title,
    Map<String, dynamic> data,
    String body, {
    String? id,
  }) async {
    _validateFinanceLinks(data);
    final now = DateTime.now().toUtc();
    final result = await repository.save(
      UniversalObject(
        id: id ?? const Uuid().v4(),
        workspaceId: repository.workspaceId,
        typeId: 'orbit.note',
        title: title.trim().isEmpty ? 'Finance record' : title.trim(),
        body: body,
        properties: {
          'finance': data,
          'tags': ['finance', data['kind']],
          'folder': 'Finance',
        },
        createdAt: now,
        updatedAt: now,
        revision: 0,
      ),
    );
    mergeRepositoryObjects();
    notify();
    return result;
  }

  Future<UniversalObject?> createFinance(
    String title,
    Map<String, dynamic> fields, {
    String body = '',
  }) {
    final data = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(fields)) as Map,
    );
    return _financeCommand(
      () => _writeFinance(title, {...data, 'version': 1}, body),
    );
  }

  Future<bool> saveFinance(
    UniversalObject expected,
    String title,
    Map<String, dynamic> updates, {
    String? body,
  }) async {
    final changes = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(updates)) as Map,
    );
    return await _financeCommand(() async {
          if (!identical(find(expected.id), expected) ||
              financeKind(expected) == null ||
              changes.containsKey('kind') &&
                  changes['kind'] != financeData(expected)['kind'] ||
              changes.containsKey('version') && changes['version'] != 1) {
            throw const FormatException(
              'This finance record changed. Reopen it before saving.',
            );
          }
          final data = {...financeData(expected), ...changes};
          for (final key in ['billId', 'occurrence', 'importKey']) {
            if (data[key] != financeData(expected)[key]) {
              throw const FormatException(
                'Recorded occurrence/import identities cannot be changed.',
              );
            }
          }
          _validateFinanceLinks(data, previous: expected);
          final ok = await _commitProductivity(
            expected,
            {'finance': data},
            title: title,
            body: body,
          );
          if (!ok) throw FormatException(error ?? 'Finance save failed.');
          return true;
        }) ??
        false;
  }

  Future<UniversalObject?> recordBill(
    UniversalObject expected,
    String date,
  ) => _financeCommand(() async {
    if (!identical(find(expected.id), expected) ||
        financeKind(expected) != 'bill') {
      throw const FormatException('The bill changed. Reopen it.');
    }
    final due = financeIndex.dueDates(
      expected,
      parseCalendarDate(date)!,
      limit: 16000,
    );
    final id = const Uuid().v5(
      repository.workspaceId,
      'finance-bill:${expected.id}:$date',
    );
    final prior = find(id);
    if (prior != null) {
      if (prior.isDeleted) {
        throw const FormatException(
          'This payment is in Trash. Restore it there to avoid duplicate payments.',
        );
      }
      return prior;
    }
    if (!due.contains(date)) {
      throw const FormatException('Choose an unpaid scheduled occurrence.');
    }
    final d = financeData(expected);
    return _writeFinance(
      '${expected.title} · $date',
      {
        'version': 1,
        'kind': 'transaction',
        'direction': d['direction'],
        'amountMinor': d['amountMinor'],
        'currency': d['currency'],
        'accountId': d['accountId'],
        'date': date,
        'category': d['category'] ?? 'Subscriptions',
        'payee': d['payee'] ?? expected.title,
        'billId': expected.id,
        'occurrence': date,
        'cleared': true,
        if (d['sourceId'] != null) 'sourceId': d['sourceId'],
      },
      'Recorded from [[${expected.id}|${expected.title}]].',
      id: id,
    );
  });

  List<FinanceImportRow> previewFinanceImport(
    String csv,
    String defaultAccountId,
  ) {
    final rows = parseFinanceCsv(csv), result = <FinanceImportRow>[];
    final occurrences = <String, int>{};
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final account = find(
        row['accountId']?.trim().isNotEmpty == true
            ? row['accountId']
            : defaultAccountId,
      );
      if (financeKind(account) != 'account') {
        throw FormatException('Row ${i + 2}: choose an existing account.');
      }
      final currency = row['currency']?.trim().isNotEmpty == true
          ? row['currency']!.trim().toUpperCase()
          : financeData(account!)['currency'] as String;
      final data = <String, dynamic>{
        'version': 1,
        'kind': 'transaction',
        'direction': row['type']!.trim().toLowerCase(),
        'amountMinor': parseMoney(row['amount']!, currency),
        'currency': currency,
        'date': row['date']!.trim(),
        'accountId': account!.id,
        if (row['toAccountId']?.trim().isNotEmpty == true)
          'toAccountId': row['toAccountId']!.trim(),
        'category': row['category']?.trim().isNotEmpty == true
            ? row['category']!.trim()
            : 'Other',
        'payee': row['payee']?.trim() ?? '',
        'cleared': row['cleared']?.trim() == 'true',
      };
      final fingerprint = sha256
          .convert(utf8.encode(jsonEncode([data, row['memo'] ?? ''])))
          .toString();
      final occurrence = occurrences.update(
        fingerprint,
        (n) => n + 1,
        ifAbsent: () => 1,
      );
      final id = const Uuid().v5(
        repository.workspaceId,
        'finance-csv:$fingerprint:$occurrence',
      );
      data['importKey'] = '$fingerprint:$occurrence';
      _validateFinanceLinks(data, previous: find(id));
      result.add(
        FinanceImportRow(
          id,
          row['payee']?.trim().isNotEmpty == true
              ? row['payee']!.trim()
              : '${data['direction']} · ${data['date']}',
          row['memo'] ?? '',
          data,
          find(id) != null,
        ),
      );
    }
    return result;
  }

  Future<({int added, int skipped})?> importFinanceCsv(
    String csv,
    String accountId, {
    List<FinanceImportRow>? expectedRows,
  }) => _financeCommand(() async {
    final rows = previewFinanceImport(csv, accountId);
    if (expectedRows != null &&
        (rows.length != expectedRows.length ||
            List.generate(rows.length, (i) => i).any(
              (i) =>
                  rows[i].id != expectedRows[i].id ||
                  !jsonValuesEqual(rows[i].data, expectedRows[i].data) ||
                  rows[i].body != expectedRows[i].body,
            ))) {
      throw const FormatException(
        'The account or import changed after preview. Preview the CSV again before importing.',
      );
    }
    var added = 0, skipped = 0;
    for (final row in rows) {
      if (find(row.id) != null) {
        skipped++;
        continue;
      }
      try {
        await _writeFinance(row.title, row.data, row.body, id: row.id);
        added++;
      } catch (e) {
        throw FormatException(
          '$added rows saved, $skipped skipped before failure: $e. Retry the same CSV to resume without duplicates.',
        );
      }
    }
    return (added: added, skipped: skipped);
  });

  Future<UniversalObject?> createFinanceReport(String month, String currency) =>
      create(
        'orbit.note',
        open: false,
        title: 'Finance review · $month · $currency',
        body: financeIndex.report(month, currency),
        properties: {
          'folder': 'Finance',
          'tags': ['finance', 'review'],
        },
      );
}
