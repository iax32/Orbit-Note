import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/app/canvas_performance.dart';
import 'package:orbit_note/features/workspace/canvas_performance_card.dart';
import 'package:orbit_note/platform/performance_log_types.dart';
import 'package:orbit_note/platform/performance_log_native.dart';

class _Store implements PerformanceLogStore {
  @override
  bool enabled = true;
  @override
  String get path => 'local-performance-log.jsonl';
  String text = '';
  Completer<void>? block;
  int writes = 0;
  bool fail = false;
  @override
  Future<void> setEnabled(bool value) async {
    enabled = value;
  }

  @override
  Future<void> append(String lines) async {
    writes++;
    if (fail) {
      throw StateError('private information must not enter diagnostics');
    }
    await block?.future;
    text += lines;
  }

  @override
  Future<String> read() async => text;
}

void main() {
  test(
    'recorder stays bounded and stores numeric diagnostics without user content',
    () async {
      final store = _Store();
      final monitor = CanvasPerformance(bindScheduler: false);
      addTearDown(monitor.dispose);
      await monitor.start(store: store);
      final surface = monitor.attach();
      monitor.context(surface, {
        'strokes': 1539,
        'samples': 42890,
        'bad private field': 5,
      });
      for (var i = 0; i < 1000; i++) {
        monitor.event(CanvasPerfEvent.frameStall, surface, {'uiUs': i});
      }
      expect(monitor.retainedEvents, 128);
      monitor.tick();
      await monitor.flush();
      final events = store.text
          .trim()
          .split('\n')
          .map((line) => jsonDecode(line) as Map)
          .toList();
      expect(events.length, lessThanOrEqualTo(128));
      expect(
        events.any((e) => e['event'] == 'summary' && (e['dropped'] as num) > 0),
        true,
      );
      expect(store.text, isNot(contains('private')));
      expect(store.text, isNot(contains('points')));
      await monitor.setEnabled(false);
      final saved = store.text;
      monitor.event(CanvasPerfEvent.frameStall, surface, {'gpuUs': 90000});
      monitor.tick();
      await monitor.flush();
      expect(store.text, saved);
      monitor.detach(surface);
    },
  );

  test(
    'async writes serialize and late events are included in readback',
    () async {
      final store = _Store()..block = Completer<void>();
      final monitor = CanvasPerformance(bindScheduler: false);
      addTearDown(monitor.dispose);
      await monitor.start(store: store);
      final surface = monitor.attach();
      monitor.event(CanvasPerfEvent.save, surface, {'us': 100});
      final first = monitor.flush();
      monitor.event(CanvasPerfEvent.save, surface, {'us': 200});
      final second = monitor.flush();
      expect(store.writes, 1);
      store.block!.complete();
      await Future.wait([first, second]);
      final content = await monitor.read();
      expect(store.writes, 2);
      expect(content, contains('100'));
      expect(content, contains('200'));
      store.fail = true;
      monitor.event(CanvasPerfEvent.save, surface, {'us': 300});
      await monitor.flush();
      expect(monitor.error, 'Could not write local performance log.');
      expect(store.text, isNot(contains('private information')));
    },
  );

  test(
    'native log rotates within its limit and the off choice survives restart',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'orbit-performance-test-',
      );
      addTearDown(() => root.delete(recursive: true));
      final store = NativePerformanceLogStore(
        root,
        defaultEnabled: true,
        maxBytes: 128,
      );
      await store.initialize();
      final line = '${jsonEncode({'event': 'summary', 'frames': 25})}\n';
      for (var i = 0; i < 12; i++) {
        await store.append(line);
      }
      final logs = await root
          .list()
          .where((entry) => entry.path.endsWith('.jsonl'))
          .toList();
      expect(logs.length, 2);
      for (final entry in logs) {
        expect(await File(entry.path).length(), lessThanOrEqualTo(128));
      }
      await store.setEnabled(false);
      final saved = await store.read();
      await store.append(line);
      expect(await store.read(), saved);
      final reopened = NativePerformanceLogStore(
        root,
        defaultEnabled: true,
        maxBytes: 128,
      );
      await reopened.initialize();
      expect(reopened.enabled, false);
      await reopened.setEnabled(true);
      await reopened.append(line);
      expect(await reopened.read(), isNotEmpty);
      await expectLater(reopened.append('x' * 200), throwsFormatException);
    },
  );

  testWidgets(
    'diagnostic controls expose a reversible logging switch and export',
    (tester) async {
      final store = _Store();
      final monitor = CanvasPerformance(bindScheduler: false);
      await monitor.start(store: store);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              child: CanvasPerformanceCard(monitor: monitor),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Save diagnostic log'), findsOneWidget);
      expect(find.text('Copy log location'), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(monitor.enabled, false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      monitor.dispose();
    },
  );
}
