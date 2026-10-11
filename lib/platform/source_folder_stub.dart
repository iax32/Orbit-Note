import '../domain/source_browser.dart';

class SourceFolder {
  SourceFolder(this.root);
  final String root;
  static const supported = false;
  Future<SourceFileListing> list() async =>
      throw UnsupportedError('Folder browsing requires a native app.');
  Future<String> read(String relativePath) async =>
      throw UnsupportedError('Folder browsing requires a native app.');
}
