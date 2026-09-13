part of 'workspace_repository.dart';

extension WorkspaceFolders on WorkspaceRepository {
  String _folder(String value) {
    final path = value.isEmpty || value == 'Notes'
        ? 'Notes'
        : value.startsWith('Notes/')
        ? value
        : 'Notes/$value';
    validateNotesPath(path);
    return path;
  }

  String objectFolder(String id) {
    final path = _paths[id];
    if (path != null && path.startsWith('Notes/')) return p.posix.dirname(path);
    final raw = _objects[id]?.properties['folder'];
    try {
      return _folder(raw is String ? raw : 'Notes');
    } on WorkspaceFailure {
      return 'Notes';
    } // Preserve invalid metadata without crashing Explorer.
  }

  bool _inside(String folder, String ancestor) =>
      folder == ancestor || folder.startsWith('$ancestor/');

  Future<void> moveObjectsToFolder(Iterable<String> ids, String folder) =>
      _serial(() async {
        _requireWritable();
        await _verifyManifest();
        final target = _folder(folder);
        if (!_folders.contains(target)) {
          throw const WorkspaceFailure('Choose an existing folder.');
        }
        final selected = ids.toSet().map(_requireObject).toList();
        final movedPaths = {
          for (final o in selected.where((o) => o.typeId == 'orbit.note'))
            _paths[o.id]!: '$target/${p.posix.basename(_paths[o.id]!)}',
        };
        final files = <FolderFileChange>[];
        for (final object in selected) {
          _validate(object);
          final source = _paths[object.id]!;
          final destination = object.typeId == 'orbit.note'
              ? '$target/${p.posix.basename(source)}'
              : source;
          files.add(
            _folderChange(object, target, destination, movedPaths: movedPaths),
          );
        }
        await _applyFolders(files);
      });

  FolderFileChange _folderChange(
    UniversalObject object,
    String folder,
    String target, {
    String? movedSource,
    String? movedTarget,
    bool trash = false,
    Map<String, String> movedPaths = const {},
  }) {
    _validate(object);
    final source = _paths[object.id]!;
    final body = object.typeId == 'orbit.note'
        ? rebaseNoteLinks(
            object.body,
            source,
            target,
            movedSource: movedSource,
            movedTarget: movedTarget,
            movedPaths: movedPaths,
          )
        : object.body;
    final next = object.copyWith(
      body: body,
      properties: {...object.properties, 'folder': folder},
      revision: object.revision + 1,
      updatedAt: DateTime.now().toUtc(),
      deletedAt: trash
          ? (object.deletedAt ?? DateTime.now().toUtc())
          : object.deletedAt,
    );
    return FolderFileChange(
      source,
      target,
      _bytes(_codec.encode(next, previousSource: _sources[object.id])),
      _hashes[object.id]!,
    );
  }

  Future<void> _changeFolder(String source, String? target) async {
    _requireWritable();
    await _verifyManifest();
    source = _folder(source);
    if (source == 'Notes') {
      throw const WorkspaceFailure('Cannot move or delete the Notes root.');
    }
    if (target != null) {
      target = _folder(target);
      if (_inside(target.toLowerCase(), source.toLowerCase()) ||
          _folders.any((f) => f.toLowerCase() == target!.toLowerCase())) {
        throw const WorkspaceFailure(
          'Choose a new destination outside this folder.',
        );
      }
    }
    final owned = _paths.values.toSet();
    for (final path in await _store.listFiles()) {
      if (_inside(path, source) && !owned.contains(path)) {
        throw const WorkspaceFailure(
          'Move unrecognized files out before changing this folder.',
        );
      }
    }
    final files = <FolderFileChange>[];
    final movedPaths = <String, String>{};
    for (final o in objects.where((o) => o.typeId == 'orbit.note')) {
      final folder = objectFolder(o.id);
      if (!_inside(folder, source)) continue;
      final nextFolder = target == null
          ? 'Notes'
          : '$target${folder.substring(source.length)}';
      movedPaths[_paths[o.id]!] =
          '$nextFolder/${p.posix.basename(_paths[o.id]!)}';
    }
    for (final object in objects) {
      final folder = objectFolder(object.id);
      if (!_inside(folder, source)) continue;
      final nextFolder = target == null
          ? 'Notes'
          : '$target${folder.substring(source.length)}';
      final path = _paths[object.id]!;
      final nextPath = object.typeId == 'orbit.note'
          ? '$nextFolder/${p.posix.basename(path)}'
          : path;
      files.add(
        _folderChange(
          object,
          nextFolder,
          nextPath,
          movedSource: source,
          movedTarget: target,
          trash: target == null,
          movedPaths: movedPaths,
        ),
      );
    }
    final oldFolders = _folders.where((f) => _inside(f, source)).toList();
    final newFolders = target == null
        ? <String>[]
        : [
            target,
            for (final old in oldFolders)
              '$target${old.substring(source.length)}',
          ];
    await _applyFolders(
      files,
      create: newFolders.toSet().toList(),
      remove: oldFolders,
    );
  }

  Future<void> _applyFolders(
    List<FolderFileChange> files, {
    List<String> create = const [],
    List<String> remove = const [],
  }) async {
    final store = _store;
    if (store is WorkspaceFolderCommandStore) {
      try {
        await (store as WorkspaceFolderCommandStore).applyFolderCommand(
          files,
          workspaceId: workspaceId,
          createFolders: create,
          removeFolders: remove,
        );
      } finally {
        await _refresh();
      }
      return;
    }
    throw const WorkspaceFailure(
      'This storage adapter cannot safely commit a folder command. Use a native Vault.',
    );
  }
}
