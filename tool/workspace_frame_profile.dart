// Native full-app profile. Only synthetic memory-backed files; no account restore
// or personal Vault access. Injected pointer events stay inside this binding.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';
import 'package:orbit_note/app/orbit_app.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/app/session_state.dart';
import 'package:orbit_note/app/google_cloud_controller.dart';
import 'package:orbit_note/app/collaboration_controller.dart';
import 'package:orbit_note/app/drive_sync_controller.dart';
import 'package:orbit_note/app/drive_vault_scheduler.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/application/sync/google_account.dart';
import 'package:orbit_note/infrastructure/sync/google_drive_api.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/object_codec.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/features/canvas/canvas_editor.dart';
import 'package:orbit_note/features/pdf/pdf_reader.dart';
import 'package:orbit_note/features/workspace/note_folder_explorer.dart';
import '../test/support/memory_store.dart';
import '../test/support/pdf_fixture.dart' show largeResearchPdf;
import 'performance/frame_statistics.dart';

class _MemoryCredentials implements GoogleCredentialStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> delete() async {}
}

class _OfflineAuth implements GoogleAccountAuth {
  @override
  bool get configured => false;
  @override
  GoogleAccount? get account => null;
  @override
  Future<GoogleAccount?> restore() async => null;
  @override
  Future<GoogleAccount> signIn({String? expectedSubject}) async =>
      throw StateError('Offline fixture');
  @override
  Future<String> accessToken({bool refresh = false}) async =>
      throw StateError('Offline fixture');
  @override
  Future<void> signOut() async {}
  @override
  void cancel() {}
}

Map<String, Object?> frameReport(List<ui.FrameTiming> frames) =>
    summarizeFrames([
      for (final f in frames)
        {
          'buildUs': f.buildDuration.inMicroseconds,
          'rasterUs': f.rasterDuration.inMicroseconds,
          'totalUs': f.totalSpan.inMicroseconds,
        },
    ], budgetUs: 1000000 / 60);
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();
  final report = args.single;
  final store = FolderMemoryStore(), codec = ObjectCodec();
  final repository = WorkspaceRepository(
    store: store,
    index: MemoryObjectIndex(),
  );
  await repository.initialize();
  for (var i = 0; i < 10000; i++) {
    final object = UniversalObject(
      id: 'fixture-$i',
      workspaceId: repository.workspaceId,
      typeId: 'orbit.note',
      title: 'Synthetic note $i',
      body: 'Synthetic body $i',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      properties: {'future': i},
    );
    store.files['Notes/fixture-$i.md'] = Uint8List.fromList(
      utf8.encode(codec.encode(object)),
    );
  }
  await codec.close();
  final client = http.Client(), auth = _OfflineAuth();
  final cloud = GoogleCloudController(
    auth,
    GoogleDriveApi(
      auth: auth,
      client: client,
      localMetadata: _MemoryCredentials(),
    ),
  );
  final container = ProviderContainer(
    overrides: [
      repositoryProvider.overrideWithValue(repository),
      googleCloudProvider.overrideWithValue(cloud),
      driveSyncStartupProvider.overrideWith((ref) {}),
      driveScheduleStartupProvider.overrideWith((ref) {}),
      collaborationStartupProvider.overrideWith((ref) {}),
    ],
  );
  final frames = <ui.FrameTiming>[];
  SchedulerBinding.instance.addTimingsCallback((values) {
    frames.addAll(values);
    if (frames.length > 5000) frames.removeRange(0, frames.length - 5000);
  });
  final errors = <String>[];
  FlutterError.onError = (e) {
    errors.add(e.exception.runtimeType.toString());
  };
  final stages = <Map<String, Object?>>[];
  final startup = Stopwatch()..start();
  var last = 0, startupGap = 0;
  final startupBeat = Timer.periodic(const Duration(milliseconds: 4), (_) {
    final now = startup.elapsedMicroseconds;
    if (now - last > startupGap) startupGap = now - last;
    last = now;
  });
  final c = container.read(workspaceProvider.notifier);
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const OrbitNoteApp(),
    ),
  );
  await c.initialize();
  final openMs = startup.elapsedMilliseconds;
  await Future<void>.delayed(const Duration(milliseconds: 600));
  startupBeat.cancel();
  stages.add({
    'name': 'cold-10000-file-workspace',
    'openMs': openMs,
    'wallMs': startup.elapsedMilliseconds,
    'maxLoopGapMs': startupGap / 1000,
    'rssMiB': ProcessInfo.currentRss / 1048576,
    ...frameReport(frames),
  });
  final note = (await c.create(
    'orbit.note',
    title: 'Synthetic long note',
    body: List.generate(
      2000,
      (i) => 'Paragraph $i with **bold** and café.\n\n',
    ).join(),
    open: false,
  ))!;
  final board = (await c.create(
    'orbit.canvas',
    title: 'Synthetic imported board',
    open: false,
    data: {
      'schemaVersion': 1,
      'future': true,
      'elements': [
        for (var i = 0; i < 10000; i++)
          {
            'id': 'shape-$i',
            'type': 'rectangle',
            'x': (i % 100) * 180.0,
            'y': (i ~/ 100) * 120.0,
            'width': 120.0,
            'height': 80.0,
            'text': 'Reference $i',
          },
        for (var i = 0; i < 100; i++)
          {
            'id': 'ink-$i',
            'type': 'ink',
            'x': 20.0,
            'y': 5 + i * 6.0,
            'width': 800.0,
            'height': 10.0,
            'strokeWidth': 3.0,
            'color': 0xff76c8aa,
            'penStyle': 'ballpoint',
            'points': [
              for (var p = 0; p < 1000; p++)
                {
                  'x': p * .8,
                  'y': 5 + math.sin(p * .03) * 4,
                  'pressure': .2 + (p % 100) / 125,
                  'timeMs': p,
                },
            ],
          },
      ],
    },
  ))!;
  final pdf = await repository.importAttachment(
    name: 'Synthetic research.pdf',
    bytes: largeResearchPdf(),
  );
  c.mergeRepositoryObjects();
  c.session.spellCheckEnabled = false;
  c.session.destination = OrbitDestination.notes;
  c.session.activeId = note.id;
  c.session.tabs = [note.id, board.id, pdf.id];
  c.notify();
  Future<void> saveReport() => File(report).writeAsString(
    jsonEncode({
      'synthetic': true,
      'fullApp': true,
      'storage': 'memory-backed ordinary files',
      'objects': c.objects.length,
      'errors': errors,
      'stages': stages,
    }),
  );
  Future<void> stage(String name, Future<void> Function() action) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    frames.clear();
    final clock = Stopwatch()..start();
    var previous = 0, gap = 0;
    final beat = Timer.periodic(const Duration(milliseconds: 4), (_) {
      final now = clock.elapsedMicroseconds;
      if (now - previous > gap) gap = now - previous;
      previous = now;
    });
    try {
      await action();
    } catch (e) {
      errors.add('$name:${e.runtimeType}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    beat.cancel();
    stages.add({
      'name': name,
      'wallMs': clock.elapsedMilliseconds,
      'maxLoopGapMs': gap / 1000,
      'rssMiB': ProcessInfo.currentRss / 1048576,
      ...frameReport(frames),
    });
    await saveReport();
  }

  await stage('workspace-status-60', () async {
    for (var i = 0; i < 60; i++) {
      c.notify();
      await pause(17);
    }
  });
  await stage('external-note-edits-30', () async {
    for (var i = 0; i < 30; i++) {
      c.edit(note.id, body: '${c.find(note.id)!.body}x');
      await pause(35);
    }
    await c.flushAll();
  });
  await stage('visible-note-typing-30', () async {
    final element = findElement(
      (w) => w is EditableText && w.controller.text.startsWith('Paragraph 0 '),
    );
    if (element is! StatefulElement || element.state is! EditableTextState) {
      throw StateError('Visible paragraph unavailable');
    }
    final field = element.widget as EditableText;
    field.focusNode.requestFocus();
    await pause(100);
    for (var i = 0; i < 30; i++) {
      final text = '${field.controller.text}x';
      (element.state as EditableTextState).userUpdateTextEditingValue(
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
        SelectionChangedCause.keyboard,
      );
      await pause(35);
    }
    await c.flushAll();
  });
  await stage('tabs-10', () async {
    for (var i = 0; i < 10; i++) {
      c.openObject(i.isEven ? board.id : note.id);
      await pause(100);
    }
  });
  await stage('canvas-cold-open', () async {
    c.openObject(board.id);
    await pause(800);
  });
  await stage('canvas-pan-120', () async {
    for (var i = 0; i < 120; i++) {
      scroll(CanvasEditor, Offset(i < 60 ? 2 : -2, 0));
      await pause(17);
    }
  });
  await stage('canvas-short-stylus-strokes-20', () async {
    for (var i = 0; i < 20; i++) {
      await stroke(CanvasEditor, 1000 + i, 8, PointerDeviceKind.stylus);
      await pause(35);
    }
    await c.flushAll();
  });
  await stage('canvas-long-stylus-mouse-strokes', () async {
    await stroke(CanvasEditor, 2000, 480, PointerDeviceKind.stylus);
    await stroke(CanvasEditor, 2001, 480, PointerDeviceKind.mouse);
    await c.flushAll();
  });
  final elements = c.find(board.id)!.data['elements'] as List;
  if (elements.length != 10122 || c.find(board.id)!.data['future'] != true) {
    errors.add('Canvas commit or unknown-field preservation failed');
  }
  await stage('pdf-cold-open-300-pages', () async {
    c.openObject(pdf.id);
    for (var i = 0; i < 600; i++) {
      final e = findElement((w) => w is PdfViewer);
      if (e != null && (e.widget as PdfViewer).controller?.isReady == true) {
        return;
      }
      await pause(25);
    }
    throw StateError('PDF timeout');
  });
  await stage('pdf-scroll-120', () async {
    for (var i = 0; i < 120; i++) {
      scroll(OrbitPdfReader, const Offset(0, 12));
      await pause(17);
    }
  });
  await stage('pdf-distant-pages', () async {
    final viewer = findElement((w) => w is PdfViewer)!.widget as PdfViewer;
    for (final page in [150, 300, 1, 299]) {
      await viewer.controller!.goToPage(
        pageNumber: page,
        duration: Duration.zero,
      );
      await pause(250);
    }
  });
  await stage('pdf-drawing', () async {
    await tapKey(const ValueKey('pdf-draw-toggle'));
    await pause(150);
    await stroke(OrbitPdfReader, 3000, 120, PointerDeviceKind.stylus);
    await c.flushAll();
    await tapKey(const ValueKey('pdf-draw-toggle'));
  });
  await stage('split-note-pdf', () async {
    c.openObject(note.id);
    c.openObject(pdf.id, secondary: true);
    await pause(400);
    for (var i = 0; i < 20; i++) {
      c.notify();
      await pause(35);
    }
    c.updateSession((s) => s.secondaryId = null);
  });
  await stage('settings-navigation', () async {
    for (var i = 0; i < 6; i++) {
      c.navigate(OrbitDestination.settings);
      await pause(120);
      c.openObject(note.id);
      await pause(120);
    }
  });
  await stage('explorer-scroll-120', () async {
    for (var i = 0; i < 120; i++) {
      scroll(NoteFolderExplorer, Offset(0, i < 60 ? 60 : -60));
      await pause(17);
    }
  });
  await stage('explorer-search', () async {
    final e = findElement(
      (w) => w is TextField && w.key == const ValueKey('explorer-filter'),
    );
    if (e == null) throw StateError('Explorer filter unavailable');
    final w = e.widget as TextField;
    for (final q in ['Synthetic', 'note 99', '', 'body 42', '']) {
      w.controller!.text = q;
      w.onChanged!(q);
      await pause(100);
    }
  });
  for (var pass = 0; pass < 5; pass++) {
    await stage('session-navigation-30-cycles-$pass', () async {
      for (var i = 0; i < 30; i++) {
        c.openObject(i.isEven ? note.id : board.id);
        await pause(80);
      }
    });
  }
  await stage('idle-5s', () async {
    await pause(5000);
  });
  await saveReport();
  c.cancelAllTimers();
  client.close();
  exit(errors.isEmpty ? 0 : 1);
}

Future<void> pause(int ms) => Future<void>.delayed(Duration(milliseconds: ms));
Element? findElement(bool Function(Widget) match) {
  Element? found;
  void visit(Element e) {
    if (found != null) return;
    if (match(e.widget)) {
      found = e;
      return;
    }
    e.visitChildElements(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildElements(visit);
  return found;
}

Offset center(Type type) {
  final e = findElement((w) => w.runtimeType == type);
  if (e == null) throw StateError('Missing surface');
  final box = e.findRenderObject() as RenderBox;
  return box.localToGlobal(box.size.center(Offset.zero));
}

void scroll(Type type, Offset delta) =>
    GestureBinding.instance.handlePointerEvent(
      PointerScrollEvent(position: center(type), scrollDelta: delta),
    );
Future<void> tapTooltip(String label) async {
  final e = findElement((w) => w is Tooltip && w.message == label);
  if (e == null) throw StateError('Missing control');
  final box = e.findRenderObject() as RenderBox;
  final p = box.localToGlobal(box.size.center(Offset.zero));
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: 9000, kind: PointerDeviceKind.mouse, position: p),
  );
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(pointer: 9000, kind: PointerDeviceKind.mouse, position: p),
  );
  await pause(30);
}

Future<void> stroke(
  Type type,
  int id,
  int samples,
  PointerDeviceKind kind,
) async {
  final p = center(type) - const Offset(100, 30);
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: id, kind: kind, position: p, pressure: .6),
  );
  for (var i = 1; i <= samples; i++) {
    GestureBinding.instance.handlePointerEvent(
      PointerMoveEvent(
        pointer: id,
        kind: kind,
        position: p + Offset(i * .35, math.sin(i * .1) * 20),
        pressure: .3 + (i % 50) / 100,
      ),
    );
    if (i % 4 == 0) await pause(8);
  }
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
      pointer: id,
      kind: kind,
      position: p + Offset(samples * .35, 0),
    ),
  );
  await pause(30);
}

Future<void> tapKey(Key key) async {
  final e = findElement((w) => w.key == key);
  if (e == null) throw StateError('Missing control');
  final box = e.findRenderObject() as RenderBox;
  final p = box.localToGlobal(box.size.center(Offset.zero));
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: 9001, kind: PointerDeviceKind.mouse, position: p),
  );
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(pointer: 9001, kind: PointerDeviceKind.mouse, position: p),
  );
  await pause(30);
}
