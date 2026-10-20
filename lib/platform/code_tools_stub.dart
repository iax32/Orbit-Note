import '../domain/code_project.dart';

CodeProject openCodeProject(String root) =>
    throw UnsupportedError('Project editing requires the desktop app.');
bool get codeToolsSupported => false;
Future<Map<String, String>> defaultCodeToolPaths() async => {};
Future<CodeToolProcess> startCodeTool(ToolCommand command, String root) async =>
    throw UnsupportedError('Local tools require the desktop app.');
Future<LanguageTransport> startCodeLanguageTool(
  ToolCommand command,
  String root,
) async => throw UnsupportedError('Language servers require the desktop app.');
