import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// A detached render tree: no desktop automation, overlay, or note mutation.
Future<Uint8List> renderPublicationMath(String tex) async {
  if (tex.length > 4000) {
    throw const FormatException('Equation preview is too large.');
  }
  final boundary = RenderRepaintBoundary();
  final view = RenderView(
    view: ui.PlatformDispatcher.instance.views.first,
    configuration: const ViewConfiguration(
      logicalConstraints: BoxConstraints.tightFor(width: 1000, height: 400),
      physicalConstraints: BoxConstraints.tightFor(width: 1000, height: 400),
      devicePixelRatio: 1,
    ),
    child: RenderPositionedBox(alignment: Alignment.center, child: boundary),
  );
  final pipeline = PipelineOwner()..rootNode = view;
  final owner = BuildOwner(focusManager: FocusManager());
  String? parseError;
  view.prepareInitialFrame();
  final root = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 22, color: Colors.black),
        child: Math.tex(
          tex,
          textStyle: const TextStyle(fontSize: 22, color: Colors.black),
          onErrorFallback: (error) {
            parseError = error.toString();
            return const SizedBox();
          },
        ),
      ),
    ),
  ).attachToRenderTree(owner);
  try {
    owner.buildScope(root);
    if (parseError != null) {
      throw FormatException('Unsupported equation: $parseError');
    }
    pipeline.flushLayout();
    pipeline.flushCompositingBits();
    pipeline.flushPaint();
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      return (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
    ).attachToRenderTree(owner, root);
    owner.finalizeTree();
    pipeline.rootNode = null;
    view.dispose();
    owner.focusManager.dispose();
  }
}
