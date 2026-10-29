import '../../canvas/university_diagram.dart';
import '../../domain/university/lab_document.dart';
import '../../domain/edge_scroll.dart';
import '../../app/retained_form.dart';
import '../../canvas/snap_index.dart';
import '../../domain/university/lab_presets.dart';
import '../university/university_lab_dialog.dart';
import '../../canvas/brainstorm.dart';
import 'brainstorm_dialog.dart';
import 'workshop_dialog.dart';
import 'canvas_presentation_dialog.dart';
import '../../app/orbit_laser_surface.dart';
import '../notes/media_clipboard.dart';
import '../math/math_lab_dialog.dart';
import '../../canvas/math_plot_elements.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import 'dart:async';
import 'dart:collection';
import 'canvas_live_ink.dart';
import 'canvas_scene_viewport.dart';
import '../../app/canvas_performance.dart';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../canvas/geometry.dart';
import '../../canvas/character_recognizer.dart';
import '../../canvas/arrangement.dart';
import '../../canvas/use_case_arrangement.dart';
import '../../canvas/canvas_svg.dart';
import '../../canvas/diagram_export.dart';
import '../../canvas/shape_recognizer.dart';
import '../../canvas/columns.dart';
import '../../canvas/connectors.dart';
import '../../canvas/groups.dart';
import '../../canvas/scene.dart';
import '../../canvas/use_case_routing.dart';
import '../../canvas/starter_templates.dart';
import 'canvas_starter_dialog.dart';
import '../../domain/json_values.dart';
import '../../domain/object_reference.dart';
import '../../platform/export_file.dart';
import '../../domain/pdf_quote_transfer.dart';
import 'canvas_painter.dart';
import 'canvas_presence_overlay.dart';
import 'canvas_images.dart';
import 'canvas_rich_text.dart';
import 'canvas_import_dialog.dart';
import '../../canvas/canvas_search.dart';
import '../../canvas/reference_capture.dart';
import 'canvas_search_overlay.dart';
import 'reference_details_dialog.dart';
import '../../canvas/uml.dart';
import '../../canvas/sequence_class_draft.dart';
import '../../canvas/uml_interaction.dart';
import 'uml_interaction_dialog.dart';
import '../../canvas/diagram_reference.dart';
import 'uml_dialog.dart';
import 'research_diagram_dialog.dart';
import '../../canvas/research_diagrams.dart';
import 'audio_player_card.dart';
import '../notes/export/pdf_bundle_dialog.dart';
import '../../domain/universal_object.dart';

export '../../domain/pdf_quote_transfer.dart' show PdfQuoteDragData;
export 'canvas_painter.dart' show CanvasObjectReference;
export 'canvas_images.dart' show CanvasImageReference;

enum _Tool {
  select,
  lasso,
  pan,
  sticky,
  text,
  rectangle,
  ellipse,
  diamond,
  arrow,
  line,
  pen,
  highlighter,
  eraser,
  frame,
}

enum CanvasAlignment {
  left,
  centerH,
  right,
  top,
  middleV,
  bottom,
  distributeH,
  distributeV,
}

class CanvasBreadcrumb {
  const CanvasBreadcrumb({required this.id, required this.title});
  final String id;
  final String title;
}

/// Ephemeral bridge for native file drops; scene mutations still use Canvas undo.
class CanvasCaptureController {
  final _placements =
      <Object, bool Function(List<String>)? Function(Offset?)>{};
  bool Function(List<String>)? prepare({Offset? globalPosition}) {
    for (final prepare in _placements.values.toList().reversed) {
      final ticket = prepare(globalPosition);
      if (ticket != null) return ticket;
    }
    return null;
  }

  bool place(List<String> ids, {Offset? globalPosition}) {
    return prepare(globalPosition: globalPosition)?.call(ids) ?? false;
  }
}

class CanvasEditor extends StatefulWidget {
  const CanvasEditor({
    super.key,
    required this.canvasId,
    this.readOnly = false,
    this.interactionActive = true,
    this.onActivate,
    this.focusMode = false,
    this.onToggleFocusMode,
    this.title = '',
    this.onTitleChanged,
    this.onSavePersonalTemplate,
    required this.data,
    required this.onChanged,
    this.onDraftChanged,
    this.draftBaseData,
    this.retainConflictingDraft = false,
    required this.objects,
    required this.onOpenObject,
    this.camera,
    this.onCameraChanged,
    this.restoreViewSerial = 0,
    this.imageLoader,
    this.imageRevision = 0,
    this.onInsertImage,
    this.onPasteImage,
    this.onOpenExternal,
    this.onOpenAttachment,
    this.breadcrumbs,
    this.onToggleTask,
    this.onUpdateObjectProperties,
    this.onExportSelectionToNote,
    this.onExportDiagramToNote,
    this.fontFamily = 'Segoe UI',
    this.defaultBackgroundStyle = 'dots',
    this.defaultSnapToGrid = false,
    this.defaultAudioSpeed = 1.0,
    this.focusElementId,
    this.focusElementIds = const [],
    this.locationSerial = 0,
    this.captureController,
    this.onCaptureReferences,
    this.onPickReference,
    this.onShowObjectConnections,
    this.remoteCursors = const [],
    this.remotePresence,
    this.onPresence,
    this.onPresenceSelection,
    this.onInkPreview,
    this.onPresenceLeave,
  });
  final Future<ObjectReference?> Function()? onPickReference;
  final ValueChanged<String>? onShowObjectConnections;
  final VoidCallback? onSavePersonalTemplate;
  final String canvasId;
  final CanvasCaptureController? captureController;
  final VoidCallback? onCaptureReferences;
  final List<Map<String, dynamic>> remoteCursors;
  final ValueListenable<List<Map<String, dynamic>>>? remotePresence;
  final void Function(double x, double y)? onPresence;
  final ValueChanged<List<String>>? onPresenceSelection;
  final ValueChanged<Map<String, dynamic>?>? onInkPreview;
  final VoidCallback? onPresenceLeave;
  final String? focusElementId;
  final List<String> focusElementIds;
  final int locationSerial;
  final String title;
  final bool readOnly;
  final bool interactionActive;
  final VoidCallback? onActivate;
  final bool focusMode;
  final VoidCallback? onToggleFocusMode;
  final ValueChanged<String>? onTitleChanged;
  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool Function(Map<String, dynamic> base, Map<String, dynamic> next)?
  onDraftChanged;
  final Map<String, dynamic>? draftBaseData;
  final bool retainConflictingDraft;
  final List<CanvasObjectReference> objects;
  final ValueChanged<String> onOpenObject;
  final Map<String, dynamic>? camera;
  final ValueChanged<Map<String, dynamic>>? onCameraChanged;
  final int restoreViewSerial;
  final Future<Uint8List?> Function(String)? imageLoader;

  /// Changes when attachment bytes are replaced outside the object store.
  /// Visible images are then reloaded without rebuilding the Canvas scene.
  final int imageRevision;
  final Future<CanvasImageReference?> Function()? onInsertImage, onPasteImage;
  final ValueChanged<Uri>? onOpenExternal;

  /// Opens an attachment reference through the workspace boundary.
  final ValueChanged<String>? onOpenAttachment;
  final List<CanvasBreadcrumb>? breadcrumbs;
  final ValueChanged<String>? onToggleTask;
  final void Function(String id, Map<String, dynamic> properties)?
  onUpdateObjectProperties;
  final void Function(List<CanvasElement> elements, String markdownNote)?
  onExportSelectionToNote;
  final Future<void> Function(List<String> elementIds)? onExportDiagramToNote;
  final String fontFamily;
  final String defaultBackgroundStyle;
  final bool defaultSnapToGrid;
  final double defaultAudioSpeed;

  @override
  State<CanvasEditor> createState() => _CanvasEditorState();
}

class _CanvasEditorState extends State<CanvasEditor> {
  bool _focusControlsVisible = false;
  bool get _drawingFocus =>
      widget.focusMode && widget.onToggleFocusMode != null;
  bool _laserMode = false;
  final _captureSurface = GlobalKey();
  final _performanceSurface = CanvasPerformance.instance.attach();
  int? _performanceRevision;
  final _dataComparison = ImmutableJsonEqualityCache();
  void _recordPerformanceContext() {
    if (_performanceRevision == _scene.revision) return;
    _performanceRevision = _scene.revision;
    var ink = 0, points = 0;
    for (final element in _scene.elements) {
      if (element.type == 'ink') {
        ink++;
        final samples = element.data['points'];
        if (samples is List) points += samples.length;
      }
    }
    CanvasPerformance.instance.context(_performanceSurface, {
      'elements': _scene.length,
      'strokes': ink,
      'samples': points,
      'revision': _scene.revision,
    });
  }

  Future<void> _editReferenceDetails() async {
    if (_readOnly || _selection.length != 1) return;
    _finishText();
    final element = _scene[_selection.single];
    if (element == null || element.locked || element.type != 'card') return;
    final retained = RetainedForm.capture(
      context,
      'reference:${widget.canvasId}:${element.id}',
      element.data,
    );
    final value = await showReferenceDetails(
      context,
      element,
      _objects[element.objectId]?.title ?? element.text,
      ownerId: widget.canvasId,
    );
    if (!mounted || value == null || _readOnly) return;
    final current = _scene[element.id];
    if (current == null ||
        current.locked ||
        !identical(current.data, element.data)) {
      _notice(
        'This card changed while its details were open. Reopen it to edit the current version.',
      );
      return;
    }
    _history.put(current.copy(value));
    _commit();
    unawaited(retained?.complete() ?? Future<void>.value());
    _focus.requestFocus();
  }

  bool Function(List<String>)? _prepareCapturedReferences(Offset? global) {
    if (!mounted || _readOnly) return null;
    final render = _captureSurface.currentContext?.findRenderObject();
    if (global != null &&
        (render is! RenderBox ||
            !(Offset.zero & render.size).contains(
              render.globalToLocal(global),
            ))) {
      return null;
    }
    final origin = global != null && render is RenderBox
        ? _world(render.globalToLocal(global))
        : _camera.toWorld(
            CanvasPoint(_viewport.width / 2, _viewport.height / 2),
          );
    final canvasId = widget.canvasId, epoch = _interactionEpoch, scene = _scene;
    return (ids) {
      if (!mounted ||
          widget.canvasId != canvasId ||
          _readOnly ||
          ids.isEmpty ||
          epoch != _interactionEpoch ||
          !identical(scene, _scene)) {
        return false;
      }
      return _placeCapturedReferences(ids, origin);
    };
  }

  bool _placeCapturedReferences(List<String> ids, CanvasPoint origin) {
    _finishText();
    final elements = capturedReferencePlacements(_scene, ids, origin, _id);
    for (final e in elements) {
      _history.put(e);
    }
    _selection
      ..clear()
      ..addAll(elements.where((e) => e.type == 'card').map((e) => e.id));
    _commit();
    _focus.requestFocus();
    return true;
  }

  static const _technicalWhite = 0xfff7fbff;
  late CanvasHistory _history;
  late CanvasCamera _camera;
  late final TextEditingController _titleController;
  final _titleFocus = FocusNode(debugLabel: 'CanvasTitle');
  final _focus = FocusNode(debugLabel: 'Canvas');
  final _text = TextEditingController();
  late final _textFocus = FocusNode(
    debugLabel: 'CanvasElementText',
    onKeyEvent: _onTextKeyEvent,
  );
  bool _showSearchHud = false;
  late final TextEditingController _searchController = TextEditingController();
  late final FocusNode _searchFocusNode = FocusNode(
    debugLabel: 'CanvasSearch',
    onKeyEvent: _onSearchKeyEvent,
  );
  List<CanvasSearchResult> _searchResults = [];
  int _activeSearchIndex = 0;
  CanvasSearchCategory _searchCategory = CanvasSearchCategory.all;
  final Set<String> _selection = {};
  Map<String, CanvasObjectReference> _objects = {};
  _Tool _tool = _Tool.select;
  CanvasPoint? _start;
  CanvasPoint? _lastScreen;
  CanvasCamera? _startCamera;
  final Map<String, CanvasElement> _original = {};
  CanvasSnapIndex? _dragSnapIndex;
  CanvasBounds? _region;
  List<CanvasPoint>? _lassoPoints;
  CanvasElement? _preview;
  bool _inkPreviewDirty = false;
  final _liveInkChanges = ValueNotifier<int>(0);
  DateTime? _lastInkBroadcast;
  final List<Map<String, dynamic>> _ink = [];
  String? _editingId;
  int? _pointer;
  PointerDeviceKind? _pointerKind;
  double get _selectionHitRadius => _pointerKind == PointerDeviceKind.touch
      ? 20
      : _pointerKind == PointerDeviceKind.stylus ||
            _pointerKind == PointerDeviceKind.invertedStylus
      ? 14
      : 6;
  double get _handleHitRadius => _pointerKind == PointerDeviceKind.touch
      ? 25
      : _pointerKind == PointerDeviceKind.stylus ||
            _pointerKind == PointerDeviceKind.invertedStylus
      ? 18
      : 13;
  _Tool? _stylusToolBeforeOverride;
  bool _panning = false;
  bool _resizing = false;
  bool? _endpointStart;
  bool _spacePressed = false;
  bool _snap = false;
  bool _showMinimap = false;
  String _backgroundStyle = 'dots';
  final List<CanvasGuideLine> _activeGuides = [];
  String? _connectingStartId;
  String? _connectingEndId;
  String? _hoveredAnchorElementId;
  int _color = 0xff8b7cf6;
  String _penStyle = 'ballpoint';
  double _penStrokeWidth = 3.0;
  double _eraserRadius = 16.0;
  bool _fingerDraws = false;
  bool _rulerMode = false;
  bool _autoRecognizeInk = false;
  String? _lastAutoRecognizedId;
  DateTime? _lastAutoRecognizedTime;
  List<CanvasPoint>? _lastAutoRecognizedStroke;
  final Map<int, Offset> _touchPointers = {};
  double _touchPreviousDistance = 0;
  Offset _touchPreviousMidpoint = Offset.zero;
  bool _inMultiTouch = false;
  Size _viewport = Size.zero;
  Timer? _edgePanTimer;
  PointerMoveEvent? _edgePanEvent;
  bool _edgePanned = false;

  void _stopEdgePan() {
    _edgePanTimer?.cancel();
    _edgePanTimer = null;
    _edgePanEvent = null;
  }

  void _trackEdgePan(PointerMoveEvent event) {
    if (_tool != _Tool.select ||
        _original.isEmpty ||
        _resizing ||
        _endpointStart != null ||
        _panning ||
        _readOnly) {
      _stopEdgePan();
      return;
    }
    _edgePanEvent = event;
    _edgePanTimer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      final latest = _edgePanEvent;
      if (!mounted ||
          latest == null ||
          _pointer != latest.pointer ||
          _readOnly ||
          _inMultiTouch) {
        _stopEdgePan();
        return;
      }
      final x = edgeScrollStep(latest.localPosition.dx, _viewport.width);
      final y = edgeScrollStep(latest.localPosition.dy, _viewport.height);
      if (x == 0 && y == 0) {
        _stopEdgePan();
        return;
      }
      _edgePanned = true;
      _camera = _camera.pan(CanvasPoint(-x, -y));
      _move(latest);
    });
  }

  Map<String, dynamic>? _lastEmitted;
  List<String>? _lastPresenceSelection;
  void _publishPresenceSelection() {
    final selection = _selection.take(64).toList();
    if (listEquals(selection, _lastPresenceSelection)) return;
    _lastPresenceSelection = selection;
    widget.onPresenceSelection?.call(selection);
  }

  void _clearPresence() {
    _lastPresenceSelection = null;
    widget.onPresenceLeave?.call();
  }

  void _sendPresence(Offset local) {
    if (!(Offset.zero & _viewport).contains(local)) {
      _clearPresence();
      return;
    }
    final point = _world(local);
    widget.onPresence?.call(point.x, point.y);
    _publishPresenceSelection();
  }

  late Map<String, dynamic> _acceptedData = widget.draftBaseData ?? widget.data;
  Duration _strokeStart = Duration.zero;
  CanvasImageCache? _images;
  final CanvasTextCache _textCache = CanvasTextCache();
  // Retained world tiles provide engine-managed, device-density raster caching.
  // Do not enqueue one GPU readback/image and full-scene repaint per stroke.
  final CanvasInkCache _inkCache = CanvasInkCache();
  final CanvasLiveInkCache _liveInkCache = CanvasLiveInkCache();
  final CanvasPictureCache _minimapCache = CanvasPictureCache();
  String? _hoveredCardId;
  String? _hoveredConnectorId;
  Timer? _cardHoverTimer;
  bool _showCardTooltip = false;
  bool _isHoveringTooltip = false;

  void _dismissCardTooltip() {
    _cardHoverTimer?.cancel();
    _cardHoverTimer = null;
    if (_showCardTooltip || _hoveredCardId != null) {
      setState(() {
        _showCardTooltip = false;
        _hoveredCardId = null;
      });
    }
  }

  void _onCanvasHover(PointerHoverEvent event) {
    final perf = CanvasPerformance.instance;
    final started = perf.begin();
    try {
      _updateCanvasHover(event);
    } finally {
      perf.duration(CanvasPerfEvent.hover, _performanceSurface, started);
    }
  }

  void _updateCanvasHover(PointerHoverEvent event) {
    if (_panning || _pointer != null || _resizing || _editingId != null) {
      if (_hoveredConnectorId != null) {
        setState(() => _hoveredConnectorId = null);
      }
      _dismissCardTooltip();
      return;
    }
    final worldPos = _world(event.localPosition);
    final tolerance = 4 / _camera.zoom;
    // Hover feedback only targets cards/connectors. On an ink-only board there
    // is no reason to walk every pressure segment just to produce no tooltip.
    // If a target exists, keep the full hit test: overlaid ink still occludes it.
    final nearby = _scene.query(
      CanvasBounds(worldPos.x, worldPos.y, 0, 0).inflate(tolerance),
    );
    final hit = nearby.any((e) => e.type == 'card' || isConnectorElement(e))
        ? _scene.hit(worldPos, tolerance: tolerance)
        : null;
    final connector = hit != null && isConnectorElement(hit) ? hit.id : null;
    if (connector != _hoveredConnectorId) {
      setState(() => _hoveredConnectorId = connector);
    }
    if (hit != null && hit.type == 'card') {
      if (_hoveredCardId != hit.id) {
        _cardHoverTimer?.cancel();
        _hoveredCardId = hit.id;
        _cardHoverTimer = Timer(const Duration(milliseconds: 350), () {
          if (mounted && _hoveredCardId == hit.id && !_panning) {
            setState(() => _showCardTooltip = true);
          }
        });
      }
    } else if (!_isHoveringTooltip) {
      if (_hoveredCardId != null || _showCardTooltip) {
        _dismissCardTooltip();
      }
    }
  }

  void _toggleTask(String taskId) {
    if (_readOnly) return;
    if (widget.onToggleTask != null) {
      widget.onToggleTask!(taskId);
    } else {
      final obj = _objects[taskId];
      if (obj != null) {
        final isDone = obj.isCompleted;
        final updatedProps = {
          ...obj.properties,
          'completed': !isDone,
          'status': !isDone ? 'done' : 'open',
          'completedAt': !isDone ? DateTime.now().toIso8601String() : null,
        };
        final updated = CanvasObjectReference(
          id: obj.id,
          title: obj.title,
          typeId: obj.typeId,
          body: obj.body,
          properties: updatedProps,
        );
        setState(() {
          _objects[taskId] = updated;
        });
      }
    }
  }

  void _cycleCardPresentation(String elementId) {
    final elem = _scene[elementId];
    if (elem == null) return;
    const order = ['card', 'preview', 'transclusion', 'properties', 'compact'];
    final current = elem.data['presentation'] as String? ?? 'card';
    final nextIdx = (order.indexOf(current) + 1) % order.length;
    final next = order[nextIdx];
    _history.put(elem.copy({'presentation': next}));
    _commit();
    _notice('Card presentation: ${next.toUpperCase()}');
  }

  Future<void> _addDynamicView({CanvasPoint? at}) async {
    if (_readOnly) return;
    final selectedType = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Add Dynamic View (Smart View)'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'tasks'),
            child: Row(
              children: [
                Icon(
                  Icons.check_box_outlined,
                  color: OrbitColors.of(context).accent,
                ),
                SizedBox(width: 12),
                Text('Open Tasks View'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'notes'),
            child: Row(
              children: [
                Icon(
                  Icons.article_outlined,
                  color: OrbitColors.of(context).secondary,
                ),
                SizedBox(width: 12),
                Text('Recent Notes View'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'files'),
            child: Row(
              children: [
                Icon(Icons.attach_file, color: OrbitColors.of(context).warning),
                SizedBox(width: 12),
                Text('Attachments & Files View'),
              ],
            ),
          ),
        ],
      ),
    );
    if (selectedType == null || !mounted) return;
    final center =
        at ??
        _camera.toWorld(CanvasPoint(_viewport.width / 2, _viewport.height / 2));
    final element = CanvasElement({
      'id': _id(),
      'type': 'card',
      'x': center.x - 140,
      'y': center.y - 100,
      'width': 280.0,
      'height': 200.0,
      'color': _color,
      'presentation': 'preview',
      'viewConfig': {
        'type': selectedType,
        'status': 'open',
        'limit': 5,
        'title': selectedType == 'tasks'
            ? 'Open Tasks'
            : (selectedType == 'notes'
                  ? 'Recent Notes'
                  : 'Files & Attachments'),
      },
    });
    _history.put(element);
    _selection
      ..clear()
      ..add(element.id);
    _commit();
    _notice('Inserted Dynamic View card on Canvas');
  }

  CanvasScene get _scene => _history.scene;
  int _clipboardPasteRequest = 0;
  int _interactionEpoch = 0, _clipboardCopyRequest = 0;
  Set<String>? _gestureSelection;
  bool get _readOnly => widget.readOnly || _scene.readOnly;
  bool get _shift => HardwareKeyboard.instance.isShiftPressed;
  bool get _command =>
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed;
  String _id() => const Uuid().v4();
  CanvasPoint _point(Offset offset) => CanvasPoint(offset.dx, offset.dy);
  CanvasPoint _world(Offset offset) => _camera.toWorld(_point(offset));

  @override
  void initState() {
    super.initState();
    _acceptedData = widget.draftBaseData ?? widget.data;
    widget.captureController?._placements[this] = _prepareCapturedReferences;
    _scheduleLocation();
    _searchController.addListener(_onSearchQueryChanged);
    _titleController = TextEditingController(text: widget.title);
    _history = CanvasHistory(_makeScene(widget.data));
    _camera = CanvasCamera.fromJson(widget.camera);
    _backgroundStyle =
        widget.data['backgroundStyle'] as String? ??
        widget.defaultBackgroundStyle;
    if (_backgroundStyle == 'blueprint' ||
        _backgroundStyle == 'blueprint_classic') {
      _color = _technicalWhite;
      _penStrokeWidth = 1.5;
    }
    _snap = widget.data['snap'] as bool? ?? widget.defaultSnapToGrid;
    _restoreDrawingTools();
    _objects = {for (final object in widget.objects) object.id: object};
    final loader = widget.imageLoader;
    if (loader != null) {
      _images = CanvasImageCache(
        loader: loader,
        onChanged: () {
          CanvasPerformance.instance.event(
            CanvasPerfEvent.imageChange,
            _performanceSurface,
            {'decoded': _images?.images.length ?? 0},
          );
          if (mounted) setState(() {});
        },
      );
    }
    final preset = widget.data['canvasPreset'] as String?;
    if (_history.scene.elements.isEmpty &&
        preset != null &&
        widget.data['canvasPresetApplied'] != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _history.scene.elements.isNotEmpty) return;
        switch (preset) {
          case 'exercise':
            _applyExercisePreset();
          case 'study_board':
            _applyStudyBoardPreset();
          case 'course_map':
            _applyCourseMapPreset();
          case 'game_roadmap':
            _applyGameRoadmapPreset();
          case 'core_loop':
            _applyCoreLoopPreset();
          case 'level_design':
            _applyLevelDesignPreset();
          case 'ai_state_machine':
            _applyAiStateMachinePreset();
          case 'moodboard':
            _applyMoodboardPreset();
          case 'playtest_feedback':
            _applyPlaytestFeedbackPreset();
          case 'narrative_board':
            _applyNarrativeBoardPreset();
          case 'game_architecture':
            _applyGameArchitecturePreset();
          case 'call_flow':
            _applyCallFlowPreset();
          case 'object_relationships':
            _applyObjectRelationshipsPreset();
          case 'structure_layout':
            _applyStructureLayoutPreset();
          case 'binary_layout':
            _applyBinaryLayoutPreset();
          case 'protocol_flow':
            _applyProtocolFlowPreset();
          case 'process_tree':
            _applyProcessTreePreset();
          case 'rendering_pipeline':
            _applyRenderingPipelinePreset();
          default:
            final starter = CanvasStarters.byId(preset);
            if (starter != null && !_readOnly) _insertStarter(starter);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant CanvasEditor oldWidget) {
    final perf = CanvasPerformance.instance;
    final started = perf.begin();
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restoreViewSerial != widget.restoreViewSerial &&
        oldWidget.canvasId == widget.canvasId) {
      _cancelGesture();
      _camera = CanvasCamera.fromJson(widget.camera);
    }
    if (oldWidget.focusMode != widget.focusMode ||
        oldWidget.canvasId != widget.canvasId) {
      _focusControlsVisible = false;
    }
    if (oldWidget.canvasId != widget.canvasId ||
        oldWidget.readOnly != widget.readOnly) {
      _stopEdgePan();
      _edgePanned = false;
      _laserMode = false;
      _interactionEpoch++;
      _clipboardPasteRequest++;
    }
    final matchesExpected = widget.retainConflictingDraft
        ? false
        : (widget.draftBaseData != null
              ? _dataComparison.matches(
                  widget.data,
                  _lastEmitted ?? oldWidget.data,
                )
              : jsonValuesEqual(widget.data, _lastEmitted ?? oldWidget.data));
    final externalSceneChange =
        !widget.retainConflictingDraft &&
        !identical(widget.data, _lastEmitted) &&
        !matchesExpected;
    // Guarded editors retain a competing gesture until it can be published as
    // a recoverable draft. Unguarded editors must adopt the external revision.
    if ((widget.readOnly ||
            (externalSceneChange && widget.onDraftChanged == null)) &&
        (_pointer != null || _inMultiTouch)) {
      _rollbackGesture();
    }
    if (oldWidget.captureController != widget.captureController) {
      oldWidget.captureController?._placements.remove(this);
      widget.captureController?._placements[this] = _prepareCapturedReferences;
    }
    if (oldWidget.locationSerial != widget.locationSerial ||
        !listEquals(oldWidget.focusElementIds, widget.focusElementIds) ||
        oldWidget.canvasId != widget.canvasId) {
      _scheduleLocation();
    }
    _objects = {for (final object in widget.objects) object.id: object};
    if (oldWidget.imageRevision != widget.imageRevision) {
      _images?.invalidateAll();
    }
    if (widget.data['backgroundStyle'] is String &&
        widget.data['backgroundStyle'] != _backgroundStyle) {
      _backgroundStyle = widget.data['backgroundStyle'] as String;
      if (_backgroundStyle == 'blueprint' ||
          _backgroundStyle == 'blueprint_classic') {
        _color = _technicalWhite;
        _penStyle = 'ballpoint';
        _penStrokeWidth = 1.5;
      }
    }
    if (oldWidget.canvasId != widget.canvasId) {
      _performanceRevision = null;
      _hoveredConnectorId = null;
      _inkCache.clear();
      _history = CanvasHistory(_makeScene(widget.data));
      _camera = CanvasCamera.fromJson(widget.camera);
      _backgroundStyle =
          widget.data['backgroundStyle'] as String? ??
          widget.defaultBackgroundStyle;
      _snap = widget.data['snap'] as bool? ?? widget.defaultSnapToGrid;
      _restoreDrawingTools();
      _selection.clear();
      _editingId = null;
      _clearGesture();
      _lastEmitted = null;
      _acceptedData = widget.draftBaseData ?? widget.data;
      _titleController.text = widget.title;
    } else if (oldWidget.title != widget.title && !_titleFocus.hasFocus) {
      _titleController.text = widget.title;
    }
    if (oldWidget.canvasId == widget.canvasId &&
        !widget.retainConflictingDraft &&
        (oldWidget.retainConflictingDraft ||
            !identical(oldWidget.data, widget.data)) &&
        !identical(widget.data, _lastEmitted) &&
        !matchesExpected &&
        !_history.inCommand) {
      // A genuine external revision replaces the scene; stale undo must not overwrite it.
      _history = CanvasHistory(_makeScene(widget.data));
      _lastEmitted = null;
      _dataComparison.clear();
      _selection.removeWhere((id) => _scene[id] == null);
    }
    if (!widget.retainConflictingDraft && !_history.inCommand) {
      _acceptedData = widget.draftBaseData ?? widget.data;
    }
    perf.duration(CanvasPerfEvent.editorUpdate, _performanceSurface, started, {
      'dataIdentityChanged': identical(oldWidget.data, widget.data) ? 0 : 1,
      'externalSceneChange': externalSceneChange ? 1 : 0,
    });
  }

  @override
  void dispose() {
    CanvasPerformance.instance.detach(_performanceSurface);
    _stopEdgePan();
    _requestedRoutingScene = null;
    _clearPresence();
    widget.captureController?._placements.remove(this);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _cardHoverTimer?.cancel();
    _titleController.dispose();
    _titleFocus.dispose();
    _images?.dispose();
    _textCache.dispose();
    _inkCache.dispose();
    _liveInkCache.dispose();
    _liveInkChanges.dispose();
    _minimapCache.dispose();
    _focus.dispose();
    _text.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  void _scheduleLocation() {
    if (widget.focusElementId == null && widget.focusElementIds.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialRoutingLoading) return;
      final ids = {
        ...widget.focusElementIds,
        if (widget.focusElementId != null) widget.focusElementId!,
      };
      final elements = ids
          .map((id) => _scene[id])
          .whereType<CanvasElement>()
          .where((e) => !e.hidden && e.renderable)
          .toList();
      if (elements.isEmpty) {
        _notice('Canvas element is missing or hidden. The board is open.');
        return;
      }
      final bounds = elements
          .skip(1)
          .fold(elements.first.bounds, (bounds, e) => bounds.union(e.bounds));
      final zoom = math
          .min(
            (_viewport.width - 96) / math.max(1, bounds.width),
            (_viewport.height - 96) / math.max(1, bounds.height),
          )
          .clamp(.1, 1.25);
      setState(() {
        _camera = CanvasCamera(
          x: bounds.center.x - _viewport.width / zoom / 2,
          y: bounds.center.y - _viewport.height / zoom / 2,
          zoom: zoom,
        );
        _selection
          ..clear()
          ..addAll(elements.map((e) => e.id));
      });
      _cameraChanged();
    });
  }

  void _emit() {
    final perf = CanvasPerformance.instance;
    final started = perf.begin();
    try {
      _publishPresenceSelection();
      if (_readOnly) return;
      final snapshotStarted = perf.begin();
      final data = {
        ..._scene.snapshotJson(),
        if (widget.data['canvasPreset'] != null) 'canvasPresetApplied': true,
        'backgroundStyle': _backgroundStyle,
      };
      perf.duration(
        CanvasPerfEvent.sceneSnapshot,
        _performanceSurface,
        snapshotStarted,
      );
      _lastEmitted = data;
      final guarded = widget.onDraftChanged;
      if (guarded == null) {
        widget.onChanged(data);
      } else if (guarded(_acceptedData, data)) {
        _acceptedData = data;
      }
    } finally {
      perf.duration(CanvasPerfEvent.save, _performanceSurface, started);
    }
  }

  /// Applies the drafting defaults without touching existing scene elements.
  /// The color and stroke are intentionally tool defaults: changing paper
  /// should never recolor a user's completed drawing.
  void _applyArchitecturalBlueprintPreset({String style = 'blueprint'}) {
    if (_readOnly) return;
    setState(() {
      _backgroundStyle = style;
      _color = _technicalWhite;
      _penStyle = 'ballpoint';
      _penStrokeWidth = 1.5;
      _tool = _Tool.pen;
    });
    _emit();
    _notice('Architectural blueprint preset applied · white technical pen');
  }

  void _commit() {
    if (_history.commit()) _emit();
    if (mounted) setState(() {});
  }

  void _cameraChanged() {
    _dismissCardTooltip();
    widget.onCameraChanged?.call({
      ..._camera.toJson(),
      'drawingTools': {
        'tool': _tool.name,
        'color': _color,
        'penStyle': _penStyle,
        'penWidth': _penStrokeWidth,
        'eraserRadius': _eraserRadius,
      },
    });
  }

  void _restoreDrawingTools() {
    final value = widget.camera?['drawingTools'];
    _tool = _Tool.select;
    _penStyle = 'ballpoint';
    _penStrokeWidth = 3;
    _eraserRadius = 16;
    _color =
        (_backgroundStyle == 'blueprint' ||
            _backgroundStyle == 'blueprint_classic')
        ? _technicalWhite
        : 0xff8b7cf6;
    if (_color == _technicalWhite) {
      _penStrokeWidth = 1.5;
    }
    if (value is! Map) return;
    for (final tool in _Tool.values) {
      if (tool.name == value['tool']) _tool = tool;
    }
    final color = value['color'];
    if (color is int && color >= 0 && color <= 0xffffffff) _color = color;
    if (const {
      'ballpoint',
      'fountain',
      'marker',
      'pencil',
      'calligraphy',
      'brush',
    }.contains(value['penStyle'])) {
      _penStyle = value['penStyle'] as String;
    }
    final width = value['penWidth'], radius = value['eraserRadius'];
    if (width is num && width.isFinite) {
      _penStrokeWidth = width.toDouble().clamp(.5, 32);
    }
    if (radius is num && radius.isFinite) {
      _eraserRadius = radius.toDouble().clamp(1, 128);
    }
  }

  void _setTool(_Tool tool) {
    _dismissCardTooltip();
    _finishText();
    _cancelGesture();
    setState(() {
      _tool = tool;
    });
    _cameraChanged();
    _focus.requestFocus();
  }

  void _down(PointerDownEvent event) {
    if (!widget.interactionActive && widget.onActivate != null) {
      widget.onActivate!();
      _focus.requestFocus();
      return;
    }
    if (_laserMode) return;
    // A palm often lands before the pen. Let the pen take capture from touch,
    // rolling back the provisional touch gesture rather than losing the stroke.
    if ((event.kind == PointerDeviceKind.stylus ||
            event.kind == PointerDeviceKind.invertedStylus) &&
        (_pointerKind == PointerDeviceKind.touch || _inMultiTouch)) {
      _rollbackGesture(restoreCamera: false);
    }
    // A palm may generate multiple touch contacts while a pen is captured.
    // They must not promote to a pinch and roll back the pen transaction.
    if (event.kind == PointerDeviceKind.touch &&
        (_pointerKind == PointerDeviceKind.stylus ||
            _pointerKind == PointerDeviceKind.invertedStylus)) {
      return;
    }
    if (event.kind == PointerDeviceKind.touch) {
      _touchPointers[event.pointer] = event.localPosition;
      if (_touchPointers.length >= 2) {
        final touches = Map<int, Offset>.of(_touchPointers);
        _rollbackGesture(restoreCamera: false);
        _startCamera = _camera;
        _touchPointers.addAll(touches);
        _inMultiTouch = true;
        if (_ink.isNotEmpty) {
          _preview = null;
          _ink.clear();
        }
        _region = null;
        _panning = false;
        final pts = _touchPointers.values.toList();
        _touchPreviousDistance = (pts[0] - pts[1]).distance;
        _touchPreviousMidpoint = (pts[0] + pts[1]) / 2;
        setState(() {});
        return;
      }
    }
    if (_inMultiTouch) return;
    if (_pointer != null) return;
    _dismissCardTooltip();
    _finishText();
    _focus.requestFocus();
    if (event.buttons == kSecondaryMouseButton &&
        event.kind != PointerDeviceKind.stylus) {
      _contextMenu(event);
      return;
    }
    _pointer = event.pointer;
    _pointerKind = event.kind;
    _gestureSelection = {..._selection};
    _start = _world(event.localPosition);
    _lastScreen = _point(event.localPosition);
    _startCamera = _camera;
    if (event.kind == PointerDeviceKind.invertedStylus ||
        (event.kind == PointerDeviceKind.stylus &&
            event.buttons == kSecondaryMouseButton)) {
      _stylusToolBeforeOverride = _tool;
      _tool = _Tool.eraser;
    } else if (event.kind == PointerDeviceKind.stylus &&
        _tool == _Tool.select) {
      // This is already the new pointer transaction. _setTool cancels capture,
      // so using it here would silently drop the first pen stroke.
      _tool = _Tool.pen;
    }
    _panning =
        _readOnly ||
        (!_fingerDraws &&
            event.kind == PointerDeviceKind.touch &&
            (_tool == _Tool.pen ||
                _tool == _Tool.highlighter ||
                _tool == _Tool.eraser)) ||
        _tool == _Tool.pan ||
        _spacePressed ||
        event.buttons == kMiddleMouseButton;
    if (_panning) return;
    if (_readOnly) {
      _clearGesture();
      return;
    }
    _history.begin();
    if (_tool == _Tool.select) {
      final single = _selection.length == 1 ? _scene[_selection.first] : null;
      final endpoints = single != null && isConnectorElement(single)
          ? resolveConnectorEndpoints(single, _scene)
          : null;
      if (single != null &&
          !single.locked &&
          endpoints != null &&
          ((_start! - endpoints.start).length <
                  _handleHitRadius / _camera.zoom ||
              (_start! - endpoints.end).length <
                  _handleHitRadius / _camera.zoom)) {
        _endpointStart =
            (_start! - endpoints.start).length <=
            (_start! - endpoints.end).length;
        _resizing = true;
        _original[single.id] = single;
      } else if (single != null &&
          !single.locked &&
          single.type != 'ink' &&
          !isConnectorElement(single) &&
          (_start! -
                      CanvasPoint(
                        single.bounds.right + 4 / _camera.zoom,
                        single.bounds.bottom + 4 / _camera.zoom,
                      ))
                  .length <
              _handleHitRadius / _camera.zoom) {
        _resizing = true;
        _original[single.id] = single;
      } else {
        final hit = _scene.hit(
          _start!,
          tolerance: _selectionHitRadius / _camera.zoom,
          includeLocked: true,
        );
        if (hit != null) {
          if (_shift && _selection.contains(hit.id)) {
            _selection.remove(hit.id);
            if (hit.groupId != null) {
              for (final m in getGroupMembers(_scene, hit.groupId!)) {
                _selection.remove(m.id);
              }
            }
          } else {
            if (!_shift && !_selection.contains(hit.id)) _selection.clear();
            _selection.add(hit.id);
            if (hit.groupId != null && !_shift) {
              for (final m in getGroupMembers(_scene, hit.groupId!)) {
                _selection.add(m.id);
              }
            }
          }
          for (final id in _selection) {
            if (_scene[id] != null && !_scene[id]!.locked) {
              _original[id] = _scene[id]!;
            }
          }
          for (final id in _selection) {
            if (_scene[id]?.type == 'column') {
              final members = columnMembers(_scene, id);
              if (members.any((e) => e.locked)) {
                _original.clear();
                _notice('Unlock the column’s items before moving it.');
                break;
              }
              for (final member in members) {
                _original[member.id] = member;
              }
            }
          }
          final checkedGroupIds = <String>{};
          for (final id in _selection) {
            final elem = _scene[id];
            if (elem?.groupId != null && checkedGroupIds.add(elem!.groupId!)) {
              if (isGroupLocked(_scene, elem.groupId!)) {
                _original.clear();
                _notice('Unlock the group’s items before moving it.');
                break;
              }
              final members = getGroupMembers(_scene, elem.groupId!);
              for (final member in members) {
                if (!member.locked) {
                  _original[member.id] = member;
                }
              }
            }
          }
        } else {
          if (!_shift) _selection.clear();
          _region = CanvasBounds(_start!.x, _start!.y, 0, 0);
        }
      }
    } else if (_tool == _Tool.lasso) {
      if (!_shift) _selection.clear();
      _lassoPoints = [_start!];
    } else if (_tool == _Tool.pen || _tool == _Tool.highlighter) {
      _strokeStart = event.timeStamp;
      _sample(event.localPosition, event.pressure, event.timeStamp);
    } else if (_tool == _Tool.eraser) {
      _erase(_start!);
    } else if (_tool == _Tool.text || _tool == _Tool.sticky) {
      final element = CanvasElement({
        'id': _id(),
        'type': _tool.name,
        'x': _start!.x,
        'y': _start!.y,
        'width': 220.0,
        'height': _tool == _Tool.text ? 100.0 : 180.0,
        'color': _color,
        'text': _tool == _Tool.text ? 'Text' : 'An idea…',
      });
      _history.put(element);
      _commit();
      _clearGesture();
      setState(() {
        _selection
          ..clear()
          ..add(element.id);
        _tool = _Tool.select;
      });
      _edit(element);
    } else if (_tool == _Tool.arrow || _tool == _Tool.line) {
      final hit = _scene.hit(
        _start!,
        tolerance: 16 / _camera.zoom,
        includeLocked: true,
      );
      if (hit != null && hit.type != 'column') {
        _connectingStartId = hit.id;
        _hoveredAnchorElementId = hit.id;
        final anchor = findClosestAnchor(hit.bounds, _start!);
        final anchorPt = getElementAnchors(hit.bounds)[anchor];
        if (anchorPt != null) _start = anchorPt;
      } else {
        _connectingStartId = null;
        _hoveredAnchorElementId = null;
      }
      _connectingEndId = null;
    }
    setState(() {});
  }

  void _move(PointerMoveEvent event) {
    if (_laserMode) return;
    if (event.kind == PointerDeviceKind.touch &&
        _touchPointers.containsKey(event.pointer)) {
      _touchPointers[event.pointer] = event.localPosition;
      if (_inMultiTouch && _touchPointers.length >= 2) {
        final pts = _touchPointers.values.toList();
        final currentDist = (pts[0] - pts[1]).distance;
        final currentMid = (pts[0] + pts[1]) / 2;
        if (_touchPreviousDistance > 1.0 && currentDist > 1.0) {
          final scaleChange = currentDist / _touchPreviousDistance;
          final panDelta = currentMid - _touchPreviousMidpoint;
          setState(() {
            _camera = _camera
                .pan(CanvasPoint(panDelta.dx, panDelta.dy))
                .zoomAt(_point(currentMid), scaleChange.clamp(0.85, 1.15));
          });
        }
        _touchPreviousDistance = currentDist;
        _touchPreviousMidpoint = currentMid;
        return;
      }
    }
    if (_inMultiTouch) return;
    if (event.pointer != _pointer) return;
    _trackEdgePan(event);
    final point = _world(event.localPosition);
    if (_panning) {
      setState(() {
        _camera = _camera.pan(_point(event.localPosition) - _lastScreen!);
      });
      _lastScreen = _point(event.localPosition);
      return;
    }
    if (_start == null) return;
    if (_tool == _Tool.select) {
      if (_original.isNotEmpty && _endpointStart == null) {
        _scene.beginInteractiveRouting();
      }
      if (_endpointStart != null && _original.isNotEmpty) {
        final original = _original.values.first;
        final endpoints = resolveConnectorEndpoints(original, _scene);
        final hit = _scene.hit(
          point,
          tolerance: 12 / _camera.zoom,
          includeLocked: true,
        );
        final anchorTarget =
            hit != null && hit.id != original.id && !isConnectorElement(hit)
            ? hit
            : null;
        final anchor = anchorTarget == null
            ? ConnectorAnchor.auto
            : findClosestAnchor(anchorTarget.bounds, point);
        final moved = anchorTarget == null
            ? point
            : getElementAnchors(anchorTarget.bounds)[anchor]!;
        _history.put(
          original.copy({
            ...connectorEndpointData(
              _endpointStart! ? moved : endpoints.start,
              _endpointStart! ? endpoints.end : moved,
            ),
            _endpointStart! ? 'startId' : 'endId': anchorTarget?.id,
            _endpointStart! ? 'startAnchor' : 'endAnchor': anchor.label,
          }),
        );
      } else if (_region != null) {
        _region = CanvasBounds.between(_start!, point);
      } else if (_resizing && _original.isNotEmpty) {
        final original = _original.values.first;
        var width = math.max(40.0, original.width + point.x - _start!.x);
        var height = math.max(
          original.type == 'section' ? 24.0 : 40.0,
          original.height + point.y - _start!.y,
        );
        if (_shift || original.type == 'image') {
          height = width * original.height / math.max(1, original.width);
        }
        if (_snap) {
          width = (width / 24).round() * 24.0;
          height = (height / 24).round() * 24.0;
        }
        if (original.type == 'section') {
          final computedFs = (height * (13.0 / 40.0)).clamp(11.0, 72.0);
          final strokeW = (computedFs * 0.12).clamp(1.5, 8.0);
          _history.put(
            original.copy({
              'width': width,
              'height': height,
              'fontSize': computedFs,
              'strokeWidth': strokeW,
            }),
          );
        } else {
          _history.put(original.copy({'width': width, 'height': height}));
        }
      } else {
        var delta = point - _start!;
        if (_snap && !HardwareKeyboard.instance.isAltPressed) {
          delta = CanvasPoint(
            (delta.x / 24).round() * 24,
            (delta.y / 24).round() * 24,
          );
        }
        _activeGuides.clear();
        if (!HardwareKeyboard.instance.isAltPressed && _original.isNotEmpty) {
          CanvasBounds movingBounds = _original.values.first.bounds;
          for (final orig in _original.values.skip(1)) {
            movingBounds = movingBounds.union(orig.bounds);
          }
          final currentBounds = CanvasBounds(
            movingBounds.left + delta.x,
            movingBounds.top + delta.y,
            movingBounds.width,
            movingBounds.height,
          );
          final threshold = 6.0 / _camera.zoom;
          final index = _dragSnapIndex ??= CanvasSnapIndex([
            for (final e in _scene.elements)
              if (e.renderable && !_original.containsKey(e.id))
                CanvasSnapTarget(
                  e.id,
                  e.bounds,
                  spacing: !isConnectorElement(e),
                  dynamic:
                      isConnectorElement(e) &&
                      (_original.containsKey(e.startId) ||
                          _original.containsKey(e.endId)),
                ),
          ]);
          final live = {
            for (final id in index.dynamicIds)
              if (_scene[id] != null) id: _scene[id]!.bounds,
          };
          final horizontal = index.alignment(
            currentBounds,
            vertical: false,
            tolerance: threshold,
            live: live,
          );
          final verticalSnap = index.alignment(
            currentBounds,
            vertical: true,
            tolerance: threshold,
            live: live,
          );
          final snapDx = horizontal?.delta, snapGuideX = horizontal?.position;
          final snapDy = verticalSnap?.delta,
              snapGuideY = verticalSnap?.position;

          if (snapDx != null) {
            delta = CanvasPoint(delta.x + snapDx, delta.y);
            _activeGuides.add(
              CanvasGuideLine(isVertical: true, position: snapGuideX!),
            );
          }
          if (snapDy != null) {
            delta = CanvasPoint(delta.x, delta.y + snapDy);
            _activeGuides.add(
              CanvasGuideLine(isVertical: false, position: snapGuideY!),
            );
          }
          for (final vertical in [false, true]) {
            if (vertical ? snapDy != null : snapDx != null) continue;
            final moved = CanvasBounds(
              movingBounds.left + delta.x,
              movingBounds.top + delta.y,
              movingBounds.width,
              movingBounds.height,
            );
            final spacing = index.spacing(
              moved,
              vertical: vertical,
              tolerance: threshold,
              live: live,
            );
            if (spacing == null) continue;
            delta = vertical
                ? CanvasPoint(delta.x, delta.y + spacing.delta)
                : CanvasPoint(delta.x + spacing.delta, delta.y);
            final label = spacing.gap.toStringAsFixed(
              spacing.gap == spacing.gap.roundToDouble() ? 0 : 1,
            );
            final start = vertical
                ? moved.top + spacing.delta
                : moved.left + spacing.delta;
            final end = vertical
                ? moved.bottom + spacing.delta
                : moved.right + spacing.delta;
            _activeGuides.addAll([
              CanvasGuideLine(
                isVertical: vertical,
                position: spacing.position,
                from: spacing.before,
                to: start,
                label: label,
              ),
              CanvasGuideLine(
                isVertical: vertical,
                position: spacing.position,
                from: end,
                to: spacing.after,
                label: label,
              ),
            ]);
          }
        }
        _scene.batch(() {
          for (final original in _original.values) {
            if ((original.type == 'connector' ||
                    original.type == 'arrow' ||
                    original.type == 'line') &&
                (original.startId != null || original.endId != null) &&
                !_original.containsKey(original.startId) &&
                !_original.containsKey(original.endId)) {
              continue;
            }
            _history.put(original.translated(delta));
          }
          for (final conn in _scene.elements) {
            if (conn.type == 'connector' ||
                conn.type == 'arrow' ||
                conn.type == 'line') {
              final startMoving =
                  conn.startId != null && _original.containsKey(conn.startId);
              final endMoving =
                  conn.endId != null && _original.containsKey(conn.endId);
              if (startMoving || endMoving) {
                final endpoints = resolveConnectorEndpoints(conn, _scene);
                _history.put(
                  conn.copy(
                    connectorEndpointData(endpoints.start, endpoints.end),
                  ),
                );
              }
            }
          }
        });
      }
    } else if (_tool == _Tool.lasso) {
      if (_lassoPoints != null &&
          (_lassoPoints!.last - point).length >= 3.0 / _camera.zoom) {
        _lassoPoints!.add(point);
      }
    } else if (_tool == _Tool.pen || _tool == _Tool.highlighter) {
      _sample(event.localPosition, event.pressure, event.timeStamp);
      _liveInkChanges.value++;
      return;
    } else if (_tool == _Tool.eraser) {
      _erase(point);
    } else {
      var currentPoint = point;
      if (_tool == _Tool.arrow || _tool == _Tool.line) {
        final hit = _scene.hit(
          point,
          tolerance: 16 / _camera.zoom,
          includeLocked: true,
        );
        if (hit != null &&
            hit.id != _connectingStartId &&
            hit.type != 'column') {
          _connectingEndId = hit.id;
          _hoveredAnchorElementId = hit.id;
          final anchor = findClosestAnchor(hit.bounds, point);
          final anchorPt = getElementAnchors(hit.bounds)[anchor];
          if (anchorPt != null) currentPoint = anchorPt;
        } else {
          _connectingEndId = null;
          _hoveredAnchorElementId = _connectingStartId;
        }
      }
      final bounds = CanvasBounds.between(_start!, currentPoint);
      final isConnector =
          _connectingStartId != null || _connectingEndId != null;
      _preview = CanvasElement({
        'id': 'preview',
        'type': isConnector ? 'connector' : _tool.name,
        'x': bounds.left,
        'y': bounds.top,
        'width': bounds.width,
        'height': bounds.height,
        'color': _color,
        'strokeWidth': 2.0,
        'reverseX': currentPoint.x < _start!.x,
        'reverseY': currentPoint.y < _start!.y,
        if (_connectingStartId != null) 'startId': _connectingStartId,
        if (_connectingEndId != null) 'endId': _connectingEndId,
        'startAnchor': 'auto',
        'endAnchor': 'auto',
        if (_tool == _Tool.arrow || _tool == _Tool.line)
          ...connectorEndpointData(_start!, currentPoint),
      });
    }
    setState(() {});
  }

  void _sample(
    Offset offset,
    double pressure,
    Duration time, {
    bool force = false,
  }) {
    final point = _world(offset);
    final isStraight = _shift || _rulerMode;
    if (isStraight) {
      if (_ink.isEmpty) {
        _ink.add({
          'x': point.x,
          'y': point.y,
          'pressure': pressure.isFinite ? pressure.clamp(0, 1) : 1.0,
          'timeMs': 0,
        });
      } else {
        if (_ink.length > 1) {
          _ink.removeRange(1, _ink.length);
        }
        _ink.add({
          'x': point.x,
          'y': point.y,
          'pressure': pressure.isFinite ? pressure.clamp(0, 1) : 1.0,
          'timeMs': (time - _strokeStart).inMilliseconds,
        });
      }
    } else {
      if (_ink.isNotEmpty && !force) {
        final last = _ink.last;
        if ((CanvasPoint(last['x'] as double, last['y'] as double) - point)
                    .length <
                .7 / _camera.zoom &&
            pressure.isFinite &&
            ((last['pressure'] as num).toDouble() - pressure.clamp(0, 1))
                    .abs() <
                .01) {
          return;
        }
      }
      _ink.add({
        'x': point.x,
        'y': point.y,
        'pressure': pressure.isFinite ? pressure.clamp(0, 1) : 1.0,
        'timeMs': (time - _strokeStart).inMilliseconds,
      });
    }
    _inkPreviewDirty = true;
    if (widget.onInkPreview != null &&
        (_lastInkBroadcast == null ||
            DateTime.now().difference(_lastInkBroadcast!) >=
                const Duration(milliseconds: 80))) {
      _lastInkBroadcast = DateTime.now();
      // Sample only the ephemeral preview. Full pressure/time samples are saved
      // unchanged through the normal Canvas command on pointer-up.
      final count = _ink.length.clamp(1, 128);
      widget.onInkPreview!({
        'points': [
          for (var i = 0; i < count; i++)
            _ink[count == 1
                ? 0
                : (i * (_ink.length - 1) / (count - 1)).round()],
        ],
        'color': _color,
        'strokeWidth': _tool == _Tool.highlighter ? 22.0 : _penStrokeWidth,
        'penStyle': _tool == _Tool.highlighter ? 'highlighter' : _penStyle,
        'isHighlighter': _tool == _Tool.highlighter,
      });
    }
  }

  CanvasElement? get _framePreview {
    if (!_inkPreviewDirty) return _preview;
    final perf = CanvasPerformance.instance;
    final started = perf.begin();
    _inkPreviewDirty = false;
    if (_ink.isEmpty) return _preview;
    final isHighlighter = _tool == _Tool.highlighter;
    final strokeWidth = isHighlighter ? 22.0 : _penStrokeWidth;
    final penStyle = isHighlighter ? 'highlighter' : _penStyle;
    _preview = CanvasElement({
      'id': 'preview',
      'type': 'ink',
      'x': 0.0,
      'y': 0.0,
      'width': 0.0,
      'height': 0.0,
      // This preview is local and ephemeral, never a history/persistence value.
      // Cache preparation reads only appended samples. Copying the full growing
      // stroke here allocated O(n) on every frame, increasing GC pressure.
      'points': UnmodifiableListView(_ink),
      'color': _color,
      'strokeWidth': strokeWidth,
      'penStyle': penStyle,
      'isHighlighter': isHighlighter,
    });
    perf.duration(CanvasPerfEvent.previewBuild, _performanceSurface, started, {
      'samples': _ink.length,
    });
    return _preview;
  }

  void _erase(CanvasPoint point) {
    final radius = _eraserRadius / _camera.zoom;
    for (final element in _scene.query(
      CanvasBounds(point.x, point.y, 0, 0).inflate(radius),
    )) {
      if (element.type == 'ink' &&
          !element.locked &&
          element.hit(
            point,
            tolerance:
                (element.data['isHighlighter'] == true ? 22.0 : radius) /
                _camera.zoom,
          )) {
        _history.remove(element.id);
      }
    }
  }

  void _up(PointerUpEvent event) {
    if (_laserMode) return;
    if (event.kind == PointerDeviceKind.touch) {
      _touchPointers.remove(event.pointer);
      if (_inMultiTouch) {
        if (_touchPointers.length < 2) {
          _inMultiTouch = false;
          _pointer = null;
          _pointerKind = null;
          _start = null;
          _lastScreen = null;
          _panning = false;
          _cameraChanged();
        }
        return;
      }
    }
    if (event.pointer != _pointer) return;
    final point = _world(event.localPosition);
    final isTap = _start != null && (point - _start!).length < 4 / _camera.zoom;
    if (_panning) {
      _cameraChanged();
    } else if (_region != null) {
      for (final element in _scene.query(_region!)) {
        if (!element.locked) _selection.add(element.id);
      }
    } else if (_tool == _Tool.lasso &&
        _lassoPoints != null &&
        _lassoPoints!.length >= 3) {
      final polygon = List<CanvasPoint>.from(_lassoPoints!);
      if ((polygon.first - polygon.last).length > 1.0) {
        polygon.add(polygon.first);
      }
      var minX = polygon.first.x;
      var maxX = polygon.first.x;
      var minY = polygon.first.y;
      var maxY = polygon.first.y;
      for (final p in polygon) {
        if (p.x < minX) minX = p.x;
        if (p.x > maxX) maxX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.y > maxY) maxY = p.y;
      }
      final polyBounds = CanvasBounds(minX, minY, maxX - minX, maxY - minY);
      final candidateElements = _scene.query(polyBounds);
      for (final el in candidateElements) {
        if (el.locked || !el.renderable || el.hidden) continue;
        if (el.type == 'ink') {
          var enclosed = false;
          for (final pt in el.points) {
            final worldPt = CanvasPoint(el.x + pt.x, el.y + pt.y);
            if (isPointInPolygon(worldPt, polygon)) {
              enclosed = true;
              break;
            }
          }
          if (enclosed) _selection.add(el.id);
        } else if (el.type == 'connector' ||
            el.type == 'arrow' ||
            el.type == 'line') {
          final endpoints = resolveConnectorEndpoints(el, _scene);
          if (isPointInPolygon(endpoints.start, polygon) ||
              isPointInPolygon(endpoints.end, polygon) ||
              isPointInPolygon(endpoints.midpoint, polygon)) {
            _selection.add(el.id);
          }
        } else {
          final b = el.bounds;
          if (isPointInPolygon(b.center, polygon) ||
              isPointInPolygon(CanvasPoint(b.left, b.top), polygon) ||
              isPointInPolygon(CanvasPoint(b.right, b.top), polygon) ||
              isPointInPolygon(CanvasPoint(b.left, b.bottom), polygon) ||
              isPointInPolygon(CanvasPoint(b.right, b.bottom), polygon)) {
            _selection.add(el.id);
          }
        }
      }
    } else if ((_tool == _Tool.pen || _tool == _Tool.highlighter) &&
        _ink.isNotEmpty) {
      // Pointer-up may contain the only final position. Release pressure is
      // commonly zero, so retain the last measured pressure for this endpoint.
      final last = _ink.last;
      if (last['x'] != point.x || last['y'] != point.y) {
        _sample(
          event.localPosition,
          (last['pressure'] as num).toDouble(),
          event.timeStamp,
          force: true,
        );
      }
      final isHighlighter = _tool == _Tool.highlighter;
      final strokeWidth = isHighlighter ? 22.0 : _penStrokeWidth;
      final penStyle = isHighlighter ? 'highlighter' : _penStyle;
      var minX = double.infinity, minY = double.infinity;
      var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
      for (final sample in _ink) {
        final x = sample['x'] as double, y = sample['y'] as double;
        minX = math.min(minX, x);
        minY = math.min(minY, y);
        maxX = math.max(maxX, x);
        maxY = math.max(maxY, y);
      }
      final rawInkElement = CanvasElement(
        immutableObjectData({
          'id': _id(),
          'type': 'ink',
          'x': minX,
          'y': minY,
          'width': math.max(1.0, maxX - minX),
          'height': math.max(1.0, maxY - minY),
          'color': _color,
          'strokeWidth': strokeWidth,
          'penStyle': penStyle,
          'isHighlighter': isHighlighter,
          'points': _ink
              .map(
                (p) => {
                  ...p,
                  'x': (p['x'] as double) - minX,
                  'y': (p['y'] as double) - minY,
                },
              )
              .toList(),
        }),
      );

      if (_autoRecognizeInk && !isHighlighter) {
        final currentStrokePoints = _ink
            .map((p) => CanvasPoint(p['x'] as double, p['y'] as double))
            .toList();

        var multiStrokeHandled = false;
        if (_lastAutoRecognizedId != null &&
            _lastAutoRecognizedTime != null &&
            _lastAutoRecognizedStroke != null &&
            DateTime.now().difference(_lastAutoRecognizedTime!).inMilliseconds <
                850) {
          final prevElem = _scene[_lastAutoRecognizedId!];
          if (prevElem != null) {
            final prevBounds = prevElem.bounds;
            final currBounds = rawInkElement.bounds;
            final maxGap = math.max(prevBounds.width, prevBounds.height) * 1.5;
            if ((currBounds.center - prevBounds.center).length <
                maxGap + 40.0) {
              final combinedBounds = prevBounds.union(currBounds);
              final combinedChar = globalCharacterRecognizer.recognize(
                [_lastAutoRecognizedStroke!, currentStrokePoints],
                bounds: combinedBounds,
                minConfidence: 0.65,
              );
              if (combinedChar != null) {
                _history.remove(_lastAutoRecognizedId!);
                final combinedElem = CanvasElement({
                  'id': _id(),
                  'type': 'text',
                  'x': combinedBounds.left,
                  'y': combinedBounds.top,
                  'width': math.max(40.0, combinedBounds.width),
                  'height': math.max(40.0, combinedBounds.height),
                  'color': _color,
                  'text': combinedChar.char,
                });
                _history.put(combinedElem);
                _selection
                  ..clear()
                  ..add(combinedElem.id);
                _lastAutoRecognizedId = combinedElem.id;
                _lastAutoRecognizedTime = DateTime.now();
                _lastAutoRecognizedStroke = [
                  ..._lastAutoRecognizedStroke!,
                  ...currentStrokePoints,
                ];
                multiStrokeHandled = true;
              }
            }
          }
        }

        if (!multiStrokeHandled) {
          final gesture = recognizeInkGesture(rawInkElement);
          if (gesture != null && gesture.confidence >= 0.65) {
            final converted = convertInkGesture(rawInkElement, gesture);
            if (converted != null) {
              _history.put(converted);
              _selection
                ..clear()
                ..add(converted.id);
              if (gesture.isCharacter) {
                _lastAutoRecognizedId = converted.id;
                _lastAutoRecognizedTime = DateTime.now();
                _lastAutoRecognizedStroke = currentStrokePoints;
              } else {
                _lastAutoRecognizedId = null;
                _lastAutoRecognizedTime = null;
                _lastAutoRecognizedStroke = null;
              }
              _clearGesture();
              _commit();
              return;
            }
          }
        } else {
          _clearGesture();
          _commit();
          return;
        }
      }

      _lastAutoRecognizedId = null;
      _lastAutoRecognizedTime = null;
      _lastAutoRecognizedStroke = null;
      _history.put(rawInkElement);
    } else if (_preview != null &&
        (_preview!.width > 2 ||
            _preview!.height > 2 ||
            _connectingStartId != null ||
            _connectingEndId != null)) {
      final element = _preview!.copy({
        'id': _id(),
        if (_connectingStartId != null) 'startId': _connectingStartId,
        if (_connectingEndId != null) 'endId': _connectingEndId,
      });
      _history.put(element);
      _selection
        ..clear()
        ..add(element.id);
    }
    if (isTap && !_panning && !_resizing && _selection.length == 1) {
      final selectedId = _selection.single;
      final element = _scene[selectedId];
      if (element != null && element.type == 'card') {
        // Task card checkbox tap
        final isTask =
            (element.objectId != null &&
                _objects[element.objectId]?.typeId == 'orbit.task') ||
            element.data['isTask'] == true;
        if (isTask) {
          final pres = element.cardPresentation;
          final cbRect = pres == 'compact'
              ? Rect.fromLTWH(
                  element.x + 22,
                  element.y + (element.height - 16) / 2,
                  18,
                  18,
                )
              : Rect.fromLTWH(
                  element.x + 16,
                  element.y + (pres == 'preview' ? 38 : 46),
                  24,
                  24,
                );
          if (cbRect.inflate(6.0).contains(Offset(point.x, point.y))) {
            if (element.objectId != null) {
              _toggleTask(element.objectId!);
            } else {
              _history.put(
                element.copy({'isDone': element.data['isDone'] != true}),
              );
              _commit();
            }
            _clearGesture();
            setState(() {});
            return;
          }
        }
        // Dynamic view items tap (CAN-09)
        final viewConfig = element.viewConfig;
        if (viewConfig != null && viewConfig['type'] == 'tasks') {
          var tasks = _objects.values
              .where((o) => o.typeId == 'orbit.task')
              .toList();
          final statusFilter = viewConfig['status'] as String? ?? 'all';
          if (statusFilter == 'open') {
            tasks = tasks.where((t) => !t.isCompleted).toList();
          } else if (statusFilter == 'completed') {
            tasks = tasks.where((t) => t.isCompleted).toList();
          }
          double itemY = element.y + 68 + 28;
          for (final task in tasks.take(3)) {
            final itemCbRect = Rect.fromLTWH(element.x + 16, itemY, 20, 20);
            if (itemCbRect.inflate(4.0).contains(Offset(point.x, point.y))) {
              _toggleTask(task.id);
              _clearGesture();
              setState(() {});
              return;
            }
            final itemRowRect = Rect.fromLTWH(
              element.x + 36,
              itemY,
              element.width - 52,
              20,
            );
            if (itemRowRect.contains(Offset(point.x, point.y))) {
              widget.onOpenObject(task.id);
              _clearGesture();
              return;
            }
            itemY += 20;
          }
        }
      }
      if (element != null &&
          (element.type == 'sticky' || element.type == 'card')) {
        final contentBounds = element.type == 'sticky'
            ? Rect.fromLTWH(
                element.x + 16,
                element.y + 16,
                math.max(1, element.width - 32),
                math.max(1, element.height - 32),
              )
            : Rect.fromLTWH(
                element.x + 16,
                element.y + 98,
                math.max(1, element.width - 32),
                math.max(1, element.height - 110),
              );
        final lines = element.text.trim().split('\n');
        final isCardWithTitle = element.type == 'card' && lines.length > 1;
        final targetText = isCardWithTitle
            ? lines.skip(1).join('\n')
            : element.text;
        final lineIndex = CanvasRichText.hitTestCheckbox(
          text: targetText,
          bounds: contentBounds,
          clickOffset: Offset(point.x, point.y),
          textCache: _textCache,
          defaultFontSize: element.type == 'sticky' ? 16.0 : 12.0,
        );
        if (lineIndex != null) {
          final updatedTargetText = CanvasRichText.toggleLine(
            targetText,
            lineIndex,
          );
          final updatedText = isCardWithTitle
              ? '${lines.first}\n$updatedTargetText'
              : updatedTargetText;
          final original = _original[selectedId];
          _history.put(
            element.copy({
              'text': updatedText,
              'x': original?.x ?? element.x,
              'y': original?.y ?? element.y,
            }),
          );
          _clearGesture();
          _commit();
          setState(() {});
          return;
        }
      }
    }
    if (!_panning &&
        !_resizing &&
        _original.isNotEmpty &&
        _selection.length == 1) {
      final element = _scene[_selection.single];
      final original = _original[_selection.single];
      if (element != null && original != null) {
        if (isTap && (element.x != original.x || element.y != original.y)) {
          _history.put(element.copy({'x': original.x, 'y': original.y}));
        } else if (element.type != 'column' &&
            (element.x != original.x || element.y != original.y)) {
          final columns = _scene
              .query(element.bounds)
              .where(
                (e) =>
                    e.type == 'column' &&
                    !e.locked &&
                    e.bounds.contains(element.bounds.center) &&
                    !columnMembers(_scene, e.id).any((child) => child.locked),
              )
              .toList();
          final target = columns.isEmpty ? null : columns.last;
          final oldColumn = element.data['columnId'];
          _history.put(element.copy({'columnId': target?.id}));
          for (final id in {oldColumn, target?.id}.whereType<String>()) {
            final column = _scene[id];
            if (column != null) {
              for (final item in arrangeColumn(
                column,
                columnMembers(_scene, id),
              )) {
                _history.put(item);
              }
            }
          }
        }
      }
    }
    _clearGesture();
    _commit();
  }

  void _clearGesture() {
    _dragSnapIndex = null;
    _liveInkCache.clear();
    if (_lastInkBroadcast != null) widget.onInkPreview?.call(null);
    _lastInkBroadcast = null;
    _stopEdgePan();
    if (_edgePanned) {
      _edgePanned = false;
      _cameraChanged();
    }
    if (_scene.finishInteractiveRouting(deferCanonical: true)) {
      _requestCanonicalRouting(_scene);
    }
    if (_stylusToolBeforeOverride != null) {
      _tool = _stylusToolBeforeOverride!;
      _stylusToolBeforeOverride = null;
    }
    _gestureSelection = null;
    _endpointStart = null;
    _pointer = null;
    _pointerKind = null;
    _start = null;
    _lastScreen = null;
    _region = null;
    _lassoPoints = null;
    _preview = null;
    _inkPreviewDirty = false;
    _ink.clear();
    _original.clear();
    _panning = false;
    _resizing = false;
    _activeGuides.clear();
    _connectingStartId = null;
    _connectingEndId = null;
    _hoveredAnchorElementId = null;
    _inMultiTouch = false;
    _touchPointers.clear();
  }

  CanvasScene? _requestedRoutingScene;
  bool _routingWorkerBusy = false;
  bool _initialRoutingLoading = false;
  CanvasScene _makeScene(Map<String, dynamic> data) {
    final elements = data['elements'];
    var links = 0;
    if (elements is List) {
      for (final e in elements) {
        if (e is Map &&
            e['type'] == 'connector' &&
            e['umlLink'] is Map &&
            const {
              'association',
              'include',
              'extend',
              'generalization',
              'constraint',
            }.contains((e['umlLink'] as Map)['kind'])) {
          links++;
        }
        if (links >= 12) break;
      }
    }
    final scene = CanvasScene.fromJson(
      data,
      deferAutomaticRouting: links >= 12,
    );
    _initialRoutingLoading = scene.canonicalRoutingPending;
    if (_initialRoutingLoading) {
      scheduleMicrotask(() {
        if (mounted && identical(scene, _scene)) {
          _requestCanonicalRouting(scene);
        }
      });
    }
    return scene;
  }

  void _requestCanonicalRouting(CanvasScene scene) {
    _requestedRoutingScene = scene;
    if (_routingWorkerBusy) return;
    unawaited(_runCanonicalRouting());
  }

  Future<void> _runCanonicalRouting() async {
    _routingWorkerBusy = true;
    try {
      while (mounted && _requestedRoutingScene != null) {
        final scene = _requestedRoutingScene!;
        _requestedRoutingScene = null;
        if (!identical(scene, _scene) ||
            scene.interactiveRouting ||
            !scene.canonicalRoutingPending) {
          continue;
        }
        try {
          final prepared = await compute(
            prepareUseCaseRouting,
            scene.toJson(),
            debugLabel: 'Orbit diagram routing',
          );
          if (!mounted || !identical(scene, _scene)) continue;
          final applied = scene.applyPreparedRouting(prepared);
          if (applied ||
              _initialRoutingLoading && !scene.canonicalRoutingPending) {
            setState(() => _initialRoutingLoading = false);
            _scheduleLocation();
          }
          if (scene.canonicalRoutingPending && !scene.interactiveRouting) {
            _requestedRoutingScene = scene;
          }
        } on Object {
          // Unknown/non-sendable extension data can use the existing solver.
          // This changes derived geometry only, never authored data/history.
          if (mounted &&
              identical(scene, _scene) &&
              !scene.interactiveRouting) {
            scene.finishPendingRouting();
            setState(() => _initialRoutingLoading = false);
            _scheduleLocation();
          }
        }
      }
    } finally {
      _routingWorkerBusy = false;
    }
  }

  void _rollbackGesture({bool restoreCamera = true}) {
    if (restoreCamera && (_panning || _inMultiTouch) && _startCamera != null) {
      _camera = _startCamera!;
    }
    _history.cancel();
    final selection = _gestureSelection;
    if (selection != null) {
      _selection
        ..clear()
        ..addAll(selection.where((id) => _scene[id] != null));
    }
    _clearGesture();
  }

  void _cancelGesture() {
    _rollbackGesture();
    if (mounted) setState(() {});
  }

  // A keyboard/menu command must not commit provisional pointer geometry as
  // part of its own undo entry. Keep its selected target after rolling back.
  void _settlePlacementCommand() {
    if (_pointer != null || _inMultiTouch) {
      final selected = {..._selection};
      _rollbackGesture();
      _selection
        ..clear()
        ..addAll(selected.where((id) => _scene[id] != null));
      if (mounted) setState(() {});
    }
    _finishText();
  }

  void _undo() {
    if (_readOnly) return;
    if (_pointer != null || _inMultiTouch) {
      _cancelGesture();
      return;
    }
    _finishText();
    if (_history.undo()) {
      _selection.removeWhere((id) => _scene[id] == null);
      _emit();
      setState(() {});
    }
  }

  void _redo() {
    if (_readOnly) return;
    if (_pointer != null || _inMultiTouch) {
      _cancelGesture();
      return;
    }
    _finishText();
    if (_history.redo()) {
      _selection.removeWhere((id) => _scene[id] == null);
      _emit();
      setState(() {});
    }
  }

  void _delete() {
    if (_readOnly) return;
    _settlePlacementCommand();
    final toDelete = {..._selection};
    for (final id in _selection) {
      if (_scene[id]?.groupId != null) {
        toDelete.addAll(
          getGroupMembers(_scene, _scene[id]!.groupId!).map((e) => e.id),
        );
      }
    }
    for (final id in toDelete) {
      if (_scene[id]?.type == 'column' && !(_scene[id]?.locked ?? true)) {
        for (final member in columnMembers(_scene, id)) {
          _history.put(member.copy({'columnId': null}));
        }
      }
      if (!(_scene[id]?.locked ?? true)) _history.remove(id);
    }
    _selection.clear();
    _commit();
    final after = _scene.revision,
        owner = widget.canvasId,
        epoch = _interactionEpoch;
    final scene = _scene;
    final removed = toDelete.where((id) => _scene[id] == null).length;
    if (removed > 0) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            'Removed $removed ${removed == 1 ? 'placement' : 'placements'} from this Canvas. Originals are retained.',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              if (mounted &&
                  !_readOnly &&
                  widget.canvasId == owner &&
                  _scene.revision == after &&
                  identical(_scene, scene) &&
                  _interactionEpoch == epoch) {
                _undo();
              }
            },
          ),
        ),
      );
    }
  }

  void _reorder(String action) {
    if (_readOnly || _selection.isEmpty) return;
    _history.reorder(_selection, () {
      final items = _selection.toList();
      if (action == 'front') {
        for (final id in items) {
          _scene.bringToFront(id);
        }
      } else if (action == 'back') {
        for (final id in items.reversed) {
          _scene.sendToBack(id);
        }
      } else if (action == 'forward') {
        final sorted = items.toList()
          ..sort(
            (a, b) =>
                (_scene.orderOf(b) ?? 0).compareTo(_scene.orderOf(a) ?? 0),
          );
        for (final id in sorted) {
          _scene.bringForward(id);
        }
      } else if (action == 'backward') {
        final sorted = items.toList()
          ..sort(
            (a, b) =>
                (_scene.orderOf(a) ?? 0).compareTo(_scene.orderOf(b) ?? 0),
          );
        for (final id in sorted) {
          _scene.sendBackward(id);
        }
      }
    });
    _commit();
    setState(() {});
  }

  Future<void> _copy({bool cut = false}) async {
    if (cut && _readOnly) return;
    _settlePlacementCommand();
    final originalSelection = {..._selection};
    final canvasId = widget.canvasId, epoch = _interactionEpoch, scene = _scene;
    final request = ++_clipboardCopyRequest;
    final ids = {..._selection};
    for (final id in _selection) {
      if (_scene[id]?.type == 'column') {
        ids.addAll(columnMembers(_scene, id).map((e) => e.id));
      }
      if (_scene[id]?.groupId != null) {
        ids.addAll(
          getGroupMembers(_scene, _scene[id]!.groupId!).map((e) => e.id),
        );
      }
    }
    if (cut && ids.any((id) => _scene[id]?.locked == true)) {
      _notice('Unlock all selected items before cutting them.');
      return;
    }
    final elements = ids
        .map((id) => _scene[id])
        .whereType<CanvasElement>()
        .map((e) => e.data)
        .toList();
    if (elements.isEmpty) return;
    // Stored fallbacks can lag behind linked-node movement. Carry the visible
    // endpoints so a connector remains in place when pasted without its nodes.
    final clipboardElements = elements.map((data) {
      final element = CanvasElement(data);
      if (!isConnectorElement(element)) return data;
      final detachedStart =
          element.startId != null && !ids.contains(element.startId);
      final detachedEnd = element.endId != null && !ids.contains(element.endId);
      if (!detachedStart && !detachedEnd) return data;
      final endpoints = resolveConnectorEndpoints(element, _scene);
      return {
        ...data,
        ...connectorEndpointData(endpoints.start, endpoints.end),
      };
    }).toList();
    try {
      await Clipboard.setData(
        ClipboardData(
          text:
              'orbit-canvas/1\n${jsonEncode({'elements': clipboardElements})}',
        ),
      );
    } catch (_) {
      if (mounted) {
        _notice('Could not copy the selection. No items were removed.');
      }
      return;
    }
    if (cut && mounted && !_readOnly) {
      if (widget.canvasId != canvasId ||
          epoch != _interactionEpoch ||
          !identical(scene, _scene) ||
          request != _clipboardCopyRequest ||
          !setEquals(_selection, originalSelection)) {
        _notice('The selection changed while copying; no items were removed.');
        return;
      }
      if (elements.any((data) => !identical(_scene[data['id']]?.data, data))) {
        _notice('The selection changed while copying; no items were removed.');
        return;
      }
      _selection
        ..clear()
        ..addAll(ids);
      _delete();
    }
  }

  Future<void> _paste({CanvasPoint? at}) async {
    if (_readOnly) return;
    _settlePlacementCommand();
    ClipboardData? clipboard;
    final canvasId = widget.canvasId;
    final epoch = _interactionEpoch;
    final scene = _scene, revision = _scene.revision;
    final selection = {..._selection};
    final request = ++_clipboardPasteRequest;
    final origin =
        at ??
        _camera.toWorld(CanvasPoint(_viewport.width / 2, _viewport.height / 2));
    try {
      clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    } catch (_) {
      if (mounted) _notice('The clipboard is unavailable.');
      return;
    }
    if (!mounted ||
        _readOnly ||
        widget.canvasId != canvasId ||
        request != _clipboardPasteRequest ||
        epoch != _interactionEpoch) {
      return;
    }
    if (!identical(_scene, scene) ||
        _scene.revision != revision ||
        !setEquals(_selection, selection)) {
      _notice(
        'The Canvas changed while reading the clipboard. Paste again at the intended position.',
      );
      return;
    }
    if ((clipboard?.text ?? '').isEmpty) {
      if (widget.onPasteImage != null) {
        await _insertImage(
          widget.onPasteImage!,
          at: origin,
          stillCurrent: () =>
              request == _clipboardPasteRequest && epoch == _interactionEpoch,
        );
      }
      return;
    }
    final text = clipboard!.text!;
    if (text.startsWith('orbit-canvas/1\n')) {
      try {
        final decoded = jsonDecode(text.substring('orbit-canvas/1\n'.length));
        if (decoded is! Map || decoded['elements'] is! List) {
          throw const FormatException('Invalid Canvas clipboard');
        }
        final originals = <CanvasElement>[];
        final originalIds = <String>{};
        for (final value in decoded['elements'] as List) {
          if (value is! Map) throw const FormatException('Invalid placement');
          final element = CanvasElement(Map<String, dynamic>.from(value));
          if (!element.renderable || !originalIds.add(element.id)) {
            throw const FormatException('Invalid or duplicate placement');
          }
          originals.add(element);
        }
        if (originals.isEmpty) return;
        // Prepare the complete batch before touching selection or undo history.
        final pasted = <CanvasElement>[];
        final newIds = {for (final original in originals) original.id: _id()};
        final groups = {
          for (final original in originals)
            if (original.groupId != null) original.groupId!: _id(),
        };
        for (final original in originals) {
          final element = original.copy({
            'id': newIds[original.id],
            'columnId': newIds[original.data['columnId']],
            'groupId': groups[original.groupId],
            if (original.startId != null) 'startId': newIds[original.startId],
            if (original.endId != null) 'endId': newIds[original.endId],
            if (original.hasEndpoints) ...{
              'startX': (original.data['startX'] as num) + 32,
              'startY': (original.data['startY'] as num) + 32,
              'endX': (original.data['endX'] as num) + 32,
              'endY': (original.data['endY'] as num) + 32,
            },
            'x': original.x + 32,
            'y': original.y + 32,
            'locked': false,
          });
          if (!element.renderable) {
            throw const FormatException('Invalid placement');
          }
          pasted.add(element);
        }
        _selection.clear();
        for (final element in pasted) {
          _history.put(element);
          _selection.add(element.id);
        }
        _commit();
        _pasteNotice(pasted.length);
      } on FormatException {
        _notice(
          'The clipboard contains invalid or unsupported Canvas items. Nothing was pasted.',
        );
      }
    } else if (text.trim().isNotEmpty) {
      final items = markdownCanvasItems(text);
      _selection.clear();
      var offset = 0.0;
      for (final item in items) {
        final ref = item['contentRef'];
        final object = ref is String
            ? _objects.values.where((o) => o.contentRef == ref).firstOrNull
            : null;
        final element = CanvasElement({
          ...item,
          'id': _id(),
          if (object != null) 'objectId': object.id,
          'x': origin.x - (item['type'] == 'image' ? 160 : 110) + offset,
          'y': origin.y - (item['type'] == 'image' ? 120 : 90) + offset,
          'width': item['type'] == 'image' ? 320.0 : 220.0,
          'height': item['type'] == 'image' ? 240.0 : 180.0,
          'color': _color,
        });
        _history.put(element);
        _selection.add(element.id);
        offset += 40;
      }
      _commit();
      _pasteNotice(items.length);
    }
  }

  void _pasteNotice(int count) {
    if (count == 0) return;
    final revision = _scene.revision,
        owner = widget.canvasId,
        epoch = _interactionEpoch;
    final scene = _scene;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('Pasted $count ${count == 1 ? 'item' : 'items'}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (mounted &&
                !_readOnly &&
                widget.canvasId == owner &&
                _interactionEpoch == epoch &&
                identical(_scene, scene) &&
                _scene.revision == revision) {
              _undo();
            }
          },
        ),
      ),
    );
  }

  void _duplicate() {
    if (_readOnly || _selection.isEmpty) return;
    _settlePlacementCommand();
    final ids = {..._selection};
    for (final id in _selection) {
      if (_scene[id]?.type == 'column') {
        ids.addAll(columnMembers(_scene, id).map((e) => e.id));
      }
      if (_scene[id]?.groupId != null) {
        ids.addAll(
          getGroupMembers(_scene, _scene[id]!.groupId!).map((e) => e.id),
        );
      }
    }
    final originals = ids
        .map((id) => _scene[id])
        .whereType<CanvasElement>()
        .where((e) => e.renderable && !e.locked)
        .toList();
    if (originals.isEmpty) return;

    final newIds = {for (final original in originals) original.id: _id()};
    final groupMap = <String, String>{};
    for (final orig in originals) {
      if (orig.groupId != null && !groupMap.containsKey(orig.groupId!)) {
        groupMap[orig.groupId!] =
            'grp_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(10000)}';
      }
    }
    final newSelection = <String>{};

    _history.begin();
    for (final original in originals) {
      final newGid = original.groupId != null
          ? groupMap[original.groupId!]
          : null;
      final patch = <String, dynamic>{
        'id': newIds[original.id],
        if (original.startId != null)
          'startId': newIds[original.startId] ?? original.startId,
        if (original.endId != null)
          'endId': newIds[original.endId] ?? original.endId,
        'columnId': newIds[original.data['columnId']],
        'x': original.x + 20,
        'y': original.y + 20,
        'locked': false,
      };
      if (newGid != null) patch['groupId'] = newGid;
      final duplicate = original.copy(patch);
      _history.put(duplicate);
      if (_selection.contains(original.id)) {
        newSelection.add(duplicate.id);
      }
    }
    _commit();
    setState(() {
      _selection
        ..clear()
        ..addAll(newSelection);
    });
  }

  void _align(CanvasAlignment alignment) {
    if (_readOnly || _selection.length < 2) return;
    final selectedElements = _selection
        .map((id) => _scene[id])
        .whereType<CanvasElement>()
        .where((e) => e.renderable)
        .toList();
    if (selectedElements.length < 2) return;

    if (alignment == CanvasAlignment.distributeH ||
        alignment == CanvasAlignment.distributeV) {
      if (selectedElements.length < 3) return;
      _history.begin();
      if (alignment == CanvasAlignment.distributeH) {
        final sorted = [...selectedElements]
          ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
        final minL = sorted.first.bounds.left;
        final maxR = sorted.last.bounds.right;
        final totalWidth = sorted.fold<double>(
          0.0,
          (sum, e) => sum + e.bounds.width,
        );
        final gap = (maxR - minL - totalWidth) / (sorted.length - 1);
        var curX = minL;
        for (final e in sorted) {
          if (!e.locked) {
            final dx = curX - e.bounds.left;
            if (dx != 0) {
              _history.put(e.copy({'x': e.x + dx}));
            }
          }
          curX += e.bounds.width + gap;
        }
      } else {
        final sorted = [...selectedElements]
          ..sort((a, b) => a.bounds.top.compareTo(b.bounds.top));
        final minT = sorted.first.bounds.top;
        final maxB = sorted.last.bounds.bottom;
        final totalHeight = sorted.fold<double>(
          0.0,
          (sum, e) => sum + e.bounds.height,
        );
        final gap = (maxB - minT - totalHeight) / (sorted.length - 1);
        var curY = minT;
        for (final e in sorted) {
          if (!e.locked) {
            final dy = curY - e.bounds.top;
            if (dy != 0) {
              _history.put(e.copy({'y': e.y + dy}));
            }
          }
          curY += e.bounds.height + gap;
        }
      }
      _commit();
      setState(() {});
      return;
    }

    CanvasBounds unionBox = selectedElements.first.bounds;
    for (final e in selectedElements.skip(1)) {
      unionBox = unionBox.union(e.bounds);
    }

    final movable = selectedElements.where((e) => !e.locked).toList();
    if (movable.isEmpty) return;

    _history.begin();
    for (final e in movable) {
      double newX = e.x;
      double newY = e.y;
      switch (alignment) {
        case CanvasAlignment.left:
          newX = unionBox.left;
        case CanvasAlignment.centerH:
          newX = unionBox.left + (unionBox.width - e.width) / 2;
        case CanvasAlignment.right:
          newX = unionBox.right - e.width;
        case CanvasAlignment.top:
          newY = unionBox.top;
        case CanvasAlignment.middleV:
          newY = unionBox.top + (unionBox.height - e.height) / 2;
        case CanvasAlignment.bottom:
          newY = unionBox.bottom - e.height;
        case CanvasAlignment.distributeH:
        case CanvasAlignment.distributeV:
          break;
      }
      final dx = newX - e.x;
      final dy = newY - e.y;
      if (dx == 0 && dy == 0) continue;

      _history.put(e.copy({'x': newX, 'y': newY}));
    }
    _commit();
    setState(() {});
  }

  void _organizeUseCases() {
    if (_readOnly || _initialRoutingLoading) return;
    _finishText();
    _cancelGesture();
    final arranged = organizeUseCases(_scene, selection: _selection);
    if (arranged.isEmpty) {
      _notice(
        'Select a use-case diagram to organize. Locked items stay in place.',
      );
      return;
    }
    _history.begin();
    _scene.batch(() {
      for (final e in arranged) {
        _history.put(e);
      }
    });
    _selection
      ..clear()
      ..addAll(arranged.map((e) => e.id));
    _commit();
    _fit(selectionOnly: true);
    _focus.requestFocus();
    _notice('Use-case diagram organized · Undo restores the previous layout');
  }

  void _applyArrangement(CanvasArrangement action) {
    if (_readOnly || _selection.length < 2) return;
    _finishText();
    _cancelGesture();
    final elements = _selection
        .map((id) => _scene[id])
        .whereType<CanvasElement>();
    final rearranged = arrangeCanvas(elements, action);
    if (rearranged.isEmpty) return;
    _history.begin();
    for (final element in rearranged) {
      _history.put(element);
    }
    _commit();
    setState(() {});
  }

  void _groupSelection() {
    if (_readOnly || _selection.length < 2) return;
    _finishText();
    _cancelGesture();
    final grouped = groupElements(_scene, _selection);
    if (grouped.isEmpty) return;
    _history.begin();
    for (final element in grouped) {
      _history.put(element);
    }
    _commit();
    setState(() {});
    _notice('Grouped ${grouped.length} elements.');
  }

  void _ungroupSelection() {
    if (_readOnly || _selection.isEmpty) return;
    _finishText();
    _cancelGesture();
    final ungrouped = ungroupElements(_scene, _selection);
    if (ungrouped.isEmpty) {
      _notice('No groups found in selection.');
      return;
    }
    _history.begin();
    for (final element in ungrouped) {
      _history.put(element);
    }
    _commit();
    setState(() {});
    _notice('Ungrouped ${ungrouped.length} elements.');
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _editTransclusionContent(String objectId) async {
    final obj = _objects[objectId];
    if (obj == null) return;
    final titleCtrl = TextEditingController(text: obj.title);
    final bodyCtrl = TextEditingController(text: obj.body);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.sync_alt,
              size: 20,
              color: OrbitColors.of(context).secondary,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Live Note Transclusion Editor',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note Title',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Live Note Body (Markdown)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Save & Sync'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      final newTitle = titleCtrl.text.trim();
      final newBody = bodyCtrl.text;
      final updated = CanvasObjectReference(
        id: obj.id,
        title: newTitle.isEmpty ? obj.title : newTitle,
        typeId: obj.typeId,
        body: newBody,
        properties: obj.properties,
      );
      setState(() {
        _objects[objectId] = updated;
      });
      widget.onUpdateObjectProperties?.call(objectId, {
        'title': updated.title,
        'body': updated.body,
      });
      _notice('Note "${updated.title}" updated live across canvas');
    }
  }

  void _showAudioPlayer(CanvasElement element) {
    final title = element.text.isNotEmpty ? element.text : 'Voice Memo';
    final transcript = element.data['transcript'] as String?;
    showOrbitDialog<void>(
      context: context,
      builder: (dialogCtx) => OrbitDialog(
        title: Row(
          children: [
            Icon(
              Icons.mic_outlined,
              size: 18,
              color: OrbitColors.of(context).accent,
            ),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: OrbitAudioPlayerCard(
          title: title,
          transcript: transcript,
          initialSpeed: widget.defaultAudioSpeed,
        ),
      ),
    );
  }

  void _edit(CanvasElement element) {
    if (isInteractionItem(element)) {
      _editInteraction(
        element: element,
        sequence: umlLinkKind(element)?.sequence == true,
      );
      return;
    }
    if (isUmlClass(element) || element.data['umlRelationship'] is String) {
      _editUml(element: element);
      return;
    }
    if (element.type == 'link') {
      final uri = Uri.tryParse(element.url);
      if (uri != null &&
          {'http', 'https'}.contains(uri.scheme) &&
          uri.host.isNotEmpty) {
        widget.onOpenExternal?.call(uri);
      }
      return;
    }
    if (element.type == 'card') {
      if (element.objectId != null &&
          element.objectId!.isNotEmpty &&
          _objects.containsKey(element.objectId)) {
        final nested = element.data['data'] is Map
            ? (element.data['data'] as Map)
            : const {};
        final pres = element.data['presentation'] is String
            ? element.data['presentation'] as String
            : (nested['presentation'] is String
                  ? nested['presentation'] as String
                  : null);
        final ref = element.data['referenceTarget'] is String
            ? element.data['referenceTarget'] as String
            : (nested['referenceTarget'] is String
                  ? nested['referenceTarget'] as String
                  : null);
        final quote = element.data['quote'] ?? nested['quote'];
        final page = element.data['page'] ?? nested['page'];

        if (pres == 'transclusion' && ref == null && quote == null) {
          _editTransclusionContent(element.objectId!);
          return;
        }
        widget.onOpenObject(
          ref ??
              (page != null
                  ? '${element.objectId}#page=$page'
                  : element.objectId!),
        );
        return;
      }
      if (element.objectId != null &&
          element.objectId!.isNotEmpty &&
          !_objects.containsKey(element.objectId) &&
          element.text.trim().isEmpty) {
        _notice(
          'The original object is unavailable. Removing this card does not delete an object.',
        );
        return;
      }
      // Standalone card or card with text: allow inline editing below
    }
    if (element.type == 'swatch') {
      final hex =
          '#${(element.color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
      Clipboard.setData(ClipboardData(text: hex));
      _notice('Color $hex copied to clipboard');
    }
    if (element.type == 'audio') {
      _showAudioPlayer(element);
      return;
    }
    if (_readOnly ||
        !{
          'text',
          'sticky',
          'rectangle',
          'ellipse',
          'diamond',
          'frame',
          'column',
          'section',
          'swatch',
          'card',
          'arrow',
          'line',
          'connector',
        }.contains(element.type)) {
      return;
    }
    setState(() {
      _editingId = element.id;
      _text.text = element.text;
    });
    _textFocus.requestFocus();
    _text.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _text.text.length,
    );
  }

  void _finishText() {
    final id = _editingId;
    if (id == null) return;
    final original = _scene[id];
    _editingId = null;
    if (original != null && !_readOnly && !original.locked) {
      final patch = <String, dynamic>{};
      if (original.text != _text.text) {
        patch['text'] = _text.text;
      }
      if (original.type == 'section') {
        final trimmed = _text.text.trim();
        if (trimmed.startsWith('# ')) {
          patch['headerSize'] = 'large';
          patch['fontSize'] = 24.0;
          patch['strokeWidth'] = 3.5;
          patch['height'] = math.max(original.height, 66.0);
        } else if (trimmed.startsWith('## ')) {
          patch['headerSize'] = 'medium';
          patch['fontSize'] = 18.0;
          patch['strokeWidth'] = 2.5;
          patch['height'] = math.max(original.height, 52.0);
        } else if (trimmed.startsWith('### ')) {
          patch['headerSize'] = 'small';
          patch['fontSize'] = 13.0;
          patch['strokeWidth'] = 1.5;
          patch['height'] = math.max(original.height, 40.0);
        }
      }
      if (patch.isNotEmpty) {
        _history.put(original.copy(patch));
        _commit();
      }
    }
    // Text drafts are published while typing; finishing coalesces their undo entry.
    if (_history.inCommand) _commit();
    if (mounted) setState(() {});
  }

  KeyEventResult _onTextKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _finishText();
      _focus.requestFocus();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter &&
        (_command ||
            (_editingId != null &&
                (_scene[_editingId!]?.type == 'connector' ||
                    _scene[_editingId!]?.type == 'arrow' ||
                    _scene[_editingId!]?.type == 'line' ||
                    _scene[_editingId!]?.type == 'section')))) {
      _finishText();
      _focus.requestFocus();
      return KeyEventResult.handled;
    }

    if (!HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isMetaPressed &&
        !HardwareKeyboard.instance.isAltPressed &&
        event.logicalKey == LogicalKeyboardKey.enter) {
      final res = CanvasRichText.handleSmartEnter(_text.text, _text.selection);
      if (res != null) {
        _text.value = TextEditingValue(
          text: res.text,
          selection: res.selection,
        );
        final element = _editingId == null ? null : _scene[_editingId!];
        if (element != null) {
          _history.put(element.copy({'text': res.text}));
          _emit();
        }
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _onSearchKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _closeSearchHud();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        _previousSearchMatch();
      } else {
        _nextSearchMatch();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _toggleSearchHud() {
    if (_showSearchHud) {
      _closeSearchHud();
    } else {
      _openSearchHud();
    }
  }

  void _openSearchHud() {
    setState(() {
      _showSearchHud = true;
    });
    _searchFocusNode.requestFocus();
    if (_searchController.text.isNotEmpty) {
      _runSearch();
    }
  }

  void _closeSearchHud() {
    setState(() {
      _showSearchHud = false;
      _searchResults = [];
      _activeSearchIndex = 0;
    });
    _focus.requestFocus();
  }

  void _onSearchQueryChanged() {
    if (!_showSearchHud) return;
    _runSearch();
  }

  void _onSearchCategoryChanged(CanvasSearchCategory cat) {
    setState(() {
      _searchCategory = cat;
    });
    _runSearch();
  }

  void _runSearch() {
    final query = _searchController.text;
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _activeSearchIndex = 0;
      });
      return;
    }
    final results = searchCanvasElements(
      scene: _scene,
      objectLookup: MapCanvasObjectLookup(_objects),
      query: query,
      category: _searchCategory,
    );
    setState(() {
      _searchResults = results;
      _activeSearchIndex = 0;
    });
    if (results.isNotEmpty) {
      _jumpToSearchMatch(0);
    }
  }

  void _jumpToSearchMatch(int index) {
    if (index < 0 || index >= _searchResults.length) return;
    _activeSearchIndex = index;
    final match = _searchResults[index];
    final bounds = match.bounds;

    final targetZoom = math
        .min(
          (_viewport.width - 240) / math.max(1, bounds.width),
          (_viewport.height - 240) / math.max(1, bounds.height),
        )
        .clamp(0.4, 1.25);

    setState(() {
      _camera = CanvasCamera(
        x: bounds.center.x - _viewport.width / targetZoom / 2,
        y: bounds.center.y - _viewport.height / targetZoom / 2,
        zoom: targetZoom,
      );
      _selection
        ..clear()
        ..add(match.elementId);
    });
    _cameraChanged();
  }

  void _nextSearchMatch() {
    if (_searchResults.isEmpty) return;
    final next = (_activeSearchIndex + 1) % _searchResults.length;
    _jumpToSearchMatch(next);
  }

  void _previousSearchMatch() {
    if (_searchResults.isEmpty) return;
    final prev =
        (_activeSearchIndex - 1 + _searchResults.length) %
        _searchResults.length;
    _jumpToSearchMatch(prev);
  }

  void _applyFormatPrefix(String prefix) {
    if (_editingId == null) return;
    final res = CanvasRichText.toggleLinePrefix(
      _text.text,
      _text.selection,
      prefix,
    );
    _text.value = TextEditingValue(text: res.text, selection: res.selection);
    final element = _scene[_editingId!];
    if (element != null) {
      _history.put(element.copy({'text': res.text}));
      _emit();
    }
    _textFocus.requestFocus();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (_laserMode) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() => _laserMode = false);
      }
      return KeyEventResult.handled;
    }
    if (_titleFocus.hasFocus) {
      return KeyEventResult.ignored;
    }
    if (_editingId != null) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        _finishText();
        _focus.requestFocus();
        return KeyEventResult.handled;
      }
      if (event is KeyDownEvent &&
          _command &&
          event.logicalKey == LogicalKeyboardKey.enter) {
        _finishText();
        _focus.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.space) {
      setState(() {
        _spacePressed = event is! KeyUpEvent;
      });
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_drawingFocus && _focusControlsVisible) {
        setState(() => _focusControlsVisible = false);
        return KeyEventResult.handled;
      }
      if (_showSearchHud) {
        _closeSearchHud();
        return KeyEventResult.handled;
      }
      _cancelGesture();
      _selection.clear();
      _setTool(_Tool.select);
    } else if (_command && key == LogicalKeyboardKey.keyF) {
      _toggleSearchHud();
      return KeyEventResult.handled;
    } else if (_command && key == LogicalKeyboardKey.keyZ) {
      _shift ? _redo() : _undo();
    } else if (_command && key == LogicalKeyboardKey.keyY) {
      _redo();
    } else if (_command && key == LogicalKeyboardKey.keyC) {
      _copy();
    } else if (_command && key == LogicalKeyboardKey.keyX) {
      _copy(cut: true);
    } else if (_command && key == LogicalKeyboardKey.keyV) {
      _paste();
    } else if (_command && key == LogicalKeyboardKey.keyD) {
      _duplicate();
    } else if (_command && key == LogicalKeyboardKey.keyG) {
      _shift ? _ungroupSelection() : _groupSelection();
    } else if (_command && key == LogicalKeyboardKey.keyI) {
      _showImportDialog();
    } else if (_command && key == LogicalKeyboardKey.keyA) {
      setState(() {
        _selection.addAll(
          _scene.elements
              .where((e) => e.renderable && !e.locked && !e.hidden)
              .map((e) => e.id),
        );
      });
    } else if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      _delete();
    } else if (key == LogicalKeyboardKey.enter && _selection.length == 1) {
      _edit(_scene[_selection.first]!);
    } else if (!_command && key == LogicalKeyboardKey.keyV) {
      _setTool(_Tool.select);
    } else if (!_command && key == LogicalKeyboardKey.keyL) {
      _setTool(_Tool.lasso);
    } else if (!_command && key == LogicalKeyboardKey.keyH) {
      _setTool(_Tool.pan);
    } else if (!_command && key == LogicalKeyboardKey.keyP) {
      _setTool(_Tool.pen);
    } else if (!_command && key == LogicalKeyboardKey.keyY) {
      _setTool(_Tool.highlighter);
    } else if (!_command &&
        key == LogicalKeyboardKey.bracketRight &&
        _selection.isNotEmpty) {
      _shift ? _reorder('front') : _reorder('forward');
    } else if (!_command &&
        key == LogicalKeyboardKey.bracketLeft &&
        _selection.isNotEmpty) {
      _shift ? _reorder('back') : _reorder('backward');
    } else if (!_command && key == LogicalKeyboardKey.keyT) {
      _setTool(_Tool.text);
    } else if (!_command && key == LogicalKeyboardKey.keyS) {
      _setTool(_Tool.sticky);
    } else if (!_command && key == LogicalKeyboardKey.keyE) {
      _setTool(_Tool.eraser);
    } else if (key == LogicalKeyboardKey.digit1) {
      _fit();
    } else if (key == LogicalKeyboardKey.digit0) {
      _zoom(1 / _camera.zoom);
    } else if (key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.add ||
        key == LogicalKeyboardKey.numpadAdd) {
      _zoom(1.25);
    } else if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract) {
      _zoom(0.8);
    } else if (!_command &&
        key == LogicalKeyboardKey.keyR &&
        (_tool == _Tool.pen || _tool == _Tool.highlighter)) {
      setState(() => _rulerMode = !_rulerMode);
    } else if (!_command &&
        key == LogicalKeyboardKey.keyK &&
        (_tool == _Tool.pen || _tool == _Tool.highlighter)) {
      setState(() => _autoRecognizeInk = !_autoRecognizeInk);
    } else if ({
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
    }.contains(key)) {
      final amount = _shift ? 10.0 : 1.0;
      final delta = CanvasPoint(
        key == LogicalKeyboardKey.arrowLeft
            ? -amount
            : key == LogicalKeyboardKey.arrowRight
            ? amount
            : 0,
        key == LogicalKeyboardKey.arrowUp
            ? -amount
            : key == LogicalKeyboardKey.arrowDown
            ? amount
            : 0,
      );
      for (final id in _selection) {
        final element = _scene[id];
        if (element != null && !element.locked) {
          _history.put(element.translated(delta));
        }
      }
      _commit();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _zoom(double factor) {
    setState(() {
      _camera = _camera.zoomAt(
        CanvasPoint(_viewport.width / 2, _viewport.height / 2),
        factor,
      );
    });
    _cameraChanged();
  }

  void _onMinimapTap(Offset localPos, Size minimapSize) {
    final (contentRect, scale, offsetX, offsetY) = CanvasMinimapPainter.layout(
      _scene,
      _camera,
      _viewport,
      minimapSize,
    );
    final clampedX = scale > 0
        ? localPos.dx.clamp(offsetX, offsetX + contentRect.width * scale)
        : localPos.dx;
    final clampedY = scale > 0
        ? localPos.dy.clamp(offsetY, offsetY + contentRect.height * scale)
        : localPos.dy;
    final worldX = scale > 0
        ? contentRect.left + (clampedX - offsetX) / scale
        : contentRect.left;
    final worldY = scale > 0
        ? contentRect.top + (clampedY - offsetY) / scale
        : contentRect.top;
    setState(() {
      _camera = CanvasCamera(
        x: worldX - (_viewport.width / _camera.zoom) / 2,
        y: worldY - (_viewport.height / _camera.zoom) / 2,
        zoom: _camera.zoom,
      );
    });
    _cameraChanged();
  }

  void _fit({bool selectionOnly = false}) {
    CanvasBounds? bounds;
    if (selectionOnly) {
      for (final id in _selection) {
        final element = _scene[id];
        final b = element == null
            ? null
            : isConnectorElement(element)
            ? resolveConnectorEndpoints(element, _scene).bounds
            : element.bounds;
        if (b != null) bounds = bounds?.union(b) ?? b;
      }
    } else {
      bounds = _scene.contentBounds;
    }
    if (bounds == null) {
      setState(() {
        _camera = const CanvasCamera();
      });
    } else {
      final zoom = math
          .min(
            (_viewport.width - 100) / math.max(1, bounds.width),
            (_viewport.height - 100) / math.max(1, bounds.height),
          )
          .clamp(.1, 2.0);
      setState(() {
        _camera = CanvasCamera(
          x: bounds!.center.x - _viewport.width / zoom / 2,
          y: bounds.center.y - _viewport.height / zoom / 2,
          zoom: zoom,
        );
      });
    }
    _cameraChanged();
  }

  Future<void> _chooseObject({CanvasPoint? at}) async {
    if (_readOnly) return;
    _finishText();
    final owner = widget.canvasId, scene = _scene, revision = _scene.revision;
    final epoch = _interactionEpoch;
    if (widget.onPickReference != null) {
      final selected = await widget.onPickReference!();
      if (!mounted ||
          selected == null ||
          _readOnly ||
          widget.canvasId != owner ||
          epoch != _interactionEpoch ||
          !identical(_scene, scene) ||
          _scene.revision != revision) {
        return;
      }
      final target = _objects[selected.id];
      if (target == null) {
        _notice('The source is unavailable. No placement was added.');
        return;
      }
      final center =
          at ??
          _camera.toWorld(
            CanvasPoint(_viewport.width / 2, _viewport.height / 2),
          );
      final element = CanvasElement({
        'id': _id(),
        'type': 'card',
        'objectId': target.id,
        'referenceTarget': selected.target,
        'presentation': 'preview',
        'x': center.x - 140,
        'y': center.y - 95,
        'width': 280.0,
        'height': 190.0,
        'color': _color,
      });
      _history.put(element);
      _selection
        ..clear()
        ..add(element.id);
      _commit();
      _focus.requestFocus();
      return;
    }
    final query = TextEditingController();
    final selected = await showDialog<CanvasObjectReference>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          final queryLower = query.text.toLowerCase().trim();
          final results = widget.objects
              .where(
                (o) =>
                    o.id != widget.canvasId &&
                    (queryLower.isEmpty ||
                        o.title.toLowerCase().contains(queryLower) ||
                        o.typeId.toLowerCase().contains(queryLower) ||
                        (o.properties['pdfSource'] is Map &&
                            ((o.properties['pdfSource'] as Map)['quote']
                                is String) &&
                            ((o.properties['pdfSource'] as Map)['quote']
                                    as String)
                                .toLowerCase()
                                .contains(queryLower))),
              )
              .toList();
          return OrbitDialog(
            title: const Text('Place an object'),
            content: SizedBox(
              width: 440,
              height: 380,
              child: Column(
                children: [
                  TextField(
                    controller: query,
                    autofocus: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Find a note, task, PDF highlight or file',
                    ),
                    onChanged: (_) => update(() {}),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: results.isEmpty
                        ? const Center(
                            child: Text(
                              'No matching objects. Create a note, task, or PDF highlight first.',
                            ),
                          )
                        : ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                              final object = results[index];
                              final isPdfHighlight =
                                  object.properties['pdfSource'] is Map;
                              final isTask = object.typeId == 'orbit.task';
                              final isFile = object.typeId == 'orbit.file';
                              final icon = isPdfHighlight
                                  ? Icons.picture_as_pdf_outlined
                                  : (isTask
                                        ? Icons.check_circle_outline
                                        : (isFile
                                              ? Icons.attach_file
                                              : Icons.link));
                              final subtitle = isPdfHighlight
                                  ? 'PDF Highlight · Page ${(object.properties['pdfSource'] as Map)['page'] ?? 1}'
                                  : (isTask
                                        ? 'Task'
                                        : (isFile
                                              ? 'Attachment'
                                              : object.typeId.replaceFirst(
                                                  'orbit.',
                                                  '',
                                                )));
                              return ListTile(
                                leading: Icon(icon, size: 20),
                                title: Text(
                                  object.title.isEmpty
                                      ? 'Untitled'
                                      : object.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(subtitle),
                                onTap: () => Navigator.pop(context, object),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
    // Dialog route transitions may still use the controller after the Future completes.
    WidgetsBinding.instance.addPostFrameCallback((_) => query.dispose());
    if (!mounted ||
        selected == null ||
        _readOnly ||
        widget.canvasId != owner ||
        epoch != _interactionEpoch ||
        !identical(_scene, scene) ||
        _scene.revision != revision) {
      return;
    }
    final center =
        at ??
        _camera.toWorld(CanvasPoint(_viewport.width / 2, _viewport.height / 2));
    final element = CanvasElement({
      'id': _id(),
      'type': 'card',
      'objectId': selected.id,
      'x': center.x - 140,
      'y': center.y - 95,
      'width': 280.0,
      'height': 190.0,
      'color': _color,
    });
    _history.put(element);
    _selection
      ..clear()
      ..add(element.id);
    _commit();
    _focus.requestFocus();
  }

  IconData _iconForElement(CanvasElement element) {
    if (element.type == 'ink') {
      return element.data['isHighlighter'] == true
          ? Icons.brush_outlined
          : Icons.draw_outlined;
    }
    return switch (element.type) {
      'sticky' => Icons.sticky_note_2_outlined,
      'card' => Icons.dashboard_outlined,
      'text' => Icons.title,
      'rectangle' => Icons.crop_square,
      'ellipse' => Icons.circle_outlined,
      'diamond' => Icons.diamond_outlined,
      'arrow' => Icons.arrow_right_alt,
      'line' => Icons.horizontal_rule,
      'connector' => Icons.timeline,
      'column' => Icons.view_column_outlined,
      'frame' => Icons.filter_frames_outlined,
      'image' => Icons.image_outlined,
      'link' => Icons.link,
      'section' => Icons.view_agenda_outlined,
      'audio' => Icons.mic_outlined,
      _ => Icons.widgets_outlined,
    };
  }

  String _labelForElement(CanvasElement element) {
    if (element.type == 'card') {
      return _objects[element.objectId]?.title ??
          (element.text.trim().isNotEmpty
              ? element.text.trim().split('\n').first.trim()
              : (element.objectId != null ? 'Missing object' : 'Card'));
    }
    if (element.type == 'ink') {
      return element.data['isHighlighter'] == true
          ? 'Highlighter stroke'
          : 'Pen stroke';
    }
    if (element.text.trim().isNotEmpty) {
      return element.text.trim().split('\n').first.trim();
    }
    return switch (element.type) {
      'rectangle' => 'Rectangle',
      'ellipse' => 'Ellipse',
      'diamond' => 'Diamond',
      'arrow' => 'Arrow',
      'line' => 'Line',
      'connector' => 'Connector',
      'column' => 'Column',
      'frame' => 'Frame',
      'image' => 'Image',
      'link' => 'Link',
      'audio' => 'Voice Memo',
      _ => element.type,
    };
  }

  Future<void> _showElementList() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final elements = _scene.elementsInOrder.reversed.toList();
          final hasItems = elements.isNotEmpty;
          return OrbitDialog(
            title: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.layers_outlined, size: 20),
                const Text('Layers & Stacking Order'),
                if (hasItems)
                  Text(
                    '${elements.length} ${elements.length == 1 ? "layer" : "layers"}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: Theme.of(
                        dialogContext,
                      ).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            contentSlivers: [
              if (!hasItems)
                const SliverToBoxAdapter(
                  child: Text('This Canvas has no elements.'),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Top (Front) to Bottom (Back)',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(
                                  dialogContext,
                                ).colorScheme.outline,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.vertical_align_top,
                                size: 18,
                              ),
                              tooltip: 'Bring to Front',
                              visualDensity: VisualDensity.compact,
                              onPressed: _selection.isEmpty || _readOnly
                                  ? null
                                  : () {
                                      _reorder('front');
                                      setDialogState(() {});
                                    },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.vertical_align_bottom,
                                size: 18,
                              ),
                              tooltip: 'Send to Back',
                              visualDensity: VisualDensity.compact,
                              onPressed: _selection.isEmpty || _readOnly
                                  ? null
                                  : () {
                                      _reorder('back');
                                      setDialogState(() {});
                                    },
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                  ),
                ),
                SliverList.separated(
                  itemCount: elements.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 44),
                  itemBuilder: (ctx, index) {
                    final element = elements[index];
                    final isSelected = _selection.contains(element.id);
                    final accentColor = Color(element.color);

                    return OrbitActionTile(
                      dense: true,
                      selected: isSelected,
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(_iconForElement(element), size: 18),
                        ],
                      ),
                      title: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _labelForElement(element),
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: element.hidden
                                  ? Theme.of(dialogContext).colorScheme.outline
                                  : null,
                            ),
                          ),
                          if (element.groupId != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(dialogContext)
                                      .colorScheme
                                      .primaryContainer
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Group',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      dialogContext,
                                    ).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ),
                          if (element.hidden)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                'Hidden',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                  color: Theme.of(
                                    dialogContext,
                                  ).colorScheme.outline,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        '${element.type} • z: ${_scene.orderOf(element.id) ?? 0}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.arrow_upward, size: 16),
                          tooltip: 'Bring Forward',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          onPressed: index == 0 || _readOnly
                              ? null
                              : () {
                                  _history.reorder([element.id], () {
                                    _scene.bringForward(element.id);
                                  });
                                  _commit();
                                  setDialogState(() {});
                                },
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_downward, size: 16),
                          tooltip: 'Send Backward',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          onPressed: index == elements.length - 1 || _readOnly
                              ? null
                              : () {
                                  _history.reorder([element.id], () {
                                    _scene.sendBackward(element.id);
                                  });
                                  _commit();
                                  setDialogState(() {});
                                },
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(
                            element.locked
                                ? Icons.lock
                                : Icons.lock_open_outlined,
                            size: 16,
                            color: element.locked
                                ? Theme.of(dialogContext).colorScheme.error
                                : null,
                          ),
                          tooltip: element.locked
                              ? 'Unlock layer'
                              : 'Lock layer',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          onPressed: _readOnly
                              ? null
                              : () {
                                  _history.put(
                                    element.copy({'locked': !element.locked}),
                                  );
                                  _commit();
                                  setDialogState(() {});
                                },
                        ),
                        IconButton(
                          icon: Icon(
                            element.hidden
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 16,
                            color: element.hidden
                                ? Theme.of(dialogContext).colorScheme.outline
                                : null,
                          ),
                          tooltip: element.hidden ? 'Show layer' : 'Hide layer',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          onPressed: _readOnly
                              ? null
                              : () {
                                  _history.put(
                                    element.copy({'hidden': !element.hidden}),
                                  );
                                  _commit();
                                  setDialogState(() {});
                                },
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(
                            Icons.center_focus_strong_outlined,
                            size: 16,
                          ),
                          tooltip: 'Focus on canvas',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            setState(() {
                              _selection
                                ..clear()
                                ..add(element.id);
                            });
                            _fit(selectionOnly: true);
                            _focus.requestFocus();
                          },
                        ),
                      ],
                      onTap: () {
                        setState(() {
                          _selection
                            ..clear()
                            ..add(element.id);
                        });
                        setDialogState(() {});
                        _fit(selectionOnly: true);
                        _focus.requestFocus();
                      },
                    );
                  },
                ),
              ],
            ],
            actions: [
              if (hasItems && !_readOnly) ...[
                TextButton(
                  onPressed: () {
                    for (final el in _scene.elements) {
                      if (el.hidden) {
                        _history.put(el.copy({'hidden': false}));
                      }
                    }
                    _commit();
                    setDialogState(() {});
                  },
                  child: const Text('Show All'),
                ),
                TextButton(
                  onPressed: () {
                    for (final el in _scene.elements) {
                      if (el.locked) {
                        _history.put(el.copy({'locked': false}));
                      }
                    }
                    _commit();
                    setDialogState(() {});
                  },
                  child: const Text('Unlock All'),
                ),
              ],
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showImportDialog() async {
    if (_readOnly) return;
    _finishText();

    final center = _camera.toWorld(
      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
    );

    final result = await CanvasImportDialog.show(
      context,
      center: center,
      idGenerator: _id,
    );

    if (result == null || result.elements.isEmpty || !mounted) return;

    for (final element in result.elements) {
      _history.put(element);
    }
    _commit();

    setState(() {
      _selection
        ..clear()
        ..addAll(result.elementIds);
    });

    _notice(result.summary);
  }

  Future<void> _showExportDialog({bool selectionOnly = false}) async {
    final hasSelection = _selection.isNotEmpty;
    var scopeSelection = selectionOnly && hasSelection;
    var format = 'png';
    var transparent = false;
    var scale = 2.0;
    var svgScale = 1.0;
    var mermaidDirection = 'TD';
    var mermaidWrapMarkdown = false;
    var isExporting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            CanvasBounds exportBounds;
            final targetIds = scopeSelection ? _selection : null;
            if (targetIds != null && targetIds.isNotEmpty) {
              CanvasBounds? unionBounds;
              for (final id in targetIds) {
                final elem = _scene[id];
                if (elem != null) {
                  unionBounds = unionBounds?.union(elem.bounds) ?? elem.bounds;
                }
              }
              exportBounds = (unionBounds ?? const CanvasBounds(0, 0, 800, 600))
                  .inflate(40);
            } else {
              exportBounds =
                  (_scene.contentBounds ?? const CanvasBounds(0, 0, 800, 600))
                      .inflate(40);
            }

            final pxWidth =
                (exportBounds.width * (format == 'png' ? scale : 1.0)).round();
            final pxHeight =
                (exportBounds.height * (format == 'png' ? scale : 1.0)).round();
            final colors = Theme.of(dialogContext).colorScheme;

            return OrbitDialog(
              title: const Row(
                children: [
                  Icon(Icons.file_download_outlined, size: 20),
                  SizedBox(width: 8),
                  Text('Export Canvas'),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SCOPE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: Center(
                                child: Text('Full Canvas (${_scene.length})'),
                              ),
                              selected: !scopeSelection,
                              onSelected: (selected) {
                                if (selected) {
                                  setDialogState(() => scopeSelection = false);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: Center(
                                child: Text('Selection (${_selection.length})'),
                              ),
                              selected: scopeSelection,
                              onSelected: hasSelection
                                  ? (selected) {
                                      if (selected) {
                                        setDialogState(
                                          () => scopeSelection = true,
                                        );
                                      }
                                    }
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'FORMAT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('PNG Image'),
                            selected: format == 'png',
                            onSelected: (selected) {
                              if (selected) {
                                setDialogState(() => format = 'png');
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Vector SVG'),
                            selected: format == 'svg',
                            onSelected: (selected) {
                              if (selected) {
                                setDialogState(() => format = 'svg');
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Mermaid (.mmd)'),
                            selected: format == 'mermaid',
                            onSelected: (selected) {
                              if (selected) {
                                setDialogState(() => format = 'mermaid');
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('JSON Backup'),
                            selected: format == 'json',
                            onSelected: (selected) {
                              if (selected) {
                                setDialogState(() => format = 'json');
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (format == 'mermaid') ...[
                        if (_scene.elements.any(isUmlClass))
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'This export produces a flowchart. Use SVG for UML appearance or Canvas JSON for editable class members and relationships.',
                            ),
                          ),
                        const Text(
                          'MERMAID OPTIONS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            const Text(
                              'Flow Direction:',
                              style: TextStyle(fontSize: 13),
                            ),
                            SegmentedButton<String>(
                              style: const ButtonStyle(
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              segments: const [
                                ButtonSegment(value: 'TD', label: Text('TD')),
                                ButtonSegment(value: 'LR', label: Text('LR')),
                                ButtonSegment(value: 'BT', label: Text('BT')),
                                ButtonSegment(value: 'RL', label: Text('RL')),
                              ],
                              selected: {mermaidDirection},
                              onSelectionChanged: (newSelection) {
                                setDialogState(
                                  () => mermaidDirection = newSelection.first,
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Markdown Code Block'),
                          subtitle: const Text(
                            'Wrap in ```mermaid block for notes and markdown files',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: mermaidWrapMarkdown,
                          onChanged: (val) {
                            setDialogState(() => mermaidWrapMarkdown = val);
                          },
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'PREVIEW',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 140),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest.withValues(
                              alpha: 0.45,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colors.outlineVariant.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              exportToMermaid(
                                _scene,
                                elementIds: targetIds,
                                direction: mermaidDirection,
                                wrapMarkdownFence: mermaidWrapMarkdown,
                              ),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ),
                      ] else if (format != 'json') ...[
                        const Text(
                          'OPTIONS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Transparent Background'),
                          subtitle: Text(
                            transparent
                                ? 'Export with transparent background'
                                : 'Include canvas $_backgroundStyle background',
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: transparent,
                          onChanged: (val) {
                            setDialogState(() => transparent = val);
                          },
                        ),
                        if (format == 'png') ...[
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              const Text(
                                'Resolution Scale:',
                                style: TextStyle(fontSize: 13),
                              ),
                              SegmentedButton<double>(
                                style: const ButtonStyle(
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                segments: const [
                                  ButtonSegment(value: 1.0, label: Text('1x')),
                                  ButtonSegment(value: 2.0, label: Text('2x')),
                                  ButtonSegment(value: 3.0, label: Text('3x')),
                                  ButtonSegment(value: 4.0, label: Text('4x')),
                                ],
                                selected: {scale},
                                onSelectionChanged: (newSelection) {
                                  setDialogState(
                                    () => scale = newSelection.first,
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHighest.withValues(
                                alpha: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.aspect_ratio, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Output dimensions: $pxWidth × $pxHeight px',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ] else if (format == 'svg') ...[
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              const Text(
                                'Vector Scale:',
                                style: TextStyle(fontSize: 13),
                              ),
                              SegmentedButton<double>(
                                style: const ButtonStyle(
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                segments: const [
                                  ButtonSegment(value: 1.0, label: Text('1x')),
                                  ButtonSegment(value: 2.0, label: Text('2x')),
                                  ButtonSegment(value: 4.0, label: Text('4x')),
                                ],
                                selected: {svgScale},
                                onSelectionChanged: (newSelection) {
                                  setDialogState(
                                    () => svgScale = newSelection.first,
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isExporting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF pages…'),
                  onPressed: isExporting
                      ? null
                      : () {
                          final now = DateTime.now().toUtc();
                          final captured = UniversalObject(
                            id: widget.canvasId,
                            workspaceId: 'pdf-snapshot',
                            typeId: 'orbit.canvas',
                            title: widget.title,
                            createdAt: now,
                            updatedAt: now,
                            data: {
                              ..._scene.toJson(),
                              if (scopeSelection)
                                'elements': [
                                  for (final e in _scene.elementsInOrder)
                                    if (_selection.contains(e.id)) e.data,
                                ],
                              'backgroundStyle': _backgroundStyle,
                            },
                          );
                          final sources = [
                            captured,
                            for (final o in widget.objects.where(
                              (o) => o.id != widget.canvasId,
                            ))
                              UniversalObject(
                                id: o.id,
                                workspaceId: 'pdf-snapshot',
                                typeId: o.typeId,
                                title: o.title,
                                body: o.body,
                                properties: o.properties,
                                createdAt: now,
                                updatedAt: now,
                              ),
                          ];
                          Navigator.pop(dialogContext);
                          showPdfBundleDialog(
                            context,
                            objects: sources,
                            initialCanvasId: captured.id,
                            readImage: widget.imageLoader,
                          );
                        },
                ),
                if (format == 'svg' || format == 'json' || format == 'mermaid')
                  TextButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy to Clipboard'),
                    onPressed: isExporting
                        ? null
                        : () async {
                            final targetIds = scopeSelection
                                ? _selection
                                : null;
                            if (format == 'mermaid') {
                              final mermaid = exportToMermaid(
                                _scene,
                                elementIds: targetIds,
                                direction: mermaidDirection,
                                wrapMarkdownFence: mermaidWrapMarkdown,
                              );
                              await Clipboard.setData(
                                ClipboardData(text: mermaid),
                              );
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Mermaid flowchart copied to clipboard',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            } else if (format == 'svg') {
                              final svg = canvasToSvg(
                                _scene,
                                transparent: transparent,
                                backgroundColor: colors.surface.toARGB32(),
                                foregroundColor: colors.onSurface.toARGB32(),
                                backgroundStyle: _backgroundStyle,
                                elementIds: targetIds,
                                scale: svgScale,
                              );
                              await Clipboard.setData(ClipboardData(text: svg));
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('SVG copied to clipboard'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            } else {
                              final jsonMap = {
                                ..._scene.toJson(),
                                'backgroundStyle': _backgroundStyle,
                              };
                              final jsonString = const JsonEncoder.withIndent(
                                '  ',
                              ).convert(jsonMap);
                              await Clipboard.setData(
                                ClipboardData(text: jsonString),
                              );
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Canvas JSON copied to clipboard',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          },
                  ),
                FilledButton.icon(
                  icon: isExporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_alt, size: 18),
                  label: Text(isExporting ? 'Exporting...' : 'Save File'),
                  onPressed: isExporting
                      ? null
                      : () async {
                          setDialogState(() => isExporting = true);
                          try {
                            final targetIds = scopeSelection
                                ? _selection
                                : null;
                            final baseName =
                                widget.data['title'] is String &&
                                    (widget.data['title'] as String).isNotEmpty
                                ? widget.data['title'] as String
                                : 'canvas';
                            final sanitized = baseName.replaceAll(
                              RegExp(r'[\\/:*?"<>|]'),
                              '_',
                            );

                            if (format == 'png') {
                              final bytes = await renderCanvasToPng(
                                semanticColors: OrbitColors.of(context),
                                scene: _scene,
                                colors: colors,
                                backgroundStyle: _backgroundStyle,
                                elementIds: targetIds,
                                scale: scale,
                                transparent: transparent,
                                images: _images?.images ?? const {},
                                objects: _objects,
                              );
                              if (bytes != null) {
                                await exportBinaryFile(
                                  '$sanitized.png',
                                  bytes,
                                  mimeType: 'image/png',
                                );
                              }
                            } else if (format == 'svg') {
                              final svg = canvasToSvg(
                                _scene,
                                transparent: transparent,
                                backgroundColor: colors.surface.toARGB32(),
                                foregroundColor: colors.onSurface.toARGB32(),
                                backgroundStyle: _backgroundStyle,
                                elementIds: targetIds,
                                scale: svgScale,
                              );
                              await exportFile(
                                '$sanitized.svg',
                                svg,
                                mimeType: 'image/svg+xml',
                              );
                            } else if (format == 'mermaid') {
                              final mermaid = exportToMermaid(
                                _scene,
                                elementIds: targetIds,
                                direction: mermaidDirection,
                                wrapMarkdownFence: mermaidWrapMarkdown,
                              );
                              await exportFile(
                                '$sanitized.mmd',
                                mermaid,
                                mimeType: 'text/vnd.mermaid',
                              );
                            } else {
                              final jsonMap = {
                                ..._scene.toJson(),
                                'backgroundStyle': _backgroundStyle,
                              };
                              final jsonString = const JsonEncoder.withIndent(
                                '  ',
                              ).convert(jsonMap);
                              await exportFile(
                                '$sanitized.canvas.json',
                                jsonString,
                                mimeType: 'application/json',
                              );
                            }
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } finally {
                            if (dialogContext.mounted) {
                              setDialogState(() => isExporting = false);
                            }
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _contextMenu(PointerDownEvent event) async {
    final epoch = _interactionEpoch, scene = _scene, revision = _scene.revision;
    final worldPos = _world(event.localPosition);
    final hit = _scene.hit(worldPos, tolerance: 6 / _camera.zoom);
    final target =
        hit ??
        _scene.elements
            .toList()
            .reversed
            .where(
              (element) =>
                  (element.type == 'column' || element.type == 'frame') &&
                  element.renderable &&
                  !element.hidden &&
                  element.bounds.contains(worldPos),
            )
            .firstOrNull;
    if (target != null && !_selection.contains(target.id)) {
      setState(() {
        _selection
          ..clear()
          ..add(target.id);
      });
    }
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;

    final selection = {..._selection};
    bool current() =>
        mounted &&
        epoch == _interactionEpoch &&
        identical(scene, _scene) &&
        revision == _scene.revision &&
        setEquals(selection, _selection);
    if (hit == null) {
      final hasSelection = _selection.isNotEmpty;
      final action = await showMenu<String>(
        context: context,
        position: RelativeRect.fromRect(
          Rect.fromLTWH(event.position.dx, event.position.dy, 1, 1),
          Offset.zero & overlay.size,
        ),
        items: [
          if (hasSelection && !_readOnly) ...[
            PopupMenuItem(
              value: 'delete',
              enabled: _selection.any((id) => _scene[id]?.locked == false),
              child: const Row(
                children: [
                  Icon(Icons.delete_outline, size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text('Remove from canvas')),
                ],
              ),
            ),
            const PopupMenuDivider(),
          ],
          if (!_readOnly) ...[
            const PopupMenuItem(
              value: 'add_uml',
              child: Text('New UML class…'),
            ),
            const PopupMenuItem(
              value: 'connect_uml',
              child: Text('Connect UML classes…'),
            ),
            const PopupMenuItem(
              value: 'interaction_tools',
              child: Text('Use-case & sequence diagrams…'),
            ),
            const PopupMenuItem(
              value: 'add_text',
              child: Row(
                children: [
                  Icon(Icons.title, size: 16),
                  SizedBox(width: 8),
                  Text('Add Text'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'add_sticky',
              child: Row(
                children: [
                  Icon(Icons.sticky_note_2_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('Add Sticky'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'brainstorm_bulk',
              child: Text('Bulk sticky notes…'),
            ),
            const PopupMenuItem(
              value: 'brainstorm_workshop',
              child: Text('Workshop timer & voting…'),
            ),
            const PopupMenuItem(
              value: 'add_checklist',
              child: Row(
                children: [
                  Icon(Icons.checklist_rounded, size: 16),
                  SizedBox(width: 8),
                  Text('Add Checklist'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'add_formula',
              child: Row(
                children: [
                  Icon(Icons.functions, size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text('Add Formula / Math Note')),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'add_math_lab',
              child: Text('Math Lab · calculate & plot'),
            ),
            const PopupMenuItem(
              value: 'add_section',
              child: Row(
                children: [
                  Icon(Icons.view_agenda_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('Add Section'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'add_swatch',
              child: Row(
                children: [
                  Icon(Icons.palette_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('Add Color Swatch'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'add_card',
              child: Row(
                children: [
                  Icon(Icons.dashboard_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('Add Card'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'starter_library',
              child: Text('Add from template library…'),
            ),
            const PopupMenuItem(
              value: 'place_object',
              child: Row(
                children: [
                  Icon(Icons.add_link, size: 16),
                  SizedBox(width: 8),
                  Text('Place object'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'add_dynamic_view',
              child: Row(
                children: [
                  Icon(Icons.saved_search_outlined, size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text('Add Dynamic View...')),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'paste',
              child: Row(
                children: [
                  Icon(Icons.paste_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('Paste'),
                ],
              ),
            ),
            const PopupMenuDivider(),
          ],
          const PopupMenuItem(
            value: 'fit_all',
            child: Row(
              children: [
                Icon(Icons.crop_free, size: 16),
                SizedBox(width: 8),
                Text('Fit All'),
              ],
            ),
          ),
          if (hasSelection)
            const PopupMenuItem(
              value: 'fit_selection',
              child: Row(
                children: [
                  Icon(Icons.filter_center_focus, size: 16),
                  SizedBox(width: 8),
                  Text('Fit Selection'),
                ],
              ),
            ),
          const PopupMenuItem(
            value: 'zoom_100',
            child: Row(
              children: [
                Icon(Icons.zoom_in, size: 16),
                SizedBox(width: 8),
                Text('100% Zoom'),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'import_diagram',
            child: Row(
              children: [
                Icon(Icons.file_upload_outlined, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Import Diagrams & Content...')),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'export_canvas',
            child: Text('Export Canvas...'),
          ),
        ],
      );
      if (!current() || action == null) return;
      switch (action) {
        case 'add_uml':
          _editUml(at: worldPos);
        case 'connect_uml':
          _editUml(relationship: true);
        case 'interaction_tools':
          _showInteractionTools(at: worldPos);
        case 'add_text':
          _addText(at: worldPos);
        case 'add_sticky':
          _addSticky(at: worldPos);
        case 'brainstorm_bulk':
          _brainstormAction('bulk');
        case 'brainstorm_workshop':
          _brainstormAction('workshop');
        case 'add_checklist':
          _addChecklist(at: worldPos);
        case 'add_math_lab':
          _addMathLab(at: worldPos);
          break;
        case 'add_formula':
          _addFormulaCard(at: worldPos);
        case 'add_section':
          _addSection(at: worldPos);
        case 'add_swatch':
          _addSwatch(at: worldPos);
        case 'starter_library':
          _showStarterLibrary();
        case 'add_card':
          _addCard(at: worldPos);
        case 'place_object':
          _chooseObject(at: worldPos);
        case 'add_dynamic_view':
          _addDynamicView(at: worldPos);
        case 'paste':
          _paste(at: worldPos);
        case 'delete':
          _delete();
        case 'fit_all':
          _fit();
        case 'fit_selection':
          _fit(selectionOnly: true);
        case 'zoom_100':
          _zoom(1 / _camera.zoom);
        case 'import_diagram':
          _showImportDialog();
        case 'export_canvas':
          _showExportDialog();
      }
      return;
    }

    final selElem = _selection.length == 1 ? _scene[_selection.first] : null;
    final isConnector =
        selElem != null &&
        (selElem.type == 'arrow' ||
            selElem.type == 'line' ||
            selElem.type == 'connector');
    final hasInk = _selection.any((id) => _scene[id]?.type == 'ink');

    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(event.position.dx, event.position.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        if (_selection.length == 1)
          const PopupMenuItem(value: 'edit', child: Text('Open / edit')),
        if (_selection.length == 1)
          const PopupMenuItem(
            value: 'copy_element_reference',
            child: Text('Copy Canvas element reference'),
          ),
        if (selElem?.type == 'card' &&
            selElem?.objectId != null &&
            _objects.containsKey(selElem!.objectId) &&
            !_readOnly)
          const PopupMenuItem(
            value: 'edit_transclusion_content',
            child: Row(
              children: [
                Icon(Icons.edit_note, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Edit Transcluded Note Content...')),
              ],
            ),
          ),
        if (selElem?.type == 'card' && !_readOnly) ...[
          PopupMenuItem(
            value: 'edit_reference',
            enabled: selElem?.locked != true,
            child: const Text('Edit reference details…'),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            enabled: false,
            height: 24,
            child: Text(
              'CARD PRESENTATION (CAN-03)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const PopupMenuItem(
            value: 'pres_compact',
            child: Row(
              children: [
                Icon(Icons.view_compact_outlined, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Compact (Pill / Single Line)')),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'pres_card',
            child: Row(
              children: [
                Icon(Icons.dashboard_outlined, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Standard Card')),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'pres_preview',
            child: Row(
              children: [
                Icon(Icons.preview_outlined, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Expanded Preview (Thumbnails & Lists)')),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'pres_transclusion',
            child: Row(
              children: [
                Icon(Icons.sync_alt, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Live Note Transclusion (CAN-02/NOTE-07)'),
                ),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'pres_properties',
            child: Row(
              children: [
                Icon(Icons.list_alt_outlined, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Selected Properties Table')),
              ],
            ),
          ),
        ],
        if ((selElem?.type == 'text' ||
                selElem?.type == 'sticky' ||
                selElem?.type == 'card') &&
            !_readOnly) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            enabled: false,
            height: 24,
            child: Text(
              'FONT FAMILY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const PopupMenuItem(
            value: 'font_default',
            child: Row(
              children: [
                Icon(Icons.font_download_outlined, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Default Font (Segoe UI)')),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'font_times_new_roman',
            child: Row(
              children: [
                Icon(Icons.format_italic, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Times New Roman (Serif)',
                    style: TextStyle(fontFamily: 'Times New Roman'),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (selElem?.type == 'section' && !_readOnly) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            enabled: false,
            height: 24,
            child: Text(
              'SECTION HEADER SIZE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const PopupMenuItem(
            value: 'section_size_small',
            child: Row(
              children: [
                Icon(Icons.text_fields, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Small (13px)')),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'section_size_medium',
            child: Row(
              children: [
                Icon(Icons.text_fields, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text('Medium (18px)')),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'section_size_large',
            child: Row(
              children: [
                Icon(Icons.title, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Large (24px)')),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'section_size_xlarge',
            child: Row(
              children: [
                Icon(Icons.title, size: 22),
                SizedBox(width: 8),
                Expanded(child: Text('Extra Large (32px)')),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'section_size_huge',
            child: Row(
              children: [
                Icon(Icons.title, size: 24),
                SizedBox(width: 8),
                Expanded(child: Text('Huge (42px)')),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            enabled: false,
            height: 24,
            child: Text(
              'LINE THICKNESS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const PopupMenuItem(
            value: 'section_line_hairline',
            child: Row(
              children: [
                Icon(Icons.horizontal_rule, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Hairline (1.0px)')),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'section_line_standard',
            child: Row(
              children: [
                Icon(Icons.horizontal_rule, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text('Standard (1.5px)')),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'section_line_medium',
            child: Row(
              children: [
                Icon(Icons.horizontal_rule, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Medium (2.5px)')),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'section_line_thick',
            child: Row(
              children: [
                Icon(Icons.horizontal_rule, size: 22),
                SizedBox(width: 8),
                Expanded(child: Text('Thick (4.0px)')),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'section_line_heavy',
            child: Row(
              children: [
                Icon(Icons.horizontal_rule, size: 24),
                SizedBox(width: 8),
                Expanded(child: Text('Heavy (6.0px)')),
              ],
            ),
          ),
        ],
        if (isConnector && !_readOnly) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            enabled: false,
            height: 24,
            child: Text(
              'CONNECTOR STYLE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const PopupMenuItem(
            value: 'stroke_solid',
            child: Text('Solid Stroke'),
          ),
          const PopupMenuItem(
            value: 'stroke_dashed',
            child: Text('Dashed Stroke'),
          ),
          const PopupMenuItem(
            value: 'stroke_dotted',
            child: Text('Dotted Stroke'),
          ),
          const PopupMenuItem(
            value: 'routing_straight',
            child: Text('Straight Line'),
          ),
          const PopupMenuItem(
            value: 'routing_curved',
            child: Text('Curved Line'),
          ),
          const PopupMenuItem(
            value: 'routing_orthogonal',
            child: Text('Orthogonal Line'),
          ),
          const PopupMenuItem(
            value: 'marker_start_arrow',
            child: Text('Arrowhead Start'),
          ),
          const PopupMenuItem(
            value: 'marker_start_dot',
            child: Text('Dot Start'),
          ),
          const PopupMenuItem(
            value: 'marker_start_diamond',
            child: Text('Diamond Start'),
          ),
          const PopupMenuItem(
            value: 'marker_start_none',
            child: Text('No Start Marker'),
          ),
          const PopupMenuItem(
            value: 'marker_arrow',
            child: Text('Arrowhead End'),
          ),
          const PopupMenuItem(value: 'marker_dot', child: Text('Dot End')),
          const PopupMenuItem(
            value: 'marker_diamond',
            child: Text('Diamond End'),
          ),
          const PopupMenuItem(
            value: 'marker_none',
            child: Text('No End Marker'),
          ),
          const PopupMenuItem(
            value: 'anchor_start_auto',
            child: Text('Start Anchor: Auto'),
          ),
          const PopupMenuItem(
            value: 'anchor_end_auto',
            child: Text('End Anchor: Auto'),
          ),
          const PopupMenuItem(
            value: 'reverse_direction',
            child: Text('Reverse Direction'),
          ),
        ],
        if (_selection.isNotEmpty)
          if (widget.onShowObjectConnections != null &&
              _selection.length == 1 &&
              _scene[_selection.first]?.objectId != null)
            const PopupMenuItem(
              value: 'connections',
              child: Text('Object connections'),
            ),
        const PopupMenuItem(value: 'copy', child: Text('Copy placements')),
        if (_selection.isNotEmpty && !_readOnly)
          PopupMenuItem(
            value: 'duplicate',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Duplicate'),
                SizedBox(width: 16),
                Text(
                  'Ctrl+D',
                  style: TextStyle(
                    fontSize: 11,
                    color: OrbitColors.of(context).muted,
                  ),
                ),
              ],
            ),
          ),
        const PopupMenuItem(value: 'paste', child: Text('Paste')),
        if (_selection.isNotEmpty && !_readOnly) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            enabled: false,
            height: 24,
            child: Text(
              'LAYER ORDER',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const PopupMenuItem(
            value: 'bring_to_front',
            child: Text('Bring to Front'),
          ),
          const PopupMenuItem(
            value: 'bring_forward',
            child: Text('Bring Forward'),
          ),
          const PopupMenuItem(
            value: 'send_backward',
            child: Text('Send Backward'),
          ),
          const PopupMenuItem(
            value: 'send_to_back',
            child: Text('Send to Back'),
          ),
        ],
        if (_selection.length >= 2 && !_readOnly) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            enabled: false,
            height: 24,
            child: Text(
              'ALIGNMENT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const PopupMenuItem(value: 'align_left', child: Text('Align Left')),
          const PopupMenuItem(
            value: 'align_center_h',
            child: Text('Horizontal Center'),
          ),
          const PopupMenuItem(value: 'align_right', child: Text('Align Right')),
          const PopupMenuItem(value: 'align_top', child: Text('Align Top')),
          const PopupMenuItem(
            value: 'align_middle_v',
            child: Text('Vertical Middle'),
          ),
          const PopupMenuItem(
            value: 'align_bottom',
            child: Text('Align Bottom'),
          ),
          if (_selection.length >= 3) ...[
            const PopupMenuItem(
              value: 'distribute_h',
              child: Text('Distribute Horizontally'),
            ),
            const PopupMenuItem(
              value: 'distribute_v',
              child: Text('Distribute Vertically'),
            ),
          ],
          const PopupMenuDivider(),
          const PopupMenuItem(
            enabled: false,
            height: 24,
            child: Text(
              'AUTO-ARRANGE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const PopupMenuItem(
            value: 'arrange_grid',
            child: Text('Arrange in Grid'),
          ),
          const PopupMenuItem(
            value: 'arrange_stack_h',
            child: Text('Stack Horizontally'),
          ),
          const PopupMenuItem(
            value: 'arrange_stack_v',
            child: Text('Stack Vertically'),
          ),
          const PopupMenuItem(
            value: 'arrange_radial',
            child: Text('Radial Circle'),
          ),
          const PopupMenuItem(
            value: 'arrange_mind_map',
            child: Text('Mind Map Tree'),
          ),
          const PopupMenuItem(
            value: 'arrange_timeline',
            child: Text('Timeline Road Map'),
          ),
          const PopupMenuItem(
            value: 'arrange_tree_v',
            child: Text('Vertical Hierarchy Tree'),
          ),
          const PopupMenuDivider(),
        ],
        if (!_readOnly &&
            (_selection.length >= 2 ||
                _selection.any((id) => _scene[id]?.groupId != null))) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            enabled: false,
            height: 24,
            child: Text(
              'GROUPING',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          if (_selection.length >= 2)
            const PopupMenuItem(value: 'group', child: Text('Group (Ctrl+G)')),
          if (_selection.any((id) => _scene[id]?.groupId != null))
            const PopupMenuItem(
              value: 'ungroup',
              child: Text('Ungroup (Ctrl+Shift+G)'),
            ),
          const PopupMenuDivider(),
        ],
        if (_selection.isNotEmpty && !_readOnly)
          const PopupMenuItem(
            value: 'delete',
            child: Text('Remove from Canvas'),
          ),
        if (_selection.isNotEmpty)
          const PopupMenuItem(
            value: 'fit_selection',
            child: Text('Fit Selection'),
          ),
        const PopupMenuItem(value: 'fit_all', child: Text('Fit All')),
        const PopupMenuItem(value: 'zoom_100', child: Text('100% Zoom')),
        if (hasInk && !_readOnly) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            enabled: false,
            height: 24,
            child: Text(
              'CLEAN SHAPE CONVERSION',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const PopupMenuItem(
            value: 'shape_auto_all',
            child: Row(
              children: [
                Icon(Icons.auto_fix_high, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Auto-Recognize (Text or Shape)')),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'shape_recognize_text',
            child: Row(
              children: [
                Icon(Icons.text_fields, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Convert Stroke to Text')),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'shape_auto',
            child: Row(
              children: [
                Icon(Icons.category_outlined, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Auto-Detect Clean Shape')),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'shape_rectangle',
            child: Row(
              children: [
                Icon(Icons.crop_square, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Convert to Rectangle')),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'shape_ellipse',
            child: Row(
              children: [
                Icon(Icons.circle_outlined, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Convert to Ellipse / Circle')),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'shape_diamond',
            child: Row(
              children: [
                Icon(Icons.diamond_outlined, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Convert to Diamond')),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'shape_arrow',
            child: Row(
              children: [
                Icon(Icons.arrow_right_alt, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Convert to Arrow')),
              ],
            ),
          ),
        ],
        const PopupMenuDivider(),
        if (_selection.isNotEmpty) ...[
          const PopupMenuItem(
            value: 'copy_mermaid',
            child: Text('Copy as Mermaid Flowchart'),
          ),
          const PopupMenuItem(
            value: 'extract_to_note',
            child: Text('Extract Selection to Note'),
          ),
          const PopupMenuItem(
            value: 'export_selection',
            child: Text('Export Selection...'),
          ),
        ],
        const PopupMenuItem(
          value: 'export_canvas',
          child: Text('Export Canvas...'),
        ),
      ],
    );
    if (!current() || action == null) return;
    switch (action) {
      case 'edit':
        if (_selection.length == 1) _edit(_scene[_selection.first]!);
      case 'edit_reference':
        _editReferenceDetails();
      case 'copy_element_reference':
        if (selElem != null) {
          final reference = ObjectReference(
            widget.canvasId,
            anchorType: 'element',
            anchorId: selElem.id,
          );
          await Clipboard.setData(
            ClipboardData(
              text: reference.markdown(
                widget.title.isEmpty
                    ? 'Canvas element'
                    : '${widget.title} · element',
              ),
            ),
          );
          if (mounted) _notice('Copied Canvas element reference');
        }
      case 'pres_compact':
        if (selElem != null) {
          _history.put(selElem.copy({'presentation': 'compact'}));
          _commit();
          _notice('Card presentation: COMPACT');
        }
      case 'pres_card':
        if (selElem != null) {
          _history.put(selElem.copy({'presentation': 'card'}));
          _commit();
          _notice('Card presentation: STANDARD CARD');
        }
      case 'pres_preview':
        if (selElem != null) {
          _history.put(selElem.copy({'presentation': 'preview'}));
          _commit();
          _notice('Card presentation: EXPANDED PREVIEW');
        }
      case 'pres_transclusion':
        if (selElem != null) {
          _history.put(selElem.copy({'presentation': 'transclusion'}));
          _commit();
          _notice('Card presentation: LIVE TRANSCLUSION');
        }
      case 'pres_properties':
        if (selElem != null) {
          _history.put(selElem.copy({'presentation': 'properties'}));
          _commit();
          _notice('Card presentation: PROPERTIES');
        }
      case 'font_default':
        for (final id in _selection) {
          final elem = _scene[id];
          if (elem != null) {
            final nextData = Map<String, dynamic>.from(elem.data)
              ..remove('fontFamily');
            _history.put(CanvasElement(nextData));
          }
        }
        _commit();
        _notice('Font: Default (Segoe UI)');
      case 'font_times_new_roman':
        for (final id in _selection) {
          final elem = _scene[id];
          if (elem != null) {
            _history.put(elem.copy({'fontFamily': 'Times New Roman'}));
          }
        }
        _commit();
        _notice('Font: Times New Roman');
      case 'section_size_small':
        _setSectionHeaderSize('small');
      case 'section_size_medium':
        _setSectionHeaderSize('medium');
      case 'section_size_large':
        _setSectionHeaderSize('large');
      case 'section_size_xlarge':
        _setSectionHeaderSize('xlarge');
      case 'section_size_huge':
        _setSectionHeaderSize('huge');
      case 'section_line_hairline':
        _setSectionLineThickness(1.0);
      case 'section_line_standard':
        _setSectionLineThickness(1.5);
      case 'section_line_medium':
        _setSectionLineThickness(2.5);
      case 'section_line_thick':
        _setSectionLineThickness(4.0);
      case 'section_line_heavy':
        _setSectionLineThickness(6.0);
      case 'edit_transclusion_content':
        if (selElem?.data['referenceTarget'] is String) {
          widget.onOpenObject(selElem!.data['referenceTarget'] as String);
        } else if (selElem?.objectId != null) {
          _editTransclusionContent(selElem!.objectId!);
        }
      case 'stroke_solid':
        _setConnectorStyle('solid');
      case 'stroke_dashed':
        _setConnectorStyle('dashed');
      case 'stroke_dotted':
        _setConnectorStyle('dotted');
      case 'routing_straight':
        _setConnectorRouting('straight');
      case 'routing_curved':
        _setConnectorRouting('curved');
      case 'routing_orthogonal':
        _setConnectorRouting('orthogonal');
      case 'marker_start_arrow':
        _setConnectorMarker('arrow', isStart: true);
      case 'marker_start_dot':
        _setConnectorMarker('dot', isStart: true);
      case 'marker_start_diamond':
        _setConnectorMarker('diamond', isStart: true);
      case 'marker_start_none':
        _setConnectorMarker('none', isStart: true);
      case 'marker_arrow':
        _setConnectorMarker('arrow');
      case 'marker_dot':
        _setConnectorMarker('dot');
      case 'marker_diamond':
        _setConnectorMarker('diamond');
      case 'marker_none':
        _setConnectorMarker('none');
      case 'anchor_start_auto':
        _setConnectorAnchor('auto', isStart: true);
      case 'anchor_end_auto':
        _setConnectorAnchor('auto', isStart: false);
      case 'reverse_direction':
        _reverseConnector();
      case 'connections':
        final source = _selection.length == 1
            ? _scene[_selection.first]?.objectId
            : null;
        if (source != null) widget.onShowObjectConnections?.call(source);
      case 'copy':
        _copy();
      case 'duplicate':
        _duplicate();
      case 'paste':
        _paste();
      case 'bring_to_front':
        _reorder('front');
      case 'bring_forward':
        _reorder('forward');
      case 'send_backward':
        _reorder('backward');
      case 'send_to_back':
        _reorder('back');
      case 'align_left':
        _align(CanvasAlignment.left);
      case 'align_center_h':
        _align(CanvasAlignment.centerH);
      case 'align_right':
        _align(CanvasAlignment.right);
      case 'align_top':
        _align(CanvasAlignment.top);
      case 'align_middle_v':
        _align(CanvasAlignment.middleV);
      case 'align_bottom':
        _align(CanvasAlignment.bottom);
      case 'distribute_h':
        _align(CanvasAlignment.distributeH);
      case 'distribute_v':
        _align(CanvasAlignment.distributeV);
      case 'arrange_grid':
        _applyArrangement(CanvasArrangement.grid);
      case 'arrange_stack_h':
        _applyArrangement(CanvasArrangement.stackH);
      case 'arrange_stack_v':
        _applyArrangement(CanvasArrangement.stackV);
      case 'arrange_radial':
        _applyArrangement(CanvasArrangement.radial);
      case 'arrange_mind_map':
        _applyArrangement(CanvasArrangement.mindMap);
      case 'arrange_timeline':
        _applyArrangement(CanvasArrangement.timeline);
      case 'arrange_tree_v':
        _applyArrangement(CanvasArrangement.treeV);
      case 'shape_auto_all':
        _autoCleanSelectedInk();
      case 'shape_recognize_text':
        _convertSelectedInkToText();
      case 'shape_auto':
        _convertSelectedInkToShape(null);
      case 'shape_rectangle':
        _convertSelectedInkToShape('rectangle');
      case 'shape_ellipse':
        _convertSelectedInkToShape('ellipse');
      case 'shape_diamond':
        _convertSelectedInkToShape('diamond');
      case 'shape_arrow':
        _convertSelectedInkToShape('arrow');
      case 'group':
        _groupSelection();
      case 'ungroup':
        _ungroupSelection();
      case 'delete':
        _delete();
      case 'fit_selection':
        _fit(selectionOnly: true);
      case 'fit_all':
        _fit();
      case 'zoom_100':
        _zoom(1 / _camera.zoom);
      case 'copy_mermaid':
        final mermaid = exportToMermaid(_scene, elementIds: _selection);
        Clipboard.setData(ClipboardData(text: mermaid));
        _notice(
          _selection.any((id) => _scene[id] != null && isUmlClass(_scene[id]!))
              ? 'Flowchart copied. Use SVG or Canvas JSON to preserve UML compartments and notation.'
              : 'Mermaid flowchart copied to clipboard',
        );
      case 'extract_to_note':
        _extractSelectionToNote();
      case 'export_selection':
        _showExportDialog(selectionOnly: true);
      case 'export_canvas':
        _showExportDialog(selectionOnly: false);
    }
  }

  void _extractSelectionToNote() {
    if (_selection.isEmpty) return;
    final selectedElements = _selection
        .map((id) => _scene[id])
        .whereType<CanvasElement>()
        .toList();
    if (selectedElements.isEmpty) return;
    if (selectedElements.any((e) => isUmlClass(e) || isInteractionNode(e)) &&
        selectedElements.every(
          (e) => isUmlClass(e) || isInteractionNode(e) || isConnectorElement(e),
        )) {
      _exportUmlDiagram();
      return;
    }

    final markdown = extractSelectionToMarkdown(
      _scene,
      _selection,
      canvasTitle: 'Canvas Board',
      canvasId: widget.canvasId,
    );

    if (widget.onExportSelectionToNote != null) {
      widget.onExportSelectionToNote!(selectedElements, markdown);
    } else {
      Clipboard.setData(ClipboardData(text: markdown));
      _notice('Extracted note Markdown copied to clipboard');
    }
  }

  Future<void> _exportUmlDiagram({bool copy = false}) async {
    _finishText();
    final ids = diagramExportSelection(_scene, _selection);
    if (ids.isEmpty) {
      _notice(
        'Select diagram shapes, or clear the selection to export all diagram shapes.',
      );
      return;
    }
    try {
      final markdown = diagramMarkdown(
        widget.canvasId,
        '${widget.title} · ${ids.every((id) => isUmlClass(_scene[id]!)) ? 'Class diagram' : 'Diagram'}',
        ids,
      );
      if (copy || widget.onExportDiagramToNote == null) {
        await Clipboard.setData(ClipboardData(text: markdown));
        if (mounted) {
          _notice(
            'Live diagram copied. Paste it into a Markdown note in this Vault.',
          );
        }
      } else {
        await widget.onExportDiagramToNote!(ids);
      }
    } on FormatException catch (e) {
      if (mounted) _notice(e.message);
    } catch (_) {
      if (mounted) {
        _notice('Could not export the diagram. The Canvas is unchanged.');
      }
    }
    if (mounted) _focus.requestFocus();
  }

  void _autoCleanSelectedInk() {
    if (_readOnly || _selection.isEmpty) return;
    final inkElements = _selection
        .map((id) => _scene[id])
        .whereType<CanvasElement>()
        .where((e) => e.type == 'ink' && !e.locked)
        .toList();
    if (inkElements.isEmpty) return;

    _history.begin();
    var convertedCount = 0;
    for (final ink in inkElements) {
      final gesture = recognizeInkGesture(ink);
      if (gesture != null) {
        final converted = convertInkGesture(ink, gesture);
        if (converted != null) {
          _history.put(converted);
          convertedCount++;
        }
      }
    }
    if (convertedCount > 0) {
      _commit();
      _notice('Recognized and cleaned $convertedCount ink element(s)');
    } else {
      _history.cancel();
      _notice('Could not recognize text or shapes from selected stroke(s)');
    }
  }

  void _convertSelectedInkToText() {
    if (_readOnly || _selection.isEmpty) return;
    final inkElements = _selection
        .map((id) => _scene[id])
        .whereType<CanvasElement>()
        .where((e) => e.type == 'ink' && !e.locked)
        .toList();
    if (inkElements.isEmpty) return;

    _history.begin();
    var convertedCount = 0;

    // Check if multiple selected strokes form a combined multi-stroke character
    if (inkElements.length > 1) {
      final allStrokes = inkElements
          .map(
            (ink) => ink.points
                .map((p) => CanvasPoint(ink.x + p.x, ink.y + p.y))
                .toList(),
          )
          .toList();
      CanvasBounds? unionBounds;
      for (final ink in inkElements) {
        unionBounds = unionBounds?.union(ink.bounds) ?? ink.bounds;
      }
      final multiChar = globalCharacterRecognizer.recognize(
        allStrokes,
        bounds: unionBounds,
        minConfidence: 0.60,
      );
      if (multiChar != null) {
        for (final ink in inkElements) {
          _history.remove(ink.id);
        }
        final textElement = CanvasElement({
          'id': _id(),
          'type': 'text',
          'x': multiChar.bounds.left,
          'y': multiChar.bounds.top,
          'width': math.max(40.0, multiChar.bounds.width),
          'height': math.max(40.0, multiChar.bounds.height),
          'color': inkElements.first.color,
          'text': multiChar.char,
        });
        _history.put(textElement);
        _selection
          ..clear()
          ..add(textElement.id);
        _commit();
        _notice('Recognized text: "${multiChar.char}"');
        return;
      }
    }

    final newIds = <String>[];
    for (final ink in inkElements) {
      final textElement = convertInkToText(ink);
      _history.put(textElement);
      newIds.add(textElement.id);
      convertedCount++;
    }
    if (convertedCount > 0) {
      _selection
        ..clear()
        ..addAll(newIds);
      _commit();
      _notice('Converted $convertedCount stroke(s) to text');
    } else {
      _history.cancel();
      _notice('Could not recognize text from stroke');
    }
  }

  void _convertSelectedInkToShape(String? forceShape) {
    if (_readOnly || _selection.isEmpty) return;
    final inkElements = _selection
        .map((id) => _scene[id])
        .whereType<CanvasElement>()
        .where((e) => e.type == 'ink' && !e.locked)
        .toList();
    if (inkElements.isEmpty) return;

    _history.begin();
    var convertedCount = 0;
    for (final ink in inkElements) {
      final cleanShape = convertInkToShape(ink, forceShape: forceShape);
      if (cleanShape != null) {
        _history.put(cleanShape);
        convertedCount++;
      }
    }
    if (convertedCount > 0) {
      _commit();
      _notice(
        forceShape == null
            ? 'Converted $convertedCount stroke(s) to geometric shapes'
            : 'Converted $convertedCount stroke(s) to ${forceShape}s',
      );
    } else {
      _history.cancel();
      _notice('Could not recognize shape from stroke');
    }
  }

  void _setConnectorStyle(String style) {
    if (_selection.length != 1) return;
    final element = _scene[_selection.first];
    if (element == null) return;
    _history.put(element.copy({'strokeStyle': style}));
    _commit();
    setState(() {});
  }

  void _setConnectorMarker(String marker, {bool isStart = false}) {
    if (_selection.length != 1) return;
    final element = _scene[_selection.first];
    if (element == null) return;
    final key = isStart ? 'startMarker' : 'endMarker';
    _history.put(element.copy({key: marker}));
    _commit();
    setState(() {});
  }

  void _setConnectorRouting(String routing) {
    if (_selection.length != 1) return;
    final element = _scene[_selection.first];
    if (element == null) return;
    _history.put(element.copy({'routing': routing}));
    _commit();
    setState(() {});
  }

  void _reverseConnector() {
    if (_selection.length != 1) return;
    final element = _scene[_selection.first];
    if (element == null) return;
    _history.put(
      element.copy({
        'startId': element.endId,
        'endId': element.startId,
        'startAnchor': element.endAnchor,
        'endAnchor': element.startAnchor,
        'startAnchorOffset': element.data['endAnchorOffset'],
        'endAnchorOffset': element.data['startAnchorOffset'],
        'startMultiplicity': element.data['endMultiplicity'],
        'endMultiplicity': element.data['startMultiplicity'],
        'startRole': element.data['endRole'],
        'endRole': element.data['startRole'],
        'startMarker': element.endMarker,
        'endMarker': element.startMarker,
        'reverseX': element.data['reverseX'] != true,
        'reverseY': element.data['reverseY'] != true,
        ...connectorEndpointData(
          storedConnectorEnd(element),
          storedConnectorStart(element),
        ),
      }),
    );
    _commit();
    setState(() {});
  }

  void _setConnectorAnchor(String anchor, {bool isStart = false}) {
    if (_selection.length != 1) return;
    final element = _scene[_selection.first];
    if (element == null) return;
    final key = isStart ? 'startAnchor' : 'endAnchor';
    _history.put(element.copy({key: anchor}));
    _commit();
    setState(() {});
  }

  void _setSectionHeaderSize(String size) {
    if (_selection.isEmpty) return;
    const sizeMap = {
      'small': (fontSize: 13.0, strokeWidth: 1.5, minHeight: 40.0),
      'medium': (fontSize: 18.0, strokeWidth: 2.5, minHeight: 52.0),
      'large': (fontSize: 24.0, strokeWidth: 3.5, minHeight: 66.0),
      'xlarge': (fontSize: 32.0, strokeWidth: 4.5, minHeight: 84.0),
      'huge': (fontSize: 42.0, strokeWidth: 6.0, minHeight: 104.0),
    };
    final config = sizeMap[size];
    if (config == null) return;
    for (final id in _selection) {
      final elem = _scene[id];
      if (elem != null && elem.type == 'section') {
        _history.put(
          elem.copy({
            'headerSize': size,
            'fontSize': config.fontSize,
            'strokeWidth': config.strokeWidth,
            'lineThickness': config.strokeWidth,
            'height': math.max(elem.height, config.minHeight),
          }),
        );
      }
    }
    _commit();
    setState(() {});
    _notice('Section size: ${size.toUpperCase()}');
  }

  void _setSectionLineThickness(double thickness) {
    if (_selection.isEmpty) return;
    for (final id in _selection) {
      final elem = _scene[id];
      if (elem != null && elem.type == 'section') {
        _history.put(
          elem.copy({'strokeWidth': thickness, 'lineThickness': thickness}),
        );
      }
    }
    _commit();
    setState(() {});
    _notice('Line thickness: ${thickness.toStringAsFixed(1)}px');
  }

  String _estimateSectionHeaderSize(CanvasElement elem) {
    final hs = elem.data['headerSize'];
    if (hs is String &&
        ['small', 'medium', 'large', 'xlarge', 'huge'].contains(hs)) {
      return hs;
    }
    final fs = elem.sectionFontSize;
    if (fs >= 38) return 'huge';
    if (fs >= 28) return 'xlarge';
    if (fs >= 21) return 'large';
    if (fs >= 15) return 'medium';
    return 'small';
  }

  void _adjustSectionSize({required bool increase}) {
    if (_selection.isEmpty) return;
    const sizes = ['small', 'medium', 'large', 'xlarge', 'huge'];
    for (final id in _selection) {
      final elem = _scene[id];
      if (elem != null && elem.type == 'section') {
        final current = _estimateSectionHeaderSize(elem);
        final idx = sizes.indexOf(current);
        if (increase) {
          if (idx < sizes.length - 1) {
            _setSectionHeaderSize(sizes[idx + 1]);
          } else {
            final newFs = (elem.sectionFontSize + 4.0).clamp(11.0, 72.0);
            final strokeW = (newFs * 0.12).clamp(1.5, 8.0);
            _history.put(
              elem.copy({
                'fontSize': newFs,
                'strokeWidth': strokeW,
                'lineThickness': strokeW,
                'height': math.max(elem.height, newFs * 2.5),
              }),
            );
            _commit();
            setState(() {});
            _notice('Section size: ${newFs.toInt()}px');
          }
        } else {
          if (idx > 0) {
            _setSectionHeaderSize(sizes[idx - 1]);
          } else {
            final newFs = (elem.sectionFontSize - 2.0).clamp(11.0, 72.0);
            final strokeW = (newFs * 0.12).clamp(1.5, 8.0);
            _history.put(
              elem.copy({
                'fontSize': newFs,
                'strokeWidth': strokeW,
                'lineThickness': strokeW,
              }),
            );
            _commit();
            setState(() {});
            _notice('Section size: ${newFs.toInt()}px');
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final perf = CanvasPerformance.instance;
    final started = perf.begin();
    _recordPerformanceContext();
    try {
      return _buildEditor(context);
    } finally {
      perf.duration(CanvasPerfEvent.editorBuild, _performanceSurface, started, {
        'revision': _scene.revision,
        'elements': _scene.length,
      });
    }
  }

  Widget _buildEditor(BuildContext context) => _initialRoutingLoading
      ? Stack(
          children: [
            Center(
              child: Semantics(
                label: 'Preparing diagram',
                child: const CircularProgressIndicator(),
              ),
            ),
            if (_drawingFocus)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  tooltip: 'Exit Canvas focus',
                  onPressed: widget.onToggleFocusMode,
                  icon: const Icon(Icons.fullscreen_exit),
                ),
              ),
          ],
        )
      : Focus(
          focusNode: _focus,
          onKeyEvent: (node, event) {
            final result = _key(node, event);
            _publishPresenceSelection();
            return result;
          },
          onFocusChange: (focused) {
            if (!focused) _clearPresence();
            if (!focused && _spacePressed) {
              setState(() {
                _spacePressed = false;
              });
            }
          },
          child: Column(
            children: [
              if (!_presentationMode && !_drawingFocus) _toolbar(context),
              if (_readOnly)
                MaterialBanner(
                  content: Text(
                    widget.readOnly
                        ? 'Shared Viewer · pan and zoom to explore this Canvas.'
                        : 'This Canvas uses an unsupported format. It is preserved and opened read-only.',
                  ),
                  actions: [SizedBox.shrink()],
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _viewport = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    final visibleElements = _scene.query(
                      _camera.viewport(_viewport.width, _viewport.height),
                    );
                    final wantedRefs = <String>{};
                    for (final el in visibleElements) {
                      if (el.type == 'image' &&
                          el.data['contentRef'] is String) {
                        wantedRefs.add(el.data['contentRef'] as String);
                      } else if (el.type == 'card') {
                        final ref =
                            el.data['contentRef'] as String? ??
                            (el.objectId != null
                                ? _objects[el.objectId]?.contentRef
                                : null);
                        final isImg =
                            el.objectId != null &&
                            (_objects[el.objectId]?.isImage ?? false);
                        if (ref != null &&
                            (isImg || el.data['contentRef'] != null)) {
                          wantedRefs.add(ref);
                        }
                      }
                    }
                    _images?.updateVisible(wantedRefs);
                    final editing = _editingId == null
                        ? null
                        : _scene[_editingId!];
                    final isConnector =
                        editing?.type == 'arrow' ||
                        editing?.type == 'line' ||
                        editing?.type == 'connector';
                    final endpoints = editing != null && isConnector
                        ? resolveConnectorEndpoints(editing, _scene)
                        : null;
                    final editingPosition = editing == null
                        ? null
                        : isConnector
                        ? _camera.toScreen(
                            CanvasPoint(
                              endpoints!.midpoint.x - 80 / _camera.zoom,
                              endpoints.midpoint.y - 20 / _camera.zoom,
                            ),
                          )
                        : _camera.toScreen(CanvasPoint(editing.x, editing.y));
                    return ClipRect(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: DragTarget<Object>(
                              onWillAcceptWithDetails: (details) {
                                if (_readOnly) return false;
                                final data = details.data;
                                if (data is ({String path, String? noteId})) {
                                  return data.noteId != null &&
                                      _objects.containsKey(data.noteId);
                                }
                                if (data is PdfQuoteDragData) return true;
                                return false;
                              },
                              onAcceptWithDetails: (details) {
                                final data = details.data;
                                final renderBox =
                                    context.findRenderObject() as RenderBox?;
                                if (renderBox == null) return;
                                final localOffset = renderBox.globalToLocal(
                                  details.offset,
                                );
                                final worldPoint = _camera.toWorld(
                                  CanvasPoint(localOffset.dx, localOffset.dy),
                                );
                                if (data is ({String path, String? noteId})) {
                                  final noteId = data.noteId;
                                  if (noteId != null) {
                                    _dropObjectOntoCanvas(noteId, worldPoint);
                                  }
                                } else if (data is PdfQuoteDragData) {
                                  _dropQuoteOntoCanvas(data, worldPoint);
                                }
                              },
                              builder: (ctx, candidateData, rejectedData) => Semantics(
                                label:
                                    'Universal Canvas. Use the element list for keyboard selection. Space drag to pan, Control wheel to zoom.',
                                child: MouseRegion(
                                  onHover: (event) {
                                    _onCanvasHover(event);
                                    _sendPresence(event.localPosition);
                                  },
                                  onExit: (_) {
                                    if (_hoveredConnectorId != null) {
                                      setState(
                                        () => _hoveredConnectorId = null,
                                      );
                                    }
                                    if (_pointer == null) _clearPresence();
                                    if (!_isHoveringTooltip) {
                                      _dismissCardTooltip();
                                    }
                                  },
                                  cursor:
                                      _panning ||
                                          _tool == _Tool.pan ||
                                          _spacePressed
                                      ? SystemMouseCursors.grab
                                      : _tool == _Tool.select
                                      ? SystemMouseCursors.basic
                                      : SystemMouseCursors.precise,
                                  child: Listener(
                                    behavior: HitTestBehavior.opaque,
                                    onPointerDown: (event) {
                                      final perf = CanvasPerformance.instance;
                                      final started = perf.begin();
                                      try {
                                        _down(event);
                                        _sendPresence(event.localPosition);
                                      } finally {
                                        perf.duration(
                                          CanvasPerfEvent.inputStart,
                                          _performanceSurface,
                                          started,
                                          {'kind': event.kind.index},
                                        );
                                      }
                                    },
                                    onPointerMove: (event) {
                                      final perf = CanvasPerformance.instance;
                                      final started = perf.begin();
                                      try {
                                        _move(event);
                                        _sendPresence(event.localPosition);
                                      } finally {
                                        perf.duration(
                                          CanvasPerfEvent.input,
                                          _performanceSurface,
                                          started,
                                          {'kind': event.kind.index},
                                        );
                                      }
                                    },
                                    onPointerUp: (event) {
                                      final perf = CanvasPerformance.instance;
                                      final started = perf.begin();
                                      try {
                                        _up(event);
                                        _sendPresence(event.localPosition);
                                      } finally {
                                        perf.duration(
                                          CanvasPerfEvent.inputEnd,
                                          _performanceSurface,
                                          started,
                                          {'kind': event.kind.index},
                                        );
                                      }
                                    },
                                    onPointerCancel: (event) {
                                      _touchPointers.remove(event.pointer);
                                      if (event.pointer == _pointer ||
                                          _inMultiTouch) {
                                        _cancelGesture();
                                      }
                                    },
                                    onPointerPanZoomStart: (_) {
                                      _finishText();
                                    },
                                    onPointerPanZoomUpdate: (event) {
                                      setState(() {
                                        _camera = _camera
                                            .pan(_point(event.panDelta))
                                            .zoomAt(
                                              _point(event.localPosition),
                                              event.scale /
                                                  (_trackpadScale == 0
                                                      ? 1
                                                      : _trackpadScale),
                                            );
                                        _trackpadScale = event.scale;
                                      });
                                    },
                                    onPointerPanZoomEnd: (_) {
                                      _trackpadScale = 1;
                                      _cameraChanged();
                                    },
                                    onPointerSignal: (event) {
                                      if (!widget.interactionActive) {
                                        widget.onActivate?.call();
                                      }
                                      if (event is PointerScrollEvent) {
                                        GestureBinding
                                            .instance
                                            .pointerSignalResolver
                                            .register(event, (event) {
                                              final scroll =
                                                  event as PointerScrollEvent;
                                              setState(() {
                                                _camera = _command
                                                    ? _camera.zoomAt(
                                                        _point(
                                                          scroll.localPosition,
                                                        ),
                                                        math.exp(
                                                          -scroll
                                                                  .scrollDelta
                                                                  .dy *
                                                              .002,
                                                        ),
                                                      )
                                                    : _camera.pan(
                                                        CanvasPoint(
                                                          -scroll
                                                              .scrollDelta
                                                              .dx,
                                                          -scroll
                                                              .scrollDelta
                                                              .dy,
                                                        ),
                                                      );
                                              });
                                              _cameraChanged();
                                            });
                                      }
                                    },
                                    child: Stack(
                                      children: [
                                        GestureDetector(
                                          onDoubleTap: () {},
                                          onDoubleTapDown: (details) {
                                            final hit = _scene.hit(
                                              _world(details.localPosition),
                                              tolerance: 6 / _camera.zoom,
                                              includeLocked: true,
                                            );
                                            if (hit != null) _edit(hit);
                                          },
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: CanvasSceneViewport(
                                                  key: _captureSurface,
                                                  performanceSurface:
                                                      _performanceSurface,
                                                  scene: _scene,
                                                  camera: _camera,
                                                  inkCache: _inkCache,
                                                  builder: (tileCamera, tileElements) => OrbitCanvasPainter(
                                                    paintElements: tileElements,
                                                    performanceSurface:
                                                        _performanceSurface,
                                                    transparentBackground: true,
                                                    paintOverlays:
                                                        tileElements.isEmpty,
                                                    semanticColors:
                                                        OrbitColors.of(context),
                                                    textCache: _textCache,
                                                    images:
                                                        _images?.images ??
                                                        const {},
                                                    scene: _scene,
                                                    camera: tileCamera,
                                                    selection: Set.of(
                                                      _selection,
                                                    ),
                                                    tracedConnectorId:
                                                        _hoveredConnectorId ??
                                                        (_selection.length ==
                                                                    1 &&
                                                                const {
                                                                  'connector',
                                                                  'arrow',
                                                                  'line',
                                                                }.contains(
                                                                  _scene[_selection
                                                                          .first]
                                                                      ?.type,
                                                                )
                                                            ? _selection.first
                                                            : null),
                                                    objects: _objects,
                                                    colors: Theme.of(
                                                      context,
                                                    ).colorScheme,
                                                    region: _region,
                                                    lassoPoints: _lassoPoints,
                                                    preview:
                                                        (_tool == _Tool.pen ||
                                                            _tool ==
                                                                _Tool
                                                                    .highlighter)
                                                        ? null
                                                        : _framePreview,
                                                    inkCache: _inkCache,
                                                    devicePixelRatio:
                                                        MediaQuery.devicePixelRatioOf(
                                                          context,
                                                        ),
                                                    editingId: _editingId,
                                                    guides: _activeGuides,
                                                    failedImages:
                                                        _images
                                                            ?.failedReferences ??
                                                        const {},
                                                    backgroundStyle:
                                                        _backgroundStyle,
                                                    hoveredAnchorElementId:
                                                        _hoveredAnchorElementId,
                                                    connectingStartElementId:
                                                        _connectingStartId,
                                                    fontFamily:
                                                        widget.fontFamily,
                                                    searchMatchIds:
                                                        _searchResults
                                                            .map(
                                                              (r) =>
                                                                  r.elementId,
                                                            )
                                                            .toSet(),
                                                    activeSearchMatchId:
                                                        _searchResults
                                                                .isNotEmpty &&
                                                            _activeSearchIndex >=
                                                                0 &&
                                                            _activeSearchIndex <
                                                                _searchResults
                                                                    .length
                                                        ? _searchResults[_activeSearchIndex]
                                                              .elementId
                                                        : null,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox.expand(),
                                              Positioned.fill(
                                                child: IgnorePointer(
                                                  child: RepaintBoundary(
                                                    child: CanvasLiveInkLayer(
                                                      performanceSurface:
                                                          _performanceSurface,
                                                      cache: _liveInkCache,
                                                      changes: _liveInkChanges,
                                                      stroke: () =>
                                                          (_tool == _Tool.pen ||
                                                              _tool ==
                                                                  _Tool
                                                                      .highlighter)
                                                          ? _framePreview
                                                          : null,
                                                      camera: () => _camera,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Positioned.fill(
                                                child:
                                                    widget.remotePresence ==
                                                        null
                                                    ? CanvasPresenceOverlay(
                                                        scene: _scene,
                                                        camera: _camera,
                                                        peers: widget
                                                            .remoteCursors,
                                                      )
                                                    : ValueListenableBuilder<
                                                        List<
                                                          Map<String, dynamic>
                                                        >
                                                      >(
                                                        valueListenable: widget
                                                            .remotePresence!,
                                                        builder: (_, peers, _) =>
                                                            CanvasPresenceOverlay(
                                                              scene: _scene,
                                                              camera: _camera,
                                                              peers: peers
                                                                  .where(
                                                                    (p) =>
                                                                        p['objectId'] ==
                                                                            widget.canvasId &&
                                                                        p['space'] ==
                                                                            'canvas',
                                                                  )
                                                                  .toList(),
                                                            ),
                                                      ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (_laserMode)
                                          const Positioned.fill(
                                            child: OrbitLaserSurface(),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_scene.length == 0 &&
                              _preview == null &&
                              editing == null)
                            const Positioned.fill(
                              child: IgnorePointer(
                                child: Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(40),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.gesture, size: 40),
                                        SizedBox(height: 16),
                                        Text(
                                          'Room for your ideas',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Place a note, sketch a connection, or add a sticky.\nEverything lives on the same Canvas.',
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (editing != null &&
                              editingPosition != null &&
                              !isConnector)
                            Positioned(
                              left: editingPosition.x,
                              top: (editingPosition.y - 38) < 10
                                  ? editingPosition.y +
                                        math.max(
                                          80,
                                          editing.height * _camera.zoom,
                                        ) +
                                        6
                                  : editingPosition.y - 38,
                              child: TapRegion(
                                groupId: 'canvas-text-editing',
                                child: Material(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  elevation: 3,
                                  borderRadius: BorderRadius.circular(8),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _FormatButton(
                                            icon: Icons.check_box_outlined,
                                            label: 'Task',
                                            tooltip: 'Checklist (- [ ])',
                                            onPressed: () =>
                                                _applyFormatPrefix('- [ ] '),
                                          ),
                                          const SizedBox(width: 2),
                                          _FormatButton(
                                            label: 'H1',
                                            tooltip: 'Heading 1 (# )',
                                            onPressed: () =>
                                                _applyFormatPrefix('# '),
                                          ),
                                          const SizedBox(width: 2),
                                          _FormatButton(
                                            label: 'H2',
                                            tooltip: 'Heading 2 (## )',
                                            onPressed: () =>
                                                _applyFormatPrefix('## '),
                                          ),
                                          const SizedBox(width: 2),
                                          _FormatButton(
                                            label: 'H3',
                                            tooltip: 'Heading 3 (### )',
                                            onPressed: () =>
                                                _applyFormatPrefix('### '),
                                          ),
                                          const SizedBox(width: 2),
                                          _FormatButton(
                                            icon: Icons.format_list_bulleted,
                                            label: 'List',
                                            tooltip: 'Bullet list (- )',
                                            onPressed: () =>
                                                _applyFormatPrefix('- '),
                                          ),
                                          const SizedBox(width: 4),
                                          SizedBox(
                                            width: 28,
                                            height: 28,
                                            child: IconButton(
                                              icon: const Icon(
                                                Icons.check,
                                                size: 16,
                                              ),
                                              tooltip: 'Done (Ctrl+Enter)',
                                              padding: EdgeInsets.zero,
                                              onPressed: () => _finishText(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (editing != null && editingPosition != null)
                            Positioned(
                              left: editingPosition.x,
                              top: editingPosition.y,
                              width: isConnector
                                  ? 160.0
                                  : math.max(100, editing.width * _camera.zoom),
                              height: isConnector
                                  ? 40.0
                                  : (editing.type == 'section'
                                        ? math.max(
                                            36.0 * _camera.zoom,
                                            editing.height * _camera.zoom,
                                          )
                                        : math.max(
                                            80,
                                            editing.height * _camera.zoom,
                                          )),
                              child: Material(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHigh,
                                elevation: 4,
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: TextField(
                                    key: const ValueKey(
                                      'canvas-element-text-field',
                                    ),
                                    groupId: 'canvas-text-editing',
                                    controller: _text,
                                    readOnly: _readOnly || editing.locked,
                                    focusNode: _textFocus,
                                    maxLines: editing.type == 'section'
                                        ? 1
                                        : null,
                                    expands: editing.type != 'section',
                                    style: TextStyle(
                                      fontSize: editing.type == 'section'
                                          ? (editing.sectionFontSize *
                                                    _camera.zoom)
                                                .clamp(11, 72)
                                          : (17 * _camera.zoom).clamp(12, 48),
                                      fontWeight: editing.type == 'section'
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                      color: editing.type == 'section'
                                          ? Color(editing.color)
                                          : null,
                                      fontFamily:
                                          (_editingId != null
                                              ? _scene[_editingId!]
                                                        ?.data['fontFamily']
                                                    as String?
                                              : null) ??
                                          widget.fontFamily,
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'Write here…',
                                    ),
                                    onTapOutside: (_) => _finishText(),
                                    onChanged: (value) {
                                      if (_readOnly || _editingId == null) {
                                        return;
                                      }
                                      final element = _scene[_editingId!];
                                      if (element != null && !element.locked) {
                                        _history.put(
                                          element.copy({'text': value}),
                                        );
                                        _emit();
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                          if (_showCardTooltip &&
                              _hoveredCardId != null &&
                              _scene[_hoveredCardId!] != null) ...[
                            () {
                              final element = _scene[_hoveredCardId!]!;
                              final screenPoint = _camera.toScreen(
                                CanvasPoint(element.x, element.y),
                              );
                              final cardScreenWidth =
                                  element.width * _camera.zoom;
                              final cardScreenHeight =
                                  element.height * _camera.zoom;

                              final tooltipWidth = math.min(
                                350.0,
                                math.max(0.0, _viewport.width - 32),
                              );
                              final tooltipHeight = math.min(
                                400.0,
                                math.max(0.0, _viewport.height - 32),
                              );
                              final double left =
                                  (screenPoint.x +
                                          cardScreenWidth / 2 -
                                          tooltipWidth / 2)
                                      .clamp(
                                        16.0,
                                        math.max(
                                          16.0,
                                          _viewport.width - tooltipWidth - 16,
                                        ),
                                      );
                              final double preferredTop = screenPoint.y - 250;
                              final double candidateTop = (preferredTop >= 16)
                                  ? preferredTop
                                  : (screenPoint.y + cardScreenHeight + 12)
                                        .clamp(
                                          16.0,
                                          math.max(
                                            16.0,
                                            _viewport.height - 280,
                                          ),
                                        );
                              final double top = candidateTop.clamp(
                                16.0,
                                math.max(
                                  16.0,
                                  _viewport.height - tooltipHeight - 16,
                                ),
                              );

                              return Positioned(
                                left: left,
                                top: top,
                                width: tooltipWidth,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: tooltipHeight,
                                  ),
                                  child: OrbitFadeScale(
                                    duration: OrbitMotion.control,
                                    child: CanvasCardPreviewTooltip(
                                      onOpenLinkedObject: widget.onOpenObject,
                                      key: const ValueKey(
                                        'canvas-card-preview-tooltip',
                                      ),
                                      element: element,
                                      object: element.objectId != null
                                          ? _objects[element.objectId]
                                          : null,
                                      objects: _objects,
                                      onOpen: () {
                                        if (element.objectId != null &&
                                            _objects.containsKey(
                                              element.objectId,
                                            )) {
                                          final nested =
                                              element.data['data'] is Map
                                              ? (element.data['data'] as Map)
                                              : const {};
                                          final ref =
                                              element.data['referenceTarget']
                                                  is String
                                              ? element.data['referenceTarget']
                                                    as String
                                              : (nested['referenceTarget']
                                                        is String
                                                    ? nested['referenceTarget']
                                                          as String
                                                    : null);
                                          final page =
                                              element.data['page'] ??
                                              nested['page'];
                                          widget.onOpenObject(
                                            ref ??
                                                (page != null
                                                    ? '${element.objectId}#page=$page'
                                                    : element.objectId!),
                                          );
                                          _dismissCardTooltip();
                                        }
                                      },
                                      onToggleTask: (taskId) =>
                                          _toggleTask(taskId),
                                      onCopyQuote: () async {
                                        final quote =
                                            element.data['quote'] ??
                                            (element.data['data'] is Map
                                                ? (element.data['data']
                                                      as Map)['quote']
                                                : null);
                                        if (quote is String &&
                                            quote.trim().isNotEmpty) {
                                          await Clipboard.setData(
                                            ClipboardData(text: quote.trim()),
                                          );
                                          _notice('Citation copied');
                                        }
                                      },
                                      onOpenSource: () {
                                        final nested =
                                            element.data['data'] is Map
                                            ? (element.data['data'] as Map)
                                            : const {};
                                        final ref =
                                            element.data['contentRef'] is String
                                            ? element.data['contentRef']
                                                  as String
                                            : (element.objectId != null &&
                                                      _objects[element.objectId]
                                                              ?.contentRef !=
                                                          null
                                                  ? _objects[element.objectId]!
                                                        .contentRef
                                                  : null);
                                        if (ref != null &&
                                            widget.onOpenAttachment != null) {
                                          widget.onOpenAttachment!(ref);
                                        } else if (element.objectId != null) {
                                          final target =
                                              element.data['referenceTarget']
                                                  is String
                                              ? element.data['referenceTarget']
                                                    as String
                                              : (nested['referenceTarget']
                                                        is String
                                                    ? nested['referenceTarget']
                                                          as String
                                                    : (nested['page'] != null
                                                          ? '${element.objectId}#page=${nested['page']}'
                                                          : element.objectId!));
                                          widget.onOpenObject(target);
                                        }
                                      },
                                      onCyclePresentation: () =>
                                          _cycleCardPresentation(element.id),
                                      onDismiss: _dismissCardTooltip,
                                      onEnterTooltip: () =>
                                          _isHoveringTooltip = true,
                                      onExitTooltip: () {
                                        _isHoveringTooltip = false;
                                        _dismissCardTooltip();
                                      },
                                    ),
                                  ),
                                ),
                              );
                            }(),
                          ],
                          if (_drawingFocus && !_presentationMode) ...[
                            if (_focusControlsVisible)
                              Positioned(
                                key: const ValueKey('canvas-focus-tools'),
                                top: 64,
                                left: 8,
                                right: 8,
                                child: Material(
                                  elevation: 3,
                                  borderRadius: BorderRadius.circular(12),
                                  clipBehavior: Clip.antiAlias,
                                  child: _toolbar(context),
                                ),
                              ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Material(
                                key: const ValueKey('canvas-focus-dock'),
                                elevation: 2,
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHigh,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Undo drawing',
                                      constraints: const BoxConstraints(
                                        minWidth: 48,
                                        minHeight: 48,
                                      ),
                                      onPressed: !_readOnly && _history.canUndo
                                          ? _undo
                                          : null,
                                      icon: const Icon(Icons.undo),
                                    ),
                                    IconButton(
                                      tooltip: _focusControlsVisible
                                          ? 'Hide Canvas tools'
                                          : 'Show Canvas tools',
                                      constraints: const BoxConstraints(
                                        minWidth: 48,
                                        minHeight: 48,
                                      ),
                                      isSelected: _focusControlsVisible,
                                      onPressed: () {
                                        setState(
                                          () => _focusControlsVisible =
                                              !_focusControlsVisible,
                                        );
                                        _focus.requestFocus();
                                      },
                                      icon: const Icon(Icons.tune),
                                    ),
                                    IconButton(
                                      tooltip: 'Exit Canvas focus',
                                      constraints: const BoxConstraints(
                                        minWidth: 48,
                                        minHeight: 48,
                                      ),
                                      onPressed: widget.onToggleFocusMode,
                                      icon: const Icon(Icons.fullscreen_exit),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (!_presentationMode && !_drawingFocus)
                            Positioned(
                              top: 16,
                              left: 16,
                              child: Material(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHigh
                                    .withValues(alpha: 0.94),
                                borderRadius: BorderRadius.circular(16),
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.space_dashboard_outlined,
                                        size: 16,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      if (widget.breadcrumbs != null &&
                                          widget.breadcrumbs!.length > 1) ...[
                                        const SizedBox(width: 8),
                                        for (
                                          int i = 0;
                                          i < widget.breadcrumbs!.length - 1;
                                          i++
                                        ) ...[
                                          InkWell(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            onTap: () => widget.onOpenObject(
                                              widget.breadcrumbs![i].id,
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 2,
                                                  ),
                                              child: Text(
                                                widget
                                                        .breadcrumbs![i]
                                                        .title
                                                        .isEmpty
                                                    ? 'Untitled'
                                                    : widget
                                                          .breadcrumbs![i]
                                                          .title,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            child: Icon(
                                              Icons.chevron_right,
                                              size: 14,
                                            ),
                                          ),
                                        ],
                                      ],
                                      const SizedBox(width: 6),
                                      if (widget.onTitleChanged != null) ...[
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            minWidth: 70,
                                            maxWidth: 240,
                                          ),
                                          child: IntrinsicWidth(
                                            child: TextField(
                                              key: const ValueKey(
                                                'canvas-title-field',
                                              ),
                                              controller: _titleController,
                                              readOnly: _readOnly,
                                              focusNode: _titleFocus,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: 'Untitled canvas',
                                                hintStyle: TextStyle(
                                                  fontSize: 13,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.4),
                                                  fontWeight: FontWeight.normal,
                                                ),
                                                isDense: true,
                                                border: InputBorder.none,
                                                focusedBorder:
                                                    UnderlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary
                                                            .withValues(
                                                              alpha: 0.6,
                                                            ),
                                                        width: 1.5,
                                                      ),
                                                    ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 4,
                                                    ),
                                              ),
                                              onChanged: widget.onTitleChanged,
                                              onSubmitted: (_) {
                                                _titleFocus.unfocus();
                                                _focus.requestFocus();
                                              },
                                            ),
                                          ),
                                        ),
                                        Tooltip(
                                          message: 'Rename canvas',
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            onTap: () {
                                              _titleFocus.requestFocus();
                                              _titleController
                                                  .selection = TextSelection(
                                                baseOffset: 0,
                                                extentOffset: _titleController
                                                    .text
                                                    .length,
                                              );
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.all(4),
                                              child: Icon(
                                                Icons.edit_outlined,
                                                size: 13,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.5),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ] else ...[
                                        Text(
                                          widget.title.isEmpty
                                              ? 'Untitled canvas'
                                              : widget.title,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (_presentationMode)
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Material(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHigh
                                    .withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(20),
                                elevation: 3,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () =>
                                      setState(() => _presentationMode = false),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.fullscreen_exit, size: 18),
                                        SizedBox(width: 6),
                                        Text(
                                          'Exit presentation',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (!_drawingFocus)
                            Positioned(
                              right: 16,
                              bottom: 16,
                              child: Material(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(12),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Zoom out',
                                      onPressed: () => _zoom(.8),
                                      icon: const Icon(Icons.remove, size: 18),
                                    ),
                                    Tooltip(
                                      message: 'Reset zoom (100%)',
                                      child: TextButton(
                                        onPressed: () =>
                                            _zoom(1 / _camera.zoom),
                                        child: Text(
                                          '${(_camera.zoom * 100).round()}%',
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Zoom in',
                                      onPressed: () => _zoom(1.25),
                                      icon: const Icon(Icons.add, size: 18),
                                    ),
                                    IconButton(
                                      tooltip: 'Fit content (1)',
                                      onPressed: _fit,
                                      icon: const Icon(
                                        Icons.fit_screen,
                                        size: 18,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Fit selection',
                                      onPressed: _selection.isEmpty
                                          ? null
                                          : () => _fit(selectionOnly: true),
                                      icon: const Icon(
                                        Icons.filter_center_focus,
                                        size: 18,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: _presentationMode
                                          ? 'Exit presentation'
                                          : 'Presentation mode',
                                      onPressed: () => setState(() {
                                        _presentationMode = !_presentationMode;
                                      }),
                                      icon: Icon(
                                        _presentationMode
                                            ? Icons.fullscreen_exit
                                            : Icons.slideshow_outlined,
                                        size: 18,
                                      ),
                                    ),
                                    IconButton(
                                      key: const ValueKey(
                                        'canvas-minimap-toggle',
                                      ),
                                      tooltip: _showMinimap
                                          ? 'Hide minimap'
                                          : 'Show minimap',
                                      isSelected: _showMinimap,
                                      onPressed: () => setState(() {
                                        _showMinimap = !_showMinimap;
                                      }),
                                      icon: Icon(
                                        _showMinimap
                                            ? Icons.map
                                            : Icons.map_outlined,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (_showMinimap &&
                              !_presentationMode &&
                              !_drawingFocus &&
                              _scene.length > 0)
                            Positioned(
                              key: const ValueKey('canvas-minimap-card'),
                              right: 16,
                              bottom: 64,
                              child: OrbitFadeScale(
                                duration: OrbitMotion.panel,
                                child: Material(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHigh
                                      .withValues(alpha: 0.94),
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 160,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest
                                              .withValues(alpha: 0.5),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.radar,
                                                      size: 13,
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                    ),
                                                    const SizedBox(width: 3),
                                                    const Text(
                                                      'RADAR',
                                                      style: TextStyle(
                                                        fontSize: 9.0,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        letterSpacing: 0.3,
                                                      ),
                                                    ),
                                                    if (_searchResults
                                                        .isNotEmpty) ...[
                                                      const SizedBox(width: 3),
                                                      Tooltip(
                                                        message:
                                                            '${_searchResults.length} search match${_searchResults.length == 1 ? '' : 'es'}',
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 3,
                                                                vertical: 1,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color:
                                                                const Color(
                                                                  0xFFF59E0B,
                                                                ).withValues(
                                                                  alpha: 0.18,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  3,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            '${_searchResults.length}',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 8.5,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: Color(
                                                                    0xFFF59E0B,
                                                                  ),
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                '${(_camera.zoom * 100).toInt()}%',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              InkWell(
                                                key: const ValueKey(
                                                  'canvas-minimap-fit-btn',
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                                onTap: () => _fit(),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    2,
                                                  ),
                                                  child: Icon(
                                                    Icons.fit_screen,
                                                    size: 13,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          width: 160,
                                          height: 110,
                                          child: GestureDetector(
                                            onTapDown: (d) => _onMinimapTap(
                                              d.localPosition,
                                              const Size(160, 110),
                                            ),
                                            onPanStart: (d) => _onMinimapTap(
                                              d.localPosition,
                                              const Size(160, 110),
                                            ),
                                            onPanUpdate: (d) => _onMinimapTap(
                                              d.localPosition,
                                              const Size(160, 110),
                                            ),
                                            onPanEnd: (_) => _cameraChanged(),
                                            child: CustomPaint(
                                              painter: CanvasMinimapPainter(
                                                semanticColors: OrbitColors.of(
                                                  context,
                                                ),
                                                pictureCache: _minimapCache,
                                                scene: _scene,
                                                camera: _camera,
                                                viewportSize: _viewport,
                                                colors: Theme.of(
                                                  context,
                                                ).colorScheme,
                                                searchMatchIds: _searchResults
                                                    .map((r) => r.elementId)
                                                    .toSet(),
                                                activeSearchMatchId:
                                                    (_searchResults
                                                            .isNotEmpty &&
                                                        _activeSearchIndex >=
                                                            0 &&
                                                        _activeSearchIndex <
                                                            _searchResults
                                                                .length)
                                                    ? _searchResults[_activeSearchIndex]
                                                          .elementId
                                                    : null,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (_selection.isNotEmpty)
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 18,
                              child: Align(
                                alignment: Alignment.bottomLeft,
                                child: OrbitFadeScale(
                                  duration: OrbitMotion.control,
                                  child: Material(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 7,
                                      ),
                                      child: Text(
                                        '${_selection.length} selected · Delete removes placements',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (_showSearchHud)
                            Positioned(
                              top: 14,
                              bottom: 14,
                              left: 0,
                              right: 0,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: OrbitFadeScale(
                                  duration: OrbitMotion.control,
                                  child: CanvasSearchOverlay(
                                    key: const ValueKey(
                                      'canvas-search-overlay',
                                    ),
                                    searchController: _searchController,
                                    searchFocusNode: _searchFocusNode,
                                    results: _searchResults,
                                    activeIndex: _activeSearchIndex,
                                    category: _searchCategory,
                                    onCategoryChanged: _onSearchCategoryChanged,
                                    onNext: _nextSearchMatch,
                                    onPrevious: _previousSearchMatch,
                                    onSelectIndex: _jumpToSearchMatch,
                                    onClose: _closeSearchHud,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );

  double _trackpadScale = 1;

  Future<void> _insertImage(
    Future<CanvasImageReference?> Function() load, {
    CanvasPoint? at,
    bool Function()? stillCurrent,
  }) async {
    if (_readOnly) return;
    _finishText();
    final owner = widget.canvasId, scene = _scene;
    final revision = scene.revision;
    final epoch = _interactionEpoch, selection = {..._selection};
    final center =
        at ??
        _camera.toWorld(CanvasPoint(_viewport.width / 2, _viewport.height / 2));
    CanvasImageReference? image;
    try {
      image = await load();
    } catch (_) {
      if (mounted) _notice('Could not load the image. No placement was added.');
      return;
    }
    if (!mounted ||
        image == null ||
        _readOnly ||
        widget.canvasId != owner ||
        epoch != _interactionEpoch ||
        stillCurrent?.call() == false) {
      return;
    }
    if (!identical(_scene, scene) ||
        _scene.revision != revision ||
        !setEquals(selection, _selection)) {
      _notice(
        'The Canvas changed while loading the image. Insert it again at the intended position.',
      );
      return;
    }
    if (image.contentRef.trim().isEmpty ||
        !image.width.isFinite ||
        !image.height.isFinite ||
        image.width <= 0 ||
        image.height <= 0) {
      _notice(
        'The image has no valid source or dimensions. No placement was added.',
      );
      return;
    }
    final element = CanvasElement({
      'id': _id(),
      'type': 'image',
      'x': center.x - image.width / 2,
      'y': center.y - image.height / 2,
      'width': image.width,
      'height': image.height,
      'contentRef': image.contentRef,
      'text': image.title,
    });
    _history.put(element);
    _selection
      ..clear()
      ..add(element.id);
    _commit();
  }

  void _dropObjectOntoCanvas(String objectId, CanvasPoint at) {
    if (_readOnly) return;
    _finishText();
    final obj = _objects[objectId];
    if (obj == null) {
      _notice('The source is unavailable. No placement was added.');
      return;
    }
    String title = obj.title.isNotEmpty ? obj.title : 'Object';
    int cardColor = _color;

    final category = obj.properties['category'];
    if (category == 'Function' || obj.properties.containsKey('address')) {
      final addr = obj.properties['address'] ?? obj.properties['rva'] ?? '';
      final mod = obj.properties['module'] ?? 'target.exe';
      final conf = obj.properties['confidence'] ?? 'Medium';
      final purpose = obj.properties['purpose'] ?? '';
      title = '${obj.title}\n$addr ($mod)\nConf: $conf\n$purpose';
      cardColor = 0xff6366f1;
    } else if (category == 'Structure') {
      final size = obj.properties['size'] ?? 'Unknown';
      title = 'struct ${obj.title}\nSize: $size';
      cardColor = 0xff3b82f6;
    } else if (category == 'Indicator' ||
        obj.properties.containsKey('iocType')) {
      final iocType = obj.properties['iocType'] ?? 'IOC';
      final val = obj.properties['value'] ?? obj.title;
      final conf = obj.properties['confidence'] ?? 'High';
      title = '[$iocType]\n$val\nConf: $conf';
      cardColor = 0xfff59e0b;
    } else if (category == 'Hypothesis') {
      final status = obj.properties['status'] ?? 'Open';
      title = 'Hypothesis: ${obj.title}\nStatus: $status';
      cardColor = 0xff8b5cf6;
    }
    final element = CanvasElement({
      'id': _id(),
      'type': 'card',
      'objectId': objectId,
      'x': at.x - 130,
      'y': at.y - 60,
      'width': 260.0,
      'height': 120.0,
      'text': title,
      'color': cardColor,
    });
    _history.put(element);
    _selection
      ..clear()
      ..add(element.id);
    _commit();
  }

  void _dropQuoteOntoCanvas(PdfQuoteDragData quote, CanvasPoint at) {
    if (_readOnly) return;
    _finishText();
    final cardText = '${quote.text}\n\n— ${quote.title}, p. ${quote.page}';
    final element = CanvasElement({
      'id': _id(),
      'type': 'card',
      'objectId': quote.objectId,
      'x': at.x - 140,
      'y': at.y - 70,
      'width': 280.0,
      'height': 140.0,
      'text': cardText,
      'color': _color,
      'presentation': 'transclusion',
      'referenceTarget': quote.referenceTarget,
      'quote': quote.text,
      'sourceTitle': quote.title,
      'sourceId': quote.objectId,
      'page': quote.page,
      if (quote.checksum != null) 'checksum': quote.checksum,
      'data': {
        'quote': quote.text,
        'sourceTitle': quote.title,
        'sourceId': quote.objectId,
        'page': quote.page,
        'presentation': 'transclusion',
        'referenceTarget': quote.referenceTarget,
        if (quote.checksum != null) 'checksum': quote.checksum,
      },
    });
    _history.put(element);
    _selection
      ..clear()
      ..add(element.id);
    _commit();
    _notice('Extracted quote placed on canvas');
  }

  void _applyExercisePreset() {
    if (_readOnly) return;
    _finishText();
    final center = _camera.toWorld(
      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
    );
    final baseX = center.x - 350;
    final baseY = center.y - 450;

    final sec = CanvasElement({
      'id': _id(),
      'type': 'section',
      'x': baseX,
      'y': baseY,
      'width': 700.0,
      'height': 40.0,
      'text': 'EXERCISE WORKBENCH',
      'color': 0xff8b7cf6,
    });
    final problem = CanvasElement({
      'id': _id(),
      'type': 'sticky',
      'x': baseX,
      'y': baseY + 60,
      'width': 700.0,
      'height': 140.0,
      'text': 'PROBLEM STATEMENT\n\nGiven:\n\nGoal:\n',
      'color': 0xff6f7fea,
    });
    final workSec = CanvasElement({
      'id': _id(),
      'type': 'section',
      'x': baseX,
      'y': baseY + 220,
      'width': 700.0,
      'height': 40.0,
      'text': 'WORK & CALCULATIONS (Freeform Math / Ink / Cards)',
      'color': 0xff65c6a3,
    });
    final result = CanvasElement({
      'id': _id(),
      'type': 'sticky',
      'x': baseX,
      'y': baseY + 680,
      'width': 340.0,
      'height': 140.0,
      'text': 'FINAL RESULT\n\n',
      'color': 0xff65c6a3,
    });
    final mistakes = CanvasElement({
      'id': _id(),
      'type': 'sticky',
      'x': baseX + 360,
      'y': baseY + 680,
      'width': 340.0,
      'height': 140.0,
      'text': 'NOTES & MISTAKES TO REVIEW\n\n',
      'color': 0xffd8b56a,
    });

    _history.put(sec);
    _history.put(problem);
    _history.put(workSec);
    _history.put(result);
    _history.put(mistakes);
    _commit();
  }

  List<PopupMenuEntry<String>> _brainstormItems() => [
    PopupMenuItem(
      enabled: !_readOnly,
      value: 'bulk',
      child: const Text('Bulk sticky notes…'),
    ),
    PopupMenuItem(
      enabled: !_readOnly,
      value: 'cluster',
      child: const Text('Cluster stickies by color'),
    ),
    PopupMenuItem(
      enabled: !_readOnly,
      value: 'workshop',
      child: const Text('Workshop timer & voting…'),
    ),
    const PopupMenuItem(
      value: 'csv',
      child: Text('Export sticky notes as CSV…'),
    ),
  ];

  BrainstormDraft? _pendingBrainstormDraft;

  Future<void> _brainstormAction(String action) async {
    if (_readOnly && action != 'csv') return;
    _finishText();
    _cancelGesture();
    final scene = _scene, owner = widget.canvasId;
    final revision = scene.revision, epoch = _interactionEpoch;
    bool current() =>
        mounted &&
        !_readOnly &&
        widget.canvasId == owner &&
        identical(_scene, scene) &&
        scene.revision == revision &&
        epoch == _interactionEpoch;
    final notes = action == 'csv'
        ? brainstormExportNotes(scene.elements, selection: _selection)
        : scene.elements
              .where(
                (e) =>
                    brainstormEligible(e) &&
                    (_selection.isEmpty || _selection.contains(e.id)),
              )
              .toList();
    if ((action == 'cluster' || action == 'workshop') && notes.length > 200) {
      _notice('Select at most 200 editable, ungrouped sticky notes.');
      return;
    }
    try {
      if (action == 'bulk') {
        final draft = await showDialog<BrainstormDraft>(
          context: context,
          builder: (_) => BrainstormDialog(initial: _pendingBrainstormDraft),
        );
        if (draft == null) return;
        _pendingBrainstormDraft = draft;
        if (!current()) {
          if (mounted) {
            _notice(
              'The board changed. Draft retained; reopen bulk sticky notes to add it safely.',
            );
          }
          return;
        }
        final existing = scene.contentBounds;
        final origin = existing == null
            ? _camera.toWorld(
                CanvasPoint(_viewport.width / 2, _viewport.height / 2),
              )
            : CanvasPoint(existing.right + 80, existing.top);
        final items = createBrainstormStickies(
          draft.ideas,
          _id,
          origin: origin,
          color: _color,
          columns: draft.columns,
        );
        if (items.any((e) => scene[e.id] != null)) {
          throw const FormatException(
            'Duplicate sticky identity. No batch added.',
          );
        }
        scene.batch(() {
          for (final e in items) {
            _history.put(e);
          }
        });
        _selection
          ..clear()
          ..addAll(items.map((e) => e.id));
        _commit();
        _pendingBrainstormDraft = null;
        _fit(selectionOnly: true);
        _notice(
          '${items.length} editable sticky notes added · one Undo removes the batch',
        );
      } else if (action == 'cluster') {
        final moved = clusterBrainstormColors(notes, obstacles: scene.elements);
        if (moved.isEmpty) {
          _notice(
            'Select at least two unlocked, ungrouped sticky notes outside columns.',
          );
          return;
        }
        final changed = moved.where((e) {
          final old = scene[e.id];
          return old != null && (old.x != e.x || old.y != e.y);
        }).toList();
        if (changed.isEmpty) {
          _notice('These sticky notes are already clustered.');
          return;
        }
        scene.batch(() {
          for (final e in changed) {
            _history.put(e);
          }
        });
        _selection
          ..clear()
          ..addAll(moved.map((e) => e.id));
        _commit();
        _fit(selectionOnly: true);
        _notice(
          'Sticky notes clustered by color · Undo restores their positions',
        );
      } else if (action == 'csv') {
        if (notes.isEmpty) {
          _notice('Add or select visible sticky notes to export.');
          return;
        }
        await exportFile(
          'Orbit brainstorming.csv',
          '\ufeff${brainstormCsv(notes)}',
          mimeType: 'text/csv',
        );
      } else if (action == 'workshop') {
        final votes = await showDialog<Map<String, int>>(
          context: context,
          builder: (_) => WorkshopDialog(
            canSave: current,
            notes: notes,
            onLocate: (id) {
              if (!current() || scene[id] == null) return;
              _selection
                ..clear()
                ..add(id);
              _fit(selectionOnly: true);
            },
          ),
        );
        if (votes == null || votes.isEmpty) return;
        if (!current()) {
          if (mounted) {
            _notice(
              'The board changed. Reopen workshop tools before saving tallies.',
            );
          }
          return;
        }
        scene.batch(() {
          for (final entry in votes.entries) {
            final note = scene[entry.key];
            if (note != null && brainstormEligible(note)) {
              _history.put(
                note.copy({'workshopVotes': entry.value.clamp(0, 999)}),
              );
            }
          }
        });
        _commit();
        _notice(
          'Workshop tallies saved · one Undo restores the previous counts',
        );
      }
    } on FormatException catch (e) {
      if (mounted) _notice(e.message);
    } catch (_) {
      if (mounted) {
        _notice(
          'The workshop action could not finish. Your board remains available.',
        );
      }
    }
  }

  Future<void> _showStarterLibrary() async {
    if (_readOnly) return;
    _finishText();
    _cancelGesture();
    final owner = widget.canvasId, scene = _scene;
    final epoch = _interactionEpoch, revision = scene.revision;
    final starter = await showDialog<CanvasStarter>(
      context: context,
      builder: (_) => const CanvasStarterDialog(),
    );
    if (!mounted ||
        starter == null ||
        _readOnly ||
        widget.canvasId != owner ||
        epoch != _interactionEpoch) {
      return;
    }
    if (!identical(_scene, scene) || scene.revision != revision) {
      _notice(
        'The board changed while choosing a template. Open the library again.',
      );
      return;
    }
    _insertStarter(starter);
  }

  void _insertStarter(CanvasStarter starter) {
    if (_readOnly) return;
    final elements = starter.createElements(_id);
    final bounds = elements.map((e) => e.bounds).reduce((a, b) => a.union(b));
    final existing = _scene.contentBounds;
    final center = _camera.toWorld(
      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
    );
    final offset = existing == null
        ? center - bounds.center
        : CanvasPoint(
            existing.right + 80 - bounds.left,
            existing.top - bounds.top,
          );
    if (elements.any((e) => _scene[e.id] != null)) return;
    for (final element in elements) {
      _history.put(element.translated(offset));
    }
    _selection
      ..clear()
      ..addAll(elements.map((e) => e.id));
    _commit();
    _fit(selectionOnly: true);
    _notice('${starter.name} added · Undo removes the whole starter');
  }

  void _applyStudyBoardPreset() {
    if (_readOnly) return;
    _finishText();
    final center = _camera.toWorld(
      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
    );
    final baseX = center.x - 560;
    final baseY = center.y - 250;

    final col1 = CanvasElement({
      'id': _id(),
      'type': 'column',
      'text': 'TOPICS',
      'x': baseX,
      'y': baseY,
      'width': 260.0,
      'height': 500.0,
      'color': 0xff8b7cf6,
    });
    final col2 = CanvasElement({
      'id': _id(),
      'type': 'column',
      'text': 'IMPORTANT (Definitions & Theorems)',
      'x': baseX + 280,
      'y': baseY,
      'width': 300.0,
      'height': 500.0,
      'color': 0xff6f7fea,
    });
    final col3 = CanvasElement({
      'id': _id(),
      'type': 'column',
      'text': 'TODO / EXERCISES',
      'x': baseX + 600,
      'y': baseY,
      'width': 260.0,
      'height': 500.0,
      'color': 0xff65c6a3,
    });
    final col4 = CanvasElement({
      'id': _id(),
      'type': 'column',
      'text': 'RESOURCES (PDFs & Notes)',
      'x': baseX + 880,
      'y': baseY,
      'width': 260.0,
      'height': 500.0,
      'color': 0xffd8b56a,
    });

    _history.put(col1);
    _history.put(col2);
    _history.put(col3);
    _history.put(col4);
    _commit();
  }

  void _applyCourseMapPreset() {
    if (_readOnly) return;
    _finishText();
    final center = _camera.toWorld(
      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
    );
    final root = CanvasElement({
      'id': _id(),
      'type': 'sticky',
      'text': 'Course Overview',
      'x': center.x - 110,
      'y': center.y - 200,
      'width': 220.0,
      'height': 80.0,
      'color': 0xff8b7cf6,
    });
    final topic1 = CanvasElement({
      'id': _id(),
      'type': 'sticky',
      'text': 'Foundations & Logic',
      'x': center.x - 360,
      'y': center.y,
      'width': 200.0,
      'height': 80.0,
      'color': 0xff6f7fea,
    });
    final topic2 = CanvasElement({
      'id': _id(),
      'type': 'sticky',
      'text': 'Core Relations & Functions',
      'x': center.x - 100,
      'y': center.y,
      'width': 200.0,
      'height': 80.0,
      'color': 0xff65c6a3,
    });
    final topic3 = CanvasElement({
      'id': _id(),
      'type': 'sticky',
      'text': 'Advanced & Exam Prep',
      'x': center.x + 160,
      'y': center.y,
      'width': 200.0,
      'height': 80.0,
      'color': 0xffd8b56a,
    });

    _history.put(root);
    _history.put(topic1);
    _history.put(topic2);
    _history.put(topic3);
    _commit();
  }

  void _applyGameRoadmapPreset() {
    if (_readOnly) return;
    _finishText();
    final center = _camera.toWorld(
      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
    );
    final baseX = center.x - 600;
    final baseY = center.y - 120;

    final stages = [
      (
        'PROTOTYPE',
        'Core mechanics, player controller, graybox loop',
        0xff6f7fea,
      ),
      (
        'VERTICAL SLICE',
        '1 polished level, final art style, complete audio',
        0xff8b7cf6,
      ),
      ('ALPHA', 'Feature complete, all systems in, content rough', 0xff65c6a3),
      (
        'BETA',
        'Content complete, bug fixing, balance & optimization',
        0xffd8b56a,
      ),
      ('RELEASE', 'Day-1 patch, store submissions, certifications', 0xfff87171),
    ];

    for (var i = 0; i < stages.length; i++) {
      final s = stages[i];
      final col = CanvasElement({
        'id': _id(),
        'type': 'sticky',
        'text': '${s.$1}\n\n${s.$2}',
        'x': baseX + (i * 245),
        'y': baseY,
        'width': 225.0,
        'height': 160.0,
        'color': s.$3,
      });
      _history.put(col);
    }
    _commit();
  }

  void _applyCoreLoopPreset() {
    if (_readOnly) return;
    _finishText();
    final center = _camera.toWorld(
      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
    );
    final cx = center.x;
    final cy = center.y;

    final step1 = CanvasElement({
      'id': _id(),
      'type': 'sticky',
      'text': '1. PLAYER ACTION\n\nMovement, attack, interaction, puzzle input',
      'x': cx - 280,
      'y': cy - 180,
      'width': 240.0,
      'height': 110.0,
      'color': 0xff6f7fea,
    });
    final step2 = CanvasElement({
      'id': _id(),
      'type': 'sticky',
      'text':
          '2. SYSTEM FEEDBACK\n\nImpact frames, SFX, camera shake, damage numbers',
      'x': cx + 40,
      'y': cy - 180,
      'width': 240.0,
      'height': 110.0,
      'color': 0xff8b7cf6,
    });
    final step3 = CanvasElement({
      'id': _id(),
      'type': 'sticky',
      'text': '3. REWARD & LOOT\n\nXP, item drops, currency, ability unlock',
      'x': cx + 40,
      'y': cy + 60,
      'width': 240.0,
      'height': 110.0,
      'color': 0xffd8b56a,
    });
    final step4 = CanvasElement({
      'id': _id(),
      'type': 'sticky',
      'text':
          '4. PROGRESSION & GOALS\n\nLevel up, stat upgrade, unlock new region/dungeon',
      'x': cx - 280,
      'y': cy + 60,
      'width': 240.0,
      'height': 110.0,
      'color': 0xff65c6a3,
    });

    _history.put(step1);
    _history.put(step2);
    _history.put(step3);
    _history.put(step4);
    _commit();
  }

  void _applyLevelDesignPreset() {
    if (_readOnly) return;
    _finishText();
    final center = _camera.toWorld(
      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
    );
    final baseX = center.x - 650;
    final baseY = center.y - 200;

    final beats = [
      (
        '1. SPAWN & TUTORIAL',
        'Safe zone · Teach core moves · Introduce visual goal',
        0xff6f7fea,
      ),
      (
        '2. FIRST ENCOUNTER',
        'Low-stakes challenge · 1-2 basic enemies · Checkpoint',
        0xff8b7cf6,
      ),
      (
        '3. PACING VALLEY',
        'Exploration · Secret lore · Lock & Key puzzle',
        0xff65c6a3,
      ),
      (
        '4. CLIMAX ARENA',
        'Mastery test · Mixed enemy waves · High tension',
        0xfff87171,
      ),
      (
        '5. REWARD & EXIT',
        'Loot chest · Level transition · Story beat',
        0xffd8b56a,
      ),
    ];

    for (var i = 0; i < beats.length; i++) {
      final b = beats[i];
      final element = CanvasElement({
        'id': _id(),
        'type': 'column',
        'text': '${b.$1}\n\n${b.$2}',
        'x': baseX + (i * 265),
        'y': baseY,
        'width': 245.0,
        'height': 420.0,
        'color': b.$3,
      });
      _history.put(element);
    }
    _commit();
  }

  void _applyAiStateMachinePreset() {
    if (_readOnly) return;
    _finishText();
    final center = _camera.toWorld(
      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
    );
    final cx = center.x;
    final cy = center.y;

    final s1 = CanvasElement({
      'id': _id(),
      'type': 'sticky',
      'text':
          'PATROL / IDLE\n\nWaypoint loop · 90° vision cone · Relaxed audio',
      'x': cx - 360,
      'y': cy - 140,
      'width': 220.0,
      'height': 100.0,
      'color': 0xff6f7fea,
    });
    final s2 = CanvasElement({
      'id': _id(),
      'type': 'sticky',
      'text':
          'SUSPICIOUS / SEARCH\n\nFootstep heard · Turn to noise · 3s search timer',
      'x': cx - 100,
      'y': cy - 140,
      'width': 220.0,
      'height': 100.0,
      'color': 0xffd8b56a,
    });
    final s3 = CanvasElement({
      'id': _id(),
      'type': 'sticky',
      'text':
          'COMBAT & CHASE\n\nDirect sight · Sprint speed · Call nearby allies',
      'x': cx + 160,
      'y': cy - 140,
      'width': 220.0,
      'height': 100.0,
      'color': 0xfff87171,
    });
    final s4 = CanvasElement({
      'id': _id(),
      'type': 'sticky',
      'text':
          'ATTACK EXECUTION\n\nTelegraph 300ms · Hitbox active 150ms · 1s cooldown',
      'x': cx + 160,
      'y': cy + 40,
      'width': 220.0,
      'height': 100.0,
      'color': 0xff8b7cf6,
    });
    final s5 = CanvasElement({
      'id': _id(),
      'type': 'sticky',
      'text':
          'STUN / RETREAT\n\nPosture broken · Low health (<20%) · Seek cover',
      'x': cx - 100,
      'y': cy + 40,
      'width': 220.0,
      'height': 100.0,
      'color': 0xff65c6a3,
    });

    _history.put(s1);
    _history.put(s2);
    _history.put(s3);
    _history.put(s4);
    _history.put(s5);
    _commit();
  }

  void _applyMoodboardPreset() {
    if (_readOnly) return;
    _finishText();
    final center = _camera.toWorld(
      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
    );
    final baseX = center.x - 560;
    final baseY = center.y - 250;

    final col1 = CanvasElement({
      'id': _id(),
      'type': 'column',
      'text': 'CHARACTER & CREATURES',
      'x': baseX,
      'y': baseY,
      'width': 260.0,
      'height': 520.0,
      'color': 0xff8b7cf6,
    });
    final col2 = CanvasElement({
      'id': _id(),
      'type': 'column',
      'text': 'ENVIRONMENT & ARCHITECTURE',
      'x': baseX + 280,
      'y': baseY,
      'width': 260.0,
      'height': 520.0,
      'color': 0xff6f7fea,
    });
    final col3 = CanvasElement({
      'id': _id(),
      'type': 'column',
      'text': 'COLOR PALETTE & LIGHTING',
      'x': baseX + 560,
      'y': baseY,
      'width': 260.0,
      'height': 520.0,
      'color': 0xffd8b56a,
    });
    final col4 = CanvasElement({
      'id': _id(),
      'type': 'column',
      'text': 'UI, VFX & AUDIO VIBES',
      'x': baseX + 840,
      'y': baseY,
      'width': 260.0,
      'height': 520.0,
      'color': 0xff65c6a3,
    });

    _history.put(col1);
    _history.put(col2);
    _history.put(col3);
    _history.put(col4);
    _commit();
  }

  void _applyPlaytestFeedbackPreset() {
    if (_readOnly) return;
    _finishText();
    final center = _camera.toWorld(
      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
    );
    final baseX = center.x - 560;
    final baseY = center.y - 250;

    final col1 = CanvasElement({
      'id': _id(),
      'type': 'column',
      'text': 'WORKED WELL (POSITIVE)',
      'x': baseX,
      'y': baseY,
      'width': 260.0,
      'height': 520.0,
      'color': 0xff65c6a3,
    });
    final col2 = CanvasElement({
      'id': _id(),
      'type': 'column',
      'text': 'CONFUSING / FRICTION',
      'x': baseX + 280,
      'y': baseY,
      'width': 260.0,
      'height': 520.0,
      'color': 0xffd8b56a,
    });
    final col3 = CanvasElement({
      'id': _id(),
      'type': 'column',
      'text': 'BUGS & CRASHES',
      'x': baseX + 560,
      'y': baseY,
      'width': 260.0,
      'height': 520.0,
      'color': 0xffef4444,
    });
    final col4 = CanvasElement({
      'id': _id(),
      'type': 'column',
      'text': 'IDEAS & MUST FIX',
      'x': baseX + 840,
      'y': baseY,
      'width': 260.0,
      'height': 520.0,
      'color': 0xff8b7cf6,
    });

    _history.put(col1);
    _history.put(col2);
    _history.put(col3);
    _history.put(col4);
    _commit();
  }

  void _applyNarrativeBoardPreset() {
    if (_readOnly) return;
    _finishText();
    final center = _camera.toWorld(
      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
    );
    final baseX = center.x - 560;
    final baseY = center.y - 250;

    final act1 = CanvasElement({
      'id': _id(),
      'type': 'section',
      'text': 'ACT 1: THE CALL & EXILE',
      'x': baseX,
      'y': baseY,
      'width': 350.0,
      'height': 500.0,
      'color': 0xff8b7cf6,
    });
    final act2 = CanvasElement({
      'id': _id(),
      'type': 'section',
      'text': 'ACT 2: CONFLICT & MIDPOINT',
      'x': baseX + 380,
      'y': baseY,
      'width': 350.0,
      'height': 500.0,
      'color': 0xff6f7fea,
    });
    final act3 = CanvasElement({
      'id': _id(),
      'type': 'section',
      'text': 'ACT 3: CLIMAX & RETURN',
      'x': baseX + 760,
      'y': baseY,
      'width': 350.0,
      'height': 500.0,
      'color': 0xff65c6a3,
    });

    final c1 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text': 'Hero is banished after the observatory breach.',
      'x': baseX + 25,
      'y': baseY + 60,
      'width': 300.0,
      'height': 90.0,
      'color': 0xff8b7cf6,
    });
    final c2 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text': 'Discovery of the ancient Relic Blade and its corruption.',
      'x': baseX + 405,
      'y': baseY + 60,
      'width': 300.0,
      'height': 90.0,
      'color': 0xff6f7fea,
    });
    final c3 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text': 'Final confrontation against the corrupted elder guardian.',
      'x': baseX + 785,
      'y': baseY + 60,
      'width': 300.0,
      'height': 90.0,
      'color': 0xff65c6a3,
    });

    _history.put(act1);
    _history.put(act2);
    _history.put(act3);
    _history.put(c1);
    _history.put(c2);
    _history.put(c3);
    _commit();
  }

  void _applyGameArchitecturePreset() {
    if (_readOnly) return;
    _finishText();
    final center = _camera.toWorld(
      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
    );
    final baseX = center.x - 450;
    final baseY = center.y - 200;

    final sys1 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text': 'Input Manager\n(Keyboard / Gamepad / Touch)',
      'x': baseX,
      'y': baseY,
      'width': 220.0,
      'height': 90.0,
      'color': 0xff8b7cf6,
    });
    final sys2 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text': 'Player Controller\n(Movement, States, Physics)',
      'x': baseX + 280,
      'y': baseY,
      'width': 220.0,
      'height': 90.0,
      'color': 0xff6f7fea,
    });
    final sys3 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text': 'Combat & Damage Engine\n(Hitboxes, Health, Stats)',
      'x': baseX + 560,
      'y': baseY,
      'width': 220.0,
      'height': 90.0,
      'color': 0xffef4444,
    });
    final sys4 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text': 'Animation & VFX Pipeline\n(Transitions, Particles)',
      'x': baseX + 280,
      'y': baseY + 160,
      'width': 220.0,
      'height': 90.0,
      'color': 0xffd8b56a,
    });
    final sys5 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text': 'Save Manager & State\n(SQLite / JSON / Backup)',
      'x': baseX + 560,
      'y': baseY + 160,
      'width': 220.0,
      'height': 90.0,
      'color': 0xff65c6a3,
    });

    _history.put(sys1);
    _history.put(sys2);
    _history.put(sys3);
    _history.put(sys4);
    _history.put(sys5);
    _commit();
  }

  void _applyCallFlowPreset() {
    if (_readOnly) return;
    _finishText();
    final center = _camera.toWorld(
      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
    );
    final baseX = center.x - 450;
    final baseY = center.y - 60;

    final n1 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text': 'GameLoop / MainTick\n0x140010000',
      'x': baseX,
      'y': baseY,
      'width': 200.0,
      'height': 80.0,
      'color': 0xff6366f1,
    });
    final n2 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text': 'UpdatePlayer(Entity*)\n0x140012340',
      'x': baseX + 260,
      'y': baseY,
      'width': 200.0,
      'height': 80.0,
      'color': 0xff8b5cf6,
    });
    final n3 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text': 'UpdateMovement()\n0x140024A00',
      'x': baseX + 520,
      'y': baseY - 60,
      'width': 200.0,
      'height': 80.0,
      'color': 0xff3b82f6,
    });
    final n4 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text': 'Physics::Integrate()\n0x140038F10',
      'x': baseX + 520,
      'y': baseY + 60,
      'width': 200.0,
      'height': 80.0,
      'color': 0xff0ea5e9,
    });

    final c1 = CanvasElement({
      'id': _id(),
      'type': 'connector',
      'startId': n1.id,
      'endId': n2.id,
      'color': 0xff6366f1,
    });
    final c2 = CanvasElement({
      'id': _id(),
      'type': 'connector',
      'startId': n2.id,
      'endId': n3.id,
      'color': 0xff8b5cf6,
    });
    final c3 = CanvasElement({
      'id': _id(),
      'type': 'connector',
      'startId': n2.id,
      'endId': n4.id,
      'color': 0xff8b5cf6,
    });

    _history.put(n1);
    _history.put(n2);
    _history.put(n3);
    _history.put(n4);
    _history.put(c1);
    _history.put(c2);
    _history.put(c3);
    _commit();
  }

  void _applyObjectRelationshipsPreset() {
    if (_readOnly) return;
    _finishText();
    final center = _camera.toWorld(
      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
    );
    final baseX = center.x - 300;
    final baseY = center.y - 180;

    final gm = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text':
          'GameManager\n[Singleton @ 0x1412A8000]\n+0x38: PlayerManager* m_players',
      'x': baseX,
      'y': baseY,
      'width': 260.0,
      'height': 90.0,
      'color': 0xff6366f1,
    });
    final pm = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text':
          'PlayerManager\n+0x10: Player* localPlayer\n+0x18: List<Player*> remotePlayers',
      'x': baseX,
      'y': baseY + 140,
      'width': 260.0,
      'height': 90.0,
      'color': 0xff8b5cf6,
    });
    final pl = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text':
          'PlayerEntity\n+0x00: void* vtable\n+0x80: Inventory* inventory\n+0xC0: Vector3 position',
      'x': baseX + 320,
      'y': baseY + 140,
      'width': 260.0,
      'height': 90.0,
      'color': 0xff3b82f6,
    });
    final inv = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text':
          'Inventory\n+0x18: ItemSlot[32] slots\n+0x98: uint32_t activeSlotIndex',
      'x': baseX + 320,
      'y': baseY + 280,
      'width': 260.0,
      'height': 90.0,
      'color': 0xff10b981,
    });

    final c1 = CanvasElement({
      'id': _id(),
      'type': 'connector',
      'startId': gm.id,
      'endId': pm.id,
      'color': 0xff6366f1,
    });
    final c2 = CanvasElement({
      'id': _id(),
      'type': 'connector',
      'startId': pm.id,
      'endId': pl.id,
      'color': 0xff8b5cf6,
    });
    final c3 = CanvasElement({
      'id': _id(),
      'type': 'connector',
      'startId': pl.id,
      'endId': inv.id,
      'color': 0xff3b82f6,
    });

    _history.put(gm);
    _history.put(pm);
    _history.put(pl);
    _history.put(inv);
    _history.put(c1);
    _history.put(c2);
    _history.put(c3);
    _commit();
  }

  void _applyStructureLayoutPreset() {
    if (_readOnly) return;
    _finishText();
    final center = _camera.toWorld(
      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
    );
    final baseX = center.x - 320;
    final baseY = center.y - 200;

    final header = CanvasElement({
      'id': _id(),
      'type': 'section',
      'x': baseX,
      'y': baseY,
      'width': 640.0,
      'height': 40.0,
      'text': 'MEMORY STRUCTURE LAYOUT: struct PlayerEntity (Size: 0x120)',
      'color': 0xff6366f1,
    });

    final f1 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text': '+0x00 | void** vtable\nPoints to Player::`vftable\'',
      'x': baseX,
      'y': baseY + 50,
      'width': 640.0,
      'height': 60.0,
      'color': 0xff6f7fea,
    });
    final f2 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text': '+0x08 | float health\nCurrent player health (Default 100.0f)',
      'x': baseX,
      'y': baseY + 120,
      'width': 640.0,
      'height': 60.0,
      'color': 0xff10b981,
    });
    final f3 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text':
          '+0x10 | Vector3 position\n(x: float, y: float, z: float) in world meters',
      'x': baseX,
      'y': baseY + 190,
      'width': 640.0,
      'height': 60.0,
      'color': 0xff3b82f6,
    });
    final f4 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text':
          '+0x28 | uint32_t stateFlags\nBit 0: IsAlive | Bit 1: IsGrounded | Bit 2: InCombat',
      'x': baseX,
      'y': baseY + 260,
      'width': 640.0,
      'height': 60.0,
      'color': 0xfff59e0b,
    });
    final f5 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text': '+0x30 | WeaponState* currentWeapon\nPointer to WeaponEntity',
      'x': baseX,
      'y': baseY + 330,
      'width': 640.0,
      'height': 60.0,
      'color': 0xffef4444,
    });

    _history.put(header);
    _history.put(f1);
    _history.put(f2);
    _history.put(f3);
    _history.put(f4);
    _history.put(f5);
    _commit();
  }

  void _applyBinaryLayoutPreset() {
    if (_readOnly) return;
    _finishText();
    final center = _camera.toWorld(
      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
    );
    final baseX = center.x - 300;
    final baseY = center.y - 220;

    final header = CanvasElement({
      'id': _id(),
      'type': 'section',
      'x': baseX,
      'y': baseY,
      'width': 600.0,
      'height': 40.0,
      'text': 'EXECUTABLE / PE FORMAT SECTIONS',
      'color': 0xff6366f1,
    });

    final s1 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text': 'DOS Header & Stub\nMagic: 0x5A4D ("MZ") | e_lfanew: 0x000000F8',
      'x': baseX,
      'y': baseY + 50,
      'width': 600.0,
      'height': 60.0,
      'color': 0xff64748b,
    });
    final s2 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text':
          'PE NT Headers\nSignature: "PE\\0\\0" | OptionalHeader (ImageBase: 0x140000000, Subsystem: GUI)',
      'x': baseX,
      'y': baseY + 120,
      'width': 600.0,
      'height': 60.0,
      'color': 0xff6366f1,
    });
    final s3 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text':
          '.text Section (Code)\nVirtualSize: 0x120000 | Characteristics: IMAGE_SCN_MEM_EXECUTE | IMAGE_SCN_MEM_READ',
      'x': baseX,
      'y': baseY + 190,
      'width': 600.0,
      'height': 60.0,
      'color': 0xff3b82f6,
    });
    final s4 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text':
          '.rdata Section (Read-Only Data & Imports)\nImport Directory Table, String literals, Vtables, CRT constants',
      'x': baseX,
      'y': baseY + 260,
      'width': 600.0,
      'height': 60.0,
      'color': 0xff10b981,
    });
    final s5 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text':
          '.data Section (Read/Write Data)\nGlobal states, Singleton instances, Mutable tables',
      'x': baseX,
      'y': baseY + 330,
      'width': 600.0,
      'height': 60.0,
      'color': 0xfff59e0b,
    });

    _history.put(header);
    _history.put(s1);
    _history.put(s2);
    _history.put(s3);
    _history.put(s4);
    _history.put(s5);
    _commit();
  }

  void _applyProtocolFlowPreset() {
    if (_readOnly) return;
    _finishText();
    final center = _camera.toWorld(
      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
    );
    final baseX = center.x - 450;
    final baseY = center.y - 60;

    final p1 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text': '1. Handshake Init\n[0x01] Client Hello (Version 1.2)',
      'x': baseX,
      'y': baseY,
      'width': 200.0,
      'height': 80.0,
      'color': 0xff6366f1,
    });
    final p2 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text': '2. Server Challenge\n[0x02] Nonce (16 bytes) + Salt',
      'x': baseX + 240,
      'y': baseY,
      'width': 200.0,
      'height': 80.0,
      'color': 0xff3b82f6,
    });
    final p3 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text': '3. Auth Response\n[0x03] HMAC-SHA256 Token',
      'x': baseX + 480,
      'y': baseY,
      'width': 200.0,
      'height': 80.0,
      'color': 0xff8b5cf6,
    });
    final p4 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text': '4. Session Active\n[0x10] World Delta State (30Hz)',
      'x': baseX + 720,
      'y': baseY,
      'width': 200.0,
      'height': 80.0,
      'color': 0xff10b981,
    });

    final c1 = CanvasElement({
      'id': _id(),
      'type': 'connector',
      'startId': p1.id,
      'endId': p2.id,
      'color': 0xff6366f1,
    });
    final c2 = CanvasElement({
      'id': _id(),
      'type': 'connector',
      'startId': p2.id,
      'endId': p3.id,
      'color': 0xff3b82f6,
    });
    final c3 = CanvasElement({
      'id': _id(),
      'type': 'connector',
      'startId': p3.id,
      'endId': p4.id,
      'color': 0xff8b5cf6,
    });

    _history.put(p1);
    _history.put(p2);
    _history.put(p3);
    _history.put(p4);
    _history.put(c1);
    _history.put(c2);
    _history.put(c3);
    _commit();
  }

  void _applyProcessTreePreset() {
    if (_readOnly) return;
    _finishText();
    final center = _camera.toWorld(
      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
    );
    final baseX = center.x - 360;
    final baseY = center.y - 60;

    final root = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text':
          'sample.exe (PID: 4820)\nEntry Point: 0x140081200\nCapabilities: Drops worker, modifies registry',
      'x': baseX,
      'y': baseY,
      'width': 260.0,
      'height': 90.0,
      'color': 0xffef4444,
    });
    final child1 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text':
          'cmd.exe /c timeout 5 (PID: 5124)\nDefense Evasion: Sleep delay before injection',
      'x': baseX + 320,
      'y': baseY - 70,
      'width': 260.0,
      'height': 80.0,
      'color': 0xfff59e0b,
    });
    final child2 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text':
          'worker.exe (PID: 5312)\nPath: %TEMP%\\worker.exe\nNetwork: Connects to C2 198.51.100.45',
      'x': baseX + 320,
      'y': baseY + 70,
      'width': 260.0,
      'height': 80.0,
      'color': 0xffe11d48,
    });

    final c1 = CanvasElement({
      'id': _id(),
      'type': 'connector',
      'startId': root.id,
      'endId': child1.id,
      'color': 0xffef4444,
    });
    final c2 = CanvasElement({
      'id': _id(),
      'type': 'connector',
      'startId': root.id,
      'endId': child2.id,
      'color': 0xffef4444,
    });

    _history.put(root);
    _history.put(child1);
    _history.put(child2);
    _history.put(c1);
    _history.put(c2);
    _commit();
  }

  void _applyRenderingPipelinePreset() {
    if (_readOnly) return;
    _finishText();
    final center = _camera.toWorld(
      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
    );
    final baseX = center.x - 450;
    final baseY = center.y - 50;

    final r1 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text': 'Scene / Entities\nWorld Space Transforms',
      'x': baseX,
      'y': baseY,
      'width': 180.0,
      'height': 75.0,
      'color': 0xff6366f1,
    });
    final r2 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text': 'Camera View Matrix\nWorld-to-Camera Space',
      'x': baseX + 220,
      'y': baseY,
      'width': 180.0,
      'height': 75.0,
      'color': 0xff8b5cf6,
    });
    final r3 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text': 'Projection Matrix\nPerspective / NDC (Clip)',
      'x': baseX + 440,
      'y': baseY,
      'width': 180.0,
      'height': 75.0,
      'color': 0xff3b82f6,
    });
    final r4 = CanvasElement({
      'id': _id(),
      'type': 'card',
      'text': 'Viewport & Rasterizer\nScreen Coordinates & Draw',
      'x': baseX + 660,
      'y': baseY,
      'width': 180.0,
      'height': 75.0,
      'color': 0xff10b981,
    });

    final c1 = CanvasElement({
      'id': _id(),
      'type': 'connector',
      'startId': r1.id,
      'endId': r2.id,
      'color': 0xff6366f1,
    });
    final c2 = CanvasElement({
      'id': _id(),
      'type': 'connector',
      'startId': r2.id,
      'endId': r3.id,
      'color': 0xff8b5cf6,
    });
    final c3 = CanvasElement({
      'id': _id(),
      'type': 'connector',
      'startId': r3.id,
      'endId': r4.id,
      'color': 0xff3b82f6,
    });

    _history.put(r1);
    _history.put(r2);
    _history.put(r3);
    _history.put(r4);
    _history.put(c1);
    _history.put(c2);
    _history.put(c3);
    _commit();
  }

  void _createColumn() {
    _finishText();
    _cancelGesture();
    final members = _selection
        .map((id) => _scene[id])
        .whereType<CanvasElement>()
        .toList();
    if (members.any((e) => e.locked || e.type == 'column')) {
      _notice('Choose unlocked items. Nested columns are not supported yet.');
      return;
    }
    final center = _camera.toWorld(
      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
    );
    final column = CanvasElement({
      'id': _id(),
      'type': 'column',
      'text': 'Column',
      'x': members.isEmpty
          ? center.x - 140
          : members.map((e) => e.x).reduce(math.min) - 16,
      'y': members.isEmpty
          ? center.y - 100
          : members.map((e) => e.y).reduce(math.min) - 54,
      'width': 280.0,
      'height': 200.0,
      'color': _color,
    });
    for (final element in arrangeColumn(column, members)) {
      _history.put(element);
    }
    _selection
      ..clear()
      ..add(column.id);
    _commit();
    _edit(_scene[column.id]!);
  }

  Future<void> _addLink([CanvasElement? existing]) async {
    if (_readOnly || existing?.locked == true) return;
    _finishText();
    final title = TextEditingController(text: existing?.text);
    final url = TextEditingController(text: existing?.url);
    String? error;
    final value = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => OrbitDialog(
          title: const Text('Website link card'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: url,
                  decoration: InputDecoration(
                    labelText: 'https://…',
                    errorText: error,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final uri = Uri.tryParse(url.text.trim());
                if (uri == null ||
                    !{'http', 'https'}.contains(uri.scheme) ||
                    uri.host.isEmpty) {
                  update(
                    () => error = 'Enter a complete HTTP or HTTPS address.',
                  );
                  return;
                }
                Navigator.pop(context, {
                  'title': title.text.trim().isEmpty
                      ? uri.host
                      : title.text.trim(),
                  'url': uri.toString(),
                });
              },
              child: Text(existing == null ? 'Add link' : 'Save link'),
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(seconds: 1), () {
      title.dispose();
      url.dispose();
    });
    if (!mounted || value == null) {
      return;
    }
    if (_readOnly) return;
    if (existing != null) {
      final latest = _scene[existing.id];
      if (latest == null ||
          latest.locked ||
          !identical(latest.data, existing.data)) {
        return;
      }
      _history.put(latest.copy({'text': value['title'], 'url': value['url']}));
      _commit();
      return;
    }
    final center = _camera.toWorld(
      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
    );
    final element = CanvasElement({
      'id': _id(),
      'type': 'link',
      'x': center.x - 140,
      'y': center.y - 65,
      'width': 280.0,
      'height': 130.0,
      'text': value['title'],
      'url': value['url'],
      'color': _color,
    });
    _history.put(element);
    _selection
      ..clear()
      ..add(element.id);
    _commit();
  }

  bool _presentationMode = false;

  List<PopupMenuEntry<String>> _interactionItems() => [
    const PopupMenuItem(enabled: false, child: Text('CLASS DIAGRAM')),
    const PopupMenuItem(
      value: 'universityLab',
      child: Text('University Lab · states, activities, tests…'),
    ),
    const PopupMenuItem(value: 'newClass', child: Text('New UML class…')),
    const PopupMenuItem(
      value: 'classLink',
      child: Text('Connect UML classes…'),
    ),
    const PopupMenuItem(
      value: 'deriveClasses',
      child: Text('Class diagram from sequence…'),
    ),
    const PopupMenuDivider(),
    const PopupMenuItem(enabled: false, child: Text('USE-CASE DIAGRAM')),
    for (final kind in [
      UmlNodeKind.actor,
      UmlNodeKind.useCase,
      UmlNodeKind.system,
      UmlNodeKind.note,
    ])
      PopupMenuItem(
        value: kind.name,
        child: Text('New ${kind.label.toLowerCase()}…'),
      ),
    const PopupMenuItem(
      value: 'useLink',
      child: Text('Connect use-case items…'),
    ),
    const PopupMenuItem(
      value: 'useStarter',
      child: Text('Insert use-case starter'),
    ),
    const PopupMenuDivider(),
    const PopupMenuItem(enabled: false, child: Text('SEQUENCE DIAGRAM')),
    for (final kind in [
      UmlNodeKind.lifeline,
      UmlNodeKind.activation,
      UmlNodeKind.fragment,
    ])
      PopupMenuItem(
        value: kind.name,
        child: Text('New ${kind.label.toLowerCase()}…'),
      ),
    const PopupMenuItem(
      value: 'sequenceLink',
      child: Text('Connect sequence message…'),
    ),
    const PopupMenuItem(
      value: 'sequenceStarter',
      child: Text('Insert sequence starter'),
    ),
    if (_selection.length == 1 &&
        _scene[_selection.single] != null &&
        isInteractionItem(_scene[_selection.single]!)) ...[
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'editInteraction',
        child: Text('Edit selected diagram item…'),
      ),
    ],
  ];

  Future<void> _showInteractionTools({CanvasPoint? at}) async {
    if (_readOnly) return;
    final scene = _scene, revision = _scene.revision, epoch = _interactionEpoch;
    final action = await showDialog<String>(
      context: context,
      builder: (dialog) => OrbitDialog(
        title: const Text('Use-case & sequence diagrams'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in _interactionItems())
                  if (item is PopupMenuItem<String>)
                    ListTile(
                      title: item.child,
                      enabled: item.enabled,
                      onTap: item.enabled
                          ? () => Navigator.pop(dialog, item.value)
                          : null,
                    )
                  else
                    const Divider(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (!mounted ||
        action == null ||
        _readOnly ||
        !identical(scene, _scene) ||
        revision != _scene.revision ||
        epoch != _interactionEpoch) {
      return;
    }
    _interactionAction(action, at: at);
  }

  void _interactionAction(String action, {CanvasPoint? at}) {
    if (_readOnly) return;
    switch (action) {
      case 'universityLab':
        _openUniversityLab();
      case 'newClass':
        _editUml(at: at);
      case 'classLink':
        _editUml(relationship: true, at: at);
      case 'deriveClasses':
        _deriveClassDraft();
      case 'useLink':
        _editInteraction(at: at, link: true);
      case 'sequenceLink':
        _editInteraction(at: at, link: true, sequence: true);
      case 'editInteraction':
        final e = _selection.length == 1 ? _scene[_selection.single] : null;
        if (e != null && isInteractionItem(e)) {
          _editInteraction(
            element: e,
            sequence: umlLinkKind(e)?.sequence == true,
          );
        }
      case 'useStarter':
        _insertInteractionStarter(false);
      case 'sequenceStarter':
        _insertInteractionStarter(true);
      default:
        final kind = UmlNodeKind.values
            .where((v) => v.name == action)
            .firstOrNull;
        if (kind != null) _editInteraction(kind: kind, at: at);
    }
  }

  Future<void> _editInteraction({
    CanvasElement? element,
    UmlNodeKind? kind,
    bool link = false,
    bool sequence = false,
    CanvasPoint? at,
  }) async {
    if (_readOnly || element?.locked == true) return;
    _finishText();
    final scene = _scene,
        revision = _scene.revision,
        owner = widget.canvasId,
        epoch = _interactionEpoch;
    final nodes = scene.elementsInOrder
        .where(
          (e) =>
              !e.hidden &&
              isInteractionNode(e) &&
              (!sequence || umlNodeKind(e) == UmlNodeKind.lifeline),
        )
        .toList();
    if (link && nodes.isEmpty) {
      _notice(
        sequence
            ? 'Add a lifeline before connecting messages.'
            : 'Add actors and use cases before connecting them.',
      );
      return;
    }
    final selected = nodes.where((e) => _selection.contains(e.id)).toList();
    final original =
        element ??
        (link
            ? CanvasElement({
                'id': _id(),
                'type': 'connector',
                'strokeWidth': 1.5,
                'startId': (selected.firstOrNull ?? nodes.first).id,
                'endId': selected.length > 1 ? selected[1].id : null,
              })
            : newInteractionNode(
                _id(),
                kind!,
                at ??
                    _camera.toWorld(
                      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
                    ),
              ));
    final patch = await showInteractionEditor(
      context,
      original,
      nodes,
      sequence: sequence,
      creating: element == null,
    );
    if (!mounted || patch == null) return;
    if (_readOnly ||
        owner != widget.canvasId ||
        epoch != _interactionEpoch ||
        !identical(scene, _scene) ||
        scene.revision != revision ||
        element != null && !identical(element, scene[element.id])) {
      _notice(
        'The Canvas changed. Reopen the diagram editor to keep the latest changes.',
      );
      return;
    }
    var result = original.copy(patch);
    if (isConnectorElement(result)) {
      final points = resolveConnectorEndpoints(result, scene);
      result = result.copy(connectorEndpointData(points.start, points.end));
    }
    _history.put(result);
    if (umlLinkKind(result) == UmlLinkKind.destroy) {
      final target = _scene[result.endId!];
      if (target != null && !target.locked) {
        _history.put(
          target.copy({
            'umlNode': {...umlNodeDetails(target), 'destroyed': true},
          }),
        );
      }
    }
    if ([
          UmlNodeKind.system,
          UmlNodeKind.fragment,
        ].contains(umlNodeKind(result)) &&
        element == null) {
      _scene.sendToBack(result.id);
    }
    _selection
      ..clear()
      ..add(result.id);
    _commit();
    _focus.requestFocus();
  }

  void _insertInteractionStarter(bool sequence) {
    if (_readOnly) return;
    _finishText();
    final at = _camera.toWorld(
      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
    );
    final elements = sequence
        ? sequenceStarter(_id, at)
        : useCaseStarter(_id, at);
    for (final e in elements) {
      _history.put(e);
    }
    _selection
      ..clear()
      ..addAll(elements.map((e) => e.id));
    _commit();
    _fit(selectionOnly: true);
    _focus.requestFocus();
  }

  Future<void> _editUml({
    CanvasElement? element,
    bool relationship = false,
    CanvasPoint? at,
  }) async {
    if (_readOnly || element?.locked == true) return;
    _finishText();
    final scene = _scene, revision = _scene.revision, owner = widget.canvasId;
    final classes = _scene.elementsInOrder
        .where(isUmlClass)
        .where((e) => !e.hidden)
        .toList();
    if (relationship && element == null && classes.isEmpty) {
      _notice('Add a UML class first. One class can have a self-association.');
      return;
    }
    final position =
        at ??
        _camera.toWorld(CanvasPoint(_viewport.width / 2, _viewport.height / 2));
    final selectedClasses = classes
        .where((e) => _selection.contains(e.id))
        .toList();
    final original =
        element ??
        (relationship
            ? CanvasElement({
                'id': _id(),
                'type': 'connector',
                'startId': (selectedClasses.firstOrNull ?? classes.first).id,
                'endId': selectedClasses.length > 1
                    ? selectedClasses[1].id
                    : null,
                'color': 0xffa6b0bf,
                'strokeWidth': 1.5,
                ...UmlRelationship.association.style,
              })
            : newUmlClass(_id(), position));
    final patch = await showUmlEditor(
      context,
      original,
      classes,
      creating: element == null,
    );
    if (!mounted || patch == null) return;
    if (_readOnly ||
        owner != widget.canvasId ||
        !identical(scene, _scene) ||
        _scene.revision != revision ||
        (element != null && !identical(element, _scene[element.id]))) {
      _notice(
        'The canvas changed while editing. Reopen the UML editor to keep the latest changes.',
      );
      return;
    }
    var result = original.copy(patch);
    if (isConnectorElement(result)) {
      final endpoints = resolveConnectorEndpoints(result, _scene);
      result = result.copy(
        connectorEndpointData(endpoints.start, endpoints.end),
      );
    }
    _history.put(result);
    _selection
      ..clear()
      ..add(result.id);
    _commit();
    _focus.requestFocus();
  }

  Future<void> _deriveClassDraft() async {
    if (_readOnly) return;
    _finishText();
    _cancelGesture();
    final scene = _scene, revision = _scene.revision, owner = widget.canvasId;
    SequenceClassDraft draft;
    try {
      draft = draftClassesFromSequence(scene, _id, selection: _selection);
    } on FormatException catch (e) {
      _notice(e.message);
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => OrbitDialog(
        title: const Text('Review class diagram draft'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Derived from typed Canvas lifelines and messages. The sequence stays unchanged.',
                ),
                for (final e in draft.elements.where(isUmlClass))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      '${e.text}\n${UmlClass(e).operations.join('\n')}',
                    ),
                  ),
                Text(
                  '${draft.elements.where(isConnectorElement).length} association(s), including observed self-associations.',
                ),
                for (final edge in draft.elements.where(isConnectorElement))
                  Text(
                    '${draft.elements.firstWhere((e) => e.id == edge.startId).text} '
                    '${UmlNavigation.of(edge) == UmlNavigation.both ? '↔' : '→'} '
                    '${draft.elements.firstWhere((e) => e.id == edge.endId).text}',
                  ),
                for (final warning in draft.warnings)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(warning),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Insert draft'),
          ),
        ],
      ),
    );
    if (!mounted || accepted != true) return;
    if (_readOnly ||
        owner != widget.canvasId ||
        !identical(scene, _scene) ||
        revision != _scene.revision) {
      _notice('The canvas changed. Reopen the draft review.');
      return;
    }
    _history.begin();
    _scene.batch(() {
      for (final e in draft.elements) {
        _history.put(e);
      }
    });
    _selection
      ..clear()
      ..addAll(draft.elements.map((e) => e.id));
    _commit();
    _fit(selectionOnly: true);
    _focus.requestFocus();
  }

  Future<void> _openUniversityLab() async {
    if (_readOnly) return;
    _finishText();
    _cancelGesture();
    final owner = widget.canvasId, scene = _scene, revision = _scene.revision;
    try {
      var initial = universityModelFromSelection(scene, _selection);
      final previous = initial == null
          ? null
          : scene.elements
                .where(
                  (e) =>
                      e.data['universityModel'] is Map &&
                      (_selection.contains(e.id) ||
                          scene.elements.any(
                            (n) =>
                                _selection.contains(n.id) && n.groupId == e.id,
                          )),
                )
                .firstOrNull;
      if (initial == null && scene.elements.any(isUmlClass)) {
        initial = universityPreset(
          UniversityLabKind.uml,
        ).updated({'model': umlModelFromCanvas(scene)});
      }
      final result = await showUniversityLab(context, initial: initial);
      if (!mounted || result == null) return;
      if (_readOnly ||
          owner != widget.canvasId ||
          !identical(scene, _scene) ||
          revision != _scene.revision) {
        await recoverUniversityReport(
          context,
          result,
          'The Canvas changed. The newer scene was preserved.',
        );
        return;
      }
      final at = previous == null
          ? _camera.toWorld(
              CanvasPoint(_viewport.width / 2, _viewport.height / 2),
            )
          : CanvasPoint(previous.x, previous.y);
      final generated = universityDiagram(
        result,
        _id,
        at,
        existingFrame: previous,
        existing: previous == null
            ? const []
            : scene.elements.where((e) => e.groupId == previous.id).toList(),
      );
      if (previous != null) {
        final oldIds = previous.data['universityGeneratedIds'] is List
            ? (previous.data['universityGeneratedIds'] as List)
                  .whereType<String>()
                  .where((id) => _scene[id]?.groupId == previous.id)
                  .toSet()
            : <String>{};
        if ({previous.id, ...oldIds}.any((id) => _scene[id]?.locked == true)) {
          await recoverUniversityReport(
            context,
            result,
            'Unlock the university diagram before replacing it.',
          );
          return;
        }
        for (final id in oldIds) {
          _history.remove(id);
        }
        _history.remove(previous.id);
      }
      final frame = generated.first;
      final inserted = [
        frame.copy({
          'universityGeneratedIds': generated.skip(1).map((e) => e.id).toList(),
        }),
        ...generated.skip(1),
      ];
      for (final e in inserted) {
        _history.put(e);
      }
      _selection
        ..clear()
        ..addAll(inserted.map((e) => e.id));
      _commit();
      _fit(selectionOnly: true);
      _focus.requestFocus();
    } catch (error) {
      if (mounted) _notice('$error');
    }
  }

  void _addUmlExample() {
    if (_readOnly) return;
    _finishText();
    final at = _camera.toWorld(
      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
    );
    final elements = umlExample(_id, at);
    for (final e in elements) {
      _history.put(e);
    }
    _selection
      ..clear()
      ..addAll(elements.map((e) => e.id));
    _commit();
    _fit(selectionOnly: true);
    _focus.requestFocus();
  }

  Future<void> _addResearchDiagram() async {
    if (_readOnly) return;
    _finishText();
    final owner = widget.canvasId, before = _scene.toJson();
    final result = await showResearchDiagramDialog(context);
    if (!mounted || result == null) return;
    if (_readOnly ||
        owner != widget.canvasId ||
        !jsonValuesEqual(before, _scene.toJson())) {
      _notice(
        'The Canvas changed. Reopen the diagram preset before inserting.',
      );
      return;
    }
    final elements = researchDiagram(
      result.kind,
      _id,
      at: _camera.toWorld(
        CanvasPoint(_viewport.width / 2, _viewport.height / 2),
      ),
    );
    for (final e in elements) {
      _history.put(e);
    }
    _selection
      ..clear()
      ..addAll(elements.map((e) => e.id));
    _commit();
    _fit(selectionOnly: true);
    _focus.requestFocus();
  }

  void _addText({CanvasPoint? at}) {
    final pos =
        at ??
        _camera.toWorld(CanvasPoint(_viewport.width / 2, _viewport.height / 2));
    final element = CanvasElement({
      'id': _id(),
      'type': 'text',
      'x': pos.x,
      'y': pos.y,
      'width': 220.0,
      'height': 100.0,
      'color': _color,
      'text': 'Text',
    });
    _history.put(element);
    _selection
      ..clear()
      ..add(element.id);
    _commit();
    _edit(element);
  }

  void _addSticky({CanvasPoint? at}) {
    final pos =
        at ??
        _camera.toWorld(CanvasPoint(_viewport.width / 2, _viewport.height / 2));
    final element = CanvasElement({
      'id': _id(),
      'type': 'sticky',
      'x': pos.x,
      'y': pos.y,
      'width': 220.0,
      'height': 180.0,
      'color': _color,
      'text': 'An idea…',
    });
    _history.put(element);
    _selection
      ..clear()
      ..add(element.id);
    _commit();
    _edit(element);
  }

  void _addChecklist({CanvasPoint? at}) {
    final pos =
        at ??
        _camera.toWorld(CanvasPoint(_viewport.width / 2, _viewport.height / 2));
    final element = CanvasElement({
      'id': _id(),
      'type': 'sticky',
      'x': pos.x,
      'y': pos.y,
      'width': 240.0,
      'height': 200.0,
      'color': _color,
      'text': '# Tasks\n- [ ] Task 1\n- [ ] Task 2\n- [ ] Task 3',
    });
    _history.put(element);
    _selection
      ..clear()
      ..add(element.id);
    _commit();
    _edit(element);
  }

  Future<void> _addMathLab({CanvasPoint? at}) async {
    if (widget.readOnly || _scene.readOnly) return;
    _finishText();
    _cancelGesture();
    final owner = widget.canvasId;
    final original = jsonEncode(_scene.toJson());
    final pos =
        at ??
        _camera.toWorld(CanvasPoint(_viewport.width / 2, _viewport.height / 2));
    final result = await showMathLab(context);
    if (!mounted || result == null) return;
    if (owner != widget.canvasId ||
        widget.readOnly ||
        _scene.readOnly ||
        jsonEncode(_scene.toJson()) != original) {
      _notice('The Canvas changed. Reopen Math Lab before inserting.');
      return;
    }
    final elements = mathResultElements(result, pos, _color, _id);
    _selection.clear();
    for (final element in elements) {
      _history.put(element);
      _selection.add(element.id);
    }
    _commit();
    if (result.plotDefinition != null || result.tableDefinition != null) {
      _fit(selectionOnly: true);
    }
  }

  void _addFormulaCard({CanvasPoint? at}) {
    final pos =
        at ??
        _camera.toWorld(CanvasPoint(_viewport.width / 2, _viewport.height / 2));
    final element = CanvasElement({
      'id': _id(),
      'type': 'sticky',
      'x': pos.x,
      'y': pos.y,
      'width': 260.0,
      'height': 190.0,
      'color': _color,
      'text':
          '# Formula\n\$\$\nE = mc^2\n\$\$\n- \$e^{i\\pi} + 1 = 0\$\n- \$f(x) = \\int_0^t g(\\tau) d\\tau\$',
    });
    _history.put(element);
    _selection
      ..clear()
      ..add(element.id);
    _commit();
    _edit(element);
  }

  void _addSection({CanvasPoint? at}) {
    final pos =
        at ??
        _camera.toWorld(CanvasPoint(_viewport.width / 2, _viewport.height / 2));
    final element = CanvasElement({
      'id': _id(),
      'type': 'section',
      'x': pos.x - 180,
      'y': pos.y - 20,
      'width': 360.0,
      'height': 40.0,
      'text': 'SECTION TITLE',
      'color': _color,
    });
    _history.put(element);
    _selection
      ..clear()
      ..add(element.id);
    _commit();
    _edit(element);
  }

  void _addSwatch({CanvasPoint? at}) {
    final pos =
        at ??
        _camera.toWorld(CanvasPoint(_viewport.width / 2, _viewport.height / 2));
    final element = CanvasElement({
      'id': _id(),
      'type': 'swatch',
      'x': pos.x - 70,
      'y': pos.y - 80,
      'width': 140.0,
      'height': 160.0,
      'text': 'Color',
      'color': _color,
    });
    _history.put(element);
    _selection
      ..clear()
      ..add(element.id);
    _commit();
  }

  void _addAudioMemo({CanvasPoint? at}) {
    final pos =
        at ??
        _camera.toWorld(CanvasPoint(_viewport.width / 2, _viewport.height / 2));
    final element = CanvasElement({
      'id': _id(),
      'type': 'audio',
      'x': pos.x - 140,
      'y': pos.y - 45,
      'width': 280.0,
      'height': 90.0,
      'text': 'Voice Memo',
      'color': _color,
      'duration': '1:45',
      'progress': 0.35,
      'transcript':
          'Key insight: offline local-first state, universal object identity, and responsive bounded motion.',
    });
    _history.put(element);
    _selection
      ..clear()
      ..add(element.id);
    _commit();
  }

  void _addCard({CanvasPoint? at}) {
    final pos =
        at ??
        _camera.toWorld(CanvasPoint(_viewport.width / 2, _viewport.height / 2));
    final element = CanvasElement({
      'id': _id(),
      'type': 'card',
      'x': pos.x - 120,
      'y': pos.y - 60,
      'width': 240.0,
      'height': 120.0,
      'color': _color,
      'text': 'Card Title\nCard description…',
    });
    _history.put(element);
    _selection
      ..clear()
      ..add(element.id);
    _commit();
    _edit(element);
  }

  void _toggleLock() {
    final allLocked = _selection.every((id) => _scene[id]?.locked == true);
    for (final id in _selection) {
      final element = _scene[id];
      if (element != null) {
        _history.put(element.copy({'locked': !allLocked}));
      }
    }
    _commit();
  }

  Widget _toolbar(BuildContext context) {
    final tools = <(_Tool, IconData, String)>[
      (_Tool.select, Icons.near_me_outlined, 'Select (V)'),
      (_Tool.lasso, Icons.gesture, 'Lasso selection (L)'),
      (_Tool.pan, Icons.pan_tool_outlined, 'Pan (H / Space)'),
      (_Tool.sticky, Icons.sticky_note_2_outlined, 'Sticky note (S)'),
      (_Tool.text, Icons.title, 'Text (T)'),
      (_Tool.pen, Icons.draw_outlined, 'Pen (P)'),
      (_Tool.highlighter, Icons.brush_outlined, 'Highlighter (Y)'),
      (_Tool.eraser, Icons.auto_fix_normal, 'Erase strokes (E)'),
    ];
    return OrbitWorkbenchToolbar(
      label: 'Canvas',
      icon: Icons.space_dashboard_outlined,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            children: [
              if (widget.onToggleFocusMode != null)
                IconButton(
                  tooltip: widget.focusMode
                      ? 'Exit Canvas focus'
                      : 'Focus on drawing',
                  onPressed: widget.onToggleFocusMode,
                  icon: Icon(
                    widget.focusMode ? Icons.fullscreen_exit : Icons.fullscreen,
                  ),
                ),
              for (final item in tools.take(3))
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: OrbitControl(
                    tooltip: item.$3,
                    selected: _tool == item.$1,
                    onPressed:
                        _readOnly &&
                            item.$1 != _Tool.pan &&
                            item.$1 != _Tool.select
                        ? null
                        : () => _setTool(item.$1),
                    icon: item.$2,
                  ),
                ),
              const OrbitToolbarDivider(),
              PopupMenuButton<_Tool>(
                tooltip: 'Text and notes',
                enabled: !_readOnly,
                initialValue: _tool,
                onSelected: _setTool,
                icon: Icon(
                  _tool == _Tool.sticky
                      ? Icons.sticky_note_2_outlined
                      : Icons.title,
                  size: 20,
                  color: _tool == _Tool.text || _tool == _Tool.sticky
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                itemBuilder: (_) => [
                  for (final item in tools.skip(3).take(2))
                    PopupMenuItem(
                      value: item.$1,
                      child: Row(
                        children: [
                          Icon(item.$2, size: 18),
                          const SizedBox(width: 12),
                          Text(item.$3),
                        ],
                      ),
                    ),
                ],
              ),
              PopupMenuButton<_Tool>(
                tooltip: 'Draw and erase',
                enabled: !_readOnly,
                initialValue: _tool,
                onSelected: _setTool,
                icon: Icon(
                  Icons.draw_outlined,
                  size: 20,
                  color: tools.skip(5).any((item) => item.$1 == _tool)
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                itemBuilder: (_) => [
                  for (final item in tools.skip(5))
                    PopupMenuItem(
                      value: item.$1,
                      child: Row(
                        children: [
                          Icon(item.$2, size: 18),
                          const SizedBox(width: 12),
                          Text(item.$3),
                        ],
                      ),
                    ),
                ],
              ),
              if (_tool == _Tool.pen ||
                  _tool == _Tool.highlighter ||
                  _tool == _Tool.eraser) ...[
                const SizedBox(width: 4),
                Container(
                  height: 22,
                  width: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                const SizedBox(width: 4),
                if (_tool == _Tool.pen) ...[
                  PopupMenuButton<String>(
                    tooltip: 'Pen style ($_penStyle)',
                    initialValue: _penStyle,
                    onSelected: (style) {
                      setState(() {
                        _penStyle = style;
                        if (style == 'marker' && _penStrokeWidth < 5.0) {
                          _penStrokeWidth = 6.0;
                        } else if (style == 'ballpoint' &&
                            _penStrokeWidth > 6.0) {
                          _penStrokeWidth = 2.5;
                        } else if (style == 'pencil' && _penStrokeWidth > 4.0) {
                          _penStrokeWidth = 2.0;
                        } else if (style == 'calligraphy' &&
                            _penStrokeWidth < 3.0) {
                          _penStrokeWidth = 4.0;
                        } else if (style == 'brush' && _penStrokeWidth < 4.0) {
                          _penStrokeWidth = 5.0;
                        }
                      });
                      _cameraChanged();
                    },
                    icon: Icon(
                      _penStyle == 'fountain'
                          ? Icons.gesture
                          : _penStyle == 'marker'
                          ? Icons.edit
                          : _penStyle == 'pencil'
                          ? Icons.create_outlined
                          : _penStyle == 'calligraphy'
                          ? Icons.history_edu
                          : _penStyle == 'brush'
                          ? Icons.brush
                          : Icons.draw_outlined,
                      size: 20,
                    ),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'ballpoint',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.draw_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Ballpoint'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'pencil',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.create_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Pencil'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'calligraphy',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history_edu, size: 18),
                            SizedBox(width: 8),
                            Text('Calligraphy'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'brush',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.brush, size: 18),
                            SizedBox(width: 8),
                            Text('Brush'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'fountain',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.gesture, size: 18),
                            SizedBox(width: 8),
                            Text('Fountain'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'marker',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Marker'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  PopupMenuButton<double>(
                    tooltip:
                        'Pen thickness (${_penStrokeWidth.toStringAsFixed(1)}px)',
                    initialValue: _penStrokeWidth,
                    onSelected: (w) {
                      setState(() => _penStrokeWidth = w);
                      _cameraChanged();
                    },
                    icon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 14,
                          height: math.max(
                            2.0,
                            math.min(10.0, _penStrokeWidth),
                          ),
                          decoration: BoxDecoration(
                            color: Color(_color),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _penStrokeWidth.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 1.5, child: Text('Fine (1.5px)')),
                      PopupMenuItem(value: 3.0, child: Text('Medium (3.0px)')),
                      PopupMenuItem(value: 6.0, child: Text('Bold (6.0px)')),
                      PopupMenuItem(value: 12.0, child: Text('Thick (12.0px)')),
                      PopupMenuItem(value: 20.0, child: Text('Heavy (20.0px)')),
                    ],
                  ),
                ],
                if (_tool == _Tool.eraser)
                  PopupMenuButton<double>(
                    tooltip: 'Eraser radius (${_eraserRadius.round()}px)',
                    initialValue: _eraserRadius,
                    onSelected: (r) {
                      setState(() => _eraserRadius = r);
                      _cameraChanged();
                    },
                    icon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_fix_normal, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${_eraserRadius.round()}px',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 10.0, child: Text('Small (10px)')),
                      PopupMenuItem(value: 20.0, child: Text('Medium (20px)')),
                      PopupMenuItem(value: 36.0, child: Text('Large (36px)')),
                    ],
                  ),
                IconButton(
                  tooltip: _fingerDraws
                      ? 'Finger inking enabled (tap to pan only)'
                      : 'Palm rejection active: Stylus draws, finger pans',
                  isSelected: _fingerDraws,
                  icon: Icon(
                    _fingerDraws ? Icons.touch_app : Icons.front_hand_outlined,
                    size: 19,
                  ),
                  onPressed: () => setState(() => _fingerDraws = !_fingerDraws),
                ),
                if (_tool == _Tool.pen || _tool == _Tool.highlighter) ...[
                  IconButton(
                    tooltip: _rulerMode
                        ? 'Ruler mode active: Drawing straight lines'
                        : 'Ruler / Straight line assist (Shift or R)',
                    isSelected: _rulerMode,
                    icon: Icon(
                      Icons.straighten,
                      size: 19,
                      color: _rulerMode
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    onPressed: () => setState(() => _rulerMode = !_rulerMode),
                  ),
                  IconButton(
                    tooltip: _autoRecognizeInk
                        ? 'Auto-recognize ink active: Converts handwriting to text & shapes (K)'
                        : 'Auto-recognize ink to text & shapes (disabled, shortcut K)',
                    isSelected: _autoRecognizeInk,
                    icon: Icon(
                      Icons.auto_fix_high,
                      size: 19,
                      color: _autoRecognizeInk
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    onPressed: () =>
                        setState(() => _autoRecognizeInk = !_autoRecognizeInk),
                  ),
                  const SizedBox(width: 2),
                  for (final c in const [
                    0xff8b7cf6,
                    0xff6f7fea,
                    0xff65c6a3,
                    0xffd8b56a,
                    0xffe57582,
                    0xff334155,
                    _technicalWhite,
                  ])
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setState(() => _color = c);
                        _cameraChanged();
                        for (final id in _selection) {
                          final elem = _scene[id];
                          if (elem != null && !elem.locked) {
                            _history.put(elem.copy({'color': c}));
                          }
                        }
                        _commit();
                      },
                      child: Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == c
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant
                                      .withValues(alpha: 0.5),
                            width: _color == c ? 2.0 : 1.0,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 2),
                ],
                Container(
                  height: 22,
                  width: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                const SizedBox(width: 4),
              ],
              PopupMenuButton<String>(
                tooltip: 'Shapes and diagrams',
                enabled: !_readOnly,
                icon: const Icon(Icons.category_outlined, size: 21),
                itemBuilder: (_) => [
                  for (final item in <(_Tool, IconData, String)>[
                    (_Tool.rectangle, Icons.crop_square, 'Rectangle'),
                    (_Tool.ellipse, Icons.circle_outlined, 'Ellipse'),
                    (_Tool.diamond, Icons.diamond_outlined, 'Diamond'),
                    (_Tool.arrow, Icons.arrow_right_alt, 'Arrow'),
                    (_Tool.line, Icons.horizontal_rule, 'Line'),
                    (_Tool.frame, Icons.filter_frames_outlined, 'Frame'),
                  ])
                    PopupMenuItem(
                      value: item.$1.name,
                      child: Row(
                        children: [
                          Icon(item.$2, size: 20),
                          const SizedBox(width: 12),
                          Text(item.$3),
                        ],
                      ),
                    ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'class',
                    child: Text('New UML class…'),
                  ),
                  const PopupMenuItem(
                    value: 'interaction_tools',
                    child: Text('Use-case & sequence diagrams…'),
                  ),
                  const PopupMenuItem(
                    value: 'relationship',
                    child: Text('Connect UML classes…'),
                  ),
                  const PopupMenuItem(
                    value: 'deriveClasses',
                    child: Text('Class diagram from sequence…'),
                  ),
                  if (_selection.length == 1 &&
                      (isUmlClass(_scene[_selection.single]!) ||
                          _scene[_selection.single]!.data['umlRelationship']
                              is String))
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit selected UML item…'),
                    ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'example',
                    child: Text('Insert UML example'),
                  ),
                  const PopupMenuItem(
                    value: 'research',
                    child: Text('Memory & research diagram…'),
                  ),
                  const PopupMenuDivider(),
                  if (widget.onExportDiagramToNote != null)
                    const PopupMenuItem(
                      value: 'exportDiagram',
                      child: Text('Export diagram to Markdown…'),
                    ),
                  const PopupMenuItem(
                    value: 'copyDiagram',
                    child: Text('Copy live diagram for Markdown'),
                  ),
                ],
                onSelected: (action) {
                  switch (action) {
                    case 'class':
                      _editUml();
                    case 'interaction_tools':
                      _showInteractionTools();
                    case 'relationship':
                      _editUml(relationship: true);
                    case 'deriveClasses':
                      _deriveClassDraft();
                    case 'edit':
                      _editUml(element: _scene[_selection.single]);
                    case 'example':
                      _addUmlExample();
                    case 'research':
                      _addResearchDiagram();
                    case 'exportDiagram':
                      _exportUmlDiagram();
                    case 'copyDiagram':
                      _exportUmlDiagram(copy: true);
                    default:
                      _setTool(_Tool.values.byName(action));
                  }
                },
              ),
              if (_scene.elements.any(
                (e) => !e.hidden && umlNodeKind(e) == UmlNodeKind.useCase,
              ))
                IconButton(
                  key: const ValueKey('canvas-organize-use-cases'),
                  tooltip: 'Organize use-case diagram',
                  icon: const Icon(
                    Icons.auto_awesome_mosaic_outlined,
                    size: 21,
                  ),
                  onPressed: _readOnly ? null : _organizeUseCases,
                ),
              IconButton(
                key: const ValueKey('canvas-search-button'),
                tooltip: 'Search canvas (Ctrl+F)',
                isSelected: _showSearchHud,
                icon: Icon(
                  Icons.search,
                  size: 20,
                  color: _showSearchHud
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                onPressed: _toggleSearchHud,
              ),
              const SizedBox(width: 8),
              if (widget.onCaptureReferences != null)
                IconButton(
                  key: const ValueKey('canvas-capture-references'),
                  tooltip: 'Import reference files',
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 20,
                  ),
                  onPressed: _readOnly ? null : widget.onCaptureReferences,
                ),
              PopupMenuButton<String>(
                tooltip: 'Add / organize board content',
                enabled: !_readOnly,
                icon: const Icon(Icons.add_box_outlined, size: 20),
                itemBuilder: (_) => [
                  if (widget.onCaptureReferences != null)
                    const PopupMenuItem(
                      value: 'captureReferences',
                      child: Text('Import reference files…'),
                    ),
                  if (_selection.length == 1 &&
                      _scene[_selection.single]?.type == 'card')
                    PopupMenuItem(
                      value: 'referenceDetails',
                      enabled: _scene[_selection.single]?.locked != true,
                      child: const Text('Edit reference details…'),
                    ),
                  if (_selection.length == 1 &&
                      _scene[_selection.single]?.data['referenceSourceUrl']
                          is String &&
                      widget.onOpenExternal != null)
                    const PopupMenuItem(
                      value: 'referenceSource',
                      child: Text('Open reference source'),
                    ),
                  if (_selection.any((id) => _scene[id]?.type == 'card'))
                    for (final state in referenceStates)
                      PopupMenuItem(
                        value: 'referenceState:$state',
                        child: Text('Mark references: $state'),
                      ),
                  if (widget.onExportSelectionToNote != null &&
                      _scene.elements.any(
                        (e) => e.data['referenceStatus'] is String,
                      ))
                    const PopupMenuItem(
                      value: 'referenceSummary',
                      child: Text('Create linked reference summary'),
                    ),
                  PopupMenuItem(
                    value: 'column',
                    child: Text(
                      _selection.isEmpty
                          ? 'New column'
                          : 'Create column from selection',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'checklist',
                    child: Text('New checklist / tasklist'),
                  ),
                  const PopupMenuItem(
                    value: 'mathLab',
                    child: Text('Math Lab · calculate & plot'),
                  ),
                  const PopupMenuItem(
                    value: 'formula',
                    child: Text('Formula / math card'),
                  ),
                  const PopupMenuItem(
                    value: 'link',
                    child: Text('Website link card'),
                  ),
                  if (_selection.length == 1 &&
                      _scene[_selection.first]?.type == 'link')
                    PopupMenuItem(
                      value: 'editLink',
                      enabled: _scene[_selection.first]?.locked != true,
                      child: const Text('Edit selected link'),
                    ),
                  const PopupMenuItem(
                    value: 'section',
                    child: Text('Section divider'),
                  ),
                  const PopupMenuItem(
                    value: 'swatch',
                    child: Text('Color swatch card'),
                  ),
                  const PopupMenuItem(
                    value: 'audio',
                    child: Text('Voice memo / audio card'),
                  ),
                  if (_selection.isNotEmpty)
                    PopupMenuItem(
                      value: 'toggleLock',
                      child: Text(
                        _selection.every((id) => _scene[id]?.locked == true)
                            ? 'Unlock selection'
                            : 'Lock selection',
                      ),
                    ),
                  if (_selection.length == 1 &&
                      _scene[_selection.first]?.type == 'swatch')
                    const PopupMenuItem(
                      value: 'copyHex',
                      child: Text('Copy HEX code'),
                    ),
                  if (_selection.length == 1 &&
                      _scene[_selection.first]?.type == 'column')
                    const PopupMenuItem(
                      value: 'tidy',
                      child: Text('Tidy column'),
                    ),
                  if (_selection.any(
                    (id) => _scene[id]?.data['columnId'] != null,
                  ))
                    const PopupMenuItem(
                      value: 'detach',
                      child: Text('Remove from column'),
                    ),
                ],
                onSelected: (action) {
                  if (action == 'captureReferences') {
                    widget.onCaptureReferences?.call();
                  }
                  if (action == 'referenceDetails') _editReferenceDetails();
                  if (action == 'referenceSource') {
                    final raw =
                        _scene[_selection.single]?.data['referenceSourceUrl'];
                    final uri = raw is String ? Uri.tryParse(raw) : null;
                    if (uri != null &&
                        {'http', 'https'}.contains(uri.scheme) &&
                        uri.host.isNotEmpty &&
                        uri.userInfo.isEmpty) {
                      widget.onOpenExternal?.call(uri);
                    }
                  }
                  if (action.startsWith('referenceState:')) {
                    final status = action.substring('referenceState:'.length);
                    for (final id in _selection) {
                      final e = _scene[id];
                      if (e != null && e.type == 'card' && !e.locked) {
                        _history.put(e.copy({'referenceStatus': status}));
                      }
                    }
                    _commit();
                  }
                  if (action == 'referenceSummary') {
                    final refs = _scene.elements
                        .where(
                          (e) =>
                              e.data['referenceStatus'] is String &&
                              (_selection.isEmpty || _selection.contains(e.id)),
                        )
                        .toList();
                    if (refs.isNotEmpty) {
                      widget.onExportSelectionToNote?.call(
                        refs,
                        referenceSummaryMarkdown(
                          widget.canvasId,
                          widget.title,
                          refs,
                          {for (final o in _objects.values) o.id: o.title},
                        ),
                      );
                    } else {
                      _notice(
                        'Select reference cards or clear the selection to summarize the board.',
                      );
                    }
                  }
                  if (action == 'checklist') {
                    _addChecklist();
                  }
                  if (action == 'mathLab') _addMathLab();
                  if (action == 'formula') {
                    _addFormulaCard();
                  }
                  if (action == 'link') {
                    _addLink();
                  }
                  if (action == 'editLink') _addLink(_scene[_selection.single]);
                  if (action == 'section') _addSection();
                  if (action == 'swatch') _addSwatch();
                  if (action == 'audio') _addAudioMemo();
                  if (action == 'toggleLock') _toggleLock();
                  if (action == 'copyHex') {
                    final element = _scene[_selection.single];
                    if (element != null) {
                      final hex =
                          '#${(element.color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
                      Clipboard.setData(ClipboardData(text: hex));
                      _notice('Color $hex copied to clipboard');
                    }
                  }
                  if (action == 'column') {
                    _createColumn();
                  }
                  if (action == 'tidy') {
                    final column = _scene[_selection.single]!;
                    for (final element in arrangeColumn(
                      column,
                      columnMembers(_scene, column.id),
                    )) {
                      _history.put(element);
                    }
                    _commit();
                  }
                  if (action == 'detach') {
                    for (final id in _selection) {
                      final element = _scene[id];
                      if (element != null && !element.locked) {
                        _history.put(element.copy({'columnId': null}));
                      }
                    }
                    _commit();
                  }
                },
              ),
              if (_selection.length >= 2 && !_readOnly)
                PopupMenuButton<CanvasAlignment>(
                  tooltip: 'Align selected elements',
                  icon: const Icon(Icons.align_horizontal_left, size: 20),
                  onSelected: _align,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: CanvasAlignment.left,
                      child: Row(
                        children: [
                          Icon(Icons.align_horizontal_left, size: 16),
                          SizedBox(width: 8),
                          Expanded(child: Text('Align Left')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: CanvasAlignment.centerH,
                      child: Row(
                        children: [
                          Icon(Icons.align_horizontal_center, size: 16),
                          SizedBox(width: 8),
                          Expanded(child: Text('Horizontal Center')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: CanvasAlignment.right,
                      child: Row(
                        children: [
                          Icon(Icons.align_horizontal_right, size: 16),
                          SizedBox(width: 8),
                          Expanded(child: Text('Align Right')),
                        ],
                      ),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: CanvasAlignment.top,
                      child: Row(
                        children: [
                          Icon(Icons.align_vertical_top, size: 16),
                          SizedBox(width: 8),
                          Expanded(child: Text('Align Top')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: CanvasAlignment.middleV,
                      child: Row(
                        children: [
                          Icon(Icons.align_vertical_center, size: 16),
                          SizedBox(width: 8),
                          Expanded(child: Text('Vertical Middle')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: CanvasAlignment.bottom,
                      child: Row(
                        children: [
                          Icon(Icons.align_vertical_bottom, size: 16),
                          SizedBox(width: 8),
                          Expanded(child: Text('Align Bottom')),
                        ],
                      ),
                    ),
                    if (_selection.length >= 3) ...[
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: CanvasAlignment.distributeH,
                        child: Row(
                          children: [
                            Icon(Icons.horizontal_distribute, size: 16),
                            SizedBox(width: 8),
                            Expanded(child: Text('Distribute Horizontally')),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: CanvasAlignment.distributeV,
                        child: Row(
                          children: [
                            Icon(Icons.vertical_distribute, size: 16),
                            SizedBox(width: 8),
                            Expanded(child: Text('Distribute Vertically')),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              if (_selection.isNotEmpty)
                IconButton(
                  key: const ValueKey('canvas-remove-selection'),
                  tooltip: 'Remove from canvas (Delete)',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed:
                      !_readOnly &&
                          _selection.any((id) => _scene[id]?.locked == false)
                      ? _delete
                      : null,
                ),
              if (_selection.isNotEmpty)
                PopupMenuButton<String>(
                  tooltip: 'Selection actions',
                  icon: const Icon(Icons.more_horiz, size: 20),
                  onSelected: (action) {
                    switch (action) {
                      case 'edit':
                        _edit(_scene[_selection.single]!);
                      case 'duplicate':
                        _duplicate();
                      case 'lock':
                        _toggleLock();
                      case 'focus':
                        _fit(selectionOnly: true);
                      case 'delete':
                        _delete();
                    }
                  },
                  itemBuilder: (_) => [
                    if (_selection.length == 1)
                      PopupMenuItem(
                        value: 'edit',
                        enabled:
                            !_readOnly &&
                            _scene[_selection.single]?.locked != true,
                        child: const Text('Edit or open'),
                      ),
                    PopupMenuItem(
                      value: 'duplicate',
                      enabled: !_readOnly,
                      child: const Text('Duplicate'),
                    ),
                    PopupMenuItem(
                      value: 'lock',
                      enabled: !_readOnly,
                      child: Text(
                        _selection.every((id) => _scene[id]?.locked == true)
                            ? 'Unlock selection'
                            : 'Lock selection',
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'focus',
                      child: Text('Focus selection'),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      enabled: !_readOnly,
                      child: const Text('Remove from canvas'),
                    ),
                  ],
                ),
              PopupMenuButton<String>(
                tooltip: 'Insert object or image',
                enabled: !_readOnly,
                icon: const Icon(Icons.add_link, size: 20),
                onSelected: (value) {
                  if (value == 'object') _chooseObject();
                  if (value == 'image') _insertImage(widget.onInsertImage!);
                  if (value == 'paste') _insertImage(widget.onPasteImage!);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'object',
                    child: Text('Place object'),
                  ),
                  if (widget.onInsertImage != null)
                    const PopupMenuItem(
                      value: 'image',
                      child: Text('Insert image'),
                    ),
                  if (widget.onPasteImage != null)
                    const PopupMenuItem(
                      value: 'paste',
                      child: Text('Paste image'),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              if (_selection.isNotEmpty ||
                  _tool != _Tool.select && _tool != _Tool.pan)
                PopupMenuButton<int>(
                  tooltip: 'Color',
                  onSelected: (value) {
                    setState(() {
                      _color = value;
                    });
                    for (final id in _selection) {
                      final element = _scene[id];
                      if (element != null && !element.locked) {
                        _history.put(element.copy({'color': value}));
                      }
                    }
                    _commit();
                  },
                  icon: Icon(Icons.circle, color: Color(_color), size: 20),
                  enabled: !_readOnly,
                  itemBuilder: (_) => [
                    for (final value in [
                      0xff8b7cf6,
                      0xff6f7fea,
                      0xff65c6a3,
                      0xffd8b56a,
                      0xffe57582,
                      _technicalWhite,
                    ])
                      PopupMenuItem(
                        value: value,
                        child: Row(
                          children: [
                            Icon(Icons.circle, color: Color(value)),
                            const SizedBox(width: 12),
                            Text(
                              {
                                0xff8b7cf6: 'Violet',
                                0xff6f7fea: 'Blue',
                                0xff65c6a3: 'Mint',
                                0xffd8b56a: 'Amber',
                                0xffe57582: 'Rose',
                                _technicalWhite: 'Technical white',
                              }[value]!,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              if (_selection.length == 1 &&
                  (_scene[_selection.first]?.type == 'arrow' ||
                      _scene[_selection.first]?.type == 'line' ||
                      _scene[_selection.first]?.type == 'connector') &&
                  !_readOnly) ...[
                PopupMenuButton<String>(
                  tooltip: 'Stroke Style',
                  icon: const Icon(Icons.line_weight, size: 20),
                  onSelected: _setConnectorStyle,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'solid', child: Text('Solid')),
                    PopupMenuItem(value: 'dashed', child: Text('Dashed')),
                    PopupMenuItem(value: 'dotted', child: Text('Dotted')),
                  ],
                ),
                PopupMenuButton<String>(
                  tooltip: 'Routing',
                  icon: const Icon(Icons.alt_route, size: 20),
                  onSelected: _setConnectorRouting,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'straight', child: Text('Straight')),
                    PopupMenuItem(value: 'curved', child: Text('Curved')),
                    PopupMenuItem(
                      value: 'orthogonal',
                      child: Text('Orthogonal'),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  tooltip: 'Start Marker',
                  icon: const Icon(Icons.west, size: 20),
                  onSelected: (m) => _setConnectorMarker(m, isStart: true),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'none', child: Text('None (Start)')),
                    PopupMenuItem(value: 'arrow', child: Text('Arrow (Start)')),
                    PopupMenuItem(value: 'dot', child: Text('Dot (Start)')),
                    PopupMenuItem(
                      value: 'diamond',
                      child: Text('Diamond (Start)'),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  tooltip: 'End Marker',
                  icon: const Icon(Icons.east, size: 20),
                  onSelected: (m) => _setConnectorMarker(m),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'arrow', child: Text('Arrow (End)')),
                    PopupMenuItem(value: 'dot', child: Text('Dot (End)')),
                    PopupMenuItem(
                      value: 'diamond',
                      child: Text('Diamond (End)'),
                    ),
                    PopupMenuItem(value: 'none', child: Text('None (End)')),
                  ],
                ),
                PopupMenuButton<String>(
                  tooltip: 'Start Anchor',
                  icon: const Icon(Icons.north_west, size: 20),
                  onSelected: (a) => _setConnectorAnchor(a, isStart: true),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'auto',
                      child: Text('Start Anchor: Auto'),
                    ),
                    PopupMenuItem(
                      value: 'top',
                      child: Text('Start Anchor: Top'),
                    ),
                    PopupMenuItem(
                      value: 'bottom',
                      child: Text('Start Anchor: Bottom'),
                    ),
                    PopupMenuItem(
                      value: 'left',
                      child: Text('Start Anchor: Left'),
                    ),
                    PopupMenuItem(
                      value: 'right',
                      child: Text('Start Anchor: Right'),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  tooltip: 'End Anchor',
                  icon: const Icon(Icons.south_east, size: 20),
                  onSelected: (a) => _setConnectorAnchor(a, isStart: false),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'auto',
                      child: Text('End Anchor: Auto'),
                    ),
                    PopupMenuItem(value: 'top', child: Text('End Anchor: Top')),
                    PopupMenuItem(
                      value: 'bottom',
                      child: Text('End Anchor: Bottom'),
                    ),
                    PopupMenuItem(
                      value: 'left',
                      child: Text('End Anchor: Left'),
                    ),
                    PopupMenuItem(
                      value: 'right',
                      child: Text('End Anchor: Right'),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Reverse Direction',
                  icon: const Icon(Icons.swap_horiz, size: 20),
                  onPressed: _reverseConnector,
                ),
              ],
              if (_selection.isNotEmpty &&
                  _selection.every((id) => _scene[id]?.type == 'section') &&
                  !_readOnly) ...[
                PopupMenuButton<String>(
                  tooltip: 'Section Header Size',
                  icon: const Icon(Icons.format_size, size: 20),
                  onSelected: _setSectionHeaderSize,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'small', child: Text('Small (13px)')),
                    PopupMenuItem(
                      value: 'medium',
                      child: Text('Medium (18px)'),
                    ),
                    PopupMenuItem(value: 'large', child: Text('Large (24px)')),
                    PopupMenuItem(
                      value: 'xlarge',
                      child: Text('Extra Large (32px)'),
                    ),
                    PopupMenuItem(value: 'huge', child: Text('Huge (42px)')),
                  ],
                ),
                IconButton(
                  tooltip: 'Decrease Header Size',
                  icon: const Icon(Icons.text_decrease, size: 20),
                  onPressed: () => _adjustSectionSize(increase: false),
                ),
                IconButton(
                  tooltip: 'Increase Header Size',
                  icon: const Icon(Icons.text_increase, size: 20),
                  onPressed: () => _adjustSectionSize(increase: true),
                ),
                PopupMenuButton<double>(
                  tooltip: 'Line Thickness',
                  icon: const Icon(Icons.horizontal_rule, size: 20),
                  onSelected: _setSectionLineThickness,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 1.0, child: Text('Hairline (1.0px)')),
                    PopupMenuItem(value: 1.5, child: Text('Standard (1.5px)')),
                    PopupMenuItem(value: 2.5, child: Text('Medium (2.5px)')),
                    PopupMenuItem(value: 4.0, child: Text('Thick (4.0px)')),
                    PopupMenuItem(value: 6.0, child: Text('Heavy (6.0px)')),
                  ],
                ),
              ],
              IconButton(
                tooltip: _snap
                    ? 'Grid snapping on (Alt bypass)'
                    : 'Grid snapping off',
                isSelected: _snap,
                onPressed: () => setState(() {
                  _snap = !_snap;
                }),
                icon: const Icon(Icons.grid_4x4, size: 20),
              ),
              PopupMenuButton<String>(
                tooltip: 'Canvas paper style',
                icon: const Icon(Icons.grain, size: 20),
                enabled: !_readOnly,
                initialValue: _backgroundStyle,
                onSelected: (val) {
                  if (val == 'blueprint_preset') {
                    _applyArchitecturalBlueprintPreset();
                    return;
                  }
                  if (val == 'blueprint_classic') {
                    _applyArchitecturalBlueprintPreset(style: val);
                    return;
                  }
                  setState(() {
                    _backgroundStyle = val;
                    if (val == 'blueprint' || val == 'blueprint_classic') {
                      _color = _technicalWhite;
                      _penStyle = 'ballpoint';
                      _penStrokeWidth = 1.5;
                    }
                  });
                  _emit();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'dots',
                    child: Text('Dot grid (Default)'),
                  ),
                  PopupMenuItem(value: 'grid', child: Text('Standard grid')),
                  PopupMenuItem(
                    value: 'graph',
                    child: Text('Engineering graph paper'),
                  ),
                  PopupMenuItem(
                    value: 'cornell',
                    child: Text('Cornell Notes layout'),
                  ),
                  PopupMenuItem(
                    value: 'lines',
                    child: Text('Ruled notebook lines'),
                  ),
                  PopupMenuItem(
                    value: 'ruled',
                    child: Text('Student / Legal ruled margin'),
                  ),
                  PopupMenuItem(
                    value: 'isometric',
                    child: Text('Isometric 3D grid'),
                  ),
                  PopupMenuItem(
                    value: 'cross',
                    child: Text('Cross / Reticle grid (+)'),
                  ),
                  PopupMenuItem(
                    value: 'hex',
                    child: Text('Hexagonal / Honeycomb grid'),
                  ),
                  PopupMenuItem(
                    value: 'blueprint',
                    child: Text('Architectural blueprint grid'),
                  ),
                  PopupMenuItem(
                    value: 'blueprint_preset',
                    child: Text('Architectural drafting preset · white pen'),
                  ),
                  PopupMenuItem(
                    value: 'blueprint_classic',
                    child: Text('Traditional blueprint · white drawing'),
                  ),
                  PopupMenuItem(
                    value: 'music',
                    child: Text('Music manuscript staff'),
                  ),
                  PopupMenuItem(
                    value: 'ledger',
                    child: Text('Columnar / Accounting ledger'),
                  ),
                  PopupMenuItem(
                    value: 'triangular',
                    child: Text('Equilateral triangular grid'),
                  ),
                  PopupMenuItem(value: 'blank', child: Text('Blank paper')),
                ],
              ),
              PopupMenuButton<String>(
                tooltip: 'Apply workspace preset (Study / Game Dev)',
                icon: const Icon(Icons.dashboard_customize_outlined, size: 20),
                enabled: !_readOnly,
                onSelected: (preset) {
                  switch (preset) {
                    case 'save_personal_template':
                      widget.onSavePersonalTemplate?.call();
                    case 'exercise':
                      _applyExercisePreset();
                    case 'study_board':
                      _applyStudyBoardPreset();
                    case 'course_map':
                      _applyCourseMapPreset();
                    case 'game_roadmap':
                      _applyGameRoadmapPreset();
                    case 'core_loop':
                      _applyCoreLoopPreset();
                    case 'level_design':
                      _applyLevelDesignPreset();
                    case 'ai_state_machine':
                      _applyAiStateMachinePreset();
                    case 'moodboard':
                      _applyMoodboardPreset();
                    case 'playtest_feedback':
                      _applyPlaytestFeedbackPreset();
                    case 'narrative_board':
                      _applyNarrativeBoardPreset();
                    case 'game_architecture':
                      _applyGameArchitecturePreset();
                    case 'call_flow':
                      _applyCallFlowPreset();
                    case 'object_relationships':
                      _applyObjectRelationshipsPreset();
                    case 'structure_layout':
                      _applyStructureLayoutPreset();
                    case 'binary_layout':
                      _applyBinaryLayoutPreset();
                    case 'protocol_flow':
                      _applyProtocolFlowPreset();
                    case 'process_tree':
                      _applyProcessTreePreset();
                    case 'rendering_pipeline':
                      _applyRenderingPipelinePreset();
                  }
                },
                itemBuilder: (_) => [
                  if (widget.onSavePersonalTemplate != null)
                    const PopupMenuItem(
                      value: 'save_personal_template',
                      child: Text('Save as personal template…'),
                    ),
                  const PopupMenuItem(
                    enabled: false,
                    child: Text(
                      'STUDY / MATH PRESETS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'exercise',
                    child: Row(
                      children: [
                        Icon(Icons.edit_note, size: 16),
                        SizedBox(width: 8),
                        Text('Exercise canvas'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'study_board',
                    child: Row(
                      children: [
                        Icon(Icons.dashboard_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Study board (Milanote style)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'course_map',
                    child: Row(
                      children: [
                        Icon(Icons.account_tree_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Visual course map'),
                      ],
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    enabled: false,
                    child: Text(
                      'GAME DEV PRESETS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'game_roadmap',
                    child: Row(
                      children: [
                        Icon(Icons.timeline, size: 16),
                        SizedBox(width: 8),
                        Text('Milestone Roadmap'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'core_loop',
                    child: Row(
                      children: [
                        Icon(Icons.loop, size: 16),
                        SizedBox(width: 8),
                        Text('Core Gameplay Loop'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'level_design',
                    child: Row(
                      children: [
                        Icon(Icons.map_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Level Beat & Flow Map'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'ai_state_machine',
                    child: Row(
                      children: [
                        Icon(Icons.psychology_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('AI Behavior State Machine'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'moodboard',
                    child: Row(
                      children: [
                        Icon(Icons.palette_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Art Moodboard & Colors'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'playtest_feedback',
                    child: Row(
                      children: [
                        Icon(Icons.rate_review_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Playtest Feedback Board'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'narrative_board',
                    child: Row(
                      children: [
                        Icon(Icons.auto_stories_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Narrative & Quest Board'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'game_architecture',
                    child: Row(
                      children: [
                        Icon(Icons.memory, size: 16),
                        SizedBox(width: 8),
                        Text('Game Architecture & Systems'),
                      ],
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    enabled: false,
                    child: Text(
                      'REVERSE ENGINEERING / RESEARCH',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'call_flow',
                    child: Row(
                      children: [
                        Icon(Icons.call_split, size: 16),
                        SizedBox(width: 8),
                        Text('Call Flow Diagram'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'object_relationships',
                    child: Row(
                      children: [
                        Icon(Icons.hub_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Object Relationships'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'structure_layout',
                    child: Row(
                      children: [
                        Icon(Icons.table_rows_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Memory Structure Layout'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'binary_layout',
                    child: Row(
                      children: [
                        Icon(Icons.format_shapes_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Binary / PE Layout'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'protocol_flow',
                    child: Row(
                      children: [
                        Icon(Icons.compare_arrows, size: 16),
                        SizedBox(width: 8),
                        Text('Protocol Packet Flow'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'process_tree',
                    child: Row(
                      children: [
                        Icon(Icons.account_tree, size: 16),
                        SizedBox(width: 8),
                        Text('Process Execution Tree'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'rendering_pipeline',
                    child: Row(
                      children: [
                        Icon(Icons.view_in_ar, size: 16),
                        SizedBox(width: 8),
                        Text('Rendering Pipeline'),
                      ],
                    ),
                  ),
                ],
              ),
              const OrbitToolbarDivider(),
              if (_images?.failedReferences.isNotEmpty ?? false)
                IconButton(
                  tooltip: 'Retry unavailable images',
                  onPressed: () => _images?.invalidateAll(),
                  icon: const Icon(Icons.refresh),
                ),
              IconButton(
                tooltip: _readOnly
                    ? 'Undo · This Canvas is read-only'
                    : _history.canUndo
                    ? 'Undo (Ctrl+Z)'
                    : 'Undo · No earlier Canvas edit',
                onPressed: !_readOnly && _history.canUndo ? _undo : null,
                icon: const Icon(Icons.undo, size: 20),
              ),
              IconButton(
                tooltip: _readOnly
                    ? 'Redo · This Canvas is read-only'
                    : _history.canRedo
                    ? 'Redo (Ctrl+Shift+Z)'
                    : 'Redo · No undone Canvas edit',
                onPressed: !_readOnly && _history.canRedo ? _redo : null,
                icon: const Icon(Icons.redo, size: 20),
              ),
              IconButton(
                tooltip: 'Layers & element list',
                onPressed: _showElementList,
                icon: const Icon(Icons.layers_outlined, size: 20),
              ),
              PopupMenuButton<String>(
                tooltip: 'Brainstorming & workshops',
                icon: const Icon(Icons.lightbulb_outline, size: 21),
                itemBuilder: (_) => _brainstormItems(),
                onSelected: _brainstormAction,
              ),
              PopupMenuButton<String>(
                tooltip: 'Canvas motion & presentation',
                icon: Icon(
                  _laserMode ? Icons.gesture : Icons.slow_motion_video,
                  size: 21,
                ),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'replay',
                    child: Text('Replay board or selection…'),
                  ),
                  PopupMenuItem(
                    value: 'laser',
                    child: Text(
                      _laserMode
                          ? 'Exit laser pointer'
                          : 'Temporary laser pointer',
                    ),
                  ),
                ],
                onSelected: (action) {
                  _cancelGesture();
                  _finishText();
                  if (action == 'laser') {
                    setState(() => _laserMode = !_laserMode);
                  } else {
                    setState(() => _laserMode = false);
                    showCanvasPresentation(
                      context,
                      scene: _scene,
                      objects: _objects,
                      images: _images?.images ?? const {},
                      selection: _selection,
                      fontFamily: widget.fontFamily,
                      background: _backgroundStyle,
                    );
                  }
                },
              ),
              IconButton(
                tooltip:
                    'University Lab · state/activity diagrams, tests and distributed systems',
                onPressed: _readOnly ? null : _openUniversityLab,
                icon: const Icon(Icons.school_outlined, size: 21),
              ),
              PopupMenuButton<String>(
                tooltip: 'Use-case and sequence diagrams',
                enabled: !_readOnly,
                icon: const Icon(Icons.account_tree_outlined, size: 21),
                itemBuilder: (_) => _interactionItems(),
                onSelected: _interactionAction,
              ),
              IconButton(
                tooltip: 'Canvas template library',
                onPressed: _readOnly ? null : _showStarterLibrary,
                icon: const Icon(Icons.auto_stories_outlined, size: 20),
              ),
              if (_selection.isNotEmpty)
                PopupMenuButton<String>(
                  tooltip: 'Layer order',
                  enabled: _selection.isNotEmpty && !_readOnly,
                  icon: const Icon(Icons.flip_to_front_outlined, size: 20),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'front',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Bring to Front'),
                          SizedBox(width: 12),
                          Text(
                            'Shift+]',
                            style: TextStyle(
                              fontSize: 11,
                              color: OrbitColors.of(context).muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'forward',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Bring Forward'),
                          SizedBox(width: 12),
                          Text(
                            ']',
                            style: TextStyle(
                              fontSize: 11,
                              color: OrbitColors.of(context).muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'backward',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Send Backward'),
                          SizedBox(width: 12),
                          Text(
                            '[',
                            style: TextStyle(
                              fontSize: 11,
                              color: OrbitColors.of(context).muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'back',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Send to Back'),
                          SizedBox(width: 12),
                          Text(
                            'Shift+[',
                            style: TextStyle(
                              fontSize: 11,
                              color: OrbitColors.of(context).muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (action) => _reorder(action),
                ),
              if (_selection.length >= 2)
                PopupMenuButton<CanvasArrangement>(
                  tooltip: 'Arrange selected placements',
                  enabled: _selection.length >= 2,
                  icon: const Icon(Icons.align_horizontal_left, size: 20),
                  itemBuilder: (_) => [
                    for (final action in CanvasArrangement.values)
                      PopupMenuItem(value: action, child: Text(action.label)),
                  ],
                  onSelected: (action) => _applyArrangement(action),
                ),
              if (_selection.length >= 2 ||
                  _selection.any((id) => _scene[id]?.groupId != null))
                PopupMenuButton<String>(
                  tooltip: 'Group (Ctrl+G) / Ungroup (Ctrl+Shift+G)',
                  enabled:
                      !_readOnly &&
                      (_selection.length >= 2 ||
                          _selection.any((id) => _scene[id]?.groupId != null)),
                  icon: const Icon(Icons.workspaces_outlined, size: 20),
                  itemBuilder: (_) => [
                    if (_selection.length >= 2)
                      const PopupMenuItem(
                        value: 'group',
                        child: Text('Group (Ctrl+G)'),
                      ),
                    if (_selection.any((id) => _scene[id]?.groupId != null))
                      const PopupMenuItem(
                        value: 'ungroup',
                        child: Text('Ungroup (Ctrl+Shift+G)'),
                      ),
                  ],
                  onSelected: (action) {
                    if (action == 'group') _groupSelection();
                    if (action == 'ungroup') _ungroupSelection();
                  },
                ),
              const OrbitToolbarDivider(),
              IconButton(
                tooltip: 'Import diagrams & templates (Ctrl+I)',
                icon: const Icon(Icons.file_upload_outlined, size: 20),
                onPressed: _showImportDialog,
              ),
              IconButton(
                tooltip: 'Export canvas (PNG, SVG, JSON)',
                icon: const Icon(Icons.file_download_outlined, size: 20),
                onPressed: _showExportDialog,
              ),
              if (_editingId != null)
                TextButton(onPressed: _finishText, child: const Text('Done')),
            ],
          ),
        ),
      ),
    );
  }
}

class CanvasMinimapPainter extends CustomPainter {
  CanvasMinimapPainter({
    required this.scene,
    required this.camera,
    required this.viewportSize,
    required this.colors,
    this.semanticColors,
    this.searchMatchIds = const {},
    this.activeSearchMatchId,
    this.pictureCache,
  }) : sceneRevision = scene.revision;

  final CanvasPictureCache? pictureCache;
  final int sceneRevision;
  final CanvasScene scene;
  final CanvasCamera camera;
  final Size viewportSize;
  final ColorScheme colors;
  final OrbitColors? semanticColors;
  Color get _warning => semanticColors?.warning ?? colors.secondary;
  Color get _success => semanticColors?.success ?? colors.tertiary;
  final Set<String> searchMatchIds;
  final String? activeSearchMatchId;

  static (Rect contentRect, double scale, double offsetX, double offsetY)
  layout(
    CanvasScene scene,
    CanvasCamera camera,
    Size viewportSize,
    Size minimapSize,
  ) {
    CanvasBounds? bounds = scene.contentBounds;
    final viewWorld = camera.viewport(viewportSize.width, viewportSize.height);
    bounds = bounds == null ? viewWorld : bounds.union(viewWorld);
    const margin = 80.0;
    final contentRect = Rect.fromLTRB(
      bounds.left - margin,
      bounds.top - margin,
      bounds.right + margin,
      bounds.bottom + margin,
    );
    final scaleX = (minimapSize.width - 12) / math.max(1.0, contentRect.width);
    final scaleY =
        (minimapSize.height - 12) / math.max(1.0, contentRect.height);
    final scale = math.min(scaleX, scaleY);
    final offsetX =
        6.0 + (minimapSize.width - 12 - contentRect.width * scale) / 2;
    final offsetY =
        6.0 + (minimapSize.height - 12 - contentRect.height * scale) / 2;
    return (contentRect, scale, offsetX, offsetY);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final (contentRect, scale, offsetX, offsetY) = layout(
      scene,
      camera,
      viewportSize,
      size,
    );

    void paintMap(Canvas canvas) {
      // Spatial Radar: Concentric range rings & crosshair guide
      final center = Offset(
        offsetX + (contentRect.width / 2) * scale,
        offsetY + (contentRect.height / 2) * scale,
      );
      final maxDim = math.max(contentRect.width, contentRect.height) * scale;
      final radarRingPaint = Paint()
        ..color = colors.primary.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      for (final factor in [0.25, 0.50, 0.75, 1.0]) {
        final radius = (maxDim / 2) * factor;
        if (radius > 8) {
          canvas.drawCircle(center, radius, radarRingPaint);
        }
      }
      final crosshairPaint = Paint()
        ..color = colors.primary.withValues(alpha: 0.16)
        ..strokeWidth = 0.8;
      canvas.drawLine(
        Offset(center.dx - 10, center.dy),
        Offset(center.dx + 10, center.dy),
        crosshairPaint,
      );
      canvas.drawLine(
        Offset(center.dx, center.dy - 10),
        Offset(center.dx, center.dy + 10),
        crosshairPaint,
      );

      // Spatial miniature elements with type color coding
      for (final element in scene.elements) {
        if (!element.renderable || element.hidden) continue;
        if (element.type == 'connector' ||
            element.type == 'arrow' ||
            element.type == 'line') {
          continue;
        }
        final elRect = Rect.fromLTWH(
          offsetX + (element.bounds.left - contentRect.left) * scale,
          offsetY + (element.bounds.top - contentRect.top) * scale,
          math.max(2.5, element.bounds.width * scale),
          math.max(2.5, element.bounds.height * scale),
        );

        Color elColor;
        PaintingStyle style = PaintingStyle.fill;
        double strokeWidth = 0;

        final isTransclusion =
            element.type == 'card' &&
            element.data['presentation'] == 'transclusion';
        if (isTransclusion) {
          elColor = colors.secondary;
        } else if (element.type == 'card') {
          elColor = colors.primary; // Blue for standard cards
        } else if (element.type == 'ink' || element.type == 'stroke') {
          elColor = colors.secondary; // Purple for ink
        } else if (element.type == 'frame' || element.type == 'section') {
          elColor = _warning; // Amber for frames
          style = PaintingStyle.stroke;
          strokeWidth = 1.0;
        } else if (element.type == 'rectangle' ||
            element.type == 'ellipse' ||
            element.type == 'diamond') {
          elColor = _success; // Emerald for shapes
        } else if (element.type == 'audio') {
          elColor = colors.secondary; // Cyan for audio
        } else {
          elColor = Color(element.color);
        }

        final elPaint = Paint()
          ..color = elColor.withValues(
            alpha: style == PaintingStyle.stroke ? 0.75 : 0.65,
          )
          ..style = style;
        if (strokeWidth > 0) elPaint.strokeWidth = strokeWidth;

        canvas.drawRRect(
          RRect.fromRectAndRadius(elRect, const Radius.circular(1.5)),
          elPaint,
        );

        // If transclusion card, draw tiny center sync dot
        if (isTransclusion) {
          canvas.drawCircle(
            elRect.center,
            1.0,
            Paint()..color = colors.surface,
          );
        }
      }

      // Search match radar pings & active targeting rings
      if (searchMatchIds.isNotEmpty) {
        final radarDotPaint = Paint()
          ..color =
              _warning // Amber radar ping
          ..style = PaintingStyle.fill;
        final radarGlowPaint = Paint()
          ..color = _warning.withValues(alpha: 0.35)
          ..style = PaintingStyle.fill;

        for (final element in scene.elements) {
          if (!element.renderable || element.hidden) continue;
          if (!searchMatchIds.contains(element.id)) continue;

          final elCenterX =
              offsetX + (element.bounds.center.x - contentRect.left) * scale;
          final elCenterY =
              offsetY + (element.bounds.center.y - contentRect.top) * scale;
          final pingCenter = Offset(elCenterX, elCenterY);

          final isActive = element.id == activeSearchMatchId;

          // Draw radar glow halo
          canvas.drawCircle(pingCenter, isActive ? 6.0 : 4.0, radarGlowPaint);
          // Draw solid center dot
          canvas.drawCircle(pingCenter, isActive ? 3.0 : 2.0, radarDotPaint);

          // Active targeting ring
          if (isActive) {
            final targetPaint = Paint()
              ..color = _warning
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4;
            canvas.drawCircle(pingCenter, 7.5, targetPaint);
          }
        }
      }
    }

    final cache = pictureCache;
    if (cache == null) {
      paintMap(canvas);
    } else {
      cache.draw(canvas, (
        scene,
        sceneRevision,
        contentRect,
        scale,
        offsetX,
        offsetY,
        colors,
        semanticColors,
        (searchMatchIds.toList()..sort())
            .map((id) => '${id.length}:$id')
            .join(),
        activeSearchMatchId,
      ), paintMap);
    }

    // Viewport indicator with tactical radar brackets
    final vpRect = Rect.fromLTWH(
      offsetX + (camera.x - contentRect.left) * scale,
      offsetY + (camera.y - contentRect.top) * scale,
      (viewportSize.width / camera.zoom) * scale,
      (viewportSize.height / camera.zoom) * scale,
    );
    final vpFill = Paint()
      ..color = colors.primary.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    final vpStroke = Paint()
      ..color = colors.primary
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(vpRect, const Radius.circular(2)),
      vpFill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(vpRect, const Radius.circular(2)),
      vpStroke,
    );

    final bracketPaint = Paint()
      ..color = colors.primary
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    final bLen = math.min(5.0, math.min(vpRect.width / 3, vpRect.height / 3));
    if (bLen >= 1.5) {
      canvas.drawLine(
        Offset(vpRect.left, vpRect.top + bLen),
        Offset(vpRect.left, vpRect.top),
        bracketPaint,
      );
      canvas.drawLine(
        Offset(vpRect.left, vpRect.top),
        Offset(vpRect.left + bLen, vpRect.top),
        bracketPaint,
      );
      canvas.drawLine(
        Offset(vpRect.right - bLen, vpRect.bottom),
        Offset(vpRect.right, vpRect.bottom),
        bracketPaint,
      );
      canvas.drawLine(
        Offset(vpRect.right, vpRect.bottom - bLen),
        Offset(vpRect.right, vpRect.bottom),
        bracketPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CanvasMinimapPainter oldDelegate) =>
      !identical(scene, oldDelegate.scene) ||
      sceneRevision != oldDelegate.sceneRevision ||
      camera.x != oldDelegate.camera.x ||
      camera.y != oldDelegate.camera.y ||
      camera.zoom != oldDelegate.camera.zoom ||
      viewportSize != oldDelegate.viewportSize ||
      colors != oldDelegate.colors ||
      semanticColors != oldDelegate.semanticColors ||
      !setEquals(searchMatchIds, oldDelegate.searchMatchIds) ||
      activeSearchMatchId != oldDelegate.activeSearchMatchId;
}

class _FormatButton extends StatelessWidget {
  const _FormatButton({
    this.icon,
    this.label,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData? icon;
  final String? label;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: colors.onSurfaceVariant),
                if (label != null) const SizedBox(width: 4),
              ],
              if (label != null)
                Text(
                  label!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CanvasCardPreviewTooltip extends StatelessWidget {
  const CanvasCardPreviewTooltip({
    super.key,
    required this.element,
    required this.object,
    required this.objects,
    required this.onOpen,
    required this.onToggleTask,
    required this.onCyclePresentation,
    required this.onDismiss,
    required this.onEnterTooltip,
    required this.onExitTooltip,
    this.onCopyQuote,
    this.onOpenSource,
    this.onOpenLinkedObject,
  });

  final CanvasElement element;
  final CanvasObjectReference? object;
  final Map<String, CanvasObjectReference> objects;
  final VoidCallback onOpen;
  final ValueChanged<String> onToggleTask;
  final VoidCallback onCyclePresentation;
  final VoidCallback onDismiss;
  final VoidCallback onEnterTooltip;
  final VoidCallback onExitTooltip;
  final Future<void> Function()? onCopyQuote;
  final VoidCallback? onOpenSource;
  final ValueChanged<String>? onOpenLinkedObject;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isTask =
        (object?.typeId == 'orbit.task') || element.data['isTask'] == true;
    final isDone = object?.isCompleted ?? (element.data['isDone'] == true);
    final nestedData = element.data['data'] is Map
        ? (element.data['data'] as Map)
        : const {};
    final rawQuote = element.data['quote'] is String
        ? element.data['quote'] as String
        : (nestedData['quote'] is String
              ? nestedData['quote'] as String
              : null);
    final rawPage =
        (element.data['page'] as num?)?.toInt() ??
        (nestedData['page'] as num?)?.toInt() ??
        1;
    final rawSourceTitle =
        element.data['sourceTitle'] as String? ??
        (nestedData['sourceTitle'] as String?) ??
        object?.title ??
        'PDF Document';
    final rawChecksum = element.data['checksum'] is String
        ? element.data['checksum'] as String
        : (nestedData['checksum'] is String
              ? nestedData['checksum'] as String
              : null);
    final quoteData = (rawQuote != null && rawQuote.trim().isNotEmpty)
        ? {
            'quote': rawQuote.trim(),
            'page': rawPage,
            'sourceTitle': rawSourceTitle,
            'color': element.color != 0 ? element.color : null,
            ...?(rawChecksum != null ? {'checksum': rawChecksum} : null),
          }
        : null;
    final pdfSource = object?.pdfSource == null && quoteData == null
        ? null
        : <String, dynamic>{...?quoteData, ...?object?.pdfSource};
    final sourceId =
        pdfSource?['objectId'] ??
        pdfSource?['sourceId'] ??
        element.data['sourceId'] ??
        nestedData['sourceId'];
    final sourceObject = sourceId is String ? objects[sourceId] : null;
    final storedSourceChecksum = pdfSource?['checksum'] is String
        ? pdfSource!['checksum'] as String
        : null;
    final currentSourceChecksum = sourceObject?.properties['checksum'] is String
        ? sourceObject!.properties['checksum'] as String
        : (object?.properties['checksum'] is String
              ? object!.properties['checksum'] as String
              : null);
    final sourceVersionStale =
        storedSourceChecksum != null &&
        currentSourceChecksum != null &&
        storedSourceChecksum != currentSourceChecksum;
    final isPdfQuote = pdfSource != null;
    final isPdf = (object?.isPdf ?? false) && !isPdfQuote;
    final isImage = object?.isImage ?? (element.data['contentRef'] != null);
    final viewConfig = element.viewConfig;
    final isDynamicView = viewConfig != null;
    final savedView =
        objects[(viewConfig?['view'] ?? viewConfig?['viewId'])?.toString()];

    final title = (isPdfQuote && rawSourceTitle.isNotEmpty)
        ? rawSourceTitle
        : (object?.title.isNotEmpty == true
              ? object!.title
              : (viewConfig?['title'] as String? ??
                    (element.text.trim().isNotEmpty
                        ? element.text.trim().split('\n').first.trim()
                        : 'Card')));

    final currentPresentation = element.cardPresentation;

    return MouseRegion(
      onEnter: (_) => onEnterTooltip(),
      onExit: (_) => onExitTooltip(),
      child: Material(
        color: colors.surfaceContainerHighest,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Container(
          width: math.min(350, MediaQuery.sizeOf(context).width),
          constraints: BoxConstraints(
            maxHeight: math.min(
              400,
              math.max(
                0,
                MediaQuery.sizeOf(context).height -
                    MediaQuery.viewInsetsOf(context).bottom -
                    32,
              ),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Type badge + Actions
              Row(
                children: [
                  Icon(
                    isTask
                        ? (isDone
                              ? Icons.check_circle
                              : Icons.check_box_outlined)
                        : (isPdfQuote
                              ? Icons.format_quote_outlined
                              : (isPdf
                                    ? Icons.picture_as_pdf_outlined
                                    : (isImage
                                          ? Icons.image_outlined
                                          : (isDynamicView
                                                ? Icons.saved_search_outlined
                                                : Icons
                                                      .description_outlined)))),
                    size: 16,
                    color: isDone
                        ? OrbitColors.of(context).success
                        : (isPdfQuote
                              ? (pdfSource['color'] is int
                                    ? Color(pdfSource['color'] as int)
                                    : OrbitColors.of(context).danger)
                              : (isPdf
                                    ? OrbitColors.of(context).danger
                                    : (isDynamicView
                                          ? OrbitColors.of(context).accent
                                          : colors.primary))),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isDynamicView
                          ? 'SAVED VIEW · ${(viewConfig['type'] ?? 'VIEW').toString().toUpperCase()}'
                          : (object?.pdfSource != null
                                ? 'PDF HIGHLIGHT · P. ${pdfSource?['page'] ?? 1}'
                                : (isPdfQuote
                                      ? 'PDF CITATION · P. ${pdfSource['page'] ?? 1}'
                                      : (isTask
                                            ? (isDone
                                                  ? 'TASK (COMPLETED)'
                                                  : 'TASK (OPEN)')
                                            : (isPdf
                                                  ? 'PDF DOCUMENT'
                                                  : (isImage
                                                        ? 'IMAGE'
                                                        : (object?.typeId
                                                                  .replaceFirst(
                                                                    'orbit.',
                                                                    '',
                                                                  )
                                                                  .toUpperCase() ??
                                                              'CARD')))))),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: isDone
                            ? OrbitColors.of(context).success
                            : (isPdf
                                  ? OrbitColors.of(context).danger
                                  : colors.onSurfaceVariant),
                      ),
                    ),
                  ),
                ],
              ),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  Tooltip(
                    message:
                        'Cycle presentation (${currentPresentation.toUpperCase()})',
                    child: InkWell(
                      key: const ValueKey(
                        'canvas-card-tooltip-cycle-presentation',
                      ),
                      borderRadius: BorderRadius.circular(4),
                      onTap: onCyclePresentation,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Icon(
                          currentPresentation == 'compact'
                              ? Icons.view_compact_outlined
                              : (currentPresentation == 'preview'
                                    ? Icons.preview_outlined
                                    : (currentPresentation == 'transclusion'
                                          ? Icons.sync_alt
                                          : (currentPresentation == 'properties'
                                                ? Icons.list_alt_outlined
                                                : Icons.dashboard_outlined))),
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (object != null) ...[
                    Tooltip(
                      message: 'Open in editor',
                      child: InkWell(
                        key: const ValueKey('canvas-card-tooltip-open'),
                        borderRadius: BorderRadius.circular(4),
                        onTap: onOpen,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Icon(
                            Icons.open_in_new,
                            size: 16,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (onCopyQuote != null)
                    Tooltip(
                      message: 'Copy citation text',
                      child: InkWell(
                        key: const ValueKey('canvas-card-tooltip-copy-quote'),
                        borderRadius: BorderRadius.circular(4),
                        onTap: () => onCopyQuote!(),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Icon(
                            Icons.content_copy_outlined,
                            size: 16,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  if (onOpenSource != null)
                    Tooltip(
                      message: isPdfQuote
                          ? 'Open PDF source'
                          : 'Open original attachment',
                      child: InkWell(
                        key: const ValueKey('canvas-card-tooltip-open-source'),
                        borderRadius: BorderRadius.circular(4),
                        onTap: onOpenSource,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Icon(
                            isPdfQuote
                                ? Icons.picture_as_pdf_outlined
                                : Icons.open_in_new,
                            size: 16,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  Tooltip(
                    message: 'Dismiss',
                    child: InkWell(
                      key: const ValueKey('canvas-card-tooltip-dismiss'),
                      borderRadius: BorderRadius.circular(4),
                      onTap: onDismiss,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          decoration: isDone
                              ? TextDecoration.lineThrough
                              : null,
                          color: isDone
                              ? colors.onSurfaceVariant
                              : colors.onSurface,
                        ),
                      ),
                      if (sourceVersionStale) ...[
                        const SizedBox(height: 6),
                        Tooltip(
                          message:
                              'The source PDF changed after this citation was created. Open the source to verify it.',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: colors.errorContainer.withValues(
                                alpha: 0.55,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 15,
                                  color: colors.onErrorContainer,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    'Source changed · verify citation',
                                    style: TextStyle(
                                      color: colors.onErrorContainer,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),

                      // Content details
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Task specific preview
                          if (isTask) ...[
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: Checkbox(
                                    key: const ValueKey(
                                      'canvas-card-tooltip-checkbox',
                                    ),
                                    value: isDone,
                                    onChanged: (_) {
                                      if (object != null) {
                                        onToggleTask(object!.id);
                                      }
                                    },
                                  ),
                                ),
                                Text(
                                  isDone ? 'Completed' : 'Open task',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDone
                                        ? OrbitColors.of(context).success
                                        : colors.onSurface,
                                  ),
                                ),
                                if (object?.priority != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      object!.priority!,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: colors.primary,
                                      ),
                                    ),
                                  ),
                                if (object?.dueDate != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.surfaceContainer,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      object!.dueDate!,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (object?.body.isNotEmpty == true) ...[
                              const SizedBox(height: 6),
                              Text(
                                object!.body
                                    .replaceAll(RegExp(r'[#*`\[\]]'), '')
                                    .trim(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.onSurfaceVariant,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],

                          // PDF Highlight specific preview
                          if (pdfSource != null) ...[
                            Container(
                              padding: const EdgeInsets.all(8),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border(
                                  left: BorderSide(
                                    color: pdfSource['color'] is int
                                        ? Color(pdfSource['color'] as int)
                                        : colors.primary,
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Text(
                                '“${(pdfSource['quote'] as String? ?? '').trim()}”',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: colors.onSurface,
                                ),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (object?.body.isNotEmpty == true &&
                                object!.typeId != 'orbit.file' &&
                                object!.body.trim() !=
                                    (pdfSource['quote'] as String? ?? '')
                                        .trim()) ...[
                              const SizedBox(height: 4),
                              Text(
                                object!.body
                                    .replaceAll(RegExp(r'[#*`\[\]]'), '')
                                    .trim(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.onSurfaceVariant,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],

                          // Dynamic view live preview (CAN-09)
                          if (isDynamicView) ...[
                            () {
                              if (savedView?.viewMemberIds != null ||
                                  savedView?.viewQueryIssue != null) {
                                final ids =
                                    savedView?.viewMemberIds ??
                                    const <String>[];
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      savedView?.viewQueryIssue ??
                                          '${ids.length} matching objects',
                                    ),
                                    for (final id in ids.take(5))
                                      if (objects[id] != null)
                                        TextButton(
                                          onPressed: onOpenLinkedObject == null
                                              ? null
                                              : () => onOpenLinkedObject!(id),
                                          child: Text(
                                            objects[id]!.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                  ],
                                );
                              }
                              final vType = viewConfig['type'] ?? 'tasks';
                              if (vType == 'tasks') {
                                var tasks = objects.values
                                    .where((o) => o.typeId == 'orbit.task')
                                    .toList();
                                final statusFilter =
                                    viewConfig['status'] as String? ?? 'all';
                                if (statusFilter == 'open') {
                                  tasks = tasks
                                      .where((t) => !t.isCompleted)
                                      .toList();
                                } else if (statusFilter == 'completed') {
                                  tasks = tasks
                                      .where((t) => t.isCompleted)
                                      .toList();
                                }
                                final totalTasks = objects.values
                                    .where((o) => o.typeId == 'orbit.task')
                                    .length;
                                final doneTasks = objects.values
                                    .where(
                                      (o) =>
                                          o.typeId == 'orbit.task' &&
                                          o.isCompleted,
                                    )
                                    .length;
                                final pct = totalTasks > 0
                                    ? (doneTasks / totalTasks)
                                    : 0.0;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '$doneTasks of $totalTasks tasks done',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                        Text(
                                          '${(pct * 100).toInt()}%',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: OrbitColors.of(
                                              context,
                                            ).accent,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        value: pct,
                                        minHeight: 6,
                                        backgroundColor: colors.outlineVariant
                                            .withValues(alpha: 0.3),
                                        valueColor: AlwaysStoppedAnimation(
                                          OrbitColors.of(context).accent,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    for (final task in tasks.take(4))
                                      InkWell(
                                        borderRadius: BorderRadius.circular(4),
                                        onTap: () => onToggleTask(task.id),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                task.isCompleted
                                                    ? Icons.check_circle
                                                    : Icons
                                                          .radio_button_unchecked,
                                                size: 14,
                                                color: task.isCompleted
                                                    ? OrbitColors.of(
                                                        context,
                                                      ).success
                                                    : colors.onSurfaceVariant,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  task.title,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    decoration: task.isCompleted
                                                        ? TextDecoration
                                                              .lineThrough
                                                        : null,
                                                    color: task.isCompleted
                                                        ? colors
                                                              .onSurfaceVariant
                                                        : colors.onSurface,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              }
                              return const SizedBox.shrink();
                            }(),
                          ],

                          // Project & folder metadata
                          if (object?.project != null || object?.folder != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.folder_outlined,
                                    size: 12,
                                    color: colors.outline,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      [
                                        if (object?.folder != null)
                                          object!.folder,
                                        if (object?.project != null)
                                          object!.project,
                                      ].join(' / '),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: colors.outline,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Tags
                          if (object?.tags.isNotEmpty ?? false)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  for (final tag in object!.tags.take(4))
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        '#$tag',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: colors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                          // Note excerpt (when not a dynamic view and not a PDF highlight with quote)
                          if (!isTask &&
                              pdfSource == null &&
                              !isDynamicView &&
                              (object?.body.isNotEmpty == true))
                            Text(
                              object!.body
                                  .replaceAll(RegExp(r'[#*`\[\]]'), '')
                                  .trim(),
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.onSurfaceVariant,
                                height: 1.3,
                              ),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Footer Quick Action Buttons
                      Divider(
                        height: 1,
                        color: colors.outlineVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (object != null)
                            TextButton.icon(
                              key: const ValueKey(
                                'canvas-card-tooltip-copy-link',
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(
                                    text: '[[${object!.id}|${object!.title}]]',
                                  ),
                                );
                                ScaffoldMessenger.maybeOf(
                                  context,
                                )?.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Copied reference link to clipboard',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.link, size: 14),
                              label: const Text(
                                'Copy link',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          if (isTask && object != null)
                            TextButton.icon(
                              key: const ValueKey(
                                'canvas-card-tooltip-toggle-action',
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => onToggleTask(object!.id),
                              icon: Icon(
                                isDone ? Icons.undo : Icons.check,
                                size: 14,
                                color: isDone
                                    ? colors.onSurfaceVariant
                                    : OrbitColors.of(context).success,
                              ),
                              label: Text(
                                isDone ? 'Mark open' : 'Mark done',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDone
                                      ? colors.onSurfaceVariant
                                      : OrbitColors.of(context).success,
                                ),
                              ),
                            ),
                          if (object != null)
                            FilledButton.icon(
                              key: const ValueKey(
                                'canvas-card-tooltip-open-button',
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: onOpen,
                              icon: const Icon(Icons.arrow_outward, size: 13),
                              label: const Text(
                                'Open',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
