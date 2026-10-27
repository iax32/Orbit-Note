import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../domain/note_writing_appearance.dart';
import '../note_writing_surface.dart';
import '../writing_photo_layer.dart';
import 'publication_math.dart';

/// A device-local opening snapshot. It never adds private design/photo recipes
/// to authored Markdown, document settings, object properties or cloud records.
class PublicationPdfTheme {
  PublicationPdfTheme(
    ThemeData base, {
    this.appearance = const NoteWritingAppearance(),
    this.highContrast = false,
    this.editorFontSize = 16,
    this.readPhoto,
  }) : theme = writingSurfaceTheme(appearance, base);
  final ThemeData theme;
  final NoteWritingAppearance appearance;
  final bool highContrast;
  final double editorFontSize;
  final Future<Uint8List?> Function(String)? readPhoto;
  final _pages = <String, Future<Uint8List>>{};
  final _equations = <String, Future<Uint8List>>{};
  Future<Uint8List?>? _photo;
  String get name =>
      '${writingDesignName(appearance.design)} · ${writingPaperName(appearance.paper)}';
  String? get fontFamily => writingDesignFont(appearance);
  String? get fontPrefix => switch (fontFamily) {
    'OrbitPixel' => 'assets/writing/Tiny5',
    'OrbitBook' => 'assets/publishing/CrimsonText',
    'OrbitTerminal' => 'assets/writing/SpaceMono',
    _ => null,
  };
  Future<Uint8List> equation(String tex) => _equations.putIfAbsent(
    tex,
    () => renderPublicationMath(tex, color: theme.colorScheme.onSurface),
  );

  Future<Uint8List> page(
    double width,
    double height,
    double margin,
    double fontSize,
    void Function(String) warn,
  ) {
    final key = '$width/$height/$margin/$fontSize';
    final cached = _pages.remove(key);
    if (cached != null) {
      _pages[key] = cached;
      return cached;
    }
    // Sliders can create many print sizes in one session. Keep a small LRU,
    // rather than retaining every photo-backed page until the dialog closes.
    if (_pages.length >= 4) _pages.remove(_pages.keys.first);
    return _pages[key] = _paint(width, height, margin, fontSize, warn);
  }

  Future<Uint8List> _paint(
    double width,
    double height,
    double margin,
    double fontSize,
    void Function(String) warn,
  ) async {
    final ratio =
        (editorFontSize.isFinite && editorFontSize >= 8 && editorFontSize <= 100
            ? editorFontSize
            : 16) /
        fontSize;
    final logical = Size(width * ratio, height * ratio);
    final scale = 3 / ratio;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    final rect = Offset.zero & logical;
    final background = writingPageColor(appearance.design, theme);
    canvas.drawRect(rect, Paint()..color = background);
    final inset = appearance.design == WritingDesign.orbit ? 0.0 : 20.0;
    WritingSurfacePainter(
      appearance,
      theme,
      inset: inset,
      highContrast: highContrast,
    ).paint(canvas, logical);
    ui.Image? photoImage;
    ui.Codec? photoCodec;
    ui.ImageDescriptor? descriptor;
    ui.ImmutableBuffer? buffer;
    final photo = appearance.photo;
    if (photo != null && !highContrast) {
      try {
        _photo ??= readPhoto?.call(photo.id) ?? Future.value(null);
        final data = await _photo!.timeout(const Duration(seconds: 10));
        if (data == null || data.length > 2 * 1024 * 1024) {
          throw const FormatException('Photo unavailable');
        }
        buffer = await ui.ImmutableBuffer.fromUint8List(data);
        descriptor = await ui.ImageDescriptor.encoded(buffer);
        if (descriptor.width > 12000 ||
            descriptor.height > 12000 ||
            descriptor.width * descriptor.height > 16000000) {
          throw const FormatException(
            'Background photo exceeds safe dimensions.',
          );
        }
        final downsample = math.min(
          1.0,
          1800 / math.max(descriptor.width, descriptor.height),
        );
        photoCodec = await descriptor.instantiateCodec(
          targetWidth: math.max(1, (descriptor.width * downsample).round()),
          targetHeight: math.max(1, (descriptor.height * downsample).round()),
        );
        photoImage = (await photoCodec.getNextFrame()).image;
        final desktop =
            appearance.design == WritingDesign.retro ||
            appearance.design == WritingDesign.command;
        final photoRect = Rect.fromLTRB(
          inset,
          inset + (desktop ? 30 : 0),
          logical.width - inset,
          logical.height - inset,
        );
        final saved = canvas.getSaveCount();
        canvas.save();
        try {
          canvas.clipRect(photoRect);
          paintImage(
            canvas: canvas,
            rect: photoRect,
            image: photoImage,
            fit: photo.contain ? BoxFit.contain : BoxFit.cover,
            alignment: Alignment(photo.x, photo.y),
            opacity: photo.readingSheet
                ? photo.opacity
                : math.min(photo.opacity, readablePhotoOpacity(theme)),
          );
          if (photo.readingSheet) {
            final sheet = Rect.fromLTRB(
              margin * ratio - 12,
              photoRect.top,
              logical.width - margin * ratio + 12,
              photoRect.bottom,
            );
            canvas.drawRect(
              sheet,
              Paint()
                ..color = theme.colorScheme.surface.withValues(
                  alpha: 1 - readablePhotoOpacity(theme).clamp(0, .04),
                ),
            );
            canvas.save();
            canvas.clipRect(sheet);
            WritingSurfacePainter(
              appearance.copyWith(design: WritingDesign.orbit),
              theme,
              inset: 0,
              highContrast: highContrast,
            ).paint(canvas, logical);
            canvas.restore();
          }
        } finally {
          canvas.restoreToCount(saved);
        }
      } catch (_) {
        warn(
          'Personal background photo unavailable; editor paper design retained.',
        );
      }
    }
    final picture = recorder.endRecording();
    ui.Image? image;
    try {
      image = await picture.toImage((width * 3).ceil(), (height * 3).ceil());
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) {
        throw const FormatException(
          'Editor page design could not be rendered.',
        );
      }
      return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    } finally {
      image?.dispose();
      picture.dispose();
      photoImage?.dispose();
      photoCodec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}
