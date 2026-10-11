/// Portable recognition evidence. Geometry uses normalized, top-left coordinates.
/// A correction keeps the original recognition, but intentionally drops its boxes.
class OcrDocument {
  static const maxCharacters = 2 * 1024 * 1024;
  static const maxPages = 500;
  static const maxLines = 20000;
  OcrDocument(this.path, this.checksum, this.language, this.pages) {
    validate(toJson());
  }
  final String path, checksum, language;
  final List<Map<String, dynamic>> pages;
  Map<String, dynamic> toJson() => {
    'version': 1,
    'path': path,
    'checksum': checksum,
    'language': language,
    'pages': pages,
  };
  static void validate(dynamic raw) {
    if (raw is! Map ||
        raw['version'] != 1 ||
        raw['path'] is! String ||
        !(raw['path'] as String).startsWith('Attachments/') ||
        raw['checksum'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(raw['checksum'] as String) ||
        raw['language'] is! String ||
        raw['pages'] is! List ||
        (raw['pages'] as List).isEmpty ||
        (raw['pages'] as List).length > maxPages) {
      throw const FormatException('Unsupported or invalid OCR record.');
    }
    var characters = 0;
    var lines = 0;
    for (final p in raw['pages'] as List) {
      if (p is! Map ||
          p['text'] is! String ||
          p['lines'] is! List ||
          (p['corrected'] != null && p['corrected'] is! String)) {
        throw const FormatException('Invalid OCR page.');
      }
      characters +=
          (p['text'] as String).length +
          ((p['corrected'] as String?)?.length ?? 0);
      if (characters > maxCharacters) {
        throw const FormatException('OCR exceeds the 2 Mi-character limit.');
      }
      lines += (p['lines'] as List).length;
      if (lines > maxLines) {
        throw const FormatException('OCR exceeds the 20,000-line limit.');
      }
      for (final line in p['lines'] as List) {
        if (line is! Map ||
            line['start'] is! int ||
            line['end'] is! int ||
            line['start'] < 0 ||
            line['end'] <= line['start'] ||
            line['end'] > (p['text'] as String).length ||
            !['x', 'y', 'width', 'height'].every(
              (key) =>
                  line[key] is num &&
                  (line[key] as num).isFinite &&
                  line[key] >= 0 &&
                  line[key] <= 1,
            ) ||
            line['x'] + line['width'] > 1.00001 ||
            line['y'] + line['height'] > 1.00001) {
          throw const FormatException('Invalid OCR source geometry.');
        }
      }
    }
  }

  static OcrDocument? parse(dynamic raw) {
    try {
      validate(raw);
      final map = raw as Map;
      return OcrDocument(map['path'], map['checksum'], map['language'], [
        for (final page in map['pages'] as List)
          Map<String, dynamic>.from(page as Map),
      ]);
    } on Object {
      return null;
    }
  }

  String text(int page) =>
      (pages[page]['corrected'] ?? pages[page]['text']) as String;
  List<Map<String, double>> regions(int page, int start, int end) => [
    if (pages[page]['corrected'] == null)
      for (final line in pages[page]['lines'] as List)
        if (line['start'] < end && line['end'] > start)
          {
            for (final key in ['x', 'y', 'width', 'height'])
              key: (line[key] as num).toDouble(),
          },
  ];
}
