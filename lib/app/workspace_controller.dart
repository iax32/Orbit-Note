import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/workspace_repository.dart';
import '../domain/calendar_event.dart';
import '../domain/universal_object.dart';
import '../domain/object_reference.dart';
import '../domain/pdf_annotation.dart';
import '../domain/research_document.dart';
import '../canvas/scene.dart';
import '../domain/wiki_links.dart';
import '../domain/search_text.dart';
import '../domain/work_session.dart';
import 'session_state.dart';

final repositoryProvider = Provider<WorkspaceRepository>(
  (ref) => WorkspaceRepository(),
);
final workspaceProvider = NotifierProvider<WorkspaceController, int>(
  WorkspaceController.new,
);

/// Coordinates drafts and serialized durable commands. UI never writes files.
class WorkspaceController extends Notifier<int> {
  late WorkspaceRepository repository;
  SessionState session = SessionState();
  List<UniversalObject> objects = [];
  bool loading = true;
  String? error;
  final Set<String> dirty = {};
  final Map<String, String> failures = {};
  final Map<String, Timer> _timers = {};
  final Map<String, Future<void>> _saving = {};
  Timer? _sessionTimer;
  bool _alive = true;
  bool savingSettings = false;
  Future<void>? _settingsSave;
  bool _settingsSaveRequested = false;
  bool _settingsSaveFailed = false;
  bool _hasWorkspace = false;
  bool get hasWorkspace => _hasWorkspace;

  WorkSessionRecord? _activeWorkSession;
  WorkSessionRecord? get activeWorkSession => _activeWorkSession;

  List<WorkSessionRecord> get completedWorkSessions {
    return [
      for (final raw in session.completedWorkSessions)
        WorkSessionRecord.fromJson(raw),
    ];
  }

  void _syncWorkSessionToSessionState() {
    session.activeWorkSession = _activeWorkSession?.toJson();
    persistSession();
    notify();
  }

  void startWorkSession({String? title, String category = 'work'}) {
    final now = DateTime.now();
    _activeWorkSession = WorkSessionRecord(
      id: 'session-${now.millisecondsSinceEpoch}',
      title: (title != null && title.trim().isNotEmpty)
          ? title.trim()
          : 'Focus Session',
      category: category,
      startedAt: now,
    );
    _syncWorkSessionToSessionState();
  }

  void pauseWorkSession() {
    if (_activeWorkSession == null || !_activeWorkSession!.isRecordingActive) {
      return;
    }
    _activeWorkSession = _activeWorkSession!.pause();
    _syncWorkSessionToSessionState();
  }

  void resumeWorkSession() {
    if (_activeWorkSession == null || !_activeWorkSession!.isPaused) return;
    _activeWorkSession = _activeWorkSession!.resume();
    _syncWorkSessionToSessionState();
  }

  void setWorkSessionContinuationNote(String note) {
    if (_activeWorkSession == null) return;
    _activeWorkSession = _activeWorkSession!.copyWith(continuationNote: note);
    _syncWorkSessionToSessionState();
  }

  WorkSessionRecord? endWorkSession({String? continuationNote}) {
    if (_activeWorkSession == null) return null;
    final completed = _activeWorkSession!.end(DateTime.now(), continuationNote);
    session.completedWorkSessions = [
      completed.toJson(),
      ...session.completedWorkSessions,
    ].take(30).toList();
    _activeWorkSession = null;
    session.activeWorkSession = null;
    persistSession();
    notify();
    return completed;
  }

  /// Constructed for a single Vault opening. The eventual sync coordinator must
  /// discard this adapter on switch; the repository generation also enforces it.
  WorkspaceSyncReplica createSyncReplica() => WorkspaceSyncReplica(
    repository,
    canApply: () =>
        _alive &&
        _hasWorkspace &&
        !loading &&
        dirty.isEmpty &&
        _saving.isEmpty &&
        failures.isEmpty,
    onApplied: () {
      mergeRepositoryObjects();
      notify();
    },
  );
  String? lastClosed;
  bool externalChangesPending = false;
  bool _checkingExternal = false;
  bool _refreshingExternal = false;
  StreamSubscription<String>? _externalSubscription;
  Timer? _externalDebounce;
  final Set<String> _changedPaths = {};

  @override
  int build() {
    repository = ref.read(repositoryProvider);
    ref.onDispose(() {
      _alive = false;
      for (final timer in _timers.values) {
        timer.cancel();
      }
      _sessionTimer?.cancel();
      _externalDebounce?.cancel();
      unawaited(_externalSubscription?.cancel());
      // The shell flushes before workspace switches and native exit.
      unawaited(repository.close());
    });
    Future.microtask(initialize);
    return 0;
  }

  void notify() {
    if (_alive) state++;
  }

  void mergeRepositoryObjects() {
    final drafts = {
      for (final o in objects)
        if (dirty.contains(o.id)) o.id: o,
    };
    final present = repository.objects.map((o) => o.id).toSet();
    objects = [
      for (final o in repository.objects) drafts[o.id] ?? o,
      for (final o in drafts.values)
        if (!present.contains(o.id)) o,
    ];
  }

  List<UniversalObject> get activeObjects =>
      objects.where((o) => !o.isDeleted).toList();
  List<UniversalObject> ofType(String type) =>
      activeObjects.where((o) => o.typeId == type).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  UniversalObject? find(String? id) {
    for (final object in objects) {
      if (object.id == id) return object;
    }
    return null;
  }

  List<NoteLinkTarget> get linkTargets => activeObjects
      .map(
        (o) => NoteLinkTarget(
          id: o.id,
          title: o.title,
          aliases: o.properties['aliases'] is List
              ? (o.properties['aliases'] as List).whereType<String>().toList()
              : const [],
        ),
      )
      .toList();
  Future<List<UniversalObject>> search(String query) async {
    final indexed = await repository.search(query);
    final indexOrder = {
      for (var i = 0; i < indexed.length; i++) indexed[i].id: i,
    };
    final results = [
      ...indexed.where((o) => !dirty.contains(o.id)),
      ...activeObjects.where(
        (o) =>
            dirty.contains(o.id) &&
            searchableText(o).toLowerCase().contains(query.toLowerCase()),
      ),
    ];
    results.sort((a, b) {
      final rank = searchRank(a, query).compareTo(searchRank(b, query));
      if (rank != 0) return rank;
      final aDraft = dirty.contains(a.id), bDraft = dirty.contains(b.id);
      if (aDraft != bDraft) return aDraft ? -1 : 1;
      if (!aDraft) return indexOrder[a.id]!.compareTo(indexOrder[b.id]!);
      return a.title.compareTo(b.title);
    });
    return results.take(100).toList();
  }

  List<UniversalObject> backlinks(String id) => activeObjects
      .where(
        (o) => parseWikiLinks(o.body).any(
          (link) =>
              resolveWikiLink(
                link,
                linkTargets,
                bindings: o.linkBindings,
              ).target?.id ==
              id,
        ),
      )
      .toList();
  String get saveLabel => failures.isNotEmpty
      ? 'Changes need attention'
      : dirty.isNotEmpty
      ? 'Saving locally…'
      : 'Saved locally';

  Future<void>? _initializingFuture;
  Future<void> initialize({String? path}) async {
    if (!_alive) return;
    if (_initializingFuture != null) {
      await _initializingFuture!;
      if (path == null) return;
    }
    final future = _doInitialize(path: path);
    _initializingFuture = future;
    try {
      await future;
    } finally {
      if (_initializingFuture == future) {
        _initializingFuture = null;
      }
    }
  }

  Future<void> _doInitialize({String? path}) async {
    final previousPath = _hasWorkspace ? repository.location : null;
    final previousSession = session;
    if (_hasWorkspace && !await flushAll()) return;
    await _externalSubscription?.cancel();
    _externalDebounce?.cancel();
    _changedPaths.clear();
    loading = true;
    error = null;
    notify();
    try {
      await repository.initialize(path: path);
      mergeRepositoryObjects();
      session = SessionState.fromJson(await repository.readDeviceSettings());
      _activeWorkSession = session.activeWorkSession != null
          ? WorkSessionRecord.fromJson(session.activeWorkSession!)
          : null;
      session.tabs = session.tabs
          .where((id) => find(id) != null && !find(id)!.isDeleted)
          .toList();
      if (find(session.activeId)?.isDeleted != false) session.activeId = null;
      if (find(session.secondaryId)?.isDeleted != false) {
        session.secondaryId = null;
      }
      // Home offers an explicit continuation into the recorded context.
      session.destination = OrbitDestination.home;
      _hasWorkspace = true;
    } catch (e) {
      error = '$e';
      if (previousPath != null) {
        try {
          await repository.initialize(path: previousPath);
          objects = List.of(repository.objects);
          session = previousSession;
          error =
              'Could not open that workspace. Your previous workspace is still open: $e';
        } catch (recoveryError) {
          _hasWorkspace = false;
          objects = [];
          error =
              'Could not open either workspace: $e. Reopening the previous workspace failed: $recoveryError';
        }
      }
    }
    loading = false;
    if (_hasWorkspace) {
      _externalSubscription = repository.externalFileChanges.listen(
        (path) {
          _changedPaths.add(path);
          _externalDebounce?.cancel();
          _externalDebounce = Timer(const Duration(milliseconds: 400), () {
            final paths = Set<String>.of(_changedPaths);
            _changedPaths.clear();
            checkExternalChanges(changedPaths: paths);
          });
        },
        onError: (Object e) {
          error =
              'File watching is unavailable. Recheck on app focus or use Reload from files. $e';
          notify();
        },
      );
    }
    notify();
  }

  void navigate(OrbitDestination destination) {
    session.destination = destination;
    if (destination == OrbitDestination.notes ||
        destination == OrbitDestination.canvas ||
        destination == OrbitDestination.tasks ||
        destination == OrbitDestination.calendar) {
      session.activeId = null;
    }
    persistSession();
    notify();
  }

  Future<bool> closeWorkspace() async {
    if (!await flushAll()) return false;
    await repository.clearSelection();
    await _externalSubscription?.cancel();
    _externalDebounce?.cancel();
    await repository.close();
    _hasWorkspace = false;
    objects = [];
    session = SessionState();
    error = null;
    notify();
    return true;
  }

  Future<void> renameWorkspace(String name) async {
    if (!await flushAll()) return;
    try {
      await repository.renameWorkspace(name);
      error = null;
    } catch (e) {
      error = '$e';
    }
    notify();
  }

  Future<bool> organize(Future<void> Function() command) async {
    if (loading) return false;
    if (!await flushAll()) return false;
    loading = true;
    notify();
    try {
      await command();
      mergeRepositoryObjects();
      error = null;
    } catch (e) {
      mergeRepositoryObjects();
      error = '$e';
    } finally {
      loading = false;
    }
    notify();
    return error == null;
  }

  final List<String> _navHistory = [];
  int _navIndex = -1;
  bool _navigatingHistory = false;

  bool get canNavigateBack => _navIndex > 0;
  bool get canNavigateForward =>
      _navIndex >= 0 && _navIndex < _navHistory.length - 1;

  void navigateBack() {
    if (!canNavigateBack) return;
    _navIndex--;
    _navigatingHistory = true;
    openObject(_navHistory[_navIndex]);
    _navigatingHistory = false;
    notify();
  }

  void navigateForward() {
    if (!canNavigateForward) return;
    _navIndex++;
    _navigatingHistory = true;
    openObject(_navHistory[_navIndex]);
    _navigatingHistory = false;
    notify();
  }

  void openObject(String id, {bool secondary = false}) {
    final object = find(id);
    if (object == null || object.isDeleted) return;
    final path = repository.objectPath(id);
    final folderProp = object.properties['folder'] as String?;
    final targetPaths = <String>[
      ?path,
      if (folderProp != null && folderProp.isNotEmpty) ...[
        folderProp,
        if (!folderProp.startsWith('Notes/')) 'Notes/$folderProp',
      ],
    ];
    if (targetPaths.isNotEmpty) {
      session.collapsedFolders = session.collapsedFolders
          .where(
            (folder) => !targetPaths.any(
              (p) => p == folder || p.startsWith('$folder/'),
            ),
          )
          .toList();
    }
    if (secondary) {
      session.secondaryId = id;
    } else {
      session.activeId = id;
      if (!_navigatingHistory) {
        if (_navIndex >= 0 && _navIndex < _navHistory.length - 1) {
          _navHistory.removeRange(_navIndex + 1, _navHistory.length);
        }
        if (_navHistory.isEmpty || _navHistory.last != id) {
          _navHistory.add(id);
          if (_navHistory.length > 50) _navHistory.removeAt(0);
          _navIndex = _navHistory.length - 1;
        }
      }
    }
    session.tabs = {...session.tabs, id}.toList();
    session.recent = [
      id,
      ...session.recent.where((v) => v != id),
    ].take(20).toList();
    if (_activeWorkSession != null && _activeWorkSession!.isRecordingActive) {
      _activeWorkSession = _activeWorkSession!.recordOpen(id);
      session.activeWorkSession = _activeWorkSession!.toJson();
    }
    if (session.destination == OrbitDestination.notes) {
      session.destination = OrbitDestination.notes;
    } else if (session.destination == OrbitDestination.canvas &&
        object.typeId == 'orbit.canvas') {
      session.destination = OrbitDestination.canvas;
    } else if (object.properties['folder'] is String &&
        (object.properties['folder'] as String).isNotEmpty) {
      session.destination = OrbitDestination.notes;
    } else {
      session.destination = switch (object.typeId) {
        'orbit.canvas' => OrbitDestination.canvas,
        'orbit.task' => OrbitDestination.tasks,
        'orbit.event' => OrbitDestination.calendar,
        _ => OrbitDestination.notes,
      };
    }
    persistSession();
    notify();
  }

  bool isPinned(String id) => session.pinnedTabs.contains(id);

  void pinTab(String id) {
    if (!session.tabs.contains(id)) return;
    if (!session.pinnedTabs.contains(id)) {
      session.pinnedTabs.add(id);
    }
    final pinned = session.tabs
        .where((t) => session.pinnedTabs.contains(t))
        .toList();
    final unpinned = session.tabs
        .where((t) => !session.pinnedTabs.contains(t))
        .toList();
    session.tabs = [...pinned, ...unpinned];
    persistSession();
    notify();
  }

  void unpinTab(String id) {
    session.pinnedTabs.remove(id);
    final pinned = session.tabs
        .where((t) => session.pinnedTabs.contains(t))
        .toList();
    final unpinned = session.tabs
        .where((t) => !session.pinnedTabs.contains(t))
        .toList();
    session.tabs = [...pinned, ...unpinned];
    persistSession();
    notify();
  }

  void closeTab(String id) {
    if (dirty.contains(id)) flush(id);
    lastClosed = id;
    session.closedTabs.remove(id);
    session.closedTabs.add(id);
    if (session.closedTabs.length > 20) {
      session.closedTabs.removeAt(0);
    }
    session.pinnedTabs.remove(id);
    session.tabs = session.tabs.where((v) => v != id).toList();
    if (session.activeId == id) session.activeId = session.tabs.lastOrNull;
    if (session.secondaryId == id) session.secondaryId = null;
    if (session.secondaryId == session.activeId) session.secondaryId = null;
    persistSession();
    notify();
  }

  void closeOtherTabs(String id) {
    if (!session.tabs.contains(id)) return;
    final toClose = session.tabs
        .where((t) => t != id && !session.pinnedTabs.contains(t))
        .toList();
    for (final closing in toClose) {
      if (dirty.contains(closing)) {
        flush(closing);
      }
      session.closedTabs.remove(closing);
      session.closedTabs.add(closing);
    }
    while (session.closedTabs.length > 20) {
      session.closedTabs.removeAt(0);
    }
    session.tabs = session.tabs
        .where((t) => t == id || session.pinnedTabs.contains(t))
        .toList();
    session.activeId = id;
    if (session.secondaryId != null &&
        !session.tabs.contains(session.secondaryId)) {
      session.secondaryId = null;
    }
    if (session.secondaryId == session.activeId) session.secondaryId = null;
    persistSession();
    notify();
  }

  void closeTabsToTheRight(String id) {
    final index = session.tabs.indexOf(id);
    if (index < 0) return;
    final toClose = session.tabs
        .sublist(index + 1)
        .where((t) => !session.pinnedTabs.contains(t))
        .toList();
    for (final closing in toClose) {
      if (dirty.contains(closing)) {
        flush(closing);
      }
      session.closedTabs.remove(closing);
      session.closedTabs.add(closing);
    }
    while (session.closedTabs.length > 20) {
      session.closedTabs.removeAt(0);
    }
    session.tabs = session.tabs.where((t) => !toClose.contains(t)).toList();
    if (toClose.contains(session.activeId)) {
      session.activeId = id;
    }
    if (toClose.contains(session.secondaryId)) {
      session.secondaryId = null;
    }
    if (session.secondaryId == session.activeId) {
      session.secondaryId = null;
    }
    persistSession();
    notify();
  }

  bool reopenClosedTab() {
    while (session.closedTabs.isNotEmpty) {
      final candidateId = session.closedTabs.removeLast();
      final object = find(candidateId);
      if (object != null && !object.isDeleted) {
        if (!session.tabs.contains(candidateId)) {
          session.tabs.add(candidateId);
        }
        openObject(candidateId);
        persistSession();
        notify();
        return true;
      }
    }
    return false;
  }

  void cycleTab({bool reverse = false, bool secondary = false}) {
    if (session.tabs.isEmpty) return;
    final id = secondary ? session.secondaryId : session.activeId;
    final index = session.tabs.indexOf(id ?? '');
    final next = index < 0
        ? 0
        : (index + (reverse ? -1 : 1)) % session.tabs.length;
    openObject(session.tabs[next], secondary: secondary);
  }

  void reorderTab(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= session.tabs.length) return;
    final movingId = session.tabs[oldIndex];
    final isMovingPinned = session.pinnedTabs.contains(movingId);
    final pinnedCount = session.tabs
        .where((t) => session.pinnedTabs.contains(t))
        .length;

    int targetIndex = newIndex;
    if (isMovingPinned) {
      targetIndex = targetIndex.clamp(0, pinnedCount - 1);
    } else {
      targetIndex = targetIndex.clamp(pinnedCount, session.tabs.length - 1);
    }

    final tabs = List.of(session.tabs);
    tabs.insert(targetIndex, tabs.removeAt(oldIndex));
    session.tabs = tabs;
    persistSession();
    notify();
  }

  Future<UniversalObject?> openTodayNote() async {
    final now = DateTime.now();
    final dateSlug =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final existing = activeObjects.cast<UniversalObject?>().firstWhere(
      (o) =>
          o != null &&
          o.typeId == 'orbit.note' &&
          !o.isDeleted &&
          (o.title == dateSlug || o.properties['dailyDate'] == dateSlug),
      orElse: () => null,
    );
    if (existing != null) {
      openObject(existing.id);
      return existing;
    }
    final weekdayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final weekday = weekdayNames[now.weekday - 1];
    final month = monthNames[now.month - 1];
    final header = '# $weekday, $month ${now.day}, ${now.year}\n\n';
    return create(
      'orbit.note',
      title: dateSlug,
      body: header,
      properties: {'icon': '📅', 'dailyDate': dateSlug},
    );
  }

  Future<UniversalObject?> saveEvent({
    UniversalObject? original,
    required String title,
    required String body,
    required Map<String, dynamic> properties,
  }) async {
    if (!await flushAll()) {
      error = 'Resolve the pending save failure before saving this event.';
      notify();
      return null;
    }
    try {
      EventSchedule.fromProperties(properties);
      if (original != null &&
          (find(original.id)?.revision != original.revision ||
              find(original.id)?.isDeleted != false)) {
        error =
            'This event changed while you were editing. Reopen it to review the latest version.';
        notify();
        return null;
      }
      final saved = original == null
          ? await repository.create(
              typeId: 'orbit.event',
              title: title,
              body: body,
              properties: properties,
            )
          : await repository.save(
              original.copyWith(
                title: title,
                body: body,
                properties: properties,
              ),
            );
      mergeRepositoryObjects();
      error = null;
      notify();
      return saved;
    } catch (e) {
      error = '$e';
      notify();
      return null;
    }
  }

  Future<UniversalObject?> create(
    String type, {
    String? title,
    String body = '',
    Map<String, dynamic> properties = const {},
  }) async {
    try {
      final now = DateTime.now();
      final today = calendarDate(now);
      final tomorrow = calendarDate(DateTime(now.year, now.month, now.day + 1));
      final object = await repository.create(
        typeId: type,
        title:
            title ??
            switch (type) {
              'orbit.canvas' => 'Untitled canvas',
              'orbit.task' => 'Untitled task',
              'orbit.event' => 'Untitled event',
              'orbit.view' => 'Untitled view',
              _ => 'Untitled note',
            },
        body: body,
        properties: {
          ...switch (type) {
            'orbit.task' => {'completed': false, 'priority': 'medium'},
            'orbit.event' => {
              'allDay': true,
              'startDate': today,
              'endDate': tomorrow,
            },
            'orbit.view' => {'viewType': 'tasks'},
            _ => const {},
          },
          ...properties,
        },
        data: type == 'orbit.canvas'
            ? {'schemaVersion': 1, 'elements': <dynamic>[]}
            : const {},
      );
      objects = [...objects, object];
      error = null;
      if (_activeWorkSession != null && _activeWorkSession!.isRecordingActive) {
        _activeWorkSession = _activeWorkSession!.recordCreate(object.id);
        session.activeWorkSession = _activeWorkSession!.toJson();
      }
      openObject(object.id);
      return object;
    } catch (e) {
      error = '$e';
      notify();
      return null;
    }
  }

  Future<UniversalObject?> createUniversityCourse(
    String courseName, {
    String semester = 'WS 2026',
    int ects = 5,
    String lecturer = '',
    String targetParentFolder = 'Notes',
  }) async {
    final cleanName = courseName.trim().isEmpty ? 'Course' : courseName.trim();
    final courseFolder = targetParentFolder == 'Notes'
        ? 'University/$cleanName'
        : '$targetParentFolder/$cleanName';

    // 1. Create folder structure
    try {
      await repository.createFolder(courseFolder);
      await repository.createFolder('$courseFolder/Lectures');
      await repository.createFolder('$courseFolder/Exercises');
      await repository.createFolder('$courseFolder/Exam Preparation');
    } catch (_) {}

    // 2. Create Course Overview Note
    final overviewBody =
        '''# $cleanName Overview

**Course:** $cleanName | **Semester:** $semester | **ECTS:** $ects${lecturer.isNotEmpty ? ' | **Lecturer:** $lecturer' : ''}

## Course Summary & Goals
Welcome to $cleanName. This course workspace contains your lectures, exercise sheets, tasks, deadlines, and exam preparations.

## Course Structure
- **Lectures:** Lecture notes, definitions, theorems, and proofs.
- **Exercises:** Practice sheets, interactive canvas calculations, and solutions.
- **Exam Preparation:** Summaries, weak topics review, and mock exams.

## Quick References & Core Foundations
> [!DEFINITION] 1.1 Course Foundations
> Key course definitions and core principles.

> [!THEOREM] 1.2 Main Result
> Fundamental theorem of $cleanName.
''';

    final overviewNote = await create(
      'orbit.note',
      title: '$cleanName Overview',
      body: overviewBody,
      properties: {
        'folder': courseFolder,
        'course': cleanName,
        'courseCode': cleanName,
        'semester': semester,
        'ects': ects,
        'lecturer': lecturer,
        'isCourseOverview': true,
      },
    );

    // 3. Create starter Lecture Note
    final lectureBody =
        '''# Lecture 01 — Foundations

**Date:** ${calendarDate(DateTime.now())} | **Course:** $cleanName${lecturer.isNotEmpty ? ' | **Lecturer:** $lecturer' : ''}

## Topics
- Introduction to $cleanName
- Basic notation and fundamentals

## Definitions
> [!DEFINITION] 1.1 Fundamental Concept
> A relation or concept is defined as...

## Theorems
> [!THEOREM] 1.2 Key Property
> If conditions hold, then...

## Proofs
> [!PROOF]
> Direct proof by definitions and established lemmas.

## Examples
> [!EXAMPLE]
> Consider the standard set...

## Questions & Unclear Items
> [!QUESTION]
> Question to ask in the next exercise session:

## Exercises
- Complete Sheet 1 practice problems.

## Summary
Core foundations introduced. Review definitions before the exercise session.
''';

    await create(
      'orbit.note',
      title: 'Lecture 01 - Foundations',
      body: lectureBody,
      properties: {
        'folder': '$courseFolder/Lectures',
        'course': cleanName,
        'topic': 'Foundations',
      },
    );

    // 4. Create starter Exercise Canvas
    await create(
      'orbit.canvas',
      title: 'Exercise 01 - Practice Sheet',
      properties: {
        'folder': '$courseFolder/Exercises',
        'course': cleanName,
        'topic': 'Foundations',
        'exerciseStatus': 'not_started',
        'difficulty': 'medium',
        'confidence': 'medium',
        'backgroundStyle': 'grid',
      },
    );

    // 5. Create Scoped Views
    await create(
      'orbit.view',
      title: '$cleanName Tasks',
      properties: {
        'folder': courseFolder,
        'scope': cleanName,
        'viewType': 'tasks',
        'preset': 'university',
      },
    );

    await create(
      'orbit.view',
      title: '$cleanName Board',
      properties: {
        'folder': courseFolder,
        'scope': cleanName,
        'viewType': 'board',
        'preset': 'university',
      },
    );

    await create(
      'orbit.view',
      title: '$cleanName Calendar',
      properties: {
        'folder': courseFolder,
        'scope': cleanName,
        'viewType': 'calendar',
      },
    );

    await create(
      'orbit.view',
      title: '$cleanName Timeline',
      properties: {
        'folder': courseFolder,
        'scope': cleanName,
        'viewType': 'timeline',
      },
    );

    await create(
      'orbit.view',
      title: '$cleanName Exercises',
      properties: {
        'folder': courseFolder,
        'scope': cleanName,
        'viewType': 'exercises',
      },
    );

    session.collapsedFolders = session.collapsedFolders
        .where(
          (f) =>
              !f.contains(cleanName) &&
              f != 'Notes' &&
              !f.endsWith('University'),
        )
        .toList();
    persistSession();
    notify();

    if (overviewNote != null) {
      openObject(overviewNote.id);
    }
    return overviewNote;
  }

  Future<UniversalObject?> createLectureNote({
    required String folder,
    String? title,
    String course = '',
    String topic = '',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Lecture Notes';
    final body =
        '''# $cleanTitle

**Date:** ${calendarDate(DateTime.now())}${course.isNotEmpty ? ' | **Course:** $course' : ''}

## Topics

## Definitions
> [!DEFINITION] 

## Theorems
> [!THEOREM] 

## Proofs
> [!PROOF] 

## Examples
> [!EXAMPLE] 

## Questions
> [!QUESTION] 

## Summary
''';
    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (course.isNotEmpty) 'course': course,
        if (topic.isNotEmpty) 'topic': topic,
      },
    );
  }

  Future<UniversalObject?> createExerciseCanvas({
    required String folder,
    String? title,
    String course = '',
    String topic = '',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Exercise Canvas';
    return create(
      'orbit.canvas',
      title: cleanTitle,
      properties: {
        'folder': folder,
        if (course.isNotEmpty) 'course': course,
        if (topic.isNotEmpty) 'topic': topic,
        'exerciseStatus': 'not_started',
        'difficulty': 'medium',
        'confidence': 'medium',
        'backgroundStyle': 'grid',
      },
    );
  }

  Future<UniversalObject?> createGameProject(
    String projectName, {
    String genre = 'Action RPG',
    String targetPlatform = 'PC / Steam',
    String targetEngine = 'Godot / Unity / Custom',
    String targetParentFolder = 'Notes',
  }) async {
    final cleanName = projectName.trim().isEmpty
        ? 'GameProject'
        : projectName.trim();
    final projectFolder = targetParentFolder == 'Notes'
        ? 'Games/$cleanName'
        : '$targetParentFolder/$cleanName';

    // 1. Create folder structure
    try {
      await repository.createFolder(projectFolder);
      await repository.createFolder('$projectFolder/Design');
      await repository.createFolder('$projectFolder/Art');
      await repository.createFolder('$projectFolder/Programming');
      await repository.createFolder('$projectFolder/Audio');
      await repository.createFolder('$projectFolder/Narrative');
      await repository.createFolder('$projectFolder/Levels');
      await repository.createFolder('$projectFolder/Production');
      await repository.createFolder('$projectFolder/Playtests');
      await repository.createFolder('$projectFolder/Reference');
    } catch (_) {}

    // 2. Create GDD
    final gddBody =
        '''# $cleanName — Game Design Document

**Genre:** $genre | **Target Platform:** $targetPlatform | **Engine:** $targetEngine
**Status:** In Pre-Production / Prototype

## 1. High Concept & Pillars
- **High Concept:** A concise one-liner describing the game.
- **Pillar 1:** Core fantasy or unique selling proposition.
- **Pillar 2:** Distinct gameplay feel or mechanical hook.
- **Pillar 3:** Visual and atmospheric identity.

## 2. Core Game Loop
1. **Explore / Encounter:** Player moves through environment and faces challenge.
2. **Action / Solve:** Player applies skills, combat, or puzzle solving.
3. **Reward / Loot:** Player gains experience, items, or unlocks.
4. **Upgrade / Progress:** Player upgrades gear/abilities and opens new areas.

See visual diagram: [[Core Loop]]

## 3. Core Mechanics & Controls
- **Player Controller:** Movement, jump, sprint, dodge, interaction.
- **Combat / Interaction:** Primary attack, secondary ability, resource management (Stamina/Mana).
- **Camera & Perspective:** Third-person / Top-down / First-person camera behavior.

## 4. World & Narrative
- **Setting:** World lore, theme, and tone.
- **Protagonist:** Player character motivations and arc.
- **Factions / NPCs:** Major factions and quest-givers.

## 5. Art & Audio Direction
- **Visual Style:** See [[Art Direction & Moodboard]].
- **Audio Palette:** Dynamic soundtrack, Foley priorities, UI feedback sounds.

## 6. Milestones & Production Targets
- **Prototype:** Core mechanics, graybox player controller, basic combat loop.
- **Vertical Slice:** One polished level, final art style test, complete audio pass.
- **Alpha:** All gameplay systems implemented, content complete.
- **Beta:** Bug fixing, balance pass, performance optimization.
- **Release:** Day-one patch ready, platform certifications.
''';

    final gddNote = await create(
      'orbit.note',
      title: '$cleanName GDD',
      body: gddBody,
      properties: {
        'folder': '$projectFolder/Design',
        'project': cleanName,
        'genre': genre,
        'platform': targetPlatform,
        'engine': targetEngine,
        'isGdd': true,
        'category': 'Design',
      },
    );

    // 3. Create Mechanics Spec
    final mechanicsBody =
        '''# Core Mechanics Specification — $cleanName

**Project:** $cleanName | **Discipline:** Game Design

## Overview
Detailed breakdown of player movement physics, combat mechanics, and interaction rules.

## State Machine
- **Idle:** Default state, transitions to Walk/Run on input.
- **Move:** Ground acceleration, max velocity, braking friction.
- **Jump / Fall:** Apex gravity float, coyote time (120ms), jump buffer (150ms).
- **Action / Attack:** Startup frames, active hit window, recovery / cancel frames.

## Numbers & Tuning
- Move Speed: 6.0 m/s
- Jump Velocity: 9.8 m/s
- Gravity Multiplier: 2.2x
''';

    await create(
      'orbit.note',
      title: 'Core Mechanics Spec',
      body: mechanicsBody,
      properties: {
        'folder': '$projectFolder/Design',
        'project': cleanName,
        'discipline': 'Game Design',
        'category': 'Specification',
      },
    );

    // 4. Create Canvases: Core Loop, Moodboard & Roadmap
    await create(
      'orbit.canvas',
      title: 'Core Loop',
      properties: {
        'folder': '$projectFolder/Design',
        'project': cleanName,
        'canvasPreset': 'core_loop',
        'backgroundStyle': 'grid',
      },
    );

    await create(
      'orbit.canvas',
      title: 'Art Direction & Moodboard',
      properties: {
        'folder': '$projectFolder/Art',
        'project': cleanName,
        'canvasPreset': 'moodboard',
        'backgroundStyle': 'dots',
      },
    );

    await create(
      'orbit.canvas',
      title: 'Game Roadmap',
      properties: {
        'folder': '$projectFolder/Reference',
        'project': cleanName,
        'canvasPreset': 'game_roadmap',
        'backgroundStyle': 'grid',
      },
    );

    // 5. Create Scoped Views
    await create(
      'orbit.view',
      title: '$cleanName Dashboard',
      properties: {
        'folder': projectFolder,
        'project': cleanName,
        'scope': cleanName,
        'viewType': 'game_dashboard',
        'genre': genre,
        'platform': targetPlatform,
        'engine': targetEngine,
      },
    );

    await create(
      'orbit.view',
      title: '$cleanName Board',
      properties: {
        'folder': projectFolder,
        'project': cleanName,
        'scope': cleanName,
        'viewType': 'board',
        'preset': 'gamedev',
      },
    );

    await create(
      'orbit.view',
      title: '$cleanName Backlog',
      properties: {
        'folder': projectFolder,
        'project': cleanName,
        'scope': cleanName,
        'viewType': 'tasks',
      },
    );

    await create(
      'orbit.view',
      title: '$cleanName Current Focus',
      properties: {
        'folder': projectFolder,
        'project': cleanName,
        'scope': cleanName,
        'viewType': 'tasks',
        'filter': 'focus',
      },
    );

    await create(
      'orbit.view',
      title: '$cleanName Bugs',
      properties: {
        'folder': projectFolder,
        'project': cleanName,
        'scope': cleanName,
        'viewType': 'board',
        'preset': 'bugs',
      },
    );

    await create(
      'orbit.view',
      title: '$cleanName Milestones',
      properties: {
        'folder': projectFolder,
        'project': cleanName,
        'scope': cleanName,
        'viewType': 'milestones',
      },
    );

    await create(
      'orbit.view',
      title: '$cleanName Roadmap',
      properties: {
        'folder': projectFolder,
        'project': cleanName,
        'scope': cleanName,
        'viewType': 'timeline',
      },
    );

    // 6. Create Starter Tasks across disciplines with dependencies
    final repoTask = await create(
      'orbit.task',
      title: 'Initialize repository & game engine template',
      body:
          '- [ ] Create Git repository\n- [ ] Configure .gitignore for engine binaries\n- [ ] Setup initial scene and project settings',
      properties: {
        'folder': '$projectFolder/Programming',
        'project': cleanName,
        'discipline': 'Programming',
        'milestone': 'Prototype',
        'priority': 'high',
        'estimate': '2',
      },
    );

    await create(
      'orbit.task',
      title: 'Implement player movement & camera rig',
      body:
          '- [ ] Implement 8-direction movement\n- [ ] Add smooth camera follow & collision avoidance\n- [ ] Tune acceleration and friction',
      properties: {
        'folder': '$projectFolder/Programming',
        'project': cleanName,
        'discipline': 'Gameplay',
        'milestone': 'Prototype',
        'priority': 'high',
        'estimate': '5',
        if (repoTask != null) 'blockedBy': repoTask.id,
      },
    );

    await create(
      'orbit.task',
      title: 'Hero character concept art & turnaround',
      body:
          '- [ ] Silhouette exploration (5 sketches)\n- [ ] Color palette definition\n- [ ] 3-view turnaround for 3D modeling',
      properties: {
        'folder': '$projectFolder/Art',
        'project': cleanName,
        'discipline': 'Art',
        'milestone': 'Prototype',
        'priority': 'medium',
        'estimate': '5',
      },
    );

    await create(
      'orbit.task',
      title: 'Movement Foley & ambiance prototype',
      body:
          '- [ ] Footstep sounds (concrete, dirt, wood)\n- [ ] Jump & landing SFX\n- [ ] Background wind / room tone loop',
      properties: {
        'folder': '$projectFolder/Audio',
        'project': cleanName,
        'discipline': 'Audio',
        'milestone': 'Prototype',
        'priority': 'low',
        'estimate': '3',
      },
    );

    session.collapsedFolders = session.collapsedFolders
        .where(
          (f) => !f.contains(cleanName) && f != 'Notes' && !f.endsWith('Games'),
        )
        .toList();
    persistSession();
    notify();

    if (gddNote != null) {
      openObject(gddNote.id);
    }
    return gddNote;
  }

  Future<UniversalObject?> createGameDesignDocument({
    required String folder,
    String? title,
    String project = '',
    String genre = 'Action RPG',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Game Design Document';
    final body =
        '''# $cleanTitle

**Project:** $project | **Genre:** $genre
**Date:** ${calendarDate(DateTime.now())}

## 1. Vision & Core Pillars
- 

## 2. Core Game Loop
- 

## 3. Mechanics & Systems
- 

## 4. Content & Level Progression
- 

## 5. Narrative & Setting
- 
''';
    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (project.isNotEmpty) 'project': project,
        'isGdd': true,
        'category': 'Design',
      },
    );
  }

  Future<UniversalObject?> createFeatureSpec({
    required String folder,
    String? title,
    String project = '',
    String discipline = 'Gameplay',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Feature Spec';
    final body =
        '''# $cleanTitle

**Project:** $project | **Discipline:** $discipline
**Date:** ${calendarDate(DateTime.now())}

## Problem & Goal
What player experience or system need does this feature address?

## Detailed Specification
- User flow / control flow
- Edge cases and failure conditions
- Dependencies on other systems

## Acceptance Criteria
- [ ] Core interaction works smoothly
- [ ] Sound effects and visual feedback hooked up
- [ ] No regression on performance or physics
''';
    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (project.isNotEmpty) 'project': project,
        'discipline': discipline,
        'category': 'Feature Spec',
      },
    );
  }

  Future<UniversalObject?> createBugReport({
    required String folder,
    String? title,
    String project = '',
    String severity = 'major',
    String build = 'v0.1.0',
    String platform = 'PC',
    String discipline = 'QA',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Bug Report';
    final body =
        '''# $cleanTitle

**Severity:** ${severity.toUpperCase()} | **Build:** $build | **Platform:** $platform
**Discipline:** $discipline | **Reported:** ${calendarDate(DateTime.now())}

## Summary & Expected vs Actual
- **Expected:** 
- **Actual:** 

## Steps to Reproduce
1. Start game on build $build.
2. 
3. 

## Reproduction Rate
- [x] 100% (Every time)
- [ ] 50% (Intermittent)
- [ ] Once only

## System Specs / Logs
Attach crash dump, engine console output, or screenshots here.
''';
    return create(
      'orbit.task',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (project.isNotEmpty) 'project': project,
        'isBug': true,
        'severity': severity,
        'build': build,
        'platform': platform,
        'discipline': discipline,
        'category': 'Bug',
        'status': 'new',
      },
    );
  }

  Future<UniversalObject?> createPlaytestSession({
    required String folder,
    String? title,
    String project = '',
    String build = 'v0.1.0',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Playtest Session';
    final body =
        '''# $cleanTitle

**Project:** $project | **Build Tested:** $build | **Date:** ${calendarDate(DateTime.now())}
**Tester / Cohort:** 

## Objectives
What questions did this session aim to answer?
- Is the tutorial intuitive?
- Where do players get stuck or lost?

## Observations
- **Positive Moments:** 
- **Friction Points:** 
- **Confusion / Rage Quits:** 

## Feedback Summary
- Controls: (1-5)
- Fun Factor: (1-5)
- Difficulty: Too easy / Just right / Too hard

## Action Items
- [ ] Task / fix to file
''';
    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (project.isNotEmpty) 'project': project,
        'category': 'Playtest',
        'build': build,
      },
    );
  }

  Future<UniversalObject?> createDevLog({
    required String folder,
    String? title,
    String project = '',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Dev Log — ${calendarDate(DateTime.now())}';
    final body =
        '''# $cleanTitle

**Date:** ${calendarDate(DateTime.now())}${project.isNotEmpty ? ' | **Project:** $project' : ''}

## Completed Today
- 

## Blockers & Roadblocks
- None

## Next Focus
- 
''';
    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (project.isNotEmpty) 'project': project,
        'category': 'DevLog',
      },
    );
  }

  Future<UniversalObject?> createLevelDesignDoc({
    required String folder,
    String? title,
    String project = '',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Level Design Document';
    final body =
        '''# $cleanTitle

**Project:** $project | **Discipline:** Level Design
**Date:** ${calendarDate(DateTime.now())}

## Level Theme & Setting
- 

## Flow & Beats (Pacing)
1. **Introduction / Spawn:** Teach mechanics in safe zone.
2. **First Encounter:** Low-stakes challenge.
3. **Pacing Valley / Exploration:** Secret paths, collectibles, lore.
4. **Climax / Boss Arena:** High intensity test of player mastery.
5. **Exit / Transition:** Reward room and transition to next area.

## Metrics & Restrictions
- Corridor Width: 3.5m min
- Ceiling Height: 4.0m min
- Sightlines: Max 40m before break
''';
    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (project.isNotEmpty) 'project': project,
        'discipline': 'Level Design',
        'category': 'Level Design',
      },
    );
  }

  Future<UniversalObject?> createMechanicDesignDoc({
    required String folder,
    String? title,
    String project = '',
    String input = 'Shift',
    String playerAction = 'Dash',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : '$playerAction Mechanic Spec';
    final body =
        '''# $cleanTitle

**Project:** $project | **Discipline:** Game Design
**Input Trigger:** `$input` | **Date:** ${calendarDate(DateTime.now())}

## Purpose & Feel
- **Goal:** Why does the player have this ability?
- **Player Fantasy:** Instant burst of evasive speed and invulnerability.

## Input & Control Rules
- **Activation:** Pressing `$input` while moving triggers $playerAction in current movement vector.
- **Duration / Window:** 250ms active invulnerability.
- **Cooldown / Cost:** 1.2s cooldown or 25 Stamina.

## Feedback & Juice
- **Animation:** Low-profile slide / phantom blur.
- **VFX:** Ghost silhouette trail.
- **SFX:** Whoosh with low-frequency bass impact.

## Edge Cases & Failure Conditions
- Cannot dash while airborne if air-dash upgrade is not acquired.
- Wall collision halts forward momentum without glitching into colliders.

## Dependencies & Related Objects
- Dependencies: Player Controller, Stamina System
- Related Tasks:
''';
    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (project.isNotEmpty) 'project': project,
        'discipline': 'Game Design',
        'category': 'Mechanic Spec',
      },
    );
  }

  Future<UniversalObject?> createEnemyDesignDoc({
    required String folder,
    String? title,
    String project = '',
    String role = 'Melee Grunt',
    int health = 100,
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Enemy Design — $role';
    final body =
        '''# $cleanTitle

**Project:** $project | **Role:** $role | **Base Health:** $health HP
**Discipline:** AI & Combat | **Date:** ${calendarDate(DateTime.now())}

## Combat Profile & Behavior
- **Role in Encounter:** Closes distance to force player dodge or parry.
- **Movement Speed:** 4.5 m/s (Walk), 7.0 m/s (Charge).
- **Detection Range:** 15m radius, 120° forward vision cone.

## Attack Patterns & Telegraphed Tells
1. **Light Slash:** 20 DMG. Tell: raises weapon for 400ms.
2. **Heavy Overhead:** 45 DMG. Tell: audio roar and 750ms wind-up.

## AI State Transitions
- Idle → Patrol (waypoint walk)
- Alert (player spotted) → Chase
- Within 2.5m → Attack
- Low Health (<20%) → Retreat or Frenzy

## Drops & Rewards
- Experience / Currency: 35 pts
- Loot Table: Scrap metal, Health potion (15% drop rate)

## Animations & Audio Cues
- Animations: Idle, Walk, Run, Wind-up, Strike, Flinch, Death
- Audio: Footsteps, Aggro bark, Strike swoosh, Death rattle
''';
    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (project.isNotEmpty) 'project': project,
        'discipline': 'AI',
        'category': 'Enemy Design',
      },
    );
  }

  Future<UniversalObject?> createCharacterDesignDoc({
    required String folder,
    String? title,
    String project = '',
    String role = 'Protagonist',
    String faction = 'Wanderers',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Character Profile';
    final body =
        '''# $cleanTitle

**Project:** $project | **Role:** $role | **Faction:** $faction
**Discipline:** Narrative | **Date:** ${calendarDate(DateTime.now())}

## Overview & Personality
- **Name:** 
- **Archetype / Personality:** Driven, cautious, dry humor.
- **Core Motivation:** Uncover the lost archives and protect their outpost.

## Visual Identity & Turnaround
- **Silhouette:** Distinct cape and oversized shoulder gear.
- **Color Palette:** Weathered graphite, bronze, indigo accents.
- Turnaround Art: [[Art Direction & Moodboard]]

## Voice & Dialogue Style
- Short, punchy sentences.
- Avoids flowery exposition; speaks through action.

## Abilities & Progression
- Signature Weapon: Relic Blade
- Passive Perk: 10% faster stamina recovery near ancient structures
''';
    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (project.isNotEmpty) 'project': project,
        'discipline': 'Narrative',
        'category': 'Character Design',
      },
    );
  }

  Future<UniversalObject?> createItemDesignDoc({
    required String folder,
    String? title,
    String project = '',
    String category = 'Weapon',
    String rarity = 'Rare',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Item — New $category';
    final body =
        '''# $cleanTitle

**Project:** $project | **Category:** $category | **Rarity:** $rarity
**Discipline:** Game Design | **Date:** ${calendarDate(DateTime.now())}

## Stats & Scaling
- **Base Damage / Value:** 45 DMG
- **Attack Speed:** 1.4 hits/sec
- **Durability / Weight:** 150 uses / 3.5 kg

## Description & Lore
- Short flavor text describing item origin and history.

## Acquisition & Crafting
- Crafting recipe: 2x Refined Iron, 1x Core Fragment
- Found in: Sunken Temple Chests

## Balance Notes
- Strong against armored enemies, slower recovery on miss.
''';
    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (project.isNotEmpty) 'project': project,
        'discipline': 'Game Design',
        'category': 'Item / Weapon',
      },
    );
  }

  Future<UniversalObject?> createAudioDesignDoc({
    required String folder,
    String? title,
    String project = '',
    String category = 'SFX',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Audio Asset Spec';
    final body =
        '''# $cleanTitle

**Project:** $project | **Audio Category:** $category
**Discipline:** Audio | **Date:** ${calendarDate(DateTime.now())}

## Cue Breakdown
| Cue Name | Type | Looping | Priority | Format | Status |
|---|---|---|---|---|---|
| Ambience_Wind_Loop | Ambience | Yes | Low | 48kHz WAV | Planned |
| Footstep_Stone_01..04 | Foley | No | Medium | 48kHz WAV | In Progress |
| Combat_Boss_Theme | Music | Yes | High | 48kHz OGG | Planned |
| UI_Button_Click | UI | No | High | 48kHz WAV | Implemented |

## Implementation Notes
- Use randomized pitch variation (±5%) on repetitive foley cues.
- Reverb zone: 1.8s decay in cathedral arenas.
''';
    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (project.isNotEmpty) 'project': project,
        'discipline': 'Audio',
        'category': 'Audio Planning',
      },
    );
  }

  Future<UniversalObject?> createQuestDesignDoc({
    required String folder,
    String? title,
    String project = '',
    String goal = 'Retrieve ancient cipher',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Quest — $goal';
    final body =
        '''# $cleanTitle

**Project:** $project | **Discipline:** Narrative & Level Design
**Quest Giver:** Elder Kael | **Location:** Abandoned Observatory

## Quest Overview
- **Objective:** $goal
- **Prerequisites:** Completed tutorial and unlocked Dash ability.

## Stages & Flow
1. **Talk to Kael:** Receives coordinates to Observatory.
2. **Navigate Ruins:** Defeat patrolling scout drones.
3. **Solve Door Puzzle:** Align glyphs based on star charts.
4. **Boss / Climax:** Defeat Guardian Golem.
5. **Turn in:** Deliver cipher for 500 gold and ancient talisman.

## Failure & Edge Cases
- Player flees boss arena: boss resets health to full.
- Abandoning quest: cipher stays in world until resumed.
''';
    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (project.isNotEmpty) 'project': project,
        'discipline': 'Narrative',
        'category': 'Quest Spec',
      },
    );
  }

  Future<UniversalObject?> createReleaseChecklist({
    required String folder,
    String? title,
    String project = '',
    String buildVersion = 'v1.0.0',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Release Checklist — $buildVersion';
    final body =
        '''# $cleanTitle

**Project:** $project | **Target Version:** $buildVersion
**Discipline:** Production & Release | **Date:** ${calendarDate(DateTime.now())}

## 1. Build Verification
- [ ] Version number bumped in project configuration
- [ ] Clean release binaries compiled without debug flags
- [ ] Smoke tested on clean Windows 11 machine
- [ ] Smoke tested on Steam Deck / Android device

## 2. QA & Stability
- [ ] Zero open blocker or critical bugs
- [ ] Save game backwards compatibility confirmed
- [ ] Gamepad / keyboard remapping verified
- [ ] Frame rate targets met across min-spec hardware

## 3. Store & Marketing Assets
- [ ] Gameplay trailer uploaded with accurate release date
- [ ] Store screenshots updated with final UI
- [ ] Store description & localization verified
- [ ] Platform achievements / cloud saves hooked up

## 4. Source & Disaster Recovery
- [ ] Release commit tagged in Git (`$buildVersion`)
- [ ] Clean build artifacts archived offsite
''';
    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (project.isNotEmpty) 'project': project,
        'discipline': 'Production',
        'category': 'Release Checklist',
      },
    );
  }

  Future<UniversalObject?> createWeeklyReview({
    required String folder,
    String? title,
    String project = '',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Weekly Dev Review — ${calendarDate(DateTime.now())}';
    final body =
        '''# $cleanTitle

**Project:** $project | **Review Date:** ${calendarDate(DateTime.now())}
**Discipline:** Production

## Accomplished This Week
- 

## Blockers & Friction Points
- 

## Milestone & Sprint Velocity
- Tasks Completed: 
- Story Points Burned: 
- Open Bugs Count: 

## Goals For Next Week
1. 
2. 
3. 

## Key Risks to Monitor
- 
''';
    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (project.isNotEmpty) 'project': project,
        'discipline': 'Production',
        'category': 'Weekly Review',
      },
    );
  }

  Future<UniversalObject?> createRiskAssessmentDoc({
    required String folder,
    String? title,
    String project = '',
    String risk = 'Physics engine latency at high object count',
    String impact = 'High',
    String likelihood = 'Medium',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Risk Assessment — $risk';
    final body =
        '''# $cleanTitle

**Project:** $project | **Impact:** $impact | **Likelihood:** $likelihood
**Discipline:** Technical Production | **Date:** ${calendarDate(DateTime.now())}

## Risk Description
$risk

## Potential Consequences
- Framerate drops below 60fps on minimum hardware specs.
- Player feedback feels sluggish during combat encounters.

## Mitigation Strategy
- Implement spatial partitioning for active physics bodies.
- Prototype stress test with 200 concurrent ragdolls before committing level design.

## Trigger & Review Criteria
- Review benchmark every sprint release.
''';
    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (project.isNotEmpty) 'project': project,
        'discipline': 'Production',
        'category': 'Risk Assessment',
      },
    );
  }

  Future<UniversalObject?> createDecisionDoc({
    required String folder,
    String? title,
    String project = '',
    String decision = 'Architecture Decision',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'ADR — $decision';
    final body =
        '''# $cleanTitle

**Project:** $project | **Date:** ${calendarDate(DateTime.now())}
**Status:** Decided / Accepted

## Context & Problem Statement
What technical, architectural, or design problem needed a choice?

## Evaluated Options
1. **Option A:** 
2. **Option B:** 

## Chosen Approach & Rationale
We chose Option A because:
- 

## Consequences & Trade-offs
- **Positive:** 
- **Negative / Risks:** 
''';
    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (project.isNotEmpty) 'project': project,
        'discipline': 'Production',
        'category': 'Decision Record',
      },
    );
  }

  Future<UniversalObject?> createTaskFromFinding({
    required String finding,
    required String sourceNoteId,
    String project = '',
    bool isBug = true,
    String severity = 'major',
    String discipline = 'QA',
    String folder = '',
  }) async {
    final cleanFinding = finding.trim();
    if (cleanFinding.isEmpty) return null;
    final sourceNote = find(sourceNoteId);
    final targetFolder = folder.isNotEmpty
        ? folder
        : (sourceNote?.properties['folder'] as String? ?? 'Notes');
    final targetProject = project.isNotEmpty
        ? project
        : (sourceNote?.properties['project'] as String? ?? '');

    final task = await create(
      'orbit.task',
      title: cleanFinding,
      body:
          'Originating playtest observation from [[${sourceNote?.title ?? "Playtest"}]]\n\n'
          '- [ ] Verify finding\n'
          '- [ ] Implement resolution\n'
          '- [ ] Validate in playtest session\n',
      properties: {
        'folder': targetFolder,
        if (targetProject.isNotEmpty) 'project': targetProject,
        'sourceNoteId': sourceNoteId,
        'isBug': isBug,
        if (isBug) 'severity': severity,
        'discipline': discipline,
        'status': 'new',
        'priority': isBug && (severity == 'blocker' || severity == 'critical')
            ? 'urgent'
            : 'medium',
      },
    );

    // If source note exists, append link in action items section
    if (sourceNote != null && task != null) {
      final updatedBody =
          '${sourceNote.body.trimRight()}\n- [ ] [[${task.title}]] (${isBug ? severity.toUpperCase() : discipline})\n';
      edit(sourceNote.id, body: updatedBody);
    }

    return task;
  }

  Future<void> duplicateGameProjectStructure(
    String sourceProjectName,
    String newProjectName, {
    String targetParentFolder = 'Notes',
  }) async {
    final cleanSource = sourceProjectName.trim();
    final cleanNew = newProjectName.trim();
    if (cleanSource.isEmpty || cleanNew.isEmpty) return;

    final sourceFolder = targetParentFolder == 'Notes'
        ? 'Games/$cleanSource'
        : '$targetParentFolder/$cleanSource';
    final newFolder = targetParentFolder == 'Notes'
        ? 'Games/$cleanNew'
        : '$targetParentFolder/$cleanNew';

    // 1. Create matching subfolders
    final subfolders = [
      '',
      '/Design',
      '/Art',
      '/Programming',
      '/Audio',
      '/Narrative',
      '/Levels',
      '/Production',
      '/Playtests',
      '/Reference',
    ];
    for (final sub in subfolders) {
      await repository.createFolder('$newFolder$sub');
    }

    // 2. Clone views scoped to the new project without historical tasks
    final sourceViews = ofType('orbit.view')
        .where(
          (v) =>
              v.properties['project'] == cleanSource ||
              v.properties['scope'] == cleanSource ||
              (v.properties['folder'] as String?)?.startsWith(sourceFolder) ==
                  true,
        )
        .toList();

    for (final v in sourceViews) {
      final oldTitle = v.title;
      final newTitle = oldTitle.replaceAll(cleanSource, cleanNew);
      final newProperties = Map<String, dynamic>.from(v.properties);
      newProperties['project'] = cleanNew;
      if (newProperties.containsKey('scope')) {
        newProperties['scope'] = cleanNew;
      }
      final oldFolder = newProperties['folder'] as String?;
      if (oldFolder != null && oldFolder.startsWith(sourceFolder)) {
        newProperties['folder'] = oldFolder.replaceFirst(
          sourceFolder,
          newFolder,
        );
      } else {
        newProperties['folder'] = newFolder;
      }
      await create('orbit.view', title: newTitle, properties: newProperties);
    }
  }

  // ==========================================
  // REVERSE ENGINEERING & SECURITY RESEARCH
  // ==========================================

  Future<UniversalObject?> createReverseEngineeringProject(
    String targetName, {
    String architecture = 'x86-64',
    String format = 'PE',
    String targetPlatform = 'Windows',
    String targetVersion = '1.0.0',
    String targetParentFolder = 'Notes',
  }) async {
    final cleanName = targetName.trim().isEmpty ? 'Target' : targetName.trim();
    final projectFolder = targetParentFolder == 'Notes'
        ? 'Reverse Engineering/$cleanName'
        : '$targetParentFolder/$cleanName';

    // 1. Create directory hierarchy
    try {
      await repository.createFolder(projectFolder);
      await repository.createFolder('$projectFolder/Functions');
      await repository.createFolder('$projectFolder/Structures');
      await repository.createFolder('$projectFolder/Sessions');
      await repository.createFolder('$projectFolder/Diagrams');
      await repository.createFolder('$projectFolder/Files');
    } catch (_) {}

    // 2. Create Target Overview Note
    final overviewBody =
        '''# $cleanName — Binary Analysis & Research Overview

**Target:** $cleanName | **Architecture:** $architecture | **Format:** $format
**Platform:** $targetPlatform | **Version:** $targetVersion | **Status:** In Analysis
**Analysis Date:** ${calendarDate(DateTime.now())}

## 1. Target Metadata
- **Original Filename:** $cleanName
- **File Format:** $format
- **Architecture:** $architecture
- **Target OS / Subsystem:** $targetPlatform
- **Compiler / Toolchain:** MSVC / GCC / Clang
- **Language:** C / C++ / Rust
- **SHA-256:** 
- **MD5:** 
- **Symbols / PDB:** Stripped / Available

## 2. Research Objectives & Scope
1. Document core logic, state managers, and entry points.
2. Reverse engineer critical data structures and object memory layouts.
3. Validate hypotheses regarding subsystems, algorithms, or protocols.

## 3. Key Findings Summary
- (Document confirmed findings with references: [[Finding Title]])

## 4. Key References & Diagrams
- Call Flow: [[Call Flow]]
- Object Relationships: [[Object Relationships]]
''';

    final overviewNote = await create(
      'orbit.note',
      title: '$cleanName Overview',
      body: overviewBody,
      properties: {
        'folder': projectFolder,
        'target': cleanName,
        'architecture': architecture,
        'format': format,
        'platform': targetPlatform,
        'version': targetVersion,
        'isTargetOverview': true,
        'category': 'Overview',
      },
    );

    // 3. Create Canvases: Call Flow & Object Relationships
    await create(
      'orbit.canvas',
      title: 'Call Flow',
      properties: {
        'folder': '$projectFolder/Diagrams',
        'target': cleanName,
        'canvasPreset': 'call_flow',
        'backgroundStyle': 'grid',
      },
    );

    await create(
      'orbit.canvas',
      title: 'Object Relationships',
      properties: {
        'folder': '$projectFolder/Diagrams',
        'target': cleanName,
        'canvasPreset': 'object_relationships',
        'backgroundStyle': 'dots',
      },
    );

    // 4. Create Scoped Views
    await create(
      'orbit.view',
      title: '$cleanName Dashboard',
      properties: {
        'folder': projectFolder,
        'target': cleanName,
        'scope': cleanName,
        'viewType': 're_dashboard',
        'architecture': architecture,
        'format': format,
      },
    );

    await create(
      'orbit.view',
      title: '$cleanName Functions',
      properties: {
        'folder': '$projectFolder/Functions',
        'target': cleanName,
        'scope': cleanName,
        'viewType': 'functions',
      },
    );

    await create(
      'orbit.view',
      title: '$cleanName Hypotheses',
      properties: {
        'folder': projectFolder,
        'target': cleanName,
        'scope': cleanName,
        'viewType': 'board',
        'preset': 'hypotheses',
      },
    );

    await create(
      'orbit.view',
      title: '$cleanName Investigation Tasks',
      properties: {
        'folder': projectFolder,
        'target': cleanName,
        'scope': cleanName,
        'viewType': 'tasks',
      },
    );

    // 5. Create starter investigation tasks
    await create(
      'orbit.task',
      title: 'Locate main entry point & unpack / decrypt check',
      body:
          '- [ ] Identify entry point\n- [ ] Check section entropy and TLS callbacks\n- [ ] Document PE headers in [[$cleanName Overview]]',
      properties: {
        'folder': projectFolder,
        'target': cleanName,
        'priority': 'high',
        'status': 'in-progress',
      },
    );

    await create(
      'orbit.task',
      title: 'Extract strings & identify API imports',
      body:
          '- [ ] Run strings dump (ASCII & UTF-16)\n- [ ] Analyze imports table for network/file/crypto APIs\n- [ ] Record suspicious or interesting strings',
      properties: {
        'folder': projectFolder,
        'target': cleanName,
        'priority': 'medium',
        'status': 'planned',
      },
    );

    session.collapsedFolders = session.collapsedFolders
        .where(
          (f) =>
              !f.contains(cleanName) &&
              f != 'Notes' &&
              !f.endsWith('Reverse Engineering'),
        )
        .toList();
    persistSession();
    notify();

    if (overviewNote != null) {
      openObject(overviewNote.id);
    }
    return overviewNote;
  }

  Future<UniversalObject?> createGameInternalsProject(
    String gameName, {
    String architecture = 'x86-64',
    String engine = 'Unreal Engine / Unity / Custom',
    String targetParentFolder = 'Notes',
  }) async {
    final cleanName = gameName.trim().isEmpty ? 'Game' : gameName.trim();
    final projectFolder = targetParentFolder == 'Notes'
        ? 'Game Internals/$cleanName'
        : '$targetParentFolder/$cleanName';

    try {
      await repository.createFolder(projectFolder);
      await repository.createFolder('$projectFolder/Architecture');
      await repository.createFolder('$projectFolder/Modules');
      await repository.createFolder('$projectFolder/Functions');
      await repository.createFolder('$projectFolder/Structures');
      await repository.createFolder('$projectFolder/Game Systems');
      await repository.createFolder('$projectFolder/Sessions');
      await repository.createFolder('$projectFolder/Findings');
    } catch (_) {}

    final overviewNote = await create(
      'orbit.note',
      title: '$cleanName Internals Overview',
      body:
          '''# $cleanName — Game Internals & Systems Research

**Target:** $cleanName | **Engine:** $engine | **Architecture:** $architecture
**Analysis Date:** ${calendarDate(DateTime.now())}

## Systems Architecture
- Game Systems: [[Player System]], [[Rendering System]], [[Inventory System]]
- Diagrams: [[Architecture Map]], [[Rendering Pipeline]], [[Call Flow]]

## Key Memory Layouts & Structures
- (Document discovered game classes, vtables, and offset tables)
''',
      properties: {
        'folder': projectFolder,
        'target': cleanName,
        'engine': engine,
        'architecture': architecture,
        'isTargetOverview': true,
        'category': 'Overview',
      },
    );

    await create(
      'orbit.canvas',
      title: 'Architecture Map',
      properties: {
        'folder': '$projectFolder/Architecture',
        'target': cleanName,
        'canvasPreset': 'game_architecture',
      },
    );

    await create(
      'orbit.canvas',
      title: 'Rendering Pipeline',
      properties: {
        'folder': '$projectFolder/Architecture',
        'target': cleanName,
        'canvasPreset': 'rendering_pipeline',
      },
    );

    await create(
      'orbit.canvas',
      title: 'Call Flow',
      properties: {
        'folder': '$projectFolder/Architecture',
        'target': cleanName,
        'canvasPreset': 'call_flow',
      },
    );

    await create(
      'orbit.view',
      title: '$cleanName Dashboard',
      properties: {
        'folder': projectFolder,
        'target': cleanName,
        'scope': cleanName,
        'viewType': 're_dashboard',
      },
    );

    await create(
      'orbit.view',
      title: '$cleanName Functions',
      properties: {
        'folder': '$projectFolder/Functions',
        'target': cleanName,
        'scope': cleanName,
        'viewType': 'functions',
      },
    );

    await create(
      'orbit.view',
      title: '$cleanName Hypotheses',
      properties: {
        'folder': projectFolder,
        'target': cleanName,
        'scope': cleanName,
        'viewType': 'board',
        'preset': 'hypotheses',
      },
    );

    await create(
      'orbit.view',
      title: '$cleanName Tasks',
      properties: {
        'folder': projectFolder,
        'target': cleanName,
        'scope': cleanName,
        'viewType': 'tasks',
      },
    );

    session.collapsedFolders = session.collapsedFolders
        .where(
          (f) =>
              !f.contains(cleanName) &&
              f != 'Notes' &&
              !f.endsWith('Game Internals'),
        )
        .toList();
    persistSession();
    notify();

    if (overviewNote != null) {
      openObject(overviewNote.id);
    }
    return overviewNote;
  }

  Future<UniversalObject?> createMalwareAnalysisProject(
    String sampleName, {
    String sha256 = '',
    String classification = 'Trojan / Downloader / Ransomware',
    String targetParentFolder = 'Notes',
  }) async {
    final cleanName = sampleName.trim().isEmpty ? 'Sample' : sampleName.trim();
    final projectFolder = targetParentFolder == 'Notes'
        ? 'Malware Analysis/$cleanName'
        : '$targetParentFolder/$cleanName';

    try {
      await repository.createFolder(projectFolder);
      await repository.createFolder('$projectFolder/Triage');
      await repository.createFolder('$projectFolder/Static');
      await repository.createFolder('$projectFolder/Dynamic');
      await repository.createFolder('$projectFolder/Behavior');
      await repository.createFolder('$projectFolder/Indicators');
      await repository.createFolder('$projectFolder/Findings');
      await repository.createFolder('$projectFolder/Hypotheses');
      await repository.createFolder('$projectFolder/Timeline');
      await repository.createFolder('$projectFolder/Sessions');
      await repository.createFolder('$projectFolder/Evidence');
    } catch (_) {}

    final triageNote = await create(
      'orbit.note',
      title: '$cleanName Triage & Overview',
      body:
          '''# $cleanName — Defensive Malware Triage & Analysis

**Sample:** $cleanName | **Classification:** $classification
**SHA-256:** `${sha256.isEmpty ? "Uncalculated" : sha256}`
**Environment:** Isolated Lab VM | **Date:** ${calendarDate(DateTime.now())}

## 1. Initial Triage
- **File Type:** PE32 / PE64 Executable / DLL
- **Subsystem:** Windows GUI / Console
- **Packer / Crypter:** None / UPX / Custom
- **Risk Assessment:** High / Critical

## 2. Observed Capabilities
- Network communication & command beaconing
- Persistence via Scheduled Task / Registry Run key
- Process hollowing / injection attempts

## 3. Indicators of Compromise (IOCs)
See [[$cleanName Indicators]] for structured table.
''',
      properties: {
        'folder': '$projectFolder/Triage',
        'target': cleanName,
        'sha256': sha256,
        'classification': classification,
        'isTargetOverview': true,
        'category': 'Overview',
      },
    );

    await create(
      'orbit.canvas',
      title: 'Process Tree',
      properties: {
        'folder': '$projectFolder/Behavior',
        'target': cleanName,
        'canvasPreset': 'process_tree',
      },
    );

    await create(
      'orbit.view',
      title: '$cleanName Dashboard',
      properties: {
        'folder': projectFolder,
        'target': cleanName,
        'scope': cleanName,
        'viewType': 're_dashboard',
      },
    );

    await create(
      'orbit.view',
      title: '$cleanName Indicators',
      properties: {
        'folder': '$projectFolder/Indicators',
        'target': cleanName,
        'scope': cleanName,
        'viewType': 'iocs',
      },
    );

    await create(
      'orbit.view',
      title: '$cleanName Timeline',
      properties: {
        'folder': '$projectFolder/Timeline',
        'target': cleanName,
        'scope': cleanName,
        'viewType': 'timeline',
      },
    );

    await create(
      'orbit.view',
      title: '$cleanName Hypotheses',
      properties: {
        'folder': projectFolder,
        'target': cleanName,
        'scope': cleanName,
        'viewType': 'board',
        'preset': 'hypotheses',
      },
    );

    session.collapsedFolders = session.collapsedFolders
        .where(
          (f) =>
              !f.contains(cleanName) &&
              f != 'Notes' &&
              !f.endsWith('Malware Analysis'),
        )
        .toList();
    persistSession();
    notify();

    if (triageNote != null) {
      openObject(triageNote.id);
    }
    return triageNote;
  }

  // -------------------------------------------------------------
  // SPECIALIZED REVERSE ENGINEERING TEMPLATES
  // -------------------------------------------------------------

  Future<UniversalObject?> createFunctionDoc({
    required String folder,
    String? name,
    String address = '0x140001000',
    String rva = '0x1000',
    String module = 'target.exe',
    String callingConvention = '__fastcall',
    String returnType = 'int',
    String parameters = 'void* this, int flags',
    String purpose = 'Initializes and updates component state',
    String status = 'Investigating',
    String confidence = 'Medium',
    String target = '',
  }) async {
    final cleanName = name?.trim().isNotEmpty == true
        ? name!.trim()
        : 'sub_${address.replaceAll('0x', '')}';
    final body =
        '''# $cleanName

**Address:** `$address` | **RVA:** `$rva` | **Module:** `$module`
**Status:** $status | **Confidence:** $confidence | **Target:** $target

## Prototype
```c
$returnType $callingConvention $cleanName($parameters);
```

## Purpose & Summary
$purpose

## Disassembly Snippet
```asm
$address:  push    rbp
           mov     rbp, rsp
           sub     rsp, 32
           mov     [rbp+16], rcx
           xor     eax, eax
           leave
           ret
```

## Decompiler Notes
- Examines incoming arguments.
- Validates internal state pointer before proceeding.

## Cross References
- **Calls:** None
- **Called By:** 

## Related Structures
- 

## Notes & Observations
- 
''';

    return create(
      'orbit.note',
      title: cleanName,
      body: body,
      properties: {
        'folder': folder,
        if (target.isNotEmpty) 'target': target,
        'category': 'Function',
        'address': address,
        'rva': rva,
        'module': module,
        'callingConvention': callingConvention,
        'returnType': returnType,
        'parameters': parameters,
        'purpose': purpose,
        'status': status,
        'confidence': confidence,
      },
    );
  }

  Future<UniversalObject?> createStructureDoc({
    required String folder,
    String? name,
    String size = '0x48',
    String module = 'target.exe',
    String confidence = 'High',
    String target = '',
  }) async {
    final cleanName = name?.trim().isNotEmpty == true
        ? name!.trim()
        : 'PlayerStruct';
    final body =
        '''# $cleanName

**Size:** `$size` bytes | **Module:** `$module` | **Confidence:** $confidence
**Target:** $target | **Date:** ${calendarDate(DateTime.now())}

## Memory Layout
| Offset | Type | Field Name | Description |
|---|---|---|---|
| `+0x00` | `void*` | `vtable` | Virtual method table pointer |
| `+0x08` | `int32_t` | `health` | Current player health value |
| `+0x0C` | `int32_t` | `maxHealth` | Maximum health cap |
| `+0x10` | `float[3]` | `position` | World coordinates (X, Y, Z) |
| `+0x1C` | `float[3]` | `velocity` | Current movement velocity |
| `+0x28` | `void*` | `inventory` | Pointer to InventoryComponent |

## Struct Definition
```c
struct $cleanName {
    void* vtable;
    int32_t health;
    int32_t maxHealth;
    float position[3];
    float velocity[3];
    void* inventory;
};
```

## Related Functions
- Writes: [[PlayerUpdate]]
- Reads: [[DamageHandler]]
''';

    return create(
      'orbit.note',
      title: cleanName,
      body: body,
      properties: {
        'folder': folder,
        if (target.isNotEmpty) 'target': target,
        'category': 'Structure',
        'size': size,
        'module': module,
        'confidence': confidence,
      },
    );
  }

  Future<UniversalObject?> createFindingDoc({
    required String folder,
    String? title,
    String target = '',
    String category = 'Logic',
    String status = 'Confirmed',
    String confidence = 'High',
    String evidence = 'Observed writes in debugger memory watch at +0x10.',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Finding — Component State';
    final body =
        '''# $cleanTitle

**Target:** $target | **Category:** $category
**Status:** $status | **Confidence:** $confidence | **Date:** ${calendarDate(DateTime.now())}

## Summary
Brief description of the verified architectural or reverse-engineered fact.

## Evidence & Verification
$evidence

## Related Functions & Structures
- Function: 
- Structure: 

## Impact & Next Steps
- 
''';

    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (target.isNotEmpty) 'target': target,
        'category': 'Finding',
        'status': status,
        'confidence': confidence,
      },
    );
  }

  Future<UniversalObject?> createHypothesisDoc({
    required String folder,
    String? title,
    String target = '',
    String hypothesis =
        'Network message 0x14 synchronizes player position and velocity.',
    String confidence = 'Medium',
    String status = 'Testing',
    String nextExperiment =
        'Filter packet capture on opcode 0x14 and correlate with movement input.',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Hypothesis — Opcode 0x14';
    final body =
        '''# $cleanTitle

**Target:** $target | **Status:** $status | **Confidence:** $confidence
**Date:** ${calendarDate(DateTime.now())}

## Hypothesis
$hypothesis

## Evidence For
- Packet length matches `sizeof(Vector3) + sizeof(Vector3) + 4`.
- Emitted each time player keyboard input changes vector.

## Evidence Against
- Also sent intermittently when standing completely idle.

## Next Experiment
$nextExperiment

## Resolution & Conclusion
- 
''';

    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (target.isNotEmpty) 'target': target,
        'category': 'Hypothesis',
        'status': status,
        'confidence': confidence,
      },
    );
  }

  Future<UniversalObject?> createAnalysisSessionDoc({
    required String folder,
    String? title,
    String target = '',
    String tool = 'x64dbg / Ghidra',
    String goal = 'Trace player damage calculation call chain',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Session — ${calendarDate(DateTime.now())}';
    final body =
        '''# $cleanTitle

**Target:** $target | **Tool:** $tool | **Date:** ${calendarDate(DateTime.now())}
**Goal:** $goal

## Inspected Addresses & Functions
- `0x140023400`: Entry point to hit resolution
- `0x140023520`: Armour reduction calculation

## Breakpoints & Observation Log
- `0x140023400`: Breakpoint hit on collision event.
  - `rcx` holds pointer to Attacker object.
  - `rdx` holds pointer to Victim object.
  - `r8d` holds raw damage scalar (e.g. 50).

## Findings Generated
- Damage is calculated in float arithmetic before subtracting from health int.

## Next Steps
- Trace caller of `0x140023400` back to physics sweep.
''';

    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (target.isNotEmpty) 'target': target,
        'category': 'Analysis Session',
        'tool': tool,
      },
    );
  }

  Future<UniversalObject?> createStaticAnalysisSessionDoc({
    required String folder,
    String? title,
    String target = '',
    String tool = 'Ghidra',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Static Analysis — ${calendarDate(DateTime.now())}';
    final body =
        '''# $cleanTitle

**Target:** $target | **Tool:** $tool | **Date:** ${calendarDate(DateTime.now())}

## Entry Point & Headers
- Entry Point RVA: `0x1000`
- Base Address: `0x140000000`
- Subsystem: Windows GUI

## Imports & Libraries of Interest
- `ws2_32.dll`: `connect`, `send`, `recv`
- `kernel32.dll`: `CreateFileW`, `VirtualAlloc`

## Notable Strings
- `"Connecting to server %s:%d"`
- `"Invalid player session state"`

## Decompiled Observations
- Function `sub_140015A00` allocates 4096 bytes and sets up socket circular buffer.
''';

    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (target.isNotEmpty) 'target': target,
        'category': 'Static Analysis Session',
        'tool': tool,
      },
    );
  }

  Future<UniversalObject?> createDynamicAnalysisSessionDoc({
    required String folder,
    String? title,
    String target = '',
    String tool = 'x64dbg',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Runtime Analysis — ${calendarDate(DateTime.now())}';
    final body =
        '''# $cleanTitle

**Target:** $target | **Tool:** $tool | **Date:** ${calendarDate(DateTime.now())}

## Environment & Setup
- OS: Windows 11 Enterprise (Analysis VM)
- Debugger: $tool with anti-detection plugins enabled
- Target PID: Observed in task manager

## Observed Behavior & Calls
- Spawned child thread at `0x140089200`.
- Continuous loop polling input states every 16ms.

## Memory Watch
- Address `0x140B82010` increments by 1 on each render frame.
''';

    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (target.isNotEmpty) 'target': target,
        'category': 'Dynamic Analysis Session',
        'tool': tool,
      },
    );
  }

  Future<UniversalObject?> createBinarySampleDoc({
    required String folder,
    String? name,
    String fileType = 'PE64',
    String architecture = 'x86-64',
    String platform = 'Windows',
    String sha256 = '',
    String md5 = '',
    String source = 'Authorized Security Review',
    String classification = 'Legitimate Executable',
    String target = '',
  }) async {
    final cleanName = name?.trim().isNotEmpty == true
        ? name!.trim()
        : 'Sample.bin';
    final body =
        '''# $cleanName — Binary Sample Record

**File Type:** $fileType | **Architecture:** $architecture | **Platform:** $platform
**Classification:** $classification | **Source:** $source

## Hashes & Identifiers
- **SHA-256:** `${sha256.isEmpty ? "Pending calculation" : sha256}`
- **MD5:** `${md5.isEmpty ? "Pending calculation" : md5}`
- **Compilation Timestamp:** 

## Protection & Packing Analysis
- **Entropy:** Normal (< 6.8)
- **Packer:** None detected / Native MSVC
- **Symbols Available:** No (Stripped)
''';

    return create(
      'orbit.note',
      title: cleanName,
      body: body,
      properties: {
        'folder': folder,
        if (target.isNotEmpty) 'target': target,
        'category': 'Binary Sample',
        'fileType': fileType,
        'architecture': architecture,
        'platform': platform,
        'sha256': sha256,
        'md5': md5,
      },
    );
  }

  Future<UniversalObject?> createExperimentDoc({
    required String folder,
    String? title,
    String target = '',
    String question = 'Does patching offset 0x4A20 bypass CRC check?',
    String setup = 'Target v1.0 running under testbed',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Experiment — CRC Validation';
    final body =
        '''# $cleanTitle

**Target:** $target | **Date:** ${calendarDate(DateTime.now())}

## Research Question
$question

## Setup & Baseline
$setup

## Change Applied in Test Environment
- Changed conditional jump `jne 0x140004B00` to `nop; nop`.

## Expected Observation
- Client processes modified configuration file without throwing initialization error 0x8004.

## Actual Observation
- Initialization error bypassed; however subsequent packet checksum failed on connection.

## Conclusion & Evidence
- Configuration check is verified local, but server independently checks hash.
''';

    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (target.isNotEmpty) 'target': target,
        'category': 'Experiment',
      },
    );
  }

  Future<UniversalObject?> createProtocolAnalysisDoc({
    required String folder,
    String? title,
    String target = '',
    String transport = 'UDP',
    String direction = 'Bidirectional',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Protocol Analysis — Game State';
    final body =
        '''# $cleanTitle

**Target:** $target | **Transport:** $transport | **Direction:** $direction
**Date:** ${calendarDate(DateTime.now())}

## Overview & Framing
- Transport Protocol: $transport
- Header Size: 4 bytes (Magic `0x4F42`, Opcode 2 bytes)
- Endianness: Little-Endian

## Message Types Breakdown
| Opcode | Name | Direction | Payload Size | Purpose |
|---|---|---|---|---|
| `0x0001` | `MsgConnect` | Client → Server | 32 B | Handshake |
| `0x0002` | `MsgConnectAck` | Server → Client | 8 B | Handshake response |
| `0x0010` | `MsgPlayerMove` | Client → Server | 24 B | Position and speed update |

## Example Payload
```hex
4F 42 10 00 00 00 80 3F 00 00 00 40 00 00 00 00
```
''';

    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (target.isNotEmpty) 'target': target,
        'category': 'Protocol Analysis',
        'transport': transport,
      },
    );
  }

  Future<UniversalObject?> createPacketStructureDoc({
    required String folder,
    String? title,
    String target = '',
    String messageId = '0x0010',
    String direction = 'Client → Server',
    String length = '24 bytes',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Packet — $messageId (PlayerMove)';
    final body =
        '''# $cleanTitle

**Message ID:** `$messageId` | **Direction:** $direction | **Length:** $length
**Target:** $target

## Field Breakdown
| Offset | Size | Type | Field Name | Description |
|---|---|---|---|---|
| `+0x00` | 2 B | `uint16_t` | `magic` | Header magic (`0x4F42`) |
| `+0x02` | 2 B | `uint16_t` | `opcode` | Message ID (`$messageId`) |
| `+0x04` | 4 B | `uint32_t` | `sequence` | Packet sequence counter |
| `+0x08` | 4 B | `float` | `posX` | X position float |
| `+0x0C` | 4 B | `float` | `posY` | Y position float |
| `+0x10` | 4 B | `float` | `posZ` | Z position float |
| `+0x14` | 4 B | `uint32_t` | `flags` | State flags (grounded, jumping) |

## Handler Function
- Client Sender: [[SendMovementUpdate]]
- Server Handler: [[HandlePlayerMove]]
''';

    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (target.isNotEmpty) 'target': target,
        'category': 'Packet Structure',
        'messageId': messageId,
      },
    );
  }

  Future<UniversalObject?> createPeAnalysisDoc({
    required String folder,
    String? title,
    String target = '',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'PE Header Analysis — $target';
    final body =
        '''# $cleanTitle

**Target:** $target | **Date:** ${calendarDate(DateTime.now())}

## DOS & NT Headers
- Signature: `IMAGE_NT_SIGNATURE` (`PE\\0\\0`)
- Machine: `IMAGE_FILE_MACHINE_AMD64` (`0x8664`)
- Number of Sections: 5
- Time Date Stamp: 

## Optional Header
- Magic: `IMAGE_NT_OPTIONAL_HDR64_MAGIC` (`0x020B`)
- Address of Entry Point: `0x000124A0`
- Image Base: `0x0000000140000000`
- Subsystem: `IMAGE_SUBSYSTEM_WINDOWS_GUI`

## Section Headers Table
| Name | Virtual Size | Virtual Address | Raw Size | Characteristics |
|---|---|---|---|---|
| `.text` | `0x00045000` | `0x00001000` | `0x00045000` | Code, Execute, Read |
| `.rdata` | `0x00021000` | `0x00046000` | `0x00021000` | Initialized Data, Read |
| `.data` | `0x0000A000` | `0x00067000` | `0x00008000` | Initialized Data, Read, Write |
| `.pdata` | `0x00004000` | `0x00071000` | `0x00004000` | Exception directory, Read |
| `.rsrc` | `0x00002000` | `0x00075000` | `0x00002000` | Resources, Read |
''';

    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (target.isNotEmpty) 'target': target,
        'category': 'PE Analysis',
      },
    );
  }

  Future<UniversalObject?> createFileFormatDoc({
    required String folder,
    String? title,
    String target = '',
    String magic = '42 49 4E 31',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'File Format Analysis — Asset Archive';
    final body =
        '''# $cleanTitle

**Target:** $target | **Magic:** `$magic` | **Date:** ${calendarDate(DateTime.now())}

## Magic & Header Layout
- Signature Bytes: `$magic` (ASCII `"BIN1"`)
- Version: `1.0`
- Compression: Zstandard (zstd) / Deflate

## Record Format
| Offset | Field Name | Type | Meaning |
|---|---|---|---|
| `+0x00` | `magic` | `char[4]` | Container identifier |
| `+0x04` | `version` | `uint32_t` | Format revision number |
| `+0x08` | `entryCount` | `uint32_t` | Number of files indexed |
| `+0x0C` | `tableOffset` | `uint64_t` | Offset to table of contents |
''';

    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (target.isNotEmpty) 'target': target,
        'category': 'File Format',
      },
    );
  }

  Future<UniversalObject?> createGameSystemDoc({
    required String folder,
    String? name,
    String target = '',
    String purpose = 'Manages player state, inventory, and equipment',
  }) async {
    final cleanName = name?.trim().isNotEmpty == true
        ? name!.trim()
        : 'Player System';
    final body =
        '''# $cleanName

**Target:** $target | **Category:** Game System
**Purpose:** $purpose

## System Overview & Architecture
High level description of how this system operates within the game loop.

## Key Entry Points & Functions
- [[PlayerUpdate]]
- [[PlayerInventoryInit]]

## Related Structures & Classes
- Structure: [[PlayerStruct]]
''';

    return create(
      'orbit.note',
      title: cleanName,
      body: body,
      properties: {
        'folder': folder,
        if (target.isNotEmpty) 'target': target,
        'category': 'Game System',
      },
    );
  }

  Future<UniversalObject?> createGameClassDoc({
    required String folder,
    String? name,
    String target = '',
    String module = 'GameAssembly.dll',
    String address = '0x180023400',
  }) async {
    final cleanName = name?.trim().isNotEmpty == true
        ? name!.trim()
        : 'EntityManager';
    final body =
        '''# $cleanName

**Target:** $target | **Module:** $module | **Base / VTable:** `$address`

## Class Hierarchy & Inheritance
```
MonoBehaviour / Object
  └── GameEntity
        └── $cleanName
```

## Methods Table
| Offset | Method Name | Return Type | Parameters |
|---|---|---|---|
| `+0x00` | `Initialize` | `void` | `void` |
| `+0x08` | `UpdateEntities` | `void` | `float deltaTime` |
| `+0x10` | `GetEntityById` | `void*` | `int32_t id` |
''';

    return create(
      'orbit.note',
      title: cleanName,
      body: body,
      properties: {
        'folder': folder,
        if (target.isNotEmpty) 'target': target,
        'category': 'Game Class',
        'address': address,
        'module': module,
      },
    );
  }

  Future<UniversalObject?> createTransformCoordinateDoc({
    required String folder,
    String? title,
    String target = '',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Coordinate & Transform System';
    final body =
        '''# $cleanTitle

**Target:** $target | **Date:** ${calendarDate(DateTime.now())}

## Coordinate System Conventions
- **Handedness:** Left-Handed (DirectX style)
- **Up Axis:** Y-Up (+Y is Up, +Z is Forward, +X is Right)
- **World Units:** 1 Unit = 1 Meter

## Matrices & Transforms
- View Matrix: 4x4 Row-Major Float
- Projection Matrix: Perspective (FOV 60°, Near 0.1, Far 1000.0)

## Related Functions
- [[UpdateCameraMatrices]]
- [[WorldToScreen]]
''';

    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (target.isNotEmpty) 'target': target,
        'category': 'Coordinate System',
      },
    );
  }

  Future<UniversalObject?> createMalwareTriageDoc({
    required String folder,
    String? title,
    String target = '',
    String sha256 = '',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Malware Triage — $target';
    final body =
        '''# $cleanTitle

**Target:** $target | **SHA-256:** `$sha256`
**Analysis Type:** Defensive Lab Triage | **Date:** ${calendarDate(DateTime.now())}

## 1. Initial Assessment
- Threat Level: High
- Suspected Actor / Family: Unknown / Commodity

## 2. Suspicious APIs Observed
- `VirtualAllocEx`, `WriteProcessMemory`, `CreateRemoteThread`
- `RegSetValueExW` (Run key)

## 3. Network Indicators
- C2 IP: `198.51.100.45:8080`
- Domain: `update-service-check.net`
''';

    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (target.isNotEmpty) 'target': target,
        'category': 'Malware Triage',
        'sha256': sha256,
      },
    );
  }

  Future<UniversalObject?> createBehaviorObservationDoc({
    required String folder,
    String? title,
    String target = '',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Behavior Observation — Process Lifecycle';
    final body =
        '''# $cleanTitle

**Target:** $target | **Date:** ${calendarDate(DateTime.now())}

## Processes Observed
- `sample.exe` (PID 4820)
  - Spawns `cmd.exe /c ping 127.0.0.1 -n 3` (evasion delay)
  - Drops and launches `updater.exe` into `%TEMP%`

## File Activity
- Created: `%APPDATA%\\Roaming\\Config\\service.dat`
- Modified: None

## Registry Changes
- Value set: `HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run\\ServiceUpdate`
''';

    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (target.isNotEmpty) 'target': target,
        'category': 'Behavior Observation',
      },
    );
  }

  Future<UniversalObject?> createIocDoc({
    required String folder,
    required String value,
    String type = 'IP Address',
    String? iocType,
    String confidence = 'High',
    String context = 'Observed outbound HTTP POST beacon',
    String? contextInfo,
    String relatedSample = '',
    String? target,
  }) async {
    final cleanValue = value.trim();
    final effectiveType = iocType ?? type;
    final effectiveContext = contextInfo ?? context;
    final effectiveTarget = (target != null && target.isNotEmpty)
        ? target
        : relatedSample;
    final body =
        '''# Indicator: $cleanValue

**Indicator Type:** $effectiveType | **Confidence:** $confidence
**Related Sample:** $effectiveTarget | **First Observed:** ${calendarDate(DateTime.now())}

## Context & Observation
$effectiveContext

## Detection & Mitigation Notes
- Block outbound traffic on gateway firewall.
- Correlate in SIEM with endpoint logs.
''';

    return create(
      'orbit.note',
      title: cleanValue,
      body: body,
      properties: {
        'folder': folder,
        if (effectiveTarget.isNotEmpty) 'target': effectiveTarget,
        'category': 'Indicator',
        'value': cleanValue,
        'iocType': effectiveType,
        'confidence': confidence,
        'context': effectiveContext,
      },
    );
  }

  Future<UniversalObject?> createDetectionRuleDoc({
    required String folder,
    String? title,
    String ruleType = 'YARA',
    String goal = 'Detect unpacked binary in memory',
    String ruleContent = '',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Detection Rule — ${ruleType.toUpperCase()}';
    final defaultRule = ruleType.toUpperCase() == 'YARA'
        ? '''rule Detect_Sample_Anomaly {
    meta:
        author = "Security Researcher"
        date = "${calendarDate(DateTime.now())}"
        description = "Detects characteristic pattern observed in memory"
    strings:
        \$magic = "CustomHeader"
        \$pattern = { 48 8B 81 30 01 00 00 48 85 C0 74 }
    condition:
        all of them
}'''
        : '''title: Suspicious Process Execution
status: experimental
description: Detects command spawned from temp folder
logsource:
    category: process_creation
    product: windows
detection:
    selection:
        Image|startswith: 'C:\\Users\\*\\AppData\\Local\\Temp\\'
    condition: selection
''';

    final body =
        '''# $cleanTitle

**Rule Type:** $ruleType | **Objective:** $goal
**Date:** ${calendarDate(DateTime.now())}

## Rule Definition
```${ruleType.toLowerCase()}
${ruleContent.isNotEmpty ? ruleContent : defaultRule}
```

## False Positive Considerations
- Validate against benign software base.
''';

    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        'category': 'Detection Rule',
        'ruleType': ruleType,
      },
    );
  }

  Future<UniversalObject?> createVersionComparisonDoc({
    required String folder,
    String? title,
    String target = '',
    String oldBuild = 'v1.0.0',
    String newBuild = 'v1.1.0',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Version Comparison — $oldBuild vs $newBuild';
    final body =
        '''# $cleanTitle

**Target:** $target | **Old Build:** $oldBuild | **New Build:** $newBuild
**Date:** ${calendarDate(DateTime.now())}

## Address & Function Shifts
| Function Name | $oldBuild Address | $newBuild Address | Delta | Status |
|---|---|---|---|---|
| `PlayerUpdate` | `0x140012340` | `0x140012580` | `+0x240` | Verified |
| `DamageHandler` | `0x140024A00` | `0x140024B20` | `+0x120` | Verified |

## Structure & Field Changes
- `PlayerStruct`: Field added at `+0x30` (`uint32_t stamina`).

## Deprecated & Unchanged Findings
- Network packet structure unchanged.
''';

    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        if (target.isNotEmpty) 'target': target,
        'category': 'Version Comparison',
        'oldBuild': oldBuild,
        'newBuild': newBuild,
      },
    );
  }

  Future<UniversalObject?> createInvestigationCaseDoc({
    required String folder,
    String? title,
    String status = 'Active',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Incident Case 001';
    final body =
        '''# $cleanTitle

**Status:** $status | **Date:** ${calendarDate(DateTime.now())}

## Case Overview
Summary of scope, affected endpoints, and timeline of investigation.

## Artifacts & Samples
- Samples analyzed: [[Sample.bin]]
- Indicators extracted: [[Indicators]]

## Investigation Tasks
- [ ] Complete memory dump analysis
- [ ] Confirm persistence mechanism
- [ ] Formulate YARA rule
''';

    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        'category': 'Investigation Case',
        'status': status,
      },
    );
  }

  Future<UniversalObject?> createAnalysisEnvironmentDoc({
    required String folder,
    String? title,
    String vm = 'Sandbox-Win11',
    String os = 'Windows 11 Enterprise 23H2',
    String snapshot = 'Clean-Baseline-01',
    String tools = 'x64dbg, Ghidra 11.1, Process Hacker, Wireshark',
  }) async {
    final cleanTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Analysis Environment — $vm';
    final body =
        '''# $cleanTitle

**Virtual Machine:** $vm | **Guest OS:** $os
**Baseline Snapshot:** $snapshot | **Tools:** $tools

## Network Configuration
- Host-Only / Isolated Sandbox (No internet access)
- INetSim gateway for simulated services

## Reproducibility Checklist
- [ ] Revert to snapshot `$snapshot` before running dynamic traces
''';

    return create(
      'orbit.note',
      title: cleanTitle,
      body: body,
      properties: {
        'folder': folder,
        'category': 'Analysis Environment',
        'vm': vm,
      },
    );
  }

  // -------------------------------------------------------------
  // ATTACHMENT HASHING & METADATA IMPORT UTILITIES
  // -------------------------------------------------------------

  Future<String?> calculateAttachmentSha256(UniversalObject fileObj) async {
    if (find(fileObj.id) == null) {
      mergeRepositoryObjects();
    }
    final currentObj = find(fileObj.id) ?? fileObj;
    final cached = currentObj.properties['sha256'] as String?;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final contentRef = currentObj.properties['contentRef'] as String?;
    if (contentRef == null || contentRef.isEmpty) return null;
    final bytes = await repository.readAttachment(contentRef);
    if (bytes == null) return null;
    final hashStr = sha256.convert(bytes).toString();
    final md5Str = md5.convert(bytes).toString();
    if (find(currentObj.id) == null) {
      objects = [...objects, currentObj];
    }
    edit(
      currentObj.id,
      properties: {
        ...currentObj.properties,
        'sha256': hashStr,
        'md5': md5Str,
        'hashCalculatedAt': DateTime.now().toIso8601String(),
      },
    );
    return hashStr;
  }

  Future<int> importFunctionsFromCsv(
    String csvContent, {
    required String folder,
    String target = '',
  }) async {
    final lines = csvContent
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return 0;

    int imported = 0;
    int nameIdx = 0;
    int addrIdx = 1;
    int modIdx = -1;
    int purposeIdx = -1;
    int statusIdx = -1;
    int confIdx = -1;

    final firstLine = lines.first.toLowerCase();
    final hasHeader =
        firstLine.contains('name') || firstLine.contains('address');
    final startIndex = hasHeader ? 1 : 0;

    if (hasHeader) {
      final headerCols = lines.first
          .split(',')
          .map((c) => c.trim().toLowerCase())
          .toList();
      nameIdx = headerCols.indexOf('name');
      if (nameIdx == -1) nameIdx = 0;
      addrIdx = headerCols.indexOf('address');
      if (addrIdx == -1) addrIdx = headerCols.indexOf('rva');
      if (addrIdx == -1) addrIdx = 1;
      modIdx = headerCols.indexOf('module');
      purposeIdx = headerCols.indexOf('purpose');
      if (purposeIdx == -1) purposeIdx = headerCols.indexOf('comment');
      statusIdx = headerCols.indexOf('status');
      confIdx = headerCols.indexOf('confidence');
    }

    for (var i = startIndex; i < lines.length; i++) {
      final cols = lines[i].split(',').map((c) => c.trim()).toList();
      if (cols.isEmpty) continue;
      final name = cols.length > nameIdx ? cols[nameIdx] : 'Function_$i';
      final addr = cols.length > addrIdx ? cols[addrIdx] : '0x0';
      final mod = modIdx != -1 && cols.length > modIdx
          ? cols[modIdx]
          : 'target.exe';
      final purpose = purposeIdx != -1 && cols.length > purposeIdx
          ? cols[purposeIdx]
          : '';
      final status = statusIdx != -1 && cols.length > statusIdx
          ? cols[statusIdx]
          : 'Investigating';
      final conf = confIdx != -1 && cols.length > confIdx
          ? cols[confIdx]
          : 'Medium';

      await createFunctionDoc(
        folder: folder,
        name: name,
        address: addr,
        module: mod,
        purpose: purpose.isNotEmpty ? purpose : 'Imported function',
        status: status,
        confidence: conf,
        target: target,
      );
      imported++;
    }
    return imported;
  }

  Future<int> importFunctionsFromJson(
    String jsonContent, {
    required String folder,
    String target = '',
  }) async {
    int imported = 0;
    try {
      final decoded = jsonDecode(jsonContent);
      final List list = switch (decoded) {
        List l => l,
        Map m when m['functions'] is List => m['functions'] as List,
        _ => const [],
      };
      for (final item in list) {
        if (item is! Map) continue;
        final name = item['name']?.toString() ?? 'Function';
        final addr =
            item['address']?.toString() ?? item['rva']?.toString() ?? '0x0';
        final mod = item['module']?.toString() ?? 'target.exe';
        final purpose =
            item['purpose']?.toString() ?? item['comment']?.toString() ?? '';
        final status = item['status']?.toString() ?? 'Investigating';
        final conf = item['confidence']?.toString() ?? 'Medium';

        await createFunctionDoc(
          folder: folder,
          name: name,
          address: addr,
          module: mod,
          purpose: purpose.isNotEmpty ? purpose : 'Imported function',
          status: status,
          confidence: conf,
          target: target,
        );
        imported++;
      }
    } catch (_) {}
    return imported;
  }

  bool isArchivedFolder(String folder) => session.archivedFolders.any(
    (f) => folder == f || folder.startsWith('$f/'),
  );

  void archiveFolder(String folder) {
    if (!session.archivedFolders.contains(folder)) {
      session.archivedFolders.add(folder);
      persistSession();
      notify();
    }
  }

  void restoreFolder(String folder) {
    if (session.archivedFolders.remove(folder)) {
      persistSession();
      notify();
    }
  }

  Future<UniversalObject?> duplicateView(String viewId) async {
    final view = find(viewId);
    if (view == null) return null;
    return create(
      'orbit.view',
      title: '${view.title} (Copy)',
      properties: Map<String, dynamic>.from(view.properties),
    );
  }

  Future<bool> moveObjectToFolder(String id, String folder) =>
      moveObjectsToFolder([id], folder);

  Future<bool> moveObjectsToFolder(Iterable<String> ids, String folder) =>
      organize(() => repository.moveObjectsToFolder(ids, folder));

  Future<bool> moveFolder(String source, String target) => organize(() async {
    await repository.moveFolder(source, target);
    session.archivedFolders = [
      for (final folder in session.archivedFolders)
        if (folder == source || folder.startsWith('$source/'))
          '$target${folder.substring(source.length)}'
        else
          folder,
    ];
    persistSession();
  });

  Future<bool> savePdfFormField(
    String id,
    String checksum,
    String key,
    Object value,
  ) async {
    final file = find(id);
    if (file == null ||
        file.isDeleted ||
        file.isReadOnly ||
        repository.readOnly ||
        file.typeId != 'orbit.file' ||
        file.properties['mimeType'] != 'application/pdf' ||
        file.properties['checksum'] != checksum ||
        !RegExp(r'^[1-9][0-9]{0,5}:[0-9]{1,5}$').hasMatch(key) ||
        (value is! bool && value is! String) ||
        (value is String && value.length > 10000)) {
      return false;
    }
    final draft = file.properties['pdfFormDraft'];
    if (draft is Map &&
        (draft['checksum'] != checksum || draft['version'] != 1)) {
      return false;
    }
    final values = draft is Map && draft['values'] is Map
        ? Map<String, dynamic>.from(draft['values'] as Map)
        : <String, dynamic>{};
    if (values.length >= 2000 && !values.containsKey(key)) return false;
    edit(
      id,
      properties: {
        ...file.properties,
        'pdfFormDraft': {
          if (draft is Map) ...Map<String, dynamic>.from(draft),
          'version': 1,
          'checksum': checksum,
          'values': {...values, key: value},
        },
      },
    );
    await flush(id);
    return !dirty.contains(id) && !failures.containsKey(id);
  }

  Future<UniversalObject?> createPdfQuote(
    String fileId,
    int page,
    String quote, {
    ResearchDocument? document,
  }) async {
    final file = find(fileId);
    if (file == null ||
        file.isDeleted ||
        file.isReadOnly ||
        repository.readOnly ||
        file.typeId != 'orbit.file' ||
        file.properties['mimeType'] != 'application/pdf' ||
        page < 1 ||
        page > 999999 ||
        quote.length > 100000 ||
        (document == null && quote.trim().isEmpty)) {
      return null;
    }
    try {
      final note = await repository.create(
        typeId: 'orbit.note',
        title: document == null
            ? '${file.title} · page $page'
            : '${document.label} · ${file.title} · p. $page',
        body:
            document?.markdown(fileId, file.title, page, quote) ??
            ObjectReference(
              fileId,
              page: page,
            ).quoteMarkdown(file.title, quote),
        properties: {
          'pdfSource': {
            'objectId': fileId,
            'page': page,
            'checksum': file.properties['checksum'],
          },
        },
      );
      objects = [...objects, note];
      error = null;
      openObject(note.id);
      return note;
    } catch (e) {
      error = '$e';
      notify();
      return null;
    }
  }

  Future<UniversalObject?> createPdfHighlight(
    String fileId,
    String checksum,
    String quote,
    List<CanvasElement> regions, {
    String comment = '',
  }) async {
    final file = find(fileId);
    if (file == null ||
        file.isDeleted ||
        file.isReadOnly ||
        repository.readOnly ||
        file.typeId != 'orbit.file' ||
        file.properties['mimeType'] != 'application/pdf' ||
        file.properties['checksum'] != checksum ||
        quote.trim().isEmpty ||
        quote.length > 100000 ||
        regions.isEmpty ||
        regions.length > 10000 ||
        !regions.every(PdfAnnotation.validRegion)) {
      error =
          'The highlight could not be saved: its source or selected regions changed.';
      notify();
      return null;
    }
    try {
      final page = regions.first.data['page'] as int;
      final note = await repository.create(
        typeId: 'orbit.note',
        title: '${file.title} · highlight p. $page',
        body:
            '${ObjectReference(fileId, page: page).quoteMarkdown(file.title, quote)}${comment.trim().isEmpty ? '' : '\n\n$comment'}',
        properties: {
          'pdfHighlightVersion': 1,
          'pdfSource': {
            'objectId': fileId,
            'checksum': checksum,
            'page': page,
            'quote': quote,
            'regions': regions.map((r) => r.data).toList(),
          },
        },
      );
      objects = [...objects, note];
      error = null;
      notify();
      return note;
    } catch (e) {
      error = '$e';
      notify();
      return null;
    }
  }

  void edit(
    String id, {
    String? title,
    String? body,
    Map<String, dynamic>? properties,
    Map<String, dynamic>? data,
  }) {
    final object = find(id);
    if (object == null || object.isReadOnly || repository.readOnly) return;
    final updated = object.copyWith(
      title: title,
      body: body,
      properties: properties,
      data: data,
      updatedAt: DateTime.now().toUtc(),
    );
    if (properties != null &&
        properties['completed'] == true &&
        object.properties['completed'] != true) {
      if (_activeWorkSession != null && _activeWorkSession!.isRecordingActive) {
        _activeWorkSession = _activeWorkSession!.recordTaskCompleted(id);
        session.activeWorkSession = _activeWorkSession!.toJson();
      }
    }
    objects = [
      for (final o in objects)
        if (o.id == id) updated else o,
    ];
    dirty.add(id);
    if (_refreshingExternal) {
      failures[id] =
          'Files changed during this edit. Save a recovered copy to preserve both versions.';
    }
    _timers[id]?.cancel();
    // Conflicts require explicit recovery; retrying every keystroke is unhelpful.
    if (!failures.containsKey(id)) {
      _timers[id] = Timer(const Duration(milliseconds: 450), () => flush(id));
    }
    notify();
  }

  Future<void> flush(String id) async {
    _timers.remove(id)?.cancel();
    final pending = _saving[id];
    if (pending != null) {
      await pending;
      if (dirty.contains(id) && !failures.containsKey(id)) await flush(id);
      return;
    }
    if (!dirty.contains(id)) return;
    final before = find(id);
    if (before == null) return;
    final work = _saveDraft(before);
    _saving[id] = work;
    await work;
    _saving.remove(id);
    if (dirty.contains(id) && !failures.containsKey(id)) await flush(id);
  }

  Future<void> _saveDraft(UniversalObject before) async {
    try {
      final saved = await repository.save(before);
      final current = find(before.id);
      final unchanged = identical(current, before);
      objects = [
        for (final o in objects)
          if (o.id == before.id)
            (unchanged ? saved : o.copyWith(revision: saved.revision))
          else
            o,
      ];
      if (unchanged) dirty.remove(before.id);
      failures.remove(before.id);
    } catch (e) {
      failures[before.id] = '$e';
    }
    notify();
  }

  Future<bool> flushAll() async {
    for (final id in List.of(dirty)) {
      await flush(id);
    }
    await saveSession();
    return dirty.isEmpty && failures.isEmpty && !_settingsSaveFailed;
  }

  Future<void> retry(String id) async {
    failures.remove(id);
    await flush(id);
  }

  Future<void> saveConflictCopy(String id) async {
    final draft = find(id);
    if (draft == null) return;
    try {
      final copy = await repository.create(
        typeId: draft.typeId,
        title: '${draft.title} — recovered copy',
        body: draft.body,
        properties: draft.properties,
        data: draft.data,
      );
      dirty.remove(id);
      failures.remove(id);
      _timers.remove(id)?.cancel();
      await repository.refresh();
      mergeRepositoryObjects();
      openObject(copy.id);
    } catch (e) {
      error = '$e';
      notify();
    }
  }

  Future<void> trash(String id) async {
    await flush(id);
    if (dirty.contains(id)) return;
    try {
      await repository.trash(id);
      mergeRepositoryObjects();
      closeTab(id);
      notify();
    } catch (e) {
      error = '$e';
      notify();
    }
  }

  Future<void> restore(String id) async {
    try {
      await repository.restore(id);
      mergeRepositoryObjects();
      notify();
    } catch (e) {
      error = '$e';
      notify();
    }
  }

  Future<void> deleteFolder(String folder) => organize(() async {
    await repository.deleteFolder(folder);
    session.archivedFolders.removeWhere(
      (f) => f == folder || f.startsWith('$folder/'),
    );
    persistSession();
  });

  Future<void> deletePermanently(String id) async {
    await flush(id);
    try {
      await repository.deletePermanently(id);
      mergeRepositoryObjects();
      closeTab(id);
      notify();
    } catch (e) {
      error = '$e';
      notify();
    }
  }

  Future<void> emptyTrash() async {
    try {
      await repository.emptyTrash();
      mergeRepositoryObjects();
      notify();
    } catch (e) {
      error = '$e';
      notify();
    }
  }

  bool get showAttachments => session.showAttachments;
  void toggleShowAttachments() =>
      updateSession((s) => s.showAttachments = !s.showAttachments);

  Future<void> refresh() async {
    if (!await flushAll()) return;
    try {
      await repository.refresh();
      mergeRepositoryObjects();
      error = null;
    } catch (e) {
      error = '$e';
    }
    notify();
  }

  Future<void> checkExternalChanges({Set<String>? changedPaths}) async {
    if (_checkingExternal) {
      _changedPaths.addAll(changedPaths ?? {'*'});
      return;
    }
    if (loading ||
        !_hasWorkspace ||
        _checkingExternal ||
        repository.isBrowser) {
      return;
    }
    _checkingExternal = true;
    try {
      if (!await repository.hasExternalChanges(changedPaths: changedPaths)) {
        return;
      }
      if (dirty.isNotEmpty || _saving.isNotEmpty) {
        externalChangesPending = true;
        error =
            'Files changed outside Orbit. Your draft is retained; save or recover it before reloading.';
        notify();
        return;
      }
      _refreshingExternal = true;
      await repository.refresh();
      mergeRepositoryObjects();
      externalChangesPending = false;
      notify();
    } catch (e) {
      error = 'Could not check external files: $e';
      notify();
    } finally {
      _refreshingExternal = false;
      _checkingExternal = false;
      if (_changedPaths.isNotEmpty && _alive) {
        _externalDebounce?.cancel();
        _externalDebounce = Timer(const Duration(milliseconds: 400), () {
          final paths = Set<String>.of(_changedPaths);
          _changedPaths.clear();
          checkExternalChanges(changedPaths: paths);
        });
      }
    }
  }

  void updateSession(void Function(SessionState) change) {
    change(session);
    persistSession();
    notify();
  }

  void persistSession() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(const Duration(milliseconds: 600), saveSession);
  }

  Future<void> saveSession() async {
    _sessionTimer?.cancel();
    if (loading || !_hasWorkspace || repository.readOnly) return;
    _settingsSaveRequested = true;
    final pending = _settingsSave;
    if (pending != null) return pending;
    final operation = _saveSessionQueue();
    _settingsSave = operation;
    try {
      await operation;
    } finally {
      _settingsSave = null;
    }
  }

  Future<void> _saveSessionQueue() async {
    savingSettings = true;
    try {
      while (_settingsSaveRequested) {
        _settingsSaveRequested = false;
        await repository.writeDeviceSettings(session.toJson());
      }
      _settingsSaveFailed = false;
    } catch (e) {
      _settingsSaveFailed = true;
      error = 'Could not save workspace layout: $e';
      notify();
    } finally {
      savingSettings = false;
    }
  }

  void resetLayout() => updateSession((s) {
    s.sidebarVisible = true;
    s.inspectorVisible = false;
    s.sidebarWidth = 240;
    s.secondaryId = null;
  });
}
