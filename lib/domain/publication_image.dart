import 'package:path/path.dart' as p;

/// Image attachments remain Vault-rooted even when an embedded note was stored
/// at another depth. Decode one URI layer; never read outside Attachments/.
String? publicationAttachmentPath(String source) {
  final uri = Uri.tryParse(source);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      source.startsWith('/')) {
    return null;
  }
  try {
    var path = p.posix.normalize(Uri.decodeComponent(source));
    while (path.startsWith('../')) {
      path = path.substring(3);
    }
    if (!path.startsWith('Attachments/') ||
        path.contains('\\') ||
        path.contains(RegExp(r'[\x00-\x1f]'))) {
      return null;
    }
    return path;
  } on FormatException {
    return null;
  }
}
