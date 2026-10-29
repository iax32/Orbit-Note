import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../application/workspace_repository.dart';
import '../domain/backlinks.dart';
import '../domain/calendar_event.dart';
import '../domain/calendar_planning.dart';
import '../domain/event_recurrence.dart';
import '../domain/universal_object.dart';
import '../domain/portable_preferences.dart';
import '../domain/workspace_failure.dart';
import '../domain/object_reference.dart';
import '../domain/orbit_search.dart';
import '../domain/document_anchors.dart';
import '../application/workspace_search.dart';
import '../application/search_execution.dart';
import '../application/pdf_search_indexer.dart';
import '../domain/pdf_search.dart';
import '../platform/pdf_text_extraction.dart';
import '../platform/ocr_pages.dart';
import '../domain/ocr_document.dart';
import '../domain/object_discovery.dart';
import '../domain/pdf_annotation.dart';
import '../domain/pdf_review_batch.dart';
import '../domain/research_document.dart';
import '../domain/research_workspace.dart';
import '../domain/reverse_engineering.dart';
import '../domain/research_comparison.dart';
import '../domain/source_browser.dart';
import '../canvas/scene.dart';
import '../canvas/diagram_reference.dart';
import '../domain/wiki_links.dart';
import '../domain/search_text.dart';
import '../domain/work_session.dart';
import '../domain/project_context.dart';
import 'session_state.dart';
import 'canvas_performance.dart';
import '../domain/smart_view_query.dart';
import '../domain/task_planning.dart';
import '../domain/gantt_planning.dart';
import '../domain/working_calendar.dart';
import '../domain/workspace_context.dart';
import '../domain/study_card.dart';
import '../domain/gameplay_workbench.dart';
import '../domain/gameplay_release.dart';
import '../domain/model_asset.dart';
import '../domain/course_progress.dart';
import '../domain/json_values.dart';
import '../domain/object_connections.dart';
import '../domain/note_composition.dart';
import '../domain/life_workspace.dart';
import '../domain/life_templates.dart';
import '../domain/finance.dart';
import '../domain/research_dossier.dart';

part 'workspace_productivity.dart';
part 'workspace_tab_recovery.dart';
part 'workspace_courses.dart';
part 'workspace_editor_drafts.dart';
part 'workspace_reference_bridges.dart';
part 'workspace_project_context.dart';
part 'workspace_ocr.dart';
part 'workspace_study.dart';
part 'workspace_study_resume.dart';
part 'workspace_calendar_planning.dart';
part 'workspace_creative.dart';
part 'workspace_research.dart';
part 'workspace_work_calendars.dart';
part 'workspace_gameplay.dart';
part 'workspace_technical.dart';
part 'workspace_pdf_review.dart';
part 'workspace_life.dart';
part 'workspace_life_packs.dart';
part 'workspace_finance.dart';
part 'workspace_dossier.dart';

final repositoryProvider = Provider<WorkspaceRepository>(
  (ref) => WorkspaceRepository(),
);
final workspaceProvider = NotifierProvider<WorkspaceController, int>(
  WorkspaceController.new,
);

/// Coordinates drafts and serialized durable commands. UI never writes files.
class WorkspaceController extends Notifier<int> {
  bool _financeBusy = false;
  bool get financeSaving => _financeBusy;
  Completer<void>? _financeWork;
  final _lifeOperations = <String, Future<UniversalObject?>>{};
  final _connectionResolver = ObjectConnectionResolver();
  List<UniversalObject>? _connectionSnapshot;
  List<ObjectConnection> _connectionEdges = const [];
  bool _creatingCreativeProject = false;
  bool _creatingCourse = false;
  final Set<String> _courseBoardsCreating = {};
  final Map<String, EditorDraftConflict> editorDraftConflicts = {};
  final _editorDraftRecoveries =
      <
        String,
        ({
          int generation,
          EditorDraftConflict draft,
          Future<UniversalObject?> future,
        })
      >{};
  List<UniversalObject>? _projectChoicesSource;
  Map<String, String> _projectChoicesCache = const {};
  final Map<
    String,
    ({
      String workspace,
      Map<String, dynamic> before,
      Map<String, dynamic> after,
    })
  >
  _projectMutationUndo = {};
  WorkspaceController({
    PdfTextExtractor? pdfTextExtractor,
    OcrPageExtractor? ocrExtractor,
  }) : _extractPdf = pdfTextExtractor ?? extractPdfText,
       _extractOcr = ocrExtractor ?? recognizeAttachment;
  final OcrPageExtractor _extractOcr;
  Future<void>? _ocrWork;
  int _ocrGeneration = 0;
  Completer<void>? _ocrResume;
  bool ocrRunning = false, ocrPaused = false;
  String ocrStatus = '';
  final Map<String, String> ocrFailures = {};
  final PdfTextExtractor _extractPdf;
  PdfSearchIndexer? _pdfIndexer;
  final _pdfIndexEvents = StreamController<void>.broadcast();
  Stream<void> get pdfIndexChanges => _pdfIndexEvents.stream;
  int get pdfIndexRevision => _pdfIndexer?.revision ?? 0;
  Map<String, PdfIndexEntry> get pdfIndexEntries =>
      _pdfIndexer?.entries ?? const {};
  bool get pdfIndexPaused => _pdfIndexer?.paused ?? false;
  bool get pdfIndexRunning => _pdfIndexer?.running ?? false;
  void pausePdfIndex(bool paused) => _pdfIndexer?.setPaused(paused);
  void retryPdfIndex() => _pdfIndexer?.retry();
  bool isCurrentSearchResult(OrbitSearchResult result) =>
      result.sourceChecksum == null ||
      (_pdfIndexer?.isCurrent(result) ?? false);
  void _startPdfIndexer() {
    _pdfIndexer = PdfSearchIndexer(
      repository,
      extract: _extractPdf,
      onChanged: () {
        if (!_alive) return;
        if (!_pdfIndexEvents.isClosed) _pdfIndexEvents.add(null);
        notify();
      },
    );
    _pdfIndexer!.synchronize(objects);
  }

  late WorkspaceRepository repository;
  int studyResumeSerial = 0;
  SessionState session = SessionState();
  bool _planningBusy = false;
  Completer<void>? _productivityOperation;
  List<UniversalObject>? _querySnapshot;
  String _queryDay = '';
  final Map<(String, String?, String?), List<UniversalObject>> _viewQueryCache =
      {};
  ({UniversalObject before, UniversalObject after})? _planningUndo;
  List<UniversalObject> objects = [];
  List<UniversalObject> _financeSnapshot = const [];
  FinanceIndex? _cachedFinanceIndex;
  int _financeIndexGeneration = -1;
  bool loading = true;
  String? error;
  final Set<String> dirty = {};
  final Map<String, String> failures = {};
  final Map<String, Timer> _timers = {};
  final Map<String, Future<void>> _saving = {};
  final Set<String> _trashing = {};
  bool _pdfReviewBatchBusy = false;
  Timer? _sessionTimer;
  bool _alive = true;
  bool savingSettings = false;
  Future<void>? _settingsSave;
  bool _settingsSaveRequested = false;
  bool _settingsSaveFailed = false;
  bool get sessionSaveFailed => _settingsSaveFailed;
  bool hasWorkspace = false;

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
  WorkspaceSyncReplica createSyncReplica({bool Function()? isCurrent}) =>
      WorkspaceSyncReplica(
        repository,
        isCurrent: isCurrent,
        canApply: () =>
            _alive &&
            !_financeBusy &&
            hasWorkspace &&
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
  StreamSubscription<String>? _attachmentSubscription;
  Timer? _externalDebounce;
  Timer? _attachmentDebounce;
  final Set<String> _changedPaths = {};
  final Set<String> _changedAttachments = {};
  int attachmentRevision = 0;
  int preferenceRevision = 0;

  @override
  int build() {
    repository = ref.read(repositoryProvider);
    ref.onDispose(() {
      cancelOcr();
      _alive = false;
      for (final timer in _timers.values) {
        timer.cancel();
      }
      _sessionTimer?.cancel();
      _externalDebounce?.cancel();
      _attachmentDebounce?.cancel();
      unawaited(_externalSubscription?.cancel());
      unawaited(_attachmentSubscription?.cancel());
      // The shell flushes before workspace switches and native exit.
      unawaited(() async {
        await _ocrWork;
        await _pdfIndexer?.close();
        await repository.close();
      }());
      unawaited(_pdfIndexEvents.close());
    });
    Future.microtask(initialize);
    return 0;
  }

  void Function() observeChanges(void Function() listener) =>
      listenSelf((_, _) => listener());

  void notify() {
    if (_alive && hasWorkspace) _pdfIndexer?.synchronize(objects);
    try {
      if (_alive) state++;
    } catch (_) {}
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
    if (!loading && hasWorkspace) _applyPortablePreferences();
  }

  Map<String, dynamic> _portableBaseline = {};

  void _applyPortablePreferences({bool opening = false}) {
    if (opening) {
      _portableBaseline = PortablePreferences.select(session.toJson());
    }
    try {
      final remote = PortablePreferences.merge(
        repository.preferenceRecords,
      ).values;
      final current = PortablePreferences.select(session.toJson());
      final apply = <String, dynamic>{
        for (final entry in remote.entries)
          if (opening ||
              PortablePreferences.equal(
                current[entry.key],
                _portableBaseline[entry.key],
              ))
            entry.key: entry.value,
      };
      if (apply.isNotEmpty) {
        session = SessionState.fromJson({...session.toJson(), ...apply});
      }
      final normalized = PortablePreferences.select(session.toJson());
      if (opening) {
        _portableBaseline = normalized;
      } else {
        for (final key in apply.keys) {
          _portableBaseline[key] = normalized[key];
        }
      }
    } catch (e) {
      error = 'Could not apply synchronized preferences: $e';
    }
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
    return repository.preferenceRecords.where((o) => o.id == id).firstOrNull;
  }

  String objectFolder(String id) => repository.objectFolder(id);

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
    return results;
  }

  /// Rich global/command results share deterministic ranking and target routing.
  Future<List<OrbitSearchResult>> searchLocations(String query) async {
    final indexed = await search(query.trim());
    final project = find(session.activeId)?.properties['project'];
    return projectWorkspaceSearch(
      indexed: indexed.where(inActiveSpace).toList(),
      snapshot: activeObjects.where(inActiveSpace).toList(),
      drafts: Set<String>.of(dirty),
      query: query,
      recent: List<String>.of(session.recent),
      project: project is String ? project : null,
      limit: null,
      pdfDocuments: Map.of(
        _pdfIndexer?.documents ?? <String, PdfTextDocument>{},
      ),
    );
  }

  int _locationSerial = 0;
  Future<ObjectReference> referenceNoteBlock(
    String noteId,
    int offset, {
    bool structured = false,
  }) async {
    final note = find(noteId);
    if (note == null ||
        note.isDeleted ||
        note.isReadOnly ||
        note.typeId != 'orbit.note' ||
        note.properties['documentFormat'] == 'latex') {
      throw StateError('Choose an editable Markdown note');
    }
    final anchored = anchorDocumentBlock(
      note.body,
      noteId,
      offset,
      'orbit-${const Uuid().v4()}',
      structured: structured,
    );
    if (anchored.source != note.body) {
      edit(noteId, body: anchored.source);
      await flush(noteId);
      if (dirty.contains(noteId)) {
        throw StateError('Save the note before creating a reference');
      }
    }
    return anchored.reference;
  }

  Future<ObjectReference> placeNoteBlock(
    String noteId,
    int offset,
    String canvasId,
  ) async {
    final board = find(canvasId);
    if (board == null ||
        board.isDeleted ||
        board.isReadOnly ||
        board.typeId != 'orbit.canvas') {
      throw StateError('Choose an editable Canvas');
    }
    final scene = CanvasScene.fromJson(board.data);
    if (scene.readOnly) throw StateError('Canvas uses an unsupported format');
    final reference = await referenceNoteBlock(noteId, offset);
    // Read current board again after asynchronous source save; preserve later edits.
    final current = find(canvasId)!;
    if (current.isDeleted || current.isReadOnly) {
      throw StateError('Canvas is unavailable');
    }
    final currentScene = CanvasScene.fromJson(current.data);
    if (currentScene.readOnly) {
      throw StateError('Canvas uses an unsupported format');
    }
    final elementId = const Uuid().v4();
    final bounds = currentScene.contentBounds;
    currentScene.put(
      CanvasElement({
        'id': elementId,
        'type': 'card',
        'objectId': noteId,
        'referenceTarget': reference.target,
        'x': bounds == null ? 0 : bounds.right + 48,
        'y': bounds?.top ?? 0,
        'width': 360,
        'height': 220,
      }),
    );
    edit(canvasId, data: currentScene.toJson());
    await flush(canvasId);
    if (dirty.contains(canvasId)) {
      throw StateError('Canvas could not be saved; the draft is retained');
    }
    return ObjectReference(
      canvasId,
      anchorType: 'element',
      anchorId: elementId,
    );
  }

  Future<bool> placeModelAsset(String assetId, String canvasId) async {
    final workspace = repository.workspaceId;
    final asset = find(assetId), board = find(canvasId);
    if (repository.readOnly ||
        asset?.isDeleted != false ||
        asset!.typeId != 'orbit.file' ||
        !isModelAsset(
          asset.properties['originalName'] as String? ?? asset.title,
        ) ||
        board?.isDeleted != false ||
        board!.isReadOnly ||
        board.typeId != 'orbit.canvas') {
      error = 'Choose an available model and an editable Canvas.';
      notify();
      return false;
    }
    final scene = CanvasScene.fromJson(board.data);
    if (scene.readOnly) {
      error = 'Canvas format is unsupported.';
      notify();
      return false;
    }
    final bounds = scene.contentBounds;
    scene.put(
      CanvasElement({
        'id': const Uuid().v4(),
        'type': 'card',
        'objectId': assetId,
        'x': bounds == null ? 0 : bounds.right + 48,
        'y': bounds?.top ?? 0,
        'width': 320,
        'height': 180,
        'presentation': 'card',
      }),
    );
    edit(canvasId, data: scene.toJson());
    await flush(canvasId);
    return repository.workspaceId == workspace &&
        !dirty.contains(canvasId) &&
        !failures.containsKey(canvasId);
  }

  final Map<
    String,
    ({ObjectReference reference, int? offset, int length, int serial})
  >
  locationRequests = {};

  void requestLocation(
    ObjectReference reference, {
    int? offset,
    int length = 0,
  }) {
    rememberNavigationLocation();
    pdfSearchRequests.remove(reference.id);
    _pdfOpenRequest++;
    locationRequests[reference.id] = (
      reference: reference,
      offset: offset,
      length: length,
      serial: ++_locationSerial,
    );
  }

  void openSearchResult(OrbitSearchResult result) {
    final request = ++_pdfOpenRequest;
    if (result.sourceChecksum != null) {
      unawaited(_openPdfSearchResult(result, request));
      return;
    }
    final current = find(result.object.id);
    if (current == null || current.isDeleted) return;
    requestLocation(
      result.location,
      offset: current.body == result.object.body ? result.sourceOffset : null,
      length: result.matchLength,
    );
    if (result.location.page != null) {
      final key = 'pdf:primary:${current.id}';
      session.noteViews = {
        ...session.noteViews,
        key: {...?session.noteViews[key], 'page': result.location.page},
      };
    }
    openObject(current.id);
  }

  int _pdfOpenRequest = 0;
  final pdfSearchRequests = <String, OrbitSearchResult>{};
  Future<void> _openPdfSearchResult(
    OrbitSearchResult result,
    int request,
  ) async {
    final workspace = repository.workspaceId;
    bool currentRequest() =>
        request == _pdfOpenRequest &&
        repository.workspaceId == workspace &&
        _alive &&
        hasWorkspace &&
        !loading;
    try {
      final valid =
          isCurrentSearchResult(result) &&
          result.sourcePath != null &&
          await repository.pdfSourceChecksum(result.sourcePath!) ==
              result.sourceChecksum;
      if (!currentRequest()) return;
      if (!valid) {
        if (result.sourcePath != null) {
          _pdfIndexer?.invalidatePath(result.sourcePath!);
        }
        error =
            'This attachment changed. Search is reindexing its current contents.';
        notify();
        return;
      }
      final current = find(result.object.id);
      if (request != _pdfOpenRequest ||
          repository.workspaceId != workspace ||
          current == null ||
          current.isDeleted ||
          current.properties['contentRef'] != result.sourcePath) {
        return;
      }
      requestLocation(
        result.location,
        offset: result.sourceOffset,
        length: result.matchLength,
      );
      pdfSearchRequests[current.id] = result;
      final key = 'pdf:primary:${current.id}';
      session.noteViews = {
        ...session.noteViews,
        key: {
          ...?session.noteViews[key],
          'page': result.location.page,
          'annotationId': null,
          'request': locationRequests[current.id]!.serial,
        },
      };
      openObject(current.id);
    } on Object {
      if (!currentRequest()) return;
      error =
          'The PDF source is unavailable. Refresh search or recover the attachment.';
      notify();
    }
  }

  List<UniversalObject> backlinks(String id) {
    final ids = connectionsTo(id).map((r) => r.source.id).toSet();
    return activeObjects.where((o) => ids.contains(o.id)).toList();
  }

  List<LinkedMention> linkedMentions(String id) {
    final existing = findLinkedMentions(
      targetId: id,
      objects: activeObjects,
      targets: linkTargets,
    );
    for (final edge in connectionsTo(id)) {
      if (existing.any(
        (m) =>
            m.source.id == edge.source.id &&
            (m.targetLocation == null ||
                m.targetLocation?.target == edge.target.target) &&
            m.sourceOffset == edge.offset &&
            (m.sourceLocation ?? ObjectReference(m.source.id)).target ==
                edge.location.target,
      )) {
        continue;
      }
      existing.add(
        LinkedMention(
          source: edge.source,
          targetId: id,
          targetTitle: find(id)?.title ?? id,
          snippet: edge.label,
          type: LinkedMentionType.objectReference,
          label: edge.label,
          targetLocation: edge.target,
          sourceLocation: edge.location,
          sourceOffset: edge.offset,
        ),
      );
    }
    return existing;
  }

  List<UnlinkedMention> unlinkedMentions(String id) => findUnlinkedMentions(
    targetId: id,
    objects: activeObjects,
    targets: linkTargets,
  );

  Future<bool> linkUnlinkedMention(
    UnlinkedMention mention,
    String targetId, {
    int? expectedGeneration,
  }) async {
    final generation = workspaceGeneration;
    final source = find(mention.source.id), target = find(targetId);
    if (expectedGeneration != null && expectedGeneration != generation ||
        source == null ||
        source.isDeleted ||
        source.isReadOnly ||
        target == null ||
        target.isDeleted ||
        repository.readOnly ||
        source.workspaceId != mention.source.workspaceId ||
        source.body != mention.source.body) {
      return false;
    }
    final updatedBody = linkMentionInMarkdown(source.body, mention, targetId);
    if (updatedBody == source.body) return false;
    edit(source.id, body: updatedBody);
    await flush(source.id);
    return generation == workspaceGeneration &&
        find(source.id)?.isDeleted == false &&
        find(source.id)?.body == updatedBody &&
        !dirty.contains(source.id) &&
        !failures.containsKey(source.id);
  }

  List<UniversalObject> outboundLinks(String id) {
    final ids = connectionsFrom(id).map((r) => r.target.id).toSet();
    return activeObjects.where((o) => ids.contains(o.id)).toList();
  }

  /// Groups all unresolved WikiLinks across active notes by missing title (LNK-05).
  Map<String, List<UniversalObject>> unresolvedWikiLinks() {
    final results = <String, List<UniversalObject>>{};
    final targets = linkTargets;
    for (final note in activeObjects.where(
      (o) => o.typeId == 'orbit.note' && !o.isDeleted,
    )) {
      final links = parseWikiLinks(note.body);
      for (final link in links) {
        final resolution = resolveWikiLink(
          link,
          targets,
          bindings: note.linkBindings,
        );
        if (resolution.status == WikiLinkStatus.unresolved) {
          final cleanTarget = link.target.trim();
          if (cleanTarget.isNotEmpty) {
            final list = results.putIfAbsent(cleanTarget, () => []);
            if (!list.any((existing) => existing.id == note.id)) {
              list.add(note);
            }
          }
        }
      }
    }
    return results;
  }

  /// Zero-friction quick capture into inbox without mandatory organization (CAP-01).
  Future<UniversalObject?> quickCapture(
    String text, {
    bool asTask = false,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return null;
    final title = clean.split('\n').first;
    final now = DateTime.now().toUtc();
    final type = asTask ? 'orbit.task' : 'orbit.note';
    return create(
      type,
      title: title,
      body: clean,
      properties: {'inbox': true, 'capturedAt': now.toIso8601String()},
    );
  }

  /// All unprocessed captures currently in inbox.
  List<UniversalObject> get inboxObjects =>
      activeObjects
          .where((o) => o.properties['inbox'] == true && !o.isDeleted)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Process an inbox capture into an organized project, folder, or task (CAP-02).
  Future<void> processInboxItem(
    String id, {
    String? project,
    String? folder,
    bool? asTask,
    bool archive = false,
    bool delete = false,
  }) async {
    final obj = find(id);
    if (obj == null) return;
    if (delete) {
      trash(id);
      return;
    }
    final nextProps = Map<String, dynamic>.from(obj.properties);
    nextProps.remove('inbox');
    if (archive) {
      nextProps['archived'] = true;
      nextProps['status'] = 'archived';
    }
    if (project != null && project.isNotEmpty) {
      nextProps['project'] = project;
    }
    if (folder != null && folder.isNotEmpty) {
      nextProps['folder'] = folder;
    }
    final newType = asTask == true ? 'orbit.task' : obj.typeId;
    if (newType != obj.typeId) {
      await create(
        newType,
        title: obj.title,
        body: obj.body,
        properties: nextProps,
      );
      trash(id);
    } else {
      edit(id, properties: nextProps);
    }
  }

  /// Temporal queries for Periodic Notes & Reviews (REV-01 - REV-04)
  List<UniversalObject> notesCreatedBetween(DateTime start, DateTime end) {
    return activeObjects
        .where(
          (o) =>
              !o.isDeleted &&
              o.typeId == 'orbit.note' &&
              !o.createdAt.isBefore(start) &&
              !o.createdAt.isAfter(end),
        )
        .toList();
  }

  List<UniversalObject> tasksCompletedBetween(DateTime start, DateTime end) {
    return activeObjects.where((o) {
      if (o.typeId != 'orbit.task' || o.isDeleted) {
        return false;
      }
      final isDone = o.isCompleted || o.properties['status'] == 'completed';
      if (!isDone) return false;
      final completedAtStr = o.properties['completedAt']?.toString();
      if (completedAtStr != null) {
        final date = DateTime.tryParse(completedAtStr);
        if (date != null) {
          return !date.isBefore(start) && !date.isAfter(end);
        }
      }
      return !o.updatedAt.isBefore(start) && !o.updatedAt.isAfter(end);
    }).toList();
  }

  List<UniversalObject> tasksUnfinishedBetween(DateTime start, DateTime end) {
    return activeObjects.where((o) {
      if (o.typeId != 'orbit.task' || o.isDeleted) {
        return false;
      }
      final isDone = o.isCompleted || o.properties['status'] == 'completed';
      if (isDone) return false;
      final dueStr = o.properties['dueDate'] ?? o.properties['scheduledDate'];
      if (dueStr != null) {
        final due = DateTime.tryParse(dueStr.toString());
        if (due != null) {
          return !due.isBefore(start) && !due.isAfter(end);
        }
      }
      return true;
    }).toList();
  }

  List<String> projectsActiveBetween(DateTime start, DateTime end) {
    return activeObjects
        .where(
          (o) =>
              !o.isDeleted &&
              o.updatedAt.isAfter(start) &&
              o.updatedAt.isBefore(end),
        )
        .map((o) => o.properties['project']?.toString())
        .whereType<String>()
        .where((p) => p.trim().isNotEmpty)
        .toSet()
        .toList();
  }

  Future<UniversalObject?> openReviewNote({
    required String periodName,
    required String title,
    required String initialBody,
  }) async {
    final existing = activeObjects.cast<UniversalObject?>().firstWhere(
      (o) =>
          o != null &&
          o.typeId == 'orbit.note' &&
          !o.isDeleted &&
          (o.title == title || o.properties['reviewPeriod'] == periodName),
      orElse: () => null,
    );
    if (existing != null) {
      openObject(existing.id);
      return existing;
    }
    return create(
      'orbit.note',
      title: title,
      body: initialBody,
      properties: {'icon': '📊', 'reviewPeriod': periodName},
    );
  }

  Future<UniversalObject?> openProjectDashboard(String projectName) async {
    final existing = activeObjects.cast<UniversalObject?>().firstWhere(
      (o) =>
          o != null &&
          o.typeId == 'orbit.view' &&
          !o.isDeleted &&
          o.properties['viewType'] == 'project' &&
          o.properties['project']?.toString().toLowerCase() ==
              projectName.toLowerCase(),
      orElse: () => null,
    );
    if (existing != null) {
      openObject(existing.id);
      return existing;
    }
    return create(
      'orbit.view',
      title: '$projectName Dashboard',
      properties: {'viewType': 'project', 'project': projectName, 'icon': '📊'},
    );
  }

  List<UniversalObject> relatedObjects(String id) {
    final o = find(id);
    if (o == null) return const [];
    final project = o.properties['project']?.toString();
    final folder = o.properties['folder']?.toString();
    final tags = (o.properties['tags'] is List)
        ? (o.properties['tags'] as List).map((e) => e.toString()).toSet()
        : <String>{};

    return activeObjects
        .where((other) {
          if (other.id == id) return false;
          if (project != null &&
              project.isNotEmpty &&
              other.properties['project']?.toString() == project) {
            return true;
          }
          if (folder != null &&
              folder.isNotEmpty &&
              other.properties['folder']?.toString() == folder) {
            return true;
          }
          if (tags.isNotEmpty) {
            final otherTags = (other.properties['tags'] is List)
                ? (other.properties['tags'] as List)
                      .map((e) => e.toString())
                      .toSet()
                : <String>{};
            if (tags.intersection(otherTags).isNotEmpty) return true;
          }
          return false;
        })
        .take(10)
        .toList();
  }

  String? _activeTagFilter;
  String? get activeTagFilter => _activeTagFilter;
  set activeTagFilter(String? value) {
    final clean = value?.trim().replaceAll(RegExp(r'^#'), '');
    final next = (clean == null || clean.isEmpty) ? null : clean;
    if (_activeTagFilter != next) {
      _activeTagFilter = next;
      notify();
    }
  }

  void clearTagFilter() {
    activeTagFilter = null;
  }

  /// Sorted list of all unique tags used across workspace objects.
  List<String> get allTags {
    final set = <String>{};
    for (final o in activeObjects) {
      if (o.properties['tags'] is List) {
        for (final t in o.properties['tags'] as List) {
          final s = t.toString().trim().replaceAll(RegExp(r'^#'), '');
          if (s.isNotEmpty) set.add(s);
        }
      }
      final bodyMatches = RegExp(
        r'(?:^|\s)#([a-zA-Z0-9_\-]+)',
      ).allMatches(o.body);
      for (final m in bodyMatches) {
        final tag = m.group(1);
        if (tag != null &&
            tag.isNotEmpty &&
            !tag.startsWith(RegExp(r'^\d+$'))) {
          set.add(tag);
        }
      }
    }
    final list = set.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  /// Number of active objects associated with [tag].
  int countForTag(String tag) {
    final target = tag.trim().replaceAll(RegExp(r'^#'), '').toLowerCase();
    if (target.isEmpty) return 0;
    int count = 0;
    for (final o in activeObjects) {
      final tags = (o.properties['tags'] is List)
          ? (o.properties['tags'] as List)
                .map(
                  (e) => e
                      .toString()
                      .trim()
                      .replaceAll(RegExp(r'^#'), '')
                      .toLowerCase(),
                )
                .toSet()
          : <String>{};
      if (tags.contains(target)) {
        count++;
      } else {
        final pattern = RegExp(
          r'(?:^|\s)#' + RegExp.escape(target) + r'(?:\s|$)',
          caseSensitive: false,
        );
        if (pattern.hasMatch(o.body)) {
          count++;
        }
      }
    }
    return count;
  }

  /// All tags specifically associated with an object.
  List<String> tagsForObject(String objectId) {
    final o = find(objectId);
    if (o == null) return const [];
    final set = <String>{};
    if (o.properties['tags'] is List) {
      for (final t in o.properties['tags'] as List) {
        final s = t.toString().trim().replaceAll(RegExp(r'^#'), '');
        if (s.isNotEmpty) set.add(s);
      }
    }
    final bodyMatches = RegExp(
      r'(?:^|\s)#([a-zA-Z0-9_\-]+)',
    ).allMatches(o.body);
    for (final m in bodyMatches) {
      final tag = m.group(1);
      if (tag != null && tag.isNotEmpty && !tag.startsWith(RegExp(r'^\d+$'))) {
        set.add(tag);
      }
    }
    final list = set.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  /// Adds a tag to an object's properties.
  Future<void> addTagToObject(
    String objectId,
    String tag, {
    int? expectedGeneration,
  }) async {
    if (expectedGeneration != null &&
        expectedGeneration != workspaceGeneration) {
      return;
    }
    final clean = tag.trim().replaceAll(RegExp(r'^#'), '');
    if (clean.isEmpty) return;
    final o = find(objectId);
    if (o == null || o.isDeleted || o.isReadOnly || repository.readOnly) return;
    if (o.properties['tags'] != null && o.properties['tags'] is! List) return;
    final currentTags = (o.properties['tags'] is List)
        ? List<dynamic>.from(o.properties['tags'] as List)
        : <dynamic>[];
    if (!currentTags.any(
      (t) =>
          t.toString().trim().replaceAll(RegExp(r'^#'), '').toLowerCase() ==
          clean.toLowerCase(),
    )) {
      currentTags.add(clean);
      updateProperty(objectId, 'tags', currentTags);
    }
  }

  /// Removes a tag from an object's properties.
  Future<void> removeTagFromObject(
    String objectId,
    String tag, {
    int? expectedGeneration,
  }) async {
    if (expectedGeneration != null &&
        expectedGeneration != workspaceGeneration) {
      return;
    }
    final clean = tag.trim().replaceAll(RegExp(r'^#'), '').toLowerCase();
    final o = find(objectId);
    if (o == null || o.isDeleted || o.isReadOnly || repository.readOnly) return;
    if (o.properties['tags'] is List) {
      final currentTags = (o.properties['tags'] as List)
          .where(
            (t) =>
                t
                    .toString()
                    .trim()
                    .replaceAll(RegExp(r'^#'), '')
                    .toLowerCase() !=
                clean,
          )
          .toList();
      updateProperty(objectId, 'tags', currentTags);
    }
  }

  void updateProperty(String id, String key, dynamic value) {
    final o = find(id);
    if (o == null || o.isReadOnly || repository.readOnly) return;
    edit(id, properties: {...o.properties, key: value});
  }

  /// Apply only reviewed metadata fields, retaining unrelated concurrent edits.
  /// The normal edit/autosave and conflict-recovery paths still own persistence.
  bool editObjectMetadata(
    UniversalObject expected, {
    required int generation,
    String? title,
    Map<String, dynamic> changes = const {},
    Set<String> remove = const {},
    Set<String> unchanged = const {},
  }) {
    final current = find(expected.id);
    if (!_alive ||
        !hasWorkspace ||
        generation != workspaceGeneration ||
        expected.workspaceId != repository.workspaceId ||
        current == null ||
        current.workspaceId != expected.workspaceId ||
        current.isDeleted ||
        current.isReadOnly ||
        repository.readOnly) {
      if (_alive && generation == workspaceGeneration) {
        error =
            'This item is no longer editable. Close the dialog and reopen it.';
        notify();
      }
      return false;
    }
    final keys = {...changes.keys, ...remove, ...unchanged};
    if ((title != null && current.title != expected.title) ||
        keys.any(
          (key) =>
              current.properties.containsKey(key) !=
                  expected.properties.containsKey(key) ||
              !jsonValuesEqual(
                current.properties[key],
                expected.properties[key],
              ),
        )) {
      error =
          'This field changed while you were editing. Your draft is retained; cancel and reopen to review the latest value.';
      notify();
      return false;
    }
    final properties = Map<String, dynamic>.from(current.properties)
      ..removeWhere((key, _) => remove.contains(key));
    properties.addAll(changes);
    edit(
      current.id,
      title: title,
      properties: keys.isEmpty ? null : properties,
    );
    final updated = find(current.id);
    return updated != null &&
        (title == null || updated.title == title) &&
        changes.entries.every(
          (e) => jsonValuesEqual(updated.properties[e.key], e.value),
        ) &&
        remove.every((key) => !updated.properties.containsKey(key));
  }

  void removeProperty(String id, String key) {
    final o = find(id);
    if (o == null || o.isReadOnly || repository.readOnly) return;
    final updated = Map<String, dynamic>.from(o.properties)..remove(key);
    edit(id, properties: updated);
  }

  String get saveLabel => failures.isNotEmpty
      ? 'Changes need attention'
      : dirty.isNotEmpty
      ? 'Saving locally…'
      : 'Saved locally';

  Future<void>? _initializingFuture;
  int _workspaceGeneration = 0;
  int get workspaceGeneration => _workspaceGeneration;
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
    final previousPath = hasWorkspace ? repository.location : null;
    final previousSession = session;
    if (hasWorkspace && !await flushAll()) {
      error =
          'Cannot switch vault: unsaved changes or save failures exist. Please resolve them first.';
      notify();
      return;
    }
    _workspaceGeneration++;
    _pdfOpenRequest++;
    await _pdfIndexer?.close();
    cancelOcr();
    await _ocrWork;
    ocrFailures.clear();
    ocrStatus = '';
    _pdfIndexer = null;
    pdfSearchRequests.clear();
    await _externalSubscription?.cancel();
    await _attachmentSubscription?.cancel();
    _externalDebounce?.cancel();
    _attachmentDebounce?.cancel();
    _changedPaths.clear();
    _changedAttachments.clear();
    loading = true;
    error = null;
    notify();
    try {
      await repository.initialize(path: path);
      _planningUndo = null;
      _querySnapshot = null;
      _financeSnapshot = const [];
      _cachedFinanceIndex = null;
      _viewQueryCache.clear();
      mergeRepositoryObjects();
      session = SessionState.fromJson(await repository.readDeviceSettings());
      final pendingPreferences = session.extra['pendingPortablePreferences'];
      _applyPortablePreferences(opening: true);
      if (pendingPreferences is Map) {
        final ownRecord = repository.preferenceRecords
            .where((r) => r.id == session.extra['portablePreferenceRecordId'])
            .firstOrNull;
        Map<String, dynamic> committed = {};
        try {
          if (ownRecord != null) {
            committed = PortablePreferences.fields(ownRecord);
          }
        } catch (_) {
          /* Preserve and report through the normal save boundary. */
        }
        session = SessionState.fromJson({
          ...session.toJson(),
          for (final entry in pendingPreferences.entries)
            if (PortablePreferences.keys.contains(entry.key) &&
                !PortablePreferences.equal(
                  (committed[entry.key] as Map?)?['value'],
                  entry.value,
                ))
              entry.key as String: entry.value,
        });
      }
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
      hasWorkspace = true;
    } catch (e) {
      error = '$e';
      if (previousPath != null && previousPath != path) {
        try {
          await repository.initialize(path: previousPath);
          objects = List.of(repository.objects);
          session = previousSession;
          error =
              'Could not open that workspace. Your previous workspace is still open: $e';
        } catch (recoveryError) {
          hasWorkspace = false;
          objects = [];
          error =
              'Could not open either workspace: $e. Reopening the previous workspace failed: $recoveryError';
        }
      }
    }
    loading = false;
    if (hasWorkspace) {
      _startPdfIndexer();
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
      _attachmentSubscription = repository.externalAttachmentChanges.listen(
        (path) {
          _pdfIndexer?.invalidatePath(path);
          _changedAttachments.add(path);
          _attachmentDebounce?.cancel();
          _attachmentDebounce = Timer(const Duration(milliseconds: 180), () {
            if (!_alive || !hasWorkspace) return;
            _changedAttachments.clear();
            // Attachment bytes are separate from object metadata. Bumping a
            // small revision lets visible media replace stale previews without
            // rebuilding the object index or disturbing note drafts.
            attachmentRevision++;
            notify();
          });
        },
        onError: (Object e) {
          error =
              'Attachment watching is unavailable. Recheck on app focus or use Reload from files. $e';
          notify();
        },
      );
    }
    notify();
  }

  void navigate(OrbitDestination destination) {
    _pdfOpenRequest++;
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
    cancelOcr();
    await _ocrWork;
    ocrFailures.clear();
    ocrStatus = '';
    if (!await flushAll()) return false;
    _workspaceGeneration++;
    _pdfOpenRequest++;
    await _pdfIndexer?.close();
    _pdfIndexer = null;
    pdfSearchRequests.clear();
    await repository.clearSelection();
    await _externalSubscription?.cancel();
    await _attachmentSubscription?.cancel();
    _externalDebounce?.cancel();
    _attachmentDebounce?.cancel();
    await repository.close();
    hasWorkspace = false;
    objects = [];
    _planningUndo = null;
    _querySnapshot = null;
    _financeSnapshot = const [];
    _cachedFinanceIndex = null;
    _viewQueryCache.clear();
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
    final repo = repository, generation = workspaceGeneration;
    if (!await flushAll()) return false;
    bool current() =>
        _alive &&
        identical(repo, repository) &&
        generation == workspaceGeneration &&
        !loading;
    if (!current()) return false;
    loading = true;
    notify();
    try {
      await command();
      if (!_alive ||
          !identical(repo, repository) ||
          generation != workspaceGeneration) {
        return false;
      }
      mergeRepositoryObjects();
      error = null;
    } catch (e) {
      if (!_alive ||
          !identical(repo, repository) ||
          generation != workspaceGeneration) {
        return false;
      }
      mergeRepositoryObjects();
      error = '$e';
    } finally {
      if (_alive &&
          identical(repo, repository) &&
          generation == workspaceGeneration) {
        loading = false;
      }
    }
    notify();
    return error == null;
  }

  final List<String> _navHistory = [];
  final List<Map<String, dynamic>> _navReturns = [];
  int _navGeneration = -1;
  int navigationRestoreSerial = 0;
  String? navigationRestoreTargetId;
  final Map<String, int> _navRequests = {};
  int _navIndex = -1;
  bool _navigatingHistory = false;

  int _historyTarget(int direction) {
    if (_navGeneration != workspaceGeneration) return -1;
    for (
      var i = _navIndex + direction;
      i >= 0 && i < _navHistory.length;
      i += direction
    ) {
      final object = find(_navHistory[i]);
      if (object != null && !object.isDeleted) return i;
    }
    return -1;
  }

  bool get canNavigateBack => _historyTarget(-1) >= 0;
  void rememberNavigationLocation() {
    if (_navGeneration != workspaceGeneration) {
      _navGeneration = workspaceGeneration;
      _navHistory.clear();
      _navReturns.clear();
      _navRequests.clear();
      _navIndex = -1;
    }
    if (_navIndex < 0) {
      // The first link after reopening a Vault must return to its restored tab,
      // even though that tab has not been opened through this runtime's history.
      final origin = find(session.activeId);
      if (origin == null || origin.isDeleted) return;
      _navHistory.add(origin.id);
      _navReturns.add({});
      _navIndex = 0;
    }
    if (_navIndex >= _navReturns.length) {
      return;
    }
    final id = _navHistory[_navIndex];
    if (session.activeId != id) return;
    _navReturns[_navIndex] =
        jsonDecode(
              jsonEncode({
                'position': session.positions['primary:$id'] ?? 0.0,
                'view': {
                  'mode': session.defaultNoteMode,
                  ...?session.noteViews['primary:$id'],
                },
                'pdf': session.noteViews['pdf:primary:$id'] ?? {'page': 1},
                'camera':
                    session.cameras[id] ?? {'x': 0.0, 'y': 0.0, 'zoom': 1.0},
              }),
            )
            as Map<String, dynamic>;
  }

  void _restoreNavigationLocation() {
    if (_navIndex < 0 || _navIndex >= _navReturns.length) return;
    final id = _navHistory[_navIndex], saved = _navReturns[_navIndex];
    if (saved.isEmpty) return;
    final position = saved['position'];
    if (position is num) {
      session.positions = {
        ...session.positions,
        'primary:$id': position.toDouble(),
      };
    }
    for (final entry in [('view', 'primary:$id'), ('pdf', 'pdf:primary:$id')]) {
      final value = saved[entry.$1];
      if (value is Map) {
        session.noteViews = {
          ...session.noteViews,
          entry.$2: Map<String, dynamic>.from(value),
        };
      }
    }
    final camera = saved['camera'];
    if (camera is Map) {
      session.cameras = {
        ...session.cameras,
        id: Map<String, dynamic>.from(camera),
      };
    }
    locationRequests.remove(id);
    pdfSearchRequests.remove(id);
    navigationRestoreTargetId = id;
    navigationRestoreSerial++;
  }

  bool get canNavigateForward => _historyTarget(1) >= 0;

  void navigateBack() {
    if (!canNavigateBack) return;
    rememberNavigationLocation();
    _navIndex = _historyTarget(-1);
    _restoreNavigationLocation();
    _navigatingHistory = true;
    openObject(_navHistory[_navIndex]);
    _navigatingHistory = false;
    notify();
  }

  void navigateForward() {
    if (!canNavigateForward) return;
    rememberNavigationLocation();
    _navIndex = _historyTarget(1);
    _restoreNavigationLocation();
    _navigatingHistory = true;
    openObject(_navHistory[_navIndex]);
    _navigatingHistory = false;
    notify();
  }

  /// Chronological backward navigation history (most recent first, deduplicated, up to 12).
  List<UniversalObject> get backHistory {
    if (!canNavigateBack) return const [];
    final result = <UniversalObject>[];
    final seen = <String>{};
    for (var i = _navIndex - 1; i >= 0 && result.length < 12; i--) {
      final id = _navHistory[i];
      if (seen.add(id)) {
        final obj = find(id);
        if (obj != null && !obj.isDeleted) {
          result.add(obj);
        }
      }
    }
    return result;
  }

  /// Chronological forward navigation history (next immediate first, deduplicated, up to 12).
  List<UniversalObject> get forwardHistory {
    if (!canNavigateForward) return const [];
    final result = <UniversalObject>[];
    final seen = <String>{};
    for (
      var i = _navIndex + 1;
      i < _navHistory.length && result.length < 12;
      i++
    ) {
      final id = _navHistory[i];
      if (seen.add(id)) {
        final obj = find(id);
        if (obj != null && !obj.isDeleted) {
          result.add(obj);
        }
      }
    }
    return result;
  }

  /// Jump directly to an object in the navigation history.
  void jumpToHistoryObject(String id) {
    if (_navGeneration != workspaceGeneration || _navHistory.isEmpty) return;
    int? bestIndex;
    var bestDistance = 999999;
    for (var i = 0; i < _navHistory.length; i++) {
      if (_navHistory[i] == id && i != _navIndex) {
        final dist = (i - _navIndex).abs();
        if (dist < bestDistance) {
          bestDistance = dist;
          bestIndex = i;
        }
      }
    }
    if (bestIndex != null) {
      rememberNavigationLocation();
      _navIndex = bestIndex;
      _restoreNavigationLocation();
      _navigatingHistory = true;
      openObject(_navHistory[_navIndex]);
      _navigatingHistory = false;
      notify();
    }
  }

  void openObject(String id, {bool secondary = false, bool reveal = false}) {
    _pdfOpenRequest++;
    final object = find(id);
    if (object == null || object.isDeleted) return;
    if (_navGeneration != workspaceGeneration) {
      _navGeneration = workspaceGeneration;
      _navHistory.clear();
      _navReturns.clear();
      _navRequests.clear();
      _navIndex = -1;
    }
    if (!secondary && !_navigatingHistory) rememberNavigationLocation();
    final path = repository.objectPath(id);
    final folderProp = object.properties['folder'] as String?;
    final targetPaths = <String>[
      ?path,
      if (folderProp != null && folderProp.isNotEmpty) ...[
        folderProp,
        if (!folderProp.startsWith('Notes/')) 'Notes/$folderProp',
      ],
    ];
    // Tab navigation must not undo an explicit folder collapse.
    if (reveal && targetPaths.isNotEmpty) {
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
      final openedForProject = find(id);
      if (openedForProject != null) {
        recordProjectActivity(openedForProject, 'opened');
      }
    } else {
      session.activeId = id;
      final openedForProject = find(id);
      if (openedForProject != null) {
        recordProjectActivity(openedForProject, 'opened');
      }
      if (!_navigatingHistory) {
        if (_navIndex >= 0 && _navIndex < _navHistory.length - 1) {
          _navHistory.removeRange(_navIndex + 1, _navHistory.length);
          _navReturns.removeRange(_navIndex + 1, _navReturns.length);
        }
        final request = locationRequests[id];
        final precise =
            request != null &&
            (request.reference.isPrecise || request.offset != null);
        if (_navHistory.isEmpty ||
            _navHistory.last != id ||
            (precise && _navRequests[id] != request.serial)) {
          _navHistory.add(id);
          _navReturns.add({});
          if (_navHistory.length > 50) {
            _navHistory.removeAt(0);
            _navReturns.removeAt(0);
          }
          _navIndex = _navHistory.length - 1;
          if (request != null) _navRequests[id] = request.serial;
          final retained = _navHistory.toSet();
          _navRequests.removeWhere((key, _) => !retained.contains(key));
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

  bool isBookmarked(String id) => session.bookmarkedTabs.contains(id);

  void toggleBookmark(String id) {
    if (isBookmarked(id)) {
      unbookmarkTab(id);
    } else {
      bookmarkTab(id);
    }
  }

  void bookmarkTab(String id) {
    if (!session.bookmarkedTabs.contains(id)) {
      session.bookmarkedTabs = [...session.bookmarkedTabs, id];
      persistSession();
      notify();
    }
  }

  void unbookmarkTab(String id) {
    if (session.bookmarkedTabs.contains(id)) {
      session.bookmarkedTabs = session.bookmarkedTabs
          .where((t) => t != id)
          .toList();
      persistSession();
      notify();
    }
  }

  List<UniversalObject> get bookmarkedObjects => session.bookmarkedTabs
      .map((id) => find(id))
      .whereType<UniversalObject>()
      .toList();

  void closeTab(String id) {
    if (session.autoSnapshotOnClose) {
      final obj = find(id);
      if (obj != null && !obj.isDeleted && obj.typeId == 'orbit.note') {
        unawaited(createDocumentSnapshot(id, label: 'Auto-snapshot on close'));
      }
    }
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
    rememberClosedTabGroup(toClose);
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
    rememberClosedTabGroup(toClose);
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
    final seen = <String>{};
    final beside = secondary ? session.activeId : session.secondaryId;
    final candidates = session.tabs.where((id) {
      final object = find(id);
      return seen.add(id) &&
          object != null &&
          !object.isDeleted &&
          // Only notes currently support two views of the same object.
          (!secondary || id != beside || object.typeId == 'orbit.note');
    }).toList();
    if (candidates.isEmpty) return;
    final id = secondary ? session.secondaryId : session.activeId;
    final index = candidates.indexOf(id ?? '');
    final next = index < 0
        ? 0
        : (index + (reverse ? -1 : 1)) % candidates.length;
    openObject(candidates[next], secondary: secondary);
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

  Future<UniversalObject?> openTodayNote({DateTime? date}) async {
    final now = date ?? DateTime.now();
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
    final header =
        '# $weekday, $month ${now.day}, ${now.year}\n\n'
        '## Tasks\n'
        '```orbit-view\n'
        'type: tasks\n'
        'status: open\n'
        '```\n\n'
        '## Notes & Reflections\n\n';
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
      if (original == null) properties = projectCreationProperties(properties);
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
      recordProjectActivity(saved, original == null ? 'created' : 'saved');
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
    bool open = true,
    String? title,
    String body = '',
    Map<String, dynamic> properties = const {},
    Map<String, dynamic>? data,
  }) async {
    final generation = workspaceGeneration;
    try {
      final now = DateTime.now();
      final today = calendarDate(now);
      properties = projectCreationProperties(properties);
      validateResearchProperties(properties);
      if (properties['workingCalendar'] != null) {
        WorkingCalendar(
          Map<String, dynamic>.from(properties['workingCalendar'] as Map),
        );
      }
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
        data:
            data ??
            (type == 'orbit.canvas'
                ? {'schemaVersion': 1, 'elements': <dynamic>[]}
                : const {}),
      );
      if (generation != workspaceGeneration ||
          object.workspaceId != repository.workspaceId) {
        return null;
      }
      objects = [...objects, object];
      recordProjectActivity(object, 'created');
      error = null;
      if (_activeWorkSession != null && _activeWorkSession!.isRecordingActive) {
        _activeWorkSession = _activeWorkSession!.recordCreate(object.id);
        session.activeWorkSession = _activeWorkSession!.toJson();
      }
      if (open) {
        openObject(object.id);
      } else {
        notify();
      }
      return object;
    } catch (e) {
      if (generation != workspaceGeneration) return null;
      error = '$e';
      notify();
      return null;
    }
  }

  Future<UniversalObject?> createUniversityCourse(
    String courseName, {
    String semester = 'WS 2026',
    num ects = 5,
    String courseCode = '',
    String lecturer = '',
    String targetParentFolder = 'Notes',
  }) async {
    if (_creatingCourse) return null;
    final cleanName = courseName.trim();
    if (cleanName.isEmpty ||
        cleanName.length > 120 ||
        !ects.isFinite ||
        ects < 0 ||
        ects > 120 ||
        RegExp(r'[\x00-\x1f\\/:*?"<>|]').hasMatch(cleanName) ||
        cleanName == '.' ||
        cleanName == '..') {
      error =
          'Use a course name without path characters and ECTS between 0 and 120.';
      notify();
      return null;
    }
    _creatingCourse = true;
    final generation = workspaceGeneration;
    final owner = repository.workspaceId;
    UniversalObject? overview;
    void checkOwner() {
      if (generation != workspaceGeneration ||
          owner != repository.workspaceId ||
          loading) {
        throw StateError(
          'Course setup stopped because the Vault changed. Completed items remain in the original Vault.',
        );
      }
    }

    Future<UniversalObject?> add(
      String type, {
      required String title,
      String body = '',
      Map<String, dynamic> properties = const {},
      Map<String, dynamic>? data,
    }) async {
      checkOwner();
      final object = await create(
        type,
        open: false,
        title: title,
        body: body,
        properties: {
          ...properties,
          'project': '',
          'context': '',
          if (overview != null) 'courseId': overview.id,
        },
        data: data,
      );
      checkOwner();
      if (object == null) {
        throw StateError(error ?? 'Course setup could not save an item.');
      }
      return object;
    }

    try {
      final courseFolder = targetParentFolder == 'Notes'
          ? 'University/$cleanName'
          : '$targetParentFolder/$cleanName';

      if (activeObjects.any(
        (o) =>
            o.properties['isCourseOverview'] == true &&
            o.properties['folder'] == courseFolder,
      )) {
        throw StateError(
          'A course already uses this folder. Choose a distinct name or parent folder.',
        );
      }
      checkOwner();
      // 1. Create folder structure
      try {
        checkOwner();
        await repository.createFolder(courseFolder);
        checkOwner();
        await repository.createFolder('$courseFolder/Lectures');
        checkOwner();
        await repository.createFolder('$courseFolder/Exercises');
        checkOwner();
        await repository.createFolder('$courseFolder/Exam Preparation');
      } catch (e) {
        rethrow;
      }
      checkOwner();

      // 2. Create Course Overview Note
      final overviewBody =
          '''# $cleanName Overview

**Course:** $cleanName${courseCode.isNotEmpty ? ' ($courseCode)' : ''} | **Semester:** $semester | **ECTS:** $ects${lecturer.isNotEmpty ? ' | **Lecturer:** $lecturer' : ''}

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

      final overviewNote = await add(
        'orbit.note',
        title: '$cleanName Overview',
        body: overviewBody,
        properties: {
          'folder': courseFolder,
          'course': cleanName,
          'courseCode': courseCode.isNotEmpty ? courseCode : cleanName,
          'semester': semester,
          'ects': ects,
          'lecturer': lecturer,
          'isCourseOverview': true,
          'courseStatus': 'active',
        },
      );

      overview = overviewNote;
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

      await add(
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
      await add(
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
      await add(
        'orbit.view',
        title: '$cleanName Tasks',
        properties: {
          'folder': courseFolder,
          'scope': cleanName,
          'folderFilter': courseFolder,
          'viewType': 'tasks',
          'preset': 'university',
        },
      );

      await add(
        'orbit.view',
        title: '$cleanName Board',
        properties: {
          'folder': courseFolder,
          'scope': cleanName,
          'folderFilter': courseFolder,
          'viewType': 'board',
          'preset': 'university',
        },
      );

      await add(
        'orbit.view',
        title: '$cleanName Calendar',
        properties: {
          'folder': courseFolder,
          'scope': cleanName,
          'folderFilter': courseFolder,
          'viewType': 'calendar',
        },
      );

      await add(
        'orbit.view',
        title: '$cleanName Timeline',
        properties: {
          'folder': courseFolder,
          'scope': cleanName,
          'folderFilter': courseFolder,
          'viewType': 'timeline',
        },
      );

      await add(
        'orbit.view',
        title: '$cleanName Exercises',
        properties: {
          'folder': courseFolder,
          'scope': cleanName,
          'folderFilter': courseFolder,
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
    } catch (e) {
      if (generation == workspaceGeneration) {
        error =
            'Course setup stopped: $e. Saved items are retained; no existing content was deleted.';
        notify();
      }
      return null;
    } finally {
      _creatingCourse = false;
    }
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
    } catch (e) {
      error = '$e';
      notify();
    }

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
        'tasksOnly': true,
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
    String? mechanicId,
  }) async {
    final workspace = repository.workspaceId;
    final cleanFinding = finding.trim();
    if (cleanFinding.isEmpty) return null;
    final sourceNote = find(sourceNoteId);
    if (sourceNote == null ||
        sourceNote.isDeleted ||
        sourceNote.isReadOnly ||
        repository.readOnly) {
      error = 'Choose an editable playtest note before creating a task.';
      notify();
      return null;
    }
    if (sourceNote.properties['mechanicId'] != null &&
        sourceNote.properties['mechanicId'] is! String) {
      error = 'Unsupported mechanic reference. The playtest is preserved.';
      notify();
      return null;
    }
    final linkedMechanic =
        mechanicId ?? sourceNote.properties['mechanicId'] as String?;
    if (linkedMechanic != null && find(linkedMechanic)?.isDeleted != false) {
      error = 'The linked mechanic is missing.';
      notify();
      return null;
    }
    final targetFolder = folder.isNotEmpty
        ? folder
        : (sourceNote.properties['folder'] as String? ?? 'Notes');
    final targetProject = project.isNotEmpty
        ? project
        : (sourceNote.properties['project'] as String? ?? '');

    final task = await create(
      'orbit.task',
      title: cleanFinding,
      body:
          'Originating playtest observation from [[$sourceNoteId|${sourceNote.title}]]\n\n'
          '- [ ] Verify finding\n'
          '- [ ] Implement resolution\n'
          '- [ ] Validate in playtest session\n',
      properties: {
        'folder': targetFolder,
        if (targetProject.isNotEmpty) 'project': targetProject,
        'sourceNoteId': sourceNoteId,
        'mechanicId': ?linkedMechanic,
        if (sourceNote.properties['build'] is String)
          'build': sourceNote.properties['build'],
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
    if (task != null) {
      final latestSource = find(sourceNote.id);
      if (repository.workspaceId != workspace ||
          latestSource == null ||
          latestSource.isDeleted ||
          latestSource.isReadOnly ||
          repository.readOnly) {
        error =
            'The task was created, but the playtest changed or became unavailable. Its source link is retained on the task.';
        notify();
        return null;
      }
      final updatedBody =
          '${latestSource.body.trimRight()}\n- [ ] [[${task.id}|${task.title}]] (${isBug ? severity.toUpperCase() : discipline})\n';
      edit(
        sourceNote.id,
        body: updatedBody,
        properties: {
          ...latestSource.properties,
          'findingTaskIds': <String>{
            if (latestSource.properties['findingTaskIds'] is List)
              ...(latestSource.properties['findingTaskIds'] as List)
                  .whereType<String>(),
            task.id,
          }.toList(),
        },
      );
      await flush(sourceNote.id);
      if (dirty.contains(sourceNote.id) ||
          failures.containsKey(sourceNote.id)) {
        error =
            'The task was created. The playtest backlink still needs save or recovery.';
        notify();
        return null;
      }
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
    } catch (e) {
      error = '$e';
      notify();
    }

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
    } catch (e) {
      error = '$e';
      notify();
    }

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
    } catch (e) {
      error = '$e';
      notify();
    }

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
    String address = '',
    String rva = '',
    String module = '',
    String callingConvention = '',
    String returnType = '',
    String parameters = '',
    String purpose = '',
    String status = 'Investigating',
    String confidence = 'Medium',
    String target = '',
    ResearchAddress? location,
    Map<String, dynamic> provenance = const {},
  }) async {
    final addressProperties =
        (location ??
                ResearchAddress(address: address, rva: rva, module: module))
            .toProperties();
    address = addressProperties['address'] as String? ?? '';
    rva = addressProperties['rva'] as String? ?? '';
    module = addressProperties['module'] as String? ?? '';
    final cleanName = name?.trim().isNotEmpty == true
        ? name!.trim()
        : address.isEmpty
        ? 'Unnamed function'
        : 'sub_${address.replaceAll('0x', '')}';
    final body =
        '''# $cleanName

**Address:** `$address` | **RVA:** `$rva` | **Module:** `$module`
**Status:** $status | **Confidence:** $confidence | **Target:** $target

## Prototype
```c
${returnType.isEmpty ? '// Record a verified prototype here.' : '$returnType $callingConvention $cleanName($parameters);'}
```

## Purpose & Summary
$purpose

## Disassembly Snippet
```asm

```

## Decompiler Notes
- Record verified observations here.

## Cross References
- **Calls:** Unknown
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
        ...addressProperties,
        if (provenance.isNotEmpty) 'researchProvenance': provenance,
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
  }) => importFunctionPlan(
    FunctionImportPlan.csv(csvContent),
    folder: folder,
    target: target,
  );

  Future<int> importFunctionsFromJson(
    String jsonContent, {
    required String folder,
    String target = '',
  }) => importFunctionPlan(
    FunctionImportPlan.json(jsonContent),
    folder: folder,
    target: target,
  );

  Future<int> importFunctionPlan(
    FunctionImportPlan plan, {
    required String folder,
    String target = '',
  }) async {
    var imported = 0;
    for (final function in plan.functions) {
      final object = await createFunctionDoc(
        folder: folder,
        name: function.name,
        location: function.location,
        purpose: function.purpose,
        status: function.status,
        confidence: function.confidence,
        target: target,
        provenance: {
          'version': 1,
          'method': 'manual-import',
          ...function.rawMetadata,
          if (plan.tool.isNotEmpty) 'tool': plan.tool,
          if (plan.source.isNotEmpty) 'source': plan.source,
        },
      );
      if (object == null) break;
      imported++;
    }
    return imported;
  }

  /// Research records remain ordinary Markdown with additive, editable metadata.
  Future<UniversalObject?> createResearchMap({
    required String folder,
    required String title,
    required List<String> objectIds,
  }) async {
    final ids = objectIds.toSet().toList();
    if (ids.isEmpty || ids.length > 500) {
      throw const FormatException(
        'Choose between 1 and 500 records for a map.',
      );
    }
    for (final id in ids) {
      if (find(id) == null || find(id)!.isDeleted) {
        throw const FormatException(
          'Map records must exist in this workspace.',
        );
      }
    }
    final placements = {for (final id in ids) id: const Uuid().v4()};
    final elements = <Map<String, dynamic>>[
      for (var i = 0; i < ids.length; i++)
        {
          'id': placements[ids[i]],
          'type': 'card',
          'objectId': ids[i],
          'x': (i % 4) * 360.0,
          'y': (i ~/ 4) * 250.0,
          'width': 320.0,
          'height': 190.0,
        },
    ];
    for (final id in ids) {
      final record = find(id)!;
      for (final relation in ['supportingIds', 'contradictingIds']) {
        final evidence = record.properties[relation];
        if (evidence is! List) continue;
        for (final evidenceId in evidence.whereType<String>().toSet()) {
          if (!placements.containsKey(evidenceId)) continue;
          elements.add({
            'id': const Uuid().v4(),
            'type': 'connector',
            'startId': placements[evidenceId],
            'endId': placements[id],
            'x': 0.0,
            'y': 0.0,
            'width': 0.0,
            'height': 0.0,
            'text': relation == 'supportingIds' ? 'Supports' : 'Contradicts',
            'color': relation == 'supportingIds' ? 0xff4caf82 : 0xffe07575,
            'routing': 'orthogonal',
            'endMarker': 'arrow',
          });
        }
      }
    }
    return create(
      'orbit.canvas',
      title: title,
      properties: {'folder': folder, 'category': 'Research Map'},
      data: {'schemaVersion': 1, 'elements': elements},
    );
  }

  /// Research records remain ordinary Markdown with additive, editable metadata.
  /// Patch records only describe changes; this command never opens a binary.
  Future<UniversalObject?> createResearchRecord({
    required String folder,
    required String category,
    required String title,
    String target = '',
    ResearchAddress? location,
    String summary = '',
    String status = 'Unverified',
    String confidence = 'Low',
    List<String> supportingIds = const [],
    List<String> contradictingIds = const [],
  }) async {
    if (!researchRecordCategories.contains(category) || title.trim().isEmpty) {
      throw const FormatException('Choose a research record type and title.');
    }
    final support = supportingIds.toSet();
    final against = contradictingIds.toSet();
    if (support.intersection(against).isNotEmpty) {
      throw const FormatException(
        'An object cannot be both supporting and contradicting evidence.',
      );
    }
    for (final id in {...support, ...against}) {
      final object = find(id);
      if (object == null || object.isDeleted) {
        throw const FormatException(
          'Evidence must reference an existing object.',
        );
      }
    }
    final properties = location?.toProperties() ?? <String, dynamic>{};
    String links(Set<String> ids) =>
        ids.map((id) => '- [[$id|${find(id)!.title}]]').join('\n');
    final details = switch (category) {
      'Function' =>
        '## Prototype\n```c\n\n```\n\n## Disassembly\n```asm\n\n```\n\n## Cross references\n',
      'Patch' =>
        '## Proposed change\n\n## Original bytes\n```hex\n\n```\n\n## Proposed bytes\n```hex\n\n```\n\n## Verification and rollback\n\nThis record does not modify binary files.\n',
      'Structure' || 'Class' =>
        '## Layout\n| Offset | Type | Field | Evidence |\n|---|---|---|---|\n\n## Relationships\n',
      'Call Graph' =>
        '## Calls\n| Caller | Callee | Evidence |\n|---|---|---|\n\n## Canvas map\n',
      'Binary' =>
        '## Identity\n\n## SHA-256\n\n## Architecture and format\n\n## Modules\n',
      'Module' => '## Sections and permissions\n\n## Imports and exports\n',
      'String' => '## Value and encoding\n\n## Cross references\n',
      'Import' => '## Library and symbol\n\n## Call sites\n',
      _ => '## Observations\n\n## Next experiment\n',
    };
    return create(
      'orbit.note',
      title: title.trim(),
      body:
          '''# ${title.trim()}

**Type:** $category | **Status:** $status | **Confidence:** $confidence
${properties.entries.map((e) => '**${e.key}:** `${e.value}`').join(' | ')}

## Summary
$summary

$details
## Supporting evidence
${links(support)}

## Contradicting evidence
${links(against)}
''',
      properties: {
        'folder': folder,
        'category': category,
        'researchSchemaVersion': 1,
        if (target.isNotEmpty) 'target': target,
        'status': status,
        'confidence': confidence,
        ...properties,
        if (category == 'Function') 'purpose': summary,
        'supportingIds': support.toList(),
        'contradictingIds': against.toList(),
        if (category == 'Patch') 'appliesToBinary': false,
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

  /// All known normalized folder paths discovered from the repository and active objects.
  Set<String> get allKnownFolders {
    final folders = <String>{'Notes'};
    for (final raw in repository.folders) {
      if (raw.isEmpty) continue;
      final f = raw == 'Notes' || raw.startsWith('Notes/') ? raw : 'Notes/$raw';
      folders.add(f);
      var parent = p.posix.dirname(f);
      while (parent.isNotEmpty && parent != '.' && parent != 'Notes') {
        folders.add(parent);
        parent = p.posix.dirname(parent);
      }
    }
    for (final o in activeObjects) {
      if (o.isDeleted) continue;
      final raw = repository.objectFolder(o.id);
      if (raw.isNotEmpty) {
        final f = raw == 'Notes' || raw.startsWith('Notes/')
            ? raw
            : 'Notes/$raw';
        folders.add(f);
        var parent = p.posix.dirname(f);
        while (parent.isNotEmpty && parent != '.' && parent != 'Notes') {
          folders.add(parent);
          parent = p.posix.dirname(parent);
        }
      }
    }
    return folders;
  }

  /// Collapses all known folders in the explorer.
  void collapseAllFolders() {
    updateSession((s) {
      s.collapsedFolders = allKnownFolders.toList();
    });
  }

  /// Expands all folders in the explorer.
  void expandAllFolders() {
    updateSession((s) {
      s.collapsedFolders = [];
    });
  }

  /// Whether all known folders are currently collapsed.
  bool get areAllFoldersCollapsed {
    final folders = allKnownFolders;
    if (folders.isEmpty) return false;
    return folders.every(session.collapsedFolders.contains);
  }

  /// Resolves the ARGB color value assigned to a folder, or inherited from its nearest colored ancestor.
  int? folderColorValue(String folder) {
    String? current = folder;
    while (current != null && current.isNotEmpty) {
      final val = session.folderColors[current];
      if (val != null) return val;
      final parent = p.posix.dirname(current);
      if (parent == current || parent == '.' || parent.isEmpty) break;
      current = parent;
    }
    return null;
  }

  /// Sets or clears the color identity of a folder.
  void setFolderColor(String folder, int? colorValue) {
    updateSession((s) {
      final next = Map<String, int>.from(s.folderColors);
      if (colorValue != null) {
        next[folder] = colorValue;
      } else {
        next.remove(folder);
      }
      s.folderColors = next;
    });
  }

  /// Clones any non-readonly object (note, canvas, task, event, view) with a "(Copy)" title suffix,
  /// preserving folder, properties, data, and body, then opens the new copy.
  Future<UniversalObject?> duplicateObject(String id) async {
    final original = find(id);
    if (original == null ||
        original.isDeleted ||
        repository.readOnly ||
        original.isReadOnly) {
      return null;
    }
    final title = original.title.isEmpty ? 'Untitled' : original.title;
    final copyTitle = '$title (Copy)';
    final newProps = Map<String, dynamic>.from(original.properties);
    return create(
      original.typeId,
      title: copyTitle,
      body: original.body,
      properties: newProps,
      data: Map<String, dynamic>.from(original.data),
    );
  }

  /// Batch-duplicates multiple objects.
  Future<List<UniversalObject>> duplicateObjects(Iterable<String> ids) async {
    final selection = ids.toSet().toList();
    final repo = repository, generation = workspaceGeneration;
    final result = <UniversalObject>[];
    for (final id in selection) {
      if (!_alive ||
          !identical(repo, repository) ||
          generation != workspaceGeneration) {
        break;
      }
      final original = find(id);
      if (original == null || original.isDeleted || original.isReadOnly) {
        continue;
      }
      final dup = await duplicateObject(id);
      if (dup != null) result.add(dup);
      // Do not bury a failed copy beneath successes later in the batch.
      if (dup == null) break;
    }
    return result;
  }

  Future<UniversalObject?> duplicateView(String viewId) async =>
      duplicateObject(viewId);

  Future<bool> moveObjectToFolder(String id, String folder) =>
      moveObjectsToFolder([id], folder);

  Future<bool> moveObjectsToFolder(Iterable<String> ids, String folder) {
    final selection = ids.toSet().toList(), repo = repository;
    return organize(() => repo.moveObjectsToFolder(selection, folder));
  }

  Future<bool> moveFolder(String source, String target) => organize(() async {
    await repository.moveFolder(source, target);
    session.archivedFolders = [
      for (final folder in session.archivedFolders)
        if (folder == source || folder.startsWith('$source/'))
          '$target${folder.substring(source.length)}'
        else
          folder,
    ];
    final updatedColors = <String, int>{};
    for (final entry in session.folderColors.entries) {
      if (entry.key == source || entry.key.startsWith('$source/')) {
        updatedColors['$target${entry.key.substring(source.length)}'] =
            entry.value;
      } else {
        updatedColors[entry.key] = entry.value;
      }
    }
    session.folderColors = updatedColors;
    session.collapsedFolders = [
      for (final folder in session.collapsedFolders)
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

  List<UniversalObject> pdfLinkedNotes(String fileId) {
    final linked = backlinks(fileId).map((o) => o.id).toSet();
    return activeObjects
        .where(
          (o) =>
              o.typeId == 'orbit.note' &&
              (linked.contains(o.id) ||
                  (o.properties['pdfSource'] is Map &&
                      (o.properties['pdfSource'] as Map)['objectId'] ==
                          fileId)),
        )
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// Navigate both ways without copying notes or replacing their source metadata.
  void openPdfNote(String noteId, {String? besidePdfId}) {
    final note = find(noteId);
    if (note == null || note.isDeleted || note.typeId != 'orbit.note') return;
    openObject(noteId);
    if (openPdfSource(noteId)) return;
    final file = find(besidePdfId);
    if (file != null &&
        !file.isDeleted &&
        file.properties['mimeType'] == 'application/pdf') {
      final key = 'pdf:secondary:${file.id}';
      final primary = session.noteViews['pdf:primary:${file.id}'];
      final secondaryPrior = session.noteViews[key];
      session.noteViews = {
        ...session.noteViews,
        key: {
          if (primary != null)
            ...Map<String, dynamic>.from(primary)..remove('zoom'),
          ...?secondaryPrior,
        },
      };
      openObject(file.id, secondary: true);
    }
  }

  bool openPdfSource(String noteId, {bool secondary = true}) {
    final note = find(noteId);
    final source = note?.properties['pdfSource'];
    if (note == null ||
        note.isDeleted ||
        source is! Map ||
        source['objectId'] is! String) {
      return false;
    }
    final file = find(source['objectId'] as String);
    if (file == null ||
        file.isDeleted ||
        file.typeId != 'orbit.file' ||
        file.properties['mimeType'] != 'application/pdf') {
      return false;
    }
    final pane = secondary ? 'secondary' : 'primary';
    final key = 'pdf:$pane:${file.id}';
    final currentPrior = session.noteViews[key];
    final otherPrior = session
        .noteViews['pdf:${secondary ? 'primary' : 'secondary'}:${file.id}'];
    final prior =
        currentPrior ??
        (otherPrior != null
            ? (secondary
                  ? (Map<String, dynamic>.from(otherPrior)..remove('zoom'))
                  : otherPrior)
            : null);
    final annotation = PdfAnnotation(note);
    session.noteViews = {
      ...session.noteViews,
      key: {
        ...?prior,
        'page': source['page'] is int && source['page'] > 0
            ? source['page']
            : 1,
        'annotationId':
            PdfAnnotation.isAnnotation(note) &&
                annotation.matches(file.properties['checksum'] as String?)
            ? note.id
            : null,
        'request': ((prior?['request'] as num?)?.toInt() ?? 0) + 1,
      },
    };
    openObject(file.id, secondary: secondary);
    return true;
  }

  Future<UniversalObject?> createPdfQuote(
    String fileId,
    int page,
    String quote, {
    ResearchDocument? document,
    String? expectedChecksum,
  }) async {
    final opening = workspaceGeneration, repo = repository;
    final file = find(fileId);
    if (file == null ||
        file.isDeleted ||
        file.isReadOnly ||
        repository.readOnly ||
        file.typeId != 'orbit.file' ||
        file.properties['mimeType'] != 'application/pdf' ||
        (expectedChecksum != null &&
            file.properties['checksum'] != expectedChecksum) ||
        page < 1 ||
        page > 999999 ||
        quote.length > 100000 ||
        (document == null && quote.trim().isEmpty)) {
      return null;
    }
    try {
      final note = await repo.create(
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
            'quote': quote,
          },
        },
      );
      if (opening != workspaceGeneration || !identical(repo, repository)) {
        return null;
      }
      objects = [...objects, note];
      error = null;
      openObject(note.id);
      return note;
    } catch (e) {
      if (opening != workspaceGeneration || !identical(repo, repository)) {
        return null;
      }
      error = '$e';
      notify();
      return null;
    }
  }

  /// Extracts a quote from a PDF directly into the active note (in split view or primary view).
  Future<bool> extractPdfQuoteToActiveNote(
    String quote,
    int page,
    String pdfId,
    String pdfTitle,
  ) async {
    final opening = workspaceGeneration;
    if (!_validPdfExtraction(pdfId, page, quote)) return false;
    final file = find(pdfId);
    if (file == null || file.isDeleted) return false;

    UniversalObject? targetNote;
    final primary = find(session.activeId);
    final secondary = find(session.secondaryId);
    if (secondary != null &&
        secondary.typeId == 'orbit.note' &&
        !secondary.isDeleted &&
        secondary.id != pdfId) {
      targetNote = secondary;
    } else if (primary != null &&
        primary.typeId == 'orbit.note' &&
        !primary.isDeleted &&
        primary.id != pdfId) {
      targetNote = primary;
    } else {
      for (final tabId in session.tabs) {
        final candidate = find(tabId);
        if (candidate != null &&
            candidate.typeId == 'orbit.note' &&
            !candidate.isDeleted &&
            candidate.id != pdfId) {
          targetNote = candidate;
          break;
        }
      }
    }

    if (targetNote == null) {
      return false;
    }
    if (targetNote.isReadOnly ||
        targetNote.properties['documentFormat'] == 'latex' ||
        editorDraftConflicts.values.any((d) => d.objectId == targetNote!.id)) {
      return false;
    }

    final quoteMarkdown = ObjectReference(
      pdfId,
      page: page,
    ).quoteMarkdown(pdfTitle, quote);
    final currentBody = targetNote.body;
    final eol = currentBody.contains('\r\n') ? '\r\n' : '\n';
    final updatedBody = currentBody.isEmpty
        ? quoteMarkdown.replaceAll('\n', eol)
        : '$currentBody$eol$eol${quoteMarkdown.replaceAll('\n', eol)}';
    edit(targetNote.id, body: updatedBody);
    await flush(targetNote.id);
    return opening == workspaceGeneration &&
        !dirty.contains(targetNote.id) &&
        !failures.containsKey(targetNote.id) &&
        find(targetNote.id)?.body == updatedBody;
  }

  bool _validPdfExtraction(String id, int page, String quote) {
    final source = find(id);
    return !repository.readOnly &&
        source != null &&
        !source.isDeleted &&
        !source.isReadOnly &&
        source.typeId == 'orbit.file' &&
        source.properties['mimeType'] == 'application/pdf' &&
        page > 0 &&
        page <= 999999 &&
        quote.trim().isNotEmpty &&
        quote.length <= 100000;
  }

  /// Extracts a quote from a PDF onto a Canvas (placing a card on the active/adjacent canvas, or creating one).
  Future<bool> extractPdfQuoteToCanvas(
    String quote,
    int page,
    String pdfId,
    String pdfTitle, {
    String? targetCanvasId,
  }) async {
    final opening = workspaceGeneration;
    if (!_validPdfExtraction(pdfId, page, quote)) return false;
    final file = find(pdfId);
    if (file == null || file.isDeleted) return false;

    UniversalObject? canvasObj;
    if (targetCanvasId != null) {
      canvasObj = find(targetCanvasId);
      if (canvasObj == null ||
          canvasObj.typeId != 'orbit.canvas' ||
          canvasObj.isDeleted) {
        return false;
      }
    }
    if (canvasObj == null) {
      final primary = find(session.activeId);
      final secondary = find(session.secondaryId);
      if (secondary != null &&
          secondary.typeId == 'orbit.canvas' &&
          !secondary.isDeleted) {
        canvasObj = secondary;
      } else if (primary != null &&
          primary.typeId == 'orbit.canvas' &&
          !primary.isDeleted) {
        canvasObj = primary;
      } else {
        final existingCanvases = ofType('orbit.canvas');
        if (existingCanvases.isNotEmpty) {
          canvasObj = existingCanvases.first;
        } else {
          canvasObj = await create(
            'orbit.canvas',
            title: '$pdfTitle Canvas',
            open: false,
          );
        }
      }
    }

    if (opening != workspaceGeneration ||
        canvasObj == null ||
        canvasObj.isReadOnly ||
        canvasObj.isDeleted ||
        canvasObj.typeId != 'orbit.canvas' ||
        editorDraftConflicts.values.any((d) => d.objectId == canvasObj!.id)) {
      return false;
    }

    final scene = CanvasScene.fromJson(canvasObj.data);
    if (scene.readOnly) return false;
    final count = scene.elements.length;
    final atX = 160.0 + (count % 4) * 320.0;
    final atY = 160.0 + (count ~/ 4) * 180.0;
    final cardText = '${quote.trim()}\n\n— $pdfTitle, p. $page';
    final element = CanvasElement({
      'id': const Uuid().v4(),
      'type': 'card',
      'objectId': pdfId,
      'x': atX,
      'y': atY,
      'width': 280.0,
      'height': 140.0,
      'text': cardText,
      'color': 0xff8b7cf6,
      'presentation': 'transclusion',
      'referenceTarget': '$pdfId#page=$page',
      'quote': quote.trim(),
      'sourceTitle': pdfTitle,
      'sourceId': pdfId,
      'page': page,
      'data': {
        'quote': quote.trim(),
        'sourceTitle': pdfTitle,
        'sourceId': pdfId,
        'page': page,
        'presentation': 'transclusion',
        'referenceTarget': '$pdfId#page=$page',
      },
    });
    scene.put(element);
    edit(canvasObj.id, data: scene.toJson());
    await flush(canvasObj.id);
    if (opening != workspaceGeneration ||
        dirty.contains(canvasObj.id) ||
        failures.containsKey(canvasObj.id) ||
        find(canvasObj.id)?.isDeleted != false) {
      return false;
    }

    if (session.activeId != canvasObj.id &&
        session.secondaryId != canvasObj.id) {
      openObject(canvasObj.id, secondary: true);
    }
    return true;
  }

  Future<UniversalObject?> createPdfHighlight(
    String fileId,
    String checksum,
    String quote,
    List<CanvasElement> regions, {
    String comment = '',
    bool pageComment = false,
  }) async {
    final opening = workspaceGeneration, repo = repository;
    final file = find(fileId);
    if (file == null ||
        file.isDeleted ||
        file.isReadOnly ||
        repository.readOnly ||
        file.typeId != 'orbit.file' ||
        file.properties['mimeType'] != 'application/pdf' ||
        file.properties['checksum'] != checksum ||
        (pageComment ? comment.trim().isEmpty : quote.trim().isEmpty) ||
        comment.length > 100000 ||
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
      final note = await repo.create(
        typeId: 'orbit.note',
        title:
            '${file.title} · ${pageComment ? 'comment' : 'highlight'} p. $page',
        body: pageComment
            ? '${ObjectReference(fileId, page: page).markdown(file.title)}\n\n$comment'
            : '${ObjectReference(fileId, page: page).quoteMarkdown(file.title, quote)}${comment.trim().isEmpty ? '' : '\n\n$comment'}',
        properties: {
          'pdfHighlightVersion': 1,
          'pdfSource': {
            'objectId': fileId,
            'checksum': checksum,
            'page': page,
            'quote': quote,
            if (pageComment) 'kind': 'pageComment',
            'regions': regions.map((r) => r.data).toList(),
          },
        },
      );
      if (opening != workspaceGeneration || !identical(repo, repository)) {
        return null;
      }
      objects = [...objects, note];
      error = null;
      notify();
      return note;
    } catch (e) {
      if (opening != workspaceGeneration || !identical(repo, repository)) {
        return null;
      }
      error = '$e';
      notify();
      return null;
    }
  }

  Future<UniversalObject?> createPdfPageComment(
    String fileId,
    String checksum,
    int page,
    String comment,
  ) async {
    if (page < 1 || page > 999999) return null;
    final count = activeObjects
        .where(PdfAnnotation.isAnnotation)
        .map(PdfAnnotation.new)
        .where((a) => a.fileId == fileId && a.page == page && a.isPageComment)
        .length;
    return createPdfHighlight(
      fileId,
      checksum,
      '',
      [
        CanvasElement({
          'id': 'page-comment',
          'type': 'rectangle',
          'page': page,
          'x': .03 + (count % 10) * .06,
          'y': .03 + ((count ~/ 10) % 10) * .06,
          'width': .04,
          'height': .04,
          'color': 0xff8b7cf6,
        }),
      ],
      comment: comment,
      pageComment: true,
    );
  }

  Future<bool> saveAnnotatedPdfCopy(
    UniversalObject expectedSource,
    List<PdfAnnotation> annotations,
    Uint8List bytes,
  ) async {
    final file = find(expectedSource.id);
    if (repository.readOnly ||
        file == null ||
        file.isDeleted ||
        file.isReadOnly ||
        !identical(file, expectedSource) ||
        file.typeId != 'orbit.file' ||
        file.properties['mimeType'] != 'application/pdf' ||
        annotations.isEmpty ||
        annotations.any(
          (a) =>
              !identical(find(a.object.id), a.object) ||
              !PdfAnnotation.isAnnotation(a.object) ||
              a.fileId != file.id ||
              !a.matches(file.properties['checksum'] as String?),
        )) {
      return false;
    }
    try {
      final copy = await repository.importAttachment(
        name:
            '${file.title.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '')} · annotated.pdf',
        bytes: bytes,
      );
      if (find(copy.id) == null) objects = [...objects, copy];
      error = null;
      notify();
      return true;
    } catch (e) {
      error = '$e';
      notify();
      return false;
    }
  }

  /// Uses ordinary revision-checked note saves and history. A stale popup or
  /// concurrent writing draft must never delete/restore a newer annotation.
  Future<PdfAnnotation?> deletePdfReview(PdfAnnotation expected) async =>
      _setPdfReviewTrashed(expected, trashed: true);

  Future<UniversalObject?> deletePdfLinkedNote(
    UniversalObject expected,
    String fileId,
  ) async {
    if (expected.typeId != 'orbit.note' ||
        !pdfLinkedNotes(fileId).any((n) => identical(n, expected))) {
      return null;
    }
    return await trash(expected.id, expected: expected)
        ? find(expected.id)
        : null;
  }

  Future<bool> restorePdfReview(PdfAnnotation expected) async =>
      await _setPdfReviewTrashed(expected, trashed: false) != null;

  Future<PdfAnnotation?> _setPdfReviewTrashed(
    PdfAnnotation expected, {
    required bool trashed,
  }) async {
    if (!hasWorkspace ||
        loading ||
        repository.readOnly ||
        !identical(find(expected.object.id), expected.object) ||
        expected.object.isReadOnly ||
        expected.object.isDeleted == trashed ||
        expected.object.typeId != 'orbit.note' ||
        expected.object.properties['pdfHighlightVersion'] != 1 ||
        expected.fileId == null ||
        dirty.contains(expected.object.id) ||
        _saving.containsKey(expected.object.id) ||
        editorDraftConflicts.values.any(
          (d) => d.objectId == expected.object.id,
        )) {
      return null;
    }
    final repo = repository, opening = workspaceGeneration;
    try {
      final saved = await repo.save(
        expected.object.copyWith(
          deletedAt: trashed ? DateTime.now().toUtc() : null,
          clearDeletedAt: !trashed,
        ),
      );
      if (workspaceGeneration != opening || !identical(repository, repo)) {
        return null;
      }
      _mergeSavedDeletion(saved);
      if (trashed) {
        // The save above already retains the before-image. Generic closeTab
        // creates another snapshot, changing the just-deleted revision and
        // invalidating Undo. Close only its presentation here.
        _closeTrashedTabs(saved.id);
      }
      error = null;
      notify();
      return PdfAnnotation(saved);
    } on Object catch (e) {
      if (workspaceGeneration == opening && identical(repository, repo)) {
        error =
            'Could not ${trashed ? 'delete' : 'restore'} the review item. Its saved note and original PDF are retained. $e';
        notify();
      }
      return null;
    }
  }

  Future<bool> updatePdfReview(
    PdfAnnotation expected, {
    required String body,
    required int color,
    required String style,
    required bool resolved,
  }) async {
    final current = find(expected.object.id);
    final file = find(expected.fileId ?? '');
    if (current == null ||
        !identical(current, expected.object) ||
        !PdfAnnotation.isAnnotation(current) ||
        current.isReadOnly ||
        repository.readOnly ||
        file == null ||
        file.isDeleted ||
        file.isReadOnly ||
        !expected.matches(file.properties['checksum'] as String?) ||
        body.length > 1000000 ||
        color < 0xff000000 ||
        color > 0xffffffff ||
        !{'highlight', 'underline', 'strikeout'}.contains(style) ||
        (current.properties['pdfReview'] is Map &&
            (current.properties['pdfReview'] as Map)['version'] != 1)) {
      return false;
    }
    final source = Map<String, dynamic>.from(expected.source);
    source['regions'] = [
      for (final region in source['regions'] as List? ?? const [])
        if (region is Map &&
            PdfAnnotation.validRegion(
              CanvasElement(Map<String, dynamic>.from(region)),
            ))
          {...region, 'color': color, 'style': style}
        else
          region,
    ];
    edit(
      current.id,
      body: body,
      properties: {
        ...current.properties,
        'pdfSource': source,
        'pdfReview': {
          if (current.properties['pdfReview'] is Map)
            ...current.properties['pdfReview'] as Map,
          'version': 1,
          'resolved': resolved,
        },
      },
    );
    await flush(current.id);
    return !dirty.contains(current.id) && !failures.containsKey(current.id);
  }

  Future<UniversalObject?> createPdfReviewSummary(
    String fileId,
    List<String> ids,
  ) async {
    final file = find(fileId);
    if (repository.readOnly ||
        file == null ||
        file.isDeleted ||
        file.isReadOnly ||
        file.typeId != 'orbit.file' ||
        file.properties['mimeType'] != 'application/pdf' ||
        ids.isEmpty ||
        ids.length > 10000) {
      return null;
    }
    final annotations = <PdfAnnotation>[];
    for (final id in ids.toSet()) {
      final object = find(id);
      if (object == null || !PdfAnnotation.isAnnotation(object)) return null;
      final annotation = PdfAnnotation(object);
      if (annotation.fileId != fileId) return null;
      annotations.add(annotation);
    }
    try {
      final body = pdfReviewMarkdown(
        file.title,
        fileId,
        annotations,
        checksum: file.properties['checksum'] as String?,
      );
      if (body.length > 2000000) return null;
      final note = await repository.create(
        typeId: 'orbit.note',
        title: 'Review · ${file.title}',
        body: body,
        properties: {
          'pdfSource': {
            'objectId': fileId,
            'page': 1,
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

  Future<bool> renamePdfBookmark(
    String id,
    int page,
    String name, {
    required String? expectedChecksum,
  }) async {
    final object = find(id);
    final label = name.trim();
    if (object == null ||
        object.isReadOnly ||
        repository.readOnly ||
        object.isDeleted ||
        object.typeId != 'orbit.file' ||
        object.properties['checksum'] != expectedChecksum ||
        label.length > 200 ||
        object.properties['pdfBookmarks'] is! List ||
        !(object.properties['pdfBookmarks'] as List).contains(page) ||
        page < 1 ||
        (object.properties['pdfBookmarkNames'] != null &&
            object.properties['pdfBookmarkNames'] is! Map)) {
      return false;
    }
    final names = <String, dynamic>{
      if (object.properties['pdfBookmarkNames'] is Map)
        for (final entry
            in (object.properties['pdfBookmarkNames'] as Map).entries)
          if (entry.key is String) entry.key as String: entry.value,
    };
    if (label.isEmpty) {
      names.remove('$page');
    } else {
      names['$page'] = label;
    }
    edit(id, properties: {...object.properties, 'pdfBookmarkNames': names});
    await flush(id);
    final latest = find(id);
    final savedNames = latest?.properties['pdfBookmarkNames'];
    return !dirty.contains(id) &&
        !failures.containsKey(id) &&
        latest?.properties['checksum'] == expectedChecksum &&
        savedNames is Map &&
        (label.isEmpty
            ? !savedNames.containsKey('$page')
            : savedNames['$page'] == label);
  }

  void edit(
    String id, {
    String? title,
    String? body,
    Map<String, dynamic>? properties,
    Map<String, dynamic>? data,
  }) {
    final object = find(id);
    if (object == null ||
        object.isDeleted ||
        object.isReadOnly ||
        repository.readOnly) {
      return;
    }
    if (object.typeId == 'orbit.task' &&
        object.properties['recurrence'] != null &&
        !object.isCompleted &&
        properties?['completed'] == true) {
      unawaited(completePlannedTask(object));
      return;
    }
    try {
      if (properties != null) validateResearchProperties(properties);
      if (properties != null &&
          jsonEncode(properties['workingCalendar']) !=
              jsonEncode(object.properties['workingCalendar']) &&
          properties['workingCalendar'] != null) {
        WorkingCalendar(
          Map<String, dynamic>.from(properties['workingCalendar'] as Map),
        );
      }
      if (object.typeId == 'orbit.task' && properties != null) {
        properties = completeTaskOccurrence(object, properties, DateTime.now());
        validateTaskWorkCalendar(object, properties);
        if ([
          'scheduledDate',
          'scheduledEndDate',
          'ganttMilestone',
        ].any((k) => properties![k] != object.properties[k])) {
          validateGanttSchedule(properties);
        }
        validateTaskPlanning(
          object.copyWith(properties: properties),
          objects,
          previous: object,
        );
      }
      if (object.typeId == 'orbit.view' && properties?['smartQuery'] != null) {
        SmartViewQuery(
          Map<String, dynamic>.from(properties!['smartQuery'] as Map),
        );
      }
    } on Object catch (e) {
      error = '$e';
      notify();
      return;
    }
    final perf = CanvasPerformance.instance;
    final comparisonStarted = perf.begin();
    final unchanged =
        (title == null || title == object.title) &&
        (body == null || body == object.body) &&
        (properties == null ||
            jsonEncode(properties) == jsonEncode(object.properties)) &&
        (data == null || jsonValuesEqual(data, object.data));
    perf.duration(CanvasPerfEvent.draftCompare, 0, comparisonStarted);
    if (unchanged) {
      return;
    }
    final snapshotStarted = perf.begin();
    final updated = object.copyWith(
      title: title,
      body: body,
      properties: properties,
      data: data,
      updatedAt: DateTime.now().toUtc(),
    );
    perf.duration(CanvasPerfEvent.draftSnapshot, 0, snapshotStarted);
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
      final interval = session.autoSaveInterval.clamp(200, 10000);
      _timers[id] = Timer(Duration(milliseconds: interval), () => flush(id));
    }
    final notifyStarted = perf.begin();
    notify();
    perf.duration(CanvasPerfEvent.draftNotify, 0, notifyStarted);
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

  /// Serializes source changes with normal object saves. Later unrelated edits
  /// keep their draft while adopting the durably committed source metadata.
  Future<bool> changeAttachmentSource(
    UniversalObject expected, {
    String? name,
    Uint8List? bytes,
    String? retainedReference,
    Stream<List<int>>? byteStream,
    String? expectedChecksum,
    void Function(int bytesRead, int totalBytes, String phase)? onProgress,
    String? resumableStageId,
    bool Function()? isCancelled,
  }) async {
    if (!identical(find(expected.id), expected) ||
        dirty.contains(expected.id) ||
        _saving.containsKey(expected.id)) {
      error =
          'The attachment changed or has unsaved edits. Save it and reopen recovery.';
      notify();
      return false;
    }
    var committed = false;
    Future<void> commit() async {
      try {
        final saved = retainedReference != null
            ? await repository.restoreAttachmentSource(
                expected,
                retainedReference,
                onProgress: onProgress,
                isCancelled: isCancelled,
              )
            : byteStream != null
            ? await repository.relinkAttachmentStream(
                expected,
                name: name!,
                expectedChecksum: expectedChecksum!,
                bytes: byteStream,
                onProgress: onProgress == null
                    ? null
                    : (bytesRead) =>
                          onProgress(bytesRead, 0, 'Saving new source…'),
                resumableStageId: resumableStageId,
                isCancelled: isCancelled,
              )
            : await repository.relinkAttachment(
                expected,
                name: name!,
                bytes: bytes!,
              );
        final current = find(expected.id);
        final sourceEdited =
            current != null &&
            const [
              'contentRef',
              'originalName',
              'mimeType',
              'byteLength',
              'checksum',
              'attachmentSourceHistory',
            ].any(
              (key) =>
                  jsonEncode(current.properties[key]) !=
                  jsonEncode(expected.properties[key]),
            );
        if (sourceEdited) {
          failures[expected.id] =
              'The source changed during recovery. Your draft is retained; review it before saving.';
        }
        objects = [
          for (final object in objects)
            if (object.id != saved.id)
              object
            else if (identical(current, expected))
              saved
            else if (sourceEdited)
              object.copyWith(revision: saved.revision)
            else
              object.copyWith(
                revision: saved.revision,
                properties: {
                  ...object.properties,
                  for (final key in const [
                    'contentRef',
                    'originalName',
                    'mimeType',
                    'byteLength',
                    'checksum',
                    'attachmentSourceHistory',
                  ])
                    key: saved.properties[key],
                },
              ),
        ];
        attachmentRevision++;
        error = null;
        committed = true;
      } catch (e) {
        error = 'Could not change attachment source: $e';
      }
    }

    final work = commit();
    _saving[expected.id] = work;
    await work;
    _saving.remove(expected.id);
    notify();
    return committed;
  }

  Future<bool> recoverMissingAttachment(
    String reference,
    Uint8List bytes,
    String checksum,
  ) async {
    try {
      await repository.recoverMissingAttachment(
        reference,
        bytes,
        expectedChecksum: checksum,
      );
      attachmentRevision++;
      error = null;
      notify();
      return true;
    } catch (e) {
      error = 'Could not restore original attachment: $e';
      notify();
      return false;
    }
  }

  Future<bool> recoverMissingAttachmentStream(
    String reference,
    Stream<List<int>> bytes,
    String checksum, {
    void Function(int bytesRead)? onProgress,
    String? resumableStageId,
    bool Function()? isCancelled,
  }) async {
    try {
      await repository.recoverMissingAttachmentStream(
        reference,
        bytes,
        expectedChecksum: checksum,
        onProgress: onProgress,
        resumableStageId: resumableStageId,
        isCancelled: isCancelled,
      );
      attachmentRevision++;
      error = null;
      notify();
      return true;
    } catch (e) {
      error = 'Could not restore original attachment: $e';
      notify();
      return false;
    }
  }

  Future<bool> forgetAttachmentSourceVersion(
    UniversalObject expected,
    String reference, {
    void Function(int bytesRead, int totalBytes, String phase)? onProgress,
    bool Function()? isCancelled,
  }) async {
    try {
      final saved = await repository.forgetAttachmentSourceVersion(
        expected,
        reference,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
      final current = find(expected.id);
      if (current != null && identical(current, expected)) {
        objects = [
          for (final object in objects) object.id == saved.id ? saved : object,
        ];
      } else if (current != null) {
        objects = [
          for (final object in objects)
            object.id == saved.id
                ? object.copyWith(
                    revision: saved.revision,
                    properties: {
                      ...object.properties,
                      'attachmentSourceHistory':
                          saved.properties['attachmentSourceHistory'],
                    },
                  )
                : object,
        ];
      }
      attachmentRevision++;
      error = null;
      notify();
      return true;
    } catch (e) {
      error = 'Could not clean up retained source: $e';
      notify();
      return false;
    }
  }

  Future<void> _saveDraft(UniversalObject before) async {
    try {
      final wasCompleted =
          repository.objects
              .where((o) => o.id == before.id)
              .firstOrNull
              ?.isCompleted ==
          true;
      final saved = await repository.save(before);
      recordProjectActivity(
        saved,
        saved.isCompleted && !wasCompleted ? 'completed' : 'saved',
      );
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
    final finance = _financeWork;
    if (finance != null) await finance.future;
    final productivity = _productivityOperation;
    if (productivity != null) await productivity.future;
    for (final id in List.of(dirty)) {
      await flush(id);
    }
    await saveSession();
    return dirty.isEmpty &&
        failures.isEmpty &&
        !_settingsSaveFailed &&
        editorDraftConflicts.isEmpty;
  }

  void cancelAllTimers() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _sessionTimer?.cancel();
    _externalDebounce?.cancel();
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

  void _closeTrashedTabs(String id) {
    final beside = session.secondaryId;
    session.tabs = session.tabs.where((v) => v != id).toList();
    session.pinnedTabs = session.pinnedTabs.where((v) => v != id).toList();
    session.closedTabs = session.closedTabs.where((v) => v != id).toList();
    if (lastClosed == id) lastClosed = null;
    if (session.activeId == id) {
      session.activeId = beside != id && find(beside)?.isDeleted == false
          ? beside
          : session.tabs.lastOrNull;
      if (session.activeId != null &&
          !session.tabs.contains(session.activeId)) {
        session.tabs.add(session.activeId!);
      }
    }
    if (session.secondaryId == id || session.secondaryId == session.activeId) {
      session.secondaryId = null;
    }
    persistSession();
  }

  // A keystroke delivered while a durable deletion is pending remains in the
  // same recoverable Trash note, with the committed revision as its save base.
  void _mergeSavedDeletion(UniversalObject saved) {
    final draft = find(saved.id);
    mergeRepositoryObjects();
    if (draft != null && dirty.contains(saved.id)) {
      objects = [
        for (final o in objects)
          if (o.id == saved.id)
            draft.copyWith(
              revision: saved.revision,
              deletedAt: saved.deletedAt,
              clearDeletedAt: !saved.isDeleted,
            )
          else
            o,
      ];
    }
  }

  Future<bool> trash(String id, {UniversalObject? expected}) async {
    final repo = repository, opening = workspaceGeneration;
    if (find(id) == null) mergeRepositoryObjects();
    final object = find(id), key = '$opening:$id';
    if (object == null || object.isDeleted) return false;
    if (repo.readOnly ||
        object.isReadOnly ||
        (expected != null && !identical(expected, object)) ||
        editorDraftConflicts.values.any((d) => d.objectId == id)) {
      error =
          'Could not move this note to Trash. Resolve its editing conflict or read-only state, then retry.';
      notify();
      return false;
    }
    if (!_trashing.add(key)) return false;
    try {
      await flush(id);
      final current = find(id);
      if (opening != workspaceGeneration || !identical(repo, repository)) {
        return false;
      }
      if (current == null ||
          current.isDeleted ||
          current.isReadOnly ||
          dirty.contains(id) ||
          failures.containsKey(id) ||
          editorDraftConflicts.values.any((d) => d.objectId == id) ||
          current.body != object.body ||
          current.title != object.title ||
          !jsonValuesEqual(
            Map<String, dynamic>.from(current.properties)
              ..remove('orbitLinkBindings')
              ..remove('aliases'),
            Map<String, dynamic>.from(object.properties)
              ..remove('orbitLinkBindings')
              ..remove('aliases'),
          ) ||
          !jsonValuesEqual(current.data, object.data)) {
        error =
            'Could not move this note to Trash. Its latest edits are retained; check the save status and retry.';
        notify();
        return false;
      }
      final saved = await repo.save(
        current.copyWith(deletedAt: DateTime.now().toUtc()),
      );
      if (opening != workspaceGeneration || !identical(repo, repository)) {
        return false;
      }
      _mergeSavedDeletion(saved);
      _closeTrashedTabs(id);
      error = null;
      notify();
      return true;
    } catch (e) {
      if (opening == workspaceGeneration && identical(repo, repository)) {
        error =
            'Could not move this note to Trash. Your note and original files are retained. $e';
        notify();
      }
      return false;
    } finally {
      _trashing.remove(key);
    }
  }

  Future<bool> restore(String id, {UniversalObject? expected}) async {
    final repo = repository, opening = workspaceGeneration;
    if (expected != null &&
        (!identical(find(id), expected) || dirty.contains(id))) {
      return false;
    }
    try {
      await flush(id);
      if (opening != workspaceGeneration ||
          !identical(repo, repository) ||
          dirty.contains(id) ||
          failures.containsKey(id)) {
        return false;
      }
      final current = find(id);
      if (current == null ||
          !current.isDeleted ||
          (expected != null && !identical(current, expected)) ||
          current.isReadOnly ||
          repo.readOnly ||
          editorDraftConflicts.values.any((d) => d.objectId == id)) {
        return false;
      }
      final saved = await repo.save(current.copyWith(clearDeletedAt: true));
      if (opening != workspaceGeneration || !identical(repo, repository)) {
        return false;
      }
      _mergeSavedDeletion(saved);
      error = null;
      notify();
      return true;
    } catch (e) {
      if (opening == workspaceGeneration && identical(repo, repository)) {
        error = '$e';
        notify();
      }
      return false;
    }
  }

  List<Map<String, dynamic>> getDocumentSnapshots(String id) {
    final object = find(id);
    if (object == null) return [];
    final raw = object.properties['revisions'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>?> createDocumentSnapshot(
    String id, {
    String label = 'Snapshot',
    String? title,
    String? body,
  }) async {
    final object = find(id);
    if (object == null ||
        object.isDeleted ||
        object.isReadOnly ||
        repository.readOnly) {
      return null;
    }
    final now = DateTime.now();
    final snapTitle = title ?? object.title;
    final snapBody = body ?? object.body;
    final words = snapBody.trim().isEmpty
        ? 0
        : snapBody.trim().split(RegExp(r'\s+')).length;

    final snapshot = {
      'id': 'rev-${now.millisecondsSinceEpoch}',
      'revision': object.revision,
      'timestamp': now.toIso8601String(),
      'title': snapTitle,
      'body': snapBody,
      'wordCount': words,
      'label': label,
    };

    final existing = getDocumentSnapshots(id);
    final updatedList = [snapshot, ...existing].take(30).toList();

    edit(id, properties: {...object.properties, 'revisions': updatedList});
    await flush(id);
    return snapshot;
  }

  Future<bool> restoreDocumentSnapshot(String id, String snapshotId) async {
    final object = find(id);
    if (object == null) return false;
    final snapshots = getDocumentSnapshots(id);
    final target = snapshots.where((s) => s['id'] == snapshotId).firstOrNull;
    if (target == null) return false;

    await createDocumentSnapshot(
      id,
      label: 'Pre-restore checkpoint',
      title: object.title,
      body: object.body,
    );

    edit(
      id,
      title: target['title']?.toString() ?? object.title,
      body: target['body']?.toString() ?? object.body,
    );
    await flush(id);
    return true;
  }

  Future<void> deleteFolder(String folder) => organize(() async {
    await repository.deleteFolder(folder);
    session.archivedFolders.removeWhere(
      (f) => f == folder || f.startsWith('$folder/'),
    );
    session.collapsedFolders.removeWhere(
      (f) => f == folder || f.startsWith('$folder/'),
    );
    session.folderColors = {
      for (final entry in session.folderColors.entries)
        if (entry.key != folder && !entry.key.startsWith('$folder/'))
          entry.key: entry.value,
    };
    persistSession();
  });

  void _purgeNavHistory(Set<String> ids) {
    if (_navHistory.isEmpty) return;
    final currentId = (_navIndex >= 0 && _navIndex < _navHistory.length)
        ? _navHistory[_navIndex]
        : null;
    _navHistory.removeWhere(ids.contains);
    if (_navHistory.isEmpty) {
      _navIndex = -1;
    } else if (currentId != null && _navHistory.contains(currentId)) {
      _navIndex = _navHistory.lastIndexOf(currentId);
    } else {
      _navIndex = _navIndex.clamp(0, _navHistory.length - 1);
    }
  }

  void _purgeSessionReferences(Set<String> ids) {
    locationRequests.removeWhere((id, _) => ids.contains(id));
    session.bookmarkedTabs = session.bookmarkedTabs
        .where((id) => !ids.contains(id))
        .toList();
    session.pinnedTabs = session.pinnedTabs
        .where((id) => !ids.contains(id))
        .toList();
    session.recent = session.recent.where((id) => !ids.contains(id)).toList();
    session.closedTabs = session.closedTabs
        .where((id) => !ids.contains(id))
        .toList();
    session.positions = Map.of(session.positions)
      ..removeWhere(
        (k, _) => ids.contains(k) || ids.any((id) => k.endsWith(':$id')),
      );
    session.cameras = Map.of(session.cameras)
      ..removeWhere((k, _) => ids.contains(k));
    session.noteViews = Map.of(session.noteViews)
      ..removeWhere((k, _) => ids.contains(k));
    _purgeNavHistory(ids);
  }

  // A journal can complete some owners before a later owner fails. Reconcile
  // only removed IDs, retaining surviving Trash items and their session state.
  void _reconcileRemovedObjects(Set<String> candidates) {
    final remaining = repository.objects.map((o) => o.id).toSet();
    final removed = candidates.difference(remaining);
    mergeRepositoryObjects();
    for (final id in removed) {
      closeTab(id);
      if (lastClosed == id) lastClosed = null;
    }
    _purgeSessionReferences(removed);
    persistSession();
  }

  Future<void> deletePermanently(String id, {UniversalObject? expected}) async {
    final repo = repository, generation = workspaceGeneration;
    bool current() =>
        _alive &&
        identical(repo, repository) &&
        generation == workspaceGeneration;
    if (expected != null && !identical(find(id), expected)) return;
    await flush(id);
    if (!current() ||
        dirty.contains(id) ||
        failures.containsKey(id) ||
        editorDraftConflicts.values.any((d) => d.objectId == id) ||
        (expected != null && !identical(find(id), expected))) {
      return;
    }
    try {
      await repo.deletePermanently(id);
      if (current()) error = null;
    } catch (e) {
      if (current()) error = '$e';
    } finally {
      if (current()) {
        _reconcileRemovedObjects({id});
        notify();
      }
    }
  }

  Future<void> emptyTrash() async {
    final repo = repository, generation = workspaceGeneration;
    final trashedIds = objects
        .where((o) => o.isDeleted)
        .map((o) => o.id)
        .toSet();
    bool current() =>
        _alive &&
        identical(repo, repository) &&
        generation == workspaceGeneration;
    if (!await flushAll() || !current()) return;
    try {
      await repo.emptyTrash(ids: trashedIds);
      if (current()) error = null;
    } catch (e) {
      if (current()) error = '$e';
    } finally {
      if (current()) {
        _reconcileRemovedObjects(trashedIds);
        notify();
      }
    }
  }

  bool get showAttachments => session.showAttachments;
  void toggleShowAttachments() =>
      updateSession((s) => s.showAttachments = !s.showAttachments);

  bool get explorerCalendarCollapsed => session.explorerCalendarCollapsed;
  void toggleExplorerCalendar() => updateSession(
    (s) => s.explorerCalendarCollapsed = !s.explorerCalendarCollapsed,
  );

  Future<void> refresh() async {
    if (!await flushAll()) return;
    try {
      await repository.refresh();
      mergeRepositoryObjects();
      _pdfIndexer?.invalidatePath('*');
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
    if (loading || !hasWorkspace || _checkingExternal || repository.isBrowser) {
      return;
    }
    _checkingExternal = true;
    if (changedPaths == null || changedPaths.contains('*')) {
      _pdfIndexer?.invalidatePath('*');
    }
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
    if (loading || !hasWorkspace || repository.readOnly) return;
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
    var requiresNotification = _settingsSaveFailed;
    try {
      while (_settingsSaveRequested) {
        _settingsSaveRequested = false;
        final owner = repository.workspaceId;
        final generation = _workspaceGeneration;
        if (session.extra['portablePreferenceRecordId'] is! String) {
          session = SessionState.fromJson({
            ...session.toJson(),
            'portablePreferenceRecordId': const Uuid().v4(),
          });
        }
        final recordId = session.extra['portablePreferenceRecordId'] as String;
        final portable = PortablePreferences.select(session.toJson());
        final seed = repository.preferenceRecords.isEmpty;
        final defaults = seed
            ? PortablePreferences.select(SessionState().toJson())
            : const <String, dynamic>{};
        final changes = <String, dynamic>{
          for (final entry in portable.entries)
            if ((seed &&
                    !PortablePreferences.equal(
                      entry.value,
                      defaults[entry.key],
                    )) ||
                !PortablePreferences.equal(
                  entry.value,
                  _portableBaseline[entry.key],
                ))
              entry.key: entry.value,
        };
        session = SessionState.fromJson({
          ...session.toJson(),
          'pendingPortablePreferences': changes,
        });
        await repository.writeDeviceSettings(session.toJson());
        if (generation != _workspaceGeneration ||
            owner != repository.workspaceId) {
          throw const WorkspaceConflict(
            'The Vault changed while saving preferences.',
          );
        }
        if (changes.isNotEmpty) {
          requiresNotification = true;
          await repository.writePortablePreferences(recordId, changes);
          preferenceRevision++;
          for (final key in changes.keys) {
            _portableBaseline[key] = portable[key];
          }
          // The device outbox survives a crash between local and portable saves.
          // Leave it on disk until the portable command has durably succeeded.
          session = SessionState.fromJson({
            ...session.toJson(),
            'pendingPortablePreferences': <String, dynamic>{},
          });
          await repository.writeDeviceSettings(session.toJson());
        }
      }
      _settingsSaveFailed = false;
      // Camera/scroll/device-only checkpoints do not change shell content.
      // Preference publication and recovery still notify sync and status UI.
      if (requiresNotification) notify();
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
    s.focusMode = false;
    s.dashboard = {};
    if (WorkspaceContext.supported(s.spaces)) {
      s.spaces = {...s.spaces, 'activeId': null};
    }
  });
}
