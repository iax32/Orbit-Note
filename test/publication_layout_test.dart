import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:orbit_note/domain/document_publication.dart';
import 'package:orbit_note/domain/publication_layout.dart';
import 'package:orbit_note/features/notes/export/publication_export.dart';
import 'package:orbit_note/features/notes/export/publication_workspace.dart';
import 'package:orbit_note/features/notes/note_find_index.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'support/pdf_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const source =
      '# Mechanic\r\n\r\n![Timing diagram](Attachments/diagram.png)\r\n\r\n## Timing\r\n\r\n| Phase | Duration |\r\n| --- | --- |\r\n| Windup | 120 ms |\r\n| Recovery | 300 ms |\r\n';
  const style = PublicationStyle(
    letter: true,
    margin: 72,
    fontSize: 12,
    titlePage: true,
    header: 'Gameplay specification',
  );

  Map<String, Map<String, dynamic>> layouts() {
    final nodes = PublicationDocument.parse(
      'Gameplay',
      source,
      style,
    ).nodes.where(publicationLayoutTarget).toList();
    return {
      publicationLayoutKey(nodes[0]): {
        ...const PublicationBlockLayout(
          width: 50,
          alignment: 'right',
          caption: 'Figure 1. Attack timing.',
        ).toJson(),
        'futureOption': 'retain',
      },
      publicationLayoutKey(nodes[1]): const PublicationBlockLayout(
        width: 75,
        alignment: 'center',
        caption: 'Table 1. Frame budget.',
        pageBreakBefore: true,
        repeatHeader: false,
      ).toJson(),
    };
  }

  test(
    'settings round-trip preserves source endings, future fields and search offsets',
    () {
      final saved = PublicationSettings.update(source, {
        ...style.toJson(),
        'futureFont': 'retain',
      }, layouts());
      final record = PublicationSettings.parse(saved)!;
      expect(saved.substring(record.end), source);
      final updated = PublicationSettings.update(
        saved,
        const PublicationStyle(fontSize: 14).toJson(),
        layouts(),
      );
      final reopened = PublicationSettings.parse(updated)!;
      expect(reopened.data['style']['futureFont'], 'retain');
      expect(
        (reopened.data['blocks'] as Map).values.first['futureOption'],
        'retain',
      );
      expect(
        PublicationStyle.fromJson(
          Map<String, dynamic>.from(reopened.data['style'] as Map),
        ).fontSize,
        14,
      );
      expect(PublicationSettings.mask(saved).length, saved.length);
      final find = NoteFindIndex(saved, rich: true);
      expect(
        find.matches('futureFont', matchCase: true, wholeWord: false),
        isEmpty,
      );
      final match = find
          .matches('Windup', matchCase: true, wholeWord: false)
          .single;
      expect(saved.substring(match.start, match.end), 'Windup');
      final private = PublicationSettings.update(
        '---\nprivateToken: not-for-export\n---\n\n# Public\n',
        style.toJson(),
        {},
      );
      expect(
        PublicationExport(
          PublicationDocument.parse('Public', private, style),
        ).html(),
        isNot(contains('not-for-export')),
      );
      expect(private, contains('not-for-export'));
    },
  );

  test(
    'future, malformed and invalid settings remain literal and refuse overwrite',
    () {
      for (final value in [
        '<!-- orbit:publication {"version":2,"style":{},"blocks":{}} -->\n',
        '<!-- orbit:publication {"version":1,"style":{"margin":900},"blocks":{}} -->\n',
        '<!-- orbit:publication broken -->\n',
      ]) {
        expect(PublicationSettings.parse(value), isNull);
        expect(PublicationSettings.mask(value), value);
        expect(
          () => PublicationSettings.update(value, style.toJson(), {}),
          throwsFormatException,
        );
      }
      expect(
        PublicationSettings.parse(
          '```md\n${PublicationSettings.update(source, style.toJson(), {})}\n```',
        ),
        isNull,
      );
    },
  );

  test(
    'layout matching follows reordered unique content and refuses duplicate or changed content',
    () {
      final values = layouts();
      final saved = PublicationSettings.update(source, style.toJson(), values);
      final document = PublicationDocument.parse('Gameplay', saved, style);
      final image =
          document.nodes.where(publicationLayoutTarget).first as md.Element;
      expect(image.attributes['orbit-width'], '50');
      final reordered = PublicationDocument.parse(
        'Reordered',
        PublicationSettings.update(
          '| Phase | Duration |\n| --- | --- |\n| Windup | 120 ms |\n| Recovery | 300 ms |\n\n![Timing diagram](Attachments/diagram.png)\n',
          style.toJson(),
          values,
        ),
        style,
      );
      expect(
        (reordered.nodes.where(publicationLayoutTarget).first as md.Element)
            .attributes['orbit-width'],
        '75',
      );
      final duplicate = PublicationDocument.parse(
        'Gameplay',
        '$saved\r\n![Timing diagram](Attachments/diagram.png)\r\n',
        style,
      );
      expect(duplicate.warnings.any((w) => w.contains('ambiguous')), true);
      expect(
        (duplicate.nodes.where(publicationLayoutTarget).first as md.Element)
            .attributes['orbit-width'],
        isNull,
      );
      final changed = PublicationDocument.parse(
        'Gameplay',
        saved.replaceFirst('Attachments/diagram.png', 'Attachments/new.png'),
        style,
      );
      expect(changed.warnings.any((w) => w.contains('no longer match')), true);
    },
  );

  test(
    'PDF, HTML and Word share print geometry, captions, page breaks and real heading pages',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 320, 180),
        Paint()..color = const Color(0xff23364a),
      );
      canvas.drawRect(
        const Rect.fromLTWH(24, 68, 100, 44),
        Paint()..color = const Color(0xff88b4dc),
      );
      canvas.drawRect(
        const Rect.fromLTWH(184, 68, 100, 44),
        Paint()..color = const Color(0xffafc7b5),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(320, 180);
      final png = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      image.dispose();
      picture.dispose();
      final saved = PublicationSettings.update(
        source,
        style.toJson(),
        layouts(),
      );
      final export = PublicationExport(
        PublicationDocument.parse('Gameplay', saved, style),
        images: {'Attachments/diagram.png': png},
      );
      final bytes = await export.pdf();
      expect(await initPdfTesting(), true);
      final pdf = await PdfDocument.openData(bytes);
      try {
        expect(export.pageCount, pdf.pages.length);
        for (final heading in export.document.headings) {
          final page = export.headingPages[heading.id]!;
          expect(
            (await pdf.pages[page - 1].loadText())!.fullText,
            contains(heading.text),
          );
        }
        final fullText = (await Future.wait(
          pdf.pages.map((p) => p.loadText()),
        )).map((t) => t!.fullText).join();
        expect(fullText, contains('Figure 1. Attack timing.'));
        expect(fullText, contains('Table 1. Frame budget.'));
        final tablePage = pdf.pages.last;
        expect((await tablePage.loadText())!.fullText, contains('Windup'));
        await File('.local/publication-layout-review.pdf').writeAsBytes(bytes);
        for (var i = 0; i < pdf.pages.length; i++) {
          final rendered = await pdf.pages[i].render(width: 612, height: 792);
          final preview = await rendered!.createImage();
          await File(
            '.local/publication-layout-review-${i + 1}.png',
          ).writeAsBytes(
            (await preview.toByteData(
              format: ui.ImageByteFormat.png,
            ))!.buffer.asUint8List(),
          );
          preview.dispose();
          rendered.dispose();
        }
      } finally {
        await pdf.dispose();
      }
      final html = export.html();
      expect(html, contains('width:50%'));
      expect(html, contains('width:75%'));
      expect(html, contains('break-before:page'));
      expect(html, contains('PDF page'));
      expect(html, contains('Figure 1. Attack timing.'));
      expect(html, isNot(contains('futureFont')));
      final zip = ZipDecoder().decodeBytes(export.docx());
      final xml = utf8.decode(
        zip.findFile('word/document.xml')!.content as List<int>,
      );
      expect(xml, contains('<w:tblW w:w="3750" w:type="pct"/>'));
      expect(xml, contains('<w:jc w:val="right"/>'));
      expect(xml, contains('PAGEREF heading_1'));
      expect(xml, contains('cx="2971800"'));
      expect(xml, isNot(contains('<w:tblHeader/>')));
      expect(xml, contains('Table 1. Frame budget.'));
    },
  );

  test(
    'saved print settings reopen from portable Markdown and remain recoverable',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'orbit-publication-',
      );
      WorkspaceRepository repository = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: MemoryObjectIndex(),
      );
      try {
        await repository.initialize(path: folder.path);
        final note = await repository.create(
          typeId: 'orbit.note',
          title: 'Gameplay',
          body: source,
        );
        final body = PublicationSettings.update(
          source,
          style.toJson(),
          layouts(),
        );
        await repository.save(note.copyWith(body: body));
        await repository.close();
        repository = WorkspaceRepository(
          store: NativeWorkspaceStore(),
          index: MemoryObjectIndex(),
        );
        await repository.initialize(path: folder.path);
        final reopened = repository.objects.single;
        expect(reopened.body, body);
        expect(
          PublicationStyle.fromJson(
            Map<String, dynamic>.from(
              PublicationSettings.parse(reopened.body)!.data['style'] as Map,
            ),
          ).letter,
          true,
        );
        await repository.save(reopened.copyWith(body: source));
        expect(repository.objects.single.body, source);
        final files = await folder
            .list(recursive: true)
            .where((e) => e is File)
            .toList();
        expect(
          await Future.wait(
            files
                .where((e) => e.path.endsWith('.md'))
                .map((e) => (e as File).readAsString()),
          ),
          contains(contains('Timing diagram')),
        );
      } finally {
        await repository.close();
        await folder.delete(recursive: true);
      }
    },
  );

  test(
    'large tables span pages with repeated headers and retain their last row',
    () async {
      final table =
          '| Phase | Description |\n| --- | --- |\n${List.generate(180, (i) => '| Step $i | An observation with enough text to use several lines in a narrow table. |').join('\n')}';
      final initial = PublicationDocument.parse(
        'Table',
        table,
        const PublicationStyle(contents: false),
      );
      final key = publicationLayoutKey(initial.nodes.single);
      final saved = PublicationSettings.update(
        table,
        const PublicationStyle(contents: false).toJson(),
        {
          key: const PublicationBlockLayout(
            width: 50,
            caption: 'End of table.',
          ).toJson(),
        },
      );
      final export = PublicationExport(
        PublicationDocument.parse(
          'Table',
          saved,
          const PublicationStyle(contents: false),
        ),
      );
      final bytes = await export.pdf();
      expect(await initPdfTesting(), true);
      final pdf = await PdfDocument.openData(bytes);
      try {
        expect(pdf.pages.length, greaterThan(2));
        final texts = (await Future.wait(
          pdf.pages.map((p) => p.loadText()),
        )).map((p) => p!.fullText).toList();
        expect(texts[1].replaceAll(RegExp(r'\s'), ''), contains('Phase'));
        expect(texts.join().replaceAll(RegExp(r'\s'), ''), contains('Step179'));
        expect(texts.join(), contains('End of table.'));
      } finally {
        await pdf.dispose();
      }
      final zip = ZipDecoder().decodeBytes(export.docx());
      expect(
        utf8.decode(zip.findFile('word/document.xml')!.content as List<int>),
        contains('<w:tblHeader/>'),
      );
    },
  );
  testWidgets(
    'contents navigation and saving use the generated pages and refuse stale saves',
    (tester) async {
      String? saved;
      int? page;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PublicationWorkspace(
              title: 'Gameplay',
              source: source,
              previewBuilder: (_) => const Text('Preview ready'),
              onNavigatePage: (value) => page = value,
              onApply: (before, next) {
                expect(before, source);
                saved = next;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });

      await tester.pump();
      final heading = find.text('Mechanic');
      await tester.ensureVisible(heading);
      await tester.tap(heading);
      await tester.pump();
      expect(page, greaterThan(0));
      await tester.tap(find.text('Save settings to note'));
      await tester.pump();
      expect(PublicationSettings.parse(saved!), isNotNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PublicationWorkspace(
              title: 'Gameplay',
              source: source,
              previewBuilder: (_) => const Text('Preview ready'),
              onApply: (_, _) => false,
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.tap(find.text('Save settings to note'));
      await tester.pump();
      expect(
        find.textContaining('The note changed or is read-only'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'caption editing keeps focus during page regeneration and restores saved settings',
    (tester) async {
      String? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PublicationWorkspace(
              title: 'Gameplay',
              source: source,
              previewBuilder: (_) => const Text('Preview ready'),
              onApply: (_, next) {
                saved = next;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      final target = find.text('Image · Timing diagram');
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
      final caption = find.byType(TextFormField).first;
      await tester.ensureVisible(caption);
      await tester.enterText(caption, 'Edited caption');
      final field = tester.widget<EditableText>(
        find.descendant(of: caption, matching: find.byType(EditableText)),
      );
      expect(field.focusNode.hasFocus, true);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      expect(find.text('Edited caption'), findsOneWidget);
      expect(field.focusNode.hasFocus, true);
      await tester.tap(find.text('Save settings to note'));
      await tester.pump();
      expect(
        (PublicationSettings.parse(saved!)!.data['blocks'] as Map)
            .values
            .first['caption'],
        'Edited caption',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PublicationWorkspace(
              title: 'Gameplay',
              source: PublicationSettings.update(
                source,
                style.toJson(),
                layouts(),
              ),
              previewBuilder: (_) => const Text('Preview ready'),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Letter'))
            .selected,
        true,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'image/table controls remain usable at compact width and 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(480, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(480, 900),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: PublicationWorkspace(
                title: 'Gameplay',
                source: source,
                previewBuilder: (_) => const Text('Preview ready'),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.tap(find.text('Document style'));
      await tester.pumpAndSettle();
      final target = find.text('Image · Timing diagram');
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
      final caption = find.byType(TextFormField).first;
      await tester.ensureVisible(caption);
      await tester.enterText(caption, 'A readable caption');
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'saving print settings preserves Source selection and one-step undo',
    (tester) async {
      await tester.runAsync(() async {
        expect(await initPdfTesting(), true);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditor(
              noteId: 'gameplay',
              title: 'Gameplay',
              body: source,
              onTitleChanged: (_) {},
              onBodyChanged: (_) {},
              linkTargets: const [],
              onOpenObject: (_) {},
              initialViewState: const {'mode': 'write'},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == source,
      );
      final editing = tester.widget<TextField>(field).controller!;
      final from = source.indexOf('Windup');
      editing.selection = TextSelection(
        baseOffset: from,
        extentOffset: from + 6,
      );
      await tester.tap(find.byTooltip('Publish document'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();
      await tester.tap(find.text('Save settings to note'));
      await tester.pump();
      await tester.tap(find.byTooltip('Close publishing'));
      await tester.pumpAndSettle();
      expect(editing.selection.textInside(editing.text), 'Windup');
      tester
          .widget<TextField>(
            find.byWidgetPredicate(
              (w) => w is TextField && w.controller == editing,
            ),
          )
          .focusNode!
          .requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(editing.text, source);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
