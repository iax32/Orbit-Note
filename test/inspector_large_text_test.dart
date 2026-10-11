import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/features/workspace/object_inspector.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';

import 'support/memory_store.dart';

void main() {
  late ProviderContainer container;
  late WorkspaceController controller;
  const longKey = 'Research publication and review status';
  const longValue =
      'Waiting for the interdisciplinary research review committee';
  const longTag = 'interdisciplinary-research-and-literature-review';
  const targetTitle =
      'Interdisciplinary research with a long reference heading';
  const sourceTitle =
      'Source document with detailed research and reading notes';

  setUp(() async {
    final repo = WorkspaceRepository(
      store: MemoryStore(),
      index: MemoryObjectIndex(),
    );
    await repo.initialize();
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    controller = container.read(workspaceProvider.notifier);
    await controller.initialize();
    controller.session.motion = 'off';
  });

  Future<void> mount(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      controller.cancelAllTimers();
      final closing = controller.closeWorkspace();
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      await closing;
      container.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: orbitDarkTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2.5)),
            child: child!,
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 280,
                child: ObjectInspector(
                  controller: controller,
                  onRename: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    final list = find.descendant(
      of: find.byType(ObjectInspector),
      matching: find.byType(ListView),
    );
    final scrollable = find
        .descendant(of: list, matching: find.byType(Scrollable))
        .first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pump();
    await tester.scrollUntilVisible(
      finder,
      150,
      scrollable: scrollable,
      maxScrolls: 80,
    );
    await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  void readable(WidgetTester tester, String text) {
    expect(
      tester.renderObject<RenderParagraph>(find.text(text)).didExceedMaxLines,
      isFalse,
    );
  }

  for (final size in [const Size(320, 640), const Size(568, 320)]) {
    testWidgets(
      'typed properties wrap and edits preserve unknown metadata at $size',
      (tester) async {
        final note = (await tester.runAsync(
          () => controller.create('orbit.note', title: targetTitle),
        ))!;
        controller.updateProperty(note.id, longKey, longValue);
        controller.updateProperty(note.id, 'tags', [longTag, 'retained']);
        controller.updateProperty(note.id, 'completed', false);
        controller.updateProperty(note.id, 'unknown', {
          'future': [1, 2],
        });
        controller.openObject(note.id);
        await mount(tester, size);
        await reveal(tester, find.text(longKey));
        readable(tester, longKey);
        readable(tester, longValue);
        await reveal(tester, find.byType(Switch));
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(controller.find(note.id)!.properties['completed'], true);
        await reveal(tester, find.text('#$longTag'));
        readable(tester, '#$longTag');
        await tester.tap(find.byTooltip('Remove tag $longTag'));
        await tester.pumpAndSettle();
        expect(controller.find(note.id)!.properties['tags'], ['retained']);
        await reveal(tester, find.byTooltip('Remove $longKey'));
        await tester.tap(find.byTooltip('Remove $longKey'));
        await tester.pumpAndSettle();
        expect(
          controller.find(note.id)!.properties.containsKey(longKey),
          isFalse,
        );
        expect(controller.find(note.id)!.properties['unknown'], {
          'future': [1, 2],
        });
        expect(tester.takeException(), isNull);
        controller.cancelAllTimers();
      },
    );

    testWidgets(
      'property dialog keeps invalid input and footer accessible with keyboard at $size',
      (tester) async {
        final note = (await tester.runAsync(
          () => controller.create('orbit.note', title: targetTitle),
        ))!;
        controller.updateProperty(
          note.id,
          'url',
          'https://example.com/research',
        );
        controller.openObject(note.id);
        await mount(tester, size);
        await reveal(tester, find.byTooltip('Edit URL'));
        await tester.tap(find.byTooltip('Edit URL'));
        await tester.pumpAndSettle();
        tester.view.viewInsets = FakeViewPadding(
          bottom: size.height > 400 ? 240 : 80,
        );
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), 'missing-scheme');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        const error = 'Must be a valid URL with scheme (e.g. https://)';
        expect(find.text(error), findsOneWidget);
        readable(tester, error);
        expect(
          controller.find(note.id)!.properties['url'],
          'https://example.com/research',
        );
        await tester.enterText(
          find.byType(TextFormField),
          'https://example.com/updated',
        );
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(
          controller.find(note.id)!.properties['url'],
          'https://example.com/updated',
        );
        expect(tester.takeException(), isNull);
        controller.cancelAllTimers();
      },
    );

    testWidgets(
      'relation tabs, long references and link commands remain usable at $size',
      (tester) async {
        final target = (await tester.runAsync(
          () => controller.create('orbit.note', title: targetTitle),
        ))!;
        final source = (await tester.runAsync(
          () => controller.create(
            'orbit.note',
            title: sourceTitle,
            body:
                'Opening context [[${target.id}#A detailed research section with long words|$targetTitle]]. Additional retained context.',
          ),
        ))!;
        final unlinked = (await tester.runAsync(
          () => controller.create(
            'orbit.note',
            title: 'Unlinked research notes',
            body: 'Before $targetTitle after.',
          ),
        ))!;
        controller.openObject(target.id);
        await mount(tester, size);
        await reveal(tester, find.text(sourceTitle));
        readable(tester, sourceTitle);
        await tester.tap(find.text(sourceTitle));
        await tester.pumpAndSettle();
        expect(controller.session.activeId, source.id);
        expect(controller.locationRequests.containsKey(source.id), isTrue);
        await reveal(tester, find.text('Outbound'));
        await tester.tap(find.text('Outbound'));
        await tester.pumpAndSettle();
        await reveal(tester, find.text(targetTitle));
        readable(tester, targetTitle);
        controller.openObject(target.id);
        await tester.pumpAndSettle();
        await reveal(tester, find.text('Unlinked'));
        await tester.tap(find.text('Unlinked'));
        await tester.pumpAndSettle();
        await reveal(tester, find.text('"$targetTitle"'));
        readable(tester, '"$targetTitle"');
        await reveal(tester, find.text('Link'));
        await tester.tap(find.text('Link'));
        await tester.pumpAndSettle();
        final body = controller.find(unlinked.id)!.body;
        expect(body, startsWith('Before '));
        expect(body, endsWith(' after.'));
        expect(controller.outboundLinks(unlinked.id).single.id, target.id);
        expect(tester.takeException(), isNull);
        controller.cancelAllTimers();
      },
    );

    testWidgets(
      'add-property types and cancellation fit enlarged text at $size',
      (tester) async {
        final note = (await tester.runAsync(
          () => controller.create('orbit.note', title: targetTitle),
        ))!;
        controller.openObject(note.id);
        await mount(tester, size);
        await reveal(tester, find.text('Add'));
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add Property').last);
        await tester.pumpAndSettle();
        readable(tester, 'Name cannot be empty');
        await tester.enterText(find.byType(TextFormField).first, longKey);
        final dropdown = find.byType(DropdownButtonFormField<PropertyType>);
        expect(dropdown, findsOneWidget);
        final selected = find.text('Text').last;
        await Scrollable.ensureVisible(tester.element(selected), alignment: .5);
        await tester.pumpAndSettle();
        final dialogScroll = find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.dragUntilVisible(
          selected.hitTestable(),
          dialogScroll,
          const Offset(0, -60),
        );
        await tester.pumpAndSettle();
        await tester.tap(selected.hitTestable());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Checkbox (Boolean)').last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(
          controller.find(note.id)!.properties.containsKey(longKey),
          isFalse,
        );
        controller.cancelAllTimers();
      },
    );
    testWidgets('local graph controls reflow and remain operable at $size', (
      tester,
    ) async {
      final note = (await tester.runAsync(
        () => controller.create('orbit.note', title: targetTitle),
      ))!;
      controller.openObject(note.id);
      await mount(tester, size);
      await reveal(tester, find.text('Graph'));
      await tester.tap(find.text('Graph'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('2 Hops'));
      await tester.tap(find.text('2 Hops'));
      await tester.pumpAndSettle();
      await reveal(tester, find.byTooltip('Reset graph view'));
      expect(find.byTooltip('Reset graph view').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Reset graph view'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      controller.cancelAllTimers();
    });
  }

  testWidgets(
    'legacy date outside picker bounds can be cancelled without altering it',
    (tester) async {
      final note = (await tester.runAsync(
        () => controller.create('orbit.note', title: targetTitle),
      ))!;
      controller.updateProperty(note.id, 'date', '1800-01-01');
      controller.openObject(note.id);
      await mount(tester, const Size(800, 800));
      await reveal(tester, find.text('1800-01-01'));
      await tester.tap(find.text('1800-01-01'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(controller.find(note.id)!.properties['date'], '1800-01-01');
      controller.cancelAllTimers();
    },
  );
}
