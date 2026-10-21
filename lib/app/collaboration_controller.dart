import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import '../application/device_secret_store.dart';
import '../infrastructure/storage/device_secret_store.dart';
import '../domain/collaboration.dart';
import 'workspace_controller.dart';

final collaborationProvider = Provider<CollaborationController>((ref) {
  final controller = CollaborationController(
    ref.read(workspaceProvider.notifier),
    http.Client(),
    secrets: (id) => SecureDeviceSecrets(
      'orbit.shared.connection.v1.${sha256.convert(utf8.encode(id))}',
    ),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

class SharedCanvasReview {
  SharedCanvasReview._(
    this.id,
    this.title,
    this.serverVersion,
    this.comparison,
    this._generation,
    this._session,
  );
  final String id, title;
  final int serverVersion;
  final CanvasConflictReview comparison;
  final int _generation;
  final String _session;
}

/// Session credentials remain in memory unless explicitly remembered in secure
/// device storage. Local repository save/history is used
/// for every accepted remote mutation; server acknowledgement is a separate state.
class CollaborationController extends ChangeNotifier {
  CollaborationController(
    this.workspace,
    this.httpClient, {
    DateTime Function()? now,
    this.automaticPolling = true,
    this.secrets,
  }) : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  final bool automaticPolling;
  final DeviceSecretStore Function(String workspaceId)? secrets;
  final WorkspaceController workspace;
  final http.Client httpClient;
  Uri? endpoint;
  String? room, _token, _workspaceId;
  String role = '', status = 'Not connected';
  List<Map<String, dynamic>> peers = [];
  final conflicts = <String, String>{};
  final _documents = <String, Map<String, dynamic>>{};
  final _inflight = <String, Map<String, dynamic>>{};
  final _canvasConflictBases = <String, Map<String, dynamic>>{};
  String _session = const Uuid().v4();
  String get session => _session;
  Timer? _timer;
  int _generation = 0;
  int _connectionRequest = 0, _failures = 0;
  DateTime? retryAt, lastAcknowledgedAt;
  bool accessBlocked = false;
  bool connecting = false, profileBusy = false;
  Map<String, dynamic>? _savedConnection;
  bool get hasSavedConnection =>
      workspace.hasWorkspace &&
      _savedConnection != null &&
      _savedConnection!['workspaceId'] == workspace.repository.workspaceId;
  String? get savedServer {
    if (!hasSavedConnection) return null;
    return _savedConnection!['server'] as String;
  }

  bool get canRememberConnection =>
      secrets != null && connected && _validWorkspace;
  int get pendingChanges => _documents.keys.where((id) {
    final local = workspace.find(id);
    return local != null &&
        !local.isDeleted &&
        (_inflight.containsKey(id) ||
            workspace.dirty.contains(id) ||
            !collaborationContentEqual(
              collaborationSnapshot(local),
              Map<String, dynamic>.from(_documents[id]!['snapshot'] as Map),
            ));
  }).length;
  bool _current(int generation) {
    if (_disposed || generation != _generation) return false;
    if (!_validWorkspace) {
      disconnect();
      return false;
    }
    return true;
  }

  int? _workspaceGeneration;
  int _sequence = 0;
  bool busy = false, _disposed = false;
  // Note editors only need rebuilding when editing permission changes. Pointer
  // heartbeats must not reconstruct their Markdown preview every half second.
  final viewerChanges = ValueNotifier<bool>(false);
  final presenceChanges = ValueNotifier<List<Map<String, dynamic>>>(const []);
  Map<String, dynamic>? _cursor;
  DateTime _lastCursor = DateTime.fromMillisecondsSinceEpoch(0);
  bool get connected => room != null;
  bool shares(String id) => _documents.containsKey(id);
  bool canReviewCanvas(String id) =>
      connected &&
      !viewer &&
      !accessBlocked &&
      _validWorkspace &&
      conflicts.containsKey(id) &&
      _canvasConflictBases.containsKey(id) &&
      workspace.find(id)?.typeId == 'orbit.canvas';
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
      final visiblePeers = [
        for (final peer in peers)
          Map<String, dynamic>.unmodifiable({...peer}..remove('seen')),
      ];
      if (!collaborationEqual(presenceChanges.value, visiblePeers)) {
        presenceChanges.value = List.unmodifiable(visiblePeers);
      }
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
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const CollaborationAccessDenied();
    }
    Map<String, dynamic> value;
    try {
      value = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } on Object {
      throw StateError(
        'The server returned an unreadable response. Local files are safe.',
      );
    }
    if (response.statusCode == 409) {
      throw CollaborationConflict(
        value['error'] as String? ?? 'shared content',
      );
    }
    if (response.statusCode != 200) {
      throw StateError(
        'The server could not finish this action. Local files are safe.',
      );
    }
    return value;
  }

  Future<Map<String, dynamic>> createRoom(
    Uri server,
    String ownerKey,
    String name,
  ) async {
    final attempt = ++_connectionRequest;
    connecting = true;
    _notify();
    try {
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
      final result = await request(server, ownerKey, 'POST', '/v1/rooms', {
        'name': name,
        'backup': backup,
      });
      if (_disposed ||
          attempt != _connectionRequest ||
          workspace.workspaceGeneration != generation) {
        throw StateError(
          'Connection cancelled or Vault changed. The local Vault was preserved.',
        );
      }
      return result;
    } finally {
      if (attempt == _connectionRequest) {
        connecting = false;
        _notify();
      }
    }
  }

  Future<Map<String, dynamic>> inspectRoom(
    Uri server,
    String id,
    String token,
  ) => request(server, token, 'GET', '/v1/rooms/$id/state');

  Future<Map<String, dynamic>> testServer(Uri server, String ownerKey) async {
    server = validateEndpoint('$server');
    final info = await request(server, ownerKey, 'GET', '/v1/server');
    if (info['service'] != 'orbit-collaboration' ||
        info['protocol'] != 1 ||
        info['ready'] != true) {
      throw StateError(
        'The server is incompatible or needs storage recovery before sharing.',
      );
    }
    return info;
  }

  Future<void> loadSavedConnection() async {
    if (profileBusy || secrets == null || !workspace.hasWorkspace) return;
    final id = workspace.repository.workspaceId,
        opening = workspace.workspaceGeneration;
    profileBusy = true;
    _notify();
    try {
      final raw = await secrets!(id).read();
      if (_disposed || workspace.workspaceGeneration != opening) return;
      if (raw == null) {
        _savedConnection = null;
        return;
      }
      if (raw.length > 16384) {
        throw const FormatException('Saved connection is too large.');
      }
      final value = jsonDecode(raw) as Map<String, dynamic>;
      if (value['format'] != 'orbit-shared-connection' ||
          value['version'] != 1 ||
          value['workspaceId'] != id ||
          value['server'] is! String ||
          value['room'] is! String ||
          value['token'] is! String ||
          !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(value['room'] as String) ||
          !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(value['token'] as String)) {
        throw const FormatException(
          'Saved connection is unsupported; forget it explicitly before replacing it.',
        );
      }
      validateEndpoint(value['server'] as String);
      _savedConnection = value;
    } finally {
      profileBusy = false;
      _notify();
    }
  }

  Future<void> rememberConnection() async {
    if (!canRememberConnection || profileBusy) {
      throw StateError('Connect this Vault before remembering its connection.');
    }
    final id = workspace.repository.workspaceId,
        opening = workspace.workspaceGeneration,
        connection = _generation;
    Map<String, dynamic> value = {
      'format': 'orbit-shared-connection',
      'version': 1,
      'workspaceId': id,
      'server': '$endpoint',
      'room': room,
      'token': _token,
    };
    profileBusy = true;
    _notify();
    try {
      final existing = await secrets!(id).read();
      if (existing != null) {
        if (existing.length > 16384) {
          throw StateError(
            'Saved connection requires recovery; forget it before replacing it.',
          );
        }
        final prior = jsonDecode(existing);
        if (prior is! Map ||
            prior['format'] != 'orbit-shared-connection' ||
            prior['version'] != 1 ||
            prior['workspaceId'] != id) {
          throw StateError(
            'The saved connection requires recovery; forget it explicitly before replacing it.',
          );
        }
        value = {...Map<String, dynamic>.from(prior), ...value};
      }
      if (_disposed ||
          workspace.workspaceGeneration != opening ||
          connection != _generation ||
          !connected) {
        throw StateError('Connection changed.');
      }
      final encoded = jsonEncode(value);
      if (encoded.length > 16384) {
        throw StateError(
          'Saved connection exceeds the safe limit; forget it before replacing it.',
        );
      }
      await secrets!(id).write(encoded);
      if (!_disposed &&
          workspace.workspaceGeneration == opening &&
          connection == _generation) {
        _savedConnection = value;
      }
    } finally {
      profileBusy = false;
      _notify();
    }
  }

  Future<void> reconnectSaved() async {
    await loadSavedConnection();
    if (!hasSavedConnection) {
      throw StateError('No saved connection for this Vault.');
    }
    final saved = _savedConnection!;
    await connect(
      validateEndpoint(saved['server'] as String),
      saved['room'] as String,
      saved['token'] as String,
    );
  }

  Future<void> forgetSavedConnection() async {
    if (secrets == null || profileBusy || !workspace.hasWorkspace) return;
    final id = workspace.repository.workspaceId,
        opening = workspace.workspaceGeneration;
    profileBusy = true;
    _notify();
    try {
      await secrets!(id).delete();
      if (!_disposed && workspace.workspaceGeneration == opening) {
        _savedConnection = null;
      }
    } finally {
      profileBusy = false;
      _notify();
    }
  }

  Future<String> downloadRoom(Uri server, String id, String token) async =>
      jsonEncode(await request(server, token, 'GET', '/v1/rooms/$id/backup'));
  Future<void> connect(Uri server, String id, String token) async {
    server = validateEndpoint('$server');
    final requestId = ++_connectionRequest;
    connecting = true;
    _notify();
    try {
      final generation = workspace.workspaceGeneration;
      if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(id) ||
          !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token)) {
        throw const FormatException('The invitation is invalid.');
      }
      if (!await workspace.flushAll()) {
        throw StateError('Save the Vault before connecting.');
      }
      if (_disposed ||
          requestId != _connectionRequest ||
          workspace.workspaceGeneration != generation) {
        throw StateError('Connection cancelled or Vault changed.');
      }
      final state = await inspectRoom(server, id, token);
      if (_disposed ||
          requestId != _connectionRequest ||
          workspace.workspaceGeneration != generation) {
        throw StateError('Vault changed before the connection finished.');
      }
      if (state['protocol'] != 1) {
        throw StateError('This server protocol is unsupported.');
      }
      if (!{'owner', 'editor', 'viewer'}.contains(state['role'])) {
        throw StateError('The server returned unsupported access permissions.');
      }
      if (state['workspaceId'] != workspace.repository.workspaceId) {
        throw StateError(
          'Open or import this shared Vault before connecting. Matching names are not matching identities.',
        );
      }
      disconnect();
      _session = const Uuid().v4();
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
          .where((peer) => peer['session'] != session)
          .toList();
      status = conflicts.isEmpty
          ? 'Connected · saved locally'
          : 'Connected · review differences';
      if (automaticPolling) {
        _timer = Timer.periodic(
          const Duration(milliseconds: 500),
          (_) => unawaited(pump()),
        );
      }
      _notify();
    } finally {
      if (requestId == _connectionRequest) {
        connecting = false;
        _notify();
      }
    }
  }

  void disconnect() {
    connecting = false;
    _connectionRequest++;
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
    _canvasConflictBases.clear();
    conflicts.clear();
    _cursor = null;
    _lastCursor = DateTime.fromMillisecondsSinceEpoch(0);
    _failures = 0;
    retryAt = lastAcknowledgedAt = null;
    accessBlocked = false;
    status = 'Not connected';
    _notify();
  }

  void cursor(String id, double x, double y, {String space = 'note'}) {
    if (!shares(id) ||
        !x.isFinite ||
        !y.isFinite ||
        x.abs() > 100000000 ||
        y.abs() > 100000000) {
      return;
    }
    _cursor = {
      'session': session,
      'objectId': id,
      'x': x,
      'y': y,
      'space': space,
      if (space == 'canvas')
        'selection': _cursor?['objectId'] == id
            ? collaborationSelectionIds(_cursor?['selection'])
            : <String>[],
    };
  }

  void selectCanvas(String id, List<String> ids) {
    if (_cursor?['objectId'] != id || _cursor?['space'] != 'canvas') return;
    final selection = collaborationSelectionIds(ids);
    if (listEquals(selection, _cursor?['selection'] as List?)) return;
    _cursor = {..._cursor!, 'selection': selection};
  }

  void clearCursor(String id) {
    if (_cursor?['objectId'] != id) return;
    _cursor = {..._cursor!, 'active': false, 'selection': <String>[]};
  }

  Future<void> pump() async {
    if (busy || !connected || _disposed) return;
    if (!_validWorkspace) {
      disconnect();
      return;
    }
    if (accessBlocked || (retryAt != null && _now().isBefore(retryAt!))) return;
    final generation = _generation,
        server = endpoint!,
        id = room!,
        token = _token!;
    busy = true;
    try {
      if (!viewer) {
        for (final entry in _documents.entries.toList()) {
          if (!_current(generation)) return;
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
          if (!_current(generation)) {
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
            if (!_current(generation)) return;
            await _adopt(
              entry.key,
              Map<String, dynamic>.from(operation['snapshot'] as Map),
              result,
            );
            if (!_current(generation)) return;
            _inflight.remove(entry.key);
          } on CollaborationConflict catch (e) {
            if (!_current(generation)) return;
            conflicts[entry.key] = e.toString();
            if (object.typeId == 'orbit.canvas') {
              _canvasConflictBases[entry.key] = base;
            }
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
      if (!_current(generation)) return;
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
            if (!_current(generation)) return;
          } on CollaborationConflict catch (e) {
            if (!_current(generation)) return;
            conflicts[entry.key as String] = e.toString();
            if (workspace.find(entry.key as String)?.typeId == 'orbit.canvas') {
              _canvasConflictBases[entry.key as String] =
                  Map<String, dynamic>.from(prior['snapshot'] as Map);
            }
          }
        }
      }
      peers = (state['peers'] as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .where((v) => v['session'] != session)
          .toList();
      _sequence = state['sequence'] as int;
      final cursor = _cursor;
      if (cursor != null &&
          (cursor['active'] == false ||
              _now().difference(_lastCursor) >=
                  const Duration(milliseconds: 400))) {
        await request(server, token, 'POST', '/v1/rooms/$id/presence', cursor);
        if (!_current(generation)) return;
        _lastCursor = _now();
        if (cursor['active'] == false && identical(_cursor, cursor)) {
          _cursor = null;
        }
      }
      if (!_current(generation)) return;
      _failures = 0;
      retryAt = null;
      if (pendingChanges == 0 && conflicts.isEmpty) lastAcknowledgedAt = _now();
      status = conflicts.isNotEmpty
          ? 'Connected · review differences'
          : pendingChanges > 0
          ? 'Connected · $pendingChanges shared document(s) pending'
          : 'Connected · changes acknowledged';
    } on CollaborationAccessDenied {
      if (_current(generation)) {
        peers = [];
        accessBlocked = true;
        retryAt = null;
        status = 'Access denied or revoked · local work is preserved';
      }
    } on Object {
      if (_current(generation)) {
        peers = [];
        _failures = (_failures + 1).clamp(1, 6);
        final seconds = (1 << (_failures - 1)).clamp(1, 30);
        retryAt = _now().add(Duration(seconds: seconds));
        status =
            'Connection interrupted · retrying in ${seconds}s · local work is preserved';
      }
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> retryNow() async {
    retryAt = null;
    accessBlocked = false;
    await pump();
  }

  Future<void> _adopt(
    String id,
    Map<String, dynamic> base,
    Map<String, dynamic> next,
  ) async {
    final generation = _generation;
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
    if (_current(generation)) _documents[id] = next;
  }

  Future<void> adoptServer(String id) async {
    if (busy || !connected || !_validWorkspace) {
      return;
    }
    if (workspace.find(id) == null) return;
    final generation = _generation;
    final original = collaborationSnapshot(workspace.find(id)!);
    await workspace.flush(id);
    final saved = workspace.find(id);
    if (!_current(generation) ||
        saved == null ||
        saved.isDeleted ||
        !collaborationContentEqual(original, collaborationSnapshot(saved))) {
      return;
    }
    if (workspace.failures.containsKey(id) || workspace.dirty.contains(id)) {
      return;
    }
    final local = workspace.find(id)!;
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
      if (_current(generation) &&
          !workspace.dirty.contains(id) &&
          !workspace.failures.containsKey(id)) {
        _documents[id] = next;
        conflicts.remove(id);
        _inflight.remove(id);
        _canvasConflictBases.remove(id);
      }
      _notify();
    } finally {
      busy = false;
      _notify();
    }
  }

  void _checkCanvasReview(
    int generation,
    String id,
    Map<String, dynamic> original,
  ) {
    final local = workspace.find(id);
    if (!_current(generation) ||
        !canReviewCanvas(id) ||
        local == null ||
        local.isDeleted ||
        local.isReadOnly ||
        workspace.loading ||
        !collaborationContentEqual(original, collaborationSnapshot(local))) {
      throw StateError(
        'The board or connection changed. Reload the comparison.',
      );
    }
    if (workspace.dirty.contains(id) || workspace.failures.containsKey(id)) {
      throw StateError(
        'Save this board locally before reviewing shared edits.',
      );
    }
  }

  Future<SharedCanvasReview> reviewCanvas(String id) async {
    if (busy || !canReviewCanvas(id)) {
      throw StateError(
        'A known common base and editable shared Canvas are required.',
      );
    }
    final generation = _generation;
    final original = collaborationSnapshot(workspace.find(id)!);
    busy = true;
    _notify();
    try {
      await workspace.flush(id);
      _checkCanvasReview(generation, id, original);
      final state = await inspectRoom(endpoint!, room!, _token!);
      _checkCanvasReview(generation, id, original);
      if (state['protocol'] != 1 || state['workspaceId'] != _workspaceId) {
        throw StateError('Server identity or protocol changed.');
      }
      final next = (state['documents'] as Map)[id];
      if (next is! Map || next['version'] is! int) {
        throw StateError(
          'The shared board is unavailable. Keep your local copy.',
        );
      }
      final comparison = CanvasConflictReview.create(
        _canvasConflictBases[id]!,
        original,
        Map<String, dynamic>.from(next['snapshot'] as Map),
      );
      return SharedCanvasReview._(
        id,
        workspace.find(id)!.title,
        next['version'] as int,
        comparison,
        generation,
        session,
      );
    } finally {
      busy = false;
      _notify();
    }
  }

  /// Save through the ordinary history boundary, then publish through the normal
  /// idempotent known-base edit protocol. A later overlapping remote edit still
  /// conflicts; this is never a force overwrite or a canonical-object deletion.
  Future<void> resolveCanvas(
    SharedCanvasReview review,
    Map<String, CanvasConflictSide> choices, {
    CanvasConflictSide? order,
  }) async {
    if (busy || review._session != session) {
      throw StateError('Connection changed or busy. Reload the comparison.');
    }
    final generation = review._generation, id = review.id;
    _checkCanvasReview(generation, id, review.comparison.local);
    final resolved = collaborationObject(
      review.comparison.resolve(choices, order: order),
    );
    busy = true;
    _notify();
    try {
      final state = await inspectRoom(endpoint!, room!, _token!);
      _checkCanvasReview(generation, id, review.comparison.local);
      final next = (state['documents'] as Map)[id];
      if (state['protocol'] != 1 ||
          state['workspaceId'] != _workspaceId ||
          next is! Map ||
          next['version'] != review.serverVersion ||
          !collaborationContentEqual(
            review.comparison.shared,
            Map<String, dynamic>.from(next['snapshot'] as Map),
          )) {
        throw StateError(
          'The shared board changed. Reload before choosing again.',
        );
      }
      workspace.edit(
        id,
        title: resolved.title,
        body: resolved.body,
        properties: resolved.properties,
        data: resolved.data,
      );
      await workspace.flush(id);
      if (!_current(generation)) {
        throw StateError(
          'The connection changed. The resolution remains in the original Vault.',
        );
      }
      if (workspace.dirty.contains(id) || workspace.failures.containsKey(id)) {
        throw StateError(
          'Resolution is still a local draft. Fix saving and reload the comparison.',
        );
      }
      _documents[id] = Map<String, dynamic>.from(next);
      _inflight.remove(id);
      _canvasConflictBases.remove(id);
      conflicts.remove(id);
      retryAt = null;
      status = 'Resolution saved locally · synchronization pending';
    } finally {
      busy = false;
      _notify();
    }
    if (_current(generation)) {
      await pump();
      if (_current(generation) && conflicts.containsKey(id)) {
        throw StateError(
          'Resolution saved locally, but a newer shared edit needs review. Reload the comparison.',
        );
      }
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
    presenceChanges.dispose();
    super.dispose();
  }
}

class CollaborationAccessDenied implements Exception {
  const CollaborationAccessDenied();
  @override
  String toString() =>
      'Access denied or invitation revoked. Local files are safe.';
}
