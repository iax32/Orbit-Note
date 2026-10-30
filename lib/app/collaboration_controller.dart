import 'dart:async';
import 'dart:convert';
import '../domain/text_digest_cache.dart';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show listEquals, compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import '../application/device_secret_store.dart';
import '../platform/collaboration_http.dart';
import '../platform/collaboration_payload.dart';
import '../infrastructure/storage/device_secret_store.dart';
import '../domain/collaboration.dart';
import '../domain/object_tombstone.dart';
import '../domain/universal_object.dart';
import '../application/workspace_repository.dart';
import '../application/sync/sync_provider.dart';
import 'workspace_controller.dart';
import 'canvas_performance.dart';

part 'shared_vault_replication.dart';

String _decodeSharedText(Uint8List bytes) => utf8.decode(bytes);
Map<String, dynamic> _decodeSharedJson(Uint8List bytes) =>
    Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);

final collaborationStartupProvider = Provider<void>((ref) {
  var alive = true, opening = -1;
  Future<void> inspect() async {
    final workspace = ref.read(workspaceProvider.notifier);
    if (!alive ||
        !workspace.hasWorkspace ||
        workspace.loading ||
        opening == workspace.workspaceGeneration) {
      return;
    }
    opening = workspace.workspaceGeneration;
    final c = ref.read(collaborationProvider);
    await c.reconnectAutomatically();
  }

  ref.listen(workspaceProvider, (_, _) => unawaited(inspect()));
  scheduleMicrotask(() => unawaited(inspect()));
  ref.onDispose(() => alive = false);
});

final collaborationProvider = Provider<CollaborationController>((ref) {
  final controller = CollaborationController(
    ref.read(workspaceProvider.notifier),
    createCollaborationHttpClient(),
    secrets: (id) => SecureDeviceSecrets(
      'orbit.shared.connection.v1.${sha256.convert(utf8.encode(id))}',
    ),
  );
  final lifecycle = AppLifecycleListener(
    onResume: () => unawaited(controller.resumeForeground()),
  );
  ref.onDispose(lifecycle.dispose);
  ref.onDispose(controller.dispose);
  ref.listen(workspaceProvider, (_, _) => controller.localChanged());
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
  final _compressedServers = <Uri>{};
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
  bool get autoReconnectSaved =>
      hasSavedConnection && _savedConnection!['autoReconnect'] == true;
  int? _manualDisconnectOpening;
  String? get savedServer {
    if (!hasSavedConnection) return null;
    return _savedConnection!['server'] as String;
  }

  bool get canRememberConnection =>
      secrets != null && connected && _validWorkspace;
  int get pendingChanges =>
      {
        ..._documents.keys,
        if (_liveReplication)
          ...[
            ...workspace.repository.objects,
            ...workspace.repository.preferenceRecords,
          ].map((o) => o.id),
      }.where((id) {
        final local = workspace.find(id);
        final doc = _documents[id];
        if (_liveReplication) {
          if (doc == null) return local != null;
          if (doc['removed'] == true) return local != null;
          if (local == null) return true;
        }
        return local != null &&
            (!local.isDeleted || _liveReplication) &&
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
      disconnect(userInitiated: false);
      return false;
    }
    return true;
  }

  int? _workspaceGeneration;
  bool _liveReplication = false;
  bool get liveReplication => _liveReplication;
  int _watchGeneration = 0, _awarenessSequence = 0;
  Timer? _localDebounce;
  Timer? _presenceTimer;
  bool _sendingPresence = false;
  final _newPlans = <String, Map<String, dynamic>>{};
  Map<String, Map<String, dynamic>> _localAttachments = {};
  int _attachmentRevision = -1;
  String _attachmentOwners = '';
  SyncStateStore? _sessionJournal;
  String? _sessionBinding;
  String? _checkpointDigest;
  int _sequence = 0;
  String? _serverEpoch;
  bool _refreshPending = false;
  bool busy = false, _disposed = false;
  // Note editors only need rebuilding when editing permission changes. Pointer
  // heartbeats must not reconstruct their Markdown preview every half second.
  final viewerChanges = ValueNotifier<bool>(false);
  final presenceChanges = ValueNotifier<List<Map<String, dynamic>>>(const []);
  Map<String, dynamic>? _cursor;
  Map<String, dynamic>? _sentCursor;
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
  Uri? invitationEndpoint;
  Uri? get invitationServer => invitationEndpoint ?? endpoint;
  String get connectionInvitation => jsonEncode({
    'version': 1,
    'server': '$invitationServer',
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
      _notifyPresence();
      notifyListeners();
    }
  }

  void _notifyPresence() {
    if (!_disposed) {
      final visiblePeers = [
        for (final peer in peers)
          Map<String, dynamic>.unmodifiable({...peer}..remove('seen')),
      ];
      if (!collaborationEqual(presenceChanges.value, visiblePeers)) {
        presenceChanges.value = List.unmodifiable(visiblePeers);
      }
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
  ]) async =>
      _readResponse(await _requestResponse(server, token, method, path, body));

  Future<http.Response> _requestResponse(
    Uri server,
    String token,
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final request = http.Request(method, Uri.parse('$server$path'))
      ..followRedirects = false;
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['X-Orbit-Client'] = '2';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      // Saved boards/initial Vaults may be many megabytes. Presence contains
      // only bounded cursor/selection/preview data: keep it cheap rather than
      // spawning a worker for every pen-awareness packet.
      final presence = path.endsWith('/presence');
      final compressed = !presence && _compressedServers.contains(server);
      if (compressed) request.headers['Content-Encoding'] = 'gzip';
      request.bodyBytes = presence
          ? encodeCollaborationPayload((body, false))
          : await compute(encodeCollaborationPayload, (body, compressed));
    }
    final incoming = await httpClient
        .send(request)
        .timeout(const Duration(seconds: 20));
    if (supportsCollaborationCompression &&
        incoming.headers['x-orbit-accept-encoding'] == 'gzip') {
      if (_compressedServers.length >= 16) _compressedServers.clear();
      _compressedServers.add(server);
    }
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
    return response;
  }

  Future<Map<String, dynamic>> _readResponse(http.Response response) async {
    Map<String, dynamic> value;
    try {
      value = response.bodyBytes.length > 64 * 1024
          ? await compute(_decodeSharedJson, response.bodyBytes)
          : _decodeSharedJson(response.bodyBytes);
    } on Object {
      throw StateError(
        'The server returned an unreadable response. Local files are safe.',
      );
    }
    if (response.statusCode == 409) {
      if (value['code'] == 'host-restarted') {
        throw const CollaborationHostChanged();
      }
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
        'replicationVersion': 2,
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
    Map<String, dynamic> info;
    try {
      info = await request(server, ownerKey, 'GET', '/v1/server');
    } on CollaborationAccessDenied {
      throw StateError(
        'The host rejected the owner key. Use owner-key.secret from this host’s private server folder, not a room invitation.',
      );
    } on TimeoutException {
      throw StateError(
        'The host did not respond in time. Keep the server running and check its HTTPS proxy, address and firewall. Localhost reaches only this device.',
      );
    } on http.ClientException {
      throw StateError(
        'The host could not be reached. Check the server, DNS and HTTPS certificate. Another device needs the host’s HTTPS address, not localhost.',
      );
    }
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

  Future<void> rememberConnection({bool? autoReconnect}) async {
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
      'autoReconnect': ?autoReconnect,
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

  Future<String> downloadRoom(Uri server, String id, String token) async {
    final response = await _requestResponse(
      server,
      token,
      'GET',
      '/v1/rooms/$id/backup',
    );
    if (response.statusCode != 200) await _readResponse(response);
    // Preserve the original envelope. Decoding and re-encoding its whole file
    // map before validation doubled initial-join work and peak allocation.
    return response.bodyBytes.length > 64 * 1024
        ? compute(_decodeSharedText, response.bodyBytes)
        : _decodeSharedText(response.bodyBytes);
  }

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
      disconnect(userInitiated: false);
      final sessionGeneration = _generation;
      try {
        _session = const Uuid().v4();
        endpoint = server;
        room = id;
        _token = token;
        _workspaceId = state['workspaceId'] as String;
        _workspaceGeneration = workspace.workspaceGeneration;
        role = state['role'] as String;
        _liveReplication = (state['capabilities'] as List? ?? []).contains(
          'live-objects',
        );
        _sequence = state['sequence'] as int;
        if (_liveReplication) _sequence = 0;
        _serverEpoch = state['epoch'] as String?;
        final recovered = _liveReplication
            ? await _restoreSharedJournal()
            : null;
        // A returning client must never treat its divergent saved draft as a known
        // common base. Reconcile explicitly instead of publishing over remote work.
        for (final entry in (state['documents'] as Map).entries) {
          final doc = Map<String, dynamic>.from(entry.value as Map);
          final local = workspace.find(entry.key as String);
          final known = (recovered?['documents'] as Map?)?[entry.key];
          if (known is Map &&
              known['version'] is int &&
              (known['version'] as int) <= (doc['version'] as int)) {
            _documents[entry.key as String] = Map<String, dynamic>.from(known);
            continue;
          }
          if (_liveReplication &&
              (local == null || doc['removed'] == true || local.isDeleted)) {
            if (doc['removed'] == true && local != null) {
              conflicts[entry.key as String] =
                  'Review the shared permanent deletion before removing this local copy.';
            }
            if (doc['removed'] == true || local != null) {
              _documents[entry.key as String] = doc;
            }
            continue;
          }
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
        if (_liveReplication) await _checkpointShared();
        if (automaticPolling) {
          _timer = Timer.periodic(
            _liveReplication
                ? const Duration(seconds: 5)
                : const Duration(milliseconds: 500),
            (_) => unawaited(pump()),
          );
        }
        if (automaticPolling && _liveReplication) {
          unawaited(_watchChanges(++_watchGeneration));
        }
        _notify();
      } catch (_) {
        if (_generation == sessionGeneration) disconnect(userInitiated: false);
        rethrow;
      }
    } finally {
      if (requestId == _connectionRequest) {
        connecting = false;
        _notify();
      }
    }
  }

  void disconnect({bool userInitiated = true}) {
    _textDigest.clear();
    if (userInitiated) _manualDisconnectOpening = workspace.workspaceGeneration;
    _watchGeneration++;
    _localDebounce?.cancel();
    _localAttachments = {};
    _attachmentRevision = -1;
    _attachmentOwners = '';
    _newPlans.clear();
    _sessionJournal = null;
    _sessionBinding = null;
    _checkpointDigest = null;
    _liveReplication = false;
    connecting = false;
    _connectionRequest++;
    _generation++;
    _timer?.cancel();
    _timer = null;
    _presenceTimer?.cancel();
    _presenceTimer = null;
    room = null;
    endpoint = null;
    invitationEndpoint = null;
    _token = null;
    _workspaceId = null;
    _workspaceGeneration = null;
    peers = [];
    _documents.clear();
    _inflight.clear();
    _canvasConflictBases.clear();
    conflicts.clear();
    _cursor = null;
    _sentCursor = null;
    _lastCursor = DateTime.fromMillisecondsSinceEpoch(0);
    _failures = 0;
    _serverEpoch = null;
    _refreshPending = false;
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
      if (space == 'canvas' && _cursor?['objectId'] == id)
        'ink': _cursor?['ink'],
      if (space == 'canvas')
        'selection': _cursor?['objectId'] == id
            ? collaborationSelectionIds(_cursor?['selection'])
            : <String>[],
    };
    _schedulePresence();
  }

  void selectCanvas(String id, List<String> ids) {
    if (_cursor?['objectId'] != id || _cursor?['space'] != 'canvas') return;
    final selection = collaborationSelectionIds(ids);
    if (listEquals(selection, _cursor?['selection'] as List?)) return;
    _cursor = {..._cursor!, 'selection': selection};
    _schedulePresence();
  }

  void previewCanvasInk(String id, Map<String, dynamic>? stroke) {
    if (!shares(id) || viewer || !connected) return;
    final ink = collaborationInkPreview(stroke);
    final last = ink == null ? null : (ink['points'] as List).last as Map;
    if (_cursor?['objectId'] != id || _cursor?['space'] != 'canvas') {
      if (last == null) return;
      cursor(
        id,
        (last['x'] as num).toDouble(),
        (last['y'] as num).toDouble(),
        space: 'canvas',
      );
    }
    _cursor = {..._cursor!, 'ink': ink};
    _schedulePresence();
  }

  void clearCursor(String id) {
    if (_cursor?['objectId'] != id) return;
    _cursor = {
      ..._cursor!,
      'active': false,
      'selection': <String>[],
      'ink': null,
    };
    _schedulePresence();
  }

  final _textDigest = TextDigestCache();
  void textSelection(String id, String source, TextSelection selection) {
    if (!connected ||
        !_documents.containsKey(id) ||
        !selection.isValid ||
        selection.end > source.length) {
      return;
    }
    _cursor = {
      'session': session,
      'objectId': id,
      'space': 'note',
      'x': 0,
      'y': 0,
      'textBase': selection.baseOffset,
      'textExtent': selection.extentOffset,
      'textHash': _textDigest.hash(source),
    };
    _schedulePresence();
  }

  void _schedulePresence() {
    if (!automaticPolling ||
        !connected ||
        accessBlocked ||
        !_validWorkspace ||
        _presenceTimer?.isActive == true) {
      return;
    }
    _presenceTimer = Timer(const Duration(milliseconds: 80), () async {
      try {
        await _publishPresence();
      } catch (_) {
        // Awareness is disposable; the durable pump handles access/retry state.
      }
    });
  }

  Future<void> _publishPresence() async {
    if (_sendingPresence || !connected || accessBlocked || !_validWorkspace) {
      return;
    }
    final cursor = _cursor;
    if (cursor == null ||
        (collaborationEqual(cursor, _sentCursor) &&
            _now().difference(_lastCursor) <
                const Duration(milliseconds: 400))) {
      return;
    }
    final generation = _generation;
    _sendingPresence = true;
    try {
      await request(
        endpoint!,
        _token!,
        'POST',
        '/v1/rooms/$room/presence',
        cursor,
      );
      if (!_current(generation)) return;
      _lastCursor = _now();
      _sentCursor = cursor;
      if (cursor['active'] == false && identical(_cursor, cursor)) {
        _cursor = null;
      }
    } finally {
      _sendingPresence = false;
      if (_current(generation) && !identical(_cursor, cursor)) {
        _schedulePresence();
      }
    }
  }

  Future<void>? _runningPump;
  Future<void> pump() {
    final running = _runningPump;
    if (running != null) {
      _refreshPending = true;
      return running;
    }
    Future<void> drain() async {
      do {
        _refreshPending = false;
        await _pump();
      } while (_refreshPending &&
          !busy &&
          connected &&
          !_disposed &&
          !accessBlocked &&
          retryAt == null);
    }

    return _runningPump = drain().whenComplete(() => _runningPump = null);
  }

  Future<void> _pump() async {
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
    final perf = CanvasPerformance.instance;
    final started = perf.begin();
    _refreshPending = false;
    try {
      final state = await request(
        server,
        token,
        'GET',
        '/v1/rooms/$id/state?${Uri(queryParameters: {'since': '$_sequence', 'epoch': _serverEpoch ?? 'unversioned'}).query}',
      );
      if (!_current(generation)) return;
      if (state['protocol'] != 1 || state['workspaceId'] != _workspaceId) {
        throw const _SharedSessionMismatch();
      }
      if (!{'owner', 'editor', 'viewer'}.contains(state['role'])) {
        throw StateError('The server returned unsupported access permissions.');
      }
      role = state['role'] as String;
      final epoch = state['epoch'] as String?;
      final restarted = epoch != _serverEpoch;
      final documents = state['documents'] as Map;
      if (_liveReplication) await _receiveAttachments(state, generation);
      if (!_current(generation)) return;
      if (restarted) {
        _canvasConflictBases.clear();
        _inflight.clear();
        _newPlans.clear();
        for (final id in _documents.keys) {
          if (documents.containsKey(id)) continue;
          conflicts[id] =
              'This document is absent after the host restarted or restored its data. Your local copy is preserved. Ask the host to recover its shared snapshot.';
          _inflight.remove(id);
          _canvasConflictBases.remove(id);
        }
      }
      for (final entry in documents.entries) {
        final prior = _documents[entry.key];
        if (conflicts.containsKey(entry.key)) continue;
        final next = Map<String, dynamic>.from(entry.value as Map);
        if (_liveReplication &&
            (prior == null ||
                next['removed'] == true ||
                workspace.find(entry.key as String) == null)) {
          if (restarted &&
              prior != null &&
              next['removed'] == true &&
              prior['removed'] != true) {
            conflicts[entry.key as String] =
                'The host restarted and now reports this source removed. Review before deleting the local copy.';
            continue;
          }
          try {
            await _receiveShared(entry.key as String, prior, next, generation);
          } on CollaborationConflict catch (e) {
            conflicts[entry.key as String] = e.toString();
          }
          if (!_current(generation)) return;
          continue;
        }
        if (prior == null) continue;
        final priorSnapshot = Map<String, dynamic>.from(
          prior['snapshot'] as Map,
        );
        final nextSnapshot = Map<String, dynamic>.from(next['snapshot'] as Map);
        if (restarted) {
          // A restart may be a restore of an older journal. Do not assume a
          // known ancestor from numeric versions, or replay uncertain edits.
          _inflight.remove(entry.key);
          if (!collaborationContentEqual(priorSnapshot, nextSnapshot)) {
            conflicts[entry.key as String] =
                'The host restarted or restored its data, and the shared version changed. Your local version is preserved; review before adopting the server version.';
            _canvasConflictBases.remove(entry.key);
          } else {
            _documents[entry.key as String] = next;
          }
          continue;
        }
        // Replay an uncertain acknowledgement before merging its own proposal.
        if (_inflight.containsKey(entry.key)) continue;
        if ((next['version'] as int) < (prior['version'] as int) ||
            (next['version'] == prior['version'] &&
                !collaborationContentEqual(priorSnapshot, nextSnapshot))) {
          conflicts[entry.key as String] =
              'The server rolled back or reused a document version with different content. Your local version is preserved; review the server before continuing.';
          _canvasConflictBases.remove(entry.key);
          continue;
        }
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
      _serverEpoch = epoch;
      peers = (state['peers'] as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .where((v) => v['session'] != session)
          .toList();
      _sequence = state['sequence'] as int;
      if (_liveReplication && !viewer) {
        await _publishShared(generation, state);
        if (!_current(generation)) return;
      }
      if (!viewer) {
        for (final entry in _documents.entries.toList()) {
          if (!_current(generation)) return;
          if (conflicts.containsKey(entry.key)) continue;
          final object = workspace.find(entry.key);
          if (object == null ||
              (object.isDeleted && !_liveReplication) ||
              object.isReadOnly ||
              entry.value['removed'] == true) {
            continue;
          }
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
              'epoch': ?_serverEpoch,
              'snapshot': local,
              'operation': const Uuid().v4(),
              if (_liveReplication)
                'path': workspace.repository.objectPath(entry.key),
            },
          );
          if (_liveReplication) await _checkpointShared();
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
            if (e is CollaborationHostChanged) {
              _canvasConflictBases.remove(entry.key);
            } else if (object.typeId == 'orbit.canvas') {
              _canvasConflictBases[entry.key] = base;
            }
            _inflight.remove(entry.key);
          }
        }
      }
      await _publishPresence();
      if (!_current(generation)) return;
      _failures = 0;
      if (_liveReplication) await _checkpointShared();
      retryAt = null;
      if (pendingChanges == 0 && conflicts.isEmpty) lastAcknowledgedAt = _now();
      status = conflicts.isNotEmpty
          ? 'Connected · review differences'
          : pendingChanges > 0
          ? 'Connected · $pendingChanges shared document(s) pending'
          : 'Connected · changes acknowledged';
    } on _SharedSessionMismatch {
      if (_current(generation)) {
        peers = [];
        accessBlocked = true;
        retryAt = null;
        status =
            'Shared server identity or protocol changed · reconnect after checking the host · local work is preserved';
      }
    } on CollaborationAccessDenied {
      if (_current(generation)) {
        peers = [];
        accessBlocked = true;
        retryAt = null;
        status = 'Access denied or revoked · local work is preserved';
      }
    } on _SharedRecoveryBlocked catch (e) {
      if (_current(generation)) {
        peers = [];
        accessBlocked = true;
        retryAt = null;
        status = e.message;
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
      perf.duration(CanvasPerfEvent.sharedSync, 0, started, {
        'phase': 0,
        'conflicts': conflicts.length,
        'documents': _documents.length,
        'blocked': accessBlocked ? 1 : 0,
      });
      _notify();
    }
  }

  Future<void> resumeForeground() async {
    if (!connected && !_disposed) {
      await reconnectAutomatically();
      return;
    }
    if (!connected || _disposed || accessBlocked) return;
    retryAt = null;
    if (busy) {
      _refreshPending = true;
      return;
    }
    await pump();
  }

  Future<void> retryNow() async {
    if (_disposed) return;
    accessBlocked = false;
    _attachmentRevision = -1;
    await resumeForeground();
  }

  Future<void> _adopt(
    String id,
    Map<String, dynamic> base,
    Map<String, dynamic> next,
  ) async {
    final generation = _generation;
    final local = workspace.find(id);
    if (local == null ||
        (local.isDeleted && !_liveReplication) ||
        local.isReadOnly ||
        !_validWorkspace ||
        workspace.loading) {
      throw const CollaborationConflict('local object identity');
    }
    final remote = Map<String, dynamic>.from(next['snapshot'] as Map);
    final merged = (_liveReplication
        ? mergeSharedDocument
        : mergeCollaboration)(base, collaborationSnapshot(local), remote);
    final object = collaborationObject(merged, allowDeleted: _liveReplication);
    if (_liveReplication &&
        (local.isDeleted ||
            object.isDeleted ||
            object.typeId == 'orbit.preferences')) {
      await _saveSharedObject(
        object,
        local,
        next['path'] as String?,
        generation,
      );
      if (_current(generation)) _documents[id] = next;
      return;
    }
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
        (saved.isDeleted && !_liveReplication) ||
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
      if (_liveReplication && next['removed'] == true) {
        await _receiveShared(
          id,
          {'snapshot': collaborationSnapshot(local)},
          next,
          generation,
        );
        if (_current(generation)) {
          conflicts.remove(id);
          _inflight.remove(id);
          _canvasConflictBases.remove(id);
          await _checkpointShared();
        }
        return;
      }
      final source = collaborationObject(
        Map<String, dynamic>.from(next['snapshot'] as Map),
        allowDeleted: _liveReplication,
      );
      if (_liveReplication && (local.isDeleted || source.isDeleted)) {
        await _saveSharedObject(
          source,
          local,
          next['path'] as String?,
          generation,
        );
        if (_current(generation)) {
          _documents[id] = next;
          conflicts.remove(id);
          _inflight.remove(id);
          _canvasConflictBases.remove(id);
          await _checkpointShared();
        }
        _notify();
        return;
      }
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
      if (state['protocol'] != 1 ||
          state['workspaceId'] != _workspaceId ||
          state['epoch'] != _serverEpoch) {
        throw StateError(
          'The host changed. Check shared changes and reload the comparison.',
        );
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
          state['epoch'] != _serverEpoch ||
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

class _SharedSessionMismatch implements Exception {
  const _SharedSessionMismatch();
}
