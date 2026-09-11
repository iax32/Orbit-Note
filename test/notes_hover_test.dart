import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/features/notes/note_editor.dart';
import 'package:orbit_note/features/notes/note_format_toolbar.dart';

void main() {
  testWidgets(
    'Windows paragraph insertion appears on hover without changing Markdown',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var body = 'First\r\n\r\nSecond';
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitDarkTheme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => NoteEditor(
                noteId: 'note',
                title: 'Centered document',
                body: body,
                onTitleChanged: (_) {},
                onBodyChanged: (value) => update(() => body = value),
                linkTargets: const [],
                onOpenObject: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final insert = find.byTooltip('Insert paragraph here').first;
      Finder opacity() =>
          find.ancestor(of: insert, matching: find.byType(Opacity)).first;
      expect(tester.widget<Opacity>(opacity()).opacity, 0);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(insert));
      await tester.pump();
      expect(tester.widget<Opacity>(opacity()).opacity, 1);
      expect(body, 'First\r\n\r\nSecond');
      await tester.tap(insert);
      await tester.pumpAndSettle();
      final focused = find.byWidgetPredicate(
        (w) => w is TextField && w.focusNode?.hasFocus == true,
      );
      await tester.enterText(focused, 'Middle');
      await tester.pumpAndSettle();
      expect(body, 'First\r\n\r\nMiddle\r\n\r\nSecond');
      final toolbarSurface = find
          .descendant(
            of: find.byType(NoteFormatToolbar),
            matching: find.byType(Container),
          )
          .first;
      expect(tester.getSize(toolbarSurface).width, lessThan(1200));
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
