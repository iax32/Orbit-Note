import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import '../../domain/writing_photo.dart';

class ImportedWritingPhoto {
  const ImportedWritingPhoto(this.photo, this.bytes);
  final WritingPhoto photo;
  final Uint8List bytes;
}

Future<ImportedWritingPhoto?> pickWritingPhoto({
  Future<XFile?> Function()? picker,
}) async {
  final file =
      await (picker ??
          () => openFile(
            acceptedTypeGroups: const [
              XTypeGroup(
                label: 'Background photo',
                extensions: ['png', 'jpg', 'jpeg', 'webp'],
                mimeTypes: ['image/png', 'image/jpeg', 'image/webp'],
              ),
            ],
          ))();
  if (file == null) return null;
  if (await file.length() > 16 * 1024 * 1024) {
    throw const FormatException('Choose a photo smaller than 16 MiB.');
  }
  final bytes = await normalizeWritingPhoto(await file.readAsBytes());
  final name = file.name.replaceAll(RegExp(r'[\x00-\x1f]'), ' ');
  return ImportedWritingPhoto(
    WritingPhoto(
      id: sha256.convert(bytes).toString(),
      name: name.isEmpty
          ? 'Personal photo'
          : name.substring(0, name.length.clamp(0, 120)),
    ),
    bytes,
  );
}

/// Decode the first frame only, remove metadata, and bound both pixels and bytes.
Future<Uint8List> normalizeWritingPhoto(Uint8List source) async {
  if (source.isEmpty || source.length > 16 * 1024 * 1024) {
    throw const FormatException('Choose a photo smaller than 16 MiB.');
  }
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(source);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width > 10000 ||
        descriptor.height > 10000 ||
        descriptor.width * descriptor.height > 40000000) {
      throw const FormatException(
        'Choose a photo below 40 megapixels and 10,000 pixels per side.',
      );
    }
    for (final edge in [1600, 1280, 1024, 800]) {
      final longest = descriptor.width > descriptor.height
          ? descriptor.width
          : descriptor.height;
      final scale = longest > edge ? edge / longest : 1.0;
      final codec = await descriptor.instantiateCodec(
        targetWidth: (descriptor.width * scale).round().clamp(1, edge),
        targetHeight: (descriptor.height * scale).round().clamp(1, edge),
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final data = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (data != null && data.lengthInBytes <= WritingPhoto.maxBytes) {
            final result = Uint8List.fromList(
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            );
            validateWritingPhotoBytes(result);
            return result;
          }
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    }
    throw const FormatException(
      'This photo is too detailed to fit the background limit.',
    );
  } on FormatException {
    rethrow;
  } on Object {
    throw const FormatException(
      'Could not decode this photo. Choose PNG, JPEG or WebP.',
    );
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
}
