import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/orbit_theme.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/note_writing_appearance.dart';
import 'package:orbit_note/domain/writing_photo.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/native_workspace_store.dart';
import 'package:orbit_note/features/notes/note_writing_surface.dart';
import 'package:orbit_note/features/notes/writing_photo_import.dart';
import 'package:orbit_note/features/notes/writing_photo_layer.dart';
import 'support/memory_store.dart';

Future<Uint8List> png({int width = 100, int height = 80}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = Colors.blue,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return Uint8List.fromList(data!.buffer.asUint8List());
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List bytes;
  late WritingPhoto photo;
  setUpAll(() async {
    bytes = await png();
    photo = WritingPhoto(
      id: sha256.convert(bytes).toString(),
      name: 'Landscape',
    );
  });

  test('JPEG and WebP decode to small static PNG copies', () async {
    for (final extension in ['jpg', 'webp']) {
      final source = await File(
        'test/fixtures/writing/photo.$extension',
      ).readAsBytes();
      final converted = await normalizeWritingPhoto(source);
      validateWritingPhotoBytes(converted);
      expect(ByteData.sublistView(converted).getUint32(16), 24);
      expect(ByteData.sublistView(converted).getUint32(20), 16);
    }
  });

  test(
    'photo recipes bound fields and preserve unfamiliar nested preferences',
    () {
      expect(
        WritingPhoto.fromData({'version': 1, 'id': '../../secret'}),
        isNull,
      );
      expect(WritingPhoto.fromData({'version': 2, 'id': photo.id}), isNull);
      final recipe = WritingPhoto.fromData({
        ...photo.toData(),
        'opacity': double.infinity,
        'x': 4,
        'y': 'bad',
      })!;
      expect(recipe.opacity, .65);
      expect(recipe.x, 0);
      final original = {
        'version': 1,
        'photo': {
          ...photo.toData(),
          'unknown': [1, 'keep'],
        },
      };
      final changed = NoteWritingAppearance.fromData(
        original,
      ).copyWith(design: WritingDesign.crt).toData(original: original);
      expect(changed['photo']['unknown'], [1, 'keep']);
      final future = {
        'version': 1,
        'photo': {'version': 9, 'id': photo.id, 'unknown': true},
      };
      expect(
        NoteWritingAppearance.fromData(
          future,
        ).toData(original: future)['photo'],
        future['photo'],
      );
      expect(
        NoteWritingAppearance.fromData(future)
            .copyWith(removePhoto: true)
            .toData(original: future)
            .containsKey('photo'),
        isFalse,
      );
    },
  );
  test(
    'normalization bounds dimensions, rejects bad data and handles picker cancel',
    () async {
      final wide = await png(width: 2400, height: 30);
      final normalized = await normalizeWritingPhoto(wide);
      validateWritingPhotoBytes(normalized);
      expect(ByteData.sublistView(normalized).getUint32(16), 1600);
      expect(ByteData.sublistView(normalized).getUint32(20), 20);
      expect(await pickWritingPhoto(picker: () async => null), isNull);
      final imported = (await pickWritingPhoto(
        picker: () async => XFile.fromData(bytes, name: 'sample.png'),
      ))!;
      expect(imported.photo.id, sha256.convert(imported.bytes).toString());
      await expectLater(
        normalizeWritingPhoto(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
      await expectLater(
        normalizeWritingPhoto(Uint8List(16 * 1024 * 1024 + 1)),
        throwsFormatException,
      );
      final huge = Uint8List.fromList(bytes);
      ByteData.sublistView(huge).setUint32(16, 20000);
      await expectLater(normalizeWritingPhoto(huge), throwsFormatException);
    },
  );
  test(
    'photo intensity protects normal, secondary and link ink at both extremes',
    () {
      for (final base in [ThemeData.dark(), ThemeData.light()]) {
        for (final design in WritingDesign.values) {
          final theme = writingSurfaceTheme(
            NoteWritingAppearance(design: design),
            base,
          );
          final amount = readablePhotoOpacity(theme);
          for (final color in [
            theme.colorScheme.onSurface,
            theme.colorScheme.onSurfaceVariant,
            theme.colorScheme.primary,
          ]) {
            final target = OrbitContrast.ratio(
              color,
              theme.colorScheme.surface,
            ).clamp(1.0, 4.5);
            for (final extreme in [Colors.white, Colors.black]) {
              final background = Color.alphaBlend(
                extreme.withValues(alpha: amount),
                theme.colorScheme.surface,
              );
              expect(
                OrbitContrast.ratio(color, background),
                greaterThanOrEqualTo(target - .00001),
                reason: design.name,
              );
            }
          }
        }
      }
    },
  );
  test(
    'cache writes are private, deduplicated, guarded, and fail without touching notes',
    () async {
      final store = MemoryStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      await repo.initialize();
      try {
        await repo.create(
          typeId: 'orbit.note',
          title: 'Keep',
          body: 'Exact authored text',
        );
        final before = {
          for (final e in store.files.entries)
            e.key: Uint8List.fromList(e.value),
        };
        final id = await repo.saveDeviceWritingPhoto(
          bytes,
          expectedWorkspace: repo.workspaceId,
        );
        expect(id, photo.id);
        expect(
          await repo.saveDeviceWritingPhoto(
            bytes,
            expectedWorkspace: repo.workspaceId,
          ),
          id,
        );
        expect(
          await repo.readDeviceWritingPhoto(
            id,
            expectedWorkspace: repo.workspaceId,
          ),
          bytes,
        );
        for (final entry in before.entries) {
          expect(store.files[entry.key], entry.value);
        }
        expect(store.files.keys.where((p) => !before.containsKey(p)).toList(), [
          '.orbit/device/writing-backgrounds/$id.png',
        ]);
        await expectLater(
          repo.saveDeviceWritingPhoto(bytes, expectedWorkspace: 'stale'),
          throwsException,
        );
        await expectLater(
          repo.readDeviceWritingPhoto(
            '../file',
            expectedWorkspace: repo.workspaceId,
          ),
          throwsException,
        );
        final damaged = Uint8List.fromList(bytes)..[32] ^= 1;
        store.files['.orbit/device/writing-backgrounds/$id.png'] = damaged;
        await expectLater(
          repo.readDeviceWritingPhoto(id, expectedWorkspace: repo.workspaceId),
          throwsException,
        );
        store.failWrites = true;
        final other = await png(width: 70);
        await expectLater(
          repo.saveDeviceWritingPhoto(
            other,
            expectedWorkspace: repo.workspaceId,
          ),
          throwsException,
        );
        for (final entry in before.entries) {
          expect(store.files[entry.key], entry.value);
        }
      } finally {
        await repo.close();
      }
    },
  );
  test(
    'native photo and pane settings survive reopening; oversized cache is refused',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'orbit-writing-photo-',
      );
      final repo = WorkspaceRepository(
        store: NativeWorkspaceStore(),
        index: MemoryObjectIndex(),
      );
      try {
        await repo.initialize(path: folder.path);
        final owner = repo.workspaceId;
        final id = await repo.saveDeviceWritingPhoto(
          bytes,
          expectedWorkspace: owner,
        );
        await repo.writeDeviceSettings({
          'noteViews': {
            'one': {
              'writingAppearance': NoteWritingAppearance(photo: photo).toData(),
            },
          },
        });
        await repo.close();
        await repo.initialize(path: folder.path);
        expect(
          await repo.readDeviceWritingPhoto(id, expectedWorkspace: owner),
          bytes,
        );
        expect(
          (await repo
              .readDeviceSettings())['noteViews']['one']['writingAppearance']['photo']['id'],
          id,
        );
        await File(
          '${folder.path}/.orbit/device/writing-backgrounds/$id.png',
        ).writeAsBytes(Uint8List(WritingPhoto.maxBytes + 1));
        await expectLater(
          repo.readDeviceWritingPhoto(id, expectedWorkspace: owner),
          throwsException,
        );
        await expectLater(
          repo.saveDeviceWritingPhoto(bytes, expectedWorkspace: owner),
          throwsException,
        );
      } finally {
        await repo.close();
        await folder.delete(recursive: true);
      }
    },
  );

  testWidgets(
    'preview and cancel never save; failed apply retains the picker',
    (tester) async {
      var saves = 0;
      NoteWritingAppearance? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showWritingAppearance(
                    context,
                    const NoteWritingAppearance(),
                    pickPhoto: () async => ImportedWritingPhoto(photo, bytes),
                    savePhoto: (_) async {
                      saves++;
                      throw StateError('No space');
                    },
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final pick = find.byKey(const ValueKey('writing-pick-photo'));
      await tester.ensureVisible(pick);
      await tester.tap(pick);
      await tester.pumpAndSettle();
      expect(saves, 0);
      await tester.tap(find.byKey(const ValueKey('writing-apply')));
      await tester.pumpAndSettle();
      expect(saves, 1);
      expect(find.textContaining('No space'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'photo controls and remove apply small recipes, never image data',
    (tester) async {
      NoteWritingAppearance? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showWritingAppearance(
                    context,
                    NoteWritingAppearance(photo: photo),
                    photoLoader: (_) async => bytes,
                    savePhoto: (_) async => photo.id,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final remove = find.byKey(const ValueKey('writing-remove-photo'));
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('writing-apply')));
      await tester.pumpAndSettle();
      expect(result!.photo, isNull);
      expect(
        jsonEncode(
          result!.toData(
            original: NoteWritingAppearance(photo: photo).toData(),
          ),
        ).contains('photo'),
        isFalse,
      );
    },
  );
  testWidgets(
    'loader caches bytes during typing and refuses a stale owner response',
    (tester) async {
      final pending = Completer<Uint8List?>();
      var reads = 0;
      Future<Uint8List?> load(String _) {
        reads++;
        return pending.future;
      }

      Widget surface(Object owner, String text) => MaterialApp(
        home: Scaffold(
          body: NoteWritingSurface(
            appearance: NoteWritingAppearance(photo: photo),
            photoOwner: owner,
            photoLoader: owner == 'old' ? load : (_) async => null,
            child: Text(text),
          ),
        ),
      );
      await tester.pumpWidget(surface('old', 'Before'));
      await tester.pump();
      await tester.pumpWidget(surface('old', 'Typing'));
      await tester.pump();
      expect(reads, 1);
      await tester.pumpWidget(surface('new', 'New Vault'));
      await tester.pumpAndSettle();
      pending.complete(bytes);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.textContaining('Photo unavailable'), findsOneWidget);
    },
  );
  testWidgets('missing backgrounds retry and high contrast suppresses photos', (
    tester,
  ) async {
    var missing = true;
    Widget surface(bool high) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(highContrast: high),
        child: Scaffold(
          body: NoteWritingSurface(
            appearance: NoteWritingAppearance(photo: photo),
            photoLoader: (_) async => missing ? null : bytes,
            child: const Text('Keep writing'),
          ),
        ),
      ),
    );
    await tester.pumpWidget(surface(false));
    await tester.pumpAndSettle();
    expect(find.textContaining('Photo unavailable'), findsOneWidget);
    missing = false;
    await tester.tap(find.text('Retry background'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    await tester.pumpWidget(surface(true));
    await tester.pumpAndSettle();
    expect(find.byType(WritingPhotoLayer), findsNothing);
    expect(find.text('Keep writing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('photo picker stays usable at narrow widths and enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showWritingAppearance(
                  context,
                  NoteWritingAppearance(photo: photo),
                  photoLoader: (_) async => bytes,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final slider = find.byKey(const ValueKey('writing-photo-intensity'));
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
