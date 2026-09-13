import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orbit_note/canvas/geometry.dart';
import 'package:orbit_note/canvas/scene.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/canvas/canvas_painter.dart';
import 'package:orbit_note/features/canvas/canvas_rich_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CanvasRichText - Parsing', () {
    test('parses headings 1, 2, and 3', () {
      final h1 = CanvasRichText.parseLine('# My Heading', 0);
      expect(h1.type, CanvasRichLineType.heading1);
      expect(h1.contentText, 'My Heading');

      final h2 = CanvasRichText.parseLine('## Subheading', 1);
      expect(h2.type, CanvasRichLineType.heading2);
      expect(h2.contentText, 'Subheading');

      final h3 = CanvasRichText.parseLine('### Minor Section', 2);
      expect(h3.type, CanvasRichLineType.heading3);
      expect(h3.contentText, 'Minor Section');
    });

    test(
      'parses unchecked checklists with various syntaxes and indentations',
      () {
        final line1 = CanvasRichText.parseLine('- [ ] Buy milk', 0);
        expect(line1.type, CanvasRichLineType.checklistUnchecked);
        expect(line1.contentText, 'Buy milk');

        final line2 = CanvasRichText.parseLine('* [ ] Walk dog', 1);
        expect(line2.type, CanvasRichLineType.checklistUnchecked);
        expect(line2.contentText, 'Walk dog');

        final line3 = CanvasRichText.parseLine('[ ] Quick task', 2);
        expect(line3.type, CanvasRichLineType.checklistUnchecked);
        expect(line3.contentText, 'Quick task');

        final line4 = CanvasRichText.parseLine('  - [ ] Indented subtask', 3);
        expect(line4.type, CanvasRichLineType.checklistUnchecked);
        expect(line4.contentText, 'Indented subtask');
      },
    );

    test('parses checked checklists (lowercase x and uppercase X)', () {
      final line1 = CanvasRichText.parseLine('- [x] Finish homework', 0);
      expect(line1.type, CanvasRichLineType.checklistChecked);
      expect(line1.contentText, 'Finish homework');

      final line2 = CanvasRichText.parseLine('- [X] Pay bills', 1);
      expect(line2.type, CanvasRichLineType.checklistChecked);
      expect(line2.contentText, 'Pay bills');

      final line3 = CanvasRichText.parseLine('* [x] Workout', 2);
      expect(line3.type, CanvasRichLineType.checklistChecked);
      expect(line3.contentText, 'Workout');

      final line4 = CanvasRichText.parseLine('[x] Done task', 3);
      expect(line4.type, CanvasRichLineType.checklistChecked);
      expect(line4.contentText, 'Done task');
    });

    test('parses bullet and numbered lists', () {
      final bullet1 = CanvasRichText.parseLine('- Item one', 0);
      expect(bullet1.type, CanvasRichLineType.bullet);
      expect(bullet1.contentText, 'Item one');

      final bullet2 = CanvasRichText.parseLine('* Item two', 1);
      expect(bullet2.type, CanvasRichLineType.bullet);
      expect(bullet2.contentText, 'Item two');

      final num = CanvasRichText.parseLine('1. First step', 2);
      expect(num.type, CanvasRichLineType.numbered);
      expect(num.prefix, '1.');
      expect(num.contentText, 'First step');
    });

    test('parses paragraphs and empty lines', () {
      final p = CanvasRichText.parseLine('Just a regular line of prose', 0);
      expect(p.type, CanvasRichLineType.paragraph);
      expect(p.contentText, 'Just a regular line of prose');

      final empty = CanvasRichText.parseLine('   ', 1);
      expect(empty.type, CanvasRichLineType.empty);
      expect(empty.contentText, '');
    });

    test('hasRichFormatting detects markdown formatting accurately', () {
      expect(CanvasRichText.hasRichFormatting('# Heading'), isTrue);
      expect(CanvasRichText.hasRichFormatting('- [ ] Task'), isTrue);
      expect(CanvasRichText.hasRichFormatting('- [x] Done'), isTrue);
      expect(CanvasRichText.hasRichFormatting('- Bullet'), isTrue);
      expect(CanvasRichText.hasRichFormatting('1. Numbered'), isTrue);
      expect(
        CanvasRichText.hasRichFormatting('Plain text without formatting'),
        isFalse,
      );
    });
  });

  group('CanvasRichText - Checkbox Toggling', () {
    test('toggles - [ ] to - [x] and vice versa', () {
      const text = '# Tasks\n- [ ] Task 1\n- [x] Task 2';

      final checked1 = CanvasRichText.toggleLine(text, 1);
      expect(checked1, '# Tasks\n- [x] Task 1\n- [x] Task 2');

      final unchecked2 = CanvasRichText.toggleLine(text, 2);
      expect(unchecked2, '# Tasks\n- [ ] Task 1\n- [ ] Task 2');

      final roundTrip = CanvasRichText.toggleLine(checked1, 1);
      expect(roundTrip, text);
    });

    test('preserves indentation and alternative checklist styles', () {
      const text = '  - [ ] Indented\n[ ] Bracket only\n* [x] Asterisk';

      expect(
        CanvasRichText.toggleLine(text, 0),
        '  - [x] Indented\n[ ] Bracket only\n* [x] Asterisk',
      );
      expect(
        CanvasRichText.toggleLine(text, 1),
        '  - [ ] Indented\n[x] Bracket only\n* [x] Asterisk',
      );
      expect(
        CanvasRichText.toggleLine(text, 2),
        '  - [ ] Indented\n[ ] Bracket only\n* [ ] Asterisk',
      );
    });

    test(
      'returns original text if lineIndex is out of bounds or not a checklist',
      () {
        const text = '# Title\nJust text';
        expect(CanvasRichText.toggleLine(text, -1), text);
        expect(CanvasRichText.toggleLine(text, 5), text);
        expect(CanvasRichText.toggleLine(text, 0), text);
        expect(CanvasRichText.toggleLine(text, 1), text);
      },
    );
  });

  group('CanvasRichText - Hit Testing', () {
    test('accurately hits checkbox within hit bounds and ignores outside', () {
      final cache = CanvasTextCache();
      const text = '# Tasks\n- [ ] First task\n- [x] Second task';
      const bounds = Rect.fromLTWH(100, 100, 200, 150);

      // Line 0 is heading (~30px high, ends ~134)
      // Line 1 is "- [ ] First task", box is around x=100..114, y=134..154
      final hitLine1 = CanvasRichText.hitTestCheckbox(
        text: text,
        bounds: bounds,
        clickOffset: const Offset(105, 142),
        textCache: cache,
      );
      expect(hitLine1, 1);

      // Line 2 is "- [x] Second task", box is around x=100..114, y=162..182
      final hitLine2 = CanvasRichText.hitTestCheckbox(
        text: text,
        bounds: bounds,
        clickOffset: const Offset(108, 170),
        textCache: cache,
      );
      expect(hitLine2, 2);

      // Clicking on the text content far to the right (x=160) does NOT hit the checkbox
      final hitTextFar = CanvasRichText.hitTestCheckbox(
        text: text,
        bounds: bounds,
        clickOffset: const Offset(160, 142),
        textCache: cache,
      );
      expect(hitTextFar, isNull);

      // Clicking heading does not hit any checkbox
      final hitHeading = CanvasRichText.hitTestCheckbox(
        text: text,
        bounds: bounds,
        clickOffset: const Offset(105, 110),
        textCache: cache,
      );
      expect(hitHeading, isNull);

      cache.dispose();
    });
  });

  group('CanvasRichText - Smart Enter & Prefix Formatting', () {
    test(
      'handleSmartEnter auto-prefixes next line on active checklist item',
      () {
        const text = '- [ ] First task';
        final res = CanvasRichText.handleSmartEnter(
          text,
          const TextSelection.collapsed(offset: text.length),
        );
        expect(res, isNotNull);
        expect(res!.text, '- [ ] First task\n- [ ] ');
        expect(res.selection.baseOffset, '- [ ] First task\n- [ ] '.length);
      },
    );

    test('handleSmartEnter clears prefix on empty checklist item', () {
      const text = '- [ ] First task\n- [ ] ';
      final res = CanvasRichText.handleSmartEnter(
        text,
        const TextSelection.collapsed(offset: text.length),
      );
      expect(res, isNotNull);
      expect(res!.text, '- [ ] First task\n');
      expect(res.selection.baseOffset, '- [ ] First task\n'.length);
    });

    test('handleSmartEnter auto-prefixes bullets and clears empty bullets', () {
      const bulletText = '- An idea';
      final res = CanvasRichText.handleSmartEnter(
        bulletText,
        const TextSelection.collapsed(offset: bulletText.length),
      );
      expect(res, isNotNull);
      expect(res!.text, '- An idea\n- ');

      const emptyBullet = '- An idea\n- ';
      final res2 = CanvasRichText.handleSmartEnter(
        emptyBullet,
        const TextSelection.collapsed(offset: emptyBullet.length),
      );
      expect(res2, isNotNull);
      expect(res2!.text, '- An idea\n');
    });

    test('toggleLinePrefix toggles checklist and heading prefixes', () {
      // Toggle checklist on plain line
      final r1 = CanvasRichText.toggleLinePrefix(
        'Buy groceries',
        const TextSelection.collapsed(offset: 5),
        '- [ ] ',
      );
      expect(r1.text, '- [ ] Buy groceries');

      // Toggle checklist off on existing checklist line
      final r2 = CanvasRichText.toggleLinePrefix(
        '- [ ] Buy groceries',
        const TextSelection.collapsed(offset: 10),
        '- [ ] ',
      );
      expect(r2.text, 'Buy groceries');

      // Toggle heading 1
      final r3 = CanvasRichText.toggleLinePrefix(
        'Project Plan',
        const TextSelection.collapsed(offset: 5),
        '# ',
      );
      expect(r3.text, '# Project Plan');

      // Toggle heading 1 to heading 2
      final r4 = CanvasRichText.toggleLinePrefix(
        '# Project Plan',
        const TextSelection.collapsed(offset: 5),
        '## ',
      );
      expect(r4.text, '## Project Plan');

      // Toggle heading 2 off
      final r5 = CanvasRichText.toggleLinePrefix(
        '## Project Plan',
        const TextSelection.collapsed(offset: 5),
        '## ',
      );
      expect(r5.text, 'Project Plan');
    });
  });

  group('Canvas Editor - Interactive Checkbox & Toolbar Widgets', () {
    testWidgets(
      'single click on canvas sticky checkbox toggles checked state',
      (tester) async {
        Map<String, dynamic>? updatedData;

        final stickyElement = CanvasElement({
          'id': 'sticky-1',
          'type': 'sticky',
          'x': 100.0,
          'y': 100.0,
          'width': 220.0,
          'height': 180.0,
          'color': 0xFFFCD34D,
          'text': '# Tasks\n- [ ] Buy groceries\n- [ ] Water plants',
        });

        final initialScene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': [stickyElement.data],
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CanvasEditor(
                canvasId: 'test-canvas',
                title: 'Test Canvas',
                data: initialScene.toJson(),
                camera: const CanvasCamera(x: 0, y: 0, zoom: 1.0).toJson(),
                objects: const [],
                onChanged: (data) => updatedData = data,
                onCameraChanged: (_) {},
                onOpenObject: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final canvasOrigin = tester.getTopLeft(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
          ),
        );

        // Tap directly on Line 1 checkbox (Offset 122, 158)
        await tester.tapAt(canvasOrigin + const Offset(122, 158));
        await tester.pumpAndSettle();

        expect(updatedData, isNotNull);
        final elements = updatedData!['elements'] as List;
        final updatedSticky = elements.firstWhere((e) => e['id'] == 'sticky-1');
        expect(
          updatedSticky['text'],
          '# Tasks\n- [x] Buy groceries\n- [ ] Water plants',
        );

        // Tap again on the same checkbox: should toggle back to unchecked!
        await tester.tapAt(canvasOrigin + const Offset(122, 158));
        await tester.pumpAndSettle();
        final elementsAfterSecondTap = updatedData!['elements'] as List;
        final toggledBackSticky = elementsAfterSecondTap.firstWhere(
          (e) => e['id'] == 'sticky-1',
        );
        expect(
          toggledBackSticky['text'],
          '# Tasks\n- [ ] Buy groceries\n- [ ] Water plants',
        );
      },
    );

    testWidgets(
      'editing overlay displays format buttons (Task, H1, H2, H3, List)',
      (tester) async {
        final stickyElement = CanvasElement({
          'id': 'sticky-1',
          'type': 'sticky',
          'x': 100.0,
          'y': 100.0,
          'width': 220.0,
          'height': 180.0,
          'color': 0xFFFCD34D,
          'text': 'Initial note',
        });

        final initialScene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': [stickyElement.data],
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CanvasEditor(
                canvasId: 'test-canvas',
                title: 'Test Canvas',
                data: initialScene.toJson(),
                camera: const CanvasCamera(x: 0, y: 0, zoom: 1.0).toJson(),
                objects: const [],
                onChanged: (_) {},
                onCameraChanged: (_) {},
                onOpenObject: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final canvasOrigin = tester.getTopLeft(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
          ),
        );

        // Click note to select, then press Enter to edit
        await tester.tapAt(canvasOrigin + const Offset(180, 180));
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        // Verify the TextField overlay appears
        expect(
          find.byKey(const ValueKey('canvas-element-text-field')),
          findsOneWidget,
        );

        // Verify quick format buttons appear
        expect(find.text('Task'), findsOneWidget);
        expect(find.text('H1'), findsOneWidget);
        expect(find.text('H2'), findsOneWidget);
        expect(find.text('H3'), findsOneWidget);
        expect(find.text('List'), findsOneWidget);

        // Click the "Task" button to convert line to checklist
        await tester.tap(find.text('Task'));
        await tester.pumpAndSettle();

        final textField = tester.widget<TextField>(
          find.byKey(const ValueKey('canvas-element-text-field')),
        );
        expect(textField.controller!.text, '- [ ] Initial note');

        // Click H1 button: changes to heading 1
        await tester.tap(find.text('H1'));
        await tester.pumpAndSettle();
        expect(textField.controller!.text, '# Initial note');

        // Click H2 button: changes to heading 2
        await tester.tap(find.text('H2'));
        await tester.pumpAndSettle();
        expect(textField.controller!.text, '## Initial note');

        // Click List button: changes to bullet list
        await tester.tap(find.text('List'));
        await tester.pumpAndSettle();
        expect(textField.controller!.text, '- Initial note');
      },
    );

    testWidgets(
      'smart Enter continues checklist and empty Enter clears prefix',
      (tester) async {
        final stickyElement = CanvasElement({
          'id': 'sticky-1',
          'type': 'sticky',
          'x': 100.0,
          'y': 100.0,
          'width': 220.0,
          'height': 180.0,
          'color': 0xFFFCD34D,
          'text': '- [ ] First task',
        });

        final initialScene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': [stickyElement.data],
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CanvasEditor(
                canvasId: 'test-canvas',
                title: 'Test Canvas',
                data: initialScene.toJson(),
                camera: const CanvasCamera(x: 0, y: 0, zoom: 1.0).toJson(),
                objects: const [],
                onChanged: (_) {},
                onCameraChanged: (_) {},
                onOpenObject: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final canvasOrigin = tester.getTopLeft(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
          ),
        );

        // Click note to select, then press Enter to edit
        await tester.tapAt(canvasOrigin + const Offset(180, 180));
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        final textFieldFinder = find.byKey(
          const ValueKey('canvas-element-text-field'),
        );
        expect(textFieldFinder, findsOneWidget);

        final textField = tester.widget<TextField>(textFieldFinder);
        textField.controller!.selection = TextSelection.collapsed(
          offset: textField.controller!.text.length,
        );

        // Press Enter key while in TextField
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        // Should auto-insert \n- [ ]
        expect(textField.controller!.text, '- [ ] First task\n- [ ] ');

        // Press Enter again on the empty item: should clear prefix
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(textField.controller!.text, '- [ ] First task\n');
      },
    );

    testWidgets(
      'context menu Add Checklist adds a starter checklist sticky note',
      (tester) async {
        Map<String, dynamic>? latestData;

        final emptyScene = CanvasScene.fromJson({
          'schemaVersion': 1,
          'elements': <dynamic>[],
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CanvasEditor(
                canvasId: 'test-canvas',
                title: 'Test Canvas',
                data: emptyScene.toJson(),
                camera: const CanvasCamera(x: 0, y: 0, zoom: 1.0).toJson(),
                objects: const [],
                onChanged: (data) => latestData = data,
                onCameraChanged: (_) {},
                onOpenObject: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final canvasOrigin = tester.getTopLeft(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is OrbitCanvasPainter,
          ),
        );

        // Secondary click (right click) on empty canvas area
        await tester.tapAt(
          canvasOrigin + const Offset(200, 200),
          buttons: kSecondaryButton,
        );
        await tester.pumpAndSettle();

        // Find "Add Checklist" menu item
        expect(find.text('Add Checklist'), findsOneWidget);

        // Tap "Add Checklist"
        await tester.tap(find.text('Add Checklist'));
        await tester.pumpAndSettle();

        expect(latestData, isNotNull);
        final elements = latestData!['elements'] as List;
        expect(elements, isNotEmpty);
        final newSticky = elements.first;
        expect(newSticky['type'], 'sticky');
        expect(
          newSticky['text'],
          '# Tasks\n- [ ] Task 1\n- [ ] Task 2\n- [ ] Task 3',
        );
      },
    );
  });
}
