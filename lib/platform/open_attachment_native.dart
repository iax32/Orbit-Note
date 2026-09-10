import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import '../infrastructure/storage/path_safety.dart';

Future<bool> openAttachment(
  String location,
  String reference, {
  bool reveal = false,
}) async {
  validateRelativePath(reference);
  final path = p.normalize(p.join(location, reference));
  if (!p.isWithin(p.normalize(location), path)) return false;
  if (reveal && Platform.isWindows) {
    await Process.run('explorer.exe', ['/select,', path]);
    return true;
  }
  return launchUrl(
    Uri.file(reveal ? p.dirname(path) : path, windows: Platform.isWindows),
  );
}
