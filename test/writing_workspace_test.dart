import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/document_footnotes.dart';
import 'package:orbit_note/domain/linked_section.dart';
import 'package:orbit_note/domain/object_reference.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/domain/writing_structure.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/note_format_toolbar.dart';
import 'package:orbit_note/features/notes/rich/rich_markdown_editor.dart';
import 'package:orbit_note/features/notes/writing_workspace.dart';

UniversalObject note(String id, String body) => UniversalObject(
  id: id,
  workspaceId: 'v',
  typeId: 'orbit.note',
  title: id,
  body: body,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
Finder field(String text) =>
    find.byWidgetPredicate((w) => w is TextField && w.controller?.text == text);

void main() {
  test('HTML/comment examples in code do not hide later prose', () {
    const source =
        '```html\n<!--\n<pre>\n```\n\n# Real\n\nText[^a]\n\n[^a]: Defined\n';
    expect(writingSections(source).map((s) => s.title), ['Real']);
    expect(DocumentFootnotes(source).references.single.id, 'a');
    expect(() => validateWritingAppend(source), returnsNormally);
    expect(() => validateWritingAppend('<pre>\nUnfinished'), throwsStateError);
    const html = '<pre>\n# Literal\n[^a]\n</pre>\n\n# Actual\n\nText[^a]';
    expect(writingSections(html).map((s) => s.title), ['Actual']);
    expect(
      DocumentFootnotes(html).references.single.start,
      html.lastIndexOf('[^a]'),
    );
  });
  testWidgets(
    'heading drag reorders whole sections and rejects stale drag source',
    (tester) async {
      const source = '# A\n\nOne\n\n## Child\n\nTwo\n\n# B\n\nThree\n';
      var body = source;
      late StateSetter refresh;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, update) {
                refresh = update;
                return WritingWorkspace(
                  source: body,
                  noteId: 'n',
                  objects: const [],
                  onApply: (before, next) {
                    if (body != before) throw StateError('Stale source');
                    update(() => body = next);
                    return true;
                  },
                  onNavigate: (_, _) {},
                  onFocus: (_) {},
                  onOpen: (_) {},
                  onRepair: (_, _) async {},
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      var targets = tester
          .widgetList<DragTarget<({int start, String source, String noteId})>>(
            find.byType(
              DragTarget<({int start, String source, String noteId})>,
            ),
          )
          .toList();
      final originalDrag = DragTargetDetails(
        data: (start: source.indexOf('# B'), source: source, noteId: 'n'),
        offset: Offset.zero,
      );
      expect(targets.first.onWillAcceptWithDetails!(originalDrag), isTrue);
      targets.first.onAcceptWithDetails!(originalDrag);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(body, '# B\n\nThree\n# A\n\nOne\n\n## Child\n\nTwo\n\n');
      refresh(() => body = '# Changed\n\n$body');
      await tester.pumpAndSettle();
      targets = tester
          .widgetList<DragTarget<({int start, String source, String noteId})>>(
            find.byType(
              DragTarget<({int start, String source, String noteId})>,
            ),
          )
          .toList();
      expect(targets.first.onWillAcceptWithDetails!(originalDrag), isFalse);
      final before = body;
      targets.first.onAcceptWithDetails!(originalDrag);
      await tester.pumpAndSettle();
      expect(body, before);
    },
  );
  test('sections move descendants losslessly with CRLF, Unicode and anchors', () {
    const source =
        'Intro\r\n\r\n# A ^a\r\n\r\nOne 😀\r\n\r\n## Child\r\n\r\nTwo\r\n\r\n# B\r\n\r\nThree\r\n';
    final sections = writingSections(source);
    expect(sections.map((s) => s.title), ['A', 'Child', 'B']);
    final a = sections.first;
    expect(a.end, source.indexOf('# B'));
    final moved = moveWritingSection(source, a, source.length);
    expect(
      moved,
      'Intro\r\n\r\n# B\r\n\r\nThree\r\n${source.substring(a.start, a.end)}',
    );
    expect(resolveWritingSection(moved, 'block:a')?.title, 'A');
    expect(
      () => moveWritingSection(source, a, sections[1].start),
      throwsStateError,
    );
  });
  test('heading rename retains body and stable anchor', () {
    const source = 'Intro\n\n# Original ^stable\n\nBody\n\n## Child\n';
    final renamed = renameWritingSection(
      source,
      writingSections(source).first,
      'New',
      2,
    );
    expect(renamed, source.replaceFirst('# Original', '## New'));
    expect(resolveWritingSection(renamed, 'block:stable')?.title, 'New');
    expect(
      () => renameWritingSection(
        source,
        writingSections(source).first,
        'bad\nname',
        1,
      ),
      throwsArgumentError,
    );
  });
  test('literal examples and frontmatter never become planning headings', () {
    const source =
        '---\n# Metadata\n---\n\n<!--\n# Comment\n-->\n\n```md\n# Code\n```\n\n    # Indented\n\n# Actual\n';
    expect(writingSections(source).map((s) => s.title), ['Actual']);
    expect(resolveWritingSection('# Same\n\n# Same\n', 'heading:Same'), isNull);
    expect(
      () => validateWritingAppend('# A\n\n```dart\nunfinished'),
      throwsStateError,
    );
    expect(() => validateWritingAppend('```\nclosed\n```'), returnsNormally);
  });
  test(
    'footnote diagnostics, multiline edits and safe renames preserve source',
    () {
      const source =
          'Prose 😀[^a] [^missing]\r\n\r\n`[^a]` \\[^a]\r\n\r\n[^a]: First\r\n    Second\r\n\r\n    Third\r\n\r\n[^unused]: Other\r\n';
      final model = DocumentFootnotes(source);
      expect(model.references.map((r) => r.id), ['a', 'missing']);
      expect(model.definitions.first.text, 'First\nSecond\n\nThird');
      final changed = model.save('a', 'Better\nTwo 😀', renamedId: 'renamed');
      expect(changed, contains('Prose 😀[^renamed] [^missing]\r\n'));
      expect(changed, contains('`[^a]` \\[^a]'));
      expect(changed, contains('[^renamed]: Better\r\n    Two 😀\r\n'));
      expect(changed, endsWith('[^unused]: Other\r\n'));
      expect(() => model.save('a', '', renamedId: 'unused'), throwsStateError);
      expect(
        () => model.save('a', '', renamedId: 'bad id'),
        throwsArgumentError,
      );
    },
  );
  test(
    'footnote references exclude literal metadata, comments and multiline code',
    () {
      const source =
          '---\nlabel: "[^a]"\n---\n\n<!-- [^a]\n[^a] -->\n\n``start\n[^a] ` inside\nend``\n\n~~~\n[^a]\n~~~\n\n    [^a]\n\nReal[^a]\n';
      expect(
        DocumentFootnotes(source).references.single.start,
        source.lastIndexOf('[^a]'),
      );
      expect(
        () => DocumentFootnotes('[^missing]\n\n```\n').save('missing', 'Text'),
        throwsStateError,
      );
      expect(
        () => DocumentFootnotes('[^a]: One\n\n[^a]: Two\n').save('a', 'Text'),
        throwsStateError,
      );
    },
  );
  test('identifier renames also update references inside other definitions', () {
    const source =
        'Text[^a]\n\n[^a]: Self[^a] `[^a]`\n\n[^b]: Also[^a]\n    More[^a]\n';
    final next = DocumentFootnotes(
      source,
    ).save('a', 'Self[^a] `[^a]`', renamedId: 'new');
    expect(
      next,
      'Text[^new]\n\n[^new]: Self[^new] `[^a]`\n\n[^b]: Also[^new]\n    More[^new]\n',
    );
  });
  test(
    'supported section embeds retain exact source ranges; fenced examples do not count',
    () {
      final embed = const LinkedSection(
        ObjectReference('source', anchorType: 'heading', anchorId: 'A'),
        'Saved',
        section: true,
      ).encode(eol: '\r\n');
      final source = '```md\r\n$embed```\r\n\r\n$embed';
      final use = sectionUses(source).single;
      expect(use.start, source.lastIndexOf('<!-- orbit:section '));
      expect(
        source.substring(use.start, use.end).trimRight(),
        embed.trimRight(),
      );
      expect(use.link.target.id, 'source');
    },
  );

  Future<void> rich(
    WidgetTester tester,
    String source,
    GlobalKey<RichMarkdownEditorState> key,
    ValueChanged<String> change,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RichMarkdownEditor(
            key: key,
            body: source,
            onChanged: change,
            onUndo: () {},
            onRedo: () {},
            linkTargets: const [],
            linkBindings: const {},
            onOpenLink: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mixed cross-block formatting becomes uniform and toggles off', (
    tester,
  ) async {
    const source = '**First**\n\nSecond\n';
    var body = source;
    final key = GlobalKey<RichMarkdownEditorState>();
    await rich(tester, source, key, (v) => body = v);
    key.currentState!.selectDocumentRange(0, source.length);
    await tester.pumpAndSettle();
    expect(key.currentState!.formatStates[NoteFormatAction.bold], 'mixed');
    await key.currentState!.format(NoteFormatAction.bold);
    await tester.pumpAndSettle();
    expect(body, '**First**\n\n**Second**\n');
    expect(key.currentState!.formatStates[NoteFormatAction.bold], 'on');
    await key.currentState!.format(NoteFormatAction.bold);
    await tester.pumpAndSettle();
    expect(body, 'First\n\nSecond\n');
  });
  testWidgets('aligned headings format without replacing alignment metadata', (
    tester,
  ) async {
    const source = '<!-- orbit:align=center -->\n# Title\n\nText\n';
    var body = source;
    final key = GlobalKey<RichMarkdownEditorState>();
    await rich(tester, source, key, (v) => body = v);
    key.currentState!.selectDocumentRange(0, source.length);
    await tester.pumpAndSettle();
    await key.currentState!.format(NoteFormatAction.italic);
    await tester.pumpAndSettle();
    expect(body, '<!-- orbit:align=center -->\n# *Title*\n\n*Text*\n');
  });
  testWidgets(
    'continuous math paragraph permits one native selection with rendered preview',
    (tester) async {
      const source = r'Before $x+1$ after.';
      var body = source;
      final key = GlobalKey<RichMarkdownEditorState>();
      await rich(tester, source, key, (v) => body = v);
      await tester.tap(find.text('Edit paragraph continuously'));
      await tester.pumpAndSettle();
      expect(field(source), findsOneWidget);
      expect(find.text('Rendered equations'), findsOneWidget);
      final controller = tester.widget<TextField>(field(source)).controller!;
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 17,
      );
      await tester.pump();
      await key.currentState!.format(NoteFormatAction.highlight);
      await tester.pumpAndSettle();
      expect(body, contains('=='));
      expect(body, contains(r'$x+1$'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'focused editor preserves hidden source and has full-document recovery',
    (tester) async {
      const source = '# A\n\nFirst\n\n# B\n\nSecond\n';
      var body = source;
      Map<String, dynamic>? view;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditor(
              noteId: 'n',
              title: 'Test',
              body: source,
              initialViewState: const {
                'mode': 'rich',
                'focusedSection': 'heading:B',
              },
              onViewStateChanged: (v) => view = v,
              onTitleChanged: (_) {},
              onBodyChanged: (v) => body = v,
              linkTargets: const [],
              onOpenObject: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(field('First'), findsNothing);
      expect(field('Second'), findsOneWidget);
      await tester.enterText(field('Second'), 'Edited');
      await tester.pumpAndSettle();
      expect(body, '# A\n\nFirst\n\n# B\n\nEdited\n');
      await tester.tap(find.text('Show full document'));
      await tester.pumpAndSettle();
      expect(field('First'), findsOneWidget);
      expect(view?['focusedSection'], isNull);
    },
  );

  Future<void> workspace(
    WidgetTester tester,
    String source, {
    int tab = 0,
    List<UniversalObject> objects = const [],
    bool Function(String, String)? apply,
    ValueChanged<int>? navigate,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WritingWorkspace(
            source: source,
            noteId: 'n',
            objects: objects,
            initialTab: tab,
            onApply: apply ?? (_, _) => true,
            onNavigate: (at, length) => navigate?.call(at),
            onFocus: (_) {},
            onOpen: (_) {},
            onRepair: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'footnote manager shows missing and unused definitions and navigates exact ranges',
    (tester) async {
      const source = 'Text[^missing]\n\n[^unused]: Value\n';
      int? target;
      await workspace(tester, source, tab: 1, navigate: (v) => target = v);
      expect(find.text('Missing definition'), findsOneWidget);
      expect(find.text('Unused definition'), findsOneWidget);
      await tester.tap(find.text('Reference 1'));
      expect(target, source.indexOf('[^missing]'));
      await tester.tap(find.text('Go to definition'));
      expect(target, source.indexOf('[^unused]'));
    },
  );
  testWidgets(
    'footnote edits reject stale source through owning editor boundary',
    (tester) async {
      const source = 'Text[^a]\n\n[^a]: Value\n';
      String? proposed;
      await workspace(
        tester,
        source,
        tab: 1,
        apply: (before, next) {
          expect(before, source);
          proposed = next;
          return false;
        },
      );
      await tester.tap(find.text('Edit footnote'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Value'), 'New\nMultiline');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(proposed, contains('[^a]: New\n    Multiline\n'));
      expect(find.text('Value'), findsOneWidget);
    },
  );
  testWidgets(
    'connections show exact incoming uses and missing outgoing targets',
    (tester) async {
      final incoming = const LinkedSection(
        ObjectReference('n', anchorType: 'heading', anchorId: 'A'),
        'Saved',
        section: true,
      ).encode();
      final outgoing = const LinkedSection(
        ObjectReference('missing', anchorType: 'block', anchorId: 'gone'),
        'Fallback',
      ).encode();
      await workspace(
        tester,
        '# A\n\n$outgoing',
        tab: 2,
        objects: [note('n', '# A\n\n$outgoing'), note('Host', incoming)],
      );
      expect(find.text('Host'), findsOneWidget);
      expect(find.text('Missing note'), findsOneWidget);
      expect(find.byTooltip('Repair linked section'), findsOneWidget);
    },
  );
  testWidgets('writing workspace handles narrow width with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 800),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: WritingWorkspace(
              source: '# A long section title for accessibility\n\nBody',
              noteId: 'n',
              objects: const [],
              onApply: (_, _) => true,
              onNavigate: (_, _) {},
              onFocus: (_) {},
              onOpen: (_) {},
              onRepair: (_, _) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Footnotes'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
