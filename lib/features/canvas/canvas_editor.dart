import '../../app/orbit_components.dart';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../canvas/geometry.dart';
import '../../canvas/arrangement.dart';
import '../../canvas/canvas_svg.dart';
import '../../canvas/columns.dart';
import '../../canvas/connectors.dart';
import '../../canvas/groups.dart';
import '../../canvas/scene.dart';
import '../../domain/json_values.dart';
import '../../platform/export_file.dart';
import 'canvas_painter.dart';
import 'canvas_images.dart';
import 'canvas_rich_text.dart';

export 'canvas_painter.dart' show CanvasObjectReference;
export 'canvas_images.dart' show CanvasImageReference;

enum _Tool {
  select,
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

class CanvasEditor extends StatefulWidget {
  const CanvasEditor({
    super.key,
    required this.canvasId,
    this.title = '',
    this.onTitleChanged,
    required this.data,
    required this.onChanged,
    required this.objects,
    required this.onOpenObject,
    this.camera,
    this.onCameraChanged,
    this.imageLoader,
    this.onInsertImage,
    this.onPasteImage,
    this.onOpenExternal,
    this.breadcrumbs,
  });
  final String canvasId;
  final String title;
  final ValueChanged<String>? onTitleChanged;
  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final List<CanvasObjectReference> objects;
  final ValueChanged<String> onOpenObject;
  final Map<String, dynamic>? camera;
  final ValueChanged<Map<String, dynamic>>? onCameraChanged;
  final Future<Uint8List?> Function(String)? imageLoader;
  final Future<CanvasImageReference?> Function()? onInsertImage, onPasteImage;
  final ValueChanged<Uri>? onOpenExternal;
  final List<CanvasBreadcrumb>? breadcrumbs;

  @override
  State<CanvasEditor> createState() => _CanvasEditorState();
}

class _CanvasEditorState extends State<CanvasEditor> {
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
  final Set<String> _selection = {};
  Map<String, CanvasObjectReference> _objects = {};
  _Tool _tool = _Tool.select;
  CanvasPoint? _start;
  CanvasPoint? _lastScreen;
  CanvasCamera? _startCamera;
  final Map<String, CanvasElement> _original = {};
  CanvasBounds? _region;
  CanvasElement? _preview;
  final List<Map<String, dynamic>> _ink = [];
  String? _editingId;
  int? _pointer;
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
  Size _viewport = Size.zero;
  Map<String, dynamic>? _lastEmitted;
  Duration _strokeStart = Duration.zero;
  CanvasImageCache? _images;
  final CanvasTextCache _textCache = CanvasTextCache();

  CanvasScene get _scene => _history.scene;
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
    _titleController = TextEditingController(text: widget.title);
    _history = CanvasHistory(CanvasScene.fromJson(widget.data));
    _camera = CanvasCamera.fromJson(widget.camera);
    _backgroundStyle = widget.data['backgroundStyle'] as String? ?? 'dots';
    _objects = {for (final object in widget.objects) object.id: object};
    final loader = widget.imageLoader;
    if (loader != null) {
      _images = CanvasImageCache(
        loader: loader,
        onChanged: () {
          if (mounted) setState(() {});
        },
      );
    }
    final preset = widget.data['canvasPreset'] as String?;
    if (_history.scene.elements.isEmpty && preset != null) {
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
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant CanvasEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _objects = {for (final object in widget.objects) object.id: object};
    if (widget.data['backgroundStyle'] is String &&
        widget.data['backgroundStyle'] != _backgroundStyle) {
      _backgroundStyle = widget.data['backgroundStyle'] as String;
    }
    if (oldWidget.canvasId != widget.canvasId) {
      _history = CanvasHistory(CanvasScene.fromJson(widget.data));
      _camera = CanvasCamera.fromJson(widget.camera);
      _backgroundStyle = widget.data['backgroundStyle'] as String? ?? 'dots';
      _selection.clear();
      _editingId = null;
      _clearGesture();
      _lastEmitted = null;
      _titleController.text = widget.title;
    } else if (oldWidget.title != widget.title && !_titleFocus.hasFocus) {
      _titleController.text = widget.title;
    } else if (!identical(oldWidget.data, widget.data) &&
        !identical(widget.data, _lastEmitted) &&
        !jsonValuesEqual(widget.data, _lastEmitted ?? oldWidget.data) &&
        !_history.inCommand) {
      // A genuine external revision replaces the scene; stale undo must not overwrite it.
      _history = CanvasHistory(CanvasScene.fromJson(widget.data));
      _selection.removeWhere((id) => _scene[id] == null);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocus.dispose();
    _images?.dispose();
    _textCache.dispose();
    _focus.dispose();
    _text.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  void _emit() {
    final data = {..._scene.toJson(), 'backgroundStyle': _backgroundStyle};
    _lastEmitted = data;
    widget.onChanged(data);
  }

  void _commit() {
    if (_history.commit()) _emit();
    if (mounted) setState(() {});
  }

  void _cameraChanged() => widget.onCameraChanged?.call(_camera.toJson());

  void _setTool(_Tool tool) {
    _finishText();
    _cancelGesture();
    setState(() {
      _tool = tool;
    });
    _focus.requestFocus();
  }

  void _down(PointerDownEvent event) {
    if (_pointer != null) return;
    _finishText();
    _focus.requestFocus();
    if (event.buttons == kSecondaryMouseButton) {
      _contextMenu(event);
      return;
    }
    _pointer = event.pointer;
    _start = _world(event.localPosition);
    _lastScreen = _point(event.localPosition);
    _startCamera = _camera;
    _panning =
        (event.kind == PointerDeviceKind.touch &&
            (_tool == _Tool.pen ||
                _tool == _Tool.highlighter ||
                _tool == _Tool.eraser)) ||
        _tool == _Tool.pan ||
        _spacePressed ||
        event.buttons == kMiddleMouseButton;
    if (_panning) return;
    if (_scene.readOnly) {
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
          ((_start! - endpoints.start).length < 13 / _camera.zoom ||
              (_start! - endpoints.end).length < 13 / _camera.zoom)) {
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
              13 / _camera.zoom) {
        _resizing = true;
        _original[single.id] = single;
      } else {
        final hit = _scene.hit(
          _start!,
          tolerance: 6 / _camera.zoom,
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
    if (event.pointer != _pointer) return;
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
        var height = math.max(40.0, original.height + point.y - _start!.y);
        if (_shift || original.type == 'image') {
          height = width * original.height / math.max(1, original.width);
        }
        if (_snap) {
          width = (width / 24).round() * 24.0;
          height = (height / 24).round() * 24.0;
        }
        _history.put(original.copy({'width': width, 'height': height}));
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
          final candidates = _scene.elements
              .where((e) => e.renderable && !_original.containsKey(e.id))
              .toList();

          double? snapDx;
          double? snapGuideX;
          final movingX = [
            currentBounds.left,
            currentBounds.center.x,
            currentBounds.right,
          ];
          for (final cand in candidates) {
            final candX = [
              cand.bounds.left,
              cand.bounds.center.x,
              cand.bounds.right,
            ];
            for (final mx in movingX) {
              for (final cx in candX) {
                final diff = cx - mx;
                if (diff.abs() <= threshold &&
                    (snapDx == null || diff.abs() < snapDx.abs())) {
                  snapDx = diff;
                  snapGuideX = cx;
                }
              }
            }
          }

          double? snapDy;
          double? snapGuideY;
          final movingY = [
            currentBounds.top,
            currentBounds.center.y,
            currentBounds.bottom,
          ];
          for (final cand in candidates) {
            final candY = [
              cand.bounds.top,
              cand.bounds.center.y,
              cand.bounds.bottom,
            ];
            for (final my in movingY) {
              for (final cy in candY) {
                final diff = cy - my;
                if (diff.abs() <= threshold &&
                    (snapDy == null || diff.abs() < snapDy.abs())) {
                  snapDy = diff;
                  snapGuideY = cy;
                }
              }
            }
          }

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
        }
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
      }
    } else if (_tool == _Tool.pen || _tool == _Tool.highlighter) {
      _sample(event.localPosition, event.pressure, event.timeStamp);
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

  void _sample(Offset offset, double pressure, Duration time) {
    final point = _world(offset);
    if (_ink.isNotEmpty) {
      final last = _ink.last;
      if ((CanvasPoint(last['x'] as double, last['y'] as double) - point)
              .length <
          .7 / _camera.zoom) {
        return;
      }
    }
    _ink.add({
      'x': point.x,
      'y': point.y,
      'pressure': pressure.isFinite ? pressure.clamp(0, 1) : 1.0,
      'timeMs': (time - _strokeStart).inMilliseconds,
    });
    final isHighlighter = _tool == _Tool.highlighter;
    _preview = CanvasElement({
      'id': 'preview',
      'type': 'ink',
      'x': 0.0,
      'y': 0.0,
      'width': 0.0,
      'height': 0.0,
      'points': List.of(_ink),
      'color': _color,
      'strokeWidth': isHighlighter ? 22.0 : 3.0,
      'isHighlighter': isHighlighter,
    });
  }

  void _erase(CanvasPoint point) {
    for (final element in _scene.query(
      CanvasBounds(point.x, point.y, 0, 0).inflate(12 / _camera.zoom),
    )) {
      if (element.type == 'ink' &&
          !element.locked &&
          element.hit(
            point,
            tolerance:
                (element.data['isHighlighter'] == true ? 22.0 : 12.0) /
                _camera.zoom,
          )) {
        _history.remove(element.id);
      }
    }
  }

  void _up(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    final point = _world(event.localPosition);
    final isTap = _start != null && (point - _start!).length < 4 / _camera.zoom;
    if (_panning) {
      _cameraChanged();
    } else if (_region != null) {
      for (final element in _scene.query(_region!)) {
        if (!element.locked) _selection.add(element.id);
      }
    } else if ((_tool == _Tool.pen || _tool == _Tool.highlighter) &&
        _ink.isNotEmpty) {
      final isHighlighter = _tool == _Tool.highlighter;
      final minX = _ink.map((p) => p['x'] as double).reduce(math.min);
      final minY = _ink.map((p) => p['y'] as double).reduce(math.min);
      final maxX = _ink.map((p) => p['x'] as double).reduce(math.max);
      final maxY = _ink.map((p) => p['y'] as double).reduce(math.max);
      _history.put(
        CanvasElement({
          'id': _id(),
          'type': 'ink',
          'x': minX,
          'y': minY,
          'width': maxX - minX,
          'height': maxY - minY,
          'color': _color,
          'strokeWidth': isHighlighter ? 22.0 : 3.0,
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
    _endpointStart = null;
    _pointer = null;
    _start = null;
    _lastScreen = null;
    _region = null;
    _preview = null;
    _ink.clear();
    _original.clear();
    _panning = false;
    _resizing = false;
    _activeGuides.clear();
    _connectingStartId = null;
    _connectingEndId = null;
    _hoveredAnchorElementId = null;
  }

  void _cancelGesture() {
    if (_panning && _startCamera != null) _camera = _startCamera!;
    _history.cancel();
    _clearGesture();
    if (mounted) setState(() {});
  }

  void _undo() {
    _finishText();
    if (_history.undo()) {
      _selection.removeWhere((id) => _scene[id] == null);
      _emit();
      setState(() {});
    }
  }

  void _redo() {
    _finishText();
    if (_history.redo()) {
      _selection.removeWhere((id) => _scene[id] == null);
      _emit();
      setState(() {});
    }
  }

  void _delete() {
    _finishText();
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
  }

  void _reorder(String action) {
    if (_scene.readOnly || _selection.isEmpty) return;
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
    await Clipboard.setData(
      ClipboardData(
        text: 'orbit-canvas/1\n${jsonEncode({'elements': elements})}',
      ),
    );
    if (cut && mounted) {
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

  Future<void> _paste() async {
    if (_scene.readOnly) return;
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    if ((clipboard?.text ?? '').isEmpty) {
      if (widget.onPasteImage != null) await _insertImage(widget.onPasteImage!);
      return;
    }
    final text = clipboard!.text!;
    if (text.startsWith('orbit-canvas/1\n')) {
      try {
        final decoded = jsonDecode(text.substring('orbit-canvas/1\n'.length));
        if (decoded is! Map || decoded['elements'] is! List) return;
        final originals = (decoded['elements'] as List)
            .whereType<Map>()
            .map((v) => CanvasElement(Map<String, dynamic>.from(v)))
            .where((e) => e.renderable)
            .toList();
        _selection.clear();
        final newIds = {for (final original in originals) original.id: _id()};
        for (final original in originals) {
          final element = original.copy({
            'id': newIds[original.id],
            'columnId': newIds[original.data['columnId']],
            'x': original.x + 32,
            'y': original.y + 32,
            'locked': false,
          });
          _history.put(element);
          _selection.add(element.id);
        }
        _commit();
      } on FormatException {
        _notice('The clipboard does not contain valid Canvas data.');
      }
    } else if (text.trim().isNotEmpty) {
      final center = _camera.toWorld(
        CanvasPoint(_viewport.width / 2, _viewport.height / 2),
      );
      final element = CanvasElement({
        'id': _id(),
        'type': 'sticky',
        'x': center.x - 110,
        'y': center.y - 90,
        'width': 220.0,
        'height': 180.0,
        'text': text,
        'color': _color,
      });
      _history.put(element);
      _selection
        ..clear()
        ..add(element.id);
      _commit();
    }
  }

  void _duplicate() {
    if (_scene.readOnly || _selection.isEmpty) return;
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
      final shiftedPoints = original.points
          .map((p) => CanvasPoint(p.x + 20, p.y + 20))
          .map((p) => {'x': p.x, 'y': p.y})
          .toList();
      final newGid = original.groupId != null
          ? groupMap[original.groupId!]
          : null;
      final patch = <String, dynamic>{
        'id': newIds[original.id],
        'columnId': newIds[original.data['columnId']],
        'x': original.x + 20,
        'y': original.y + 20,
        'locked': false,
        if (shiftedPoints.isNotEmpty) 'points': shiftedPoints,
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
    if (_scene.readOnly || _selection.length < 2) return;
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
              if (e.points.isNotEmpty) {
                final shiftedPoints = e.points
                    .map((p) => CanvasPoint(p.x + dx, p.y))
                    .map((p) => {'x': p.x, 'y': p.y})
                    .toList();
                _history.put(e.copy({'x': e.x + dx, 'points': shiftedPoints}));
              } else {
                _history.put(e.copy({'x': e.x + dx}));
              }
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
              if (e.points.isNotEmpty) {
                final shiftedPoints = e.points
                    .map((p) => CanvasPoint(p.x, p.y + dy))
                    .map((p) => {'x': p.x, 'y': p.y})
                    .toList();
                _history.put(e.copy({'y': e.y + dy, 'points': shiftedPoints}));
              } else {
                _history.put(e.copy({'y': e.y + dy}));
              }
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

      if (e.points.isNotEmpty) {
        final shiftedPoints = e.points
            .map((p) => CanvasPoint(p.x + dx, p.y + dy))
            .map((p) => {'x': p.x, 'y': p.y})
            .toList();
        _history.put(e.copy({'x': newX, 'y': newY, 'points': shiftedPoints}));
      } else {
        _history.put(e.copy({'x': newX, 'y': newY}));
      }
    }
    _commit();
    setState(() {});
  }

  void _applyArrangement(CanvasArrangement action) {
    if (_scene.readOnly || _selection.length < 2) return;
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
    if (_scene.readOnly || _selection.length < 2) return;
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
    if (_scene.readOnly || _selection.isEmpty) return;
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

  void _edit(CanvasElement element) {
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
        widget.onOpenObject(element.objectId!);
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
    if (_scene.readOnly ||
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
    if (original != null && original.text != _text.text) {
      _history.put(original.copy({'text': _text.text}));
      _commit();
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
                    _scene[_editingId!]?.type == 'line')))) {
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
      _cancelGesture();
      _selection.clear();
      _setTool(_Tool.select);
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
    } else if (!_command && key == LogicalKeyboardKey.digit1) {
      _fit();
    } else if (!_command && key == LogicalKeyboardKey.digit0) {
      _zoom(1 / _camera.zoom);
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
        final b = _scene[id]?.bounds;
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
    _finishText();
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
    if (!mounted || selected == null) return;
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
            title: Row(
              children: [
                const Icon(Icons.layers_outlined, size: 20),
                const SizedBox(width: 8),
                const Text('Layers & Stacking Order'),
                const Spacer(),
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
            content: SizedBox(
              width: 500,
              height: 420,
              child: !hasItems
                  ? const Center(child: Text('This Canvas has no elements.'))
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
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
                              const Spacer(),
                              IconButton(
                                icon: const Icon(
                                  Icons.vertical_align_top,
                                  size: 18,
                                ),
                                tooltip: 'Bring to Front',
                                visualDensity: VisualDensity.compact,
                                onPressed: _selection.isEmpty || _scene.readOnly
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
                                onPressed: _selection.isEmpty || _scene.readOnly
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
                        Expanded(
                          child: ListView.separated(
                            itemCount: elements.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1, indent: 44),
                            itemBuilder: (ctx, index) {
                              final element = elements[index];
                              final isSelected = _selection.contains(
                                element.id,
                              );
                              final accentColor = Color(element.color);

                              return ListTile(
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
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _labelForElement(element),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: element.hidden
                                              ? Theme.of(
                                                  dialogContext,
                                                ).colorScheme.outline
                                              : null,
                                        ),
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
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
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
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.arrow_upward,
                                        size: 16,
                                      ),
                                      tooltip: 'Bring Forward',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
                                        minHeight: 28,
                                      ),
                                      onPressed: index == 0 || _scene.readOnly
                                          ? null
                                          : () {
                                              _history.reorder(
                                                [element.id],
                                                () {
                                                  _scene.bringForward(
                                                    element.id,
                                                  );
                                                },
                                              );
                                              _commit();
                                              setDialogState(() {});
                                            },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.arrow_downward,
                                        size: 16,
                                      ),
                                      tooltip: 'Send Backward',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
                                        minHeight: 28,
                                      ),
                                      onPressed:
                                          index == elements.length - 1 ||
                                              _scene.readOnly
                                          ? null
                                          : () {
                                              _history.reorder(
                                                [element.id],
                                                () {
                                                  _scene.sendBackward(
                                                    element.id,
                                                  );
                                                },
                                              );
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
                                            ? Theme.of(
                                                dialogContext,
                                              ).colorScheme.error
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
                                      onPressed: _scene.readOnly
                                          ? null
                                          : () {
                                              _history.put(
                                                element.copy({
                                                  'locked': !element.locked,
                                                }),
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
                                            ? Theme.of(
                                                dialogContext,
                                              ).colorScheme.outline
                                            : null,
                                      ),
                                      tooltip: element.hidden
                                          ? 'Show layer'
                                          : 'Hide layer',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
                                        minHeight: 28,
                                      ),
                                      onPressed: _scene.readOnly
                                          ? null
                                          : () {
                                              _history.put(
                                                element.copy({
                                                  'hidden': !element.hidden,
                                                }),
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
                                ),
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
                        ),
                      ],
                    ),
            ),
            actions: [
              if (hasItems && !_scene.readOnly) ...[
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

  Future<void> _showExportDialog({bool selectionOnly = false}) async {
    final hasSelection = _selection.isNotEmpty;
    var scopeSelection = selectionOnly && hasSelection;
    var format = 'png';
    var transparent = false;
    var scale = 2.0;
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
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('PNG Image')),
                              selected: format == 'png',
                              onSelected: (selected) {
                                if (selected) {
                                  setDialogState(() => format = 'png');
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('Vector SVG')),
                              selected: format == 'svg',
                              onSelected: (selected) {
                                if (selected) {
                                  setDialogState(() => format = 'svg');
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('JSON Backup')),
                              selected: format == 'json',
                              onSelected: (selected) {
                                if (selected) {
                                  setDialogState(() => format = 'json');
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (format != 'json') ...[
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
                          Row(
                            children: [
                              const Text(
                                'Resolution Scale:',
                                style: TextStyle(fontSize: 13),
                              ),
                              const Spacer(),
                              SegmentedButton<double>(
                                segments: const [
                                  ButtonSegment(value: 1.0, label: Text('1x')),
                                  ButtonSegment(value: 2.0, label: Text('2x')),
                                  ButtonSegment(value: 3.0, label: Text('3x')),
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
                        ],
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
                if (format == 'svg' || format == 'json')
                  TextButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy to Clipboard'),
                    onPressed: isExporting
                        ? null
                        : () async {
                            final targetIds = scopeSelection
                                ? _selection
                                : null;
                            if (format == 'svg') {
                              final svg = canvasToSvg(
                                _scene,
                                transparent: transparent,
                                backgroundColor: colors.surface.toARGB32(),
                                elementIds: targetIds,
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
                                elementIds: targetIds,
                              );
                              await exportFile(
                                '$sanitized.svg',
                                svg,
                                mimeType: 'image/svg+xml',
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
    final worldPos = _world(event.localPosition);
    final hit = _scene.hit(worldPos, tolerance: 6 / _camera.zoom);
    if (hit != null && !_selection.contains(hit.id)) {
      setState(() {
        _selection
          ..clear()
          ..add(hit.id);
      });
    }
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;

    if (hit == null) {
      final hasSelection = _selection.isNotEmpty;
      final action = await showMenu<String>(
        context: context,
        position: RelativeRect.fromRect(
          Rect.fromLTWH(event.position.dx, event.position.dy, 1, 1),
          Offset.zero & overlay.size,
        ),
        items: [
          if (!_scene.readOnly) ...[
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
              value: 'place_object',
              child: Row(
                children: [
                  Icon(Icons.add_link, size: 16),
                  SizedBox(width: 8),
                  Text('Place object'),
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
            value: 'export_canvas',
            child: Text('Export Canvas...'),
          ),
        ],
      );
      if (!mounted || action == null) return;
      switch (action) {
        case 'add_text':
          _addText(at: worldPos);
        case 'add_sticky':
          _addSticky(at: worldPos);
        case 'add_checklist':
          _addChecklist(at: worldPos);
        case 'add_section':
          _addSection(at: worldPos);
        case 'add_swatch':
          _addSwatch(at: worldPos);
        case 'add_card':
          _addCard(at: worldPos);
        case 'place_object':
          _chooseObject(at: worldPos);
        case 'paste':
          _paste();
        case 'fit_all':
          _fit();
        case 'fit_selection':
          _fit(selectionOnly: true);
        case 'zoom_100':
          _zoom(1 / _camera.zoom);
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

    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(event.position.dx, event.position.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        if (_selection.length == 1)
          const PopupMenuItem(value: 'edit', child: Text('Open / edit')),
        if (isConnector && !_scene.readOnly) ...[
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
          const PopupMenuItem(value: 'copy', child: Text('Copy placements')),
        if (_selection.isNotEmpty && !_scene.readOnly)
          const PopupMenuItem(
            value: 'duplicate',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Duplicate'),
                SizedBox(width: 16),
                Text(
                  'Ctrl+D',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        const PopupMenuItem(value: 'paste', child: Text('Paste')),
        if (_selection.isNotEmpty && !_scene.readOnly) ...[
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
        if (_selection.length >= 2 && !_scene.readOnly) ...[
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
          const PopupMenuDivider(),
        ],
        if (!_scene.readOnly &&
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
        if (_selection.isNotEmpty && !_scene.readOnly)
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
        const PopupMenuDivider(),
        if (_selection.isNotEmpty)
          const PopupMenuItem(
            value: 'export_selection',
            child: Text('Export Selection...'),
          ),
        const PopupMenuItem(
          value: 'export_canvas',
          child: Text('Export Canvas...'),
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        if (_selection.length == 1) _edit(_scene[_selection.first]!);
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
      case 'export_selection':
        _showExportDialog(selectionOnly: true);
      case 'export_canvas':
        _showExportDialog(selectionOnly: false);
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

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _focus,
    onKeyEvent: _key,
    onFocusChange: (focused) {
      if (!focused && _spacePressed) {
        setState(() {
          _spacePressed = false;
        });
      }
    },
    child: Column(
      children: [
        if (!_presentationMode) _toolbar(context),
        if (_scene.readOnly)
          const MaterialBanner(
            content: Text(
              'This Canvas uses an unsupported format. It is preserved and opened read-only.',
            ),
            actions: [SizedBox.shrink()],
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _viewport = Size(constraints.maxWidth, constraints.maxHeight);
              _images?.updateVisible(
                _scene
                    .query(_camera.viewport(_viewport.width, _viewport.height))
                    .where(
                      (element) =>
                          element.type == 'image' &&
                          element.data['contentRef'] is String,
                    )
                    .map((element) => element.data['contentRef'] as String),
              );
              final editing = _editingId == null ? null : _scene[_editingId!];
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
                      child: DragTarget<({String path, String? noteId})>(
                        onWillAcceptWithDetails: (details) =>
                            details.data.noteId != null && !_scene.readOnly,
                        onAcceptWithDetails: (details) {
                          final noteId = details.data.noteId;
                          if (noteId == null) return;
                          final renderBox =
                              context.findRenderObject() as RenderBox?;
                          if (renderBox == null) return;
                          final localOffset = renderBox.globalToLocal(
                            details.offset,
                          );
                          final worldPoint = _camera.toWorld(
                            CanvasPoint(localOffset.dx, localOffset.dy),
                          );
                          _dropObjectOntoCanvas(noteId, worldPoint);
                        },
                        builder: (ctx, candidateData, rejectedData) => Semantics(
                          label:
                              'Universal Canvas. Use the element list for keyboard selection. Space drag to pan, Control wheel to zoom.',
                          child: MouseRegion(
                            cursor:
                                _panning || _tool == _Tool.pan || _spacePressed
                                ? SystemMouseCursors.grab
                                : _tool == _Tool.select
                                ? SystemMouseCursors.basic
                                : SystemMouseCursors.precise,
                            child: Listener(
                              behavior: HitTestBehavior.opaque,
                              onPointerDown: _down,
                              onPointerMove: _move,
                              onPointerUp: _up,
                              onPointerCancel: (_) => _cancelGesture(),
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
                                if (event is PointerScrollEvent) {
                                  GestureBinding.instance.pointerSignalResolver
                                      .register(event, (event) {
                                        final scroll =
                                            event as PointerScrollEvent;
                                        setState(() {
                                          _camera = _command
                                              ? _camera.zoomAt(
                                                  _point(scroll.localPosition),
                                                  math.exp(
                                                    -scroll.scrollDelta.dy *
                                                        .002,
                                                  ),
                                                )
                                              : _camera.pan(
                                                  CanvasPoint(
                                                    -scroll.scrollDelta.dx,
                                                    -scroll.scrollDelta.dy,
                                                  ),
                                                );
                                        });
                                        _cameraChanged();
                                      });
                                }
                              },
                              child: GestureDetector(
                                onDoubleTap: () {},
                                onDoubleTapDown: (details) {
                                  final hit = _scene.hit(
                                    _world(details.localPosition),
                                    tolerance: 6 / _camera.zoom,
                                    includeLocked: true,
                                  );
                                  if (hit != null) _edit(hit);
                                },
                                child: CustomPaint(
                                  painter: OrbitCanvasPainter(
                                    textCache: _textCache,
                                    images: _images?.images ?? const {},
                                    scene: _scene,
                                    camera: _camera,
                                    selection: Set.of(_selection),
                                    objects: _objects,
                                    colors: Theme.of(context).colorScheme,
                                    region: _region,
                                    preview: _preview,
                                    editingId: _editingId,
                                    guides: _activeGuides,
                                    backgroundStyle: _backgroundStyle,
                                    hoveredAnchorElementId:
                                        _hoveredAnchorElementId,
                                    connectingStartElementId:
                                        _connectingStartId,
                                  ),
                                  child: const SizedBox.expand(),
                                ),
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
                                  math.max(80, editing.height * _camera.zoom) +
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
                                      onPressed: () => _applyFormatPrefix('# '),
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
                                      onPressed: () => _applyFormatPrefix('- '),
                                    ),
                                    const SizedBox(width: 4),
                                    SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: IconButton(
                                        icon: const Icon(Icons.check, size: 16),
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
                            : math.max(80, editing.height * _camera.zoom),
                        child: Material(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHigh,
                          elevation: 4,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: TextField(
                              key: const ValueKey('canvas-element-text-field'),
                              groupId: 'canvas-text-editing',
                              controller: _text,
                              focusNode: _textFocus,
                              maxLines: null,
                              expands: true,
                              style: TextStyle(
                                fontSize: (17 * _camera.zoom).clamp(12, 48),
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Write here…',
                              ),
                              onTapOutside: (_) => _finishText(),
                              onChanged: (value) {
                                final element = _scene[_editingId!];
                                if (element != null) {
                                  _history.put(element.copy({'text': value}));
                                  _emit();
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    if (!_presentationMode)
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
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.space_dashboard_outlined,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
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
                                      borderRadius: BorderRadius.circular(4),
                                      onTap: () => widget.onOpenObject(
                                        widget.breadcrumbs![i].id,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        child: Text(
                                          widget.breadcrumbs![i].title.isEmpty
                                              ? 'Untitled'
                                              : widget.breadcrumbs![i].title,
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
                                          focusedBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withValues(alpha: 0.6),
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
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        _titleFocus.requestFocus();
                                        _titleController.selection =
                                            TextSelection(
                                              baseOffset: 0,
                                              extentOffset:
                                                  _titleController.text.length,
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
                                onPressed: () => _zoom(1 / _camera.zoom),
                                child: Text('${(_camera.zoom * 100).round()}%'),
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
                              icon: const Icon(Icons.fit_screen, size: 18),
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
                              key: const ValueKey('canvas-minimap-toggle'),
                              tooltip: _showMinimap
                                  ? 'Hide minimap'
                                  : 'Show minimap',
                              isSelected: _showMinimap,
                              onPressed: () => setState(() {
                                _showMinimap = !_showMinimap;
                              }),
                              icon: Icon(
                                _showMinimap ? Icons.map : Icons.map_outlined,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showMinimap && !_presentationMode && _scene.length > 0)
                      Positioned(
                        key: const ValueKey('canvas-minimap-card'),
                        right: 16,
                        bottom: 64,
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
                            child: SizedBox(
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
                                    scene: _scene,
                                    camera: _camera,
                                    viewportSize: _viewport,
                                    colors: Theme.of(context).colorScheme,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_selection.isNotEmpty)
                      Positioned(
                        left: 16,
                        bottom: 18,
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
                              style: Theme.of(context).textTheme.labelSmall,
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
    Future<CanvasImageReference?> Function() load,
  ) async {
    if (_scene.readOnly) return;
    _finishText();
    final image = await load();
    if (!mounted || image == null) return;
    final center = _camera.toWorld(
      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
    );
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
    if (_scene.readOnly) return;
    _finishText();
    final obj = _objects[objectId];
    String title = (obj != null && obj.title.isNotEmpty) ? obj.title : 'Object';
    int cardColor = _color;

    if (obj != null) {
      final category = obj.properties['category'] as String?;
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

  void _applyExercisePreset() {
    if (_scene.readOnly) return;
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

  void _applyStudyBoardPreset() {
    if (_scene.readOnly) return;
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
    if (_scene.readOnly) return;
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
    if (_scene.readOnly) return;
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
    if (_scene.readOnly) return;
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
    if (_scene.readOnly) return;
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
    if (_scene.readOnly) return;
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
    if (_scene.readOnly) return;
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
    if (_scene.readOnly) return;
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
    if (_scene.readOnly) return;
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
    if (_scene.readOnly) return;
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
    if (_scene.readOnly) return;
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
    if (_scene.readOnly) return;
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
    if (_scene.readOnly) return;
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
    if (_scene.readOnly) return;
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
    if (_scene.readOnly) return;
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
    if (_scene.readOnly) return;
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
    if (_scene.readOnly) return;
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
    if (_scene.readOnly || existing?.locked == true) return;
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
    if (_scene.readOnly) return;
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
      (_Tool.pan, Icons.pan_tool_outlined, 'Pan (H / Space)'),
      (_Tool.sticky, Icons.sticky_note_2_outlined, 'Sticky note (S)'),
      (_Tool.text, Icons.title, 'Text (T)'),
      (_Tool.pen, Icons.draw_outlined, 'Pen (P)'),
      (_Tool.highlighter, Icons.brush_outlined, 'Highlighter (Y)'),
      (_Tool.eraser, Icons.auto_fix_normal, 'Erase strokes (E)'),
    ];
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            children: [
              for (final item in tools)
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: OrbitControl(
                    tooltip: item.$3,
                    selected: _tool == item.$1,
                    onPressed:
                        _scene.readOnly &&
                            item.$1 != _Tool.pan &&
                            item.$1 != _Tool.select
                        ? null
                        : () => _setTool(item.$1),
                    icon: item.$2,
                  ),
                ),
              PopupMenuButton<_Tool>(
                tooltip: 'Shapes and diagrams',
                onSelected: _setTool,
                enabled: !_scene.readOnly,
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
                      value: item.$1,
                      child: Row(
                        children: [
                          Icon(item.$2, size: 20),
                          const SizedBox(width: 12),
                          Text(item.$3),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: 'Add / organize board content',
                enabled: !_scene.readOnly,
                icon: const Icon(Icons.add_box_outlined, size: 20),
                itemBuilder: (_) => [
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
                  if (action == 'checklist') {
                    _addChecklist();
                  }
                  if (action == 'link') {
                    _addLink();
                  }
                  if (action == 'editLink') _addLink(_scene[_selection.single]);
                  if (action == 'section') _addSection();
                  if (action == 'swatch') _addSwatch();
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
              if (_selection.length >= 2 && !_scene.readOnly)
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
                          Text('Align Left'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: CanvasAlignment.centerH,
                      child: Row(
                        children: [
                          Icon(Icons.align_horizontal_center, size: 16),
                          SizedBox(width: 8),
                          Text('Horizontal Center'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: CanvasAlignment.right,
                      child: Row(
                        children: [
                          Icon(Icons.align_horizontal_right, size: 16),
                          SizedBox(width: 8),
                          Text('Align Right'),
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
                          Text('Align Top'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: CanvasAlignment.middleV,
                      child: Row(
                        children: [
                          Icon(Icons.align_vertical_center, size: 16),
                          SizedBox(width: 8),
                          Text('Vertical Middle'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: CanvasAlignment.bottom,
                      child: Row(
                        children: [
                          Icon(Icons.align_vertical_bottom, size: 16),
                          SizedBox(width: 8),
                          Text('Align Bottom'),
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
                            Text('Distribute Horizontally'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: CanvasAlignment.distributeV,
                        child: Row(
                          children: [
                            Icon(Icons.vertical_distribute, size: 16),
                            SizedBox(width: 8),
                            Text('Distribute Vertically'),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              TextButton.icon(
                onPressed: _scene.readOnly ? null : _chooseObject,
                icon: const Icon(Icons.add_link, size: 19),
                label: const Text('Place object'),
              ),
              if (widget.onInsertImage != null)
                IconButton(
                  tooltip: 'Insert image',
                  onPressed: _scene.readOnly
                      ? null
                      : () => _insertImage(widget.onInsertImage!),
                  icon: const Icon(Icons.image_outlined, size: 20),
                ),
              if (widget.onPasteImage != null)
                IconButton(
                  tooltip: 'Paste image',
                  onPressed: _scene.readOnly
                      ? null
                      : () => _insertImage(widget.onPasteImage!),
                  icon: const Icon(Icons.content_paste, size: 20),
                ),
              const SizedBox(width: 8),
              PopupMenuButton<int>(
                tooltip: 'Color',
                onSelected: (value) {
                  setState(() {
                    _color = value;
                  });
                  for (final id in _selection) {
                    final element = _scene[id];
                    if (element != null) {
                      _history.put(element.copy({'color': value}));
                    }
                  }
                  _commit();
                },
                icon: Icon(Icons.circle, color: Color(_color), size: 20),
                enabled: !_scene.readOnly,
                itemBuilder: (_) => [
                  for (final value in [
                    0xff8b7cf6,
                    0xff6f7fea,
                    0xff65c6a3,
                    0xffd8b56a,
                    0xffe57582,
                    0xffeceaf2,
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
                              0xffeceaf2: 'White',
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
                  !_scene.readOnly) ...[
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
                initialValue: _backgroundStyle,
                onSelected: (val) {
                  setState(() {
                    _backgroundStyle = val;
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
                  PopupMenuItem(value: 'blank', child: Text('Blank paper')),
                ],
              ),
              PopupMenuButton<String>(
                tooltip: 'Apply workspace preset (Study / Game Dev)',
                icon: const Icon(Icons.dashboard_customize_outlined, size: 20),
                enabled: !_scene.readOnly,
                onSelected: (preset) {
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
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
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
              IconButton(
                tooltip: 'Undo (Ctrl+Z)',
                onPressed: _history.canUndo ? _undo : null,
                icon: const Icon(Icons.undo, size: 20),
              ),
              IconButton(
                tooltip: 'Redo (Ctrl+Shift+Z)',
                onPressed: _history.canRedo ? _redo : null,
                icon: const Icon(Icons.redo, size: 20),
              ),
              IconButton(
                tooltip: 'Layers & element list',
                onPressed: _showElementList,
                icon: const Icon(Icons.layers_outlined, size: 20),
              ),
              PopupMenuButton<String>(
                tooltip: 'Layer order',
                enabled: _selection.isNotEmpty && !_scene.readOnly,
                icon: const Icon(Icons.flip_to_front_outlined, size: 20),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'front',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Bring to Front'),
                        SizedBox(width: 12),
                        Text(
                          'Shift+]',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
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
                          style: TextStyle(fontSize: 11, color: Colors.grey),
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
                          style: TextStyle(fontSize: 11, color: Colors.grey),
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
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (action) => _reorder(action),
              ),
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
              PopupMenuButton<String>(
                tooltip: 'Group (Ctrl+G) / Ungroup (Ctrl+Shift+G)',
                enabled:
                    !_scene.readOnly &&
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
  const CanvasMinimapPainter({
    required this.scene,
    required this.camera,
    required this.viewportSize,
    required this.colors,
  });

  final CanvasScene scene;
  final CanvasCamera camera;
  final Size viewportSize;
  final ColorScheme colors;

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
        math.max(2.0, element.bounds.width * scale),
        math.max(2.0, element.bounds.height * scale),
      );
      final elPaint = Paint()
        ..color = Color(element.color).withValues(alpha: 0.55)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(elRect, const Radius.circular(1.5)),
        elPaint,
      );
    }

    final vpRect = Rect.fromLTWH(
      offsetX + (camera.x - contentRect.left) * scale,
      offsetY + (camera.y - contentRect.top) * scale,
      (viewportSize.width / camera.zoom) * scale,
      (viewportSize.height / camera.zoom) * scale,
    );
    final vpFill = Paint()
      ..color = colors.primary.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    final vpStroke = Paint()
      ..color = colors.primary.withValues(alpha: 0.8)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(vpRect, const Radius.circular(2)),
      vpFill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(vpRect, const Radius.circular(2)),
      vpStroke,
    );
  }

  @override
  bool shouldRepaint(covariant CanvasMinimapPainter oldDelegate) =>
      scene.revision != oldDelegate.scene.revision ||
      camera.x != oldDelegate.camera.x ||
      camera.y != oldDelegate.camera.y ||
      camera.zoom != oldDelegate.camera.zoom ||
      viewportSize != oldDelegate.viewportSize ||
      colors != oldDelegate.colors;
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
