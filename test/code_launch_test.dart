import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/code_launch.dart';
import 'package:orbit_note/domain/code_project.dart';
import 'package:orbit_note/application/code_profile_run.dart';
import 'package:orbit_note/platform/code_launch.dart';
import 'package:orbit_note/platform/code_tools.dart';
import 'package:orbit_note/features/workspace/code_launch_profiles.dart';
import 'package:orbit_note/features/workspace/code_ide_workspace.dart';
import 'code_ide_test.dart' show MemoryCodeProject, MemoryToolProcess;

class NativeHttpOverrides extends HttpOverrides {}

Map<String, dynamic> profile({
  String cwd = '.',
  List<Map<String, dynamic>>? steps,
}) => {
  'id': 'pipeline',
  'name': 'Script pipeline',
  'cwd': cwd,
  'steps':
      steps ??
      [
        {
          'tool': 'python',
          'arguments': ['-u', 'main.py', 'two words; & literal'],
        },
        {'tool': 'program', 'arguments': []},
      ],
};

class MemoryLaunchStore implements CodeLaunchStore {
  CodeLaunchSnapshot snapshot = CodeLaunchSnapshot.empty();
  final past = <CodeLaunchSnapshot>[];
  int revision = 0;
  @override
  Future<CodeLaunchSnapshot> load() async => snapshot;
  @override
  Future<CodeLaunchSnapshot> save(
    CodeLaunchSnapshot expected,
    Map<String, dynamic> data,
  ) async {
    if (expected.hash != snapshot.hash) {
      throw const FormatException('Stale settings');
    }
    final next = CodeLaunchSnapshot(data, '${++revision}');
    next.profiles;
    past.insert(0, snapshot);
    snapshot = next;
    return next;
  }

  @override
  Future<List<CodeLaunchSnapshot>> history() async => past;
}

class MemoryPreview implements CodeWebPreview {
  bool stopped = false;
  int reloads = 0;
  final controller = StreamController<String>.broadcast();
  @override
  Uri get url =>
      Uri.parse('http://127.0.0.1:8231/index.html?orbitPreview=example');
  @override
  Stream<String> get events => controller.stream;
  @override
  void refresh() => reloads++;
  @override
  Future<void> stop() async {
    stopped = true;
    await controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'profiles retain unknown data, literal arguments and validated scoped folders',
    () {
      final raw = {
        'version': 1,
        'futureSetting': {'retained': true},
        'profiles': [profile(cwd: 'src')],
      };
      final snapshot = CodeLaunchSnapshot(raw, 'revision');
      final original = snapshot.profiles.single;
      final changed = CodeRunProfile.parse({
        ...original.data,
        'name': 'Changed',
        'customMetadata': ['preserved'],
      });
      final updated = CodeLaunchSnapshot(snapshot.replacing(changed), 'next');
      expect(updated.data['futureSetting'], {'retained': true});
      expect(updated.profiles.single.data['customMetadata'], ['preserved']);
      final command = changed.steps.first.command(
        {'python': 'python'},
        '/project/output.exe',
        changed.cwd,
      );
      expect(command.workingDirectory, 'src');
      expect(command.arguments.last, 'two words; & literal');
      expect(
        changed.steps.last.command({}, '/project/output.exe', 'src').executable,
        '/project/output.exe',
      );
      for (final cwd in [
        '../other',
        '/absolute',
        r'C:\other',
        '.git',
        'folder/../other',
      ]) {
        expect(
          () => CodeRunProfile.parse(profile(cwd: cwd)),
          throwsFormatException,
        );
      }
      expect(
        () =>
            CodeLaunchSnapshot({'version': 99, 'profiles': []}, null).profiles,
        throwsFormatException,
      );
      expect(
        () => CodeLaunchSnapshot({
          'version': 1,
          'profiles': [profile(), profile()],
        }, null).profiles,
        throwsFormatException,
      );
      expect(
        () => CodeRunProfile.parse(
          profile(
            steps: [
              {'tool': 'custom', 'executable': 5, 'arguments': []},
            ],
          ),
        ),
        throwsFormatException,
      );
    },
  );
  test('sequences stop on failure, cancellation and invalid context', () async {
    final commands = [ToolCommand('first', []), ToolCommand('second', [])];
    final seen = <String>[];
    final failed = await CodeProfileRun().run(
      commands,
      execute: (c) async {
        seen.add(c.executable);
        return 1;
      },
      canContinue: () async => true,
    );
    expect(failed, 1);
    expect(seen, ['first']);
    final runner = CodeProfileRun(), gate = Completer<int>();
    seen.clear();
    final result = runner.run(
      commands,
      execute: (c) {
        seen.add(c.executable);
        return gate.future;
      },
      canContinue: () async => true,
    );
    await Future<void>.delayed(Duration.zero);
    runner.cancel();
    gate.complete(0);
    expect(await result, isNull);
    expect(seen, ['first']);
    seen.clear();
    expect(
      await CodeProfileRun().run(
        commands,
        execute: (c) async {
          seen.add(c.executable);
          return 0;
        },
        canContinue: () async => false,
      ),
      isNull,
    );
    expect(seen, isEmpty);
  });
  test(
    'native launch settings survive restart, preserve metadata and reject stale/future writes',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-launch-');
      try {
        final store = openCodeLaunchStore(root.path),
            initial = await openCodeLaunchStore(root.path).load();
        final first = await store.save(initial, {
          'version': 1,
          'futureRoot': ['kept'],
          'profiles': [
            {...profile(), 'futureProfile': 42},
          ],
        });
        final restored = await openCodeLaunchStore(root.path).load();
        expect(restored.hash, first.hash);
        expect(restored.profiles.single.data['futureProfile'], 42);
        final changed = await store.save(
          restored,
          restored.removing('pipeline'),
        );
        expect(changed.data['futureRoot'], ['kept']);
        await expectLater(store.save(first, first.data), throwsFormatException);
        final past = await store.history();
        expect(past.first.profiles.single.id, 'pipeline');
        await store.save(changed, past.first.data);
        expect((await store.load()).profiles.single.id, 'pipeline');
        final file = File('${root.path}/.orbit-ide/config/launch.json');
        const future = '{"version":99,"profiles":[],"future":true}';
        await file.writeAsString(future);
        await expectLater(store.load(), throwsFormatException);
        await expectLater(
          store.save(changed, changed.data),
          throwsFormatException,
        );
        expect(await file.readAsString(), future);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'concurrent launch writers retain one committed configuration',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'orbit-launch-concurrent-',
      );
      try {
        final a = openCodeLaunchStore(root.path),
            b = openCodeLaunchStore(root.path);
        final expected = await a.load();
        final results = await Future.wait([
          a
              .save(expected, {
                'version': 1,
                'profiles': [profile()],
              })
              .then((_) => true, onError: (Object _) => false),
          b
              .save(expected, {
                'version': 1,
                'profiles': [
                  {...profile(), 'name': 'Other'},
                ],
              })
              .then((_) => true, onError: (Object _) => false),
        ]);
        expect(results.where((ok) => ok), hasLength(1));
        expect((await a.load()).profiles, hasLength(1));
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'two preview servers keep independent browser cookies and authorization',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-preview-pair-');
      CodeWebPreview? first, second;
      final client = HttpOverrides.runWithHttpOverrides(
        () => HttpClient(),
        NativeHttpOverrides(),
      );
      try {
        await File(
          '${root.path}/index.html',
        ).writeAsString('<body>Two independent previews</body>');
        first = await startCodeWebPreview(root.path, 'index.html');
        second = await startCodeWebPreview(root.path, 'index.html');
        final cookies = <Cookie>[];
        for (final server in [first, second]) {
          final response = await (await client.getUrl(server.url)).close();
          await response.drain<void>();
          cookies.addAll(response.cookies);
        }
        expect(cookies.map((c) => c.name).toSet(), hasLength(2));
        for (final server in [first, second]) {
          final request = await client.getUrl(server.url.replace(query: ''));
          request.cookies.addAll(cookies);
          final response = await request.close();
          expect(response.statusCode, 200);
          await response.drain<void>();
        }
      } finally {
        await first?.stop();
        await second?.stop();
        client.close(force: true);
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'failed configuration checkpoint cannot replace current settings',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'orbit-launch-failed-',
      );
      try {
        final store = openCodeLaunchStore(root.path),
            initial = await store.load();
        await Directory('${root.path}/.orbit-ide').create();
        await File(
          '${root.path}/.orbit-ide/config-history',
        ).writeAsString('blocked directory');
        await expectLater(
          store.save(initial, {
            'version': 1,
            'profiles': [profile()],
          }),
          throwsA(isA<FileSystemException>()),
        );
        expect(
          await File('${root.path}/.orbit-ide/config/launch.json').exists(),
          false,
        );
        expect((await store.load()).profiles, isEmpty);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'real static preview serves modules/assets with authorization and reload, then closes',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-web-');
      CodeWebPreview? preview;
      final client = HttpOverrides.runWithHttpOverrides(
        () => HttpClient(),
        NativeHttpOverrides(),
      );
      try {
        const authored =
            '<html><body>Hello<script>const marker = "</body>";</script><script type="module" src="/app.js"></script></body></html>';
        await File('${root.path}/index.html').writeAsString(authored);
        await File(
          '${root.path}/app.js',
        ).writeAsString('export const greeting = "Hello";');
        await File(
          '${root.path}/style.css',
        ).writeAsString('body { color: red; }');
        await File('${root.path}/.secret.json').writeAsString('private');
        await File('${root.path}/main.py').writeAsString('private source');
        preview = await startCodeWebPreview(root.path, 'index.html');
        final address = preview.url;
        Future<({int status, String body, HttpHeaders headers})> get(
          String path, {
          bool auth = true,
          String? host,
          String? origin,
          String method = 'GET',
        }) async {
          final uri = Uri.parse('http://127.0.0.1:${address.port}$path');
          final req = await client.openUrl(method, uri);
          if (auth) {
            req.cookies.add(
              Cookie(
                'orbit_preview_${address.port}',
                address.queryParameters['orbitPreview']!,
              ),
            );
          }
          if (host != null) req.headers.set('Host', host);
          if (origin != null) req.headers.set('Origin', origin);
          final res = await req.close();
          final body = await utf8.decoder.bind(res).join();
          return (status: res.statusCode, body: body, headers: res.headers);
        }

        final initialReq = await client.getUrl(address),
            initial = await initialReq.close();
        final html = await utf8.decoder.bind(initial).join();
        expect(initial.statusCode, 200);
        expect(html, contains('data-orbit-preview'));
        expect(html, startsWith(authored));
        expect(await File('${root.path}/index.html').readAsString(), authored);
        expect(
          initial.headers.value('set-cookie'),
          contains('SameSite=Strict'),
        );
        expect((await get('/app.js')).body, contains('export const greeting'));
        expect(
          (await get('/app.js')).headers.contentType!.mimeType,
          'text/javascript',
        );
        expect((await get('/style.css')).status, 200);
        for (final path in [
          '/.secret.json',
          '/.git/config.json',
          '/%2e%2e/outside.css',
          '/main.py',
          '/folder/',
          '/unknown',
        ]) {
          expect((await get(path)).status, 404, reason: path);
        }
        expect((await get('/app.js', auth: false)).status, 403);
        expect((await get('/app.js', host: 'attacker.test')).status, 403);
        expect(
          (await get('/app.js', origin: 'https://attacker.test')).status,
          403,
        );
        expect((await get('/app.js', method: 'POST')).status, 405);
        expect((await get('/app.js', method: 'HEAD')).body, isEmpty);
        final before = jsonDecode(
          (await get('/__orbit_preview/revision')).body,
        )['revision'];
        preview.refresh();
        expect(
          jsonDecode((await get('/__orbit_preview/revision')).body)['revision'],
          greaterThan(before),
        );
        if (Platform.isWindows) {
          final prior = jsonDecode(
            (await get('/__orbit_preview/revision')).body,
          )['revision'];
          await File(
            '${root.path}/style.css',
          ).writeAsString('body { color: blue; }');
          var after = prior;
          for (var i = 0; i < 20 && after == prior; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            after = jsonDecode(
              (await get('/__orbit_preview/revision')).body,
            )['revision'];
          }
          expect(
            after,
            greaterThan(prior),
            reason: 'Windows source watcher should reload external saves',
          );
        }
        await preview.stop();
        await expectLater(
          Socket.connect(
            address.host,
            address.port,
            timeout: const Duration(seconds: 2),
          ),
          throwsA(isA<SocketException>()),
        );
      } finally {
        await preview?.stop();
        client.close(force: true);
        await root.delete(recursive: true);
      }
    },
  );
  test('preview rejects symlinks escaping the project', () async {
    final root = await Directory.systemTemp.createTemp('orbit-web-link-'),
        outside = await Directory.systemTemp.createTemp('orbit-web-outside-');
    try {
      final secret = File('${outside.path}/outside.html');
      await secret.writeAsString('outside');
      try {
        await Link('${root.path}/escape.html').create(secret.path);
      } on FileSystemException {
        markTestSkipped('Native symlink creation requires OS permission.');
        return;
      }
      await expectLater(
        startCodeWebPreview(root.path, 'escape.html'),
        throwsFormatException,
      );
    } finally {
      await root.delete(recursive: true);
      await outside.delete(recursive: true);
    }
  });
  final interpreter = Platform.environment['ORBIT_IDE_TEST_PYTHON'];
  test(
    'native profile command uses a scoped working folder and literal arguments',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'orbit-launch-process-',
      );
      try {
        await Directory('${root.path}/src').create();
        await File('${root.path}/src/main.py').writeAsString(
          'import pathlib,sys\nprint(pathlib.Path.cwd().name)\nprint(sys.argv[1])',
        );
        final step = CodeRunStep.parse({
          'tool': 'python',
          'arguments': ['-u', 'main.py', 'two words; & literal'],
        });
        final process = await startCodeTool(
          step.command({'python': interpreter!}, '', 'src'),
          root.path,
        );
        final output = StringBuffer(),
            sub = process.output.listen(output.write);
        expect(await process.exitCode, 0);
        await sub.cancel();
        expect(output.toString(), contains('src'));
        expect(output.toString(), contains('two words; & literal'));
        await expectLater(
          startCodeTool(
            ToolCommand(interpreter, [], workingDirectory: '../'),
            root.path,
          ),
          throwsFormatException,
        );
      } finally {
        await root.delete(recursive: true);
      }
    },
    skip: interpreter == null
        ? 'Configure native Python for acceptance.'
        : false,
  );

  for (final size in [const Size(360, 640), const Size(640, 360)]) {
    testWidgets(
      'profile editor saves literal arguments at 200% text on $size',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final store = MemoryLaunchStore();
        await tester.pumpWidget(
          MaterialApp(
            builder: (_, child) => MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(2),
              ),
              child: child!,
            ),
            home: CodeLaunchProfiles(store: store),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Add Python'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add Python'));
        await tester.pumpAndSettle();
        final name = find.widgetWithText(TextField, 'Profile name');
        await tester.ensureVisible(name);
        await tester.enterText(name, 'Daily script');
        final args = find.widgetWithText(TextField, 'Arguments as JSON array');
        await tester.ensureVisible(args);
        await tester.enterText(args, '["-u", "main.py", "two words"]');
        await tester.ensureVisible(find.text('Save profile'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save profile'));
        await tester.pumpAndSettle();
        expect(store.snapshot.profiles.single.name, 'Daily script');
        expect(
          store.snapshot.profiles.single.steps.single.arguments.last,
          'two words',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'web preview starts explicitly and saves refresh it; stopping removes controls',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final preview = MemoryPreview(), store = MemoryLaunchStore();
      var opens = 0, starts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CodeIdeWorkspace(
            initialProject: MemoryCodeProject(),
            launchStoreFactory: (_) => store,
            previewStarter: (_, _) async {
              starts++;
              return preview;
            },
            previewOpener: (_) async {
              opens++;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(starts, 0);
      expect(opens, 0);
      await tester.tap(find.text('index.html'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start web preview'));
      await tester.pumpAndSettle();
      expect(starts, 1);
      expect(opens, 1);
      await tester.enterText(
        find.byKey(const ValueKey('ide-editor')),
        '<h1>Changed</h1>',
      );
      await tester.tap(find.text('Save · Ctrl+S'));
      await tester.pumpAndSettle();
      expect(preview.reloads, 1);
      await tester.ensureVisible(find.text('Stop preview'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop preview'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
      expect(preview.stopped, true);
      expect(find.text('Stop preview'), findsNothing);
    },
  );
  testWidgets(
    'cancel during pending profile startup stops its process and never starts the next step',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = MemoryLaunchStore();
      await store.save(store.snapshot, {
        'version': 1,
        'profiles': [profile()],
      });
      final gate = Completer<CodeToolProcess>(), process = MemoryToolProcess();
      var starts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CodeIdeWorkspace(
            initialProject: MemoryCodeProject(),
            launchStoreFactory: (_) => store,
            toolStarter: (_, _) {
              starts++;
              return gate.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Script pipeline').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Run profile'));
      await tester.pumpAndSettle();
      expect(starts, 1);
      await tester.ensureVisible(find.text('Stop'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop'));
      await tester.pump();
      gate.complete(process);
      await tester.pumpAndSettle();
      expect(process.stopped, true);
      expect(starts, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
