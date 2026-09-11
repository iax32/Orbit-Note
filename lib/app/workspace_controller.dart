import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/workspace_repository.dart';
import '../domain/calendar_event.dart';
import '../domain/universal_object.dart';
import '../domain/object_reference.dart';
import '../domain/pdf_annotation.dart';
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

  void closeTab(String id) {
    lastClosed = id;
    session.tabs = session.tabs.where((v) => v != id).toList();
    if (session.activeId == id) session.activeId = session.tabs.lastOrNull;
    if (session.secondaryId == id) session.secondaryId = null;
    persistSession();
    notify();
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
    final tabs = List.of(session.tabs);
    tabs.insert(newIndex, tabs.removeAt(oldIndex));
    session.tabs = tabs;
    persistSession();
    notify();
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

  Future<UniversalObject?> create(String type, {String? title}) async {
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
              _ => 'Untitled note',
            },
        properties: switch (type) {
          'orbit.task' => {'completed': false, 'priority': 'medium'},
          'orbit.event' => {
            'allDay': true,
            'startDate': today,
            'endDate': tomorrow,
          },
          _ => const {},
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

  Future<UniversalObject?> createPdfQuote(
    String fileId,
    int page,
    String quote,
  ) async {
    final file = find(fileId);
    if (file == null ||
        file.isDeleted ||
        file.typeId != 'orbit.file' ||
        file.properties['mimeType'] != 'application/pdf' ||
        page < 1 ||
        page > 999999 ||
        quote.trim().isEmpty) {
      return null;
    }
    try {
      final note = await repository.create(
        typeId: 'orbit.note',
        title: '${file.title} · page $page',
        body: ObjectReference(
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
