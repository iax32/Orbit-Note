import 'dart:typed_data';

/// Private presentation recipe, never an attachment or a network URL.
class WritingPhoto {
  const WritingPhoto({
    required this.id,
    this.name = 'Personal photo',
    this.opacity = .65,
    this.x = 0,
    this.y = 0,
    this.contain = false,
    this.readingSheet = true,
  });
  final String id, name;
  final double opacity, x, y;
  final bool contain, readingSheet;
  static const maxBytes = 2 * 1024 * 1024;
  static bool validId(Object? id) =>
      id is String && RegExp(r'^[a-f0-9]{64}$').hasMatch(id);

  static WritingPhoto? fromData(Object? value) {
    if (value is! Map || value['version'] != 1 || !validId(value['id'])) {
      return null;
    }
    double number(String key, double fallback, double min, double max) {
      final n = value[key];
      return n is num && n.isFinite && n >= min && n <= max
          ? n.toDouble()
          : fallback;
    }

    final name = value['name'];
    return WritingPhoto(
      id: value['id'] as String,
      name: name is String && name.isNotEmpty && name.length <= 120
          ? name.replaceAll(RegExp(r'[\x00-\x1f]'), ' ')
          : 'Personal photo',
      opacity: number('opacity', .65, 0, 1),
      x: number('x', 0, -1, 1),
      y: number('y', 0, -1, 1),
      contain: value['fit'] == 'contain',
      readingSheet: value['readingSheet'] != false,
    );
  }

  WritingPhoto copyWith({
    double? opacity,
    double? x,
    double? y,
    bool? contain,
    bool? readingSheet,
  }) => WritingPhoto(
    id: id,
    name: name,
    opacity: opacity ?? this.opacity,
    x: x ?? this.x,
    y: y ?? this.y,
    contain: contain ?? this.contain,
    readingSheet: readingSheet ?? this.readingSheet,
  );
  Map<String, dynamic> toData({Object? original}) => {
    if (original is Map)
      for (final entry in original.entries)
        if (entry.key is String) entry.key as String: entry.value,
    'version': 1,
    'id': id,
    'name': name,
    'opacity': opacity,
    'x': x,
    'y': y,
    'fit': contain ? 'contain' : 'cover',
    'readingSheet': readingSheet,
  };
  @override
  bool operator ==(Object other) =>
      other is WritingPhoto &&
      other.id == id &&
      other.name == name &&
      other.opacity == opacity &&
      other.x == x &&
      other.y == y &&
      other.contain == contain &&
      other.readingSheet == readingSheet;
  @override
  int get hashCode =>
      Object.hash(id, name, opacity, x, y, contain, readingSheet);
}

/// Only small normalized PNGs belong in the private photo cache.
void validateWritingPhotoBytes(Uint8List bytes) {
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < 33 ||
      bytes.length > WritingPhoto.maxBytes ||
      List.generate(8, (i) => bytes[i] == signature[i]).contains(false) ||
      bytes[12] != 73 ||
      bytes[13] != 72 ||
      bytes[14] != 68 ||
      bytes[15] != 82) {
    throw const FormatException(
      'Choose a supported photo up to 2 MiB after resizing.',
    );
  }
  final data = ByteData.sublistView(bytes);
  final w = data.getUint32(16), h = data.getUint32(20);
  if (data.getUint32(8) != 13 ||
      w == 0 ||
      h == 0 ||
      w > 1600 ||
      h > 1600 ||
      bytes[26] != 0 ||
      bytes[27] != 0 ||
      bytes[28] > 1) {
    throw const FormatException(
      'Background photo dimensions or PNG header are invalid.',
    );
  }
}
