import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';
import 'support/memory_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:orbit_note/domain/document_anchors.dart';
import 'package:orbit_note/domain/linked_section.dart';
import 'package:orbit_note/domain/object_reference.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/notes/linked_section.dart';
import 'package:orbit_note/features/notes/note_typography.dart';
import 'package:orbit_note/features/notes/rich/markdown_document.dart';

UniversalObject note(String id, String body) => UniversalObject(
  id: id,
  workspaceId: 'vault',
  typeId: 'orbit.note',
  title: 'Design $id',
  body: body,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
const typography = NoteTypography(
  fontFamily: 'Segoe UI',
  fontSize: 16,
  lineHeight: 1.6,
);

void main() {
  test(
    'heading/list anchors remain hidden and survive edits; code stays literal',
    () {
      for (final body in [
        '# Jump\n\nText',
        'Jump\r\n====\r\n\r\nText',
        '- [ ] Check\n',
      ]) {
        final anchored = anchorDocumentBlock(
          body,
          'a',
          0,
          'stable',
          structured: true,
        );
        final fragment = resolveDocumentFragment(
          anchored.source,
          anchored.reference,
        )!;
        expect(fragment.text, contains('stable'));
        final document = MarkdownDocument.parse(anchored.source);
        expect(document.source, anchored.source);
        expect(document.blocks.first.content, isNot(contains('^stable')));
        final edited = document.blocks.first.replaceContent('Updated');
        expect(edited, contains('^stable'));
      }
      const source = 'Text ^p\r\n\r\n```cpp\r\nvalue ^literal\r\n```\r\n';
      expect(
        withoutBlockAnchor(source),
        'Text\r\n\r\n```cpp\r\nvalue ^literal\r\n```\r\n',
      );
      final nested = LinkedSection(
        const ObjectReference('b', anchorType: 'block', anchorId: 'p'),
        'Older',
      );
      final outer = LinkedSection(
        const ObjectReference('a', anchorType: 'heading', anchorId: 'A'),
        '',
        section: true,
      );
      final snapshot = snapshotLinkedSection(
        outer,
        [note('a', '# A\n\n${nested.encode()}'), note('b', 'Latest ^p')],
        {'host'},
      );
      expect(snapshot, contains('Latest'));
      expect(snapshot, isNot(contains('orbit:section')));
    },
  );
  test(
    'structured anchors persist through normal saves and reject failed writes',
    () async {
      final store = MemoryStore();
      final repository = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repository)],
      );
      final controller = container.read(workspaceProvider.notifier);
      while (controller.loading) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      try {
        final source = (await controller.create(
          'orbit.note',
          title: 'Mechanic',
        ))!;
        controller.edit(
          source.id,
          body: '# Jump\r\n\r\n- [ ] Test\r\n',
          properties: {
            ...source.properties,
            'future': {'keep': true},
          },
        );
        await controller.flush(source.id);
        final reference = await controller.referenceNoteBlock(
          source.id,
          0,
          structured: true,
        );
        expect(controller.dirty, isNot(contains(source.id)));
        expect(controller.find(source.id)!.properties['future'], {
          'keep': true,
        });
        final saved = controller.find(source.id)!;
        expect(
          resolveDocumentFragment(saved.body, reference)?.heading,
          contains('Jump'),
        );
        store.failWrites = true;
        await expectLater(
          controller.referenceNoteBlock(
            source.id,
            saved.body.indexOf('- [ ]'),
            structured: true,
          ),
          throwsStateError,
        );
        expect(controller.dirty, contains(source.id));
        store.failWrites = false;
        await controller.flush(source.id);
      } finally {
        container.dispose();
        await repository.close();
      }
      final reopened = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await reopened.initialize();
      expect(
        reopened.objects.where((o) => o.title == 'Mechanic').single.body,
        contains('^orbit-'),
      );
      await reopened.close();
    },
  );
  testWidgets(
    'Rich editor refreshes cached linked sections without editing the host',
    (tester) async {
      final link = LinkedSection(
        const ObjectReference('a', anchorType: 'block', anchorId: 'p'),
        'Snapshot',
      );
      final host = 'Before\n\n${link.encode()}\nAfter';
      String? edited;
      Future<void> render(String text) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichMarkdownEditor(
              noteId: 'host',
              body: host,
              allObjects: [note('a', '$text ^p')],
              onChanged: (v) => edited = v,
              onUndo: () {},
              onRedo: () {},
              linkTargets: const [],
              linkBindings: const {},
              onOpenLink: (_) {},
            ),
          ),
        ),
      );
      await render('First live text');
      await render('Updated live text');
      expect(
        find.text('Updated live text', findRichText: true),
        findsOneWidget,
      );
      expect(edited, isNull);
      await tester.tap(find.text('Make independent copy'));
      await tester.pump();
      expect(edited, contains('Before\n\nUpdated live text\n\nAfter'));
      expect(edited, contains('After'));
      expect(edited, isNot(contains('orbit:section')));
    },
  );
  test(
    'portable snapshot preserves Unicode, nested markers and surrounding source',
    () {
      const fallback =
          '## Jump 😀\r\n\r\n<!-- /orbit:section -->\r\n- [ ] Tune';
      final link = LinkedSection(
        const ObjectReference('a', anchorType: 'block', anchorId: 'jump'),
        fallback,
        section: true,
      );
      final encoded = link.encode(eol: '\r\n');
      final parsed = LinkedSection.parse(encoded)!;
      expect(parsed.target.target, 'a#^jump');
      expect(parsed.fallback, fallback.replaceAll('\r\n', '\n'));
      expect(parsed.section, isTrue);
      final body = 'Before\r\n\r\n$encoded\r\nAfter';
      final document = MarkdownDocument.parse(body);
      expect(document.source, body);
      expect(
        document.blocks.where((b) => LinkedSection.parse(b.source) != null),
        hasLength(1),
      );
      expect(
        LinkedSection.parse(
          encoded.replaceFirst('"section":true', '"section":true,"future":1'),
        ),
        isNull,
      );
      expect(
        LinkedSection.parse(
          encoded.replaceRange(
            encoded.lastIndexOf(LinkedSection.closing),
            encoded.lastIndexOf(LinkedSection.closing) +
                LinkedSection.closing.length,
            'broken',
          ),
        ),
        isNull,
      );
      expect(
        MarkdownDocument.parse('```markdown\n$encoded```\n').blocks.first.kind,
        MarkdownBlockKind.code,
      );
    },
  );
  test(
    'stable anchored headings include subordinate sections and survive rename',
    () {
      const body =
          '# Jump\r\n\r\nTune 😀\r\n\r\n## Air control\r\n\r\n- [ ] Test\r\n\r\n# Run\r\n\r\nOther';
      final anchored = anchorDocumentBlock(
        body,
        'a',
        0,
        'jump',
        structured: true,
      );
      final link = LinkedSection(anchored.reference, 'snapshot', section: true);
      final resolved = resolveLinkedSection(
        link,
        [note('a', anchored.source)],
        {'host'},
      );
      expect(resolved.warning, isNull);
      expect(resolved.text, contains('Air control'));
      expect(resolved.text, isNot(contains('# Run')));
      expect(resolved.text, isNot(contains('^jump')));
      expect(
        resolveLinkedSection(
          link,
          [note('a', anchored.source.replaceFirst('Jump', 'Leap'))],
          {'host'},
        ).text,
        contains('Leap'),
      );
      expect(
        anchorDocumentBlock(
          anchored.source,
          'a',
          0,
          'unused',
          structured: true,
        ).source,
        anchored.source,
      );
    },
  );
  test(
    'live paragraphs, checklists, ambiguity and safe missing/cyclic fallbacks',
    () {
      final anchored = anchorDocumentBlock(
        '- [ ] Test\n- [x] Fix\n',
        'a',
        0,
        'tasks',
        structured: true,
      );
      final link = LinkedSection(anchored.reference, 'Saved tasks');
      expect(
        resolveLinkedSection(link, [note('a', anchored.source)], {'host'}).text,
        contains('- [x] Fix'),
      );
      expect(
        resolveLinkedSection(
          link,
          [note('a', anchored.source.replaceFirst('[ ]', '[x]'))],
          {'host'},
        ).text,
        startsWith('- [x]'),
      );
      expect(resolveLinkedSection(link, [], {'host'}).text, 'Saved tasks');
      expect(
        resolveLinkedSection(link, [note('a', anchored.source)], {'a'}).warning,
        contains('Circular'),
      );
      expect(
        resolveLinkedSection(link, [
          note('a', '${anchored.source}\nAgain ^tasks'),
        ], {}).warning,
        contains('ambiguous'),
      );
      expect(
        () => anchorDocumentBlock('> quote', 'a', 0, 'bad', structured: true),
        throwsStateError,
      );
    },
  );
  testWidgets(
    'Rich card updates source, opens exact target and copies latest text',
    (tester) async {
      final link = LinkedSection(
        const ObjectReference('a', anchorType: 'block', anchorId: 'p'),
        'Old snapshot',
      );
      String? opened, copied;
      var removed = false;
      Future<void> render(String text) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LinkedSectionCard(
              link: link,
              objects: [note('a', '$text ^p')],
              ancestors: const {'host'},
              typography: typography,
              onOpen: (v) => opened = v,
              onCopy: (v) => copied = v,
              onRemove: () => removed = true,
            ),
          ),
        ),
      );
      await render('First version');
      expect(find.text('First version', findRichText: true), findsOneWidget);
      await render('New version');
      expect(find.text('New version', findRichText: true), findsOneWidget);
      await tester.tap(find.text('Open source'));
      expect(opened, 'a#^p');
      await tester.tap(find.text('Make independent copy'));
      expect(copied, 'New version');
      await tester.tap(find.byTooltip('Remove linked section'));
      expect(removed, isTrue);
    },
  );
  testWidgets(
    'Read parses live embeds, stops nested cycles and scales narrowly',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final a = LinkedSection(
        const ObjectReference('a', anchorType: 'heading', anchorId: 'A'),
        'Snapshot A',
        section: true,
      );
      final b = LinkedSection(
        const ObjectReference('b', anchorType: 'heading', anchorId: 'B'),
        'Snapshot B',
        section: true,
      );
      final objects = [
        note('a', '# A\n\n${b.encode()}'),
        note('b', '# B\n\n${a.encode()}'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: MarkdownBody(
                  data: a.encode(),
                  blockSyntaxes: const [LinkedSectionSyntax()],
                  builders: {
                    'orbit-section': LinkedSectionBuilder(
                      objects: objects,
                      onOpen: (_) {},
                      typography: typography,
                      ancestors: const {'host'},
                    ),
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Circular'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'picker searches and previews, returns a section and stays usable at 200%',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? inserted;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    inserted = await showLinkedSectionPicker(
                      context,
                      [note('a', '# Jump\n\nUseful detail\n\n# Run\nOther')],
                      'host',
                      null,
                    );
                  },
                  child: const Text('Choose'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Jump');
      await tester.pump();
      await tester.tap(find.byType(ListTile).first);
      await tester.pump();
      expect(find.text('Useful detail', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Insert linked section'));
      await tester.pumpAndSettle();
      expect(
        LinkedSection.parse(inserted!)!.fallback,
        contains('Useful detail'),
      );
    },
  );
}
