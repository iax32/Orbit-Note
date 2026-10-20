import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/wiki_links.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/note_format_toolbar.dart';
import 'package:orbit_note/features/notes/rich/equation_editor.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';

import 'support/memory_store.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    ValueNotifier<({String id, String body, bool readOnly})> owner,
    List<String> edits, {
    WorkspaceController? controller,
    Future<String?> Function()? attachment,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: owner,
            builder: (_, value, _) => NoteEditor(
              noteId: value.id,
              title: 'Writing',
              body: value.body,
              viewOnly: value.readOnly,
              initialViewState: const {'mode': 'write', 'base': 0, 'extent': 0},
              spellCheckEnabled: false,
              controller: controller,
              onInsertAttachment: attachment,
              onBodyChanged: (body) => edits.add('${value.id}:$body'),
              onTitleChanged: (_) {},
              onOpenObject: (_) {},
              linkTargets: const [
                NoteLinkTarget(id: 'target', title: 'Target'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> completeDialog(WidgetTester tester, String kind) async {
    if (kind == 'equation') {
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    } else if (kind == 'table') {
      await tester.tap(find.text('Insert Table'));
    } else {
      await tester.tap(find.byKey(const ValueKey('note-link-target-target')));
    }
    await tester.pumpAndSettle();
  }

  for (final kind in ['equation', 'table', 'link']) {
    testWidgets('$kind insertion preserves content and undo', (tester) async {
      final owner = ValueNotifier((
        id: 'first',
        body: 'Original',
        readOnly: false,
      ));
      addTearDown(owner.dispose);
      final edits = <String>[];
      await mount(tester, owner, edits);
      tester.widget<NoteFormatToolbar>(find.byType(NoteFormatToolbar)).onFormat(
        switch (kind) {
          'equation' => NoteFormatAction.math,
          'table' => NoteFormatAction.table,
          _ => NoteFormatAction.link,
        },
      );
      await tester.pump(const Duration(milliseconds: 400));
      await completeDialog(tester, kind);
      expect(edits, hasLength(1));
      expect(edits.single, contains('Original'));
      expect(
        edits.single,
        contains(switch (kind) {
          'equation' => r'$x^2$',
          'table' => 'Column 1',
          _ => '[[target|Target]]',
        }),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(edits.last, 'first:Original');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'moved link insertion offers explicit relocation without bypassing read-only',
    (tester) async {
      final owner = ValueNotifier((
        id: 'first',
        body: 'Original',
        readOnly: false,
      ));
      addTearDown(owner.dispose);
      final edits = <String>[];
      await mount(tester, owner, edits);
      tester
          .widget<NoteFormatToolbar>(find.byType(NoteFormatToolbar))
          .onFormat(NoteFormatAction.link);
      await tester.pump(const Duration(milliseconds: 400));
      owner.value = (id: 'first', body: 'Newer text', readOnly: false);
      await tester.pump(const Duration(milliseconds: 400));
      await completeDialog(tester, 'link');
      final action = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
      expect(action.label, 'Insert here');
      owner.value = (id: 'first', body: 'Newer text', readOnly: true);
      await tester.pump();
      action.onPressed();
      await tester.pumpAndSettle();
      expect(edits, isEmpty);
    },
  );

  testWidgets(
    'equation studio remains reachable at narrow width and enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<String>(
                  context: context,
                  builder: (_) =>
                      const EquationEditor(source: 'x^2', display: false),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();
      expect(find.byType(EquationEditor), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final kind in ['equation', 'table', 'link']) {
    for (final change in ['other note', 'switch and return', 'read-only']) {
      testWidgets('$kind dialog refuses $change before completion', (
        tester,
      ) async {
        final owner = ValueNotifier((
          id: 'first',
          body: 'Original',
          readOnly: false,
        ));
        addTearDown(owner.dispose);
        final edits = <String>[];
        await mount(tester, owner, edits);
        final toolbar = tester.widget<NoteFormatToolbar>(
          find.byType(NoteFormatToolbar),
        );
        toolbar.onFormat(switch (kind) {
          'equation' => NoteFormatAction.math,
          'table' => NoteFormatAction.table,
          _ => NoteFormatAction.link,
        });
        await tester.pump(const Duration(milliseconds: 400));
        owner.value = change == 'read-only'
            ? (id: 'first', body: 'Original', readOnly: true)
            : (id: 'second', body: 'Original', readOnly: false);
        await tester.pump(const Duration(milliseconds: 400));
        if (change == 'switch and return') {
          owner.value = (id: 'first', body: 'Original', readOnly: false);
          await tester.pump(const Duration(milliseconds: 400));
        }
        await completeDialog(tester, kind);
        expect(edits, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('link dialog cannot overwrite newer authored text', (
    tester,
  ) async {
    final owner = ValueNotifier((
      id: 'first',
      body: 'Original',
      readOnly: false,
    ));
    addTearDown(owner.dispose);
    final edits = <String>[];
    await mount(tester, owner, edits);
    tester
        .widget<NoteFormatToolbar>(find.byType(NoteFormatToolbar))
        .onFormat(NoteFormatAction.link);
    await tester.pump(const Duration(milliseconds: 400));
    owner.value = (id: 'first', body: 'Newer text', readOnly: false);
    await tester.pump(const Duration(milliseconds: 400));
    await completeDialog(tester, 'link');
    expect(edits, isEmpty);
    expect(
      find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == 'Newer text',
      ),
      findsOneWidget,
    );
  });

  testWidgets('delayed attachment cannot insert after note switch and return', (
    tester,
  ) async {
    final owner = ValueNotifier((
      id: 'first',
      body: 'Original',
      readOnly: false,
    ));
    addTearDown(owner.dispose);
    final edits = <String>[];
    final result = Completer<String?>();
    await mount(tester, owner, edits, attachment: () => result.future);
    tester
        .widget<NoteFormatToolbar>(find.byType(NoteFormatToolbar))
        .onInsertAttachment!();
    await tester.pump();
    owner.value = (id: 'second', body: 'Original', readOnly: false);
    await tester.pump(const Duration(milliseconds: 400));
    owner.value = (id: 'first', body: 'Original', readOnly: false);
    await tester.pump(const Duration(milliseconds: 400));
    result.complete('![Photo](attachments/photo.png)');
    await tester.pumpAndSettle();
    expect(edits, isEmpty);
  });

  for (final switchBack in [false, true]) {
    testWidgets(
      'block placement refuses changed owner${switchBack ? ' and return' : ''}',
      (tester) async {
        final repo = WorkspaceRepository(
          store: MemoryStore(),
          index: MemoryObjectIndex(),
        );
        final container = ProviderContainer(
          overrides: [repositoryProvider.overrideWithValue(repo)],
        );
        final c = container.read(workspaceProvider.notifier);
        await c.initialize();
        addTearDown(() async {
          container.dispose();
          await repo.close();
        });
        final first = (await c.create(
          'orbit.note',
          title: 'First',
          body: 'Original',
        ))!;
        final second = (await c.create(
          'orbit.note',
          title: 'Second',
          body: 'Original',
        ))!;
        final board = (await c.create('orbit.canvas', title: 'Board'))!;
        final originalBoard = board.data;
        final owner = ValueNotifier((
          id: first.id,
          body: 'Original',
          readOnly: false,
        ));
        addTearDown(owner.dispose);
        await mount(tester, owner, [], controller: c);
        tester
            .widget<PopupMenuButton<String>>(
              find.byKey(const ValueKey('note-copy-as-menu')),
            )
            .onSelected!('place_block');
        await tester.pumpAndSettle();
        expect(find.text('Place current block on Canvas'), findsOneWidget);
        owner.value = (id: second.id, body: 'Original', readOnly: false);
        await tester.pumpAndSettle();
        if (switchBack) {
          owner.value = (id: first.id, body: 'Original', readOnly: false);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Board'));
        await tester.pumpAndSettle();
        expect(c.find(first.id)!.body, 'Original');
        expect(c.find(second.id)!.body, 'Original');
        expect(c.find(board.id)!.data, originalBoard);
        expect(tester.takeException(), isNull);
        c.cancelAllTimers();
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() => c.flushAll());
        c.cancelAllTimers();
      },
    );
  }
}
