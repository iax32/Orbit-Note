import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/source_browser.dart';
import 'package:orbit_note/platform/source_folder.dart';
import 'package:orbit_note/features/workspace/source_browser_dialog.dart';

class FakeSourceFolder extends SourceFolder {
  FakeSourceFolder() : super('Example project');
  Completer<String>? pending;
  @override
  Future<SourceFileListing> list() async => const SourceFileListing([
    SourceFileEntry('src/player.cpp', 'cpp'),
    SourceFileEntry('web/main.js', 'javascript'),
  ]);
  @override
  Future<String> read(String relativePath) async =>
      pending?.future ?? 'int jump() {\r\n  return 42;\r\n}\r\n';
}

void main() {
  testWidgets(
    'capture returns bounded exact provenance and rejects invalid ranges',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SourceExcerpt? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                captured = await showDialog<SourceExcerpt>(
                  context: context,
                  builder: (_) => SourceBrowserDialog(
                    initialFolder: FakeSourceFolder(),
                    capture: true,
                  ),
                );
              },
              child: const Text('Capture'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Capture'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('src/player.cpp'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Last line'), '99');
      await tester.tap(find.text('Use excerpt'));
      await tester.pumpAndSettle();
      expect(captured, isNull);
      expect(
        find.textContaining('Select a valid source line range.'),
        findsOneWidget,
      );
      await tester.enterText(find.widgetWithText(TextField, 'Last line'), '2');
      await tester.tap(find.text('Use excerpt'));
      await tester.pumpAndSettle();
      expect(captured!.repository, 'Example project');
      expect(captured!.path, 'src/player.cpp');
      expect(captured!.start, 1);
      expect(captured!.end, 2);
      expect(captured!.text, 'int jump() {\r\n  return 42;\r\n');
    },
  );

  test('source excerpts retain mixed endings and fence literal backticks', () {
    const source = 'first\r\n😀 second\rthird\n';
    expect(sourceLineExcerpt(source, 2, 3), '😀 second\rthird\n');
    expect(sourceLineExcerpt(source, 4, 4), '');
    expect(() => sourceLineExcerpt(source, 0, 2), throwsFormatException);
    expect(() => sourceLineExcerpt(source, 3, 2), throwsFormatException);
    expect(() => sourceLineExcerpt(source, 1, 5), throwsFormatException);
    expect(
      const SourceExcerpt('repo', 'a.cpp', 1, 1, '```', 'cpp').markdown,
      '````cpp\n```\n````',
    );
  });

  testWidgets(
    'source range keyboard cut copies without deleting and reports failure',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? clipboard;
      bool fail = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            if (fail) throw PlatformException(code: 'unavailable');
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SourceBrowserDialog(initialFolder: FakeSourceFolder()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('src/player.cpp'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('source-line-1')));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.byKey(const ValueKey('source-line-2')));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(
        clipboard,
        sourceLineExcerpt('int jump() {\r\n  return 42;\r\n}\r\n', 1, 2),
      );
      expect(find.byType(SelectableText), findsWidgets);
      await tester.tap(find.text('Copy for note'));
      await tester.pumpAndSettle();
      expect(clipboard, startsWith('```cpp\n'));
      fail = true;
      await tester.tap(find.text('Copy lines'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not copy. Source remains unchanged.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('source languages and search preserve CRLF/Unicode and case policy', () {
    expect(sourceLanguage('src/a.CPP'), 'cpp');
    expect(sourceLanguage('a.js'), 'javascript');
    expect(sourceLanguage('asset.png'), isNull);
    expect(sourceMatchingLines('Jump 😀\r\nJUMP\rjump\n', 'jump'), [0, 1, 2]);
    expect(
      sourceMatchingLines(
        'Jump 😀\r\nJUMP\rjump\n',
        'jump',
        caseSensitive: true,
      ),
      [2],
    );
    expect(sourceMatchingLines('text', ''), isEmpty);
  });

  test(
    'native browser reads exact text, excludes generated folders and rejects unsafe/invalid/oversized files',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-source-');
      try {
        await Directory('${root.path}/src').create();
        await Directory('${root.path}/node_modules').create();
        final source = File('${root.path}/src/player.cpp');
        const text = 'int jump() {\r\n  // 😀\r\n}\r\n';
        await source.writeAsBytes(utf8.encode(text));
        await File(
          '${root.path}/node_modules/hidden.js',
        ).writeAsString('excluded');
        await File('${root.path}/image.png').writeAsBytes([0, 1, 2]);
        final folder = SourceFolder(root.path);
        expect((await folder.list()).files.map((f) => f.path), [
          'src/player.cpp',
        ]);
        expect(await folder.read('src/player.cpp'), text);
        expect(await source.readAsBytes(), utf8.encode(text));
        for (final path in [
          '../other.cpp',
          'src/../player.cpp',
          source.path,
          r'src\player.cpp',
        ]) {
          await expectLater(folder.read(path), throwsFormatException);
        }
        await File('${root.path}/binary.cpp').writeAsBytes([65, 0, 66]);
        await expectLater(folder.read('binary.cpp'), throwsFormatException);
        await File('${root.path}/invalid.cpp').writeAsBytes([255]);
        await expectLater(folder.read('invalid.cpp'), throwsFormatException);
        await File(
          '${root.path}/large.cpp',
        ).writeAsBytes(List.filled(1024 * 1024 + 1, 65));
        await expectLater(folder.read('large.cpp'), throwsFormatException);
        await expectLater(
          folder.read('missing.cpp'),
          throwsA(isA<FileSystemException>()),
        );
      } finally {
        await root.delete(recursive: true);
      }
    },
  );

  testWidgets(
    'source browser shows line numbers, highlighted source, search navigation and file filtering',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final folder = FakeSourceFolder();
      await tester.pumpWidget(
        MaterialApp(home: SourceBrowserDialog(initialFolder: folder)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('src/player.cpp'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('source-line-1')), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      final line = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .first;
      expect(line.textSpan!.toPlainText(), 'int jump() {');
      expect(
        line.textSpan!.children!.any(
          (s) => s is TextSpan && s.style?.color != null,
        ),
        true,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Find in file'),
        'return',
      );
      await tester.pumpAndSettle();
      expect(find.text('0 / 1 matching lines'), findsOneWidget);
      await tester.tap(find.byTooltip('Next matching line'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 1 matching lines'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Filter file paths'),
        'main',
      );
      await tester.pumpAndSettle();
      expect(find.text('1 source files'), findsOneWidget);
      expect(find.text('web/main.js'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'narrow enlarged layout and late read completion after close are safe',
    (tester) async {
      final folder = FakeSourceFolder();
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: SourceBrowserDialog(initialFolder: folder),
          ),
        ),
      );
      await tester.pumpAndSettle();
      folder.pending = Completer<String>();
      await tester.tap(find.text('src/player.cpp'));
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      folder.pending!.complete('Late source');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
