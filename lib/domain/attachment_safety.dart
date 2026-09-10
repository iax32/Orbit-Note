/// File ownership is unrestricted. Opening a potentially executable file is an
/// explicit action; revealing it in Explorer never executes its contents.
bool attachmentNeedsConfirmation(String name) {
  final extension = name.split('.').last.toLowerCase();
  return !const {
    'txt',
    'md',
    'pdf',
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
    'bmp',
    'tiff',
    'mp3',
    'wav',
    'ogg',
    'flac',
    'mp4',
    'mkv',
    'mov',
    'avi',
    'docx',
    'xlsx',
    'pptx',
    'odt',
    'ods',
    'odp',
    'csv',
    'json',
    'yaml',
    'yml',
  }.contains(extension);
}
