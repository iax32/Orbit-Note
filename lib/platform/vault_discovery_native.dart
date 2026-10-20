import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../application/workspace_repository.dart';
import '../domain/vault_candidate.dart';
import '../domain/workspace_failure.dart';
import '../infrastructure/storage/memory_object_index.dart';
import '../infrastructure/storage/native_workspace_store.dart';

bool vaultPathsEqual(String a, String b) => p.equals(
  Platform.isWindows ? a.toLowerCase() : a,
  Platform.isWindows ? b.toLowerCase() : b,
);

Future<VaultCandidate?> _inspect(String path) async {
  if (await FileSystemEntity.type(path, followLinks: false) !=
      FileSystemEntityType.directory) {
    return null;
  }
  final root = await Directory(path).resolveSymbolicLinks();
  final file = File(p.join(root, 'workspace.json'));
  if (await FileSystemEntity.type(file.path, followLinks: false) !=
      FileSystemEntityType.file) {
    return null;
  }
  if (await file.length() > 1024 * 1024) {
    throw const WorkspaceFailure(
      'Vault manifest exceeds the safe opening limit.',
    );
  }
  final value = jsonDecode(await file.readAsString()) as Map;
  if (value['format'] != 'orbit-note-workspace' ||
      value['version'] != 1 ||
      value['id'] is! String ||
      (value['id'] as String).isEmpty) {
    throw const WorkspaceFailure('Vault identity or format is unsupported.');
  }
  return VaultCandidate(
    path: root,
    id: value['id'] as String,
    name: value['name'] is String ? value['name'] as String : p.basename(root),
  );
}

/// Only explicit locations and immediate child directories; never a disk crawl.
Future<VaultDiscovery> discoverVaults(
  List<String> paths, {
  bool children = false,
}) async {
  final vaults = <VaultCandidate>[], warnings = <String>[];
  Future<void> inspect(String path, {bool explicit = false}) async {
    try {
      final v = await _inspect(path);
      if (v == null) {
        if (explicit) warnings.add('No supported Orbit Vault at $path');
      } else if (!vaults.any((e) => vaultPathsEqual(e.path, v.path))) {
        vaults.add(v);
      }
    } on Object {
      warnings.add(
        'Could not inspect Vault at $path. Its files were preserved.',
      );
    }
  }

  for (final path in paths.take(256)) {
    await inspect(path, explicit: !children);
    if (children) {
      try {
        if (await FileSystemEntity.type(path, followLinks: false) !=
            FileSystemEntityType.directory) {
          warnings.add(
            'Choose an ordinary folder rather than a folder link: $path',
          );
          continue;
        }
        var count = 0;
        await for (final entity in Directory(path).list(followLinks: false)) {
          if (entity is! Directory) continue;
          if (++count > 512) {
            warnings.add(
              'Stopped after 512 folders in $path. Choose a smaller folder.',
            );
            break;
          }
          await inspect(entity.path);
        }
      } on Object {
        warnings.add('Could not list $path. Choose an accessible folder.');
      }
    }
  }
  return VaultDiscovery(vaults, warnings);
}

Future<WorkspaceRepository> openExistingVault(VaultCandidate vault) async {
  final repo = WorkspaceRepository(
    store: NativeWorkspaceStore(existingWorkspaceId: vault.id),
    index: MemoryObjectIndex(),
  );
  try {
    await repo.initialize(path: vault.path);
    return repo;
  } on Object {
    await repo.close();
    rethrow;
  }
}

Future<void> rememberDownloadedVault(String path) =>
    NativeWorkspaceStore(rememberWorkspace: true).rememberRecentLocation(path);
