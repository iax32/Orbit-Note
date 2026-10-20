import 'dart:async';
import 'dart:convert';
import '../domain/code_project.dart';
import '../domain/code_language.dart';

/// Content-Length is a byte count; UTF-8 may span arbitrary stream chunks.
class LanguageFrames {
  final _bytes = <int>[];
  int? _length;
  List<Map<String, dynamic>> add(List<int> bytes) {
    if (_bytes.length + bytes.length > 4 * 1024 * 1024) {
      throw const FormatException('Language message exceeds limit.');
    }
    _bytes.addAll(bytes);
    final messages = <Map<String, dynamic>>[];
    while (true) {
      if (_length == null) {
        var end = -1;
        for (var i = 0; i + 3 < _bytes.length; i++) {
          if (_bytes[i] == 13 &&
              _bytes[i + 1] == 10 &&
              _bytes[i + 2] == 13 &&
              _bytes[i + 3] == 10) {
            end = i;
            break;
          }
        }
        if (end < 0) {
          if (_bytes.length > 8192) {
            throw const FormatException('Invalid language header.');
          }
          break;
        }
        final header = ascii.decode(_bytes.sublist(0, end));
        final lengths = RegExp(
          r'^Content-Length:\s*(\d+)\s*$',
          multiLine: true,
          caseSensitive: false,
        ).allMatches(header.replaceAll('\r', '')).toList();
        if (lengths.length != 1) {
          throw const FormatException('Invalid language frame length.');
        }
        _length = int.parse(lengths.single[1]!);
        if (_length! > 2 * 1024 * 1024) {
          throw const FormatException('Language response exceeds limit.');
        }
        _bytes.removeRange(0, end + 4);
      }
      if (_bytes.length < _length!) break;
      final payload = _bytes.sublist(0, _length!);
      _bytes.removeRange(0, _length!);
      _length = null;
      final value = jsonDecode(utf8.decode(payload));
      if (value is! Map || value['jsonrpc'] != '2.0') {
        throw const FormatException('Invalid language response.');
      }
      messages.add(Map<String, dynamic>.from(value));
    }
    return messages;
  }
}

class CodeLanguageClient {
  CodeLanguageClient(this.transport) {
    subscription = transport.output.listen(
      receive,
      onError: (Object e) => fail(e),
      onDone: () =>
          fail(const FormatException('Language server disconnected.')),
    );
  }
  final LanguageTransport transport;
  final frames = LanguageFrames();
  late final StreamSubscription<List<int>> subscription;
  final pending = <int, Completer<dynamic>>{};
  final documents = <String, ({String text, int version})>{};
  final problems =
      StreamController<({Uri uri, List<CodeProblem> problems})>.broadcast();
  int serial = 0, syncKind = 1;
  bool closed = false;
  String? failure;
  Future<void> _writes = Future.value();
  Future<void> send(Map<String, dynamic> message) {
    if (closed) {
      return Future.error(const FormatException('Language server is closed.'));
    }
    final bytes = utf8.encode(jsonEncode({'jsonrpc': '2.0', ...message}));
    final packet = [
      ...ascii.encode('Content-Length: ${bytes.length}\r\n\r\n'),
      ...bytes,
    ];
    final result = _writes.then((_) => transport.send(packet));
    _writes = result.catchError((Object _) {});
    return result;
  }

  Future<dynamic> request(String method, Map<String, dynamic> params) async {
    if (failure != null) throw FormatException(failure!);
    final id = ++serial, result = Completer<dynamic>();
    pending[id] = result;
    try {
      final values = await Future.wait<dynamic>([
        send({'id': id, 'method': method, 'params': params}),
        result.future.timeout(const Duration(seconds: 12)),
      ], eagerError: true);
      return values.last;
    } finally {
      pending.remove(id);
    }
  }

  Future<void> initialize(Uri root) async {
    final result = await request('initialize', {
      'processId': null,
      'rootUri': root.toString(),
      'workspaceFolders': [
        {'uri': root.toString(), 'name': 'Selected project'},
      ],
      'capabilities': {
        'general': {
          'positionEncodings': ['utf-16'],
        },
        'textDocument': {
          'completion': {
            'completionItem': {'snippetSupport': false},
          },
          'publishDiagnostics': {'versionSupport': true},
        },
        'workspace': {'applyEdit': false},
      },
      'clientInfo': {'name': 'Orbit Note', 'version': '1.0'},
    });
    if (result is! Map || result['capabilities'] is! Map) {
      throw const FormatException('Language server initialization failed.');
    }
    final caps = result['capabilities'] as Map;
    if (caps['positionEncoding'] != null &&
        caps['positionEncoding'] != 'utf-16') {
      throw const FormatException(
        'This server did not select UTF-16 positions.',
      );
    }
    final sync = caps['textDocumentSync'];
    syncKind = sync is Map
        ? sync['change'] as int? ?? 1
        : sync is int
        ? sync
        : 1;
    await send({'method': 'initialized', 'params': <String, dynamic>{}});
  }

  void fail(Object error) {
    if (closed) return;
    failure =
        'Language server stopped or returned an invalid response. Reconnect language tools.';
    for (final result in pending.values) {
      if (!result.isCompleted) result.completeError(FormatException(failure!));
    }
    pending.clear();
  }

  void receive(List<int> bytes) {
    if (closed) return;
    try {
      for (final message in frames.add(bytes)) {
        final id = message['id'];
        if (message['method'] != null && id != null) {
          // Servers cannot initiate edits, run commands or obtain arbitrary config.
          send({
            'id': id,
            'error': {
              'code': -32601,
              'message': 'Client-side workspace mutations are disabled.',
            },
          }).catchError((Object _) {});
        } else if (id is int && pending.containsKey(id)) {
          final result = pending[id]!;
          if (!result.isCompleted) {
            if (message['error'] != null) {
              result.completeError(
                const FormatException(
                  'The language server could not complete this request.',
                ),
              );
            } else {
              result.complete(message['result']);
            }
          }
        } else if (message['method'] == 'textDocument/publishDiagnostics') {
          final params = message['params'];
          if (params is! Map ||
              params['uri'] is! String ||
              params['diagnostics'] is! List) {
            continue;
          }
          final uri = Uri.parse(params['uri'] as String),
              doc = documents[params['uri']];
          if (doc == null ||
              (params['version'] is int && params['version'] != doc.version)) {
            continue;
          }
          final next = <CodeProblem>[];
          for (final item in (params['diagnostics'] as List).take(200)) {
            if (item is! Map ||
                item['message'] is! String ||
                item['range'] is! Map) {
              continue;
            }
            final position = CodePosition.parse(
              (item['range'] as Map)['start'],
            );
            codeOffset(doc.text, position);
            final text = item['message'] as String;
            next.add(
              CodeProblem(
                uri,
                position,
                text.length > 4000 ? text.substring(0, 4000) : text,
                item['severity'] is int ? item['severity'] as int : 3,
                params['version'] is int ? params['version'] as int : null,
              ),
            );
          }
          problems.add((uri: uri, problems: next));
        }
      }
    } on Object catch (e) {
      fail(e);
    }
  }

  Future<void> update(
    Uri uri,
    String language,
    String text,
    int version,
  ) async {
    final previous = documents[uri.toString()];
    documents[uri.toString()] = (text: text, version: version);
    if (previous == null) {
      await send({
        'method': 'textDocument/didOpen',
        'params': {
          'textDocument': {
            'uri': uri.toString(),
            'languageId': language,
            'version': version,
            'text': text,
          },
        },
      });
    } else if (previous.version != version || previous.text != text) {
      await send({
        'method': 'textDocument/didChange',
        'params': {
          'textDocument': {'uri': uri.toString(), 'version': version},
          'contentChanges': [
            {
              'text': text,
              if (syncKind == 2)
                'range': {
                  'start': const CodePosition(0, 0).json,
                  'end': codePosition(previous.text, previous.text.length).json,
                },
            },
          ],
        },
      });
    }
  }

  Future<void> closeDocument(Uri uri) async {
    documents.remove(uri.toString());
    await send({
      'method': 'textDocument/didClose',
      'params': {
        'textDocument': {'uri': uri.toString()},
      },
    });
  }

  Future<List<CodeSuggestion>> complete(
    Uri uri,
    String text,
    int offset,
  ) async {
    final value = await request('textDocument/completion', {
      'textDocument': {'uri': uri.toString()},
      'position': codePosition(text, offset).json,
    });
    final items = value is List
        ? value
        : value is Map && value['items'] is List
        ? value['items'] as List
        : [];
    final word = RegExp(
      r'[A-Za-z_0-9]*$',
    ).firstMatch(text.substring(0, offset))!;
    final result = <CodeSuggestion>[];
    for (final item in items.take(100)) {
      if (item is! Map ||
          item['label'] is! String ||
          item['insertTextFormat'] == 2) {
        continue;
      }
      try {
        final edit = item['textEdit'] == null
            ? CodeTextEdit(
                word.start,
                offset,
                item['insertText'] is String
                    ? item['insertText'] as String
                    : item['label'] as String,
              )
            : CodeTextEdit.parse(text, item['textEdit']);
        final extras = item['additionalTextEdits'];
        final edits = [
          edit,
          if (extras is List)
            ...extras.take(30).map((e) => CodeTextEdit.parse(text, e)),
        ];
        applyCodeEdits(text, edits);
        result.add(
          CodeSuggestion(
            item['label'] as String,
            item['detail']?.toString() ?? 'Language server',
            edits,
          ),
        );
      } on FormatException {
        /* Unsupported/unsafe proposals stay unapplied. */
      }
    }
    return result;
  }

  Future<void> close() async {
    if (closed) return;
    try {
      await request('shutdown', {}).timeout(const Duration(seconds: 2));
      await send({'method': 'exit'});
    } on Object {
      /* Server may have exited. */
    }
    closed = true;
    for (final result in pending.values) {
      if (!result.isCompleted) {
        result.completeError(const FormatException('Language session closed.'));
      }
    }
    pending.clear();
    await subscription.cancel();
    await transport.close();
    await problems.close();
  }
}
