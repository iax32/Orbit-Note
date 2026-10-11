import '../../../domain/universal_object.dart';

/// Presentation model and metadata for a PDF or eBook in Orbit Note's personal library.
class PdfBookMeta {
  PdfBookMeta({
    required this.id,
    required this.title,
    this.author = '',
    this.totalPages = 1,
    this.lastReadPage = 1,
    this.progress = 0.0,
    this.isFavorite = false,
    this.shelf = 'Currently Reading',
    this.readingTimeMinutes = 0,
    this.bookmarksCount = 0,
    this.notesCount = 0,
    this.lastRoomId = 'rainy_library',
    this.coverColor = 0xFF8B7CF6,
  });

  final String id;
  final String title;
  final String author;
  final int totalPages;
  final int lastReadPage;
  final double progress; // 0.0 to 1.0
  final bool isFavorite;
  final String shelf;
  final int readingTimeMinutes;
  final int bookmarksCount;
  final int notesCount;
  final String lastRoomId;
  final int coverColor;

  bool get isFinished => progress >= 0.99 || shelf.toLowerCase() == 'finished';
  bool get hasStarted => lastReadPage > 1 || progress > 0.05;

  String get formattedReadingTime {
    if (readingTimeMinutes <= 0) return '0m';
    if (readingTimeMinutes < 60) return '${readingTimeMinutes}m';
    final hours = readingTimeMinutes ~/ 60;
    final mins = readingTimeMinutes % 60;
    return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
  }

  /// Extracts metadata from an existing UniversalObject representing an orbit.file PDF.
  factory PdfBookMeta.fromObject(UniversalObject object, {int? currentPage}) {
    final props = object.properties;
    int number(Object? value, int fallback) =>
        value is num && value.isFinite && value >= 0 ? value.toInt() : fallback;
    final rawPages = props['pageCount'] ?? props['totalPages'];
    final knownPages = rawPages is num && rawPages.isFinite && rawPages > 0;
    final totalPages = knownPages ? number(rawPages, 1) : 1;

    final hasExplicitPage = currentPage != null || props['lastReadPage'] is num;
    final page = number(
      currentPage ?? props['lastReadPage'],
      1,
    ).clamp(1, 0x7fffffff);
    final lastReadPage = knownPages
        ? page.clamp(1, totalPages.clamp(1, 0x7fffffff))
        : page;

    final progress = hasExplicitPage && knownPages && totalPages > 0
        ? (lastReadPage / totalPages).clamp(0.0, 1.0)
        : 0.0;

    final isFav = props['isFavorite'] == true;

    final shelf =
        (props['shelf'] is String && (props['shelf'] as String).isNotEmpty)
        ? props['shelf'] as String
        : (progress >= 0.99 ? 'Finished' : 'Currently Reading');

    final readingTime = number(props['readingTimeMinutes'], 0);

    final bookmarks = (props['pdfBookmarks'] is List)
        ? (props['pdfBookmarks'] as List)
              .whereType<int>()
              .where((p) => p > 0)
              .length
        : (props['bookmarks'] is List)
        ? (props['bookmarks'] as List)
              .whereType<int>()
              .where((p) => p > 0)
              .length
        : 0;

    final notes = number(props['notesCount'], 0);

    final lastRoom = (props['lastRoomId'] is String)
        ? props['lastRoomId'] as String
        : 'rainy_library';

    final author =
        (props['author'] is String &&
            (props['author'] as String).trim().isNotEmpty)
        ? props['author'] as String
        : 'Unknown Author';

    final coverColor = (props['coverColor'] is int)
        ? props['coverColor'] as int
        : 0xFF8B7CF6;

    final cleanTitle = object.title.replaceFirst(
      RegExp(r'\.pdf$', caseSensitive: false),
      '',
    );

    return PdfBookMeta(
      id: object.id,
      title: cleanTitle.isEmpty ? 'Untitled Document' : cleanTitle,
      author: author,
      totalPages: totalPages,
      lastReadPage: lastReadPage,
      progress: progress,
      isFavorite: isFav,
      shelf: shelf,
      readingTimeMinutes: readingTime,
      bookmarksCount: bookmarks,
      notesCount: notes,
      lastRoomId: lastRoom,
      coverColor: coverColor,
    );
  }

  /// Serializes updated metadata into property dictionary for saving.
  Map<String, dynamic> toProperties() {
    return {
      'totalPages': totalPages,
      'lastReadPage': lastReadPage,
      'isFavorite': isFavorite,
      'shelf': shelf,
      'readingTimeMinutes': readingTimeMinutes,
      'lastRoomId': lastRoomId,
      'author': author,
    };
  }
}
