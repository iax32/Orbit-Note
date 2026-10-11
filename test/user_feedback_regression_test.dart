import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/domain/grammar/spell_grammar_engine.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/notes/creative_brief_dialog.dart';
import 'package:orbit_note/features/notes/note_templates.dart';
import 'package:orbit_note/features/notes/rich/code_editing.dart';
import 'package:orbit_note/features/notes/rich/code_workspace.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';

void main() {
  testWidgets('creative and code dialogs fit narrow enlarged-text layouts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final dialog in <Widget>[
      const CreativeBriefDialog(),
      CodeWorkspace(
        code: 'let value = 1;',
        language: 'javascript',
        canApply: () => true,
      ),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Scaffold(body: dialog),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
  test(
    'recent Vaults prune missing folders and preserve preference extensions on restart',
    () async {
      final root = await Directory.systemTemp.createTemp('orbit-recent-test-');
      try {
        final existing = await Directory('${root.path}/existing').create();
        final missing = '${root.path}/deleted';
        final pointer = File('${root.path}/selection.json');
        await pointer.writeAsString(
          jsonEncode({
            'version': 1,
            'path': missing,
            'recent': [missing, existing.path],
            'extension': {'keep': true},
          }),
        );
        final store = NativeWorkspaceStore(
          rememberWorkspace: true,
          selectionFilePath: pointer.path,
        );
        expect(await store.recentLocations(), [existing.path]);
        final saved = jsonDecode(await pointer.readAsString()) as Map;
        expect(saved['path'], isNull);
        expect(saved['extension'], {'keep': true});
        final reopened = NativeWorkspaceStore(
          rememberWorkspace: true,
          selectionFilePath: pointer.path,
        );
        expect(await reopened.recentLocations(), [existing.path]);
        await expectLater(reopened.initialize(), throwsA(anything));
        expect(await Directory(missing).exists(), isFalse);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );

  test('writing width has a wider default and retains existing choices', () {
    expect(SessionState().contentWidth, 1080);
    expect(SessionState.fromJson({'contentWidth': 800}).contentWidth, 800);
    expect(SessionState.fromJson({'contentWidth': 2000}).contentWidth, 2000);
  });

  test('grammar finds repeated words at either word-pair alignment', () {
    final engine = EnglishSpellGrammarEngine();
    for (final text in [
      'This is the the best idea.',
      'This is the best best idea.',
    ]) {
      expect(
        engine.analyze(text).where((i) => i.message.startsWith('Repeated')),
        hasLength(1),
      );
    }
    expect(
      engine
          .analyze('the\n\nthe')
          .where((i) => i.message.startsWith('Repeated')),
      isEmpty,
    );
  });
  test(
    'grammar excludes long/tilde/unclosed fences, code runs and identifiers',
    () {
      final engine = EnglishSpellGrammarEngine();
      for (final text in [
        '~~~cpp\nteh recieve\n~~~',
        '````js\nteh recieve\n````',
        '~~~js\nteh recieve',
        '``teh ` recieve``',
        'render_context updateLoop Vulkan',
      ]) {
        expect(engine.analyze(text), isEmpty, reason: text);
      }
      expect(engine.analyze('teh'), isNotEmpty);
      expect(engine.analyze('blorbquux'), isEmpty);
    },
  );
  test(
    'code indentation retains reversed selections and excludes trailing line',
    () {
      const input = TextEditingValue(
        text: 'one\ntwo\nthree',
        selection: TextSelection(baseOffset: 8, extentOffset: 0),
      );
      final indented = indentCode(input);
      expect(indented.text, '  one\n  two\nthree');
      expect(indented.selection.baseOffset, 12);
      expect(indented.selection.extentOffset, 2);
      final restored = indentCode(indented, outdent: true);
      expect(restored.text, input.text);
      expect(restored.selection, input.selection);
      expect(
        indentCode(
          const TextEditingValue(
            text: '',
            selection: TextSelection.collapsed(offset: 0),
          ),
        ).text,
        '  ',
      );
    },
  );

  testWidgets('emptying a template board stays empty after reopening', (
    tester,
  ) async {
    Map<String, dynamic> data = {
      'schemaVersion': 1,
      'elements': [],
      'canvasPreset': 'game_roadmap',
    };
    Widget board(String key) => MaterialApp(
      theme: orbitDarkTheme(),
      home: Scaffold(
        body: CanvasEditor(
          key: ValueKey(key),
          canvasId: 'board',
          data: data,
          objects: const [],
          onOpenObject: (_) {},
          onChanged: (value) => data = value,
        ),
      ),
    );
    await tester.pumpWidget(board('first'));
    await tester.pumpAndSettle();
    expect(data['elements'], isNotEmpty);
    await tester.tapAt(const Offset(400, 500));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(data['elements'], isEmpty);
    expect(data['canvasPresetApplied'], isTrue);
    await tester.pumpWidget(board('reopened'));
    await tester.pumpAndSettle();
    expect(data['elements'], isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded code search, apply and stale-source protection', (
    tester,
  ) async {
    bool current = true;
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: orbitDarkTheme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<String>(
                context: context,
                builder: (_) => CodeWorkspace(
                  code: 'let value = 1;',
                  language: 'javascript',
                  canApply: () => current,
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('code-workspace-editor')),
      'let value = 2;',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Find in code'),
      'value',
    );
    await tester.tap(find.text('Next match'));
    await tester.pump();
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('code-workspace-editor')),
    );
    expect(
      field.controller!.selection,
      const TextSelection(baseOffset: 4, extentOffset: 9),
    );
    current = false;
    await tester.tap(find.text('Apply to note'));
    await tester.pump();
    expect(result, isNull);
    expect(find.textContaining('The source changed.'), findsOneWidget);
    current = true;
    await tester.tap(find.text('Apply to note'));
    await tester.pumpAndSettle();
    expect(result, 'let value = 2;');
  });

  testWidgets('creative brief captures project details as portable Markdown', (
    tester,
  ) async {
    NoteTemplate? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<NoteTemplate>(
                context: context,
                builder: (_) => const CreativeBriefDialog(),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('brief-Project name')),
      'Forest prototype',
    );
    await tester.enterText(
      find.byKey(const ValueKey('brief-Outcome')),
      'Test a readable core loop.',
    );
    await tester.tap(find.text('Create brief'));
    await tester.pumpAndSettle();
    expect(result!.defaultTitle, 'Forest prototype');
    expect(result!.body, contains('Test a readable core loop.'));
    expect(result!.body, contains('## Decisions & open questions'));
  });
}
