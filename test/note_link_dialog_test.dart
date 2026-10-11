import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/domain/wiki_links.dart';
import 'package:orbit_note/features/notes/note_link_dialog.dart';

const _search = ValueKey('note-link-search');

Future<void> _mount(
  WidgetTester tester,
  List<NoteLinkTarget> targets, {
  Size size = const Size(800, 640),
  double scale = 1,
  String query = '',
  ValueChanged<NoteLinkTarget?>? onResult,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: orbitDarkTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final target = await showNoteLinkDialog(
                context,
                targets,
                initialQuery: query,
              );
              onResult?.call(target);
            },
            child: const Text('Pick link'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Pick link'));
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isNotEmpty) {
    await Scrollable.ensureVisible(tester.element(target));
    await tester.pumpAndSettle();
    return;
  }
  await tester.scrollUntilVisible(
    target.hitTestable(at: Alignment.topCenter),
    100,
    maxScrolls: 100,
    scrollable: find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

void _readable(WidgetTester tester, Finder text) => expect(
  tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
  isFalse,
);

void main() {
  const title =
      'Detailed interdisciplinary research and literature review document';
  const alias = 'University research conference and interdisciplinary projects';
  const id =
      'stable-object-identity-for-the-complete-research-conference-source';

  for (final size in [const Size(320, 640), const Size(568, 320)]) {
    testWidgets('link target details wrap at 250% text in $size', (
      tester,
    ) async {
      const target = NoteLinkTarget(id: id, title: title, aliases: [alias]);
      NoteLinkTarget? chosen;
      await _mount(
        tester,
        [target],
        size: size,
        scale: 2.5,
        onResult: (value) => chosen = value,
      );
      await _reveal(tester, find.text(title));
      _readable(tester, find.text(title));
      await _reveal(tester, find.text(id));
      _readable(tester, find.text(id));
      await _reveal(tester, find.text('Aliases: $alias'));
      _readable(tester, find.text('Aliases: $alias'));
      expect(find.text('Cancel').hitTestable(), findsOneWidget);
      await tester.tap(
        find.text('Aliases: $alias').hitTestable(at: Alignment.topCenter),
      );
      await tester.pumpAndSettle();
      expect(chosen, same(target));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'keyboard reveals tall lazy targets and picks exact identity in $size',
      (tester) async {
        final targets = [
          for (var i = 0; i < 30; i++)
            NoteLinkTarget(
              id: 'id-$i',
              title: 'Research ${i.toString().padLeft(2, '0')} $title',
              aliases: [alias],
            ),
        ];
        NoteLinkTarget? chosen;
        await _mount(
          tester,
          targets,
          size: size,
          scale: 2.5,
          onResult: (value) => chosen = value,
        );
        for (var i = 0; i < 24; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
        }
        expect(
          find.text(targets[24].title).hitTestable(at: Alignment.topCenter),
          findsOneWidget,
        );
        for (var i = 0; i < 3; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
          await tester.pumpAndSettle();
        }
        expect(
          find.text(targets[21].title).hitTestable(at: Alignment.topCenter),
          findsOneWidget,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(chosen, same(targets[21]));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'keyboard insets keep cancellation reachable and empty query editable in $size',
      (tester) async {
        final results = <NoteLinkTarget?>[];
        await _mount(
          tester,
          const [NoteLinkTarget(id: id, title: title)],
          size: size,
          scale: 2.5,
          query: 'unmatched',
          onResult: results.add,
        );
        tester.view.viewInsets = FakeViewPadding(
          bottom: size.height > 400 ? 240 : 80,
        );
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        await _reveal(tester, find.text('No matching objects'));
        _readable(tester, find.text('No matching objects'));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(results, isEmpty);
        expect(find.text('Cancel').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(results, [null]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('alias search and clear reset scrolled selection in $size', (
      tester,
    ) async {
      final targets = [
        for (var i = 0; i < 30; i++)
          NoteLinkTarget(
            id: 'id-$i',
            title: 'Research ${i.toString().padLeft(2, '0')} $title',
            aliases: [i == 28 ? 'Needle' : alias],
          ),
      ];
      NoteLinkTarget? chosen;
      await _mount(
        tester,
        targets,
        size: size,
        scale: 2.5,
        onResult: (value) => chosen = value,
      );
      for (var i = 0; i < 12; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      await tester.enterText(find.byKey(_search), ' nEeDlE ');
      await tester.pumpAndSettle();
      await _reveal(tester, find.text(targets[28].title));
      _readable(tester, find.text(targets[28].title));
      await _reveal(tester, find.byTooltip('Clear search'));
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byKey(_search)).focusNode!.hasFocus,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(chosen, same(targets.first));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'same-title objects expose identity and selected button semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      const targets = [
        NoteLinkTarget(id: 'b', title: 'Research'),
        NoteLinkTarget(id: 'a', title: 'Research'),
      ];
      NoteLinkTarget? chosen;
      await _mount(tester, targets, onResult: (value) => chosen = value);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('note-link-target-a'))),
        matchesSemantics(
          label: 'Research\na',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // First target
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // Second target
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(chosen, same(targets.first));
      semantics.dispose();
    },
  );

  testWidgets(
    'initial query, modified arrows and repeated Enter preserve exact choice',
    (tester) async {
      const targets = [
        NoteLinkTarget(id: 'a', title: 'Alpha'),
        NoteLinkTarget(id: 'b', title: 'Beta', aliases: ['Alpha alias']),
      ];
      final results = <NoteLinkTarget?>[];
      await _mount(tester, targets, query: 'ALPHA', onResult: results.add);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(results, [same(targets.first)]);
    },
  );

  testWidgets(
    'empty workspace can dismiss with Escape without selecting a target',
    (tester) async {
      final results = <NoteLinkTarget?>[];
      await _mount(tester, [], onResult: results.add);
      expect(find.text('No matching objects'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(results, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(results, [null]);
    },
  );
}
