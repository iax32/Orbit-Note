/// Portable metadata for one authored entry. Provider IDs never become object IDs.
class SyncEntry {
  const SyncEntry({
    required this.key,
    required this.path,
    required this.hash,
    this.deleted = false,
  });
  final String key, path, hash;
  final bool deleted;

  bool sameAs(SyncEntry? other) =>
      other != null &&
      key == other.key &&
      path == other.path &&
      hash == other.hash &&
      deleted == other.deleted;

  Map<String, dynamic> toJson() => {
    'key': key,
    'path': path,
    'hash': hash,
    'deleted': deleted,
  };
  factory SyncEntry.fromJson(Map<String, dynamic> json) {
    if (json['key'] is! String ||
        (json['key'] as String).isEmpty ||
        json['path'] is! String ||
        json['hash'] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(json['hash'] as String) ||
        json['deleted'] is! bool) {
      throw const FormatException('Invalid sync entry.');
    }
    return SyncEntry(
      key: json['key'] as String,
      path: json['path'] as String,
      hash: json['hash'] as String,
      deleted: json['deleted'] as bool,
    );
  }
}

enum SyncAction { unchanged, acknowledge, upload, download, conflict, missing }

/// Missing is not a deletion. Time and local revision numbers cannot pick a winner.
SyncAction reconcileSyncEntry({
  SyncEntry? base,
  SyncEntry? local,
  SyncEntry? remote,
}) {
  if (local == null && remote == null) {
    return base == null ? SyncAction.unchanged : SyncAction.missing;
  }
  if (local?.sameAs(remote) == true) {
    return local!.sameAs(base) ? SyncAction.unchanged : SyncAction.acknowledge;
  }
  if (base == null) {
    if (local == null) return SyncAction.download;
    if (remote == null) return SyncAction.upload;
    return SyncAction.conflict;
  }
  if (local == null || remote == null) return SyncAction.missing;
  if (local.sameAs(base)) return SyncAction.download;
  if (remote.sameAs(base)) return SyncAction.upload;
  return SyncAction.conflict;
}
