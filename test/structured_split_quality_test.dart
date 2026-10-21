import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/workspace/orbit_tab_strip.dart';
import 'package:orbit_note/features/notes/rich/rich_table_editor.dart';
import 'split_focus_quality_test.dart' as fixtures;

const structuredSource =
    'Intro\r\n\r\n| Name | Detail |\r\n| --- | --- |\r\n| one | a\\|b target |\r\n| two | second target |\r\n\r\n```dart\r\nalpha target 😀\r\n```\r\n\r\nTail';
Finder pane(String id) =>
    find.byWidgetPredicate((w) => w is NoteEditor && w.noteId == id);
Finder field(String id, String key) =>
    find.descendant(of: pane(id), matching: find.byKey(ValueKey(key)));

void main() {
  for (final cut in [false, true]) {
    testWidgets(
      'code ${cut ? 'cut' : 'literal paste'} remains undoable beside another pane',
      (t) async {
        final (c, a, b, _) = await fixtures.fixture(
          t,
          bodyA: structuredSource,
          bodyB: structuredSource,
          mode: 'rich',
        );
        final target = field(a.id, 'rich-code');
        await t.ensureVisible(target);
        await t.tap(target);
        final controller = t.widget<TextField>(target).controller!;
        controller.selection = TextSelection(
          baseOffset: cut ? 6 : 0,
          extentOffset: cut ? 12 : controller.text.length,
        );
        String? copied;
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'Clipboard.getData') {
            return {'text': '```\nnew 😀'};
          }
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
        addTearDown(
          () =>
              messenger.setMockMethodCallHandler(SystemChannels.platform, null),
        );
        await fixtures.shortcut(
          t,
          cut ? LogicalKeyboardKey.keyX : LogicalKeyboardKey.keyV,
        );
        if (cut) {
          expect(copied, 'target');
          expect(c.find(a.id)!.body, contains('alpha  😀'));
        } else {
          expect(
            c.find(a.id)!.body,
            contains('````dart\r\n```\nnew 😀\r\n````'),
          );
        }
        final changed = c.find(a.id)!.body;
        expect(c.find(b.id)!.body, structuredSource);
        await fixtures.shortcut(t, LogicalKeyboardKey.keyZ);
        expect(c.find(a.id)!.body, structuredSource);
        await fixtures.shortcut(t, LogicalKeyboardKey.keyY);
        expect(c.find(a.id)!.body, changed);
        c.cancelAllTimers();
      },
    );
  }
  for (final code in [false, true]) {
    testWidgets(
      'secondary ${code ? 'code' : 'table'} Find/Replace and document history stay in their pane',
      (t) async {
        final (c, a, b, _) = await fixtures.fixture(
          t,
          bodyA: structuredSource,
          bodyB: structuredSource,
          mode: 'rich',
        );
        final target = field(b.id, code ? 'rich-code' : 'rich-cell-2-1');
        await t.ensureVisible(target);
        await t.tap(target);
        final controller = t.widget<TextField>(target).controller!;
        final start = controller.text.indexOf('target');
        controller.selection = TextSelection(
          baseOffset: start + 6,
          extentOffset: start,
        );
        await fixtures.shortcut(t, LogicalKeyboardKey.keyF);
        final query = find.descendant(
          of: pane(b.id),
          matching: find.widgetWithText(TextField, 'Find in this note'),
        );
        expect(t.widget<TextField>(query).controller!.text, 'target');
        await t.tap(
          find.descendant(
            of: pane(b.id),
            matching: find.byTooltip('Find in selection · Alt+S'),
          ),
        );
        await t.enterText(field(b.id, 'note-replacement'), 'VALUE');
        await t.pumpAndSettle();
        expect(
          find.descendant(of: pane(b.id), matching: find.text('1 match')),
          findsOneWidget,
        );
        await t.tap(
          find.descendant(
            of: pane(b.id),
            matching: find.text('Replace all in selection'),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.textContaining('Apply '));
        await t.pumpAndSettle();
        final expected = structuredSource.replaceFirst(
          code ? 'alpha target' : 'second target',
          code ? 'alpha VALUE' : 'second VALUE',
        );
        expect(c.find(a.id)!.body, structuredSource);
        expect(c.find(b.id)!.body, expected);
        await fixtures.shortcut(t, LogicalKeyboardKey.keyZ);
        expect(
          c.find(b.id)!.body,
          expected,
          reason: 'Find input owns keyboard undo',
        );
        await t.tap(field(b.id, 'note-document-undo'));
        await t.pumpAndSettle();
        expect(c.find(b.id)!.body, structuredSource);
        expect(c.find(a.id)!.body, structuredSource);
        await t.tap(field(b.id, 'note-document-redo'));
        await t.pumpAndSettle();
        expect(c.find(b.id)!.body, expected);
        c.cancelAllTimers();
      },
    );
    testWidgets(
      'same-note ${code ? 'code' : 'table'} conflict undo preserves the winning pane',
      (t) async {
        final (c, a, _, _) = await fixtures.fixture(
          t,
          bodyA: structuredSource,
          bodyB: structuredSource,
          mode: 'rich',
        );
        c.openObject(a.id, secondary: true);
        await t.pumpAndSettle();
        final fields = find.byKey(
          ValueKey(code ? 'rich-code' : 'rich-cell-2-1'),
        );
        final left = t.widget<TextField>(fields.first),
            right = t.widget<TextField>(fields.last);
        final original = left.controller!.text;
        left.controller!.text = 'left accepted';
        left.onChanged!('left accepted');
        right.controller!.text = 'right retained';
        right.onChanged!('right retained');
        await t.pumpAndSettle();
        final canonical = c.find(a.id)!.body;
        expect(canonical, contains('left accepted'));
        expect(canonical, isNot(contains('right retained')));
        final undo = find
            .byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Undo · Ctrl+Z',
            )
            .last;
        t.widget<IconButton>(undo).onPressed!();
        await t.pumpAndSettle();
        expect(c.find(a.id)!.body, canonical);
        expect(t.widget<TextField>(fields.last).controller!.text, original);
        expect(
          c.editorDraftConflicts['secondary:${a.id}']!.body,
          structuredSource,
        );
        c.cancelAllTimers();
      },
    );
  }
  testWidgets('external table text updates preserve both selection endpoints', (
    t,
  ) async {
    final (c, a, b, _) = await fixtures.fixture(
      t,
      bodyA: structuredSource,
      bodyB: structuredSource,
      mode: 'rich',
    );
    final target = field(a.id, 'rich-cell-2-1');
    await t.ensureVisible(target);
    await t.tap(target);
    const selection = TextSelection(baseOffset: 9, extentOffset: 2);
    t.widget<TextField>(target).controller!.selection = selection;
    c.edit(
      a.id,
      body: structuredSource.replaceFirst(
        'second target',
        'second target extra',
      ),
    );
    await t.pumpAndSettle();
    expect(t.widget<TextField>(target).controller!.selection, selection);
    expect(c.find(b.id)!.body, structuredSource);
    c.cancelAllTimers();
  });
  for (final code in [false, true]) {
    testWidgets(
      'delayed ${code ? 'code paste' : 'table grid paste'} retires when another pane takes focus',
      (t) async {
        final (c, a, b, _) = await fixtures.fixture(
          t,
          bodyA: structuredSource,
          bodyB: structuredSource,
          mode: 'rich',
        );
        final key = code ? 'rich-code' : 'rich-cell-2-1';
        final left = field(a.id, key), right = field(b.id, key);
        await t.ensureVisible(left);
        await t.tap(left);
        await t.pumpAndSettle();
        final gate = Completer<void>(), entered = Completer<void>();
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'Clipboard.getData') {
            if (!entered.isCompleted) entered.complete();
            await gate.future;
            return {'text': 'PASTED'};
          }
          return null;
        });
        messenger.setMockMethodCallHandler(
          const MethodChannel('pasteboard'),
          (_) async => null,
        );
        addTearDown(() {
          if (!gate.isCompleted) gate.complete();
          messenger.setMockMethodCallHandler(SystemChannels.platform, null);
          messenger.setMockMethodCallHandler(
            const MethodChannel('pasteboard'),
            null,
          );
        });
        Future<void>? pending;
        if (code) {
          await fixtures.shortcut(t, LogicalKeyboardKey.keyV);
        } else {
          final state = t.state<RichTableEditorState>(
            find.descendant(
              of: pane(a.id),
              matching: find.byType(RichTableEditor),
            ),
          );
          state.selectRectangle(
            startRow: 1,
            startColumn: 0,
            endRow: 2,
            endColumn: 1,
          );
          pending = state.pasteGrid();
        }
        await t.pump();
        expect(entered.isCompleted, isTrue);
        await t.ensureVisible(right);
        await t.tap(right);
        await t.pumpAndSettle();
        gate.complete();
        await pending;
        await t.pumpAndSettle();
        expect(c.find(a.id)!.body, structuredSource);
        expect(c.find(b.id)!.body, structuredSource);
        c.cancelAllTimers();
      },
    );
  }
  for (final key in ['rich-cell-2-1', 'rich-code']) {
    testWidgets(
      'reactivating a split restores $key focus and backwards selection',
      (t) async {
        final (c, a, b, _) = await fixtures.fixture(
          t,
          bodyA: structuredSource,
          bodyB: structuredSource,
          mode: 'rich',
        );
        final left = field(a.id, key), right = field(b.id, key);
        await t.ensureVisible(left);
        await t.tap(left);
        final controller = t.widget<TextField>(left).controller!;
        const selection = TextSelection(baseOffset: 6, extentOffset: 1);
        controller.selection = selection;
        await t.ensureVisible(right);
        await t.tap(right);
        await t.pumpAndSettle();
        t.widget<OrbitTabStrip>(find.byType(OrbitTabStrip)).onActivate(a.id);
        await t.pumpAndSettle();
        expect(t.widget<TextField>(left).focusNode!.hasFocus, isTrue);
        expect(controller.selection, selection);
        expect(c.find(a.id)!.body, structuredSource);
        expect(c.find(b.id)!.body, structuredSource);
        c.cancelAllTimers();
      },
    );
  }
}
