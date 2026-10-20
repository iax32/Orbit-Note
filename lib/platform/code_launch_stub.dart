import '../domain/code_launch.dart';

CodeLaunchStore openCodeLaunchStore(String root) =>
    throw UnsupportedError('Launch profiles require desktop.');
Future<CodeWebPreview> startCodeWebPreview(String root, String entry) async =>
    throw UnsupportedError('Web preview requires desktop.');
