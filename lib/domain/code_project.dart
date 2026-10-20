import 'source_browser.dart';

class CodeSnapshot {
  const CodeSnapshot(this.path, this.text, this.hash, {this.hasBom = false});
  final String path, text;
  final String? hash;
  final bool hasBom;
}

class CodeRecoveredDraft {
  const CodeRecoveredDraft(this.path, this.baseHash, this.text);
  final String path, text;
  final String? baseHash;
}

class CodeHistoryEntry {
  const CodeHistoryEntry(
    this.id,
    this.path,
    this.before,
    this.after,
    this.savedAt,
  );
  final String id, path, before, after, savedAt;
}

abstract interface class CodeProject {
  String get root;
  Uri get rootUri;
  bool get supported;
  Future<SourceFileListing> list();
  Future<CodeSnapshot> read(String path);
  Future<CodeSnapshot> save(CodeSnapshot expected, String text);
  Future<void> writeDraft(CodeSnapshot base, String text);
  Future<CodeRecoveredDraft?> recoverDraft(String path);
  Future<void> clearDraft(String path);
  Future<List<CodeHistoryEntry>> history(String path);
  Future<void> createDirectory(String path);
  Future<Uri> buildOutput(String path);
  String? relativePath(Uri uri);
  Uri fileUri(String path);
}

bool validCodePath(String path) =>
    path.isNotEmpty &&
    path.length <= 4096 &&
    !path.startsWith('/') &&
    !RegExp(r'^[a-zA-Z]:').hasMatch(path) &&
    !path.contains(RegExp(r'[\\\x00\r\n]')) &&
    !path
        .split('/')
        .any(
          (s) =>
              s.isEmpty ||
              s == '.' ||
              s == '..' ||
              s.toLowerCase() == '.git' ||
              s.toLowerCase() == '.orbit-ide',
        ) &&
    sourceLanguage(path) != null;

class ToolCommand {
  ToolCommand(
    this.executable,
    List<String> arguments, {
    this.workingDirectory = '.',
  }) : arguments = List.unmodifiable(arguments) {
    if (executable.trim().isEmpty ||
        executable.length > 4096 ||
        executable.contains(RegExp(r'[\r\n\x00]')) ||
        arguments.length > 100 ||
        arguments.any((a) => a.length > 32768 || a.contains('\x00'))) {
      throw const FormatException(
        'Choose an executable and a valid argument list.',
      );
    }
  }
  final String executable;
  final List<String> arguments;
  final String workingDirectory;
}

abstract interface class CodeToolProcess {
  Stream<String> get output;
  Future<int> get exitCode;
  Future<void> writeInput(String text);
  Future<void> stop();
}

abstract interface class LanguageTransport {
  Stream<List<int>> get output;
  Future<void> send(List<int> bytes);
  Future<void> close();
}
