import 'dart:async';

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

  Future<void> initialize({String? path}) async {
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

  Future<void> organize(Future<void> Function() command) async {
    if (loading) return;
    if (!await flushAll()) return;
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
    if (path != null) {
      session.collapsedFolders = session.collapsedFolders
          .where((folder) => !path.startsWith('$folder/'))
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
    session.destination = switch (object.typeId) {
      'orbit.canvas' => OrbitDestination.canvas,
      'orbit.task' => OrbitDestination.tasks,
      'orbit.event' => OrbitDestination.calendar,
      _ => OrbitDestination.notes,
    };
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
    await repository.createFolder(courseFolder);
    await repository.createFolder('$courseFolder/Lectures');
    await repository.createFolder('$courseFolder/Exercises');
    await repository.createFolder('$courseFolder/Exam Preparation');

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
    await repository.createFolder(projectFolder);
    await repository.createFolder('$projectFolder/Design');
    await repository.createFolder('$projectFolder/Art');
    await repository.createFolder('$projectFolder/Programming');
    await repository.createFolder('$projectFolder/Audio');
    await repository.createFolder('$projectFolder/Production');
    await repository.createFolder('$projectFolder/Playtests');

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

    // 4. Create Canvases: Core Loop & Moodboard
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

  Future<void> moveObjectToFolder(String id, String folder) async {
    final obj = find(id);
    if (obj == null) return;
    if (obj.typeId == 'orbit.note') {
      try {
        await repository.moveNote(id, folder);
      } catch (_) {}
    }
    edit(id, properties: {...obj.properties, 'folder': folder});
  }

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

  Future<void> deleteFolder(String folder) =>
      organize(() => repository.deleteFolder(folder));

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
