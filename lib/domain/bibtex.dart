import 'document_citations.dart';

/// A bounded data parser. It never executes TeX, evaluates macros or fetches URLs.
class BibtexImport {
  BibtexImport(String input) {
    if (input.length > 1024 * 1024) {
      throw const FormatException('BibTeX import is limited to 1 MiB of text.');
    }
    final parser = _BibtexParser(input);
    if (input.startsWith('\ufeff')) parser.at = 1;
    while (parser.at < input.length) {
      parser.space();
      if (parser.at == input.length) break;
      parser.expect('@');
      final type = parser.token().toLowerCase();
      if (!RegExp(r'^[A-Za-z]+$').hasMatch(type)) {
        parser.fail('Unsupported entry type');
      }
      parser.space();
      if (parser.at >= input.length || !'{('.contains(input[parser.at])) {
        parser.fail('Expected an entry opening brace');
      }
      final closing = input[parser.at++] == '{' ? '}' : ')';
      if (['comment', 'preamble', 'string'].contains(type)) {
        parser.skipEntry(closing);
        warnings.add(
          '@$type is retained in the original import file, not evaluated or stored as a source.',
        );
        continue;
      }
      parser.space();
      final keyStart = parser.at;
      while (parser.at < input.length &&
          input[parser.at] != ',' &&
          input[parser.at] != closing) {
        parser.at++;
      }
      final key = input.substring(keyStart, parser.at).trim();
      if (key.isEmpty ||
          key.length > 200 ||
          RegExp(r'[\s{}()=#\\]').hasMatch(key)) {
        parser.fail('Invalid citation key');
      }
      final fields = <String, String>{};
      var unsupported = false;
      parser.space();
      if (parser.take(closing)) {
        warnings.add('$key has no fields and was skipped.');
        continue;
      }
      parser.expect(',');
      while (true) {
        parser.space();
        if (parser.take(closing)) break;
        final name = parser.token().toLowerCase();
        if (!RegExp(r'^[A-Za-z][A-Za-z0-9_-]*$').hasMatch(name)) {
          parser.fail('Invalid field name');
        }
        parser.space();
        parser.expect('=');
        parser.space();
        final parts = <String>[];
        do {
          parser.space();
          if (parser.at == input.length) parser.fail('Missing field value');
          final char = input[parser.at];
          if (char == '{') {
            parts.add(parser.braced());
          } else if (char == '"') {
            parts.add(parser.quoted());
          } else {
            final start = parser.at;
            while (parser.at < input.length &&
                !',#$closing'.contains(input[parser.at]) &&
                !RegExp(r'\s').hasMatch(input[parser.at])) {
              parser.at++;
            }
            if (start == parser.at) parser.fail('Empty field value');
            final value = input.substring(start, parser.at);
            if (!RegExp(r'^\d+$').hasMatch(value)) unsupported = true;
            parts.add(value);
          }
          parser.space();
        } while (parser.take('#'));
        if (fields.containsKey(name)) {
          parser.fail('Duplicate field $name in $key');
        }
        fields[name] = parts.join();
        if (fields.length > 100) {
          parser.fail('An entry has more than 100 fields');
        }
        if (fields[name]!.length > 16000) {
          parser.fail('A field exceeds 16,000 characters');
        }
        if (parser.take(closing)) break;
        parser.expect(',');
      }
      if (unsupported) {
        warnings.add(
          '$key uses unresolved macros; the entire entry was skipped. Expand macros before importing.',
        );
        continue;
      }
      String field(String name) => _display(fields[name] ?? '');
      var id = key.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '-');
      if (id.length > 80) id = id.substring(0, 80);
      if (id != key) {
        warnings.add(
          '$key uses the portable key $id; exports use this normalized key.',
        );
      }
      final publisherField = [
        'publisher',
        'journal',
        'booktitle',
      ].firstWhere(fields.containsKey, orElse: () => 'publisher');
      final source = CitationSource(
        id: id,
        title: field('title'),
        author: field('author'),
        year: field('year'),
        publisher: field(publisherField),
        doi: field('doi'),
        isbn: field('isbn'),
        url: field('url'),
      );
      try {
        source.validate();
      } catch (e) {
        warnings.add('$key was skipped: $e');
        continue;
      }
      records.add({
        ...source.toJson(),
        'bibtex': {
          'key': key,
          'type': type,
          'fields': fields,
          'publisherField': publisherField,
          'mapped': source.toJson(),
        },
      });
      if (fields.values.any((v) => v.contains('\\'))) {
        warnings.add(
          '$key contains TeX commands. Review the displayed source fields; commands are never executed.',
        );
      }
      if (records.length > 1000) {
        parser.fail('Import is limited to 1,000 sources');
      }
    }
  }
  final records = <Map<String, dynamic>>[];
  final warnings = <String>[];
}

String _display(String value) {
  final result = StringBuffer();
  for (var i = 0; i < value.length; i++) {
    if (value[i] == '\\' &&
        i + 1 < value.length &&
        '{}'.contains(value[i + 1])) {
      result.write(value[++i]);
    } else if (!'{}'.contains(value[i])) {
      result.write(value[i]);
    }
  }
  return result.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

String exportBibtex(DocumentCitations document) {
  if (document.duplicates.isNotEmpty) {
    throw const FormatException(
      'Repair duplicate source keys before exporting.',
    );
  }
  final output = StringBuffer(
    '% Orbit Note source export. TeX commands are data only.\n\n',
  );
  for (final source in document.sources.values) {
    final bib = document.record(source.id)['bibtex'];
    final fields = <String, String>{};
    Map? mapped;
    var type = 'misc', publisherField = 'publisher';
    if (bib is Map) {
      if (bib['type'] is String &&
          RegExp(r'^[A-Za-z]+$').hasMatch(bib['type'] as String)) {
        type = bib['type'] as String;
      }
      if (bib['fields'] is Map) {
        for (final entry in (bib['fields'] as Map).entries) {
          if (entry.key is String &&
              entry.value is String &&
              RegExp(
                r'^[A-Za-z][A-Za-z0-9_-]*$',
              ).hasMatch(entry.key as String)) {
            fields[entry.key as String] = entry.value as String;
          }
        }
      }
      if ([
        'publisher',
        'journal',
        'booktitle',
      ].contains(bib['publisherField'])) {
        publisherField = bib['publisherField'] as String;
      }
      if (bib['mapped'] is Map) mapped = bib['mapped'] as Map;
    }
    final values = {
      'title': source.title,
      'author': source.author,
      'year': source.year,
      publisherField: source.publisher,
      'doi': source.doi,
      'isbn': source.isbn,
      'url': source.url,
    };
    for (final entry in values.entries) {
      final mappedKey = entry.key == publisherField ? 'publisher' : entry.key;
      if (mapped?[mappedKey] == entry.value && fields.containsKey(entry.key)) {
        continue;
      }
      if (entry.value.isEmpty) {
        fields.remove(entry.key);
      } else {
        fields[entry.key] = _escape(entry.value);
      }
    }
    output.writeln('@$type{${source.id},');
    for (final entry in fields.entries) {
      // Reparse each retained value to reject malformed/future metadata injection.
      final parser = _BibtexParser('{${entry.value}}');
      parser.braced();
      if (parser.at != parser.input.length) {
        throw FormatException(
          'Unsafe BibTeX value in ${source.id}/${entry.key}.',
        );
      }
      output.writeln('  ${entry.key} = {${entry.value}},');
    }
    output.writeln('}\n');
  }
  return output.toString();
}

String _escape(String text) => text
    .split('')
    .map(
      (char) => switch (char) {
        '\\' => r'\textbackslash{}',
        '{' => r'\{',
        '}' => r'\}',
        _ => char,
      },
    )
    .join();

class _BibtexParser {
  _BibtexParser(this.input);
  final String input;
  int at = 0;
  Never fail(String message) =>
      throw FormatException('$message at character ${at + 1}.');
  void space() {
    while (at < input.length) {
      if (RegExp(r'\s').hasMatch(input[at])) {
        at++;
      } else if (input[at] == '%') {
        while (at < input.length && input[at] != '\n') {
          at++;
        }
      } else {
        break;
      }
    }
  }

  bool take(String value) {
    if (at < input.length && input[at] == value) {
      at++;
      return true;
    }
    return false;
  }

  void expect(String value) {
    if (!take(value)) fail('Expected $value');
  }

  String token() {
    final start = at;
    while (at < input.length && RegExp(r'[A-Za-z0-9_-]').hasMatch(input[at])) {
      at++;
    }
    if (start == at) fail('Expected a name');
    return input.substring(start, at);
  }

  String braced() {
    expect('{');
    final start = at;
    var depth = 1;
    while (at < input.length) {
      final char = input[at++];
      if (char == '\\' && at < input.length) {
        at++;
        continue;
      }
      if (char == '{') depth++;
      if (depth > 64) fail('Brace nesting exceeds 64 levels');
      if (char == '}') {
        depth--;
        if (depth == 0) return input.substring(start, at - 1);
      }
    }
    fail('Unclosed braced value');
  }

  String quoted() {
    expect('"');
    final start = at;
    var depth = 0;
    while (at < input.length) {
      final char = input[at++];
      if (char == '\\' && at < input.length) {
        at++;
        continue;
      }
      if (char == '{') depth++;
      if (char == '}') depth--;
      if (depth < 0 || depth > 64) fail('Invalid quoted brace nesting');
      if (char == '"' && depth == 0) return input.substring(start, at - 1);
    }
    fail('Unclosed quoted value');
  }

  void skipEntry(String closing) {
    var depth = 1;
    while (at < input.length) {
      final char = input[at++];
      if (char == '"') {
        at--;
        quoted();
        continue;
      }
      if (closing == ')' && char == '{') {
        at--;
        braced();
        continue;
      }
      if (char == '\\' && at < input.length) {
        at++;
        continue;
      }
      if (char == (closing == '}' ? '{' : '(')) depth++;
      if (char == closing) depth--;
      if (depth > 64) fail('Entry nesting exceeds 64 levels');
      if (depth == 0) return;
    }
    fail('Unclosed skipped entry');
  }
}
