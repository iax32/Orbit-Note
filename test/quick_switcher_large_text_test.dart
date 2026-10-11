import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/domain/object_discovery.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/workspace/quick_switcher_dialog.dart';

class _Controller extends WorkspaceController {
  String? openedId;
  final createdTitles = <String?>[];

  @override
  void openObject(String id, {bool secondary = false}) => openedId = id;

  @override
  Future<UniversalObject?> create(
    String type, {
    bool open = true,
    String? title,
    String body = '',
    Map<String, dynamic> properties = const {},
    Map<String, dynamic>? data,
  }) async {
    createdTitles.add(title);
    return null;
  }
}

UniversalObject _object(
  String id,
  String title, {
  String type = 'orbit.note',
  Map<String, dynamic> properties = const {},
}) => UniversalObject(
  id: id,
  workspaceId: 'test',
  typeId: type,
  title: title,
  properties: properties,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

const _search = ValueKey('quick-switcher-search-input');

Future<void> _mount(
  WidgetTester tester,
  Size size,
  _Controller controller,
) async {
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
        ).copyWith(textScaler: const TextScaler.linear(2.5)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showQuickSwitcher(context, controller),
            child: const Text('Open switcher'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open switcher'));
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
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

void _readable(WidgetTester tester, Finder text) {
  expect(tester.renderObject<RenderParagraph>(text).didExceedMaxLines, isFalse);
}

void main() {
  const title =
      'Detailed interdisciplinary research and literature review document';
  const folder =
      'University research conference and interdisciplinary projects';
  for (final size in [const Size(320, 640), const Size(568, 320)]) {
    testWidgets('full switcher titles, context and badges wrap at $size', (
      tester,
    ) async {
      final object = _object('long', title, properties: {'folder': folder});
      final c = _Controller()
        ..objects = [object]
        ..session = SessionState(tabs: ['long'], activeId: 'long');
      await _mount(tester, size, c);
      _readable(tester, find.text(title));
      _readable(tester, find.text(objectContextLabel(object)));
      await _reveal(tester, find.text('ACTIVE'));
      _readable(tester, find.text('ACTIVE'));
      expect(tester.takeException(), isNull);
      expect(
        find.byTooltip('Close Quick Switcher').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Close Quick Switcher'));
      await tester.pumpAndSettle();
      expect(find.byType(QuickSwitcherDialog), findsNothing);
    });

    testWidgets('lazy keyboard selection reveals exact result at $size', (
      tester,
    ) async {
      final c = _Controller()
        ..objects = [
          for (var i = 0; i < 30; i++)
            _object(
              'item-$i',
              'Research ${i.toString().padLeft(2, '0')} $title',
              properties: {'folder': folder},
            ),
        ];
      await _mount(tester, size, c);
      await tester.enterText(find.byKey(_search), 'Research');
      await tester.pumpAndSettle();
      for (var i = 0; i < 24; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      expect(
        find.text(c.objects[24].title).hitTestable(at: Alignment.topCenter),
        findsOneWidget,
      );
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
      }
      expect(
        find.text(c.objects[21].title).hitTestable(at: Alignment.topCenter),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(c.openedId, 'item-21');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'query and accessible clear reset scrolled selection at $size',
      (tester) async {
        final c = _Controller()
          ..objects = [
            for (var i = 0; i < 30; i++)
              _object(
                'item-$i',
                'Research ${i.toString().padLeft(2, '0')} $title',
              ),
          ];
        await _mount(tester, size, c);
        await tester.enterText(find.byKey(_search), 'Research');
        await tester.pumpAndSettle();
        for (var i = 0; i < 15; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
        }
        await tester.enterText(find.byKey(_search), 'Research 28');
        await tester.pumpAndSettle();
        expect(
          find.text(c.objects[28].title).hitTestable(at: Alignment.topCenter),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('Clear search'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byKey(_search)).focusNode!.hasFocus,
          isTrue,
        );
        expect(
          find.text(c.objects.first.title).hitTestable(at: Alignment.topCenter),
          findsOneWidget,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(c.openedId, 'item-0');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'long create option and controls fit keyboard insets at $size',
      (tester) async {
        final c = _Controller();
        await _mount(tester, size, c);
        tester.view.viewInsets = FakeViewPadding(
          bottom: size.height > 400 ? 240 : 80,
        );
        addTearDown(tester.view.resetViewInsets);
        await tester.enterText(find.byKey(_search), title);
        await tester.pumpAndSettle();
        final create = find.text('Create new note "$title"');
        _readable(tester, create);
        expect(find.byTooltip('Clear search').hitTestable(), findsOneWidget);
        expect(
          find.byTooltip('Close Quick Switcher').hitTestable(),
          findsOneWidget,
        );
        await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(c.createdTitles, [title]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('row semantics and keyboard focus support Space activation', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final c = _Controller()
      ..objects = [_object('one', 'First note'), _object('two', 'Second note')];
    await _mount(tester, const Size(568, 320), c);
    final first = find.byKey(const ValueKey('quick-switcher-item-one'));
    expect(
      tester.getSemantics(first),
      matchesSemantics(
        label: 'First note\nNote',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // Close
    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // First result
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // Second result
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(c.openedId, 'two');
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets(
    'modified arrows preserve selection and document kinds remain distinct',
    (tester) async {
      final c = _Controller()
        ..objects = [
          _object(
            'pdf',
            'Research PDF',
            type: 'orbit.file',
            properties: {'mimeType': 'application/pdf'},
          ),
          _object(
            'latex',
            'Research equations',
            properties: {'documentFormat': 'latex'},
          ),
          _object('file', 'Research file', type: 'orbit.file'),
        ];
      await _mount(tester, const Size(568, 640), c);
      for (final label in ['PDF', 'LaTeX document', 'File']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(c.openedId, 'pdf');
    },
  );

  testWidgets('empty workspace hints scroll without hiding dismissal', (
    tester,
  ) async {
    await _mount(tester, const Size(320, 240), _Controller());
    await _reveal(tester, find.text('Dismiss'));
    _readable(tester, find.text('Dismiss'));
    expect(
      find.byTooltip('Close Quick Switcher').hitTestable(),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(QuickSwitcherDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
