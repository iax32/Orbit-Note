import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../domain/publication_objects.dart';
import '../../../domain/universal_object.dart';
import '../../../domain/smart_view_query.dart';
import '../../canvas/canvas_painter.dart';
import 'publication_svg.dart';

/// The normal spatial painter, detached from desktop/UI interaction. Input is an
/// immutable opening snapshot; attachments still use the repository read adapter.
Future<Uint8List?> renderPublicationCanvas(
  PublicationCanvasSnapshot snapshot, {
  required List<UniversalObject> objects,
  required void Function(String) warn,
  Future<Uint8List?> Function(String)? readImage,
}) async {
  final scene = snapshot.scene;
  final bounds = scene.contentBounds?.inflate(40);
  if (bounds == null ||
      !bounds.width.isFinite ||
      !bounds.height.isFinite ||
      !bounds.left.isFinite ||
      !bounds.top.isFinite ||
      bounds.width <= 0 ||
      bounds.height <= 0 ||
      bounds.width > 10000000 ||
      bounds.height > 10000000) {
    throw const FormatException(
      'Canvas preview has invalid or excessive bounds.',
    );
  }
  final used = <String>{};
  for (final e in scene.elementsInOrder) {
    if (e.objectId != null) used.add(e.objectId!);
    final config = e.viewConfig;
    for (final id in [config?['view'], config?['viewId']]) {
      if (id is String) used.add(id);
    }
  }
  final byId = <String, CanvasObjectReference>{};
  final ids = <String>{}, duplicate = <String>{};
  for (final o in objects) {
    if (!ids.add(o.id)) duplicate.add(o.id);
  }
  for (final o in objects) {
    if (!duplicate.contains(o.id) && !o.isDeleted && !o.isReadOnly) {
      List<String>? memberIds;
      String? queryIssue;
      if (o.typeId == 'orbit.view' && used.contains(o.id)) {
        try {
          memberIds = resolveSmartView(
            o,
            objects,
            pathFor: (id) => snapshot.paths[id],
            now: snapshot.now,
          ).map((m) => m.id).toList();
        } catch (_) {
          queryIssue = 'Collection snapshot unavailable';
          warn(
            'Canvas collection snapshot could not resolve its saved definition: ${o.title}',
          );
        }
      }
      byId[o.id] = CanvasObjectReference(
        id: o.id,
        title: o.title,
        typeId: o.typeId,
        body: used.contains(o.id) ? publicationCardBody(o.body) : '',
        properties: o.properties,
        viewMemberIds: memberIds,
        viewQueryIssue: queryIssue,
      );
    }
  }
  final references = <String>{};
  for (final e in scene.elementsInOrder) {
    final card = byId[e.objectId];
    if (e.type == 'image' && e.data['contentRef'] is String) {
      references.add(e.data['contentRef'] as String);
    }
    if (e.type == 'card' && card?.isImage == true && card?.contentRef != null) {
      references.add(card!.contentRef!);
    }
    if (e.type == 'card' && e.data['contentRef'] is String) {
      references.add(e.data['contentRef'] as String);
    }
    if (e.type == 'audio' ||
        e.type == 'card' && card?.typeId == 'orbit.canvas') {
      warn(
        'Canvas media/nested boards use labelled static cards: ${snapshot.object.title}',
      );
    }
    if (e.type == 'card' && e.objectId != null && card == null) {
      warn('Canvas card source unavailable: ${e.objectId}');
    }
  }
  if (references.length > 24) {
    warn(
      'Canvas preview embeds the first 24 images; remaining image cards retain placeholders: ${snapshot.object.title}',
    );
  }
  final images = <String, ui.Image>{};
  var total = 0;
  try {
    for (final reference in references.take(24)) {
      try {
        // Canvas attachment capture is local-only, even when web images are
        // explicitly enabled elsewhere in the document.
        if (Uri.tryParse(reference)?.hasScheme == true ||
            reference.startsWith('//')) {
          throw const FormatException('External Canvas image');
        }
        var bytes = await readImage?.call(reference);
        if (bytes == null ||
            bytes.length > 20 * 1024 * 1024 ||
            total + bytes.length > 64 * 1024 * 1024) {
          throw const FormatException('Missing/large Canvas image');
        }
        total += bytes.length;
        if (isPublicationSvg(bytes)) bytes = await renderPublicationSvg(bytes);
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        ui.ImageDescriptor? descriptor;
        ui.Codec? codec;
        try {
          descriptor = await ui.ImageDescriptor.encoded(buffer);
          if (descriptor.width * descriptor.height > 100000000) {
            throw const FormatException('Canvas image exceeds pixel limit');
          }
          final longest = descriptor.width > descriptor.height
              ? descriptor.width
              : descriptor.height;
          final scale = longest > 1024 ? 1024 / longest : 1.0;
          codec = await descriptor.instantiateCodec(
            targetWidth: (descriptor.width * scale).round().clamp(1, 1024),
            targetHeight: (descriptor.height * scale).round().clamp(1, 1024),
          );
          images[reference] = (await codec.getNextFrame()).image;
          if (codec.frameCount > 1) {
            warn('Canvas animated image uses its first frame: $reference');
          }
        } finally {
          codec?.dispose();
          descriptor?.dispose();
          buffer.dispose();
        }
      } catch (_) {
        warn('Canvas image unavailable; placeholder retained: $reference');
      }
    }
    final longest = bounds.width > bounds.height ? bounds.width : bounds.height;
    final scale = longest > 800 ? 1600 / longest : 2.0;
    return await renderCanvasToPng(
      scene: scene,
      colors: ColorScheme.fromSeed(
        seedColor: const Color(0xff8b7cf6),
        brightness: Brightness.dark,
      ),
      backgroundStyle: snapshot.object.data['backgroundStyle'] is String
          ? snapshot.object.data['backgroundStyle'] as String
          : 'dots',
      bounds: bounds,
      scale: scale,
      images: images,
      objects: byId,
      forceUmlDetails: true,
    );
  } finally {
    for (final image in images.values) {
      image.dispose();
    }
  }
}
