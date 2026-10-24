import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orbit_note/app/collaboration_controller.dart';
import 'package:orbit_note/domain/collaboration.dart';
import 'package:orbit_note/features/workspace/shared_server_setup.dart';
import 'package:orbit_note/infrastructure/collaboration/server.dart';
import 'canvas_shared_presence_test.dart' show CanvasSessions;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CanvasSessions f;
  setUp(() async {
    HttpOverrides.global = null;
    f = CanvasSessions();
    await f.open();
  });
  tearDown(() => f.close());

  Future<void> restart({String? journal}) async {
    final port = f.endpoint.port;
    await f.server.close();
    if (journal != null) {
      await File(
        '${f.directory.path}/events.jsonl',
      ).writeAsString(journal, flush: true);
    }
    f.server = CollaborationServer(f.directory, 'synthetic-owner');
    await f.server.start(port: port);
  }

  test(
    'server restart safely resets old cursors and continues unchanged documents',
    () async {
      final before = await f.first.inspectRoom(
        f.endpoint,
        f.room,
        f.firstToken,
      );
      await restart();
      final after = await f.first.request(
        f.endpoint,
        f.firstToken,
        'GET',
        '/v1/rooms/${f.room}/state?since=99999&epoch=${before['epoch']}',
      );
      expect(after['epoch'], isNot(before['epoch']));
      expect(after['documents'], contains(f.id));
      await f.first.pump();
      await f.second.pump();
      f.edit(f.firstWorkspace, 0, 77);
      await f.first.pump();
      await f.second.pump();
      expect(f.first.conflicts, isEmpty);
      expect(f.second.conflicts, isEmpty);
      expect(f.secondWorkspace.find(f.id)!.data['elements'][0]['x'], 77);
    },
  );

  test(
    'restored older host requires review before publishing queued local edits',
    () async {
      final journal = await File(
        '${f.directory.path}/events.jsonl',
      ).readAsString();
      f.edit(f.firstWorkspace, 0, 20);
      await f.first.pump();
      await f.second.pump();
      f.edit(f.secondWorkspace, 0, 30);
      await f.secondWorkspace.flush(f.id);
      await restart(journal: journal);
      await f.second.pump();
      expect(f.second.retryAt, null);
      expect(f.second.conflicts[f.id], contains('host restarted'));
      expect(f.second.canReviewCanvas(f.id), false);
      expect(f.secondWorkspace.find(f.id)!.data['elements'][0]['x'], 30);
      final state = await f.first.inspectRoom(f.endpoint, f.room, f.firstToken);
      expect(
        state['documents'][f.id]['snapshot']['data']['elements'][0]['x'],
        0,
      );
      await f.second.adoptServer(f.id);
      expect(f.second.conflicts, isEmpty);
      expect(f.secondWorkspace.find(f.id)!.data['elements'][0]['x'], 0);
    },
  );

  test(
    'uncertain edit acknowledgement is preserved for review across a restart',
    () async {
      f.transport.loseNextEdit = true;
      f.edit(f.firstWorkspace, 0, 42);
      await f.first.pump();
      expect(f.first.pendingChanges, 1);
      f.edit(f.firstWorkspace, 0, 43);
      await f.firstWorkspace.flush(f.id);
      await restart();
      await f.first.resumeForeground();
      expect(f.first.conflicts, contains(f.id));
      expect(f.firstWorkspace.find(f.id)!.data['elements'][0]['x'], 43);
      final state = await f.second.inspectRoom(
        f.endpoint,
        f.room,
        f.secondToken,
      );
      expect(
        state['documents'][f.id]['snapshot']['data']['elements'][0]['x'],
        42,
      );
    },
  );

  test(
    'documents missing from a restored snapshot never disappear locally',
    () async {
      final events =
          (await File('${f.directory.path}/events.jsonl').readAsLines())
              .map((line) => jsonDecode(line) as Map<String, dynamic>)
              .toList();
      final create = events.firstWhere((e) => e['kind'] == 'create');
      (create['state']['documents'] as Map).remove(f.id);
      await restart(journal: '${events.map(jsonEncode).join('\n')}\n');
      await f.second.pump();
      expect(f.second.conflicts[f.id], contains('absent'));
      expect(f.secondWorkspace.find(f.id), isNotNull);
      expect(f.second.retryAt, null);
    },
  );

  test(
    'foreground recovery does not repeatedly retry revoked capabilities',
    () async {
      await f.first.revoke(f.secondToken);
      await f.second.pump();
      expect(f.second.accessBlocked, true);
      await f.second.resumeForeground();
      expect(f.second.accessBlocked, true);
      expect(f.second.retryAt, null);
      expect(f.second.status, contains('Access denied'));
    },
  );

  test(
    'foreground request during a shared poll performs one follow-up check',
    () async {
      var reads = 0;
      final entered = Completer<void>(), release = Completer<void>();
      final transport = http.Client();
      final controller = CollaborationController(
        f.secondWorkspace,
        MockClient((request) async {
          reads++;
          if (reads == 2) {
            entered.complete();
            await release.future;
          }
          return transport.get(request.url, headers: request.headers);
        }),
        automaticPolling: false,
      );
      try {
        await controller.connect(f.endpoint, f.room, f.secondToken);
        final poll = controller.pump();
        await entered.future;
        await controller.resumeForeground();
        await controller.resumeForeground();
        release.complete();
        await poll;
        for (var i = 0; i < 100 && (reads < 3 || controller.busy); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(reads, 3);
        expect(controller.retryAt, null);
      } finally {
        controller.dispose();
        transport.close();
      }
    },
  );

  test(
    'owner setup diagnoses the wrong key without exposing its contents',
    () async {
      await expectLater(
        f.first.testServer(f.endpoint, 'private-wrong-key'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('owner-key.secret'),
              isNot(contains('private-wrong-key')),
            ),
          ),
        ),
      );
    },
  );

  test(
    'host configuration accepts only a domain, never injected proxy directives',
    () {
      expect(sharedServerHostname(' Notes.Example.com '), 'notes.example.com');
      for (final value in [
        'localhost',
        '127.0.0.1',
        'https://notes.example.com',
        'notes.example.com:443',
        'notes.example.com/path',
        'host..com',
        '-host.example.com',
        'host.example.com {\nreverse_proxy evil:80\n}',
        'host.example.com\nother.example.com',
      ]) {
        expect(sharedServerHostname(value), null, reason: value);
      }
    },
  );

  test(
    'legacy host version rollback or reuse cannot overwrite local documents',
    () async {
      for (final rollback in [false, true]) {
        var calls = 0, writes = 0;
        final baseline = collaborationSnapshot(f.secondWorkspace.find(f.id)!);
        final changed =
            jsonDecode(jsonEncode(baseline)) as Map<String, dynamic>;
        changed['data']['elements'][0]['x'] = 99;
        final controller = CollaborationController(
          f.secondWorkspace,
          MockClient((request) async {
            if (request.method == 'POST') writes++;
            calls++;
            return http.Response(
              jsonEncode({
                'protocol': 1,
                'workspaceId': f.secondRepo.workspaceId,
                'role': 'editor',
                'sequence': calls == 1 ? 3 : (rollback ? 2 : 3),
                'documents': {
                  f.id: {
                    'version': calls == 1 ? 3 : (rollback ? 2 : 3),
                    'snapshot': calls == 1 ? baseline : changed,
                  },
                },
                'peers': [],
              }),
              200,
            );
          }),
          automaticPolling: false,
        );
        try {
          await controller.connect(f.endpoint, f.room, f.secondToken);
          await controller.pump();
          expect(controller.conflicts, contains(f.id));
          expect(writes, 0);
          expect(f.secondWorkspace.find(f.id)!.data['elements'][0]['x'], 0);
        } finally {
          controller.dispose();
        }
      }
    },
  );

  test(
    'changed server identity suspends automatic requests without losing work',
    () async {
      var calls = 0;
      final controller = CollaborationController(
        f.secondWorkspace,
        MockClient((_) async {
          calls++;
          return http.Response(
            jsonEncode({
              'protocol': calls == 1 ? 1 : 99,
              'workspaceId': f.secondRepo.workspaceId,
              'role': 'editor',
              'sequence': 1,
              'documents': {},
              'peers': [],
            }),
            200,
          );
        }),
        automaticPolling: false,
      );
      try {
        await controller.connect(f.endpoint, f.room, f.secondToken);
        await controller.pump();
        expect(controller.accessBlocked, true);
        expect(controller.status, contains('identity or protocol changed'));
        await controller.pump();
        await controller.resumeForeground();
        expect(calls, 2);
        expect(f.secondWorkspace.find(f.id), isNotNull);
      } finally {
        controller.dispose();
      }
    },
  );

  test('server role refresh precedes publication of pending edits', () async {
    var calls = 0, writes = 0;
    final baseline = collaborationSnapshot(f.secondWorkspace.find(f.id)!);
    final controller = CollaborationController(
      f.secondWorkspace,
      MockClient((request) async {
        calls++;
        if (request.method == 'POST') writes++;
        return http.Response(
          jsonEncode({
            'protocol': 1,
            'workspaceId': f.secondRepo.workspaceId,
            'role': calls == 1 ? 'editor' : 'viewer',
            'sequence': 1,
            'documents': {
              f.id: {'version': 1, 'snapshot': baseline},
            },
            'peers': [],
          }),
          200,
        );
      }),
      automaticPolling: false,
    );
    try {
      await controller.connect(f.endpoint, f.room, f.secondToken);
      f.edit(f.secondWorkspace, 0, 55);
      await controller.pump();
      expect(controller.viewer, true);
      expect(controller.viewerChanges.value, true);
      expect(writes, 0);
      expect(controller.pendingChanges, 1);
      expect(f.secondWorkspace.find(f.id)!.data['elements'][0]['x'], 55);
    } finally {
      controller.dispose();
    }
  });

  test(
    'upgrading a host without epoch metadata requests full state once',
    () async {
      var reads = 0;
      final transport = http.Client();
      final controller = CollaborationController(
        f.secondWorkspace,
        MockClient((request) async {
          final response = await transport.get(
            request.url,
            headers: request.headers,
          );
          final state = jsonDecode(response.body) as Map<String, dynamic>;
          if (++reads == 1) state.remove('epoch');
          return http.Response(jsonEncode(state), response.statusCode);
        }),
        automaticPolling: false,
      );
      try {
        await controller.connect(f.endpoint, f.room, f.secondToken);
        await controller.pump();
        expect(controller.conflicts, isEmpty);
        expect(controller.retryAt, null);
        expect(controller.pendingChanges, 0);
        await controller.pump();
        expect(controller.conflicts, isEmpty);
      } finally {
        controller.dispose();
        transport.close();
      }
    },
  );

  Future<void> canvasConflict() async {
    f.edit(f.firstWorkspace, 0, 30);
    f.edit(f.secondWorkspace, 0, 50);
    await f.first.pump();
    await f.second.pump();
    expect(f.second.canReviewCanvas(f.id), true);
  }

  test(
    'host restart invalidates an open Canvas review before saving its choices',
    () async {
      await canvasConflict();
      final review = await f.second.reviewCanvas(f.id);
      final original = f.secondWorkspace.find(f.id)!.data;
      await restart();
      await expectLater(
        f.second.resolveCanvas(review, {f.ids[0]: CanvasConflictSide.shared}),
        throwsStateError,
      );
      expect(f.secondWorkspace.find(f.id)!.data, original);
      await f.second.pump();
      expect(f.second.canReviewCanvas(f.id), false);
      expect(f.second.conflicts, contains(f.id));
    },
  );

  test(
    'Canvas review cannot invent a base after the host restarts before polling',
    () async {
      await canvasConflict();
      await restart();
      await expectLater(f.second.reviewCanvas(f.id), throwsStateError);
      expect(f.secondWorkspace.find(f.id)!.data['elements'][0]['x'], 50);
      await f.second.pump();
      expect(f.second.canReviewCanvas(f.id), false);
    },
  );

  test(
    'an edit cannot cross a host restart between preflight and publication',
    () async {
      var restartOnEdit = true;
      final transport = http.Client();
      final controller = CollaborationController(
        f.secondWorkspace,
        MockClient((request) async {
          if (request.method == 'POST' && restartOnEdit) {
            restartOnEdit = false;
            await restart();
          }
          final forwarded = http.Request(request.method, request.url)
            ..headers.addAll(request.headers)
            ..bodyBytes = request.bodyBytes
            ..followRedirects = false;
          return transport.send(forwarded).then(http.Response.fromStream);
        }),
        automaticPolling: false,
      );
      try {
        await controller.connect(f.endpoint, f.room, f.secondToken);
        f.edit(f.secondWorkspace, 0, 777);
        await controller.pump();
        expect(controller.conflicts[f.id], contains('host restarted'));
        expect(controller.canReviewCanvas(f.id), false);
        expect(f.secondWorkspace.find(f.id)!.data['elements'][0]['x'], 777);
        final state = await f.first.inspectRoom(
          f.endpoint,
          f.room,
          f.firstToken,
        );
        expect(state['documents'][f.id]['version'], 1);
        expect(
          state['documents'][f.id]['snapshot']['data']['elements'][0]['x'],
          0,
        );
      } finally {
        controller.dispose();
        transport.close();
      }
    },
  );

  testWidgets('hosting guide works at a narrow width with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? address;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: SharedServerSetup(onUseAddress: (v) => address = v),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Set up a host for your devices'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'notes.example.com');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Use this HTTPS address'));
    await tester.tap(find.text('Use this HTTPS address'));
    expect(address, 'https://notes.example.com');
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
}
