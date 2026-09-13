import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/workspace_controller.dart';
import 'package:orbit_note/application/workspace_repository.dart';
import 'package:orbit_note/domain/search_text.dart';
import 'package:orbit_note/features/workspace/workspace_views.dart';
import 'package:orbit_note/infrastructure/storage/memory_object_index.dart';
import 'package:orbit_note/infrastructure/storage/workspace_store.dart';
import 'support/memory_store.dart';

class TestFolderStore extends MemoryStore implements WorkspaceFolderStore {
  final folders = <String>['Notes'];
  @override
  Future<List<String>> listFolders() async => List.of(folders);
  @override
  Future<void> createFolder(String path) async {
    if (!folders.contains(path)) {
      folders.add(path);
    }
  }

  @override
  Future<void> deleteFolder(String path) async {
    folders.remove(path);
    folders.removeWhere((f) => f.startsWith('$path/'));
    files.removeWhere((k, _) => k.startsWith('$path/'));
  }

  @override
  Future<void> movePath(
    String source,
    String target,
    Map<String, FileReplacement> replacements,
  ) async {
    final content = files.remove(source);
    if (content != null) {
      files[target] = content;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Reverse Engineering, Binary Analysis & Security Research Workflows', () {
    late ProviderContainer container;
    late WorkspaceController controller;
    late TestFolderStore store;

    setUp(() async {
      store = TestFolderStore();
      final repo = WorkspaceRepository(
        store: store,
        index: MemoryObjectIndex(),
      );
      container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      container.read(workspaceProvider);
      controller = container.read(workspaceProvider.notifier);
      for (var i = 0; i < 100 && controller.loading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
    });

    tearDown(() async {
      await controller.flushAll();
      container.dispose();
    });

    test(
      'createReverseEngineeringProject scaffolds complete project and views',
      () async {
        final overview = await controller.createReverseEngineeringProject(
          'GameClient',
          architecture: 'x86-64',
          format: 'PE',
          targetPlatform: 'Windows 11',
          targetVersion: '1.4.2',
        );

        expect(overview, isNotNull);
        expect(overview!.title, 'GameClient Overview');
        expect(overview.properties['target'], 'GameClient');
        expect(overview.properties['architecture'], 'x86-64');
        expect(overview.properties['format'], 'PE');
        expect(overview.properties['platform'], 'Windows 11');
        expect(overview.properties['version'], '1.4.2');
        expect(overview.properties['isTargetOverview'], true);

        // Verify folder hierarchy
        expect(store.folders, contains('Reverse Engineering/GameClient'));
        expect(
          store.folders,
          contains('Reverse Engineering/GameClient/Functions'),
        );
        expect(
          store.folders,
          contains('Reverse Engineering/GameClient/Structures'),
        );
        expect(
          store.folders,
          contains('Reverse Engineering/GameClient/Sessions'),
        );
        expect(
          store.folders,
          contains('Reverse Engineering/GameClient/Diagrams'),
        );
        expect(store.folders, contains('Reverse Engineering/GameClient/Files'));

        // Verify canvases created
        final canvases = controller.ofType('orbit.canvas');
        expect(canvases.any((c) => c.title == 'Call Flow'), isTrue);
        expect(canvases.any((c) => c.title == 'Object Relationships'), isTrue);

        // Verify views created
        final views = controller.ofType('orbit.view');
        expect(
          views.any(
            (v) =>
                v.title == 'GameClient Dashboard' &&
                v.properties['viewType'] == 're_dashboard',
          ),
          isTrue,
        );
        expect(
          views.any(
            (v) =>
                v.title == 'GameClient Functions' &&
                v.properties['viewType'] == 'functions',
          ),
          isTrue,
        );
        expect(
          views.any(
            (v) =>
                v.title == 'GameClient Hypotheses' &&
                v.properties['preset'] == 'hypotheses',
          ),
          isTrue,
        );
        expect(
          views.any(
            (v) =>
                v.title == 'GameClient Investigation Tasks' &&
                v.properties['viewType'] == 'tasks',
          ),
          isTrue,
        );

        // Verify starter tasks
        final tasks = controller.ofType('orbit.task');
        expect(tasks.any((t) => t.title.contains('entry point')), isTrue);
      },
    );

    test(
      'createGameInternalsProject scaffolds game internals folders and canvases',
      () async {
        final overview = await controller.createGameInternalsProject(
          'EldenRealm',
          engine: 'Unreal Engine 5',
          architecture: 'x86-64',
        );

        expect(overview, isNotNull);
        expect(overview!.title, 'EldenRealm Internals Overview');
        expect(overview.properties['target'], 'EldenRealm');

        expect(store.folders, contains('Game Internals/EldenRealm'));
        expect(
          store.folders,
          contains('Game Internals/EldenRealm/Game Systems'),
        );

        final canvases = controller.ofType('orbit.canvas');
        expect(canvases.any((c) => c.title == 'Rendering Pipeline'), isTrue);
        expect(canvases.any((c) => c.title == 'Architecture Map'), isTrue);
      },
    );

    test(
      'createMalwareAnalysisProject scaffolds defensive lab triage and IOC views',
      () async {
        final triage = await controller.createMalwareAnalysisProject(
          'Trojan.Dropper.01',
          sha256:
              'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        );

        expect(triage, isNotNull);
        expect(triage!.title, 'Trojan.Dropper.01 Triage & Overview');
        expect(triage.properties['target'], 'Trojan.Dropper.01');

        expect(
          store.folders,
          contains('Malware Analysis/Trojan.Dropper.01/Indicators'),
        );

        final views = controller.ofType('orbit.view');
        expect(views.any((v) => v.properties['viewType'] == 'iocs'), isTrue);

        final canvases = controller.ofType('orbit.canvas');
        expect(canvases.any((c) => c.title == 'Process Tree'), isTrue);
      },
    );

    test(
      'createFunctionDoc creates canonical note with address and module',
      () async {
        final fn = await controller.createFunctionDoc(
          folder: 'Reverse Engineering/Target/Functions',
          name: 'ProcessPacket',
          address: '0x140024B20',
          rva: '0x24B20',
          module: 'game.exe',
          purpose: 'Validates and unpacks network telemetry packet',
          status: 'Confirmed',
          confidence: 'Verified',
          target: 'Target',
        );

        expect(fn, isNotNull);
        expect(fn!.title, 'ProcessPacket');
        expect(fn.properties['category'], 'Function');
        expect(fn.properties['address'], '0x140024B20');
        expect(fn.properties['rva'], '0x24B20');
        expect(fn.properties['module'], 'game.exe');
        expect(fn.properties['status'], 'Confirmed');
        expect(fn.properties['confidence'], 'Verified');
        expect(fn.body, contains('0x140024B20'));
        expect(fn.body, contains('game.exe'));
      },
    );

    test(
      'createStructureDoc generates proper memory layout structure',
      () async {
        final st = await controller.createStructureDoc(
          folder: 'Reverse Engineering/Target/Structures',
          name: 'PlayerEntity',
          size: '0x140',
          module: 'engine.dll',
          confidence: 'High',
          target: 'Target',
        );

        expect(st, isNotNull);
        expect(st!.title, 'PlayerEntity');
        expect(st.properties['category'], 'Structure');
        expect(st.properties['size'], '0x140');
        expect(st.body, contains('| `+0x00` |'));
        expect(st.body, contains('vtable'));
      },
    );

    test(
      'createHypothesisDoc and createFindingDoc preserve status and confidence',
      () async {
        final hyp = await controller.createHypothesisDoc(
          folder: 'Reverse Engineering/Target/Hypotheses',
          title: 'CRC Check in UpdateLoop',
          target: 'Target',
          status: 'Testing',
          confidence: 'High',
        );

        expect(hyp, isNotNull);
        expect(hyp!.properties['category'], 'Hypothesis');
        expect(hyp.properties['status'], 'Testing');
        expect(hyp.properties['confidence'], 'High');

        final finding = await controller.createFindingDoc(
          folder: 'Reverse Engineering/Target/Findings',
          title: 'Hardcoded Encryption Key',
          target: 'Target',
          category: 'Cryptography',
          status: 'Confirmed',
          confidence: 'Verified',
        );

        expect(finding, isNotNull);
        expect(finding!.properties['category'], 'Finding');
        expect(finding.properties['status'], 'Confirmed');
        expect(finding.properties['confidence'], 'Verified');
      },
    );

    test('createIocDoc stores indicator types cleanly', () async {
      final ioc = await controller.createIocDoc(
        folder: 'Reverse Engineering/Target/Indicators',
        value: '198.51.100.45',
        type: 'IP Address',
        confidence: 'Verified',
        context: 'C2 callback IP',
      );

      expect(ioc, isNotNull);
      expect(ioc!.properties['category'], 'Indicator');
      expect(ioc.properties['iocType'], 'IP Address');
      expect(ioc.properties['value'], '198.51.100.45');
      expect(ioc.properties['confidence'], 'Verified');
    });

    test('formatAddress and formatModuleOffset helper functions', () {
      expect(formatAddress(null), '0x0');
      expect(formatAddress(''), '0x0');
      expect(formatAddress('0x140012340'), '0x140012340');
      expect(formatAddress('140012340'), '0x140012340');
      expect(
        formatModuleOffset('game.exe', '0x140024B20'),
        'game.exe+0x140024B20',
      );
      expect(formatModuleOffset('', '0x1000'), 'target.exe+0x1000');
    });

    test(
      'calculateAttachmentSha256 calculates and caches local file hash',
      () async {
        final fileContent = Uint8List.fromList(
          utf8.encode('Test executable payload content'),
        );
        final fileObj = await controller.repository.importAttachment(
          name: 'sample.bin',
          bytes: fileContent,
        );
        expect(fileObj, isNotNull);

        final sha = await controller.calculateAttachmentSha256(fileObj);
        expect(sha, isNotNull);
        expect(sha!.length, 64); // Valid SHA-256 hex length

        // Calling again should return cached hash without reading attachment
        final cachedObj = controller.find(fileObj.id);
        expect(cachedObj!.properties['sha256'], sha);
        expect(cachedObj.properties['md5'], isNotNull);
      },
    );

    test(
      'importFunctionsFromCsv parses CSV lines into canonical function notes',
      () async {
        const csv = '''Name,Address,Module,Purpose,Status,Confidence
InitGraphics,0x140001000,renderer.dll,Initializes Direct3D 12 device,Confirmed,Verified
HandleCollision,0x140018500,physics.dll,AABB vs OBB collision check,Investigating,Medium
RenderHUD,0x140020A00,ui.dll,Draws health bar and crosshair,Partially Understood,Low''';

        final imported = await controller.importFunctionsFromCsv(
          csv,
          folder: 'Reverse Engineering/Target/Functions',
          target: 'Target',
        );

        expect(imported, 3);
        final functions = controller.activeObjects
            .where((o) => o.properties['category'] == 'Function')
            .toList();
        expect(functions.length, 3);
        expect(
          functions.any(
            (f) =>
                f.title == 'InitGraphics' &&
                f.properties['address'] == '0x140001000',
          ),
          isTrue,
        );
        expect(
          functions.any(
            (f) =>
                f.title == 'HandleCollision' &&
                f.properties['status'] == 'Investigating',
          ),
          isTrue,
        );
      },
    );

    test(
      'importFunctionsFromJson parses JSON objects into canonical function notes',
      () async {
        const jsonStr = '''[
        {"name": "DecryptPayload", "address": "0x140089200", "module": "core.dll", "purpose": "RC4 decrypt", "status": "Confirmed", "confidence": "High"},
        {"name": "HookAPI", "address": "0x140089A00", "module": "core.dll", "purpose": "Inline detour", "status": "Investigating", "confidence": "Medium"}
      ]''';

        final imported = await controller.importFunctionsFromJson(
          jsonStr,
          folder: 'Reverse Engineering/Target/Functions',
          target: 'Target',
        );

        expect(imported, 2);
        final functions = controller.activeObjects
            .where((o) => o.properties['category'] == 'Function')
            .toList();
        expect(functions.length, 2);
        expect(
          functions.any(
            (f) =>
                f.title == 'DecryptPayload' &&
                f.properties['purpose'] == 'RC4 decrypt',
          ),
          isTrue,
        );
      },
    );

    test('searchRank prioritizes exact address and RVA matches', () async {
      final fn = await controller.createFunctionDoc(
        folder: 'Reverse Engineering/Target/Functions',
        name: 'PlayerMovement',
        address: '0x140034B10',
        rva: '0x34B10',
      );
      expect(fn, isNotNull);

      // Search by exact address
      final rankAddr = searchRank(fn!, '0x140034b10');
      expect(rankAddr, 0);

      // Search by exact RVA without prefix
      final rankRva = searchRank(fn, '0x34b10');
      expect(rankRva, 0);
    });

    test(
      'KanbanPreset hypotheses and functions have expected column definitions',
      () {
        final hypPreset = KanbanPreset.hypotheses;
        expect(hypPreset.id, 'hypotheses');
        expect(hypPreset.columns.map((c) => c.$1), [
          'open',
          'testing',
          'supported',
          'confirmed',
          'rejected',
        ]);

        final fnPreset = KanbanPreset.functions;
        expect(fnPreset.id, 'functions');
        expect(fnPreset.columns.map((c) => c.$1), [
          'unknown',
          'interesting',
          'investigating',
          'partial',
          'confirmed',
        ]);

        expect(KanbanPreset.fromId('hypotheses'), KanbanPreset.hypotheses);
        expect(KanbanPreset.fromId('functions'), KanbanPreset.functions);
      },
    );
  });
}
