import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'editor_transactions_quality_test.dart' as fixtures;

void main() {
  for (final cut in [false, true]) {
    testWidgets(
      'delayed ${cut ? 'cut' : 'paste'} retires after an edit and undo return to identical source',
      (t) async {
        final draft = await fixtures.fixture(t);
        final gate = Completer<void>();
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'Clipboard.getData') {
            if (!cut) await gate.future;
            return {'text': 'CLIP'};
          }
          if (call.method == 'Clipboard.setData' && cut) await gate.future;
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
        final field = t.widget<TextField>(
          find.byKey(const ValueKey('note-body')),
        );
        await t.tap(find.byKey(const ValueKey('note-body')));
        field.controller!.selection = TextSelection(
          baseOffset: 0,
          extentOffset: cut ? 5 : 0,
        );
        await fixtures.command(
          t,
          cut ? LogicalKeyboardKey.keyX : LogicalKeyboardKey.keyV,
        );
        field.controller!.value = const TextEditingValue(
          text: 'temporary',
          selection: TextSelection.collapsed(offset: 9),
        );
        field.onChanged!('temporary');
        await t.pumpAndSettle();
        await fixtures.command(t, LogicalKeyboardKey.keyZ);
        expect(draft.value.body, 'alpha beta');
        gate.complete();
        await t.pumpAndSettle();
        expect(draft.value.body, 'alpha beta');
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'review authorization retires after source changes away and back',
    (t) async {
      final draft = await fixtures.fixture(t);
      await t.tap(find.byTooltip('Find in note · Ctrl+F'));
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextField, 'Find in this note'),
        'alpha',
      );
      await t.enterText(
        find.byKey(const ValueKey('note-replacement')),
        'changed',
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Replace all'));
      await t.pumpAndSettle();
      draft.value = (id: 'one', body: 'different text', readOnly: false);
      await t.pumpAndSettle();
      draft.value = (id: 'one', body: 'alpha beta', readOnly: false);
      await t.pumpAndSettle();
      await t.tap(find.textContaining('Apply '));
      await t.pumpAndSettle();
      expect(draft.value.body, 'alpha beta');
      expect(
        find.text('The note changed. Reopen the writing tool before applying.'),
        findsOneWidget,
      );
    },
  );
}
