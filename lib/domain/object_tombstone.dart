/// Durable deletion identity, independent of transport and device clocks.
class ObjectTombstone {
  const ObjectTombstone({
    required this.workspaceId,
    required this.objectId,
    required this.operationId,
    required this.path,
    required this.beforeHash,
    required this.deletedAt,
  });

  final String workspaceId, objectId, operationId, path, beforeHash;
  final DateTime deletedAt;
  String get storagePath => '.orbit/tombstones/$objectId.json';

  Map<String, dynamic> toJson() => {
    'format': 'orbit-note-tombstone',
    'version': 1,
    'workspaceId': workspaceId,
    'objectId': objectId,
    'operationId': operationId,
    'path': path,
    'beforeHash': beforeHash,
    'deletedAt': deletedAt.toUtc().toIso8601String(),
  };

  factory ObjectTombstone.fromJson(Map<String, dynamic> json) {
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (json['format'] != 'orbit-note-tombstone' ||
        json['version'] != 1 ||
        !['workspaceId', 'objectId', 'operationId'].every(
          (key) => json[key] is String && uuid.hasMatch(json[key] as String),
        ) ||
        json['path'] is! String ||
        json['beforeHash'] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(json['beforeHash'] as String) ||
        json['deletedAt'] is! String) {
      throw const FormatException('Unsupported or invalid deletion record.');
    }
    return ObjectTombstone(
      workspaceId: json['workspaceId'] as String,
      objectId: json['objectId'] as String,
      operationId: json['operationId'] as String,
      path: json['path'] as String,
      beforeHash: json['beforeHash'] as String,
      deletedAt: DateTime.parse(json['deletedAt'] as String).toUtc(),
    );
  }
}
