/// Domain model representing a bounded work, study, or reading session
/// with honest elapsed active-time tracking and local activity records.
/// Conforms to CTX-04, CTX-05, CTX-06, CTX-07, CTX-11, and CTX-12.
class WorkSessionRecord {
  WorkSessionRecord({
    required this.id,
    required this.title,
    this.category = 'work',
    required this.startedAt,
    this.endedAt,
    this.isPaused = false,
    this.lastPausedAt,
    this.totalPausedDuration = Duration.zero,
    List<String>? notesOpened,
    List<String>? notesCreated,
    List<String>? tasksCompleted,
    this.continuationNote = '',
  }) : notesOpened = List.unmodifiable(notesOpened ?? const []),
       notesCreated = List.unmodifiable(notesCreated ?? const []),
       tasksCompleted = List.unmodifiable(tasksCompleted ?? const []);

  final String id;
  final String title;
  final String category; // 'work', 'study', 'reading', 'general'
  final DateTime startedAt;
  final DateTime? endedAt;
  final bool isPaused;
  final DateTime? lastPausedAt;
  final Duration totalPausedDuration;
  final List<String> notesOpened;
  final List<String> notesCreated;
  final List<String> tasksCompleted;
  final String continuationNote;

  bool get isRecordingActive => !isPaused && endedAt == null;
  bool get isEnded => endedAt != null;

  /// Computes honest elapsed active duration without inventing unrecorded focus time.
  Duration elapsedActiveDuration([DateTime? now]) {
    final current = now ?? DateTime.now();
    if (endedAt != null) {
      final total = endedAt!.difference(startedAt) - totalPausedDuration;
      return total.isNegative ? Duration.zero : total;
    }
    if (isPaused && lastPausedAt != null) {
      final total = lastPausedAt!.difference(startedAt) - totalPausedDuration;
      return total.isNegative ? Duration.zero : total;
    }
    final total = current.difference(startedAt) - totalPausedDuration;
    return total.isNegative ? Duration.zero : total;
  }

  /// Pauses recording and captures the pause timestamp.
  WorkSessionRecord pause([DateTime? now]) {
    if (isPaused || isEnded) return this;
    final pauseTime = now ?? DateTime.now();
    return copyWith(isPaused: true, lastPausedAt: pauseTime);
  }

  /// Resumes recording, accumulating paused time into [totalPausedDuration].
  WorkSessionRecord resume([DateTime? now]) {
    if (!isPaused || isEnded) return this;
    final resumeTime = now ?? DateTime.now();
    final additionalPaused = lastPausedAt != null
        ? resumeTime.difference(lastPausedAt!)
        : Duration.zero;
    return copyWith(
      isPaused: false,
      clearLastPausedAt: true,
      totalPausedDuration: totalPausedDuration + additionalPaused,
    );
  }

  /// Ends the work session, closing the active interval.
  WorkSessionRecord end([DateTime? now, String? finalContinuationNote]) {
    if (isEnded) return this;
    final endTime = now ?? DateTime.now();
    var finalPaused = totalPausedDuration;
    if (isPaused && lastPausedAt != null) {
      finalPaused += endTime.difference(lastPausedAt!);
    }
    return copyWith(
      isPaused: false,
      clearLastPausedAt: true,
      endedAt: endTime,
      totalPausedDuration: finalPaused,
      continuationNote: finalContinuationNote ?? continuationNote,
    );
  }

  /// Records note opening if and only if recording is currently active.
  WorkSessionRecord recordOpen(String noteId) {
    if (!isRecordingActive || notesOpened.contains(noteId)) return this;
    return copyWith(notesOpened: [...notesOpened, noteId]);
  }

  /// Records note creation if and only if recording is currently active.
  WorkSessionRecord recordCreate(String noteId) {
    if (!isRecordingActive || notesCreated.contains(noteId)) return this;
    return copyWith(notesCreated: [...notesCreated, noteId]);
  }

  /// Records task completion if and only if recording is currently active.
  WorkSessionRecord recordTaskCompleted(String taskId) {
    if (!isRecordingActive || tasksCompleted.contains(taskId)) return this;
    return copyWith(tasksCompleted: [...tasksCompleted, taskId]);
  }

  WorkSessionRecord copyWith({
    String? title,
    String? category,
    DateTime? endedAt,
    bool? isPaused,
    DateTime? lastPausedAt,
    bool clearLastPausedAt = false,
    Duration? totalPausedDuration,
    List<String>? notesOpened,
    List<String>? notesCreated,
    List<String>? tasksCompleted,
    String? continuationNote,
  }) {
    return WorkSessionRecord(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      isPaused: isPaused ?? this.isPaused,
      lastPausedAt: clearLastPausedAt
          ? null
          : (lastPausedAt ?? this.lastPausedAt),
      totalPausedDuration: totalPausedDuration ?? this.totalPausedDuration,
      notesOpened: notesOpened ?? this.notesOpened,
      notesCreated: notesCreated ?? this.notesCreated,
      tasksCompleted: tasksCompleted ?? this.tasksCompleted,
      continuationNote: continuationNote ?? this.continuationNote,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'startedAt': startedAt.toIso8601String(),
    if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
    'isPaused': isPaused,
    if (lastPausedAt != null) 'lastPausedAt': lastPausedAt!.toIso8601String(),
    'totalPausedDurationMs': totalPausedDuration.inMilliseconds,
    'notesOpened': notesOpened,
    'notesCreated': notesCreated,
    'tasksCompleted': tasksCompleted,
    'continuationNote': continuationNote,
  };

  factory WorkSessionRecord.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return fallback;
    }

    List<String> parseList(dynamic val) {
      if (val is List) {
        return val.whereType<String>().toList();
      }
      return const [];
    }

    final now = DateTime.now();
    final startedAt = parseDate(json['startedAt'], now);
    final endedAt = json['endedAt'] != null
        ? parseDate(json['endedAt'], startedAt)
        : null;
    final lastPausedAt = json['lastPausedAt'] != null
        ? parseDate(json['lastPausedAt'], startedAt)
        : null;
    final pausedMs = json['totalPausedDurationMs'] is num
        ? (json['totalPausedDurationMs'] as num).toInt()
        : 0;

    return WorkSessionRecord(
      id: json['id'] is String && (json['id'] as String).isNotEmpty
          ? json['id'] as String
          : 'session-${startedAt.millisecondsSinceEpoch}',
      title: json['title'] is String
          ? json['title'] as String
          : 'Focus Session',
      category:
          ['work', 'study', 'reading', 'general'].contains(json['category'])
          ? json['category'] as String
          : 'work',
      startedAt: startedAt,
      endedAt: endedAt,
      isPaused: json['isPaused'] == true,
      lastPausedAt: lastPausedAt,
      totalPausedDuration: Duration(milliseconds: pausedMs < 0 ? 0 : pausedMs),
      notesOpened: parseList(json['notesOpened']),
      notesCreated: parseList(json['notesCreated']),
      tasksCompleted: parseList(json['tasksCompleted']),
      continuationNote: json['continuationNote'] is String
          ? json['continuationNote'] as String
          : '',
    );
  }
}
