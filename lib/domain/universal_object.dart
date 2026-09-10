import 'dart:collection';

/// One identity shared by every presentation of user knowledge.
class UniversalObject {
  UniversalObject({
    required this.id,
    required this.workspaceId,
    required this.typeId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.body = '',
    this.schemaVersion = 1,
    this.revision = 1,
    this.deletedAt,
    Map<String, dynamic> properties = const {},
    Map<String, dynamic> data = const {},
    Map<String, dynamic> extra = const {},
    Map<String, dynamic> documentExtra = const {},
    this.formatVersion = 1,
  }) : properties = _freezeMap(properties),
       data = _freezeMap(data),
       extra = _freezeMap(extra),
       documentExtra = _freezeMap(documentExtra);

  final String id;
  final String workspaceId;
  final String typeId;
  final String title;
  final String body;
  final int schemaVersion;
  final int formatVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;
  final DateTime? deletedAt;
  final Map<String, dynamic> properties;
  final Map<String, dynamic> data;
  final Map<String, dynamic> extra;
  final Map<String, dynamic> documentExtra;

  bool get isDeleted => deletedAt != null;
  bool get isReadOnly => schemaVersion != 1 || formatVersion != 1;
  bool get isCompleted => properties['completed'] == true;
  Map<String, String> get linkBindings => {
    if (properties['orbitLinkBindings'] is Map)
      for (final entry in (properties['orbitLinkBindings'] as Map).entries)
        if (entry.key is String && entry.value is String)
          entry.key as String: entry.value as String,
  };

  UniversalObject copyWith({
    String? title,
    String? body,
    DateTime? updatedAt,
    int? revision,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    Map<String, dynamic>? properties,
    Map<String, dynamic>? data,
  }) => UniversalObject(
    id: id,
    workspaceId: workspaceId,
    typeId: typeId,
    title: title ?? this.title,
    body: body ?? this.body,
    schemaVersion: schemaVersion,
    formatVersion: formatVersion,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    revision: revision ?? this.revision,
    deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
    properties: properties ?? this.properties,
    data: data ?? this.data,
    extra: extra,
    documentExtra: documentExtra,
  );

  Map<String, dynamic> toJson() => {
    ...extra,
    'id': id,
    'workspaceId': workspaceId,
    'typeId': typeId,
    'schemaVersion': schemaVersion,
    'title': title,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'revision': revision,
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
    'properties': properties,
  };

  factory UniversalObject.fromJson(
    Map<String, dynamic> json, {
    String? workspaceId,
    String body = '',
    Map<String, dynamic> data = const {},
    Map<String, dynamic> documentExtra = const {},
    int formatVersion = 1,
  }) {
    const known = {
      'id',
      'workspaceId',
      'typeId',
      'schemaVersion',
      'title',
      'createdAt',
      'updatedAt',
      'revision',
      'deletedAt',
      'properties',
    };
    final id = json['id'];
    final type = json['typeId'];
    if (id is! String || id.isEmpty || type is! String || type.isEmpty) {
      throw const FormatException('Object identity or type is missing.');
    }
    return UniversalObject(
      id: id,
      workspaceId: workspaceId ?? json['workspaceId'] as String,
      typeId: type,
      title: json['title'] as String? ?? 'Untitled',
      body: body,
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      formatVersion: formatVersion,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      revision: json['revision'] as int? ?? 1,
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String).toUtc(),
      properties: Map<String, dynamic>.from(json['properties'] as Map? ?? {}),
      data: data,
      extra: Map.fromEntries(json.entries.where((e) => !known.contains(e.key))),
      documentExtra: documentExtra,
    );
  }
}

class _FrozenMap extends UnmodifiableMapView<String, dynamic> {
  _FrozenMap(super.map);
}

Map<String, dynamic> _freezeMap(Map<String, dynamic> map) => map is _FrozenMap
    ? map
    : _FrozenMap(map.map((key, value) => MapEntry(key, _freeze(value))));

dynamic _freeze(dynamic value) {
  if (value is _FrozenMap) return value;
  if (value is Map) {
    return _freezeMap(Map<String, dynamic>.from(value));
  }
  if (value is List) return List<dynamic>.unmodifiable(value.map(_freeze));
  return value;
}
