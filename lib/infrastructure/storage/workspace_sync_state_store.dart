import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../application/sync/sync_provider.dart';
import '../../domain/workspace_failure.dart';
import 'workspace_store.dart';

/// Device-only operational state; independent of FTS rebuild and content export.
/// The caller must own the workspace and one SyncEngine for this state file.
class WorkspaceSyncStateStore implements SyncStateStore {
  WorkspaceSyncStateStore(this.store);
  final WorkspaceStore store;
  static const path = '.orbit/device/sync/state-v1.json';
  String? _expectedHash;
  bool _loaded = false;

  @override
  Future<Map<String, dynamic>?> load() async {
    final bytes = await store.read(path);
    if (bytes != null && bytes.length > 16 * 1024 * 1024) {
      throw const WorkspaceFailure(
        'Sync state exceeds the current safe size limit.',
      );
    }
    final state = bytes == null
        ? null
        : jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    _expectedHash = bytes == null ? null : sha256.convert(bytes).toString();
    _loaded = true;
    return state;
  }

  @override
  Future<void> save(Map<String, dynamic> state) async {
    if (!_loaded) throw StateError('Load sync state before writing it.');
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(state)));
    if (bytes.length > 16 * 1024 * 1024) {
      throw const WorkspaceFailure(
        'Sync state exceeds the current safe size limit.',
      );
    }
    await store.write(path, bytes, expectedHash: _expectedHash);
    _expectedHash = sha256.convert(bytes).toString();
  }
}
