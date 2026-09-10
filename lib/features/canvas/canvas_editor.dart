import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../canvas/geometry.dart';
import '../../canvas/arrangement.dart';
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

class CanvasEditor extends StatefulWidget {
  const CanvasEditor({
    super.key,
    required this.canvasId,
    required this.data,
    required this.onChanged,
    required this.objects,
    required this.onOpenObject,
    this.camera,
    this.onCameraChanged,
    this.imageLoader,
    this.onInsertImage,
    this.onPasteImage,
  });
  final String canvasId;
  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final List<CanvasObjectReference> objects;
  final ValueChanged<String> onOpenObject;
  final Map<String, dynamic>? camera;
  final ValueChanged<Map<String, dynamic>>? onCameraChanged;
  final Future<Uint8List?> Function(String)? imageLoader;
  final Future<CanvasImageReference?> Function()? onInsertImage, onPasteImage;

  @override
  State<CanvasEditor> createState() => _CanvasEditorState();
}

class _CanvasEditorState extends State<CanvasEditor> {
  late CanvasHistory _history;
  late CanvasCamera _camera;
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
    _history = CanvasHistory(CanvasScene.fromJson(widget.data));
    _camera = CanvasCamera.fromJson(widget.camera);
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
    if (oldWidget.canvasId != widget.canvasId) {
      _history = CanvasHistory(CanvasScene.fromJson(widget.data));
      _camera = CanvasCamera.fromJson(widget.camera);
      _selection.clear();
      _editingId = null;
      _clearGesture();
      _lastEmitted = null;
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
    _images?.dispose();
    _textCache.dispose();
    _focus.dispose();
    _text.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  void _emit() {
    final data = _scene.toJson();
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
        final hit = _scene.hit(_start!, tolerance: 6 / _camera.zoom);
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
      if (!(_scene[id]?.locked ?? true)) _history.remove(id);
    }
    _selection.clear();
    _commit();
  }

  Future<void> _copy({bool cut = false}) async {
    final elements = _selection
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
    if (cut && mounted) _delete();
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
        for (final original in originals) {
          final element = original.copy({
            'id': _id(),
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

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _edit(CanvasElement element) {
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
    if (_scene.readOnly ||
        !{
          'text',
          'sticky',
          'rectangle',
          'ellipse',
          'diamond',
          'frame',
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
          return AlertDialog(
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
      builder: (context) => AlertDialog(
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
    final hit = _scene.hit(
      _world(event.localPosition),
      tolerance: 6 / _camera.zoom,
    );
    if (hit != null && !_selection.contains(hit.id)) {
      setState(() {
        _selection
          ..clear()
          ..add(hit.id);
      });
    }
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
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
        const PopupMenuItem(value: 'paste', child: Text('Paste')),
        if (_selection.isNotEmpty && !_scene.readOnly)
          const PopupMenuItem(
            value: 'delete',
            child: Text('Remove from Canvas'),
          ),
        const PopupMenuItem(value: 'fit', child: Text('Fit content')),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'edit':
        if (_selection.length == 1) _edit(_scene[_selection.first]!);
      case 'copy':
        _copy();
      case 'paste':
        _paste();
      case 'delete':
        _delete();
      case 'fit':
        _fit();
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
        _toolbar(context),
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
                      child: Semantics(
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
                                                  -scroll.scrollDelta.dy * .002,
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
                                ),
                                child: const SizedBox.expand(),
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
                            TextButton(
                              onPressed: () => _zoom(1 / _camera.zoom),
                              child: Text('${(_camera.zoom * 100).round()}%'),
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
                          ],
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
                  child: IconButton.filledTonal(
                    tooltip: item.$3,
                    isSelected: _tool == item.$1,
                    onPressed:
                        _scene.readOnly &&
                            item.$1 != _Tool.pan &&
                            item.$1 != _Tool.select
                        ? null
                        : () => _setTool(item.$1),
                    style: IconButton.styleFrom(
                      backgroundColor: _tool == item.$1
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Colors.transparent,
                      foregroundColor: _tool == item.$1
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    icon: Icon(item.$2, size: 20),
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
