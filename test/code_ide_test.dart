import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/application/code_language_client.dart';
import 'package:orbit_note/application/code_project_session.dart';
import 'package:orbit_note/domain/code_language.dart';
import 'package:orbit_note/domain/code_launch.dart';
import 'package:orbit_note/domain/code_project.dart';
import 'package:orbit_note/domain/source_browser.dart';
import 'package:orbit_note/features/workspace/code_ide_workspace.dart';
import 'package:orbit_note/platform/code_tools.dart';
import 'package:orbit_note/platform/code_tool_settings.dart';
import 'package:orbit_note/features/notes/rich/code_editing.dart';

String hash(String value) => sha256.convert(utf8.encode(value)).toString();

class MemoryCodeProject implements CodeProject {
  final sources = <String, String>{
    'main.py': 'print("hello")\n',
    'index.html': '<h1>Hello</h1>',
    'main.cpp': 'int main() { return 0; }',
  };
  final drafts = <String, CodeRecoveredDraft>{};
  final checkpoints = <CodeHistoryEntry>[];
  bool fail = false;
  Completer<void>? saveGate;
  @override
  String get root => Directory.systemTemp.path;
  @override
  Uri get rootUri => Uri.directory(root);
  @override
  bool get supported => true;
  @override
  Future<SourceFileListing> list() async => SourceFileListing([
    for (final p in sources.keys) SourceFileEntry(p, sourceLanguage(p)!),
  ]);
  @override
  Future<CodeSnapshot> read(String path) async =>
      CodeSnapshot(path, sources[path]!, hash(sources[path]!));
  @override
  Future<CodeSnapshot> save(CodeSnapshot expected, String text) async {
    await saveGate?.future;
    if (fail) throw StateError('Disk unavailable');
    final existing = sources[expected.path];
    if ((existing == null ? null : hash(existing)) != expected.hash) {
      throw const FormatException('External edit');
    }
    sources[expected.path] = text;
    checkpoints.add(
      CodeHistoryEntry(
        '${checkpoints.length}',
        expected.path,
        existing ?? '',
        text,
        'today',
      ),
    );
    return CodeSnapshot(expected.path, text, hash(text));
  }

  @override
  Future<void> writeDraft(CodeSnapshot base, String text) async {
    if (fail) throw StateError('Draft unavailable');
    drafts[base.path] = CodeRecoveredDraft(base.path, base.hash, text);
  }

  @override
  Future<CodeRecoveredDraft?> recoverDraft(String path) async => drafts[path];
  @override
  Future<void> clearDraft(String path) async {
    drafts.remove(path);
  }

  @override
  Future<List<CodeHistoryEntry>> history(String path) async =>
      checkpoints.where((e) => e.path == path).toList();
  @override
  Future<void> createDirectory(String path) async {}
  @override
  Future<Uri> buildOutput(String path) async => rootUri.resolve('program.exe');
  @override
  Uri fileUri(String path) => rootUri.resolveUri(Uri(path: path));
  @override
  String? relativePath(Uri uri) => uri.toString().startsWith(rootUri.toString())
      ? uri.pathSegments.last
      : null;
}

List<int> packet(Map<String, dynamic> value) {
  final bytes = utf8.encode(jsonEncode({'jsonrpc': '2.0', ...value}));
  return [...ascii.encode('Content-Length: ${bytes.length}\r\n\r\n'), ...bytes];
}

class MemoryLanguageTransport implements LanguageTransport {
  final messages = <Map<String, dynamic>>[];
  final controller = StreamController<List<int>>();
  final frames = LanguageFrames();
  dynamic completion;
  bool closed = false;
  final replies = <String, dynamic>{};
  @override
  Stream<List<int>> get output => controller.stream;
  void reply(Map<String, dynamic> value) => controller.add(packet(value));
  @override
  Future<void> send(List<int> bytes) async {
    for (final request in frames.add(bytes)) {
      messages.add(request);
      if (request['method'] != null && request['id'] != null) {
        final method = request['method'];
        reply({
          'id': request['id'],
          'result': method == 'initialize'
              ? {
                  'capabilities': {
                    'textDocumentSync': 2,
                    'positionEncoding': 'utf-16',
                  },
                }
              : method == 'textDocument/completion'
              ? completion
              : replies[method],
        });
      }
    }
  }

  @override
  Future<void> close() async {
    closed = true;
    await controller.close();
  }
}

class SilentLanguageTransport extends MemoryLanguageTransport {
  @override
  Future<void> send(List<int> bytes) async {
    messages.addAll(frames.add(bytes));
  }
}

class EmptyLaunchStore implements CodeLaunchStore {
  @override
  Future<CodeLaunchSnapshot> load() async => CodeLaunchSnapshot.empty();
  @override
  Future<CodeLaunchSnapshot> save(
    CodeLaunchSnapshot expected,
    Map<String, dynamic> data,
  ) async => CodeLaunchSnapshot(data, 'saved');
  @override
  Future<List<CodeLaunchSnapshot>> history() async => [];
}

class MemoryToolProcess implements CodeToolProcess {
  final controller = StreamController<String>();
  final done = Completer<int>();
  String? input;
  bool stopped = false;
  @override
  Stream<String> get output => controller.stream;
  @override
  Future<int> get exitCode => done.future;
  @override
  Future<void> writeInput(String text) async {
    input = text;
  }

  @override
  Future<void> stop() async {
    stopped = true;
    if (!done.isCompleted) done.complete(1);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'UTF-16 positions and nonoverlapping edits preserve mixed endings and emoji',
    () {
      const text = '😀 name\r\nsecond\rthird\n';
      expect(codeOffset(text, const CodePosition(0, 3)), 3);
      expect(codePosition(text, 10).line, 1);
      expect(
        () => codeOffset(text, const CodePosition(0, 1)),
        throwsFormatException,
      );
      expect(
        () => codeOffset(text, const CodePosition(9, 0)),
        throwsFormatException,
      );
      final edit = CodeTextEdit.parse(text, {
        'range': {
          'start': {'line': 0, 'character': 3},
          'end': {'line': 0, 'character': 7},
        },
        'newText': 'value',
      });
      expect(applyCodeEdits(text, [edit]), '😀 value\r\nsecond\rthird\n');
      expect(
        () => applyCodeEdits(text, [
          const CodeTextEdit(0, 4, ''),
          const CodeTextEdit(3, 6, ''),
        ]),
        throwsFormatException,
      );
    },
  );
  test(
    'offline language snippets avoid duplicate HTML/C++ prefixes and preserve indentation',
    () {
      final html = offlineCodeSuggestions('<di', 3, 'html').first;
      expect(applyCodeEdits('<di', html.edits), '<div>\n  \n</div>');
      final cpp = offlineCodeSuggestions('#inc', 4, 'cpp').first;
      expect(applyCodeEdits('#inc', cpp.edits), '#include <>');
      final python = offlineCodeSuggestions('    de', 6, 'python').first;
      expect(
        applyCodeEdits('    de', python.edits),
        '    def function_name():\n        pass',
      );
      final newline = newlineCode(
        const TextEditingValue(
          text: 'if x:',
          selection: TextSelection.collapsed(offset: 5),
        ),
        unit: '    ',
        language: 'python',
      );
      expect(newline.text, 'if x:\n    ');
    },
  );
  test(
    'language framing handles split UTF-8 packets and rejects invalid or huge headers',
    () {
      final frame = packet({'id': 1, 'result': '😀 Zürich'}),
          parser = LanguageFrames();
      final result = <Map<String, dynamic>>[];
      for (final byte in frame) {
        result.addAll(parser.add([byte]));
      }
      expect(result.single['result'], '😀 Zürich');
      expect(
        () => LanguageFrames().add(
          ascii.encode('Content-Length: 99999999\r\n\r\n'),
        ),
        throwsFormatException,
      );
      expect(
        () => LanguageFrames().add(
          ascii.encode('Content-Length: 1\r\nContent-Length: 1\r\n\r\n0'),
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'LSP full and incremental updates are versioned; stale diagnostics are dropped',
    () async {
      final transport = MemoryLanguageTransport(),
          client = CodeLanguageClient(MemoryLanguageTransport());
      await client
          .close(); // A server is optional; close works before initialization.
      final language = CodeLanguageClient(transport),
          events = <({Uri uri, List<CodeProblem> problems})>[];
      final subscription = language.problems.stream.listen(events.add);
      final uri = Uri.parse('file:///project/main.py');
      await language.initialize(Uri.parse('file:///project/'));
      await language.update(uri, 'python', '😀 name\r\n', 1);
      await language.update(uri, 'python', '😀 value\r\n', 2);
      final change = transport.messages.firstWhere(
        (m) => m['method'] == 'textDocument/didChange',
      );
      expect(change['params']['textDocument']['version'], 2);
      expect(change['params']['contentChanges'][0]['range']['end'], {
        'line': 1,
        'character': 0,
      });
      for (final version in [1, 2]) {
        transport.reply({
          'method': 'textDocument/publishDiagnostics',
          'params': {
            'uri': uri.toString(),
            'version': version,
            'diagnostics': [
              {
                'range': {
                  'start': {'line': 0, 'character': 3},
                },
                'message': 'Unknown name',
                'severity': 1,
              },
            ],
          },
        });
      }
      await Future<void>.delayed(Duration.zero);
      expect(events.length, 1);
      expect(events.single.problems.single.version, 2);
      await subscription.cancel();
      await language.close();
      expect(transport.closed, true);
    },
  );
  test(
    'language completion edits and unsolicited server mutations are guarded',
    () async {
      final transport = MemoryLanguageTransport();
      transport.completion = [
        {
          'label': 'value',
          'textEdit': {
            'range': {
              'start': {'line': 0, 'character': 0},
              'end': {'line': 0, 'character': 2},
            },
            'newText': 'value',
          },
        },
        {
          'label': 'bad',
          'textEdit': {
            'range': {
              'start': {'line': 99, 'character': 0},
              'end': {'line': 99, 'character': 1},
            },
            'newText': 'bad',
          },
        },
        {'label': 'snippet', 'insertTextFormat': 2},
      ];
      final client = CodeLanguageClient(transport),
          uri = Uri.parse('file:///project/main.cpp');
      await client.initialize(Uri.parse('file:///project/'));
      await client.update(uri, 'cpp', 'va', 1);
      final choices = await client.complete(uri, 'va', 2);
      expect(choices.map((c) => c.label), ['value']);
      expect(applyCodeEdits('va', choices.single.edits), 'value');
      transport.reply({
        'id': 500,
        'method': 'workspace/applyEdit',
        'params': {
          'edit': {'changes': {}},
        },
      });
      await Future<void>.delayed(Duration.zero);
      expect(transport.messages.last['error']['code'], -32601);
      await client.close();
    },
  );
  test(
    'document save retains edits arriving during save and survives session recreation',
    () async {
      final project = MemoryCodeProject();
      final editing = CodeProjectSession(project),
          doc = await editing.open('main.py');
      doc.edit('print("one")\n');
      project.saveGate = Completer<void>();
      final saving = editing.save(doc);
      doc.edit('print("two")\n');
      project.saveGate!.complete();
      await saving;
      expect(project.sources['main.py'], 'print("one")\n');
      expect(doc.modified, true);
      expect(project.drafts['main.py']!.text, 'print("two")\n');
      await editing.dispose();
      final restored = await CodeProjectSession(project).open('main.py');
      expect(restored.text, 'print("two")\n');
      expect(restored.conflict, false);
    },
  );
  test(
    'external edits and failed draft writes retain both sides and block unsafe closing',
    () async {
      final project = MemoryCodeProject(),
          session = CodeProjectSession(project);
      final doc = await session.open('main.py');
      doc.edit('user draft');
      project.sources['main.py'] = 'external edit';
      await expectLater(session.save(doc), throwsFormatException);
      expect(project.sources['main.py'], 'external edit');
      expect(project.drafts['main.py']!.text, 'user draft');
      final restored = await CodeProjectSession(project).open('main.py');
      expect(restored.conflict, true);
      project.fail = true;
      await expectLater(session.dispose(), throwsStateError);
      expect(session.disposed, false);
      expect(doc.text, 'user draft');
    },
  );
  test(
    'native files preserve exact bytes, recovery, history, conflict and creation boundaries',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-ide-');
      try {
        final file = File('${root.path}/main.py');
        const original = '\uFEFFprint("😀")\r\n';
        await file.writeAsBytes(utf8.encode(original));
        final project = openCodeProject(root.path),
            before = await project.read('main.py');
        expect(before.text, original.substring(1));
        expect(before.hasBom, true);
        expect((await project.list()).files.map((f) => f.path), ['main.py']);
        await project.writeDraft(before, 'print("draft")\r\n');
        expect(
          (await openCodeProject(root.path).recoverDraft('main.py'))!.text,
          'print("draft")\r\n',
        );
        final saved = await project.save(before, 'print("saved")\r\n');
        expect(await file.readAsBytes(), utf8.encode('\uFEFF${saved.text}'));
        expect(
          (await project.history('main.py')).single.before,
          original.substring(1),
        );
        await expectLater(project.save(before, 'stale'), throwsFormatException);
        expect(await file.readAsString(), saved.text);
        await project.createDirectory('web');
        await project.save(
          const CodeSnapshot('web/index.html', '', null),
          '<h1>New</h1>',
        );
        for (final path in [
          '../a.py',
          '/a.py',
          'C:/a.py',
          '.git/a.py',
          '.orbit-ide/a.py',
        ]) {
          await expectLater(project.read(path), throwsFormatException);
        }
        await expectLater(
          project.save(const CodeSnapshot('main.py', '', null), 'overwrite'),
          throwsFormatException,
        );
        expect(
          (await project.list()).files.any(
            (f) => f.path.startsWith('.orbit-ide'),
          ),
          false,
        );
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'separate native sessions never overwrite or clear each other’s recovery draft',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-ide-sessions-');
      try {
        await File('${root.path}/a.py').writeAsString('original');
        final a = openCodeProject(root.path), b = openCodeProject(root.path);
        await a.writeDraft(await a.read('a.py'), 'draft A');
        await b.writeDraft(await b.read('a.py'), 'draft B');
        await a.clearDraft('a.py');
        expect(
          (await openCodeProject(root.path).recoverDraft('a.py'))!.text,
          'draft B',
        );
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'concurrent project sessions serialize saves and reject the stale writer',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'orbit-code-concurrent-',
      );
      try {
        await File('${root.path}/a.py').writeAsString('initial');
        final a = openCodeProject(root.path), b = openCodeProject(root.path);
        final left = await a.read('a.py'), right = await b.read('a.py');
        final results = await Future.wait([
          a.save(left, 'left').then((_) => true, onError: (Object _) => false),
          b
              .save(right, 'right')
              .then((_) => true, onError: (Object _) => false),
        ]);
        expect(results.where((v) => v), hasLength(1));
        expect(
          await File('${root.path}/a.py').readAsString(),
          anyOf('left', 'right'),
        );
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'device tool preferences preserve unknown data and reject future versions',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'orbit-code-settings-',
      );
      try {
        final location = '${root.path}/settings.json';
        await File(location).writeAsString(
          jsonEncode({
            'version': 1,
            'unknown': true,
            'servers': {
              'rust': {'executable': 'rust-analyzer'},
              'python': {'custom': 'retain'},
            },
          }),
        );
        await saveCodeToolSettings({
          'python': 'python',
          'compiler': 'clang++',
          'debugger': 'gdb',
          'debuggerArguments': '["--args","{program}"]',
          'servers': {
            'python': {
              'executable': 'python',
              'arguments': ['-I', '-m', 'pylsp'],
            },
          },
        }, location: location);
        final restored = await loadCodeToolSettings(location);
        expect(restored['unknown'], true);
        expect(restored['servers']['python']['custom'], 'retain');
        expect(restored['servers']['rust']['executable'], 'rust-analyzer');
        await File(location).writeAsString('{"version":999,"opaque":"retain"}');
        await expectLater(
          saveCodeToolSettings({'servers': {}}, location: location),
          throwsFormatException,
        );
        expect(
          await File(location).readAsString(),
          '{"version":999,"opaque":"retain"}',
        );
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'language disconnection rejects pending requests without waiting for timeout',
    () async {
      final transport = SilentLanguageTransport();
      final active = CodeLanguageClient(transport);
      final pending = active.initialize(Uri.directory('/project/'));
      final rejected = expectLater(pending, throwsFormatException);
      await Future<void>.delayed(Duration.zero);
      await transport.controller.close();
      await rejected;
      await expectLater(
        active.request('textDocument/hover', {}),
        throwsFormatException,
      );
      await active.close();
    },
  );
  test('future recovery data remains intact and source still opens', () async {
    final root = await Directory.systemTemp.createTemp('orbit-ide-future-');
    try {
      await File('${root.path}/main.py').writeAsString('original');
      final project = openCodeProject(root.path),
          base = await openCodeProject(root.path).read('main.py');
      await project.writeDraft(base, 'recovered');
      final file = (await Directory(
        '${root.path}/.orbit-ide/drafts',
      ).list().toList()).whereType<File>().single;
      final value =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      value['version'] = 999;
      final bytes = jsonEncode(value);
      await file.writeAsString(bytes);
      final session = CodeProjectSession(openCodeProject(root.path));
      final doc = await session.open('main.py');
      expect(doc.text, 'original');
      expect(doc.draftError, isNotNull);
      await session.dispose();
      expect(await file.readAsString(), bytes);
      expect(await File('${root.path}/main.py').readAsString(), 'original');
    } finally {
      await root.delete(recursive: true);
    }
  });
  test('tab limit refuses another file without changing open drafts', () async {
    final project = MemoryCodeProject();
    for (var i = 0; i < 21; i++) {
      project.sources['file$i.py'] = 'source$i';
    }
    final active = CodeProjectSession(project);
    for (var i = 0; i < 20; i++) {
      await active.open('file$i.py');
    }
    active.documents['file0.py']!.edit('unsaved');
    await expectLater(active.open('file20.py'), throwsFormatException);
    await active.dispose();
    expect(project.drafts['file0.py']!.text, 'unsaved');
  });
  final pythonPath = Platform.environment['ORBIT_IDE_TEST_PYTHON'];
  test(
    'real Python process receives literal stdin and complete bounded output',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-ide-python-');
      try {
        final tool = await startCodeTool(
          ToolCommand(pythonPath!, [
            '-u',
            '-c',
            'print("ready"); print(input()); print("done")',
          ]),
          root.path,
        );
        final output = StringBuffer();
        final subscription = tool.output.listen(output.write);
        await tool.writeInput('😀 literal ; & input');
        expect(await tool.exitCode.timeout(const Duration(seconds: 15)), 0);
        await subscription.cancel();
        expect(output.toString(), contains('literal ; & input'));
        expect(output.toString(), contains('done'));
      } finally {
        await root.delete(recursive: true);
      }
    },
    skip: pythonPath == null
        ? 'Set ORBIT_IDE_TEST_PYTHON to an installed interpreter for native acceptance.'
        : false,
  );
  test(
    'native stop terminates only the owned temporary Python process',
    () async {
      final process = await startCodeTool(
        ToolCommand(pythonPath!, [
          '-u',
          '-c',
          'import time;print("ready",flush=True);time.sleep(60)',
        ]),
        Directory.systemTemp.path,
      );
      final ready = Completer<void>();
      final subscription = process.output.listen((text) {
        if (text.contains('ready') && !ready.isCompleted) ready.complete();
      });
      try {
        await ready.future.timeout(const Duration(seconds: 10));
        await process.stop();
        expect(
          await process.exitCode.timeout(const Duration(seconds: 10)),
          isNot(0),
        );
      } finally {
        await process.stop();
        await subscription.cancel();
      }
    },
    skip: pythonPath == null ? 'No native Python configured.' : false,
  );
  test(
    'real installed C++ toolchain compiles a temporary project without shell commands',
    () async {
      final tools = await defaultCodeToolPaths(),
          executable = tools['compiler'];
      if (executable == null) {
        markTestSkipped('No installed C++ compiler for native acceptance.');
        return;
      }
      final root = await Directory.systemTemp.createTemp('orbit-ide-cpp-');
      try {
        final source = File('${root.path}/main.cpp');
        await source.writeAsString(
          '#include <iostream>\nint main() { std::cout << "native C++ OK"; }\n',
        );
        final project = openCodeProject(root.path),
            output = (await project.buildOutput('main.cpp')).toFilePath();
        final msvc = executable.toLowerCase().endsWith('cl.exe');
        final compile = await startCodeTool(
          ToolCommand(
            executable,
            msvc
                ? [
                    '/nologo',
                    '/EHsc',
                    source.path,
                    '/Fe:$output',
                    '/Fo:$output.obj',
                  ]
                : [source.path, '-o', output],
          ),
          root.path,
        );
        final log = StringBuffer(),
            subscription = compile.output.listen(log.write);
        expect(
          await compile.exitCode.timeout(const Duration(seconds: 45)),
          0,
          reason: log.toString(),
        );
        await subscription.cancel();
        final run = await startCodeTool(ToolCommand(output, []), root.path),
            text = StringBuffer();
        final result = run.output.listen(text.write);
        expect(await run.exitCode.timeout(const Duration(seconds: 15)), 0);
        await result.cancel();
        expect(text.toString(), 'native C++ OK');
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
  testWidgets(
    'IDE does not execute on open and saves tabs through validated commands',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1300, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final project = MemoryCodeProject(), commands = <ToolCommand>[];
      await tester.pumpWidget(
        MaterialApp(
          home: CodeIdeWorkspace(
            launchStoreFactory: (_) => EmptyLaunchStore(),
            initialProject: project,
            toolStarter: (c, _) async {
              commands.add(c);
              return MemoryToolProcess();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(commands, isEmpty);
      await tester.tap(find.text('main.py'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('ide-editor')),
        'print("edited")\n',
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(project.sources['main.py'], 'print("hello")\n');
      expect(project.drafts['main.py']!.text, 'print("edited")\n');
      await tester.tap(find.text('Save · Ctrl+S'));
      await tester.pumpAndSettle();
      expect(project.sources['main.py'], 'print("edited")\n');
      await tester.tap(find.text('index.html'));
      await tester.pumpAndSettle();
      expect(find.textContaining('main.py'), findsWidgets);
      expect(commands, isEmpty);
    },
  );
  testWidgets(
    'offline completion remains undoable and Python colon Enter indents',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1300, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final project = MemoryCodeProject();
      await tester.pumpWidget(
        MaterialApp(
          home: CodeIdeWorkspace(
            launchStoreFactory: (_) => EmptyLaunchStore(),
            initialProject: project,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('main.py'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('ide-editor')), 'de');
      await tester.ensureVisible(find.text('Code actions'));
      await tester.tap(find.text('Code actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Complete · Ctrl+Space'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('def'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('ide-editor')),
      );
      expect(field.controller!.text, 'def function_name():\n    pass');
      await tester.tap(find.byKey(const ValueKey('ide-editor')));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(field.controller!.text, 'de');
    },
  );
  testWidgets(
    'run is explicit, dirty files are blocked and debugger uses argument arrays',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1300, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final project = MemoryCodeProject(), commands = <ToolCommand>[];
      final processes = <MemoryToolProcess>[];
      await tester.pumpWidget(
        MaterialApp(
          home: CodeIdeWorkspace(
            launchStoreFactory: (_) => EmptyLaunchStore(),
            initialProject: project,
            toolStarter: (command, _) async {
              commands.add(command);
              final process = MemoryToolProcess();
              processes.add(process);
              return process;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('main.py'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('ide-editor')),
        'changed',
      );
      await tester.ensureVisible(find.text('Run Python'));
      await tester.tap(find.text('Run Python'));
      await tester.pumpAndSettle();
      expect(commands, isEmpty);
      expect(find.textContaining('Save this source'), findsOneWidget);
      await tester.ensureVisible(find.text('Save · Ctrl+S'));
      await tester.tap(find.text('Save · Ctrl+S'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Code actions'));
      await tester.tap(find.text('Code actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Debug in console · F5'));
      await tester.pumpAndSettle();
      expect(
        commands.single.arguments,
        containsAllInOrder(['-u', '-m', 'pdb']),
      );
      expect(
        commands.single.arguments.last,
        project.fileUri('main.py').toFilePath(),
      );
      processes.single.done.complete(0);
      await tester.pumpAndSettle();
    },
  );
  for (final size in [const Size(360, 640), const Size(640, 360)]) {
    testWidgets('IDE layout retains editing at 200% text on $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final process = MemoryToolProcess();
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => MediaQuery(
            data: MediaQueryData(size: size, textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: CodeIdeWorkspace(
            launchStoreFactory: (_) => EmptyLaunchStore(),
            initialProject: MemoryCodeProject(),
            toolStarter: (_, _) async => process,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('main.py'));
      await tester.tap(find.text('main.py'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ide-editor')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Run Python'));
      await tester.tap(find.text('Run Python'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Show output'));
      await tester.tap(find.text('Show output'));
      await tester.pumpAndSettle();
      process.controller.add('Live console output');
      await tester.pumpAndSettle();
      expect(find.textContaining('Live console output'), findsOneWidget);
      final input = find.widgetWithText(
        TextField,
        'Process input · Enter to send',
      );
      await tester.ensureVisible(input);
      await tester.enterText(input, 'hello');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(process.input, 'hello');
      await tester.ensureVisible(find.text('Stop'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();
      expect(process.stopped, isTrue);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Process exited with code'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
