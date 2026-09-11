import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/domain/code_preview.dart';
import 'package:orbit_note/features/files/code_file_preview.dart';
import 'support/capture_ui.dart';

void main() {
  test('source detection and strict decoding preserve original text', () {
    for (final name in ['main.cpp', 'main.CXX', 'header.hpp']) {
      expect(previewLanguage(name), 'cpp');
    }
    expect(previewLanguage('main.py'), 'python');
    expect(previewLanguage('main.ts'), 'typescript');
    expect(previewLanguage('file.exe'), isNull);
    const source = '#include <iostream>\r\nint main() { return 0; }\r\n';
    expect(decodeCodePreview(Uint8List.fromList(utf8.encode(source))), source);
    expect(
      () => decodeCodePreview(Uint8List.fromList([0xff])),
      throwsFormatException,
    );
    expect(
      () => decodeCodePreview(Uint8List.fromList([0, 1])),
      throwsFormatException,
    );
    expect(
      () => decodeCodePreview(Uint8List(1024 * 1024 + 1)),
      throwsFormatException,
    );
  });
  testWidgets('C++ preview is read-only, highlighted and copies exact source', (
    tester,
  ) async {
    await prepareCapture(tester);
    const source = '#include <iostream>\r\nint main() { return 0; }\r\n';
    var clipboard = '';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: orbitDarkTheme(),
        home: Scaffold(
          body: CodeFilePreview(
            title: 'main.cpp',
            language: 'cpp',
            loadBytes: () async => Uint8List.fromList(utf8.encode(source)),
            onOpenOriginal: () => opened = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.readOnly, isTrue);
    final span = field.controller!.buildTextSpan(
      context: tester.element(find.byType(TextField)),
      withComposing: false,
    );
    expect(span.toPlainText(), source);
    expect(span.children!.length, greaterThan(1));
    await captureUi(tester, 'code-file-preview');
    await tester.tap(find.text('Copy code'));
    await tester.pump();
    expect(clipboard, source);
    await tester.tap(find.byTooltip('Open original externally'));
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
