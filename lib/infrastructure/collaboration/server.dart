import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import '../../application/backup_bundle.dart';
import '../../domain/collaboration.dart';
import '../../domain/object_tombstone.dart';
import '../../domain/sync_entry.dart';
import '../../application/sync/sync_policy.dart';
import '../storage/object_codec.dart';

part 'shared_replication.dart';

String collaborationToken() => base64Url
    .encode(List<int>.generate(32, (_) => Random.secure().nextInt(256)))
    .replaceAll('=', '');
String _hash(String token) => sha256.convert(utf8.encode(token)).toString();

/// Server grants and journals must never enter a portable Vault or its backups.
Future<void> validateCollaborationDirectory(Directory directory) async {
  var current = Directory(p.normalize(directory.absolute.path));
  while (!await current.exists()) {
    final parent = current.parent;
    if (parent.path == current.path) {
      throw StateError('Choose an accessible private server data directory.');
    }
    current = parent;
  }
  current = Directory(await current.resolveSymbolicLinks());
  for (var depth = 0; depth < 256; depth++) {
    if (await File(p.join(current.path, 'workspace.json')).exists()) {
      throw StateError(
        'Server data must be outside every Orbit Vault. No server key or journal was created here.',
      );
    }
    final parent = current.parent;
    if (parent.path == current.path) return;
    current = parent;
  }
  throw StateError('Choose a shallower private server data directory.');
}

/// Standalone self-hosted service. Append/flush precedes every acknowledgement;
/// an incomplete final record is truncated on restart, never replayed.
class CollaborationServer {
  CollaborationServer(this.directory, this.ownerToken);
  final Directory directory;
  final String ownerToken;
  final _rooms = <String, Map<String, dynamic>>{};
  final _presence = <String, Map<String, Map<String, dynamic>>>{};
  final _sessions = <String, ({String room, String grant})>{};
  final _placementIds =
      <(String, String), ({Object snapshot, Set<Object?> ids})>{};
  Set<Object?> _knownPlacements(String room, String id, Map snapshot) {
    final key = (room, id), prior = _placementIds[(room, id)];
    if (prior != null && identical(prior.snapshot, snapshot)) return prior.ids;
    final elements = (snapshot['data'] as Map)['elements'];
    final ids = elements is List
        ? elements.whereType<Map>().map((e) => e['id']).toSet()
        : <Object?>{};
    if (_placementIds.length >= 128) {
      _placementIds.remove(_placementIds.keys.first);
    }
    _placementIds[key] = (snapshot: snapshot, ids: ids);
    return ids;
  }

  Future<void> _queue = Future.value();
  HttpServer? _server;
  RandomAccessFile? _lock;
  bool _writeFailed = false;
  String _epoch = collaborationToken();
  final _signals = <String, StreamController<void>>{};
  final _awareness = <String, int>{};
  final _watchers = <String, int>{};
  final _documentBytes = <(String, String), int>{};
  final _roomDocumentBytes = <String, int>{};
  static const maxDocumentBytes = 32 * 1024 * 1024;
  static const maxHistoryBytes = 64 * 1024 * 1024;
  static const maxRoomBytes = 128 * 1024 * 1024;

  Future<int> start({InternetAddress? address, int port = 47831}) async {
    try {
      await validateCollaborationDirectory(directory);
      await directory.create(recursive: true);
      _lock = await File(
        '${directory.path}/server.lock',
      ).open(mode: FileMode.append);
      await _lock!.lock(FileLock.exclusive);
      final journal = File('${directory.path}/events.jsonl');
      if (await journal.exists()) {
        final bytes = await journal.readAsBytes();
        var start = 0;
        for (var i = 0; i < bytes.length; i++) {
          if (bytes[i] != 10) continue;
          _replay(
            Map<String, dynamic>.from(
              jsonDecode(utf8.decode(bytes.sublist(start, i))) as Map,
            ),
          );
          start = i + 1;
        }
        if (start != bytes.length) {
          final file = await journal.open(mode: FileMode.append);
          await file.truncate(start);
          await file.flush();
          await file.close();
        }
      }
      _epoch = collaborationToken();
      _server = await HttpServer.bind(
        address ?? InternetAddress.loopbackIPv4,
        port,
      );
      // Native clients negotiate gzip automatically. Compress JSON losslessly;
      // decoded response limits still apply on the receiving client.
      _server!.autoCompress = true;
      _server!.listen((request) => unawaited(_handle(request)));
      return _server!.port;
    } on Object {
      // Failed startup must release the lock so storage can be repaired and a
      // new server started in the same process.
      await _lock?.close();
      _lock = null;
      rethrow;
    }
  }

  Future<void> close() async {
    for (final signal in _signals.values) {
      signal.add(null);
    }
    await _server?.close(force: true);
    _server = null;
    for (final signal in _signals.values) {
      await signal.close();
    }
    _signals.clear();
    await _queue;
    final lock = _lock;
    _lock = null;
    try {
      await lock?.unlock();
    } finally {
      await lock?.close();
    }
  }

  void _replay(Map<String, dynamic> event) {
    final room = event['room'] as String;
    if (event['kind'] == 'create') {
      _rooms[room] = Map<String, dynamic>.from(event['state'] as Map);
    } else if (event['kind'] == 'grant') {
      (_rooms[room]!['grants'] as Map)[event['hash']] = event['grant'];
    } else if (event['kind'] == 'revoke') {
      (_rooms[room]!['grants'] as Map).remove(event['hash']);
    } else if (event['kind'] == 'attachment') {
      final state = _rooms[room]!;
      state['replicationVersion'] = 2;
      (state['attachments'] ??= <String, dynamic>{})[event['path']] =
          event['attachment'];
      state['sequence'] = event['sequence'];
    } else if (event['kind'] == 'put') {
      final state = _rooms[room]!;
      state['replicationVersion'] = 2;
      (state['documents'] as Map)[event['id']] = event['document'];
      state['sequence'] = event['sequence'];
    } else if (event['kind'] == 'edit') {
      final state = _rooms[room]!;
      final id = event['id'] as String;
      final doc = (state['documents'] as Map)[id] as Map;
      (doc['history'] as Map)['${doc['version']}'] = doc['snapshot'];
      doc['version'] = event['version'];
      doc['snapshot'] = event['snapshot'];
      if (event['path'] != null) doc['path'] = event['path'];
      if (event['removed'] == true) {
        doc['removed'] = true;
        doc['tombstone'] = event['tombstone'];
      }
      doc['sequence'] = event['sequence'];
      while ((doc['history'] as Map).length > 32 ||
          utf8.encode(jsonEncode(doc['history'])).length > maxHistoryBytes) {
        (doc['history'] as Map).remove((doc['history'] as Map).keys.first);
      }
      state['sequence'] = event['sequence'];
      final operations = state['operations'] as Map;
      operations[event['operation']] = {
        'id': id,
        'version': event['version'],
        'proposalHash': event['proposalHash'],
      };
      while (operations.length > 1000) {
        operations.remove(operations.keys.first);
      }
    } else {
      throw const FormatException('Unsupported complete journal record.');
    }
    if (event['kind'] == 'create') {
      for (final entry in (_rooms[room]!['documents'] as Map).entries) {
        _recordDocumentBytes(room, entry.key as String, entry.value as Map);
      }
    } else if (event['kind'] == 'edit' || event['kind'] == 'put') {
      _recordDocumentBytes(
        room,
        event['id'] as String,
        (_rooms[room]!['documents'] as Map)[event['id']] as Map,
      );
    }
  }

  void _recordDocumentBytes(String room, String id, Map document) {
    final key = (room, id), size = utf8.encode(jsonEncode(document)).length;
    _roomDocumentBytes[room] =
        (_roomDocumentBytes[room] ?? 0) - (_documentBytes[key] ?? 0) + size;
    _documentBytes[key] = size;
  }

  void _checkRoomBudget(Map<String, dynamic> event) {
    final room = event['room'] as String;
    if (event['kind'] == 'create') {
      if (utf8.encode(jsonEncode(event['state'])).length > maxRoomBytes) {
        throw const FormatException('Shared room metadata limit reached.');
      }
      return;
    }
    final state = _rooms[room]!;
    final metadata = {...state}..remove('documents');
    var size = _roomDocumentBytes[room] ?? 0;
    if (event['kind'] == 'put' || event['kind'] == 'edit') {
      final id = event['id'] as String;
      Map next;
      if (event['kind'] == 'put') {
        next = event['document'] as Map;
      } else {
        final old = (state['documents'] as Map)[id] as Map;
        final history = Map<String, dynamic>.from(old['history'] as Map)
          ..['${old['version']}'] = old['snapshot'];
        while (history.length > 32 ||
            utf8.encode(jsonEncode(history)).length > maxHistoryBytes) {
          history.remove(history.keys.first);
        }
        next = {
          ...old,
          'history': history,
          'snapshot': event['snapshot'],
          'version': event['version'],
          'sequence': event['sequence'],
        };
      }
      size +=
          utf8.encode(jsonEncode(next)).length -
          (_documentBytes[(room, id)] ?? 0);
    } else if (event['kind'] == 'attachment') {
      metadata['attachments'] = {
        ...?state['attachments'] as Map?,
        event['path']: event['attachment'],
      };
    }
    if (size + utf8.encode(jsonEncode(metadata)).length > maxRoomBytes) {
      throw const FormatException('Shared room metadata limit reached.');
    }
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _commit(Map<String, dynamic> event) async {
    if (_writeFailed) {
      throw StateError('Restart the server after repairing its storage.');
    }
    _checkRoomBudget(event);
    final serialized = jsonEncode(event);
    try {
      if ({'put', 'attachment'}.contains(event['kind'])) {
        final before = File('${directory.path}/events.before-live-v2.jsonl');
        final log = File('${directory.path}/events.jsonl');
        if (!await before.exists() && await log.exists()) {
          final pending = File('${before.path}.pending');
          final sink = pending.openWrite();
          try {
            await sink.addStream(log.openRead());
            await sink.flush();
          } finally {
            await sink.close();
          }
          if ((await sha256.bind(log.openRead()).first).toString() !=
              (await sha256.bind(pending.openRead()).first).toString()) {
            throw StateError(
              'Host journal changed during recovery checkpoint.',
            );
          }
          await pending.rename(before.path);
        }
      }
      await File(
        '${directory.path}/events.jsonl',
      ).writeAsString('$serialized\n', mode: FileMode.append, flush: true);
      _replay(Map<String, dynamic>.from(jsonDecode(serialized) as Map));
      _signals[event['room']]?.add(null);
    } on Object {
      // A failed append may have left a partial record. Do not append another
      // acknowledged edit after it; restart repairs only a torn final record.
      _writeFailed = true;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _body(HttpRequest request, int max) async {
    final bytes = BytesBuilder(copy: false);
    final encoding = request.headers.value(HttpHeaders.contentEncodingHeader);
    if (encoding != null && encoding != 'identity' && encoding != 'gzip') {
      throw const FormatException('Unsupported request encoding.');
    }
    var encodedBytes = 0;
    Stream<List<int>> stream = request.map((chunk) {
      encodedBytes += chunk.length;
      if (encodedBytes > max + 65536) {
        throw const FormatException('Request too large.');
      }
      return chunk;
    });
    if (encoding == 'gzip') stream = stream.transform(gzip.decoder);
    await for (final chunk in stream.timeout(const Duration(seconds: 30))) {
      if (bytes.length + chunk.length > max) {
        throw const FormatException('Request too large.');
      }
      bytes.add(chunk);
    }
    return Map<String, dynamic>.from(
      jsonDecode(utf8.decode(bytes.takeBytes())) as Map,
    );
  }

  ({Map state, Map grant, String hash}) _access(
    String room,
    String token, {
    bool edit = false,
    bool owner = false,
  }) {
    final state = _rooms[room];
    final hash = _hash(token);
    final grant = (state?['grants'] as Map?)?[hash];
    if (state == null ||
        grant is! Map ||
        (edit && grant['role'] == 'viewer') ||
        (owner && grant['role'] != 'owner')) {
      throw const HttpException('Access denied.');
    }
    return (state: state, grant: grant, hash: hash);
  }

  List<Map<String, dynamic>> _peers(String room) {
    final peers = _presence[room] ?? {};
    final prior = peers.keys.toSet();
    peers.removeWhere(
      (_, v) =>
          DateTime.now().difference(DateTime.parse(v['seen'] as String)) >
              const Duration(seconds: 15) ||
          !(_rooms[room]!['grants'] as Map).containsKey(v['grant']),
    );
    for (final session in prior.difference(peers.keys.toSet())) {
      _sessions.remove(session);
    }
    return peers.values
        .map((v) => Map<String, dynamic>.from(v)..remove('grant'))
        .toList();
  }

  Future<void> _handle(HttpRequest request) async {
    request.response.headers.contentType = ContentType.json;
    request.response.headers.set('Cache-Control', 'no-store');
    // Optional HTTP capability; older clients/hosts continue using plain JSON.
    request.response.headers.set('X-Orbit-Accept-Encoding', 'gzip');
    try {
      if (request.headers.value('origin') != null) {
        throw const HttpException('Browser clients are not enabled.');
      }
      final token =
          request.headers.value('authorization')?.replaceFirst('Bearer ', '') ??
          '';
      if (request.method == 'GET' && request.uri.path == '/healthz') {
        request.response.statusCode = _writeFailed ? 503 : 200;
        request.response.write(
          jsonEncode({
            'service': 'orbit-collaboration',
            'ready': !_writeFailed,
            'instance': _epoch,
          }),
        );
        return;
      }
      if (request.method == 'GET' && request.uri.path == '/v1/server') {
        if (_hash(token) != _hash(ownerToken)) {
          throw const HttpException('Access denied.');
        }
        request.response.write(
          jsonEncode({
            'service': 'orbit-collaboration',
            'protocol': 1,
            'ready': !_writeFailed,
            'rooms': _rooms.length,
            'capabilities': [
              'existing-notes',
              'canvas',
              'presence',
              'durable-journal',
              'snapshot-attachments',
              'live-objects',
              'live-attachments',
              'events',
              'text-ranges',
            ],
            'maxSnapshotBytes': BackupBundle.maxEncodedBytes,
          }),
        );
        return;
      }
      if (request.method == 'POST' && request.uri.path == '/v1/rooms') {
        if (_hash(token) != _hash(ownerToken)) {
          throw const HttpException('Access denied.');
        }
        final body = await _body(request, BackupBundle.maxEncodedBytes + 1024);
        final source = body['backup'] as String;
        final bundle = BackupBundle.parse(source);
        if (bundle.warnings.isNotEmpty) {
          throw const FormatException(
            'Resolve backup validation warnings before sharing.',
          );
        }
        final room = collaborationToken();
        final invitation = collaborationToken();
        final documents = <String, dynamic>{};
        final workspace =
            (jsonDecode(utf8.decode(bundle.files['workspace.json']!))
                    as Map)['id']
                as String;
        for (final entry in bundle.files.entries) {
          if (syncPathRole(entry.key) == SyncPathRole.tombstone) {
            final tombstone = ObjectTombstone.fromJson(
              jsonDecode(utf8.decode(entry.value)) as Map<String, dynamic>,
            );
            if (tombstone.workspaceId != workspace) {
              throw const FormatException('Wrong deletion Vault.');
            }
            documents[tombstone.objectId] = {
              'version': 1,
              'sequence': 1,
              'removed': true,
              'tombstone': tombstone.toJson(),
              'path': tombstone.path,
            };
            continue;
          }
          if (syncPathRole(entry.key) != SyncPathRole.object) {
            continue;
          }
          final object = ObjectCodec().decode(
            utf8.decode(entry.value),
            workspace,
            markdown: entry.key.endsWith('.md'),
          );
          if (object.isReadOnly) {
            continue;
          }
          final snapshot = collaborationSnapshot(object);
          if (utf8.encode(jsonEncode(snapshot)).length > maxDocumentBytes) {
            throw const FormatException(
              'A shared note or Canvas exceeds the 32 MiB document limit.',
            );
          }
          documents[object.id] = {
            'version': 1,
            'sequence': 1,
            'snapshot': snapshot,
            'history': <String, dynamic>{},
            'path': entry.key,
          };
        }
        if (documents.length > 10000) {
          throw const FormatException('Shared object limit reached.');
        }
        await _serial(() async {
          final attachments = <String, dynamic>{};
          for (final entry in bundle.files.entries.where(
            (e) => syncPathRole(e.key) == SyncPathRole.attachment,
          )) {
            final hash = sha256.convert(entry.value).toString();
            final file = _blobFile(room, hash);
            await file.parent.create(recursive: true);
            await file.writeAsBytes(entry.value, flush: true);
            attachments[entry.key] = {'hash': hash, 'size': entry.value.length};
          }
          await File(
            '${directory.path}/$room.backup.json',
          ).writeAsString(source, flush: true);
          await _commit({
            'kind': 'create',
            'room': room,
            'state': {
              'workspaceId': workspace,
              'replicationVersion': body['replicationVersion'] == 2 ? 2 : 1,
              'name': bundle.name,
              'sequence': 1,
              'documents': documents,
              'attachments': attachments,
              'operations': <String, dynamic>{},
              'grants': {
                _hash(invitation): {
                  'role': 'owner',
                  'name': _name(body['name']),
                },
              },
            },
          });
        });
        request.response.write(jsonEncode({'room': room, 'token': invitation}));
      } else {
        final parts = request.uri.pathSegments;
        if (parts.length != 4 || parts[0] != 'v1' || parts[1] != 'rooms') {
          throw const FormatException('Unknown endpoint.');
        }
        final room = parts[2], action = parts[3];
        if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(room)) {
          throw const HttpException('Access denied.');
        }
        final access = _access(room, token);
        if (access.state['replicationVersion'] == 2 &&
            request.headers.value('x-orbit-client') != '2') {
          throw const FormatException(
            'This shared Vault requires an updated Orbit client.',
          );
        }
        if (await _replicationRequest(request, room, token, action)) return;
        switch ((request.method, action)) {
          case ('GET', 'state'):
            final documents = access.state['documents'] as Map;
            // A restarted/restored host has a new incarnation. A client's old
            // cursor may exceed this journal, so return a full snapshot instead.
            final requestedEpoch = request.uri.queryParameters['epoch'];
            final since = requestedEpoch != null && requestedEpoch != _epoch
                ? 0
                : int.tryParse(request.uri.queryParameters['since'] ?? '0');
            if (since == null ||
                since < 0 ||
                since > (access.state['sequence'] as int)) {
              throw const FormatException('Invalid sequence.');
            }
            request.response.write(
              jsonEncode({
                'protocol': 1,
                'epoch': _epoch,
                'workspaceId': access.state['workspaceId'],
                'name': access.state['name'],
                'sequence': access.state['sequence'],
                'role': access.grant['role'],
                'capabilities': access.state['replicationVersion'] == 2
                    ? [
                        'live-objects',
                        'live-attachments',
                        'events',
                        'text-ranges',
                      ]
                    : <String>[],
                'minimumClient': access.state['replicationVersion'] == 2
                    ? 2
                    : 1,
                'attachments':
                    access.state['attachments'] ?? <String, dynamic>{},
                'documents': {
                  for (final e in documents.entries)
                    if (((e.value as Map)['sequence'] as int? ?? 1) > since)
                      e.key: {
                        'version': (e.value as Map)['version'],
                        'snapshot': (e.value as Map)['snapshot'],
                        'path': (e.value as Map)['path'],
                        if ((e.value as Map)['removed'] == true)
                          'removed': true,
                        if ((e.value as Map)['tombstone'] != null)
                          'tombstone': (e.value as Map)['tombstone'],
                      },
                },
                'peers': _peers(room),
              }),
            );
          case ('GET', 'backup'):
            final root =
                jsonDecode(
                      await File(
                        '${directory.path}/$room.backup.json',
                      ).readAsString(),
                    )
                    as Map;
            final files = root['files'] as Map;
            final attachments = access.state['attachments'] as Map? ?? {};
            if (attachments.values.whereType<Map>().fold<int>(
                  0,
                  (sum, a) => sum + (a['size'] as int) * 4 ~/ 3 + 4,
                ) >
                BackupBundle.maxEncodedBytes) {
              throw const FormatException(
                'Attachments exceed the snapshot limit; use live replication.',
              );
            }
            for (final doc
                in (access.state['documents'] as Map).values.cast<Map>()) {
              if (doc['removed'] == true) {
                files.remove(doc['path']);
                final tombstone = ObjectTombstone.fromJson(
                  Map<String, dynamic>.from(doc['tombstone'] as Map),
                );
                files[tombstone.storagePath] = base64Encode(
                  utf8.encode(jsonEncode(tombstone.toJson())),
                );
                continue;
              }
              files[doc['path']] = base64Encode(
                utf8.encode(
                  ObjectCodec().encode(
                    collaborationObject(
                      Map<String, dynamic>.from(doc['snapshot'] as Map),
                      allowDeleted: true,
                    ),
                  ),
                ),
              );
            }
            for (final entry
                in (access.state['attachments'] as Map? ?? {}).entries) {
              final attachment = entry.value as Map;
              files[entry.key] = base64Encode(
                await _blobFile(
                  room,
                  attachment['hash'] as String,
                ).readAsBytes(),
              );
            }
            if (utf8.encode(jsonEncode(root)).length >
                BackupBundle.maxEncodedBytes) {
              throw const FormatException(
                'Shared backup exceeds snapshot limit.',
              );
            }
            request.response.write(jsonEncode(root));
          case ('POST', 'invite'):
            _access(room, token, owner: true);
            final body = await _body(request, 1024);
            if (!['editor', 'viewer'].contains(body['role'])) {
              throw const FormatException('Choose editor or viewer.');
            }
            final invitation = collaborationToken();
            await _serial(
              () => _commit({
                'kind': 'grant',
                'room': room,
                'hash': _hash(invitation),
                'grant': {'role': body['role'], 'name': _name(body['name'])},
              }),
            );
            request.response.write(jsonEncode({'token': invitation}));
          case ('POST', 'revoke'):
            _access(room, token, owner: true);
            final body = await _body(request, 1024);
            final hash = _hash(body['token'] as String);
            if (((access.state['grants'] as Map)[hash] as Map?)?['role'] ==
                'owner') {
              throw const FormatException(
                'Owner access cannot be revoked here.',
              );
            }
            await _serial(
              () => _commit({'kind': 'revoke', 'room': room, 'hash': hash}),
            );
            request.response.write('{}');
          case ('POST', 'presence'):
            final body = await _body(request, 16 * 1024);
            final session = body['session'] as String;
            if (!RegExp(r'^[A-Za-z0-9-]{1,80}$').hasMatch(session)) {
              throw const FormatException('Invalid session.');
            }
            final prior = _sessions[session];
            if (prior != null &&
                (prior.room != room || prior.grant != access.hash)) {
              throw const HttpException('Session belongs to another member.');
            }
            if (body['active'] == false) {
              _presence[room]?.remove(session);
              _sessions.remove(session);
              _awareness[room] = (_awareness[room] ?? 0) + 1;
              _signals[room]?.add(null);
              request.response.write('{}');
              return;
            }
            _peers(room);
            if (prior == null && (_presence[room]?.length ?? 0) >= 128) {
              throw const FormatException('Too many active sessions.');
            }
            final objectId = body['objectId'];
            if (!(access.state['documents'] as Map).containsKey(objectId)) {
              throw const FormatException('Object is not shared.');
            }
            for (final key in ['x', 'y']) {
              if (body[key] is! num ||
                  !(body[key] as num).isFinite ||
                  (body[key] as num).abs() > 100000000) {
                throw const FormatException('Invalid cursor.');
              }
            }
            final selected = body['selection'];
            if (selected != null &&
                (selected is! List ||
                    selected.length > 64 ||
                    selected.any(
                      (id) => id is! String || id.isEmpty || id.length > 160,
                    ))) {
              throw const FormatException('Invalid selected placements.');
            }
            final document =
                (access.state['documents'] as Map)[objectId] as Map;
            if (document['removed'] == true) {
              throw const FormatException('Object was removed.');
            }
            final snapshot = document['snapshot'] as Map;
            final knownIds = _knownPlacements(
              room,
              objectId as String,
              snapshot,
            );
            _sessions[session] = (room: room, grant: access.hash);
            final textRange = _textRange(body, document);
            (_presence[room] ??= {})[session] = {
              'session': session,
              'name': access.grant['name'],
              'role': access.grant['role'],
              'grant': access.hash,
              'objectId': objectId,
              'x': body['x'],
              'y': body['y'],
              'space': body['space'] == 'canvas' ? 'canvas' : 'note',
              'selection': body['space'] == 'canvas'
                  ? collaborationSelectionIds(
                      selected,
                    ).where(knownIds.contains).toList()
                  : <String>[],
              'seen': DateTime.now().toUtc().toIso8601String(),
              if (body['space'] == 'canvas' && access.grant['role'] != 'viewer')
                'ink': collaborationInkPreview(body['ink']),
              ...textRange,
            };
            _awareness[room] = (_awareness[room] ?? 0) + 1;
            _signals[room]?.add(null);
            request.response.write('{}');
          case ('POST', 'edit'):
            _access(room, token, edit: true);
            final body = await _body(request, maxDocumentBytes + 2048);
            await _serial(() async {
              _access(room, token, edit: true);
              if (body['epoch'] != null && body['epoch'] != _epoch) {
                throw const CollaborationHostChanged();
              }
              final state = _rooms[room]!;
              final operation = body['operation'] as String;
              if (!RegExp(r'^[A-Za-z0-9-]{1,80}$').hasMatch(operation)) {
                throw const FormatException('Invalid operation.');
              }
              final operationKey = '${access.hash}:$operation';
              final oldResult = (state['operations'] as Map)[operationKey];
              final proposalHash = _hash(jsonEncode(body));
              if (oldResult != null) {
                if ((oldResult as Map)['proposalHash'] != proposalHash) {
                  throw const CollaborationConflict(
                    'a reused operation identifier',
                  );
                }
                final latest =
                    (state['documents'] as Map)[oldResult['id']] as Map;
                request.response.write(
                  jsonEncode({'id': oldResult['id'], ..._document(latest)}),
                );
                return;
              }
              final doc = (state['documents'] as Map)[body['id']] as Map?;
              if (doc == null || doc['removed'] == true) {
                throw const FormatException('Object is not shared.');
              }
              final base = body['version'] == doc['version']
                  ? doc['snapshot']
                  : (doc['history'] as Map)['${body['version']}'];
              if (base == null) {
                throw const CollaborationConflict('an expired editing base');
              }
              final proposed = Map<String, dynamic>.from(
                body['snapshot'] as Map,
              );
              final merged =
                  (state['replicationVersion'] == 2
                  ? mergeSharedDocument
                  : mergeCollaboration)(
                    Map<String, dynamic>.from(base as Map),
                    proposed,
                    Map<String, dynamic>.from(doc['snapshot'] as Map),
                  );
              final object = collaborationObject(merged, allowDeleted: true);
              if (object.workspaceId != state['workspaceId']) {
                throw const FormatException('Invalid shared document.');
              }
              final path = body['path'] as String? ?? doc['path'] as String;
              if (path != doc['path']) {
                throw const CollaborationConflict('a physical owner-file move');
              }
              _validateSharedPath(path, object.id, object.typeId, state);
              await _validateFileObject(
                room,
                state,
                object.properties,
                object.typeId,
              );
              if (utf8.encode(jsonEncode(merged)).length > maxDocumentBytes) {
                throw const FormatException('Shared document exceeds 32 MiB.');
              }
              await _commit({
                'kind': 'edit',
                'room': room,
                'id': body['id'],
                'version': (doc['version'] as int) + 1,
                'snapshot': merged,
                'path': path,
                'operation': operationKey,
                'proposalHash': proposalHash,
                'sequence': (state['sequence'] as int) + 1,
              });
              request.response.write(
                jsonEncode({'id': body['id'], ..._document(doc)}),
              );
            });
          default:
            throw const FormatException('Unknown endpoint.');
        }
      }
    } on CollaborationConflict catch (e) {
      request.response.statusCode = 409;
      request.response.write(
        jsonEncode({
          'error': e.toString(),
          if (e is CollaborationHostChanged) 'code': 'host-restarted',
        }),
      );
    } on HttpException {
      request.response.statusCode = 403;
      request.response.write('{"error":"Access denied."}');
    } on FormatException {
      request.response.statusCode = 400;
      request.response.write(
        '{"error":"Invalid or unsupported request. Nothing was replaced."}',
      );
    } on Object {
      request.response.statusCode = 503;
      request.response.write(
        '{"error":"The server could not durably finish this action. Retry with the same operation."}',
      );
    } finally {
      await request.response.close();
    }
  }

  String _name(dynamic value) {
    if (value is! String ||
        value.trim().isEmpty ||
        value.length > 80 ||
        RegExp(r'[\x00-\x1f]').hasMatch(value)) {
      throw const FormatException('A display name is required.');
    }
    return value.trim();
  }
}
