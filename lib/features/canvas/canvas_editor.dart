import '../../app/orbit_components.dart';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../canvas/geometry.dart';
import '../../canvas/arrangement.dart';
import '../../canvas/columns.dart';
import '../../canvas/scene.dart';
import '../../domain/json_values.dart';
import 'canvas_painter.dart';
import 'canvas_images.dart';

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
  final _textFocus = FocusNode();
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
  bool _spacePressed = false;
  bool _snap = false;
  bool _showMinimap = false;
  String _backgroundStyle = 'dots';
  final List<CanvasGuideLine> _activeGuides = [];
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
            (_tool == _Tool.pen || _tool == _Tool.eraser)) ||
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
      if (single != null &&
          !single.locked &&
          single.type != 'ink' &&
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
          } else {
            if (!_shift && !_selection.contains(hit.id)) _selection.clear();
            _selection.add(hit.id);
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
        } else {
          if (!_shift) _selection.clear();
          _region = CanvasBounds(_start!.x, _start!.y, 0, 0);
        }
      }
    } else if (_tool == _Tool.pen) {
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
      if (_region != null) {
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
          _history.put(original.translated(delta));
        }
      }
    } else if (_tool == _Tool.pen) {
      _sample(event.localPosition, event.pressure, event.timeStamp);
    } else if (_tool == _Tool.eraser) {
      _erase(point);
    } else {
      final bounds = CanvasBounds.between(_start!, point);
      _preview = CanvasElement({
        'id': 'preview',
        'type': _tool.name,
        'x': bounds.left,
        'y': bounds.top,
        'width': bounds.width,
        'height': bounds.height,
        'color': _color,
        'strokeWidth': 2.0,
        'reverseX': point.x < _start!.x,
        'reverseY': point.y < _start!.y,
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
    _preview = CanvasElement({
      'id': 'preview',
      'type': 'ink',
      'x': 0.0,
      'y': 0.0,
      'width': 0.0,
      'height': 0.0,
      'points': List.of(_ink),
      'color': _color,
      'strokeWidth': 3.0,
    });
  }

  void _erase(CanvasPoint point) {
    for (final element in _scene.query(
      CanvasBounds(point.x, point.y, 0, 0).inflate(12 / _camera.zoom),
    )) {
      if (element.type == 'ink' &&
          !element.locked &&
          element.hit(point, tolerance: 12 / _camera.zoom)) {
        _history.remove(element.id);
      }
    }
  }

  void _up(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    if (_panning) {
      _cameraChanged();
    } else if (_region != null) {
      for (final element in _scene.query(_region!)) {
        if (!element.locked) _selection.add(element.id);
      }
    } else if (_tool == _Tool.pen && _ink.isNotEmpty) {
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
          'strokeWidth': 3.0,
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
        (_preview!.width > 2 || _preview!.height > 2)) {
      final element = _preview!.copy({'id': _id()});
      _history.put(element);
      _selection
        ..clear()
        ..add(element.id);
    }
    if (!_panning &&
        !_resizing &&
        _original.isNotEmpty &&
        _selection.length == 1) {
      final element = _scene[_selection.single];
      final original = _original[_selection.single];
      if (element != null &&
          original != null &&
          element.type != 'column' &&
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
    _clearGesture();
    _commit();
  }

  void _clearGesture() {
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
    for (final id in _selection) {
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

  Future<void> _copy({bool cut = false}) async {
    final ids = {..._selection};
    for (final id in _selection) {
      if (_scene[id]?.type == 'column') {
        ids.addAll(columnMembers(_scene, id).map((e) => e.id));
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
    }
    final originals = ids
        .map((id) => _scene[id])
        .whereType<CanvasElement>()
        .where((e) => e.renderable && !e.locked)
        .toList();
    if (originals.isEmpty) return;

    final newIds = {for (final original in originals) original.id: _id()};
    final newSelection = <String>{};

    _history.begin();
    for (final original in originals) {
      final shiftedPoints = original.points
          .map((p) => CanvasPoint(p.x + 20, p.y + 20))
          .map((p) => {'x': p.x, 'y': p.y})
          .toList();
      final duplicate = original.copy({
        'id': newIds[original.id],
        'columnId': newIds[original.data['columnId']],
        'x': original.x + 20,
        'y': original.y + 20,
        'locked': false,
        if (shiftedPoints.isNotEmpty) 'points': shiftedPoints,
      });
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
      if (_objects.containsKey(element.objectId)) {
        widget.onOpenObject(element.objectId!);
      } else {
        _notice(
          'The original object is unavailable. Removing this card does not delete an object.',
        );
      }
      return;
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
    final worldX = contentRect.left + (localPos.dx - offsetX) / scale;
    final worldY = contentRect.top + (localPos.dy - offsetY) / scale;
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

  Future<void> _chooseObject() async {
    _finishText();
    final query = TextEditingController();
    final selected = await showDialog<CanvasObjectReference>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          final results = widget.objects
              .where(
                (o) =>
                    o.id != widget.canvasId &&
                    o.title.toLowerCase().contains(query.text.toLowerCase()),
              )
              .toList();
          return OrbitDialog(
            title: const Text('Place an object'),
            content: SizedBox(
              width: 420,
              height: 360,
              child: Column(
                children: [
                  TextField(
                    controller: query,
                    autofocus: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Find a note, task or project',
                    ),
                    onChanged: (_) => update(() {}),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: results.isEmpty
                        ? const Center(
                            child: Text(
                              'No matching objects. Create a note or task first.',
                            ),
                          )
                        : ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                              final object = results[index];
                              return ListTile(
                                title: Text(object.title),
                                subtitle: Text(object.typeId),
                                leading: const Icon(Icons.link),
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
    final center = _camera.toWorld(
      CanvasPoint(_viewport.width / 2, _viewport.height / 2),
    );
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

  Future<void> _showElementList() async {
    final elements = _scene.elements.where((e) => e.renderable).toList();
    await showDialog<void>(
      context: context,
      builder: (context) => OrbitDialog(
        title: const Text('Canvas elements'),
        content: SizedBox(
          width: 420,
          height: 350,
          child: elements.isEmpty
              ? const Center(child: Text('This Canvas is empty.'))
              : ListView.builder(
                  itemCount: elements.length,
                  itemBuilder: (context, index) {
                    final element = elements[index];
                    final label = element.type == 'card'
                        ? _objects[element.objectId]?.title ?? 'Missing object'
                        : element.text.isNotEmpty
                        ? element.text
                        : element.type;
                    return ListTile(
                      title: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(element.type),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _selection
                            ..clear()
                            ..add(element.id);
                        });
                        _fit(selectionOnly: true);
                        _focus.requestFocus();
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
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
        ],
      );
      if (!mounted || action == null) return;
      switch (action) {
        case 'add_text':
          _addText(at: worldPos);
        case 'add_sticky':
          _addSticky(at: worldPos);
        case 'add_section':
          _addSection(at: worldPos);
        case 'add_swatch':
          _addSwatch(at: worldPos);
        case 'paste':
          _paste();
        case 'fit_all':
          _fit();
        case 'fit_selection':
          _fit(selectionOnly: true);
        case 'zoom_100':
          _zoom(1 / _camera.zoom);
      }
      return;
    }

    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(event.position.dx, event.position.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        if (_selection.length == 1)
          const PopupMenuItem(value: 'edit', child: Text('Open / edit')),
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
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        if (_selection.length == 1) _edit(_scene[_selection.first]!);
      case 'copy':
        _copy();
      case 'duplicate':
        _duplicate();
      case 'paste':
        _paste();
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
      case 'delete':
        _delete();
      case 'fit_selection':
        _fit(selectionOnly: true);
      case 'fit_all':
        _fit();
      case 'zoom_100':
        _zoom(1 / _camera.zoom);
    }
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
              final editingPosition = editing == null
                  ? null
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
                    if (editing != null && editingPosition != null)
                      Positioned(
                        left: editingPosition.x,
                        top: editingPosition.y,
                        width: math.max(100, editing.width * _camera.zoom),
                        height: math.max(80, editing.height * _camera.zoom),
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
    final title = (obj != null && obj.title.isNotEmpty) ? obj.title : 'Object';
    final element = CanvasElement({
      'id': _id(),
      'type': 'card',
      'objectId': objectId,
      'x': at.x - 130,
      'y': at.y - 60,
      'width': 260.0,
      'height': 120.0,
      'text': title,
      'color': _color,
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
                  PopupMenuItem(value: 'grid', child: Text('Math graph paper')),
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
                        Icon(Icons.autorenew, size: 16),
                        SizedBox(width: 8),
                        Text('Core Game Loop'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'level_design',
                    child: Row(
                      children: [
                        Icon(Icons.alt_route, size: 16),
                        SizedBox(width: 8),
                        Text('Level Design & Pacing'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'ai_state_machine',
                    child: Row(
                      children: [
                        Icon(Icons.psychology_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('AI State Machine'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'moodboard',
                    child: Row(
                      children: [
                        Icon(Icons.palette_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Art Direction & Moodboard'),
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
                tooltip: 'Canvas element list',
                onPressed: _showElementList,
                icon: const Icon(Icons.list_alt, size: 20),
              ),
              PopupMenuButton<CanvasArrangement>(
                tooltip: 'Arrange selected placements',
                enabled: _selection.length >= 2,
                icon: const Icon(Icons.align_horizontal_left, size: 20),
                itemBuilder: (_) => [
                  for (final action in CanvasArrangement.values)
                    PopupMenuItem(value: action, child: Text(action.label)),
                ],
                onSelected: (action) {
                  _finishText();
                  _cancelGesture();
                  final elements = _selection
                      .map((id) => _scene[id])
                      .whereType<CanvasElement>();
                  for (final element in arrangeCanvas(elements, action)) {
                    _history.put(element);
                  }
                  _commit();
                },
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
