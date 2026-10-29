part of 'server.dart';

extension _SharedReplication on CollaborationServer {
  File _blobFile(String room, String hash, {bool partial = false}) =>
      File('${directory.path}/$room.blobs/$hash${partial ? '.part' : '.blob'}');
  String _digest(Object? value) {
    if (value is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
      throw const FormatException('Invalid attachment hash.');
    }
    return value;
  }

  int _length(Object? value) {
    final result = int.tryParse('$value');
    if (result == null || result < 0 || result > 2 * 1024 * 1024 * 1024) {
      throw const FormatException('Invalid attachment size.');
    }
    return result;
  }

  void _validateSharedPath(String path, String id, String type, Map state) {
    validateSyncEntries({id: SyncEntry(key: id, path: path, hash: '0' * 64)});
    final valid = switch (type) {
      'orbit.note' => path.startsWith('Notes/') && path.endsWith('.md'),
      'orbit.canvas' =>
        path.startsWith('Boards/') && path.endsWith('.board.json'),
      'orbit.drawing' =>
        path.startsWith('Drawings/') && path.endsWith('.drawing.json'),
      _ => path.startsWith('Objects/') && path.endsWith('.object.json'),
    };
    if (!valid) throw const FormatException('Wrong owning path.');
    for (final entry in (state['documents'] as Map).entries) {
      if (entry.key != id &&
          ((entry.value as Map)['path'] as String).toLowerCase() ==
              path.toLowerCase()) {
        throw const CollaborationConflict('an occupied owning path');
      }
    }
  }

  Future<void> _validateFileObject(
    String room,
    Map state,
    Map props,
    String type,
  ) async {
    if (type != 'orbit.file') return;
    final path = props['contentRef'], hash = props['checksum'];
    final attachment = (state['attachments'] as Map?)?[path];
    if (attachment is! Map ||
        attachment['hash'] != hash ||
        !await _blobFile(room, _digest(hash)).exists()) {
      throw const CollaborationConflict(
        'an attachment that has not finished transferring',
      );
    }
  }

  Map<String, dynamic> _document(Map value) => {
    'version': value['version'],
    'snapshot': value['snapshot'],
    'path': value['path'],
    if (value['removed'] == true) 'removed': true,
    if (value['tombstone'] != null) 'tombstone': value['tombstone'],
  };

  Future<bool> _replicationRequest(
    HttpRequest request,
    String room,
    String token,
    String action,
  ) async {
    final access = _access(room, token);
    final query = request.uri.queryParameters;
    switch ((request.method, action)) {
      case ('GET', 'events'):
        if ((_watchers[room] ?? 0) >= 128) {
          throw const FormatException('Too many waiting clients.');
        }
        final seq = int.tryParse(query['since'] ?? '-1'),
            awareness = int.tryParse(query['awareness'] ?? '-1');
        if (seq == null || seq < 0 || awareness == null || awareness < 0) {
          throw const FormatException('Invalid event cursor.');
        }
        _watchers[room] = (_watchers[room] ?? 0) + 1;
        try {
          if (query['epoch'] == _epoch &&
              seq == access.state['sequence'] &&
              awareness == (_awareness[room] ?? 0)) {
            final signal = _signals.putIfAbsent(
              room,
              () => StreamController<void>.broadcast(),
            );
            await signal.stream.first.timeout(
              const Duration(seconds: 15),
              onTimeout: () {},
            );
          }
          final current = _access(room, token);
          request.response.write(
            jsonEncode({
              'epoch': _epoch,
              'sequence': current.state['sequence'],
              'awareness': _awareness[room] ?? 0,
              'peers': _peers(room),
            }),
          );
        } finally {
          _watchers[room] = (_watchers[room] ?? 1) - 1;
        }
      case ('GET', 'blob-status'):
        _access(room, token, edit: true);
        final hash = _digest(query['hash']), size = _length(query['size']);
        final file = _blobFile(room, hash),
            part = _blobFile(room, hash, partial: true);
        final complete = await file.exists();
        if (complete &&
            (await file.length() != size ||
                (await sha256.bind(file.openRead()).first).toString() !=
                    hash)) {
          throw const CollaborationConflict('damaged stored attachment bytes');
        }
        request.response.write(
          jsonEncode({
            'offset': complete
                ? size
                : await part.exists()
                ? await part.length()
                : 0,
            'complete': complete,
          }),
        );
      case ('PUT', 'blob'):
        _access(room, token, edit: true);
        final hash = _digest(query['hash']),
            size = _length(query['size']),
            offset = _length(query['offset']);
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in request.timeout(
          const Duration(seconds: 30),
        )) {
          if (bytes.length + chunk.length > 1024 * 1024) {
            throw const FormatException('Attachment chunk exceeds 1 MiB.');
          }
          bytes.add(chunk);
        }
        await _serial(() async {
          _access(room, token, edit: true);
          final file = _blobFile(room, hash),
              part = _blobFile(room, hash, partial: true);
          if (await file.exists()) {
            if (await file.length() != size) {
              throw const CollaborationConflict('attachment size');
            }
            request.response.write(
              jsonEncode({'offset': size, 'complete': true}),
            );
            return;
          }
          await part.parent.create(recursive: true);
          final current = await part.exists() ? await part.length() : 0;
          if (current != offset) {
            request.response.write(
              jsonEncode({'offset': current, 'complete': false}),
            );
            return;
          }
          if (offset + bytes.length > size || (bytes.isEmpty && size != 0)) {
            throw const FormatException('Invalid attachment range.');
          }
          await part.writeAsBytes(
            bytes.takeBytes(),
            mode: FileMode.append,
            flush: true,
          );
          final end = await part.length();
          if (end == size) {
            if ((await sha256.bind(part.openRead()).first).toString() != hash) {
              await part.delete();
              throw const FormatException('Attachment checksum differs.');
            }
            await part.rename(file.path);
          }
          request.response.write(
            jsonEncode({'offset': end, 'complete': end == size}),
          );
        });
      case ('GET', 'blob'):
        final hash = _digest(query['hash']),
            offset = _length(query['offset'] ?? 0);
        if (!(access.state['attachments'] as Map? ?? {}).values
            .whereType<Map>()
            .any((a) => a['hash'] == hash)) {
          throw const HttpException('Unpublished attachment.');
        }
        final file = _blobFile(room, hash), size = await file.length();
        if (offset > size) {
          throw const FormatException('Invalid attachment offset.');
        }
        final end = (offset + 1024 * 1024).clamp(offset, size);
        request.response.headers.contentType = ContentType.binary;
        request.response.headers.set('X-Orbit-Size', '$size');
        request.response.contentLength = end - offset;
        await request.response.addStream(file.openRead(offset, end));
      case ('POST', 'attachment'):
        _access(room, token, edit: true);
        final body = await _body(request, 4096);
        await _serial(() async {
          final state = _access(room, token, edit: true).state;
          if (body['epoch'] != _epoch) throw const CollaborationHostChanged();
          final path = body['path'] as String,
              hash = _digest(body['hash']),
              size = _length(body['size']);
          validateSyncEntries({
            'blob:$path': SyncEntry(key: 'blob:$path', path: path, hash: hash),
          });
          if (syncPathRole(path) != SyncPathRole.attachment) {
            throw const FormatException('Invalid attachment path.');
          }
          final file = _blobFile(room, hash);
          if (!await file.exists() || await file.length() != size) {
            throw const CollaborationConflict('an incomplete attachment');
          }
          final prior = (state['attachments'] as Map?)?[path];
          if ((state['attachments'] as Map? ?? {}).keys.any(
            (p) =>
                p != path && (p as String).toLowerCase() == path.toLowerCase(),
          )) {
            throw const CollaborationConflict('a conflicting attachment path');
          }
          if (prior != null) {
            if ((prior as Map)['hash'] != hash || prior['size'] != size) {
              throw const CollaborationConflict('an immutable attachment path');
            }
          } else {
            await _commit({
              'kind': 'attachment',
              'room': room,
              'path': path,
              'attachment': {'hash': hash, 'size': size},
              'sequence': (state['sequence'] as int) + 1,
            });
          }
          request.response.write('{}');
        });
      case ('POST', 'put'):
        _access(room, token, edit: true);
        final body = await _body(
          request,
          CollaborationServer.maxDocumentBytes + 4096,
        );
        await _serial(() async {
          final state = _access(room, token, edit: true).state;
          if (body['epoch'] != _epoch) throw const CollaborationHostChanged();
          final snapshot = Map<String, dynamic>.from(body['snapshot'] as Map);
          if (utf8.encode(jsonEncode(snapshot)).length >
              CollaborationServer.maxDocumentBytes) {
            throw const FormatException('Shared document exceeds 32 MiB.');
          }
          final object = collaborationObject(snapshot, allowDeleted: true),
              path = body['path'] as String;
          if (object.workspaceId != state['workspaceId']) {
            throw const FormatException('Wrong Vault identity.');
          }
          _validateSharedPath(path, object.id, object.typeId, state);
          await _validateFileObject(
            room,
            state,
            object.properties,
            object.typeId,
          );
          final operation = body['operation'] as String;
          if (!RegExp(r'^[A-Za-z0-9-]{1,80}$').hasMatch(operation)) {
            throw const FormatException('Invalid operation.');
          }
          final op = '${access.hash}:$operation',
              hash = _hash(jsonEncode(body));
          final prior = (state['documents'] as Map)[object.id] as Map?;
          if (prior != null) {
            if (prior['removed'] == true) {
              throw const CollaborationConflict('a permanently deleted object');
            }
            if (!((prior['creationOperation'] == op &&
                    prior['creationHash'] == hash) ||
                (prior['path'] == path &&
                    collaborationContentEqual(
                      snapshot,
                      Map<String, dynamic>.from(prior['snapshot'] as Map),
                    )))) {
              throw const CollaborationConflict('an existing object identity');
            }
            request.response.write(jsonEncode(_document(prior)));
            return;
          }
          if ((state['documents'] as Map).length >= 10000) {
            throw const FormatException('Shared object limit reached.');
          }
          final doc = {
            'version': 1,
            'sequence': (state['sequence'] as int) + 1,
            'snapshot': snapshot,
            'path': path,
            'history': <String, dynamic>{},
            'creationOperation': op,
            'creationHash': hash,
          };
          await _commit({
            'kind': 'put',
            'room': room,
            'id': object.id,
            'document': doc,
            'sequence': doc['sequence'],
          });
          request.response.write(jsonEncode(_document(doc)));
        });
      case ('POST', 'remove'):
        _access(room, token, edit: true);
        final body = await _body(
          request,
          CollaborationServer.maxDocumentBytes + 4096,
        );
        await _serial(() async {
          final state = _access(room, token, edit: true).state;
          if (body['epoch'] != _epoch) throw const CollaborationHostChanged();
          final tombstone = ObjectTombstone.fromJson(
            Map<String, dynamic>.from(body['tombstone'] as Map),
          );
          if (tombstone.workspaceId != state['workspaceId'] ||
              syncPathRole(tombstone.path) != SyncPathRole.object) {
            throw const FormatException('Invalid deletion identity.');
          }
          final id = tombstone.objectId,
              doc = (state['documents'] as Map)[tombstone.objectId] as Map?;
          if (doc != null && doc['path'] != tombstone.path) {
            throw const CollaborationConflict('a mismatched deletion owner');
          }
          if (doc?['removed'] == true) {
            request.response.write(jsonEncode(_document(doc!)));
            return;
          }
          if (doc != null && doc['version'] != body['version']) {
            throw const CollaborationConflict(
              'deletion versus a newer shared edit',
            );
          }
          final next = {
            ...?doc,
            'version': (doc?['version'] as int? ?? 0) + 1,
            'sequence': (state['sequence'] as int) + 1,
            'path': doc?['path'] ?? tombstone.path,
            'removed': true,
            'tombstone': tombstone.toJson(),
          };
          await _commit({
            'kind': 'put',
            'room': room,
            'id': id,
            'document': next,
            'sequence': next['sequence'],
          });
          request.response.write(jsonEncode(_document(next)));
        });
      default:
        return false;
    }
    return true;
  }

  Map<String, dynamic> _textRange(Map body, Map doc) {
    if (body['textBase'] == null && body['textExtent'] == null) return {};
    if (body['space'] == 'canvas') {
      throw const FormatException('Text ranges require note space.');
    }
    final text = ((doc['snapshot'] as Map)['body']) as String;
    if (body['textHash'] != sha256.convert(utf8.encode(text)).toString()) {
      return {'textStale': true};
    }
    final base = body['textBase'], extent = body['textExtent'];
    bool valid(Object? offset) =>
        offset is int &&
        offset >= 0 &&
        offset <= text.length &&
        !(offset > 0 &&
            offset < text.length &&
            text.codeUnitAt(offset) >= 0xdc00 &&
            text.codeUnitAt(offset) <= 0xdfff);
    if (!valid(base) || !valid(extent)) {
      throw const FormatException('Invalid UTF-16 selection.');
    }
    return {
      'textBase': base,
      'textExtent': extent,
      'textHash': body['textHash'],
      'textVersion': doc['version'],
    };
  }
}
