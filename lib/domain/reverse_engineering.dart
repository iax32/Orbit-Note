import 'dart:convert';

/// Hexadecimal addresses stay strings so 64-bit values round-trip on the web.
String normalizeResearchAddress(String value) {
  final text = value.trim().replaceFirst(RegExp(r'^0[xX]'), '');
  if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(text)) {
    throw FormatException('Invalid hexadecimal address: $value');
  }
  final number = BigInt.parse(text, radix: 16);
  if (number.bitLength > 64) {
    throw const FormatException('Address exceeds 64 bits.');
  }
  return '0x${number.toRadixString(16).toUpperCase()}';
}

/// Incomplete legacy context is readable but cannot identify a unique location.
class ResearchAddress {
  const ResearchAddress({
    this.binaryId = '',
    this.binaryVersion = '',
    this.moduleId = '',
    this.module = '',
    this.addressSpace = 'virtual',
    this.address = '',
    this.rva = '',
    this.moduleBase = '',
  });

  final String binaryId, binaryVersion, moduleId, module, addressSpace;
  final String address, rva, moduleBase;

  Map<String, dynamic> toProperties() {
    if (!const ['virtual', 'rva', 'file'].contains(addressSpace)) {
      throw const FormatException(
        'Address space must be virtual, rva or file.',
      );
    }
    final absolute = address.isEmpty ? '' : normalizeResearchAddress(address);
    final offset = rva.isEmpty ? '' : normalizeResearchAddress(rva);
    final base = moduleBase.isEmpty ? '' : normalizeResearchAddress(moduleBase);
    if (addressSpace == 'file' && base.isNotEmpty) {
      throw const FormatException('A file offset cannot have a module base.');
    }
    if (addressSpace == 'file' && offset.isNotEmpty) {
      throw const FormatException('A file offset cannot also be an RVA.');
    }
    var resolvedRva = offset;
    if (addressSpace == 'rva') {
      if (absolute.isNotEmpty && offset.isNotEmpty && absolute != offset) {
        throw const FormatException('Relative address and RVA disagree.');
      }
      resolvedRva = offset.isEmpty ? absolute : offset;
    }
    if (addressSpace == 'virtual' && base.isNotEmpty && absolute.isNotEmpty) {
      final difference =
          BigInt.parse(absolute.substring(2), radix: 16) -
          BigInt.parse(base.substring(2), radix: 16);
      if (difference.isNegative) {
        throw const FormatException('Address is below the module base.');
      }
      resolvedRva = normalizeResearchAddress(difference.toRadixString(16));
      if (offset.isNotEmpty && offset != resolvedRva) {
        throw const FormatException('Address, RVA and module base disagree.');
      }
    }
    return {
      if (binaryId.isNotEmpty) 'binaryId': binaryId,
      if (binaryVersion.isNotEmpty) 'binaryVersion': binaryVersion,
      if (moduleId.isNotEmpty) 'moduleId': moduleId,
      if (module.isNotEmpty) 'module': module,
      'addressSpace': addressSpace,
      if (absolute.isNotEmpty) 'address': absolute,
      if (resolvedRva.isNotEmpty) 'rva': resolvedRva,
      if (base.isNotEmpty) 'moduleBase': base,
    };
  }

  /// No numeric-address-only fallback: build identity must be explicit.
  String? get identity {
    final properties = toProperties();
    if (binaryId.isEmpty || binaryVersion.isEmpty || moduleId.isEmpty) {
      return null;
    }
    final relative = properties['rva'];
    final location = addressSpace == 'virtual' && relative != null
        ? ['rva', relative]
        : [addressSpace, properties['address'] ?? relative];
    if (location.last == null) return null;
    return jsonEncode([binaryId, binaryVersion, moduleId, ...location]);
  }
}

class ImportedFunction {
  ImportedFunction(Map<String, dynamic> input, Map<String, dynamic> context) {
    rawMetadata = {
      'record': Map<String, dynamic>.from(input),
      'context': Map<String, dynamic>.from(context),
    };
    String value(String key, [String fallback = '']) {
      final raw = input[key] ?? context[key] ?? fallback;
      if (raw is! String) {
        throw FormatException(
          '$key must be text; hexadecimal addresses need quotes.',
        );
      }
      return raw.trim();
    }

    name = value('name');
    if (name.isEmpty) {
      throw const FormatException('Every function needs a name.');
    }
    final address = value('address');
    final rva = value('rva');
    if (address.isEmpty && rva.isEmpty) {
      throw FormatException('$name needs an address or RVA.');
    }
    location = ResearchAddress(
      address: address,
      rva: rva,
      module: value('module'),
      moduleId: value('moduleId'),
      binaryId: value('binaryId'),
      binaryVersion: value('binaryVersion'),
      moduleBase: value('moduleBase'),
      addressSpace: value('addressSpace', address.isEmpty ? 'rva' : 'virtual'),
    );
    location.toProperties(); // Validate the entire batch before any write.
    purpose = value('purpose', value('comment'));
    status = value('status', 'Investigating');
    confidence = value('confidence', 'Medium');
  }
  late final String name, purpose, status, confidence;
  late final ResearchAddress location;
  late final Map<String, dynamic> rawMetadata;
}

/// Versioned manual interchange, not a live debugger connector.
class FunctionImportPlan {
  FunctionImportPlan(this.functions, {this.tool = '', this.source = ''});
  final List<ImportedFunction> functions;
  final String tool, source;

  factory FunctionImportPlan.json(String text) {
    final decoded = jsonDecode(text);
    Map<String, dynamic> context = {};
    List<dynamic> records;
    var tool = '';
    var source = '';
    if (decoded is List) {
      records = decoded;
    } else if (decoded is Map && decoded['functions'] is List) {
      if (decoded['version'] != null && decoded['version'] != 1) {
        throw const FormatException('Unsupported function export version.');
      }
      if (decoded['context'] != null) {
        if (decoded['context'] is! Map) {
          throw const FormatException('Export context must be an object.');
        }
        context = Map<String, dynamic>.from(decoded['context'] as Map);
      }
      records = decoded['functions'] as List;
      tool = decoded['tool']?.toString() ?? '';
      source = decoded['source']?.toString() ?? '';
    } else {
      throw const FormatException('Expected an array or a functions export.');
    }
    return FunctionImportPlan(
      [
        for (final row in records)
          if (row is Map)
            ImportedFunction(Map<String, dynamic>.from(row), context)
          else
            throw const FormatException('Every function must be an object.'),
      ],
      tool: tool,
      source: source,
    );
  }

  factory FunctionImportPlan.csv(String text) {
    final rows = _csvRows(text);
    if (rows.isEmpty) return FunctionImportPlan([]);
    final first = rows.first.map((s) => s.trim().toLowerCase()).toList();
    final hasHeader =
        first.contains('name') &&
        (first.contains('address') || first.contains('rva'));
    const keys = {
      'binaryid': 'binaryId',
      'binaryversion': 'binaryVersion',
      'moduleid': 'moduleId',
      'modulebase': 'moduleBase',
      'addressspace': 'addressSpace',
    };
    final header = hasHeader
        ? first.map((key) => keys[key] ?? key).toList()
        : ['name', 'address'];
    final functions = <ImportedFunction>[];
    for (final row in rows.skip(hasHeader ? 1 : 0)) {
      if (row.length != header.length) {
        throw const FormatException('CSV row does not match the column count.');
      }
      functions.add(
        ImportedFunction({
          for (var i = 0; i < header.length; i++) header[i]: row[i],
        }, {}),
      );
    }
    return FunctionImportPlan(functions);
  }
}

List<List<String>> _csvRows(String input) {
  final text = input.replaceFirst(RegExp(r'^\uFEFF'), '');
  final rows = <List<String>>[];
  var row = <String>[];
  var field = StringBuffer();
  var quoted = false;
  var closed = false;
  void finishField() {
    row.add(field.toString());
    field = StringBuffer();
    closed = false;
  }

  void finishRow() {
    finishField();
    if (row.any((s) => s.trim().isNotEmpty)) rows.add(row);
    row = [];
  }

  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (quoted) {
      if (char == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
          closed = true;
        }
      } else {
        field.write(char);
      }
    } else if (char == ',' || char == '\n' || char == '\r') {
      if (char == ',') {
        finishField();
      } else {
        finishRow();
        if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      }
    } else if (char == '"' && field.isEmpty && !closed) {
      quoted = true;
    } else if (closed && char.trim().isNotEmpty || char == '"') {
      throw const FormatException('Malformed quoted CSV field.');
    } else if (!closed) {
      field.write(char);
    }
  }
  if (quoted) throw const FormatException('Unterminated quoted CSV field.');
  if (field.isNotEmpty || row.isNotEmpty || closed) finishRow();
  return rows;
}

const researchRecordCategories = [
  'Binary',
  'Module',
  'Function',
  'Address',
  'Structure',
  'Class',
  'Import',
  'String',
  'Finding',
  'Hypothesis',
  'Patch',
  'Call Graph',
];
