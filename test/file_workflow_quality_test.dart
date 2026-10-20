import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/domain/source_browser.dart';
import 'package:orbit_note/features/files/code_file_preview.dart';
import 'package:orbit_note/features/files/model_asset_viewer.dart';
import 'package:orbit_note/features/workspace/source_browser_dialog.dart';
import 'package:orbit_note/platform/source_folder.dart';

Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));
const triangle = 'v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n';
const quad = 'v 0 0 0\nv 1 0 0\nv 1 1 0\nv 0 1 0\nf 1 2 3\nf 1 3 4\n';

class QualitySourceFolder extends SourceFolder {
  QualitySourceFolder({this.count = 2}) : super('Synthetic source');
  final int count;
  final pending = <String, Completer<String>>{};
  @override
  Future<SourceFileListing> list() async => SourceFileListing([
    for (var i = 0; i < count; i++) SourceFileEntry('file-$i.cpp', 'cpp'),
  ]);
  @override
  Future<String> read(String path) async =>
      pending[path]?.future ?? '// $path\r\nint value = 1;\r\n';
}

void main() {
  Future<void> host(WidgetTester t, Widget child, {bool settle = true}) async {
    t.view.physicalSize = const Size(1200, 850);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: orbitDarkTheme(),
        home: Scaffold(body: child),
      ),
    );
    if (settle) {
      await t.pumpAndSettle();
    } else {
      await t.pump();
    }
  }

  CodeFilePreview code(String name, Future<Uint8List?> Function() load) =>
      CodeFilePreview(
        title: name,
        language: 'cpp',
        loadBytes: load,
        onOpenOriginal: () {},
      );
  Future<void> settleModel(WidgetTester t) async {
    for (
      var i = 0;
      i < 100 && find.textContaining('vertices ·').evaluate().isEmpty;
      i++
    ) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump();
    }
  }

  testWidgets('source preview retries a transient missing attachment', (
    t,
  ) async {
    var available = false;
    await host(
      t,
      code(
        'retry.cpp',
        () async => available ? bytes('int restored = 1;\r\n') : null,
      ),
    );
    expect(find.textContaining('unavailable'), findsOneWidget);
    available = true;
    expect(find.text('Retry'), findsOneWidget);
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      'int restored = 1;\r\n',
    );
  });

  testWidgets('source preview does not show old text beneath a new filename', (
    t,
  ) async {
    await host(t, code('old.cpp', () async => bytes('old source')));
    final gate = Completer<Uint8List?>();
    await t.pumpWidget(
      MaterialApp(
        theme: orbitDarkTheme(),
        home: Scaffold(body: code('new.cpp', () => gate.future)),
      ),
    );
    await t.pump();
    expect(find.byType(TextField), findsNothing);
    gate.complete(bytes('new source'));
    await t.pumpAndSettle();
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      'new source',
    );
  });

  testWidgets('late source completion cannot replace the latest preview', (
    t,
  ) async {
    final old = Completer<Uint8List?>();
    await host(t, code('old.cpp', () => old.future), settle: false);
    await host(t, code('new.cpp', () async => bytes('current source')));
    old.complete(bytes('stale source'));
    await t.pumpAndSettle();
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      'current source',
    );
  });

  testWidgets('model source changes retire old geometry while loading', (
    t,
  ) async {
    await host(
      t,
      ModelAssetViewer(
        name: 'old.obj',
        loadBytes: () async => bytes(triangle),
        onOpenOriginal: () {},
      ),
      settle: false,
    );
    await settleModel(t);
    expect(find.textContaining('3 vertices · 1 triangles'), findsOneWidget);
    final gate = Completer<Uint8List?>();
    await t.pumpWidget(
      MaterialApp(
        theme: orbitDarkTheme(),
        home: Scaffold(
          body: ModelAssetViewer(
            name: 'new.obj',
            loadBytes: () => gate.future,
            onOpenOriginal: () {},
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.textContaining('3 vertices ·'), findsNothing);
    await t.runAsync(() async {
      gate.complete(bytes(quad));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await settleModel(t);
    expect(find.textContaining('4 vertices · 2 triangles'), findsOneWidget);
  });

  testWidgets(
    'source evidence completion cannot label a different selected file',
    (t) async {
      final save = Completer<bool>();
      final folder = QualitySourceFolder();
      await host(
        t,
        SourceBrowserDialog(
          initialFolder: folder,
          onSaveExcerpt: (_) => save.future,
        ),
      );
      await t.tap(find.text('file-0.cpp'));
      await t.pumpAndSettle();
      await t.tap(find.text('Save evidence note'));
      await t.pump();
      await t.tap(find.text('file-1.cpp'));
      await t.pumpAndSettle();
      save.complete(true);
      await t.pumpAndSettle();
      expect(
        find.text('Source evidence saved as a linked project note.'),
        findsNothing,
      );
      expect(find.text('file-1.cpp'), findsWidgets);
    },
  );

  testWidgets(
    'source metadata bounds avoid loading oversized bytes and allow correction',
    (t) async {
      var reads = 0;
      Widget preview(int length) => CodeFilePreview(
        title: 'large.cpp',
        language: 'cpp',
        sourceVersion: 'unchanged-source',
        byteLength: length,
        loadBytes: () async {
          reads++;
          return bytes('small corrected source');
        },
        onOpenOriginal: () {},
      );
      await host(t, preview(1024 * 1024 + 1));
      expect(reads, 0);
      expect(find.textContaining('1 MiB'), findsOneWidget);
      await host(t, preview(22));
      expect(reads, 1);
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        'small corrected source',
      );
    },
  );

  testWidgets(
    'stable source versions keep selection through repeated parent rebuilds',
    (t) async {
      var reads = 0;
      for (var i = 0; i < 30; i++) {
        await host(
          t,
          CodeFilePreview(
            title: 'Renamed $i.cpp',
            language: 'cpp',
            sourceVersion: (1, 'same'),
            loadBytes: () async {
              reads++;
              return bytes('constant source');
            },
            onOpenOriginal: () {},
          ),
        );
        if (i == 0) {
          t.widget<TextField>(find.byType(TextField)).controller!.selection =
              const TextSelection(baseOffset: 1, extentOffset: 6);
        }
      }
      expect(reads, 1);
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.selection,
        const TextSelection(baseOffset: 1, extentOffset: 6),
      );
    },
  );

  testWidgets(
    'forty out-of-order source reads leave only the latest file visible',
    (t) async {
      final gates = List.generate(40, (_) => Completer<Uint8List?>());
      for (var i = 0; i < gates.length; i++) {
        final gate = gates[i];
        await host(
          t,
          CodeFilePreview(
            title: 'file-$i.cpp',
            language: 'cpp',
            sourceVersion: i,
            loadBytes: () => gate.future,
            onOpenOriginal: () {},
          ),
          settle: false,
        );
      }
      gates.last.complete(bytes('latest source'));
      await t.pumpAndSettle();
      for (var i = gates.length - 2; i >= 0; i--) {
        gates[i].complete(bytes('obsolete $i'));
      }
      await t.pumpAndSettle();
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        'latest source',
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('model retry does not return a Future from setState', (t) async {
    var available = false;
    await host(
      t,
      ModelAssetViewer(
        name: 'retry.obj',
        loadBytes: () async => available ? bytes(triangle) : null,
        onOpenOriginal: () {},
      ),
    );
    expect(find.text('Retry'), findsOneWidget);
    available = true;
    await t.tap(find.text('Retry'));
    await t.pump();
    await settleModel(t);
    expect(find.textContaining('3 vertices · 1 triangles'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'stable model versions preserve camera and avoid repeated decoding',
    (t) async {
      var reads = 0;
      Widget preview() => ModelAssetViewer(
        name: 'stable.obj',
        sourceVersion: 1,
        loadBytes: () async {
          reads++;
          return bytes(triangle);
        },
        onOpenOriginal: () {},
      );
      await host(t, preview(), settle: false);
      await settleModel(t);
      await t.tap(find.byTooltip('Zoom in'));
      await t.pumpAndSettle();
      for (var i = 0; i < 20; i++) {
        await host(t, preview());
      }
      expect(reads, 1);
      expect(find.text('120%'), findsOneWidget);
    },
  );

  testWidgets('source listings keep rows lazy and filter the final entry', (
    t,
  ) async {
    await host(
      t,
      SourceBrowserDialog(initialFolder: QualitySourceFolder(count: 5000)),
    );
    expect(find.byType(ListTile).evaluate().length, lessThan(50));
    expect(find.text('file-4999.cpp'), findsNothing);
    await t.enterText(
      find.widgetWithText(TextField, 'Filter file paths'),
      'file-4999.cpp',
    );
    await t.pumpAndSettle();
    final last = find.widgetWithText(ListTile, 'file-4999.cpp');
    expect(last, findsOneWidget);
    await t.tap(last);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('source-line-1')), findsOneWidget);
  });
}
