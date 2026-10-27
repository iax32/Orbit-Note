import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// A detached render tree: no desktop automation, overlay, or note mutation.
Future<Uint8List> renderPublicationMath(
  String tex, {
  Color color = Colors.black,
}) async {
  if (tex.length > 4000) {
    throw const FormatException('Equation preview is too large.');
  }
  final boundary = RenderRepaintBoundary();
  final surface = RenderConstrainedOverflowBox(
    minWidth: 0,
    minHeight: 0,
    maxWidth: double.infinity,
    maxHeight: double.infinity,
    child: boundary,
  );
  final view = RenderView(
    view: ui.PlatformDispatcher.instance.views.first,
    configuration: const ViewConfiguration(
      logicalConstraints: BoxConstraints.tightFor(width: 1000, height: 400),
      physicalConstraints: BoxConstraints.tightFor(width: 1000, height: 400),
      devicePixelRatio: 1,
    ),
    child: surface,
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
        style: TextStyle(fontSize: 22, color: color),
        child: Math.tex(
          tex,
          textStyle: TextStyle(fontSize: 22, color: color),
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
    // Measure the complete formula before allocating pixels. A fixed viewport
    // can silently crop long aligned equations and tall matrices.
    final size = boundary.size;
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0 ||
        size.width > 8192 ||
        size.height > 8192 ||
        size.width * size.height > 4000000) {
      throw const FormatException(
        'Equation dimensions exceed the export limit.',
      );
    }
    pipeline.flushCompositingBits();
    pipeline.flushPaint();
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    } finally {
      image.dispose();
    }
  } finally {
    RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
    ).attachToRenderTree(owner, root);
    owner.finalizeTree();
    pipeline.rootNode = null;
    view.child = null;
    surface.child = null;
    boundary.dispose();
    surface.dispose();
    view.dispose();
    owner.focusManager.dispose();
  }
}
