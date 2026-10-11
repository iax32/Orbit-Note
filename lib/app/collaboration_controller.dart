import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../domain/collaboration.dart';
import 'workspace_controller.dart';

final collaborationProvider = Provider<CollaborationController>((ref) {
  final controller = CollaborationController(
    ref.read(workspaceProvider.notifier),
    http.Client(),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// Session credentials remain in memory. Local repository save/history is used
/// for every accepted remote mutation; server acknowledgement is a separate state.
class CollaborationController extends ChangeNotifier {
  CollaborationController(this.workspace, this.httpClient);
  final WorkspaceController workspace;
  final http.Client httpClient;
  Uri? endpoint;
  String? room, _token, _workspaceId;
  String role = '', status = 'Not connected';
  List<Map<String, dynamic>> peers = [];
  final conflicts = <String, String>{};
  final _documents = <String, Map<String, dynamic>>{};
  final _inflight = <String, Map<String, dynamic>>{};
  final session = const Uuid().v4();
  Timer? _timer;
  int _generation = 0;
  int? _workspaceGeneration;
  int _sequence = 0;
  bool busy = false, _disposed = false;
  // Note editors only need rebuilding when editing permission changes. Pointer
  // heartbeats must not reconstruct their Markdown preview every half second.
  final viewerChanges = ValueNotifier<bool>(false);
  Map<String, dynamic>? _cursor;
  DateTime _lastCursor = DateTime.fromMillisecondsSinceEpoch(0);
  bool get connected => room != null;
  bool shares(String id) => _documents.containsKey(id);
  bool get viewer => connected && role == 'viewer';
  String get connectionInvitation => jsonEncode({
    'version': 1,
    'server': '$endpoint',
    'room': room,
    'token': _token,
  });
  bool get _validWorkspace =>
      workspace.hasWorkspace &&
      workspace.repository.workspaceId == _workspaceId &&
      workspace.workspaceGeneration == _workspaceGeneration;
  void _notify() {
    if (!_disposed) {
      viewerChanges.value = viewer;
      notifyListeners();
    }
  }

  static Uri validateEndpoint(String value) {
    final uri = Uri.parse(value.trim());
    if (uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.scheme != 'https' &&
            !(uri.scheme == 'http' &&
                ['localhost', '127.0.0.1', '::1'].contains(uri.host)))) {
      throw const FormatException(
        'Use HTTPS for a remote server, or HTTP on localhost.',
      );
    }
    return uri.replace(path: uri.path.replaceFirst(RegExp(r'/$'), ''));
  }

  Future<Map<String, dynamic>> request(
    Uri server,
    String token,
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final request = http.Request(method, Uri.parse('$server$path'))
      ..followRedirects = false;
    request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final incoming = await httpClient
        .send(request)
        .timeout(const Duration(seconds: 20));
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in incoming.stream.timeout(
      const Duration(seconds: 20),
    )) {
      if (bytes.length + chunk.length > 130 * 1024 * 1024) {
        throw const FormatException(
          'Server response exceeds the safety limit.',
        );
      }
      bytes.add(chunk);
    }
    final response = http.Response.bytes(
      bytes.takeBytes(),
      incoming.statusCode,
    );
    final value = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    if (response.statusCode == 409) {
      throw CollaborationConflict(
        value['error'] as String? ?? 'shared content',
      );
    }
    if (response.statusCode != 200) {
      throw StateError(
        response.statusCode == 403
            ? 'Access denied or invitation revoked.'
            : 'The server could not finish this action. Local files are safe.',
      );
    }
    return value;
  }

  Future<Map<String, dynamic>> createRoom(
    Uri server,
    String ownerKey,
    String name,
  ) async {
    final generation = workspace.workspaceGeneration;
    if (!await workspace.flushAll()) {
      throw StateError('Save the Vault before sharing.');
    }
    final workspaceId = workspace.repository.workspaceId;
    final backup = await workspace.repository.exportBundle();
    if (workspace.repository.workspaceId != workspaceId ||
        workspace.workspaceGeneration != generation) {
      throw StateError('Vault changed.');
    }
    return request(server, ownerKey, 'POST', '/v1/rooms', {
      'name': name,
      'backup': backup,
    });
  }

  Future<Map<String, dynamic>> inspectRoom(
    Uri server,
    String id,
    String token,
  ) => request(server, token, 'GET', '/v1/rooms/$id/state');
  Future<String> downloadRoom(Uri server, String id, String token) async =>
      jsonEncode(await request(server, token, 'GET', '/v1/rooms/$id/backup'));
  Future<void> connect(Uri server, String id, String token) async {
    final generation = workspace.workspaceGeneration;
    if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(id) ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token)) {
      throw const FormatException('The invitation is invalid.');
    }
    if (!await workspace.flushAll()) {
      throw StateError('Save the Vault before connecting.');
    }
    final state = await inspectRoom(server, id, token);
    if (_disposed || workspace.workspaceGeneration != generation) {
      throw StateError('Vault changed before the connection finished.');
    }
    if (state['protocol'] != 1) {
      throw StateError('This server protocol is unsupported.');
    }
    if (state['workspaceId'] != workspace.repository.workspaceId) {
      throw StateError(
        'Open or import this shared Vault before connecting. Matching names are not matching identities.',
      );
    }
    disconnect();
    endpoint = server;
    room = id;
    _token = token;
    _workspaceId = state['workspaceId'] as String;
    _workspaceGeneration = workspace.workspaceGeneration;
    role = state['role'] as String;
    _sequence = state['sequence'] as int;
    // A returning client must never treat its divergent saved draft as a known
    // common base. Reconcile explicitly instead of publishing over remote work.
    for (final entry in (state['documents'] as Map).entries) {
      final doc = Map<String, dynamic>.from(entry.value as Map);
      final local = workspace.find(entry.key as String);
      if (local == null ||
          !collaborationContentEqual(
            collaborationSnapshot(local),
            Map<String, dynamic>.from(doc['snapshot'] as Map),
          )) {
        conflicts[entry.key as String] =
            'Local and server content differ on connection. Keep your local copy or explicitly adopt the server version.';
      }
      _documents[entry.key as String] = doc;
    }
    peers = (state['peers'] as List)
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
    status = conflicts.isEmpty
        ? 'Connected · saved locally'
        : 'Connected · review differences';
    _timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => unawaited(pump()),
    );
    _notify();
  }

  void disconnect() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    room = null;
    endpoint = null;
    _token = null;
    _workspaceId = null;
    _workspaceGeneration = null;
    peers = [];
    _documents.clear();
    _inflight.clear();
    conflicts.clear();
    _cursor = null;
    status = 'Not connected';
    _notify();
  }

  void cursor(String id, double x, double y, {String space = 'note'}) {
    if (!shares(id) || !x.isFinite || !y.isFinite) return;
    _cursor = {
      'session': session,
      'objectId': id,
      'x': x,
      'y': y,
      'space': space,
    };
  }

  Future<void> pump() async {
    if (busy || !connected || _disposed) return;
    if (!_validWorkspace) {
      disconnect();
      return;
    }
    final generation = _generation,
        server = endpoint!,
        id = room!,
        token = _token!;
    busy = true;
    try {
      if (!viewer) {
        for (final entry in _documents.entries.toList()) {
          if (generation != _generation) return;
          if (conflicts.containsKey(entry.key)) continue;
          final object = workspace.find(entry.key);
          if (object == null || object.isDeleted || object.isReadOnly) continue;
          final local = collaborationSnapshot(object);
          final base = Map<String, dynamic>.from(
            entry.value['snapshot'] as Map,
          );
          if (!_inflight.containsKey(entry.key) &&
              collaborationContentEqual(local, base)) {
            continue;
          }
          // First preserve the local proposal in normal save/history. A failed
          // upload never means that a successful local save has been lost.
          await workspace.flush(entry.key);
          if (generation != _generation || !_validWorkspace) {
            return;
          }
          if (workspace.dirty.contains(entry.key) ||
              workspace.failures.containsKey(entry.key)) {
            continue;
          }
          final operation = _inflight.putIfAbsent(
            entry.key,
            () => {
              'id': entry.key,
              'version': entry.value['version'],
              'snapshot': local,
              'operation': const Uuid().v4(),
            },
          );
          try {
            final result = await request(
              server,
              token,
              'POST',
              '/v1/rooms/$id/edit',
              operation,
            );
            if (generation != _generation) return;
            await _adopt(
              entry.key,
              Map<String, dynamic>.from(operation['snapshot'] as Map),
              result,
            );
            _inflight.remove(entry.key);
          } on CollaborationConflict catch (e) {
            conflicts[entry.key] = e.toString();
            _inflight.remove(entry.key);
          }
        }
      }
      final state = await request(
        server,
        token,
        'GET',
        '/v1/rooms/$id/state?since=$_sequence',
      );
      if (generation != _generation) return;
      if (state['protocol'] != 1 || state['workspaceId'] != _workspaceId) {
        throw StateError('Server identity or protocol changed.');
      }
      for (final entry in (state['documents'] as Map).entries) {
        final prior = _documents[entry.key];
        if (prior == null || conflicts.containsKey(entry.key)) continue;
        final next = Map<String, dynamic>.from(entry.value as Map);
        if (next['version'] != prior['version']) {
          try {
            await _adopt(
              entry.key as String,
              Map<String, dynamic>.from(prior['snapshot'] as Map),
              next,
            );
          } on CollaborationConflict catch (e) {
            conflicts[entry.key as String] = e.toString();
          }
        }
      }
      peers = (state['peers'] as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .where((v) => v['session'] != session)
          .toList();
      _sequence = state['sequence'] as int;
      if (_cursor != null &&
          DateTime.now().difference(_lastCursor) >
              const Duration(milliseconds: 400)) {
        await request(server, token, 'POST', '/v1/rooms/$id/presence', _cursor);
        _lastCursor = DateTime.now();
      }
      if (generation != _generation) return;
      status = conflicts.isEmpty
          ? 'Connected · changes acknowledged'
          : 'Connected · review differences';
    } on Object {
      if (generation == _generation) {
        peers = [];
        status = 'Connection interrupted · local work is preserved';
      }
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> _adopt(
    String id,
    Map<String, dynamic> base,
    Map<String, dynamic> next,
  ) async {
    final local = workspace.find(id);
    if (local == null ||
        local.isDeleted ||
        local.isReadOnly ||
        !_validWorkspace ||
        workspace.loading) {
      throw const CollaborationConflict('local object identity');
    }
    final remote = Map<String, dynamic>.from(next['snapshot'] as Map);
    final merged = mergeCollaboration(
      base,
      collaborationSnapshot(local),
      remote,
    );
    final object = collaborationObject(merged);
    if (!collaborationContentEqual(collaborationSnapshot(local), merged)) {
      workspace.edit(
        id,
        title: object.title,
        body: object.body,
        properties: object.properties,
        data: object.data,
      );
      await workspace.flush(id);
      if (workspace.failures.containsKey(id) || workspace.dirty.contains(id)) {
        throw const CollaborationConflict('local saving');
      }
    }
    _documents[id] = next;
  }

  Future<void> adoptServer(String id) async {
    if (busy || !connected || !_validWorkspace) {
      return;
    }
    if (workspace.find(id) == null) return;
    await workspace.flush(id);
    if (workspace.failures.containsKey(id) || workspace.dirty.contains(id)) {
      return;
    }
    final local = workspace.find(id)!;
    final generation = _generation;
    busy = true;
    try {
      final state = await inspectRoom(endpoint!, room!, _token!);
      if (generation != _generation ||
          !_validWorkspace ||
          !identical(local, workspace.find(id))) {
        throw const CollaborationConflict('a newer local edit');
      }
      final next = Map<String, dynamic>.from(
        (state['documents'] as Map)[id] as Map,
      );
      final source = collaborationObject(
        Map<String, dynamic>.from(next['snapshot'] as Map),
      );
      // The normal repository save retains the complete Markdown/Canvas before-image.
      workspace.edit(
        id,
        title: source.title,
        body: source.body,
        properties: source.properties,
        data: source.data,
      );
      await workspace.flush(id);
      if (!workspace.dirty.contains(id) &&
          !workspace.failures.containsKey(id)) {
        _documents[id] = next;
        conflicts.remove(id);
        _inflight.remove(id);
      }
      _notify();
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<String> invite(String name, String role) async =>
      (await request(endpoint!, _token!, 'POST', '/v1/rooms/$room/invite', {
            'name': name,
            'role': role,
          }))['token']
          as String;
  Future<void> revoke(String token) async {
    await request(endpoint!, _token!, 'POST', '/v1/rooms/$room/revoke', {
      'token': token,
    });
  }

  @override
  void dispose() {
    _disposed = true;
    disconnect();
    httpClient.close();
    viewerChanges.dispose();
    super.dispose();
  }
}
