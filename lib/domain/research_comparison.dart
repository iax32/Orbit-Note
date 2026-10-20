import 'dart:convert';
import 'universal_object.dart';
import 'reverse_engineering.dart';

class ResearchBuild {
  const ResearchBuild(this.binaryId, this.version);
  final String binaryId, version;
  String get key => jsonEncode([binaryId, version]);
  String get label => '$binaryId · $version';
  @override
  bool operator ==(Object other) => other is ResearchBuild && other.key == key;
  @override
  int get hashCode => key.hashCode;
  static ResearchBuild? of(UniversalObject o) {
    final id = o.properties['binaryId'],
        version = o.properties['binaryVersion'];
    return id is String &&
            id.trim().isNotEmpty &&
            version is String &&
            version.trim().isNotEmpty
        ? ResearchBuild(id, version)
        : null;
  }
}

class ResearchComparisonRow {
  ResearchComparisonRow(
    this.symbol,
    this.module,
    List<UniversalObject> before,
    List<UniversalObject> after,
    this.state,
    List<String> fields,
  ) : before = List.unmodifiable(before),
      after = List.unmodifiable(after),
      fields = List.unmodifiable(fields);
  final String symbol, module, state;
  final List<UniversalObject> before, after;
  final List<String> fields;
  Iterable<UniversalObject> get sources => [...before, ...after];
}

class ResearchBuildComparison {
  ResearchBuildComparison(
    List<UniversalObject> records,
    this.baseline,
    this.candidate,
  ) : sources = List.unmodifiable(
        records.where(
          (o) =>
              !o.isDeleted &&
              o.properties['category'] == 'Function' &&
              (ResearchBuild.of(o) == baseline ||
                  ResearchBuild.of(o) == candidate),
        ),
      ) {
    if (baseline.binaryId != candidate.binaryId || baseline == candidate) {
      throw const FormatException(
        'Choose two different builds of the same binary.',
      );
    }
    if (sources.length > 1000) {
      throw const FormatException(
        'Compare up to 1,000 function records; narrow the project scope.',
      );
    }
    final groups =
        <
          String,
          (String, String, List<UniversalObject>, List<UniversalObject>)
        >{};
    final output = <ResearchComparisonRow>[];
    for (final o in sources) {
      final module = o.properties['moduleId'];
      final symbol = o.properties['symbol'] is String
          ? (o.properties['symbol'] as String).trim()
          : o.title.trim();
      final before = ResearchBuild.of(o) == baseline;
      // Auto-address names cannot be used as cross-build symbol identities.
      if (module is! String ||
          module.isEmpty ||
          symbol.isEmpty ||
          symbol == 'Unnamed function' ||
          RegExp(
            r'^(sub|fun|loc)_[0-9a-f]+$',
            caseSensitive: false,
          ).hasMatch(symbol)) {
        output.add(
          ResearchComparisonRow(
            o.title,
            module is String ? module : '',
            before ? [o] : [],
            before ? [] : [o],
            'Unmatched',
            const ['Explicit module and stable symbol required'],
          ),
        );
        continue;
      }
      final key = jsonEncode([module, symbol]);
      final group = groups.putIfAbsent(key, () => (symbol, module, [], []));
      (before ? group.$3 : group.$4).add(o);
    }
    for (final g in groups.values) {
      var state = 'Unchanged';
      final fields = <String>[];
      if (g.$3.length > 1 || g.$4.length > 1) {
        state = 'Ambiguous';
        fields.add('Duplicate module/symbol; no automatic pairing');
      } else if (g.$3.isEmpty) {
        state = 'Added';
      } else if (g.$4.isEmpty) {
        state = 'Removed';
      } else {
        final a = g.$3.single, b = g.$4.single;
        for (final key in [
          'purpose',
          'returnType',
          'parameters',
          'callingConvention',
          'status',
          'confidence',
        ]) {
          if ((a.properties[key] ?? '') != (b.properties[key] ?? '')) {
            fields.add(key);
          }
        }
        final locA = _location(a), locB = _location(b);
        if (locA == null || locB == null) {
          state = 'Unmatched';
          fields.add('Location context is invalid or incomplete');
        } else {
          if (locA != locB) fields.add('relative location');
          state = fields.isNotEmpty
              ? 'Changed'
              : a.properties['address'] != b.properties['address'] ||
                    a.properties['moduleBase'] != b.properties['moduleBase']
              ? 'Rebased'
              : 'Unchanged';
        }
      }
      output.add(
        ResearchComparisonRow(
          g.$1,
          g.$2,
          List.unmodifiable(g.$3),
          List.unmodifiable(g.$4),
          state,
          List.unmodifiable(fields),
        ),
      );
    }
    output.sort(
      (a, b) => '${a.module}\u0000${a.symbol}'.compareTo(
        '${b.module}\u0000${b.symbol}',
      ),
    );
    rows = List.unmodifiable(output);
  }
  final ResearchBuild baseline, candidate;
  final List<UniversalObject> sources;
  late final List<ResearchComparisonRow> rows;
  Map<String, int> get counts => {
    for (final state in states)
      state: rows.where((r) => r.state == state).length,
  };
  static const states = [
    'Changed',
    'Added',
    'Removed',
    'Rebased',
    'Unchanged',
    'Ambiguous',
    'Unmatched',
  ];
  static String? _location(UniversalObject o) {
    String value(String key, [String fallback = '']) =>
        o.properties[key] is String ? o.properties[key] as String : fallback;
    try {
      final location = ResearchAddress(
        binaryId: value('binaryId'),
        binaryVersion: value('binaryVersion'),
        moduleId: value('moduleId'),
        addressSpace: value('addressSpace', 'virtual'),
        address: value('address'),
        rva: value('rva'),
        moduleBase: value('moduleBase'),
      );
      final p = location.toProperties();
      // A bare virtual address cannot distinguish relocation from changed offset.
      if (p['rva'] != null) return jsonEncode(['rva', p['rva']]);
      if (p['addressSpace'] == 'file' && p['address'] != null) {
        return jsonEncode(['file', p['address']]);
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  String get markdown {
    final text = StringBuffer('# Recorded function-map comparison\n\n')
      ..writeln(
        'Baseline: ${_literal(baseline.label)}\n\nCandidate: ${_literal(candidate.label)}\n',
      )
      ..writeln(
        'This compares recorded metadata, not binary bytes or executable behaviour. '
        'Pairs use exact module ID and stable symbol. Missing rows may reflect incomplete imports. '
        'Unchanged means the compared metadata matches; edited note bodies are not compared.\n',
      );
    for (final row in rows) {
      text.writeln('## ${_literal(row.symbol)} · ${row.state}\n');
      text.writeln('Module: ${_literal(row.module)}\n');
      if (row.fields.isNotEmpty) {
        text.writeln('Review: ${row.fields.join(', ')}\n');
      }
      for (final (label, entries) in [
        ('Baseline', row.before),
        ('Candidate', row.after),
      ]) {
        for (final o in entries) {
          text.writeln(
            '- $label: [[${o.id}]] · revision ${o.revision} · '
            '${_literal((o.properties['rva'] ?? o.properties['address'] ?? 'location unrecorded').toString())}',
          );
        }
      }
      text.writeln();
    }
    return text.toString();
  }
}

String _literal(String text) => text
    .replaceAll(RegExp(r'[\r\n]'), ' ')
    .replaceAllMapped(RegExp(r'[\\`*_\[\]<>#|]'), (m) => '\\${m[0]}');
