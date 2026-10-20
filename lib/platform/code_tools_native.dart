import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../domain/code_project.dart';
import '../domain/code_launch.dart';
import '../domain/source_browser.dart';
import 'source_folder_native.dart';

bool get codeToolsSupported => !Platform.isAndroid && !Platform.isIOS;
Future<Map<String, String>> defaultCodeToolPaths() async {
  final result = <String, String>{};
  for (final (key, names) in [
    ('python', ['python3', 'python', 'py']),
    ('compiler', ['clang++', 'g++', 'cl']),
  ]) {
    for (final name in names) {
      for (final folder
          in (Platform.environment['PATH'] ??
                  Platform.environment['Path'] ??
                  '')
              .split(p.separator == '\\' ? ';' : ':')) {
        if (folder.toLowerCase().contains('windowsapps')) continue;
        final file = File(
          p.join(folder, '$name${Platform.isWindows ? '.exe' : ''}'),
        );
        if (await file.exists()) {
          result[key] = file.path;
          break;
        }
      }
      if (result.containsKey(key)) break;
    }
  }
  if (Platform.isWindows && !result.containsKey('compiler')) {
    final programs =
        Platform.environment['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)';
    for (final edition in [
      'BuildTools',
      'Community',
      'Professional',
      'Enterprise',
    ]) {
      final directory = Directory(
        p.join(
          programs,
          'Microsoft Visual Studio',
          '2022',
          edition,
          'VC',
          'Tools',
          'MSVC',
        ),
      );
      if (!await directory.exists()) continue;
      final versions = await directory
          .list()
          .where((e) => e is Directory)
          .toList();
      versions.sort((a, b) => b.path.compareTo(a.path));
      for (final version in versions) {
        final file = File(
          p.join(version.path, 'bin', 'Hostx64', 'x64', 'cl.exe'),
        );
        if (await file.exists()) {
          result['compiler'] = file.path;
          break;
        }
      }
      if (result.containsKey('compiler')) break;
    }
  }
  return result;
}

CodeProject openCodeProject(String root) {
  if (!codeToolsSupported) {
    throw UnsupportedError('Project editing requires the desktop app.');
  }
  return NativeCodeProject(root);
}

class NativeCodeProject implements CodeProject {
  NativeCodeProject(this.root);
  @override
  final String root;
  String? _resolved;
  final String sessionId = const Uuid().v4();
  Future<void> _tail = Future.value();
  static final _projectSaves = <String, Future<void>>{};
  Future<T> _withProjectSave<T>(Future<T> Function() action) async {
    final key = await _anchor();
    final result = (_projectSaves[key] ?? Future<void>.value()).then(
      (_) => action(),
    );
    final done = result.then<void>((_) {}, onError: (Object _) {});
    _projectSaves[key] = done;
    try {
      return await result;
    } finally {
      if (identical(_projectSaves[key], done)) _projectSaves.remove(key);
    }
  }

  @override
  bool get supported => codeToolsSupported;
  @override
  Uri get rootUri => Uri.directory(p.absolute(root));
  @override
  Uri fileUri(String path) {
    if (!validCodePath(path)) {
      throw const FormatException('Choose a source file in this project.');
    }
    return rootUri.resolveUri(Uri(path: path));
  }

  @override
  String? relativePath(Uri uri) {
    if (uri.scheme != 'file' || uri.hasQuery || uri.hasFragment) return null;
    final target = p.fromUri(uri), base = p.absolute(root);
    if (!p.isWithin(base, target)) return null;
    final path = p.relative(target, from: base).replaceAll('\\', '/');
    return validCodePath(path) ? path : null;
  }

  Future<String> _anchor() async {
    final actual = await Directory(root).resolveSymbolicLinks();
    _resolved ??= actual;
    if (actual != _resolved) {
      throw const FormatException(
        'The selected project location changed. Reopen it.',
      );
    }
    return actual;
  }

  Future<File> _file(String path) async {
    if (!validCodePath(path)) {
      throw const FormatException('Choose a supported relative source file.');
    }
    final base = await _anchor(), file = File(p.join(await _anchor(), path));
    final exists = await file.exists();
    final actual = exists
        ? await file.resolveSymbolicLinks()
        : p.join(
            await file.parent.resolveSymbolicLinks(),
            p.basename(file.path),
          );
    if (!p.isWithin(base, actual)) {
      throw const FormatException(
        'This source is outside the selected project.',
      );
    }
    return File(actual);
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<Directory> _state() async {
    final base = await _anchor();
    final directory = Directory(p.join(base, '.orbit-ide'));
    if (!await directory.exists()) await directory.create();
    if (await directory.resolveSymbolicLinks() != directory.path) {
      throw const FormatException(
        'IDE state must be inside the selected project, not a symbolic link.',
      );
    }
    return directory;
  }

  Future<File> _stateFile(String section, String name) async {
    final state = await _state();
    final directory = Directory(p.join(state.path, section));
    if (!await directory.exists()) await directory.create();
    if (await directory.resolveSymbolicLinks() != directory.path) {
      throw const FormatException('IDE state folder changed.');
    }
    final file = File(p.join(directory.path, name));
    if (await file.exists() && await file.resolveSymbolicLinks() != file.path) {
      throw const FormatException('IDE state file is a link.');
    }
    return file;
  }

  @override
  Future<void> createDirectory(String path) => _serialize(() async {
    if (path.isEmpty ||
        path.startsWith('/') ||
        path.contains(RegExp(r'[\\:\x00\r\n]')) ||
        path
            .split('/')
            .any(
              (s) => s.isEmpty || s == '.' || s == '..' || s.startsWith('.'),
            )) {
      throw const FormatException('Choose a normal relative folder name.');
    }
    final base = await _anchor(),
        directory = Directory(p.join(await _anchor(), path));
    final parent = await directory.parent.resolveSymbolicLinks();
    if (parent != base && !p.isWithin(base, parent)) {
      throw const FormatException('Folder is outside this project.');
    }
    if (await directory.exists()) {
      throw const FormatException('This folder already exists.');
    }
    await directory.create();
  });
  @override
  Future<Uri> buildOutput(String path) async {
    if (!validCodePath(path)) {
      throw const FormatException('Invalid build source.');
    }
    return (await _stateFile(
      'build',
      '${_key(path)}${Platform.isWindows ? '.exe' : ''}',
    )).uri;
  }

  String _key(String path) => sha256
      .convert(utf8.encode(Platform.isWindows ? path.toLowerCase() : path))
      .toString();
  Future<void> _replace(File target, List<int> bytes) async {
    final temporary = File('${target.path}.${const Uuid().v4()}.tmp');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(target.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  @override
  Future<SourceFileListing> list() async =>
      SourceFolder(await _anchor()).list();
  @override
  Future<CodeSnapshot> read(String path) async {
    final file = await _file(path);
    final bytes = await file.open().then((input) async {
      try {
        return await input.read(1024 * 1024 + 1);
      } finally {
        await input.close();
      }
    });
    if (bytes.length > 1024 * 1024 || bytes.contains(0)) {
      throw const FormatException('Edit UTF-8 text files up to 1 MiB.');
    }
    return CodeSnapshot(
      path,
      utf8.decode(bytes),
      sha256.convert(bytes).toString(),
      hasBom:
          bytes.length >= 3 &&
          bytes[0] == 0xef &&
          bytes[1] == 0xbb &&
          bytes[2] == 0xbf,
    );
  }

  @override
  Future<CodeSnapshot> save(CodeSnapshot expected, String text) => _serialize(
    () => _withProjectSave(() async {
      final bytes = utf8.encode(
        expected.hasBom && !text.startsWith('\uFEFF') ? '\uFEFF$text' : text,
      );
      if (bytes.length > 1024 * 1024 || bytes.contains(0)) {
        throw const FormatException('Save UTF-8 source up to 1 MiB.');
      }
      final state = await _state();
      final lockFile = File(p.join(state.path, 'save.lock'));
      if (await lockFile.exists() &&
          await lockFile.resolveSymbolicLinks() != lockFile.path) {
        throw const FormatException('IDE lock is a link.');
      }
      final lock = await lockFile.open(mode: FileMode.append);
      try {
        await lock.lock(FileLock.exclusive);
        final file = await _file(expected.path);
        final exists = await file.exists();
        final before = exists
            ? await read(expected.path)
            : CodeSnapshot(expected.path, '', null);
        if (before.hash != expected.hash) {
          throw const FormatException(
            'Source changed outside this editor. Compare or copy your draft before reloading.',
          );
        }
        if (before.text == text && exists) return before;
        final afterHash = sha256.convert(bytes).toString();
        final id =
            '${_key(expected.path)}-${DateTime.now().microsecondsSinceEpoch}-${const Uuid().v4()}.json';
        final history = await _stateFile('history', id);
        await _replace(
          history,
          utf8.encode(
            jsonEncode({
              'version': 1,
              'path': expected.path,
              'before': before.text,
              'after': text,
              'beforeHash': before.hash,
              'hasBom': before.hasBom,
              'afterHash': afterHash,
              'savedAt': DateTime.now().toUtc().toIso8601String(),
            }),
          ),
        );
        // History is flushed first. Check the source again immediately before replacement.
        final check = await file.exists()
            ? (await read(expected.path)).hash
            : null;
        if (check != expected.hash) {
          throw const FormatException(
            'Source changed during save. Its contents and your history are retained.',
          );
        }
        await _file(expected.path);
        await _replace(file, bytes);
        return CodeSnapshot(
          expected.path,
          text,
          afterHash,
          hasBom: before.hasBom,
        );
      } finally {
        try {
          await lock.unlock();
        } on Object {
          /* A failed lock acquisition owns no lock. */
        }
        await lock.close();
      }
    }),
  );
  @override
  Future<void> writeDraft(CodeSnapshot base, String text) =>
      _serialize(() async {
        if (utf8.encode(text).length > 1024 * 1024) {
          throw const FormatException(
            'Draft exceeds 1 MiB. Copy it before closing.',
          );
        }
        if (!validCodePath(base.path)) {
          throw const FormatException('Invalid source path.');
        }
        final file = await _stateFile(
          'drafts',
          '${_key(base.path)}-$sessionId.json',
        );
        await _replace(
          file,
          utf8.encode(
            jsonEncode({
              'version': 1,
              'path': base.path,
              'baseHash': base.hash,
              'text': text,
            }),
          ),
        );
      });
  @override
  Future<CodeRecoveredDraft?> recoverDraft(String path) async {
    if (!validCodePath(path)) {
      throw const FormatException('Invalid source path.');
    }
    final directory = Directory(
      p.join(await _anchor(), '.orbit-ide', 'drafts'),
    );
    if (!await directory.exists()) return null;
    final probe = await _stateFile('drafts', '.probe');
    final files = await probe.parent
        .list(followLinks: false)
        .where(
          (e) =>
              e is File &&
              p.basename(e.path).startsWith('${_key(path)}-') &&
              e.path.endsWith('.json'),
        )
        .take(100)
        .toList();
    if (files.isEmpty) return null;
    final dates = {
      for (final file in files) file.path: (await file.stat()).modified,
    };
    files.sort((a, b) => dates[b.path]!.compareTo(dates[a.path]!));
    final safe = await _stateFile('drafts', p.basename(files.first.path));
    if (await safe.length() > 8 * 1024 * 1024) {
      throw const FormatException('Recovered draft is too large.');
    }
    final value = jsonDecode(await safe.readAsString());
    if (value is! Map ||
        value['version'] != 1 ||
        value['path'] != path ||
        value['text'] is! String ||
        (value['text'] as String).contains('\u0000') ||
        utf8.encode(value['text'] as String).length > 1024 * 1024 ||
        (value['baseHash'] != null && value['baseHash'] is! String)) {
      throw const FormatException(
        'Unsupported recovered draft. It was left intact.',
      );
    }
    return CodeRecoveredDraft(
      path,
      value['baseHash'] as String?,
      value['text'] as String,
    );
  }

  @override
  Future<void> clearDraft(String path) => _serialize(() async {
    if (!validCodePath(path)) {
      throw const FormatException('Invalid source path.');
    }
    if (!await File(
      p.join(
        await _anchor(),
        '.orbit-ide',
        'drafts',
        '${_key(path)}-$sessionId.json',
      ),
    ).exists()) {
      return;
    }
    final file = await _stateFile('drafts', '${_key(path)}-$sessionId.json');
    if (await file.exists()) await file.delete();
  });
  @override
  Future<List<CodeHistoryEntry>> history(String path) async {
    if (!validCodePath(path)) {
      throw const FormatException('Invalid source path.');
    }
    final directory = Directory(
      p.join(await _anchor(), '.orbit-ide', 'history'),
    );
    if (!await directory.exists()) return [];
    final safe = await _stateFile('history', '.probe');
    final files = await safe.parent
        .list(followLinks: false)
        .where(
          (f) =>
              f is File &&
              p.basename(f.path).startsWith('${_key(path)}-') &&
              f.path.endsWith('.json'),
        )
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    final result = <CodeHistoryEntry>[];
    for (final entry in files.take(50)) {
      final file = await _stateFile('history', p.basename(entry.path));
      if (await file.length() > 16 * 1024 * 1024) continue;
      final value = jsonDecode(await file.readAsString());
      if (value is Map &&
          value['version'] == 1 &&
          value['path'] == path &&
          value['before'] is String &&
          value['after'] is String &&
          value['savedAt'] is String) {
        result.add(
          CodeHistoryEntry(
            p.basename(file.path),
            path,
            value['before'] as String,
            value['after'] as String,
            value['savedAt'] as String,
          ),
        );
      }
    }
    return result;
  }
}

Future<Process> _start(ToolCommand command, String root) async {
  if (!codeToolsSupported) {
    throw UnsupportedError('Local tools require desktop.');
  }
  if (RegExp(
    r'\.(cmd|bat)$',
    caseSensitive: false,
  ).hasMatch(command.executable)) {
    throw const FormatException(
      'Choose the actual executable (python/node/clangd), with module or script arguments. Shell wrappers are not run.',
    );
  }
  Map<String, String>? environment;
  if (RegExp(
    r'^(python[0-9.]*|py)(\.exe)?$',
    caseSensitive: false,
  ).hasMatch(p.basename(command.executable))) {
    environment = {'PYTHONIOENCODING': 'utf-8', 'PYTHONUTF8': '1'};
  }
  if (Platform.isWindows &&
      p.basename(command.executable).toLowerCase() == 'cl.exe' &&
      p.isAbsolute(command.executable)) {
    final vc = p.normalize(
      p.join(p.dirname(command.executable), '..', '..', '..'),
    );
    final kits = Directory(
      p.join(
        Platform.environment['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)',
        'Windows Kits',
        '10',
      ),
    );
    final include = Directory(p.join(kits.path, 'Include'));
    if (await include.exists() &&
        await Directory(p.join(vc, 'include')).exists()) {
      final versions = await include
          .list()
          .where((e) => e is Directory)
          .toList();
      versions.sort((a, b) => b.path.compareTo(a.path));
      for (final version in versions) {
        final sdk = p.basename(version.path);
        if (!await Directory(
          p.join(kits.path, 'Lib', sdk, 'um', 'x64'),
        ).exists()) {
          continue;
        }
        environment = {
          'INCLUDE': [
            p.join(vc, 'include'),
            for (final area in ['ucrt', 'shared', 'um'])
              p.join(version.path, area),
          ].join(';'),
          'LIB': [
            p.join(vc, 'lib', 'x64'),
            for (final area in ['ucrt', 'um'])
              p.join(kits.path, 'Lib', sdk, area, 'x64'),
          ].join(';'),
          'PATH':
              '${p.dirname(command.executable)};${Platform.environment['PATH'] ?? Platform.environment['Path'] ?? ''}',
        };
        break;
      }
    }
  }
  if (!validCodeWorkingDirectory(command.workingDirectory)) {
    throw const FormatException('Choose a project-relative working folder.');
  }
  final base = await Directory(root).resolveSymbolicLinks();
  final working = await Directory(
    p.join(base, command.workingDirectory),
  ).resolveSymbolicLinks();
  if (working != base && !p.isWithin(base, working)) {
    throw const FormatException('Working folder is outside this project.');
  }
  return Process.start(
    command.executable,
    command.arguments,
    workingDirectory: working,
    runInShell: false,
    environment: environment,
  );
}

Future<CodeToolProcess> startCodeTool(ToolCommand command, String root) async =>
    _NativeToolProcess(await _start(command, root));

CodeLaunchStore openCodeLaunchStore(String root) =>
    _NativeLaunchStore(NativeCodeProject(root));

class _NativeLaunchStore implements CodeLaunchStore {
  _NativeLaunchStore(this.project);
  final NativeCodeProject project;
  @override
  Future<CodeLaunchSnapshot> load() async {
    final candidate = File(
      p.join(await project._anchor(), '.orbit-ide', 'config', 'launch.json'),
    );
    if (!await candidate.exists()) return CodeLaunchSnapshot.empty();
    final file = await project._stateFile('config', 'launch.json');
    if (await file.length() > 131072) {
      throw const FormatException('Launch settings exceed 128 KiB.');
    }
    final bytes = await file.readAsBytes(),
        value = jsonDecode(utf8.decode(bytes));
    if (value is! Map) {
      throw const FormatException(
        'Invalid launch settings; original retained.',
      );
    }
    final snapshot = CodeLaunchSnapshot(
      Map<String, dynamic>.from(value),
      sha256.convert(bytes).toString(),
    );
    snapshot.profiles;
    return snapshot;
  }

  @override
  Future<CodeLaunchSnapshot> save(
    CodeLaunchSnapshot expected,
    Map<String, dynamic> data,
  ) => project._serialize(
    () => project._withProjectSave(() async {
      final proposal = CodeLaunchSnapshot(data, null);
      proposal.profiles;
      final bytes = utf8.encode(jsonEncode(proposal.data));
      if (bytes.length > 131072) {
        throw const FormatException('Launch settings exceed 128 KiB.');
      }
      final state = await project._state(),
          lockFile = File(p.join((await project._state()).path, 'save.lock'));
      if (await lockFile.exists() &&
          await lockFile.resolveSymbolicLinks() !=
              p.join(state.path, 'save.lock')) {
        throw const FormatException('Project lock is a link.');
      }
      final lock = await lockFile.open(mode: FileMode.append);
      try {
        await lock.lock(FileLock.exclusive);
        final current = await load();
        if (current.hash != expected.hash) {
          throw const FormatException(
            'Launch settings changed. Reopen profiles before saving.',
          );
        }
        final checkpoint = await project._stateFile(
          'config-history',
          '${DateTime.now().microsecondsSinceEpoch}-${const Uuid().v4()}.json',
        );
        await project._replace(
          checkpoint,
          utf8.encode(
            jsonEncode({
              'version': 1,
              'before': current.data,
              'after': proposal.data,
            }),
          ),
        );
        if ((await load()).hash != expected.hash) {
          throw const FormatException(
            'Launch settings changed during save; checkpoint retained.',
          );
        }
        await project._replace(
          await project._stateFile('config', 'launch.json'),
          bytes,
        );
        return CodeLaunchSnapshot(
          proposal.data,
          sha256.convert(bytes).toString(),
        );
      } finally {
        try {
          await lock.unlock();
        } on Object {
          /* Lock may not have been acquired. */
        }
        await lock.close();
      }
    }),
  );
  @override
  Future<List<CodeLaunchSnapshot>> history() async {
    final directory = Directory(
      p.join(await project._anchor(), '.orbit-ide', 'config-history'),
    );
    if (!await directory.exists()) return [];
    final safe = await project._stateFile('config-history', '.probe');
    final files = await safe.parent
        .list(followLinks: false)
        .where((e) => e is File && e.path.endsWith('.json'))
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    final result = <CodeLaunchSnapshot>[];
    for (final entry in files.take(20)) {
      try {
        final file = await project._stateFile(
          'config-history',
          p.basename(entry.path),
        );
        if (await file.length() > 1048576) continue;
        final value = jsonDecode(await file.readAsString());
        if (value is! Map || value['version'] != 1 || value['before'] is! Map) {
          continue;
        }
        final before = CodeLaunchSnapshot(
          Map<String, dynamic>.from(value['before'] as Map),
          null,
        );
        before.profiles;
        result.add(before);
      } on Object {
        /* Leave incompatible checkpoints intact. */
      }
    }
    return result;
  }
}

Future<LanguageTransport> startCodeLanguageTool(
  ToolCommand command,
  String root,
) async => _NativeLanguageTransport(await _start(command, root));

class _NativeToolProcess implements CodeToolProcess {
  _NativeToolProcess(this.process) {
    stdout = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(
          controller.add,
          onError: controller.addError,
          onDone: () => outDone.complete(),
        );
    stderr = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(
          controller.add,
          onError: controller.addError,
          onDone: () => errDone.complete(),
        );
    exitCode = process.exitCode.then((code) async {
      exited = true;
      try {
        await Future.wait([
          outDone.future,
          errDone.future,
        ]).timeout(const Duration(seconds: 2));
      } on TimeoutException {
        /* A descendant may have inherited the pipe. */
      }
      await stdout.cancel();
      await stderr.cancel();
      unawaited(controller.close());
      return code;
    });
  }
  final Process process;
  bool exited = false;
  final outDone = Completer<void>(), errDone = Completer<void>();
  final controller = StreamController<String>();
  late final StreamSubscription<String> stdout, stderr;
  @override
  late final Future<int> exitCode;
  @override
  Stream<String> get output => controller.stream;
  @override
  Future<void> writeInput(String text) async {
    if (exited || text.length > 10000) {
      throw const FormatException('Process input is unavailable or too long.');
    }
    process.stdin.writeln(text);
    await process.stdin.flush();
  }

  @override
  Future<void> stop() async {
    if (exited) return;
    if (Platform.isWindows) {
      try {
        await Process.run(
          p.join(
            Platform.environment['SystemRoot'] ?? r'C:\Windows',
            'System32',
            'taskkill.exe',
          ),
          ['/PID', '${process.pid}', '/T', '/F'],
          runInShell: false,
        ).timeout(const Duration(seconds: 5));
      } on Object {
        process.kill();
      }
    } else {
      process.kill();
    }
  }
}

class _NativeLanguageTransport implements LanguageTransport {
  _NativeLanguageTransport(this.process) {
    stderr = process.stderr.listen((_) {});
  }
  final Process process;
  late final StreamSubscription<List<int>> stderr;
  @override
  Stream<List<int>> get output => process.stdout;
  @override
  Future<void> send(List<int> bytes) async {
    process.stdin.add(bytes);
    await process.stdin.flush();
  }

  @override
  Future<void> close() async {
    process.kill();
    await stderr.cancel();
    try {
      await process.stdin.close();
    } on Object {
      /* Already exited. */
    }
  }
}
