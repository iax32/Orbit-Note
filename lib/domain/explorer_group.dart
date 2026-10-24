import 'universal_object.dart';
import 'code_preview.dart';

/// Display-only groups for unfiled objects; never moves durable content.
enum ExplorerGroup {
  notes('Notes'),
  canvases('Canvases'),
  pdfs('PDFs'),
  images('Images'),
  code('Code'),
  models('3D assets'),
  audio('Audio'),
  video('Video'),
  files('Files'),
  tasks('Tasks'),
  events('Events'),
  views('Views'),
  other('Other items');

  const ExplorerGroup(this.label);
  final String label;
}

ExplorerGroup explorerGroup(UniversalObject object) {
  switch (object.typeId) {
    case 'orbit.note':
      return ExplorerGroup.notes;
    case 'orbit.canvas':
      return ExplorerGroup.canvases;
    case 'orbit.task':
      return ExplorerGroup.tasks;
    case 'orbit.event':
      return ExplorerGroup.events;
    case 'orbit.view':
      return ExplorerGroup.views;
    case 'orbit.file':
      final mime = (object.properties['mimeType'] as String? ?? '')
          .toLowerCase();
      final original =
          (object.properties['originalName'] as String? ??
                  object.properties['contentRef'] as String? ??
                  object.title)
              .toLowerCase();
      final ext = original.split('.').last;
      if (mime == 'application/pdf' || ext == 'pdf') {
        return ExplorerGroup.pdfs;
      }
      if (mime.startsWith('image/') ||
          const {
            'png',
            'jpg',
            'jpeg',
            'webp',
            'gif',
            'bmp',
            'svg',
            'tif',
            'tiff',
            'avif',
            'heic',
          }.contains(ext)) {
        return ExplorerGroup.images;
      }
      if (mime.startsWith('model/') ||
          const {
            'glb',
            'gltf',
            'obj',
            'stl',
            'fbx',
            'blend',
            'mtl',
          }.contains(ext)) {
        return ExplorerGroup.models;
      }
      if (mime.startsWith('audio/') ||
          const {'mp3', 'wav', 'ogg', 'flac', 'm4a', 'aac'}.contains(ext)) {
        return ExplorerGroup.audio;
      }
      if (mime.startsWith('video/') ||
          const {'mp4', 'webm', 'mov', 'mkv', 'avi'}.contains(ext)) {
        return ExplorerGroup.video;
      }
      if ((codeLanguages[ext] ?? '').isNotEmpty && ext != 'md') {
        return ExplorerGroup.code;
      }
      return ExplorerGroup.files;
    default:
      return ExplorerGroup.other;
  }
}
